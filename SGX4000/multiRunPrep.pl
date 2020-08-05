#!/ats/bin/perl 

use ATS;
use Data::Dumper;
use File::Find qw(find);
use SonusQA::ATSHELPER;
use Getopt::Long; 

=head1 NAME

SonusQA:: class

=head1 DESCRIPTION

Provides an infrastructure to prepare the Environment before running ATS Test Suites.

=head1 AUTHORS

=head2 

DESCRIPTION:

    This subroutines prepares the testbed for a ATS run by:
       1 - Setting the Release and TMS Update Flag
       2 - Removing current cores
       3 - Removing old results_summary_file

ARGUMENTS:
    -rel           Specify a testbed_release  V07.03.06
    -tms           Specify the tms Flag 0,1
    -def           Specify a testbed definition file (full path)

PACKAGE:

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:
 
    SonusQA::SGX4000::newFromAlias

OUTPUT:

    None

EXAMPLE:

       ./SonusQA/SGX4000/multiRunPrep.pl -rel V07.03.05 -tms 0 -def testbedDefinition.pl
       
=cut

########################
# Variables
########################
my ($testbed_release, $tms_flag);

# Testbed 
#
our (
    @TESTBED,
    %TESTBED,
);

########################
# Help info
########################

my $usage_string = "    Usage: multiRunPrep -rel <Release Version> -tms <TMS Flag> [-debug]";
my $help_string = q{
    multiRunPrep - ATS automation tool
}.$usage_string. q{

    Options:
         -rel           Specify a testbed_release  V07.03.06
         -tms           Specify the tms Flag 0,1
         -def           Specify a testbed definition file (full path)

        --help          Print this summary
        --usage         Print the usage line 

};

sub usage {
    # Print this if user needs a little help...
    die "$usage_string\n\n";
}

sub help {
    # Print this if user needs a little more help...
    die "$help_string";
}

sub handleControlC {
    print "\nOh my God, you killed Kenny\n\n";
    exit;
}
$SIG{INT} = \&handleControlC;

########################
# Read CMD LINE options
########################

GetOptions (
    "rel=s"     => \$testbed_release,
    "tms=s"     => \$tms_flag,
    "def=s"     => \$testbed_definition_file,
    "usage"     => \&usage,
    "help"      => \&help,
) or help; 

# Check for def file
unless (( defined $testbed_release) && ( length($testbed_release) eq 9)) {
    # Error if not present
    print "ERROR: rel flag not present.\n";
    help;
}

# Check for tests file
unless ( defined $tms_flag)  {
    # Error if not present
    print "ERROR: tms flag not present.\n";
    help;
}
if (($tms_flag != 0) && ($tms_flag != 1)) {
    # Error if not present
    print "ERROR: tms flag not valid.\n";
    help;
}

# Check for def file
unless ( defined $testbed_definition_file ) {
    # Error if not present
    print "ERROR: def flag not present.\n";
    help;
}

#####################################################
# Ensure user has logging directory
#####################################################
my (
    $name,
    $user_home_dir,
);

# System

if ( $ENV{ HOME } ) {
    $user_home_dir = $ENV{ HOME };
}
else {
    $name = $ENV{ USER };
    if ( system( "ls /home/$name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
        $user_home_dir   = "/home/$name";
    }
    elsif ( system( "ls /export/home/$name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
        $user_home_dir   = "/export/home/$name";
    }
    else {
        print "*** Could not establish users home directory... using /tmp ***\n";
        $user_home_dir = "/tmp";
    }
} 

#
##########################################################
# Update Software Release and TMS Flag
##########################################################
my $dir     =  "$user_home_dir/ats_repos/lib/perl/QATEST/SGX4000/APPLICATION";
my $pattern = 'testsuiteList.pl';

print "\n Release:$testbed_release, TMS Flag:$tms_flag \n\n";

# Find all files recursively from the indicated directory 
find (\&changeRel,  $dir);

sub changeRel {

  # Only check matching files
  if ( $_ eq $pattern ) {
      print "$File::Find::name \n" ;

      my $data_file = $_;

      #   Open file
      open DATA, "$data_file" or die "can't open $data_file $!";
      my @array_of_data = <DATA>;

      # Check each line in the file
      foreach my $line (@array_of_data)
      {
          if ( $line =~ /ATS_LOG_RESULT/ ){
            $line = '$ENV{ "ATS_LOG_RESULT" } = ' . $tms_flag .';' . "\n";
          }
          if ( $line =~ /TESTED_RELEASE/ ) {
            $line = 'our $TESTSUITE->{TESTED_RELEASE} = "' . $testbed_release . '";   # Release info' . "\n";
          }
      }
      close (DATA);

      # Open the file for writing.
      open DATAOUT, ">$data_file" or die "can't open $data_file $!";

      # Write each line to the file
      foreach my $line (@array_of_data) {
         print DATAOUT "$line";
      }

      # Close the new file.
      close (DATAOUT)

  }
}

########################################################
# Check for files
########################################################
if ( -e $testbed_definition_file ) {
    unless ( my $return_val = do $testbed_definition_file ) {
        die "ERROR: Couldn't parse def file \"$testbed_definition_file\": $@\n" if $@;
        die "ERROR: Couldn't 'do' def file \"$testbed_definition_file\": $!\n" unless defined $return_val;
        die "ERROR: Couldn't run def file \"$testbed_definition_file\": $!\n" unless $return_val;
    }
} else {
    die "ERROR: Failed to find -def file \"$testbed_definition_file\"\n";
}

#####################################################
# Build TESTBED array
#####################################################
%TESTBED = SonusQA::ATSHELPER::resolveHashFromAliasArray( -input_array  => \@TESTBED );


#####################################################
# Remove or rename any cores on Testbed equipment
#####################################################
    # Rename Cores on SGX's
    my $sgx_object;
    if ( $TESTBED{ "sgx4000:1:obj" } = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => \@{ $TESTBED{ "sgx4000:1" }}, -debug => 1 )) {
        # Get the SGX object
        $sgx_object = $TESTBED{ "sgx4000:1:obj" };
        # check for core in SGX
        my $sgxCoreInfo = $sgx_object->checkSGXcoreOnBothCE( -sgxAliasCe0 => $TESTBED{ "sgx4000:1:ce0" },
                                                             -sgxAliasCe1 => $TESTBED{ "sgx4000:1:ce1" },
                                                             -testId      => "prep");
        $sgx_object->DESTROY;
    }                                                        
                                                        


#############################
# Remove Summary Email
#############################
my $result_file = $user_home_dir . "/ats_user/logs/Results_Summary_File";
&SonusQA::Utils::cleanresults( $result_file );


##########################################################
# Install Release Software 
##########################################################

##########################################################
# Check MGTS Slot is available
##########################################################

   my $mgts_object = SonusQA::ATSHELPER::newFromAlias(
                                                      -tms_alias      => $TESTBED{"mgts:1"}[0],
                                                      -protocol       => "ITU-M3UA",
                                                      -shelf          => $TESTBED{"mgts:1:ce0:hash"}->{SHELF}->{1}->{NAME},
                                                      -fish_hook_port => 1050 );


###########################
# Let sessions close...
sleep 1;
##print "\n\nWhen the tests are all gone, its time to move on... arrivederci.\n\n";

