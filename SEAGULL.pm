package SonusQA::SEAGULL;

=head1 NAME

SonusQA::SEAGULL- Perl module for SEAGULL application control.

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION

This module provides an interface for the SEAGULL test tool.
It provides methods for starting and stopping single-shot and load testing, most cli methods returning true or false (0|1).
Control of command input is up to the QA Engineer implementing this class 
allowing the engineer to specific which attributes to use.

=head1 METHODS

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Utils qw(:all);
use File::Basename;
use Module::Locate qw(locate);
use Data::Dumper;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);

=head2 SonusQA::SEAGULL::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub doInitialization {
  my($self, %args)=@_;
	
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)

  $self->{LOCATION} = locate __PACKAGE__ ;

  $self->{PID} = 0; # We will use PID to determine if an instance is running or not,
  $self->{LASTPID} = 0; # We use this to store the previous PID when the simulation is stopped, required
}

=head2 SonusQA::SEAGULL::setSystem()

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the SEAGULL to enable a more efficient automation environment.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub setSystem(){
    my($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
 
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    my($cmd,$prompt, $prevPrompt);
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $self->{DEFAULTTIMEOUT} = 30;
    $self->{CONFIGPATH} = '';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd(" ");
    $self->{conn}->cmd('export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/ats/tools/seagull/bin');
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    
    my $ret = 1;
    my $seagullip = $self->{OBJ_HOST};
    my $cmd1 = "netstat -an | grep $seagullip:3868";
    my @stdout = $self->{conn}->cmd( $cmd1 );
    if(grep {/.*$seagullip:3868\s+.*/} @stdout)
    {
     $logger->error(__PACKAGE__ . ".setSystem: Seagull is already running, so can't proceed.");
     $ret = 0;
    }
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [$ret]");
    return $ret;
}


=head2 SonusQA::SEAGULL::startBackground(<command>)

  Start SEAGULL in the background, used for load testing.

=over

=item Argument

  If <command> is specified, it is expected to be a well formatted set of seagull command line options

  the -bg (background) option is forced on by this method if not specified by the user.

=item Returns

  (Set's $self->{PID} to the PID of the started process).

=back

=cut

sub startBackground {
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startBackground");
  
  unless ($cmd) {
	$logger->error(__PACKAGE__ . ".startBackground mandotory argument \$cmd is missing");
	return 0;
  }
  
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".startBackground  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".startBackground  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".startBackground  ALREADY STARTED");
    }
	return 0;
  } 
  
  # Always run in background mode, no matter what.
  $cmd .= " -bg" unless ($cmd =~ /\-bg/);
  $logger->info(__PACKAGE__ . ".startBackground  Starting seagull with args $cmd");
  
  unless ($self->{CONFIGPATH}) {
    $logger->error(__PACKAGE__ . ".startBackground  CONFIGPATH is missing please specify the value in your feature");
    return 0;
  } else {
    $self->{conn}->cmd("cd $self->{CONFIGPATH}");
  } 
  
  my @lines = $self->{conn}->cmd( $cmd );
  # Get PID
  foreach (@lines) {
	$logger->info(__PACKAGE__ . ".startBackground  $_");
    if(m/^(\d+)$/){
	  $self->{PID} =$_;
	  last;
	}elsif(m/PID/) {
      $logger->info(__PACKAGE__ . ".startBackground  SEAGULL1-PID - Match\n");
      $self->{PID} = $_;
      $self->{PID} =~ s/.*PID\s+\[//g;
      $self->{PID} =~ s/\]//g;
	  last;
	}
  }
  
  chomp $self->{PID};
  if ($self->{PID} == 0) {
    &error(__PACKAGE__ . ".startBackground Failed to get SEAGULL PID, manual cleanup is likely required\n");
  } 

  $self->{LASTPID} = $self->{PID};      
  $logger->info(__PACKAGE__ . ".startBackground  Started SEAGULL with PID $self->{PID}\n");
  
  return 1;
}

=head2 SonusQA::SEAGULL::gracefulStop(<timeout>)

  Send a SIGUSR1 (equivalent to pressing 'q' from the Gui, to cause SEAGULL to stop
  making new calls and exit once all existing calls are done.

=over

=item Argument

  <timeout> in seconds is the number of seconds to wait for the SEAGULL application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.

  Used only for background SEAGULL instances (started with startBackground()

=item Returns

  1 on successful termination
  0 on timeout.

=back

=cut

sub gracefulStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gracefulStop");
  $logger->info( __PACKAGE__ . ".gracefulStop  Terminating SEAGULL, PID=$self->{PID}, timeout = $timeout seconds.");
  
  my $count=0;
  $self->{conn}->cmd("kill -SIGUSR1 $self->{PID}");


  while ($count < $timeout) {
     my @lines=(); 

    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.

     @lines = $self->{conn}->cmd("pidof seagull");
     my $flag =0;
     foreach(@lines){
		if($_ =~m/$self->{PID}/){
			$flag = 1;
		}	
	}

    if ($flag != 1) {
      $logger->info( __PACKAGE__ . ".gracefulStop  SUCCESS.");
      $self->{PID} = 0;
      return 1;
    } else {
      $logger->info( __PACKAGE__ . ".gracefulStop  Waiting for SEAGULL to terminate iteration $count/$timeout.");
    }
    sleep 1;
    $count++;
  }
  $logger->warn( __PACKAGE__ . ".gracefulStop  WARNING - SEAGULL (PID=$self->{PID}) failed to stop.");
  return 0
}

=head2 SonusQA::SEAGULL::hardStop(<timeout>)

  Send a SIGKILL to cause SEAGULL to exit immediately, possibly leaving calls hanging.

=over

=item Argument

  <timeout> in seconds is the number of seconds to wait for the SEAGULL application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.

  Used only for background SEAGULL instances (started with startBackground()

=item Returns

  1 on successful termination
  Calls &error on timeout - SIGKILL is assumed to be an unstoppable force, if this
  fails then we can't vouch for the state of the controlled system, so we might as well bail.

=back

=cut

sub hardStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".hardStop");
  $logger->warn( __PACKAGE__ . ".hardStop  Terminating SEAGULL, PID=$self->{PID}, some calls may be left hanging.");
  
  my $count=0;
  $self->{conn}->cmd("kill -SIGKILL $self->{PID}");
  while ($count < $timeout) {
  
    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.
    my @lines = $self->{conn}->cmd("pidof seagull");
     my $flag =0;
     foreach(@lines){
		if($_ =~m/$self->{PID}/){
			$flag = 1;
		}	
	}
        if ($flag != 1) {
      $logger->info( __PACKAGE__ . ".hardStop  SUCCESS.");
      $self->{PID} = 0;
      return 1;
    } else {
      $logger->info( __PACKAGE__ . ".hardStop  Waiting for SEAGULL to terminate iteration $count/$timeout.");
    }
    sleep 1;
    $count++;
  }
  &error( __PACKAGE__ . ".hardStop  WARNING - SEAGULL (PID=$self->{PID}) failed to stop (SIGKILL) we're boned");
  
}


=head2 SonusQA::SEAGULL::startSeagull(<command>)

  Starts SEAGULL in the foreground

=over

=item Argument

  If <command> is specified, it is expected to be a well formatted set of seagull command line options
  The -bg option is stripped even if the user passes it in <command>.

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  $seagullobj->startSeagull('seagull -conf ../config/conf.server.xml -dico ../config/base_cx.xml -scen ../scenario/sar-saa.server.xml -log ../logs/sar-saa.server.log -llevel ET');

=back

=cut

sub startSeagull {
  my ($self, $cmd)=@_;
  
  my $sub = 'startSeagull';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  unless ($cmd) {
	$logger->error(__PACKAGE__ . ".$sub mandotory argument \$cmd is missing");
	return 0;
  }
  
  if( $self->{PID} ) {
	$logger->warn(__PACKAGE__ . ".$sub  This instance appears to already be running - NOT starting");
	if($self->{CMDERRORFLAG}){
	  $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
	  &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  ALREADY STARTED");
	}
	return 0;
  }
  
  $cmd =~ s/-bg//g;

  unless ($self->{CONFIGPATH}) {
    $logger->error(__PACKAGE__ . ".$sub CONFIGPATH is missing please specify the value in your feature");
    return 0;
  } else {
    $self->{conn}->cmd("cd $self->{CONFIGPATH}");
  }
  
  $logger->info(__PACKAGE__ . ".$sub  Starting seagull with \'$cmd\'");
  
  $self->{conn}->cmd('export LD_LIBRARY_PATH=/usr/local/bin:$LD_LIBRARY_PATH');
  
  unless ($self->{conn}->print( $cmd )) {
	$logger->warn(__PACKAGE__ . ".$sub  \'$cmd\' COMMAND EXECTION ERROR OCCURRED");
	if($self->{CMDERRORFLAG}){
	  &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR");
	  return 0;
	}
  }
  
  $self->{PID} = -1;
  $self->{LASTPID} = -1;
  $logger->info(__PACKAGE__ . ".$sub  finished succesufully");
  
  return 1;

}

=head2 SonusQA::SEAGULL::startSingleShot(<command>)

  Starts SEAGULL in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  If <command> is specified, it is expected to be a well formatted set of seagull command line options,
  The -bg option is stripped even if the user passes it in <command>.

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  $seagullobj->startSingleShot('seagull -conf ../config/conf.server.xml -dico ../config/base_cx.xml -scen ../scenario/sar-saa.server.xml -log ../logs/sar-saa.server.log -llevel ET');

=back

=cut

sub startSingleShot {
  my ($self, $cmd)=@_;

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startSingleShot");
  unless ($cmd) {
	$logger->error(__PACKAGE__ . ".startSingleShot mandotory argument \$cmd is missing");
	return 0;
  }
  if ($self->startSeagull($cmd)) {
	$logger->debug(__PACKAGE__ . ".startSingleShot  finished succesufully");
	return 1;
  } 
  $logger->error(__PACKAGE__ . ".startSingleShot  failed");
  return 0;
}

=head2 SonusQA::SEAGULL::startServer(<command>)

  Starts SEAGULL server in the foreground

=over

=item Argument

  If <command> is specified, it is expected to be a well formatted set of seagull command line options,
  The -bg option is stripped even if the user passes it in <command>.

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  $seagullobj->startServer('seagull -conf ../config/conf.server.xml -dico ../config/base_cx.xml -scen ../scenario/sar-saa.server.xml -log ../logs/sar-saa.server.log -llevel ET');

=back

=cut

sub startServer {
  my ($self, $cmd)=@_;

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startServer");
  unless ($cmd) {
	$logger->error(__PACKAGE__ . ".startServer mandotory argument \$cmd is missing");
	return 0;
  }
  if ($self->startSeagull($cmd)) {
	$logger->debug(__PACKAGE__ . ".startServer  finished succesufully");
	return 1;
  } 
  $logger->error(__PACKAGE__ . ".startServer  failed");
  return 0;
}

=head2 SonusQA::SEAGULL::startClient(<command>)

  Starts SEAGULL client in the foreground

=over

=item Argument

  If <command> is specified, it is expected to be a well formatted set of seagull command line options,
  The -bg option is stripped even if the user passes it in <command>.

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  $seagullobj->startClient('seagull -conf ../config/conf.server.xml -dico ../config/base_cx.xml -scen ../scenario/sar-saa.server.xml -log ../logs/sar-saa.server.log -llevel ET');

=back

=cut

sub startClient {
  my ($self, $cmd)=@_;

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startClient");
  unless ($cmd) {
	$logger->error(__PACKAGE__ . ".startClient mandotory argument \$cmd is missing");
	return 0;
  }
  
  if ($self->startSeagull($cmd)) {
	$logger->debug(__PACKAGE__ . ".startClient  finished succesufully");
	return 1;
  } 
  $logger->error(__PACKAGE__ . ".startClient  failed");
  return 0;
}

=head2 SonusQA::SEAGULL::waitCompletion(<timeout>,<singleshot>)

  Used to wait for a test to complete

=over

=item Argument

  timeout in seconds.
  For Single shot testing pass $singleshot as 1

=item Returns

  1 if the test is complete and SEAGULL exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut

sub waitCompletion {
  my ($self, $timeout, $singleshot)=@_;
  my $sub = "waitCompletion";
  
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
  if( $self->{PID} == -1 ) {
    if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub  No timeout specified, using default ($timeout s)");
    }
    else {
      $logger->debug(__PACKAGE__ . ".$sub Using user timeout ($timeout s)");
    }

    
    unless (my($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                                -errmode => "return",
                                                -timeout => $timeout)) {
      $logger->warn(__PACKAGE__ . ".$sub  SEAGULL did not complete in $timeout seconds.");
	  unless ($singleshot) {
	    $logger->debug(__PACKAGE__ . ".$sub \$singleshot not set");
        #BEGIN: TOOLS-18517 FIX
        foreach ("qq", "\cC"){
            my $cmd = ($_ eq 'qq') ? $_ : 'Ctrl+c';
            unless($self->{conn}->cmd($_)){
                $logger->warn(__PACKAGE__ . ".$sub Couldn't get prompt ($self->{PROMPT}) after executing '$cmd'");
                $logger->debug(__PACKAGE__ . ".$sub errmsg: ". $self->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub lastline: ". $self->{conn}->lastline);
                $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
            }
            else{
                $logger->info(__PACKAGE__ . ".$sub SEAGULL killed using '$cmd'");
                $self->{PID} = 0;
                last;
            }
        }
        #END: TOOLS-18517 FIX
	  }

          $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	  return 0;
    }
  
  } else {
    $logger->warn(__PACKAGE__ . ".$sub Called but SEAGULL is not marked as running a single-shot test.");
    return 0;
  }
  
  $logger->info(__PACKAGE__ . ".$sub Successfully detected SEAGULL completion, getting status");
  $self->{PID} = 0;
 
  my @cmdResults;
  unless (@cmdResults = $self->{conn}->cmd(String => "echo \$?", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  Failed to get return value");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults;
  }
  chomp @cmdResults;

  $logger->info(__PACKAGE__ . ".$sub returned exit code : $cmdResults[0]");

  if ("$cmdResults[0]" eq "0"){
    $logger->debug(__PACKAGE__ . ".$sub  SEAGULL command returned success");
    return 1;
  } else {
    $logger->warn(__PACKAGE__ . ".$sub  SEAGULL command returned error code $cmdResults[0]");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: echo \$?");
    }
    return 0;
  }
  die "This should be unreachable\n";
}

=head2 SonusQA::SEAGULL::waitCompletionServer(timeout)

  This subroutine shall be used to wait for the completion of server instance

=over

=item Argument

  <timeout> in seconds

=item Returns

  1 if the test is complete and SEAGULL exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut

sub waitCompletionServer {
  my ($self, $timeout)=@_;
  
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". waitCompletionServer");
  
  if ($self->waitCompletion($timeout,0)) {
	$logger->debug(__PACKAGE__ . ".waitCompletionServer  finished succesufully");
	return 1;
  } 
  
  $logger->error(__PACKAGE__ . ".waitCompletionServer  failed");
  return 0;
 
}

=head2 SonusQA::SEAGULL::waitcompletionClient(timeout)

  This subroutine shall be used to wait for the completion of client instance

=over

=item Argument

  <timeout> in seconds

=item Returns

  1 if the test is complete and SEAGULL exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut

sub waitCompletionClient {
  my ($self, $timeout)=@_;
  
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". waitCompletionClient");
  
  if ($self->waitCompletion($timeout,0)) {
	$logger->debug(__PACKAGE__ . ".waitCompletionClient  finished succesufully");
	return 1;
  } 
  
  $logger->error(__PACKAGE__ . ".waitCompletionClient  failed");
  return 0;
 
}

=head2 SonusQA::SEAGULL::csvsplit(%args)
csvsplit is used to create a reduced CSV file from the raw CSV data. csvsplit combines two features:

    * Sample raw CSV data by taking one measure out of "r"
    * Suppress the beginning of raw CSV data to remove unwanted "startup" data

=over

=item Argument

  manditory arguments -
        -in  => Name of the xml scenario file without the extension
                eg -> -in => '../logs/server-protocol-stat.diameter'
        -out => file name for reduced CSV file
                eg -> -out => '../logs/csvsplit.csv'
  optional -
        -skip => skip the n first values (default 0)
        -ratio=> let 1 out of r value (default 10)

=item Returns

  1 if the reduced CSV file created.
  0 on any failur

=item Example(s)

  my %a = ( -in => '../logs/server-protocol-stat.diameter', -out => '../logs/csvsplit.csv');
  $seagullObj2->csvsplit(%a);

=back

=cut

sub csvsplit {
  my ($self, %args) = @_;
  
  my $sub = 'csvsplit()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
 
  unless ($args{-in}) {
	$logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-in} is missing or balnk");
	return 0;
  }
 
  my $xmlfileName = $args{-in};
  my @tmp = $self->{conn}->cmd("ls -t1 $xmlfileName*.csv");
  chomp $tmp[0];
  $tmp[0] =~ m/.*($xmlfileName.*\.csv)/;
  my $fName  = $1;
  $logger->debug(__PACKAGE__ . ".$sub Name of the Trace file is $fName");
  unless ($fName) {
    $logger->debug(__PACKAGE__ . ".$sub Unable to find the trace counts file! Please ensure that the you passes the correct file name");
    return 0;
  }
 
  unless ($args{-out}) {
    $logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-out} is missing or balnk");
	return 0;
  }
  
  my $cmd = "csvsplit $fName $args{-out} ";
  $cmd .= "-skip $args{-skip} " if ($args{-skip});
  $cmd .= "-ratio  $args{-ratio } " if ($args{-ratio});
  
  my @cmdResults;
  unless (@cmdResults = $self->{conn}->cmd(String => "$cmd", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  unable to execute \'$cmd\'");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults;
        $logger->debug(__PACKAGE__ . ".$sub  errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	return 0;
  }
  
  $logger->debug(__PACKAGE__ . ".$sub  successful");
  return 1;
}

=head2 SonusQA::SEAGULL::computestat(%args)

  computestat is used to compute the statistics from the raw or sampled CSV data. computestat.ksh relies on Octave to compute reliable statistical results.
  Note - presenlty this feture is not provide

=over

=item Argument

  manditory arguments -
        -in  => Name of the xml scenario file without the extension
                eg -> -in => '../logs/server-protocol-stat.diameter'
        -out => file name for computed CSV file
                eg -> -out => '../logs/compute.stat.csv'
  optional -
        -percentile => nth percentile calculus (default 95)

=item Returns

  1 if the reduced CSV file created.
  0 on any failur

=item Example(s)

  my %a = ( -in => '../logs/server-protocol-stat.diameter', -out => '../logs/compute.stat.csv');
  $seagullObj2->computestat(%a);

=back

=cut

sub computestat {
  my ($self, %args) = @_;
  
  my $sub = 'computestat()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
  
  unless ($args{-in}) {
	$logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-in} is missing or balnk");
	return 0;
  }
 
  my $xmlfileName = $args{-in};
  my @tmp = $self->{conn}->cmd("ls -t1 $xmlfileName*.csv");
  chomp $tmp[0];
  $tmp[0] =~ m/.*($xmlfileName.*\.csv)/;
  my $fName  = $1;
  $logger->debug(__PACKAGE__ . ".$sub Name of the Trace file is $fName");

  unless ($fName) {
    $logger->debug(__PACKAGE__ . ".$sub Unable to find the trace counts file! Please ensure that the you passes the correct file name");
    return 0;
  }
 
  unless ($args{-out}) {
    $logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-out} is missing or balnk");
	return 0;
  }
  
  my $cmd = "computestat.ksh -in $fName -out $args{-out} ";
  $cmd .= "-nth $args{-percentile} " if ($args{-percentile});
    
  my @cmdResults;
  unless (@cmdResults = $self->{conn}->cmd(String => "$cmd", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  unable to execute \'$cmd\'");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults;
        $logger->debug(__PACKAGE__ . ".$sub  errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	return 0;
  }
  
  $logger->debug(__PACKAGE__ . ".$sub  successful");
  return 1;
}

=head2 SonusQA::SEAGULL::plotstat(%args)

  plotstat is used to create graphics from the raw or sampled CSV data. plotstat.ksh relies also on Octave to create PNG graphical files.
  Note - presenlty this feture is not provide

=over

=item Argument

  manditory arguments -
        -in  => Name of the xml scenario file without the extension
                eg -> -in => '../logs/server-protocol-stat.diameter'
        -out => file name for stats
                eg -> -out => '../logs/plotstat.png'
  optional -
        -stat => input stat file name (default no file)

=item Returns

  1 if the reduced CSV file created.
  0 on any failur

=item Example(s)

  my %a = ( -in => '../logs/server-protocol-stat.diameter', -out => '../logs/plotstat.png');
  $seagullObj2->plotstat(%a);

=back

=cut

sub plotstat {
  my ($self, %args) = @_;
  
  my $sub = 'plotstat()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
  
  unless ($args{-in}) {
	$logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-in} is missing or balnk");
	return 0;
  }
  
  my $xmlfileName = $args{-in};
  my @tmp = $self->{conn}->cmd("ls -t1 $xmlfileName*.csv");
  chomp $tmp[0];
  $tmp[0] =~ m/.*($xmlfileName.*\.csv)/;
  my $fName  = $1;
  $logger->debug(__PACKAGE__ . ".$sub Name of the Trace file is $fName");

  unless ($fName) {
    $logger->debug(__PACKAGE__ . ".$sub Unable to find the trace counts file! Please ensure that the you passes the correct file name");
    return 0;
  }
  
  unless ($args{-out}) {
    $logger->error(__PACKAGE__ . ".$sub  manitory arqument \$args{-out} is missing or balnk");
	return 0;
  }
  
  my $cmd = "plotstat.ksh -in $fName -out $args{-out} ";
  $cmd .= "-stat $args{-stat} " if ($args{-stat});
    
  my @cmdResults;
  unless (@cmdResults = $self->{conn}->cmd(String => "$cmd", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  unable to execute \'$cmd\'");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults;
        $logger->debug(__PACKAGE__ . ".$sub  errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	return 0;
  }
  
  $logger->debug(__PACKAGE__ . ".$sub  successful");
  return 1;
}

=head2 SonusQA::SEAGULL::getCurStats()

    This method will get the current global statistics

=over

=item Arguments

    Name of the xml scenario file without the extension.

=item Returns

    Hash containing the global statistics names as the key and its value.

=item Example(s)

    my %retHash = $seagullObject->getCurStats('../logs/client-stat');

=back

=cut

sub getCurStats{

  my ($self, $xmlfileName)=@_;
  my ($match, $prematch, @tmp, @head, @tail, $fName, %retHash);
  my $sub = "getCurCountStats";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  @tmp = $self->{conn}->cmd("ls -t1 $xmlfileName*.csv");
  chomp $tmp[0];
  $tmp[0] =~ m/.*($xmlfileName.*\.csv)/;
  $fName  = $1;

  $logger->debug(__PACKAGE__ . ".$sub Name of the Trace file is $fName");

  if (defined $fName) {
    @tmp = $self->execCmd("head -1 $fName");
    chomp $tmp[0];
    @head = split(/;/, $tmp[0]);
	
    @tmp = $self->execCmd("tail -1 $fName");
	chomp $tmp[0];
    @tail = split(/;/, $tmp[0]);
	map{$retHash{ $head[$_] } = $tail[$_]} (0..$#head);
	
    return %retHash;
  } else {
    $logger->debug(__PACKAGE__ . ".$sub Unable to find the trace counts file! Please ensure that the you passes the correct file name");
    return %retHash;
  }
}


=head2 SonusQA::SEAGULL::execCmd()

    This function enables user to execute any command on the SEAGULL server.

=over

=item Arguments

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Returns

    Output of the command executed.

=item Example(s)

    my @results = $seagullObject->execCmd("ls /ats/NBS/sample.csv");
    This would execute the command "ls /ats/NBS/sample.csv" on the SEAGULL server and return the output of the command.

=back

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
        $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        return @cmdResults;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    return @cmdResults;
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

=head2 SonusQA::SEAGULL::DESTROY

 Override the DESTROY method inherited from Base.pm, we'll use this to attempt
 to kill (forcefully) any running SEAGULL instances before we are destroyed.

=over

=item Argument

  None

=item Returns

  None

=back

=cut

sub DESTROY {
    my ($self)=@_;
    my ($logger);
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    if ($self->{PID} == -1) {
      $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up singleshot instance");
      $self->{conn}->print("qq");
    } elsif ($self->{PID} > 0) {
      $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up background instance");
      $self->hardStop(1);
    } else {
      $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] No running SEAGULL instance to cleanup");
    }
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

1;
