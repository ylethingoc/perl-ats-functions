package SonusQA::SIPP;

=head1 NAME

SonusQA::SIPP- Perl module for SIPP application control.

=head1 AUTHOR

Malcolm Lashley - mlashley@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   ##use SonusQA::SIPP; # Only required until this module is included in ATS above.
   my $obj = SonusQA::SIPP->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               -cmdline => "<sipp command line options, e.g. -sn uac -p 1234 -trace_err etc.>"
                               );
                               note: -bg will be appended -cmdline to run SIPP when the background methods are
                               called, and will be stripped (if provided) when invoking the single-shot methods.

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for the SIPP test tool.
It provides methods for starting and stopping single-shot and load testing, most cli methods returning true or false (0|1).
Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, 
allowing the engineer to specific which attributes to use.  Complete examples are given for each method.

=head2 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
# use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use File::Basename;
use File::Path qw(mkpath);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);


=head2 doInitialization

    Routine to set object defaults and session prompt.

=over

=item Arguments:

        Object Reference

=item Returns:

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
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{SIPPPATH} = "/ats/bin/sipp";
  $self->{PID} = 0; # We will use PID to determine if an instance is running or not,
    # this means we
    #   set PID to the real PID on starting the application, background case,
    #   to -1 for starting in foreground
    #   and reset to 0 when stopping.
  $self->{LASTPID} = 0; # We use this to store the previous PID when the simulation is stopped, required
    # to retrieve log/statistics files which include the PID and scenario name
  
  # Set some defaults for sipp cmdline options if the user specifies nothing (for demo purposes really, there's no *good* defaults)
  if ( exists $args{-cmdline} ) {
    $self->{USER_ARGS} = $args{-cmdline}
  } else {
    $self->{USER_ARGS} = "-sn uac localhost"; # to store user defined args.
  }  
  
  $self->{START_TIMEOUT} = 10; # using in startSingleShot()

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

sub setSystem(){
  my($self)=@_;
  my $subName = 'setSystem';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);

  # Fix for TOOLS-7229
  # If LOGIN -> 1 -> TYPE is set in TMS, we execute 'sudo su' 
  if($self->{OBJ_LOGIN_TYPE} eq 'sudo'){
        $cmd = 'sudo su';
        $logger->debug(__PACKAGE__ . ".$subName: Running '$cmd', sicne user has set LOGIN->1->TYPE is 'sudo'");
        unless($self->{conn}->cmd($cmd)){
            $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
            $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
            $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
    	    $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
		$main::failure_msg .= "TOOLS:SIPP-Login Error; ";
            return 0 ;
        }
  }

  $self->{conn}->cmd("bash");
  $self->{conn}->cmd("unset PROMPT_COMMAND");
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".$subName: Setting prompt to '" . $self->{conn}->prompt . "' from '$prevPrompt'");

  $cmd = 'export PS1="AUTOMATION> "';
  #cahnged cmd() to print() to fix, TOOLS-4974
  unless($self->{conn}->print($cmd)){
    $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
    $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
    $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
    $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SIPP-Login Error; ";
    return 0 ;
  }

  unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
    $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
    $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
    $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
    $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SIPP-Login Error; ";
    return 0 ;
  }

  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".$subName: SET PROMPT TO: " . $self->{conn}->last_prompt);
  # Clear the prompt
  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
  $self->{conn}->cmd('export TERM="xterm"'); #setting the TERM to xterm. Fix TOOLS-5618
  $self->{conn}->cmd('set +o history');
  $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
  return 1;
}

=head3 SonusQA::SIPP::startBackground(<command>)

  Start SIPP in the background, used for load testing.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  e.g
    -sf malc.xml -r 100 -d 1500 -l 6000 10.31.200.60
  the -bg (background) option is forced on by this method if not specified by the user.

=over

=item Returns:
  (Set's $self->{PID} to the PID of the started process).

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
    $logger->info(__PACKAGE__ . ".startBackground  Starting sipp with args $cmd");
    my @lines = $self->{conn}->cmd( $self->{SIPPPATH} . " " . $cmd );
    # Get PID
    foreach (@lines) {
		$logger->info(__PACKAGE__ . ".startBackground  $_");
        if(m/^(\d+)$/){
	$self->{PID} =$_;last;
	}elsif(m/PID/) {
        $logger->info(__PACKAGE__ . ".startBackground  SIPP1-PID - Match\n");
        $self->{PID} = $_;
        $self->{PID} = $1 if ($self->{PID} =~ /.*\sPID=\[(\d+)\]/);
	last;
	}
    }
    if ($self->{PID} == 0) {
      if($self->{CMDERRORFLAG}){
         $logger->warn(__PACKAGE__ . ".startBackground  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
         &error(__PACKAGE__ . ".startBackground Failed to get SIPP PID, manual cleanup is likely required\n");
      } else {
         $logger->warn(__PACKAGE__ . ".startBackground Failed to get SIPP PID, manual cleanup is likely required\n");
		$main::failure_msg .= "TOOLS:SIPP-Failed Starting SIPP; ";	
         return 0;
      }
    } 

    $self->{LASTPID} = $self->{PID};      
    $logger->info(__PACKAGE__ . ".startBackground  Started SIPP with PID $self->{PID}\n");
    return 1;
  }
}

=head3 SonusQA::SIPP::gracefulStop(<timeout>)

  Send a SIGUSR1 (equivalent to pressing 'q' from the Gui, to cause SIPP to stop
  making new calls and exit once all existing calls are done.
  <timeout> in seconds is the number of seconds to wait for the SIPP application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.
  -Used only for background SIPP instances (started with startBackground()

=over

=item Returns:
  1 on successful termination
  0 on timeout.

=back

=cut

sub gracefulStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".gracefulStop");
  $logger->info( __PACKAGE__ . ".gracefulStop  Terminating SIPP, PID=$self->{PID}, timeout = $timeout seconds.");
  
  my $count=0;
 $self->{conn}->cmd("kill -SIGUSR1 $self->{PID}");


  while ($count < $timeout) {
     my @lines=(); 

    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.

     @lines = $self->{conn}->cmd("pidof sipp");
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
      $logger->info( __PACKAGE__ . ".gracefulStop  Waiting for SIPP to terminate iteration $count/$timeout.");
    }
    sleep 1;
    $count++;
  }
  $logger->warn( __PACKAGE__ . ".gracefulStop  WARNING - SIPP (PID=$self->{PID}) failed to stop.");
	$main::failure_msg .= "UNKNOWN:SIPP-Call Failure; ";
  return 0
}

=head3 SonusQA::SIPP::hardStop(<timeout>)

  Send a SIGKILL to cause SIPP to exit immediately, possibly leaving calls hanging.
  <timeout> in seconds is the number of seconds to wait for the SIPP application to finish,
  a general rule of thumb is to set this to your call hold time plus a fudge factor.
  -Used only for background SIPP instances (started with startBackground()

=over  

=item Returns:

  1 on successful termination
  Calls &error on timeout - SIGKILL is assumed to be an unstoppable force, if this
  fails then we can't vouch for the state of the controlled system, so we might as well bail.

=back

=cut

sub hardStop {
  my ($self,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".hardStop");
  $logger->warn( __PACKAGE__ . ".hardStop  Terminating SIPP, PID=$self->{PID}, some calls may be left hanging.");

  my $count=0;
  $self->{conn}->cmd("kill -SIGKILL $self->{PID}");
  while ($count < $timeout) {
  
    # Now we check if it's stopped, iterating thru until $timeout seconds have passed.
    my @lines = $self->{conn}->cmd("pidof sipp");
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
      $logger->info( __PACKAGE__ . ".hardStop  Waiting for SIPP to terminate iteration $count/$timeout.");
    $main::failure_msg .= "UNKNOWN:SIPP-Call Failure; ";
	}

    sleep 1;
    $count++;
  }
  &error( __PACKAGE__ . ".hardStop  WARNING - SIPP (PID=$self->{PID}) failed to stop (SIGKILL) we're boned");
  
}

=head3 SonusQA::SIPP::startSingleShot(<command>)

  Starts SIPP in the foreground, useful for singleshot testing where we want to check the return code.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  e.g
    -sf malc.xml -r 100 -d 1500 -l 6000 10.31.200.60
  The -bg option is stripped even if the user passes it in <command>.
  -NB this does not wait for the singleShot test to complete, see waitCompletion() below.

=over

=item Returns:
  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut

sub startSingleShot {
  my ($self,$cmd, $custom, $client)=@_;
  my $sub = 'startSingleShot';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  if( $self->{PID} ) {
	$main::failure_msg .= "TOOLS:SIPP-Failed starting SIPP - instance appears to already be running; ";
    $logger->warn(__PACKAGE__ . ".$sub This instance appears to already be running - NOT starting");
    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".$sub CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub ALREADY STARTED");
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
  } else {
        if(defined $client and exists $main::TESTBED{"sbx5000:1:ce0:hash"}->{HFE}->{1}->{IP}){ #TOOLS-18594
            $logger->debug(__PACKAGE__ . ".$sub: cmd: $cmd");

            #Next hop IP should be HFE ip instead of SIG_SIP IP
            $cmd =~ s/$main::TESTBED{"sbx5000:1:ce0:hash"}->{SIG_SIP}->{1}->{IP}/$main::TESTBED{"sbx5000:1:ce0:hash"}->{HFE}->{1}->{IP}/;

            #Inside xml file, [local_ip] and [media_ip] should be replaced with Public IP (i.e NODE -> 1 -> IP) and need to retain the Original file with its content unchanged.
            $cmd =~ s/-sf\s+(\S+)\.xml\s+/-sf $1_test.xml /;

            my $old_xml = $1.'.xml';
            my $new_xml = $1.'_test.xml';

            $self->{TO_DELETE} .= " $new_xml";

            $self->execCmd('sed -E \'s/\[(local_ip|media_ip)\]/'.$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}.'/\' '.$old_xml.' > '.$new_xml);
            $logger->debug(__PACKAGE__ . ".$sub: cmd after replacing next hop ip to HFE ip instead of SIG_SIP IP : $cmd");
        }

    $self->{STATUS} = 0;
    $cmd = $self->{USER_ARGS} unless($cmd);
    # Always run in Singleshot mode, no matter what the user supplies in -cmdline
    $cmd =~ s/-bg//g;
    unless($custom){
        $cmd =~ s/^.*sipp\s+//;
        $cmd = "$self->{SIPPPATH} $cmd";
    }
    $logger->info(__PACKAGE__ . ".$sub Starting sipp with args $cmd");
    unless ($self->{conn}->print( $cmd )) {
	  $main::failure_msg .= "TOOLS:SIPP-Failed starting SIPP; ";
      $logger->error(__PACKAGE__ . ".$sub COMMAND EXECTION ERROR OCCURRED");
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub COMMAND EXECUTION ERROR") if($self->{CMDERRORFLAG});
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
    }

    my ($prematch, $match, $time_out);
    if($cmd=~/> (.+)$/){
        $logger->warn(__PACKAGE__ . ".$sub: Didn't check actual start of SIPP, since the output is redirected to $1");
        $time_out=1;
        unless( ($prematch, $match) = $self->{conn}->waitfor(
                                                          -match => $self->{PROMPT},
                                                          -errmode => "return",
                                                          -timeout => $time_out)) {
            $logger->info(__PACKAGE__ . ".$sub Considering SIPP is started since we didn't get $self->{PROMPT} in 1s");
            $match = 'Scenario Screen'; #setting it to match the condition below
        }
    }
    else{
        unless( ($prematch, $match) = $self->{conn}->waitfor( 
                                                          -match => '/\-+ Scenario Screen \-+/',
                                                          -match => $self->{PROMPT},
                                                          -errmode => "return",
                                                          -timeout => $self->{START_TIMEOUT})) {
            $logger->error(__PACKAGE__ . ".$sub  SIPP is not started  $self->{START_TIMEOUT}s");
            $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
            $main::failure_msg .= "TOOLS:SIPP-Failed SIPP is not started in $self->{START_TIMEOUT}s";
            &error("CMD FAILURE: " . __PACKAGE__ . ".$sub SIPP is not started in $self->{START_TIMEOUT}s") if($self->{CMDERRORFLAG});
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

    if($match=~/Scenario Screen/){
        $self->{PID} = -1;
        $self->{LASTPID} = -1;
        $self->{STATUS} = 1;
        $logger->info(__PACKAGE__ . ".$sub: SIPP is started") unless($time_out == 1);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    }

    $logger->debug(__PACKAGE__ . ".$sub console out: $prematch");
    $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
    my $lastline = $self->{conn}->lastline;
    $logger->debug(__PACKAGE__ . ".$sub lastline: $lastline");
    my $exit_status;
    unless (($exit_status) = $self->{conn}->cmd("echo \$?")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to get return value of echo");
      $main::failure_msg .= "TOOLS:SIPP-Failed Failed to get return value of echo in startSingleShot";
      &error("CMD FAILURE: " . __PACKAGE__ . ".$sub Failed to get return value of echo") if($self->{CMDERRORFLAG});
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
    }

    chomp $exit_status;
    if ($exit_status){ 
        my $error_msg = ($lastline =~ m/\d+:\d+:\d+.\d+\s+\d+.\d+:\s+(.+)/) ? $1 : $lastline;
        $logger->error(__PACKAGE__ . ".$sub SIPP completed with error: $error_msg");
        $logger->debug(__PACKAGE__ . ".$sub Error code: $exit_status");
        $main::failure_msg .= "TOOLS:SIPP-Failed SIPP completed with error, $error_msg";
        &error("CMD FAILURE: " . __PACKAGE__ . ".$sub SIPP completed with error: $error_msg") if($self->{CMDERRORFLAG});
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;

    } else {
       $logger->info(__PACKAGE__ . ".$sub SIPP completed in ${time_out}s.");
       $self->{PID} = 0;
       $self->{STATUS} = 1;
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
       return 1;
    }
  }
}

=head3 SonusQA::SIPP::startServer(<command>)

  Starts SIPP SERVER in the foreground, useful for singleshot testing where we want to check the return code.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  The -bg option is stripped even if the user passes it in <command>.
	 The path shall be read in from the SIPP.pm file itself
        DEFAULT PATH IS :<$self->{SIPPPATH}> :  /ats/bin/sipp
  Command passed shall not have the above path specified, as shown in example below

=over

=item Example: 
 my $cmd1 = "-sf /ats/NBS/V0800/NBS8_INREGL/SIPP/NBS8_001_SERVER.xml -p 5091 -mp 1211 -m 1"
 $sippObj1->startServer($cmd1);
 It shall be invoked after appending the path as :
        /ats/bin/sipp -sf /ats/NBS/V0800/NBS8_INREGL/SIPP/NBS8_001_SERVER.xml -p 5091 -mp 1211 -m 1
  NB this does not wait for the singleShot test to complete, see waitCompletionServer() below.

=item Returns:
  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut

sub startServer {
  my ($self,$cmd1)=@_;
  my $sub = "startServer";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  my $ret = $self->startSingleShot($cmd1);
  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
  return $ret;
}


=head3 SonusQA::SIPP::startClient(<command>)

  Starts SIPP CLIENT in the foreground, useful for singleshot testing where we want to check the return code.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  The -bg option is stripped even if the user passes it in <command>.
  The path shall be read in from the SIPP.pm file itself 
	DEFAULT PATH IS :<$self->{SIPPPATH}> :  /ats/bin/sipp
  Command passed shall not have the above path specified, as shown in example below 
  my $cmd2 = "-sf /ats/NBS/V0800/NBS8_INREGL/SIPP/NBS8_001_CLIENT.xml -s 988681234 -p 6091 10.34.20.114 -m 1 -mp 2345";
 $sippObj2->startClient($cmd2);
 It shall be invoked after appending the path as : 
	/ats/bin/sipp -sf /ats/NBS/V0800/NBS8_INREGL/SIPP/NBS8_001_CLIENT.xml -s 988681234 -p 6091 10.34.20.114 -m 1 -mp 2345
  NB this does not wait for the singleShot test to complete, see waitCompletionClient() below.

=over

=item Returns:
  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut

sub startClient {
  my ($self,$cmd2)=@_;
  my $sub = "startClient";  
  my $timeout = 1;
  $self->{STATUS} = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

  my $ret = $self->startSingleShot($cmd2, '', 1); #passing 1 as the third argument to indicate client is calling startSingleShot 
  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
  return $ret;
}

=head3 SonusQA::SIPP::startCustomServer(<command>)

  Starts CUSTOMIZED SIPP SERVER in the foreground, useful for singleshot testing where we want to check the return code.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  The -bg option is stripped even if the user passes it in <command>.
  Command passed shall have the path to customized sipp specified as in example below
  my $cmd1 = "/ats/tools/sipp-2.0.1.src/sipp -sf $sipppath$testcase_SERVER.xml -m 1 -i $sipp_ip -p $calledport";
 $sippObj1->startCustomServer($cmd2);
  NB this does not wait for the singleShot test to complete, see waitCompletionServer() below.

=over

=item Returns:
  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut


sub startCustomServer {
  my ($self,$cmd3)=@_;
  my $sub = "startCustomServer";  
  my $timeout = 1;
  $self->{STATUS} = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

  my $ret = $self->startSingleShot($cmd3, 1);

  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
  return $ret;
}


=head3 SonusQA::SIPP::startCustomClient(<command>)

  Starts  CUSTOMIZED SIPP CLIENT in the foreground, useful for singleshot testing where we want to check the return code.
  If <command> is specified, it is expected to be a well formatted set of sipp command line options,
  The -bg option is stripped even if the user passes it in <command>.
Command passed shall have the path to customized sipp specified as in example below  
my $cmd2 = "/ats/tools/sipp-2.0.1.src/sipp -sf $sipppath$testcase_CLIENT.xml -m 1 -i $sipp_ip -p $callingport $gsx_ssip:5060 -mp $mediaport1";
 $sippObj2->startCustomClient($cmd2);
  NB this does not wait for the singleShot test to complete, see waitCompletionClient() below.

=over

=item Returns:
  1 on success (Set's $self->{PID} to -1).
  0 on failure to start.

=back

=cut

sub startCustomClient {
  my ($self,$cmd4)=@_;
  my $sub = "startCustomClient";  
  my $timeout = 1;
  $self->{STATUS} = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

  my $ret = $self->startSingleShot($cmd4, 1, 1);#passing 1 as the third argument to indicate client is calling startSingleShot

  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
  return $ret;
}


=head3 SonusQA::SIPP::waitCompletion(<timeout>)
  Used to wait for a singleshot test to complete, timeout in seconds.

=over

=item Arguments:
  Optional ::
   1. timeout : Pass the argument as Scalar : "$timeout" for overriding the value for default timeout. 

   2. Expected Return Code / Expected Return Code and timeout ::  Whenever there is a need to check for the expected return code, we should the pass the hash reference as following : 
      %hash = ( -expectedReturnCode => '97' , 
                -timeout => '90'
              ) ; 

         OR (when you want to use the default timeout ) : 

     %hash = ( -expectedReturnCode => '97' ) ; 
     $reference = \%hash ;  

=item Returns:
  1 if the test is complete and SIPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=item USAGE : 
  $timeout = 90 ; 
  unless($testtool_sipp_uas->waitCompletion($timeout)){
     $logger->info(__PACKAGE__ . " . SERVER ERROR");
     return 0 ; 
  }  

  %hash = ( -expectedReturnCode => '97' , -timeout => '120') ; 
  $reference = \%hash ; 
  unless($testtool_sipp_uas->waitCompletion($reference)){
     $logger->info(__PACKAGE__ . " . SERVER ERROR");
     return 0 ; 
  } 

=back

=cut

sub waitCompletion {
      
    # FYI - SIPP return codes
    #    0: All calls were successful
    #    1: At least one call failed
    #   99: Normal exit without calls processed
    #   -1: Fatal error

  my ($self,$timeout)=@_; 
  my $sub = "waitCompletion" ; 
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  $logger->debug(__PACKAGE__ . ".$sub Passed parameter, timeout = $timeout");
  my ($match,$prematch,$expected_return_code,@cmdResults) ;
  my $prompt = '/AUTOMATION\> $/';
  if(!$self->{PID}) {
     if($self->{STATUS}){
      $logger->info(__PACKAGE__ . ".$sub Successfully detected SIPP completion");    
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
      return 1;
    }
    else {
      $logger->error(__PACKAGE__ . ".$sub SIPP not running");    
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;    
    }    
  }
  elsif( $self->{PID} == -1 ) { 
    if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub  No timeout specified, using default ($timeout s)");
    } else {        
      if (defined ref($_[1]) and ref($_[1]) eq 'HASH' )  {
          $logger->debug(__PACKAGE__ . ".$sub Paramter passed is hash reference \n".Dumper($timeout)) ;  
          my %hash = %$timeout ; 
          $expected_return_code = $hash{-expectedReturnCode} ;  
          $timeout = (defined $hash{-timeout}) ? $hash{-timeout} : $self->{DEFAULTTIMEOUT};       
          $logger->debug(__PACKAGE__ . ".$sub Paramter passed are : $expected_return_code and $timeout \n");    
      } else {
          $logger->debug(__PACKAGE__ . ".$sub Paramter passed is Scalar i.e. timeout value is ($timeout s) \n");           
      }
    }

    # Wait for completion
    unless(($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT}, -errmode => "return", -timeout => $timeout)){
        $logger->warn(__PACKAGE__ . ".waitCompletion  SIPP did not complete in $timeout seconds.");
        $main::failure_msg .= "UNKNOWN:SIPP-Call Failure; ";
        $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");

        my @out;
        foreach ("qq", "\cC"){
            my $cmd = ($_ eq 'qq') ? $_ : 'Ctrl+c';
            unless(@out = $self->{conn}->cmd($_)){
                $logger->warn(__PACKAGE__ . ".$sub Couldn't get prompt ($self->{PROMPT}) after executing '$cmd'");
                $logger->debug(__PACKAGE__ . ".$sub errmsg: ". $self->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub lastline: ". $self->{conn}->lastline);
                $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
            }
            else{
                $logger->debug(__PACKAGE__ . ".$sub output for '$cmd' : ".Dumper(\@out));
                $logger->error(__PACKAGE__ . ".$sub  SIPP killed using '$cmd'");
                last;
            }
        }
     unless(@out = $self->{conn}->cmd('echo TEST123')){
            $logger->error(__PACKAGE__ . ".$sub Couldn't get prompt ($self->{PROMPT}) after executing 'echo TEST123'");
            $logger->error(__PACKAGE__ . ".$sub this shell session is hosed and our attempts to recover it have failed.");
            $logger->debug(__PACKAGE__ . ".$sub errmsg: ". $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub lastline: ". $self->{conn}->lastline);
            $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
        }
        else{
            $logger->debug(__PACKAGE__ . ".$sub output for 'echo TEST123' : ".Dumper(\@out));
            $self->{PID} = 0;                     # No instance running now.
            unless(grep {/TEST123/} @out){
                unless(($prematch,$match) = $self->{conn}->waitfor(-match => $self->{PROMPT})){
                    $logger->error(__PACKAGE__ . ".$sub Detected a probably unrecoverable error in the shell interaction.");
                    $logger->debug(__PACKAGE__ . ".$sub errmsg: ". $self->{conn}->errmsg);
                    $logger->debug(__PACKAGE__ . ".$sub lastline: ". $self->{conn}->lastline);
                    $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
                    $self->{PID} = -1; #setting back to -1, since we were not able to get the prompt and dont want to start sipp
                }
                else{
                    $logger->debug(__PACKAGE__ . ".$sub Got the prompt '$self->{PROMPT}' after 'echo TEST123' : $prematch");
                }
            }
        }

        $logger->debug(__PACKAGE__ . ".$sub Clearing the buffer");
        $self->{conn}->buffer_empty;

        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  } else {
    $logger->warn(__PACKAGE__ . ".waitCompletion Called but SIPP is not marked as running a single-shot test.");
    $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SIPP-Call Failure; ";
    return 0;
  }

  $logger->info(__PACKAGE__ . ".waitCompletion Successfully detected SIPP completion, getting status");
# $logger->debug(__PACKAGE__ . "\SIPP Screen Output :\n $prematch"); 
  unless (@cmdResults = $self->{conn}->cmd(String => "echo \$?", Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".waitCompletion  Failed to get return value");
    map { $logger->warn(__PACKAGE__ . ".waitCompletion\t\t$_") } @cmdResults;
  }; 


  chomp @cmdResults;

  my $match_value ; 

  if (defined $expected_return_code) {
      $match_value = $expected_return_code ;     
  } else {
      $match_value = 0 ; 
  } 

  $logger->debug(__PACKAGE__ . ".$sub : Match Value for comparing with echo output is : $match_value "); 
  $self->{PID} = 0;                     # No instance running now.

  if ($cmdResults[0] == $match_value){
    $logger->info(__PACKAGE__ . ".waitCompletion  SIPP command returned success with code : $cmdResults[0]");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
  } else {
    $logger->warn(__PACKAGE__ . ".waitCompletion  SIPP command returned error code $cmdResults[0]");
     $logger->debug(__PACKAGE__ . "waitCompletion SIPP Screen Output :\n $prematch");     ##### TOOLS-8148
	if ($cmdResults[0] == 255) {
		$main::failure_msg .= "TOOLS:SIPP-Wrong SIPP Path; ";
		}
	elsif($cmdResults[0] == 254) {
		$main::failure_msg .= "TOOLS:SIPP-Port Clash; ";
		}
	else
		{
		my $fail_reason = $1 if($prematch =~ /.*((while expecting|Aborting call on) .*)/);
		$main::failure_msg .= "UNKNOWN:SIPP-Call Failure: $fail_reason; ";
		}

    if($self->{CMDERRORFLAG}){
      $logger->warn(__PACKAGE__ . ".waitCompletion  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
      &error("SIPP command returned error code $cmdResults[0]");

    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
  }
}


=head3 SonusQA::SIPP::waitCompletionServer(timeout)

 This subroutine shall be used to wait for the completion of server instance

=over

=item Arguments:

  Optional ::
   1. timeout : Pass the argument as Scalar : "$timeout" for overriding the value for default timeout. 

   2. Expected Return Code / Expected Return Code and timeout ::  Whenever there is a need to check for the expected return code, we should the pass the hash reference as following : 
      %hash = ( -expectedReturnCode => '97' , 
                -timeout => '90'
              ) ; 
     OR (when you want to use the default timeout ) : 

     %hash = ( -expectedReturnCode => '97' ) ; 
     $reference = \%hash ;  

=item Returns:
  1 if the test is complete and SIPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=item USAGE : 

 please refer to the documentation for waitCompletion() subroutine. 

=back

=cut

sub waitCompletionServer {

  my ($self,$timeout)=@_;
  my $sub = "waitCompletionServer" ;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");  
  my $result = $self->waitCompletion($timeout);
  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
  return $result;

}


=head3 SonusQA::SIPP::waitcompletionClient(timeout)

 This subroutine shall be used to wait for the completion of client instance

=over

=item Arguments:
  Optional ::
   1. timeout : Pass the argument as Scalar : "$timeout" for overriding the value for default timeout. 

   2. Expected Return Code / Expected Return Code and timeout ::  Whenever there is a need to check for the expected return code, we should the pass the hash reference as following : 
      %hash = ( -expectedReturnCode => '97' , 
                -timeout => '90'
              ) ; 
     OR (when you want to use the default timeout ) : 

     %hash = ( -expectedReturnCode => '97' ) ; 
     $reference = \%hash ;  

=item Returns:
  1 if the test is complete and SIPP exit code does not indicate any failures.
  If CMDERRORFLAG is FALSE
  0 if either a timeout occurs, or the test fails
  If CMDERRORFLAG is TRUE
  calls the inherited ATS error() method (see ATS documentation for details)

=item USAGE : 
 please refer to the documentation for waitCompletion() subroutine.  

=back

=cut

sub waitCompletionClient {
	
  my ($self,$timeout)=@_;
  my $sub = "waitCompletionClient" ;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  my $result = $self->waitCompletion($timeout);
  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ");
  return $result;
}

=head3 SonusQA::SIPP::DESTROY

 Override the DESTROY method inherited from Base.pm, we'll use this to attempt
 to kill (forcefully) any running SIPP instances before we are destroyed.

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
      $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up foreground instance");
      $self->{conn}->print("qq");
    } elsif ($self->{PID} > 0) {
      $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up background instance");
      $self->hardStop(1);
    } else {
      $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] No running SIPP instance to cleanup");
    }
    if( $self->{TO_DELETE} ){ #TOOLS-18594
	$logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Removing Created xml files");

#Deleting the created XML  file in startSingleShot( ) for Client.
	$self->execCmd('rm -f'.$self->{TO_DELETE});
    }
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

#*****************************************************************************

=head2 createcsvfile()
 
    This function enables dynamic creation of the csv file on the SIPP server. The name of the
    file needs to be passed as an input argument. If the file is already present, then the
    contents are cleared.

=over

=item Argument: 
    Name of the file.
    Optional: 
       1: $content, which will be written into CSV file along with "SEQUENTIAL"

=item Return:
    1: Success
    0: Failure 

=item usage:
    1: By Default, It will create a CSV file with content "SEQUENTIAL". 
       my $csvResult = $sippObject->createcsvfile("/ats/NBS/sample.csv");
       This would create a file sample.csv under /ats/NBS directory on the sipp server. 
    2: While creating CSV file, If you want to add some content to "SEQUENTIAL", for Example as "SEQUENTIAL PRINTF=250000", usage changes as below
       my $content = "PRINTF=250000";
       my $csvResult = $sippObject->createcsvfile("/ats/NBS/sample.csv",$content);  

=back

=cut

sub createCSVFile {
    
  my($self, $filename,$input) = @_;
  my $sub = "createCSVFile";
  my ($retVal, @retVal);
    
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $self->{CSVFILENAME} = $filename;
    
  unless ( $self->{CSVFILENAME} ) {
    $logger->error(__PACKAGE__ . ".$sub  .csv full file name not defined");
	$main::failure_msg .= "TOOLS:SIPP-Undefined CSV Filename; ";
    return 0;
  }
  
  # Clear the contents of the file if it already exists. If not, create a new one
  my $cmd1 = defined $input ? "echo SEQUENTIAL $input > ".$self->{CSVFILENAME} : "echo SEQUENTIAL > ".$self->{CSVFILENAME} ;
  $logger->info(__PACKAGE__ . ".$sub Executing command $cmd1");
  @retVal = $self->{conn}->cmd($cmd1);
  $retVal = join '', @retVal;
  if ($retVal){
    $logger->error(__PACKAGE__ . ".$sub .Unable to write to file $self->{CSVFILENAME}");
    $logger->error(__PACKAGE__ . ".$sub .Command <$cmd1> returned <$retVal>");
	$main::failure_msg .= "TOOLS:SIPP-CSVFile Creation Failed; ";
    return 0;
  }
  
  $logger->info(__PACKAGE__ . ".$sub Created CSV file $self->{CSVFILENAME}");
  return 1;
  
}#End of createCSVfile()

#*****************************************************************************

=head2 appendToCSVFile()
 
    This function is used to write to the csv file on the SIPP server created using createCSVfile.
    The contents of the file needs to be passed as an input argument.

=over

=item Argument: 
    Contents of the file to be passed as an array.

=item Return:
    1: Success
    0: Failure 

=item usage:
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
	$main::failure_msg .= "TOOLS:SIPP-Undefined CSV Filename; ";
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
	$main::failure_msg .= "TOOLS:SIPP-CSVFile Updation Failed; ";
      return 0;
    }
  }
  
  $logger->info(__PACKAGE__ . ".$sub Updated CSV file $self->{CSVFILENAME}");
  return 1;

}#End of appendToCSVFile()

=head2 execCmd()

    This function enables user to execute any command on the SIPP server.

=over

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Return Value:

    Output of the command executed.

=item Usage:

    my @results = $sippObject->execCmd("ls /ats/NBS/sample.csv");
    This would execute the command "ls /ats/NBS/sample.csv" on the SIPP server and return the output of the command.

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
    
    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command

    $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
	$main::failure_msg .= "TOOLS:SIPP-$cmd Execution Failed; ";

        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        return @cmdResults;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd ...... : ".Dumper(\@cmdResults));
    return @cmdResults;
}   

=head2 getCurCountStats()

    This function is used to read the last line of statistics written in the xxxxx_counts.csv file by sipp. SIPP dumps the statistics that is
    displayed on the screen to a csv file when the -trace_counts option is set and this interface is used to read and return the value of the 
    last line in the file. The duration at which sipp writes to the file can be controlled using the -fd option while invoking the sipp instance
    using startClient/startServer/startCustomClient/startCustomServer interfaces.

  Pre-requisites:

    1. SIPP Version used should be 3.1 or above.
    2. -trace_counts option must be included while invoking sipp command without which the statistics file will not be created by sipp.

=over

=item Arguments:

    Name of the xml scenario file without the extension.

=item Return Value:

    Hash containing the counter names as the key and the count as the value.

=item Usage:

    my %retHash = $sippObject->getCurCountStats("uas"); # where uas.xml is the name of the scenario file

=back

=cut


sub getCurCountStats{

  my ($self,$xmlfileName)=@_;
  my ($match,$prematch,@tmp,@head2,@val2,$head1,$val1,$fName,$fName1,%retHash,$cmd);
  my $sub = "getCurCountStats";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> $xmlfileName");
  my $filepid = $self->{LASTPID} - 1; #Sipp uses the PID in the filename and it is one less than the actual PID
  #Incase of forgound the LASTPID is -1 , and that backgorund it is actual PID 
  if ( $self->{LASTPID} == '-1') {
     $cmd = "ls -lt $xmlfileName*_counts.csv";
  } else {
     $cmd = 'ls -lt ' . "$xmlfileName" . '_' . "$filepid" . '_counts.csv' ;
  }
  @tmp = $self->execCmd("$cmd");
  my $sippcmdresult = grep (/No such file or directory/, @tmp);
  if ( $sippcmdresult == 1 and  $self->{LASTPID} != '-1' ){
    $logger->debug(__PACKAGE__ . ".$sub Could not file a file ending with $filepid\_counts.csv.. Retrying ls -lrt to find the last csv file..");
    $cmd = "ls -lt $xmlfileName*_counts.csv";
    @tmp = $self->execCmd("$cmd");
    $sippcmdresult = grep (/No such file or directory/, @tmp);
  }
  chomp(@tmp);
  $logger->debug(__PACKAGE__ . ".getCurCountStats ...... : ".Dumper(\@tmp));
  if ( $sippcmdresult == 1){
     $logger->debug(__PACKAGE__ . ".$sub Could not find a file ending with $xmlfileName\_$filepid\_counts.csv ");
     $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
	$main::failure_msg .= "TOOLS:SIPP-.csv file NotFound; ";
     return 0;
  }

  $fName1  = $tmp[ 0 ];
  chomp($fName1);
  $fName1 =~ m/.*($xmlfileName\_\d+\_counts\.csv)/;
  $fName  = $1;


  $logger->debug(__PACKAGE__ . ".$sub Name of the Trace Counts file is $fName");

  if (defined $fName) {
    @tmp = $self->execCmd("head -1 $fName");
    $head1 = $tmp[0];
    @tmp = $self->execCmd("tail -1 $fName");
    $val1 = $tmp[0];

    @head2 = split /;/, $head1;
    @val2 = split /;/, $val1;

    for (my $i = 0; $i<$#head2; $i++) {
      $retHash{ $head2[$i] } = $val2[$i];
    }
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub");
    return %retHash;
  } else {
	$main::failure_msg .= "TOOLS:SIPP-TraceCount file NotFound; ";
    $logger->debug(__PACKAGE__ . ".$sub Unable to find the trace counts file! Please ensure that the -trace_counts option is included in the sipp command");
    $logger->debug(__PACKAGE__ . ".$sub Ensure that the sipp version being used is 3.1 or higher since -trace_counts option is not available in earlier versions!");
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub");
    return %retHash;
  }

}

=head2 getCurMsgRetransCnt(), getCurMsgTimeoutCnt(), getCurUnexpMsgCnt(), getCurMsgCnt()

    These functions are used to return the current value of the various counts which are displayed on the sipp screen. 
    A sample screen output is shown below -


------------------------------ Scenario Screen -------- [1-9]: Change Screen --
  Call-rate(length)     Port   Total-time  Total-calls  Remote-host
  10.0(0 ms)/1.000s   22055      0.00 s            0  10.34.17.172:5060(SCTP)

  0 new calls during 0.009 s period      9 ms scheduler resolution
  0 calls (limit 30)                     Peak was 0 calls, after 0 s
  0 Running, 0 Paused, 0 Woken up
  0 out-of-call msg (discarded)
  2 open sockets

                                 Messages  Retrans   Timeout   Unexpected-Msg
      INVITE ---------->         0         0         0
         100 <----------         0         0                   0
         180 <----------         0         0                   0
         183 <----------         0         0                   0
         200 <----------  E-RTD1 0         0                   0
         ACK ---------->         0         0
       Pause [      0ms]         0                             0
         BYE ---------->         0         0         0
         200 <----------         0         0                   0

------ [+|-|*|/]: Adjust rate ---- [q]: Soft exit ---- [p]: Pause traffic -----

    These functions are used to return the latest value of the Messages,Retrans,Timeout and Unexpected-Msg count which are 
    displayed on the screen. SIPP writes these statistics to a file when the -trace_counts option is included while invoking 
    the sipp instance.

=over

=item PRE-REQUISITES:

    1. SIPP Version used should be 3.1 or above.
    2. -trace_counts option must be specified while invoking sipp command.
    3. -fd option must be used to specify the desired interval (in seconds) at which the statistics is to be written to the file. Default value is 60 seconds.

=item Arguments:

    1. Name of the xml scenario file without the extension.
    2. Index of the message whose counter value is required.(Indexing starts with 0 and so the index of the first message will be 0)

=item Return Value:

    Latest value of the counter corresponding to the message.

=item Usage:

    To get the latest value of the number of INVITE messages that have been sent use getCurMsgCnt as follows-
                               my $ret = $sippObject->getCurMsgCnt("uas",0);

    To get the latest count of the number of 180 retransmissions, use getCurMsgRetransCnt as follows -
                               my $ret = $sippObject->getCurMsgRetransCnt("uas",2);

    To get the latest count of the number of BYE timeouts, use getCurMsgTimeoutCnt as follows -
                               my $ret = $sippObject->getCurMsgTimeoutCnt("uas",7);

    To get the latest count of the number of Unexpected messages received in place of 183, use getCurUnexpMsgCnt as follows -
                               my $ret = $sippObject->getCurUnexpMsgCnt("uas",3);

    where uas is the name of the xml file being used by the sipp instance and the second argument represents the index of the message.
    The frequency at which the statistics are written to the file is controlled by the -fd option in sipp. Its default value is 60 seconds.
    Please provide the -fd option with the desired time interval at which the statistics might be required while invoking the sipp instance.

=back

=cut

sub getCurMsgRetransCnt{

  my ($self,$xmlfileName,$msgNum)=@_;
  my $sub = "getCurMsgRetransCnt";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my %statHash = $self->getCurCountStats($xmlfileName);
  foreach my $key (%statHash) {
    if ($key =~ m/$msgNum\_.*\_Retrans/i) {
      $logger->debug(__PACKAGE__ . ".$sub $key = $statHash{$key}");
      return $statHash{$key};
    }
  }
  $logger->error(__PACKAGE__ . ".$sub ERROR finding Retransmission Count for Message number $msgNum"); 
  return -1;

}

sub getCurMsgCnt{

  my ($self,$xmlfileName,$msgNum)=@_;
  my $sub = "getCurMsgCnt";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %statHash = $self->getCurCountStats($xmlfileName);
  foreach my $key (%statHash) {
    if ($key =~ m/$msgNum\_.*\_(Recv|Sent)/i) {
      $logger->debug(__PACKAGE__ . ".$sub $key = $statHash{$key}");
      return $statHash{$key};
    }
  }

  $logger->error(__PACKAGE__ . ".$sub ERROR finding Message Count for Message number $msgNum"); 
  return -1;

}

sub getCurMsgTimeoutCnt{

  my ($self,$xmlfileName,$msgNum)=@_;
  my $sub = "getCurMsgTimeoutCnt";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %statHash = $self->getCurCountStats($xmlfileName);
  foreach my $key (%statHash) {
    if ($key =~ m/$msgNum\_.*\_Timeout/i) {
      $logger->debug(__PACKAGE__ . ".$sub $key = $statHash{$key}");
      return $statHash{$key};
    }
  }

  $logger->error(__PACKAGE__ . ".$sub ERROR finding Message Timeout Count for Message number $msgNum"); 
  return -1;

}

sub getCurUnexpMsgCnt{

  my ($self,$xmlfileName,$msgNum)=@_;
  my $sub = "getCurUnexpMsgCnt";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %statHash = $self->getCurCountStats($xmlfileName);
  foreach my $key (%statHash) {
    if ($key =~ m/$msgNum\_.*\_Unexp/i) {
      $logger->debug(__PACKAGE__ . ".$sub $key = $statHash{$key}");
      return $statHash{$key};
    }
  }

  $logger->error(__PACKAGE__ . ".$sub ERROR finding Unexpected Message Count for Message number $msgNum"); 
  return -1;

}

=head2 getFinalStats()

    This function is used to get the final statistics from sipp on the number of calls that were created, number of calls that were successful and the number of calls that failed.
    Ensure that the -trace_screen option is used while invoking the sipp instance which will enable sipp to dump the final statistics to a file that will be read by this interface. 
    This interface will return the Cumalative value of the Total Call Created, Successful Call and Failed Call as displayed on the final statistics screen before sipp exits. Hence 
    ensure that you call this interface after sipp completes so that the file is written.

=over

=item PRE-REQUISITES:

    1. -trace_screen option must be included while invoking sipp command without which the final statistics file will not be created by sipp.

=item Arguments:

    Name of the xml scenario file without the extension.

=item Return Value:

    Hash containing the counter names(TOTAL CALLS,SUCCESSFUL CALLS and FAILED CALLS) as the key and the count as the value.

=item Usage:

    my %retHash = $sippObject->getFinalStats("uas"); # where uas.xml is the name of the scenario file
    Contents of retHash would be as follows -
          $retHash{"TOTAL CALLS"} = 100;
          $retHash{"SUCCESSFUL CALLS"} = 100;
          $retHash{"FAILED CALLS"} = 0;

=back

=cut

sub getFinalStats{

  my ($self,$xmlfileName)=@_;
  my (%retHash,@tmp,$cmd,$fName,$fName1);
  my $sub = "getFinalStats";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $filepid = $self->{LASTPID} - 1; #Sipp uses the PID in the filename and it is one less than the actual PID
  #Incase of forgound the LASTPID is -1 , and that backgorund it is actual PID
  if ( $self->{LASTPID} == '-1') {
     $cmd = "ls -lrt $xmlfileName*_screen.log";
  } else {
    $cmd = 'ls -lrt ' . "$xmlfileName" . '_' . "$filepid" . '_screen.log' ;
  }
  @tmp = $self->execCmd("$cmd");
  my $sippcmdresult = grep (/No such file or directory/, @tmp); 
  if ( $sippcmdresult == 1 and  $self->{LASTPID} != '-1' ){
    $logger->debug(__PACKAGE__ . ".$sub Could not file a file ending with $filepid\_screen.log.. Retrying ls -lrt to find the last log file..");
	$main::failure_msg .= "TOOLS:SIPP-Screen.Log file NotFound; " ;
  $cmd = "ls -lrt $xmlfileName*_screen.log";
    @tmp = $self->execCmd("$cmd");
  }
  chomp(@tmp);

  $fName1  = $tmp[ $#tmp-1 ];
  chomp($fName1);
  $fName1 =~ m/.*($xmlfileName\_\d+\_screen\.log)/;
  $fName  = $1;

  $logger->debug(__PACKAGE__ . ".$sub Name of the SIPP final statistics log file is $fName");

  # Get the Failed Calls, Successful calls and Total calls created
  $cmd = "grep -i 'total call created' $fName";
  @tmp = $self->execCmd($cmd);
  chomp(@tmp);
  if ($tmp[0] =~ m/.*\|.*\|\s+(\d+)/) {
    $logger->debug(__PACKAGE__ . ".$sub Total Call Created (Cumulative) : $1");
    $retHash{"TOTAL CALLS"} = $1;
  } else {
    $logger->error(__PACKAGE__ . ".$sub Unable to find the Total Call Created!");
	$main::failure_msg .= "UNKNOWN:SIPP-Total CallCount Error; ";
  }

  $cmd = "grep -i 'Successful call' $fName";
  @tmp = $self->execCmd($cmd);
  chomp(@tmp);
  if ($tmp[0] =~ m/.*\|.*\|\s+(\d+)/) {
    $logger->debug(__PACKAGE__ . ".$sub Successful call (Cumulative) : $1");
    $retHash{"SUCCESSFUL CALLS"} = $1;
  } else {
	$main::failure_msg .= "UNKNOWN:SIPP-SuccessFul CallCount Error; ";
    $logger->error(__PACKAGE__ . ".$sub Unable to find the total number of Successful calls created by sipp!");
  }

  $cmd = "grep -i 'Failed call' $fName";
  @tmp = $self->execCmd($cmd);
  chomp(@tmp);
  if ($tmp[0] =~ m/.*\|.*\|\s+(\d+)/) {
    $logger->debug(__PACKAGE__ . ".$sub Failed call (Cumulative) : $1");
    $retHash{"FAILED CALLS"} = $1;
  } else {
	$main::failure_msg .= "UNKNOWN:SIPP-Failed CallCount Error; ";
    $logger->error(__PACKAGE__ . ".$sub Unable to find the total number of failed calls!");
  }

  return %retHash;
  
}

=head2 getStatsByType()
    This function is used to get the sipp statics based on value of specific type.

=over

=item PRE-REQUISITES:

    1. -trace_screen option must be included while invoking sipp command without which the final statistics file will not be created by sipp.

=item Arguments:
    -keyName  => Type based on which statics has to be retrived
    -keys     => values of above type , who statics has to be retrived
    -required => required column from statics
    -path     => path of statics csv file
    -xmlFileName => Name of the xml scenario file without the extension

=item Return Value:

    Hash containing the value for the requested types.

=item Usage:

    my %args = ( -keyName => 'TargetRate', -keys => [20,30,40], -required => ['CurrentTime', 'OutgoingCall(C)'], -path => '/home/autouser/SIPP/PCR8005/', -xmlFileName => 'PCR8005_01_UAC');
    my %result = $Obj->getStatsByType(%args)

    Contents of result hash would be as follows -
          $result{20}->{'OutgoingCall(C)'} = 49;
          $result{20}->{'CurrentTime'} = '2013-05-27,12:02:36';
          $result{30}->{'OutgoingCall(C)'} = 148;
          $result{30}->{'CurrentTime'} = '2013-05-27,12:02:41';
          $result{40}->{'OutgoingCall(C)'} = 297;
          $result{40}->{'CurrentTime'} = '2013-05-27,12:02:46'; 

=back

=cut

sub getStatsByType{
  my ($self, %args)=@_;
  my (%retHash,@temp,$cmd);
  my $sub = "getFinalStats";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  foreach ('-path', '-xmlFileName', '-keyName', '-keys', '-required') {
      unless (defined $args{$_}) {
          $logger->error(__PACKAGE__ . ".$sub manditory argument \'$_\' miising or empty");
          $logger->info(__PACKAGE__ . ".$sub Leaving <- [0]");
          return 0;
      }
  }

  unless ($self->{conn}->cmd("cd $args{-path}")) {
      $logger->error(__PACKAGE__ . ".$sub failed to get into directory \'$args{-path}\'");
      $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
      $logger->info(__PACKAGE__ . ".$sub Leaving <- [0]");
      return 0;
  }
 
  #redirecting error message to /dev/null, so that it won't affect output check 
  unless (@temp = $self->execCmd("/bin/ls -1t $args{-xmlFileName}*.csv 2> /dev/null") ) {
      $logger->error(__PACKAGE__ . ".$sub failed to get stats csv file");
      $logger->info(__PACKAGE__ . ".$sub Leaving <- [0]");
	$main::failure_msg .= "TOOLS:SIPP-StatsCSV file NotFound; " ;    
  return 0;
  }

  my @head1 = $self->execCmd("head -1 $temp[0]");
  my @head = split(';', $head1[0]);
  my %header = ();
  map {$header{$head[$_]} = $_} 0..$#head;

  my @stats = $self->execCmd("cat $temp[0]");

  my %result = ();
  foreach my $line (@stats) {
      chomp $line;
      my @splitData = split(";", $line);
      foreach my $key (@{$args{-keys}} ) {
         next unless ($splitData[$header{$args{-keyName}}] == $key);
         foreach (@{$args{-required}}) {
             #pick only the date,time
             if ($splitData[$header{$_}] =~ /(\d+\-\d+\-\d+)\s+(\d+:\d+:\d+)/) {
                 $splitData[$header{$_}] = "$1,$2";
             }
             $result{$key}->{$_} = $splitData[$header{$_}];
         }
      }
  }

  unless (scalar (keys %result) == scalar (@{$args{-keys}})) {
      $logger->error(__PACKAGE__ . ".$sub  did not get all the required data");
      $logger->error(__PACKAGE__ . ".$sub retrived only" .  Dumper(\%result));
      $logger->info(__PACKAGE__ . ".$sub Leaving <- [0]");
	$main::failure_msg .= "UNKNOWN:SIPP-Call Stats Error; ";
      return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub  succsess");
  return %result;
}
   
=head2 changeUserHome()
    This function is used to change the user home path to current user home path in all the files of given path.

=over

=item Arguments:
    path  => scripts path where we need to change the user id. 

=item Return Value:

    1 => for success
    0 => for failure

=item Usage:

    unless($sipp_obj->changeUserHome($script_path){
        $logger->error(__PACKAGE__ . ".$sub  Couldn't change the user id in scripts");
        $logger->debug(__PACKAGE__ . ".$sub Leaving <- [0]");
        return 0;
    }

=back

=cut

sub changeUserHome {
    my ($self,$script_path)=@_;

    my $sub = "changeUserHome";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless($script_path){
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument 'script path' is missed.");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
        return 0;
    }

    my $cmd = 'whoami';
    my ($user_id) = $self->execCmd($cmd);
    $user_id =~s/\s//g;
    unless($user_id){
        $logger->error(__PACKAGE__ . ".$sub: Couldn't get userid.");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Change user id to $user_id in scripts");
    #$cmd = qq(grep -rl '/home/[a-zA-Z]*/' ./ | xargs sed -i 's|/home/[a-zA-Z]*|/home/$user_id|g');
    $cmd = qq(grep -rl '/home/[a-zA-Z]*/' $script_path | xargs sed -i 's|/home/[a-zA-Z]*|/home/$user_id|g');
    unless ($self->execCmd("$cmd")) {
        $logger->error(__PACKAGE__ . ".$sub: Error in the $cmd execution.");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
	$main::failure_msg .= "TOOLS:SIPP-Wrong SIPP path; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".User id changed in scripts\n");
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
    return 1;
}



=head2 TODO - OTHER METHODS NOT YET IMPLEMENTED.

SonusQA::SIPP::gatherLogs() - retrieve any of the many log files generated by SIPP and return them to the user. (use $self->{LASTPID} to figure out the filename for the background case, we will also need to stash the SIPP scenario name at execution time since this also makes up part of the logfile name. (For background the PID in the filename is really the parent PID, so it will be LASTPID-1.)

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

=head3 SonusQA::SIPP::pt_collectlogs(arguments)

    This function just collects all the stats of sipp server/client that was started with a PID, which will be provided while calling this function, and dumps into ATS repository.

Arguments:
   1. -path => Mandatory. Path where sipp stats have to be dumped.
   2. -pid  => Mandatory. Pid with which sipp instance was started(in background).

Returns:
  1 on success 
  0 on failure.

=cut

sub pt_collectlogs {

my ($self, %args )=@_;
my $sub = "pt_collectlogs";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

my @cmd_res = ();
unless ( defined ( $args{-path} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument -path has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

unless ( defined ( $args{-pid} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument -pid has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

my $orig_path = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};

my %scpArgs;
$scpArgs{-hostip} = $self->{OBJ_HOST}; 
$scpArgs{-hostuser} = $self->{OBJ_USER};
$scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD}; 
$scpArgs{-sourceFilePath} = $scpArgs{-hostip}. ':' .$orig_path."/*$args{-pid}*"; 

$scpArgs{-destinationFilePath} = $args{-path}."/sipp_DATA/";
$logger->info(".$sub Creating dir : $scpArgs{-destinationFilePath}");
unless (mkpath($scpArgs{-destinationFilePath})) {
    $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir $scpArgs{-destinationFilePath} ");
}

$logger->debug(__PACKAGE__ . ".$sub: scp files  to $scpArgs{-destinationFilePath}");

unless(&SonusQA::Base::secureCopy(%scpArgs)){
    $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the sipp log files");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
	$main::failure_msg .= "TOOLS:SIPP-Failed to copy Logs; ";
    return 0;

}

$logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
return 1;

}

=head4 SonusQA::SIPP::generateCmdfromCSV(arguments)

	This function takes a CSV file as the input and returns the hash table with scenario filename as the key and the command as the value.

The format of the CSV file is as shown below.

     sf , RemoteIp , i , mp , p , EP2 , 3pcc , s , tls_key , tls_cert , ,
  CallFlow1_UAS.xml, ,10.54.80.9 ,76636,25769 , , , , , , ,
  BW_Proxy_CF1_Ingress.xml, ,10.54.80.101 , ,25768, , 127.0.0.1:4003, , , , ,
  BW_Proxy_CF1_Egress.xml, 10.54.160.41 ,10.54.80.101, ,6545,10.54.80.9:25769 , 127.0.0.1:4003 , 4443600002 , , , ,

Arguments:
1) Filename --> Mandatory

Return:
1) Command for success
2) 0 for failure

Example:

The subroutine is called as shown below:
my %cmd = SonusQA::SIPP::generateCmdfromCSV('SIPP.csv');

The command for the above scenario filename is obtained as shown below:
/ats/bin/sipp -sf BW_Proxy_CF1_Egress.xml -i 10.54.160.41 10.54.80.101 -p 6545 -EP2 10.54.80.9:25769 -3pcc 127.0.0.1:4003 -s 4443600002

=cut

sub generateCmdfromCSV{
    my $file_name = shift;
    my $sub = "generateCmdfromCSV";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless($file_name){
        $logger->error(__PACKAGE__ . ".$sub: File not passed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    `dos2unix $file_name`;

    unless(open(DATA,$file_name)){
        $logger->error(__PACKAGE__ . ".$sub: Unable to open file,$file_name");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SIPP-Undefined CSV Filename; ";
        return 0;
    }

    my @array = <DATA>;
    chomp @array;
    my @header = split(",",shift@array);
    my %hash;

    foreach(@array){
        my @values = split(",",$_);
        next, unless $values[0];
        my $cmd = "";
        for(my $column=0;$column<scalar@values;$column++){
            next,unless $values[$column];

            $cmd.= " -$header[$column] $values[$column]";
            $cmd =~ s/-RemoteIp//;
        }

        $hash{$values[0]} = $cmd;

    }

    close(DATA);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return %hash;
}


=head1 EXAMPLE CODE

  use ATS;
  use SonusQA::SIPP;

# Note - if you want this example code to do something, setup 'sipp -sn uas localhost'
in a seperate terminal to emulate the uas (receiving side of the call)

my $malc = SonusQA::SIPP->new(-OBJ_HOST => 'localhost',
                               -OBJ_USER => 'atd',
                               -OBJ_PASSWORD => 'sonus',
                               -OBJ_COMMTYPE => "SSH",
                               -cmdline => "-sn uac -m 20 localhost",
                               );

# Start the scenario identified at the object creation time
#(useful when running the same call load repeatedly with different impairments.)

  $malc->startBackground;     
  sleep 5;     
# Attempt a gracefulStop (wait for calls to complete, give it 5 seconds)
  if($malc->gracefulStop(5)) {
    print "w00t";
  } else {
    # Do a hardstop.
    $malc->hardStop(5);
  }

# Example 2 - singleshot test (assumes ->new() method called as above.

# This is a generic flag inherited from ATS objects, see their description. We use it to determine whether to call &error, if SIPP returns an error code, or to return failure to the calling function and let them handle it.
  $malc->{CMDERRORFLAG}=1;
# Start a single-shot testcase.
  $malc->startSingleShot("-sn uac -r 1 -m 1 localhost") or die "Failed to startSingleShot\n"; We use it to determine whether to call &error, if SIPP returns an error code, or to return failure to the calling function and let them handle it.
# Give it 2 seconds to complete. 
  $malc->waitCompletion(2) or die "Failed to complete\n";

#or use :

$sippObj1->startServer($cmd1)
$sippObj2->startClient($cmd2)
$sippObj1->waitCompletionServer($timeout)
$sippObj2->waitCompletionClient($timeout)

=cut

1;
