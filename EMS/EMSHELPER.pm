package SonusQA::EMS::EMSHELPER;

=head1 NAME

 SonusQA::EMS::EMSHELPER class

=head1 SYNOPSIS

 use SonusQA::EMS::EMSHELPER;

=head1 DESCRIPTION

 SonusQA::EMS::EMSHELPER provides a EMS infrastructure on top of what is classed as base EMS functions. These functions are EMS specific. It maybe that 
 functions here are also for EMS automation harness use. In this case, as the harness infrastructure becomes more generic, those functions will be taken 
 out of this helper module.

=head1 AUTHORS

 Ramesh Pateel (rpateel@sonusnet.com)

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX;
use List::Util qw(first);
use Time::Local;
use POSIX qw(strftime);
use File::Path qw(mkpath);
use WWW::Curl::Easy;
use SonusQA::PSX::INSTALLER;
use SonusQA::EMS::INSTALLER;
=head1 B<startInsight()>

=over 6

=item Description:

 This function will login as insight/insight user and start the ems.
             
=item Arguments:
 
 Optional
        -timeout => the timeout valuse in seconds required to start ems, default is 600

=item Return Value:

 0 - on failure
 number of seconds taken to start the ems - on success

=item Usage:

 my $timeTaken = $emsObj->startInsight();
    
=back

=cut

sub startInsight {
    my($self, %args)=@_;
    my $sub_name = 'startInsight';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $cmd = "";

    unless ( $self->becomeUser() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as insight");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    

    $cmd = "$self->{BASEPATH}" . "$self->{sonusEms} start";
    my $timeout = $args{-timeout} || 2400;
    my ($prematch, $match);

    #Truncating the log files 
    
    #PM related logs
    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/pm_trace_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/pm_diagnos_trace_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/ems_trace_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/emsOutput.log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/hibernate_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/quartz_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );
   
    #FM related logs
    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/fm_trace_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.trace';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/fmOutput.log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_trace';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );
     
    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/sonusFMSrvr.audit';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_trap_trace';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );
 
    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_diagnosis';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );   
 
    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_audit';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/emsFM/logs/owl.log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );
   

    #API related logs
    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/emsapi_prov_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/emsapi_debug_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    #CLI related logs
    $logfile = " >". "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/ems_cli_log';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>5 );

    $logger->info(__PACKAGE__ . ".$sub_name: Truncated log files ");

    #Removing the old log files
    
    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/weblogic/sonusEms/logs/sys/*log.*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/emsOutput.log.*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.log*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );
   
    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.trace*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/emsFM/logs/*receiver*.*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/emsFM/logs/*log.*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logfile = " rm -rf " . "$self->{BASEPATH}" . '/emsFM/logs/*audit.*';
    $self->{conn}->cmd(String =>"$logfile", Timeout=>60 );

    $logger->info(__PACKAGE__ . ".$sub_name: Removed old log files ");

    my $timeTaken = time;
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/Insight has been started/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \'$cmd\' is failed, din't recive expected success msg");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $timeTaken = time - $timeTaken;
    unless ($self->{conn}->waitfor( -match     => $self->{DEFAULTPROMPT})) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to get prompt back");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
       return 0;
    }

    $self->exitUser(); #TOOLS-18820
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$timeTaken]");
    return $timeTaken;
}

=head1 B<stopInsight()>

=over 6

=item Description:

 This function will login as insight/insight user and stop the ems.
             
=item Arguments:

 Optional
        -timeout => the timeout valuse in seconds required to start ems, default is 300

=item Return Value:

 0 - on failure
 number of seconds taken to stop the ems - on success

=item Usage:

 my $timeTaken = $emsObj->stopInsight();
    
=back

=cut

sub stopInsight {
    my($self, %args)=@_;
    my $sub_name = 'stopInsight';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");


    my $cmd = "$self->{BASEPATH}" . "$self->{sonusEms} stop";
    my $timeout = $args{-timeout} || 600;
    my ($prematch, $match);

    unless ( $self->becomeUser() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as insight");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $timeTaken = time;
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/Insight has been stopped/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \'$cmd\' is failed, din't recive expected success msg");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    } 
    $timeTaken = time - $timeTaken;

    unless ($self->{conn}->waitfor( -match     => $self->{DEFAULTPROMPT})) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to get prompt back");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
       return 0;
    }


    $self->exitUser();#TOOLS-18820 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$timeTaken]");
    return $timeTaken;
}

=head1 B<status_ems()>

=over 6

=item Description:

 This function checks if the main processes are running in ems.

=item Arguments:

    Optional arguments:
        -timeInterval = Wait time after every loop  (default 60 if noOfRetries is greater than 1)
        -noOfRetries  = no of iterations (default = 1)

=item Return Value:

 0 - If any main process is down.
 1 - If all the main process are running.

=item Usage:
 my %args;
 $args{timeInterval} = 30;
 $args{noOfRetries} = 10;
 my $status = $obj->status_ems(\%args);
 or
 my $status = $obj->status_ems();

=back

=cut

sub status_ems {

    my $self = shift;
    my %args = @_;
    my $sub = "status_ems";
    my $ret_status = '0';
    my ($time_interval, $no_of_retries, @status_ems);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");


    $time_interval = $args{-timeInterval} || 60;
    $no_of_retries = $args{-noOfRetries} || 1;
 

    my $loop=1;
    while ( $loop <= $no_of_retries ) {
        @status_ems = $self->execCmd("$self->{BASEPATH}/$self->{sonusEms} status");

        unless(grep(/Not Running/i, @status_ems)) {
            $ret_status = 1;
            $logger->debug(__PACKAGE__ . ".$sub: SUCCESSFUL - loop($loop), all process are in expected status(Running).");
            last ;            
        }

        $logger->debug(__PACKAGE__ . ".$sub: UNSUCCESSFUL - loop($loop), all process are not in expected status(Running) or EMS is not up.");
        if($loop < $no_of_retries){
            $logger->debug(__PACKAGE__ . ".$sub: sleep for ($time_interval) seconds.");
            sleep ($time_interval);
        }
        $loop++;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [$ret_status]");
    return $ret_status;
}


=head1
=item Description: RAC install script 1

=cut

sub racInstallScript1 {
    my($self, %args)=@_;
    my $sub_name = 'racInstallScript1';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    # get the required information from TMS 
    my $emsIPAddress    = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $emsRootPassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $racConfFileloc = "$self->{TMS_ALIAS_DATA}->{NODE}->{2}->{USER_DATA}";
    my $confFileName = "$self->{TMS_ALIAS_DATA}->{NODE}->{3}->{USER_DATA}";
    my $confFileloc = "$racConfFileloc" . '/' . "$confFileName";

=head
     #To copy rac.conf file
     my %scpArgs;
     $scpArgs{-hostip} = "$emsIPAddress";
     $scpArgs{-hostuser} =  $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
     $scpArgs{-hostpasswd} = $emsRootPassword;
     $scpArgs{-destinationFilePath} = "/tmp/";

     $scpArgs{-sourceFilePath} = $confFileloc;
     $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";

      unless(&SonusQA::Base::secureCopy(%scpArgs)){
          $logger->error(__PACKAGE__ . ".  SCP failed to copy rac.conf file to destination");
          $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
        }

    $logger->info(__PACKAGE__ . ".SCP Success to copy the rac.conf file to $scpArgs{-destinationFilePath}");
    
    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
=cut

    # To go to the /tmp folder:
    my $cmdPath = "cd /tmp";
    unless ( $self->{conn}->print( $cmdPath ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmdPath\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    #Fetch the file from racConfFileloc mentioned in TMS alias.
    $logger->debug(__PACKAGE__ . ".$sub_name:  ********wget is being used here for copying**********");
    $logger->debug(__PACKAGE__ . ".$sub_name:  ********Started copying the script********");

    $logger->debug(__PACKAGE__ . ".$sub_name: Conf File Location is: \'$racConfFileloc\'");
    my $cmd1 = "wget" . " " . $racConfFileloc;
    $logger->debug(__PACKAGE__ . ".$sub_name: Command to copy the file is: \'$cmd1\'");
    unless ( $self->{conn}->print( $cmd1 ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd1\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    

    my $cmd = "/export/home/pkg/" . 'RACinstall_1 /tmp/rac.conf'; 

    my $timeout = $args{-timeout} || 5400;
    my ($prematch, $match);
    my $timeTaken = time;
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
  
   my  $max_attempts = 30;
   my $confType = $self->{TMS_ALIAS_DATA}->{NODE}->{4}->{USER_DATA};
   if($confType == 1) {
      $logger->info( __PACKAGE__ . " RAC conf type is RAID. waiting for completion of 1st script execution." );
       
     unless (($prematch, $match) = $self->{conn}->waitfor( -match => '/Rebooting ems1/i' , -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: please wait, Rebooting ems1 ..");
    }
 
   for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){
    if( $self->{root_session} = new SonusQA::Base( -obj_host => "$emsIPAddress",
                                         -obj_user       => "root",
                                         -obj_password   => "$emsRootPassword",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 300,
                                                             -sessionlog => 1,
                                       )){
                                             $logger->info(__PACKAGE__ . ".$sub_name: connection to primary EMS on $emsIPAddress is successfull after reboot");
                                             last;
        }else {
               if ($attempt < $max_attempts){
             $logger->error(__PACKAGE__ . "connection to primary EMS on $emsIPAddress failed, still rebooting. Retrying....");
             sleep(65);
            }
            else {
                $logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. Not able to login to primary EMS on $emsIPAddress ");
                return 0;
             }
        }
        }

        }else {
        # check for SAN conf type : for SAN => no reboot at this stage.
         $logger->info( __PACKAGE__ . " RAC conf type is SAN. waiting for completion of RAC install scrip1." );
        unless (($prematch, $match) = $self->{conn}->waitfor( -match => '/Generating and installing cluster-specific ssh keys for oracle.*ok/i' , -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get prompt back");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
        }

    $timeTaken = time - $timeTaken;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$timeTaken]");
    return 1;
}

=head1
=item Description: RAC install script 2

=cut

sub runRacScript2 {
    my($self, %args)=@_;
    my $sub_name = 'runRacScript2';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $cmd = "";

    unless ( $self->{root_session} ) {
     # get the required information from TMS
     my $emsIPAddress    = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
     my $emsHostName     = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
     my $emsRootPassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};

     $self->{root_session} = new SonusQA::Base( -obj_host       => "$emsIPAddress",
                                         -obj_user       => "root",
                                         -obj_password   => "$emsRootPassword",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                                             -sessionlog => 1,
                                       );
     unless ( $self->{root_session} ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to EMS on $emsIPAddress");
       return 0;
     }
   }

    $cmd = "/export/home/pkg/" . 'EMSRACinstall';
    my $timeout = 7200;
    my ($prematch, $match);
    my $timeTaken = time;
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
   #check for completion of 2nd script, it takes around 90 minutes to complete
     $logger->info(__PACKAGE__ . ".$sub_name: Waiting for EMSRACinstall script execution to complete. it will takes around 90 minutes.");
	 
    unless (($prematch, $match) = $self->{conn}->waitfor( -match => '/Completed EMS installation/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \'$cmd\' is failed, din't recive expected success msg");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
   }
    $timeTaken = time - $timeTaken;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$timeTaken]");
    return 1;
}


=head1
=item Description: checkHaEmsStatus

=cut

sub checkHaEmsStatus {
 my ($self) = @_;
    my $sub = "checkHaEmsStatus";
    my @status_ems = ();
    my $ret_status = '1';

    my $BASEDIR = $self->{BASEPATH};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return $ret_status;
      } 

      @status_ems = $self->execCmd($BASEDIR."/conf/HA/RAC/sonusEMS status");
       
     $logger->debug(__PACKAGE__ . ".$sub: The status of EMS process :". Dumper(\@status_ems));

     if(grep( /'OFFLINE'/i, @status_ems)) {
            $logger->error(__PACKAGE__ . ".$sub : All the EMS processes have not come ONLINE yet !");
            $ret_status = 0;
        }
        else { 
                $logger->info(__PACKAGE__ . ".$sub Success : All the EMS processes have come ONLINE "); 
        }  

        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [$ret_status]");
       return $ret_status;
}



=head1

Description : switchOverHaRac

=cut

sub switchOverHaRac {
    my ($self) = @_;
    my $sub = "switchOverHaRac";
    my @switch_ems = ();
    my $ret_status = '1';
    my $timeout = 1200;

    my $BASEDIR = $self->{BASEPATH};
    my $cmd = $BASEDIR."/conf/HA/RAC/sonusEMS relocate" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");
    my ($prematch, $match);

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
      } 

	unless ( $self->becomeUser() ) {
        $logger->error(__PACKAGE__ . ".$sub:  failed to login as insight");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
         }
	 
        $logger->info(__PACKAGE__ . ".$sub : Started Relocating HA EMS ..");
      unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/Relocate Complete/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub: Relocate failed !");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
  }else {
        $logger->info(__PACKAGE__ . ".$sub : Success - Relocate Completed");
        }

        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [$ret_status]");
       return $ret_status;

}


=head1

Description :checkPreUpgrade for HA EMS
=cut

sub checkPreUpgrade {
    my ($self) = @_;
    my $sub = "checkPreUpgrade";    
    my $BASEDIR = $self->{BASEPATH};
    my @status_ems = ();
    my $cmd = $BASEDIR."/conf/HA/RAC/sonusEMS status" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	
    my $primaryHostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $secondaryHostname = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
    my $retVal = 0;    
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");
    
    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
      }

        @status_ems = $self->execCmd($cmd);
	 my $countPrim = grep (/$primaryHostname/, @status_ems);
	 my $countSec = grep (/$secondaryHostname/, @status_ems);

         $logger->debug(__PACKAGE__ . ".$sub: val of countPrim = $countPrim and val of countSec = $countSec ");
	 
	 if ($countPrim < $countSec) {
	    $retVal = 1;
	  }else {
            $retVal = 0;
           }
	 	 
    return $retVal ;
}



=head1 B<Start_jstat()>

=over 6

=item Description:

 This function starts the jstat for the EMS under test
                 - validates the existence of jdk package and tools.policy on EMS under test
                 - Starts the jstatd on the EMS under test
                 - Validates the existence of the jstat utility on jstat machine
                 - Depending on the arguments passed, starts the jstat for the respective processes such as insight , fm & fmds

=item Arguments:

 Hash with below deatils
          - Manditory
                -jstat_obj => object for the jstat machine
                -testcase_id => testcase id of the test
                -insight => the process name for which to start the jstat
          - Optional
                -fm => optional process name for which to start the jstat
                -fmds => optional process name for which to start the jstat
=item Return Value:

 1 - on success
 0 - on failure

=item Usage:
  
 my %args = (-jstat_obj => 'jstat_obj',
             -testcase_id => "PM_PERF_001"
             -insight => "insight",
             -fm => "fm",
             -fmds => "fmds");

 my $result = $Obj->Start_jstat(%args);

=back

=cut

sub Start_jstat {
    my($self, %args)=@_;
    my $sub = "Start_jstat";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    foreach ('-jstat_obj','-testcase_id', '-insight') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }
    $args{-fm} ||= "root";
    $args{-fmds} ||= "root";


    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    
    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;
    my $SUT_Name=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
 my $EmsIP = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    $logger->debug(__PACKAGE__ . ".$sub: EMS IP : $EmsIP");  
    $args{-jstat_obj}->{ems_ip}=$self->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    $args{-jstat_obj}->{jstat_path} = "/export/home2/".$SUT_Name."_".$args{-testcase_id}."_".$timestamp;
    
    #Changing the directory to JSTATD_DIR
    $logger->info(__PACKAGE__ . ".$sub Changing the working directory to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
    my @cmd_res= $self->{conn}->cmd("cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub ");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub Changed the working directory to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");


    #Checking if tools.policy exists
    $logger->info(__PACKAGE__ . ".$sub Checking if tools.polcy exists in $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
    my $cmd = "ls $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}/tools.policy";
    my @exist=$self->{conn}->cmd("$cmd");
         my @hostcheck = $self->{conn}->cmd("hostname");
           $logger->info(__PACKAGE__ . ".$sub hostname : $hostcheck[0]");
        if (grep(/No such file or directory/, $exist[0])) {
         $logger->error(__PACKAGE__ . ".$sub $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}/tools.policy not present" . Dumper(\@exist));
         return 0;
         } else {

        $logger->info(__PACKAGE__ . ".$sub tools.polcy exists in $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
        $logger->info(__PACKAGE__ . ".$sub Checking if some instance of jstatd is already running");

        #Killing an already running jstatd instance if any
        my @pid  = $self->{conn}->cmd(" ps -ef | grep jstatd | grep -v grep | awk \'{ print \$2 }\'");
        if ($pid[0]) {
            $logger->info(__PACKAGE__ . ".$sub Found an already running instance of jstatd");
            $self->{conn}->cmd(" kill -9 ` ps -ef | grep jstatd | grep -v grep | awk \'{ print \$2 }\'`");
            sleep 2; 
            $self->{conn}->cmd(); 
            $logger->info(__PACKAGE__ . ".$sub Killed the already running instance of jstatd");}
        
        $logger->info(__PACKAGE__ . ".$sub No instance of jstatd running anymore, starting jstatd");
         my @hostid = $self->{conn}->cmd("id");
           $logger->info(__PACKAGE__ . ".$sub id : $hostid[0]");
        my @pwd = $self->{conn}->cmd("pwd");
           $logger->info(__PACKAGE__ . ".$sub pwd : $pwd[0]");

        my $jstatcmd = "nohup ./jstatd -p 2099 -J-Djava.security.policy=tools.policy -J-Djava.rmi.server.hostname=$EmsIP > nohup.out 2>&1&";  
        # $self->{conn}->cmd("nohup ./jstatd -p 2099 -J-Djava.security.policy=tools.policy -J-Djava.rmi.server.hostname=$EmsIP > nohup.out 2>&1& ");
        $self->{conn}->cmd("$jstatcmd"); 

          $logger->info(__PACKAGE__ . ".$sub jstatcmd : $jstatcmd");
	#In case of Error Execpetion will be printed in nohup.out	

        @cmd_res  = $self->{conn}->cmd(" grep -ci exception nohup.out  ");
        #@cmd_res  = $self->{conn}->cmd(" ls -l  nohup.out | awk \'{print \$5}\'");
        if ( $cmd_res[0] != "0" ) {
            $logger->error(__PACKAGE__ . ".$sub jstatd not started successfully on $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}");
            return 0;}
        else
        {
        $logger->info(__PACKAGE__ . ".$sub jstatd started successfully on $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}");
        $logger->info(__PACKAGE__ . ".$sub Changing the working directory to $args{-jstat_obj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}");
        @cmd_res= $args{-jstat_obj}->{conn}->cmd("cd $args{-jstat_obj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}");
        if(grep ( /no.*such/i, @cmd_res)) {
           $logger->error(__PACKAGE__ . ".$sub $args{-jstat_obj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH} directory not present");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub ");
           return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub Changed the working directory to $args{-jstat_obj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}");
        $logger->info(__PACKAGE__ . ".$sub Starting jstat for testcase $args{-testcase_id} for EMS $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} at $timestamp");
        sleep 10;
        if ($args{-insight} ne "root") {
        
        $logger->info(__PACKAGE__ . ".$sub Starting $args{-insight}\'_'jstat ");
        $args{-jstat_obj}->{conn}->cmd("nohup ./$args{-insight}\'_'jstat.sh 3 $SUT_Name\'_'$args{-testcase_id}\'_'$timestamp $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}  > nohup.out 2>&1& "); sleep 10;
         $logger->info(__PACKAGE__ . ".$sub nohup ./$args{-insight}\'_'jstat.sh 3 $SUT_Name\'_'$args{-testcase_id}\'_'$timestamp $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}");       
        }
        if ($args{-fm} ne "root") {
        $logger->info(__PACKAGE__ . ".$sub Starting $args{-fm}\'_'jstat ");
        $args{-jstat_obj}->{conn}->cmd("nohup ./$args{-fm}\'_'jstat.sh 3 $SUT_Name\'_'$args{-testcase_id}\'_'$timestamp $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}  >> nohup.out 2>&1& "); sleep 10; }
		 if ($args{-fmds} ne "root") {
        $logger->info(__PACKAGE__ . ".$sub Starting $args{-fmds}\'_'jstat ");
        $args{-jstat_obj}->{conn}->cmd("nohup ./$args{-fmds}\'_'jstat.sh 3 $SUT_Name\'_'$args{-testcase_id}\'_'$timestamp $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}  >> nohup.out 2>&1& "); sleep 10;}
        sleep 15;
        @cmd_res = $args{-jstat_obj}->{conn}->cmd(" grep -i writing nohup.out |wc -l ");
        if ($cmd_res[0] >= '1' ) {
            @cmd_res = $args{-jstat_obj}->{conn}->cmd(" grep -i Exception nohup.out |wc -l");
            if ($cmd_res[0] == '0' ) {
               $logger->info(__PACKAGE__ . ".$sub jstat started successfully");
               return 1;}
            else {
               $logger->error(__PACKAGE__ . ".$sub java exception observed");
               return 0;
            }
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub could not start jstat, check ssh connection to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}");
            return 0;
        }
        }
     }
}

=head1 B<Stop_jstat()>

=over 6

=item Description:

 This function stops the jstat for the EMS under test
                 - validates the existence of jdk package and tools.policy on EMS under test
                 - Stops the jstatd on the EMS under test

=item Arguments:

 Hash with below deatils
                   No arguments

=item Return Value:

 1 - on success
 0 - on failure

=item Usage:
    
 my $result = $Obj->Stop_jstat();

=back

=cut


sub Stop_jstat {
    my($self)=@_;
    my $sub = "Stop_jstat";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    # Just pressing enter to get if any old command responses


    $logger->info(__PACKAGE__ . ".$sub Changing the working directory to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
    my @cmd_res=  $self->{conn}->cmd("cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub ");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub Changed the working directory to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");

    $logger->info(__PACKAGE__ . ".$sub Checking if tools.polcy exists in $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
    my $cmd = "ls $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}/tools.policy";
    my @exist=$self->{conn}->cmd("$cmd");
    if (grep(/No such file or directory/, $exist[0])) {
         $logger->error(__PACKAGE__ . ".$sub $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR}/tools.policy not present" . Dumper(\@exist));
         return 0;
         } else {
        $logger->info(__PACKAGE__ . ".$sub tools.polcy exists in $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JSTATD_DIR} ");
        $logger->info(__PACKAGE__ . ".$sub Checking if some instance of jstatd is running");

        my @pid  = $self->{conn}->cmd(" ps -ef | grep jstatd | grep -v grep | awk \'{ print \$2 }\'");
        #print $pid[0];
        if ($pid[0]) {
            $logger->info(__PACKAGE__ . ".$sub Found a running instance of jstatd");
            $self->{conn}->cmd(" kill -9 ` ps -ef | grep jstatd | grep -v grep | awk \'{ print \$2 }\'`");
            sleep 2;          
            $self->{conn}->cmd(); 
            $logger->info(__PACKAGE__ . ".$sub Killed the instance of jstatd running on $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}");
           
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
            return 1;
            } 
         
         else {
            $logger->error(__PACKAGE__ . ".$sub No instance of jstatd running on $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}");
            return 0;
         }
   } 
}

=head1 B<pm_export_trim()>

=over 6

=item Description:

 This function will delete all the PM export files at that moemnt in that directory

=item Arguments:
      
 The PM directory under /export/home/ems/weblogic/sonusEms/data

=item Return Value:

 0 - on failure
 1 - on success

=item Usage:
     
 my $del_pm = $emsObj->pm_export_trim($testcaseid);

=back

=cut


sub pm_export_trim {

     my ($self,$dir) = @_;
     my $sub = "pm_export_trim";
     my $pm_dir=$self->{BASEPATH}."/".$main::TESTSUITE->{PM_DIR}."/".$dir.'/'."$self->{dev}"; #$self-{dev} will be set by modify profile based on Device type
     my @del_file = ();
     my @cmd_res = ();
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

     $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

     unless ( $dir ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory directory input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     $self->execCmd("unalias rm");
     @cmd_res = $self->execCmd("cd $pm_dir");
     if(grep ( /no.*such/i, @cmd_res)) {
         $logger->error(__PACKAGE__ . ".$sub $pm_dir not present");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub Changed working directory to $pm_dir");
     
     #Reading the curremt time of the EMS and waiting accordingly so that no export happens currently
     my $cmd = 'date +\'%M\'';
     @cmd_res = $self->execCmd("$cmd");
     my $time = $cmd_res[0];
     if (($time % 5) <= 1 ) {
         $logger->debug(__PACKAGE__ . ".$sub:The Current minute is $time, so sleeping for 70 secs before removing the currently exported files");
	sleep 70 ;
     } elsif (($time % 5) >= 4 ) { 
        $logger->debug(__PACKAGE__ . ".$sub: The Current minute is $time, so  sleeping for 130 secs before removing the currently exported files");
	sleep 130;
     } else {
	 $logger->debug(__PACKAGE__ . ".$sub: The Current minute is $time , so removing the currently exported files ");
     } 
     
     #Removing the currently exported stats iles and also already existing PM report CSVs
     $self->execCmd("rm *.csv",3600);
     $self->execCmd("rm -rf ../*.csv",3600);
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
     return 1;
 }

=head1 B<pm_device_loss()>

=over 6

=item Description:

 This function will generate the loss report for PM export data and copy the report to ATS repository.

=item Arguments:
     
 Mandatory
         1.the name of the file containining the names of the nodes for which the report has to be generated.
         2.PM directory under /export/home/ems/weblogic/sonusEms/data

=item Return Value:

 0 - on failure
 1 - on success. 

=item Usage:
     
 my $pm_export = $emsObj->pm_device_loss("GSX",$testcaseid);

=back

=cut

sub pm_device_loss {

     my ($self, $node_file,$dir) = @_;
     my $sub = "pm_device_loss";
     my @cmd_res = ();
     my $pm_dir= $self->{BASEPATH}."/".$main::TESTSUITE->{PM_DIR}."/".$dir;
     my $pm_tool_path = $main::TESTSUITE->{PM_Tool_path};
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     my $cmd = '';

     $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

     unless ( $node_file ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory node file input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     unless ( $dir ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory directory input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }
    
     @cmd_res = $self->execCmd("cd $pm_dir");
     if(grep ( /no.*such/i, @cmd_res)) {
         $logger->error(__PACKAGE__ . ".$sub $pm_dir directory not present");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub Changed working directory to $pm_dir");

     #Selecting the script file based on the device type set in modify_profile
     if(uc "$self->{dev}"  eq 'SBX5K' ) {
     $cmd = "$pm_tool_path/allstat_SBC5K.sh $node_file > $dir-\$(date +%m-%d-%y-%H-%M).csv ";
     } elsif (uc "$self->{dev}"  eq 'SBX1K' ) {
     $cmd = "$pm_tool_path/allstat_SBC1K.sh $node_file > $dir-\$(date +%m-%d-%y-%H-%M).csv ";
     } else {
     $cmd = "$pm_tool_path/allstat.sh $node_file > $dir-\$(date +%m-%d-%y-%H-%M).csv ";
     }
     $logger->debug(__PACKAGE__ . ".$sub: Executing $cmd");
     
     
     #The result sheet generated will be of the form TESTCASEALIASName_yy-mm-dd.csv
     @cmd_res = $self->execCmd(" $cmd ",14400);
     chomp(@cmd_res);
     if(@cmd_res) {
         foreach(@cmd_res) {
             $logger->error(__PACKAGE__ . ".$sub: ERROR : $_");
             $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
             return 0;
         }
     }
     #Copying result sheet to ATS repository
     my %scpArgs;
     $scpArgs{-hostip} = $self->{OBJ_HOST}; 
     $scpArgs{-hostuser} = $self->{OBJ_USER};
     $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
     $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$pm_dir/$dir-*";
     $scpArgs{-destinationFilePath} = $self->{result_path};

     $logger->debug(__PACKAGE__ . ".$sub: scp files $scpArgs{-sourceFilePath} to $self->{result_path}");
     unless(&SonusQA::Base::secureCopy(%scpArgs)){
         $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the result files to $self->{result_path}");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub:  SCP Success to copy the result files to $self->{result_path}");
     $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
     return 1;
 }

=head1 B<pm_total_loss()>

=over 6

=item Description:

 This function enables user to determine whether PM export data is greater than 0.1% or not.

=item  Arguments:
    
 1. Expected record count.
 2.PM directory under /export/home/ems/weblogic/sonusEms/data


=item Return Value:

 0 - if loss in PM export data is less greater than 0.1%.
 1 - if loss in PM export data is less than or equal to 0.1%

=item Usage:
     
 my $pm_total = $emsObj->pm_total_loss("123456",$testcaseid);

=back

=cut

sub pm_total_loss {

     my ($self, $exp_count,$dir) = @_;
     my @cmd_res = ();
     my $sub = "pm_total_loss";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     my $pm_dir=$self->{BASEPATH}."/".$main::TESTSUITE->{PM_DIR}."/".$dir;
     my @interval_count = ();
     $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
     my $cmd = '';

     unless( $exp_count ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory expected count input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     unless ( $dir ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory directory input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     @cmd_res = $self->execCmd("cd $pm_dir");
     if(grep ( /no.*such/i, @cmd_res)) {
         $logger->error(__PACKAGE__ . ".$sub $pm_dir directory not present");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub Changed directory to $pm_dir");
	 
     #calculating the  no of intervals for which the export data is obtained
     if(uc "$self->{dev}"  eq 'SBX5K' ) {
     $cmd = "ls -lrt ./SBX5K/NBS5200TrunkGroupStatusStats*.csv |wc -l";
     } elsif (uc "$self->{dev}"  eq 'SBC 1000' ) {
     $cmd = "ls -lrt ./SBX1K/*PT*.csv |wc -l";
     } else {
     $cmd = "ls -lrt ./GSX/GsxTg*.csv |wc -l";
     }
     $logger->debug(__PACKAGE__ . ".$sub: Executing $cmd");
     @interval_count = $self->execCmd( " $cmd", 7200);
     unless(@interval_count) {
         $logger->error(__PACKAGE__ . ".$sub Failed to get the Count of intervals exported");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }

     $logger->info(__PACKAGE__ . ".$sub No of intervals currently exported " . Dumper(\@interval_count));
     $exp_count = $exp_count*$interval_count[0];
     $logger->info(__PACKAGE__ . ".$sub: Total no of stats expected for the run :" . " $exp_count");


     #Checking the record count of all nodes and all the intervals
     if(uc "$self->{dev}"  eq 'SBX5K' ) {
     $cmd = "grep -v ^\$ ./SBX5K/* | grep -v \"#\" | wc -l";
     } elsif (uc "$self->{dev}"  eq 'SBC 1000' ) {
     $cmd = "grep -v ^\$ ./SBX1K/* | grep -v \"#\" | wc -l";
     } else {
     $cmd = "grep -v ^\$ ./GSX/* | grep -v \"#\" | wc -l";
     }
     $logger->debug(__PACKAGE__ . ".$sub: Executing $cmd");
     @cmd_res = $self->execCmd("$cmd",7200);
     unless(@cmd_res) {
         $logger->error(__PACKAGE__ . ".$sub Failed to fetch the records in PM export data");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->info(__PACKAGE__ . ".$sub: Total No of stats  exported in EMS_SUT:" . " $cmd_res[0]" ); 

    
     my $loss = eval{sprintf "%0.3f",100*(1-$cmd_res[0]/$exp_count)};

     #Printing the stats to result file
     my $fp;
     open $fp , ">>", "$self->{result_path}/Testcase_Results.txt";
     print $fp "##########################\n";
     print $fp "PM Loss Summary  \n";
     print $fp "##########################\n";
     print $fp "Total No of stats expected : $exp_count\n";
     print $fp "Total No of stats  exported in EMS_SUT: $cmd_res[0]\n";
     print $fp "The PM Loss for the test case is :$loss %\n";
     close $fp;

     if(eval{sprintf "%0.3f",$cmd_res[0]/$exp_count}  < 0.999 ) {
         $logger->error(__PACKAGE__ . ".$sub:Loss is greater than 0.1%.The loss is :"  . $loss . '%');
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->info(__PACKAGE__ . ".$sub:The loss %age is less than 0.1 and the loss for current test case is :" .  $loss . '%' );
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
     return 1;
 }

=head1 B<call_netcool()>

=over 6

=item Description

 This function enables user to either clear traps and find total number of traps in EMS netcool DB SCPs the result summary to ATS in case of netcool count total

=item Arguments:
     
 Mandatory
         Required action ( clear/total)

=item Return Value:

 0 - on failure
 1 - if it successfully clears traps
 total number of traps in EMS netcool DB

=item Usage:
     
 my $traps = $emsObj->call_netcool("clear");

=back

=cut

sub call_netcool {

     my ($self,$action) = @_;
     my $sub = "call_netcool";
     my $ncdb_path = $main::TESTSUITE->{PM_Tool_path};
     my $emsHostName     = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
     my @cmd_res = ();
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;
     my $file="Netcool_Summary_".$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}."_".$timestamp.".txt";
     $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

     unless ( $action ) {
         $logger->error(__PACKAGE__ . ".$sub Mandatory input action is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
         return 0;
     }

     @cmd_res = $self->execCmd("cd $ncdb_path");
     if( grep (/no.*such.*dir/i, @cmd_res)) {
         $logger->error(__PACKAGE__ . ".$sub $ncdb_path directory not present");
         $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub. [0]");
         return 0;
     }
     #Printing the summary of Alarms before perfroming any operations and moving it to csv file
     $logger->info(__PACKAGE__ . ".$sub Performing Summary operation");
     @cmd_res = $self->execCmd("./ncdb_script.sh summary > $file");
     if( grep (/no.*such.*file/i, @cmd_res)) {
     $logger->error(__PACKAGE__ . ".$sub ncdb_script.sh file not present");
     $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub. [0]");
     return 0;
     } else {
     $logger->info(__PACKAGE__ . ".$sub Per Device alarm summary the EMS" . Dumper(\@cmd_res));
     }
     #Checking if the input is valid (total/clear)
     if( $action =~ /clear/ || $action =~ /total/ ) {
         $logger->info(__PACKAGE__ . ".$sub Action is $action");
         $self->execCmd("./ncdb_script.sh $action  >> $file");
         @cmd_res = $self->execCmd(" tail -6 $file"); 
         if( grep (/no.*such.*file/i, @cmd_res)) {
             $logger->error(__PACKAGE__ . ".$sub ncdb_script.sh file not present");
             $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub. [0]");
             return 0;
         }
         elsif( grep ( /\d+ row.*affected/i, @cmd_res)) {
             $logger->info(__PACKAGE__ . ".$sub Performed action $action");
             if( $action =~ /total/i) {                                                      #Prints the count only if the action is total
                 $logger->info(__PACKAGE__ . ".$sub Total number of traps = $cmd_res[3]");
                 $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub. [$cmd_res[3]]");
            
             #Copying result sheet to ATS repository
	    my %scpArgs;
            $scpArgs{-hostip} = $self->{OBJ_HOST};
            $scpArgs{-hostuser} = $self->{OBJ_USER};
            $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
            $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$ncdb_path/Netcool*.txt";
            $scpArgs{-destinationFilePath} = $self->{result_path};

            $logger->debug(__PACKAGE__ . ".$sub: scp file $file to $self->{result_path}");
            unless(&SonusQA::Base::secureCopy(%scpArgs)){
                $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the result files to $self->{result_path}");
                $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                return 0;
            }
            sleep 10;
            $logger->debug(__PACKAGE__ . ".$sub:  <-- SCP of netcool results file was successful ");
           
             # Printing the FM Results to Testcase_Results.txt

             my $fp; # File handler
             open $fp , ">>", "$self->{result_path}/Testcase_Results.txt";
             print $fp "##########################\n";
             print $fp "FM Results  \n";
             print $fp "##########################\n";
             print $fp "Total number of traps in $emsHostName = $cmd_res[3]\n";
             close $fp;
            } 
            $self->execCmd(" rm -rf Netcool*.txt ");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
            return $cmd_res[3];
         
          
         }
         else {
             $logger->error(__PACKAGE__ . ".$sub Failed to perform $action");
         }
     }
     else {
         $logger->error(__PACKAGE__ . ".$sub  Invalid input : $action .");
         $logger->debug(__PACKAGE__ . ".$sub  <-- Leaving Sub [0]");
         return 0;
     }
 }

=head1 B<pm_purge()>

=over 6

=item Description:

 This function will be called to truncate all ATT PM stats tables and set the GSX connecvity mode. if -GsxCon is set then it will enable SSH or disbale SSH

=item Arguments:
    
 None

=item Return Value:

 0 - on failure
 1 - on success

=item Usage:
    
 my $del_pm = $emsObj->pm_purge(-GsxCon=> 'SSH'); # Will truncate all tables and enable SSH
                                            or
 my $del_pm = $emsObj->pm_purge(); # will Traunacte all tables and disable SSH

=back

=cut

sub pm_purge {
    
    my ($self,%args) = @_;
    my $sub = "pm_purge";
    my $sql_userid = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $sql_passwd = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
    my @tables = ('ACCOUNTINGSUMMARYSTATS' , 'CALLCOUNTSTATS' , 'CONGESTIONINTERVALSTATS', 'GATEWAYCALLSTATS' , 'GSXHPCINTERVALSTATS' , 'GSXSIPHPCINTERVALSTATS' , 'GSXTGINTERVALSTATS' , 'IPTRUNKGROUPINTERVALSTATS' , 'PNSENETSTATS' , 'SOFTSWITCHSTATS' , 'SYSTEMSTATS' , 'TRUNKGROUPSTATS' , 'TRUNKGROUPSTATSV32', 'CallFailIntervalStats' , 'CallIntervalStats' ,     'DnsGroupDnsServerStats' , 'DspResDspUsageIntervalStats' , 'EthernetPortMgmtStats' , 'IpAclOverallStats' , 'IpAclRuleStats' , 'IpGeneralGroupStats' , 'IpGeneralGroupStats' , 'LinkDetectionGroupStats' , 'LinkMonitorStats' , 'SipIntervalStats' , 'SipRegCountStats' , 'SipSigConnStatisticsStats' , 'SipSigPortStatisticsStats' , 'SipSigPortTlsStats' , 'SipSubCountStats' , 'SystemCongestionIntervalStats' , 'TcpGeneralGroupStats' , 'TrafficControlStats' , 'UdpGeneralGroupStats' , 'ZoneIntervalStatisticsStats' , 'DspResDspCallIntervalStats' , 'EthernetPortPacketStats' , 'IcmpGeneralGroupStats' , 'SYSMEMORYUTILINTSTATSSTS' , 'H323SigPortStatisticsStats' , 'IpGeneralGroupStats' , 'SYSCPUUTILINTSTATSSTS' , 'NBS5200TrunkGroupStatusStats' , 'NBS5200SYSTEMLICENSEINFOSTATS' , 'NBS5200CallCountStats' , 'SBX5KSIPOCSCALLINTERVALSTATS' , 'SBX5KMtrmConnPortPeerStats' , 'SBC1000PTStats' , 'SBC1000ChannelStatusStats' , 'SBC2000PTStats' , 'SBC2000ChannelStatusStats' );
    my @cmd_res = ();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($dbresult,$cmd) = '';
    my $result = 1;
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    my $prePrompt = $self->{conn}->prompt;
    
    #switching  to oracle user
    unless ( $self->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub:  failed to login as oracle");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }


    $logger->info(__PACKAGE__ . ".$sub: Entering SQL");
    $self->{conn}->prompt('/SQL\> $/');

    unless ($self->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd", Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER SQL ");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    foreach my $tab (@tables) {
	$tab = "SBCEDGE".$1 if(SonusQA::Utils::greaterThanVersion($self->{VERSION},'V11.01.00') and $tab =~ /SBC\d{4}(ChannelStatusStats|PTStats)/);
        @cmd_res = $self->execCmd("truncate table $tab ;",3600);
            unless ( grep(/Table truncated/ , @cmd_res)) {
                $logger->error(__PACKAGE__ . ".$sub: Error truncating table  $tab" . Dumper(\@cmd_res));
		$dbresult = $dbresult . "Error truncating table  $_ :";
	    	$result = 0;	
            }
        $logger->info(__PACKAGE__ . ".$sub: Truncated table $tab");
    }
    #Setting the GSX connectivity based on the args passed from the user
    if((defined $args{-GsxCon}) && (uc"$args{-GsxCon}" eq 'SSH')) {
         $logger->info(__PACKAGE__ . ".$sub: GSX to be configured as SSH");
         $cmd = 'Update dbimpl.node set sshenabled=1 where type=\'GSX9000\';';
     } else {
         $logger->info(__PACKAGE__ . ".$sub: GSX to be configured as Telnet");
         $cmd = 'Update dbimpl.node set sshenabled=0 where type=\'GSX9000\';';
     }
     @cmd_res = $self->execCmd("$cmd",3600);
     unless ( grep(/rows? updated/ , @cmd_res)) {
          $logger->error(__PACKAGE__ . ".$sub: Error setting/unsetting the SSH  " ."$cmd" . Dumper(\@cmd_res));
          $result = 0;
          $dbresult.= " Error setting/unsetting the SSH $cmd"; 
      } else {
          $logger->info(__PACKAGE__ . ".$sub: Successully set the SSH :".$cmd);
      }	
	

    @cmd_res = $self->execCmd("commit;");
    unless(grep(/Commit.*complete/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO COMMITT CHANGES");
	$dbresult = $dbresult . "UNABLE TO COMMITT CHANGES";
        $result = 0;
    }
    $self->{conn}->cmd("exit");
    $self->{conn}->prompt($prePrompt);
    # Exiting from oracle login
    $self->exitUser();#TOOLS-18820

    unless($result) {
    $logger->error(__PACKAGE__ . ".$sub: Errors are : $dbresult");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [0]");
	
	return $result;
     } else {
        $logger->debug(__PACKAGE__ . ".$sub: Successfully deleted all tables");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [1]");
	return $result;
     }
}

=head1 B<pm_db_enable()>

=over 6

=item Description:

 This function does the following 
	1. Disables the PM collection for all nodes
	2. Enables collection from the start node to number of nodes given in number
	3. If the Mode is FTP will enable FTP else disable FTP
 EMS needs a restart for the effect to be reflected

=item Arguments:

 Mandatory
          -start_node 	: nodeid of the starting node to enable collection for
          -number 	: number of nodes to enable collection for
          -mode   	: SNMP or FTP
 Optional
          -exportDelay 	: Whether to Enable export delay. By default this is set to n .

=item Return Value:

 0 - on failure
 1 - on success

=item Usage:
    
 my $result = $emsObj->pm_db_enable( -start_node => '12345', -number => '200', -mode = 'SNMP' | 'FTP' , -exportDelay => y);

=back

=cut


sub pm_db_enable {

    my ($self,%args) = @_;
    my $sub = "pm_db_enable";
    my $sql_userid = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $sql_passwd = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
    my @cmd_res = ();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $dbresult = '';
    my $result = 1;
    my $cmd = '';
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    foreach ('-start_node','-number', '-mode') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: mandatory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    my $prePrompt = $self->{conn}->prompt;

    #switching  to oracle user
    unless ( $self->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub:  failed to login as oracle");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }


    $logger->info(__PACKAGE__ . ".$sub: Entering SQL");
    $self->{conn}->prompt('/SQL\> $/');

    unless ($self->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd",  Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER SQL ");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    #Disbaling the Perfdata collection for all nodes
    @cmd_res = $self->execCmd("update dbimpl.node set perfdatacollecting=0;",3600);

    #Reading the nodeid from db based on node name
    @cmd_res = $self->execCmd("select nodeid from dbimpl.node  where name = '$args{-start_node}' ;",3600);
    unless ( grep(/NODEID/ , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub: Error fectching nodeid  " . Dumper(\@cmd_res));
        $result = 0;
    }
    else {
        $logger->info(__PACKAGE__ . ".$sub: start nodeid fetched");
   }
   my $start_nodeid= $cmd_res[2];
   chomp ($start_nodeid);
   my $last_nodeid = $start_nodeid + $args{-number} - 1;

   #Reading the Node type from DB
   @cmd_res = $self->execCmd("select TYPE from dbimpl.node  where name = '$args{-start_node}' ;",3600);
   unless ( grep(/TYPE/ , @cmd_res)) {
       $logger->error(__PACKAGE__ . ".$sub: Failed : Error fetching NODE TYPE  " . Dumper(\@cmd_res));
       $result = 0;
   } else {
       $logger->info(__PACKAGE__ . ".$sub: Success : NODE TYPE fetched");
   }
   my $nodetype = $cmd_res[2];
   chomp ($nodetype);

   #Setting the datacollection flag for the nodes
   @cmd_res = $self->execCmd("update dbimpl.node set perfdatacollecting=1 where nodeid between $start_nodeid and $last_nodeid ;",3600);
   unless ( grep(/$args{-number} rows updated/ , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub: Error enabling collection  " . Dumper(\@cmd_res));
        $result = 0;
   } else {
        $logger->info(__PACKAGE__ . ".$sub: enabled collection");
   }
       
   #Determining Starting Sequence number and Property Name based on Node Type
   my $sequencenum = ($nodetype eq 'SBX5K') ? '0':'16777210'; 
   my $propname = ($nodetype eq 'SBX5K') ? 'sonus.pm.enableFTPCollection.sbc':'sonus.pm.enableFTPCollection';  
        
   if ($args{-mode} eq 'FTP') {
      @cmd_res = $self->execCmd("update dbimpl.pm_ftpfilesequencedetails set sequencenum=$sequencenum ;",3600);
      unless ( grep(/rows updated/ , @cmd_res)) {
          $logger->error(__PACKAGE__ . ".$sub: Error setting filesequencenum  " . Dumper(\@cmd_res));
          $result = 0;
      }  else {
        $logger->info(__PACKAGE__ . ".$sub: file sequence number set");
      }

      @cmd_res = $self->execCmd("update dbimpl.config_properties set propvalue='true' where propname='$propname' ;",3600);
      unless ( grep(/row updated/ , @cmd_res)) {
          $logger->error(__PACKAGE__ . ".$sub: Error enabling FTP colletion  " . Dumper(\@cmd_res));
          $result = 0;
      } else {
          $logger->info(__PACKAGE__ . ".$sub: FTP collecton enabled");
      }
   } else {
       @cmd_res = $self->execCmd("update dbimpl.config_properties set propvalue='false' where propname='$propname' ;",3600);
       unless ( grep(/row updated/ , @cmd_res)) {
          $logger->error(__PACKAGE__ . ".$sub: Error disabling FTP collection  " . Dumper(\@cmd_res));
          $result = 0;
       } else {
          $logger->info(__PACKAGE__ . ".$sub: FTP collection disabled");
      }
   }
	
   #Setting the Export Delay if the user wants it or else setting to disbaled by default
   if(lc "$args{-exportDelay}" eq 'y' ) {
      $cmd = "update dbimpl.config_properties set propvalue='true' where propname='sonus.pm.export.delay.interval';";
      $logger->info(__PACKAGE__ . ".$sub: Delay Export of Data by a Collection Interval will be enabled");
   } else {
      $cmd = "update dbimpl.config_properties set propvalue='false'  where propname='sonus.pm.export.delay.interval';";
      $logger->info(__PACKAGE__ . ".$sub: Delay Export of Data by a Collection Interval will be disabled");
   }
   @cmd_res = $self->execCmd("$cmd",3600);
   unless ( grep(/row updated/ , @cmd_res)) {
      $logger->error(__PACKAGE__ . ".$sub: Error enabling/disabling Delay Export of Data by a Collection Interval  " . Dumper(\@cmd_res));
      $result = 0;
   } else {
      $logger->info(__PACKAGE__ . ".$sub: Enabling/Disabling of Delay Export of Data by a Collection Interval succeeded");
   }

   @cmd_res = $self->execCmd("commit;");
   unless(grep(/Commit.*complete/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO COMMITT CHANGES");
        $dbresult = $dbresult . "UNABLE TO COMMITT CHANGES";
        $result = 0;
   }

   # Exiting from oracle login
   $self->exitUser();#TOOLS-18820
   $self->{conn}->prompt($prePrompt);

   unless($result) {
      $logger->error(__PACKAGE__ . ".$sub: <-- Leaving sub. [0]");
      $logger->error(__PACKAGE__ . ".$sub: Errors are : $dbresult");
      return $result;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [1]");
       $logger->debug(__PACKAGE__ . ".$sub: Suceefully deleted all tables");
       return $result;
    }

}

=head1 B<pmdbDisable()>

=over 6

=item Description:

 This function will be called to disable the PM collection for the devices. After this the EMS has to be restarted
 This will blindly set perfdatacollecting to 0 in the node able for the all nodes resigistered in the EMS 

=item Arguments:
    
 None

=item Return Value:

 0 - on failure
 1 - on success

=item Usage:
    
 my $result = $emsObj->pmdbDisable();

=back

=cut


sub pmdbDisable {

    my ($self) = @_;
    my $sub = "pmdbDisable";
    my $sql_userid = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $sql_passwd = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");
    my $cmd="update dbimpl.node set perfdatacollecting=0;";
    my $timeout=3600;
    unless($self->sqlplusCommand($cmd,$sql_userid,$sql_passwd,$timeout)){
	$logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER sqlplusCommand sub");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	return 0 ;
    }
     else {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [1]");
        $logger->debug(__PACKAGE__ . ".$sub: Suceefully deleted all tables");
        return 1;
     }

}

=head1 B<verifyCpsAlarms()>

=over 6

=item Description:

 This function is used to validate the Alarm msg time stamp with input timestamps (function add -cpsInterval for all input timestamp and add 5 hours 30 minutes for IST)

=item Arguments:
  
 Mandatory :
    -file => file containing alaram msgs(trap log), includes complete path
    -pattern => A array reference having alaram pattern msgs
    -timeStamp => A array reference having timestamp for the above respective pattern array
  
 Optional :
    -cpsInterval => cps time interval in seconds, default is 30

=item Return Value:

 0 - on failure
 1 - on success

=item Usage:
 
 my $result = $emsObj->verifyCpsAlarms(-file => '/opt/sonus/netcool/omnibus/log/222.txt', -pattern => ['20% License threshold exceeded for Ingress Interface SIP', 
 '30% License threshold exceeded for Ingress Interface SIP'], -timeStamp => ['2013-05-27,18:29:08','2013-05-27,18:30:08'], -cpsInterval => 30);

=back

=cut

sub verifyCpsAlarms {
    my ($self,%args) = @_;
    my $sub_name = "verifyCpsAlarms";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name --> Entered Sub ");

    foreach ('-timeStamp', '-pattern', '-file') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name:  manditory argument \'$_\' is blank or not defined");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    my (@unixTime, %result, @content);
    #redirecting error to /dev/null, so that it won't affect the output check
    unless ( @content = $self->{conn}->cmd("cat $args{-file} 2> /dev/null")) {
        $logger->error(__PACKAGE__ . ".$sub_name: faile to get content of \'$args{-file}\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    #checking the status of the command and logging it
	my ($status_code) = $self->{conn}->cmd('echo $?');
	chomp($status_code);
    unless($status_code == 0){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to execute the command 'cat $args{-file} 2> /dev/null'");
    }

    $args{-cpsInterval} ||= 30;

    # converting to unix timestamp
    foreach (@{$args{-timeStamp}}) {
        next unless ($_ =~ /(\d+)\-(\d+)\-(\d+),(\d+)\:(\d+)\:(\d+)/);
        my $temp = timelocal($6,$5,$4,$3,$2,$1) + $args{-cpsInterval};
        my $istTime = 5*60*60+30*60;
        push (@unixTime, $temp, ($temp - $istTime));
    }

    # getting timestamp of pattern and converting to unix timestamp
    foreach my $pat (@{$args{-pattern}}) {
        my @temp = grep(/\Q$pat\E/i, @content);
        foreach (@temp) {
            next unless ($_=~ /(\d+)\/(\d+)\/(\d+) (\d+)\:(\d+)\:(\d+)/);
            push (@{$result{$pat}}, timelocal($6,$5,$4,$2,$1,$3));
        }
    }

    my $lastIndex = (scalar @{$args{-pattern}} ) - 1;
    for my $i (0..$lastIndex) {
        foreach my $alramTime ( @{$result{$args{-pattern}->[$i]}}) {
            my $k = (abs($unixTime[$i] - $alramTime ) > 18000) ? $i+1 : $i;
            if ( $alramTime < $unixTime[$k]) {
                $logger->error(__PACKAGE__ . ".$sub_name: \'$args{-pattern}->[$i]\' occurance time \'". &get_date($alramTime) . "\' is less than cps time \'" . &get_date($unixTime[$k]));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            if ($i == 0) {
                $logger->info(__PACKAGE__ . ".$sub_name: \'$args{-pattern}->[$i]\' occurance time \'" . &get_date($alramTime) . "\' matches the cretiria with cps time \'" . &get_date($unixTime[$k]));
                next;
            }
            if ($alramTime <= $unixTime[$k -2]) {
                $logger->error(__PACKAGE__ . ".$sub_name: \'$args{-pattern}->[$i]\' occurance time \'" . &get_date($alramTime) . "\' is less than cps time \'" .  &get_date($unixTime[$k-1]));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            $logger->info(__PACKAGE__ . ".$sub_name: \'$args{-pattern}->[$i]\' occurance time \'" . &get_date($alramTime) . "\' matches the cretiria with cps time \'" . &get_date($unixTime[$k]));

        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head1 B<get_date()>

=over 6

=item Description:

 This function is for internal use of verifyCpsAlarms

=back

=cut

sub get_date {
        my $date = shift;
        my %return;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime($date);

        $mon++;
        $year += 1900;

        return "$mon/$mday/$year $hour:$min:$sec";
}

=head1 B<EMS_Logs_Collect()>

=over 6

=item Description:

 This function  
	1) just collects all the logs of EMS and dumps in the ATS logs
	2) Collects the Core files and dumps in ATS log folder
	3) Checks if the Queueoverflow alarm is there, and copies the sonustrap.log if  Queueoverflow is raised by the EMS

=item Arguments:
   
 1. -path => Mandatory. Path where EMS logs have to be collected.

=item Return Value:

 1 - on success
 0 - on failure

=item Usage:

 my $result =  $emsObj->EMS_Logs_Collect();

=back

=cut

sub EMS_Logs_Collect {

my ($self, %args )=@_;
my $sub = "EMS_Logs_Collect";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
my @cmd_res = ();
my $cmd ;
my $testResult = 1;
my $testCaseId = '';
unless ( defined ( $args{-path} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -path has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}
#Deriving the test case id from path
if($args{-path}  =~ m/.*\/EMS\/(EMS[0-9a-zA-Z_\-]*)\/.*/i) {
   $testCaseId = $1;
}


my $dut_Logs = $args{-path}."/dut_Logs/";
my $core_logpath = $args{-path}."/Core_Logs/";

$logger->info(".$sub Creating dir : $dut_Logs , $core_logpath ");
unless (mkpath($dut_Logs)) {
    $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir : $dut_Logs");
}

unless (mkpath($core_logpath)) {
    $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir : $core_logpath");
}

#General Logs
my $ems_reachability_log = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/reachability_audit_log*";
#PM related logs
my $ems_trace_log = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/ems_trace_log*";
my $emsOutput_log = "$self->{BASEPATH}" . "/emsOutput.log*";
my $pm_trace_log  = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/pm_trace_log*";
my $pm_diagnos_trace_log  = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/pm_diagnos_trace_log*";
my $hibernate_log  = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/hibernate_log*";
my $quartz_log  = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/quartz_log*";

#FM related logs
my $fm_trace_log  = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/fm_trace_log*";
my $sonus_trap_log = "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.log*';
my $sonus_trap_trace = "$self->{BASEPATH}" . '/../netcool/omnibus/log/sonustrap.trace*';
my $fm_output_log = "$self->{BASEPATH}" . '/emsFM/logs/fmOutput.log*';
my $fm_receiver_trace = "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_trace*';
my $fm_receiver_audit = "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_audit*';
my $fm_receiver_trap_trace = "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_trap_trace*';
my $fm_receiver_diagnosis = "$self->{BASEPATH}" . '/emsFM/logs/fm_receiver_diagnosis*';
my $owl_log = "$self->{BASEPATH}" . '/emsFM/logs/owl.log*';
my $sonusFMSrvr_audit = "$self->{BASEPATH}" . '/emsFM/logs/sonusFMSrvr.audit*';

#API related logs
my $emsapi_debug_log = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/emsapi_debug_log*";
my $emsapi_prov_log = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/emsapi_prov_log*";

#CLI related logs
my $ems_cli_log   = "$self->{BASEPATH}" . "/weblogic/sonusEms/logs/sys/ems_cli_log*";

#Copying result sheet to ATS repository
my %scpArgs;
$scpArgs{-hostip} = $self->{OBJ_HOST};
$scpArgs{-hostuser} = 'root';
$scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
$scpArgs{-destinationFilePath} = $dut_Logs;

my @logNames = ($ems_reachability_log,$ems_trace_log,$emsOutput_log,$pm_trace_log,$pm_diagnos_trace_log,$hibernate_log,$quartz_log,$fm_trace_log,$sonus_trap_trace,$fm_output_log,$fm_receiver_trace,$fm_receiver_audit,$fm_receiver_trap_trace,$fm_receiver_diagnosis,$owl_log,$sonusFMSrvr_audit,$emsapi_debug_log,$emsapi_prov_log,$ems_cli_log);

foreach my $file (@logNames){
   $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$file;
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
     $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the log files : $file to $dut_Logs");
     $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
     $testResult = 0;
   }

}
$logger->debug(__PACKAGE__ . ".$sub:  SCP Success to copy the log files to $dut_Logs ");

#check if the core files are present in core log folder
my $numCores = $self->checkCore(-testCaseID => $testCaseId);
if ($numCores > 0 ) {
    $testResult = 0;
    $logger->error(__PACKAGE__ . ".$sub:  Copying $numCores core file  to $core_logpath");

    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$self->{coreDirPath}/*";
    $scpArgs{-destinationFilePath} = $core_logpath;
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
       $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the core files  to $core_logpath");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
       $testResult = 0;
    }
    $self->{root_session}->{conn}->cmd("rm -f $self->{coreDirPath}/*");
} elsif ($numCores < 0 ) {
     $logger->error(__PACKAGE__ . ".$sub: Failed to connect to SUT with root login and check the core files");
     $testResult = 0;
} else {
     $logger->info(__PACKAGE__ . ".$sub: No core files generated in $self->{coreDirPath}");
}


#Checking if the FMTrapFwdWOQueueOverflowNotification alarm in the Trap logs
$cmd = 'zgrep -c sonusEmsFMTrapFwdWOQueueOverflowNotification' .  " $sonus_trap_log" . ' | awk -F":" \'BEGIN {sum = 0 } {sum += $2} END{print sum}\'' if ($self->{PLATFORM} eq 'linux');
$cmd = 'grep -c sonusEmsFMTrapFwdWOQueueOverflowNotification' .  " $sonus_trap_log" . ' | awk -F":" \'BEGIN {sum = 0 } {sum += $2} END{print sum}\'' if ($self->{PLATFORM} eq 'SunOS');

@cmd_res = $self->execCmd("$cmd",300);
 if($cmd_res[0] != 0 ) {
      $logger->error(__PACKAGE__ . ".$sub:  OverFlowalarm is present in the sonustrap.log and the count is :$cmd_res[0]");
      
      $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$sonus_trap_log";
      $scpArgs{-destinationFilePath} = $dut_Logs;
      unless(&SonusQA::Base::secureCopy(%scpArgs)){
    	 $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the log files :$sonus_trap_log to $dut_Logs");
    	 $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
    	 $testResult = 0;
      }	
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
      $testResult = 0;
 }

#Gun-zip the log files and remove them from /dut_Logs path
@cmd_res = system('tar -zcvf' . " $dut_Logs" . 'dutlogs.tar.gz' . " $dut_Logs" . '*' . ' --remove-files');
$logger->info(__PACKAGE__ . ".$sub: All the DUT log files are gun-zipped to dutlogs.tar.gz file");

$logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
return $testResult;

}

=head1 B<emsLicense()>

=over 6

=item DESCRIPTION:

 This subroutine is used to push license from EMS to the target device

=item ARGUMENTS:

 Mandatory-
    $emsobject     - EMS object
    -deviceName    - Device Name in EMS
    -deviceType    - Device Type (PSX,SGX, etc)
    
 Optional-
    -emsIP        - EMS IP address

=item PACKAGE:

 SonusQA::EMS:EMSHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0   - fail
 1   - success

=item EXAMPLE:

 unless ( $ems_object->emsLicense(-deviceName => "monaco",-deviceType => "PSX") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot push the license from EMS");
        return 0;
 }

=back

=cut

sub emsLicense {

    my ($self) = shift;
    my ($deviceName,$deviceType,$emsIp);
    my $sub_name = "emsLicense";
    my (%args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ##################################################
    # Step 1: Checking mandatory args;
    ##################################################

    unless ( defined $args{-deviceType} ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -deviceType input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    unless ( defined $args{-deviceName} ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -deviceName input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    if( defined $args{-emsIP}){
	$emsIp = $args{-emsIP};
	$logger->debug(__PACKAGE__ . ".$sub_name: Taking emsip from arguments : \'$args{-emsIP}\' ");
    }else{
        $emsIp = $self->{OBJ_HOST};
    }
    $deviceName = $args{-deviceName};
    $deviceType = $args{-deviceType};
    unless ($self->discoverNode( -emsIp           => $emsIp,
                                 -deviceNameInEms => $deviceName,
                                 -deviceType      => $deviceType)) {
        $logger->error(__PACKAGE__ . ".$sub_name : unable to perform EMS -> Insight Administration -> \'$deviceType\' -> \'$deviceName\' -> Discover");
        return 0;
    }

    $emsIp = "[$emsIp]" if ($emsIp =~ m/::/);

    unless ($self->emsLogin(-emsIp => $emsIp)) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to login to EMS");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my ($retcode,$protocol_type);
    if( defined $self->{HTTPS} and $self->{HTTPS} == 1){ 
	$protocol_type = "https";
    }else{
	$protocol_type = "http";
    }

    $self->{curl}->setopt(CURLOPT_TIMEOUT,180);
    $self->{curl}->setopt(CURLOPT_HEADER,1);
    $self->{curl}->setopt(CURLOPT_FOLLOWLOCATION,1);
    $self->{curl}->setopt(CURLOPT_AUTOREFERER,1);
    $self->{curl}->setopt(CURLOPT_USERAGENT,"curl/7.19.6 (x86_64-pc-linux-gnu) libcurl/7.19.6 OpenSSL/0.9.8k zlib/1.2.3");
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYHOST, 0);
    # Store cookies in memory
    $self->{curl}->setopt(CURLOPT_COOKIEJAR,"-");
    $self->{curl}->setopt(CURLOPT_URL, "$protocol_type://$emsIp/coreGui/ui/logon/");
    $retcode = $self->{curl}->perform;

    # Get EMS Version
    if ($retcode == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name : ===== Get EMS Version =========");
        my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
        $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

        # judge result and next action based on $response_code
        unless ($response_code == 200) {
            $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
            $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt.");
            return 0;
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name : An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
        $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt");
        return 0;
    }

    $self->{curl_response_body} =~ m/.*V([0-9]{2}\.[0-9]{2}\.[0-9]{2}).*/;
    my $ems_version = $1;

    if ($deviceType eq 'SGX4000' && $ems_version gt '10.00.02') {
        my %featureHash = (
            'SGX-SS7' => 1,
            'SGX-SIG' => 1,
            'SGX-CAP-SM' => 1,
            'SGX-CAP-SM-TO-MED' => 1,
            'SGX-CAP-MED-TO-LRG' => 1,
            'SGX-DUAL-CE' => 1,
            'SGX-GR' => 1,
            'SGX-16NODES' => 1,
            'SGX-32NODES' => 1,
        );

        SonusQA::ATSHELPER::associateLicenses($emsIp, $deviceName, %featureHash);

        #clearing the HTTP data
        $self->{curl_response_body} = undef;
        $self->{curl_file_handle} = undef;
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully pushed the license to $deviceType");
        return 1;
    }

    MAIN: foreach my $attempt (1..3) {
        # Discovering the target
        $self->{curl}->setopt(CURLOPT_POST,0);
        $self->{curl}->setopt(CURLOPT_HTTPGET,1);
        $self->{curl}->setopt(CURLOPT_URL, "$protocol_type://$emsIp/emsGui/jsp/licmgmt/license/license.jsp?query=$deviceType" . '&cmd_sync_targets=Discover+Targets');
        $retcode = $self->{curl}->perform;

        if ($retcode == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name : ===== Discovering the target");
            my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
            $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

            # judge result and next action based on $response_code
            unless ($response_code == 200) {
                $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
                $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
                next MAIN;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name :An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
            $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
            next MAIN;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: sleep for 20 secs after Discovering the target");
        sleep(20);
        # Get OID for our target device
        $self->{curl}->setopt(CURLOPT_POST,0);
        $self->{curl}->setopt(CURLOPT_HTTPGET,1);
        $self->{curl}->setopt(CURLOPT_URL, "$protocol_type://$emsIp/emsGui/jsp/licmgmt/license/license.jsp?query=$deviceType,$deviceName");
        $retcode = $self->{curl}->perform;

        if ($retcode == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name : ===== Get OID =========");
            my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
            $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

            # judge result and next action based on $response_code
            unless ($response_code == 200) {
                $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
                $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
                next MAIN;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name : An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
            $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
            next MAIN;
        }

        my $oid = $self->{curl_response_body};

        # Good old multi-line replace :)
        $oid =~ s/.*name="targetOid" value="//s;
        $oid =~ s/".*//s;

        $logger->debug(__PACKAGE__ . ".$sub_name : Got oid $oid for device \'$deviceName\'");

        # Following GET seems to be necessary in perl - not in the shell script...
        $self->{curl}->setopt(CURLOPT_URL, "$protocol_type://$emsIp/emsGui/jsp/licmgmt/license/setTargetLicense.jsp?targetType=$deviceType&targetOid=$oid");

        $retcode = $self->{curl}->perform;

        if ($retcode == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name : ===== Get License ========");
            my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
            $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

            # judge result and next action based on $response_code
            unless ($response_code == 200) {
                $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
                $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
                next MAIN;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name : An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
            $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
            next MAIN;
        }

        # Re-Push the existing license
        $self->{curl}->setopt(CURLOPT_URL, "$protocol_type://$emsIp/emsGui/jsp/licmgmt/license/setTargetLicense.jsp");
        $self->{curl}->setopt(CURLOPT_POST,1);
        $self->{curl}->setopt(CURLOPT_POSTFIELDS, "targetType=$deviceType&targetOid=$oid&cmd_ok=OK");
        $retcode = $self->{curl}->perform;

        if ($retcode == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name : ===== Push License =========");
            my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
            $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

            # judge result and next action based on $response_code
            unless ($response_code == 200) {
                $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code"   );
                $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
                next MAIN;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name : An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
            $logger->debug(__PACKAGE__ . ".$sub_name : Failure occured in attempt $attempt. Retrying..");
            next MAIN;
        }

      #clearing the HTTP data
      $self->{curl_response_body} = undef;
      $self->{curl_file_handle} = undef;
      $logger->debug(__PACKAGE__ . ".$sub_name: Successfully pushed the license to $deviceType");
      return 1;
   }
   $logger->debug(__PACKAGE__ . ".$sub_name: All 3 attempts to push the license to $deviceType failed");
   return 0;
}

=head1 B<checkCore()>

=over 6

=item Description:

 This subroutine checks for core file in EMS. If core file is present, the file is renamed with the test case ID

=item Arguments :
   
 The mandatory parameters are
      -testCaseID   => Test case ID

=item Return Values :

 0  : No core files found
 m  : Number of core files found

=item Example :
   
 $emsObj->checkCore(-testCaseID => $testId);

=back

=cut


sub checkCore {
   my ($self, %args) = @_;
   my $sub = "checkCore()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my ($cmdString,@cmdResults);
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value };

   # Setting the Core directory
   unless ( $self->{coreDirPath} ) {
	$self->{coreDirPath} = "/home/core/" if ( $self->{PLATFORM} eq 'linux');
	$self->{coreDirPath} =  "/export/home/core/" if ($self->{PLATFORM} eq 'SunOS');
   }

   unless ( $self->{root_session} ) {
   # get the required information from TMS
   my $emsIPAddress    = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
   my $emsRootPassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};

   $self->{root_session} = new SonusQA::Base( -obj_host       => "$emsIPAddress",
                                         -obj_user       => "root",
                                         -obj_password   => "$emsRootPassword",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 120,
                                       );
       unless ( $self->{root_session} ) {
          $logger->error(__PACKAGE__ . ".$sub: Could not open connection to EMS on $emsIPAddress");
          return -1;
       }
   }


   # get the core file names
   $cmdString = "ls -1 $self->{coreDirPath}/core*";
   $logger->debug(__PACKAGE__ . ".$sub executing command $cmdString");
   my @coreFiles = $self->{root_session}->{conn}->cmd("$cmdString");
   $logger->debug(__PACKAGE__ . ".$sub ***** \n @coreFiles \n\n ******* ") ;

   foreach(@coreFiles) {
      if(m/No such file or directory/i) {
         $logger->info(__PACKAGE__ . ".$sub No cores found");
         return 0;
      }
   }

   # Get the number of core files
   my $numcore = $#coreFiles + 1;
   $logger->info(__PACKAGE__ . ".$sub Number of cores in EMS is $numcore");
   my $cmd;

   # Move all core files
   foreach (@coreFiles) {
      if( /$cmdString/ ) {
         #skip the first line if its the command
         next;
      }
      my $core_timer = 0;
      chomp($_);
      my $file_name = $_;

      # wait till core file gets generated full
      while ($core_timer < 120) {
         # get the file size
         $cmd = "ls -l $file_name";

         my @fileDetail = $self->{root_session}->{conn}->cmd($cmd);
         $logger->debug(__PACKAGE__ . ".$sub @fileDetail");

         my $fileInfo;
         #start_size of the core file
         my $start_file_size;

         foreach $fileInfo (@fileDetail) {
            if( $fileInfo =~ /$cmd/ ) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;
            $start_file_size = $1;
         }
         $logger->debug(__PACKAGE__ . ".$sub Start File size of core file $file_name is $start_file_size");
         sleep(5);
         $core_timer = $core_timer + 5;
         #end_size of the core file;
         my $end_file_size;
         @fileDetail = $self->{root_session}->{conn}->cmd($cmd);

         foreach $fileInfo (@fileDetail) {
            if( $fileInfo =~ /$cmd/ ) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;
            $end_file_size = $1;
         }

         $logger->debug(__PACKAGE__ . ".$sub End File size of core file $file_name is $end_file_size");
         if ($start_file_size == $end_file_size) {
            $file_name =~ s/$self->{coreDirPath}\///g;
            my $name = join "_",$args{-testCaseID},$file_name;
            # Rename the core to filename with testcase specified
            $cmd = "mv $self->{coreDirPath}/$file_name $self->{coreDirPath}/$name";
            my @retCode = $self->{root_session}->{conn}->cmd($cmd);
            $logger->info(__PACKAGE__ . ".$sub Core found in $self->{coreDirPath}/$name");
            last;
         }
      }
   }
   return $numcore;
}

=head1 B<netcoolDBlogin(), netcoolTrapcleanup(), netcoolCMDexecute(), netcoolDBexit()>

=over 6

=item Description:

 These functions are used for complete funcationality of Netcool DB, such as login, cleanup, command execute and exit.

=item Arguments:
     
 Mandatory
         <Refer each function respectively>

=item Return Value:

 <Refer each function respectively>
     
=item Usage:
    
 unless (SonusQA::EMS::EMSHELPER::netcoolDBlogin ($self)) {
		print "Netcool DB login failure";
 }
 if (my $ret = SonusQA::EMS::EMSHELPER::netcoolTrapcleanup($self, "D01")){
		my @res = SonusQA::EMS::EMSHELPER::netcoolCMDexecute ($self, "SELECT Summary from alerts.status where Node = 'D01';");
		print Dumper(@res);
		unless (SonusQA::EMS::EMSHELPER::netcoolDBexit ($self)){
			print "Netcool DB exit failure\n";
		}
 }
 else{
		print "Cleanup Failure\n";
 }

=back

=cut

=head1 B<netcoolDBlogin()>

=over 6

=item Description:

 This function provides the user the functionality of login to the netcool DB of the EMS user as logged in.

=item Arguments:
     
 Mandatory
         EMS login object ($self)

=item Return Value:

 0 - on login failure
 1 - on login success
     
=item Usage:
    
 unless (SonusQA::EMS::EMSHELPER::netcoolDBlogin ($self)) {
	print "Netcool DB login failure";
 }

=back

=cut

sub netcoolDBlogin {
	#change directory path to login to netcool DB
	my  $sub_name = "netcoolDBlogin";
	my ($self) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	$self->execCmd("cd /opt/sonus/netcool/omnibus/bin");
	$self->execCmd("perl -pi -e 's/isql -S/isql -w 2000 -S/' nco_sql");
	$self->{conn}->prompt('/> $/');
	unless ($self->execCmd("./nco_sql -server SONUSDB -user Insight_Admin_User -password sonus")) {
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
}

=head1 B<netcoolTrapcleanup()>

=over 6

=item Description:

 This function provides the user the functionality to clear all the traps of the particular SBC node passed as arguement in netcool DB of the EMS user as logged in.

=item Arguments:
     
 Mandatory
         EMS login object ($self)
	 SBC node name ("<sbcNodename")

=item Return Value:

 0 - on traps cleanup failure
 1 - on traps cleanup success
     
=item Usage:
   
 my $ret = SonusQA::EMS::EMSHELPER::netcoolTrapcleanup($self, "D01")

=back

=cut

sub netcoolTrapcleanup {
	#delete all the traps related to the node $sbcNodename
	my  $sub_name = "netcoolTrapcleanup";
	my ($self,$sbcNodename) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	$self->execCmd("delete from alerts.status where Node = \'$sbcNodename\';");
	$self->execCmd("go");

	#verify deletion of traps are successfull
	$self->execCmd("SELECT Summary from alerts.status where Node = \'$sbcNodename\';");
	my @verify;
	unless (@verify = $self->execCmd("go")){
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Delete of alerts failed. @verify");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
	unless (grep(/0 rows affected/, @verify)) {
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
}

=head1 B<netcoolCMDexecute()>

=over 6

=item Description:

 This function provides the user the functionality to execute the command on netcool DB of the EMS user as logged in.

=item Arguments:
   
   Mandatory
         EMS login object ($self)
	 Command to be executed ("<netcool DB command to be executed>")

=item Return Value:

 result - result of the command executed in array
     
=item Usage:
    
 my @res = SonusQA::EMS::EMSHELPER::netcoolCMDexecute ($self, "SELECT Summary from alerts.status where Node = 'D01';");

=back

=cut

sub netcoolCMDexecute {
	#Execute the command '$cmd' as requested by the user on the node 'sbcNodename'
	my  $sub_name = "netcoolCMDexecute";
	my ($self, $cmd) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	$self->execCmd("$cmd");
	my @result = $self->execCmd("go");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
	return @result;
}

=head1 B<netcoolDBexit()>

=over 6

=item Description:
     
 This function provides the user the functionality to execute the command on netcool DB of the EMS user as logged in.

=item Arguments:
     
 Mandatory
         EMS login object ($self)
		 
=item Return Value:

 0 - on exit failure
 1 - on exit success
     
=item Usage:
    
 SonusQA::EMS::EMSHELPER::netcoolDBexit ($self)

=back

=cut

sub netcoolDBexit {
	my  $sub_name = "netcoolDBexit";
	my ($self) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	$self->{conn}->prompt($self->{PROMPT});
	if (my @temparray = $self->execCmd("exit")){
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
}

=head1 B<Inventory_loss()>

=over 6

=item Description:

 This subroutine calculates the count of expected reports and calculates the inventory loss by comparing it with the expected stats

=item Arguments:

 $exp_count - Expected count

=item Return:

 0 - loss %age is greater than 0.1
 1 - loss %age is less than 0.1 

=back

=cut

sub Inventory_loss {

     my ($self, $exp_count) = @_;
     my @cmd_res = ();
     my $sub = "Inventory_loss";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     my $dir="/export/home/ems/weblogic/sonusEms/data/inventoryReports";
     my @interval_count = ();
	 my @reports_count = ();
     $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
     my $cmd = '';

     unless( $exp_count ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory expected count input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     unless ( $dir ) {
         $logger->error(__PACKAGE__ . ".$sub: Mandatory directory input is empty or blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }

     @cmd_res = $self->execCmd("cd $dir");
     if(grep ( /no.*such/i, @cmd_res)) {
         $logger->error(__PACKAGE__ . ".$sub $dir directory not present");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub Changed directory to $dir");

     #check the number of records in the directory
     $cmd = "ls -lrt |wc -l";
     
     $logger->debug(__PACKAGE__ . ".$sub: Executing $cmd");
     @reports_count = $self->execCmd( " $cmd", 7200);
     unless(@reports_count) {
         $logger->error(__PACKAGE__ . ".$sub Failed to get the Count of reports exported");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }

     $logger->info(__PACKAGE__ . ".$sub No of reports currently exported " . Dumper(\@reports_count));
     
	 
	 
	 
	 $exp_count = $exp_count*$reports_count[0];
     $logger->info(__PACKAGE__ . ".$sub: Total no of stats expected for the run :" . " $exp_count");


     #Checking the record count of all nodes and all the intervals
     
     $cmd = "zgrep -c EMSPET1 * | awk -F\":\" 'BEGIN {SUM=0} {SUM += \$2} END { printf  SUM}'";
  
     $logger->debug(__PACKAGE__ . ".$sub: Executing $cmd");
     @cmd_res = $self->execCmd("$cmd",7200);
     unless(@cmd_res) {
         $logger->error(__PACKAGE__ . ".$sub Failed to fetch the stats in Inventory export data");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->info(__PACKAGE__ . ".$sub: Total No of Inventory stats  exported in EMS_SUT:" . " $cmd_res[0]" );


     my $loss = eval{sprintf "%0.3f",100*(1-$cmd_res[0]/$exp_count)};

     #Printing the stats to result file
     my $fp;
     open $fp , ">>", "$self->{result_path}/Testcase_Results.txt";
     print $fp "##########################\n";
     print $fp "Inventory Loss Summary  \n";
     print $fp "##########################\n";
     print $fp "Total No of stats expected : $exp_count\n";
     print $fp "Total No of stats  exported in EMS_SUT: $cmd_res[0]\n";
     print $fp "The Inventory Loss for the test case is :$loss %\n";
     close $fp;

     if(eval{sprintf "%0.3f",$cmd_res[0]/$exp_count}  < 0.999 ) {
         $logger->error(__PACKAGE__ . ".$sub:Loss is greater than 0.1%.The loss is :"  . $loss . '%');
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
     }
     $logger->info(__PACKAGE__ . ".$sub:The loss %age is less than 0.1 and the loss for current test case is :" .  $loss . '%' );
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
     return 1;
 }

=head1 B<emsUpgrade()>

=over 6

=item Description:

 This function provides the user upgrade the EMS using iso

=item Arguments:

 Mandatory
         EMS login object ($self)

=item Return Value:

 0 - on exit failure
 1 - on exit success

=item Usage:

 SonusQA::EMS::EMSHELPER::emsUpgrade ($self)

=back

=cut

sub emsUpgrade {
    my($self, %args)=@_;
    my $sub_name = 'emsUpgrade';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $dir = '/opt/sonus/emsInstall/';
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $rebootFlag = '0';
    foreach ('-basePath','-upgradeFileName', '-isoname') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
            return 0;
        }
    } 
   

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Dumper Value :".Dumper(\%args));
 #   $logger->debug(__PACKAGE__ . ".$sub_name: -->Self  Dumper Value :".Dumper(\$self)); 
    my $cmd = "nohup" . ' ' . "$dir" . '/' . "$args{-upgradeFileName}" . ' -p ' . "$args{-basePath}" . '/' . "$args{-isoname}" . ' ' . "&";


    $logger->debug(__PACKAGE__ . ".$sub_name: <---- cmd : $cmd");


    my $timeout = $args{-timeout} || 10800;
    my ($prematch, $match);
	
	my $isHa = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{USER_DATA};
    my $emsIPAddress = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    
    #switching  to root user
    #This is commented because of https://jira.sonusnet.com/browse/INS-31319, once the JIRA is resolved in 11.0 this code needs to be uncommented.
    unless ( $self->becomeUser(-userName => 'root',-password =>$self->{ROOTPASSWD}) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as sonus");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }


    my $copyCmd = "mv -f $args{-basePath}" . '/' . "$args{-upgradeFileName}" . " " . "$dir";
    my $timeTaken = time;
    if ( -d $dir)
    {
        $logger->error(__PACKAGE__ . ".$sub_name: $dir already exists");
    } else {
    unless ( $self->{conn}->print("mkdir $dir") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to create $dir");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Successfully created $dir");
    }
    if ( -f "$dir" . '/' . "$args{-upgradeFileName}")
    {
        $logger->error(__PACKAGE__ . ".$sub_name: $args{-upgradeFileName} already exists in $dir");
    } else {
    unless ( $self->{conn}->print( $copyCmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$copyCmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Successfully copied $args{-upgradeFileName} to $dir");   
    }
 
    my $changePermission = "chmod 755 $dir" . "$args{-upgradeFileName}";
    unless ( $self->{conn}->print( $changePermission ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$changePermission\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Successfully changed the permission of $args{-upgradeFileName} file.");

	    if($isHa == 1) {
          unless ( $self->{conn}->print("rm -rf /var/sadm/install/logs/EMSinstall*") ) {
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
          return 0;
       }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Successfully removed /var/sadm/install/logs/EMSinstall* file from EMS");
      } else {	
        unless ( $self->{conn}->print("rm -rf /var/sadm/install/logs/upgradeEMS.log") ) {
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
          return 0;
       }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Successfully removed /var/sadm/install/logs/upgradeEMS.log file from EMS");		
	  }
		

    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: ********** EMS Upgrade Started Please Wait .. ************"); 

	my  $max_attempts = 120;
	
	if($isHa == 1) {
     #for HA upgrade
       $logger->debug(__PACKAGE__ . ".$sub_name: upgrade will take time and EMS boxes will reboot during this period. sleeping for 2.5 hours.");
       sleep(9000);
	   
	   $logger->debug(__PACKAGE__ . ".$sub_name: connection would be lost after reboot, so creating new root session..");

       my $rootObj = SonusQA::EMS->new( -obj_host => $emsIPAddress,
                                         -obj_user       => "root",
                                         -obj_password   => "sonus",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                                             -sessionlog => 1,
                                       );
	   
       for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){
        my @results = $rootObj->{conn}->cmd("grep 'EMS upgrade is complete' /var/sadm/install/logs/*");
        $logger->info(__PACKAGE__ . ".@results");

        if(grep /EMS upgrade is complete/, @results){
             $logger->info(__PACKAGE__ . "EMS Upgrade on G8 server is completed.");
             last;
        }
        else {
          if ($attempt < $max_attempts){
              $logger->error(__PACKAGE__ . "EMS Upgrade on G8 server is not completed.... Waiting for 5 Mins..");
              sleep(300);
         }
         else {
            $logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. EMS Upgrade on G8 server is not completed. Please check logs under /var/sadm/install/logs/");
            return 0;
         }
         }
       }
	   
      } else {
	 # for SA upgrade
	
     $self->{session} = new SonusQA::Base( -obj_host       => "$self->{OBJ_HOST}",
                                         -obj_user       => "root",
                                         -obj_password   => "$self->{ROOTPASSWD}",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                       );
      unless ( $self->{session} ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to EMS on $self->{OBJ_HOST}");
       return 0;
    }

   
      for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){
      
           my @upgraderesults = $self->{session}->{conn}->cmd("grep \"Upgrading OS if required\\|Platform upgrade is in progress\" /var/sadm/install/logs/upgradeEMS.log");
           $logger->info(__PACKAGE__ . " upgrade result : @upgraderesults");
           $logger->debug(__PACKAGE__ . ".$sub_name: ********** Checking the Platform Changes required or not  ************");
         if(grep /OS Upgrade is not required, hence skipping/i,@upgraderesults){

             $logger->error(__PACKAGE__ . "<-----------OS Upgrade is not required. EMS not rebooting");
             last;
        }elsif(grep /Platform upgrade is in progress/i,@upgraderesults){
             $logger->debug(__PACKAGE__ . ".$sub_name: ********** EMS will be Rebooted  ************");
            # sleep(600);
             $rebootFlag =1; 
             last;
        }else{
            if ($attempt < $max_attempts){

             $logger->error(__PACKAGE__ . "Upgrading OS message not recevied.... Waiting for 2 mins..");
             sleep(120);
            }
            else {
                $logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. Upgrading OS if required message not received. Please check the /var/sadm/install/logs/upgradeEMS.log");
                return 0;
            }
         }
      }

      if ($rebootFlag)
	{
        sleep(1800);
        my  $max_check = 20;
        for ( my $attempt =1; $attempt<=$max_check; $attempt++)
		{
			if( $self->{root_session} = new SonusQA::Base( -obj_host => "$self->{OBJ_HOST}",
                                         -obj_user       => "root",
                                         -obj_password   => "$self->{ROOTPASSWD}",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 300,
                                         -sessionlog => 1,
                                       ))
			{
				$logger->info(__PACKAGE__ . ".$sub_name: connection to primary EMS on $emsIPAddress is successfull after reboot");                    
				last;
			}
			else
			{
				if ($attempt < $max_check)
				{
					$logger->error(__PACKAGE__ . "connection to primary EMS on $emsIPAddress failed, still rebooting. Retrying....");
					sleep(600);
				}
				else 
				{
					$logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. Not able to login to primary EMS on $emsIPAddress ");
     			           return 0;
				}
			}	
	
		}
	}
      
      $self->{root_session} = new SonusQA::Base( -obj_host       => "$self->{OBJ_HOST}",
                                         -obj_user       => "root",
                                         -obj_password   => "$self->{ROOTPASSWD}",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 300,
                                         -sessionlog => 1,
                                       );
      unless ( $self->{root_session} ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to EMS on $self->{OBJ_HOST}");
       return 0;
      }



     my  $max_attempts = 24;
       for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){
	my @results = $self->{root_session}->{conn}->cmd("grep 'Upgrade completed successfully.' /var/sadm/install/logs/upgradeEMS.log");
	$logger->info(__PACKAGE__ . ".@results");

	if(grep /Upgrade completed successfully./, @results){

             $logger->info(__PACKAGE__ . "EMS Upgrade on G8 server is completed.");
             last;
        }
        else {
          if ($attempt < $max_attempts){

              $logger->error(__PACKAGE__ . "EMS Upgrade on G8 server is not completed.... Waiting for 5 mins..");
              sleep(300);
         }
         else {
            $logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. EMS Upgrade on G8 server is not completed. Please check the /var/sadm/install/logs/upgradeEMS.log");
            return 0;
         }
         }
       }
	   
	   }
	   
    $timeTaken = time - $timeTaken;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$timeTaken]");
    return $timeTaken;
}


=head1 B<checkEmsInstallationStatus()>

=over 6

=item Description:

 This function provides EMS Installation Status 

=item Arguments:

 Mandatory
         EMS login object ($self)

=item Return Value:

 0 - on exit failure
 1 - on exit success

=item Usage:

 SonusQA::EMS::EMSHELPER::emsInstallationStatus ($self)

=back

=cut

sub emsInstallationStatus {
    my($self)=@_;
    my $sub_name = 'emsInstallationStatus';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $file = '/tmp/emsUpgrade.status';
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    my @results = $self->{conn}->cmd("cat $file");
    $logger->info(__PACKAGE__ . ".@results");

    if(grep /Installation completed successfully/, @results) {
        $logger->info(__PACKAGE__ . ".$sub_name Installation completed successfully.");
    }
    else{
       $logger->info(__PACKAGE__ . ".$sub_name EMS Installation not complete.");  
       return 0; 
    }

    #switching  to root user
    unless ( $self->becomeUser(-userName => 'root',-password =>'sonus') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as sonus");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
   my @oraclePatchStatus = $self->{conn}->cmd("cat /root/emsKickstartInstall.log");
   $logger->info(__PACKAGE__ . ".@oraclePatchStatus");

   if(grep /Successfully restarted the database instance SIDB. Continuing with the rest of the upgrade.../, @oraclePatchStatus) {
        $logger->info(__PACKAGE__ . ".$sub_name Oracle Patch installation is completed ");
        return 1;  
   }
    else{
       $logger->info(__PACKAGE__ . ".$sub_name Oracle Patch installation is not complete.");
       return 0;
   }
 

}


=head1 confugureJumpstart() 

=over

=item DESCRIPTION: 

To execute configure Jumpstart on EMS

=item ARGUMENTS: 

None

=item AUTHOR: Sanjay Sequeira (ssequeira@rbbn.com)

=back

=cut

sub confugureJumpstart {
        my ($self,%args)=@_;
        my $sub_name = ".confugureJumpstart";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        $logger->debug(__PACKAGE__ . "$sub_name --> Entered");
        my ($prematch, $match);
       foreach ('-emsIP') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
            return 0;
        }
       }

       unless ( $self->becomeUser(-userName => 'root',-password =>'sonus') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as root user");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
       }



        $self->{conn}->print("/opt/sonus/ems/conf/configureJumpstart.sh");
        $logger->debug(__PACKAGE__ . "$sub_name Trying to run configureJumpstart  - waiting for IP address prompt");
        unless($self->{conn}->waitfor(String => 'Please specify the new IP Address for this system: ')) {
                $logger->error(__PACKAGE__ . "$sub_name FAILED to get confirmation question [Return 0]");
                return 0;
        } 
        $self->{conn}->print("$args{-emsIP}");
        $logger->info(__PACKAGE__ . "$sub_name Updated EMS IP address");
        unless(($prematch,$match) = $self->{conn}->waitfor( -match  => '/Do you want to upgrade the system passwords to use strong passwords \(production setup\) \(y\|Y\) or continue to use the old weak hardcoded passwords \(lab setup\) \(n\|N\) \(default:Y\)?/',-timeout   => '300')){
           $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected prompt");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
           return 0;
       }
       $self->{conn}->print("n");
       $self->{conn}->print("y");
	   
        unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/Completed changing the EMS keystore password./i')) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not Completed changing the EMS keystore password.\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    return 1;
}
=head1 InstallEmsOnHardware() 
=over

=item DESCRIPTION: 

InstallEmsOnHardware will install EMS iso and EMS application on G8 server

=item ARGUMENTS: 

None

=item AUTHOR: Simran Malhotra (smalhotra@rbbn.com)

=back

=cut

sub InstallEmsOnHardware{
     my $sub_name = "InstallEmsOnHardware";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
     my $installStatus = '1';  
     my (%TESTBED) = @_;
     my $testbed = keys %TESTBED;

     my $isolocation = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{BUILD}";	 
     my $primaryEmsIsoLocation = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IMAGE}";
     my $secondaryEmsIsoLocation  = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{IMAGE}";
     my $racConfLocation = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{USER_DATA}";
     my $racConfName = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{3}->{USER_DATA}";
     my $upgradeScriptloc = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{BUILD}";
     my $racConfType = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{4}->{USER_DATA}";
     my $isoname = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{3}->{BUILD}";
     my $upgradeScriptName = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{4}->{BUILD}";
     my $isoloc = "$isolocation" . '/' . "$isoname";
     my $upgradeloc = "$upgradeScriptloc" . '/' . "$upgradeScriptName";
     my $basePath = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{BASEPATH}";
     my $isHA = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{USER_DATA}";
     my $newPassword = "$TESTBED{'ems_sut:1:ce0:hash'}->{'LOGIN'}->{'3'}->{'PASSWD'}";
     my $newRootPasswd = "$TESTBED{'ems_sut:1:ce0:hash'}->{'LOGIN'}->{'2'}->{'ROOTPASSWD'}";

    $logger->info(__PACKAGE__ . ".testbed  $testbed");
    $logger->info(__PACKAGE__ . ".testbed $TESTBED{'ems_sut:1:ce0'}");
    if($isHA != 1)
        {
     unless(SonusQA::PSX::INSTALLER::installISOonG8(
                        -ilom_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{ILOM_IP},
                        -mgmt_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
                        -gateway =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{GATEWAY},
                        -netmask =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{NETMASK},
                        -iso_path =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IMAGE},
                        -hostname =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{HOSTNAME},
                        -ntpservers =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{TIMEZONE},
                        -timezone =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{TIMEZONE}

    )){
    $logger->error(__PACKAGE__ . ".$sub_name: Installation on G8 box failed.");
    $logger->error(__PACKAGE__ . ".$sub_name:  Sub[0]-");
    $installStatus = 0;
    return 0;
    }
    $logger->info(__PACKAGE__ . ".Installation on G8 box is complete.");
    #To check the admin login after ISO installation
    $logger->info( __PACKAGE__ . " Waiting for 20 min before checking the EMS application installation status ..." );
    sleep(1200);

    my $emsObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
          -OBJ_USER     =>  'admin',
          -OBJ_PASSWORD =>  $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{2}->{PASSWD},
          -ROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD},
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
          -NEWROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{2}->{ROOTPASSWD},
    );

     #To change the root password and login to EMS using root user
     unless ( $emsObj->enterRootSessionViaSU()) {

       $logger->error(__PACKAGE__ . ".$sub_name: failed to login to EMS using root user");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
     }else{
        $logger->info(__PACKAGE__ . ".$sub_name: Success: successfully logged in to the EMS using root user");
     }

     $logger->info( __PACKAGE__ . " Waiting for EMS application installation ..." );
       my  $max_attempts = 15;
       for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){

          if(&emsInstallationStatus($emsObj)){

                 $logger->error(__PACKAGE__ . "EMS Application Installation on G8 server is completed.");
                 last;
                 }
         else {
            if ($attempt < $max_attempts){

             $logger->error(__PACKAGE__ . "EMS Application Installation on G8 server is not completed.... Waiting for 5 mins..");
             sleep(300);
            }
            else {
                $logger->error( __PACKAGE__ . " Reached max attempts $max_attempts. EMS Application Installation on G8 server is not completed. Please check the /root/emsKickstartInstall.log");
                return 0;
            }
         }
       }


     $logger->info(__PACKAGE__ . ".EMS Application Installation on G8 server is successful");

     my $emsAdminObj = SonusQA::EMS->new(
          -OBJ_HOST     => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
          -OBJ_USER     =>  'admin',
          -OBJ_PASSWORD =>  $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{2}->{PASSWD},
          -ROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD},
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
      );

     #To run configure jumpstart on EMS
     unless ($emsAdminObj->confugureJumpstart(-emsIP => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP})) {

       $logger->error(__PACKAGE__ . ".$sub_name: failed to run configure jumpstart ");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
     } else{
    $logger->info(__PACKAGE__ . ".$sub_name: Success: successfully executed configure jumpstart.");
    }


   $logger->info( __PACKAGE__ . "Starting Insight Processes. Please Wait..." );
   my $EmsObj_Inight = SonusQA::ATSHELPER::newFromAlias( -tms_alias =>  $TESTBED{ "ems_sut:1:ce0"}, -ignore_xml => 0, -sessionlog => 1);
   # Starting the Insight of System Under Test
    unless ($EmsObj_Inight->startInsight ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to start the Insight of System Under Test");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success: started the Insight of System Under Test");
    }

    # Checking the Insight status of System Under Test
    unless ($EmsObj_Inight->status_ems ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Insight of System Under Test is not up completely");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       $installStatus = 0;
       return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name:Success:  Insight of System Under Test is up completely ");
   }
	$logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [$installStatus]");
	return $installStatus;

   }
  else
        {
     #For HA

    my ($objConn_1 ,$objConn_2);
     #iso install on primary
      unless( $objConn_1 = SonusQA::EMS::INSTALLER::installISOonG8ForRAC(
                        -ilom_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{ILOM_IP},
                        -mgmt_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
                        -gateway =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{GATEWAY},
                        -netmask =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{NETMASK},
                        -iso_path =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IMAGE},
                        -hostname =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{HOSTNAME},
                        -ntpservers =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{TIMEZONE},
                        -timezone =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{TIMEZONE},
                        -primary_dns =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{ALOM_IP},
                        -dns_search_path =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{ALOM_IP}
        )){
                $logger->error(__PACKAGE__ . ".$sub_name: Installation on primary G8 box failed.");
        $logger->error(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
                }
      #iso install on secondary
         unless ( $objConn_2 = SonusQA::EMS::INSTALLER::installISOonG8ForRAC(
                                                -ilom_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{ILOM_IP},
                                                -mgmt_ip =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{IP},
                                                -gateway =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{GATEWAY},
                                                -netmask =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{NETMASK},
                                                -iso_path =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{IMAGE},
                                                -hostname =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{HOSTNAME},
                                                -ntpservers =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{TIMEZONE},
                                                -timezone =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{TIMEZONE},
                                                -primary_dns =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{ALOM_IP},
                                                -dns_search_path =>  $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{ALOM_IP}
        )) {
                $logger->error(__PACKAGE__ . ".$sub_name: Installation on secondary G8 box failed.");
        $logger->error(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
                }


       unless(SonusQA::EMS::INSTALLER::checkBootCompletedForBothG8( -obj_primary => $objConn_1 , -obj_secondary => $objConn_2 ) ){
        $logger->error(__PACKAGE__ . ".$sub_name: Installation on G8 box failed.");
        $logger->error(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
        }
 $logger->info(__PACKAGE__ . "ISO Installation on G8 boxes is completed.");

 # A sleep of 5 to 10 min is required for G8 boxes to come up.
      $logger->info(__PACKAGE__ . "sleeping for 10 min to let both boxes come up");
      sleep (600);


 # to change root paswd of primary and secondary ems.
      $logger->info(__PACKAGE__ . ".$sub_name: calling loginAndChangeRootPswd ..");
       unless(SonusQA::EMS::INSTALLER::loginAndChangeRootPswd( -primary => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
                                                               -secondary => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{IP},
                                                               -ROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD},
                                                               -NEWROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{2}->{ROOTPASSWD}
                 )){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to login and change root paswd for ems servers.");
        $logger->error(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
        }else {
                 $logger->info(__PACKAGE__ . ".$sub_name: login and change root paswd successful on both ems servers");
                }


       $logger->info(__PACKAGE__ . ".$sub_name: about to call SonusQA::ATSHELPER::newFromAlias ");
       my $EmsObj_SUT = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $TESTBED{ "ems_sut:1:ce0"}, -ignore_xml => 0, -sessionlog => 1);


      # now the 2 scripts for RAC install will be executed sequentially below ..
      $logger->info(__PACKAGE__ . ".$sub_name: about to call racInstallScript1 ");

      unless (my $resultScript1 = $EmsObj_SUT->racInstallScript1 ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to run RACinstall_1 script");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success:  RACinstall_1 script executed successfully ");
    }

          $EmsObj_SUT = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $TESTBED{ "ems_sut:1:ce0"}, -ignore_xml => 0, -sessionlog => 1);
         $logger->info(__PACKAGE__ . ".$sub_name: about to call runRacScript2 ");

          unless (my $resultScript2 = $EmsObj_SUT->runRacScript2 ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to run EMSRACinstall script");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success:  EMSRACinstall script executed successfully ");
	 }
       $logger->info(__PACKAGE__ . ".$sub_name: waiting for 15 minutes to check EMS HA status.");
      sleep(900);

     unless (my $emsStatus = $EmsObj_SUT->checkHaEmsStatus ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to start all the EMS processes after EMS installation.");
      
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success:  EMS started successfully ");
    }

        $logger->info(__PACKAGE__ . ".$sub_name: EMS installation completed successfully.");
	}
    return 1;

}



=over

=item DESCRIPTION: 

UpgradeEmsOnHardware will upgrade EMS

=item ARGUMENTS: 

None

=item AUTHOR: Simran Malhotra (smalhotra@rbbn.com)

=back

=cut

sub UpgradeEmsOnHardware{
     my $sub_name = "UpgradeEmsOnHardware";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
     my $upgradeStatus = '0';
     my (%TESTBED) = @_;
     my $testbed = $TESTBED{ "ems_sut:1:ce0"};
     
     my $isolocation = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{BUILD}";
     my $upgradeScriptloc = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{BUILD}";
     my $isoname = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{3}->{BUILD}";
     my $upgradeScriptName = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{4}->{BUILD}";
     my $isoloc = "$isolocation" . '/' . "$isoname";
     my $upgradeloc = "$upgradeScriptloc" . '/' . "$upgradeScriptName";
     my $basePath = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{BASEPATH}";
     my $isHA = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{USER_DATA}";
     my $newPassword = $TESTBED{'ems_sut:1:ce0:hash'}->{'LOGIN'}->{'3'}->{'PASSWD'};
     my $emsStartStop = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{USER_DATA}"; 
       
     if(defined($newPassword)){
         $TESTBED{'ems_sut:1:ce0:hash'}->{'LOGIN'}->{'1'}->{'PASSWD'} = $newPassword; 
         $TESTBED{'ems_sut:1:ce0:hash'}->{'LOGIN'}->{'2'}->{'PASSWD'} = $newPassword; 
         $logger->warn(__PACKAGE__ . ". new password has been updated in EMS alias Hash");
     }

    $logger->debug('EMS details after : '. Dumper(%TESTBED));
   $logger->debug('EMS :'.Dumper(%TESTBED{'ems_sut:1:ce0:hash'}));

    my $filename = '/tmp/report.pl';
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    print $fh Dumper(%TESTBED{'ems_sut:1:ce0:hash'});
    close $fh;
     my $EmsObj_SUT = SonusQA::ATSHELPER::newFromAlias(-alias_file => $filename,  -tms_alias => $TESTBED{ "ems_sut:1:ce0"}); 
     my @logNames = ("$upgradeloc");
     if ( -f "$basePath" . '/' . "$isoname")
     {
         $logger->info(__PACKAGE__ . ".$sub_name: ISO $isoname already exists in $basePath.");
     }
     else
     {
	 $logger->info(__PACKAGE__ . ".$sub_name: ISO $isoname does not exist in $basePath.Needs to be copied");
         @logNames = ("$isoloc","$upgradeloc");
     }

=head
     #To copy the files
     my %scpArgs;
     $scpArgs{-hostip} = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP}";
     $scpArgs{-hostuser} = 'root';
     $scpArgs{-hostpasswd} = $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD};
     $scpArgs{-destinationFilePath} = "$TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{BASEPATH}";

    foreach my $file (@logNames){
      $scpArgs{-sourceFilePath} = $file;
      $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";

        unless(&SonusQA::Base::secureCopy(%scpArgs)){
          $logger->error(__PACKAGE__ . ".  SCP failed to copy the log files : $file to destination");
          $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
          return 0;
        }
    }
=cut

#Download the iso and upgradeEms.sh script from Artifacorty
    $logger->debug(__PACKAGE__ . ".$sub_name:  ********wget is being used here for copying**********");
    $logger->debug(__PACKAGE__ . ".$sub_name:  ********Started copying the upgrade script********");

    $logger->debug(__PACKAGE__ . ".$sub_name: Upgrade file Location is: \'$upgradeloc\'");
    my $cmd1 = "wget" . " " . "--no-check-certificate" . " " .  $upgradeloc;
    $logger->debug(__PACKAGE__ . ".$sub_name: Command to copy the file is: \'$cmd1\'");
    unless ( $EmsObj_SUT->{conn}->print( $cmd1 ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd1\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $EmsObj_SUT->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $EmsObj_SUT->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    else
    {
       $logger->info(__PACKAGE__ . "Success to copy the upgradeEMS.sh script");
    }

    my $cmd3 = "chmod +x $upgradeScriptName";
    $logger->debug(__PACKAGE__ . ".$sub_name: Command to give the permission to upgrade script is: \'$cmd3\'");
    unless ( $EmsObj_SUT->{conn}->print( $cmd3 ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd3\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $EmsObj_SUT->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $EmsObj_SUT->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    else
    {
       $logger->info(__PACKAGE__ . "Success to give the permission to upgrade script");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  ********wget is being used here for copying**********");
    $logger->debug(__PACKAGE__ . ".$sub_name:  ********Started copying the ems iso image********");

    $logger->debug(__PACKAGE__ . ".$sub_name: EMS iso image Location is: \'$isoloc\'");
    my $cmd2 = "wget" . " " . "--no-check-certificate" . " " .  $isoloc;
    $logger->debug(__PACKAGE__ . ".$sub_name: Command to copy the file is: \'$cmd2\'");

    unless ( $EmsObj_SUT->execCmd($cmd2, 3600) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd2\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $EmsObj_SUT->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $EmsObj_SUT->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    else
    {
       $logger->info(__PACKAGE__ . "Success to copy the ems iso image");
    }

    if($isHA != 1) {

    #To upgrade the EMS
    unless (my $emsUpgrade = $EmsObj_SUT->emsUpgrade( -basePath => $basePath, -upgradeFileName => $upgradeScriptName, -isoname => $isoname)) {

       $logger->error(__PACKAGE__ . ".$sub_name: failed to upgrade the EMS");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
     } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success: successfully upgraded the EMS $emsUpgrade secs");
    }

    my $EmsObj_Insight = SonusQA::ATSHELPER::newFromAlias(-alias_file => $filename,  -tms_alias => $TESTBED{ "ems_sut:1:ce0"});
    # Checking the Insight status of System Under Test
    unless ($EmsObj_Insight->status_ems ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Insight of System Under Test is not up completely");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
       return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name:Success:  Insight of System Under Test is up completely ");

 	if($emsStartStop == 1){
	 my $number_of_attempts = 10;
         $logger->info(__PACKAGE__ . ".$sub_name: emsStartStop Flag is enabled. Hence restarting ems $number_of_attempts times.\n");	
         for (my $attempt = 1 ; $attempt <= $number_of_attempts ; $attempt++){
                unless( my $EMS_StopInsight = $EmsObj_SUT->stopInsight )
                {
                  $logger->info(__PACKAGE__ . ".$sub_name: Stop Insight is executing. Attempt $attempt.");   
                }
                else
                {
                 $logger->info(__PACKAGE__ . ".$sub_name:Success: Stop Insight is executed. Attempt $attempt.");
                }
                my $EMS_StopInsight1 = SonusQA::ATSHELPER::newFromAlias(-alias_file => $filename,  -tms_alias => $TESTBED{ "ems_sut:1:ce0"}); 
                unless ($EMS_StopInsight1->status_ems ) {
                $logger->info(__PACKAGE__ . ".$sub_name: Insight is not stopped completely. Attempt $attempt.");
                }
                else
                {
                $logger->info(__PACKAGE__ . ".$sub_name:Success:  Insight is stopped completely. Attempt $attempt.");
                }
                my $EMS_StartInsight1 = SonusQA::ATSHELPER::newFromAlias(-alias_file => $filename,  -tms_alias => $TESTBED{ "ems_sut:1:ce0"});
                unless( my $EMS_StartInsight1 = $EmsObj_SUT->startInsight)
                {
                  $logger->info(__PACKAGE__ . ".$sub_name: Start Insight is executing. Attempt $attempt.");
                }
                else
                {
                 $logger->info(__PACKAGE__ . ".$sub_name:Success: Start Insight is executed. Attempt $attempt.");
                }
                my $EMS_StartInsight = SonusQA::ATSHELPER::newFromAlias(-alias_file => $filename,  -tms_alias => $TESTBED{ "ems_sut:1:ce0"});
                unless ($EMS_StartInsight->status_ems ) {
                $logger->info(__PACKAGE__ . ".$sub_name: Insight is not started completely. Attempt $attempt.");
                }
                else
                {
                $logger->info(__PACKAGE__ . ".$sub_name:Success:  Insight is started completely. Attempt $attempt.");
                }
	 }
	}
        $upgradeStatus = 1;
   }
}
   else {
   #HA Upgrade       
         unless ( $EmsObj_SUT->checkHaEmsStatus ) {
         $logger->error(__PACKAGE__ . ".$sub_name: All the EMS processes are not up , aborting EMS RAC upgrade .. ");
         return 0;
      } else {
        $logger->info(__PACKAGE__ . ".$sub_name: All the EMS processes are up and running, will start checkPreUpgrade ..");
      }

      if ( $EmsObj_SUT->checkPreUpgrade == 0 ) {
       $logger->error(__PACKAGE__ . ".$sub_name: active EMS is primary, no need to relocate, starting upgrade now. ");
     } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: active EMS is Secondary, so relocating it to proceed with upgrade.");
        unless ($EmsObj_SUT->switchOverHaRac ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to switchover EMS RAC, aborting upgrade.");
        return 0;
      } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success: switchover completed, starting upgrade now.");
      }

    }

       #To upgrade the EMS
       unless (my $emsUpgrade = $EmsObj_SUT->emsUpgrade( -basePath => $basePath, -upgradeFileName => $upgradeScriptName, -isoname => $isoname)) {

       $logger->error(__PACKAGE__ . ".$sub_name: failed to upgrade the EMS");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
        return 0;
       } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success: successfully upgraded the EMS $emsUpgrade secs");
       }

         $logger->info(__PACKAGE__ . ".$sub_name: sleeping for 15 minutes.");
         sleep (900);
        # during upgrade after reboot connection is lost, so creating connection object again.  
        $EmsObj_SUT = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $TESTBED{ "ems_sut:1:ce0"}, -ignore_xml => 0, -sessionlog => 1);

       unless (my $emsStatus = $EmsObj_SUT->checkHaEmsStatus ) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to start all the EMS processes after upgrade");
      } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Success: All the EMS processes are up and running.");
		$upgradeStatus = 1;
      }

   }
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [$upgradeStatus]");
    return $upgradeStatus;
}

=over

=item DESCRIPTION:

Create a KVM instance using Qcow2, does the following:
1. Downloads the config file and qcow2 from artifactory.
2. Mounts the config file and updates the instance details in the ems config file
3. Increases the HDD in the qcow2
4. Creates the KVM instance
5. Waits for the EMS application to be up

=item ARGUMENTS:
kvmHostIp : KVM Host IP
kvmHostUserName : KVM Host SSH UserName
kvmHostPassword : KVM Host SSH Password
kvmHostConfFile : KVM Host Conf File (VMInstanceConf.img)
kvmHostQcow2File : KVM Host Conf File
kvmInstanceName : KVM Instance Name
kvmInstanceIp : KVM Instance IP
kvmInstanceGw : KVM Instance Gateway
kvmInstanceMask : KVM Instance Net Mask
kvmInstanceNtp : KVM Instance NTP Server IP
kvmInstanceRamMb : KVM Instance Ram size in MB
kvmInstanceCores : KVM Instance Number of Cores
kvmInstanceSocket : KVM Instance Socket count
kvmInstanceThreads : KVM Instance Thread count
kvmInstanceHddGbIncrease : How much do you want to grow the ems size, in GB?
artifactoryUrl : Artifactory URL from where the qcow2 and config file needs to be downloaded from
kvmIsoAndConfCopyLoc : Path where the conf file and the iso is to be copied
kvmMountDir : Specifies the path where to mount the VMInstanceConf.img file
kvmInstanceSource :  Defines the Bridge of the source EMS

=item AUTHOR: Naveen Vandiyar

=back

=cut


sub createKvmInstanceFromQcow2 {
    my (%args ) = @_;
    my $sub_name = 'createKvmInstanceFromQcow2';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($prematch, $match);
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $cmd = "";
    my $kvmHostIp = $args{-kvmHostIp};
    my $kvmHostUserName = $args{-kvmHostUserName};
    my $kvmHostPassword = $args{-kvmHostPassword};
    my $kvmHostConfFile = $args{-kvmHostConfFile};
    my $kvmHostQcow2File = $args{-kvmHostQcow2File};
    my $kvmInstanceName = $args{-kvmInstanceName};
    my $kvmInstanceIp = $args{-kvmInstanceIp};
    my $kvmInstanceGw = $args{-kvmInstanceGw};
    my $kvmInstanceMask = $args{-kvmInstanceMask};
    my $kvmInstanceNtp = $args{-kvmInstanceNtp};
    my $kvmInstanceRamMb = $args{-kvmInstanceRamMb};
    my $kvmInstanceCores = $args{-kvmInstanceCores};
    my $kvmInstanceSocket = $args{-kvmInstanceSocket};
    my $kvmInstanceThreads = $args{-kvmInstanceThreads};
    my $kvmInstanceHddGbIncrease = $args{-kvmInstanceHddGbIncrease};
    my $artifactoryUrl = $args{-artifactoryUrl};
    my $kvmIsoAndConfCopyLoc = $args{-kvmIsoAndConfCopyLoc};
    my $kvmMountDir = $args{-kvmMountDir};
    my $kvmInstanceSource = $args{-kvmInstanceSource};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmHostIp :$kvmHostIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmHostUserName :$kvmHostUserName");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmHostPassword :$kvmHostPassword");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmHostConfFile :$kvmHostConfFile");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmHostQcow2File :$kvmHostQcow2File");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceName :$kvmInstanceName");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceIp :$kvmInstanceIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceGw :$kvmInstanceGw");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceMask :$kvmInstanceMask");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceNtp :$kvmInstanceNtp"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceRamMb :$kvmInstanceRamMb"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceCores :$kvmInstanceCores"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceSocket :$kvmInstanceSocket"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceThreads :$kvmInstanceThreads"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstanceHddGbIncrease :$kvmInstanceHddGbIncrease"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> artifactoryUrl :$artifactoryUrl"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmIsoAndConfCopyLocation :$kvmIsoAndConfCopyLoc");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> VMconfigMountDirectory :$kvmMountDir");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> kvmInstaneBrige :$kvmInstanceSource");


    my $self;
    $self->{root_session} = new SonusQA::Base( -obj_host       => $kvmHostIp,
                                         -obj_user       => $kvmHostUserName,
                                         -obj_password   => $kvmHostPassword,
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                          );


    $self->{root_session}->{conn}->cmd("rm -rf"." ".$kvmIsoAndConfCopyLoc.$kvmHostConfFile);
    $self->{root_session}->{conn}->cmd("rm -rf"." ".$kvmIsoAndConfCopyLoc.$kvmHostQcow2File);
    $self->{root_session}->{conn}->cmd("mkdir $kvmIsoAndConfCopyLoc");
    $self->{root_session}->{conn}->cmd("chmod 777 $kvmIsoAndConfCopyLoc");



    $logger->debug(__PACKAGE__ . ".$sub_name: Downloading config file from artifactory");
    $self->{root_session}->{conn}->cmd("wget --no-check-certificate ".$artifactoryUrl."/".$kvmHostConfFile." -P ".$kvmIsoAndConfCopyLoc);
    $logger->debug(__PACKAGE__ . ".$sub_name: Downloading qcow2 file");
    $self->{root_session}->{conn}->cmd("wget --no-check-certificate ".$artifactoryUrl."/".$kvmHostQcow2File." -P ".$kvmIsoAndConfCopyLoc);


    $self->{root_session}->{conn}->cmd("mkdir $kvmMountDir");
    my $mountConfName = $kvmMountDir."emsVMInstance.conf";
    $self->{root_session}->{conn}->cmd("/usr/bin/mount -o loop $kvmIsoAndConfCopyLoc".$kvmHostConfFile." $kvmMountDir");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/systemHostName=/systemHostName=".$kvmInstanceName."/g\" $mountConfName");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/timeZone=/timeZone=Asia\\/Kolkata/g\" $mountConfName");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/ntpServerIpaddr=/ntpServerIpaddr=".$kvmInstanceNtp."/g\" $mountConfName");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/nif1Ipaddr=/nif1Ipaddr=".$kvmInstanceIp."/g\" $mountConfName");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/nif1Netmask=/nif1Netmask=".$kvmInstanceMask."/g\" $mountConfName");
    $self->{root_session}->{conn}->cmd("sed -i -e \"s/nif1GatewayIpaddr=/nif1GatewayIpaddr=".$kvmInstanceGw."/g\" $mountConfName");

    $self->{root_session}->{conn}->cmd("umount $kvmMountDir");
    $self->{root_session}->{conn}->cmd("rm -rf $kvmMountDir");

	
    $self->{root_session}->{conn}->cmd("qemu-img resize $kvmIsoAndConfCopyLoc".$kvmHostQcow2File." +".$kvmInstanceHddGbIncrease."G");
    $self->{root_session}->{conn}->cmd("/usr/bin/virt-install --name ".$kvmInstanceName." --ram ".$kvmInstanceRamMb." --vcpus sockets=".$kvmInstanceSocket.",cores=".$kvmInstanceCores.",threads=".$kvmInstanceThreads." --disk $kvmIsoAndConfCopyLoc".$kvmHostQcow2File."  --disk path=$kvmIsoAndConfCopyLoc".$kvmHostConfFile.",device=disk,cache=none --import --autostart --os-type=linux --os-variant=rhel7 --arch=x86_64  --network type=direct,source=".$kvmInstanceSource.",model=virtio --noautoconsole");
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Executing command /usr/bin/virt-install --name $kvmInstanceName --ram $kvmInstanceRamMb --vcpus sockets=$kvmInstanceSocket,cores=$kvmInstanceCores,threads=$kvmInstanceThreads --disk $kvmIsoAndConfCopyLoc$kvmHostQcow2File  --disk path=$kvmIsoAndConfCopyLoc$kvmHostConfFile,device=disk,cache=none --import --autostart --os-type=linux --os-variant=rhel7 --arch=x86_64  --network type=direct,source=$kvmInstanceSource,model=virtio --noautoconsole");
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Sleeping for 5 mins"); 
    sleep(5*60); 

    my $ret_status = 1;
    my $max_attempts = 100;
    for ( my $attempt =1; $attempt<=$max_attempts; $attempt++)
    {
		$ret_status = 1;
  
	    $self->{root_session} = new SonusQA::Base( -obj_host       => $kvmInstanceIp ,
						 -obj_user       => "insight",
						 -obj_password   => "insight",
						 -comm_type      => 'SSH',
						 -obj_port       => 22,
						 -return_on_fail => 1,
						 -defaulttimeout => 60,
						 -sessionlog => 1,
					       );

	    my @status_ems = $self->{root_session}->{conn}->cmd("./$self->{sonusEms} status");
	    $logger->debug(__PACKAGE__ . ".$sub_name: The status of EMS process :". Dumper(\@status_ems));
	my @checkpoint = ('Sonus Insight is running' , 'Call Trace Listener is running' , 'Successfully connected to the DB and verified the correct DB version', 'manageLogSize is running', 'License_Manager.*lmgrd.*RUNNING' , 'Process_Control.*nco_pa.*RUNNING' , 'Object_Server.*nco_objserv.*RUNNING' , 'SonusTrapProbe.*nco_p_sonustrap.*RUNNING' , 'FMTrapReceiver.*Process.*RUNNING');
	 
	foreach my $pat(@checkpoint) {
		$logger->debug(__PACKAGE__ . ".$sub_name The string is $pat");
		if(grep(/$pat/i, @status_ems)) {
		    $logger->info(__PACKAGE__ . ".$sub_name Found -> $pat");
		}
		else {
		    if (grep(/Actual State.*standby/si, @status_ems) and $pat =~ /(FM DataServer|Object_Server)/i) {
			$logger->info(__PACKAGE__ . ".$sub_name System is standby. Hence could not find -> $pat");
		    }
		    else {
			$logger->error(__PACKAGE__ . ".$sub_name Could not find -> $pat");
			$ret_status = 0;
			last;
		    }
		}
	    }

	    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [$ret_status]");
	    if($ret_status ==1)
	    {
		last;
	    } 
	    else 
	    {
		sleep(30);
    		$logger->debug(__PACKAGE__ . ".$sub_name: --> Sleeping and trying after 30 seconds"); 
	    }
	}
	return $ret_status;	
}



=over

=item DESCRIPTION:

Start the SAPro maps, does the following:
1. Copies the prerequiste setup script on the ems and invokes it.
2. Starts the script to register the devices on SAPro host 
3. Copies the DB script and executes on the EMS
4. Starts the script to re-register the deviecs on SAPro host

=item ARGUMENTS:
-emsIp= IP of the EMS
-saproIp=>IP of the SAPro host
-saproUsername=>Username to ssh into the SAPro host
-saproPassword=>Password to ssh into the SAPro host

=item AUTHOR: Naveen Vandiyar

=back

=cut


sub startSaproSbcDevices {
    my (%args ) = @_;
    my $sub_name = 'createKvmInstanceFromQcow2';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $ret_status = 1;
    my $cmd = "";
    my $emsIp = $args{-emsIp};
    my $emsUsername = $args{-emsUsername};
    my $emsPassword = $args{-emsPassword};
    my $saproIp = $args{-saproIp};
    my $saproUsername = $args{-saproUsername};
    my $saproPassword = $args{-saproPassword};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsIp :$emsIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsUsername :$emsUsername"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsPassword :$emsPassword"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> saproIp :$saproIp"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> saproUsername :$saproUsername"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> saproPassword :$saproPassword"); 

    my $self;
    #Copies the prerequiste setup script on the ems (/SBC/PTprerequisite_tan.sh)
    my %scpArgs;
    $scpArgs{-hostip} = "$emsIp";
    $scpArgs{-hostuser} =  $emsUsername;
    $scpArgs{-hostpasswd} = $emsPassword;

    $scpArgs{-destinationFilePath} = "/tmp/";
    $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/PTprerequisite_tan.sh";
    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";

     unless(&SonusQA::Base::secureCopy(%scpArgs)){
         $logger->error(__PACKAGE__ . ".  SCP failed to copy PTprerequisite_tan.sh file to destination");
         $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
       }

   $logger->info(__PACKAGE__ . ".SCP Success to copy the PTprerequisite_tan.sh file to $scpArgs{-destinationFilePath}");
   
   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/FectchNodeIds.sh";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy FectchNodeIds.sh file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
      }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the FectchNodeIds.sh file to $scpArgs{-destinationFilePath}");


   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/PmTruncate.sql";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy PmTruncate.sql file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
      }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the PmTruncate.sql file to $scpArgs{-destinationFilePath}");


   #Run the PTprerequisite_tan.sh file on EMS
    my $emsAdminObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $emsIp,
          -OBJ_USER     => $emsUsername,
          -OBJ_PASSWORD =>  $emsPassword,
          -ROOTPASSWD => '',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
	  -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
    unless ( $emsAdminObj->enterRootSessionViaSU('sudo')) {
        $logger->debug(__PACKAGE__ . " : Could not enter sudo root session");
        return 0;
        }
    $emsAdminObj->execCmd("chmod 777 /tmp/PTprerequisite_tan.sh", 60);
    $emsAdminObj->execCmd("chmod 777 /tmp/FectchNodeIds.sh", 60);
    $emsAdminObj->execCmd("chmod 777 /tmp/PmTruncate.sql", 60);

    $emsAdminObj->execCmd("/tmp/PTprerequisite_tan.sh", 6000);


    #Update the EMS IP in the MAPs
    
    my $saproObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $saproIp,
          -OBJ_USER     => $saproUsername,
          -OBJ_PASSWORD =>  $saproPassword,
          -ROOTPASSWD => '',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
          -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
    $saproObj->execCmd("sed -i 's/HttpClientServerAddr =.*/HttpClientServerAddr =/g' /opt/sapro/map/HORIZON_*", 60);
    $saproObj->execCmd("sed -i 's/HttpClientServerAddr =.*/HttpClientServerAddr = \"".$emsIp."\"/g' /opt/sapro/map/HORIZON_*", 60);
 
    #Copy the node id file to PSX as well.
    $saproObj->execCmd("cp -u /SBC/aks /PSX/aks", 240);

    #Start the StartSimulatedNodes.sh 0 script
    $saproObj->execCmd("/SBC/StartSimulatedNodes.sh 0","6000");
   
    #Run the node id fectching script on the EMS
    $emsAdminObj->execCmd("/tmp/FectchNodeIds.sh", 240);

    #Start the StartSimulatedNodes.sh 0 script
    $saproObj->execCmd("/SBC/StartSimulatedNodes.sh 1","6000");
  
    #Stop the PSX Simulator
    $saproObj->execCmd("/SBC/StartandStopPSXNodes.sh 0","6000");
    
    #Stop the PSX Simulator
    $saproObj->execCmd("/SBC/StartandStopPSXNodes.sh 1","6000");

    $emsAdminObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $emsIp,
          -OBJ_USER     => $emsUsername,
          -OBJ_PASSWORD =>  $emsPassword,
          -ROOTPASSWD => '',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
	  -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
    unless ( $emsAdminObj->enterRootSessionViaSU('sudo')) {
        $logger->debug(__PACKAGE__ . " : Could not enter sudo root session");
        return 0;
        }

    #Stop EMS
    $emsAdminObj->execCmd("su - insight -c \"/opt/sonus/ems/$self->{sonusEms} stop\"", 300);

    #Run the node id fectching script on the EMS
    $emsAdminObj->execCmd("su - oracle -c \"sqlplus dbimpl/dbimpl @/tmp/PmTruncate.sql\"", 300);
    
    #Start EMS
    $emsAdminObj->execCmd("su - insight -c \"/opt/sonus/ems/$self->{sonusEms} start\"", 1200);

    return $ret_status;	
}


=over

=item DESCRIPTION:

Setup Filebeat and Telegraf on EMS
1. Copies the rpm and installs on ems
2. Strats the service

=item ARGUMENTS:
-emsIp= IP of the EMS
-emsUsername=>Username to ssh into the EMS host
-emsPassword=>Password to ssh into the EMS host

=item AUTHOR: Naveen Vandiyar

=back

=cut


sub configureFilebeatAndTelegraf {
    my (%args ) = @_;
    my $sub_name = 'configureFilebeatAndTelegraf';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $ret_status = 1;
    my $cmd = "";
    my $emsIp = $args{-emsIp};
    my $emsUsername = $args{-emsUsername};
    my $emsPassword = $args{-emsPassword};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsIp :$emsIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsUsername :$emsUsername"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> emsPassword :$emsPassword"); 

    my $self;
    #Copies the prerequiste setup script on the ems (/SBC/PTprerequisite_tan.sh)
    my %scpArgs;
    $scpArgs{-hostip} = "$emsIp";
    $scpArgs{-hostuser} =  $emsUsername;
    $scpArgs{-hostpasswd} = $emsPassword;

    $scpArgs{-destinationFilePath} = "/tmp/";
    $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/filebeat-7.3.0-linux-x86_64.tar.gz";
    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";

    unless(&SonusQA::Base::secureCopy(%scpArgs)){
         $logger->error(__PACKAGE__ . ".  SCP failed to copy filebeat-7.3.0-linux-x86_64.tar.gz file to destination");
         $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
    }

   $logger->info(__PACKAGE__ . ".SCP Success to copy the filebeat-7.3.0-linux-x86_64.tar.gz file to $scpArgs{-destinationFilePath}");
   
   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/telegraf-1.11.3-1.i386.rpm";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy telegraf-1.11.3-1.i386.rpm file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the telegraf-1.11.3-1.i386.rpm file to $scpArgs{-destinationFilePath}");


   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/filebeat.yml";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy filebeat.yml file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the filebeat.yml file to $scpArgs{-destinationFilePath}");

   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/filebeat.service";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy filebeat.service file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the filebeat.service file to $scpArgs{-destinationFilePath}");


   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/telegraf.conf";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy telegraf.conf file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the telegraf.conf file to $scpArgs{-destinationFilePath}");


   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/jolokia-jvm-1.6.0-agent.jar";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy jolokia-jvm-1.6.0-agent.jar file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the jolokia-jvm-1.6.0-agent.jar file to $scpArgs{-destinationFilePath}");

   $scpArgs{-destinationFilePath} = "/tmp/";
   $scpArgs{-sourceFilePath} = $ENV{HOME}."/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/jolokia.sh";
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";
   unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy jolokia.sh file to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
   }
   $logger->info(__PACKAGE__ . ".SCP Success to copy the jolokia.sh file to $scpArgs{-destinationFilePath}");



   #Run rpm -ivh telegraf-1.11.3-1.i386.rpm
    my $emsAdminObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $emsIp,
          -OBJ_USER     => $emsUsername,
          -OBJ_PASSWORD =>  $emsPassword,
          -ROOTPASSWD => '',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
	  -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
    unless ( $emsAdminObj->enterRootSessionViaSU('sudo')) {
        $logger->debug(__PACKAGE__ . " : Could not enter sudo root session");
        return 0;
        }
    $emsAdminObj->execCmd("rpm -ivh /tmp/telegraf-1.11.3-1.i386.rpm", 600);
    $emsAdminObj->execCmd("\\cp -ff /tmp/telegraf.conf /etc/telegraf/telegraf.conf", 600);

   #Setup Filebeat
    $emsAdminObj->execCmd("tar -xvzf /tmp/filebeat-7.3.0-linux-x86_64.tar.gz -C /root", 600);
    $emsAdminObj->execCmd("ln -s /root/filebeat-7.3.0-linux-x86_64 /root/filebeat", 60);
    $emsAdminObj->execCmd("\\cp -rf /tmp/filebeat.yml /root/filebeat/filebeat.yml", 60);
    $emsAdminObj->execCmd("\\cp -rf /tmp/filebeat.service /etc/systemd/system/filebeat.service", 60);

    #Update the hostnames
    $emsAdminObj->execCmd("hostname=`hostname`;sed -i \"s|REPL_HOSTNAME|\$hostname|\" /etc/telegraf/telegraf.conf", 60);
    $emsAdminObj->execCmd("version=`rpm -qa | grep -i EMS | awk -F \"-\" '{print \$2\$3}'`;sed -i \"s|REPL_BUILD|\$version|\" /etc/telegraf/telegraf.conf", 60);
    $emsAdminObj->execCmd("version=`rpm -qa | grep -i EMS | awk -F \"-\" '{print \$2}'`;sed -i \"s|REPL_RELEASE|\$version|\" /etc/telegraf/telegraf.conf", 60);
    #Updates for jolokia-jvm-1.6.0-agent.jar
    $emsAdminObj->execCmd("\\cp -ff /tmp/jolokia-jvm-1.6.0-agent.jar /opt/sonus/ems/jolokia-jvm-1.6.0-agent.jar", 600);
    $emsAdminObj->execCmd("chown insight:insight /opt/sonus/ems/jolokia-jvm-1.6.0-agent.jar", 60);
    $emsAdminObj->execCmd("chmod 777 /opt/sonus/ems/jolokia-jvm-1.6.0-agent.jar", 60);

    $emsAdminObj->execCmd("chmod 777 /tmp/jolokia.sh", 60);
    $emsAdminObj->execCmd("/tmp/jolokia.sh", 60);

    $emsAdminObj->execCmd("systemctl start telegraf", 600);
    $emsAdminObj->execCmd("systemctl start filebeat", 600);
    return $ret_status;	
}


=over

=item DESCRIPTION:

Master PSX DB fresh install
1. ./PSXInstall.pl -mode advance -ha standalone -install newdbinstall

=item ARGUMENTS:
-psxIp= IP of the PSX
-psxUsername=>Username to ssh into the PSX host
-psxPassword=>Password to ssh into the PSX host

=item AUTHOR: Naveen Vandiyar

=back

=cut

sub cleanPsxMasterDataBase{
    my (%args,@cmdResults,$prematch,$match  ) = @_;
    my $sub_name = 'cleanPsxMasterDataBase';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $ret_status = 1;
    my $cmd = "";
    my $psxIp = $args{-psxIp};
    my $psxUsername = $args{-psxUsername};
    my $psxPassword = $args{-psxPassword};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxIp :$psxIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxUsername :$psxUsername"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxPassword :$psxPassword"); 

    my $self;
    my $emsAdminObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $psxIp,
          -OBJ_USER     => $psxUsername,
          -OBJ_PASSWORD =>  $psxPassword,
          -ROOTPASSWD => 'sonus',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
	  -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
	$cmd = "perl -pi -e 's/ClientAliveInterval [0-9]*/ClientAliveInterval 0/' /etc/ssh/sshd_config";
        $emsAdminObj->execCmd("$cmd");
        $cmd = "perl -pi -e 's/ClientAliveCountMax [0-9]*/ClientAliveCountMax 0/' /etc/ssh/sshd_config";
        $emsAdminObj->execCmd("$cmd");
        $cmd = "sudo service sshd restart";
        $emsAdminObj->execCmd("$cmd");
        sleep 5;

    $emsAdminObj->execCmd("cd /export/home/ssuser/SOFTSWITCH/BIN/");
    @cmdResults = $emsAdminObj->{conn}->print("./PSXInstall.pl -mode advance -ha standalone -install newdbinstall");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for ssuser :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("ssuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for ssuser :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("ssuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for oracle :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("oracle");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for oracle :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("oracle");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for root :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonus");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for root :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonus");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for admin :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("admin");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for admin :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("admin");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Is this PSX a master or slave/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("M");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Is this PSX a provisioning only master/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print("N");

    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enable PSX Test Data Access on this PSX/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print("N");


    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enable ACL Profile rule/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print("N");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user system/',
                                                 -errmode => "return",
                                                 -timeout => 3600) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonusdba");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user system/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonusdba");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user dbquery/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("dbquery");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user dbquery/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("dbquery");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user insightuser/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("insightuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user insightuser/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("insightuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 3600) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    sleep(60);
    my $psxSsuserObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $psxIp,
          -OBJ_USER     => "ssuser",
          -OBJ_PASSWORD =>  "ssuser",
          -ROOTPASSWD => 'sonus',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
          -DO_NOT_TOUCH_SSHD => 1,
          -RETRYCMDFLAG => 1
      );
    @cmdResults = $psxSsuserObj->{conn}->print("start.ssoftswitch");
    ($prematch, $match) = $psxSsuserObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 200) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    sleep(90); 
   
    return $ret_status;	
}


=over

=item DESCRIPTION:

Slave PSX DB fresh install
1. ./PSXInstall.pl -mode advance -ha standalone -install newdbinstall

=item ARGUMENTS:
-psxIp= IP of the PSX
-psxUsername=>Username to ssh into the PSX host
-psxPassword=>Password to ssh into the PSX host
-psxMasterHostName=> Host name of the master PSX
-psxMasterIp=>PSX Master Ip

=item AUTHOR: Naveen Vandiyar

=back

=cut

sub cleanPsxSlaveDataBase{
    my (%args,@cmdResults,$prematch,$match  ) = @_;
    my $sub_name = 'cleanPsxMasterDataBase';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $logfile = "";
    my $ret_status = 1;
    my $cmd = "";
    my $psxIp = $args{-psxIp};
    my $psxUsername = $args{-psxUsername};
    my $psxPassword = $args{-psxPassword};
    my $psxMasterHostName = $args{-psxMasterHostName};
    my $psxMasterIp = $args{-psxMasterIp};


    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxIp :$psxIp");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxUsername :$psxUsername"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxPassword :$psxPassword"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxMasterHostName :$psxMasterHostName"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: --> psxMasterIp :$psxMasterIp"); 


    my $self;

    #stop softswitch
    my $psxSsuserObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $psxIp,
          -OBJ_USER     => "ssuser",
          -OBJ_PASSWORD =>  "ssuser",
          -ROOTPASSWD => 'sonus',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
          -DO_NOT_TOUCH_SSHD => 1,
          -RETRYCMDFLAG => 1
      );
    
    @cmdResults = $psxSsuserObj->{conn}->print("stop.ssoftswitch");
    ($prematch, $match) = $psxSsuserObj->{conn}->waitfor(-match => '/Automatically stop all SoftSwitch Processes/',
							 -match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 200) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    if($match =~ m/Automatically stop all SoftSwitch Processes/i) {
	    @cmdResults = $psxSsuserObj->{conn}->print("y");
	    ($prematch, $match) = $psxSsuserObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
							 -errmode => "return",
							 -timeout => 200) or do {
	    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
	    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	    $self->DESTROY;
	    };
    }
    sleep(20);


    my $emsAdminObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $psxIp,
          -OBJ_USER     => $psxUsername,
          -OBJ_PASSWORD =>  $psxPassword,
          -ROOTPASSWD => 'sonus',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
	  -DO_NOT_TOUCH_SSHD => 1,
	  -RETRYCMDFLAG => 1
      );
	$cmd = "perl -pi -e 's/ClientAliveInterval [0-9]*/ClientAliveInterval 0/' /etc/ssh/sshd_config";
        $emsAdminObj->execCmd("$cmd");
        $cmd = "perl -pi -e 's/ClientAliveCountMax [0-9]*/ClientAliveCountMax 0/' /etc/ssh/sshd_config";
        $emsAdminObj->execCmd("$cmd");
        $cmd = "sudo service sshd restart";
        $emsAdminObj->execCmd("$cmd");
        sleep 5;

    $emsAdminObj->execCmd("cd /export/home/ssuser/SOFTSWITCH/BIN/");
    @cmdResults = $emsAdminObj->{conn}->print("./PSXInstall.pl -mode advance -ha standalone -install newdbinstall");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for ssuser :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("ssuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for ssuser :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("ssuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for oracle :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("oracle");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for oracle :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("oracle");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for root :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonus");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for root :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonus");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for admin :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("admin");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Re-type new password for admin :/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("admin");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Please confirm the above input y|Y|n|N .../',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("y");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Is this PSX a master or slave/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("S");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Master host name/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print($psxMasterHostName);

    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/IP address of the master system/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print($psxMasterIp);


    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter the Master DB platform password/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");

    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enable ACL Profile rule/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };
    @cmdResults = $emsAdminObj->{conn}->print("N");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user system/',
                                                 -errmode => "return",
                                                 -timeout => 3600) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonusdba");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user system/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("sonusdba");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user dbquery/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("dbquery");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user dbquery/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("dbquery");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for master DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for master DB user platform/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("dbplatform");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/Enter new password for DB user insightuser/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    @cmdResults = $emsAdminObj->{conn}->print("insightuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/RE-Enter new password for DB user insightuser/',
                                                 -errmode => "return",
                                                 -timeout => 120) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };


    @cmdResults = $emsAdminObj->{conn}->print("insightuser");
    ($prematch, $match) = $emsAdminObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 3600) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };



    $psxSsuserObj = SonusQA::TOOLS->new(
          -OBJ_HOST     => $psxIp,
          -OBJ_USER     => "ssuser",
          -OBJ_PASSWORD =>  "ssuser",
          -ROOTPASSWD => 'sonus',
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
          -DO_NOT_TOUCH_SSHD => 1,
          -RETRYCMDFLAG => 1
      );
    @cmdResults = $psxSsuserObj->{conn}->print("start.ssoftswitch");
    ($prematch, $match) = $psxSsuserObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 200) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    sleep(300); 


    @cmdResults = $psxSsuserObj->{conn}->print("ps -eaf | grep -i pipe");
    ($prematch, $match) = $psxSsuserObj->{conn}->waitfor(-match => '/AUTOMATION\> $/',
                                                 -errmode => "return",
                                                 -timeout => 200) or do {
    $logger->warn(__PACKAGE__ . ". $sub_name unable to get required prompt ssuser: @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name Prematch : $prematch \n Match : $match ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    $self->DESTROY;
    return 0;
    };

    return $ret_status;	
}

=over

=item DESCRIPTION:

Creates a DR setup

=item AUTHOR: Nikitha Taranath

=back

=cut

sub createDRSetup
{
    my(%args)=@_;
    my $sub_name = 'createDRSetup';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    # get the required information from TMS

    my $kvmInstIp = $args{-kvmInstanceIp};
    my $kvmInstIp1 = $args{-kvmInstanceIp1};
    my $cmd = "/opt/sonus/ems/conf/DR/manageDR setup";
    my $cmd1 = "/opt/sonus/ems/conf/DR/manageDR status";
    my $timeout = $args{-timeout} || 1200;
    my ($prematch, $match);
    my $timeTaken = time;


    my $self;
    $self->{root_session} = new SonusQA::Base( -obj_host       => $kvmInstIp,
                                         -obj_user       => "insight",
                                         -obj_password   => "insight",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                          );



   $self->{root_session}->{conn}->print($cmd);

   $logger->debug(__PACKAGE__ . "$sub_name Trying to run to create DR command");

      unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match     => '/Do you want to continue with setting up DR\? \[y\|n\]\:/i' , -timeout   => $timeout )) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Got an expected message string");
    }

   $self->{root_session}->{conn}->print("y");

   unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match => '/Please specify the IP address of the remote DR TARGET node\:/i' , -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message : please enter the EMS Taget Ip");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Got an expected message for entering the EMS Taget Ip");
    }

   $self->{root_session}->{conn}->print($kvmInstIp1);

         unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match => '/Completed DR setup\./i' , -timeout   => $timeout))     {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message : Completed the DR setup");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Completed the DR setup");
    }

     $self->{root_session}->{conn}->print($cmd1);

     unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match => '/Completed DR status\./i' , -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message : not completed the DR status");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Completed the DR status");
    }

}

=over

=item DESCRIPTION:

Shut down the target EMS

=item AUTHOR: Nikitha Taranath

=back

=cut

sub shutdownTarget
{
    my(%args)=@_;
    my $sub_name = 'shutdownTarget';
    my $max_attempts= 1000;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    # get the required information from TMS
    my $kvmInstanceName1 = $args{-kvmInstanceName1};
    my $kvmHostIp = $args{-kvmHostIp};
    my $kvmHostUserName = $args{-kvmHostUserName};
    my $kvmHostPassword = $args{-kvmHostPassword};

    my $self;
    $self->{root_session} = new SonusQA::Base( -obj_host       => $kvmHostIp,
                                         -obj_user       => $kvmHostUserName,
                                         -obj_password   => $kvmHostPassword,
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                          );
    my $cmd = "virsh shutdown ".$kvmInstanceName1;
    $self->{root_session}->{conn}->print($cmd);
    sleep(120);
    for ( my $attempt =1; $attempt<=$max_attempts; $attempt++){
    my @results = $self->{root_session}->{conn}->cmd("virsh list --all | grep ". $kvmInstanceName1." | awk {'print \$3\$4'}");

    if(grep /shutoff/, @results)
        {
                $logger->debug(__PACKAGE__ . "Target has shutdown");
                sleep(20);
                return 1;
        }
        else
        {
                $logger->error(__PACKAGE__ . "Target shutdown not completed");
                sleep(20);
        }
}

}

=over

=item DESCRIPTION:

For performing a teardown in EMS

=item AUTHOR: Nikitha Taranath

=back

=cut

sub teardown
{
    my(%args)=@_;
    my $sub_name = 'teardown';
    my $cmd ="/opt/sonus/ems/conf/DR/manageDR -f teardown";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my $kvmInstIp = $args{-kvmInstanceIp};
    my $timeout = $args{-timeout} || 1200;
    my ($prematch, $match);

    my $self;
    $self->{root_session} = new SonusQA::Base( -obj_host       => $kvmInstIp,
                                         -obj_user       => "insight",
                                         -obj_password   => "insight",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                          );

  $self->{root_session}->{conn}->print($cmd);
  $logger->debug(__PACKAGE__ . "$sub_name Trying to run the tear down command");

  unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match     => '/Do you want to continue with DR teardown\? \[y\|n\]\:/i' , -timeout   => $timeout )) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Got an expected message string");
    }

  $self->{root_session}->{conn}->print("y");

    unless (($prematch, $match) = $self->{root_session}->{conn}->waitfor( -match => '/Completed DR teardown\./i' , -timeout   => $timeout))     {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected message : Not completed the DR teardown");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Completed the DR teardown");
    }

}

=over

=item DESCRIPTION:RSM Installation on Hardware

=item AUTHOR: Yashawanth M M

=back

=cut

sub InstallRsmOnHardware
{
    my $subName = 'InstallRsmOnHardware';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my (%TESTBED) = @_;
    my $testbed = keys %TESTBED;
    my $dir = $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{BASEPATH};

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub ");
  
      my $rsmObj = SonusQA::RSM->new(

          -OBJ_HOST     => $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{IP},
          -OBJ_USER     =>  $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{USERID},
          -OBJ_PASSWORD =>   $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{2}->{PASSWD},
          -ROOTPASSWD =>  $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD},
          -skip => 1,
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
       );

    # To create directory
    if ( -d $dir)
    {
        $logger->error(__PACKAGE__ . ".$subName: $dir already exists");
    } else {
    unless ( $rsmObj->{conn}->print("mkdir -p $dir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to create $dir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully created directory $dir");
    }
     
     # To copy the files from dev server to ATS server
    my %scpArgs;

    my $hostIp = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{2}->{IP}";
    my $hostUser = "$TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{2}->{USERID}";
    my $hostPasswd = "$TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{PASSWD}";
    my $hostDestPath = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{2}->{BASEPATH}";
    my $sourceFile = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{3}->{BASEPATH}";


    $scpArgs{-hostip} = $hostIp;
    $scpArgs{-hostuser} = $hostUser;
    $scpArgs{-hostpasswd} = $hostPasswd;
    $scpArgs{-destinationFilePath} = $hostDestPath;

    $scpArgs{-sourceFilePath} = $sourceFile;
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-sourceFilePath}";


        unless(&SonusQA::Base::secureCopy(%scpArgs)){
          $logger->error(__PACKAGE__ . ".  SCP failed to copy the log files : $sourceFile to destination");
          $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
          return 0;
        }


    # To copy the files from ATS server to RSM server
    my $rsmHostIp = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{IP}";
    my $rsmHostUser = "$TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{USERID}";
    my $rsmHostPasswd = "$TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD}";
    my $rsmHostDestPath = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{BASEPATH}";
    my $rsmSourceFile = "$TESTBED{'rsm:1:ce0:hash'}->{NODE}->{4}->{BASEPATH}";

   $scpArgs{-hostip} = $rsmHostIp;
   $scpArgs{-hostuser} = $rsmHostUser;
   $scpArgs{-hostpasswd} = $rsmHostPasswd;
   $scpArgs{-destinationFilePath} = $rsmHostDestPath;

    $scpArgs{-sourceFilePath} = $rsmSourceFile;
    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$scpArgs{-destinationFilePath}";


      unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".  SCP failed to copy the log files : $sourceFile to destination");
        $logger->debug(__PACKAGE__ . ".  <-- Leaving sub. [0]");
        return 0;
      }
  
    # Change directory
    my $rsmDir = $dir;
    $logger->info(__PACKAGE__ . ".$subName: <-- Changing directory to $rsmDir");
    unless ( $rsmObj->{conn}->print("cd $rsmDir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to change directory to $rsmDir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully changed directory to $rsmDir");

     # To untar RSM tar file
    my $tarFile = $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{BUILD};
    $logger->info(__PACKAGE__ . ".$subName: <-- Untar $tarFile");
    unless ( $rsmObj->{conn}->print("tar xvzf $tarFile") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to untar $tarFile");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully untar $tarFile");

     # To untar RSM install.tar file
    my $installFile = 'install.tar';
    $logger->info(__PACKAGE__ . ".$subName: <-- Untar $installFile");
    unless ( $rsmObj->{conn}->print("tar xvf $installFile") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to untar $installFile");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully untar $installFile");

    # Execute ./setup command
    my $cmd1 = "./setup"; 
    $logger->info(__PACKAGE__ . ".$subName: <-- Executing command $cmd1");
    unless ($rsmObj->{conn}->print($cmd1) ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $cmd1");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $cmd1");
   
   my ($prematch, $match);
   $logger->info(__PACKAGE__ . ".$subName: <-- Select the choice by number");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }       
    $rsmObj->{conn}->print("1");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected choice by number as 1");

   $logger->info(__PACKAGE__ . ".$subName:<-- Scroll down to accept license");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/GENBAND receives written agreement of the person or entity to which it will/')) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to scrolled down to accept license");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully scrolled down to accept license");

   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");
   $rsmObj->{conn}->print("\n");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to accept license term");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Do you agree to the above license terms/')) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to accept license term");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully accepted license term as yes");

   $logger->info(__PACKAGE__ . ".$subName:<-- Select the RSM server package");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')){
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("1");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected the RSM server package");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue installation process");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/continue/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue installation process");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue installation process");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to accept fresh Mysql server to install");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Do you want to install a fresh MySQL server/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get accept fresh Mysql server to install");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully accepted yes for fresh Mysql server to install");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to clean up the contents of /opt/nxtn/mysql/data");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Setup needs to clean up the contents of \/opt\/nxtn\/mysql\/data./')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to accept to clean up the contents /opt/nxtn/mysql/data");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully accepted yes to clean up the contents /opt/nxtn/mysql/data");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to clean up the contents /opt/nxtn/mysql/log");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Setup needs to clean up the contents of \/opt\/nxtn\/mysql\/log/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to accept to clean up the contents /opt/nxtn/mysql/log");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully accepted to clean up the contents /opt/nxtn/mysql/log");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter new password for MySQL root user");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Type new password for MySQL root user/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter new password for MySQL root user");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("root");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered  new password for MySQL root user");

   $logger->info(__PACKAGE__ . ".$subName:<-- Re-enter new password for MySQL root user");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Retype new password for MySQL root user/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to Re-enter new password for MySQL root user");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("root");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully Re-entered new password for MySQL root user");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter new database password for RSM");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Type new database password for RSM/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get enter new database password for RSM");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("root");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered new database password for RSM");

   $logger->info(__PACKAGE__ . ".$subName:<-- Re-enter new database password for RSM");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Retype new database password for RSM/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to Re-enter new database password for RSM");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("root");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully Re-entered new database password for RSM");

   my $rsmIp =  $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{IP};
   $logger->info(__PACKAGE__ . ".$subName:<-- Enter your host IP address");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter your host IP address/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter your host IP address");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("$rsmIp");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered your host IP address");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter your organization");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter your organization/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter your organization");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("sonus");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered your organization");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter your city");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter your city/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter your city");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("Bangalore");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered your city");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter your state");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter your state/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter your state");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("Karnataka");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered your city");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter your country code");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter your country code/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter your country code");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("91");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered your country code");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter key password");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Enter key password/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter key password");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("shipped!!");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered key password");

   $logger->info(__PACKAGE__ . ".$subName:<-- Re-enter key password");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Re-enter key  password/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to Re-enter key password");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("shipped!!");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully Re-entered key password");

   my $timeout = 2400;
   $logger->info(__PACKAGE__ . ".$subName:<-- Select the type of action which will be added to Default Alarms");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/This will not create any action/', timeout => $timeout)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to select the type of action which will be added to Default Alarms");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("3");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected the type of action which will be added to Default Alarms");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to create a bonded interface");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Do you want to create a bonded interface to be used as management interface/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create a bonded interface");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected NO to create a bonded interface");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/continue/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }

    $rsmObj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/continue/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }

    $rsmObj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter choice to exit from genband utility");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to exit from genband utility");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("q");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully exit from genband utility");
}

=over

=item DESCRIPTION: RSM UnInstallation from Hardware

=item AUTHOR: Yashawanth M M

=back

=cut

sub UnInstallRsmFromHardware{

    my $subName = 'UnInstallRsmFromHardware';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my (%TESTBED) = @_;
    my $testbed = keys %TESTBED;
    my $dir = $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{BASEPATH};

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub ");

      my $rsmObj = SonusQA::RSM->new(

          -OBJ_HOST     => $TESTBED{'rsm:1:ce0:hash'}->{NODE}->{1}->{IP},
          -OBJ_USER     =>  $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{USERID},
          -OBJ_PASSWORD =>   $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{2}->{PASSWD},
          -ROOTPASSWD =>  $TESTBED{'rsm:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD},
          -skip => 1,
          -OBJ_COMMTYPE => "SSH",
          -sessionlog   => 1,
       );

  # Change directory
    my $rsmDir = $dir;
    $logger->info(__PACKAGE__ . ".$subName: <-- Changing the directory to $rsmDir");
    unless ( $rsmObj->{conn}->print("cd $rsmDir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to change directory to $rsmDir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully changed directory to $rsmDir");

    # Execute ./setup command
    my $cmd1 = './setup';
    $logger->info(__PACKAGE__ . ".$subName: <-- Executing command $cmd1");
    unless ($rsmObj->{conn}->print("$cmd1") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $cmd1");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $cmd1");

   my ($prematch, $match);
   $logger->info(__PACKAGE__ . ".$subName: <-- Select choice by number");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("2");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected choice by number as 1");

   $logger->info(__PACKAGE__ . ".$subName:<-- Select the RSM server package");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')){
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("1");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected the RSM server package");

   $logger->info(__PACKAGE__ . ".$subName:<-- Select Uninstall RSM package");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Uninstall RSM package/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to select uninstall RSM package");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected the Uninstall RSM  package");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter password for MySQL root user");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Type password for MySQL root user/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter password for MySQL root user");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("root");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered password for MySQL root user");

   $logger->info(__PACKAGE__ . ".$subName:<-- Uninstall /usr/lib/jvm/java");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Uninstall \/usr\/lib\/jvm\/java/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to uninstall /usr/lib/jvm/java");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully uninstalled /usr/lib/jvm/java");

   $logger->info(__PACKAGE__ . ".$subName:<-- Remove /opt/nxtn/mysql/data and /opt/nxtn/mysql/log");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Remove \/opt\/nxtn\/mysql\/data and \/opt\/nxtn\/mysql\/log/')){
        $logger->error(__PACKAGE__ . ".$subName: Failed to Remove /opt/nxtn/mysql/data and /opt/nxtn/mysql/log");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully removed /opt/nxtn/mysql/data and /opt/nxtn/mysql/log");

   my $timeout = 900;
   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/continue/', timeout => $timeout)){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter choice to exit from genband utility");
   unless ( my ($prematch, $match) = $rsmObj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to exit from genband utility");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $rsmObj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $rsmObj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $rsmObj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $rsmObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $rsmObj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $rsmObj->{conn}->print("q");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully exit from genband utility");
}

=over

=item DESCRIPTION: SBC Installation on Hardware

=item AUTHOR: Yashawanth M M

=back

=cut

sub standaloneSBCInstallation{

    my $subName = 'InstallSBC';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my (%TESTBED) = @_;
    my $testbed = keys %TESTBED;
    my $dir = $TESTBED{'qsbc:1:ce0:hash'}->{NODE}->{1}->{BASEPATH};


    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub ");

         my $obj = SonusQA::QSBC->new(-OBJ_HOST => $TESTBED{'qsbc:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},
                               -OBJ_USER => $TESTBED{'qsbc:1:ce0:hash'}->{LOGIN}->{1}->{USERID},
                               -OBJ_PASSWORD => $TESTBED{'qsbc:1:ce0:hash'}->{LOGIN}->{1}->{PASSWD},
                               -OBJ_COMMTYPE => "SSH",
                               
                              );

    # To create directory
    if ( -d $dir)
    {
        $logger->error(__PACKAGE__ . ".$subName: $dir already exists");
    } else {
    unless ( $obj->{conn}->print("mkdir -p $dir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to create $dir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully created directory $dir");
    }

   # Change directory
    $logger->info(__PACKAGE__ . ".$subName: <-- Changing directory to $dir");
    unless ( $obj->{conn}->print("cd $dir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to change directory to $dir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully changed directory to $dir");

   # Copy SBC tar file from release server to QSBC server
    my ($prematch, $match);
    my $timeout = 1800;
    $logger->info(__PACKAGE__ . ".$subName:<-- Copy file from release server to QSBC server");
    my $sbcPath = $TESTBED{'qsbc:1:ce0:hash'}->{NODE}->{3}->{BASEPATH};
    my $cmd1 = "wget $sbcPath";
    unless ($obj->{conn}->print($cmd1) ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $cmd1");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $cmd1");

   unless (my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/100/', timeout => $timeout)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to copy file from release server");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully copied file from release server");

    # To untar SBC tar file
    my $sbcTar = $TESTBED{'qsbc:1:ce0:hash'}->{NODE}->{1}->{BUILD};
    unless ( $obj->{conn}->print("tar xvzf $sbcTar") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command tar xvzf $sbcTar");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command tar xvzf $sbcTar");

   my $timeout1 = 120; 
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/iserverinstall.tar/', timeout => $timeout1)) {
        $logger->error(__PACKAGE__ . ".$subName: unable to untar $sbcTar");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully untar $sbcTar");


    # Change directory
    my $dir1 = $TESTBED{'qsbc:1:ce0:hash'}->{NODE}->{2}->{BASEPATH};
    $logger->info(__PACKAGE__ . ".$subName: <-- Change directory to $dir1");
    unless ( $obj->{conn}->print("cd $dir1") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to change directory to $dir1");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully changed directory to $dir1");


     # To untar SBC install.tar file
    my $installFile = 'install.tar';
    $logger->info(__PACKAGE__ . ".$subName: <-- Untar $installFile");
    unless ($obj->{conn}->print("tar xvf $installFile") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to untar $installFile");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully untar $installFile");
 
#    # Linux Master updater
#    my $gis_version = 'patch_9.4.0.0rc3';
#    my %args=@_;        
#    %args=(path=>'/var/builds/',
#        gis_version=>$gis_version
#        );              
#    $obj->linuxHandler(%args);
#
#    # Install media processor
#    $obj->mediaAppInstall('version'=>'9.4.0.0','path'=>'/var/genband/builds/SBC/', 'force'=>'--force')
#

    # Execute ./setup command
    my $cmd2 = './setup';
    $logger->info(__PACKAGE__ . ".$subName: <-- Executing command $cmd2");
    unless ($obj->{conn}->print("$cmd2") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $cmd2");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $cmd2");

   $logger->info(__PACKAGE__ . ".$subName: <-- Select choice by number");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("1");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected choice by number as 1");

   $logger->info(__PACKAGE__ . ".$subName:<-- Scroll down to accept license");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Additional copyright notices and license terms applicable to portions of the software can be found/')) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to scrolled down to accept license");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully scrolled down to accept license");

   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n"); 
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n"); 
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");
   $obj->{conn}->print("\n");

   $logger->info(__PACKAGE__ . ".$subName:<-- Accept license term");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Do you agree to the above license terms/')) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to accept license term");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully accepted license term as yes");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter a new password for the iServer database user");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter a new password for the iServer database user/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter new password for the iServer database user");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("shipped!!");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered a new password for the iServer database user");

   $logger->info(__PACKAGE__ . ".$subName:<-- Retype the password you entered for the iServer database user");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Retype the password you entered for the iServer database user/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to reenter new password for the iServer database user");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("shipped!!");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully Reentered password for the iServer database user");

   my $timeout2 = 300;
   $logger->info(__PACKAGE__ . ".$subName:<-- Select standalone or cluster");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Select your choice/', timeout => $timeout2)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to select standalone");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("a");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully selected standalone");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter the management ip address");
   my $sbcIp = $TESTBED{'qsbc:1:ce0:hash'}->{MGMTNIF}->{1}->{IP};
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter the management IP address/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter the management ip address");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("$sbcIp");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered the management ip address");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter the management IPv6 address");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter the management IPv6 address/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter the management IPv6 address");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered the management IPv6 address");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to commit the changes");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Do you want to commit the changes/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to enter commit the changes");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered yes to commit the changes");

   my $timeout3 = 600;
   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/continue/', timeout => $timeout3)){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter choice to exit from genband utility");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to exit from genband utility");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("q");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully exit from genband utility");

    my $shellcmd = 'source ~/.bashrc';
    $logger->info(__PACKAGE__ . ".$subName: <-- Executing command $shellcmd");
    unless ($obj->{conn}->cmd("$shellcmd") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $shellcmd");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $shellcmd");
  
}

=over

=item DESCRIPTION: SBC UnInstallation on Hardware

=item AUTHOR: Yashawanth M M

=back

=cut

sub standaloneSBCUnInstallation(){

    my $subName = 'UnInstallSBC';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my (%TESTBED) = @_;
    my $testbed = keys %TESTBED;

    my $dir = $TESTBED{'qsbc:1:ce0:hash'}->{NODE}->{2}->{BASEPATH};

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub ");

         my $obj = SonusQA::QSBC->new(-OBJ_HOST => $TESTBED{'qsbc:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},,
                               -OBJ_USER => $TESTBED{'qsbc:1:ce0:hash'}->{LOGIN}->{1}->{USERID},,
                               -OBJ_PASSWORD => $TESTBED{'qsbc:1:ce0:hash'}->{LOGIN}->{1}->{PASSWD},,
                               -OBJ_COMMTYPE => "SSH",

                              );

    $logger->info(__PACKAGE__ . ".$subName: <-- Changing directory to $dir");
    unless ( $obj->{conn}->cmd("cd $dir") ) {
        $logger->error(__PACKAGE__ . ".$subName:  unable to change directory to $dir");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully changed directory to $dir");

    # Execute ./setup command
    my $cmd1 = './setup';
    $logger->info(__PACKAGE__ . ".$subName:<-- Executing command $cmd1");
    unless ($obj->{conn}->print("$cmd1") ) {
       $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->error(__PACKAGE__ . ".$subName:  unable to execute command $cmd1");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully executed command $cmd1");

   my ($prematch, $match); 
   $logger->info(__PACKAGE__ . ".$subName:<-- Select choice to uninstall SBC");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Select choice by number or type q to quit/')) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("2");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected choice by number as 2");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to uninstall iserver version");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Are you sure you want to uninstall iServer version/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Are you sure you want to uninstall iServer version'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected yes to uninstall iserver version");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to Backup iserver database");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Do you want to backup the iServer database/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Do you want to backup the iServer database'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->cmd("y");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully selected yes to backup iserver database");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter full pathname of backup database");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter full pathname of backup database/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Enter full pathname of backup database'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully entered pathname to backup database");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to Backup iServer configuration files");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Do you want to backup the iServer configuration files/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Do you want to backup the iServer configuration files'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully entered yes to backup the iServer configuration files");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter full pathname of the directory to copy the backup files");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter full pathname of the directory to copy the backup files/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Enter full pathname of the directory to copy the backup file'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully entered full pathname of the directory to copy the backup files");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter yes or no to Backup the iServer license file");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Do you want to backup the iServer license file/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Do you want to backup the iServer license file'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("y");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully entered yes to backup the iServer license file");

   $logger->info(__PACKAGE__ . ".$subName:<-- Enter full pathname for license file");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Enter full pathname for license file/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to get message 'Enter full pathname for license file'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName: <-- Successfully entered full pathname for license file");

   my $timeout = 180;
   $logger->info(__PACKAGE__ . ".$subName:<-- Enter to continue");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/continue/', timeout => $timeout)){
        $logger->error(__PACKAGE__ . ".$subName: Failed to continue");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("\n");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully entered to continue");

   $logger->info(__PACKAGE__ . ".$subName:<-- Select choice to exit from genband utility");
   unless ( my ($prematch, $match) = $obj->{conn}->waitfor( -match     => '/Select choice by number/')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to exit from genband utility");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $obj->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $obj->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $obj->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $obj->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $obj->{conn}->print("q");
    $logger->info(__PACKAGE__ . ".$subName:<-- Successfully exit from genband utility");

}

1;
