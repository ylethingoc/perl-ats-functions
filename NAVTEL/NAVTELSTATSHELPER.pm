package SonusQA::NAVTEL::NAVTELSTATSHELPER;

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

2011-01-07

=cut

#########################################################################################################

=pod

=head1 NAME

 SonusQA::NAVTEL::NAVTELSTATSHELPER - Perl module for Sonus Networks NAVTEL Statistics interaction

=head1 DESCRIPTION

 This NAVTELSTATSHELPER package contains various subroutines that assists with NAVTEL Statistics related interactions.
 Subroutines are defined to provide Value add to the test execution in terms of verification and validation.

=head1 AUTHORS

   The <SonusQA::NAVTEL::NAVTELSTATSHELPER> module is written by Kevin Rodrigues <krodrigues@sonusnet.com>
   and updated by Thangaraj Arumugachamy <tarmugasamy@sonusnet.com>,
   alternatively contact <sonus-auto-core@sonusnet.com>.
   See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

#########################################################################################################
use SonusQA::Utils qw(:all);
use SonusQA::Base;
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;


use vars qw( $VERSION );
our $VERSION = '1.0';

#########################################################################################################


#########################################################################################################

=head1 loadProfileExecStartStopCallStats()

DESCRIPTION:

 The function is test case specific to load the profile,
 execute the following action commands
     - runGroup(),
     - startCallGeneration(),
     - stopCallGeneration(),
     all groups or a specified group.
 and get test case specific detailed statistics to shell variable,
 from  NAVTEL CLI session (i.e. wish prompt).
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

 2. The STATSDATA (hash reference) containing the following keys:
     statsGroupName - The name of the specific group to retrieve statistics
     statsType      - The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type
     inOrOutStats   - incoming or outgoing statistics (i.e. in / out)
     curOrCumStats  - CURRENT or CUMULATIVE type of statistics (i.e. current / cumulative)
     variable       - Variable name to store the statistics data retrived using getDetailedStatistics() API
     statsTimeout   - In seconds - getDetailedStatistics() API timeout

 3. -stopCallGeneration - Either O or 1
     0 -> To skip stopCallGeneration() and getDetailedStatistics().
     1 -> Includes stopCallGeneration() and getDetailedStatistics().	 
     Default set to 1. 

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 loadProfile()
 runGroup()
 startCallGeneration()
 stopCallGeneration()
 getDetailedStatistics()

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


     # Test Case Related Data
     my ( $file, $groupName );
     $file       = 'SBV01_24A';
     $groupName  = '*';

     my $testData = {
         testId           => $TestId,
         profilePath      => $NavtelData{profilePath},
         profileFile      => $file,
         profileTimeout   => 60,  # seconds - loadProfile() API timeout
         groupName        => $groupName,
         runGroupTimeout  => 120, # seconds - runGroup() API timeout
         startCallTimeout => 90,  # seconds - startCallGeneration() API timeout
         startCallPause   => 20,  # seconds - Sleep Time after startCallGeneration
         stopCallTimeout  => 90,  # seconds - stopCallGeneration() API timeout
         stopCallPause    => 30,  # seconds - Sleep Time after stopCallGeneration
     };

     # Statistics Related Data
     my ( $statsGroupName, $statsType, $inOrOutStats, $curOrCumStats, $detailedStatsVariable );
     $statsGroupName = 'Navtel_2_1'; # The name of the group to retrieve statistics
     $statsType      = 'Flows';      # The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type
     $inOrOutStats   = 'in';         # incoming or outgoing statistics
     $curOrCumStats  = 'cumulative'; # CURRENT or CUMULATIVE type of statistics
     $detailedStatsVariable = 'FlowsInCumulative';

     my $flowsDetailedStatsVariable = 'FlowsInCumulative';
     my $statsData = {
         statsGroupName => $statsGroupName,
         statsType      => $statsType,
         inOrOutStats   => $inOrOutStats,
         curOrCumStats  => $curOrCumStats,
         variable       => $flowsDetailedStatsVariable,
         statsTimeout   => 20,  # seconds - Default is 10 seconds
     };
    
     # load profile, exec commands - runGroup, startCallGeneration, stopCallGeneration, getDetailedStats
     unless ( $NavtelObj->loadProfileExecStartStopCallStats (
                             '-testData'  => $testData,
                             '-statsData' => $statsData,
                         ) ) {
         my $errMsg = "  FAILED - loadProfileExecStartStopCallStats().\'";
         $testStatus->{reason} = $errMsg;
         $logger->error($errMsg);
         printFailTest (__PACKAGE__, $TestId, $errMsg);
         return $testStatus;
     }
     $logger->debug("  SUCCESS - loadProfileExecStartStopCallStats()");

=cut

#################################################
sub loadProfileExecStartStopCallStats {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'loadProfileExecStartStopCallStats()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my @validTestDataArgs  = qw/ testId profilePath profileFile profileTimeout groupName runGroupTimeout startCallTimeout startCallPause stopCallTimeout stopCallPause /;
    my @validStatsDataArgs = qw/ statsGroupName statsType inOrOutStats curOrCumStats variable statsTimeout /;

    # Check Mandatory Parameters
    foreach ( qw/ testData statsData / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( defined ($args{-stopCallGeneration}) ) {
	$args{-stopCallGeneration} = 1;
    }

    my ( %testData, %statsData );
    %testData  = %{ $args{'-testData'} };
    %statsData = %{ $args{'-statsData'} };

    foreach ( @validTestDataArgs ) {
        unless ( defined ( $testData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Test DATA argument for \'$_\' has not been specified OR is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  testData\{$_\}\t- $testData{$_}");
    }

    foreach ( @validStatsDataArgs ) {
        unless ( defined ( $statsData{$_} ) ) {
            $logger->error("  ERROR: The mandatory Stats DATA argument for \'$_\' has not been specified OR is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug("  statsData\{$_\}\t- $statsData{$_}");
    }

    # Load test case related Profile
    unless ( $self->loadProfile(
                           '-path'    => $testData{profilePath},
                           '-file'    => $testData{profileFile},
                           '-timeout' => $testData{profileTimeout},
            ) ) {
        $logger->error("  FAILED - $testData{testId} to load profile \'$testData{profilePath}\/$testData{profileFile}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $testData{testId} profile loaded \'$testData{profilePath}\/$testData{profileFile}\'");

    # Run Group(s) related to Profile / Test Case
    unless ( $self->runGroup(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => $testData{runGroupTimeout}, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - $testData{testId} to execute runGroup command for group \'$testData{groupName}\'.";
        $logger->error($errMsg);
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $testData{testId} executed runGroup command for group \'$testData{groupName}\'");

    # Start Call Generation related to Profile / Test Case
    unless ( $self->startCallGeneration(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => $testData{startCallTimeout}, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - $testData{testId} to execute startCallGeneration command for group \'$testData{groupName}\'.";
        $logger->error($errMsg);

        unless ( $self->haltGroup(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$testData{groupName}\'.";
            $logger->error($errMsg);
        }
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $testData{testId} executed startCallGeneration command for group \'$testData{groupName}\'");

    if ( $testData{startCallPause} ) {
        $logger->debug("  $testData{testId} startCallGeneration done, Sleeping for $testData{startCallPause} seconds...");
        sleep ( $testData{startCallPause} );
    }

    
    # Stop Call Generation related to Profile / Test Case
    if ( $args{-stopCallGeneration} ) {

        unless ( $self->stopCallGeneration(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => $testData{stopCallTimeout}, # Seconds
                                           # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - $testData{testId} to execute stopCallGeneration command for group \'$testData{groupName}\'.";
            $logger->error($errMsg);

            unless ( $self->haltGroup(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
                ) ) {
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testData{groupName}\'.";
                $logger->error($errMsg);
            }
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug("  SUCCESS - $testData{testId} executed stopCallGeneration command for group \'$testData{groupName}\'");
    
    
        # Sleep for Call(s) in-progress to complete
        if ( $testData{stopCallPause} ) {
            $logger->debug("  $testData{testId} stopCallGeneration done, Sleeping for $testData{stopCallPause} seconds...");
            sleep ( $testData{stopCallPause} );
        }

        # Get detailed statistics related to data provided, and save it to given variable
        unless ( $self->getDetailedStatistics(
                           '-groupName'     => $statsData{statsGroupName},
                           '-statsType'     => $statsData{statsType},
                           '-inOrOutStats'  => $statsData{inOrOutStats},
                           '-curOrCumStats' => $statsData{curOrCumStats},
                           '-variable'      => $statsData{variable},
                           '-timeout'       => $statsData{statsTimeout}, # Seconds
                                                   # default is 10 seconds
                ) ) {
            my $errMsg = "  FAILED - $testData{testId} to get detailed statistics for \'$statsData{statsGroupName} $statsData{statsType} $statsData{inOrOutStats} $statsData{curOrCumStats}\'";
            $logger->error($errMsg);

            unless ( $self->haltGroup(
                           '-groupName' => $testData{groupName},
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
                ) ) {
                my $errMsg = "  FAILED - to execute haltGroup command for group \'$testData{groupName}\'.";
                $logger->error($errMsg);
            }
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug("  SUCCESS - $testData{testId} got detailed statistics for \'$statsData{statsGroupName} $statsData{statsType} $statsData{inOrOutStats} $statsData{curOrCumStats}\'.");
    }
    $logger->debug(" <-- Leaving Sub [1]");
    return 1;
}

#########################################################################################################

=head1 loadProfileExecStartStopCalls()

DESCRIPTION:

 The function is test case specific to load the profile,
 execute the following action commands
     - runGroup(),
     - startCallGeneration(),
     - stopCallGeneration(),
     for all groups or a specified group,
     from  NAVTEL CLI session (i.e. wish prompt).
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

 Optional :
    
PACKAGE:

 SonusQA::NAVTELSTATSHELPER

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
    unless ( $NavtelObj->loadProfileExecStartStopCalls (
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
                            #optional params for config
                            '-serverName'       => "proxy_chet",
                            '-serverIpAddress'  => "10.54.32.141",
                            '-serverPort'       => "5060",
                            '-serverSelection'  => "proxy_chet",
                            '-blockName'        => "{user[0]}",
                        ) ) {
        my $errMsg = '  FAILED - loadProfileExecStartStopCalls().';
        $testStatus->{reason} = $errMsg;
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug('  SUCCESS - loadProfileExecStartStopCalls()');

=cut

#################################################
sub loadProfileExecStartStopCalls {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'loadProfileExecStartStopCalls()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    ###############################
    # Check Mandatory Parameters
    ###############################
    # foreach ( qw/ testId profilePath profileFile profileTimeout groupName runGroupTimeout startCallTimeout startCallPause stopCallTimeout stopCallPause / ) {
    foreach ( qw/ testId profilePath profileFile groupName / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = (
        '-groupName'        => '*',
        '-profileTimeout'   => 60,  # Seconds - default is 30 seconds
        '-runGroupTimeout'  => 120, # Seconds - default is 60 seconds (i.e. 1 minute)
        '-startCallTimeout' => 90,  # Seconds - default is 60 seconds (i.e. 1 minute)
        '-stopCallTimeout'  => 90,  # Seconds - default is 60 seconds (i.e. 1 minute)
        '-startCallPause'   => 20,  # seconds - Sleep Time after startCallGeneration
        '-stopCallPause'    => 30,  # seconds - Sleep Time after stopCallGeneration
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    #--------------------------------
    # Load test case related Profile
    #--------------------------------
    unless ( $self->loadProfile(
                           '-path'    => $a{'-profilePath'},
                           '-file'    => $a{'-profileFile'},
                           '-timeout' => $a{'-profileTimeout'},
            ) ) {
        $logger->error("  FAILED - $a{'-testId'} to load profile \'$a{'-profilePath'}\/$a{'-profileFile'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $a{'-testId'} profile loaded \'$a{'-profilePath'}\/$a{'-profileFile'}\'");

    
    #---------------------------------------------
    # Config Proxy server and EPBlockServer if,
    # relevant params are passed.
    #---------------------------------------------
    my $doConfig = 1;
    foreach ( qw/ serverName blockName serverPort serverIpAddress / ) {
        unless ( defined ( $a{"-$_"} ) ) {
            $logger->debug("  The required argument \'-$_\' for configuring Proxy server not present. So skipping Config");
            $doConfig = 0;
            last;
        }
    }
    
    # If all config params defined then go ahead do the config
    if ( $doConfig ) {
        my $cmd = "configProxyServer -serverName $a{-serverName} -ipAddress $a{-serverIpAddress} -port $a{-serverPort}";
        unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
            $logger->error("  FAILED - $a{'-testId'}  to configure using CLI command \'$cmd\':--\n@{ $self->{CMDRESULTS}}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug("  SUCCESS - Configured Proxy server \'$cmd\'.");
        
        $cmd = "hideGUI";
        
        $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        );
        
        $self->{conn}->buffer_empty;
        
        $cmd = "configEPBlockServer -group SIP_EP_1 -blockName $a{-blockName} -serverSelection $a{-serverName}";
        unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
            $logger->error("  FAILED - $a{'-testId'}  to configure EPBlockServer using CLI command \'$cmd\':--\n@{ $self->{CMDRESULTS}}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug("  SUCCESS - Configured EPBlock server \'$cmd\'.");
    } else {
        $logger->debug(" Not all config parameters defined, so skipping config step.");
    }
    
    #---------------------------------------------
    # Run Group(s) related to Profile / Test Case
    #---------------------------------------------
    unless ( $self->runGroup(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => $a{'-runGroupTimeout'}, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - $a{'-testId'} to execute runGroup command for group \'$a{'-groupName'}\'.";
        $logger->error($errMsg);
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $a{'-testId'} executed runGroup command for group \'$'-testData{groupName'}\'");

    #------------------------------------------------------
    # Start Call Generation related to Profile / Test Case
    #------------------------------------------------------
    unless ( $self->startCallGeneration(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => $a{'-startCallTimeout'}, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - $a{'-testId'} to execute startCallGeneration command for group \'$a{'-groupName'}\'.";
        $logger->error($errMsg);

        unless ( $self->haltGroup(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$a{'-groupName'}\'.";
            $logger->error($errMsg);
        }
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $a{'-testId'} executed startCallGeneration command for group \'$a{'-groupName'}\'");

    if ( $a{'-startCallPause'} ) {
        $logger->debug("  $a{'-testId'} startCallGeneration done, Sleeping for $a{'-startCallPause'} seconds...");
        sleep ( $a{'-startCallPause'} );
    }

    #-----------------------------------------------------
    # Stop Call Generation related to Profile / Test Case
    #-----------------------------------------------------
    unless ( $self->stopCallGeneration(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => $a{'-stopCallTimeout'}, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - $a{'-testId'} to execute stopCallGeneration command for group \'$a{'-groupName'}\'.";
        $logger->error($errMsg);

        unless ( $self->haltGroup(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - to execute haltGroup command for group \'$a{'-groupName'}\'.";
            $logger->error($errMsg);
        }
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug("  SUCCESS - $a{'-testId'} executed stopCallGeneration command for group \'$a{'-groupName'}\'");

    #-------------------------------------------
    # Sleep for Call(s) in-progress to complete
    #-------------------------------------------
    if ( $a{'-stopCallPause'} ) {
        $logger->debug("  $a{'-testId'} stopCallGeneration done, Sleeping for $a{'-stopCallPause'} seconds...");
        sleep ( $a{'-stopCallPause'} );
    }

    $logger->debug(" <-- Leaving Sub [1]");
    return 1;
}

#########################################################################################################

=head1 getDetailedStatistics()

DESCRIPTION:

 The function retrieves detailed statistics for given statistics type using the NAVTEL API getDetailedStats
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME     - Name of the Group to validate (i.e. Navtel_2_2 System_1 Navtel_2_1)
 2. The STATSTYPE     - Statistic type (i.e. KPI Media Signalling Summary Flows Ethernet)
 3. The INOROUTSTATS  - Incoming or Outgoing Statistics (i.e. in out)
 4. The CURORCUMSTATS - Current or Cumulative type of Statistics (i.e. cur cum)
 5. The VARIABLE      - variable in which to store the detailed Statistics.
 6. The TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _validateGroupName()
 _validateStatsType()
 execCmd()

OUTPUT:
 
 1 - Got detailed statistics
 0 - failed to get detailed statistics


EXAMPLE:

    my $flowsDetailedStatsVariable = 'FlowsInCumulative';
    unless ( $NavtelObj->getDetailedStatistics(
                           '-groupName'     => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-statsType'     => 'Flows',      # The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type
                           '-inOrOutStats'  => 'in',         # incoming or outgoing statistics
                           '-curOrCumStats' => 'cumulative', # current or cumulative type of statistics
                           '-variable'      => $flowsDetailedStatsVariable,
                           '-timeout'       => 20, # Seconds
                                                   # default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - to get detailed statistics for \'Navtel_2_1 Flows in cum\'.}";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - got detailed statistics for \'Navtel_2_1 Flows in cum\'.");

=cut

#################################################
sub getDetailedStatistics {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getDetailedStatistics()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ groupName statsType inOrOutStats curOrCumStats variable / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }
    }

    my %a = (
        '-groupName' => '',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    # Validate Group Name
    # the name of the group to retrieve statistics
    unless ( $self->_validateGroupName(
                           '-groupName' => $a{'-groupName'},
                           '-timeout'   => $a{'-timeout'},
            ) ) {
        $logger->error("  ERROR - to validate for group \'$a{'-groupName'}\', valid group names are:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->debug("  SUCCESS - group name \'$a{'-groupName'}\' is valid.");

    # Validate Statistic Type
    # the name of the table as returned by getStatsType
    unless ( $self->_validateStatsType(
                           '-statsType' => $a{'-statsType'},
                           '-timeout'   => $a{'-timeout'},
            ) ) {
        $logger->error("  ERROR - to validate for Statistic Type \'$a{'-statsType'}\', valid statsType are:--\n@{$self->{CMDRESULTS}}");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug("  SUCCESS - Statistic Type \'$a{'-statsType'}\' is valid.");

    # Validate IN or OUT type of statistics
    # incoming or outgoing statistics
    my @inOrOutTypeofStatistics = qw/ in out /;
    my $validInOrOutStatsTypeFlag = 0;
    foreach ( @inOrOutTypeofStatistics ) {
        if ( $a{'-inOrOutStats'} eq $_ ) {
            $validInOrOutStatsTypeFlag = 1;
            last;
        }
    }

    unless ( $validInOrOutStatsTypeFlag ) {
        $logger->error("  ERROR - to validate for In or Out Statistic Type \'$a{'-inOrOutStats'}\', valid inOrOutstats are:--\n@inOrOutTypeofStatistics");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->debug("  SUCCESS - In or Out Statistic Type \'$a{'-inOrOutStats'}\' is valid.");

    # Validate CURRENT or CUMULATIVE type of statistics
    my %curOrcum = (
        'current'    => { type => 'cur' },
        'cumulative' => { type => 'cum' },
        'all'        => { type => 'all' },
    );

    my @curOrCumTypeofStatistics = qw/ current cumulative all /;
    my $validCurOrCumStatsTypeFlag = 0;
    foreach ( @curOrCumTypeofStatistics ) {
        if ( $a{'-curOrCumStats'} eq $_ ) {
            $validCurOrCumStatsTypeFlag = 1;
            my $type = $curOrcum{$a{'-curOrCumStats'}}->{type};
            $a{'-curOrCumStats'} = $type;
            last;
        }
    }

    unless ( $validCurOrCumStatsTypeFlag ) {
        $logger->error("  ERROR - to validate for CURRENT or CUMULATIVE Statistic Type \'$a{'-curOrCumStats'}\', valid curOrCumStats are:--\n@curOrCumTypeofStatistics");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->debug("  SUCCESS - CURRENT or CUMULATIVE Statistic Type \'$a{'-curOrCumStats'}\' is valid.");


    my $detailedStatsCmd = "set $a{'-variable'} \[lindex \[getDetailedStats $a{'-groupName'} $a{'-statsType'} $a{'-inOrOutStats'} $a{'-curOrCumStats'}\] 1\]";
    my @detailedStats = $self->execCmd( 
                               '-cmd'     => $detailedStatsCmd,
                               '-timeout' => $a{'-timeout'},
                           );

    if ( @detailedStats ) {
        $retValue = 1; # PASS
        $logger->debug("  SUCCESS - detailed Stats is:--\n@detailedStats");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 getFlowStatisticKeyValues()

DESCRIPTION:

 The function validates the given Stats Type using the NAVTEL API getStatsType
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The VARIABLE      - variable in which statistic detailes are stored using getDetailedStatistics().
 2. The CURORCUMSTATS - Current or Cumulative type of Statistics (i.e. currrent cumulative)
 3. The FLOWNAME      - Row in Flows statistics  as seen in GUI
                        i.e. Make Call, Initiating, Error Handling, Summary,
                             481 Dialog or Transaction not Found
 4. The KEYVALUES     - Column in Flows statistics as seen in GUI
                        ( hash containing keys i.e. Column name in GUI, values shall be retrived and returned )
                        i.e. Attempted, Skipped, Failed, Started, In Process, Completed
                             Successfully Completed, UnSuccessfully Completed, Lingering
 5. The TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 STATUS
     1 - Flow Statistic value found
     0 - Flow Statistic value not found

 VALUE - value for given Row / Column


EXAMPLE:

    # Get statistics details for Flow Table - Key(s) Attempted & Completed
    my $flowsDetailedStatsVariable = 'FlowsInCumulative';
    my $flowKeyValues = {
        'Attempted' => undef,
        'Completed' => undef,
    };
    my @statKeys = keys( %{$flowKeyValues} );

    unless( $NavtelObj->getFlowStatisticKeyValues(
                           '-variable'      => $flowsDetailedStatsVariable,
                           '-curOrCumStats' => 'cumulative',
                           '-flowName'      => 'Make Call',
                           '-keyValues'     => $flowKeyValues,
                           '-timeout'       => 20, # Seconds
                                                   # default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - to get statistics VALUES for \'$statsGroupName $statsType $inOrOutStats $curOrCumStats\' - keys(@statKeys)";
        $logger->error($errMsg);
        $testStatus->{reason} = $errMsg;
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug("  SUCCESS - got statistics VALUES for \'$statsGroupName $statsType $inOrOutStats $curOrCumStats\' - keys(@statKeys)");

=cut

#################################################
sub getFlowStatisticKeyValues {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getFlowStatisticKeyValues()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ variable curOrCumStats flowName keyValues / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }
    }

    my %a = (
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my %curOrcum = (
        'current'    => { prefix => '-cur', type => 'Current' },
        'cumulative' => { prefix => '-cum', type => 'Cumulative' },
    );

    # Validate CURRENT or CUMULATIVE type of statistics
    my @curOrCumTypeofStatistics = keys (%curOrcum);
    my $validCurOrCumStatsTypeFlag = 0;
    my ( $cmdPrefix, $cmdCurOrCumType );
    foreach ( @curOrCumTypeofStatistics ) {
        if ( $a{'-curOrCumStats'} eq $_ ) {
            $validCurOrCumStatsTypeFlag = 1;
            $cmdPrefix       = $curOrcum{$_}->{prefix};
            $cmdCurOrCumType = $curOrcum{$_}->{type};
            last;
        }
    }

    unless ( $validCurOrCumStatsTypeFlag ) {
        $logger->error("  ERROR - to validate for CURRENT or CUMULATIVE Statistic Type \'$a{'-curOrCumStats'}\', valid curOrCumStats are:--\n@curOrCumTypeofStatistics");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->debug("  SUCCESS - CURRENT or CUMULATIVE Statistic Type \'$a{'-curOrCumStats'}\' is valid.");

    my %validFlowNames = (
        'Make Call'      => 'Flow60004',
        'Initiating'     => 'Flow60005',
        'Error Handling' => 'Flow65534',
        'Summary'        => 'Flow65535',
        '481 Dialog or Transaction not Found' => 'Flow18',
    );

    my %validFlowKeys = (
        # Attempted
        'Attempted'  => 'FlowAttempted',
        'Skipped'    => 'FlowSkipped',
        'Failed'     => 'FlowFailed',
        'Started'    => 'FlowStarted',

        # Completed
        'Completed'                => 'FlowCompleted',
        'Successfully Completed'   => 'FlowSuccCompleted',
        'Unsuccessfully Completed' => 'FlowUnSuccCompleted',

        'In Process' => 'FlowInProcess',
        'Lingering'  => 'FlowLingering',
    );

    my ( $tableID, $tableKEY );
    if ( exists $validFlowNames{$a{'-flowName'}} ) {
        $tableID = $validFlowNames{$a{'-flowName'}};

        # Validate all KEYs
        while ( my ($key, $value) = each( %{ $a{'-keyValues'} } ) ) {
            $a{'-keyValues'}->{$key} = undef;

            $logger->debug("  key is $key");
            if ( exists $validFlowKeys{$key} ) {
                if ( ( $key eq 'Attempted' ) || ( $key eq 'Skipped' ) ||
                     ( $key eq 'Failed' ) || ( $key eq 'Started' ) ) {
                    $tableKEY = 'Attempted' . '.' . $cmdPrefix . $validFlowKeys{$key};
                }
                elsif ( ( $key eq 'Completed' ) ||
                        ( $key eq 'Successfully Completed' ) ||
                        ( $key eq 'Unsuccessfully Completed' ) ) {
                    $tableKEY = 'Completed' . '.' . $cmdPrefix . $validFlowKeys{$key};
                }
                elsif ( ( $key eq 'In Process' ) ||
                        ( $key eq 'Lingering' ) ) {
                    $tableKEY = $cmdPrefix . $validFlowKeys{$key};
                }
                $logger->debug("  valid key($key) for flow key name \'$tableKEY\', retriving value . . .");

                my ( $statString, $cmd );
                $statString = '-Flow_GlobalStat.' . $tableID . '.' . $cmdCurOrCumType . '.Flow Statistics.' . $tableKEY;
                $cmd = 'keylkeys ' . $a{'-variable'} . ' "' . $statString . '"';

                $logger->debug("  statString - $statString.");
                $logger->debug("  cmd        - $cmd.");

                $self->execCmd( 
                       '-cmd'     => $cmd,
                       '-timeout' => $a{'-timeout'},
                );

                my $value;
                $logger->debug("  CMDRESULT:--\n@{$self->{CMDRESULTS}}\n");
                if ( @{$self->{CMDRESULTS}} ) {
                    foreach ( @{$self->{CMDRESULTS}} ) {
                        if ( /keyed list entry must be a two element list\, found \"(\d+)\"/ ) {
                        # if ( /[\S\s]+found \"(\d+)\"/ ) {
                            $a{'-keyValues'}->{$key} = $1;
                            $logger->debug("  SUCCESS - $key value is \'$a{'-keyValues'}->{$key}\'");
                            last;
                        }
                    }
                }
            } # END - valid flow key name found
        } # END - foreach (KEY)

        # check for all values
        my $undefValueFlag = 0;
        while ( my ($key, $value) = each( %{ $a{'-keyValues'} } ) ) {
            unless ( defined $value ) {
                $undefValueFlag = 1;
                $logger->debug("  UNABLE to find statistic data for KEY - \'$key\'");
            }
            else {
                $logger->debug("  FOUND statistic data for KEY - \'$key\', VALUE - \'$value\'");
            }
        }

        unless ( $undefValueFlag ) {
            $retValue = 1; # SUCCESS
        }

    }
    else {
        $logger->error("  ERROR - to validate for flow name \'$a{'-flowName'}\', valid flowName are:--\n" . keys (%validFlowNames));
    }

    unless ( $retValue ) {
        unless ( $self->haltGroup(
                           '-groupName' => '*',
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - to execute haltGroup command for group \'\*\'.";
            $logger->error($errMsg);
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 getMediaStatistics()

DESCRIPTION:

 The function gets detailed Media statistics, and then retrieves VALUE associated for each
 KEY(Row Path, Row Key & Column Key) from KEYVALUES list,
 using the NAVTEL API(s), from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. TESTID         - Test Case ID (i.e. TMS Execution Planning - Test Case ID).
 
 2. STATSGROUPNAME - The name of the group (Called/Calling) to retrieve statistics
                     i.e. Navtel_2_1
 
 3. INOROUTSTATS   - incoming or outgoing statistic type
                     i.e. 'in' or 'out'

 4. CURORCUMSTATS  - Current or Cumulative type of Statistics 
                     i.e. 'currrent' or 'cumulative'

 5. KEYVALUES      - list of Key/Value(s) to be retrieved from Media statistics as seen in GUI
                     i.e. Array of Hashes and each hash containing
                        ROW PATH - iterating through the NODE(s) as seen in the GUI,
                                    connected by '.' 
                        example: rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures.Teardown',
                        ROW KEY  - the NODE / KEY name in row as seen in the GUI
                        example: rowKey  => 'Teardown',     # i.e. NODE
                                 rowKey  => 'Inconclusive', # i.e. KEY
                        COLKEY   - the Column Name i.e. key as seen in the GUI
                        example: 'Summary', 'G.711(mu-Law)-0', 'G.711(A-Law)-0',
                                 'G.721-0', 'iLBCFamily-0', 'Unclassified'
                        VALUE    - the DATA Value shall be retrived and returned
                         
 6. TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _getStatValueUsingRowpathRowkeyColkey()

OUTPUT:
 
 STATUS
     1 - SUCCESS - retrieved Media Statistic value(s) found
     0 - FAILURE - Media Statistic value not found for one or many

 on SUCCESS - return value(s) for given Row(Path & Key)/ Column retrieved from Media Statistics
 on FAILURE - does 'haltGroup *'


EXAMPLE:

    ##############################
    # Test Case Related Data
    ##############################
    my %testSpecificData = (
        profile   => 'SBV01_24A', # Profile File Name
        groupName => '*',         # for API - runGroup(), startCallGeneration(), stopCallGeneration()
    );

    # load profile and execute following action commands:-
    # runGroup(), startCallGeneration(), stopCallGeneration()
    unless ( $NavtelObj->loadProfileExecStartStopCalls (
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
        my $errMsg = '  FAILED - loadProfileExecStartStopCalls().';
        $testStatus->{reason} = $errMsg;
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug('  SUCCESS - loadProfileExecStartStopCalls()');

    ##########################################
    # Media statistics - Key(s) & Values(s)
    ##########################################
    my $mediaKeyValues = [
        { # index 0
            rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV)',
            rowKey  => 'Audio Analysis(QOS/VQT:PV)',
            colKey  => 'Summary',
            value   => undef,
        },
        { # index 1
            rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures.Teardown',
            rowKey  => 'Teardown',
            colKey  => 'Unclassified',
            value   => undef,
        },
        { # index 2
            rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures',
            rowKey  => 'No Packets Received - Inconclusive',
            colKey  => 'Summary',
            value   => undef,
        },
    ];

    unless( $NavtelObj->getMediaStatistics(
                           '-testId'         => $TestId,
                           '-statsGroupName' => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-inOrOutStats'   => 'in',         # incoming or outgoing statistics
                           '-curOrCumStats'  => 'cumulative', # CURRENT or CUMULATIVE type of statistics
                           '-keyValues'      => $mediaKeyValues,
                           '-timeout'        => 20,           # seconds - Default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - getMediaStatistics() for \'Navtel_2_1 in cumulative\'";
        $logger->error($errMsg);
        $testStatus->{reason} = $errMsg;
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug("  SUCCESS - getMediaStatistics() for \'Navtel_2_1 in cumulative\'");

    #------------------------------------------------------------------
    # Validate statistics details for Media Table - Value(s) retrieved
    #------------------------------------------------------------------
    my $errorMsg = '';
    my ( $AudioAnalysis, $RtpFailTeardown, $RtpFailNoPktRxedIncon );
    $AudioAnalysis         = $mediaKeyValues->[0]->{value}; # Audio Analysis(QOS/VQT:PV) / Summary
    $RtpFailTeardown       = $mediaKeyValues->[1]->{value}; # Teardown / Unclassified
    $RtpFailNoPktRxedIncon = $mediaKeyValues->[2]->{value}; # No Packets Received - Inconclusive / Summary
    $logger->debug("  Successfully retrieved for Key(row - Audio Analysis, col - Summary) value - $AudioAnalysis");
    $logger->debug("  Successfully retrieved for Key(row - Teardown, col - Unclassified) value - $RtpFailTeardown");
    $logger->debug("  Successfully retrieved for Key(row - No Packets Received - Inconclusive, col - Summary) value - $RtpFailNoPktRxedIncon");

    if ( ( defined $AudioAnalysis ) &&
         ( defined $RtpFailTeardown ) &&
         ( defined $RtpFailNoPktRxedIncon ) ) {
        $testStatus->{result} = 1;
        $logger->debug('  SUCCESS - retrieved all Key/Value(s)');
    }
    else {
        $errorMsg = '  FAILED - retrieving all Key/Value(s)';
        $logger->error($errorMsg);
    }

=cut

#################################################
sub getMediaStatistics {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getMediaStatistics()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue     = 0;  # FAIL

    my $validMediaColumnKeyNames = {
        'Summary'        => 'StatView',
        'G.711(µ-Law)-0' => 'StatView0',
        'G.711(A-Law)-0' => 'StatView1',
        'G.721-0'        => 'StatView2',
        'iLBCFamily-0'   => 'StatView3',
        'Unclassified'   => 'StatView255',
    };

    $args{'-validTableIdMap'} = $validMediaColumnKeyNames;
    $args{'-statsType'}       = 'Media';

    if ( $self->_getStatValueUsingRowpathRowkeyColkey( %args ) ) {
        $retValue = 1;  # SUCCESS
    }

    $logger->debug(" <-- Leaving Sub [$retValue] - $args{'-testId'} ");
    return $retValue;
}

#########################################################################################################

=head1 getSignallingStatistics()

DESCRIPTION:

 The function gets detailed Signalling statistics, and then retrieves VALUE associated for each
 KEY(Row Path, Row Key & Column Key) from KEYVALUES list,
 using the NAVTEL API(s), from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. TESTID         - Test Case ID (i.e. TMS Execution Planning - Test Case ID).
 
 2. STATSGROUPNAME - The name of the group (Called/Calling) to retrieve statistics
                     i.e. Navtel_2_1
 
 3. INOROUTSTATS   - incoming or outgoing statistic type
                     i.e. 'in' or 'out'

 4. CURORCUMSTATS  - Current or Cumulative type of Statistics 
                     i.e. 'currrent' or 'cumulative'

 5. KEYVALUES      - list of Key/Value(s) to be retrieved from Signalling statistics as seen in GUI
                     i.e. Array of Hashes and each hash containing
                        ROW PATH - iterating through the NODE(s) as seen in the GUI,
                                    connected by '.' 
                        example: rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures.Teardown',
                        ROW KEY  - the NODE / KEY name in row as seen in the GUI
                        example: rowKey  => 'Teardown',     # i.e. NODE
                                 rowKey  => 'Inconclusive', # i.e. KEY
                        COLKEY   - the Column Name i.e. key as seen in the GUI
                        example: 'Summary', 'G.711(mu-Law)-0', 'G.711(A-Law)-0',
                                 'G.721-0', 'iLBCFamily-0', 'Unclassified'
                        VALUE    - the DATA Value shall be retrived and returned
                         
 6. TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _getStatValueUsingRowpathRowkeyColkey()

OUTPUT:
 
 STATUS
     1 - SUCCESS - retrieved Signalling Statistic value(s) found
     0 - FAILURE - Signalling Statistic value not found for one or many

 on SUCCESS - return value(s) for given Row(Path & Key)/ Column retrieved from Signalling Statistics
 on FAILURE - does 'haltGroup *'


EXAMPLE:

    ##############################
    # Test Case Related Data
    ##############################
    my %testSpecificData = (
        profile   => 'SBV01_24A', # Profile File Name
        groupName => '*',         # for API - runGroup(), startCallGeneration(), stopCallGeneration()
    );

    # load profile and execute following action commands:-
    # runGroup(), startCallGeneration(), stopCallGeneration()
    unless ( $NavtelObj->loadProfileExecStartStopCalls (
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
        my $errMsg = '  FAILED - loadProfileExecStartStopCalls().';
        $testStatus->{reason} = $errMsg;
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug('  SUCCESS - loadProfileExecStartStopCalls()');

    ##########################################
    # Signalling statistics - Key(s) & Values(s)
    ##########################################
    my $signallingKeyValues = [
        { # index 0
            rowPath => 'SIP.Outgoing Calls',
            rowKey  => 'Outgoing Calls',
            colKey  => 'Summary',
            value   => undef,
        },
        { # index 1
            rowPath => 'SIP.Outgoing Calls',
            rowKey  => 'Unsuccessful',
            colKey  => 'Summary',
            value   => undef,
        },
        { # index 2
            rowPath => 'SIP.Message Types.Retransmission.Request',
            rowKey  => 'INVITE',
            colKey  => 'Summary',
            value   => undef,
        },
    ];

    unless( $NavtelObj->getSignallingStatistics(
                           '-testId'         => $TestId,
                           '-statsGroupName' => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-inOrOutStats'   => 'out',        # incoming or outgoing statistics
                           '-curOrCumStats'  => 'cumulative', # CURRENT or CUMULATIVE type of statistics
                           '-keyValues'      => $signallingKeyValues,
                           '-timeout'        => 20,           # seconds - Default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - getSignallingStatistics() for \'Navtel_2_1 out cumulative\'";
        $logger->error($errMsg);
        $testStatus->{reason} = $errMsg;
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug("  SUCCESS - getSignallingStatistics() for \'Navtel_2_1 out cumulative\'");

    # Validate statistics details for Signalling Table - Value(s) retrieved
    my $errorMsg = '';
    my ( $SipOutgoingCalls, $SipOutgoingUnsuccessfulCalls, $SipRetranmitInvite );
    # SIP-Outgoing Calls / Summary
    $SipOutgoingCalls             = $signallingKeyValues->[0]->{value};

    # SIP-Outgoing Calls-Unsuccessful / Summary
    $SipOutgoingUnsuccessfulCalls = $signallingKeyValues->[1]->{value};

    # SIP-Message Types-Retransmission-Request-INVITE / Summary
    $SipRetranmitInvite           = $signallingKeyValues->[2]->{value};

    $logger->debug("  Successfully retrieved for Key(row - SIP-Outgoing Calls, col - Summary) value - $SipOutgoingCalls");
    $logger->debug("  Successfully retrieved for Key(row - SIP-Outgoing Calls-Unsuccessful, col - Summary) value - $SipOutgoingUnsuccessfulCalls");
    $logger->debug("  Successfully retrieved for Key(row - SIP-Message Types-Retransmission-Request-INVITE, col - Summary) value - $SipRetranmitInvite");

    if ( ( defined $SipOutgoingCalls ) &&
         ( defined $SipOutgoingUnsuccessfulCalls ) &&
         ( defined $SipRetranmitInvite ) ) {
        $testStatus->{result} = 1;
        $logger->debug('  SUCCESS - retrieved all Key/Value(s)');
    }
    else {
        $errorMsg = '  FAILED - retrieving all Key/Value(s)';
        $logger->error($errorMsg);
    }

=cut

#################################################
sub getSignallingStatistics {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getSignallingStatistics()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue     = 0;  # FAIL

    my $validSignallingColumnKeyNames = {
        'Summary'                             => 'Flow65535',
        '481 Dialog or Transaction not Found' => 'Flow18',
        'Make Call'                           => 'Flow60004',
        'Initiating'                          => 'Flow60005',
        'Error Handling'                      => 'Flow65534',
    };

    $args{'-validTableIdMap'} = $validSignallingColumnKeyNames;
    $args{'-statsType'}       = 'Signalling';

    if ( $self->_getStatValueUsingRowpathRowkeyColkey( %args ) ) {
        $retValue = 1;  # SUCCESS
    }

    $logger->debug(" <-- Leaving Sub [$retValue] - $args{'-testId'} ");
    return $retValue;
}

#########################################################################################################

=head1 getFlowStatistics()

DESCRIPTION:

 The function gets detailed Flow statistics, and then retrieves VALUE associated for each
 KEY(Row & Column Keys) from KEYVALUES list,
 using the NAVTEL API(s), from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. TESTID         - Test Case ID (i.e. TMS Execution Planning - Test Case ID).
 
 2. STATSGROUPNAME - The name of the group (Called/Calling) to retrieve statistics
                     i.e. Navtel_2_1
 
 3. INOROUTSTATS   - incoming or outgoing statistic type
                     i.e. 'in' or 'out'

 4. CURORCUMSTATS  - Current or Cumulative type of Statistics 
                     i.e. 'currrent' or 'cumulative'

 5. KEYVALUES      - list of Key/Value(s) to be retrieved from Signalling statistics as seen in GUI
                     i.e. Array of Hashes and each hash containing
                        ROW KEY  - the NODE / KEY name in row as seen in the GUI
                        example: rowKey  => 'Teardown',     # i.e. NODE
                                 rowKey  => 'Inconclusive', # i.e. KEY
                        COLKEY   - the Column Name i.e. key as seen in the GUI
                        example: 'Summary', 'G.711(mu-Law)-0', 'G.711(A-Law)-0',
                                 'G.721-0', 'iLBCFamily-0', 'Unclassified'
                        VALUE    - the DATA Value shall be retrived and returned
                         
 6. TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _getStatValueUsingRowpathRowkeyColkey()

OUTPUT:
 
 STATUS
     1 - SUCCESS - retrieved Signalling Statistic value(s) found
     0 - FAILURE - Signalling Statistic value not found for one or many

 on SUCCESS - return value(s) for given Row(Path & Key)/ Column retrieved from Signalling Statistics
 on FAILURE - does 'haltGroup *'


EXAMPLE:

   ##############################
    # Test Case Related Data
    ##############################
    my %testSpecificData = (
        profile   => 'SBV01_24A', # Profile File Name
        groupName => '*',         # for API - runGroup(), startCallGeneration(), stopCallGeneration()
    );

    #-----------------------------------------------------------
    # load profile and execute following action commands:-
    # runGroup(), startCallGeneration(), stopCallGeneration()
    #-----------------------------------------------------------
    unless ( $NavtelObj->loadProfileExecStartStopCalls (
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
        my $errMsg = '  FAILED - loadProfileExecStartStopCalls().';
        $testStatus->{reason} = $errMsg;
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug('  SUCCESS - loadProfileExecStartStopCalls()');

    ####################################################################
    # Flow statistics - Key(s) & Values(s)
    ####################################################################
    # Row Key in Flows statistics  as seen in GUI
    # i.e. Make Call, Initiating, Error Handling, Summary,
    #      481 Dialog or Transaction not Found
    #
    # Columnm Key in Flows statistics as seen in GUI
    # i.e. Attempted, Skipped, Failed, Started, In Process, Completed,
    #      Successfully Completed, UnSuccessfully Completed, Lingering
    #
    ####################################################################
    my $flowKeyValues = [
        { # index 0
            rowKey  => 'Make Call',
            colKey  => 'Attempted',
            value   => undef,
        },
        { # index 1
            rowKey  => 'Make Call',
            colKey  => 'Successfully Completed',
            value   => undef,
        },
        { # index 2
            rowKey  => 'Summary',
            colKey  => 'Completed',
            value   => undef,
        },
    ];

    #-------------------------------------------------------------------------
    # Get Flow Statistic value(s) for above given Key(s) i.e. Row/Column keys
    #-------------------------------------------------------------------------
    unless( $NavtelObj->getFlowStatistics(
                           '-testId'         => $TestId,
                           '-statsGroupName' => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-inOrOutStats'   => 'in',         # incoming or outgoing statistics
                           '-curOrCumStats'  => 'cumulative', # CURRENT or CUMULATIVE type of statistics
                           '-keyValues'      => $flowKeyValues,
                           '-timeout'        => 20,           # seconds - Default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - getFlowStatistics() for \'Navtel_2_1 in cumulative\'";
        $logger->error($errMsg);
        $testStatus->{reason} = $errMsg;
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return $testStatus;
    }
    $logger->debug("  SUCCESS - getFlowStatistics() for \'Navtel_2_1 in cumulative\'");

    #-----------------------------------------------------------------
    # Validate statistics details for Flow Table - Value(s) retrieved
    #-----------------------------------------------------------------
    my $errorMsg = '';
    my ( $AttemptedCalls, $SuccessfullyCompletedCalls, $CompletedSummary );
    # Make Call / Attempted
    $AttemptedCalls             = $flowKeyValues->[0]->{value};

    # Make Call / Successfully Completed
    $SuccessfullyCompletedCalls = $flowKeyValues->[1]->{value};

    # Summary / Completed
    $CompletedSummary           = $flowKeyValues->[2]->{value};

    $logger->debug("  Retrieved for Key(row - Make Call, col - Attempted) value - $AttemptedCalls");
    $logger->debug("  Retrieved for Key(row - Make Call, col - Successfully Completed) value - $SuccessfullyCompletedCalls");
    $logger->debug("  Retrieved for Key(row - Summary, col - Completed) value - $CompletedSummary");

    if ( ( defined $AttemptedCalls ) &&
         ( defined $SuccessfullyCompletedCalls ) &&
         ( defined $CompletedSummary ) ) {
        $logger->debug('  SUCCESS - retrieved all Key/Value(s)');

        if ( $AttemptedCalls == $SuccessfullyCompletedCalls ) {
            $logger->debug("  SUCCESS - Attempted($AttemptedCalls) matched Successfully Completed($SuccessfullyCompletedCalls) calls.");
            $testStatus->{result} = 1;
        }
        else {
            $errorMsg = "  Attempted($AttemptedCalls) mismatch Successfully Completed($SuccessfullyCompletedCalls) calls.";
            $logger->error("  FAILED - $errorMsg");
        }
    }
    else {
        $errorMsg = '  FAILED - retrieving all Key/Value(s)';
        $logger->error($errorMsg);
    } 

=cut

#################################################
sub getFlowStatistics {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getFlowStatistics()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue     = 0;  # FAIL

    my $validFlowRowKeyNames = {
        'Make Call'      => 'Flow60004',
        'Initiating'     => 'Flow60005',
        'Error Handling' => 'Flow65534',
        'Summary'        => 'Flow65535',
        '481 Dialog or Transaction not Found' => 'Flow18',
    };

    my $validFlowColKeys = {
        # Attempted
        'Attempted'  => 'FlowAttempted',
        'Skipped'    => 'FlowSkipped',
        'Failed'     => 'FlowFailed',
        'Started'    => 'FlowStarted',

        # Completed
        'Completed'                => 'FlowCompleted',
        'Successfully Completed'   => 'FlowSuccCompleted',
        'Unsuccessfully Completed' => 'FlowUnSuccCompleted',

        'In Process' => 'FlowInProcess',
        'Lingering'  => 'FlowLingering',
    };

    $args{'-validTableIdMap'} = $validFlowRowKeyNames;
    $args{'-validColumnKeys'} = $validFlowColKeys;
    $args{'-statsType'}       = 'Flow';

    if ( $self->_getStatValueUsingRowkeyColkey( %args ) ) {
        $retValue = 1;  # SUCCESS
    }

    $logger->debug(" <-- Leaving Sub [$retValue] - $args{'-testId'} ");
    return $retValue;
}

#########################################################################################################

=head1 _validateGroupName()

DESCRIPTION:

 The function validates the given Group Name using the NAVTEL API getAllGroup
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME - Name of the Group to validate
                    i.e. Navtel_2_2 System_1 Navtel_2_1
 2. The TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - valid Group Name found
 0 - invalid Group Name or Group name not found


EXAMPLE:

    my $groupName = 'Navtel_2_1';  # i.e. group name to be validated
    unless ( $NavtelObj->_validateGroupName(
                           '-groupName' => $groupName,
                           '-timeout'   => 20, # Seconds
                                               # default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - to validate for group \'$groupName\', valid group names are:--\n@{$NavtelObj->{CMDRESULTS}}";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - group name \'$groupName\' is valid.");

=cut

#################################################
sub _validateGroupName {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_validateGroupName()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL
    my $validGroupNameFlag = 0; # FALSE

    # Check Mandatory Parameters
    foreach ( qw/ groupName / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-groupName' => '',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my $cmd = 'getAllGroups';
    my @validGroupNames = $self->execCmd( 
                               '-cmd'     => $cmd,
                               '-timeout' => $a{'-timeout'},
                           );

    if ( @validGroupNames ) {
        # Check valid Group Name
        foreach my $groupName ( @validGroupNames ) {
            if ( $groupName =~ /$a{'-groupName'}/ ) {
                $validGroupNameFlag = 1; # TRUE
                $retValue           = 1; # PASS
                last;
            }
        }

        unless ( $validGroupNameFlag ) {
            $logger->error("  ERROR: Invalid Group Name ($a{'-groupName'}) used, Valid:--\n@validGroupNames.");
        }
    }
    else { # Empty Array
        $logger->error("  ERROR: unable to get valid Group Names using command \'$cmd\':--\n@validGroupNames.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 _validateStatsType()

DESCRIPTION:

 The function validates the given Stats Type using the NAVTEL API getStatsType
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The STATSTYPE - Statistic type (KPI Media Signalling Summary Flows Ethernet)
 2. The TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - valid Statistic Type found
 0 - invalid Statistic Type not found


EXAMPLE:

    my $statsType = 'Flows';  # i.e. Statistic Type to be validated
    unless ( $NavtelObj->_validateStatsType(
                           '-statsType' => $statsType,
                           '-timeout'   => 20, # Seconds
                                               # default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - to validate for Statistic Type \'$statsType\', valid statsType are:--\n@{$NavtelObj->{CMDRESULTS}}";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - Statistic Type \'$statsType\' is valid.");

=cut

#################################################
sub _validateStatsType {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_validateStatsType()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL
    my $validStatsTypeFlag = 0; # FALSE

    # Check Mandatory Parameters
    foreach ( qw/ statsType / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-statsType' => '',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my $cmd = 'getStatsType';
    my @validStatsTypes = $self->execCmd( 
                               '-cmd'     => $cmd,
                               '-timeout' => $a{'-timeout'},
                           );

    if ( @validStatsTypes ) {
        # Check valid Statistic Type
        foreach my $statsType ( @validStatsTypes ) {
            if ( $statsType =~ /$a{'-statsType'}/ ) {
                $validStatsTypeFlag = 1; # TRUE
                $retValue           = 1; # PASS
                last;
            }
        }

        unless ( $validStatsTypeFlag ) {
            $logger->error("  ERROR: Invalid Statistic Type ($a{'-statsType'}) used, Valid:--\n@validStatsTypes.");
        }
    }
    else { # Empty Array
        $logger->error("  ERROR: unable to get valid Statistic Type using command \'$cmd\':--\n@validStatsTypes.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 _getKeyNameLookupList()

DESCRIPTION:

 The function retrieves Key-Name lookup list for given statistics type using the NAVTEL API getKeyNameLookup
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The STATSTYPE  - Statistic type (i.e. KPI Media Signalling Summary Flows Ethernet)
 2. The VARIABLE   - variable in which to store the Key-Name list using getKeyNameLookup() Navtel API.
 3. The TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - Got Key-Name lookup list
 0 - failed to get Key-Name lookup list


EXAMPLE:

    unless ( $self->_getKeyNameLookupList(
                           '-statsType' => 'Media', # The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type
                           '-variable'  => $MediaNameLookupVariable,
                           '-timeout'   => 20,      # Seconds - default is 10 seconds
            ) ) {
        $logger->error("  FAILED - to get Key-Name lookup list for \'Media\'");
        return 0;
    }
    $logger->debug("  SUCCESS -  retrieved Key-Name lookup list for \'Media\'.");

=cut

#################################################
sub _getKeyNameLookupList {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_getKeyNameLookupList()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ statsType variable / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }
    }

    my %a = (
        '-groupName' => '',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    # Validate Statistic Type - already verified in getDetailedStatistics()
    # The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type

    # set '.$variableNameKVList.' [lindex [getKeyNameLookup Media] 1]';
    my $getKeyNameLookupCmd = "set $a{'-variable'} \[lindex \[getKeyNameLookup $a{'-statsType'}\] 1\]";
    my @keyNameLookupList = $self->execCmd( 
                               '-cmd'     => $getKeyNameLookupCmd,
                               '-timeout' => $a{'-timeout'},
                           );

    if ( @keyNameLookupList ) {
        $logger->debug("  SUCCESS - executed getKeyNameLookup() using cmd \'$getKeyNameLookupCmd\'");
        $retValue = 1; # PASS
    }
    else {
        $logger->error("  ERROR - failed to getKeyNameLookup() using cmd \'$getKeyNameLookupCmd\'");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 _getStatValueUsingRowpathRowkeyColkey()

DESCRIPTION:

 The function gets detailed Media statistics, and then retrieves VALUE associated for each
 KEY(Row Path, Row Key & Column Key) from KEYVALUES list,
 using the NAVTEL API(s), from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. TESTID         - Test Case ID (i.e. TMS Execution Planning - Test Case ID).

 2. STATSTYPE      - Statistic type (KPI Media Signalling Summary Flows Ethernet)
 
 3. STATSGROUPNAME - The name of the group (Called/Calling) to retrieve statistics
                     i.e. Navtel_2_1
 
 4. INOROUTSTATS   - incoming or outgoing statistic type
                     i.e. 'in' or 'out'

 5. CURORCUMSTATS  - Current or Cumulative type of Statistics 
                     i.e. 'currrent' or 'cumulative'

 6. KEYVALUES      - list of Key/Value(s) to be retrieved from Media statistics as seen in GUI
                     i.e. Array of Hashes and each hash containing
                        ROW PATH - iterating through the NODE(s) as seen in the GUI,
                                    connected by '.' 
                        example: rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures.Teardown',
                        ROW KEY  - the NODE / KEY name in row as seen in the GUI
                        example: rowKey  => 'Teardown',     # i.e. NODE
                                 rowKey  => 'Inconclusive', # i.e. KEY
                        COLKEY   - the Column Name i.e. key as seen in the GUI
                        example: 'Summary', 'G.711(mu-Law)-0', 'G.711(A-Law)-0',
                                 'G.721-0', 'iLBCFamily-0', 'Unclassified'
                        VALUE    - the DATA Value shall be retrived and returned
                         
 7. VALIDTABLEIDMAP - Mapping of Column Key to DB Table ID (i.e. Hash)

 8. TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 getDetailedStatistics()
 _getKeyNameLookupList()
 execCliCmd()
 execCmd()

OUTPUT:
 
 STATUS
     1 - SUCCESS - retrieved Statistic value(s) found
     0 - FAILURE - Statistic value not found for one or many

 on SUCCESS - return value(s) for given Row(Path & Key)/ Column retrieved from Media Statistics
 on FAILURE - does 'haltGroup *'


EXAMPLE:

    unless( $self->_getStatValueUsingRowpathRowkeyColkey(
                           '-testId'          => $TestId,
                           '-statsType'       => 'Media',
                           '-statsGroupName'  => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-inOrOutStats'    => 'in',         # incoming or outgoing statistics
                           '-curOrCumStats'   => 'cumulative', # CURRENT or CUMULATIVE type of statistics
                           '-keyValues'       => $mediaKeyValues,
                           '-validTableIdMap' => $validMediaColumnKeyNames;
                           '-timeout'         => 20,           # seconds - Default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - _getStatValueUsingRowpathRowkeyColkey() for \'Navtel_2_1 in cumulative\'";
        $logger->error($errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - _getStatValueUsingRowpathRowkeyColkey() for \'Navtel_2_1 in cumulative\'");

=cut

#################################################
sub _getStatValueUsingRowpathRowkeyColkey {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_getStatValueUsingRowpathRowkeyColkey()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue     = 0;  # FAIL
    my $funcFailFlag = 0;  # Function Return Successful (i.e. 0)
    my $errMsg       = (); # Debug - Error Print Message

    #############################################
    # Check Mandatory Parameters
    #############################################
    foreach ( qw/ testId statsGroupName inOrOutStats curOrCumStats keyValues validTableIdMap statsType / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            $funcFailFlag = 1; # Function Return Failure(i.e. 1)
        }
    }

    my %a = (
        '-detailedStatsVariable'  => "$args{'-statsType'}".'DetailedStats',
        '-keyNameLookupVariable'  => "$args{'-statsType'}".'KeyNameLookup',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my %curOrcumStats = (
        'current'    => 'Current',
        'cumulative' => 'Cumulative',
    );

    my $cmdCurOrCumType = $curOrcumStats{$a{'-curOrCumStats'}};

    my %inOroutStats = (
        'in'  => 'Incoming',
        'out' => 'Outgoing',
    );

    my $cmdInOrOutType = $inOroutStats{$a{'-inOrOutStats'}};

    unless ( $funcFailFlag ) {
        #---------------------------------------------------
        # Get detailed statistics related to data provided,
        # and save it to given variable
        #---------------------------------------------------
        unless ( $self->getDetailedStatistics(
                           '-groupName'     => $a{'-statsGroupName'},
                           '-statsType'     => $a{'-statsType'},
                           '-inOrOutStats'  => $a{'-inOrOutStats'},
                           '-curOrCumStats' => $a{'-curOrCumStats'},
                           '-variable'      => $a{'-detailedStatsVariable'},
                           '-timeout'       => $a{'-timeout'}, # Seconds
                                                   # default is 10 seconds
            ) ) {
            $errMsg = "  FAILED - $a{'-testId'} to get detailed statistics for \'$a{'-statsGroupName'} $a{'-statsType'} $a{'-inOrOutStats'} $a{'-curOrCumStats'}\'";
            $logger->error($errMsg);
    
            $funcFailFlag = 1; # Function Return Failure(i.e. 1)
        }
    }

    unless ( $funcFailFlag ) {
        $logger->debug("  SUCCESS - $a{'-testId'} got detailed statistics for \'$a{'-statsGroupName'} $a{'-statsType'} $a{'-inOrOutStats'} $a{'-curOrCumStats'}\'.");

        #-----------------------------------------------------------
        # Get statistics NAME key value list to Variable
        #-----------------------------------------------------------
        unless ( $self->_getKeyNameLookupList(
                           '-statsType' => $a{'-statsType'}, # The statistics (i.e. KPI Media Signalling Summary Flows Ethernet) type
                           '-variable'  => $a{'-keyNameLookupVariable'},
                           '-timeout'   => 20,      # Seconds - default is 10 seconds
                ) ) {
            $errMsg = "  FAILED - $a{'-testId'} to get Key-Name lookup list for stats type \'$a{'-statsType'}\'";
            $logger->error($errMsg);
            $funcFailFlag = 1; # Function Return Failure(i.e. 1)
        }
    }

    unless ( $funcFailFlag ) {
        $logger->debug("  SUCCESS - $a{'-testId'} retrieved Key-Name lookup list for stats type \'$a{'-statsType'}\'.");

        my $index = 0;
        foreach my $keyRef ( @{ $a{'-keyValues'} } ) {
            my ( $rowPath, $rowKey, $colKey );
            $rowPath = $keyRef->{rowPath};
            $rowKey  = $keyRef->{rowKey};
            $colKey  = $keyRef->{colKey};

            # initalise the value - undef
            $a{'-keyValues'}->[$index]->{value} = undef;

            #-----------------------------------------------------------
            # execute 'keylget' for given ROW PATH
            #-----------------------------------------------------------
            my $variableOutList    = $a{'-statsType'} . 'KeyOutList' . $index;

            my $colID = $a{'-validTableIdMap'}->{'Summary'};
            my $cmd;
            if ( $a{'-statsType'} eq 'Media' ) {
                $cmd   = 'keylget '.$a{'-keyNameLookupVariable'}.' "-'.$a{'-statsType'}.'_GlobalStat.'.$colID.'.'.$cmdCurOrCumType.'.'.$rowPath.'" '.$variableOutList;
            }
            elsif ( $a{'-statsType'} eq 'Signalling' ) {
                $cmd   = 'keylget '.$a{'-keyNameLookupVariable'}.' "-'.$a{'-statsType'}.'_GlobalStat.'.$cmdCurOrCumType.'.'.$cmdInOrOutType.'.'.$rowPath.'" '.$variableOutList;
            }

            unless ( $self->execCliCmd( 
                               '-cmd'     => $cmd,
                               '-timeout' => $a{'-timeout'},
                            ) ) {
                $errMsg = "  ERROR - $a{'-testId'} index($index) failed to exec CLI cmd \'$cmd\'";
                $logger->error($errMsg);
                $funcFailFlag = 1; # Function Return Failure(i.e. 1)
                last;
            }
            $logger->debug("  SUCCESS - $a{'-testId'} index($index) executed CLI cmd \'$cmd\'");

            #-----------------------------------------------------------
            # Retrieve the list of ROW KEY(s) / Database KeyId(s)
            #-----------------------------------------------------------
            $cmd = 'dumpKeyedList $'.$variableOutList;
            $self->execCmd( 
                           '-cmd'     => $cmd,
                           '-timeout' => $a{'-timeout'},
            );

            unless ( @{$self->{CMDRESULTS}} ) {
                $errMsg = "  ERROR - $a{'-testId'} index($index) failed to exec cmd \'$cmd\'";
                $logger->error($errMsg);
                $funcFailFlag = 1; # Function Return Failure(i.e. 1)
                last;
            }
            $logger->debug("  SUCCESS - $a{'-testId'} index($index) executed cmd \'$cmd\', CMDRESULT:--\n@{$self->{CMDRESULTS}}\n");

            #-----------------------------------------------------------
            # search for ROW KEY in retrieved list and
            # get Database Key ID for given ROW KEY.
            #-----------------------------------------------------------
            my %rowKeyKeyIdMap;
            my $leadSpaceCount;
            foreach ( @{$self->{CMDRESULTS}} ) {
                unless( defined $leadSpaceCount ) {
                    if( /^(\s*)/ && length($1) ) {
                        $leadSpaceCount = length($1);
                    }
                }

                if ( /^(\s*)(\-\S+)\s\-\s([\S\s]+)$/ ) {
                    my ( $key, $keyID );
                    $keyID = $2;
                    $key   = $3;
                    if( length($1) == $leadSpaceCount ) {
                        $rowKeyKeyIdMap{$key} = $keyID;
                        $logger->debug("  $a{'-testId'} index($index) FOUND - key($key) and Database keyId($keyID)\n");
                    }
    
                    if ( $rowKey eq $key ) {
                        # found ROWKEY and associated KEYID
                        $keyRef->{keyId} = $keyID;
                        $logger->debug("  SUCCESS - $a{'-testId'} index($index) for rowKey($rowKey) found Database keyId \'$keyRef->{keyId}\'");
                    }
                }
            }

            ############################################################
            # fetch Key Value from variable provided
            ############################################################
            unless ( defined $keyRef->{keyId} ) {
                $errMsg = "  ERROR - $a{'-testId'} index($index) failed to exec cmd \'$cmd\'";
                $logger->error($errMsg);
                $funcFailFlag = 1; # Function Return Failure(i.e. 1)
                $logger->debug(' <-- Leaving Sub [0]');
                return $retValue;
            }
            $logger->debug("  SUCCESS - $a{'-testId'} index($index) found KEYID \'$keyRef->{keyId}\' for rowKey($rowKey) colKey($colKey)");

            my $statString;
            if ( $a{'-statsType'} eq 'Media' ) {
                $statString = '-'.$a{'-statsType'}.'_GlobalStat.'.$colID.'.'.$cmdCurOrCumType.'.'.$rowPath.'.'.$keyRef->{keyId};
            }
            elsif ( $a{'-statsType'} eq 'Signalling' ) {
                $statString = '-'.$a{'-statsType'}.'_GlobalStat.'.$colID.'.'.$cmdCurOrCumType.'.'.$cmdInOrOutType.'.'.$rowPath.'.'.$keyRef->{keyId};
            }

            $cmd = 'keylkeys '.$a{'-detailedStatsVariable'}.' "'.$statString.'"';

            $logger->debug("  $a{'-testId'} - index($index) statString - $statString.");
            $logger->debug("  $a{'-testId'} - index($index) cmd        - $cmd.");

            $self->execCmd( 
                       '-cmd'     => $cmd,
                       '-timeout' => $a{'-timeout'},
            );

            my $value;
            $logger->debug("  $a{'-testId'} index($index) executed cmd \'$cmd\', CMDRESULT:--\n@{$self->{CMDRESULTS}}\n");
            if ( @{$self->{CMDRESULTS}} ) {
                foreach ( @{$self->{CMDRESULTS}} ) {
                    if ( /keyed list entry must be a two element list\, found \"([\S\s]+)\"/ ) {
                        $a{'-keyValues'}->[$index]->{value} = $1;
                        $logger->debug("  SUCCESS - $a{'-testId'} index($index) value is \'$a{'-keyValues'}->[$index]->{value}\', \$1 ($1)");
                        last;
                    }
                    elsif ( /key not found\:\s+\"([\S\s]+)\"/i ) {
                        $logger->error("  FAILED - $a{'-testId'} index($index) unable to retrieve value for DB key \'$1\'");
                        last;
                    }
                }
            }

            $index++;
        } # FOREACH - END
    } # UNLESS - END - Function Return Failure(i.e. 1)
    
    unless ( $funcFailFlag ) {
        # check for all values
        my $undefValueFlag = 0;
        my $index = 0;
        foreach my $keyRef ( @{ $a{'-keyValues'} } ) {
            unless ( defined $keyRef->{value} ) {
                $undefValueFlag = 1;
                $logger->error("  $a{'-testId'} index($index) UNABLE to find statistic data for rowKey($keyRef->{rowKey}) colKey($keyRef->{colKey})");
            }
            else {
                $logger->debug("  $a{'-testId'} index($index) FOUND statistic data for rowKey($keyRef->{rowKey}) colKey($keyRef->{colKey}), VALUE - \'$keyRef->{value}\'");
            }
    
            $index++;
        }

        unless ( $undefValueFlag ) {
            $retValue = 1; # SUCCESS
        }
    }

    unless ( $retValue ) {
        unless ( $self->haltGroup(
                           '-groupName' => '*',
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - $a{'-testId'} to execute haltGroup command for group \'\*\'.";
            $logger->error($errMsg);
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue] - $a{'-testId'} ");
    return $retValue;
}

#########################################################################################################

=head1 _getStatValueUsingRowkeyColkey()

DESCRIPTION:

 The function gets detailed Media statistics, and then retrieves VALUE associated for each
 KEY(Row Path, Row Key & Column Key) from KEYVALUES list,
 using the NAVTEL API(s), from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. TESTID         - Test Case ID (i.e. TMS Execution Planning - Test Case ID).

 2. STATSTYPE      - Statistic type (KPI Media Signalling Summary Flows Ethernet)
 
 3. STATSGROUPNAME - The name of the group (Called/Calling) to retrieve statistics
                     i.e. Navtel_2_1
 
 4. INOROUTSTATS   - incoming or outgoing statistic type
                     i.e. 'in' or 'out'

 5. CURORCUMSTATS  - Current or Cumulative type of Statistics 
                     i.e. 'currrent' or 'cumulative'

 6. KEYVALUES      - list of Key/Value(s) to be retrieved from Media statistics as seen in GUI
                     i.e. Array of Hashes and each hash containing
                        ROW PATH - iterating through the NODE(s) as seen in the GUI,
                                    connected by '.' 
                        example: rowPath => 'Incoming.Audio Analysis(QOS/VQT:PV).RTP PV - Active.Failures.Teardown',
                        ROW KEY  - the NODE / KEY name in row as seen in the GUI
                        example: rowKey  => 'Teardown',     # i.e. NODE
                                 rowKey  => 'Inconclusive', # i.e. KEY
                        COLKEY   - the Column Name i.e. key as seen in the GUI
                        example: 'Summary', 'G.711(mu-Law)-0', 'G.711(A-Law)-0',
                                 'G.721-0', 'iLBCFamily-0', 'Unclassified'
                        VALUE    - the DATA Value shall be retrived and returned
                         
 7. VALIDTABLEIDMAP - Mapping of Column Key to DB Table ID (i.e. Hash)

 8. TIMEOUT for executing NAVTEL command API (Optional - default 10 seconds)

PACKAGE:

 SonusQA::NAVTELSTATSHELPER

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 getDetailedStatistics()
 _getKeyNameLookupList()
 execCliCmd()
 execCmd()

OUTPUT:
 
 STATUS
     1 - SUCCESS - retrieved Statistic value(s) found
     0 - FAILURE - Statistic value not found for one or many

 on SUCCESS - return value(s) for given Row(Path & Key)/ Column retrieved from Media Statistics
 on FAILURE - does 'haltGroup *'


EXAMPLE:

    unless( $self->_getStatValueUsingRowkeyColkey(
                           '-testId'          => $TestId,
                           '-statsType'       => 'Media',
                           '-statsGroupName'  => 'Navtel_2_1', # The name of the group to retrieve statistics
                           '-inOrOutStats'    => 'in',         # incoming or outgoing statistics
                           '-curOrCumStats'   => 'cumulative', # CURRENT or CUMULATIVE type of statistics
                           '-keyValues'       => $mediaKeyValues,
                           '-validTableIdMap' => $validMediaColumnKeyNames;
                           '-timeout'         => 20,           # seconds - Default is 10 seconds
            ) ) {
        my $errMsg = "  FAILED - _getStatValueUsingRowkeyColkey() for \'Navtel_2_1 in cumulative\'";
        $logger->error($errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - _getStatValueUsingRowkeyColkey() for \'Navtel_2_1 in cumulative\'");

=cut

#################################################
sub _getStatValueUsingRowkeyColkey {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_getStatValueUsingRowkeyColkey()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue     = 0;  # FAIL
    my $funcFailFlag = 0;  # Function Return Successful (i.e. 0)
    my $errMsg       = (); # Debug - Error Print Message

    #############################################
    # Check Mandatory Parameters
    #############################################
    foreach ( qw/ testId statsGroupName inOrOutStats curOrCumStats keyValues validTableIdMap validColumnKeys statsType / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(' <-- Leaving Sub [0]');
            $funcFailFlag = 1; # Function Return Failure(i.e. 1)
        }
    }

    my %a = (
        '-detailedStatsVariable'  => "$args{'-statsType'}".'DetailedStats',
        '-timeout'   => $self->{DEFAULTTIMEOUT}, # Default is 10 seconds
    );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my ( %curOrcumStats, $cmdCurOrCumType );
    %curOrcumStats = (
        'current'    => 'Current',
        'cumulative' => 'Cumulative',
    );
    $cmdCurOrCumType = $curOrcumStats{$a{'-curOrCumStats'}};

    my ( %curOrcumPrefix, $cmdCurOrCumPrefix );
    %curOrcumPrefix = (
        'current'    => '-cur',
        'cumulative' => '-cum',
    );
    $cmdCurOrCumPrefix = $curOrcumPrefix{$a{'-curOrCumStats'}};

    my ( %inOroutStats, $cmdInOrOutType );
    %inOroutStats = (
        'in'  => 'Incoming',
        'out' => 'Outgoing',
    );
    $cmdInOrOutType = $inOroutStats{$a{'-inOrOutStats'}};

    unless ( $funcFailFlag ) {
        #---------------------------------------------------
        # Get detailed statistics related to data provided,
        # and save it to given variable
        #---------------------------------------------------
        unless ( $self->getDetailedStatistics(
                           '-groupName'     => $a{'-statsGroupName'},
                           '-statsType'     => $a{'-statsType'},
                           '-inOrOutStats'  => $a{'-inOrOutStats'},
                           '-curOrCumStats' => $a{'-curOrCumStats'},
                           '-variable'      => $a{'-detailedStatsVariable'},
                           '-timeout'       => $a{'-timeout'}, # Seconds
                                                   # default is 10 seconds
            ) ) {
            $errMsg = "  FAILED - $a{'-testId'} to get detailed statistics for \'$a{'-statsGroupName'} $a{'-statsType'} $a{'-inOrOutStats'} $a{'-curOrCumStats'}\'";
            $logger->error($errMsg);
    
            $funcFailFlag = 1; # Function Return Failure(i.e. 1)
        }
        else {
            $logger->debug("  SUCCESS - $a{'-testId'} got detailed statistics for \'$a{'-statsGroupName'} $a{'-statsType'} $a{'-inOrOutStats'} $a{'-curOrCumStats'}\'.");
        }
    }

    unless ( $funcFailFlag ) {

        my $index = 0;
        foreach my $keyRef ( @{ $a{'-keyValues'} } ) {
            my ( $rowKey, $rowKeyId, $colKey, $dbColKey );
            $rowKey  = $keyRef->{rowKey};
            $colKey  = $keyRef->{colKey};

            # initalise the value - undef
            $a{'-keyValues'}->[$index]->{value} = undef;

            #-----------------------------------------------------------
            # Retrieve the Row KEY ID i.e. Database tabele Id
            #-----------------------------------------------------------
            $rowKeyId = $a{'-validTableIdMap'}->{$rowKey};

            #-----------------------------------------------------------
            # Retrieve the list of COLUMN KEY
            #-----------------------------------------------------------
            $logger->debug("  Retrieving Database Column Key ID for Column key ($colKey)");
            if ( exists $a{'-validColumnKeys'}->{$colKey} ) {
                if ( ( $colKey eq 'Attempted' ) || ( $colKey eq 'Skipped' ) ||
                     ( $colKey eq 'Failed' ) || ( $colKey eq 'Started' ) ) {
                    $dbColKey = 'Attempted' . '.' . $cmdCurOrCumPrefix . $a{'-validColumnKeys'}->{$colKey};
                }
                elsif ( ( $colKey eq 'Completed' ) ||
                        ( $colKey eq 'Successfully Completed' ) ||
                        ( $colKey eq 'Unsuccessfully Completed' ) ) {
                    $dbColKey = 'Completed' . '.' . $cmdCurOrCumPrefix . $a{'-validColumnKeys'}->{$colKey};
                }
                elsif ( ( $colKey eq 'In Process' ) ||
                        ( $colKey eq 'Lingering' ) ) {
                    $dbColKey = $cmdCurOrCumPrefix . $a{'-validColumnKeys'}->{$colKey};
                }
                $logger->debug("  SUCCESS - $a{'-testId'} index($index) retrieved for Column Key($colKey) database Column Key \'$dbColKey\', retriving value . . .");
            }
            else {
                my @validColKeys = keys %{$a{'-validColumnKeys'}};
                $errMsg = "  FAILED - $a{'-testId'} index($index) invalid Column Key($colKey), valid keys are:--\n@validColKeys\n";
                $logger->error($errMsg);

                $funcFailFlag = 1; # Function Return Failure(i.e. 1)
            }
            
            unless ( $funcFailFlag ) {
                #-----------------------------------------------------------
                # fetch Key Value from variable provided
                #-----------------------------------------------------------
                my ( $statString, $cmd );
                $statString = '-'.$a{'-statsType'}.'_GlobalStat.'.$rowKeyId.'.'.$cmdCurOrCumType.'.'.$a{'-statsType'}.' Statistics.'.$dbColKey;

                $cmd = 'keylkeys '.$a{'-detailedStatsVariable'}.' "'.$statString.'"';

                $logger->debug("  $a{'-testId'} - index($index) statString - $statString.");
                $logger->debug("  $a{'-testId'} - index($index) cmd        - $cmd.");

                $self->execCmd( 
                       '-cmd'     => $cmd,
                       '-timeout' => $a{'-timeout'},
                );

                my $value;
                $logger->debug("  $a{'-testId'} index($index) executed cmd \'$cmd\', CMDRESULT:--\n@{$self->{CMDRESULTS}}\n");
                if ( @{$self->{CMDRESULTS}} ) {
                    foreach ( @{$self->{CMDRESULTS}} ) {
                        if ( /keyed list entry must be a two element list\, found \"([\S\s]+)\"/ ) {
                            $a{'-keyValues'}->[$index]->{value} = $1;
                            $logger->debug("  SUCCESS - $a{'-testId'} index($index) value is \'$a{'-keyValues'}->[$index]->{value}\', \$1 ($1)");
                            last;
                        }
                        elsif ( /key not found\:\s+\"([\S\s]+)\"/i ) {
                            $logger->error("  FAILED - $a{'-testId'} index($index) unable to retrieve value for DB key \'$1\'");
                            last;
                        }
                    }
                }
                else {
                    $errMsg = "  FAILED - $a{'-testId'} index($index) while trying to fetch statistic value, command output is EMPTY, cmd \'$cmd\'";
                    $logger->error($errMsg);
                }
            } # UNLESS - END - Function Error

            $index++;
        } # FOREACH - END
    } # UNLESS - END - Function Return Failure(i.e. 1)
    
    unless ( $funcFailFlag ) {
        #------------------------
        # check for all values
        #------------------------
        my $undefValueFlag = 0;
        my $index = 0;
        foreach my $keyRef ( @{ $a{'-keyValues'} } ) {
            unless ( defined $keyRef->{value} ) {
                $undefValueFlag = 1;
                $logger->error("  $a{'-testId'} index($index) UNABLE to find statistic data for rowKey($keyRef->{rowKey}) colKey($keyRef->{colKey})");
            }
            else {
                $logger->debug("  $a{'-testId'} index($index) FOUND statistic data for rowKey($keyRef->{rowKey}) colKey($keyRef->{colKey}), VALUE - \'$keyRef->{value}\'");
            }
    
            $index++;
        }

        unless ( $undefValueFlag ) {
            $retValue = 1; # SUCCESS
        }
    }

    unless ( $retValue ) {
        unless ( $self->haltGroup(
                           '-groupName' => '*',
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
            my $errMsg = "  FAILED - $a{'-testId'} to execute haltGroup command for group \'\*\'.";
            $logger->error($errMsg);
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue] - $a{'-testId'} ");
    return $retValue;
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
##########################################################################################################
sub exportStatistics
##########################################################################################################
{
    my ($self,$NavtelStatisticsDir,@NavtelStats) = @_;
    my $sub = "exportNavtelStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ .".$sub");
    my $statsType;
    foreach $statsType (@NavtelStats)
    {
	$logger->info(__PACKAGE__ . ".$sub, StatsType: [$statsType]");
	if (($statsType =~ /^Signalling/) || ($statsType =~ /^Media/) || ($statsType =~ /^KPI/) || ($statsType =~ /^Ethernet/) || ($statsType =~ /^CallRecord/))
	{
	    unless ( $self->execCliCmd(
                            '-cmd'     => "exportStats $statsType $NavtelStatisticsDir /header short /oneFilePerGroup /noMergeInOut ",
                            '-timeout' => 30,
                        ) ) {
		my $errMessage = "  FAILED - Could not execute CLI command for Exporting [$statsType] Stats ";
		$logger->error("$errMessage");
		next;
	    }
	    $logger->debug("  SUCCESS - Executed CLI command for Exporting [$statsType] Stats ");

	}
	else{
	    $logger->error(__PACKAGE__ . ".$sub Invalid StatsType [$statsType]...");
	}

    }    	
}
1;
__END__
