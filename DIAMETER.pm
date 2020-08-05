package SonusQA::DIAMETER;

use strict;
use warnings;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    # set the version for version checking
    $VERSION     = '0.01';

    @ISA         = qw(Exporter SonusQA::Base);
    @EXPORT      = qw( newFromAlias setSystem startSingleLeg waitSingleLeg );
    %EXPORT_TAGS = ( 'all' => [ qw( newFromAlias setSystem startSingleLeg waitSingleLeg ) ]);

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );

    # non-exported package globals go here
    use vars qw($self );
}

use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;


########################### main pod documentation begin #######################

=head1 NAME

SonusQA::DIAMETER - Perl module for DIAMETER interaction

=head1 SYNOPSIS

use ATS;
or:
use SonusQA::DIAMETER;

=head1 DESCRIPTION

SonusQA::DIAMETER provides a common interface for DIAMETER objects.

=head1 USAGE


=head1 SUPPORT


=head1 HISTORY

0.01 Wed Mar 16 13:14:09 2011
- original version; created by Kevin Rodrigues <krodrigues@sonusnet.com>

=head1 AUTHOR

The <SonusQA::DIAMETER> module has been created by
Kevin Rodrigues <krodrigues@sonusnet.com>

and updated by
Thangaraj Arumugachamy
Sonus Networks India Private Limited
tarmugasamy@sonusnet.com
http://www.sonusnet.com

alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors

=head1 COPYRIGHT

                              Sonus Networks, Inc.
                         Confidential and Proprietary.
                     Copyright (c) 2011 Sonus Networks
                              All Rights Reserved
 Use of copyright notice does not imply publication.
 This document contains Confidential Information Trade Secrets, or both which
 are the property of Sonus Networks. This document and the information it
 contains may not be used disseminated or otherwise disclosed without prior
 written consent of Sonus Networks

=head1 DATE

2011-03-16

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=head1 SEE ALSO

perl(1).

=cut

########################### main pod documentation end #########################

=head1 Methods

  ############################ subroutine header begin ###########################

=head2 SonusQA::DIAMETER::newFromAlias()

 This function attempts to resolve the TMS Test Bed Management alias passed in as the first argument
 and creates an instance of the ATS object based on the object type passed in as the second argument.
 This argument is optional. If not specified the OBJTYPE will be looked up from TMS. As an additional
 check it will double check that the OBJTYPE in TMS corresponds with the user's entry. If not it will
 error. It will also add the TMS alias data to the object as well as the resolved alias name.
 It will return the ATS object if successful or undef otherwise. In addition, if the user specifies
 extra flags not recognised by newFromAlias, these will all be passed to Base::new on creation of
 the session object. That subroutine will handle the parsing of those arguments.
 This is primarily to enable the user to override default flags.

=over

=item ARGUMENTS:

 Mandatory Args:
    -tms_alias => TMS alias string

 Optional Args:
   [-obj_type        => ATS object type string]
   [-target_instance => Optional 3rd arg for DIAMETER target instance when object type is "DIAMETER"]
   [-ignore_xml      => Optional 4th arg for xml library ignore flag,
                        Values - 0 or OFF, defaults to 1]

=item PACKAGE:

 SonusQA::DIAMETER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::Utils::resolve_alias()

=item RETURNS:

 $AtsObjRef - ATS object if successful
    Adds - $AtsObjRef->{TMS_ALIAS_DATA} and $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME}
    exit - otherwise

=item EXAMPLE(s):

    our $DiameterObj;

    # DIAMETER - session
    if(defined ($TESTBED{ 'diameter:1:ce0' })) {
        $DiameterObj = SonusQA::DIAMETER::newFromAlias(
                        -tms_alias => $TESTBED{ 'diameter:1:ce0' },
                    );
        unless ( defined $DiameterObj ) {
            $logger->error('  -----FAILED TO CREATE DIAMETER OBJECT-----');
            return 0;
        }
    }
    $logger->debug('  -----SUCCESS CREATED DIAMETER OBJECT-----');

=back

=cut

############################ subroutine header end #############################

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

    if ( defined $AtsObjType ) {
        if ( $AtsObjType =~ /^DIAMETER$/ ) {
            # Check TMS alias parameters are defined and not blank
            my %DiameterTMSAttributes = (
                #=====================================
                # DIAMETER - IPv4 address
                #=====================================
                'NODE_1_IP'          => $TmsAlias_hashRef->{NODE}->{1}->{IP},

                #=====================================
                # DIAMETER - Login & Password
                #=====================================
                # ADMIN - User ID
                'LOGIN_1_USERID'     => $TmsAlias_hashRef->{LOGIN}->{1}->{USERID},
                # ADMIN - User Password
                'LOGIN_1_PASSWD'     => $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD},
            );

            my @missingTmsValues;
            my $TmsAttributeFlag = 0;
            while ( my($key, $value) = each(%DiameterTMSAttributes) ) {
             
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

            unless ( defined( $refined_args{ '-obj_password' } ) ) {
                $refined_args{ '-obj_password' } = $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD};
                $logger->debug("  -obj_password set to TMS_ALIAS->LOGIN->1->PASSWD");
            }

            unless ( defined( $refined_args{ '-obj_commtype' } ) ) {
                $refined_args{ '-obj_commtype' } = 'SSH';
                $logger->debug("  -obj_commtype set to \'$refined_args{'-obj_commtype'}\'");
            }

            # Attempt to create ATS DIAMETER object
            $AtsObjRef = SonusQA::DIAMETER->new(
                                        -obj_host => "$TmsAlias_hashRef->{NODE}->{1}->{IP}",
                                        %refined_args,
                                    );
        }
    }

    # Add TMS alias data to the newly created ATS object for later use
    $AtsObjRef->{TMS_ALIAS_DATA} = $TmsAlias_hashRef;

    # Add the TMS alias name to the TMS ALAIAS DATA
    $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME} =  $TmsAlias;
    
    $logger->debug(" Leaving sub \[obj:$AtsObjType\]");    
    return $AtsObjRef;

} # End sub newFromAlias

################################################################################

############################ subroutine header begin ###########################

=pod

=head2 SonusQA::DIAMETER::doInitialization()

  Base module over-ride. Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over 

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

############################ subroutine header end #############################

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
    
    $self->{COMMTYPES}          = [ 'SSH', 'TELNET' ];
    $self->{COMM_TYPE}          = undef;
    $self->{TYPE}               = __PACKAGE__;
    $self->{conn}               = undef;
    $self->{OBJ_HOST}           = undef;

    $self->{DEFAULTPROMPT}      = '/.*[\$%#>] $/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};

    $self->{REVERSE_STACK}      = 1;
    $self->{VERSION}            = $VERSION;
    $self->{LOCATION}           = locate __PACKAGE__;
    my ($name,$path,$suffix)    = fileparse($self->{LOCATION},"\.pm"); 
    $self->{DIRECTORY_LOCATION} = $path;

    $self->{DEFAULTTIMEOUT}     = 60;
    $self->{SESSIONLOG}         = 0;
    $self->{IGNOREXML}          = 1;

    $self->{HISTORY}      = ();
    $self->{CMDRESULTS}   = [];
  
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
            $logger->debug("  Check if comm type ($commType) is valid. . . from DIAMETER list (@{ $self->{COMMTYPES} })");
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
    
    # Python script being executed
    $self->{PYTHON_SCRIPT} = undef;

    $logger->debug('  Initialization Complete');
    $logger->debug(' <-- Leaving Sub [1]');
}

#########################################################################################################

=head2 SonusQA::DIAMETER::setSystem()

  Sets the DIAMETER connection for the automation related configurations

=over

=item Arguments

  None

=item Returns

  1 - Configuration is done properly

=back

=cut

#################################################
sub setSystem() {
#################################################
    my( $self ) = @_;
    my $subName = 'setSystem()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    
    unless ( defined $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn(' Hostname variable (via -obj_hostname) not set.');
    }

    my( $cmd, $prompt, $prevPrompt, @results);
    my $errMode = sub {
        unless ( $cmd =~ /exit/ ) {
            $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            $logger->error('  Timeout OR Error for command (' . "$cmd" . ')');
            $logger->warn ('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        }
        return 1;
    };

    $cmd = 'bash';
    $self->{conn}->cmd( String => $cmd, Errmode => $errMode );
    $cmd = '';
    $self->{conn}->cmd( String => $cmd, Errmode => $errMode );

    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info('  SET PROMPT TO: ' . $self->{conn}->prompt . ' FROM: ' . $prevPrompt);

    $cmd = 'export PS1="AUTOMATION> "';
    @results = $self->{conn}->cmd( String => $cmd, Errmode => $errMode );

    $cmd = ' ';
    $self->{conn}->cmd( String => $cmd, Errmode => $errMode );
    $logger->info('  SET PROMPT TO: ' . $self->{conn}->last_prompt );

    $self->{conn}->waitfor(
                        Match   => $self->{PROMPT},
                        Timeout => $self->{DEFAULTTIMEOUT},
                    );

    $logger->debug(__PACKAGE__ . ".setSystem: Set System Complete");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}  


#######################################################################################################

############################ subroutine header begin ###########################

=head2 SonusQA::DIAMETER::startSingleLeg()

  This function is used to execute a single leg of diameter,
  i.e. invoke diameter Python script.
  and a different tool (EAST, MGTS, SIPP, INET etc) as the other leg.

  startSingleLeg() will execute the command passed as an argument and return the
  control back to the user script.

  Note: When using startSingleLeg(), get the execution status using waitSingleLeg().

=over

=item ARGUMENTS:

 Mandatory Args:
    cmd => command to execute Python script (string)

 Optional Args:
    timeout => Timeout to execute the command i.e. DEFAULTTIMEOUT 60 seconds
    testId  => TMS Test Case (6 digits) ID

=item PACKAGE:

 SonusQA::DIAMETER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - success i.e. DIAMETER command was invoked successfully.
 0 - failure i.e. failed to invoke DIAMETER Command

 Note: This does not indicate whether the DIAMETER leg was successfull or not.
       For the leg status, use waitSingleLeg(), as shown in the example.

=item EXAMPLE(s):

    my $diameterCmd = "$diameterPath/diameterScript.py"

    unless ( $DiameterObji->startSingleLeg(
                                cmd     => $diameterCmd,
                                timeout => 120, # seconds
                                testId  => $TestId,
                            ) {
        $errorMsg = "  FAILED - Invoking Diameter Python script using cmd \'$diameterCmd\'.";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - Invoked Diameter Python script using cmd \'$diameterCmd\'.");

=back

=cut

############################ subroutine header end #############################

#################################################
sub startSingleLeg {
#################################################

    my ($self, %args ) = @_;
    my $subName = 'startSingleLeg()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;
 
    # Check Mandatory Parameters
    foreach ( qw/ cmd / ) {
        unless ( defined ( $args{ $_ } ) ) {
            $logger->error("  ERROR: The mandatory argument for $_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        cmd     => '',
        timeout => $self->{DEFAULTTIMEOUT},
        testId  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( subName => $subName, %a );

    $self->{PROMPT} = $self->{conn}->last_prompt;

    # Some machines have prompts with incrementing numbers in sqare brackets
    # Get rid of them
    $self->{PROMPT} =~ s/\[\d+\]//g;    
    $logger->debug("Last prompt saved : $self->{PROMPT}");

    unless ( defined $self->{PYTHON_SCRIPT} ) {
        # discard all data in object's input buffer
        $self->{conn}->buffer_empty;

        unless ( $self->{conn}->print( $a{cmd} ) ) {
            $logger->error(" $a{testId} Error: executing Command : $a{cmd}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
        else {
            # Python script being executed
            $self->{PYTHON_SCRIPT} = $a{cmd};

            $logger->debug(" $a{testId} SUCCESS: invoked command \'$a{cmd}\'.");
            $retValue = 1;
        }
    }
    else {
        $logger->error(" $a{testId} Error: Diameter Object already executing Python script using command : $self->{PYTHON_SCRIPT}");
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

########################################################################################################

############################ subroutine header begin ###########################

=head2 waitSingleLeg()

  This function is used to get the execution result status of startSingleLeg(),

  startSingleLeg() shall execute the command passed and return the control back to the user script.
  To get back the details of that execution and also to print the call details into the logs
  use waitSingleLeg()

  Note: Inorder to use waitSingleLeg(), the Python script should be started using startSingleLeg().

=over

=item ARGUMENTS:

 Mandatory Args:
    timeout => Timeout to execute the command in seconds i.e. DEFAULTTIMEOUT 60 seconds

 Optional Args:
    testId  => TMS Test Case (6 digits) ID

=item PACKAGE:

 SonusQA::DIAMETER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - success i.e. DIAMETER command was invoked successfully.
 0 - failure i.e. failed to invoke DIAMETER Command

 Note: This does not indicate whether the DIAMETER leg was successfull or not.
       For the leg status, use waitSingleLeg(), as shown in the example.

=item EXAMPLE(s): 

    my $wait = 15;
    $logger->debug(" Executing waitSingleLeg() for timeout: $wait seconds");
    unless ( $DiameterObj->waitSingleLeg(
                            timeout => $wait, # seconds
                            testId  => $TestId,
                        ) ) {
        $errorMsg = "  FAILED - waitSingleLeg()";
        $logger->error("$errorMsg");
        $testStatus->{reason} = $errorMsg;
        return $testStatus;
    }
    $logger->debug("  SUCCESS - waitSingleLeg().");

=back

=cut

############################ subroutine header end #############################

#################################################
sub waitSingleLeg {
#################################################

    my ($self, %args ) = @_;
    my $subName = 'waitSingleLeg()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0;
 
    # Check Mandatory Parameters
    foreach ( qw/ timeout / ) {
        unless ( defined ( $args{ $_ } ) ) {
            $logger->error("  ERROR: The mandatory argument for $_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my %a = (
        timeout => $self->{DEFAULTTIMEOUT},
        testId  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( subName => $subName, %a );

    my $errorFlag = 0;

    # -----------------------------------------------------------------------
    # ERROR HANDLE (used for error mode in the waitfor above)
    # -----------------------------------------------------------------------
    my $errorMode_ref = sub {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        # Timeout OR error occured while executing command, so set errorFlag
        $errorFlag = 1;
        $logger->error(" $a{testId} ERROR: Diameter Python script did not complete in \'$a{timeout}\' seconds.");
          
        # Waited too long! Abort Diameter script execution, by issuing a "Ctrl-C"
        unless ( $self->{conn}->cmd(
                                String => "\cC",
                                Prompt => $self->{PROMPT},
                            ) ) {
            $logger->error(" $a{testId} ERROR: Failed killing diameter Python script using Ctrl-C");
        }
        else {
            $logger->warn(" $a{testId} SUCCESS: Diameter Python script killed using Ctrl-C");
        }
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
    };
    # -----------------------------------------------------------------------

    my ( $prematch, $match ) = $self->{conn}->waitfor(
                                    String  => $self->{PROMPT},
                                    Errmode => $errorMode_ref,
                                    Timeout => $a{timeout},
                                );

    if ( $errorFlag == 0 ) {
        $logger->debug(" $a{testId} DIAMETER Python script execution output:--\n$prematch\n");
        $logger->debug(" $a{testId} Detected DIAMETER Python script completion, getting status");
        my @cmdResults;
        unless ( @cmdResults = $self->{conn}->cmd(
                                                String  => "echo \$?",
                                                Timeout => $self->{DEFAULTTIMEOUT},
                                            ) ) {
            $logger->warn(" $a{testId} ERROR: Failed to get return value");
        }
        chomp ( @cmdResults );

        foreach my $line (@cmdResults) {
            if ( $line =~ /^(\d+)/ ) {
                my $errorValue = $1;
                if ($errorValue == 0) {
                    # when $? == 0, success;
                    $logger->debug(" $a{testId} SUCCESS: shell return code \'$errorValue\'");
                    $retValue = 1;
                }
                else {
                    $logger->error(" $a{testId} ERROR: SHELL CMD FAILED - shell return code \'$errorValue\'");
                }
                last;
            }
            last;
        }
    }
    else {
        $logger->debug(" $a{testId} DIAMETER Python script execution error Flag is SET ($errorFlag).");
    }

    # Python script being executed
    $self->{PYTHON_SCRIPT} = undef;

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

########################################################################################################

=head2 SonusQA::DIAMETER::_info()

  subroutine to print all arguments passed to a sub.
  Used for debuging only.

=over

=item Arguments

  args <Hash>

=item Returns

  0 - On Error
  1 - Successful execution

=back

=cut

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '_info');

    unless ($args{subName}) {
        $logger->error("ERROR: Argument \"subName\" must be specified and not be blank. $args{subName}");
        return 0;
    }

    $logger->debug(".$args{subName} ===================================");
    $logger->debug(".$args{subName} Entering $args{subName} function");
    $logger->debug(".$args{subName} ===================================");

    foreach ( keys %args ) {
        if (defined $args{$_}) {
            $logger->debug(".$args{subName}\t$_ => $args{$_}");
        } else {
            $logger->debug(".$args{subName}\t$_ => undef");
        }
    }

    $logger->debug(".$args{subName} ===================================");

    return 1;
}

########################################################################################################


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
