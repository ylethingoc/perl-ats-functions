package SonusQA::MGTS::MGTSHELPER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::MGTS;
use Net::SCP::Expect;
use POSIX qw(strftime);

=head1 NAME

SonusQA::MGTS::MGTSHELPER class

=head1 SYNOPSIS

use SonusQA::MGTS:MGTSHELPER;

=head1 DESCRIPTION

SonusQA::MGTS::MGTSHELPER provides a MGTS infrastructure on top of what is classed as base MGTS functions. These functions are MGTS specific.

=head1 AUTHORS

Susanth Sukumaran (ssukumaran@sonusnet.com)
Malcolm Lashley (mlashley@sonusnet.com)
Avinash Chandrashekar (achandrashekar@sonusnet.com)

=head1 METHODS

=head2 configureTriggerSock

=over

=item DESCRIPTION:

    This subroutine configures the socket to receive trigger messages from MGTS

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS::writeFishHookToDatafiles
    SonusQA::MGTS::setupRemoteHook

=item OUTPUT:

    0                - fail
    listenPortObject - the socket object created. Further any operation requires this socket uses
                       this object

=item EXAMPLE:

    unless ($mgts_object->configureTriggerSock()) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not configure socket to receive the trigger message from MGTS");
        return 0;
    }

=back

=cut

sub configureTriggerSock {
   my ($self, %args) = @_;
   my %a;

   my $sub = "configureTriggerSock()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);

   $logger->info(__PACKAGE__ . ".$sub : Writing the fishHook file");

   # Write the fishHook file in MGTS
   # This file contains the current systems (ATS) IP and a port number
   $self->writeFishHookToDatafiles();

   $logger->info(__PACKAGE__ . ".$sub : Opening a socket for trigger messages");

   # Open a socket to receive trigger messages
   my $listenPortObject = $self->setupRemoteHook();

   $logger->info(__PACKAGE__ .  ".$sub : listen_port_object : " . Dumper ($listenPortObject) . "\n");

   $logger->debug(__PACKAGE__ . ".$sub : Success - Trigger socket created");
   return $listenPortObject;

}

=head2 executeStateMachine

=over

=item DESCRIPTION:

    This subroutine executes a single MGTS state machine

=item ARGUMENTS:

    -testId              => Test Case ID
    -nodeName            => Node name
    -stateMachine        => State Machine name (This is unnecessary if -pasmMachineName is given.)
    -mgtsStatesDir       => MGTS States directory (This is unnecessary if -pasmMachineName is given.)
    -logDir              => ATS log directory
    -timeStamp           => Test suite execution start timestamp

    The following arguments are having default values. This needs to given only if
    the required values are changed
    -variant             => Test Varaint
                            The default value is "NONE"
    -stateTimeOut        => Timeout for a state machine execution. Once this timeout is
                            occurred, the state machine is stopped
                            Default value is 90 seconds
    -doNotLogMGTS        => If this flag is set to 1, the MGTS logging is not done
                            Default value is set 0
    -waitForTrigger      => Pass in a value of 1 if your state machine contains action states
                            that send trigger messages.  Default value is 0.
    -customProcessMsg    => Reference to a function which will perform custom processing
                            on the received trigger message.  If not included then the
                            standard processing will occur.
    -pasmMachineName     => The name of the state machine as expected by PASM.
                            Equivalent to $stateMachineDescri.

=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:getStateDesc
    SonusQA::MGTS:startExecContinue
    SonusQA::MGTS:areStatesRunning
    SonusQA::MGTS:checkResult
    SonusQA::MGTS:stopExec
    SonusQA::MGTS:downloadLog

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->executeStateMachine (-testId             => $testId,
                                               -nodeName           => $nodeName,
                                               -stateMachine       => $stateMachine,
                                               -logDir             => $log_dir,
                                               -mgtsStatesDir      => $mgtsStatesDir,
                                               -timeStamp          => $timestamp)) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not execute the MGTS state machine");
        return 0;
    }

=back

=cut

sub executeStateMachine {
   my ($self, %args) = @_;
   my %a = ( -stateTimeOut     => 90,
             -doNotLogMGTS     => 0,
             -waitForTrigger   => 0,
             -variant          => "NONE" );
   my $sub = "executeMGTSStateMachine()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my ( $timestamp , $logFileName );

   my $stateMachineDescri = "";
   if( ( $stateMachineDescri = $a{-pasmMachineName} ) eq "" ) {
      my $fullMgtsStateName = $a{-mgtsStatesDir} . $a{-stateMachine} . ".states";
      $stateMachineDescri = $self->getStateDesc(-full_statename => $fullMgtsStateName);
   } else {
      # Update state machine name for logs
      $a{-stateMachine} = $a{-pasmMachineName};
   }

   $logger->info(__PACKAGE__ . ".$sub : Starting state machine $a{-stateMachine} on node $a{-nodeName}");

    my $doNotLogMGTS = $a{-doNotLogMGTS};

   # Run the state machine
   if($doNotLogMGTS eq 1)
   {
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   } else {
      $timestamp = strftime "%Y%m%d-%H%M%S", localtime;
      $logFileName = 'MGTS_' . $a{-testId} . "_$a{-variant}" . "_$timestamp" .  "_" . $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$a{-nodeName} . ".log";
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri,
                                    -logfile     => $logFileName) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my $timeout = $a{-stateTimeOut};
   my $allTestsComplete = 0;
   my $pollingPeriod = 1;
   my $startLoopTime    = [gettimeofday];
   my $loopTimer        = 0;
   my $mgtsResult;
   my $executionStatus = "FAILED";

   my $result = 0;

   if( ( $timeout > 60 ) && ( $a{-waitForTrigger} == 0 ) ) { $pollingPeriod = $timeout/10; }

   # Loop till all the states are executed or the timeout occurs
   while ( (!$allTestsComplete) && (tv_interval($startLoopTime) < $timeout) ) {

      if( $a{-waitForTrigger} == 1 ) {
         $self->waitForTriggerMsg( -timeout             => $pollingPeriod,
                                   -customProcessMsg    => $a{-customProcessMsg} );
      } else {
         sleep( $pollingPeriod );
      }

      $allTestsComplete = 1;

      my $areStatesRunning = $self->areStatesRunning(-node => $a{-nodeName});

      if ( $areStatesRunning == 0 ) {
         $logger->info(__PACKAGE__ . ".$sub : $a{-stateMachine} execution completed");
         
         $mgtsResult = $self->checkResult( -node     => $a{-nodeName},
                                           -machine  => $stateMachineDescri);
         if ( $mgtsResult == 1) {
            $executionStatus = "PASSED";
            $logger->info(__PACKAGE__ . ".$sub : $a{-stateMachine} execution passed");
            $result = 1;
         } elsif ( $mgtsResult == 0) {
            $executionStatus = "FAILED";
            $logger->error(__PACKAGE__ . ".$sub : $a{-stateMachine} execution failed");
         } elsif ( $mgtsResult == -1) {
            $executionStatus = "ERROR";
            $logger->error(__PACKAGE__ . ".$sub : $a{-stateMachine} execution failed");
            $logger->error(__PACKAGE__ . ".$sub : MGTS script did not transition through PASS/FAIL node" .
                                         " OR MGTS::checkResult returned inconclusive result");
         } elsif ( $mgtsResult == -2 ) {
            $executionStatus = "ERROR";
            $logger->error(__PACKAGE__ . ".$sub : $a{-stateMachine} execution failed");
            $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::checkResult");
         } else {
            $logger->error(__PACKAGE__ . ".$sub : $a{-stateMachine} execution failed");
            $logger->error(__PACKAGE__ . ".$sub : Unexpected return code from MGTS::checkResult ".
                                         "for test-$a{-testId}, mgtsStateMachine-$a{-stateMachine}.");
         }
         last;
      }
      elsif ( $areStatesRunning == -1 ) {
         $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::areStatesRunning");
      }
      elsif ( $areStatesRunning == 1 ) {
         $allTestsComplete = 0;
      }
      else {
          $logger->error(__PACKAGE__ . ".$sub : Unexpected return code from MGTS::areStatesRunning.");
         last;
      }
   } # while loop

   if ( $allTestsComplete == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub : State Machine execution timed out");
      $logger->error(__PACKAGE__ . ".$sub : Start of FORCEFUL STOP OF SCRIPTS.");
      $logger->error(__PACKAGE__ . ".$sub : $a{-stateMachine} Script has been forcibly stopped due to timing out.");

      # The statemachine is hanging more than the expected time. The following call stops execution of any
      # state machine which is running on the given node
      #
      unless ($self->stopExec(-node => $a{-nodeName})) { }

      $logger->error(__PACKAGE__ . ".$sub : End of  FORCEFUL STOP OF SCRIPTS.");
      # END OF FORCEFUL STOP OF SCRIPTS
   }

   #logs
   if ($doNotLogMGTS eq 0) {
      if ( $self->downloadLog(-logfile => $logFileName,
                              -local_dir => $a{-logDir}) == 1 ) {
         my $grepCmd1 = "\\grep \"Warning: The following message does not match any templates\" $a{-logDir}/" . $logFileName;
         my $grepCmd2 = "\\grep \"Sequence Completed by Stop\" $a{-logDir}/" . $logFileName;
         my $grepResult1 = `$grepCmd1`;
         my $grepResult2 = `$grepCmd2`;
         if ( $grepResult1 ne "" || $grepResult2 ne "" ) {
            my $mgtsLogErrorFound=1;
            $logger->error(__PACKAGE__ .  ".$sub : \n#### LOG ERRORS FOUND\n##$grepResult1\n##$grepResult2\n");
         }
      } else {
         $logger->warn(__PACKAGE__ .  ".$sub : Error in downloading log file from MGTS");
      }
   }


   if( $a{-waitForTrigger} == 1 ) {
      $self->downloadRemoteHookLog( -testId    => $a{-testId},
                                    -logDir    => $a{-logDir},
                                    -timeStamp => $a{-timeStamp},
                                    -variant   => $a{-variant} );
   }

   $logger->debug(__PACKAGE__ . ".$sub : Leaving sub with return code => $result");
   return $result;
}

=head2 executeTwoStateMachines

=over

=item DESCRIPTION:

    This subroutine executes a two MGTS state machines

=item ARGUMENTS:

    -testId              => Test Case ID
    -nodeName            => Node name
    -stateMachine        => State Machine name  (This is unnecessary if -pasmMachineName is given.)
    -nodeNameNext        => Next node name
    -stateMachineNext    => Next state machine name  (This is unnecessary if -pasmMachineName is given.)
    -mgtsStatesDir       => MGTS States directory  (This is unnecessary if -pasmMachineName is given.)
    -logDir              => ATS log directory
    -timeStamp           => Test suite execution start timestamp


    The following arguments are having default values. This needs to given only if
    the required values are changed
    -variant             => Test Varaint
                            The default value is "NONE"
    -timeout             => Timeout for waiting for a trigger message from MGTS
                            Default value is 60 seconds
    -stateTimeOut        => Timeout for a state machine execution. Once this timeout is
                            occurred, the state machine is stopped
                            Default value is 90 seconds
    -doNotLogMGTS        => If this flag is set to 1, the MGTS logging is not done
                            Default value is set 0
    -waitForTrigger      => Pass in a value of 1 if your state machine contains action states
                            that send trigger messages.  Default value is 0.
    -customProcessMsg    => Reference to a function which will perform custom processing
                            on the received trigger message.  If not included then the
                            standard processing will occur.
    -pasmMachineName     => The name of the state machine as expected by PASM.
                            Equivalent to $stateMachineDescri.
    -pasmMachineNext     => The name of the next state machine as expected by PASM.
                            Equivalent to $stateMachineDescriNext.


=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:getStateDesc
    SonusQA::MGTS:startExecContinue
    SonusQA::MGTS:areStatesRunning
    SonusQA::MGTS:checkResult
    SonusQA::MGTS:stopExec
    SonusQA::MGTS:downloadLog

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->executeTwoStateMachines (-testId             => $testId,
                                                   -nodeName           => $nodeName,
                                                   -stateMachine       => $stateMachine,
                                                   -nodeNameNext       => $nodeNameNext,
                                                   -stateMachineNext   => $stateMachineNext,
                                                   -timeStamp          => $timestamp)) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not execute the MGTS state machine");
        return 0;
    }

=back

=cut

sub executeTwoStateMachines {
   my ($self, %args) = @_;
   my %a = ( -doNotLogMGTS     => 0,
             -timeout          => 60,
             -stateTimeOut     => 90,
             -waitForTrigger   => 0,
             -variant          => "NONE" );
   my $sub = "executeTwoMGTSStateMachines()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );
   
   my ( $timestamp , $logFileName , $logFileNameNext );
   my $stateMachineDescri = "";
   my $stateMachineDescriNext = "";

   if( ( $stateMachineDescri = $a{-pasmMachineName} ) eq "" ) {
      my $fullMgtsStateName = $a{-mgtsStatesDir} . $a{-stateMachine} . ".states";
      $stateMachineDescri = $self->getStateDesc(-full_statename => $fullMgtsStateName);
   } else {
      # Update state machine name for logs
      $a{-stateMachine} = $a{-pasmMachineName};
   }

   if( ( $stateMachineDescriNext = $a{-pasmMachineNext} ) eq "" ) {
      my $fullMgtsStateNameNext = $a{-mgtsStatesDir} . $a{-stateMachineNext} . ".states";
      $stateMachineDescriNext = $self->getStateDesc(-full_statename => $fullMgtsStateNameNext);
   } else {
      # Update state machine name for logs
      $a{-stateMachineNext} = $a{-pasmMachineNext};
   }

   #Needs to run two state machines
   my $doNotLogMGTS = $a{-doNotLogMGTS};

   $logger->info(__PACKAGE__ . ".$sub : Starting state machine $a{-stateMachine} on node $a{-nodeName}");

   # Run the state machine
   if($doNotLogMGTS eq 1) {
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri,
                                    -reset_stats => 1) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      my $resetStat = 1;
      if ($a{-nodeName} eq $a{-nodeNameNext}) {
         $resetStat = 0;
      }

      # Run the state machine
      if ( $self->startExecContinue(-node        => $a{-nodeNameNext},
                                    -machine     => $stateMachineDescriNext,
                                    -reset_stats => $resetStat) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachineNext} on node $a{-nodeNameNext} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachineNext} on node $a{-nodeNameNext}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   } else {
       $timestamp = strftime "%Y%m%d-%H%M%S", localtime;
       $logFileName = 'MGTS_' . $a{-testId} . "_$a{-variant}" . "_$timestamp" .  "_" . $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$a{-nodeName} . ".log";
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri,
                                    -logfile     => $logFileName,
                                    -reset_stats => 1) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      my $resetStat = 1;
      if ($a{-nodeName} eq $a{-nodeNameNext}) {
         $resetStat = 0;
      }
      
      $timestamp = strftime "%Y%m%d-%H%M%S", localtime;
      $logFileNameNext = 'MGTS_' . $a{-testId} . "_$a{-variant}" . "_$timestamp" .  "_" . $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$a{-nodeNameNext} . ".log";
      
      # Run the state machine
      if ( $self->startExecContinue(-node        => $a{-nodeNameNext},
                                    -machine     => $stateMachineDescriNext,
                                    -logfile     => $logFileNameNext,
                                    -reset_stats => $resetStat) ) {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachineNext} on node $a{-nodeNameNext} started");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachineNext} on node $a{-nodeNameNext}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   # Check the status of both the nodes
   my $node_index = 0;
   my $tempLogFile;

   my $result = 0;
   my $resultNext = 0;

   while ($node_index lt 2) {
      # results
      my $timeout = $a{-stateTimeOut};

      my $pollingPeriod = 1;
      my $allTestsComplete = 0;
      my $startLoopTime    = [gettimeofday];
      my $loopTimer        = 0;
      my $mgtsResult;
      my $executionStatus = "FAILED";

      if( ( $timeout > 60 ) && ( $a{-waitForTrigger} == 0 ) ) { $pollingPeriod = $timeout/10; }

      $node_index = $node_index + 1;

      my $statusNode;
      my $statusStateName;
      my $statusStateDescri;

      if ($node_index eq 1) {
         $tempLogFile = $logFileName;
         $statusNode = $a{-nodeName};
         $statusStateName = $a{-stateMachine};
         $statusStateDescri = $stateMachineDescri;
      } else {
         $tempLogFile = $logFileNameNext;
         $statusNode = $a{-nodeNameNext};
         $statusStateName = $a{-stateMachineNext};
         $statusStateDescri = $stateMachineDescriNext;
      }

      # Loop till all the states are executed or the timeout occurs
      while ( (!$allTestsComplete) && (tv_interval($startLoopTime) < $timeout) ) {
         if( $a{-waitForTrigger} == 1 ) {
            $self->waitForTriggerMsg( -timeout          => $pollingPeriod,
                                      -customProcessMsg => $a{-customProcessMsg} );
         } else {
            sleep( $pollingPeriod );
         }

         $allTestsComplete = 1;

         my $areStatesRunning = $self->areStatesRunning(-node => $statusNode);

         if ( $areStatesRunning == 0 ) {
            $logger->info(__PACKAGE__ . ".$sub : $statusStateName execution completed");

            $mgtsResult = $self->checkResult( -node => $statusNode,
                                                       -machine => $statusStateDescri);
            if ( $mgtsResult == 1) {
               $executionStatus = "PASSED";
               $logger->info(__PACKAGE__ . ".$sub : $statusStateName execution passed");

               if ($node_index eq 1) {
                  $result = 1;
               } else {
                  $resultNext = 1;
               }
            }
            elsif ( $mgtsResult == 0) {
               $executionStatus = "FAILED";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
            } elsif ( $mgtsResult == -1) {
               $executionStatus = "ERROR";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : MGTS script did not transition through PASS/FAIL node" .
                                            " OR MGTS::checkResult returned inconclusive result");
            } elsif ( $mgtsResult == -2 ) {
               $executionStatus = "ERROR";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::checkResult");
            } else {
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : Unexpected return code from MGTS::checkResult ".
                                            "for test-$a{-testId}, mgtsStateMachine-$statusStateName.");
            }
         } elsif ( $areStatesRunning == -1 ) {
            $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::areStatesRunning");
         } elsif ( $areStatesRunning == 1 ) {
            $allTestsComplete = 0;
         } else {
            $logger->error(__PACKAGE__ . "Unexpected return code from MGTS::areStatesRunning.");
         }
      } # while loop

      if ( $allTestsComplete == 0 ) {
         $logger->error(__PACKAGE__ . ".$sub : State Machine execution timed out");
         $logger->error(__PACKAGE__ . ".$sub : Start of FORCEFUL STOP OF SCRIPTS.");
         $logger->error(__PACKAGE__ . ".$sub : $statusStateName Script has been forcibly stopped due to timing out.");

         # The statemachine is hanging more than the expected time. The following call stops execution of any
         # state machine which is running on the given node
         #

         unless ($self->stopExec(-node => $statusNode)) { }

         $logger->error(__PACKAGE__ . ".$sub : End of  FORCEFUL STOP OF SCRIPTS.");
         # END OF FORCEFUL STOP OF SCRIPTS
      }

      #logs
      if ($doNotLogMGTS eq 0) {
         if ( $self->downloadLog(-logfile => $tempLogFile,
                                 -local_dir => "$a{-logDir}") == 1 ) {
            my $grepCmd1 = "\\grep \"Warning: The following message does not match any templates\" $a{-logDir}/" . $tempLogFile;
            my $grepCmd2 = "\\grep \"Sequence Completed by Stop\" $a{-logDir}/" . $tempLogFile;
            my $grepResult1 = `$grepCmd1`;
            my $grepResult2 = `$grepCmd2`;
            if ( $grepResult1 ne "" || $grepResult2 ne "" ) {
               $logger->error(__PACKAGE__ .  ".$sub : \n#### LOG ERRORS FOUND\n##$grepResult1\n##$grepResult2\n");
            }
         } else {
            $logger->warn(__PACKAGE__ .  ".$sub : Error in downloading log file from MGTS");
         }
      }
   }

   if( $a{-waitForTrigger} == 1 ) {
      $self->downloadRemoteHookLog( -testId    => $a{-testId},
                                    -logDir    => $a{-logDir},
                                    -timeStamp => $a{-timeStamp},
                                    -variant   => $a{-variant} );
   }

   # If any of the state machine failed, return failed
   if(($result eq 0) or ($resultNext eq 0)) {
      $result = 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub : Leaving sub with return code => $result");
   return $result;
}

=head2 executeTwoStateMachinesTwoAssign

=over

=item DESCRIPTION:

    This subroutine executes a two MGTS state machines on two assignments. Here two mgts objects will be used execute the test case

=item ARGUMENTS:

    -mgtsSession         => Second mgts object
    -testId              => Test Case ID
    -nodeName            => Node name
    -stateMachine        => State Machine name  (This is unnecessary if -pasmMachineName is given.)
    -nodeNameNext        => Next node name
    -stateMachineNext    => Next state machine name  (This is unnecessary if -pasmMachineName is given.)
    -logDir              => ATS log directory
    -mgtsStatesDir       => MGTS States directory  (This is unnecessary if -pasmMachineName is given.)
    -timeStamp           => Test suite execution start timestamp , not required. Current Timestamp will be taken.
    -mgtsStatesDirNext   => MGTS States directory for the second state machine


    The following arguments are having default values. This needs to given only if
    the required values are changed
    -variant             => Test Varaint
                            The default value is "NONE"
    -stateTimeOut        => Timeout for a state machine execution. Once this timeout is
                            occurred, the state machine is stopped
                            Default value is 90 seconds
    -doNotLogMGTS        => If this flag is set to 1, the MGTS logging is not done
                            Default value is set 0
    -waitForTrigger      => Pass in a value of 1 if your state machine contains action states
                            that send trigger messages.  Default value is 0.
    -customProcessMsg    => Reference to a function which will perform custom processing
                            on the received trigger message.  If not included then the
                            standard processing will occur.
    -pasmMachineName     => The name of the state machine as expected by PASM.
                            Equivalent to $stateMachineDescri.
    -pasmMachineNext     => The name of the next state machine as expected by PASM.
                            Equivalent to $stateMachineDescriNext.

=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:getStateDesc
    SonusQA::MGTS:startExecContinue
    SonusQA::MGTS:areStatesRunning
    SonusQA::MGTS:checkResult
    SonusQA::MGTS:stopExec
    SonusQA::MGTS:downloadLog

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->executeTwoStateMachinesTwoAssign (-mgtsSession        => $second_mgts_object,
                                                            -testId             => $testId,
                                                            -nodeName           => $nodeName,
                                                            -stateMachine       => $stateMachine,
                                                            -mgtsStatesDir      => $mgtsStatesDir,
                                                            -nodeNameNext       => $nodeNameNext,
                                                            -stateMachineNext   => $stateMachineNext,
                                                            -mgtsStatesDirNext  => $mgtsStatesDirNext,
                                                            #-timeStamp          => $timestamp)) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not execute the MGTS state machine");
        return 0;
    }

=back

=cut

##################################################################################
sub executeTwoStateMachinesTwoAssign {
##################################################################################
   my ($self, %args) = @_;
   my %a = ( -doNotLogMGTS     => 0,
             -stateTimeOut     => 90,
             -waitForTrigger   => 0,
             -variant          => "NONE" );
   my $sub = "executeTwoMGTSStateMachinesTwoAssign()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my $secondMgtsObj = $a{-mgtsSession};
   
   my $stateMachineDescri = "";
   my $stateMachineDescriNext = "";

   if( ( $stateMachineDescri = $a{-pasmMachineName} ) eq "" ) {
      my $fullMgtsStateName = $a{-mgtsStatesDir} . $a{-stateMachine} . ".states";
      $stateMachineDescri = $self->getStateDesc(-full_statename => $fullMgtsStateName);
   } else {
      # Update state machine name for logs
      $a{-stateMachine} = $a{-pasmMachineName};
   }

   if( ( $stateMachineDescriNext = $a{-pasmMachineNext} ) eq "" ) {
      my $fullMgtsStateNameNext = $a{-mgtsStatesDirNext} . $a{-stateMachineNext} . ".states";
      $stateMachineDescriNext = $secondMgtsObj->getStateDesc(-full_statename => $fullMgtsStateNameNext);
   } else {
      # Update state machine name for logs
      $a{-stateMachineNext} = $a{-pasmMachineNext};
   }

   #Needs to run two state machines
   my $doNotLogMGTS = $a{-doNotLogMGTS};
   my ( $timestamp , $logFileName , $logFileNameNext );

   $logger->info(__PACKAGE__ . ".$sub : Starting state machine $a{-stateMachine} on node $a{-nodeName}");

   # Run the state machine
   if($doNotLogMGTS eq 1)
   {
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri,
                                    -reset_stats => 1) )
      {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      }
      else
      {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # Run the state machine
      if ( $secondMgtsObj->startExecContinue(-node        => $a{-nodeNameNext},
                                             -machine     => $stateMachineDescriNext,
                                             -reset_stats => 1) )
      {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachineNext} on node $a{-nodeNameNext} started");
      }
      else
      {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachineNext} on node $a{-nodeNameNext}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }
   else
   {
      $timestamp = strftime "%Y%m%d-%H%M%S", localtime;
      $logFileName = 'MGTS_' . $a{-testId} . "_$a{-variant}" . "_$timestamp" .  "_" . $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$a{-nodeName} . ".log";
   
      if ( $self->startExecContinue(-node        => $a{-nodeName},
                                    -machine     => $stateMachineDescri,
                                    -logfile     => $logFileName,
                                    -reset_stats => 1) )
      {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachine} on node $a{-nodeName} started");
      }
      else
      {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachine} on node $a{-nodeName}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
      
      $timestamp = strftime "%Y%m%d-%H%M%S", localtime;
      $logFileNameNext = 'MGTS_' . $a{-testId} . "_$a{-variant}" . "_$timestamp" .  "_" . $secondMgtsObj->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$a{-nodeNameNext} . ".log";
      # Run the state machine
      if ( $secondMgtsObj->startExecContinue(-node        => $a{-nodeNameNext},
                                                -machine     => $stateMachineDescriNext,
                                                -logfile     => $logFileNameNext,
                                                -reset_stats => 1) )
      {
         $logger->info(__PACKAGE__ . ".$sub : State machine $a{-stateMachineNext} on node $a{-nodeNameNext} started");
      }
      else
      {
         $logger->debug(__PACKAGE__ . ".$sub : Failed to execute MGTS test $a{-stateMachineNext} on node $a{-nodeNameNext}");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   # Check the status of both the nodes
   my $node_index = 0;
   my $tempLogFile;

   my $result = 0;
   my $resultNext = 0;

   while ($node_index lt 2)
   {
      # results
      my $timeout = $a{-stateTimeOut};

      my $pollingPeriod = 1;
      my $allTestsComplete = 0;
      my $startLoopTime    = [gettimeofday];
      my $loopTimer        = 0;
      my $mgtsResult;
      my $executionStatus = "FAILED";

      if( ( $timeout > 60 ) && ( $a{-waitForTrigger} == 0 ) ) { $pollingPeriod = $timeout/10; }

      $node_index = $node_index + 1;

      my $statusNode;
      my $statusStateName;
      my $statusStateDescri;
      my $mgtsObj;

      if ($node_index eq 1)
      {
         $tempLogFile = $logFileName;
         $statusNode = $a{-nodeName};
         $statusStateName = $a{-stateMachine};
         $statusStateDescri = $stateMachineDescri;
         $mgtsObj = $self;
      }
      else
      {
         $tempLogFile = $logFileNameNext;
         $statusNode = $a{-nodeNameNext};
         $statusStateName = $a{-stateMachineNext};
         $statusStateDescri = $stateMachineDescriNext;
         $mgtsObj = $secondMgtsObj;
      }

      # Loop till all the states are executed or the timeout occurs
      while ( (!$allTestsComplete) && (tv_interval($startLoopTime) < $timeout) )
      {
         if( $a{-waitForTrigger} == 1 ) {
            $self->waitForTriggerMsg( -timeout          => $pollingPeriod,
                                      -customProcessMsg => $a{-customProcessMsg} );
         } else {
            sleep( $pollingPeriod );
         }

         $allTestsComplete = 1;

         my $areStatesRunning = $mgtsObj->areStatesRunning(-node => $statusNode);

         if ( $areStatesRunning == 0 )
         {
            $logger->info(__PACKAGE__ . ".$sub : $statusStateName execution completed");

            $mgtsResult = $mgtsObj->checkResult( -node => $statusNode,
                                                 -machine => $statusStateDescri);
            if ( $mgtsResult == 1)
            {
               $executionStatus = "PASSED";
               $logger->info(__PACKAGE__ . ".$sub : $statusStateName execution passed");

               if ($node_index eq 1) {
                  $result = 1;
               } else {
                  $resultNext = 1;
               }
            }
            elsif ( $mgtsResult == 0)
            {
               $executionStatus = "FAILED";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
            }
            elsif ( $mgtsResult == -1)
            {
               $executionStatus = "ERROR";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : MGTS script did not transition through PASS/FAIL node" .
                                            " OR MGTS::checkResult returned inconclusive result");
            }
            elsif ( $mgtsResult == -2 )
            {
               $executionStatus = "ERROR";
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::checkResult");
            }
            else
            {
               $logger->error(__PACKAGE__ . ".$sub : $statusStateName execution failed");
               $logger->error(__PACKAGE__ . ".$sub : Unexpected return code from MGTS::checkResult ".
                                            "for test-$a{-testId}, mgtsStateMachine-$statusStateName.");
            }

         }
         elsif ( $areStatesRunning == -1 )
         {
            $logger->error(__PACKAGE__ . ".$sub : Failed to get result via MGTS::areStatesRunning");
         }
         elsif ( $areStatesRunning == 1 )
         {
            $allTestsComplete = 0;
         }
         else
         {
            $logger->error(__PACKAGE__ . "Unexpected return code from MGTS::areStatesRunning.");
         }
      } # while loop

      if ( $allTestsComplete == 0 )
      {
         $logger->error(__PACKAGE__ . ".$sub : State Machine execution timed out");
         $logger->error(__PACKAGE__ . ".$sub : Start of FORCEFUL STOP OF SCRIPTS.");
         $logger->error(__PACKAGE__ . ".$sub : $statusStateName Script has been forcibly stopped due to timing out.");

         # The statemachine is hanging more than the expected time. The following call stops execution of any
         # state machine which is running on the given node
         #

         unless ($mgtsObj->stopExec(-node => $statusNode))
         {
         }

         $logger->error(__PACKAGE__ . ".$sub : End of  FORCEFUL STOP OF SCRIPTS.");
         # END OF FORCEFUL STOP OF SCRIPTS
      }

      #logs
      if ($doNotLogMGTS eq 0)
      {
         if ( $mgtsObj->downloadLog(-logfile => $tempLogFile,
                                    -local_dir => "$a{-logDir}") == 1 )
         {
            my $grepCmd1 = "\\grep \"Warning: The following message does not match any templates\" $a{-logDir}/" . $tempLogFile;
            my $grepCmd2 = "\\grep \"Sequence Completed by Stop\" $a{-logDir}/" . $tempLogFile;
            my $grepResult1 = `$grepCmd1`;
            my $grepResult2 = `$grepCmd2`;
            if ( $grepResult1 ne "" || $grepResult2 ne "" )
            {
               $logger->error(__PACKAGE__ .  ".$sub : \n#### LOG ERRORS FOUND\n##$grepResult1\n##$grepResult2\n");
            }
         } else {
            $logger->warn(__PACKAGE__ .  ".$sub : Error in downloading log file from MGTS");
         }
      }
      if( $a{-waitForTrigger} == 1 ) {
         $mgtsObj->downloadRemoteHookLog( -testId    => $a{-testId},
                                          -logDir    => $a{-logDir},
                                          -variant   => $a{-variant},
                                          -timeStamp => $a{-timeStamp});
      }
   }

   # If any of the state machine failed, return failed
   if(($result eq 0) or ($resultNext eq 0)) {
      $result = 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Leaving sub with return code => $result");
   return $result;
}

=head2 validateMGTSNode

=over

=item DESCRIPTION:

    This subroutine validates a given MGTS node is present in the assignment.

=item ARGUMENTS:

    -nodeName    => The node name

=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:cmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->validateMGTSNode (-nodeName    => $nodeName)) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not execute two MGTS state machines");
        return 0;
    }

=back

=cut

##################################################################################
sub validateMGTSNode {
##################################################################################
   my ($self, %args) = @_;
   my %a;

   my $sub = "validateMGTSNode()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my $node;

   # Search for the requested node name
   foreach $node ( @{ $self->{NODELIST} } ) {

      # Check for the requested node
      if($node eq $a{-nodeName})
      {
         # Got the requested node
         $logger->info(__PACKAGE__ . ".$sub : Requested node $a{-nodeName} found");
         $logger->debug(__PACKAGE__ . ".$sub : Success - The requested node is valid");
         return 1;
      }
   }

   # requested node is NOT found
   $logger->error(__PACKAGE__ . ".$sub : Requested node $a{-nodeName} NOT found");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   return 0;
}

=head2 validateMGTSStateMachine

=over

=item DESCRIPTION:

    This subroutine validates a given MGTS state machine is present in the assignment

=item ARGUMENTS:

    -nodeName => MGTS node name
    -stateMachine => MGTS state machine

=item PACKAGE:

    SonusQA::MGTS:MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:cmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->validateMGTSStateMachine (-nodeName => $nodeName,
                                                    -stateMachine => $stateMachine )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not validate the given state machine name");
        return 0;
    }

=back

=cut

##################################################################################
sub validateMGTSStateMachine {
##################################################################################
   my ($self, %args) = @_;
   my %a;
   my $sub = "validateMGTSStateMachine()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Get the number of states to loop
   my $number_of_states = 0;
   unless( $number_of_states = $self->getSeqList(-node => $a{-nodeName}) ) {
      $logger->error(__PACKAGE__ . ".$sub  : Could not get the sequence list for node $a{-nodeName}.");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   my $state_index = 0;
   while ($state_index < $number_of_states) {
      $state_index = $state_index + 1;

      my $stateName = $self->{SEQLIST}->{$a{-nodeName}}->{SEQUENCE}{$state_index};
      my $tempStateName =$a{-stateMachine};
      if( $stateName =~ m/$tempStateName/) {
         $logger->info(__PACKAGE__ . ".$sub : Got the state machine $a{-stateMachine}");
         $logger->debug(__PACKAGE__ . ".$sub : Success - The requested state machine is valid");
         return 1;
      }
      else {
         next;
      }
   }

   $logger->error(__PACKAGE__ . ".$sub : The requested state machine $a{-stateMachine} NOT present");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   return 0;
}

=head2 configureMgts

=over

=item DESCRIPTION:

    This subroutine does the configuration for MGTS

=item ARGUMENTS:

    -mgtsAccount        => MGTS account from where the assignment is downloaded
    -mgtsAssginment     => MGTS assignment to be downloaded
    -setupTriggerSock   => optional parameter to specify if mgts trigger socket is to be created 1 = yes 0 = no (default = 0)
    -timeout            => Optional argument. Used to increase the timeout for downloading bigger assignments
                           Default is set to 30secs
    -downloadOption     => Optional argument. Used to provide download option for the commands 'networkExecuteM5k' or 'networkExecute'
                           Default is set to '-download'. Example -downloadOption => '-noBuild'
    -alignwait          => <align timeout value>
                           Wait a specified time (seconds) for alignment to occur.
                           Valid values:   positive integer > 0
                           Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
                           Arg example:    -alignwait => 18
    -reset_shelf        => <0 or 1>
                           Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
 	                   Valid Values:   0 (don't reset) or 1 (reset)
	                   Default Value:  1 (reset)
 	                   Arg example:    -reset_shelf => 0

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->configureMgts(-mgtsAccount      => $mgts_assignment_account,
                                        -mgtsAssginment   => $mgts_assignment,
					-alignwait        => 30,
					-reset_shelf      => 0,	
                                        -setupTriggerSock => 1)) {

        $logger->debug(__PACKAGE__ . ".$sub : Error in configuring MGTS");
        return 0;
    }

=back

=cut

sub configureMgts {
   my ($self, %args) = @_;
   my $sub = "configureMgts()";
   my %a = ( -setupTriggerSock      => 0,
             -timeout               => 30,
	     -reset_shelf	    => 1,
             -downloadOption        => '-download');

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");


   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my $mgts_name   = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   $logger->debug(__PACKAGE__ . ".$sub Configuring MGTS $mgts_name");

   my $mgtsAssignmentAccount = $a{-mgtsAccount};
   my $mgts_assignment         = $a{-mgtsAssignment};

   my $shelf_version = $self->{SHELF_VERSION};
   my $extension= ($shelf_version eq 'p400' or $shelf_version eq 'm500') ? '.AssignM5k' : '.assign';

   # check align wait is a positive integer
   if (defined($a{-alignwait}) && $a{-alignwait} <= 0) {
       $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
       return 0;
   }

   unless( $a{-alignwait}) {
      if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
         $a{-alignwait} = 15;
      } else {
         $a{-alignwait} = 10;
      }
   }

   # check force disconnect arg is 0 or 1
   if (($a{-reset_shelf} < 0) || ($a{-reset_shelf} > 1)) {
      $logger->error(__PACKAGE__ . ".$sub Argument \"-reset_shelf\" must be 0 or 1");
      return 0;
   }

   #Configure Trigger Socket if required
   if( $a{-setupTriggerSock})
	 {
	   if( defined $self->{FISH_HOOK_PORT} )
		 {
		   unless($self->setupTriggerSocket() ) 
			 {
			   $logger->info(__PACKAGE__ . ".$sub : Could not configure socket to receive the trigger message from MGTS");
			   return 0;
			 }	  
		 } 
	   else
		 {
		   # If the suite requested this functionality, and the data has not been set in the TMS object, we can't continue, we should die here else the suite will fail with an obscure error message *way* down the line. (malc)
		   $logger->error(__PACKAGE__ . ".$sub Trigger Socket not configured as no Port was defined. Since the suite indicates it requires it, unable to continue.");
		   $logger->error(__PACKAGE__ . ".$sub Please populate the data in TMS, or if not really required by the suite, omit the -setupTriggerSock parameter when calling this function.");
		   die "Looks like you failed to update the FISH_HOOK port in the TMS object for the MGTS in question, this suite says it requires it, unable to continue.";
		 } 
	 }

   # Upload MGTS Assignment from Repository
   unless( $self->uploadFromRepository( -account        => "$mgtsAssignmentAccount",
                                        -path           => "/home/$mgtsAssignmentAccount/datafiles",
                                        -file_to_copy   => "${mgts_assignment}$extension",)) {
      $logger->debug(__PACKAGE__ . ".$sub Could not upload $mgts_assignment from account $mgtsAssignmentAccount."); 
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Uploaded MGTS Assignment from Repository");

   unless( $self->getNetworkMapName(-assignment => $mgts_assignment) ) {
      $logger->debug(__PACKAGE__ . ".$sub Could not get network map name from map $mgts_assignment"); 
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub NETMAP: $self->{NETMAP} PROT: $self->{PROTOCOL} SHELF: $self->{SHELF_VERSION}");

   my $user_directory = "/home/".$self->{OBJ_USER};

   $logger->debug(__PACKAGE__ . ".$sub rest_shelf --> $a{-reset_shelf}");
   $logger->debug(__PACKAGE__ . ".$sub downloadoption --> $a{-downloadOption}");
   $logger->debug(__PACKAGE__ . ".$sub timeout --> $a{-timeout}");
   $logger->debug(__PACKAGE__ . ".$sub alignwait --> $a{-alignwait}");

   unless( $self->downloadAssignment(-assignment     => $mgts_assignment,
                                     -timeout        => $a{-timeout},
			             -alignwait	     => $a{-alignwait},	
				     -reset_shelf    => $a{-reset_shelf},	
                                     -downloadOption => $a{-downloadOption},) ) {
		
      $logger->debug(__PACKAGE__ . ".$sub Could not download assignment $mgts_assignment."); 
      return 0;   
   }

   unless( $self->getNodeList() ) {
      $logger->debug(__PACKAGE__ . ".$sub Could not get node list."); 
      return 0;
   }

   my $node;

   foreach $node ( @{ $self->{NODELIST} } ) {
      my $number_of_states;
      $logger->debug(__PACKAGE__ . ".$sub MGTS node: $node found.");
      unless( $number_of_states = $self->getSeqList(-node => $node) ) {
         $logger->debug(__PACKAGE__ . ".$sub Could not get the sequence list for node $node."); 
         return 0;
      }

      # On each node run the first test ($self->{SEQLIST}->{<STP>}->{SEQUENCE}{1})
      my $stateName = $self->{SEQLIST}->{$node}->{SEQUENCE}{1};

      unless ( $stateName ) {
         $logger->error(__PACKAGE__ . ".$sub Could not get 1st state machine name for node $node.");
         return 0;
      }
   } # End foreach (node)

   $logger->debug(__PACKAGE__ . ".$sub Successfully configured MGTS ". "$mgts_name" );
   return 1;
}

=head2 configureMgtsFromTar

=over

=item DESCRIPTION:

    This subroutine does the configuration for MGTS

=item ARGUMENTS:

=item Mandatory:

    -mgtsAssignment     => MGTS assignment to be downloaded
    -tarFileName        => Tar file to be downloaded
                           E.g., "abcd.tar"
    -localDir           => Directory where the file to be transferred is placed
                           E.g., "/home/user/ats_repos/lib/perl/QATEST/SGX4000/APPLICATION/SEGMENTATION/ITU"

=item Optional:

    -putTarFile           => Do the FTP. Sometimes during the testing there is no need
                             to FTP the tar files. Downloading the tar files even removes
                             the updates if the latest tar file is not FTPed. Setting
                             this flag to '0', the file is not FTPed but the assignment
                             is downloaded onto the shelf
                             The default value is '1'
    -downloadToDatafiles  => Flag to download tar file to the data files directory.
                             The default value is '0'
    -timeout              => Used to increase the timeout for downloading bigger assignments
                             Default is set to 30secs
    -downloadOption       => Used to provide download option for the commands 'networkExecuteM5k' or 'networkExecute'
                             Default is set to '-download'. Example -downloadOption => '-noBuild'
    -alignwait            => <align timeout value>
        		     Wait a specified time (seconds) for alignment to occur.
		             Valid values:   positive integer > 0
		             Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
		             Arg example:    -alignwait => 18
    -reset_shelf          => <0 or 1>
                             Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
                             Valid Values:   0 (don't reset) or 1 (reset)
                             Default Value:  1 (reset)
                             Arg example:    -reset_shelf => 0

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->configureMgtsFromTar(-tarFileName    => $tarFileName,
                                               -localDir       => $localDir,
                                               -mgtsAssignment => $mgts_assignment,
					       -reset_shelf    => 0,	
					       -downloadOption => '-download',	
					       -alignwait      => 30)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in configuring MGTS");
        return 0;
    }

=back

=cut

sub configureMgtsFromTar {
   my ($self, %args) = @_;
   my $sub = "configureMgtsFromTar()";
   my %a = (-putTarFile          => 1,
            -downloadToDatafiles => 0,
            -timeout             => 30,
   	    -reset_shelf         => 1,		
            -downloadOption      => '-download');

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my $mgts_name   = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   $logger->debug(__PACKAGE__ . ".$sub Configuring MGTS $mgts_name");


   # check align wait is a positive integer
   if (defined($a{-alignwait}) && $a{-alignwait} <= 0) {
       $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
       return 0;
   }

   unless( $a{-alignwait}) {
      if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
         $a{-alignwait} = 15;
      } else {
         $a{-alignwait} = 10;
      }
   }

   # check force disconnect arg is 0 or 1
   if (($a{-reset_shelf} < 0) || ($a{-reset_shelf} > 1)) {
      $logger->error(__PACKAGE__ . ".$sub Argument \"-reset_shelf\" must be 0 or 1");
      return 0;
   }
   
   my $mgts_assignment         = $a{-mgtsAssignment};

   #Transfer the tar file to MGTS
   if($a{-putTarFile} eq 1) {
      unless( $self->putTarFile(%a) ) {
         $logger->error(__PACKAGE__ . ".$sub Could not FTP the tar file");
         return 0;
      }
   }

   # Get the shelf type
   my $shelf_version = $self->{SHELF_VERSION};
   my $extension= ($shelf_version eq 'p400' or $shelf_version eq 'm500') ? '.AssignM5k' : '.assign';

   # FTP the tar file to MGTS

   unless( $self->getNetworkMapName(-assignment => $mgts_assignment) ) {
      $logger->debug(__PACKAGE__ . ".$sub Could not get network map name from map $mgts_assignment");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub NETMAP: $self->{NETMAP} PROT: $self->{PROTOCOL} SHELF: $self->{SHELF_VERSION}");

   my $user_directory = "/home/".$self->{OBJ_USER};

   $logger->debug(__PACKAGE__ . ".$sub rest_shelf --> $a{-reset_shelf}");
   $logger->debug(__PACKAGE__ . ".$sub downloadoption --> $a{-downloadOption}");
   $logger->debug(__PACKAGE__ . ".$sub timeout --> $a{-timeout}");
   $logger->debug(__PACKAGE__ . ".$sub alignwait --> $a{-alignwait}");

   unless( $self->downloadAssignment(-assignment     => $mgts_assignment,
                                     -timeout        => $a{-timeout},
				     -reset_shelf    => $a{-reset_shelf},	
                                     -downloadOption => $a{-downloadOption},
   				     -alignwait	     => $a{-alignwait},) ) {

      $logger->debug(__PACKAGE__ . ".$sub Could not download assignment $mgts_assignment.");
      return 0;
   }

   unless( $self->getNodeList() ) {
      $logger->debug(__PACKAGE__ . ".$sub Could not get node list.");
      return 0;
   }

   my $node;

   foreach $node ( @{ $self->{NODELIST} } ) {
      my $number_of_states;
      $logger->debug(__PACKAGE__ . ".$sub MGTS node: $node found.");
      unless( $number_of_states = $self->getSeqList(-node => $node) ) {
         $logger->debug(__PACKAGE__ . ".$sub Could not get the sequence list for node $node.");
         return 0;
      }

      # On each node run the first test ($self->{SEQLIST}->{<STP>}->{SEQUENCE}{1})
      my $stateName = $self->{SEQLIST}->{$node}->{SEQUENCE}{1};

      unless ( $stateName ) {
         $logger->error(__PACKAGE__ . ".$sub Could not get 1st state machine name for node $node.");
         return 0;
      }
   } # End foreach (node)

   $logger->debug(__PACKAGE__ . ".$sub Successfully configured MGTS ". "$mgts_name" );
   return 1;
}

=head2 putTarFile

=over

=item DESCRIPTION:

    This subroutine transfers .tar file to the MGTS and untar the file

=item ARGUMENTS:

=item Mandatory :

    -mgtsAssignment     => MGTS assignment to be downloaded
    -tarFileName        => Tar file to be downloaded
                           E.g., "abcd.tar"
    -localDir           => Directory where the file to be transferred is placed
                           E.g., "/home/user/ats_repos/lib/perl/QATEST/SGX4000/APPLICATION/SEGMENTATION/ITU"

=item Optional :

    -downloadToDatafiles  => Flag to download tar file to the data files directory.
                             The default value is '0'

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->putTarFile(-tarFileName    => $tarFileName,
                                     -localDir       => $localDir,
                                     -mgtsAssignment => $mgts_assignment)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in configuring MGTS");
        return 0;
    }

=back

=cut

sub putTarFile {
   my ($self, %args) = @_;
   my $sub = "putTarFile()";
   my %a = ( -downloadToDatafiles => 0);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   my $local_dir               = $a{-localDir};
   my $mgts_assignment         = $a{-mgtsAssignment};
   my $localFile               = $local_dir . "/" . $a{-tarFileName};

   my %scpArgs;
   $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
   $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
   $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
   $scpArgs{-sourceFilePath} = $localFile;

   $logger->debug(__PACKAGE__ . ".$sub : Transfering \'$localFile\' to MGTS \'$scpArgs{-hostip}\'");
   my $cmdString;

   if ($self->cmd( -cmd => "echo \$HOME")) {#TOOLS-17756
      $logger->error(__PACKAGE__ . ".$sub Failed to get \$HOME : $self->{OUTPUT}");
      $logger->debug(__PACKAGE__ . ".$sub :  <-- Leaving sub. [0]");
      return 0;
   }
   chomp($self->{OUTPUT});
   # Send the file
   if($a{-downloadToDatafiles} eq 0) {
      # keep the file in the home directory
	$scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:".$self->{OUTPUT};
      $cmdString = "cd  ";
   } else {
      # keep the file in the datafiles directory 
	$scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:".$self->{OUTPUT}."/datafiles";
      $cmdString = "cd ~/datafiles";
   }
   if (&SonusQA::Base::secureCopy(%scpArgs)){
      $logger->debug(__PACKAGE__ . ".$sub :  file $localFile transfered to \($scpArgs{-hostip}\) MGTS");
   }
   # go to MGTS_DATA directory
   if ( $self->cmd( -cmd => $cmdString) ) {
      $logger->error(__PACKAGE__ . ".$sub Failed to cd into \$HOME or \$HOME/datafiles directory: $self->{OUTPUT}");
      return 0;
   } else {
      $logger->debug(__PACKAGE__ . ".$sub Successfully cd'd into \$HOME or \$HOME/datafiles directory");
   }

   my $tar_extraction_output;

   # Extract the tar file
   if ( $self->cmd( -cmd => "tar -xvf $a{-tarFileName}" ) ) {
      $logger->error(__PACKAGE__ . ".$sub Failed to untar $a{-tarFileName}: $self->{OUTPUT}");
      return 0;
   } else {
      $tar_extraction_output = $self->{OUTPUT};
      $logger->info(__PACKAGE__ . ".$sub Successfully copied '$a{-tarFileName}' file and its dependencies");
      $self->cmd( -cmd => "ls -l $a{-mgtsAssignment}\*");
   }

   # Remove the tar file
   if ( $self->cmd( -cmd => "rm -f $a{-tarFileName}" ) ) {
      $logger->warn(__PACKAGE__ . ".$sub Failed to delete $a{-tarFileName}: $self->{OUTPUT}");
   } else {
      $logger->debug(__PACKAGE__ . ".$sub Successfully removed '$a{-tarFileName}' file");
   }

    # Ensure we are set to the HOME directory of the MGTS user
   if ( $self->cmd( -cmd => "cd " ) ) {
     $logger->error(__PACKAGE__ . ".$sub Failed to cd to HOME directory: $self->{OUTPUT}");
     return 0;
   } else {
      $logger->debug(__PACKAGE__ . ".$sub Successfully cd'd to HOME directory");
   }

   # Setting $self->{OUTPUT} to contents of extracted tar
   $self->{OUTPUT} = $tar_extraction_output;

   $logger->debug(__PACKAGE__ . ".$sub :  <-- Leaving sub. [1]");

   return 1;
}

=head2 execMgtsStateMachines()

Execute the given list of MGTS state machines in the respective Node in order with trigger node in the last of execution list.
return SUCCESS(1) if all the MGTS state machines are executed successful else return FAILURE(0)

=over

=item Arguments:

     -testId
        TMS testcase ID

     -mgtsStateDir
        MGTS state directory

     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node

        Optional keys:
            timeout      - Timeout for executing MGTS state machhine
                           default is 60 seconds
            mgtsExecLog  - MGTS execution log disable/enable i.e. 0/1
                           default 0 (no log file created)
            reset_stats  - Reset stats i.e. 0/1 - default 1 (reset)
            decode       - Decode level i.e. 0 to 4
                           default 4 (full decodes)

     -execOrder
        execution order of MGTS state machines on respective nodes.
        Trigger node is defined in the last.

=item Returns:

    * 1, if all MGTS state machines executed successfuly.
    * 0, otherwise

=item Examples:

    my @mgtsStateMachineList = (
    # Mandatory hash keys are - node, statemachine
    # Optional hash keys are:
    #     timeout     - default to 60 seconds
    #     mgtsExecLog - 0 / 1  - default 0 (no log file created)
    #     reset_stats - 0 / 1  - default 1 (reset)     
    #     decode      - 0 to 4 - default 4 (full decodes)
        {'node' => 'HLR',   'statemachine' => 'svt_SCTP_M3UA_LINK_HLR',  'timeout' => 90, 'mgtsExecLog' => 1, 'reset_stats' => 1, 'decode' => 4},
        {'node' => 'RNC1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1', 'timeout' => 90, 'mgtsExecLog' => 1,},
        {'node' => 'RNC2',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC2', 'timeout' => 90, 'mgtsExecLog' => 1,},
        {'node' => 'RNC3',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC3', 'timeout' => 90, 'mgtsExecLog' => 1,},
        {'node' => 'SMSC',  'statemachine' => 'svt_SCTP_M3UA_LINK_SMSC', 'timeout' => 90, 'mgtsExecLog' => 1,},
        {'node' => 'PSTN1', 'statemachine' => 'svt_SCTP_M3UA_LINK_PSTN', 'timeout' => 90, 'mgtsExecLog' => 1,},
    );

    # Execution of MGTS state machine(s)
    # Trigger node is defined in the last i.e. PSTN in the given example
    my @execOrder     = qw(HLR RNC1 RNC2 RNC3 SMSC PSTN);
    my $MgtsObj       = $TESTBED{ "mgts:1:obj" };
    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA';

    unless ( $MgtsObj->execMgtsStateMachines ( 	
                      -testId       => $TestId,
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder,
                  ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to execute MGTS state machines - (@execOrder)";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  PASSED - execution of MGTS state machines - (@execOrder)");

=back

=cut

#################################################
sub execMgtsStateMachines {
#################################################
    my  ( $self, %args ) = @_ ;

    my  $subName = $args{'-testId'} ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub execMgtsStateMachines()");

    my $result = 0;

    # Check Mandatory Parameters
    foreach ( qw / testId mgtsStateDir stateMc execOrder / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

    my @execOrder            = @{$args{'-execOrder'}};
    my @mgtsStateMachineList = @{$args{'-stateMc'}};
    my $mgtsStateDir         = $args{'-mgtsStateDir'};
    
    # START executing the MGTS state machines in the execution order
    foreach my $node (@execOrder) {
        foreach (@mgtsStateMachineList) {
            if ( $_->{node} eq $node) {
                # Get the MGTS state machine(s) description
                my $fullStateMachineName = "$mgtsStateDir" . "$_->{statemachine}" . ".states";
                $_->{description} = $self->getStateDesc(-full_statename => $fullStateMachineName);

                # Set the state machine status to '-1' i.e. otherwise
                # Shall be updated by areStatesRunning()
                $_->{status} = -1;

                # Start executing the MGTS state machine(s) in the order of execution
                my $resetStats = 1; # default (reset)
                if ( defined $_->{reset_stats}) {
                    $resetStats = $_->{reset_stats};
                }
                my $decode = 4; # default (full decodes)
                if ( defined $_->{decode}) {
                    $decode = $_->{decode};
                }
                my $timeout = 60; # default
                if ( defined $_->{timeout}) {
                    $timeout = $_->{timeout};
                }

                if ( ( defined $_->{mgtsExecLog} ) &&
                     ( $_->{mgtsExecLog} == 1) ) {
                    $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node with log file.\n");
                    my $logFileName = "MGTS_" . "$subName" . "$timestamp" . "_" . "$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}" . "_" . $node . "_" . "$_{statemachine}" . ".log";
                    $logger->debug(__PACKAGE__ . ".$subName: log file name \'$logFileName\'\n");
                    unless ( $self->startExecContinue(
                                                      '-node'        => $_->{node},
                                                      '-machine'     => $_->{description},
                                                      '-timeout'     => $timeout,
                                                      '-logfile'     => $logFileName,
                                                      '-reset_stats' => $resetStats,
                                                      '-decode'      => $decode,
                                                    ) ) {
                        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node." );
                        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                else {
                    $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node without log file.\n");
                    unless ( $self->startExecContinue(
                                                      '-node'        => $_->{node},
                                                      '-machine'     => $_->{description},
                                                      '-timeout'     => $timeout,
                                                      '-reset_stats' => $resetStats,
                                                      '-decode'      => $decode,
                                                    ) ) {
                        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node." );
                        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
            }
        }
    } # END executing the MGTS state machines in the execution order

    # calculate polling interval
    my $maxTimeout = 60; # default 60 seconds
    foreach (@mgtsStateMachineList) {
        if ( ( defined($_->{timeout}) ) &&
             ( $maxTimeout < $_->{timeout}) ) {
             $maxTimeout = $_->{timeout};
        }
    }

    my $pollingInterval = $maxTimeout/10;

    # Check if all state machines have completed execution till timeout occurs
    my $allStatemachinesExecuted = 0;
    my $startLoopTime            = [Time::HiRes::gettimeofday];
    while ( (!$allStatemachinesExecuted) &&
            (tv_interval($startLoopTime) < $maxTimeout) ) {

        sleep($pollingInterval);

        my $statuscompleteCount = 0;
        foreach (@mgtsStateMachineList) {
            $_->{status} = $self->areStatesRunning('-node' => $_->{node});
            if( $_->{status} == 0) { # no state machine(s) running
                $statuscompleteCount++;
            }
        }

        if ( ($#execOrder + 1) == $statuscompleteCount) {
            $allStatemachinesExecuted = 1;
        }
    }

    # Stop the failed nodes if any
    unless ( $allStatemachinesExecuted ) {
        foreach (@mgtsStateMachineList) {
            if( ( $_->{status} == -1 ) || # otherwise
                ( $_->{status} == 1 ) ) { # if state machine(s) are still running on the node
                $self->stopExec('-node' => $_->{node});
            }
        }
    }

    # Check the results of statemachine(s)
    my $passedCount = 0;
    foreach (@mgtsStateMachineList) {
        $_->{result} = $self->checkResult(
                                   '-node'    => $_->{node},
                                   '-machine' => $_->{statemachine},
                               );

        $logger->info(__PACKAGE__ . ".$subName: Result \'$_->{result}\' for node \'$_->{node}\' state machine \'$_->{statemachine}\' and status \'$_->{status}\'");

        if ( $_->{result} == 1 ) { # state machine passed
            $logger->info(__PACKAGE__ . ".$subName: Execution PASSED");
            $passedCount++;
        }
        elsif ( $_->{result} == 0 ) { # state machine failed
            $logger->info(__PACKAGE__ . ".$subName: Execution FAILED");
        }
        elsif ( $_->{result} == -1 ) { # state machine was not executed or result was inconclusive
            $logger->info(__PACKAGE__ . ".$subName: MGTS script did not transition through PASS/FAIL node OR MGTS::checkResult returned inconclusive result");
        }
        elsif ( $_->{result} == -2 ) { # error occurred in result processing
            $logger->info(__PACKAGE__ . ".$subName: Failed to get result via MGTS::checkResult");
        }
        else {
            $logger->info(__PACKAGE__ . ".$subName: Unexpected return code from MGTS::checkResult");
        }
    }

    if ( ($#execOrder + 1) == $passedCount) {
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub execMgtsStateMachines [$result]");
    return $result;
}

=head2 updateBhca

=over

=item DESCRIPTION:

    This subroutine update the BHCA of the given sequnce group.

=item ARGUMENTS:

=item Mandatory :

    -bhca          => The New BHCA to be updated
    -remoteDir     => Remote directory where the sequence group is present
    -seqGroup      => Sequence group file name
    -stateMachine  => State machine name
                      Note : Here the state machine file name is to be passed. Not like in execute MGTS state machine
                             sub, where the description of the state machine name is used
    -localDir      => Local dir where the file is copied and edited
                      If a specified local directory is not used, sometimes the file will copied into SonusQA directory

=item Optional :

    None

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   $mgts_object->updateBhca( -bhca                => 1111,
                             -seqGroup            => "M3UA-LOAD-REDUNDANCY-STP1.sequenceGroup",
                             -stateMachine        => "txIAM-STP1",
                             -remoteDir           => "/home/smalihalli/datafiles/States",
                             -localDir            => "/home/ssukumaran/ats_repos/lib/perl/QATEST/MGTSLOAD"
                           );

=back

=cut

sub updateBhca {
   my ($self, %args) = @_;
   my $sub = "updateBhca()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   unless ( defined $a{-bhca} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory BHCA is empty or blank.");
       return 0;
   }
   unless ( defined $a{-seqGroup} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory sequence group is empty or blank.");
       return 0;
   }
   unless ( defined $a{-remoteDir} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory remote directory is empty or blank.");
       return 0;
   }
   unless ( defined $a{-stateMachine} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory State Machine Name is empty or blank.");
       return 0;
   }
   unless ( defined $a{-localDir} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory Local Directory is empty or blank.");
       return 0;
   }

   my $cmdString;

   my $remoteFile = $a{-remoteDir} . "/" . $a{-seqGroup};

   # Remove double slashes if present
   $remoteFile =~ s|//|/|;

   my $localFile = $a{-localDir} . "/" . $a{-seqGroup};

   # Remove double slashes if present
   $localFile =~ s|//|/|;

   my %scpArgs;
   $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
   $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
   $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
   $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$remoteFile;
   $scpArgs{-destinationFilePath} = $localFile;

   $logger->debug(__PACKAGE__ . ".$sub : Transferring \'$remoteFile\' From MGTS ($scpArgs{-hostip}) to \'$localFile\'");

   # Get the file to the local dir provided
   if (&SonusQA::Base::secureCopy(%scpArgs)){
   $logger->debug(__PACKAGE__ . ".$sub : Transferred \'$remoteFile\' From MGTS ($scpArgs{-hostip}) to \'$localFile\'");
   }

   # Rename the file for a backup
   rename "$localFile", "$localFile~";

   # Open the files
   open IN, "<$localFile~";
   open OUT, ">$localFile";

   # Edit the file
   while (<IN>) {
      my $line = $_;
      if($line =~ m/$a{-stateMachine}/) {
         if($line =~ m/STATE=(.*)\/(\S+) (.*)/) {
            if($a{-stateMachine} eq $2) {
               if($line =~ m/(.*)BHCA=(\d+)/) {
                  $logger->debug(__PACKAGE__ . ".$sub : The current BHCA : $2 changing to $a{-bhca}");
                  $line = $1 . "BHCA=" . $a{-bhca} . "\n";
               }
            }
         }
      }
      print OUT $line;
   }

   close IN;
   close OUT;

   $logger->debug(__PACKAGE__ . ".$sub : Transferring \'$localFile\' to MGTS ($scpArgs{-hostip}) as \'$remoteFile\' ");

   # Put the file back into MGTS
   $scpArgs{-sourceFilePath} = $localFile;
   $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$remoteFile;

   if (&SonusQA::Base::secureCopy(%scpArgs)){
      $logger->debug(__PACKAGE__ . ".$sub : Transferred \'$localFile\' to MGTS ($scpArgs{-hostip}) as \'$remoteFile\' ");
   }
   return 1;
}

=head2 updateBhcaForLoad

=over

=item DESCRIPTION:

    This subroutine update the BHCA of the given sequence group for load testing.

=item ARGUMENTS:

=item Mandatory:

    -bhcaInfo           => The reference hash for the new BHCA to be updated
                           seqGroup        => Sequence group file name
                           stateMachines   => Array reference to state machine names
                                              Note : Here the state machine file name is to be passed. 
                                              Not like in execute MGTS state machine
                                              sub, where the description of the state machine name is used
                           callRate        => Call rate like 5, 10, 15
                                              The call rate is calculated for 5 as 5 * 1000 * 60 * 60
                                              This value will be divided by the number of state machines
                                              and then updates the new value for BHCA for a state machine

    -localDir           => Local dir where the file is copied and edited
                           If a specified local directory is not used, sometimes the file will copied into SonusQA directory
    -remoteDir          => Remote directory where the sequence group is present
    -mgtsAssignment     => MGTS assignment to be downloaded

=item Optional :

    -timeout            => Used to increase the timeout for downloading bigger assignments
                           Default is set to 30secs
    -downloadOption     => Used to provide download option for the commands 'networkExecuteM5k' or 'networkExecute'
                           Default is set to '-download'. Example -downloadOption => '-noBuild'
    -cps                => This flag can be used to determine the required BHCA i.e whether user wants BHCA or KBHCA.
                           Default is set to zero. i.e. -cps => '0'

                           If this flag is set to '1', the formula to calculate the BHCA will become '$callRate * 60 * 60'
                           If this flag is set to '0', the formula to calculate the BHCA will become '$callRate * 1000 * 60 * 60'
    -alignwait          => <align timeout value>
                           Wait a specified time (seconds) for alignment to occur.
                           Valid values:   positive integer > 0
                           Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
                           Arg example:    -alignwait => 18

    -reset_shelf        => <0 or 1>
  		           Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
		           Valid Values:   0 (don't reset) or 1 (reset)
   		           Default Value:  1 (reset)
                           Arg example:    -reset_shelf => 0

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   my $mgts_object = $TESTBED{ "mgts:1:obj" };

   my @isupStates = ("txIAM-STP1", "txIAM-STP1-1", "txIAM-STP1-2");
   my @isup1States = ("txIAM-STP1", "txIAM-STP1-3", "txIAM-STP1-4");
   my @sccpStates = ("txIAM-STP1", "txIAM-STP1-5", "txIAM-STP1-6");

   my %bhcaInfo;

   $bhcaInfo{ISUP}->{stateMachines} = \@isupStates; # No of states is derived from this
   $bhcaInfo{ISUP}->{callRate} = 10;                # 5K = 5 * 1000 * 60 * 60
   $bhcaInfo{ISUP}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1.sequenceGroup";
   $bhcaInfo{ISUP1}->{stateMachines} = \@isup1States; # No of states is derived from this
   $bhcaInfo{ISUP1}->{callRate} = 10;                # 5K = 5 * 1000 * 60 * 60
   $bhcaInfo{ISUP1}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1-one.sequenceGroup";
   $bhcaInfo{SCCP}->{stateMachines} = \@sccpStates;
   $bhcaInfo{SCCP}->{callRate} = 5;
   $bhcaInfo{SCCP}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1-temp.sequenceGroup";

   $mgts_object->updateBhcaForLoad( -bhcaInfo            => \%bhcaInfo,
                                    -remoteDir           => "/home/ssukumaran/SusTest",
				    -alignwait           => 30,
                                    -localDir            => "/home/ssukumaran/ats_repos/lib/perl/QATEST/MGTSLOAD",
                                    -mgtsAssignment      => "Abcd"
                                  );

=item EXAMPLE:

  my $mgts_object = $TESTBED{ "mgts:1:obj" };

   my @isupStates = ("txIAM-STP1", "txIAM-STP1-1", "txIAM-STP1-2");
   my @isup1States = ("txIAM-STP1", "txIAM-STP1-3", "txIAM-STP1-4");
   my @sccpStates = ("txIAM-STP1", "txIAM-STP1-5", "txIAM-STP1-6");

   my %bhcaInfo;

   $bhcaInfo{ISUP}->{stateMachines} = \@isupStates; # No of states is derived from this
   $bhcaInfo{ISUP}->{callRate} = 180;            # 180 * 60 * 60    
   $bhcaInfo{ISUP}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1.sequenceGroup";
   $bhcaInfo{ISUP1}->{stateMachines} = \@isup1States; # No of states is derived from this
   $bhcaInfo{ISUP1}->{callRate} = 100;           # 100 * 60 * 60    
   $bhcaInfo{ISUP1}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1-one.sequenceGroup";
   $bhcaInfo{SCCP}->{stateMachines} = \@sccpStates;
   $bhcaInfo{SCCP}->{callRate} = 50;            # 50 * 60 * 60
   $bhcaInfo{SCCP}->{seqGrp} = "M3UA-LOAD-REDUNDANCY-STP1-temp.sequenceGroup";

   $mgts_object->updateBhcaForLoad( -bhcaInfo            => \%bhcaInfo,
                                    -remoteDir           => "/home/ssukumaran/SusTest",
                                    -localDir            => "/home/ssukumaran/ats_repos/lib/perl/QATEST/MGTSLOAD",
				    -reset_shelf	 => 0,
                                    -mgtsAssignment      => "Abcd",
                                    -cps                 => '1',
                                  );

=back

=cut

sub updateBhcaForLoad {
   my ($self, %args) = @_;
   my $sub = "updateBhcaForLoad()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %a = (-timeout             => 30,
            -downloadOption      => '-download',
	    -reset_shelf         => 1,
            -cps                 => '0',);

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   # check align wait is a positive integer
   if (defined($a{-alignwait}) && $a{-alignwait} <= 0) {
       $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
       return 0;
   }

   unless( $a{-alignwait}) {
      if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
         $a{-alignwait} = 15;
      } else {
         $a{-alignwait} = 10;
      }
   }

   # check force disconnect arg is 0 or 1
   if (($a{-reset_shelf} < 0) || ($a{-reset_shelf} > 1)) {
       $logger->error(__PACKAGE__ . ".$sub Argument \"-reset_shelf\" must be 0 or 1");
       return 0;
   }

   unless ( defined $a{-remoteDir} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory remote directory is empty or blank.");
       return 0;
   }
   unless ( defined $a{-localDir} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory Local Directory is empty or blank.");
       return 0;
   }

   unless ( defined $a{-bhcaInfo} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory BHCA info parameter is empty or blank.");
       return 0;
   }
   unless ( defined $a{-mgtsAssignment} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory MGTS assignment is empty or blank.");
       return 0;
   }

   my %scpArgs;
   $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
   $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
   $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
 
   my %bhcaInfo = %{$a{-bhcaInfo}};
   
   my $loadType;
 
   foreach $loadType (keys %bhcaInfo) {
      my $cmdString;

      my $seqGroup = $bhcaInfo{$loadType}->{seqGrp};
      my @stateMachines = @{$bhcaInfo{$loadType}->{stateMachines}};
      my $noOfStatesMachines = scalar @stateMachines;

      if ($noOfStatesMachines eq 0) {
         $logger->error(__PACKAGE__ . ".$sub : There are no statechines in the list");
         return 0;
      }

      my $callRate = $bhcaInfo{$loadType}->{callRate};
      my $bhca;
      unless ($a{-cps}) {
          $bhca = ($callRate * 1000 * 60 * 60) / $noOfStatesMachines;
      } else {
          $bhca = ($callRate * 60 * 60) / $noOfStatesMachines;
      }

      my $remoteFile = $a{-remoteDir} . "/" . $seqGroup;

      # Remove double slashes if present
      $remoteFile =~ s|//|/|;

      my $localFile = $a{-localDir} . "/" . $seqGroup;

      # Remove double slashes if present
      $localFile =~ s|//|/|;

      $logger->debug(__PACKAGE__ . ".$sub : Transferring \'$remoteFile\' From MGTS ($scpArgs{-hostip})to \'$localFile\'");

      # Get the file to the local dir provided
      $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$remoteFile;
      $scpArgs{-destinationFilePath} = $localFile;
      if (&SonusQA::Base::secureCopy(%scpArgs)){
	$logger->debug(__PACKAGE__ . ".$sub : Transferred \'$remoteFile\' From MGTS ($scpArgs{-hostip})to \'$localFile\'");
      } 
      # Rename the file for a backup
      rename "$localFile", "$localFile~";

      # Open the files
      open IN, "<$localFile~";
      open OUT, ">$localFile";

      # Edit the file
      while (<IN>) {
         my $line = $_;
         my $stateMachine;
         foreach $stateMachine (@stateMachines) {
            if($line =~ m/$stateMachine/) {
               if($line =~ m/STATE=(.*)\/(\S+) (.*)/) {
                  if($stateMachine eq $2) {
                     if($line =~ m/(.*)BHCA=(\d+)/) {
                        $logger->debug(__PACKAGE__ . ".$sub : The current BHCA : $2 changing to $bhca for state machine $stateMachine");
                        $line = $1 . "BHCA=" . $bhca . "\n";
                     }
                  }
               }
            }
         }
         print OUT $line;
      }

      close IN;
      close OUT;
   
      $logger->debug(__PACKAGE__ . ".$sub : Transferring \'$localFile\' to MGTS ($scpArgs{-hostip}) as \'$remoteFile\' ");
      $scpArgs{-sourceFilePath} = $localFile;
      $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$remoteFile;
      # Put the file back into MGTS
      if (&SonusQA::Base::secureCopy(%scpArgs)){
         $logger->debug(__PACKAGE__ . ".$sub : Transferred \'$localFile\' to MGTS ($scpArgs{-hostip}) as \'$remoteFile\' ");
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub rest_shelf --> $a{-reset_shelf}");
   $logger->debug(__PACKAGE__ . ".$sub downloadoption --> $a{-downloadOption}");
   $logger->debug(__PACKAGE__ . ".$sub timeout --> $a{-timeout}");
   $logger->debug(__PACKAGE__ . ".$sub alignwait --> $a{-alignwait}");

   unless( $self->downloadAssignment(-assignment     => $a{-mgtsAssignment},
                                     -timeout        => $a{-timeout},
				     -reset_shelf    => $a{-reset_shelf},	
				     -alignwait      => $a{-alignwait},	
                                     -downloadOption => $a{-downloadOption},) ) {
      $logger->debug(__PACKAGE__ . ".$sub Could not download assignment $a{-mgtsAssignment}.");
      return 0;
   }

   return 1;
}

=head2 sysInfoForDebug

=over

=item DESCRIPTION:

    This subroutine gets MGTS system information for debug. This data can be handed over to Ixia for
    initial analysis

=item ARGUMENTS:
    Mandatory :
        -testCaseID  => Test Case Id
        -logDir      => Logs are stored in this directory

   Optional:
        -variant    => Test case variant "ANSI", "ITU" etc
                       Default => "NONE"
        -timeStamp  => Time stamp
                       Default => "00000000-000000"

=item PACKAGE:

    QATEST::PRODUCT::MGTSHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   $mgts_object->sysInfoForDebug(-testCaseID      => $testId,
                                 -logDir          => "/home/ssukumaran/ats_user/logs",
                                 -timeStamp       => $timestamp);

=back

=cut

sub sysInfoForDebug {
   my ($self, %args) = @_;
   my $sub = "sysInfoForDebug()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %a = (-variant   => "NONE",
            -timeStamp => "00000000-000000");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );

   unless ( $a{-testCaseID} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Test Case ID is empty or blank.");
      return 0;
   }
   unless ( $a{-logDir} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
      return 0;
   }

   my $cmdString;
   my $logFile;
   my $tmsAlias = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   #Get process info
   $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-ps.log" ;

   # Open log file
   unless (open(PSLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   $cmdString = "ps -aef"; 
   print PSLOG "====================================== $cmdString ======================================================" . "\n";
   my @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 20 );
 
   print PSLOG "@commandResults" . "\n";
   print PSLOG "====================================== END  ======================================================" . "\n";
   close(PSLOG);

   #Get open file descriptors 
   $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-fd.log" ;

   # Open log file
   unless (open(FDLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   $cmdString = "cat /proc/sys/fs/file-nr";

   print FDLOG "====================================== $cmdString ======================================================" . "\n";
   @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 20 );

   print FDLOG "@commandResults" . "\n";

   print FDLOG "====================================== END  ======================================================" . "\n";

   $cmdString = "lsof";

   print FDLOG "====================================== $cmdString ======================================================" . "\n";
   @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 20 );

   print FDLOG "@commandResults" . "\n";
   print FDLOG "====================================== END  ======================================================" . "\n";
   close(FDLOG);

   # Get the Misc Info
   $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-misc.log" ;

   # Open log file
   unless (open(MSLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   my @cmds = ("date",
               "uptime",
               "dmesg",
               "cat /proc/sys/kernel/HZ",
               "cat /proc/vmstat",
               "cat /proc/interrupts",
               "cat /proc/slabinfo",
               "cat /proc/meminfo",
               "netstat -an",
               "lsmod",
               "ps -ewwo pid,ppid,cp,%mem,blocked,c,flags,fname,nice,lwp,policy,rss,sig,stat,sz,vsz,wchan:42,args:256" );

   foreach $cmdString (@cmds) {
      print MSLOG "====================================== $cmdString ======================================================" . "\n";
      @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 20 );
      print MSLOG "@commandResults" . "\n";
      print MSLOG "====================================== END  ======================================================" . "\n";
   }

   close(MSLOG);

   # Tar the temp file of the user
   my $tarFile = $self->{LOG_DIR} . "/" . "$a{-testCaseID}-" . "debugError-temp.tar";
   my $userInfo = $self->{OBJ_USER};
   $cmdString = "tar -cvf $tarFile /tmp/*$userInfo*";

   @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 20 );

   # Get the tar file
   $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-temp.tar" ;

   my %scpArgs;
   $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
   $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
   $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
   $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$tarFile;
   $scpArgs{-destinationFilePath} = $logFile;

   # Get the file to the local dir provided
   if(&SonusQA::Base::secureCopy(%scpArgs)){
      $logger->debug(__PACKAGE__ . ".$sub Copied the file $tarFile to the local dir"); 
   }   

   # Get CPU usage running top for 30secs
   $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-top.log" ;

   # Open log file
   unless (open(TOPLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   $cmdString = "top -d 5 -n 3";

   @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> 60 );

   print TOPLOG "@commandResults" . "\n";
   close(TOPLOG);

   # Copy the session logs
   if ( $self->{SESSIONLOG} ) {
      $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-sLog1.log" ;
      qx{cp $self->{sessionLog1} $logFile};
      
      $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "MGTS-" . "$tmsAlias-" . "debugError-sLog2.log" ;
      qx{cp $self->{sessionLog2} $logFile};
   }

   return 1;
}

=head2 startStateMachines

Execute the given list of MGTS state machines in the respective Node in order with trigger node in the last of execution list.
return SUCCESS(1) if all the MGTS state machines are started successfully else return FAILURE(0)

Note : This subroutine is same as execMgtsStateMachines(), but starting the state machine and checking the result are split here.
The first subroutine startStateMachines() starts the state machines and the second subroutine checkStateMachineStatus() will verify the
status of the state machines started by the first subroutine

=over

=item Arguments:

     -testId
        TMS testcase ID

     -mgtsStateDir
        MGTS state directory

     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node

        Optional keys:
            timeout      - Timeout for executing MGTS state machine
                           default is 60 seconds
            mgtsExecLog  - MGTS execution log disable/enable i.e. 0/1
                           default 0 (no log file created)
            reset_stats  - Reset stats i.e. 0/1 - default 1 (reset)
            decode       - Decode level i.e. 0 to 4
                           default 4 (full decodes)

     -execOrder
        execution order of MGTS state machines on respective nodes.
        Trigger node is defined in the last.

    -variant
        Test case variant "ANSI", "ITU" etc
        Default => "NONE"

    -timeStamp
        Time stamp
        Default => "00000000-000000"

    -doNotLogMGTS
        If this flag is set to 1, the MGTS logging is not done
        Default value is set 0

=item Returns:

    * The updated hash, if all the state machines are executed
    * 0, otherwise

=item Examples:

    my @mgtsStateMachineList = (
    # Mandatory hash keys are - node, statemachine
    # Optional hash keys are:
    #     timeout     - default to 60 seconds
    #     mgtsExecLog - 0 / 1  - default 0 (no log file created)
    #     reset_stats - 0 / 1  - default 1 (reset)
    #     decode      - 0 to 4 - default 4 (full decodes)
        {'node' => 'HLR',   'statemachine' => 'svt_SCTP_M3UA_LINK_HLR',  'timeout' => 90, 'reset_stats' => 1, 'decode' => 4},
        {'node' => 'RNC1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1', 'timeout' => 90, },
        {'node' => 'RNC2',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC2', 'timeout' => 90, },
        {'node' => 'RNC3',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC3', 'timeout' => 90, },
        {'node' => 'SMSC',  'statemachine' => 'svt_SCTP_M3UA_LINK_SMSC', 'timeout' => 90, },
        {'node' => 'PSTN1', 'statemachine' => 'svt_SCTP_M3UA_LINK_PSTN', 'timeout' => 90, },
    );

    # Execution of MGTS state machine(s)
    # Trigger node is defined in the last i.e. PSTN in the given example
    my @execOrder     = qw(HLR RNC1 RNC2 RNC3 SMSC PSTN);
    my $MgtsObj       = $TESTBED{ "mgts:1:obj" };
    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA';

    unless ( $MgtsObj->startStateMachines (
                      -testId       => $TestId,
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder,
                  ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to execute MGTS state machines - (@execOrder)";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }

=item Note :

    check checkStateMachineStatus() to know how the results are verified/retrieved

=back

=cut

#################################################
sub startStateMachines {
#################################################
   my  ( $self, %args ) = @_ ;
   my  $subName = "startStateMachines()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   my %a   = ( -variant            => "NONE",
               -timeStamp          => "00000000-000000",
               -doNotLogMGTS       => 0, );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");

   my $result = 0;

   # Check Mandatory Parameters
   foreach ( qw / testId mgtsStateDir stateMc execOrder / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
         return 0;
      }
   }

   my @execOrder            = @{$a{'-execOrder'}};
   my @mgtsStateMachineList = @{$a{'-stateMc'}};
   my $mgtsStateDir         = $a{'-mgtsStateDir'};

   # START executing the MGTS state machines in the execution order
   foreach my $node (@execOrder) {
      foreach (@mgtsStateMachineList) {
         if ( $_->{node} eq $node) {
            # Get the MGTS state machine(s) description
            my $fullStateMachineName = "$mgtsStateDir" . "$_->{statemachine}" . ".states";
            $_->{description} = $self->getStateDesc(-full_statename => $fullStateMachineName);

            # Set the state machine status to '-1' i.e. otherwise
            # Shall be updated by areStatesRunning()
            $_->{status} = -1;

            # Start executing the MGTS state machine(s) in the order of execution
            my $resetStats = 1; # default (reset)
            if ( defined $_->{reset_stats}) {
               $resetStats = $_->{reset_stats};
            }
            my $decode = 4; # default (full decodes)
            if ( defined $_->{decode}) {
               $decode = $_->{decode};
            }
            my $timeout = 60; # default
            if ( defined $_->{timeout}) {
               $timeout = $_->{timeout};
            }

            if ( $a{-doNotLogMGTS} eq 0) {
               $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node with log file.\n");

               my $logFileName = 'MGTS_' . "$a{-testId}" . "_$a{-variant}" . "_$a{-timeStamp}" .  "_" . $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} . "_" .$_->{node} . ".log";
               $logger->debug(__PACKAGE__ . ".$subName: log file name \'$logFileName\'\n");
               $_->{logFileName} = $logFileName;
               unless ( $self->startExecContinue(
                                                 '-node'        => $_->{node},
                                                 '-machine'     => $_->{description},
                                                 '-timeout'     => $timeout,
                                                 '-logfile'     => $logFileName,
                                                 '-reset_stats' => $resetStats,
                                                 '-decode'      => $decode,
                                                ) ) {
                  $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node." );
                  $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                  return 0;
               }
            } else {
               $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node without log file.\n");
               unless ( $self->startExecContinue(
                                                 '-node'        => $_->{node},
                                                 '-machine'     => $_->{description},
                                                 '-timeout'     => $timeout,
                                                 '-reset_stats' => $resetStats,
                                                ) ) {
                  $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node." );
                  $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                  return 0;
               }
            }
         }
      }
   } # END executing the MGTS state machines in the execution order

   return \@mgtsStateMachineList;
}

=head2 checkStateMachineStatus

This subroutine is the continuation of startStateMachines(). This subroutine checks the status of state machines
started by startStateMachines().

Note : Makesure startStateMachines is run before this and the reference returned by startStateMachines subroutine
is passed on this subroutine

=over

=item Arguments:

     -testId
        TMS testcase ID
     -timeout
        Timeout use for executing machine state check
     -pollingInterval
	polling time interval to sleep after machine status check
     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node

        Optional keys:
            timeout      - Timeout for executing MGTS state machine
                           default is 60 seconds
            mgtsExecLog  - MGTS execution log disable/enable i.e. 0/1
                           default 0 (no log file created)
            reset_stats  - Reset stats i.e. 0/1 - default 1 (reset)
            decode       - Decode level i.e. 0 to 4
                           default 4 (full decodes)

     -execOrder
        execution order of MGTS state machines on respective nodes.
        Trigger node is defined in the last.

    -logDir
         Logs are stored in this directory

    -doNotLogMGTS
        If this flag is set to 1, the MGTS logging is not done
        Default value is set 0

=item Returns:

    * The updated hash, if all the state machines are executed
    * 0, otherwise

=item Examples:

    Refer startStateMachines for the complete details of -stateMc and -execOrder

    my $retData;
    unless ( $retData = $MgtsObj->startStateMachines (
                      -testId       => $testId,
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder,
                  ) ) {
        return 0;
    }

    # Do the test specific activities here
    # E.g., Executing SGX/GSX CLIs

    unless ( $retData = $MgtsObj->checkStateMachineStatus (
                      -testId       => $testId,
                      -stateMc      => $retData,
                      -execOrder    => \@execOrder,
                      -logDir       => "/home/ssukumaran/ats_user/logs/",
                  ) ) {
        return 0;
    }

=back

=cut

sub checkStateMachineStatus {
#################################################
   my  ( $self, %args ) = @_ ;
   my  $subName = "checkStateMachineStatus()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   my %a   = ( -variant            => "NONE",
               -timeStamp          => "00000000-000000",
               -doNotLogMGTS       => 0 );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");

   my $result = 0;

   # Check Mandatory Parameters
   foreach ( qw / testId stateMc execOrder logDir / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
         return 0;
      }
   }

   my @execOrder            = @{$a{'-execOrder'}};
   my @mgtsStateMachineList = @{$a{'-stateMc'}};

   # calculate polling interval
   my $maxTimeout = 60; # default 60 seconds
   foreach (@mgtsStateMachineList) {
      if ( ( defined($_->{timeout}) ) &&
           ( $maxTimeout < $_->{timeout}) ) {
         $maxTimeout = $_->{timeout};
      }
   }

   # Override the maxTimeout if -timeout is passed as argument
   $maxTimeout = $args{"-timeout"} if( defined($args{"-timeout"}) );

   my $pollingInterval = $maxTimeout/10;

   # Override the polling interval if -pollingInterval is passed as argument
   $pollingInterval = $args{"-pollingInterval"} if( defined($args{"-pollingInterval"}) );

   # Check if all state machines have completed execution till timeout occurs
   my $allStatemachinesExecuted = 0;
   my $startLoopTime            = [Time::HiRes::gettimeofday];
   while ( (!$allStatemachinesExecuted) &&
            (tv_interval($startLoopTime) < $maxTimeout) ) {

      sleep($pollingInterval);

      my $statuscompleteCount = 0;
      foreach (@mgtsStateMachineList) {
         $_->{status} = $self->areStatesRunning('-node' => $_->{node});
         if( $_->{status} == 0) { # no state machine(s) running
            $statuscompleteCount++;
         }
      }

      if ( ($#execOrder + 1) == $statuscompleteCount) {
         $allStatemachinesExecuted = 1;
      }
   }

   # Stop the failed nodes if any
   unless ( $allStatemachinesExecuted ) {
      foreach (@mgtsStateMachineList) {
         if( ( $_->{status} == -1 ) || # otherwise
                ( $_->{status} == 1 ) ) { # if state machine(s) are still running on the node
            $self->stopExec('-node' => $_->{node});
         }
      }
   }

   # Check the results of statemachine(s)
   my $passedCount = 0;
   foreach (@mgtsStateMachineList) {
      $_->{result} = $self->checkResult(
                                   '-node'    => $_->{node},
                                   '-machine' => $_->{description},
                               );

      $logger->info(__PACKAGE__ . ".$subName: Result \'$_->{result}\' for node \'$_->{node}\' state machine \'$_->{statemachine}\' and status \'$_->{status}\'");

      if ( $_->{result} >= 1 ) { # state machine passed
         $logger->info(__PACKAGE__ . ".$subName: Execution PASSED");
         $passedCount++;
      }
      elsif ( $_->{result} == 0 ) { # state machine failed
         $logger->info(__PACKAGE__ . ".$subName: Execution FAILED");
      }
      elsif ( $_->{result} == -1 ) { # state machine was not executed or result was inconclusive
         $logger->info(__PACKAGE__ . ".$subName: MGTS script did not transition through PASS/FAIL node OR MGTS::checkResult returned inconclusive result");
      }
      elsif ( $_->{result} == -2 ) { # error occurred in result processing
         $logger->info(__PACKAGE__ . ".$subName: Failed to get result via MGTS::checkResult");
      }
      else {
         $logger->info(__PACKAGE__ . ".$subName: Unexpected return code from MGTS::checkResult");
      }
   }

   if ( ($#execOrder + 1) == $passedCount) {
        $result = 1;
   }

   
   # Get the MGTS logs if required
   if ( $a{-doNotLogMGTS} eq 0) {
      # Get the unique file names
      my %tempNames;
      foreach (@mgtsStateMachineList) {
         $tempNames{$_->{logFileName}}++;
      }
      # Get the file names
      foreach my $tempLogFile (keys %tempNames) {
         if ( $self->downloadLog(-logfile => $tempLogFile,
                                 -local_dir => "$a{-logDir}") == 1 ) {
            my $grepCmd1 = "\\grep \"Warning: The following message does not match any templates\" $a{-logDir}/" . $tempLogFile;
            my $grepCmd2 = "\\grep \"Sequence Completed by Stop\" $a{-logDir}/" . $tempLogFile;
            my $grepResult1 = `$grepCmd1`;
            my $grepResult2 = `$grepCmd2`;
            if ( $grepResult1 ne "" || $grepResult2 ne "" ) {
               $logger->error(__PACKAGE__ .  ".$subName : \n#### LOG ERRORS FOUND\n##$grepResult1\n##$grepResult2\n");
            }
         } else {
            $logger->warn(__PACKAGE__ .  ".$subName : Error in downloading log file from MGTS");
         }
      }
   }

   my %temp;
   $temp{'finalResult'} = $result;

   push (@mgtsStateMachineList, \%temp);

   $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub execMgtsStateMachines [$result]");

   return \@mgtsStateMachineList;
}

=head2 isFileOrDirExists

    This subroutine is used to check whether given file or directory exists on MGTS box.

=over

=item Arguments :

   path - file/directory name or path

=item Return Values :

   1 - if exists
   0 - On failure

=item Example :

   my $path = "/home/mgts";
   my $status= $mgtsObj->isFileOrDirExists($path);

   my $path = "file.txt"
   my $status= $mgtsObj->isFileOrDirExists($path);

   my $path = "MYDIR";
   my $status= $mgtsObj->isFileOrDirExists($path);

=item Author :

Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub isFileOrDirExists {
    my ($self, $path) = @_;
    my $sub = "isFileOrDirExists()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".isFileOrDirExists()");

    unless ($path) {
        $logger->error("$sub : Did not specified file or directory name which is a mandatory parameter");
        return 0;
    }

    my $fileCmd = "test -f $path";
    my $dircmd  = "test -d $path";

    unless ($self->cmd( -cmd => $fileCmd)) {
        $logger->debug("$sub : Given file \"$path\" exists");
        return 1;
    }

    unless ($self->cmd( -cmd => $dircmd)) {
        $logger->debug("$sub : Given directory \"$path\" exists");
        return 1;
    }

    $logger->error("$sub : Given file or directory does not exists");

    return 0;
}

=head2 convertM2paAssignmentV4toV6

=over

=item DESCRIPTION:

 This subroutine is used to utilise the currently available script provided by Ixia to convert IPv4 M2PA assignments to IPv6.
 Written for the requirement specified in CQ SONUS00117952.
 Basically the steps performed by this API are :
   1. Sources the set_mgts_env from users home directory.
   2. downloads the assignment specified by the user.
   3. Execute the following command from /home/<user>/datafiles Dir. :-
      mipv6 <build file name> <conversion file>

=item Arguments:

   Mandatory :

   1. Assignment Name      - User has to pass the desired assignment name that he wishes to download.
   2. Conversion File Name - User has to pass the conversion file for IPv4 to IPv6 conversion.

   Optional:

   1. alignwait            - <align timeout value>
                             Wait a specified time (seconds) for alignment to occur.
                             Valid values:   positive integer > 0
                             Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
                             Arg example:    -alignwait => 18
   2. timeout 		   - <timeout value>
		             Command timeout in seconds;
 		             Valid values:   positive integer > 0
		             Default value:  20 seconds
		             Arg example:    -timeout => 20
   3. downloadOption       - <assignmennt download option>
		             Specify assignmennt download option for the commands 'networkExecuteM5k' or 'networkExecute'
		             Valid values  : -download or -noBuild
		             Default value : -download
		             Example       : -downloadOption => '-noBuild'

   4. reset_shelf 	   - <0 or 1>
		             Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
		             Valid Values:   0 (don't reset) or 1 (reset)
 		             Default Value:  1 (reset)
		             Arg example:    -reset_shelf => 0 

=item Returns:

    - 1, on success
    - 0, otherwise

=item Example:

   unless ($mgts_object->convertM2paAssignmentV4toV6(-assignment     => "M2PA_Traffic_Controls_ANSI_Slot8" ,
						     -alignwait      => 30 ,	
						     -downloadOption =>	'download',
						     -timeout 	     => 30,
						     -rest_shelf     => 0,	
                                                     -convFileName   => "IP_Conversions" )) {

        $logger->error(__PACKAGE__ . ".$sub : Failed to convert desired M2pa assignment from V4 to V6 ");
        return 0;
    }

=back

=cut

sub convertM2paAssignmentV4toV6 {

    my ($self, %args) = @_;
    my $mgtsBashObj;
    
    my $sub = "convertM2paAssignmentV4toV6";
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %args);

    my @output;
    # Attempt to create ATS MGTS object.If unsuccessful ,exit will be called from SonusQA::MGTS::new function
    # New Object created with shell = bash. 
    unless( $mgtsBashObj = SonusQA::Base->new(-obj_host => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}",
                                              -obj_user => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}",
                                              -comm_type => "$self->{COMM_TYPE}",
                                             # -shelf => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}",
                                             # -shelf_version => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM}",
                                             # -display => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{DISPLAY}", 
                                             # -protocol => "ANSI-SS7",
                                             # -shell => "bash",
                                             # -fish_hook_port => 10063
                                            )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to create a MGTS Object with bash shell for $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} ");
        return 0;
    }
    @output = $mgtsBashObj->{conn}->cmd( "bash"  );
    $logger->debug(__PACKAGE__ . ".$sub : Successfully created a MGTS Object with bash shell :\n @output \n");
    
    # Set the MGTS Environment in "bash" shell by sourcing set_mgts_env from the Home Directory.
    my $cmd = "source set_mgts_env";
    unless ( @output = $mgtsBashObj->{conn}->cmd( $cmd  )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to execute  \' $cmd \' ");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Executed \' $cmd \' Successfully : OUTPUT: @output \n");
    
    # check align wait is a positive integer
    if (defined($args{-alignwait}) && $args{-alignwait} <= 0) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
        return 0;
    }    

    unless( $args{-alignwait}) {
        if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
            $args{-alignwait} = 15;
        } else {
            $args{-alignwait} = 10;
        }
    }
   
    unless (defined($args{-reset_shelf})) {
	$args{-reset_shelf} = 1;
    }    
    unless (defined($args{-timeout})) {
        $args{-timeout} = 30;	
    }
    unless (defined($args{-downloadOption})) {
	$args{-downloadOption} = '-download';
    }
   
    $logger->debug(__PACKAGE__ . ".$sub rest_shelf --> $args{-reset_shelf}");
    $logger->debug(__PACKAGE__ . ".$sub downloadoption --> $args{-downloadOption}");
    $logger->debug(__PACKAGE__ . ".$sub timeout --> $args{-timeout}");
    $logger->debug(__PACKAGE__ . ".$sub alignwait --> $args{-alignwait}");

    #download the assignment specified by the user from the "csh" shell.
    unless($self->downloadAssignment(-assignment     => $args{-assignment},
				     -reset_shelf    => $args{-reset_shelf}, 	
				     -timeout        => $args{-timeout},
				     -downloadOption => $args{-downloadOption},		     	
				     -alignwait      => $args{-alignwait},)) {

       $logger->error(__PACKAGE__ . ".$sub : Failed to Download the Assignment  \' $args{-assignment} \' ");
       return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Downloaded Assignment \' $args{-assignment} \' Successfully  ");
    
    #change the "bash" shell directory to /home/<user>/datafiles
    $cmd = "cd datafiles";
    unless ( $mgtsBashObj->{conn}->cmd( $cmd )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to execute  \'$cmd \' ");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Executed \'$cmd \'  Successfully  ");
    
    #convert IPv4 M2PA assignments to IPv6. with the build file name and conversion file name as specified by the user.
    $cmd = "mipv6 $args{-assignment} $args{-convFileName}";
    unless ( @output = $mgtsBashObj->{conn}->cmd( $cmd )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to execute  \'$cmd \'");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Executed \'$cmd \'  Successfully  \n :OUTPUT: @output \n ");
    
    #Destroy the "bash" shell mgts object created in this API.
    $mgtsBashObj->{conn}->close;
    $mgtsBashObj->DESTROY;
    return 1;
    
}

=head2 executeLoad

Execute the given list of MGTS state machines in load mode in the respective Node in order with trigger node in the last of execution list.
return SUCCESS(1) if all the MGTS state machines are started successfully else return FAILURE(0)

Note : This subroutine is same as startStateMachines(), but this API is entirely for the load cases. [ for both with and without the "-run" parameter. ]
      And this API is introduced so as to provision for running a selected state machine once or mutiple times [ i.e, without -run parameter ]

=over

=item Arguments:

=item Mandatory Arguments:

     -mgtsStateDir
        MGTS state directory

     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node
            or
            sequence     - <state sequence number> sequence number of state machine to execute,
                            if "" (or not defined) then either -machine or the whole sequence group

            Optional keys:
            noOfTimes    - The number of times, you want this node<=>state machine or node<=>sequence to run.
                            The values can be
                               1.	A number 1-n
                                       - Needs to execute multiple times in a loop
                               2.	Default value 1
                                 -> The -run parameter shall not be used in the above two cases.
                               3.	0  running for indefinite times. ( with "-run " )

            timeout      - Timeout for executing MGTS state machine
                           default is 60 seconds
            reset_stats  - Reset stats i.e. 0/1 - default 1 (reset)

     -execOrder
        execution order of MGTS state machines on respective nodes.
        Trigger node is defined in the last.

=item Returns:

    * The updated hash, if all the state machines are executed
    * 0, otherwise

=item Examples:

    my @mgtsStateMachineList = (
    # Mandatory hash keys are - node, statemachine
    # Optional hash keys are:
    #     timeout     - default to 60 seconds
    #     reset_stats - 0 / 1  - default 1 (reset)
        {'node' => 'HLR',   'statemachine' => 'svt_SCTP_M3UA_LINK_HLR',  'timeout' => 90, 'noOfTimes' => 0, 'reset_stats' => 1}, # with "-run" 
        {'node' => 'RNC1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1', 'noOfTimes' => 8,  'timeout' => 90, },                  #without "-run" -> run 8 times
        {'node' => 'RNC2',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC2', 'noOfTimes' => 1, 'timeout' => 90, },                   #without "-run" ->  run 1 time
        {'node' => 'RNC3',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC3', 'timeout' => 90, },                   #Default without "-run" ->  run 1 time
        {'node' => 'SMSC',  'sequence' => 11 , 'timeout' => 90, },                                             #Default without "-run" ->  run 1 time
        {'node' => 'PSTN1', 'sequence' => 12 , 'timeout' => 90, },                                             #Default without "-run" ->  run 1 time
    );

    # Execution of MGTS state machine(s)
    # Trigger node is defined in the last i.e. PSTN in the given example
    my @execOrder     = qw(HLR RNC1 RNC2 RNC3 SMSC PSTN);
    my $MgtsObj       = $TESTBED{ "mgts:1:obj" };
    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA';

    unless ( $MgtsObj->executeLoad (
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder,
                  ) ) {
        $logger->error( __PACKAGE__ . "$sub : Failed to Execute All the state machines " ); 
        return 0;
    }

=item Note :

    check checkStateMachineStatus() to know how the results are verified/retrieved

=back

=cut

sub executeLoad {
   my  ( $self, %args ) = @_ ;
   my  $subName = "executeLoad()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   my %a   = ( );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");

   # Check Mandatory Parameters
   foreach ( qw / mgtsStateDir stateMc execOrder / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
         return 0;
      }
   }

   my @execOrder            = @{$a{'-execOrder'}};
   my @mgtsStateMachineList = @{$a{'-stateMc'}};
   my $mgtsStateDir         = $a{'-mgtsStateDir'};
   
   #Check for mandatory keys in the stateMc List.
   foreach (@mgtsStateMachineList) {
        unless (defined $_->{node}) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory key \'node\' for one of the statemachines has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
        unless ( defined $_->{statemachine} || defined $_->{sequence} ) {
            $logger->error(__PACKAGE__ . ".$subName:  Neither of the keys \'statemachine\' or \'sequence\' has been specified for the node $_->{node} ");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
        # Default value of 1 for the noOfTimes key, if not specified by the user.
        unless (defined $_->{noOfTimes}) {
            $_->{noOfTimes} = 1;        
        }
   }
   
   # START executing the MGTS state machines in the execution order
   foreach my $node (@execOrder) {
      foreach (@mgtsStateMachineList) {
         if ($_->{noOfTimes} == 0) {   # If to run the state machine for an indefinite period. 
             if ( $_->{node} eq $node) {
            
                 # Set the state machine status to '-1' i.e. otherwise
                 # Shall be updated by areStatesRunning()
                 $_->{status} = -1;
                 
                 # start Tx counts, to be used in stopLoad() to check for failures.
                 $_->{startCount} = 1;

                 # Start executing the MGTS state machine(s) in the order of execution
                 my $resetStats = 0; # default (do not reset)
                 if ( defined $_->{reset_stats}) {
                     $resetStats = $_->{reset_stats};
                 }
                 
                 my $timeout = 60; # default
                 if ( defined $_->{timeout}) {
                     $timeout = $_->{timeout};
                 }
                 #If statemachine is defined.
                 if (defined $_->{statemachine}) {
                     # Get the MGTS state machine(s) description
                     my $fullStateMachineName = "$mgtsStateDir" . "$_->{statemachine}" . ".states";
                     $_->{description} = $self->getStateDesc(-full_statename => $fullStateMachineName);

                     $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node for an indefinite period.\n");
                     unless ( $self->startExecContinue(
                                             '-node'        => $_->{node},
                                             '-machine'     => $_->{description},
                                             '-timeout'     => $timeout,
                                             '-reset_stats' => $resetStats,
                                             '-load'        => 1,
                                                ) ) {
                           $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node for an indefinite period." );
                           $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                           return 0;
                     }
                 } 
                 else  { # If sequence number is passed instead of statemachine.
                     $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS sequence numbered \'$_->{sequence}\' on node $node for an indefinite period.\n");
                     unless ( $self->startExecContinue(
                                             '-node'        => $_->{node},
                                             '-sequence'    => $_->{sequence},
                                             '-timeout'     => $timeout,
                                             '-reset_stats' => $resetStats,
                                             '-load'        => 1,
                                                ) ) {
                          $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS sequence numbered \'$_->{sequence}\' on node $node for an indefinite period." );
                          $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                          return 0;
                     }
                 }
             }
         }  
         else { # If the statemachine has to be run for a definite number of times specified by the user.
            if ( $_->{node} eq $node) {
            
             # Set the state machine status to '-1' i.e. otherwise
             # Shall be updated by areStatesRunning()
             $_->{status} = -1;
            
             # start Tx counts, to be used in stopLoad() to check for failures.
             $_->{startCount} = $_->{noOfTimes};
            
             # Start executing the MGTS state machine(s) in the order of execution
             my $resetStats = 0; # default (reset)
             if ( defined $_->{reset_stats}) {
                 $resetStats = $_->{reset_stats};
                 delete $_->{reset_stats};
             }
             
             my $timeout = 60; # default
             if ( defined $_->{timeout}) {
                 $timeout = $_->{timeout};
             }
             
             if (defined $_->{statemachine}) {
                 # Get the MGTS state machine(s) description
                 my $fullStateMachineName = "$mgtsStateDir" . "$_->{statemachine}" . ".states";
                 $_->{description} = $self->getStateDesc(-full_statename => $fullStateMachineName);
             }
             
             my $noOfTimes = $_->{noOfTimes};
             # Loop and run the state machine for specified no of times.
             while ( $noOfTimes  ) {
                 #If statemachine is defined.
                 if (defined $_->{statemachine}) {
                     $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS \'$_->{statemachine}\' on node $node .\n");
                     unless ( $self->startExecContinue(
                                             '-node'        => $_->{node},
                                             '-machine'     => $_->{description},
                                             '-timeout'     => $timeout,
                                             '-reset_stats' => $resetStats,
                                             '-load'        => 1,
                                             '-runOnceForLoad'     => 1,
                                                ) ) {
                         $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS \'$_->{statemachine}\' on node $node." );
                         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                         return 0;
                     }
                     $self->awaitLoadCompletion( -nodes => "$_->{node}" );
                     my $result = $self->checkResult( -node => $_->{node}, -machine => $_->{description});
                     if (  $result gt 0 ) {
                         $logger->debug(__PACKAGE__ . ".$subName: $_->{statemachine} PASSED . Passed Count is $result ");
                     } elsif ( $result eq 0 ) {
                         $logger->debug(__PACKAGE__ . ".$subName: $_->{statemachine} FAILED ");
                         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                         return 0;
                     } else {
                         $logger->debug(__PACKAGE__ . ".$subName: No results found for $_->{statemachine} . \( $result \) \n");
                         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                         return 0;
                     }
                     #$self->awaitLoadCompletion( -nodes => "$_->{node}" );
                 } 
                 else { # If sequence number is passed instead of statemachine.
                     $logger->debug(__PACKAGE__ . ".$subName: starting to execute MGTS sequence numbered \'$_->{sequence}\' on node $node .\n");
                     unless ( $self->startExecContinue(
                                             '-node'        => $_->{node},
                                             '-sequence'    => $_->{sequence},
                                             '-timeout'     => $timeout,
                                             '-reset_stats' => $resetStats,
                                             '-load'        => 1,
                                             '-runOnceForLoad'     => 1,
                                                ) ) {
                          $logger->error(__PACKAGE__ . ".$subName:  Failed to execute MGTS sequence numbered \'$_->{sequence}\' on node $node." );
                          $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                          return 0;
                     }
                     $self->awaitLoadCompletion( -nodes => "$_->{node}" );
                     my $result = $self->checkResult( -node => $_->{node}, -sequence => $_->{sequence});
                     if (  $result gt 0 ) {
                         $logger->debug(__PACKAGE__ . ".$subName: $_->{sequence} PASSED. Passed Count is $result  ");
                     } elsif ( $result eq 0 ) {
                         $logger->debug(__PACKAGE__ . ".$subName: $_->{sequence} FAILED ");
                         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                         return 0;
                     } else {
                         $logger->debug(__PACKAGE__ . ".$subName: No results found for $_->{sequence} . \( $result \) \n");
                         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                         return 0;
                     }
                     #$self->awaitLoadCompletion( -nodes => "$_->{node}" );
                 }
                 $noOfTimes--;
                 # reset stats only once . the first time.
                 if ( $resetStats ) {
                     $resetStats = 0;
                 }
             }
            }
         } # END executing the MGTS state machines in the execution order
      }
   }
   return \@mgtsStateMachineList;
}

=head2 startLoad

Execute the given list of MGTS state machines in load mode in the respective Node in order with trigger node in the last of execution list.
return SUCCESS(1) if all the MGTS state machines are started successfully else return FAILURE(0) 

Note: Here State machine execution is done with the "-run" Parameter.

This is Wrapper Function, which in turn calls API executeLoad(). 

=over

=item Arguments:

=item Mandatory Arguments:

     -mgtsStateDir
        MGTS state directory

     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node
            or
            sequence     - <state sequence number> sequence number of state machine to execute,
                            if "" (or not defined) then either -machine or the whole sequence group

            Optional keys:
            timeout      - Timeout for executing MGTS state machine
                           default is 60 seconds
            reset_stats  - Reset stats i.e. 0/1 - default 1 (reset)

     -execOrder
        execution order of MGTS state machines on respective nodes.
        Trigger node is defined in the last.

=item Returns:

    * The updated hash, if all the state machines are executed
    * 0, otherwise

=item Examples:

    my @mgtsStateMachineList = (
    # Mandatory hash keys are - node, statemachine
    # Optional hash keys are:
    #     timeout     - default to 60 seconds
    #     reset_stats - 0 / 1  - default 1 (reset)
        {'node' => 'HLR',   'statemachine' => 'svt_SCTP_M3UA_LINK_HLR',  'timeout' => 90, 'reset_stats' => 1},
        {'node' => 'RNC1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1',  'timeout' => 90, },                 
        {'node' => 'SMSC',  'sequence' => 11 , 'timeout' => 90, },        
        {'node' => 'PSTN1', 'sequence' => 12 , 'timeout' => 90, },       
    );

    # Execution of MGTS state machine(s)
    # Trigger node is defined in the last i.e. PSTN in the given example
    my @execOrder     = qw(HLR RNC1 RNC2 RNC3 SMSC PSTN);
    my $MgtsObj       = $TESTBED{ "mgts:1:obj" };
    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA/';

    unless ( $MgtsObj->startLoad (
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder,
                  ) ) {
        $logger->debug( __PACKAGE__ . "$sub : Failed to stop all the state machines" ); 
        return 0;
    }

=item Note :

    check checkStateMachineStatus() to know how the results are verified/retrieved

=back

=cut

sub startLoad {
   my  ( $self, %args ) = @_ ;
   my  $subName = "startLoad()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   my %a   = ( );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");
   
   # Check Mandatory Parameters
   foreach ( qw / mgtsStateDir stateMc execOrder / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
         return 0;
      }
   }
   
   my @execOrder            = @{$a{'-execOrder'}};
   my @mgtsStateMachineList = @{$a{'-stateMc'}};
   my $mgtsStateDir         = $a{'-mgtsStateDir'};
   
   foreach (@mgtsStateMachineList) {
      $_->{noOfTimes} = 0;
   }
   
   unless($self->executeLoad(
                      -mgtsStateDir => $mgtsStateDir,
                      -stateMc      => \@mgtsStateMachineList,
                      -execOrder    => \@execOrder, )) {
       $logger->debug( __PACKAGE__ . "$subName : Failed to Start All the stateMachines mentioned in the List." ); 
       return 0;
   }
   
   return \@mgtsStateMachineList;
}

=head2 stopLoad

Stop the given list of MGTS state machines in load mode in the respective Node.
return SUCCESS(1) if all the MGTS state machines are stopped successfully else return FAILURE(0)

Note: Has to be called after startLoad() or executeLoad().

=over

=item Arguments:

=item Mandatory Arguments:

     -mgtsStateDir
        MGTS state directory

     -stateMc
        MGTS state machine details
        Mandatory keys:
            node         - Node name defined in MGTS
            statemachine - State machine name defined in MGTS for given Node
            or
            sequence     - <state sequence number> sequence number of state machine to execute,
                            if "" (or not defined) then either -machine or the whole sequence group

            Optional keys: 
            timeout      - Timeout for executing MGTS state machine
                           default is 60 seconds.

=item Returns:

    * 1, if all the statemachines mentioned are stopped successfully.
    * 0, otherwise

=item Examples:

    my @mgtsStateMachineList = (
    # Mandatory hash keys are - node, statemachine
    # Optional hash keys are:
    #     timeout     - default to 60 seconds
    #     reset_stats - 0 / 1  - default 1 (reset)
        {'node' => 'HLR',   'statemachine' => 'svt_SCTP_M3UA_LINK_HLR' , 'timeout' => 90, },
        {'node' => 'RNC1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1', 'timeout' => 90, },
        {'node' => 'RNC2',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC2', 'timeout' => 90, },
        {'node' => 'RNC3',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC3', 'timeout' => 90, },
        {'node' => 'SMSC',  'sequence' => 11 , 'timeout' => 90, },
        {'node' => 'PSTN1', 'sequence' => 12 , 'timeout' => 90, },
    );
    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA';

    unless ( $MgtsObj->stopLoad (
                      -mgtsStateDir => $mgtsStatesDir,
                      -stateMc      => \@mgtsStateMachineList,
                  ) ) {
        $logger->debug( __PACKAGE__ . "$sub : Failed to stop all the state machines" ); 
        return 0;
    }

=item Note :

    check checkStateMachineStatus() to know how the results are verified/retrieved

=back

=cut

sub stopLoad {
   my  ( $self, %args ) = @_ ;
   my  $subName = "stopLoad()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   my %a   = ( );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");
   
   # Check Mandatory Parameters
   foreach ( qw / mgtsStateDir stateMc / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
         return 0;
      }
   }
   
   my @mgtsStateMachineList = @{$a{'-stateMc'}};
   my $mgtsStateDir         = $a{'-mgtsStateDir'};
   
   #Check for Mandatory Keys in the state machine List.
   foreach (@mgtsStateMachineList) {
        unless (defined $_->{node}) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory key \'node\' for one of the statemachines has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
        unless ( defined $_->{statemachine} || defined $_->{sequence} ) {
            $logger->error(__PACKAGE__ . ".$subName:  Neither of the keys \'statemachine\' or \'sequence\' has been specified for the node $_->{node} ");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
   }
   
   foreach (@mgtsStateMachineList) {
       
       my $timeout = 60; # default
       if ( defined $_->{timeout}) {
           $timeout = $_->{timeout};
       }
      
       if (defined $_->{statemachine}) {
           # Get the MGTS state machine(s) description
           my $fullStateMachineName = "$mgtsStateDir" . "$_->{statemachine}" . ".states";
           $_->{description} = $self->getStateDesc(-full_statename => $fullStateMachineName);
       }
       #If statemachine is defined.
       if (defined $_->{statemachine}) {
           $logger->debug(__PACKAGE__ . ".$subName: starting to stop MGTS \'$_->{statemachine}\' on node $_->{node} .\n");
           unless ( $self->stopExec(
                                    '-node'        => $_->{node},
                                    '-machine'     => $_->{description},
                                    '-timeout'     => $timeout,
                                       ) ) {
               $logger->error(__PACKAGE__ . ".$subName:  Failed to stop MGTS \'$_->{statemachine}\' on node $_->{node}." );
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
       } 
       else { # If sequence number is passed instead of statemachine.
           $logger->debug(__PACKAGE__ . ".$subName: starting to stop MGTS sequence numbered \'$_->{sequence}\' on node $_->{node} .\n");
           unless ( $self->stopExec(
                                    '-node'        => $_->{node},
                                    '-sequence'    => $_->{sequence},
                                    '-timeout'     => $timeout,
                                       ) ) {
               $logger->error(__PACKAGE__ . ".$subName:  Failed to stop MGTS sequence numbered \'$_->{sequence}\' on node $_->{node}." );
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
       }
   }
   return 1;
}

=head2 compareLoadStatusOn2SidesOfMGTS

This Sub Compares the Total Number of Transmission Starts to the Total Number of Passed Counts in the Transmitting Side ( As specified by the User ).
If they are EQUAL, then it compares the Total Number of Received Starts to the Total Number of Passed Counts in the Receiving Side.
In the End, Compare the Transmitting side Passed Counts with the Receiving side Passed Counts.

The External Side can have many MGTS Objects. Those MGTS Objects will be passed in an array. The internal Side will have a single MGTS Object.

Which side ( External or Internal) is the Transmitting Side will be specified by the User.

Note: Shall be called After executeLoad() . To check if the state machine calls were successful.

=over

=item Arguments:

=item Mandatory Arguments:

     -externalSideInfo
      This will be an Array(list) of Hashes. 
       Mandatory Keys:
        mgtsObj       - MGTS Object used for this particular state machine Call.
        mgtsStatesDir - Mgts States Directory for this state machine call.
        node          - Node name defined in MGTS
        statemachine  - State machine name defined in MGTS for given Node
            or
        sequence     - <state sequence number> sequence number of state machine 

     -internalSideInfo
      An Array (list) of Hashes.
      Mandatory Keys:
        mgtsObj   -  MGTS Object used for this particular state machines Call.
        mgtsStatesDir - Mgts States Directory for this state machine call.
        node         - Node name defined in MGTS
        statemachine - State machine name defined in MGTS for given Node
            or
        sequence     - <state sequence number> sequence number of state machine 

=item Optional Arguments:

     -transmitSide - "external" or "internal" . By default external side 

=item Returns:

    * 1, if Successful.
    * 0, otherwise

=item Examples:

    my $mgtsStatesDir = '/home/ahegde/17.3user/datafiles/States/M3UA';
    my @externalSideList = (
        {'mgtsObj' => $mgtsObject1,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'STP1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC1' , },
        {'mgtsObj' => $mgtsObject1,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'STP1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC2' , },
        {'mgtsObj' => $mgtsObject2,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'STP1',  'statemachine' => 'svt_SCTP_M3UA_LINK_RNC3' , },
        {'mgtsObj' => $mgtsObject1,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'STP1',  'sequence' => 8 , },
        {'mgtsObj' => $mgtsObject2,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'STP1',  'sequence' => 9 , },
    );

    my @internalSideList = (
        {'mgtsObj' => $mgtsObject3,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'GSX1',  'statemachine' => 'SCTP-Req-ASPUP-GSX1-CE0-M3UA-ANSI' , },
        {'mgtsObj' => $mgtsObject3,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'GSX1',  'statemachine' => 'SCTP-Req-ASPUP-GSX1-CE1-M3UA-ANSI' , },
        {'mgtsObj' => $mgtsObject3,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'GSX1',  'statemachine' => 'M3UA-GSX1-Register-CE0-ANSI' , },
        {'mgtsObj' => $mgtsObject3,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'GSX1',  'sequence' => 4 , },
        {'mgtsObj' => $mgtsObject3,   'mgtsStatesDir' => $mgtsStatesDir , 'node' => 'GSX1',  'sequence' => 5 , },
    );

    unless ( SonusQA::MGTS::MGTSHELSPER::compareLoadStatusOn2SidesOfMGTS (
                      -externalSideInfo   => \@externalSideList,
                      -internalSideInfo   => \@internalSideList,
                      -transmitSide       => "external",
                  ) ) {
        $logger->debug( __PACKAGE__ . "$sub : Passed Counts on the 2 Sides of MGTS are not EQUAL " ); 
        return 0;
    }

=back

=cut

sub compareLoadStatusOn2SidesOfMGTS {
   
   my  ( %args ) = @_ ;
   my  $subName = "compareLoadStatusOn2SidesOfMGTS()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   unless ( defined $args{-transmitSide}) {
      $args{-transmitSide} = "external";
   }
   
   my %a   = ( );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__, -sub => $subName, %a );

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub $subName");
   
   # Check Mandatory Parameters and its Keys.
   foreach ( qw / externalSideInfo internalSideInfo / ) {
       unless ( defined ( $a{"-$_"} ) ) {
           $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
           $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
           return 0;
       }
       foreach (@{$a{"-$_"}}) {
           unless (defined $_->{mgtsObj}) {
               $logger->error(__PACKAGE__ . ".$subName:  The mandatory key \'mgtsObj\' for one of the statemachines has not been specified or is blank.");
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
           unless (defined $_->{mgtsStatesDir}) {
               $logger->error(__PACKAGE__ . ".$subName:  The mandatory key \'mgtsStatesDir\' for one of the statemachines has not been specified or is blank.");
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
           unless (defined $_->{node}) {
               $logger->error(__PACKAGE__ . ".$subName:  The mandatory key \'node\' for one of the statemachines has not been specified or is blank.");
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
           unless ( defined $_->{statemachine} || defined $_->{sequence} ) {
               $logger->error(__PACKAGE__ . ".$subName:  Neither of the keys \'statemachine\' or \'sequence\' has been specified for the node $_->{node} ");
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
               return 0;
           }
       }
   }
   # Assign the external and internal sides.
   my ( @transmitSide, @receiveSide ); 
   if ( $a{-transmitSide} =~  /external/i ) {
      @transmitSide = @{$a{'-externalSideInfo'}};
      @receiveSide  = @{$a{'-internalSideInfo'}};
   } else {
      @transmitSide = @{$a{'-internalSideInfo'}};
      @receiveSide = @{$a{'-externalSideInfo'}};
   }
   
   my $retStatus = 1;
   
   my $totalPassedInTxSide =0;
   foreach ( @transmitSide ) {
      if (defined $_->{sequence}) {
         unless ( $_->{mgtsObj}->getSeqList(-node => $_->{node} )) {
             $logger->error(__PACKAGE__ . ".$subName:  Could not Get the Required Sequence Details for specified node.");
             $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
             return 0;
         }
         $_->{description} = $_->{mgtsObj}->{SEQLIST}->{$_->{node}}->{SEQUENCE}{$_->{sequence}};
      } else {
         my $fullStateMachineName = "$_->{mgtsStatesDir}" . "$_->{statemachine}" . ".states";
         $_->{description} = $_->{mgtsObj}->getStateDesc(-full_statename => $fullStateMachineName);
      }
      
      unless ( $_->{mgtsObj}->_readLoadStatus(-node => $_->{node})) {
          $logger->error(__PACKAGE__ . ".$subName:  Could not Get the Required Load Status Details for specified node.");
          $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
          return 0;
      }
      
      my $TxCount = $_->{mgtsObj}->{STATUS}->{$_->{node}}->{$_->{description}}{transmitted};
      my $passedCount = $_->{mgtsObj}->{STATUS}->{$_->{node}}->{$_->{description}}{passed};
      unless ( $TxCount eq $passedCount ) {
          $logger->error(__PACKAGE__ . ".$subName:  Tx Start Count \( $TxCount \) is NOT EQUAL to the Passed Count \( $passedCount \) of state machine $_->{description}");
          $retStatus = 0;
      }
      if ( $retStatus == 1 ) {
          $logger->debug(__PACKAGE__ . ".$subName:  Tx Start Count \( $TxCount \) is EQUAL to the Passed Count \( $passedCount \) of state machine $_->{description}");
      }
      $retStatus = 1;
      $totalPassedInTxSide += $TxCount;
   }
   
   my $totalPassedInRxSide =0;
   foreach ( @receiveSide ) {
      if (defined $_->{sequence}) {
         unless ( $_->{mgtsObj}->getSeqList(-node => $_->{node} )) {
             $logger->error(__PACKAGE__ . ".$subName:  Could not Get the Required Sequence Details for specified node.");
             $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
             return 0;
         }
         $_->{description} = $_->{mgtsObj}->{SEQLIST}->{$_->{node}}->{SEQUENCE}{$_->{sequence}};
      } else {
         my $fullStateMachineName = "$_->{mgtsStatesDir}" . "$_->{statemachine}" . ".states";
         $_->{description} = $_->{mgtsObj}->getStateDesc(-full_statename => $fullStateMachineName);
      }
       
      unless ( $_->{mgtsObj}->_readLoadStatus(-node => $_->{node})) {
          $logger->error(__PACKAGE__ . ".$subName:  Could not Get the Required Load Status Details for specified node.");
          $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
          return 0;
      }
      
      my $RxCount = $_->{mgtsObj}->{STATUS}->{$_->{node}}->{$_->{description}}{received};
      my $passedCount = $_->{mgtsObj}->{STATUS}->{$_->{node}}->{$_->{description}}{passed};
      unless ( $RxCount eq $passedCount ) {
          $logger->error(__PACKAGE__ . ".$subName:  Rx Start Count \( $RxCount \) is not EQUAL to the Passed Count \( $passedCount \) of state machine $_->{description}");
          $retStatus = 0;
      }
      if ( $retStatus == 1 ) {
          $logger->debug(__PACKAGE__ . ".$subName:  Rx Start Count \( $RxCount \) is EQUAL to the Passed Count \( $passedCount \) of state machine $_->{description}");
      }
      $retStatus = 1;
      $totalPassedInRxSide += $passedCount;
   }
   
   unless ( $totalPassedInTxSide eq $totalPassedInRxSide  ) {
       $logger->error(__PACKAGE__ . ".$subName: Total Transmitted Count \( $totalPassedInTxSide \) of Transmit Side  is NOT EQUAL to the Total Passed Count \( $totalPassedInRxSide \) of Received Side.");
       $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
       return 0;
   }
   $logger->debug(__PACKAGE__ . ".$subName: Total Transmitted Count \( $totalPassedInTxSide \) of Transmit Side  is EQUAL to the Total Passed Count \( $totalPassedInRxSide \) of Received Side.");
   $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [Success]");
   return 1;
}


=head2 configureMgtsFromTemplate

Iterate through template files for tokens, 
replace all occurrences of the tokens with the values in the supplied hash (i.e. data from TMS).
Download TarFile into the MGTS Path or upload from repository depending upon the input.
Later, configure the MGTS by downloading the assignment.

Note : This is also a wrapper function for configureMgtsFromTemplateFromTar.

=over

=item Arguments :

Mandatory
 1. -mgtsAccount                -  MGTS account from where the assignment is downloaded
                                   and to where the converted file from template is copied to.
    or
    -tarFileName                -  Tar file to be downloaded
                                   E.g., "abcd.tar"
 2. -mgtsAssignmentTemplateList - file list (array reference)
                                  specify the list of file names of template (containing CLI commands)
 3. -replacementMap             - replacement map for the tokens .(hash reference)
                                  specify the string to search for in the file
 4. -mgtsAssignment             - MGTS assignment to be downloaded.

Conditional:
 1. -localDirForTarFile          - This is the directory where the tar file is present.
                                   Mandatory if tarFileName is specified.

Optional :
 1. -mgtsPath                   - Path in the MGTS, where the converted file from template has to be copied to.
                                  Default : $self->{MGTS_DATA} will be taken as the path.
 2. -pasmDbName                 - PASM DB Name of the MGTS. Expected to be present in the /home/<user>/datafiles/ directory of the MGTS.
 3. -columnValues               - A hash reference . The hash will have the keys as the column names of the DB
 4. -timeout                    - Used to increase the timeout for downloading bigger assignments
                                  Default is set to 30secs
 5. -downloadOption             - Used to provide download option for the commands 'networkExecuteM5k' or 'networkExecute'
                                  Default is set to '-download'. Example -downloadOption => '-noBuild'
 6. -alignwait                  - <align timeout value>
                             	  Wait a specified time (seconds) for alignment to occur.
                                  Valid values:   positive integer > 0
                                  Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
                                  Arg example:    -alignwait => 18
 7. -reset_shelf                - <0 or 1>
                             	  Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
	                          Valid Values:   0 (don't reset) or 1 (reset)
        	                  Default Value:  1 (reset)
                	          Arg example:    -reset_shelf => 0

=item Return Values :

 - 0 configuration of MGTS using template files failed.
 - 1 configuration of MGTS using template files successful.

i=item Example :

    my @mgts_template_list = ("<template file path>/<assignment_name>.AssignM5k.template",
 		              "<template file path>/<config_name>.cfg.template ");

    my %replacement_map = ( 
        # GSX - related tokens
        'GSXMNS11IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},
        'GSXMNS12IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{2}->{IP},
        'GSXMNS21IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{3}->{IP},
        'GSXMNS22IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{4}->{IP},

        # PSX - related tokens
        'PSX0IP1'  => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{IP},
        'PSX0NAME' => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{NAME},

        # MGTS - related tokens
        'CE0SHOSTNAME' => $TESTBED{'mgts:1:ce0:hash'}->{CE}->{1}->{HOSTNAME},
        'CE1SHOSTNAME' => $TESTBED{'mgts:1:ce1:hash'}->{CE}->{1}->{HOSTNAME},
        'CE0LONGNAME' => "$TESTBED{'mgts:1:ce0:hash'}->{CE}->{1}->{HOSTNAME}",
        'CE1LONGNAME' => "$TESTBED{'mgts:1:ce1:hash'}->{CE}->{1}->{HOSTNAME}",
    );

    unless ( $mgts_object->configureMgtsFromTemplate (
                                                      -mgtsAccount                => $mgts_assignment_account,
                                                      -mgtsAssignmentTemplateList => \@mgts_template_list, 
                                                      -replacementMap  		  => \%replacement_map,
                                                      -mgtsAssignment             => $mgts_assignment,
                                                      -mgtsPath                   => "/home/mgtsuser25/datafiles",
                                                      ) {
        $logger->debug( __PACKAGE__ . "$sub : Could not Configure MGTS from Template Files." ); 
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured MGTS from Template files.");

                                    Or
    unless ( $mgts_object->configureMgtsFromTemplate (
                                                      -tarFileName                => $tarfilename,
                                                      -mgtsAssignmentTemplateList => \@mgts_template_list, 
                                                      -replacementMap  		  => \%replacement_map,
                                                      -mgtsAssignment             => $mgts_assignment,
                                                      -localDirForTarFile         => $localdir,
                                                      ) {
        $logger->debug( __PACKAGE__ . "$sub : Could not Configure MGTS from Template Files." ); 
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured MGTS from Template files.");

                                    or
    unless ( $mgts_object->configureMgtsFromTemplate (
                                                      -tarFileName                => $tarfilename,
                                                      -mgtsAssignmentTemplateList => \@mgts_template_list,
                                                      -replacementMap             => \%replacement_map,
                                                      -mgtsAssignment             => $mgts_assignment,
                                                      -localDirForTarFile         => $localdir,
						      -reset_shelf   		  => 0,
                                               	      -downloadOption 		  => '-download',
	                                              -alignwait	          => 30,	
                                                      ) {
        $logger->debug( __PACKAGE__ . "$sub : Could not Configure MGTS from Template Files." );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured MGTS from Template files.");

=back

=cut

sub configureMgtsFromTemplate {

    my ($self, %args ) = @_ ;
    my $sub = "configureMgtsFromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a = (-timeout             => 30,
             -reset_shelf         => 1,
             -downloadOption      => '-download');

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );
 
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");
    
    # Checking mandatory inputs...
    foreach ( qw / mgtsAssignmentTemplateList replacementMap mgtsAssignment / ) {
       unless ( defined ( $a{"-$_"} ) ) {
           $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
       }
    }
    
    # check align wait is a positive integer
    if (defined($a{-alignwait}) && $a{-alignwait} <= 0) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
        return 0;
    }

    unless( $a{-alignwait}) {
        if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
            $a{-alignwait} = 15;
        } else {
           $a{-alignwait} = 10;
        }
    }

    # check force disconnect arg is 0 or 1
    if (($a{-reset_shelf} < 0) || ($a{-reset_shelf} > 1)) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-reset_shelf\" must be 0 or 1");
        return 0;
    }    

    # Equate to default if not specified.
    unless ( defined $a{-mgtsPath} ) {
        $a{-mgtsPath} = $self->{MGTS_DATA};
        $logger->debug(__PACKAGE__ . ".$sub: Argument \'mgtsPath\' not specified. So by default will be taken as $self->{MGTS_DATA}");
    }
    
    my $mgts_assignment         = $a{-mgtsAssignment};
    
    # Check which mandatory input is defined -mgtsAccount or -tarFileName and do appropriate actions. 
    if ( defined $a{-mgtsAccount} ) {
        my $shelf_version = $self->{SHELF_VERSION};
        my $extension= ($shelf_version eq 'p400' or $shelf_version eq 'm500') ? '.AssignM5k' : '.assign';
       
        unless( $self->uploadFromRepository( -account        => "$a{-mgtsAccount}",
                                            -path           => "/home/$a{-mgtsAccount}/datafiles",
                                            -file_to_copy   => "${mgts_assignment}$extension",)) {
            $logger->error(__PACKAGE__ . ".$sub Could not upload $mgts_assignment from account $a{-mgtsAccount}.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    } elsif ( defined $a{-tarFileName} ) {
        $a{-mgtsPath} = $self->{MGTS_DATA};
        $logger->debug(__PACKAGE__ . ".$sub: Tar File Name is specified. So downloading it. MGTS Path will be \'$a{-mgtsPath}\'");
        unless ( defined $a{-localDirForTarFile}) {
            $logger->error(__PACKAGE__ . ".$sub Local Directory for the tar file $a{-tarFileName} not specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        unless ($self->putTarFile(       -tarFileName    => $a{-tarFileName},
                                         -localDir       => $a{-localDirForTarFile},
                                         -mgtsAssignment => $mgts_assignment,
                                         -downloadToDatafiles => 1 , )) {
            $logger->error(__PACKAGE__ . ".$sub Could not download tar file $a{-tarFileName} from $a{-localDirForTarFile}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub Neither \'-mgtsAccount\' nor \'-tarFileName\' specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    # error handler for scp  
    my $errorHandler = sub {
     $logger->error(__PACKAGE__ . ".$sub:  @_ ");
     $logger->error(__PACKAGE__ . ".$sub:  ERROR problems with the call :'scp()' ");
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
     return 0;
    };
   
    my ( @file_list, %replacement_map );
    @file_list       = @{$a{-mgtsAssignmentTemplateList}};
    %replacement_map = %{$a{-replacementMap}};

    my $file_name;
   
    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}; 
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
 
    #loop through the files list and convert them one by one.
    foreach $file_name (@file_list) {
        my ( $f, @template_file );
        unless ( open INFILE, $f = "<$file_name" ) {
             $logger->error(__PACKAGE__ . ".$sub:  Cannot open input file \'$file_name\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
             return 0;
        }

        @template_file  = <INFILE>;

        unless ( close INFILE ) {
             $logger->error(__PACKAGE__ . ".$sub:  Cannot close input file \'$file_name\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
             return 0;
        }

        # Check to see that all tokens in our input file are actually defined by the user... 
        # if so - go ahead and do the processing.
        my @tokens = SonusQA::Utils::listTokens(\@template_file);

        unless (SonusQA::Utils::validateTokens(\@tokens, \%replacement_map) == 0) {
            $logger->error(__PACKAGE__ . ".$sub:  validateTokens failed.");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        my @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);

        # Now the framework would go write @file_processed either to a new file, for sourcing
        my $out_file;
        if($file_name =~ m/(.*?)\.template/) {
           $out_file = $1;
        }

        # open out file and write the content
        $logger->debug(__PACKAGE__ . ".$sub: writing \'$out_file\'");
        unless ( open OUTFILE, $f = ">$out_file" ) {
           $logger->error(__PACKAGE__ . ".$sub:  Cannot open output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
        
        if ( $out_file =~ /(.*?)\.cfg/) {
            my $skip_slot =0;
            my ($slot_num, $file_line,$expected_slot,@remove_list,$slot_type_target, @add_list );

            foreach $file_line (@file_processed) {
                unless ( $skip_slot ) {
                if ( $file_line =~ /slot\[(\d+)\].*/ ) {
                    $slot_num = $1;
                    if ( $file_line =~ /slot\[\d+\]\.phys_int\[\d\] PPCI_(\S+)/ ) {
                        $slot_type_target = $1;
                        next;
                    }
                    if ( ( defined $slot_type_target )) {
                        if ( $slot_type_target =~ /ETHERNET/) {
                            $expected_slot = "ETHERNET";
                        } elsif ( $slot_type_target =~ /GIGE/) {
                            $expected_slot = "GIGE";
                        } else {
                            $slot_type_target = undef;
                            $skip_slot = 1;
                        }
                    }
                    if ( $file_line =~ /slot\[\d+\]\.mezzanine\.gige\.codec_microphone Carbon/ ) {
                        if ( $expected_slot =~ /GIGE/) {
                            push @remove_list, $slot_num;
                            $skip_slot = 1;
                        }
                    } elsif ( $file_line =~ /slot\[\d+\]\.mezzanine\.ethernet\.line_reset On/ ) {
                       if ( $expected_slot =~ /ETHERNET/) {
                           push @add_list, $slot_num;
                           $skip_slot = 1;
                       }
                   }
                }
                } else {
                     if ( $file_line =~ /slot\[(\d+)\].*/ ){
                          if ( $slot_num ne $1 ) {
                              $skip_slot = 0;
                              $expected_slot = "";
                              $slot_type_target = undef;
                          }
                     }
                }
            }
        
            my ($offset,@repl_array,@rem);
            foreach $slot_num ( @remove_list ) {
                $offset =0;
                foreach $file_line (@file_processed) {
                    if ( $file_line =~ /^slot\[$slot_num\].*/) {
                        if ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.gige\.mode Emulation/ ) {
                            @repl_array = ("slot[$slot_num].mezzanine.gige.mode Emulation\n" , "slot[$slot_num].mezzanine.gige.line_reset On\n");
                            @rem = splice (@file_processed, $offset , 1 , @repl_array );
                        }
                        elsif ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.gige\.port3_mode Unused/ ) {
                            @repl_array = ("slot[$slot_num].mezzanine.gige.phys_medium[0] Copper\n" , "slot[$slot_num].mezzanine.gige.phys_medium[1] Copper\n",
                                           "slot[$slot_num].mezzanine.gige.mtu[0] 1500\n","slot[$slot_num].mezzanine.gige.mtu[1] 1500\n");
                            @rem = splice (@file_processed, $offset  , 4 , @repl_array );
                        } elsif ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.gige\.ipv6_enabled\[1\] No/ ) {
                            @repl_array = ("slot[$slot_num].mezzanine.gige.ipv6_enabled[1] No\n" , "slot[$slot_num].mezzanine.gige.vlan_enabled[0] No\n",
                                    "slot[$slot_num].mezzanine.gige.vlan_enabled[1] No\n");
                            @rem = splice (@file_processed, $offset  , 1 , @repl_array );
                        }
                    }
                $offset++;
                }
            }
            
            foreach $slot_num ( @add_list ) {
                $offset =0;
                foreach $file_line (@file_processed) {
                    if ( $file_line =~ /^slot\[$slot_num\].*/) {
                        if ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.ethernet\.mode Emulation/ ) {
                            @repl_array = ("slot[$slot_num].mezzanine.ethernet.mode Emulation\n" );
                            @rem = splice (@file_processed, $offset , 2 , @repl_array );
                        }
                        elsif ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.ethernet\.port2_mode DropAndInsert/ ) {
                            @repl_array = ("slot[$slot_num].mezzanine.ethernet.port2_mode DropAndInsert\n" , "slot[$slot_num].mezzanine.ethernet.port3_mode Unused\n",
                                    "slot[$slot_num].mezzanine.ethernet.codec_law MuLaw\n","slot[$slot_num].mezzanine.ethernet.codec_microphone Carbon\n",
                                    "slot[$slot_num].mezzanine.ethernet.codec_mode DROP_INSERT\n");
                            @rem = splice (@file_processed, $offset  , 1 , @repl_array );
                        }
                        elsif ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.ethernet\.phys_medium\[0\] Copper/ ) {
                            @repl_array = ();
                            @rem = splice (@file_processed, $offset  , 4 , @repl_array );
                        } elsif ( $file_line =~ /^slot\[$slot_num\]\.mezzanine\.ethernet\.vlan_enabled\[0\] No/ ) {
                            @repl_array = ();
                            @rem = splice (@file_processed, $offset  , 2 , @repl_array );
                        }
                    }
                    $offset++;
                }
            }
        }
        
        print OUTFILE (@file_processed);

        unless ( close OUTFILE ) {
           $logger->error(__PACKAGE__ . ".$sub:  Cannot close output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
        
        $logger->debug(__PACKAGE__ . ".$sub : Transfering \'$out_file\' to MGTS \'$scpArgs{-hostip}\'");
        # Transfer File
        
        $scpArgs{-sourceFilePath} = "$out_file";
        $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$a{-mgtsPath};

	if(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->debug(__PACKAGE__ . ".$sub:  $out_file File copied to $scpArgs{-hostip}:$a{-mgtsPath}");
        }else {
            $logger->error(__PACKAGE__ . ".$sub:  ERROR in copying $out_file to $scpArgs{-hostip}:$a{-mgtsPath}");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub :  file $out_file transferred to \($scpArgs{-hostip}\) MGTS");
    }
    
    # Update PASM Db
    if ( (defined $a{-pasmDbName} ) && (defined $a{-columnValues}) ) {
        # Update PASM Db       
        unless ( $self->updatePasmDb (
                                       -pasmDbName        => $a{-pasmDbName},
                                       -columnValues      => $a{-columnValues},
                ) ) {
            $logger->debug( __PACKAGE__ . "$sub : Failed to update the desired PASM DB " ); 
            return 0;
        }
    }
        
    $logger->debug(__PACKAGE__ . ".$sub rest_shelf --> $a{-reset_shelf}");
    $logger->debug(__PACKAGE__ . ".$sub downloadoption --> $a{-downloadOption}");
    $logger->debug(__PACKAGE__ . ".$sub timeout --> $a{-timeout}");
    $logger->debug(__PACKAGE__ . ".$sub alignwait --> $a{-alignwait}");

    #Download the Assignment
    unless ($self->configureMgtsFromTar( -mgtsAssignment => $mgts_assignment,
                                         -timeout        => $a{-timeout},
                                         -reset_shelf    => $a{-reset_shelf},
                                         -downloadOption => $a{-downloadOption},
                                         -alignwait      => $a{-alignwait},
                                         -putTarFile     => 0,)) {

        $logger->debug(__PACKAGE__ . ".$sub : Error in configuring MGTS after the conversion of Template Files.");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub:  Successfully configured MGTS from Template.");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
    return 1;
}

=head2 updatePasmDb

This API Updates the values of columns of PASM DB specified by the user in the MGTS called,with the values specified by the user.

=over

=item Arguments:

=item Mandatory Arguments:

   -pasmDbName       =>       PASM DB Name of the MGTS. Expected to be present in the /home/<user>/datafiles/ directory of the MGTS.
   -columnValues     =>       A hash reference . The hash will have the keys as the column names of the DB and
                              the values will be array of values to be updated in the rows(value) of the specific
                              column key in the Pasm DB.
                              If there are more number of value rows than specified by the user, then the last value passed
                              by the user in the array will be repeated for the remaining value rows.
                              For Example : If a column named STP1_IP1 has 5 value rows and only 2 values are passed by user ,
                              then the first 2 rows will get the corresponding values from the array and then the second value will
                              be repeated for the remaining 3 row values of that column.

=item Returns:

    * 1, Success
    * 0, otherwise

=item Examples:

    my %columnvalues = (
                          "STP1_IP1"  => [ "12.34.56.78" ] ,
                          "CIC"       => ["2"],
                          "PL9"       => [ "9*****" , "8*****" , "7*****" ],
    );

    unless ( $MgtsObj->updatePasmDb (
                      -pasmDbName        => "ISUP-test.pdb",
                      -columnValues      => \%columnvalues,
                  ) ) {
        $logger->debug( __PACKAGE__ . "$sub : Failed to update the desired PASM DB " ); 
        return 0;
    }

=back

=cut

sub updatePasmDb {
    my ( $self , %args ) = @_;
    
    my $sub = "updatePasmDb()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a   = ( );

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );
 
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");
    
    # Checking mandatory inputs...
    foreach ( qw / pasmDbName columnValues / ) {
       unless ( defined ( $a{"-$_"} ) ) {
           $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
       }
    }
    
    my %col = %{$a{-columnValues}};
    $logger->debug(__PACKAGE__ . ".$sub: Pasm DB Name : $a{-pasmDbName} \n ");
    
    # check whether the DB name exists or not.by getting into the Datafiles directory.
    unless ( $self->{conn}->cmd("cd datafiles")){
        $logger->error(__PACKAGE__ . ".$sub:  Could not change the directory to /datafiles ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my @output = $self->{conn}->cmd("ls | grep $a{-pasmDbName} ");
    unless ( @output ) {
        $logger->error(__PACKAGE__ . ".$sub : Specified PASM DB not present in the /datafiles Directory of MGTS \n");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $scpError = 0;
    # error handler for scp  
    my $errorHandler = sub {
     $logger->error(__PACKAGE__ . ".$sub:  @_ ");
     $logger->error(__PACKAGE__ . ".$sub:  ERROR problems with the call :'scp()' ");
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
     $scpError = 1;
     return 0;
    };
    my $mgtsDataDir = $self->{MGTS_DATA};
    `touch $a{-pasmDbName}`;
    
    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$mgtsDataDir/$a{-pasmDbName}";
    $scpArgs{-destinationFilePath} = $a{-pasmDbName};

    if(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->debug(__PACKAGE__ . ".$sub:  $a{-pasmDbName} Copied from MGTS $scpArgs{-hostip} ");
    }
    
    open FILE , "<$a{-pasmDbName}";
    my @file = <FILE>;
    my ( $line , $found , $colPresent , $replaced ) ;
    $replaced =0;
    $colPresent = 0;
    $found =0;
    while (my ($key , $value) = each %col ) {
        my @values = @{$value};
        my $num = scalar (@values);
        my $count =0;
        foreach $line ( @file ) {
            if ( $line =~ /COLUMN=$key\s+/){
                $replaced = 0;
                $found = 1;
                next;
            }
            if ( $found && ( $line =~ /VALUE=/ ) ) {
                my $val = $values[$count];
                $line =~ s/VALUE=.*/VALUE=$val/;
                unless ( ( $count + 1 ) == $num ){
                    $count++;
                }
                $replaced = 1;
                next;
            }
            if ( (  $line =~ /COLUMN=/  ) && $found ) {
                $logger->debug(__PACKAGE__ . ".$sub: Column $key was found in $a{-pasmDbName} and Updated with Values:  @values  ");
                $found = 0;
                $colPresent = 1;
                $replaced = 0;
                last;
            }
        }
        if ( $replaced ) {
            $logger->debug(__PACKAGE__ . ".$sub: The Column $key was found in $a{-pasmDbName} and Updated with Values:  @values  ");
            $colPresent = 1;
        }
        unless ( $colPresent ) {
           $logger->error(__PACKAGE__ . ".$sub: WARN : Column $key was NOT found in $a{-pasmDbName} . ");
        }
        $colPresent = 0;
        $replaced = 0;
    }
    close FILE;
    
    open FILE ,">$a{-pasmDbName}";
    print FILE (@file);
    close FILE;

    $scpArgs{-sourceFilePath} = $a{-pasmDbName};
    $scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:$mgtsDataDir/$a{-pasmDbName}";
    
    if(&SonusQA::Base::secureCopy(%scpArgs)){ 
            $logger->debug(__PACKAGE__ . ".$sub:  $a{-pasmDbName} Copied to MGTS $scpArgs{-hostip} /datafiles Directory ");
    }
    
    #delete the Copied and modified file present in the local Directory.
    `rm $a{-pasmDbName}`;
    $logger->debug(__PACKAGE__ . ".$sub:  Successfully Updated the PASM DB $a{-pasmDbName} ");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
    return 1;
}

=head2 configureMTPLinks

    This API Activates/Deactivates the MTP Links from the MGTS side.

=over

=item Arguments :

   Mandatory : -assignment => Assignment
               -action     => "Activate" or  "Deactivate" or "Align"

   Optional  : -linkName   => Link name
               -nodeName   => Node name

=item Return Values :

   0 - Failed
   1 - Success

=item Example :

   my $status = $mgts_object1->configureMTPLinks(-shelf => "mgts-M500-1", -assignment => "JAPAN_MTP2_REDUNDANCY_SEP1", -action => "Deactivate", -linkName  => "11-1-1-1");
   my $status = $mgts_object1->configureMTPLinks(-shelf => "mgts-M500-1", -assignment => "JAPAN_MTP2_REDUNDANCY_SEP1", -action => "Activate", -linkName  => "11-1-1-1");
   my $status = $mgts_object1->configureMTPLinks(-shelf => "mgts-M500-1", -assignment => "JAPAN_MTP2_REDUNDANCY_SEP1", -action => "Align", -linkName  => "11-1-1-1");

=item Author :
Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub configureMTPLinks{

    my ($self,%args) = @_;
    my $sub = "configureMTPLinks()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a = ();

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->info(__PACKAGE__ . ".$sub  Args - ", Dumper(%args));

    # Checking for mandatory parameter
    foreach (qw(shelf assignment action)) {
        unless (defined "$a{-$_}") {
            $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

    # Construct the command based on -linkname and -nodeName
    # commandLine <shelfname>+<AssignmentName> Deactivate link: link=4-1-1 :Node=
    #                        OR
    # commandLine <shelfname>+<AssignmentName> Deactivate link: link= :Node=SSP1
    my $cmd;
    if (defined $a{-linkName}) {
        $cmd = 'commandLine ' . "$a{-shelf}" . '+' . "$a{-assignment}" . " $a{-action}" . " link: link=$a{-linkName}" . ' :Node=';
    } elsif (defined $a{-nodeName}) {
        $cmd = 'commandLine ' . "$a{-shelf}" . '+' . "$a{-assignment}" . " $a{-action}" . " link: link=" . " :Node=$a{-nodeName}";
    } else {
        $logger->error(__PACKAGE__ . ".$sub:  Either one of the optional parameter -linkName/-nodeName should be passed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Command to be executed --> $cmd");

    unless($self->cmd(-cmd => $cmd)) {
        $logger->debug(__PACKAGE__ . ".$sub: $a{-action} MTP links is successful");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    } else {
        $logger->error(__PACKAGE__ . ".$sub:  $a{-action} MTP links is failed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
}

1;
