package SonusQA::MSE::MSEHELPER;
use strict;

use vars qw( $VERSION );
our $VERSION = "1.00";

################################################################################

=head1 NAME

SonusQA::MSE::MSEHELPER - SonusQA MSEHELPER class

=head1 SYNOPSIS

use MSEHELPER;

=head1 DESCRIPTION

SonusQA::MSE::MSEHELPER provides a interface to MSE specific functions.

=head1 AUTHOR

AUTOMATION ENGINEER : Thangaraj A <tarmugasamy@sonusnet.com>

Created On          : 2010-03-08-10:27:52

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

2010-03-08

=cut

################################################################################
###############################################################################
# Define Packages Used
###############################################################################
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use SonusQA::GSX;



###############################################################################

=head1 METHODS

=cut

###############################################################################
# validateCliCmdResponseforCics()
###############################################################################

=head1 validateCliCmdResponseforCics()

=over 4

=item DESCRIPTION: 

    This function executes the CLI command, and validated the response for all
CICs against the list of columns and their respective values given.


=item ARGUMENTS:

    cliSession - MSE CLI session object

    cliCommand - MSE CLI command

    validate   - Hash containing column & value to validate for each CIC
                 column number - command result column (one based)
                 value         - command result value to be verified

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item INTERNAL FUNCTIONS USED:

    SonusQA::MSE::MSEHELPER::execCliCmd()

=item OUTPUT:

    %resultHash - RESULT hash

    $resultHash{RESULT} = 0 or 1;
                          0 - FAILED
                          1 - SUCCESS

    $resultHash{REASON} = "Contains reason for failure.";

    $resultHash{CICs}   - contains list of CIC's for which the validation failed.

    NOTE: REASON & CICs - used only when this function fails.

=item EXAMPLE: 

    my $cliCommand  = "SHOW BICC CIRCUIT SERVICE bs_SIVA CIC ALL STATUS";

    my %validateCICs = ( # Column(s) to validate per CIC
                         4 => 'IDLE',       # column 4 i.e. Circuit Status
                         5 => 'UNBLOCK',    # column 5 i.e. Admin Mode
                         7 => 'UNBLK',      # column 7 i.e. Maint Remote
                       );
    
    my %resultHash = SonusQA::MSE::MSEHELPER::validateCliCmdResponseforCics (
                                          $cliSession,
                                          $cliCommand,
                                          \%validateCICs,
                                        );

    unless ($resultHash{RESULT}) {
        $logger->debug(__PACKAGE__ . ".$testId:  validateCliCmdResponseforCics() - FAILED");
        $logger->debug(__PACKAGE__ . ".$testId:  Reason - $resultHash{REASON}");
        $logger->debug(__PACKAGE__ . ".$testId:  CICs   - @{ $resultHash{CICs} }");

        # Take corrective action based on CICs ...
        ...
        ...

        return $resultHash{RESULT};
    }

    $logger->debug(__PACKAGE__ . ".$testId:  validateCliCmdResponseforCics() - SUCCESS");

=back

=cut

################################################################################

sub validateCliCmdResponseforCics {
    my ($cliSession, $cliCommand, $validateHashRef) = @_;
    my $sub_name     = "validateCliCmdResponseforCics";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my %resultHash = ( # subroutine return value.
                     RESULT  => 0,            # FAIL
                   );

    ########################################################
    # Input Checking - Mandatory
    ########################################################
    unless ( defined $cliSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for MSE CLI session has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $resultHash{REASON} = "The mandatory argument for MSE CLI session has not been specified or is blank.";
        return %resultHash;
    }

    unless ( defined $cliCommand ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for MSE CLI Command has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $resultHash{REASON} = "The mandatory argument for MSE CLI Command has not been specified or is blank.";
        return %resultHash;
    }

    unless ( defined $validateHashRef ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for validating the CLI cmd response has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $resultHash{REASON} = "The mandatory argument for validating the CLI cmd response  has not been specified or is blank.";
        return %resultHash;
    }

    # variables used
    my %validate = %{ $validateHashRef };
    my @validateKeys = keys %validate;
    my $noOfKeysValidate = scalar keys %validate;

    # No. of header lines to check before actual response.
    # For most of CLI commands it has 2 header lines.
    my $headerFlag     = 2;
    my $maxRespColumns = -1;
    my @respHash;
    my (@failedCICs, @passedCICs);


    unless ( execCliCmd($cliSession, $cliCommand) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Execution of CLI command - \'$cliCommand\' - FAILED.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $resultHash{RESULT} = 0; # FAIL
        $resultHash{REASON} = "CLI Command Execution Error - \'$cliCommand\'.";
        return %resultHash;
    }

    foreach (@{$cliSession->{CMDRESULTS}}) {
        my $maxColumns = 0;
        my ($key, $value, %resp);

        unless ( $headerFlag == 0 ) { # i.e. processing header
            if ( /^--[\-|\ ]*--$/ ) {
                # Header line found
                $headerFlag--;
            }
            next;
        }
        else {
            # Start processing the response(s).
            my ( @tmp );
#            print "Response - \'$_\'\n";
            @tmp = split ( /\s+/, $_ );

            if ( $#tmp == -1 ) {
                # empty line i.e. no Column
                next;
            }
            elsif ($maxRespColumns == -1) {
                $maxRespColumns = $#tmp; # zero based
            }
            my $i = 1;
            foreach (@tmp) {
                $resp{$i} = $_;
                $i++;
            }
            push ( @respHash, %resp );
        }

        $maxColumns = $maxRespColumns + 1; # one based
        #print "\n\tMax Columns = $maxColumns \(i.e. one based\)\n\n";

        foreach $key (sort keys %validate) {
            $value = $validate{$key};
            #print "\tvalidating: sorted key = $key,\tvalue = $value\n";

            if ( $key <= $maxColumns ) {
                if ( $resp{$key} eq $value ) {
                    if ($passedCICs[-1] ne $resp{1} ) {
                        push ( @passedCICs, $resp{1} );
                    }
                    next;
                }
                else {
                    # process ERROR HANDLING
                    $resultHash{RESULT} = 0; # FAIL
                    push ( @failedCICs, $resp{1} );
                    unless (defined $resultHash{REASON}) {
                        $resultHash{REASON} = "CIC $resp{1}: validation for column $key with \'$value\', but received \'$resp{$key}\'";
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name:  CIC $resp{1} - validation for column $key with \'$value\', but received \'$resp{$key}\'");
                    last;
                }
            }
            else {
                # Invalid Column given for validation
                # so test case failed
                $resultHash{RESULT} = 0; # FAIL
                $resultHash{REASON} = "Invalid column $key, max column is $maxColumns.";
                push ( @failedCICs, $resp{1} );
                #last; # failed to break the loop
                $resultHash{CICs} = \@failedCICs;

                $logger->debug(__PACKAGE__ . ".$sub_name:  CIC $resp{1} - Invalid column $key, max column is $maxColumns.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return %resultHash;

            }
        }
    }

    if ( @failedCICs ) {
        $resultHash{RESULT} = 0; # FAIL
        $resultHash{CICs} = \@failedCICs;
        $logger->debug(__PACKAGE__ . ".$sub_name:  FAILED for CICs - @failedCICs");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    }
    else {
        $resultHash{RESULT} = 1; # PASS
        $resultHash{CICs} = \@passedCICs;
        $logger->debug(__PACKAGE__ . ".$sub_name:  PASSED for CICs - @passedCICs");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    }

    #$logger->debug(__PACKAGE__ . ".$sub_name:  result = $resultHash{RESULT}");
    #$logger->debug(__PACKAGE__ . ".$sub_name:  reason = \'$resultHash{REASON}\'");
    #$logger->debug(__PACKAGE__ . ".$sub_name:  CICs   = $resultHash{CICs}");
    return %resultHash;
}


###############################################################################
# getBiccServiceAdminStatus()
###############################################################################

=head1 getBiccServiceAdminStatus()

=over 4

=item DESCRIPTION: 

    This function executes the CLI command, and returns hash containing the response.


=item ARGUMENTS:

    cliSession   - MSE CLI session object

    service      - BICC service name

    responseHash - Hash containing CLI 'SHOW BICC SERVICE service ADMIN' output

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item INTERNAL FUNCTIONS USED:

    SonusQA::MSE::MSEHELPER::execCliCmd()

=item OUTPUT:

    return - 0 or 1
             0 - FAILED
             1 - SUCCESS

    %responseHash - conatining the command response output.


=item EXAMPLE: 

    my $service       = "Test";
    my %responseHash;

    unless (SonusQA::MSE::MSEHELPER::getBiccServiceAdminStatus (
                                    $mseCliSession,
                                    $service,
                                    \%responseHash,
                              ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Reason: getBiccServiceAdminStatus() - FAILED";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  getBiccServiceAdminStatus() - SUCCESSFUL");

    my $key = "Admin State";
    my $value = $responseHash{$key};
    $logger->debug(__PACKAGE__ . ".$test_id:  Admin State \= $value");

=back

=cut

################################################################################

sub getBiccServiceAdminStatus {
    my ($cliSession, $service, $responseHash_Ref) = @_;
    my $sub_name     = "getBiccServiceAdminStatus";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ########################################################
    # Input Checking - Mandatory
    ########################################################
    unless ( defined $cliSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument MSE CLI session has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $service ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument Service Name has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $responseHash_Ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument hash reference for getting CLI cmd response has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # variables used
    my $headerFlag   = 2;
    my $value_undef  = ""; # usef if VALUE is NOT DEFINED
    my ($key1, $key2, $val1, $val2);
    my ($prefixKey1, $prefixKey2);
    delete $responseHash_Ref->{$_} for keys %$responseHash_Ref;

    my $cliCommand = "SHOW BICC SERVICE $service ADMIN";
    
    unless ( execCliCmd($cliSession, $cliCommand) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Execution of CLI command - \'$cliCommand\' - FAILED.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@{$cliSession->{CMDRESULTS}}) {
        $key1 = undef; $val1 = undef;
        $key2 = undef; $val2 = undef;

        if ( ($_ eq "") || ($_ eq "\n") ) {
            # encountered empty line
            next;
        }

        unless ( $headerFlag == 0 ) { # i.e. processing header
            if ( /^--[\-|\ ]*--$/ ) {
                # Header line found
                $headerFlag--;
            }
            elsif (/^([\s\w]+)\s*\:\s(\S+)\s+\s+([\s\w]+)\s*\:\s([\s\S+]+)\s*$/) {
                # both key/value pair defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
            }
            elsif (/^([\s\w]+)\s*\:\s([\s\S+]+)\s*$/) {
                # Only one key/value pair defined
                $key1 = $1; $val1 = $2;
            }
        }
        else {
            if (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                # both key/value pair defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
               }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*\:\s*$/) {
                # first key/value pair defined, but 2nd value not defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*$/) {
                # first key/value pair defined, but 2nd (prefix)
                $key1 = $1; $val1 = $2;
                $prefixKey2 = $3;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s+\s+([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st value not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $3; 
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s+\s+([\s\(\)\w]+)\s*\:\s*$/) {
                # for both keys only defined, but values not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s*$/) {
                $key1 = $1; $val1 = $value_undef;
            }
            elsif (/^(([\s]*\b[\(]*\w+[\)]*\b)+)\s+\s+\s+(([\s]*\b[\(]*\w+[\)]*\b)+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st (prefix)
                $prefixKey1 = $1;
                $key2 = $3; $val2 = $5; 
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                $key1 = $1; $val1 = $2;
            }
            elsif (/^([\s\(\)\w]+)\s+\s+\s+([\s\(\)\w]+)$/) {
                $prefixKey1 = $1; $prefixKey2 = $2;
            }
        }
        if (defined $key1) {
            $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
            $val1 =~ s/^\s*//g; $val1 =~ s/\s*$//g;
            if (defined $prefixKey1) {
                $prefixKey1 =~ s/^\s*//g;
                $prefixKey1 =~ s/\s*$//g;
                my $newKey = "$prefixKey1 " . "$key1";
                $key1 = $newKey;
                $prefixKey1 = undef;
                $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
            }
            $responseHash_Ref->{$key1} = $val1;
        }

        if (defined $key2) {
            $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            $val2 =~ s/^\s*//g; $val2 =~ s/\s*$//g;
            if (defined $prefixKey2) {
                $prefixKey2 =~ s/^\s*//g;
                $prefixKey2 =~ s/\s*$//g;
                my $newKey = "$prefixKey2 " . "$key2";
                $key2 = $newKey;
                $prefixKey2 = undef;
                $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            }
            $responseHash_Ref->{$key2} = $val2;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


###############################################################################
# getBiccServiceProfileAdminStatus()
###############################################################################

=head1 getBiccServiceProfileAdminStatus()

=over 4

=item DESCRIPTION: 

    This function executes the CLI command, and returns hash containing the response.


=item ARGUMENTS:

    cliSession   - MSE CLI session object

    service      - BICC service name

    responseHash - Hash containing CLI 'SHOW BICC SERVICE PROFILE service ADMIN' output

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item INTERNAL FUNCTIONS USED:

    SonusQA::MSE::MSEHELPER::execCliCmd()

=item OUTPUT:

    return - 0 or 1
             0 - FAILED
             1 - SUCCESS

    %responseHash - conatining the command response output.


=item EXAMPLE: 

    my $service       = "Test";
    my %responseHash;

    unless (SonusQA::MSE::MSEHELPER::getBiccServiceProfileAdminStatus (
                                    $mseCliSession,
                                    $service,
                                    \%responseHash,
                              ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Reason: getBiccServiceProfileAdminStatus() - FAILED";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  getBiccServiceProfileAdminStatus() - SUCCESSFUL");

    my $key = "Admin State";
    my $value = $responseHash{$key};
    $logger->debug(__PACKAGE__ . ".$test_id:  Admin State \= $value");

=back

=cut

################################################################################

sub getBiccServiceProfileAdminStatus {
    my ($cliSession, $service, $responseHash_Ref) = @_;
    my $sub_name     = "getBiccServiceProfileAdminStatus";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ########################################################
    # Input Checking - Mandatory
    ########################################################
    unless ( defined $cliSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument MSE CLI session has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $service ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument Service Name has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $responseHash_Ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument hash reference for getting CLI cmd response has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # variables used
    my $headerFlag   = 2;
    my $value_undef  = ""; # usef if VALUE is NOT DEFINED
    my ($key1, $key2, $val1, $val2);
    my ($prefixKey1, $prefixKey2);
    delete $responseHash_Ref->{$_} for keys %$responseHash_Ref;

    my $cliCommand = "SHOW BICC SERVICE PROFILE $service ADMIN";
    
    unless ( execCliCmd($cliSession, $cliCommand) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Execution of CLI command - \'$cliCommand\' - FAILED.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@{$cliSession->{CMDRESULTS}}) {
        $key1 = undef; $val1 = undef;
        $key2 = undef; $val2 = undef;

        if ( ($_ eq "") || ($_ eq "\n") ) {
            # encountered empty line
            next;
        }

        unless ( $headerFlag == 0 ) { # i.e. processing header
            if ( /^--[\-|\ ]*--$/ ) {
                # Header line found
                $headerFlag--;
            }
            elsif (/^([\s\w]+)\s*\:\s(\S+)\s+\s+([\s\w]+)\s*\:\s([\s\S+]+)\s*$/) {
                # both key/value pair defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
            }
            elsif (/^([\s\w]+)\s*\:\s([\s\S+]+)\s*$/) {
                # Only one key/value pair defined
                $key1 = $1; $val1 = $2;
            }
        }
        else {
            if (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                # both key/value pair defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
               }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*\:\s*$/) {
                # first key/value pair defined, but 2nd value not defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\w]+)\s*$/) {
                # first key/value pair defined, but 2nd (prefix)
                $key1 = $1; $val1 = $2;
                $prefixKey2 = $3;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s+\s+([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st value not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $3; 
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s+\s+([\s\(\)\w]+)\s*\:\s*$/) {
                # for both keys only defined, but values not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s*$/) {
                $key1 = $1; $val1 = $value_undef;
            }
            elsif (/^(([\s]*\b[\(]*\w+[\)]*\b)+)\s+\s+\s+(([\s]*\b[\(]*\w+[\)]*\b)+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st (prefix)
                $prefixKey1 = $1;
                $key2 = $3; $val2 = $5; 
            }
            elsif (/^([\s\(\)\w]+)\s*\:\s(\S+)\s*$/) {
                $key1 = $1; $val1 = $2;
            }
            elsif (/^([\s\(\)\w]+)\s+\s+\s+([\s\(\)\w]+)$/) {
                $prefixKey1 = $1; $prefixKey2 = $2;
            }
        }

        if (defined $key1) {
            $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
            $val1 =~ s/^\s*//g; $val1 =~ s/\s*$//g;
            if (defined $prefixKey1) {
                $prefixKey1 =~ s/^\s*//g;
                $prefixKey1 =~ s/\s*$//g;
                my $newKey = "$prefixKey1 " . "$key1";
                $key1 = $newKey;
                $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
                $prefixKey1 = undef;
            }
            $responseHash_Ref->{$key1} = $val1;
        }

        if (defined $key2) {
            $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            $val2 =~ s/^\s*//g; $val2 =~ s/\s*$//g;
            if (defined $prefixKey2) {
                $prefixKey2 =~ s/^\s*//g;
                $prefixKey2 =~ s/\s*$//g;
                my $newKey = "$prefixKey2 " . "$key2";
                $key2 = $newKey;
                $prefixKey2 = undef;
                $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            }
            $responseHash_Ref->{$key2} = $val2;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


###############################################################################
# getSS7NodeAdminStatus()
###############################################################################

=head1 getSS7NodeAdminStatus()

=over 4

=item DESCRIPTION: 

    This function executes the CLI command, and returns hash containing the response.


=item ARGUMENTS:

    cliSession   - MSE CLI session object

    service      - SS7 service name

    responseHash - Hash containing CLI 'SHOW SS7 NODE service ADMIN' output

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item INTERNAL FUNCTIONS USED:

    SonusQA::MSE::MSEHELPER::execCliCmd()

=item OUTPUT:

    return - 0 or 1
             0 - FAILED
             1 - SUCCESS

    %responseHash - conatining the command response output.


=item EXAMPLE: 

    my $service       = "c7n5";
    my %responseHash;

    unless (SonusQA::MSE::MSEHELPER::getSS7NodeAdminStatus (
                                    $mseCliSession,
                                    $service,
                                    \%responseHash,
                              ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Reason: getSS7NodeAdminStatus() - FAILED";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  getSS7NodeAdminStatus() - SUCCESSFUL");

    my $key = "T1";
    my $value = $responseHash{$key};
    $logger->debug(__PACKAGE__ . ".$test_id:  $key \= $value");

=back

=cut

################################################################################

sub getSS7NodeAdminStatus {
    my ($cliSession, $service, $responseHash_Ref) = @_;
    my $sub_name     = "getSS7NodeAdminStatus";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ########################################################
    # Input Checking - Mandatory
    ########################################################
    unless ( defined $cliSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument MSE CLI session has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $service ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument Service Name has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $responseHash_Ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument hash reference for getting CLI cmd response has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # variables used
    my $headerFlag   = 4;
    my $value_undef  = ""; # usef if VALUE is NOT DEFINED
    my ($key1, $key2, $val1, $val2);
    my ($prefixKey1, $prefixKey2);
    delete $responseHash_Ref->{$_} for keys %$responseHash_Ref;

    my $cliCommand = "SHOW SS7 NODE $service ADMIN";
    
    unless ( execCliCmd($cliSession, $cliCommand) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Execution of CLI command - \'$cliCommand\' - FAILED.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@{$cliSession->{CMDRESULTS}}) {
        $key1 = undef; $val1 = undef;
        $key2 = undef; $val2 = undef;

        if ( ($_ eq "") || ($_ eq "\n") ) {
            # encountered empty line
            next;
        }

        unless ( $headerFlag == 0 ) { # i.e. processing header
            # Header line found
            $headerFlag--;

            if (/^([\s\w]+)\s*\:\s(\S+)\s+\s+([\s\w]+)\s*\:\s([\s\S]+)\s*$/) {
                # both key/value pair defined
                # keys - Node & Date
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
            }
            elsif (/^([\s\w]+)\s*\:\s([\s\S]+)\s*$/) {
                # Only one key/value pair defined
                # key - zone
                $key1 = $1; $val1 = $2;
            }
        }
        else {
            if (/^([\s\(\)\/\.\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\/\.\w]+)\s*\:\s([\s\w\(\)\-]+)\s*$/) {
                # both key/value pair defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $4;
               }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\/\.\w]+)\s*\:\s*$/) {
                # first key/value pair defined, but 2nd value not defined
                $key1 = $1; $val1 = $2;
                $key2 = $3; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s(\S+)\s+\s+([\s\(\)\/\.\w]+)\s*$/) {
                # first key/value pair defined, but 2nd (prefix)
                $key1 = $1; $val1 = $2;
                $prefixKey2 = $3;
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s+\s+([\s\(\)\/\.\w]+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st value not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $3; 
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s+\s+([\s\(\)\/\.\w]+)\s*\:\s([\s\w\(\)\-]+)\s*$/) {
                # 2nd key/value pair defined, but 1st value not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $3; 
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s+\s+([\s\(\)\/\.\w]+)\s*\:\s*$/) {
                # for both keys only defined, but values not defined
                $key1 = $1; $val1 = $value_undef;
                $key2 = $2; $val2 = $value_undef;
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s*$/) {
                $key1 = $1; $val1 = $value_undef;
            }
            elsif (/^(([\s]*\b[\(]*\w+[\)]*\b)+)\s+\s+\s+(([\s]*\b[\(]*\w+[\)]*\b)+)\s*\:\s(\S+)\s*$/) {
                # 2nd key/value pair defined, but 1st (prefix)
                $prefixKey1 = $1;
                $key2 = $3; $val2 = $5; 
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s(\S+)\s*$/) {
                $key1 = $1; $val1 = $2;
            }
            elsif (/^([\s\(\)\/\.\w]+)\s*\:\s([\s\w\(\)\-]+)\s*$/) {
                $key1 = $1; $val1 = $2;
            }
            elsif (/^([\s\(\)\/\.\w]+)\s+\s+\s+([\s\(\)\/\.\w]+)$/) {
                $prefixKey1 = $1; $prefixKey2 = $2;
            }
        }

        if (defined $key1) {
            $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
            $val1 =~ s/^\s*//g; $val1 =~ s/\s*$//g;
            if (defined $prefixKey1) {
                $prefixKey1 =~ s/^\s*//g;
                $prefixKey1 =~ s/\s*$//g;
                my $newKey = "$prefixKey1 " . "$key1";
                $key1 = $newKey;
                $key1 =~ s/^\s*//g; $key1 =~ s/\s*$//g;
                $prefixKey1 = undef;
            }
            $responseHash_Ref->{$key1} = $val1;
        }

        if (defined $key2) {
            $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            $val2 =~ s/^\s*//g; $val2 =~ s/\s*$//g;
            if (defined $prefixKey2) {
                $prefixKey2 =~ s/^\s*//g;
                $prefixKey2 =~ s/\s*$//g;
                my $newKey = "$prefixKey2 " . "$key2";
                $key2 = $newKey;
                $prefixKey2 = undef;
                $key2 =~ s/^\s*//g; $key2 =~ s/\s*$//g;
            }
            $responseHash_Ref->{$key2} = $val2;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


###############################################################################
# getUserLogDirectory()
###############################################################################

=head1 getUserLogDirectory()

=over 4

=item DESCRIPTION: 

    This function retrives user log directory if present else creates one.


=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    return 
        - user log directory path
        - 0 on failure


=item EXAMPLE: 

    my $userLogDir = SonusQA::MSE::MSEHELPER::getUserLogDirectory ();

=back

=cut

################################################################################

sub getUserLogDirectory() {
    my $sub_name     = "getUserLogDirectory";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($user_name, $user_home_dir, $user_log_dir);

    # Get User Home Directory
    if ( $ENV{ HOME } ) {
        $user_home_dir = $ENV{ HOME };
    }
    else {
        $user_name = $ENV{ USER };
        if ( system( "ls /home/$user_name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
            $user_home_dir   = "/home/$user_name";
        }
        elsif ( system( "ls /export/home/$user_name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
            $user_home_dir   = "/export/home/$user_name";
        }
        else {
            $user_home_dir = "/tmp";
            $logger->debug(__PACKAGE__ . ".$sub_name:   Could not establish users home directory... using $user_home_dir.");
        }
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name:   using User Home Directory \($user_home_dir\)");

    # User Log Directory
    $user_log_dir = "$user_home_dir/ats_user/logs";

    unless ( "-d $user_log_dir" ) {
        unless ( system ( "mkdir -p $user_log_dir" ) == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not create user log directory in $user_log_dir.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:   created User Log Directory \($user_log_dir\) - SUCCESS");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:   User Log Directory \($user_log_dir\) - SUCCESS");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return $user_log_dir;
}



###############################################################################
# execCliCmd()
###############################################################################

=head1 execCliCmd()

=over 4

=item DESCRIPTION: 

    The function is a wrapper around SonusQA::GSX::execCmd().
    This function parses the output of execCmd() to look for 'error' specific string. 
    It will then return 1 or 0 depending on this.
    In the case of timeout 'error' is returned.
    The CLI output from the command is then only accessible from $cliSession->{CMDRESULTS}.
    The idea of this function is to remove the parsing for 'error' from every CLI command call.


=item ARGUMENTS:

    cliSession - MSE CLI session object

    cliCommand - MSE CLI command

=item PACKAGE:

    SonusQA::MSE::MSEHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::GSX::execCmd()

=item OUTPUT:

    return 
        1 - Successful execution of CLI command
        0 - 'error' found in output or the CLI command timed out.

        $cliSession->{CMDRESULTS} - CLI output
        $cliSession->{HISTORY}    - CLI command issued


=item EXAMPLE: 

    unless ( SonusQA::MSE::MSEHELPER::execCliCmd($mseCliSession, $cliCommand) ) {
        $logger->error(__PACKAGE__ . ".$test_id:  execCliCmd\($cliCommand\) - FAILED");
        $TESTSUITE->{$test_id}->{METADATA} .= "CLI CMD ERROR:--\n@{$cliSession->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }

    # process the CLI command result
    foreach (@{$cliSession->{CMDRESULTS}}) {
        ...
        ...
        ...
    }

=back

=cut

################################################################################

sub execCliCmd {

    # If successful the cmd response is stored in $cliSession->{CMDRESULTS}

    my ($cliSession, $cliCommand) = @_;
    my $sub_name     = "execCliCmd";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ########################################################
    # Input Checking - Mandatory
    ########################################################
    unless ( defined $cliSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for MSE CLI session has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $cliCommand ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for MSE CLI Command has not been specified or is blank.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @result = $cliSession->execCmd( $cliCommand );

    foreach ( @result ) {
        chomp;
        if ( /^error/i ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Execution of CLI command - \'$cliCommand\' - FAILED.");
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI Command Execution Output - \'$_\'.");
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR:--\n@result");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:   Execution of CLI command - \'$cliCommand\' - SUCCESS");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}



=head2 C< configureMseFromTemplate >

Iterate through template files for tokens, 
replace all occurrences of the tokens with the values in the supplied hash (i.e. data from TMS).
For each template file using MSE session do the provisioning by sourcing the file from SonusNFS server.

Arguments :

 - file list (array reference)
      specify the list of file names of template (containing MSE commands)
 - replacement map (hash reference)
      specify the string to search for in the file
 - Path Information. Optional. Set as 1, for not to use "../C/" for sourcing TCL file

Return Values :

 - 0 configuration of sgx4000 using template files failed.
 - 1 configuration of sgx4000 using template files successful.

Example :
    my @file_list = (
                        "QATEST/MSE10/TEMPLATE/MSE10_CARD.template",
                        "QATEST/MSE10/TEMPLATE/MSE10_MEDIA.template",
                        "QATEST/MSE10/TEMPLATE/MSE10_BICC.template",
                        "QATEST/MSE10/TEMPLATE/MSE10_CIC.template",
                    );

    my %replacement_map = ( 
        # GSX - related tokens
        'GSXMNS11IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},
        'GSXMNS12IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{2}->{IP},
        'GSXMNS21IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{3}->{IP},
        'GSXMNS22IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{4}->{IP},
    
        # PSX - related tokens
        'PSX0IP1'  => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{IP},
        'PSX0NAME' => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{NAME},
    
        # GSX configuration
        'GSXPNS1SHELF' => $TESTBED{'gsx:1:ce0:hash'}->{SHELF}->{1}->{PNSCARD},
        'GSXPNS1SHELF' => $TESTBED{'gsx:1:ce0:hash'}->{SLOT}->{1}->{PNSCARD},
        'GSXSPS1SHELF' => $TESTBED{'gsx:1:ce0:hash'}->{SHELF}->{1}->{SPSCARD},
        'GSXSPS1SHELF' => $TESTBED{'gsx:1:ce0:hash'}->{SLOT}->{1}->{SPSCARD},

        # MGTS
        'MGTSIP' => $TESTBED{'mgts:1:ce0:hash'}->{NODE}->{1}->{IP},
    );

    unless ( SonusQA::MSE::MSEHELPER::configureMseFromTemplate( $gsx_session, \@mse_template_list, \%replacement_map, 1 ) ) {
        $logger->error(__PACKAGE__ . ".$sub : Could not source tcl file\(s\) on MSE ".$gsx_name);
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured MSE from Template files.");

=cut


sub configureMseFromTemplate {

    my ($session, $file_list_arr_ref, $replacement_map_hash_ref, $flagC) = @_ ;
    my $sub_name = "configureMseFromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $file_list_arr_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory file list array reference input is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    unless ( defined $replacement_map_hash_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory replacement map hash reference input is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    my $doNotUseC = 0;

    if( defined $flagC ) {
       if( $flagC eq 1 )  {
          $doNotUseC = 1;
       }
    }

    my ( @file_list, %replacement_map );
    @file_list       = @$file_list_arr_ref;
    %replacement_map = %$replacement_map_hash_ref;

    my ($NFS_ip, $NFS_userid, $NFS_passwd, $NFS_path);
    $NFS_ip     = $session->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    $NFS_userid = $session->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
    $NFS_passwd = $session->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
    $NFS_path   = $session->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'};

    foreach (@file_list) {
        my ( $f, @file_processed );
        my ( @template_file, $out_file_name );
        if (/(\w+\.template)$/) {
            $out_file_name = $1;
            $out_file_name =~ s/template/tcl/;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Out File name \'$out_file_name\'");

        unless ( open INFILE, $f = "<$_" ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open input file \'$_\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
        }

        @template_file  = <INFILE>;

        unless ( close INFILE ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close input file \'$_\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
        }

        # Check to see that all tokens in our input file are actually defined by the user... 
        # if so - go ahead and do the processing.
        my @tokens = SonusQA::Utils::listTokens(\@template_file);

        unless (SonusQA::Utils::validateTokens(\@tokens, \%replacement_map) == 0) {
            $logger->error(__PACKAGE__ . ".$sub_name:  validateTokens failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);
        unless ( @file_processed ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  replaceTokens failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        # open out file and write the content
        unless ( open OUTFILE, $f = ">$out_file_name" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open output file \'$out_file_name\'- Error: $!");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        print OUTFILE (@file_processed);

        unless ( close OUTFILE ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close output file \'$out_file_name\'- Error: $!");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        unless ( SonusQA::Utils::SftpFiletoNFS(
                                                $NFS_ip,
                                                $NFS_userid,
                                                $NFS_passwd,
                                                $NFS_path,
                                                $out_file_name,
                                              ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not SFTP file \'$out_file_name\' to SonusNFS.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Could SFTP file \'$out_file_name\' to SonusNFS.");
    
        unless ( $session->sourceTclFile( -tcl_file     => "$out_file_name",
                                          -doNotUseC    => $doNotUseC ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not source file \'$out_file_name\' from SonusNFS to MSE.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Could source file \'$out_file_name\' from SonusNFS to MSE.");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured MSE from Template.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}


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
