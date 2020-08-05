package SonusQA::SIMS::SIMSHELPER;
require Exporter;

use strict;
use warnings;

#########################################################################################################

=head1 COPYRIGHT

                              Sonus Networks, Inc.
                         Confidential and Proprietary.
                     Copyright (c) 2011 Sonus Networks
                              All Rights Reserved
 Use of copyright notice does not imply publication.
 This document contains Confidential Information Trade Secrets, or both which
 are the property of Sonus Networks. This document and the information it
 contains may not be used disseminated or otherwise disclosed without prior
 written consent of Sonus Networks.

=head1 DATE

2011-02-04

=cut

#########################################################################################################

=pod

=head1 NAME

 SonusQA::SIMS::SIMSHELPER - Perl module for Sonus Networks SIMS Statistics interaction

=head1 DESCRIPTION

 This SIMSHELPER package contains various subroutines that assists with SIMS Statistics related interactions.
 Subroutines are defined to provide Value add to the test execution in terms of verification and validation.

=head1 AUTHORS

   The <SonusQA::SIMS::SIMSHELPER> module has been created Thangaraj Arumugachamy <tarmugasamy@sonusnet.com>,
   alternatively contact <sonus-auto-core@sonusnet.com>.
   See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

#########################################################################################################
use SonusQA::Utils qw(:all);
use SonusQA::Base;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;


use vars qw( $VERSION );
our $VERSION = '1.0';

our %EXPORT_TAGS = ( 'all' => [ qw(
    getServerName
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
    getServerName
);

#########################################################################################################


#########################################################################################################

=head1 searchLogforPattern()

DESCRIPTION:

 The function is test case specific to load the profile,
 execute the following action commands
     - runGroup(),
     - startCallGeneration(),
     - stopCallGeneration(),
     for all groups or a specified group,
     from  SIMS CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The TESTDATA (hash reference) containing the following keys:
     testId           - Test Case ID as given in TMS
     profilePath      - Path of profile file
     profileFile      - File name of profile file
     profileTimeout   - In seconds - loadProfile() API timeout
     groupName        - Specific group name OR all groups (i.e. '*')
     runGroupTimeout  - In seconds - runGroup() API timeout
     startCallTimeout - In seconds - startCallGeneration() API timeout
     startCallPause   - In seconds - Sleep Time after startCallGeneration
     stopCallTimeout  - In seconds - stopCallGeneration() API timeout
     stopCallPause    - In seconds - Sleep Time after stopCallGeneration

PACKAGE:

 SonusQA::SIMSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 loadProfile()
 runGroup()
 startCallGeneration()
 stopCallGeneration()

OUTPUT:
 
 1 - Load profile and action commands applied to group successfuly
 0 - Failed to load profile and apply action commands to group


EXAMPLE:

    # Navtel Data required for Configuring Navtel for SIP, and loading Profile
    %NavtelData = (
        # used to source SIP configuration (.tcl) file
        configPath  => '/opt/GNiw95000/appl/atak/atak.data/testsuites/atak_sip_flex',
        configfile  => 'flexRunner.tcl',
    
        # used to source profile for each test case
        profilePath => '/var/iw95000/work/atak.data',
    );


    ##############################
    # Test Case Related Data
    ##############################
    my %testSpecificData = (
        profile   => 'SBV01_24A', # Profile File Name
        groupName => '*',         # for API - runGroup(), startCallGeneration(), stopCallGeneration()
    );

    # load profile and execute following action commands:-
    # runGroup(), startCallGeneration(), stopCallGeneration()
    unless ( $SimsAdminObj->searchLogforPattern (
                            '-testId'           => $TestId,
                            '-profilePath'      => $NavtelData{profilePath},
                            '-profileFile'      => $testSpecificData{profile},
                            '-profileTimeout'   => 60,  # seconds - loadProfile() API timeout
                            '-groupName'        => $testSpecificData{groupName},
                            '-runGroupTimeout'  => 120, # seconds - runGroup() API timeout
                            '-startCallTimeout' => 90,  # seconds - startCallGeneration() API timeout
                            '-startCallPause'   => 20,  # seconds - Sleep Time after startCallGeneration
                            '-stopCallTimeout'  => 90,  # seconds - stopCallGeneration() API timeout
                            '-stopCallPause'    => 30,  # seconds - Sleep Time after stopCallGeneration
                        ) ) {
        my $errMsg = '  FAILED - searchLogforPattern().';
        $testStatus->{reason} = $errMsg;
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug('  SUCCESS - searchLogforPattern()');

=cut

#################################################
sub searchLogforPattern {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'searchLogforPattern()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ testId patternList fullPath / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    #--------------------------------
    # Load test case related Profile
    #--------------------------------
    my %retHash;
    foreach my $pattern ( @{ $a{'-patternList'} } ) {
        my $cmd = 'grep "' . $pattern . '"' . $a{'-fullPath'};
        my @cmdResults = $self->{conn}->cmd (
                          '-string'  => $cmd,
                          '-timeout' => $a{'-timeout'},
                        );
        unless ( @cmdResults ) {
            $logger->error("  FAILED - $a{'-testId'} to execute cmd \'$cmd\'");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug("  SUCCESS - $a{'-testId'} executed cmd \'$cmd\'");

        $retHash{$pattern} = \@cmdResults;
    }

    $logger->debug(" <-- Leaving Sub [1]");
    return 1;
}


#########################################################################################################

=head1 getServerName()

DESCRIPTION:

 The subroutine is used to retrieve the server name.
 It will return server name or 0
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()

OUTPUT:
 
 0           - Failure
 $serverName - Success


EXAMPLE:

    my $serverName = $SimsAdminObj->getServerName(
                            '-timeout' => 30,
                            '-testId'  => $TestId,
                        );
    unless ( $serverName ) {
        $errorMsg = "  FAILED - to retrieve server name.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return 0;
    }
    $logger->debug("  SUCCESS - retrieved server name \'$serverName\'."); 

=cut

#################################################
sub getServerName {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getServerName()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    #---------------------
    # Execute CLI command
    #---------------------
    my $cmd = 'show table system serverAdmin';

    unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} FAILED - to execute cmd \'$cmd\'");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->info(" $a{'-testId'} SUCCESS - executed cmd \'$cmd\'");

    #--------------------------------
    # Parse command output/result
    #--------------------------------
    my $headerFlag = 0;
    my $serverName;
    foreach ( @{ $self->{CMDRESULTS} } ) {
        # admin@connexip915> show table system serverAdmin 
        #             COREDUMP           
        # NAME         PROFILE   ROLE     
        # --------------------------------
        # connexip915  default   primary  
        # [ok][2011-02-22 03:52:37]
        # admin@connexip915>
        unless ( $headerFlag ) { # i.e. processing header
            if( /^--[\-]*--$/ ) {
                $headerFlag = 1;
            }
            next;
        }
        else {
            if ( /^(\S+)\s+[\S\s]+$/ ) {
                $serverName = $1;
                last;
            }
            else {
                next;
            }
        }
    }

    unless ( defined $serverName ) {
        $logger->error(" $a{'-testId'} FAILED - to retrieve the server name.");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    else {
        $logger->debug(" $a{'-testId'} SUCCESS - retrieved server name \'$serverName\'");
        $retValue = 1;
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $serverName;
    }
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
