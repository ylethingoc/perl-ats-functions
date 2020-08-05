package SonusQA::NAVTEL;

#########################################################################################################

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

2010-11-23

=cut

#########################################################################################################

=pod

=head1 NAME

SonusQA::NAVTEL - Perl module for Sonus Networks NAVTEL interaction

=head1 SYSOPSIS

 use ATS; # This is the base class for Automated Testing Structure

 my $NavtelObj = SonusQA::NAVTEL->new(
                             #REQUIRED PARAMETERS
                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                              -obj_commtype => 'TELNET',
                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                              %refined_args,
                             );

 OR

 my $NavtelObj = SonusQA::NAVTEL->new(
                             #REQUIRED PARAMETERS
                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                              -obj_commtype => 'TELNET',
                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                              -obj_gui      => 1, # enable GUI for user to see the status for debug purpose ONLY
                              %refined_args,
                             );

PARAMETER DESCRIPTIONS:

OBJ_HOST

      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.

OBJ_USER

      The user name or ID that is used to 'login' to the device.

OBJ_PASSWORD

      The user password that is used to 'login' to the device.

OBJ_COMMTYPE

      The session or connection type that will be established.

OBJ_HOSTNAME

      The host name of Navtel box.

OBJ_GUI

      The VNC server object to be created (if SET to 1) for user to see the status for debug purpose ONLY.

=head1 DESCRIPTION


=head1 AUTHORS

   The <SonusQA::NAVTEL> module is written by Kevin Rodrigues <krodrigues@sonusnet.com>
   and updated by Thangaraj Arumugachamy <tarmugasamy@sonusnet.com>,
   alternatively contact <sonus-auto-core@sonusnet.com>.
   See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

#########################################################################################################
use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;


our $VERSION = '1.1';
use vars qw($self %sessionType @sessionDetails);
our @ISA = qw(SonusQA::Base SonusQA::NAVTEL::NAVTELSTATSHELPER);

#########################################################################################################
# INITIALIZATION ROUTINES FOR NAVTEL
# -------------------------------
# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.

=pod

=head3 SonusQA::NAVTEL::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
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
    
    %sessionType = (
        LOGIN => 0,
        CLI   => 1,
    );

    @sessionDetails = (
        # LOGIN Session - 0
        { prompt => '/\$\s+$/', pattern => qr/\$\s+$/ },

        # CLI Session - 1
        { prompt => '/wish>/', pattern => qr/wish>/ },
    );

    $self->{COMMTYPES}          = ['TELNET'];
    $self->{OBJ_PORT}           = 23; # TELNET
    $self->{COMM_TYPE}          = 'TELNET';
    $self->{TYPE}               = __PACKAGE__;
    $self->{conn}               = undef;
    $self->{OBJ_HOST}           = undef;

    $self->{DEFAULTPROMPT}      = '/[\S\s]+\:.*$/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};
    $self->{LOGIN_PROMPT}       = $sessionDetails[$sessionType{LOGIN}]{prompt},
    $self->{CLI_PROMPT}         = $sessionDetails[$sessionType{CLI}]{prompt},

    $self->{REVERSE_STACK}      = 1;
    $self->{VERSION}            = $VERSION;
    $self->{LOCATION}           = locate __PACKAGE__;
    my ($name,$path,$suffix)    = fileparse($self->{LOCATION},"\.pm"); 
    $self->{DIRECTORY_LOCATION} = $path;

    $self->{DEFAULTTIMEOUT}     = 10;
    $self->{SESSIONLOG}         = 0;
    $self->{IGNOREXML}          = 1;
  
    $self->{GUI_MODE}           = 0;
    $self->{X_DISPLAY}          = undef;

    foreach ( keys %args ) {
        if ( /^-?obj_gui$/i ) {
            $self->{GUI_MODE} = $args{ $_ };
        }

        if ( /^-?obj_host$/i ) {   
            $self->{OBJ_HOST} = $args{ $_ };
        }

        if ( /^-?obj_user$/i ) {   
            $self->{OBJ_USER} = $args{ $_ };
        }

        if ( /^-?obj_password$/i ) {   
            $self->{OBJ_PASSWORD} = $args{ $_ };
        }
        # Checks for -obj_hostname being set    
        if ( /^-?obj_hostname$/i ) {   
            $self->{OBJ_HOSTNAME} = $args{ $_ };
        }
        # Checks for -obj_port being set    
        if ( /^-?obj_port$/i ) {   
            $self->{OBJ_PORT} = $args{ $_ };
        }
        #check if Session log being set.
        if ( /^-?sessionLog$/) {
            $self->{SESSIONLOG} = 1;
        }
    }
    
    $self->{ENTERED_CLI} = 0;
    $self->{SESSIONTYPE} = undef;
    
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
    
    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn(__PACKAGE__ . ".$subName: Hostname variable (via -obj_hostname) not set.");
	$main::failure_msg .= "TOOLS:NAVTEL- Hostname variable(obj_hostname) not set.";
        return 0;
    }

    # Set prompt to - LOGIN
    $self->{PROMPT} = $self->{LOGIN_PROMPT};
    $self->{conn}->prompt($self->{PROMPT});

    # Enter 'cli' after telnet session login i.e. DEFAULT prompt
    $self->{conn}->print('cli');
    my ($prematch, $match) = $self->{conn}->waitfor(
                                    -match => $self->{LOGIN_PROMPT},
                                    -errmode => 'return',
                                );

    # match LOGIN prompt after executing 'cli'
    if ($match =~ $sessionDetails[$sessionType{LOGIN}]{pattern}) {

        $self->{SESSIONTYPE} = $sessionType{LOGIN};
        if ( $self->{GUI_MODE} == 0 ) {
        }
        elsif ( $self->{GUI_MODE} == 1 ) {
            unless ( $self->_createXdisplay() ) {
                $logger->warn("  FAILED - to create VNC server using command 'vncserver'");
            }
            $logger->debug("  SUCCESS - to create VNC server using command 'vncserver'");
        }
    }
    else {
        $logger->warn("  [$self->{OBJ_HOST}] Did not get one of expected patterns after 'cli': " . $self->{conn}->lastline);
    }

    $logger->debug('  Set System Complete');
    $logger->debug(' <-- Leaving Sub [1]');
    return 1;
}  


#########################################################################################################

=head1 execCmd()

DESCRIPTION:

 The function is the generic function to issue a command to the NAVTEL.
 It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the command issued

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned.
 It is highly recommended that the user parses the return from execCmd for both the expected string and error strings to better identify any possible cause of failure.

ARGUMENTS:

 1. The command to be issued
 2. Timeout value (Optional)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 @cmdResults - either the information from the CLI on successful return of the expected prompt, or an empty array on timeout of the command.

EXAMPLE:

    my $cmd = 'vncserver';
    my @cmdResults = $NavtelObj->execCmd( 
                            '-cmd'     => $cmd,
                            '-timeout' => 20,
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
    #$logger->debug(' --> Entered Sub');

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    #$self->_info( '-subName' => $subName, %a );

    if ( $self->{ENTERED_CLI} ) {
        $logger->info("  ISSUING CLI CMD: $a{'-cmd'}");    
    }
    else { 
        $logger->info("  ISSUING CMD: $a{'-cmd'}");
    }
    $self->{LASTCMD}    = $args{'-cmd'}; 
    $self->{CMDRESULTS} = ();
  
    # discard all data in object's input buffer
    $self->{conn}->buffer_empty;

    my $timestamp = $self->getTime();

    my $errMode = sub {
        unless ( $a{'-cmd'} =~ /exit/ ) {
            $logger->error('  Timeout OR Error for command (' . "$a{'-cmd'}" . ')');
            my $errMsg = $self->{conn}->errmsg;
            $logger->debug(" The error message is : \"$errMsg\" ");
            if ( defined($self->{X_DISPLAY}) )  {
                $logger->debug(" ********** NAVTEL - GUI WARNING MESSAGE **********");
                $logger->error("  GUI is enabled - X_DISPLAY($self->{X_DISPLAY}).");
                $logger->warn("  Manual intervention required to respond to GUI pop-up.");
                $logger->warn("  Kill the GUI session using cmd \'vncserver -kill \:$self->{X_DISPLAY}\' from shell login \$ prompt");
                $logger->debug(" **************************************************");
            }
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
            $logger->warn("  COMMAND ERROR. CMD: \'$a{'-cmd'}\'.\n ERROR:\n @cmdResults");
        }elsif($cmdResults[$#cmdResults] =~ /^CONFIRM\:.*\? \[1\=YES\, 0\=NO\]\?/){
	    @cmdResults = $self->{conn}->cmd (
                      '-string'  => 'YES',
                      '-timeout' => $a{'-timeout'},
                      '-errmode' => $errMode,
                    );
	}	
    }
 
    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    
    #$logger->debug(' <-- Leaving Sub');
    return @cmdResults;
}

#########################################################################################################

=head1 execShellCmd()

DESCRIPTION:

 The function is a wrapper around execCmd for the NAVTEL linux shell.
 The function issues a command then issues echo $? to check for a return value.
 The function will then return 1 or 0 depending on whether the echo command yielded 0 or not.
 ie. in the shell 0 is PASS (and so the perl function returns 1)
     any other value is FAIL (and so the perl function returns 0).
     In the case of timeout 0 is returned.
 
 The command output from the command is then accessible from $self->{CMDRESULTS}. 

ARGUMENTS:

 1. The command to be issued
 2. Timeout value (Optional)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:

 1 - success
 0 - failure 

 $self->{CMDRESULTS} - shell output
 $self->{LASTCMD}    - shell command issued

EXAMPLE:

    my $cmd = 'runGroup *';

    unless ( $NavtelObj->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
        my $errMessage = "  FAILED - Could not execute Shell command \'$cmd\':--\n@{ $NavtelObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, $errMessage);
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug("  SUCCESS - Executed shell command \'$cmd\'.");

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
    $logger->debug(' --> Entered Sub');

    my (@retResults, @cmdShellStatus);
    my $retValue = 0;
 
    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
        return $retValue;
    }
 
    unless ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        $logger->error("  ERROR: Not in LOGIN session, to execute shell command \'$args{'-cmd'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Not in LOGIN session to execute shell command.";
        return $retValue;
    }

    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    #$self->_info( '-subName' => $subName, %a );

    my @cmdList = (
        $a{'-cmd'},
        'echo $?',
    );

    foreach (@cmdList) {

        $a{'-cmd'} = $_;

        my @cmdResults;
        unless ( @cmdResults = $self->execCmd (
                                  '-cmd'  => $a{'-cmd'},
                                  '-timeout' => $a{'-timeout'},
                                ) ) {

            # Entered due to a timeout on receiving the correct prompt.
            # What reasons would lead to this? Reboot?
            # remove empty elements or spaces in the array
            @cmdResults = grep /\S/, @cmdResults;

            # if( grep /syntax error: unknown command/is, @cmdResults ) {
            if( grep /:\s+not found$/is, @cmdResults ) {
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                $logger->warn('  ERROR DETECTED, CMD ISSUED WAS:');
                $logger->warn("  $a{'-cmd'}");
                $logger->warn('  CMD RESULTS:');
		$main::failure_msg .= "TOOLS:NAVTEL- Command execution error. Not able to execute the command.";	
                chomp(@cmdResults);
    
                map { $logger->warn("\t\t$_") } @cmdResults;
        
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
                # $logger->debug("  CMD SUCCESS: shell return code \'$1\'");
                $retValue = 1;
            }
            else {
                $logger->error("  ERROR: CMD FAILED - shell return code \'$1\'");
		$main::failure_msg .= "TOOLS:NAVTEL- Command failed with return code \'$1\'";
            }
            last;
        }
        last;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 execCliCmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for NAVTEL CLI specific strings: {1} and {0 <ErrorCode>}. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The CLI output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for 'COMPLD' or 'DENY' from every CLI command call. 

ARGUMENTS:

 1. The command to be issued to the TL1
 2. Timeout value (Optional)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 execCmd()

OUTPUT:
 
 1 - {1} (Success) found in output
 0 - {0 <ErrorCode>} found in output or the CLI command timed out.

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

EXAMPLE:

    my $cmd = 'runGroup *';

    unless ( $NavtelObj->execCliCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
        my $errMessage = "  FAILED - Could not execute CLI command \'$cmd\':--\n@{ $NavtelObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, $errMessage);
        $logger->error("$errMessage");
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
    $logger->debug(' --> Entered Sub');

    my ( @cmdResults, $cliCmdStatus );
    my $retValue = 0;

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error("  ERROR: The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
        return 0;
    }
 
    unless ( $self->{SESSIONTYPE} == $sessionType{CLI} ) {
        $logger->error("  ERROR: Not in CLI session, to execute CLI command \'$args{'-cmd'}\'.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Not in CLI session, to execute the CLI command.";
        return $retValue;
    }

    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    # Are we already in a session?
    if ($self->{ENTERED_CLI} == 1) {
        unless ( @cmdResults = $self->execCmd (
                                  '-cmd'  => $a{'-cmd'},
                                  '-timeout' => $a{'-timeout'},
                                ) ) {

            # Entered due to a timeout on receiving the correct prompt.
            # What reasons would lead to this? Reboot?
            # remove empty elements or spaces in the array
            @cmdResults = grep /\S/, @cmdResults;
        }

        if ( @cmdResults ) {
            $cliCmdStatus = $cmdResults[$#cmdResults];
            $logger->debug(__PACKAGE__ . ".$subName  COMMAND RESULT - last line = \'$cliCmdStatus\'");

            if ( ( $cliCmdStatus =~ /invalid command name\s+/ ) ||
                 ( $cliCmdStatus =~ /ambiguous command name\s+/ ) ||
                 ( $cliCmdStatus =~ /wrong \# args\:\s+/ ) ) {
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
                $logger->warn('  ERROR DETECTED, CMD ISSUED WAS:');
                $logger->warn("  $a{'-cmd'}");
                $logger->warn('  CMD RESULTS:');
		$main::failure_msg .= "TOOLS:NAVTEL- Command execution failed. CMD error detected.";
        
                map { $logger->warn("\t\t$_") } @cmdResults;
        
                $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            }
            elsif ( ( $cliCmdStatus =~ m/^1\s*$/ ) || ( grep /returnCode\s+1/ , @cmdResults ) ) {
                $retValue = 1;
            }
            elsif ( $cliCmdStatus =~ m/^0\s+(\d+)\s*$/ ) {
                my $errMsg = ();
                if ( $1 == 0 ) { $errMsg = 'Generic Error'; }
                elsif ( $1 == 10 ) { $errMsg = 'Wrong # of arguments'; }
                elsif ( $1 == 400 ) {
                    # Loading Profiles Error Code(s)
                    # Group Selection Commands Error Code(s)
                    $errMsg = 'Profile Not Exist';
                }
                # Statistics Commands Error Code(s)
                elsif ( $1 == 420 ) { $errMsg = 'Invalid Option'; }
                elsif ( $1 == 421 ) { $errMsg = 'Invalid Dir'; }
                elsif ( $1 == 422 ) { $errMsg = 'Failed'; }
                # Saving Profiles Error Code(s)
                elsif ( $1 == 411 ) {
                    $errMsg = 'Profile Exist - Profile filename exists and / noOverwrite is specified';
                }
                elsif ( $1 == 430 ) {
                    # Action Commands Error Code(s)
                    # Statistics Commands Error Code(s)
                    # Call Pattern Control Error Code(s)
                    # Call Hold Time Control Error Code(s)
                    $errMsg = 'Group Not Exist';
                }
                elsif ( $1 == 440 ) {
                    # Call Pattern Control Error Code(s)
                    # Call Hold Time Control Error Code(s)
                    $errMsg = 'Group In Calling State - Command not executed';
                }
                # Call Pattern Control Error Code(s)
                elsif ( $1 == 441 ) { $errMsg = 'Group Is Answer Only'; }
                elsif ( $1 == 451 ) { $errMsg = 'Invalid InitCallRate'; }
                elsif ( $1 == 452 ) { $errMsg = 'Invalid FinalCallRate'; }
                elsif ( $1 == 453 ) { $errMsg = 'Invalid StepIncrement'; }
                elsif ( $1 == 454 ) { $errMsg = 'Invalid StepDuration'; }
                # Call Hold Time Control Error Code(s)
                elsif ( $1 == 455 ) { $errMsg = 'Invalid CallHoldTime'; }
                elsif ( $1 == 456 ) { $errMsg = 'Invalid RandomToTime'; }
                else {
                    $errMsg = 'FAILURE';
                }
                $logger->warn("  CLI ERROR : {0 $1} - $errMsg, CMDRESULTS--\n@{$self->{CMDRESULTS}}\n");
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$subName  <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 enterCliSession()

DESCRIPTION:

 The function is to enter NAVTEL CLI session (i.e. 'wish' prompt) from LOGIN session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 None

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - Entered CLI session
 0 - Failed to enter CLI session


EXAMPLE:

    unless ( $NavtelObj->enterCliSession() ) {
        my $errMessage = '  FAILED - Could not enter CLI session.';
        printFailTest (__PACKAGE__, $TestId, $errMessage);
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug('  SUCCESS - Entered CLI session via LOGIN session.');

=cut

#################################################
sub enterCliSession {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'enterCliSession()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    # Are we already in a session?
    if ( ( $self->{SESSIONTYPE} == $sessionType{CLI} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->debug('  Already in CLI session.');
        $logger->debug(' <-- Leaving Sub [1]');
    }
    elsif ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        # Set prompt to CLI prompt 
        $self->{conn}->prompt($self->{CLI_PROMPT});
        $self->{PROMPT} = $self->{CLI_PROMPT};

        unless ( $self->{conn}->print('wish') ) {
            # switching back to LOGIN prompt
            $self->{PROMPT} = $self->{LOGIN_PROMPT};
            $self->{conn}->prompt($self->{LOGIN_PROMPT});
            $logger->error('  ERROR: Unable to enter CLI session.');
            $logger->debug(__PACKAGE__ . ".$subName:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(' <-- Leaving Sub [0]');
            return $retValue;
        }

        my ($prematch, $match) = $self->{conn}->waitfor(
                                    -match => $self->{CLI_PROMPT},
                                    -errmode => 'return',
                                );
           if ( $match =~ $sessionDetails[$sessionType{CLI}]{pattern} ) {
               # Set prompt to CLI prompt 
               $self->{SESSIONTYPE} = $sessionType{CLI};
               $self->{ENTERED_CLI} = 1;
               $retValue = 1;
           }
           else {
               $logger->warn("  [$self->{OBJ_HOST}] Did not get one of expected patterns after 'wish': " . $self->{conn}->lastline);
           }
    }
    else {
        # Neither in login / CLI session
        $logger->error('  ERROR: Cannot enter CLI session i.e. currently not in default login session');
        $logger->debug(' <-- Leaving sub [0]');
        return $retValue;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 leaveCliSession()

DESCRIPTION:

 The function is to leave NAVTEL CLI session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 None

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - closed CLI session made
 0 - Failed to leave CLI session (OR)
     not inside CLI session


EXAMPLE:

    unless ( $NavtelObj->leaveCliSession() ) {
        my $errMessage = '  FAILED - Could not leave CLI session.';
        printFailTest (__PACKAGE__, $TestId, $errMessage);
        $logger->error("$errMessage");
        return 0;
    }
    $logger->debug('  SUCCESS - left CLI session.');

=cut

#################################################
sub leaveCliSession () {
#################################################
    my  ($self ) = @_ ;
    my  $subName = 'leaveCliSession()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');
    my $retValue = 0;

    # Are we already in a CLI session?
    unless ($self->{ENTERED_CLI} == 1) {
        # NOT in CLI session !!!!
        $logger->debug('  Not in CLI session.');
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Not in CLI session";
        return $retValue;
    }

    my @results = $self->execCmd(
                            '-cmd'     => 'exit',
                            '-timeout' => 60,
                        );

    # Set session type to LOGIN
    $self->{conn}->prompt($self->{LOGIN_PROMPT});
    $self->{PROMPT}      = $self->{LOGIN_PROMPT};
    $self->{SESSIONTYPE} = $sessionType{LOGIN};
    $self->{ENTERED_CLI} = 0;
    $retValue = 1;

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 sourceConfigTclFile()

DESCRIPTION:

 The function is to source .tcl file from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The PATH for .tcl file
 2. The FILE for sourcing
 3. The TIMEOUT for sourcing .tcl file (Optional - default 300 seconds i.e. 5 mins)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - .tcl file has been sourced successfuly
 0 - Failed to source .tcl file


EXAMPLE:

    my ($path, $file);
    $path = '/opt/GNiw95000/appl/atak/atak.data/testsuites/atak_sip_flex';
    $file = 'flexRunner.tcl';
    unless ( $NavtelObj->sourceConfigTclFile(
                           '-path'    => $path,
                           '-file'    => $file,
                           '-timeout' => 360, # Seconds
                                              # default is 300 seconds (i.e. 5 mins)
            ) ) {
        $logger->error("  FAILED - to source \'$path\/$file\'.");
        return 0;
    }
    $logger->debug("  SUCCESS - sourced \'$path\/$file\'");

=cut

#################################################
sub sourceConfigTclFile {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'sourceConfigTclFile()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    # Check Mandatory Parameters
    foreach ( qw/ path file / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
            return $retValue;
        }
    }

    my %a = (
        '-path'    => '',
        '-file'    => '',
        '-timeout' => 300, # Default is 300 seconds ( i.e. 5 mins )
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    # Are we already in a CLI session?
    if ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        # enter CLI session i.e. 'wish' prompt
        unless ( $self->enterCliSession() ) {
            $logger->error('  ERROR: Cannot Enter CLI session.');
            $logger->debug(' <-- Leaving sub [0]');
	    $main::failure_msg .= "TOOLS:NAVTEL- Entering to CLI session failed.";
            return $retValue;
        }
        $logger->debug('  Entered CLI session.');
    }
    elsif ( ( $self->{SESSIONTYPE} == $sessionType{CLI} ) &&
            ( $self->{ENTERED_CLI} == 1 ) ) {
        $logger->debug('  Already in CLI session.');
    }
    else {
        # Neither in login / CLI session
        $logger->error('  ERROR: Cannot enter CLI session i.e. currently not in default login session');
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Cannot enter CLI session i.e. currently not in default login session";
        return $retValue;
    }

    my @result = $self->execCmd( 
                        '-cmd'     => "source $a{'-path'}\/$a{'-file'}",
                        '-timeout' => $a{'-timeout'},
                    );

    foreach my $line ( @result ) {
        $logger->debug('line obtained is :: \$line');      
        #      neFlex: Network Device & Endpoint Emulation is now ready to accept command
        if ( $line =~ /Network Device \& Endpoint Emulation is now ready to accept command/ || $line =~ /SIP PS Performance is now ready to accept command/) {
            # TCL file sourced successfuly.
            $logger->debug("  SUCCESS - sourced TCL file \'$a{'-file'}\'");
            $retValue = 1;
            last;
        }
        elsif ( $line =~ /couldn\'t read file\s+\"[\S\s]+\"\:\s+no such file or directory$/ ) {
            $logger->error("  ERROR: couldn\'t read file \"$a{'-path'}\/$a{'-file'}\" no such file or directory");
	    $main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
            last;
        }
    }

    if ( $retValue == 0 ) {
        $logger->error("  ERROR: FAILED - sourcing TCL file \'$a{'-file'}\'");
	$main::failure_msg .= "TOOLS:NAVTEL- Sourcing TCL file Failed.";
    }
	
            # TOOLS-1805  - fix
    if ( defined($self->{X_DISPLAY}) ) {
	$logger->debug("  GUI is enabled - X_DISPLAY($self->{X_DISPLAY}), so executing \'hideGUI\'");
	$self->execCmd(
	    '-cmd' => 'hideGUI',
	    '-timeout' => 90,
	    );	
    }	
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 loadProfile()

DESCRIPTION:

 The function is to load profile file from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The PATH for existing profile
 2. The FILE for existing profile filename
 3. The TIMEOUT for loading profile file (Optional - default 30 seconds)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 None

OUTPUT:
 
 1 - profile file has been loaded successfuly
 0 - Failed to load profile file


EXAMPLE:

    my ($path, $file);
    $path = '/var/iw95000/work/atak.data';
    $file = 'KR-flex-Auto';
    unless ( $NavtelObj->loadProfile(
                           '-path'    => $path,
                           '-file'    => $file,
                           '-timeout' => 60,  # Seconds
                                              # default is 30 seconds
            ) ) {
        $logger->error("  FAILED - to load profile \'$path\/$file\'.");
        return 0;
    }
    $logger->debug("  SUCCESS - profile loaded \'$path\/$file\'");

=cut

#################################################
sub loadProfile {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'loadProfile()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    # Check Mandatory Parameters
    foreach ( qw/ path file / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
            return $retValue;
        }
    }

    my %a = (
        '-path'    => '',
        '-file'    => '',
        '-timeout' => 30, # Default is 30 seconds
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    unless ( $self->execCliCmd( 
                        '-cmd'     => "loadProfile $a{'-path'}\/$a{'-file'}",
                        '-timeout' => $a{'-timeout'},
                    ) ) {
        $logger->error("  ERROR: FAILED - execCliCmd(), cmd \'loadProfile $a{'-path'}\/$a{'-file'}\'.");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Command execution failed.";
        return $retValue;
    }
    else {
        $logger->debug("  SUCCESS - execCliCmd(), cmd \'loadProfile $a{'-path'}\/$a{'-file'}\'.");
        $retValue = 1;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 runGroup()

DESCRIPTION:

 The function is to run the test on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME to run.
     - Enter '*' to run all groups
     - if GROUPNAME specified, it becomes current group
 2. The TIMEOUT for executing NAVTEL API 'runGroup' command (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _actionCommand()

OUTPUT:
 
 1 - runGroup action applied to group successfuly
 0 - Failed to apply runGroup action to group


EXAMPLE:

    my $groupName = '*'; # i.e. apply to all group(s)
    unless ( $NavtelObj->runGroup(
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - to execute runGroup command for group \'$groupName\'.";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - executed runGroup command for group \'$groupName\'");

=cut

#################################################
sub runGroup {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'runGroup()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    $args{'-actionCmd'} = 'runGroup';
    if ( $self->_actionCommand( %args ) ) {
        $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 haltGroup()

DESCRIPTION:

 The function is to halt the test on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME to halt.
     - Enter '*' to halt all groups
     - if GROUPNAME specified, it becomes current group
 2. The TIMEOUT for executing NAVTEL API 'haltGroup' command (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _actionCommand()

OUTPUT:
 
 1 - haltGroup action applied to group successfuly
 0 - Failed to apply haltGroup action to group


EXAMPLE:

    my $groupName = '*'; # i.e. apply to all group(s)
    unless ( $NavtelObj->haltGroup(
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - to execute haltGroup command for group \'$groupName\'.";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - executed haltGroup command for group \'$groupName\'");

=cut

#################################################
sub haltGroup {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'haltGroup()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    $args{'-actionCmd'} = 'haltGroup';
    if ( $self->_actionCommand( %args ) ) {
        $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################


=head1 startCallGeneration()

DESCRIPTION:

 The function is to start call generation on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME to start call generation.
     - Enter '*' to start call generation all groups
     - if GROUPNAME specified, it becomes current group
 2. The TIMEOUT for executing NAVTEL API 'startCallGeneration' command (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _actionCommand()

OUTPUT:
 
 1 - startCallGeneration action applied to group successfuly
 0 - Failed to apply startCallGeneration action to group


EXAMPLE:

    my $groupName = '*'; # i.e. apply to all group(s)
    unless ( $NavtelObj->startCallGeneration(
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - to execute startCallGeneration command for group \'$groupName\'.";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - executed startCallGeneration command for group \'$groupName\'");

=cut

#################################################
sub startCallGeneration {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'startCallGeneration()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    $args{'-actionCmd'} = 'startCallGeneration';
    if ( $self->_actionCommand( %args ) ) {
        $retValue = 1;
    }
    
    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 stopCallGeneration()

DESCRIPTION:

 The function is to stop call generation on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME to stop call generation.
     - Enter '*' to stop call generation all groups
     - if GROUPNAME specified, it becomes current group
 2. The TIMEOUT for executing NAVTEL API 'stopCallGeneration' command (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 _actionCommand()

OUTPUT:
 
 1 - stopCallGeneration action applied to group successfuly
 0 - Failed to apply stopCallGeneration action to group


EXAMPLE:

    my $groupName = '*'; # i.e. apply to all group(s)
    unless ( $NavtelObj->stopCallGeneration(
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - to execute stopCallGeneration command for group \'$groupName\'.";
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - executed stopCallGeneration command for group \'$groupName\'");

=cut

#################################################
sub stopCallGeneration {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'stopCallGeneration()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    $args{'-actionCmd'} = 'stopCallGeneration';
    if ( $self->_actionCommand( %args ) ) {
        $retValue = 1;
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 _actionCommand()

DESCRIPTION:

 The function is to stop call generation on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The ACTIONCMD to execute.
     Following are the action commands to execute on specified or all(*) groups
     - runGroup            => command to 'run' the test
     - haltGroup           => command to 'halt' the test
     - startCallGeneration => command to 'start call generation'
     - stopCallGeneration  => command to 'stop call generation'
 2. The GROUPNAME to execute.
     - Enter '*' to execute all groups
     - if GROUPNAME specified, it becomes current group
 3. The TIMEOUT for executing NAVTEL action command APIs (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

 enterCliSession()
 execCliCmd()

OUTPUT:
 
 1 - Action command applied to group successfuly
 0 - Failed to apply action command to group


EXAMPLE:

    my $actionCmd = 'runGroup' # i.e. command to 'run' the test
    my $groupName = '*';       # i.e. apply to all group(s)
    unless ( $NavtelObj->_actionCommand(
                           '-actionCmd' => $actionCmd,
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        my $errMsg = "  FAILED - to execute action command ($actionCmd) for group \'$groupName\'."
        $logger->error($errMsg);
        printFailTest (__PACKAGE__, $TestId, $errMsg);
        return 0;
    }
    $logger->debug("  SUCCESS - executed action command ($actionCmd) for group \'$groupName\'");

=cut

#################################################
sub _actionCommand {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = '_actionCommand()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(' --> Entered Sub');

    my $retValue = 0;

    my @validActionCommands = qw/ runGroup haltGroup startCallGeneration stopCallGeneration /;

    # Check Mandatory Parameters
    foreach ( qw/ actionCmd groupName / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error("  ERROR: The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(" <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
            return $retValue;
        }
    }

    my %a = (
        '-groupName' => '',
        '-timeout'   => 60, # Default is 60 seconds ( i.e. 1 minute )
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    my $validActionCmdFlag = 0;
    # Check valid action commands
    foreach my $actionCmd ( @validActionCommands ) {
        if ( $a{'-actionCmd'} eq $actionCmd ) {
            $validActionCmdFlag = 1;
        }
    }

    unless ( $validActionCmdFlag ) {
        $logger->error("  ERROR: Invalid action command ($a{'-actionCmd'}) used, Valid:--\n@validActionCommands.");
        $logger->debug(' <-- Leaving Sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Invalid action command used.";
        return $retValue;
    }

    $self->_info( '-subName' => $subName, %a );

    if ( ( $self->{SESSIONTYPE} == $sessionType{CLI} ) &&
         ( $self->{ENTERED_CLI} == 1 ) ) {

        if ( $a{'-actionCmd'} =~ /haltGroup|runGroup/ ) {
            if ( defined($self->{X_DISPLAY}) ) {
                $logger->debug("  GUI is enabled - X_DISPLAY($self->{X_DISPLAY}), so executing \'hideGUI\'");
            }
            # SONUS00117371 - fix
            $self->execCmd(
                '-cmd' => 'hideGUI',
                '-timeout' => 90,
            );
        }

        unless ( $self->execCliCmd(
                                '-cmd'     => "$a{'-actionCmd'} " . $a{'-groupName'},
                                '-timeout' => $a{'-timeout'},
                            ) ) {
            $logger->error("  ERROR: FAILED - $a{'-actionCmd'} action to group \'$a{'-groupName'}\'.");
	    $main::failure_msg .= "TOOLS:NAVTEL- Action to the group with actionCmd failed.";
        }
        else {
            $logger->debug("  SUCCESS - $a{'-actionCmd'} action applied to group \'$a{'-groupName'}\'.");
            $retValue = 1;
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

sub _createXdisplay () {
    my ( $self ) = @_;
    my $subName = '_createXdisplay()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL

    unless ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        # we already in a CLI session?
        $logger->error("  ERROR: FAILED - to create VNC server, as we are not in LOGIN session (Prompt - \'$sessionDetails[$sessionType{LOGIN}]{prompt}\' - Expected).");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Failed to create VNC server, as we are not in LOGIN session.";
        return $retValue;
    }

    if ( defined ($self->{X_DISPLAY}) ) {
        $logger->error("  ERROR: FAILED - VNC server \'$self->{X_DISPLAY}\', already created and is in use.");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Failed to create VNC server, as it is already created and is in use.";
        return $retValue;
    }

    if ( ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) &&
         ( $self->{ENTERED_CLI} == 0 ) ) {
        
        my $cmd = 'vncserver';
        unless ( $self->execShellCmd( 
                            '-cmd'     => $cmd,
                            '-timeout' => 60,
                        ) ) {
            $logger->error("  ERROR: FAILED - creating VNC server using command \'$cmd\'");
            $logger->debug(' <-- Leaving sub [0]');
	    $main::failure_msg .= "TOOLS:NAVTEL- Failed in creating VNC server using command passed.";
            return $retValue;
        }

        foreach my $line ( @{$self->{CMDRESULTS}} ) {

            # if ($line =~ /^New \'X\' desktop is\s+$self->{OBJ_HOSTNAME}\:(\d+)$/) {
            if ($line =~ /^New [\S\s]+ desktop is\s+$self->{OBJ_HOSTNAME}\:(\d+)$/) {
                # New 'X' desktop is iw95000:2
                $self->{X_DISPLAY} = $1;
                $self->{GUI_MODE}  = 1;
                $logger->info("  SUCCESS - created VNC x-display:$self->{X_DISPLAY}");

                # export DISPLAY
                if ( $self->execShellCmd( '-cmd' => "export DISPLAY=127.0.0.1\:$self->{X_DISPLAY}", ) ) {
                    $logger->debug("  SUCCESS - export VNC x-display:$self->{X_DISPLAY}");
                    $retValue = 1;
                }
                last;
            }
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

sub _deleteXdisplay () {
    my ( $self ) = @_;
    my $subName = '_deleteXdisplay()' ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    my $retValue = 0; # FAIL

    unless ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        # we already in a CLI session?
        $logger->error("  ERROR: FAILED - to create VNC server, as we are not in LOGIN session (Prompt - \'$sessionDetails[$sessionType{LOGIN}]{prompt}\' - Expected).");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Failed to create VNC server, as we are not in LOGIN session prompt.";
        return $retValue;
    }

    unless ( defined ($self->{X_DISPLAY}) ) {
        $logger->error('  ERROR: FAILED - VNC server not created and not in use.');
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Failed to create VNC server.";
        return $retValue;
    }

    if ( ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) &&
         ( $self->{ENTERED_CLI} == 0 ) ) {
        my $cmd = "vncserver -kill \:$self->{X_DISPLAY}";
        unless ( $self->execShellCmd( 
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
            $logger->error("  ERROR: FAILED - deleting VNC server using command \'$cmd\'");
            $logger->debug(' <-- Leaving sub [0]');
	    $main::failure_msg .= "TOOLS:NAVTEL- Failed to delete VNC server using the command passed.";
            return $retValue;
        }

        foreach my $line ( @{$self->{CMDRESULTS}} ) {
            if ($line =~ /^Killing Xvnc process ID\s+(\d+)$/) {
                # Killing Xvnc process ID 15451
                $logger->info("  Deleted VNC x-display:$self->{X_DISPLAY}, process ID $1");
                $self->{X_DISPLAY} = undef;
                $self->{GUI_MODE}  = 0; # to avoid recursive deletion of VNC server.
                $retValue = 1;
                last;
            }
        }
    }

    $logger->debug(" <-- Leaving Sub [$retValue]");
    return $retValue;
}


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
	$main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
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

#########################################################################################################

# Override the DESTROY method inherited from Base.pm in order to remove any config if we bail out.
sub DESTROY {
    my ($self,@args)=@_;
    my $subName: = 'DESTROY()';
    my $logger;

    unless ( Log::Log4perl->initialized() ) {
        # No, not initialized yet ...
        Log::Log4perl->easy_init($DEBUG);
    }
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(' --> Entered Sub');

    if ( $self->{SESSIONTYPE} == $sessionType{CLI} ) {
        if ( defined($self->{X_DISPLAY}) ) {
            $logger->debug("  GUI is enabled - X_DISPLAY($self->{X_DISPLAY}), so executing \'hideGUI\'");
            $self->execCmd(
                '-cmd' => 'hideGUI',
                '-timeout' => 90,
            );
        }
        $logger->debug("  Closing CLI session i.e. exec 'exit'");
        unless ( $self->leaveCliSession() ) {
            $logger->warn('  FAILED - closing CLI session');
        }
        else {
            $logger->debug('  SUCCESS - closing CLI session');
        }
    }

    if ( $self->{GUI_MODE} == 1 ) {
        if ( defined ($self->{X_DISPLAY}) ) {
            unless ( $self->_deleteXdisplay() ) {
                $logger->warn('  FAILED - killed VNC x-display');
            }
            else {
                $logger->debug('  SUCCESS - killed VNC x-display');
            }
        }
    }

    # Fall thru to regulare Base::DESTROY method.
    SonusQA::Base::DESTROY($self);
    $logger->debug(' <-- Leaving Sub');
}
#########################################################################################################

=head1 clearActiveFlows()

DESCRIPTION:

 The function is to clear active call flows on all groups or a specified group,
 from  NAVTEL CLI session (i.e. wish prompt).
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 1. The GROUPNAME to clear active flows.
     - Enter '*' to clear active flows on all groups
     - if GROUPNAME specified, it becomes current group
 2. The TIMEOUT for executing NAVTEL API 'clearActiveFlows' command (Optional - default 60 seconds i.e. 1 minute)

PACKAGE:

 SonusQA::NAVTEL

GLOBAL VARIABLES USED:

 None

EXTERNAL FUNCTIONS USED:

execCliCmd()

OUTPUT:

 1 - clearActiveFlows action applied to group successfuly
 0 - Failed to apply clearActiveFlows action to group


EXAMPLE:

    my $groupName = '*'; # i.e. apply to all group(s)
    unless ( $NavtelObj->clearActiveFlows(
                           '-groupName' => $groupName,
                           '-timeout'   => 120, # Seconds
                                                # default is 60 seconds (i.e. 1 minute)
            ) ) {
        $logger->error("  FAILED - to execute clearActiveFlows command for group \'$groupName\'.");
        return 0;
    }
    $logger->debug("  SUCCESS - executed clearActiveFlows command for group \'$groupName\'");

=cut

#################################################
sub clearActiveFlows {
    my  ($self, %args ) = @_ ;
    my  $subName = 'clearActiveFlows()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug("$subName: --> Entered Sub");

    unless ( defined $args{'-groupName'} ){
        $logger->error("$subName: Mandatory argument \'group name\' is missing or blank");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Mandatory arguement has not been specified or is blank.";
        return 0;
    }	 
    my $timeout = $args{'-timeout'}||60; # Default is 60 seconds ( i.e. 1 minute )

    unless ( $self->execCliCmd(
                        '-cmd'     => "clearActiveFlows -group $args{'-groupName'}",
                        '-timeout' => $timeout,
                    ) ) {
        $logger->error("$subName: FAILED to execute cmd \'clearActiveFlows -group $args{'-groupName'}\'.");
        $logger->debug(' <-- Leaving sub [0]');
	$main::failure_msg .= "TOOLS:NAVTEL- Failed to execute command passed with the groupname.";
        return 0;
    }
    $logger->debug("$subName: successfully executed cmd \'clearActiveFlows -group $args{'-groupName'}\' .");
    $logger->debug(" $subName: <-- Leaving Sub [1]");
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
