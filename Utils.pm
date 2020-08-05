package SonusQA::Utils;
BEGIN {
    use lib '/ats/lib/perl';
    use Sonus::Utils qw (:all);
}

=pod

=head1 Name

SonusQA::Utils

=head1 SYNOPSIS

Sonus Networks collaborative Software Quality Assurance Utilities.

=head1 DESCRIPTION

A collaborative Utitlities library, for storing and documenting callable functions used by Sonus Quality Assurance Libraries and test cases, under collaborative control and governance.

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, Data::Dumper, POSIX, DBD::mysql, File::Basename, Data::Dumper

=head1 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head1 METHODS

=cut


use Exporter;
our @ISA = qw(Exporter);

use Log::Log4perl::Layout::JSON; # For ES Logging
use Log::Log4perl qw(get_logger :easy :levels);
use DBI();
use File::Basename;
use Data::Dumper;
use Data::UUID;
use Config::IniFiles;
use Config::Simple;
use XML::Simple;
use Module::Locate qw /locate/;
use POSIX qw(strftime);
use Socket;
use Net::SCP::Expect;
use Net::Telnet;
use Net::SFTP::Foreign;
use File::Path qw(make_path remove_tree);

# This allows declaration	
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

# methods: resovle_alias, pass, fail, error, warn, blocked, db_connect logMetaData logTestInfo ptime initializeTestCase $metaInfo $testcase $metaInfo @cleanup
# are imported from Sonus::Utils and re-exported here.  This are methods that sonus-auto-core maintains.

our %EXPORT_TAGS = (
    'all' => [
        qw( resolve_alias pass fail error warn blocked db_connect logMetaData logTestInfo ptime resolve_testcase testLoggerConf initializeTestCase getTestInfo $metaInfo $testcase $metaInfo @cleanup &db_connect %vm_ctrl_obj %SSH_KEYS $LOG_DIRECTORY %GATEWAY_ID 
        stripArray stripArrayBlanks getLocalIPAddr getHostIPAddress greaterThanVersion %VLAN_TAGS)],
    'errorhandlers' => [qw( pass fail warn error )],
    'utilities'     => [qw( stripArray stripArrayBlanks getLocalIPAddr getHostIPAddress %vm_ctrl_obj %SSH_KEYS %VLAN_TAGS $LOG_DIRECTORY %GATEWAY_ID)],
);
our @EXPORT_OK = (
    @{ $EXPORT_TAGS{'all'} },
    @{ $EXPORT_TAGS{'errorhandlers'} },
    @{ $EXPORT_TAGS{'utilities'} }
);
our @EXPORT = qw(logSubInfo);
our ($testcase, $metaInfo, @cleanup, %vm_ctrl_obj, %SSH_KEYS, $LOG_DIRECTORY, %GATEWAY_ID);

$metaInfo = {};

=pod

=head2 SonusQA::Utils::stripArray(<array>)

=over

=item DESCRIPTION:

    Sub-routine to remove new line characters from array elements.  Primitive copy of array, touching each element - and remove (regex) DOS and Unix new line characters.

=item ARGUMENTS:

    - array <Array> : a flat array structure.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    ARRAY - processed and cleaned array

=item EXAMPLE(S):

    @array = &stripArray(@array);

    my @newarray = &stripArray(@array);

    @array = &SonusQA::Utils::stripArray(@array);

    my @newarray = &&SonusQA::Utils::stripArray(@array); 

=back

=cut

sub stripArray {
    my ($arr) = @_;
    my ( @clean, $modified );
    foreach $modified ( @{$arr} ) {
        $modified =~ s/[\n|\r]//g;
        push( @clean, $modified );
    }
    return @clean;
}

=pod

=head2 SonusQA::Utils::stripArrayBlanks(<array>)

=over

=item DESCRIPTION: 

    Sub-routine to remove empty array elements (elements with empty values) from the provided array.
    Primitive copy of array, touching each element - and removing (regex) all elements that only contain white spaces.

=item ARGUMENTS:

    array <Array> : a flat array structure.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    ARRAY - processed and cleaned array

=item EXAMPLE(S):

    @array = &stripArrayBlanks(@array);

    my @newarray = &stripArrayBlanks(@array);

    @array = &SonusQA::Utils::stripArrayBlanks(@array);

    my @newarray = &&SonusQA::Utils::stripArrayBlanks(@array); 

=back

=cut

sub stripArrayBlanks {
    my ($arr) = @_;
    my (@passed);
    @passed = grep /\S/, @{$arr};
    return @passed;
}

=pod

=head2 SonusQA::Utils::getLocalIPAddr(<array>)

=over

=item DESCRIPTION

    Sub-routine to remove empty array elements (elements with empty values) from the provided array.
    Primitive copy of array, touching each element - and removing (regex) all elements that only contain white spaces.

=item ARGUMENTS:

    - array <Array> : a flat array structure.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    ARRAY - processed and cleaned array

=item EXAMPLE(S):

    @array = &stripArrayBlanks(@array);

    my @newarray = &stripArrayBlanks(@array);

    @array = &SonusQA::Utils::stripArrayBlanks(@array);

    my @newarray = &&SonusQA::Utils::stripArrayBlanks(@array); 

=back

=cut

sub getLocalIPAddr {
    my ($interface) = @_;
    my ( $ipaddress, @results, $ostype, $cmd );
    $ostype    = $^O;
    $ipaddress = 0;
    unless ( defined $interface ) {
        return $ipaddress;
    }
    if ( $ostype =~ /linux/i ) {
        $cmd = "/sbin/ifconfig $interface";
    }else {
        $cmd = "/sbin/ifconfig $interface";
    }
    $cmd .= " | perl -ne '/dr:(\\S+)/||next;(/127\\.0\\.0\\.1/) || print \"\$1\"'";
    return `$cmd`;
}

=pod

=head2 SonusQA::Utils::getHostIPAddress()

=over

=item DESCRIPTION:

    Sub-routine to remove empty array elements (elements with empty values) from the provided array.
    Primitive copy of array, touching each element - and removing (regex) all elements that only contain white spaces.

=item ARGUMENTS:

    array <Array> : An flat array structure.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    ARRAY - processed and cleaned array

=item EXAMPLE(S):

    @array = &stripArrayBlanks(@array);

    my @newarray = &stripArrayBlanks(@array);

    @array = &SonusQA::Utils::stripArrayBlanks(@array);

    my @newarray = &&SonusQA::Utils::stripArrayBlanks(@array); 

=back

=cut

sub getHostIPAddress() {
    my $hostname = hostname_long;
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".getHostIPAddress" );
    $logger->info( __PACKAGE__ . "getHostIPAddress HOSTNAME RETRIEVED: $hostname");
    my($addr)=inet_ntoa((gethostbyname($hostname))[4]);
    $logger->info( __PACKAGE__ . "getHostIPAddress IP ADDRESS RETRIEVED: $addr");
    return $addr;
}

sub DUMMY_FUNC {
    my $logger = Log::Log4perl->get_logger();
    $logger->info("INFO LOGGED"); 
    $logger->debug("DEBUG LOGGED"); 
    return;
}

=head2 SonusQA::Utils::mail()

=over

=item DESCRIPTION:

    Sub-routine to mail the results after execution of automation suite

=item ARGUMENTS:

   Mandatory:
   - File
   - suite
   - start_time
   - finish_time

   Optional:
   - exec_time
   - extraInfo
   - maillist

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    0 - if file is not passed

=item EXAMPLE:

    &SonusQA::Utils::mail(Results);

=item AUTHOR: 

    ssiddegowda@sonusnet.com

=item UPDATED-BY:  

    Richard Whittall

=back

=cut

sub mail( )
{
my($File,$suite,$start_time,$finish_time,$exec_time,$extraInfo,$maillist)=@_;
my $sub = "mail";
$logger = Log::Log4perl->get_logger( __PACKAGE__ . "$sub .Send Mail" );
unless(defined $File){
    $logger->error( __PACKAGE__ . "File name undefined");
    return 0;
};
$logger->debug( __PACKAGE__ . "Sending Mail");

unless($maillist){
    my @to1 = qx#id -un#;
    chomp(@to1);
    $maillist = [$to1[0].'@rbbn.com'];#TOOLS-18700
}

my $sendmail = "/usr/sbin/sendmail -t";
my $subject = "Subject: Automation Test Results";
my $to = "To:@$maillist \n";
$logger->debug(__PACKAGE__ . "$sub .Sending mail :  $to");

open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";

open(RESULT , "$File") or return "cannot open file";
print SENDMAIL "$subject : $suite\n";
print SENDMAIL "$to\n";

print SENDMAIL " AUTOMATION RESULTS $suite\n";
print SENDMAIL " EXECUTION STARTED AT : $start_time\n";
if ( defined($extraInfo)) {
    print SENDMAIL "$extraInfo\n";
}

#Adding information about the skipped optional elements in mail
if(@{SonusQA::ATSHELPER::skipped_ces}){ #@skipped_ces is populated by SonusQA::ATSHELPER::checkRequiredConfiguration
	print SENDMAIL "\n############################################\n";
	print SENDMAIL "Following optional elements were skipped:\n";
	print SENDMAIL "\t". join(', ',@{SonusQA::ATSHELPER::skipped_ces}) ."\n";
}

print SENDMAIL "\n";
print SENDMAIL " ############################################";
print SENDMAIL "\n";
while(<RESULT>)
{
print(SENDMAIL " $_");
}
print SENDMAIL "\n";
print SENDMAIL " ############################################";
print SENDMAIL "\n\n";
print SENDMAIL " EXECUTION COMPLETED AT : $finish_time\n\n";
if ( defined ($exec_time))
{
  my @time1 = reverse((gmtime($exec_time))[0..2]);
  print SENDMAIL " EXECUTION DURATION : $time1[0] hours $time1[1] minutes $time1[2] seconds\n";
} 
close(SENDMAIL);
$logger->debug( __PACKAGE__ . "$sub .Successfully Mailed");

} #end of mail 

=pod

=head2 AUTOLOAD()

    This subroutine will be called if any undefined subroutine is called.

=cut

sub AUTOLOAD {
    our $AUTOLOAD;
    my $warn ="$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
    if ( Log::Log4perl::initialized() ) {
        my $logger = Log::Log4perl->get_logger($AUTOLOAD);
        $logger->warn($warn);
    }else {
        Log::Log4perl->easy_init($DEBUG);
        WARN($warn);
    }
}

=head2 logCheck()

=over

=item DESCRIPTION:

    logCheck method checks for a particular string's presence in a certain log file which is already generated.
    The mandatory parameters are the name of file and the string to be searched for in the log file.

=item ARGUMENTS:

 -file
    specify the file name which needs to be checked
 -string
    specify the string to search for in the file

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 n - number of occurences of the string specified.
 0-Failure when string is not found

=item EXAMPLE:

 SonusQA::Utils::logCheck(-file => "/home/ukarthik/Logs/15804_gsx_20080101_11:26:20.log",-string => "CQM");

=back

=cut

sub logCheck {
    my(%args) = @_;
    my $sub = "logCheck()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Error if file is not set
    if ($args{-file} eq undef) {
  
        $logger->error(__PACKAGE__ . ".$sub File is not specified");
        return 0;
    }

    # Error if string is not set
    if ($args{-string} eq undef) {
  
        $logger->error(__PACKAGE__ . ".$sub String is not specified");
        return 0;
    }

    # Check if string exists in the specified log file

    my $find = `grep -i \"$args{-string}\" $args{-file} | wc -l`;
    $logger->debug(__PACKAGE__ . ".$sub Number of occurences of the string $args{-string} in $args{-file} is $find");
     
    return $find;


} # End sub logCheck

=head2 read_file()

=over

=item DESCRIPTION:

    The read_file method is used to generate array of testcases to be executed from TESTSUITE DEFINITON file : actively used by NBS/GSX/PSX Automation teams
    Internally used by START automation script

=item ARGUMENTS:

    -file : specify the file name which needs to be read

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    -array of testcases

=item EXAMPLE:

    &SonusQA::Utils::read_file($filename);

=item AUTHOR:

    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub read_file
{
my ($filename) = @_; 
$sub = "read_file()";
$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

unless(defined $filename){
    $logger->error(__PACKAGE__ . ".$sub .TEST CASE DEFINITON FILE NOT SPECIFIED");
    return 0;
};	

$logger->debug(__PACKAGE__ . ".$sub .LOOKING FOR TEST CASES"); 
my @lines;

open( FILE, "< $filename" ) or die "Can't open $filename : $!";

        while( <FILE> ) {

            s/#.*//;            # ignore comments by erasing them
            next if /^(\s)*$/;  # skip blank lines

            chomp;              # remove trailing newline characters

            push @lines, $_;    # push the data line onto the array

 $logger->debug(__PACKAGE__ . ".$sub .TESTCASE : $_");
}

   close FILE;
  return @lines;  # return array of testcases 
    
}  # End sub read_file


=head2 result()

=over

=item DESCRIPTION:

    This method generates the result file to be mailed : actively used by NBS/GSX/PSX Automation teams 
    The mandatory parameters are the result code and testcase number.

    Internally used by START automation script

=item ARGUMENTS:

 -result : 0/1
 -testcase : testcase number /name  

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 Creates file(named Results) with testcases and corresponding results 

=item EXAMPLE:

    &SonusQA::Utils::result(0,TC_001)

=item AUTHOR:

    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub result {
        my ($result,$testcase, $defined_file,$testresults)=@_;
        my $testcasedata = $$testresults;
        my $sub = "result";
        $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

        if ($result eq undef) {

                $logger->error(__PACKAGE__ . ".$sub .Result is not specified");
                return 0;

        }

        if ($testcase eq undef) {

                $logger->error(__PACKAGE__ . ".$sub  .Testcase  is not specified");
                return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub  .Test result for $testcase being updated ");

        my $filename = (defined $defined_file and $defined_file) ? $defined_file : "Results";
        open (MYFILE, ">>$filename");
        if($result == 1){
                print MYFILE "\t$testcase\t\tPASS\t\t$testcasedata->{'starttime'}\t\t$testcasedata->{'finishtime'}\t\t$testresults{variant}\n";
        }else{
                print MYFILE "\t$testcase\t\tFAIL\t\t$testcasedata->{'starttime'}\t\t$testcasedata->{'finishtime'}\t\t$testresults{variant}\n";
        }
        close (MYFILE);

}  # End sub resul

=head2 cleanresults()

=over

=item DESCRIPTION:

    This method clears the result file if any in the working directory 
    Internally used by START automation script

=item ARGUMENTS:

 -filename to be deleted   

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item EXAMPLE:

    &SonusQA::Utils::cleanresults("Result")

=item AUTHOR:

    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub cleanresults {
my ($file)=@_;
my $sub = "cleanresults";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 if ($file eq undef) {
        $logger->error(__PACKAGE__ . ".$sub File  is not specified");
        return 0;
    }

if (-e "$file")
        {
        system("rm -rf $file");
        }

}  # End cleanresults

=head2 helpstring()

=over

=item DESCRIPTION:

    This method is internally used by the NBS/GSX/PSX automation START script.
    Internally used by START automation script

=item ARGUMENTS:

    filename

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    prints the statements

=item EXAMPLE:

 Internally used by STARTAUTOMATION SCRIPTS 
 &SonusQA::Utils::helpstring($filename)

=item AUTHOR:

    sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub helpstring {
my ($filename) = @_;
my $sub = "helpstring";
$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
unless(defined $filename){
$logger->error(__PACKAGE__ . ".$sub Please specify the filename ");
}

my $help_string = "
    \n\tSelection of Command Line : \n
                                            
    \tCommand :perl $filename --testbed TESTBED --config CONFIG --log DEBUG\n" 
    .q {
        Description : This command is employed when all testcases are to be given for regression run
                        TESTBED : Name of the file in which testbed information is specified
			CONFIG  : Specify the basic configurations done ,in this file 
                        log     : Log Level for PERL scripts : DEBUG/INFO/WARN/ERROR
     }                   
    . "\n\tCommand : perl $filename --testbed TESTBED --select Y --testcases TESTS --config CONFIG --log DEBUG\n"
    .q {
        Description : This command is employed when testcases across features are to be selected
                        TESTBED : Name of the file in which testbed information is specified
                        Y       : To indicate selection of testcases
                        TESTS   : Name of the file where the testcases to be executed are specified
			CONFIG  : Specify the configurations done, in this file 
                        log     : Log Level for PERL scripts : DEBUG/INFO/WARN/ERROR
                        
        Command :perl STARTV0800 --GUI 
    
        Description : This command is executed when the user wants a perl UI to take user inputs 

};

print "$help_string";    
    
} # End of helpstring 

=head2 listTokens()

=over

=item DESCRIPTION:

    listTokens parse an input file, given in the form of a reference to an array which is assumed to be the lines from the config file.
    Token format as follows : @@@ followed by an uppercase alpha-numeric string (i.e. [A-Z,0-9]+) followed by a closing @@@
    The mandatory parameter is the name of file, in the form of reference to an array - \@infile.
    output list of tokens is passed to validateTokens().

=item ARGUMENTS:

 -file array reference
    specify the file name which needs to parsed

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 - array of the unique tokens found in the input file array

=item EXAMPLE:

    my @tokens = SonusQA::Utils::listTokens( \@template_file );

=back

=cut

sub listTokens {
    my ($infile_aref) = @_;
    my $sub_name = "listTokens";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ( defined $infile_aref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file array reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my %tokenlist;
    my @tokens;
    foreach (@{$infile_aref}) {
        @tokens = split /(\@\@\@)/, $_;
        my $isatoken = -1;
        foreach (@tokens) {
            if (/^\@\@\@$/) {
                $isatoken *= -1;
            } elsif ($isatoken eq 1) {
                $tokenlist{$_} = 1;
            }
        }
    }
    @tokens = sort keys %tokenlist;
    if ($#tokens eq -1) {
        $logger->warn(__PACKAGE__ . ".$sub_name: No tokens found in input template - please make your checks");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        @tokens = ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Returning with " . scalar(@tokens) ." tokens");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [@tokens]");
    return @tokens;
}

=head2 validateTokens()

=over

=item DESCRIPTION:

    Given a list of tokens (passed as an array reference) along with a 'replacement map',
    which should map generic tokens to their specific values, given in the form of a hashref
    Ensure that:
        each token contains only alphanumeric characters.
        each token in the input array exists in the replacement map.
    the missing tokens are logged.

=item ARGUMENTS:

 -token list (array reference)
    list of tokens i.e. return value of listTokens()
 -replacement map (hash reference)
    map generic tokens to their specific values

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 -1 - Failure of input arguments
 0  - Success
 n  - number of missing/erroneous tokens on failure

=item EXAMPLE:

     unless (SonusQA::Utils::validateTokens(\@tokens, \%replacement_map) == 0) {
        $logger->error(__PACKAGE__ . ".$sub_name:  validateTokens failed.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

=back

=cut

sub validateTokens {
    my($toklist_aref, $rmap_href) = @_;
    my $sub_name = "validateTokens";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ( defined $toklist_aref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory token list array reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    unless ( defined $rmap_href ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory replacement map hash reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    my $missing = 0;
	
    foreach (@{$toklist_aref}) {
        if (m/[^A-Z0-9]/) {
            $logger->warn(__PACKAGE__ . ".$sub_name: Token $_ is badly formatted - permitted characters are A-Z and 0-9 only.");
            $missing++;
        } else {
            unless (defined $rmap_href->{$_}) {
                $logger->warn(__PACKAGE__ . ".$sub_name: Token $_ exists in input file - but undefined in replacement hash.");
                $missing++;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Returning with $missing out of " . scalar @{$toklist_aref} . " missing/badly-formatted tokens");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$missing]");
    return $missing;
}

=head2 replaceTokens()

=over

=item DESCRIPTION:

    Iterate through an array of strings (i.e. our input config file),
    replace all occurrences of the tokens with the values in the supplied hash (%replacement_map)
    Token format as follows : @@@ followed by an uppercase alpha-numeric string (i.e. [A-Z,0-9]+) followed by a closing @@@
    Return the processed file in the form of an array for either writing to disk - or execution with execCmd() and friends.

=item ARGUMENTS:

 - input file (hash reference)
      specify the file name which needs to be checked
 - replacement map (hash reference)
      specify the string to search for in the file

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 - processed file in the form of an array

=item EXAMPLE:

 my @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);

=back

=cut

sub replaceTokens {
    my ($infile_aref,$replacementmap_href) = @_;
    my $sub_name = "replaceTokens";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ( defined $infile_aref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file array reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $replacementmap_href ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory replacement map hash reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my (@outfile, @tokens);
    foreach (@{$infile_aref}) {
        #$logger->debug(__PACKAGE__ . ".$sub_name:  Input Line: $_");
        @tokens = split /(\@\@\@)/, $_;
        my $isatoken = -1;
        my $output_line;
        TOKEN: foreach (@tokens) {
            if (/^\@\@\@$/) {
                $isatoken *= -1;
                next TOKEN;
            } elsif ($isatoken eq 1) {
                if (m/[A-Z,0-9]+/) { 
                # For our own sanity - let's require tokens to be
                # upper-case alpha-numerics only - limiting the
                # formatting means less chance of false-positives.
                    if (defined  $replacementmap_href->{$_}) {
                        $output_line .= $replacementmap_href->{$_};
                        next TOKEN;
                    } 
                }
                # User should have called validateTokens to check the input data 
                # - if we get here either they forgot 
                # - or something bad happened - so die and tell them.
                $logger->logdie(__PACKAGE__ . ".$sub_name: Unknown or badly formatted token to replace '$_' - Hint - you should use validateTokens() before calling replaceTokens()");
            } else {
                $output_line .= $_;
            }
        }
        push @outfile,$output_line;
        #$logger->debug(__PACKAGE__ . ".$sub_name: Output Line: $output_line");
    }

    if ($#outfile eq -1) {
        $logger->warn(__PACKAGE__ . "$sub_name: No tokens found in input template - please make your checks");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        @tokens = [];
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Returning with $#outfile out file");
#    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [@outfile]");
    return @outfile;
}

=head2 SftpFiletoNFS()

=over

=item DESCRIPTION:

    Establish SFTP session to NFS server and put the file into NFS server.

=item ARGUMENTS:

 - NFS IP address
      specify the NFS server IP address to which file needs to be SFTPed.

 - NFS username
      specify the NFS server username.

 - NFS user password
      specify the NFS server user password.

 - NFS path
      specify the NFS server path to which file needs to be 'put'.

 - input file
      specify the file which needs to be SFTPed to NFS server

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

 - 0 on failure
 - 1 on successfull file transfer to NFS server

=item EXAMPLE:

    # Note: read the NFS server details from TMS
    unless ( SonusQA::Utils::SftpFiletoNFS(
                                            $NFS_ip,
                                            $NFS_userid,
                                            $NFS_passwd,
                                            $NFS_path,
                                            $file,
                                          ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Could not SFTP file \'$file\' to NFS server.";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Could SFTP file \'$file\' to NFS server.");

=back

=cut

sub SftpFiletoNFS {
    my ($NFS_ip, $NFS_userid, $NFS_passwd, $NFS_path, $file) = @_;
    my $sub_name = "SftpFiletoNFS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ( defined $NFS_ip ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory NFS IP address input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $NFS_userid ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory NFS username input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $NFS_passwd ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory NFS user password input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $NFS_path ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory NFS path input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $file ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory file input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    $logger->info(__PACKAGE__ . ".$sub_name:  Opening SCPE session to NFS server, ip = $NFS_ip, user = $NFS_userid ");
    
    # create connection
    eval{
        $scpe = Net::SCP::Expect->new(host=> "$NFS_ip" , user=> "$NFS_userid" , password=> "$NFS_passwd", auto_yes => "1",recursive => 1,option => 'StrictHostKeyChecking=no');
    };

    if($@) {
        $logger->error(__PACKAGE__ . ".$sub_name: connection error : $@");
	$logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
	return 0;
    }

    unless($scpe) {
        $logger->error(__PACKAGE__ . ".$sub_name: SCPE connection not successful ");
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not open \'$NFS_userid\' session object to required NFS server \($NFS_ip\)");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name:  Opened $NFS_userid SCPE session to \($NFS_ip\) NFS server");
    $logger->info(__PACKAGE__ . ".$sub_name: Transfering \'$file\' to NFS Server \'$NFS_ip\'");

    my $destfile = "$NFS_path\/$file";
    $logger->info(__PACKAGE__ . ".$sub_name: destination file : $destfile ");

    # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens
    eval{
        unless( $scpe->scp ($file, $destfile) ){
	    $logger->info(__PACKAGE__ . ".$sub_name:  SCP [$file] to NFS Server [$NFS_ip] Failed");
	    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
	    return 0;
        }
    };

    if($@) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Error in copying : $@ ");
	$logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
	return 0;
    }

    $cmd = "ls $destfile";

    #opening Telnet Session to confirm the file transfer
    unless( $telObj = new Net::Telnet (-prompt => '/.*[\$#%>] $/') ){
	$logger->debug(__PACKAGE__ . ".$sub_name:[$NFS_ip] Failed to create a session object");                                    
    }

    unless ( $telObj->open($NFS_ip) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:[$NFS_ip] Net::Telnet->open() failed");
    }

    unless ( $telObj->login(
                        Name     => $NFS_userid,
                        Password => $NFS_passwd,
                        Prompt   => '/.*[\$#%>] $/',
                        ) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:[$NFS_ip] Net::Telnet->login() failed");
    }

    sleep 2;
    my @result = $telObj->cmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub_name: cmd[$cmd] result : @result");    

    foreach (@result) {
	$logger->info(__PACKAGE__ . ".$sub_name:[$cmd] command result : $_");
        if($_ =~ /No such file or directory/i) {
            $logger->debug(__PACKAGE__ . ".$sub_name:File[$file] not transferred to NFS server[$NFS_ip]");
	    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
	    return 0;
        } elsif( $_ =~ /$destfile$/i ) {
	    $logger->info(__PACKAGE__ . ".$sub_name:  File [$file] successfully transfered to NFS server[$NFS_ip]");
	    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
	    return 1;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Unknown error");
    return 0;
}

=head2 configFailureMail()

=over

=item DESCRIPTION:

 This function informs the user by email that the test suite Configuration has failed, and no tests will be run.

=item ARGUMENTS:

 None.

=item PACKAGE:

 SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 None

=item EXAMPLE:

        SonusQA::Utils::configFailureMail(-suite   => __PACKAGE__, 
                                          -release => $TESTSUITE->{TESTED_RELEASE}, 
                                          -build   => $TESTSUITE->{BUILD_VERSION},
                                          -reason  => "Configuration failed because" ); 

=back

=cut

sub configFailureMail {
    my (%args ) = @_ ; 
    my $sub     = "configFailureMail";
    my %a = (-suite => "a", -suiteInfo => "", -release => "V01.00.00", -build => "V01.00.00R000", -reason => "REASON UNKNOWN");
    my $TotalTestCases = 1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");  
   
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Start of suite execution
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $TestSuiteEndTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

    # Determine Path
    my $location = locate($a{-suite});
    my ( $name, $path, $suffix) = fileparse( $location, "\.pm" );

    # Tests in Suite
    my $ActualTestCases;
    if (defined $a{-tests}) {
        $ActualTestCases = scalar @{$a{-tests}};
    }
           
    # Obtain email address
    my $to;
    unless(defined $main::TESTSUITE->{iSMART_EMAIL_LIST}){
         my @to1 = qx#id -un#;
         chomp(@to1);
         $to = $to1[0].'@rbbn.com';
    }else{
         $to = join(',',@{$main::TESTSUITE->{iSMART_EMAIL_LIST}});
    }
    my @maillist = ("$to");

    my $sendmail = "/usr/sbin/sendmail -t";
    $to = "To:@maillist \n";
    $logger->debug(__PACKAGE__ . ".$sub Sending the mail to :  $to");
    
    # Email Header
    open(SENDMAIL, "|$sendmail") or return "Cannot open $sendmail: $!";
    print SENDMAIL "Subject: ATS Results : $a{-suite}\n";
    print SENDMAIL "$to\n";

    # Email Contents
    print SENDMAIL " AUTOMATION RESULTS   : $a{-suite}\n";
    print SENDMAIL " TESTSUITE PATH\/FILE  : $path$name$suffix \n";    
    print SENDMAIL " TESTSUITE INFOMATION : $a{-suiteInfo}\n ";
    print SENDMAIL "\n";    
    print SENDMAIL " TESTED RELEASE       : $a{-release} \n";
    print SENDMAIL " TESTED BUILD         : $a{-build} \n";
    print SENDMAIL "\n";
    print SENDMAIL " EXECUTION STARTED AT : \n";
    print SENDMAIL " ####################################################################\n";
    print SENDMAIL " No.\tTest_ID\tResult\tExecTime\tVariant\tInfo\n";
    print SENDMAIL " ####################################################################\n";    
    print SENDMAIL "\n CONFIGURATION FAILURE: ";
    if ( defined($a{-reason})) {
        print SENDMAIL "$a{-reason}\n\n";
    }
    else { print SENDMAIL "\n"; }
    if ( defined($a{-extraInfo})) {
        print SENDMAIL "$a{-extraInfo}\n";
    }
    if ( $ActualTestCases > 0) {
        foreach ( @{$a{-tests}} ) {
            print SENDMAIL " $TotalTestCases\t" . substr($_,3) . "\n";
            $TotalTestCases++;
        }
    }
    print SENDMAIL "\n";
    print SENDMAIL " ####################################################################\n";
    print SENDMAIL " EXECUTION COMPLETED AT : $TestSuiteEndTime\n";
    print SENDMAIL "\n";    
    if ( defined ($TestSuiteExecInterval) ) {
          my @duration = reverse((gmtime($TestSuiteExecInterval))[0..2]);
          $TestSuiteExecTime = sprintf( "%02d:%02d:%02d", $duration[0], $duration[1], $duration[2] );
          print SENDMAIL " EXECUTION DURATION     : $TestSuiteExecTime\n\n";
    }  
    print SENDMAIL " ====================================================================\n";
    print SENDMAIL " Total Test Case(s) Passed    : 0\n";
    print SENDMAIL " Total Test Case(s) Failed    : 0\n";
    print SENDMAIL "\n";
    print SENDMAIL " Total Test Case(s) Executed  : 0\n";
    print SENDMAIL " Actual Test Case(s) in Suite : $ActualTestCases \n";
    print SENDMAIL " ====================================================================\n";
    print SENDMAIL " Harness Log Directory : \n";
    print SENDMAIL " Harness Result File   : \n"; 
    if ( defined $ENV{'ATS_LOG_FILE'} ) {
        print SENDMAIL " ATS Log File          : $ENV{'ATS_LOG_FILE'}\n";
    }
    if ( defined $ENV{'TEST_LOG_FILE'} ) {
        print SENDMAIL " TEST Log File         : $ENV{'TEST_LOG_FILE'}\n";
    }
    print SENDMAIL " --------------------------------------------------------------------\n";
    
    close(SENDMAIL);
    
    
    # Save failure to Results Summary File when running multiple suites
    my $result_file = $ENV{ HOME } . "/ats_user/logs/Results_Summary_File";
    unless ( open MYFILE, ">>$result_file" ) {
         $logger->error("  Cannot open output file \'$result_file\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    # Obtain last part of suite name
    my @tmpArray = split(/::/ , $a{-suite});
    @tmpArray = reverse(@tmpArray);
    
    my $resultStr =  "$tmpArray[0] \t0 \t0 \t0 \t$ActualTestCases \t$a{-reason}";
    print MYFILE "$resultStr\n";

    unless ( close MYFILE ) {
         $logger->error("  Cannot close output file \'$result_file\'- Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");         
    return;        
}

=head2 mailResultsSummary()

=over

=item DESCRIPTION:

 This function informs the user by email of the summary test results stored in the Summary_Results_File.
 Currently used by SGX4000 but can be changed without causing any problems.

=item ARGUMENTS:

  Mandatory:
    -release     Software Release
    -logDir      Directrory Location for Results_Summary_File file.

  Optional:
    -sgxcore     Was a SGX core detected

=item PACKAGE:

 SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 None

=item EXAMPLE:

        SonusQA::Utils::mailResultsSummary( -release => "V07.03.06R001", 
                                            -logdir  => '$user_home_dir . "/ats_user/logs/"',
                                            -sgxcore => "None" ); 

=back

=cut

sub mailResultsSummary {
    my (%args ) = @_ ; 
    my $sub     = "mailResultsSummary";
    my %a = (-testInfo => "", -release => "V01.00.00" );

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");  
   
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Test Results File
    my $result_file = $a{-logdir} . "Results_Summary_File";
    unless ( open RESULT, "$result_file" ) {
         $logger->error("  Cannot open file $result_file - Error: $!");
         $logger->debug(' <-- Leaving sub. [0]');
         return 0;
    }

    # Start of suite execution
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $TestSuiteEndTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

    # Determine longest suite name to calculate column padding
    my $max_length = 0;
    while(<RESULT>)
    {
        my @tmpArr = split /\t/,$_;
        if ( length($tmpArr[0]) > $max_length ) {
            $max_length = length($tmpArr[0]); 
        }
    }

    # Reset Filehandle
    seek(RESULT, 0, 0);

    ##################################
    # Obtain email address
    ##################################
    my @toID = qx#id -un#;
    chomp(@toID);
    my $defaultEmailID = "$toID[0]" . '@rbbn.com';#TOOLS-18700
    my @maillist;

    if ( defined $ENV{'ATS_EMAIL_LIST'} ) {
        @maillist = $ENV{'ATS_EMAIL_LIST'};
        push ( @maillist, $defaultEmailID );
    }
    
    if ( scalar(@maillist) eq 0 ) {
        if ( ( defined $a{'-email'} ) && ( @{ $a{'-email'} } ) ) {
            @maillist = $a{'-email'};
            push ( @maillist, $defaultEmailID );
        }
        else {
            @maillist = ($defaultEmailID);
        }
    }
    $logger->info(" TEST SUITE EMAIL LIST : @maillist ");
    
    ##################################################
    # mail the results
    ##################################################
    my $sendmail = "/usr/sbin/sendmail -t";
    my $to = "To:@maillist \n";
    $logger->debug(__PACKAGE__ . ".$sub Sending the mail to :  $to");
    
    # Email Header
    open(SENDMAIL, "|$sendmail") or return "Cannot open $sendmail: $!";
    print SENDMAIL "Subject: ATS Results : $a{-release}\n";
    print SENDMAIL "$to\n";

    # Email Contents
    print SENDMAIL " TESTED RELEASE       : $a{-release} \n";
    print SENDMAIL "\n";
    print SENDMAIL " TEST INFOMATION      : $a{-testInfo}\n";    
    print SENDMAIL " TEST RESULT FILE     : $result_file \n";
    print SENDMAIL " TEST LOG DIRECTORY   : $a{-logdir}\n";    
    print SENDMAIL "\n";       
    print SENDMAIL " EXECUTION STARTED AT : \n";
    print SENDMAIL " ####################################################################\n";
    my $line = sprintf(" Suite%*s \tPass\tFail\tExec\tTotal\tInfo", $max_length - 5);
    print SENDMAIL " $line\n";
    print SENDMAIL " ####################################################################\n";    

    my $totalPass = 0; my $totalFail = 0; my $totalExec = 0; my $totalTests = 0;
    
    while(<RESULT>)
    {     
        my @tmpArr = split /\t/,$_;
        my $line = pack("A$max_length",$tmpArr[0]) . sprintf("\t%3d\t%3d\t%3d\t%3d\t%s", $tmpArr[1], $tmpArr[2], $tmpArr[3], $tmpArr[4], $tmpArr[5]);
        print(SENDMAIL "  $line");
        
        $totalPass = $totalPass + $tmpArr[1];
        $totalFail = $totalFail + $tmpArr[2];
        $totalExec = $totalExec + $tmpArr[3];
        $totalTests= $totalTests + $tmpArr[4];
    }

    print SENDMAIL "\n";
    print SENDMAIL " ####################################################################\n";
    print SENDMAIL " EXECUTION COMPLETED AT : $TestSuiteEndTime\n";
    print SENDMAIL "\n";     
    print SENDMAIL " ====================================================================\n";
    print SENDMAIL " Total Test Case(s) Passed    : $totalPass\n";
    print SENDMAIL " Total Test Case(s) Failed    : $totalFail\n";
    print SENDMAIL "\n";
    print SENDMAIL " Total Test Case(s) Executed  : $totalExec\n";
    print SENDMAIL " Total Test Case(s)           : $totalTests \n";
    print SENDMAIL " ====================================================================\n";
    print SENDMAIL "\n"; 
    if ( defined $a{-sgxcore} ) {
        print SENDMAIL " SGX4000 Core Files           : $a{-sgxcore} \n";
    }
    print SENDMAIL "\n";          
    print SENDMAIL " --------------------------------------------------------------------\n";
    
    close(SENDMAIL);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");         
    return;        
}

=head2 mailLog()

=over

=item DESCRIPTION:

 This function is used to attach a file in the results email.

=item ARGUMENTS:

 Name of the results file, Name of the suite, Start Time, End Time, Time taken for the execution, Name of the file to be attached.

=item PACKAGE:

 SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 None

=item EXAMPLE:

        SonusQA::Utils::mailLog("Results","NBS16","Thu Oct 28 16:43:59 2010","Thu Oct 28 16:44:22 2010","22","Automation.log.zip");

=back

=cut

sub mailLog
{
my($File,$suite,$start_time,$finish_time,$exec_time,$logFile,$maillist)=@_;
my $sub = "mailLog";
my $cmd = "";
$logger = Log::Log4perl->get_logger( __PACKAGE__ . "$sub .Send Mail" );
unless(defined $File){
    $logger->error( __PACKAGE__ . "$sub Result File name undefined");
    return 0;
};

unless($maillist){
    my @to1 = qx#id -un#;
    chomp(@to1);
    $maillist = [$to1[0].'@rbbn.com'];#TOOLS-18700
}
my $sendmail = "/usr/sbin/sendmail -t";
my $subject = "Subject: Automation Test Results";

$to = "To:@$maillist \n";
$logger->debug(__PACKAGE__ . "$sub .Sending mail :  $to");
open(SENDMAIL, ">tmpFile") or die "Cannot open tmpFile: $!";
open(RESULT , "$File") or return "cannot open file";
print SENDMAIL "$subject : $suite\n";
print SENDMAIL "$to\n";

print SENDMAIL " AUTOMATION RESULTS $suite\n";
print SENDMAIL " EXECUTION STARTED AT : $start_time\n";
print SENDMAIL "\n ############################################\n";
while(<RESULT>)
{
print(SENDMAIL " $_");
}
print SENDMAIL " ############################################\n\n";
print SENDMAIL " EXECUTION COMPLETED AT : $finish_time\n\n";
if ( defined ($exec_time))
{
  my @time1 = reverse((gmtime($exec_time))[0..2]);
  print SENDMAIL " EXECUTION DURATION : $time1[0] hours $time1[1] minutes $time1[2] seconds\n";
} 
close(SENDMAIL);

$cmd = "( cat tmpFile ; uuencode $logFile $logFile ) | $sendmail";
`$cmd`;
`rm -rf tmpFile`;
$logger->debug( __PACKAGE__ . "$sub .Successfully Mailed");

}

=head2 logSubInfo()

=over

=item DESCRIPTION:

   This subroutine logs the starting of a subroutine with proper indendation

=item ARGUMENTS:

    -pkg      => Package information
    -sub      => Subroutine name
    %a        - The input arguments hash

=item PACKAGE:

 SonusQA::Utils

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 None

=item EXAMPLE:

   logSubInfo ( -pkg => __PACKAGE__,
                -sub => $sub,
                %a )

=back

=cut

sub logSubInfo {
   my %args = @_;
   my @info = %args;
   my $sub = "logSubInfo()";

   my $logger = Log::Log4perl->get_logger($args{-pkg} . "$sub");

   unless ($args{-sub}) {
      $logger->error($args{-pkg} . ".$sub Argument \"-sub\" must be specified and not be blank. $args{-sub}");
      return 0;
   }

   $logger->debug($args{-pkg} . ".$args{-sub} Entering $args{-sub} function");
   $logger->debug($args{-pkg} . ".$args{-sub} ====================");

   if ( $args{-sub} eq "cmd()" ) {
      foreach ( qw/ -cmd -timeout / ) {
         if (defined $args{$_}) {
            $logger->debug($args{-pkg} . ".$args{-sub}\t$_ => $args{$_}");
         } else {
            $logger->debug($args{-pkg} . ".$args{-sub}\t$_ => undef");
         }
      }
   } else {
      foreach ( keys %args ) {
         if (defined $args{$_}) {
            $logger->debug($args{-pkg} . ".$args{-sub}\t$_ => $args{$_}");
         } else {
            $logger->debug($args{-pkg} . ".$args{-sub}\t$_ => undef");
         }
      }
   }

   $logger->debug($args{-pkg} . ".$args{-sub} ====================");

   return 1;
}

=head2 changeLogFile()

=over

=item DESCRIPTION:

   This subroutine changes the current log file. This can be used, if a log file needs to be
   changed during the execution of a script.

=item ARGUMENTS:

   Mandatory :
   -appenderName      => Appender name. Refer NOTES section for more information
   -newLogFile        => New log file

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   None

=item EXAMPLE:

   my $newATSLog  = "$log_dir/ATS_log-$a{-testId}.$timestamp";
   SonusQA::Utils::changeLogFile(-appenderName => "AtsLog", -newLogFile => $newATSLog);

=item NOTES : 

   When the Appender class is created for logger, the following needs to be mentioned

   # Create the ATS appender and point it to a log file
   my $ats_file_appender = Log::Log4perl::Appender->new(
                                                         "Log::Log4perl::Appender::File",
                                                         filename => "$log_dir/ATS_log.$timestamp",
                                                         name => "AtsLog",
                                                       );

   The name variable passed here is used as the appender name and needs to be used to 
   access the class again in a later time. Pass this name in "-appenderName" varaible while
   callng the subroutine.

   Also, the class is changed here to Log::Log4perl::Appender::File from
   Log::Dispatch::File 

=back

=cut

sub changeLogFile {
   my (%args) = @_;
   my %a;

   my $sub    = "changeLogFile()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . " .$sub: Switching the log files to \'$a{-newLogFile}\'");

   my $atsAppender   = Log::Log4perl->appender_by_name($a{-appenderName});

   $atsAppender->file_switch($a{-newLogFile});

   $logger->info(__PACKAGE__ . " .$sub: Switched to new log file");

   return 1;
}

=head2 copyDirToRemoteMc()

=over

=item DESCRIPTION:

   This subroutine copies all the files from the specified source directory on the local machine to the specified directory on the remote machine.

=item ARGUMENTS:

   1. IP Address of the Remote Machine
   2. User Name of the Remote Machine
   3. Password of the User on the Remote Machine
   4. Name of the directory on the remote machine where the files are to be copied (If not present, this directory will be created by the subroutine)
   5. Source Directory on the local machine where the files are present

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:

   my $srcDir = "FEATURES/LEGACY/NBS16_TD/GKScripts";
   my $remoteDir = "/tmp/GKScripts";
   my $res1 = &SonusQA::Utils::copyDirToRemoteMc("10.34.9.56","root","sonus1",$remoteDir,$srcDir);
   if ($res1 == 0) {
     print "ERROR COPYING FILES on the remote machine";
   } else {
     print "Successfully copied all the files from $srcDir to the remote machine";
   }

   The above code will copy all the files under FEATURES/LEGACY/NBS16_TD/GKScripts on the local machine to the remote machine 10.34.9.56 under directory /tmp/GKScripts. If the
   directory /tmp/GKScripts is not present on 10.34.9.56, then it is created and then the files are copied.

=back

=cut  

sub copyDirToRemoteMc(){
    my ($dest_ip, $dest_userid, $dest_passwd, $dest_dir, $src_dir) = @_;
    my $sub_name = "copyDirToRemoteMc";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ($dest_ip && $dest_userid && $dest_passwd &&  $dest_dir && $src_dir) {
        $logger->error(__PACKAGE__ . ".$sub_name: Please provide all the following MANDATORY parameters");
        $logger->error(__PACKAGE__ . ".$sub_name: Destination IP","Destination User ID","Destination Password","Destination Directory","Source Directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Opening SFTP session to NFS server, ip = $dest_ip, user = $dest_userid");
    eval {
             $sftp_session = new Net::SFTP::Foreign(
                                      $dest_ip,
                                      user     => $dest_userid,
                                      password => $dest_passwd,
                                      more => [-o => 'StrictHostKeyChecking=no',-o => 'UserKnownHostsFile=/dev/null'],
                                    );
    };
    if ($sftp_session->error ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not open SFTP session to NFS server, ip = $dest_ip, user = $dest_userid error:".$sftp_session->error);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # transfer all the files from remote directory
    unless($sftp_session->rput($src_dir,$dest_dir))
    {
      $logger->error(__PACKAGE__ . ".$sub_name:  Failed to transfer file $src_dir to $dest_dir on remote machine");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  File(s) $src_dir successfully transferred to $dest_dir  on remote machine");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");

    return 1; 

}


=head2 copyDirFromRemoteMc()

=over

=item DESCRIPTION:

   This subroutine copies all the files from the specified remote directory on the remote machine to the specified directory on the remote machine.

=item ARGUMENTS:

   1. IP Address of the Remote Machine
   2. User Name of the Remote Machine
   3. Password of the User on the Remote Machine
   4. Name of the directory on the remote machine where the files are present
   5. Source Directory on the local machine where the files need to be copied

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:

   my $remoteDir = "/tmp/GKScripts";
   my $localDir = "/home/<username>/FEATURES/LEGACY/NBS16_TD/GKScripts";
   my $res1 = &SonusQA::Utils::copyDirFromRemoteMc("10.34.9.56","root","sonus1",$remoteDir,$localDir);
   if ($res1 == 0) {
     print "ERROR COPYING FILES to the local machine";
   } else {
     print "Successfully copied all the files from $remoteDir to the local machine";
   }

   The above code will copy all the files under FEATURES/LEGACY/NBS16_TD/GKScripts on the remote machine 10.34.9.56 to local machine under directory /tmp/GKScripts. If the
   directory /tmp/GKScripts is not present on the local machine the function will fail.

=back

=cut  

sub copyDirFromRemoteMc(){
    my ($remote_ip, $remote_userid, $remote_passwd, $remote_dir, $local_dir) = @_;
    my $sub_name = "copyDirFromRemoteMc";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ($remote_ip && $remote_userid &&  $remote_passwd &&  $remote_dir &&  $local_dir) {
        $logger->error(__PACKAGE__ . ".$sub_name: Please provide all the following MANDATORY parameters");
        $logger->error(__PACKAGE__ . ".$sub_name: Remote IP ","Remote User ID ","Remote Password ","Remote Directory ","Local Directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Opening SFTP session to NFS server, ip = $remote_ip, user = $remote_userid");
    eval {
             $sftp_session = new Net::SFTP::Foreign(
                                      $remote_ip,
                                      user     => $remote_userid,
                                      password => $remote_passwd,
                                      more => [-o => 'StrictHostKeyChecking=no',-o => 'UserKnownHostsFile=/dev/null'],
                                    );
    };
    if ($sftp_session->error ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not open SFTP session to NFS server, ip = $remote_ip, user = $remote_userid error:". $sftp_session->error);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # transfer all the files from remote directory
    unless($sftp_session->rget($remote_dir, "$local_dir"))
    {
      $logger->error(__PACKAGE__ . ".$sub_name:  Failed to transfer file from remote dir $remote_dir to local dir $local_dir");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  File(s) $remote_dir successfully transferred to $local_dir");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1; 

}


=head2 sftpToRemote()

=over

=item DESCRIPTION:

   This subroutine copies all the files from the specified source directory on the local machine to the specified directory on the remote machine.

=item ARGUMENTS:
 Mandatory:
   -remoteip: IP Address of the Remote Machine
   -remoteport: User Name of the Remote Machine
   -remotepasswd: Password of the User on the Remote Machine
   -remoteDir: Name of the directory on the remote machine where the files are to be copied (If not present, this directory will be created by the subroutine)
   -sourceFilePath: Source Directory on the local machine where the files are present
 Optional:
   -remotePort: Remote port number or 22 by default.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:
   my %args;
   $args{-remoteip}       = <IP>;
   $args{-remoteuser}     = <Remote User>;
   $args{-remotepasswd}   = <Remote Password>;
   $args{-sourceFilePath} = "FEATURES/LEGACY/NBS16_TD/GKScripts/*"; or $args{-sourceFilePath} = "FEATURES/LEGACY/NBS16_TD/GKScripts/<file>"; $args{-sourceFilePath} = ["/tmp/file1","/tmp/file2"];
   $args{-remoteDir}      = "/tmp/GKScripts";
   
   my $res1 = &SonusQA::Utils::sftpToRemote(%args);
   if ($res1 == 0) {
     print "ERROR COPYING FILES on the remote machine";
   } else {
     print "Successfully copied all the files from $args{-sourceFilePath} to the remote machine";
   }

   The above code will copy the file(s) under $args{-sourceFilePath} on the local machine to the remote machine <Remote IP> under directory $args{-remoteDir}. If the
   directory $args{-remoteDir} is not present on <Remote IP>, the directory is created and then the files are copied.

=back

=cut  

sub sftpToRemote(){
    my %args = @_;
    my $flag = 1;
    my $sub_name = "sftpToRemote";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{-remotePort} ||= 22;

    foreach ('-remoteip','-remoteuser','-remotepasswd','-remoteDir','-sourceFilePath')
    {
      unless($args{$_})
      {
        $logger->error(__PACKAGE__.".$sub_name: Mandatory parameter '$_' not set");
        $flag = 0;
        last;
      }
    }
    unless($flag)
    {
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Opening SFTP session to remote server, ip = $args{-remoteip}, user = $args{-remoteuser}");
    eval {
             $sftp_session = new  Net::SFTP::Foreign(
                                      $args{-remoteip},
                                      user     => $args{-remoteuser},
                                      password => $args{-remotepasswd},
                                      port => $args{-remotePort},
                                      more => [-o => 'StrictHostKeyChecking=no',-o => 'UserKnownHostsFile=/dev/null'],
                                    );
    };
    if ($sftp_session->error)
    {
            $logger->error(__PACKAGE__.".$sub_name: SFTP Failed". $sftp_session->error);
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not open $args{-remoteuser} session object to required server $args{-remoteip}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    
   $logger->debug(__PACKAGE__ . ".$sub_name:  Opened $args{-remoteuser} SFTP session to $args{-remoteip} Remote server");

    # Create the directory on the remote machine
    my $attrs = new Net::SFTP::Foreign::Attributes();
    my $chk = $sftp_session->opendir( $args{-remoteDir} );
    unless ($chk) {
      $sftp_session->mkdir("$args{-remoteDir}");
      $logger->info(__PACKAGE__ . ".$sub_name: Created directory $args{-remoteDir} on $args{-remoteip}");
    } else {
      $logger->info(__PACKAGE__ . ".$sub_name: Directory $args{-remoteDir} is present on $args{-remoteip}");
    }


    unless ( $sftp_session->mput( $args{-sourceFilePath} , "$args{-remoteDir}" ) ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  Failed to transfer file $args{-sourceFilePath} to $args{-remoteDir} on remote machine");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  File(s) $args{-sourceFilePath} successfully transferred to $args{-remoteDir} on remote machine");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1; 
}


=head2 sftpFromRemote()

=over

=item DESCRIPTION:

   This subroutine copies the file(s) from the specified remote directory on the remote machine to the specified directory on the local machine.

=item ARGUMENTS:
  Mandatory:
   -remoteip:  IP Address of the Remote Machine
   -remoteuser:  User Name of the Remote Machine
   -remotepasswd: Password of the User on the Remote Machine
   -remoteFilePath: Name of the directory on the remote machine where the files are present
   -localDir:  Source Directory on the local machine where the files need to be copied
  optional:
   -remotePort: Remote port number or 22 by default.

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   1 - Incase of success
   0 - Incase of failure

=item EXAMPLE:
   my %args;
   $args{-remoteip}       = <IP>;
   $args{-remoteuser}     = <Remote User>;
   $args{-remotepasswd} = <Remote Password>;
   $args{-remoteFilePath} = "/tmp/GKScripts/*"; or my $args{-remoteFilePath} = "/tmp/GKScripts/<file>"; or my $args{-remoteFilePath} = ["/tmp/file1","/tmp/file2"];
   $args{-localDir}       = "/home/<username>/FEATURES/LEGACY/NBS16_TD/GKScripts";
   my $res1 = &SonusQA::Utils::sftpFromRemote(%args);
   if ($res1 == 0) {
     print "ERROR COPYING FILES to the local machine";
   } else {
     print "Successfully copied all the files from $args{-remoteFilePath} to the local machine";
   }

   The above code will copy all the files under $args{-remoteFilePath} on the remote machine <IP> to local machine under directory $args{-localDir}. If the
   directory $args{-localDir} is not present on the local machine the directory is created and then the files are copied.

=back

=cut  

sub sftpFromRemote(){
    my %args = @_;
    my $flag = 1;
    my $sub_name = "sftpFromRemote";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{-remotePort} ||= 22;
    
    # Checking mandatory args;
    foreach ('-remoteip','-remoteuser','-remotepasswd','-localDir','-remoteFilePath')
    {
      unless($args{$_})
      {
        $logger->error(__PACKAGE__.".$sub_name: Mandatory parameter '$_' not set");
        $flag = 0;
        last;
      }
    }
    unless($flag)
    {
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Opening SFTP session to remote server, ip = $args{-remoteip}, user = $args{-remoteuser}");
    eval {
             $sftp_session = new Net::SFTP::Foreign(
                                      $args{-remoteip},
                                      user     => $args{-remoteuser},
                                      password => $args{-remotepasswd},
                                      port => $args{-remotePort},
                                      more => [-o => 'StrictHostKeyChecking=no', -o => 'UserKnownHostsFile=/dev/null'],
                                      );
    };
    
    if ($sftp_session->error)
    {
	    $logger->error(__PACKAGE__.".$sub_name: SFTP Failed ".$sftp_session->error);
	    $logger->error(__PACKAGE__ . ".$sub_name:  Could not open $args{-remoteuser} session object to required server $args{-remoteip}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	    return 0; 
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Opened $args{-remoteuser} SFTP session to $args{-remoteip} Remote server");

    # Find the directory of the local machine

    if(make_path($args{-localDir} , {error => \my $err} ))
    {
      $logger->debug(__PACKAGE__.".$sub_name Directory $args{-localDir} created in Local machine");
      
    }else{
      $logger->debug(__PACKAGE__.".$sub_name Local Directory $args{-localDir} present");
    }
    
    if($err)
    {
      $logger->error(__PACKAGE__.".$sub_name Unable to create directory $err");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    
    # transfer all the files from remote directory
    unless($sftp_session->mget($args{-remoteFilePath}, "$args{-localDir}"))
    {
      $logger->error(__PACKAGE__.".$sub_name: SFTP Failed Remote Directory/File not found");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  File(s) successfully transferred to $args{-localDir} from remote machine");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1; 
}


=head2 remoteToRemoteCopy()
DESCRIPTION:
    This function copies the files from remote source to remote destination.

Arguments:

    Hash with below deatils
          - Manditory
                -remoteip                 Ip Address of the remote, to which you want to connect and copy the files
                -remoteuser               UserName of the remote remote 
                -remotepasswd             Password of the remote remote
                -sourceFilePath           File path of source
                -destinationFilePath      File path of destination
                -srcip                    Source IP
                -srcuser                  Source User ID
                -srcport                  Source Port
          - Optional
                -scpPort        Port Number to which you want to connect, By default it is 22
                -timeout        Time out value, by default it is 10s
                -extension      Fetch the latest file in the directory with the extension

Return Value:

    1 - on success
    0 - on failure

Usage:
     my %rtrCopyArgs;
     $rtrCopyArgs{-remoteip}      = "$remote_ip";
     $rtrCopyArgs{-remoteuser}    = "$remoteuser";
     $rtrCopyArgs{-remotepasswd}  = "$remotepasswd";
     $rtrCopyArgs{-recvrip}       = "$obj->{OBJ_HOST}";
     $rtrCopyArgs{-recvruser}     = "$obj->{OBJ_USER}";
     $rtrCopyArgs{-recvrport}     = "$obj->{OBJ_PORT}";
     $rtrCopyArgs{-recvrpassword} = "$obj->{OBJ_PASSWORD}";
     unless(&SonusQA::Utils::remoteToRemoteCopy(%rtrCopyArgs))
     {
      $logger->error(__PACKAGE__.".$sub Error in copying file from remote server 1 to remote server 2");
     }

Values of Source asnd Destination file names, and function call varies as following:
========================================================== 
==========================================================

=cut

sub remoteToRemoteCopy{
	my %args = @_;
	my $sub = "remoteToRemoteCopy";
  my $file;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
  $logger->info(__PACKAGE__ . ".$sub Entered sub ");
	$args{-recvrport} = $args{-recvrport} || 22;
	$args{-timeout} = $args{-timeout} || 360;
	
	#Creating Remote SCP Client Object
	my $rtrScp = SonusQA::TOOLS->new(-OBJ_HOST => $args{-remoteip}, -OBJ_USER => $args{-remoteuser}, -OBJ_PASSWORD => $args{-remotepasswd}, -comm_type  => 'SSH',);
	
	#Checking if the file is present on the Remote SCP Client Object
    if($args{-extension})
    {
        $logger->debug(__PACKAGE__.".$sub Extension defined. Getting the latest file with extension $args{-extension} from the folder $args{-sourceFilePath}");
        ($file) = $rtrScp->execCmd("ls $args{-sourceFilePath} -t | grep $args{-extension}");
        if(grep /No such file or directory/, $file)
        {
            $logger->error(__PACKAGE__.".$sub: No such file or directory,");
            $logger->debug(__PACKAGE__.".$sub: Please provide correct File,Path or Version");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $args{-sourceFilePath} = $args{-sourceFilePath}."/".$file;
        $logger->debug(__PACKAGE__.".$sub The file path is $args{-sourceFilePath}");
    }
    else{
      $args{-sourceFilePath} =~/\/.+\/(\S+)/;
      $file = $1;
    }


	my @result = $rtrScp->{conn}->cmd("ls $args{-sourceFilePath}");
    if(grep /No such file or directory/, @result)
    {
      $logger->error(__PACKAGE__.".$sub: No such file or directory,");
      $logger->debug(__PACKAGE__.".$sub: Please provide correct File,Path or Version");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
      return 0;
    }
    else{
        chomp($args{-sourceFilePath});
        my $cmd = "scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P $args{-recvrport} $args{-sourceFilePath} $args{-recvruser}"."\@"."$args{-recvrip}"."\:"."$args{-destinationFilePath}";
        $logger->debug(__PACKAGE__.".$sub: SCP command is --> $cmd");
        unless($rtrScp->{conn}->print($cmd))
        {
            $logger->error(__PACKAGE__.".$sub Error in issuing SCP command");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        my ($prematch,$match);
        unless(($prematch,$match)= $rtrScp->{conn}->waitfor(-match => '/[Pp]assword:/', -errmode => "return",-timeout => 20,)){
                $logger->debug(__PACKAGE__ . ".$sub: Didn't get expected match -> $_ ,prematch ->  $prematch,  match ->$match");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
        }
        
        unless($rtrScp->{conn}->print($args{-recvrpassword}))
        {
            $logger->error(__PACKAGE__.".$sub --> Unable to provide Password to the QSBC");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        
        unless(($prematch,$match)= $rtrScp->{conn}->waitfor(-match => $rtrScp->{conn}->prompt, -timeout => $args{-timeout}))
        {
            $logger->error(__PACKAGE__.".$sub --> SCP Failed.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return $file;
    }
}


=head2 getLoggerFile()

=over

=item DESCRIPTION:

   This subroutine get the current Logger file 

=item ARGUMENTS:

   Mandatory :
   Appender name. Refer NOTES section for more information

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   current Logger file name 

=item EXAMPLE:

   SonusQA::Utils::changeLogFile(-appenderName => "AtsLog", -newLogFile => $newATSLog);

=item NOTES : 

   When the Appender class is created for logger, the following needs to be mentioned

   # Create the ATS appender and point it to a log file
   my $ats_file_appender = Log::Log4perl::Appender->new(
                                                         "Log::Log4perl::Appender::File",
                                                         filename => "$log_dir/ATS_log.$timestamp",
                                                         name => "AtsLog",
                                                       );
   In above "AtsLog" suggest the Appender name which need to passed to this method

=back

=cut

sub getLoggerFile {
   my $appenderName = shift;
   my $sub    = "getLoggerFile()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . " .$sub: Entered Sub");

   my $atsAppender   = Log::Log4perl->appender_by_name($appenderName);

   my $file = $atsAppender->{filename};

   $logger->info(__PACKAGE__ . " .$sub: current logger file is -> $file");

   return $file;
}

=head2 getPlatformInfo()

=over

=item DESCRIPTION:

   This is test method to get platform of DUT's, Executed only for bangalore ATS clients

=back

=cut

sub getPlatformInfo {
   my ($args) = shift;

   my $sub_name = "getPlatformInfo";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

   my %login = ( 'sbx5000' => { -obj_user => 'linuxadmin', -obj_password => 'sonus', -obj_port => 2024},
                 'sgx4000' => { -obj_port => 2024, -obj_password => 'sonus1'},
                 'brx'     => {-obj_password => 'sonus1'});

   my %a = ( -comm_type => 'SSH', -obj_port => 22, -defaulttimeout => 30, -obj_user => 'root', -obj_password => 'sonus' , RETURN_ON_FAIL => 1);
   my @platform;
   foreach my $key (keys %main::TESTBED) {
       next unless ($key =~ /(.+)_count/);
       my $device = $1;
       foreach my $count (1..$main::TESTBED{$key}) {
           my $temp = "$device:$count";
           $args->{dut} .= "$1-$main::TESTBED{$temp}->[0]-" . ($main::TESTBED{"$temp:ce0:hash"}->{NODE}->{1}->{IP} || $main::TESTBED{"$temp:ce0:hash"}->{MGMTNIF}->{1}->{IP}). "/";
           $device = lc $device;
           next unless ($device =~ /(psx|ems|brx|sbx|sgx|dsi|asx)/);
	    if (exists $main::TESTBED{"$temp:ce0:hash"}->{UNAME} and $main::TESTBED{"$temp:ce0:hash"}->{UNAME}) {
		#Stored the uname in TESTBED hash when the object was created
		$logger->debug(__PACKAGE__ . ".$sub_name: Getting the platform from TESTBED hash");
                @platform = @{$main::TESTBED{"$temp:ce0:hash"}->{UNAME}};
            }
       else{
            $logger->warn(__PACKAGE__ . ".$sub_name: couldn't get platform info for  ". $main::TESTBED{"$temp:ce0"});
       }
           chomp @platform;
           @platform = grep /\S/, @platform;
           next unless @platform;
           $Obj->DESTROY if ($Obj);
           $args->{platform_variant} .= "$device-$main::TESTBED{$temp}->[0]-$platform[0]/ ";
       }
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
}

=head2 greaterThanVersion()

=over

=item DESCRIPTION:

   This subroutine compares 2 software versions, and determines if the first is greater than the second.

=item ARGUMENTS:

   Mandatory :
   "V08.04.02R000"    => First software version
   "V07.03.06R010"    => Second software version

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   None

=item EXAMPLE:

   greaterThanVersion( "V08.04.02R004", $psxOBJ->{TARGETINSTANCEVERSION} );

=item NOTES : 

   None

=back

=cut

sub greaterThanVersion {
    my($first_ref, $second_ref) = @_;
    my $sub_name     = "greaterThanVersion";
    my $return_value = 1;
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    unless ( defined $first_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory first reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    unless ( defined $second_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory second reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    # Split release
        my @first = (  $first_ref  =~ /^V(\d{2})\.(\d{2})\.(\d{2})[A-Z]*(\d{3})*/ );
        my @second = ( $second_ref =~ /^V(\d{2})\.(\d{2})\.(\d{2})[A-Z]*(\d{3})*/ );
	$logger->debug(__PACKAGE__ . ".$sub_name: @first");
	$logger->debug(__PACKAGE__ . ".$sub_name: @second");

    # Loop and compare elements
    for ( $i = 0; $i < 5; $i++) {
        # Set the 
        if ( $first[$i] == $second[$i] ) {
            #$logger->debug(__PACKAGE__ . ".$sub_name: @first[$i]  @second[$i]");
        }
        elsif ( $first[$i] > $second[$i] ) {
            $return_value = 1;
            last;
        } 
        elsif ( $first[$i] < $second[$i] ) {
            $return_value = 0;
            last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$return_value]");
    return $return_value;
}

=head2 versionRange()

=over

=item DESCRIPTION:

   This subroutine compares current release is between the range of releases.
   Based on the return result user will be able to decide whether to include/exlude test cases.

=item ARGUMENTS:

   Mandatory :
   "V08.04.02R000"    => Current software version
   (['V08.04.02R004', 'V08.04.02R008'], ['V08.08.02R000', 'V08.08.02R004']);    => Software version range array

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   1    - Current version is IN the range of the version ranges provided in the array
   0    - Current version is NOT in the range of the version ranges provided in the array
   -1   - Any of the input parameters missing for the subroutine

=item EXAMPLE:

        @versionRange = (['V08.04.02R004', 'V08.04.02R008'], ['V08.08.02R000', 'V08.08.02R004']);
        my $currentVer = "V08.08.02R008";
        my $result = versionRange (\@versionRange, $currentVer);

=item NOTES :

   None

=back

=cut

sub versionRange {
        my ($versionRange, $currentVer) = @_;
        my $sub_name     = "versionRange";
        my $return_value = 0;
	my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        # Checking mandatory args;
    unless ( @$versionRange ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory first reference input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    unless ( $currentVer ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory second reference input is empty or blank.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

        # Verifying whether the current version is in the range of the user defined range.
        for (my $i = 0; $i < @$versionRange; $i++){
                if (greaterThanVersion ($currentVer, $versionRange->[$i][0]) && greaterThanVersion ($versionRange->[$i][1], $currentVer)){
                        $return_value = 1;
                        last;
                }
        }
        $logger->info(__PACKAGE__ . ".$sub_name: Returning the value $return_value.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$]");
    return $return_value;
}

=head2 getSVNinfo()

=over

=item DESCRIPTION:

    This subroutine use to get the local and server svn info. 
    It will help to know whether the user SonusQA diretory is up to date.
    Called from startAutomation and BISTQ/STARTBISTQAUTOMATION.

=item ARGUMENTS:

    None

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

    ($svn_info_loc, $svn_info) : local and sever svn info

=item EXAMPLE:

    SonusQA::Utils::getSVNinfo();

=item NOTES :

   None

=back

=cut

sub getSVNinfo{
    my $sub_name     = "getSVNinfo";
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $svn_info_loc = `svn info ~/ats_repos/lib/perl/SonusQA`;
    $logger->info(__PACKAGE__ . ".$sub_name: svn_info local: $svn_info_loc");

    my $svn_info = `svn info --username atsinfra --password sonus --no-auth-cache http://masterats.sonusnet.com/ats/lib/trunk/perl/SonusQA/`;
    $logger->info(__PACKAGE__ . ".$sub_name: svn_info server: $svn_info");

    my $svn_status = `svn status -v ~/ats_repos/lib/perl/SonusQA`;
    $logger->debug(__PACKAGE__ . ".$sub_name: svn_status: $svn_status");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
    return ($svn_info_loc, $svn_info);
}

=head2 getCoverageInfo()

=over

=item DESCRIPTION:

   This subroutine handle string for main test case to report results for the "also covers" test cases.
   It call from test case subroutine in feature pm

=item ARGUMENTS:

   Mandatory :
   %also_covers_result => 'also covers' test cases result hash

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item OUTPUT:

   coverage info string - string containing 'also covers' test case id and their result

=item EXAMPLE:

   $resultHash{$testCaseId} ->{also} = SonusQA::Utils::getCoverageInfo(map {$_ => $resultHash{$_}} (872882, 872883));

=item NOTES :

   None

=back

=cut

sub getCoverageInfo{
    my %also_covers_result = @_;

    my $sub_name     = "getCoverageInfo";
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @result_map = ('FAILED', 'PASSED', 'WARN', 'ERROR', 'BLOCKED');

    my $coverage_info;
    foreach (keys %also_covers_result){
        $also_covers_result{$_} = $result_map[$also_covers_result{$_}] if($also_covers_result{$_}=~/^\d+$/);
        $coverage_info .= " $_ $also_covers_result{$_}";
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$coverage_info]");
    return $coverage_info;
}

=head2 getSystemIPs()

=over

=item DESCRIPTION:

   This function returns primary ip , secondary IPv4 array reference and secondary IPv6 array reference, returns 0 in case of any failure.
   Note: The subroutine working is guaranteed only on systems with Ubuntu OS.

=item ARGUMENTS:

   Mandatory :
   -host   => host name or IP must be passed to get the primary and secondary IP's of that system.

   Optional :
   -user : User name, Will use the current user id if not passed in new()
   -password : password,  ssh key should be set if not passed
   -key_file : ssh key file path

=item PACKAGE:

   SonusQA::Utils

=item GLOBAL VARIABLES USED:

   None

=item EXTERNAL FUNCTIONS USED:

   SonusQA::TOOLS->new
   SonusQA::TOOLS->execCmd

=item OUTPUT:

   $primary_ip : primary ip 
   \@secondary_ip4 : reference of secondary IPv4s array
   \@secondary_ip6 : reference of secondary IPv6s array

=item EXAMPLE:

    SonusQA::Utils->getSystemIPs(-host => 'bats11', -user => 'username' , -password =>'passwd' );

=item NOTES :

   None

=back

=cut

sub getSystemIPs {
    my %args = @_ ;
    my $sub_name = "getSystemIPs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless($args{-host}) {
        $logger->info(__PACKAGE__ . ".$sub_name: Argument -host is not passed so taking the current -host");
        $args{-host} = `hostname -s`;
        chomp $args{-host};
    }

    my $toolsObj;
    unless(($toolsObj = SonusQA::TOOLS->new(-obj_host => $args{-host},
                          -obj_user => $args{-user},
                          -obj_password => $args{-password},
                          -obj_commtype => "SSH",
                          -obj_key_file => $args{-key_file},
                          ))){
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't create tools object");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @lsb_cmd_result = $toolsObj->execCmd('lsb_release -a');  
    my $os_name ;

    foreach(@lsb_cmd_result) {
        if (/Distributor\s+ID\s*\:\s+([a-zA-Z]+)/) {
            $os_name = $1;
            last;
        }
    }
  
    unless($os_name =~/Ubuntu/i) {
        $logger->info(__PACKAGE__ . ".$sub_name: $args{-host} OS is $os_name. Presently we have support only for UBUNTU server.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $primary_ip_cmd= 'grep -oE "address\s+([0-9]{1,3}\.){3}[0-9]{1,3}" /etc/network/interfaces.d/ens*.conf |awk \'{print $2}\'';
    my $secondary_ip_cmd = 'awk \'/address/\' /etc/network/interfaces | awk \'{gsub(/\/.*/,"",$2);print $2}\'';
    my ($primary_ip ,@secondry_ip,  @secondary_ip4, @secondary_ip6);

    unless (@secondry_ip = $toolsObj->execCmd($secondary_ip_cmd)) {
       $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the secondary ips\n");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }else {
       unless((($primary_ip) = $toolsObj->execCmd($primary_ip_cmd)) && ($primary_ip !~ /No such file or directory/) ) {
           $primary_ip = shift @secondry_ip;
       }
    }

    foreach (@secondry_ip ){
        if(/(\d+\.\d+\.\d+\.\d+)/) {
            push @secondary_ip4 , $_;
        }else {
            push @secondary_ip6 , $_;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
    return ($primary_ip, \@secondary_ip4,\@secondary_ip6);
}

=head1 combineEchoInXml()

=over

=item DESCRIPTION:

 This function takes a path as the input, checks for XML files in that directory with multiple echo commands in a block  and combines the commands for proper execution.
 This is used for SIPP Xml files.

=item ARGUMENTS:

 Mandatory Args:
 $path - Path of the suite

=item PACKAGES USED:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

1 - Success

=back

=cut

sub combineEchoInXml{
    my ($path, $write_to_file) = @_;
    my $sub = "combineEchoInXml";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $do_not_delete = 0;
    my $user = `whoami`;
    chomp $user;
    my @CommitFiles;
    $logger->info(__PACKAGE__ . ".$sub: Finding XML files with echo command");
    my @xmlFiles = `find $path -type f -name '*.xml' -exec grep -irl '<exec command[[:space:]]\\{0,\\}=[[:space:]]\\{0,\\}"[[:space:]]\\{0,\\}echo.*.csv' {} \\;`; #List xml files containing echo command
    unless(scalar @xmlFiles){
        $logger->error(__PACKAGE__ . ".$sub: No files to modify in $path");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
        return ();
    }
    foreach my $filename(@xmlFiles){
        chomp $filename;
        my $counter = 0;
        open(DATA, "<$filename") or die("Cant open file $filename");
        my @file = <DATA>;
        close(DATA);
        open(DATA, ">_backup.xml") or die("Cant open file _backup.xml");
        my ($line, $space);
        foreach(@file){
            chomp;
            if(($_ !~ /<!-- | -->/) && ($_ =~ /(\s*)\<exec command\s*\=\s*\"(\s*echo.*.csv\s*)\"\s*\/\>/)){                       # matching line for echo command
                $line .= $2 . ';';                                                                # Appending ';' at the end of the command
                $space = $1;                                                                      # Storing initial space
                $counter++;                                                                       # counter to determine whether or not to modify the file
                next;
            }elsif($line){
                my $cmd = '<exec command="'.$line.'sync'.'"/>';                                   # Concatenating the commands
                print DATA "$space$cmd\n";
                $counter = 0 if ($counter == 1);
                $line = '';
            }
            print DATA "$_\n";
        }
        close(DATA);
        if($counter > 1){                                                                         # File to be committed only if the counter is greater than 1 ==> file is modified
            `mv _backup.xml $filename`;
            my @diff_out = `svn diff $filename`;
            foreach(@diff_out){
		if(/^-.*<!--/ || /^-.*-->/){
                    $do_not_delete = 1;
                    $logger->error(__PACKAGE__ . ".$sub: $filename has some unwated svn diff. So not committing it. Check \'TOOLS-4544_File_with_XMLcomment.txt\' to change files manually and commit");
                    open(FILE, ">>/home/$user/TOOLS-4544_File_with_XMLcomment.txt") or die ("Cant open file");
                    print FILE "$filename\n";
                    close (FILE);
	            last;
		}
            }
	    next;                
            push(@CommitFiles, $filename);                                                        # Pushing into an array all the files to be committed
        }
    }
    `rm _backup.xml` if (-e '_backup.xml');
    unless(@CommitFiles){
        $logger->error(__PACKAGE__ . ".$sub: No files modified in $path");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
        return ();
    }
    $logger->info(__PACKAGE__ . ".$sub: ATS has modified the XML files \'@CommitFiles\' in \'$path\'.");
    if($write_to_file){                                                                           # input 1 ==> create the files and write to it, 0 ==> no file operation
        `chmod +w /home/$user/TOOLS-4544_Files_to_commit.txt`;
        `chmod +w /home/$user/TOOLS-4544_Suites_to_commit.txt`;
        open(COMMIT, ">>/home/$user/TOOLS-4544_Files_to_commit.txt") or die("Cant open file /home/$user/TOOLS-4544_Files_to_commit.txt");     # check this file for the changed files to be committed
        my $line = join("\n", @CommitFiles);
        print COMMIT "$line\n";
        close(COMMIT);
        open(SUITES, ">>/home/$user/TOOLS-4544_Suites_to_commit.txt") or die("Cant open file /home/$user/TOOLS-4544_Suites_to_commit.txt");   # check this file for the changed suites to be committed
        $path  =~ /.*\/(QATEST.*)\s*$/;
        my $suitePath = $1;
        print SUITES "$suitePath\n";
        close(SUITES);
        $logger->info(__PACKAGE__ . ".$sub: Check \'/home/$user/TOOLS-4544_Files_to_commit.txt\' for the file list and \'/home/$user/TOOLS-4544_Suites_to_commit.txt\' for the suite list");
        `chmod -w /home/$user/TOOLS-4544_Files_to_commit.txt`;
        `chmod -w /home/$user/TOOLS-4544_Suites_to_commit.txt`;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
    return ($do_not_delete, @CommitFiles);
}

=head1 initJsonLayout()

=over

=item DESCRIPTION:

 This function create Log::Log4perl::Layout::JSON object for JSON layout.
 It is using in startAutomation scripts to create json logger and which will be used for Elastic Search

=item ARGUMENTS:

 None

=item RETURNS:

 Log::Log4perl::Layout::JSON object

=back

=cut

sub initJsonLayout{
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

    my $json_layout = Log::Log4perl::Layout::JSON->new(
        include_mdc => { value => 1},
        max_json_length_kb => { value => 100},
        field => {
            message => { value => '%Z'},  # NB - Custom cspec defined above
            level => { value => '%p'},
            module => { value => '%M'},
            line => { value => '%L'},
            pid => { value => '%P'},
            category => { value => '%c'},
            file => { value => '%F'},
            genhost => { value => '%H'}, # NB - The host /generating/ this log, and the host /forwarding/ this log need not be the same.
            '@timestamp' => { value => '%d{yyyy-MM-ddTHH:mm:ss.SSS}Z'}, # NB - This *has* to be strict ISO8601 or filebeat and downstream won't parse it - dont mess with it.
        }
    );

    return $json_layout;
}

=head1 createUserLogDir()

=over

=item DESCRIPTION:

 This function create the user log directory in user home.
 Called from START(PSX|GSX|NBS)AUTOMATION 

=item ARGUMENTS:

  sub_dir : if need to create sub directory under ~/ats_user/logs/. We pass 'PSX' from STARTPSXAUTOMATION and respectively for START(GSX|NBS)AUTOMATION

=item RETURNS:

 log directory with complete path in success
 0 when failure

=back

=cut

sub createUserLogDir{
    my $sub_dir = shift;
    if ( $ENV{ HOME } ) {
        $user_home_dir = $ENV{ HOME };
    }
    else {
        $name = $ENV{ USER };
        if ( system( "ls /home/$name/ > /dev/null" ) == 0 ) {#to run silently, redirecting the output to /dev/null
            $user_home_dir   = "/home/$name";
        }
        elsif ( system( "ls /export/home/$name/ > /dev/null" ) == 0 ) {#to run silently, redirecting the output to /dev/null
            $user_home_dir   = "/export/home/$name";
        }
        else {
            print "*** Could not establish users home directory... using /tmp ***\n";
            $user_home_dir = "/tmp";
        }
    }

    my $log_dir = "$user_home_dir/ats_user/logs/$sub_dir";

    unless ( system ( "mkdir -p $log_dir" ) == 0 ) {
        print "Could not create user log directory ($log_dir)";
        return 0;
    }
    
    return $log_dir;
}
 
1;

