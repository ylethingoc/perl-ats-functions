=head1 NAME

SonusQA::SBX5000::PERFHELPER - Perl module to support Performance Testing
=head1 AUTHOR

sonus-ats-dev@sonusnet.com

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Utils, Data::Dumper, POSIX

=head1 SYNOPSIS

 use ATS;
   or
 use SonusQA::SBX5000::PERFHELPER;

=head1 DESCRIPTION

Provides an interface to automate the IXIA/NAVTEL for Performance testing.

=head1 METHODS

=cut

package SonusQA::SBX5000::PERFHELPER;
use SonusQA::Utils qw(:all logSubInfo);
use SonusQA::Base;
use SonusQA::IXIA;
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
use List::Util qw( min max );
use File::Path qw(mkpath);
#use Net::SFTP::Foreign;


our $VERSION = "6.1";
our $resetPort = 0;
our $portType;

use vars qw($self);

=head2 C< getNifIp >

=over

=item DESCRIPTION:

	executes 'SHOW NIF ALL ADMIN' cmd and fetch the NIF ip and check its reachability

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->getNifIp();


=back

=cut

sub getNifIp {
    my ($obj) = @_;
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
        my $value = $obj->pingHost("$_");
        if (!$value){
            $logger->debug(__PACKAGE__ . "IP $_ is down");
            $retVal = 0;
        }
    }
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

=head2 C< getTrunkGroupStatus >

=over

=item DESCRIPTION:

	Executes 'SHOW TRUNK GROUP ALL STATUS' and find the trunk group, configured circuit and available circuit.

output of 'SHOW TRUNK GROUP ALL STATUS' :
------------------------------------------

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

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->getTrunkGroupStatus();


=back

=cut

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

=head2 C< getPsxStatus >

=over

=item DESCRIPTION:

	Executes 'SHOW SONUS SOFTSWITCH ALL STATUS' and check the PSX status.

output of 'SHOW SONUS SOFTSWITCH ALL STATUS':
-------------------------------------------

#%SHOW SONUS SOFTSWITCH ALL STATUS
#Node: PHOBOS                                   Date: 2013/06/18 17:03:13  GMT
#                                               Zone: GMTMINUS05-EASTERN-US
#
#SoftSwitchName          State    Congest Completed            Retries    Failed
#--------------------------------------------------------------------------------
#puttur                  ACTIVE    CLEAR  0                    0          0

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->getPsxStatus();


=back

=cut

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

=head2 C< getMLPPSetting >

=over

=item DESCRIPTION:

	helps to get the MLPP and HPC license settings

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->getMLPPSetting();


=back

=cut

sub getMLPPSetting{
    my ($obj) = @_;
    my $sub = ".getMLPPSetting";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    my @lic = ("MLPP", "HPC" );
    my $retVal = 1;
    my $licStatus;
    my $ip_type           = ($obj->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
    my $psxIPAddress      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{$ip_type};
    my $psxOracleUserName      = $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $psxOraclePassword       = $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my $oracleSession = new SonusQA::Base( -obj_host   => "$psxIPAddress",
                                           -obj_user       => "$psxOracleUserName",
                                           -obj_password   => "$psxOraclePassword",
                                           -comm_type      => 'SSH',
                                           -obj_port       => 22,
                                           -return_on_fail => 1,
                                           -defaulttimeout => 120,
                                         );
    unless ($oracleSession) {
        $logger->error("Unable to open a session to PSX $psxIPAddress");
        return 0;
    }

    my $cmdString = "sqlplus '/ as sysdba'";
    $logger->debug("Executing a command :-> $cmdString");
    my @r = $oracleSession->execCmd("$cmdString");
    sleep (5);
    $logger->debug("Command Output : @r");

    foreach(@lic) {
        $cmdString = "select * from license_feature where feature_name like '%$_%';";
        $logger->debug("Executing a command :-> $cmdString");
        @r = $oracleSession->execCmd("$cmdString");
        $logger->debug("Command Output : @r");
        sleep (1);
            foreach (@r) {
                if (m/(\w+)\s+(\d+)\s+(\d+)/){
                    $licStatus = $3;
                    if($licStatus != 0){
                        $retVal = 0;
                    }
                }
            }
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $retVal;
}

=head2 C< checkEventLog >

=over

=item DESCRIPTION:

	Checks the event logging for all logs

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

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->checkEventLog();

=back

=cut

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

=head2 C< checkRedundancyStaus >

=over

=item DESCRIPTION:

	checks the Redundancy status 

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

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->checkRedundancyStaus();


=back

=cut

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

=head2 C< sourceTCL >

=over

=item DESCRIPTION:

	helps to source TCL 	

=item ARGUMENTS:

 Mandatory :

	$dsiobj = DSI object,
	$gsxobj = GSX object,
	$testbed = name of the test bed

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  sourceTCL($dsiobj,$gsxobj,$testbed);

=back

=cut

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

=head2 C< clearNfsLogs >

=over

=item DESCRIPTION:

	Clears NFS logs

=item ARGUMENTS:

 Mandatory :

	-$dsiobj = DSI object,
	-$gsxobj = GSX object

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  clearNfsLogs($dsiobj,$gsxobj);

=back

=cut

sub clearNfsLogs{

    my ($dsiobj,$gsxobj) = @_;
    my $sub = ".clearNfsLogs";
    my @logType = ('DBG', 'ACT', 'SYS');

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $gsxName      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
    my $sonicId      = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SONICID};

    my $log = "/export/home/SonusNFS/$gsxName/evlog/$sonicId";

    foreach(@logType){

        my $cmdString = "cd $log/$_";
        my @r = $dsiobj->SonusQA::SBX5000::execCmd("$cmdString");
        if(grep(/no.*such.*dir/i , @r)) {
           $logger->error(__PACKAGE__ . ".$sub directory not present");
           $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
           return 0;
        }
        sleep (1);
        my $cmd = "ls -tr *.$_ | tail -1";

        my @lastFile = $dsiobj->SonusQA::SBX5000::execCmd('ls -tr | tail -1');

        $cmdString = "ls -tr *.$_ | grep -v @lastFile";
        $logger->debug("Executing a command :-> $cmdString");

        @r = $dsiobj->SonusQA::GSX::execCmd("$cmdString");
        foreach(@r){
           $cmdString = "/usr/bin/rm -f $_";
           #$logger->debug("Executing a command :-> $cmdString");
           my @retVal = $dsiobj->execCmd("$cmdString");
           sleep (1);
        }
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return 1;
}
=head2 C< getListOfFilesFromNFS >

=over

=item DESCRIPTION:

	provides the list of particular file type from NFS

=item ARGUMENTS:

 Mandatory :

	$dsiobj = DSI object,
	$destDir = destination directory,
	$logType = type of the log

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  getListOfFilesFromNFS($dsiobj,$destDir,$logType);

=back

=cut

sub getListOfFilesFromNFS{

    my ($dsiobj,$destDir,$logType) = @_;
    my $sub = ".clearNfsLogs";
    my @r;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");



        my $cmdString = "cd $destDir";
        @r = $dsiobj->SonusQA::SBX5000::execCmd("$cmdString");
        if(grep(/no.*such.*dir/i , @r)) {
           $logger->error(__PACKAGE__ . ".$sub directory not present");
           $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
           return 0;
        }
        sleep (1);
        my $cmd = "ls -tr *.$logType";
        my @fileList = $dsiobj->SonusQA::SBX5000::execCmd("$cmd");

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");

    return @fileList;
}

=head2 C< collectLogFromNFS >

=over

=item DESCRIPTION:

	collects 'SYS','DBG' and 'ACT' log from NFS

=item ARGUMENTS:

 Mandatory :

	src_dir - source directory

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->collectLogFromNFS($src_dir);

=back

=cut

sub collectLogFromNFS{

    my ($obj, $src_dir) = @_;
    my ($dest_ip, $dest_userid, $dest_passwd, $dest_dir);
    my ($sftp_session,@logType,@srcSubDir,$srcPath,$dstPath,$retVal,$gsxName,$sonicId,$paramFile,$sysinitOut);
    my $sub = ".collectLogFromNFS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    $retVal = 1;
    @logType = ('SYS','DBG','ACT');

    my $ip_type   = ($obj->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP'; 
    $sonicId      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SONICID};
    $dest_dir     = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{LOG_DIR};
    $dest_ip      = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{$ip_type};
    $dest_userid  = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{USERID};
    $dest_passwd  = $obj->{TMS_ALIAS_DATA}->{NFS}->{1}->{PASSWD};
    $gsxName      = $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

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

    #Open SFTP Session
    $sftp_session = new Net::SFTP(
                                    $dest_ip,
                                    user     => $dest_userid,
                                    password => $dest_passwd,
                              debug => 0
    );
    unless ( $sftp_session ) {
        $logger->error("Could not open sftp connection to destination server --> $dest_ip");
        return 0;
    }

    $logger->info("SFTP $sub:  Opened $dest_userid SFTP session to $dest_ip NFS server");
    sleep 1;

    #######Move log to server 

    #Check if OneCallLog needs to be collected or all
    if(grep(/OneCallLog/i, @srcSubDir)) {
        foreach (@logType) {
          $srcPath = "$dest_dir$_/*.$_" ;
          unless ( $sftp_session->get("$srcPath" , "$src_dir" ) ) {
              $logger->error(__PACKAGE__ . ".$sub:  Failed to transfer file from NFS to local Server");
              $retVal = 0;
          }
          $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $src_dir from NFS");

        }
    } else {
#Move param file
      $dstPath = $src_dir.'PARAM';
      unless ( $sftp_session->get("$paramFile" , "$dstPath" ) ) {
          $logger->error(__PACKAGE__ . ".$sub:  Failed to transfer file from NFS to local M/C");
          $retVal = 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub:  File $sonicId.prm transferred to $dstPath from the NFS");
#Move sysinti.tcl.out  file
      unless ( $sftp_session->get("$sysinitOut" , "$dstPath" ) ) {
          $logger->error(__PACKAGE__ . ".$sub:  Failed to transfer file from NFS to local M/C");
          $retVal = 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub:  File $sysinitOut transferred to $dstPath from NFS.");
#Move ACT/SYS/DBG files

      foreach (@logType) {
           $srcPath = "$dest_dir$_/*.$_" ;
           $dstPath = "$src_dir/$_";
           unless ( $sftp_session->get("$srcPath" , "$dstPath" ) ) {
               $logger->error(__PACKAGE__ . ".$sub:  Failed to transfer file from NFS to local Server");
               $retVal = 0;
           }
           $logger->debug(__PACKAGE__ . ".$sub:  File $_ transferred to $dstPath from NFS");
      }
    }

   return $retVal;
}

=head2 C< checkSysinitOutput >

=over

=item DESCRIPTION:

	checks the system initiatation output

=item ARGUMENTS:

 Mandatory :

	$gsxName = Name of the GSX,
	$serialNum = serial number

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->checkSysinitOutput($gsxName,$serialNum);

=back

=cut

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
    unless (@r = $obj->execCmd(String => $cmdString)) {
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

=head2 C< getSeaGirtLink >

=over

=item DESCRIPTION:

	helps to get the sea girt link.

=item ARGUMENTS:

 Mandatory :

	$dirPath = path of the directory

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

 link of the sea girt	

=item EXAMPLE:

  getSeaGirtLink($dirPath);

=back

=cut

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
    $logger->info("INFO - The perfLogger file name is: $fileName");

    $output = `grep \"$pattern\" $fileName`;

    $runId = substr($output, index($output,"$pattern") + 11);

    $logger->debug("Executing a command :-> $output");
    $logger->info("INFO: THE RUNID :-> $runId");
    $link = "http://seagirt.nj.sonusnet.com/PTDATA/plot.php?product=gsx&slot=1&runuuid=$runId";

    $logger->debug("THE LINK :-> $link");

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $link;
}

=head2 C< createDirStr >

=over

=item DESCRIPTION:

	helps to create a directory structure seperately for active and standby in the below formate for ACT,DBG,SYS,NAVTEL_DATA,PKTART_DATA/SERVER,PKTART_DATA/CLIENT,ESX_DATA,OneCallLog and SPAM.

##################################################################################################
###Directory structure:e.g. /sonus/PerfDataBkup/Release/V09.00.00R000/GSXNBS/GSX-103/testbed_A/20130607
##################################################################################################


=item ARGUMENTS:

 Mandatory :

	$path = path where the directory to be created,
	$Hostactive = active host name,
	$Hoststandby = standby host name

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  createDirStr();

=back

=cut

sub createDirStr{

    my ($path,$Hostactive,$Hoststandby) = @_;
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
             unless ( system ( "mkdir -m 777 $dir" ) == 0 ) {
                 $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                 return 0;
             }
       }  
    }

   #create remaining dir ACT,DBG,SYS,NAVTEL_DATA,perflogger,OneCallLog,PARAM,INET_DATA,PKTART DATA
  unless ( system ("mkdir -m 777 $dir\/$Hostactive $dir\/$Hoststandby") == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $Hostactive $Hoststandby $dir");
                return 0;
    }
   unless ( system ("mkdir -m 777 $dir/$Hostactive/ACT $dir/$Hostactive/DBG $dir/$Hostactive/SYS $dir/$Hostactive/NAVTEL_DATA  $dir/$Hostactive/SYS $dir/$Hostactive/PKTART_DATA/SERVER $dir/$Hostactive/SYS $dir/$Hostactive/PKTART_DATA/CLIENT $dir/$Hostactive/ESX_DATA $dir/$Hostactive/OneCallLog  $dir/$Hostactive/SPAM ") == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                return 0;
    }
   unless ( system ("mkdir -m 777 $dir/$Hoststandby/ACT $dir/$Hoststandby/DBG $dir/$Hoststandby/SYS $dir/$Hoststandby/NAVTEL_DATA $dir/$Hostactive/SYS $dir/$Hostactive/PKTART_DATA/SERVER $dir/$Hostactive/SYS $dir/$Hostactive/PKTART_DATA/CLIENT $dir/$Hoststandby/ESX_DATA $dir/$Hoststandby/OneCallLog  $dir/$Hoststandby/SPAM ") == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub *** Could not create directory  $dir");
                return 0;
    }
=for comment

   unless (  system ("cd $dir;touch README;echo SeaGrit Link: > README;echo Steps : >> README;echo Max Run CPS and Observation :  >> README;chmod -R 777 *") == 0 ){
                $logger->error(__PACKAGE__ . ".$sub *** Could not create README file");
                return 0;
    }

=cut

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $dir;
}

=head2 C< createDir >

=over

=item DESCRIPTION:

        helps to create a 'ACT,DBG,SYS,NAVTEL_DATA,PKTART_DATA/SERVER,PKTART_DATA/CLIENT,ESX_DATA,OneCallLog and SPAM' directory for given sbc nodes.

=item ARGUMENTS:

 Mandatory :

	$path = path where the directory to be created,
	@sbcNode = list of SBC's.
 Optional :

	$dos_flag = decides whether _Dos need to be there in the directory name

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  createDir();

=back

=cut

sub createDir{

    my ($dos_flag,$path,@sbcNode) = @_;
    my (@subDirs,$dir,$nodeName);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    
    my $timestamp = sprintf "%4d%02d%02d_%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    my $dateDir;

    if($dos_flag){
        $dateDir = "$timestamp\_DoS";
    }else{
        $dateDir = "$timestamp";
    }
        
    my $sub = ".createDir";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    @subDirs = split(/\//,$path);
    push @subDirs,$dateDir;

    $dir = "";
    $logger->debug("the directory structure :-> @subDirs");
    foreach(@subDirs){
       $dir .= $_."/";
       if(!-d $dir){
             unless ( system ( "mkdir -m 777 $dir" ) == 0 ) {
                 $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                 return 0;
             }
       }
    }
foreach(@sbcNode){
   # change the string to lower case
   $nodeName = lc($_);
   #create remaining dir ACT,DBG,SYS,NAVTEL_DATA,perflogger,OneCallLog,PARAM,IXIA_DATA
   unless ( system ("mkdir -p -m 777 $dir$nodeName/ACT $dir$nodeName/DBG $dir$nodeName/SYS $dir$nodeName/NAVTEL_DATA  $dir$nodeName/PKTART_DATA/SERVER $dir$nodeName/PKTART_DATA/CLIENT $dir$nodeName/ESX_DATA $dir$nodeName/OneCallLog $dir$nodeName/SPAM $dir$nodeName/IXIA_DATA ") == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
                return 0;
   }
    $logger->debug(__PACKAGE__ . "$sub created Dir structure for the node $_");
}

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");
    return $dir;
}#End of createDir


=head2 C< createDirCommon >

=over

=item DESCRIPTION:

        helps to create directories for given sbc nodes.

=item ARGUMENTS:

 Mandatory :

        'path' = path where the directory to be created.
        'sbcNodes' = list of SBC's CE names.
        'subDirs' = list of sub directory names for which directories have to be created.

 Optional :
 
        'sbcNodes' = list of SBC's CE names. Define this only for ISBC.
        'dos_flag' = decides whether _Dos need to be there in the directory name

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0      - fail
    $dir   - success

=item EXAMPLE:

  createDirCommon('path' => "/tmp/", 'sbcNodes' => ['vsbc1'], 'subDirs' => ['DutLogs','PktartStats/SERVER','PktartStats/CLIENT','Perflogger'], 'dos_flag' => "0");

=back

=cut

sub createDirCommon{

    my (%args) = @_;
    my $sub = ".createDirCommon";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d_%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    my $dateDir;

    #Checking mandatory arguments
    unless ( $args{'path'} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument path is missing.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( @{$args{'subDirs'}} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument subDirs is missing.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    if($args{'dos_flag'}){
        $dateDir = "$timestamp\_DoS";
    }else{
        $dateDir = "$timestamp";
    }

    my $dir = $args{'path'};
    my $nodeName;
    my $sbcNodesFlag = (exists $args{'sbcNodes'} && @{$args{'sbcNodes'}}) ? '1':'0';

    if( $sbcNodesFlag == 1 ){
	#Creating two directories for HA setup. Used for legacy suites.
	foreach(@{$args{'sbcNodes'}}){
	   # change the string to lower case
	   $nodeName = lc($_);
	   #create remaining dir with passed subDirs
	   foreach (@{$args{'subDirs'}}) {
		unless ( system ("mkdir -p -m 777 $dir/$dateDir/$nodeName/$_ ") == 0 ) {
		$logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
		return 0;
		}
		$logger->debug(__PACKAGE__ . "$sub created Dir structure for the node $_");
		}
	}
	} else {
		#create remaining dir with passed subDirs for standalone setup
		foreach (@{$args{'subDirs'}}) {
			unless ( system ("mkdir -p -m 777 $dir/$dateDir/$_ ") == 0 ) {
			$logger->error(__PACKAGE__ . ".$sub *** Could not create directory $dir");
			return 0;
			}
		$logger->debug(__PACKAGE__ . "$sub created Dir structure for the node $_");
		}
	}

    my $returnDir = "$dir$dateDir\/";
    $logger->debug(__PACKAGE__ . "$sub <== Leaving");

    return $returnDir;
}#End of createDirCommon

=head2 C< genReport >

=over

=item DESCRIPTION:

	generates Report using the given data in the given file.

=item ARGUMENTS:

 Mandatory :

	$msgString = Data to be pushed in the file,
	$fileName = Name of the file
 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &genReport($msgString,$fileName);

=back

=cut

sub genReport {

    my ($msgString,$fileName) = @_;
    open reportOpen, ">>$fileName" or die $!;
    print reportOpen $msgString;
    close reportOpen;
}

=head2 C< pretest_checkList >

=over

=item DESCRIPTION:

	Its a wrapper function , used to make sure everything is up and works fine.

=item ARGUMENTS:

 Mandatory :

	$gsxobj = GSX object,
	$psxobj = PSX object,
	$dsiobj = DSI object,
	$testbed = test bed,
	$reportPath = Path, where the report to be generated

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::SBX5000::PERFHELPER::getNifIp()
	SonusQA::SBX5000::PERFHELPER::genReport()
	SonusQA::SBX5000::PERFHELPER::getPsxStatus()
	SonusQA::SBX5000::PERFHELPER::checkRedundancyStaus()
	SonusQA::SBX5000::PERFHELPER::getTrunkGroupStatus()
	SonusQA::SBX5000::PERFHELPER::getMLPPSetting()
	SonusQA::SBX5000::PERFHELPER::checkSysinitOutput()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &pretest_checkList($gsxobj,$psxobj,$dsiobj,$testbed,$reportPath);

=back

=cut

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

    $retVal = getNifIp($gsxobj);
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

=head2 C< startPerfLogger >

=over

=item DESCRIPTION:

    This function enables user to start perflogger script(used for collecting performance stats of SUT) as background process and returns the PID of the process in which perflogger was started.

=item Arguments:

    Mandatory
        -testcase => "EMS_GUI_PERF_001" Test case ID
        -sut  => "orsted" EMS device for which Performance stats has to be collected.
        -testbed  => "A" Test bed type A for solrias and B for linux
        -upload => "n" whether we attempt to push results to the DB. If the input is not 'n|N', it is assumed pushing results to DB is required.
        -path => "n" whether we attempt to push results to the DB. If the input is not 'n|N', it is assumed pushing results to DB is required.

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0 - on failure
    PID of the process in which perflogger was started.

=item EXAMPLE:

    my $pl_pid = $atsObj->start_perflogger( -testcase => "<TESTCASE_ID>",
                                            -sut  => "<EMS_SUT>",
                                            -testbed  => "<TESTBED_TYPE>",
                                            -upload => "<n|N for no, any other input will be assumed yes>",
                                            -path => "<path where perflogger will be started >");

=back

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
	
    @cmd_res = $self->execCmd("$basepath/perfLogger.pl -tc $args{-testcase} -g $args{-sut} -tb $args{-testbed} $upload_append >> nohup.out 2>&1& ");

    #PerfLogger takes some 10 secs to initialise.
    sleep 60;
    $logger->debug(__PACKAGE__ . ".$sub: Waiting for perflogger to inistialise ");


    @cmd_res = split /]/ , $cmd_res[0];
    $pid = $cmd_res[1];
    $logger->info(__PACKAGE__ . ".$sub Perflogger started with PID = $cmd_res[1]");
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [$cmd_res[1]]");
    return $pid;
}

=head2 C< startStopHaltCallFromNavtel >

=over

=item DESCRIPTION:

	Its a wrapper function used to start, Stop or Halt a Call From Navtel.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::NAVTEL::startCallGeneration()
	SonusQA::NAVTEL::stopCallGeneration()
	SonusQA::NAVTEL::haltGroup()
	SonusQA::NAVTEL::loadProfile()
	SonusQA::NAVTEL::runGroup()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args = 
	(
		-startCallGeneration => 1,
		-testSpecificData => %testSpecificData
	);
  $obj->startStopHaltCallFromNavtel(%args);

=back

=cut

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
                              '-timeout' =>120,
          )) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profilePath}\'");
    }
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

    #start Call generation from navtel
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
        }
    #wait for test enitre duration only if runGroup and startCallGenration fails
       $logger->debug("  WAITING - for test to finish for duration \'$testSpecificData{testDuration}\'");
       sleep ( $testSpecificData{testDuration} );

    #stop call generation from Navtel
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

=head2 C< startStopHaltCallFromNavtelIXIA > 

=over

=item DESCRIPTION:

	Its a wrapper function used to start, Stop and Halt a Call From Navtel and IXIA.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::NAVTEL::startCallGeneration()
	SonusQA::NAVTEL::stopCallGeneration()
	SonusQA::NAVTEL::haltGroup()
	SonusQA::NAVTEL::loadProfile()
	SonusQA::NAVTEL::runGroup()

	SonusQA::IXIA::portProfileLoad()
	SonusQA::IXIA::startTransmit()
	SonusQA::IXIA::stopTransmit()
	SonusQA::IXIA::checkTransmitStatus()
	SonusQA::IXIA::portCleanUp()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args =
        (
                -startCallGeneration => 1,
                -testSpecificData => %testSpecificData
        );

  $obj->startStopHaltCallFromNavtelIXIA($ixia_obj,$ixprof,%args);

=back

=cut

sub startStopHaltCallFromNavtelIXIA {
    my ($obj,$Obj1,$ixprof,%args) = @_;
    my $sub = ".startStopHaltCallFromNavtel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1; 
    my @verifyInputData  = qw/ profilePath profile groupName holdtime testDuration/;

    $logger->debug(" profile for ixia $ixprof " );
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

    #start Call generation from navtel
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
        }
sleep 200;
       ####################starting IXIA in TC #########################

            $logger->info(__PACKAGE__ . ".$sub: \n \n Loading profile to IXIA  \n \n");
                unless ($Obj1->portProfileLoad( -file => $ixprof, -cardID => 2, -portID => 7)) {
                die "dead in portProfileLoad\n";
                  }
                else {
                $logger->debug(" SUCCESS - executed Load profile for IXIA  \'$ixprof\'");
                  }
          ######## running the profile
      $logger->info(__PACKAGE__ . ".$sub: \n \n Starting IXIA Transmission \n \n");
                ######## START IXIA
                die "dead in startTransmit\n" unless $Obj1->startTransmit(-cardID => 2, -portID => 7);
            $logger->info(__PACKAGE__ . ".$sub: \n \n Yahoo !!! IXIA Transmission Started \n \n");

     #############################Ixia Started and the transmission started ###########################################

    #wait for test enitre duration only if runGroup and startCallGenration fails
       $logger->debug("  WAITING - for test to finish for duration \'$testSpecificData{testDuration}\'");
       sleep ( $testSpecificData{testDuration} );
        

######### STOP IXIA transmissioni####################
        die "dead in stopTransmit\n" unless $Obj1->stopTransmit(-cardID => 2, -portID => 7);
        sleep 1;


                die "dead in checkTransmitStatus\n" unless $Obj1->checkTransmitStatus(-cardID => 3, -portID => 2);
        sleep 1;
        die "dead in portCleanUp\n" unless $Obj1->portCleanUp();
        sleep 1;
     #############################Ixia Stopped and the transmission stopped ###########################################

    #stop call generation from Navtel
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

=head2 C< startStopHaltCallFromNavtelREG >

=over

=item DESCRIPTION:

	Its a wrapper function , used to start, Stop and Halt Call From NavtelREG

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::NAVTEL::haltGroup()
	SonusQA::NAVTEL::loadProfile()
	SonusQA::NAVTEL::runGroup()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args =
        (
                -startCallGeneration => 1,
                -testSpecificData => %testSpecificData
        );

  $obj->startStopHaltCallFromNavtelREG(%args);

=back

=cut

sub startStopHaltCallFromNavtelREG {
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
                              '-timeout' =>120,
          )) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profilePath}\'");
    }
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

    #start Call generation from navtel
   # if ( $args{-startCallGeneration} ) {
   #     unless ( $obj->startCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
   #         my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
   #         $logger->error($errMsg);
   #         #return 0;
   #         #$retVal = 0;
   #         unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
   #             my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
   #             $logger->error($errMsg);
   #             return 0;
   #         }
   #     return 0;
   #     }else {
   ##         $logger->debug(" SUCCESS - executed startCallGeneration command for group \'$testSpecificData{groupName}\'");
   #     }
   # #wait for test enitre duration only if runGroup and startCallGenration fails
       $logger->debug("  WAITING - for test to finish for duration \'$testSpecificData{testDuration}\'");
       sleep ( $testSpecificData{testDuration} );

    #stop call generation from Navtel
   #     unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
   #         my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
   #         $logger->error($errMsg);
   #         #return 0;
            #$retVal = 0;
            unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ){
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
                $logger->error($errMsg);
                return 0;
            }
       # return 0;
        #else {
           $logger->debug(" SUCCESS - executed stopCallGeneration command for group \'$testSpecificData{groupName}\'");
       # }

    #wait for call to gracefully complete
        $logger->debug("  WAITING - for call to finish for gracefully \'$testSpecificData{holdtime}\'");
        sleep ( $testSpecificData{holdtime} );
        $logger->debug(" <-- Leaving Sub [1]");
        return 1;
   # }else {
   #    $logger->debug("SUCCESS - profile is running in responding mode only." );
   #    return 1;
   # }

}#End of startStopHaltCallFromNavtel

=head2 C< collectOneCallLog >

=over

=item DESCRIPTION:

	Its a wrapper function used to run a call and collect the logs.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::NAVTEL::startCallGeneration()
	SonusQA::NAVTEL::stopCallGeneration()
	SonusQA::NAVTEL::haltGroup()
	SonusQA::NAVTEL::loadProfile()
	SonusQA::NAVTEL::runGroup()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args =
        (
                -startCallGeneration => 1,
                -testSpecificData => %testSpecificData
        );


  $obj->collectOneCallLog(%args);

=back

=cut

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
unless( $obj->loadProfile('-path' =>$testSpecificData{profilePath},'-file' =>$testSpecificData{profile},'-timeout' =>180)) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profile}\'");
    }

#Run Navtel Group's
    unless ($obj->runGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute runGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed runGroup command for group \'$testSpecificData{groupName}\'");
    }
#set Single Attempt Traffic Profile

    @callGenGroup = @{$trafficPattern{callOrgGroup}};
    foreach(@callGenGroup){
        $NavtelCmd = "setSingleAttemptTrafficProfile $_ {Make Call}";
        unless ($obj->execCliCmd('-cmd' =>$NavtelCmd, '-timeout' =>120) ) {
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
        unless ($obj->execCliCmd('-cmd' =>$NavtelCmd , '-timeout' =>120) ) {
            my $errMsg = "  FAILED - to execute $NavtelCmd  command for group \'$_\'.";
            $logger->error($errMsg);
           # return 0;
           #$retVal = 0;
        }else {
            $logger->debug("  SUCCESS - executed $NavtelCmd  command for group \'$_\'");
        }
    }
#start Call generation from navtel
    unless ( $obj->startCallGeneration('-groupName' =>$callGenGroup[0],'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed startCallGeneration command for group \'$callGenGroup[0]\'");
    }
#wait for call completion
    $logger->debug("  INFO - wating for call to get completed for $testSpecificData{holdtime}*2 sec");
    sleep $testSpecificData{holdtime}*2;

#stop call generation from Navtel
    unless ( $obj->stopCallGeneration('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed stopCallGeneration command for group \'$callGenGroup[0]\'");
    }


#halt the navtel
    unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        return 0;
    } else {
       $logger->debug("  SUCCESS - executed haltGroup command for group \'$testSpecificData{groupName}\'");
    }
    sleep 1;
   return $retVal;

}#End of collectOneCallLog

=head2 C< collectOneCallLogREG >

=over

=item DESCRIPTION:

        Its a wrapper function used to run a call and collect the logs.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::NAVTEL::startCallGeneration()
        SonusQA::NAVTEL::stopCallGeneration()
        SonusQA::NAVTEL::haltGroup()
        SonusQA::NAVTEL::loadProfile()
        SonusQA::NAVTEL::runGroup()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args =
        (
                -startCallGeneration => 1,
                -testSpecificData => %testSpecificData
        );


  $obj->collectOneCallLogREG(%args);

=back

=cut

sub collectOneCallLogREG{

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
unless( $obj->loadProfile('-path' =>$testSpecificData{profilePath},'-file' =>$testSpecificData{profile},'-timeout' =>180)) {
        my $errMsg = '  FAILED - loadProfile().';
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - profile loaded \'$testSpecificData{profilePath}\/$testSpecificData{profile}\'");
    }

#set Single Attempt Traffic Profile

    @callGenGroup = @{$trafficPattern{callOrgGroup}};
    foreach(@callGenGroup){
        $NavtelCmd = "setSingleAttemptTrafficProfile $_ {Register all EPs}";
        unless ($obj->execCliCmd('-cmd' =>$NavtelCmd, '-timeout' =>120) ) {
           my $errMsg = "  FAILED - to execute $NavtelCmd command for group \'$_\'.";
           $logger->error($errMsg);
           $retVal = 0;
          # return 0;
        }else {
           $logger->debug("  SUCCESS - executed $NavtelCmd  command for group \'$_\'");
        }
    }
    sleep 1;

#start Call generation from navtel
    unless ( $obj->runGroup('-groupName' =>$callGenGroup[0],'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute rungroup command for group \'$callGenGroup[0]\'";
        $logger->error($errMsg);
        #return 0;
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - executed runGroup command for group \'$callGenGroup[0]\'");
    }
#wait for call completion
    $logger->debug("  INFO - wating for call to get completed for $testSpecificData{holdtime}*2 sec");
    sleep 10;



#halt the navtel
    unless ( $obj->haltGroup('-groupName' =>$testSpecificData{groupName},'-timeout' =>120) ) {
        my $errMsg = "  FAILED - to execute haltGroup command for group \'$testSpecificData{groupName}\'.";
        $logger->error($errMsg);
        return 0;
    } else {
       $logger->debug("  SUCCESS - executed haltGroup command for group \'$testSpecificData{groupName}\'");
    }
    sleep 1;
   return $retVal;

}#End of collectOneCallLog

=head2 C< exportNavtelStat >

=over

=item DESCRIPTION:

	helps to export Navtel stats

=item ARGUMENTS:

 Mandatory :

	$testcase - test case id

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCmd()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->exportNavtelStat($testcase);

=back

=cut

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
         my $dirPath= $statsDir."/$testcase";
         $logger->debug("directory structure \'$dirPath\'");

##Check if stats dir exist if not create it

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

=head2 C< testCaseValidation >

=over

=item DESCRIPTION:

	Its a wrapper fucntion to validate the test case by checking the SYS or DBG error and do core check.

=item ARGUMENTS:

 Mandatory :

	$dirpath,
	$testcase,
	$gsxobj,
	@err_strings

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::Utils::logCheck
	checkCore

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &testCaseValidation($dirpath,$testcase,$gsxobj,@err_strings);

=back

=cut

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

=head2 C< RemoveSbxlogs >

=over

=item DESCRIPTION:

	Removes all the SBC logs

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->RemoveSbxlogs();

=back

=cut

sub RemoveSbxlogs {
my ($Obj) = @_;
  my $sub = "Remove_sbx_logs";
 my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&RemoveSbxlogs);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

  $logger->info(__PACKAGE__ . ".$sub :  Inside Remove SBX LOGS subroutine.");
  $logger->info(__PACKAGE__ . "Inside Remove SBX LOGS subroutine.");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("cd /var/log/sonus/sbx/evlog");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.ACT*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.DBG*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.SYS*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.AUD*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.TRC*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.SEC*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("rm -f *.PKT*");
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("cd");
  $logger->info(__PACKAGE__ . "Leaving Remove SBX LOGS subroutine.");
  return 1;
}

=head2 C< SBXStartSpamAct >

=over

=item DESCRIPTION:

	Used to start the SPAM in Active box of SBC and executes 'start-perf' cmd.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->SBXStartSpamAct();

=back

=cut

sub SBXStartSpamAct
{
  my ($Obj) = @_;
  my $sub = "Start SPAM on Active box";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub :  Start SPAM on Active box.");

    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&SBXStartSpamAct);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("start-perf");
  $logger->info(__PACKAGE__ . ".$sub :  Started SPAM on Active box.");
  return  1
}

=head2 C< SBXStartSpamStby >

=over

=item DESCRIPTION:

        Used to start the SPAM in Standby box of SBC and executes 'start-perf' cmd.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->SBXStartSpamStby();

=back

=cut

sub SBXStartSpamStby
{
  my ($Obj) = @_;
  my $sub = "Start SPAM on standby box";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub :  start SPAM on standby box.");

    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&SBXStartSpamStby);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
$Obj->{$Obj->{STAND_BY}}->{conn}->cmd("start-perf");
  $logger->info(__PACKAGE__ . ".$sub :  started SPAM on stanby box.");
  return  1;
}

=head2 C< SBXStopSpamAct >

=over

=item DESCRIPTION:

        Used to stop the SPAM in Active box of SBC and executes 'stop-perf' cmd.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->SBXStopSpamAct();

=back

=cut

sub SBXStopSpamAct
{
  my ($Obj) = @_;
  my $sub = "Stop SPAM on Active box";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub :  Stop SPAM on Active box.");
    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&SBXStopSpamAct);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
  $Obj->{$Obj->{ACTIVE_CE}}->{conn}->cmd("stop-perf");
  $logger->info(__PACKAGE__ . ".$sub :  Stopped SPAM on Active box.");
  return  1;
}

=head2 C< SBXStopSpamStby >

=over

=item DESCRIPTION:

        Used to stop the SPAM in Standby box of SBC and executes 'stop-perf' cmd.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->SBXStopSpamStby();

=back

=cut

sub SBXStopSpamStby
{
  my ($Obj) = @_;
  my $sub = "Stop SPAM on standby box";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub :  stop SPAM on standby box.");
    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&SBXStartSpamStby);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
  $Obj->{$Obj->{STAND_BY}}->{conn}->cmd("stop-perf");
  $logger->info(__PACKAGE__ . ".$sub :  stopped SPAM on stanby box.");
  return  1;
}

# Start and Stop Spam

=head2 C< spamStartStop >

=over

=item DESCRIPTION:

        Used to start/stop the SPAM .

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success

=item EXAMPLE:

  $obj->spamStartStop($ce,$cmd);

=back

=cut

sub spamStartStop
{
  my ($Obj,$ce,$cmd) = @_;
  my $sub = ".spamStartStop";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub :  $cmd on $ce box.");
    if ($Obj->{D_SBC}) {
        my $retVal = $Obj->__dsbcCallback(\&spamStartStop);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

  $Obj->{$Obj->{$ce}}->{conn}->cmd($cmd);
  $logger->info(__PACKAGE__ . ".$sub :  executed $cmd on $ce box.");
  return  1;
}

=head2 C< moveLogs >

=over

=item DESCRIPTION:

	helps to move the logs to the given path in the local server.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->moveLogs($tcid,$copyLocation,$nodename

=back

=cut

sub moveLogs {

    my ($self,$tcid,$copyLocation,$nodename) = @_ ;
    my $dstPathSpam;
    my $sub_name = "moveLogs";
    my ($srcPath,$dstPath,$ip,$hostactive,$localPath,$store_log,$ce,$datestamp);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "location .$copyLocation");
    my @logType = ('DBG', 'ACT', 'SYS');

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as testcase id.");
    }

   $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   #$ce = $self->{ACTIVE_CE};
   $localPath = '/var/log/sonus/sbx/evlog';
   
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   #$hostactive = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
   $hostactive = lc($nodename);
   #$hostactive = lc($self->{TMS_ALIAS_DATA}->{CE0}->{1}->{HOSTNAME});
   $ip = $self->{TMS_ALIAS_DATA}->{CE0}->{1}->{$ip_type};

   $logger->info(__PACKAGE__ . ".$sub_name: Hostname for currenlty active CE is $hostactive and IP: $ip");

   $ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type};

   unless ($self->{SCP}) {
    unless ($self->{SCP} = SonusQA::SCPATS->new(host => $ip, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
   }

   foreach (@logType) {
       $srcPath = "$localPath/*.$_" ;
       $dstPath = "$copyLocation$hostactive/$_";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self->{SCP}->scp( $ip . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
           return 0;
       }
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}#End of moveLogs

=head2 C< moveLogsCommon >

=over

=item DESCRIPTION:

        helps to move the Dut logs to the given path in the local server.

=item ARGUMENTS:

 Mandatory :

    $self= DUT object.
	$args{'copylocation'}= Destination path where the logs have to be stored.

 Optional :

	$args{'nodeName'}= Instance ce name for an ISBC.
	$args{'instanceName'}= Instance name(SSBC or MSBC) for a DSBC.

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  moveLogsCommon($ssbcObj,'copyLocation' => $SdirStr, 'nodename' => @ceNameSSBC, 'instanceName' => "SSBC");

=back

=cut

sub moveLogsCommon {

    my ($self,%args) = @_ ;
    my $sub = "moveLogsCommon";
    my ($srcPath,$dstPath,$ip,$hostactive,$localPath);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "Copy location is" .$args{'copyLocation'});
    my @logType = ('DBG', 'SYS', 'TRC', 'AUD', 'SEC', 'PKT', 'ACT');

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input sbx object is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{'copyLocation'} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument copyLocation is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

   $localPath = '/var/log/sonus/sbx/evlog';

   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   $hostactive = lc($args{'nodename'});
   $ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type};

   $logger->info(__PACKAGE__ . ".$sub: Hostname for currently active CE is $hostactive and IP: $ip");

   my %scpArgs;
   $scpArgs{-hostip} = $self->{OBJ_HOST};
   $scpArgs{-hostuser} = 'root';
   $scpArgs{-scpPort} = 2024;
   $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};

   # Set the instance Flag. This argument will be provided for DSBC.
   my $instance = (defined $args{'instanceName'}) ? '1':'0';

   foreach my $file (@logType) {
        $self->{$self->{ACTIVE_CE}}->{conn}->cmd("cd $localPath");
        $self->{$self->{ACTIVE_CE}}->{conn}->cmd("gzip *.$file"); #zipping all the logs
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip} . ':' . "$localPath/*.$file*";
		if ($instance){
			system("mkdir -p -m 777 $args{'copyLocation'}/DutLogs/$args{'instanceName'}");
			$scpArgs{-destinationFilePath} = "$args{'copyLocation'}/DutLogs/$args{'instanceName'}/";
		}else{
			$scpArgs{-destinationFilePath} = "$args{'copyLocation'}$hostactive/DutLogs/";
		}

		$logger->info(__PACKAGE__ . ".$sub: scp log $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");

		unless(&SonusQA::Base::secureCopy(%scpArgs)){
			$logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the  file");
			return 0;
		}
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;

}#End of moveLogsCommon

=head2 C< $ce,$copyLocation,$nodename >

=over

=item DESCRIPTION:

	helps to store the SPAM logs.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->storeSpamLogs($ce,$copyLocation,$nodename);

=back

=cut

sub storeSpamLogs {

    my ($self,$ce,$copyLocation,$nodename) = @_ ;
    my $sub_name = ".storeSpamLogs";
    my ($dstPathSpam,$hostactive,$hoststandby,$ip,$localPathSpam,$srcPath,$dstPath,$datestamp);

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  " location .$copyLocation");


   unless ( $self ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
   }

   unless ( $ce ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory ce type is empty or blank.");
   }

   $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ($ce eq "ACTIVE_CE"){
        #$hostactive = lc($self->{TMS_ALIAS_DATA}->{CE0}->{1}->{HOSTNAME});
        $hostactive = lc($nodename);
        $ip = $self->{TMS_ALIAS_DATA}->{CE0}->{1}->{$ip_type};
        $localPathSpam = $self->{TMS_ALIAS_DATA}->{CE0}->{1}->{BASEPATH};
        $dstPathSpam = "$copyLocation$hostactive/SPAM";
        $logger->debug(__PACKAGE__ . ".$sub_name: ACTIVE_CE CE0 Name: $hostactive and IP:$ip");

   } elsif ($ce eq "STAND_BY" ){
        #$hoststandby = lc($self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME});
        $hoststandby = lc($nodename);
        $ip = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{$ip_type};
        $dstPathSpam = "$copyLocation$hoststandby/SPAM";
        $localPathSpam = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{BASEPATH};
        $logger->debug(__PACKAGE__ . ".$sub_name: STAND_BY CE1 Name: $hoststandby and IP:$ip");

   }

   unless ($self->{SCP}) {
        unless ($self->{SCP} = SonusQA::SCPATS->new(host => $ip, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
   }

    $logger->debug(__PACKAGE__ . ".$sub_name: scp log $localPathSpam  to $dstPathSpam");
    unless( $self->{SCP}->scp( $ip . ':' ."$localPathSpam/\*.log", $dstPathSpam )){
        $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
        return 0;
    }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}#End of storeSpamLogs

=head2 C< storeLogs >

=over

=item DESCRIPTION:

	helps to store 'DBG', 'ACT' and 'SYS' logs from evlog path to given location.

=item ARGUMENTS:

 Mandatory :

	$tcid,
	$copyLocation

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->storeLogs($tcid,$copyLocation);

=back

=cut

sub storeLogs {

    my ($self,$tcid,$copyLocation) = @_ ;
    my $home_dir;
    my $dstPathSpam;
    my $sub_name = "storeLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "location .$copyLocation");
    my @logType = ('DBG', 'ACT', 'SYS');

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as testcase id.");
    }

   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 2 for saving logs on ATS server only
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $ce = $self->{ACTIVE_CE};
   my $store_log = $self->{STORE_LOGS} ;
   $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
   my $localPath = '/var/log/sonus/sbx/evlog';
   my $localPathSpam = '/root/spamlog';
   my $hostactive = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
   #my $hoststandby = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME};
   $logger->debug(__PACKAGE__ . ".$sub_name: Hostname for active and standby is $hostactive ");
   
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ( $store_log == 2 or $store_log == 3) {
       my $Ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type};
       unless ($self->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
       }
my  $srcPath;
my  $dstPath;
 foreach (@logType) {
           $srcPath = "$localPath/*.$_" ;
           $dstPath = "$copyLocation/$hostactive/$_";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self->{SCP}->scp( $Ip . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
return 0;
      }
    }
   $dstPathSpam = "$copyLocation/$hostactive/SPAM";
 $logger->debug(__PACKAGE__ . ".$sub_name: scp log $localPathSpam  to $dstPathSpam");
 unless( $self->{SCP}->scp( $Ip . ':' ."$localPathSpam/*.log", $dstPathSpam )){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
return 0;
      }
}
if ( $store_log == 2 or $store_log == 3) {
       my $Ip1 = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{$ip_type};
       unless ($self->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip1, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

       }
my  $srcPath;
my  $dstPath;
my $hoststandby = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME};
   $dstPathSpam = "$copyLocation/$hoststandby/SPAM";
 $logger->debug(__PACKAGE__ . ".$sub_name: scp log $localPathSpam  to $dstPathSpam");
 unless( $self->{SCP}->scp( $Ip1 . ':' ."$localPathSpam/*.log", $dstPathSpam )){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
return 0;
      }

}
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}

=head2 C< storeOnecallLog >

=over

=item DESCRIPTION:

	used to store log for one call

=item ARGUMENTS:

 Mandatory :

	$tcid,
	$copyLocation

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->storeOnecallLog($tcid,$copyLocation);

=back

=cut

sub storeOnecallLog {

    my ($self,$tcid,$copyLocation) = @_ ;
    my $home_dir;
    my $dstPathSpam;
    my $sub_name = "storeOneCallLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "location .$copyLocation");
    if ($self->{D_SBC}) {
        my $retVal = $self->__dsbcCallback(\&storeOnecallLog);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    $self->{$self->{"ACTIVE_CE"}}->{conn}->cmd("cd /var/log/sonus/sbx/evlog/");
    my @log_array = $self->{$self->{"ACTIVE_CE"}}->{conn}->cmd("ls 10*");
    my ($logs) = @log_array;
    #my @logType = ('DBG', 'ACT', 'SYS');
    my @logType = split(/\s+/,$logs);

    unless ( $self ) {
        $self->{$self->{"ACTIVE_CE"}}->{conn}->cmd("cd");
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as testcase id.");
    }
 unless ( $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as CopyLocation.");
    }
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $ce = $self->{ACTIVE_CE};
   my $store_log = $self->{STORE_LOGS} ;
   $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
   my $localPath = '/var/log/sonus/sbx/evlog';
   my $hostactive = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
   my $hoststandby = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME};
   
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ( $store_log == 2 or $store_log == 3) {
       my $Ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type};
       unless ($self->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
       }
my  $srcPath;
my  $dstPath;
 foreach (@logType) {
           $srcPath = "$localPath/$_" ;
           $dstPath = "$copyLocation/";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self->{SCP}->scp( $Ip . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
      }
    }
}
   $self->{$self->{"ACTIVE_CE"}}->{conn}->cmd("cd");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}

=head2 C< storeOnecallLog_pkt >

=over

=item DESCRIPTION:

        used to store 'DBG', 'ACT', 'SYS' and 'PKT' log for one call.

=item ARGUMENTS:

 Mandatory :

        $tcid,
        $copyLocation

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->storeOnecallLog_pkt($tcid,$copyLocation);

=back

=cut

sub storeOnecallLog_pkt {

    my ($self,$tcid,$copyLocation) = @_ ;
    my $home_dir;
    my $dstPathSpam;
    my $sub_name = "storeOneCallLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "location .$copyLocation");
    my @logType = ('DBG', 'ACT', 'SYS', 'PKT');

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as testcase id.");
    }
 unless ( $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: considering \'NONE\' as CopyLocation.");
    }
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $ce = $self->{ACTIVE_CE};
   my $store_log = $self->{STORE_LOGS} ;
   $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
   my $localPath = '/var/log/sonus/sbx/evlog';
   my $hostactive = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
   my $hoststandby = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME};
 
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ( $store_log == 2 or $store_log == 3) {
       my $Ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type};
       unless ($self->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip, user => 'root', password => 'sonus1', port => 2024, timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
       }
my  $srcPath;
my  $dstPath;
 foreach (@logType) {
           $srcPath = "$localPath/*.$_" ;
           $dstPath = "$copyLocation/";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self->{SCP}->scp( $Ip . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
      }
    }
}
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}

=head2 C< storeESXLogs >

=over

=item DESCRIPTION:

	Used to store ESX logs to the given location in local server.

=item ARGUMENTS:

 Mandatory :

	$self1,
	$self2,
	$self,
	$esxcsvn,
	$esxcsvk,
	$copyLocation

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &storeESXLogs($self1,$self2,$self,$esxcsvn,$esxcsvk,$copyLocation);

=back

=cut

sub storeESXLogs {

    my ($self1,$self2,$self,$esxcsvn,$esxcsvk,$copyLocation) = @_ ;
    my $sub_name = "storeESXLogs";
my $hostactive;
my $hoststandby;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  "location .$copyLocation");
    my @logType1 = ("$esxcsvn");
    my @logType2 = ("$esxcsvk");

    unless ( $self1 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $self2 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }



   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 2 for saving logs on ATS server only
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $store_log = $self->{STORE_LOGS} ;
   $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
   my $HYP1 = $self1->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
   my $HYP2 = $self2->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    $hostactive = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
    $hoststandby = $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME};

$logger->debug(__PACKAGE__ . ".$sub_name: ACTIVE hypervisor path $HYP1");
$logger->debug(__PACKAGE__ . ".$sub_name:  ACTIVE hypervisor path $HYP2");

   my $ip_type = ($self1->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ( $store_log == 2 or $store_log == 3) {
       #my $locallogname ;
       #$locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
       #$locallogname = "$copyLocation/nemo/DBG";
       #$logger->debug(__PACKAGE__ . ".$sub_name: $locallogname");
       my $Ip = $self1->{TMS_ALIAS_DATA}->{NODE}->{1}->{$ip_type};
       unless ($self1->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip, user => 'root', password => 'sonusnet', timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
       }
my  $srcPath;
my  $dstPath;
 foreach (@logType1) {
           $srcPath = "$HYP1/$_" ;
           $dstPath = "$copyLocation/$hostactive/ESX_DATA";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self1->{SCP}->scp( $Ip . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
      }
    }
}
 $ip_type = ($self2->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
 if ( $store_log == 2 or $store_log == 3) {
       #my $locallogname ;
       #$locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
       #$locallogname = "$copyLocation/nemo/DBG";
       #$logger->debug(__PACKAGE__ . ".$sub_name: $locallogname");
       my $Ip1 = $self2->{TMS_ALIAS_DATA}->{NODE}->{1}->{$ip_type};
       unless ($self2->{SCP}) {
            unless ($self->{SCP} = SonusQA::SCPATS->new(host => $Ip1, user => 'root', password => 'sonusnet', timeout => 180)){
                $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
       }
my  $srcPath;
my  $dstPath;
 my @logType2 = ("$esxcsvk");
$logger->debug(__PACKAGE__ . ".$sub_name: $esxcsvk");
foreach (@logType2) {
           $srcPath = "$HYP2/$_" ;
           $dstPath = "$copyLocation/$hoststandby/ESX_DATA";
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $self2->{SCP}->scp( $Ip1 . ':' ."$srcPath", $dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
      }
    }

}
$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}

=head2 C< moveESXLogs >

=over

=item DESCRIPTION:

	used to move the ESX logs.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->moveESXLogs($testCaseId,$copyLocation,$hostName,$interface,$sbxObj1);

=back

=cut

sub moveESXLogs {

    my ($self,$testCaseId,$copyLocation,$hostName,$interface,$sbxObj1) = @_ ;
    my $sub_name = "moveESXLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my @cmd_res = ();

    my ($basePath,$nodeName,$ip,$dstPath,$srcPath,$password,$fileName);
    my $hostname = lc($hostName);

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  ".$sub_name: --> $copyLocation");
    
    my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
    $basePath = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    $nodeName = lc($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});
    $ip = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{$ip_type};
    $password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    #$fileName = "$testCaseId-$nodeName.csv";

    $logger->debug(__PACKAGE__ . ".$sub_name: Hypervisor base path $basePath");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);

   unless ($self->{SCP}) {
        unless ($self->{SCP} = SonusQA::SCPATS->new(host => $ip, user => 'root', password => $password, timeout => 180)){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
   }
   $dstPath = "$copyLocation$hostname/ESX_DATA";
   if (lc($interface) eq lc("VmWare")) {
      $fileName = "$testCaseId-$nodeName.csv";
      $srcPath = "$basePath/$fileName" ;
   #$dstPath = "$copyLocation$nodeName/ESX_DATA";
   #$dstPath = "$copyLocation$hostname/ESX_DATA";
      $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");

         unless( $self->{SCP}->scp( $ip . ':' ."$srcPath", $dstPath)){
             $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
             return 0;
         } else {
             $logger->debug( "SUCCESS . .$sub_name: successfully moved log form $srcPath to $dstPath");
         }
   }elsif (lc($interface) eq lc("kvm") || lc($interface) eq lc("OpenStack") ) {
      my $vmname = $sbxObj1->{TMS_ALIAS_DATA}->{CE}->{1}->{ILOM_HOSTNAME};
      my $fileName1 = "GUEST_aut$vmname.csv";
      my $fileName2 = "$vmname"."_Packet_Drops_aut.csv";
      $srcPath = "$basePath/$fileName1" ;
         unless( $self->{SCP}->scp( $ip . ':' ."$srcPath", $dstPath)){
             $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
             return 0;
         } else {
             $logger->debug( "SUCCESS . .$sub_name: successfully moved log form $srcPath to $dstPath");
         }
     $srcPath = "$basePath/$fileName2";
         unless( $self->{SCP}->scp( $ip . ':' ."$srcPath", $dstPath)){
             $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
             return 0;
         } else {
             $logger->debug( "SUCCESS . .$sub_name: successfully moved log form $srcPath to $dstPath");
         }
     }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}#End of moveESXLogs

=head2 C< Removehypervisorlogs >

=over

=item DESCRIPTION:

	Used to remove the hypervisor logs.	

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &Removehypervisorlogs($self1,$self2);

=back

=cut

sub Removehypervisorlogs {

    my ($self1,$self2) = @_ ;
    my $sub_name = "Removehypervisorlogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self1 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $self2 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }



   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 2 for saving logs on ATS server only
   # $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $store_log = $self->{STORE_LOGS} ;
   $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
   my $HYP1 = $self1->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
   my $HYP2 = $self2->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
$logger->debug(__PACKAGE__ . ".$sub_name: printing ACTIVE hypervisor path $HYP1");
$logger->debug(__PACKAGE__ . ".$sub_name: printing ACTIVE hypervisor path $HYP2");

   my $ip_type = ($self1->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   if ( $store_log == 2 or $store_log == 3) {
       #my $locallogname ;
       #$locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
       #$locallogname = "$copyLocation/nemo/DBG";
       #$logger->debug(__PACKAGE__ . ".$sub_name: $locallogname");
my $cmd1= "cd $HYP1";
my $cmd2= "rm -fr *VSBC*";
unless ( $self1->{conn}->cmd($cmd1)) {
$logger->error(__PACKAGE__ . ".$sub_name: failed to get Hypervisor path on ACTIVE BOX");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully got Hypervisor path on ACTIVE BOX: $HYP1");
}

unless ( $self1->{conn}->cmd($cmd2)) {
$logger->error(__PACKAGE__ . ".$sub_name: failed to remove hypervisor stats on ACTIVE BOX");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully removed hypervisor stats on ACTIVE BOX: $HYP1");
}

      }

$ip_type = ($self2->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
if ( $store_log == 2 or $store_log == 3) {
       #my $locallogname ;
       #$locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
       #$locallogname = "$copyLocation/nemo/DBG";
       #$logger->debug(__PACKAGE__ . ".$sub_name: $locallogname");

my $cmd3= "cd $HYP2";
my $cmd4= "rm -fr *VSBC*";
unless ( $self2->{conn}->cmd($cmd3)) {
$logger->error(__PACKAGE__ . ".$sub_name: failed to get  Hypervisor  path on standby BOX");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully got Hypervisor path on standby BOX: $HYP2");
}
unless ( $self2->{conn}->cmd($cmd4)) {
$logger->error(__PACKAGE__ . ".$sub_name: failed to remove hypervisor stats on STANDBY BOX");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully removed hypervisor stats on STANDBY BOX: $HYP2");
}

      }

$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}
=head2 C< cleanHypervisorLogs >

=over

=item DESCRIPTION:

        Used to clean the hypervisor logs.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->cleanHypervisorLogs();

=back

=cut

sub cleanHypervisorLogs {

    my ($self) = @_ ;
    my $sub_name = ".cleanHypervisorLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($basePath,$nodeName,$cmd);
    my @cmd_res = ();

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);

   $basePath = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
   $nodeName = lc($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});

   $logger->debug(__PACKAGE__ . ".$sub_name: printing  hypervisor $nodeName basepath $basePath");

   $cmd = "cd $basePath";
   @cmd_res = $self->execCmd("$cmd");

   if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub_name $basePath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub_name <-- Leaving Sub [0]");
        return 0;
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully executed $cmd on hypervisor $nodeName");
    }

   $cmd = "rm -fr *VSBC*";

   unless ( $self->{conn}->cmd($cmd)) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to renove $cmd  $nodeName ");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
    }else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully executed $cmd on hypervisor $nodeName");
    }


   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}#Emd of cleanHypervisorLogs

=head2 C< esxCmdExecution >

=over

=item DESCRIPTION:

	Used to execute ESX commands.

=item ARGUMENTS:

 Mandatory :

	esxCmd - array of ESX cmds

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->esxCmdExecution(@esxCmd);

=back

=cut

sub esxCmdExecution {

    my ($self,@esxCmd) = @_ ;
    my $sub_name = ".esxCmdExecution";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my ($cmd,$basePath,$nodeName,$ip,$password);
    my @cmd_res = ();


    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $basePath = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    $nodeName = lc($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});

    $logger->debug(__PACKAGE__ . ".$sub_name: printing Hypervisor base path for $nodeName $basePath");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   $cmd = "cd $basePath";
   @cmd_res = $self->execCmd($cmd);

   if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub_name $basePath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub_name <-- Leaving Sub [0]");
        return 0;
   }else {
       $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully executed on $cmd on $nodeName");
   }

### execute the esxtop cmd
   foreach $cmd (@esxCmd){
       unless ( $self->{conn}->cmd($cmd)) { 
           $logger->error(__PACKAGE__ . ".$sub_name: failed to execute $cmd on $nodeName");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
           return 0;
       }else {
           $logger->info(__PACKAGE__ . ".$sub_name: Sucessfully executed  $cmd on $nodeName");
       }
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}#End of esxCmdExecution

=head2 C< testCaseValidationSbc >

=over

=item DESCRIPTION:

	validates the testcase by checking the pcaket drops,SYS/DBG error,core dump check and call failures.

=item ARGUMENTS:

 Mandatory :

	$dirpath,
	$testcase,
	$Obj,
	$interfaceType,
	$pdsp,
	@err_strings

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &testCaseValidationSbc($dirpath,$testcase,$Obj,$interfaceType,$pdsp,@err_strings);

=back

=cut

sub testCaseValidationSbc {
    my ($dirpath,$testcase,$Obj,$interfaceType,$pdsp,@err_strings) = @_;
    my $sub = ".testCaseValidationSbc";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $vmname;
    my $packetDropCount =0;
    my $retVal=2;
    
#my $hostname = $Obj->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
    my $hostname = lc($Obj->{TMS_ALIAS_DATA}->{CE0}->{1}->{HOSTNAME});
    #my $interfaceType = lc($Obj->{TMS_ALIAS_DATA}->{CE}->{1}->{DEVICE});
    switch ($interfaceType){
       case /vmxnet3/i {

        $logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be vmxnet3 hence checking for packet drops");
        #my $noOfVM = $Obj->{TMS_ALIAS_DATA}->{CE}->{1}->{NUMBER}; 
        #for (my $i = 1; $i <= $noOfVM ; $i++){
            $vmname = $Obj->{TMS_ALIAS_DATA}->{CE}->{1}->{ILOM_HOSTNAME};
            $a = system ("sh $pdsp/Packet_Drop_By_VM_Name.sh $dirpath/$hostname/ESX_DATA/*.csv $vmname");
            if ($a){$packetDropCount++;}
        if ($packetDropCount){
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/$hostname/ESX_DATA/*.csv");
            $retVal=1;
        }else{
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/$hostname/ESX_DATA/*.csv"); 
        }
    
    }
       case /virtio/i {
        $logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be kvm hence checking for packet drops");
            $a = system ("sh $pdsp/Packet_Drop_KVM.sh $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
            if ($a){$packetDropCount++;}
        if ($packetDropCount){
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
            $retVal=1;
        }else{
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
        }

    }
    
       case /none/i {

		$logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or kvm hence not checking for packet drops");
       }

     else{
        $logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or virtio hence not checking for packet drops");
         }
     
  }            
$logger->info(__PACKAGE__ . ".$sub: directory path $dirpath");
foreach my $s (@err_strings)
{
    my $err_sys = SonusQA::Utils::logCheck(-file => "$dirpath/$hostname/SYS/*.SYS",-string => "$s");
    my $err_dbg = SonusQA::Utils::logCheck(-file => "$dirpath/$hostname/DBG/*.DBG",-string => "$s");
if ( ($err_sys>1) || ($err_dbg>1) )
{
      $retVal=1;
      $logger->info(__PACKAGE__ . ".$sub:  $s is present in SYS/DBG log");
}
     else {
     $logger->info(__PACKAGE__ . ".$sub:  $s is not present  in SYS/DBG log");
}
}
my $core=0;
#core check
unless($Obj->checkforCore( -testCaseID => "$testcase")) {
      $logger->debug(__PACKAGE__ . ".$sub : SUCCESS - no cores found ");
      }
      else {
      $logger->debug(__PACKAGE__ . ".$sub : FAILURE -  cores found ");
      $retVal=2;
      $core=1;
      }


#call fails check
    my @r;
    my @data = ();
    my ($callAttempts,$CallComp,$cmd);
    my @commands = ("show status system systemCongestionCurrentStatistics","show status system systemCongestionIntervalStatistics","show table global callCountStatus");

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    foreach $cmd (@commands){
    unless ( @r = $Obj->execCmd($cmd) ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r));
    push (@data,@r);
    $logger->debug(__PACKAGE__ . "$sub  FILE to write : \'$dirpath/$hostname/README\' ");

    }
        open FH, ">>", "$dirpath/$hostname/README" or die $!;
                foreach (@data){
                        print FH "$_\n";
                }
        close FH;

    foreach (@r) {
        if (/all\s*(\d+)\s*(\d+)/) {
            $callAttempts = $1;
            $CallComp = $2;
            if ($callAttempts == 0) {
               $logger->error(__PACKAGE__ . "$sub No calls went through");
               $logger->debug(__PACKAGE__ . "$sub <== Leaving");
               $retVal=2; 
               return $retVal;
            } else {
            my $fail_percentage = eval{100 - eval{eval{$CallComp/$callAttempts}*100}};
            if ( $fail_percentage > 0.05 ) {
               $logger->debug(__PACKAGE__ . "$sub call failure % is $fail_percentage");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
               $retVal=2;
            }
        else{
               $logger->debug(__PACKAGE__ . "$sub call failure % is less than 0.05 ");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
              if ($retVal == 2 && $core == 0) 
              {$retVal = 0;}
        }}
   }
}


  
   $logger->debug(__PACKAGE__ . "$sub <== Leaving");

return $retVal;
}

=head2 C< mosValidation >

=over

=item DESCRIPTION:

      This function is used to calculate the MoS value from the Navtel stats that is stored in water server and validate them.
      Initially will compare the MoS values under Min MoS column with threshold value. If any one value goes below threshold, 
      validation will be failed and other files will be skipped

=item Arguments:

        Mandatory
                $nav_path : Navtel stats path of current working directory which will be sent from PT_SANITY file
       Optional
                None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Output:

        This function will return a falg($validation_flag) - which is used by PT_SANITY file to validate the testcase failure, 
        Minimum of MoS values($min_val) calculated from the present csv file, 
        Maximum of MoS values($max_val) and Average of MoS values( $avg_val)

=item EXAMPLE:

	&mosValidation();

=back

=cut

sub mosValidation{

use List::Util qw( min max );
my $zero_check = 0;
my $mos_threshold = 3.0; #MoS values of Navtel stats will be compared against this threshold value. If any of the values in csv file, goes below this value, validation will fail 

my $mos_Quality = 0;
my $validation_flag=0;   #Flag which will be sent to PT_SANITY file, based on which validation will be performed. Vlaue of zero is success, other than which will be failure.

my $min_mosvalue;
my $sub = ".mosValidation";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
my (@gmin1,@gavg1,@gmax1); #Resepctive lists which contains the respective values from the csv files. 
my ($v1, $v2, $v3);        #Scalar variables that holds the maximum value from each of the above lsits which will be returned back
my $dir_path = shift;
chomp($dir_path);
$logger->info(__PACKAGE__ . "$sub ==> \n Navtel Stats directory path taken from automation:$dir_path");

#Sub routine to check the value is already appended to list
sub listCheck{
my $dup_flag = 0;
my @list = @{$_[0]};
for (my $i=0; $i < scalar(@list); $i++){
   if($list[$i] == $_[1]){
      return 0;
   }
   else{
      $dup_flag += 1;
	}
}
if ($dup_flag != 0){
return 1;
   }
}

`gzip -d  $dir_path/SBC_testing_Media*`;
our @files = `ls $dir_path/SBC_testing_Media_In*`;
$logger->info(__PACKAGE__ . "$sub ==> \n Files going to be validated: @files"); 
my $file_count =0;   #Variable used to validate the MoS based on filecount. 
for (my $i = 0; $i < scalar(@files);$i++){
	my $fh;
	my (@min_moslist, @max_moslist,@avg_moslist);
	my $file_Name = $files[$i];
	chomp($file_Name);
	$logger->info(__PACKAGE__ . "$sub ==> \n MOS VALIDATION FUNCTION ENTERED WITH INPUT FILE $file_Name");
	open($fh, "<$file_Name") or die "Couldn't open file $file_Name";
	while (<$fh>)   #Loop to check whether the field contains atleast one value other than zero
	{
	   $file_count += 1;
	   my  @cur_list  = split(',');
	   if($cur_list[19] != '-' and $cur_list[19] != 0 ){
	           $zero_check += 1;
        	   if($cur_list[19] > $mos_threshold){
                	next;
	           }
	           else{
	                $mos_Quality += 1;
	                $min_mosvalue = $cur_list[19];
	                last;
	                }
	   }
	}

	if ($mos_Quality != 0 or $zero_check == 0){
        	if ( $zero_check == 0 and $file_count==1){
	                $validation_flag -= 1;
                }
	}
        if ($mos_Quality != 0 and $zero_check != 0){
                $validation_flag += 1;
                $logger->info(__PACKAGE__ . "$sub ==> \n Mos Value has fallen below the Threshold value: $mos_threshold");
                $logger->info(__PACKAGE__ . "$sub ==> \n File $file_Name has mos value below than threshold value");
                $logger->info(__PACKAGE__ . "$sub ==> \n Poor MoS Value: $min_mosvalue");


        }
#######MOS VALID IS ABOVE THRESHOLD AND HENCE PROCEEDING WITH VALUE EXTRACTION####################
	elsif ($mos_Quality == 0 and $zero_check != 0){
		$logger->info(__PACKAGE__ . "$sub ==> \n MoS value is above the Threshold value $mos_threshold");
####MINIMUM MOS-VALUE FIELD#########
		open($fh, "<$file_Name") or die "Couldn't open file $file_Name";
		while (<$fh>)
		{
		   my  @cur_list  = split(',');
		   if($cur_list[19] != '-' and $cur_list[19] != 0 ){
		           if (scalar(@min_moslist) == 0) {
		                push(@min_moslist,$cur_list[19]);
                		#my $len = scalar(@max_moslist);
		            }
	        	   elsif ( listCheck(\@min_moslist,$cur_list[19]) ){
		                push(@min_moslist,$cur_list[19]);
	            	    }

  	 	    }
####MAXIMUM MOS-VALUE FIELD#########		 
                    if($cur_list[20] != '-' and $cur_list[20] != 0 ){
                            if (scalar(@max_moslist) == 0) {
                                 push(@max_moslist,$cur_list[20]);
                                 #my $len = scalar(@max_moslist);
                             }
                            elsif ( listCheck(\@max_moslist,$cur_list[20]) ){
                                 push(@max_moslist,$cur_list[20]);
                            }
                    
                    }
####AVERAGE MOS-VALUE FIELD#########
                    if($cur_list[21] != '-' and $cur_list[21] != 0 ){
                            if (scalar(@avg_moslist) == 0) {
                                 push(@avg_moslist,$cur_list[21]);
                                 #my $len = scalar(@avg_moslist);
                            }
                            elsif ( listCheck(\@avg_moslist,$cur_list[21]) ){
                                 push(@avg_moslist,$cur_list[21]);
                            }
 
                    }
                 }
                 
                 $logger->info(__PACKAGE__ . "$sub ==> \n MINIMUM MOS LIST @min_moslist");
                 my $min = max @min_moslist;
                 push(@gmin1,$min);
                 $logger->info(__PACKAGE__ . "$sub ==> \n Minimum MoS Value: $min");

		 $logger->info(__PACKAGE__ . "$sub ==> \n MAXIMUM MOS LIST @max_moslist");
		 my $max = max @max_moslist;
		 push(@gmax1,$max);
		 $logger->info(__PACKAGE__ . "$sub ==> \n Maximum MoS Value: $max");

                 $logger->info(__PACKAGE__ . "$sub ==> \n AVERAGE MOS LIST @avg_moslist");
                 my $avg = max @avg_moslist;
                 push(@gavg1,$avg);
                 $logger->info(__PACKAGE__ . "$sub ==> \n Average MoS Value: $avg\n");




	}
$mos_Quality = 0; #Resetting the value back to zero before the validation of next file
$zero_check = 0;  #Resetting the value back to zero before the validation of next file
  

   if ($validation_flag >= 1 or $validation_flag < 0){
	last;
   }
}
$v1 = max @gmin1;
$v2 = max @gmax1;
$v3 = max @gavg1;

if ($validation_flag < 0){
$logger->info(__PACKAGE__ . "$sub ==> \n FAILING THE TEST CASE AS THE FILE HAS NO MOS VAUES PRESENT");
}

elsif( $validation_flag == 0 or $validation_flag >0) {
$logger->info(__PACKAGE__ . "$sub ==> \n FINAL LIST FROM ALL THE FILES\n MINIMUM:@gmin1 \n MAXIMUM: @gmax1 \n AVERAGE:@gavg1");
#Returns the validation flag value along with the mos values
return ($validation_flag, $v1, $v2, $v3);
}
}
=head2 C< testCaseValidationSbc_DSBC >

=over

=item DESCRIPTION:

        validates the testcase by checking the pcaket drops,SYS/DBG error,core dump check and call failures for a DSBC.

=item ARGUMENTS:

 Mandatory :

        $dirpath,
        $testcase,
        $Obj,
        $interfaceType,
        $pdsp,
	$error_flag,
        @err_strings

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &testCaseValidationSbc_DSBC($dirpath,$testcase,$Obj,$interfaceType,$pdsp,$error_flag,@err_strings);

=back

=cut

sub testCaseValidationSbc_DSBC {
    my ($dirpath,$testcase,$Obj,$interfaceType,$pdsp,$error_flag,@err_strings) = @_;
    my $sub = ".testCaseValidationSbc_DSBC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal=2;
    my $failure_reason;
    my $testStatus;
    my $vmname;
    my $packetDropCount =0;

    my $hostname = lc($Obj->{TMS_ALIAS_DATA}->{CE0}->{1}->{HOSTNAME});

    switch ($interfaceType){
       case /vmxnet3/i {

        $logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be vmxnet3 hence checking for packet drops");
            $vmname = $Obj->{TMS_ALIAS_DATA}->{CE}->{1}->{ILOM_HOSTNAME};
            $a = system ("sh $pdsp/Packet_Drop_By_VM_Name.sh $dirpath/$hostname/ESX_DATA/*.csv $vmname");
            if ($a){$packetDropCount++;}
        if ($packetDropCount){
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/$hostname/ESX_DATA/*.csv");
            $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Packet drops are observed in Host machine of the DUT";
            $retVal=1;
        }else{
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/$hostname/ESX_DATA/*.csv");
        }

    }
       case /virtio/i {
        $logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be kvm/openstack hence checking for packet drops");
            $a = system ("sh $pdsp/Packet_Drop_KVM.sh $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
            if ($a){$packetDropCount++;}
        if ($packetDropCount){
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
            $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Packet drops are observed in Host machine of the DUT";
            $retVal=1;
        }else{
            $logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/$hostname/ESX_DATA/*Packet_Drops_aut.csv");
        }

    }

       case /none/i {

                $logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or kvm hence not checking for packet drops");
       }

     else{
        $logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or virtio hence not checking for packet drops");
         }

  }

$logger->info(__PACKAGE__ . ".$sub: directory path $dirpath");
foreach my $s (@err_strings)
{
    my $err_sys = SonusQA::Utils::logCheck(-file => "$dirpath/$hostname/SYS/*.SYS",-string => "$s");
    my $err_dbg = SonusQA::Utils::logCheck(-file => "$dirpath/$hostname/DBG/*.DBG",-string => "$s");
if ( ($err_sys>1) || ($err_dbg>1) )
{
    if ($error_flag==1){
        $retVal=1;
        $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- $s string is present in SYS/DBG log of the DUT";
        $logger->info(__PACKAGE__ . ".$sub: $s is present in SYS/DBG log");
     } else {
        $logger->info(__PACKAGE__ . ".$sub\n\nError String Validation is disabled\n\n");
        $logger->info(__PACKAGE__ . ".$sub: $s string is present in SYS/DBG log");
}}
     else {
     $logger->info(__PACKAGE__ . ".$sub:  $s is not present  in SYS/DBG log");
}
}
my $core=0;
#core check
unless($Obj->checkforCore( -testCaseID => "$testcase")) {
      $logger->debug(__PACKAGE__ . ".$sub : SUCCESS - no cores found ");
      }
      else {
      $logger->debug(__PACKAGE__ . ".$sub : FAILURE -  cores found ");
      $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Core Dump is found in the DUT!!!!!";
      $retVal=2;
      $core=1;
      }


#call fails check
    my @r;
    my @data = ();
    my ($callAttempts,$CallComp,$cmd);
    my @commands = ("show status system systemCongestionCurrentStatistics","show status system systemCongestionIntervalStatistics","show table global callCountStatus");

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    foreach $cmd (@commands){
    unless ( @r = $Obj->execCmd($cmd) ) {
                $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r));
    push (@data,@r);
    $logger->debug(__PACKAGE__ . "$sub  FILE to write : \'$dirpath/$hostname/README\' ");

    }
        open FH, ">>", "$dirpath/$hostname/README" or die $!;
                foreach (@data){
                        print FH "$_\n";
                }
        close FH;

    foreach (@r) {
        if (/all\s*(\d+)\s*(\d+)/) {
            $callAttempts = $1;
            $CallComp = $2;
            if ($callAttempts == 0) {
               $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- No calls went through";
               $logger->error(__PACKAGE__ . "$sub No calls went through");
               $logger->debug(__PACKAGE__ . "$sub <== Leaving");
               $retVal=2;
               $testStatus = {
                result => $retVal,
                reason => $failure_reason # FAIL
                };
                return @{[%$testStatus]};
            } else {
            my $fail_percentage = eval{100 - eval{eval{$CallComp/$callAttempts}*100}};
            if ( $fail_percentage > 0.05 ) {
               $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Call failure is > .05% in DUT";
               $logger->debug(__PACKAGE__ . "$sub call failure % is $fail_percentage");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
               $retVal=2;
            }
        else{
               $logger->debug(__PACKAGE__ . "$sub call failure % is less than 0.05 ");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
              if ($retVal == 2 && $core == 0)
              {$retVal = 0;} 
        }}    
   }    
}  

   $logger->debug(__PACKAGE__ . "$sub <== Leaving");

        if ($retVal ==0 )  #### Test case Validation Passed
        {
        return $retVal;
        } else {          # test case validation failed
                $testStatus = {
                result => $retVal,
                reason => $failure_reason
        };
        return @{[%$testStatus]};
        }
}

=head2 C< testCaseValidationSbc_DSBCcommon >

=over

=item DESCRIPTION:

        validates the testcase by checking the pcaket drops,SYS/DBG error,core dump check and call failures for a DSBC.

=item ARGUMENTS:

 Mandatory :

        $args{'checkPath'} = Path where the Logs are present. 
        $args{'testCase'} = TestCase id 
        $obj = Dut object
        $args{'interfaceType'} = interface type
        $args{'pdsp'} = path of packet drop script,
        $args{'error_flag'} = ,
        @{$args{'err_strings'}} = Error strings that has to be checked in Dut Logs.

 Optional :

    $args{'instanceName'} = SBX instance name. This si mandatory for DSBC object.

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &testCaseValidationSbc_DSBCcommon($Obj,'testCase' => $testCase, 'checkPath' => $dirPath, 'interfacetype' => $interfaceype, 'pdsp' => $packet_drops_script, 'error_flag' => $error_flag, 'err_strings' => @error_strings, 'instanceName' => "SSBC1");

=back

=cut

sub testCaseValidationSbc_DSBCcommon {
    my ($obj,%args) = @_;
    my $sub = ".testCaseValidationSbc_DSBCcommon";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal=2;
    my $failure_reason;
    my $testStatus;
    my $vmname;
    my $packetDropCount =0;
    my $dirpath;
    my $dutpath;

    my $hostname = lc($obj->{TMS_ALIAS_DATA}->{CE0}->{1}->{HOSTNAME});

    # Set the instance Flag. This argument will be provided for DSBC-Performance.
    my $instance = (defined $args{'instanceName'}) ? '1':'0';
    if (!$instance){
		$dirpath = "$args{'checkPath'}/$hostname";
		$dutpath = "$dirpath/DutLogs";
     } else {
		$dirpath = "$args{'checkPath'}";
		$dutpath = "$dirpath/DutLogs/$args{'instanceName'}";
     }

     my @err_strings = @{$args{'err_strings'}};

     switch ($args{'interfacetype'}){
       case /vmxnet3/i {

			$logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be vmxnet3 hence checking for packet drops");
				$vmname = $obj->{TMS_ALIAS_DATA}->{CE}->{1}->{ILOM_HOSTNAME};
				$a = system ("sh $args{'pdsp'}/Packet_Drop_By_VM_Name.sh $dirpath/ESX_DATA/*.csv $vmname");
				if ($a){$packetDropCount++;}
			if ($packetDropCount){
				$logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/ESX_DATA/*.csv");
				$failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Packet drops are observed in Host machine of the DUT";
				$retVal=1;
			}else{
				$logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/ESX_DATA/*.csv");
			}

		}
       case /virtio/i {
			$logger->debug(__PACKAGE__ . ".$sub :the interface type is found to be kvm/openstack hence checking for packet drops");
				$a = system ("sh $args{'pdsp'}/Packet_Drop_KVM.sh $dirpath/ESX_DATA/*Packet_Drops_aut.csv");
				if ($a){$packetDropCount++;}
			if ($packetDropCount){
				$logger->debug(__PACKAGE__ . ".$sub : packet drops are present in the csv file $dirpath/ESX_DATA/*Packet_Drops_aut.csv");
				$failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Packet drops are observed in Host machine of the DUT";
				$retVal=1;
			}else{
				$logger->debug(__PACKAGE__ . ".$sub : packet drops are not present in the csv file $dirpath/ESX_DATA/*Packet_Drops_aut.csv");
			}
		}

       case /none/i {

                $logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or kvm hence not checking for packet drops");
       }

     else{
        $logger->debug(__PACKAGE__ . ".$sub :the interface type is not vmxnet3 or virtio hence not checking for packet drops");
     }
    }

    $logger->info(__PACKAGE__ . ".$sub: directory path $dirpath");
    foreach my $s (@err_strings)
    {
    	my $err_sys = SonusQA::Utils::logCheck(-file => "$dutpath/*.SYS*",-string => "$s");
    	my $err_dbg = SonusQA::Utils::logCheck(-file => "$dutpath/*.DBG*",-string => "$s");
	if ( ($err_sys>1) || ($err_dbg>1) )
	{
    		if ($args{'error_flag'}==1){
        		$retVal=1;
        		$failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- $s string is present in SYS/DBG log of the DUT";
        		$logger->info(__PACKAGE__ . ".$sub: $s is present in SYS/DBG log");
     		} else {
        		$logger->info(__PACKAGE__ . ".$sub\n\nError String Validation is disabled\n\n");
        		$logger->info(__PACKAGE__ . ".$sub: $s string is present in SYS/DBG log");
		}
	}
	else {
     		$logger->info(__PACKAGE__ . ".$sub:  $s is not present  in SYS/DBG log");
	}
    }

    my $core=0;
    #core check
    unless($obj->checkforCore( -testCaseID => "$args{'testCase'}")) {
	$logger->debug(__PACKAGE__ . ".$sub : SUCCESS - no cores found ");
    }
    else {
    	$logger->debug(__PACKAGE__ . ".$sub : FAILURE -  cores found ");
      	$failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Core Dump is found in the DUT!!!!!";
      	$retVal=2;
      	$core=1;
    }

    #call fails check
    my @r;
    my @data = ();
    my ($callAttempts,$CallComp,$cmd);
    my @commands = ("show status system systemCongestionCurrentStatistics","show status system systemCongestionIntervalStatistics","show table global callCountStatus");

    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    foreach $cmd (@commands){
    unless ( @r = $obj->execCmd($cmd) ) {
                $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result:");
    }
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r));
    push (@data,@r);
    $logger->debug(__PACKAGE__ . "$sub  FILE to write : \'$dirpath/README\' ");

    }
        open FH, ">>", "$dirpath/README" or die $!;
                foreach (@data){
                        print FH "$_\n";
                }
        close FH;

    foreach (@r) {
        if (/all\s*(\d+)\s*(\d+)/) {
            $callAttempts = $1;
            $CallComp = $2;
            if ($callAttempts == 0) {
               $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- No calls went through";
               $logger->error(__PACKAGE__ . "$sub No calls went through");
               $logger->debug(__PACKAGE__ . "$sub <== Leaving");
               $retVal=2;
               $testStatus = {
                result => $retVal,
                reason => $failure_reason # FAIL
                };
                return @{[%$testStatus]};
            } else {
            my $fail_percentage = eval{100 - eval{eval{$CallComp/$callAttempts}*100}};
            if ( $fail_percentage > 0.05 ) {
               $failure_reason= $failure_reason . "\n\t\t\t\t\t\t\t\t- Call failure is > .05% in DUT";
               $logger->debug(__PACKAGE__ . "$sub call failure % is $fail_percentage");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
               $retVal=2;
            }
            else{
               $logger->debug(__PACKAGE__ . "$sub call failure % is less than 0.05 ");
               $logger->debug(__PACKAGE__ . "$sub No of Calls failed: ". eval{$callAttempts - $CallComp});
              if ($retVal == 2 && $core == 0)
              {$retVal = 0;}
            }}
        }
    }

    $logger->debug(__PACKAGE__ . "$sub <== Leaving");

    if ($retVal ==0 )  #### Test case Validation Passed
    {
        return $retVal;
    } else {          # test case validation failed
                $testStatus = {
                result => $retVal,
                reason => $failure_reason
    		};
    	return @{[%$testStatus]};
    }
}#EndOf-testCaseValidationSbc_DSBCcommon

=head2 C< setNavtelTrafficPattern >

=over

=item DESCRIPTION:

	used to set the NAVTEL traffic pattern.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->setNavtelTrafficPattern(%args);

=back

=cut

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

=head2 C< startCallFromNavtel >

=over

=item DESCRIPTION:

	Its a wrapper funciton to start the call from NAVTEL and do more funcitons

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::NAVTEL::startCallGeneration()
        SonusQA::NAVTEL::stopCallGeneration()
        SonusQA::NAVTEL::haltGroup()
        SonusQA::NAVTEL::loadProfile()
        SonusQA::NAVTEL::runGroup()

	SonusQA::SBX5000::PERFHELPER::configGlobalParameters()
	SonusQA::SBX5000::PERFHELPER::configEPBlock()
	SonusQA::SBX5000::PERFHELPER::setNavtelTrafficPattern()
	SonusQA::SBX5000::PERFHELPER::setNavtelOutBoundProxy()
	SonusQA::SBX5000::PERFHELPER::configHardwareSelection()
	SonusQA::SBX5000::PERFHELPER::configEPMapping()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  my %args =
        (
                -startCallGeneration => 1,
                -testSpecificData => %testSpecificData
        );

  $obj->startCallFromNavtel(%args);

=back

=cut

sub startCallFromNavtel {
    my ($obj,%args) = @_;
    my $sub = ".startCallFromNavtel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1;
    my @verifyInputData  = qw/ profilePath profile groupName holdtime testDuration/;
    my $key;

    if ($obj->{D_SBC}) {
        $retVal = $obj->__dsbcCallback(\&startCallFromNavtel);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
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
##Check if global Parameters needs to be set
    if ( $args{-configGlobal} ) {
        my $configGlobal = $args{-configGlobal};
        $logger->debug("  SUCCESS - Global Parameters needs to be  set");
        unless (configGlobalParameters($obj,'-configGlobal'=>$configGlobal) ) {
           my $errMsg = "  FAILED - to set the global Parameters";
           $logger->error($errMsg);
           return 0;
         }else {
           $logger->debug("  SUCCESS - successfully set the global Parameters");
       }

    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the global parameters");
    }

##Check if ep block needs to be set
    if ( $args{-configEP} ) {
        my $configEP = $args{-configEP};
        $logger->debug("  SUCCESS - ep block needs to be  set");
        unless (configEPBlock($obj,'-configEP'=>$configEP) ) {
           my $errMsg = "  FAILED - to set the ep block";
           $logger->error($errMsg);
           return 0;
         }else {
           $logger->debug("  SUCCESS - successfully set ep block");
       }
 
    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the ep block");
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
    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the traffic pattern");
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
    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the proxy server data");
    }

##check if Navtel hardware board selection is required
   if ( $args{-HardwareSelection} ) {
      my $configHardware = $args{-HardwareSelection};
      $logger->debug("  SUCCESS - Navtel hardware board detail needs to be set ");

      unless (configHardwareSelection($obj,'-HardwareSelection' =>$configHardware) ){
         my $errMsg = "  FAILED - to set Navtel hardware board detail ";
         $logger->error($errMsg);
           return 0;
       }else {
           $logger->debug("  SUCCESS - successfully set the Navtel hardware board detail");
       }
    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the hardware parameters");
    }

##check if Endpoint Mapping is Required
   if ( $args{-EPMapping} ) {
      my $EPMapping = $args{-EPMapping};
      $logger->debug("  SUCCESS - Enpoint mapping is required ");

      unless (configEPMapping($obj,'-EPMapping'=>$EPMapping) ){
          my $errMsg = "  FAILED - to do endpoint mapping ";
         $logger->error($errMsg);
           return 0;
       }else {
           $logger->debug("  SUCCESS - successfully set the endpoint mapping");
       }
    }else{
         $logger->debug("  end point configuration parameters are not passed hence not setting the endpoint mapping");
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

=head2 C< stopHaltCallFromNavtel >

=over

=item DESCRIPTION:

	Its a wrapper function to start a call from NAVTEL.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::NAVTEL::stopCallGeneration()
        SonusQA::NAVTEL::haltGroup()
        SonusQA::NAVTEL::loadProfile()
        SonusQA::NAVTEL::runGroup()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->stopHaltCallFromNavtel(%args);

=back

=cut

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

=head2 C< stopIxiaTransmit >

=over

=item DESCRIPTION:

	used to stop the IXIA transmit.

=item ARGUMENTS:

 Mandatory :

	$readme,
	%args

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::IXIA::stopTransmit()
        SonusQA::IXIA::checkTransmitStatus()
        SonusQA::IXIA::portCleanUp()
        SonusQA::IXIA::statsCollect()

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->stopIxiaTransmit($readme,%args);

=back

=cut

sub stopIxiaTransmit{
    my ($Obj1,$readme,%args)=@_;
    my $sub = ".stopIxiaTransmit";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");
    my $retVal = 1;
    my %ixiaSpecificData;
    my %statistics;
    my $key;
    my @ixiaMandatoryData  = qw/ cardId portId streamId chasId ixiaProfile/;
   
    if ($Obj1->{D_SBC}) {
        $retVal = $Obj1->__dsbcCallback(\&stopIxiaTransmit);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

    if ( defined ($args{"-ixiaSpecificData"}) ) {
       %ixiaSpecificData  = %{ $args{'-ixiaSpecificData'} };
   } else {
       $logger->error("  ERROR: The mandatory  DATA argument for  has not been defined.");
       return 0;
   }

     foreach ( @ixiaMandatoryData ) {
        unless ( defined ( $ixiaSpecificData{$_} ) ) {
            $logger->error("  ERROR: The mandatory  DATA argument for \'$_\' has not been specified.");
            $logger->debug(" <-- Leaving Sub [0]");
            $retVal = 0;
            return $retVal;
        }
        $logger->debug("  ixiaSpecificData\{$_\}\t- $ixiaSpecificData{$_}");
   }

    unless ($Obj1->stopTransmit('-cardID' => $ixiaSpecificData{cardId},'-portID' => $ixiaSpecificData{portId} )){
        $logger->debug("  FAIL - to stop transmission from IXIA. ");
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - successfully stopped traffic from IXIA.");
    }
    sleep 1;

    unless ($Obj1->checkTransmitStatus('-cardID' => $ixiaSpecificData{cardId},'-portID' => $ixiaSpecificData{portId} )){
        $logger->debug("  FAIL - to check IXIA  transmission Status. ");
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - successfully checked transmission status of IXIA.");
    }
    sleep 1;

    unless (%statistics=$Obj1->statsCollect('-cardID' => $ixiaSpecificData{cardId},'-portID' => $ixiaSpecificData{portId},  -stats => ['bytesSent', 'framesReceived', 'framesSent', 'oversize'] )){
       $logger->error(__PACKAGE__ . ".$sub: failed to get required stats");
       $retVal = 0;

     }else {
       $logger->debug("  SUCCESS - successfully collected stats from IXIA.");
     }
     sleep 1;

    $logger->debug(__PACKAGE__ . "$sub  FILE to write : $readme' ");

        open FH, ">>", "$readme" or die $!;
                foreach $key (keys %statistics){
                        print FH "$key = $statistics{$key}\n";
                }
                print FH "framesSentPerSec = $ixiaSpecificData{fpsRate}\n";
        close FH;

    unless ($Obj1->portCleanUp()){
        $logger->debug("  FAIL - to cleanup  IXIA. ");
        $retVal = 0;
    }else {
        $logger->debug("  SUCCESS - successfully cleanup traffic from IXIA.");
    }


    return $retVal;
}

=head2 C< collectLogFromRemoteServer >

=over

=item DESCRIPTION:

	Helps to collect the log from server.

=item ARGUMENTS:

 Mandatory :

	$src_ip, 
	$username, 
	$passwd , 
	$src_dir,
	$dest_dir

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &collectLogFromRemoteServer($src_ip, $username, $passwd , $src_dir, $dest_dir);

=back

=cut

sub collectLogFromRemoteServer{

    my ($src_ip, $username, $passwd , $src_dir, $dest_dir) = @_;
    #my ($dest_ip, $dest_userid, $dest_passwd);
    my ($scp_session,@logType,$srcPath,$dstPath,$retVal);

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

    #Open SCP Session
    unless ($scp_session = SonusQA::SCPATS->new(host => $src_ip, user => $username, password => $passwd, timeout => 180)){
        $logger->error(__PACKAGE__ . ".$sub: failed to make scp connection");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->info("$sub:  Opened $username SCP session to $src_ip server");

    sleep 5;

#######Move log to server
#Move all the files
    $srcPath = "$src_dir/*.*" ;
    $dstPath = "$dest_dir/";

    $logger->info("$sub:  Moving Log from remote Server path:$srcPath to Local Server path:$dstPath");
    unless($scp_session->scp( $src_ip . ':' ."$srcPath", $dstPath)){
        $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the  file");
        $retVal = 0;
    }else {
        $logger->info("$sub:  SUCCESS Log moved from remote Server path:$srcPath to Local Server path:$dstPath");
    }
   $logger->info("$sub: returning [1]");
   return $retVal;
}#End of collect log from server

=head2 C< setNavtelOutBoundProxy >

=over

=item DESCRIPTION:

	Helps to set the NAVTEL out bound proxy.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->setNavtelOutBoundProxy(%args);

=back

=cut

sub setNavtelOutBoundProxy {

    my ($obj,%args) = @_;
    my $sub = ".setNavtelOutBoundProxy";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($proxyName,$key,$navtelCmd,$proxyIp,$port);

    my @verifyInputData  = qw/ serverName serverIp ipVersion port /;
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

####validate the input data accourding to the pattern
    foreach $key (keys %proxyServerData){

        $port = $proxyServerData{$key}{port};
        $proxyName = $proxyServerData{$key}{serverName};
        $proxyIp = $proxyServerData{$key}{serverIp};
        
        if ($proxyServerData{$key}{ipVersion} eq "IPV4" ){
            $navtelCmd = "configProxyServer -serverName $proxyName -ipv4AddrEnable 1 -ipv4Address $proxyIp -port $port";
        }elsif ($proxyServerData{$key}{ipVersion} eq "IPV6" ) {
            $navtelCmd = "configProxyServer -serverName $proxyName -ipv6AddrEnable 1 -ipv6Address $proxyIp -port $port";
        }
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
=for comment
sub configEPBlock {

    my ($obj,%args) = @_;
    my $sub = ".configEPBlock";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($key1,$key,$navtelCmd,$key3,$key2,$item,$blockName,$temp,$temp1);
    my (@arguments,@arguments1);
    my @verifyInputData  = qw/ groupName /;
	my %verifyOptionalData =  (
	                            'blockType' => {'gw'  =>  ['numOfGW','numOfEpPerGW'],
                                                    'ua'  =>  ['numOfUA']},
                             	    'stepType' =>  {'IP'   =>   ['stepIP','baseIPAddress'], 
						    'port' =>  ['stepPort','basePort']}
								);
     my %configEP;
     %configEP  =  %args;
    # validate Input data
    foreach $key (keys %configEP){
        foreach $key1 ( @verifyInputData ) {
            unless ( defined ( $configEP{$key}{$key1} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for \'$key1\' has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
    }
    foreach $key (keys %configEP){
        foreach $key1 (keys %verifyOptionalData) {
	    if (defined ($configEP{$key}{$key1})){
	        foreach $key2 (keys %{$verifyOptionalData{$key1}}){
	            if (defined $configEP{$key}{$key1}{$key2}){
	                foreach $key3 (@{$verifyOptionalData{$key1}{$key2}}){
	                    unless ( defined ( $configEP{$key}{$key1}{$key3} ) ) {
                                $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
                                $logger->debug(" <-- Leaving Sub [0]");
                                return 0;
	                     }else{
			        $temp1 = "-$key3 $configEP{$key}{$key1}{$key3}";
				push @arguments1 , $temp1;
		             }
			}
                         unshift (@arguments1,("-$key1",$key2));
                         $temp = join(' ',@arguments1);
                         push @arguments , $temp;
                         @arguments1=();
                    }
                }					
            }
        }
	
####execution of the command accourding to the values provided

#####getting the block name from the profile
        my $groupName = $configEP{$key}{groupName};
         $logger->debug("  groupName = $groupName"); 
        $navtelCmd = "getAllEPBlocks $groupName";
	unless ($blockName=$obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
	    my $errMsg = "  FAILED - to execute $navtelCmd command ";
        $logger->error($errMsg);
        return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command and block name = $blockName");
        }
	    
	$navtelCmd="configEPBlock -group $groupName -blockName $blockName";
	
        foreach (@arguments){
            $navtelCmd = "$navtelCmd $_"
	}
		
        unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>120) ) {
            my $errMsg = "  FAILED - to execute $navtelCmd command ";
            $logger->error($errMsg);
            return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command '");
        }
    @arguments=();
    }
  
return 1;

}#End of configEPBlock
=cut

=head2 C< configEPBlock >

=over

=item DESCRIPTION:

	helps to config the EP block

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->configEPBlock(%args);

=back

=cut

sub configEPBlock {

    my ($obj,%args) = @_;
    my $sub = ".configEPBlock";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($key1,$key2,$key,$navtelCmd,$argument,$blockName);
    my @blockName1;
    my @verifyInputData  = qw/ -group /;
    my %configEP  = %{ $args{'-configEP'} };
    my @array2 = qw/ -groupName -baseIPAddr32bit -stepIP -stepPort -basePort -numOfUA -numOfGW -numOfEpPerGW /;
    
    $obj->execCliCmd('-cmd' =>"hideGUI", '-timeout' =>180);

    # validate Input data
    foreach $key (keys %configEP){
        foreach ( @verifyInputData ) {
            unless ( defined ( $configEP{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
    unless ( defined ( $configEP{$key}{-blockName})){
        $navtelCmd = "getAllEPBlocks $configEP{$key}{-group}";
        $logger->debug("  SUCCESS - the Navtel Cmd  $navtelCmd ");
        @blockName1=$obj->execCmd('-cmd' =>$navtelCmd, '-timeout' =>120);
        ($blockName)=@blockName1; 
        $logger->debug("  SUCCESS - executed $navtelCmd  command and block name = $blockName");
    }else{
        $blockName=$configEP{$key}{-blockName};
    }
    $navtelCmd="configEPBlock -group $configEP{$key}{-group} -blockName $blockName";
     
    foreach $key1 (keys %{$configEP{$key}}){
    if ($key1 eq "-blockType"){
        if($configEP{$key}{'-blockType'} eq "gw"){
	    $argument='';
	    $logger->debug(" SUCCESS -  block type is gateway");		    
	    my @verifyOptionalData1 = qw/ -numOfGW -numOfEpPerGW /;
            foreach $key2 (@verifyOptionalData1){
                unless ( defined ( $configEP{$key}{$key2})){
	            $logger->error("  ERROR: The mandatory argument for $key2 has not been specified.");
	            return 0;
	        }else{
	            $argument = "$argument $key2 $configEP{$key}{$key2}"
	        }
            }
            $navtelCmd= "$navtelCmd -blockType gw $argument";
        }
        elsif ($configEP{$key}{'-blockType'} eq "ua"){
            $argument='';		
            $logger->debug(" SUCCESS -  block type is user agent");	
            unless ( defined ( $configEP{$key}{'-numOfUA'})){
                $logger->error("  ERROR: The mandatory argument for numOfUA has not been specified.");
		return 0;
            }else{ 
                $argument = "$argument -numOfUA $configEP{$key}{-numOfUA}"
	    }
            $navtelCmd= "$navtelCmd -blockType ua $argument";
        }
    }		
				    
    elsif ($key1 eq "-stepType"){
        if($configEP{$key}{'-stepType'} eq "IP"){
	    $argument='';
	    $logger->debug(" SUCCESS -  step type is IP");		    
	    my @verifyOptionalData1 = qw/ -stepIP -ipStepUnit -baseIPAddr32bit /;
               foreach $key2 (@verifyOptionalData1){
                unless ( defined ( $configEP{$key}{$key2})){
	             $logger->debug("  INFO: The argument for $key2 has not been specified.");
                }else{ 
	             $argument = "$argument $key2 $configEP{$key}{$key2}"
	        }
            }
            $navtelCmd= "$navtelCmd -stepType IP $argument";
        }
        elsif ($configEP{$key}{'-stepType'} eq "port"){
	    $argument='';
            $logger->debug(" SUCCESS -  step type is port");		    
	    my @verifyOptionalData1 = qw/ -stepPort -basePort /;
            foreach $key2 (@verifyOptionalData1){
	       unless ( defined ( $configEP{$key}{$key2})){
		    $logger->debug("  ERROR: The  argument for $key2 has not been specified.");
	       }else{
		    $argument = "$argument $key2 $configEP{$key}{$key2}";
               }
            }
            $navtelCmd= "$navtelCmd -stepType port $argument";	  
        }   
    }
    
    elsif ($key1 eq "-vlanEnable"){
         if($configEP{$key}{'-vlanEnable'} eq "1"){
            $argument='';
            $logger->debug(" SUCCESS - vlan is eabled");
            my @verifyOptionalData1 = qw/ -vlanPriority -vlanID /;
               foreach $key2 (@verifyOptionalData1){
                  unless ( defined ( $configEP{$key}{$key2})){
                     $logger->debug("  INFO: The argument for $key2 has not been specified.");
                  }else{
                     $argument = "$argument $key2 $configEP{$key}{$key2}";
                  }
              }
              unless ( defined ( $configEP{$key}{-vlanStepEnable})){
                  $logger->debug("  INFO: The argument for -vlanStepEnable has not been specified.");
              }else{
                  $argument = "$argument -vlanStepEnable $configEP{$key}{-vlanStepEnable}";
                  if ( $configEP{$key}{-vlanStepEnable} eq "1"){
                      @verifyOptionalData1 = qw/ -vlanStepSize -vlanMaxID /;
                      foreach $key2 (@verifyOptionalData1){
                         unless ( defined ( $configEP{$key}{$key2})){
                             $logger->debug("  INFO: The argument for $key2 has not been specified.");
                         }else{
                             $argument = "$argument $key2 $configEP{$key}{$key2}"
                         }
                     }
                 }
            }
            $navtelCmd= "$navtelCmd -vlanEnable $argument";
        }
        elsif ($configEP{$key}{'-vlanEnable'} eq "0"){
            $logger->debug(" SUCCESS -  vlan is not enabled");
            $navtelCmd= "$navtelCmd -vlanEnable 0";
        }
    }

    elsif (grep(/$key1/,@array2)){
        $navtelCmd ="$navtelCmd";
    }else{
        $navtelCmd = "$navtelCmd $key1 $configEP{$key}{$key1}";
    }
} 

    unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute $navtelCmd command ";
        $logger->error($errMsg);
        return 0;
    }else {
        $logger->debug("  SUCCESS - executed $navtelCmd command ");
    }
 } 
return 1;

}#End of configEPBlock	     

=head2 C< configGlobalParameters >

=over

=item DESCRIPTION:

	helps to configure the global parameters in NAVTEL.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->configGlobalParameters(%args);

=back

=cut

sub configGlobalParameters {

    my ($obj,%args) = @_;
    my $sub = ".configGlobalParameters";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($key1,$key2,$key,$navtelCmd,$argument);
    my @verifyInputData  = qw/ -group /;

    my %configGlobal  = %{ $args{'-configGlobal'} };
    my @array2 = qw/ -securityEnable -securityProtocol -defaultGW -defaultGWAddr -group -unsolicitedAdEnable -EUI64FormatEnable -prefix -prefixLength -gratuitousARPEnable -subnetMask -ToSDiffServ -IPVersion /;
    # validate Input data
    foreach $key (keys %configGlobal){
        foreach ( @verifyInputData ) {
            unless ( defined ( $configGlobal{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for $key has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
   
    $navtelCmd="configGlobalParameters -group $configGlobal{$key}{-group}";

    foreach $key1 (keys %{$configGlobal{$key}}){
	

    if ($key1 eq "-IPVersion"){
        if($configGlobal{$key}{'-IPVersion'} eq "IPv4"){
            $argument='';
            $logger->debug(" SUCCESS - IPVersion is IPv4");
            my @verifyOptionalData1 = qw/ -gratuitousARPEnable -subnetMask -ToSDiffServ /;
            foreach $key2 (@verifyOptionalData1){
                if ( defined ( $configGlobal{$key}{$key2})){
                    $argument = "$argument $key2 $configGlobal{$key}{$key2}";
                }else{
                    $logger->debug("  $key2 has not been specified");
                }
            }
            $navtelCmd= "$navtelCmd -IPVersion IPv4 $argument";
        }
        elsif ($configGlobal{$key}{'-IPVersion'} eq "IPv6"){
            $argument='';
            $logger->debug(" SUCCESS - IPVersion is IPv6");
            my @verifyOptionalData1 = qw/ -unsolicitedAdEnable -EUI64FormatEnable -prefix -prefixLength /;
            foreach $key2 (@verifyOptionalData1){
                if ( defined ( $configGlobal{$key}{$key2})){
                    $argument = "$argument $key2 $configGlobal{$key}{$key2}";
                }else{
                    $logger->debug("  $key2 has not been specified");
                }
            }
            $navtelCmd= "$navtelCmd -IPVersion IPv6 $argument";
        }
    }
	elsif ($key1 eq "-securityEnable"){
        if($configGlobal{$key}{'-securityEnable'} eq "1"){
           $argument='';
	   $logger->debug(" SUCCESS -  EP Security is enabled");		    
	   unless ( defined ( $configGlobal{$key}{'-securityProtocol'})){
               $logger->error("  ERROR: The mandatory argument for Security has not been specified.");
	       return 0;
	    }else{
	       $argument = "$argument -securityProtocol $configGlobal{$key}{-securityProtocol}";
	    }
            $navtelCmd= "$navtelCmd -securityEnable 1 $argument";
        }
        elsif ($configGlobal{$key}{'-securityEnable'} eq "0"){
            $logger->debug(" SUCCESS -  security is disabled");
            $navtelCmd= "$navtelCmd -securityEnable 0";	
        }
    }
     elsif ($key1 eq "-defaultGW"){
        if($configGlobal{$key}{'-defaultGW'} eq "Global"){
            $argument='';
            $logger->debug(" SUCCESS -  default gateway type is Global");
            unless ( defined ( $configGlobal{$key}{'-defaultGWAddr'})){
               $logger->error("  ERROR: The mandatory argument for defaultGWAddr has not been specified.");
               return 0;
            }else{
               $argument = "$argument -defaultGWAddr $configGlobal{$key}{-defaultGWAddr}";
            }
            $navtelCmd= "$navtelCmd -defaultGW $configGlobal{$key}{'-defaultGW'} $argument";
        }
        elsif (($configGlobal{$key}{'-defaultGW'} eq "None") or($configGlobal{$key}{'-defaultGW'} eq "EPDefined")){
            $logger->debug(" SUCCESS -  default gateway type is None or EPDefined");
            $navtelCmd= "$navtelCmd -defaultGW $configGlobal{$key}{'-defaultGW'}";
        }
    }

    elsif (grep(/$key1/,@array2)){
        $navtelCmd ="$navtelCmd";
    }else{
        $navtelCmd = "$navtelCmd $key1 $configGlobal{$key}{$key1}"; 
    } 

}


    unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>180) ) {
        my $errMsg = "  FAILED - to execute $navtelCmd command ";
        $logger->error($errMsg);
        return 0;
          }else {
        $logger->debug("  SUCCESS - executed $navtelCmd  command ");
    }
 }
return 1;

}#End of configGlobalParameters

=head2 C< configEPMapping >

=over

=item DESCRIPTION:

	helps to execute the configEPMapping cmds in the NAVTEL.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->configEPMapping(%args);

=back

=cut

sub configEPMapping {

    my ($obj,%args) = @_;
    my $sub = ".configEPMapping";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($key1,$key2,$key,$navtelCmd,$argument);
    my @verifyInputData  = qw/ -group /;

    my %EPMapping =  %{ $args{'-EPMapping'} };
    my @array2 = qw/ -initiateFromAllEndpoints -localSelection -localBlockCallingList -endpointMappingMode -remote1Selection -remote1SelectedBlockList -remote2Selection -remote2SelectedBlockList -presentitiesSelection -presentitiesPerWatcher -overlapsPerWatcher -presentitiesSelectedBlockList /; 
    # validate Input data
    foreach $key (keys %EPMapping){
        foreach ( @verifyInputData ) {
            unless ( defined ( $EPMapping{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for $key has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
        $navtelCmd = "configEPMapping -group $EPMapping{$key}{-group}";
        my $argument = '';
        foreach $key2 (@array2){
            if (defined ( $EPMapping{$key}{$key2})){
                $argument="$argument $key2 $EPMapping{$key}{$key2}";
            }
        }
        $navtelCmd ="$navtelCmd $argument";
        unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>180) ) {
            my $errMsg = "  FAILED - to execute $navtelCmd command ";
            $logger->error($errMsg);
            return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command ");
        }
     }
return 1;

}#End of configEPMapping

=head2 C< configHardwareSelection >

=over

=item DESCRIPTION:

	helps to execute 'configHardwareSelection' cmd in NAVTEL.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->configHardwareSelection(%args);

=back

=cut

sub configHardwareSelection {
    my ($obj,%args) = @_;
    my $sub = ".configHardwareSelection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . "$sub ==> Entered");

    my ($key1,$key2,$key,$navtelCmd,$argument);
    my @verifyInputData  = qw/ -group /;
    my @verifyOptionalInputData = qw/ -interfaceCardPort -protocolEngine /;
    my %HardwareSelection =  %{ $args{'-HardwareSelection'} };
    foreach $key (keys %HardwareSelection){
        foreach ( @verifyInputData ) {
            unless ( defined ( $HardwareSelection{$key}{$_} ) ) {
               $logger->error("  ERROR: The mandatory Stats DATA argument for $key has not been specified.");
               $logger->debug(" <-- Leaving Sub [0]");
               return 0;
            }
        }
        $navtelCmd = "configHardwareSelection -group $HardwareSelection{$key}{-group}";
        my $argument ='';
        foreach $key2 (@verifyOptionalInputData){
            if(defined ($HardwareSelection{$key}{$key2})){
                $argument = "$argument $key2 {$HardwareSelection{$key}{$key2}}";
            }
        }
        $navtelCmd ="$navtelCmd $argument";
        unless ($obj->execCliCmd('-cmd' =>$navtelCmd, '-timeout' =>180) ) {
            my $errMsg = "  FAILED - to execute $navtelCmd command ";
            $logger->error($errMsg);
            return 0;
        }else {
            $logger->debug("  SUCCESS - executed $navtelCmd  command ");
        }
     }
return 1;

}#End of configHardwareSelection

=head2 C< moveEsxLogs >

=over

=item DESCRIPTION:

 This subroutine checks for csv file containing esxtop data and moves it to the specified location

=item Arguments :

   The mandatory parameters are
      -testCaseID   => Test case ID
      -copyLocation => destination for copying the file

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

   0  : failed to copy the file
   1  : file copied successfully

=item Example :

   $esxObj->moveEsxLogs(-testCaseID => $testId, -copyLocation=> $location);

=back

=cut

sub moveEsxLogs {

    my ($self,$testCaseId,$copyLocation,$hostName) = @_ ;
    my $sub_name = "moveESXLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my @cmd_res = ();

    my ($basePath,$nodeName,$ip,$dstPath,$srcPath,$password,$fileName);
    my $hostname = lc($hostName);

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ .  ".$sub_name: --> $copyLocation");

    my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
    $basePath = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    $nodeName = lc($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});
    $ip = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{$ip_type};
    $password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    $fileName = "$testCaseId-$nodeName.csv";

    $logger->debug(__PACKAGE__ . ".$sub_name: Hypervisor base path $basePath");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);

   unless ($self->{SCP}) {
        unless ($self->{SCP} = SonusQA::SCPATS->new(host => $ip, user => 'root', password => $password, timeout => 180)){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
   }

   $srcPath = "$basePath/$fileName" ;
   $dstPath = "$copyLocation$hostname/ESX_DATA";
   $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");

   unless( $self->{SCP}->scp( $ip . ':' ."$srcPath", $dstPath)){
       $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the  file");
       return 0;
   } else {
         $logger->debug( "SUCCESS . .$sub_name: successfully moved log form $srcPath to $dstPath");
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;
}#End of moveEsxLogs

=head2 C< collectPktartStats >

=over

=item DESCRIPTION:

 This sub routne will copy the PKTART Client and Server Stats to the Logs path created for the test case.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::PERFHELPER.pm

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  &collectPktartStats($C_Obj,$S_Obj,$folder,$copy_loaction,$nodename,$pktart_no);

=back

=cut


sub collectPktartStats {

    my $sub_name = "collectPktartStats";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

	my ($C_Obj,$S_Obj,$folder,$copy_loaction,$nodename,$pktart_no) = @_;
	my $C_source	      =  $C_Obj->{TMS_ALIAS_DATA}->{'NODE'}->{2}->{EXECPATH};
	my $S_source	      =  $S_Obj->{TMS_ALIAS_DATA}->{'NODE'}->{2}->{EXECPATH};
	my $C_source_location =  "$C_source/$folder";
	my $S_source_location =  "$S_source/$folder";
	
        my $ip_type           =  ($C_Obj->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
        my $C_ip	      =  $C_Obj->{TMS_ALIAS_DATA}->{'NODE'}->{1}->{$ip_type};
	my $C_user	      =  $C_Obj->{TMS_ALIAS_DATA}->{'LOGIN'}->{1}->{USERID};
	my $C_passwd	      =  $C_Obj->{TMS_ALIAS_DATA}->{'LOGIN'}->{1}->{PASSWD};

        $ip_type              =  ($S_Obj->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
	my $S_ip	      =  $S_Obj->{TMS_ALIAS_DATA}->{'NODE'}->{1}->{$ip_type};
	my $S_user            =  $S_Obj->{TMS_ALIAS_DATA}->{'LOGIN'}->{1}->{USERID};
        my $S_passwd          =  $S_Obj->{TMS_ALIAS_DATA}->{'LOGIN'}->{1}->{PASSWD};
	my $hostactive = lc($nodename);
	my $C_dest_location   = "$copy_loaction$hostactive/PKTART_DATA/CLIENT/";
	my $S_dest_location   = "$copy_loaction$hostactive/PKTART_DATA/SERVER/";
	
	$C_Obj->execCmd("cd $C_source_location");
	$S_Obj->execCmd("cd $S_source_location");

	my @C_file_count = $C_Obj->execCmd("ls -l | grep -v ^total | cut -d ':' -f 2 | cut -d ' ' -f 2"); 
	my @S_file_count = $S_Obj->execCmd("ls -l | grep -v ^total | cut -d ':' -f 2 | cut -d ' ' -f 2");

	chomp(@C_file_count);
	chomp(@S_file_count);

   unless ($C_Obj->{SCP}) {
        unless ($self->{SCP} = SonusQA::SCPATS->new(host => $C_ip, user => $C_user, password => $C_passwd, port => 22, timeout => 180)){
           $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection to PKTART Client");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           return 0;
        }
   }
   foreach my $file (@C_file_count) {
       my $srcPath = "$C_source_location/$file" ;
       my $dstPath = $C_dest_location.$pktart_no."_".$file;
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $C_Obj->{SCP}->scp( "$C_ip:$srcPath",$dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the file from PKTART Client");
           return 0;
       }	
   }

   unless ($S_Obj->{SCP}) {
        unless ($self->{SCP} = SonusQA::SCPATS->new(host => $S_ip, user => $S_user, password => $S_passwd, port => 22, timeout => 180)){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to make scp connection to PKTART Server");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        } 
   }
   foreach my $file (@S_file_count) {
       my $srcPath = "$S_source_location/$file" ;
       my $dstPath = $S_dest_location.$pktart_no."_".$file;
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $srcPath to $dstPath");
       unless( $S_Obj->{SCP}->scp("$S_ip:$srcPath",$dstPath)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the file from PKTART Server");
           return 0;
       }
   }
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
   return 1;

}

=head2 C< configSbxPerf >

=over

=item DESCRIPTION:

        This subroutine configures the the interfaces for performance testing.

=item ARGUMENTS:

 Mandatory :

        $parameterHash                  =       hash of parameters need to configure the interfaces for performance testing

 Optional:
    none

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

        SonusQA::SBX5000::SBX5000HELPER::configureIpInterfaceV6()
        SonusQA::SBX5000::SBX5000HELPER::configureIpInterfaceV6()
        SonusQA::SBX5000::SBX5000HELPER::configureSipSigPortSBCV6()
        SonusQA::SBX5000::SBX5000HELPER::configureSipTrunkGroup()
        SonusQA::SBX5000::SBX5000HELPER::configureStaticRoute()
        SonusQA::SBX5000::SBX5000HELPER::configureAltMedia()

=item OUTPUT:

    1

=item EXAMPLES:

    configSbxPerf($sbxObj, %parameterHash);

    Refer JIRA 8949 for %parameterHash example/structure

=back

=cut

sub configSbxPerf {
        my($self,%parameterHash)=@_;
        my $sub_name = "configSbxPerf";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
       my $return_flag = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

                foreach my $addContext ( keys %parameterHash ){
                        foreach my $interfaceGroupName (keys %{$parameterHash{$addContext}}){
                                foreach my $portName (keys %{$parameterHash{$addContext}{$interfaceGroupName}}){
                                       $logger->info(__PACKAGE__ . ".$sub_name: Configuring for address context $addContext, inteface group $interfaceGroupName and port $portName.");
                                        my $arrayLength = @{$parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}};
                                        foreach my $i (0..$arrayLength-1){
                                               $logger->info(__PACKAGE__ . ".$sub_name: configureIpInterfaceV6 for IP Interface $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}[$i]");
                                                unless ($self->configureIpInterfaceV6($addContext, $interfaceGroupName, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}[$i], $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}, $portName, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipAddress}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{prefix}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{altIpAddress}[$i],$parameterHash{$addContext}{$interfaceGroupName}{$portName}{altPrefix}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{vlanTag}[$i])){
                                                       $logger->info(__PACKAGE__ . ".$sub_name: configureIpInterfaceV6 for IP Interface $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}[$i] Failed.");
                                                       $return_flag = 0;
                                                       last;
                                               }
                                                my $sipSigArrayLength = @{$parameterHash{$addContext}{$interfaceGroupName}{$portName}{sigport}[$i]};
                                                foreach my $j (0..$sipSigArrayLength-1){
                                                        $logger->info(__PACKAGE__ . ".$sub_name: configureSipSigPortSBCV6 for Sip Sig Port V6 $parameterHash{$addContext}{$interfaceGroupName}{$portName}{sigport}[$i][$j]");
                                                       unless ($self->configureSipSigPortSBCV6($addContext, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{sigport}[$i][$j], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{zone}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{zoneid}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{SigIp}[$i][$j], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{SigPort}[$i][$j], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{SigIp_V6}[$i][$j], $interfaceGroupName, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{allowedProtocols}[$i][$j])){
                                                               $logger->info(__PACKAGE__ . ".$sub_name: configureSipSigPortSBCV6 for Sip Sig Port V6 $parameterHash{$addContext}{$interfaceGroupName}{$portName}{sigport}[$i][$j] Failed.");
                                                               $return_flag = 0;
                                                               last;
                                                       }
                                                }
                                                my $sipTrunkArrayLength = @{$parameterHash{$addContext}{$interfaceGroupName}{$portName}{trunkgp}[$i]};
                                                foreach my $j (0..$sipTrunkArrayLength-1){
                                                       $logger->info(__PACKAGE__ . ".$sub_name: configureSipTrunkGroup for each trunk group");
                                                        unless ($self->configureSipTrunkGroup($addContext, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{trunkgp}[$i][$j], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{zone}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{zoneid}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{IngressIp}[$i][$j], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{IngressIpPrefix}[$i][$j], $interfaceGroupName)){
                                                               $logger->info(__PACKAGE__ . ".$sub_name: configureSipSigPortSBCV6 for trunk group $parameterHash{$addContext}{$interfaceGroupName}{$portName}{trunkgp}[$i][$j] Failed.");
                                                               $return_flag = 0;
                                                               last;
                                                       }
                                                }
                                               $logger->info(__PACKAGE__ . ".$sub_name: configureStaticRoute for Static route IP $parameterHash{$addContext}{$interfaceGroupName}{$portName}{remoteIp}[$i]");
                                                unless ($self->configureStaticRoute($addContext, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{remoteIp}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{remoteIPprefix}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{nextHop}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{preference}[$i], $interfaceGroupName)){
                                                       $logger->info(__PACKAGE__ . ".$sub_name: configureStaticRoute for Static route IP $parameterHash{$addContext}{$interfaceGroupName}{$portName}{remoteIp}[$i] Failed.");
                                                       $return_flag = 0;
                                                        last;
                                               }
                                                my $altArrayLength = @{$parameterHash{$addContext}{$interfaceGroupName}{$portName}{altMediaIp}[$i]};
                                                foreach my $j (0..$altArrayLength-1){
                                                       $logger->info(__PACKAGE__ . ".$sub_name: configureAltMedia for alternate media IP  $parameterHash{$addContext}{$interfaceGroupName}{$portName}{altMediaIp}[$i][$j]");
                                                        unless ($self->configureAltMedia($addContext, $interfaceGroupName, $parameterHash{$addContext}{$interfaceGroupName}{$portName}{ipInterface}[$i], $parameterHash{$addContext}{$interfaceGroupName}{$portName}{altMediaIp}[$i][$j])){
                                                               $logger->info(__PACKAGE__ . ".$sub_name: configureAltMedia for alternate media IP $parameterHash{$addContext}{$interfaceGroupName}{$portName}{altMediaIp}[$i][$j] Failed.");
                                                               $return_flag = 0;
                                                               last;
                                                       }
                                                }
                                        }
					last unless($return_flag);
                                }
				last unless($return_flag);
                        }
			last unless($return_flag);
                }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$return_flag]");
        return $return_flag;
}

1;

