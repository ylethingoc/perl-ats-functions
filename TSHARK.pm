package SonusQA::TSHARK;
#$Id#

use strict;
use warnings;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    # set the version for version checking
    $VERSION     = '0.01';

    @ISA         = qw(Exporter SonusQA::Base);
    @EXPORT      = qw( newFromAlias setSystem execCmd );
    %EXPORT_TAGS = ( 'all' => [ qw( newFromAlias setSystem execCmd ) ]);

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );

    # non-exported package globals go here
    use vars qw($self);
}

use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use Net::SCP::Expect;
use File::Basename;
use POSIX qw(:errno_h :sys_wait_h);

########################### main pod documentation begin #######################

=head1 NAME

SonusQA::TSHARK - Perl module for TSHARK interaction

=head1 SYNOPSIS

 use ATS;
   or:
 use SonusQA::TSHARK;

=head1 DESCRIPTION

 SonusQA::TSHARK provides a common interface for TSHARK objects.

=head1 HISTORY

0.01 Wed Mar  9 13:14:09 2011
    - original version; created by ExtUtils::ModuleMaker 0.51


=head1 AUTHOR

    The <SonusQA::TSHARK> module has been created by

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

 2011-03-09

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=head1 SEE ALSO

 perl(1).

=cut

########################### main pod documentation end #########################


############################ subroutine header begin ###########################

=head1 METHODS

=head2 newFromAlias()

=over

=item DESCRIPTION: 

 This function attempts to resolve the TMS Test Bed Management alias passed in as the first argument
 and creates an instance of the ATS object based on the object type passed in as the second argument.
 This argument is optional. If not specified the OBJTYPE will be looked up from TMS. As an additional
 check it will double check that the OBJTYPE in TMS corresponds with the user's entry. If not it will
 error. It will also add the TMS alias data to the object as well as the resolved alias name.
 It will return the ATS object if successful or undef otherwise. In addition, if the user specifies
 extra flags not recognised by newFromAlias, these will all be passed to Base::new on creation of
 the session object. That subroutine will handle the parsing of those arguments.
 This is primarily to enable the user to override default flags.

=item ARGUMENTS:

 Mandatory Args:
    -tms_alias => TMS alias string

 Optional Args:
   [-obj_type        => ATS object type string]
   [-target_instance => Optional 3rd arg for TSHARK target instance when object type is "TSHARK"]
   [-ignore_xml      => Optional 4th arg for xml library ignore flag,
                        Values - 0 or OFF, defaults to 1]

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::Utils::resolve_alias()

=item RETURNS:

 $AtsObjRef - ATS object if successful
    Adds - $AtsObjRef->{TMS_ALIAS_DATA} and $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME}
    exit - otherwise

=item EXAMPLE: 

    our $TsharkObj;

    # TSHARK - session
    if(defined ($TESTBED{ 'tshark:1:ce0' })) {
        $TsharkObj = SonusQA::TSHARK::newFromAlias(
                        -tms_alias => $TESTBED{ 'tshark:1:ce0' },
                    );
        unless ( defined $TsharkObj ) {
            $logger->error(__PACKAGE__ . ".$subName:   -----FAILED TO CREATE TSHARK OBJECT-----");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$subName:  -----SUCCESS CREATED TSHARK OBJECT-----");

=back

=cut

sub newFromAlias {
    my ( %args ) = @_;
    my $subName = 'newFromAlias()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");;
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

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
        $logger->error(__PACKAGE__ . ".$subName: Value for -tms_alias undefined or is blank");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [exit]");
        exit;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Resolving Alias $TmsAlias");

    # Set ignore_xml flag to user specified value if $args{-ignore_xml} specified
    if ( defined($ignore_xml) && ($ignore_xml !~ m/^\s*$/) ) {
        $logger->error(__PACKAGE__ . ".$subName: Ignore XML flag is blank");
    }

    my $TmsAlias_hashRef = SonusQA::Utils::resolve_alias($TmsAlias);

    # Check if $TmsAlias_hashRef is empty
    unless ( keys ( %{$TmsAlias_hashRef} ) ) {
        $logger->error(__PACKAGE__ . ".$subName: \$TmsAlias_hashRef for TMS alias $TmsAlias empty. This element does not seem to be in the database.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [exit]");
        exit;
    }

    # Check for __OBJTYPE. If this is blank and -obj_type is not defined error.
    # If -obj_type is different to __OBJTYPE error.
    if ( defined( $AtsObjType ) && ( $AtsObjType !~ m/^\s*$/ ) ) {
        unless ( $AtsObjType eq $TmsAlias_hashRef->{__OBJTYPE} ) {
            $logger->error(__PACKAGE__ . ".$subName: Value for -obj_type ($AtsObjType) does not match TMS OBJTYPE ($TmsAlias_hashRef->{__OBJTYPE})");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [exit]");
            exit;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Object Type (from cmdline) is $AtsObjType");
    }
    else {
        if ( $TmsAlias_hashRef->{__OBJTYPE} eq "" ) {
            $logger->error(__PACKAGE__ . ".$subName: Value for -obj_type and TMS OBJTYPE undefined or is blank");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [exit]");
            exit;
        }
        else {
            $AtsObjType = $TmsAlias_hashRef->{__OBJTYPE};
            $logger->debug(__PACKAGE__ . ".$subName: Object Type (from TMS) is $AtsObjType");
        }
    }
    
    #TOOLS-5914 & TOOLS-5972
    if ($TmsAlias_hashRef->{VM_CTRL}->{1}->{NAME} && ($TmsAlias_hashRef->{VM_CTRL}->{1}->{TYPE} eq 'OpenStack')){
        my $vmctrl;
        $logger->debug(__PACKAGE__ . ".$subName: creating VMCTRL Object");

        my $vmctrl_alias = $TmsAlias_hashRef->{VM_CTRL}->{1}->{NAME};
        # no need to create the vmctrl object again, if its already created.
        # %vm_ctrl_obj is global variable, declared in SonusQA::Utils
        unless ($vm_ctrl_obj{$vmctrl_alias}){
            unless($vmctrl = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $vmctrl_alias, -ignore_xml => 0, -sessionLog => 1, -iptype => 'any', -return_on_fail => 1)) {
                    $logger->debug(__PACKAGE__ . ".$subName: Failed to create VMCTRL Object");
                    return 0;
            }
            $vm_ctrl_obj{$vmctrl_alias} = $vmctrl;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$subName: VMCTRL obj for '$vmctrl_alias' is already present");
            $vmctrl = $vm_ctrl_obj{$vmctrl_alias};
        }

        $args{-key_file} ||= "$ENV{ HOME }/ats_repos/lib/perl/SonusQA/cloud_ats.key";
        unless ($vmctrl->resolveCloudInstance(%args, -alias_hashref => $TmsAlias_hashRef)){
            $logger->error(__PACKAGE__ . ".$subName: Failed to fetch Cloud Instance details from VmCtrl");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }

        $refined_args{-obj_key_file} ||= $TmsAlias_hashRef->{LOGIN}->{1}->{KEY_FILE};
        $refined_args{'-obj_user'} ||= $TmsAlias_hashRef->{LOGIN}->{1}->{USERID};
        $refined_args{-failures_threshold} = 6; 
    }

    if ( defined $AtsObjType ) {
        my  %TsharkTMSAttributes;
        if ( $AtsObjType =~ /^TSHARK$/ ) {
            # Check TMS alias parameters are defined and not blank
            my $login = $TmsAlias_hashRef->{NODE}->{1}->{IP};
            if(exists $TmsAlias_hashRef->{NODE}->{1}->{NAME}){
                $login =  $main::TESTBED{"$main::TESTBED{$TmsAlias_hashRef->{NODE}->{1}->{NAME}}".":hash"}->{SLAVE_CLOUD}->{1}->{IP} if($main::TESTBED{$TmsAlias_hashRef->{NODE}->{1}->{NAME}} =~ /psx/ and exists $main::TESTBED{"$main::TESTBED{$TmsAlias_hashRef->{NODE}->{1}->{NAME}}".":hash"}->{SLAVE_CLOUD});
            }
            %TsharkTMSAttributes = (loginIp    => "$login");
            $refined_args{'-obj_user'} ||= $TmsAlias_hashRef->{LOGIN}->{1}->{USERID};
    	    $refined_args{-obj_key_file} ||= $TmsAlias_hashRef->{LOGIN}->{1}->{KEY_FILE};
            $TsharkTMSAttributes{userPasswd} = $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD} unless ($refined_args{-obj_key_file});
            unless ( defined( $refined_args{ '-obj_hostname' } ) ) {
                $refined_args{ '-obj_hostname'} = $TmsAlias_hashRef->{NODE}->{1}->{HOSTNAME};
                $logger->debug(__PACKAGE__ . ".$subName: -obj_hostname set to \'$refined_args{'-obj_hostname'}\'");
            }                                          
         }

         if ( $AtsObjType =~ /SGX4000/ ) {
            # Check TMS alias parameters are defined and not blank
            %TsharkTMSAttributes = (loginIp    => ["$TmsAlias_hashRef->{MGMTNIF}->{1}->{IP}",
                                                   "$TmsAlias_hashRef->{MGMTNIF}->{2}->{IP}",
                                                  ],
                                    userPasswd => $TmsAlias_hashRef->{LOGIN}->{1}->{ROOTPASSWD},);
                                    
            unless ( defined( $refined_args{ '-obj_port' } ) ) {
                $refined_args{ '-obj_port' } = '2024';
                $logger->debug(__PACKAGE__ . ".$subName: -obj_port set to \'$refined_args{'-obj_port'}\'");
            }
            
            unless ( defined( $refined_args{ '-obj_hostname' } ) ) {
                $refined_args{ '-obj_hostname'} = $TmsAlias_hashRef->{CE}->{1}->{HOSTNAME};
                $logger->debug(__PACKAGE__ . ".$subName: -obj_hostname set to \'$refined_args{'-obj_hostname'}\'");
            }
         }

         if ( $AtsObjType =~ /PSX/ ) {
            # Check TMS alias parameters are defined and not blank
            %TsharkTMSAttributes = (loginIp    =>"$TmsAlias_hashRef->{NODE}->{1}->{IP}",
                                    userPasswd => $TmsAlias_hashRef->{LOGIN}->{1}->{ROOTPASSWD},);
                                    
            unless ( defined( $refined_args{ '-obj_hostname' } ) ) {
                $refined_args{ '-obj_hostname'} = $TmsAlias_hashRef->{NODE}->{1}->{HOSTNAME};
                $logger->debug(__PACKAGE__ . ".$subName: -obj_hostname set to \'$refined_args{'-obj_hostname'}\'");
            }                                    
         }

         if ( $AtsObjType =~ /NETEM|QSBC/ ) {
            # Check TMS alias parameters are defined and not blank
            %TsharkTMSAttributes = (loginIp    =>"$TmsAlias_hashRef->{MGMTNIF}->{1}->{IP}",
                                    userPasswd => $TmsAlias_hashRef->{LOGIN}->{1}->{PASSWD},);

            unless ( defined( $refined_args{ '-obj_hostname' } ) ) {
                $refined_args{ '-obj_hostname'} = $TmsAlias_hashRef->{NODE}->{1}->{HOSTNAME};
                $logger->debug(__PACKAGE__ . ".$subName: -obj_hostname set to \'$refined_args{'-obj_hostname'}\'");
            }
         }

         my @missingTmsValues;
         my $TmsAttributeFlag = 0;
         while ( my($key, $value) = each(%TsharkTMSAttributes) ) {
             unless (defined($value) && ($value  !~ m/^\s*$/)) {
                  $TmsAttributeFlag = 1;
                  push ( @missingTmsValues, $key );
             }
         }

         if ( $TmsAttributeFlag == 1 ) {
             $logger->error(__PACKAGE__ . ".$subName: TMS alias parameters could not be obtained for alias $TmsAlias of object type $AtsObjType");
             foreach my $key (@missingTmsValues) {
                 $logger->error(__PACKAGE__ . ".$subName: TMS value for attribute $key is not present OR empty");
             }
             $logger->debug(__PACKAGE__ . ".$subName: Leaving sub [exit]");
             exit;
         }

         unless ( defined( $refined_args{ '-obj_user' } ) ) {
             $refined_args{ '-obj_user' } = 'root';
             $logger->debug(__PACKAGE__ . ".$subName: -obj_user set to \'$refined_args{'-obj_user'}\'");
         }

         unless ( defined( $refined_args{ '-obj_password' } ) ) {
             $refined_args{ '-obj_password' } = $TsharkTMSAttributes{userPasswd};
             $logger->debug(__PACKAGE__ . ".$subName: -obj_password set to TMS_ALIAS->LOGIN->1->PASSWD");
         }

         unless ( defined( $refined_args{ '-obj_commtype' } ) ) {
             $refined_args{ '-obj_commtype' } = 'SSH';
             $logger->debug(__PACKAGE__ . ".$subName: -obj_commtype set to \'$refined_args{'-obj_commtype'}\'");
         }

         unless ( defined ( $refined_args{'-sessionlog'} )) {
            $refined_args{'-sessionlog'} = 1;
            $logger->debug(__PACKAGE__ . ".$subName:  -sessionlog set to \'1\'");
         }


         # Attempt to create ATS SGX object.If unsuccessful,
         # exit will be called from new() function
         if ( $AtsObjType =~ /SGX4000/ ) {
              $AtsObjRef = SonusQA::TSHARK->new(-obj_hosts => $TsharkTMSAttributes{loginIp},
                                               %refined_args,);
         } else {
              $AtsObjRef = SonusQA::TSHARK->new(-obj_host => $TsharkTMSAttributes{loginIp},
                                                %refined_args,);
         }
    }

    # Add TMS alias data to the newly created ATS object for later use
    $AtsObjRef->{TMS_ALIAS_DATA} = $TmsAlias_hashRef;

    # Add the TMS alias name to the TMS ALAIAS DATA
    $AtsObjRef->{TMS_ALIAS_DATA}->{ALIAS_NAME} =  $TmsAlias;

    $logger->debug(__PACKAGE__ . ".$subName: Leaving sub \[obj:$AtsObjType\]");
    return $AtsObjRef;

} # End sub newFromAlias

=head2 doInitialization()

=over

=item DESCRIPTION:

  Base module over-ride. Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub doInitialization {
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

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "..$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    
    $self->{COMMTYPES}          = [ 'SSH', 'TELNET' ];
    $self->{COMM_TYPE}          = undef;
    $self->{TYPE}               = __PACKAGE__;
    $self->{conn}               = undef;
    $self->{OBJ_HOST}           = undef;
    $self->{DEFAULTPROMPT}      = '/.*[\$%#\}\|\>].*$/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};

    $self->{REVERSE_STACK}      = 1;
    $self->{VERSION}            = $VERSION;
    $self->{LOCATION}           = locate __PACKAGE__;
    my ($name,$path,$suffix)    = fileparse($self->{LOCATION},"\.pm"); 
    $self->{DIRECTORY_LOCATION} = $path;

    $self->{DEFAULTTIMEOUT}     = 60;
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
            $logger->debug(__PACKAGE__ . ".$subName:  Check if comm type ($commType) is valid. . . from TSHARK list (@{ $self->{COMMTYPES} })");
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
    
    $logger->debug(__PACKAGE__ . ".$subName:  Initialization Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
}

=head2 setSystem()

    This subroutine sets the system information and prompt.

=cut

sub setSystem() {
    my( $self, %args ) = @_;  
    my $subName = 'setSystem()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
 
    if ($args{-windows}) {
        $logger->info(__PACKAGE__ . ".$subName: Creating TSHARK object for Windows against the Parameter passed"); 
        $self->{WINDOWS} = 1 ;
        $logger->debug(__PACKAGE__ . ".$subName:  Set System Complete for Tshark windows object");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]"); 
        return 1 ; 
    }   
    
    if($self->{OBJ_USER}  =~ /^admin$/){
        $self->{SU_CMD} = 'sudo -i -u ';
        unless ( $self->enterRootSessionViaSU() ) {
            $logger->error(__PACKAGE__ . " : Could not enter root session" );
            return 0;
        }
    }
     
    $self->{conn}->cmd("bash");
    my $prevprompt = $self->{conn}->prompt('/AUTOMATION> $/');
    $logger->info(__PACKAGE__ . ".$subName: Changing shell prompt from $prevprompt to  \'AUTOMATION> \'");
    my $cmd = "PS1='AUTOMATION> '";
    #cahnged cmd() to print() to fix, TOOLS-4974
    unless ( $self->{conn}->cmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    $self->{conn}->waitfor(Timeout => 1);
    
    $self->{conn}->cmd("unset PROMPT_COMMAND");
    $logger->info(__PACKAGE__ . ".setSystem Unset \$PROMPT_COMMAND to avoid errors");

    $self->{DEFAULTPROMPT}      = '/AUTOMATION> $/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};
    
    unless ( defined $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn("$subName: Hostname variable (via -obj_hostname) not set.");
    }
    #TOOLS-5972
    elsif($self->{OBJ_HOSTNAME}=~/graylog/i){ #should not contain _ in hostname, ({NODE}->{1}->{HOSTNAME} in TMS)
        $logger->info("$subName: Setting up graylog server");
        unless($self->{OBJ_HOSTNAME} eq 'graylog'){
            $self->{conn}->cmd('sudo chmod 777 /etc/hosts');
            $logger->debug(__PACKAGE__ . ".$subName: \"sudo chmod 777 /etc/hosts\"");
            $self->{conn}->cmd("sudo echo '127.0.0.1 $self->{OBJ_HOSTNAME}' >> /etc/hosts");
            $logger->debug(__PACKAGE__ . ".$subName: Executed \"sudo echo '127.0.0.1 $self->{OBJ_HOSTNAME}' >> /etc/hosts\"");
        }

        $self->{conn}->cmd('sudo graylog-ctl reconfigure');
        $logger->debug(__PACKAGE__ . ".$subName: Executed \"sudo graylog-ctl reconfigure\"");
    }

    $self->{conn}->cmd('set +o history');
    $logger->debug(__PACKAGE__ . ".$subName:  Set System Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}  

=head2 startCaptureProcess()

=over

=item DESCRIPTION: 

 The function is used to start TSHARK capture process in background by executing command passed.
 It will then return 1 or 0 depending on this.

=item ARGUMENTS:

 Mandatory Args:
    cmd - tshark command to be passed

 Optional Args:
    timeout - i.e. DEFAULTTIMEOUT 60 seconds
    testId  - i.e. TMS Test Case (6 digits) ID

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - Success
 0 - Failure

=item EXAMPLE: 

    my $tsharkCmd = 'tethereal -i eth0 -w test.pcap';

    $logger->debug(__PACKAGE__ . ".$subName: Executing tshark command: \'$tsharkCmd\'");
    unless ( $TsharkObj->startCaptureProcess(
                            cmd     => $tsharkCmd,
                            timeout => 30,
                            testId  => $TestId,
                        ) ) {
        my $errMessage = "  FAILED - executing tshark command \'$tsharkCmd\':--\n@{ $TsharkObj->{CMDRESULTS}}\n";
        $logger->error("$errMessage");
        $testStatus->{reason} = $errMessage;
        return $testStatus;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  SUCCESS - Executed tshark command \'$tsharkCmd\'.");

=back

=cut

sub startCaptureProcess {
    my ($self, %args ) = @_;
    my $subName = 'startCaptureProcess()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . "..$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $retValue = 0;
 
    # Check Mandatory Parameters
    foreach ( qw/ cmd / ) {
        unless ( defined ( $args{$_} ) ) {
            $logger->error(__PACKAGE__ . ".$subName: ERROR: The mandatory argument for $_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return $retValue;
        }
        elsif($args{$_} =~ /.*\s+(\S+\/\w+\.pcap)/) {
            push(@{$self->{PCAP_FILES}},$1);
        }
        else{
            $logger->warn(__PACKAGE__ . ".$subName: pcap file not found");
        }
    }

    my %a = (
        cmd     => '',
        timeout => $self->{DEFAULTTIMEOUT},
        testId  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( subName => $subName, %a );

    #-------------------------------------------
    # If already an TSHARK process is running,
    # we cannot start another. . .
    #-------------------------------------------
    if ( defined $self->{TSHARKPROCESS}->{cmd}  ) {
        $logger->error(" $a{testId} ERROR: Already capture process for command \'$self->{TSHARKPROCESS}->{cmd} \' in progress.");
        $logger->error(" $a{testId} ERROR: Cannot start capture process for command \'$a{cmd}\'.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
        $main::failure_msg .= "TOOLS:TSHARK-tshark didnot start; ";
        return $retValue;
    }

    #------------------------------------------------
    # create a new TSHARK capture background process
    #------------------------------------------------
    # - Start the background process.
    # - If it is started sucessfully, then record
    # - the process id in $self->{TSHARKPROCESS}->{object}.
    #------------------------------------------------
    # Fork a child process ( i.e. Background Process ).
    my $pid;
    {
        if ( $pid = fork() ) {
            # Parent Process
            $logger->debug(__PACKAGE__ . ".$subName: $a{testId} SUCCESS: In PARENT process, CHILD PID \'$pid\'.");
            $self->{TSHARKPROCESS}->{object} = $pid;

            # Get PID of newly created TSHARK capture background process
            $self->{TSHARKPROCESS}->{pid}    = $pid;

            # Get Start Time of newly created TSHARK capture background process
            $self->{TSHARKPROCESS}->{startTime} = time;

            last;
        }
        elsif ( defined $pid ) {
            # Child Process
            { exec $a{cmd} }; $logger->error(" $a{testId} ERROR: CHILD process $0: exec() failed: $!");
            $main::failure_msg .= "TOOLS:TSHARK-tshark execution failed; ";
        }
        elsif ( $! == EAGAIN ) {
            sleep (5);
            redo;
        }
        else {
            $logger->error(" $a{testId} ERROR: Cannot start CHILD process for command \'$a{cmd}\'.");
            $main::failure_msg .= "TOOLS:TSHARK-tshark didnot start; ";
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
            return $retValue;
        }
    }

    unless ( defined $self->{TSHARKPROCESS}->{object} ) {
        $logger->error(" $a{testId} ERROR: Failed to start using command \'$a{cmd}\'.");
        $main::failure_msg .= "TOOLS:TSHARK-tshark didnot start; ";
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $retValue;
    }
    $logger->debug(__PACKAGE__ . ".$subName: $a{testId} SUCCESS: Started CHILD process (PID: $self->{TSHARKPROCESS}->{pid}) using command \'$a{cmd}\'.");
    $self->{TSHARKPROCESS}->{cmd}  = $a{cmd};


    #============================================================================
    # Sleeping for 5 second....
    # ---------------------------------------------------------------------------
    # This is to make sure that the process has been started and status is 'alive'
    # OR
    # Process might not have started due to permission issues, i.e. error message
    # ---------------------------------------------------------------------------
    # tshark: The capture session could not be initiated (socket: Operation not permitted).
    # Please check to make sure you have sufficient permissions, and that you have the proper interface or pipe specified.
    #============================================================================
    sleep (5);

    # Get STATUS of newly created TSHARK capture background process
    $self->{TSHARKPROCESS}->{status} = $self->_checkChildProcessStatus();

    unless ( $self->{TSHARKPROCESS}->{status} ) {
        if ( defined $self->{TSHARKPROCESS}->{pid} ) {
            $logger->debug(__PACKAGE__ . ".$subName: $a{testId} ERROR: Process create failed.");  
            $main::failure_msg .= "TOOLS:TSHARK-tsharkprocess creation failed; ";
        }

        # Kill the TSHARK capture process
        if ( $self->_killChildProcess() ) {
            # Returns 1 if the process no longer exists once die has completed
            $logger->info(__PACKAGE__ . ".$subName: $a{testId} tshark capture process killed . . . PID($self->{TSHARKPROCESS}->{pid})");
        }

        # Clear all the variables
        foreach my $key ( keys %{$self->{TSHARKPROCESS}} ) {
            $self->{TSHARKPROCESS}->{$key} = undef;
        }
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName: $a{testId} SUCCESS: Process created, PID($self->{TSHARKPROCESS}->{pid}), status(Alive)");
        $retValue = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
    return $retValue;
}

=head2 stopCaptureProcess()

=over

=item DESCRIPTION: 

 The function is used to stop TSHARK capture process running in background.
 It will then return 1 or 0 depending on this.

=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    timeout - i.e. DEFAULTTIMEOUT 60 seconds
    testId  - i.e. TMS Test Case (6 digits) ID

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - Success
 0 - Failure

=item EXAMPLE: 

    unless ( $TsharkObj->stopCaptureProcess(
                            timeout => 20,
                            testId  => $TestId,
            ) ) {
        my $errMessage = "  FAILED - stopCaptureProcess()";
        $logger->error("$errMessage");
        $testStatus->{reason} = $errMessage;
        return $testStatus;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  SUCCESS - stopCaptureProcess().");

=back

=cut

sub stopCaptureProcess {
    my ($self, %args ) = @_;
    my $subName = 'stopCaptureProcess()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . "..$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $retValue = 0;
 
    my %a = (
        timeout => $self->{DEFAULTTIMEOUT},
        testId  => '',
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    # $self->_info( subName => $subName, %a );

    unless ( defined $self->{TSHARKPROCESS}->{pid} ) {
        $logger->debug(__PACKAGE__ . ".$subName: $a{testId} ERROR: NO Process running i.e. PID in not defined.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    # Get STATUS of TSHARK capture background process
    $self->{TSHARKPROCESS}->{status} = $self->_checkChildProcessStatus();

    unless ( $self->{TSHARKPROCESS}->{status} ) {
        # Returns 1 if the process no longer exists
        $retValue = 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName: $a{testId} Process PID($self->{TSHARKPROCESS}->{pid}), status(Alive)");

        # Kill the TSHARK capture process
        if ( $self->_killChildProcess() ) {
            $retValue = 1;
            
            my $duration = $self->{TSHARKPROCESS}->{endTime} - $self->{TSHARKPROCESS}->{startTime};
            $logger->debug(__PACKAGE__ . ".$subName: $a{testId} SUCCESS: CHILD Process killed, PID($self->{TSHARKPROCESS}->{pid}), duration($duration).");
        }
        undef %{$self->{TSHARKPROCESS}};
    }

    if ( $retValue ) {
        undef %{$self->{TSHARKPROCESS}};
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
    return $retValue;
}

=head2 _reapChildProcess()

=over

=item DESCRIPTION:

 Reap the child.  
 If the first argument is 0 the wait should return  immediately, 1 if it should wait forever.  
 If this number is  non-zero, then wait.  If the wait was sucessful, then delete $self->{TSHARKPROCESS}->{object} and set $self->{TSHARKPROCESS}->{exitValue} to the OS specific class return of _reapChildProcess.  

=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    timeout - wait time, default is 0

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - if we sucessfully waited
 0 - otherwise

=back

=cut

sub _reapChildProcess {
    my $self    = shift;
    my $timeout = shift || 0;

    return 0 unless exists($self->{TSHARKPROCESS}->{object});

    # Try to wait on the process, using _waitPID() call,
    # which returns one of three values.
    #   (0, exit_value) : sucessfully waited on.
    #   (1, undef)  : process already reaped and exist value lost.
    #   (2, undef)  : process still running.
    my ($result, $exitValue) = $self->_waitPID($timeout);

    if ($result == 0 or $result == 1) {
        $self->{TSHARKPROCESS}->{exitValue} = defined($exitValue) ? $exitValue : 0;
        delete $self->{TSHARKPROCESS}->{object};
        # Save the end time of the process.
        $self->{TSHARKPROCESS}->{endTime} = time;
        return 1;
    }
    return 0;
}

=head2 _checkChildProcessStatus()

=over

=item DESCRIPTION:

    If $self->{TSHARKPROCESS}->{object} is not set, then the process is definitely not running.
    If $self->{TSHARKPROCESS}->{exitValue} is set, then the process has already finished.
    Try to reap the child.  If it doesn't reap, then it's 'alive'.    

=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 None

=back

=cut

sub _checkChildProcessStatus {
    my $self = shift;

    # If $self->{TSHARKPROCESS}->{object} is not set,
    # then the process is definitely not running.
    return 0 unless exists($self->{TSHARKPROCESS}->{object});

    # If $self->{TSHARKPROCESS}->{exitValue} is set, then the process has already finished.
    return 0 if exists($self->{TSHARKPROCESS}->{exitValue});

    # Try to reap the child.  If it doesn't reap,
    # then it's 'alive'.
    !$self->_reapChildProcess(0);
}

=head2 _killChildProcess()

=over

=item DESCRIPTION:

    See if the process has already died.
    Kill the process using the OS specific method.
    See if the process status is still 'alive'.

=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 None

=back

=cut

sub _killChildProcess {
    my $self = shift;

    # See if the process has already died.
    return 1 unless $self->_checkChildProcessStatus();

    # Kill the process using the OS specific method.
    $self->_killProcessUsingSignals();

    # See if the process status is still 'alive'.
    !$self->_checkChildProcessStatus();
}

=head2 _killProcessUsingSignals()

=over

=item DESCRIPTION:

    Try to kill the process with different signals.
    Calling _checkChildProcessStatus() will collect the exit status of the program.


=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 None

=back

=cut

sub _killProcessUsingSignals {
    my $self = shift;

    # Try to kill the process with different signals.
    # Calling _checkChildProcessStatus() will collect
    # the exit status of the program.
    SIGNAL: {
        foreach my $signal (qw(HUP QUIT INT KILL)) {
            my $count = 5;
            while ($count and $self->_checkChildProcessStatus()) {
                --$count;
                kill($signal, $self->{TSHARKPROCESS}->{object});
                last SIGNAL unless $self->_checkChildProcessStatus();
                sleep 1;
            }
        }
    }
}

=head2 _killProcessUsingSignals()

=over

=item DESCRIPTION:

    Wait for the child.
    Try to wait on the process.
    Grab the exit value if the process is finished.
    We don't know the exist status, if the process is already reaped.
    Retry if waitpid caught a signal.   


=item ARGUMENTS:

 Mandatory Args:
    None

 Optional Args:
    timeout

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 (0, $?) - if the process is finised.
 (1,0) - if the process is already reaped.
 (2,0) - if the process is still running. 

=back

=cut

sub _waitPID {
    my $self    = shift;
    my $timeout = shift;

    {
        # Try to wait on the process.
        my $result = waitpid($self->{TSHARKPROCESS}->{object}, $timeout ? 0 : WNOHANG);
        # Process finished.  Grab the exit value.
        if ($result == $self->{TSHARKPROCESS}->{object}) {
            return (0, $?);
        }
        # Process already reaped.  We don't know the exist status.
        elsif ($result == -1 and $! == ECHILD) {
            return (1, 0);
        }
        # Process still running.
        elsif ($result == 0) {
            return (2, 0);
        }
        # If we reach here, then waitpid caught a signal, so let's retry it.
        redo;
    }

    return 0;
}

=head2 _info()

=over

=item DESCRIPTION:

  Subroutine to print all arguments passed to a sub.
  Used for debuging only.


=item ARGUMENTS:

 Mandatory Args:
    %args - argument hash

 Optional Args:
    None

=item PACKAGE:

 SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item RETURNS:

 1 - Success
 0 - Failure

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
  

=head2 startCapturing()

=over

=item DESCRIPTION:

    This subroutine starts capturing by executing tethereal command.

=item ARGUMENTS:

   Mandatory:
    -cmd     => Command to execute ('tethereal -i eth0 -w test.pcap')

    Optional:
    -timeout => Timeout for command complition
                Default => 20;

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $tsharkObj->startCapturing( -cmd     => 'tethereal -i eth0 -w test.pcap',
                                -timeout => 30);

=back

=cut

sub startCapturing {
    my ($self, %args) = @_;
    my $sub = "startCapturing()";
    my %a   = ( -timeout => '20');
    my (@cmdResult, $cmdString);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    unless ( exists $a{-cmd} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory -cmd is missing in argument");
        return 0;
    }
    $cmdString = $a{-cmd};           
    #make sure we have directory before starting the capture
    unless ($self->{WINDOWS}) {
        if ($cmdString =~ /.*\s+(\S+\/)(\w+\.pcap)/) { 
            $self->{conn}->cmd("mkdir -p $1");
            push(@{$self->{PCAP_FILES}},$1.$2);
        }
        else{
            $logger->warn(__PACKAGE__ . ".$sub: pcap file not found");
        } 
    } else { 
        my $basepath ; 
        if ($cmdString =~ /.*\s+(\S+\\)\w+\.pcap/) { 
            $logger->info(__PACKAGE__ . ".$sub : Directory for creating pcap file is \'$1\' \n"); 
            my $cmd1 = "if exist \"$1\" (echo yes) else (echo no && mkdir $1)"  ;  
            $logger->info(__PACKAGE__ . ".$sub : checking for existence of mentioned directory \n");
            my @result = $self->{conn}->cmd($cmd1) ; 
            $logger->debug(__PACKAGE__ . ".$sub: Result of echo command is \'@result\' \n ");  
        } 
       
        unless (defined $self->{TMS_ALIAS_DATA}->{CLI}->{1}->{BASEPATH}) { 
            $logger->info(__PACKAGE__ . ".$sub: Basepath Not defined in TMS values : taking default value of \'C:\\Program Files\\Wireshark\' ") ;
            $basepath = "C:\\Program Files\\Wireshark" ; 
        } else {
            $basepath = "$self->{TMS_ALIAS_DATA}->{CLI}->{1}->{BASEPATH}" ;  
        } 
         
        $logger->info(__PACKAGE__ . ".$sub: Basepath is \'$basepath\' \n "); 
        $self->{conn}->cmd("C:"); 
        $self->{conn}->cmd("cd $basepath");
    }  

    my $port = $1 if($a{-cmd} =~ /\-i (\S+)/);
    if($VLAN_TAGS{$self->{OBJ_HOST}}{$port}){
	$logger->debug(__PACKAGE__ . ".$sub: Adding vlan id to the command as vlan is used by SBC");
	$a{-cmd} =~ s/$port/$port\.$VLAN_TAGS{$self->{OBJ_HOST}}{$port}/;
	$logger->debug(__PACKAGE__ . ".$sub: new cmd : $a{-cmd}");
    }
    unless( $self->{conn}->print("$a{-cmd}") ) {
        $logger->error(__PACKAGE__ . ".$sub: --> Execution for $a{-cmd} failed.");
        $main::failure_msg .= "TOOLS:TSHARK-tshark execution failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Execution of command $a{-cmd} is successful.");
    my ($prematch, $match);
    my $localPrompt = '/' . "Capturing on" . '/i';
    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => "$localPrompt",
                                                           -match     => '/tcpdump\: listening on/',
                                                           -timeout   => $a{-timeout})) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after $a{-cmd}.");
        $main::failure_msg .= "TOOLS:TSHARK-tcpdump execution failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: buffer: ". Dumper($self->{conn}->buffer));
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }

    sleep(2); #added sleep because even after "Capturing on" message comes it takes a fraction of sec to actual start capturing the packets
    $logger->info(__PACKAGE__ . ".$sub: Prompt match is successful, Prematch --> $prematch and Match --> $match");

    $logger->debug(__PACKAGE__ . ".$sub: Starting tetherial is successful !!!!");                

    return 1;
}

=head2 stopCapturing()

=over

=item DESCRIPTION:

    This subroutine is used to stop capturing

=item ARGUMENTS:

   Optional:    
    -timeout => Timeout for command complition
                Default => 20;

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $tsharkObj->stopCapturing(-timeout => 30);
    $tsharkObj->stopCapturing();

=back

=cut

sub stopCapturing {
    my ($self, %args) = @_;
    my $sub = "stopCapturing()";
    my %a   = ( -timeout => '20');
    my (@cmdResult, $cmdString);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    my ($prematch, $match);
    if ( ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT},
                                                           -timeout   => 1 )) {   # Fix for TOOLS-5391
        $logger->debug(__PACKAGE__ . ".$sub: Prompt match is successful, Prematch --> $prematch and Match --> $match");
        $logger->debug(__PACKAGE__ . ".$sub:  TSHARK is completed ,before doing Ctrl-C");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1 ;
     } else {
    $logger->debug(__PACKAGE__ . ".$sub: Prompt match is not  successful, Prematch --> $prematch and Match --> $match");
    $main::failure_msg .= "TOOLS:TSHARK-unable toStop tshark; ";
}
    
    unless( $self->{conn}->put("\cC") ) {
        $logger->error(__PACKAGE__ . ".$sub: --> Sending Ctrl-C failed."); 
        $main::failure_msg .= "TOOLS:TSHARK-unable toStop tshark; ";
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Sending Ctrl-C is successful !!!!");
    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT},
                                                           -timeout   => $a{-timeout})) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after sending Ctrl-C.");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: Prompt match is successful, Prematch --> $prematch and Match --> $match");
    
    $logger->debug(__PACKAGE__ . ".$sub: Stopping tetherial is successful !!!!");  
    
   
    return 1;
}

=head2 copyCapturedLogToServer()

=over

=item DESCRIPTION:

    This subroutine is used to copy the captured log to a server  .

=item Arguments:

    Mandatory:
        -srcFiles  => Captured log file names

    Optional:
        -userName     => Login ID, Default: root
        -passwd       => Login password, Default: sonus1
        -loginPort    => Login port, Default: 22 (SSH)   
        -timeStamp    => Time stamp
                         Default => Current timestamp which is calculated in subroutine
        -deviceType   => Device type like SGX/PSX/GSX etc.
                         Default => NONE                              
        -variant      => Test case variant "ANSI", "ITU" etc
                         Default => "NONE"
	-testCaseID   => Test Case Id
        -logDir       => Logs are stored in this directory 
                         Default: It will copy to your present directory where you are running the tests
        -cptInterface => Device interface on which capturing is enabled 
                         Default: "NONE"                         
        -zipCapturedLog => If set to '1' it will zip the copied captured logs in your directory
                           Defaullt; set to '0'

=item Return Values:

    $fileName - Incase of success
    0         - Incase of failure

=item Example:

    $tsharkObj->copyCapturedLogToServer(-srcFiles  => '/home/Administrator/test.pcap');

    $tsharkObj->copyCapturedLogToServer(-srcFiles  => ['/home/Administrator/test.pcap', '/home/Administrator/test1.pcap', '/home/Administrator/test2.pcap']);

    $tsharkObj->copyCapturedLogToServer(-loginPort    => '2024'
                                        -userName     => 'ssuser',
                                        -passwd       => 'ssuser',
                                        -logDir       => '/home/shayyal/ats_user/logs/'
                                        -variant      => 'ANSI',
                                        -cptInterface => "eth0",
                                        -srcFiles  => '/home/Administrator/test.pcap',);                                        

=item Author:

    Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub copyCapturedLogToServer {
    my ($self, %args) = @_;
    my $sub = "copyCapturedLogToServer";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my ($pcap_files, $dest_file, $tar_file, %scpArgs, $zipCapturedLog, $hostName);
    my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
    $year  += 1900;
    $month += 1;
    my $timeStamp = $year . $month . $day . '-' . $hour . $min . $sec;
    my %a = (-userName     => 'root',
             -passwd       => 'sonus1',
             -variant      => 'NONE',
             -deviceType   => 'NONE',
             -loginPort    => '22',
             -logDir       => $LOG_DIRECTORY || "$ENV{ HOME }/ats_user/logs", #SBX5000_$main::TESTSUITE->{TESTED_VARIANT}/$main::TESTSUITE->{TESTED_RELEASE}/$temp_version/
             -cptInterface => "NONE",
             -timeStamp    => "$timeStamp",
             -zipCapturedLog => '0');
    unless ($self->{OBJ_HOSTNAME}) {
        $logger->error(__PACKAGE__ . ".$sub: TMS entry for HOSTNAME is missing so initialising host name to NONE");
        $hostName = "NONE";
    } else {
        $hostName = $self->{OBJ_HOSTNAME};
    }

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    my $file;
    if($a{-testCaseID}){
        $file = "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "$a{-deviceType}-" . "$hostName-" . "$a{-cptInterface}-";
    } else {
        $file = "$a{-timeStamp}-" . "$hostName";
    }
    if (not $a{-srcFileName}) {
        $logger->error(__PACKAGE__ . ".$sub: Source\(captured log\) file name is missing. This is a mandatory parameter");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    } elsif (ref($a{-srcFileName}) eq 'ARRAY') {
		$pcap_files = "@{$a{-srcFileName}}";
		$zipCapturedLog = 1;
    } else {
        chomp($a{-srcFileName});
        $pcap_files = $a{-srcFileName};
        if ($pcap_files =~ /\.pcap$/i) {
            $dest_file = $file.'_TSHARK'.'.pcap';
        } else {
            $dest_file = $file.'_TSSHARK'.'.log';
        }
    }

    if($zipCapturedLog){
        $tar_file = '/tmp/'.$file.'_TSHARK.tgz';
        $logger->info(__PACKAGE__ . ".$sub: Tar File will be --> $tar_file");
        my $tar_res;
        unless($tar_res = $self->execCmd("tar \-czf $tar_file $pcap_files")){
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute 'tar \-czf $tar_file $pcap_files'");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        if(grep(/No such file or directory/,@$tar_res)){
	        $logger->error(__PACKAGE__ . ".$sub: Pcap file does not exist");
            $self->execCmd("rm -f $tar_file");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        unless($tar_res = $self->execCmd("chmod a+r $tar_file")){
            $logger->error(__PACKAGE__ . ".$sub: Failed to chmod $tar_file");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
		$a{-srcFileName} =  $tar_file;
		$dest_file = $file.'_TSHARK.tgz';
    }

    $logger->info(__PACKAGE__ . ".$sub: =================================================");
    $logger->info(__PACKAGE__ . ".$sub: Login IP     : $self->{OBJ_HOST}");
    $logger->info(__PACKAGE__ . ".$sub: Login Port   : $a{-loginPort}");
    $logger->info(__PACKAGE__ . ".$sub: Login ID     : $a{-userName}");
    $logger->info(__PACKAGE__ . ".$sub: Login Pass   : $a{-passwd}");
    $logger->info(__PACKAGE__ . ".$sub: Source File  : $a{-srcFileName}");
    $logger->info(__PACKAGE__ . ".$sub: Dest File    : $a{-logDir}\/$dest_file");
    $logger->info(__PACKAGE__ . ".$sub: =================================================");

    $scpArgs{-hostip} = "$self->{OBJ_HOST}";
    $scpArgs{-hostuser} = $a{-userName};
    $scpArgs{-hostpasswd} = $a{-passwd};
    $scpArgs{-sourceFilePath} = $self->{OBJ_HOST}.':'.$a{-srcFileName};
    $scpArgs{-destinationFilePath} = $a{-logDir}.'/'.$dest_file;
    $scpArgs{-scpPort} = $a{-loginPort};

    my $flag = 1;
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
        $flag = 0;
    }
    if($zipCapturedLog){
        $self->execCmd("rm -f $tar_file");
        $logger->debug(__PACKAGE__ . ".$sub: Successfully removed tar file");
    }
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$flag]");
    return $flag;
}

=head2 grepCapturedLogForPattern()

=over

=item DESCRIPTION:

    This subroutine is used to check given pattern in captured log file.

=item Arguments:

    Mandatory:
        -logFileName => Captured log file name
        -pattern     => Pattern to check in log file

=item Return Values :

    $count - Number of times matched incase of success
    0      - Incase of failure

=item Example :

    $tsharkObj->grepCapturedLogForPattern(-logFileName  => '/home/Administrator/test.pcap',
                                          -pattern      => 'IP\s+10\\.23\\.28\\.65\\.42385\s+>');    

=item Author :

    Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub grepCapturedLogForPattern() {
    my ($self, %args) = @_;
    my $sub = "grepCapturedLogForPattern()";
    my ($cmd, $isPlainTxtFile, @cmdResults, %a);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    if (not exists $a{-logFileName}) {
        $logger->error(__PACKAGE__ . ".$sub: Captured file name is missing. This is a mandatory argument");
        $main::failure_msg .= "TOOLS:TSHARK-Captured file NotFound; ";
        return 0;
    }
    
    if (not exists $a{-pattern}) {
        $logger->error(__PACKAGE__ . ".$sub: Pattern is missing. This is a mandatory argument");
        $main::failure_msg .= "TOOLS:TSHARK-Pattern NotFound; ";
        return 0;
    }
            
    $logger->info(__PACKAGE__ . ".$sub: =================================================");    
    $logger->info(__PACKAGE__ . ".$sub: Log File : $a{-logFileName}");
    $logger->info(__PACKAGE__ . ".$sub: Pattern  : $a{-pattern}");
    $logger->info(__PACKAGE__ . ".$sub: =================================================");

	if ($a{-logFileName} =~ /\.pcap$/i) {
		$cmd = 'tcpdump -vvv -tttt -nn -r ' . $a{-logFileName};
		$logger->info(__PACKAGE__ . ".$sub: Log file is in pcap format, using \'tcpdump\' to display the file");
	} else {
		$isPlainTxtFile = 1;
		$cmd = 'cat ' . $a{-logFileName};
		$logger->info(__PACKAGE__ . ".$sub: Log file is in plain text format, using \'cat\' to display the file");
	}

	$logger->info(__PACKAGE__ . ".$sub: Issuing a command --> $cmd");

	@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT});
	sleep (5);
	unless (@cmdResults) {
		$logger->error(__PACKAGE__ . ".$sub: execCmd COMMAND EXECUTION ERROR OCCURRED");
                $main::failure_msg .= "TOOLS:TSHARK-tshark execution failed; ";
		return 0;
	}
		
	$logger->info(__PACKAGE__ . ".$sub: Command execution successful !!!!!");

	my ($line_in, $count, @patterns);
	$count = 0;

	$logger->debug(__PACKAGE__ . ".$sub: pattern is: '$a{-pattern}'");

	@patterns = split(" ", $a{-pattern});

	##################################################################################
	##  New Matching API for grepCapturedLogForPattern()							##
	##	Author: Mark Randall (email: mrandall@sonusnet.com) Oct 31 2012				##
	##																				##
	##	If there is any issues or confusion, please contact me.						##
	##################################################################################

	my @words;
	my $word;
	my $pattern;
	my $skipper = 0;
	my $matchCounter = 0;
	my $comboCounter = 0;
	my $orderCounter = 0;
	my $patternLen = @patterns;
    ##  	Uses 1 line at a time, from the TSHARK logs, we							##
    ##  remove any tabs and spaces from $line_in, and leave it with 1 space         ##
    ##  inbetween each word.                                                        ##
	foreach $line_in (@cmdResults) {
		@words = split("\t",$line_in);
		$line_in = "@words";
		@words = split(" ",$line_in);
    	##  	Uses 1 word at a time, from the $line_in var						##
    	##  We also set $skipper to equal $matchCounter, so that when we start      ##
    	##  matching words within the pattern, we can skip the ones we have ticked  ##
    	##  off (i.e. we have found) so that if we have duplicate words, we dont    ##
    	##  match the same word with the previous word in the pattern, and fail the ##
    	##	matching when we should pass it.                                        ##
		foreach $word (@words) {
			$skipper = $matchCounter;
		    ## 		We check that we get a word in $line_in that matches 			##
    		##  a word in the pattern, $orderCounter and $matchCounter are used as  ##
    		##  checkers. $orderCounter makes sure we get the pattern and $line_in  ##
    		##  to be matched in the correct order.                                 ##
    		##  $matchCounter makes sure we get all of the patterns words, and      ##
    		##  words in $line_in matched, i.e we dont incorrectly match for a      ##
    		##  missing IP address, but everything else matches.                    ##
			foreach $pattern (@patterns) {
				$orderCounter++;
				unless($skipper < 1) {
					$skipper--;
					next;
				}
				if ($word eq $pattern) {
					$matchCounter++;
					last;
				}
			} #end of 'foreach $pattern'

			##		$comboCounter is used to ensure we match a      			  	##
    		##  $line_in with the pattern without skipping words in the pattern.    ##		
			if ($matchCounter != ($comboCounter + 1)) {
				$matchCounter = 0;
				$comboCounter = 0;
			}
			else {
				$comboCounter++;
			}

			unless ($orderCounter == $matchCounter) {
				$matchCounter = 0;
				$comboCounter = 0;
			}
			$orderCounter = 0;
		} #end of 'foreach $word'

    	##  	$matchCounter and $patternLen are used to check that we got a exact ##
		##  match, and didn't have extra words at the end of $line_in    			##
    	##  and gave a false posistive match.                                    	##
		if ($matchCounter == $patternLen) {
			$count++;
			$logger->debug(__PACKAGE__.".$sub: Pattern matched[$count]");
		}
		$matchCounter = 0;
    	$comboCounter = 0;
    	$orderCounter = 0;
	} #end of 'foreach $line_in'

	$logger->debug(__PACKAGE__ .".$sub: Exiting with [$count]");

	@cmdResults = "";

    return $count;
}

=head2 deleteFile()

=over

=item DESCRIPTION:

    This subroutine is used to delete the (captured) log file from TSHARK server.

=item ARGUMENTS:

   Mandatory:
    -fileName     => Filename to be deleted

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $tsharkObj->deleteFile( -fileName => '/root/me.pcap');

=back

=cut

sub deleteFile {
    my ($self, %args) = @_;
    my $sub = "deleteFile()";
    my %a   = ( -timeout => '20');
    my (@cmdResult, $cmdString);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    unless ( exists $a{-fileName} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory -fileName is missing in argument");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: deleting a file \'$a{-fileName}\' from TSHARK server");
    
    $cmdString = "rm -rf $a{-fileName}";     
          
    unless( $self->execCliCmd("$cmdString") ) {
        $logger->error(__PACKAGE__ . ".$sub: --> Failed to delete a file \'$a{-fileName}\'");
        $main::failure_msg .= "TOOLS:TSHARK-FailedTo Delete \'$a{-fileName}\'; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Deleting of file \'$a{-fileName}\' is successful !!!!");
    
    return 1;
}

=head2 execCliCmd()

=over

=item DESCRIPTION:

    This subroutine is used to execute command on TSHARK server

=item ARGUMENTS:

   Mandatory:
   Command to execute.

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $tsharkObj->execCliCmd("tethereal -i eth0 -w test.pcap ");

=back

=cut

sub execCliCmd {
    my ($self, $cmdString) = @_;
    my $sub = "execCliCmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    
    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }
    
    my ($arrRef, @cmdResult);
    unless ($arrRef = $self->execCmd("$cmdString")) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmdString'\n@cmdResult");
       $main::failure_msg .= "TOOLS:TSHARK-FailedTo execute command; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
   
    @cmdResult = @{$arrRef};
    my $line;
    foreach $line (@cmdResult) {
        if ($line =~ m/Permission|Error|unable/i) {
            $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmdString'");
            $main::failure_msg .= "TOOLS:TSHARK-PermissionDenied or UnableToExecute; ";
            $logger->error(__PACKAGE__ . ".$sub: Error message: $line");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
       
    return 1;
}

    
=head2 execCmd()

=over

=item DESCRIPTION:

    This subroutine is used to execute command on TSHARK server

=item ARGUMENTS:

   Mandatory:
   Command to execute.

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0            - fail
    \@cmdresults - Success (Reference to command result array)

=item EXAMPLE:

    $tsharkObj->execCmd("tethereal -i eth0 -w test.pcap ");

=back

=cut

sub execCmd {
    my ($self, $cmdString) = @_;
    my $sub = "execCmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    
    $logger->debug(__PACKAGE__ . ".$sub: executing $cmdString command");
    
    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }
    $self->{conn}->buffer_empty;
    
    my @cmdResult;
    unless (@cmdResult = $self->{conn}->cmd(String => $cmdString, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmdString'\n@cmdResult");
        $main::failure_msg .= "TOOLS:TSHARK-FailedTo execute tshark ; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
   
    chomp(@cmdResult);
    @cmdResult = grep /\S/, @cmdResult;
    
    $logger->debug(__PACKAGE__ . ".$sub: Execution of \'$cmdString\' command is successfull !!!!");

    $logger->debug(__PACKAGE__ . ".$sub: ---------------------- COMMAND OUTPUT -----------------------");
    my $line;
    foreach $line (@cmdResult) {
        $logger->debug(__PACKAGE__ . ".$sub: $line");
    }
    $logger->debug(__PACKAGE__ . ".$sub: ---------------------- COMMAND OUTPUT ENDS -------------------");
    return \@cmdResult;
}    

=head2 verifySipMsg()

=over

=item DESCRIPTION:

    This subroutine is used to validate sip message content from captured pcap/text file.

=item ARGUMENTS:

   Mandatory:
       -pcap / -testFile => captured pcap or convertd test file (full path)

       -pattern => serach data hash referance having below pattern
					( 'msg type1' => { 'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
					'msg type1' => { 'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
					)
   Optional:

       -readfilter => The read filter used while running the "tshark -2 -V -R .." command

       -case_sensitive_search => Pass this value to 1 if pattern search has to be Case sensitive, by default the search is Case Insensitive.  
                                Ex : -case_sensitive_search => 1  

       -unique_check => Pass the value as 1 , if you need to check the patterns exist only once.It will return 0, if  more than one occurance of pattern found.
                      Ex : unique_check => 1       
       -returnpattern => 1, When we pass this value as 1, It will return all the records for the given message instance. It will be helpful to get all the values of a particular header from the given message instance. See the below example for more detail.
       -reverse_check => 1      this argument should be set if the pattern not found need to be considered as true

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search pattern is not found)

=item EXAMPLE:

    my %input = (-pcap => '/auto/v030/test.pcap',
	             -pattern => { 'INVITE' => { 1 => ['To: "PK"<sip:8740400000@10.54.78.21>','Connection Information (c): IN IP4 10.54.78.21'],
				                             2 => ['To: "PK"<sip:8740400000@10.54.78.21>','Connection Information (c): IN IP4 10.54.78.21']
										   },
								'BYE'   => 	{ 1 => ['To: "PK"<sip:8740400000@10.54.78.21>','Connection Information (c): IN IP4 10.54.78.21'],
				                             2 => ['To: "PK"<sip:8740400000@10.54.78.21>','Connection Information (c): IN IP4 10.54.78.21']
										   }
                              },
                   -endboundry => 'MIME TYPE',  
                   -reorder => 1 (Optional)

                 );
    my %egress_sipinput = (	-pcap => "$TESTSUITE->{PATH}/logs/$EG_TSHARKFileName",

 				-pattern =>{ 'MESSAGE' => { 1 => ["Route: <sip:$sipp_ipServer:$calledport;lr>"] }

                                           },
				-unique_check => 1,
			  );							  
    $Obj->verifySipMsg(%input);

# Example: When you want to pass -returnpattern => 1 

       my %input =                         (
    		-pcap => "794052_TSHARK.pcap",
    		-pattern => {
    	    		'REGISTER'   =>{ 1 => ["Path: <sip:.*>"]}
    			},
    		-returnpattern => 1,
                -reorder =>1(Optional)
	);

    my $result = $Obj->verifySipMsg(%input);
    # $result contain all the headers and values of first 'REGISTER'. 
    # To get all the values for {REGISTER}{1}{Path}, we need to use $result like below
    my @pathValues = @{$result->{REGISTER}{1}{Path}};

=back

=cut

sub verifySipMsg {
    my ($self, %args) = @_;
    my $sub = "verifySipMsg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: args: ". Dumper(\%args));

    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }

    if (!defined $args{-pcap} and !defined $args{-testFile}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument pcap/testfile is empty or blank");
       $main::failure_msg .= "TOOLS:TSHARK-pcap/testfile is empty; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless (defined $args{-pattern}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument search pattern data is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my (@cmdResult, $cmd, $readfilter,@status,$newPcapFile ,@cmd_arr ,@file_arr ) = ((), '', '', (), '', () , () );
    $readfilter = $args{-readfilter} if(defined $args{-readfilter});
    $readfilter ||= "sip";

    #Setting Tshark_Rm_Duplicate to 1 as default to fix TOOLS-5127
    unless(defined $main::TESTSUITE->{Tshark_Rm_Duplicate}){
        $main::TESTSUITE->{Tshark_Rm_Duplicate} = 1;
        $logger->warn(__PACKAGE__ . ".$sub: Setting Tshark_Rm_Duplicate to 1, since its not defined in TESTSUITE. Set it as 0 in TESTSUITE, if you don't need to remove duplicates.");
    }
    #TOOLS-20119
    if ($args{-pcap}) {
        if ( $main::TESTSUITE->{Tshark_Rm_Duplicate} ){
             push(  @file_arr , 'edit.pcap' );
             push(  @cmd_arr , 'editcap -D 500');
        }
        if($args{-reorder}){
            push(  @file_arr ,'reorder.pcap');
            push(  @cmd_arr ,'reordercap -n' );
        }
        my $flag = 0;
        for (my $i = 0 ;$i < @file_arr; $i++){
             my $appendCmd = "$cmd_arr[$i] $args{-pcap} $file_arr[$i]" ;
             $logger->info(__PACKAGE__ . ".$sub: executing command $appendCmd ");
             unless (@cmdResult = $self->{conn}->cmd($appendCmd)) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to execute the command : \'$appendCmd\' ");
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                $flag = 1;
                last;
             }

            $logger->info(__PACKAGE__ . ".$sub: executing \'echo \$?\' to check the status ");
            my @result1 = ($self->{conn}->cmd("echo \$?")) ;
            unless ( $result1[0] == 0 ) {
                $logger->error(__PACKAGE__ . ".$sub:  CMD ERROR: return code : $result1[0] --\n@result1");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                $flag = 1;
		last;
            }
            $args{-pcap} =$file_arr[$i] unless(grep /.*input file is already in order!/ ,@cmdResult);
       }
       return 0 if($flag ==1);
    }

    $cmd = (defined $args{-testFile} and $args{-testFile}) ? "cat $args{-testFile}" : "tshark -2 -V -R \"$readfilter\" -r $args{-pcap}";
    unless (@cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmd'\n @cmdResult");
        $main::failure_msg .= "TOOLS:TSHARK-tshark execution failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: cmd: $cmd");
    $logger->debug(__PACKAGE__ . ".$sub: For debugging check the command output on session input log, $self->{sessionLog2}");

    $cmd = "echo \$?";
    unless (@status = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed while trying to get the status of the previous command execution \n '@status'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    #Deleting the temporary file we created so that it doesn't affect the next call of this subroutine. The status(in the above unless condition) is checked but we have to delete the file first because we have a return if the status($status[0]) is not equal to 0. 
        $cmd = "rm -rf @file_arr";
        unless ($self->{conn}->cmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute the command : \'$cmd\' ");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
    
    chomp @status;
    unless( $status[0] == 0 ){
        $logger->error(__PACKAGE__ . ".$sub: An error occured while filtering the infile/pcap file. \n Error code : '$status[0]' \n Command Output : '@cmdResult'"); 
       $main::failure_msg .= "TOOLS:TSHARK-Unable ToFilter pcapFile; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0; 
    }

    my ($pdu_start, $sip_line, %count, %temp_result) = ('','', (), ());
    foreach my $line (@cmdResult) {
        chomp $line;
        $pdu_start =1 if ($line =~ /^Session Initiation Protocol.*/); #Changed the reg exp to fix TOOLS-3874
        unless (defined $args{-endBoundry}) {
            $pdu_start =0 if ( $line =~ /^Frame/); #changed the default end boundry to /^Frame/ to fix TOOLS-2849. It was /(Content-Length:0|Media Attribute Value:)/
        } else {
            $pdu_start =0 if ( $line =~ /\Q$args{-endBoundry}\E/);
        }
        
        next unless $pdu_start;
        if ($line =~ /^\s*(Request-Line:\s+(\S+)\s+|Status-Line: SIP\/2.0\s+(.*)\s*$)/) { 
            $sip_line = uc ($2 || $3);
            $count{$sip_line}++;
        }
        next unless $sip_line;
        push (@{$temp_result{$sip_line}{$count{$sip_line}}}, $line);
    }

    $logger->debug(__PACKAGE__ . ".$sub: temp_result: ". Dumper(\%temp_result));

    my $input = $args{-pattern};
    my %returnvalues;
    my $flag = 1;

    foreach my $msg (keys %{$input}) {
        foreach my $instance (keys %{$input->{$msg}} )  {
            unless ($temp_result{uc($msg)}{$instance}) {
               $logger->error(__PACKAGE__ . ".$sub: there is no $instance occurance of $msg");
	       $flag =0;
	       last;
            }
	    if ( defined $args{-returnpattern} and $args{-returnpattern} == 1) {
 	        foreach (@{$temp_result{uc($msg)}{$instance}}) {
		    $_ =~ s/^\s+//;
		    chomp;
                    if($_ =~ /\[?\s*([\w\s-]+):\s*(.*)\]?/){
                        push (@{$returnvalues{$msg}{$instance}{$1}},$2);
                    }
                }
	    }   
    
            my $case_sensitive ; 
            unless (defined $args{-case_sensitive_search} and $args{-case_sensitive_search}) { 
                $logger->info(__PACKAGE__ . ".$sub: Case Insensitive Search for the Input Pattern");
                $case_sensitive = 0 ; 
            } else {
                $logger->info(__PACKAGE__ . ".$sub: Case Sensitive Search for the Input Pattern");
                $case_sensitive = 1 ;  
            } 
            foreach (@{$input->{$msg}->{$instance}}) {
               $logger->info(__PACKAGE__ . ".$sub: checking for input_msg_instance : $_ "); 
               my @temp_pattern = split(/\.\*/, $_);
               map { $_ = "\Q$_\E"} @temp_pattern; # escaping character belongs to property of regex
               my $pat = join(".*", @temp_pattern); # i want to give some value to .* so retaining it
               $pat ||= "\Q$_\E"; # orginale value if ther is now .* present
               
               my $output ;  
               unless ($case_sensitive) {
                  $output = grep (/$pat/i , @{$temp_result{uc($msg)}{$instance}}) ;
               } else {
                  $output = grep (/$pat/ , @{$temp_result{uc($msg)}{$instance}})  ;
               }

               if ( $args{-unique_check} && ( $output > 1 ) ) {
                   $logger->error(__PACKAGE__ . ".$sub: Unique check fails. Search pattern \'$pat\' found $instance -> $msg $output times");
		   $flag = 0;
               } elsif ( $output ){
                   if($args{-reverse_check}){
		       $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' found $instance -> $msg");
		       $flag = 0;
		       last;
		   }else{
		       $logger->info(__PACKAGE__ . ".$sub: search pattern \'$pat\' found $instance -> $msg");
		   } 
               } else  {
		   my @xml_arr = ();
                   if ($_ =~ /^\<\?xml/){
                        $logger->info(__PACKAGE__ . ".$sub:Since the pattern is <?XML, Searching again by splitting it by space");
                        $_ =~ s/\?\>$/ ?>/;
                        @xml_arr = split(/\s+/,$_);
		   }
		   elsif($_ =~ /(\<.+\>)(.+)(\<.+\>)/){
		        $logger->info(__PACKAGE__ . ".$sub: Splitting data and trying validation.");
	   	        @xml_arr = ($1, $2, $3);
		   }
		   if(scalar(@xml_arr)){		
                       foreach(@xml_arr){
                           my @temp_pattern = split(/\.\*/, $_);
                           map { $_ = "\Q$_\E"} @temp_pattern; # escaping character belongs to property of regex
                           my $pat = join(".*", @temp_pattern); # i want to give some value to .* so retaining it
                           $pat ||= "\Q$_\E"; # orginale value if ther is now .* present
                           my $output ;
                           unless ($case_sensitive) {
                               $output = grep (/$pat/i , @{$temp_result{uc($msg)}{$instance}}) ;
                           } else {
                                $output = grep (/$pat/ , @{$temp_result{uc($msg)}{$instance}})  ;
                           }
                           my $logvar;
                           if ($output) {
                               $output = 1;
                               $logvar = '';
                           }else {
                               $output = 0;
                               $logvar = 'not';
                           }
                           if ($args{-reverse_check} ^ $output){
                               $logger->info(__PACKAGE__ . ".$sub: search pattern \'$pat\' $logvar found $instance -> $msg");
                           }else{
                               $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' $logvar found $instance -> $msg");                  
			       $flag = 0;
			       last;
                           }
                       }
                   }elsif(!$args{-reverse_check}){
                        $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' not found $instance -> $msg");
		        $flag = 0;
                   }
               }
	       last unless($flag);	
            }
            last unless($flag);
        }
	last unless($flag);
    }
    unless($flag) {
        if ($args{-reverse_check}) {
            $main::failure_msg .= "TOOLS:TSHARK-Pattern Found; ";
        }else{
            $main::failure_msg .= "TOOLS:TSHARK-Pattern NotFound; ";
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$flag]");
    if ( defined $args{-returnpattern} and $args{-returnpattern} == 1 and $flag) {
        return \%returnvalues;
    }
    return $flag;
}

=head2 verifyDiameterMsg()

=over

=item DESCRIPTION:

    This subroutine is used validate diameter message content from captured pcap/text file


=item ARGUMENTS:

   Mandatory:
       -pcap / -testFile => captured pcap or convertd test file (full path)
       -pattern => serach data hash referance having below pattern
					( 'flag1' => { 'command-code1' => {'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
									'command-code2' => {'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
							     }
					'flag2' => { 'command-code1' => {'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
									'command-code2' => {'occurance1' => ['pattern1','pattern2'.....]],
					                  'occurance1' => ['pattern1','pattern2'.....]], },
							     }
					)
    Optional:
    -reverse_check

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search pattern is not found)

    NOTE -> only .* is valad as regex pattern in user input

=item EXAMPLE:

    my %input = (-pcap => '/auto/v030/test.pcap',
	             -pattern => { '0xc0' => { '265 AA' => { 1 => ['AVP: Origin-Realm(296) l=25 f=-M- val=pcscf-rx-ims.test', 'Flow-Description: permit out 17 from any to 10.54.78.21 6000'],
				                             2 => ['AVP: Origin-Realm(296) l=25 f=-M- val=pcscf-rx-ims.test', 'Flow-Description: permit out 17 from any to 10.54.78.21 6000'],
										               },
										   '275 Session-Termination' => { 1 => ['AVP: Origin-Realm(296) l=25 f=-M- val=pcscf-rx-ims.test', 'Flow-Description: permit out 17 from any to 10.54.78.21 6000'],
				                             2 => ['AVP: Origin-Realm(296) l=25 f=-M- val=pcscf-rx-ims.test', 'Flow-Description: permit out 17 from any to 10.54.78.21 6000']
										               },
										 }
                 );

    $Obj->verifyDiameterMsg(%input);

=back

=cut

sub verifyDiameterMsg {
    my ($self, %args) = @_;
    my $sub = "verifyDiameterMsg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: args: ". Dumper(\%args));

    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }

    if (!defined $args{-pcap} and !defined $args{-testFile}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument pcap/testfile is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless (defined $args{-pattern}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument search pattern data is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my (@cmdResult, $cmd) = ((), '');

    #TOOLS-8075: Added code to remove duplicate
    #Setting Tshark_Rm_Duplicate to 1 as default to fix TOOLS-5127
    unless(defined $main::TESTSUITE->{Tshark_Rm_Duplicate}){
        $main::TESTSUITE->{Tshark_Rm_Duplicate} = 1;
        $logger->warn(__PACKAGE__ . ".$sub: Setting Tshark_Rm_Duplicate to 1, since its not defined in TESTSUITE. Set it as 0 in TESTSUITE, if you don't need to remove duplicates.");
    }

    if ( $main::TESTSUITE->{Tshark_Rm_Duplicate} && $args{-pcap}) {
        my $newPcapFile =  'test.pcap';
        my $appendCmd = "editcap -D 500 $args{-pcap} $newPcapFile" ;

        $logger->info(__PACKAGE__ . ".$sub: executing command $appendCmd to remove duplicate packets if any");
        unless ($self->{conn}->cmd($appendCmd)) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute the command : \'$appendCmd\' ");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }

        $logger->info(__PACKAGE__ . ".$sub: executing \'echo \$?\' to check the status.");
        my @result1 = ($self->{conn}->cmd("echo \$?")) ;
        unless ( $result1[0] == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub:  CMD ERROR: return code : $result1[0] --\n@result1");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $args{-pcap} = $newPcapFile;
    }
    

    
    $cmd = (defined $args{-testFile} and $args{-testFile}) ? "cat $args{-testFile}" : "tshark -2 -V -R \'diameter\' -r $args{-pcap}"; #TOOLS-7597 diameter3gpp filter should be removed in verifyDiameterMsg of TSHARK.pm since it is no longer supported in SBC. 

    unless (@cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmd'\n @cmdResult");
        $main::failure_msg .= "TOOLS:TSHARK-tshark Execution Failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my ($pdu_start, $flag_code, $command_code, %count, %temp_result) = ('', '', '', (), ());
    foreach my $line (@cmdResult) {
        chomp $line;
        $pdu_start =1 if ($line =~ /Diameter Protocol\s*$/i);
        $pdu_start =0 if ($line =~ /(Service-Info-Status:|Result-Code:|Termination-Cause:)/);
        if ($line =~ /^\s*Flags:\s+(\w+)/) {
            $flag_code = $1;
        }
        next unless $flag_code;
        if ($line =~ /Command Code:\s+(\d+ \S+)/) {
            $command_code = $1;
            $count{"$flag_code-$command_code"}++;
        }
        next unless $command_code;
        next unless $count{"$flag_code-$command_code"};
        push (@{$temp_result{"$flag_code-$command_code"}{$count{"$flag_code-$command_code"}}}, $line) if ($line =~ /:/ and $line !~ /\.\.+/);
    }

    my $input = $args{-pattern};
    foreach my $msg1 (keys %{$input}) {
        foreach my $msg2 (keys %{$input->{$msg1}} )  {
           foreach my $instance (sort keys %{$input->{$msg1}->{$msg2}}) {
              unless ($temp_result{"$msg1-$msg2"}{$instance}) {
		         $logger->debug(__PACKAGE__ . ".$sub: COMMAND RESULT" .Dumper(\%temp_result));
                 if($args{-reverse_check}){
                    $logger->info(__PACKAGE__ . ".$sub: there is no $instance occurance for $msg1 - $msg2");
                    next;
                 }
                 $logger->error(__PACKAGE__ . ".$sub: there is no $instance occurance for $msg1 - $msg2");
                 $main::failure_msg .= "TOOLS:TSHARK-DiameterMsg Pattern NotFound; ";
                 $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                 return 0;
              } 
              foreach (@{$input->{$msg1}->{$msg2}->{$instance}}) {
                 my @temp_pattern = split(/\.\*/, $_);
                 
                 map { $_ = "\Q$_\E"} @temp_pattern; # escaping character belongs to property of regex
                 my $pat = join(".*", @temp_pattern); # i want to give some value to .* so retaining it
                 $pat ||= "\Q$_\E"; # orginale value if ther is now .* present

                 if (grep (/$pat/, @{$temp_result{"$msg1-$msg2"}{$instance}})) {
                     $logger->info(__PACKAGE__ . ".$sub: search pattern \'$pat\' found at $instance occurance for $msg1 - $msg2");
                     if ($args{-reverse_check}) {
                        $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' found at $instance occurance for $msg1 - $msg2");
                        $main::failure_msg .= "TOOLS:TSHARK-DiameterMsg Pattern Found when 'reverse_check' is enabled; ";
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        return 0;
                     }
                 } else {
                     if($args{-reverse_check}){
                        $logger->info(__PACKAGE__ . ".$sub: search pattern \'$pat\' not found at $instance occurance for $msg1 - $msg2");
                        next;
                     }
                     $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' not found at $instance occurance for $msg1 - $msg2");
                     $main::failure_msg .= "TOOLS:TSHARK-DiameterMsg Pattern MisMatch; ";
                     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                     return 0;
                 }
              }
           }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 verifyIpMsg()

=over

=item DESCRIPTION:

    This subroutine is used for Generic  IP message validation.

=item ARGUMENTS:

   Mandatory:
       -pcap / -testFile => captured pcap or convertd test file (full path)
       -pattern => serach data hash referance having below pattern
                                        ( 'ip type' => { 'occurance1' => ['pattern1','pattern2'.....]],
                                                          'occurance1' => ['pattern1','pattern2'.....]], },
                                        'ip type2' => { 'occurance1' => ['pattern1','pattern2'.....]],
                                                          'occurance1' => ['pattern1','pattern2'.....]], },
                                        )

                                -> valid ip type are v6 and v4

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search pattern is not found)

=item EXAMPLE:

    my %input = (-pcap => '/home/linuxadmin/PCR3037/LateMedia_V4_V6.pcap',
                  -pattern =>
                        { 'v4' =>
                           { 1 =>
                                 ['Differentiated Services Field: 0x00 (DSCP 0x00: Default; ECN: 0x00)', '0000 00.. = Differentiated Services Codepoint: Default (0x00)', '.... ..0. = ECN-Capable Transport (ECT): 0',        '.... ...0 = ECN-CE: 0'],
                            2 =>
                                  ['Differentiated Services Field: 0x00 (DSCP 0x00: Default; ECN: 0x00)','0000 00.. = Differentiated Services Codepoint: Default (0x00)','.... ..0. = ECN-Capable Transport (ECT): 0',        '.... ...0 = ECN-CE: 0']
                           },
                        'v6'   =>
                           { 1 => ['.... 0000 0000 .... .... .... .... .... = Traffic class: 0x00000000', '.... .... .... 0000 0000 0000 0000 0000 = Flowlabel: 0x00000000']
                                                   }
                        },
                  );

    $Obj->verifyIpMsg(%input);

=back

=cut

sub verifyIpMsg {
    my ($self, %args) = @_;
    my $sub = "verifyIpMsg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;

    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }

    if (!defined $args{-pcap} and !defined $args{-testFile}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument pcap/testfile is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless (defined $args{-pattern}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument search pattern data is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my (@cmdResult, $cmd) = ((), '');

    #TOOLS-8075: Added code to remove duplicate
    #Setting Tshark_Rm_Duplicate to 1 as default to fix TOOLS-5127
    unless(defined $main::TESTSUITE->{Tshark_Rm_Duplicate}){
        $main::TESTSUITE->{Tshark_Rm_Duplicate} = 1;
        $logger->warn(__PACKAGE__ . ".$sub: Setting Tshark_Rm_Duplicate to 1, since its not defined in TESTSUITE. Set it as 0 in TESTSUITE, if you don't need to remove duplicates.");
    }

    if ( $main::TESTSUITE->{Tshark_Rm_Duplicate} && $args{-pcap}) {
        my $newPcapFile =  'test.pcap';
        my $appendCmd = "editcap -D 500 $args{-pcap} $newPcapFile" ;

        $logger->info(__PACKAGE__ . ".$sub: executing command $appendCmd to remove duplicate packets if any");
        unless ($self->{conn}->cmd($appendCmd)) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute the command : \'$appendCmd\' ");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }

        $logger->info(__PACKAGE__ . ".$sub: executing \'echo \$?\' to check the status.");
        my @result1 = ($self->{conn}->cmd("echo \$?")) ;
        unless ( $result1[0] == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub:  CMD ERROR: return code : $result1[0] --\n@result1");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $args{-pcap} = $newPcapFile;
    }

    $cmd = (defined $args{-testFile} and $args{-testFile}) ? "cat $args{-testFile}" : "tshark -2 -V -R \'ip || ipv6' -r $args{-pcap}";

    unless (@cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmd'\n @cmdResult");
         $main::failure_msg .= "TOOLS:TSHARK-tshark execution failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my ($pdu_start, $ip_version, %count, %temp_result) = ('','', (), ());
    foreach my $line (@cmdResult) {
        chomp $line;
        $pdu_start =1 if ($line =~ /Linux cooked capture/i);
        $pdu_start =0 if ($line =~ /bytes captured/);
        if ($line =~ /^\s*Protocol:\s+IPv6\s+.*/) {
            $ip_version = 'v6';
            $count{"$ip_version"}++;
        } elsif ($line =~ /^\s*Protocol:\s+(IP|IPv4)\s+.*/) {
            $ip_version = 'v4';
            $count{"$ip_version"}++;
        }
        next unless $ip_version;
        next unless $count{"$ip_version"};
        push (@{$temp_result{$ip_version}{$count{$ip_version}}}, $line);
    }

    my $input = $args{-pattern};
    foreach my $ip_type (keys %{$input}) {
        foreach my $instance (keys %{$input->{$ip_type}} )  {
            unless ($temp_result{"$ip_type"}{$instance}) {
		$logger->info(__PACKAGE__ . ".$sub: COMMAND RESULT: ".Dumper(\%temp_result));
                $logger->error(__PACKAGE__ . ".$sub: there is no $instance occurance for $ip_type");
                $main::failure_msg .= "TOOLS:TSHARK-IPMsg Pattern MisMatch; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            foreach (@{$input->{$ip_type}->{$instance}}) {
                my @temp_pattern = split(/\.\*/, $_);
                map { $_ = "\Q$_\E"} @temp_pattern; # escaping character belongs to property of regex
                my $pat = join(".*", @temp_pattern); # i want to give some value to .* so retaining it
                $pat ||= "\Q$_\E"; # orginale value if ther is now .* present
                if (grep (/$pat/, @{$temp_result{$ip_type}{$instance}})) {
                     $logger->info(__PACKAGE__ . ".$sub: search pattern \'$pat\' found at $instance occurance for $ip_type");
                } else {
                     $logger->error(__PACKAGE__ . ".$sub: search pattern \'$pat\' not found at $instance occurance for $ip_type");
                    $main::failure_msg .= "TOOLS:TSHARK-IPMsg Pattern NotFound; ";
                     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                     return 0;
                }
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 verifyCapturedMsg()

=over

=item DESCRIPTION:

    This subroutine is used for Generic  H225/Any message validation.

=item ARGUMENTS:

   Mandatory:
       -pcap / -testFile => captured pcap or convertd test file (full path)
       -pattern => serach data hash referance having any tree pattern, but the match string will kept in array referance ([]) 
                    give the occurrence as '0' for checking in any occurrence.
                                        ( 'header1' => { '1' => { 'tree1' => ['pattern1','pattern2'.....],
                                                                  'tree2' => { 'tree21' => ['pattern1','pattern2'.....]
                                                                                .
                                                                                .
                                                                                .
                                                                              },
                                                                },
                                                         '2' => ['pattern1','pattern2'.....]], }
                                         'header2' => { '1' => { 'tree1' => ['pattern1','pattern2'.....],
                                                                 'tree2' => { 'tree21' => ['pattern1','pattern2'.....]
                                                                                .
                                                                                .
                                                                                .
                                                                              },
                                                                },
                                                         '2' => ['pattern1','pattern2'.....]], }
                                        )
   Optional
       -startBoundary   => start boundary for packet, default is 'Internet Protocol'
       -endBoundary     => end boundary for packet, default is '^\s*$'
       -msgFilter       => protocol match passed to filter while decoding pcap to text msg, default is h225
       -returnpattern   => if the argument is set, suborutine will return the patterns with values (as a hash)

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item FUNCTIONS USED:

    validator() -> used to match the patter present in array referance and also goes recursive untill we get array referance

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search pattern is not found)

=item EXAMPLE:

      my %input = (-pcap => "/tmp/ingress-openphone.pcap",
               -pattern => {
                              'request: terminalCapabilitySet' => { 2 => { 'capabilityTable:' => ['receiveAudioCapability: g711Ulaw64k', 'receiveUserInputCapability: hookflash', 'receiveUserInputCapability: basicString', 'receiveUserInputCapability: dtmf']}},
                              'h323-message-body: setup' => { 1 =>['ip: 10.34.9.239', 'port: 1720']}
                            }
                 );
      my $result = $Obj->verifyCapturedMsg(%input);

    # if need to check in any occurrence
    my %input_lpl = (-pcap => "$TESTSUITE->{PATH}/logs/$tshark_filename",
               -msgFilter => "arp",
               -startBoundary   => 'Ethernet II | '^Session Initiation Protocol.*|SIP\/2\.0(?!\/)',
               -pattern => {
                              'Address Resolution Protocol (request)'=> { 0 => ['Sender MAC address: fa:16:3e:c5:65:ae', 'Sender IP address: 0.0.0.0', 'Target MAC address: 00:00:00_00:00:00', 'Target IP address: 10.54.224.1' ]}
                            }
                 );

      my $result_lpl1 = $obj2->verifyCapturedMsg(%input_lpl); 

=back

=cut

sub verifyCapturedMsg {
    my ($self, %args) = @_;
    my $sub = "verifyCapturedMsg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }

    if (!defined $args{-pcap} and !defined $args{-testFile}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument pcap/testfile is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless (defined $args{-pattern}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument search pattern data is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my (@cmdResult, $cmd,@status) = ((), '', '');
    my $filter = $args{-msgFilter} || 'h225';
    $cmd = (defined $args{-testFile} and $args{-testFile}) ? "cat $args{-testFile}" : "tshark -2 -V -R \'$filter\' -r $args{-pcap}";

    unless (@cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmd'\n @cmdResult");
        $main::failure_msg .= "TOOLS:TSHARK-tshark Execution Failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $cmd = "echo \$?";
    unless (@status = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed while trying to get the status of the previous command execution \n '@status'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    chomp @status;
    unless( $status[0] == 0 ){ 
        $logger->error(__PACKAGE__ . ".$sub: An error occured while filtering the infile/pcap file. \n Error code : '$status[0]' \n Command Output : '@cmdResult'");
        $main::failure_msg .= "TOOLS:TSHARK-Unable ToFilter PcapFile; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    
    my ($pdu_start,  %count, %content, $returnvalidator, $resultvalidator, %returnhash) = ('', (), (), '', '', ());
    my %input = %{$args{-pattern}};
    my @temp_pat = map{quotemeta $_} keys %input;  #to escape regular expression special characters
    my $pattern = join ('|', @temp_pat);
    my $start_boundary = $args{-startBoundary} || 'Internet Protocol'; #defined boundary or i will take default
    my $end_boundary = $args{-endBoundary} || '^\s*$';
    my $header = '';
    foreach my $line (@cmdResult) {
        chomp $line;
        # finding start and end of msg
        $pdu_start = 1 if ( $line =~ /$start_boundary/i);
        if ( $line =~ /$end_boundary/) {
            $pdu_start = 0;
            $header ='';
        }
        next unless $pdu_start;
        #if we match for required header i will count them, also i store data in array
        #TOOLS-78249, some headers are not in starting for sbc pcap. adding \s* in the starting solved the issue
        #            h323-message-body: callProceeding (1)

        if ($line =~ /^\s*($pattern)/i) {
            $header = $1;
            $count{$header}++;
        }
        next unless $header;
        next unless ($count{$header});
        push (@{$content{$header}{$count{$header}}}, $line);
    }
    my $flag;
    foreach my $msg ( keys %input) {
        $flag = -1;
        foreach my $occurrence ( keys %{$input{$msg}}) {
            $flag = 1;
            # Calling validator subroutine which goes recurrsive based on tree passed
            if($occurrence){
                unless ($content{$msg}{$occurrence}) {
                    $logger->error(__PACKAGE__ . ".$sub: there is no $occurrence occurrence of $msg");
                    $main::failure_msg .= "TOOLS:TSHARK- Pattern NotFound; ";
                    $flag = 0;
                    last;
                }
                ($resultvalidator, $returnvalidator) = SonusQA::ATSHELPER::validator($input{$msg}->{$occurrence}, $content{$msg}{$occurrence},"",1); 
            }
            else{#TOOLS-18561
                $logger->debug(__PACKAGE__ . ".$sub: Checking all the occurrences, since occurrence passed is '$occurrence'");
                ($resultvalidator, $returnvalidator) = SonusQA::ATSHELPER::validator($input{$msg}->{$occurrence}, $content{$msg},"",1);
            }

            unless ( $resultvalidator ) {
                $logger->error(__PACKAGE__ . ".$sub: not all the pattern of $occurrence occurrence of $msg present in captured data");
                $main::failure_msg .= "TOOLS:TSHARK- Pattern Count MisMatch; ";
                $flag = 0;
                last;
            }
	        $returnhash{$msg}{$occurrence} = $returnvalidator;
        }
        
        last unless($flag == 1);
    }


    if($flag == 1){
        $logger->info(__PACKAGE__ . ".$sub: you found all patterns in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        if( defined $args{-returnpattern} and $args{-returnpattern}){
	        return (1,\%returnhash);
        }else{
            return 1;
        }
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub: Input pattern is not in valid format. Check the subroutine description for e.g.\n Input pattern passed: ". Dumper(\%input)) if($flag == -1);
       $main::failure_msg .= "TOOLS:TSHARK- INVALID Input Pattern; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0; 
    }
}

=head2 getTimeDifference()

=over

=item DESCRIPTION:

    This method will get the time difference between two two packets holding required msgs

=item ARGUMENTS:

   Mandatory:
       -pcap / -testFile => captured pcap or convertd test file (full path)
       -msgFilter => msg type you are looking for, default is sctp
	   -startRecord  => start string ( string in packet A incase of when you request for time difference between A and B)
	                    should be pass as array reference, [occurance, string]
	   -endRecord  => start string ( string in packet B incase of when you request for time difference between A and B)
	                    should be pass as array reference, [occurance, string]

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    time difference - Success 

=item EXAMPLE:

    my %input = (-pcap => '/home/linuxadmin/PCR3037/LateMedia_V4_V6.pcap',
                  -msgFilter => 'sip',
                  -startRecord => [1, 'Session Initiation Protocol (INVITE)'],
                  -endRecord => [2, 'Session Initiation Protocol (INVITE)'],
                  );                                                 

    $Obj->getTimeDifference(%input);

=back

=cut

sub getTimeDifference {
    my ($self, %args) = @_;
    my $sub = "getTimeDifference()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ($self->{DEFAULTTIMEOUT}) {
        $self->{DEFAULTTIMEOUT} = 60;
    }

    if (!defined $args{-pcap} and !defined $args{-testFile}) {
        $logger->error(__PACKAGE__ . ".$sub: manditory argument pcap/testfile is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my (@cmdResult, $cmd) = ((), '');
    my $filter = $args{-msgFilter} || 'sctp';
    $cmd = (defined $args{-testFile} and $args{-testFile}) ? "cat $args{-testFile}" : "tshark -2 -V -R \'$filter\' -r $args{-pcap}";

    unless (@cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Failed execute the command '$cmd'\n @cmdResult");
        $main::failure_msg .= "TOOLS:TSHARK- tshark Execution Failed; ";
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my ($frameStart, $time, %count) = ('','',());
    my ($startTime, $endTime) = ('','');
    my ($socr, $startString) =  ($args{-startRecord}->[0], $args{-startRecord}->[1]);
    my ($eocr, $endString) =  ($args{-endRecord}->[0], $args{-endRecord}->[1]);

    foreach my $line (@cmdResult) {
        chomp $line;
        if ($line =~ /Time since reference.*\s(\d+\.\d+)\s+seconds/i) {
            $time = $1;
        }
	unless ($startTime) {
            if ($line =~ $startString) {
                $count{'start'}++ ;
                $startTime = $time if ($socr == $count{'start'}) ;
            }
	}
        if ($line =~ $endString) {
            $count{'end'}++;
            $endTime = $time if ($eocr == $count{'end'});
        }
        last if ($startTime and $endTime);
   }

   if (!$startTime and !$endTime) {
        $logger->error(__PACKAGE__ . ".$sub: unable to get the time stamp details");
        $main::failure_msg .= "TOOLS:TSHARK- Unable ToGet TimeStamp; ";
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub: start time = $startTime, end time = $endTime ");

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving sub [" . ($endTime - $startTime) . "]");
   return ($endTime - $startTime);
}

=head2 verifyPatternInterval()

=over

=item DESCRIPTION:

    This method will check the occurance of a Pattern after every M secs for N No.of times(M, and N vlaues are input to the subroutine ) In TSHARK cmd O/P

=item ARGUMENTS:

   Mandatory:
	-timeInterval => for every timeInterval(seconds) the pattern comes in tshark o/p
	-repetition => For how many repetitions Pattern is expected to come in tshark O/P
	-ipAddress  => IP Address which you want to match along with pattern
	-pattern    => Pattern that you want to look for in tshark O/P
	-logFileName=> TSHARK o/p log file path
	-forceType  => Is the request is forced or nonForced  (nonForced/forced)

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success

=item EXAMPLE:

    my $IPfile= "/home/nanthoti/tsharkCmdOutput.log";
    my $pattern="bindRequest";
    my $Ip= "10.54.92.101";
    my $interval=10;
    my $rep=3;
    my $forceType = "nonForced";

    my $res = $TsharkObj->verifyPatternInterval(-timeInterval => $interval,-repetition => $rep,-forceType => $forceType,-ipAddress => $Ip,-pattern => $pattern,-logFileName => $IPfile);

    OR 

    my $res = $TsharkObj->verifyPatternInterval(-timeInterval =>10 ,-repetition =>5, -forceType => "forced",-ipAddress => "10.54.92.101",-pattern => "bindRequest",-logFileName => "/home/nanthoti/tsharkCmdOutput.log");

=item Author :

    Naresh Kumar Anthoti (nanthoti@sonusnet.com)

=back

=cut

sub verifyPatternInterval{
    my($self,%args)= @_;
    my %a;
    my($time,$nextInterval,$i,$j);
    my $count = 0;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    my $sub = "verifyPatternInterval";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless (open(LOGFH,"<", "$a{-logFileName}")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to open $a{-logFileName}");
        $main::failure_msg .= "TOOLS:TSHARK- Failed ToOpen LogFile; ";
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
        return 0;
    }
    my @tsharkOutput = <LOGFH>;
    close(LOGFH);
    my @patternMatched = grep {$_ =~ /^\s*\d+.*$a{-ipAddress}.*\s+\Q$a{-pattern}\E/} @tsharkOutput;
    $logger->info(__PACKAGE__ .".$sub List of all the pattern matches for $a{-pattern}");
    $logger->info(" @patternMatched");
    $logger->info(__PACKAGE__ .".$sub forcedType is [$a{-forceType}]");
    for($i = 0;$i <= $#patternMatched;$i++)
    {
        if(($patternMatched[$i] =~/^\s*(\d+)\.\d+.*$a{-ipAddress}.*\s+\Q$a{-pattern}\E.*/) && ($count == 0)){
            $time = $1;
        }
        for($j = $i;$j <= $#patternMatched; $j++)
        {
            $nextInterval = $time+$a{-timeInterval};

            if($patternMatched[$j] =~ /^\s*($nextInterval).*/)
            {
                $logger->info(__PACKAGE__ .".$sub Pattern $a{-pattern}  Found as expected in the following Intervals") if($count == 0);
                $logger->info(__PACKAGE__ .".$sub $patternMatched[$i]") if($count == 0);
                $logger->info(__PACKAGE__ .".$sub $patternMatched[$j]") ;
                $time = $1;
                $i = $j;
                $count++;
                last;
            }
        }
    }
    if($a{-forceType} eq "nonForced")
    {
        if($count == $a{-repetition}){
            $logger->info(__PACKAGE__ .".$sub Pattern $a{-pattern} Successfully found $count times");
            return 1;
        }
        else{
            $logger->info(__PACKAGE__ .".$sub Pattern $a{-pattern} found $count times, instead of ".$a{-repetition}." times");
            $main::failure_msg .= "TOOLS:TSHARK- Pattern Count Mismatch; ";
            return 0;
        }
    }
    elsif($a{-forceType} eq "forced")
    {
        if($count == ($a{-repetition}-1)){
            $logger->info(__PACKAGE__ .".$sub Pattern $a{-pattern} Successfully found $count times");
            return 1;
        }
        else{
            $logger->info(__PACKAGE__ .".$sub Pattern $a{-pattern} found $count times instead of ".($a{-repetition}-1)." times");
            $main::failure_msg .= "TOOLS:TSHARK- Pattern Count MisMatch; ";
            return 0;
        }

    } 
}

=head2 closeConn()

    Subroutine to close the connection. 
    pcap files will copy to ATS before closing the connection.    

=cut

sub closeConn {
    my $self = shift;
    my $sub = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    $logger->debug(__PACKAGE__ .".$sub: -->Entered Sub");
    unless (defined $self->{conn}) { 
	$logger->warn(__PACKAGE__ . ".$sub: Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}"); 
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
        return 0; 
    }
    $self->copyCapturedLogToServer(     -userName     => $self->{OBJ_USER},
                                        -passwd       => $self->{OBJ_PASSWORD},
                                        -srcFileName  => $self->{PCAP_FILES},
					-loginPort    => $self->{OBJ_PORT});
    $logger->debug(__PACKAGE__ . ".$sub: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2 getVersion()

=over

=item DESCRIPTION:

    This method will get the version number of the tshark being used on the server

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::TSHARK

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if tshark -v command could not be run)
    $version_number - Tshark version number

=item EXAMPLE:

    my $tshark_version = $self->getVersion();

=back

=cut

sub getVersion {
    my $self = shift;
    my $sub = 'getVersion';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");;
    $logger->debug(__PACKAGE__ .".$sub: -->Entered Sub");
    $logger->debug(__PACKAGE__. ".$sub: Checking the tshark version");
    my $version_number = 0;
    my $cmd;
    unless ($cmd = $self->execCmd('tshark -v')) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to check tshark version");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
        return 0;
    }
    foreach(@{$cmd}){
        if(/TShark\s+\S+\s+(\S+)/i){
            $version_number = $1;
            last;
        }
    }
    $logger->debug(__PACKAGE__. ".$sub: The tshark version is: $version_number");
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[$version_number]");
    return $version_number;
}

=head2 AUTOLOAD

 This subroutine will be called if any undefined subroutine is called.   

=cut

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

=head2 verifyCapturedMsg()

=over

=item DESCRIPTION:

    This subroutine is used to validate value against specific fields.

=item ARGUMENTS:

   Mandatory:
       -pcap    => captured pcap (full path)
       -fields  => specify fields to match
       -protocol => which protocol to match ex: IPV6 or IPV4 or SIP
   Optional
       -filter       => matching filter

=item PACKAGE:

   SonusQA::TSHARK

=item OUTPUT:

   1 - Successfully matched all fields and values
   0 - Match failed for a field

=item EXAMPLES:

   my %args=(-pcap => "test.pcap",
	     -filter => "ip.src==10.54.215.139 or ipv6.src==fd00:10:6b50:4c70::8b and tcp",
	     -fields => { 'Traffic Class' => { 1 => '6'},
                          'Differentiated Services Field' => { 5 => '4'}},
	     -protocol => "IPV6"
            );
   unless($self->verifyCapturedValue(%args)){
       $logger->error(__PACKAGE__ . ".$sub: Failed to match value.");
   }

=back

=cut

sub verifyCapturedValue {
    my ($self, %args) = @_;
    my $sub = 'verifyCapturedValue';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    our %field_list;
    $logger->debug(__PACKAGE__ .".$sub: -->Entered Sub".Dumper \%args);

    $self->{DEFAULTTIMEOUT} = 60 unless($self->{DEFAULTTIMEOUT});
    $args{-protocol} = uc($args{-protocol});

    my $flag = 1;
    foreach my $key (-pcap,-fields,-protocol){
      unless ($args{$key}) {
        $logger->error(__PACKAGE__ . ".$sub: mandatory argument $key is missing");
        $flag = 0;
        last;
      }
    }

    unless($flag){
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$flag]");
      return $flag;
    }

    if(-e "$ENV{HOME}"."/ats_repos/lib/perl/SonusQA/TSHARK/PROTOCOL_$args{-protocol}.pl"){
      unless(my $res = do "$ENV{HOME}"."/ats_repos/lib/perl/SonusQA/TSHARK/PROTOCOL_$args{-protocol}.pl"){
        $logger->error(__PACKAGE__.".$sub: ERROR -> Couldn't parse file PROTOCOL_$args{-protocol}: $@") if $@;
        $logger->error(__PACKAGE__.".$sub: ERROR -> Couldn't 'do' file $args{-protocol}: $!");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
      }
    }
    else{
      $logger->error(__PACKAGE__."$sub: PROTOCOL_$args{-protocol} not supported. Protocol file not found");
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
      return 0;
    }
   
    my (@fields, $cmdResult,$field);
    $logger->debug(__PACKAGE__ .".$sub: Getting Tshark version. ");
    my $ver = $self->getVersion();
    my $cmd = "tshark -2 -V -r $args{-pcap}";
    if($args{-fields}){
      $cmd .= " -T fields";
      @fields = keys %{$args{-fields}};
      foreach my $val (@fields){
        unless($field_list{uc $val}){
          $logger->error(__PACKAGE__ .".$sub: There is no field $val for the specified protocol[$args{-protocol}]");
          $flag = 0;
          last;
        }
        foreach my $range (keys %{$field_list{uc $val}}){
        my($start,$end) = split(' to ',$range);
        if($ver ge $start and $ver le $end){
          $field = $field_list{uc $val}{$range};
          last;
          }
        }
        $cmd .= " -e \"$field\"";
      }
    }
    
    unless($flag){
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$flag]");
      return $flag;
    }
    $cmd .= " -R \"$args{-filter}\"" if(defined $args{-filter});
    unless($cmdResult= $self->execCmd($cmd)){
      $logger->error(__PACKAGE__ . ".$sub: Failed to execute $cmd");
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
      return 0;
    }
    my $index = -1;
    for(my $i=0; $i<2; $i++){
      if($cmdResult->[$i] =~ /Running as user "root" and group "root"\. This could be dangerous\./){
        $index = $i;
        last;
      }
    }
      
    for(my $i=0; $i<scalar @fields; $i++){
      foreach my $key (keys %{$args{-fields}{$fields[$i]}}){
      my $value = $args{-fields}{$fields[$i]}{$key};
      my $result = $cmdResult->[$key+$index];
      my @match = split(' ',$result);
      if($match[$i] eq $value){
          $logger->debug(__PACKAGE__ . ".$sub: Matched Value.  Field - $fields[$i] Expected Value - $value Received Value - $match[$i]");
      }
      else {
        $logger->error(__PACKAGE__ . ".$sub: Failed to match value. Field - $fields[$i] Expected Value - $value Received Value - $match[$i]");
        $flag = 0;
        last;
        }
      }
    }
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$flag]");
    return $flag;
}    
1;
__END__
