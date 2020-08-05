package SonusQA::ROUTER;

=head1 NAME

SonusQA::ROUTER - Perl module for CISCO Router interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $routerObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'CiscoATS', -sessionlog => 1);

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper

=head2 AUTHORS

Naresh Kumar Anthoti <nanthoti@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

   This module provides an interface for Cisco Router. 
   This ATS module can be used to get the information about CpuUtilization percentage, Top 10 Loaded Interfaces, and Memory Utilisation.

=head2 SUB-ROUTINES

=cut

use strict;
use warnings;
use SonusQA::Base;
use SonusQA::Utils;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;

our @ISA = qw(SonusQA::Base);

=pod

=head3 SonusQA::ROUTER::doInitialization()

    This function is internally called during the object creation ie. from Base.pm and sets the default parameters as defined herein.

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub_name = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name");
    $logger->debug(__PACKAGE__ . ".Entered $sub_name");
    $self->{COMMTYPES} = ["TELNET"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]]\s?$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[1]");
}

=pod

=head3 SonusQA::ROUTER::setSystem() 

    This function sets the system information and Prompt.
=back

=cut

sub setSystem(){
    my($self)=@_;
    
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name");
    $logger->debug(__PACKAGE__ . ".Entered $sub_name");
    my($cmd,$prompt, $prevPrompt);
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ". $sub_name SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd(" ");
    $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[1]");
    return 1;
}

=pod

=head3 SonusQA::ROUTER::getCpuUtilization()

 DESCRIPTION:

 The function returns the CPU load percentage.

=over

=item EXAMPLE(s):
 my $cpuUtil = $ciscoRouter->getCpuUtilization();

=back

=cut

sub getCpuUtilization{
    my $self = shift;
    my $sub_name = "getCpuUtilization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".Entered $sub_name");
    my $cmd = "show processes cpu sorted";
    my (@cpuProcesses,$prematch, $match,$cpuUtil);
    unless($self->{conn}->print($cmd)){
        $logger->debug(__PACKAGE__ . " $cmd failed : ". $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    while(1){
        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                       -match     => '/ --More-- /i',
                                                       -match     => $self->{PROMPT},
                                                      )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \'$cmd\'.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        chomp $prematch;
        push @cpuProcesses,split /\n/,$prematch;
        last if($match !~ / --More-- /i);
        unless($self->{conn}->print("")){
            $logger->debug(__PACKAGE__ . " $cmd failed : ". $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[0]");
            return 0;
        }
    }
    
    foreach(@cpuProcesses){
        if($_ =~ /five minutes:\s+(\d+)\%/){
	    $logger->debug(__PACKAGE__ . "cpu Utilisation percentage $1");
	    $cpuUtil = $1;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ". $sub_name :  <-- Leaving sub[1]");
    return $cpuUtil ;
}

=pod

=head3 SonusQA::ROUTER::getInterfacesLoad()

 DESCRIPTION:

 The function is used to get information of Top 10 loaded interfaces, returns a array of hashes having Interfaces list sorted in decending order based on their load,
  Each hash in result array will have Slot, Port, txLoad, rxLoad, and sumLoad values.
  Hash entry inside Return Array Ex:
  {
            'rxload' => '54/255',
            'sumload' => 110,
            'txload' => '56/255',
            'port' => '6',
            'slot' => '2'
  }

=over

=item EXAMPLE(s):
 my $interfacesLoad = $ciscoRouter->getInterfacesLoad();

=back

=cut

sub getInterfacesLoad{
    my $self = shift;
    my $sub_name ="getInterfacesLoad";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name");
    $logger->debug(__PACKAGE__. ". Entered $sub_name");
    my (@interfacesLoad,$prematch, $match);
    my $cmd = 'show interfaces | in tx|^Gi';
    
    unless($self->{conn}->print($cmd)){
        $logger->debug(__PACKAGE__ . " $cmd failed : ". $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[0]");
        return 0;
    }
        $logger->debug(__PACKAGE__ . " lstline : ". $self->{conn}->lastline);

    while(1){
        unless(($prematch, $match) = $self->{conn}->waitfor(
                                                       -match     => '/ --More-- /i',
                                                       -match     => $self->{PROMPT},
						       -Timeout    => 120,
                                                      )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \'[$cmd]\', [$self->{PROMPT}]");
            $logger->debug(__PACKAGE__ . " $cmd errmsg : ". $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        chomp $prematch;
        push @interfacesLoad,split /\n/,$prematch;
        last if($match !~ / --More-- /i);
        unless($self->{conn}->print("")){
            $logger->debug(__PACKAGE__ . " $cmd failed : ". $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[0]");
            return 0;
        }
    }
    my ($i,@gigabitEthernet,$count);
    for($i=0;$i<=$#interfacesLoad;$i++){
        if($interfacesLoad[$i] =~ /GigabitEthernet(\d+)\/(\d+)\s+is\s+up/i){
            my ($slot,$port)=($1,$2);
            my %tempHash;
            $tempHash{'slot'}=$1;
            $tempHash{'port'}=$2;
            if($interfacesLoad[$i+1] =~ /.*txload\s+(\d+)\/(\d+).*rxload\s+(\d+)\/(\d+)/){
                $tempHash{'txload'}=$1."/".$2;
                $tempHash{'rxload'}=$3."/".$4;
                $tempHash{'sumload'} = $1+$3;
            }
            push @gigabitEthernet,{%tempHash};
            $i++;
        }
    }
    my @sortLoad = reverse sort {$a->{'sumload'} <=> $b->{'sumload'}} @gigabitEthernet;
    $logger->debug(__PACKAGE__ . ". $sub_name :  <-- Leaving sub[1]");
    return [@sortLoad[0..9]];
}

=pod

=head3 SonusQA::ROUTER::getMemoryDetails()

 DESCRIPTION:

 The function is used to get Memory details of router,

=over

=item EXAMPLE(s):
 my $memory = $ciscoRouter->getMemoryDetails();

=back

=cut

sub getMemoryDetails{
    my $self = shift;
    my $sub_name ="getMemoryDetails";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name");
    $logger->debug(__PACKAGE__. ". Entered $sub_name");
    my (@interfacesLoad,$prematch, $match);
    my $cmd = 'show memory';

    unless($self->{conn}->print($cmd)){
        $logger->debug(__PACKAGE__ . " $cmd failed : ". $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ". $sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    unless(($prematch, $match) = $self->{conn}->waitfor(
                                                       -match     => $self->{PROMPT},
                                                      )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \'$cmd\'.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    } 
    $logger->debug(__PACKAGE__ . ". $sub_name :  <-- Leaving sub[1]");
    return $prematch;
}

=pod

=head3 SonusQA::ROUTER::sendMail()

 DESCRIPTION:

 The function is used to sendmail, takes a hash as argument.
 Input hash should have 3 keys "subject, mailList, and Message" and their values.
 
=over

=item EXAMPLE(s):

    $mailDetails{'subject'} = "Router Performance notification";
    $mailDetails{'message'} = $message;
    $mailDetails{'mailList'}= \@mailList;
    my $mailRet = $ciscoRouter->sendMail(%mailDetails);

=back

=cut

sub sendMail{
    my ($self,%mailList) = @_;
    my $sub_name = "sendMail";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name");
    $logger->debug(__PACKAGE__. ". Entered $sub_name");
    $logger->debug(__PACKAGE__. ". subjext:[$mailList{'subject'}] and mailList[@{$mailList{'mailList'}}] and message\n[$mailList{'message'}\n]");
    my $sendmail = '/usr/sbin/sendmail -t';
    my $subject = "Subject: $mailList{'subject'}\n";
    my $to = "To: ".join( ',', @{$mailList{'mailList'}} )." \n"; 
    my $from = "From: <nanthoti\@sonusnet.com> \n";
    eval{
	open(SENDMAIL,"|$sendmail");
 	print SENDMAIL $to;
	print SENDMAIL $from;
	print SENDMAIL $subject;
	print SENDMAIL "Content-type: text/plain\n\n";
	print SENDMAIL $mailList{'message'};
	close(SENDMAIL);
    };
    if($@){
	$logger->error(__PACKAGE__. ". $sub_name SendEMail ERROR: ".$@);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ". $sub_name :  <-- Leaving sub[1]");
    return 1;
}

=pod

=head3 SonusQA::ROUTER::connect()

 DESCRIPTION:

 The subroutine is used to make connection to Router for running commands to get the required information.
 this subroutine is called from SonusQA::Base::new 

=over

=back

=cut

sub connect {
    my ($self, %args) = @_;
    my $sub = "connect";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my($loop, $ok_flag , $telObj, @results, $prematch, $match, $ug, @cmd);
    $ug = new Data::UUID();
    my $failures = 0;
    my $failures_threshold = 2;

    while ( $failures < $failures_threshold ) {

        $ug = new Data::UUID();
        $logger->info(__PACKAGE__ . ". $sub [$self->{OBJ_HOST}] Making $self->{COMM_TYPE} connection attempt");

        my $uuid = $ug->create_str();
        my %sessionLogInfo;
        if ( $self->{SESSIONLOG} ) {
            $sessionLogInfo{sessionDumpLog} = "/tmp/sessiondump_". $uuid. ".log";
            $sessionLogInfo{sessionInputLog} = "/tmp/sessioninput_". $uuid. ".log";
            # Update the log filenames
            $self->getSessionLogInfo(-sessionLogInfo   => \%sessionLogInfo);

            $self->{sessionLog1} = $sessionLogInfo{sessionDumpLog};
            $self->{sessionLog2} = $sessionLogInfo{sessionInputLog};
        }
        else {
            $self->{sessionLog1} = ""; # turning off dump_log
            $self->{sessionLog2} = ""; # turning off input_log
        }
        $logger->debug(__PACKAGE__ . ". $sub [$self->{OBJ_HOST}] Session dump log: $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ". $sub [$self->{OBJ_HOST}] Session input log: $self->{sessionLog2}");

        $self->{CONNECTED_IPTYPE} = ($self->{OBJ_HOST} =~ /\d+\.\d+\.\d+\.\d+/) ? 'IPV4' : 'IPV6'; # storing the ip type used for connection
        if($self->{COMM_TYPE} eq 'TELNET'){
            if((!$self->{OBJ_PORT}) or ($self->{OBJ_PORT} == 22)){
                $self->{OBJ_PORT}=23;
            }
            $telObj = new Net::Telnet (-prompt => $self->{PROMPT},
                                       -port => $self->{OBJ_PORT},
                                       -telnetmode => 1,
                                       -cmd_remove_mode => 1,
                                       -output_record_separator => $self->{OUTPUT_RECORD_SEPARATOR},
                                       -Timeout => $self->{DEFAULTTIMEOUT},
                                       -Errmode => "return",
                                       -Dump_log => $self->{sessionLog1},
                                       -Input_log => $self->{sessionLog2},
                                       -binmode => $self->{BINMODE},
                                    );
            unless ( $telObj ) {
                $logger->warn(__PACKAGE__ . ". $sub [$self->{OBJ_HOST}] Failed to create a session object");
                $failures += 1;
                next;
            }

            unless ( $telObj->open($self->{OBJ_HOST}) ) {
                $logger->warn(__PACKAGE__ . ". $sub [$self->{OBJ_HOST}] Net::Telnet->open() failed");
                $failures += 1;
                next;
            }
	    my ($prematch,$match);
	    unless ( ($prematch, $match) = $telObj->waitfor(
                                                               -match => '/Password: /i',
								 -errmode => "return"
                                                             )) {
                $logger->error(__PACKAGE__ . ". failed to match password : ". $telObj->errmsg );
                $logger->debug(__PACKAGE__ . ". <-- Leaving sub [0]");
                return 0;
            }
	    $logger->debug(__PACKAGE__ . ". $sub Match: $match, and Prematch [$prematch]");
	    unless($telObj->cmd($self->{OBJ_PASSWORD})){
		$logger->error(__PACKAGE__ . ". $sub failed to enter password : ". $telObj->errmsg );
                $logger->debug(__PACKAGE__ . ". $sub <-- Leaving sub [0]");
                return 0;
	    }
            $self->{conn} = $telObj;

	    $self->{PROMPT} = '/'.$self->{conn}->last_prompt().'/';
	    $self->{conn}->prompt($self->{PROMPT});
	    $logger->debug(__PACKAGE__ . ": $sub PROMPT : ". $self->{conn}->prompt);
	    $logger->debug(__PACKAGE__ . ": $sub Connect <-- Leaving sub ");
            last; # We must have connected; exit the loop

        }  
    }
    $logger->debug(__PACKAGE__ . ". $sub :  <-- Leaving sub[1]");
    return 1;
}

1;
