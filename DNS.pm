package SonusQA::DNS;

=head1 NAME

SonusQA::DNS- Perl module for operation on DNS.

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::DNS->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               );

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for DNS.

=head1 METHODS

=over

=cut

use strict;
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use File::Basename;
use Module::Locate qw(locate);
use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);

=item B<doInitialization>

    This subroutine is to set object defaults

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)

    if ($args{-masterPath} and $args{-zonePath}) {
        $self->{MASTERPATH} = $args{-masterPath};
        $self->{ZONEPATH} = $args{-zonePath};
    }
    else {
        $self->{MASTERPATH} = '/var/lib/named/etc/';
        $self->{ZONEPATH} = '/var/lib/named/';
    }
    $self->{ZONEFILE} = [];

    $self->{LOCATION} = locate __PACKAGE__ ;

}

=item B<setSystem>

    This subroutine sets the system information and prompt.

=cut

sub setSystem(){
    my($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    my $sub = "setSystem";
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my($cmd,$prompt, $prevPrompt);
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $self->{conn}->cmd("export PATH=/usr/sbin:\$PATH"); #for non-root user, setting path for rndc
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub: SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".$sub: SET PROMPT TO: " . $self->{conn}->last_prompt);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $self->{conn}->cmd('unalias grep');
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[1]");
    return 1;
}

=item B<addDnsRecord>

    This subroutine add domain and its details to dns configuration.
	     - configure named.conf as required
		 - creates domainName.zone file with passed deatils
		 - runs service named restart
		 - check the named service status and validates
		 - validate the added record status from /var/log/messages

    Arguments:

    Hash with below deatils
          - Manditory
                -domainName   => name of the domain to be added to dns
                -nameServerHost  => nameserver hostname
                -nameServerIp    => name server ip deatils (separated by comma)
				-aRecords    => ip deatils of the domain (separated by comma)
	  -optional
	        -nameServerUser  => username for the nameserver deafult is root
		-extraData    => any extra records can be passsed here, example MX records
                -ttlValue    =>  argument for changing the default value for $TTL, by default value is '1D'
		-nameServerList => extra servers can be passed here
		-zoneFile 	=> zone file name

    Return Value:

    1 - on success
    0 - on failure

    Usage:

    my %args = (-domainName => 'ram.com', 
                -nameServerHost => 'labsip',
                -nameServerIp => 'fc00:0:0:3100:0:0:220:71,10.31.220.71',
                -aRecords =>'10.33.241.1,10.33.241.2,10.33.241.3,10.33.241.4,10.33.241.5,10.33.241.6,10.33.241.7,10.33.241.8,10.33.241.9,10.33.241.10,fc00::3300:0:0:241:2,fc00::3300:0:0:241:3',
                -nameServerUser => 'hostmaster'
		-nameServerList => ["xyz.com", "abc.com", "def.com"]);

    my $result = $Obj->addDnsRecord(%args);
=cut

sub addDnsRecord {
    my($self, %args)=@_;
    my $sub_name = 'addDnsRecord';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    foreach ('-domainName', '-nameServerHost', '-nameServerIp', '-aRecords') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	    $main::failure_msg .= "TOOLS:DNS-Mandatory parameters not passed; ";
            return 0;
        }
    }

    unless ($args{-zoneFile}) {
	my $zoneFile = $args{-domainName};
	$zoneFile =~ s/\.com$//;
	$zoneFile .= '.zone';
	$args{-zoneFile} = $zoneFile;
    }

    push (@{$self->{DOMAIN_NAME}}, "$args{-domainName}");
    push (@{$self->{ZONEFILE}}, "$self->{ZONEPATH}$args{-zoneFile}");

    unless ($self->configureMasterFile(%args)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to make change in Master configuration file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- Master configuration file changes failed; ";
        return 0;
    }

    unless ($self->configureZoneFile(%args)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to create \'$args{-zoneFile}\' file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- Creating file \'$args{-zoneFile}\' failed; ";
        return 0;
    }

    $self->execCmd("rndc reconfig");
    $self->execCmd("rndc reload $args{-domainName}");

    my @status = $self->execCmd('rndc status');

    unless (grep(/server is up and running/i, @status)) {
        $logger->error(__PACKAGE__ . ".$sub_name: server not up after reload");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- DNS Server has not started after reload;";
        return 0;
    }

    sleep(2);
    #TOOLS-20392:replacing tail command with rndc zonestatus
 
    @status = $self->execCmd("rndc zonestatus $args{-domainName}");
    unless(grep /serial:\s+\d+/i ,@status){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to load $args{-domainName}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        $main::failure_msg .= "TOOLS:DNS- Failed to load $args{-domainName} ";
        return 0;
    }


    $logger->info(__PACKAGE__ . ".$sub_name: successfully added DNS record");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    return 1;
}

=item B<configureMasterFile>

    This subroutine add the domain record to master file (named.conf).

    Arguments:

    Hash with below deatils
          - Manditory
                -domainName   => name of the domain to be added to dns
                -zoneFile  => zone file name

    Return Value:

    1 - on success
    0 - on failure

    Usage:

    my %args = (-domainName => 'ram.com', 
                -zoneFile => 'ram.zone');
    my $result = $Obj->configureMasterFile(%args);
=cut

sub configureMasterFile {
    my($self, %args)=@_;
    my $sub_name = 'configureMasterFile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    foreach ('-domainName', '-zoneFile') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	    $main::failure_msg .= "TOOLS:DNS- Mandatory parameters are not passed;";
            return 0;
        }
    }

    unless ($self->{conn}->cmd("cd $self->{MASTERPATH}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to enter into $self->{MASTERPATH} directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- Failed to enter inot $self->{MASTERPATH} directory;";
        return 0;
    }

    $self->{conn}->cmd("/bin/cp named.conf named_back.conf");
    $self->{conn}->cmd("sed -ie \'/zone\\s*\"$args{-domainName}\"/,/^\\s*};/d\' named.conf");

    foreach ("zone \"$args{-domainName}\" IN {", "     type master;", "     allow-query {any;};",  "     file \"$args{-zoneFile}\";", "};") {
        unless ($self->{conn}->cmd("echo \'$_\' >>named.conf")) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed add zone entry in master named.conf");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	    $main::failure_msg .= "TOOLS:DNS- Failed to add Zone Entry in master named.conf file;";
            return 0;
        }
    }

    #TOOLS-6047, copying the file 
    $logger->debug(__PACKAGE__ . ".$sub_name: copying the file");
    if ($self->{MASTERPATH} eq '/var/lib/named/etc/') {
        $self->execCmd("cp named.conf /etc/named.conf");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: successfully added zone entry to named.conf");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    return 1;
}

=item B<configureZoneFile>

    This subroutine created the zone file for the domain using arguments.

    Arguments:

    Hash with below deatils
          - Manditory
                -domainName   => name of the domain to be added to dns
		-zoneFile => zone file name
                -nameServerHost  => nameserver hostname
                -nameServerIp    => name server ip deatils (separated by comma)
                -aRecords    => ip deatils of the domain (separated by comma)
           -optional
                -nameServerUser  => username for the nameserver deafult is root
                -extraData    => any extra records can be passsed here, example MX records 
                -ttlValue    =>  argument for changing the default value for $TTL, by default value is '1D' 

    Return Value:

    1 - on success
    0 - on failure

    Usage:

    my %args = (-domainName => 'ram.com', 
                -nameServerHost => 'labsip',
		-zoneFile => 'ram.zone',
                -nameServerIp => 'fc00:0:0:3100:0:0:220:71,10.31.220.71',
                -aRecords =>'10.33.241.1,10.33.241.2,10.33.241.3,10.33.241.4,10.33.241.5,10.33.241.6,10.33.241.7,10.33.241.8,10.33.241.9,10.33.241.10,fc00::3300:0:0:241:2,fc00::3300:0:0:241:3',
                -nameServerUser => 'hostmaster');
    my $result = $Obj->configureZoneFile(%args);
=cut

sub configureZoneFile {
    my($self, %args)=@_;
    my $sub_name = 'configureZoneFile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    foreach ('-nameServerHost', '-zoneFile', '-domainName', '-aRecords', '-nameServerIp') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	    $main::failure_msg .= "TOOLS:DNS- Mandatory arguements are not passed; ";
            return 0;
        }
    }
    unless ($self->{conn}->cmd("cd $self->{ZONEPATH}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to enter into $self->{ZONEPATH} directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- Failed to enter inot $self->{ZONEPATH} directory;";
        return 0;
    }

    $self->{conn}->cmd("/bin/rm $args{-zoneFile}");

	#checking the status of the command and logging it
	my ($status_code) = $self->{conn}->cmd('echo $?');
	chomp($status_code);
   	unless($status_code == 0){
		$logger->error(__PACKAGE__ . ".$sub_name: failed to execute the command '/bin/rm $args{-zoneFile}'");
   	}

    my @date = $self->execCmd("date +%Y%m%d");
    my @serialNumbes = $self->execCmd("grep -oh \'$date[0]" . '\w*\' *.*');
    @serialNumbes = sort {$b <=> $a} @serialNumbes;

    my $value_ttl ; 
    $value_ttl = (defined $args{-ttlValue}) ? $args{-ttlValue} : '1D' ; 

    my @zoneContent = ("\$TTL $value_ttl", ""); 
    $logger->info(__PACKAGE__ . ".$sub_name: Value for Zone Content : @zoneContent"); 

    $args{-nameServerUser} ||= 'root';
    my $temp = '@ IN SOA ' . "$args{-nameServerHost}.$args{-domainName}.  $args{-nameServerUser}.$args{-domainName}. (";
    push (@zoneContent, $temp);
    ((scalar @serialNumbes) > 0 and $serialNumbes[0] =~ /^\d+$/) ? push (@zoneContent, $serialNumbes[0]+1 . ' ; Serial number (yyyymmdd-num)') : push (@zoneContent, $date[0] . '00 ; Serial number (yyyymmdd-num)');

    push (@zoneContent, '8H ; Refresh', '2M ; Retry', '4W ; Expire', '1D ) ; Minimum', "     IN NS $args{-nameServerHost}");

    foreach(@{$args{-nameServerList}}) {
        push(@zoneContent, "     IN NS $_");
    }
    push(@zoneContent, "");

    my ($index, @ipv4, @ipv6);
    map {( $_ =~ /(\d+\.\d+\.\d+\.\d+)/) ? push(@ipv4, $_) : push(@ipv6, $_)} split (/\,/, $args{-aRecords});

    foreach $index (0..$#ipv4) {
        ($index == 0) ? push(@zoneContent, sprintf( "%-25s %-25s %-25s", 'as.ipv4','A',$ipv4[0])) : push(@zoneContent, sprintf( "%-25s %-25s %-25s", '','A',$ipv4[$index]));
    } 

    push(@zoneContent, "");

    foreach $index (0..$#ipv6) {
        ($index == 0) ? push(@zoneContent, sprintf( "%-25s %-25s %-45s", 'as.ipv6','AAAA',$ipv6[0])) : push(@zoneContent, sprintf( "%-25s %-25s %-40s", '','AAAA',$ipv6[$index]));
    }

    push(@zoneContent, "");
    my @nameServerIp = split(/\,/, $args{-nameServerIp});
    foreach $index (0..$#nameServerIp) {
        $temp = ($nameServerIp[$index] =~ /(\d+\.\d+\.\d+\.\d+)/) ? 'A' : 'AAAA';
        ($index == 0) ? push(@zoneContent, sprintf( "%-25s %-25s %-45s", $args{-nameServerHost},$temp,$nameServerIp[0])) : push(@zoneContent, sprintf( "%-25s %-25s %-45s", "",$temp,$nameServerIp[$index]));
    }

    push(@zoneContent, "");
    $args{-extraData} =~ s/\\,/\|/g;  #TOOLS-4623: if (,) is part of record to be added.  
    my @tmp;
    if (defined $args{-extraData}) {
        map {push(@tmp, $_)} split(/,/, $args{-extraData});
    }

    foreach(@tmp){
       $_ =~ s/\|/\,/g;
       push(@zoneContent, $_);
    }

    push(@zoneContent, "");

    my $ret_val = 1;
    $logger->debug(__PACKAGE__ . ".$sub_name: Writing the zone file");
    foreach (@zoneContent) {
	unless ($self->{conn}->cmd("echo \'$_\' >>$args{-zoneFile}")) {
	    $logger->error(__PACKAGE__ . ".$sub_name: failed to write \'$_\' into  $args{-zoneFile}");
	    $ret_val = 0;
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	    $main::failure_msg .= "TOOLS:DNS- Failed to write \'$_\' into  $args{-zoneFile};";
	    last;
	}
    }

    $logger->info(__PACKAGE__ . ".$sub_name: successfully created $args{-zoneFile}") if ($ret_val);
    $logger->debug(__PACKAGE__ . ".$sub_name: Content of the zone file -- \n". join("\n", @zoneContent));

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$ret_val]");
    return $ret_val;
}

=item B<execCmd>

    This subroutine enables user to execute any command on the DNS server.

    Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

    Return Value:

    Output of the command executed.

    Usage:

    my @results = $obj->execCmd("cat test.txt");
    This would execute the command "cat test.txt" on the session and return the output of the command.

=cut

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
   my(@cmdResults,$timestamp);
   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
   }
   $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
      $main::failure_msg .= "TOOLS:DNS-DNS command error; ";
      return @cmdResults;
   }
   chomp(@cmdResults);
   @cmdResults = grep /\S/, @cmdResults;
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   return @cmdResults;
}

=item B<dropZoneFile>

    This subroutine delete the zone file created.

    Arguments:
    none

    Return Value:

    1 - on success

    Usage:

    $Obj->dropZoneFile();
=cut

sub dropZoneFile {
    my($self, %args)=@_;
    my $sub_name = 'dropZoneFile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    #Fix for TOOLS-5424
    $logger->debug(__PACKAGE__ . ".$sub_name: ZONEFILE: $self->{ZONEFILE}");
    unless($self->{ZONEFILE}){
        $logger->warn(__PACKAGE__ . ".$sub_name: ZONEFILE is not created by this object, so skipping dropping zone file.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
        return 1;
    }

    #removing all the zone files and master file configuration created by the object.
    my $length = @{$self->{ZONEFILE}};
    my $count = 0;
    while ($length != $count) {
	$self->{conn}->cmd("/bin/rm $self->{ZONEFILE}[$count]");
	#checking the status of the command and logging it
        my ($status_code) = $self->{conn}->cmd('echo $?');
        chomp($status_code);
        unless($status_code == 0){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to execute the command '/bin/rm $self->{ZONEFILE}[$count]'");
		$main::failure_msg .= "TOOLS:DNS- Failed to execute command '/bin/rm $self->{ZONEFILE}[$count]'";
        }
	$self->{conn}->cmd("cd $self->{MASTERPATH}");
	$self->{conn}->cmd("sed -ie \'/zone\\s*\"$self->{DOMAIN_NAME}[$count]*\"/,/^\\s*};/d\' named.conf");
	$count++;
    }

    #TOOLS-6047, copying the file
    if ($self->{MASTERPATH} eq '/var/lib/named/etc/') {
        $self->execCmd("cp named.conf /etc/named.conf");
    }

    $self->execCmd('rndc reconfig');

    my @status = $self->execCmd('rndc status');

    unless (grep(/server is up and running/i, @status)) {
        $logger->error(__PACKAGE__ . ".$sub_name: server not up and running after reconfig");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
	$main::failure_msg .= "TOOLS:DNS- Server is not up and running after reconfig; ";
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    return 1;
}



=item B<DESTROY>

  PERL default module method Over-rides.
  Typical inner library usage:

  $obj->DESTROY();

=back

=cut

sub DESTROY{
    my ($self) = @_;
    my $sub = 'DESTROY';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $result = 1;

	unless ($self->dropZoneFile()){
		$logger->warn(__PACKAGE__ . ".DESTROY [$self->dropZoneFile()] dropping of Zone file Unsuccessful");
		$main::failure_msg .= "TOOLS:DNS- [$self->dropZoneFile()] dropping of Zone file Unsuccessful; ";
	}

    $logger->debug(__PACKAGE__ . ".$sub calling closeConn sub to destroy the connection object.");
    $self->closeConn;
    $logger->info(__PACKAGE__ . ".$sub: Leaving Sub [$result]");
    return $result;
}

1;
