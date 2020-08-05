package SonusQA::GSX::PERFHELPER;

=head1 NAME

 SonusQA::GSX::GSXHELPER - Perl module for Sonus Networks GSX 9000 interaction

=head1 SYNOPSIS

 This Module is specific to GSX Performance test cases but can also be used for other testing purpose.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Utils, Data::Dumper, POSIX

=head1 METHODS

=cut

use SonusQA::Utils qw(:all logSubInfo);
use SonusQA::Base;
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use File::stat;
use File::Basename;
use Text::CSV;
use Time::HiRes qw(gettimeofday tv_interval);
use Tie::IxHash;
use Time::Local;
use Net::SFTP;
use Net::SFTP::Foreign;

our $VERSION = "6.1";
our $resetPort = 0;
our $portType;

use vars qw($self);

sub getNifIp {
    my ($obj,$dsiobj) = @_;
    my $sub = ".getNifIp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my @r;
    my @nifIp;
    my $retVal = 1;

    unless ( @r = $obj->execCmd("SHOW NIF ALL ADMIN") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)) ;# if $logger->is_debug();
    foreach (@r) {
        if (m/\D(\d+)\s+(\d+)\s+(.*)\s+(\d+)\s+(\w+)\s+(.*?)\s\s+(\d+)/){
            push @nifIp ,$6;
        }
    }
#Check if all the nifs are active
    foreach (@nifIp) {
        $logger->debug(__PACKAGE__ . "IP $_ is going to ping");
        my $value = $dsiobj->pingHost("$_"); # obj changed in automation to accomodate the ping from outside GSX
        $logger->debug(__PACKAGE__ . "the retun value for pingHost is $value\n");
        if (!$value){
            $logger->debug(__PACKAGE__ . "IP $_ is down");
            $retVal = 0;
        }
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

#%sh trunk group all st
#Node: PHOBOS                                   Date: 2013/06/01 14:05:01  GMT
#                                               Zone: GMTMINUS05-EASTERN-US
#
#                                                      Outbound Calls
#                         Total Calls   In Calls    Usages     Resv    Oper
#  Local Trunk Name       Conf  Avail  Resv Usage no-pri   pri        State
#----------------------- ------------ ----------- ------------------ -----------
#defaultiptg             UNLMT UNLMT      0     0      0     0     0 INSERVICE
#1-PHOBOS-ISUP-ATT       3024  0          0     0      0     0     0 INSERVICE

sub getTrunkGroupStatus{
    my ($obj) = @_;
    my $sub = ".getTrunkGroupStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my @r;
    my ($confCir,$availCir,$tgName);
    my $retVal = 1;

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    unless ( @r = $obj->execCmd("SHOW TRUNK GROUP ALL STATUS") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r));

    foreach (@r) {
        if (m/(.*?)\s\s+(\w*|\d*)\s+(\w*|\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w)/){
            $tgName = $1;
            $confCir = $2;
            $availCir = $3;
            if ( $confCir != $availCir ) {
               $retVal = 0;
               $logger->debug(__PACKAGE__ . "$sub trunk group $tgName has $confCir config'd and only $availCir available circuit");
            }
        }
   }
   $logger->debug(__PACKAGE__ . "$sub <== Leaving");
   return $retVal;
}

#%SHOW SONUS SOFTSWITCH ALL STATUS
#Node: PHOBOS                                   Date: 2013/06/18 17:03:13  GMT
#                                               Zone: GMTMINUS05-EASTERN-US
#
#SoftSwitchName          State    Congest Completed            Retries    Failed
#--------------------------------------------------------------------------------
#puttur                  ACTIVE    CLEAR  0                    0          0

sub getPsxStatus{
    my ($obj) = @_;
    my $sub = ".getPsxStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my @r;
    my $psxState;
    my $retVal = 1;

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    unless ( @r = $obj->execCmd("SHOW SONUS SOFTSWITCH ALL STATUS") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result: ");
    }   
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)) ;# if $logger->is_debug();


    foreach (@r) {
        if (m/(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)/){
            $psxState = $2;
                if ($psxState ne "ACTIVE"){
                    $retVal = 0;
                    $logger->debug(__PACKAGE__ . "$sub The PSX State is $psxState");
                }
        }
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}


sub getMLPPSetting{
    my ($obj) = @_;
    my $sub = ".getMLPPSetting";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my @lic = ("MLPP", "HPC" );
    my $retVal = 1;
    my $licStatus;

    my $psxIPAddress      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $psxOracleUserName      = $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $psxOraclePassword       = $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $oracleSession = new SonusQA::Base( -obj_host   => "$psxIPAddress",
                                           -obj_user       => "$psxOracleUserName",
                                           -obj_password   => "$psxOraclePassword",
                                           -comm_type      => 'SSH',
                                           -return_on_fail => 1,
                                           -sessionlog => 1,
                                           -defaulttimeout => 120,
                                         );
    unless ($oracleSession) {
        $logger->error("Unable to open a session to PSX $psxIPAddress");
        return 0;
    }

    my $cmdString = "sqlplus '/ as sysdba'";
    $logger->debug("Executing a command :-> $cmdString");
    my @r;

    #my @r = $oracleSession->{conn}->cmd("$cmdString");
    #sleep (5);
    #$logger->debug("Command Output : @r");
# Added the new code as part of SQL prompt waiting and command to execute to get the MLPP information.

    unless ($oracleSession->{conn}->cmd(String => "$cmdString", Prompt => '/SQL\>/') ) {
        $logger->warn(__PACKAGE__ . ".execSqlplusCommand: UNABLE TO ENTER SQL ");
        &error("CMD FAILURE: $cmdString ") if($oracleSession->{CMDERRORFLAG});
        $logger->debug(__PACKAGE__ . ".execSqlplusCommand: errmsg: " . $oracleSession->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execSqlplusCommand: Session Dump Log is : $oracleSession->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execSqlplusCommand: Session Input Log is: $oracleSession->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".execSqlplusCommand: <-- Leaving sub [0]");
        return 0;
    }

    foreach(@lic) {
        $cmdString = "select * from license_feature where feature_name like '%$_%';";
        $logger->debug("Executing a command :-> $cmdString");
        @r = $oracleSession->{conn}->cmd("$cmdString");
        $logger->debug("Command Output : @r");
        sleep (1);
            foreach (@r) {
                if (m/(\w+)\s+(\d+)\s+(\d+)/){
                    $licStatus = $3;
                    $logger->debug("Output of a command Perminder :-> $licStatus");
                    if($licStatus != 0){
                        $retVal = 0;
                    }
                }
            }
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

#%SHOW EVENT LOG ALL ADMIN
#Node: PHOBOS                                   Date: 2013/06/19 04:36:54  GMT
#                                               Zone: GMTMINUS05-EASTERN-US
#
#            File  File   File           Mem
#       File Size  Msg    Write   Save   Size Filter   Admin
#Type   Cnt  (KB)  Queue  Mode    To     (KB) Level    State
#------ ---- ----- ----- -------- ------ ---- -------- --------
#SYSTEM 10   16384 10    OPTIMIZE BOTH   16   MAJOR    ENABLED
#DEBUG  10   16384 10    OPTIMIZE BOTH   16   MAJOR    ENABLED
#TRACE  32   2048  10    OPTIMIZE MEMORY 16   MAJOR    ENABLED

sub checkEventLog{
    my ($obj) = @_;
    my $sub = ".checkEventLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my @r;
    my ($logType,$writeMode,$filterLevel,$adminState);
    my $retVal = 1;

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    unless ( @r = $obj->execCmd("SHOW EVENT LOG ALL ADMIN") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)) ;# if $logger->is_debug();

    foreach (@r) {
        if (m/(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\w+)\s+(\w+)/){
            $logType = $1;
            $writeMode = $5;
            $filterLevel = $8;
            $adminState = $9;
            if ( ($writeMode ne "OPTIMIZE") || ($filterLevel ne "MAJOR") || ($adminState ne "ENABLED") ) {
                $logger->debug(__PACKAGE__ . "$sub Check the event logging for $logType:");
                $retVal = 0;
            }
        }
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}
#%SHOW REDUNDANCY GROUP SUMMARY
#Node: PHOBOS                                   Date: 2013/06/02 07:29:35  GMT
#                                               Zone: GMTMINUS05-EASTERN-US
#
#------------------------------------------------------
#        REDUNDANCY GROUPS SUMMARY
#------------------------------------------------------
#
#                             Redundant                 Server
#  Name              Shelf      Slot       Type        Function        State
# ----------------  -------  -----------  -------  ----------------  ----------
#  MNS20-1             1          2        MNS20     MGMT             ENABLED
#  PNS41-1-9           1          9        PNS41     ENET             ENABLED

sub checkRedundancyStaus{
    my ($obj) = @_;
    my $sub = ".checkRedundancyStaus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my @r;
    my (@groupName,$status,$redState);
    my $retVal = 1;

    unless ( @r = $obj->execCmd("SHOW REDUNDANCY GROUP SUMMARY") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)) ;# if $logger->is_debug();

    foreach (@r) {
        if (m/(.*?)\s\s+(\d+)\s+(\d+)\s+(\w+|\d+)\s+(\w+)\s+(\w+)/){
            $redState = $6;
            if ( $redState eq "DISABLED") {
                $logger->debug(__PACKAGE__ . "$sub Redundancy state is disble for @groupName");
                $retVal = 0;
                return $retVal;
            } else {
                push @groupName , $1;
            }
        }
    }
    foreach (@groupName) {
        unless ( @r = $obj->execCmd("SHOW REDUNDANCY GROUP $_ STATUS") ) {
        $logger->error(__PACKAGE__ ."$sub Remote command execution failed, data maybe incomplete, result:");
    }
       $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)) ;# if $logger->is_debug();

        foreach (@r) {
            if (m/\s+(\d+)\s+(\w+)/){
            $status = $2;
                if ($status ne "ACTIVESYNCED"){
                    $logger->debug(__PACKAGE__ . "$sub Redundancy Status is Not in SYNC for @groupName");
                    $retVal = 0;
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

sub sourceTCL{

    my ($dsiobj,$gsxobj,$testbed) = @_;
    my $sub = ".sourceTCL";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    
    my $gsxName = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

    my $sysinitPath = "/export/home/SonusNFS/$gsxName/cli/sys";
    my $cmdString = "cd /export/home/SonusNFS/$gsxName/cli/sys";
    $logger->debug("Executing a command :-> $cmdString");

    my @r = $dsiobj->execCmd("$cmdString");

    if(grep(/no.*such.*dir/i , @r)) {
        $logger->error(__PACKAGE__ . ".$sub directory not present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }
    sleep (1);
    $cmdString = "cp sysinit.tcl_TB_$testbed sysinit.tcl";
    $logger->debug("Executing a command :-> $cmdString");
    @r = $dsiobj->execCmd("$cmdString");
    if(grep(/no.*such.*dir/i , @r)) {
        $logger->error(__PACKAGE__ . ".$sub  no file present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");

    return 1;
}

sub clearNfsLogs{

    my ($dsiobj,$gsxobj) = @_;
    my $sub = ".clearNfsLogs";
    my @logType = ('DBG', 'ACT', 'SYS');
    my @r;
    my @lastFile;
    my @retVal;


    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $gsxName      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
    my $sonicId      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SONICID};

    my $log = "/export/home/SonusNFS/$gsxName/evlog/$sonicId";


    foreach(@logType){

        my $cmdString = "cd $log/$_";
        my @r = $dsiobj->SonusQA::TOOLS::execCmd("$cmdString");

        if(grep(/no.*such.*dir/i , @r)) {
           $logger->error(__PACKAGE__ . ".$sub directory not present");
           $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
           return 0;
        }
        sleep (1);
        my $cmd = "ls -tr *.$_ | tail -1";

        my @lastFile = $dsiobj->SonusQA::TOOLS::execCmd($cmd);
        if(grep(/no.*such.*dir/i , @lastFile)) {
           $logger->error(__PACKAGE__ . ".$sub directory not present");
           $logger->debug(__PACKAGE__ . ".$sub No such file or directory");
        } else {
            $logger->info(__PACKAGE__ . ".$sub: going to remove all the file except most recent one");
            $cmdString = "rm -rf `ls -tr *.$_ | grep -v @lastFile`";
            $logger->debug("Executing a command :-> $cmdString");
            my @retVal = $dsiobj->SonusQA::TOOLS::execCmd($cmdString);
        }

         $logger->debug(__PACKAGE__ . "$sub the last file is" . Dumper(\@lastFile)) ;# if $logger->is_debug();

         $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@retVal)) ;# if $logger->is_debug();

        #@r = $dsiobj->SonusQA::GSX::execCmd("$cmdString");
        #foreach(@r){
        #   $cmdString = "/usr/bin/rm -f $_";
           #$logger->debug("Executing a command :-> $cmdString");
        #   my @retVal = $dsiobj->execCmd("$cmdString");
        #   sleep (1);
        #}
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return 1;
}
sub getListOfFilesFromNFS{

    my ($dsiobj,$destDir,$logType) = @_;
    my $sub = ".clearNfsLogs";
    my @r;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");



        my $cmdString = "cd $destDir";
        @r = $dsiobj->SonusQA::GSX::execCmd("$cmdString");
        if(grep(/no.*such.*dir/i , @r)) {
           $logger->error(__PACKAGE__ . ".$sub directory not present");
           $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
           return 0;
        }
        sleep (1);
        my $cmd = "ls -tr *.$logType";
        my @fileList = $dsiobj->SonusQA::GSX::execCmd("$cmd");

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");

    return @fileList;
}


sub collectLogFromNFS{

    my ($obj, $src_dir) = @_;
    my ($dest_ip, $dest_userid, $dest_passwd, $dest_dir ,%scpArgs);
    my ($sftp_session,@logType,@srcSubDir,$srcPath,$dstPath,$retVal,$gsxName,$sonicId,$paramFile,$sysinitOut);
    my $sub = ".collectLogFromNFS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    $retVal = 1;
    @logType = ('SYS','DBG','ACT');

    $sonicId      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SONICID};
    $dest_dir     = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{LOG_DIR};
    $dest_ip      = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{IP};
    $dest_userid  = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{USERID};
    $dest_passwd  = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{PASSWD};
    $gsxName      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

    $logger->debug(__PACKAGE__ . ".$sub:  src dir $src_dir and det dir $dest_dir  and gsx name $gsxName" );

    my @subDirs = split(/\//,$dest_dir);

    @srcSubDir = split(/\//,$src_dir);

    #$gsxName = $subDirs[4];
    #$sonicId = $subDirs[6];
     
    $paramFile = "/export/home/SonusNFS/$gsxName/param/$sonicId.prm";
    $sysinitOut = "/export/home/SonusNFS/$gsxName/cli/logs/$sonicId/sysinit.tcl.out";

    # Checking mandatory args;
    if ((defined $dest_ip) && (defined $dest_userid) && (defined $dest_passwd) && (defined $dest_dir) && (defined $src_dir)) {
        $logger->info(__PACKAGE__ . ".$sub Mandatory Input parameters have been provided");
    } else {
        $logger->error(__PACKAGE__ . ".$sub: Please provide all the following MANDATORY parameters");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub:  Opening SFTP session to NFS server, ip = $dest_ip, user = $dest_userid, passwd = TMS_ALIAS->NFS->1->PASSWD");
    $scpArgs{-hostip} = $dest_ip;
    $scpArgs{-hostuser} = $dest_userid;
    $scpArgs{-hostpasswd} = $dest_passwd;


    #######Move log to server 

    #Check if OneCallLog needs to be collected or all
    if(grep(/OneCallLog/i, @srcSubDir)) {
        foreach (@logType) {
          $srcPath = "$dest_dir$_/*.$_" ;
          $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$srcPath";
          $scpArgs{-destinationFilePath} = $src_dir;
          unless(&SonusQA::Base::secureCopy(%scpArgs)){
              $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
              $retVal = 0;
          }  else {
              $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $src_dir from NFS $srcPath");
          }


        }
    } else {
#Move param file
      $dstPath = $src_dir.'PARAM';
      $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$paramFile";
      $scpArgs{-destinationFilePath} = $dstPath;
          unless(&SonusQA::Base::secureCopy(%scpArgs)){
              $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
              $retVal = 0;
          }  else {
              $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $src_dir from NFS $paramFile");
          }
 
#Move sysinti.tcl.out  file
      $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$sysinitOut";
      $scpArgs{-destinationFilePath} = $dstPath;
          unless(&SonusQA::Base::secureCopy(%scpArgs)){
              $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
              $retVal = 0;
          }  else {
              $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $src_dir from NFS $sysinitOut");
          }

#Move ACT/SYS/DBG files

      foreach (@logType) {
           $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$dest_dir$_/*.$_" ;
           $scpArgs{-destinationFilePath} = "$src_dir/$_";

           unless(&SonusQA::Base::secureCopy(%scpArgs)){
              $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
              $retVal = 0;
          }  else {
              $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $src_dir from NFS");
          }

      }
    }

   return $retVal;
}

sub collectLogFromRemoteServer{
 my ($src_ip, $username, $passwd , $src_dir, $dest_dir) = @_;
    #my ($dest_ip, $dest_userid, $dest_passwd);
    my ($sftp_session,@logType,$srcPath,$dstPath,$retVal,%scpArgs);

    my $sub = ".collectLogFromRemoteServer";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    $retVal = 1;
    $logger->debug(__PACKAGE__ . ".$sub:  Source Dir: $src_dir, Destination Dir: $dest_dir, Source IP: $src_ip");

    # Checking mandatory args;
    if ((defined $src_ip) && (defined $username) && (defined $passwd) && (defined $src_dir) && (defined $dest_dir)) {
        $logger->info(__PACKAGE__ . ".$sub Mandatory Input parameters have been provided");
    } else {
       $logger->error(__PACKAGE__ . ".$sub: Please provide all the following MANDATORY parameters");
       return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub:  Opening SCP session to Remote server ip:$src_ip,user:$username");


     $scpArgs{-hostip} = $src_ip;
     $scpArgs{-hostuser} = $username;
     $scpArgs{-hostpasswd} = $passwd;
     $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$src_dir/*.*";
     $scpArgs{-destinationFilePath} = "$dest_dir/";

        unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
           $retVal = 0;
           return 0;
        }
   return $retVal;

}


sub checkSysinitOutput{
    my ($obj,$gsxName,$serialNum) = @_;
    my $sub = ".checkSysinitOutput";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my $sysinitOutFile = "/export/home/SonusNFS/$gsxName/cli/logs/$serialNum/sysinit.tcl.out";
    my $pattern = "END OF SCRIPT";
    my $retVal = 0;

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my $cmdString = "grep \"$pattern\" $sysinitOutFile";

    $logger->debug("Executing a command :-> $cmdString");
    my @r;
    unless (@r = $obj->{conn}->cmd(String => $cmdString)) {
            $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECUTION ERROR OCCURRED");
    }


    $logger->debug(__PACKAGE__ . "$sub  the return value of " . Dumper(\@r)) ;# if $logger->is_debug();
    sleep (1);

    if ( grep /$pattern/,@r){ 
        $retVal = 1;
        $logger->debug(__PACKAGE__ . "$sub <== pattern matched tcl file sourced properly");
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

sub getSeaGirtLink{
    my ($dirPath) = @_;
    my $sub = ".getSeaGirtLink";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my ($runId,$output,$link,$fileName,$perfLoggerPath) ;
    my $pattern = "test-run:";	

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    $perfLoggerPath = $dirPath.'perflogger';
    $logger->info("INFO - The perfLogger path is: $perfLoggerPath");

    $fileName = `ls -tr $perfLoggerPath/*.log`;
    if(!$fileName){
            $logger->debug(__PACKAGE__ . ".$sub: File (*.log) not found ");
            return 0;
        }else{
            $logger->info("INFO - The perfLogger file name is: $fileName");
    }
    $output = `grep \"$pattern\" $fileName`;

    $runId = substr($output, index($output,"$pattern") + 11);

    $logger->debug("Executing a command :-> $output");
    $logger->info("INFO: THE RUNID :-> $runId");
    $link = "http://seagirt.nj.sonusnet.com/PTDATA/plot.php?product=gsx&slot=1&runuuid=$runId";

    $logger->debug("THE LINK :-> $link");

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $link;
}
##################################################################################################
###Directory structure:e.g. /sonus/PerfDataBkup/Release/V09.00.00R000/GSXNBS/GSX-103/testbed_A/20130607
##################################################################################################

sub createDirStr{

    my ($path) = @_;
    my (@subDirs,$dir);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d_%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

    my $sub = ".createDirStr";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    @subDirs = split(/\//,$path);
    push @subDirs,$timestamp;
    $dir = "";
    $logger->debug("the directory structure :-> @subDirs");
    foreach(@subDirs){
       $dir .= $_."/";
       if(!-d $dir){
             unless ( system ( "mkdir -pm 777 $dir" ) == 0 ) {
                 $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                 return 0;
             }
       }  
    }
   #create remaining dir ACT,DBG,SYS,NAVTEL_DATA,perflogger,OneCallLog,PARAM,INET_DATA
   unless ( system ("mkdir -pm 777 $dir/ACT $dir/DBG $dir/SYS $dir/NAVTEL_DATA $dir/perflogger $dir/OneCallLog $dir/PARAM $dir/INET_DATA $dir/checkList") == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                return 0;
    }
    
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $dir;
}


sub genReport {

    my ($msgString,$fileName) = @_;
    open reportOpen, ">>$fileName" or die $!;
    print reportOpen $msgString;
    close reportOpen;
}

sub pretest_checkList{
    my ($gsxobj,$psxobj,$dsiobj,$testbed,$reportPath) = @_;
    my $sub = ".pretest_checkList";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my $result = 1;
    my ($retVal,$gsxName,$psxName,$reportName,$version,$sonicId);
    $version = "V09.00";
	

    # Create timestamp for logfile naming
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;


    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    $psxName      = $psxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
    $gsxName      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
    $sonicId      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SONICID};

#######################Generate Report#########################################

##################"#############################################################
########################## Check if NIF is INSERVICE  #########################
    my $fileHeader = "=======>PRE TEST EXECUTION REPORT FOR GSX $gsxName<=======\n\n";

    $reportName = "$reportPath/REPORT_$gsxName\_$timestamp.txt";

    genReport ("$fileHeader",$reportName);

    $retVal = getNifIp($gsxobj,$dsiobj);
    if ($retVal){
        genReport ("GSX $gsxName all the Nif's are UP==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
    } else {
        genReport ("GSX $gsxName some of the  Nif's are DOWN==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

###############################################################################
########################## Check if EVLOG is MAJOR  ###########################
    $retVal = checkEventLog($gsxobj);
    if ($retVal){
        genReport ("GSX $gsxName  Event Log's are MAJOR==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
    } else {
        genReport ("GSX $gsxName Event Log's are not MAJOR==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

###############################################################################
####################Check if PSX is ACTIVE and Configured Correctly ###########
    $retVal = getPsxStatus($gsxobj);
    if ($retVal){
        genReport ("PSX is ACTIVE on GSX $gsxName==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
    } else {
        genReport ("PSX is DOWN on GSX $gsxName==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

###############################################################################
######################## Check if Redundacy is in SYNC ########################
    $retVal = checkRedundancyStaus($gsxobj);
    if ($retVal){
        genReport ("GSX $gsxName Redundacy is in SYNC==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
    } else {
        genReport ("GSX $gsxName Redundacy is not in SYNC==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

###############################################################################
######################## Check if Trunk Group is UP ###########################

    if ( ($testbed eq "C") || ($testbed eq "D") ) {
        $retVal = getTrunkGroupStatus($gsxobj);
        if ($retVal){
            genReport ("GSX $gsxName Trunk group's are UP==>PASS\n\n", $reportName);
            $logger->debug(__PACKAGE__ . "$sub ==> return value$retVal");
        } else {
            genReport ("GSX $gsxName Trunk group's are DWON==>FAIL\n\n", $reportName);
            $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
            $result = 0;
        }
    }else {
        genReport ("GSX $gsxName Trunk group's are UP==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value$retVal");
    }

###############################################################################
######################## Check if MLPP is Enable/Disable ######################
###############################################################################
    $retVal = getMLPPSetting($psxobj);
    if ($retVal){
        genReport ("PSX $psxName MLPP/HPC Feature is DISABLE==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value$retVal");
    } else {
        genReport ("PSX $psxName MLPP/HPC Feature is ENABLE==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

###############################################################################
######################## Check if sysinit.tcl ran properly ####################
###############################################################################

    $retVal = checkSysinitOutput($dsiobj,$gsxName,$sonicId);
    if ($retVal){
        genReport ("GSX $gsxName TCL FILE SOURCED CORRECTLY==>PASS\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value $retVal");
    } else {
        genReport ("GSX $gsxName TCL FILE FAIL TO SOURCE CORRECTLY==>FAIL\n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$retVal");
        $result = 0;
    }

return $result;
}

=head2 startPerfLogger()

    This function enables user to start perflogger script(used for collecting performance stats of SUT) as background process and returns the PID of the process in which perflogger was started.

Arguments:
    Mandatory
        -testcase => "EMS_GUI_PERF_001" Test case ID
        -sut  => "orsted" EMS device for which Performance stats has to be collected.
        -testbed  => "A" Test bed type A for solrias and B for linux
        -upload => "n" whether we attempt to push results to the DB. If the input is not 'n|N', it is assumed pushing results to DB is required.
        -path => "n" whether we attempt to push results to the DB. If the input is not 'n|N', it is assumed pushing results to DB is required.

Return Value:

    0 - on failure
    PID of the process in which perflogger was started.

Usage:
    my $pl_pid = $atsObj->start_perflogger( -testcase => "<TESTCASE_ID>",
                                            -sut  => "<EMS_SUT>",
                                            -testbed  => "<TESTBED_TYPE>",
                                            -upload => "<n|N for no, any other input will be assumed yes>",
                                            -path => "<path where perflogger will be started >");

=cut

sub startPerfLogger {

    my ($self,%args) = @_;
    my $sub = ".startPerfLogger";
    my @cmd_res = ();
    my $pid = '';
    my $upload_append = (defined $args{-upload} and $args{-upload} =~ /n/i) ? '-noup':'';
    my $basepath = $self->{BASEPATH};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    foreach('-testcase' , '-sut' , '-testbed' , '-upload' , '-path') {
    unless( defined ($args{$_})) {
            $logger->error(__PACKAGE__ . ".$sub Mandatory input $_ is not defined ");
            $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
            return 0;
        }
    }

    @cmd_res = $self->execCmd("cd $basepath");
    if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $basepath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }

    @cmd_res = $self->execCmd("ls perfLogger.pl");
    if(grep(/no.*such.*file/i,  @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub perfLogger.pl script file not present in $basepath");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }
    my $perfLogPath = $args{-path};

    @cmd_res = $self->execCmd("cd $perfLogPath");
    if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $perfLogPath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }

#checking if any old instance of perflogger is running for the same test case alias
    my $cmd = 'ps -ef | grep ' . "\"$args{-testcase} -g " ."$args{-sut} \"" .  '| grep -v "grep " | awk \'{print $2}\'';
    my @old_perflogger = $self->execCmd($cmd);
    unless ($old_perflogger[0]){
       $logger->debug(__PACKAGE__ . ".$sub: No Old instance of perflogger loader running for $args{-testcase} ");
    } else {
    for my $perflogger (@old_perflogger) {
       $logger->error(__PACKAGE__ . ".$sub: Old perflogger for $args{-testcase} is  running on pid : $perflogger");
       $logger->error(__PACKAGE__ . ".$sub: Killing the old perflogger on pid : $perflogger");
        $self->execCmd("kill -9 $perflogger");
        }
    sleep 10;
    }


    @cmd_res = $self->execCmd("pwd");
    $logger->debug(__PACKAGE__ . ".$sub PWD @cmd_res");
	
    @cmd_res = $self->execCmd("nohup $basepath/perfLogger.pl -tc $args{-testcase} -g $args{-sut} -tb $args{-testbed} $upload_append >> nohup.out 2>&1& ");

    #PerfLogger takes some 10 secs to initialise.
    sleep 60;
    $logger->debug(__PACKAGE__ . ".$sub: Waiting for perflogger to inistialise ");


    @cmd_res = split /]/ , $cmd_res[0];
    $pid = $cmd_res[1];
    $logger->info(__PACKAGE__ . ".$sub Perflogger started with PID = $cmd_res[1]");
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [$cmd_res[1]]");
    return $pid;
}

sub startStopHaltCallFromNavtel {
    my ($obj,%args) = @_;
    my $sub = ".startStopHaltCallFromNavtel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1; 
    my @verifyInputData  = qw/ profilePath profile groupName holdtime testDuration/;

    # Check Mandatory Parameters
    foreach ( qw/ testSpecificData / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }
    my %testSpecificData;
    %testSpecificData  = %{ $args{'-testSpecificData'} };
    # validate Input data
    foreach ( @verifyInputData ) {
        unless ( defined ( $testSpecificData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  testSpecificData\{$_\}\t- $testSpecificData{$_}");
    }

    #check if start of call genration required by default it's set to yes(1)
    $logger->debug("INFO - Start Call Generation option $args{-startCallGeneration}");
    unless ( defined ($args{"-startCallGeneration"}) ) {
        $args{-startCallGeneration} = 1;
        $logger->debug("SUCCESS - profile is running in call generation mode" );
    }else {
        $logger->debug("SUCCESS - profile is running in respondig mode" );
    }

    # Load test case related Profile
    unless( $obj->loadProfile('-path'    =>$testSpecificData{profilePath},
                              '-file'    =>$testSpecificData{profile},
                              '-timeout' =>180,
          )) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profilePath}\'");
    }
    unless ($obj->runGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute runGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        #$retVal = 0;
        unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ){
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            return 0;
        }
    return 0;
    }else {
        $logger->debug("  SUCCESS - executed runGroup command for group \'$testSpecificData{groupName}\'");
    }

    #start Call generation from navtel
    if ( $args{-startCallGeneration} ) {
        unless ( $obj->startCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ) {
            my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            #return 0;
            #$retVal = 0;
            unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ){
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                $logger->error($errMsg);
                return 0;
            }
        return 0;
        }else {
            $logger->debug(" SUCCESS - executed startCallGeneration command for group \'$testSpecificData{groupName}\'");
        }
    #wait for test enitre duration only if runGroup and startCallGenration fails
       $logger->debug("  WAITING - for test to finish for duration \'$testSpecificData{testDuration}\'");
       sleep ( $testSpecificData{testDuration} );

    #stop call generation from Navtel
        unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ) {
            my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            #return 0;
            #$retVal = 0;
            unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ){
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                $logger->error($errMsg);
                return 0;
            }
        return 0;
        }else {
            $logger->debug(" SUCCESS - executed stopCallGeneration command for group \'$testSpecificData{groupName}\'");
        }

    #wait for call to gracefully complete
        $logger->debug("  WAITING - for call to finish for gracefully \'$testSpecificData{holdtime}\'");
        sleep ( $testSpecificData{holdtime} );
        $logger->debug(" <-- Leaving Sub [1]");
        return 1;
    }else {
       $logger->debug("SUCCESS - profile is running in responding mode only." );
       return 1;
    }

}#End of startStopHaltCallFromNavtel

sub collectOneCallLog{

    my ($obj,%args) = @_;
    my $sub = ".collectOneCallLog";
    my ($NavtelCmd,@callGenGroup);
    my $retVal = 1; 

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my @verifyInputData   = qw/ profilePath profile groupName holdtime testDuration/;
    my @verifyTrafficData = qw/ initrate finalrate stepincrement stepduration callOrgGroup /;

    # Check Mandatory Parameters
    foreach ( qw/ testSpecificData trafficPattern / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }
    my (%testSpecificData,%trafficPattern);
    %testSpecificData  = %{ $args{'-testSpecificData'} };
    %trafficPattern  = %{ $args{'-trafficPattern'} };

    # validate Input data
    foreach ( @verifyInputData ) {
        unless ( defined ( $testSpecificData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  testSpecificData\{$_\}\t- $testSpecificData{$_}");
    }

    # validate trafficPattern
    foreach ( @verifyTrafficData ) {
        unless ( defined ( $trafficPattern{$_} ) ) {
            $logger->error("  ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  trafficPattern\{$_\}\t- $trafficPattern{$_}");
    }
#set Single Attempt Traffic Profile

    @callGenGroup = @{$trafficPattern{callOrgGroup}};
    foreach(@callGenGroup){
        $NavtelCmd = "setSingleAttemptTrafficProfile $_ {Make Call}";
        unless ($obj->execCliCmd('-cmd' =>$NavtelCmd, '-timeout' =>180) ) {
           my $errMsg = "  FAILED - to execute $NavtelCmd command for group \'$_\'.";
           $logger->error($errMsg);
           $retVal = 0;
          # return 0;
        }else {
           $logger->debug("  SUCCESS - executed $NavtelCmd  command for group \'$_\'");
        }
    }
    sleep 1;

#set Call Hold time for single attempt Traffic Profile
    foreach(@callGenGroup){
        $NavtelCmd  = "setHT $_ $testSpecificData{holdtime} {Make Call}";
        unless ($obj->execCliCmd('-cmd' =>$NavtelCmd , '-timeout' =>180) ) {
            my $errMsg = "  FAILED - to execute $NavtelCmd  command for group \'$_\'.";
            $logger->error($errMsg);
           # return 0;
           #$retVal = 0;
        }else {
            $logger->debug("  SUCCESS - executed $NavtelCmd  command for group \'$_\'");
        }
    }
#start Call generation from navtel
    unless ( $obj->startCallGeneration('-groupName' =>$callGenGroup[0],'-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed startCallGeneration command for group \'$callGenGroup[0]\'");
    }
#wait for call completion
    $logger->debug("  INFO - wating for call to get completed for $testSpecificData{holdtime}*3 sec");
    sleep $testSpecificData{holdtime}*2;

#stop call generation from Navtel
    unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed stopCallGeneration command for group \'$callGenGroup[0]\'");
    }


#halt the navtel
    unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        return 0;
    } else {
       $logger->debug("  SUCCESS - executed haltGroup command for group \'$testSpecificData{groupName}\'");
    }
    sleep 1;
   return $retVal;

}#End of collectOneCallLog

sub exportNavtelStat {
    my ($obj,$testcase) = @_;
    my $sub = ".exportNavtelStat";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $groupName ='*';
    my $retVal=1;
    my $NavtelCmd; 
    my @statType = ('Summary', 'Signalling', 'Ethernet', 'Media');
    my $statsDir = '/var/iw95000/work/home/guiuser/automationStats';

##Before exporting make sure all the groups in halt state
    unless ( $obj->haltGroup('-groupName' => $groupName ,'-timeout' =>120) ){
         my $errMsg = "  FAILED - to execute haltGroup command for group $groupName .";
         $logger->error($errMsg);
    }

##Check if stats dir exist if not create it
   my $dirPath= $statsDir."/$testcase";

   $NavtelCmd = "mkdir -p $dirPath";

   $obj->execCliCmd('-cmd' => $NavtelCmd ,'-timeout' =>120);

   foreach(@statType){
        unless($obj->execCliCmd('-cmd' =>"exportStats $_ $statsDir/$testcase /header short /oneFilePerGroup /noMergeInOut",'-timeout' =>180) ) {
           my $errMessage = "  FAILED - Could not execute CLI command:--\n@{ $obj->{CMDRESULTS}}";
           $retVal = 0;
       } else {
        $logger->debug("  SUCCESS - Executed CLI command. ");
       }
       sleep 60;
    }

    return $retVal;
} #End of stat's export

sub testCaseValidation {
    my ($dirpath,$testcase,$gsxobj,@err_strings) = @_;
    my $sub = ".testCaseValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $gsxname = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
       $gsxobj->{CORE_DIR} = "/export/home/SonusNFS/$gsxname/coredump";

my $retVal=1;
foreach my $s (@err_strings)
{
    my $err_sys = SonusQA::Utils::logCheck(-file => "$dirpath/SYS/*.SYS",-string => "$s");
    my $err_dbg = SonusQA::Utils::logCheck(-file => "$dirpath/DBG/*.DBG",-string => "$s");
if ( ($err_sys || $err_dbg) >1 )
{
      $retVal=0;
      $logger->info(__PACKAGE__ . ".$sub:  $s is present in SYS/DBG log");
}
     else {
     $logger->info(__PACKAGE__ . ".$sub:  $s is not present  in SYS/DBG log");
}
}
#core check
unless(my $res=$gsxobj->checkCore(-testCaseID => "$testcase")) {
      $logger->debug(__PACKAGE__ . ".$sub : SUCCESS - no cores found ");
      }
      else {
      $logger->debug(__PACKAGE__ . ".$sub : SUCCESS - core found ");
      $retVal = 0;
      }
return $retVal;
}

sub postExecutionData{
    my ($gsxobj,$reportPath) = @_;
    my $sub = ".postExecutionData";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my $result = 1;
    my ($retVal,$reportName,@r,$gsxName,$link);
	

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    $gsxName      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

#######################Generate Report#########################################

    my $fileHeader = "=======>POST TEST EXECUTION REPORT FOR GSX $gsxName<=======\n\n";

    $reportName = "$reportPath/README.txt";

    genReport ("$fileHeader",$reportName);

###Get Seagirt Link
    $link = getSeaGirtLink($reportPath);

    if ($link){
        genReport ("SeaGirtLink: $link \n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$link");
    } else {
        genReport ("Failed to get Seagirt Link \n\n", $reportName);
        $logger->debug(__PACKAGE__ . "$sub ==> return value:$link");
        $result = 0;
    }

###Get acc summary
    unless ( @r = $gsxobj->execCmd("SHOW ACCOUNTING SUMMARY") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete\n");
        $result = 0;
    } else {
        foreach (@r) {
            genReport ("$_\n", $reportName);
        }
    }

###Get Log summary
    unless ( @r = $gsxobj->execCmd("SHOW LOG STATUS SUMMARY") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete");
        $result = 0;
    } else {
        foreach (@r) {
            genReport ("$_\n", $reportName);
        }
    }

###Get softswitch summary
    unless ( @r = $gsxobj->execCmd("SHOW SONUS SOFTSWITCH ALL STATUS") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete");
        $result = 0;
    } else {
        foreach (@r) {
            genReport ("$_\n", $reportName);
        }
    }

###Get call counts summary
    unless ( @r = $gsxobj->execCmd("SHOW CALL COUNTS ALL") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete");
        $result = 0;
    } else {
        foreach (@r) {
            genReport ("$_\n", $reportName);
        }
    }

return $result;
}

sub setNavtelTrafficPattern {
    my ($obj,%args) = @_;
    my $sub = ".setNavtelTrafficPattern";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1;
    my ($flowGroup,$key,$navtelCmd,$groupName,$initrate,$finalrate,$stepincrement,$stepduration,$holdtime,$burstduration,$burstgap,$minrate,$maxrate,$lambda,$cyclingpattern,$testDuration,$td);
    my @verifyInputData  = qw/ pattern groupName flowGroup /;

    my %trafficPattern;
    %trafficPattern  = %{ $args{'-trafficPattern'} };
    $td = 1;

    # validate Input data
    foreach $key (keys %trafficPattern){
        foreach ( @verifyInputData ) {
            unless ( defined ( $trafficPattern{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
    }
####validate the input data accourding to the pattern
    foreach $key (keys %trafficPattern){
        switch ($trafficPattern{$key}{pattern}){
            case "setUniformTrafficProfile" {
                unless (defined $trafficPattern{$key}{initrate}){
                    $logger->error("ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                    $logger->debug(" <-- Leaving Sub [0]");
                    return 0;
                }else {
                    $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
                }
            }
            case "setUniformStepTrafficProfile" {
                my @verifyData  = qw/ initrate finalrate stepduration stepincrement /;
                foreach ( @verifyData ) {
                    unless ( defined ( $trafficPattern{$key}{$_} ) ) {
                        $logger->error("ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                        $logger->debug(" <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
            }
            case "setBurstTrafficProfile" {
                my @verifyData  = qw/ initrate burstduration burstgap /;
                foreach ( @verifyData ) {
                    unless ( defined ( $trafficPattern{$key}{$_} ) ) {
                        $logger->error("  ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                        $logger->debug(" <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
            }
            case "setBurstStepTrafficProfile" {
                my @verifyData  = qw/ initrate finalrate stepincrement burstduration burstgap /;
                foreach ( @verifyData ) {
                    unless ( defined ( $trafficPattern{$key}{$_} ) ) {
                        $logger->error("  ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                        $logger->debug(" <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
            }
            case "setRandomTrafficProfile" {
                my @verifyData  = qw/ minrate maxrate stepduration /;
                foreach ( @verifyData ) {
                    unless ( defined ( $trafficPattern{$key}{$_} ) ) {
                        $logger->error("  ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                        $logger->debug(" <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
            }
            case "none" {$logger->debug("using saved profile ");}
                else{$logger->debug("no pattern specified ");}
        }
    }#end of validation of required parameters for specific pattern

####set the traffic pattern for each endpoints
    foreach $key (keys %trafficPattern){
        $flowGroup = $trafficPattern{$key}{flowGroup};
        $logger->debug("traffic pattern is: $trafficPattern{$key}{pattern} and Flow Group $trafficPattern{$key}{flowGroup}");

        if ( ($trafficPattern{$key}{'pattern'} eq "setSingleAttemptTrafficProfile")) {
            $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{'pattern'}");
            $groupName = $trafficPattern{$key}{groupName};
            $navtelCmd = "setSingleAttemptTrafficProfile $groupName {$flowGroup}";
            unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
                my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
                $logger->error($errMsg);
                $retVal = 0;
                return 0;
            }else {
                $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
                $td = 0;
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setUniformTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{'pattern'}");

           $groupName = $trafficPattern{$key}{groupName};
           $initrate = $trafficPattern{$key}{initrate};
           $navtelCmd = "setUniformTrafficProfile $groupName $initrate {$flowGroup}";

           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
              my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
              $logger->error($errMsg);
              $retVal = 0;
              return 0;
           }else {
              $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setUniformStepTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{pattern}");
           $groupName     = $trafficPattern{$key}{groupName};
           $initrate      = $trafficPattern{$key}{initrate};
           $finalrate     = $trafficPattern{$key}{finalrate};
           $stepincrement = $trafficPattern{$key}{stepincrement};
           $stepduration  = $trafficPattern{$key}{stepduration};

           if ( defined $trafficPattern{$key}{cyclesTD}){
               $logger->debug("  SUCCESS - cycleTD needs to set for stepup");
               $td=2;
           }

           $navtelCmd = "setUniformStepTrafficProfile $groupName $initrate $finalrate $stepincrement $stepduration {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
              my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
              $logger->error($errMsg);
              $retVal = 0;
              return 0;
           }else {
              $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
              $groupName      = $trafficPattern{$key}{groupName};
              $cyclingpattern = $trafficPattern{$key}{cyclingpattern};
              $navtelCmd = "setStepCyclingPattern $groupName $cyclingpattern {$flowGroup}";
              unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
                 my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
                 $logger->error($errMsg);
                 $retVal = 0;
                 return 0;
              }
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setBurstTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{pattern}");
           $groupName     = $trafficPattern{$key}{groupName};
           $initrate      = $trafficPattern{$key}{initrate};
           $burstduration = $trafficPattern{$key}{burstduration};
           $burstgap      = $trafficPattern{$key}{burstgap};

           $navtelCmd = "setBurstTrafficProfile $groupName $initrate $burstduration $burstgap {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
              my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
              $logger->error($errMsg);
              $retVal = 0;
              return 0;
           }else {
               $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setBurstStepTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{pattern}");
           $groupName = $trafficPattern{$key}{groupName};
           $initrate      = $trafficPattern{$key}{initrate};
           $finalrate     = $trafficPattern{$key}{finalrate};
           $stepincrement = $trafficPattern{$key}{stepincrement};
           $burstduration = $trafficPattern{$key}{burstduration};
           $burstgap      = $trafficPattern{$key}{burstgap};

           if ( defined $trafficPattern{$key}{cyclesTD}){
               $logger->debug("  SUCCESS - cycleTD needs to set for stepup");
               $td=2;
           }

           $navtelCmd = "setBurstStepTrafficProfile $groupName $initrate $finalrate $stepincrement $burstduration $burstgap {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
               my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
               $logger->error($errMsg);
               $retVal = 0;
               return 0;
           }else {
               $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
               $groupName      = $trafficPattern{$key}{groupName};
               $cyclingpattern = $trafficPattern{$key}{cyclingpattern};
               $navtelCmd = "setStepCyclingPattern $groupName $cyclingpattern {$flowGroup}";
               unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
                   my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
                   $logger->error($errMsg);
                   $retVal = 0;
                   return 0;
               }
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setRandomTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{pattern}");
           $groupName     = $trafficPattern{$key}{groupName};
           $minrate       = $trafficPattern{$key}{minrate};
           $maxrate       = $trafficPattern{$key}{maxrate};
           $stepduration  = $trafficPattern{$key}{stepduration};

           $navtelCmd = "setRandomTrafficProfile $groupName $minrate $maxrate $stepduration {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
               my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
               $logger->error($errMsg);
               $retVal = 0;
               return 0;
           }else {
                $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
       }
       elsif ( ($trafficPattern{$key}{pattern} eq "setPoissonTrafficProfile")) {
           $logger->debug("INFO - traffic pattern is: $trafficPattern{$key}{pattern}");
           $groupName     = $trafficPattern{$key}{groupName};
           $minrate       = $trafficPattern{$key}{minrate};
           $maxrate       = $trafficPattern{$key}{maxrate};
           $stepduration  = $trafficPattern{$key}{stepduration};
           $lambda        = $trafficPattern{$key}{lambda};

           $navtelCmd = "setPoissonTrafficProfile $groupName $minrate $maxrate $lambda $stepduration {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
              my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
              $logger->error($errMsg);
              $retVal = 0;
              return 0;
           }else {
               $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
       }
       else {
           $logger->debug("INFO - failed to get matching traffic pattern");
           return 0;
       }
###set call Hold time
        if($trafficPattern{$key}{'holdtime'} eq "setRandomCHT"){
            my @verifyData  = qw/ minCHT maxCHT /;
            foreach ( @verifyData ) {
                unless ( defined ( $trafficPattern{$key}{$_} ) ) {
                    $logger->error("  ERROR: The mandatory traffic pattern argument for \'$_\' has not been specified.");
                    $logger->debug(" <-- Leaving Sub [0]");
                    return 0;
                }
            }
            $logger->debug("  SUCCESS: All the mandatory parameter has been provided for $trafficPattern{$key}{pattern}) ");
            $groupName = $trafficPattern{$key}{groupName};
            my $minCHT  = $trafficPattern{$key}{minCHT};
            my $maxCHT=$trafficPattern{$key}{maxCHT};
            my $NavtelCmd  = "setRandomCHT $groupName $minCHT $maxCHT {$flowGroup}";
            unless ($obj->execCliCmd('-cmd' =>$NavtelCmd , '-timeout' =>120) ) {
                my $errMsg = "  FAILED - to execute $NavtelCmd  command for group \'$key\'.";
                $logger->error($errMsg);
                return 0;
            }else {
                $logger->debug("  SUCCESS - executed $NavtelCmd  command for group \'$key\'");
            }

        }
        else{
            $logger->debug("INFO - set the call hold time: $trafficPattern{$key}{holdtime}");
            $groupName = $trafficPattern{$key}{groupName};
            $holdtime  = $trafficPattern{$key}{holdtime};
            $navtelCmd = "setHT $groupName $trafficPattern{$key}{holdtime} {$flowGroup}";
            unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
                my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
                $logger->error($errMsg);
                $retVal = 0;
                return 0;
            }else {
                $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
            }
        }
    }#end of foreach key

###SET TEST DURATION
    foreach $key (keys %trafficPattern){
        $flowGroup     = $trafficPattern{$key}{flowGroup};
        switch ($td){
        case'1'{
            $logger->debug("INFO - set the test duration : $trafficPattern{$key}{testDuration}");
            $groupName     = $trafficPattern{$key}{groupName};
            $testDuration  = $trafficPattern{$key}{testDuration};

           $navtelCmd = "setTimeTD $groupName $trafficPattern{$key}{testDuration} {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
               my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
               $logger->error($errMsg);
               $retVal = 0;
               return 0;
           }else {
               $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
        }
        case'2'{
            $logger->debug("INFO - set the test cycles time duration: $trafficPattern{$key}{testDuration}");
            $groupName     = $trafficPattern{$key}{groupName};
            my  $cyclesTD  = $trafficPattern{$key}{cyclesTD};

           $navtelCmd = "setCyclesTD $groupName $trafficPattern{$key}{cyclesTD} {$flowGroup}";
           unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
               my $errMsg = "  FAILED - to execute $navtelCmd command for group \'$groupName\'.";
               $logger->error($errMsg);
               $retVal = 0;
               return 0;
           }else {
               $logger->debug("  SUCCESS - executed $navtelCmd  command for group \'$groupName\'");
           }
        }

        else {
           $logger->debug("  SUCCESS - executed ");
        }
       }
  }
return 1;

}#End of setNavtelTrafficPattern

sub startCallFromNavtel {
    my ($obj,%args) = @_;
    my $sub = ".startCallFromNavtel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1;
    my @verifyInputData  = qw/ profilePath profile groupName holdtime testDuration/;
    my $key;

    # Check Mandatory Parameters
    foreach ( qw/ testSpecificData / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }
    my %testSpecificData;
    %testSpecificData  = %{ $args{'-testSpecificData'} };
    # validate Input data
    foreach ( @verifyInputData ) {
        unless ( defined ( $testSpecificData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  testSpecificData\{$_\}\t- $testSpecificData{$_}");
    }

    #check if start of call genration required by default it's set to yes(1)
    $logger->debug("INFO - Start Call Generation option $args{-startCallGeneration}");
    unless ( defined ($args{"-startCallGeneration"}) ) {
        $args{-startCallGeneration} = 1;
        $logger->debug("SUCCESS - profile is running in call generation mode" );
    }else {
        $logger->debug("SUCCESS - profile is running in respondig mode" );
    }
    # Load test case related Profile
    unless( $obj->loadProfile('-path'    =>$testSpecificData{profilePath},
                              '-file'    =>$testSpecificData{profile},
                              '-timeout' =>120,
          )) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profilePath}\'");
    }
##Check if traffic pattern needs to be set
    if ( $args{-trafficPattern} ) {
       my $trafficPattern = $args{-trafficPattern};
      $logger->debug("  SUCCESS - traffic pattern needs to be  set");

       unless (setNavtelTrafficPattern($obj,'-trafficPattern' =>$trafficPattern) ) {
           my $errMsg = "  FAILED - to set Navtel traffic parameter";
           $logger->error($errMsg);
           return 0;
       }else {
           $logger->debug("  SUCCESS - successfully set the Navtel traffic parameter");
       }
    }
## Check if Proxy Server needs to be set
    if ( $args{-proxyServerData} ) {
       my $proxyServerData = $args{-proxyServerData};
      $logger->debug("  SUCCESS - proxy server detail needs to be set ");

       unless (setNavtelOutBoundProxy($obj,'-proxyServerData' =>$proxyServerData) ) {
           my $errMsg = "  FAILED - to set Navtel out bound proxy server detail ";
           $logger->error($errMsg);
           return 0;
       }else {
           $logger->debug("  SUCCESS - successfully set the Navtel outbound proxy server detail");
       }
    }

##run the call from navtel
 unless ($obj->runGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute runGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        #$retVal = 0;
        unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            return 0;
        }
    return 0;
    }else {
        $logger->debug("  SUCCESS - executed runGroup command for group \'$testSpecificData{groupName}\'");
    }

##call generation for single attempt
    if ( $args{-trafficPattern} ) {
         my %trafficPattern  = %{ $args{'-trafficPattern'} };
         foreach $key (keys %trafficPattern){
             if ($trafficPattern{$key}{pattern} eq "setSingleAttemptTrafficProfile"){
                 unless ( $obj->startCallGeneration('-groupName' =>$trafficPattern{$key}{groupName},'-timeout' =>120) ) {
                     my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
                     $logger->error($errMsg);
                     unless($obj->haltCallGeneration('-groupName' =>$trafficPattern{$key}{groupName},'-timeout' =>120)){
                         my $errMsg = "  FAILED - to execute haltCallGeneration command for group \'$testSpecificData{groupName}\'.";
                         $logger->error($errMsg);
                         return 0;
                     }
                 return 0;
                 }else{
                     $logger->debug("  SUCCESS - started the one call generation");
                 }
                 $logger->debug(" INFO -Waiting for 2*$trafficPattern{$key}{holdtime}");
                 sleep (2*$trafficPattern{$key}{holdtime});
                 unless ($obj->stopCallGeneration('-groupName' =>$trafficPattern{$key}{groupName},'-timeout' =>120)){
                     my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
                     $logger->error($errMsg);
                     unless($obj->haltCallGeneration('-groupName' =>$trafficPattern{$key}{groupName},'-timeout' =>120)){
                         my $errMsg = "  FAILED - to execute haltCallGeneration command for group \'$testSpecificData{groupName}\'.";
                         $logger->error($errMsg);
                         return 0;
                     }
                 return 0;
                 }else{
                     $logger->debug("  SUCCESS - stopped the one call generation");
                 }
                 $args{-startCallGeneration} = 0;
             }
        }
    }

##start Call generation from navtel
    if ( $args{-startCallGeneration} ) {
        unless ( $obj->startCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
            my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            #return 0;
            #$retVal = 0;
            unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                $logger->error($errMsg);
                return 0;
            }
        return 0;
        }else {
            $logger->debug(" SUCCESS - executed startCallGeneration command for group \'$testSpecificData{groupName}\'");
            return 1;
        }
##wait for test enitre duration only if runGroup and startCallGenration fails
       $logger->debug("  WAITING - for test to finish for duration \'$testSpecificData{testDuration}\'");
       sleep ( $testSpecificData{testDuration} );

##stop call generation from Navtel
        unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
            my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            #return 0;
            #$retVal = 0;
            unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                $logger->error($errMsg);
                return 0;
            }
        return 0;
        }else {
            $logger->debug(" SUCCESS - executed stopCallGeneration command for group \'$testSpecificData{groupName}\'");
        }

##wait for call to gracefully complete
        $logger->debug("  WAITING - for call to finish for gracefully \'$testSpecificData{holdtime}\'");
        sleep ( $testSpecificData{holdtime} );
        $logger->debug(" <-- Leaving Sub [1]");
        return 1;
    }else {
       $logger->debug("SUCCESS - profile is running in responding mode only." );
       return 1;
    }

}#End of startCallFromNavtel

sub stopHaltCallFromNavtel {
    my ($obj,%args) = @_;
    my $sub = ".stopHaltCallFromNavtel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1;
    my @verifyInputData  = qw/ profilePath profile groupName holdtime /;

 foreach ( qw/ testSpecificData / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }
    my %testSpecificData;
    %testSpecificData  = %{ $args{'-testSpecificData'} };
    # validate Input data
    foreach ( @verifyInputData ) {
        unless ( defined ( $testSpecificData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  testSpecificData\{$_\}\t- $testSpecificData{$_}");
    }

    if ( defined ($args{"-stopCallGeneration"}) ) {
       if ($args{-stopCallGeneration} == 1 ){
           $logger->debug("INFO - Stop Call Generation only");
           unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
               my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
               $logger->error($errMsg);
               #return 0;
               #$retVal = 0;
               unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
                   my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                   $logger->error($errMsg);
                   return 0;
               }
               return 0;
           }else {
              $logger->debug(" SUCCESS - executed stopCallGeneration command for group \'$testSpecificData{groupName}\'");
           }
           $logger->debug("  WAITING - for call to finish for gracefully \'$testSpecificData{holdtime}\'");
           sleep ( $testSpecificData{holdtime} );
           return 1;
       } else {
           $logger->debug("INFO - Halt group only");
           unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
               my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
               $logger->error($errMsg);
               return 0;
           }else {
            $logger->debug(" SUCCESS - executed haltGroup command for group \'$testSpecificData{groupName}\'");
            return 1;
        }
       }
    } else {
       $logger->debug("INFO - Stop Call Generation Followed by Halt");
       unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        #$retVal = 0;
        unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            return 0;
        }
        return 0;
        }else {
             $logger->debug(" SUCCESS - executed stopCallGeneration command for group \'$testSpecificData{groupName}\'");
        }
        $logger->debug("  WAITING - for call to finish for gracefully \'$testSpecificData{holdtime}\'");
        sleep ( $testSpecificData{holdtime} );
##Halt the group
        unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
            $logger->error($errMsg);
            return 0;
        }else {
            $logger->debug(" SUCCESS - executed haltGroup command for group \'$testSpecificData{groupName}\'");
            return 1;
        }
   }

return 1;

}#End of stopHaltCallFromNavtel

sub setNavtelOutBoundProxy {

    my ($obj,%args) = @_;
    my $sub = ".setNavtelOutBoundProxy";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($proxyName,$key,$navtelCmd,$proxyIp,$port,$groupName);
    my @blockName;
    my @verifyInputData  = qw/ serverName serverIp ipVersion port groupName/;
    my %proxyServerData;

    %proxyServerData  = %{ $args{'-proxyServerData'} };

    # validate Input data
    foreach $key (keys %proxyServerData){
        foreach ( @verifyInputData ) {
            unless ( defined ( $proxyServerData{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
    }
$obj->execCliCmd('-cmd' =>"hideGUI", '-timeout' =>120);
foreach $key (keys %proxyServerData){

        $port = $proxyServerData{$key}{port};
        $proxyName = $proxyServerData{$key}{serverName};
        $proxyIp = $proxyServerData{$key}{serverIp};
       $groupName = $proxyServerData{$key}{groupName};
  
                              
     my $navtelCmd = "getAllEPBlocks $groupName";
    $logger->debug("  SUCCESS - the Navtel Cmd  $navtelCmd ");
    @blockName=$obj->execCmd('-cmd' =>$navtelCmd, '-timeout' =>120);
    $logger->debug("  SUCCESS - executed $navtelCmd  command and block name = @blockName");
    
        if ($proxyServerData{$key}{ipVersion} eq "IPV4" ){
            $navtelCmd = "configProxyServer -serverName $proxyName -ipv4AddrEnable 1 -ipv4Address $proxyIp -port $port";
        }else {
            $navtelCmd = "configProxyServer -serverName $proxyName -ipv6AddrEnable 1 -ipv6Address $proxyIp -port $port";
        }
        unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
            my $errMsg = "  FAILED - to execute $navtelCmd command for server \'$proxyName\'.";
            $logger->error($errMsg);
            return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command for server \'$proxyName\'");
        }

        $navtelCmd="configEPBlockServer -group $groupName -blockName @blockName -serverSelection $proxyName";
         unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute $navtelCmd command for server \'$proxyName\'.";
        $logger->error($errMsg);
        return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command for server \'$proxyName\'");
        }
    }
return 1;

}#End of setNavtelOutBoundProxy

1;
