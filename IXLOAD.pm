package SonusQA::IXLOAD;

=head1 NAME

SonusQA::IXLOAD - Perl module for interacting with IXLOAD Client

=head1 SYNOPSIS

my $ixLoadObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'IxLoad_Ats', -sessionlog => 1);

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::IXIA, File::Basename

=head2 AUTHORS

Naresh Kumar Anthoti <nanthoti@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

This module provides an interface to run IXLOAD Client commands.
This ATS module can be used to modify the tcl file, source it and wait for completion of script.

=cut

use strict;
use warnings;
use Module::Locate qw /locate/;
use File::Basename;
use Log::Log4perl qw(get_logger :easy);
use vars qw(@ISA);
use SonusQA::IXIA;
our @ISA = qw(SonusQA::IXIA);


=head1 doInitialization()

=over

=item DESCRIPTION:

This function is to set object defaults

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub = 'doInitialization' ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{PROMPT} = '/.*[\$%#\}\|\>]\s?$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{TCLSHELL} = 1;
    $self->{LOCATION} = locate __PACKAGE__ ;
    $self->{DEFAULTTIMEOUT} = 60;
    $self->{PATH}  = "";
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head1 setSystem()

=over

=item DESCRIPTION:

This function sets the system variables and Prompt.

=back

=cut

sub setSystem{
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my($cmd,$prompt, $prevPrompt);
    $logger->debug(__PACKAGE__ . ".$sub: Prompt [". $self->{PROMPT}."]");
    $self->{conn}->cmd("bash");

    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->last_prompt);

    $self->{conn}->cmd('export PATH=$PATH:/ats/tools/IXIA_6.60GA/bin/');
    $self->{conn}->cmd('export IXIA_HOME=/ats/tools/IXIA_6.60GA/');
    $self->{conn}->cmd('export IXIA_VERSION=6.60');
    $self->{conn}->cmd('export TCLLIBPATH=${IXIA_HOME}/lib/');
    $self->{conn}->cmd('export IXLOAD_6_40_59_6_INSTALLDIR=/ats/tools/IXIA_6.60GA/lib/IxLoad6.40-GA/');

    my @basic_cmd = ('tclsh', 'package req IxLoad');
    foreach (@basic_cmd) {
        unless ($self->{conn}->cmd(String => $_, Timeout => $self->{DEFAULTTIMEOUT}, Prompt => '/% /')) {
            $logger->error(__PACKAGE__ . ".$sub: failed run \'$_\'");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: Exit from tclsh");
    unless($self->{conn}->cmd('exit')){
    	    $logger->error(__PACKAGE__ . ".$sub: failed run \'exit\'");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: lastLine[". $self->{conn}->lastline."]");
    $self->{conn}->cmd('set +o history');
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}


=head1 modifyfile()

=over

=item DESCRIPTION:

The function modifies the tcl file content with the TMS values.

=item ARGUMENTS:

    Mandatory Args:
        'Tcl file name with absolute path': we need to pass the tcl file name, which we want to source and start the pumping of packets from IXIA Server.

=item EXAMPLE:

my $status = $ixLoadObj->modifyfile('/home/nanthoti/ats_repos/lib/perl/SonusQA/ACK-FLOOD-ATTACK.tcl');

=back

=cut

sub modifyfile{
    my($self,$file) = @_;
    my $sub = 'modifyfile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless(-e $file){
       $logger->debug(__PACKAGE__ . ".$sub: $file does not exist"); 
       return 0;
    }
    my %ChangeValues = (

                        'connect' =>    { 'pattern' => '::IxLoad connect' ,
                                          'value'       => "10.54.20.141",
                                          'previous'=> 'package require IxLoad'
                                        },
                        'addChassis' => { 'pattern' => '$chassisChain addChassis',
                                          'value'=> "10.54.20.140"
                                        },
                        'DUT'  =>       {'pattern' => '-ipAddress',
                                         'value'        => "10.54.20.142",
                                         'previous' => '$my_ixDutConfigVip config '
                                        },
                        'chassisID' =>  { 'pattern' => '-chassisId',
                                          'value'=> "1"
                                        },
                        'cardID' =>     { 'pattern' => '-cardId',
                                          'value'=> "2"
                                        },
                        'portID'=>      { 'pattern' => '-portId',
                                          'value'=> "9"
                                        }
                   );

    my %mapTmsValues = ('addChassis' => 'NODE-3-IP',
                        'connect'=>'NODE-2-IP',
                        'DUT' => 'DUT-1-IP',
                        'chassisID'=> 'NODE-3-NUMBER',
		        'cardID' => 'NODE-3-SLOT',
                        'portID' => 'NODE-3-PORT',
                   );     
    foreach my $key(keys %ChangeValues){
        my ($grpName,$grpIndex,$attr) = split '-',$mapTmsValues{$key};
        $ChangeValues{$key}{'value'} = $self->{'TMS_ALIAS_DATA'}{$grpName}{$grpIndex}{$attr};
    }
    $self->{'IXIA_SERVER'} = $ChangeValues{'addChassis'}{'value'};
    $self->{'CHASSIS_ID'} = $ChangeValues{'chassisID'}{'value'};
    $self->{'CARD_ID'} = $ChangeValues{'cardID'}{'value'};
    $self->{'PORT_ID'} = $ChangeValues{'portID'}{'value'};
    

    my ($fileName,$dir,$suffix) = fileparse($file,('.tcl'));
    my $sourceFile = $dir . $fileName. '_Source' . $suffix;
    open my $FD,"<","$file" or die $logger->debug(__PACKAGE__ . ".$sub: failed to open $file file in read mode");
    my @fileContent = <$FD>;
    close $FD;
    open $FD,">","$sourceFile" or die $logger->debug(__PACKAGE__ . ".$sub: failed to open $sourceFile file in write mode");
    my (@resultArray, $preLine);
    my $flag = undef;
    foreach my $fileLine (@fileContent){

        if ($fileLine =~ /^$/){
            print $FD $fileLine;
            next;
        }
        $preLine = $fileLine;
        unless(defined $flag){
            foreach(keys %ChangeValues){
                if(exists $ChangeValues{$_}{'previous'} && $preLine =~ /\Q$ChangeValues{$_}{'previous'}\E/){
                    $flag = $_;
                    last;
                }elsif(($preLine =~ /(\s*\Q$ChangeValues{$_}{'pattern'}\E\s+)\S+(.*)/) and (!exists $ChangeValues{$_}{'previous'})){
                    $fileLine = $1 . "$ChangeValues{$_}{'value'}".$2."\n";
                    $logger->debug(__PACKAGE__ . ".$sub: File line : [$fileLine]");
                    $flag = undef;
                    last;
                }
            }
            print $FD $fileLine;
        }elsif(defined $flag && $preLine =~ /(\s*\Q$ChangeValues{$flag}{'pattern'}\E\s+)\S+(.*)/){
            $fileLine = $1 ."\"". "$ChangeValues{$flag}{'value'}"."\"".$2."\n";
            print $FD $fileLine;
            $flag = undef;
            next;
        }else{
            print $FD $fileLine;
        }
    }
    $self->{'SOURCE_FILE'} = $sourceFile;
    return 1;

}

=head1 sourceBackground()

=over

=item DESCRIPTION:

The function runs the tcl script in background, so that user can get the control.

=item EXAMPLE:

my $retunSource = $ixLoadObj->sourceBackground;

=back

=cut

sub sourceBackground{
    my($self) = @_;
    my $sub = 'sourceBackground';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: Source File: $self->{'SOURCE_FILE'}");
    $self->{PID} = 0;
    my @cmdResults = $self->{conn}->cmd("tclsh $self->{'SOURCE_FILE'} \&");
print "cmdResults for sourcing File: [@cmdResults]\n";
    foreach (@cmdResults){
        chomp ;
        if ($_ =~ /\[.*\]\s+(\d+)/){
            $self->{PID} = $1;
print "PID is: [$self->{PID}]\n";
	    last; 
        }
    }
    if ($self->{PID} == 0) {
         $logger->warn(__PACKAGE__ . ".$sub Failed to get  PID of sourcing tcl file, manual cleanup is likely required\n");
         return 0;
      }
    $logger->info(__PACKAGE__ . ".$sub Started sourcing tcl file in backGround with PID $self->{PID}\n");
    $self->{STOPSOURCING} = 0;
    return 1;
}

=head1 waitCompletion()

=over

=item DESCRIPTION:

The function waits for the completion of tcl file execution.

=item ARGUMENTS:

    Optional Args:
        'timeout': this is the expected time for the completion of tcl file execution, If you dont pass any timeout value, ATS assigns 300secs as default timout, and kills the tcl process and stops pumping packets on IXIA server.

=item EXAMPLE:

my $retunWait = $ixLoadObj->waitCompletion(600);

=back

=cut

sub waitCompletion{
    my ($self,$timeOut)= @_;
    my $sub = "waitCompletion";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
    $logger->info(__PACKAGE__ . ". $sub: ---> Entered Sub ");
    $timeOut ||= 300;
    my $waited = 0;
    my $flag;
    while ($waited <= $timeOut){
        $flag = 0;
        my @lines = $self->{conn}->cmd("pidof tclsh");
        foreach(@lines){
            if($_ =~m/$self->{PID}/){
                $flag = 1;
                last;
            }
        }
        unless($flag){
            $logger->info(__PACKAGE__ . ".$sub Tcl file execution completed with in $waited seconds.");
            $logger->info(__PACKAGE__ . ".$sub clearing the port ownership.");
            unless ($self->stopSourcing){
                $logger->error(__PACKAGE__ . ".$sub: failed to clear ownership or stop transmitting");
                $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
                return 0;               
            }
            $self->{STOPSOURCING} = 1;
            return 1;
        }
        sleep 10;
        $waited += 10;   
    }
    if ($flag){
        $logger->warn(__PACKAGE__ . ".$sub  Tcl file execution did not complete in $timeOut seconds.");
        $logger->warn(__PACKAGE__ . ".$sub  tclsh instance still exists, calling stopSourcing to kill the tclsh instance.");   
        $self->stopSourcing;
        return 0;
    }
    
}

=head1 stopSourcing()

=over

=item DESCRIPTION:

The function stops the execution of tcl file, and connects to IXIA Server and stops pumping packets.
This subroutine is called in 2 situations, 
1: If Tcl instance still exists after the waitCompletion time.  
2: If user enters Ctrl-C to exit the script execution.

=back

=cut

sub stopSourcing{
    my ($self) = @_;
    my $sub = 'stopSourcing';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $try = 2;
    VERIFYKILL:
    my $flag = 0;
    my @lines = $self->{conn}->cmd("pidof tclsh");
    foreach(@lines){
        if($_ =~m/$self->{PID}/){
            $flag = 1;
        }
    }
    if($flag && $try){
        $logger->warn(__PACKAGE__ . ".$sub  sourcing Tcl file did not complete..");
        $logger->error(__PACKAGE__ . ".$sub Terminating Sourcing Tcl file, PID=$self->{PID}");
        $self->{conn}->cmd("kill -SIGKILL $self->{PID}");
        $try--;
        goto VERIFYKILL;
    }elsif($flag == 0 ){
        $logger->info( __PACKAGE__ . ".$sub Killing tclsh instance is SUCCESS.");
        $self->{PID} = 0;                     # No instance running now.
    }
    $self->SUPER::setSystem();
    my $stopPumppingCmd = 'ixPortClearOwnership '. $self->{'CHASSIS_ID'} .' '. $self->{'CARD_ID'} .' '. $self->{'PORT_ID'} .' force' ;
    $logger->debug( __PACKAGE__ . ".$sub Running [$stopPumppingCmd] command to stop IXIA pumpping");
    unless ($self->{conn}->cmd(String => $stopPumppingCmd, Timeout => $self->{DEFAULTTIMEOUT}, Prompt => '/% /')){
        $logger->error(__PACKAGE__ . ".$sub: failed run \'$stopPumppingCmd\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 
    $stopPumppingCmd = 'ixStopPortTransmit '. $self->{'CHASSIS_ID'} .' '. $self->{'CARD_ID'} .' '. $self->{'PORT_ID'} ;
    $logger->debug( __PACKAGE__ . ".$sub Running [$stopPumppingCmd] command to stop IXIA pumpping");
    unless ($self->{conn}->cmd(String => $stopPumppingCmd, Timeout => $self->{DEFAULTTIMEOUT}, Prompt => '/% /')){
        $logger->error(__PACKAGE__ . ".$sub: failed run \'$stopPumppingCmd\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $self->{STOPSOURCING} = 1;
    return 1;
}
sub DESTROY{
    my ($self) = @_;
    my $sub = 'DESTROY';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless($self->{STOPSOURCING}){
        $logger->debug(__PACKAGE__ . ".$sub  Sourcing Tcl file didn't completed, calling stopSourcing to kill the tclsh instance.");
        unless ($self->stopSourcing){
            $logger->error(__PACKAGE__ . ".$sub: failed stop transmission");
            $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
            $self->{conn}->close;
            undef $self->{conn};
            return 0;
        }
    }else{
        $logger->debug(__PACKAGE__ . ".$sub  Sourcing Tcl file completed, destroying the connection object.");
        $self->{conn}->close;
        undef $self->{conn};
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [1]");
        return 1;
    }
}

1;


