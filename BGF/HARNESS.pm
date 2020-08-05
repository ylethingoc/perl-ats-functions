package SonusQA::BGF::HARNESS;
require Exporter;

our %TESTBED;
our $TESTSUITE;


=head1 NAME

SonusQA::BGF::HARNESS - Perl module for BGF interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $obj = SonusQA::SGX->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]',
                               -OBJ_PORT => '<port>'
                               );

   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus SBX5000-BGF.

=head2 METHODS

=cut

use Cwd;
use SonusQA::Utils qw(:all);
use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy :levels);
use SonusQA::Base;
use Data::Dumper;
use POSIX qw(strftime);
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval);


our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw( Exporter );

our @EXPORT = qw( );



# INITIALIZATION ROUTINES 
# -------------------------------

# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.

######################
sub doInitialization {
######################
    my ( $self, %args ) = @_;
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");


    $self->{TYPE}               = __PACKAGE__;
    $self->{PROMPT}             = '/.*[#>\$%] $/';
    $self->{DEFAULTTIMEOUT}         = 10;
 
}

sub new {

    my($class, %args) = @_;
   
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".new");
    my(
       $suite,
       );
    my $self = bless {}, $class; 

    if ( $args{-suite} ) {
        $self->{SUITE} = $args{-suite};
		$logger->info(__PACKAGE__ . ".new ======:   $self->{SUITE}");
    }
    if ( $args{-release} ) {
        $self->{TESTED_RELEASE} = $args{-release};
		$logger->info(__PACKAGE__ . ".new ======:   $self->{TESTED_RELEASE}");
    }
    if ( $args{-build} ) {
        $self->{BUILD_VERSION} = $args{-build};
		$logger->info(__PACKAGE__ . ".new ======:   $self->{BUILD_VERSION}}");
    }if ( $args{-path} ) {
        $self->{PATH} = $args{-path};
		$logger->info(__PACKAGE__ . ".new ======:   $self->{PATH}");
    }
    return $self;
}

sub runTestsinSuite {

    my ( $self, @tests_to_run ) = @_;
    my $suite_package = $self->{SUITE};

    my $logger          = Log::Log4perl->get_logger($suite_package);
    my $harness_logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".runTestsinSuite");

    unless ( @tests_to_run ) {
        $harness_logger->error(__PACKAGE__ . ".new ======: No Testcases specified.");
        return 0;
    }

    # Timestamp vars
    my ($build, $result, $sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst,$options);

    # If an array is passed in use that. If not run every test.
    $logger->info($suite_package . " ======: Running testcases:");

    foreach ( @tests_to_run ) {
        $logger->info($suite_package . " ======:   $_");
    }

##print "ENV: ".$ENV{ "ATS_LOG_RESULT" }."\nREL: $self->{TESTED_RELEASE}\n";
#$self->{TESTED_RELEASE} = "7.1.6";
#$self->{BUILD_VERSION} = "V07.01.06A002";

    if ( $ENV{ "ATS_LOG_RESULT" } && $self->{TESTED_RELEASE}) {

        $logger->info($suite_package . " ======: Logging TMS results against release: $self->{TESTED_RELEASE}");

        if ( $self->{BUILD_VERSION} ) {
            $build = $self->{BUILD_VERSION};
            $logger->info($suite_package . " ======: Logging TMS results against build:   $self->{BUILD_VERSION}");
        }
        else {
            $build = "Unknown";
            $logger->info($suite_package . " ======: Logging TMS results without build. Information must be added post test run");
        }
    }
    else {
        $logger->warn($suite_package . " ======: \$ENV{ATS_LOG_RESULT} or \$self->{TESTED_RELEASE} is not set.");
        $logger->warn($suite_package . " ======: Test results will not be logged in TMS");
    }

    foreach ( @tests_to_run ) {
        my $user_home;
         
        if ( $ENV{ "ATS_LOG_RESULT" } && $self->{TESTED_RELEASE} ) {

            my $testcase_id = $_;

            # Prepare test case id for TMS
            if (/^tms/) { $testcase_id =~ s/^tms// }
            $self->{$testcase_id}->{METADATA} = "";
 
            # Start timestamp
            ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
            my $start_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
         
            #
            # RUN TEST
            #
	    my $result = 0;

	    if($self->{SUBROUTINE} == 1){
	            my $test = "$self->{SUITE}::$_";
		    $result = &{$test};
	    }else{
			if ( $ENV{ HOME } ) {
   			 	$user_home = $ENV{ HOME };
			}else{
				die "ERROR:cannot get user home";
				}
			my $testscript = $_.".pl";
			my $testsuitepath = "$user_home"."\/"."$self->{PATH}";
			$logger->info("$testsuitepath");
			my $testfile = "$testsuitepath"."\/"."$testscript";
			$logger->info("$testfile");
			#chdir ("$testsuitepath");
			#unless (chdir("$testsuitepath")  == 0 ) {
   			#	 die "Could not log into $self->{PATH}";
			#}
			if ( -e $testfile ) {
    				unless ( $result = do $testfile ) {
        				die "ERROR: Couldn't parse the test script \"$_\": $@\n" if $@;
        				
    				}
			}
	    }

            # Switch value of result as log_result expects 1 for FAIL and 0 for PASS (opposite of perl)
            if ( $result == 1 ) {
                $result = 0;
                $logger->debug($suite_package . " $testcase_id: Logging result in TMS: PASS for testcase ID $testcase_id");
            }
            elsif ( $result == 0 ) {
                $result = 1;
                $logger->debug($suite_package . " $testcase_id: Logging result in TMS: FAIL for testcase ID $testcase_id");
            }
            else {
                $logger->debug($suite_package . " $testcase_id: Logging result in TMS: $result for testcase ID $testcase_id");
            }
            ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
            my $finish_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

            unless ( SonusQA::Utils::log_result (
                                            -test_result    => $result,
                                            -release        => "$self->{TESTED_RELEASE}",
                                            -metadata       => "#!ATS!$suite_package#\n $self->{$testcase_id}->{METADATA}",
                                            -testcase_id    => "$testcase_id",
                                            -starttime      => "$start_time",
                                            -endtime        => "$finish_time",
                                            -build          => "$build",
                                       ) ) {
                $logger->error($suite_package . " $testcase_id: ERROR: Logging of test result to TMS has FAILED");
            }
        }
        else {
		    if($self->{SUBROUTINE} == 1){
		            my $test = "$self->{SUITE}::$_";
			    	&{$test};
		    }else{
					my $testscript = $_.".pl";
					$logger->info($suite_package . "$testscript");
					if ( -e $testscript ) {
    					unless ( $result = do $testscript ) {
    	    				die "ERROR: Couldn't parse the test script \"$_\": $@\n" if $@;
        				}
					}
		    }
        }
    }
    $logger->info($suite_package . " ======: -------------------------------------------------");
    $logger->info($suite_package . " ======: Test execution for $suite_package COMPLETE.");
    $logger->info($suite_package . " ======: Thank Automation team");
    return 1;
}

1;
