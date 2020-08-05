package SonusQA::GSX::UKLogParser;

=head1 NAME

 SonusQA::GSX::UKLogParser - Perl module for Sonus UK GSX specific log parsing and validation.

=head1 SYNOPSIS

 logparse.pl [options]

 Options:
    -tid <testid>
        Testid to check logs for (or 'all' for validation of DB entries) - mandatory
        
    -nfs_gsx1 <path>, -n1 <path>
        NFS path to GSX1 - eg /sonus/SonusNFS/JAY/evlog/101033300
        
    -nfs_gsx2 <path>, -n2 <path>
        NFS path to GSX2 (in GW-GW)
        
    -dir_log_path <path>, -dlp <path>
        Path to directory containing all logs to be checked.
        (mutually exclusive with --nfs* options, one or other is mandatory)


    The following are optional - but the tool will report an error if the DB
    indicates to check a log file that is not specified.
    
    -act1 <file>, -a1 <file>
        Name of accounting file for GSX1 (e.g. 100023A.ACT)
        
    -act2 <file>, -a2 <file>
        Name of accounting file for GSX2 (in GW-GW)
        
        
    -dbg1 <file>, -d1 <file>
        Name of debug file for GSX1
        
    -dbg2 <file>, -d2 <file>
        Name of debug file for GSX2 (in GW-GW)


    -sys1 <file>, -s1 <file>
        Name of system file for GSX1
        
    -sys2 <file>, -s2 <file>
        Name of system file for GSX2 (in GW-GW)
        
        
    -trc1 <file>, -t1 <file>
        Name of trace file for GSX1
        
    -trc2 <file>, -t2 <file>
        Name of trace file for GSX2 (in GW-GW)
       

    -generic <file>, -gf <file>
        Name of file containing generic parse strings
        
    -gw
        Flag to indicate GW-GW testing.
        
    -verbose
        If specifed prints the test case has passed otherwise the printing is omitted
        
    -help, -h
        This information.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, Text::CSV, DBI, Sonus::QA::Utils, Data::Dumper, POSIX

=head1 METHODS

=cut

use strict;
use SonusQA::Utils;
# All error and warning logs done via Log::Log4perl module for consistency
# with ATS
use Log::Log4perl qw(get_logger :easy :levels);

# For debugging only
use Data::Dumper;
use SonusQA::GSX::camRecordTable;


our $logger;
our $debuglevel = "INFO";

if ( Log::Log4perl::initialized() ) {
    $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".GSXParseLog" );
} else {
    Log::Log4perl->init( \&SonusQA::Utils::testLoggerConf( "UKGSXEvlogCDRChecker", $debuglevel ) );
    $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".GSXParseLog" );
}

sub error {
    if (@_) {
        my $message = join( " ", @_ );
        $logger->error( __PACKAGE__ . " $message" );
    }
    $logger->error( __PACKAGE__ . " ERROR" );
    exit 3;
}


use Getopt::Long qw(GetOptions);
use Text::CSV;
use Pod::Usage;

require Exporter;
our @ISA = qw(Exporter);
# TODO fill me with public methods.
our @EXPORT_OK = qw();

# Initialise variables
our %gsx_file; # Hash to store the various GSX Log pathnames that we may get passed.

our ($nfs_gsx1, $nfs_gsx2, $dir_log_path, $gen_file);
our ($gw, $verbose, $test_id);

our (@input_matchstrings); # Stash the input from DB and File here

our (@matchstrings_act, @matchstrings_evlog); # Processed and validated form of above (AoA)

# DB currently set to UK Test Wrtiting Automation Tool DB
# This may change in future
use constant DB_SOURCE => 'dbi:mysql:database=twat;hostname=megablast';
use constant DB_USER => "readonlyuser";
use constant DB_AUTH => "password"; 

=head1 B<parse_cmdline()> 

  Parse and validate command line arguments

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=back

=cut
 
sub parse_cmdline {
    

    GetOptions ("tid=s"             => \$test_id,
                "nfs_gsx1|n1=s"     => \$nfs_gsx1,
                "nfs_gsx2|n2=s"     => \$nfs_gsx2,
                "dir_log_path|dlp=s" => \$dir_log_path,
                "act1|a1=s"         => \$gsx_file{ACTING},
                "act2|a2=s"         => \$gsx_file{ACTEG},
                "dbg1|d1=s"         => \$gsx_file{DBGING},
                "dbg2|d2=s"         => \$gsx_file{DBGEG},
                "sys1|s1=s"         => \$gsx_file{SYSING},
                "sys2|s2=s"         => \$gsx_file{SYSEG},
                "trc1|t1=s"         => \$gsx_file{TRCING},
                "trc2|t2=s"         => \$gsx_file{TRCEG},
                "generic|gf=s"      => \$gen_file,
                "gw"                => \$gw,
                "verbose|v"         => \$verbose,
                "help|h|?"          => sub { &pod2usage(-pathlist => "/local/home/atd/ats_repos/lib/perl/SonusQA/GSX/", -input => "UKLogParser.pm", -verbose => 2, -exit => '2' ); }
          ) or pod2usage(-pathlist => "/local/home/atd/ats_repos/lib/perl/SonusQA/GSX/" , -input => "UKLogParser.pm", -verbose=> 2, -exit => '2');
}

=head1 B<validate_options()>

  Validate the combination of options passed - split from parse_cmdline so that we can validate when called as a subroutine from a test-case in ATS.

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=back

=cut


sub validate_options {

    my $sub = "validate_options()";

    my $found_error = 0;
    $logger->debug(__PACKAGE__ . ".$sub Entered function");

    # Test ID MUST be specified.
    if ((!defined $test_id) || ($test_id eq "")) {
        $logger->error(__PACKAGE__ . ".$sub Test ID not specified");
        $found_error++;
    }
    
    # dirlogpath and nfs[12] are mutually exclusive.
    if (defined $dir_log_path) {
        if (defined $nfs_gsx1 || defined $nfs_gsx2) {
            
            $logger->error(__PACKAGE__ . ".$sub The dir_log_path option cannot be used together with either the nfs_gsx1 or nfs_gsx2 options");
            $found_error++;
        }
    } elsif(!(defined $nfs_gsx1)) {
        # HEFYI - TODO - Malc check - do we really want to support not specifying anything for these 2, if so, what does it mean? (cwd?)
        $logger->error(__PACKAGE__ . ".$sub You must specify one of either dir_log_path or nfs_gsx1");
        $found_error++;
    }
     
    if (defined $gw) {
        $logger->info(__PACKAGE__ . "$sub Running in GW-GW Mode.");
        # If $gw specified, check we have $gsx_nfs2
        if ((!(defined $dir_log_path)) && (!(defined $nfs_gsx2))) {
            $logger->error(__PACKAGE__ . "$sub GW-GW Mode specified, but no GSX2 NFS Directory");
            $found_error++;
        }
    } else {
        $logger->info(__PACKAGE__ . "$sub Running in Single GSX Mode.");
        # If $gw NOT specified, check we don't have $gsx_nfs2, act2 etc.
        if ((!(defined $dir_log_path)) && (defined $nfs_gsx2)) {
            $logger->error(__PACKAGE__ . "$sub GSX2 NFS Directory specified, but running in Single GSX Mode");
            $found_error++;
        }
        if (defined $gsx_file{ACTEG}) {
            $logger->error(__PACKAGE__ . "$sub GSX2 ACT filename specified, but running in Single GSX Mode");
            $found_error++;
        }
        if (defined $gsx_file{DBGEG}) {
            $logger->error(__PACKAGE__ . ".$sub GSX2 DBG filename specified, but running in Single GSX Mode");
            $found_error++;
        }
        if (defined $gsx_file{SYSEG}) {
            $logger->error(__PACKAGE__ . ".$sub GSX2 SYS filename specified, but running in Single GSX Mode");
            $found_error++;
        }
        if (defined $gsx_file{TRCEG}) {
            $logger->error(__PACKAGE__ . ".$sub GSX2 TRC filename specified, but running in Single GSX Mode");
            $found_error++;
        }
    }
    
    if (defined $gen_file) {
        $logger->info(__PACKAGE__ . ".$sub Using $gen_file for generic checking strings.");
    } else {
        $logger->info(__PACKAGE__ . ".$sub NO generic checking strings specified.");
    }
    
    # Check for trailing slashes on directories, add them here if not specified.
    foreach my $ref (\$dir_log_path, \$nfs_gsx1, \$nfs_gsx2 ) {
        if (defined $$ref) {
            $$ref .= "/" if (!($$ref =~ /\/$/));
        }
    }
    if($found_error) {
        
        $logger->warn(__PACKAGE__ . ".$sub Found $found_error errors (see above) - giving up");
        $logger->warn(__PACKAGE__ . ".$sub Hint - trying reading the help options below");
        pod2usage(-pathlist => "/local/home/atd/ats_repos/lib/perl/SonusQA/GSX/" , -input => "UKLogParser.pm", -verbose=> 2, -exit => '1');
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Leaving function successfully (no errors found)");
    }
}    


=head1 B<expand_filenames()>

  Prepend appropriate paths to each of the specified event log files.

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=back

=cut

sub expand_filenames {
    my $sub = "expand_filenames()";
    $logger->debug(__PACKAGE__ . ".$sub Entered function");

    my (@list1, @list2);
    @list1 = (\$gsx_file{ACTING}, \$gsx_file{DBGING}, \$gsx_file{SYSING}, \$gsx_file{TRCING} );
    if (defined($gw)) {
        @list2 = (\$gsx_file{ACTEG}, \$gsx_file{DBGEG}, \$gsx_file{SYSEG}, \$gsx_file{TRCEG});
    }
    
    if (defined($dir_log_path)) {        
        foreach my $ref (@list1,@list2) {
            # prepend log_path to $$ref
            $$ref = $dir_log_path . $$ref if defined($$ref);
        }
    } else {
        foreach my $log_type_ind ("ACT", "DBG", "SYS", "TRC") {
            my $ref = \$gsx_file{"${log_type_ind}ING"};
            if (defined($$ref)) {
                # If current log file name is prefixed with log type directory
                # e.g. "ACT/" then just prefix with nfs directory name
                # otherwise prefix with nfs directory as well as log type directory
                if ($$ref =~ /^${log_type_ind}\//) {
                    $$ref = $nfs_gsx1 . $$ref;
                } else {
                    $$ref = $nfs_gsx1 . $log_type_ind . "/" . $$ref;
                }
            }
        }
        # Working on the assumption that the user didn't specify logs for gsx2
        foreach my $log_type_ind ("ACT", "DBG", "SYS", "TRC") {
            my $ref = \$gsx_file{"${log_type_ind}EG"};
            if (defined($$ref)) {
                # If current log file name is prefixed with log type directory
                # e.g. "ACT/" then just prefix with nfs directory name
                # otherwise prefix with nfs directory as well as log type directory
                if ($$ref =~ /^${log_type_ind}\//) {
                    $$ref = $nfs_gsx2 . $$ref;
                } else {
                    $$ref = $nfs_gsx2 . $log_type_ind . "/" . $$ref;
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
}

=head1 B<get_parse_strings_from_db()>

  Gets all the text stored in the "logDetails" field of the Test DB for the specified test id (defaults to all tests)
  Any line of test that is not blank or is not a commnet is added to the input_matchstrings array of the form:
                             <test id> <text line> <test author>

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs:

 $test_id, DB config constants

=item Output:

 @input_matchstrings array

=back

=cut

sub get_parse_strings_from_db {
    
    # Don't think NOT ISNULL is enough for our current DB...
    # we have some entries with empty/whitespace strings (which are not NULL.)
    my $sub = "get_parse_strings_from_db()"; 
    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    my $sql = "SELECT id,logDetails,author,lastuser FROM test WHERE NOT ISNULL(logDetails) AND test_type!='DELETED'";
    $sql .= " AND id='$test_id'" if ($test_id ne "ALL" and $test_id ne "all");
    $sql .= ";";

    $logger->debug(__PACKAGE__ . ".$sub Connecting to DB " . DB_SOURCE . " " . DB_USER . " " . DB_AUTH);
    my $dbh = DBI->connect(DB_SOURCE, DB_USER, DB_AUTH, {PrintError => 0})
        or do { $logger->error(__PACKAGE__ . ".$sub connect " . $DBI::errstr); exit 1 ; };
    $logger->debug(__PACKAGE__ . ".$sub SQL statement tot execute: \n$sql\n");
    my $sth = $dbh->prepare($sql)
        or do { $logger->error(__PACKAGE__ . ".$sub prepare " . $DBI::errstr); exit 1 ; };
    $sth->execute
        or do { $logger->error(__PACKAGE__ . ".$sub execute " . $DBI::errstr); exit 1 ; };
    $sth->bind_columns(\( my $id, my $logdetails, my $author, my $lastuser))
        or do { $logger->error(__PACKAGE__ . ".$sub bind_columns " . $DBI::errstr); exit 1 ; };
    $#input_matchstrings = -1; # Let's start with an empty list.
    
    while ($sth->fetch) {
        my $author_str = "";
        if ((!defined($lastuser)) || ($lastuser eq $author)) {
            $author_str = $author;
        } else {
            $author_str = "${author}($lastuser)";    
        }
        foreach my $elem (split /\n+/,$logdetails) {
            $elem =~ s/\r//;   # Remove DOS/Window Carriage return 
            if (($elem ne "") && (!($elem =~ /^#/))) {
                # ignore blank lines and lines begin with #, otherwise add string to array
                $logger->debug(__PACKAGE__ . ".$sub Adding \[ $id, $elem, $author_str \] match string to array");
                push @input_matchstrings, [ $id, $elem, $author_str ];
            } else {
                $logger->debug(__PACKAGE__ . ".$sub Ignoring line '$elem' for test_id:'$id'");
            }
        }
    }
   
    my $num_matchstrings = $#input_matchstrings + 1;
    $logger->debug(__PACKAGE__ . ".$sub Found " . $num_matchstrings . " matchstring(s) in DB'");
    $logger->debug(__PACKAGE__ . ".$sub Disconnecting from DB");
    $dbh->disconnect;

    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
}


=head1 B<get_generic_parse_strings()>

  This sub be responsible for deciding whether the user specified a generic file or not and acting accordingly
  Adds any specified generic parse strings to the @input_matchstrings array

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs:  

 $gen_file  (generic file name if specified)

=item Outputs: 

 @input_matchstrings

=back

=cut

sub get_generic_parse_strings {
    my $sub = "get_generic_parse_strings()"; 
    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    if(defined $gen_file) {
        open FILE,"<$gen_file"
            or do { $logger->error(__PACKAGE__ . ".$sub Cannot open Generic Strings file '$gen_file'") ; exit 1 };
        my $i=0;
        while(<FILE>) {
            chomp;
            $i++;
            $logger->debug(__PACKAGE__ . ".$sub Adding \[ GEN_$i, $_, generic\] match string to array");
            push @input_matchstrings, [ "GEN_". $i, $_ , "generic" ];
        }
        $logger->debug(__PACKAGE__ . ".$sub Leaving function after finding $i generic parse strings in file '$gen_file'");
        return $i;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub No generic strings file defined");
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function after finding no generic parse strings");
    return 0;
}

=head1 B<validate_parse_strings()>

  Takes the array of @input_matchstrings and validates against a set of pre-defined rules. Any validation errors are highlighted with a reason.
  Any valid ACT file match strings are added to the @matchstrings_act array.
  Any valid Event Log match strings are added to the @matchstrings_evlog array
  
  Format of DBG, SYS, TRC Log parse string is:
  <log_file>:<log_type>:"<regexp>"

  Format of ACT Log parse string is:
  <log_file>:<log_type>:<cdr_rec>[<rec_occurrence>]:<cdr_field>[-<cdr_sub>]:"<regexp>"
  
  Either may be preceded by an optional ! to negate the match (i.e. FAIL if the match is found)

=over 6
 
=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs: 

 @input_matchstrings array

=item Outputs: 

 @matchstrings_act
 @matchstrings_evlog
 Error strings for any invalid match strings
 Returns a count of the number of errors found.

=back

=cut

sub validate_parse_strings {
    
    my $sub = "validate_parse_strings()"; 
    $logger->debug(__PACKAGE__ . ".$sub Entering function");

    my $global_found_error = 0;      # Count of errors in entire input space
    my $found_error = 0;
    
    $#matchstrings_act = -1; 	# Let's start with an empty list.
    $#matchstrings_evlog = -1; 	# Let's start with an empty list.

    LOOP: foreach my $elem (@input_matchstrings) {
        
        $logger->debug(__PACKAGE__ . " Checking ID: $elem->[0]");

        $found_error = 0; # Count of errors in 1 string
        my ($log_type, $log_dir, $rest_of_parse_string) = split /:/, $elem->[1], 3;
        my $not_expr = 0;
        # Check to see if the split returned 3 values...
        if(!((defined $log_type) && (defined $log_dir) && (defined $rest_of_parse_string))) {
            $logger->warn(__PACKAGE__ . " ID: $elem->[0] Could not find 2 ':' delimiters in string, skipping further checks.`$elem->[1]`");
            $found_error++;
            $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
            # We also need to increment global_found_error as we are skipping
            # to the next loop iteration
            $global_found_error++;
            next LOOP;
        }
        
        if($log_type =~ /^\!/) {
            $not_expr = 1;
            $log_type =~ s/^\!//;
        }
        
        # Validate the log_type...
        SWITCH: foreach($log_type) {
            last SWITCH if /^ACT$/;
            last SWITCH if /^DBG$/;
            last SWITCH if /^SYS$/;
            last SWITCH if /^TRC$/;
            $logger->warn(__PACKAGE__ . " ID: $elem->[0] Log type '$log_type' should be ACT, DBG, SYS or TRC, skipping further checks");
            $found_error++;
            $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
            # We also need to increment global_found_error as we are skipping
            # to the next loop iteration
            $global_found_error++;
            next LOOP;
        }
        
        # Validate the log_dir
        SWITCH: foreach ($log_dir) {
            last SWITCH if /^ING$/;
            last SWITCH if /^EG$/;
            $logger->warn(__PACKAGE__ . " ID: $elem->[0] Log direction '$log_dir' should be ING or EG");
            $found_error++;
        }
        
        if ($log_type eq "ACT") {
        # This is a CDR parse string so we need to further split 
        # the $rest_of_parse_string

            my ($cdr_record_type, $cdr_field, $cdr_regexp) = split /:/, $rest_of_parse_string, 3;     
        
            # Check split succeeded...
            if(!((defined $cdr_record_type) && (defined $cdr_field) && (defined $cdr_regexp))) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] Could not find second 2 ':' delimiters in CDR string, skipping further checks");
                $found_error++;
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                # We also need to increment global_found_error as we are skipping
                # to the next loop iteration
                $global_found_error++;
                next LOOP;
            }

            SWITCH: foreach ($cdr_record_type) {
                last SWITCH if /^START([0-9]*)$/;
                last SWITCH if /^STOP([0-9]*)$/;
                last SWITCH if /^INTERMEDIATE([0-9]*)$/;
                last SWITCH if /^ATTEMPT([0-9]*)$/;
                last SWITCH if /^SW_CHANGE([0-9]*)$/;
                last SWITCH if /^REBOOT([0-9]*)$/;
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] CDR Record type '$cdr_record_type' should be START,STOP,INTERMEDIATE,ATTEMPT,SW_CHANGE or REBOOT succeeded by zero or more numeric characters");
                $found_error++;
            }
            
            # Extract the occurrence, if any.
            $cdr_record_type =~ /^([A-Z,_]+)([0-9]*)$/;
            $cdr_record_type = $1;
            my $cdr_occurrence = $2;
            
            if (!($cdr_field =~ /^F([1-9][0-9]*)(-([1-9][0-9]*))?$/)) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] CDR Field number '$cdr_field' is INVALID. Must be in format F[1-9][0-9]*(-([1-9][0-9]*))?");
                $found_error++;
            }
            # Extract the field, and sub-field, if any.
            $cdr_field = $1;
            my $cdr_subfield = $3;
             
            # Check if the user-supplied regexp is valid - where valid == parseable by perl.
            # NB 'dummy' kills warnings where $_ is undefined cf. the // alone.
            
            # We only allow regular expressions that are:
            #   1. Non-blank
            #   2. Enclosed in double quotes
            #   3. Can not have any chars preceeding the first double quotes of the regexp.
            #   4. Can optionally have trailing whitespace and/or comment string after the close quote of the regexp
            #   5. The comment string is prefixecd with '#' and must not contain any double quotes
            if (!($cdr_regexp =~ /^"(.*)"(\s+)?(#.*)?$/)) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Regexp is not wrapped in \"\" or contains leading/trailing garbage");
                $found_error++;
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                # We also need to increment global_found_error as we are skipping
                # to the next loop iteration
                $global_found_error++;
                # Need to jump to next iteration of for loop to parse next string.
                next LOOP;
            }
            # Extract the regexp string, if any.
            $cdr_regexp = $1;
            
            # If cdr_regexp is undefined at this point this means that the regexp
            # was defined blank between two quotes. i.e. ""
            # This is invalid and needs to warn the user to change to "^$";
            if (!defined($cdr_regexp) || ($cdr_regexp eq "")) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Invalid Blank Regexp defined. Ensure regexp set to \"\^\$\" if you want to identify a blank value.");
                $found_error++;
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                # We also need to increment global_found_error as we are skipping
                # to the next loop iteration
                $global_found_error++;
                # Need to jump to next iteration of for loop to parse next string.
                next LOOP;
            }
            
            eval {
                "dummy" =~ /$cdr_regexp/;
            };
            if ($@) {
                my $error=$@;
                $error =~ s/ at UKLogParser.pm.*//;
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Regexp '$cdr_regexp' is INVALID ($error)");
                $found_error++;
            }

            
            # Phew - we're done with all our checks for ACT match-strings!
            
            if ($found_error) {
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                $global_found_error++;                  
            } else {
                # Stash the results in our new AoA.
                push @matchstrings_act, [ $elem->[0], $not_expr, $log_type, $log_dir, $cdr_record_type, $cdr_occurrence, $cdr_field, $cdr_subfield, $cdr_regexp ];
            }    
        } else {
            # Log type is "DBG", "SYS" or "TRC"
            
            # We only allow regular expressions that are:
            #   1. Non-blank
            #   2. Enclosed in double quotes
            #   3. Can not have any chars preceeding the first double quotes of the regexp.
            #   4. Can optionally have trailing whitespace and/or comment string after the close quote of the regexp
            #   5. The comment string is prefixecd with '#' and must not contain any double quotes
            if (!($rest_of_parse_string =~ /^"(.*)"(\s+)?(#.*)?$/)) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Regexp '$rest_of_parse_string' is not wrapped in \"\" or contains leading/trailing garbage");
                $found_error++;
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                $global_found_error++;
                # Need to jump to next iteration of for loop to parse next string.
                next LOOP;
            }
            
            # Extract the regexp string, if any.
            $rest_of_parse_string = $1;
            
            # If $rest_of_parse_string is undefined at this point this means
            # that the regexp was defined blank between two quotes. i.e. ""
            # This is invalid and needs to warn the user to change to "^$";
            if (!defined($rest_of_parse_string)) {
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Invalid Blank Regexp defined. Ensure regexp set to \"\^\$\" if you want to identify a blank value.");
                $found_error++;
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                $global_found_error++;
                # Need to jump to next iteration of for loop to parse next string.
                next LOOP;
            }

            eval {
                "dummy" =~ /$rest_of_parse_string/;
            };
            if ($@) {
                my $error=$@;
                $error =~ s/ at UKLogParser.pm.*//;
                $logger->warn(__PACKAGE__ . " ID: $elem->[0] $log_type Regexp '$rest_of_parse_string' is INVALID ($error)");
                $found_error++;
            }
            if ($found_error) {
                $logger->error(__PACKAGE__ . " ID: $elem->[0] contains $found_error error(s) - (Author:$elem->[2] please fix them)");
                $global_found_error++;                  
            } else {
                # Stash the results in our new AoA.
                push @matchstrings_evlog, [ $elem->[0], $not_expr, $log_type, $log_dir, $rest_of_parse_string ];
            }    
        } # endif ACT (or DBG,SYS,TRC)
    }

    $logger->debug(__PACKAGE__ . ".$sub Leaving function with return code '$global_found_error'");
    return ($global_found_error);
}

=head1 B<parse_act_file()>

  Takes the specified ACT file and parses it into an array of arrays using Text::CSV module.

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs: 

 <act filename>

=item Outputs: 

 Reference to array of arrays of ACT fields

=back

=cut

sub parse_act_file {
    
    my $filename = shift(@_);
    my @returnary;
   
    my $sub = "parse_act_file()";
    $logger->debug(__PACKAGE__ . ".$sub Entering function");

    if (defined($filename)) {
        open ACT, "<$filename" or do { $logger->error(__PACKAGE__ . ".parse_act_file - Cannot open ACT file") ; return undef };
        my $fcsv = Text::CSV->new;
        LOOP: while(<ACT>) {
            my @tempary;
            $#tempary=-1;
            if($fcsv->parse($_)) {
                my @cdr_record_fields = $fcsv->fields;
                for (@cdr_record_fields) {
                    if (/,/) { # Field is a subfield, split it again
                        if($fcsv->parse($_)) {
                            my @subfield = $fcsv->fields;
                            push @tempary, [ @subfield ]; 
                        } else {
                            $logger->error(__PACKAGE__ . ".parse_act_file - failed to parse subfield '$_', error " . $fcsv->error_input);
                            $#returnary=-1;
                            last LOOP;
                        }
                    } else {
                        # Normal field
                        push @tempary, [ $_ ];
                    }
                }
            } else {
                $logger->error(__PACKAGE__ . ".parse_act_file - failed to parse field '$_', error " . $fcsv->error_input);
                $#returnary=-1;
                last LOOP;
            }
            push @returnary, [ (@tempary) ];
        }       
        
        close ACT;
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return \@returnary;
}

=head1 B<match_evlog()>

  Takes the array of valid evlog matchstings and validates against the specified event logs.

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs: 

 Current error count, Event log type (DBG/SYS/TRC), GSX side (ING or EG), appropriate Event log filename, @matchstrings_evlog array

=item Outputs: 

 Returns the current error count which is incremneted for each error found

=back

=cut

sub match_evlog {
    my ($current_error_count,$evlog_type,$gsx_side_regexp,$evlog_filename) = @_;
    
    my @valid_evlog_match_str_ary;
    
    my $sub = "match_evlog()";
    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    
    foreach my $matchstring (@matchstrings_evlog) {
        my ($test_id, $not_expr, $log_type, $log_dir, $match_regexp) = @$matchstring;
        if (($log_type eq $evlog_type) && ($log_dir =~ /$gsx_side_regexp/)) {
            push @valid_evlog_match_str_ary, [ $test_id, $not_expr, $match_regexp ];
        }
    }
    
    my $num_valid_evlog_match_str = $#valid_evlog_match_str_ary +1;
    if ($num_valid_evlog_match_str > 0) {
        if (!defined($evlog_filename)) {
            $logger->error(__PACKAGE__ . ".match_evlog - No $evlog_type file specified to match against $num_valid_evlog_match_str $evlog_type match string(s)");
            return ++$current_error_count;
        }
        
        open EVLOG, "<$evlog_filename" or do { $logger->error(__PACKAGE__ . ".match_evlog - Cannot open $evlog_type file '$evlog_filename'. Cannot match against $evlog_type match string") ;return ++$current_error_count};
        
        my @search_str_match_result_ary;
        my $evlog_line_count = 0;
        
        LOOP: while(<EVLOG>) {
            my $match_str_index = -1;
            $evlog_line_count++;
            foreach my $matchstring (@valid_evlog_match_str_ary) {
                my ($test_id, $not_expr, $match_regexp) = @$matchstring;
                
                my $result = 0;
                $match_str_index++;
            
                if (/$match_regexp/) {
                    # successfully match expression $match_regexp
                    $result = 1;
                } else {
                    # failed to match expression $match_regexp
                    $result = 0;
                }
                
                if ($not_expr == 1) {
                    if ($result == 1) {
                        # We have found a match that is not supposed to be there
                        $search_str_match_result_ary[$match_str_index] = 0;
                        # Jump to next line in evlog file
                        next LOOP;
                    } elsif (!(defined($search_str_match_result_ary[$match_str_index]))) {
                        
                        $search_str_match_result_ary[$match_str_index] = 1;   
                    } 
                } elsif ($result == 1) {
                    # We are a positive match so
                    # jump to next_line in evlog file
                    $search_str_match_result_ary[$match_str_index] = 1;
                    next LOOP;
                } elsif (!(defined($search_str_match_result_ary[$match_str_index]))) {
                    $search_str_match_result_ary[$match_str_index] = 0;
                }
            } # end of for
        } # end of while
        
        for (my $match_str_index=0; $match_str_index < $num_valid_evlog_match_str; $match_str_index++) {
            my $overall_result =  $search_str_match_result_ary[$match_str_index];
            my $valid_evlog_match_str = $valid_evlog_match_str_ary[$match_str_index];
            my ($test_id, $not_expr, $match_regexp) = @$valid_evlog_match_str;
            
            if (defined($overall_result) && $overall_result == 0) {
                # The match string expression has failed so print an error
                my $not_char = ($not_expr == 1) ? "due " : "";
                $logger->error(__PACKAGE__ . ".match_evlog ID: $test_id - Failed " . $not_char . "to match regexp \"" . qq{$match_regexp} . "\" in $gsx_side_regexp $evlog_type Event Log" );
                $current_error_count++;
            } elsif ($evlog_line_count == 0 && $test_id =~ /^GEN_/) {
                my $neg_str = ($not_expr == 1) ? "negative " : "";
                $logger->warn(__PACKAGE__ . ".match_evlog ID: $test_id - Warning, ignoring attempt to " . $neg_str . "match on generic regexp \"" . qq{$match_regexp} . "\" in $gsx_side_regexp $evlog_type Event Log due to empty log file." );
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function with return code '$current_error_count'");
    return $current_error_count;
}

=head1 B<match_actlog()>

  Takes the array of valid act log matchstings and validates against the specified act logs.

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Inputs:

 current error count, GSX side (ING or EG), array of the parsed ACT file, @matchstrings_act array

=item Outputs:

 Returns the current error count which is incremneted for each error found

=back

=cut

sub match_actlog {
    my ($current_error_count,$gsx_side_regexp,$cdr_records_ary_ref) = @_;
    
    my $sub = "match_actlog()"; 
    $logger->debug(__PACKAGE__ . ".$sub Entering function");

    # Setup hashes to identify the CDR field number of the Ingress/Egress Protocol 
    # Variant data for each type of CDR record
    # Hash:
    #       Key=<CDR Record Type>
    #       Value=<CDR field of Ingress/Egress Protocol Variant Data>
    # NOTE: Array index from 0 (not 1) so field number is one less than actual value.
    
    # Ingress Protocol Variant hash
    my %ing_prot_variant_hash   = ( START => 41,
                                    STOP  => 51,
                                    INTERMEDIATE => 37,
                                    ATTEMPT => 44 );
  
    # Egress Protocol Variant Data hash
    my %eg_prot_variant_hash    = ( START => 54,
                                    STOP  => 68,
                                    INTERMEDIATE => 50,
                                    ATTEMPT => 58 );
    
    # Identify the match strings that are valid for the log
    my @valid_act_match_str_ary;
    # Hef change 15 Apr 2008
    my $carrier_info_7_populated=0;
    my $carrier_info_14_populated=0;
    my $carrier_info_20_populated=0;
    foreach my $matchstring (@matchstrings_act) {               
        my ($test_id, $not_expr, $log_type, $log_dir, $cdr_record_type, $cdr_occurrence, $cdr_field, $cdr_subfield, $cdr_regexp) = @$matchstring;
        
        if ($log_dir =~ /$gsx_side_regexp/) {
            $cdr_subfield = "" if !defined($cdr_subfield);
        
            # Checking to see what match strings are being checked for the JAPAN CDR sub-fields
            # to see if we need to make any modification to the parse strings for the
            # Carrier Information Transfer fields
            #
            # Upto and including GSX Release 6.0 there were:
            #       7 carrier type CDR structures (1 to 7) (subfields 27 through to 54)
            #          where each structure contains:
            #               Carrier Flag 
            #               Carrier Code
            #               POI-CA code
            #               POI-Level
            #
            # GSX Release 6.1 through to 7.1 added a further:
            #       7 carrier type structures (8 to 14) (structure same as above) (subfields 69 through to 96)
            #    and Carrier Information Transfer Message and Type fields for carrier types 1 to 14 (subfields 107 through to 120)
            #
            # Release 7.2 onwards has added a further:
            #       6 carrier type structures (15 to 20) (subfields 143 through to 172)
            #           where each structure contains:
            #               Carrier Information Transfer Message and Type
            #               Carrier Flag 
            #               Carrier Code
            #               POI-CA code
            #               POI-Level
            #           
            # ASSUMPTION: One or more of the 4 or 5 fields representing the last carrier type structure is checked for
            #             by the match strings. This is used to identify the conversion required later.
            # 
            if ( $cdr_subfield =~ m/^16[8-9]$|^17[0-2]$/ ||  $cdr_subfield eq "168" ) {
                # The match strings are assuuming a 7.2 format
                $carrier_info_20_populated = 1;
                $carrier_info_7_populated = 0;
                $carrier_info_14_populated = 0;
            } elsif ( $cdr_subfield =~ m/^9[3-6]$/ || $cdr_subfield eq "120" ) {
                # The match strings are assuuming a 6.1 format
                $carrier_info_14_populated = 1;
                $carrier_info_7_populated = 0;
                $carrier_info_20_populated = 0; 
            } elsif (  $cdr_subfield =~ m/^5[1-4]$/) {
                # The match strings are assuuming a 6.0 format
                $carrier_info_7_populated = 1;
                $carrier_info_14_populated = 0;
                $carrier_info_20_populated = 0;
            }
            # else do nothing as we need to leave variables as they are
            push @valid_act_match_str_ary, [ $test_id, $not_expr, $cdr_record_type, $cdr_occurrence, $cdr_field, $cdr_subfield, $cdr_regexp ];
        }
    }
    
    my $num_valid_act_match_str = $#valid_act_match_str_ary +1;
    if ($num_valid_act_match_str > 0) {
                            
        if (!defined($cdr_records_ary_ref) || $#{$cdr_records_ary_ref} < 0) {
            $logger->error(__PACKAGE__ . ".match_actlog - No $gsx_side_regexp ACT file specified to match against $num_valid_act_match_str ACT match string(s) or ACT file is blank");
            return ++$current_error_count;
        }
     
        my %occurrence_hash = ();
        my @search_str_match_result_ary;
        my $cdr_record_count = 0;
        foreach my $cdr_record (@$cdr_records_ary_ref) {
            
            if (defined $occurrence_hash{$$cdr_record[0][0]} ) {
                #Increment hash value by one
                $occurrence_hash{$$cdr_record[0][0]} += 1;                                                     
            } else {
                # Initialise has value to 1
                $occurrence_hash{$$cdr_record[0][0]} = 1;
            }
            
            my $ing_cdr_variant_format_type = 10;
            my $eg_cdr_variant_format_type = 10;
            my $ing_prot_field_num;
            my $eg_prot_field_num;
            my %subfield_sub_hash=();
            my $ing_carr_offset = -1;
            my $eg_carr_offset = -1;
          
            # Check to see if the actual CDR record is valid    
            if ($ing_prot_variant_hash{$$cdr_record[0][0]}) {
                
                # Get CDR subfield value of Ingress Protocol Variant data for current CDR record
                $ing_prot_field_num = $ing_prot_variant_hash{$$cdr_record[0][0]};
                # Get CDR subfield value of Egress Protocol Variant data for current CDR record                
                $eg_prot_field_num = $eg_prot_variant_hash{$$cdr_record[0][0]};
                
                if ( $$cdr_record[$ing_prot_field_num][0] eq "JAPAN" ) {
                        
                    # Get length of CDR Ingress Protocol Data subfield structure
                    my $ing_variant_length = $#{$$cdr_record[$ing_prot_field_num]} + 1;
                    
                    if ($ing_variant_length < 69) {
                        # CDR is in 6.0 format. No conversion necessary
                        $ing_cdr_variant_format_type = 60 ;
                    } else{
                        # CDR must be 6.1 or 7.2 format
                       
                        if ($ing_variant_length < 143) {
                            # CDR is in 6.1 format. 
                            $ing_cdr_variant_format_type = 61;
                        } else {
                            # CDR is in 7.2 format.
                            $ing_cdr_variant_format_type = 72;
                        }
                        
                        if (($carrier_info_7_populated == 1) || ($carrier_info_14_populated == 1))  {
                            # Match string format in 6.0 or 6.1 format
                            # NOTE: No conversion necessary if match string format is 7.2
                            
                            my $carrier_count = 1;      # Init to first carrier structure
                            my $carrier_subfield = 107; # Init to first carrier field of Carrier Info Trans Msg and Type field
                            my $carrier_info_rec_field_gap = 1;
                            
                            # Loop through the carrier structures until Carrier Info Trans Msg and Type is blank or not equal values 3 to 9.
                            # Value 3 to 9 are the Post IAM carrier info trans event data.
                            #print Dumper($cdr_record);
                            #print "Ingress Subfield $carrier_subfield for log $ing_prot_field_num= $$cdr_record[$ing_prot_field_num][$carrier_subfield-1]\n";
                            while ($$cdr_record[$ing_prot_field_num][$carrier_subfield-1] ne "" && $$cdr_record[$ing_prot_field_num][$carrier_subfield-1] !~ /^[1-2]$/ ) {
                            #while ($carrier_count<=20 && $$cdr_record[$ing_prot_field_num][$carrier_subfield-1] !~ /^[1-2]$/ ) {

                                $carrier_subfield += $carrier_info_rec_field_gap;
                                if ($carrier_subfield == 121) {
                                    # We've gone beyond carrier 14 so we now need to convert to carrier 15
                                    # and adjust CIT message type field gap accordingly
                                    $carrier_subfield = 143;
                                    $carrier_info_rec_field_gap = 5;
                                }
                                $carrier_count++;
                            }
                            #print "Ingress carrier count = $carrier_count\n";

                            # ing_carr_offset will mark the start of the split for conversion of carrier structure data
                            # for the ingress protocol variant data
                            $ing_carr_offset = $carrier_count;
                        }
                    }
                    $logger->debug(__PACKAGE__ . ".match_actlog ID: $test_id - Found JAPAN ingress protocol variant! Size = $ing_variant_length, Format=$ing_cdr_variant_format_type, Offset=$ing_carr_offset");
                }
                
                if ( $$cdr_record[$eg_prot_field_num][0] eq "JAPAN" ) {
                   
                    # Get length of CDR Egress Protocol Data subfield structure
                    my $eg_variant_length = $#{$$cdr_record[$eg_prot_field_num]} + 1;
                    
                    if ($eg_variant_length < 69) {
                        # CDR is in 6.0 format. No conversion necessary
                        $eg_cdr_variant_format_type = 60 ;
                    } else{
                        # CDR must be 6.1 or 7.2 format
                        
                        if ($eg_variant_length < 143) {
                            # CDR is in 6.1 format.
                            $eg_cdr_variant_format_type = 61;
                        } else {
                            # CDR is in 7.2 format.
                            $eg_cdr_variant_format_type = 72;
                        }
                        
                        if (($carrier_info_7_populated == 1) || ($carrier_info_14_populated == 1))  {
                            # Match string format in 6.0 or 6.1 format
                            # NOTE: No conversion necessary if match string format is 7.2
                            
                            my $carrier_count = 1;      # Init to first carrier structure
                            my $carrier_subfield = 107; # Init to first carrier field of Carrier Info Trans Msg and Type field
                            my $carrier_info_rec_field_gap = 1;
                            #print "Egress Subfield $carrier_subfield for Log $eg_prot_field_num = $$cdr_record[$eg_prot_field_num][$carrier_subfield-1]\n";
                            # Loop through the carrier structures until Carrier Info Trans Msg and Type is blank or not equal values 3 to 9.
                            # Value 3 to 9 are the Post IAM carrier info trans event data.
                            while ($$cdr_record[$eg_prot_field_num][$carrier_subfield-1] ne "" && $$cdr_record[$eg_prot_field_num][$carrier_subfield-1] !~ /^[1-2]$/ ) {
                                $carrier_subfield += $carrier_info_rec_field_gap;
                                if ($carrier_subfield == 121) {
                                    # We've gone beyond carrier 14 so we now need to convert to carrier 15
                                    # and adjust CIT message type field gap accordingly
                                    $carrier_subfield = 143;
                                    $carrier_info_rec_field_gap = 5;
                                }
                                $carrier_count++;
                            }
                            #print "Egress carrier count = $carrier_count\n";

                            
                            # eg_carr_offset will mark the start of the split for conversion of carrier structure data
                            # for the egress protocol variant data
                            $eg_carr_offset = $carrier_count;
                        }
                    }    
                    $logger->debug(__PACKAGE__ . ".match_actlog ID: $test_id - Found JAPAN egress protocol variant! Size = $eg_variant_length, Format=$eg_cdr_variant_format_type, Offset=$eg_carr_offset");
                }

                
                if (($ing_cdr_variant_format_type == 61 || $eg_cdr_variant_format_type == 61) && $carrier_info_7_populated == 1) {
                    # The CDR format is in 6.1 format and the match strings are in 6.0 format.
                    # Conversion required from 6.0 to 6.1
                    
                    my $source_field_no ;
                    # Calculate CDR subfield position of first field in first carrier structure to split
                    # Default to CDR subfield 39 which is the first field (Carrier Flag) of carrier structure #4
                    if ( $ing_carr_offset != -1) {
                        $source_field_no = ($ing_carr_offset * 4) + 23;
                    } elsif ( $eg_carr_offset != -1) {
                        $source_field_no = ($eg_carr_offset * 4) + 23;
                    } else {
                        $source_field_no = 39;
                    }
                    
                    # Calculate CDR subfield position of where the first field in first carrier structure to split
                    # will be converted to.
                    # Offset by 42 sub-fields
                    my $target_field_no = $source_field_no + 42;
                    while ($target_field_no <= 96) {
                        # Add element to hash with key=source subfield value=target_subfield
                        $subfield_sub_hash{$source_field_no} = $target_field_no;
                        $source_field_no++;
                        $target_field_no++;
                    }
                } elsif ($ing_cdr_variant_format_type == 72 || $eg_cdr_variant_format_type == 72 ) {
                    # The CDR format is in 7.2 format 
                    
                    if ($carrier_info_7_populated) {
                        # The match strings are in 6.0 format.
                        # Conversion required from 6.0 to 7.2
                       
                        my $source_field_no ;
                        # Calculate CDR subfield position of first field in first carrier structure to split
                        # Default to CDR subfield 39 which is the first field (Carrier Flag) of carrier structure #4
                        if ( $ing_carr_offset != -1) {
                            $source_field_no = ($ing_carr_offset * 4) + 23;
                        } elsif ( $eg_carr_offset != -1) {
                            $source_field_no = ($eg_carr_offset * 4) + 23;
                        } else {
                            $source_field_no = 39;
                        }
                    
                        my $field_space = 1;
                        #my $target_field_no = 239;  #Init to first field of carrier structure #8
                        my $target_field_no = 172;  #Init to lastt field of carrier structure #20
                        #if ($source_field_no > 27) {
                        #    $target_field_no = ((($source_field_no - 27) / 4) * 5) + $target_field_no;
                        #}
                        
                        # 172 is the last field in carrier structure #20
                        my $tmp_field_no = 54;
                        while ($tmp_field_no >= $source_field_no) {
                            # Add element to hash with key=source subfield value=target_subfield
                            $subfield_sub_hash{$tmp_field_no} = $target_field_no;
                            $tmp_field_no--;
                            $target_field_no--;
                            if ($target_field_no == 143) {
                              $target_field_no = 96;
                            }
                            if ($target_field_no > 143 ) {
                              if ($field_space == 4) {
                                  # skip the carrier info transfer field
                                  $target_field_no--;
                                  $field_space = 0;
                              }
                              $field_space++;
                            }
                        }       
                    } elsif ($carrier_info_14_populated ) {
                        # The match strings are in 6.1 format.
                        # Conversion required from 6.1 to 7.2
                        
                        my $source_carrier = 8;
                        if ( $ing_carr_offset != -1) {
                            $source_carrier = $ing_carr_offset;
                        } elsif ( $eg_carr_offset != -1) {
                            $source_carrier = $eg_carr_offset;
                        }
                         
                        my $source_field_no;
                        # Calculate CDR subfield position of first field in first carrier structure to split
                        # If carrier structure to split on is less than 8 i.e. structures 1 to 7 then set the source_field_no accordingly by 23
                        # If 8 to 14 then adjust by 37.
                        if ($source_carrier < 8) {
                            $source_field_no = ($source_carrier * 4) + 23;
                        } else {
                            # Must be 8 to 14
                            $source_field_no = ($source_carrier * 4) + 37; 
                        }
                        # Target field
                        #my $target_field_no = 169 - ((14 - $source_carrier) * 5);
                        my $target_field_no = 172;
                        
                        my $field_space = 1;
                        my $tmp_field_no = 96;
                        my $cit_source_count = 120;
                        # 172 is the last field in carrier structure #20
                        while ($tmp_field_no >= $source_field_no) {
                            # Add element to hash with key=source subfield value=target_subfield
                            $subfield_sub_hash{$tmp_field_no} = $target_field_no;
                            if ($tmp_field_no == 69) {
                                # We have reached the start of carrier
                                # structure 8 so now jump to end  of carrier structure 7
                                $tmp_field_no = 54;
                            } else {
                                $tmp_field_no--;
                            }
                            
                            if ($target_field_no == 69) {
                                # We have reached the start of carrier
                                # structure 8 so now jump to end  of carrier structure 7
                                $target_field_no = 54;
                            } else {
                                $target_field_no--;
                            }
                            if ($field_space == 4) {
                                # skip the carrier info transfer field
                                if ($carrier_info_14_populated ) {
                                  if ($target_field_no >= 143) {
                                    $subfield_sub_hash{$cit_source_count} = $target_field_no;
                                    if ($target_field_no == 143) {
                                        # We have reached the start of carrier
                                        # structure 15 so now jump to end of carrier
                                        # structure 14 
                                        $target_field_no = 96;
                                    } else {
                                        $target_field_no--;
                                    }
                                  } else {
                                    $subfield_sub_hash{$cit_source_count} = $cit_source_count + 6;
                                  }
                                  $cit_source_count--;
                                }
                                $field_space = 0;
                             }
                             $field_space++;
                        }
                    }
                }   
            }
            
            my $match_str_index = 0;
            foreach my $matchstring (@valid_act_match_str_ary) {
                my ($test_id, $not_expr, $cdr_record_type, $cdr_occurrence, $cdr_field, $cdr_subfield, $cdr_regexp) = @$matchstring;
                my $result = 0;
                
                # Check the CDR parse str is parsing against correct record
                if ( (($cdr_occurrence eq "") || ($cdr_occurrence eq $occurrence_hash{$$cdr_record[0][0]})) && ($cdr_record_type eq $$cdr_record[0][0]) ) {
                    my $cdr_field_index = $cdr_field - 1;
                    my $cdr_subfield_index = 0;
                    my $cdr_subfield_type = "";
                
                    if ( (($$cdr_record[$ing_prot_field_num][0] eq "JAPAN")||($$cdr_record[$eg_prot_field_num][0] eq "JAPAN")) &&
                         ($subfield_sub_hash{$cdr_subfield}) &&
                         ((($cdr_field - 1) == $ing_prot_variant_hash{$$cdr_record[0][0]}) ||
                          (($cdr_field - 1) == $eg_prot_variant_hash{$$cdr_record[0][0]}) ) ) {
                        # Adjust CDR match string to check for new JAPAN sub-field
                        $logger->debug(__PACKAGE__ . ".match_actlog ID: $test_id - Changing F${cdr_field}-${cdr_subfield} to be F${cdr_field}-$subfield_sub_hash{$cdr_subfield} for JAPAN");

                        $cdr_subfield = $subfield_sub_hash{$cdr_subfield};
                        $valid_act_match_str_ary[$match_str_index] = ["$test_id", "$not_expr", "$cdr_record_type", "$cdr_occurrence", "$cdr_field", "$cdr_subfield", "$cdr_regexp"];
                    }
                     
                    if ($cdr_subfield ne "") {
                        $cdr_subfield_index = $cdr_subfield - 1;
                    } 
                    # We need to try and match
                    
                    if (!defined $$cdr_record[$cdr_field_index] ) {
                        $logger->error(__PACKAGE__ . ".match_actlog ID: $test_id - Could not find CDR field F${cdr_field} in $gsx_side_regexp ACT $cdr_record_type record $occurrence_hash{$$cdr_record[0][0]}");
                        return ++$current_error_count;
                    }
                                        
                    if (!defined $$cdr_record[$cdr_field_index][$cdr_subfield_index]) {
                        $logger->error(__PACKAGE__ . ".match_actlog ID: $test_id - Could not find CDR sub-field F${cdr_field}-${cdr_subfield} in $gsx_side_regexp ACT $cdr_record_type record $occurrence_hash{$$cdr_record[0][0]}");
                        return ++$current_error_count;
                    } elsif ($#{$$cdr_record[$cdr_field_index]} > 0) {
                        $cdr_subfield_type = $$cdr_record[$cdr_field_index][0];
                    }
                   
                    if ($$cdr_record[$cdr_field_index][$cdr_subfield_index] =~ /^${cdr_regexp}$/) {
                        # successfully match expression $match_regexp
                        $result = 1;
                    } else {
                        #failed to match expression $match_regexp
                        $result = 0;
                    }
                    
                    if ($not_expr == 1) {
                        # Negate result
                        $result = ($result == 1) ? 0 : 1;   
                    }
                    
                    if (!defined($search_str_match_result_ary[$match_str_index])) {
                        $search_str_match_result_ary[$match_str_index] = "$result:$cdr_subfield_type:$$cdr_record[$cdr_field_index][$cdr_subfield_index]";  
                    } elsif ($cdr_occurrence eq "") {
                        # Only change the result if it has currently been marked as a pass
                        if ($search_str_match_result_ary[$match_str_index] =~ /^1:/) {
                            $search_str_match_result_ary[$match_str_index] = "$result:$cdr_subfield_type:$$cdr_record[$cdr_field_index][$cdr_subfield_index]";
                        }
                    } else {
                        # defined and looking for certain occurrence
                        $search_str_match_result_ary[$match_str_index] = "$result:$cdr_subfield_type:$$cdr_record[$cdr_field_index][$cdr_subfield_index]"; 
                    }
                }
                $match_str_index++;
            }
        } # end of for loop through records
        
        # Loop through all valid act match strings and check overall results 
        # for each string              
        for (my $match_str_index=0; $match_str_index < $num_valid_act_match_str; $match_str_index++) {
            # Get the current match str 
            my $valid_act_match_str = $valid_act_match_str_ary[$match_str_index];
            # Split the match string into its components
            my ($test_id, $not_expr, $cdr_record_type, $cdr_occurrence, $cdr_field, $cdr_subfield, $cdr_regexp) = @$valid_act_match_str;
            
            my $cdr_desc_str = "";
            # Setup the correct CDR record occurrence string for failure printing
            if ($cdr_occurrence eq "") {
                $cdr_desc_str = "ALL " . $cdr_record_type . " records";
            } else {
                $cdr_desc_str = $cdr_record_type . " record #" . $cdr_occurrence;
            }
            $cdr_desc_str .= " in " . $gsx_side_regexp . " ACT log";
            
            if (defined($search_str_match_result_ary[$match_str_index])) {
                # A valid result is available for this current match string
                
                # result_string is stored as follows:
                # <0 (fail) or 1 (pass)>:<cdr subfield type (possibly blank)>:<cdr field value>
                my $result_string = $search_str_match_result_ary[$match_str_index];
                if (($result_string =~ /^0:/)) {
                    # The match_string failed to match
                    
                    my $not_char = ($not_expr == 1) ? "!=" : "==";
                
                    my $cdr_field_desc = "(F" . $cdr_field;
                    my $cdr_field_name = "";
                    my ($dummy,$cdr_sub_field_name,$cdr_value) = split /:/, $result_string,3;
                    if ($cdr_subfield ne "") {
                        # A sub-field exists so we need to get name of CDR subfield
                        $cdr_field_name = CamRecordTable::CamGetSubFieldName($cdr_sub_field_name,$cdr_subfield);
                        $cdr_field_desc .= "-" . $cdr_subfield;
                    } else {
                        # No subfield exists so just get name of CDR field
                        $cdr_field_name = CamRecordTable::CamGetFieldName($cdr_record_type, $cdr_field);                    
                    }
                    if (defined $cdr_field_name) {
                        $cdr_field_name =~ s/\s+$// ;
                    } else {
                        $cdr_field_name = "";
                    }
                    $cdr_field_desc = $cdr_field_desc . " \"" . $cdr_field_name . "\" $not_char \"" . qq|$cdr_regexp| . "\")";
                    
                    $logger->error(__PACKAGE__ . ".match_actlog ID: $test_id - Failed to match on CDR Field $cdr_field_desc in $cdr_desc_str. Actual value = \"" . qq|$cdr_value| . "\"");
                    
                    $current_error_count++;
                }
            } else {
                # Remove any unknown records out of ACT log from hash so we can
                # test to see if the ACT log is empty.
                # Unknown records include the start and end line in ACT files.
                
                my $failure_reason = "";
                while (my ($key, $value) = each(%occurrence_hash)) {
                    if (($key ne "START") && ($key ne "STOP") && ($key ne "ATTEMPT") &&
                        ($key ne "INTERMEDIATE") && ($key ne "SW_CHANGE")) {
                        delete $occurrence_hash{$key};
                    } else {
                        $failure_reason = $failure_reason . "$key,";
                    }
                }
                if ($failure_reason eq "") {
                    $failure_reason = "due to ACT file being empty.";
                } else {
                    #Remove last comma
                    $failure_reason =~ s/,$//;
                    $failure_reason = ". Only found (" . $failure_reason . ")";
                }
                
                # If the result is not populated within the @search_str_match_result_ary
                # for the current match string then this means no occurrence of this
                # particular record was found so print an error.
                
                $logger->error(__PACKAGE__ . ".match_actlog ID: $test_id - Failed to find occurrence of ${cdr_desc_str} ${failure_reason}");
                $current_error_count++;
            }
        }     
    }   
    $logger->debug(__PACKAGE__ . ".$sub Leaving function with return code '$current_error_count'");
    return $current_error_count;
}

=head1 B<matchmaker()>

  Wrapper function to validate and match the  parse strings to the appropriate files

=over 6

=item Package:

 SonusQA::GSX::UKLogParser

=item Returns:

 1 if successful and 0 otherwise.

=back

=cut

sub matchmaker {

    my $sub = "matchmaker()";
    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    # Validate the parse strings and return the number of errors found 
    my $parse_error_count = validate_parse_strings;

    # If one or more of the parse strings are invalid the test has already failed
    # so there is no point in trying to match using bad data.
    if ($parse_error_count > 0) {
        $logger->info(__PACKAGE__ . ".$sub: Test Failed due to $parse_error_count parse error(s)\n");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function (retcode-0)");
        return 0;
    } else {
        # All the parse strings are valid
        
        my $match_error_count = 0;      # Count of errors in entire input space
        my $act1_ary_ref = parse_act_file($gsx_file{ACTING});
        my $act2_ary_ref = parse_act_file($gsx_file{ACTEG});
            
        foreach my $evlog_type ("DBG","SYS","TRC") {
            if (defined($gw)) {
                # Pattern match INGress patterns on GSX1 $evlog_type file
                $match_error_count = match_evlog($match_error_count, $evlog_type, "ING", $gsx_file{"${evlog_type}ING"});
                # Pattern match EGress patterns on GSX2 $evlog_type file
                $match_error_count = match_evlog($match_error_count, $evlog_type, "EG", $gsx_file{"${evlog_type}EG"});
            } else {
                # Pattern match ALL patterns on GSX1 $evlog_type file
                $match_error_count = match_evlog($match_error_count, $evlog_type, "ING|EG", $gsx_file{"${evlog_type}ING"}); 
            }
        }
        
        if (defined($gw)) {
            # Pattern match INGress patterns on GSX1 ACT file
            $match_error_count = match_actlog($match_error_count, "ING", $act1_ary_ref);
            # Pattern match EGress patterns on GSX2 $evlog_type file
            $match_error_count = match_actlog($match_error_count, "EG", $act2_ary_ref);
        } else {
            # Pattern match ALL patterns on GSX1 ACT file
            $match_error_count = match_actlog($match_error_count, "ING|EG", $act1_ary_ref); 
        }
        
        if ( $match_error_count > 0 ) {
            $logger->info(__PACKAGE__ . ".$sub: Test '$test_id' Failed due to $match_error_count match error(s)\n");
            $logger->debug(__PACKAGE__ . ".$sub Leaving function (retcode-0)");
            return 0;
        } else {
            if (defined $verbose) {
                $logger->info(__PACKAGE__ . ".$sub: Test '$test_id' Passed\n");
            }
            $logger->debug(__PACKAGE__ . ".$sub Leaving function (retcode-1)");
            return 1;
        }   
    }
}
1;
