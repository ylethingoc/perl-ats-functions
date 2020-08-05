package SonusQA::HARNESS;
require Exporter;

our (%TESTBED, $log_dir);

=head1 NAME

SonusQA::HARNESS - Perl module for MGW9000/MSX/BSX/SGX4000 interaction for updating results in TMS

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::HARNESS->new(
                                   -suite   => __PACKAGE__,
                                   -release => "$TESTSUITE->{TESTED_RELEASE}",
                                   -build   => "$TESTSUITE->{BUILD_VERSION}",
                               );

   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for Sonus MGW9000/MSX/BSX/SGX4000.

=head1 METHODS

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

=cut

use SonusQA::Utils qw(:all);
use strict;
no strict 'refs';
use warnings;
use Log::Log4perl qw(get_logger :easy :levels);
use SonusQA::Base;
use POSIX qw(strftime);
use File::Basename;
use Module::Locate qw /locate/;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
use MIME::Lite;
use JSON;

our $VERSION = "1.1";

use vars qw($self);
use constant TC_NOT_RUN => 99; # When returned, HARNESS will not update the results on TMS.

$ENV{LOG_EXECUTION_TIME} = 1;

our @ISA = qw( Exporter );

our @EXPORT = qw( doInitialization new runTestsinSuite updateResultFile updateResultSummaryFile AUTOLOAD $testsuite_name );

our %EXPORT_TAGS = (
    'all' => [qw(doInitialization new runTestsinSuite updateResultFile updateResultSummaryFile AUTOLOAD)]);

my ( %feature, $LogResult, $logstatus, %testresults, $jiraissue, $JiraBugId );
# INITIALIZATION ROUTINES 
# -------------------------------

# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.

#################################################
sub doInitialization {
#################################################
    my ( $self, %args ) = @_;
    my $subName = 'doInitialization()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');


    $self->{TYPE}           = __PACKAGE__;
    $self->{PROMPT}         = '/\[.*\]\[.*\]\$.*$/';
    $self->{DEFAULTTIMEOUT} = 10;
 
    $logger->debug('  Initialization Complete');
    $logger->debug(' <-- Leaving Sub [1]');
}
#########################################################################################################

#################################################
sub new {
#################################################

    my ( $class, %args ) = @_;
    my $subName = 'new()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');
    my ( $suite );
    my $self = bless {}, $class; 
    %feature = ();

    # Check Mandatory Parameters
    foreach ( qw/ suite release / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
    }
    # build will be picked from dut. hence optional for sbc, sgx
    unless ($args{"-suite"} =~ /(SBX|SGX|SBC)/) {
        unless ( defined ( $args{"-build"})) {
            $logger->error("  ERROR: The mandatory argument for -build has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
    }
    $self->{IGNORE_COREDUMP} = $args{'-ignore_coredump'};
    $self->{SUITE}          = $args{'-suite'};
    $self->{TESTED_RELEASE} = $args{'-release'};
    $self->{BUILD_VERSION}  = $args{'-build'}if (defined $args{'-build'});
    $self->{BUILD_VERSION}  = $main::TESTSUITE->{BUILD_VERSION} if(defined $main::TESTSUITE->{BUILD_VERSION});
    $self->{ATTACH_FILE}    = $args{-attach_file};
    $self->{FILEPATH}       = $args{-filepath};
    $self->{EXTENSION}      = $args{-extension};

    # for brx suite, overwrite BUILD_VERSION with BRX_BUILD_VERSION
    $self->{BUILD_VERSION}  = $main::TESTSUITE->{BRX_BUILD_VERSION} if(defined $main::TESTSUITE->{BRX_BUILD_VERSION});
    $self->{TESTED_RELEASE} = $main::TESTSUITE->{TESTED_RELEASE} if(defined $main::TESTSUITE->{TESTED_RELEASE});
    $feature{'release'} = $self->{TESTED_RELEASE};
    our $testsuite_name = $self->{SUITE}; 

    if ( defined $args{'-suiteInfo'} ) {
        $self->{SUITE_INFO} = $args{'-suiteInfo'};
        $logger->info(" SUITE INFO     : $self->{SUITE_INFO}");
    }
        
    if ( defined $args{'-variant'} ) {
        $self->{VARIANT} = $args{'-variant'};
        $logger->info(" VARIANT IN TESTSUITE  : $self->{VARIANT}");
    }
    
    $self->{VARIANT} = $main::TESTSUITE->{TESTED_VARIANT} if(defined $main::TESTSUITE->{TESTED_VARIANT});
    undef $ENV{SESSION_DIR} if (defined $ENV{SESSION_DIR});

    my $userName = '';
    unless ($ENV{ HOME } ) {
         $userName = $ENV{ USER };
         if ( system( 'ls /home/' . "$userName" . '/ > /dev/null' ) == 0 ) { # to run silently, redirecting output to /dev/null
             $ENV{ HOME }   = '/home/' . "$userName";
         }
         elsif ( system( 'ls /export/home/' . "$userName" . '/ > /dev/null' ) == 0 ) { # to run silently, redirecting output to /dev/null
             $ENV{ HOME }   = '/export/home/' . "$userName";
         }
         else {
             $logger->warn("*** Could not establish user ($userName) home directory... using /tmp ***");
             $ENV{ HOME } = '/tmp';
         }
    }

    my $location = locate $self->{SUITE};
    my ( $name, $path, $suffix) = fileparse( $location, "\.pm" );
    $self->{MODULE} = $name;
    $self->{SUITE_PATH_FILE} = "$path$name$suffix";

    $self->{LOGDIR} = "$ENV{ HOME }/ats_user/logs/";

    my $product;
    my $application_path = substr( $self->{SUITE}, 8);
    $application_path =~  s/\:+/\//g; # Replace :: with a /
    my $temp_rel;
    if ($application_path =~ /(SGX4000|BARRACUDA|SB\w5\w00|VIGIL|PLATFORM)\/(.+)/) {
        $application_path = $2;
        $product = ($1 =~ /BARRACUDA|SB\w5\w00/) ? 'SBX5000' : $1;
        if ( $main::TESTSUITE->{$product.'_APPLICATION_VERSION'} =~ /(V.+\.\d+\.\d{1,2}).*/) {
            $temp_rel = $1;
            $self->{BUILD_VERSION} = $main::TESTSUITE->{$product.'_APPLICATION_VERSION'};
            $logger->debug("Setting BUILD_VERSION for $product as '${product}_APPLICATION_VERSION' : $main::TESTSUITE->{$product.'_APPLICATION_VERSION'}");
        } else {
            $logger->error(__PACKAGE__ . ".$subName: ERROR: *** Could not get BUILD_VERSION  from '${product}_APPLICATION_VERSION'($main::TESTSUITE->{$product.'_APPLICATION_VERSION'}) for $product. Check whether the object is created");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub[0]");
            return 0;
        }
    }

    if ($ENV{'DEFINED_LOG_DIR'}) {
        #will swith all the logs user defined dir's
        $self->{LOGDIR} = "$args{'-path'}" . 'logs' if ( defined $args{'-path'} ); # Log Directory PATH
        $self->{LOGBASE} = $self->{LOGDIR};
        $self->{LOGDIR} = "$self->{LOGDIR}/$application_path";
        $self->{RESULTFILE} = $args{'-resultFile'} if (defined $args{'-resultFile'});
    } else {
        #switch all the logs to default directory as per feature name and path
        $self->{LOGDIR} = "$ENV{ HOME }/ats_user/logs/";
        if ($product eq 'SGX4000') {
             $application_path =~ s/\w+\///;
             $self->{LOGDIR} .= "${product}_$main::TESTSUITE->{SGX4000_PLATFORM}/$temp_rel/$main::TESTSUITE->{$product.'_APPLICATION_VERSION'}/";
            $name = $application_path;
        } 
        elsif($product) {
             my $temp_version = $main::TESTSUITE->{$product.'_APPLICATION_VERSION'};
             $temp_version =~ s/.+\_(V.+)/$1/;
             $self->{LOGDIR} .= "${product}_$main::TESTSUITE->{TESTED_VARIANT}/$self->{TESTED_RELEASE}/$temp_version/";
        }
        $self->{LOGBASE} = $self->{LOGDIR};
        $self->{LOGDIR} .=  $name;
    }
    $feature{'build'} = $self->{BUILD_VERSION};

    $logger->info(" SUITE          : $self->{SUITE}");
    $logger->info(" TESTED RELEASE : $self->{TESTED_RELEASE}");
    $logger->info(" BUILD VERSION  : $self->{BUILD_VERSION}");


    unless ( system ( "mkdir -p $self->{LOGDIR}" ) == 0 ) {
        die "Could not create user log directory in $self->{LOGDIR}/ ";
    }

    my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
    
    unless ($self->{RESULTFILE}){
        $self->{RESULTFILE} = "$self->{LOGDIR}" . '/' . 'Results_' . "$self->{MODULE}" . '_' . "$timestamp";
        $self->{RESULTFILE} .= '_' . "$main::job_uuid" if(defined $main::job_uuid);
    }
    $feature{'resultfile'} = $self->{RESULTFILE};

    unless ($ENV{'DEFINED_LOG_DIR'}) {
        # Create new log files
        my $newATSLog = "$self->{LOGDIR}/ATS_log-$self->{MODULE}.$timestamp";
        $ENV{'ATS_LOG_FILE'} = $newATSLog;
        my $newTestLog = "$self->{LOGDIR}/test_run-$self->{MODULE}.$timestamp";
        $ENV{'TEST_LOG_FILE'} = $newTestLog;

        my $oldAtsLog = SonusQA::Utils::getLoggerFile('AtsLog'); #get the current ATS log file name
        my $oldTestLog = SonusQA::Utils::getLoggerFile('TestRunLog'); #get current Test log file name
        SonusQA::Utils::changeLogFile(-appenderName => "AtsLog", -newLogFile => $newATSLog); #switchin the ATS log
        SonusQA::Utils::changeLogFile(-appenderName => "TestRunLog", -newLogFile => $newTestLog); #switching the test log
        $logger->info("Successfully switched ATS log from '$oldAtsLog'");
	$logger->info("Successfully switched Test Run log from '$oldTestLog'");

	$LOG_DIRECTORY = $self->{LOGDIR};
        # switching session logs
        unless (SonusQA::Base::switchSessionLog($self->{LOGDIR}) ) {
            $logger->info("unable to switch the session logs to $self->{LOGDIR}");
        } else {
            $ENV{SESSION_DIR} = $self->{LOGDIR};
            $logger->info("successfully switched all session logs to $self->{LOGDIR}");
        }
    }

    $logger->info(" HARNESS LOG DIRECTORY : $self->{LOGDIR}");
    $logger->info(" TEST SUITE FILE       : $self->{SUITE_PATH_FILE}");
    $feature{'featurefile'} = $self->{SUITE_PATH_FILE};
    
    $main::log_dir = $self->{LOGDIR}; #to store SBX logs

    ##################################
    # Obtain Additonal Info
    ##################################
    if (defined $main::TESTSUITE->{ADDITIONAL_INFO}){
      $self->{ADDITIONAL_INFO} = $main::TESTSUITE->{ADDITIONAL_INFO};
    }

    ##################################
    # Obtain email address
    ##################################
    my @toID = qx#id -un#;
    chomp(@toID);
    my $defaultEmailID = "$toID[0]" . '@rbbn.com';
    $self->{USERID} = $toID[0];
    if ( defined $ENV{'ATS_EMAIL_LIST'} ) {
        $self->{EMAIL_LIST} = $ENV{'ATS_EMAIL_LIST'};
        push ( @{$self->{EMAIL_LIST}}, $defaultEmailID );
    } elsif (defined $main::TESTSUITE->{iSMART_EMAIL_LIST} and @{$main::TESTSUITE->{iSMART_EMAIL_LIST}}) {
        $self->{EMAIL_LIST} = $main::TESTSUITE->{iSMART_EMAIL_LIST};
    }
    #TOOLS-20025
    elsif(defined $main::TESTSUITE->{EMAIL_LIST} and @{$main::TESTSUITE->{EMAIL_LIST}}) {
        $self->{EMAIL_LIST} = $main::TESTSUITE->{EMAIL_LIST};
    }
    unless ( defined $self->{EMAIL_LIST} ) {
        if ( ( defined $args{'-email'} ) &&
             ( @{ $args{'-email'} } ) ) {
            $self->{EMAIL_LIST} = $args{'-email'};
            push ( @{$self->{EMAIL_LIST}}, $defaultEmailID );
        }
        else {
            $self->{EMAIL_LIST} = [$defaultEmailID];
        }
    }
    $logger->info(" TEST SUITE EMAIL LIST : @{ $self->{EMAIL_LIST} }");

    $logger->info(" HARNESS RESULT FILE   : $self->{RESULTFILE}");
    $self->{SUMMARYFILE} = "$self->{LOGBASE}" . '/' . 'Results_Summary_File';

    $logger->info(" ATS LOG FILE          : $ENV{'ATS_LOG_FILE'}") if ( defined $ENV{'ATS_LOG_FILE'} );
    $logger->info(" TEST LOG FILE         : $ENV{'TEST_LOG_FILE'}") if ( defined $ENV{'TEST_LOG_FILE'} );

    $logger->debug('<-- Leaving Sub [1]');
    return $self;
}
#########################################################################################################

#################################################
sub runTestsinSuite {
#################################################
	my ($tests_to_run,$self, $testcaseInfo, @tests_to_run, %testcaseInfo);
	if($main::tma) {
		($self, $tests_to_run, $testcaseInfo) = @_;
	} else {
		( $self, @tests_to_run) = @_;
	}
	
    my @attachments;
    my $subName = 'runTestsinSuite()';
    my $harness_logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my %result_count;

    my $logger = Log::Log4perl->get_logger($self->{SUITE} . ".$subName");

	if($main::tma) {
		   $harness_logger->info("===== tma case");
		@tests_to_run = @{ $tests_to_run };
		%testcaseInfo = %{ $testcaseInfo };  
	}
	
    $main::TESTSUITE->{SUITE} = $self->{SUITE};

    unless ( @tests_to_run ) {
        $harness_logger->error("$self->{MODULE} : No Testcases specified.");
        return 0;
    }

    if($main::asan_build_failure) {             #TOOLS-72075
        $harness_logger->error("$self->{MODULE} : ASAN Build Failure");
        return 0;
    }

    if($self->{ATTACH_FILE}){
      unless($self->{FILEPATH}){
        $self->{FILEPATH} = `pwd`;
        $harness_logger->debug(__PACKAGE__."File Path not defined using default file path $self->{FILEPATH}");
      }
    }    
    # Clear the results file
    &SonusQA::Utils::cleanresults("$self->{RESULTFILE}");


    # If an array is passed in use that. If not run every test.
    $logger->info("$self->{MODULE} : Running testcases:");

    foreach ( @tests_to_run ) {
        $logger->info("$self->{MODULE} : \t$_");
    }
    my ( $TestCasesPassed, $TestCasesFailed, $TestCasesNotRun, $TotalTestCases, $reruntests ) = ( 0, 0, 0, 0, 0, 0);
    my ( $build, $result, $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $options, $feature, $feature_dir, $ActualTestCases);
    my ( $TestSuiteStartTime, $TestSuiteEndTime, $TestSuiteExecTime, $TestSuiteStartTimestamp, $TestSuiteEndTimestamp, $FeatureRunTime, $StartTimeReference, $TestSuiteExecInterval, $TestStartTimeReference );
    my ( $LogDir,$ResultFile );
    my $failure_cause = "";
    my $stop_reason = "";

    $failure_cause .= "base_config\n$main::failure_msg\n" if($main::failure_msg);
    $LogResult = 0;
    %testresults = ();
    $jiraissue = "";
    $ActualTestCases = scalar @tests_to_run;
    $feature{'totaltests'} = $ActualTestCases;
    my @TestSuiteResults = ("No.\tTest_ID\tResult\tExecTime\t\tStartTime\t\t\tEndTime\t\tVariant\tInfo\n","################################################################################\n");
    $build = 'Unknown';

    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )=localtime(time);
    $TestSuiteStartTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
    $StartTimeReference = [Time::HiRes::gettimeofday];
    $TestSuiteStartTimestamp = `date`;
    chomp $TestSuiteStartTimestamp;
    $feature{'starttime'} = $TestSuiteStartTimestamp;

    if ( $self->{TESTED_RELEASE}) {

        $logger->info("$self->{MODULE} : Logging TMS results against release: $self->{TESTED_RELEASE}");

        if ( $self->{BUILD_VERSION} ) {
            $build = $self->{BUILD_VERSION};
            $logger->info("$self->{MODULE} : Logging TMS results against build:   $self->{BUILD_VERSION}");
        }
        else {
            $logger->info("$self->{MODULE} : Logging TMS results without build. Information must be added post test run");
        }
    }
    else {
        $logger->warn("$self->{MODULE} : \$self->{TESTED_RELEASE} is not set.");
        $logger->warn("$self->{MODULE} : Test results will not be logged in TMS");
    }

    my %execution_time = (); #loging suite execution time for bangalore
    if (defined $ENV{LOG_EXECUTION_TIME} and $ENV{LOG_EXECUTION_TIME}) {
        $execution_time{feature_starttime} = $TestSuiteStartTime;
        $execution_time{feature} = $self->{MODULE};
        if ($self->{SUITE} =~ /^\w+\:\:(\w+)\:\:\S+/) {
            $execution_time{product} = $1;
	    $feature{'product'} = $execution_time{product};
        }
    }
    $feature = $self->{SUITE};
    if(  $feature =~ /^.*::.*::.*::.*::.*$/ ){
        ($feature_dir,$feature) = ( $feature =~ /^.*::.*::.*::(.*)::(.*)$/ );
    }elsif( $feature =~ /^.*::.*::.*::.*$/ ){
        ($feature_dir,$feature) = ( $feature =~ /^.*::.*::(.*)::(.*)$/ );
    }
    $feature .= ".pm";
    $feature{'feature'} = $feature;
    $feature{'svnpath'} = $self->{SUITE};

    my @result_map = ('FAILED', 'PASSED', 'WARN', 'ERROR', 'BLOCKED', 'INVALID','UNKNOWN'); 
    my (@failedTestCase);
    my $reruncount=0;
    my $rerun_flag = "";

RERUN_FAILED:
    my ($failed_tests_count, $core_count) ;
    my $failed_tests_threshold = 10;
    my $core_count_threshold = 2;

    $logger->info(__PACKAGE__ ."Using VARIANT as $self->{VARIANT} for each testcase");
    my $TestedVariant = $self->{VARIANT};

    foreach ( @tests_to_run ) {

        my $TestCaseId = $_;
		my $TestCaseName = $TestCaseId;
	$main::failure_msg = "";
        # Prepare test case id for TMS
        if (/^tms/) { $TestCaseId =~ s/^tms// }
        $main::TESTSUITE->{TEST_ID} = $TestCaseId;
        $self->{METADATA}  = undef;
        $self->{EXTRADATA} = ();
 
        # Test case - START timestamp
        ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
        my $TestStartTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
        $TestStartTimeReference = [Time::HiRes::gettimeofday];
         
        ###########
        # RUN TEST
        ###########
        my $test = "$self->{SUITE}::$_";
        my $ret_val;
		my $executionLog;
		if($main::tma) {
			eval {
			   ($ret_val, $executionLog) = &$test(); 
			};
			$executionLog = $self->{LOGDIR}."/".$executionLog;
		} else {
			eval {
				$ret_val = &$test();
			};
		}
		
		$logger->error("tma case execution log  === : $executionLog");
		$logger->error("tma case ret_val  === : $ret_val");
				
        if ($@) {
           $logger->error("$self->{MODULE} : The testcase $_ failed because of run-time error $@");
        }

        # Test case - END timestamp
        ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
        my $TestFinishTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
        my $TestCaseExecTimeSeconds = int tv_interval ($TestStartTimeReference);
        my @execTime = reverse( ( gmtime( $TestCaseExecTimeSeconds ) )[0..2] );
        my $TestCaseExecTime = sprintf("%02d:%02d:%02d", $execTime[0], $execTime[1], $execTime[2]);

        # getting execution time and data for bangalore ATS clients
        if (defined $ENV{LOG_EXECUTION_TIME} and $ENV{LOG_EXECUTION_TIME}) {
            my $test_result = (ref($ret_val) eq 'HASH')? $ret_val->{result} : $ret_val;
            $test_result ||= 0; #considering as failed, if we didn't receive any value
	        $testresults{$TestCaseId}{'result'} = $test_result;
	        $testresults{$TestCaseId}{'testcaseid'} = $TestCaseId;
	        $testresults{$TestCaseId}{'failurecause'} = "n/a";
            if($test_result == 1) {
                $test_result = "PASS";
                $execution_time{Total_Pass}++;
                $feature{"$rerun_flag".'passedtests'}++;
            } 
            elsif($test_result == 0) { #skipping invalid(5) - TOOLS-75989
                $test_result = "FAIL";
                $execution_time{Total_Fail}++;
                $feature{"$rerun_flag".'failedtests'}++;
                $self->{METADATA} .= $main::failure_msg;
                $failure_cause .= $TestCaseId . "\t$main::failure_msg\n";
                $testresults{$TestCaseId}{'failurecause'} = $main::failure_msg;
                $feature{'failedtestslist'} .=$TestCaseId . "\t:$main::failure_msg\n";
                push (@failedTestCase,$TestCaseId) if($main::TESTSUITE->{RERUN_FAILED});
            }
            if($self->{ATTACH_FILE})
            {
              if($self->{EXTENSION}){
                if(-e "$self->{FILEPATH}/$TestCaseId.$self->{EXTENSION}"){
                  push @attachments, "$self->{FILEPATH}/$TestCaseId.$self->{EXTENSION}";
                }
                else{
                  $logger->debug(__PACKAGE__.".$self->{MODULE}: File not found. Continuing automation");
                }
              }
              else{
                $logger->debug(__PACKAGE__.".$self->{MODULE}: Not attaching file as extension is not defined");
              }
            }            
            push (@{$execution_time{testcases}}, ( {testid => $TestCaseId, test_starttime => $TestStartTime, test_endtime => $TestFinishTime, test_execution_time => $TestCaseExecTime}));
        }

        my $result;
	
		# If testcase returned a hash rather than an scalar (pass/fail)
        if (ref($ret_val) eq 'HASH') {
            $result = $ret_val->{result};

            while ( my ($key, $value) = each(%$ret_val) ){
                # Remove whitespace(s)
                $key   =~ s/^\s*//g; $key   =~ s/\s*$//g;
                $value =~ s/^\s*//g; $value =~ s/\s*$//g;

                if ( ($key ne 'result') &&
                     ($key ne 'VARIANT') ) {
                     $self->{EXTRADATA} .= "$key : $value";

                     if( ( $key =~ /reason/i ) ||
                         ( $key =~ /metadata/i ) ) {
                         $self->{METADATA} = $value;
                     }
                }
            }
        }
        else {
            $result = $ret_val;
		$ret_val->{result} = $result;
        }

        # The Extra platform variant is appended to whatever the variant that is being set by the Harness or the testcase. This is to differntiate the testcase runs on various platforms, in the reporting
        if ( defined $main::TESTSUITE->{PLATFORMVARIANT} ) {
             $TestedVariant .= $main::TESTSUITE->{PLATFORMVARIANT};
        }

        my $result_str;
        if($result eq 'TC_NOT_RUN'){
            $result_str = 'NOTRUN';
            $TestCasesNotRun++;
        }
        elsif($result=~/^\d+$/ && $result_map[$result]){ #result should be an integer and its mapped as the index in @result_map
            $result_str = $result_map[$result];
            $result_count{$rerun_flag.$result_str}++; 

            if($self->{TESTED_RELEASE}){
                $self->{METADATA} = '' unless ( defined $self->{METADATA} );
                if ( defined $main::TESTSUITE->{DUT_VERSIONS}) {
                    $build = "";
                    my ($allBuilds, $primaryBuild) = ('', 0);
                    foreach my $key (keys %{$main::TESTSUITE->{DUT_VERSIONS}}) {
                        my @type_name = split(",",$key);
                        next if($allBuilds and $allBuilds =~ /$type_name[0]/);
                        $allBuilds .= "${type_name[0]}_$main::TESTSUITE->{DUT_VERSIONS}->{$key},";
                        if ($self->{SUITE} =~ /QATEST\:\:$type_name[0]/ ) {
                            $allBuilds .= "$main::TESTSUITE->{OS_VERSION}->{$key}," if( defined $main::TESTSUITE->{OS_VERSION}->{$key});
                            $primaryBuild = 1;
                        }
                    }
                    $build = $primaryBuild ? $allBuilds : "$build,$allBuilds";
                    $build =~ s/^,|,$//g;
                }

                my $meta_data = (defined $main::TESTSUITE->{iSMART_EMAIL_LIST} and @{$main::TESTSUITE->{iSMART_EMAIL_LIST}}) ? "#!iSMART!$self->{SUITE}#\n $self->{METADATA}" : "#!ATS!$self->{SUITE}#\n $self->{METADATA}";
                $meta_data .= " Hardware Sub Type : $main::TESTSUITE->{SBX_HWSUBTYPE}" if ($main::TESTSUITE->{SBX_HWSUBTYPE})  ; 
                $build =~ s/-//g;
                $testresults{$TestCaseId}{'metadata'} = $meta_data;
                $testresults{$TestCaseId}{'starttime'} = $TestStartTime;
                $testresults{$TestCaseId}{'endtime'} = $TestFinishTime;
                $testresults{$TestCaseId}{'duration_seconds'} = $TestCaseExecTimeSeconds;
                $main::self->{BUILD_VERSION} = $build;
                $feature{'build'} = $self->{BUILD_VERSION};
                $testresults{$TestCaseId}{'variant'} = $TestedVariant if ( defined $TestedVariant );
            }
        }
        else{
            $testresults{$TestCaseId}{'starttime'} = $TestStartTime;
            $testresults{$TestCaseId}{'endtime'} = $TestFinishTime;
            $testresults{$TestCaseId}{'duration_seconds'} = $TestCaseExecTimeSeconds;
            $testresults{$TestCaseId}{'variant'} = $TestedVariant if ( defined $TestedVariant );
            $logger->warn("$self->{MODULE} : $TestCaseId: Unknown result value has returned, $result");
            $result_str = "UNKNOWN";
            $result_count{$result_str}++; #updating the UNKNOWN result
        }

        my $resultStr = ++$TotalTestCases . "\t$TestCaseId \t$result_str\t$TestCaseExecTime\t$TestStartTime\t$TestFinishTime";

        if ( defined $TestedVariant ) {
            $resultStr .= "\t$TestedVariant\t";
        }
        else {
            $resultStr .= "\t   \-\t\t";
        }

        if ( $self->{EXTRADATA} ) {
                $resultStr .= "$self->{EXTRADATA}";
                $testresults{$TestCaseId}{'EXTRADATA'} = $self->{EXTRADATA};
        }
	
	
        push ( @TestSuiteResults, "$resultStr\n" );

        unless ( $self->updateResultFile($resultStr) ) {
            $logger->warn("$self->{MODULE} : $TestCaseId: Updating test case result in File($self->{RESULTFILE}) FAILED");
        }

	    $feature{'runtests'} = $TotalTestCases;
        $testresults{$TestCaseId}{'release'} = $feature{'release'};
        $testresults{$TestCaseId}{'build'} = $feature{'build'};
        $logger->debug("$self->{MODULE} : Updating the results for testcase id: $TestCaseId --> $result_str ($result)");
        if(exists $main::TESTSUITE->{RERUN_FAILED} and $main::TESTSUITE->{RERUN_FAILED} == 0){
             $logger->debug("$self->{MODULE} : $TestCaseId: Creating Jira.");

             # In the below if condition , we are looking for (S_SBC|M_SBC|T_SBC) and if found we are not raising any TOOLS bugs, Untill Transcoding issue's are fixed in DSBC: TOOLS-12468
#             if($testresults{$TestCaseId}{'result'} !=1 and $JiraBugId eq '' and ((scalar grep { $_ =~ /(S_SBC|M_SBC|T_SBC)/  } keys %main::TESTBED) == 0) ){
                    ($logstatus,$jiraissue) = &SonusQA::Utils::do_log_result(\%testresults,\%feature,'create');
                   if(keys %{$jiraissue}){
                      $JiraBugId = $jiraissue->{id};
                      $logger->debug("PRINTING results output logstatus $logstatus jiraissue $jiraissue->{id} and url: $jiraissue->{link}");
                      $testresults{$TestCaseId}{'cq'} = $jiraissue->{id};
#                   }
            }
        }elsif($main::TESTSUITE->{RERUN_FAILED} == 1 and $reruncount == 1 and ((scalar grep { $_ =~ /(S_SBC|M_SBC|T_SBC)/  } keys %main::TESTBED) == 0)){
            $logger->debug("$self->{MODULE} : $TestCaseId: Creating Jira after rerun of failed TC.");
            if($testresults{$TestCaseId}{'result'} !=1 and $JiraBugId eq ''){
                ($logstatus,$jiraissue) = &SonusQA::Utils::do_log_result(\%testresults,\%feature,'create');
                 if(keys %{$jiraissue}){
                    $JiraBugId = $jiraissue->{id};
                    $logger->debug("PRINTING results output logstatus $logstatus jiraissue $jiraissue->{id} and url: $jiraissue->{link}");
                    $testresults{$TestCaseId}{'cq'} = $jiraissue->{id};
                }
            }
        }
        $testresults{$TestCaseId}{'cq'} = $JiraBugId if($testresults{$TestCaseId}{'result'} !=1 and defined $JiraBugId and $JiraBugId =~ /TOOLS\-.*/);
        $testresults{$TestCaseId}{'jobid'} = $main::bistq_job_uuid;
        $testresults{$TestCaseId}{'suitename'} = $self->{MODULE};
        $LogResult = 1;
        &SonusQA::Utils::atsResultUpdate($testresults{$TestCaseId});

		if (%testcaseInfo) {
			$testcaseInfo{-testcaseName} = $TestCaseName;
			$testcaseInfo{-testsuiteName} = $self->{MODULE};
			$testcaseInfo{-status} = $result_str;
			$testcaseInfo{-duration} = $TestCaseExecTime;
			$testcaseInfo{-startTime} = $TestStartTime;
			$testcaseInfo{-endTime} = $TestFinishTime;
			$testcaseInfo{-executionLog} = $executionLog;
			$self->addTestcase(%testcaseInfo);
		}
		
        #TOOLS-72075: ASAN Build failure
        #Will stop executing feature if $main::asan_build_failure flag is set.
        if($main::asan_build_failure){
            $stop_reason = "$self->{MODULE} : Stopping the feature execution, since tests failed on SBC ASAN Build.";
            $logger->debug("$stop_reason");
            $reruncount = 1;
            last;
        }

        #TOOLS-5917: BISTQ enhancement for 10 consecutive failure
        #Will stop feature execution if we got $failed_tests_threshold (= 10) consecutive failures 
        if($main::bistq_job_uuid){ 
            if($result eq 0){
                if(++$failed_tests_count == $failed_tests_threshold){
                    $stop_reason = "$self->{MODULE} : Stopping the feature execution, since we got $failed_tests_count consecutive failures. BISTQ_JOBID: $main::bistq_job_uuid";
                    $logger->debug("$stop_reason");
                    $reruncount = 1;
                    last;
                }
            }
            else{
                $failed_tests_count = 0;
            }
            next if($self->{IGNORE_COREDUMP});
            #check for core
            #TOOLS-5916: BISTQ Enhancement for Coredump issue
            #Will stop feature execution if we get $core_count_threshold (= 2) consecutive coredumps
            if($main::core_found){
                if(++$core_count == $core_count_threshold){
                    $stop_reason = "$self->{MODULE} : Stopping the feature execution, since we got $core_count consecutive core found. BISTQ_JOBID: $main::bistq_job_uuid";
                    $logger->debug("$stop_reason");
                    $reruncount = 1;
                    last;
                }
            }
            else{
                $core_count = 0;
            }
        }
    } # END - foreach() loop
    $TotalTestCases = $TotalTestCases - $TestCasesNotRun;
    $feature{$rerun_flag.'totaltestcases'} = $TotalTestCases;
    if(exists $main::TESTSUITE->{RERUN_FAILED} and $main::TESTSUITE->{RERUN_FAILED} == 1 and $reruncount == 0){
        @tests_to_run = map {"tms".$_} @failedTestCase;
        $feature{'failedtestslist'} = '';
        $reruncount = 1;
        $logger->debug("$self->{MODULE} : \n".Dumper(@tests_to_run).": You have choosen RERUN FAILED. ATS is going for rerun of the above testcases.");
        $reruntests = scalar(@tests_to_run);
        undef @failedTestCase;
        $TotalTestCases = 0;
        $rerun_flag = "rerun_";
        goto RERUN_FAILED;
   }

    # Adjust the actual test cases run.
    
    
    # to display the version info in mail, test log
    my @versionInfo = ();
    push(@versionInfo, "####################################################################");
    push(@versionInfo, sprintf( "%-15s %-15s %-15s %-15s",'Product','Name','App Version','OS Version'));
    my @versionInfo_head = ('Product','Name','App Version','OS Version');
    my @versionInfo_body;

    if ( defined $main::TESTSUITE->{DUT_VERSIONS}) {
        foreach my $key (keys %{$main::TESTSUITE->{DUT_VERSIONS}}) {
           my @type_name = split(",",$key);
           my $osinfo = ( defined $main::TESTSUITE->{OS_VERSION}->{$key}) ? $main::TESTSUITE->{OS_VERSION}->{$key} : '';
           push(@versionInfo, sprintf( "%-15s %-15s %-15s %-15s",$type_name[0],$type_name[1],$main::TESTSUITE->{DUT_VERSIONS}->{$key},$osinfo));
           push @versionInfo_body, ["$type_name[0]","$type_name[1]","$main::TESTSUITE->{DUT_VERSIONS}->{$key}","$osinfo"];
           
        }
    }
    # display test tools
    foreach my $key (keys %main::TESTBED) {
       next unless ($key =~ /(\S+)_count/);
       my $device = $1;
       foreach my $count (1..$main::TESTBED{$key}) {
          next if ($device =~ /(sbx|sgx|gsx|psx|brx|ems|vmccs)/);
          push(@versionInfo, sprintf( "%-15s %-15s %-15s %-15s",uc($device), $main::TESTBED{"$device:$count"}->[0], '-', '-'));
          push @versionInfo_body, [uc($device),$main::TESTBED{"$device:$count"}->[0],'-','-'];
       }
    }


    # open out file and write the content
    my $f;
    unless ( open OUTFILE, $f = ">$self->{RESULTFILE}" ) {
         $logger->error("$self->{MODULE} :  Cannot open output file \'$self->{RESULTFILE}\'- Error: $!");
         $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
         return 0;
    }

    print OUTFILE join("\n",@versionInfo);
    print OUTFILE "\n\n";
    print OUTFILE (@TestSuiteResults);
    print OUTFILE "\n\n########################### Failure Cause Capture ##############################\nTestcase_ID\tFailure-Reason\t\n##################################################################################\n";
    print OUTFILE ($failure_cause);
    unless ( close OUTFILE ) {
         $logger->error("$self->{MODULE} :  Cannot close output file \'$self->{RESULTFILE}\'- Error: $!");
         $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
         return 0;
    }

    $TestSuiteEndTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
    $TestSuiteEndTimestamp = `date`;
    chomp $TestSuiteEndTimestamp;
    $TestSuiteExecInterval = int tv_interval ($StartTimeReference);
	
    if (defined $ENV{LOG_EXECUTION_TIME} and $ENV{LOG_EXECUTION_TIME}) {
        $execution_time{feature_endtime} = $TestSuiteEndTime;
        my @temp_time = reverse( ( gmtime( int tv_interval ($StartTimeReference) ) )[0..2] );
        $execution_time{execution_time} = sprintf("%02d:%02d:%02d", $temp_time[0], $temp_time[1], $temp_time[2]);
	$FeatureRunTime = $execution_time{execution_time};
        $execution_time{userid} = $self->{USERID};

        unless (SonusQA::Utils::logExecutionTime(\%execution_time) ) {
           $logger->error("$self->{MODULE} : ***************unable to log execution time to database****************");
        }
    }

    # CPP Unit XML results output (for Jenkins)
    # See http://wiki.sonusnet.com/display/~mlashley/BISTQ+to+Jenkins+result+reporting for notes on design/formatting etc.
    # For JUnit doc: https://github.com/windyroad/JUnit-Schema/blob/master/JUnit.xsd

    my $passxml="";
    my $failxml="";
    my $id=1;
    my $passcount=0; 
    my $failcount=0;

    my $testcase_junitxml = '';
	
    foreach my $tcid (keys %testresults) {
        if($testresults{$tcid}->{'result'} == 1) { # PASS
            $passxml .= '<Test id="'.$id.'">';
            $passxml .= "<Name>$self->{SUITE}::$tcid</Name>"; 
            $passxml .= "</Test>\n";
			
            $testcase_junitxml .= '<testcase name="'. $self->{SUITE} .'::'. $tcid .'" time="'. $testresults{$tcid}{duration_seconds} .'"></testcase>' . "\n";

	    $passcount++;
        } elsif ($testresults{$tcid}->{'result'} == 0) { # FAIL
            $failxml .= '<FailedTest id="'.$id.'">';
            $failxml .= "<Name>$self->{SUITE}::$tcid</Name>";
            $failxml .= "<FailureType>ATS</FailureType>";
	    my $failmsg = $testresults{$tcid}{'failurecause'} ? $testresults{$tcid}{'failurecause'} : "ATS Test Failed";
		
            $testcase_junitxml .= '<testcase name="'. $self->{SUITE} .'::'. $tcid .'" time="'. $testresults{$tcid}{duration_seconds} .'">' . "\n";
            $testcase_junitxml .= '<failure message="'. $failmsg .'" type="ERROR">' . "\n";			
			
            $failmsg .= "\n$testresults{$tcid}{'EXTRADATA'}" if ($testresults{$tcid}{'EXTRADATA'});
			
            $testcase_junitxml .= "$failmsg\n";
            $testcase_junitxml .= "</failure></testcase>\n";
			
            $failxml .= "<Message>$failmsg</Message>";
            $failxml .= "</FailedTest>\n";
	    $failcount++;
        } else { # Handle other options here? 
        }
        $id++;
    }
    my $totalcount = $passcount + $failcount;

    my $cppunitxml = '<?xml version="1.0"?>' . "\n";
    $cppunitxml .= '<?xml-stylesheet type="text/xsl" href="http://swdev/Transforms/displaycppunit.xsl"?><TestRun>' . "\n";
    $cppunitxml .= "<FailedTests>$failxml</FailedTests>";
    $cppunitxml .= "<SuccessfulTests>$passxml</SuccessfulTests>";
    $cppunitxml .= "<Statistics> <Tests>$totalcount</Tests> <FailuresTotal>$failcount</FailuresTotal> <Errors>0</Errors> <Failures>0</Failures> </Statistics>";
    $cppunitxml .= "</TestRun>";
   
    chomp (my $hostname = `hostname`);
 
    my $junitxml = '<?xml version="1.0" encoding="UTF-8" ?>' . "\n";
    $junitxml .= '<testsuite name="'. $self->{SUITE} .'" tests="'. $totalcount .'" failures="'. $failcount .'" errors="'. $failcount .'" time="'. $TestSuiteExecInterval .'" hostname="'. $hostname .'" timestamp="'. $TestSuiteEndTime .'">' . "\n";
    $junitxml .= $testcase_junitxml;
    $junitxml .= "</testsuite>\n";
	
    unless ( open OUTFILE, $f = ">$self->{RESULTFILE}_jenkins.xml" ) {
         $logger->error("$self->{MODULE} :  Cannot open output file \'$self->{RESULTFILE}_jenkins.xml\'- Error: $!");
         $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
         return 0;
    }

    print OUTFILE ($main::junit) ? $junitxml : $cppunitxml;

    unless ( close OUTFILE ) {
         $logger->error("$self->{MODULE} :  Cannot close output file \'$self->{RESULTFILE}_jenkins.xml\'- Error: $!");
         $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
         return 0;
    }

    #Archive logs created on this run and remove the original logs (TOOLS-5197)
    my $archive_cmd;
    if($main::TESTSUITE->{ARCHIVE_LOGS}){
        (my $tar_file = $self->{LOGDIR}) =~s/.+\/(.+)$/$1/;
        $tar_file =~s/[\/\s]//g;

        (my $tar_time = $TestSuiteStartTime)=~s/[-:]//g;
        $tar_time =~s/\s+/-/g;
        (my $after_date = $TestSuiteStartTime)=~s/:\d+$//; #Fix for TOOLS-15490 - removing seconds
        if($main::bistq_job_uuid) { # Include JobId in filename for easy Jenkins grabbing
            my $jobid = $main::bistq_job_uuid;
            $jobid =~ s/-/_/g;
            $ENV{ARCHIVE_LOG_FILE} = "$ENV{HOME}/ats_user/logs/${tar_file}_$self->{BUILD_VERSION}_${tar_time}_${jobid}.tar";
        } else {
            $ENV{ARCHIVE_LOG_FILE} = "$ENV{HOME}/ats_user/logs/${tar_file}_$self->{BUILD_VERSION}_${tar_time}.tar";
        }
        $ENV{ARCHIVE_CMD} = "tar -czf $ENV{ARCHIVE_LOG_FILE} --after-date='$after_date' --remove-files $self->{LOGDIR} 2>/dev/null"; # archive will happen in END of SonusQA::Base
    }

    $feature{'endtime'} = $TestSuiteEndTimestamp;
    $feature{'runtime'} = $FeatureRunTime;
    $feature{'runtests'} = $TotalTestCases;
    $feature{'failedtests'} = $feature{'failedtests'} - $feature{$rerun_flag.'passedtests'} if($reruntests);

    # In the below if condition , we are looking for (S_SBC|M_SBC|T_SBC) and if found we are not raising any TOOLS bugs, Untill Transcoding issue's are fixed in DSBC: TOOLS-12468
#    if($feature{'failedtests'} and ((scalar grep { $_ =~ /(S_SBC|M_SBC|T_SBC)/  } keys %main::TESTBED) == 0)){
      ($logstatus,$jiraissue) = &SonusQA::Utils::do_log_result(\%testresults,\%feature,'',$JiraBugId);
       $logger->debug("PRINTING results output logstatus $logstatus jiraissue ".defined  $jiraissue);
#    }

    ##################################################
    # mail the results after execution of testsuite
    ##################################################

    my $subject = "";
    my $filename = "$self->{RESULTFILE}";
    my $from = "$ENV{USER}\@rbbn.com";
    my $to = join ', ', @{$self->{EMAIL_LIST}};
    my $title = "ATS Results : $self->{BUILD_VERSION} / $self->{SUITE}";
    $logger->debug("$self->{MODULE} : Sending the mail to: $to");
    # Email Header
    $ENV{SEND_FAILURE_MAIL}=0;    #TOOLS 19330
    open(my $SENDMAIL,'+>', "/tmp/$ENV{USER}_email.txt") or die "Cannot open /tmp/$ENV{USER}_email.txt";
    open(RESULT, "$self->{RESULTFILE}") or die "cannot open file $self->{RESULTFILE}";
    my @fileContent;
    
    # Email Contents
    print $SENDMAIL '<html>
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <style type = text/css>{BODY{margin:0px;font:normal normal normal 12px/normal verdana,arial,tahoma}H5{font-size:110%;margin-left:15px}a:link{color:#00E;text-decoration:underline}a.fake{cursor:pointer;color:#039;text-decoration:underline}.testcase{padding-left:2px;padding-right:2px;color:red;font-weight:bold;FONT-SIZE:12px;text-decoration:none}a.testcase_title{text-decoration:none}a.testcase_title_report{text-decoration:none;color:maroon;FONT-SIZE:10px}a.header{text-decoration:underline;FONT-SIZE:10px;font-weight:bold}table.body{border-width:1px;border-style:outset;border-color:gray;border-collapse:collapse}tr.body{vertical-align:middle}td.body{border-style:inset;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px}td.body_text_smaller{vertical-align:middle;background-color:#E6E6FA;border-style:inset;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:10px}td.body_text_smaller_align{border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:10px}td.body_text_smaller_align_red{border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:10px;color:white;font-weight:bold}td.body_text{background-color:#E6E6FA;border-style:inset;text-align:left;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px}td.body_text_align{background-color:#E6E6FA;border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px}td.body_text_align_left{background-color:#E6E6FA;border-style:inset;text-align:left;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px}table.content_split{width:100%}td.body_no_border{FONT-SIZE:11px;text-align:left}td.body_no_border_text_align_left{FONT-SIZE:11px;text-align:left}td.body_no_border_text_align_right{FONT-SIZE:11px;text-align:right}td.body_text_align_fixedwidth{width:100px;background-color:#E6E6FA;border-style:inset;text-align:center;border-width:1px;border-color:gray;FONT-SIZE:11px}td.body_text_align_totals{background-color:#ECE5B6;border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px;font-weight:bold}td.body_text_align_totals_fixedwidth{width:100px;background-color:#ECE5B6;border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px;font-weight:bold}td.header{border-style:inset;text-align:center;border-width:1px;border-color:gray;padding:5px;FONT-SIZE:11px;font-weight:bold}span.bug_resolved{padding:1px;font-size:10px;color:gray}span.bug_unresolved{padding:1px;font-size:10px}span.bug_unresolved_gating{padding:1px;font-size:10px;color:black;background-color:#FF5454}span.bug_unresolved_beta_gating{padding:1px;font-size:10px;color:black;background-color:#FFB52B}ol.none,ul.none,li.none{list-style-type:disc;margin-left:15px;padding-top:10px;padding-left:4px}pre.none{width:420px;margin:15px;background:#f0f0f0;border:1px solid #ccc;overflow:auto;overflow-Y:hidden}pre.none code{margin:0 0 0 5px; padding:15px;display:block}h1.heading{font-size:16px;background:#f5f5f5;font-weight:bold;letter-spacing:1px;border-top:1px solid #CCC;border-bottom:1px solid #CCC;padding:10px 0px 10px 10px}div.hr{background:#CCC;height:1px;line-height:1px;margin:5px 0px;overflow:hidden}div.description{color:dimGray;background:#F8F8F8;border:1px dotted #CCC;font-size:12px;line-height:14px;margin:15px;padding:7px}pre{font:normal normal normal 12px/normal verdana,arial,tahoma}h1{font:normal normal normal 24px/normal verdana,arial,tahoma}h2{font:bold normal normal 20px/normal verdana,arial,tahoma}</style>
    </head>
    ';
    
    print $SENDMAIL "<body>";
    print $SENDMAIL "<div class='description'><h2 id= 'testcase_title_report'>Execution Details: </h2>";
    print $SENDMAIL "<div class='description'><font color=' #ff8000'><b>$stop_reason</b></font>" if ($stop_reason);
    print $SENDMAIL "<br>";

    print $SENDMAIL "
    <table class='body' style='margin-left:15px;margin-right:10px;'>
        <tbody>";
    if($reruntests){
        print $SENDMAIL "
            <thead>
            <th></th>
            <th>Actual</th>
            <th>Rerun</th>
            </thead>
            ";
    }
    
    #Adding failed testcases to the mail
    $result_count{$result_map[0]} ||= 0;
    $result_count{$rerun_flag.$result_map[0]} ||= 0;
    print $SENDMAIL "<tr><td style='text-align:center'>Total Test Case(s)&nbsp;<font color = 'red'> $result_map[0]</font></td>
                        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'><font color = 'red'>$result_count{$result_map[0]}</font></td>";
    print $SENDMAIL "<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'><font color = 'red'>$result_count{$rerun_flag.$result_map[0]}</font></td>" if($reruntests);
    print $SENDMAIL "</tr>";

    #Adding passed testcases to the mail
    $result_count{$result_map[1]} ||= 0;
    $result_count{$rerun_flag.$result_map[1]} ||= 0;        
    print $SENDMAIL "<tr><td style='text-align:center'>Total Test Case(s)&nbsp;<font color = 'green'> $result_map[1]</font></td>
                        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'><font color = 'green'>$result_count{$result_map[1]}</font></td>";
    print $SENDMAIL "<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'><font color = 'green'>$result_count{$rerun_flag.$result_map[1]}</font></td>" if($reruntests);
    print $SENDMAIL "</tr>";

    #Adding the remaining cases to the mail.
    for (my $i=2; $i<@result_map;$i++){
         $result_count{$result_map[$i]} ||= 0;
         $result_count{$rerun_flag.$result_map[$i]} ||= 0;
        if($result_count{$result_map[$i]} > 0) {
            print $SENDMAIL "<tr><td style='text-align:center'>Total Test Case(s)&nbsp; $result_map[$i]</td>
                               <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$result_count{$result_map[$i]}</td>";
            print $SENDMAIL "<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$result_count{$rerun_flag.$result_map[$i]}</td>" if($reruntests);
            print $SENDMAIL "</tr>"; 
         }    
    }

    #Modifying the subject of the mail.
    if($reruntests){
        if($result_count{$rerun_flag.$result_map[0]}){
            $subject = "RERUN FAILED ($result_count{$rerun_flag.$result_map[0]}/".($feature{'totaltests'}).")";
        } else {
            $subject = "RERUN PASSED ($result_count{$rerun_flag.$result_map[1]}/".($feature{'totaltests'}).")";
        }
    } else {
        if($result_count{$result_map[0]}){
            $subject = "FAILED ($result_count{$result_map[0]}/$feature{'totaltests'})";
        } else {
            $subject = "PASSED ($result_count{$result_map[1]}/$feature{'totaltests'})";
        }
    }

    $title = $title." / ".$subject;

    print $SENDMAIL "<tr> 
                        <td style='text-align:center'>Total Test Case(s) Executed</td>
                        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>".($feature{'totaltestcases'})."</td>".(($reruntests)?("<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>".($feature{$rerun_flag.'totaltestcases'})."</td></tr>"):"</tr>");
    print $SENDMAIL "<tr><td style='text-align:center'>Total Test Case(s) Not Run</td>
                     <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$TestCasesNotRun</td>".(($reruntests)?"<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>".($reruntests - ($feature{$rerun_flag.'totaltestcases'}))."</td></tr>":"</tr>");
    print $SENDMAIL "<tr><td style='text-align:center'>Actual Test Case(s) in Suite</td>
                     <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$ActualTestCases</td>".(($reruntests)?"<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>".($reruntests)."</td></tr>":"</tr>");
    print $SENDMAIL "</tbody></table><br><br>";

    if(keys %{$jiraissue}){
    print $SENDMAIL "<li> JIRA Issue created for failed testcases: $jiraissue->{id} </li>";
    print $SENDMAIL "<li> \nJIRA Issue link : $jiraissue->{'link'}</li>";
    print $SENDMAIL "<br><br>";
    }
    print $SENDMAIL "
        <table class='body' style='margin-left:15px;margin-right:10px;'>
          <tbody>";
    print $SENDMAIL "<tr><td style='text-align:center'> AUTOMATION RESULTS</td>
                         <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$self->{SUITE}</td><br></tr>";
    print $SENDMAIL "<tr><td> TESTSUITE PATH\/FILE</td>
                         <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$self->{SUITE_PATH_FILE}</td><br></tr>";
    if ( defined $self->{SUITE_INFO} ) {
        print $SENDMAIL "<tr><td style='text-align:center'> TESTSUITE INFOMATION</td>
                             <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$self->{SUITE_INFO}</td><br></tr>";
    }

    if ( defined $self->{TESTED_RELEASE} ) {
        print $SENDMAIL "<tr><td style='text-align:center'> TESTED RELEASE</td>
                             <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$self->{TESTED_RELEASE}</td><br></tr>";
    }

    if ( defined $self->{BUILD_VERSION} ) {
        print $SENDMAIL "<tr><td style='text-align:center'> TESTED BUILD</td>
                             <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$self->{BUILD_VERSION}</td><br></tr>";
    }
    print $SENDMAIL "</tbody></table><br>";
  
    print $SENDMAIL "
        <table class='body' style='margin-left:15px;margin-right:10px;'>
          <thead>";
    foreach (@versionInfo_head) {
      print $SENDMAIL "<th class='header'>$_</th>";
    }
    print $SENDMAIL "</thead><tbody>";
    foreach my $rows (@versionInfo_body) {
      print $SENDMAIL "<tr>";
      foreach (@{$rows}){
        print $SENDMAIL "<td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$_</td>";
      }
      print $SENDMAIL "<br></tr>";
    }
    print $SENDMAIL "</tbody></table>";
    print $SENDMAIL "<p></p>";
    print $SENDMAIL "<br><br>";
    print $SENDMAIL "<b>Execution Started At : $TestSuiteStartTime</b>";
    print $SENDMAIL "<br>";
    print $SENDMAIL "<b>Execution Completed At  : $TestSuiteEndTime</b>";
    print $SENDMAIL "<br>";

    if ( defined ($TestSuiteExecInterval) ) {
          my @duration = reverse((gmtime($TestSuiteExecInterval))[0..2]);
          $TestSuiteExecTime = sprintf( "%02d:%02d:%02d", $duration[0], $duration[1], $duration[2] );
          print $SENDMAIL "<b>Execution Duration      : $TestSuiteExecTime</b>";
          print $SENDMAIL "<br>";
    }

	if (%testcaseInfo) {
		my %testsuiteInfo = (-token => $testcaseInfo{-token}, -baseUrl => $testcaseInfo{-baseUrl}, -testsuiteId => $testcaseInfo{-testsuiteId},
							-duration => $TestSuiteExecTime, -status => "Complete");
		sleep(3);
		#$logger->info("$self->{MODULE} : ***************testsuite info  *************".Dumper(\%testsuiteInfo));
		&updateTestsuite(%testsuiteInfo);
	}
	
    print $SENDMAIL "
        <table class='body' style='margin-left:15px;margin-right:10px;'>
          <thead>
              <th class='header'>No.</th>
              <th class='header'>TestCase ID</th>
              <th class='header'>Result</th>
              <th class='header'>ExecTime</th>
              <th class='header'>StartTime</th>
              <th class='header'>EndTime</th>
              <th class='header'>Variant</th>
              <th class='header'>Previous Results</th>
              <th class='header'>Info</th>
          </thead>
          <tbody>
      ";
    my $check = join('|',@result_map,'NOTRUN','Invalid');
    while(<RESULT>) {
      my @temp = ();
      push (@fileContent, $_);
      next unless($_ =~ /($check)/);
        my ($no,$tcid, $result, $exectime, $start_date_time, $end_date_time, $variant,$info) = split(/\t/,$_);
        my $color;
        $tcid =~ s/\s+//g;
        if($result =~ /PASSED/) {
          $color = "#66FE66";#green
        }
        elsif($result =~ /FAILED/){
          $color = "#FE6666";#red
        }
        else{
          $color = "#DCDCF5";#lavender
        }

        print $SENDMAIL "<tr>
        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$no</td>
        <td class='body_text_align_fixedwidth' style='background-color:$color; text-align:center'><a href=https://tms-inba.rbbn.com/search/execute/?query=sons_testcase_id='$tcid'&order_by=sons_project_title&table=t> $tcid </a></td>
        <td class='body_text_align_fixedwidth' style='background-color:$color; text-align:center'> &nbsp;$result&nbsp; </td>
        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>&nbsp;$exectime&nbsp;</td>
        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'> $start_date_time&nbsp; </td>
        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'> $end_date_time&nbsp; </td>
        <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'> &nbsp;$variant&nbsp; </td>
        <td class='body_text_align_fixedwidth' style='background-color:lavender; text-align:center'><a href=https://wiki.sonusnet.com/display/~mlashley/TMS+Lookup+Previous+Results?pageId=84018386&run_1_testid=$tcid&run_1=run>Click Here</a></td>
        <td class='body_text_align_fixedwidth' style='background-color:lavender; text-align:center'> &nbsp;$info&nbsp; </td>
        </tr><br>";
      }
    print $SENDMAIL "</tbody></table>";
    print $SENDMAIL "<br>";
    print $SENDMAIL "<br>";

    print $SENDMAIL "<h2>Logs: </h2>";
    print $SENDMAIL "<p>Harness Log Directory : $self->{LOGDIR}</p>";

    if($ENV{'ARCHIVE_LOG_FILE'}){
        print $SENDMAIL "<p>Archived Log File     : $ENV{'ARCHIVE_LOG_FILE'}</p>";
    }
    else{
        print $SENDMAIL "<p>Harness Result File   : $self->{RESULTFILE}</p>";

        $ENV{'ATS_LOG_FILE'} = SonusQA::Utils::getLoggerFile('AtsLog'); #get the current ATS log file name
        print $SENDMAIL "<p>ATS Log File          : $ENV{'ATS_LOG_FILE'}</p>";
        $ENV{'TEST_LOG_FILE'} = SonusQA::Utils::getLoggerFile('TestRunLog'); #get current Test log file name
        print $SENDMAIL "<p>TEST Log File         : $ENV{'TEST_LOG_FILE'}</p>";
    }
    print $SENDMAIL "<br>";
    if($failure_cause) {
      my @failures = split "\n",$failure_cause;
        
      print $SENDMAIL "<h2>Failure Cause Capture:</h2>";
      print $SENDMAIL "
          <table class='body' style='margin-left:15px;margin-right:10px;'>
            <thead>
                <th class='header'>Testcase_ID</th>
                <th class='header'>Failure-Reason</th>
            </thead>   
            ";
      
      print  $SENDMAIL "<tbody>";
      foreach my $failed_test (@failures){
        $failed_test =~ /(\d+)\s+(.*)/;
        print  $SENDMAIL "
                            <tr>
                              <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$1</td>
                              <td class='body_text_align_fixedwidth' style='background:lavender; text-align:center'>$2</td>
                            <br></tr>";
      
      }
      print  $SENDMAIL "</tbody></table>";
    }

    if(defined $self->{ADDITIONAL_INFO}) {
    print $SENDMAIL "
        <h2>Additional Info:</h2>
        <table class='body' style='margin-left:15px;margin-right:10px;'>
          <tbody>";
      foreach my $info (keys %{$self->{ADDITIONAL_INFO}}){
              if(grep /https:|http:/, $self->{ADDITIONAL_INFO}->{$info}){
                print $SENDMAIL "<tr><td style='text-align:center'> $info</td><td class='body_text_align_fixedwidth style='background:lavender; text-align:center'><a href=$self->{ADDITIONAL_INFO}->{$info} >$self->{ADDITIONAL_INFO}->{$info}</a></td></tr><br>";
              }
              else{
                print $SENDMAIL "<tr><td style='text-align:center'> $info</td><td class='body_text_align_fixedwidth style='background:lavender; text-align:center'>$self->{ADDITIONAL_INFO}->{$info}</td></tr><br>";
              }
      }
      print $SENDMAIL "</tbody></table><br>";
    }

    print $SENDMAIL "<br></div>";
    print $SENDMAIL "</body></html>";
    close($SENDMAIL);
    open($SENDMAIL,'<', "/tmp/$ENV{USER}_email.txt") or return "Cannot open message.txt";
    my $message =  do { local $/; <$SENDMAIL> };;
    
    my $msg = MIME::Lite->new(
                 From     => $from,
                 To       => $to,
                 Subject  => $title,
                 Type     => 'multipart/mixed'
                 );
    $msg->attach(
             Type         => 'text/html',
             Data         => $message,
             );
    $msg->attach(
             Type =>'application/octet-stream',
             Encoding => "base64",
             Path         => $filename,
             Disposition  => 'attachment'
            );

    foreach (@attachments){
      $msg->attach(
             Type =>'application/octet-stream',
             Encoding => "base64",
             Path         => $_,
             Disposition  => 'attachment'
            );      
    }
    close($SENDMAIL);
    $msg->send;             

    if(-e "/tmp/$ENV{USER}_email.txt"){
      unlink("/tmp/$ENV{USER}_email.txt") or warn "Could not unlink /tmp/$ENV{USER}_email.txt: $!"; #Deleting the file created.
    }
    # Save Results to Summary File when running multiple suites
    my $resultStr =  sprintf("%-40s %-10s %-10s %-10s %-10s %-10s %-30s", $self->{MODULE},$result_count{$result_map[1]},$result_count{$result_map[0]},$TotalTestCases,$ActualTestCases,($self->{SUITE_INFO}||'-'));
    $self->updateResultSummaryFile($resultStr);

    $logger->info("$self->{MODULE} : -------------------------------------------------");
    $logger->info("$self->{MODULE} : Test Suite Exec Duration     : $TestSuiteExecTime\n");

    for (my $i=0; $i<@result_map;$i++){
        $logger->info("$self->{MODULE} : Total Test Case(s) $result_map[$i]    : $result_count{$result_map[$i]}");
    }

    $logger->info("$self->{MODULE} : Total Test Case(s) Executed  : ".(($reruntests)?($feature{'totaltestcases'}+$feature{$rerun_flag.'totaltestcases'}):($feature{'totaltestcases'})));
    $logger->info("$self->{MODULE} : Total Test Case(s) Not Run   : $TestCasesNotRun");
    $logger->info("$self->{MODULE} : Actual Test Case(s) in Suite : $ActualTestCases\n");
    $logger->info("$self->{MODULE} : -------------------------------------------------");
    if(keys %{$jiraissue}){
        $logger->info("$self->{MODULE} : JIRA Issue created for failed testcases: $jiraissue->{'id'} ");
	$logger->info("$self->{MODULE} : JIRA Issue link : $jiraissue->{'link'}");
	$logger->info("$self->{MODULE} : -------------------------------------------------");
    }
    $logger->info("$self->{MODULE} : Harness Log Directory : $self->{LOGDIR}");

    if($ENV{'ARCHIVE_LOG_FILE'}){
        $logger->info("$self->{MODULE} : Archived Log File : $ENV{'ARCHIVE_LOG_FILE'}");
    }
    else{
        $logger->info("$self->{MODULE} : Harness Result File   : $self->{RESULTFILE}");
        if ( defined $ENV{'ATS_LOG_FILE'} ) {
            $logger->info("$self->{MODULE} : ATS Log File          : $ENV{'ATS_LOG_FILE'}");
        }
        if ( defined $ENV{'TEST_LOG_FILE'} ) {
            $logger->info("$self->{MODULE} : TEST Log File         : $ENV{'TEST_LOG_FILE'}");
        }
    }

    $logger->info("$self->{MODULE} : -------------------------------------------------");
    $logger->info("$self->{MODULE} : Test execution for $self->{SUITE} COMPLETE.");

    $main::TESTSUITE->{DUT_VERSIONS} = {} if (defined $main::TESTSUITE->{DUT_VERSIONS}); # i will clear all the application version stored for the suite 
    $main::TESTSUITE->{OS_VERSION} = {} if (defined  $main::TESTSUITE->{OS_VERSION}); # i will clear all the os version stored for the suite

    #Executing the command to archive logs created on this run and remove the original logs
    `$archive_cmd` if($archive_cmd);

    return 1;
}

#########################################################################################################

sub updateResultFile {
    my $self   = shift;
    my $result = shift;
    my $subName = 'updateResultFile()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    # open out file and write the content
    my $f;
    unless ( open MYFILE, $f = ">>$self->{RESULTFILE}" ) {
         $logger->error("  Cannot open output file \'$self->{RESULTFILE}\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    print MYFILE "$result\n";

    unless ( close MYFILE ) {
         $logger->error("  Cannot close output file \'$self->{RESULTFILE}\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    return 1;
}


sub updateResultSummaryFile {
    my $self   = shift;
    my $result = shift;
    my $subName = 'updateResultSummaryFile()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    # open out file and write the content
    my $f;
    unless ( open MYFILE, $f = ">>$self->{SUMMARYFILE}" ) {
         $logger->error("  Cannot open output file \'$self->{SUMMARYFILE}\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    print MYFILE "$result\n";

    unless ( close MYFILE ) {
         $logger->error("  Cannot close output file \'$self->{SUMMARYFILE}\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    #######################################
    ##### Adding header to summuary file###
    ######################################3
    unless (`grep  'FEATURE.*PASS.*FAIL' $self->{SUMMARYFILE}`) {
        my @header = ("#####################################################################################", sprintf("%-40s %-10s %-10s %-10s %-10s %-30s",'FEATURE NAME','PASS','FAIL','TOTAL','ACTUAL','SUITE INFO'), "#####################################################################################");
        foreach my $h (@header) {
            if(`sed -i "1i $h" $self->{SUMMARYFILE}`) {
                $logger->error("$self->{MODULE} : failed add header to file $self->{SUMMARYFILE}");
            }
        }
    }

    ############Toatl calculation for ResultSummaryFile##############
    my @result_summary = `cat $self->{SUMMARYFILE}`;
    my @total = (0,0,0,0);
    foreach my $line (@result_summary) {
         if ($line =~ /No such file or directory/) {
              $logger->error("$self->{MODULE} : unable to read the file $self->{SUMMARYFILE}, total wont be calculated");
              last;
         }
         next if ($line =~ /(====|FEATURE NAME|TOTAL|####)/);
         chomp $line;
         next if ($line =~ /^\s+$/);
         my @temp = split(/\s{3,}/, $line);
         @temp = grep /\S/, @temp;
         shift @temp;
         map {($temp[$_] and $temp[$_] =~ /^\d+$/) and $total[$_] += $temp[$_]} 0..3; #finding the total of all the features
    }

    ######removing the older TOTAL######
    if (`sed -i '/===.*/,+2d' $self->{SUMMARYFILE}`) {
         $logger->error("$self->{MODULE} : unable to drop TOTAL row from $self->{SUMMARYFILE}");
    }

    #############Adding TOTAL footer to ResultSummaryFile#############
    my $footer = sprintf("%-40s %-10s %-10s %-10s %-10s %-10s",'TOTAL',@total);
    `echo -e "=====================================================================================\n$footer\n=====================================================================================" >>$self->{SUMMARYFILE}`;

    return 1;
}

#########################################################################################################

sub updateSuiteInfo {
    my $self   = shift;
    my $suiteInfo = shift;
    my $subName = 'updateSuiteInfo()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub : $suiteInfo");
    $self->{SUITE_INFO} = $suiteInfo;

    return 1;
}


#########################################################################################################

### TMA Analytics ###
=head 
	Sub: Login => to get token
    Mandatory: - baseUrl
			   - username
			   - password
              
    Return: 1 if pass
            0 if fail
    my %args = (-baseUrl => 'http://10.250.193.189:3000', -username => 'admin', -password => '***');
    
    Ex: SonusQA::HARNESS::login(%args);
=cut

sub login {
    my (%args) = @_;
    my $sub_name = 'login()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	my $flag = 1;
    foreach ('-baseUrl', '-username', '-password') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
    my $url = $args{-baseUrl}.'/user/authenticate';
	my $body = "{\"username\": \"$args{-username}\",\"password\": \"$args{-password}\"}";
 
	my ($responcecode,$responsecontent) = SonusQA::Base::restAPI(-url => $url, 
																 -contenttype => 'JSON',
																 -method => 'POST',
																 -arguments => $body);
    unless ($responcecode == 200) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to Login with username : '$args{-usernamr}' and password: '$args{-password}'. Message error: ".$responsecontent);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
	}
	my ($token) = $responsecontent =~ /\"jwt\":\"(.+)\",/; 
	
    $logger->info(__PACKAGE__ . " .$sub_name : Login successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$token]");
    return $token;
}  

=head
    Mandatory: - baseUrl
			   - project
              
    Return: projectId 
    my %args = (-baseUrl => 'http://10.250.193.189:3000', -project => 'AS');
    
    Ex: my $projectId;
		unless($projectId = (SonusQA::HARNESS::getProjectId(%args))) {
			$logger->error(__PACKAGE__ . ": Failed to get project Id ");
			return 0;
		} 
=cut

sub getProjectId {
    my (%args) = @_;
    my $sub_name = 'getProjectId()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	my $flag = 1;
    foreach ('-baseUrl', '-project') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);

    my $url = $args{-baseUrl}.'/project';
	my ($responcecode,$responsecontent) = (SonusQA::Base::restAPI(-url => $url, -contenttype => 'JSON', -method => 'GET', -token => $args{-token}));
    unless ($responcecode == 200) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to send REST API to get project info!. Error : $responcecode - $responsecontent");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
	}
	unless ($responsecontent =~ /$args{-project}/) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to find project $args{-project} in $responsecontent");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
	}
	my ($projectId) = $responsecontent =~ /"_id":\s*"(\w*)","projectname":\s*"$args{-project}"/;  
    $logger->error(__PACKAGE__ . " .$sub_name : Get project id successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$projectId]");
    return $projectId;
}  

=head
    Mandatory: - baseUrl
			   - projectId
			   - testsuiteName
			   - executionDate
			   - totalTCs
              
    Return: 1 if pass
            0 if fail
    my %args = (-baseUrl => 'http://10.250.193.189:3000', -projectId => '5e8b59c1c51c454238c9c830',
				-testsuiteName => 'TEMPLATE', -executionDate => '2020-03-13 00:10:00', -totalTCs => 2);
    
    Ex: SonusQA::HARNESS::addTestsuite(%args);
=cut

sub addTestsuite {
    my (%args) = @_;
    my $sub_name = 'addTestsuite()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	my $flag = 1;
    foreach ('-baseUrl', '-projectId', '-testsuiteName', '-source', '-executionDate', '-totalTCs') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
    my $url = $args{-baseUrl}.'/testsuites';
	my $body = "\{\"projectId\": \"$args{-projectId}\", \"testsuiteName\": \"$args{-testsuiteName}\", \"source\": \"$args{-source}\", \"executionDate\": \"$args{-executionDate}\", \"totalTCs\": $args{-totalTCs} \}";
 
	my ($responcecode,$responsecontent) = SonusQA::Base::restAPI(-url => $url, 
																-token => $args{-token},
																 -contenttype => 'JSON',
																 -method => 'POST',
																 -arguments => $body);
    unless ($responcecode == 200) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to Add testsuite $args{-testsuiteName}. Message error: ".$responsecontent);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
	}
	my ($testsuiteId) = $responsecontent =~ /"_id":\s*"(\w*)"/; 
	
    $logger->info(__PACKAGE__ . " .$sub_name : Add testsuite $args{-testsuiteName} successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$testsuiteId]");
    return $testsuiteId;
}  

=head
    Mandatory: - baseUrl
			   - testsuiteId
			   - duration
			   - 
              
    Return: 1 if pass
            0 if fail
    my %args = (-baseUrl => 'http://10.250.193.189:3000', -testsuiteId => '5eb3e3475eed648484c1cb59',
				-duration => 10000, -executedTCs => 2,
				-passedTCs => 2, -failedTCs => 0, -skippedTCs => 0, -passRate => 100, -status => 'Complete'
				);
    
    Ex: SonusQA::HARNESS::updateTestsuite(%args);
=cut

sub updateTestsuite {
    my (%args) = @_;
    my $sub_name = 'updateTestsuite()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	my $flag = 1;
    foreach ('-baseUrl', '-testsuiteId', '-duration', '-status') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
 
    my $url = $args{-baseUrl}.'/testsuites/'.$args{-testsuiteId};
	my ($h, $m, $s) = $args{-duration} =~ /(\d{2}):(\d{2}):(\d{2})/;
	my $duration = ($h*3600 + $m*60 + $s)*1000;
	my $body = "{\"duration\": $duration,\"status\": \"$args{-status}\"}";
 $logger->debug(__PACKAGE__ . ".$sub_name: <-- bbody " . $body);
	my ($responcecode,$responsecontent) = SonusQA::Base::restAPI(-url => $url, 
																 -contenttype => 'JSON',
																 -token => $args{-token},
																 -method => 'PATCH',
																 -arguments => $body);
    unless ($responcecode == 200) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to Update testsuite . Message error: ".$responsecontent);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
	}
	
    $logger->error(__PACKAGE__ . " .$sub_name : Update testsuite successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}  
###
=head
    Mandatory: - baseUrl
			   - testsuiteId
			   - testsuiteName
			   - testcaseName
			   - status
			   - duration
			   - startTime
			   - endTime
			   - failReason
			   - executionLog
			   
              
    Return: 1 if pass
            0 if fail
    my %args = (-baseUrl => 'http://10.250.193.189:3000', -testsuiteId => '5e8b59c1c51c454238c9c830',
				-testsuiteName => 'TEMPLATE', -testcaseName);
    
    Ex: SonusQA::HARNESS::addTestcase(%args);
=cut

sub addTestcase {
    my ($self, %args) = @_;
    my $sub_name = 'addTestcase()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	my $flag = 1;
    foreach ('-baseUrl', '-executionLog', '-testsuiteId', '-testsuiteName', '-testcaseName') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
	
	unless (-e $args{-executionLog}) {
		$logger->error(__PACKAGE__ . ".$sub_name: Execution log file '$args{-executionLog}' is not exists! ");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	} 
	
	$logger->info(__PACKAGE__ ."======: execution log : $args{-executionLog}");
	
	
	
	my ($LOG, @lines);
	unless (open ($LOG, '<', $args{-executionLog})|| die "couldn't open the file!") {
		$logger->error( __PACKAGE__ . ".$sub_name: Open $args{-executionLog} failed " );
		$logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
		return 0;
    }
	chomp(@lines = <$LOG>);
	close $LOG;
	my (%tmp, $json);
	my $allSteps = "[";
	$logger->info(__PACKAGE__ ."======: line ".Dumper(@lines));
	for (@lines) {
		$logger->info(__PACKAGE__ ."======: $_  ");
		if (/STEP\:*(.+)-\s*(\w*)\s*$/) {
			$logger->info(__PACKAGE__ ."  =====  $1 =========== $2 ");
			%tmp = ('keyword' => 'STEP', 'arg'=>$1, 'status'=>$2);
			$json = encode_json \%tmp;
			$allSteps = $allSteps.$json.",";
		}
	
	}
	chop($allSteps);
	$allSteps = $allSteps."]";
	$logger->info(__PACKAGE__ ."=====testcase allSteps  =============:". $allSteps);
	
	my $url = $args{-baseUrl}."/TestCases";
	my ($h, $m, $s) = $args{-duration} =~ /(\d{2}):(\d{2}):(\d{2})/;
	my $duration = ($h*3600 + $m*60 + $s)*1000;
	my $body = "{\"testsuiteid\": \"$args{-testsuiteId}\",\"testcaseName\": \"$args{-testcaseName}\", \"status\": \"$args{-status}\",\"duration\": $duration,
				\"testsuiteName\": \"$self->{MODULE}\", \"startTime\": \"$args{-startTime}\", \"endTime\": \"$args{-endTime}\", \"failedReason\": \"\", \"executionLog\":$allSteps}";
	$logger->info(__PACKAGE__ ."=====testcase body  =============:". $body);
	my ($responcecode,$responsecontent) = (SonusQA::Base::restAPI(-url => $url, -contenttype => 'JSON', 
																-token => $args{-token},
																 -method => 'POST', -arguments => $body));
	unless ($responcecode == 200) {
		$logger->error(__PACKAGE__ . " .$sub_name : Failed to send REST API to add tetcase. Error : $responcecode - $responsecontent");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
	
    $logger->error(__PACKAGE__ . " .$sub_name : Add testcase $args{-testcaseName} successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}  

#############################################

sub AUTOLOAD {
    our $AUTOLOAD;
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;

    my $warn = "$AUTOLOAD ATTEMPT TO CALL $AUTOLOAD FAILED ON " . ref($self) . " OBJECT (POSSIBLY INVALID METHOD)";

    if(Log::Log4perl::initialized()){
        my $logger = Log::Log4perl->get_logger($AUTOLOAD);
        $logger->warn($warn);
    }else{
        Log::Log4perl->easy_init($DEBUG);
        WARN($warn);
    }
}

END{
    $feature{'error'} = "This automation run terminated abnormally!";
    # In the below if condition , we are looking for (S_SBC|M_SBC|T_SBC) and if found we are not raising any TOOLS bugs, Untill Transcoding issue's are fixed in DSBC: TOOLS-12468
#    unless($LogResult and ((scalar grep { $_ =~ /(S_SBC|M_SBC|T_SBC)/  } keys %main::TESTBED) != 0)){
        ($logstatus,$jiraissue) = &SonusQA::Utils::do_log_result(\%testresults,\%feature,'',$JiraBugId);
#    }
};
1;
__END__