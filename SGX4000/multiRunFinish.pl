#!/ats/bin/perl 

use ATS;
use Data::Dumper;
use File::Find qw(find);
use SonusQA::ATSHELPER;
use Getopt::Long; 

=head1 NAME

SonusQA:: class

=head1 DESCRIPTION

 After completing a test run tidy up the environment and send summary Test results email.
 
=head1 AUTHORS

=head2 

DESCRIPTION:

    This subroutines prepares the testbed for a ATS run by:
       1 - Check for cores
       2 - Send Summary Results Email

ARGUMENTS:
    -def           Specify a testbed definition file (full path)

PACKAGE:

    SonusQA::

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:
 
    SonusQA::ATSHELPER::resolveHashFromAliasArray
    SonusQA::SGX4000::newFromAlias
    SGX4000::SGX4000HELPER::connectAny
    SonusQA::Utils::mailResultsSummary

OUTPUT:

    None

EXAMPLE:

    ./SonusQA/SGX4000/multiRunFinish.pl -def testbedDefinition.pl

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

my $usage_string = "    Usage: multiRunFinish -def <testbedDefinition.pl> [-debug]";
my $help_string = q{
    multiRunPrep - ATS automation tool
}.$usage_string. q{

    Options:
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
    "def=s"     => \$testbed_definition_file,
    "usage"     => \&usage,
    "help"      => \&help,
) or help; 


# Check for def file
unless ( defined $testbed_definition_file ) {
    # Error if not present
    print "ERROR: def flag not present.\n";
    help;
}

########################
# Ensure user has logging directory
########################
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
# Obtain Software Build
#####################################################
my $sgx_object;
my $sgx_release;
if ( $TESTBED{ "sgx4000:1:obj" } = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => \@{ $TESTBED{ "sgx4000:1" }}, -debug => 1 )) {
    $sgx_release = $TESTBED{ "sgx4000:1:obj" }->{APPLICATION_VERSION};
}

#####################################################
# Check for cores
#####################################################

my $sgxcores = "None";


#############################
# Send Summary Email
#############################
my $log_files = $user_home_dir . "/ats_user/logs/";
&SonusQA::Utils::mailResultsSummary( -release => $sgx_release, -logdir => $log_files, -sgxcore => $sgxcores, -email => ("rwhittall@sonusnet.com","rwhittall@sonusnet.com","rwhittall@sonusnet.com") );

###########################
# Let sessions close...
sleep 1;
print "\n\nWhen the tests are all gone, its time to move on... arrivederci.\n\n";

