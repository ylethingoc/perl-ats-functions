package SonusQA::PSX;

=pod

=head1 NAME

SonusQA::PSX- Perl module for PSX UNix side interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   my $obj = SonusQA::PSX->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH|SFTP|FTP>",
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for the PSX Unix side.
   It provides methods for both postive and negative testing, most cli methods returning true or false (0|1).
   Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, 
   allowing the engineer to specific which attributes to use.  Complete examples are given for each method.

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;
use SonusQA::PSX::CMD_LOOKUP;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase SonusQA::PSX::PSXHELPER);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%\}\|\>\]#]\s*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  $self->{SSBIN} = "/export/home/ssuser/SOFTSWITCH/BIN";
  $self->{PLATFORM} = '';

  $self->{sftp_session} = undef;
  $self->{POST_9_0} = 0;
  $self->{coreDirPath} = '/export/home/core';            #TOOLS - 14462
}

sub setSystem(){
  my($self)=@_;
  my $sub = "setSystem";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results, @version_info,@cmdResults);

  @results = $self->execCmd('ls /export/home/ssuser/SOFTSWITCH/BIN/OPENSTACK /var/log/metadata-psx.log /var/log/register-psx.log');#TOOLS-18542

  $main::TESTBED{CLOUD_PSX}{lc($self->{TMS_ALIAS_NAME})} = $self->{CLOUD_PSX} = (grep /No such file or directory/, @results) ? 0 : 1;
#TOOLS-17912 - START
  @results = $self->execCmd('rpm -qa SONSss');
  $results[0] =~ /(V[\d\.]+)\-([\w|\d]+)/g;
  $self->{VERSION} = $1.$2; #TOOLS-18580
  $self->{SU_CMD} = 'sudo -i -u ' if($self->{CLOUD_PSX} and SonusQA::Utils::greaterThanVersion( $self->{VERSION},'V11.01.00' )); #TOOLS-18541

  if( exists $self->{TMS_ALIAS_DATA} && $self->{OBJ_USER} eq 'admin' && $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} && $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}){ #TOOLS-18810
    unless($self->becomeUser(-password => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} ,-userName => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID})){
              $logger->debug(__PACKAGE__ . ".setSystem: unable to enter as $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ");
              return 0;
    }

  $self->{OBJ_USER} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} if($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID});#TOOLS-18820
  $self->{OBJ_PASSWORD} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} if($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD});
}

  #TOOLS-71195
  if ($self->{OBJ_KEY_FILE}) {
        $logger->debug(__PACKAGE__ . ".$sub: storing keys for ".$self->{OBJ_HOST}." and user $self->{OBJ_USER}");   #TOOLS - 13882
        $SSH_KEYS{$self->{OBJ_HOST}}{$self->{OBJ_USER}} = $self->{OBJ_KEY_FILE};
   }
  $self->execCmd("export PATH=\$PATH:$self->{SSBIN}");
#TOOLS-17912 - END

  # Set some more defaults for commonly used utilities
  $self->{STARTSS} = "$self->{SSBIN}/start.ssoftswitch";
  $self->{STOPSS} = "$self->{SSBIN}/stop.ssoftswitch";
  $self->{THREADSPERCORE} = 0;
  $self->{CORESPERSOCKET} = 0;
  $self->{NUMOFSOCKETS} = 0;
  $self->{HYPERVISOR} = "BAREMETAL"; #By default we assume the hardware is BareMetal
  $self->{NUMOFCORES} = 0;
  $self->{CPUMODEL} = '';

  #Setting the Platform type 
  my @platform = $self->{conn}->cmd('uname');
  $self->{PLATFORM} =  ($platform[0] =~ /Linux/i) ? 'linux' : 'SunOS';


 #Read lscpu&/proc/cpuinfo for threads,Socket,cores,Hypervisor & CPU model  details
 my @r = ();
 if ($self->{PLATFORM} eq 'linux' ) {
     unless ( @r =  $self->{conn}->cmd('lscpu') ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed for \"lscpu \", data maybe incomplete, result: " . Dumper(\@r));
     }

     chomp @r;
     foreach my $line (@r) {
         $self->{THREADSPERCORE} = $1 if ($line =~ m/Thread\(s\)\s+per\s+core\s*:\s+(\d+)/i);
         $self->{CORESPERSOCKET} = $1 if ($line =~ m/Core\(s\)\s+per\s+socket\s*:\s+(\d+)/i);
         $self->{NUMOFSOCKETS} = $1 if ($line =~ m/Socket\(s\)\s*:\s+(\d+)/i);
         $self->{HYPERVISOR} = $1 if ($line =~ m/Hypervisor\s+vendor\s*:\s+([a-zA-Z]+)/i);
     }
      
     unless ( @r =  $self->{conn}->cmd('cat /proc/cpuinfo') ) {
         $logger->error(__PACKAGE__ . "$sub Remote command \"cat /proc/cpuinfo \" execution failed, data maybe incomplete, result: " . Dumper(\@r));
     }
     
     chomp @r;
     foreach my $line (@r) {
         $self->{NUMOFCORES} = $1 if ($line =~ m/processor\s+:\s+(\d+)/i);
         $self->{CPUMODEL} = $1 if ($line =~ m/model\s+name\s*:\s+.*\s+CPU\s+([a-zA-Z0-9\-_\s]+)/i);
	 $self->{CPUMODEL} =  $1 if ( ( $line =~ m/model\s+name\s*:\s+.*[CPU]*\s+([a-zA-Z0-9]+[\-_\s]*)\s.+/i)  && ( $self->{HYPERVISOR} eq 'KVM'));
     }
     $self->{NUMOFCORES}++; # /proc/cpuinfo is zero-based.
  } else {
        unless ( @r =  $self->{conn}->cmd('uname -i') ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed for \"uname -i \", data maybe incomplete, result: " . Dumper(\@r));
     }
      chomp @r;
      $self->{CPUMODEL} = $1 if ($r[0] =~ m/.*,(.*)/i);
  }


  if ($self->{OBJ_USER} =~ /ssuser/i) {
     unless (@version_info = $self->{conn}->cmd('pes -v')) {
        $logger->error(__PACKAGE__ . ".$sub CMD: \'pes -v\' failed");
     } else {
        chomp @version_info;
        $self->{VERSION} = $version_info[0];
        if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
            $main::TESTSUITE->{DUT_VERSIONS}->{"PSX,$self->{TMS_ALIAS_NAME}"} = $self->{VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"PSX,$self->{TMS_ALIAS_NAME}"});
        }
        if ($self->{VERSION} =~ /^\w(\d+\.\d+)\./) {
            if ( $1 ge '09.00' ) {
               $self->{POST_9_0} = 1;
               $logger->debug(__PACKAGE__ . ".$sub PSX POST_9_0 flag is set");
            }
        }
     }
  }
 
  my @processes = qw (pes pgk sipe scpa slwresd ada);
  if ($self->{CLOUD_PSX} && SonusQA::Utils::versionRange([['V10.00.03R000','V11.02.00R000']]  ,$self->{VERSION})>0){
    $logger->info(__PACKAGE__ . ".$sub since it is a cloud psx ($self->{CLOUD_PSX}) and version is greater than 10.3, adding 'plm' to the process list");
    push(@processes, 'plm');
  }

  foreach (@processes) {
      $self->{conn}->cmd("cat \/export\/home\/ssuser\/SOFTSWITCH\/BIN\/svc.conf.$_ \| grep -iw \"$_-MGMT\" | grep \"\\-v 6\"");
      my @IPV4 = $self->{conn}->cmd("echo \$?");
      my $mgmt = ($_ eq 'pes') ?"ssmgmt" : $_.'mgmt';
      $self->{uc ($mgmt)} = ($IPV4[0])?"$self->{SSBIN}/$mgmt":"$self->{SSBIN}/$mgmt ::1";
 }
  $self->{LOGPATH} = "/export/home/ssuser/SOFTSWITCH/BIN";
  $self->{LOGPATH} .= "/logs" if (SonusQA::Utils::greaterThanVersion( $self->{VERSION}, 'V10.03.01' ));
  
  if(SonusQA::Utils::greaterThanVersion( $self->{VERSION}, 'V12.00.00')){
       $self->{coreDirPath} = '/home/core';
  }

  unless($self->{DO_NOT_TOUCH_SSHD}){ #TOOLS-18508
      unless ( $self->setClientAliveInterval() ) {
          $logger->error( __PACKAGE__ . " : Could not set ClientAliveinterval to 0." );
          $logger->info( __PACKAGE__ . ".setSystem: <-- Leaving sub [0]" );
          return 0;
      }
  }else{
      $logger->debug(__PACKAGE__ . ".setSystem: do_not_touch_sshd flag is set ");
  }

  $self->{conn}->cmd("TMOUT=72000");

  @cmdResults = $self->execCmd('grep ssconfigid /var/opt/sonus/ssScriptInputs | cut -d= -f2 |sed \'s/"//g\''); # TOOLS-17226 
  $self->{'ssmgr_config'} = $cmdResults[0] || 'DEFAULT';
  $main::TESTBED{'ssmgr_config'} ||= $self->{'ssmgr_config'};

  if($self->{PSX_ROLE} !~ /MASTER/ && exists $self->{TMS_ALIAS_DATA}->{MASTER} && exists $self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME}){ #TOOLS-12934 TOOLS-15665 #TOOLS-15967
      $self->{PSX_ROLE} = 'SLAVE';
      #Changes for TOOLS-12925
      if (exists $self->{TMS_ALIAS_DATA}->{SLAVE_CLOUD} && exists $self->{TMS_ALIAS_DATA}->{SLAVE_CLOUD}->{3}->{IPV6}  && $self->{TMS_ALIAS_DATA}->{SLAVE_CLOUD}->{3}->{IPV6}){$main::TESTBED{PSXCloudType} = 'SRV4';}   #determining if the Cloud PSX is an SRV4 PSX

      unless($self->{MASTER} = SonusQA::PSX->new(-tms_alias_data => $self->{TMS_ALIAS_DATA},
				      -tms_alias_name => $self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME},
				      -obj_hosts => $self->{TMS_ALIAS_DATA}->{MASTER_OBJHOSTS},
                                      -obj_user => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      -obj_key_file => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE},
                                      -sys_hostname => "$self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME}",
				      -do_not_delete => $self->{DO_NOT_DELETE},
                                      -sessionlog => 1,
                                      -psx_role => 'MASTER',
                                      -ROOTPASSWD => 'sonus'
                                                )){
	  $logger->error( __PACKAGE__ . ".setSystem: PSX master Obj creation Failed" );
          $vm_ctrl_obj{$self->{TMS_ALIAS_DATA}->{VM_CTRL}->{1}->{NAME}}->deleteInstance($self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME}); #TOOLS-12934
          $logger->info( __PACKAGE__ . ".setSystem: <-- Leaving sub [0]" );
          return 0;
      }
      $logger->debug(__PACKAGE__. ".setSystem: PSX master Obj creation is successful");
  }
  @{$main::TESTBED{$main::TESTBED{lc($self->{TMS_ALIAS_NAME})}.":hash"}->{UNAME}} = $self->execCmd('uname');
  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
  return 1;
}

=pod

=head2 SonusQA::PSX::execCmd()

  This routine is responsible for executing commands.  Commands can enter this routine via two methods:
    1. Via a straight call (if script is not using XML libraries, this would be the perferred method in this instance)
    2. Via an execFuncCall call, in which the XML libraries are used to generate a correctly sequence command.
  It performs some basic operations on the results set to attempt verification of an error.

=over

=item Arguments

  cmd <Scalar>
  A string of command parameters and values
  timeout <optional>
  timeout value in seconds
=item Returns

  Array
  This return will be an empty array if:
    1. The command executes successfully (no error statement is return)
    2. And potentially empty if the command times out (session is lost)

  The assumption is made, that if a command returns directly to the prompt, nothing has gone wrong.
  The GSX product done not return a 'success' message.

=item Example(s):

  &$obj->execCmd("SHOW INVENTORY SHELF 1 SUMMARY",120);

=back

=cut

sub execCmd {  
  my ($self,$cmd, $timeout)=@_;
  my($flag, $logger, @cmdResults,$timestamp,$prevBinMode,$lines,$last_prompt, $lastpos, $firstpos);
  $flag = 1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }

  $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub");
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  $self->{CMDRESULTS} = [];

  $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");
  $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command
  $timeout ||= $self->{DEFAULTTIMEOUT};
  
  my @cmd_results_master;
  if ($self->{CLOUD_PSX} and $self->{MASTER}) {
      my @type_arr = $self->cmdLookUp($cmd);                    #TOOLS - 13183
      if(grep (/MASTER/,@type_arr) ){
          @cmd_results_master = $self->{MASTER}->execCmd($cmd);
      }
      unless ( grep(/SLAVE/ , @type_arr)){
          return @cmd_results_master;
      }
  }
  my ($retries ,$reconnect);
  RETRY:
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $timeout )) {
    $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
    $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);

    #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
    $logger->debug(__PACKAGE__ . ".execCmd  Sending ctrl+c");
    unless($self->{conn}->cmd(-string => "\cC")){
        $logger->warn(__PACKAGE__ . ".execCmd  Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);

        #Reconnect in case ctrl+c fails.
        $logger->warn(__PACKAGE__ . ".execCmd  Trying to reconnect...");
        unless( $self->reconnect() ){
            $logger->warn(__PACKAGE__ . ".execCmd Failed to reconnect.");
           &error(__PACKAGE__ . ".execCmd CMD ERROR - EXITING");
        }
        $reconnect = 1;
    }
    else {
        $logger->info(__PACKAGE__ .".exexCmd Sent ctrl+c successfully.");
    }
    if (!$retries && ($self->{RETRYCMDFLAG} || $reconnect)) {
       $logger->info(__PACKAGE__ .".exexCmd retrying.");
       $retries = 1;
       goto RETRY;
    }
  };

  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults ;
  foreach(@cmdResults) {
    if(m/(Permission|Error)/i){
        if($self->{CMDERRORFLAG}){
          $logger->warn(__PACKAGE__ . ".execCmd  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
          &error("CMD FAILURE: $cmd");
        }
        $flag = 0;
        last;
    }
  }
  push (@cmdResults , @cmd_results_master);
  $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
  return @cmdResults;
}

=head2 startStopSoftSwitch()

DESCRIPTION:
 Items that will return true/false (1|0) by just calling execCmd

=cut

sub startStopSoftSwitch {
    my ($self, $bFlag)=@_;
    my (@cmdResults, $cmd,$logger);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startStopSoftSwitch");
    $cmd = ($bFlag) ? $self->{STARTSS} : $self->{STOPSS};  
    $logger->info(__PACKAGE__ . ".startStopSoftSwitch Sending cmd: $cmd");
    return $self->execCmd($cmd);
}

sub removeLog {
  my ($self, $logPath)=@_;
  my (@cmdResults, $cmd, $logger, $line, $bsize, $asize);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".removeLog");
  if(!defined($logPath)){
    $logger->warn(__PACKAGE__ . ".removeLog  PATH MISSING OR NOT DEFINED - REQUIRED");
    return 0;
  }
  if($self->_sessFileExtension($logPath) !~ /log$/i){
    $logger->warn(__PACKAGE__ . ".getLog  FILE ARGUMENT DOES NOT SEEM TO BE A LOG FILE - SKIPPING");
    return 0;    
  }

  # Fix for TOOLS-16756
  $logPath =~s/.+\/(.+\.log)$/$self->{LOGPATH}\/$1/;
  $logger->info(__PACKAGE__ . ".getLog Chainged the log path to '$logPath'");

  $bsize = $self->_sessFileExists($logPath);
  if(!defined($bsize)){
    $logger->warn(__PACKAGE__ . ".removeLog  $logPath DOES NOT SEEM TO EXIST");
    # means that there was no need for removal
    return 1;
  }
  if( $bsize ){
    $logger->info(__PACKAGE__ . ".removeLog  ISSUING RM FOR $logPath ");
    $self->{conn}->cmd("/bin/rm $logPath");
    $logger->info(__PACKAGE__ . ".removeLog  RE-TESTING FILE $logPath");
    $asize = $self->_sessFileExists($logPath);
    if(!defined($asize)){
      $logger->info(__PACKAGE__ . ".removeLog  $logPath DOES NOT SEEM TO EXIST - REMOVAL COMPLETE");
      # means that there was no need for removal
      return 1;
    }
    else{
      if($asize <= $bsize){
        $logger->info(__PACKAGE__ . ".removeLog  $logPath IS SAME SIZE AS BEFORE REMOVAL ATTEMPT");
        # means that there was no need for removal
        return 1;
      }
      else{
        $logger->warn(__PACKAGE__ . ".removeLog  $logPath EXISTS STILL");
        $logger->warn(__PACKAGE__ . ".removeLog  SIZE BEFORE REMOVAL: $bsize");
        $logger->warn(__PACKAGE__ . ".removeLog  SIZE AFTER REMOVAL: $asize");
        return 0;
      }
    }
  }
}

sub getLogSegment {
  my ($self, $startDemarc, $endDecmarc, $logArray)=@_;
  my (@log, @cmdResults, $lineCnt, $spos,$logger);
  @cmdResults = ();
  $spos = 0;
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getLogSegment");
  if(!defined($startDemarc)){
    $logger->warn(__PACKAGE__ . ".getLogSegment  START DEMARCATION NOT SUPPLIED - REQUIRED");
    return 0;
  }
  if(!defined($endDecmarc)){
    $logger->warn(__PACKAGE__ . ".getLogSegment  END DEMARCATION NOT SUPPLIED - REQUIRED");
    return 0;
  }
  if(!defined($logArray)){
    $logger->warn(__PACKAGE__ . ".getLogSegment  LOG NOT SUPPLIED - REQUIRED");
    return 0;
  }
  $lineCnt = 0;
  foreach my $line (@{$logArray}){
    chomp(@{$logArray}[$lineCnt]);
    if($line =~ m/($startDemarc)/){
      $spos = $lineCnt;
    }
    if($line =~ m/($endDecmarc)/){
      push(@cmdResults, [@{$logArray}[$spos .. $lineCnt]]);
      $spos = 0;
    }
    $lineCnt++; 
    
  }
  return @cmdResults;
}


sub getLog {
  my ($self, $logPath)=@_;
  my (@cmdResults, $cmd, $logger, $line, $bsize, $asize);
  @cmdResults = ();
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getLog");
  if(!defined($logPath)){
    $logger->warn(__PACKAGE__ . ".getLog  PATH MISSING OR NOT DEFINED - REQUIRED");
    return 0;
  }

  # Fix for TOOLS-16756
  $logPath =~s/.+\/(.+\.log)$/$self->{LOGPATH}\/$1/;
  $logger->info(__PACKAGE__ . ".getLog Chainged the log path to '$logPath'");

  # Removing this section -> there is no real reason for it, and it will allow this function to be
  # used to grab other files
  #if($self->_sessFileExtension($logPath) !~ /log$/i){
  #  $logger->warn(__PACKAGE__ . ".getLog  FILE ARGUMENT DOES NOT SEEM TO BE A LOG FILE - SKIPPING");
  #  return 0;    
  #}
  $bsize = $self->_sessFileExists($logPath);
  if(!defined($bsize)){
    $logger->warn(__PACKAGE__ . ".getLog  $logPath DOES NOT SEEM TO EXIST");
    # means that there was no need for removal
    return @cmdResults;
  }
  $logger->info(__PACKAGE__ . ".getLog  RETRIEVING FILE CONTENTS");
  my @log = $self->{conn}->cmd("/bin/cat $logPath");
  chomp(@log);
  return @log;
}


sub saveLog {
  my ($self, $tcid, $logPath)=@_;
  my (@cmdResults, $cmd, $logger, $line, $bsize, $asize, $psxVersion, $logName, $logType);
  @cmdResults = ();
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".saveLog");
  if(!defined($logPath)){
    $logger->warn(__PACKAGE__ . ".saveLog  PATH MISSING OR NOT DEFINED - REQUIRED");
    return 0;
  }
  if($self->_sessFileExtension($logPath) !~ /log$/i){
    $logger->warn(__PACKAGE__ . ".saveLog  FILE ARGUMENT DOES NOT SEEM TO BE A LOG FILE - SKIPPING");
    return 0;    
  }

  # Fix for TOOLS-16756
  $logPath =~s/.+\/(.+\.log)$/$self->{LOGPATH}\/$1/;
  $logger->info(__PACKAGE__ . ".getLog changed the log path to '$logPath'");

  $bsize = $self->_sessFileExists($logPath);
  if(!defined($bsize)){
    $logger->warn(__PACKAGE__ . ".saveLog  $logPath DOES NOT SEEM TO EXIST");
    # means that there was no need for removal
    return @cmdResults;
  }
  my @log = $self->{conn}->cmd("/bin/cat $logPath");
  chomp(@log);

  # Construct the local log name and save the log
  @cmdResults = $self->{conn}->cmd("pes -v");
  $psxVersion = $cmdResults[$#cmdResults];
  chomp($psxVersion);
  if ($logPath =~ m|.*\/(\w+).log|) { $logType = $1; }
  if ($tcid =~ m|(.*).pl|) { $tcid = $1; }
  $logName = ">" . "$tcid" . "_" . "$logType" . "_" . "$psxVersion" . ".log";
  if (open(FILEHANDLE, $logName)) {
    $logger->info(__PACKAGE__ . ".saveLog  SAVING FILE CONTENTS");  
    foreach(@log) { print FILEHANDLE "$_\n"; }
    close(FILEHANDLE);
    return 1;    
  }
  else {
    $logger->warn(__PACKAGE__ . ".saveLog  COULD NOT CREATE LOCAL LOG FILE");  
    return 0;
  }  
}

=head2 sipemgmtStats () 

DESCRIPTION:

 This subroutine will get the sipemgmt stats for the user passed numbers from the menu and return the results of those
 in an array.
 The menu is :
    ===================================================
                         Sonus SIP Engine Management Menu
                ===================================================
                1.       Trace Level DEBUG ON
                2.       Trace Level DEBUG OFF
                3.       Trace Level TRACE ON
                4.       Trace Level TRACE OFF
                5.       Hex Dump ON
                6.       Hex Dump OFF
                7.       Get Sipe Counters
                8.       Get Sipe Proxy Counters
                9.       Get Sipe Summary Counters
                10.      Get Sipe Misc Counters
                11.      Get All Sipe Counters
                12.      Reset Sipe counters
                13.      Reset Sipe Proxy Counters
                14.      Reset Sipe Summary Counters
                15.      Reset Sipe Misc Counters
                16.      Reset All Sipe Counters
                17.      Get Connection Summary
                18.      Get Connection Details
                19.      Get Connection History
                20.      Garbage Collection and Cleanup
                21.      Get SIPE DNS Counters
                22.      Reset SIPE DNS Counters
                23.      Reset SIPE DNS Timers
                24.      SCTP Test Options
                25.      Get Debug Counters
                26.      Get Congestion Info
                27.      Get Processing Stats
                28.      Reset Processing Stats
                29.      Set SIP Stack Log Level
                30.      Address Reachability Service Menu
                31.      Get Thread Details
                q.       Exit
                Enter Selection: 

=over

=item ARGUMENTS:

 Mandatory :
  -sequence     =>  ["11" , "2" , "5" ] . here you pass the numbers that you want to
                                          see the output for.
                      if ["30"] , then it will be assumed that you want to recover the blacklisted servers
                                   and the API will proceed accordingly.
=item PACKAGE:

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( @result = $psxObj->sipemgmtStats( -sequence => ["11" , "2" ] ,
					-clear_from_blacklist => { 
								ip =>port,
								ip => port
							}
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

unless ( @result = $psxObj->sipemgmtStats( -sequence => ["30-1-2" ] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }
unless ( @result = $psxObj->sipemgmtStats( -sequence => ["30-1-2-1" ] ,        =====>   Recover Blacklisted Servers with tranport selection ( default will be taken as 2 - UDP)
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

=back

=cut

sub sipemgmtStats {
    my ($self, %args )=@_;
    my %a;
    
    my $sub = "sipemgmtStats";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub" );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  
    my (@cmdResults, $cmd, @cmds, $prematch, $match, $prevPrompt , $enterSelPrompt , @results );
    $prevPrompt = $self->{conn}->prompt;
  
    @cmds = @{$a{-sequence}};
    $self->{conn}->print($self->{SIPEMGMT});
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter.+\:\s+/',                  #13489
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
    $logger->warn(__PACKAGE__ . ".$sub  UNABLE TO ENTER SIPEMGMT MENU SYSTEM");
    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
    return 0;
    };
    $prevPrompt = $self->{conn}->prompt;
    $self->{conn}->prompt('/Enter.+\:\s+/');          #13489
    
    my %clear_ip = %{$a{-clear_from_blacklist}} if($a{-clear_from_blacklist});
    if ( $cmds[0] eq "30-1-2" ) {
        $logger->info(__PACKAGE__ . ".$sub  Sequence Number 30-1-2 passed in argument. Will Check for Blacklisted Servers Now ");
        @cmdResults = $self->{conn}->cmd(30);
        push ( @results , @cmdResults );
        @cmdResults = $self->{conn}->cmd(1);
        push ( @results , @cmdResults );
        my ( %blacklistIpPorts , $blackListFlag , $key , $ipCnt);
        $ipCnt = "a";
        foreach ( @cmdResults ) {
            if ($self->{POST_9_0} ) {
                 if ( $_ =~ /\s+(\S+)\s+(\S+)\s+(\d+)/ ) {
                     $logger->info(__PACKAGE__ . ".$sub  POST_9_0 is set, so i will take care of Transport protocol");
                     $logger->info(__PACKAGE__ . ".$sub  BlackList : IP $1 with Port $3 with Transport $2 found to be blacklisted ");
                     $blacklistIpPorts{$1}{$3} = $2;
                     $blackListFlag = 1;
                 }
            } else {
                 if ( $_ =~ /\s+(\S+)\s+(\d+)/ ) {
                     $logger->info(__PACKAGE__ . ".$sub POST_9_0 is not set, so i wont take care of Transport protocol");
                     $logger->info(__PACKAGE__ . ".$sub BlackList : IP $1 with Port $2 found to be blacklisted ");
                     $blacklistIpPorts{$1}{$2} = 1;
                     $blackListFlag = 1;
                 }
            }
        }

        foreach $key ( keys %blacklistIpPorts ) {
            if ($a{-clear_from_blacklist}) {
                if (!defined $blacklistIpPorts{$key}{$clear_ip{$key}}) {
                     $logger->info(__PACKAGE__ . ".$sub: $key - " . $clear_ip{$key} . " doesnt match passed params - mismatch in ip and port");
                     next;
                }
            }

            foreach my $port (keys %{$blacklistIpPorts{$key}}) {
			
                $logger->info(__PACKAGE__ . ".$sub: Recover BlackListed Server : IP $key with Port $port");
                @cmdResults = $self->{conn}->cmd(30);
                push ( @results , @cmdResults );
                $self->{conn}->print(2);
                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Server IP Address to be recovered\:/',
                                                             -errmode => "return",
                                                             -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".$sub:  PROBLEM ENTERING IP Address to be recovered $key ");
                     $self->{conn}->cmd("\cC");
		     $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                     return 0;
                };
                push ( @results , $prematch );
                push ( @results , $match );
                $self->{conn}->print($key);
               ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Server Port Number\:/',
                                                            -errmode => "return",
                                                            -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".$sub  PROBLEM ENTERING Port Number ");
                     $self->{conn}->cmd("\cC");
  		     $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
                     return 0;
               };
               push ( @results , $prematch );
               push ( @results , $match );
               push ( @results , $port);
               unless ( $self->{POST_9_0} ) {
                     @cmdResults = $self->{conn}->cmd($port);
                     push ( @results , @cmdResults );
               } else {
                     $self->{conn}->print($port);
                     $logger->info(__PACKAGE__ . ".$sub POST_9_0 falg is set so i will take care Transport Selection");
                     ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Transport Selection\:/',
                                                                  -errmode => "return",
                                                                  -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".$sub  PROBLEM ENTERING Port Number ");
                     $self->{conn}->cmd("\cC");
    		     $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                     return 0;
                     };
                     push ( @results , $prematch );
                     push ( @results , $match );
                     $logger->info(__PACKAGE__ . ".$sub passing $blacklistIpPorts{$key}{$port} for Transport Selection");
                     my $transport = ( $blacklistIpPorts{$key}{$port} =~ /UDP/i) ? 2 : 1;
                     push ( @results , $transport);
                     @cmdResults = $self->{conn}->cmd($transport);
                     push ( @results , @cmdResults );
                     $logger->info(__PACKAGE__ . ".$sub BlackListed Server : IP $key with Port $port transport $blacklistIpPorts{$key}{$port} Recovered ");
               }
               $logger->info(__PACKAGE__ . ".$sub BlackListed Server : IP $key with Port $port Recovered ");
            }
        }
        unless ( $blackListFlag ) {
             $logger->info(__PACKAGE__ . ".$sub NO Blacklisted Servers Found !!!! ");
        }
    } else {
        foreach(@cmds){
            if ($_ =~ /.+/) {                         #TOOLS - 13489
                $logger->info(__PACKAGE__ . ".$sub SENDING SEQUENCE ITEM: [$_]");
                @cmdResults = $self->{conn}->cmd($_);
                push ( @results , @cmdResults );
            }
            else {
                $logger->warn(__PACKAGE__ . ".$sub  SEQUENCE HAS NO ITEM - SKIPPING");      #13489
            }     
        }
    }
    #$logger->debug(__PACKAGE__ . ".sipemgmtSequence PROMPT: " . $self->{conn}->prompt );
    
    $logger->debug(__PACKAGE__ . ".$sub SENDING q TO BREAK OUT OF SIPEMGMT");
    $self->{conn}->print("q");
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter.+\:\s+/',         #13489
                                                 -match => $prevPrompt,
                                                 -errmode => "return",
                                                 -timeout => 5) or do {
            $logger->debug(__PACKAGE__ . ".$sub PRE-MATCH:" . $prematch);
            $logger->debug(__PACKAGE__ . ".$sub MATCH: " . $match);
            $logger->debug(__PACKAGE__ . ".$sub LAST LINE:" . $self->{conn}->lastline);
    };
    
    # In case inside another menu . Come out of it by printing q
    if ( $match =~ /Enter.+\:\s+/ ) {         #13489
        $logger->debug(__PACKAGE__ . ".$sub SENDING 0 AGAIN TO BREAK OUT OF SIPEMGMT MAIN MENU");
        $self->{conn}->print("q");
    }
    
    # Set the previous prompt back
    $self->{conn}->prompt($prevPrompt);

    $self->{conn}->print("date");
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prevPrompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
        $logger->debug(__PACKAGE__ . ".$sub PRE-MATCH:" . $prematch);
        $logger->debug(__PACKAGE__ . ".$sub MATCH: " . $match);
        $logger->error(__PACKAGE__ . ".$sub  PROBLEM SETTING THE PROMPT TO $prevPrompt ");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    };
    
    $logger->debug(__PACKAGE__ . ".$sub: SUCCESS : The SIPE MGMT stats were found. Returning the stats in an array .");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return @results;
  
}
=head2 C< cmdLookUp >

=over

=item DESCRIPTION:

 This function will looks for the command in SonusQA::PSX::CMD_LOOKUP file and will finds out in which type(MASTER or SLAVE) the command can be run.

=item ARGUMENTS:

 $cmd - Command to be checked.

=iteSonusQA::PSX::CMD_LOOKUPe

=item PACKAGE:

 SonusQA::PSX

=item GLOBAL VARIABLES USED:

 %SonusQA::PSX::CMD_LOOKUP::CMD_LIST

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  Array of type(MASTER or SLAVE or both)

=item EXAMPLE:

  For example, to check "vbrrsprsr" command
  my @sbc_arr = $obj->cmdLookUp("vbrrsprsr");

=back

=cut

sub cmdLookUp {                                              #TOOLS - 13183
    my ($self,$cmd) = @_;
    my $sub = "cmdLookUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ($cmd) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory command is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[0]");
        $main::failure_msg .= "TOOLS:SBX5000-Mandatory command missing; ";
        return 0;
    }

    my @type_arr;
    my %look_up = %SonusQA::PSX::CMD_LOOKUP::CMD_LIST;
    foreach my $type (keys %look_up){
        my $to_match = '('.join ('|',@{$look_up{$type}}).')';
        if($cmd =~ /$to_match/) {
            $logger->debug(__PACKAGE__. ".$sub: The command '$cmd' can be run on '$type'");
            push (@type_arr,$type);
        }
    }
    unless (@type_arr){
        $logger->debug(__PACKAGE__. ".$sub: The command '$cmd' can be run only on 'SLAVE'");
        @type_arr = ('SLAVE');
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
    return @type_arr;
}

=head2 adamgmtSequence ()

DESCRIPTION:

 This subroutine will run adamgmt and does the operation bases on the sequence passed

=over

=item ARGUMENTS:

 Mandatory :

  -sequence     =>  ['1','4']

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

my $adamgmt= ['1','4'];

unless ( $psxObj->adamgmtSequence($adamgmt)) {
        $logger->debug(__PACKAGE__ . ": Could not complete adamgmt");
        return 0;
}

=back

=cut

sub adamgmtSequence {
  my ($self, $sequence)=@_;
  my ($logger,$sub, $ada);
  $sub = "adamgmtSequence";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $bFlag = 1;
  $ada = $self->{ADAMGMT};
  unless($self->mgmtSequence($ada,$sequence)){
     if($self->{VERIFICATION_LOG_BACKUP}){
        $logger->warn(__PACKAGE__ . ". $sub revert the log file name from $self->{VERIFICATION_LOG}_back to  $self->{VERIFICATION_LOG}");
        $self->{conn}->cmd("mv $self->{VERIFICATION_LOG}_back $self->{VERIFICATION_LOG}");
     }
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }
  $logger->debug(__PACKAGE__ . " $sub <-- Leaving Sub [1]");
  return $bFlag;

}

=head2 ssmgmtSequence ()

DESCRIPTION:

 This subroutine will run ssmgmt and does the operation bases on the sequence passed

=over

=item ARGUMENTS:

 Mandatory :

  -sequence     =>  ['14','1','3','5','0']

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

my $ssmgmt= ['14','1','3','5'];

unless ( $psxObj->ssmgmtSequence($ssmgmt)) {
        $logger->debug(__PACKAGE__ . ": Could not complete ssmgmt");
        return 0;
}

=back

=cut

sub ssmgmtSequence {
  my ($self, $sequence)=@_;
  my ($logger,$sub, $pes);
  $sub = "ssmgmtSequence";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $bFlag = 1;
  $pes = $self->{SSMGMT};
  unless($self->mgmtSequence($pes,$sequence)){
     if($self->{VERIFICATION_LOG_BACKUP}){
        $logger->warn(__PACKAGE__ . ". $sub revert the log file name from $self->{VERIFICATION_LOG}_back to  $self->{VERIFICATION_LOG}");
        $self->{conn}->cmd("mv $self->{VERIFICATION_LOG}_back $self->{VERIFICATION_LOG}");
     }
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }
  $logger->debug(__PACKAGE__ . " $sub <-- Leaving Sub [1]");
  return $bFlag;

}

=head2 pgkmgmtSequence ()

DESCRIPTION:

 This subroutine will run pgkmgmt and does the operation bases on the sequence passed

=over

=item ARGUMENTS:

 Mandatory :

  -sequence     =>  ['3','4']

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

my $pgkmgmt= ['3','4'];

unless ( $psxObj->pgkmgmtSequence($pgkmgmt)) {
        $logger->debug(__PACKAGE__ . ": Could not complete pgkmgmt");
        return 0;
}

=back

=cut

sub pgkmgmtSequence {
  my ($self, $sequence)=@_;
  my ($logger,$sub, $pgk);
  $sub = "pgkmgmtSequence";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $bFlag = 1;
  $pgk = $self->{PGKMGMT};
  unless($self->mgmtSequence($pgk,$sequence)){
     if($self->{VERIFICATION_LOG_BACKUP}){
        $logger->warn(__PACKAGE__ . ". $sub revert the log file name from $self->{VERIFICATION_LOG}_back to  $self->{VERIFICATION_LOG}");
        $self->{conn}->cmd("mv $self->{VERIFICATION_LOG}_back $self->{VERIFICATION_LOG}");
     }
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }
  $logger->debug(__PACKAGE__ . " $sub <-- Leaving Sub [1]");
  return $bFlag;

}

=head2 ssmgmtStats ()

DESCRIPTION:
Purpose      : Returns the output of an ssmgmt stats fetch; Current ssmgmt utility only enters options using the perl print function 
without capturing the result of the command. This sub uses cmd (instead of print to enter the digit at the ssmgmt menu and captures 
the result of the command 

=over

=item ARGUMENTS:

 Mandatory :
  ssmgmt menu option in integer format (like 26 = Get INAP Counters)
  $sequence     =  ["6" , "12" , "22" ] . here you pass the numbers that you want to see the output for.

=item Return values: Output from ssmgmt menu option (example 26 will return a stats

table that looks like:
        ---------------------------------------------------------------
        INAP Counters
        ---------------------------------------------------------------
        INAP IDP Sent   = 25
        INAP IDP Failed = 5
        INAP TSSF Timeouts              = 0
        INAP Errors Received            = 5
        INAP Errors Detected            = 0
        ---------------------------------------------------------------
=item EXAMPLE:

unless ( @result = $psxObj->ssmgmtStats( $sequence)){
        $logger->debug(__PACKAGE__ . " : Could not get the ssmgmt Statistics ");
        return 0;
        }

=back

=cut

sub ssmgmtStats {
  my ($self, $sequence)=@_;
  my (@cmdResults,$res, $logger, $sub, $pes);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
  $pes = $self->{SSMGMT};
  $logger->info(__PACKAGE__ . ".ssmgmtStats command => $pes");
  ($res,@cmdResults) = $self->mgmtStats($pes,$sequence);
  unless($res){
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }else{
     $logger->debug(__PACKAGE__ . ". $sub <-- Leaving Sub [1]");
     return (@cmdResults);   
  }
}

=head2 scpamgmtSequence () 

DESCRIPTION:
 This subroutine will run scpamgmt and does the operation bases on the sequence passed

=over

=item ARGUMENTS:

 Mandatory :
  -sequence     =>  ["1" , "2" , "5" ] 

 Optional :

   Optional argument is a Hash with following options

       -validation_pattern  => Multiple patterns need to be verfied on scpa.log
                               Patterns are passed in form of an hash with key and values
                               Ex - { 'SUA Trace' => 'ENABLED',
                                      'TCAP Trace' => 'DISABLED'}

       -port                => port number to be passed while starting scpamgmt


=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

my $scpamgmt= ['14','1','3','5'];
my %args = (-validation_pattern => { 'SUA Trace' => 'ENABLED',
                                     'TCAP Trace' => 'DISABLED'},
            -port => 8747);

unless ( $psxObi->scpamgmtSequence($scpamgmt, %args)) {
        $logger->debug(__PACKAGE__ . ": Could complete scpamgmt");
        return 0;
}

=back

=cut

sub scpamgmtSequence {
  my ($self, $sequence, %args)=@_;
  my ($logger,$sub, $scpa);
  $sub = "scpamgmtSequence";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $bFlag = 1;
  if($args{-port}) {
     $scpa = $self->{SCPAMGMT} . " -s " . $args{-port};
  } else {
     $scpa = $self->{SCPAMGMT};
  }
  unless($self->mgmtSequence($scpa,$sequence,%args)){
     if($self->{VERIFICATION_LOG_BACKUP}){
	$logger->warn(__PACKAGE__ . ". $sub revert the log file name from $self->{VERIFICATION_LOG}_back to  $self->{VERIFICATION_LOG}");
	$self->{conn}->cmd("mv $self->{VERIFICATION_LOG}_back $self->{VERIFICATION_LOG}"); 
     }
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }
  $logger->debug(__PACKAGE__ . ". $sub <-- Leaving Sub [1]");
  return $bFlag;
}

=head2 scpamgmtStats()

DESCRIPTION:
Purpose      : Returns the output of an scpamgmt stats fetch; Current scpamgmt utility only enters options using the perl print function 
	without capturing the result of the command. This sub uses cmd (instead of print to enter the digit at the scpamgmt menu 
	and captures the result of the command

=over

=item ARGUMENTS: 

	scpamgmt menu option in integer format (like 3 = Show SS7 TCAP Statistics) And port number to access the specific SCPA if required.
	If port number is not given, the command is executed without -s option

	$sequence     =  ["3" , "4"]  -- here you pass the numbers that you want to see the output for.
	$port = 22	

=item Return values: Output from scpamgmt menu option

=item EXAMPLE:

unless ( @result = $psxObj->scpamgmtStats( $sequence, $port)){
        $logger->debug(__PACKAGE__ . " : Could not get the ssmgmt Statistics ");
        return 0;
        }

=back

=cut

sub scpamgmtStats {
  my ($self, $sequence, $port)=@_;
  my ($logger, $sub, $scpa,@cmdResults,$res);
  $sub = "scpamgmtStats";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
  # Make sure scpamgmt is not currently running
  $self->stopScpamgmtCmd();
  if(defined($port)) {
     $scpa = $self->{SCPAMGMT} . " -s " . $port;
  } else {
     $scpa = $self->{SCPAMGMT};
  }
  $logger->info(__PACKAGE__ . ".scpamgmtStats command => $scpa");
  ($res,@cmdResults) = $self->mgmtStats($scpa,$sequence);
  unless($res){
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
  }else{
     $logger->debug(__PACKAGE__ . ". $sub <-- Leaving Sub [1]");
     return (@cmdResults);
  }
}

=head2 stopScpamgmtCmd()

DESCRIPTION:

Purpose : Check whether scpamgmt command is running. If the process is running
           terminate the processes so that the new invoked process will get
           the control

=cut

sub stopScpamgmtCmd () {

   my ($self)=@_;
   my $sub = "stopScpamgmtCmd()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub: Inside $sub sub");

   $self->{conn}->buffer_empty;

   # Check if already scpamgmt session is running if yes kill it
   my $pid;
   my $cmd1 = "ps -ef|grep scpamgmt|grep -v grep";
   $logger->info(__PACKAGE__ . ".$sub: Executing the shell command:$cmd1 --.");

   my @cmdResults = $self->{conn}->cmd("$cmd1");

   unless ($self->execCmd("$cmd1")) {
      $logger->info(__PACKAGE__ . ".$sub: No scpamgmt sessions running.");
      $logger->info(__PACKAGE__ . ".$sub: cmd result :  \n@{$self->{CMDRESULTS}}");
      return 1;
   }

   $logger->info(__PACKAGE__ . ".$sub: \n@{$self->{CMDRESULTS}}.");

   my $string;
   foreach $string ( @{ $self->{CMDRESULTS}} ) {
      $logger->info(__PACKAGE__ . ".$sub $string");

      if($string =~ /\S+\s+(\d+)/) {
         $pid = $1;
         my $cmd2 = "kill -9 $pid";
         $logger->info(__PACKAGE__ . ".$sub Captured the PID=$pid of the scpamgmt command");
         unless ($self->execCmd("$cmd2")) {
            $logger->info(__PACKAGE__ . ".$sub: Executing the shell command:$cmd2 --.");
         }
         $logger->info(__PACKAGE__ . ".$sub: kill command result \n@{$self->{CMDRESULTS}}");
      } else {
        $logger->error(__PACKAGE__ . ".$sub : This should not come");
      }
   }
   $logger->info(__PACKAGE__ . ".$sub: Leaving $sub sub");
   return 1;
}

=head2 mgmtSequence()

This method shall enable the loglevel for various processes
The mandatory parameters are -

$mgmt : mgmt name -> scpamgmt / sipemgmt / ssmgmt / pgkmgmt
$ref : array reference having the various selection inputs

=over

=item Arguments :

$mgmt can hold one of the following values  :  ssmgmt / pgkmgmt / sipemgmt / scpamgmt
$ref must be initilaised as : $loglevel = ['14','1','3','5','0']
The values are in the order entered during manual selection of log level

=item Optional arguments :

        -validation_pattern => string need to be greped from log file.

        -validation_pattern => { 'SUA Trace' => 'ENABLED',
                                'TCAP Trace' => 'DISABLED'}

=item Return Values :

0 : failure
1 : Success

=item Example :

        my $ssmgmt = ['14','1','3','5']
        my $log1 = "ssmgmt"
        my %args = (-validation_pattern => { 'SUA Trace' => 'ENABLED',
                                             'TCAP Trace' => 'DISABLED'});

        or

        my %args = (-validation_pattern => { 'SUA Stack log mask' => '0xff',
                                             'TCAP Stack log mask' => '0x3'});
 $psxObj->mgmtSequence($log1,$ssmgmt, %args)

=item Added by :

sangeetha <ssiddegowda@sonusnet.com>

Modified by Malc <mlashley@sonusnet.com> - old version didn't set {conn}->prompt before invoking cmd() method - which meant we had to wait for a timeout each time this method was called, since the subsequent call was to waitfor() simply set the prompt accordingly - and change cmd() to print().

Modified by Naresh <nanthoti@sonusnet.com> - to support JIRA Issue TOOLS-2499. removed the duplicate code from subrotines  ssmgmtSequence, scpamgmtSequence in PSX.pm and set_loglevel in PSXHELPER.pm and copied into the subroutine mgmtSequence in PSX.pm

=back 

=cut

sub mgmtSequence(){

   my ($self,$mgmt,$ref, %args) = @_;
   my (@cmdResults,$prematch, $match, $prevPrompt,$logName);
   my $sub = "mgmtSequence";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $prompt = '/Enter (Selection|Choice)\:/';
   my $prompt2;
   my %mgmtLogNames =('ssmgmt' => "pes", 'sipemgmt' =>"sipe", 'scpamgmt'=>"scpa", 'slwresdmgmt' => "slwresd", 'adamgmt' => "ada", 'pgkmgmt' => "pgk", 'httpmgmt' => "httpc");
   $logger->info(__PACKAGE__ . ".$sub Entered sub to set mgmtSequence for $mgmt");
   unless(defined($ref)){
      $logger->error(__PACKAGE__ . ".$sub $mgmt Sequence  LOGGING LEVELS MISSING - REQUIRED");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }
   my @array = @$ref;
   if($mgmt =~ m{^/.*/(\w+).*$})
   {
      $logName = $1;
   }else{
      $logName = $mgmt;
   }
   $self->{VERIFICATION_LOG} = "$self->{LOGPATH}/$mgmtLogNames{$logName}.log";
   $logger->warn(__PACKAGE__ . ". $sub lets keep a backup of $self->{VERIFICATION_LOG} as $self->{VERIFICATION_LOG}_back");
   $self->{conn}->cmd("cp $self->{VERIFICATION_LOG} $self->{VERIFICATION_LOG}_back");
   $self->{VERIFICATION_LOG_BACKUP}=1;
# Be sure to restore this from any place you may add a 'return'... malc.
   $prevPrompt = $self->{conn}->prompt($prompt);

   $logger->debug(__PACKAGE__ . ".$sub ENTERING $mgmt MENU ");
   $self->{conn}->print($mgmt);
   ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                             -errmode => "return",
                                             -timeout => $self->{DEFAULTTIMEOUT}) or do {
      $logger->warn(__PACKAGE__ . ". $sub  UNABLE TO ENTER $mgmt MENU ");
      $self->{conn}->prompt($prevPrompt);
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   };

   if ( $mgmt =~ /scpamgmt/ ){
      $prompt = '/Enter.*' . ':/';
      $prompt2 ='/Enter Selection\:/';
   }
   else {
      $prompt = '/\.*' . ':/';
      $prompt2 ='/Enter Selection\:/';
   }

   foreach (@array)
   {
      if ($_ =~ /^\d+$/) {
	$logger->info(__PACKAGE__ . ".$sub. $mgmt - SENDING SELECTION : [$_]");
        $self->{conn}->print($_);

        ($prematch, $match)=$self->{conn}->waitfor(-match => $prompt,
                                                   -match => $prompt2,
                                                   -errmode => "return",
                                                   -timeout => $self->{DEFAULTTIMEOUT}) or do {
          $logger->warn(__PACKAGE__ . ".$sub. $mgmt  ERROR ENTERING LOGGING LEVEL MENU NUMBER [$_]");
          $self->{conn}->prompt($prevPrompt);
          $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
          return 0;
        };
      }
      else {
	$logger->warn(__PACKAGE__ . ".$sub. $mgmt LOGGING LEVEL [$_] IS NOT AN INTEGER");
      }
   }
   sleep(1);
   $logger->debug(__PACKAGE__ . ".$sub. $mgmt Sequence PROMPT: " . $self->{conn}->prompt );
   $logger->info(__PACKAGE__ . ".$sub. LOG LEVELS FOR $mgmt SUCCESSFULLY SET");
   $logger->debug(__PACKAGE__ . ".$sub. $mgmt  SENDING CONTROL-C TO BREAK OUT OF $mgmt");

   $self->{conn}->print("\x03");
   ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                             -match => $prevPrompt,
                                             -errmode => "return",
                                             -timeout => $self->{DEFAULTTIMEOUT}) or do {
      $logger->debug(__PACKAGE__ . ".$sub $mgmt Sequence  PRE-MATCH:" . $prematch);
      $logger->debug(__PACKAGE__ . ".$sub $mgmt Sequence  MATCH: " . $match);
      $self->{conn}->prompt($prevPrompt);
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   };

   $self->{conn}->prompt($prevPrompt);

   $logger->warn(__PACKAGE__ . ".$sub getting diff between $self->{VERIFICATION_LOG} and $self->{VERIFICATION_LOG}_back");
   my @diff_array = $self->{conn}->cmd("diff  $self->{VERIFICATION_LOG} $self->{VERIFICATION_LOG}_back"); 

   $logger->warn(__PACKAGE__ . ".$sub deleting $self->{VERIFICATION_LOG}_back");
   $self->{conn}->cmd("rm $self->{VERIFICATION_LOG}_back");
   $self->{VERIFICATION_LOG_BACKUP}=0;
   $logger->warn(__PACKAGE__ . ".$sub $self->{VERIFICATION_LOG} file is not updated after setting log level") unless (@diff_array);

   if (exists $args{-validation_pattern}) {
      my %pattern = %{$args{-validation_pattern}};
      foreach my $key (keys %pattern) {
	my $temp = $key;
	$temp =~ s/\s+/ \*/g;
	
	unless (grep(/$temp *\[$pattern{$key}\]/, @diff_array)) {
		$logger->warn(__PACKAGE__ . ".$sub validation of $key in $self->{VERIFICATION_LOG} failed");
		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
		return 0;
	} else {
		$logger->debug(__PACKAGE__ . ".scpamgmtSequence  $temp \*\[$pattern{$key}\] found in scpa\.log");
	}
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
	
}

=head2 mgmtStats()

Purpose      : Returns the output of an mgmt stats fetch; This sub uses cmd (instead of print to enter the digit at
	       the mgmt menu and captures the result of the command
Parameters   : mgmtName and mgmt menu option in integer format (like 3 = Show SS7 TCAP Statistics in SCPA mgmt)
Return values: Output of mgmt menu options

The mandatory parameters are -
$mgmt : mgmt name -> scpamgmt / ssmgmt / pgkmgmt
$ref : array reference having the various selection inputs

=over

=item Arguments :

$mgmt can hold one of the following values  :  ssmgmt / pgkmgmt / scpamgmt
$ref must be initilaised as : $statSequence = ['1','3','5',]

=item Return Values :

0 	      : failure
1,resultArray : Success

=item Usage :

	my($ret,@SequenceReturn);
        my $sequence = ['1','3','5']
        my $mgmt = "/export/home/ssuser/SOFTSWITCH/BIN/pgkmgmt" or "pgkmgmt"
        ($ret,@SequenceReturn)=$psxObj->mgmtStats($mgmt,$sequence);
	unless($ret){
	   print "Failed to get result from mgmtStats";
	}else{
	   print "Successfully fetched mgmtStats result: @SequenceReturn";
	}

=item Added by : 

        Naresh <nanthoti@sonusnet.com> - removed the duplicate code from subrotines  ssmgmtStats, scpamgmtStats copied into the subroutine mgmtStats.

=back 

=cut


sub mgmtStats {
    my ($self, $mgmt,$sequence)=@_;
    my (@cmdResults, @final, $mgmtName, $logger, @cmds, $prematch, $match, $prevPrompt);
    my $sub = "mgmtStats";
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $prompt = '/Enter (Selection|Choice)\:/';
    $prevPrompt = $self->{conn}->prompt;
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    if((!defined($sequence))||(!defined($mgmt))){
	$logger->warn(__PACKAGE__ . ".$sub LOGGING LEVELS MISSING ARGUMENTS SEQUENCE or MGMT TYPE- REQUIRED");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
    }
    if($mgmt =~ m{^/.*/(\w+).*$}) # Added .* in the pattern to work fine even if port is passed (e.g: $mgmt = "/export/home/ssuser/SOFTSWITCH/BIN/scpamgmt -s 3061"). Fix for TOOLS-2718
    {
	$mgmtName = $1;
    }else{
	($mgmtName = $mgmt)=~s/^(\w+).*$/$1/; # removing port from mgmtName if it is passed. 
	$mgmt = "/export/home/ssuser/SOFTSWITCH/BIN/$mgmt";
    }
    @cmds = @{$sequence};
    $self->{conn}->print($mgmt);
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
	$logger->warn(__PACKAGE__ . ".$sub UNABLE TO ENTER SSMGMT MENU SYSTEM");
	$self->{conn}->prompt($prevPrompt);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
	};
    if($mgmt =~ /scpamgmt/){
	$self->{conn}->prompt('/Enter Choice.*\:/');	  
    }else{
	$self->{conn}->prompt('/Enter Selection\:/');
    }
    foreach(@cmds){
	if ($_ =~ /^\d+$/) {
	    $logger->info(__PACKAGE__ . ".$sub  SENDING SEQUENCE ITEM: [$_]");
	    @cmdResults=$self->{conn}->cmd($_);
	    push ( @final , @cmdResults );
	}
	else {
	    $logger->warn(__PACKAGE__ . ".$sub LOGGING LEVEL [$_] IS NOT AN INTEGER - SKIPPING");
	}
    }
    $logger->debug(__PACKAGE__ . ".$sub PROMPT: " . $self->{conn}->prompt );
    if($mgmt =~ /pgkmgmt/){
	$logger->debug(__PACKAGE__ . ".$sub  SENDING \'9\'  TO BREAK OUT OF $mgmtName");
	$self->{conn}->print("9");
	($prematch, $match) = $self->{conn}->waitfor(-match => $prevPrompt,
                                                 -errmode => "return",
                                                 -timeout => 5) or do {
	    $logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
	    $logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
	    $logger->debug(__PACKAGE__ . ".$sub  LAST LINE:" . $self->{conn}->lastline);
            };
    }else{
	foreach(my $i =0; $i <= $#cmds; $i++){
	    $logger->debug(__PACKAGE__ . ".$sub  SENDING \'0\' TO BREAK OUT OF $mgmtName");
	    $self->{conn}->print("0");
	    ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                                 -match => $prevPrompt,
                                                 -errmode => "return",
                                                 -timeout => 5) or do {
		$logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
		$logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
		$logger->debug(__PACKAGE__ . ".$sub  LAST LINE:" . $self->{conn}->lastline);
		};
	}
    }
    $self->{conn}->waitfor( -match => $prevPrompt, -timeout => 10) if ($match =~ /Bye/); #SCPA Mgmt sends 'Bye' when we exit
    # Set the previous prompt back
    $self->{conn}->prompt($prevPrompt);
    $self->{conn}->print("date");
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prevPrompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
	$logger->debug(__PACKAGE__ . ".$sub PRE-MATCH:" . $prematch);
	$logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
	};
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return (1,@final);

}

=head2 execGksim()

DESCRIPTION:

   This subroutine executes the given GK Sim script on the PSX and checks if the script was successful or not. It searches the script output for the success string provided to ensure that the script was successful. The command would be executed from /export/home/ssuser/SOFTSWITCH/BIN directory where the gksim executable would be found. The exact path where the scripts are present on the PSX is also required to be provided as input.

=over

=item ARGUMENTS:

   1. Name of the script to be executed by gksim.
   2. Pattern which indicates that the script was successful.

=item RETURN VALUE:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:

   my $res = $psxtmsObj->execGksim("GKScripts/test.scr","TEST SUCCESSFUL");

   This statement would execute the script /export/home/ssuser/SOFTSWITCH/BIN/GKScripts/test.scr and would return 1 if the string TEST SUCCESSFUL was found in its output and 
   0 if not. 

=back

=cut

sub execGksim() {
  my ($self,$script,$successString)=@_;
  my (@cmdResults,$res,$logger);
  my $sub = "execGksim";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Check if the user is ssuser
  @cmdResults = $self->execCmd("id");
  $res = grep(/ssuser/,@cmdResults);
  if ($res == 0) {
    $logger->error(__PACKAGE__ . ".$sub : Not logged in as ssuser and hence cannot execute gksim!");
    return 0;
  }

  $self->execCmd("cd $self->{SSBIN}");

  # Execute the GKSIM script
  $logger->error(__PACKAGE__ . ".$sub : Executing command - ./gksim $script");
  @cmdResults = $self->execCmd("./gksim $script");

  # Verify if the success pattern received
  $res = grep(/$successString/,@cmdResults);
  if ($res == 0) {
    $logger->error(__PACKAGE__ . ".$sub : ERROR: Gksim script failed");
    return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub : Gksim script completed successfully");
  return 1;
}


=head2 startGksim()

DESCRIPTION:

   This subroutine executes the given GK Sim script on the PSX. This interface DOES NOT wait for the script to complete and returns back immediately after executing the command on the PSX. The command would be executed from /export/home/ssuser/SOFTSWITCH/BIN directory where the gksim executable would be found. The exact path where the scripts are present on the PSX is also required to be provided as input.

=over

=item ARGUMENTS:

   1. Name of the script to be executed by gksim.

=item RETURN VALUE:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:

   my $res = $psxtmsObj->startGksim("GKScripts/test.scr");

   This statement would execute the script /export/home/ssuser/SOFTSWITCH/BIN/GKScripts/test.scr and would return 1 if there were no errors and 0 if any error was encountered.

=back

=cut

sub startGksim() {

  my ($self,$script)=@_;
  my (@cmdResults,$res,$logger);
  my $sub = "startGksim";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Check if the user is ssuser
  @cmdResults = $self->execCmd("id");
  $res = grep(/ssuser/,@cmdResults);
  if ($res == 0) {
    $logger->error(__PACKAGE__ . ".$sub : Not logged in as ssuser and hence cannot execute gksim!");
    return 0;
  }

  $self->execCmd("cd $self->{SSBIN}");

  # Execute the GKSIM script
  $logger->info(__PACKAGE__ . ".$sub : Starting command - ./gksim $script");
  @cmdResults = $self->{conn}->print("./gksim $script");

  $logger->info(__PACKAGE__ . ".$sub : Gksim script initiated successfully");
  return 1;

} 

=head2 waitforGksimCompletion()

DESCRIPTION:

   This subroutine is called after startGksim to check the status of the GK script execution. It waits for the prompt and checks if the success string provided is present in the output of the GKscript. If the success string is found in the GKscript output, then it returns 1 and 0 if not.

=over

=item ARGUMENTS:

   1. Pattern which indicates that the script was successful.

=item RETURN VALUE:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:

   my $res = $psxtmsObj->waitforGksimCompletion("TEST SUCCESSFUL");

   This statement would wait for the prompt to be returned and return 1 if the string TEST SUCCESSFUL was found in its output and 0 if not.

=back 

=cut

sub waitforGksimCompletion() {

  my ($self,$successString)=@_;
  my ($prematch, $match, $sub,$logger);

  $sub = "waitforGksimCompletion";
  ($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
    $logger->error(__PACKAGE__ . ".$sub Error waiting for prompt after executing GKSim script.");
    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
    return 0;
  };

  $logger->info(__PACKAGE__ . ".$sub Received prompt after executing Gksim script");
  $logger->info(__PACKAGE__ . ".$sub Output of Gksim script is as follows");
  $logger->info(__PACKAGE__ . ".$sub $prematch");
  
  # Check if the script was successful by looking for the success string
  if ($prematch  =~ /$successString/) {
    $logger->info(__PACKAGE__ . ".$sub GkSim script successfully executed");
    return 1;
  } else {
    $logger->error(__PACKAGE__ . ".$sub Error during GkSim script execution");
    return 0;
  } 

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

=head2 psx_purge()

    This function will delete entries from routing_label, route, GATEWAY, TRUNKGROUP & SUBSCRIBER tables of PSX DB.

=over

=item Arguments:

    None

=item Return Value:

    0 - on failure
    1 - on success

=item Usage:

    my $purge_psx = $psxObj->psx_purge();

=back 

=cut

sub psx_purge {

    my ($self) = @_;
    my $sub = "psx_purge";
    my @psx_purge_res = ();
    my @cmd_res = ();
   # my @tables = ('routing_label', 'route' , 'SUBSCRIBER', 'GATEWAY' , 'TRUNKGROUP');
    my @commands = ('delete from route where ROUTING_LABEL_ID like \'auto%\'','delete from  routing_label_routes where ROUTING_LABEL_ID like \'auto%\'','delete from routing_label where ROUTING_LABEL_ID like \'auto%\'');
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    foreach(@commands) {
       @cmd_res = $self->execSqlplusCommand("$_;",10800);
        unless(@cmd_res) {
            $logger->error(__PACKAGE__ . ".$sub: Error deleting rows from $_");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
	$logger->info(__PACKAGE__ . ".$sub: command Successfull:  $_ ");
        $logger->info(__PACKAGE__ . ".$sub: Successfully:  $cmd_res[$#cmd_res]  ");
    }

    return 1;
}

=head2 execSqlplusCommand()

    This function will execute the sql plus command and returns the output inform of array.

=over

=item Arguments:

   sql plus command

=item Return Value:

    0 - on failure
    array - command output

=item Usage:

    @output = $psxObj->execSqlplusCommand("select count(*) from routing_label where routing_label_id like \'automation%\';");

=back

=cut

sub execSqlplusCommand {
    my ($self, $command, $timeout)=@_;
    my $sub_name = "execSqlplusCommand";  
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".sqlplusCommand");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    my @cmdResults = $self->sqlplusCommand($command,'','',$timeout);   #TOOLS-18610 

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub with command output");
    return @cmdResults;
}


=head2 C< getCloudPsxLogs >

=over

=item DESCRIPTION:

This function is called in SonusQA::ATSHELPER::checkStatus() to collect Cloud Metadata logs post spawning as per the requirement of TOOLS-72088

=item ARGUMENTS:

Mandatory Args:
-obj : SonusQA::TOOLS  object
-fileprefix : preferred prefix of archive file

=item PACKAGES USED:

SonusQA::Base::secureCopy

=item GLOBAL VARIABLES USED:

$LOG_DIRECTORY

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - On Failure
1 - On success

=item EXAMPLE:

    unless(SonusQA::PSX::getCloudPsxLogs(-obj => $obj, -filePrefix => "username_slave") ) {
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub: Failed to get metadata logs");
    }

=back

=cut

sub getCloudPsxLogs {
    my $sub_name = 'getCloudPsxLogs';
    my %args = @_;
    my $obj = $args{-obj};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . ".$sub_name Entered Sub -->");

    my $cmd = '/export/home/ssuser/SOFTSWITCH/BIN/archiveCloudLogs.sh';
    $logger->debug(__PACKAGE__ . ".$sub_name: Executing the command: $cmd");

    my @cmd_results;

    unless(@cmd_results = $obj->{conn}->cmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command: $cmd");
        $logger->debug(__PACKAGE__. ".$sub_name: errmsg: [" . $obj->{conn}->errmsg . ']');
        $logger->debug(__PACKAGE__. ".$sub_name: Session Dump Log: " . $obj->{sessionLog1});
        $logger->debug(__PACKAGE__. ".$sub_name: Session Input Log: " . $obj->{sessionLog2});
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @match = grep(/Cloud log archive completed in/ , @cmd_results);
    my ($source, $dest, $scp_obj);
    if($match[0] =~ /Cloud log archive completed in (\S+)/ ) {
        $source = $1;
        $source =~ /.+\/(\S+\.tgz)/;
        `mkdir -p $LOG_DIRECTORY/DUTLogs`;
        $dest = "$LOG_DIRECTORY/DUTLogs/$args{-file_prefix}"."_$1";

        my %scpArgs;
        $scpArgs{-hostip} = "$obj->{OBJ_HOST}";
        $scpArgs{-hostuser} = "$obj->{OBJ_USER}";
        $scpArgs{-hostpasswd} = "$obj->{OBJ_NEW_PASSWORD}";
        $scpArgs{-scpPort} = "$obj->{OBJ_PORT}";
        $scpArgs{-timeout} = 180;
        $scpArgs{-identity_file} = "$obj->{OBJ_KEY_FILE}";
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$source;
        $scpArgs{-destinationFilePath} = $dest;
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to copy Cloud PSX logs");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Cloud PSX Logs archive copied successfully at [$dest]");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

1;
