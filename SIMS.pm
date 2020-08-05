package SonusQA::SIMS;
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

2011-01-19

=cut

#########################################################################################################
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;
use Switch;

our $VERSION = '1.0';
use vars qw($self %sessionDetails %eventLogFileTypeDetails %signallingSbxPort);
our @ISA = qw(Exporter SonusQA::Base SonusQA::SIMS::SIMSHELPER);

our %EXPORT_TAGS = ( 'all' => [ qw(
    newFromAlias
    setSystem
    execCmd
    execShellCmd
    execCliCmd
    execCommitCliCmd
    enterConfigureMode
    leaveConfigureMode
    enterLinuxShellViaDsh
    enterLinuxShellViaDshBecomeRoot
    leaveDSHtoAdminMode
    leaveSUtoAdminMode
    getCurrentEventLogFile
    getSimsCurrentEventLogFiles
    rollOverSimsEventLogFilesNow
    rollOverEventLogFile
    parseLogFile
    clearCoreFiles
    checkForCoreFiles
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
    newFromAlias
    setSystem
    execCmd
    execShellCmd
    execCliCmd
    execCommitCliCmd
    enterConfigureMode
    leaveConfigureMode
    enterLinuxShellViaDsh
    enterLinuxShellViaDshBecomeRoot
    leaveDSHtoAdminMode
    leaveSUtoAdminMode
    getCurrentEventLogFile
    getSimsCurrentEventLogFiles
    rollOverSimsEventLogFilesNow
    rollOverEventLogFile
    parseLogFile
    clearCoreFiles
    checkForCoreFiles
);

#########################################################################################################

=head1 NAME

 SonusQA::SIMS - Perl module for Sonus Networks SIMS interaction

=head1 SYNOPSIS

 use ATS;

   or:

 use SonusQA::SIMS;

=head1 DESCRIPTION

 SonusQA::SIMS provides a common interface for SIMS objects.

=head1 AUTHORS

 The <SonusQA::SIMS> module has been created Thangaraj Arumugachamy <tarmugasamy@sonusnet.com>,
 alternatively contact <sonus-auto-core@sonusnet.com>.
 See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

#########################################################################################################

=head1 newFromAlias()

DESCRIPTION: 

 This function attempts to resolve the TMS Test Bed Management alias passed in as the first argument
 and creates an instance of the ATS object based on the object type passed in as the second argument.
 This argument is optional. If not specified the OBJTYPE will be looked up from TMS. As an additional
 check it will double check that the OBJTYPE in TMS corresponds with the user's entry. If not it will
 error. It will also add the TMS alias data to the object as well as the resolved alias name.
 It will return the ATS object if successful or undef otherwise. In addition, if the user specifies
 extra flags not recognised by newFromAlias, these will all be passed to Base::new on creation of
 the session object. That subroutine will handle the parsing of those arguments.
 This is primarily to enable the user to override default flags.

ARGUMENTS:

 Specific to newFromAlias:
    -tms_alias => TMS alias string
   [-obj_type => ATS object type string]
   [-target_instance =>  Optional 3rd arg for EMS target instance when object type is "EMSCLI"]
   [-ignore_xml => Optional 4th argument for xml library ignore flag ,
                   Values - 0 or OFF ,defaults to 1]

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 SonusQA::Utils::resolve_alias()

OUTPUT:

 $AtsObjRef - ATS object if successful
    Adds - $AtsObjRef->{TMS_ALIAS_DATA} and $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME}
    exit - otherwise

EXAMPLE: 

    our ( $SimsAdminObj, $SimsRootObj );

    # SIMS - ADMIN session
    if(defined ($TESTBED{ 'sims:1:ce0' })) {
        $SimsAdminObj = SonusQA::SIMS::newFromAlias(
                        -tms_alias => $TESTBED{ 'sims:1:ce0' },
                    );
        unless ( defined $SimsAdminObj ) {
            $logger->error('  -----FAILED TO CREATE SIMS ADMIN OBJECT-----');
            return 0;
        }
    }
    $logger->debug('  -----SUCCESS CREATED SIMS ADMIN OBJECT-----');

    # SIMS - ROOT session
    if(defined ($TESTBED{ 'sims:1:ce0' })) {
        $SimsRootObj = SonusQA::SIMS::newFromAlias(
                        -tms_alias => $TESTBED{ 'sims:1:ce0' },
                        -obj_user  => 'root',
                    );
        unless ( defined $SimsRootObj ) {
            $logger->error('  -----FAILED TO CREATE SIMS ROOT OBJECT-----');
            return 0;
        }
    }
    $logger->debug('  -----SUCCESS CREATED SIMS ROOT OBJECT-----');

=cut

#################################################
sub newFromAlias {
#################################################

    my ( %args ) = @_;
    my $subName = 'newFromAlias()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my ( $TmsAlias, %refined_args, $AtsObjType, $AtsObjRef, $EmsTargetInstance );
    my $ignore_xml = 1; # default value

    # Iterate through the args that are passed in and remove tms_alias and
    # obj_type
    foreach ( keys %args ) {
        if ( $_ eq '-tms_alias' ) { 
            $TmsAlias = $args{'-tms_alias'};
        }
        elsif ( $_ eq '-obj_type' ) {
            $AtsObjType = $args{'-obj_type'};
        }
        elsif ( $_ eq '-target_instance' ) {
            $EmsTargetInstance = $args{'-target_instance'};
        }
        elsif ( $_ eq '-ignore_xml' ) {
            $ignore_xml = $args{'-ignore_xml'};
        }
        else {
            # Populate a hash with other flags passed in. This will then be
            # passed to Base::new where that function will
            # process remaining hash entries.
            $refined_args{ $_ } = $args{ $_ };
        } 
    }

    # Check if $TmsAlias is defined and not blank
    unless ( defined($TmsAlias) && ($TmsAlias !~ m/^\s*$/) ) {
        $logger->error('  Value for -tms_alias undefined or is blank');
        $logger->debug(' <-- Leaving sub [exit]');
        exit;
    }
    $logger->debug("  Resolving Alias $TmsAlias"); 

    # Set ignore_xml flag to user specified value if $args{-ignore_xml} specified    
    if ( defined($ignore_xml) && ($ignore_xml !~ m/^\s*$/) ) {
        $logger->error('  Ignore XML flag is blank');
    }

    my $TmsAlias_hashRef = SonusQA::Utils::resolve_alias($TmsAlias);

    # Check if $TmsAlias_hashRef is empty 
    unless ( keys ( %{$TmsAlias_hashRef} ) ) {
        $logger->error("  \$TmsAlias_hashRef for TMS alias $TmsAlias empty. This element does not seem to be in the database.");
        $logger->debug(' <-- Leaving sub [exit]');
        exit;
    }

    # Check for __OBJTYPE. If this is blank and -obj_type is not defined error.
    # If -obj_type is different to __OBJTYPE error.
    if ( defined( $AtsObjType ) && ( $AtsObjType !~ m/^\s*$/ ) ) {
        unless ( $AtsObjType eq $TmsAlias_hashRef->{__OBJTYPE} ) {
            $logger->error("  Value for -obj_type ($AtsObjType) does not match TMS OBJTYPE ($TmsAlias_hashRef->{__OBJTYPE})");
            $logger->debug(' <-- Leaving sub [exit]');
            exit;
        }
        $logger->debug("  Object Type (from cmdline) is $AtsObjType");
    }
    else {
        if ( $TmsAlias_hashRef->{__OBJTYPE} eq "" ) {
            $logger->error('  Value for -obj_type and TMS OBJTYPE undefined or is blank');
            $logger->debug(' <-- Leaving sub [exit]');
            exit;
        }
        else {
            $AtsObjType = $TmsAlias_hashRef->{__OBJTYPE};
            $logger->debug("  Object Type (from TMS) is $AtsObjType");
        }
    }

    switch ($AtsObjType) {
        case /^SIMS$/ {
            # Check TMS alias parameters are defined and not blank
            my %SimsTMSAttributes = (
                #=====================================
                # SIMS - IPv4 address & Hostname
                #=====================================
                'NODE_1_IP'          => $TmsAlias_hashRef->{NODE}->{1}->{IP},
                'NODE_1_HOSTNAME'    => $TmsAlias_hashRef->{NODE}->{1}->{HOSTNAME},

                #=====================================
                # SIMS - Login & Password
                #=====================================
                # ADMIN - User ID
                'LOGIN_1_USERID'     => $TmsAlias_hashRef->{LOGIN}->{1}->{USERID},
                # ADMIN - User Password
                'LOGIN_1_PASSWD'     => $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD},
                # ROOT - Linus Shell Password
                'LOGIN_1_ROOTPASSWD' => $TmsAlias_hashRef->{LOGIN}->{1}->{ROOTPASSWD},
                # password for dsh / linuxadmin login
                'LOGIN_1_DSHPASSWD'  => $TmsAlias_hashRef->{LOGIN}->{1}->{DSHPASSWD},

                #=====================================
                # SIMS Component(s) - Log Directories
                #=====================================
                # P-CSCF Log directory
                'NODE_1_LOG_DIR_PCSCF' => $TmsAlias_hashRef->{NODE}->{1}->{LOG_DIR},
                # I-CSCF Log directory
                'NODE_2_LOG_DIR_ICSCF' => $TmsAlias_hashRef->{NODE}->{2}->{LOG_DIR},
                # S-CSCF Log directory
                'NODE_3_LOG_DIR_SCSCF' => $TmsAlias_hashRef->{NODE}->{3}->{LOG_DIR},

                #======================================================
                # SIMS BSX Component(s) - Ingress/Egress Signalling IP
                #======================================================
                # Ingress Signalling SIP IPv4
                'SIG_SIP_1_IP_Ingress' => $TmsAlias_hashRef->{SIG_SIP}->{1}->{IP},
                # Egress Signalling SIP IPv4
                'SIG_SIP_2_IP_Egress'  => $TmsAlias_hashRef->{SIG_SIP}->{2}->{IP},
            );

            my @missingTmsValues;
            my $TmsAttributeFlag = 0;
            while ( my($key, $value) = each(%SimsTMSAttributes) ) {
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $TmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $TmsAttributeFlag == 1 ) {
                $logger->error("  TMS alias parameters could not be obtained for alias $TmsAlias of object type $AtsObjType");
                foreach my $key (@missingTmsValues) {
                    $logger->error("  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(' Leaving sub [exit]');
                exit;
            }

            unless ( defined( $refined_args{ '-obj_user' } ) ) {
                $refined_args{ '-obj_user' } = $TmsAlias_hashRef->{LOGIN}->{1}->{USERID};
                $logger->debug("  -obj_user set to \'$refined_args{'-obj_user'}\'");
            }

            if ( $refined_args{ '-obj_user' } eq 'root' ) {
                unless ( exists( $refined_args{ '-obj_password' } ) &&
                         defined( $refined_args{ '-obj_password' } ) ) {
                    $refined_args{ '-obj_password' } = $TmsAlias_hashRef->{LOGIN}->{1}->{ROOTPASSWD};
                    $logger->debug("  -obj_password set to TMS_ALIAS->LOGIN->1->ROOTPASSWD");
                }

                unless ( exists( $refined_args{ '-obj_port' } ) &&
                         defined( $refined_args{ '-obj_port' } ) ) {
                    $refined_args{ '-obj_port' } = 2024;
                    $logger->debug("  -obj_port set to \'$refined_args{'-obj_port'}\'");
                }
            }
            elsif ( $refined_args{ '-obj_user' } eq "$TmsAlias_hashRef->{LOGIN}->{1}->{USERID}" ) {
                unless ( exists( $refined_args{ '-obj_password' } ) &&
                         defined( $refined_args{ '-obj_password' } ) ) {
                    $refined_args{ '-obj_password' } = $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD};
                    $logger->debug("  -obj_password set to TMS_ALIAS->LOGIN->1->PASSWD");
                }
                unless ( exists( $refined_args{ '-obj_port' } ) &&
                         defined( $refined_args{ '-obj_port' } ) ) {
                    $refined_args{ '-obj_port' } = 22;
                    $logger->debug("  -obj_port set to \'$refined_args{'-obj_port'}\'");
                }
            }

            unless ( defined( $refined_args{ '-obj_commtype' } ) ) {
                $refined_args{ '-obj_commtype' } = 'SSH';
                $logger->debug("  -obj_commtype set to \'$refined_args{'-obj_commtype'}\'");
            }


            # Attempt to create ATS SIMS object.If unsuccessful,
            $AtsObjRef = SonusQA::SIMS->new(
                                        -obj_host     => "$TmsAlias_hashRef->{NODE}->{1}->{IP}",
                                        -obj_hostname => "$TmsAlias_hashRef->{NODE}->{1}->{HOSTNAME}",
                                        %refined_args,
                                    );
        } # End - case SIMS
    } # End switch

    # Add TMS alias data to the newly created ATS object for later use
    $AtsObjRef->{TMS_ALIAS_DATA} = $TmsAlias_hashRef;

    # Add the TMS alias name to the TMS ALAIAS DATA
    $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME} =  $TmsAlias;
    
    $logger->debug(" Leaving sub \[obj:$AtsObjType\]");    
    return $AtsObjRef;

} # End sub newFromAlias

#########################################################################################################


=pod

=head1 NAME

SonusQA::SIMS - Perl module for Sonus Networks SIMS interaction

=head1 SYSOPSIS

 use ATS; # This is the base class for Automated Testing Structure

 or:

 use SonusQA::SIMS;

 my $SimsObj = SonusQA::SIMS->new(
                             #REQUIRED PARAMETERS
                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                              -obj_commtype => 'SSH',
                              -obj_port     => 22,
                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                              %refined_args,
                             );

PARAMETER DESCRIPTIONS:

OBJ_HOST

      The connection address for this object.
      Typically this will be a resolvable (DNS) host name or a specific IP Address.

OBJ_USER

      The user name or ID that is used to 'login' to the device.

OBJ_PASSWORD

      The user password that is used to 'login' to the device.

OBJ_COMMTYPE

      The session or connection type that will be established.

OBJ_PORT

      The port connection that will be established.

OBJ_HOSTNAME

      The host name of SIMS box.

=head1 DESCRIPTION


=cut

#########################################################################################################

=pod

=head3 SonusQA::SIMS::doInitialization()

  Base module over-ride. Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.
   
Arguments

  NONE 

Returns

  NOTHING   

=cut

#################################################
sub doInitialization {
#################################################
    my( $self, %args ) = @_;
    my $subName = 'doInitialization()' ;
    
    if ( exists $ENV{LOG_LEVEL} ) {
        $self->{LOG_LEVEL} = uc $ENV{LOG_LEVEL};
    }
    else {
        $self->{LOG_LEVEL} = 'INFO';
    }

    if ( ! Log::Log4perl::initialized() ) {
        if (  ${self}->{LOG_LEVEL} eq 'DEBUG' ) {
            Log::Log4perl->easy_init($DEBUG);
        } elsif (  ${self}->{LOG_LEVEL} eq 'INFO' ) {
            Log::Log4perl->easy_init($INFO);
        } elsif (  ${self}->{LOG_LEVEL} eq 'WARN' ) {
            Log::Log4perl->easy_init($WARN);
        } elsif (  ${self}->{LOG_LEVEL} eq 'ERROR' ) {
            Log::Log4perl->easy_init($ERROR);
        } elsif (  ${self}->{LOG_LEVEL} eq 'FATAL' ) {
            Log::Log4perl->easy_init($FATAL);
        } else {
            # Default to INFO level logging
            Log::Log4perl->easy_init($INFO);
        }
    }

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');
    
    ############################
    # SIMS - SSH Session Types
    ############################
    %sessionDetails = (
        # sgx4k prompt => '/.*[#>\$%] $/'
        # Admin Login / CLI - Session
        ADMIN => {
                    prompt => '/admin\@\S+\> $/',
                    pattern => qr/admin\@\S+\> $/,
                    session => 'ADMIN',
                },

        # Root Login / Shell - Session
        ROOT  => {
                    prompt => '/\[root\@\S+\s\~\]\# $/',
                    pattern => qr/\[root\@\S+\s\~\]\# $/,
                    session => 'ROOT',
                },

        # Configure Private and Configure Exclusive Sessions
        CONFMODE => {
                    prompt => '/admin\@\S+\% $/',
                    pattern => qr/admin\@\S+\% $/,
                    session => 'CONFMODE',
                },

        # Debug Shell (i.e. from Admin session to Root Session)
        # i.e. linuxadmin session
        DEBUGSHELL => {
                    prompt => '/linuxadmin\@\S+\:\~\$ $/',
                    pattern => qr/linuxadmin\@\S+\:\~\$ $/,
                    session => 'DEBUGSHELL',
                },
    );

    $self->{COMMTYPES}          = [ 'SSH', 'SCP', 'FTP', 'SFTP' ];
    $self->{COMM_TYPE}          = undef;
    $self->{TYPE}               = __PACKAGE__;
    $self->{conn}               = undef;
    $self->{OBJ_HOST}           = undef;

    $self->{DEFAULTPROMPT}      = '/[\$%#>] $/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};

    $self->{REVERSE_STACK}      = 1;
    $self->{VERSION}            = $VERSION;
    $self->{LOCATION}           = locate __PACKAGE__;
    my ($name,$path,$suffix)    = fileparse($self->{LOCATION},"\.pm"); 
    $self->{DIRECTORY_LOCATION} = $path;

    $self->{DEFAULTTIMEOUT}     = 10;
    $self->{SESSIONLOG}         = 0;
    $self->{IGNOREXML}          = 1;
  
    foreach ( keys %args ) {

        if ( /^-?obj_host$/i ) {   
            $self->{OBJ_HOST} = $args{ $_ };
        }

        if ( /^-?obj_user$/i ) {   
            $self->{OBJ_USER} = $args{ $_ };
        }

        if ( /^-?obj_password$/i ) {   
            $self->{OBJ_PASSWORD} = $args{ $_ };
        }

        if ( /^-?obj_hostname$/i ) {   
            $self->{OBJ_HOSTNAME} = $args{ $_ };
        }

        if ( /^-?obj_port$/i ) {   
            $self->{OBJ_PORT} = $args{ $_ };
        }

        if ( /^-?obj_commtype$/i ) {   
            my $commType = $args{ $_ };
            $logger->debug("  Check if comm type ($commType) is valid. . . from SIMS list (@{ $self->{COMMTYPES} })");
            foreach ( @{ $self->{COMMTYPES} } ) {
                if ( $commType eq $_ ) {
                    $self->{COMM_TYPE} = $commType;
                    last;
                }
            }

            unless ( defined $self->{COMM_TYPE} ) {
                $logger->warn("  Invalid commtype($args{ $_ }) used, set default session type to \'SSH\'");
                $self->{COMM_TYPE} = 'SSH';
            }
        }
    }
    
    $self->{ENTERED_CLI}          = 0;
    $self->{ENTERED_CONFIG}       = 0;
    $self->{ENTERED_DEBUG}        = 0;
    $self->{ENTERED_ROOT_VIA_DSH} = 0;

    $self->{SESSIONTYPE}    = undef;

    ####################################
    # SIMS - Event Log File and Type(s)
    ####################################
    %eventLogFileTypeDetails = (
      # File    # Event Log
      # Extn    # Type
        'ACT' => 'acct',
        'DBG' => 'debug',
        'SEC' => 'security',
        'SYS' => 'system',
        'TRC' => 'trace',
    );

    ####################################
    # SIMS - Signalling SIP (SBX)
    # Ingress/Egress port details
    ####################################
    %signallingSbxPort = (
        'INGRESS' => 65210,
        'EGRESS'  => 65210,
    );

    $logger->debug('  Initialization Complete');
    $logger->debug(' <-- Leaving Sub [1]');
}

#########################################################################################################

#################################################
sub setSystem() {
#################################################
    my( $self ) = @_;
    my $subName = 'setSystem()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');
    
    unless ( defined $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn(' Hostname variable (via -obj_hostname) not set.');
        return 0;
    }

    # set default Session type and Prompt
    if ( $self->{COMM_TYPE} eq 'SSH' ) {
        if ( $self->{OBJ_PORT} == 22 ) {
            # Set ADMIN - prompt & session type
            $self->{PROMPT} = $sessionDetails{ADMIN}->{prompt};
            $self->{conn}->prompt($self->{PROMPT});

            $self->{SESSIONTYPE} = $sessionDetails{ADMIN}->{session};
            $self->{ENTERED_CLI} = 1;
        }
        elsif ( $self->{OBJ_PORT} == 2024 ) {
            # Set ROOT - prompt & session type
            $self->{PROMPT} = $sessionDetails{ROOT}->{prompt};
            $self->{conn}->prompt($self->{PROMPT});

            $self->{SESSIONTYPE} = $sessionDetails{ROOT}->{session};
        }
        $logger->debug("  for \'$self->{COMM_TYPE}\' session set prompt($self->{PROMPT}) and session type \'$self->{SESSIONTYPE}\'.");
    }

    unless ( defined ( $self->{PROMPT} ) ) {
        $logger->error('  ERROR: PROMPT not set.');
    }

    unless ( defined ( $self->{SESSIONTYPE} ) ) {
        $logger->error('  ERROR: SESSION Type not set.');
    }

    $logger->debug('  Set System Complete');
    $logger->debug(' <-- Leaving Sub [1]');
    return 1;
}  


#########################################################################################################

=head1 execCmd()

DESCRIPTION:

 The function is the generic function to issue a command to the SIMS.
 It utilises the mechanism of issuing a command and then waiting for prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $SimsObj->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $SimsObj->{CMDRESULTS} - contains the return information from the command issued

 There is no failure as such.
 What constitutes a "failure" will be when the expected prompt is not returned.
 It is highly recommended that the user parses the return from execCmd for
 both the expected string and error strings to better identify any possible cause of failure.

ARGUMENTS:

 1. The command to be issued
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 @cmdResults - either the information from the CLI on successful return of the expected prompt,
               or an empty array on timeout of the command.

EXAMPLE:

    my $cmd = 'ls';
    my @cmdResults = $SimsObj->execCmd( 
                            '-cmd'     => $cmd,
                            '-timeout' => 20,
                            '-testId'  => '111111',
                        );

=cut

#################################################
sub execCmd {  
#################################################
  
    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}
    my ( $self, %args ) = @_;
    my $subName = 'execCmd()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    # $logger->debug(' --> Entered Sub');

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    if ( $self->{ENTERED_CLI} ) {
        $logger->info(" $a{'-testId'} Issuing CLI command from Admin\/CLI session($self->{SESSIONTYPE}): \'$a{'-cmd'}\'");    
    }
    elsif ( $self->{ENTERED_CONFIG} ) {
        $logger->info(" $a{'-testId'} Issuing CLI command from Configure (Private\/Exclusive) mode ($self->{SESSIONTYPE}): \'$a{'-cmd'}\'");    
    }
    elsif ( $self->{ENTERED_DEBUG} ) {
        $logger->info(" $a{'-testId'} Issuing DEBUG command from linuxadmin session ($self->{SESSIONTYPE}): \'$a{'-cmd'}\'");    
    }
    else { 
        $logger->info("  $a{'-testId'} Issuing CMD: \'$a{'-cmd'}\'");
    }
    $self->{LASTCMD}    = $args{'-cmd'}; 
    $self->{CMDRESULTS} = ();
  
    # discard all data in object's input buffer
    $self->{conn}->buffer_empty;

    my $timestamp = $self->getTime();

    my $errMode = sub {
        unless ( $a{'-cmd'} =~ /exit/ ) {
            $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            $logger->error("  $a{'-testId'} " . 'Timeout OR Error for command (' . "$a{'-cmd'}" . ')');
            $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        }
        return 1;
    };

    my @cmdResults = $self->{conn}->cmd (
                      '-string'  => $a{'-cmd'},
                      '-timeout' => $a{'-timeout'},
                      '-errmode' => $errMode,
                    );

    if ( @cmdResults ) {
        if ( ( $cmdResults[$#cmdResults] =~ /command not found$/ ) ||
             ( $cmdResults[$#cmdResults] =~ /not found$/ ) ||
             ( $cmdResults[$#cmdResults] =~ /^invalid command name/ ) ||
             ( $cmdResults[$#cmdResults] =~ /^wrong \# args\:/ ) ||
             ( $cmdResults[$#cmdResults] =~ /couldn\'t read file\s+\"[\S\s]+\"\:\s+no such file or directory$/ )
         ) {
            # command has produced an error. This maybe intended, but the least we can do is warn 
            $logger->warn(" $a{'-testId'} COMMAND ERROR. CMD: \'$a{'-cmd'}\'.\n ERROR:\n @cmdResults");
        }
    }
 
    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    
    # $logger->debug(' <-- Leaving Sub');
    return @cmdResults;
}

#########################################################################################################

=head1 execShellCmd()

DESCRIPTION:

 The function is a wrapper around execCmd for the SIMS linux shell.
 The function issues a command then issues echo $? to check for a return value.
 The function will then return 1 or 0 depending on whether the echo command yielded 0 or not.
 ie. in the shell 0 is PASS (and so the perl function returns 1)
     any other value is FAIL (and so the perl function returns 0).
     In the case of timeout 0 is returned.
 
 The command output from the command is then accessible from $self->{CMDRESULTS}. 

ARGUMENTS:

 1. The Shell command to be issued
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:

 1 - success
 0 - failure 

 $SimsRootObj->{CMDRESULTS} - shell output
 $SimsRootObj->{LASTCMD}    - shell command issued

EXAMPLE:

    my $cmd = 'ls';

    unless ( $SimsRootObj->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                            '-testId'  => '111111',
                        ) ) {
        my $errMessage = "  FAILED - executing SHELL command \'$cmd\':--\n@{ $SimsRootObj->{CMDRESULTS}}\n";
        $logger->error("$errMessage");
        $errorMsg = "FAILED - SHELL cmd \'$cmd\'";
        return 0;
    }
    $logger->debug("  SUCCESS - Executed SHELL command \'$cmd\'.");

=cut

#################################################
sub execShellCmd {
#################################################

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName       = 'execShellCmd()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    # $logger->debug(' --> Entered Sub');

    my (@retResults, @cmdShellStatus);
    my $retValue = 0;
 
    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ROOT}->{session} ) ||
             ( $self->{SESSIONTYPE} eq $sessionDetails{DEBUGSHELL}->{session} ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in SHELL session, to execute shell command \'$args{'-cmd'}\'.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    my @cmdList = (
        $a{'-cmd'},
        'echo $?',
    );

    foreach (@cmdList) {

        $a{'-cmd'} = $_;

        my @cmdResults;
        unless ( @cmdResults = $self->execCmd (
                                  '-cmd'     => $a{'-cmd'},
                                  '-timeout' => $a{'-timeout'},
                                  '-testId'  => $a{'-testId'},
                                ) ) {

            # Entered due to a timeout on receiving the correct prompt.
            # What reasons would lead to this? Reboot?
            # remove empty elements or spaces in the array
            @cmdResults = grep /\S/, @cmdResults;

            if( grep /:\s+command not found$/is, @cmdResults ) {
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                $logger->error(" $a{'-testId'} ERROR DETECTED, SHELL CMD ISSUED WAS:");
                $logger->error("  $a{'-cmd'}");
                $logger->error(" $a{'-testId'} CMD RESULTS:");
        
                chomp(@cmdResults);
                map { $logger->error("\t$_") } @cmdResults;
        
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            }
            
            chomp(@cmdResults);
        }

        unless ( @retResults ) {
            @retResults = @cmdResults;
        }

        if ( /echo/ ) {
            @cmdShellStatus = @cmdResults;
            $self->{CMDRESULTS} = ();
            if ( @retResults ) {
                push( @{$self->{CMDRESULTS}}, @retResults );
            }
        }
    }

    chomp(@cmdShellStatus);

    my $errorValue = undef;
    foreach (@cmdShellStatus) {
        if (/^(\d+)/) {
            $errorValue = $1;
            if ($1 == 0) {
                # when $? == 0, success;
                $logger->debug(" $a{'-testId'} SUCCESS: shell return code \'$1\'");
                $retValue = 1;
            }
            elsif ( $1 == 3 ) {
$logger->debug(" $a{'-testId'} 3: cmd \'$a{'-cmd'}\', \$arg \'$args{'-cmd'}\'");
#                if ( $args{'-cmd'} eq 'service sbx status' ) {
                if ( $args{'-cmd'} =~ /service sbx status/ ) {
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->warn (" $a{'-testId'} WARN: \"$args{'-cmd'}\" intentionally returns 3, after \'service sbx stop\'");
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->debug(" $a{'-testId'} SUCCESS: shell return code \'$errorValue\'");
                    $retValue = 1;
                }
            }
            elsif ( $1 == 127 ) {
$logger->debug(" $a{'-testId'} 127: cmd \'$a{'-cmd'}\', \$arg \'$args{'-cmd'}\'");
                if ( $args{'-cmd'} =~ /service sbx stop/ ) {
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->warn (" $a{'-testId'} WARN: \"$args{'-cmd'}\", May be DB process is in running status");
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->error(" $a{'-testId'} ERROR: shell return code \'$errorValue\'");
#                    $retValue = 1;
                }
            }
            else {
                $logger->error(" $a{'-testId'} ERROR: SHELL CMD FAILED - shell return code \'$1\'");
            }
            last;
        }
        last;
    }

    # $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 execCliCmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for
 SIMS CLI specific strings: '[ok]' or '[error]'.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.
 The CLI output from the command is then only accessible from $self->{CMDRESULTS}.
 The idea of this function is to remove the parsing for '[ok]' or '[error]' from every CLI command call. 

ARGUMENTS:

 1. The CLI command to be issued
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - [ok] (Success) found in output
 0 - [error] found in output or the CLI command timed out.

 $SimsAdminObj->{CMDRESULTS} - CLI output
 $SimsAdminObj->{LASTCMD}    - CLI command issued

EXAMPLE:

    my $cmd = 'show table system serverAdmin';

    unless ( $SimsAdminObj->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                            '-testId'  => '111111',
                        ) ) {
        my $errMessage = "  FAILED - executing CLI command \'$cmd\':--\n@{ $SimsAdminObj->{CMDRESULTS}}\n";
        $logger->error("$errMessage");
        $errorMsg = "FAILED - CLI cmd \'$cmd\'";
        return 0;
    }
    $logger->debug("  SUCCESS - Executed CLI command \'$cmd\'.");

=cut

#################################################
sub execCliCmd {
#################################################

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful the cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName       = 'execCliCmd()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    # $logger->debug(' --> Entered Sub');

    my ( @cmdResults, $cliCmdStatus );
    my $retValue = 0;

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ADMIN}->{session} ) ||
             ( $self->{SESSIONTYPE} eq $sessionDetails{CONFMODE}->{session} ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in CLI session, to execute CLI command \'$args{'-cmd'}\'.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    # Are we already in a session?
    if ( ($self->{ENTERED_CLI} == 1) ||
         ($self->{ENTERED_CONFIG} == 1) ) {
        unless ( @cmdResults = $self->execCmd (
                                  '-cmd'     => $a{'-cmd'},
                                  '-timeout' => $a{'-timeout'},
                                  '-testId'  => $a{'-testId'},
                                ) ) {

            # Entered due to a timeout on receiving the correct prompt.
            # What reasons would lead to this? Reboot?
            # remove empty elements or spaces in the array
            @cmdResults = grep /\S/, @cmdResults;
        }

        if ( @cmdResults ) {
            foreach ( @cmdResults ) {
                if ( /^\[(\S+)\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/ ) {
                    $cliCmdStatus = $1;
                    last;
                }
            }

            unless ( defined $cliCmdStatus ) {
                # Reached end of result without error or ok
                $logger->error('  CLI CMD ERROR: Neither [error] nor [ok]');
                $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                $logger->error(" $a{'-testId'} ERROR DETECTED, CLI CMD ISSUED WAS:");
                $logger->error("  $a{'-cmd'}");
                $logger->error(" $a{'-testId'} CMD RESULTS:");

                map { $logger->error("\t$_") } @cmdResults;

                $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            }
            else {
                $logger->debug(" $a{'-testId'} CLI COMMAND STATUS is \'$cliCmdStatus\'");

                if ( $cliCmdStatus eq 'error' ) {
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->error(" $a{'-testId'} ERROR DETECTED i.e.[error], CLI CMD ISSUED WAS:");
                    $logger->error("  $a{'-cmd'}");
                    $logger->error(" $a{'-testId'} CMD RESULTS:");
    
                    map { $logger->error("\t$_") } @cmdResults;
    
                    $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                }
                elsif ( $cliCmdStatus eq 'ok' ) {
                    $retValue = 1;
                    $logger->debug(" $a{'-testId'} SUCCESS: CLI command executed \'$a{'-cmd'}\'");
                    $logger->debug(" $a{'-testId'} CMD RESULTS:");

                    map { $logger->debug("\t$_") } @cmdResults;
                }
            }
        } # END - CLI command Success/Failure check
    }

    # $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 execCommitCliCmd()

DESCRIPTION:

 The function is a wrapper around execCliCmd that also parses the output to look for
 SIMS CLI specific strings: '[ok]' or '[error]'.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.
 The CLI output from the command is then only accessible from $self->{CMDRESULTS}.

ARGUMENTS:

 1. The command to be issued to the TL1
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - {1} (Success) found in output
 0 - {0 <ErrorCode>} found in output or the CLI command timed out.

 $SimsAdminObj->{CMDRESULTS} - CLI output
 $SimsAdminObj->{LASTCMD}    - CLI command issued

EXAMPLE:

    my $cliCmdList = [
        'CLI Command 1',
        'CLI Command 2',
        'CLI Command 3',
        'CLI Command 4',
    ];

    unless ( $SimsAdminObj->execCommitCliCmd(
                            '-cmdList' => $cliCmdList,
                            '-timeout' => 30,
                            '-testId'  => '111111',
                        ) ) {
        my $errMessage = "  FAILED - to execute CLI command list \n@{$cliCmdList}\nCLI Command Output:--\n@{ $SimsAdminObj->{CMDRESULTS}}";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Executed CLI command \'$cmd\'.");

=cut

#################################################
sub execCommitCliCmd {
#################################################

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful the cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName       = 'execCommitCliCmd()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    # $logger->debug(' --> Entered Sub');

    my ( @cmdResults, $cliCmdStatus );
    my $retValue = 0;

    # Check Mandatory Parameters
    unless ( defined $args{'-cmdList'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmdList\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
 
    my %a = (
        '-cmdList' => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    unless ( $self->{SESSIONTYPE} eq $sessionDetails{CONFMODE}->{session} ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in CONFIGURE session mode, to execute CLI command(s) and then \'commit\'.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    my @CliCmdList = @{ $a{'-cmdList'} };
    push ( @CliCmdList, 'commit' );
    # Are we already in a Configure session?
    if ($self->{ENTERED_CONFIG} == 1) {
        foreach my $cliCmd ( @CliCmdList ) {
            unless ( @cmdResults = $self->execCmd (
                                      '-cmd'     => $cliCmd,
                                      '-timeout' => $a{'-timeout'},
                                      '-testId'  => $a{'-testId'},
                                    ) ) {

                # Entered due to a timeout on receiving the correct prompt.
                # What reasons would lead to this? Reboot?
                # remove empty elements or spaces in the array
                @cmdResults = grep /\S/, @cmdResults;
            }

            if ( @cmdResults ) {
                foreach ( @cmdResults ) {
                    if ( /^\[(\S+)\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/ ) {
                        $cliCmdStatus = $1;
                        last;
                    }
                }

                unless ( defined $cliCmdStatus ) {
                    $retValue = 0;
                    # Reached end of result without error or ok
                    $logger->error('  CLI CMD ERROR: Neither [error] nor [ok]');
                    $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    $logger->error(" $a{'-testId'} ERROR DETECTED, CLI CMD ISSUED WAS:");
                    $logger->error("  $cliCmd");
                    $logger->error(" $a{'-testId'} CMD RESULTS:");

                    map { $logger->error("\t$_") } @cmdResults;

                    $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                }
                else {
                    $logger->debug(" $a{'-testId'} CLI COMMAND STATUS is \'$cliCmdStatus\'");

                    if ( $cliCmdStatus eq 'error' ) {
                        $retValue = 0;
                        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                        $logger->error(" $a{'-testId'} ERROR DETECTED i.e.[error], CLI CMD ISSUED WAS:");
                        $logger->error("  $cliCmd");
                        $logger->error(" $a{'-testId'} CMD RESULTS:");
            
                        map { $logger->error("\t$_") } @cmdResults;
            
                        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                    }
                    elsif ( $cliCmdStatus eq 'ok' ) {
                        $retValue = 1;
                        $logger->debug(" $a{'-testId'} SUCCESS: CLI command executed \'$cliCmd\'");
                        $logger->debug(" $a{'-testId'} CMD RESULTS:");
        
                        map { $logger->debug("\t$_") } @cmdResults;
                    }
                }
            } # END - CLI command Success/Failure check

            if ( $retValue == 0 ) {
                # Leave Configure mode and Enter configure session mode
                # to avoid further error

                ######################################
                # TBD
                ######################################
                last;
            }

        } # --> END - Foreach CLI command list
    }

    # $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 enterConfigureMode()

DESCRIPTION:

 The function is used to enter 'configure private' or 'configure exclusive' mode to manipulate
 software configuration information.
 It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. Configure mode (Optional) - either 'private' or 'exclusive' mode
                              - default is 'private' mode
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    unless ( $SimsAdminObj->enterConfigureMode(
                            '-mode'    => 'private', # OR
                         #  '-mode'    => 'exclusive',
                            '-timeout' => 30,
                            '-testId'  => '111111',
                        ) ) {
        my $errMessage = "  FAILED - to enter Configure(private) mode.";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Entered Configure(private) mode.");

=cut

#################################################
sub enterConfigureMode {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'enterConfigureMode()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my ( @cmdResults, $cliCmdStatus );
    my $retValue = 0;
    my @validConfigModes = (
        'private',
        'exclusive',
    );

    unless ( defined $args{'-testId'} ) {
        $args{'-testId'} = '',
    }

    # Check 'configure' mode Parameter
    unless ( defined $args{'-mode'} ) {
        $logger->warn (" $args{'-testId'} WARN : The argument \'-mode\' has not been specified or is blank.");
        $logger->warn (" $args{'-testId'} WARN : So using \'configure private\' mode");
    }
    else {
        my $validModeFlag = 0;
        foreach my $mode ( @validConfigModes ) {
            if ( $args{'-mode'} eq $mode ) {
                $validModeFlag = 1;
                last;
            }
        }

        unless ( $validModeFlag ) {
            $logger->error(" $args{'-testId'} ERROR: The argument \'-mode\' is INVALID ($args{'-mode'}), possible values:--\n@validConfigModes\n");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
    }
 
    # Are we already in a Configure session?
    if ( ( $self->{SESSIONTYPE} eq $sessionDetails{CONFMODE}->{session} ) &&
         ( $self->{ENTERED_CONFIG} == 1 ) ) {
        $retValue = 1;
        $logger->debug(" $args{'-testId'} Already in configure session.");
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    # Are we in ADMIN/CLI session? to enter 'configure' mode . . .
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ADMIN}->{session} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $args{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $args{'-testId'} ERROR: Not in ADMIN\/CLI session, to enter \'configure\' mode.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    my %a = (
        '-mode' => 'private',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    # Set CONFMODE - prompt & session type
    $self->{PROMPT} = $sessionDetails{CONFMODE}->{prompt};
    $self->{conn}->prompt($self->{PROMPT});
    $self->{SESSIONTYPE} = $sessionDetails{CONFMODE}->{session};

    my $cliCmd = 'configure ' . $a{'-mode'};
    unless ( @cmdResults = $self->execCmd (
                                      '-cmd'     => $cliCmd,
                                      '-timeout' => $a{'-timeout'},
                                      '-testId'  => $a{'-testId'},
                                    ) ) {
        # Entered due to a timeout on receiving the correct prompt.
        # What reasons would lead to this? Reboot?
        # remove empty elements or spaces in the array
        @cmdResults = grep /\S/, @cmdResults;
    }

    if ( @cmdResults ) {
        foreach ( @cmdResults ) {
            if ( /^\[(\S+)\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/ ) {
                $cliCmdStatus = $1;
                last;
            }
        }

        unless ( defined $cliCmdStatus ) {
            # Reached end of result without error or ok
            $logger->error('  CLI CMD ERROR: Neither [error] nor [ok]');
            $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            $logger->error(" $a{'-testId'} ERROR DETECTED, CLI CMD ISSUED WAS:");
            $logger->error("  $cliCmd");
            $logger->error(" $a{'-testId'} CMD RESULTS:");

            map { $logger->error("\t$_") } @cmdResults;

            $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        }
        else {
            $logger->debug("  CLI COMMAND STATUS is \'$cliCmdStatus\'");

            if ( $cliCmdStatus eq 'error' ) {
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                $logger->error(" $a{'-testId'} ERROR DETECTED i.e.[error], CLI CMD ISSUED WAS:");
                $logger->error("  $cliCmd");
                $logger->error(" $a{'-testId'} CMD RESULTS:");
    
                map { $logger->error("\t$_") } @cmdResults;
    
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            }
            elsif ( $cliCmdStatus eq 'ok' ) {
                $retValue = 1;
                $logger->debug(" $a{'-testId'} SUCCESS: CLI command executed \'$cliCmd\'");
                $logger->debug(" $a{'-testId'} CMD RESULTS:");

                map { $logger->debug("\t$_") } @cmdResults;
            }
        }
    } # END - CLI command Success/Failure check

    if ( $retValue == 1 ) {
        $self->{ENTERED_CONFIG} = 1;
        $self->{ENTERED_CLI}    = 0;
    }
    else {
        # Set back to ADMIN - prompt & session type
        $self->{PROMPT} = $sessionDetails{ADMIN}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});

        $self->{SESSIONTYPE} = $sessionDetails{ADMIN}->{session};
        $self->{ENTERED_CLI}    = 1;
        $self->{ENTERED_CONFIG} = 0;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 leaveConfigureMode()

DESCRIPTION:

 The function is used to exit the management session 'configure private' or 'configure exclusive' mode
 which is used to manipulate software configuration information.
 It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    unless ( $SimsAdminObj->leaveConfigureMode( 
                                '-timeout' => 20,
                                '-testId'  => '111111',
                            ) ) {
        my $errMessage = "  FAILED - to leave Configure (private\/exclusive) mode.";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Leave Configure (private\/exclusive) mode.");

=cut

#################################################
sub leaveConfigureMode {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'leaveConfigureMode()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my ( @cmdResults, $cliCmdStatus );
    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Are we already in a Configure session? - to leave the session
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{CONFMODE}->{session} ) &&
             ( $self->{ENTERED_CONFIG} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in CONFMODE session, to leave \'configure\' mode.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    my $cliCmd = 'quit';
    unless ( $self->{conn}->print($cliCmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cliCmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cliCmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/Discard changes and continue/',
                                    '-match'   => '/^\[error\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/',
                                    '-match'   => '/^\[ok\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/',
                                    '-match'   => $sessionDetails{ADMIN}->{prompt},
                                    '-errmode' => 'return',
                                );

    # Match - Discard changes and continue? [yes,no]
    # i.e. There are uncommitted changes.
    if ( $match =~ m/Discard changes and continue/ ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Discard changes and continue\? \[yes,no\] prompt");

        $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->warn(" $a{'-testId'} THERE ARE UNCOMMITTED CHANGES.");
        $logger->warn(" $a{'-testId'} DiSCARD CHANGES AND CONTINUE:");
        $logger->warn("  $cliCmd");
        $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');

        # Give/Enter 'yes'
        unless ( $self->{conn}->print('yes') ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter \'yes\' to discard uncommitted changes and continue...");
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered \'yes\' to discard uncommitted changes and continue...");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/^\[error\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/',
                                    '-match'   => '/^\[ok\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/',
                                    '-match'   => $sessionDetails{ADMIN}->{prompt},
                                    '-errmode' => 'return',
                                );
    }

    if ( $match =~ m/^\[ok\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/ ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: command \'$cliCmd\' accepted.");
    }
    elsif ( $match =~ $sessionDetails{ADMIN}->{pattern} ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: command \'$cliCmd\' accepted i.e. matched prompt.");
    }
    elsif ( $match =~ m/^\[error\]\[\d+\-\d+\-\d+\s+\d+\:\d+\:\d+\]\s*$/ ) {
        $logger->error(" $a{'-testId'} ERROR: command \'$cliCmd\' failed:--\nprematch:\t$prematch\nmatch:\t$match\n");

        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR DETECTED i.e.[error], CLI CMD ISSUED WAS:");
        $logger->error("  $cliCmd");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cliCmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");

        # Reached end of result without error or ok
        $logger->error('  CLI CMD ERROR: Neither [error] nor [ok]');
        $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR DETECTED, CLI CMD ISSUED WAS:");
        $logger->error("  $cliCmd");
        $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
    }

    if ( $retValue == 1 ) {
        # Set ADMIN - prompt & session type
        $self->{PROMPT} = $sessionDetails{ADMIN}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});
        $self->{SESSIONTYPE} = $sessionDetails{ADMIN}->{session};

        $self->{ENTERED_CLI}    = 1;
        $self->{ENTERED_CONFIG} = 0;
    }
    else {
        # Set back to ADMIN - prompt & session type
        $self->{PROMPT} = $sessionDetails{CONFMODE}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});

        $self->{SESSIONTYPE} = $sessionDetails{CONFMODE}->{session};
        $self->{ENTERED_CONFIG} = 1;
        $self->{ENTERED_CLI}    = 0;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 _unhideDebug()

DESCRIPTION:

 This subroutine is used to reveal debug commands in the SIMS CLI.
 It basically issues the unhide debug command and deals with the prompts that are presented.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. SIMS 'root' password (needed for 'unhide debug')
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - Success - 'unhide debug' completed
 0 - Failure - to execute 'unhide debug'

EXAMPLE:

    my $rootPassword = $TmsAlias_hashRef->{LOGIN}->{1}->{ROOTPASSWD};
    unless ( $self->_unhideDebug(
                            '-rootPassword' => $rootPassword,
                            '-timeout'      => 20,
                            '-testId'  => '111111',
                        ) ) {
        $logger->error("  FAILED - executing \'unhide debug\'");
        return 0;
    }
    $logger->debug("  SUCCESS - executed \'unhide debug\'.");

=cut

#################################################
sub _unhideDebug {
#################################################

    my ($self, %args) = @_;
    my $subName       = '_unhideDebug()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Check Mandatory Parameters
    unless ( defined $args{'-rootPassword'} ) {
        $logger->error(" $a{'-testId'} ERROR: The mandatory argument \'-rootPassword\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
 
    # Are we in ADMIN/CLI session?
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ADMIN}->{session} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in ADMIN\/CLI session, to enter \'configure\' mode.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    # execute 'unhide debug' command on ADMIN session
    my $cmd = 'unhide debug';
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/[P|p]assword:/',
                                    '-match'   => '/\[ok\]/',
                                    '-match'   => '/\[error\]/',
                                    '-match'   => $self->{PROMPT},
                                    '-errmode' => 'return',
                                );

    # Match 'Password' prompt
    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Matched \'Password\' prompt");

        # Give/Enter 'root' password
        unless ( $self->{conn}->print($a{'-rootPassword'}) ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter root password \'$a{'-rootPassword'}\'");
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered root password \$a{'-rootPassword'}");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/\[ok\]/',
                                    '-match'   => '/\[error\]/',
                                    '-match'   => $self->{PROMPT},
                                    '-errmode' => 'return',
                                );
        if ( $match =~ m/\[ok\]/ ) {
            $retValue = 1;
            $logger->debug(" $a{'-testId'} SUCCESS: command \'$cmd\' accepted.");
        }
        elsif ( $match =~ m/\[error\]/ ) {
            $logger->error(" $a{'-testId'} ERROR: command \'$cmd\' did not accept root password \'$a{'-rootPassword'}, failed:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }
        else {
            $logger->error(" $a{'-testId'} ERROR: Failed after entering root password:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }

    }
    elsif ( $match =~ m/\[ok\]/ ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: command \'$cmd\' accepted without root password.");
    }
    elsif ( $match =~ m/\[error\]/ ) {
        $logger->error(" $a{'-testId'} ERROR: command \'$cmd\' failed:--\nprematch:\t$prematch\nmatch:\t$match\n");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 enterLinuxShellViaDsh()

DESCRIPTION:

 The function used to enter the linux shell (debug shell) via the 'dsh' command available
 in the SIMS ADMIN/CLI commands, i.e. Start a debug shell to local host.
 It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. SIMS 'root' password (needed for 'unhide debug')
 2. SIMS 'dsh' password (needed for 'dsh' command)
 3. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 4. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _unhideDebug()

OUTPUT:
 
 1 - Success - entered debug shell (dsh)
 0 - Failure - to enter debug shell (dsh)

EXAMPLE:

    unless ( $SimsAdminObj->enterLinuxShellViaDsh(
                            '-dshPassword'  => $SimsAdminObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{DSHPASSWD},
                            '-rootPassword' => $SimsAdminObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD},
                            '-timeout'      => 30, # default 10 seconds
                            '-testId'       => '111111',
                        ) ) {
        my $errMessage = "  FAILED - to enter debug shell (dsh) session.";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Entered debug shell (dsh) session.");

=cut

#################################################
sub enterLinuxShellViaDsh {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'enterLinuxShellViaDsh()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    # Check Mandatory Parameters
    foreach ( qw/ rootPassword dshPassword / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }
 
    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Are we in ADMIN/CLI session? to enter 'Debug Shell' . . .
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ADMIN}->{session} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in ADMIN\/CLI session, to enter \'configure\' mode.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    # execute 'unhide debug' command on ADMIN session
    unless ( $self->_unhideDebug(
                            '-rootPassword' => $a{'-rootPassword'},
                            '-timeout'      => $a{'-timeout'},
                            '-testId'       => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing \'unhide debug\':--\n@{ $self->{CMDRESULTS}}");
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed \'unhide debug\'.");

    # Start a debug shell to local host
    my $cmd = 'dsh';
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/[P|p]assword:/',
                                    '-match'   => '/\[error\]/',
                                    '-match'   => '/Do you wish to proceed <y\/N>/i',
                                    '-match'   => '/Are you sure you want to continue connecting \(yes\/no\)/i',
                                    '-match'   => $sessionDetails{DEBUGSHELL}->{prompt},
                                    '-errmode' => 'return',
                                );

    # Match 'Do you wish to proceed <y/N>?'
    # i.e. allows access to the operating system shell.
    if ( $match =~ m/<y\/N>/i ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Matched \'Do you wish to proceed\', entering \'y\'...");

        # Enter 'y'
        unless ( $self->{conn}->print('y') ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter \'y\' to allows access to the operating system shell.");
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered \'y\' to allows access to the operating system shell.");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/[P|p]assword:/',
                                    '-match'   => '/\[error\]/',
                                    '-match'   => '/Are you sure you want to continue connecting \(yes\/no\)/i',
                                    '-match'   => $sessionDetails{DEBUGSHELL}->{prompt},
                                    '-errmode' => 'return',
                                );
    }

    # Match 'Are you sure you want to continue connecting (yes/no)?'
    # i.e. add RSA key fingerprint to the list of known hosts.
    if ( $match =~ m/\(yes\/no\)/i ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Matched \'yes\/no prompt for adding RSA key fingerprint\', entering \'yes\'...");

        # Enter 'yes'
        unless ( $self->{conn}->print('yes') ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter \'yes\' for adding RSA key fingerprint to the list of known hosts.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered \'yes\' for adding RSA key fingerprint to the list of known hosts.");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/[P|p]assword:/',
                                    '-match'   => '/\[error\]/',
                                    '-match'   => $sessionDetails{DEBUGSHELL}->{prompt},
                                    '-errmode' => 'return',
                                );
    }

    # Match dsh 'Password' prompt
    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Matched dsh \'Password:\' prompt");

        # Enter 'dsh' password
        unless ( $self->{conn}->print($a{'-dshPassword'}) ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter dsh password \'$a{'-dshPassword'}\'");
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered dsh password \$a{'-dshPassword'}");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/linuxadmin/i',
                                    '-match'   => '/Permission denied/i',
                                    '-match'   => $sessionDetails{DEBUGSHELL}->{prompt},
                                    '-errmode' => 'return',
                                );
        if ( $match =~ m/linuxadmin/i ) {
            $retValue = 1;
            $logger->debug(" $a{'-testId'} SUCCESS: accepted dsh password \$a{'-dshPassword'}.");
        }
        elsif ( $match =~ m/Permission denied/i ) {
            $logger->error(" $a{'-testId'} ERROR: did not accept dsh password \'$a{'-dshPassword'}, failed:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }
        else {
            $logger->error(" $a{'-testId'} ERROR: Failed after entering dsh password:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }
    }
    elsif ( $match =~ $sessionDetails{DEBUGSHELL}->{pattern} ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: command \'$cmd\' accepted without dsh password.");
    }
    elsif ( $match =~ m/\[error\]/ ) {
        $logger->error(" $a{'-testId'} ERROR: command \'$cmd\' failed:--\nprematch:\t$prematch\nmatch:\t$match\n");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");
    }

    if ( $retValue == 1 ) {
        # Set CONFMODE - prompt & session type
        $self->{PROMPT} = $sessionDetails{DEBUGSHELL}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});
        $self->{SESSIONTYPE} = $sessionDetails{DEBUGSHELL}->{session};

        $self->{ENTERED_DEBUG} = 1;
        $self->{ENTERED_CLI}   = 0;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 enterLinuxShellViaDshBecomeRoot()

DESCRIPTION:

 The function is used to enter the linux shell (debug shell) via the 'dsh' command
 available in the SIMS ADMIN/CLI commands.
 Once at the linux shell it will issue the 'su -' command to become root.
 It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. SIMS 'root' password (needed for 'unhide debug' and 'root' session login)
 2. SIMS 'dsh' password (needed for 'dsh' command)
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 4. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 enterLinuxShellViaDsh()

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    unless ( $SimsAdminObj->enterLinuxShellViaDshBecomeRoot(
                            '-dshPassword'  => $SimsAdminObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{DSHPASSWD},
                            '-rootPassword' => $SimsAdminObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD},
                            '-timeout'      => 30,
                            '-testId'       => '111111',
                        ) ) {
        my $errMessage = "  FAILED - to enter root via debug shell (dsh) session.";
        $logger->error("$errMessage");
        return 0;
    }

=cut

#################################################
sub enterLinuxShellViaDshBecomeRoot {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'enterLinuxShellViaDshBecomeRoot()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    # Check Mandatory Parameters
    foreach ( qw/ rootPassword dshPassword / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }
 
    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Are we in ADMIN/CLI session? to enter 'Debug Shell' . . .
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ADMIN}->{session} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in ADMIN\/CLI session, to enter \'configure\' mode.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    # Execute enterLinuxShellViaDsh() to enter debug shell
    unless ( $self->enterLinuxShellViaDsh(
                            '-dshPassword'  => $a{'-dshPassword'},
                            '-rootPassword' => $a{'-rootPassword'},
                            '-timeout'      => $a{'-timeout'},
                            '-testId'       => $a{'-testId'},
                        ) ) {
        my $errMessage = " $a{'-testId'} ERROR: executing \'enterLinuxShellViaDsh()\'";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed \'enterLinuxShellViaDsh()\'.");

    # Become Root using `su -`
    my $cmd = 'su -';
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/[P|p]assword:/',
                                    '-match'   => $sessionDetails{ROOT}->{prompt},
                                    '-errmode' => 'return',
                                );

    # Match root/su 'Password' prompt
    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(" $a{'-testId'} SUCCESS: Matched root\/su \'Password:\' prompt");

        # Enter 'root/su' password
        unless ( $self->{conn}->print($a{'-rootPassword'}) ) {
            $logger->error(" $a{'-testId'} ERROR: Cannot enter root\/su password \'$a{'-rootPassword'}\'");
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: entered root\/su password \$a{'-rootPassword'}");

        ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => '/Authentication failure/i',
                                    '-match'   => $sessionDetails{ROOT}->{prompt},
                                    '-errmode' => 'return',
                                );
        if ( $match =~ $sessionDetails{ROOT}->{pattern} ) {
            $retValue = 1;
            $logger->debug(" $a{'-testId'} SUCCESS: accepted root\/su password \$a{'-rootPassword'}.");
        }
        elsif ( ( $match =~ m/Authentication failure/i ) ||
                ( $match =~ $sessionDetails{DEBUGSHELL}->{pattern} ) ) {
            $logger->error(" $a{'-testId'} ERROR: did not accept root\/su password \'$a{'-rootPassword'}, failed:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }
        else {
            $logger->error(" $a{'-testId'} ERROR: Failed after entering root\/su password:--\nprematch:\t$prematch\nmatch:\t$match\n");
        }
    }
    elsif ( $match =~ $sessionDetails{ROOT}->{pattern} ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: command \'$cmd\' accepted without root\/su password.");
    }
    elsif ( $match =~ $sessionDetails{DEBUGSHELL}->{pattern} ) {
        $logger->error(" $a{'-testId'} ERROR: Failed entering root\/su via dsh:--\nprematch:\t$prematch\nmatch:\t$match\n");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");
    }

    if ( $retValue == 1 ) {
        # Set CONFMODE - prompt & session type
        $self->{PROMPT} = $sessionDetails{ROOT}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});
        $self->{SESSIONTYPE} = $sessionDetails{ROOT}->{session};

        $self->{ENTERED_ROOT_VIA_DSH} = 1;
        $self->{ENTERED_DEBUG} = 0;
        $self->{ENTERED_CLI}   = 0;
    }
    else {
        if ( $self->{SESSIONTYPE} eq $sessionDetails{DEBUG}->{session} ) {
            $logger->warn (" $a{'-testId'} Inside \'$self->{SESSIONTYPE}\' session, so leaving back to ADMIN\/CLI session");
            #################################################
            # TBD
            #################################################
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 leaveDSHtoAdminMode()

DESCRIPTION:

 The function is used to leave the linux shell (debug shell) via the 'logout' command
 and return to ADMIN/CLI session. It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    unless ( $SimsAdminObj->leaveDSHtoAdminMode( 
                                '-timeout' => 20,
                                '-testId'  => '111111',
                            ) ) {
        my $errMessage = "  FAILED - to leave debug shell (dsh) session.";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Leave debug shell (dsh) session.");

=cut

#################################################
sub leaveDSHtoAdminMode {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'leaveDSHtoAdminMode()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Are we already in a debug/dsh session? - to leave the session
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{DEBUGSHELL}->{session} ) &&
             ( $self->{ENTERED_DEBUG} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in debug\/dsh session to leave.");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    my $cmd = 'logout';
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => $sessionDetails{ADMIN}->{prompt},
                                    '-errmode' => 'return',
                                );

    if ( $match =~ $sessionDetails{ADMIN}->{pattern} ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: back to ADMIN\/CLI session.");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");
    }

    if ( $retValue == 1 ) {
        # Set DEBUG Shell - prompt & session type
        $self->{PROMPT} = $sessionDetails{ADMIN}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});
        $self->{SESSIONTYPE} = $sessionDetails{ADMIN}->{session};

        $self->{ENTERED_ROOT_VIA_DSH} = 0;
        $self->{ENTERED_DEBUG}  = 0;
        $self->{ENTERED_CONFIG} = 0;
        $self->{ENTERED_CLI}    = 1;
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: still in \'$self->{SESSIONTYPE}\' session.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 leaveSUtoAdminMode()

DESCRIPTION:

 The function is used to leave root/su session to linux shell (debug shell) via the 'logout' command
 and then return to ADMIN/CLI session using leaveDSHtoAdminMode().
 It will then return 1 or 0 depending on this.

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID

PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 leaveDSHtoAdminMode()

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    unless ( $SimsAdminObj->leaveSUtoAdminMode(
                                '-timeout' => 20,
                                '-testId'  => '111111',
                            ) ) {
        my $errMessage = "  FAILED - to leave root\/su to ADMIN session.";
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Leave root\/su to ADMIN session.");

=cut

#################################################
sub leaveSUtoAdminMode {
#################################################

    my ($self, %args) = @_;
    my $subName       = 'leaveSUtoAdminMode()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # Are we already in a root/su session? - to leave the session
    unless ( ( $self->{SESSIONTYPE} eq $sessionDetails{ROOT}->{session} ) &&
             ( $self->{ENTERED_ROOT_VIA_DSH} == 1 ) ) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(" $a{'-testId'} ERROR: Session type: \'$self->{SESSIONTYPE}\'.");
        $logger->error(" $a{'-testId'} ERROR: Not in root session(i.e. entered via dsh).");
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }

    # $self->_info( '-subName' => $subName, %a );

    my $cmd = 'logout';
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(" $a{'-testId'} ERROR: Cannot issue command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed command \'$cmd\'");

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    '-match'   => $sessionDetails{DEBUGSHELL}->{prompt},
                                    '-errmode' => 'return',
                                );

    if ( $match =~ $sessionDetails{DEBUGSHELL}->{pattern} ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: back to dsh shell.");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Did not match expected prompt after command \'$cmd\':--\nprematch:\t$prematch\nmatch:\t$match\n");
    }

    if ( $retValue == 1 ) {
        # Set DEBUG Shell - prompt & session type
        $self->{PROMPT} = $sessionDetails{DEBUGSHELL}->{prompt};
        $self->{conn}->prompt($self->{PROMPT});
        $self->{SESSIONTYPE} = $sessionDetails{DEBUGSHELL}->{session};

        $self->{ENTERED_ROOT_VIA_DSH} = 0;
        $self->{ENTERED_DEBUG}  = 1;
        $self->{ENTERED_CONFIG} = 0;
        $self->{ENTERED_CLI}    = 0;

        unless ( $self->leaveDSHtoAdminMode( %a ) ) {
            $retValue = 0;
            $logger->error(" $a{'-testId'} FAILED: leaveDSHtoAdminMode()");
        }
        $logger->debug(" $a{'-testId'} SUCCESS - Executed CLI command \'$cmd\'.")
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: still in \'$self->{SESSIONTYPE}\' session.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 getCurrentEventLogFile()

DESCRIPTION:

 The subroutine is used to retrieve the current event log file with extention ACT/DBG/SEC/SYS/TRC.
 It will return current event log file name or 0
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Current Event Log File extention - i.e. ACT(acct)/DBG(debug)/SEC(Security))/SYS(system)/TRC(trace)
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()

OUTPUT:
 
 0                - Failure
 $curEventLogFile - Success


EXAMPLE:

    my $curEventLogFile = $SimsAdminObj->getCurrentEventLogFile(
                                    '-fileExtn' => 'DBG',
                                    '-timeout'  => 30,
                                    '-testId'   => $TestId,
                        );
    unless ( $curEventLogFile ) {
        $errorMsg = "  FAILED - to retrieve current event log file extn type \'DBG\'.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return 0;
    }
    $logger->debug("  SUCCESS - retrieved current event log file extn type \'DBG\' \'$curEventLogFile\'."); 

=cut

#################################################
sub getCurrentEventLogFile {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getCurrentEventLogFile()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ fileExtn / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #---------------------
    # Execute CLI command
    #---------------------
    my $cmd = "show table oam eventLog typeStatus " . $eventLogFileTypeDetails{$a{'-fileExtn'}} . ' currentFile';

    unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to execute cmd \'$cmd\'");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->info(" $a{'-testId'} SUCCESS: executed cmd \'$cmd\'");

    #--------------------------------
    # Parse command output/result
    #--------------------------------
    my $curEventLogFile;
    foreach ( @{ $self->{CMDRESULTS} } ) {
        #      currentFile    1000008.DBG;
        if ( /^currentFile\s+(\w+\.$a{'-fileExtn'});$/ ) {
            $curEventLogFile = $1;
            last;
        }
        else {
            next;
        }
    }

    unless ( defined $curEventLogFile ) {
        $logger->error(" $a{'-testId'} ERROR: to retrieve current event log file with extn \'$a{'-fileExtn'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    else {
        $logger->debug(" $a{'-testId'} SUCCESS: retrieved current event log file \'$curEventLogFile\'");
        $retValue = 1;
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $curEventLogFile;
    }
}


#########################################################################################################

=head1 getSimsCurrentEventLogFiles()

DESCRIPTION:

 The subroutine is used to retrieve all the SIMS current event log files
 of type acct/debug/security/system/trace.
 It will return list of ACT, DBG, SEC, SYS, TRC event log file names or empty list

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()

OUTPUT:
 
 FAILURE - returns a empty list
 SUCCESS - returns a list of ACT, DBG, SEC, SYS, TRC event log file names


EXAMPLE:

    my @simsCurEventLogFiles;
    unless ( @simsCurEventLogFiles = $SimsAdminObj->getSimsCurrentEventLogFiles(
                                            '-timeout'  => 30,
                                            '-testId'   => $TestId,
                                        ) ) {
        $errorMsg = "  FAILED - to retrieve all SIMS current event log file(s).";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return 0;
    }
    $logger->debug("  SUCCESS - Retrieved all SIMS current event log files (@simsCurEventLogFiles).");

=cut

#################################################
sub getSimsCurrentEventLogFiles {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getSimsCurrentEventLogFiles()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    my @logFiles;
    my $totalLogFiles;
    #-----------------------------------------
    # Retrieve current Event Log File name(s)
    #-----------------------------------------
    while ( my($key,$value) = each %eventLogFileTypeDetails ) {
        my $curEventLogFile = $self->getCurrentEventLogFile(
                                        '-fileExtn' => $key,
                                        '-timeout'  => $a{'-timeout'},
                                        '-testId'   => $a{'-testId'},
                            );
        unless ( $curEventLogFile ) {
            $logger->error(" $a{'-testId'} ERROR: to retrieve current event log file extn type \'$key\'.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: retrieved current event log file extn type \'$key\' \'$curEventLogFile\'.");
        $totalLogFiles = push (@logFiles, $curEventLogFile);
    }

    my $eventLogTypes = scalar (keys %eventLogFileTypeDetails);
    if ( $eventLogTypes == $totalLogFiles ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: Retrieved all SIMS current event log files \'@logFiles\'.");
    }
    else {
        undef @logFiles;
        $logger->error(" $a{'-testId'} ERROR: unable to retrieve all SIMS current event log files.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return (@logFiles);

}


#########################################################################################################

=head1 rollOverSimsEventLogFilesNow()

DESCRIPTION:

 The subroutine is used to rollover all the SIMS event log files of type acct/debug/security/system/trace.
 It will return 1 on successful rollover of all SIMS event log files or 0
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 2. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()
 enterConfigureMode()
 leaveConfigureMode()

OUTPUT:
 
 0 - Failure
 1 - Success


EXAMPLE:

    unless ( $SimsAdminObj->rollOverSimsEventLogFilesNow(
                                    '-timeout'  => 30,
                                    '-testId'   => $TestId,
                        ) ) {
        $errorMsg = "  FAILED - to rollover all SIMS event log file(s).";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return 0;
    }
    $logger->debug("  SUCCESS - rollover all SIMS event log file(s)."); 

=cut

#################################################
sub rollOverSimsEventLogFilesNow {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'rollOverSimsEventLogFilesNow()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    my (%oldLogFiles, %newLogFiles);
    #-----------------------------------------
    # Retrieve current Event Log File name(s)
    #-----------------------------------------
    while ( my($key,$value) = each %eventLogFileTypeDetails ) {
        my $curEventLogFile = $self->getCurrentEventLogFile(
                                        '-fileExtn' => $key,
                                        '-timeout'  => $a{'-timeout'},
                                        '-testId'   => $a{'-testId'},
                            );
        unless ( $curEventLogFile ) {
            $logger->error(" $a{'-testId'} ERROR: to retrieve current event log file extn type \'$key\'.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: retrieved current event log file extn type \'$key\' \'$curEventLogFile\'.");
        $oldLogFiles{$key} = $curEventLogFile;
    }

    #-----------------------------------------
    # Roll-Over all SIMS Event Log Files
    #-----------------------------------------
    unless ( $self->enterConfigureMode(
                            '-mode'    => 'private',
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to enter Configure(private) mode.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: Entered Configure(private) mode.");

    # request oam eventLog typeAdmin debug rolloverLogNow
    while ( my($key,$value) = each %eventLogFileTypeDetails ) {
        my $cmd = "request oam eventLog typeAdmin $value rolloverLogNow";

        unless ( $self->execCliCmd(
                                '-cmd'     => $cmd,
                                '-timeout' => $a{'-timeout'},
                                '-testId'  => $a{'-testId'},
                            ) ) {
            $logger->error(" $a{'-testId'} ERROR: to execute cmd \'$cmd\'");
            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }
        $logger->info(" $a{'-testId'} SUCCESS: executed cmd \'$cmd\'");

        # Parse command output/result
        my $rolloverSuccessFlag = 0;
        foreach ( @{ $self->{CMDRESULTS} } ) {
            #      Rollover Successful
            if ( /^Rollover Successful$/ ) {
                $rolloverSuccessFlag = 1;
                last;
            }
            else {
                next;
            }
        }

        unless ( $rolloverSuccessFlag == 1 ) {
            $logger->error(" $a{'-testId'} ERROR: to rollover \'$key\' event log file.");

            unless ( $self->leaveConfigureMode(
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
                $logger->error(" $a{'-testId'} ERROR: to leave Configure (private) mode.");
                $logger->debug(' <-- Leaving Sub [0]');
                return 0;
            }
            #$logger->debug(" $a{'-testId'} SUCCESS - Leave Configure (private\/exclusive) mode.");

            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }
        else {
            $logger->debug(" $a{'-testId'} SUCCESS: rollover \'$key\' event log file.");
        }
    }

    unless ( $self->leaveConfigureMode(
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to leave Configure (private) mode.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: Leave Configure (private\/exclusive) mode.");

    #-----------------------------------------
    # Retrieve New Event Log File name(s)
    # after Roll-Over
    #-----------------------------------------
    while ( my($key,$value) = each %eventLogFileTypeDetails ) {
        my $curEventLogFile = $self->getCurrentEventLogFile(
                                        '-fileExtn' => $key,
                                        '-timeout'  => $a{'-timeout'},
                                        '-testId'   => $a{'-testId'},
                            );
        unless ( $curEventLogFile ) {
            $logger->error(" $a{'-testId'} ERROR: to retrieve new event log file extn type \'$key\'.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: retrieved new event log file extn type \'$key\' \'$curEventLogFile\'.");
        $newLogFiles{$key} = $curEventLogFile;
    }

    #---------------------------------------------------------
    # Verify rollover successful for all event log file types
    #---------------------------------------------------------
    my $rolloverFailFlag = 0;
    while ( my($key,$value) = each %eventLogFileTypeDetails ) {
        if( defined $oldLogFiles{$key} && defined $newLogFiles{$key} ) {
            if ( $oldLogFiles{$key} eq $newLogFiles{$key} ) {
                $rolloverFailFlag = 1;
                $logger->error(" $a{'-testId'} ERROR: New rollover and Old event log file are same $oldLogFiles{$key}.");
                last;
            }
            else {
                $logger->debug(" $a{'-testId'} SUCCESS: rollover for $key - old ($oldLogFiles{$key}) new ($newLogFiles{$key}) event log files.");
            }
        }
        else {
            $rolloverFailFlag = 1;
        }
    }

    unless ( $rolloverFailFlag ) {
        $retValue = 1;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}


#########################################################################################################

=head1 rollOverEventLogFile()

DESCRIPTION:

 The subroutine is used to rollover SIMS event log file of extention type ACT/DBG/SEC/SYS/TRC.
 It will return 1 on successful rollover of SIMS event log file or 0
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Current Event Log File extention - i.e. ACT(acct)/DBG(debug)/SEC(Security))/SYS(system)/TRC(trace)
 2. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 3. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()
 enterConfigureMode()
 leaveConfigureMode()

OUTPUT:
 
 0 - Failure
 1 - Success


EXAMPLE:

    my $eventLogFileExtn = 'DBG';
    unless ( $SimsAdminObj->rollOverEventLogFile(
                                    '-fileExtn' => $eventLogFileExtn,
                                    '-timeout'  => 30,
                                    '-testId'   => $TestId,
                        ) ) {
        $errorMsg = "  FAILED - to rollover event log file ($eventLogFileExtn).";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return 0;
    }
    $logger->debug("  SUCCESS - rollover event log file ($eventLogFileExtn)."); 

=cut

#################################################
sub rollOverEventLogFile {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'rollOverEventLogFile()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ fileExtn / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    my ($oldEventLogFile, $newEventLogFile);
    #-----------------------------------------
    # Retrieve current Event Log File name(s)
    #-----------------------------------------
    $oldEventLogFile = $self->getCurrentEventLogFile( %a );
    unless ( $oldEventLogFile ) {
        $logger->error(" $a{'-testId'} ERROR: to retrieve event log file extn type \'$a{'-fileExtn'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: retrieved event log file extn type \'$a{'-fileExtn'}\' \'$oldEventLogFile\'.");

    #-----------------------------------------
    # Roll-Over all SIMS Event Log Files
    #-----------------------------------------
    unless ( $self->enterConfigureMode(
                            '-mode'    => 'private',
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to enter Configure(private) mode.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: Entered Configure(private) mode.");

    my $cmd = "request oam eventLog typeAdmin $eventLogFileTypeDetails{$a{'-fileExtn'}} rolloverLogNow";

    unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to execute cmd \'$cmd\'");
        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    $logger->info(" $a{'-testId'} SUCCESS: executed cmd \'$cmd\'");

    # Parse command output/result
    my $rolloverSuccessFlag = 0;
    foreach ( @{ $self->{CMDRESULTS} } ) {
        #      Rollover Successful
        if ( /^Rollover Successful$/ ) {
            $rolloverSuccessFlag = 1;
            last;
        }
        else {
            next;
        }
    }

    unless ( $rolloverSuccessFlag == 1 ) {
        $logger->error(" $a{'-testId'} ERROR: to rollover \'$a{'-fileExtn'}\' event log file.");

        unless ( $self->leaveConfigureMode(
                        '-timeout' => $a{'-timeout'},
                        '-testId'  => $a{'-testId'},
                    ) ) {
            $logger->error(" $a{'-testId'} ERROR: to leave Configure (private) mode.");
            $logger->debug(' <-- Leaving Sub [0]');
            return 0;
        }
        #$logger->debug(" $a{'-testId'} SUCCESS - Leave Configure (private) mode.");

        $logger->debug(' <-- Leaving Sub [0]');
        return $retValue;
    }
    else {
        $logger->debug(" $a{'-testId'} SUCCESS: rollover \'$a{'-fileExtn'}\' event log file.");
    }

    unless ( $self->leaveConfigureMode(
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: to leave Configure (private) mode.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: Leave Configure (private) mode.");

    #------------------------------------------------
    # wait for some time for new file to be created.
    #------------------------------------------------
    sleep (5);

    #-----------------------------------------
    # Retrieve New Event Log File name(s)
    # after Roll-Over
    #-----------------------------------------
    $newEventLogFile = $self->getCurrentEventLogFile( %a );
    unless ( $newEventLogFile ) {
        $logger->error(" $a{'-testId'} ERROR: to retrieve new event log file extn type \'$a{'-fileExtn'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
        return 0;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: retrieved new event log file extn type \'$a{'-fileExtn'}\' \'$newEventLogFile\'.");

    #---------------------------------------------------------
    # Verify rollover successful for event log file type
    #---------------------------------------------------------
    if ($oldEventLogFile ne $newEventLogFile) {
        $logger->debug(" $a{'-testId'} SUCCESS: rollover for $a{'-fileExtn'} - old ($oldEventLogFile) new ($newEventLogFile) event log files.");
        $retValue = 1;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 parseLogFile()

DESCRIPTION:

 The subroutine is used to parse given log file for a particular component and list of patterns.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Path      - Log file path on SIMS
 2. file      - Log file name on SIMS
 3. Component - Component log to be searched in log file i.e. PES etc
 4. Patterns  - list of patterns to be searched in the log file within given component
 5. Timeout value (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 6. TestID (Optional) - i.e. TMS Test Case (6 digits) ID2.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 /bin/ls
 /bin/grep

OUTPUT:
 
 1 - Success
 0 - Failure


EXAMPLE:

    # Get Current DEBUG event log file for parsing
    my $curDebugEventLogFile = $SimsAdminObj->getCurrentEventLogFile(
                                    '-fileExtn' => 'DBG',
                                    '-timeout'  => 30,
                                    '-testId'   => $TestId,
                        );
    unless ( $curDebugEventLogFile ) {
        $errorMsg = "  FAILED - to retrieve current DEBUG event log file.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - retrieved current DEBUG event log file extn type \'DBG\' \'$curDebugEventLogFile\'.");

    # Parse Current DEBUG event log file
    my ( $component, $patternList );
    $component   = 'PES';
    $patternList = [
        'Start SsProtocolAdapterIn at time',
        'ProtocolAdapterIn Normal block received hop',
        'SCPA message received',
        '[Success] Decoding Primitive',
    ];

    unless ( $SimsRootObj->parseLogFile(
                            '-path'      => '/var/log/sonus/sbx/evlog',
                            '-file'      => $curDebugEventLogFile,
                            '-component' => $component,
                            '-patterns'  => $patternList,
                            '-timeout'   => 30,
                            '-testId'    => $TestId,
                        ) ) {
        $errorMsg = "  FAILED - parsing log file ($curDebugEventLogFile) for component \'$component\'.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - parsed log file ($curDebugEventLogFile) for component \'$component\'.");

=cut

#################################################
sub parseLogFile {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'parseLogFile()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ path file component patterns / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    unless ( @{ $args{'-patterns'} } ) {
        $logger->error("  ERROR: The mandatory argument \'-patterns\' has empty list of patterns.");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    #$self->_info( '-subName' => $subName, %a );

    my $logFile = $a{'-path'} . '/' . $a{'-file'};
    #---------------------
    # Open & Read Log File
    #---------------------
    my $cmd = '/bin/ls ' . "$logFile";
    $logger->debug(" $a{'-testId'} going to execute command \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->error(" $a{'-testId'} ERROR: The log file ($logFile) is not present.");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: The log file ($logFile) is present.");

    $cmd = '/bin/grep ' . "\"$a{'-component'}\" $logFile";
    $logger->debug(" $a{'-testId'} Going to grep log file \'$logFile\' for component \'$a{'-component'}\', using cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: Executed SHELL command \'$cmd\'.");

    my @componentData = @{ $self->{CMDRESULTS} };

    unless ( @componentData ) {
        $logger->error(" $a{'-testId'} ERROR: NO-MATCH for component ($a{'-component'}) in log file ($logFile).");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    chomp (@componentData);
    $logger->debug(" $a{'-testId'} SUCCESS: Lines in component data is \'$#componentData\'.");

    #--------------------------------------------
    # Parse list of patterns for given component
    #--------------------------------------------
    my $noMatchFlag = 0;
    foreach my $pattern ( @{$a{'-patterns'}} ) {
        $logger->debug(" $a{'-testId'} Checking pattern \'$pattern\' match for component ($a{'-component'}).");
        my @match = grep( /\Q$pattern\E/, @componentData );

        unless ( @match ) {
            $logger->error(" $a{'-testId'} ERROR: NO-MATCH Pattern \'$pattern\' not found.");
            $noMatchFlag = 1;
            last;
        }
        else {
            $logger->debug(" $a{'-testId'} SUCCESS: MATCH Pattern \'$pattern\' found $#match match(s).");
        }
    }

    unless ( $noMatchFlag ) {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: All pattern(s) matched for component ($a{'-component'}) in log file \'$logFile\'.");
    }
    else {
        $logger->error(" $a{'-testId'} ERROR: Not all pattern(s) matched for component ($a{'-component'}) in log file \'$logFile\'.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 clearCoreFiles()

DESCRIPTION:

 The subroutine is used to check for core file(s) if any in given path and remove the same.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Path      - Core path on SIMS
 5. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds
 6. TestID  (Optional) - i.e. TMS Test Case (6 digits) ID.


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 /bin/ls
 /bin/rm

OUTPUT:
 
 1 - Success - Core file(s) cleared
 0 - Failure


EXAMPLE:

    my $corePath = '/var/log/sonus/sbx/coredump';
    unless ( $SimsRootObj->clearCoreFiles(
                            '-path'      => $corePath,
                            '-timeout'   => 30,
                            '-testId'    => $TestId,
                        ) ) {
        $errorMsg = "  FAILED - clearing core file(s) in \'$corePath\'.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - Cleared Core file(s) in \'$corePath\'.");

=cut

#################################################
sub clearCoreFiles {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'clearCoreFiles()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ path / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-path'  => '/var/log/sonus/sbx/coredump',
        '-file'  => 'core.1.*',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Checking for Core path
    #-------------------------------------------------
    my $cmd = '/bin/ls ' . "$a{'-path'}";
    $logger->debug(" $a{'-testId'} Checking for Core path \'$a{'-path'}\', executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->error(" $a{'-testId'} ERROR: The core path \'$a{'-path'}\' not present.");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} The core path \'$a{'-path'}\' present.");

    my $coreFiles = $a{'-path'} . '/' . $a{'-file'};
    #-------------------------------------------------
    # Checking for Core file(s) Presence in given path
    #-------------------------------------------------
    $cmd = '/bin/ls ' . "$coreFiles";
    $logger->debug(" $a{'-testId'} Checking for Core file(s) Presence in \'$a{'-path'}\', executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->error(" $a{'-testId'} SUCCESS: The core file(s) not present in \'$a{'-path'}\'.");
        $retValue = 1;
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} The core file(s) present in \'$a{'-path'}\':--\n@{ $self->{CMDRESULTS}}\n");

    #-------------------------------------------------
    # Core file(s) Present in given path
    # So removing all core.1.* file(s)
    #-------------------------------------------------
    $cmd = '/bin/rm ' . "$coreFiles";
    $logger->debug(" $a{'-testId'} removing core file(s) in \'$a{'-path'}\', executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: removing core file(s), cmd \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: removed core file(s), cmd \'$cmd\'.");
    $retValue = 1;

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 checkForCoreFiles()

DESCRIPTION:

 The subroutine is used to check for core file(s) in given path,
 if any found move core file prefixing with Test ID
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. Path   - Core path on SIMS
 2. TestID - i.e. TMS Test Case (6 digits) ID.
 3. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 /bin/ls
 /bin/mv

OUTPUT:
 
 1 - Success - Core file(s) found, and moved.
 0 - Failure


EXAMPLE:

    my $corePath = '/var/log/sonus/sbx/coredump';
    unless ( $SimsRootObj->checkForCoreFiles(
                            '-path'      => $corePath,
                            '-testId'    => $TestId,
                            '-timeout'   => 30,
                        ) ) {
        $errorMsg = "  FAILED - clearing core file(s) in \'$corePath\'.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - Cleared Core file(s) in \'$corePath\'.");

=cut

#################################################
sub checkForCoreFiles {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'checkForCoreFiles()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Check Mandatory Parameters
    ###############################
    foreach ( qw/ path testId / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for \'-$_\' has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        '-path'  => '/var/log/sonus/sbx/coredump',
        '-file'  => 'core.1.*',
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Checking for Core path
    #-------------------------------------------------
    my $cmd = '/bin/ls ' . "$a{'-path'}";
    $logger->debug(" $a{'-testId'} Checking for Core path \'$a{'-path'}\', executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->error(" $a{'-testId'} ERROR: The core path \'$a{'-path'}\' not present.");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} The core path \'$a{'-path'}\' present.");

    #-------------------------------------------------
    # Checking for Core file(s) Presence in given path
    #-------------------------------------------------
    $cmd = '/bin/ls -1 ' . $a{'-path'} . '/' . $a{'-file'};
    $logger->debug(" $a{'-testId'} Checking for Core file(s) Presence in \'$a{'-path'}\', executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        # Core File(s) not present - return FAILURE
        $logger->error(" $a{'-testId'} ERROR: executing SHELL command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->error(" $a{'-testId'} ERROR: The core file(s) not present in \'$a{'-path'}\'.");
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $retValue;
    }
    # Core File(s) present - return SUCCESS
    $retValue = 1;
    $logger->debug(" $a{'-testId'} The core file(s) present in \'$a{'-path'}\':--\n@{ $self->{CMDRESULTS}}\n");

    #-------------------------------------------------
    # Core file(s) Present in given path
    # So moving all core.1.* file(s)
    #-------------------------------------------------
    my $index = 1;
    foreach my $core ( @{ $self->{CMDRESULTS} } ) {
        my $newFile;
        if ( $core =~ /($a{'-path'}\/)(core.1.\S+)$/ ) {
            $newFile = $1 . $a{'-testId'} . '_' . $2;
        }
        else {
            $newFile = $a{'-path'} . '/' . $a{'-testId'} . '_core_' . $index;
        }
        $cmd = '/bin/mv ' . "$core $newFile";
        $logger->debug(" $a{'-testId'} moving [$index] core ($core) file, executing cmd \'$cmd\'.");

        unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: moving [$index] core ($core) file, cmd \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        }
        $logger->debug(" $a{'-testId'} SUCCESS: moved [$index] core ($core) file.");
        $index++;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 getSimsUsers()

DESCRIPTION:

 The subroutine is used to retrieve SIMS users using CLI command,
 'request sims users showRegImsUsers'
 if command results have users, the command results are parsed and return list of hash reference.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCliCmd()
 _parseCliCmdResults()

OUTPUT:
 
 1 - Success - i.e. retrieve SIMS users
 0 - Failure

 NOTE: on SUCCESS returns reference to Hash containing each SIMS user details.

EXAMPLE:

    my ( $result, $AOHrefData ) = $SimsAdminObj->getSimsUsers(
                                        '-testId'    => $TestId,
                                        '-timeout'   => 30,
                                    );
    unless ( $result ) {
        $errorMsg = "  FAILED - getSimsUsers().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    else {
        $logger->debug("  SUCCESS - getSimsUsers().");
        $testStatus->{result} = 1;
    }

    #---------------------------
    # Print the parsed output
    #---------------------------
    my $rowIndex = 0;
    foreach my $dataHash_ref ( @{ $AOHrefData } ) {
        my $colIndex = 0;
        while ( my($key, $value) = each %{ $dataHash_ref } ) {
            $logger->debug(" SUCCESS: Row[$rowIndex], column[$colIndex] :: key ($key), value ($value).");
            $colIndex++;
        }
        $rowIndex++;
    }


=cut

#################################################
sub getSimsUsers {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getSimsUsers()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Execute CLI command
    #-------------------------------------------------
    my $cmd = 'request sims users showRegImsUsers';
    $logger->debug(" $a{'-testId'} Getting SIMS users, executing cmd \'$cmd\'.");

    unless ( $self->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing CLI command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed CLI command \'$cmd\'.");

    #-------------------------------------------------
    # Check is users are provisioned in database
    #-------------------------------------------------
    foreach ( @{ $self->{CMDRESULTS} } ) {
        if ( /No Users/ ) {
            $logger->error(" $a{'-testId'} ERROR: \'No users\' provisioned.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    #-------------------------------------------------
    # parse CLI command results
    #-------------------------------------------------
    my ( $parseResult, $AOHrefData ) = $self->_parseCliCmdResults(
                            '-header'  => ['Private ID', 'Public ID', 'Contact'],
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        );
    unless ( $parseResult ) {
        $logger->error(" $a{'-testId'} ERROR: Parsing of CLI command \'$cmd\' output:--\n@{ $self->{CMDRESULTS}}\n");
    }
    else {
        $retValue = 1;
        $logger->debug(" $a{'-testId'} SUCCESS: Parsed CLI command \'$cmd\' output.");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return ( $retValue ) ? ( $retValue, $AOHrefData ) : ( $retValue );
}

#######################################################################################################

sub _parseCliCmdResults {

    my  ($self, %args ) = @_ ;
    my  $subName = '_parseCliCmdResults()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    my $rowHeaderFoundFlag = 0;
    my ( %header, @AOH_Data );
    my ( $numOfColumns );

    #-------------------------------------------------
    # Parse for number of rows received.
    #-------------------------------------------------
    my @cmdResults = @{ $self->{CMDRESULTS} };

    unless ( @cmdResults ) {
        # i.e. zero rows in output, so no meaning in processing further.
        $logger->error(" $a{'-testId'} ERROR: CLI command output has '0' rows - FAILED.");
        $logger->debug(" <-- Leaving Sub [0]");
        return ( $retValue );
    }

    my $headerFlag = 0;
    if ( defined $a{'-header'} ) {
        if ( @{$a{'-header'}} ) {
            $headerFlag = 1;

            my $count = 0;
            foreach my $data ( @{$a{'-header'}} ) {
                $data =~ s/^\s*//g; $data =~ s/\s*$//g;
                $header{$count++} = $data;
            }
            $numOfColumns = $count;
        }
    }

    # parsing of all rows of CLI command results.
    my $dataRowCount  = 0;
    foreach my $line ( @cmdResults ) {

        if ( ($line eq "") || ($line eq "\n") ) {
            # encountered empty line
            next;
        }

        if ( defined $line ) {
            if ( $line =~ /^--[\-|\ ]*--$/ ) {
                # Header line found
                $rowHeaderFoundFlag = 1;
                next;
            }

            my @rowData = split ( /\s+/, $line );
            # Processing Header Row
            if ( ( $rowHeaderFoundFlag == 0 ) &&
                 ( $headerFlag == 0 ) &&
                 ( @rowData ) ) {
                $numOfColumns = scalar(@rowData);

                my $count = 0;
                foreach my $data ( @rowData ) {
                    $data =~ s/^\s*//g; $data =~ s/\s*$//g;
                    $header{$count++} = $data;
                }
                next;
            }
    
            # Processing Data Row(s)
            if ( ( $rowHeaderFoundFlag ) &&
                 ( @rowData ) &&
                 ( scalar(@rowData) == $numOfColumns ) ) {
                my $rec = {};
                $dataRowCount++;

                my $count = 0;
                foreach my $data (@rowData) {
                    $data =~ s/^\s*//g; $data =~ s/\s*$//g;
                    $rec->{$header{$count++}} = $data;
                }
                push ( @AOH_Data, $rec );
            }
        } # END - if line contains something . . .
    } # END - parsing of all rows of CLI command results.


    $logger->debug(" $a{'-testId'} Processed all rows received");
    if ( ( $dataRowCount ) == scalar(@AOH_Data) ) {
        $retValue = 1; # PASS
    }
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return ( $retValue ) ? ( $retValue, \@AOH_Data ) : ( $retValue );
}


#######################################################################################################

=head1 checkSbxProcessStatus()

DESCRIPTION:

 The subroutine is used to retrieve status of SBX process by executing from root login
 'service sbx status'
 the command results are parsed for current process and its status.
 If given list of process and/or expected status are checked against current process & status.
 unless process status is not of expected status, sleeps for given interval and re-tries again.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. processList   (Optional) - List of processes whose status are required to be checked
                               if undefined by default all processes are checked for given status.
 2. ProcessStatus (Optional) - Required status of the processes, Default is 'running'
 3. RetryInterval (Optional) - Maximum number of retry attempts to be done to check for
                               success of given process status. Default is 6.
 4. RetryCount    (Optional) - Time interval required for re-trying next for service status.
                               Default is 6 Seconds
 5. TestID - i.e. TMS Test Case (6 digits) ID.
 6. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()

OUTPUT:
 
 1 - Success - i.e. retrieved status of SBX process
 0 - Failure

EXAMPLE:

    # to check for all process(s) are in 'running' status
    unless ( $SimsRootObj->checkSbxProcessStatus(
                            '-testId'    => $TestId,
                            '-timeout'   => 30,
                        ) ) {
        $errorMsg = "  FAILED - checkSbxProcessStatus().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - checkSbxProcessStatus().");

    # OR

    # to check for given process(s) are in 'stopped' status
    my $processList = [
        'Policy server DB',
        'asp_amf',
        'CE_2N_Comp_ChmProcess',
        'CE_2N_Comp_SmProcess',
        'CE_2N_Comp_CsgProcess_0',
        'CE_2N_Comp_DimaProcess',
        'CE_2N_Comp_SipeProcess',
    ];

    unless ( $SimsRootObj->checkSbxProcessStatus(
                            '-retryInterval' => 6,            # time interval between retries in seconds
                            '-retryCount'    => 6,            # no. of retries
                            '-processStatus' => 'stopped',    # expected process status
                            '-processList'   => $processList, # List of process to be checked
                            '-testId'    => $TestId,
                            '-timeout'   => 30,
                        ) ) {
        $errorMsg = "  FAILED - checkSbxProcessStatus().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - checkSbxProcessStatus().");


=cut

#################################################
sub checkSbxProcessStatus {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'checkSbxProcessStatus()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-retryInterval' => 6,         # time interval between retries in seconds
        '-retryCount'    => 6,         # no. of retries
        '-processStatus' => 'running', # expected process status
        '-processList'   => undef,     # List of process to be checked
        '-timeout' => $self->{DEFAULTTIMEOUT},
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Check for status of mentioned processes.
    #-------------------------------------------------
    my $cmdFailFlag    = 0;
    my $statusFailFlag = 0;

    my $loopIndex = 0;
    while ( $loopIndex < $a{'-retryCount'} ) {
        if ( $loopIndex ) {
            my $sleepTime = $loopIndex * $a{'-retryInterval'};
            $logger->debug(" $a{'-testId'} INFO: loop($loopIndex), all process are not in expected status($a{'-processStatus'}), sleeping for $sleepTime.");
            sleep ($sleepTime);
            $logger->debug(" $a{'-testId'} INFO: loop($loopIndex), out of sleep ($sleepTime).");
        }

        $cmdFailFlag = 0;
        #-------------------------------------------------
        # Execute Shell command
        #-------------------------------------------------
        my $cmd = 'service sbx status';
        $logger->debug(" $a{'-testId'} loop($loopIndex) Retrieving SBX process Status, executing cmd \'$cmd\'.");

        unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: loop($loopIndex) executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
            $cmdFailFlag = 1;
            last;
        }
        $logger->debug(" $a{'-testId'} SUCCESS: loop($loopIndex) executed Shell command \'$cmd\'.");

    
        #-------------------------------------------------
        # Parse command result for process name & status
        #-------------------------------------------------
        my %curProcessStatus;
        if ( @{ $self->{CMDRESULTS} } ) {
            foreach ( @{ $self->{CMDRESULTS} } ) {
            if ( /(asp_amf|CE_2N_Comp_\w+|Policy server DB)[\s\S\(\)]*\s+is\s+(\w+)/ ) {
                    $curProcessStatus{$1} = $2;
                }
            }
        }
        else {
            $logger->error(" $a{'-testId'} ERROR: loop($loopIndex) Result is empty for command \'$cmd\'");
            $cmdFailFlag = 1;
            last;
        }
    
        #-------------------------------------
        # check for processes defined by user
        # OR
        # check for all processes in SBX box
        #-------------------------------------
        $statusFailFlag = 0;
        my @processes = ();
        unless ( defined $a{'-processList'} ) {
            # Process List not provided, So check all process status
            @processes = keys( %curProcessStatus );
        }
        else { 
            @processes = @{ $a{'-processList'} }; 
        }

        #------------------------------------------------------
        # check current process status against expected status
        #------------------------------------------------------
        foreach my $process ( @processes ) { 
             if ( $curProcessStatus{$process} eq $a{'-processStatus'} ) {
                  $logger->debug(" $a{'-testId'} INFO: loop($loopIndex) Process \'$process\' is in expected \'$curProcessStatus{$process}\' status.");
             }
             else {
                  $logger->error(" $a{'-testId'} ERROR: loop($loopIndex) Process \'$process\' status expected \'$a{'-processStatus'}\' but in $curProcessStatus{$process}.");
                  $statusFailFlag = 1;
             }
        }

        #-----------------------------------------
        # If Processes are not in expected status
        # sleep for some time and try again.
        #-----------------------------------------
        unless( $statusFailFlag ) {
            $logger->debug(" $a{'-testId'} INFO: SUCCESSFUL - loop($loopIndex), all process are in expected status($a{'-processStatus'}).");
            last;
        }
        else {
            $loopIndex++;
        }
    }

    #-------------------------------------------------
    # parse CLI command results
    #-------------------------------------------------
    if ( ( $cmdFailFlag == 0 ) &&
         ( $statusFailFlag == 0 ) ) {
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 stopSbxService()

DESCRIPTION:

 The subroutine is used to stop SBX service by executing from root login
 'service sbx stop'.
 Then SBX process(s) are checked for 'stopped' status.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - Default 360 sec i.e. 6 mins


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 checkSbxProcessStatus()

OUTPUT:
 
 1 - Success - i.e. executed 'service sbx stop' and all SBX process(s) are in 'stopped' status.
 0 - Failure

EXAMPLE:

    #---------------------------------------------------
    # To Stop SBX Service and
    # ensure all SBX process(s) are in 'Stopped' status
    #---------------------------------------------------
    unless ( $SimsRootObj->stopSbxService(
                            '-testId'  => $TestId,
                            '-timeout' => 480, # Default 360 sec i.e. 6 mins
                        ) ) {
        $errorMsg = "  FAILED - stopSbxService().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - stopSbxService().");

=cut

#################################################
sub stopSbxService {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'stopSbxService()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => 360, # seconds i.e. 6 mins
        '-testId'  => '',
    );

    if ( $args{'-timeout'} < $a{'-timeout'} ) {
        $logger->warn("  WARN: The optional argument \'-timeout\' is ($args{'-timeout'}) i.e. less than default value $a{'-timeout'}.");
        $args{'-timeout'} = $a{'-timeout'};
        $logger->warn("  WARN: The optional argument \'-timeout\' is set to default value $args{'-timeout'}.");
    }

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-----------------------------------------------------
    # Pre-check for all process(s) are in 'stopped' status
    #-----------------------------------------------------
    if ( $self->checkSbxProcessStatus(
                    '-retryCount'    => 1,            # no. of retries
                    '-processStatus' => 'stopped',    # expected process status
                    '-timeout'       => $self->{DEFAULTTIMEOUT},
                    '-testId'        => $a{'-testId'},
                ) ) {
        $logger->debug(" $a{'-testId'} INFO: All process(s) are already in expected \'stopped\' status.");
        $retValue = 1;
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    #-------------------------------------------------
    # Execute Shell command
    #-------------------------------------------------
    my $cmd = 'service sbx stop';
    $logger->debug(" $a{'-testId'} Stopping SBX process(s), executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                    '-cmd'     => $cmd,
                    '-timeout' => $a{'-timeout'},
                    '-testId'  => $a{'-testId'},
                ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");

        #-------------------------------------------------------------
        # Check if SBX 'Policy server DB' process is in running state
        # which can cause shell status return code "127"
        #-------------------------------------------------------------
        $logger->debug(" $a{'-testId'} Checking for SBX process \'Policy server DB\' in \'running\' status.");
        my $processList = [ 'Policy server DB', ];

        if ( $self->checkSbxProcessStatus(
                    '-retryCount'    => 1,            # no. of retries
                    '-processStatus' => 'running',    # expected process status
                    '-processList'   => $processList, # List of process to be checked
                    '-timeout'       => $self->{DEFAULTTIMEOUT},
                    '-testId'        => $a{'-testId'},
                ) ) {
            $logger->debug(" $a{'-testId'} INFO: SBX process \'Policy server DB\' in \'running\' status.");

            #-------------------------------------------------
            # Re-Try to stop the SBX service again.
            #-------------------------------------------------
            $logger->debug(" $a{'-testId'} Re-Trying: Stopping SBX process(s), executing cmd \'$cmd\'.");
            unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
                $logger->error(" $a{'-testId'} ERROR: Re-Trying to stop SBX service, using cmd \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
                $logger->debug(" <-- Leaving Sub [0]");
                return $retValue;
            }
            else {
                $logger->debug(" $a{'-testId'} SUCCESS: Re-Trying to stop SBX service, using cmd \'$cmd\'");
            }
        }
        else {
            $logger->error(" $a{'-testId'} ERROR: SBX process \'Policy server DB\' not in \'running\' status.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed Shell command \'$cmd\'.");

    #-------------------------------------------------
    # Expected Shell command response(s)
    #-------------------------------------------------
    my @cmdResponse = (
        'Stopping asp:',
        'INFO Stopping AMF...',
        'INFO Stopping AMF watchdog...',
        'INFO Waiting for AMF to shutdown...',
        'Stopping orphaned confd...',
        'Stopping policy server DB',
        'Unloading Sonus KLMs',
        'Removing shared memory sections',
        'Removing semaphores',
    );
    
    #-------------------------------------------------
    # parse Shell command results
    #-------------------------------------------------
    my $grepFailFlag = 0;
    foreach my $response ( @cmdResponse ) {
        unless ( grep( /\Q$response\E/, @{ $self->{CMDRESULTS} } ) ) {
            $logger->error(" $a{'-testId'} ERROR: string \'$response\' not present in command \'$cmd\' response:--\n@{ $self->{CMDRESULTS} }\n");
            $grepFailFlag = 1; # Failure
            last;
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: string \'$response\' present in command response.");
        }
    }
    
    my $StatusFailFlag = 0;
    #-----------------------------------------------------
    # to check for all process(s) are in 'stopped' status
    #-----------------------------------------------------
    unless ( $grepFailFlag ) {
        unless ( $self->checkSbxProcessStatus(
                            '-retryCount'    => 10,   # no. of retries
                            '-retryInterval' => 10,   # time interval between retries in seconds
                            '-processStatus' => 'stopped',    # expected process status
                            '-timeout'       => $self->{DEFAULTTIMEOUT},
                            '-testId'        => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: All process(s) are not in expected \'stopped\' status.");
            $StatusFailFlag = 1; # Failure
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: All process(s) are in expected \'stopped\' status.");
        }
    }

    #-----------------------------------------------------------------------------
    # return success if 
    # - all expected responses are found in shell command results and
    # - all process are in expected status i.e. 'stopped'
    #-----------------------------------------------------------------------------
    if ( ( $grepFailFlag == 0 ) &&
         ( $StatusFailFlag == 0 ) ) {
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 startSbxService()

DESCRIPTION:

 The subroutine is used to start SBX service by executing from root login
 'service sbx start'.
 Then SBX process(s) are checked for 'running' status.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - Default 360 sec i.e. 6 mins


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 checkSbxProcessStatus()

OUTPUT:
 
 1 - Success - i.e. executed 'service sbx start' and all SBX process(s) are in 'running' status.
 0 - Failure

EXAMPLE:

    #---------------------------------------------------
    # To Start SBX Service and
    # ensure all SBX process(s) are in 'running' status
    #---------------------------------------------------
    unless ( $SimsRootObj->startSbxService(
                            '-testId'  => $TestId,
                            '-timeout' => 480, # Default 360 sec i.e. 6 mins
                        ) ) {
        $errorMsg = "  FAILED - startSbxService().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - startSbxService().");

=cut

#################################################
sub startSbxService {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'startSbxService()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => 360, # seconds i.e. 6 mins
        '-testId'  => '',
    );

    if ( ( defined $args{'-timeout'} ) &&
         ( $args{'-timeout'} < $a{'-timeout'} ) ) {
        $logger->warn("  WARN: The optional argument \'-timeout\' is ($args{'-timeout'}) i.e. less than default value $a{'-timeout'}.");
        $args{'-timeout'} = $a{'-timeout'};
        $logger->warn("  WARN: The optional argument \'-timeout\' is set to default value $args{'-timeout'}.");
    }

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-----------------------------------------------------
    # Pre-check for all process(s) are in 'running' status
    #-----------------------------------------------------
    if ( $self->checkSbxProcessStatus(
                    '-retryCount'    => 1,            # no. of retries
                    '-timeout'       => $self->{DEFAULTTIMEOUT},
                    '-testId'        => $a{'-testId'},
                ) ) {
        $logger->debug(" $a{'-testId'} INFO: All process(s) are already in expected \'running\' status.");
        $retValue = 1;
        $logger->debug(" <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    #-------------------------------------------------
    # Execute Shell command
    #-------------------------------------------------
    my $cmd = 'service sbx start';
    $logger->debug(" $a{'-testId'} Starting SBX process(s), executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                        '-cmd'     => $cmd,
                        '-timeout' => $a{'-timeout'},
                        '-testId'  => $a{'-testId'},
                    ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed Shell command \'$cmd\'.");

    #----------------------------------------------------------------
    # if Shell Command 'service sbx start' had been executed earlier
    # the command results shall have the following string
    # "The service is already running"
    #----------------------------------------------------------------
    my $grepFailFlag = 0;
    if ( grep( /The service is already running/, @{ $self->{CMDRESULTS} } ) ) {
        $logger->debug(" $a{'-testId'} SUCCESS: \'The service is already running\'.");
    }
    else {
        #-------------------------------------------------
        # Expected Shell command response(s)
        #-------------------------------------------------
        my @cmdResponse = (
            'Starting asp:',
            'INFO Saved previous log directory in',
            'INFO Saved previous run directory in',
            'INFO Starting SNMP daemon...',
            'Removing shared memory sections',
            'Removing semaphores',
            'Starting policy server DB',
            'INFO Starting AMF...',
            'INFO Starting AMF watchdog...',
        );
    
        #-------------------------------------------------
        # parse Shell command results
        #-------------------------------------------------
        foreach my $response ( @cmdResponse ) {
            unless ( grep( /\Q$response\E/, @{ $self->{CMDRESULTS} } ) ) {
                $logger->error(" $a{'-testId'} ERROR: string \'$response\' not present in command \'$cmd\' response:--\n@{ $self->{CMDRESULTS} }\n");
                $grepFailFlag = 1; # Failure
                last;
            }
            else {
                $logger->debug(" $a{'-testId'} INFO: string \'$response\' present in command response.");
            }
        }
    }
    
    #-----------------------------------------------------
    # to check for all process(s) are in 'running' status
    #-----------------------------------------------------
    my $StatusFailFlag = 0;
    unless ( $grepFailFlag ) {
        unless ( $self->checkSbxProcessStatus(
                            '-retryCount'    => 10,   # no. of retries
                            '-retryInterval' => 10,   # time interval between retries in seconds
                            '-timeout'       => $self->{DEFAULTTIMEOUT},
                            '-testId'        => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: All process(s) are not in expected \'running\' status.");
            $StatusFailFlag = 1; # Failure
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: All process(s) are in expected \'running\' status.");
        }
    }

    #-----------------------------------------------------------------------------
    # return success if 
    # - all expected responses are found in shell command results and
    # - all process are in expected status i.e. 'running'
    #-----------------------------------------------------------------------------
    if ( ( $grepFailFlag == 0 ) &&
         ( $StatusFailFlag == 0 ) ) {
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 restartSbxService()

DESCRIPTION:

 The subroutine is used to restart SBX process(s) by executing 'sbxrestart' from root login
 Then SBX process(s) are checked for 'running' status.
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - Default 600 sec i.e. 10 mins


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 checkSbxProcessStatus()

OUTPUT:
 
 1 - Success - i.e. executed 'sbxrestart' and all SBX process(s) are in 'running' status.
 0 - Failure

EXAMPLE:

    #---------------------------------------------------
    # To Re-Start SBX Service and
    # ensure all SBX process(s) are in 'running' status
    #---------------------------------------------------
    unless ( $SimsRootObj->restartSbxService(
                            '-testId'  => $TestId,
                            '-timeout' => 720, # Default 600 sec i.e. 10 mins
                        ) ) {
        $errorMsg = "  FAILED - restartSbxService().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - restartSbxService().");

=cut

#################################################
sub restartSbxService {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'restartSbxService()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => 600, # seconds i.e. 10 mins
        '-testId'  => '',
    );

    if ( ( defined $args{'-timeout'} ) &&
         ( $args{'-timeout'} < $a{'-timeout'} ) ) {
        $logger->warn("  WARN: The optional argument \'-timeout\' is ($args{'-timeout'}) i.e. less than default value $a{'-timeout'}.");
        $args{'-timeout'} = $a{'-timeout'};
        $logger->warn("  WARN: The optional argument \'-timeout\' is set to default value $args{'-timeout'}.");
    }

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Execute Shell command
    #-------------------------------------------------
    my $cmd = 'sbxrestart';
    $logger->debug(" $a{'-testId'} Restarting SBX process(s), executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                        '-cmd'     => $cmd,
                        '-timeout' => $a{'-timeout'},
                        '-testId'  => $a{'-testId'},
                    ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed Shell command \'$cmd\'.");

    #-------------------------------------------------
    # Expected Shell command response(s)
    #-------------------------------------------------
    my @cmdResponse = (
        'Stopping asp:',
        'INFO Stopping AMF...',
        'INFO Stopping AMF watchdog...',
        'INFO Waiting for AMF to shutdown...',
        'Stopping orphaned confd...',
        'Stopping policy server DB',
        'Unloading Sonus KLMs',
        'Removing shared memory sections',
        'Removing semaphores',

        'Starting asp: ',
        'INFO Saved previous log directory in',
        'INFO Saved previous run directory in',
        'INFO Starting SNMP daemon...',
        'Removing shared memory sections',
        'Removing semaphores',
        'Starting policy server DB',
        'INFO Starting AMF...',
        'INFO Starting AMF watchdog...',
    );
    
    #-------------------------------------------------
    # parse Shell command results
    #-------------------------------------------------
    my $grepFailFlag = 0;
    foreach my $response ( @cmdResponse ) {
        unless ( grep( /\Q$response\E/, @{ $self->{CMDRESULTS} } ) ) {
            $logger->error(" $a{'-testId'} ERROR: string \'$response\' not present in command \'$cmd\' response:--\n@{ $self->{CMDRESULTS} }\n");
            $grepFailFlag = 1; # Failure
            last;
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: string \'$response\' present in command response.");
        }
    }
    
    #-----------------------------------------------------
    # to check for all process(s) are in 'running' status
    #-----------------------------------------------------
    my $StatusFailFlag = 0;
    unless ( $grepFailFlag ) {
        unless ( $self->checkSbxProcessStatus(
                            '-retryCount'    => 10,   # no. of retries
                            '-retryInterval' => 10,   # time interval between retries in seconds
                            '-timeout'       => $self->{DEFAULTTIMEOUT},
                            '-testId'        => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: All process(s) are not in expected \'running\' status.");
            $StatusFailFlag = 1; # Failure
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: All process(s) are in expected \'running\' status.");
        }
    }

    #-----------------------------------------------------------------------------
    # return success if 
    # - all expected responses are found in shell command results and
    # - all process are in expected status i.e. 'running'
    #-----------------------------------------------------------------------------
    if ( ( $grepFailFlag == 0 ) &&
         ( $StatusFailFlag == 0 ) ) {
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 restartBind9Service()

DESCRIPTION:

 The subroutine is used to restart bind9 service by executing from root login
 'service bind9 restart'
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()
 checkSbxProcessStatus()

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    #---------------------------------------------------
    # To Restart bind9 Service
    #---------------------------------------------------
    unless ( $SimsRootObj->restartBind9Service(
                            '-testId'  => $TestId,
                            '-timeout' => 20, # Default i.e. DEFAULTTIMEOUT 10 seconds
                        ) ) {
        $errorMsg = "  FAILED - restartBind9Service().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - restartBind9Service().");

=cut

#################################################
sub restartBind9Service {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'restartBind9Service()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT}, # i.e. 10 seconds
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #-------------------------------------------------
    # Execute Shell command
    #-------------------------------------------------
    my $cmd = 'service bind9 restart';
    $logger->debug(" $a{'-testId'} Restarting SBX bind9 service, executing cmd \'$cmd\'.");

    unless ( $self->execShellCmd(
                        '-cmd'     => $cmd,
                        '-timeout' => $a{'-timeout'},
                        '-testId'  => $a{'-testId'},
                    ) ) {
        $logger->error(" $a{'-testId'} ERROR: executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
        $logger->debug(" <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(" $a{'-testId'} SUCCESS: executed Shell command \'$cmd\'.");

    #-------------------------------------------------
    # Expected Shell command response(s)
    #-------------------------------------------------
    my @cmdResponse = (
        'Stopping domain name service...: bind9 waiting for pid',
        'Starting domain name service...: bind9.',
    );
    
    #-------------------------------------------------
    # parse Shell command results
    #-------------------------------------------------
    my $grepFailFlag = 0;
    foreach my $response ( @cmdResponse ) {
        unless ( grep( /\Q$response\E/, @{ $self->{CMDRESULTS} } ) ) {
            $logger->error(" $a{'-testId'} ERROR: string \'$response\' not present in command \'$cmd\' response:--\n@{ $self->{CMDRESULTS} }\n");
            $grepFailFlag = 1; # Failure
            last;
        }
        else {
            $logger->debug(" $a{'-testId'} INFO: string \'$response\' present in command response.");
        }
    }
    
    unless ( $grepFailFlag ) {
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#######################################################################################################

=head1 getSimsIngressEgressPortStatus()

DESCRIPTION:

 The subroutine is used to check Ingress/Egress Signalling SIP IPs are active on port 65210,
 by executing from root login 'netstat -an |grep "65210"', and verify the command results with
 Ingress/Egress IPs retrieved from TMS alias object, 
 It will return 0 or 1
 In the case of timeout 0 is returned.

ARGUMENTS:

 1. TestID - i.e. TMS Test Case (6 digits) ID.
 2. Timeout (Optional) - i.e. DEFAULTTIMEOUT 10 seconds


PACKAGE:

 SonusQA::SIMS

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execShellCmd()

OUTPUT:
 
 1 - Success
 0 - Failure

EXAMPLE:

    #---------------------------------------------------------------------
    # To check Ingress/Egress Signalling SIP IPs are active on port 65210
    #---------------------------------------------------------------------
    unless ( $SimsRootObj->getSimsIngressEgressPortStatus(
                            '-testId'  => $TestId,
                            '-timeout' => 20, # Default i.e. DEFAULTTIMEOUT 10 seconds
                        ) ) {
        $errorMsg = "  FAILED - getSimsIngressEgressPortStatus().";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - getSimsIngressEgressPortStatus().");

=cut

#################################################
sub getSimsIngressEgressPortStatus {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'getSimsIngressEgressPortStatus()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    ###############################
    # Init Optional Parameters
    ###############################
    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT}, # i.e. 10 seconds
        '-testId'  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( '-subName' => $subName, %a );

    #------------------------------------------------------------
    # Retrieve Ingress/Egress Signalling SIP IP's frpm TMS alias
    #------------------------------------------------------------
    my %sigSipIPv4 = (
        'INGRESS' => $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IP},
        'EGRESS'  => $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{2}->{IP},
    );
   
    my %result;

    foreach my $sigSipPortType ( 'INGRESS', 'EGRESS' ) {
        my $port = $signallingSbxPort{INGRESS};
        my $cmd = "netstat -an |grep \"$port\"";
        $logger->debug(" $a{'-testId'} Getting SIMS - Signalling SIP (SBX) \'$sigSipPortType\' netstat, executing cmd \'$cmd\'.");

        #-------------------------------------------------
        # Execute Shell command
        #-------------------------------------------------
        unless ( $self->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => $a{'-timeout'},
                            '-testId'  => $a{'-testId'},
                        ) ) {
            $logger->error(" $a{'-testId'} ERROR: executing Shell command \'$cmd\':--\n@{ $self->{CMDRESULTS}}\n");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
        # $logger->debug(" $a{'-testId'} SUCCESS: executed Shell command \'$cmd\'.");

        #-------------------------------------------------
        # Parse Shell command Result(s)
        #-------------------------------------------------
        my $sigSipIPv4;
        $result{$sigSipPortType} = 0; # FAIL
        foreach my $line ( @{ $self->{CMDRESULTS} } ) {
            if( $line =~ /^udp\s+\d+\s+\d+\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\:$port\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\:.*$/ ) {
                $sigSipIPv4 = $1;

                if ( $sigSipIPv4 eq $sigSipIPv4{$sigSipPortType} ) {
                    $logger->debug(" $a{'-testId'} $sigSipPortType: Found ACTIVE ($sigSipIPv4), port $port.");
                    $result{$sigSipPortType} = 1; # PASS
                }
            }
            else {
                $logger->error(" $a{'-testId'} $sigSipPortType: NOT matched Signalling SIP IPv4, port $port.");
            }
        }

        #-------------------------------------------------
        # Inform User about the ERROR
        #-------------------------------------------------
        unless ( $result{$sigSipPortType} ) {
            $logger->error(" $a{'-testId'} ERROR: $sigSipPortType IPv4 $sigSipIPv4{$sigSipPortType} NOT Active (netstat) for port $port.");
        }
    }
    
    if ( ( $result{INGRESS} ) && ( $result{EGRESS} ) ) {
         $logger->debug(" $a{'-testId'} Both (Ingress\/Egress) Signalling SIP IPv4 are (netstat) active.");
         $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

##################################################################################################

###################################################
# _info
# subroutine to print all arguments passed to a sub.
# Used for debuging only.
###################################################

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '_info');

    unless ($args{-subName}) {
        $logger->error("ERROR: Argument \"-subName\" must be specified and not be blank. $args{-subName}");
        return 0;
    }

    $logger->debug(".$args{-subName} ===================================");
    $logger->debug(".$args{-subName} Entering $args{-subName} function");
    $logger->debug(".$args{-subName} ===================================");

    foreach ( keys %args ) {
        if (defined $args{$_}) {
            $logger->debug(".$args{-subName}\t$_ => $args{$_}");
        } else {
            $logger->debug(".$args{-subName}\t$_ => undef");
        }
    }

    $logger->debug(".$args{-subName} ===================================");

    return 1;
}

##################################################################################################


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
