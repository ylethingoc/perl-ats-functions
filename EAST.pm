package SonusQA::EAST;

=pod

=head1 NAME

 SonusQA::EAST- Perl module for Sonus Networks Nethawk EAST CLI interaction

=head1 SYNOPSIS

 use ATS;  # This is the base class for Automated Testing Structure
  
 my $obj = SonusQA::EAST->new(
                              B<#REQUIRED PARAMETERS>
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name - usually admin>',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_COMMTYPE => "<TELNET | SSH>",
                              
                              # OPTIONAL PARAMETERS:
                              # CURRENTLY NONE
                              );
                               
 PARAMETER DESCRIPTIONS:
    OBJ_HOST
      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_USER
      The user name or ID that is used to 'login' to the device. 
    OBJ_PASSWORD
      The user password that is used to 'login' to the device. 
    OBJ_COMMTYPE
      The session or connection type that will be established.  
      
 FLAGS:
    NONE
    
=head1 DESCRIPTION

 This module provides an interface for the NetHAWK EAST CLI
 This module will allow scripts to remotely execute EAST scripts from automated test cases.
 This module extends SonusQA::Base

=head1 AUTHORS

 Darren Ball <dball@sonusnet.com>  alternatively contact <sonus-auto-core@sonusnet.com>.
 See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, XML::Simple, Storable, Data::Dumper, SonusQA::Utils,

=head1 ISA

 SonusQA::Base, SonusQA::GSX::GSXHELPER, SonusQA::GSX::GSXLTT

=head1 SUB-ROUTINES

=cut


use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use Module::Locate qw / locate /;
our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

=pod

=head1 B<SonusQA::EAST::doInitialization()>

=over 6

=item Description:

 Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically, use to set Object 
 specific flags, paths, and prompts. This library does not use the XML Library infrastructure.
 This routine sets defaults for:  EAST CLI path (assumed: /export/home/autouser/EastCLI.exe)
  
=item Arguments:

 NONE 

=item Returns:

 NOTHING   

=back

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#:]\s$/';
  #$self->{PROMPT} = '/.*[#\$%]/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{CLI} = "/export/home/autouser/EASTCLI.exe || /export/home/autouser/EastCLI.exe";
  # Note: For SuSE Linux, the following line had to be changed
  # Orginal Line: test -x /usr/bin/tset && /usr/bin/tset -I -Q 
  # New Line    : test -x /usr/bin/tset && /usr/bin/tset -I -Q -m network:vt100
  # SuSE Linux and possibly others do not like 'network';
}

=pod

=head1 B<SonusQA::EAST::setSystem()>

=over 6

=item Description:

 Base module over-ride.  This routine is responsible to completeing the connection to the object.  It performs some basic operations on the Object to enable 
 a more efficient automation environment.
 Some of the items or actions is it performing:
    Traverses down the EAST CLI heirarchy - answers multiple question automatically (Menu Options) in order to get to the Load Engine interface.    

=item Arguments:

 NONE 

=item Returns:

 NOTHING   

=back

=cut

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results, $ok, $lastline);
  
  # Adding a check here to ensure that the user supplies an IP address for OBJ_HOST.
  &error("EAST CLI REQUIRES OBJ_HOST TO BE IP ADDRESS - PLEASE ALTER YOUR INSTANTIATION TO USE IP")
          unless( $self->{'OBJ_HOST'} =~ m/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/);
  
  # DEBUG:
  # [autouser@ceast1 ~]$ ./EastCLI.exe
  # EASTCLI>Enter remote EAST host(IP-Address): 10.9.16.197
  # EASTCLI/10.9.16.197>3
  # EASTCLI/10.9.16.197/LoadEngine>    
  #
  $self->{conn}->last_prompt("");
  #$prevPrompt = $self->{conn}->prompt('/.*\(IP-Address\):.*$/');
  $logger->info(__PACKAGE__ . ".setSystem  ATTEMPTING TO ENTER EAST CLI");
  $logger->debug(__PACKAGE__ . ".setSystem  EAST CLI LOCATION BEING USED: $self->{CLI}");
  $self->{conn}->print($self->{CLI});
  $self->{conn}->waitfor(-match => '/.*\(IP-Address.*\):.*$/',
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT}) 
  or &error(__PACKAGE__ . ".setSystem  UNABLE TO GET TO EASTCLI PROMPT");
  
  $logger->debug(__PACKAGE__ . ".setSystem  PASSED FIRST CLI PROMPT SUCCESSFULLY");           
  # Clear prompting
  $self->{conn}->last_prompt("");
  #$self->{conn}->cmd("$self->{'OBJ_HOST'}");
  $self->{conn}->print($self->{'OBJ_HOST'});
  $self->{conn}->waitfor(-match => '/EASTCLI\/.*\>$/',
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
  or &error(__PACKAGE__ . ".setSystem  UNABLE TO GET TO EASTCLI PROMPT");
  
  $logger->debug(__PACKAGE__ . ".setSystem  PASSED SECOND CLI PROMPT SUCCESSFULLY");

  #$self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/.*LoadEngine\>$/');
  #$self->{conn}->cmd("3");
   $self->{conn}->print("3");
  $self->{conn}->waitfor(-match => '/.*LoadEngine\>$/',
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
  or &error(__PACKAGE__ . ".setSystem  UNABLE TO GET TO EASTCLI PROMPT");
  
  $prevPrompt = $self->{conn}->prompt('/.*LoadEngine\>$/');
  
  $logger->debug(__PACKAGE__ . ".setSystem  PASSED THIRD CLI PROMPT SUCCESSFULLY");
  $logger->info(__PACKAGE__ . ".setSystem  ENTERED EAST LOAD ENGINE");
  @results = $self->execCmd('ver');
  $logger->info(__PACKAGE__ . ".setSystem");
  $logger->info(__PACKAGE__ . ".setSystem  RETRIEVING EAST VERSION INFO");
  map { $logger->info(__PACKAGE__ . ".setSystem\t$_") } @results;
  $logger->info(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}

#--------------------------------------------------------------------------------

=head1 B<SonusQA::EAST::startSingleLeg()>

=over 6

=item Description:

 This routine is responsible for waiting for commands started using startSingleLeg. The output from EASTCLI is captured and tested for error on return.
 Typically this routine is not called alone, waitSingleLeg has to be called after this inorder to get the execution results.

=item Arguments:

 timeout in seconds (Optional)

=item Returns:

 0: Failure in invoking the EASTCLI command
 1: Successfull invoking of the EASTCLI command
  
 Note: This does not indicate that the EAST script passed or failed.
       The result needs to be picked up using waitSingleLeg(<timeout>)
  
=item Example(s):
      
 $eastObj->startSingleLeg({
                                "runnerType" => "tc",
                                "script" => $script_name,
                                "block" => 1,
                                "testbed" =>$testbed,
                                "timeout" => 90
                                });
 # Anything else you need to run here while the EAST call is running
   $result = $eastObj->waitSingleLeg(90);
   if ($result) { PASS };
   else { FAIL };
      
=back

=cut

sub startSingleLeg() { 
  my($self,$mKeyVals)=@_;
  my(@runnerTypes, @mandatoryKeys, @cmdResults, 
     $cmd,$logger,$flag,$cmdTimeout, $prematch, $match, $prevTimeout);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startSingleLeg");
  @runnerTypes = qw ( tc ts load testpool);
  @mandatoryKeys = qw ( runnerType script testbed timeout);
  #  example: rt tc TC_PCR982-1.script -testbed SAFARI block -timeout 60
  foreach(@mandatoryKeys) { 
    unless(defined($mKeyVals->{$_})){
            $logger->warn(__PACKAGE__ . ".runScript  MANADATORY KEY [$_] IS MISSING.");
            return 0;
    };
  }
  unless ( grep { $_ eq $mKeyVals->{runnerType} } @runnerTypes ) {  
    $logger->warn(__PACKAGE__ . ".runScript  INVALID RUNNERTYPE SUPPLIED: $mKeyVals->{runnerType} - ERROR");
    return 0;
  }
  if(defined($mKeyVals->{block})){
    if($mKeyVals->{block}){
      $mKeyVals->{block} = "block";
    }else{
      $mKeyVals->{block} = "";
    }
  }else{
    $mKeyVals->{block} = "";
  }
    $self->{PROMPT} = $self->{conn}->last_prompt;
    #$logger->debug("Last prompt saved : $self->{PROMPT}");
  $cmd = sprintf("rs %s %s -testbed %s %s -timeout %s  ",$mKeyVals->{runnerType},$mKeyVals->{script},$mKeyVals->{testbed},$mKeyVals->{block},$mKeyVals->{timeout});
  if(defined($mKeyVals->{timeout})){
    $mKeyVals->{timeout} = $mKeyVals->{timeout} + 30;
    $prevTimeout = $self->{DEFAULTTIMEOUT};
    $self->{DEFAULTTIMEOUT} = $mKeyVals->{timeout};
  }
  $mKeyVals->{timeout} = $mKeyVals->{timeout} + 30;
  if($self->{conn}->print($cmd)) {
        $logger->debug(__PACKAGE__ . ".startSingleLeg  EAST invoked successfully: $cmd");
        return 1;
  }
  else {
        $logger->warn(__PACKAGE__ . ".startSingleLeg  EAST did not invoke command: $cmd");
        $logger->debug(__PACKAGE__ . ".startSingleLeg  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".startSingleLeg  Session Input Log is: $self->{sessionLog2}");
        return 0;
  }
  
}

#--------------------------------------------------------------------------------

=head1 B<SonusQA::EAST::waitSingleLeg()>

=over 6

=item Description:

 This routine is responsible for waiting for commands started using startSingleLeg. The output from EASTCLI is captured and tested for error on return.
 Rudimentary error checking for time out situation is in place.
  
 Typically this routine is not called directly, startSingleLeg has to be called
 before this.

=item Arguments:

 timeout in seconds (Optional)

=item Returns:

 1: Success
 0: Failure
  
=item Example(s):

 $result = $eastObj->waitSingleLeg(90);
 if ($result) { PASS };
 else { FAIL };

=back

=cut


sub waitSingleLeg() {
  my $sub = "waitSingleLeg";
   my ($self, $timeout) = @_;
   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
   }
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".waitSingleLeg");
  my $prompt = $self->{PROMPT};
   my(@runnerTypes, @mandatoryKeys, $cmdTimeout, $prematch, $match, $prevTimeout);
  my $flag = 0;
  my $error_flag = 0  ;
  $logger->debug(__PACKAGE__ . ".waitSingleLeg executing ... ");

  # EASTERRORHANDLE (used for error mode in the waitfor above)
  unless (($prematch, $match) = $self->{conn}->waitfor( -string => $prompt,
                                                  -timeout => $timeout)) {
      $logger->error(__PACKAGE__ . ".$sub  east did not complete in $timeout seconds.");
      $error_flag = 1;
  }
  if ($error_flag == 0 ) {
      $logger->debug(__PACKAGE__ . ".$sub EAST Execution Output: $prematch");
      $logger->info(__PACKAGE__ . ".$sub Detected EAST completion, getting status");
  }
  else {
      $logger->debug(__PACKAGE__ . ".$sub EAST Execution Timedout");
      return 0;
  }
  
  my @cmdResults = split /\n/, $prematch;

  foreach(@cmdResults) {
    if(m/time.*out.*occurs/is) {
        $logger->warn(__PACKAGE__ . ".waitSingleLeg  TIMEOUT CMD RESULT: $_");
        &error(__PACKAGE__ . ".waitSingleLeg  SCRIPT TIMEOUT ERROR - EXITING");
    }
    if(m/Success\s+/) {
        $flag = 1;
        $logger->info(__PACKAGE__ . ".waitSingleLeg  $_ [SUCCESS]");
    }
    if(m/Failure/) {
        $flag = 0;
        $logger->info(__PACKAGE__ . ".waitSingleLeg  $_ [FAILURE]");
    }
  }
  return $flag;  
}

#--------------------------------------------------------------------------------



=pod

=head1 B<SonusQA::EAST::execCmd()>

=over 6

=item Description:

 This routine is responsible for executing commands.  Commands sent to this routine will be executed and tested for error on return.
 Rudimentary error checking for time out situation is in place. Typically this routine is not called directly, other routines call this one.
  
=item Arguments:

 -cmd <Scalar>
  A string of command parameters and values

=item Returns:

 -Array
  This routine will return an array of the results that were sent back by the EAST CLI.1
  
=item Example(s):

 &$obj->execCmd("");

=back

=cut

sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,@cmdResults1,@cmdResults2,$timestamp,$prevBinMode);
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  $prevBinMode = $self->{conn}->binmode(0);
  $self->{CMDRESULTS} = [];
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout=> $self->{DEFAULTTIMEOUT} )) {
    $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
    if (grep /time.*out.*occurs/is, @cmdResults){  # this means there was an error, and the error has the CLI hung.
      #print map { __PACKAGE__ . ".execCmd\t\t$_" } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  SCRIPT TIME OUT DETECTED");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    }else{
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  A DIFFERENT EAST ERROR OCCURRED");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    }
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  if (grep /time.*out.*occurs/is, @cmdResults){  # this means there was an error, and the error has the CLI hung.
    #print map { __PACKAGE__ . ".execCmd\t\t$_" } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  SCRIPT TIME OUT DETECTED");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
  }
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  $self->{conn}->binmode($prevBinMode);
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  sleep(2);
  @cmdResults1 = $self->{conn}->cmd(" ");
  @cmdResults2 = $self->{conn}->cmd(" ");
  chomp(@cmdResults1);
  @cmdResults1 = grep /\S/, @cmdResults1;
  map { $logger->debug(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults1;
  chomp(@cmdResults2);
  @cmdResults2 = grep /\S/, @cmdResults2;
  map { $logger->debug(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults2;
  @cmdResults = (@cmdResults,@cmdResults1,@cmdResults2);  
  return @cmdResults;
}

=pod

=head1 B<SonusQA::EAST::runScript()>

=over 6

=item Description:

 This routine is used to execute EAST CLI commands concerning script execution. This routine can execute any of the following types of scripts:
  
  tc        - TEST CASE
  ts        - TEST SUITE
  load      - LOAD SCRIPT
  testpool  - TEST POOL
  
 This routine will accept any key value pairs, so all parameters for each script type can be sent into this generically, and they will be passed directly to the command.
  
 This routine will attempt to ensure that the 'BLOCK' parameter is passed regardless if it is passed or not.  This may affect script types other than 'tc' or 'ts'.

=item Arguments:

 -KEY VALUES <HASH> [Anonymous structure]
  An anonymous hash structure of key value pairs.

=item Returns:

 -Boolean
  This routine will attempt to decipher the results of the EAST Command.
  It attempt to detect: Success, Failure or Timeout and return the Boolean value that represents the result (Success = 1, Failure/Timeout = 0)
  
=item Example(s):

 Example for TEST CASE execution:
  
 $obj->runScript({"runnerType" => "tc",
                   "script" => "TC_AO3-ISUP_to_ISUP.script",
                   "block" => 1,
                   "testbed" => $gsx1->{'NODE'}->{'1'}->{'NAME'},
                   "timeout" => 90});

=back

=cut

sub runScript() { 
  my($self,$mKeyVals)=@_;
  my(@runnerTypes, @mandatoryKeys, @cmdResults, 
     $cmd,$logger,$flag,$cmdTimeout, $prematch, $match, $prevTimeout);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runScript");
  @runnerTypes = qw ( tc ts load testpool);
  @mandatoryKeys = qw ( runnerType script testbed timeout);
  #  example: rt tc TC_PCR982-1.script -testbed SAFARI block -timeout 60
  unless(defined($mKeyVals)){
          $logger->warn(__PACKAGE__ . ".runScript  MANADATORY KEY VALUE PAIRS ARE MISSING.");
          return 0;
  };
  foreach(@mandatoryKeys) { 
    unless(defined($mKeyVals->{$_})){
            $logger->warn(__PACKAGE__ . ".runScript  MANADATORY KEY [$_] IS MISSING.");
            return 0;
    };
  }
  unless ( grep { $_ eq $mKeyVals->{runnerType} } @runnerTypes ) {  
    $logger->warn(__PACKAGE__ . ".runScript  INVALID RUNNERTYPE SUPPLIED: $mKeyVals->{runnerType} - ERROR");
    return 0;
  }
  if(defined($mKeyVals->{block})){
    if($mKeyVals->{block}){
      $mKeyVals->{block} = "block";
    }else{
      $mKeyVals->{block} = "";
    }
  }else{
    $mKeyVals->{block} = "";
  }
  
  $cmd = sprintf("rs %s %s -testbed %s %s -timeout %s  ",$mKeyVals->{runnerType},$mKeyVals->{script},$mKeyVals->{testbed},$mKeyVals->{block},$mKeyVals->{timeout});
  $flag = 0; # Assume cmd will not work
  if(defined($mKeyVals->{timeout})){
    $mKeyVals->{timeout} = $mKeyVals->{timeout} + 30;
    $prevTimeout = $self->{DEFAULTTIMEOUT};
    $self->{DEFAULTTIMEOUT} = $mKeyVals->{timeout};
  }
  $mKeyVals->{timeout} = $mKeyVals->{timeout} + 30;
  @cmdResults = $self->execCmd($cmd,$mKeyVals->{timeout});
  foreach(@cmdResults) {
    if(m/time.*out.*occurs/is) {
        $logger->warn(__PACKAGE__ . ".runScript  TIMEOUT CMD RESULT: $_");
        &error(__PACKAGE__ . ".runScript  SCRIPT TIMEOUT ERROR - EXITING");
    }
    if(m/Success\s+/) {
        $flag = 1;
        $logger->info(__PACKAGE__ . ".runScript  $_ [SUCCESS]");
    }
    if(m/Failure/) {
        $flag = 0;
        $logger->info(__PACKAGE__ . ".runScript  $_ [FAILURE]");
    }
   if(m/Aborted/) {
        $flag = 0;
        $logger->info(__PACKAGE__ . ".runScript  $_ [ABORTED]");
    }
  }
  $self->{DEFAULTTIMEOUT} = $prevTimeout;
  return $flag;  #$self->getStatistics($mKeyVals->{script});
}


=pod

=head1 B<SonusQA::EAST::getStatistics()>

=over 6

=item Description:

 This routine is used to execute the EAST CLI command 'gs'. 
 The routine will attempt to retrieve and verify the statistics (success or failure) for the script that is provided as an argument.

=item Arguments:

 -SCRIPT <SCALAR>
  The script in which to scan the statistics results for.

=item Returns:

 -Boolean
  This routine will attempt to decipher the results of the EAST 'gs' Command.
  It will simply look for the script name provided and scan for 'success'. If it finds 'success' it will return true (1) else false (0)
  
=item Example(s):

  &$obj->getStatistics("SCRIPTNAME");

=back

=cut

sub getStatistics() { 
  my($self,$script)=@_;
  my(@cmdResults, 
     $cmd,$logger,$flag,$cmdTimeout);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getStatistics");
  
  #  example: rt tc TC_PCR982-1.script -testbed SAFARI block -timeout 60
  unless(defined($script)){
          $logger->warn(__PACKAGE__ . ".getStatistics  MANADATORY SCRIPT NAME MISSING");
          return 0;
  };
  $script =~ s/\..*//;
  $logger->info(__PACKAGE__ . ".getStatistics  LOOKING FOR $script RESULTS");
  $cmd = "gs";
  $flag = 0; # Assume cmd will not work
  @cmdResults = $self->execCmd($cmd, 60);
  $logger->info(__PACKAGE__ . ".getStatistics  CMD RESULTS:");
  foreach(@cmdResults) {
    if(m/^$script/i){
      if(grep /success/i, $_){
        $flag = 1;
        $logger->info(__PACKAGE__ . ".getStatistics  $_ [SUCCESS]");
      }
    }
  }
  return $flag;
}

sub help(){
  my $cmd="pod2text " . locate __PACKAGE__;
  print `$cmd`;
}

sub usage(){
  my $cmd="pod2usage " . locate __PACKAGE__ ;
  print `$cmd`;
}

sub manhelp(){
  eval {
   require Pod::Help;
   Pod::Help->help(__PACKAGE__);
  };
  if ($@) {
    my $cmd="pod2text " . locate __PACKAGE__ ;
    print `$cmd`;
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

1;
