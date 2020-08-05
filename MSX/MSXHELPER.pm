package SonusQA::MSX::MSXHELPER;

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use POSIX;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;

use vars qw( $VERSION );
our $VERSION = "1.00";

=head1

#########################################################################################################
# NAME
#
# SonusQA::MSX::MSXHELPER - Perl module for MSX interaction
#
# DESCRIPTION
#	This MSXHELPER package contains various subroutines that assists with MSX related interactions.
#	Subroutines are defined to provide Value add to the test execution in terms of verification and validation.
#
#	Currently this package includes the following subroutines:
#
#	sub getProcessfromMsxApplList()
#       sub sortProcessesforStartup()
#       sub checkHangingCallLegsinCCSW()
#       sub restartProcesses()
#       sub checkRequiredMsxProcessesRunning()
#       sub makeRequiredMsxApplProcessRunning()
#       sub validateConsoleCommand()
#       sub checkConsoleCommand()
#       sub ProcessConsoleCommand()
#       sub parseConsoleCmdResults()
#       sub parseCICStatCmdResults()
#
# AUTHORS
#   See Inline documentation for contributors.
#
# REQUIRES
#
# Perl5.8.6, Log::Log4perl, SonusQA::Utils, Net::SCP::Expect
#
#########################################################################################################              

=cut

=head1 COPYRIGHT

                              Sonus Networks, Inc.
                         Confidential and Proprietary.

                     Copyright (c) 2010 Sonus Networks
                              All Rights Reserved
Use of copyright notice does not imply publication.
This document contains Confidential Information Trade Secrets, or both which
are the property of Sonus Networks. This document and the information it
contains may not be used disseminated or otherwise disclosed without prior
written consent of Sonus Networks.

=head1 DATE

2010-07-04

=cut

#########################################################################################################              

#########################################################################################################

=head1 getProcessfromMsxApplList()

DESCRIPTION:

 The function is used to specific process(s) from list
 i.e. ccsw/advlr/pcmgr/ss7mh/ipmh/cdrcp - process type

ARGUMENTS:

1. The Application process type (ccsw/advlr/pcmgr/ss7mh/ipmh/cdrcp)
2. list of application process(s) to be sorted - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 list containing - Result / function return value
 1 - success
 0 - failure

 and
 @appList - containing sorted list of process(s)


EXAMPLE:

   # get the list of ccsw process(s)
    my ($result, @list);
    ($result, @list) = $MsxObj->getProcessfromMsxApplList('ccsw', \@MsxApplList);
    unless ( $result ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "getProcessfromMsxApplList() - Failed";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: list of CCSW(s) found:--\n@list");

    # OR

    # get the list of ccsw process(s)
    my ($result, $ccsw01, $ccsw02);
    ($result, $ccsw01, $ccsw02) = $MsxObj->getProcessfromMsxApplList('ccsw', \@MsxApplList);
    unless ( $result ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "getProcessfromMsxApplList() - Failed";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: list of CCSW(s) found $ccsw01 $ccsw02");

=cut

#################################################
sub getProcessfromMsxApplList {
#################################################
    my ($self, $processType, $msxApplList) = @_;
    my $subName = 'getProcessfromMsxApplList()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL
    my @processList;
    unless ( defined($processType) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX process type specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    unless ( defined($msxApplList) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX application list reference specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    foreach (@$msxApplList) {
        unless (/$processType/i) {
            next;
        }

        push ( @processList, $_ );
    }

    if ( @processList ) {
        $result = 1; # PASS
    }

    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return ($result, @processList);
}


#########################################################################################################

=head1 sortProcessesforStartup()

DESCRIPTION:

 The function is used to sort the list of application process(s) in the order of startup sequence.
 i.e. order of sorting is CCSW ADVLR TEST PCMGR SS7MH IPMH CDRCP processes

ARGUMENTS:

1. list of application process(s) to be sorted - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - success
 0 - failure

 @appList - containing sorted list of process(s)

EXAMPLE:

    # sort the process inthe order for startup sequence.
    my  ($sortResult, @appList) = $self->sortProcessesforStartup(\@{$args{'-applications'}});

    unless ( $sortResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  sortProcessesforStartup() FAILED");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

=cut

#################################################
# sortProcessesforStartup()
#################################################
sub sortProcessesforStartup {
    my ($self, $processList) = @_;
    my $subName = 'sortProcessesforStartup()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my @sorted = ();
    my $completeFlag = 0;
    unless ( defined($processList) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX process list specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $completeFlag;
    }
    my @input  = @{$processList};

    # Order in which the process has to be sorted for startup.
    my @order = qw(CCSW ADVLR TEST PCMGR SS7MH IPMH CDRCP);

    foreach my $sort (@order) {
        foreach (@input) {
            if(/$sort/) {
                push ( @sorted, $_ );
            }
        }

        if ($#input == $#sorted) {
            # sort complete
            $completeFlag = 1;
            last;
        }
    }

    unless ($completeFlag) {
        foreach my $process (@input) {
            my $found = 0;
            foreach (@order) {
                if($process =~ /$_/) {
                    $found = 1;
                    next;
                }
            }

            unless ($found) {
                push ( @sorted, $process );
            }
        
            if ($#input == $#sorted) {
                # sort complete
                $completeFlag = 1;
                last;
            }
        }
    }

    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$completeFlag]");
    return ($completeFlag, @sorted);
}


#########################################################################################################

=head1 checkHangingCallLegsinCCSW()

DESCRIPTION:

 The function is used to check list of Call Control Switch (CCSW) application process(s) for any hanging call leg(s).
 Uses the console command "protostat ALL" on CCSW application process, if number of rows received is '0' (zero), then we have no hanging call legs, else the list of CCSW application process is returned with FAILURE.

ARGUMENTS:

1. list of Call Control Switch (CCSW) application process(s) - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 execConsoleCmd()

OUTPUT:
 
 1 - success - Hanging call legs found in Call Control Switch (CCSW)
 0 - failure - No hanging call legs found in Call Control Switch (CCSW)

 \@ccswList - containing Call Control Switch (CCSW) list reference, having hanging Call Leg(s)

EXAMPLE:

    # Check for any hanging call leg(s)
    my ( $result, $ccswList ) = $MsxObj->checkHangingCallLegsinCCSW( \@ccsw );
    unless ( $result ) {
        if ( defined($ccswList) ) {
            $TESTSUITE->{$TestId}->{METADATA} .= "we have hanging call leg(s) in:--\n@{$ccswList}";
            $MsxObj->restartProcesses( $ccswList );
        }
        else {
            $TESTSUITE->{$TestId}->{METADATA} .= "checkHangingCallLegsinCCSW() - Failed";
        }
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  No hanging call leg(s) found.");

=cut

#################################################
# checkHangingCallLegsinCCSW()
#################################################
sub checkHangingCallLegsinCCSW {
    my ($self, $processList) = @_;
    my $subName = 'checkHangingCallLegsinCCSW()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL
    my ( @failedCcswList, @passedCcswList );

    unless ( defined($processList) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX CCSW(s) specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    # Execute console command(s).
    my $cmd = 'mode ccsw';
    unless ( $self->execConsoleCmd ( 
                        -cmd     => $cmd,
                        -timeout => $self->{DEFAULTTIMEOUT},
                    ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
    #$logger->debug(__PACKAGE__ . ".$subName:  CONSOLE command \'$cmd\' result:--\n@{ $self->{CMDRESULTS}}");

    foreach my $ccsw (@$processList) {
        unless (/ccsw/i) {
            next;
        }
        my @consoleCmdList = (
            "connect $ccsw",
            "protostat ALL",
        );

        foreach my $cmd (@consoleCmdList) {
            unless ( $self->execConsoleCmd ( 
                            -cmd     => $cmd,
                            -timeout => $self->{DEFAULTTIMEOUT},
                        ) ) {
                $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                return $result;
            }
            $logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");

            if ( $cmd =~ /protostat/ ) {
                my $rowsReceived;
                foreach ( @{$self->{CMDRESULTS}} ) {
                    if ( /(\d+)\s+rows received\s+/ ) {
                        $rowsReceived = $1;
                    }
                }

                if ( $rowsReceived == 0 ) {
                    $logger->debug(__PACKAGE__ . ".$subName:  SUCCESS for ccsw($ccsw), NO hanging call leg(s) found - $rowsReceived");
                    push (@passedCcswList, $ccsw);
                }
                else {
                    $logger->debug(__PACKAGE__ . ".$subName:  FAILED for ccsw($ccsw), has hanging call leg(s) - $rowsReceived");
                    push (@failedCcswList, $ccsw);
                }
            }
        }

    }


    my $ccswList;
    if ( @failedCcswList ) {
        $ccswList = \@failedCcswList;
        $logger->debug(__PACKAGE__ . ".$subName:  FAILED ccsw(s) \'@failedCcswList\'");
    }
    else {
        $ccswList = \@passedCcswList;
        $logger->debug(__PACKAGE__ . ".$subName:  PASSED ccsw(s) \'@passedCcswList\'");
        $result = 1; # PASS
    }
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return ($result, $ccswList);
}

#########################################################################################################

=head1 restartProcesses()

DESCRIPTION:

 The function is used to "STOP" & "START" list of Call Control Switch (CCSW) application process(s) for any hanging call leg(s).

ARGUMENTS:

1. list of Call Control Switch (CCSW) application process(s) - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 execConsoleCmd()

OUTPUT:
 
 1 - success - Restarting of Call Control Switch (CCSW) applications process successful
 0 - failure - Restarting of Call Control Switch (CCSW) applications process Failed


EXAMPLE:

    unless ( $MsxObj->restartProcesses( $ccswList ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "restartProcesses() Failed, when trying to clear hanging call legs in CCSW(s):--\n@{$ccswList}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  restartProcesses() Success, hanging call leg(s) cleared.");

=cut

#################################################
# restartProcesses()
#################################################
sub restartProcesses {
    my ($self, $processList) = @_;
    my $subName = 'restartProcesses()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my ( @failedCcswList, @passedCcswList );

    unless ( defined($processList) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX process list specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    # Execute console command(s).
    my $cmd = 'mode console';
    unless ( $self->execConsoleCmd ( 
                        -cmd     => $cmd,
                        -timeout => $self->{DEFAULTTIMEOUT},
                    ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
    #$logger->debug(__PACKAGE__ . ".$subName:  CONSOLE command \'$cmd\' result:--\n@{ $self->{CMDRESULTS}}");

    foreach (@$processList) {
        my @consoleCmdList = (
            "stop $_",
            "start $_",
        );

        foreach my $cmd (@consoleCmdList) {
            unless ( $self->execConsoleCmd ( 
                            -cmd     => $cmd,
                            -timeout => $self->{DEFAULTTIMEOUT},
                        ) ) {
                $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");

            # sleep between STOP & START of application process
            sleep $self->{DEFAULTTIMEOUT};
        }
    }


    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}


#########################################################################################################

=head1 checkRequiredMsxProcessesRunning()

DESCRIPTION:

 The function is used to check required application process(s) for executing the test suite are in RUNNING state.
 It uses the console command 'showprocs all' to get the application process(s) list.

ARGUMENTS:

1. list of application process(s) required in RUNNING state - Hash Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 enterConsoleSession()
 execConsoleCmd()
 parseConsoleCmdResults()
 leaveConsoleSession()

OUTPUT:
 
 1 - success
 0 - failure

 on SUCCESS returns the list of application process(s) in RUNNING state - Array Reference


EXAMPLE:

    my %REQUIREDMSXPROCESSES = (
        CCSW  => { ACTIVE => 1, BACKUP => 0 },
        ADVLR => { ACTIVE => 1, BACKUP => 0 },
        PCMGR => { ACTIVE => 1, BACKUP => 0 },
        SS7MH => { ACTIVE => 1, BACKUP => 0 },
    # Process(s) not used in this feature
    #    IPMH  => { ACTIVE => 1, BACKUP => 0 },
    #    CDRCP => { ACTIVE => 1, BACKUP => 0 },
    );

    # Check required MSX processes are in RUNNING state
    my ($result, $appList) = $MsxObj->checkRequiredMsxProcessesRunning( \%REQUIREDMSXPROCESSES );
    unless ( $result ) {
        $logger->error(__PACKAGE__ . " ======: Could not find required Msx processes in RUNNING state"); 
        return 0;
    }
    $logger->debug(__PACKAGE__ . " ======: Could find required Msx processes in RUNNING state:--\n@{$appList}");

=cut

#################################################
# checkRequiredMsxProcessesRunning()
#################################################
sub checkRequiredMsxProcessesRunning {
    my ($self, $hrefRequiredProcesses) = @_;
    my $subName = 'checkRequiredMsxProcessesRunning()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined($hrefRequiredProcesses) ) {
        $logger->error(__PACKAGE__ . ".$subName:  No MSX process(s) specified." );
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    my $result = 0; # FAIL

    # enter CONSOLE session
    my ( $ConsoleUserId, $ConsolePassword );
    $ConsoleUserId   = $self->{TMS_ALIAS_DATA}->{CONSOLE}->{1}->{USERID};
    $ConsolePassword = $self->{TMS_ALIAS_DATA}->{CONSOLE}->{1}->{PASSWD};

    unless ( $self->enterConsoleSession ( 
                                     '-login'    => $ConsoleUserId,
                                     '-password' => $ConsolePassword,
                                ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Could not enter console session user \'$ConsoleUserId\', password \'$ConsolePassword\':--\n@{ $self->{CMDRESULTS}}");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
        return $result;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Entered console session via admin, using user \'$ConsoleUserId\', password TMS_ALIAS->CONSOLE->1->PASSWD.");

    # Execute console command.
    my $cmd = 'showprocs all';
    unless ( $self->execConsoleCmd ( 
                        -cmd     => $cmd,
                        -timeout => $self->{DEFAULTTIMEOUT},
                    ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }
    #$logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
    #$logger->debug(__PACKAGE__ . ".$subName:  CONSOLE command \'$cmd\' result:--\n@{ $self->{CMDRESULTS}}");

    my @cmdResults;
    push ( @cmdResults, @{$self->{CMDRESULTS}} );

    # Parse the console command response
    my  ($parseResult, $AOHrefData) = $self->parseConsoleCmdResults(\@cmdResults);

    unless ( $parseResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  Parsing of CONSOLE command \'$cmd\' FAILED:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    my @AOH_Data = @{$AOHrefData};

    my $errorFlag = 0;
    my $processTypeFoundFlag = 0;
    my ( @appList, @stopAppList );
    my @requiredProcType = keys(%$hrefRequiredProcesses);

    while ( my ($procType, $hrefAB) = each %$hrefRequiredProcesses ) {
        my $processType = uc($procType);
        $processTypeFoundFlag = 0;

        while ( my ($ab, $requiredProcesses) = each %$hrefAB) {
            my $ActiveBackup = uc($ab);
            my $count = 0;

            unless ($requiredProcesses == 0) {
                foreach ( @AOH_Data ) {
                    my $AppName = 'AppName';
                    my $State   = 'State';
                    my $ActBkp  = 'A-B';
               
                    if ( ( $_->{$AppName} =~ /$processType/ ) &&
                         ( $requiredProcesses != $count ) ) {
                        $processTypeFoundFlag = 1;
                        if ( $_->{$State} =~ /RUNNING/ ) {
                            if ( $ActiveBackup eq 'ACTIVE' ) {
                                unless ( $_->{$ActBkp} eq 'A' ) {
                                    # Warn the user that the process is active on BACKUP
                                    $logger->warn(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, expected to be $ActiveBackup on \'A\' but received \'$_->{$ActBkp}\'");
                                }
                                else {
                                    $logger->warn(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, expected to be $ActiveBackup on \'A\' but received \'$_->{$ActBkp}\' PASS");
                                }
                                $count++;

                                if ( $count <= $requiredProcesses ) {
                                    push (@appList, $_->{$AppName});
                                }
                            }
                            elsif ( $ActiveBackup eq 'BACKUP' ) {
                                unless ( $_->{$ActBkp} eq 'B' ) {
                                    # Warn the user that the process is active on BACKUP
                                    $logger->warn(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, expected to be $ActiveBackup on \'B\' but received \'$_->{$ActBkp}\'");
                                }
                                else {
                                    $logger->warn(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, expected to be $ActiveBackup on \'B\' but received \'$_->{$ActBkp}\' PASS");
                                }
                                $count++;
    
                                if ( $count <= $requiredProcesses ) {
                                    push (@appList, $_->{$AppName});
                                }
                            }
                        }
                        else {
                            $logger->debug(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, expected to be \'RUNNING\'");
                        }
                    }
                    elsif ( ( $_->{$AppName} =~ /$processType/ ) &&
                            ( $requiredProcesses < $count ) ) {
                        if ( $_->{$State} =~ /RUNNING/ ) {
                            # list of process to be STOPPED
                            push (@stopAppList, $_->{$AppName});
                        }
                    }
                    elsif ( $_->{$State} =~ /RUNNING/ ) {
                        my $rec = $_;
                        my $found = 0;
                        foreach (@requiredProcType) {
                            if ( $rec->{$AppName} =~ /$_/i ) {
                                $found = 1;
                            }
                        }
                        unless ( $found ) {
                            # list of process to be STOPPED
                            push (@stopAppList, $_->{$AppName});
                        }
                    }
                }
                unless ( $processTypeFoundFlag ) {
                    # invalid key
                    $logger->debug(__PACKAGE__ . ".$subName:  for INVALID \'$processType\' used - FAILED");
                    last;
                }

                unless ( $requiredProcesses == $count ) {
                    $logger->debug(__PACKAGE__ . ".$subName:  for \'$processType\', $ActiveBackup - required process(s) \($requiredProcesses\) but found only $count:--\n@appList");
                    $errorFlag = 1;
                }
                $logger->debug(__PACKAGE__ . ".$subName:  for \'$processType\', $ActiveBackup - required process(s) \($requiredProcesses\) found:--\n@appList");
            }
        }

        if ( ($processTypeFoundFlag == 0) ||
             ($errorFlag == 1) ) {
        }
    }

    if ( ($processTypeFoundFlag == 1) &&
         ($errorFlag == 0) ) {
        $result = 1;
    }

    if (@stopAppList) {
        # remove duplicate enteries in the list
        my %hash = map { $_ => 1 } @stopAppList;
        my @list = keys %hash;
        $logger->warn(__PACKAGE__ . ".$subName:  ******************************************************");
        $logger->warn(__PACKAGE__ . ".$subName:  Process(s) not in MSX required list, being stopped are:--\n@list");
        $logger->warn(__PACKAGE__ . ".$subName:  ******************************************************");

        # stop the processes which are not required.
        foreach (@list) {
            my $cmd = "stop $_";
            unless ( $self->execConsoleCmd ( 
                            -cmd     => $cmd,
                            -timeout => $self->{DEFAULTTIMEOUT},
                        ) ) {
                $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");

            # sleep between STOP application process
            # do we really need this ????
            sleep $self->{DEFAULTTIMEOUT};
        }
    }

    # Leave Console session
    unless ( $self->leaveConsoleSession() ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot leave console session.");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
        return $result;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  left console session.");

    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");

    unless ($result) {
        return $result;
    }
    return ($result, \@appList);
}

#########################################################################################################

=head1 makeRequiredMsxApplProcessRunning()

DESCRIPTION:

 The function is used to check required application process(s) for executing the test case are in RUNNING state,
 else try to start the process(s). The order of process startup is considered to bring the process to RUNNING state.
 The function retries (default 3 times) to bring the process(s) to RUNNING state, else returns FAILURE.

ARGUMENTS:

Mandatory:-
1. list of application process(s) required in RUNNING state - Array Reference

Optional:-
1. Retry      - number of retries to get the process to Running state
              - default - 3
2. Sleep Time - Sleep time between the process retries
              - default 30 seconds
3. Timeout    - used for execution of console commands
              - default 10 seconds

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 sortProcessesforStartup()
 enterConsoleSession()
 execConsoleCmd()
 parseConsoleCmdResults()
 getProcessfromMsxApplList()
 leaveConsoleSession()

OUTPUT:
 
 1 - success
 0 - failure


EXAMPLE:

    unless ( $MsxObj->makeRequiredMsxApplProcessRunning(
                                                        '-applications' => \@MsxApplList,
                                                        '-timeout'      => 20, # Optional
                                                        '-retry'        => 3,  # Optional
                                                        '-sleeptime'    => 30, # Optional
                                                       ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Cannot have required MSX applications in RUNNING state.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot have required MSX applications in RUNNING state.");
        return 0;
    }

=cut

#################################################
# makeRequiredMsxApplProcessRunning()
#################################################
sub makeRequiredMsxApplProcessRunning {
    my ($self, %args) = @_;
    my $subName = 'makeRequiredMsxApplProcessRunning()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL
    # Check Mandatory Parameters
    foreach ( 'applications' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return $result;
        }
    }

    # sort the process inthe order for startup sequence.
    my  ($sortResult, @appList) = $self->sortProcessesforStartup(\@{$args{'-applications'}});

    unless ( $sortResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  sortProcessesforStartup() FAILED");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    my %a = (
        -retry     => 3,
        -sleeptime => 30,
        -timeout   => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    # enter CONSOLE session
    my ( $ConsoleUserId, $ConsolePassword );
    $ConsoleUserId   = $self->{TMS_ALIAS_DATA}->{CONSOLE}->{1}->{USERID};
    $ConsolePassword = $self->{TMS_ALIAS_DATA}->{CONSOLE}->{1}->{PASSWD};

    unless ( $self->enterConsoleSession ( 
                                     '-login'    => $ConsoleUserId,
                                     '-password' => $ConsolePassword,
                                ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Could not enter console session user \'$ConsoleUserId\', password \'$ConsolePassword\':--\n@{ $self->{CMDRESULTS}}");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
        return $result;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Entered console session via admin, using user \'$ConsoleUserId\', password TMS_ALIAS->CONSOLE->1->PASSWD.");


    my $applFoundFlag = 0;
    my $errorFlag     = 0;
    for ( my $loopCount = 1; $loopCount <= $a{'-retry'}; $loopCount++ ){

        $logger->debug(__PACKAGE__ . ".$subName:  LOOP $loopCount - Execution START");

        # Execute console command.
        my $cmd = 'showprocs all';
        unless ( $self->execConsoleCmd ( 
                        -cmd     => $cmd,
                        -timeout => $self->{DEFAULTTIMEOUT},
                    ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{$self->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return $result;
        }
        #$logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
        #$logger->debug(__PACKAGE__ . ".$subName:  CONSOLE command \'$cmd\' result:--\n@{ $self->{CMDRESULTS}}");

        my @cmdResults;
        push ( @cmdResults, @{$self->{CMDRESULTS}} );

        # Parse the console command response
        my  ($parseResult, $AOHrefData) = $self->parseConsoleCmdResults(\@cmdResults);

        unless ( $parseResult ) {
            $logger->error(__PACKAGE__ . ".$subName:  Parsing of CONSOLE command \'$cmd\' results FAILED:--\n@{$self->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return $result;
        }

        my @AOH_Data = @{$AOHrefData};

        my $applCountRunningState = 0;
        foreach my $applName ( @appList ) {
            $applFoundFlag = 0;

            foreach ( @AOH_Data ) {
                my $AppName = 'AppName';
                my $State   = 'State';
               
                if ( $_->{$AppName} eq $applName ) {
                    $applFoundFlag = 1;

                    if ( $_->{$State} =~ /RUNNING/ ) {
                        $logger->debug(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}");
                        $applCountRunningState++;
                        next;
                    }
                    elsif ( ( $_->{$State} =~ /KILLED/ ) ||
                            ( $_->{$State} =~ /DEAD_ON_START/ ) ||
                            ( $_->{$State} =~ /STOPPED/ ) ) {
                        # Restart the process
                        $logger->debug(__PACKAGE__ . ".$subName:  $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, So restarting the process.");
                        
                        my @cmdList;
                        my $cmd;
                        if ( $_->{$AppName} =~ /PCMGR/ ) {
                            # May be the SS7MH is up & running before the PCMGR is up.
                            # - STOP all the SS7MH processes
                            # - START the PCMGR process
                            # - START all the SS7MH processes
                            my ($retVal, @list) = $self->getProcessfromMsxApplList('ss7mh', \@appList);
                            unless ( $retVal ) {
                                $errorFlag = 1;
                                last;
                            }
                            $logger->debug(__PACKAGE__ . ".$subName: list of SS7MH processes found:--\n@list");

                            my (@stopCmdList, @startCmdList);
                            foreach (@list) {
                                $cmd = "stop $_";
                                push (@stopCmdList, $cmd);
                                my $cmd = "start $_";
                                push (@startCmdList, $cmd);
                            }

                            push (@cmdList, @stopCmdList);
                            $cmd = "start $_->{$AppName}";
                            push (@cmdList, $cmd);
                            push (@cmdList, @startCmdList);
                        }
                        else {
                            # Restart the process
                            $cmd = "start $_->{$AppName}";
                            push (@cmdList, $cmd);
                        }

                        foreach (@cmdList) {
                            my $cmd = $_;
                            unless ( $self->execConsoleCmd ( 
                                            -cmd     => $cmd,
                                            -timeout => 10,
                                        ) ) {
                                $logger->error(__PACKAGE__ . "$subName:  Cannot execute CONSOLE command \'$cmd\':--\n@{ $self->{CMDRESULTS}}");
                                $errorFlag = 1;
                                last;
                            }
                            $logger->debug(__PACKAGE__ . "$subName:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
                        }
                    }
                    elsif ( $_->{$State} =~ /PROV_FAILED/ ) {
                        # May be DB error, the process cannot be restarted
                        $logger->debug(__PACKAGE__ . ".$subName:  FAILED - $AppName process \'$_->{$AppName}\' is in $State $_->{$State}, may be DB error.");

                        $errorFlag = 1;
                        last;
                    }
                }
            } # FOREACH - cmd result (Data) - END

            unless ( $applFoundFlag ) {
                # invalid key
                $logger->debug(__PACKAGE__ . ".$subName:  for INVALID \'$applName\' used - FAILED");
                $errorFlag = 1;
                last;
            }

        } # FOREACH - Application list - END

        if ( ($applFoundFlag == 0) ||
             ($errorFlag == 1) ) {
            last;
        }

        if ( $applCountRunningState == ($#appList + 1) ) {
            $logger->debug(__PACKAGE__ . ".$subName:  All MSX Applications($applCountRunningState) required are in RUNNING state.");
            last;
        }

        sleep $a{'-sleeptime'};
    } # FOR loop - END

    # Leave Console session
    unless ( $self->leaveConsoleSession() ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot leave console session.");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
        return $result;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  left console session.");

    if ( ($applFoundFlag == 1) &&
         ($errorFlag == 0) ) {
        $result = 1;
    }

    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}


#########################################################################################################

=head1 validateConsoleCommand()

DESCRIPTION:

 This function is a wrapper to ProcessConsoleCommand().

 The function is used to execute any console command and validate the response against 2 column attributes and return Success if all the key/value attribute(s) matches in console command response. On Failure it return the hash containing the key column attribute and respective response value, based on which the corrective action can be taken.
 
ARGUMENTS:

Mandatory:-
1. '-cmd'        - console command to execute
2. '-keyColName' - Reference Column Name i.e. header column name in command response
                   used as KEY attribute.
3. '-valcolname' - Value column name i.e. header column name in command response
                   used as VALUE attribute.
4. '-validate'   - hash reference i.e. hash containing the KEY/VALUE to be verified
                   example: application processes and their respective states.

Optional:-
1. Timeout    - used for execution of console commands
              - default 10 seconds

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 ProcessConsoleCommand()

OUTPUT:
 
 1 - success
 0 - failure

  returns Hash Reference - hash containing the key column attribute and respective response value

EXAMPLE:

    my %validate   = ( # Process(s) to validate
                       # State
                         CDRCP01 => 'RUNNING',
                         ADVLR01 => 'RUNNING',
                         SS7MH01 => 'RUNNING',
                     );
    
    my ($result, $href_processStates) = $MsxObj->validateConsoleCommand (
                                          '-cmd'        => 'showprocs all',
                                          '-keyColName' => 'AppName',  # Reference Column Name
                                          '-valColName' => 'State',    # Value Column Name
                                          '-validate'   => \%validate,
                                          '-timeout'    => 20,         # optional argument
                                        );

    unless ($result) {
        $logger->debug(__PACKAGE__ . ".$TestId:  validateConsoleCommand() - FAILED");

        if (defined $href_processStates) {
            while ( my ($process, $state) = each %{$href_processStates} ) {
                $logger->debug(__PACKAGE__ . ".$TestId:  Failed for process $process - current state \'$state\'");
            }
        }

        # Take corrective action based on REFERENCE(s) ...
#        ...
#        ...
#        return $resultHash{RESULT};

        # OR

        # Fail the testcase
        $TESTSUITE->{$TestId}->{METADATA} .= "validation FAILED for Process(s)";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return $result;
    }

    $logger->debug(__PACKAGE__ . ".$TestId:  validateConsoleCommand() - SUCCESS");

=cut

#################################################
# validateProcessStates()
#################################################
sub validateConsoleCommand {
    my ($self, %args)   = @_;
    return ( $self->ProcessConsoleCommand(
                        '-subName'    => 'validateConsoleCommand()',
                        %args) );
}

#########################################################################################################

=head1 checkConsoleCommand()

DESCRIPTION:

 This function is a wrapper to ProcessConsoleCommand().

 The function is used to execute any console command and validate the response against 2 column attributes and return Success if all the key/value attribute(s) matches in console command response. On Failure it return the array containing the key column attribute, based on which the corrective action can be taken.
 
ARGUMENTS:

Mandatory:-
1. '-cmd'        - console command to execute
2. '-keyColName' - Reference Column Name i.e. header column name in command response
                   used as KEY attribute.
3. '-valcolname' - Value column name i.e. header column name in command response
                   used as VALUE attribute.
4. '-validate'   - hash reference i.e. hash containing the KEY/VALUE to be verified
                   example: application processes and their respective states.

Optional:-
1. Timeout    - used for execution of console commands
              - default 10 seconds

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 ProcessConsoleCommand()

OUTPUT:
 
 1 - success
 0 - failure

 returns Array Reference - array containing the key column attribute


EXAMPLE:

   %validate   = ( # Process(s) to validate
                   # State
                     CDRCP01 => 'RUNNING',
                     ADVLR01 => 'RUNNING',
                     SS7MH01 => 'STOPPED',
                     SSAAAAA => 'STOPPED',
                 );

    my ($result, $aref_processStates) = $MsxObj->checkConsoleCommand (
                                          '-cmd'        => 'showprocs all',
                                          '-keyColName' => 'AppName',
                                          '-valColName' => 'State',
                                          '-validate'   => \%validate,
                                          '-timeout'    => 20,         # optional argument
                                        );

    unless ($result) {
        $logger->debug(__PACKAGE__ . ".$TestId:  checkConsoleCommand() - FAILED");

        if (defined $aref_processStates) {
            foreach my $process ( @{$aref_processStates} ) {
                $logger->debug(__PACKAGE__ . ".$TestId:  Failed for process $process");
            }
        }

        # Take corrective action based on REFERENCE(s) ...
#        ...
#        ...
#        return $resultHash{RESULT};

        # OR

        # Fail the testcase
        $TESTSUITE->{$TestId}->{METADATA} .= "Check FAILED for Process(s):--\n @{$aref_processStates}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return $result;
    }

    $logger->debug(__PACKAGE__ . ".$TestId:  checkConsoleCommand() - SUCCESS");

=cut

#################################################
# checkProcessStates()
#################################################
sub checkConsoleCommand {
    my ($self, %args)   = @_;
    return ( $self->ProcessConsoleCommand(
                        '-subName'    => 'checkConsoleCommand()',
                        %args) );
}
################################################################################


#########################################################################################################

=head1 ProcessConsoleCommand()

DESCRIPTION:

 The function is used to execute any console command and validate the response against 2 column attributes and return Success if all the key/value attribute(s) matches in console command response. On Failure it return the array containing the key column attribute, based on which the corrective action can be taken.
 
ARGUMENTS:

Mandatory:-
1. '-cmd'        - console command to execute
2. '-keyColName' - Reference Column Name i.e. header column name in command response
                   used as KEY attribute.
3. '-valcolname' - Value column name i.e. header column name in command response
                   used as VALUE attribute.
4. '-validate'   - hash reference i.e. hash containing the KEY/VALUE to be verified
                   example: application processes and their respective states.
5. '-subName'    - Subroutine name

Optional:-
1. Timeout    - used for execution of console commands
              - default 10 seconds

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 execConsoleCmd()
 parseCICStatCmdResults()
 parseConsoleCmdResults()

OUTPUT:
 
 1 - success
 0 - failure

 returns Hash Reference if the subName name is validate (OR)
 returns Array Reference if the subName name is check


EXAMPLE:

sub checkConsoleCommand {
    my ($self, %args)   = @_;
    return ( $self->ProcessConsoleCommand(
                        '-subName'    => 'checkConsoleCommand()',
                        %args) );
}
   

=cut

#################################################
sub ProcessConsoleCommand {
#################################################
    my ($self, %args) = @_;
    my ($subName, $keyColumnName, $valueColumnName);
    $subName = $args{'-subName'};
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'subName', 'cmd', 'keyColName', 'valColName', 'validate' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return $result;
        }
    }

    $keyColumnName   = $args{'-keyColName'};
    $valueColumnName = $args{'-valColName'};

    my %a = (
        -cmd     => '',
        -timeout => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    # Execute console command.
    unless ( $self->execConsoleCmd ( 
                        -cmd     => $a{"-cmd"},
                        -timeout => $a{"-timeout"},
                    ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot execute CONSOLE command \'$a{-cmd}\':--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }
    #$logger->debug(__PACKAGE__ . ".$subName:  Executed CONSOLE command \'$a{-cmd}\' - SUCCESS.");
    #$logger->debug(__PACKAGE__ . ".$subName:  CONSOLE command \'$a{-cmd}\' result:--\n@{ $self->{CMDRESULTS}}");

    my @cmdResults;
    push ( @cmdResults, @{$self->{CMDRESULTS}} );

    # Parse the console command response
    my ($parseResult, $AOHrefData);
    if ( $a{-cmd} =~ /cicstat/ ) {
        ($parseResult, $AOHrefData) = $self->parseCICStatCmdResults(\@cmdResults);
    }
    else {
        ($parseResult, $AOHrefData) = $self->parseConsoleCmdResults(\@cmdResults);
    }

    unless ( $parseResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  Parsing of CONSOLE command \'$a{-cmd}\' FAILED:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    my @AOH_Data = @{$AOHrefData};

    # validate process & state
    my %validateProcess = %{$a{'-validate'}};
    my ( @validationPassedList, @validationFailedList );
    my ( %passedHash, %failedHash, $processList );

    while ( my ($key, $value) = each %validateProcess ) {
        my $keyFoundFlag = 0;
        foreach ( @AOH_Data ) {
            if ( $_->{$keyColumnName} eq $key ) {
                $keyFoundFlag = 1;
                if ( $_->{$valueColumnName} eq $value ) {
                    push (@validationPassedList, $key);
                    $passedHash{$_->{$keyColumnName}} = $_->{$valueColumnName};
                }
                else {
                    $logger->error(__PACKAGE__ . ".$subName:  NOT MATCHED Key \'$key\', value expected \'$value\' but received \'$_->{$valueColumnName}\'");
                    push (@validationFailedList, $key);
                    $failedHash{$_->{$keyColumnName}} = $_->{$valueColumnName};
                }
            }
        }
        unless ( $keyFoundFlag ) {
            # invalid key
            push (@validationFailedList, $key);
            $failedHash{$key} = "INVALID_"."$keyColumnName"."_NotFound";
        }
    }

    if ( ( @validationFailedList ) ||
         ( %failedHash ) ) {
        if ($subName =~ /validate\S+/ ) {
            $processList = \%failedHash;
            $logger->debug(__PACKAGE__ . ".$subName:  FAILED validation of $keyColumnName(s)");
        }
        elsif ($subName =~ /check\S+/ ) {
            $processList = \@validationFailedList;
            $logger->debug(__PACKAGE__ . ".$subName:  FAILED validation of $keyColumnName(s) \'@validationFailedList\'");
        }
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
    }
    else {
        if ($subName =~ /validate\S+/ ) {
            $processList = \%passedHash;
            $logger->debug(__PACKAGE__ . ".$subName:  PASSED validation of $keyColumnName(s)");
        }
        elsif ($subName =~ /check\S+/ ) {
            $processList = \@validationPassedList;
            $logger->debug(__PACKAGE__ . ".$subName:  PASSED validation of $keyColumnName(s) \'@validationPassedList\'");
        }
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
        $result = 1; # PASS
    }
    return ($result, $processList);
}



#########################################################################################################

=head1 parseConsoleCmdResults()

DESCRIPTION:

 The function is parses the console command response output, into an array of hash(s) using the header column name as key(s).
 

ARGUMENTS:

1. Console command response to be parsed - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - success
 0 - failure

 $AOHrefData - containing parsed console command response - AoH reference

EXAMPLE:

    # Parse the console command response
    my ($parseResult, $AOHrefData);
    if ( $a{-cmd} =~ /cicstat/ ) {
        ($parseResult, $AOHrefData) = $self->parseCICStatCmdResults(\@cmdResults);
    }
    else {
        ($parseResult, $AOHrefData) = $self->parseConsoleCmdResults(\@cmdResults);
    }

    unless ( $parseResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  Parsing of CONSOLE command \'$a{-cmd}\' FAILED:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

=cut

#################################################
sub parseConsoleCmdResults {

    my ($self, $hrefCmdResults) = @_;
    my $subName       = "parseConsoleCmdResults()";
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    unless ( defined $hrefCmdResults ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument 'cmdResults' has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    my @cmdResults = @{$hrefCmdResults};

    my $rowHeaderFoundFlag = 0;
    my ( %header, @AOH_Data );
    my ( $rowsReceived, $numOfColumns );

    # Parse for number of rows received.
    my $rowReceivedFoundFlag = 0;
    foreach ( @cmdResults ) {
        if ( /(\d+)\s+rows received\s+/ ) {
            $rowsReceived = $1;
            $rowReceivedFoundFlag = 1;
        }
    }

    unless ( ( $rowsReceived ) && ($rowReceivedFoundFlag) ) {
        # i.e. zero rows in output, so no meaning in processing further.
        $logger->error(__PACKAGE__ . ".$subName:  console command output has '0' rows - FAILED.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return ($result);
    }

    # parsing of all rows of console command results.
    my $rowCount = 0;
    foreach ( @cmdResults ) {

        if ( ($_ eq "") || ($_ eq "\n") ) {
            # encountered empty line
            next;
        }

        if (/\|/) {
            my @row = split ( /[\|]/ );
            # Processing Header Row
            if ( ( $rowHeaderFoundFlag == 0) &&
                 ( @row ) ) {
                $rowHeaderFoundFlag = 1;
                $numOfColumns = $#row;
                my $count = 0;
                foreach ( @row ) {
                    $_ =~ s/^\s*//g; $_ =~ s/\s*$//g;
                    $header{$count++} = $_;
                }
                next;
            }
    
            # Processing Data Row(s)
            if ( ( $rowHeaderFoundFlag ) &&
                 ( @row ) &&
                 ( $#row == $numOfColumns ) &&
                 ( $rowCount != $rowsReceived ) ) {
                my $rec = {};
                $rowCount++;
                my $count = 0;
                foreach (@row) {
                    $_ =~ s/^\s*//g; $_ =~ s/\s*$//g;
                    $rec->{$header{$count++}} = $_;
                }
                push ( @AOH_Data, $rec );
            }
        } # END - if line contains '|'
    
        if ( $rowCount == $rowsReceived ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Processed all rows received");
            $result = 1; # PASS
            last;
        }
    } # END - parsing of all rows of console command results.

    return ($result, \@AOH_Data);
}


#########################################################################################################

=head1 parseCICStatCmdResults()

DESCRIPTION:

 The function is parses the console command "cicstat" response output, into an array of hash(s) using the header column name as key(s).
 

ARGUMENTS:

1. Console command response to be parsed - Array Reference

PACKAGE:
 SonusQA::MSX::MSXHELPER

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - success
 0 - failure

 $AOHrefData - containing parsed console command response - AoH reference

EXAMPLE:

    # Parse the console command response
    my ($parseResult, $AOHrefData);
    if ( $a{-cmd} =~ /cicstat/ ) {
        ($parseResult, $AOHrefData) = $self->parseCICStatCmdResults(\@cmdResults);
    }
    else {
        ($parseResult, $AOHrefData) = $self->parseConsoleCmdResults(\@cmdResults);
    }

    unless ( $parseResult ) {
        $logger->error(__PACKAGE__ . ".$subName:  Parsing of CONSOLE command \'$a{-cmd}\' FAILED:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

=cut

#################################################
sub parseCICStatCmdResults {
#################################################

    my ($self, $hrefCmdResults) = @_;
    my $subName       = "parseCICStatCmdResults()";
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    unless ( defined $hrefCmdResults ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument 'cmdResults' has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $result;
    }

    my @cmdResults = @{$hrefCmdResults};

    my $rowHeaderFoundFlag = 0;
    my ( %header, @AOH_Data );
    my ( $rowsReceived, $numOfColumns );

    # Parse for number of rows received.
    my $rowReceivedFoundFlag = 0;
    foreach ( @cmdResults ) {
        if ( /(\d+)\s+rows received\s+/ ) {
            $rowsReceived = $1;
            $rowReceivedFoundFlag = 1;
        }
    }

    unless ($rowReceivedFoundFlag) {
        # i.e. command output is empty, (may be input argument is wrong)
        $logger->error(__PACKAGE__ . ".$subName:  console command \'cicstat\', CIC details not available - FAILED.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return ($result);
    }

    unless ( ( $rowsReceived ) && ($rowReceivedFoundFlag) ) {
        # i.e. zero rows in output, so no meaning in processing further.
        $logger->error(__PACKAGE__ . ".$subName:  console command output has '0' rows - FAILED.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return ($result);
    }

    # parsing of all rows of console command results.
    my $rowCount = 0;
    foreach ( @cmdResults ) {

        if ( ($_ eq "") || ($_ eq "\n") ) {
            # encountered empty line
            next;
        }

        if (/\|/) {
            my @row = split ( /[\|]/ );
            # Processing Header Row
            if ( ( $rowHeaderFoundFlag == 0) &&
                 ( @row ) ) {
                $rowHeaderFoundFlag = 1;
                $numOfColumns = $#row;
                my $count = 0;
                foreach ( @row ) {
                    $_ =~ s/^\s*//g; $_ =~ s/\s*$//g;

                    if (/(\S+)\((\S+)\)/) {
                    # Owner(PID)
                        $header{$count++} = $1;
                        $header{$count++} = $2;
                    }
                    elsif (/(\S+)\s+([\S\-]+)/) {
                    # State SI-DFLB-MB-HB-DF-PL-TR-RP-GL-OS-PO-AL-LB-RB-
                        $header{$count++} = $1;
                        $header{$count++} = $2;
                    }
                    elsif (/(\S+)\,(\S+)/) {
                    # TG,RPC
                        $header{$count++} = $1;
                        $header{$count++} = $2;
                    }
                    elsif (/(\S+)\,\s+(\S+)/) {
                    # CallId, ConnId
                        $header{$count++} = $1;
                        $header{$count++} = $2;
                    }
                    else {
                        $header{$count++} = $_;
                    }
                }
                next;
            }
    
            # Processing Data Row(s)
            if ( ( $rowHeaderFoundFlag ) &&
                 ( @row ) &&
                 ( $#row == $numOfColumns ) &&
                 ( $rowCount != $rowsReceived ) ) {
                my $rec = {};
                $rowCount++;
                my $count = 0;
                foreach (@row) {
                    $_ =~ s/^\s*//g; $_ =~ s/\s*$//g;

                    if (/(\S+\d+)\((\d+)\)/) {
                    # Owner(PID)
                    # CCSW01(1)
                        $rec->{$header{$count++}} = $1;
                        $rec->{$header{$count++}} = $2;
                    }
                    elsif (/\((\d\d\d\d)\)\s+([\S\-]+)/) {
                    # State SI-DFLB-MB-HB-DF-PL-TR-RP-GL-OS-PO-AL-LB-RB-
                    # (0000) --------------------------------------------
                        $rec->{$header{$count++}} = $1;
                        $rec->{$header{$count++}} = $2;
                    }
                    elsif (/(\d+)\s+\(([\S\d]+)\)/) {
                    # TG,RPC
                    # 2 (0xde)
                        $rec->{$header{$count++}} = $1;
                        $rec->{$header{$count++}} = $2;
                    }
                    elsif (/(\d+\/\d+)\,\s+([\S\d\-]+)/) {
                    # CallId, ConnId
                    # 0/0, -
                        $rec->{$header{$count++}} = $1;
                        $rec->{$header{$count++}} = $2;
                    }
                    else {
                        $rec->{$header{$count++}} = $_;
                    }
                }
                push ( @AOH_Data, $rec );
            }
        } # END - if line contains '|'
    
        if ( $rowCount == $rowsReceived ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Processed all rows received");
            $result = 1; # PASS
            last;
        }
    } # END - parsing of all rows of console command results.

    return ($result, \@AOH_Data);
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
__END__
