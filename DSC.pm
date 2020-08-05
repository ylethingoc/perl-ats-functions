package SonusQA::DSC;

=head1 NAME

 SonusQA::DSC - Perl module for DSC interaction

=head1 SYNOPSIS

 use ATS;	#This is base class for Automated Testing Structure

 my $obj = SonusQA::DSC->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<root user name>',
                               -OBJ_PASSWORD => '<root user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]',
                               );

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

 This module provides an interface for DSC

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw(locate);
use File::Basename;
use XML::Simple;
use Data::GUID;
use List::Util qw(first);
use List::Util 1.33 qw(any);
use Tie::File;
use String::CamelCase qw(camelize decamelize wordsplit);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::DSC::DSCHELPER);

=head1 B<doInitialization()>

=over 6

=item DESCRIPTION:

 This subroutine is used to set object defaults and session prompt.

=item PACKAGE:

 SonusQA::DSC

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=back

=cut

sub doInitialization {

    my ( $self, %args ) = @_;
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".doInitialization" );
    my $sub    = "doInitialization";
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );

    $self->{COMMTYPES}     = ["SSH"];
    $self->{TYPE}          = __PACKAGE__;
    $self->{conn}          = undef;
    $self->{PROMPT}        = '/.*[#>\$%] $/';
    $self->{TL1_PROMPT}    = '/PTI_TL1[#>%] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};      #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{LOCATION}      = locate __PACKAGE__;

    my ( $name, $path, $suffix ) = fileparse( $self->{LOCATION}, "\.pm" );

    $self->{DIRECTORY_LOCATION} = $path;
    $self->{IGNOREXML}          = 1;
    $self->{SESSIONLOG}         = 0;
    $self->{DEFAULTTIMEOUT}     = 60;
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );

}

=head1 B<setSystem()>

=over 6

=item DESCRIPTION:

 This function sets the system information. It disables autologout on the system and gets the version info.

=item PACKAGE:

 SonusQA::DSC

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=back

=cut

sub setSystem() {

    my $sub = "setSystem";
    my ( $self, %args ) = @_;

    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );
    my ( $cmd, $prompt, $prevPrompt, @results );

    my $lastline = $self->{conn}->lastline;

    if ( ( scalar( @{ $self->{BANNER} } ) < 1 ) and $lastline !~ m/(connected|Last login)/i ) {

        # WARN until further notice
        #
        $logger->warn( __PACKAGE__ . ".$sub:  This session does not seem to be connected. Skipping System Information Retrieval" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
        return 0;
    }

    unless ( $self->{OBJ_HOSTNAME} ) {

        # WARN until further notice
        #
        $logger->warn( __PACKAGE__ . ".$sub:  Hostname variable (via -obj_hostname) not set." );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
        return 0;
    }

    # checking user wished to make connection using ipv4/ipv6 and MGMTNIF->1/MGMTNIF->2
    my $version_check_cmd = 'dsc -v';
    my $mgmt_nif          = ( defined $self->{MGMTNIF} and $self->{MGMTNIF} ) ? $self->{MGMTNIF} : 1;
    my $ip_type           = ( $self->{CONNECTED_IPTYPE} eq 'IPV6' ) ? 'IPV6' : 'IP';
    my @version_info;
    @version_info = $self->{conn}->cmd($version_check_cmd);
    $self->{conn}->cmd("systemctl stop idled.service");
    $self->{conn}->cmd("stty cols 200");

    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return 1;
}

=head1 execCmd()

=over 6

=item DESCRIPTION:

 The function is the generic function to issue a command to the DSC. It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the CLI command

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned. It is highly recommended that the user parses the return from 
 execCmd for both the expected string and error strings to better identify any possible cause of failure.

=item ARGUMENTS:

 1. The command to be issued to the CLI
 2. Timeout.

=item PACKAGE:

 SonusQA::DSC

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:
 
 @cmdResults - either the information from the CLI on successful return of the expected prompt, or an empty array on timeout of the command.

=item EXAMPLE:

 my @result = $obj->execCmd( "cd /var/log/cpu_ss7gw" , 10 );

=back

=cut

sub execCmd {

    my ( $self, $cmd, $timeOut ) = @_;
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".execCmd" );
    my (@cmdResults);
    my $sub = "execCmd";
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );
    my $timestamp = $self->getTime();
    $timeOut ||= $self->{DEFAULTTIMEOUT};

    if ( $self->{ENTEREDCLI} ) {
        $logger->info( __PACKAGE__ . ".$sub  ISSUING CLI CMD: $cmd" );
    }
    else {
        $logger->info( __PACKAGE__ . ".$sub  ISSUING CMD: $cmd" );
    }
    $self->{LASTCMD}    = $cmd;
    $self->{CMDRESULTS} = ();
    unless ( defined $timeOut ) {
        $timeOut = $self->{DEFAULTTIMEOUT};
    }

    #    my $abortFlag =0;

    #   my @avoid_us = ('Request Timeout','Stopping user sessions during sync phase\!','Disabling updates \-\- read only access','Enabling updates \-\- read\/write access');
    my $try = 0;
  EXECUTE:
    $logger->debug( __PACKAGE__ . ".$sub Clearing the buffer" );

    $self->{conn}->buffer_empty;    #clearing the buffer before the execution of CLI command

    unless ( @cmdResults = $self->{conn}->cmd( String => $cmd, Timeout => $timeOut ) ) {

        # Entered due to a timeout on receiving the correct prompt. What reasons would lead to this?
        # Reboot?
        $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
        $logger->warn( __PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*" );
        $logger->warn( __PACKAGE__ . ".$sub  UNKNOWN CLI ERROR DETECTED, CMD ISSUED WAS:" );
        $logger->warn( __PACKAGE__ . ".$sub  $cmd" );
        $logger->warn( __PACKAGE__ . ".$sub  errmsg: " . $self->{conn}->errmsg );
        $logger->warn( __PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*" );
############Send CTRL-C when error occurs. Presently not checking core since we are not sure if it is required for DSC as af now
        if ( defined $self->{ENTEREDCLI} and $self->{ENTEREDCLI} ) {
            $logger->debug( __PACKAGE__ . ".$sub  Sending ctrl+]" );
            my $prevPrompt = $self->{conn}->prompt("telnet>");
            $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
            $self->{conn}->cmd( -string => "\c]" );
            $prevPrompt = $self->{conn}->prompt( $self->{PROMPT} );
            $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
            $self->{conn}->cmd( -string => "quit" );
            $prevPrompt = $self->{conn}->prompt("$self->{TL1_PROMPT}");
            $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
            my @telnetcmd_out = $self->{conn}->cmd('telnet 0 6669');

            unless ( any { /Connected to 0/ } @telnetcmd_out ) {
                $logger->error( __PACKAGE__ . ".$sub: Failed to enter tl1 session" );
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                &error( __PACKAGE__ . ".$sub CMD ERROR - EXITING" );
            }
            $logger->debug( __PACKAGE__ . ".$sub: tl1 session is created successfully" );
        }
        else {
            $logger->debug( __PACKAGE__ . ".$sub  Sending ctrl+c" );
            unless ( $self->{conn}->cmd( -string => "\cC" ) ) {
                $logger->warn( __PACKAGE__ . ".$sub  Didn't get the prompt back after ctrl+c: errmsg: " . $self->{conn}->errmsg );

                #Reconnect in case ctrl+c fails.
                $logger->warn( __PACKAGE__ . ".$sub  Trying to reconnect..." );
                unless ( $self->reconnect() ) {
                    $logger->warn( __PACKAGE__ . ".$sub Failed to reconnect." );
                    &error( __PACKAGE__ . ".$sub CMD ERROR - EXITING" );
                }
            }
            else {
                $logger->info( __PACKAGE__ . ".exexCmd Sent ctrl+c successfully." );
            }
            if ( !$try && $self->{RETRYCMDFLAG} ) {
                $try = 1;
                goto EXECUTE;
            }
        }
    }
    ;    # End unless

    chomp(@cmdResults);

    @cmdResults = grep /\S/, @cmdResults;    # remove empty elements or spaces in the array

    push( @{ $self->{CMDRESULTS} }, @cmdResults );
    push( @{ $self->{HISTORY} },    "$timestamp :: $cmd" );
    map { $logger->debug( __PACKAGE__ . ".$sub\t\t$_" ) } @cmdResults;
    foreach (@cmdResults) {
        if (m/(Permission|Error)/i) {
            if ( $self->{CMDERRORFLAG} ) {
                $logger->warn( __PACKAGE__ . ".$sub  CMDERROR FLAG IS POSITIVE - CALLING ERROR" );
                &error("CMD FAILURE: $cmd");
            }
            last;
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return @cmdResults;
}

=head1 B<execCliCmds()>

=over 6

=item DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for DSC CLI specific strings: [ok] and [error]. It will then return 1 or 0 depending on this. In 
 the case of timeout 0 is returned. The CLI output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for ok 
 and error from every CLI command call. 

=item ARGUMENTS:

 1. The command to be issued to the CLI
 2. Timeout.
 3. string should be matched on command output, Ex -> "Aborted: too many 'system ntp serverAdmin'"

=item PACKAGE:

 SonusQA::DSC

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:
 
 1 - [ok] found in output
 0 - [error] found in output or the CLI command timed out.

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

=item EXAMPLE:

 my $result = $obj->execCliCmds( \@commands , 10 );

=back

=cut

sub execCliCmds {

    # Due to the frequency of running this command there will only be log output
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub = "execCliCmd";
    my ( $self, $cmdList, $timeOut ) = @_;
    $timeOut ||= $self->{DEFAULTTIMEOUT};
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".execCliCmd" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );
    my ( @result, $cmd, $error_flag );

    $logger->info( __PACKAGE__ . ".$sub:  Entering into TL1 session" );
    my $prevPrompt = $self->{conn}->prompt("$self->{TL1_PROMPT}");
    $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
    my @telnetcmd_out = $self->{conn}->cmd('telnet 0 6669');
    unless ( any { /Connected to 0/ } @telnetcmd_out ) {
        $logger->error( __PACKAGE__ . ".$sub: Failed to enter tl1 session" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        $prevPrompt = $self->{conn}->prompt("$self->{PROMPT}");
        $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
        return 0;
    }
    $logger->info( __PACKAGE__ . ".$sub:  Successfully entered into TL1 session" );
    $self->{ENTEREDCLI} = 1;
    $error_flag = 0;

    unshift @$cmdList, "ACT-USER::root:1::$self->{OBJ_PASSWORD};";
    foreach $cmd (@$cmdList) {

        unless ( @result = $self->execCmd( $cmd, $timeOut ) ) {
            $logger->error( __PACKAGE__ . ".$sub:  CLI CMD ERROR. No return information" );
            $logger->warn( __PACKAGE__ . ".$sub:  **ABORT DUE TO CLI FAILURE **" );
            $error_flag = 1;
            last;
        }

        foreach (@result) {
            chomp;
            if (/error/i) {
                $logger->error( __PACKAGE__ . ".$sub:  CLI CMD ERROR" );
                $logger->warn( __PACKAGE__ . ".$sub:  **ABORT DUE TO CLI FAILURE **" );
                if ( defined $ENV{CMDERRORFLAG} && $ENV{CMDERRORFLAG} ) {
                    $logger->warn( __PACKAGE__ . ". $sub: CMDERRORFLAG flag set -CALLING ERROR " );
                    &error("CMD FAILURE: $cmd");
                }
                $error_flag = 1;
                goto EXITCLI;    #Do not execute further TL1 commands
            }
            elsif (/COMPLD/) {
                $logger->info( __PACKAGE__ . ".$sub:  Successfully completed TL1 command $cmd" );
                last;
            }

            elsif (/Successful event/) {
                $logger->info( __PACKAGE__ . ".$sub:  Successfully completed TL1 command $cmd" );
                last;
            }
            elsif (/User Not Logged In/) {
                $logger->error( __PACKAGE__ . ".$sub:  User not logged in." );
                $logger->warn( __PACKAGE__ . ".$sub:  **ABORT DUE TO CLI FAILURE **" );
                if ( defined $ENV{CMDERRORFLAG} && $ENV{CMDERRORFLAG} ) {
                    $logger->warn( __PACKAGE__ . ". $sub: CMDERRORFLAG flag set -CALLING ERROR " );
                    &error("CMD FAILURE: $cmd");
                }
                $error_flag = 1;
                goto EXITCLI;    #Do not execute further TL1 commands
            }
            elsif ( $_ eq $result[$#result] ) {

                # Reached end of result without error or ok
                $logger->error( __PACKAGE__ . ".$sub:  CLI CMD ERROR: Neither \[error\] nor \[ok\] returned from cmd --\n@result" );
                $logger->warn( __PACKAGE__ . ".$sub:  **ABORT DUE TO CLI FAILURE **" );
                if ( defined $ENV{CMDERRORFLAG} && $ENV{CMDERRORFLAG} ) {
                    $logger->warn( __PACKAGE__ . ". $sub: CMDERRORFLAG flag set -CALLING ERROR " );
                    &error("CMD FAILURE: $cmd");
                }
                $error_flag = 1;
                goto EXITCLI;    #Do not execute further TL1 commands
            }
        }
    }
    $logger->info( __PACKAGE__ . ".$sub:  Successfully executed all TL1 commands. Now quiting from TL1 session" ) if ( $error_flag eq '0' );
  EXITCLI:
    $cmd        = 'quit;';
    $prevPrompt = $self->{conn}->prompt("$self->{PROMPT}");
    $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
    @result = $self->execCmd( $cmd, $timeOut );
    unless ( any { /Connection closed by foreign host./ } @result ) {
        $logger->error( __PACKAGE__ . ".$sub:  CLI CMD ERROR. No return information. Probably still in CLI session." );
        $logger->warn( __PACKAGE__ . ".$sub:  **ABORT DUE TO CLI FAILURE **" );
        $prevPrompt = $self->{conn}->prompt("$self->{TL1_PROMPT}");
        $logger->info( __PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt" );
        return 0;
    }
    $self->{ENTEREDCLI} = 0;
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return 0 if ($error_flag);
    return 1;
}

=head1 B<execShellCmd()>

=over 6

=item DESCRIPTION:

 The function is a wrapper around execCmd for the DSC linux shell. The function issues a command then issues echo $? to check for a return value. The function will then return 
 1 or 0 depending on whether the echo command yielded 0 or not. ie. in the shell 0 is pass (and so the perl function returns 1) any other value is fail (and so the perl function 
 returns 0). In the case of timeout 0 is returned. The command output from the command is then accessible from $self->{CMDRESULTS}. 

=item ARGUMENTS:

 1. The command to be issued to the CLI

=item PACKAGE:

 SonusQA::DSC

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure 

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

=item EXAMPLE:

 my @result = $obj->execShellCmd( "ls /opt/sonus" );

=back

=cut

sub execShellCmd {

    # Due to the frequency of running this command there will only be log output
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub = "execShellCmd";
    my ( $self, $cmd ) = @_;
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );

    my (@result);

    @result = $self->execCmd($cmd);

    foreach (@result) {
        chomp;

        if ( /error/ || /^\-bash:/ || /: command not found$/ || /No such file or directory/ ) {
            $logger->error( __PACKAGE__ . ".$sub:  CMD ERROR \($cmd\): --\n@result" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
            return 0;
        }
    }

    # Save cmd output
    my $command_output = $self->{CMDRESULTS};

    # So far so good then... now check the return code
    unless ( @result = $self->execCmd("echo \$?") ) {
        $logger->error( __PACKAGE__ . ".$sub:  CMD ERROR. Could not get return code from `echo \$?`. No return information" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    unless ( $result[0] == 0 ) {
        $logger->error( __PACKAGE__ . ".$sub:  CMD ERROR: return code $result[0] --\n@result" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }

    # Put the result back in case the user wants them.
    $self->{CMDRESULTS} = $command_output;

    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
    return 1;
}

