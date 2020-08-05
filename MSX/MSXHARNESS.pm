package SonusQA::MSX::MSXHARNESS;
require Exporter;

our %TESTBED;
our %TESTSUITE;


=head1 NAME

SonusQA::MSX::MSXHARNESS - Perl module for MSX interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $obj = SonusQA::MSX::MSXHARNESS->new(
                                   -suite   => __PACKAGE__,
                                   -release => "$TESTSUITE->{TESTED_RELEASE}",
                                   -build   => "$TESTSUITE->{BUILD_VERSION}",
                               );

   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus MSX.

=head2 METHODS

=cut

#########################################################################################################

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

#################################################
sub doInitialization {
#################################################
    my ( $self, %args ) = @_;
    my $subName = "doInitialization()" ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");


    $self->{TYPE}           = __PACKAGE__;
    $self->{PROMPT}         = '/\[.*\]\[.*\]\$.*$/';
    $self->{DEFAULTTIMEOUT} = 10;
 
    $logger->debug(__PACKAGE__ . ".$subName: Initialization Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
}
#########################################################################################################

#################################################
sub new {
#################################################

    my($class, %args) = @_;
    my $subName = "new()" ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    my(
       $suite,
       );
    my $self = bless {}, $class; 

    if ( $args{-suite} ) {
        $self->{SUITE} = $args{-suite};
        $logger->info(__PACKAGE__ . " ====== SUITE:  $self->{SUITE}");
    }

    if ( $args{-release} ) {
        $self->{TESTED_RELEASE} = $args{-release};
        $logger->info(__PACKAGE__ . " ====== TESTED RELEASE: $self->{TESTED_RELEASE}");
    }

    if ( $args{-build} ) {
        $self->{BUILD_VERSION} = $args{-build};
        $logger->info(__PACKAGE__ . " ====== BUILD VERSION:  $self->{BUILD_VERSION}");
    }
    
    if ( $args{-path} ) {
        $self->{PATH} = $args{-path};
        $logger->info(__PACKAGE__ . " ====== PATH OF TESTSUITES:  $self->{PATH}");
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return $self;
}
#########################################################################################################

#################################################
sub runTestsinSuite {
#################################################

    my ( $self, @tests_to_run ) = @_;

    my $suite_package = $self->{SUITE};

    my $logger          = Log::Log4perl->get_logger($suite_package);
    my $harness_logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".runTestsinSuite");

    unless ( @tests_to_run ) {
        $harness_logger->error(__PACKAGE__ . " ======: No Testcases specified.");
        return 0;
    }

    # Clear the results file
    &SonusQA::Utils::cleanresults("Results");

    # Timestamp vars
    my ($build, $result, $sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst,$options);

    # If an array is passed in use that. If not run every test.
    $logger->info($suite_package . " ======: Running testcases:");

    foreach ( @tests_to_run ) {
        $logger->info($suite_package . " ======:   $_");
    }


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

        my $TestCaseId = $_;
        my $TestedVariant;

        # Prepare test case id for TMS
        if (/^tms/) { $TestCaseId =~ s/^tms// }
        $self->{$TestCaseId}->{METADATA} = "";
 
        # Test case - START timestamp
        ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
        my $TestStartTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
         
        ###########
        # RUN TEST
        ###########
        my $test = "$self->{SUITE}::$_";
        my $ret_val = &{$test};

        # Test case - END timestamp
        ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
        my $TestFinishTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

        my $result;
        if (ref($ret_val) eq 'HASH') {
            $TestedVariant = $ret_val->{VARIANT};
            $result = $ret_val->{result};
        }
        else {
            $result = $ret_val;
            if ( defined $self->{VARIANT} ) {
                $TestedVariant = $self->{VARIANT};
            }
        }

        # Switch value of result as log_result expects
        # 1 for FAIL and
        # 0 for PASS
        # (opposite of perl)
        if ( $result == 1 ) {
            $result = 0;
            &SonusQA::Utils::result(1,$TestCaseId);
            $logger->debug($suite_package . ".$TestCaseId: PASS for testcase ID $TestCaseId");
        }
        elsif ( $result == 0 ) {
            $result = 1;
            &SonusQA::Utils::result(0,$TestCaseId); 
            $logger->debug($suite_package . ".$TestCaseId: FAIL for testcase ID $TestCaseId");
        }
        else {
            $logger->debug($suite_package . ".$TestCaseId: $result for testcase ID $TestCaseId");
        }

        if ( $ENV{ "ATS_LOG_RESULT" } && $self->{TESTED_RELEASE} ) {
            if ( $result == 0 ) {
                $logger->debug($suite_package . ".$TestCaseId: Logging result in TMS: PASS");
            }
            else {
                $logger->debug($suite_package . ".$TestCaseId: Logging result in TMS: FAIL");
            }

            if ( defined $TestedVariant ) {
                unless ( SonusQA::Utils::log_result (
                                            -test_result    => $result,
                                            -release        => "$self->{TESTED_RELEASE}",
                                            -metadata       => "#!ATS!$suite_package#\n $self->{$TestCaseId}->{METADATA}",
                                            -testcase_id    => "$TestCaseId",
                                            -starttime      => "$TestStartTime",
                                            -endtime        => "$TestFinishTime",
                                            -build          => "$build",
                                            -variant        => "$TestedVariant",
                                       ) ) {
                    $logger->error($suite_package . ".$TestCaseId: ERROR: Logging of test result to TMS has FAILED");
                }
            }
            else {
                unless ( SonusQA::Utils::log_result (
                                            -test_result    => $result,
                                            -release        => "$self->{TESTED_RELEASE}",
                                            -metadata       => "#!ATS!$suite_package#\n $self->{$TestCaseId}->{METADATA}",
                                            -testcase_id    => "$TestCaseId",
                                            -starttime      => "$TestStartTime",
                                            -endtime        => "$TestFinishTime",
                                            -build          => "$build",
                                       ) ) {
                    $logger->error($suite_package . ".$TestCaseId: ERROR: Logging of test result to TMS has FAILED");
                }
            }
        }
    } # END - foreach() loop
    $logger->info($suite_package . " ======: -------------------------------------------------");
    $logger->info($suite_package . " ======: Test execution for $suite_package COMPLETE.");
    return 1;
}

#########################################################################################################


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
