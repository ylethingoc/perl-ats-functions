package SonusQA::SGX4000::HARNESS;
require Exporter;

our ( %TESTBED, $TESTSUITE, $log_dir );

=head1 NAME

SonusQA::SGX4000::HARNESS - Perl module for SGX4000 interaction

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

   This module provides an interface for Sonus SGX4000.

=head2 METHODS

=cut

use SonusQA::Utils qw(:all);
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
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".doInitialization" );

#   $self->{COMMTYPES}          = ["SSH"];
    $self->{TYPE} = __PACKAGE__;

#   $self->{CLITYPE}            = "sgx4000";    # Is there a real use for this?
#   $self->{conn}               = undef;
    $self->{PROMPT} = '/.*[#>\$%] $/';

#   $self->{REVERSE_STACK}      = 1;
#   $self->{LOCATION}           = locate __PACKAGE__;

#   my ( $name, $path, $suffix )    = fileparse($self->{LOCATION},"\.pm");

#   $self->{DIRECTORY_LOCATION}     = $path;
#   $self->{IGNOREXML}              = 1;
#   $self->{SESSIONLOG}             = 0;
    $self->{DEFAULTTIMEOUT} = 10;

    foreach ( keys %args ) {

        # Checks for -obj_hostname being set
        #
        if (/^-?obj_hostname$/i) {
            $self->{OBJ_HOSTNAME} = $args{$_};
        }

        # Checks for -obj_port being set
        #
        if (/^-?obj_port$/i) {

            # Attempting to set ENTEREDCLI
            # based on PORT number
            #
            $self->{OBJ_PORT} = $args{$_};

            if ( $self->{OBJ_PORT} == 2024 ) {    # In Linux shell
                $self->{ENTEREDCLI} = 0;
            }
            elsif ( $self->{OBJ_PORT} == 22 ) {    # Explicitly specified default ssh port
                $self->{ENTEREDCLI} = 1;
            }
            else {                                 # Other port. Not the CLI. Maybe an error.
                $self->{ENTEREDCLI} = 0;
            }
            last;                                  # Don't forget to stop the search!
        }
    }
    if ( !$self->{OBJ_PORT} ) {                    # No PORT set, default port is CLI
        $self->{ENTEREDCLI} = 1;
    }
}

sub new {

    my ( $class, %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ( $suite, );
    my $self = bless {}, $class;

    if ( $args{-suite} ) {
        $self->{SUITE} = $args{-suite};
    }
    if ( $args{-release} ) {
        $self->{TESTED_RELEASE} = $args{-release};
    }
    if ( $args{-build} ) {
        $self->{BUILD_VERSION} = $args{-build};
    }
    if ( $args{-variant} ) {
        $self->{VARIANT} = $args{-variant};
    }
    if ( $args{-logDir} ) {
        $self->{LOGDIR} = $args{-logDir};
    }    
    return $self;
}

sub runCliTests {

    my ( $self, @tests_to_run ) = @_;

    my $suite_package = $self->{SUITE};

    my $logger         = Log::Log4perl->get_logger($suite_package);
    my $harness_logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    unless (@tests_to_run) {
        $harness_logger->error( __PACKAGE__ . " ======: No Testcases specified." );
        return 0;
    }
  
    # Timestamp vars
    my ( $build, $result, $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $options );

    # If an array is passed in use that. If not run every test.
    $logger->info( $suite_package . " ======: Running testcases:" );

    foreach (@tests_to_run) {
        $logger->info( $suite_package . " ======:   $_" );
    }

    if ( $ENV{"ATS_LOG_RESULT"} && $self->{TESTED_RELEASE} ) {

        $logger->info( $suite_package . " ======: Logging TMS results against release: $self->{TESTED_RELEASE}" );

        if ( $self->{BUILD_VERSION} ) {
            $build = $self->{BUILD_VERSION};
            $logger->info( $suite_package . " ======: Logging TMS results against build:   $self->{BUILD_VERSION}" );
        }
        else {
            $build = "Unknown";
            $logger->info( $suite_package . " ======: Logging TMS results without build. Information must be added post test run" );
        }
    }
    else {
        $logger->warn( $suite_package . " ======: \$ENV{ATS_LOG_RESULT} or \$self->{TESTED_RELEASE} is not set." );
        $logger->warn( $suite_package . " ======: Test results will not be logged in TMS" );
    }

    # Start of suite execution
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $test_start_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $timeOfDay = [gettimeofday];
    
    # Create Results File
    $self->printResultFile(-firstTestCase => 1);

    # Loop executing each test
    foreach (@tests_to_run) {

        my $testcase_id = $_;
        my $tested_variant = "";
        my $errorMsg = "None";

        # Prepare test case id for TMS
        if (/^tms/) { $testcase_id =~ s/^tms// }
        $self->{$testcase_id}->{METADATA} = "";

        # Start timestamp
        ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
        my $start_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;

        #
        # RUN TEST
        #
        my $test    = "$self->{SUITE}::$_";
        my $ret_val = &{$test};
        my $result;

        if ( ref($ret_val) eq 'HASH' ) {
            $tested_variant = $ret_val->{VARIANT};
            $result         = $ret_val->{result};
        }
        else {
            $result = $ret_val;
            if ( defined $self->{VARIANT} ) {
                $tested_variant = $self->{VARIANT};
            }
        }

        # The Extra platform variant is appended to whatever the variant that is being set by the Harness or the testcase. This is to differntiate the testcase runs on various platforms, in the reporting
        $logger->info(" The Platform Variant is " . $main::TESTSUITE->{PLATFORMVARIANT});
        if ( defined $main::TESTSUITE->{PLATFORMVARIANT} ) {
             $tested_variant .= $main::TESTSUITE->{PLATFORMVARIANT};
        }
       
        # Finish Time
        ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
        my $finish_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
        
        # Print Result to File
        $self->printResultFile( -testId       => $testcase_id,
                                -variant      => $tested_variant,
                                -testStatus   => $result,
                                -startTime    => $start_time,
                                -endTime      => $finish_time,
                                -errorMsg     => $errorMsg );
                         
        # Switch value of result as log_result expects 1 for FAIL and 0 for PASS (opposite of perl)
        if ( $result == 1 ) {
            $result = 0;
            $logger->debug( $suite_package . " $testcase_id: Test result: PASS for testcase ID $testcase_id" );
        }
        elsif ( $result == 0 ) {
            $result = 1;
            $logger->debug( $suite_package . " $testcase_id: Test result: FAIL for testcase ID $testcase_id" );
        }
        else {
            $logger->debug( $suite_package . " $testcase_id: Test result: $result for testcase ID $testcase_id" );
        }
        $logger->debug( $suite_package . " $testcase_id: -------------------------------------------------" );

        # Log Results to TMS                   
        if ( $ENV{"ATS_LOG_RESULT"} && $self->{TESTED_RELEASE} ) {

            $logger->debug( $suite_package . " $testcase_id: Logging result in TMS" );

            if ( defined $tested_variant ) {
                unless (
                         SonusQA::Utils::log_result(
                                                     -test_result => $result,
                                                     -release     => "$self->{TESTED_RELEASE}",
                                                     -metadata    => "#!ATS!$suite_package#\n $self->{$testcase_id}->{METADATA}",
                                                     -testcase_id => "$testcase_id",
                                                     -starttime   => "$start_time",
                                                     -endtime     => "$finish_time",
                                                     -build       => "$build",
                                                     -variant     => "$tested_variant",
                         )
                  )
                {
                    $logger->error( $suite_package . " $testcase_id: ERROR: Logging of test result to TMS has FAILED" );
                }
            }
            else {
                unless (
                         SonusQA::Utils::log_result(
                                                     -test_result => $result,
                                                     -release     => "$self->{TESTED_RELEASE}",
                                                     -metadata    => "#!ATS!$suite_package#\n $self->{$testcase_id}->{METADATA}",
                                                     -testcase_id => "$testcase_id",
                                                     -starttime   => "$start_time",
                                                     -endtime     => "$finish_time",
                                                     -build       => "$build",
                         )
                  )
                {
                    $logger->error( $suite_package . " $testcase_id: ERROR: Logging of test result to TMS has FAILED" );
                }
            }
        }        
    }

    my $test_finish_time = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $file_timestamp  = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    my $test_exec_time = int tv_interval($timeOfDay);
    $self->printResultFile(-lastTestCase => 1, -endTime => $file_timestamp );
    
    my $extraInfo = " SOFTWARE RELEASE : $self->{TESTED_RELEASE} \n SOFTWARE BUILD   : $self->{BUILD_VERSION} \n";
    
    &SonusQA::Utils::mail( 'Result.csv', $suite_package, $test_start_time, $test_finish_time, $test_exec_time, $extraInfo );    

    $logger->info( $suite_package . " ======: -------------------------------------------------" );
    $logger->info( $suite_package . " ======: Test execution for $suite_package COMPLETE." );
    $logger->info( $suite_package . " ======: Thank you for travelling with AirATS." );
    return 1;
}

=head2 setSystem()

    This function sets the system information. The following variables are set if successful:

                $self->{CE_NAME_LONG}         = long CE name, ie. the domain name of the CE
                $self->{HARDWARE_TYPE}        = hardware_type, the physical box
                $self->{SERIAL_NUMBER}        = serial number
                $self->{PART_NUMBER}          = part number
                $self->{MANUFACTURE_DATE}     = manufacture date
                $self->{PLATFORM_VERSION}     = platform version
                $self->{APPLICATION_VERSION}  = application version
                $self->{MGMT_RED_ROLE}        = platform management redundancy role, ie. active or standby

=cut

sub newFromAlias {

    my (%args)     = @_;
    my $tms_alias  = $args{-tms_alias};
    my $root_login = $args{-root};
    my $return_on_fail;
    my $sessionlog;

    my $ats_obj_ref;

    if ( defined( $args{-return_on_fail} ) && $args{-return_on_fail} == 1 ) {
        $return_on_fail = 1;
    }
    else {
        $return_on_fail = 0;
    }

    if ( defined( $args{-sessionlog} ) && $args{-sessionlog} == 1 ) {
        $sessionlog = 1;
    }
    else {
        $sessionlog = 0;
    }

    my $sub_name = "newFromAlias()";
    my $logger   = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );

    unless ( defined($tms_alias) && ( $tms_alias !~ m/^\s*$/ ) ) {
        $logger->error( __PACKAGE__ . ".$sub_name: \$tms_alias undefined or is blank" );
        $logger->debug( __PACKAGE__ . ".$sub_name: Leaving $sub_name" );
        exit;
    }

    $ats_obj_ref = SonusQA::ATSHELPER::newFromAlias(
                                                     -tms_alias      => $tms_alias,
                                                     -obj_type       => "SGX4000",
                                                     -return_on_fail => $return_on_fail,
                                                     -sessionlog     => $sessionlog,
    );

    return $ats_obj_ref;
}

=head2 C< printResultFile >

DESCRIPTION:

    This subroutine saves the test result to a file

=over 

=item ARGUMENTS:

   NONE

=item PACKAGE:

    SonusQA::SGX4000::HARNESS

=item GLOBAL VARIABLES USED:
 
    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    $self->printResultFile( -testId       => $testcase_id,
                            -variant      => $tested_variant,
                            -testStatus   => $result,
                            -startTime    => $start_time,
                            -endTime      => $finish_time,
                            -errorMsg     => $errorMsg );

=back 

=cut

sub printResultFile {
   my ( $self, %args ) = @_;
   my %a = (-lastTestCase     => 0,
            -firstTestCase    => 0,
            -errorMsg         => "None");
   my $sub = "printResultFile()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   
   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
   
   my $file = "Result.csv";

   if($a{-firstTestCase} eq 1) {
      $logger->info( __PACKAGE__ . ".$sub:  outputFile $file" );
      
      # Create new file
      open (OUTFILE, ">", $file)  or die ("Can't open the file : $!\n");
      print OUTFILE "TestID,Variant,Status,StartTime,EndTime,FailureReason\n";
      $completeTestInfo{-totalTestCases} = 0;
      $completeTestInfo{-totalPassedTests} = 0;
      $completeTestInfo{-totalFailedTests} = 0;

      close(OUTFILE);
      return 1;
   }

   # Open file in append mode
   open (OUTFILE, ">>", $file)
         or die ("Can't open the file : $!\n");
         
   if($a{-lastTestCase} eq 1) {
      print OUTFILE "\nTotal Test Cases => $completeTestInfo{-totalTestCases}, Passed => $completeTestInfo{-totalPassedTests}, Failed => $completeTestInfo{-totalFailedTests}\n";
      close(OUTFILE);
      
      # Consider saving to log_dir location, with unique package filename      
      my $dest_file = $self->{LOGDIR} . "/ATS_Result-" . $a{-endTime} . ".csv";
      $logger->info( __PACKAGE__  . ".$sub:  $dest_file" );    
      
      if ( defined($self->{LOGDIR}) ) {  
          if ( system "/bin/cp", "-f", "$file",  "$dest_file") {
              $logger->error(__PACKAGE__ . ".$sub Failed to copy file '$file' to '$dest_file'");
          }
      }
      return 1;
   }

   my $testStatus;

   if($a{-testStatus} eq 1) {
      $testStatus = "PASSED";
      $completeTestInfo{-totalPassedTests}++;
   } else {
      $testStatus = "FAILED";
      $completeTestInfo{-totalFailedTests}++;
   }

   $completeTestInfo{-totalTestCases}++;

   print OUTFILE "$a{-testId},$a{-variant},$testStatus,$a{-startTime},$a{-endTime},$a{-errorMsg} \n";

   close(OUTFILE);
   
   return 1;
}
1;
