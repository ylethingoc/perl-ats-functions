package SonusQA::BGF;

=head1 NAME

SonusQA::BGF - Perl module for BGF interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $obj = SonusQA::BGF->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]',
                               -OBJ_PORT => '<port>'
                               );

   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus SBX5000-BGF.

=head2 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::ATSHELPER;
use SonusQA::UnixBase;
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw(locate);
use File::Basename;
use XML::Simple;
use Data::GUID;
use Tie::File;
use String::CamelCase qw(camelize decamelize wordsplit);

require SonusQA::BGF::BGFHELPER;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::BGF::BGFHELPER);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------

# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.

######################
sub doInitialization {
######################
    my ( $self, %args ) = @_;
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES}          = ["SSH"];
    $self->{TYPE}               = __PACKAGE__;
    $self->{CLITYPE}            = "bgf";    # Is there a real use for this?
    $self->{conn}               = undef;
    $self->{PROMPT}             = '/.*[#>\$%] $/';
    $self->{DEFAULTPROMPT}      = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{REVERSE_STACK}      = 1;
    $self->{LOCATION}           = locate __PACKAGE__;
  
    my ( $name, $path, $suffix )    = fileparse($self->{LOCATION},"\.pm"); 
  
    $self->{DIRECTORY_LOCATION}     = $path;
    $self->{IGNOREXML}              = 1;
    $self->{SESSIONLOG}             = 0;
    $self->{DEFAULTTIMEOUT}         = 10;

    foreach ( keys %args ) {
        # Checks for -obj_hostname being set    
        #
        if ( /^-?obj_hostname$/i ) {   
            $self->{OBJ_HOSTNAME} = $args{ $_ };
        } 
        # Checks for -obj_port being set    
        #
        if ( /^-?obj_port$/i ) {  
            # Attempting to set ENTEREDCLI
            # based on PORT number
            #
            $self->{OBJ_PORT} = $args{ $_ };

            if ( $self->{OBJ_PORT} == 2024 ) {      # In Linux shell
                $self->{ENTEREDCLI} = 0;
            }
            elsif ( $self->{OBJ_PORT} == 22 ) {     # Explicitly specified default ssh port
                $self->{ENTEREDCLI} = 1;
            }
            else {                                  # Other port. Not the CLI. Maybe an error.
                $self->{ENTEREDCLI} = 0;
            }
            last;                                   # Don't forget to stop the search!
        }
    }
    if ( !$self->{OBJ_PORT} ) {                     # No PORT set, default port is CLI
                $self->{ENTEREDCLI} = 1;
    }    
}

=head2 C< setSystem >

    This function sets the system information. The following variables are set if successful:

                $self->{CE_NAME_LONG}         = long CE name, ie. the domain name of the CE
                $self->{HARDWARE_TYPE}        = hardware_type, the physical box
                $self->{SERIAL_NUMBER}        = serial number
                $self->{PART_NUMBER}          = part number
                $self->{MANUFACTURE_DATE}     = manufacture date
                $self->{PLATFORM_VERSION}     = platform version
                $self->{APPLICATION_VERSION}  = application version
                $self->{MGMT_RED_ROLE}        = platform management redundancy role, ie. active or standby

=cut

#################
sub setSystem() {
#################
    my $version_check_cmd       = "show table system serverStatus";
    my $anti_paginating_cmd     = "set paginate false";

    my ($self) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    my ( $cmd, $prompt, $prevPrompt, @results );

    my $lastline = $self->{conn}->lastline;

#sbalaji - assume everything is fine for now; dont worry!!!
       return 1;

    unless ( $lastline =~ m/connected/i ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".setSystem:  This session does not seem to be connected. Skipping System Information Retrieval");
        return 0;
    }

    unless ( $self->{ENTEREDCLI} ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".setSystem:  Not in CLI (PORT=$self->{OBJ_PORT}), BGF version information not set.");
        return 0;
    }
    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".setSystem:  Hostname variable (via -obj_hostname) not set.");
        return 0;
    }
    my @page_info = $self->{conn}->cmd($anti_paginating_cmd);

    $logger->info(__PACKAGE__ . ".setSystem:  ATTEMPTING TO RETRIEVE BGF SYSTEM INFORMATION FROM CLI");

    my @version_info = $self->{conn}->cmd($version_check_cmd);

    if ( $version_info[$#version_info] =~ /^\[error\]/ ) {
        # CLI command is wrong
        #
        $logger->warn(__PACKAGE__ . ".setSystem:  SYSTEM INFO NOT SET. CLI COMMAND ERROR. CMD: \'$version_check_cmd\'.\n ERROR:\n @version_info");
       # return 0;
    }

    foreach ( @version_info ) {
        # Scan for this system
        #
        #if ( $_ =~ m/^(\S+)\s+(.*)\s+(\w+\-\w+)\s+(\d+)\s+(\d{4}\.\d\d\.\d\d \d\d:\d\d:\d\d)\s+(V\d\d\.\d\d\.\d\d[A-Z]\d{3})\s+(V\d\d\.\d\d\.\d\d[A-Z]\d{3})\s+(\w+)\s+(\d+ Days \d\d:\d\d:\d\d)\s+(\w+)\s*/ ) {
            ########  ^---^   ^--^   ^--------^   ^---^   ^--------------------------------^   ^---------------------------^   ^---------------------------^   ^---^   ^-----------------------^   ^---^
            # Match:    1      2         3          4                     5                                  6                               7                   8                   9              10
            #------
            
            if ( $_ =~ m/\s*(\S+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(.*)\s+(V\d\d\.\d\d\.\d\d[A-Z]\d{3})\s+(V\d\d\.\d\d\.\d\d[A-Z]\d{3})\s+(\w+)\s+(\d+ Days \d\d:\d\d:\d\d)\s+(\d+ Days \d\d:\d\d:\d\d)\s+(\w+)\s*/ ) {
            
            my $ce_name                 = $1; 
            my $hardware_type           = $2;   
            my $serial_number           = $3;
            my $part_number             = $4;   
            my $manufacture_date        = $5; 
            my $platform_version        = $6;
            my $application_version     = $7;
            my $mgmt_redundancy_role    = $8;
            my $up_time                 = $9;
            my $app_up_time             = $10;
            my $restart_reason          = $11;
            #------
            #
            if ( $ce_name =~ m/^$self->{OBJ_HOSTNAME}/i ) {       # assuming all ce names here are like <hostname>.domain.uk for example.

                $self->{CE_NAME_LONG}         = $ce_name;
                $self->{HARDWARE_TYPE}        = $hardware_type;
                $self->{SERIAL_NUMBER}        = $serial_number;
                $self->{PART_NUMBER}          = $part_number;
                $self->{MANUFACTURE_DATE}     = $manufacture_date;
                $self->{PLATFORM_VERSION}     = $platform_version;
                $self->{APPLICATION_VERSION}  = $application_version;
                $self->{MGMT_RED_ROLE}        = $mgmt_redundancy_role;
                $self->{RESTART_REASON}       = $restart_reason;

                $logger->debug (__PACKAGE__ . ".setSystem:  Matched: \'$self->{OBJ_HOSTNAME}\' ($self->{CE_NAME_LONG})");
                $logger->info  (__PACKAGE__ . ".setSystem:  \'$self->{OBJ_HOSTNAME}\': Platform/Application Versions: $self->{PLATFORM_VERSION} / $self->{APPLICATION_VERSION}");
            }
        }
    }
    # Check to see if there was any luck...
    #
    unless ( $self->{CE_NAME_LONG} ) {
        $logger->warn(__PACKAGE__ . ".setSystem:  System information for hostname '$self->{OBJ_HOSTNAME}' not found, Version Info:\n@version_info"); 
        #return 0;
    }
   
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head1 execCmd()

DESCRIPTION:

 The function is the generic function to issue a command to the BGF. It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the CLI command

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned. It is highly recommended that the user parses the return from execCmd for both the expected string and error strings to better identify any possible cause of failure.

ARGUMENTS:

1. The command to be issued to the CLI

PACKAGE:
 SonusQA::BGF

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 @cmdResults - either the information from the CLI on successful return of the expected prompt, or an empty array on timeout of the command.

EXAMPLE:

 my @result = $obj->execCmd( "show table sigtran sctpAssociation" );

=cut


sub execCmd {  
  
    my ($self,$cmd)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
    my(@cmdResults);
    my $timestamp = $self->getTime();
 
    if ( $self->{ENTEREDCLI} ) {
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CLI CMD: $cmd");    
    }
    else { 
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
    }
    $self->{LASTCMD}    = $cmd; 
    $self->{CMDRESULTS} = ();
  
    unless ( @cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=>$self->{DEFAULTTIMEOUT} ) ) {

        # Entered due to a timeout on receiving the correct prompt. What reasons would lead to this?
        # Reboot?
        #
        @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        push(@{$self->{CMDRESULTS}},@cmdResults);
        $logger->debug(__PACKAGE__ . ".execCmd: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd: Session Input Log is: $self->{sessionLog2}");
   
        if ( !$self->{ENTEREDCLI} ) {
            # Check to see if we are actually at the CLI by mistake
            #
            foreach ( @cmdResults ) {

                if ( $_ =~ /^\[ok|error\]/ ) {
                    
                    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
                    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
                    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        
                    chomp(@cmdResults);
        
                    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
            
                    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                    $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
                    exit ;

                }
            }
        }
        elsif( grep /syntax error: unknown command/is, @cmdResults ) {
    
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
            $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
            $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        
            chomp(@cmdResults);
        
            map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
            
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
            exit ;

         } 
        else {
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".execCmd  UNKNOWN CLI ERROR DETECTED, CMD ISSUED WAS:");
            $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
            $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        
            chomp(@cmdResults);
        
            map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
            exit ;

        }
    }; # End unless

    if ( @cmdResults && $cmdResults[$#cmdResults] =~ /^\[[Ee]rror\]/ ) {
        # CLI command has produced an error. This maybe intended, but the least we can do is warn 
     $logger->warn(__PACKAGE__ . ".execCmd  CLI COMMAND ERROR. CMD: \'$cmd\'.\n ERROR:\n @cmdResults");
    }
 
    chomp(@cmdResults);
 
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  
    push( @{$self->{CMDRESULTS}}, @cmdResults );
#    push( @{$self->{HISTORY}}, "$timestamp :: $cmd" );
    
    return @cmdResults;
}

=head1 execCliCmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for BGF CLI specific strings: [ok] and [error]. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The CLI output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for ok and error from every CLI command call. 

ARGUMENTS:

1. The command to be issued to the CLI

PACKAGE:
 SonusQA::BGF

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:
 
 1 - [ok] found in output
 0 - [error] found in output or the CLI command timed out.

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

EXAMPLE:

 my @result = $obj->execCliCmd( "show table sigtran sctpAssociation" );

=cut

sub execCliCmd {

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execCliCmd";
    my ($self,$cmd) = @_;
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".execCliCmd");
    my (@result);
 
    unless ( @result = $self->execCmd( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR. No return information");
        $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
        exit ;
     }

    foreach ( @result ) {
        chomp;
        if ( /^\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR:--\n@result");
            $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
            exit ;
        }
        elsif ( /^\[ok\]/ ) {
            last;
        }
        elsif ( $_ eq $result[ $#{ @result } ] ) {
            # Reached end of result without error or ok
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR: Neither \[error\] or \[ok\] returned from cmd --\n@result");
           $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
            exit;
        }
    }
    return 1;
}

=head1 execShellCmd()

DESCRIPTION:

 The function is a wrapper around execCmd for the BGF linux shell. The function issues a command then issues echo $? to check for a return value. The function will then return 1 or 0 depending on whether the echo command yielded 0 or not. Ie. in the shell 0 is pass (and so the perl function returns 1) any other value is fail (and so the perl function returns 0). In the case of timeout 0 is returned. The command output from the command is then accessible from $self->{CMDRESULTS}. 

ARGUMENTS:

1. The command to be issued to the CLI

PACKAGE:
 SonusQA::BGF

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 None

OUTPUT:

 1 - success
 0 - failure 

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

EXAMPLE:

 my @result = $obj->execShellCmd( "ls /opt/sonus" );

=cut

sub execShellCmd {

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execShellCmd";
    my ($self,$cmd) = @_;
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".execCliCmd");
    my (@result);
 
    @result = $self->execCmd( $cmd ); 

    foreach ( @result ) {
        chomp;
        if ( /error/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
            return 0;
        }
        elsif ( /^\-bash:/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
            return 0;
        }
        elsif ( /: command not found$/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
            return 0;
        }
        elsif ( /No such file or directory/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
            return 0;
        }
    }
    # Save cmd output
    my $command_output = $self->{CMDRESULTS};

    # So far so good then... now check the return code
    unless ( @result = $self->execCmd( "echo \$?" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        return 0;
    }
    unless ( $result[0] == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0] --\n@result");
        return 0;
    }
    # Put the result back in case the user wants them.
    $self->{CMDRESULTS} = $command_output;
    return 1;
}



sub leaveConfigureSession {

    my  ($self, %args ) = @_ ;
    my  $sub_name = "leaveConfigureSession";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Issue exit and wait for either [ok], [error], or [yes,no]
    unless ( $self->{conn}->print( "exit" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'exit\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'exit\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[yes,no\]/',
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'exit\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/\[yes,no\]/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes,no prompt for discarding changes");

        # Enter "yes"
        $self->{conn}->print( "yes" );

        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                               -match => $self->{PROMPT},
                                                             )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'");
            $logger->debug(__PACKAGE__ . ".Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $prematch =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  \'Yes\' resulted in error\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        elsif ( $prematch =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Left private session abandoning modifications");
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

    }
    elsif ( $match =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Left private session.");
            # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
            # next call to execCmd
            $self->{conn}->waitfor( -match => $self->{PROMPT} );;
    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'exit\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
            # next call to execCmd
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


sub leaveDshLinuxShell {

    my  ($self, %args ) = @_ ;
    my  $sub_name = "leaveDshLinuxShell";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $previous_err_mode = $self->{conn}->errmode("return");

    # Issue exit and wait for either [ok], [error]
    unless ($self->{conn}->print( "exit" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'exit\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'exit\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'exit\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Match :$match");
    if ( $match =~ m/linuxadmin/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Dsh is in root");

        # Enter one more exit to get out of linux shell

    	unless ($self->{conn}->print( "exit" ) ) {
        	$logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'exit\'");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        	return 0;
    	} 

        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                               -match => $self->{PROMPT},
                                                             )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \exit\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
 
}


=head2 C< unhideDebug >

DESCRIPTION:

    This subroutine is used to reveal debug commands in the BGF CLI. It basically issues the unhide debug command and deals with the prompts that are presented.

ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The BGF root user password (needed for 'unhide debug')

PACKAGE:

    SonusQA::BGF:BGFHELPER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:
 
    None

OUTPUT:
 
    0   - fail 
    1   - success

EXAMPLE:

    unless ( SonusQA::BGF::BGFHELPER::unhideDebug ( $self, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        return 0;
    }

=cut

sub unhideDebug {

    my $self   = shift;
    my $root_password = shift;

    my $sub_name = "unhideDebug";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Execute unhide debug 
    unless ( $self->{conn}->print( "unhide debug" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'unhide debug\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[ok\]/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => $self->{PROMPT},
                                                                )) {    
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'unhide debug\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched Password: prompt");

        # Give root password
        $self->{conn}->print( $root_password );

        unless ( $self->{conn}->waitfor( 
                                                -match => '/\[ok\]/',   
                                                -match => '/\[error\]/', 
                                              )) {    
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($root_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }   
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'unhide debug\'");
        }

    }
    elsif ( $match =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'unhide debug\' accepted without password.");
    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'unhide debug\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    else {  
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}



=head2 C< enterLinuxShellViaDsh >

DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the BGF CLI commands.

ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh')
    3rd Arg    - The BGF root user password (needed for 'unhide debug')

PACKAGE:

    SonusQA::BGF:BGFHELPER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:
 
    SonusQA::BGF::BGFHELPER::unhideDebug

OUTPUT:
 
    0   - fail 
    1   - success

EXAMPLE:

    unless ( SonusQA::BGF::BGFHELPER::enterLinuxShellViaDsh ( $self, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        return 0;
    }

=cut


sub enterLinuxShellViaDsh {

    my $self     = shift;
    my $user_password   = shift;
    my $root_password   = shift;

    my $sub_name = "enterLinuxShellViaDsh";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub_name: user passwd : \$user_password");
    $logger->debug(__PACKAGE__ . ".$sub_name: root passwd : \$root_password");

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Execute unhide debug 
    unless ( unhideDebug ( $self, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($prematch, $match);

    # Execute dsh 
    unless ( $self->{conn}->print( "dsh" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'dsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'dsh\'");

    unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
                                                                    -match     => '/Do you wish to proceed <y\/N>/i',
                                                                )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'dsh\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/<y\/N>/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched: Do you wish to proceed, entering \'y\'...");
        $self->{conn}->print("y");
        unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                     -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'y\' to Do you wish to proceed prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/\(yes\/no\)/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes/no prompt for RSA key fingerprint");
        $self->{conn}->print("yes");
        unless ( ($prematch, $match) = $self->{conn}->waitfor( 
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'yes\' to RSA key fingerprint prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched password: prompt");
        $self->{conn}->print($user_password);
        unless ( $self->{conn}->waitfor( 
                                                -match => '/Permission denied/',   
                                                -match => $self->{PROMPT}, 
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/Permission denied/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($user_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'dsh\'");
        }

    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  dsh debug command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< enterLinuxShellViaDshBecomeRoot >

DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the BGF CLI commands. Once at the linux shell it will issue the su command to become root.

ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh')
    3rd Arg    - The BGF root user password (needed for 'unhide debug' and 'su -')

PACKAGE:

    SonusQA::BGF:BGFHELPER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:
 
    SonusQA::BGF::BGFHELPER::unhideDebug
    SonusQA::BGF::BGFHELPER::enterLinuxShellViaDsh

OUTPUT:
 
    0   - fail 
    1   - success

EXAMPLE:

    unless ( SonusQA::BGF::BGFHELPER::enterLinuxShellViaDshBecomeRoot ( $self, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell and become root via Dsh.");
        return 0;
    }

=cut

sub enterLinuxShellViaDshBecomeRoot {

    my $self     = shift;
    my $user_password   = shift;
    my $root_password   = shift;

    my $sub_name = "enterLinuxShellViaDshBecomeRoot";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Execute enterLinuxShellViaDsh
    unless ( enterLinuxShellViaDsh ( $self, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot \'enterLinuxShellViaDsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered Linux shell");

    # Become Root using `su -`
    unless ( $self->{conn}->print( "su -" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'su -\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'su -\'");
    
    my ($prematch, $match);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                                    -match     => '/[P|p]assword:/',
                                                                    -errmode   => "return",
                                                                )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected Password prompt after \'su -\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched \'Password:\' prompt");

        $self->{conn}->print( $root_password );

        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                -match => '/incorrect password/',
                                                -match => $self->{PROMPT},
                                                -errmode   => "return",
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/incorrect password/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \(\"$root_password\"\) for su was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'su\'");
        }

    }
    else {  
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< getSystemProcessInfo >

DESCRIPTION:

    This function checks if the BGF system is running on the specified CE server.

ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which the BGF system is running;

PACKAGE:

    SonusQA::BGF:BGFHELPER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:


OUTPUT:
    -1  - function failure; 
    0   - the BGF system is not up;
    1   - the BGF system is up;

EXAMPLE:
        $result=SonusQA::BGF::BGFHELPER::getSystemProcessInfo($shell_session);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . " ======: The BGF system is not up yet.");
            return 0;
        } elsif ( $result == 1) {
            $logger->debug(__PACKAGE__ . " ======: The SGX system is up.");
            return 0;
        } else {
            $logger->debug(__PACKAGE__ . " ======: Failure in checking the BGF system running status.");
            return 0;
        }

=cut

sub getSystemProcessInfo {

    my ( $self, $numberofrun )=@_;
    my $hashref = [];
    my $sub_name = "getSystemProcessInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory input: shell session is empty or blank.");
        return -1;
    }
	$hashref = $self;

    my @return_result;

   @return_result = $self->{conn}->cmd("service bgf status");

    foreach (@return_result){

      	if(m/^(\w+)\s+(\(pid)\s+(\d+)(\))\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : $3 status: $6");
	    $hashref->{systemprocess}->{$1}->{PID} = $3;					
	    $hashref->{systemprocess}->{$1}->{STATE} = $6;
	}elsif(m/^(\w+)\s+(\(pid)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)(\))\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : $3 status: $9");
            $hashref->{systemprocess}->{$1}->{PID} = $3;
            $hashref->{systemprocess}->{$1}->{STATE} = $9;
	}elsif(m/^(\w+)\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : None status: $3");
	    $hashref->{systemprocess}->{$1}->{PID} = "None";					
	    $hashref->{systemprocess}->{$1}->{STATE} = $3;
	}
    	if (defined($numberofrun)) {
		$self->{$numberofrun}= $hashref;
    	}
    }
    return 1;
}





=head2 C< closeConn >
  
  $obj->closeConn();

  Overriding the Base.closeConn due to it thinking us using port 2024 means we're on the console.

=cut

sub closeConn {

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn"); 
    $logger->debug(__PACKAGE__ . ".closeConn Closing BGF connection...");
 
    my ($self) = @_;

    if ($self->{conn}) {
      $self->{conn}->print("exit");
      $self->{conn}->close;
    }
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
