package SonusQA::GTB::doTestPSX;

=head1 NAME

SonusQA::GTB::doTestPSX

=head1 DESCRIPTION

This module provides functions for running PSX/GSX BISTQ jobs.

=over

=item PACKAGES USED:
Log::Log4perl;
threads;
threads::shared;
SonusQA::Utils;
Data::Dumper;
Time::HiRes;
POSIX;

=back 

=cut 

use strict;
use warnings;
use Log::Log4perl;
use threads;
use threads::shared;
use SonusQA::Utils qw (:all);
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use POSIX qw(strftime);

my $logger;
my %g_jobRunning : shared;
my %g_cancelRequest : shared;
my %g_totalTests : shared;
my $AutomationOutputFile;


=head1 main()

=over

=item DESCRIPTION:
This will being invoked from Scheduler::doTest depending on the product type. It serves as an entry point. This sub-routine is not for end user use and will be invoked by BISTQ scheduler.

=item ARGUMENTS:
Mandatory Args:
jobTestBed - hash containing testbed info related to the job.
JobSubJobs - hash containing job details like suite type, suite path etc.


=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub main {
    $logger = Log::Log4perl->get_logger(__PACKAGE__);

    my $function = "main";
    my ( $jobTestBed, $JobSubJobs ) = @_;
    my ( $checkForCancelThread, $monitorJobThread, $timeStamp, $returnCode, $updateJobStatusThread, $schedulerTestBed );

    my $jobId = $jobTestBed->[0];
    $AutomationOutputFile = $ENV{"HOME"} . "/ats_user/logs/". $JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'} . "/Automation_". $jobId . ".log";

    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    $g_jobRunning{$jobId}    = 1;
    $g_cancelRequest{$jobId} = 0;
    $g_totalTests{$jobId}    = 0;

    unless ( -e $ENV{"HOME"} . "/ats_user/logs/". $JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'} ) {
        system( "mkdir ". $ENV{"HOME"} . "/ats_user/logs/". $JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'} );
    }

    $checkForCancelThread = threads->create( \&checkForCancel, $jobId, $JobSubJobs );
    $monitorJobThread = threads->create( \&monitorJob, $jobId );
    $updateJobStatusThread = threads->create(
        \&updateJobStatus, $jobId, $AutomationOutputFile,
        $JobSubJobs->{'ATTRIBUTES'}->{'VERSION'},
        $JobSubJobs->{'ATTRIBUTES'}->{'DUT'}
    );

    $schedulerTestBed = $JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'};
    $returnCode = &kickoffStartAutomation( $jobTestBed, $JobSubJobs, $AutomationOutputFile, $schedulerTestBed);
    unless ( $updateJobStatusThread->join() ) {
        $logger->error("ERROR: Update Job Status Thread Returned ERROR:" . $jobId );
    }

    unless ( $monitorJobThread->join() ) {
        $logger->error("ERROR: Monitor Job Status Thread Returned ERROR:" . $jobId );
    }

    &cleanUp( $jobId, $JobSubJobs, $AutomationOutputFile );

    $AutomationOutputFile = undef;

    if ( $checkForCancelThread->join() && $returnCode ) {
        undef($checkForCancelThread);
        undef($monitorJobThread);
        undef($updateJobStatusThread);
        $logger->info( "LEAVING(1): " . $function . " jobId:" . $jobId );
        $jobId = undef;
        return 1;
    }
    else {
        undef($checkForCancelThread);
        undef($monitorJobThread);
        undef($updateJobStatusThread);
        $logger->info( "LEAVING(0): " . $function . " jobId:" . $jobId );
        $jobId = undef;
        return 0;
    }
}

=head1 cleanUp()

=over

=item DESCRIPTION:
Clean up checkedout suites and delete job from threads after the completion of job.

=item ARGUMENTS:
Mandatory Args:
JobId - Jobid to be deleted from threads
JobSubJobs - JobSubJobs hash containing checked out path info.


=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub cleanUp {
    my $function = "cleanUp";
    my ( $jobId, $jobSubJobs, $AutomationOutputFile ) = @_;
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    $logger->info($function . "Deleting jobid from threads." );
    delete( $g_jobRunning{$jobId} );
    delete( $g_cancelRequest{$jobId} );
    delete( $g_totalTests{$jobId} );

    $logger->info( "LEAVING: " . $function . " jobId:" . $jobId );
    return 1;
}

=head1 checkForCancel()

=over

=item DESCRIPTION:
When a job is deleted from UI, this subroutine cleanups checked out folder.

=item ARGUMENTS:
Mandatory Args:
JobId - Jobid to be deleted from threads
JobSubJobs - JobSubJobs hash containing checked out path info.


=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub checkForCancel {
    my $function = "checkForCancel";
    my ( $jobId, $jobSubJobs ) = @_;

    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    while ( $g_jobRunning{$jobId} ) {
        if ( SonusQA::GTB::Scheduler::CheckForCancel($jobId) ) {
            $g_cancelRequest{$jobId} = 1;
            $logger->info( "CANCEL PROCESSED BY BACKEND jobId:" . $jobId );
            foreach ( keys %{$jobSubJobs} ) {
                next if ( $_ =~ m/ATTRIBUTES/ );
                $logger->info( $function . " Deleting : ". $jobSubJobs->{$_}->{'checked_out_dir'} );
                system("rm -rf  $jobSubJobs->{$_}->{'checked_out_dir'}") ;    # removing all checked-out files
            }
            $logger->info( "LEAVING(0): " . $function . " jobId:" . $jobId );
            return 0;
        }
        sleep(5);
    }
    $logger->info( "LEAVING(1): " . $function . " jobId:" . $jobId );
    return 1;
}

=head1 updateJobStatus()

=over

=item DESCRIPTION:
When the job is running, keep updating job status to DB. After the completion of job send the status email to user.

=item ARGUMENTS:
Mandatory Args:
JobId - Running job id 
AutomationOutputFile - path of the automation file. We keep parsing this file to fetch details like how many testcases have passed/failed and which suite is currently running.
jobVersion - Build version
jobDUT - Test DUT 


=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub updateJobStatus {
    my $function = "updateJobStatus";
    my ( $jobId, $AutomationOutputFile, $jobVersion, $jobDUT ) = @_;
    my ( $passCount, $failCount, $executedCount, $line, $currentPos, $JobIsAlive, $currentSuite, $suiteHistory, $suiteStartTime, $suiteEndTime, $actualCaseCount, $suiteExecutionTime, $totalPass, $totalFail, $totalExecuted, $totalActualCount, $totalExecutionTime );

    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    $totalPass = 0;
    $totalFail = 0;
    $totalExecuted = 0;
    $totalActualCount = 0;
    $totalExecutionTime = "00:00:00";

    $passCount       = 0;
    $failCount       = 0;
    $executedCount   = 0;
    $currentPos      = 0;
    $JobIsAlive      = 1;

    my $jobResultSummary = "##################################### Result Summary #############################################\n"
      . sprintf( "%-40s %-10s %-10s %-10s %-10s %-20s", 'FEATURE NAME', 'PASS', 'FAIL', 'TOTAL', 'ACTUAL', 'Exec Duration' )
      . "\n##################################################################################################\n";
    sleep(5);

    while ( $g_jobRunning{$jobId} ) { #WHILE JOB IS RUNNING
        if ( -e $AutomationOutputFile && -s $AutomationOutputFile ne "0" ) { #WAIT TILL SOMETHING IS IN THE FILE
            SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_job SET URLtoLogs='". $AutomationOutputFile . "' WHERE JobId='". $jobId . "'" ); # NOW THAT THE JOB OFFICIALLY STARTERD UPDATE DB OF WHERE THE LOG IS
            while ($JobIsAlive) {    #WHILE JOB IS ALIVE
                if ( !$g_jobRunning{$jobId} ) {
                    $JobIsAlive = 0;
                }
                #ONCE JOB HAS FINISHED CYCLE THROUGH LOG ONE LAST TIME
                open( LOGREADER, "<", $AutomationOutputFile );
                seek( LOGREADER, $currentPos, 0 ); #GO TO POSITION LEFT OFF FROM
                while ( $line = <LOGREADER> ) {    #IF SOMETHING TO READ

                    if ( $line =~ /.*STARTING EXECUTION OF TESTCASES UNDER FEATURE CODE\s:\s\[(.*)\].*/ ) {
                        $currentSuite = $1;
                        $currentSuite =~ s/\s//g if(defined $currentSuite);
                        $suiteHistory .= ( $suiteHistory eq "" ) ? $currentSuite : "->" . $currentSuite;
                        SonusQA::GTB::Scheduler::jobStatusUpdate( "Running :$suiteHistory", $jobId );
                    }

                    $actualCaseCount = $1 if ( $line =~ /.*TOTAL TESTCASES\s*:\s*(.*)/ );
                    $actualCaseCount =~ s/\s//g if(defined $actualCaseCount);

                    $executedCount = $1 if ( $line =~ /.*TOTAL EXECUTED\s*:\s*(.*)/ );
                    $executedCount =~ s/\s//g if(defined $executedCount);

                    $passCount = $1 if ( $line =~ /.*TOTAL PASS\s*:\s*(.*)/ );
                    $passCount =~ s/\s//g if(defined $passCount);

                    $failCount = $1 if ( $line =~ /.*TOTAL FAIL\s*:\s*(.*)/ );
                    $failCount =~ s/\s//g if(defined $failCount);

                    $suiteStartTime = $1 if ( $line =~ /.*SUITE START TIME\s*:\s*(.*)/ );
                    $suiteStartTime =~ s/\s//g if(defined $suiteStartTime);

                    $suiteEndTime = $1 if ( $line =~ /.*SUITE END TIME\s*:\s*(.*)/ );
                    $suiteEndTime =~ s/\s//g if(defined $suiteEndTime);

                    $suiteExecutionTime = $1 if ( $line =~ /.*SUITE EXECUTION TIME\s*:\s*(.*)/ );
                    $suiteExecutionTime =~ s/\s//g if(defined $suiteExecutionTime);

                    #if we see the testcase completion overview
                    if ($line =~ /.*AUTOMATION COMPLETED.*/) {

                        $logger->debug( "SUITE ENDED-> SUITE: " . $currentSuite . " Execution Length: " . $suiteExecutionTime );
                        $logger->debug ( "Executed: " . $executedCount. " OUT OF " . $actualCaseCount);
                        $jobResultSummary .= sprintf( "%-40s %-10s %-10s %-10s %-10s %-20s", $currentSuite, $passCount, $failCount, $executedCount, $actualCaseCount, $suiteExecutionTime ) . "\n";

                        $logger->debug( "DEBUG POINT :" . $jobResultSummary);
                        $logger->debug( "UPDATING EXECUTION LENGTH FOR " . $currentSuite );

                        $suiteExecutionTime =~ s/\s//g if(defined $suiteExecutionTime);
                        if ( $suiteExecutionTime =~ m/(.*)\:(.*)\:(.*)/ ) {
                            $suiteExecutionTime = ( $1 * 60 ) + $2;
                        }
                        $logger->debug( "UPDATE ats_sched_suite SET LastExecDuration='" . $suiteExecutionTime . "'" . " WHERE SuiteName='" . $currentSuite . "' AND DUT='" . $jobDUT . "'" . " AND find_in_set('" . $jobVersion . "',Version)" );
                        &SonusQA::GTB::Scheduler::dbCmd( "UPDATE ats_sched_suite SET LastExecDuration='" . $suiteExecutionTime . "'" . " WHERE SuiteName='" . $currentSuite . "' AND DUT='" . $jobDUT . "'" . " AND find_in_set('" . $jobVersion . "',Version)" );

                        $totalPass = $totalPass + $passCount;
                        $totalFail = $totalFail + $failCount;
                        $totalExecuted = $totalExecuted + $executedCount;
                        $totalActualCount = $totalActualCount + $actualCaseCount;
						
						# Circus to add suiteExecutionTime to $totalExecutionTime
                        my ($hr, $min, $sec) = split /:/, $suiteExecutionTime;
                        my ($hr2, $min2, $sec2) = split /:/, $totalExecutionTime;
                        my $hr3 = $hr + $hr2;
                        my $min3 = $min + $min2;
                        my $sec3 = $sec + $sec2;
                        my $elapsed = ($hr3 * 3600) + ($min3 * 60) + $sec3;
                        my $hr4 = int $elapsed / 3600;
                        my $new = $elapsed % 3600 ;
                        my $min4 = int $new / 60;
                        my $sec4 = $new % 60 ;
                        $totalExecutionTime = sprintf("%02d:%02d:%02d",$hr4,$min4,$sec4);;

                        $actualCaseCount          = 0;
                        $executedCount            = 0;
                        $passCount                = 0;
                        $failCount                = 0;
                        $suiteStartTime           = '';
                        $suiteEndTime             = '';
                        $suiteExecutionTime       = '';

                        SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_job SET TotalTests='" . $g_totalTests{$jobId} . "', ExecTests='" . $executedCount. "', Pass = '" . $passCount . "', Fail = '" . $failCount. "' WHERE JobId = '". $jobId . "'");
                    }

                    #IF NEXT READ WOULD BE EOF, FIND OUT WHERE WE ARE, CLOSE HANDLER
                    if ( eof(LOGREADER) ) {
                        sleep(5);
                        $currentPos = tell(LOGREADER);
                        close(LOGREADER);
                        last;
                    }
                }    #END while($line = <LOGREADER> )
            }    #END while($g_jobRunning)

    		$jobResultSummary .= "##################################################################################################\n"
                              .sprintf( "%-40s %-10s %-10s %-10s %-10s %-20s", "TOTAL", $totalPass, $totalFail, $totalExecuted, $totalActualCount, $totalExecutionTime )
                              ."##################################################################################################\n";

			
        }    #END if(-s $AutomationOutputFile ne "0")
    }    #END while($g_jobRunning)

    if ( $g_cancelRequest{$jobId} ) { #if job was cancelled send a summary email
        $jobResultSummary .= "Summary for " . $jobId . " After Cancellation:\n\n\n";
        $jobResultSummary .= "\nAutomation log file: " . $AutomationOutputFile . "\n";
        SonusQA::GTB::Scheduler::sendEmail( $jobResultSummary, $jobId );
    }
    else {
        $jobResultSummary .= "\nAutomation log file: " . $AutomationOutputFile . "\n";
        SonusQA::GTB::Scheduler::sendEmail( $jobResultSummary, $jobId );
    }

    $logger->info( "LEAVING(1): " . $function . " jobId:" . $jobId );
    return 1;
}

=head1 createConfigFile()

=over

=item DESCRIPTION:
Create a CONFIG.pm file required for STARTPSXAUTOMATION/STARTGSXAUTOMATION/STARTNBSAUTOMATION

=item ARGUMENTS:
Mandatory Args:
jobTestBed - testbed required for the suite.
suitePath - suite path.
version - release version.
build - build number.
variant - variant.
mailIds - mailids to send status mails.


=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub createConfigFile {
    local $/;
    my $function = "createConfigFile";
    my ( $jobTestBed, $suitePath, $version, $build, $variant, $mailIds, $rerunfailed ) = @_;
    my $jobId = $jobTestBed->[0];
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    my $configFile = "$suitePath/CONFIG.pm" ;

    my $testBedData = "\n" . '@TESTBED = (' . "\n";
    for ( my $index = 0 ; $index < scalar @{$jobTestBed->[1]} ; $index = $index + 3 ) {
        $testBedData .= "\t\"$jobTestBed->[1]->[$index + 1]\"" . ", # $jobTestBed->[1]->[$index] \n" ;
    }
    $testBedData .= ');' . "\n\n";

    open(FILE, ">>$configFile" ) or die "Can't read file $configFile [$!]\n";
    print FILE $testBedData;
    print FILE 'our $emailList = ['. $mailIds .'];' if($mailIds);
    print FILE 'our $RERUN_FAILED = '.$rerunfailed.';' if($rerunfailed);
    close (FILE);

    my $changeVersion = "sed -i \"/^.*\\\$version\\s*=.*;/c\\our \\\$version = '" .  $build . "';" . "\" $configFile";
    $logger->info("Executing - $changeVersion");
    system($changeVersion);

    my $changeRelease = "sed -i \"/^.*\\\$release\\s*=.*;/c\\our \\\$release = '" .  $version . "';" . "\" $configFile";
    $logger->info("Executing - $changeRelease");
    system($changeRelease);


    # if variant exists, change it
    my $changeVariant = "sed -i \"/^.*\\\$variant\\s*=.*;/c\\our \\\$variant = '" .  $variant . "';" . "\" $configFile";
    $logger->info("Executing - $changeVariant");
    system($changeVariant);

    # if variant does not exists, add it  
    $logger->info("Adding Variant. Executing - sed -i \"/rel[[:space:]]*=>[[:space:]]*/a\\\t\\\t variant => '" . $variant . "',\" $configFile");
    my $addVariant = "sed -i \"/rel[[:space:]]*=>[[:space:]]*/a\\\t\\\t variant => '" . $variant . "',\" $configFile";
    system($addVariant);

    $logger->info( "CONFIG FILE: $configFile" );
    $logger->info( "LEAVING(1): " . $function . " jobId:" . $jobId );
    return 1;
}

=head1 changeNameSpace()

=over

=item DESCRIPTION:
Set the namespace correctly in CONFIG.pm, SCRIPTS.pm & STARTPSXAUTOMATION/STARTGSXAUTOMATION/STARTNBSAUTOMATION

=item ARGUMENTS:
Mandatory Args:
jobId
suitePath
jobSubJobs
suite
startAutomationScript
dut

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub changeNameSpace {

    my $function = "changeNameSpace";
    my ( $jobId, $suitePath, $jobSubJobs, $suite, $startAutomationScript,$dut) = @_;
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    # some circus to get the namespace for checked out file
    my $temp_namespace = $suitePath;
    $temp_namespace =~ s/\/\//\//g;
    $temp_namespace =~ s/.*ats_repos\/lib\/perl//;
    $temp_namespace =~ s/\//\:\:/g;
    $temp_namespace =~ s/(^::|::$)//g;
    $jobSubJobs->{$suite}->{'pacakage'} = "${temp_namespace}";

    my $cofigNameSpaceCmd = 'sed -i "s/package.*QATEST::.*/package '. "${temp_namespace}::CONFIG;" . '/"'. " ${suitePath}/CONFIG.pm";
    unless ( system("$cofigNameSpaceCmd") == 0 ) {
        $logger->error("LEAVING: $function - unable to change CONFIG.pm pacakage name");
        $logger->error("LEAVING: $function - $cofigNameSpaceCmd - failed");
        $logger->info("LEAVING(0): $function ");
        return 0;
    }

    my $scriptsNameSpaceCmd = 'sed -i "s/package.*QATEST::.*/package '. "${temp_namespace}::SCRIPTS;" . '/"'. " ${suitePath}/SCRIPTS.pm";
    unless ( system("$scriptsNameSpaceCmd") == 0 ) {
        $logger->error("LEAVING: $function - unable to change SCRIPTS.pm pacakage name");
        $logger->error("LEAVING: $function - $scriptsNameSpaceCmd - failed");
        $logger->info("LEAVING(0): $function ");
        return 0;
    }

    my $startAutomationScriptNameSpaceCmd = 'sed -i "s/use.*QATEST::.*::SCRIPTS/use '. "${temp_namespace}" . '::SCRIPTS/"'. " ${suitePath}/${startAutomationScript}";

    unless ( system("$startAutomationScriptNameSpaceCmd") == 0 ) {
        $logger->error("LEAVING: $function - unable to change 'QATEST::.*::SCRIPTS' in $startAutomationScript");
        $logger->error("LEAVING: $function - $startAutomationScriptNameSpaceCmd - failed");
        $logger->info("LEAVING(0): $function ");
        return 0;
    }

    my $startAutomationConfigNameSpaceCmd = 'sed -i "s/QATEST::'.$dut.'::CONFIG/'. "${temp_namespace}" . '::CONFIG/g"'. " ${suitePath}/${startAutomationScript}";
    unless ( system("$startAutomationConfigNameSpaceCmd") == 0 ) {
        $logger->error("LEAVING: $function - unable to change 'QATEST::$dut::CONFIG' in $startAutomationScript");
        $logger->error("LEAVING: $function - $startAutomationConfigNameSpaceCmd - failed");
        $logger->info("LEAVING(0): $function ");
        return 0;
    }

    my $feature_cmd = 'sed -i "s/QATEST::'.$dut.'::CONFIG/'. $temp_namespace . '::CONFIG/"'. " ${suitePath}/${suite}.pm";
    unless ( system("$feature_cmd") == 0 ) {
        $logger->error("LEAVING: $function - unable to change 'QATEST::$dut::CONFIG' in $suite");
        $logger->error("LEAVING: $function - $feature_cmd - failed");
        $logger->info("LEAVING(0): $function ");
        return 0;
    }


    $logger->info( "LEAVING(1): " . $function . " jobId:" . $jobId );
    return 1;
}

=head1 checkoutImmediates()

=over

=item DESCRIPTION:
Checkout suite for execution. It does svn co --depth=immediates <svn_url> <path>

=item ARGUMENTS:
Mandatory Args:
path - path on ats machine to checkout
url - svn url of the suite

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub checkoutImmediates {
    my ( $path, $url ) = @_;
    $logger->debug("ENTERED checkoutImmediates" );

    $logger->debug("Present working directory : " . `pwd` );
    my $cmd = ($url) ? "svn co --depth=immediates --username atsinfra --password sonus --no-auth-cache $url $path" : "svn up --set-depth=immediates --username atsinfra --password sonus --no-auth-cache $path";

    my @output = `$cmd  2>\&1`;    # check-out using atsinfra and sonus
    unless ( grep ( /(Checked out|Updated to|At) revision \d+/, @output ) ) {
        $logger->error("checkoutImmediates - svn checkout failed to directory '$path'\n Svn command : '$cmd'\n Svn command failure reason : ". Dumper( \@output ) );
        return 0;
    }

    #need to replace the user path to current user in xml files for SIPP
    my $user_home = qx#echo ~#;
    chomp($user_home);
    `sed -i 's|/home/[a-zA-Z]*|'$user_home'|g' $path/*.xml`;

    my $return = 1;
    foreach (@output) {
        if (m/^A\s+(.*)/) {
            my $name = $1;
            if ( -d $name ) {
                unless ( $name =~ m/log/i ) {
                    $logger->debug("checkoutImmediates - updating $name");
                    unless ( checkoutImmediates($name) ) {
                        $return = 0;
                        last;
                    }
                }
                else {
                    $logger->debug("checkoutImmediates - Excluding log directory $name");
                }
            }
        }
    }
    $logger->debug("LEAVING checkoutImmediates" );
    return ($return);
}


=head1 kickoffStartAutomation()

=over

=item DESCRIPTION:
This sub-routine kicks off the job and calls various other sub-routines in this module to run a job.

=item ARGUMENTS:
Mandatory Args:
jobTestBed - Hash containing job testbed information.
jobSubJobs - Hash containing all suites info related job. 
AutomationOutputFile - Automation log file full path. 

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub kickoffStartAutomation {

    my $function = "kickoffStartAutomation";
    my ( $jobTestBed, $jobSubJobs, $AutomationOutputFile, $schedulerTestBed ) = @_;
    my $jobId = $jobTestBed->[0];
    my $returnCode;
    my $version = $jobSubJobs->{'ATTRIBUTES'}->{'VERSION'};
    my $build = $jobSubJobs->{'ATTRIBUTES'}->{'BUILD'};
    my $variant = $jobSubJobs->{'ATTRIBUTES'}->{'VARIANT'};
    my $rerunfailed = $jobSubJobs->{'ATTRIBUTES'}->{'RERUNFAILED'};
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    foreach my $suite (sort {$jobSubJobs->{$a}->{'ORDER'} <=> $jobSubJobs->{$b}->{'ORDER'}} (keys %{$jobSubJobs})) {
        next if ( $suite =~ m/ATTRIBUTES/ );
        if ( !defined $jobSubJobs->{$suite}->{'PATH'} or !$jobSubJobs->{$suite}->{'PATH'} ) {
            $logger->error("LEAVING: kickoffStartAutomation - svn path is empty or blank for the -> $suite");
            $logger->info("LEAVING(0): kickoffStartAutomation ");
            return 0;
        }
        if ($g_cancelRequest{$jobId}) {
            $logger->info( "Job has been deleted. Abort executing suite - $jobSubJobs->{$suite}->{'PATH'}" );
            next;
        }

        my $suitePath = $jobSubJobs->{$suite}->{'PATH'};
        $suitePath =~ s/^\/QATEST/QATEST/;

        my $dut = $1 if($suitePath =~ m/^QATEST\/(\w+)\//);
        $dut = 'PSX' if($dut eq 'EPX');
        unless($dut){
            $logger->error("$function :: Couldn't parse dut from suite path ($suitePath)");
            $logger->info("LEAVING(0) :: $function");
            return 0;
        }

        my $suiteFullPath = $ENV{"HOME"} . "/ats_repos/lib/perl/$suitePath";

        unless ( system("mkdir -p $suiteFullPath") == 0 ) {
            $logger->error("LEAVING: kickoffStartAutomation - unable to create directory $suiteFullPath");
            $logger->info("LEAVING(0): kickoffStartAutomation ");
            return 0;
        }

        unless (checkoutImmediates($suiteFullPath, "http://masterats.sonusnet.com/ats/test/branches/$jobSubJobs->{$suite}->{'PATH'}/") ) {
            $logger->error("kickoffStartAutomation - svn checkout failed to directory '$suiteFullPath', Suite path : '$jobSubJobs->{$suite}->{'PATH'}', JobID : '$jobId'");
            SonusQA::GTB::Scheduler::sendEmail("svn checkout failed to directory '$suiteFullPath', Suite path : '$jobSubJobs->{$suite}->{'PATH'}', JobID : '$jobId'", $jobId );
            $logger->debug("NEXT: kickoffStartAutomation - Going to next test suite");
            delete $jobSubJobs->{$suite};
            next;
        }
        $logger->debug("kickoffStartAutomation - Successfully checked out suite '$suite' to directory '$suiteFullPath', suite path : '$jobSubJobs->{$suite}->{'PATH'}'");

        $jobSubJobs->{$suite}->{'checked_out_dir'} = $suiteFullPath; # to remove checked-out files on completion of test

        $logger->info( "########################## GENERATING CONFIG file for $suite ##########################" );
        my $mailIds;
        if (defined $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'} and $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'}) {
            map { $mailIds .= "\'$_\@sonusnet.com\',"} split(/\,/, $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'});
            $mailIds =~ s/\,$//;
        } 

        unless ( &createConfigFile( $jobTestBed, $suiteFullPath, $version, $build, $variant, $mailIds, $rerunfailed ) ) {
            $logger->error( "ERROR IN CREATING CONFIG FILE!" . $jobId );
            $logger->info( "LEAVING(0): " . $function . " jobId:" . $jobId );
            SonusQA::GTB::Scheduler::sendEmail( "Failed to create CONFIG file!", $jobId );
            return 0;
        }
        $logger->info("########################## GENERATED CONFIG file for $suite SUCCESSFULLY ##########################" );

        $logger->info( "########################## UPDATE TESTSUITE file for $suite ##########################" );
        unless ( &updateTestSuiteFile( $jobId, $jobSubJobs, $suite, $suiteFullPath) ) {
            $logger->error( "ERROR IN UPDATING TESTSUITES FILE!" . $jobId );
            $logger->info( "LEAVING(0): " . $function . " jobId:" . $jobId );
            SonusQA::GTB::Scheduler::sendEmail( "Failed to update TESTSUITES file!", $jobId );
            return 0;
        }
        $logger->info("########################## UPDATED TESTSUITE file for $suite SUCCESSFULLY ##########################" );

        my $startAutomationScript = "START${dut}AUTOMATION";

        $logger->info( "Copying $startAutomationScript script" );
        system( "cp " . $ENV{"HOME"} . "/ats_repos/lib/perl/QATEST/$dut/$startAutomationScript $suiteFullPath/$startAutomationScript" );

        `chmod -R 777 $suiteFullPath`;
        chdir "$suiteFullPath/";
        system("rm $suiteFullPath/Results");

        my $startAutomation_cmd;
        if($dut=~/(GSX|NBS)/){
            $logger->info( "########################## Change Namespace for $suite ##########################" );
            unless ( &changeNameSpace( $jobId, $suiteFullPath, $jobSubJobs, $suite, $startAutomationScript,$dut) ) {
                $logger->error( "ERROR IN CHANGING NAMESPACE!" . $jobId );
                $logger->info( "LEAVING(0): " . $function . " jobId:" . $jobId );
                SonusQA::GTB::Scheduler::sendEmail( "Failed to create CONFIG file!", $jobId );
                return 0;
            }
            $logger->info("########################## Changing Namespace for $suite SUCCESSFULLY ##########################" );
            $startAutomation_cmd = "perl $suiteFullPath/$startAutomationScript --config CONFIG --log DEBUG >> $AutomationOutputFile 2>&1";
        }
        else{ #PSX/EPSX
            my $automationFlags = ($variant =~ /sbx/i) ? " --sbx y " : " --sbx n ";
            $automationFlags .= ($variant =~ /gsx/i) ? " --gsx y " : " --gsx n ";
            $automationFlags .= ($variant =~ /epsx/i) ? " --epsx y " : " --epsx n ";
            system( "cp $suiteFullPath/TESTSUITES $suiteFullPath/TESTSUITES_$jobId");
            $startAutomation_cmd = "perl $suiteFullPath/$startAutomationScript --bistq_job_uuid $jobId --config CONFIG --log DEBUG --ats n --testcases $suiteFullPath/TESTSUITES_$jobId --select n $automationFlags >> $AutomationOutputFile 2>&1";
        }
        if ($g_cancelRequest{$jobId}) {
            $logger->info( "Job has been deleted. Abort executing suite - $jobSubJobs->{$suite}->{'PATH'}" );
            next;
        } else {
            my $now_string = strftime "%Y-%m-%d %H:%M:%S", localtime;
            &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT('$suite',' [s]','$now_string') WHERE JobId='".$jobId."' AND JobStatus like '".$suite." [%'");

            $logger->info("########################## Executing Test Suite $suite ##########################" );
            $logger->info($startAutomation_cmd);
            $returnCode = system($startAutomation_cmd);

            SonusQA::GTB::Scheduler::sendEmail("There was an error while executing $suite. Please make sure you have updated all ATS libraries and try again ", $jobId) if($returnCode < 0);
            $now_string = strftime "%Y-%m-%d %H:%M:%S", localtime;
            &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT(JobStatus,' [c]','$now_string') WHERE JobId='".$jobId."' AND JobStatus like '".$suite." [%'");
            $logger->info("########################## Completed Executing Test Suite $suite ##########################" );
        }

        $logger->info("Deleting checked out suite - " . $jobSubJobs->{$suite}->{'checked_out_dir'});
        system("rm -rf  $jobSubJobs->{$suite}->{'checked_out_dir'}");

        chdir $ENV{"HOME"};
        $logger->info("cd to ". $ENV{"HOME"} );
    }

    $logger->info("LEAVING(1): " . $function . " jobId:" . $jobId ); 
    return 1;
}

=head1 updateTestSuiteFile()

=over

=item DESCRIPTION:
Update testsuite file to run testcases which are bistq ready and active

=item ARGUMENTS:
Mandatory Args:
jobId
jobSubJobs
suite

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub updateTestSuiteFile {

    my ( $jobId, $jobSubJobs, $suite, $suitePath ) = @_;
    my ($match, $line);
    my $function = "updateTestSuiteFile";
    my $testSuiteFile = $suitePath . "/TESTSUITES";
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );

    open( TESTSUITEFILEREADER, "<", $testSuiteFile );
    while ( $line = <TESTSUITEFILEREADER> ){ 
		chomp $line;
		$line =~ s/\s+$//;
        $match = 0;
        foreach my $testcaseid (@{$jobSubJobs->{$suite}->{TESTCASES}}){
            $match = 1 if( $line =~ m/tms$testcaseid/ );
        }

        unless($match){
            $logger->info("sed -i /$line/s/^/#/ $testSuiteFile");
            system("sed -i /$line/s/^/#/ $testSuiteFile");
        }
    }

    close(TESTSUITEFILEREADER);
    $logger->debug("LEAVING(1) updateTestSuiteFile" );
    return 1;
}

=head1 monitorJob()

=over

=item DESCRIPTION:
This keeps monitoring running job. If user deletes a job from UI, we see it here and kill a running process to end a job.

=item ARGUMENTS:
Mandatory Args:
jobId - jobid.

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
1 - Success
0 - Failure

=back

=cut

sub monitorJob {
    my $function     = "monitorJob";
    my $jobId        = shift;
    my $processAlive = 1;
    my $attempt      = 0;
    $logger->info( "ENTERED: " . $function . " jobId:" . $jobId );
    sleep(30);
    while ($processAlive) {
        $processAlive = 0;
        foreach (`ps uxww`) {
            if ( $_ =~ m/START.*$jobId/ ) { 
                $processAlive = 1;
                $attempt = 0;
            }
            if ( $g_cancelRequest{$jobId} && $_ =~ m/^[a-zA-Z]+.*([0-9]{3,7}).*START.*$jobId/ ) {
                foreach(`pgrep -f \'$jobId\'`){
                       chomp $_;
                       $logger->info( $function . " Issuing 'kill -2 \$(pgrep -P $_)' " );
                       system("kill -2 \$(pgrep -P $_)");
                       $logger->info( $function . " Issuing 'kill -2 $_' " );
                       system("kill -2 $_");
                }
            }
        }

        if (!$g_cancelRequest{$jobId} && $attempt < 10 && !$processAlive) {
            $attempt++;
            $logger->info("Wait for 30 more seconds to check if automation kicks in. Attempt $attempt of 10.");
            sleep(30);
            $processAlive = 1;
        }
    }
    $g_jobRunning{$jobId} = 0;
    $logger->info( "LEAVING: " . $function . " jobId:" . $jobId );
}

1;
