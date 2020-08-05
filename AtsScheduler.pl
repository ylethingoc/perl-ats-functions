#!/ats/bin/perl -w 

# Revision history
#    06/23/2011       WM   initial version

# Purpose: process test queue in TMS with STARTPSXAUTOMATION 
# Usage: see usage() function.

# Runs on a web server (now linuxad) to access TMS db, then sends ssh cmds to remote test bed host, eg: byte,
# where doTest.pl executes the cmds.

use strict;

use FileHandle;
use Getopt::Std;
use Carp;
use Env;
use Cwd 'abs_path';
use File::Path;
use File::Copy;
use File::Basename;
use Net::SSH::Perl;

use Mysql;
use DBI;
use threads;
use threads::shared;

our $g_masterHost = "byte";                ### interface to all test beds
our $g_install_host = "masterats";         ### host that does install of CC view onto testbed
our $g_view_host = "slate";                ### a host of CC view
our $g_web_host = "linuxad";               ### web server
our $g_publicDir = "/srv/www/htdocs/logs"; ### public dir on web server
our $g_web_url = "http://$g_web_host/logs";    ### url of $g_publicDir

our $s_threads_allowed :shared = 1;   ### set to 0 to disable threads
our $s_stopThread :shared = 0;     ### shared between threads
our $s_prevNewestJob :shared = "";

our $g_errMsg = "";
our $g_tst = "wxxxxxm";   ### wm or other, tag used for testing script - allows multiple users of DB
our $g_jid = "jid-wm";  ### tag used for test jobid - for testing script
our $g_progname;
our $g_pgName = "ATS Scheduler";
our $g_generic_user = $ENV{ USER};
our $g_wkdir = "/home/$g_generic_user/ats_repos/lib/perl/QATEST/PSX";
our $g_tmpDir = "/home/$g_generic_user/tmp";
our $g_killFile = "";
our @g_appenders = ();
our $g_idStr = "";

### just for Log4perl.pm, Sendmail.pm
use lib "/ats/langs/perl_5.8.7/lib/site_perl/5.8.7";
### this "use lib  ..i686..." dangerous, but host linuxad, unlike host byte
#  with cmd:   perl -V:archname   gives:
#    archname='i586-linux-thread-multi';
#  although uname -a gives:
#    Linux linuxad 2.6.16.21-0.25-smp #1 SMP Tue Sep 19 07:26:15 UTC 2006 i686 i686 i386 GNU/Linux
use lib "/ats/langs/perl_5.8.7/lib/site_perl/5.8.7/i686-linux-thread-multi";

use Mail::Sendmail;
use Log::Log4perl qw(get_logger :levels);
our $logger = get_logger();

### =========== main ============================================
#print join( "\n", @INC);

$SIG{INT} = \&handleControlC;

$g_progname = $0;
$g_progname =~ s/^.*\///;     # drop leading path

my $cmdline = "cmdline= $g_progname @ARGV";
my( $doClean, $lgLevel, $simulateTst, $testBed, $skipCp) = getArgs( );
our $g_logLevel = $lgLevel;
our $g_simulateTest = $simulateTst;
our $g_skipCopy = $skipCp;   ### skip copy of ClearCase build to testbed
$g_killFile = "/home/$g_generic_user/ats_scheduler_kill_$testBed";

### db query to get job queue, top/front of queue is first entry, 
### last entry if last job queued
our $g_nextJobQuery = "select qslot, q2.jobid, j2.testbedid, t2.testbedalias, t2.dut from 
     ats_sched_job_queue as q2, 
     ats_sched_job as j2, 
     ats_sched_testbed as t2 
       where 
     q2.jobid = j2.jobid and 
     t2.testbedid=j2.testbedid and 
     t2.testbedalias=\"$testBed\" and 
     t2.status='F' 
       order by qslot";

my $dirx = "$g_tmpDir/$testBed";
unless( -e $dirx) {
    #warn "dirx = $dirx";
    mkpath( $dirx);
}
our $g_headDir = "/home/psxats";
### all testbeds use same base log dir so GUI can find all the remote.log's
our $g_logDir = "$g_headDir/tmp/$testBed";   
unless( -d $g_logDir) {
    print "missing: $g_logDir\n";
    exit 3;
}
my $localLog = "$g_logDir/local.log";
my $remoteLog = "$g_logDir/remote.log";
unlink $localLog;
unlink $remoteLog;

initLog( $localLog);
#warn "loglevel = $g_logLevel";
$logger->level( eval( "\$$g_logLevel"));
$logger->info( $cmdline);
$logger->info("starting: $g_progname, local: $localLog, remote: $remoteLog");

# Autoflush all output buffers so that output is ordered in the sequence
# that the procedure executes it.
select STDERR; $|=1;
select STDOUT; $|=1;
if( $g_simulateTest) {
    $logger->warn( "XXXX will simulate test XXXX");
}

our $g_dbh = dbConnect();

if( $doClean) {  ### for test only
    cleanDb( $g_dbh);
    ### $logger->logcroak( "exit after cleanDb");
    loadFakedata( $g_dbh);
    $logger->warn("cleaned and init db, then exit");
    $logger->logcroak("cleaned and init db, then exit");
}

unless( isSingleton( $testBed)) {
    $g_dbh->disconnect();
    $logger->warn("already running, exiting");
    exit( 0);
}

### run all jobs in queue
while( 1) {   ### loop forever

    my ($jobInfo, $aRef) = getNextJob( $g_dbh, $testBed);  ### //////////
    if( defined( $aRef)) {
        $logger->info("start job");
        ## run job and sub-jobs
        runJob( $g_dbh, $jobInfo, $aRef);  ### ////////////
        $s_stopThread = 1;   ### stop all sub-threads
    }
    sleep( 5);  ### poll queue every n sec
    if( $s_stopThread == 1) {
        sleep( 7);  ### wait for kill and log threads to die
        $s_stopThread = 0;
    }
}

$logger->info("End: $g_progname, log: $localLog");
exit 0;

### =============================================================
### =============================================================
sub getJobResults {
    my( $jobResultPath) = @_;

    #warn "jobResultPath= $jobResultPath";
    unless( -e $jobResultPath) {
        $logger->info( "missing: $jobResultPath");
        return( undef, undef, undef);
    }
    my @rtn = ();
    open( FH, "< $jobResultPath");
    my @lines = <FH>;
    close( FH);

    my $failedTotal = 0;
    my $passedTotal = 0;
    my $execTotal = 0;

    my @failTest = grep /FAILED/, @lines;
    map( s#.* (\d\d\d\d\d\d*) .*#$1#, @failTest);
    chomp @failTest;

    my @runtime = grep /overhead/, @lines;
    map( s#.* (\d+) sec =.*#$1#, @runtime);
    chomp @runtime;

    my @suite = grep /suite=/, @lines;
    map( s#.*=(\S+) .*#$1#, @suite);
    chomp @suite;

    my @counts = grep /Counts/, @lines;
    map( s#Counts - ##, @counts);
    chomp @counts;

    my %runtime;
    for( my $ii = 0; $ii < scalar @counts; $ii++) {
        my $countLine = $counts[ $ii];
        $countLine =~ s/\D+/ /g;
        $countLine =~ s/^\s*(\S.*\S)\s*$/$1/g;
        my ($failed, $passed, $exec) = split( / +/, $countLine);
        $failedTotal += $failed;
        $passedTotal += $passed;
        $execTotal += $exec;
        my $strx = sprintf( "%7d %7d %7d", $failed, $passed, $exec);
        $counts[ $ii] = $strx;

        #warn "$suite[ $ii] = $runtime[ $ii]";
        $runtime{ $suite[ $ii]} = $runtime[ $ii];
    }
    my $totalTime = 0;
    foreach my $runtime (@runtime) {
        $totalTime += $runtime;
    }
    push( @rtn, sprintf( "%-18s %7s %7s %7s  Runtime\n", "    Suite", "failed", "passed", "exec"));
    my $spacer = "----------------------------------------------------------\n";
    push( @rtn, $spacer);
    for( my $ii = 0; $ii < scalar @suite; $ii++) {
        my $strx = sprintf( "%-18s %s %3d min\n",  $suite[ $ii], $counts[ $ii], int( ($runtime[ $ii] + 30)/60));
        push( @rtn, $strx);
    }
    push( @rtn, $spacer);
    my $totalStr = sprintf( "%18s %7d %7d %7d", "Totals", $failedTotal, $passedTotal, $execTotal);
    push( @rtn, sprintf( "$totalStr %3d min = %d hrs\n", int(($totalTime + 30)/60),  int((${totalTime} + (30 *60))/(60*60))));
    if( scalar @failTest > 0){
        push( @rtn,  "\nJob Failures:\n  " . join( "\n  ", @failTest) . "\n");
    }

    #print join( "", @rtn);
    return( "$failedTotal,$passedTotal,$execTotal", \%runtime, \@rtn);
}

### =============================================================
sub clearCaseViewFound {
    my( $ccView) = @_;

    my( $status, $arrRef) = systemCmd( "ssh -l $g_generic_user $g_view_host 'ct lsview'");
    if( $status) {
        return 0;
    }
    my @cviews = @$arrRef;
    map( s#\*# #g, @cviews);   ### drop "*", else grep fails
    my @zview = grep( m/ ${ccView} /, @cviews);
    $logger->debug( "zview= @zview");

    return (scalar @zview > 0);
}

### =============================================================
### copy build in clearcase view to testbed
sub build2testbed {
    my( $testBed, $version, $ccView, $location) = @_;

    ### atsInstallPsx.pl must run on host $g_install_host
    my $cmd = "cd $g_headDir/ats_user; ./atsInstallPsx.pl -psx $testBed -ver $version -ccview $ccView -loc $location -usr $g_generic_user -pass sonus1";
    # my $cmd = "./atsInstallPsx.pl -psx florida -ver V07.03.07R00 -ccview release.ssV07.03.07R000 -loc W -usr psxats -pass sonus1"
    $logger->info( $cmd);
    if( $g_simulateTest || $g_skipCopy) {
        $logger->info( "Skipping copy of CC build. $g_simulateTest, $g_skipCopy");
        return 1;
    }
    $logger->info( "Copying CC build in: $ccView to: $testBed.  Takes about 15 minutes.");
    my $fpath = "$g_logDir/atsInstallPsx-$$.log";
    open( FH, "> $fpath") or $logger->croak( "failed to open: $fpath");
    print FH getTimeStamp() . "\n";

    my @results = doCmd( "ssh -l $g_generic_user $g_install_host '$cmd'"); ### CAUTION: single quotes are essential
    my $status = $?;
    my @filtered = grep /\S/, @results;   ### dump empty lines
    print FH "@filtered";
    print FH "exit status= $status\n";
    print FH getTimeStamp() . "\n";
    close( FH);
    chmod oct( "0664"), $fpath;

    $logger->info( "status= $status, log: $fpath");
    if( $status != 0) {
        $logger->error( "atsInstallPsx failed on $testBed, status: $status");
        return 0;
    }
    return 1;
}


### =============================================================
sub runSubJobs {  ### last arg is optional
    my( $dbh, $jobResultPath, $jobInfo, $subJobListRef, $verifyJob) = @_;

    my @subJobList = @$subJobListRef;
    unless( defined $verifyJob) {
        $verifyJob = 0;
    }
    my @testAreas = ();
    my $subJobCnt = 0;
    my $tmsUpdate = ($jobInfo->{tmsupdate} eq "T" ? "-t" : " ");
    recordJobStart( $dbh, $jobInfo->{jobid});
    $logger->info( "num of subjobs: " . scalar @subJobList);
    foreach my $subJobRef (@subJobList) {
        ### every job has at least 1 sub-job - eg: a job may have
        ### sub-jobs, BILLING, VPN 
        unless( $verifyJob) {
            unlink $localLog;   ### delete old logs
            unlink $remoteLog;
            initLog( $localLog, "per sub-job");
        }
        my $testType = $subJobRef->{type};
        my $tcid = $subJobRef->{testsToRun};

        my $tbStr = "$jobInfo->{user},$jobInfo->{dut},$jobInfo->{tmsupdate}";
        if ( $g_simulateTest) {
            $logger->warn( "XXXXXXX simulate test XXXXXXXXX");
            $tbStr .= ",simulate"; ### trig doTest.pl to simulate test
        }
        # warn "tbStr= $tbStr";
        ### my $area = $jobInfo->{area};
        my $tcidStr = $subJobRef->{testsToRun};
        my $area = "";
        my $testStr = "";
        my $testPath = "";
        my $version = $jobInfo->{version};
        my $ccView = $jobInfo->{ccview};
        my $build = $jobInfo->{build};
        $g_idStr = "Testbed: $testBed\nBuild: $build\nClearCase view: $ccView\n";
        ( $area, $testStr, $tcidStr, $testPath) = getArea( $dbh, $testType, $tcidStr, $version);
        unless( defined( $area)) {
            emailUser( $jobInfo->{user}, undef);
            last;
        }
        $testPath .= "/$version";
        push @testAreas, "$area - $tcidStr";
        $tcidStr =~ s/,|'/ /g;
        $logger->info( "$area, $tcidStr");
        unless( $verifyJob) {
            emailUser( $jobInfo->{user}, "starting: $area - $g_pgName on $testBed~Starting $area tests\n$tcidStr");
            if( $s_threads_allowed) {
                ### use thread that polls log file to update DB currentTest field in ats_sched_job_queue
                my $thr = threads->create(\&getCurrentTestId, $jobInfo->{jobid}); ## /////////////
                sleep( 5);              ### let thread start up just so log entries are in correct sequence
            } else {
                warn "////// NOT starting thread: getCurrentTestId";
            }
        }
        my $pathOption = "-p QATEST/PSX"; ### default to use test files from SVN
        if ( $testType eq "UserDefined") {
            unless ( $testPath =~ s#/$jobInfo->{version}##) {
                $logger->logcroak( "path missing: $jobInfo->{version}");
            }
            $pathOption = "-p $testPath"; ### an abs path - use test files from user's dir instead of svn
            $tmsUpdate = "";    ### tms update not allowed for user defined tests
        }
        $logger->info( "ccView = $ccView");
        if ( $subJobCnt++ == 0) {
            my $ccView2 = $ccView;
            $ccView2 =~ s/\s.*//s;   ### drop user's comment (comment starts with a space)
            unless( $g_simulateTest || $g_skipCopy) {
                unless( clearCaseViewFound( $ccView2)) {
                    $logger->error( "no such cc view: $ccView2");
                    emailUser( $jobInfo->{user}, "Error on $testBed, $g_pgName~Missing CC view: $ccView");
                    last;
                }
            }
            unless( $verifyJob) {
                my $sqlCmd = "update ats_sched_job_queue set currentTest='Installing build' where jobid='$jobInfo->{jobid}'"; 
                runSqlCmd( $dbh, $sqlCmd);
                unless ( build2testbed( $testBed, $jobInfo->{version}, $ccView2, $jobInfo->{ccviewloc})) {
                    emailUser( $jobInfo->{user}, "Error on $testBed, $g_pgName~Failed to download ClearCase build $ccView to $testBed");
                    last;
                }
            }
        } else {
            $pathOption = "";   ### no path - load active area from svn only for first subJob
        }
        $ccView =~ s/\s+/_/sg;   ### allow spaces in user's comment
        if ( $pathOption =~ m#QATEST/PSX#) {
            if ( $g_simulateTest) {
                $pathOption = "";   ### use tests in active area
            }
        }
        my $testBedName = $jobInfo->{testbed};
        ### using /tmp to avoid exceeding disk quota limit on remote, but want logs in /home/...
        my $chkDir = "/tmp/$testBedName";   ### used by job verify on remote
	my $rLog = $remoteLog;
        $tcidStr =~ s#([\(\)])#\\$1#g;
        my $zcmd =  "cd $g_wkdir; /ats/bin/perl doTest.pl -d $g_logLevel -l $rLog -r $jobResultPath $tmsUpdate -u wmau -B $testBedName -b $build -v $jobInfo->{version} $pathOption -C $ccView -x $tbStr $area $tcidStr";
        if( $verifyJob) {
            $rLog =~ s#remote.log#remote-chk.log#;
            $zcmd =  "cd $chkDir; /ats/bin/perl $g_wkdir/doTest.pl -d $g_logLevel -l $rLog  -r $chkDir/result  -u wmau -B $testBedName -b $build -v $jobInfo->{version} $pathOption -C $ccView -x simulate,verify $area $tcidStr";
        } else {
            ### update job status in GUI
            my $sqlCmd = "update ats_sched_job_queue set currentTest='Loading frameWk' where jobid='$jobInfo->{jobid}'"; 
            runSqlCmd( $dbh, $sqlCmd);
        }
        ### use ssh to run or verify tests on remote testbed //////////////////
        $logger->info( $zcmd);
        my $rtn = cmd2TestBed( $zcmd); ### ////////////////////////////////
        warn "rtn==== $rtn";
        if ( $rtn != 0) {
            $logger->error( "error on remote: $rtn");
        }
        if ( -e $g_killFile) {
            warn "email job canceled";
            emailUser( $jobInfo->{user}, "$g_pgName - Job canceled $area~ $area tests\njobid: $jobInfo->{jobid}");
            last;               ### skip any remaining sub-jobs, ie other suites
        }
    }
    return @testAreas;
}

### =============================================================
sub runJob {   ### last arg is optional
    my( $dbh, $jobInfo, $subRef, $verifyJob) = @_; 

    unless( defined $verifyJob) {
        $verifyJob = 0;
    }
    my @subJobList = @$subRef;
    my $typex = $subJobList[0]{type};
    my $testBedName = $jobInfo->{testbed};
    my $version = $jobInfo->{version};
    my $jobResultPath = "$g_logDir/job-verify";
    unless( $verifyJob) {
        if ( -e $g_killFile) {
            unlink $g_killFile;
        }
        ### use thread to poll top of queue to detect kill of active job
        #$s_currentJobId = $jobInfo->{jobid};  ## shared with check4kill thread
        if( $s_threads_allowed) {
            my $thr = threads->create(\&check4kill, $jobInfo->{jobid}, $g_killFile, $testBedName);
        } else {
            warn "////// NOT starting thread: check4kill";
        }
        $jobResultPath = "$g_logDir/job-results";
        ### $jobResultPath has results for all sub-jobs in job.
        if ( -e $jobResultPath) {
            unlink $jobResultPath;
            if ( -e $jobResultPath) {
                $logger->logcroak( "failed to delete: $jobResultPath");
            }
        } else {
            my $zdir = dirname( $jobResultPath);
            my $cmd = "mkdir -p $zdir";
            `$cmd`;
            if ( $?) {
                $logger->logcroak( "failed to run: $cmd");
            }
        }
    }
    ## /////////////////////////////////////
    my @testAreas = runSubJobs( $dbh, $jobResultPath, $jobInfo, \@subJobList, $verifyJob);   ### /////////
    ### all sub-jobs are done
    if ( scalar @testAreas > 0) {
        my @areasOnly = @testAreas;
        map( s/ .*//, @areasOnly); # drop tcids
        my $areaStr = "$g_pgName";
        unless( $verifyJob) {
            my( $cntsString, $runtimeHRef, $jobSummaryRef) = getJobResults( $jobResultPath);
            if ( defined( $jobSummaryRef)) {
                my( $failCnt,$passedCnt,$execCnt) = split( /,/, $cntsString);
                if ( $failCnt > 0) {
                    $areaStr = "///// $failCnt FAILURES from $areaStr";
                } else {
                    my $tag = "";
                    if( $passedCnt == 0) {
                        $tag = "#### ";
                    }
                    $areaStr = "$tag$passedCnt passed from $areaStr";
                }
                recordJobEnd( $dbh, $jobInfo, $failCnt, $passedCnt, $execCnt, $runtimeHRef);
                my $summaryPath = $jobResultPath . ".summary";
                open( FH, "> $summaryPath") or $logger->logcroak( "failed to open: $summaryPath");
                print FH join( "", @$jobSummaryRef);
                open (IN, "< $jobResultPath");
                my @details = <IN>;
                close( IN);
                print FH join( "", @details);
                close( FH);
                chmod oct( "0664"), $summaryPath;

                if ( scalar @testAreas > 1) {
                    ### email job summary only if more than one sub-job
                    my $testbed = $jobInfo->{testbed};
                    emailUser( $jobInfo->{user}, "$areaStr on $testbed~~$summaryPath");
                }
            }
        }
    }
    warn "subJobList= @subJobList\ntestAreas= @testAreas";
    unless( $verifyJob) {
        popJobQueue( $dbh, $jobInfo->{ jobid});
    }
}


### =============================================================
# convert log to be dos format and copy to public dir for viewing by browser
sub convertLog {
    my( $oldLog, $newName) = @_;

    my $absOldLog = abs_path( $oldLog);
    my $webLog = "";
    if ( -e $absOldLog) {
        $webLog = "$g_publicDir/$$" . "$newName.log";
        copy( $absOldLog, $webLog);
        ### convert all files to dos format
        my $cmd = "ssh $g_web_host \"perl -i -pe 's/\\n/\\r\\n/'g $webLog\"";
        `$cmd`;
        if ( $?) {
            $logger->logcroak( "Error with cmd: $cmd");
        }
    } else {
      $logger->warn( "missing: $oldLog");
    }
    return $webLog;
}

### =============================================================
# if $msgInfo is undef, use msg in $g_errMsg
# msg format: "subject text~msg text"
# or: "subject text~~file-path"  -- msg is contents of file-path 
# multi-line msg text is allowed
sub emailUser {
    my( $userx, $msgInfo) = @_;

    unless( defined( $msgInfo)) {
        $msgInfo = $g_errMsg;
    }
    unless( $msgInfo =~ m/~/) {
        $logger->logcroak( "Missing \"~\" in: $msgInfo");
    }
    unless( $msgInfo =~ m#build|~~#i) {
        $msgInfo .= "\n\n$g_idStr";
    }
    unless( $msgInfo =~ m/~~/) {
        my $webLocal = convertLog( $localLog, "local");
        my $webRemote = convertLog( $remoteLog, "remote");

        $msgInfo .= "\n\nlogs:\n$webLocal";
        $msgInfo =~ s/\n/\\n/g;
    }

    ### email from host linuxad fails ???????    ### queues mail, no error, but never received????????
    ## sendMail( $userx, undef, $g_generic_user, $subject, $g_errMsg);

    ### using ssh to utilize testbed to send email 
    my $cmd = "cd $g_wkdir; /ats/bin/perl doTest.pl -d $g_logLevel -l $remoteLog -u $userx -x \"$msgInfo\" email";
    $cmd =~ s#$g_publicDir#$g_web_url#g;
    ## warn "cmd= $cmd";
    my @results = doCmd( "ssh -l $g_generic_user $g_masterHost '$cmd'"); ### CAUTION: single quotes are essential
}

### =============================================================
sub createKillFile {
    my( $killFile) = @_;

    my $cmd = "touch $killFile"; ### examined by SSREQ and SIPART <suite>.pm files
    `$cmd`;
    if ( $?) {
        $logger->logcroak( "failed: $cmd");
    }
    $logger->debug( "created $killFile");
}

### =============================================================
### verify job at end of queue is correctly defined
### Want to quickly tell user if job is wrong, and not wait until
### job reaches top of queue which could be hours later.
sub chkNewJob {
    my( $dbh, $testBed) = @_;

    ### setup logs
    my $locLog = $localLog;
    $locLog =~ s#local.log#local-chk.log#;
    if( -e $locLog) {
       unlink( $locLog);
    }
    my $rLog = $remoteLog;
    $rLog  =~ s#remote.log#remote-chk.log#;
    if( -e $rLog) {
       unlink( $rLog);
    }
    initLog( $locLog);
    #warn "99999999 g_appenders= @g_appenders";
    #@@ thread! # $logger->info("start verify job");

    my ($jobInfo, $aRef) = getNextJob( $dbh, $testBed, "get newest job");  ### //////////
    if( defined( $aRef)) {
        ## run job and sub-jobs
        runJob( $dbh, $jobInfo, $aRef, "just verify job");  ### ////////////
    }
    my $webLocal = convertLog( $locLog, "local-chk");
    my $webRemote = convertLog( $rLog, "remote-chk");
    #warn "webLocal= $webLocal, webRemote= $webRemote";
    emailUser( $jobInfo->{user}, "Pre-test done on $testBed, $g_pgName~Pre-test done on queued job on $testBed,\n$webLocal\n$webRemote");
    #@@ thread! # $logger->debug( "end chkNewJob");
}

### =============================================================
# a thread. 
# If top of queue changes in middle of job, user at GUI has canceled job.
# If tail of queue changes, must chkNewJob.
sub check4kill {
    my( $jobid, $killFile, $testBedName) = @_;

    my $dbh = dbConnect();
    my $query = $g_nextJobQuery;
    my $zchar = "k";
    while( 1) { 
        if( $s_stopThread == 1) {
            warn "terminate kill-thread since job is done";
            last;
        }
        my $hashRef = readDb( "get jobid", $dbh, $query);
        if ( ! defined( $hashRef)) { 
            # queue is empty
            # warn "may have attempt to kill only job in queue";
            createKillFile( $killFile);
            last;
        }
        my %hashx = %$hashRef;
        my @qslotArray = @{$hashx{ qslot}};
        ### warn "qslotArray= @qslotArray";
        if( scalar @qslotArray > 1) {
            my $newestJob = $qslotArray[ -1];
            if( $newestJob != $s_prevNewestJob) {
                ### new job was appended to queue
                #warn "newestJob= $newestJob";
                $s_prevNewestJob = $newestJob;
                chkNewJob( $dbh, $testBedName);   ### /////////////////
            }
        }

        my $jobid2 = @{$hashx{ jobid}}[0];   ## at top of queue
        if( $jobid ne $jobid2) {
            # must kill active job
            createKillFile( $killFile);
            last;
        }
        print $zchar;
        sleep 5;
    }
    #@# #@@ thread! # $logger->debug( "end check4kill");
    $dbh->disconnect();
}

### =============================================================
# thread to update current test field in DB using STARTPSXAUTOMATION log
sub getCurrentTestId {
    my( $jobid) = @_;

    my $logPath = "/home/$g_generic_user/ats_repos/lib/perl/QATEST/PSX/Automation.log";
    my $dbh = dbConnect();
    if ( -e $logPath) {
        my $numx = unlink "$logPath"; ##  delete old log file
        if ( $numx != 1) {
            die "failed to delete $logPath";
        }
    }
    my $ii = 0;
    while( 1) {
        if( -e $logPath) { last}
        sleep 5;  ### wait for new log file to be created
        print "L";
        if( $ii++ > 3000/5) {  ### ie 50 min
            $dbh->disconnect();
            $logger->error( "timeout waiting for log creation");
            ## thread dies, main thread continues
            return;
        }
        if( $s_stopThread == 1) {
            warn "terminate log thread since job is done";
            $dbh->disconnect();
            return;
        }
    }
    ### CAUTION: $logpath may quickly be large at start up, so must start way back from end
    open fh_tail, "/usr/bin/tail --lines 3000 -f $logPath |" or die "failed: $!";
    my @tcid = ();
    my $ii = 0;
    while (<fh_tail>) {
        #warn "111 line= $_";
        if( m/.TESTCASE :.*tms(\d+)/) {
            push @tcid, $1;   ### build list of all tcid's to be run
        } elsif( m#(^\d.*?:\d\d) \[.*:(\d+)\s+Test case\s+(\S+)#) {
            print "\n\tresult:: $1 $2 $3 - ";
        } elsif( m/Starting: (\d+)/) {
            # warn "starting: $1";
            $ii++;
            my $sizex = scalar @tcid;
            my $strx = "$1, $ii of $sizex";
            my $query = "update ats_sched_job_queue set currentTest='$strx' where jobid='$jobid'"; 
            #@# $logger->debug( "query= $query");
            my $qh = $dbh->prepare($query);
            $qh->execute();
        } elsif ( m/Destroyed object/) {
            #close fh_tail;   ### hangs ???
            last;               ### exit thread
        }
    }
    $dbh->disconnect();
}

### =============================================================
### put results into DB
sub recordJobEnd {
    my( $dbh, $jobInfo, $badCnt, $goodCnt, $totalCnt, $runtimeHRef) = @_;
    
    my $jobId = $jobInfo->{ jobid};
    my $version = $jobInfo->{ version};
    $logger->info( "$badCnt, $goodCnt, $totalCnt, jobId= $jobId, version= $version");

    my $sqlCmd = "update ats_sched_job set endtime = now()-interval 4 hour where jobid='$jobId'";
    runSqlCmd( $dbh, $sqlCmd);

    my $totalx = $badCnt + $goodCnt;
    $sqlCmd = "update ats_sched_job set fail=$badCnt, pass=$goodCnt, totaltests=$totalx, execTests=$totalCnt where jobid='$jobId'";
    runSqlCmd( $dbh, $sqlCmd);

    my $query = "select type, teststorun from ats_sched_test_to_run where jobid = '$jobId'";
    my $hashRef = readDb( "get jobid", $dbh, $query);
    if( defined( $hashRef) && ! $g_simulateTest) { 
        ### skip this if a job-cancel deleted entry in ats_sched_test_to_run
        updateSuiteDurations( $dbh, $hashRef, $version, $runtimeHRef);
    }
}

### =============================================================
sub getSuiteID2name{
    my( $dbh, $version) = @_;

    my $query = "select suiteid, suitename from ats_sched_suite where version=\"$version\"";
    my $hashRef = readDb( "get suiteid to suitename map", $dbh, $query);
    if ( ! defined( $hashRef)) { 
        $logger->logcroak( "failed: $query");
    }
    my %hashx = %$hashRef;
    my @suiteId = @{$hashx{ suiteid}};
    my @suiteName = @{$hashx{ suitename}};

    my %suitename2id = ();
    @suitename2id{ @suiteName} = @suiteId;

    my %suiteId2name = ();
    @suiteId2name{ @suiteId} = @suiteName;
    return (\%suiteId2name, \%suitename2id);
}

### =============================================================
sub updateSuiteDurations {
    my( $dbh, $hashRef, $version, $runtimeHRef) = @_;

    ### keys of $runtimeHRef are suiteName not suiteId
    my %hashx = %$hashRef;
    my @suiteId = @{$hashx{ teststorun}};
    my @type = @{$hashx{ type}};
    # my $version = @{$hashx{ version}}[ 0];
    my @suiteNames = keys %$runtimeHRef;
    my( $suiteId2nameRef, $suitename2idRef) = getSuiteID2name( $dbh, $version);
    for( my $ii = 0; $ii < scalar @type; $ii++) {
        if( $type[ $ii] =~ m/SuiteId/i) {
            my @aaa = keys %$runtimeHRef;
            my $suiteName = $suiteId2nameRef->{ $suiteId[ $ii]};
            if( $runtimeHRef->{ $suiteName} ){
                my $runtimeMin = int( ($runtimeHRef->{ $suiteName} + 30)/60);
                my $sqlCmd = "update ats_sched_suite set lastExecDuration = $runtimeMin 
                     where suitename= \"$suiteName\" and version= \"$version\"";
                runSqlCmd( $dbh, $sqlCmd);
            }
        }
    }
}

### =============================================================
sub recordJobStart {
    my( $dbh, $jobId) = @_;

    #warn "jobId= $jobId";
    my $sqlCmd = "update ats_sched_job set starttime = now()-interval 4 hour where jobid='$jobId'";
    runSqlCmd( $dbh, $sqlCmd);
}

### =============================================================
### load queue with fake jobs
sub loadFakedata {  ## for test only
    my ( $dbh)= @_;

    my $qslotMin = 8001;
    my $ii = $qslotMin;
    my @tcid = ();
    my @tlist = ();

#    $ii++;
#    #@tlist = ( "tcap");  ### three areas in one string
#    @tlist = ("TCI-JTI-VPN,516985,516054  516986,  517013", "tcap");  ### three areas in one string
#    qFakeJob( $dbh, $ii, "$g_jid" . $ii, $ii, \@tlist);

    $ii++;
    @tlist = ("TCI,516985,516986", );  ### CAUTION: must be real test id's 
    qFakeJob( $dbh, $ii, "$g_jid" . $ii, $ii, \@tlist);

#    $ii++;
#    ## my @tlist = ("TCAP");  ### CAUTION: must be real test id's 
#    @tlist = ("VPN,517013,517014", );  ### CAUTION: must be real test id's 
#    qFakeJob( $dbh, $ii, "$g_jid" . $ii, $ii, \@tlist);

#    $ii++;
#    @tlist = ("JTI,516054999,516055", "VPN,517013");  ### CAUTION: must be real test id's 
#    qFakeJob( $dbh, $ii, "$g_jid" . $ii, $ii, \@tlist);

}

### =============================================================
### chk if previous job is still running
sub isSingleton {
    my( $testBed) = @_;

    my $cmd = "ps -eaf";
    my @lines = `$cmd`;
    if( $?) { die "failed: $cmd"}
    my @filtered = grep( /$g_progname/, @lines);
    @filtered = grep( /$testBed/, @filtered);
    #warn "filtered= \n" . join( "\n", @filtered);

    return ( scalar @filtered == 1);  ### rtn 1 for a singleton
}

### =============================================================
sub cmd2TestBed {
    my( $cmd) = @_;

    $logger->info("//////////////////////////////////////////////////////");
    $logger->info("start: $cmd");

    my @results = doCmd( "ssh -l $g_generic_user $g_masterHost '$cmd'"); ### CAUTION: single quotes are essential
    my $rtn = $?;
    $logger->debug("rtn: $rtn, @results");

    return $rtn;
}

### =============================================================
sub doCmd {
    my( $cmd) = @_;

    my @rtn = `$cmd`;

    return ( "unused", "@rtn");   ## rtn array of two strings
}


### =============================================================
### =============================================================
sub cleanDb {
    my( $dbh) = @_;

    runSqlCmd( $dbh, "delete from ats_sched_job_queue   where jobid like '$g_jid%'");
    runSqlCmd( $dbh, "delete from ats_sched_job         where jobid like '$g_jid%'");
    runSqlCmd( $dbh, "delete from ats_sched_test_to_run where jobid like '$g_jid%'");
}


### =============================================================
sub qFakeJob {  ### for script test only  -- obsolete ?????????
    my( $dbh, $ii, $jobid, $qslot, $tRef) = @_;

    my $testbedid = "635bf74a-e3fb-102e-8917-000a5e757444";
    my $testid = "$g_tst" . "tests" . $ii;

    ### tmsupdate is true for value 1, but 0 does not give false??????????, '0' gives blank???
    ### CAUTION: insert into ats_sched_job also does automatic insert into ats_sched_job_queue
    runSqlCmd( $dbh, "insert into ats_sched_job ( jobid, username, testbedid, ccview, version, build, tmsupdate) 
       values( '$jobid', 'wmau', '$testbedid', '', 'V07.03.07', 'PSX_V01.00.00R000', '0')");

    runSqlCmd( $dbh, "update ats_sched_job_queue set qslot='$qslot', currenttest= '$g_tst' where jobid='$jobid'"); 

    my @tlist = @$tRef;
    foreach my $strx (@tlist) {
        my @tcid = split( /,/, $strx);
        my $area = shift @tcid;
        my $tcidStr = join( ",", @tcid);
        $logger->info( "qslot= $qslot,  area= $area,  tcid = $tcidStr");

        my $testType = "SuiteID";
        if (scalar @tcid > 0) {
            $testType =  "Single";
        } else {
            $tcidStr = uc( $area) . "-id";
        }
        $logger->info( "tcid = $tcidStr");
        runSqlCmd( $dbh, "insert into ats_sched_test_to_run ( jobid, testsToRun, type) values( '$jobid', '$tcidStr', '$testType')");
    }
}

### =============================================================
sub groupTcidsByArea {
    my ($dbh, $tcid, $version) = @_;

    $tcid =~ s/,/ /g;
    $tcid =~ s/ +/','/g;
    $tcid =~ s/^(.*)$/'$1'/;
    my $query = "select t2.suiteid, t2.testcaseid from 
           ats_sched_suite_test as t2, ats_sched_suite as s2 
           where t2.testcaseid in ($tcid) and t2.suiteid=s2.suiteid and s2.version=\"$version\"";
    my $hashRef = readDb( "get type, testsToRun", $dbh, $query);
    unless( defined( $hashRef)) {
        my $g_errMsg = "ERROR: $g_progname - ";
        $logger->logcroak( $g_errMsg);
        return (undef, undef, $tcid);
    }
    my %hashx = %$hashRef;
    my @keys = keys %hashx;
#     warn "keys= @keys";
#     warn "tcid = @{$hashx{testcaseid}}[0]";
#     warn "suiteid = @{$hashx{suiteid}}[0]";
    my @tcid = @{$hashx{testcaseid}};
    my @suiteid = @{$hashx{suiteid}};
    my @arx = ();
    for( my $ii = 0; $ii < scalar @tcid; $ii++) {
        push( @arx, "$suiteid[ $ii];$tcid[ $ii]");
    }
    my @arx2 = sort @arx;
#    warn "arx2 = @arx2";
    my @uniqAreas = uniq(@suiteid); 
    my @out = ();
    for my $areaId (@uniqAreas) {
        my @arx3 = grep /$areaId/, @arx;
        #warn "arx3= @arx3";
        map( s/$areaId;//, @arx3);
        push( @out, join( ",", @arx3));
    }
    #warn "out= @out";
    if( scalar @out == 1) {
        ### when only one suite, use tcid string from GUI
        ### this allows running tcid's multiple times in given order
        $tcid =~ s/'//g;
        @out = $tcid;
        $logger->debug( "out= @out");
    }
    return @out;   ### array of strings, each string: 1111,222,333
}

### =============================================================
### ensure items in given array are uniq
sub uniq {
    my @arrx = @_;

    my %seen = ();
    foreach my $item ( @arrx) {
         unless( $seen{ $item}) {
               $seen{ $item} = 1;   # value unused
         }
    }
    return sort keys %seen;
}

### =============================================================
sub initDBxx {   ### run once per test area 
    my( $dbh) = @_;

    #my $area = "BILLING";
    #my @tcid = ( qw( 515989 515990 515991 515992 515993 515994 515995 515996 515997 515998 515999 516000 516001 516002 516003 516004));

    #my $area = "JTI";
    #my @tcid = ( qw( 516054 516055 516056 516057 516058 516059 516060 516061 516062 516063));

#    my $area = "TCAP";
#    my @tcid = ( qw( 512463 512464 512465 512466));

    my $area = "tci";
    my @tcid = ( qw( 516985 516986 516987 516988 516989 516990));

    my $suiteId = uc( $area) . "-id";
    runSqlCmd( $dbh, "insert into ats_sched_suite ( suiteid, suitename, dut, path, version, requiredelement) values( '$suiteId', '$area', 'psx', 'pathx', 'ver987', 'req')");

    foreach my $tcidx (@tcid) {
        # CAUTION: testcaseid must be in area.pm file
        runSqlCmd( $dbh, "insert into ats_sched_suite_test (suiteid, testcaseid) values( '$suiteId', '$tcidx')");
    }
    exit;
}
    

### =============================================================
sub runSqlCmd {
    my( $dbh, $query) = @_;

    $logger->debug( "query= $query");
    my $qh = $dbh->prepare($query);
    $qh->execute();
    if( $?){
        $logger->logcroak( "failed: $query");
    }
}

### =============================================================
sub popJobQueue {
    my( $dbh, $jobid) = @_;

    $logger->info( "pop $jobid");
    my $query = "delete from ats_sched_job_queue where jobid='$jobid'";
    $logger->debug( "query= $query");
    my $qh = $dbh->prepare($query);
    $qh->execute();
}

### =============================================================
# normally get top of queue
# can get bottom of queue to run quick validity chk of new queue entry
sub getNextJob {
    my ($dbh, $testBed, $useEndOfQueue) = @_;   ### last arg is optional

    my $hashRef;
    my %hashx;

    my $qIndex = 0;     ### start/top of queue
    if( defined $useEndOfQueue) {
        $qIndex = -1;   ### want end of queue, ie newest job appended
    }
    ### get jobid for top of queue, ie smallest "qslot"
    my $query = "";
    if ( $g_tst ne "wm") {
        ### normal operation
        $query = $g_nextJobQuery;  ### ///////////
    }
    ### warn "query= $query";
    $hashRef = readDb( "get jobid", $dbh, $query);
    if ( ! defined( $hashRef)) { 
        ##$logger->info( "queue is empty");
        print "E";
        return (undef, undef);
    }
    %hashx = %$hashRef;
    my $qslot = @{$hashx{ qslot}}[ $qIndex];
    my $jobid = @{$hashx{ jobid}}[ $qIndex];
    $logger->info( "qslot= $qslot,  jobid= $jobid");
    $query = "select username, testbedid, version, ccview, ccviewloc, build, tmsupdate   from ats_sched_job 
                 where jobid = '$jobid'";
    $hashRef = readDb( "get username, etc", $dbh, $query);
    %hashx = %$hashRef;
    my $version = trim( @{$hashx{ version}}[ $qIndex]);

    my $aRef = getSubJobs( $dbh, $jobid, $version);

    my $build = trim( @{$hashx{ build}}[ $qIndex]);
    ### $build =~ s#(\S+)_(V\d\d\.\d\d\.\d\d).*#$2#;    ### ??????
    my $ccView = trim( @{$hashx{ ccview}}[ $qIndex]);
    $ccView =~ s#['";\*\[\]\(\)]##sg;  ### drop odd char in user's comments
    my $dut = $1;
    my $jobInfo = {
        jobid => $jobid,
        dut => uc( $dut),
        testbed => $testBed,      ### @{$hashx{ testbedalias}}[ $qIndex],
        user => trim( @{$hashx{ username}}[ $qIndex]),
        version => $version,
        build => $build,
        tmsupdate => @{$hashx{ tmsupdate}}[ $qIndex],
        ccview => $ccView,
        ccviewloc => trim( @{$hashx{ ccviewloc}}[ $qIndex])
    };

    return ($jobInfo, $aRef);
}

### =============================================================
sub getArea {
    my( $dbh, $testType, $tcidStr, $version) = @_;

    my $area = "";
    my $testStr = "";
    my $testPath = "";
    my @area = ();
    my $query = "";
    my $hashRef;
    my %hashx;
    $tcidStr =~ s/tms//ig; ### drop any tcid prefix
    # warn "333 $tcidStr";

    my $zpath = $tcidStr;
    $zpath =~ s# .*##;
    if( $tcidStr =~ s#(/home/.+)/[^/]+/([^/]+)\.pm(.*)#$3#) {  ## drop version
        ### have a user defined test, ie not in svn
        $area = $2;
        $testPath = $1;
        $version =~ s#\.#_#g;
        my $expectedPath = "/$version/${area}.pm";
        unless( $zpath =~ m#^/home/.*$expectedPath$#) {
            my $errx = "Bad path: $zpath\nexpected: /home/...$expectedPath";
            $logger->error( $errx);
            $g_errMsg = "Error in job - $g_pgName~$errx";
            return (undef, undef, $tcidStr);
        }
        unless( -e $zpath) {
            $logger->error( "missing: $zpath");
            $g_errMsg = "Error in job - $g_pgName~Missing: $zpath";
            return (undef, undef, $tcidStr);
        }
    }
    $logger->debug( "$testType, $area, $testPath, $tcidStr");
    my @tcid = split( /,/, $tcidStr);
    if ( $testType =~ m/Single/i  || $testType eq "UserDefined") {
        ### specific tests are listed
        map( s/(.*)/'$1'/, @tcid);
        $testStr = join( ", ", @tcid);

        if ( $area eq "") {
            ### get test area using first tcid
            $query = "select distinct s2.suitename, s2.path 
                  from ats_sched_suite as s2, ats_sched_suite_test as t2 
                  where s2.suiteid = (select t4.suiteid from ats_sched_suite as s4, ats_sched_suite_test as t4 
                         where t4.testcaseid = $tcid[0] and 
                               s4.suiteid=t4.suiteid and 
                               s4.version=\"$version\")";

            $hashRef = readDb( "get suiteName", $dbh, $query);
            unless( defined( $hashRef)) {
                $g_errMsg = "ERROR: $g_progname - bad tcid?~No such tcid: $tcid[0] in ats_sched_suite_test";
                $logger->error( $g_errMsg);
                return (undef, undef, $tcidStr);
            }
            %hashx = %$hashRef;
            @area = @{$hashx{suitename}};
            $area = $area[0];
            $testPath = @{$hashx{path}}[0];
        }
    } elsif( $testType ne "UserDefined") {
        ### run all tests in area/suite given by suiteId
        my $suiteId = $tcid[0];
        $query = "select suiteName, suiteid, path from ats_sched_suite where suiteId = '$suiteId'";
        $hashRef = readDb( "get suiteName, suiteid", $dbh, $query);
        unless( defined( $hashRef)) {
            $g_errMsg = "ERROR: $g_progname - bad suiteId?~No such suiteId: $suiteId in ats_sched_suite";
            $logger->error( $g_errMsg);
            $logger->logcroak( $g_errMsg);   ### ??????????????
            return (undef, undef, $tcidStr);
        }
        %hashx = %$hashRef;
        @area = @{$hashx{suiteName}};
        $area = $area[0];
        $testPath = @{$hashx{path}}[0];
        $tcidStr = "";
    }
    # warn "$area| $testStr| $tcidStr| $testPath";
    return ( $area, $testStr, $tcidStr, $testPath);
}

### =============================================================
## return hash of arrays where key is field name array is all values for that key
sub readDb {
    my( $msg, $dbh, $query) = @_;

    my %hashx = ();
    my @rtn2 = ();
    my ( $key, $value);

    $query =~ m/from\s+(\S+)/;
    my $ztable = $1;

    # warn "222 query= $query";
    unless( $query =~ m/ats_sched_job_queue/) {
        $logger->debug( "msg= $msg, query= $query");
    }
    my $qh = $dbh->prepare($query);
    if( $?) {
        my $errx = $?;
        $logger->logcarp( "dbh error $errx, $msg");
        $g_dbh->disconnect();
        $dbh = dbConnect();   ### try to re-connect to db
        $g_dbh = $dbh;
        $qh = $dbh->prepare($query);
    }
    $qh->execute();
    while ( my $result = $qh->fetchrow_hashref()) {
        while (($key, $value) = each %$result ) {
            unless ( $hashx{ $key}) {
                $hashx{ $key} =  []; ## ref to empty array
            }
            my $aRef = $hashx{ $key};
            push( @$aRef, $value);
            #print "  2020 $msg; table= $ztable, $key = $value\n";
            #warn "tmp = @$aRef";
        }
    }
    if( scalar keys %hashx == 0){
        return undef;
    }
    return \%hashx;
}

### =============================================================
## return array of hashs - each sub-job is one array
sub getSubJobs {
    my( $dbh, $jobid, $version) = @_;

    my @arryHash = ();   ### array of hashes where each array is a sub-job
    my ( $key, $value);

    ### get jobid's test suite/s
    my $query = "select type, testsToRun, jobId from ats_sched_test_to_run where jobId = \"$jobid\" order by type";
    $logger->debug( "query= $query");
    my $qh = $dbh->prepare($query);
    $qh->execute();

    my @tcid = ();
    my $doEntireSuite = 0;
    my $onlyOne = 0;  ### allow only one sub job when type is UserDefined
    while ( my $result = $qh->fetchrow_hashref()) {
        my %hashx = ();
        while (($key, $value) = each %$result ) {
            $value = trim( $value);
            ## warn "key= $key, val= $value";
            if( $key =~ m/testsToRun/i && $value =~ m#/home/#) {
                # have user defined test dir
                ## $logger->debug( "55555 $key= $value");
                $hashx{ $key} = $value;
                $hashx{ type} = "UserDefined";
                push( @arryHash, \%hashx);
                $onlyOne = 1;
            } elsif( $key =~ m/testsToRun/i && $value =~ m/^\d\d\d\d\d+/) {
                ### have individual tcid/s
                ### value may be "123456 111111,222222" 
                ### CAUTION: assuming suiteId (a sql uuid) does not start with 5 digits
                ## warn "key= $key, value= $value, tcid = @tcid";
                @tcid = groupTcidsByArea( $dbh, $value, $version);
            } else {
                ### have a suiteId
                ## warn "key= $key, val= $value";
                $hashx{ $key} = $value;
                if( $key =~ m/testsToRun/i) {
                    $doEntireSuite = 1;
                }
            }
        }
        if( $onlyOne) {
            ### UserDefined type allows only one sub job
            # testsToRun eg: /home/wmau/V1.2.3.4/jnk.pm,111,222
            @arryHash = (\%hashx);
            last;  ### ignore any other sub-jobs
        }
        if( $doEntireSuite) {
            push( @arryHash, \%hashx);
            $doEntireSuite = 0;
        }
        foreach my $tcidStr ( @tcid) {
            ### a list of tcid's, may have one or more suites
            my %thash = %hashx;
            $thash{ testsToRun} = $tcidStr;
            push( @arryHash, \%thash);
        }
    }
#      foreach my $aaa ( @arryHash) {
#          my %bbb = %$aaa;
#          warn "8888 jobId= $bbb{jobId}, type= $aaa->{type}, testsToRun= $aaa->{testsToRun}";
#      }
#      warn "999 xxxxxxxxx";
#      exit;

    return \@arryHash;
}

### =============================================================
sub dbConnect {

    ### $logger->debug("start: ");

    # MYSQL CONFIG VARIABLES
    my $host = "masterats.sonusnet.com";   ### "127.0.0.1";  # 127 for linuxad
    ### my $host = "localhost";   ### fails
    my $database = "ats";
    my $user = "ats";
    my $pw = "ats";

    my $dbh = DBI->connect("DBI:mysql:ats;host=$host", $user, $pw) or die "Connection Error: $DBI::errstr\n";
    if( $?) {
        my $errx = $?;
        #emailUser( "wmau", "dbh error~err= $errx");
        $logger->error( "dbh error $errx");
    }
    $dbh->{'mysql_auto_reconnect'} = 1;   ## for slow jobs ( > 13 hrs), tested 22 hrs

    return $dbh;
}

### =============================================================
### =============================================================
sub usage {
    my $msg = shift;
    my $sub = "usage";

    if( defined( $msg)) { print "$msg\n"}
    # $logger->debug( __PACKAGE__ . "::$sub() info msg in $sub"); # no line number
    # $logger->logcarp( "warn with small trace"); ## show line number
    # $logger->logcroak( "die with small trace"); ## show line number

    print STDOUT <<end;
 Purpose: process test queue in TMS with STARTPSXAUTOMATION 
   \t\t Runs all queued jobs, then waits for more jobs.
 Usage:
   \t/ats/bin/perl $g_progname  [-i] [-d <DEBUG INFO, etc>] [-s] [-c] -B <testBedName>
   \t\t -i --- clear db of fake jobs and init db with new fake job entries then exit
   \t\t -s --- cause remote host to simulate test
   \t\t -c --- do not copy ClearCase build to testbed, just use whatever build is there.
end
exit(2);
}

### =============================================================
sub getArgs {

    use vars qw( $opt_B $opt_c $opt_i $opt_d $opt_s); ## define possible cmd line options 
    getopts( 'B:cid:s'); ## ref pg 452, single letter options
    ## if( defined( $opt_t)) {print "TMS will be updated.\n"}

    my $logLvl = "--";
    unless( defined( $opt_d)) { 
	$logLvl = "INFO";
    } else {
	$logLvl = $opt_d;
    }
    $logLvl = uc( $logLvl);
    #warn "arg cnt = $#ARGV";
    unless( $#ARGV == -1) {
        usage();
    }
    my $levels = "TRACE DEBUG INFO WARN ERROR FATAL";
    unless( grep /$logLvl/, split( / /, $levels)) {
	$logger->logcroak( "got: $logLvl, log level must be one of: $levels");
    }

    unless( defined $opt_B) {
        $logger->logcroak( "must have -B switch");
    }

    return ( defined( $opt_i), $logLvl, defined $opt_s, $opt_B, defined( $opt_c));
}

### =============================================================
### =============================================================
### Create a datestamp: yyyy-mm-dd hh:mm:ss or as specified
sub getTimeStamp {
    my( $fmt) = @_;

    my @timex = localtime( time());

    unless( defined( $fmt)) {
        ### yyyy-mm-dd hh:mm:ss
        $fmt = "%04d-%02d-%02d %02d:%02d:%02d";
    }
    my $datestamp = sprintf( $fmt,
                             $timex[5] % 100 + 2000, $timex[4]+1, $timex[3], $timex[2], $timex[1], $timex[0]);

    return $datestamp;
}

### =============================================================
sub initLog {
    my( $logPath, $inSubJob) = @_;

    # Appenders
    #warn "22222-1 logPath= $logPath,  g_appenders= @g_appenders";
    foreach my $appenderx ( @g_appenders) {
        ### warn " 66666666666 dump old appender";
        Log::Log4perl->eradicate_appender( $appenderx);
    }
    @g_appenders = ();
    my $appender = Log::Log4perl::Appender->new(
						"Log::Dispatch::File",
						autoflush => 1,
						name => "zfilelog",
						filename => $logPath,
						mode     => "clobber", ### append or clobber
						);
    my $appender2 = Log::Log4perl::Appender->new(
						 "Log::Dispatch::Screen",
						 name => "zscreenlog",
						 stderr => 1, ### 1=stderr, 0=stdout
						 );

    # Layouts
    my $layout =
      Log::Log4perl::Layout::PatternLayout->new( "%p %L %d %F{1} %L %M %m%n");
    $appender->layout($layout);
    $appender2->layout($layout);
    $logger->add_appender($appender);
    $logger->add_appender($appender2);


    if( (! defined( $inSubJob)) && $logPath !~ /-chk/) {
        ### for script debugging
        ### also used by doTest.pl!
        my $zlog = dirname( $logPath) . "/localBig.log";
        my $appender3 = Log::Log4perl::Appender->new(
                                                     "Log::Dispatch::File",
                                                     autoflush => 1,
                                                     name => "zdebuglog",
                                                     filename => $zlog,
                                                     mode     => "clobber", ### append or clobber
                                                 );
        $appender3->layout($layout);
        $logger->add_appender($appender3);
    }

    push( @g_appenders, "zfilelog", "zscreenlog");
    #warn "22222-2  g_appenders= @g_appenders";
    # push( @g_appenders, $appender->{name}, $appender->{name};
    # warn "77777777 @g_appenders";
    # exit;
}

### =============================================================
sub sendMail {
  my $toList  = shift;
  my $ccList  = shift;
  my $from    = shift;
  my $subject = shift;
  my $message = shift;

  my $opts    = {domain=> undef, @_};
  my %mail;
  my ($to, $cc);
  my $i;

  my $mbox = "\@sonusnet.com";
  $from .= $mbox;

  # warn "to= $toList";
  my @toList = split /,/, $toList;
  map( s/$/$mbox/, @toList);
  $toList = join( ",", @toList);
  #warn "to= $toList";
  $cc = "";
  $to = $toList;
  $logger->debug("to: $to, from: $from, msg: $message");

  %mail = ( To => $to,
                        Cc => $cc,
                        From => $from,
                        Subject => $subject,
                        Message => $message,
                   );

  print("222 sendmail: \n\tto '$to'\n\tfrom '$from'\n\tcc '$cc'\n\tsubj '$subject'\n\tmsg $message\n");
  sendmail(%mail) or die "Error: $Mail::Sendmail::error\n";
  print "OK. Log says:\n", $Mail::Sendmail::log, "\n";

  return;
}

### =============================================================
### drop leading and trailing whitespace
sub trim {
    my( $strx) = @_;

    if( defined( $strx)) {
        ### must allow single char, eg: "___X___"
        $strx =~ s#^\s*(\S.*$)#$1#;  # drop leading whitespace
        $strx =~ s#^(.*\S)\s*$#$1#;  # drop trailing whitespace

        $strx =~ s#^\s*$##;  # rtn "" if only have whitespace
    }
    return $strx;
}
### =============================================================
sub systemCmd {                 ### last arg is optional
    my( $cmd, $doCroak) = @_;

    $logger->info( "cmd: $cmd");

    my @rtn = `$cmd`;
    my $status = $?;
    if ( $status) {
        if ( defined( $doCroak)) {
            $logger->logcroak( "error: $cmd; @rtn");
        } else {
            $logger->logcarp( "error: $cmd; @rtn");
        }
    }
    return( $status, \@rtn);
}

### =============================================================
sub handleControlC {
    $g_dbh->disconnect();
    createKillFile( $g_killFile);   ### eventually stops remote testbed
    $logger->logcarp( "$g_progname RUN ABORTED BY USER");

    print "\n***************************************************************************\n";
    print "***************** $g_progname RUN ABORTED BY USER *********************\n";
    print "***************************************************************************\n\n";
    exit( 123);
}

### =============================================================
### =============================================================


