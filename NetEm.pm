package SonusQA::NetEm;

=pod

=head1 NAME

SonusQA::NetEm- Perl module for Linux Net::Em interaction

=head1 SYNOPSIS

   use SonusQA::NetEm;  # This is the class for the ATS interface to a WAN impairment simulation system using Net::Em.

   my $netem = SonusQA::NetEm->new(-OBJ_HOST => '<host name | IP Adress>',
                                   -OBJ_USER => '<cli user name>',
                                   -OBJ_PASSWORD => '<cli user password>',
                                   -OBJ_COMMTYPE => "<TELNET|SSH>",
                                );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

That the target device already have the ipRoute2, bridge-utils and netem kernel modules installed - and the ethernet bridge(s) pre-configured on the appropriate LAN(s)

=head1 DESCRIPTION

   This module provides an interface for Linux Net::Em interaction.

=head2 AUTHORS

Malcolm Lashley <mlashley@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
Based on the original code in SonusQA::NistNet
See Inline documentation for contributors.

=head2 Test/Example code

Example/Test code is included at the bottom of the module - please ensure this runs correctly when submitting changes.

=head2 SUB-ROUTINES

The following subroutines contain the guts of the implementation - scroll down to EASY-INTERFACE for the high-level wrappers which should be used in most test scripts.


=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;

use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = "NetEm";
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{SESSIONLOG} = 0; # Set to 1 to enable session logs dumped to /tmp 
}

=head3 $obj->detectBridges();

Object method to retrieve the ethernet bridge(s) configured on the NetEm box and store the details of which physical interfaces make up the bridge in $self->{BRIDGES}

Return:  none ($self->{BRIDGES} is populated if bridges are found - else it will be undef.

Example: 

 $obj->detectBridges();

Would yield the following structure on a machine with 2 bridges each of 2 interfaces.

 $self->{BRIDGES} = \{
            'br1' => {
                       'INTERFACES' => [
                                         'eth3',
                                         'eth4'
                                       ],
                     },
            'br0' => {
                       'INTERFACES' => [
                                         'eth1',
                                         'eth2'
                                       ],
                     }
          };

=cut

sub detectBridges(){
  my($self)=@_;
	my $sub_name = '.detectBridges';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
	my (@results,%bridges,$bridge,$interfaces); 
  @results = $self->{conn}->cmd("brctl show");
  foreach(@results) {
		if (m/^(br[0-9]).*(eth[0-9])/) {
	  	$bridge = $1;
			$interfaces = $2;
			chomp $interfaces;
			$self->{BRIDGES}->{$bridge}->{INTERFACES} = [ $interfaces ];
		  $logger->info(__PACKAGE__ . "$sub_name Found ethernet bridge $bridge - using interface $interfaces");
		} elsif (m/(eth[0-9])/) {
			# Found additional interface for the current bridge
			$interfaces = $1;
			chomp $interfaces;
			push @{$self->{BRIDGES}->{$bridge}->{INTERFACES}} , $interfaces ;
		  $logger->info(__PACKAGE__ . "$sub_name Found additional interface $1 on existing/known bridge $bridge");
		}
	}
}
=head3 $obj->detectBridgeIPs();

Object method to retrieve the IP address(es) and netmask(s) of the ethernet bridge(s) detected above and add the information to $self->{BRIDGES}

Return:  none ($self->{BRIDGES}->{$bridgename}->{IP} is populated if an IP address is found - else it will be undef.

Example: 

 $obj->detectBridgeIPs();

Would set the datastructure such as:

 $obj->{BRIDGES}->{$bridgename}->{IP} = '10.31.242.10/16'

Where the IP is 10.31.242.10 and the netmask is in standard shorthand (here == 255.255.0.0)

=cut


sub detectBridgeIPs(){
  my($self)=@_;
	my $sub_name = '.detectBridgeIPs';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
	my (@results,%bridges,$bridge,$interfaces); 
	foreach $bridge (keys %{$self->{BRIDGES}}) {
	  $logger->info(__PACKAGE__ . "$sub_name Fetching IP address for $bridge");
	  @results = $self->{conn}->cmd("ip addr show dev $bridge");
		foreach(@results) {
			if(m/inet ([0-9\.\/]+)/) {
				$logger->info(__PACKAGE__ . "$sub_name Device $bridge has ip $1");
				$self->{BRIDGES}->{$bridge}->{IP} = $1;
			}
		}
	}
}
			


sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $cmd = 'PS1="AUTOMATION#"';
  $self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION#$/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd("");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  

  # Check we have connected to a box with the prerequisites installed/configured 
  # i.e. at least one ethernet bridge setup, and the 'tc' command from the ipRoute2 package
  $logger->info(__PACKAGE__ . ".setSystem Checking prerequisite - 'tc' utility (from ipRoute2)");
  @results = $self->{conn}->cmd("tc -V");
  foreach(@results) {
	  if (m/iproute2/) {
		  $logger->info(__PACKAGE__ . ".setSystem found $_");
			last;
	  } else {	  
		  &error(__PACKAGE__ . ".setSystem could not find 'tc' utility on remote machine - unable to continue: " . Dumper(\@results));
	  }	  
	}

  $logger->info(__PACKAGE__ . ".setSystem Checking prerequisite - brctl utility (from bridge-utils)");
  @results = $self->{conn}->cmd("brctl -V");
  foreach(@results) {
	  if (m/bridge-utils/) {
		  $logger->info(__PACKAGE__ . ".setSystem found $_");
			last;
	  } else {	  
		  &error(__PACKAGE__ . ".setSystem could not find 'brctl' utility on remote machine - unable to continue $_");
	  }
  }

  $logger->info(__PACKAGE__ . ".setSystem Checking prerequisite - ethernet bridge(s) configured");
	$self->detectBridges();
	if (not defined $self->{BRIDGES}) {
	  &error(__PACKAGE__ . ".setSystem could not find any ethernet bridges configure on remote machine - unable to continue");
	}

  $logger->info(__PACKAGE__ . ".setSystem Fetching Bridge IP addresses");
	$self->detectBridgeIPs();
	$logger->info(__PACKAGE__ . ".setSystem Determined Bridge config:\n" . Dumper(\$self->{BRIDGES}));

	foreach ($self->getAllInterfaces()) {
			# Robustness - we try to delete any old cruft a user may have left configured, only error if we cannot add in the qdiscs.
		  $logger->info(__PACKAGE__ . ".setSystem Clearing out any old config on the remote device - ignore errors for the 'del' action");
			$self->execShellCmd("tc qdisc del dev $_ root netem delay 0ms");
			unless ($self->execShellCmd("tc qdisc add dev $_ root netem delay 0ms")) {
				&error(__PACKAGE__ . ".setSystem Unable to add netem qdiscs, cannot continue (Is netem installed?)");
			}
	}
        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
        return 1;
}

=head3 $obj->getBridges()

Returns the sorted list of bridges defined on this NetEm host device.

Example:

 @ary=$obj->getBridges();

Now $ary[0] contains what we later refer to as bridge0
Now $ary[1] contains what we later refer to as bridge1 etc.

=cut


sub getBridges() {
  my ($self)=@_;
	my $sub_name = '.getBridges';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
	return sort keys %{$self->{BRIDGES}};
}


=head3 $obj->getAllInterfaces([$bridge]);

 Object method to retrieve the interfaces which make up the specified ethernet bridge
 If no bridge is specified, or 'all' is specified - return all devices for all bridges (used in the case where we need to reset each interface to a sane state).

=head3 ARGUMENTS:

 $obj->applyGeneric($netem, [$bridge|$interface|<none>]).

e.g.

 # Get the list of interfaces which make up bridge 'br0'
 @interfaces = $obj->getAllInterfaces('br0');

 # Get the list of interfaces which make up all configured bridge(s) 
 @interfaces = $obj->getAllInterfaces();

=head3 RETURNS:

Return:  ARRAYREF containing list of interfaces e.g. [ 'eth1', 'eth3' ] - or undef if the specified bridge is not found.

=head3 AUTHOR:

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub getAllInterfaces {
  my ($self,$bridge)=@_;
	my $sub_name = '.getAllInterfaces';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
	if (defined $bridge && $bridge ne "all") {
  # Look for a specific bridge and return the child interfaces
    $logger->info(__PACKAGE__ . "$sub_name Getting child interfaces for bridge '$bridge'");
		my ($b);
		foreach ($self->getBridges()) { 
			if ($bridge eq $_) {
				if (defined $self->{BRIDGES}->{$bridge}->{INTERFACES}) {
					return @{$self->{BRIDGES}->{$bridge}->{INTERFACES}};
				} else {
					$logger->warn(__PACKAGE__ . "$sub_name Could not find any interfaces for bridge '$bridge' in the config");
					return;
				}
			}
		}
		$logger->warn(__PACKAGE__ . "$sub_name Could not find any bridge by that name ('$bridge') in the config");
		return;
	} else {
	# Return all interfaces for all bridges
	  $logger->debug(__PACKAGE__ . "$sub_name Getting all configured interfaces for all bridges");
		my @result;
		foreach $bridge ($self->getBridges()) {
			push @result, $self->getAllInterfaces($bridge); # Yay - recursion ;-)
		}
		return @result;
	}
}

=head3 $obj->applyGeneric($netem, [$bridge|$interface|<none>]);

 Object method to apply a generic netem action (specified as the first argument) to either
 a) all interfaces which make up the specified ethernet bridge ( br[0-9] )
 b) a specific interface ( eth[0-9] )
 c) all configured interfaces on all bridges (if no bridge specified)
 (used in the case where we need to reset each interface to a sane state)

=head3 ARGUMENTS:

 $obj->applyGeneric($netem, [$bridge|$interface|<none>]).

e.g.

 # Apply 80ms delay to each of the interfaces which make up bridge 'br0'
 @res = $obj->applyGeneric('delay 80ms','br0');

 # Apply 0ms delay to all interfaces on all configured bridges
 @res = $obj->applyGeneric('delay 0ms');

 # Apply 1% packet loss to all interface eth1
 @res = $obj->applyGeneric('loss 1%', 'eth1');

=head3 RETURNS:

1 on success, 0 on command failure - or undef if the specified bridge/interface is not found.

=head3 AUTHOR:

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub applyGeneric {
  my ($self,$cmd,$device)=@_;
	my $sub_name = '.applyGeneric';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
  my(@interfaces,@cmdResults);
	 
	@interfaces = $self->getAllInterfaces($device);

	if (not @interfaces) {
			$logger->error(__PACKAGE__ . "$sub_name Could not determine interface(s) to act on");
			return;
	} else {
		foreach (@interfaces) {
			@cmdResults = $self->execShellCmd("tc qdisc change dev $_ root netem $cmd");
		}
	}
}

=head3 $obj->getQdisc([$bridge|$interface|<none>]);

 Object method to retreive the current qdisc (i.e. the netem config) applied to either
 a) all interfaces which make up the specified ethernet bridge ( br[0-9] )
 b) a specific interface ( eth[0-9] )
 c) all configured interfaces on all bridges (if no bridge specified)
 (used in the case where we need to reset each interface to a sane state)

=head3 ARGUMENTS:

 $obj->getQdisc([$bridge|$interface|<none>]).

e.g.

 $netem->getQdisc('br1');

=head3 RETURNS:

HASHREF of ARRAYs containing the state of each interface (interface name is hash-key) or undef if the specified bridge/interface is not found

=head3 AUTHOR:

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub getQdisc{
  my ($self,$device)=@_;
	my $sub_name = '.getQdisc';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
  my(@interfaces,%cmdResults);
	 
	if (defined $device and $device =~ m/^eth[0-9]$/) {
		$logger->info(__PACKAGE__ . "$sub_name assuming $device is a single interface");
		@interfaces = ( $device );
	} else {
		@interfaces = $self->getAllInterfaces($device);
	}

	if (not @interfaces) {
			$logger->error(__PACKAGE__ . "$sub_name Could not determine interface(s) to act on for $device");
			return;
	} else {
		foreach (@interfaces) {
			push @{$cmdResults{$_}}, $self->execCmd("tc qdisc show dev $_ ");
		}
		return %cmdResults;
	}
}

# This would be better moved to UNIX Base...
sub checkShellReturnValue {
  my ($self,$cmd)=@_;
	my $sub_name = '.checkShellReturnValue';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
	my (@result);
	unless ( @result = $self->execCmd( "echo \$?" ) ) {
		$logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        return 0;
    }
    unless ( $result[0] == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0]");
        return 0;
    }
    return 1;
}

=head3 $obj->execShellCmd()

 Almost the same as execCmd - with the addition of checking the shell commands return code, and the fact that this is used for commands which are not expected to return output.

=head3 RETURNS:

        - 1 execCmd() was ok *and* the shell return value was 0.
        - 0 either execCmd() failed (it can't as currently written - as it will error on timeout..., or the shell return value was non-zero.

=head3 AUTHOR:

Malcolm Lashley <mlashley@sonusnet.com>

=cut


sub execShellCmd {
	my ($self,$cmd)=@_;
	my $sub_name = ".execShellCmd";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
#	$logger->debug(__PACKAGE__ . "$sub_name Entered");
	my @cmdResults = $self->execCmd($cmd);
	return $self->checkShellReturnValue();
}

sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd)) {
    # Section for commnad execution error handling - CLI hangs, etc can be noted here.
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd NetEm CLI CMD ERROR - EXITING");
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");

  return @cmdResults;
}

=head2 EASY-INTERFACE $obj->apply(...)

This is meant as an easy wrapper to allow complex setups/combinations of impairments to be applied.
The command take an array of the following as arguments, each array element has similar syntax and are meant to be self explanatory... 

apply [ bridge/lan identifier ] [ direction ] [impairment type(s)] [ specific args ]

apply [bridge[0|1]|all] [UnidirIn|UnidirOut|Bidir] [delay|loss|corrupt|duplicate|reorder] [ [DELAY TIME [ JITTER [ CORRELATION ]]]| (DROP,CORRUPT,DUPLICATE,REORDER) PERCENT [CORRELATION]   ]

Uni-directional impairments assume that 'In' is applied to the lowest numbered ethX in the bridge, and 'Out' is applied to the highest numbered ethX. The concept of In/Out is specific to the user's testbed setup.

Bridge 0 is the lowest numbered 'brX' device, Bridge1 is the next. etc. (NB tested only with br0 and br1)

Examples:

 $obj->apply([bridge0, bidir, delay, '80ms'])

# The following (3) are equivalent (80ms delay, 5ms Jitter, 50% Correlation) - additional array elements are just treated as additional tc trailing arguments.

 $obj->apply([bridge0, bidir, delay, '80ms 5ms 50%'])
 $obj->apply([bridge0, bidir, delay, '80ms','5ms','50%'])
 $obj->apply([bridge0, bidir, delay, '80000 5000 50'])

 $obj->apply([all, bidir, delay, '0ms'])

 $obj->apply([bridge0, bidir, drop, '1%'], [bridge1, bidir, corrupt, '2%']) 

If you supply multiple entries for a single device - the commands will be concatenated - e.g apply 1% packet drop and 2% packet corruption on both interfaces in bridge0.

 $obj->apply([bridge0, bidir, drop, '1%'], [bridge0, bidir, corrupt, '2%']) 

Supplying conflicting requests (such as the following) will result in the latter overriding the former (be careful).

 $obj->apply([bridge0, bidir, drop, '1%'], [bridge0, bidir, drop, '2%']) 

Returns: 1 Success, 0 Failure.

=cut

sub apply {
  my ($self,@args)=@_;
	my $sub_name = ".apply";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
  $logger->debug(__PACKAGE__ . "$sub_name --> Entered");

	my (%cmdhash,$e,$i,@bridges);

	foreach $e (@args) {
		my $br = shift @{$e};
		unless ($br =~ m/bridge[0-9]|all/) { 
		  $logger->warn(__PACKAGE__ . "$sub_name Illegal bridge '$br', expected (bridge0|bridge1...|all)");
			return;
		}
		my $dir = shift @{$e};
		unless ($dir =~ m/unidir(in|out)|bidir/) {
		  $logger->warn(__PACKAGE__ . "$sub_name Illegal direction '$dir', expected (bidir|unidirin|unidirout)");
			return;
		}
		my $action = shift @{$e};
		unless ($action =~ m/delay|drop|corrupt|duplicate|reorder|distribution/) {
		  $logger->warn(__PACKAGE__ . "$sub_name Illegal action '$action', expected (delay|drop|corrupt|duplicate|reorder|distribution)");
			return;
		}
		my $arg = join " ",@{$e};

		$br =~ s/idge//;

		if ($br eq "all") { @bridges = $self->getBridges(); }
		else { @bridges = ( $br ); }

		foreach $b (@bridges) {
		  $logger->debug(__PACKAGE__ . "$sub_name Commands for bridge $b"); 
			my @interfaces = sort $self->getAllInterfaces($b);

			if ($dir eq "unidirin") { @interfaces = $interfaces[0] }; # Assumes 2 interfaces per bridge.
			if ($dir eq "unidirout") { @interfaces = $interfaces[1] }; 

		  $logger->debug(__PACKAGE__ . "$sub_name determined interfaces to be:\n" . Dumper(\@interfaces));
			foreach $i (@interfaces) {
				$cmdhash{$i} .= "$action $arg ";
			}
		}
	}
	foreach (keys %cmdhash) {
	  unless ($self->execShellCmd("tc qdisc change dev $_ root netem $cmdhash{$_}")) {
		  $logger->info(__PACKAGE__ . "$sub_name <-- Exited Abnormally (Command Failed)");
			return;
		}
	}

  $logger->debug(__PACKAGE__ . "$sub_name <-- Exited normally");
	return 1;

}





sub AUTOLOAD {
  our $AUTOLOAD;
  my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
  if(Log::Log4perl::initialized()){
    my $logger = Log::Log4perl->get_logger($AUTOLOAD);
    $logger->warn($warn);
  }else{
    Log::Log4perl->easy_init($DEBUG);
    WARN($warn);
  }
}

=head2 C< DESTROY >
# Override the DESTROY method inherited from Base.pm in order to remove any config if we bail out.
$obj->DESTROY();

=cut

sub DESTROY {
  my ($self,@args)=@_;
	my ($logger);
	my $sub_name = ".DESTROY";
	if(Log::Log4perl::initialized()){
		$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
	}else{
		$logger = Log::Log4perl->easy_init($DEBUG);
	}
	$logger->info(__PACKAGE__ . "$sub_name <-- Entered");

	# Delete any cruft we may leave lying around.
	foreach ($self->getAllInterfaces()) {
			$self->execShellCmd("tc qdisc del dev $_ root netem delay 0ms");
	}
	# Fall thru to regulare Base::DESTROY method.
	SonusQA::Base::DESTROY($self);
	$logger->info(__PACKAGE__ . "$sub_name --> Exiting");
}

=head1 TEST CODE 

The following code can be extracted and used to test the module - it is included here as additional examples of how (not) to use this module:

Please change the IP address before attempting to execute it!

 use SonusQA::NetEm;
 use Data::Dumper;

 print "\nTest 0 - Connect...\n";
 
 my $netem = SonusQA::NetEm->new(-OBJ_HOST => "10.128.97.151",-OBJ_USER => "root",-OBJ_PASSWORD => "ihavechangedtheipaddressonthisline",-OBJ_COMMTYPE => 'SSH', -IGNOREXML=>1);
 
 print "\nTest 1 - Cmd\n";
 print "-----------=======================--------------\n";
 print join "\n", $netem->execCmd("ip addr show dev eth1");
 print "-----------=======================--------------\n";
 
 { print "\nTest 2 - getAllInterfaces();\n";
 my @ary = $netem->getAllInterfaces();
 print Dumper(\@ary);
 die "Test Failed" unless defined @ary;
 }
 
 {print "\nTest 3 - getAllInterfaces('br0');\n";
 my @ary = $netem->getAllInterfaces('br0');
 print Dumper(\@ary);
 die "Test Failed" unless defined @ary;
 }
 
 {print "\nTest 4 - getAllInterfaces('bogus');\n";
 my @ary = $netem->getAllInterfaces('bogus');
 print Dumper(\@ary);
 if (defined @ary) { die "Test Failed"};
 }
 
 {print "\nTest 5 - applyGeneric('delay 69ms');\n";
 my @ary = $netem->applyGeneric('delay 69ms');
 my %hsh =  $netem->getQdisc();
 print Dumper(\%hsh);
 }
 {print "\nTest 6 - applyGeneric('loss 50%','br0');\n";
 my @ary = $netem->applyGeneric('loss 50%','br0');
 my %hsh =  $netem->getQdisc('br0');
 print Dumper(\%hsh);
 my %hsh =  $netem->getQdisc('br1');
 print Dumper(\%hsh);
 my %hsh =  $netem->getQdisc('eth1');
 print Dumper(\%hsh);
 }
 
 {print "\nTest 7 - applyGeneric('delay 0ms');\n";
 my @ary = $netem->applyGeneric('delay 0ms');
 my %hsh =  $netem->getQdisc();
 print Dumper(\%hsh);
 print "\n==================\n";
 print $hsh{'eth1'}[0];
 print "\n==================\n";
 }
 
 {print "\nTest 8 - getBridges();\n";
 my @ary = $netem->getBridges();
 print Dumper(\@ary);
 }
 
 
 {print "\nTest 9 - apply([all, bidir, delay, 0ms])\n";
 $netem->apply([all, bidir, delay, '0ms']);
 }
 
 {print "\nTest 10- apply([bridge0, bidir, drop, '1%'], [bridge1, unidirin, delay, '80ms 20ms'])\n";
 $netem->apply([bridge0, bidir, drop, '1%'], [bridge1, unidirin, delay, '80ms 20ms']) 
 }
 
 {print "\nTest 11- apply([bridge0, bidir, drop, '1%'], 
 	      [bridge1, unidirin, delay, '80ms 20ms'],
 	      [all, bidir, duplicate, '50'])";
 $netem->apply([bridge0, bidir, drop, '1%'], 
 	      [bridge1, unidirin, delay, '80ms 20ms'],
 	      [all, bidir, duplicate, '50']) ;
 my %hsh =  $netem->getQdisc();
 print Dumper(\%hsh);
 }
 
 {print "\nTest 12 apply([bridge0, bidir, drop, '1%'], [bridge0, bidir, drop, '2%']) - conflicting info - expected result is 2% loss on br0 (latter commands override former\n";
 $netem->apply([bridge0, bidir, drop, '1%'], [bridge0, bidir, drop, '2%']);
 print Dumper($netem->getQdisc('br0'));
 }
 
=cut


1;


