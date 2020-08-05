package SonusQA::DIAMAPP;

=head1 NAME

SonusQA::DIAMAPP- Perl module for DIAMAPP application control.

=head1 AUTHOR

Balaji Srinivasan  - bsrinivasan@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   ##use SonusQA::DIAMAPP; # Only required until this module is included in ATS above.
   my $obj = SonusQA::DIAMAPP->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               -cmdline => "<diamapp command line options, e.g.  -c  <cfg-file>  -sf <scenario file >  -rp -client  -fg -trace-msg"
                               );
                               note: -bg will be appended -cmdline to run DIAMAPP when the background methods are
                               called, and will be stripped (if provided) when invoking the single-shot methods.

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for the DIAMAPP test tool.
It provides methods for starting and stopping single-shot and load testing, most cli methods returning true or false (0|1).
Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, 
allowing the engineer to specific which attributes to use.  Complete examples are given for each method.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);


# INITIALIZATION ROUTINES FOR CLI
# -------------------------------

=pod 

=head2 SonusQA::DIAMAPP::doInitialization()

  Routine to set object defaults and session prompt.

=over

=item Argument

  None

=item Returns

  None

=back

=cut

sub doInitialization {
  my($self, %args)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{DIAMAPPPATH} = "/home/mpietsch/PCRF/diamapp/diamapp";
  $self->{PID} = 0; # We will use PID to determine if an instance is running or not,
    # this means we
    #   set PID to the real PID on starting the application, background case,
    #   to -1 for starting in foreground
    #   and reset to 0 when stopping.
  $self->{LASTPID} = 0; # We use this to store the previous PID when the simulation is stopped, required
    # to retrieve log/statistics files which include the PID and scenario name
  
  # Set some defaults for diamapp cmdline options if the user specifies nothing (for demo purposes really, there's no *good* defaults)
  if ( exists $args{-cmdline} ) {
    $self->{USER_ARGS} = $args{-cmdline}
  } else {
    $self->{USER_ARGS} = "-sn uac localhost"; # to store user defined args.
  }  
  
  ### START For future use
  $self->{TRACE_MSG} = 0;
  $self->{TRACE_SHORTMSG} = 0;
  $self->{TRACE_SCREEN} = 1;
  $self->{TRACE_ERR} = 1;
  $self->{TRACE_TIMEOUT} = 1;
  $self->{TRACE_STAT} = 1;
  $self->{TRACE_RTT} = 0;
  $self->{TRACE_LOGS} = 0;
  $self->{UA} = "C"; # UAC or UAS
  $self->{SCENARIO_NAME} = "uac"; # Either builtin (per default) or external xml script (e.g. uac_2KPDU.xml)
  # External files *must* end in .xml, everything else is assumed to be builtin
  ### END For future use
}

=pod

=head2 SonusQA::DIAMAPP::setSystem()

  This routine is responsible to completeing the connection to the object.

=over

=item Argument

  None

=item Retuns

  1 - Automation related configuration is complete

=back

=cut

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd(""); 
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;

}

=pod 

=head2 SonusQA::DIAMAPP::startBackground(<command>)

  Start DIAMAPP in the background, used for load testing.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of diamapp command line options,
  e.g
    -sf malc.xml -r 100 -d 1500 -l 6000 10.31.200.60
  the -bg (background) option is forced on by this method if not specified by the user.

=item Returns

  Set's $self->{PID} to the PID of the started process

=back

=cut

sub startBackground {
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startBackground");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".startBackground  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".startBackground  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".startBackground  ALREADY STARTED");
    }
  } else {
    if (!(defined $cmd)) {
      $cmd = $self->{USER_ARGS};
    }
    # Always run in background mode, no matter what.
    $cmd .= " -bg";
    $logger->info(__PACKAGE__ . ".startBackground  Starting diamapp with args $cmd");
    my @lines = $self->{conn}->cmd( $self->{DIAMAPPPATH} . " " . $cmd );
    # Get PID
    foreach (@lines) {
		$logger->info(__PACKAGE__ . ".startBackground  $_");
        if(m/^(\d+)$/){
	$self->{PID} =$_;last;
	}elsif(m/PID/) {
        $logger->info(__PACKAGE__ . ".startBackground  SIPP1-PID - Match\n");
        $self->{PID} = $_;
        $self->{PID} =~ s/.*PID=\[//g;
        $self->{PID} =~ s/\]//g;
	last;
	}
    }
    chomp $self->{PID};
    if ($self->{PID} == 0) {
      &error(__PACKAGE__ . ".startBackground Failed to get DIAMAPP PID, manual cleanup is likely required\n");
    } 

    $self->{LASTPID} = $self->{PID};      
    $logger->info(__PACKAGE__ . ".startBackground  Started DIAMAPP with PID $self->{PID}\n");
    return 1;
  }
}

=pod 

=head2 SonusQA::DIAMAPP::gracefulStop(<timeout>)

  Send a SIGUSR1 (equivalent to pressing 'q' from the Gui, to cause DIAMAPP to stop
  making new calls and exit once all existing calls are done.

=over

=item Argument

  timeout <Scalar>
  <timeout> in seconds is the number of seconds to wait for the DIAMAPP application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.

  Used only for background DIAMAPP instances (started with startBackground()

=item Returns

  1 on successful termination
  0 on timeout.

=back

=cut

sub gracefulStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gracefulStop");
  $logger->info( __PACKAGE__ . ".gracefulStop  Terminating DIAMAPP, PID=$self->{PID}, timeout = $timeout seconds.");
  
  my $count=0;
 $self->{conn}->cmd("kill -SIGUSR1 $self->{PID}");


  while ($count < $timeout) {
     my @lines=(); 

    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.

     @lines = $self->{conn}->cmd("pidof diamapp");
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
      $logger->info( __PACKAGE__ . ".gracefulStop  Waiting for DIAMAPP to terminate iteration $count/$timeout.");
    }
    sleep 1;
    $count++;
  }
  $logger->warn( __PACKAGE__ . ".gracefulStop  WARNING - DIAMAPP (PID=$self->{PID}) failed to stop.");
  return 0
}

=pod 

=head2 SonusQA::DIAMAPP::hardStop(<timeout>)

  Send a SIGKILL to cause DIAMAPP to exit immediately, possibly leaving calls hanging.

=over

=item Argument

  timeout <Scalar>
  <timeout> in seconds is the number of seconds to wait for the DIAMAPP application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.

  Used only for background DIAMAPP instances (started with startBackground()

=item Returns

  1 on successful termination
  Calls &error on timeout - SIGKILL is assumed to be an unstoppable force, if this
  fails then we can't vouch for the state of the controlled system, so we might as well bail.

=back

=cut

sub hardStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".hardStop");
  $logger->warn( __PACKAGE__ . ".hardStop  Terminating DIAMAPP, PID=$self->{PID}, some calls may be left hanging.");
  
  my $count=0;
  $self->{conn}->cmd("kill -SIGKILL $self->{PID}");
  while ($count < $timeout) {
  
    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.
    my @lines = $self->{conn}->cmd("pidof diamapp");
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
      $logger->info( __PACKAGE__ . ".hardStop  Waiting for DIAMAPP to terminate iteration $count/$timeout.");
    }
    sleep 1;
    $count++;
  }
  &error( __PACKAGE__ . ".hardStop  WARNING - DIAMAPP (PID=$self->{PID}) failed to stop (SIGKILL) we're boned");
  
}

=pod 

=head2 SonusQA::DIAMAPP::startSingleShot(<command>)

  Starts DIAMAPP in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of diamapp command line options,
  e.g
   -fg -trace-msg -c server.cfg -sf server.xml > server.log 2>&1
  The -bg option is stripped even if the user passes it in <command>.

  NB this does not wait for the singleShot test to complete, see waitCompletion() below.

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut

sub startSingleShot {
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startSingleshot");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".startSingleshot  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".startSingleshot  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".startSingleshot  ALREADY STARTED");
    }
    return 0;
  } else {
    if (!(defined $cmd)) {
      $cmd = $self->{USER_ARGS};
    }
    # Always run in Singleshot mode, no matter what the user supplies in -cmdline
    $cmd =~ s/-bg//g;
    $logger->info(__PACKAGE__ . ".startSingleshot  Starting diamapp with args $cmd");
    # Use ->print, this cmd ain't gonna return immediately.
    my @cmdResults;
    unless ($self->{conn}->print( $self->{DIAMAPPPATH} . " " . $cmd )) {
      $logger->warn(__PACKAGE__ . ".startSingleshot  COMMAND EXECTION ERROR OCCURRED");
      map { $logger->warn(__PACKAGE__ . ".startSingleshot\t\t$_") } @cmdResults;
      if($self->{CMDERRORFLAG}){
        &error("CMD FAILURE: " . __PACKAGE__ . ".startSingleshot  COMMAND EXECUTION ERROR");
        return 0; # Unreachable...
      }
    }
    
    $self->{PID} = -1;
    $self->{LASTPID} = -1;
    $logger->info(__PACKAGE__ . ".startSingleshot  Started DIAMAPP\n");
    return 1;
  };
  
}

=pod 

=head2 SonusQA::DIAMAPP::startServer(<command>)

  Starts DIAMAPP SERVER in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of diamapp command line options,
  The -bg option is stripped even if the user passes it in <command>.
	 The path shall be read in from the DIAMAPP.pm file itself
        DEFAULT PATH IS :<$self->{DIAMAPPPATH}> :  /ats/bin/diamapp
  Command passed shall not have the above path specified, as shown in example below

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example

 my $cmd1 = "-sf /ats/NBS/V0800/NBS8_INREGL/DIAMAPP/NBS8_001_SERVER.xml -p 5091 -mp 1211 -m 1"
 $diamappObj1->startServer($cmd1);
 It shall be invoked after appending the path as :
        /ats/bin/diamapp -sf /ats/NBS/V0800/NBS8_INREGL/DIAMAPP/NBS8_001_SERVER.xml -p 5091 -mp 1211 -m 1
  NB this does not wait for the singleShot test to complete, see waitCompletionServer() below.

=back

=cut

sub startServer {

  my ($self,$cmd1)=@_;
  my $sub = "startServer";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".$sub  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  ALREADY STARTED");
    }
    return 0;
  } else {
    if (!(defined $cmd1)) {
      $cmd1 = $self->{USER_ARGS};
    }

    # Always run in Singleshot mode, no matter what the user supplies in -cmdline
    $cmd1 =~ s/-bg//g;
    $logger->info(__PACKAGE__ . ".$sub  Starting diamapp SERVER with args $cmd1");
    my @cmdResults1;

        unless ($self->{conn}->print( $self->{DIAMAPPPATH} . " " . $cmd1 )) {
      $logger->warn(__PACKAGE__ . ".$sub  COMMAND EXECTION ERROR OCCURRED");
      map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults1;
      if($self->{CMDERRORFLAG}){
        &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR");
        return 0; # Unreachable...
}
    }

    $self->{PID} = -1;
    $self->{LASTPID} = -1;
    $logger->info(__PACKAGE__ . ".$sub  Started DIAMAPP SERVER\n");
    return 1;
  }

}

=pod 

=head2 SonusQA::DIAMAPP::startClient(<command>)

  Starts DIAMAPP CLIENT in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of diamapp command line options,
  The -bg option is stripped even if the user passes it in <command>.
  The path shall be read in from the DIAMAPP.pm file itself 
	DEFAULT PATH IS :<$self->{DIAMAPPPATH}> :  /ats/bin/diamapp
  Command passed shall not have the above path specified, as shown in example below 

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  my $cmd2 = "-sf /ats/NBS/V0800/NBS8_INREGL/DIAMAPP/NBS8_001_CLIENT.xml -s 988681234 -p 6091 10.34.20.114 -m 1 -mp 2345";
  $diamappObj2->startClient($cmd2);
  It shall be invoked after appending the path as : 
	/ats/bin/diamapp -sf /ats/NBS/V0800/NBS8_INREGL/DIAMAPP/NBS8_001_CLIENT.xml -s 988681234 -p 6091 10.34.20.114 -m 1 -mp 2345
  NB this does not wait for the singleShot test to complete, see waitCompletionClient() below.

=back

=cut

 sub startClient {

  my ($self,$cmd2)=@_;
  my $sub = "startClient";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".$sub  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  ALREADY STARTED");
    }
    return 0;
  } else {
    if (!(defined $cmd2)) {
        $cmd2 = $self->{USER_ARGS};
    }

    $cmd2 =~ s/-bg//g;
    $logger->info(__PACKAGE__ . ".$sub  Starting diamapp CLIENT  with args $cmd2");
    my @cmdResults2;

    unless ($self->{conn}->print( $self->{DIAMAPPPATH} . " " . $cmd2 )) {
      $logger->warn(__PACKAGE__ . ".$sub  COMMAND EXECTION ERROR OCCURRED");
      map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults2;
      if($self->{CMDERRORFLAG}){
        &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR");
        return 0; # Unreachable...
      }
    }
 $self->{PID} = -1;
 $self->{LASTPID} = -1;
 $logger->info(__PACKAGE__ . ".$sub  Started DIAMAPP CLIENT \n");
 return 1;
  }

}

=pod

=head2 SonusQA::DIAMAPP::startCustomServer(<command>)

  Starts CUSTOMIZED DIAMAPP SERVER in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of diamapp command line options,
  The -bg option is stripped even if the user passes it in <command>.
  Command passed shall have the path to customized diamapp specified as in example below

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  my $cmd1 = "/ats/tools/sipp-2.0.1.src/sipp -sf $sipppath$testcase_SERVER.xml -m 1 -i $sipp_ip -p $calledport";
  $sippObj1->startCustomServer($cmd2);
  NB this does not wait for the singleShot test to complete, see waitCompletionServer() below.

=back

=cut


sub startCustomServer {

  my ($self,$cmd3)=@_;
  my $sub = "startCustomServer";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".$sub  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  ALREADY STARTED");
    }
    return 0;
  } else {
    if (!(defined $cmd3)) {
        $cmd3 = $self->{USER_ARGS};
    }

    $cmd3 =~ s/-bg//g;
    $logger->info(__PACKAGE__ . ".$sub  Starting Customized DIAMAPP Server with args $cmd3");
    my @cmdResults3;
    unless ($self->{conn}->print( $cmd3 )) {
      $logger->warn(__PACKAGE__ . ".$sub  COMMAND EXECTION ERROR OCCURRED");
      map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults3;
      if($self->{CMDERRORFLAG}){
        &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR");
        return 0; # Unreachable...
      }
    }
 $self->{PID} = -1;
 $self->{LASTPID} = -1;
 $logger->info(__PACKAGE__ . ".$sub  Started DIAMAPP CUSTOMIZED CLIENT \n");
 return 1;
  }

}

=pod

=head2 SonusQA::DIAMAPP::startCustomClient(<command>)

  Starts  CUSTOMIZED DIAMAPP CLIENT in the foreground, useful for singleshot testing where we want to check the return code.

=over

=item Argument

  command <Scalar>
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  The -bg option is stripped even if the user passes it in <command>.
  Command passed shall have the path to customized sipp specified as in example below  

=item Returns

  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=item Example(s)

  my $cmd2 = "/ats/tools/sipp-2.0.1.src/sipp -sf $sipppath$testcase_CLIENT.xml -m 1 -i $sipp_ip -p $callingport $gsx_ssip:5060 -mp $mediaport1";
  $sippObj2->startCustomClient($cmd2);
  NB this does not wait for the singleShot test to complete, see waitCompletionClient() below.

=back

=cut

sub startCustomClient {

  my ($self,$cmd4)=@_;
  my $sub = "startCustomClient";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  if( $self->{PID} ) {
    $logger->warn(__PACKAGE__ . ".$sub  This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  ALREADY STARTED");
    }
    return 0;
  } else {
    if (!(defined $cmd4)) {
      $cmd4 = $self->{USER_ARGS};
    }

    $cmd4 =~ s/-bg//g;
    $logger->info(__PACKAGE__ . ".$sub  Starting Customized DIAMAPP  Client with args $cmd4");
    my @cmdResults4;

    unless ($self->{conn}->print( $cmd4 )) {
      $logger->warn(__PACKAGE__ . ".$sub  COMMAND EXECTION ERROR OCCURRED");
      map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults4;
      if($self->{CMDERRORFLAG}){
        &error("CMD FAILURE: " . __PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR");
        return 0; # Unreachable...
      }
    }
 $self->{PID} = -1;
 $self->{LASTPID} = -1;
 $logger->info(__PACKAGE__ . ".$sub  Started DIAMAPP CUSTOMIZED CLIENT \n");
 return 1;
  }

}

=pod

=head2 SonusQA::DIAMAPP::waitCompletion(<timeout>)

  Used to wait for a singleshot test to complete, timeout in seconds.

=over

=item Argument

  timeout <Scalar>

=item Returns

  1 if the test is complete and DIAMAPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut


sub waitCompletion {
      
    # FYI - DIAMAPP return codes
    #    0: All calls were successful
    #    1: At least one call failed
    #   99: Normal exit without calls processed
    #   -1: Fatal error

  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".waitCompletion");
  my ($match,$prematch,@cmdResults);
  if( $self->{PID} == -1 ) {
    if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".waitCompletion  No timeout specified, using default ($timeout s)");
    }
    else {
      $logger->debug(__PACKAGE__ . ".waitCompletion Using user timeout ($timeout s)");
    }

    # Wait for completion
    ($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                               -errmode => "return",
                                               -timeout => $timeout) or do {
    $logger->warn(__PACKAGE__ . ".waitCompletion  DIAMAPP did not complete in $timeout seconds.");
    $logger->debug(__PACKAGE__ . ".waitCompletion  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".waitCompletion  Session Input Log is: $self->{sessionLog2}");
    return 0;
    };
  } else {
    $logger->warn(__PACKAGE__ . ".waitCompletion Called but DIAMAPP is not marked as running a single-shot test.");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".waitCompletion Successfully detected DIAMAPP completion, getting status");
  #$logger->debug(__PACKAGE__ . "\DIAMAPP Screen Output :\n $prematch"); 
  
  unless (@cmdResults = $self->{conn}->cmd(String => "echo \$?", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".waitCompletion  Failed to get return value");
    map { $logger->warn(__PACKAGE__ . ".waitCompletion\t\t$_") } @cmdResults;
  };
  chomp @cmdResults;
  if ("$cmdResults[0]" eq "0" ){
    $logger->info(__PACKAGE__ . ".waitCompletion  DIAMAPP command returned success");
    return 1;
  } else {
    $logger->warn(__PACKAGE__ . ".waitCompletion  DIAMAPP command returned error code $cmdResults[0]");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".waitCompletion  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error('CMD FAILURE: echo $?'); 
    }
    return 0;
  }
  die "This should be unreachable\n";
}

=pod

=head2 SonusQA::DIAMAPP::waitCompletionServer(timeout)

  This subroutine shall be used to wait for the completion of server instance 

=over

=item Argument

  timeout <Scalar>

=item Returns

  1 if the test is complete and DIAMAPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut

sub waitCompletionServer {

  my ($self,$timeout)=@_;
  my $sub = "waitCompletionServer";
  my ($match,$prematch,@cmdResults1);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
  if( $self->{PID} == -1 ) {
    if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub  No timeout specified, using default ($timeout s)");
    }
    else {
      $logger->debug(__PACKAGE__ . ".$sub Using user timeout ($timeout s)");
    }

    my $prompt = '/AUTOMATION\> $/';
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                                -errmode => "return",
                                                -timeout => $timeout) or do {
            $logger->warn(__PACKAGE__ . ".$sub  DIAMAPP did not complete in $timeout seconds.");
	    $self->{conn}->cmd(-string => "qq",
                             -prompt => $prompt);
	    $self->{conn}->cmd(-string => "\cC",
                             -prompt => $prompt);
	    $logger->error(__PACKAGE__ . ".$sub  DIAMAPP killed using Ctrl-C");
            $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	    return 0;
    };
  }
  else {
    $logger->warn(__PACKAGE__ . ".$sub Called but DIAMAPP is not marked as running a single-shot test.");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".$sub Successfully detected DIAMAPP completion, getting status");
  #$logger->debug(__PACKAGE__ . "\DIAMAPP Screen Output :\n $prematch");
  unless (@cmdResults1 = $self->{conn}->cmd(String => "echo \$?", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  Failed to get return value");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults1;
  }
  chomp @cmdResults1;

  $logger->info(__PACKAGE__ . ".$sub returned exit code : $cmdResults1[0]");

  if ("$cmdResults1[0]" eq "0"){
    $logger->info(__PACKAGE__ . ".$sub  DIAMAPP command returned success");

    return 1;
  }
  else {
    $logger->warn(__PACKAGE__ . ".$sub  DIAMAPP command returned error code $cmdResults1[0]");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error('CMD FAILURE: echo $?'); 
    }
    return 0;
  }
  die "This should be unreachable\n";
}

=pod

=head2 SonusQA::DIAMAPP::waitcompletionClient(timeout)

  This subroutine shall be used to wait for the completion of client instance

=over

=item Argument

  timeout <Scalar>

=item Returns

  1 if the test is complete and DIAMAPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=back

=cut

sub waitCompletionClient {

my ($self,$timeout)=@_;
  my($prematch,$match,@cmdResults2);
  my $sub = "waitCompletionClient";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

if( $self->{PID} == -1 ) {
    if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub  No timeout specified, using default ($timeout s)");
    }
    else {
      $logger->debug(__PACKAGE__ . ".$sub Using user timeout ($timeout s)");
    }


my $prompt = '/AUTOMATION\> $/';
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                                -errmode => "return",
                                                -timeout => $timeout) or do {
            $logger->warn(__PACKAGE__ . ".$sub  DIAMAPP did not complete in $timeout seconds.");
	    $self->{conn}->cmd(-string => "qq",
                             -prompt => $prompt);
            $self->{conn}->cmd(-string => "\cC",
                             -prompt => $prompt);
	    $logger->error(__PACKAGE__ . ".$sub  DIAMAPP killed using Ctrl-C");
            $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
	    return 0;
    };
  } else {
    $logger->warn(__PACKAGE__ . ".$sub Called but DIAMAPP is not marked as running a single-shot test.");
    return 0;

  }
  $logger->info(__PACKAGE__ . ".$sub Successfully detected DIAMAPP completion, getting status");
  #$logger->debug(__PACKAGE__ . "\DIAMAPP Screen Output :\n $prematch");
  unless (@cmdResults2 = $self->{conn}->cmd(String => "echo \$?", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".$sub  Failed to get return value");
    map { $logger->warn(__PACKAGE__ . ".$sub\t\t$_") } @cmdResults2;
  }

 chomp @cmdResults2;

  $logger->info(__PACKAGE__ . ".$sub returned exit code : $cmdResults2[0]");

   if ("$cmdResults2[0]" eq "0"){
    $logger->info(__PACKAGE__ . ".$sub  DIAMAPP command returned success");
    return 1;
  } else {
    $logger->warn(__PACKAGE__ . ".$sub  DIAMAPP command returned error code $cmdResults2[0]");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error('CMD FAILURE: echo $?');
    }
    return 0;
  }
  die "This should be unreachable\n";
}

=pod

=head2 SonusQA::DIAMAPP::DESTROY

 Override the DESTROY method inherited from Base.pm, we'll use this to attempt
 to kill (forcefully) any running DIAMAPP instances before we are destroyed.

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
      $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] No running DIAMAPP instance to cleanup");
    }
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

#*****************************************************************************

=pod

=head2 SonusQA::DIAMAPP::createcsvfile()

  This function enables dynamic creation of the csv file on the DIAMAPP server. The name of the
  file needs to be passed as an input argument. If the file is already present, then the
  contents are cleared.

=over

=item Argument

  Name of the file.

=item Returns    

  1: Success
  0: Failure 

=item Example(s)

  my $csvResult = $sippObject->createcsvfile("/ats/NBS/sample.csv");
  This would create a file sample.csv under /ats/NBS directory on the sipp server with the content
  "SEQUENTIAL".

=back

=cut

sub createCSVFile {
    
  my($self, $filename) = @_;
  my $sub = "createCSVFile";
  my ($retVal, @retVal);
    
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $self->{CSVFILENAME} = $filename;
    
  unless ( $self->{CSVFILENAME} ) {
    $logger->error(__PACKAGE__ . ".$sub  .csv full file name not defined");
    return 0;
  }
  
  # Clear the contents of the file if it already exists. If not, create a new one
  my $cmd1 = "echo SEQUENTIAL > " . $self->{CSVFILENAME} ;
  $logger->info(__PACKAGE__ . ".$sub Executing command $cmd1");
  @retVal = $self->{conn}->cmd($cmd1);
  $retVal = join '', @retVal;
  if ($retVal){
    $logger->error(__PACKAGE__ . ".$sub .Unable to write to file $self->{CSVFILENAME}");
    $logger->error(__PACKAGE__ . ".$sub .Command <$cmd1> returned <$retVal>");
    return 0;
  }
  
  $logger->info(__PACKAGE__ . ".$sub Created CSV file $self->{CSVFILENAME}");
  return 1;
  
}#End of createCSVfile()

#*****************************************************************************

=pod

=head2 SonusQA::DIAMAPP::appendToCSVFile()

  This function is used to write to the csv file on the DIAMAPP server created using createCSVfile.
  The contents of the file needs to be passed as an input argument.

=over

=item Argument

  Contents of the file to be passed as an array.

=item Returns    

  1: Success
  0: Failure 

=item Example(s)

  my $csvResult = $sippObject->createcsvfile("/ats/NBS/sample.csv");
  unless($csvResult){
    $logger->error(__PACKAGE__ ."CSVFILE CREATION FAILED");
    return 0;
  }

  my @contents = ("line1_data1;line1_data2;line1_data3",
                "line2_data1;line2_data2;line2_data3",
                "line3_data1;line3_data2;line3_data3");

  my $csvResult = $sippObject->appendToCSVFile(@contents);
  unless($csvResult){
    $logger->error(__PACKAGE__ ."CSVFILE UPDATION FAILED");
    return 0;
  }

  This would create a file sample.csv under /ats/NBS directory on the sipp server with the contents -
  SEQUENTIAL
  line1_data1;line1_data2;line1_data3
  line2_data1;line2_data2;line2_data3
  line3_data1;line3_data2;line3_data3

=back

=cut

sub appendToCSVFile {
  
  my $sub = "appendToCSVFile";
  my($self, @fileContents) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  
  unless ( $self->{CSVFILENAME} ) {
    $logger->error(__PACKAGE__ . ".$sub  .csv file name not defined. Invoke createCSVfile before calling appendToCSVFile");
    return 0;
  }
  
  foreach my $fileContent (@fileContents){
    my $cmd = 'echo "'.$fileContent.'" >> '.$self->{CSVFILENAME};
    $logger->info(__PACKAGE__ . ".$sub Executing command $cmd");
    my @retVal = $self->{conn}->cmd($cmd);    
    my $retVal = join ''. @retVal;    
    if ($retVal){
      $logger->error(__PACKAGE__ . ".$sub .Unable to write to file $self->{CSVFILENAME}");
      $logger->error(__PACKAGE__ . ".$sub .Command <$cmd> returned <$retVal>");
      return 0;
    }
  }
  
  $logger->info(__PACKAGE__ . ".$sub Updated CSV file $self->{CSVFILENAME}");
  return 1;

}#End of appendToCSVFile()

=pod

=head2 TODO - OTHER METHODS NOT YET IMPLEMENTED.

=head2 SonusQA::DIAMAPP::gatherLogs()

  retrieve any of the many log files generated by DIAMAPP and return them to the user. (use $self->{LASTPID} to figure out the filename for the background case, we will also need to stash the DIAMAPP scenario name at execution time since this also makes up part of the logfile name. (For background the PID in the filename is really the parent PID, so it will be LASTPID-1.)

=cut 

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

=pod

=head2 EXAMPLE CODE

  use ATS;
  use SonusQA::DIAMAPP;

=over

=item Note

  if you want this example code to do something, setup 'sipp -sn uas localhost'
  in a seperate terminal to emulate the uas (receiving side of the call)

  my $malc = SonusQA::DIAMAPP->new(-OBJ_HOST => 'localhost',
                               -OBJ_USER => 'atd',
                               -OBJ_PASSWORD => 'sonus',
                               -OBJ_COMMTYPE => "SSH",
                               -cmdline => "-sn uac -m 20 localhost",
                               );

  #Start the scenario identified at the object creation time


  #(useful when running the same call load repeatedly with different impairments.)

  $malc->startBackground;     
  sleep 5;     
  Attempt a gracefulStop (wait for calls to complete, give it 5 seconds)
  if($malc->gracefulStop(5)) {
    print "w00t";
  } else {
    # Do a hardstop.
    $malc->hardStop(5);
  }

=item Example 2

  singleshot test (assumes ->new() method called as above.

  This is a generic flag inherited from ATS objects, see their description. We use it to determine whether to call &error, if DIAMAPP returns an error code, or to return failure to the calling function and let them handle it.
  $malc->{CMDERRORFLAG}=1;
  Start a single-shot testcase.
  $malc->startSingleShot("-sn uac -r 1 -m 1 localhost") or die "Failed to startSingleShot\n"; We use it to determine whether to call &error, if DIAMAPP returns an error code, or to return failure to the calling function and let them handle it.
  Give it 2 seconds to complete. 
  $malc->waitCompletion(2) or die "Failed to complete\n";

  or use :

    $sippObj1->startServer($cmd1)
    $sippObj2->startClient($cmd2)
    $sippObj1->waitCompletionServer($timeout)
    $sippObj2->waitCompletionClient($timeout)

=back

=cut

1;

=pod

=head2 SonusQA::DIAMAPP::searchStringInFile

  This function is to search a specified string in a file in the local machine.
  Returns on the first occurance of the string in the file.

=over

=item Argument

  1st Arg  -  the log file name;
  2nd Arg  -  the string to look for;

=item Returns

  -1 - function fail;
  0  - fail (string not found);
  1  - success;

=item Example(s)

  SonusQA::DIAMAPP::searchStringInFile($file_name,$str);

=back

=cut

sub searchStringInFile{

    my ($file_name,$str)=@_;
    my $sub_name = "getFileToLocalDirectoryViaSFTP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $retval = 0;

   open (TEXTFILE, $file_name);
   #@lines = <>;

#print @lines;

   $_ = join('',<TEXTFILE>);
   close (TEXTFILE);

   while (/(.{0,1})$str(.{0,1})/gis) {
     $retval = 1;
     last;
   }                      

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the $file_name via sftp.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $retval;
}

=pod

=head2 SonusQA::DIAMAPP::logCheck()

  logCheck method checks for a particular string's presence in a certain log file which is already generated.
  The mandatory parameters are the name of file and the pattern  to be searched for in the log file. 
  The pattern is stored in a file and the pattern file name is passed as an argument

=over

=item Argument

 -file
    specify the file name which needs to be checked
 -pattern
    specify the  file name which contains the pattern to search for in the file

=item Returns

 n - number of occurences of the string specified.
 0-Failure when string is not found

=item Example(s)

 SonusQA::DIAMAPP::logCheck(-file => "/home/mpietsch/Logs/diamResults_NBS270_023.log",-pattern => "/home/mpietsch/Logs/pattern");

=back

=cut

sub logCheck {

    my(%args) = @_;
    my $sub = "logCheck()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Error if file is not set
    if ($args{-file} eq undef) {

        $logger->error(__PACKAGE__ . ".$sub File is not specified");
        return 0;
    }

    # Error if pattern file is not set
    if ($args{-pattern} eq undef) {

        $logger->error(__PACKAGE__ . ".$sub pattern file is not specified");
        return 0;
    }

    # Check if pattern exists in the specified log file

    my $find = `grep  -f $args{-pattern} $args{-file} | wc -l`;
    $logger->debug(__PACKAGE__ . ".$sub Number of occurences of the pattern $args{-string} in $args{-file} is $find");

    return $find;


} # End sub logCheck   

=pod

=head2 SonusQA::DIAMAPP::getFileToLocalDirectoryViaSFTP()

  This function is to get a specified file from the named directory on remote host to a local machine.

=over

=item Argument

  1st Arg  -  the shell session name;
  2nd Arg  -  the local directory where the log file will be stored after sftp;
  3rd Arg  -  the remote directory where the log file store (in the CE server);
  4th Arg  -  the log file name;

=item Returns

  -1 - function fail;
  0  - fail (permission denied);
  1  - success;

=item Example(s)

  SonusQA::DIAMAPP::getFileToLocalDirectoryViaSFTP($local_shell_session,$local_log_directory,$sftp_log_directory,$file_name);

=back

=cut

sub getFileToLocalDirectoryViaSFTP {

    my ($shell_session,$local_directory,$remote_directory,$file_name)=@_;
    my $sub_name = "getFileToLocalDirectoryViaSFTP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $local_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory local directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }                                       
   unless ( $remote_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory remote directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name file from $remote_directory directory to $local_directory 
directory.");

    unless ( $shell_session->{conn}->prompt('/sftp> $/') ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to set the 'sftp> ' prompt.");
        return -1;
    }

    $shell_session->{CMDRESULTS} = ();

    my $cmd="lcd $local_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd($cmd);        # The expected return should be empty;
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
    }

    $shell_session->{CMDRESULTS} = ();      

   $cmd="cd $remote_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd("$cmd");
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            return -1;
        }
    }

    # Setting the timeout to 300 seconds as the default timeout is too short to transfer a large coredump file size.
    $cmd="get $file_name";
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name, wait...");
    unless ( @{$shell_session->{CMDRESULTS}}=$shell_session->{conn}->cmd(
                                                            String => $cmd,
                                                            Prompt => '/sftp> /',
                                                            Timeout=> 300,
                                                        ))
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd");
        return -1;
    }                                                        

   # Checking the possible get output message;
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;
        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to get $file_name:'No such file or 
directory'.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /(couldn't|Permission denied)/i ){
            $logger->debug(__PACKAGE__ . ".$sub_name: Permission denied...\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /\S+\s+100%\s+\d+/ ) {
            # If successful, the result looks like:
            # /var/log/sonus/sgx/coredump/core.CE_2N_Comp_N 100%  473MB  43.0MB/s   00:11

            $logger->debug(__PACKAGE__ . ".$sub_name: Successfully completed the file transfer - 100%.");
            last;
        }
        # Otherwise, the return should be the transfering messages.
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the $file_name via sftp.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}
