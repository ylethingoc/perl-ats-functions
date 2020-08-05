package SonusQA::GBL;

use Tie::File;

=head1 NAME

SonusQA::GBL - Perl module for Sonus Networks GBL interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::GBL->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually admin>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET | SSH>",
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for the GSX switch.
   It provides methods for both postive and negative testing, most cli methods returning true or false (0|1).
   Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, 
   allowing the engineer to specific which attributes to use.  Complete examples are given for each method.

=head1 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head1 METHODS

=head2 new

    Constructure subroutine to create object.

=over

=item Arguments

    -obj_host
        GBL server
    -obj_user
        GBL user account
    -obj_password
        User password
    -obj_commtype
        TELNET or SSH; defaults to TELNET
    -shell
        Unix shell: csh, tcsh, sh, bash, or ksh; defaults to sh
    -force
        Disconnect from a server before connecting; defaults to 1
    -log_level
        Controls the amount of displayed information; defaults to an environment variable LOG_LEVEL or to INFO when the variable not defined
        log levels and their hierarchy:
            * DEBUG
            * INFO
            * WARN
            * ERROR
            * FATAL
    -defaulttimeout
      Default timeout for commands; in seconds; defaults to 10

=item Returns

    * An instance of the SonusQA::MGTS class, on success
    * undef, otherwise

=item Examples

    my $gbl = new SonusQA::GBL (-obj_host => blues.sonusnet.com,
                                  -obj_user => gbl,
                                  -obj_password => sonus,
                                  -comm_type => TELNET,
                                  -shell => csh); 

=back

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime sys_wait_h waitpid setsid :errno_h);
use Module::Locate qw / locate / ;
use File::Basename;
use Data::UUID;
use Net::Telnet ();
use Cwd;
our $VERSION = "1.0";
use vars qw($VERSION $self);
use SonusQA::Base;
use SonusQA::UnixBase;

our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

=head2 doInitialization

    This function is called by Object new() method. Do not need to call it explicitly

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{TYPE} = __PACKAGE__;
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  $self->{VARFILES} = $self->{DIRECTORY_LOCATION} . "gbl/VARFILES";
  $self->{GBL} = "/ats/bin/gbl";
  $self->{SCRIPTPATH} = dirname($0);
  $self->{GBLINCLUDEPATH} = getcwd();
  $self->{LAUNCHDELAY} = 5;
  $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
 
  $self->{DEFAULTTIMEOUT} = 120;
  $self->{HISTORY} = ();
  $self->{CMDRESULTS} = [];
  $self->{COMMTYPES} = ["TELNET","SSH"];
  $self->{COMM_TYPE} = "TELNET";
  #
  $self->{TERMINATIONDELAY} = 180;
  $self->{GBLLOG} = undef;
}

=head2 setSystem

    This subroutine sets the system information and prompt.

=cut

sub setSystem(){
  my($self)=@_;
  my $subName = 'setSystem';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd(""); 
  if( $self->{OBJ_USER} =~ /autouser/ ){
      $self->{conn}->cmd("cd /ats/VARFILES/");
      $logger->info(__PACKAGE__ . ".$subName  Changed the path to '/ats/VARFILES/' ");
  }
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  #cahnged cmd() to print() to fix, TOOLS-4974
  unless($self->{conn}->print($cmd)){
    $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
    $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
    $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
    $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
    $main::failure_msg .= "TOOLS:GBL-Login Error; ";
    return 0 ;
  } 
 
  unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
    $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
    $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
    $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
    $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
    $main::failure_msg .= "TOOLS:GBL-Login Error; ";
    return 0 ;
  } 

  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->last_prompt);
  # Clear the prompt
  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
  $self->{conn}->cmd("set +o history");
  $self->{conn}->cmd('PATH=/ats/bin:$PATH');
  $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
  return 1;
}

=head2 startSingleLeg
   
    This function is used incase you need to execute a single leg (UAS) using GBL
    and a different tool (EAST, MGTS, SIPP, INET etc) as the other leg (UAC)

    startSingleLeg will execute the command passed as an argument and return the
    control back to the user script.

    Note: When you use startSingleLeg, get the execution status using waitSingleLeg
    function.

=over

=item Argument

    $cmd (string)

=item Return

    0 Incase of failure to invoke the GBL Command
    1 Incase the GBL command was invoked successfully.
    Note: This does not indicate whether the GBL call leg was successfull or not.
          For the call leg status, use waitSingleLeg(), as shown in the example.

=item Usage

    my $cmd = "gbl -I VARFILES varfile=ACCORD.var MyDirectory/Testcases/UAS.gbl"
    my $invoke_status = $gblObject->startSingleLeg($cmd);
    # Any other tool to be used for invoking the other leg/legs
    my $result = $gblObject->waitSingleLeg (<timeout>);

=back

=cut

sub startSingleLeg {
  my ($self,$cmd)=@_;
  my $sub = "startSingleLeg()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    unless(defined($cmd)){
        $logger->error(__PACKAGE__.".$sub Command not specified");
        return 0;
    }
 
    $self->{PROMPT} = $self->{conn}->last_prompt;
    # Some machines have prompts with incrementing numbers in sqare brackets
    # Get rid of them
    $self->{PROMPT} =~ s/\[\d+\]//g;    
    #$logger->debug("Last prompt saved : $self->{PROMPT}");
 
    unless ($self->{conn}->print($cmd)) {
        $logger->warn(__PACKAGE__ . ".$sub  Error in executing Command : $cmd");
        $main::failure_msg .= "TOOLS:GBL-GBL socket/varfile error; ";
	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0; 
    }
    
    $logger->info(__PACKAGE__.".$sub . Successfully invoked : $cmd ");
    return 1;
}

=head2 waitSingleLeg

    This function is used to get the execution result status of
    startSingleLeg function.

    startSingleLeg will execute the command passed as an argument and return the
    control back to the user script. To get back the details of that execution
    and also to print the call details into the logs, use waitSingleLeg

    Note: Inorder to use waitSingleLeg, the GBL should be started using startSingleLeg
    function.

=over 

=item Arguments

    $timeout (in seconds)
    If timeout is not specified the default value, 60 seconds, is used

=item Return

    0 Incase of failure to invoke the GBL Command
    1 Incase the GBL command was invoked successfully.
    Note: This does not indicate whether the GBL call leg was successfull or not.
          For the call leg status, use waitSingleLeg(), as shown in the Usage.

=item Usage

    my $cmd = "gbl -I VARFILES varfile=ACCORD.var MyDirectory/Testcases/UAS.gbl"
    my $invoke_status = $gblObject->startSingleLeg($cmd);
    # Any other tool to be used for invoking the other leg/legs
    my $result = $gblObject->waitSingleLeg (<timeout>);

=back

=cut

sub waitSingleLeg () {
 
  my ($self, $timeout)=@_;
  my $sub = "waitSingleLeg";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".In waitSingleLeg");
    if (!defined $timeout) {
        $timeout = $self->{DEFAULTTIMEOUT};
    }
  my @cmdResults;
  my $prematch;
  my $match;
  my $error_flag = 0 ;
  my $prompt = $self->{PROMPT};
  
    unless (($prematch, $match) = $self->{conn}->waitfor( -string => $prompt, -timeout => $timeout)){
        $logger->error(__PACKAGE__ . ".$sub  GBL did not complete in $timeout seconds.");

        # Waited too long! Abort GBL execution, by issuing a "Ctrl-C"
        $self->{conn}->cmd(-string => "\cC",
                             -prompt => $prompt);
        $logger->error(__PACKAGE__ . ".$sub  GBL killed using Ctrl-C");
        $error_flag = 1;
        $main::failure_msg .= "UNKNOWN:GBL-GBL call error; ";
    }

    if ($error_flag == 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub GBL Execution Output: $prematch");
        $logger->info(__PACKAGE__ . ".$sub Detected GBL completion, getting status");
        unless (@cmdResults = $self->{conn}->cmd(-string => "echo \$?",
                                                 -timeout => $self->{DEFAULTTIMEOUT} )) {
            $logger->warn(__PACKAGE__ . ".$sub  Failed to get return value");
        }
        chomp @cmdResults;
        $logger->info(__PACKAGE__ . ".$sub returned exit code : $cmdResults[0]");
        if ($cmdResults[0] eq '0')   {
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
            return 1;
        }
        
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

=head2 execCmd

    This function executes a command on the server (GBL server)

=over

=item Argument

    $cmd (string)

=item Return

    List (@ array) of command result.

=item Usage

    my $cmd = "gbl -I VARFILES varfile=ACCORD.var MyDirectory/Testcases/TC1-Called.gbl"
    my @cmdResult = $gblObject->execCmd($cmd);

=back

=cut

sub execCmd {  
  my ($self,$cmd, $timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
    if (!(defined $timeout)) { 
       $timeout = $self->{DEFAULTTIMEOUT}; 
       $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
    }
    else {
       $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
    } 
    #cmdResults = $self->{conn}->cmd($cmd);
    #return @cmdResults;
    $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
    $timestamp = $self->getTime();
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        # Section for commnad execution error handling - CLI hangs, etc can be noted here.
        $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        if($self->{CMDERRORFLAG}){
        $logger->warn(__PACKAGE__ . ". CMDERROR FLAG IS POSITIVE - CALLING ERROR");
        &error(__PACKAGE__ . ".execCmd GBL CMD ERROR - EXITING");
      }
       $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".execCmd : \n @cmdResults");
    chomp(@cmdResults);
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    push(@{$self->{HISTORY}},"$timestamp :: $cmd");
    return @cmdResults;
}

=head2 waitcompletion

    This function waits for the compeltion of the GBL script and returns the result  
    It assumes that the GBL script employs the spawn and join functions to invoke multiple legs 
    in a single GBL script. (This imples  PERL fork is not required )

=over

=item Argument

    None

=item Return

    1: Success
    0: Failure 

=item Usage

    $cmd="gbl -I /ats/SCRIPTS/GBL/VARFILES filepath=/ats/SCRIPTS/GBL/NBS/V07.01.01/$FC varfile=$FC.var /ats/SCRIPTS/GBL/NBS/V07.01.01/$FC/$testcase";
    Invoke GBL script : $gblObject->execCmd($cmd);

    my $result = $gblObject->waitcompletion();

=item Author

    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub waitcompletion() {

 my ($self)=@_;
 my $sub = "waitcompletion";
 my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".In waitcompletion");
 my $cmd1 = "echo \$?"; 
 $logger->info(__PACKAGE__ . ".$sub Retrieving the return code");
 my @result=$self->{conn}->cmd($cmd1);
 chomp(@result);
 
 $logger->info(__PACKAGE__ . ".$sub Return Code is : $result[0]");

 if ("$result[0]" eq "0"){
    $logger->info(__PACKAGE__ . ".$sub  GBL command returned success");
    return 1;
  } else {
    $logger->warn(__PACKAGE__ .".$sub  GBL command returned error code $result[0]");
    $main::failure_msg .= "UNKNOWN:GBL-GBL call error; ";
    return 0;
  }
 
}

=head2 createvarfile
 
    This function enables dynamic creation of VARFILE in the name of the user 
    by default or in the name specified by the user as an input.
    The varfile created is stored in the ats/VARFILES directory on GBL server
    There is no need to delete the file after use,
    since the deletion is taken care by this function,before every create.

=over

=item Argument

    None

=item Return

    var file name on successful creation 
    0: Failure 

=item usage

    Invoke GBL script : my $varfile = $gblObject->createvarfile(
                                                              "localsip" , "10.34.9.74:5072" ,
                                                              "sipaddr" , "10.34.9.74:5081",
                                                              );

                        my $varfile = $gblObject->createvarfile(
                                                              "varFileName", "tmpVarFile",
                                                              "localsip" , "10.34.9.74:5072" ,
                                                              "sipaddr" , "10.34.9.74:5081",
                                                              );

=item Added by:
    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub createvarfile {
    
  my($self, %args) = @_;
  my $sub = "createvarfile";
  my ($retVal, @retVal,$varfile);
  
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  
  # Check if the var file dir is provided as input
  if (exists $args{"varFileDir"}) 
	{
	  $self->{VARFILE_DIR} = $args{"varFileDir"};
	  delete $args{"varFileDir"};
	}
  else {
	$self->{VARFILE_DIR} = "/ats/VARFILES/";
  }
  
  unless ( $self->{VARFILE_DIR} ) {
	$logger->error(__PACKAGE__ . ".$sub  .gbl path not defined");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
	return 0;
  }
  
  # Check if the var file name is provided as input
  if (exists $args{"varFileName"}) {
	$varfile = $args{"varFileName"}."\.var";
	# Remove the entry from the hash, since it is not required to be written in the var file
	delete $args{"varFileName"};
  }
  else {
	#Find out user's name to create varfile
	my @user = qx#id -un# ;
	chomp(@user);
	unless(defined $user[0]){
	  $logger->error(__PACKAGE__ . ".$sub  .Cannot determine user name");
          $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
	  return 0;
	}
	
	$varfile = $user[0]."\.var";
  }

my $cmd1 = "file " . $self->{VARFILE_DIR} ;
@retVal = $self->execCmd($cmd1);
$retVal = join '', @retVal;
    
    if ($retVal =~ m/No such/ ){
        $cmd1 = "mkdir  " . $self->{VARFILE_DIR} ;
        @retVal = $self->execCmd($cmd1);
        $retVal = join '', @retVal;
    
    if ( $retVal =~ m/Permission|space/ ){
        $logger->error(__PACKAGE__ . " .$sub .Failed to create directory: [$self->{VARFILE_DIR}]");      
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; "; 
        return 0;
        }
    }
my $cmd = "file " . $self->{VARFILE_DIR}.$varfile;
@retVal = $self->execCmd($cmd);
$logger->info(__PACKAGE__ . ".$sub .File command <$cmd> return value <@retVal>");
$retVal = join '', @retVal;
$logger->info(__PACKAGE__ . ".$sub .File command <$cmd> return value <$retVal>");
    
    if ( $retVal !~ m/ cannot open/ ){
        $logger->info(__PACKAGE__ . ".$sub VAR file $self->{VARFILE_DIR}$varfile} already exists .. Removing it");
        $cmd = "rm \-rf $self->{VARFILE_DIR}$varfile";
        #$self->execCmd($cmd);
        if(!($self->{conn}->cmd($cmd))){
            $cmd = "echo > $self->{VARFILE_DIR}$varfile";
            if(!($self->{conn}->cmd($cmd))){
                $logger->error(__PACKAGE__ . ".$sub .Unable to remove VARFILE");
	        $logger->debug(__PACKAGE__ . ".$sub  errmsg: " . $self->{conn}->errmsg);
    		$logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
            }
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0;
        }; 
    }
    
$cmd = "touch " . "$self->{VARFILE_DIR}" . $varfile ;
@retVal = $self->execCmd($cmd);
$retVal = join '', @retVal;   
    
    if ( $retVal =~ m/ cannot open / ){
        $logger->error(__PACKAGE__ . ".$sub .Failed to open variable file <$varfile> for writing");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0;
    }
    
my @array=keys(%args);
my $size=$#array+1;

$logger->debug(__PACKAGE__ . ".$sub .Number of entries to be added to VARFILE is : $size");
    
    foreach my $key (keys %args) {
        $cmd = "echo '\$$key=\"$args{$key}\"\;' >> $self->{VARFILE_DIR}$varfile";
        @retVal = $self->execCmd($cmd);
        $logger->info(__PACKAGE__ . ".$sub .File command : <$cmd> | return value : <@retVal>");
        $retVal = join ''. @retVal;
        if ( $retVal =~ m/ Permission denied / ){
            $logger->error(__PACKAGE__ . ".$sub .Cannot write to VAR file <$self->{VARFILE_DIR}$varfile>");
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0; 
        }
    }
    
    return ($varfile);
}#End of createvarfile()

#May be incorporated later. They are: 
#setDut() makeGblCall() gblTerminationAlarm() catchSigInt() catchSigWarn() catchSigWarn()
#buildCall() 

=head2 setDut

    This function set passed dut to $self->{DUT}. 
    $self->{DUT} = $dut if defined($dut);

=over

=item Argument

    $dut

=item Return

    None

=item Usage

    $gblObject->setDut($dut);

=back

=cut

sub setDut() {
  my ($self, $dut) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDut");
  $logger->warn(__PACKAGE__ . ".setDut UNABLE TO SET BUT - VALUE MUST BE SUPPLIED") unless defined $dut;
  $self->{DUT} = $dut if defined($dut);
}

=head2 setSequence

    This function set passed sequence to $self->{SEQUENCE}.
    $self->{SEQUENCE} =$sequence;

=over

=item Argument

    $sequence

=item Return

    None

=item Usage

    $gblObject->setSequence($sequence);

=back

=cut

sub setSequence() {
  my ($self, $sequence) = @_;
  $self->{SEQUENCE} =$sequence;
  
}

=head2 makeGblCall

    This function make gbl call.

=over

=item Argument

    $sequence (hash reference) 

=item Return

    0 for success
    1 for failure 

=item Usage

    $gblObject->makeGblCall($sequence);

=back

=cut

sub makeGblCall() {
  my ($self, $sequence) = @_;
  my (@commands, $callingCnt,$calledCnt, $command, $pid, $masterQ, $gblLogFile,$successFlag);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".makeCall");
  $masterQ = {};
  return 0 unless defined ($sequence);
  $successFlag = 1;
  my $ug = new Data::UUID();
  my $uuid = $ug->create_str();
  $self->{GBLLOG} = sprintf("/tmp/gbl_%s.log",$uuid);
  foreach(qw / called calling / ){
    if(defined($sequence) && defined $sequence->{$_}) {
      foreach my $scriptRef  (@{$sequence->{$_}}){
        my $cmd = $self->buildCall($scriptRef);
        push @commands, $cmd if defined $cmd;
      }
    }
  }
  $logger->info(__PACKAGE__ . ".makeCall SETTING GLOBAL TERMINATION ALARM TO $self->{TERMINATIONDELAY} SECONDS");
  local $SIG{ALRM} = sub { $self->gblTerminationAlarm($masterQ); };
  local $SIG{'__WARN__'} = sub { $self->catchSigWarn($_[0]); };
  alarm($self->{TERMINATIONDELAY});
  $logger->info(__PACKAGE__ . ".makeCall GBL WILl BE LOGGING TO: $self->{GBLLOG}");
  foreach my $command (@commands)
  {      
      ## Run command in child
      my $startTime = time();
      eval {
        unless ($pid = fork() ) {
            do {
              $logger->info(__PACKAGE__ . ".makeCall UNABLE TO FORK GBL PROCESS!");
              return ();               
            } unless defined $pid;
            exec("$command 2>&1>>$self->{GBLLOG}");
        }
      };
      if($@){
        $logger->warn(__PACKAGE__ . ".makeCall PROCESS SIGNAL CAUGHT!");
      }
      $logger->info(__PACKAGE__ . ".makeCall PID [$pid] : Started '$command'");
      $masterQ->{jobs}{$pid}{starttime} = $startTime;
      $logger->debug(__PACKAGE__ . ".makeCall SLEEING FOR -> $self->{LAUNCHDELAY}");
      sleep($self->{LAUNCHDELAY});
  }
  while ( ( $pid = wait()) > 0 ) {    # Wait for job exiting
    if($masterQ->{jobs}{$pid}){
      $logger->info(__PACKAGE__ . ".makeCall CHILD PID COLLECTED: $pid");
      $logger->info(__PACKAGE__ . ".makeCall CHILD PID EXIT CODE: $?");
      if($?){
        $successFlag = 0;
      }
      delete $masterQ->{jobs}{$pid};
    }else{
      $logger->debug(__PACKAGE__ . ".makeCall SURPRISE PID COLLECTED [$pid] IGNORING");
    }
  }
  if( -e $self->{GBLLOG}){
    open(GBLFILE, $self->{GBLLOG});
    my @gblLog = <GBLFILE>;
    close GBLFILE;
    map { $logger->info(__PACKAGE__ . ".makeCall [GBLLOG]  $_") } @gblLog;
  }
  if($successFlag){
    $logger->info(__PACKAGE__ . ".makeCall GBL TESTS PASSED");
  }else{
    $logger->warn(__PACKAGE__ . ".makeCall GBL TESTS FAILED");
  }
  unlink($self->{GBLLOG}) if ( -e $gblLogFile);
  $SIG{ALRM} = "DEFAULT";
  $SIG{INT} = "DEFAULT";
  $SIG{'__WARN__'} = "DEFAULT";
  return $successFlag;
}

=head2 gblTerminationAlarm

    This function send termination alarm.

=over

=item Argument

    $masterQ

=item Return

    None

=item Usage

    $gblObject->gblTerminationAlarm($masterQ);

=back

=cut

sub gblTerminationAlarm(){
  my $self = shift;
  my $masterQ = shift;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gblTerminationAlarm");
  $logger->warn(__PACKAGE__ . ".gblTerminationAlarm TERMINATION TRIGGERED " . time());
  $logger->warn(__PACKAGE__ . ".gblTerminationAlarm MAXRUNTIME EXCEEDED, PROCEEDING TO TERMINATED EXISTING PIDS");
  foreach my $minion ( keys %{ $masterQ->{'jobs'} } ) {
    $logger->warn(__PACKAGE__ . ".gblTerminationAlarm SENDING PID [$minion] KILL");    
    if (kill 0 => $minion) {
      $logger->debug(__PACKAGE__ . ".gblTerminationAlarm $minion is alive!");
      kill 'KILL', $minion;
    } elsif ($! == EPERM) {             # changed uid
      $logger->debug(__PACKAGE__ . ".gblTerminationAlarm $minion has escaped my control");
    } elsif ($! == ESRCH) {
      print "$minion is deceased.\n";  # or zombied
      $logger->debug(__PACKAGE__ . ".gblTerminationAlarm $minion is deceased");
    } else {
      $logger->warn(__PACKAGE__ . ".gblTerminationAlarm Odd; I couldn't check on the status of $minion: $!");
    }
  }
  
}

=head2 catchSigInt

    This function cleanup GBLLOG.
    unlink($self->{GBLLOG});

=over

=item Argument

    $masterQ

=item Return

    None

=item Usage

    $gblObject->catchSigInt($masterQ);

=back

=cut


sub catchSigInt () {
  my $self = shift;
  my ($masterQ)=shift;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".catchSigInt");
  $logger->warn(__PACKAGE__ . ".catchSigInt CAUGHT SIGINT - ATTEMPTING CLEANUP");
  if (-e $self->{GBLLOG}){
    $logger->warn(__PACKAGE__ . ".catchSigInt GBLLOG EXISTS - UNLINKING");
    unlink($self->{GBLLOG});
  }
}

=head2 catchSigWarn

    This function log the passed warning.

=over

=item Argument

    warning message

=item Return

    None

=item Usage

    $gblObject->catchSigWarn($line);

=back

=cut

sub catchSigWarn () {
 my ($self,$line) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".catchSigWarn");
  $logger->warn(__PACKAGE__ . ".catchSigWarn CAUGHT WARNING STATEMENT");
  $logger->warn(__PACKAGE__ . ".catchSigWarn $line");
}

=head2 gblLog

    This function log the passed message.
    Not in use at this time. Switched to logging.

=over

=item Argument

    message

=item Return

    None

=item Usage

    $gblObject->gblLog($line);

=back

=cut

# no in use at this time...switched to logging.
sub gblLog () {
    my ($self,$line) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gblLog");
    chomp($line);
    my $time = time();
    $logger->info(__PACKAGE__ . ".gblLog [$time]: $line") if defined ($line);
  #  print "STDOUT [$time]: $line\n" if defined ($line);
}

=head2 buildCall

=over

=item Arguments

    -var_file
        Name of the VAR File (ACCORD.var)
    -script_name
        Script name ( absolute Path )
        /export/home/gbl/SIPART/RFC3261Conformance/Presentation_Layer/C2_Called.gbl
    -script_type
        called
        calling

=item Returns

      Command String Array with key value. Key is script type, Values is the command

=item Example

    my @cmd = gbl->buildCall( -var_file => ACCORD.var,
                              -script_name => /export/home/gbl/SIPART/RFC3261Conformance/Presentation_Layer/C2_Called.gbl,
                              -script_type => called,
                              -script_name => /export/home/gbl/SIPART/RFC3261Conformance/Presentation_Layer/C2_Calling.gbl,
                              -script_type => calling );

=back

=cut

sub buildCall(){
  my ($self, $scriptRef) = @_;
  my ($cmd, $includePath, $scriptPath, $varPath, $varString, $logger);
  $varString = ""; $cmd=undef;
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".buildCall");
  $logger->debug(__PACKAGE__ . ".buildCall STARTED");
  if(defined($scriptRef->{'vars'})){
    $logger->info(__PACKAGE__ . ".buildCall SCRIPT VARIABLES ARE DEFINED - PROCESSING");
    while (my ($k, $v) = each %{$scriptRef->{'vars'}} ){
        $varString .= "$k=$v ";        
    }
  }
  $scriptPath = sprintf("%s/%s",$self->{SCRIPTPATH},$scriptRef->{'script'});
  $varPath = sprintf("%s/%s.var",$self->{VARFILES},$self->{DUT});
  if(defined($scriptRef->{'dut'})){
    $logger->debug(__PACKAGE__ . ".buildCall SCRIPT DUT OVER-RIDE DETECTED - USING DUT: $scriptRef->{'dut'}");
    $varPath = sprintf("%s/%s.var",$self->{VARFILES},$scriptRef->{'dut'});
  }
  $logger->debug(__PACKAGE__ . ".buildCall VERIFYING SCRIPT PARAMTER INFORMATION AND PATHS");
  foreach($self->{GBLINCLUDEPATH}, $scriptPath, $varPath){
    if( -e $_){
        $logger->debug(__PACKAGE__ . ".buildCall PATH $_ EXISTS");
    }else{
        $logger->warn(__PACKAGE__ . ".buildCall PATH $_ DOES NOT EXIST");
        return $cmd;  # returns empty command.
    }
  }
  $cmd = sprintf("%s -I %s varfile=%s %s %s",$self->{GBL},$self->{GBLINCLUDEPATH}, $varPath, $varString, $scriptPath);
  $logger->debug(__PACKAGE__ . ".buildCall GENERATED GBL COMMAND:");
  $logger->debug(__PACKAGE__ . ".buildCall $cmd");
  $logger->debug(__PACKAGE__ . ".buildCall INCLUDE PATH: $self->{GBLINCLUDEPATH}");
  return $cmd;
}


=head2 getPort():

    This subroutine gets you available port for use.
    Call it twice for called and calling port.

=over

=item Argument

    It takes input a global port list (@portList) and returns the first not in use port.

=item Return

    Port Number on Success
    0 on Failure.

=item Usage

    my $calledPort;
    unless($calledPort = $gblObject->getPort(@portList)){
      Error - Cannot get port for the script execution on GBL Server [Server Name] .
    }

=back

=cut


sub getPort(){
  my($self,@portNum)=@_;
  my ($cmd, $logger, $retVal, @retVal, $cmd1);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getPort");
  $self->{PORT_DIR} = "/tmp/.port/";
  $cmd1 = "file " . $self->{PORT_DIR} ;
  @retVal = $self->execCmd($cmd1);
  $retVal = join '', @retVal;
    if ($retVal =~ m/No such/ ){
        #Create directory.
        $cmd1 = "mkdir  " . $self->{PORT_DIR} ;
        @retVal = $self->execCmd($cmd1);
        $retVal = join '', @retVal;
        if ( $retVal =~ m/Permission|space/ ){
            logger->error(__PACKAGE__ . " .getPort() Failed to create directory: [$self->{PORT_DIR}]");      
            $main::failure_msg .= "TOOLS:GBL-Port not avaialable; "; 
            return 0;
        }
    }
  foreach ( @portNum ) {
    $cmd = "file " . $self->{PORT_DIR} . "port" . $_;
    @retVal = $self->execCmd($cmd);
    $retVal = join '', @retVal;
    if ( $retVal =~ m/ cannot open/ ){
        $cmd1 = "touch " . $self->{PORT_DIR} . "port" . $_;
        @retVal = $self->execCmd($cmd1);
        $retVal = join '', @retVal;
        if ( $retVal =~ m/ cannot / ) {
            logger->error(__PACKAGE__ . " .getPort() Failed to get port: [$_]");       
            $main::failure_msg .= "TOOLS:GBL-Port not avaialable; ";
            return 0;
        }
        return $_; 
       }       
  }
  $main::failure_msg .= "TOOLS:GBL-Port not avaialable; ";
  return 0;
}

=head2 releasePort()

=over

=item Argument

    $portNum

=item Return

    1 if Success
    0 if Failure

=item Usage

    (unless($gblObject->releasePort($portNum)){
      Error: Failed to release the port [$portNum] ; 
    }

=back

=cut

sub releasePort(){
  my($self,$portNum)=@_;
  my ($cmd, $logger);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".releasePort");
  $self->{PORT_DIR} = "/tmp/.port/";
  $cmd = "rm " . $self->{PORT_DIR}. "port" . $portNum;
  my @retVal = $self->execCmd($cmd);
  my $retVal = join '', @retVal;
  if ( $retVal =~ m/Permission /) {$main::failure_msg .= "TOOLS:GBL-Port not released; ";return 0;}
  # unshift ($portNum, -e);
  return 1;  
}

# Input to this is Name-Value Pair. First argument being the FILENAME
# - VALUE pair. Remaining items are the typical var file name values.
#

=head2 buildVarFile()

=over

=item Argument:

    All the Name, Value pair that you want in a given VAR file. (hash)
    VARFILES are created in /tmp/varfile direcotry.
    Mandatory argument: "fileName", "<nameOftheVarFile>"

=item Return:

    0 on Failure to create VARFILE
    1 on success.

=item Usage:

    my $fstatus = $gblObj->buildVarFile( "fileName",  "ACCORD.var,
                                        "localsip", "0.0.0.0:5072" );

=back

=cut

sub buildVarFile() {
  my($self, %args) = @_;
  my ($retVal, @retVal);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".buildVarFile");
  $self->{VARFILE_DIR} = "/tmp/varfile/";
  
    unless ( $args{fileName} ) {
        $logger->error(__PACKAGE__ . ".buildVarFile() fileName not defiend");
        return 0;
    }
  
  
    my $cmd1 = "file " . $self->{VARFILE_DIR} ;
    @retVal = $self->execCmd($cmd1);
    $retVal = join '', @retVal;
    if ($retVal =~ m/No such/ ){
        #Create directory.
        $cmd1 = "mkdir  " . $self->{VARFILE_DIR} ;
        @retVal = $self->execCmd($cmd1);
        $retVal = join '', @retVal;
        if ( $retVal =~ m/Permission|space/ ){
            logger->error(__PACKAGE__ . " .buildVarFile() Failed to create directory: [$self->{VARFILE_DIR}]");       
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0;
        }
    }
    my $cmd = "file " . $self->{VARFILE_DIR}.$args{fileName};
    @retVal = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".buildVarFile() File command [$cmd] return value [@retVal]");
    $retVal = join '', @retVal;
    $logger->info(__PACKAGE__ . ".buildVarFile() File command [$cmd] return value [$retVal]");
    if ( $retVal !~ m/ cannot open/ ){
        $logger->error(__PACKAGE__ . ".buildVarFile() VAR file [$args{fileName}} already exists");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0; 
    }
    
    $cmd = "touch " . "$self->{VARFILE_DIR}" . $args{fileName} ;
    @retVal = $self->execCmd($cmd);
    $retVal = join '', @retVal;
    
    if ( $retVal =~ m/ cannot open / ){
        $logger->error(__PACKAGE__ . ".buildVarFile() Failed to open variable file [$args{fileName}] for writing");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return -1;
    }
    

    foreach my $key (keys %args) {
        print "$key = $args{$key}\n";
       # $cmd = "echo " . " \"" . "\\\$" . $key ."=" . "\\\"" .$args{$key} . "\\\"" . " \" " . " >> " . $self->{VARFILE_DIR} . $args{fileName}  ;
        $cmd = "echo '\$$key=\"$args{$key}\"\;' >> $self->{VARFILE_DIR}/$args{fileName}";
        @retVal = $self->execCmd($cmd);
        $logger->info(__PACKAGE__ . ".buildVarFile() File command [$cmd] return value [@retVal]");
        $retVal = join ''. @retVal;
        if ( $retVal =~ m/ Permission denied / ){
            $logger->error(__PACKAGE__ . ".buildVarFile() Cannot write to VAR file [$args{fileName}]");
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0; 
        }
    }
    
    return 1;
}

=head2 removeVarFile()

    This subroutine remove the passed var file.

=over

=item Argument:

    var file name

=item Return:

    None

=item Usage:

    my $fstatus = $gblObj->removeVarFile( 'ACCORD.var' );

=back

=cut

sub removeVarFile() {
  my ($self, $filename) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".removeVarFile");
  my ($cmd, @retVal, $retVal);
  $self->{VARFILE_DIR} = "/tmp/varfile/"; 
  
  $cmd = "rm . " . $self->{VARFILE_DIR} . $_ ;
  
  @retVal = $self->execCmd($cmd);
  $retVal = join '' . @retVal;
  if ($retVal =~ m/ Permission | No such / ) {
    $logger->error(__PACKAGE__ . ".buildVarFile() Cannot delete the VAR file [$self->{VARFILE_DIR} . $_] ");
    $main::failure_msg .= "TOOLS:GBL-Cannot delete varfile; ";
  }
  return;
}

=head2 runScript

    This subroutine create a telnet connection to the gbl server and execute the passed script (command).

=over

=item Argument:

    - $cmds
    - $timeout

=item Return:

    0 on success
    1 on call failure
    -1 on login failure or script failure

=item Usage:

    my $status = $gblObj->runScript($cmds, $timeout);

=back

=cut


#  $obj->runScript() is used by makeCall()
#  TBD: make it robust by using SIG Handler
#  
sub runScript() {
    my ($self,$cmds, $timeout ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runScript()");
    my ($failures, $failures_threshold, @retvalue);
    my $telObj= undef ;
    my $retVal = undef;
    
    $logger->info(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] Command: [$cmds], timeout: [$timeout] ");
        
    if(!$self->{COMM_TYPE}){
        $self->{COMM_TYPE}="TELNET";
    }
            
    if(!$self->{OBJ_PORT}){
        $self->{OBJ_PORT}=23;
    }
    if(!$self->{OBJ_USER}){
        $self->{OBJ_USER} = "gbl";
    }
    if(!$self->{OBJ_PASSWORD}){
        $self->{OBJ_PASSWORD} = "gbl007";
    }
    
    if(!$self->{PROMPT}){
        $self->{PROMPT} = '/hills%|.*[\$#%>] $/';;
    }
    
    if(!$self->{OUTPUT_RECORD_SEPARATOR}){
        $self->{OUTPUT_RECORD_SEPARATOR} = "\r";;
    }
    
    if(!$self->{BINMODE}){
        $self->{BINMODE} = 0;;
    }
    
    $logger->info(__PACKAGE__ . ".runScript Connecting to [$self->{OBJ_HOST}] with [$self->{COMM_TYPE}] and port [$self->{OBJ_PORT}]");

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
            $logger->warn(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] Failed to create a session object");
            #$failures += 1;
            $main::failure_msg .= "TOOLS:GBL-GBL object error; ";
            return -1;
        }
            unless ( $telObj->open($self->{OBJ_HOST}) ) {
                $logger->warn(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] Net::Telnet->open() failed");
                #$failures += 1;
                $main::failure_msg .= "TOOLS:GBL-GBL Login error; ";
                return -1;
            }
            unless ( $telObj->login($self->{OBJ_USER},$self->{OBJ_PASSWORD}) ) {
                $logger->warn(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] User: [$self->{OBJ_USER}]");
                $logger->warn(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] Net::Telnet->login() failed");
                #$failures += $failures_threshold;
                $main::failure_msg .= "TOOLS:GBL-GBL Login error; ";
                return -1;
            }

         #   last; # We must have connected; exit the looP
    

      $logger->info(__PACKAGE__ . ".runScript [$self->{OBJ_HOST}] Net::Telnet->login() succeeded. ");
   # if(defined(@cmds->{'timeout'})){
        #log timeout being used.
    #    $timeout = @cmds->{'timeout'};
   # } else {
        #default timeout
    #    $timeout = $self->{DEFAULTTIMEOUT};
    #}
    $logger->info(__PACKAGE__ . ".runScript() [$self->{OBJ_HOST}] Received Cmd [$cmds] for telObject [$telObj]");
    
    @retvalue = $telObj->cmd(String => $cmds,
                             Timeout => $timeout,
                             Prompt => $self->{PROMPT});
    
   # $logger->error(__PACKAGE__ . ".runScript(). Script Execution Output [@retvalue]");
    
    $retVal = join '', @retvalue;
    
    
   # $logger->error(__PACKAGE__ . ".runScript(). Script Execution Output [$retVal]");
    if ( $retVal =~ m/die/mi ) {
        $logger->error(__PACKAGE__ . ".runScript(). Script Failed on remote host [$self->{OBJ_HOST}]");
        $logger->error(__PACKAGE__ . ".runScript(). Script Failed with output [$retVal]");
        $main::failure_msg .= "UNKNOWN:GBL-GBL call error; ";
        return 1;
    }
    elsif( $retVal =~ m/No such /mi )  {
        $logger->error(__PACKAGE__ . ".runScript(). Script Execution Failed on remote host [$self->{OBJ_HOST}]");
        $logger->error(__PACKAGE__ . ".runScript(). Script Execution Failed with output [$retVal]");
        $main::failure_msg .= "TOOLS:GBL-GBL script error; ";
        return -1;
    }
    else
    {
        $logger->info(__PACKAGE__ . ".runScript(). Script Execution Successful on remote host [$self->{OBJ_HOST}]");
        return 0;
    }
} # end of runScript


=head2 makeCall()

    This method will execute a list of GBL commands passed to it in separate sessions.
    $obj->makeCall(@cmds);

=over

=item Arguments

    -cmd_array : array of gbl command to be run.
    -timeout : timeout Value in seconds. It defaults to 10 Seconds.

=item Return:

    0 for success
    1 for failure

=item Usage:

    @cmds = ( 'cd /export/home/gbl/SIPART/ ; /usr/local/bin/gbl -I /tmp/varfile/ varfile=$filename /export/home/gbl/SIPART/RFC3261Conformance/Session_Layer/C53-3_Called.gbl',
              'cd /export/home/gbl/SIPART/ ; /usr/local/bin/gbl -I /tmp/varfile/ varfile=$filename  /export/home/gbl/SIPART/RFC3261Conformance/Session_Layer/C53-3_Calling.gbl',
              'cd /export/home/gbl/SIPART/ ; /usr/local/bin/gbl -I /tmp/varfile/ varfile=$filename  /export/home/gbl/SIPART/RFC3261Conformance/Session_Layer/C53-3_ThirdLeg.gbl');
    $status = $gblObj->makeCall(@cmds);     

=back

=cut

sub makeCall() {
    my($self, @cmds, $timeout) = @_;   ### $timeout is never defined since @cmds is not a reference
    my $sub = "makeCall";
  
    my $error_flag = 0 ;
    my $prompt = $self->{PROMPT};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".makeCall()");

    $logger->info(__PACKAGE__ . ".makeCall() cmds= @cmds");
    if( $cmds[ -1] =~ m/^\d+$/) {
        ### timeout mistakenly appended to cmds array
        $timeout = pop( @cmds);
    }
    my ($failures, $cmd, $cmdCount, @retvalue, $retVal, $status,$pid);
    my $successFlag = 1 ;
    $logger->info(__PACKAGE__ . ".makeCall() Received Command [@cmds]");
    
	if ( ! defined $timeout) {
		$timeout = "900";
    	$logger->info(__PACKAGE__ . ". Timeout Not Defined Using Default: $timeout");
	}

    $logger->info(__PACKAGE__ . ".makeCall() timeout= $timeout");

    my $counter = @cmds;
    $logger->debug(__PACKAGE__ .".makeCall : Command count is : [" . $counter . "] \n" );
    --$counter;
    my (@gblObj, @results,@waiting, @gblPass);
    my $res_ref;

    $prompt = undef;
    foreach my $i (0..$counter) {
      $logger->debug(__PACKAGE__ .".makeCall : Executing : " . $cmds[$i]);
      $gblObj[$i]= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} );
      $prompt = $gblObj[$i]->{conn}->last_prompt;
      $logger->debug(__PACKAGE__ .".makeCall : Prompt recovered : " . $prompt );
      $results[$i]= $gblObj[$i]->{conn}->print($cmds[$i]);
    }
    foreach my $i (0..$counter) {
      $logger->debug(__PACKAGE__ .".makeCall : Waiting for prompt : \$gblObj[" . $i . "]... ");
      unless (($results[$i],$waiting[$i]) = $gblObj[$i]->{conn}->waitfor( -string => $prompt, 
                                                                  -timeout => $timeout )) {
          $logger->error(__PACKAGE__ . ".$sub  GBL did not complete in $timeout seconds.");

          # Waited too long! Abort GBL execution, by issuing a "Ctrl-C"
          $self->{conn}->cmd(-string => "\cC",
                           -prompt => $prompt);
          $logger->error(__PACKAGE__ . ".$sub  GBL killed using Ctrl-C");
          $main::failure_msg .= "UNKNOWN:GBL-GBL command error; ";
          $error_flag = 1;
      } 
      $logger->debug(__PACKAGE__ .".makeCall : Output $i -- " . $results[$i] );
      $logger->debug(__PACKAGE__ .".makeCall : waiting $i -- " .  $waiting[$i] );
      $gblObj[$i]->{conn}->close;
      my @verRes = split /\n/, $results[$i];
      $gblPass[$i] = 1;
      if( $error_flag == 1) {
          $logger->error(__PACKAGE__ .".makeCall : timeout after $timeout sec");
          $gblPass[$i]=0;
          last;
      }

      foreach (@verRes) {
        if ($gblPass[$i] &
            ( $_ =~ /die/i |
              $_ =~ /no such/i |
              $_ =~ /FATAL/i |
              $_ =~ /can not open file/i |
              $_ =~ /Forgot end quotes/ | 
              $_ =~ /Segmentation fault/ |
			  $_ =~ /parse error/i |
			  $_ =~ m/parse error, syntax error/ 
            )
           ) {
          $gblPass[$i]=0;
          $logger->error(__PACKAGE__ .".makeCall : Error in the GBL execution output");
          $logger->error(__PACKAGE__ .".makeCall : Error : " . $_);
          last;
        }
      }
    }
    foreach (@gblPass) {
      if ($_ == 0) {
        $logger->error(__PACKAGE__ .".makeCall : Returning on makeCall Failure");
        $main::failure_msg .= "UNKNOWN:GBL-GBL command error; ";
        return 0;
      }
    }
    $logger->info(__PACKAGE__ .".makeCall : Returning on makeCall Success");
    return 1;
}
 
 sub gblLogScript(){
  my($self,$scriptName)=@_;
  my ($cmd, $logger);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gblLogScript");
  $self->{SIPART_DIR} = "/export/home/gbl/SIPART";
  $cmd = "cd " . $self->{SIPART_DIR};
  my @retVal = $self->execCmd($cmd);
  my $retVal = join '', @retVal;
  if ( $retVal =~ m/Permission /)
  {$logger->error(__PACKAGE__ . ".gblLogScript() Cannot locate directory [$self->{SIPART_DIR}]...");}
  
  my $cmd1 = "/usr/local/bin/gbl -I /tmp/varfile/ varfile=CAMEL.var " . $scriptName;
  
  my @retVal1 = $self->runScript($cmd1);
  my $retVal1 = join '', @retVal1;
  if ( $retVal1 =~ m/Permission| No such| Not /)
  {
   $logger->error(__PACKAGE__ . ".gblLogScript() Logging Script not found...");
   $main::failure_msg .= "TOOLS:GBL-GBL path error; ";
  }
  # unshift ($portNum, -e);
  return @retVal1;  
}
 
=head2 trim

    This subroutine remove leading/trailing spaces.

=over

=item Argument:

    - string

=item Return:

    trimmed string

=item Usage:

    my $new_str = SonusQA::GBL::trim($str);

=back

=cut

sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

=head2 createVarfileFromTemplate()

    This function takes a template of a GBL varfile and substitutes the digits representing 
    the GSX with the appropriate GSX digits defined by the .ing_gsx_id and .eg_gsx_id arguments 
    and outputs to a file in the /tmp directory indicated by "filename" argument. 

=over

=item Arguments :

    -varfile_path <path where the GBL varfile will get generated on 
   the GBL server. Defaults to the /tmp/GBL_VARFILES directory>

    -filename <name of GBL varfile to generate. Will generate in the 
           directory specified by .varfile_path option or default 
           to /tmp/GBL_VARFILES directory>

    -template <full name and path to UK GBL template>

    -ing_gsx_id  <GSX Id number of originating GSX>

    -eg_gsx_id   <GSX Id number of destination GSX>

    -ing_gsx_name <name of ingress GSX>

=item Return Values :

    1 . if command successful
    0 . otherwise (failure)

=item Example :

    $gblObj->createVarfileFromTemplate( 
    -varfile_path => '/home/mysuser/GBL_VARFILES', 
    -filename => 'ERNIE.var',
    -template => '/home/gblstuff/TEMPLATE/UK_VARFILE_TEMPLATE.var',
    -ing_gsx_id => '2',
    -eg_gsx_id  => '23',
    -ing_gsx_name => 'ERNIE');

=item Author :
 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub createVarfileFromTemplate {

    my($self,%args) = @_;
    my $sub = "createVarfileFromTemplate()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @templateFileContent;
    my ($ingGsxIDPad, $egGsxIDPad);
    my %sampleSignature = ( -filename     => '',
                           -ing_gsx_id   => '',
                           -eg_gsx_id    => '',
                           -ing_gsx_name => '',
                           );

    $logger->debug(" Entered $sub with args - ", Dumper(%args));

    foreach my $keyz (keys %sampleSignature) {
        my $value = $args{$keyz};
        if (! defined $args{$keyz} || ($value eq ""))
        {
            $logger->error(__PACKAGE__ . ".$sub mandatory arg \"$keyz\" missing.");
            $logger->debug(" Leaving $sub with returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0;
        }
    }
    my $filePath   = trim( $args{-varfile_path} );
    my $fileName   = trim( $args{-filename} );
    my $template   = trim( $args{-template} );
    my $ingGsxID   = trim( $args{-ing_gsx_id} );
    my $egGsxID    = trim( $args{-eg_gsx_id} );
    my $ingGsxName = trim( $args{-ing_gsx_name} );

    if ( (!defined $args{-varfile_path}) ||
         ($filePath eq "") ) {

        $logger->debug(__PACKAGE__ . ".$sub \"varfile_path\" is not specified, defaulting to /tmp/GBL_VARFILES.");
        $filePath = "\/tmp\/GBL_VARFILES";
    }

    if ( (!defined $args{-template}) ||
         ($template eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"template\" is not specified.");
        $logger->debug(" Leaving $sub with returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0;
    }
    else
    {
        my $cmd = "\\cat $template";
        @templateFileContent = $self->execCmd($cmd);
        $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@templateFileContent]");

        my @retVal = $self->execCmd("echo \$?");
        if( ($retVal[0] != 0) || ($#templateFileContent <= 0) )
        {
            $logger->error(__PACKAGE__ . ".$sub empty/inaccessible template file - $template.");
            $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0;
        }
    }

    # Check and create filePath

    my $cmd = "\\ls $filePath";
    my @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");
    if ( $retVal[0] =~ m/No such file or directory/i ) {
        $logger->debug(__PACKAGE__ . ".$sub $filePath does not exists, attmepting to create.");
        
        $cmd = "mkdir -p $filePath"; # -p -> make parent directories as needed.
        @retVal = $self->execCmd($cmd);
        $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

        @retVal = $self->execCmd("echo \$?");
        if( $retVal[0] != 0 )
        {
            $logger->error(__PACKAGE__ . ".$sub unable to create $filePath.");
            $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
            return 0;
        }
    }

    # Create varFile
    $cmd = "\\touch $filePath" . "\/" . "$fileName";
    @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub unable to create $filePath"."\/".$fileName);
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0;
    }

    $ingGsxIDPad = (length($ingGsxID) == 1 ) ? ( '0' . $ingGsxID) : $ingGsxID;
    $egGsxIDPad  = (length($egGsxID) == 1 ) ? ( '0' . $egGsxID) : $egGsxID;
    $logger->debug(__PACKAGE__ . ".$sub ingGsxIDPad-$ingGsxIDPad, egGsxIDPad-$egGsxIDPad.");

    my $sipServerIP = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    if ( $sipServerIP == undef ||
         $sipServerIP eq "" )
    {
        $logger->error(__PACKAGE__ . ".$sub" . '$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}' . " not defined.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub sipServerIP - $sipServerIP");

    my @writeArray;
    my $writeLine;
    foreach ( @templateFileContent )
    {
        my $line = trim ($_);

        if ( $line =~ /SIP_SERVER_IP/ )
        {
           $line =~ s/\#\+\#SIP_SERVER_IP\#\+\#/$sipServerIP/g; 
        }
        if ( $line =~ /ING_GSX_PAD/ ) # as ING_GSX_PAD/SIP_SERVER_IP/ are in the same line (hence not elsif)
        {
           $line =~ s/\#\+\#ING_GSX_PAD\#\+\#/$ingGsxIDPad/g; 
        }
        elsif ( $line =~ /ING_GSX_NAME/ )
        {
           $line =~ s/\#\+\#ING_GSX_NAME\#\+\#/$ingGsxName/g;
        }
        elsif ( $line =~ /ING_GSX_DIG1/ )
        {
           my $firstDig = substr $ingGsxIDPad, 0, 1;
           $line =~ s/\#\+\#ING_GSX_DIG1\#\+\#/$firstDig/g;
        }
        elsif ( $line =~ /ING_GSX_DIG2/ )
        {
           my $secDig = substr $ingGsxIDPad, 1, 1;
           $line =~ s/\#\+\#ING_GSX_DIG1\#\+\#/$secDig/g;
        }
        elsif ( $line =~ /EG_GSX_PAD/ )
        {
           $line =~ s/\#\+\#EG_GSX_PAD\#\+\#/$egGsxIDPad/g;
        }
        elsif ( $line =~ /EG_GSX_DIG1/ )
        {
           my $firstDig = substr $egGsxIDPad, 0, 1;
           $line =~ s/\#\+\#EG_GSX_DIG1\#\+\#/$firstDig/g;
        }
        elsif ( $line =~ /EG_GSX_DIG2/ )
        {
           my $secDig = substr $egGsxIDPad, 1, 1;
           $line =~ s/\#\+\#EG_GSX_DIG1\#\+\#/$secDig/g;
        }
        elsif ( $line =~ /EG_GSX/ )
        {
           $line =~ s/\#\+\#EG_GSX\#\+\#/$egGsxID/g;
        }
        elsif ( $line =~ /ING_GSX/ )
        {
           $line =~ s/\#\+\#ING_GSX\#\+\#/$ingGsxID/g;
        }

        $line =~ s/\$/\\\$/g;
        $writeLine = $writeLine . $line . "\n";    

    }

    $cmd = "echo \"". $writeLine . "\" > " . $filePath . "\/" . $fileName;
    @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub could not write to $filePath"."\/".$fileName);
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Varfile creation failed; ";
        return 0;
    }
    
    return 1;
}

=head2 startExecContinue()

    This function takes a varfile name, GBL script name and GBL Log file name and starts 
    the execution of a GBL script in the background logging to the specified GBL log file.

=over

=item Arguments :

    -varfile => <name of GBL varfile to use with GBL script>

    -varfile_path => <name of include path to VARFILES. Defaults to 
                    /tmp/GBL_VARFILES>

    -nfs_mount => <optional full path to nfs directory mounted on GBL 
                    server. Defaults to /sonus/SonusNFS> and will be 
                    assigned to the $nfs_mount variable.

    -logfile => <log file name of GBL log file>

    -logfile_subdir => <local sub directory path to log file on GBL 
                       server located under ${nfs_mount}/AUTOMATION)>

    -script => <Full path and script name of GBL script to execute>

=item Return Values :

    The function returns the PID if successful or 0 otherwise.

=item Example :

    $gblobj->startExecContinue(-varfile_path => '/tmp/GBL_VARFILES',
                               -varfile => 'ERNIE.var',
                               -script => '/a/file/location/KDDI/UK10612_Called.gbl',
                               -logfile => 'mytestid_GBL_timestamp.log');

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub startExecContinue 
{

    my($self,%args) = @_;
    my $sub = "startExecContinue()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(" Entered $sub with args - ", Dumper(%args));
    my %sampleSignature = ( -varfile       => '',
                           -logfile        => '',
                           -logfile_subdir => '',
                           -script         => '',
                           );

    foreach my $keyz (keys %sampleSignature) {
        my $value = $args{$keyz};
        if (! defined $args{$keyz} || ($value eq ""))
        {
            $logger->error(__PACKAGE__ . ".$sub mandatory arg \"$keyz\" missing.");
            $logger->debug(" Leaving $sub with returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-Mandatory Values missing; ";
            return 0;
        }
    }

    my $filePath   = trim( $args{-varfile_path} );
    my $fileName   = trim( $args{-varfile} );
    my $nfsMount   = trim( $args{-nfs_mount} );
    my $logFile    = trim( $args{-logfile} );
    my $logFileDir = trim( $args{-logfile_subdir} );
    my $script     = trim( $args{-script} );

    if ( (!defined $args{-varfile_path}) ||
         ($filePath eq "") ) 
    {
        $logger->debug(__PACKAGE__ . ".$sub \"varfile_path\" is not specified, defaulting to /tmp/GBL_VARFILES.");
        $filePath = "\/tmp\/GBL_VARFILES";
    }
    if ( (!defined $args{-nfs_mount}) ||
         ($script eq "") ) 
    {
        $logger->debug(__PACKAGE__ . ".$sub \"nfs_mount\" is not specified, defaulting to /sonus/SonusNFS.");
        $nfsMount = "\/sonus\/SonusNFS";
    }

    #Check file path
    my $cmd = "\\ls $filePath"."\/".$fileName;
    my @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");
 
    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub $filePath"."\/"."$fileName does not exist.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }

    # Check gbl-file exists.
    $cmd = "\\ls $script";
    @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub gbl-scrip $script does not exist.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }

    #Check log-file path
    my $logDirName = $nfsMount . "\/AUTOMATION\/" . $logFileDir;
    $cmd = "\\ls $logDirName";
    @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");
 
    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->debug(__PACKAGE__ . ".$sub $logDirName does not exist, attempting to create.");
        $cmd = "mkdir -p $logDirName"; 
        @retVal = $self->execCmd($cmd);
        $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

        @retVal = $self->execCmd("echo \$?");
        if( $retVal[0] != 0 )
        {
            $logger->error(__PACKAGE__ . ".$sub could not create $logDirName.");
            $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
            return 0;
        }
    }

    # Is log file writeable?
    $cmd = "\\touch $logDirName" . "\/" . $logFile;
    @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

    @retVal = $self->execCmd("echo \$?");
    if( $retVal[0] != 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub". " unable to create logfile " . $logDirName . "\/" . $logFile);
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }

    ###  Execute Script
    my $pid=0;
    $cmd = "$self->{GBL} -I $filePath varfile=$fileName $script > $logDirName"."\/"."$logFile &";
    #$cmd = "$self->{GBL} /home/nsarup/a.pl &";
    #$cmd = "$self->{GBL} $script > $logDirName"."\/"."$logFile &";

    # Need the following code to get around background process problem
    # cmd function does not seem to "return" for a background process.
    @retVal = $self->{conn}->cmd("export PS1=\"# \"");
    $self->{conn}->prompt('/#\s+/');

    my @cmdretVal = $self->{conn}->cmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@cmdretVal]");
    $self->{conn}->prompt('/.*[\$#%>] $/');

    $pid = trim( (split(/]/, $cmdretVal[0]))[1] );
    my $processStarted = 0;

    if ($pid eq "") {
        $logger->error(__PACKAGE__ . ".$sub unable to get PID/start gbl script.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }
    else {
        # Check pid is still there.
        sleep 2;
        @retVal = $self->execCmd("ps | grep $pid | egrep -v grep");
        $logger->debug(__PACKAGE__ . ".$sub ps command return value [@retVal]");
        foreach ( @retVal )
        {
            if ( m/^\s*$pid\s+\S+/ )
            {
                # pid still there
                $logger->debug(__PACKAGE__ . ".$sub successfully started GBL script");
                $processStarted = 1;
                last;
            }
        }
        
    }
    
    if ( $processStarted == 1 ) {
        $logger->debug(" Leaving $sub with returnCode(pid) - $pid.");
        return $pid;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub unable to start gbl script.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }
}

=head2 isScriptRunning()

  This function takes a process ID as input and if the GBL process 
  is still executing then it returns 1 otherwise it returns 0.

=over

=item Arguments :

  -pid => Process-ID.

=item Return Values :

  2  . if script is still running
  1  . no script running
  0  . otherwise (error conditions)

=item Example :

    $gblobj->isScriptRunning(-pid => '1234');

=item Author :
 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub isScriptRunning
{

    my($self,%args) = @_;
    my $sub = "isScriptRunning()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(" Entered $sub with args - ", Dumper(%args));

    my $pid = trim( $args{-pid} );

    if ( (!defined $args{-pid}) ||
         ($pid eq "") )
    {
        $logger->error(__PACKAGE__ . ".$sub mandatory arg \"-pid\" is not specified.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Mandatory Values missing; ";
        return 0;
    }

    my $cmd = "\\ps -e | grep $pid | egrep -v grep";
    my @retVal = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

    if( $#retVal < 0 )
    {
        $logger->debug(__PACKAGE__ . ".$sub process $pid is not running.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 1.");
        return 1;
    }
    else 
    {
        foreach (@retVal)
        {
            if ( m/^\s*$pid\s+\S+/i )
            {
                $logger->debug(__PACKAGE__ . ".$sub process $pid is still running.");
                $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 2.");
                return 2;
            }
            elsif ( m/^error/i )
            {
                $logger->debug(__PACKAGE__ . ".$sub error in executing \"ps\" command.");
                $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
                $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
                return 0;
            }
        }
    }

    $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 1.");
    return 1;
}

=head2 stopExec()
 
  This function takes a process ID as input and if the GBL process is still executing then it kills the process.
  The function returns 1 (success) if the process was not running or was killed successfully and 0 otherwise.

=over

=item Arguments :

  -pid => Process-ID.

=item Return Values :

  1  . if command successful
  0  . otherwise (failure)

=item Example :

  $gblobj->stopExec(-pid => '1234');

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub stopExec
{

    my($self,%args) = @_;
    my $sub = "stopExec()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(" Entered $sub with args - ", Dumper(%args));

    my $pid = trim( $args{-pid} );

    if ( (!defined $args{-pid}) ||
         ($pid eq "") )
    {
        $logger->error(__PACKAGE__ . ".$sub mandatory arg \"-pid\" is not specified.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-Mandatory Values missing; ";
        return 0;
    }

    my $scriptStatus = $self->isScriptRunning(-pid => $pid);

    if ( $scriptStatus == 1 ) # script not running
    {
        $logger->debug(__PACKAGE__ . ".$sub scriptStatus-$scriptStatus, script not running.");
        return 1;
    }
    elsif ( $scriptStatus == 2 ) # Script running
    {
        my $cmd = "\\kill -9 $pid";
        my @retVal = $self->execCmd($cmd);
        $logger->debug(__PACKAGE__ . ".$sub command [$cmd] return value [@retVal]");

        @retVal = $self->execCmd("echo \$?");
        if( $retVal[0] != 0 )
        {
            $logger->error(__PACKAGE__ . ".$sub. \"kill\" command failed on pid-$pid." );
            $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
            $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub. \"kill\" command successfull on pid-$pid." );
        return 1;
    }
    else # Command error
    {
        $logger->error(__PACKAGE__ . ".$sub error in \"isScriptRunning\", cannot determine status.");
        $logger->debug(__PACKAGE__ . " Leaving $sub returnCode - 0.");
        $main::failure_msg .= "TOOLS:GBL-GBL command error; ";
        return 0;
    }
}

1;
