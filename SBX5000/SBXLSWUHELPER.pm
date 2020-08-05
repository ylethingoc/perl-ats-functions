package SonusQA::SBX5000::SBXLSWUHELPER;

=head1 NAME

SonusQA::SBX5000::SBX5000HELPER- Perl module to support LSWU Automation.

=head1 AUTHOR

sonus-ats-dev@sonusnet.com

=head1 REQUIRES

Perl5.8.7, SonusQA::Utils, Log::Log4perl, Data::Dumper, SonusQA::SBX5000, SonusQA::SBX5000::SBX5000HELPER, POSIX.

=head1 DESCRIPTION

Provides an interface to interact with the SBC during LSWU Automation.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use SonusQA::SBX5000;
use SonusQA::SBX5000::SBX5000HELPER;
use POSIX;

our $TESTSUITE;
our $ccPackage;

=head2 C< checkSystemSyncStatus >

=over

=item DESCRIPTION:

    This API executes the cli command and checks for the system sync status. The API returns failure even if one field is not in Sync state.

=item ARGUMENTS:

    Mandatory:
	1. cli command
	2. Cli hash

    Optional:
	1. mode 

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::SBX5000::execCmd()

=item OUTPUT:

    0   - fail 
    Hardware Type - success

=item EXAMPLE:

    %cliHash = ( "stableCalls" => "unprotected" );
    unless ( $self->checkSystemSyncStatus("show status global callCountStatus",\%cliHash ) ) {
        $logger->error(__PACKAGE__ . " status not in syncd state");
        return 0;
    }

=back

=cut

sub checkSystemSyncStatus {
    my $self = shift;
    my $sub_name = "checkSystemSyncStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    if ($self->{D_SBC}) {
        my %hash = (
            'args' => [@_]
        );
        my $retVal = $self->__dsbcCallback(\&checkSystemSyncStatus, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }

    my ($cmd, $cliHash, $mode) = @_ ;
    my %cliHash = %$cliHash;

    if($self->{REDUNDANCY_ROLE}){
        if($self->{REDUNDANCY_ROLE} =~ /ACTIVE/i){
            %cliHash =  ( 'Metavar Data' => 'syncCompleted',
                          'Call/Registration Data' => 'syncCompleted' );
        }elsif($self->{REDUNDANCY_ROLE} =~ /STANDBY/i){
            %cliHash =  ( 'Metavar Data' => 'unprotectedRunningStandby',
                          'Call/Registration Data' => 'unprotectedRunningStandby' );
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Entered", Dumper(\%cliHash));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CLI command empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cliHash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Hash Reference empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @avoid_us = ('Stopping user sessions during sync phase\!','Disabling updates \-\- read only access','Enabling updates \-\- read\/write access');
    my $pattern = '(' . join('|',@avoid_us) . ')';

    ########  Execute input CLI Command #########################################

    my @output;
    if ( $mode =~ m/private/i ) {
        $self->execCmd("configure private");
        $logger->info(__PACKAGE__ . ".$sub_name: Issuing command : $cmd");
        unless ( @output = $self->execCmd($cmd) ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: CLI COMMAND UNSUCCESSFUL");
            return 0;
        }
	foreach (@output) {
	    if ($_ =~ /$pattern/i) {
		$logger->debug(__PACKAGE__ . ".$sub_name: Atleast one of the pop up messages appeared: $_ ");
		$logger->debug(__PACKAGE__ . ".$sub_name: Issuing the cli cmd again: $cmd");		
		unless ( @output = $self->execCmd($cmd) ) {
             	   $logger->debug(__PACKAGE__ . ".$sub_name: CLI COMMAND UNSUCCESSFUL");
	           return 0;
                }
	    }
	}
        $self->leaveConfigureSession;
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Issuing cli command : $cmd");
        unless ( @output = $self->execCmd($cmd) ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: CLI COMMAND NOT SUCCESSFUL");
            return 0;
        }
	foreach (@output) {
            if ($_ =~ /$pattern/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Atleast one of the pop up messages appeared: $_ ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Issuing the cli cmd again: $cmd");
                unless ( @output = $self->execCmd($cmd) ) {
                   $logger->debug(__PACKAGE__ . ".$sub_name: CLI COMMAND UNSUCCESSFUL");
                   return 0;
                }
            }
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: cmd output : \n@output\n");
    return 0 if ($#output < 0);

    my $match = 1;
    my $match_found = 0;
    my ($syncStatus, $len);
    my $no_match = 0 ;


    for ( keys %cliHash ) {
        $match_found = 0;
        foreach my $line (@output) {
#            if ( $line =~ /^\[ok\]/i ) {
#                last;
#            }
            if ( $line =~ /$_/i ) {
                $match_found = 1;
                next;
            }
            if ( $match_found ) {
                $no_match = 1;
                if ( $line =~ /\s+status\s+(.*)$/i ) {
                    $syncStatus = $1;
                    $len = length($syncStatus);
                    $syncStatus = substr($syncStatus, 0, $len-1);
                    if ( $syncStatus =~ /$cliHash{$_}/i ) {
                        $logger->info(__PACKAGE__ . ".$sub_name: Matched $_, Expected : $cliHash{$_} Actual : $syncStatus ");
                        last;
                    } else {
                        $logger->info(__PACKAGE__ . ".$sub_name: Did not Match $_, Expected : $cliHash{$_} Actual : $syncStatus ");
                        $match = 0;
                        last;
                    }
                }
            } 
		 
        }
    }
   
    if (( $match ) and ( $no_match == 0 )) {
        $logger->info(__PACKAGE__ . ".$sub_name: Unable to get the required output" . Dumper(\@output) );
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    if ( $match ) {
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
        return 1;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
    return 0;
}


=head2 C< checkSbxSyncStatus >

=over

=item DESCRIPTION:

    This API executes the cli command and checks for the system sync status. The API returns failure even if one field is not in Sync state. This API internally calls checkSystemSyncStatus(). Here it loops for 4 minites inside which it verifies the state for every 60 seconds.

=item ARGUMENTS:

    Mandztory:
	1. cli command
	2. Cli hash

    Optional:
	1. Number of attempts for syncstatus check, default value is 8  

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::SBX5000::SBXLSWUHELPER::checkSystemSyncStatus()

=item OUTPUT:

    0   - fail 
    Hardware Type - success

=item EXAMPLE:

    %cliHash = ( "stableCalls" => "unprotected" );
    unless ( $self->checkSbxSyncStatus("show status global callCountStatus",\%cliHash , 5) ) {
        $logger->error(__PACKAGE__ . " status not in syncd state");
        return 0;
    }

=back

=cut


sub checkSbxSyncStatus {
    my ($self, $cmd, $clihash, $attempt) = @_ ;
    my $sub_name = "checkSbxSyncStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CLI command empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $clihash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Hash Reference empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $count = 1;    
    $attempt ||= 8;
    while ($count <= $attempt) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Sync status check Attempt->$count");
  	if ($self->checkSystemSyncStatus($cmd, $clihash)) {
	    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");  
            $logger->debug(__PACKAGE__ . ".$sub_name: Capturing the complete output to handle sync updates");
            my @gettrail = $self->{conn}->getlines(All => "", Timeout=> 1);      # Added to handle the Popups coming during HA sync after switchover : TOOLS: 2546
	    return 1;
	}
	$count += 1;
	$logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 60 seconds!"); 
        sleep 60; 
        my @gettrail = $self->{conn}->getlines(All => "", Timeout=> 1); 
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
}

=head2 C< execSbxCliCmd >

=over

=item DESCRIPTION:

 This API prints the CLI command and waits for the prompt and if it matches it will return true. This API handles for the prompt (yes/no) or [yes,no] and Error. This API should be used only for LSWU Feature.

 Note : 
 1. If the command is to be issued in primary SBX, then the API will match for the (yes/no) prompt and executes the cli. Here, it will not match for the device prompt to update the result since the connection is closed after issuing the command.
 2. If it is the secondary SBX, then the API matches for the (yes/no) or [yes,no] prompt after issuing the cli. Then it matches for the prompt(result failure or result success) and updates/returns the result accordingly.

=item ARGUMENTS:

 1. CLI Command to be executed.

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::SBX5000::SBXLSWUHELPER::getSwitchOverObject()

=item OUTPUT:

 returns 1 , if success
 returns 0 , if fails

=item EXAMPLE:

 $cmd = "request system serverAdmin sbx39.eng.sonusnet.com startSoftwareUpgrade package sbx-V03.00.00-A010.x86_64.tar.gz versionCheck skip";

 unless ( $self->execSbxCliCmd($cmd) ) {
    $logger->debug(__PACKAGE__ . ".$sub_name: Command Execution Failed");
    return 0;
 }

=back

=cut

sub execSbxCliCmd {
    my ( $self, $cmd ) = @_;
    my $sub_name = "execSbxCliCmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered");

    if ($self->{D_SBC}) {
	my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
	my @role_arr = $self->nkRoleLookUp($cmd) if ($self->{NK_REDUNDANCY});
        my %hash = (
                        'args' => [$cmd],
                        'types'=> [@dsbc_arr],
			'roles'=> [@role_arr]
                );
        my $retVal = $self->__dsbcCallback(\&execSbxCliCmd, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }

    unless ( $cmd ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Mandatory Argument not defined");
 	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if (exists $self->{REDUNDANCY_ROLE} and $cmd =~ /switchover/){
        $self = $self->getSwitchOverObject();
    }
    elsif($self->{REDUNDANCY_ROLE} =~ /STANDBY/){ #TOOLS-15088 - to reconnect to standby before executing command
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing CLI Command : $cmd");
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command :$cmd");
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }	  

    $logger->info(__PACKAGE__ . ".$sub_name:  Executed : $cmd");

    my ($prematch, $match);
    my ($prematch1, $match1);	

    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/(yes|no)[\/,](yes|no)/',
                                                           -match     => '/\[error\]/',
                                                         )) {
        $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after issuing Upgrade command");
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if ( $match =~ m/error/ ) {
        $logger->info(__PACKAGE__ . ".$sub_name:  Command resulted in error\n$prematch\n$match");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/(yes|no)[\/,](yes|no)/ ) {
        $logger->info(__PACKAGE__ . ".$sub_name:  Matched yes,no prompt for discarding changes");
	$logger->info(__PACKAGE__ . ".$sub_name: Entering - \"yes\"");
        # Enter "yes"
        unless ( $self->{conn}->print( "yes" ) ) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command :\"yes\" ");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
	}

	if ($cmd =~ /$main::TESTSUITE->{Primary_SBX}/i) {
	    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	    return 1;	
	}

	sleep 10;
	unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/result success/',
                                                           -match     => '/result failure/',
                                                         )) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \"yes\" ");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
	if ( $match =~ m/result failure/ ) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Command resulted in error\n$prematch\n$match");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
	if ( $match =~ m/result success/ ) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Matched success prompt!");
	    $self->{conn}->waitfor(
                                   -match     => $self->{PROMPT},
                                   -timeout    => 10,
                                            );
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'Cli Command\'\n$prematch\n$match");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
   }
}

=head2 C< checkCallCounts >

=over

=item DESCRIPTION:

 This API executes the CLI command (show status global callCountStatus) and returns the Hash containing the value of current stablecalls.

=item ARGUMENTS:

 1. CLI Command to be executed.

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCmd()

=item OUTPUT:

 returns stablecalls , if success
 returns 0 , if fails

=item EXAMPLE:

 unless ( $self->checkCallCounts() ) {
    $logger->debug(__PACKAGE__ . ".$sub_name: Command Execution Failed");
    return 0;
 }

=back

=cut


sub checkCallCounts {
    my ( $self, $input_callcount ) = @_;
    my $sub_name = "checkCallCounts()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: Entered");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "show status global callCountStatus";
    my (@output, $callcount, $len, %callcount_hash);
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing Command : $cmd");
    unless ( @output = $self->execCmd($cmd) ) {
	$logger->error(__PACKAGE__ . ".$sub_name: Command Execution Unsuccessful");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed command ($cmd)");
    foreach my $line(@output) {
	if ( $line =~ /^\s+stableCalls\s+(.*)$/i ) {
	    $callcount = $1;
            $len = length($callcount);
            $callcount = substr($callcount, 0, $len-1);
	    $logger->info(__PACKAGE__ . ".$sub_name:callcount -> $callcount");	
	    
	    %callcount_hash = (
				 -callCount => $callcount,
					);	

	    return \%callcount_hash;	
	}
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
    return 0;	
}

=head2 C< compareCallCountsAndUpgrade >

=over

=item DESCRIPTION:

 This API actually gets the stable calls value and compares with input Stable_Call_Counts value ( $TESTSUITE->{Stable_Call_Counts} ). If the current value is greater than or equal to that input value, execute the upgrade command. if not, it will wait for 60 secs and loops untill it reaches a maximum time limit of 180 secs .

=item ARGUMENTS:

 -SBXtype, (Primary/Secondary)

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::SBX5000::_execShellCmd()
        SonusQA::SBX5000::SBXLSWUHELPER::checkCallCounts()

=item OUTPUT:

    0   - fail 
    1 - success

=item EXAMPLE:

    unless ( $self->compareCallCountsAndUpgrade('sbx48.eng.sonusnet.com') ) {
        $logger->error(__PACKAGE__ . " Failed to upgrade the SBX ");
        return 0;
    }

=back

=cut

sub compareCallCountsAndUpgrade {
    my ($self) = shift;
    my $sub_name = "compareCallCountsAndUpgrade()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    if ($self->{D_SBC}) {
	my %hash = (
			'args' => [@_]
		);
	my $retVal = $self->__dsbcCallback(\&compareCallCountsAndUpgrade, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
	return $retVal;
    }
    my ($SBX_type)  = @_;    
    unless ( defined ($SBX_type) ) {
	$logger->error(__PACKAGE__ . ".$sub_name: SBX Type not specified");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
	return 0;
    }

    #verifying the presence of the target package in the device
    my $target_package = "/opt/sonus/external/" . "$main::TESTSUITE->{Target_Package}";
    my $shellCmd = "ls -lrt $target_package";

    my ($re, @result) = _execShellCmd($self->{$self->{ACTIVE_CE}}, $shellCmd);
    unless ($re) {
	$logger->debug(__PACKAGE__ . ".$sub_name: failed cmd execution: $shellCmd");
	$logger->debug(__PACKAGE__ . ".$sub_name: the output is \n".Dumper(\@result));
	return 0;
    }

    if ($result[1] =~ /No such file or directory/i) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Package ($target_package) not Found! ");
	return 0;
    }
    else {
	$logger->info(__PACKAGE__ . ".$sub_name: Package  ($target_package) exists! ");
    }

    #get the callcounts and compare                                           
    my ($res, %call_count_Hash, $call_count);

    unless ( $res = $self->checkCallCounts() ) {                                    
        $logger->debug(__PACKAGE__ . ".$sub_name: Could'nt get the Stablecall status from the table");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    
    %call_count_Hash = %{$res};
    $call_count = $call_count_Hash{-callCount};
    my $upgrade_cmd;

    #Framing the software upgrade command
    if ($main::TESTSUITE->{Skip_Version_Check} =~ m/yes/i) {
	$upgrade_cmd = "request system serverAdmin " . $SBX_type . " startSoftwareUpgrade package " . $main::TESTSUITE->{Target_Package} . " versionCheck skip"; 
    } else {
	$upgrade_cmd = "request system serverAdmin " . $SBX_type . " startSoftwareUpgrade package " . $main::TESTSUITE->{Target_Package} . " versionCheck perform";
    }

    my $sleep_time = 0;
    my $count = 1;

    while ($sleep_time <= 180) {
 
       $logger->debug(__PACKAGE__ . ".$sub_name: Comparing the CallCount status: Attempt-->$count");
        unless ( $res = $self->checkCallCounts() ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Could'nt get the Stablecall status from the table");
            $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }

        %call_count_Hash = %{$res};
        $call_count = $call_count_Hash{-callCount};

        if ( $call_count >= $main::TESTSUITE->{Stable_Call_Counts} ) {
            #run cli command to upgrade the standby
            $logger->debug(__PACKAGE__ . ".$sub_name: Issuing Upgrade Command : $upgrade_cmd");
            unless ( $self->execSbxCliCmd ( $upgrade_cmd ) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Upgrade Command Unsuccessful");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
			$logger->debug(__PACKAGE__ . " Sleep for 20 seconds for the Standby box to become active");
			sleep 20;
            return 1;
        }else{
            #wait for 60 secs and check the call counts again
            $count += 1;
            $sleep_time += 60;
            $logger->debug(__PACKAGE__ . ".$sub_name: Current CallCounts, Actual: $call_count, Expected: $main::TESTSUITE->{Stable_Call_Counts}");
            last if ($sleep_time > 180);
            $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 60 seconds");
            sleep 60;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Upgrading SBX unsuccessful\n");
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
    return 0;
}

=head2 C< verifyLswuStatus >

=over

=item DESCRIPTION:

 This API internally calls the API, verifyTable() to verify the upgrade status and if not loops till 3 mins max with 60 mins interval for each attempt.  

=item ARGUMENTS:

 Mandatory:
 1. cliHash  

 Optional: 
 2. total waiting time for all the attempts(default is 3 mins)

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail 
    1 - success

=item EXAMPLE:

    my %cliHash = ("secondaryUpgradeStatus" => "upgraded");    	
    unless ( $self->verifyLswuStatus ( %cliHash ) ) {
        $logger->error(__PACKAGE__ . " Failed to upgrade the SBX ");
        return 0;
    }

=back

=cut

sub verifyLswuStatus {

    my $self = shift;
    my $sub_name = "verifyLswuStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    if ($self->{D_SBC}) {
	my %hash = (
			'args' => [@_]
		);
	my $retVal = $self->__dsbcCallback(\&verifyLswuStatus, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
	return $retVal;
    }
    my ($total_waiting_time, %cliHash);
    $total_waiting_time = pop if ($_[-1] =~ /^\d+$/); # if the last argument to method is number then consider it as waiting time :-)
    %cliHash = @_;

    unless ( defined ( keys (%cliHash) ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Input hash not specified");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    
    unless ( $total_waiting_time ) {
	$logger->info(__PACKAGE__ . ".$sub_name: Maximum waiting time for all attempts is not defined!");
	$logger->info(__PACKAGE__ . ".$sub_name: setting the default value as 180 secs");
	$total_waiting_time = 180;
    }

    my $sleep_time = 0;
    my $count = 1;
    my $true = 0;

    while ($sleep_time <= $total_waiting_time) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Verifying the upgrade Status: Attempt-->$count");
	if ( $self->verifyTable("show status system softwareUpgradeStatus", \%cliHash) ) {
            $logger->info(__PACKAGE__ . ".$sub_name: SBX Upgrade Successful");
	    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
	    $true = 1;
	    last;
        } else {
            ############### Waiting for 60 seconds and check the status again ##############
	    $sleep_time += 60;
	    last if ($sleep_time > $total_waiting_time);
            $logger->info(__PACKAGE__ . ".$sub_name: Waiting for 60 seconds");
	    $count += 1;
            sleep 60;
        }
    }
    
    return 1 if ($true);
  
    $logger->info(__PACKAGE__ . ".$sub_name: SBX Still Not Upgraded");
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
    return 0;	
}

=head2 C< commitSoftwareUpgrade >

=over

=item DESCRIPTION:

 This API gets the SBX alias name as input and simply executes the Software upgrade command(request system admin sbx51-10 commitSoftwareUpgrade).

=item ARGUMENTS:

 -SBX Alias Name

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::SBX5000::SBXLSWUHELPER::execSbxCliCmd()

=item OUTPUT:

    0   - fail 
    1 - success

=item EXAMPLE:

    unless ( $self->commitSoftwareUpgrade ( 'sbx51-10' ) ) {
        $logger->error(__PACKAGE__ . " Failed to Commit the Software Upgrade ");
        return 0;
    }

=back

=cut

sub commitSoftwareUpgrade {
    my ($self, $SBX_Alias) = @_;
    my $sub_name = "commitSoftwareUpgrade()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless ( defined ( $SBX_Alias ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: SBX Alias not specified");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    
    my $commitCmd = "request system admin " . $SBX_Alias . " commitSoftwareUpgrade";
   
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing UpgradeCommit Command : $commitCmd"); 
    unless ( $self->execSbxCliCmd($commitCmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Software Upgrade Commit Unsuccessful");
        return 0;
    }
   
    $logger->info(__PACKAGE__ . ".$sub_name: Successfully Committed the Software Upgrade");
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]"); 	
    return 1;
}

=head2 C< switchOverSBX >

=over

=item DESCRIPTION:

 This API gets the SBX alias name as input and simply executes the Software Switch over command(request system admin $system_name switchover).

=item ARGUMENTS:

 -SBX Alias Name

=item PACKAGE:

    SonusQA::SBX5000::SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::SBX5000::SBXLSWUHELPER::execSbxCliCmd()

=item OUTPUT:

    0   - fail
    1 - success

=item EXAMPLE:

    unless ( $self->switchOverSBX ( 'sbx51-10' ) ) {
        $logger->error(__PACKAGE__ . " Failed to Switch Over ");
        return 0;
    }

=back

=cut

sub switchOverSBX {
    my ($self, $sys_name) = @_;
    my $sub_name = "switchOverSBX";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless ( defined ( $sys_name ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: System Name not specified");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    my $switchOver_Cmd = "request system admin " . $sys_name . " switchover";
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing Switch Over Command :$switchOver_Cmd ");
   
    unless ( $self->execSbxCliCmd ($switchOver_Cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: SBX Switch Over Unsuccessful");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Successfully Switched Over to make $sys_name Active!");
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 C< revertLSWU >

=over

=item DESCRIPTION:

 This API gets the SBX alias name as input and executes the LSWU Revert command(request system admin $system_name revertSoftwareUpgrade revertMode normal)


=item ARGUMENTS:

 -SBX Alias Name

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::SBXLSWUHELPER::execSbxCliCmd()

=item OUTPUT:

    0   - fail
    1 - success

=item EXAMPLE:

    unless ( $self->revertLSWU ( 'sbx51-10' ) ) {
        $logger->error(__PACKAGE__ . " Failed to Revert SBX ");
        return 0;
    }

=back

=cut

sub revertLSWU {
    my ($self, $system_name) = @_;
    my $sub_name = "revertLSWU";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless ( defined ( $system_name ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: System Name not specified");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
 
    my $revert_cmd = "request system admin " . $system_name . " revertSoftwareUpgrade revertMode" . " normal" ;
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing Revert Command : $revert_cmd ");

    unless ( $self->execSbxCliCmd ($revert_cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Reverting SBX Unsuccessful");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Successfully Reverted SBX!");
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 C< cleanInstallSBX >

=over

=item DESCRIPTION:

 This API first stops the sbx service in both primary and secondary, then it updates the SBX package from the path /opt/sonus/ after untarring. This API handles incase if the device is singleCE.  

=item ARGUMENTS:

 Mandatory:

    -primarySBX =>
    -secondarySBX =>

 Optional:

    -package =>
    -timeout =>
    -ccHostIp =>
    -ccView =>
    -ccUsername =>
    -ccPassword =>	

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::ATSHELPER::newFromAlias()
	SonusQA::SBX5000::SBXLSWUHELPER::copyFileFromRemoteServerToSBX
	SonusQA::Base::secureCopy
	SonusQA::SBX5000::SBX5000HELPER::_execShellCmd()
	SonusQA::SBX5000::execCmd()
	SonusQA::SBX5000::SBXLSWUHELPER::verifyPrimaryActive

=item OUTPUT:

    0   - fail
    1 - success

=item EXAMPLE:

    unless ( $self->cleanInstallSBX ( 'sbx-V02.00.06-R000.x86_64.tar.gz', '10.6.82.88', '10.6.82.59' ) ) {
        $logger->error(__PACKAGE__ . " Failed to install the required package ");
        return 0;
    }

=back

=cut

sub cleanInstallSBX {
    my ($self,%args) = @_;
    my $sub_name = "cleanInstallSBX";
    my (%a);
    my $cc_copy = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Checking mandatory args;
    if ( defined ( $a{-package} ) ) {
        foreach ( qw/ package primarySBX / ) {
            unless ( defined $a{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
        }
    } 

    if ( defined ( $a{-ccHostIp} ) ) {
        foreach ( qw/ primarySBX ccHostIp ccView ccUsername ccPassword / ) {
            unless ( defined $a{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
    	    $cc_copy = 1;
        }
    }

    my $singleCE = 0;
    unless ( defined ( $a{-secondarySBX} ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Secondary SBX not specified");
        $logger->info(__PACKAGE__ . ".$sub_name: Considering this device as a Single CE system!");
	$singleCE = 1;
    }

    my $sbx_cmd1 = "service sbx stop";
    my $sbx_cmd2 = "cd /opt/sonus/staging";
    my $sbx_cmd4 = "swinfo";
    my $sbx_cmd5 = "service sbx restart";
    my ($cmdStatus , @cmdResult, $Timeout, $sbx_cmd3, $rpm, $primary_cmd1, $shellCmd, $sbxcliobj1, $App_version);

    if ( defined ( $a{-package} ) ) {
        $sbx_cmd3 = "tar -zxvf " . $a{-package};

        $rpm = $a{-package};
        $rpm =~ s/\.gz//;
        $rpm =~ s/\.tar//;
        $rpm = "$rpm" . "\.rpm";
        $logger->info(__PACKAGE__ . ".$sub_name: RPM file-->$rpm");

		if ($a{-sbxInstall} =~ m/yes/i) {
		$primary_cmd1 = "\./sbxInstall.sh -f " . $rpm . " -c /opt/sonus/sbx.conf";
		}else{
        $primary_cmd1 = "\./sbxUpdate\.sh -d -f " . $rpm; 
        }
        $shellCmd = "ls -lrt " . "/opt/sonus/staging/" . $a{-package};

        $sbxcliobj1 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $a{-primarySBX}, -ignore_xml => 0, -sessionlog => 1, -do_not_delete => 1);

        if ( $a{-package} =~ /\S+(V.*-\S+)\.\S+\.tar\.gz/i ) {
            $App_version = $1;
            $App_version =~ s/-//;
        }

        if ($sbxcliobj1->checkVersion($App_version)) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Skipping the installation process since SBX is already running requested Application Version ( $App_version )");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
            return 1;
        }
    }

    # Set default Timeout value of 300 secs i.e. 5 minutes.
    unless ( defined $a{timeout} ) {
         $Timeout = 300;
    }    

    # Create SSH session object to primary SBX using linuxadmin (becoming root) login & port 2024 
    			
    my $SbxObj1 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $a{-primarySBX}, -ignore_xml => 0, -sessionlog => 1, -obj_port => 2024,  -obj_user => 'linuxadmin', -obj_password => 'sonus', -do_not_delete => 1);

    unless (defined $SbxObj1){
        $logger->info(__PACKAGE__ . ".$sub_name: SBX Root object creation unsuccessful");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: SBX Root object creation successful");
    
    if ( $cc_copy ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: copying file from ClearCase server to sbx");
        unless ( SonusQA::SBX5000::SBXLSWUHELPER::copyFileFromRemoteServerToSBX( -ccHostIp   => $a{-ccHostIp},
                                                                                 -ccUsername => $a{-ccUsername},
                                                                                 -ccPassword => $a{-ccPassword},
                                                                                     -ccView => $a{-ccView},
                                                                                    -sbxHost => $a{-primarySBX}
                                                                                       ) ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to copy the package from ClearCase server to SBX!");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }

        unless ($SbxObj1->{conn}->cmd("cp /tmp/$ccPackage /opt/sonus/staging/")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$ccPackage /opt/sonus/staging/\' failed");
    	    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj1->{conn}->errmsg);
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj1->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj1->{sessionLog2}");
            return 0;
        }

        $sbx_cmd3 = "tar -zxvf " . $ccPackage;
        $shellCmd = "ls -lrt " . "/opt/sonus/staging/" . $ccPackage;
        $rpm = $ccPackage;
        $rpm =~ s/\.gz//;
        $rpm =~ s/\.tar//;
        $rpm = "$rpm" . "\.rpm";
        $logger->info(__PACKAGE__ . ".$sub_name: RPM file-->$rpm");
        
		if ($a{-sbxInstall} =~ m/yes/i) {
		$primary_cmd1 = "\./sbxInstall.sh -f " . $rpm . " -c /opt/sonus/sbx.conf";
		}else{
        $primary_cmd1 = "\./sbxUpdate\.sh -d -f " . $rpm; 
        }

    } else {
        my @cmdresults1;
        if ( defined ( $a{-package} ) ) {
            unless ( @cmdresults1 = $SbxObj1->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj1->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj1->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj1->{sessionLog2}");
                return 0;
            }
        }

        foreach ( @cmdresults1 ) {
            if($_ =~ /No such file or directory/i){
                $logger->debug(__PACKAGE__ . ".$sub_name: Package ($a{-package}) not Found in SBX!");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Copying the installation package from ATS server to SBX...");
 	        $logger->debug(__PACKAGE__ . ".$sub_name: Transfering \'$a{-package}\' to Remote server");

	        my $dest_path = "/tmp/";
  	        my $source_file;			  
 
	        if ($a{-package} =~ /sb[cx]-(.*)\.(.*)\.tar.gz/i) {
		    my $temp = $1;
		    $temp =~ s/-//;
		    $source_file = "/sonus/ReleaseEng/Images/SBX5000/" . $temp . "/" . $a{-package};
	        }	
	   
	        unless ($source_file) {
		    $logger->info(__PACKAGE__ . ".$sub_name: Source file not identified!");
		    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
		    return 0;
	        }
	    
	        $logger->info(__PACKAGE__ . ".$sub_name: Source file : $source_file ");
 	        $logger->info(__PACKAGE__ . ".$sub_name: destination path : $dest_path ");
		
		my %scpArgs;
     		$scpArgs{-hostip} = "$a{-primarySBX}";
     		$scpArgs{-hostuser} = 'linuxadmin';
     		$scpArgs{-hostpasswd} = 'sonus';
     		$scpArgs{-scpPort} = '2024';
     		$scpArgs{-sourceFilePath} = $source_file; 
     		$scpArgs{-destinationFilePath} = $scpArgs{-hostip}.'-1:'.$dest_path;

		unless(&SonusQA::Base::secureCopy(%scpArgs)) {
                        $logger->info(__PACKAGE__ . ".$sub_name:  copying package to remote server Failed");
                        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                        return 0;
                }
 
 	        # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens
                unless ($SbxObj1->{conn}->cmd("cp /tmp/$a{-package} /opt/sonus/staging/")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$a{-package} /opt/sonus/staging/\' failed");
            	    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj1->{conn}->errmsg);
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj1->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj1->{sessionLog2}");
                    return 0;
                }

	    }else{
                $logger->info(__PACKAGE__ . ".$sub_name: Package  ($a{-package}) exists! ");
            }
        }      	
    }

    my (@cmdresults2);
    unless ( @cmdresults2 = $SbxObj1->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
        $logger->info(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj1->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj1->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj1->{sessionLog2}");
        return 0;
    }

    foreach ( @cmdresults2 ) {
        if($_ =~ /No such file or directory/i){
            $logger->info(__PACKAGE__ . ".$sub_name: package transfer unsuccessful ");
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: Package  ($a{-package}) exists! ");
            $logger->info(__PACKAGE__ . ".$sub_name: File transfer successful");
        }
    }
	    	
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_cmd1");
    unless ( ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj1, $sbx_cmd1, $Timeout )) {
        $logger->info(__PACKAGE__ . ".$sub_name: cannot issue shell command : $sbx_cmd1");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_cmd2");
    my @cmdResult1 = $SbxObj1->{conn}->cmd(
                                        String  => $sbx_cmd2,
                                        Timeout => $Timeout,
                                      );

    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_cmd3");    
    my @cmdResult2 = $SbxObj1->{conn}->cmd(
                                        String  => $sbx_cmd3,
                                        Timeout => $Timeout,
                                      );

    my $SbxObj2;
    #upgrade the primary server after stopping both the servers if any

    unless ($singleCE) { 
        # Create SSH session object to Secondary SBX using linuxdmin (becoming root) login & port 2024 
       
	$SbxObj2 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $a{-secondarySBX}, -ignore_xml => 0, -sessionlog => 1, -obj_port => 2024, -obj_user => 'linuxadmin', -obj_password => 'sonus', -do_not_delete => 1);
		
        unless (defined $SbxObj2){
            $logger->info(__PACKAGE__ . ".$sub_name: SBX Root object creation unsuccessful");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: SBX Root object creation successful");

        if ( $cc_copy ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: copying file from ClearCase server to sbx");
            unless ( SonusQA::SBX5000::SBXLSWUHELPER::copyFileFromRemoteServerToSBX( -ccHostIp   => $a{-ccHostIp},
                                                                                     -ccUsername => $a{-ccUsername},
                                                                                     -ccPassword => $a{-ccPassword},
                                                                                         -ccView => $a{-ccView},
											-sbxHost => $a{-secondarySBX}			
                                                                                           ) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Failed to copy the package from ClearCase server to SBX!");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                return 0;
            }

            unless ($SbxObj2->{conn}->cmd("cp /tmp/$ccPackage /opt/sonus/staging/")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$ccPackage /opt/sonus/staging/\' failed");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj2->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj2->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj2->{sessionLog2}");
                return 0;
            }
        }else{       
            my @cmdresults3;
            unless ( @cmdresults3 = $SbxObj2->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj2->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj2->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj2->{sessionLog2}");
                return 0;
            }

            foreach ( @cmdresults3 ) {
                if($_ =~ /No such file or directory/i){
                    $logger->debug(__PACKAGE__ . ".$sub_name: Package ($a{-package}) not Found! ");
   	    	    $logger->debug(__PACKAGE__ . ".$sub_name: Copying the installation package from ATS server to SBX...");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Transfering \'$a{-package}\' to Remote server");

                    my $dest_path = "/tmp/";
	    	    my $source_file;

   		    if ($a{-package} =~ /sb[cx]-(.*)\.(.*)\.tar.gz/i) {
		        my $temp = $1;
                        $temp =~ s/-//;
                        $source_file = "/sonus/ReleaseEng/Images/SBX5000/" . $temp . "/" . $a{-package};        
                    }    

                    unless ($source_file) {
                        $logger->info(__PACKAGE__ . ".$sub_name: Source file not identified!");
                        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                        return 0;
                    }

                    $logger->info(__PACKAGE__ . ".$sub_name: Source file : $source_file ");
                    $logger->info(__PACKAGE__ . ".$sub_name: destination path : $dest_path ");
                    # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens

		    my %scpArgs;
                    $scpArgs{-hostip} = "$a{-secondarySBX}";
                    $scpArgs{-hostuser} = 'linuxadmin';
                    $scpArgs{-hostpasswd} = 'sonus';
                    $scpArgs{-scpPort} = '2024';
                    $scpArgs{-sourceFilePath} = $source_file;
                    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.'-1:'.$dest_path;
		    unless(&SonusQA::Base::secureCopy(%scpArgs)) {
                       $logger->info(__PACKAGE__ . ".$sub_name:  copying package to remote server Failed");
                       $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                       return 0;
                    }
                    unless ($SbxObj2->{conn}->cmd("cp /tmp/$a{-package} /opt/sonus/staging/")) {
                        $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$a{-package} /opt/sonus/staging/\' failed");
                	$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj2->{conn}->errmsg);
        	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj2->{sessionLog1}");
	                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj2->{sessionLog2}");
                        return 0;
                    }
		}else{
	            $logger->info(__PACKAGE__ . ".$sub_name: Package  ($a{-package}) exists! ");
                }
            }
        }
             
        my @cmdresults4; 
        unless ( @cmdresults4 = $SbxObj1->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
            $logger->info(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $SbxObj1->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $SbxObj1->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $SbxObj1->{sessionLog2}");
            return 0;
        }

        foreach ( @cmdresults4 ) {
            if($_ =~ /No such file or directory/i){
                $logger->info(__PACKAGE__ . ".$sub_name: Transferring the package (a{-package}) unsuccessful ");
                return 0;
            }else{
                $logger->info(__PACKAGE__ . ".$sub_name: Package  ($a{-package}) exists! ");
                $logger->info(__PACKAGE__ . ".$sub_name: File($a{-package}) transfer successful");
            }
        }

        unless ( ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj2, $sbx_cmd1, $Timeout )) {
            $logger->info(__PACKAGE__ . ".$sub_name: cannot issue shell command : $sbx_cmd1");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
            return 0;
        }	

	$logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_cmd2");	
        my @cmdResult1 = $SbxObj2->{conn}->cmd(
                                        String  => $sbx_cmd2,
                                        Timeout => $Timeout,
                                              );

	$logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_cmd3");
        my @cmdResult2 = $SbxObj2->{conn}->cmd(
                                        String  => $sbx_cmd3,
                                        Timeout => $Timeout,
                                              );

    }

    #At this point both the servers are stopped  
    #upgrading the CEs
	
    $logger->debug(__PACKAGE__ . ".$sub_name: upgrading the primary server....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $primary_cmd1");    

    unless ( ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj1, $primary_cmd1, $Timeout )) {
        $logger->info(__PACKAGE__ . ".$sub_name: cannot issue shell command : $primary_cmd1");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: successfully executed shell command: $primary_cmd1 on SBX server");
		
    unless ($singleCE) {
        unless ( ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj2, $primary_cmd1, $Timeout )) {
            $logger->info(__PACKAGE__ . ".$sub_name: cannot issue shell command : $primary_cmd1");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: successfully executed shell command: $primary_cmd1 on Secondary server");
	
	if ($a{-sbxInstall} =~ m/yes/i) {
		# Make sure the SBX application is started
		$logger->info(__PACKAGE__ . ".$sub_name: Start the SBX to make sure it is running after the base package installation");
		my $sbx_start = "service sbx start";
		$logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_start in Primary SBX ");
                ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj1, $sbx_start );  #TOOLS - 13145
                unless ( $cmdStatus ) {
                    $logger->error(__PACKAGE__ . ".$sub_name: cannot issue shell command in primary SBX : $sbx_start");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
                    return 0;
                }
		$logger->debug(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $sbx_start in secondary SBX ");
                ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj2, $sbx_start, $Timeout );  #TOOLS - 13145
                unless($cmdStatus) {
                    $logger->error(__PACKAGE__ . ".$sub_name: cannot issue shell command in secondary SBX : $primary_cmd1");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
                    return 0;
                }

        $logger->info(__PACKAGE__ . ".$sub_name: sleeping for 180 seconds...");
		sleep 180;
	  }else{
        $logger->info(__PACKAGE__ . ".$sub_name: sleeping for 60 seconds...");
		sleep 60;
	 }
        my $primary_active;
        $primary_active = $SbxObj1->verifyPrimaryActive($a{-primarySBX}); 
    
        unless ( $primary_active ) {
            # Primary is inactive, so restarting secondary so that primary SBX comes up
            $logger->info(__PACKAGE__ . ".$sub_name: Primary is inactive, so restarting secondary to bring up primary!"); 		
        
   	    ($cmdStatus , @cmdResult) =  SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($SbxObj2, $sbx_cmd5, $Timeout );  #TOOLS - 13145
            unless ( $cmdStatus) {
	        $logger->info(__PACKAGE__ . ".$sub_name: restarting secondary SBX failed!");   
  	        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
	        return 0;
 	    }		
	    $logger->info(__PACKAGE__ . ".$sub_name: Successfully restarted Secondary SBX...");
        }else{
   	    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
            return 1;
        }
	
        unless ($SbxObj1->verifyPrimaryActive($a{-primarySBX})) {
            $logger->info(__PACKAGE__ . ".$sub_name: Primary SBX status is inactive even after restarting secondary");   
 	    return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: primary SBX is currently active!");
    }else{
        $logger->info(__PACKAGE__ . ".$sub_name: Skikking secondary upgrade process as the SBX is single CE");
    }
	
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub[1]");
    return 1;	
}

=head2 C< checkVersion >

=over

=item DESCRIPTION:

    This API executes the cli command(show status system serverStatus) and verifies whether the input version is same as the cli output. This API handles for both single as well as dual CEs.

=item ARGUMENTS:

    - version to be matched (if passed as 1, will just return the Application version name)    

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail 
    1 - success

=item EXAMPLE:

    unless ( $self->checkVersion('V02.00.06R001') ) {
        $logger->error(__PACKAGE__ . " Failed to check vrsion ");
        return 0;
    }

=back

=cut


sub checkVersion {
    my ($self, $version) = @_;
    my $sub_name = "checkVersion()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless ( defined ($version) ) {
	$logger->info(__PACKAGE__ . ".$sub_name: version not specified!");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    #checking if D_SBC,
    #execute only for S_SBC as version will be same for each type of SBC
    #to check the version for different personality of SBC, the subroutine will be called using appropriate object
    if ($self->{D_SBC}) {
	my $sbc_type = (exists $self->{I_SBC}) ? 'I_SBC' : 'S_SBC';
        $self = $self->{$sbc_type}->{1};
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type)");
    }

    my $skip_version_check = 1 if ($version == 1);

    my $cmd = "show status system serverStatus";
    unless ($self->execCliCmd($cmd)) {
        $logger->info(__PACKAGE__ . ".$sub_name: command execution failed");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    my $match;
    foreach (@{$self->{CMDRESULTS}}) {
        if ($_ =~ /^\s+applicationVersion\s+(.*)\;$/i) {
            $logger->info(__PACKAGE__ . ".$sub_name: Successfully retrieved the Hardware Type : $1");
	    $match = $1;
	    $logger->info(__PACKAGE__ . ".$sub_name: Current Application Version : $match");
	    last if ($skip_version_check);
	    unless ($match =~ /$version/i) {
		$logger->info(__PACKAGE__ . ".$sub_name: Did not match Application version Expected: $version Actual: $match");
		$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
		return 0;
	    }else{
		$logger->info(__PACKAGE__ . ".$sub_name: Matched Application version Expected: $version Actual: $match");
	    }
        }
    }

    return $match if ($skip_version_check);

    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 C< connectTOActive >

=over

=item DESCRIPTION:

    This subroutines takes an array of Device CEs and tries to connect to each alternately in order to find any connection to the system. The idea is to try and find the connection to the CLI. The IP address information is taken from TMS, so each entry in the array should be a tms alias. The login user and password are also taken from TMS as this function uses newFromAlias to handle the connection and resolution of the tms alias.

=item ARGUMENTS:

    -devices    - An array of tms aliases. The array should ideally represent a single or dual CE.
    -debug      - Should you want to enable session logs, use this flag.
    -timeToWaitForConn - optional time in seconds to keep retrying if connect attempts to both CEs fail. Will retry every 5 seconds during this time. By default will not retry.

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::ATSHELPER::newFromAlias

=item OUTPUT:

    0      - fail
    $obj   - on success the reference to the connection object is returned

=item EXAMPLE:

    unless ( my $cli_session = SonusQA::SBX5000::SBXLSWUHELPER::connectTOActive( -devices => ["asterix", "obelix"], -debug => 1 )) {
        $logger->debug(__PACKAGE__ . " ======: Could not open session object ");
        return 0;
    }

=back

=cut

sub connectTOActive {

    my %args = @_;

    my @device_list = @{ $args{ -devices } } if defined $args{ -devices };
    my $debug_flag  = $args{ -debug   };
    my $user        = $args{ -user   } || "admin";
    my $timeout;

    my $sub_name = "connectTOActive";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{-ha_setup} ||= 0;

    # Check if $ats_obj_type is defined and not blank
    unless ( $#device_list >= 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Error with array -devices:\n@device_list" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ( defined ( $args{-debug} ) && $args{-debug}) {#Removed '== 1' check, because we support 'strings' also as the input to session log
        $debug_flag = $args{-debug};
    }
    else {
        $debug_flag = 1;
    }

    if ( defined ( $args{-defaulttimeout} ) ) {
       $timeout = $args{-defaulttimeout};
    } else {
       $timeout = 60;
    }


    my $connAttempts = 1;  # default number of connection attempts
    my $retryInterval = 5;

    if ( defined $args{-timeToWaitForConn}) {
        # convert time in seconds to number of attempts required
        if ($args{-timeToWaitForConn} >= $retryInterval) {
            $connAttempts = int($args{-timeToWaitForConn} / $retryInterval);
        }
    }
    my $attempts_remaining = $connAttempts;
    while ( $connAttempts > 0 ) {
        foreach my $device ( @device_list ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Attempting connection to $device.");
            $args{-obj_hostname} = $device;
            $args{-tms_alias} = $device;
            $args{-return_on_fail} = 1;
            $args{-sessionlog} = $debug_flag;
            $args{-ha_alias} = \@device_list;
            $args{-defaulttimeout} = $timeout;
            if ( my $connection = SonusQA::ATSHELPER::newFromAlias(
                                                         %args
                                                                      ) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $device successful.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [obj:$device]");
                return $connection;
            } else {
                $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $device failed.");
            }
        } 

        last if ( $attempts_remaining == 0 ); 
        $logger->error(__PACKAGE__ . ".$sub_name:  Waiting $retryInterval seconds before retrying connection attempt -- Attempts remaining = $attempts_remaining ");
        sleep $retryInterval;
	$attempts_remaining--;
    }

    $logger->error(__PACKAGE__ . ".$sub_name:  Connection attempt to all hosts failed.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
    return 0;
}

=head2 C< checkTargetPackage >

=over

=item DESCRIPTION:

 This API checks if the target packages exist in both the CEs. If they do not exist then this API will copy them from the local ATS to the SBCs.
 This API requires root login for both the SBCs and assumes that root login has been enabled with password as 'sonus1'. 'linuxadmin' login does not have permission to write in the following path : /opt/sonus/external

=item ARGUMENTS:

 Mandatory:

    -package

 Optional:

    NONE

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::Base::secureCopy()

=item OUTPUT:

    0   - fail
    1 - success

=item EXAMPLE:

    unless ( $self->checkTargetPackage ( "sbx-V02.00.06-R000.x86_64.tar.gz" ) ) {
        $logger->error(__PACKAGE__ . " Failed to check for the required package ");
        return 0;
    }

=back

=cut

sub checkTargetPackage {

    my $self = shift;
    my $sub_name = "checkTargetPackage";
    my (%a);
    my $Timeout = 60;
    my $copyfromserver = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub->");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&checkTargetPackage, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }
    my $package = shift;
    my ( %args ) = @_;

    while ( my ($key, $value) = each %args ) { $a{$key} = $value;}

    # Checking mandatory args;
    unless ( defined ( $package ) ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
    }

    if ( defined ( $a{-copyfromserver} ) ) {
        $copyfromserver = 1 if ( $a{-copyfromserver} == 1 );
    }

    foreach my $ce (@{$self->{ROOT_OBJS}}){
    my @shCmd = ("ls -lrt " . "/opt/sonus/external/" . $package, "ls -lrt " . "/opt/sonus/external/" .  $package);
    $shCmd[1] =~ s/\.tar\.gz/\.md5/;
    foreach my $shellCmd (@shCmd) {
        my @cmdresults1;
        if ( defined ( $package ) ) {
            unless ( @cmdresults1 = $self->{$ce}->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
    		$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
		$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                return 0;
            }
        }
        my $pkg = $package;
        my $source_file;
        if ($package =~ /sb[cx]-(.*)\.(.*)\.tar.gz/i) {
           my $temp = $1;
           $temp =~ s/-//;
           $pkg =~ s/\.tar\.gz/\.md5/ if ($shellCmd =~ m/\.md5/i);
           $source_file = "/sonus/ReleaseEng/Images/SBX5000/" . $temp . "/" . $pkg;
        }

        foreach ( @cmdresults1 ) {
            if($_ =~ /No such file or directory/i){
                $logger->debug(__PACKAGE__ . ".$sub_name: Package ($pkg) not found in SBX - ($self->{OBJ_HOSTNAME}) Path: /opt/sonus/external/");
                return 0 if($copyfromserver == 0);
                if($copyfromserver == 1){
                    $logger->debug(__PACKAGE__ . ".$sub_name: Copying the installation package from ATS server to SBX...");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Transfering package to Remote server");

                    my $dest_path = "/tmp/";

                    unless ($source_file) {
                        $logger->info(__PACKAGE__ . ".$sub_name: Source file not identified!");
                        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                        return 0;
                    }

                    $logger->info(__PACKAGE__ . ".$sub_name: Source file : $source_file ");
                    $logger->info(__PACKAGE__ . ".$sub_name: destination path : $dest_path ");
                    # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens

		    my %scpArgs;
                    $scpArgs{-hostip} = "$self->{$ce}->{OBJ_HOST}";
                    $scpArgs{-hostuser} = 'linuxadmin';
                    $scpArgs{-hostpasswd} = 'sonus';
                    $scpArgs{-scpPort} = '2024';
                    $scpArgs{-sourceFilePath} = $source_file;
                    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$dest_path;
		    unless(&SonusQA::Base::secureCopy(%scpArgs)){
                            $logger->info(__PACKAGE__ . ".$sub_name:  copying package ($pkg) to remote server Failed");
                            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                            return 0;
                    }
                    unless ($self->{$ce}->{conn}->cmd("cp /tmp/$pkg /opt/sonus/external/")) {
                        $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$pkg /opt/sonus/external/\' failed");
                	$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
        	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                        return 0;
                    }
                    my (@cmdresults2);
                    unless ( @cmdresults2 = $self->{$ce}->{conn}->cmd(String  => $shellCmd, Timeout => $Timeout) ) {
                        $logger->info(__PACKAGE__ . ".$sub_name: Error : cmd unsuccessful $shellCmd");
                	$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
        	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                        return 0;
                    }

                    foreach ( @cmdresults2 ) {
                        if($_ =~ /No such file or directory/i){
                            $logger->info(__PACKAGE__ . ".$sub_name: package transfer ($pkg) unsuccessful ");
                            return 0;
                        } else{
                            $logger->info(__PACKAGE__ . ".$sub_name: File transfer to SBX($self->{OBJ_HOSTNAME}) successful");
                        }
                    }
                }
                } else{
                    $logger->info(__PACKAGE__ . ".$sub_name: Package ($pkg) exists in SBX($self->{OBJ_HOSTNAME}) Path: /opt/sonus/external/ ");
                }
            }
        }
    }
    return 1;
}

=head2 C< verifyPrimaryActive >

=over

=item DESCRIPTION:

    This subroutine takes primary sbx alias name as argument and verifies whether the primary SBX passed is currently active.

=item ARGUMENTS:

    -sbx alias name

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1	   - success

=item EXAMPLE:

    unless ( $output = SonusQA::SBX5000::SBXLSWUHELPER::verifyPrimaryActive( "sbx48" )) {
        $logger->debug(__PACKAGE__ . " ======: Could not verify the status");
        return 0;
    }

=back

=cut

sub verifyPrimaryActive {
    my ($self) = shift;
    my $sub_name = "verifyPrimaryActive()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name Entered-");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&verifyPrimaryActive, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }
    my ($primarySBX) = @_;
    unless ( $primarySBX ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: SBX Alias name not specified!");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    	
    my $sbx_cmd = "swinfo";
    my $Timeout = 30;
    my @cmdResults1; 

    #TOOLS-15088 - to reconnect to standby before executing command
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Issuing \'swinfo\' command to check whether primary is active");
    if ($self->{conn}->last_prompt =~ m/root/) {
        $logger->debug(__PACKAGE__ . ".$sub_name: already in root mode");
        @cmdResults1 = $self->{conn}->cmd(
                                          String  => $sbx_cmd,
                                          Timeout => $Timeout,
                                               );   
        $logger->debug(__PACKAGE__ . ".$sub_name:command executed in the root mode which was already set ");
    }else{
        @cmdResults1 = $self->{$self->{ACTIVE_CE}}->{conn}->cmd(
                                                               String  => $sbx_cmd,
                                                               Timeout => $Timeout,
                                                                    );
         $logger->info(__PACKAGE__ . ".$sub_name: Issuing Command after setting the root mode");
    }

    my $Inst_host_active = 0; 
    my $primary_inactive = 0;
	
    foreach (@cmdResults1) {															
        if ( $_ =~ /^Installed\s+host\s+role\:\s+(\S+)$/i ) {
 	    if ( $1 =~ /active/i ) {
                $Inst_host_active = 1;
		$logger->info(__PACKAGE__ . ".$sub_name: Installed Host role is active for primary");		
		next;
            }else{
                $logger->info(__PACKAGE__ . ".$sub_name: Installed Host role is currently inactive in primary!"); 	
		return 0;
            }				
	}
	if ( $Inst_host_active ) {
	    if ( $_ =~ /^Current\s+host\s+role\:\s+(\S+)$/i ) {
  	        if ( $1 =~ /active/i ) {
		    $logger->info(__PACKAGE__ . ".$sub_name: Current Host role is also active for primary");	    
		    $logger->info(__PACKAGE__ . ".$sub_name: Primary is currently active!");	
		    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
		    return 1;
		}else{
		    $logger->info(__PACKAGE__ . ".$sub_name: Current Host role is currently inactive in primary!");
		    return 0;
		}
	    }
	}
    }
	
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
    return 0;
}

=head2 C< copyFileFromRemoteServerToSBX >

=over

=item DESCRIPTION:

    This subroutine the logs in to the clearcase machine and copies the package from the CC machine to the SBX server using SCP.

=item ARGUMENTS:

 Mandatory:

        ccHostIp   -  Ip of the clearcase machine
	ccUsername -  username for the clearcase machine 
	ccPassword -  password for the clearcase machine	
	ccView     -  view of the machine from where the installation package is available
	sbxHost    -  hostname of the SBX machine to which the package is copied

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    ccPackage - package name available in the clearcase machine

=item EXTERNAL FUNCTIONS USED:

	SonusQA::Base::new()

=item OUTPUT:

    0      - fail
    1      - success

=item EXAMPLE:

    SonusQA::SBX5000::SBXLSWUHELPER::copyFileFromRemoteServerToATS( -ccHostIp   => "10.6.40.63",
                                                                    -ccUsername => "autouser",
                                                                    -ccPassword => "autouser",
                                                                    -ccView     => "release.sbx5000_V03.00.00A054",
                                                                    -sbxHost    => "SBX48",
    		                                                           );

=back

=cut

sub copyFileFromRemoteServerToSBX {
    my ( %args ) = @_;
    my $sub_name = "copyFileFromRemoteServerToSBX()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name Entered-");
    my %a;
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # checking for mandatory parameters
    foreach ( qw/ ccHostIp ccUsername ccPassword ccView sbxHost/ ) {
        unless ( defined $a{-$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
            return 0;
        }
    }

    # Creating a telnet session to clearcase server
    my $ssh_session = new SonusQA::Base(           -obj_host       => $a{-ccHostIp},
                                                   -obj_user       => $a{-ccUsername},
                                                   -obj_password   => $a{-ccPassword},
                                                   -comm_type      => 'SSH',
						   -prompt         => '/.*[\$#%>\}]\s*$/',
                                                   -obj_port       => 22,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

    unless ( $ssh_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to clearcase server");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    unless ( $ssh_session->{conn}->cmd( String  => "sv -f $a{-ccView}",
					Timeout => "60",
					) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter the ccView");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $ssh_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    sleep 5;

    $ssh_session->{conn}->cmd("bash");
    if ( defined $a{-completeBuild} ) {
        my @buildSummary = $ssh_session->{conn}->cmd("cat /software/src/orca/mkSummary.out");
        my $err_Line = '';
        $logger->info(__PACKAGE__ . ".$sub_name: The build log summary details: @buildSummary ");
        foreach my $line( @buildSummary ) {
            if ($line =~ m/cannot open/){
                $logger->debug(__PACKAGE__ . ".$sub_name: Package not Built and Ready! ");
                return 2;
            }
            elsif($line =~ m/Errors:/){
                $err_Line = $line;
                last;
            }
        }

        $err_Line =~ s/\s//g;
        my @err_count = split(":", $err_Line);
        if ($err_count[1] >= 1){
            $logger->debug(__PACKAGE__ . ".$sub_name: $err_count[1] Errors found and reported in the build \n");
            return 2;
        }
    }

    my @files = ();
    unless ( defined $a{-completeBuild} ) {
        my $cmd1 = '/bin/ls /software/src/orca/rel/*sb[cx]*tar.gz';
        my @cmdresults = $ssh_session->{conn}->cmd("$cmd1");

        if ($cmdresults[0] =~ /(\S+)\s+/i) {
           $ccPackage = $1;
        }
        if ( $cmdresults[0] =~ /\/software\/src\/orca\/rel\/(\S+\.tar\.gz)\s+/i ) {
           $ccPackage = $1;
        }
        @files = ($ccPackage);
        $logger->info(__PACKAGE__ . ".$sub_name: Package to be copied: $ccPackage");
    } else {
        foreach ('sb[cx]*tar.gz', 'sb[cx]*.md5', 'sonusdb*.rpm', 'sonusdb*.md5', 'appInstall*.sh') {
	   #redirecting error messages to /dev/null. So that it won't affect the output checking
           my @cmdresults = $ssh_session->{conn}->cmd("/bin/ls -1 /software/src/orca/rel/$_ 2> /dev/null");
           chomp @cmdresults;
           if ( $cmdresults[0] =~ /\/software\/src\/orca\/rel\/(\S+)\s*/i) {
                push (@files, $1);
           } else {
                $logger->error(__PACKAGE__ . ".$sub_name: unable find the $_ int /software/src/orca/rel/");
                return 0;
           }
        }
    }
           
    foreach (@files) {
        my $cp_cmd = "scp -P 2024 " . "/software/src/orca/rel/" . $_ . " linuxadmin\@" . $a{-sbxHost} . ( $a{-sbxHost} =~ /^(\d+\.|\w+\:)/ ? ":/tmp/" : "-1:/tmp/");
        unless ( $ssh_session->{conn}->print($cp_cmd) ) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command : $cp_cmd");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: Executed : $cp_cmd");

        my ($prematch, $match);

        unless ( ($prematch, $match) = $ssh_session->{conn}->waitfor(
                                                               -match     => '/yes[\/,]no/',
                                                               -match     => '/password\:/',
                                                               -match     => '/\[error\]/',
                                                             )) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after issuing SCP command");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/error/ ) {
            $logger->info(__PACKAGE__ . ".$sub_name:  Command resulted in error\n$prematch\n$match");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        my ($prematch1, $match1);
        if ( $match =~ m/yes[\/,]no/ ) {
            $logger->info(__PACKAGE__ . ".$sub_name: Matched 'yes/no' prompt ");
            $logger->info(__PACKAGE__ . ".$sub_name: Entering 'yes'");

            unless ( $ssh_session->{conn}->print( "yes" ) ) {
                $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command :\"yes\" ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            unless ( ($prematch1, $match1) = $ssh_session->{conn}->waitfor(
                                                               -match     => '/password\:/',
                                                               -match     => '/\[error\]/',
                                                              )) {
                $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \"yes\" ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }

        if ( ($match =~ /password\:/i) or ($match1 =~ /password\:/i) ) {
            $logger->info(__PACKAGE__ . ".$sub_name: Matched 'password' prompt ");
            $logger->info(__PACKAGE__ . ".$sub_name: Entering password");
            unless ( $ssh_session->{conn}->cmd( String   => "sonus",
                                                Timeout  => 100,		
                                              ) ) {
                $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the password:\"sonus\" ");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $ssh_session->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $ssh_session->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $ssh_session->{sessionLog2}");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
	
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: didnot get the required prompt");
            $logger->info(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
            return 0;
        }
    }
	
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}
 
=head2 makeReconnection 

=over

=item DESCRIPTION:

    This method will make cli reconnection(Active CE incase of HA setup)

=item ARGUMENTS:

    Mandatory:
        NA

    Optional:
       -iptype            => type of ip to use,  V4, V6 or any. If passed any values other than V4 or V6, will use both.
       -timeToWaitForConn => time to wait for connection, based up on this value number of reattempt is calculated
       -retry_timeout    => maximum time to try reconnection (all attempts)
       -retryInterval    => retry interval, which definds the number of attempts, sleep between each attempt

       -logicalIP        => which logical ip need to use for connect, 1 or 2. We use both 1 and 2, if any other value passed. If it passed will get the ip from 'LOGICAL_IP' attribute.
           or
       -mgmtnif         => which mgmt ip need to use for connect, 1 or 2.  We use both 1 and 2, if any other value passed. If it passed will get the ip from 'MGMTNIF' attribute. It is the default value.

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::reconnect()


=item OUTPUT:

        1      - if success
        0      - if failure.

=item EXAMPLE:

   unless ($self->makeReconnection( )) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to reconnect" );
      return 0;
   } 

   #####################
   # E.G. code for using LOGICAL_IP
   unless ( $sbxObj->makeReconnection(-logicalIP => 1, -timeToWaitForConn => 10, -retry_timeout => 1)){
      $logger->error(__PACKAGE__ . ".$sub:  unable to reconnect" );
      return 0;
   }

=back

=cut

sub makeReconnection {
    my $self = shift;
    my $sub_name = "makeReconnection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        delete $self->{STANDBY_ROOT} if (exists $self->{STANDBY_ROOT});
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&makeReconnection, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }

    my (%args) = @_;
    my @device_list = ();

    # TOOLS-13381. Skip re-connection if the index is NEW_STANDBY_INDEX and also we set REDUNDANCY_ROLE is STANDBY.
    my $sbc_type = $self->{SBC_TYPE};
    if($sbc_type && $self->{PARENT}->{NEW_STANDBY_INDEX}->{$sbc_type} == $self->{INDEX}){
        $self->{'REDUNDANCY_ROLE'} = 'STANDBY';
        $self->{CE1LinuxObj} =  $self->{CE0LinuxObj};
        $logger->info(__PACKAGE__ . ".$sub_name: skipping makeReconnection, since NEW_STANDBY_INDEX == INDEX ($self->{INDEX}) for $sbc_type.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

    # lets do some kung fu to find out who is active at the moment, such that we dont waste much time for CLI reconnection
    if ($self->{HA_SETUP} and ! $self->{PARENT}->{NK_REDUNDANCY}) {
       $logger->debug(__PACKAGE__ . ".$sub_name: sounds like your test is on HA");
       @device_list = @{$self->{HA_ALIAS}};
       my @swinfo;
       unless (@swinfo =  $self->{$self->{ACTIVE_CE}}->{conn}->cmd('swinfo')){
           $logger->warn(__PACKAGE__ . ".$sub_name:  Failed to get 'swinfo' from SBC \'@swinfo\' ");
       }else {
           my @current_role = grep(/Current\s+host\s+role:/i, @swinfo);
           @device_list = reverse @device_list unless ($current_role[0] =~ /active/i); #conside current active first else revese the list
	   $self->{HA_ALIAS} = \@device_list;
       }
    } else {
       @device_list = ($self->{TMS_ALIAS_NAME});
    }

    unless ( $#device_list >= 0 ) {
       $logger->error(__PACKAGE__ . ".$sub_name:  Error with array -devices:\n@device_list" );
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }

    my $connAttempts = 1;  # default number of connection attempts
    my $retryInterval = $args{-retryInterval} || 5;
    $args{-retry_timeout} ||= 60;

    if ( defined $args{-timeToWaitForConn}) {
       $connAttempts = int($args{-timeToWaitForConn} / $retryInterval) if ($args{-timeToWaitForConn} >= $retryInterval);
    }
    my $doNotDelete = $self->{DO_NOT_DELETE};
    $self->{DO_NOT_DELETE} = 1; #Dont delete the Cloud SBC Instance, in case of reconnection
    $self->closeConn();
    $self->{DO_NOT_DELETE} = $doNotDelete;

    my $ip_index;
    my $logicalOrMgmt = 'MGMTNIF'; # Default to old behaviour if no arguments speficified
    if ( defined $args{-logicalIP} and $args{-logicalIP}) {
       $logicalOrMgmt = 'LOGICAL_IP';
       $ip_index = $args{-logicalIP};
    }
    elsif ( defined $args{-mgmtnif} and $args{-mgmtnif}) {
       $logicalOrMgmt = 'MGMTNIF';
       $ip_index = $args{-mgmtnif};
    }elsif ($self->{MGMTNIF}) { #TOOLS-17907
        $ip_index = $self->{MGMTNIF};
    }
    $self->{MGMT_LOGICAL} = $logicalOrMgmt;        #TOOLS - 13882
    $self->{$logicalOrMgmt} = 1;

    my @mgmtNIF = (1,2);
    if ( $ip_index =~ /(1|2)/) {
       $logger->debug(__PACKAGE__ . ".$sub_name: you have wished to make reconnection using $logicalOrMgmt->$1->IP");
       @mgmtNIF = ($1);
       $self->{$logicalOrMgmt} = $1;       #TOOLS -13882
    } 
    else {
       $logger->warn(__PACKAGE__ . ".$sub_name: unknown $logicalOrMgmt value passed, will use default (@mgmtNIF)");
     }

    my @ipType = ('IP', 'IPV6');
    if (defined $args{-iptype} and $args{-iptype}) {
       if ( $args{-iptype} =~ /(V4|V6|any)/i) {
           $logger->debug(__PACKAGE__ . ".$sub_name: you have wished to make reconnection using IP->$1 address");
           #if($1 eq 'any') { @ipType = ('IP', 'IPV6'); } else { @ipType = ($1); }
           @ipType =  ($1 eq 'V4')  ?  'IP': 'IPV6'   unless($1 eq 'any');   # TOOLS - 13404
       } else {
           $logger->warn(__PACKAGE__ . ".$sub_name: unknow iptype value passed, will use default iptype (@ipType)");
       }
    }

    while ( $connAttempts > 0 ) {
       foreach ( @device_list ) {
           my $alias_hashref = $main::TESTBED{$main::TESTBED{$_}.':hash'};

           $self->{OBJ_HOSTS} = [];
           foreach my $ip_type (@ipType) {
               foreach (@mgmtNIF) {
                   push (@{$self->{OBJ_HOSTS}}, $alias_hashref->{$logicalOrMgmt}->{$_}->{$ip_type}) if defined $alias_hashref->{$logicalOrMgmt}->{$_}->{$ip_type};
               }
           }

           unless(@{$self->{OBJ_HOSTS}}){
               $logger->warn(__PACKAGE__ . ".$sub_name: Skipping connection to $_, since couldn't get OBJ_HOSTS");
               next;
           }

           $self->{SYS_HOSTNAME} = $alias_hashref->{CONFIG}->{1}->{HOSTNAME};
           $self->{TMS_ALIAS_DATA} = $alias_hashref;
           $self->{OBJ_HOSTNAME} = $_;
           $self->{TMS_ALIAS_NAME} = $_;
           $self->{ROOT_OBJS} = [];
           $self->{ACTIVE_CE} = '';
           $self->{STAND_BY} = '';
           $self->{CMDRESULTS} = [];
           undef $self->{SCP};
           undef $self->{conn};
           undef $self->{LASTCMD};

           $logger->debug(__PACKAGE__ . ".$sub_name:  Attempting connection to $_.");
           if ( $self->reconnect(-retry_timeout => $args{-retry_timeout}) ) {
               $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $_ successful.");
               @{$self->{HA_ALIAS}} = reverse @device_list  unless ($_ eq $device_list[0]); # holding up the HA_ALIAS array inform of active, standby 
               $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
               return 1; 
           } else {
               $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $_ failed.");
           }
       }

       if ( --$connAttempts > 0) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Waiting $retryInterval seconds before retrying connection attempt -- Attempts remaining = $connAttempts ");
           sleep $retryInterval;
       }
    }

    $logger->error(__PACKAGE__ . ".$sub_name:  Connection attempt to all hosts failed.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
    return 0;
}

=head2 C< allowSsh >

=over

=item DESCRIPTION:

    This function is used to enable ssh(root) access to sbx server 

=item Arguments:

    NONE

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1 - success 
    0 - failure

=item EXAMPLE:

    $obj->allowSsh();

=back

=cut

sub allowSsh {
    my ($self) = shift;
    my $sub_name = "allowSsh";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&allowSsh, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }
    my (%args) = @_; #make it flexible to accept some arguments for future enhancement
    my $cmd1 = "sed -i 's/allowSshAccess=n/allowSshAccess=y/g' /opt/sonus/sbx.conf";
    my $cmd2 = "cp /opt/sonus/debugSonus.key /opt/sonus/debugSonus.key_back";
    my $cmd3 = "echo \"SSH access will remain unchanged\" > /opt/sonus/debugSonus.key";

    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        foreach my $cmd ($cmd1, $cmd2, $cmd3) {
            $self->{$ce}->{conn}->cmd($cmd);#not validating command execution status
            $logger->info(__PACKAGE__ . ".$sub_name: Successfully execute the shell command:$cmd on $ce");
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< dennySsh >

=over

=item DESCRIPTION:

    This function is used to denny ssh(root) access to sbx server 

=item Arguments:

    NONE

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1 - success 
    0 - failure

=item EXAMPLE:

    $obj->dennySsh();

=back

=cut

sub dennySsh {
    my ($self) = shift;
    my $sub_name = "dennySsh";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&dennySsh, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
        return $retVal;
    }

    my (%args) = @_; #make it flexible to accept some arguments for future enhancement
    my $cmd1 = "sed -i 's/allowSshAccess=y/allowSshAccess=n/g' /opt/sonus/sbx.conf";
    my $cmd2 = "cp /opt/sonus/debugSonus.key_back /opt/sonus/debugSonus.key";
    
    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        foreach my $cmd ($cmd1, $cmd2) {            
            $self->{$ce}->{conn}->cmd($cmd); #not validating command execution status
            $logger->info(__PACKAGE__ . ".$sub_name: Successfully execute the shell command:$cmd on $ce");
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< getSwitchOverObject >

=over

=item DESCRIPTION:

    This API is used to get the object for which user has to do swichover (N:1 Scenario).
    We wil decide which object to use based on the following table - 

    If the object from which subroutine is called has - 
    Current Role  |  Installed Role  |  Object
    --------------------------------------------------------
      Active	  |  Stand By	     |  Same Object
		  |  Active 	     |  Same Object

      StandBy	  |  Stand By 	     |  sbc_type->1 Object
		  |  Active	     |  The Object (in DSBC{sbc_type}) 
					for which Installed Role is StandBy

=item ARGUMENTS:

    Mandatory:
        1. Sbc Object

=item PACKAGE:

    SonusQA::SBX5000:SBXLSWUHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    The Objcet on which Switchober should happen

=item EXAMPLE:

    my $self = $self->getSwitchOverObject() if ($self->{REDUNDANCY_ROLE} and $cmd =~ /switchover/);

=back

=cut

sub getSwitchOverObject {
    my ($self) = shift;
    my $sub_name = "getSwitchOverObject";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $object = '';
	my $type = $self->{SBC_TYPE};
    $self->{PARENT}->{NEW_STANDBY_INDEX}->{$type} = 0;
    $logger->debug(__PACKAGE__ . ".$sub_name:The current role is $self->{REDUNDANCY_ROLE}");
    if ($self->{REDUNDANCY_ROLE} =~ /standby/i) {
	$logger->debug(__PACKAGE__ . ".$sub_name: checking the installed role");
	$logger->debug(__PACKAGE__ . ".$sub_name: The installed role is ".$self->{CE0LinuxObj}->{INSTALLED_ROLE});
	if ($self->{CE0LinuxObj}->{INSTALLED_ROLE} =~ /active/i) {
	    $logger->debug(__PACKAGE__ . ".$sub_name: Returning the object for which installed role is StandBy");
	    foreach my $index (keys %{$self->{PARENT}->{$type}}) {
		if ($self->{PARENT}->{$type}->{$index}->{CE0LinuxObj}->{INSTALLED_ROLE} =~ /standby/i) {
		    $logger->debug(__PACKAGE__ . ".$sub_name: Returning the $type -> $index object");
		    $object = $self->{PARENT}->{$type}->{$index};
            # TOOLS-13381. Storing $index as NEW_STANDBY_INDEX, this will be used to skip when we do makeReconnection
            $self->{PARENT}->{NEW_STANDBY_INDEX}->{$type} = $index;
		    last;
		}
	    }
	}
	else {
	    $logger->debug(__PACKAGE__ . ".$sub_name: Returning the $type->1 object");
	    $object = $self->{PARENT}->{$type}->{1};
        # TOOLS-13381. Storing $index as NEW_STANDBY_INDEX, this will be used to skip when we do makeReconnection
        $self->{PARENT}->{NEW_STANDBY_INDEX}->{$type} = 1;
	}
    }
    else {
	$logger->debug(__PACKAGE__ . ".$sub_name: Returning the same object");
	$object = $self;
    # TOOLS-13381. Storing $index as NEW_STANDBY_INDEX, this will be used to skip when we do makeReconnection
    $self->{PARENT}->{NEW_STANDBY_INDEX}->{$type} = $self->{INDEX};
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return $object;
}

1;
