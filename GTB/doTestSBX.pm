package SonusQA::GTB::doTestSBX;

=head1 NAME

SonusQA::GTB::doTestSBX

=head1 DESCRIPTION

This module provides functions for running SBX BISTQ jobs.

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
my %g_jobRunning:shared;
my %g_cancelRequest:shared;
my %g_totalTests:shared;
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

sub main{
    $logger=Log::Log4perl->get_logger(__PACKAGE__);

    my $function="main";
    my ($jobTestBed,$JobSubJobs)=@_;
    my ($checkForCancelThread,$monitorJobThread,$timeStamp, $returnCode);
	
    my $updateJobStatusThread;	

    my $jobId=$jobTestBed->[0];
    $AutomationOutputFile=$ENV{"HOME"}."/ats_user/logs/".$JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'}."/Automation_".$jobId.".log";
	
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
	
    $g_jobRunning{$jobId}=1;
    $g_cancelRequest{$jobId}=0;
    $g_totalTests{$jobId}=0;
	

    unless(-e $ENV{"HOME"}."/ats_user/logs/".$JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'}){
        system("mkdir ".$ENV{"HOME"}."/ats_user/logs/".$JobSubJobs->{'ATTRIBUTES'}->{'TESTBED'});
    }
	
    $checkForCancelThread=threads->create(\&checkForCancel,$jobId,$JobSubJobs);
    $monitorJobThread=threads->create(\&monitorJob,$jobId);
    $updateJobStatusThread=threads->create(\&updateJobStatus,$jobId,$AutomationOutputFile,$JobSubJobs->{'ATTRIBUTES'}->{'VERSION'},
                                                                                             $JobSubJobs->{'ATTRIBUTES'}->{'DUT'});
    $returnCode=&kickoffStartAutomation($jobId,$AutomationOutputFile,$JobSubJobs,$jobTestBed->[1]);
    unless($updateJobStatusThread->join()){
        $logger->error("ERROR: Update Job Status Thread Returned ERROR:".$jobId);
    }

    unless($monitorJobThread->join()){
        $logger->error("ERROR: Monitor Job Status Thread Returned ERROR:".$jobId);
    }

    &cleanUp($jobId,$JobSubJobs,$AutomationOutputFile);
	

    $AutomationOutputFile=undef;

    if($checkForCancelThread->join() && $returnCode){
		
        undef($checkForCancelThread);
        undef($monitorJobThread);
        undef($updateJobStatusThread); 
	$logger->info("LEAVING(1): ".$function." jobId:".$jobId);
	$jobId=undef;
        return 1;
    } else {
        undef($checkForCancelThread);
        undef($monitorJobThread);
        undef($updateJobStatusThread);
	$logger->info("LEAVING(0): ".$function." jobId:".$jobId);
	$jobId=undef;
        return 0;	
    }
}

=head1 setupExecutionRequirements()

=over

=item DESCRIPTION:
This will set up requirements to run a job. It calls following subroutines to accomplish this. createTestBedDefinition  - to create testbed definition file, createTestSuiteFile - to create testsuite file & checkoutTestSuites - to checkout files.

=item ARGUMENTS:
Mandatory Args:
testBed - hash containing testbed info related to the job.
JobSubJobs - hash containing job details like suite type, suite path etc.
jobId - Id of a running job.

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

sub setupExecutionRequirements{
    my $function="setupExecutionRequirements";
    my ($testBed,$JobSubJobs,$jobId)=@_;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);

    $logger->info("##########################GENERATING TESTBED: ".$function." jobId:".$jobId."##########################");	
    unless(&createTestBedDefinition($testBed,$jobId)){
        $logger->error("ERROR IN CREATING TESTBED DEFINITION FILE!".$jobId);
	$logger->info("LEAVING(0): ".$function." jobId:".$jobId);
        SonusQA::GTB::Scheduler::sendEmail("Failed to create TESTBED DEFINITION FILE!", $jobId);
        return 0;	
    }
    $logger->info("##########################GENERATED TESTBED SUCCESSFULLY: ".$function." jobId:".$jobId."##########################");

    $logger->info("##########################CHECKING OUT SUITES: ".$function." jobId:".$jobId."##########################");
    unless(&checkoutTestSuites($JobSubJobs,$jobId)){
        $logger->error("ERROR IN CHECKING OUT SUITES!:".$jobId);
        $logger->info("LEAVING(0): ".$function." jobId:".$jobId);
        return 0;
    }
    $logger->info("##########################CHECKINGED OUT SUITES SUCCESSFULLY: ".$function." jobId:".$jobId."##########################");

    $logger->info("##########################GENERATING TESTSUITE FILE: ".$function." jobId:".$jobId."##########################"); 
    unless(&createTestSuiteFile($JobSubJobs,$jobId)){
        $logger->error("ERROR IN CREATING TESTSUIT FILE!:".$jobId);
	$logger->info("LEAVING(0): ".$function." jobId:".$jobId);
        SonusQA::GTB::Scheduler::sendEmail("Failed to create TESTSUIT FILE", $jobId);
        return 0;
    }
    $logger->info("##########################GENERATED TESTSUITE FILE SUCCESSFULLY: ".$function." jobId:".$jobId."##########################");

    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
    return 1;
}


=head1 cleanUpSuite()

=over

=item DESCRIPTION:
This subroutine cleans suite folder after each suite execution

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

sub cleanUpSuite{
    my $function="cleanUpSuite";
    my ($jobId,$jobSubJobs,$AutomationOutputFile)=@_;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);

    $logger->info($function." Deleting the testsuiteList, testbedDefinition and the checked out suites ");
    system ("rm -rf ".$ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl ; rm ".$ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl");
    foreach (keys %{$jobSubJobs}){
        next if ($_ =~ m/ATTRIBUTES/);
        $logger->info($function." Deleting : ".$jobSubJobs->{$_}->{'checked_out_dir'});
        system ("rm -rf  $jobSubJobs->{$_}->{'checked_out_dir'}"); # removing all checked-out files
    }

    $logger->info("LEAVING: ".$function." jobId:".$jobId);
    return 1;
}


=head1 cleanUp()

=over

=item DESCRIPTION:
Clean up checkedout suites, if anything left and delete job from threads after the completion of job.

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

sub cleanUp{
    my $function="cleanUp";
    my ($jobId,$jobSubJobs,$AutomationOutputFile)=@_;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
	
    $logger->info($function." Deleting the testsuiteList, testbedDefinition and the checked out suites ");	
    system ("rm -rf ".$ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl ; rm ".$ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl");
    foreach (keys %{$jobSubJobs}){
        next if ($_ =~ m/ATTRIBUTES/);
	$logger->info($function." Deleting : ".$jobSubJobs->{$_}->{'checked_out_dir'});
        system ("rm -rf  $jobSubJobs->{$_}->{'checked_out_dir'}"); # removing all checked-out files
    }
    delete($g_jobRunning{$jobId});
    delete($g_cancelRequest{$jobId});
    delete($g_totalTests{$jobId});

    $logger->info("LEAVING: ".$function." jobId:".$jobId);
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

sub checkForCancel{
    my $function="checkForCancel";
    my ($jobId,$jobSubJobs)=@_;

    $logger->info("ENTERED: ".$function." jobId:".$jobId);
	
    while($g_jobRunning{$jobId}){
        if(SonusQA::GTB::Scheduler::CheckForCancel($jobId)){
             $g_cancelRequest{$jobId}=1;
             $logger->info("CANCEL PROCESSED BY BACKEND jobId:".$jobId);
             foreach (keys %{$jobSubJobs}){
                      next if ($_ =~ m/ATTRIBUTES/);
                      $logger->info($function." Deleting : ".$jobSubJobs->{$_}->{'checked_out_dir'});
                      system ("rm -rf  $jobSubJobs->{$_}->{'checked_out_dir'}"); # removing all checked-out files
             }
  	     $logger->info("LEAVING(0): ".$function." jobId:".$jobId);
             return 0;
        }
        sleep(5);
    }
    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
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

sub updateJobStatus{
    my $function="updateJobStatus";
    my ($jobId,$AutomationOutputFile,$jobVersion,$jobDUT)=@_;
    my ($totalPass,$totalFail,$totalExecuted,$updateRequired,$line,$currentPos,$JobIsAlive,$suitTcRun,@ExecutionSummary,$suitTcPass,$suitTcFail,$CurrentTestCase,$suiteCompleted,$currentSuite,$suiteHistory) ;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
    $totalPass=0;
    $totalFail=0;
    $totalExecuted=0;
    $currentPos=0;
    $updateRequired=0;
    $suiteCompleted = 0;
    $CurrentTestCase='';
    $JobIsAlive=1;
    ($suitTcPass,$suitTcFail) = (0,0);

    sleep(5);

    my $StartTimeReference = [Time::HiRes::gettimeofday];
    my $SuiteStartTimeReference = [Time::HiRes::gettimeofday];
    my $TestSuiteExecInterval = '';
    my $ExecInterval = '';
    my @executionTime = ();
    my (@passedTests, @failedTests);

    while($g_jobRunning{$jobId}){#WHILE JOB IS RUNNING
        if(-e $AutomationOutputFile && -s $AutomationOutputFile ne "0"){ #WAIT TILL SOMETHING IS IN THE FILE
             SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_job SET URLtoLogs='".$AutomationOutputFile."' WHERE JobId='".$jobId."'" );# NOW THAT THE JOB OFFICIALLY STARTERD UPDATE DB OF WHERE THE LOG IS
             while($JobIsAlive){#WHILE JOB IS ALIVE
                 if(!$g_jobRunning{$jobId}){$JobIsAlive=0;} #ONCE JOB HAS FINISHED CYCLE THROUGH LOG ONE LAST TIME
                 open(LOGREADER,"<",$AutomationOutputFile);
                 seek(LOGREADER,$currentPos,0);#GO TO POSITION LEFT OFF FROM
                 while($line = <LOGREADER> ){#IF SOMETHING TO READ 
                     if($line =~ m/.*SUITE.*::(.*)$/){
                        $currentSuite = $1;
                        $currentSuite =~ s/\s//g;
                        $suiteHistory .= ($suiteHistory eq "") ? $currentSuite : "->".$currentSuite; 
                        SonusQA::GTB::Scheduler::jobStatusUpdate("Running :$suiteHistory",$jobId);
#                        &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT(SUBSTRING(JobStatus, 1, CHAR_LENGTH(JobStatus) - 3),'[s]') WHERE JobId='".$jobId."' AND JobStatus like '".$currentSuite."[%'");
                     }

                     if($line =~ m/[:](\s).*\s[:]\s[0-9]+[:]\s((PASS|FAIL).*?(\d+))/){#LOOK FOR A PASS OR FAIL FROM FILE
                         $logger->debug("TC UPDATE FOUND");	
                         if( $3 eq "PASS" ) {
                             $totalPass++;
                             push (@passedTests, $4);
                             $suitTcPass++;
                         }
                         elsif( $3 eq "FAIL" ) {
                             $totalFail++;
                             push (@failedTests, $4);
                             $suitTcFail++;
                         }
  		         $CurrentTestCase="$1-$4";		
                         $totalExecuted++;
                         $updateRequired=1;
                         push(@ExecutionSummary,$2);
                         $suitTcRun++;	
                     }
					
                     #if we see the testcase completion overview
                     if($line=~ m/[:](.*)[:]\s+Test Suite Exec Duration\s+[:]\s+([0-9|:]+)/){
                         $logger->debug("SUITE ENDED-> SUITE: ".$1." Execution Length: ".$2);
                         $currentSuite=$1;
                         my $executionLength=$2;
                         $currentSuite =~ s/\s//g;
						
                         #grabs the number of tc in the suite so we can compare later
                         my $tcInSuite=&SonusQA::GTB::Scheduler::dbCmd("SELECT COUNT(TestCaseId) FROM ats_sched_suite_test,ats_sched_suite ".
                                                                       "WHERE ats_sched_suite_test.SuiteId=ats_sched_suite.SuiteId ".
                                                                       "AND ats_sched_suite.SuiteName='".$currentSuite."' ".
                                                                       "AND ats_sched_suite.DUT='".$jobDUT."'".
                                                                       "AND find_in_set('".$jobVersion."',ats_sched_suite.Version)");
                         $logger->debug("Executed: ".$suitTcRun." OUT OF ".$tcInSuite->[0]);

                         # storing the summary of current suit
                         @executionTime = reverse( ( gmtime( int tv_interval ($SuiteStartTimeReference)))[0..2] );
                         $TestSuiteExecInterval = sprintf("%02d:%02d:%02d", $executionTime[0], $executionTime[1], $executionTime[2]);
						
                         #if we ran the entire suite
#                         if($tcInSuite->[0] == $suitTcRun){
                              $logger->debug("UPDATING EXECUTION LENGTH FOR ".$currentSuite);
                              #$executionLength=(substr($executionLength,0,2)*60)+(substr($executionLength,3,2));
                              $executionLength =~ s/\s//g;
                              if($executionLength=~ m/(.*)\:(.*)\:(.*)/){
                                 $executionLength = ($1*60)+$2;
                              }
                              $logger->debug("UPDATE ats_sched_suite SET LastExecDuration='".$executionLength."'".
                                                              " WHERE SuiteName='".$currentSuite."' AND DUT='".$jobDUT."'".
                                                              " AND find_in_set('".$jobVersion."',Version)");
                              &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_suite SET LastExecDuration='".$executionLength."'".
                                                              " WHERE SuiteName='".$currentSuite."' AND DUT='".$jobDUT."'".
                                                              " AND find_in_set('".$jobVersion."',Version)");	
#                          }
                          $suitTcRun=0;
                          $suitTcPass=0;
                          $suitTcFail=0;
                          $suiteCompleted=1;
#                          &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT(SUBSTRING(JobStatus, 1, CHAR_LENGTH(JobStatus) - 3),'[c]') WHERE JobId='".$jobId."' AND JobStatus like '".$currentSuite."[%'");
#                          $SuiteStartTimeReference = [Time::HiRes::gettimeofday];
                     }
					
                     if($updateRequired ){
                          SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_job SET TotalTests='".$g_totalTests{$jobId}.
                                                         "', ExecTests='".$totalExecuted."', Pass='".$totalPass."', Fail='".$totalFail . 
                                                         (((scalar @passedTests) >0) ? "', TestsPassed='" . join(',',@passedTests) : '') .
                                                         (((scalar @failedTests)>0) ? "', TestsFailed='".join(',',@failedTests) :'') . 
                                                         "' WHERE JobId='".$jobId."'");
#                          SonusQA::GTB::Scheduler::jobStatusUpdate("Running :$currentSuite -> $CurrentTestCase (".($totalExecuted+1).") of ".$g_totalTests{$jobId},$jobId)  if ($totalExecuted < $g_totalTests{$jobId} ); #not needed as we have http://wiki.sonusnet.com/pages/viewpage.action?spaceKey=SVT&title=Active+jobs+in+BISTq to monitor jobs
                          my $now_string = strftime "%Y-%m-%d %H:%M:%S", localtime;
#                          &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT(SUBSTRING(JobStatus, 1, CHAR_LENGTH(JobStatus) - 3),'[s]',' $now_string') WHERE JobId='".$jobId."' AND JobStatus like '".$currentSuite."[%'");
                          $updateRequired=0;
                     }			
                    if($suiteCompleted == 1){
                         @passedTests=();
                         @failedTests=();
                         $suiteCompleted=0;
                         
                         @executionTime = reverse( ( gmtime( int tv_interval ($SuiteStartTimeReference)))[0..2] );
                         $ExecInterval = sprintf("%02d:%02d:%02d", $executionTime[0], $executionTime[1], $executionTime[2]);
                        $SuiteStartTimeReference = [Time::HiRes::gettimeofday];
                        $totalPass = 0;
                        $totalFail =0;
                        $totalExecuted = 0;

                          
                     }
                     if(eof(LOGREADER)){#IF NEXT READ WOULD BE EOF, FIND OUT WHERE WE ARE, CLOSE HANDLER
                          sleep(5);
                          $currentPos=tell(LOGREADER);
                          close(LOGREADER);
                          last;
                     }
                 }#END while($line = <LOGREADER> ){ 
            }#END while($g_jobRunning){
        }#END if(-s $AutomationOutputFile ne "0"){
    }#END while($g_jobRunning){	


    if($g_cancelRequest{$jobId}){#if job was cancelled send a summary email
        my $msg;
  	$msg="Summary for ".$jobId." After Cancellation:\n\n\n";
        foreach my $line(@ExecutionSummary){
            $msg.=$line."\n";
        }
	$msg.="\nAutomation log file: ".$AutomationOutputFile."\n";
        SonusQA::GTB::Scheduler::sendEmail($msg,$jobId);
    } 

    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
    return 1;
}

=head1 createTestBedDefinition()

=over

=item DESCRIPTION:
Creates testbed definition file, containing testbed info, required by startAutomation script.

=item ARGUMENTS:
Mandatory Args:
jobTestBed - hash containing testbed info related to the job.
jobId - Id of a running job.

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

sub createTestBedDefinition{
    my $function="createTestBedDefinition";
    my ($jobTestBed,$jobId)=@_;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
    system("touch ".$ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl");
    $logger->info("TESTBED FILE: ".$ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl  ".$function." jobId:".$jobId);
    unless(open(TESTBEDFILE,">", $ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl")){
        $logger->error($function.":".$jobId.": ".$!);
	$logger->info("LEAVING(0): ".$function." jobId:".$jobId);
        return 0;
    }
    my %tempTestbed;
    for(my $index=1; $index<scalar(@{$jobTestBed});$index+=3){
    
          $tempTestbed{$jobTestBed->[$index]}{'order'}=$jobTestBed->[$index+1];
          $tempTestbed{$jobTestBed->[$index]}{'type'} = $jobTestBed->[$index-1];

   }

    print TESTBEDFILE "#!/ats/bin/perl\n";
    print TESTBEDFILE "our \@TESTBED = (\n\n";
    foreach my $testbed (sort {$tempTestbed{$a}->{'order'} <=> $tempTestbed{$b}->{'order'}} (keys %tempTestbed)){ 		
        if($tempTestbed{$testbed}{'type'} =~ m/SBX/i){
            my @ces = split('__', $testbed);

            if ($ces[1] && $ces[1] ne 'SA'){
                 $logger->debug("$function : considering [\"$ces[0],$ces[1]\"] nodes of HA"); 
                 print TESTBEDFILE "[\"$ces[0]\",\"$ces[1]\"], #" . $tempTestbed{$testbed}{'type'}."\n";
            } else {
                 $logger->debug("$function : considering [\"$ces[0]\"] as stand alone");
                 print TESTBEDFILE "[\"$ces[0]\"], #" . $tempTestbed{$testbed}{'type'}."\n";
            }
            next;
        }
        print TESTBEDFILE "[\"".$testbed."\"], #".$tempTestbed{$testbed}{'type'}."\n";
    }
    print TESTBEDFILE ");\n";
	
    close(TESTBEDFILE);
    my $testbed_file = $ENV{"HOME"}."/ats_user/testbedDefinition_$jobId.pl";
    $logger->debug("Your TESTBED Defination file: ".$function." jobId:".$jobId."\n".Dumper(`cat $testbed_file`));
    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
    return 1;
}

=head1 createTestSuiteFile()

=over

=item DESCRIPTION:
Creates testsuite file required by startAutomation script to kickoff test execution.

=item ARGUMENTS:
Mandatory Args:
jobSubJobs - hash containing job details like suite type, suite path etc.
jobId - Id of a running job.

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

sub createTestSuiteFile{
    my $function="createTestSuiteFile";
    my ($jobSubJobs,$jobId)=@_;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
	
    system("touch ".$ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl");
    $logger->info("TEST SUITE FILE".$ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl  ".$function." jobId:".$jobId);
    unless(open(TESTSUITEFILE,">", $ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl")){
        $logger->error($function.":".$jobId.": ".$!);
	$logger->info("LEAVING(0): ".$function." jobId:".$jobId);
        return 0;
    }

    my $mailIds = '';
    $logger->info("TEST SUITE FILE".Dumper($jobSubJobs));
    if (defined $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'} and $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'}) {
        map { $mailIds .= "\'$_\@rbbn.com\',"} split(/\,/, $jobSubJobs->{'ATTRIBUTES'}->{'EMAILID'});
        $mailIds =~ s/\,$//;
    } else {
       $mailIds = "'" . $jobSubJobs->{'ATTRIBUTES'}->{'USERNAME'}."\@rbbn.com". "'";
    }

    my $qcow2_path = $jobSubJobs->{'ATTRIBUTES'}->{'BUILDPATH'} if (defined $jobSubJobs->{'ATTRIBUTES'}->{'BUILDPATH'} and $jobSubJobs->{'ATTRIBUTES'}->{'BUILDPATH'}=~/\.qcow2$/);
	
    my @suitFileHeader=split("~","#!/ats/bin/perl ~
use strict;~
use warnings;~
use ATS;~
use Data::Dumper;~
use SonusQA::SBX5000::SBX5000HELPER;~
use Log::Log4perl qw(get_logger :levels);\n~
our \$TESTSUITE;~
\$TESTSUITE->{USE_CONF_ROLLBACK} =\"no\";~ 

\$TESTSUITE->{STORE_GSXLOGS_IN_SBX} =\"2\";~
\$TESTSUITE->{iSMART_EMAIL_LIST} = [". $mailIds ."];~
\$ENV{ \"ATS_LOG_RESULT\" } =".$jobSubJobs->{'ATTRIBUTES'}->{'TMSUPDATE'}.";~
\$TESTSUITE->{TESTED_RELEASE}= \"$jobSubJobs->{'ATTRIBUTES'}->{'VERSION'}\";~
\$TESTSUITE->{PATH} = '/var/log/sonus/ats_user/'.\$TESTSUITE->{TESTED_RELEASE};~
\$TESTSUITE->{STORE_LOGS} = $jobSubJobs->{'ATTRIBUTES'}->{'STORELOGS'};~
\$TESTSUITE->{BUILD_VERSION} = \"$jobSubJobs->{'ATTRIBUTES'}->{'BUILD'}\";~
\$TESTSUITE->{TESTED_VARIANT} = \"$jobSubJobs->{'ATTRIBUTES'}->{'VARIANT'}\";~
\$TESTSUITE->{SET_COREDUMP_PROFILE} = $jobSubJobs->{'ATTRIBUTES'}->{'SENSITIVECOREDUMPLEVEL'};\n~
\$TESTSUITE->{RERUN_FAILED} = $jobSubJobs->{'ATTRIBUTES'}->{'RERUNFAILED'};\n~
\$TESTSUITE->{ARCHIVE_LOGS} = 1;\n~
\$TESTSUITE->{QCOW2_PATH} = '$qcow2_path';\n~
\$ENV{ \"CMDERRORFLAG\" } = ".$jobSubJobs->{'ATTRIBUTES'}->{'CMDERRORFLAG'}.";~
");

    foreach(@suitFileHeader){
        print TESTSUITEFILE $_;
    }
	
    my $isBRXJob;
    foreach my $suite (keys %{$jobSubJobs}){
        if($suite =~ m/ATTRIBUTES/){next;}
        print TESTSUITEFILE "use $jobSubJobs->{$suite}->{'pacakage'};\n";
        $isBRXJob = ($jobSubJobs->{$suite}->{'pacakage'} =~ /brx/i) ? 1 : 0;
        $logger->debug($suite);
    }

    # if brx suite, add addtional variable BRX_BUILD_VERSION to testsuitefile, which sould be updated for tms results
    # because BUILD_VERSION is being overwritten in SBX5000::setSystem()
    if($isBRXJob) {
        print TESTSUITEFILE "\$TESTSUITE->{BRX_BUILD_VERSION} = \"$jobSubJobs->{'ATTRIBUTES'}->{'BUILD'}\";\n";
    }

    print TESTSUITEFILE "\n\n";

    foreach my $suite (sort {$jobSubJobs->{$a}->{'ORDER'} <=>  $jobSubJobs->{$b}->{'ORDER'}} (keys %{$jobSubJobs})){
        if($suite =~ m/ATTRIBUTES/){next;}
        print TESTSUITEFILE "&". $jobSubJobs->{$suite}->{'pacakage'} . "::runTests(";
        $logger->debug($suite);
        $logger->debug("SuiteID:".$jobSubJobs->{$suite}->{TYPE});
        $logger->debug("DEFAULTS".$jobSubJobs->{'ATTRIBUTES'}->{'DEFAULTTESTS'});
        my $suitePath =$ENV{"HOME"}."/ats_repos/lib/perl/".$jobSubJobs->{$suite}->{'pacakage'}.".pm";
        $suitePath =~ s/::/\//g;
        # shows the stupidity to do patch, i am proving that i will run tests if request for specific testcases or else i will just run all mess present in suite
        # $jobSubJobs->{$suite}->{'TESTCASES'} is undefiled  incase the suite belongs to project `SBC Customer CQs` : Enhancement as per TOOLS-9384
        unless( defined ($jobSubJobs->{$suite}->{'TESTCASES'})) {
           $logger->debug("eq SuiteID and DEFAULTTESTS");
            print TESTSUITEFILE ");\n";
            close(TESTSUITEFILE);
            my $testsuitelist= $ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl";
            $logger->debug("Your TEST Suite file: ".$function." jobId:".$jobId. "\n". Dumper(`cat $testsuitelist`));
            $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
            return 1;
        }
        # yes you are right keeping counting total tests in suite just to update status table such that one will be happy to see in front end
        my (%testcaseid,$testsuiteData,$testcaseCount,%excludetestcase);
        $testcaseCount =0;
        foreach(@{$jobSubJobs->{$suite}->{'TESTCASES'}}){
            $testcaseid{$_} = 1;
        }

        foreach(@{$jobSubJobs->{$suite}->{'EXCLUDETESTCASE'}}){
            $excludetestcase{$_} = 1; # collecting list of test cases to be excluded
        }

        my @testcaseListFromSuite  = `cat $suitePath | awk '/^[[:space:]]*(our|my)*[[:space:]]*\@TESTCASES/,/);/' | sed -e 's/[[:space:]|)|(|;|my|our|\@TESTCASES|=]*//g' | sed -e 's/,/,\\n/g' | sed -e "s/'//g" | awk -F '[#,]' '/^["t]/ {print \$1}' | sed -e 's/["a-zA-Z]*//g'`;
        $logger->debug("Your suite has below TC's \n".Dumper(@testcaseListFromSuite));
        chomp(@testcaseListFromSuite);
        my @testcaseid;
        foreach(@testcaseListFromSuite){
		next unless($testcaseid{$_}); #include testcase if mentioned
                next if($excludetestcase{$_}); #exclude the testcase if menstioned
                push(@testcaseid,$_);
                $testcaseCount++;
	}

        $logger->debug("There were $testcaseCount TC matching(regression flag F/M/L or testcase's menstioned in CONFIG.pm) with the suite provided");
        if($testcaseCount == 0){
            $logger->error($function.":".$jobId.": "."Cannont procceed with execution. Please check if 1) The TC's in the suite match the TC's mapped to feature in TMS. \n 2) Check if you have entered the correct SVN path.");
            $logger->info("LEAVING(0): ".$function." jobId:".$jobId);
            return 0;
        }

        foreach(@testcaseid){
            if ($jobSubJobs->{'ATTRIBUTES'}->{'DEFAULTTESTS'} ne '0' and scalar @{$jobSubJobs->{$suite}->{'TESTCASES'}} > 0) {
                if($testcaseCount == 1 ){
                   $testsuiteData .=  "\"tms".$_."\");\n";
                   $logger->debug("\"tms".$_."\");");
                } else {
                   $testsuiteData .= "\"tms".$_."\",";
                   $logger->debug("\"tms".$_."\",");
                }
            }
            $g_totalTests{$jobId}+=1;
            $testcaseCount--;
            #$testcaseid{$_}++; #mark it as already seen testcase
        }
        if(defined $testsuiteData){
            print TESTSUITEFILE $testsuiteData;
        }
    }
	
    close(TESTSUITEFILE);
    my $testsuitelist= $ENV{"HOME"}."/ats_user/testsuiteList_$jobId.pl";
    $logger->debug("Your TEST Suite file: ".$function." jobId:".$jobId. "\n". Dumper(`cat $testsuitelist`));
    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
    return 1;
}

=head1 checkoutTestSuites()

=over

=item DESCRIPTION:
This API checks out testsuite from svn to same directory structure (creates the if required). Also the pacakge name is edited as required.

=item ARGUMENTS:
Mandatory Args:
jobSubJobs - Hash containing the suite related information
jobId - Id of a running job

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

sub checkoutTestSuites{
    my ($jobSubJobs,$jobId)=@_;

    $logger->info("ENTERED: checkoutTestSuites");
    my $temp_dut = ($jobSubJobs->{'ATTRIBUTES'}->{'DUT'} =~ /sbx5(1|2|0)00/i) ? 'SBX5000' : $jobSubJobs->{'ATTRIBUTES'}->{'DUT'};

    my %checked_out_path; #to check whether svn co is happened for the same path

    foreach my $suite (keys %{$jobSubJobs}){
       next if($suite =~ m/ATTRIBUTES/);
       if (!defined $jobSubJobs->{$suite}->{'PATH'} or !$jobSubJobs->{$suite}->{'PATH'}) {
           $logger->error("LEAVING: checkoutTestSuites - svn path is empty or blank for the -> $suite");
           $logger->info("LEAVING(0): checkoutTestSuites ");
           return 0;
       }

       my $temp_path = $jobSubJobs->{$suite}->{'PATH'};
       $temp_path =~s/^\/QATEST/QATEST/;
       unless  ($temp_path =~ /QATEST/) {
          $temp_path =~ s/[\w.\d_]+\///;
          $temp_path = "QATEST/$temp_dut/$temp_path";
       }
             
       my $destination = $ENV{"HOME"} . "/ats_repos/lib/perl/$temp_path/";
       if (-e $destination and -d $destination) {
          $logger->debug("checkoutTestSuites - Folder($destination) already exist, unable to check out the $suite.");
          return 0;
       }
       if($checked_out_path{$temp_path}){
           $logger->debug("checkoutTestSuites - already checked out the suite '$suite' to directory '$destination', suite path : '$jobSubJobs->{$suite}->{'PATH'}'");
       }
       else{
           unless ( system ("mkdir -p $destination") == 0 ) {
               $logger->error("LEAVING: checkoutTestSuites - unable to create destination directory $destination");
               $logger->info("LEAVING(0): checkoutTestSuites ");
               return 0;
           }

           unless(checkoutImmediates($destination, "http://masterats.sonusnet.com/ats/test/branches/$jobSubJobs->{$suite}->{'PATH'}/")){
               $logger->error("checkoutTestSuites - svn checkout failed to directory '$destination', Suite path : '$jobSubJobs->{$suite}->{'PATH'}', JobID : '$jobId'");
               SonusQA::GTB::Scheduler::sendEmail("Failed to CHECK OUT SUITES!! svn checkout failed to directory '$destination', Suite path : '$jobSubJobs->{$suite}->{'PATH'}', JobID : '$jobId'", $jobId);
               $logger->debug("NEXT: checkoutTestSuites - Going to next test suite");
               delete $jobSubJobs->{$suite};
               next ;
               #return 0;
           }

           $logger->debug("checkoutTestSuites - successfully checked out the suite '$suite' to directory '$destination', suite path : '$jobSubJobs->{$suite}->{'PATH'}'");       

           `chmod -R 777 $destination`;
       }

       # some circus to get the namespace for checked out file
       my $temp_namespace = $destination;
       $temp_namespace =~ s/\/\//\//g;
       $temp_namespace =~ s/.*ats_repos\/lib\/perl//;
       $temp_namespace =~ s/\//\:\:/g;
       $temp_namespace =~ s/(^::|::$)//g;
       $jobSubJobs->{$suite}->{'pacakage'} = "${temp_namespace}::${suite}";
       my $edit_cmd = 'sed -i "s/package.*QATEST::.*/package '  . "${temp_namespace}::${suite};" . '/"' . " ${destination}/${suite}.pm";

       $jobSubJobs->{$suite}->{'checked_out_dir'} = $destination; # to remove checked-out files on completion of test 

       unless (system("$edit_cmd") == 0) {
           $logger->error("LEAVING: checkoutTestSuites - unable to change test suite pacakage name");
           $logger->error("LEAVING: checkoutTestSuites - $edit_cmd - failed");
           $logger->info("LEAVING(0): checkoutTestSuites ");
           return 0;
       }

       $checked_out_path{$temp_path} = 1; #setting it to skip checking out same svn path
    }
    $logger->debug("LEAVING(1): checkoutTestSuites ");

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

sub checkoutImmediates{
    my ($path,$url) = @_;

    my $cmd = ($url) ? "svn co --depth=immediates --username atsinfra --password sonus --no-auth-cache $url $path" : "svn up --set-depth=immediates --username atsinfra --password sonus --no-auth-cache $path";

    my @output= `$cmd  2>\&1`; # check-out using atsinfra and sonus
    unless ( grep (/(Checked out|Updated to|At) revision \d+/, @output)) {
        $logger->error("checkoutImmediates - svn checkout failed to directory '$path'\n Svn command : '$cmd'\n Svn command failure reason : " . Dumper(\@output));
        return 0;
    }

    #need to replace the user path to current user in xml files for SIPP
    my $user_home = qx#echo ~#;
    chomp($user_home);
    `sed -i 's|/home/[a-zA-Z]*|'$user_home'|g' $path/*.xml`;
    my $return = 1;
    foreach (@output){
        if (m/^A\s+(.*)/) {
            my $name = $1;
            if (-d $name){
                unless($name =~ m/log/i) {
                    $logger->debug("checkoutImmediates - updating $name");
                    unless(checkoutImmediates($name)){
                        $return=0;
                        last ;
                    }
                }
                else{
                    $logger->debug("checkoutImmediates - Excluding log directory $name");
                }
            }
        }
    }
    return($return);
}

=head1 kickoffStartAutomation()

=over

=item DESCRIPTION:
This sub-routine kicks off the job and calls various other sub-routines in this module to run a job.

=item ARGUMENTS:
Mandatory Args:
jobId - Running job id.
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

sub kickoffStartAutomation{
    my $function="kickoffStartAutomation";
    my ($jobId,$AutomationOutputFile,$jobSubJobs,$jobTestBed)=@_;
    my $returnCode;
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
    foreach my $suite (sort {$jobSubJobs->{$a}->{'ORDER'} <=>  $jobSubJobs->{$b}->{'ORDER'}} (keys %{$jobSubJobs})){
       next if($suite =~ m/ATTRIBUTES/);
       if ($g_cancelRequest{$jobId}) {
           $logger->info( "Job has been deleted. Abort executing suite - $jobSubJobs->{$suite}->{'PATH'}" );
           next;
       }
       my $tempJobSubJobs->{$suite} = $jobSubJobs->{$suite};
          $tempJobSubJobs->{'ATTRIBUTES'} = $jobSubJobs->{'ATTRIBUTES'};
       $logger->info("RUNNING BISTQ SUITE  ".$function." SUITE: $suite"." jobId:".$jobId); 
       unless(&setupExecutionRequirements($jobTestBed,$tempJobSubJobs,$jobId)){
           $logger->debug("FAILED TO setupExecutionRequirements: ".$function." jobId:".$jobId);
            next;
       }

       if ($g_cancelRequest{$jobId}) {
           $logger->info( "Job has been deleted. Abort executing suite - $jobSubJobs->{$suite}->{'PATH'}" );
           next;
       } else {       
          my $now_string = strftime "%Y-%m-%d %H:%M:%S", localtime;
          &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT('$suite',' [s]','$now_string') WHERE JobId='".$jobId."' AND JobStatus like '".$suite." [%'");
          $logger->info("RUNNING BISTQ SUITE  ".$function." ~/ats_repos/lib/perl/SonusQA/startAutomation -bistq_job_uuid $jobId -def ~/ats_user/testbedDefinition_".$jobId.".pl -tests ~/ats_user/testsuiteList_".$jobId.".pl > ".$AutomationOutputFile." 2>&1 "." jobId:".$jobId);

          $returnCode=system("~/ats_repos/lib/perl/SonusQA/startAutomation -bistq_job_uuid $jobId -def ~/ats_user/testbedDefinition_".$jobId.".pl -tests ~/ats_user/testsuiteList_".$jobId.".pl >> ".$AutomationOutputFile." 2>&1");
          # $returnCode = 1;
          SonusQA::GTB::Scheduler::sendEmail("Executing suite: $suite, Had some problems. Please make sure you have updated all ATS libraries and try again ", $jobId) if($returnCode < 0);
          $now_string = strftime "%Y-%m-%d %H:%M:%S", localtime;
          &SonusQA::GTB::Scheduler::dbCmd("UPDATE ats_sched_test_to_run SET JobStatus = CONCAT(JobStatus,' [c]','$now_string') WHERE JobId='".$jobId."' AND JobStatus like '".$suite." [%'");
          &cleanUpSuite($jobId,$tempJobSubJobs,$AutomationOutputFile);
       }
    }
    if($returnCode < 0){$returnCode=0;}else{$returnCode=1;}
    #sleep(60);

    $logger->info("LEAVING(1): ".$function." jobId:".$jobId);
    return 1;
}

=head1 monitorJob()

=over

=item DESCRIPTION:
This keeps monitoring a running job. If user deletes a job from UI, we see it here and kill a running process to end a job.

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

sub monitorJob{
    my $jobId = shift;
    my $processAlive = 1;
    my $attempt = 0;
    my $function = "monitorJob";
    $logger->info("ENTERED: ".$function." jobId:".$jobId);
    sleep(30);
    while($processAlive){
        $processAlive = 0;
        foreach(`ps uxww`){
            if($_ =~ m/startAutomation.*$jobId/) {
                $processAlive = 1;
                $attempt = 0;
            }
            if ( $g_cancelRequest{$jobId} && $_ =~ m/^[a-zA-Z]+.*([0-9]{3,7}).*startAutomation.*$jobId/ ) {
                foreach(`pgrep -f \'$jobId\'`){
                        chomp $_;
                       $logger->info( $function . " Issuing 'kill -2 $_' " );
                       system("kill -2 $_");
                }
            }
        }
        
        if (!$g_cancelRequest{$jobId} && $attempt < 10  && !$processAlive) {
            $attempt++;
            $logger->info("Wait for 30 more seconds to check if startAutomation kicks in. Attempt $attempt of 10.");
            sleep(30);
            $processAlive = 1;
        }
    }
    $g_jobRunning{$jobId}=0;
    $logger->info("LEAVING: ".$function." jobId:".$jobId);
}
1;
