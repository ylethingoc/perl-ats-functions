package SonusQA::BSX;

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

2010-09-29

=cut

#########################################################################################################

=pod

NAME

SonusQA::BSX - Perl module for Sonus Networks BSX interaction

SYSOPSIS

 use ATS; # This is the base class for Automated Testing Structure

 my $BsxObj = SonusQA::BSX->new(
                             #REQUIRED PARAMETERS
                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                              -obj_commtype => "SSH",
                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
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
DESCRIPTION


AUTHORS
   See Inline documentation for contributors.

REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename


our $VERSION = "1.0";
use vars qw($self %sessionType);
our @ISA = qw(SonusQA::Base SonusQA::BSX::BSXHELPER);

# INITIALIZATION ROUTINES FOR BSX
# -------------------------------
# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.

#################################################
sub doInitialization {
#################################################
    my( $self, %args ) = @_;
    my $subName = 'doInitialization()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    
    $self->{COMMTYPES}          = ["SSH"];
    $self->{COMM_TYPE}          = "SSH";
    $self->{TYPE}               = __PACKAGE__;
    $self->{conn}               = undef;
    $self->{DEFAULTPROMPT}      = '/\[.*\][\$#].*$/';
    $self->{PROMPT}             = $self->{DEFAULTPROMPT};
    $self->{OBJ_PORT}           = 2024;

    $self->{TL1PROMPT}          = '/WMS-TL1> $/';
    $self->{CONSOLEPROMPT}      = '/\S+.*> $/';
    $self->{REVERSE_STACK}      = 1;
    $self->{VERSION}            = "UNKNOWN";
    $self->{LOCATION}           = locate __PACKAGE__;
    
    my ($name,$path,$suffix)    = fileparse($self->{LOCATION},"\.pm"); 
    $self->{DIRECTORY_LOCATION} = $path;
    $self->{DEFAULTTIMEOUT}     = 10;
    $self->{SESSIONLOG}         = 0;
    $self->{IGNOREXML}          = 1;
  
    foreach ( keys %args ) {
        # Checks for -obj_hostname being set    
        if ( /^-?obj_hostname$/i ) {   
            $self->{OBJ_HOSTNAME} = $args{ $_ };
        } 
        # Checks for -obj_port being set    
        if ( /^-?obj_port$/i ) {   
            $self->{OBJ_PORT} = $args{ $_ };
        }
    }
    
    %sessionType = (
        LOGIN   => 0,
        TL1     => 1,
        CONSOLE => 2,
    );

    $self->{SESSIONTYPE}    = $sessionType{LOGIN};
    $self->{ENTEREDTL1}     = 0;
    $self->{ENTEREDCONSOLE} = 0;
    
    $logger->debug(__PACKAGE__ . ".$subName: Initialization Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
}


#################################################
sub setSystem() {
#################################################
    my( $self ) = @_;
    my $subName = 'setSystem()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    
    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn(__PACKAGE__ . ".$subName: Hostname variable (via -obj_hostname) not set.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Set System Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}  


#########################################################################################################

=head1 execCmd()

DESCRIPTION:

 The function is the generic function to issue a command to the BSX.
 It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the TL1 command

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned.
 It is highly recommended that the user parses the return from execCmd for both the expected string and error strings to better identify any possible cause of failure.

ARGUMENTS:

1. The command to be issued to the TL1
2. Timeout value (Optional)

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 @cmdResults - either the information from the TL1 on successful return of the expected prompt, or an empty array on timeout of the command.

EXAMPLE:

    my $cmd = 'wms_tl1';
    my @result = $BsxObj->execCmd( 
                        '-cmd'     => $cmd,
                        '-timeout' => 20,
                    );

=cut


#################################################
sub execCmd {  
#################################################
  
    my ( $self, %args ) = @_;
    my $subName = 'execCmd()' ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    #$logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    
    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    #$self->_info( '-subName' => $subName, %a );

    if ( $self->{ENTEREDTL1} ) {
        $logger->info(__PACKAGE__ . ".$subName:  ISSUING TL1 CMD: $a{'-cmd'}");    
    }
    else { 
        $logger->info(__PACKAGE__ . ".$subName:  ISSUING CMD: $a{'-cmd'}");
    }
    $self->{LASTCMD}    = $args{'-cmd'}; 
    $self->{CMDRESULTS} = ();
  
    # discard all data in object's input buffer
    $self->{conn}->buffer_empty;

    my $timestamp = $self->getTime();

    my @cmdResults = $self->{conn}->cmd (
                                          '-string'  => $a{'-cmd'},
                                          '-timeout' => $a{'-timeout'},
                                        );

    if ( !$self->{ENTEREDTL1} ) {
        # Check to see if we are actually at the TL1 by mistake
        foreach ( @cmdResults ) {
            if ( $_ =~ /^[\S\s]*(COMPLD|DENY)$/ ) {
                
                $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                $logger->warn(__PACKAGE__ . ".$subName:  TL1 ERROR DETECTED, CMD ISSUED WAS:");
                $logger->warn(__PACKAGE__ . ".$subName:  $a{'-cmd'}");
                $logger->warn(__PACKAGE__ . ".$subName:  CMD RESULTS:");
        
                chomp(@cmdResults);
    
                map { $logger->warn(__PACKAGE__ . ".$subName:\t\t$_") } @cmdResults;
        
                $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            }
        }
    }

    if ( @cmdResults && $cmdResults[$#cmdResults] =~ /command not found$/ ) {
        # command has produced an error. This maybe intended, but the least we can do is warn 
        $logger->warn(__PACKAGE__ . ".$subName:  COMMAND ERROR. CMD: \'$a{'-cmd'}\'.\n ERROR:\n @cmdResults");
    }
 
    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    
    #$logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub");
    return @cmdResults;
}

#########################################################################################################

=head1 execShellCmd()

DESCRIPTION:

 The function is a wrapper around execCmd for the BSX linux shell.
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
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:

 1 - success
 0 - failure 


EXAMPLE:

    my $cmd = 'ls /opt/sonus';

    unless ( $BsxObj->execShellCmd(
                            '-cmd'     => $cmd,
                            '-timeout' => 30,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not execute Shell command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot execute Shell command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  Executed shell command \'$cmd\' - SUCCESS.");

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
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my (@retResults, @cmdShellStatus, $retValue);
 
    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    my $timestamp = $self->getTime();

    my @cmdList = (
        $a{'-cmd'},
        "echo \$?",
    );

    foreach (@cmdList) {

        $a{'-cmd'} = $_;
        $self->_info( '-subName' => $subName, %a );

        my @cmdResults;
        unless ( @cmdResults = $self->execCmd (
                                  '-cmd'  => $a{'-cmd'},
                                  '-timeout' => $a{'-timeout'},
                                ) ) {

            # Entered due to a timeout on receiving the correct prompt.
            # What reasons would lead to this? Reboot?
            # remove empty elements or spaces in the array
            @cmdResults = grep /\S/, @cmdResults;

            if( grep /syntax error: unknown command/is, @cmdResults ) {
                $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                $logger->warn(__PACKAGE__ . ".$subName:  ERROR DETECTED, CMD ISSUED WAS:");
                $logger->warn(__PACKAGE__ . ".$subName:  $a{'-cmd'}");
                $logger->warn(__PACKAGE__ . ".$subName:  CMD RESULTS:");
        
                chomp(@cmdResults);
    
                map { $logger->warn(__PACKAGE__ . ".$subName:\t\t$_") } @cmdResults;
        
                $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            }
            
            chomp(@cmdResults);
        }

        unless (@retResults) {
            @retResults = @cmdResults;
        }

        if (/echo/) {
            @cmdShellStatus = @cmdResults;
        }
    }

    chomp(@retResults);
    chomp(@cmdShellStatus);

    my $errorValue;
    foreach (@cmdShellStatus) {
        if (/^(\d)/) {
            $errorValue = $1;
            if ($1 == 0) {
                # when $? == 0, success;
                $logger->debug(__PACKAGE__ . ".$subName:  CMD SUCCESS: return code \'$1\' --\n@cmdShellStatus");
                $retValue = 1;
            }
            last;
        }
        last;
    }


    unless ($retValue) {
        $logger->error(__PACKAGE__ . ".$subName:  CMD ERROR: return code \'$errorValue\' --\n@retResults");
    }

    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 execTL1Cmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for BSX TL1 specific strings: 'COMPLD' and 'DENY'. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The TL1 output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for 'COMPLD' or 'DENY' from every TL1 command call. 

ARGUMENTS:

1. The command to be issued to the TL1
2. Timeout value (Optional)

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - 'COMPLD' found in output
 0 - 'DENY' found in output or the TL1 command timed out.

 $self->{CMDRESULTS} - TL1 output
 $self->{LASTCMD}    - TL1 command issued

EXAMPLE:

    my $cmd = "RTRV-rpc::\"pc_itu:111\":C1::";

    unless ( $BsxObj->execTL1Cmd ( 
                        '-cmd'     => $cmd,
                        '-timeout' => 30,
                    ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not execute TL1 command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . "$TestId:  Cannot execute TL1 command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . "$TestId:  Executed TL1 command \'$cmd\' - SUCCESS.");
    $logger->debug(__PACKAGE__ . "$TestId:  TL1 command \'$cmd\' result:--\n@{ $BsxObj->{CMDRESULTS}}");

=cut

#################################################
sub execTL1Cmd {
#################################################

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful the cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName       = 'execTL1Cmd()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my @cmdResults;
    my $retValue = 0;
    my $timestamp = $self->getTime();

    # Are we already in a session?
    if ($self->{ENTEREDTL1} == 1) {
        $logger->debug(__PACKAGE__ . ".$subName:  Already in TL1 session.");

        # discard all data in object's input buffer
        $self->{conn}->buffer_empty;

        $self->{CMDRESULTS} = ();

        unless ( $self->{conn}->print( $a{'-cmd'} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Cannot issue \'$a{'-cmd'}\'");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$retValue]");
            return $retValue;
        }

        #$logger->debug(__PACKAGE__ . ".$subName:  Executed \'$a{'-cmd'}\'");

        my ($prematch, $match);
        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                   -match => '/COMPLD/',
                                                   -match => '/DENY/',
                                                 ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after \'$a{'-cmd'}\'.");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
     	    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$retValue]");
            return $retValue;
        }

        push @cmdResults,$prematch;
        push @cmdResults,$match;

        if ( $match =~ m/COMPLD/ ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : COMPLD");
            $retValue = 1;
        }
        elsif ( $match =~ m/DENY/ ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : DENY");
        }

        while( my $line = $self->{conn}->getline ) {
            push @cmdResults,$line;
            next if( $line =~ m/last line/ );
        } 
    }
    else {
        # not in TL1 session
        $logger->error(__PACKAGE__ . ".$subName:  Not in TL1 session, cannot execute TL1 cmd \'$a{'-cmd'}\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################

=head1 enterTL1Session()

DESCRIPTION:

 The function is to establish BSX TL1 session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

1. The TL1 login ID for establising TL1 session
2. The TL1 password for establising TL1 session

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - TL1 session has been made
 0 - Failed to establish TL1 session


EXAMPLE:

    unless ( $BsxObj->enterTL1Session ( 
                                     -login    => $TL1_user,
                                     -password => $TL1_password,
                                ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not enter TL1 session user \'$TL1_user\', password \'$TL1_password\':--\n@{ $BsxObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot Enter TL1 via admin.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  Entered TL1 session via admin, using user \'$TL1_user\', password \'$TL1_password\'.");

=cut

#################################################
sub enterTL1Session {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'enterTL1Session()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Parameters
    foreach ( qw/ login password / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $TL1LoginId  = $args{'-login'};
    my $TL1Password = $args{'-password'};

    # Are we already in a session?
    if ( ( $self->{SESSIONTYPE} == $sessionType{TL1} ) &&
         ( $self->{ENTEREDTL1} == 1 ) ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Already in TL1 session.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    }
    elsif ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        unless ( $self->_enterSession( -session => $sessionType{TL1}, %args ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Unable to enter TL1 session.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }
    else {
        # Neither in login / TL1 session
        $logger->error(__PACKAGE__ . ".$subName:  Cannot enter TL1 session i.e. currently not in default login session");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}

#########################################################################################################


=head1 leaveTL1Session()

DESCRIPTION:

 The function is to leave BSX TL1 session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 None

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - closed TL1 session made
 0 - Failed to leave TL1 session (OR)
     not inside TL1 session


EXAMPLE:

    unless ( $BsxObj->leaveTL1Session() ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not leave TL1 session.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot leave TL1 session.");
        return 0;
    }

=cut

#################################################
sub leaveTL1Session () {
#################################################
    my  ($self ) = @_ ;
    my  $subName = 'leaveTL1Session()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Are we already in a TL1 session?
    unless ($self->{ENTEREDTL1} == 1) {
        # NOT in TL1 session !!!!
        $logger->debug(__PACKAGE__ . ".$subName:  Not in TL1 session.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    my @result = $self->execCmd( '-cmd' => 'exit' );

    # Set prompt to DEFAULT prompt & session type
    $self->{conn}->prompt($self->{DEFAULTPROMPT});
    $self->{SESSIONTYPE} = $sessionType{LOGIN};
    $self->{ENTEREDTL1}  = 0;
    $self->{PROMPT}      = $self->{DEFAULTPROMPT};

    $logger->debug(__PACKAGE__ . ".$subName:  Leaving TL1 session.");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");

    return 1;
}

#########################################################################################################

=head1 enterConsoleSession()

DESCRIPTION:

 The function is to establish BSX console session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

1. The CONSOLE login ID for establising console session
2. The CONSOLE password for establising console session

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - console session has been made
 0 - Failed to establish console session


EXAMPLE:

    unless ( $BsxObj->enterConsoleSession ( 
                                     -login    => $ConsoleUserId,
                                     -password => $ConsolePassword,
                                ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not enter console session user \'$ConsoleUserId\', password \'$ConsolePassword\':--\n@{ $BsxObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot Enter console via admin.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId:  Entered console session via admin, using user \'$ConsoleUserId\', password \'$ConsolePassword\'.");

=cut

#################################################
sub enterConsoleSession {
#################################################
    my  ($self, %args ) = @_ ;
    my  $subName = 'enterConsoleSession()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Parameters
    foreach ( qw/ login password / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $ConsoleLoginId  = $args{'-login'};
    my $ConsolePassword = $args{'-password'};

    # Are we already in a session?
    if ( ( $self->{SESSIONTYPE} == $sessionType{CONSOLE} ) &&
         ( $self->{ENTEREDCONSOLE} == 1 ) ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Already in CONSOLE session.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    }
    elsif ( $self->{SESSIONTYPE} == $sessionType{LOGIN} ) {
        unless ( $self->_enterSession( -session => $sessionType{CONSOLE}, %args ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Unable to enter CONSOLE session.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }
    else {
        # Neither in login / CONSOLE session
        $logger->error(__PACKAGE__ . ".$subName:  Cannot enter CONSOLE session i.e. currently not in default login session");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}

#########################################################################################################


=head1 leaveConsoleSession()

DESCRIPTION:

 The function is to leave BSX console session.
 It will then return 1 or 0 depending on this. In the case of timeout 0 is returned.

ARGUMENTS:

 None

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - closed console session made
 0 - Failed to leave console session (OR)
     not inside console session


EXAMPLE:

    unless ( $BsxObj->leaveConsoleSession() ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not leave console session.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . ".$TestId:  Cannot leave console session.");
        return 0;
    }

=cut

#################################################
sub leaveConsoleSession () {
#################################################
    my  ($self ) = @_ ;
    my  $subName = 'leaveConsoleSession()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Are we already in a CONSOLE session?
    unless ($self->{ENTEREDCONSOLE} == 1) {
        # NOT in CONSOLE session !!!!
        $logger->debug(__PACKAGE__ . ".$subName:  Not in CONSOLE session.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    my @result = $self->execCmd( '-cmd' => 'exit' );

    # Set prompt to DEFAULT prompt & session type
    $self->{conn}->prompt($self->{DEFAULTPROMPT});
    $self->{ENTEREDCONSOLE} = 0;
    $self->{SESSIONTYPE}    = $sessionType{LOGIN};
    $self->{PROMPT}         = $self->{DEFAULTPROMPT};

    $logger->debug(__PACKAGE__ . ".$subName:  Leaving CONSOLE session.");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");

    return 1;
}

#########################################################################################################


=head1 execConsoleCmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for BSX CONSOLE specific strings: 'rows received' and 'DENY'. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The CONSOLE output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for 'COMPLD' or 'DENY' from every CONSOLE command call. 

ARGUMENTS:

1. The command to be issued to the CONSOLE
2. Timeout value (Optional)

PACKAGE:
 SonusQA::BSX

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - 'rows received' found in output
 0 - 'DENY' found in output or the CONSOLE command timed out.

 $self->{CMDRESULTS} - CONSOLE output
 $self->{LASTCMD}    - CONSOLE command issued

EXAMPLE:

    my $cmd = 'showprocs';

    unless ( $BsxObj->execConsoleCmd ( 
                        '-cmd'     => $cmd,
                        '-timeout' => 30,
                    ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not execute CONSOLE command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(__PACKAGE__ . "$TestId:  Cannot execute CONSOLE command \'$cmd\':--\n@{ $BsxObj->{CMDRESULTS}}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . "$TestId:  Executed CONSOLE command \'$cmd\' - SUCCESS.");
    $logger->debug(__PACKAGE__ . "$TestId:  CONSOLE command \'$cmd\' result:--\n@{ $BsxObj->{CMDRESULTS}}");

=cut

#################################################
sub execConsoleCmd {
#################################################

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful the cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName       = 'execConsoleCmd()';
    my $logger        = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Parameters
    unless ( defined $args{'-cmd'} ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
 
    my %a = (
        '-cmd'     => '',
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-subName' => $subName, %a );

    my @cmdResults;
    my $retValue = 0;
    my $timestamp = $self->getTime();

    # Are we already in a session?
    if ($self->{ENTEREDCONSOLE} == 1) {
        $logger->debug(__PACKAGE__ . ".$subName:  Already in CONSOLE session.");

        # discard all data in object's input buffer
        $self->{conn}->buffer_empty;

        $self->{CMDRESULTS} = ();

        unless ( $self->{conn}->print( $a{'-cmd'} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Cannot issue \'$a{'-cmd'}\'");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$retValue]");
            return $retValue;
        }

        $logger->debug(__PACKAGE__ . ".$subName:  Executed \'$a{'-cmd'}\'");

        my ($prematch, $match);
        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                   -match => '/(\-)+\s+\d+\s+rows received\s+(\-)+/',
                                                   -match => '/ERROR/i',
                                                   -match => '/[\s\S\:]+Command not found/',
                                                   -match => '/Entering\s+(\w+)\s+mode/',
                                                   -match => '/SUCCESS/i',
                                                 ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after \'$a{'-cmd'}\'.");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$retValue]");
            return $retValue;
        }

        my $tmp = join ( '', $prematch, $match);
        my @tmp = split ( /\n/, $tmp );
        push @cmdResults, @tmp;

        if ( $match =~ m/(\-)+\s+\d+\s+rows received\s+(\-)+/ ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : rows received");
            $retValue = 1;
        }
        elsif ( $match =~ m/ERROR/i ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : ERROR");
        }
        elsif ( $match =~ m/[\s\S\:]+Command not found/ ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : Command not found");
        }
        elsif ( $match =~ m/Entering\s+(\w+)\s+mode/ ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : Entering $1 mode");
            $retValue = 1;
        }
        elsif ( $match =~ m/SUCCESS/i ) {
            $logger->debug(__PACKAGE__ . ".$subName:  Matched : SUCCESS");
            $retValue = 1;
        }

        while( my $line = $self->{conn}->getline ) {
            push @cmdResults,$line;
            next if( $line =~ m/last line/ );
        } 
    }
    else {
        # not in CONSOLE session
        $logger->error(__PACKAGE__ . ".$subName:  Not in CONSOLE session, cannot execute Console cmd \'$a{'-cmd'}\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
        return $retValue;
    }

    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{'-cmd'}" );
    
    $logger->debug(__PACKAGE__ . ".$subName: cmdResults: \n@cmdResults\n");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue]");
    return $retValue;
}

#########################################################################################################




###################################################
# _enterSession
# subroutine to enter TL1 or Console session
###################################################
sub _enterSession {
    my  ($self, %args ) = @_ ;
    my  $subName = '_enterSession()' ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Parameters
    foreach ( qw/ login password session / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $loginId  = $args{'-login'};
    my $password = $args{'-password'};
    my $timestamp = $self->getTime();

    my $cmd;
    if ( $args{'-session'} == $sessionType{TL1} ) {
        $cmd = 'wms_tl1'; # command to enter TL1 session
    }
    elsif ( $args{'-session'} == $sessionType{CONSOLE} ) {
        $cmd = 'wms_con'; # command to enter console session
    }

    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Cannot issue \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Executed \'$cmd\'");

    my ($prematch, $match);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                   -match => '/[L|l]ogin:/',
                                                   -match => '/Connection down/',
                                                   -match => $self->{TL1PROMPT},
                                                 ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after \'$cmd\'.");
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[L|l]ogin:/ ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Matched Login: prompt");

        # Enter login ID
        $self->{conn}->print( $loginId );

        unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                     -match => '/[P|p]assword:/',
                                                     -match => $self->{TL1PROMPT},
                                                    ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after entering TL1 login-id \'$loginId\'.");
            $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Matched Password: prompt");

        # Enter password
        $self->{conn}->print( $password );

        if ( $args{'-session'} == $sessionType{TL1} ) {

            unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                         -match => '/LOGIN_CTAG COMPLD/',
                                                         -match => $self->{TL1PROMPT},
                                                        ) ) {
                $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after entering TL1 Password \'$password\'.");
        	$logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
                return 0;
            }

            if ( $match =~ m/LOGIN_CTAG COMPLD/i ) {
                $logger->debug(__PACKAGE__ . ".$subName:  Matched TL1: prompt");
                $logger->debug(__PACKAGE__ . ".$subName:  Password accepted for \'TL1 Session\'");

                # Set prompt to TL1 prompt 
                $self->{SESSIONTYPE} = $sessionType{TL1};
                $self->{conn}->prompt($self->{TL1PROMPT});
                $self->{ENTEREDTL1} = 1;
                $self->{PROMPT} = $self->{TL1PROMPT};

                push( @{$self->{HISTORY}}, "$timestamp :: $cmd" );
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
                return 1;
            }
            else {
                $logger->error(__PACKAGE__ . ".$subName:  Matched FAILED for TL1: prompt");
                $logger->error(__PACKAGE__ . ".$subName:  FAIL \$match \'$match\'");
                $logger->error(__PACKAGE__ . ".$subName:  FAIL \$prompt\'$self->{TL1PROMPT}\'\n\n");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
                return 0;
            }
        }
        elsif ( $args{'-session'} == $sessionType{CONSOLE} ) {
            unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                         -match => '/Entering console mode/i',
                                                         -match => $self->{CONSOLEPROMPT},
                                                        ) ) {
                $logger->error(__PACKAGE__ . ".$subName:  Could not match expected prompt after entering CONSOLE Password \'$password\'.");
        	$logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
                return 0;
            }

            if ( $match =~ m/Entering console mode/i ) {
                $logger->debug(__PACKAGE__ . ".$subName:  Matched CONSOLE: prompt");
                $logger->debug(__PACKAGE__ . ".$subName:  Password accepted for \'CONSOLE Session\'");

                # Set prompt to CONSOLE prompt 
                $self->{SESSIONTYPE} = $sessionType{CONSOLE};
                $self->{conn}->prompt($self->{CONSOLEPROMPT});
                $self->{ENTEREDCONSOLE} = 1;
                $self->{PROMPT} = $self->{CONSOLEPROMPT};

                push( @{$self->{HISTORY}}, "$timestamp :: $cmd" );
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
                return 1;
            }
            else {
                $logger->error(__PACKAGE__ . ".$subName:  Matched FAILED for CONSOLE: prompt");
                $logger->error(__PACKAGE__ . ".$subName:  FAIL \$match \'$match\'");
                $logger->error(__PACKAGE__ . ".$subName:  FAIL \$prompt\'$self->{CONSOLE}\'\n\n");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
                return 0;
            }
        }

    }

    # TL1 process is down
    if ( $match =~ m/Connection down/i ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Connection down.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    # Console process is down
    elsif ( $match =~ m/Attempting to reconnect to/i ) {
        $logger->debug(__PACKAGE__ . ".$subName:  Connection down.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0;
    }
}

#########################################################################################################

###################################################
# _info
# subroutine to print all arguments passed to a sub.
# Used for debuging only.
###################################################

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "_info");

    unless ($args{-subName}) {
        $logger->error(__PACKAGE__ . "._info Argument \"-subName\" must be specified and not be blank. $args{-subName}");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$args{-subName} ===================================");
    $logger->debug(__PACKAGE__ . ".$args{-subName} Entering $args{-subName} function");
    $logger->debug(__PACKAGE__ . ".$args{-subName} ===================================");

    foreach ( keys %args ) {
        if (defined $args{$_}) {
            $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => $args{$_}");
        } else {
            $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => undef");
        }
    }

    $logger->debug(__PACKAGE__ . ".$args{-subName} ===================================");

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
