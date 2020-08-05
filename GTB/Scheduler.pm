package SonusQA::GTB::Scheduler;

use strict;
use warnings;
use SonusQA::GTB::doTestSBX;
use SonusQA::GTB::doTestPSX;
use SonusQA::GTB::INSTALLER;
use SonusQA::Utils;
use Time::HiRes;
use Log::Log4perl::Layout::JSON;
use Log::Log4perl;
use DBI;
use threads;
use threads::shared;
use Thread::Queue;
use Thread::Queue::Any;
use Data::Dumper;


################################################################################################################
##                                        GLOBAL VARIABLES                                                    ##
    ##--------KEY------##
    #    $g_ == GLOBAL SCOPE
    #    _s  == string data
    #    _b  == bool data

#########-----SYSTEM VARIABLES-----##############
my $g_MAX_CONCURRENT_JOBS = 5;  #max number of jobs, if multi job is not specified, will be set to 1 in schedulerStartUpRoutine()

##################################################
$SIG{INT} = \&handleControlC;   #defines what we do on Control-C
$SIG{ALRM}=\&handleALRM;
my %g_cmdLineArguements=@ARGV;  #takes arguments from commandline
my %g_checkForGuiCancel:shared; #object to store bool on whether we should check for cancel from the GUI per job basis
my %g_jobCanceled:shared;       #object to store bool on whether job has been canceled
my %imageInstallRunning:shared; #object to store # of thread instance still in ImageRetrieveInstall() per job basis
my $g_JobsRunning:shared=0;     #number of jobs running, used so we do not exit waitforJobsCompletion() too early
my %cancel_THREAD_POOL:shared;  #object to store TIDs created for checkForJobCancel()
my %imageinstall_THREAD_POOL:shared;#object to store TIDs created for checkForJobCancel()
my %executeJob_THREAD_POOL;     #object to store TIDs created for checkForJobCancel()
my %g_Install_Result:shared;    #has an installation to an element failed? if yes, sets g_Install_Result{jobid} to '1'
my %jobDelay:shared;            #stores array for job delaying algorithm
our $g_jobType_s:shared;        ##testbed JobType (bistq/ISMART)
our $g_logger;                  #Logger Object
my $g_testBedAlias_s;           #testbed alias, passed at commandline
my $g_multiJobExecution_b;      #execute mulitple jobs at a time? passed at commandline
my $g_allowProgramExit_b=1;     #bool for allowing a control-c to exit the program, if set to '0', exit will have to wait till running Job execution finishes
my $g_exitRequested_b=0;        #has control-c been issued? if yes, will be set to '1'

my $g_cancel_IDLE_THREAD_QUEUE = Thread::Queue->new();      #queue to hold Idle checkForJobCancel() threads
my $g_cancel_WORK_QUEUE= Thread::Queue->new();              #queue to hold work for checkForJobCancel()

my $g_executeJob_IDLE_THREAD_QUEUE = Thread::Queue->new();  #queue to hold Idle executeJob() threads
my $g_executeJob_WORK_QUEUE= Thread::Queue::Any->new();     #queue to hold work for executeJob()

my $g_imageInstall_IDLE_THREAD_QUEUE = Thread::Queue->new();#queue to hold Idle ImageRetrieveInstall() threads
my $g_imageInstall_WORK_QUEUE= Thread::Queue::Any->new();   #queue to hold work for ImageRetrieveInstall()

our (%readDatabaseConn,%writeDatabaseConn);
##                               END OF GLOBAL VARIABLES                                                     ##
###############################################################################################################

&schedulerStartUpRoutine();
&createThreadPools();
&queueMonitor(&retrieveTestBedData);

sub schedulerStartUpRoutine{

    my $logpath;

    if(defined($g_cmdLineArguements{'-h'})){# NEED HELP?
        &usage();
    }
    unless(defined($g_cmdLineArguements{'-t'})){# DO WE HAVE THE ALIAS ARGUMENT?
        &usage();
    }
    else{
        $g_testBedAlias_s=$g_cmdLineArguements{'-t'};
    }
    unless(defined($g_cmdLineArguements{'-j'})){
        &usage();
    }
    else{
        $g_jobType_s=$g_cmdLineArguements{'-j'};
    }
    if(defined($g_cmdLineArguements{'-q'})){#TYPE OF QUEUE TO RUN, IF SUPPLIED AND MULTI, THEN WE CAN MULTIPLE JOBS AT A TIME
        if($g_cmdLineArguements{'-q'} eq "multi"){
             $g_multiJobExecution_b=1;
        }else{$g_MAX_CONCURRENT_JOBS=1;}
    }else{$g_MAX_CONCURRENT_JOBS=1;}

    unless($logpath=&createLogger()){die(0);}#CREATES LOGGER
    unless(SonusQA::Utils::db_connect('RODATABASE')){die(0);} # CREATES DB CONNECTION

    threads->create(\&logRotation,${$logpath});
    $g_logger->info("SCHEDULER STARTUP SUCCESSFULL");
}

sub createThreadPools{

    for(1..$g_MAX_CONCURRENT_JOBS){# CREATES THREAD POOL FOR checkForJobCancel()
        my $thr = threads->create(\&checkForJobCancel_ThreadQueue, $g_cancel_WORK_QUEUE);
        $cancel_THREAD_POOL{$thr->tid()} = $g_cancel_WORK_QUEUE;
    }

    for(1..$g_MAX_CONCURRENT_JOBS){# CREATES THREAD POOL FOR executeJob()
        my $thr = threads->create(\&executeJob_ThreadQueue, $g_executeJob_WORK_QUEUE);
        $executeJob_THREAD_POOL{$thr->tid()} = $g_executeJob_WORK_QUEUE;
    }

    for(1..5){# CREATES THREAD POOL FOR ImageRetrieveInstall()
        my $thr = threads->create(\&ImageRetrieveInstall_ThreadQueue, $g_imageInstall_WORK_QUEUE);
        $imageinstall_THREAD_POOL{$thr->tid()} = $g_imageInstall_WORK_QUEUE;
    }

}

sub queueMonitor{
    my $function="queueMonitor";
    my $availableTBElementsRef=shift;

    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());
    my $iteration=0;
    my ($activeJobs,$QueueJobIds,$jobRequirements,$subJobs);
    ##################################################################################################
    ##                                                                                              ##
    #ARRAY REF
    $QueueJobIds=&pollQueue();# GRABS  JOB IDs FROM QUEUE
    unless(ref($QueueJobIds) eq "ARRAY"){
        $g_logger->error("EXPECTING ARRAY REF FROM pollQueue(), received: ".$QueueJobIds);
        return 0;
    }

    if(1>scalar(@{$QueueJobIds})){# IF NO JOBS IN QUEUE SLEEP, TRY AGAIN
        $g_logger->error("Could not find any jobs. Count : " . scalar(@{$QueueJobIds}));
        return 0;
    }
    $iteration++;
    #    HASH REF     HASH REF
    ($jobRequirements,$subJobs)=&retrieveSubJobRequirements($QueueJobIds);#GRAB ALL REQUIREMENTS FOR EACH JOB EXECUTION IN QueueJobIds object
    unless(ref($jobRequirements) eq "HASH" && ref($subJobs) eq "HASH"){
        $g_logger->error("EXPECTING 2 HASH REF FROM retrieveSubJobRequirements(), RECEIVED:".$jobRequirements. "  &&  ". $subJobs );
        return 0;
    }

    unless(keys %{$subJobs}){
        $g_logger->error("NO ELIGIBLE JOBS AFTER REQUIRMENTS");
        return 0;
    }

    if($g_exitRequested_b){&handleControlC();}# CHECK FOR CONTROL-C
    $g_allowProgramExit_b=0;#DISALLOW CONTROL C

    #             ARRAY        HASH             HASH     HASH
    &startRunJobs($QueueJobIds,$jobRequirements,$subJobs,$availableTBElementsRef);# START EXECUTION PROCESS
    &waitforJobsCompletion();# MAIN THREAD WILL ENTER HERE AND WAIT FOR ALL SUB-THREADS TO FINISH

    undef($activeJobs);# CLEAN OBJECT
    undef($QueueJobIds);
    undef($jobRequirements);
    undef($subJobs);

    $g_allowProgramExit_b=1;# ALLOW CONTROL C
    $g_logger->info($function.":FINISHED SCHEDULER ITERATION");
    $g_logger->info("iteration:".$iteration." COMPLETE!");
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
}

sub usage{

    print "\n ERROR: scheduler should not be run manually. Contact ATS TEAM for more information \n";
    #print "\n USAGE: ./scheduler.pl -t TESTBEDALIAS -j JOBTYPE [-q single|multi] [-lp logpath] \n";
    exit(0);
}

sub createLogger{
    my ($logpath,$conf);

    $logpath="$ENV{HOME}/ats_repos/lib/perl/SonusQA/GTB/".$g_testBedAlias_s;
    if(defined($g_cmdLineArguements{'-lp'})){$logpath=$g_cmdLineArguements{'-lp'}."/".$g_testBedAlias_s;}else{$logpath="$ENV{HOME}/ats_repos/lib/perl/SonusQA/GTB/".$g_testBedAlias_s;}# USER CAN DEFINE THE ROOT LOGGING PATH
    unless(-d $logpath){# IF PATH DOES NOT EXIST, CREATE PATHS NEEDED BY THE SCHEDULER
        system("mkdir ".$logpath);
        system("mkdir ".$logpath."/oldLogs/");
    }

    $Log::Log4perl::DateFormat::GMTIME = 1;
    Log::Log4perl::MDC->put('jobuuid', "Unknown"); #TOOLS-8492
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    $year += 1900;
    $mon  += 1; # Zero-based...

    my $index = sprintf("log4perl-%d-%02d",$year,$mon);

    # Current ATS puts the package/sub name in the logmsgs - so we define a new conversion specifier (cspec) to strip them out
    # sub is called with the following args (see perldoc for ::PatternLayout) ($layout, $message, $category, $priority, $caller_level);
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('Z', sub {
        # Strip category from logmsgs
        # Cat is typically SonusQA.Utils.subroutine (always dots)
        # Logmsgs would typically be SonusQA::Utils.subroutine
        my $cat = $_[2];
        $cat =~ s/\./\[\.:\]+/g; # Form cat regexp matching . or : separator
        $_[1] =~ s/^$cat[\s:]+// ; # Strip the category plus any trailing whitespace/ colon from the message.
        return $_[1];
    });

    $conf="log4perl.rootLogger=DEBUG, DEBUG,INFO,ERROR,JSON
           log4perl.appender.DEBUG=Log::Log4perl::Appender::File
           log4perl.appender.DEBUG.filename=$logpath/SchedulerDEBUG.out
           log4perl.appender.DEBUG.mode=append
           log4perl.appender.DEBUG.recreate=1
           log4perl.appender.DEBUG.recreate_check_interval=0
           log4perl.appender.DEBUG.layout=PatternLayout
           log4perl.appender.DEBUG.layout.ConversionPattern=[%d]|%L|%c| - %m%n

           log4perl.appender.INFO=Log::Log4perl::Appender::Screen
           log4perl.appender.INFO.stderr=0
           log4perl.appender.INFO.layout=PatternLayout
           log4perl.appender.INFO.layout.ConversionPattern=[%d]|%L|%c| - %m%n
           log4perl.appender.INFO.Threshold=INFO

           log4perl.appender.ERROR=Log::Log4perl::Appender::File
           log4perl.appender.ERROR.filename=$logpath/SchedulerERROR.out
           log4perl.appender.ERROR.mode=append
           log4perl.appender.ERROR.recreate=1
           log4perl.appender.ERROR.recreate_check_interval=0
           log4perl.appender.ERROR.layout=PatternLayout
           log4perl.appender.ERROR.layout.ConversionPattern=[%d]|%L|%c| - %m%n
           log4perl.appender.ERROR.Threshold=ERROR

           log4perl.appender.JSON=Log::Log4perl::Appender::File
           log4perl.appender.JSON.filename=$logpath/SchedulerDEBUG.jsonlog
           log4perl.appender.JSON.mode=append
           log4perl.appender.JSON.recreate=1
           log4perl.appender.JSON.recreate_check_interval=0
           log4perl.appender.JSON.layout = Log::Log4perl::Layout::JSON
           log4perl.appender.JSON.layout.include_mdc = 1
           log4perl.appender.JSON.layout.max_json_length_kb = 100
           log4perl.appender.JSON.layout.field.message = %Z
           log4perl.appender.JSON.layout.field.level = %p
           log4perl.appender.JSON.layout.field.module = %M
           log4perl.appender.JSON.layout.field.line = %L
           log4perl.appender.JSON.layout.field.pid = %P
           log4perl.appender.JSON.layout.field.category = %c
           log4perl.appender.JSON.layout.field.file = %F
           log4perl.appender.JSON.layout.field.genhost = %H
           log4perl.appender.JSON.layout.field.\@timestamp = %d{yyyy-MM-ddTHH:mm:ss.SSS}Z

           log4perl.logger=DEBUG";


    Log::Log4perl->init(\$conf);

    $g_logger=Log::Log4perl->get_logger(__PACKAGE__);
    return \$logpath;
}

sub retrieveTestBedData{

    # RETRIEVES ELEMENTS STORED UNDER THE TESTBED ALIAS, CREATES A OBJECT TO BE POLLED AGAINST FOR SCHEDULED JOBS AND THEIR REQUIREMENTS ###

    my $function="retrieveTestBedData";
    my ($queryResult,$index,$elementStatus,%availableTestBedElements);
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    $queryResult=&dbCmd("SELECT TestBedOrder,Status,sons_nelement_alias,sons_objtype_name,ElementType FROM ats_sched_testbed,sons_nelement,sons_objtype ".
                              "WHERE sons_nelement.sons_nelement_objtype_uuid=sons_objtype.sons_objtype_uuid ".
                              "AND sons_nelement.sons_nelement_uuid=ats_sched_testbed.Element AND ats_sched_testbed.TestBedAlias=\'".$g_testBedAlias_s."\' order by TestBedOrder");

    foreach my $row (@{$queryResult}) {
        if($row->{'ElementType'} eq 'N' and $row->{'Status'} =~ m/[BUO]/){
            $elementStatus = 0;
        }elsif($row->{'ElementType'} eq 'S' and $row->{'Status'} =~ m/[BO]/){
            $elementStatus = 0;
        }else {
            $elementStatus = 1;
        }

        unless(defined($availableTestBedElements{$row->{'sons_objtype_name'}})){
            $availableTestBedElements{$row->{'sons_objtype_name'}}=[];
        }
        push(@{$availableTestBedElements{$row->{'sons_objtype_name'}}},[$elementStatus, $row->{'sons_nelement_alias'},$row->{'TestBedOrder'},$row->{'ElementType'}]);
    }

    return \%availableTestBedElements;
}

sub handleControlC {
    if($g_allowProgramExit_b){
        print "\n***************************************************************************\n";
        print "***************** SCHEDULER PROCESS ABORTED BY USER *********************\n";
        print "***************************************************************************\n\n";
        exit(0);
    } else {
        $g_exitRequested_b=1;
        print "\n***************************************************************** *********\n";
        print "***************** CANT EXIT AT THIS TIME, IN MIDDLE OF JOB ******************\n";
        print "***************EXIT REQUEST RECORED, WILL EXIT WHEN JOB ENDS*****************\n\n";
        sleep(1);
    }
}

sub handleALRM{
    print "\n ALARM WAS TRIGGERED!\n";
}

sub logRotation{
    my $function="logRotation";
    my ($logpath)=@_;

    my $startDate=`date +%F`;
    while(1){
       my $currentDate=`date +%F`;
       sleep(600);
       if($startDate ne $currentDate){
           $g_logger->info("LOG ROTATION OCCURED AT ". `date`);
           system("mv $logpath/SchedulerERROR.out $logpath/oldLogs/SchedulerERROR.".$startDate);
           system("mv $logpath/SchedulerDEBUG.out $logpath/oldLogs/SchedulerDEBUG.".$startDate);
           # These can be large, and have been uploaded to ES anyway - only save previous day.
           system("mv $logpath/SchedulerDEBUG.jsonlog $logpath/oldLogs/SchedulerDEBUG.jsonlog");
           $startDate=$currentDate;
       }
    }
}

sub pollQueue{
    ##
    #    GRABS JOBS FROM QUEUE SCHEDULED AGAINTS A PARTICULAR TESTBED ALIAS    #

    my(@EligibleJobs,$match,@jobQueue);
    my $result= dbCmd("SELECT DISTINCT queue.JobId FROM ats_sched_job_queue as queue ".
                          "INNER JOIN ats_sched_job as job ON  queue.JobId=job.JobId ".
                          "JOIN ats_sched_testbed as testbed ON job.TestbedId=testbed.TestBedId ".
                          "WHERE testbed.TestBedAlias='".$g_testBedAlias_s."' ".
                          "ORDER BY Qslot LIMIT 0, ".(($g_MAX_CONCURRENT_JOBS*2)-1));

    Log::Log4perl::MDC->put('jobuuid', $result->[0]->{'JobId'}); #TOOLS-8492

    foreach my $job (@{$result}){
       push(@jobQueue, $job->{'JobId'});
    }

    return &Build_TestDelayLogic(\@jobQueue);
}

sub Build_TestDelayLogic{
    ##
    #   1)Creates 2 hash entries for 10 topmost jobs in queue
    #        Every Job starts at [0,0], left values is for how many execution cycles the job must wait
    #        right value represents number of execution cycles waited
    #   2)when left == right, job is eligible for execution.
    #   3)each istance where we poll the build and it is not complete we increment the left value and zero out the right value(sub executeJob)
    #   4)each execution cycle we increment the right value IF the job is required to wait for N execution cycles
    ##

    my $queue=shift;
    my (@EligibleJobs,$match);

    unless(ref($queue) eq "ARRAY"){
        return;
    }

    foreach my $jobId(@{$queue}){
        unless(defined($jobDelay{"Wait_Req".$jobId})){#CHECK TO SEE IF IT HAS BEEN PROCESSED BEFORE
            $jobDelay{"Wait_Req".$jobId}=0;
            $jobDelay{"Wait_Com".$jobId}=0
        }
        $g_logger->debug("[".$jobDelay{"Wait_Req".$jobId}.",".$jobDelay{"Wait_Com".$jobId}."]");
        if($jobDelay{"Wait_Req".$jobId}==$jobDelay{"Wait_Com".$jobId}){#IF JOB'S ITERATION PENALTY == ITERATIONS WAITED
            push(@EligibleJobs,$jobId);# MAKE IT ELIGIBLE FOR EXECUTION SELECTION
        }
    }

    foreach my $key(grep{/Wait_Req/} keys %jobDelay){#GOING TO SCAN ALL KEYS IN THE JOB DELAY LOGIC AND MAKE SURE WE ONLY HAVE CURRENT QUEUED JOBS. ie WE DONT WANT TO KEEP JOBS THAT HAVE BEEN CANCELED OR MOVED DOWN THE QUEUE
        my $jobId=substr($key,8);
        foreach my $jobInQ(@{$queue}){
            if($key =~ m/$jobInQ/){
                $match=1;
                last;
            }
        }
        unless($match){#IF JOB IS NOT SEEN
            foreach(grep{/$jobId/} keys %jobDelay){
                delete($jobDelay{$_});
            }
            next;
        }
        $match=0;
        if($jobDelay{"Wait_Req".$jobId}==0){next;}#IF JOB HAS NOT BEEN PROCESSED FOR A DELAY
        $jobDelay{"Wait_Com".$jobId}+=1;#INCREMENT INTERATION WAITED FOR JOBS
    }
    return \@EligibleJobs;
}

sub retrieveSubJobRequirements{
    # FOR A PARTICULAR JOB, DETERMINES WHAT ELEMENT REQUIREMENTS WILL BE REQUIRED AND CREATS AN OBJECT CONTAINING ALL SUITES/TESTCASES THAT WILL EXECUTED

    my $function="retrieveJobData";
    my $QueueJobIdList=shift;
    my (%jobRequirements,$jobSubJobs, $invalidTestCases,$validTestCases);
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    $validTestCases='';
    my %regression = ( S =>  '1',
                       L  => '2',
                       M  => '3\',\'2',
                       F  => '0\',\'2\',\'3\',\'4');
    foreach my $JobId (@{$QueueJobIdList}){#FOREACH JOB WE HAVE IN OUR LIST
        my $index=0;
        $invalidTestCases='';
        $validTestCases='';

        my (%requiredElements,$jobSubJobResult);
        $jobRequirements{$JobId}=[];

        sleep 2; #some time i felt tms was slow to insert the records into mysql database, hence adding 2 seconds
        $jobSubJobResult=dbCmd("SELECT Type,TestsToRun,TestSuiteOrder FROM ats_sched_test_to_run WHERE JobId='".$JobId."' ORDER BY TestSuiteOrder");#single testcases will receive priority
        my $ats_sched_jobQuery=dbCmd("SELECT Build,Version,BuildFlag,JobAlias,UserName,RunDefaultTests,EmailIds,StoreLogs,SensitiveCoredumpLevel,CmdErrorFlag,ReRunFailed,TestsFailed,ExcludeTestcase,CCView FROM ats_sched_job WHERE JobId='".$JobId."'");

        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'RERUNFAILED'}= ($ats_sched_jobQuery->[0]->{'ReRunFailed'} == 1) ? 1 : 0;
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'STORELOGS'} = ($ats_sched_jobQuery->[0]->{'StoreLogs'} !~ /\d/) ? 0 : $ats_sched_jobQuery->[0]->{'StoreLogs'};
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'BUILD'}= $ats_sched_jobQuery->[0]->{'Build'};
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'SENSITIVECOREDUMPLEVEL'} = ($ats_sched_jobQuery->[0]->{'SensitiveCoredumpLevel'} == 1) ? 1 : 0;
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'EXCLUDETESTCASE'} = $ats_sched_jobQuery->[0]->{'ExcludeTestcase'}; #Exclude these test cases from run
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'FAILEDTESTCASE'} = $ats_sched_jobQuery->[0]->{'TestsFailed'};  #include these testcases from run

        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'BUILDPATH'}=$ats_sched_jobQuery->[0]->{'CCView'}; #CCView
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'USERNAME'}=$ats_sched_jobQuery->[0]->{'UserName'}; #5
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'EMAILID'}=($ats_sched_jobQuery->[0]->{'EmailIds'} ne 'NULL') ? $ats_sched_jobQuery->[0]->{'EmailIds'} : $ats_sched_jobQuery->[0]->{'UserName'}; #6, 5
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'VERSION'}=$ats_sched_jobQuery->[0]->{'Version'}; #7
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'JOBALIAS'}=$ats_sched_jobQuery->[0]->{'JobAlias'}; #8
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'BUILDFLAG'}=$ats_sched_jobQuery->[0]->{'BuildFlag'}; #9
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'DEFAULTTESTS'}=$ats_sched_jobQuery->[0]->{'RunDefaultTests'}; #10
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'CMDERRORFLAG'}=($ats_sched_jobQuery->[0]->{'CmdErrorFlag'} ne 'NULL') ? $ats_sched_jobQuery->[0]->{'CmdErrorFlag'} : 0; #11
        $jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'ORDER'} = '200';

        foreach my $subJob (@{$jobSubJobResult}){ #FOREACH SUBJOB TO PROCESS

            if($subJob->{'Type'} =~ m/SuiteID/){#REQUEST FOR ENTIRE SUITE
                 my $elementRequirements=dbCmd("SELECT RequiredElement FROM ats_sched_suite WHERE SuiteId='".$subJob->{'TestsToRun'}."'");# GET REQUIRED ELEMENTS FROM SUITE TABLE
                 my %tempRequiredElements = ();
                 foreach my $element(split(',',$elementRequirements->[0]->{'RequiredElement'})){#calculate the required elment for perticular suite
                     next unless($element ne 'NULL');
                     $tempRequiredElements{$element}++;
                 }
                 # Make sure we have required element as maximum entry
                 foreach my $element (keys %tempRequiredElements) {
                     $requiredElements{$element} = $tempRequiredElements{$element} if (!defined $requiredElements{$element} or ($requiredElements{$element} < $tempRequiredElements{$element}));
                 }
                 my $suiteName=dbCmd("SELECT SuiteName FROM ats_sched_suite WHERE SuiteId='".$subJob->{'TestsToRun'}."'");#GETS SUITNAME

                 if(defined($jobSubJobs->{$JobId}->{$suiteName->[0]->{'SuiteName'}})){# Checks To Ensure We have not already added a sub job for this suite
                     next;
                 }

                 $jobSubJobs=&buildSubJobsObject($jobSubJobs,$JobId,$suiteName->[0]->{'SuiteName'},"",'SuiteID');

                 unless(ref($jobSubJobs) eq "HASH"){
                    $g_logger->error("EXPECTING HASH REF FROM buildSubJobsObject(), RECEIVED: ".$jobSubJobs);
                 }


                 @{$jobSubJobs->{$JobId}->{$suiteName->[0]->{'SuiteName'}}->{'EXCLUDETESTCASE'}} = split(',',$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'EXCLUDETESTCASE'});
                 if($jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'FAILEDTESTCASE'} ne ''){
                    my @testcase = split(',',$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'FAILEDTESTCASE'});
                    @{$jobSubJobs->{$JobId}->{$suiteName->[0]->{'SuiteName'}}->{'TESTCASES'}} = @testcase;
                 }elsif(defined $regression{$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'DEFAULTTESTS'}}){

                    my $projectName=dbCmd("SELECT sons_project_title FROM sons_project, sons_feature WHERE sons_feature_uuid=(SELECT FeatureUuid FROM ats_sched_suite WHERE SuiteId='".$subJob->{'TestsToRun'}."' ) AND sons_feature_project_uuid = sons_project_uuid");#GETS PROJECT NAME , This will skip the L,MF regression flags and run the entire suite : Enhancement as per TOOLS-9384
                    next unless($projectName->[0]->{'sons_project_title'} ne 'SBC Customer CQs');#TOOLS-15016 : This will help us run single TC in case of customer CQ

                    my $testCasesHash = dbCmd("SELECT sons_testcase_id FROM sons_testcase AS tc JOIN ats_sched_suite AS s ON tc.sons_testcase_feature_uuid = s.FeatureUuid JOIN ats_sched_test_to_run AS run ON run.TestsToRun=s.SuiteId WHERE run.JobId='".$JobId."' AND run.TestsToRun='".$subJob->{'TestsToRun'}."' AND tc.sons_testcase_status = 'A' AND tc.sons_testcase_regression_flag IN ('".$regression{$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'DEFAULTTESTS'}}."')");#GETS TestCases

                    my @testCasesArray;
                    foreach my $tc (@{$testCasesHash}){
                        push(@testCasesArray, $tc->{'sons_testcase_id'});
                    }
                    @{$jobSubJobs->{$JobId}->{$suiteName->[0]->{'SuiteName'}}->{'TESTCASES'}} = @testCasesArray;
                 }
                $jobSubJobs->{$JobId}->{$suiteName->[0]->{'SuiteName'}}->{'ORDER'}=$subJob->{'TestSuiteOrder'};

            } elsif ($subJob->{'Type'} =~ m/Single/){ #REQUEST FOR SINGLE TC
                 my $exists=0;
                 foreach my $testcase(split(',',$subJob->{'TestsToRun'})){#FOREACH INVIDUAL TESTCASES PROVIDED
                     # HAVE TO GET THE SUITE ID BASED OFF TESTCASE ID, VERSION and DUT
                     my $suite=dbCmd("SELECT DISTINCT t1.SuiteId,t2.SuiteName from ats_sched_suite_test as t1, ats_sched_suite as t2, ats_sched_test_to_run as t3 ".
                                           "where t1.testcaseid in (".$testcase.") and t1.suiteid = t2.suiteid and t1.suiteid = t3.suiteid ".
                                           "and t2.DUT in (select distinct ats_sched_testbed.DUT from ats_sched_job ".
                                           "join ats_sched_testbed on (ats_sched_job.TestbedId = ats_sched_testbed.TestBedId and ".
                                           "ats_sched_job.JobId = '".$JobId."'))");

                     unless(defined($suite->[0]->{'SuiteId'})){#If this is not defined, test case was not configured for version &| DUT running against
                         $invalidTestCases.=$testcase.", ";
                         next;
                     }

                     $validTestCases.=$testcase.",";#KEEP ONGOING STRING OF VALID TESTCASES
                     my $elementRequirements=dbCmd("SELECT RequiredElement FROM ats_sched_suite WHERE SuiteId='".$suite->[0]->{'SuiteId'}."'");# GET REQUIRED ELEMENTS FROM SUITE
                     my %tempRequiredElements = ();
                     foreach my $element(split(',',$elementRequirements->[0]->{'RequiredElement'})){ ##calculate the required elment for perticular suite
                          next unless($element ne 'NULL');
                          $tempRequiredElements{$element}++;
                     }
                     # Make sure we have required element as maximum entry
                     foreach my $element (keys %tempRequiredElements) {
                          $requiredElements{$element} = $tempRequiredElements{$element} if (!defined $requiredElements{$element} or ($requiredElements{$element} < $tempRequiredElements{$element}));
                     }
                     #                                                  SUITE Name                 TC ID
                     $jobSubJobs=&buildSubJobsObject($jobSubJobs,$JobId,$suite->[0]->{'SuiteName'},$testcase,'Single');#BUILDS OBJECT WITH RELATIONSHIP BETWEEN SUITES AND THEIR TESTCASES
                     unless(ref($jobSubJobs) eq "HASH"){
                          $g_logger->error("EXPECTING HASH REF FROM buildSubJobsObject(), RECEIVED: ".$jobSubJobs);
                     }
                 }
            } else {
                 $g_logger->error($function.": UNKNOWN SUBJOB TYPE ~ $subJob->{'Type'}");
            }
        }#END while EACH SUBJOB

        if($invalidTestCases ne ''){#IF WE HAVE ANY TEST CASE THAT WAS MARKED AS INVALID, SEND EMAIL AND UPDATE The TESTS to RUN FIELD IN DB
            &sendEmail("TestCase(s):". $invalidTestCases." is/are Not Available For Execution On ".$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'VERSION'}." Contact Your Administrator or Select a Different Version", $JobId);
            dbCmd("UPDATE ats_sched_test_to_run SET TestsToRun ='".$validTestCases."' WHERE JobId='".$JobId."' AND Type='Single'");
        }

        $requiredElements{$jobSubJobs->{$JobId}->{'ATTRIBUTES'}->{'DUT'}}+=1;# ADDS THE DUT AS AN ELEMENT NEEDED

        #foreach(keys %requiredElements ){push(@{$jobRequirements{$JobId}},$_);}#PUSH EACH REQUIREMENT INTO OBJECT FOR EACH Job In QUEUE
        foreach my $elm (keys %requiredElements) {
            map {push (@{$jobRequirements{$JobId}}, $elm) } (1..$requiredElements{$elm});
        }
        unless(scalar(@{$jobRequirements{$JobId}})){
            delete($jobRequirements{$JobId});
            $g_logger->error("NO Requirements In job, removing");
            &popJobFromQueue($JobId);#REMOVES JOB FROM QUEUE
        }
    }# END foreach $JobId
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
    return (\%jobRequirements,$jobSubJobs);
}

sub buildSubJobsObject{
    #   POPULATES JOB'S SUBJOB INFORMATION -- DUT, VERSION, TMSUDATE, AND TESTCASES TO EXECUTE

    my $function="buildSubJobsObject";
    my ($subJobObject,$JobId,$Suite,$type)=@_;
    my ($dbResults,$tmsUpdate,$versionCheck,@versionArray,$epsxElementType);

    unless(ref($subJobObject->{$JobId}->{$Suite}) eq "HASH"){#DETERMINES IF THIS IS FIRST TIME WE'VE SEEN THIS SUITE

        $dbResults=dbCmd("SELECT DISTINCT DUT FROM ats_sched_testbed JOIN ats_sched_job ON ats_sched_testbed.TestBedId=ats_sched_job.TestbedId WHERE ats_sched_job.JobId='".$JobId."'");
        $subJobObject->{$JobId}->{'ATTRIBUTES'}->{'DUT'}=$dbResults->[0]->{'DUT'};

        $subJobObject->{$JobId}->{'ATTRIBUTES'}->{'TESTBED'}=$g_testBedAlias_s;

        if ($subJobObject->{$JobId}->{'ATTRIBUTES'}->{'DUT'} eq 'PSX') {
            $epsxElementType = "'PSX', 'EPSX'";
            $dbResults = dbCmd("SELECT Version FROM ats_sched_suite WHERE SuiteName = '".$Suite."' AND DUT IN ($epsxElementType)");
        } else {
            $dbResults = dbCmd("SELECT Version FROM ats_sched_suite WHERE SuiteName = '".$Suite."' AND DUT = '".$subJobObject->{$JobId}->{'ATTRIBUTES'}->{'DUT'}."'");
        }

        $versionCheck = 0;
        @versionArray = split (',', $dbResults->[0]->{'Version'});
        foreach (@versionArray){
            if ($subJobObject->{$JobId}->{'ATTRIBUTES'}->{'VERSION'} ge '$_' ) {
                $versionCheck = 1;
                $g_logger->debug($function. " The VERSION specified in the job > \'$_\' so we are proceeding with the execution ");
                last;
            }
        }
        unless($versionCheck == 1){
            $g_logger->error($function. " ERROR, The \'VERSION\' specified in the job is less than all the versions supported by the suite ");
            $g_logger->warn($function. " Edit the testsuite \'$Suite\', add the \'VERSION\': \'$subJobObject->{$JobId}->{'ATTRIBUTES'}->{'VERSION'}\'  to the suite and rerun the job ");
            return 0;
        }


        if ($subJobObject->{$JobId}->{'ATTRIBUTES'}->{'DUT'} eq 'PSX') {
            $epsxElementType = "'PSX', 'EPSX'";
            $dbResults = dbCmd("SELECT Path FROM ats_sched_suite WHERE SuiteName = '".$Suite."' AND DUT IN ($epsxElementType)");
        } else {
            $dbResults = dbCmd("SELECT Path FROM ats_sched_suite WHERE SuiteName = '".$Suite."' AND DUT = '".$subJobObject->{$JobId}->{'ATTRIBUTES'}->{'DUT'}."'");
        }
        $subJobObject->{$JobId}->{$Suite}->{"TYPE"} = $type;
        $subJobObject->{$JobId}->{$Suite}->{"PATH"}=$dbResults->[0]->{'Path'};
        $subJobObject->{$JobId}->{$Suite}->{"PATH"} =~ s/\/$//;

        $dbResults=dbCmd("SELECT TMSUpdate,Variant FROM ats_sched_job WHERE JobId='".$JobId."'");
        $subJobObject->{$JobId}->{'ATTRIBUTES'}->{'VARIANT'}=$dbResults->[0]->{'Variant'};
        if($dbResults->[0]->{'TMSUPDATE'} eq "F"){$subJobObject->{$JobId}->{'ATTRIBUTES'}->{'TMSUPDATE'}=0;}
        else{$subJobObject->{$JobId}->{'ATTRIBUTES'}->{'TMSUPDATE'}=1;}
    }

    return $subJobObject;
}

sub startRunJobs{
    #   WE NOW HAVE JOBS FROM QUEUE, THEIR REQUIREMNETS, THEIR SUBJOBS TO EXECUTE, AND THE AVAIABLE ELEMENTS, PROCEEDS TO EXECUTION

    my $function="runJobs";
    #   ARRAY   HASH   HASH   HASH
    my ($queueJobIds,$jobRequirements,$subJobs,$availableTBElementsRef)=@_;
    unless(ref($queueJobIds) eq "ARRAY" && ref($jobRequirements) eq "HASH" && ref($subJobs) eq "HASH" && ref($availableTBElementsRef) eq "HASH"){
        $g_logger->error($function. " ERROR, INPUT DATA INCORRECT, EXPECT ARRAY - HASH - HASH - HASH, RECEIVED: ". $queueJobIds." ".$jobRequirements." ".$subJobs." ".$availableTBElementsRef);
        return;
    }
    my @activeJobThreads;

    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    # ARRAY HASH HASH
    foreach my $job (@{&executionSearch($queueJobIds,$jobRequirements,$availableTBElementsRef,$subJobs)}){#DETERMINES WHAT JOBS CAN WE EXECUTE
        my $tid=$g_executeJob_IDLE_THREAD_QUEUE->dequeue();
        $executeJob_THREAD_POOL{$tid}->enqueue([$job,$subJobs->{$job->[0]}]);# QUESES JOB INTO THREAD POOL executeJob's queue (see executeJob_ThreadQueue())
    }
    sleep(1);
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
}

sub executionSearch{
    #  POPULATES OBJECT WITH ELEMENTS GOING TO BE USED FOR EXECUTION PER JOB

    my $function="executionSearch";

    #   ARRAY    HASH    HASH    PASSED ON RECURSION
    my ($queueRef,$jobRequirements,$tbElements,$subJobs,$jobsToExecute)=@_;
    my (@executing_testbed);
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    #**Phase 2, dont de-reference, use references within algorthim SAVES MEMORY as it recurses

    my @queueJobIds=@{$queueRef};#EACH ELEMENT IS A JOBID, IN QUEUED ORDER
    my %jobRequirments=%{$jobRequirements}; #KEYS ARE JOBIDs
    my %availableTestBedElements=%{$tbElements}; #KEYS ARE ELEMENT TYPES
    my %jobSubJobs=%{$subJobs};

    ###############################################################################
    #   $availableTestBedElements{"ELEMENT TYPE"}->[#]->[0]= 1|0 #free or not     #
    #                                                   [1]="element alias"       #
    #   $jobRequirments{"JOBID"}->[#]= "element type"                             #
    ###############################################################################
    my $currentJobId=shift(@queueJobIds);#pull JobId from Top of Queue
    my %required = ();
    map {$required{$_}++} @{$jobRequirments{$currentJobId}}; # store count of required elemets
    foreach my $element( keys %required){#IF WE GET A REQUIREMENT FOR AN ELEMENT WHICH DOES NOT EXIST
        if(!ref($availableTestBedElements{$element}) or ($required{$element} > scalar @{$availableTestBedElements{$element}})){
            $g_logger->error("ELEMENT: REQUIRED NUMBER OF $element IS NOT AVAILABLE IN TESTBED!, REQUIRED => $required{$element}");
            undef %required;
            &popJobFromQueue($currentJobId);#REMOVES JOB FROM QUEUE
            my @blankArray;
            return \@blankArray;
        }
    }
    undef %required;
    for(my $elementIndex=0; $elementIndex<scalar(@{$jobRequirments{$currentJobId}}); $elementIndex++){# for all requiements in job

        for(my $availableTestBedIndex=0; $availableTestBedIndex<scalar(@{$availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}}); $availableTestBedIndex++){# for all testbed elements of same type as requirement

            if($availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[0]){# if available
                $availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[0]=0;#set unavailable
                push(@executing_testbed,$jobRequirments{$currentJobId}->[$elementIndex]);#STORES ELEMENT TYPE
                push(@executing_testbed,$availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[1]); #store tesbed element alias in current jobs testbed
                push(@executing_testbed,$availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[2]); #store the order of the testbed , needed while creating testbedDefination

                # UPDATES TMS GUI
                my $elementAlias = $availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[1];
                if($availableTestBedElements{$jobRequirments{$currentJobId}->[$elementIndex]}->[$availableTestBedIndex]->[3] eq 'N') {
                    my $query = "UPDATE ats_sched_testbed, sons_nelement SET ats_sched_testbed.Status = 'B' WHERE sons_nelement.sons_nelement_uuid = ats_sched_testbed.Element AND sons_nelement.sons_nelement_alias = '".$elementAlias."'";
                    &dbCmd($query);
                }else {
                    my $query = "SELECT Status, TestBedId, SharedTBUseCount FROM ats_sched_testbed INNER JOIN sons_nelement ON sons_nelement.sons_nelement_uuid = ats_sched_testbed.Element AND sons_nelement.sons_nelement_alias='".$elementAlias."'";
                    my $results = &dbCmd($query);
                    my $count = $results->[0]->{'SharedTBUseCount'} + 1;
                    $query = "UPDATE ats_sched_testbed, sons_nelement SET ats_sched_testbed.Status = 'U', ats_sched_testbed.SharedTBUseCount = $count WHERE sons_nelement.sons_nelement_uuid = ats_sched_testbed.Element AND sons_nelement.sons_nelement_alias='".$elementAlias."'";
                    $g_logger->info("QUERY $function: " . $query);
                    &dbCmd($query);
                }
                last;
            }
        }
    }

    push(@{$jobsToExecute},[$currentJobId,\@executing_testbed]);#STORES JOBID AND ITS TESTBED

    if($g_multiJobExecution_b){# IF WE WANT TO MULTI SCHEDULE, BOOL SET AT CMD LINE ARGUMENTS
        my $match;
        #find more jobs we can execute now
        for(my $queueIndex=0; $queueIndex<scalar(@queueJobIds); $queueIndex++){#for all jobs in queue

            for(my $elementIndex=0; $elementIndex<@{$jobRequirments{$queueJobIds[$queueIndex]}}; $elementIndex++){#for all requirments in each job

                if($jobRequirments{$queueJobIds[$queueIndex]}->[$elementIndex] eq ''){next;}#if element alias is blank move on

                for(my $availableTestBedIndex=0; $availableTestBedIndex<scalar(@{$availableTestBedElements{$jobRequirments{$queueJobIds[$queueIndex]}->[$elementIndex]}}); $availableTestBedIndex++){#for all elements in testbed of '$queue[$queueIndex]->[$jobIndex]' type

                   if($availableTestBedElements{$jobRequirments{$queueJobIds[$queueIndex]}->[$elementIndex]}->[$availableTestBedIndex]->[0]){#if we have a requirement available in testbed
                      $match=1;
                      last;
                   } else {$match=0};
                }#for(all elements of type)
                unless($match){last;}
            }#for(all requirments for job)

            if($match){
                unshift(@queueJobIds,splice(@queueJobIds,$queueIndex,1));# push item to front of queue
                &executionSearch(\@queueJobIds,\%jobRequirments,\%availableTestBedElements,\%jobSubJobs,$jobsToExecute); # RECURSE
                last;
            }
       }#for(all Jobs)
    }

    #    Once we get here the recursion has completed...
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
    $g_logger->info($function.": JOBS IN ITERATION : ".scalar(@{$jobsToExecute}));

    return $jobsToExecute;
}

sub waitforJobsCompletion{
    ##
    #    WAITS FOR ALL EXECUTION THREADS TO FINISH
    ##

    my $function="waitforJobsCompletion";
    my $activeJobs=shift;
    my $exitCount=0;
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    while($g_JobsRunning>0){
        sleep(4);
    }

    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
}

sub checkForJobCancel{
    #   CHECKS TO SEE IF JOB NO LONGER IS IN QUEUE, IF SO, MEANS USER CANCELED VIA GUI

    my $function = "checkForJobCancel";
    my $JobId = shift;
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    $g_jobCanceled{$JobId}=0;
    my $query = "SELECT Deleted FROM ats_sched_job_queue WHERE JobId = '".$JobId."'";
    my $deleted = dbCmd($query);

    while($g_checkForGuiCancel{$JobId} && $deleted->[0]->{'Deleted'} == 0){
        $deleted = dbCmd($query);
        sleep(5);
    }

    if($g_checkForGuiCancel{$JobId}){
        $g_jobCanceled{$JobId}=1;
        &sendEmail("JOB EXECUTION CANCELATION HAS BEEN PROCESSED BY THE BACKEND",$JobId);
    }
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
}

sub executeJob{
    # PERFORMS ALL EXECTION ROUTINES FOR A JOB

    my $function="executeJob";
    my($jobTestBed,$JobSubJobs)=@_;
    my ($checkForJobCancelThread,$timeStamp,$resultReturn);
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    my @testBedArray=@{$jobTestBed->[1]};
    my $JobId=$jobTestBed->[0];
    unless(scalar(@testBedArray)){
        $g_logger->error("TestBed Was Empty at this point, ERROR!");
        return 0;
    }

    &jobStatusUpdate("PREPARING TESTBED FOR EXECUTION",$JobId);#UPDATE STATUS OF JOB

    if($resultReturn=&ImageRetrieveInstall($JobId,@testBedArray,$JobSubJobs->{'ATTRIBUTES'}->{'BUILDFLAG'})){##IMAGE INSTALL
        if($resultReturn==1){#RECEIVED SUCCESS
            &jobStatusUpdate("STARTING TESTCASE(S) EXECUTION",$JobId);
            $g_checkForGuiCancel{$JobId}=1;

            my $tid=$g_cancel_IDLE_THREAD_QUEUE->dequeue();
            $cancel_THREAD_POOL{$tid}->enqueue($JobId);

            my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
            $timeStamp = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
            &dbCmd("UPDATE ats_sched_job SET StartTime='".$timeStamp."' WHERE JobId='".$JobId."'");#UPDATES START TIME
            if(&doTest($jobTestBed,$JobSubJobs)){#SENDS TO SWITCH FOR PROPER AUTOMATION INFRASTRUCTURE
                &sendEmail("Job has been Completed. For any failures in suite execution, Please check the ATS log",$JobId);
            } else {#ERROR IN TC EXECUTION
                $g_logger->error("***************************************************************************");
                $g_logger->error($function.":Thread:threads->tid() Test KickOff Failed --".$JobId);
                $g_logger->error('@testBedArray Contents:');
                for(my $index=0;$index<scalar(@testBedArray);$index+=3){
                    my $string="";
                    $g_logger->error("[".$testBedArray[$index].",".$testBedArray[$index+1]."]");
                }
                $g_logger->error('%JobSubJobs Contents:');
                foreach my $key (keys %{$JobSubJobs}){
                    if($key =~ m/ATTRIBUTES/){next;}
                    $g_logger->error($key.':');
                    foreach(@{$JobSubJobs->{$key}->{'TESTCASES'}}){
                        $g_logger->error("\t".$_);
                    }
                }
                $g_logger->error("***************************************************************************");
                &sendEmail("There Was A Failure Trying To Execute The Testcase(s), Check Your Jobs Configuration or Contact The Administrator",$JobId);
            }
            $g_checkForGuiCancel{$JobId}=0;
            ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
            $timeStamp = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
            &dbCmd("UPDATE ats_sched_job SET EndTime='".$timeStamp."' WHERE JobId='".$JobId."'");

        } elsif ($resultReturn==2){#BUILD&TEST Job, BUILD WAS NOT READY

            &elementStatusUpdate(@testBedArray);
            $jobDelay{"Wait_Req".$JobId}+=1;
            $jobDelay{"Wait_Com".$JobId}=0;
            &sendEmail("Job Has Been Pushed Down Queue ".$jobDelay{"Wait_Req".$JobId}." Places Due To Build Not Being Ready For Execution",$JobId);
            &jobStatusUpdate("Job Delayed ".$jobDelay{"Wait_Req".$JobId}." Execution Cycles",$JobId);
            $g_logger->info($function."JOB:".$JobId."  HAS BEEN DELAYED ".$jobDelay{"Wait_Req".$JobId}." ITERATIONS  ");
            $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
            return 1;
        }
    }
    else {#ERROR IN IMAGE INSTALL PROCESS
        &sendEmail("There Was A Failure During TestBed Preperation, Check Your Jobs Configuration or Contact The Administrator",$JobId);
    }

    &elementStatusUpdate(@testBedArray);
    &popJobFromQueue($JobId);#REMOVES JOB FROM QUEUE

    delete($g_checkForGuiCancel{$JobId});
    delete($g_jobCanceled{$JobId});
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
    return 1;
}

sub ImageRetrieveInstall {
    my $function="ImageRetrieveInstall";
    my ($JobId,@testBedArray,$BuildFlag)=@_;
    my ($index,$exitCount,$dbResults,$failFlag,%requiredElementInfo,@activeElementInstallThreads);

    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());
    $imageInstallRunning{$JobId}=0;

    $dbResults=dbCmd("SELECT DISTINCT CCView,CCViewLoc,Build,DUT,InstalledFlag FROM ats_sched_job, ats_sched_testbed WHERE ats_sched_testbed.TestBedId=ats_sched_job.TestBedId AND ats_sched_job.JobId='".$JobId."'");

    $requiredElementInfo{$dbResults->[0]->{'DUT'}}->{'Build'}=$dbResults->[0]->{'Build'};
    $requiredElementInfo{$dbResults->[0]->{'DUT'}}->{'InstalledFlag'}= $dbResults->[0]->{'InstalledFlag'};
    $requiredElementInfo{$dbResults->[0]->{'DUT'}}->{'ViewLocation'}=$dbResults->[0]->{'CCViewLoc'};
    $requiredElementInfo{$dbResults->[0]->{'DUT'}}->{'View'}=$dbResults->[0]->{'CCView'};
    $requiredElementInfo{$dbResults->[0]->{'DUT'}}->{'BuildFlag'}=$BuildFlag;

    $dbResults=dbCmd("SELECT DISTINCT Element,CCView,CCViewLoc,Build,InstalledFlag FROM ats_sched_required_element WHERE JobId='".$JobId."'");

    foreach my $record (@{$dbResults}) {
        $requiredElementInfo{$dbResults->[0]->{'Element'}}->{'Build'}=$dbResults->[0]->{'Build'};
        $requiredElementInfo{$dbResults->[0]->{'Element'}}->{'InstalledFlag'}= $dbResults->[0]->{'InstalledFlag'};
        $requiredElementInfo{$dbResults->[0]->{'Element'}}->{'ViewLocation'}=$dbResults->[0]->{'CCViewLoc'};
        $requiredElementInfo{$dbResults->[0]->{'Element'}}->{'View'}=$dbResults->[0]->{'CCView'};
        $requiredElementInfo{$dbResults->[0]->{'Element'}}->{'BuildFlag'}=0;
    }

    $index=0;
    while($index<scalar(@testBedArray)){
        if(defined($requiredElementInfo{$testBedArray[$index]})){
            my $Alias = $testBedArray[$index+1];

            my $tid=$g_imageInstall_IDLE_THREAD_QUEUE->dequeue();#GRAB AN IDLE THREAD
            $imageinstall_THREAD_POOL{$tid}->enqueue([$JobId,$testBedArray[$index],#PUSH A INSTALL ONTO THREAD
                                                             $Alias,
                                                             $requiredElementInfo{$testBedArray[$index]}->{'Build'},
                                                             $requiredElementInfo{$testBedArray[$index]}->{'ViewLocation'},
                                                             $requiredElementInfo{$testBedArray[$index]}->{'View'},
                                                             $requiredElementInfo{$testBedArray[$index]}->{'InstalledFlag'},
                                                             $requiredElementInfo{$testBedArray[$index]}->{'BuildFlag'}]);
        }
        $index+=3;#MOVE TO NEXT ELEMENT INSTALL
    }
    sleep(1);
    #WAIT HERE UNTIL ALL INSTALLS HAVE COMPLETED
    my $iteration = 0;
    while($imageInstallRunning{$JobId} > 0 and $iteration < 1080){# 3hrs: 180*60:10800/10:1080. 
        sleep(10);
        $iteration += 1;
    }
    delete($imageInstallRunning{$JobId});
    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
    my $result = ($iteration >= 720) ? 0 : $g_Install_Result{$JobId};
    delete($g_Install_Result{$JobId});
    return $result;
}

sub doTest {
    my $function="doTest";
    my($jobTestBed,$JobSubJobs)=@_;
    my ($returnCode, $isBRXJob);

    #SHOULD PROB CHANGE THIS TO A SWITCH CASE RATHER THAN IFs... IF Only :p
    #Also, instead of calling doTest module from within this thread we should fork! so we do not poison this process with memeleaks and faults

    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    if($JobSubJobs->{'ATTRIBUTES'}->{'DUT'} =~ m/SBX5\d00/ or $JobSubJobs->{'ATTRIBUTES'}->{'DUT'} =~ m/VIGIL/){
        $g_logger->info("ENTERED: ".$function." SBX ThreadID~".threads->tid());
        $returnCode=SonusQA::GTB::doTestSBX::main($jobTestBed,$JobSubJobs);
    }

    # BRX suites need to be triggered with startAutomation instead of STARTPSXAUTOMATION
    # if any of the suites contain BRX in path, then call doTestSBX
    elsif($JobSubJobs->{'ATTRIBUTES'}->{'DUT'} =~ m/PSX/) {
        foreach my $suite ( keys %{$JobSubJobs} ) {
            next if ( $suite =~ m/ATTRIBUTES/ );
            $isBRXJob = ( $JobSubJobs->{$suite}->{'PATH'} =~ /brx/i ) ? 1 : 0;
            last if ( $isBRXJob == 1 );
        }

        if ($isBRXJob == 1) {
            $g_logger->info("ENTERED: ".$function." BRX ThreadID~".threads->tid());
            $returnCode = SonusQA::GTB::doTestSBX::main($jobTestBed,$JobSubJobs);
        }else {
            $g_logger->info("ENTERED: ".$function." PSX ThreadID~".threads->tid());
            $returnCode = SonusQA::GTB::doTestPSX::main($jobTestBed,$JobSubJobs);
        }
    }
    elsif($JobSubJobs->{'ATTRIBUTES'}->{'DUT'} =~ m/GSX/){
        #GSX/NBS
        $g_logger->info("ENTERED: ".$function." GSX ThreadID~".threads->tid());
        $returnCode = SonusQA::GTB::doTestPSX::main($jobTestBed,$JobSubJobs);
    }

    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());

    return $returnCode;
}

sub elementStatusUpdate {

    my $function = "elementStatusUpdate";
    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    my (@testBedArray) = @_;
    my ($query, $results, $count, $status);
    my $index = 0;

    while($index < scalar(@testBedArray)) {

        $query = "SELECT TestBedId, ElementType, Status, SharedTBUseCount FROM ats_sched_testbed INNER JOIN sons_nelement ON sons_nelement.sons_nelement_uuid = ats_sched_testbed.Element AND sons_nelement.sons_nelement_alias='".$testBedArray[$index+1]."'";
        $results = &dbCmd($query);

        # After substracting current count, if it usage is still greater that zero then set it 'In Use', otherwise 'Free'
        if($results->[0]->{'ElementType'} eq 'S' and $results->[0]->{'Status'} eq 'U' ){
            $count = $results->[0]->{'SharedTBUseCount'} - 1;
            $status = ($count > 0) ? 'U' : 'F' ;
        }else{
            $count = 0;
            $status = 'F';
        }

        $query = "UPDATE ats_sched_testbed, sons_nelement SET ats_sched_testbed.Status = '$status', ats_sched_testbed.SharedTBUseCount = $count WHERE sons_nelement.sons_nelement_uuid=ats_sched_testbed.Element AND sons_nelement.sons_nelement_alias='".$testBedArray[$index+1]."'";

        $g_logger->info("QUERY $function: " . $query);
        &dbCmd($query);

        $index += 3
    }

    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
    return 1;
}

sub popJobFromQueue{
    my $function="popJobFromQueue";
    my $JobId=shift;

    $g_logger->info("ENTERED: ".$function." ThreadID~".threads->tid());

    dbCmd("DELETE FROM ats_sched_job_queue WHERE JobId='".$JobId."'");

    $g_logger->info("LEAVING: ".$function." ThreadID~".threads->tid());
}

sub jobStatusUpdate{
    my ($update,$JobId)=@_;
    unless(defined($update) && defined($JobId) && $update =~ m/^(\S|\s)+$/ && $JobId =~ m/^\S+$/){
        $g_logger->error("jobStatusUpdate($update,$JobId) MISSING/INVALID ARGUMENTS");
        return 0;
    }

    my $query="UPDATE ats_sched_job_queue SET CurrentTest='".$update."' WHERE JobId='".$JobId."'";
    if(ref(&dbCmd($query)) eq "ARRAY"){return 1;}
    else{return 0;}
}

sub systemCmd{
    my ($cmd,@returnData);
    $cmd=shift;
    unless(defined($cmd)){
        $g_logger->error("systemCmd INVALID ARGUMENT:  $cmd");
        return 0;
    }

    unless(scalar(@returnData=`$cmd`)){
        $g_logger->error("systemCmd DID NOT SEE OUTPUT FROM CMD: $cmd");
        return 0;
    }
    return \@returnData;
}

sub dbCmd{
    my($query) = @_;
    my($databaseConn);

    unless(defined($query)){
        $g_logger->error("dbCmd QUERY ARGUMENT WAS LEFT EMPTY");
        return 0;
    }
    my $threadid = threads->tid();
    RETRY:
    if($query=~ m/SELECT/i){
        unless($readDatabaseConn{$threadid}){
            eval{
                $readDatabaseConn{$threadid} = SonusQA::Utils::db_connect('RODATABASE')
            };
            if($@){
                $g_logger->debug("ERROR IN CONNECTING TO READ DB! Waiting for 120 seconds to try again...");
                sleep(120);
                goto RETRY;
            }
        }
        $databaseConn = $readDatabaseConn{$threadid};
    }
    else{
        unless($writeDatabaseConn{$threadid}){
            eval{
                $writeDatabaseConn{$threadid} = SonusQA::Utils::db_connect('DATABASE')
            };
            if($@){
                $g_logger->debug("ERROR IN CONNECTING TO WRITE DB! Waiting for 120 seconds to try again...");
                sleep(120);
                goto RETRY;
            }
        }
        $databaseConn =  $writeDatabaseConn{$threadid};
    }

    my ($queryHandler,$key, $value,$row, @result);
    unless($databaseConn->ping()){
       $writeDatabaseConn{$threadid}->disconnect;
        $readDatabaseConn{$threadid}->disconnect;
        delete $writeDatabaseConn{$threadid};
        delete $readDatabaseConn{$threadid};
        goto RETRY;
    }
    eval{
        $queryHandler = $databaseConn->prepare($query);
        $queryHandler->execute();
    };
    if($@){
        $g_logger->error("DB ERROR: '$@' Statement : ".$queryHandler->{Statement});
        $writeDatabaseConn{$threadid}->disconnect;
        $readDatabaseConn{$threadid}->disconnect;
        delete $writeDatabaseConn{$threadid};
        delete $readDatabaseConn{$threadid};
        if ($@ =~ /MySQL server has gone away/i ){
            $g_logger->debug("DB connection lost due to timeout. Retrying.. ");
            goto RETRY;
        }
        return 0;
    }

    $g_logger->trace("Database Query: $query\n");
    if($query=~ m/SELECT/i){
        while($row = $queryHandler->fetchrow_hashref()){
            push(@result,$row);
        }
        foreach(@result){$g_logger->trace("Database Query returned:".$_);}
    }

    $writeDatabaseConn{$threadid}->disconnect if(defined $writeDatabaseConn{$threadid});
    delete $writeDatabaseConn{$threadid};
    $readDatabaseConn{$threadid}->disconnect if(defined $readDatabaseConn{$threadid});
    delete $readDatabaseConn{$threadid};

    return \@result;
}

sub sendEmail{

    my($msg,$JobId)=@_;
    unless(defined($msg) && defined($JobId)){
       $g_logger->error("sendEmail ARGUMENTS LEFT EMPTY");
       return 0;
    }

    my $JobInfo=dbCmd("SELECT EmailIds,JobAlias FROM ats_sched_job WHERE JobId='".$JobId."'");
    my $sendmail = "/usr/sbin/sendmail -t";
    my $subject = "Subject: Automation Scheduler\n";
    my $to = "To: ".$JobInfo->[0]->{'EmailIds'}."\n";
    my $from = "From: iSMART System <iSMART-admin\@sonusnet.com>\n";

    if( defined $g_jobType_s and $g_jobType_s =~ /bistq/i ) {
        $subject = "Subject: BISTQ Automation Execution Status - $JobId\n";
        $from = "From: BISTQ <sonus-ats-dev\@sonusnet.com>\n";
    }

    eval{
        open(SENDMAIL, "|$sendmail");
        print SENDMAIL $to;
        print SENDMAIL $from;
        print SENDMAIL $subject;
        print SENDMAIL "Content-type: text/plain\n\n";
        print SENDMAIL "** JobID:".$JobId."\t**\n\n";
        print SENDMAIL "Job Alias:".$JobInfo->[0]->{'JobAlias'}."\n\n";
        print SENDMAIL $msg;
        close(SENDMAIL);
    };
    if($@){
        $g_logger->error("sendEmail ERROR: ".$@);
        return 0;
    }
    return 1;
}

sub CheckForCancel{
    my $JobId=shift;
    unless(defined($JobId)){
        $g_logger->error("CheckForCancel JOBID ARGUMENT LEFT EMPTY!");
        return undef;
    }

    return $g_jobCanceled{$JobId};
}

sub executeJob_ThreadQueue{
    my $work_queue=shift;
    my $thread_id = threads->tid();
    while(1){
        $g_executeJob_IDLE_THREAD_QUEUE->enqueue($thread_id);
        my $workReference=$work_queue->dequeue();
        Log::Log4perl::MDC->put('jobuuid', @{@{$workReference}[0]}[0]); #TOOLS-8492

        $g_JobsRunning++;
        unless(&executeJob(@{$workReference})){
            $g_logger->error("ERROR DURING JOB!");
        }
        $g_JobsRunning--;
    }
}

sub checkForJobCancel_ThreadQueue{
    my $work_queue=shift;
    my $thread_id = threads->tid();

    while(1){
        $g_cancel_IDLE_THREAD_QUEUE->enqueue($thread_id);
        my $JobId=$work_queue->dequeue();
        Log::Log4perl::MDC->put('jobuuid', $JobId); #TOOLS-8492

        &checkForJobCancel($JobId);
    }
}

sub ImageRetrieveInstall_ThreadQueue{
    my $work_queue=shift;
    my $thread_id = threads->tid();
    while(1){
        $g_imageInstall_IDLE_THREAD_QUEUE->enqueue($thread_id);
        my $workReference=$work_queue->dequeue();
        Log::Log4perl::MDC->put('jobuuid', $workReference->[0]); #TOOLS-8492

        $imageInstallRunning{$workReference->[0]}++;
        $g_Install_Result{$workReference->[0]}=0;
        if (defined $workReference->[6] and $workReference->[6] == 1) {
             $g_logger->warn("Installed flag is set for - $workReference->[1], hence skiping the installation");
             &sendEmail("Skip installation flag has been set, hence skiping the installation and Continuing the  Execution, Executing Testcase(s).",$workReference->[0]);
             $g_Install_Result{$workReference->[0]} = 1;
        } else {
            &sendEmail("Starting the Installation . Please wait this might take a while.",$workReference->[0]);
            unless($g_Install_Result{$workReference->[0]}=SonusQA::GTB::INSTALLER::installElement(@{$workReference})){
                 $g_logger->error("***************************************************************************");
                 $g_logger->error("ImageRetrieveInstall:".threads->tid() ." IMAGE RETRIEVE AND INSTALL FAILED --".$workReference->[0]);
                 $g_logger->error('@testBedArray Contents:');
                 $g_logger->error("[");
                 for(my $index=0;$index<scalar(@{$workReference});$index++){
                      $g_logger->error($workReference->[$index]);
                 }
                 $g_logger->error("]");
                 $g_logger->error("***************************************************************************");
                 my $logpath = "$ENV{HOME}/ats_repos/lib/perl/SonusQA/GTB/" . $g_testBedAlias_s;
                 &sendEmail("There was a problem while Installation, Please check SchedulerERROR.out for more information. \n $logpath/SchedulerERROR.out", $workReference->[0]);
             }
             else{
                $g_logger->debug("Installation completed successfully. Continuing the  Execution, Executing Testcase(s).");
                &sendEmail("Installation completed successfully. Continuing the  Execution, Executing Testcase(s).",$workReference->[0]);
             }
        }
        $g_logger->debug($g_Install_Result{$workReference->[0]});
        $imageInstallRunning{$workReference->[0]}--;
    }
}

END{
    for (keys %writeDatabaseConn ) {
        $writeDatabaseConn{$_}->disconnect;
    }
    for (keys %readDatabaseConn ) {
        $readDatabaseConn{$_}->disconnect;
    }
};

1;
