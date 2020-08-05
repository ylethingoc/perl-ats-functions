package SonusQA::SGX4000;

=head1 NAME

SonusQA::SGX4000 - Perl module for SGX4000 interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure   
   my $obj = SonusQA::SGX->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]',
                               -OBJ_PORT => '<port>'
                               );
   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus SGX4000.

=head2 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;

#use diagnostics;

use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::ATSHELPER;
use SonusQA::UnixBase;
require SonusQA::SGX4000::SGX4000HELPER;
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw(locate);
use File::Basename;
use XML::Simple;
use Data::GUID;
use Tie::File;
use String::CamelCase qw(camelize decamelize wordsplit);

our $VERSION = "1.0";
our %hws_version;

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SGX4000::SGX4000HELPER SonusQA::SGX::SGXHELPER SonusQA::SGX::SGXUNIX);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------

# ROUTINE: doInitialization
# Routine to set object defaults, Initialize all object variables and session prompt.

######################
sub doInitialization {
######################
    my ( $self, %args ) = @_;
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES}          = ["SSH", "SFTP"];
    $self->{TYPE}               = __PACKAGE__;
    $self->{CLITYPE}            = "sgx4000";    # Is there a real use for this?
    $self->{conn}               = undef;
    $self->{PROMPT}             = '/.*[#>\$%] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{REVERSE_STACK}      = 1;
    $self->{LOCATION}           = locate __PACKAGE__;
  
    my ( $name, $path, $suffix )    = fileparse($self->{LOCATION},"\.pm"); 
    
    $self->{sftp_session}       = undef;
    $self->{sftp_session_for_ce} = undef;
    $self->{shell_session}      = undef;
    $self->{curl}               = undef;
    $self->{CLI_RECONNECT}      = 1;
    $self->{DBGfile}            = "";
    $self->{SYSfile}            = "";
    $self->{ACTfile}            = "";
    $self->{TRCfile}            = "";
    $self->{AUDfile}            = "";
    $self->{SECfile}            = "";
  
    $self->{DIRECTORY_LOCATION}     = $path;
    $self->{IGNOREXML}              = 1;
    $self->{SESSIONLOG}             = 0;
    $self->{DEFAULTTIMEOUT}         = 60;

    $self->{POST_8_4}           = undef;
    
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

=head2 setSystem()

    This function sets the system information such as pagination, screen width, also set the system vesrion and following variables:

                $self->{CE_NAME_LONG}         = long CE name, ie. the domain name of the CE
                $self->{PLATFORM_VERSION}     = platform version
                $self->{APPLICATION_VERSION}  = application version

=cut

#################
sub setSystem() {
#################
    my $version_check_cmd       = "show status system serverStatus";
    my $anti_paginating_cmd     = "set paginate false";
    my $fix_cli_width_cmd         = "set screen width 512";

    my ($self, %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    my ( $cmd, $prompt, $prevPrompt, @results );
    
    my $lastline = $self->{conn}->lastline;
    unless ( ($lastline =~ m/connected|^Last login/i) || (grep /connected|Last login:/i, @{$self->{'BANNER'}}) ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".setSystem  This session does not seem to be connected. Skipping System Information Retrieval");
        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $self->{ENTEREDCLI} ) {
        $logger->warn(__PACKAGE__ . ".setSystem Not in CLI (PORT = $self->{OBJ_PORT})");
        if(!defined $self->{HW_TYPE} && $self->{OBJ_USER} eq "root"){
            my (%hw_match,@hw_info,$version,$hw_version_cmd);
            $hw_version_cmd = "dmidecode -t 4 | grep Version";
            %hw_match =('L5408'=>"4250",'E5-2620 0'=>"HPG8",'E5-2620 v2'=>"HPG8_V2");
            @hw_info = $self->{conn}->cmd($hw_version_cmd);
            if ($hw_info[0] =~ m/Version:.*CPU\s+(.*)\s+@.*/){
                $version = $1;
                $version =~ s/^\s+|\s+$//g;
            }
            $hws_version{$self->{OBJ_HOST}} = $hw_match{$version};
            $logger->debug(__PACKAGE__ . ".setSystem [$self->{OBJ_HOST}] HW_TYPE [$hws_version{$self->{OBJ_HOST}}] ");
        }
        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
        return 1;
    }
    my %info_hash = ( 'platformVersion'    => 'PLATFORM_VERSION',
                      'applicationVersion' => 'APPLICATION_VERSION'
                    );
    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".setSystem  Hostname variable (via -obj_hostname) not set.");
        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [0]");
        return 0;
    }
    # Turn off CLI paging and set screen width to maximum (512 chars)
    my @page_info = $self->{conn}->cmd($anti_paginating_cmd);
       @page_info = $self->{conn}->cmd($fix_cli_width_cmd);

    $logger->info(__PACKAGE__ . ".setSystem  ATTEMPTING TO RETRIEVE SGX4000 SYSTEM INFORMATION FROM CLI");

    my (@version_info, $flag);

    LOOP: foreach my $try (1..5) {

        unless (@version_info = $self->{conn}->cmd($version_check_cmd)) {
            if( grep /Request Timeout/, ${$self->{conn}->buffer}){
		$logger->debug(__PACKAGE__ . ".setSystem Error: ".${$self->{conn}->buffer});
                $logger->debug(__PACKAGE__ . ".setSystem CMD: \'$version_check_cmd\' execution failed on attempt $try due to Get Request Timeout. Retrying..");
                $logger->debug(__PACKAGE__ . "Sleeping for 10 sec before retrying system serverStatus command again");
                sleep 10;
                next;
            }else{
                $logger->error(__PACKAGE__ . ".setSystem CMD: \'$version_check_cmd\' execution failed");
 	        $logger->debug(__PACKAGE__ . ".setSystem errmsg: " . $self->{conn}->errmsg);
		$logger->debug(__PACKAGE__ . ".setSystem Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".setSystem Session Input Log is: $self->{sessionLog2}");
                return 0;
            }
        }

        if ( $version_info[$#version_info] =~ /^\[error\]/ ) {
            # CLI command is wrong
            #
            $logger->warn(__PACKAGE__ . ".setSystem  SYSTEM INFO NOT SET. CLI COMMAND ERROR. CMD: \'$version_check_cmd\'.\n ERROR:\n @version_info");
            return 0;
        }

        VLOOP: foreach my $vi ( @version_info ) {
            # Scan for this system
            if ($vi =~ /serverStatus\s*(\S+)\s*\{/i) {
                my $ce_name = $1;
                $self->{CE_NAME_LONG} = $ce_name;
            }

            next VLOOP if ($self->{CE_NAME_LONG} !~ m/^$self->{OBJ_HOSTNAME}/i);
            if ($vi =~ /\s*(\w+)\s*(.+)\;/) {
                my ($key, $value) = ($1, $2);
                $self->{$info_hash{$key}} = $value if($info_hash{$key});
            }

            next VLOOP unless ($self->{PLATFORM_VERSION} and $self->{APPLICATION_VERSION});
            $logger->info (__PACKAGE__ . ".setSystem  Matched: \'$self->{OBJ_HOSTNAME}\' ($self->{CE_NAME_LONG})");
            $logger->info  (__PACKAGE__ . ".setSystem  \'$self->{OBJ_HOSTNAME}\': Platform/Application Versions: $self->{PLATFORM_VERSION} / $self->{APPLICATION_VERSION}");
            last VLOOP if ($self->{PLATFORM_VERSION} and $self->{APPLICATION_VERSION});
        } 
    
        if ($self->{APPLICATION_VERSION} and $self->{APPLICATION_VERSION} !~ /Unknown/i) {
           $logger->info(__PACKAGE__ . ".setSystem got the APPLICATION VERSION on $try attempt");
           $flag = 1;
           last LOOP;
        } 
        elsif($self->{CE_NAME_LONG} and $self->{CE_NAME_LONG} !~ m/^$self->{OBJ_HOSTNAME}/i){
            $logger->error(__PACKAGE__ . ".setSystem  System information for hostname '$self->{OBJ_HOSTNAME}' not found/matching, Version Info:\n@version_info"); 
            last LOOP; 
        }
        else {
           if ($try == 5) {
               $logger->error(__PACKAGE__ . ".setSystem Unable to get Application Version, Tried for 5 times");
               last LOOP;
           } else {
               $logger->debug(__PACKAGE__ . ".setSystem sleep of 2 seconds");
               sleep (2);
               $logger->error(__PACKAGE__ . ".setSystem Unable to get Application Version on $try attempt, Lets try again");
               map {$self->{$info_hash{$_}} = undef } keys %info_hash;
           }
       }
   }
    # Check to see if there was any luck...
    #
    unless ( $flag ) {
        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [0]");
        return 0;
    }
    
    # Set the LOG PATH based on the relevant version of SGX 
    if ( $self->{PLATFORM_VERSION} =~ /^V(\d{2})\.(\d{2})/ ) {
            if ( $1 == 8 ) {
               if ( $2 > 2 ) {
                   $self->{LOG_PATH} = "/var/log/sonus/sgx/evlog";
               } else {
                   $self->{LOG_PATH} = "/var/log/sonus/sgx";
               } 
            }
            elsif ( $1 > 8 ) {
                $self->{LOG_PATH} = "/var/log/sonus/sgx/evlog";
            } elsif ( $1 < 8 ) {
                $self->{LOG_PATH} = "/var/log/sonus/sgx";
            }
     }

     $self->{HW_TYPE} = $hws_version{$self->{OBJ_HOST}} if (defined $hws_version{$self->{OBJ_HOST}});
     $main::TESTSUITE->{SGX4000_PLATFORM} = $self->{HW_TYPE} unless ($main::TESTSUITE->{SGX4000_PLATFORM}); #hold the PLATFORM_VERSION to frame log dir
     $main::TESTSUITE->{SGX4000_APPLICATION_VERSION} = 'SGX_'.$self->{APPLICATION_VERSION} unless ($main::TESTSUITE->{SGX4000_APPLICATION_VERSION}); #hold the APPLICATION_VERSION to frame log dir
     if ($self->{APPLICATION_VERSION} =~ /^\w(\d+\.\d+)\./) {
         if ($1 ge '08.04' ) {
             $self->{POST_8_4} = 1;
             $logger->debug(__PACKAGE__ . ".setSystem  SGX4000 POST_8_4 flag is set");
         }
     } 

     if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
        if (my $system_name = $self->retrieveSystemName()) {
            $main::TESTSUITE->{DUT_VERSIONS}->{"SGX,$system_name"} = $self->{APPLICATION_VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"SGX,$system_name"});
         } else {
            $logger->warn(__PACKAGE__ . ".setSystem unable to retrive the system name");
         }
     }
    
     unless ( $self->{LOG_PATH} ) {
         $logger->warn (__PACKAGE__ . ".setSystem \$self->\{LOG_PATH} not set. Version info : $self->{PLATFORM_VERSION} ");
         return 0;
     } 
     $logger->info  (__PACKAGE__ . ".setSystem Default LOG PATH set to \'$self->{LOG_PATH}\' for Version $self->{PLATFORM_VERSION} ");

    # Populating the SGX4000 TESTBED PAIR $self->{TESTBED_PAIR_NO}  of the current CE.
    # This was introduced in order to provide a workaround solution for CLI connection Loss Issue. Refer CQ: SONUS00125904
    foreach ( @main::TESTBED ) {
        if ( ref($_) ne "ARRAY" ) { 
            if ( $self->{OBJ_HOSTNAME} =~ /$_/i ) {
                for ( my $i =1 ; $i <= 3; $i++ ) {
                    if (  defined $main::TESTBED{ "sgx4000:$i:ce0" } ) {
                        if ( $main::TESTBED { "sgx4000:$i:ce0" } eq $_ ) {
                            $logger->debug (__PACKAGE__ . ".setSystem  SGX4000 TESTBED PAIR NO FOR THIS CE is  \"$i\""); 
                            $self->{TESTBED_PAIR_NO} = $i;
                            last;
                        }
                    }
                    if (   defined $main::TESTBED{ "sgx4000:$i:ce1"} ) {
                        if ( $main::TESTBED { "sgx4000:$i:ce1" } eq $_ ) {
                            $logger->debug (__PACKAGE__ . ".setSystem  SGX4000 TESTBED PAIR NO FOR THIS CE is  \"$i\"");
                            $self->{TESTBED_PAIR_NO} = $i;
                            last;
                        }
                    }
                }
            }
        } else {
            my @testbed = @{$_};
            foreach ( @testbed ) {
                if ( $self->{OBJ_HOSTNAME} =~ /$_/i ) {
                    for ( my $i =1 ; $i <= 3; $i++ ) {
                        if (  defined $main::TESTBED{ "sgx4000:$i:ce0" } ) {
                            if ( $main::TESTBED { "sgx4000:$i:ce0" } eq $_ ) {
                                $logger->debug (__PACKAGE__ . ".setSystem  SGX4000 TESTBED PAIR NO FOR THIS CE is  \"$i\"");
                                $self->{TESTBED_PAIR_NO} = $i;
                                last;
                            }
                        }
                        if (   defined $main::TESTBED{ "sgx4000:$i:ce1"} ) {
                            if ( $main::TESTBED { "sgx4000:$i:ce1" } eq $_ ) {
                                $logger->debug (__PACKAGE__ . ".setSystem  SGX4000 TESTBED PAIR NO FOR THIS CE is  \"$i\"");
                                $self->{TESTBED_PAIR_NO} = $i;
                                last;
                            }
                        } # end if-elsif
                    } # end inner for loop
                } # end if eq to hostname
            } # end testbed for
        } # end if-else of ref ARRAY
    } # End main for loop
    
    unless ( defined $self->{TESTBED_PAIR_NO} ) {
        $logger->error(__PACKAGE__ . ".setSystem Testbed Pair No could not be defined for $args{-obj_hostname} ");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head2 execCmd()

DESCRIPTION:

 The function is the generic function to issue a command to the SGX4000. It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the CLI command

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned. It is highly recommended that the user parses the return from execCmd for both the expected string and error strings to better identify any possible cause of failure.

 Note :- 1) The below messages are removed to make sure we get required result.
            Messages - Stopping user sessions during sync phase!
                       Disabling updates -- read only access
                       Enabling updates -- read/write access
         2) Incase of CLI connection loss, command will be executed on active cli session (GBLOBAL object if available else reconnection made to active CE and considered it as a GLOBAL object)

=over

=item ARGUMENTS:

1. The command to be issued to the CLI
2. Maximun number of seconds before whcih command execution should complete, optional argument, default value will be value of $self->{DEFAULTTIMEOUT}

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 @cmdResults - either the information from the CLI on successful return of the expected prompt, or an empty array on timeout of the command.

=item EXAMPLE:

 my @result = $obj->execCmd( "show table sigtran sctpAssociation" , 120);

=back 

=cut


sub execCmd {  
  
    my ($self,$cmd, $timeout)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
    my(@cmdResults);
 
    my $timestamp = $self->getTime();
    $timeout ||= $self->{DEFAULTTIMEOUT};
 
    if ( $self->{ENTEREDCLI} ) {
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CLI CMD: $cmd");    
    }
    else { 
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
    }
    $self->{LASTCMD}    = $cmd; 
    $self->{CMDRESULTS} = ();
    my $abortFlag =0;

    my @avoid_us = ('Stopping user sessions during sync phase\!','Disabling updates \-\- read only access','Enabling updates \-\- read\/write access');
    my $pattern = '(' . join('|',@avoid_us) . ')';
    if ( $self->{ENTEREDCLI} ) {

        $self->{PRIVATE_MODE} = 1 if ($cmd eq 'configure private'); # set a flag saying we are into private mode
        $self->{PRIVATE_MODE} = 0 if ($cmd eq 'exit'); # un-set the falg indicating we are out of configure mode

        unless ($self->{conn}->prompt eq $self->{PROMPT} ) {
            $logger->error(__PACKAGE__ . ".execCmd change of prompt, so considering it as new prompt");
            $self->{PROMPT} = ($self->{conn}->prompt =~ /.*[#>\$%] $/) ? '/.*[#>\$%] $/' : $self->{conn}->prompt;
        }

        $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command
       
        my $last_prompt = $self->{conn}->last_prompt;
        unless ($self->{conn}->put( -string => $cmd . $self->{conn}->output_record_separator , -timeout   => $timeout)) {
           $logger->info(__PACKAGE__ . ".execCmd: unable to execute $cmd");
        }

        unless ($self->{conn}->print_length > 0) {
           $logger->info(__PACKAGE__ . ".execCmd: re-execution of $cmd, failed to print $cmd to the buffer on first try");
           $self->{conn}->put( -string => $cmd . $self->{conn}->output_record_separator , -timeout   => $timeout );
        }

        if ($self->{conn}->print_length > 0) {
        my ($prematch, $match);
        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                              -match     => '/\[ok\]/',
                                                              -match     => '/\[error\]/',
                                                              -match     => $self->{PROMPT},
                                                              -timeout   => $timeout,
	                                                     )) {
           $logger->error(__PACKAGE__ . ".execCmd:  Could not match expected prompt after $cmd.");
        }
        
        if ($prematch =~ /$pattern/i or $match =~ /$pattern/i) {
            my $matched_msg = $1;
            $logger->info(__PACKAGE__ . ".execCmd: \'$matched_msg\' thrown by device during the execution of the command, clearing it");
            $prematch =~ s/$pattern//gi;
            $prematch =~ s/$last_prompt//g; #clearing all the prompts in prematch
            $match =~ s/$pattern//gi;
            $last_prompt = $self->{conn}->last_prompt if ($self->{conn}->last_prompt);
            if ($match =~ /$last_prompt/ and $prematch !~ /\S/) {
                unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                                  -match     => '/\[ok\]/',
                                                                  -match     => '/\[error\]/',
                                                                  -match     => $self->{PROMPT},
                                                                  -timeout   => $timeout,
                                                                 )) {
                    $logger->error(__PACKAGE__ . ".execCmd:  clearing $matched_msg and capturing the required output failed after the execution of command $cmd.");
	            $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
        	    $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
                    return 0;
               }
            }
        }
		
        if ( $match =~ m/\[ok\]/ ) {
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
        } elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".execCmd:  \'$cmd\' CLI COMMAND ERROR:\n$prematch\n$match");
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
        }
	
	$prematch =~ s/$cmd//i;	
        @cmdResults = split('\n', $prematch);
        push (@cmdResults, $match) if ($match);
	chomp (@cmdResults);
        }
    } else {
        @cmdResults = $self->{conn}->cmd( String =>$cmd, Timeout=> $timeout);
    } 

    unless ( @cmdResults  ) {
        # Entered due to a timeout on receiving the correct prompt. What reasons would lead to this?
        # Reboot?
        #
        @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        push(@{$self->{CMDRESULTS}},@cmdResults);
   
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
        } 
        else {
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".execCmd  UNKNOWN CLI ERROR DETECTED, CMD ISSUED WAS:");
            $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
            $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        
            chomp(@cmdResults);
        
            map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        
            $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            if ($self->{CLI_RECONNECT}) { 

                # lets start the circus of reconnection of CLI session ( along with collection and roll over of logs)
		$self->{CHECK_CORE} = 1;
		$logger->debug(__PACKAGE__ . ".execCmd Alias Argument for checkSGXcore: [$self->{TMS_ALIAS_NAME}]");
		if($self->checkSGXcore(-sgxAlias => $self->{TMS_ALIAS_NAME},-corePath=>"/var/log/sonus/sgx/coredump")) {
        	    $logger->error(__PACKAGE__ . ".execCmd   found core.");
		    unless ($self->reconnectAny()) {
			$logger->error(__PACKAGE__ . ".execCmd - failed make re-connection");
			&error("Unable to reconnect after CMD FAILURE: $cmd");
                    }else {
			$logger->info(__PACKAGE__ . ".execCmd - succesfully made a re-connection");
			if ($self->{PRIVATE_MODE} == 1 and ($cmd ne 'configure private')) {
			   $logger->debug(__PACKAGE__ . ".execCmd enetring into private mode after the reconnection");
                           $logger->error(__PACKAGE__ . ".execCmd unable to run \'configure private\'") unless ($self->{conn}->cmd(String =>"configure private"));
                        }
                        unless (@cmdResults = $self->{conn}->cmd( String =>$cmd, Timeout=> $self->{DEFAULTTIMEOUT})) {
                           $logger->error(__PACKAGE__ . ".execCmd \'$cmd\' execution failed after the reconnection");
                           $abortFlag =1;
                        } else {
                           $logger->debug(__PACKAGE__ . ".execCmd \'$cmd\' executed after the reconnection");
                        }
                    }
    		} else {
                    my @logs = (defined $self->{REQUIRED_LOGS}) ? @{$self->{REQUIRED_LOGS}} : ("system", "debug");
                    my %file_type = ( system => "SYS", debug  => "DBG",  trace  => "TRC", acct   => "ACT", audit  => "AUD", security => "SEC");
                    my @logfiles = ();

                    foreach (@logs) {
                       next unless defined $self->{$file_type{$_} . 'file'};
                       my $destfile = ( (defined $main::TESTSUITE->{TEST_ID}) ? $main::TESTSUITE->{TEST_ID} : 'NONE' ) . "-NONE-$self->{LOG_TIME_STAMP}-SGX-$self->{OBJ_HOSTNAME}-CLIFAILURE-" . $self->{$file_type{$_} . 'file'};
                       push (@logfiles, "$self->{$file_type{$_} . 'file'} $destfile");
                    }
                    if ($self->getSGXLog($main::log_dir , @logfiles)) {
                       $logger->error(__PACKAGE__ . ".execCmd - failed to collect the current logs before re-connection");
                    } else {
                       $logger->info(__PACKAGE__ . ".execCmd - succesfully collect the current logs before re-connection");
                    }
                    unless ($self->reconnectAny()) {
                       $logger->error(__PACKAGE__ . ".execCmd - failed make re-connection");
                       &error("Unable to reconnect after CMD FAILURE: $cmd");
                    } else {
                       $logger->info(__PACKAGE__ . ".execCmd - succesfully made a re-connection");
                       if ($self->{PRIVATE_MODE} == 1 and ($cmd ne 'configure private')) {
                           $logger->debug(__PACKAGE__ . ".execCmd enetring into private mode after the reconnection");
                           $logger->error(__PACKAGE__ . ".execCmd unable to run \'configure private\'") unless ($self->{conn}->cmd(String =>"configure private"));
                       }
                       unless ( SonusQA::ATSHELPER::startLogs(-objectArray   => [ $self])) {
                           $logger->error(__PACKAGE__ . ".execCmd failed to roll over logs after CLI re-connection");
                       } else {
                           $logger->debug(__PACKAGE__ . ".execCmd succesfully rolled over logs after CLI re-connection");
                       }
                       unless (@cmdResults = $self->{conn}->cmd( String =>$cmd, Timeout=> $self->{DEFAULTTIMEOUT})) {
                           $logger->error(__PACKAGE__ . ".execCmd \'$cmd\' execution failed after the reconnection");
                           $abortFlag =1;
                       } else {
                           $logger->debug(__PACKAGE__ . ".execCmd \'$cmd\' executed after the reconnection");
                       }
                    } # end unless else for re-connection
		}
		$self->{CHECK_CORE} = 0;
            } #end CLI_RECONNECT flag check
        } # end if else
     } # end main unless

    #$logger->debug(__PACKAGE__ . ".execCmd  ISSUING CLI CMD: 111111111 cmdResults = @cmdResults");    

    if ( @cmdResults && $cmdResults[$#cmdResults] =~ /^\[[Ee]rror\]/ ) {
        # CLI command has produced an error. This maybe intended, but the least we can do is warn 
        #
 #       $logger->warn(__PACKAGE__ . ".execCmd  CLI COMMAND ERROR. CMD: \'$cmd\'.\n ERROR:\n @cmdResults");
    }

    if ($abortFlag) {
        if( defined $ENV{CMDERRORFLAG} &&  $ENV{CMDERRORFLAG} ) {
             $logger->warn(__PACKAGE__ . ".execCmd  ABORT_ON_CLI_ERROR ENV FLAG IS POSITIVE - CALLING ERROR ");
             &error("CMD FAILURE: $cmd");
        }
    }
 
    chomp(@cmdResults);
 
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  
    push( @{$self->{CMDRESULTS}}, @cmdResults );
#    push( @{$self->{HISTORY}}, "$timestamp :: $cmd" );
    
    return @cmdResults;
}

=head2 execCliCmd()

DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for SGX4000 CLI specific strings: [ok] and [error]. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The CLI output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for ok and error from every CLI command call. 

=over

=item ARGUMENTS:

1. The command to be issued to the CLI

=item PACKAGE:

 SonusQA::SGX4000

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

 my @result = $obj->execCliCmd( "show table sigtran sctpAssociation" );

=back 

=cut

sub execCliCmd {

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execCliCmd";
    my ($self,$cmd) = @_;
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".execCliCmd");
    my (@result);
 
    $logger->debug(__PACKAGE__ . ".$sub_name: Clearing the buffer");

    $self->{conn}->buffer_empty;

    # Execute Command
    unless ( @result = $self->execCmd( $cmd ) ) {
       $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR. No return information");
       return 0;
    }

    foreach ( @result ) {
        chomp;
        if ( /^\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR:--\n@result");
            return 0;
        }
        elsif ( /^\[ok\]/ ) {
            return 1;
        }
    }
	# Reached end of result without error or ok
	$logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR: Neither \[error\] or \[ok\] returned from cmd --\n@result");
	return 0;
}


=head1 execCommitCliCmd()

DESCRIPTION:

 THis function is used to execute commands which need to commit after execution, by running commit command on SGX4000

=over 

=item ARGUMENTS:

1. The commands to be issued to the CLI, passed as a array

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - All command excuted and commited 
 0 - Incase of any error 

=item EXAMPLE:

 my $return = $obj->execCommitCliCmd( "command1", "command2" );

=back 

=cut

sub execCommitCliCmd {
    my  ($self, @cli_command ) = @_ ;
    my  $sub_name = "execCommitCliCmd" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( @cli_command ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  No CLI command specified." );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Assumption: We are already in a configure session

    foreach ( @cli_command ) {
        chomp();
        unless ( $self->execCliCmd ( $_ ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot execute command $_:\n@{ $self->{CMDRESULTS} }" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
#            $self->execCliCmd("exit");  - this is not to be added here, as there are many negative testcases that expects the command to fail and the prompt is expected to be in that state, but if the 'exit' given here is executed it will change the prompt to [yes,no], so those testcases will fail. 
            $self->{LASTCMD} = $_;
            return 0;
        }

        unless ( $self->execCliCmd ( "commit" ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot commit command $_:\n@{ $self->{CMDRESULTS} }" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            # Set LASTCMD back to the original command, else it will always leave here being 'commit'
#            $self->execCliCmd("exit");
            $self->{LASTCMD} = $_;
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Committed command: $_");
        $self->{LASTCMD} = $_;
    }  
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 enterPrivateSession()

DESCRIPTION:

    This subroutine enters configure private mode

=over 

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   unless ( $object->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode" );
      return 0;
   } 

=back 

=cut

sub enterPrivateSession {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "enterPrivateSession" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Enter private session
    
    unless ( $self->execCliCmd( "configure private" ) ) {
        # Are we already in a session?
        unless ( $self->execCliCmd( "status" ) ) {
            # This should work if we're in a config session already. 
            # If this fails, we're off the reservation
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot enter private configure session" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 execShellCmd()

DESCRIPTION:

 The function is a wrapper around execCmd for the SGX4000 linux shell. The function issues a command then issues echo $? to check for a return value. The function will then return 1 or 0 depending on whether the echo command yielded 0 or not. Ie. in the shell 0 is pass (and so the perl function returns 1) any other value is fail (and so the perl function returns 0). In the case of timeout 0 is returned. The command output from the command is then accessible from $self->{CMDRESULTS}. 

=over 

=item ARGUMENTS:

1. The command to be issued to the CLI
2. Maximun number of seconds before whcih command execution should complete, optional
3. Additional sleep required to check the command status

=item PACKAGE:

 SonusQA::SGX4000

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

 my $result = $obj->execShellCmd( "ls /opt/sonus" );

 For command which takes long time, such as 'sgxstop' etc

 my $result = $obj->execShellCmd('sgxstop', 180, 20);

 note - Output of command will be stored in array reference $obj->{CMDRESULTS}

=back 

=cut

sub execShellCmd {

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execShellCmd";
    my ($self,$cmd, $timeout, $seconds) = @_;
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".execCliCmd");
    my (@result);

    my $temp_flag = $self->{ENTEREDCLI};
    $self->{ENTEREDCLI} = 0;
 
    @result = $self->execCmd( $cmd , $timeout); 

    #foreach ( @result ) {
    #    chomp;
    #    if ( /^error/ ) {
    #        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
    #        return 0;
    #    }
    #    elsif ( /^\-bash:/ ) {
    #        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
    #        return 0;
    #    }
    #    elsif ( /: command not found$/ ) {
    #        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
    #        return 0;
    #    }
    #    elsif ( /No such file or directory/ ) {
    #        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
    #        return 0;
    #    }
    #}

    # Save cmd output

    my $command_output = [@result];
    sleep $seconds if ( defined $seconds and $seconds);

    # So far so good then... now check the return code
    unless ( @result = $self->execCmd( "echo \$?" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        return 0;
    }

    $self->{ENTEREDCLI} = $temp_flag;
    # when $? == 0, success;
    # otherwise when $? == 1, failure;

    # Put the result back in case the user wants them.
    $self->{CMDRESULTS} = $command_output;

    my $first_element_of_result=(split /\s+/,$result[0])[0];
    unless ( $first_element_of_result eq 0  ) {
	$self->{RETURNCODE} = $result[0]; # storing it to check in SonusQA::SGX4000::SGX4000HELPER.clearSgxConfigDatabase (CQ: SONUS00152276)
	$logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0] --\n@result");
        return 0;
    }

    return 1;
}

=head2 newFromAlias()
  
DESCRIPTION: 
This function uses the ATSHELPER newFromAlias to open a standard session to the SGX4000. Choices are login in via the CLI as admin:admin (or whatever the USERID and PASSWD are from TMS) or as root into port 2024. For anything more complex than that, it is recommended to use SonusQA::SGX4000::new.

=over 

=item ARGUMENTS:                               

 -tms_alias => TMS alias string 

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ATSHELPER::newFromAlias()

=item OUTPUT:

 $ats_obj_ref - ATS object if successful
 exit         - otherwise

=item EXAMPLE: 

 my $sgx4000_obj = SonusQA::SGX4000::newFromAlias(-tms_alias => <tms alias>);

=back

=cut

sub newFromAlias {   

    my ( %args ) = @_;
    my $tms_alias       = $args{-tms_alias};
    my ( $return_on_fail, $sessionlog );
    my ( $user, $password, $commtype );

    my $ats_obj_ref;

    my $sub_name        = "newFromAlias()";
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( defined($tms_alias) && ($tms_alias !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \$tms_alias undefined or is blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving $sub_name");
        exit;
    }

    my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);

    if ( defined ( $args{"-return_on_fail"} ) && $args{"-return_on_fail"} == 1) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  -return_on_fail set to \'1\'");
        $return_on_fail = 1;
    }
    else {
        $return_on_fail = 0;
        $logger->debug(__PACKAGE__ . ".$sub_name:  -return_on_fail set to \'0\'");
    }

    if ( defined ( $args{"-sessionlog"} ) && $args{"-sessionlog"} == 1) {
        $sessionlog = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name:  -sessionlog set to \'1\'");
    }
    else {
        $sessionlog = 0;
        $logger->debug(__PACKAGE__ . ".$sub_name:  -sessionlog set to \'0\'");
    }

    if ( defined ( $args{"-obj_user"} ) ) {
        $user = $args{ "-obj_user" };
    }
    else {
        $user = $alias_hashref->{LOGIN}->{1}->{USERID};
        $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_user set to \'$user\' from TMS");
    }

    if ( defined ( $args{"-obj_password"} ) ) {
        $password = $args{"-obj_password"};
    }
    else {
        $password = $alias_hashref->{LOGIN}->{1}->{PASSWD};
        $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_password set to TMS_ALIAS->LOGIN->1->PASSWD");
    }

    if ( defined ( $args{"-obj_commtype"} ) ) {
        $commtype = $args{"-obj_commtype"};
        if ( ($commtype ne "TELNET") && ($commtype ne "SSH") &&
             ($commtype ne "SFTP")   && ($commtype ne "FTP") ) {
            $commtype = "SSH";
        }
    }
    else {
        $commtype = "SSH";
        $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_commtype set to \'$commtype\'");
    }

    my $timeout;
    if ( defined ( $args{-defaulttimeout} ) ) {
       $timeout = $args{-defaulttimeout};
    } else {
       $timeout = 60;
    }

    $ats_obj_ref = SonusQA::ATSHELPER::newFromAlias(
                                                    -tms_alias      => $tms_alias, 
                                                    -obj_type       => "SGX4000",     
                                                    -return_on_fail => $return_on_fail,
                                                    -sessionlog     => $sessionlog,
                                                    -obj_user       => $user,
                                                    -obj_password   => $password,
                                                    -obj_commtype   => $commtype,
                                                    -defaulttimeout => $timeout,
                                                   ); 

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return $ats_obj_ref; 

}


=head2 configureAllSignalingNifs()

DESCRIPTION:

 This function configures the internal/external signaling NIFs for the SGX4000 based on information stored in TMS. Each CE should have two INT_SIG_NIFs and 2 EXT_SIG_NIFs. These IP address are then configured as:
 1) Primary internalSignaling NIF   = <ce name>-nif3
 2) Primary externalSignaling NIF   = <ce name>-nif4
 3) Secondary internalSignaling NIF = <ce name>-nif7
 4) Secondary externalSignaling NIF = <ce name>-nif8

 Internal Signaling NIFs are configured on port 3, external signaling NIFs are on port 4.

 For the "internalSignaling" NIF netmask is "255.255.0.0". The "externalSignaling" NIF netmask is "255.255.255.0".

=over 

=item ARGUMENTS:

 1. SGX4000 CE name (eg "asterix" or "obelix") - this is also the TMS alias name.
 Note: The verification of the CE name to be configured on the SGX4000 will be done by the SGX CLI. Ie. if the CE that is being attempted to be configured is not a part of the system, the CLI will error.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 - fail; 
 1 - success;

=item EXAMPLE:

 To configure the Signaling links for Obelix on the present SGX object call - $obj->configureAllSignalingNifs("obelix");  

=back 

=cut

sub configureAllSignalingNifs{

    my ($self,$ce_name) = @_;
    my $sub_name = "configureAllSignalingNifs";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring Signaling NIFs for $ce_name...");

     
    # variables used in the nif config command
    my $ip_mode;        # store the value of 'INT_SIG_NIF' or 'EXT_SIG_NIF' from TMS hash
    my $ip_index;       # 1 for 'primary' and 2 for 'secondary' from TMS hash. Eg {INT_SIG_NIF}->{1}
    my $nif_name;       # has the format of ce name + "-nif" + nif number. Eg asterix-nif3.
    my $netmask;        # netmask="255.255.0.0" for 'internalSignaling', netmask="255.255.255.0" for 'externalSignaling'.
    my $port_id;        # portId
    my $ip_address;     # ipAddress
    my $cmd;

    # the possible nif combinations:
    my %nif_combinations= (
        "internalSignaling" => [ "primary", "secondary" ],
        "externalSignaling" => [ "primary", "secondary" ],
    );

    # %nif_parameters_hash contains the config parameters for internalSingaling and externalSignaling. 
    #       InternalSignalling - the network mask is 255.255.0.0, port_id =3,  
    #                            and, 'primary'-nidID =3; 'secondary'- nifID=7;  (secondary nifID value = primary's nifID +4 )
    #       ExternalSignalling - the network mask is 255.255.255.0; port_id =4,
    #                            and, 'primary'-nidID =4; 'secondary'- nifID=8;  (secondary nifID value = primary's nifID +4 )
    my %nif_parameters_hash = (
        "internalSignaling" =>{
            "primary"   => { "nif_id" => 3, "ip_index" => 1 },
            "secondary" => { "nif_id" => 7, "ip_index" => 2 },
            "port_id"   => "port3",
            "ip_mode"   => "INT_SIG_NIF",
            "netmask"   => "255.255.0.0",
         },
        "externalSignaling" =>{
            "primary"   => { "nif_id" => 4, "ip_index" => 1 },
            "secondary" => { "nif_id" => 8, "ip_index" => 2 },
            "port_id"   => "port4",
            "ip_mode"   => "EXT_SIG_NIF",
            "netmask"   => "255.255.255.0",
         },
    );

    my $alias_hashref;

    # If newFromAlias has been used, TMS DATA hash is already populated
    if ( keys %{ $self->{TMS_ALIAS_DATA} } ) {

        # Check if this data is for the named CE, else we'll need to retrieve it anyway
        if ( $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} eq $ce_name ) {
            $alias_hashref=$self->{TMS_ALIAS_DATA};
        }
        else {
            # This is not the CE you're looking for...
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $ce_name through resolve_alias.");
            $alias_hashref=SonusQA::Utils::resolve_alias($ce_name);
        }
    }
    else {
        if ( $self->{OBJ_HOSTNAME} eq $ce_name ) {
            # Resolve and attach
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $ce_name through resolve_alias.");
            $self->{TMS_ALIAS_DATA} = SonusQA::Utils::resolve_alias($ce_name);
            $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} = $ce_name;
            $alias_hashref=$self->{TMS_ALIAS_DATA};
        }
        else { 
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $ce_name through resolve_alias.");
            $alias_hashref=SonusQA::Utils::resolve_alias($ce_name);
        }
    }

    # Check if the object type is SGX40000
    unless ( $alias_hashref->{ __OBJTYPE } eq "SGX4000") {
        $logger->error(__PACKAGE__ . ".$sub_name:  The TMS object type: $alias_hashref->{__OBJTYPE} should be SGX4000 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->execCliCmd("show table networkInterface admin $ce_name")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute command $self->{LASTCMD}--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my  @cur_nif_table = @{$self->{CMDRESULTS}};  # store the table result;

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute command $self->{LASTCMD}--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered config private mode.");


    # To ensure internalSignaling & primary to appear first;
    # for 'internalSignaling' & 'externalSignaling' : sort + reverse 

    foreach my $int_ext_key (reverse (sort keys %nif_combinations ) ) {
        NEXTNIFCMD:
        foreach my $prim_sec_key ( @{$nif_combinations{$int_ext_key}}) {
            $port_id   = $nif_parameters_hash{$int_ext_key}{port_id};
            $ip_mode   = $nif_parameters_hash{$int_ext_key}{ip_mode};
            $ip_index  = $nif_parameters_hash{$int_ext_key}{$prim_sec_key}{ip_index};
            $netmask   = $alias_hashref->{$ip_mode}->{$ip_index}->{MASK} || $nif_parameters_hash{$int_ext_key}{netmask}; # Fix for TOOLS-4922
            $ip_address= $alias_hashref->{$ip_mode}->{$ip_index}->{IP};
            $nif_name  = sprintf("%s-nif%s",$ce_name,$nif_parameters_hash{$int_ext_key}{$prim_sec_key}{nif_id});

            # remove the trailling whitespace for varying IP address length, eg 10.31.3.50 -> 10.1.3.50
            $ip_address =~ s/\s+$//;

            # check if the ip address is already in the table (show table networkInterface admin);
            foreach (@cur_nif_table) {
                if(/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+$ip_address\s+[0-9\.]+\s+(\S+)\s+(\S+)/) {
                    # ^^^    ^^^     ^^^     ^^^     ^^^                              ^^^     ^^^
                    # ce     type    use     port    NIF                             state   mode
                    # $1      $2     $3       $4     $5                               $6      $7
                    if ($4 eq "disabled" or $5 eq "outOfService") {
                        $logger->error(__PACKAGE__ . ".$sub_name:  $ip_address already exists and is $4 - $5 for CE: $1, NIF \($2\): $3");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }
                    elsif ( $1 eq $ce_name and $2 eq $int_ext_key and $3 eq $prim_sec_key and $4 eq $port_id ) {
                        $logger->debug(__PACKAGE__ . ".$sub_name:  The NIF \($2\): $3, IP: $ip_address has already been configured for CE: $1. Skipping...");
                        next NEXTNIFCMD;
                    }
                    else {
                        $logger->error(__PACKAGE__ . ".$sub_name:  An entry exists for IP: $ip_address, CE: $1, but the information is not as expected.");
                        $logger->debug(__PACKAGE__ . ".$sub_name:  Expecting: Type - $int_ext_key, Usage - $prim_sec_key and Port ID - $port_id.");
                        $logger->debug(__PACKAGE__ . ".$sub_name:  Found:     Type - $2, Usage - $3 and Port ID - $4.");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
            }
            $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring Signaling NIF - Usage: $prim_sec_key, Type: $int_ext_key, on port $port_id as $ip_address for CE: $ce_name...");

            for(0..2) {
                if ($_ == 0 ) {
                    $cmd = "set networkInterface admin $ce_name $int_ext_key $prim_sec_key portId $port_id interfaceName $nif_name ipAddress $ip_address mask $netmask speed speed1000Mbps duplexMode full autoNegotiation on";
                }
                elsif($_==1) {
                    $cmd = "set networkInterface admin $ce_name $int_ext_key $prim_sec_key state enabled";
                }
                elsif($_== 2) {
                    $cmd = "set networkInterface admin $ce_name $int_ext_key $prim_sec_key mode in";
                }
                # start to execute the cmd;
                unless ($self->execCliCmd("$cmd")) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Command $cmd - failed --\n@{$self->{CMDRESULTS}}" );
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
                unless ( $self->execCliCmd("commit")) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}" );
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        } # foreach (primary/secondary)
    } # foreach (internal/external Signaling) 

    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot leave private session--\n@{$self->{CMDRESULTS}}" );
        $logger->warn(__PACKAGE__ . ".$sub_name:  Unable to leave a configure session. This may result in errors if this object is continues to be used" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  All Signaling NIFs for CE: $ce_name configured.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 configureInternalM3UALinks()

DESCRIPTION:

 This function configures all necessary entities in order to enable M3UA messaging on the internal Signalling NIFs between the named CE and the named device (GSX or PSX). The steps taken in order to do this are: 

 1) Creation of the SCTP assocations between the named CE and the named device
 2) Creation of the sgp/sua links between the CE and the named device. 
    (We need to pass the argument '-link_type' as sua for sua links. By default it takes sgp)

 Note: on the internal signalling side there is no reference to a node or a linkset

 The SCTP associations can be specified as multi-homed or single homed. The array returned by the function contains a list of names. These names refer to the SCTP association name AND the corresponding sgpLink/suaLink.

=over 

=item ARGUMENTS:

     -ce          - Mandatory SGX4000 CE name
     -device      - Mandatory remote device name (ie. GSX or PSX tms alias)
     -local_port  - Mandatory local port number
     -remote_port - Mandatory remote port number
     -assoc_type  - Mandatory preference for SCTP associations, single or multi homed.
     -prefix      - Optional prefix for sctp association and sgplinks/sualinks names
     -link_type	  - Optional, pass it the value as 'sua' for sua links

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None.

=item EXTERNAL FUNCTIONS USED:

 None.

=item OUTPUT:

 0            - fail
 @assoc_names - an array of sctp assoc names. The configured sgpLinks/sualLinks mirror these names 1:1. 

=item EXAMPLE:

    Between asterix and Oscar:
    	$obj->configureInternalM3UALinks( -ce =>"asterix",-device => "oscar", -assoc_type => "multi", -local_port => 2905, -remote_port => 2905, -prefix => "oscarCE0");

	For sua link:
		$obj->configureInternalM3UALinks( -ce => .sgx4k12., -device => .TECGSX1., -assoc_type => 'single', -local_port => 14001, -remote_port=> 14001, -link_type => 'sua' );	

=back 

=cut

sub configureInternalM3UALinks {

    my ($self,%int_m3ua_hash) = @_;
    my $sub_name = "configureInternalM3UALinks";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #****************************************************
    # step 1: Input checking 
    #****************************************************

    foreach ("ce","device","local_port","remote_port","assoc_type") {
        unless ( $int_m3ua_hash{-$_} && $int_m3ua_hash{-$_} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

	#setting default value (sgp) for '-link_type' if it is not passed 
	$int_m3ua_hash{-link_type} ||= 'sgp';

    $logger->debug(__PACKAGE__ . ".$sub_name:  Creating SCTP/M3UA associations and links between $int_m3ua_hash{-ce} and $int_m3ua_hash{-device}");

    #****************************************************
    # step 2: set the sctp association through configureSCTPAssocs
    #****************************************************

    # Creating the prefic line to be passed into to configureSCTPAssocs
    my $prefix_argument;
    
    if ( $int_m3ua_hash{-prefix} && $int_m3ua_hash{-prefix} ne "" ) {
        $prefix_argument = "-prefix       => \"$int_m3ua_hash{-prefix}\"";
    } 
    else {
        $prefix_argument = "";
    }

    my @assoc_names = $self->configureSCTPAssocs( 
                                             -ce             => $int_m3ua_hash{-ce},
                                             -device         => $int_m3ua_hash{-device},
                                             -assoc_type     => $int_m3ua_hash{-assoc_type},
                                             -local_port     => $int_m3ua_hash{-local_port},
                                             -remote_port    => $int_m3ua_hash{-remote_port},
                                             $prefix_argument
                                            );

    # Check if the return is 0;
    if ( (@assoc_names==1) && !$assoc_names[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not create SCTP associations between $int_m3ua_hash{-ce} and $int_m3ua_hash{-device}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #****************************************************
    # step 3: to set m3ua sgp/sua link
    #****************************************************

    foreach (@assoc_names) {
        unless ( $self->createM3UALink( -assoc_name => "$_", -type => $int_m3ua_hash{-link_type} )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not create $int_m3ua_hash{-link_type} link $_ between $int_m3ua_hash{-ce} and $int_m3ua_hash{-device}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured SCTP/M3UA associations and links between $int_m3ua_hash{-ce} and $int_m3ua_hash{-device}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [array:link/assoc names]");

    # Both the SCTP associations and the sgpLinks/suaLinks have the same name
    return @assoc_names;

}

=head2 createM3UALink()

DESCRIPTION:

This function simnply configures a m3ua asp, sgp or sua link. Information passed in at a minimum is the link type, sgp, asp or sua, and the SCTP association. If an asp link, then the asp linkset argument must also be passed in. Link name is optional and if omitted will become the same as the SCTP association name.

=over 

=item ARGUMENTS:

     -type              -  Mandatory type of M3UA link, values are "sgp", "asp" or "sua"
     -assoc_name        -  Mandatory sctp association name
     -asp_linkset_name  -  Mandatory IF type is asp
     -link_name         -  Optional input for link name. By default, the link name will be the same as the SCTP assoc. name.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createM3UAlink( -type => "sgp", -assoc_name => "asterixGsxOscar11" );
 OR
    $obj->createM3UAlink( -type => "asp", -assoc_name => "asterixSTP1", -asp_linkset_name => "asterixMGTS25stp1", -link_name => "mgtsLink1" );

=back 

=cut

sub createM3UALink {

    my ($self,%link_hash) = @_;

    my $sub_name = "createM3UALink";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my ( $cmd, $assoc_name, $link_type, $asp_linkset, $link_name );

    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ( keys %link_hash ) {

        if ( $_ eq "-assoc_name" ) {
            $assoc_name  = $link_hash{-assoc_name};
        }
        elsif ( $_ eq "-type" ) {
            $link_type   = $link_hash{-type};
        }
        elsif ( $_ eq "-asp_linkset_name" ) {
            $asp_linkset = $link_hash{-asp_linkset_name};
        }
        elsif ( $_ eq "-link_name" ) {
            $link_name   = $link_hash{-link_name};
        }
        else { 
            $logger->error(__PACKAGE__ . ".$sub_name:  Argument \'$_\' is not recognised.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    
    # For asp and sgp links, we need assoc name 
    unless ( defined $assoc_name && $assoc_name ne "" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory argument for $link_type links \'-assoc_name\' is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # For asp links we need the linkset name and assoc name as a minimum
    if ( $link_type eq "asp" ) {
        unless ( defined $asp_linkset && $asp_linkset ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory argument for $link_type links \'-asp_linkset_name\' is missing or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    # Name is defaulted to the association name if optional link_name not specified
    unless ( defined $link_name && $link_name ne "" ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  \'-link_name\' is not specified or blank, defaulting link name to equal association name.");
        $link_name = $assoc_name;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring $link_type link $link_name...");

    unless ( $self->execCliCmd( "configure private" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #****************************************************
    # step 2: Configuring m3ua aspLink if aspLinkSet is given;
    #         whether to configure aspLink or sgpLink , depends on if aspLinkSet name is given or not;
    #****************************************************

    my @link_config_cmds;

    # Checking if asp
    if ( $link_type eq "asp" ) {

        @link_config_cmds = (
                                 "set m3ua aspLink $link_name m3uaAspLinkSetName $asp_linkset sctpAssociationName $assoc_name",
                                 "set m3ua aspLink $link_name state enabled",
                                 "set m3ua aspLink $link_name mode in",
                            );

    }
    # If sgp
    elsif ( $link_type eq "sgp" ) {

        @link_config_cmds = (
                                 "set m3ua sgpLink $link_name sctpAssociationName $assoc_name",
                                 "set m3ua sgpLink $link_name state enabled",
                                 "set m3ua sgpLink $link_name mode in",
                            );

    }
    # If sua
    elsif ( $link_type eq "sua" ) {

        @link_config_cmds = (
                                 "set sua sgpLink $link_name sctpAssociationName $assoc_name",
                                 "set sua sgpLink $link_name state enabled",
                                 "set sua sgpLink $link_name mode in",
                            );

    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name:  Value for link type: $link_type is not valid. Please state one of sgp, asp or sua" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Configure Links...
    foreach ( @link_config_cmds ) {
        unless ($self->execCliCmd( $_ ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command \'$_\' failed --\n@{$self->{CMDRESULTS}}" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $self->execCliCmd("exit");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' for command \'$cmd\' failed --\n@{$self->{CMDRESULTS}}" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $self->execCliCmd("exit");
            return 0;
        }
    }

    #****************************************************
    # step 4: Leaving the config mode;
    #****************************************************

    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot leave private session--\n@{$self->{CMDRESULTS}}");
        $logger->warn(__PACKAGE__ . ".$sub_name:  Unable to leave a configure session. This may result in errors if this object is continues to be used" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Configured $link_type link $link_name with association $assoc_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 configureSCTPAssocs()

DESCRIPTION:

This function configures the SCTP associations between the SGX4000 and the defined GSX/PSX/MGTS. The association type can be multi-homed or single-homed. In the case where single homed associations are chosen there will only be connections defined between the two named devices on ONE subnet only. Where both subnets exist, there should no reason for single-homed associations. 

There is an option to specify a prefix name for the SCTP associations. If no prefix is defined, by default, the SCTP assocation names follow the following format:

 1) Between SGX4000 and GSX

    SGX4000 CE name (lower case) + "Gsx"+ GSX device name (first letter upper case) + MNS number + index
    eg: asterixGsxOscar11  (MNS 1, index number 1 )
        asterixGsxOscar12  (MNS 1, index number 2 )
        asterixGsxOscar21  (MNS 2, index number 1 )
        asterixGsxOscar22  (MNS 2, index number 2 )

 2) Between SGX4000 and PSX

    SGX4000 CE name (lower case) + "Psx"+ PSX device name (first letter upper case) + index
    eg: asterixPsxCheech1  (index number 1 )
        asterixPsxCheech2  (index number 2 )

 3) Between SGX4000 and MGTS

    SGX4000 CE name (lower case) + MGTS device name (first letter upper case) + index
    eg: asterixUkmgts251  (index number 1 )
        asterixUkmgts252  (index number 2 )

 If the prefix has been provided, the name will be "prefix+index". 
 Note: For SGX4000 - GSX associations where a prefix has been defined the format will be prefix+MNS+index to avoid name clashes within the function.

 Otherwise,the default name will be used according to the above formats. The index number refers to the connection index between the pair (the same IP address with different port numbers) of SGX4000 CE and remote device. 
 Note: If an association is found with the same prefix, the sub will find the last index and continue to create associations incremeting from there.

 As the maximum association name length is 24 bytes, so the maximum length for the SGX4000 CE, GSX,PSX and MGTS will be 9,9,10 and 13 bytes respectively due to different naming formats. Consequently if there is a prefix defined, this must not exceeed 22 bytes.

=over

=item ARGUMENTS:

    -ce          - mandatory, SGX4000 CE name (eg asterix)
    -device      - mandatory, the remote GSX/PSX/MGTS device name 
    -assoc_type  - mandatory, either single home mode or multi home mode
    -local_port  - mandatory, the port number used by SGX4000 CE
    -remote_port - mandatory, the port number used by remote device
    -prefix      - optional, allows the user to define the sctp assoc name

NOTE: 
 For ALL SCTP associations that are to be used for Internal Signalling traffic (ie. to the GSX or PSX) the local port number should remain unchanged while the remote ports can be changed. For SCTP associations that are to be used for External Signalling then there should only be one local port per node.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None.

=item EXTERNAL FUNCTIONS USED:

None.

=item OUTPUT:

 @assoc_names - an array that consists of the sctp association names
 0            - failure

=item EXAMPLE:

 For SCTP connections between SGX4000 CE obelix and the GSX oscar:

    $obj->configureSCTPAssocs( -ce => "obelix", -device => "oscar", -assoc_type => "single", -local_port => 2905, -remote_port => 2907 );
 OR    
    $obj->configureSCTPAssocs( -ce => "obelix", -device => "oscar", -assoc_type => "multi", -local_port => 2905, -remote_port => 2907, -prefix => "ce1Oscar" );

=back 

=cut

sub configureSCTPAssocs {

    my  ($self, %assoc_input ) = @_ ;
    my  $sub_name = "configureSCTPAssocs";
    my  $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # The following hashes provides the information about how to read the IP address from TMS
    my  %gsx_mns1_ip_hash  = ( 
           single => { localIP  => ["INT_SIG_NIF","1","IP"], remoteIP => ["MGMTNIF","1","IP"] },
           multi  => { localIP  => ["INT_SIG_NIF","1","IP","INT_SIG_NIF","2","IP"],
                       remoteIP => ["MGMTNIF","1","IP","MGMTNIF","2","IP"]},
           );
    my  %gsx_mns2_ip_hash = ( 
           single => { localIP  => ["INT_SIG_NIF","1","IP"], remoteIP => ["MGMTNIF","3","IP"] },
           multi  => { localIP  => ["INT_SIG_NIF","1","IP","INT_SIG_NIF","2","IP"] ,
                       remoteIP => ["MGMTNIF","3","IP","MGMTNIF","4","IP"]},
           );
    my  %psx_ip_hash = (
           single => { localIP  => ["INT_SIG_NIF","1","IP"],  remoteIP => ["NODE","1","IP"] },
           multi => {  localIP  => ["INT_SIG_NIF","1","IP","INT_SIG_NIF","2","IP"],
                       remoteIP => ["NODE","1","IP","NODE","2","IP"]},
           );
    my  %mgts_ip_hash = (
           single =>{ localIP  => ["EXT_SIG_NIF","1","IP"],  remoteIP => ["SIGNIF","1","IP"] },
           multi => { localIP  => ["EXT_SIG_NIF","1","IP","EXT_SIG_NIF","2","IP"],
                      remoteIP => ["SIGNIF","1","IP","SIGNIF","2","IP"]},
          );

    # %assoc_name_hash contains two types of input parameters: the assoc name format and the hash reference to the related NIF information
    my  %assoc_name_hash = (
          "GSX"  => { "%sGsx%s1"  => \%gsx_mns1_ip_hash,    # here, 1 means MNS1
                      "%sGsx%s2"  => \%gsx_mns2_ip_hash     # here, 2 means MNS2
                     },
          "PSX"  => { "%sPsx%s"  =>  \%psx_ip_hash },
          "MGTS" => { "%s%s"  => \%mgts_ip_hash },          # the "Mgts" is not included as the mgts device name already contains "MGTS"; eg "UKMGTS25";
          );

    my  $assoc_name;            # the association name according to the format defined in assoc_name_hash
    my  @assoc_name_buffer;     # the association name results will be stored in this variable;
    my  $ip_address;            # the NIF ip address


    # ***********************************************
    # step 1: Checking inputs, prefix and tms alias
    # ***********************************************

    foreach ("ce","device","local_port","remote_port","assoc_type") {
        unless ( $assoc_input{-$_} && $assoc_input{-$_} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    unless ( $assoc_input{-assoc_type} eq "multi" or $assoc_input{-assoc_type} eq "single" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The specified value for -assoc_type \($assoc_input{-assoc_type}\) is not multi or single.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring $assoc_input{-assoc_type}-homed SCTP associations between $assoc_input{-ce} and $assoc_input{-device}...");

    # If the prefix is given, its length should not be larger than 22 as the maximum assoc name length =24 and the minimum length for the index number is 2;
    if ( $assoc_input{-prefix} ) {
        if ( length( $assoc_input{-prefix} ) > 22 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Error - the prefix length should not larger than 22 bytes.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    if ( $assoc_input{-prefix} && $assoc_input{-prefix} eq "" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Specified prefix should not be blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Check if object has been opened with newFromAlias, or if the data needs to be resolved
    my  $local_alias_hashref;

    # If newFromAlias has been used, TMS DATA hash is already populated
    if ( keys %{ $self->{TMS_ALIAS_DATA} } ) {

        # Check if this data is for the named CE, else we'll need to retrieve it anyway
        if ( $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} eq $assoc_input{-ce} ) {
            $local_alias_hashref=$self->{TMS_ALIAS_DATA};
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $assoc_input{-ce} through resolve_alias.");
            $local_alias_hashref=SonusQA::Utils::resolve_alias($assoc_input{-ce});
        }
    }
    else {
        if ( $self->{OBJ_HOSTNAME} eq $assoc_input{-ce} ) {
            # Resolve and attach
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $assoc_input{-ce} through resolve_alias.");
            $self->{TMS_ALIAS_DATA} = SonusQA::Utils::resolve_alias($assoc_input{-ce});
            $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} = $assoc_input{-ce};
            $local_alias_hashref=$self->{TMS_ALIAS_DATA};
        }
        else { 
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving hash for $assoc_input{-ce} through resolve_alias.");
            $local_alias_hashref=SonusQA::Utils::resolve_alias($assoc_input{-ce});
        }
    }

    # Check if the local object type equals SGX40000
    unless ( $local_alias_hashref-> { __OBJTYPE } eq "SGX4000") {
        $logger->error(__PACKAGE__ . ".$sub_name:  The local object type: $local_alias_hashref->{__OBJTYPE} is not SGX4000");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get TMS alias data for remote device
    my  $remote_alias_hashref=SonusQA::Utils::resolve_alias($assoc_input{-device});

    # Check if $remote_alias_hashref is empty 
    unless (keys %$remote_alias_hashref) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Error: TMS alias data for $assoc_input{-device} is empty or unavailable, please check TMS.");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
    }
    # ***********************************************
    # step 2: Set the connection mode and command format
    # ***********************************************

    my  $connection_mode ;              # the connection mode type

    if    ( $remote_alias_hashref->{__OBJTYPE} eq "GSX"  ) { $connection_mode = "passive"; }
    elsif ( $remote_alias_hashref->{__OBJTYPE} eq "PSX"  ) { $connection_mode = "passive"; }
    elsif ( $remote_alias_hashref->{__OBJTYPE} eq "MGTS" ) { $connection_mode = "active" ; }
    else {
         $logger->error(__PACKAGE__ . ".$sub_name:  The remote device type $remote_alias_hashref->{__OBJTYPE} for $assoc_input{-device} does not match with GSX or PSX, MGTS.");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
    }

    unless ($self->execCliCmd("show table sigtran sctpAssociation")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to query for exisiting SCTP associations by executing the command $self->{LASTCMD}: @{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    my  @cur_conf_table = @{$self->{CMDRESULTS}};  # store the current sctp association configuration data

    # ***********************************************
    # step 4: to produce the sctp assoc commands;
    # ***********************************************

    my $device_type = $remote_alias_hashref->{__OBJTYPE};        # the remote device type; eg GSX/PSX/MGTS
    my $assoc_name_format;  # the name format defined in assoc_name_hash;

    foreach $assoc_name_format ( sort keys %{ $assoc_name_hash{ $device_type } } ) {

        # Set the assoc name in order to make a max total of 24 bytes: 
        # max CE name size = 9 bytes, max GSX name size = 9 bytes, max PSX name size = 10 bytes; max MGTS name size = 13 bytes

        if ($assoc_input{-prefix}) {

            $assoc_name = $assoc_input{-prefix};

            #if the device is "GSX", the MNS number needs to be defined to avoid name clashes;

            if ($device_type eq "GSX") {
                if ( $assoc_name_format eq "%sGsx%s1" )     { $assoc_name .= "1"; }     # for MNS1, attach "1";
                elsif ( $assoc_name_format eq "%sGsx%s2" )  { $assoc_name .= "2"; }     # for MNS2, attach "2";
            }
        }
        else {
            if ($device_type eq "MGTS") {
                $assoc_name= sprintf("$assoc_name_format",(substr lc($assoc_input{-ce}),0,9),(substr ucfirst(lc($assoc_input{-device})),0,13));  # 9+13+2 =24 
            }
            elsif ($device_type eq "PSX") {
                $assoc_name= sprintf("$assoc_name_format",(substr lc($assoc_input{-ce}),0,9),(substr ucfirst(lc($assoc_input{-device})),0,10));  # 10+9+3+2 =24
            }
            else {
                $assoc_name= sprintf("$assoc_name_format",(substr lc($assoc_input{-ce}),0,9),(substr ucfirst(lc($assoc_input{-device})),0,9));  # 9+9+3+1+2 =24
            }
        }

        $logger->debug(__PACKAGE__ . ".$sub_name:  Using prefix $assoc_name for configuring next SCTP association.");

        # Check if assoc name is already used in the SCTP table
        my  @grep_results = grep(/$assoc_name/i, @cur_conf_table);

        # If the assoc name has been already used, find the largest index number;
        my @index_number;  # store all the index number;

        if ($#grep_results >= 0 ) {
            foreach( @grep_results) {
                if (/^$assoc_name/i) {
                    if ((split/\s+/,$_)[0]=~ /($assoc_name)(\d+)$/) { 
                    #                           ^^^         ^^^
                    #                        $1=assoc name  $2=index
                        push @index_number,$2; 
                    }
                }
            }
        }
        if (@index_number) {
            $assoc_name .=(reverse sort {$a<=>$b} @index_number )[0]+1; # attach the largest index number plus 1 to assoc name
        }
        else {
            $assoc_name .="1";  # otherwise, starting from 1;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SCTP association $assoc_name...");

        my @cmd_buffer;
        push @cmd_buffer,$assoc_name;    # store the sctp association name;

        my  $i;
        # Retrieving local IP address from TMS
        for ($i=0; $i<=$#{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}}; ) {
            $ip_address = $local_alias_hashref->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i]}->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+1]} ->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+2]};

            unless($ip_address) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Can't retrieve IP address: $assoc_input{-ce}:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i]:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+1]:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+2] from TMS.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            $ip_address=~ s/\s+//;        # remove space
            push @cmd_buffer,$ip_address; # store the ip address
            $i+=3;
        }
        push @cmd_buffer,$assoc_input{-local_port}; # store the local port number;

        # Retrieving remote IP address from TMS; 
        for ($i=0;$i<=$#{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{remoteIP}};) {
            $ip_address=$remote_alias_hashref->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{remoteIP}[$i]}->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{remoteIP}[$i+1]} ->{$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{remoteIP}[$i+2]};

            unless($ip_address) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Can't retrieve IP address: $assoc_input{-ce}:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i]:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+1]:$assoc_name_hash{$device_type}{$assoc_name_format}{$assoc_input{-assoc_type}}{localIP}[$i+2] from TMS.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            $ip_address=~ s/\s+//;          # remove space
            push @cmd_buffer,$ip_address;   # store the ip address;
            $i+=3;
       }

        #store remote port number and the connection mode;
        push @cmd_buffer, $assoc_input{-remote_port};
        push @cmd_buffer, $connection_mode;

        # Check if the parameters are already in the table
        foreach (@cur_conf_table) {
            chomp;
            if(/^(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+([0-9\.]+)\s+([0-9\.-]+)\s+(\d+)\s+([0-9\.]+)\s+([0-9\.-]+)\s+(\d+)\s+/){
                # ^^^    ^^^    ^^^     ^^^      ^^^           ^^^         ^^^      ^^^           ^^^          ^^^     
                # name  index  state    mode   localIP1    localIP2/-     port1  remoteIP1     remoteIP2/-    port2   
                # $1             $2     $3      $4             $5          $6       $7            $8           $9

                if($assoc_input{-assoc_type} eq "single") {
                    if (($4 eq $cmd_buffer[1]) && ($6 eq $cmd_buffer[2]) && ($7 eq $cmd_buffer[3]) && ($9 eq $cmd_buffer[4])) {
                        $logger->error(__PACKAGE__ . ".$sub_name:  The configuration already exists for ce: $1, local IP: $4 / port: $6, remote IP: $7 / port: $9.");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
                if($assoc_input{-assoc_type} eq "multi") {
                    if (($4 eq $cmd_buffer[1])  && ($5 eq $cmd_buffer[2]) && ($6 eq $cmd_buffer[3])&& ($7 eq $cmd_buffer[4]) && ($8 eq $cmd_buffer[5]) && ($9 eq $cmd_buffer[6])) {
                        $logger->error(__PACKAGE__ . ".$sub_name:  The configuration already exists for ce: $1, local IPs: $4 & $5 / port: $6, remote IPs: $7 & $8 / port: $9");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
            }
        }

        if ( $assoc_input{-assoc_type} eq "multi" ) {
            unless ( $self->createSCTPAssoc( -name =>$cmd_buffer[0],
                     -local_ip1 => $cmd_buffer[1], -local_ip2 => $cmd_buffer[2], -local_port => $cmd_buffer[3],
                     -remote_ip1 => $cmd_buffer[4], -remote_ip2 => $cmd_buffer[5], -remote_port => $cmd_buffer[6],
                     -connection_mode => $cmd_buffer[7]))
            {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to configure SCTP Assocication:" );
                $logger->debug(__PACKAGE__ . ".$sub_name:   local ip: $cmd_buffer[1], local ip2: $cmd_buffer[2], local port: $cmd_buffer[3], remote ip1: $cmd_buffer[4]" );
                $logger->debug(__PACKAGE__ . ".$sub_name:   remote ip2: $cmd_buffer[5], remote port: $cmd_buffer[6], connection mode: $cmd_buffer[7]" );
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        else {
            unless ( $self->createSCTPAssoc( -name =>$cmd_buffer[0],
                     -local_ip1 => $cmd_buffer[1], -local_port => $cmd_buffer[2],
                     -remote_ip1 => $cmd_buffer[3], -remote_port => $cmd_buffer[4],
                     -connection_mode => $cmd_buffer[5]))
            {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to configure SCTP Assocication:" );
                $logger->debug(__PACKAGE__ . ".$sub_name:   local ip: $cmd_buffer[1], local port: $cmd_buffer[2], remote ip1: $cmd_buffer[3]" );
                $logger->debug(__PACKAGE__ . ".$sub_name:   remote port: $cmd_buffer[4], connection mode: $cmd_buffer[5]" );
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        push @assoc_name_buffer,$assoc_name;  # store the sctp assoc name
    } #foreach

    $logger->debug(__PACKAGE__ . ".$sub_name:  The $assoc_input{-assoc_type}-homed SCTP associations between $assoc_input{-ce} and $assoc_input{-device} have been successfully created");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [array:sctp assocs]");
    return @assoc_name_buffer;
}

=head2 createSCTPAssoc()

DESCRIPTION:
This function creates a single sigtran sctp association based on the input parameters. If a single-homed association is specified, ONLY the first addresses for local and remote ips must be used. If a multi-homed association is to be configured all four local and remote ip addresses must be specified. 

ARGUMENTS:
     -name              - Mandatory sctp association name,
     -local_ip1         - Mandatory local ip address,
     -local_ip2         - Optional second local ip address (for use in multi-homed associations)
     -local_port        - Mandatory local port number,
     -remote_ip1        - Mandatory remote device ip address,
     -remote_ip2        - Optional second remote ip address (for use in multi-homed associations)
     -remote_port       - Mandatory remote port number,
     -connection_mode   - Mandatory connection mode, its value is either 'passive' or 'active;

NOTE: 
 None

=over 

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  1) $obj->createSCTPAssoc( -name =>"gsx1",
                         -local_ip1=>"10.31.242.50", -local_ip2=>"10.1.242.50",-local_port=>2905,
                         -remote_ip1=>"10.31.3.1",-remote_ip2=>"10.31.3.2",-remote_port=>2905,-connection_mode=>"passive");

  2) $obj->createSCTPAssoc( -name =>"gsx2",
                         -local_ip1=>"10.31.242.50", -local_port=>2905, -remote_ip1=>"10.31.3.1",-remote_port=>2906,-connection_mode=>"passive");

=back

=cut

sub createSCTPAssoc {
    
    my ($self,%set_hash) = @_ ;
    my $sub_name = "createSCTPAssoc";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # ***********************************************
    # step 1: Checking mandatory inputs, prefix and tms alias
    # ***********************************************

    foreach ("local_ip1","local_port", "remote_ip1","remote_port","connection_mode") {
        unless ( $set_hash{-$_} && $set_hash{-$_} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ parameter is not specified or empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    if  ( ( $set_hash{-local_ip2} and !$set_hash{-remote_ip2} ) ||
          ( ! $set_hash{-local_ip2} and $set_hash{-remote_ip2} )) 
    {
            $logger->error(__PACKAGE__ . ".$sub_name:  Error: one of the secondary ip addresses is empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  local ip address 2: \'$set_hash{-local_ip2}\', remote ip address 2: \'$set_hash{-remote_ip2}\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
    }

    # ***********************************************
    # step 2: Setting configuration commands;
    # ***********************************************

    # Set mandatory IP address information to be used in the CLI cmd.
    my $ip_info  = "localIpAddress1 $set_hash{-local_ip1} remoteIpAddress1 $set_hash{-remote_ip1}";
    my $mode = "Single-homed";

    # If we are multi-homed, then append the extra IP info
    if ( $set_hash{-local_ip2} and $set_hash{-remote_ip2} ) {
        $mode = "Multi-homed";
        $ip_info  .= " localIpAddress2 $set_hash{-local_ip2} remoteIpAddress2 $set_hash{-remote_ip2}";
    }

    # Enter private session
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode --\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered config private mode.");

    # Set up SCTP configure commands based on ip_info set above
    my @sctp_cmds = (
         "set sigtran sctpAssociation $set_hash{-name} $ip_info localPort $set_hash{-local_port} remotePort $set_hash{-remote_port} connectionMode $set_hash{-connection_mode}",
         "set sigtran sctpAssociation $set_hash{-name} state enabled",
         "set sigtran sctpAssociation $set_hash{-name} mode in",
                    );

    foreach ( @sctp_cmds ) {
        unless ($self->execCliCmd( $_ ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command \'$_\' failed --\n@{$self->{CMDRESULTS}} . " );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $self->execCliCmd("exit");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}} . " );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $self->execCliCmd("exit");
            return 0;
        }
    }

    # ***********************************************
    # step 3: Leaving config private mode;
    # ***********************************************

    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave private session @{$self->{CMDRESULTS}}" );
        $logger->warn(__PACKAGE__ . ".$sub_name:  Unable to leave a configure session. This may result in errors if this object is continues to be used" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured the $mode SCTP association $set_hash{-name}:");
    if ($mode eq "Multi-homed") {
        $logger->debug(__PACKAGE__ . ".$sub_name:   \[$set_hash{-local_ip1} & $set_hash{-local_ip2}\] Port: $set_hash{-local_port} <--> \[$set_hash{-remote_ip1} & $set_hash{-remote_ip2}\] Port: $set_hash{-remote_port} ");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:   \[$set_hash{-local_ip1}\] Port: $set_hash{-local_port} <--> \[$set_hash{-remote_ip1}\] Port: $set_hash{-remote_port} ");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 createSS7Node()

DESCRIPTION:

This function is to set ss7 node configurations.

ARGUMENTS:

     -name                  - mandatory ss7 node name,  
     -pointCode             - mandatory point code value,  
     -ss7ProtocolType       - mandatory value for protocol. Options are itu, ansi and japan,
     -networkIndicator      - optional,
     -networkAppearance     - optional,
     -pointCodeFormat       - optional,
     -servicesList          - optional, 
     -ss7ProtocolVariant    - optional, 
     -sccpTimerProfileName  - optional,

 Default values are depends on which ss7 protocol type is:
    1) For "ansi":
      pointCodeFormat       = "networkClusterMember",
      servicesList          =  "tup,isup,sccp",
      networkIndicator      = "nat0",  
      networkAppearance     =  0,
      ss7ProtocolVariant    =  "base",
      sccpTimerProfileName  = "defaultANSI",

    2) For "itu":
     pointCodeFormat        = "decimal",
     networkIndicator       = "nat0",  
     servicesList           = "tup,isup,sccp",
     networkAppearance      = 0,
     ss7ProtocolVariant     = "base",
     sccpTimerProfileName   = "defaultITU",

    3) For "japan":
     pointCodeFormat        = "hexHex",
     servicesList           = "tup,isup,sccp",
     networkIndicator       = "intl0",  
     networkAppearance      = 0,
     ss7ProtocolVariant     = "base",
     sccpTimerProfileName   = "defaultJAPAN",

NOTE: 
The point code format includes:
        networkClusterMember: network-cluster-member with 8-8-8 bit fields.
        examples            : 250-200-250
                              0xFF-0xFF-0x1F

        zoneAreaId: zone-area-identifier with 3-8-3 bit fields.
        examples  : 7-250-5
                    0x7-0xFF-0x7

        hexHex  : hex-hex used with 8-8 bit fields.
        examples: 0xF0-0xF1
                  0xff-0x17

        unitMemberSubNumMainNum: unit member-sub numbering domain-main
                                 numbering domain with 7-4-5 bit fields.
        examples               : 127-15-31
                                 0x7F-0xf-0x7

        decimal : non-formatted used for any protocol type.
                  The actual length in bits shall be determined
                  by a particular protocol type.
        examples: For maximum 14 bit value(0-16383)
                  16300
                  For maximum 16 bit value(0-65535)
                  65000
                  For maximum 24 bit value(0-16777215)
                  16777200

=over 

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail
 1 -  success

=item EXAMPLE:

    $obj->createSS7Node( -name => "j7n1", -pointCode => "0x1-0x1", -ss7ProtocolType => "japan" );
 OR
    $obj->createSS7Node( -name => "sgxSigtranNode1", -pointCode => "40-40-40", -ss7ProtocolType => "ansi", 
                         -networkIndicator => "nat0", -networkAppearance => "666", -pointCodeFormat => "networkClusterMember",
                         -servicesList => "scp,tup,isup", -ss7ProtocolVariant =>"base", -sccpTimerProfileName =>"defaultANSI" );

=back

=cut

sub createSS7Node {
    my  ($self, %node_hash ) = @_ ;
    my  $sub_name = "createSS7Node";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my  $cmd ;

    #set the default node values;
    my  $default_setting_hash = {
        ansi   => {  
                    sccpTimerProfileName    => "defaultANSI",
                    pointCodeFormat         => "networkClusterMember",
                    networkIndicator        => "nat0",
                    servicesList            => "tup,isup,sccp",
                    networkAppearance       => 0,
                    ss7ProtocolVariant      => "base",
                  },
        itu    => { 
                    sccpTimerProfileName    => "defaultITU",
                    pointCodeFormat         => "decimal",
                    networkIndicator        => "nat0",
                    servicesList            => "tup,isup,sccp",
                    networkAppearance       => 0,
                    ss7ProtocolVariant      => "base",
                  },
        japan  => {
                    sccpTimerProfileName    => "defaultJAPAN",
                    pointCodeFormat         => "hexHex",
                    networkIndicator        => "intl0",
                    servicesList            => "tup,isup,sccp",
                    networkAppearance       => 0,
                    ss7ProtocolVariant      => "base",
                  },
    };


    #****************************************************
    # step 1: Check inputs and default setting
    #****************************************************

    foreach ( "name","pointCode", "ss7ProtocolType" ) {
        unless ( $node_hash{-$_} && $node_hash{-$_} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ parameter is not specified or empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Creating $node_hash{-ss7ProtocolType} ss7 node $node_hash{-name} with Point Code $node_hash{-pointCode}");

    #Checking the maximum length of the given node name (max=24 bytes)
    unless ( length($node_hash{-name}) <= 24 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Error: the $node_hash{-name} is larger than 24 bytes.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    unless ( $node_hash{-ss7ProtocolType} =~ /(ansi)|(itu)|(japan)/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Error: '$node_hash{-ss7ProtocolType}'- unknown SS7ProtocolType type. Please enter: 'ansi','itu' or 'japan'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    # Populate the rest of the attributes if not specified

    foreach ( keys %{ $default_setting_hash->{ $node_hash{-ss7ProtocolType} } } ) {
        # If the optional input is empty, setting it to the value defined in the %default_setting_hash;
        unless ( $node_hash{-$_} ) {
            $node_hash{-$_} = $default_setting_hash->{$node_hash{-ss7ProtocolType}}->{$_};
        }
    }

    unless ( $self->execCliCmd("configure private")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode--\n @{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered config private mode.");

    #****************************************************
    # step 2: Configure ss7 node
    #****************************************************

    my @node_cmds = (
                        "set ss7 node $node_hash{-name} pointCode $node_hash{-pointCode} ss7ProtocolType $node_hash{-ss7ProtocolType}".
                            " sccpTimerProfileName $node_hash{-sccpTimerProfileName} pointCodeFormat $node_hash{-pointCodeFormat} networkIndicator $node_hash{-networkIndicator}".
                            " servicesList $node_hash{-servicesList} networkAppearance $node_hash{-networkAppearance} ss7ProtocolVariant $node_hash{-ss7ProtocolVariant}",
                        "set ss7 node $node_hash{-name} state enabled",
                        "set ss7 node $node_hash{-name} mode in",
                    );

    foreach ( @node_cmds ) {
chomp();
        unless ($self->execCliCmd( $_ )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command \'$_\' failed--\n@{$self->{CMDRESULTS}}" );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  commit for \'$_\' failed--\n@{$self->{CMDRESULTS}}" );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving config private mode;
    #****************************************************

    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave private session--\n @{$self->{CMDRESULTS}}" );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created $node_hash{-ss7ProtocolType} ss7 node $node_hash{-name} with Point Code $node_hash{-pointCode}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 leaveConfigureSession()

DESCRIPTION:

    This subroutine take out system from private/Configure mode

=over

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   unless ( $object->leaveConfigureSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode" );
      return 0;
   } 

=back 

=cut

sub leaveConfigureSession {

    my  ($self, %args ) = @_ ;
    my  $sub_name = "leaveConfigureSession";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Issue exit and wait for either [ok], [error], or [yes,no]
    $self->{PRIVATE_MODE} = 0; # un-set the falg indicating we are out of configure mode
    unless ( $self->{conn}->print( "exit" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue exit" );
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
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
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
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
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
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

=head2 configureExternalM3UALinkSet()

DESCRIPTION:

 This function configures all necessary entities in order to enable M3UA messaging on the external Signalling NIFs between the named CE and the named device (MGTS). The steps taken in order to do this are: 

 1) Creation of the SCTP assocations between the named CE and the named device
 2) Creation of the asp links between the CE and the named device
 2) Creation of the asp linksets between the CE and the named device

 The SCTP associations can be specified as multi-homed or single homed. The array returned by the function contains a list of names. These names refer to the SCTP association name AND the corresponding sgpLink.

=over 

=item ARGUMENTS:

     -ce          - Mandatory SGX4000 CE name
     -device      - Mandatory remote device name (ie. MGTS tms alias)
     -node_name   - Mandatory ss7 node name
     -local_port  - Mandatory local port number
     -remote_port - Mandatory remote port number
     -assoc_type  - Mandatory preference for SCTP associations, single or multi homed.
     -prefix      - Optional prefix for sctp association and sgplinks names

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None.

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::configureSCTPAssocs
 SonusQA::SGX4000::createAspLinkSet
 SonusQA::SGX4000::activateAspLinkSet
 SonusQA::SGX4000::createM3UALink

=item OUTPUT:

 0            - fail
 @assoc_names - an array of sctp assoc names. The configured sgpLinks mirror these names 1:1. 

=item EXAMPLE:

    Between asterix and ukmgts25:
    $obj->configureExternalM3UALinkSet( -ce =>"asterix",-device => "oscar", -assoc_type => "multi", -local_port => 2905, -remote_port => 2905, -prefix => "oscarCE0");

=back

=cut

sub configureExternalM3UALinkSet {

    my  ($self, %ext_m3ua_hash ) = @_ ;
    my  $sub_name = "configureExternalM3UALinkSet" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # checking mandatory args
    foreach ("node_name","ce","device","local_port","remote_port","assoc_type") {
        unless ( $ext_m3ua_hash{-$_} && $ext_m3ua_hash{-$_} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Creating SCTP/M3UA associations and links/linkset between $ext_m3ua_hash{-ce} and $ext_m3ua_hash{-device}");

    # Creating the prefic line to be passed into to configureSCTPAssocs
    my $prefix_argument;
    
    if ( $ext_m3ua_hash{-prefix} && $ext_m3ua_hash{-prefix} ne "" ) {
        $prefix_argument = "-prefix       => \"$ext_m3ua_hash{-prefix}\"";
    } 
    else {
        $prefix_argument = "";
    }

    my @assoc_names = $self->configureSCTPAssocs(
                                                 -ce           => $ext_m3ua_hash{-ce},
                                                 -device       => $ext_m3ua_hash{-device},
                                                 -assoc_type   => $ext_m3ua_hash{-assoc_type},
                                                 -local_port   => $ext_m3ua_hash{-local_port},
                                                 -remote_port  => $ext_m3ua_hash{-remote_port},
                                                 $prefix_argument 
                                                );

    # Check if the return is 0 or not;
    unless ( $assoc_names[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not create SCTP associations between $ext_m3ua_hash{-ce} and $ext_m3ua_hash{-device}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Name the AspLinkSet the same as the 1st SCTP assoc. In the MGTS case
    # there will only ever be 1 association. But using this as a rule will minimise info passed out of sub

    my $linkset_name = $assoc_names[0];

    # Create aspLinkSet
    unless ( $self->createAspLinkSet( -name => $linkset_name, -node => $ext_m3ua_hash{-node_name} )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  createAspLinkSet failed for linkset: $linkset_name, node: $ext_m3ua_hash{-node_name}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Created asp linkset $linkset_name");

    # Create one link for each assoc
    foreach ( @assoc_names ) {
        unless ( $self->createM3UALink( -asp_linkset_name   => $linkset_name,
                                        -assoc_name         => $_,
                                        -type               => "asp", 
                                      ) )
        {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not create asp link $_");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    # Activate aspLinkSet
    unless ( $self->activateAspLinkSet( $linkset_name )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not activate aspLinkSet $linkset_name--\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured SCTP/M3UA associations, links and linkset between $ext_m3ua_hash{-ce} and $ext_m3ua_hash{-device}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [array:link/assoc names]");
    return @assoc_names;
}

=head2 activateAspLinkSet()

DESCRIPTION:

    This function activate all feeded M3UA asp linksets.

=over 

=item ARGUMENTS:

    Array of required M3UA asp linksets.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None.

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execCliCmd

=item OUTPUT:

 0  - Failure
 1  - Success

=item EXAMPLE:

    $obj->activateAspLinkSet( "linkset1", "linkset2");

=back 

=cut

sub activateAspLinkSet {

    my  ($self, @linkset_name ) = @_ ;
    my  $sub_name = "activateAspLinkSet" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode --\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered config private mode.");

    foreach ( @linkset_name ) {

    unless ($self->execCliCmd("set m3ua aspLinkSet $_ mode in") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  $self->{LASTCMD} failed --\n@{$self->{CMDRESULTS}}" );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $self->execCliCmd("commit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed--\n@{$self->{CMDRESULTS}}" );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Activated (mode inservice) aspLinkSet $_.");
    }
    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not leave private session" );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 1;
}


=head2 createAspLinkSet()

=over 

=item DESCRIPTION:

    This function creates an M3UA asp linkset. The only thing this depends on an exisiting SS7 node. Once created, the linkset is enabled but not activated, that is, the mode is left out of service. This is actually enforced by the CLI anyway.

=item ARGUMENTS:

    -name       - The name to be used for the asp linkset itself
    -node       - The node name for to be assigned to the linkset
    [options]   - Optional values to pass to the CLI command 'set m3ua aspLinkSet'

=item OPTIONS:

    At present the following are understood by the CLI:

    dynamicRegistration     - This object indicates whether the M3UA dynamic registration procedure is supported or not.
    remoteHostName          - This object refers to a remote host name that can be reached via this link set.
    routingContextTableName - This object refers to the associated routing context table that is used by the link set/links.

    In order to pass these to the CLI, simply use the name prepended with a dash, as in -dynamicRegistration => "yes"

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None.

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execCliCmd

=item OUTPUT:

 0  - Failure
 1  - Success

=item EXAMPLE:

    Between asterix and ukmgts25:
    $obj->configureExternalM3UALinkSet( -ce =>"asterix",-device => "oscar", -assoc_type => "multi", -local_port => 2905, -remote_port => 2905, -prefix => "oscarCE0");

#NOTE: this sub does not take the linkset inservice as there are no links configured

=item AUTHOR:

    Stuart Congdon (scongdon@sonusnet.com)

=back 

=cut

sub createAspLinkSet {

    my  ($self, %args ) = @_ ;
    my  $sub_name = "createAspLinkSet" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
 
    # Check args
    foreach ("node", "name") {
        unless ( $args{ -$_ } && $args{ -$_ } !~ /^\s*$/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory argument \'-$_\' is missing or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    my $node_name    = $args{ -node };
    my $linkset_name = $args{ -name };

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring asp linkset $linkset_name on node $node_name...");

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter private configuration session--\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @asp_linkset_cmds = (
                            "set m3ua aspLinkSet $linkset_name nodeName $node_name",
                            "set m3ua aspLinkSet $linkset_name state enabled"
                           ); 

    foreach ( @asp_linkset_cmds ) {
        unless ($self->execCliCmd( $_ ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command \'$_\' failed--\n@{$self->{CMDRESULTS}}" );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Commit for \'$_\' failed--\n@{$self->{CMDRESULTS}}" );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    # Don't forget to leave the private session
    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to leave private configure session" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }        
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created asp linkset $linkset_name on node $node_name.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  NOTE: This linkset has not been configured mode inservice as there are no aspLinks assigned to it.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 getSS7TableInfo()

DESCRIPTION:
This function is to get the requred information from ss7 tables, which include:
    ss7 node,
    ss7 route,
    ss7 destination,
    ss7 t1e1Board,
    ss7 t1e1Trunk,
    ss7 mtp2Link,
    ss7 mtp2SignalingLink,
    ss7 mtp2SignalingLinkSet,

 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over

=item ARGUMENTS:

     -table - Mandatory table type, values are sgpLink, sgpLinkStatus.
     -name     - Optional, if we want to get a specfic item's information, this option should be provided.
     -all    - Optional, if we want to get the whole table's information, this option should be provided.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

 0 - fail.
 @get_results: contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getSS7TableInfo(-table=>"route", -name =>"asplinkset1" );
  2) $obj->getSS7TableInfo(-table=>"route", -all => 1 );

=back

=cut

sub getSS7TableInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getSS7TableInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $get_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank. ");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }


    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }


    #****************************************************
    # step 2: To get info through retrieveConfigurationTableData;
    #****************************************************

    my @get_results;
    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"ss7/$get_hash{-table}", -all=>$get_hash{-all}  );
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"ss7/$get_hash{-table}", -name=>$get_hash{-name});
    }

    if ( (@get_results==1) && !$get_results[0] ) {
        defined $get_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $get_hash{-table} table data\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $get_hash{-name} data from the $get_hash{-table} table");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        defined $get_hash{-all} ?
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $get_hash{-table} table data\(-all\)."):
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $get_hash{-name} data from the $get_hash{-table} table");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    defined $get_hash{-all} ?
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $get_hash{-table} table data\(-all\)."):
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $get_hash{-name} data from the $get_hash{-table} table");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}

=head2 checkSS7TableInfo()

DESCRIPTION:
This function checks the named attribute status for SS7 tables.
 1) If the -all key is presented, it checks the named attributes with the whole table.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over

=item ARGUMENTS:

     -table       - Mandatory ss7 related names like mtp2Link, node.
     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::getSS7TableInfo;

=item OUTPUT:

  0 - false ( the results do not match the requirements).
  1 - true  ( the results match the requirements).
 -1 - error ( eg cli error ).

=item EXAMPLE:

  1) $obj->checkSS7TableInfo(-table=>"route", -name=>"asplinkset11" , -mode=>"outOfService");
  2) $obj->checkSS7TableInfo(-table=>"route", -name=>"/asplinkset1/", -mode=>"outOfService");
  3) $obj->checkSS7TableInfo(-table=>"route", -all=>1, -mode=>"outOfService");

=back

=cut

sub checkSS7TableInfo {
    my ($self, %check_hash) = @_;
    my $sub_name = "checkSS7TableInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
        -route => {
                 -index => 1,
                 -state => 2,
                 -mode =>3,
                 -destination =>4,
                -pointCodeDecimalValue => 5,
                -node =>6,
                -routeMode => 7,
                -priority=>8,
                -typeOfRoute=>9,
                -linkSetName=>10,
                },
        -destination => {
                 -index => 1,
                -state => 2,
                -mode => 3,
                -pointCodeDecimalValue=>4,
                -node=>5,
                -nodeIndex=>6,
                -pointCode=>7,
                -pointCodeDecimalValue=>8,
                -destinationType=>9,
                -isupProfile=>10,
                },
        -destinationStatus => {
                -mode=>1,
                -node=>2,
                -pointCode=>3,
                -destinationType=>4,
                -overAllPcStatus=>5,
                -overAllPcCongestionLevel=>6,
                -overAllUserPartAvailableList=>7,
                -m3uaPcStatus=>8,
                -m3uaUserPartAvailableList=>9,
                -m3uaPcCongestionLevel=>10,
                -mtpPcStatus=>11,
                -mtpPcCongestionLevel=>12,
                -mtpUserPartAvailableList=>13,
        },
        -t1e1Board => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -ceName=>4,
                -boardNumber=>5,
                -clockSourceExternal=>6,
                -clockSourceTrunk=>7,
                -independentClockTrunks=>8,
        },
        -t1e1Trunk => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -t1e1BoardName=>4,
                -trunkNumber=>5,
                -trunkType=>6,
                -mtp2Rate=>7,
                -framing=>8,
                -lineEncoding=>9,
                -e1Crc4Checking=>10,
                -t1SignalStrength=>11,
                -autoAlarm=>12,
        },
        -mtp2Link => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -trunkName=>4,
                -timeSlot=>5,
                -protocolType=>6,
                -timerProfileName=>7,
                -linkSpeed=>8,
                -errorCorrectionMode=>9,
                -loopBackCheckMode=>10,
        },
        -mtp2SignalingLink => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -activationType=>4,
                -linkSet=>5,
                -slc=>6,
                -sltPeriodicTest=>7,
                -srtPeriodicTest=>8,
                -blockMode=>9,
                -inhibitMode=>10,
                -level2LinkType=>11,
                -level2Link=>12,
        },
        -mtp2SignalingLinkSet => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -activationType=>4,
                -type=>5,
                -nodeName=>6,
                -destination=>7,
                -autoSlt=>8,
        },
    );

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $check_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missiing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( scalar(keys %check_hash) >=3 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find an attribute key.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    my $attr_name;                # attribute name like 'state' , 'mode' etc
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {
            unless ( $tbl_attr_info{-$check_hash{-table}}{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Can't find '$attr_name' in the $check_hash{-table} table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Getting the requested information through getSS7TableInfo
    #****************************************************

    my @get_results;
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getSS7TableInfo(-table=>$check_hash{-table}, -all=>$check_hash{-all}) ;
    } else {
        @get_results = $self->getSS7TableInfo(-table=>$check_hash{-table}, -name=>$check_hash{-name});
    }

    if ( ( @get_results==1 ) && !$get_results[0] ) {
        defined $check_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $check_hash{-table} table data\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $check_hash{-name} data from the $check_hash{-table} table");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        defined $check_hash{-all} ?
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $check_hash{-table} table data\(-all\)."):
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $check_hash{-name} data from the $check_hash{-table} table");
    }

    my $column_number;            # the column number for each attribute;

    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {

            $column_number = $tbl_attr_info{-$check_hash{-table}}{$attr_name};

            $attr_name =~ s/-//;        # removing '-' for debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the $check_hash{-table} table's $attr_name values=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the $check_hash{-name}'s $attr_name value=\"$check_hash{-$attr_name}\" in the $check_hash{-table}.");

            foreach (@get_results) {
                my  @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to match \"$check_hash{-$attr_name}\" as $info_ary[0]'s '$attr_name' status=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }

            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  All the items' $attr_name values=\"$check_hash{-$attr_name}\" in the $check_hash{-table} table."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  The $check_hash{-name}'s $attr_name value =\"$check_hash{-$attr_name}\" in the $check_hash{-table} table.");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success - the checked results matched all the specified conditions.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}


=head2 inhibitSS7Route()

DESCRIPTION:
This function sets a ss7 route to the inhibit mode.

=over

=item ARGUMENTS:

 The ss7 route name.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->inhibitSS7Route( "ss7route1");

=back 

=cut

sub inhibitSS7Route {

    my ($self,$route_name) = @_;
    my $sub_name = "inhibitSS7Route";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    my (@route_buf,$route_mode);

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    unless ( $route_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory route_name input is blank or missing.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }


    #****************************************************
    # step 2: Checking if the route is in the table and the mode is 'normal' or not;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the route $route_name in the ss7 route table.");
    unless ($self->execCliCmd("show table ss7 route")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute 'show table ss7 route' --\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    

    foreach ( @{$self->{CMDRESULTS}} ) {
        @route_buf=split /\s+/;
        if($route_buf[0] eq $route_name) {
            $route_mode=$route_buf[7];            # get the route mode
            last;
        }
    }

    unless ($route_mode) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find the $route_name route in the ss7 route table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # The route mode is either in 'normal' or 'inhibit';
    unless ($route_mode eq "normal" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The SS7 route $route_name is already in the inhibit mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    #****************************************************
    # step 3: Setting the route to inhibit;
    #****************************************************

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Setting the ss7 route $route_name to the inhibit mode.");
    unless ($self->execCliCmd("set ss7 route $route_name routeMode inhibit")){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to inhibit the $route_name route--\n@{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
    }
    unless ($self->execCliCmd("commit")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the SS7 route\($route_name\) to inhibit.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");
    return 1;
}

=head2 unInhibitSS7Route()

DESCRIPTION:
 This function sets a ss7 route to the normal (un-inhibit) mode.

=over 

=item ARGUMENTS:

 The ss7 route name.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 - fail
 1 - success

=item EXAMPLE:

 $obj->unInhibitSS7Route("ss7route1");

=back 

=cut

sub unInhibitSS7Route {

    my ($self,$route_name) = @_;
    my $sub_name = "unInhibitSS7Route";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    my (@route_buf,$route_mode);

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( $route_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory route name is blank or missing.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    #****************************************************
    # step 2: Checking if the route is in the table and the mode is 'inhibit' or not;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the route $route_name in the ss7 route table.");

    unless ($self->execCliCmd("show table ss7 route")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute 'show table ss7 route' --\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    foreach ( @{$self->{CMDRESULTS}} ) {
        @route_buf=split /\s+/;
        if($route_buf[0] eq $route_name) {
            $route_mode=$route_buf[7];
        }
    }

    unless ($route_mode) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find the $route_name route in the ss7 route table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    unless ( $route_mode eq "inhibit") {
        $logger->error(__PACKAGE__ . ".$sub_name:  The SS7 route $route_name is already in the normal\(un-inhibit\) mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    #****************************************************
    # step 3: Setting the route to the normal mode;
    #****************************************************

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Setting the $route_name route to the un-inhibit mode.");

    unless ($self->execCliCmd("set ss7 route $route_name routeMode normal")){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to set the $route_name route to normal--\n@{$self->{CMDRESULTS}}");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    unless ($self->execCliCmd("commit")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the $route_name route to the normal mode.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");
    return 1;
}

=head2 C< createSS7Route >

DESCRIPTION:
 This function is to create an ss7 route for a given destination. There are two types of routes available for the configuration: m3uaAsp or mtp.
 The default route mode is set to normal (un-inhibit).

=over 

=item ARGUMENTS:

     -name            - Mandatory route name.
       -destination   - Mandatory, this object indicates the name of the associated destination.
       -linkSetName   - Mandatory, this object indicates the linkset name that is used for this route.
       -priority      - Mandatory, this object indicates the priority assigned to this route (1-8).
       -typeOfRoute   - Mandatory, this object indicates the type of the route(m3uaAsp or mtp).
       -routeMode     - Optional, this object indicates the mode of the destination (inhibit or normal).
NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->createSS7Route (-name=>"sigtran1Route",-linkSetName=>"asterixUkmgts251",-typeOfRoute=>"m3uaAsp",-priority=>2, -destination=> "sgxSigtran1" );

=back 

=cut

sub createSS7Route {
    my ($self,%input_hash) = @_;
    my $sub_name = "createSS7Route";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ( "-name", "-typeOfRoute", "-linkSetName", "-priority", "-destination" ) {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory '$_' input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( $input_hash{-typeOfRoute} =~ /^(m3uaAsp|mtp)$/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not recognise -typeOfRoute:$input_hash{-typeOfRoute}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    unless ( $input_hash{-priority}>=1 and $input_hash{-priority}<=8 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  the priority's value should be between 1 and 8:$input_hash{-priority}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    unless ( length($input_hash{-name}) <=24 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  the name length is larger than 24 characters: $input_hash{-name}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    #****************************************************
    # step 2: Setting SS7 route
    #****************************************************

    my @cmd;

    $logger->debug(__PACKAGE__ . ".$sub_name:  Creating the ss7 route\($input_hash{-name}\) for the destination\($input_hash{-destination}\) with linkset=$input_hash{-linkSetName}.");

    @cmd = (
        "set ss7 route $input_hash{-name} linkSetName $input_hash{-linkSetName} typeOfRoute $input_hash{-typeOfRoute} priority $input_hash{-priority} destination $input_hash{-destination}",
        "set ss7 route $input_hash{-name} state enabled",
        "set ss7 route $input_hash{-name} mode inService"
    );
    
    # checking if the optional input route mode is specified or not;
    # otherwise, appending it to the command line;

    if ( defined $input_hash{-route_mode} ) {
        unless ( $input_hash{-route_mode} =~ /^(inhibit|normal)$/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not recognise -routeMode:$input_hash{-route_mode}.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
        $cmd[0] .=" routeMode $input_hash{-route_mode}";
    }
    
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    foreach (@cmd) {
        unless ($self->execCliCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute $_--\n@{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
        unless ($self->execCliCmd("commit")) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created the $input_hash{-typeOfRoute} $input_hash{-name} ss7 route for the dest=$input_hash{-destination} and linkset=$input_hash{-linkSetName}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");
    return 1;
}

=head2 createSS7Destination()

DESCRIPTION:
This function is to create an ss7 destination for a given node.

=over 

=item ARGUMENTS:

Mandatrory:
     -name            - Mandatory ss7 destination name.
      -destinationType - Mandatory,the destinations type data can be configured with one of the following types:remote, cluster, adjacent, internal.
       -isupProfile     - Mandatory,this object indicates the ISUP profile name that is attached to this destination to handle various ISUP messages/procedures.
       -node            - Mandatory,this object indicates the name of the associated local SS7 node.
       -pointCode       - Mandatory,this object indicates the point code value of the destination that shall be configured as per point code format element.
Optional:
      -signallingPointType -  Signalling Point Type. Value can be either "stp" or "sep". Mandatory for Japan Profile.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

     $obj->createSS7Destination( -name => "sgxDestination1",
                                 -node => "sgxSigtran1",
                                 -pointCode => "10-22-1", 
                                 -destinationType  => "remote", 
                                 -isupProfile => "defaultANSI",
                                 -signallingPointType => "stp");

=back 

=cut

sub createSS7Destination {

    my ($self,%input_hash) = @_;
    my $sub_name = "createSS7Destination";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-node","-name","-pointCode","-destinationType","-isupProfile") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( $input_hash{-isupProfile} =~ /default(ITU|JAPAN|ANSI)/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not recognise the isupProfile value:$input_hash{-isupProfile}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    unless ( $input_hash{-destinationType} =~ /(remote|cluster|adjacent|internal)/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not recognise the destinationType value: $input_hash{-destinationType}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    unless ( length($input_hash{-name}) <=24 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  the name length is larger than 24: $input_hash{-name}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    my @cmd;
    if ( defined $input_hash{-signallingPointType} ) {
        unless ( $input_hash{-signallingPointType} =~ /s[te]p/ ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  The signallingPointType is neither \"stp\" nor \"sep\" \n");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
             return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Creating the $input_hash{-name} destination\(local node=$input_hash{-node},pointcode=$input_hash{-pointCode} , signallingPointType =$input_hash{-signallingPointType}\) ).");
        @cmd = (
            "set ss7 destination $input_hash{-name} node $input_hash{-node} pointCode $input_hash{-pointCode} destinationType $input_hash{-destinationType} isupProfile $input_hash{-isupProfile} signallingPointType $input_hash{-signallingPointType}",
            "set ss7 destination $input_hash{-name} state enabled",
            "set ss7 destination $input_hash{-name} mode inService",
        );
    }

    #****************************************************
    # step 2: Setting SS7 destination node
    #****************************************************
    unless ( defined $input_hash{-signallingPointType} ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Creating the $input_hash{-name} destination\(local node=$input_hash{-node},pointcode=$input_hash{-pointCode}\).");
        @cmd = (
            "set ss7 destination $input_hash{-name} node $input_hash{-node} pointCode $input_hash{-pointCode} destinationType $input_hash{-destinationType} isupProfile $input_hash{-isupProfile}",
            "set ss7 destination $input_hash{-name} state enabled",
            "set ss7 destination $input_hash{-name} mode inService",
        );
    }
    
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    foreach (@cmd) {
        unless ($self->execCliCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to set the $input_hash{-name} destination --\n@{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
        unless ($self->execCliCmd("commit")) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created the $input_hash{-name} ss7  destination for the local node:$input_hash{-node}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");
    return 1;
}


=head2 setStateModeAttr()

DESCRIPTION:

This function is to process the mode and state attribute settings, used by enableState(),disableState(),activateMode() and deactivateMode().
It firstly invokes the related get-functions to check if the named state or mode status matches the expected status.
If the match checking is unsuccessful,this fucntion will set the state or mode to the value as required.

=over 

=item ARGUMENTS:

    -name        - Mandatory, a specific item in the table.
    -table_dir    - Mandatory table directory information. 

    another key is either -mode or -state; its value could be: inService/outOfService, enabled/disabled;
    -mode
OR    
    -state

 The -table_dir contains a table's category and type information. For example, if the CLI command is: 'show table m3ua sgpLink',
 then the -table_dir value is "m3ua/sgpLink".

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkM3UAInfo;
 SonusQA::SGX4000::checkSUAInfo;
 SonusQA::SGX4000::checkSS7TableInfo;
 SonusQA::SGX4000::checkM2PAInfo;
 SonusQA::SGX4000::checkSCTPAssoc;

=item OUTPUT:

 0 - fail;
 1 - success;

=item EXAMPLE:

    $obj->setStateModeAttr( -table_dir=>"sua/sgpLink",-name=>"sgplink11",-mode=>"outOfService") ) {

=back 

=cut

sub setStateModeAttr {

    my ($self,%input_hash) = @_;
    my $sub_name = "setStateModeAttr";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-table_dir","-name") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory '$_' input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }


    # Get the attribute key;
    my $attr_name=undef;
    foreach ( keys %input_hash ) {
        if ( ! /-(table_dir|name)/ ) {
            $attr_name=$_;                # To get the attribute name like 'mode' or 'state';
            last;
        }
    }

    # Checking if the expected attribute key is given or not;
    unless ( defined $attr_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Can't find the expected attribute keys: -mode or -state.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    #****************************************************
    # step 2: Adding the CLI comamnd with arguments
    #****************************************************

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    my @tbl_dir=split /\//, $input_hash{-table_dir};
    $attr_name =~ s/-//;        # remove '-';

    my $cmd = "set";

    # Adding command parameters....

    foreach (@tbl_dir) { $cmd.=" $_"; }
    $cmd .= " $input_hash{-name} $attr_name $input_hash{-$attr_name}";
    #          ^^^^^^^^^^^^^^^^  ^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^
    #         table name         state/mode  en/disabled or in/outOfService

    unless ($self->execCliCmd($cmd)) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Could not set $input_hash{-name}'s $attr_name to '$input_hash{-$attr_name}' --\n@{$self->{CMDRESULTS}}");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    unless ($self->execCliCmd("commit")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set $input_hash{-name}'s $attr_name to '$input_hash{-$attr_name}'.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");
    return 1;
}

=head2 enableState()

DESCRIPTION:
 This function sets a table item's state to the enabled status.

=over

=item ARGUMENTS:

    -name        - Mandatory, a specific item (eg an asplink name) in the table,
    -category    - Mandatory table category, values are like "m3ua", "sua" and "sigtran",
     -table        - Mandatory table name (such as sgpLink, sctpAssociation and aspLink etc),

NOTE: 
 None

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::setStateModeAttr;

=item OUTPUT:

 0 - fail;
 1 - success;

=item EXAMPLE:

    $obj->enableState(-category=>"sua",-table=>"sgpLink", -name=>"sgplink1");

=back 

=cut

sub enableState {
    my ($self,%enable_input_hash) = @_;
    my $sub_name = "enableState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-category","-table","-name") {
        unless ( $enable_input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Enabling 'state' status
    #****************************************************

    # enabling state;
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering setStateModeAttr to enable $enable_input_hash{-name}");
    unless ( $self->setStateModeAttr( -table_dir=>"$enable_input_hash{-category}/$enable_input_hash{-table}",-name=>$enable_input_hash{-name},-state=>"enabled") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enable the $enable_input_hash{-name} state.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the $enable_input_hash{-name}'s state to 'enabled'.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}


=head2 disableState()

DESCRIPTION:
 This function sets a table item's state to the disabled status (eg a sgp link).

=over 

=item ARGUMENTS:

    -category    - Mandatory table category, values include "m3ua", "sua" and "sigtran".
     -table        - Mandatory table name (eg sgpLink, sctpAssociation and aspLink).
    -name        - Mandatory, a specific item(eg an sgplink name) in the table

NOTE: 
 None

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::setStateModeAttr;

=item OUTPUT:

 0 - fail;
 1 - success;

=item EXAMPLE:

    $obj->disableState(-category=>"sua",-table=>"sgpLink", -name=>"sgplink1");

=back 

=cut

sub disableState {
    my ($self,%disable_input_hash) = @_;
    my $sub_name = "disableState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-category","-table","-name") {
        unless ( $disable_input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }
    #****************************************************
    # step 2: Disabling 'state' status
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering setStateModeAttr to disable $disable_input_hash{-name}.");
    unless ( $self->setStateModeAttr( -table_dir=>"$disable_input_hash{-category}/$disable_input_hash{-table}",-name=>$disable_input_hash{-name},-state=>"disabled") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to set the $disable_input_hash{-name}'s state to 'disabled'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }    

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the $disable_input_hash{-name}'s state to 'disabled'.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}

=head2 activateMode()

DESCRIPTION:

This function sets a table item's mode to the inService status, which is opposite to the deactivateMode function.

=over 

=item ARGUMENTS:

    -name        - Mandatory, a specific item in the table.
    -category    - Mandatory table category, values are like "m3ua", "sua" and "sigtran".
     -table        - Mandatory table name.

NOTE: 
 None

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::setStateModeAttr;

=item OUTPUT:

 0 - fail;
 1 - success;

=item EXAMPLE:

    $obj->activateMode(-category=>"sua",-table=>"sgpLink", -name=>"sgplink1");

=back 

=cut

sub activateMode {
    my ($self,%activate_input_hash) = @_;
    my $sub_name = "activateMode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-category","-table","-name") {
        unless ( $activate_input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is  missing or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Activating 'mode' status
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering setStateModeAttr to activate $activate_input_hash{-name}.");
    unless ( $self->setStateModeAttr( -table_dir=>"$activate_input_hash{-category}/$activate_input_hash{-table}",-name=>$activate_input_hash{-name},-mode=>"inService") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to set $activate_input_hash{-name}'s mode to 'inService'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the $activate_input_hash{-name}'s mode to 'inService'.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}


=head2 deactivateMode()

DESCRIPTION:

This function sets a table item's mode to the outOfService status, which is opposite to the activateMode function.

=over 

=item ARGUMENTS:

    -name        - Mandatory, a specific item (eg an sgplink name) in the table
    -category    - Mandatory table category, values are like "m3ua", "sua" and "sigtran".
     -table        - Mandatory table name (eg sgpLink, sctpAssociation and aspLink).

NOTE: 
 None

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::setStateModeAttr;

=item OUTPUT:

 0 - fail;
 1 - success;

=item EXAMPLE:

    $obj->deactivateMode(-category=>"sua",-table=>"sgpLink", -name=>"sgplink1");

=back 

=cut

sub deactivateMode {
    my ($self,%deactivate_input_hash) = @_;
    my $sub_name = "deactivateMode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ("-category","-table","-name") {
    unless ( $deactivate_input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Error: '$_' input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Setting mode to outOfService;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering setStateModeAttr to deactivate $deactivate_input_hash{-name}.\n");

    unless ( $self->setStateModeAttr( -table_dir=>"$deactivate_input_hash{-category}/$deactivate_input_hash{-table}",-name=>$deactivate_input_hash{-name},-mode=>"outOfService") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to deactivate $deactivate_input_hash{-name}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the $deactivate_input_hash{-name}'s mode to 'outOfService'.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}


=head2 retrieveConfigurationTableData()

DESCRIPTION:
 This function is to retrieve the table information used by getM3UAInfo, getSUAInfo, getSCTPAssoc and getSCTPAssocStatus subs.

 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

     -name     - Optional, if we want to get a specfic item's information, this option should be provided.
     -all    - Optional, if we want to get the whole table's information, this option should be provided.
     -table_dir    - Mandatory table directory information. 

 The -table_dir contains a table's category and table name. For example, if the CLI command is: 'show table m3ua sgpLink',
 then the -table_dir value is "m3ua/sgpLink".


NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1) 0 - fail; 
 2) @retrieved_results: an array contains the retrieved table results according the get request. 

 Note that if the table is empty, 0 will be returned.

=item EXAMPLE:

    1) $obj->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociationStatus",-name=>"asterixGW11");
    2) $obj->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociationStatus",-all=>1 );

=back 

=cut

sub retrieveConfigurationTableData {
    my ($self,%input_hash) = @_;
    my $sub_name = "retrieveConfigurationTableData";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");
    
                    
    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");

    unless ( $input_hash{-table_dir} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory -table_dir input is missing or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
    }
    

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $input_hash{-name} xor exists $input_hash{-all} ) {
        if ( exists $input_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $input_hash{-all} ) {
        unless ( $input_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-all' value is not equal to 1:$input_hash{-all}.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $input_hash{-name} ) {
        unless ( $input_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Retrieving config information;
    #****************************************************

    my @tbl_dir;
    my $cmd="show table";    

    foreach ( @tbl_dir = split (/\//, $input_hash{-table_dir} )) {
        $cmd .=" $_";
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  executing '$cmd'");
    unless ($self->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute $cmd --\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }


    #****************************************************
    # step 3: To check if the table is empty or not;
    #****************************************************

    my $tbl_line;                 # store each line of a table;
    my $content_flag =0;        # the flag to indicate if the line contains table content  or not;
    my @retrieved_results;        # store the table content expect the table header and tail;
    
    foreach $tbl_line( @{$self->{CMDRESULTS}} ) {
        
        if ( $content_flag ) { 
            # Donot copy '[ok]' starting lines.
            if ( $tbl_line !~ /^\[ok\]/ ) { 
                push @retrieved_results,$tbl_line;      
            }
        }
        if (!$content_flag) {
            if ( $tbl_line =~ /^--------/ ) { 
                $content_flag = 1;    # start to copy the table afterh the '------' seperation line;
                }
        }
    }

    # If the table is empty, '0' is returned.
    unless ( @retrieved_results ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The table is empty:$tbl_dir[-1].");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    #****************************************************
    # step 4: To process -name option (including regex)
    #****************************************************

    if (defined $input_hash{-name} ) {

        # Checking if the input contains the regular expression like '/asterix/'.
        if ( $input_hash{-name} =~ /\/(\S+)\// ) {
            my $grep_name = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name:  Checking the table with '$input_hash{-name}'.");

            # The regex(grep_name) should be from the first column; So, ^ is needed. 
            # Before the regex, there could be any letters or none of letters.

            @retrieved_results=grep( /^(\S+|)$grep_name/ , @{$self->{CMDRESULTS}} );  # support multiple matches;

            # Printing message for debug logs.
            if ( @retrieved_results ) {
                my $matching_name;
                foreach ( @retrieved_results ) {
                    $matching_name=(split /\s+/,$_)[0];
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Found the name=$matching_name matching with '$input_hash{-name}' in the table.");
                }
            }
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the '$input_hash{-name}' data from the $tbl_dir[-1] table.");
            @retrieved_results=grep(/^$input_hash{-name}\s+/,@{$self->{CMDRESULTS}});  # searching the specific item according to the given name;
        }

        # if the retrieved result is empty, 0 is returned.
        unless ( @retrieved_results ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieved result is empty,could not find '$input_hash{-name}' in the $tbl_dir[1] table.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    defined ( $input_hash{-all} ) ?
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved all the $tbl_dir[-1] table data\(-all\)."):
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $input_hash{-name} data from the $tbl_dir[-1] table.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return @retrieved_results;
}


=head2 getSUAInfo()

DESCRIPTION:
 This function gets the information from the sua tables of sgpLink or sgpLinkStatus.
 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

     -type    - Mandatory table name, its value could be sgpLink or sgpLinkStatus.
     -name     - Optional, if we want to get a specfic item's information, this option should be provided.
     -all    - Optional, if we want to get the whole table's information, this option should be provided.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

  0 - fail.
  @get_results: an array contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getSUAInfo(-table=>"sgpLink", -name =>"sgplink11" );
  2) $obj->getSUAInfo(-table=>"sgpLink", -all => 1 );

=back 

=cut

sub getSUAInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getSUAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $get_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: To get info through retrieveConfigurationTableData;
    #****************************************************

    my @get_results;
    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"sua/$get_hash{-table}", -all=>$get_hash{-all}  );
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"sua/$get_hash{-table}", -name=>$get_hash{-name});
    }

    if ( (@get_results==1) && !$get_results[0] ) {
        defined $get_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-table} table data\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-name} data from the $get_hash{-table} table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        defined $get_hash{-all} ?
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully got the $get_hash{-table} table data\(-all\)."):
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully got the $get_hash{-name} data from the $get_hash{-table} table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    defined $get_hash{-all} ?
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-table} table data\(-all\)."):
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-name} data from the $get_hash{-table} table.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}

=head2 checkSUAInfo()

DESCRIPTION:
This function checks the named attribute status for SUA tables.
 1) If the -all key is presented,it checks the whole table for the named attributes.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over 

=item ARGUMENTS:

     -table      - Mandatory table name, values are sgpLink,sgpLinkStatus,aspLink,aspLinkStatus and asplinkSet);
     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkSUAInfo;

=item OUTPUT:

  0 - false ( the results do not match the requirements).
  1 - true  ( the results match the requirements).
 -1 - error (eg cli error).

=item EXAMPLE:

  1) $obj->checkSUAInfo(-table=>"sgpLink", -name=>"asterixGW11",-mode=>"outOfService");
  2) $obj->checkSUAInfo(-table=>"sgpLink", -name=>"asterixGW11",-mode=>"outOfService",-state=>"enabled");
  3) $obj->checkSUAInfo(-table=>"sgpLink", -name=>"/asterixGW1/",-mode=>"outOfService");
  4) $obj->checkSUAInfo(-table=>"sgpLink", -all=>1, -mode=>"outOfService");

=back 

=cut

sub checkSUAInfo {

    my ($self, %check_hash) = @_;
    my $sub_name = "checkSUAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
        -sgpLink => {
                     -index => 1,
                     -state => 2,
                     -mode =>3,
                     -sctpAssociationName =>4,
                     -periodicHeartbeat => 5,
                },
        -sgpLinkStatus => {
                    -state => 1,
                    -mode => 2,
                    -sctpAssociationName =>3,
                    -status =>4,
                },
        );

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( $check_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory name is is missing or blank. ");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( scalar(keys %check_hash) >=3 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find any attribute key.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    my $attr_name;                # attribute name like 'state' , 'mode' etc
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {
            unless ( $tbl_attr_info{-$check_hash{-table}}{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Could not find '$attr_name' in the $check_hash{-table} table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Getting the requested information through getSUAInfo
    #****************************************************

    my @get_results;
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getSUAInfo(-table=>$check_hash{-table}, -all=>$check_hash{-all} );
    } else {
        @get_results = $self->getSUAInfo(-table=>$check_hash{-table}, -name=>$check_hash{-name});
    }

    # checking if the return is 0;
    if ( (@get_results==1) && !$get_results[0] ) {
        defined $check_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the table data\(-all\):$check_hash{-table}."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $check_hash{-name} data from the $check_hash{-table} table.");
        
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        defined $check_hash{-all} ?
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the table data\(-all\):$check_hash{-table}."):
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the $check_hash{-name} data from the $check_hash{-table} table.");
    }

    #****************************************************
    # step 2: Checking the attributes
    #****************************************************

    my $column_number;            # the column number for each attribute;
    my @info_ary;

    foreach $attr_name ( keys %check_hash ) {

        if ( $attr_name !~ /(-table|-name|-all)/ ) {
            $column_number = $tbl_attr_info{-$check_hash{-table}}{$attr_name}; # get the column number of each attribute;

            $attr_name =~ s/-//;        # removing '-' for the debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the SUA $check_hash{-table} table's '$attr_name' values=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the SUA $check_hash{-table} $check_hash{-name}'s '$attr_name' value=\"$check_hash{-$attr_name}\".");

            foreach (@get_results) {
                @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected \"$check_hash{-$attr_name}\" as $info_ary[0]'s '$attr_name' value=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }
            defined $check_hash{-all} ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: all the SUA $check_hash{-table} table's '$attr_name' values=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: the SUA $check_hash{-table} $check_hash{-name}'s '$attr_name' value=\"$check_hash{-$attr_name}\".");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success: the checked results matched all the conditions.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}


=head2 getM3UAInfo()

DESCRIPTION:
This function is simply to get the information from M3UA tables including aspLinkSet, aspLink, aspLinkStatus, sgpLink and sgpLinkStatus.

 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

     -table    - Mandatory table name, values are sgpLink, aspLink,sgpLinkStatus, aspLinkset and aspLinkStatus.
     -name     - Optional, if we want to get a specfic item's information, this option should be provided.
     -all    - Optional, if we want to get the whole table's information, this option should be provided.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

  0 - fail.
  @get_results: an array contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getM3UAInfo(-table=>"sgpLink", -name =>"sgplink11" );
  2) $obj->getM3UAInfo(-table=>"sgpLink", -all => 1 );

=back 

=cut

sub getM3UAInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getM3UAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( $get_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank. ");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    my @get_results;

    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"m3ua/$get_hash{-table}", -all=>$get_hash{-all});
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"m3ua/$get_hash{-table}", -name=>$get_hash{-name});
    }

    if ( (@get_results==1) && !$get_results[0] ) {
        defined $get_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-table} table data\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the $get_hash{-name} data from the $get_hash{-table} table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        defined $get_hash{-all} ?
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully got the $get_hash{-table} table data\(-all\)."):
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully got the $get_hash{-name} data from the $get_hash{-table} table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}


=head2 checkM3UAInfo()

DESCRIPTION:

This function checks the named attribute status for M3UA tables.
 1) If the -all key is presented,it checks the whole table for the named attributes.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over 

=item ARGUMENTS:

     -table       - Mandatory m3ua table name, values are sgpLink,sgpLinkStatus,aspLink,aspLinkStatus and asplinkSet;
     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkM3UAInfo;

=item OUTPUT:

  0 - false ( the results do not match the requirements).
  1 - true  ( the results match the requirements).
 -1 - error (eg cli error).

=item EXAMPLE:

    1) $obj->checkM3UAInfo(-table=>"aspLink", -name=>"asterixMgts11",-mode=>"outOfService");
    2) $obj->checkM3UAInfo(-table=>"aspLink", -name=>"asterixMgts11",-mode=>"outOfService",-state=>"enabled");
    3) $obj->checkM3UAInfo(-table=>"aspLink", -name=>"/asterixMgts1/",-mode=>"outOfService");
    4) $obj->checkM3UAInfo(-table=>"aspLink", -all=>1, -mode=>"outOfService");

=back

=cut

sub checkM3UAInfo {

    my ($self, %check_hash) = @_;
    my $sub_name = "checkM3UAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
        -aspLinkSet=> {
                    -index => 1,
                    -state => 2,
                    -mode  => 3,
                    -nodeName => 4,
                    -nodeIndex => 5,
                    -dynamicRegistration => 6,
                    -routingContextTableName => 7,
                    -remoteHostName => 8,
                },
        -aspLink => {
                    -index => 1,
                    -state => 2,
                    -mode => 3,
                    -m3uaAspLinkSetName => 4,
                    -sctpAssociationName => 5,
                    -periodicHeartbeat => 6,
                },
        -aspLinkStatus => {
                    -state => 1,
                    -mode => 2,
                    -m3uaAspLinkSetName => 3,
                    -sctpAssociationName => 4,
                    -status => 5,
                },
        -sgpLink => {
                     -index => 1,
                     -state => 2,
                     -mode =>3,
                     -sctpAssociationName =>4,
                     -periodicHeartbeat => 5,
                },
        -sgpLinkStatus => {
                    -state => 1,
                    -mode => 2,
                    -sctpAssociationName =>3,
                    -status =>4,
                },
        );

    #****************************************************
    # step 1: Checking arguments
    #****************************************************

    unless ( $check_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} eq "1" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the number of keys is larger than 2. ( -table, -name , -attr_name);

    unless ( scalar(keys %check_hash) >=3 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find an attribute key.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    my $attr_name;                # attribute name like 'state' , 'mode' etc

    foreach $attr_name ( keys %check_hash ) {
        if ($attr_name !~ /(-table|-name|-all)/) {
            unless ( $tbl_attr_info{-$check_hash{-table}}{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Could not find $attr_name in the $check_hash{-table} table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Checking arguments
    #****************************************************

    my @get_results;        
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getM3UAInfo(-table=>$check_hash{-table}, -all=>$check_hash{-all}) ;
    } else {
        @get_results = $self->getM3UAInfo(-table=>$check_hash{-table}, -name=>$check_hash{-name});
    }

    if ( (@get_results==1) && !$get_results[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the data from the $check_hash{-table} table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        defined $check_hash{-all} ?
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the $check_hash{-table} table data \(-all\)."):
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the $check_hash{-table} table data \($check_hash{-name}\).");
    }

    #****************************************************
    # step 3: Checking the attributes
    #****************************************************

    my $column_number;            # the column number for each attribute;
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {
            $column_number = $tbl_attr_info{-$check_hash{-table}}{$attr_name};

            $attr_name =~ s/-//;        # removing '-' for debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the items' $attr_name values=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the $check_hash{-name}'s $attr_name value=\"$check_hash{-$attr_name}\".");

            foreach (@get_results) {
                my  @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to match \"$check_hash{-$attr_name}\" as $info_ary[0]'s '$attr_name' status=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }

            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  success: all the items' $attr_name value=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  success: the $check_hash{-name}'s $attr_name value=\"$check_hash{-$attr_name}\".");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success - the checked results matched the specified conditions.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}

=head2 getSCTPAssocInfo()

DESCRIPTION:
This function is simply to get the sctpAssocation table information.
 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

  There is only one input which is either '-name' or '-all'. 

  If we want to get the whole table's information, the '-all=>1' input should be provided.
  Otherwise, if we want to get a specific sctp assocation's information, the '-name' input should be specified.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

  0 - fail.
  @get_results: an array contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getSCTPAssocInfo( -name =>"asterixGsxOscar11" );
  2) $obj->getSCTPAssocInfo( -all => 1 );

=back 

=cut

sub getSCTPAssocInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getSCTPAssocInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $get_hash{-name} or defined $get_hash{-all}) {
        $logger->error(__PACKAGE__ . ".$sub_name:  None of the '-name' and '-all' inputs is given.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Entering retrieveConfigurationTableData....
    #****************************************************

    my @get_results;

    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociation",-all=>$get_hash{-all} );
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociation", -name=>$get_hash{-name} );
    }

    #****************************************************
    # step 3: Checking the return array;
    #****************************************************
    if ( (@get_results==1) && !$get_results[0] ) {
        defined $get_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the sctpAssociation table data \(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the $get_hash{-name} data from the sctpAssociation table.");
            
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        defined $get_hash{-all} ?
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the sctpAssociation table data\(-all\)."):
            $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the $get_hash{-name} data from the sctpAssociation table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}


=head2 checkSCTPAssoc()

DESCRIPTION:
This function checks the named attribute status for the sctpAssociation table.
 1) If the -all key is presented,it checks the whole table for the named attributes.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over 

=item ARGUMENTS:

     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkSCTPAssoc;

=item OUTPUT:

  0 - false ( the results do not match the requirements).
  1 - true  ( the results match the requirements).
 -1 - error ( eg cli error).

=item EXAMPLE:

    1) $obj->checkSCTPAssoc(-name=>"asterixMgts11",-mode=>"outOfService",-state=>"enabled");
    2) $obj->checkSCTPAssoc(-name=>"/asterixMgts1/",-mode=>"outOfService");
    3) $obj->checkSCTPAssoc(-all=>1, -mode=>"outOfService",-state=>"enabled");

=back

=cut

sub checkSCTPAssoc {
    my ($self, %check_hash) = @_;
    my $sub_name = "checkSCTPAssoc";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
            -index => 1, 
            -state => 2,
            -mode => 3,
            -localIpAddress1 => 4,
            -localIpAddress2 => 5,
            -localPort => 6,
            -remoteIpAddress1 => 7,
            -remoteIpAddress2 => 8,
            -remotePort => 9,
            -maxInboundStream => 10,
            -maxOutboundStream => 11,
            -sctpProfileName => 12,
            -connectionMode  => 13,
        );

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( scalar(keys %check_hash) >1 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find an attribute key.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    my $attr_name;                # attribute name like 'state' , 'mode' etc

    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-name|-all)/ ) {
            unless ( $tbl_attr_info{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Error:please check the input:$attr_name, as it can't be found in the sctpAssociation table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Entering getSCTPAssocInfo to get sctpAssocation table information
    #****************************************************

    my @get_results;
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering getSCTPAssocInfo sub.");
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getSCTPAssocInfo(-all=>$check_hash{-all});
    } else {
        @get_results = $self->getSCTPAssocInfo(-name=>$check_hash{-name});
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking the return value from getSCTPAssocInfo.");
    if ( (@get_results==1) && !$get_results[0] ) {
        defined $check_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the data from the sctpAssocation table\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the data from the sctpAssocation table\($check_hash{-name}\).");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        defined $check_hash{-all} ?
            $logger->info(__PACKAGE__ . ".$sub_name:  Got the data from the sctpAssocation table\(-all\)."):
            $logger->info(__PACKAGE__ . ".$sub_name:  Got the data from the sctpAssocation table\($check_hash{-name}\).");
    }


    #****************************************************
    # step 3: Checking if the current attribute setting is true or false
    #****************************************************

    my $column_number;            # the column number for each attribute;
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-name|-all)/ ) {

            $column_number = $tbl_attr_info{$attr_name};

            $attr_name =~ s/-//;        # removing '-' for debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the item's $attr_name value=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the $check_hash{-name}'s $attr_name value=\"$check_hash{-$attr_name}\".");

            foreach (@get_results) {
                my  @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to match \"$check_hash{-$attr_name}\" as the $info_ary[0]'s $attr_name value=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }

            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  success - all the items' $attr_name values=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  success - the $check_hash{-name}'s $attr_name value=\"$check_hash{-$attr_name}\".");
        }
    }

    defined ( $check_hash{-all} ) ?
        $logger->debug(__PACKAGE__ . ".$sub_name:  Success - all the checked results matched the specified requirements\(-all\)."):
        $logger->debug(__PACKAGE__ . ".$sub_name:  Success - the checked result matched the specified requirement.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}


=head2 getSCTPAssocStatusInfo

DESCRIPTION:
This function is simply to get the sctpAssocationStatus table information.
 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

  There is only one input which either is '-name' or '-all'. 
  If we want to get the whole table's information, the '-all' input should be provided (set to 1). 
  Otherwise, if we want to get a specific assocation status information, the '-name' input should be specified.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

  0 - fail.
  @get_results: an array contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getSCTPAssocStatusInfo( -name =>"asterixGsxOscar11" );
  2) $obj->getSCTPAssocStatusInfo( -all => 1 );

=back 

=cut

sub getSCTPAssocStatusInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getSCTPAssocStatusInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }


    #****************************************************
    # step 2: Retrieving table information through "retrieveConfigurationTableData"
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering retrieveConfigurationTableData sub.");

    my @get_results; # store the return table information;
    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociationStatus", -all=>$get_hash{-all} );
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir=>"sigtran/sctpAssociationStatus",-name=>$get_hash{-name} );
    }

    #****************************************************
    # step 3: Checking if the return value
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the returning value from retrieveConfigurationTableData is error or the table information.");
    if ( (@get_results==1) && !$get_results[0] ) {
        defined $get_hash{-all} ? 
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the sctpAssociationStatus table data\(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the $get_hash{-name} data from the sctpAssocationStatus table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        defined $get_hash{-all} ? 
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully retrieved the sctpAssociationStatus table data\(-all\)."):
            $logger->info(__PACKAGE__ . ".$sub_name:  Successfully retrieved the $get_hash{-name} data from the sctpAssocationStatus table.");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}

=head2 checkSCTPAssocStatus()

DESCRIPTION:
This function checks the named attribute status for the sctpAssociationStatus table.
 1) If the -all key is presented,it checks the whole table for the named attributes.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over 

=item ARGUMENTS:

     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkSCTPAssocStatus;

=item OUTPUT:

  0 - false ( the results do not match the checking requirements).
  1 - true  ( the results match the checking requirements).
 -1 - error ( eg cli error).

=item EXAMPLE:

    1) $obj->checkSCTPAssocStatus(-name=>"asterixMgts11",-mode=>"outOfService",-state=>"enabled");
    2) $obj->checkSCTPAssocStatus(-name=>"/asterixMgts1/",-mode=>"outOfService");
    3) $obj->checkSCTPAssocStatus(-all=>1, -mode=>"outOfService",-state=>"enabled");

=back 

=cut

sub checkSCTPAssocStatus {
    my ($self, %check_hash) = @_;
    my $sub_name = "checkSCTPAssocStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
        -sctpStatus => 1,
        -primaryPathPort => 2,
        -primaryPathIp => 3,
        -currentPathIp => 4, 
        -currentPathPort => 5,
        -maxOutboundStream => 6,
    );

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( scalar(keys %check_hash) >1 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Error: the attribute field is missing.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }


    my $attr_name;                # attribute name like 'state' , 'mode' etc
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-name|-all)/ ) {
            unless ( $tbl_attr_info{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Error:please check the input:$attr_name, as it can't be found in the sctpAssociationStatus table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Entering getSCTPASsocationStatusInfo ....
    #****************************************************

    my @get_results;
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entering getSCTPAssocStatusInfo to retrieve table.");
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getSCTPAssocStatusInfo(-all=>$check_hash{-all});
    } else {
        @get_results = $self->getSCTPAssocStatusInfo(-name=>$check_hash{-name});
    }

    $logger->error(__PACKAGE__ . ".$sub_name:  Checking if the return value is error or the table information.");
    if ( (@get_results==1) && !$get_results[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the requested information fom the sctpAssociationStatus table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        unless ( @get_results ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Got empty result from getSCTPAssocInfo.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
            return -1;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the requested information from the sctpAssociationStatus table.");
    }

    #****************************************************
    # step 3: Checking if the attribute status is true or false.
    #****************************************************

    my $column_number;            # the column number for each attribute;
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-name|-all)/ ) {

            $column_number = $tbl_attr_info{$attr_name};
            $attr_name =~ s/-//;        # removing '-' for debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the sigtran sctpAssocationStatus table's '$attr_name' status=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the sigtran sctpAssociationStatus:$check_hash{-name}'s '$attr_name' status=\"$check_hash{-$attr_name}\".");

            foreach (@get_results) {
                my  @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to match \"$check_hash{-$attr_name}\" as $info_ary[0]'s '$attr_name' status=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }

            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: all the sctpAssociationStatus table's '$attr_name' status=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: The sigran sctpAssociationStatus:$check_hash{-name}'s '$attr_name' status=\"$check_hash{-$attr_name}\".");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success: the checking results matched all the requirements.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}

=head2 createM2PALink()

DESCRIPTION:
 This function simply creates an m2pa link based on the given sctp assocation connection. 

=over 

=item ARGUMENTS:

     -name  -  Optional m2pa link name . By default, the link name will be the same as the SCTP assoc. name.
     -sctpAssociationName -  Mandatory sctp association name
     -m2paTimerProfile      -  Optional timer profile input.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createM2PAlink( -sctpAssociationName => "m2paAssoc1" );
 OR
    $obj->createM2PAlink( -sctpAssociationName => "m2paAssoc1",-name=>"m2palink1" );

=back 

=cut

sub createM2PALink {
    my ( $self, %link_hash ) = @_ ;
    my $sub_name = "createM2PALink";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    unless ( $link_hash{-sctpAssociationName} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory sctpAssociationName input is missing.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Configuring M2PA link
    #****************************************************

    # Checking if link name is given or not;

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring m2pa link:assoc=$link_hash{-sctpAssociationName}.");
    unless ( $link_hash{-name} ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Setting m2pa link name to:$link_hash{-sctpAssociationName}.");
        $link_hash{-name}=$link_hash{-sctpAssociationName};  # set the link name=assoc name
    }

    # Checking if the m2pa timer profile is specified;
    unless ( defined $link_hash{-m2paTimerProfile} ) {
            $link_hash{-m2paTimerProfile}="default";  # if not specified, it is set to default;
    }

    my  @cmd=(
        "set m2pa link $link_hash{-name} m2paTimerProfile $link_hash{-m2paTimerProfile} sctpAssociationName $link_hash{-sctpAssociationName}",
        "set m2pa link $link_hash{-name} state enabled",
        "set m2pa link $link_hash{-name} mode in",
    );

    foreach (@cmd) {
        chomp();
        unless ($self->execCommitCliCmdConfirm("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created the m2pa link $link_hash{-name} on the $link_hash{-sctpAssociationName} sctp assocation.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}


=head2 createSS7T1E1Board()

DESCRIPTION:
 This function simply creates an ss7 board for the named CE.

=over 

=item ARGUMENTS:

    -name                     - Mandatory, the board name;
    -boardNumber            - Mandatory, this object indicates the board number.
    -ceName                 - Mandatory, this object indicates the configured CE name.
    -clockSourceExternal    - Optional, this object indicates the type of the source of the clock.
    -clockSourceTrunk       - Optional, this object indicates the trunk number that supplies reference clock to the board.
    -independentClockTrunks - Optional, this object indicates the bitmask represenation of trunk number that has independent clocking.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createSS7T1E1Board( -name=>"board0",-ceName=>"asterix",-boardNumber=>1);

=back 

=cut

sub createSS7T1E1Board {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createSS7T1E1Board";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ("-name","-ceName","-boardNumber") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Configuring SS7 t1e1 board
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SS7 t1e1Board for $input_hash{-ceName}.");

    my  @cmd=(
        "set ss7 t1e1Board $input_hash{-name}",
        "set ss7 t1e1Board $input_hash{-name} state enabled",
        "set ss7 t1e1Board $input_hash{-name} mode in",
        );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name") {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created an SS7 board on $input_hash{-ceName}:board name=$input_hash{-name},board number=$input_hash{-boardNumber}");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}

=head2 createSS7T1E1Trunk()

DESCRIPTION:
 This function simply creates an ss7 trunk based on the name ss7 board. 
 One ss7 board supports up to 8 ss7 trunk numbers.

=over 

=item ARGUMENTS:

    -name              - Mandatory trunk name.
    -framing          - Mandatory, this object indicates the framing type supported for different types of trunks.
    -lineEncoding     - Mandatory, this object indicates the line encoding type supported for different types of trunks.
    -t1e1BoardName    - Mandatory, this object indicates the existing T1/E1 board name.
    -trunkNumber      - Mandatory, this object indicates the configured trunk number.
    -trunkType        - Mandatory, this object indicates the type of the trunk.
    -autoAlarm        - Optional, this object indicates auto alarm setting.
    -e1Crc4Checking   - Optional, this object indicates whether this trunk is configured with CRC4 checking or not.
    -mtp2Rate         - Optional, this object indicates the speed of the MTP2 trunk.
    -t1SignalStrength - Optional, this object indicates the setting for the transmit equalization according to the transmit distance for a T1 line.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createSS7T1E1Trunk(-name=>"trunk0",-t1e1BoardName=>"board1",-trunkNumber=>2, -trunkType=>"typeT1", -framing=>"esfFraming",-lineEncoding=>"b8zs");

=back 

=cut

sub createSS7T1E1Trunk {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createSS7T1E1Trunk";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ("-name","-t1e1BoardName","-trunkNumber","-framing","-lineEncoding") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Configuring SS7 t1e1 trunk
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SS7 t1e1Trunk $input_hash{-name} for t1e1 board $input_hash{-t1e1BoardName}.");

    my  @cmd=(
        "set ss7 t1e1Trunk $input_hash{-name}",
        "set ss7 t1e1Trunk $input_hash{-name} state enabled",
        "set ss7 t1e1Trunk $input_hash{-name} mode in",
        );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name") {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created an trunk for the SS7 board\($input_hash{-t1e1BoardName}\):name=$input_hash{-name},trunk number=$input_hash{-trunkNumber}");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}

=head2 createSS7MTP2Link()

DESCRIPTION:
This function is to create an mtp2 link based on the named trunk name.

=over 

=item ARGUMENTS:

    -name                 - Mandatory mtp2 link name;
    -linkSpeed           - Mandatory, this object refers to the type of the speed of this link.
    -protocolType        - Mandatory, this object indicates the SS7 protocol type configured.
    -timeSlot            - Mandatory, this object indicates time slot configured for this link.
    -timerProfileName    - Mandatory, this object indicates the name of the associated MTP2 timer profile.
    -trunkName           - Mandatory, this object indicates the trunk name configured for this link.
    -errorCorrectionMode - Optional, this object indicates the type of error correction configured.
    -loopBackCheckMode   - Optional, this object indicates the type of loop back configured for this MTP2 link.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createSS7MTP2Link(-name=>"asterixMtp2Link1",-timerProfileName=>"defaultANSI",-trunkName=>"trunk0",-timeSlot=>1,-linkSpeed=>"speed64kbps",-protocolType=>"ansi");

=back 

=cut

sub createSS7MTP2Link {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createSS7MTP2Link";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ("-name","-timerProfileName","-trunkName","-timeSlot","-linkSpeed","-protocolType"){
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************
    # step 2: Configuring the ss7 mtp2 link
    #****************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SS7 MTP2 link $input_hash{-name} on trunk $input_hash{-trunkName}.");

    my  @cmd=(
        "set ss7 mtp2Link $input_hash{-name}",
        "set ss7 mtp2Link $input_hash{-name} state enabled",
        "set ss7 mtp2Link $input_hash{-name} mode in",
        );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name") {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured an mtp2 link\(type=$input_hash{-protocolType},trunk=$input_hash{-trunkName}\): $input_hash{-name}");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}

=head2 createSS7MTP2SignalingLinkSet()

DESCRIPTION:
This function creates an ss7 mtp2 signaling linkset for the specified ss7 node.
After creating a linkset, its mode will be not activated as there is no link assocaited with this linkset yet.

=over 

=item ARGUMENTS:

    -name            - Mandatory mtp2 signaling linkset name.
    -nodeName       - Mandatory,this object indicates the name of the associated local SS7 node.
    -destination    - Mandatory,this object refers to a remote destination that can be reached via this link set.
    -activationType - Mandatory,this object indicates the type of the activation of MTP2 based signaling link.
    -type           - Mandatory,this object indicates the type of the link. Possible values: linkTypeA, linkTypeB, linkTypeD,linkTypeE, linkTypeF
    -autoSlt        - Optional, this object indicates whether the automatic SLT is done after initial alignment: Possible values: true, false

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createSS7MTP2SignalingLinkSet(-name=>"mtp2SignalingLink1",-activationType=>"normal", -destination=>"stpMgts1", -nodeName=>"sgxDastardlyMuttley",-type=>"linkTypeA");

=back 

=cut

sub createSS7MTP2SignalingLinkSet {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createSS7MTP2SignalingLinkSet";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ( "-name", "-nodeName", "-destination", "-activationType", "-type") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Configuring ss7 mtp2 signaling link
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SS7 MTP2 signaling linkset $input_hash{-name}");

    my  @cmd=(
        "set ss7 mtp2SignalingLinkSet $input_hash{-name}",
        "set ss7 mtp2SignalingLinkSet $input_hash{-name} state enabled",
        );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name") {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created the MTP2-Sig LinkSet\($input_hash{-name}\) between the local node\($input_hash{-nodeName}\) and the destination\($input_hash{-destination}\).");
    $logger->debug(__PACKAGE__ . ".$sub_name:  But,its mode is not activated as there is no link configured yet.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}


=head2 createSS7MTP2SignalingLink()

DESCRIPTION:

This function is to create an mtp2 signaling link based on the specified mtp2 link and linkset.
The mtp2 link be either an mtp2 link or an m2pa link. 

=over 

=item ARGUMENTS:

    -name             - Mandatory,mtp2 signaling link name.
    -activationType  - Mandatory,this object indicates the activation type of the MTP2 based signaling link, its value could be normal or emergence.
    -level2Link      - Mandatory,this object indicates the name of the associated MTP2 link or M2PA link.
    -level2LinkType  - Mandatory,this object refers to a level 2 link type, its value is either mtp2 or m2pa.
    -linkSet         - Mandatory,this object indicates the name of the associated MTP2 signaling link set.
    -slc             - Mandatory,this object indicates the SLC of the link:
    -blockMode       - Optional, this object indicates block mode setting, its value is either on or off.
    -inhibitMode     - Optional, this object indicates inhibit mode setting, its value is either on or off..
    -sltPeriodicTest - Optional, the flag to indicate whether periodic SLT test procedure of MTP protocol is enabled or disabled.
    -srtPeriodicTest - Optional, the flag to indicate whether periodic signaling routing test procedure of MTP protocol is enabled or disabled.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->createSS7MTP2SignalingLink(-name=>"mtp2SignalingLink1",-activationType=>"normal",-level2Link=>"asterixMtp2Link1",-level2LinkType=>"mtp2",-linkSet=>"mtp2LinkSet1",-slc=>"0");

=back 

=cut

sub createSS7MTP2SignalingLink {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createSS7MTP2SignalingLink";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    # note -slc's value could be zero, so $input_hash{-slc} could be empty when it is actually 0;

    foreach ( "-name", "-activationType", "-level2Link", "-level2LinkType", "-linkSet", "-slc" ) {
        unless ( defined $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Configuring ss7 mtp2 signaling link
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Configuring SS7 MTP2 signaling link $input_hash{-name}");

    my  @cmd=(
        "set ss7 mtp2SignalingLink $input_hash{-name}",
        "set ss7 mtp2SignalingLink $input_hash{-name} state enabled",
        "set ss7 mtp2SignalingLink $input_hash{-name} mode in",
        );

    # Adding args .....
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name") {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created the MTP2-Sig Link\($input_hash{-name}\) with the $input_hash{-level2Link}\($input_hash{-level2LinkType}\) link.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  
}

=head2 C< configureSS7MTP2SignalingLink >

DESCRIPTION:
 This function configures a group of mtp2 signaling links accorinding to the given a linkset.

=over 

=item ARGUMENTS:

    -prefix             - Mandatory prefix name for mtp2 signaling links.
    -activationType  - Mandatory, this object indicates the activation type of the MTP2 based signaling link.
    -level2Link      - Mandatory, this object indicates the name of the associated MTP2 link or M2PA link.
    -level2LinkType  - Mandatory, this object refers to a level 2 link type.
    -linkSet         - Mandatory, this object indicates the name of the associated MTP2 signaling link set.
    -slc             - Mandatory, this object indicates the SLC of the link:
    -blockMode       - Optional,  this object indicates block mode setting.
    -inhibitMode     - Optional,  this object indicates inhibit mode setting.
    -sltPeriodicTest - Optional,  the flag to indicate whether periodic SLT test procedure of MTP protocol is enabled or disabled.
    -srtPeriodicTest - Optional,  the flag to indicate whether periodic signaling routing test procedure of MTP protocol is enabled or disabled.

 1) To allow this function to configure multiple signaling links, the '-slc', '-level2Link' and '-level2LinkType' inputs accept multiple values seperated by ','; For example: 
        -level2Link=>"mtp2link1,mtp2link2,mtp2link3" , -level2LinkType=>"m2pa,mtp2,mtp2" and -slc=>"2,3,5"
    The above means that there are three level 2 links where:
        mtp2link1 is the m2pa type and its expected slc number is 2;
        mtp2link2 is the mtp2 type and its expected slc number is 3;
        mtp2link3 is the mtp2 type and its expected slc number is 5;

 2) The -prefix input gives the prefix link name. The rest of the link name is specified by index numbers. This function checks the ss7 mtp2SignalingLink table and calculates the number of link names that match with the prefix name specified in '-prefix'. This number will be used as the index number.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::createSS7MTP2SignalingLink();

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    $obj->configureSS7MTP2SignalingLink(-prefix=>"mtp2SigLink",-activationType=>"normal",-level2Link=>"mtp2Link1,mtp2Link2,mtp2Link3",-level2LinkType=>"m2pa,mtp2,mtp2",-linkSet=>"mtp2LinkSet1",-slc=>"0,1,2";

=back 

=cut

sub configureSS7MTP2SignalingLink {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "configureSS7MTP2SignalingLink";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    my ($sig_link_index,@index_ary,$linkset_mode,@cmd);

    #****************************************************
    # step 1: Preparing configurations (eg parameters checking)
    #****************************************************

    foreach ( "-prefix", "-activationType", "-level2Link", "-level2LinkType", "-linkSet", "-slc" ) {
        unless ( defined $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 2: Checking the linkset mode 
    #         & calculating the signaling link index number;
    #****************************************************

    unless ( $self->execCliCmd("show table ss7 mtp2SignalingLinkSet") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute the command --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    foreach ( @{$self->{CMDRESULTS}} ) {
        if (/$input_hash{-linkSet}\s+\d+\s+\w+\s+(inService|outOfService)\s+/) {
        #                                          ^^^^^^^^$1=mode^^^^^^^
            $linkset_mode=$1;
        }
    }

    unless ( $self->execCliCmd("show table ss7 mtp2SignalingLink") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute the command --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    # checking if there is any link name that matches with the -prefix input.
    foreach (@{$self->{CMDRESULTS}}) {
        # searching: link name + index number
        if ( /$input_hash{-prefix}(\d+)\s+/ ) {
                push @index_ary,$1;    
        }
    }

    $sig_link_index=0;        #  initialisation of index = 0;

    # Checking if the index array is not empty;
    if ( @index_ary) {
        $sig_link_index=( sort {$a<=>$b} @index_ary)[-1]; # sort index array and get the largest index number;
        $sig_link_index++;
    }

    #****************************************************
    # step 3: Retrieving the mtp2link names and slc numbers
    #****************************************************

    # Retrieving the slc numbers and link names

    my @level2_link_name=split(/,/,$input_hash{-level2Link}) ;

    my @level2_link_type=split(/,/,$input_hash{-level2LinkType}) ;

    my @slc_number=split(/,/,$input_hash{-slc});
    my @link_names;        # to store how many links have been configured;

    unless ( $#level2_link_name eq $#slc_number ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The slc number\($#slc_number\) is not equal to the number of the given level2 link number\($#level2_link_name\)."); 
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    # Adding args into the cmd hash ......
    my %cmd_hash;
    foreach ( keys %input_hash ) {
        unless ( /^(-prefix|-slc|-level2Link|-level2LinkType)$/ ) {
            $cmd_hash{$_}=$input_hash{$_};
        }
    }


    #****************************************************
    # step 3: Configuring ss7 mtp2 signaling link
    #****************************************************

    for (0..$#level2_link_name) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Creating the $input_hash{-prefix}$sig_link_index MTP2 signaling link with $level2_link_name[$_]\(type=$level2_link_type[$_]\)."); 
        unless ( $self->createSS7MTP2SignalingLink( -name=>"$input_hash{-prefix}$sig_link_index",
                                        -level2Link=>"$level2_link_name[$_]",
                                        -level2LinkType=>"$level2_link_type[$_]",
                                        -slc=>"$slc_number[$_]",
                                        %cmd_hash
                                     ) ) 
        {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to create mtp2 signaling link:$input_hash{-prefix}$sig_link_index");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }

        push @link_names,"$input_hash{-prefix}$sig_link_index";        # the input -prefix + index
        $sig_link_index++;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured a group of MTP2-Sig Links\(@link_names\) within the $input_hash{-linkSet} linkset.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}

=head2 getM2PAInfo()

DESCRIPTION:
This function is simply to get the attribute information from m2pa tables.
 1) with the -all key: it returns the whole table.
 2) with the -name key: it returns the table line whose first column exactly matches the specified -name value.
 3) with the -name key and the regex format: it returns all the table lines whose names (first column) match the given regex.

 Note: when it returns the whole table, it does not include the table header and tail.

=over 

=item ARGUMENTS:

    -type    - Mandatory table name (eg link)
    -name     - Optional, if we want to get a specfic item's information in the table, this option should be provided.
    -all    - Optional, if we want to get the whole table's information, this option should be provided.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::retrieveConfigurationTableData;

=item OUTPUT:

  0 - fail.
  @get_results: an array contains the retrieved data from the table.

=item EXAMPLE:

  1) $obj->getM2PAInfo(-table=>"link", -name =>"M2PALink1" );
  2) $obj->getM2PAInfo(-table=>"link", -all => 1 );

=back 

=cut

sub getM2PAInfo {
    my ($self,%get_hash) = @_;
    my $sub_name = "getM2PAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $get_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'defined' returns a boolean value (true or false), therefore XOR can be used here.

    unless ( exists $get_hash{-name} xor exists $get_hash{-all} ) {
        if ( exists $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $get_hash{-all} ) {
        unless ( $get_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect usuage: the '-all' value is $get_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $get_hash{-name} ) {
        unless ( $get_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: To get info through retrieveConfigurationTableData;
    #****************************************************

    my @get_results;
    if ( defined $get_hash{-all} ) {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"m2pa/$get_hash{-table}", -all=>$get_hash{-all}  );
    } else {
        @get_results = $self->retrieveConfigurationTableData( -table_dir =>"m2pa/$get_hash{-table}", -name=>$get_hash{-name});
    }

    if ( (@get_results==1) && !$get_results[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the requested information from the $get_hash{-table} table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the requested information from the $get_hash{-table} table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
        return @get_results;
    }

    $logger->error(__PACKAGE__ . ".$sub_name:  Could not get the requested information from the $get_hash{-table} table.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}

=head2 checkM2PAInfo()

DESCRIPTION:
This function checks the named attribute values of an M2PA table.
 1) If the -all key is presented,it checks the whole table for the named attributes.
 2) If the -name key is presented, it checks the named attributes only with the table line whose first column exactly matches the specified -name value.
 3) If the -name key is presented with the regex format, it checks the named attributes with all the table lines whose names (first column) match the regex.

=over 

=item ARGUMENTS:

 An hash input including the following keys:
     -table       - Mandatory table name,its value could be route, destination, node.
     -attr_name - Mandatory table attribute names and relevant attribute values (eg. for -attr_name=state, the value could be "enabled" or "disabled").
     -name      - Optional, the table item/key name that the function is going to check.
     -all        - Optional, the whole table will be checked if -all is given.

 Note that the -name input supports the regular expression.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::checkM2PAInfo;

=item OUTPUT:

  0 - false ( the results do not match the requirements).
  1 - true  ( the results match the requirements).
 -1 - error ( eg cli error ).

=item EXAMPLE:

  1) $obj->checkM2PAInfo(-table=>"link", -name=>"M2PALink1" , -mode=>"outOfService");
  2) $obj->checkM2PAInfo(-table=>"link", -name=>"/M2PALink/", -mode=>"outOfService");
  3) $obj->checkM2PAInfo(-table=>"link", -all=>1, -mode=>"outOfService");

=back 

=cut

sub checkM2PAInfo {
    my ($self, %check_hash) = @_;
    my $sub_name = "checkM2PAInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # The column number for each attribute in the table,
    my %tbl_attr_info = (
        -link => {
                -index=>1,
                -state=>2,
                -mode=>3,
                -sctpAssociationName=>4,
                -m2paTimerProfile=>5,
        },
    );

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    unless ( defined $check_hash{-table} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory table name is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    # Checking if: 1) both -name and -all keys are presented ; 2) none of them is presented;
    # 'exists' returns the boolean value (true or false), therefore XOR can be used here.

    unless ( exists $check_hash{-name} xor exists $check_hash{-all} ) {
        if ( exists $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Both '-name' and '-all' keys exist, only one of them is allowed.");
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  None of the key '-name' or '-all' exists, one of them needs to be specified.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }

    # Checking if the key -all's value =1;

    if ( defined $check_hash{-all} ) {
        unless ( $check_hash{-all} == 1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Incorrect value: the '-all' input equals $check_hash{-all} as its value should be 1.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    # Checking if the key -name's value is empty or not;
    if ( exists $check_hash{-name} ) {
        unless ( $check_hash{-name} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The '-name' value should not be empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    unless ( scalar(keys %check_hash) >=3 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not find an attribute key.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return -1;
    }

    my $attr_name;                # attribute name like 'state' , 'mode' etc
    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {
            unless ( $tbl_attr_info{-$check_hash{-table}}{$attr_name} ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Error:please check the input:$attr_name, as it can't be found in the $check_hash{-table} table.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
                return -1;
            }
        }
    }

    #****************************************************
    # step 2: Getting the requested information through getM2PAInfo
    #****************************************************

    my @get_results;
    if ( defined $check_hash{-all} ) {
        @get_results = $self->getM2PAInfo(-table=>$check_hash{-table}, -all=>$check_hash{-all}) ;
    } else {
        @get_results = $self->getM2PAInfo(-table=>$check_hash{-table}, -name=>$check_hash{-name});
    }

    if ( ( @get_results==1 ) && !$get_results[0] ) {
        defined $check_hash{-all} ?
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $check_hash{-table} table data \(-all\)."):
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the $check_hash{-table} table data \($check_hash{-all}\).");

        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
        return -1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully got the requested informatoin from the $check_hash{-table} table.");
        unless ( @get_results ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The get result is empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [-1]");
            return -1;
        }
    }

    my $column_number;            # the column number for each attribute;

    foreach $attr_name ( keys %check_hash ) {
        if ( $attr_name !~ /(-table|-name|-all)/ ) {

            $column_number = $tbl_attr_info{-$check_hash{-table}}{$attr_name};

            $attr_name =~ s/-//;        # removing '-' for debug message output;
            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if all the SS7 $check_hash{-table} table's '$attr_name' value=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the SS7 $check_hash{-table}:$check_hash{-name}'s '$attr_name' value=\"$check_hash{-$attr_name}\".");

            foreach (@get_results) {
                my  @info_ary = split(/\s+/, $_);
                if ( $info_ary[$column_number] ne "$check_hash{-$attr_name}" ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to match \"$check_hash{-$attr_name}\" as the current $info_ary[0]'s '$attr_name' value=\"$info_ary[$column_number]\".");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                    return    0;
                }
            }

            defined ( $check_hash{-all} ) ?
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: All the SS7 $check_hash{-table} table's '$attr_name' value=\"$check_hash{-$attr_name}\"."):
                $logger->debug(__PACKAGE__ . ".$sub_name:  Success: The SS7 $check_hash{-table}:$check_hash{-name}'s '$attr_name' value=\"$check_hash{-$attr_name}\".");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success: the checking results matched all the requirements.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return    1;
}

=head2 createTableKey()

DESCRIPTION:
 This is a generic function to create a key (item) for the given table. It only requires two inputs: the input of table information and the key name input.
 It also supports the creation of a linkset whose initial mode often should be in the outOfService status.

=over 

=item ARGUMENTS:

    An hash input including the following keys:
    -table_dir       - Mandatory table information including the table category and type;
    -name            - Mandatory table key name;
    -without_mode    - Optional, when it is set to 1, the mode setting will be igored;
                      Otherwise (if it equals 0), the mode will be set to 'inService'.
    others:  the inputs to specify an item in the table.

  Note, the other input key name (without '-') is required as the same with the CLI name.

=item PACKAGE:

 SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 0 -  fail; 
 1 -  success;

=item EXAMPLE:

    1) $obj->createTableKey(-table_dir=>"m2pa/link",-name=>"m2paLink1",-sctpAssociationName=>"asterixUkmgts251");
    2) $obj->createTableKey(-table_dir=>"ss7/mtp2SignalingLinkSet",-name=>"mtp2SigLinkSet1",-without_mode=>1,-activationType=>"normal", -destination=>"mgts1", -nodeName=>"asterixNode1",-type=>"linkTypeA");

=back

=cut

sub createTableKey {
    my ($self,%input_hash) = @_ ;
    my $sub_name = "createTableKey";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");


    #****************************************************
    # step 1: Checking mandatory inputs
    #****************************************************

    foreach ("-name","-table_dir") {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is missing.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    #****************************************************
    # step 2: Checking the table dir information;
    #****************************************************

    my ($category,$type) = split (/\//,$input_hash{-table_dir}) ;

    $logger->debug(__PACKAGE__ . ".$sub_name:  Creating the $input_hash{-name} key in the $category\/$type table.");

    my  @cmd=(
        "set $category $type $input_hash{-name}",
        "set $category $type $input_hash{-name} state enabled",
        );

    # If the -without_mode is specified, the mode setting command is not added in @cmd;
    unless ( defined $input_hash{-without_mode} ) {
        $cmd[2]="set $category $type $input_hash{-name} mode inService";
    }

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( ! /^(-name|-table_dir|-without_mode)$/ ) {
            s/-//;
            $cmd[0].=" $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    #****************************************************
    # step 3: Leaving the config mode;
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    defined $input_hash{-without_mode} ?
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created an key\($input_hash{-name}\) in the $category $type table, but its mode is NOT activated."):
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully created an key\($input_hash{-name}\) in the $category $type table");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;  

}

=head2 retrieveSystemName()

DESCRIPTION:
 This function simply retrieves the system name from the system admin table.

=over 

=item ARGUMENTS:

 None;

NOTE: 
 None

=item PACKAGE:

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  $system_name - the system name

=item EXAMPLE:

  $obj->retrieveSystemName;

=back 

=cut

sub retrieveSystemName {
    my ($self) = @_ ;
    my $sub_name = "retrieveSystemName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Retrieving system name...
    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name from the system admin table.");
    unless ( $self->execCliCmd("show table system admin") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not show system admin table --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    my $system_name = undef;
    foreach (@{$self->{CMDRESULTS}}) {
        if (/^(\S+)\s+\S+\s+\S+\s+\d+\s+/) {
        #     ^^^^^  
        # $1=sys name    
            $system_name=$1;
            last;
        }    
    }
    
    unless ( defined $system_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Can't retrieve the system name from the system admin table.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved the system name:$system_name.");
    return $system_name;
}

=head2 execSystemCliCmd()

DESCRIPTION:

This function is a wrapper to execute a system or server admin command through CLI. It checks the (yes/no) after issuing a system command. If the prompt is (yes/no), this function will issue 'yes' and then it will check the [ok] and [error] messages. Note that the screen width should be set to 512, otherwise the '(yes/no)' prompt may be splitted into different lines.

=over 

=item ARGUMENTS:

The system or server admin CLI command.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  For example, to execute a system restart command
  $obj->execSystemCliCmd("request system admin SGX_asterix_obelix restart");

=back 

=cut

sub execSystemCliCmd {
    my  ($self, $cmd ) = @_ ;
    my  $sub_name = "execSystemCliCmd";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub_name: Executing the system command:'$cmd'");
    
    unless ( $self->{conn}->print( $cmd ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue $cmd" );
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
    }

    # wait for (yes/no), [ok] or [error].

    my ($prematch, $match);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/yes.no/i',
                                                           -match     => '/\[error\]/',
                                                           -match     => '/\[ok\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ($prematch =~ m/Stopping user sessions during sync phase/i) {
        ($prematch, $match) = $self->{conn}->waitfor( -match     => '/\(yes\/no\)/',
                                                      -match     => '/\[error\]/',
                                                      -match     => $self->{PROMPT});
    }

    if ( $match =~ m/yes.no/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Got match '$match'.");

        unless ( $self->execCliCmd("yes") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'Yes' resulted in error -- \n@{$self->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }

        my $failure_flag=0;
        foreach ( @{$self->{CMDRESULTS}} ) {
            chomp;
            if( /result\s+failure/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Result failure after typing 'yes'.");
                $failure_flag=1;
            }
            if ( $failure_flag &&  /^reason/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  The failure message is:'$_'");
                last;
            }
        }

        if ( $failure_flag ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    elsif ( $match =~ m/\[error\]/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute '$cmd'.\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        push( @{$self->{CMDRESULTS}}, $prematch );
        # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
        # next call to execCmd        
        $self->{conn}->waitfor( -match => $self->{PROMPT} );
        return 0;
    }
    elsif ( $match =~ m/\[ok\]/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched [ok]");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 switchoverCE()

DESCRIPTION:
 This function simply performs the system switchover functionality.

=over 

=item ARGUMENTS:

 Optional :
 1. type       - "forced" can be passed as argument, if required.
 2. waitFSOver - 1, if waiting for switch over to complete is required before exiting the API. 

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->switchoverCE();
OR
  $obj->switchoverCE(-type => "forced" , -waitFSOver => 1 );

=back 

=cut

sub switchoverCE {
    my ( $self, %args) = @_;
    my $sub_name = "switchoverCE";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( defined $args{-waitFSOver}) {
        $args{-waitFSOver} = 0;
    }
    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing switchover from the '$self->{OBJ_HOSTNAME}' CE.");

    my $cmd="request system admin $system_name switchover";


    #From: Nimmagadda, Gautham 
    #Sent: 24 January 2012 22:00
    #To: Ross, Alan
    #Subject: RE: request system admin SGX_astrix_obelix switchover type

    #In the older releases, this option would cause the switchover even if the sync is in progress. But later deprecated that option because softReset achieves the same functionality.

    #Thanks,
    #Gautham

   # commenting the type argument forever due to deprecated further

    # Checking if the type input is empty or not, otherwise, it will be appended into $cmd;
   # if (defined $args{-type} ) {
   #     $cmd .=" type $args{-type}";
   # } 



    unless ( $self->execSystemCliCmd("$cmd") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to perform switchover from '$self->{OBJ_HOSTNAME}'--\n@{$self->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    #wait for switch over to complete.
    if ( $args{-waitFSOver} == 1  ) {
        my ($prematch, $match);
        my $sgxIp = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
        unless(($prematch, $match) = $self->{conn}->waitfor(-match     => '/Connection to '.$sgxIp.' closed/',
                                                        -Timeout   => 7 )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Switchover from '$self->{OBJ_HOSTNAME}'was not done in 7 seconds. Connection was not closed in 7 seconds");
        }
       $logger->debug(__PACKAGE__ . ".$sub_name: sleeping for a sec");
       sleep (1); 
    } 
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the switchover on the system: $system_name.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  All the connection will be closed with the CE:$self->{OBJ_HOSTNAME}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 restartSystem()

DESCRIPTION:
 This function simply performs the system restart functionality, which will firstly stop all the applications on the system and then reboot the whole system ( eg all the CE servers).

=over 

=item ARGUMENTS:

 None

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->restartSystem();

=back 

=cut

sub restartSystem {
    my $self = shift ;
    my $sub_name = "restartSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing system restart from '$self->{OBJ_HOSTNAME}'.");

    my $cmd="request system admin $system_name restart";

    unless ( $self->execSystemCliCmd("$cmd") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to restart system from the CE:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the restart command on the $system_name system from $self->{OBJ_HOSTNAME}.");
    $logger->warn(__PACKAGE__ . ".$sub_name:   All the applications will be stopped and the servers will be rebooted.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 softResetSystem()

DESCRIPTION:
 This function simply performs the system softReset functionality. This function only soft resets the system (will not reboot the CE servers).

=over 

=item ARGUMENTS:

 1. waitFSReset - ( Optional ) if this argument is passed with value 1 , then the API waits for the soft reset to complete and
                   hence returns success if Connection is closed in 7 seconds.
                   If not passed or passed with value 0 , API will not wait for Soft reset to complete.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->softResetSystem( );
  $obj->softResetSystem( -waitFSReset => 1);

=back 

=cut

sub softResetSystem {
    my ($self, %args) = @_ ;
    my $sub_name = "softResetSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( defined $args{-waitFSReset}) {
        $args{-waitFSReset} = 0;
    }
    
    # Retrieving system name...
    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing softReset from '$self->{OBJ_HOSTNAME}'.");
    my $cmd="request system admin $system_name softReset";
    unless ( $self->execSystemCliCmd("$cmd") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to softReset system from the CE:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    #wait for soft reset to complete.
    if ( $args{-waitFSReset} == 1  ) {
        my ($prematch, $match);
        my $sgxIp = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
        unless(($prematch, $match) = $self->{conn}->waitfor(-match     => '/Connection to '.$sgxIp.' closed/',
                                                        -Timeout   => 7 )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Soft reset from '$self->{OBJ_HOSTNAME}'did not happen in 7 seconds. Connection was not closed in 7 seconds");
        } 
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the system softReset command from the CE:$self->{OBJ_HOSTNAME}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 loadSystemConfig()

DESCRIPTION:
 This function simply performs the system loadConfig functionality. It will firstly load saved SGX configuration and then restarts the system without rebooting the server(s).

=over 

=item ARGUMENTS:

 None

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->loadSystemConfig();

=back 

=cut

sub loadSystemConfig {
    my ($self, %args) = @_ ;
    my $sub_name = "loadSystemConfig";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing loadConfig from '$self->{OBJ_HOSTNAME}'.");
    my $cmd;
    unless( $args{ -fileName }){
	 $cmd="request system admin $system_name loadConfig";
    }else{
	$cmd="request system admin $system_name loadConfig fileName $args{ -fileName }";
    }
    unless ( $self->execSystemCliCmd("$cmd") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to load system config from the CE:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed loadConfig from the CE:$self->{OBJ_HOSTNAME}.");
    $logger->warn(__PACKAGE__ . ".$sub_name:  The $system_name system is going to restart.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 saveSystemConfig()

DESCRIPTION:
This function simply performs the system saveConfig functionality, which is going save current SGX configuration data.

=over 

=item ARGUMENTS:

 None

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->saveSystemConfig();

=back

=cut

sub saveSystemConfig {
    my $self = shift ;
    my $sub_name = "saveSystemConfig";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my ($system_name, @cmdresults);
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing saveConfig from '$self->{OBJ_HOSTNAME}'.");
    my $cmd="request system admin $system_name saveConfig";

    unless ($self->execSystemCliCmd("$cmd") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to save system config from the CE:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

	@cmdresults=@{$self->{CMDRESULTS}};
	$logger->debug(__PACKAGE__ . ".$sub_name:  cmdresults dump is".Dumper(@cmdresults));

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the saveConfig system command from the CE:$self->{OBJ_HOSTNAME}.");
    foreach (@cmdresults){
	if($_ =~/\/.+\/(.*\.gz)$/)
	{
		$logger->debug(__PACKAGE__ . ".$sub_name:  current line is $_");
	   $logger->debug(__PACKAGE__ . ".$sub_name: Filename found : $1. ");
	   $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
	   return $1;
	}
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
}

=head2 restartCE()

DESCRIPTION:
This function simply performs the CE restart functionality, which will reboot the named CE.

=over 

=item ARGUMENTS:

Mandatory:
 1. The CE name.
Optional:
 2. "wait" - wait for Connection to be closed if the CE is active CE.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->restartCE("asterix");
or 
  $obj->restartCE("asterix", "wait");

=back 

=cut

sub restartCE {
    my ($self,$ce_name,$wait) = @_ ;
    my $sub_name = "restartCE";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory ce name is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing the CE restart:$self->{OBJ_HOSTNAME}.");

    my $cmd="request system serverAdmin $ce_name restart";
    unless ( $self->execSystemCliCmd("$cmd")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to perform the CE restart:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    # Wait for the Connection to be closed if $self is the Active CE.
    my $ceNameOfSelf = $self->{TMS_ALIAS_DATA}->{'CE'}->{'1'}->{'HOSTNAME'};
    if (defined $wait) {
        if (($wait eq "wait" ) && ( $ce_name eq $ceNameOfSelf )) {
            my ($prematch, $match);
            my $sgxIp = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
            unless(($prematch, $match) = $self->{conn}->waitfor(-match     => '/Connection to '.$sgxIp.' closed/',
                                                                -Timeout   => 10 )) {
                $logger->error(__PACKAGE__ . ".$sub_name: restartCE from '$self->{OBJ_HOSTNAME}'did not happen in 10 seconds. Connection was not closed in 10 seconds");
            }
        }
    } 

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the server restart command on $self->{OBJ_HOSTNAME}.");
    $logger->warn(__PACKAGE__ . ".$sub_name:  The $self->{OBJ_HOSTNAME} server is going to rebooted now.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 softResetCE()

DESCRIPTION:

This function simply performs the CE softReset functionality.

=over 

=item ARGUMENTS:

Mandatory: 
 1. The CE name.
Optional:
 2. "wait" - wait for Connection to be closed if the CE is active CE.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->softResetCE("asterix");
or 
  $obj->softResetCE("asterix","wait");

=back

=cut

sub softResetCE {
    my ($self,$ce_name,$wait) = @_ ;
    my $sub_name = "softResetCE";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory ce name is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Performing the CE softReset:$self->{OBJ_HOSTNAME}.");
    my $cmd="request system serverAdmin $ce_name softReset";
    unless ( $self->execSystemCliCmd("$cmd")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to perform the CE softReset:$self->{OBJ_HOSTNAME}.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    # Wait for the Connection to be closed if $self is the Active CE.
    my $ceNameOfSelf = $self->{TMS_ALIAS_DATA}->{'CE'}->{'1'}->{'HOSTNAME'};
    if (defined $wait) {
        if (($wait eq "wait" ) && ( $ce_name eq $ceNameOfSelf )) {
            my ($prematch, $match);
            my $sgxIp = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
            unless(($prematch, $match) = $self->{conn}->waitfor(-match     => '/Connection to '.$sgxIp.' closed/',
                                                                -Timeout   => 7 )) {
                $logger->error(__PACKAGE__ . ".$sub_name: Soft reset from '$self->{OBJ_HOSTNAME}'did not happen in 7 seconds. Connection was not closed in 7 seconds");
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed the server softReset on the CE:$self->{OBJ_HOSTNAME}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 startFileTransfer()

DESCRIPTION:
 This function initiates a file transfer from a specified remote location to a local SGX4000 system. The transferred file will be put in the /opt/sonus/external directory. After running this function, the transfer progress can be checked through "show table system fileTransferStatus" and, it can be stopped by running "request system admin systemName stopFileTransfer packageName".

=over 

=item ARGUMENTS:

  -from           - Mandatory remote location inforamtion to indicate from where to get the file.
                    Its value could be a host name or a decimal ip address.
  -remoteFileName - Mandatory remote file information,its value is the absolute path name of the file to transfer.
  -localFileName  - Mandatory local file information to tell what is the local file name should be used to store the transfered file. 
  -userName       - Mandatory login name for the remote host.
  -password       - Mandatory password data for the remote host.


NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->startFileTransfer(-from=>"bennevis.uk.sonusnet.com",-remoteFileName=>"/sonus/SonusNFS/SGX4000/V07.03.00A028/sgx4000-V07.03.00-A028.x86_64.tar.gz",-localFileName=>"sgx4000-V07.03.00-A028.x86_64.tar.gz",-userName=>"blai",-password=>"xxxx");

=back 

=cut

sub startFileTransfer {
    my ($self,%transfer_input_hash) = @_ ;
    my $sub_name = "startFileTransfer";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

      foreach ("-from","-remoteFileName","-localFileName","-userName","-password") {
        unless ( $transfer_input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory $_ is missing or blank.\n");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    # Retrieving system name...

    my $system_name;

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    
    my $cmd = "request system admin $system_name transferFile from $transfer_input_hash{-from} remoteFileName $transfer_input_hash{-remoteFileName} userName $transfer_input_hash{-userName} password $transfer_input_hash{-password}";

    $logger->debug(__PACKAGE__ . ".$sub_name: Initialising the file transfer.\n'$cmd'.");

    unless ( $self->execSystemCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to perform the file transfer --\n'$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed: transfer the $transfer_input_hash{-remoteFileName} file ");
    $logger->debug(__PACKAGE__ . ".$sub_name:  from $transfer_input_hash{-from} to the $system_name system ");
    $logger->debug(__PACKAGE__ . ".$sub_name:  with the local file name=$transfer_input_hash{-localFileName} by user:$transfer_input_hash{-userName}.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
}

=head2 stopFileTransfer()

DESCRIPTION:
 This function stops a file transfer if it is in progress through the system fileTransferStatus table.

=over 

=item ARGUMENTS:

 The local file name that is requied to stop transfer.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->stopFileTransfer("sgx4000-V07.03.00-A028.x86_64.tar.gz");

=back 

=cut

sub stopFileTransfer {
    my ($self,$file_name) = @_ ;
    my $sub_name = "stopFileTransfer";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory local file name is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Checking if the given file is in the transfer progress 
    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking if the file\($file_name\) is in the transfer progress.");

    unless ( $self->execCliCmd("show table system fileTransferStatus")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute 'show system fileTransferStatus' --\n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    my $local_file_matching_flag=0;
    my $transfer_progress_percentage;

    foreach (@{$self->{CMDRESULTS}}) {
        
        if (/^\S+\s+(\S+)\s+(\S+\s+){2,8}(\d+%)\s*$/) {
        #           ^^^^^    ^^^^^^^^^^^  ^^^^^^^
        #       $1=file name $2=date     $3=percentage   
            if ($1 eq $file_name) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Found the file name\($file_name\) in the system fileTransferStatus table."); 
                $logger->debug(__PACKAGE__ . ".$sub_name: And, its transfer progress=$3.");
                $local_file_matching_flag=1;
                $transfer_progress_percentage=$3;
                last;
            }
        }
    }

    # checking if the file can be found in the system table...
    unless ( $local_file_matching_flag ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The user specified file name\($file_name\) is not in the transfer progress.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    # Checking if the file's transfer has already completed.
    unless ( $transfer_progress_percentage ne "100%" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Can't stop the $file_name transfer as its transfer has already completed.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }


    # Retrieving system name...

    my $system_name;

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    

    $logger->debug(__PACKAGE__ . ".$sub_name: Stopping the $file_name file's transfer.");

    my $cmd = "request system admin $system_name stopFileTransfer localFileName $file_name";

    unless ( $self->execSystemCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed: stopped the $file_name file transfer.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}

=head2 C< removeTransferredFile >

DESCRIPTION:

 This function removes the named software package from both servers.

=over 

=item ARGUMENTS:

 The software package name that is requied to remove.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->removeTransferredFile("sgx4000-V07.03.00-A028.x86_64.tar.gz");

=back 

=cut

sub removeTransferredFile {
    my ($self,$package_name) = @_ ;
    my $sub_name = "removeTransferredFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $package_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory package name is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Removing the $package_name package.");

    my $cmd = "request system admin $system_name removeTransferredFile localFileName $package_name";

    unless ( $self->execSystemCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed: remove the $package_name package from the $system_name system.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}

=head2 startSoftwareUpgrade()

DESCRIPTION:\

 This function initiates live software upgrade with the specified package. This pacakge should be located in the /opt/sonus/external directory. The update progress can be checked through the system softwareUpgradeStatus table. It upgrades the standby CE first and then updates another CE. The system will be automatically switched over after the first CE has been upgraded.

=over 

=item ARGUMENTS:

 -package       - Mandatory software package name that will be used for upgrading.
 -revertScript  - Optional, the script to run to perform revert in case upgrade fails.
 -upgradeMode   - Optional, it indicates wether to proceed with software upgrade when running as single CE mode.
 -upgradeScript - Optional, the script to run to perform upgrade.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->startSoftwareUpgrade(-package=>"sgx4000-V07.03.00-A029.x86_64.tar.gz");

=back 

=cut

sub startSoftwareUpgrade {
    my ($self,%upgrade_hash) = @_ ;
    my $sub_name = "startSoftwareUpgrade";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $upgrade_hash{-package} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory -package input is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Upgrading the $upgrade_hash{-package} package.");

    my $cmd = "request system admin $system_name startSoftwareUpgrade package $upgrade_hash{-package}";
    
    foreach ( keys %upgrade_hash ) {
        unless ( /-package/ ) {
            s/-//g;
             $cmd .=" $_ $upgrade_hash{-$_}";
        }
    }

    unless ( $self->execSystemCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed:upgrade the package $upgrade_hash{-package} on the $system_name system.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}

=head2 revertSoftwareUpgrade()

DESCRIPTION:

 This function reverts the system to the previous software package.

=over 

=item ARGUMENTS:

 None

NOTE: 
 None

=item PACKAGE:

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SGX4000::execSystemCliCmd;

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  $obj->revertSoftwareUpgrade();

=back 

=cut

sub revertSoftwareUpgrade {
    my ($self,$revert_mode) = @_ ;
    my $sub_name = "revertSoftwareUpgrade";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( $revert_mode ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory -package input is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    # Retrieving system name...

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    my $system_name;
    unless ( $system_name=$self->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Reverting the system...");

    my $cmd = "request system admin $system_name revertSoftwareUpgrade revertMode $revert_mode";
    
    unless ( $self->execSystemCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully executed:reverte the $system_name system.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}

=head2 closeConn()
  
  $obj->closeConn();

  Overriding the Base.closeConn due to it thinking us using port 2024 means we're on the console.

=cut

sub closeConn {

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn"); 
    $logger->debug(__PACKAGE__ . ".closeConn Closing SGX4000 connection...");
 
    my ($self) = @_;

    my $key;

    foreach $key (keys %{$self->{sftp_session_for_ce}}) {
       $logger->info(__PACKAGE__ . ".closeConn Closing SFTP connection to $key");
       $self->{sftp_session_for_ce}->{$key}->{conn}->print("exit");
       $self->{sftp_session_for_ce}->{$key}->{conn}->close;
    }

    $self->{sftp_session_for_ce} = undef;

    if ($self->{conn}) {
      $self->{conn}->print("exit");
      $self->{conn}->close;
    }
    if ($self->{sftp_session}){
      $self->{sftp_session}->{conn}->print("exit");
      $self->{sftp_session}->{conn}->close;
      $self->{sftp_session} = undef;
    }
    foreach $key (keys %{$self->{shell_session}}) {
        $logger->info(__PACKAGE__ . ".closeConn Closing Shell connection to $key");
        $self->{shell_session}->{$key}->{conn}->print("exit");
        $self->{shell_session}->{$key}->{conn}->close;
    }
    $self->{shell_session} = undef;
}


=head2 configureSgx4000FromTemplate()

Iterate through template files for tokens, 
replace all occurrences of the tokens with the values in the supplied hash (i.e. data from TMS).
For each template file using CLI session do the provisioning.

=over 

=item Arguments :

 - file list (array reference)
      specify the list of file names of template (containing CLI commands)
 - replacement map (hash reference)
      specify the string to search for in the file

=item Return Values :

 - 0 configuration of sgx4000 using template files failed.
 - 1 configuration of sgx4000 using template files successful.

=item Example :

    my @file_list = (
                        "QATEST/SGX4000/sgxNicCfg.template",
                        "QATEST/SGX4000/sgxANSIM3uaSingleSTPMultiGSX.template",
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

        # SGX4000 - related tokens
        'CE0SHORTNAME' => $TESTBED{'sgx4000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME},
        'CE1SHORTNAME' => $TESTBED{'sgx4000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME},
        'CE0LONGNAME' => "$TESTBED{'sgx4000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME}",
        'CE1LONGNAME' => "$TESTBED{'sgx4000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME}",
        'CE0EXT0IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{IP},
        'CE0EXT1IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{IP},
        'CE0INT0IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{IP},
        'CE0INT1IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{IP},
        'CE1EXT0IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{IP},
        'CE1EXT1IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{IP},
        'CE1INT0IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{IP},
        'CE1INT1IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{IP},

        'CE0EXT0NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
        'CE0EXT1NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
        'CE0INT0NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{MASK},
        'CE0INT1NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{MASK},
        'CE1EXT0NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
        'CE1EXT1NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
        'CE1INT0NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{MASK},
        'CE1INT1NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{MASK},
    );

    unless ( $cli_session->configureSgx4000FromTemplate( \@file_list, \%replacement_map ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Could not configure SGX4000 from Template files.";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured SGX4000 from Template files.");

=back 

=cut

sub configureSgx4000FromTemplate {

    my ($self, $file_list_arr_ref, $replacement_map_hash_ref) = @_ ;
    my $sub_name = "configureSgx4000FromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $file_list_arr_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory file list array reference input is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    unless ( defined $replacement_map_hash_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory replacement map hash reference input is missing or blank.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $sftpadmin_ip  = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    my $ipaddress     = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    my $script_path   = "/home/Administrator/";

    # Open a session for SFTP
    if (!defined ($self->{sftp_session})) {
        $logger->debug(__PACKAGE__ . ".$sub_name: starting new SFTP sesssion");

        $self->{sftp_session} = new SonusQA::Base( -obj_host       => $sftpadmin_ip,
                                                   -obj_user       => "root",
                                                   -obj_password   => $root_password,
                                                   -comm_type      => 'SFTP',
                                                   -obj_port       => 2024,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

        unless ( $self->{sftp_session} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to SGX");
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not open session object to required SGX \($ipaddress\)");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    my $timeout = 300;

    my ( @file_list, %replacement_map );
    @file_list       = @$file_list_arr_ref;
    %replacement_map = %$replacement_map_hash_ref;

    my $file_name;

    foreach $file_name (@file_list) {
        my ( $f, @template_file );
        unless ( open INFILE, $f = "<$file_name" ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open input file \'$file_name\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
        }

        @template_file  = <INFILE>;

        unless ( close INFILE ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close input file \'$file_name\'- Error: $!");
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

        my @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);

        # Now the framework would go write @file_processed either to a new file, for sourcing
        my $out_file;
        if($file_name =~ m/(.*?)\.template/) {
           $out_file = $1;
        }

        my $script_file;
        my $from_path;
        if($file_name =~ m/(.*\/)(.*?)\.template/) {
           $from_path = $1;
           $script_file = $2;
        }

        # open out file and write the content
        $logger->debug(__PACKAGE__ . ".$sub_name: writing \'$out_file\'");
        unless ( open OUTFILE, $f = ">$out_file" ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
        }

        print OUTFILE (@file_processed);

        unless ( close OUTFILE ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
        }

        # Transfer File
        my $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::putFileToRemoteDirectoryViaSFTP (
                                                                             $self->{sftp_session},
                                                                             $from_path,       # From, local DIR
                                                                             $script_path,     # To remote directory
                                                                             $script_file,     # file to transfer
                                                                             $timeout,         # Maximum file transfer time
                                                                             );

        # Check status
        if ( $file_transfer_status == 1 ) {
           $logger->info(__PACKAGE__ . ".$sub_name: $script_file transfer success");
        } else {
           $logger->error(__PACKAGE__ . ".$sub_name: failed");
           return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: Sourcing the $script_file on SGX");

        my $cmd_string = "source $script_file";
        my $database_error = 0;

        unless ( $self->execCliCmd ( $cmd_string ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot execute command $cmd_string:\n@{ $self->{CMDRESULTS} }" );
            foreach (@{$self->{CMDRESULTS} }) {
                if ( /Aborted: the configuration database is locked/) {
                    $database_error = 1;
                    last;
                }
            }
            if ( $database_error ) {
                 $logger->debug(__PACKAGE__ . ".$sub_name: Database Error Encountered. So sleeping for 15 seconds ");
                 sleep (15);
                 $logger->debug(__PACKAGE__ . ".$sub_name: Waking up after sleep, will retry sourcing the file now after doing an exit ");
                 my $retry = 2;
                 # Issue exit and wait for either [ok], [error], or [yes,no]
                 unless ( $self->{conn}->print( "exit" ) ) {
                     $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue exit " );                     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                     $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
                     $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
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
        	     $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
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
                         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
                         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
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

                 while ( $retry <= 3 ) {
                     unless ( $self->execCliCmd ( $cmd_string ) ) { 
                         $logger->debug(__PACKAGE__ . ".$sub_name: Database Error Encountered for the $retry time. So sleeping for another 15 seconds ");
                         sleep (15);
                         $logger->debug(__PACKAGE__ . ".$sub_name: Waking up after sleep, exiting from config mode now.");

                         # Issue exit and wait for either [ok], [error], or [yes,no]
                         unless ( $self->{conn}->print( "exit" ) ) {
                             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'exit\'");
        	             $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
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
        	             $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
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
        	                $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
	                        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
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
                     } else { 
                           $logger->debug(__PACKAGE__ . ".$sub_name: Sourcing $script_file file on SGX Successful ");
                           last;
                     }
                     $retry++;
                 }
            } else {
                  $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error while sourcing the file $script_file . Failure");
                  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                  return 0;
            } 
        } else { 
            $logger->debug(__PACKAGE__ . ".$sub_name: Sourcing $script_file file on SGX Successful ");
        }
    }
     
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured SGX4000 from Template.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}

 

###################################################
# rollSGXLog
###################################################

=head2 rollSGXLog()

Roll the SGX Log Files.

=over 

=item Arguments:

        Optional :
        -snmpRoll   -  Set to 1 , if snmplogs are to be rolled. else 0.

=item Returns:

    The the DBG, SYS, TRC, ACT Log File Names along with the Full Path

=item Examples:

        unless ( @cmdresults = $cli_session->rollSGXLog ) {
                $logger->debug(__PACKAGE__ . ".$test_id:  Could not Roll over the SGX Logs");
                $cli_session->DESTROY;
        }
        $logger->debug(__PACKAGE__ . ".$test_id:  Log File Rolled Over");

=back 

=cut

sub rollSGXLog()
{
    my ($self, %args) = @_;
    my $sub = "rollSGXLog()";
    my (%a, $add_path, @arr_result, @cmdresults, $cmd );
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE SGX DBG, SYS, TRC, ACT LOG");

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   ## GET the SGX Object HERE

    my %file_type = (
        'SYS' => 'system',
        'DBG' => 'debug',
        'TRC' => 'trace',
        'ACT' => 'acct'
    );

    if (defined  $self->{POST_8_4} and $self->{POST_8_4}) {
        $file_type{'AUD'} = 'audit';
        $file_type{'SEC'} = 'security';
    }
     
    # Determine name of active DBG, SYS, TRC, ACT log
    foreach (keys %file_type) {
        $cmd = "request eventLog typeAdmin $file_type{$_} rolloverLogNow";
        $self->execCliCmd($cmd);
    }

    $cmd = "show table eventLog typeStatus";
    @cmdresults = $self->execCliCmd($cmd);

    $logger->debug(__PACKAGE__ . ".$sub Rolling the Log Files on the SGX ");
       
    my $suffix = '(' . join('|',keys %file_type) . ')';
    
    $add_path= $self->{LOG_PATH};

    foreach(@{$self->{CMDRESULTS}}) {
        next unless (m/(\w+.$suffix)/);

        my ($file, $file_suffix) = ($1, $2);
        $logger->debug(__PACKAGE__ . ".$sub The New $file_type{$file_suffix} File Name is $file");

        # Store start filenames, in case of multiple logs during a tests
        $self->{$file_suffix . 'file'} = $file;

        # Create full path to log....Currently this is set to a STATIC path
        my $logfullpath = "$add_path/$file"; 
        push (@arr_result, "$logfullpath");
    }
        
    # roll over the SNMP Log.
    if(defined $a{-snmpRoll} && $a{-snmpRoll} ) {
        $self->startLog ( -logType => "snmp",
                          -path    => "/opt/sonus/sgx/tailf/var/confd/log/" );
    }

    # Return file
    return (@arr_result);
}


###################################################
# getSGXLog
###################################################

=head2 getSGXLog()

Retreive the Log file from the SGX into the ATS server.
The default Path stored is on the ATS default account 'autouser'
i.e /export/home/autouser/ats_user/logs or
    /home/autouser/ats_user/logs

=over 

=item Arguments:

     -log
        Log file names to be retreived

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

     $cli_session->getSGXLog(-log => $log, );

=back 

=cut

sub getSGXLog {
    my ($self, $autoUserDir, @logFiles) = @_;
    my $sub = "getSGXLog()";
    my ($add_path);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE SGX DBG, SYS, TRC, ACT LOG");

     $logger->debug(__PACKAGE__ . ".$sub autoUserDir => $autoUserDir : logFiles => @logFiles");

if ( $self->sftpLogFile ($autoUserDir, @logFiles) ) {
                $logger->debug(__PACKAGE__ . ".$sub Retreived the @logFiles file successfully...");
                return 0;
                }
        else {
                $logger->error(__PACKAGE__ . ".$sub Failed to Get the Log file @logFiles");
                return 1;
        }

}

###################################################
# sftpLogFile --Internal Function
#autoUserDir => "/export/home/autouser/ats_user/logs";  For Bangalore
#autoUserDir => "/home/autouser/ats_user/logs";   For UK
###################################################

sub sftpLogFile()
{
    my ($self, $autoUserDir, @files) = @_;
    my $sub = "sftpLogFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub FTP the log file into autouser of ATS");

   $logger->debug(__PACKAGE__ . ".$sub autoUserDir => $autoUserDir : files => @files");

   my $logDir = $self->{LOG_PATH};
   my $timeout = 300;
   my $log_dir = $autoUserDir;

   my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
   my $sftpadmin_ip = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};

   # Open a session for SFTP
   my $sftp_session = new SonusQA::Base( -obj_host       => $sftpadmin_ip,
                                         -obj_user       => "root",
                                         -obj_password   => $root_password,
                                         -comm_type      => 'SFTP',
                                         -obj_port       => 2024,
                                         -return_on_fail => 1,
                                       );

   unless ( $sftp_session ) {
      $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
      return 0;
   }
   sleep 1;

   my $fileName;

   foreach $fileName (@files) {
      my $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP (
                                                                             $sftp_session,
                                                                             $log_dir,      # TO Remote directory
                                                                             $logDir,       # FROM remote directory
                                                                             $fileName,     # file to transfer
                                                                             $timeout,
                                                                           );
      if ( $file_transfer_status == 1 ) {
         $logger->info(__PACKAGE__ . ".$sub $fileName transfer success");
      } else {
         $logger->error(__PACKAGE__ . ".$sub failed");
         $sftp_session->DESTROY;
         return 0;
      }
   }

   $sftp_session->DESTROY;
   return 1;
}

=head2 getSGXLogs()

DESCRIPTION:

  This function is to retrieve the current logs.
  If the Log Type argument is not supplied, SYS and DBG will be copied.

=over 

=item ARGUMENTS:

   Mandatory:
    -testCaseID => Test Case Id
    -logDir     => Logs are stored in this directory

   Optional: 
    -logType    => Log Types to copy e.g. 'system','debug','trace'
                   Default => ["system", "debug"]
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item PACKAGE:

    SonusQA::SGX4000:SGX4000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGX4000HELPER::retrieveCurrentLogFileName;
    SonusQA::SGX4000::SGX4000HELPER::nameLastLogFile;

=item OUTPUT:

      0  - fail ;
      1  - success;

=item EXAMPLE:

    $sgx_object->getSGXLogs(-testCaseID => $a{-testId}, -logDir => $log_dir, -variant => $variant, -timeStamp => $timestamp});
    $sgx_object->getSGXLogs(-testCaseID => $a{-testId}, -logDir => $log_dir, -logType => ['system','debug','trace','audit','security']);

=back 

=cut

sub getSGXLogs {
    my ($self, %args)=@_;    
    my $sub = "getSGXLogs";
    my $remainder;
        
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    # Set default values before args are processed
    my %a   = ( -logType => ["system", "debug"], -variant   => "NONE", -timeStamp => "00000000-000000" );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    my @log_array     = @{$a{-logType}};

    my %file_type = (
        system => "SYS",
        debug  => "DBG",
        trace  => "TRC",
        acct   => "ACT",
        audit  => "AUD",
        security => "SEC",
    );

    # TMS Data            
    my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $sftpadmin_ip  = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    my $ipaddress  = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
   
    ##########################################
    # Step 1: Checking mandatory args;
    ##########################################
    unless ($sftpadmin_ip) {
       $logger->warn(__PACKAGE__ . ".$sub MGMT IP Address MUST BE DEFINED");
       return $0;
    }
    unless ($root_password) {
       $logger->warn(__PACKAGE__ . ".$sub SFTP Password MUST BE DEFINED");
       return $0;
    }      
    unless ( $a{-testCaseID} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory -testCaseID is empty or blank.");
        return 0;
    }          
    unless ( $a{-logDir} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
        return 0;
    }

    ####################################################
    # Step 2: Create SFTP session;
    ####################################################
    my $timeout = 300;
 
    # Open a session for SFTP   
    if (!defined ($self->{sftp_session})) {
        $logger->debug(__PACKAGE__ . ".$sub starting new SFTP sesssion");
        
        $self->{sftp_session} = new SonusQA::Base( -obj_host       => $sftpadmin_ip,
                                                   -obj_user       => "root",
                                                   -obj_password   => $root_password,
                                                   -comm_type      => 'SFTP',
                                                   -obj_port       => 2024,
                                                   -return_on_fail => 1,
                                                 );

        unless ( $self->{sftp_session} ) {
            $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
            $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required SGX \($ipaddress\)");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");      
            return 0;
        }
    }
          
    ##########################################
    # Step 3: Get the current log file name and SFTP
    ##########################################
    my $file_name;
    my $from_Dir = $self->{LOG_PATH};
    my $to_Dir = $a{-logDir};
    my $file_transfer_status;
    my $sgxlog_type;
    my @returnArr;

    # Loop for each Logfile requested
    foreach $sgxlog_type (@log_array) {
        # Retrieve Current filename
        $file_name = SonusQA::SGX4000::SGX4000HELPER::retrieveCurrentLogFileName ($self, $sgxlog_type);
        my $startfile = " ";

        # Check this is a filename and not a error code        
        if (length($file_name) < 11 ) {
            $logger->error(__PACKAGE__ . ".$sub: Can't retrieve the current log file name.  Error:$file_name");

            # Determine latest file from directory
            $file_name = $self->nameLastLogFile($file_type{$sgxlog_type});
            
            if (length($file_name) < 11 ) { next; }
        }
     
        # Obtain saved startfile
        if ($file_type{$sgxlog_type}) {
            ($startfile, $remainder) = split /\./, $self->{$file_type{$sgxlog_type} . 'file'};
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub: Unknown log type requested :  $sgxlog_type ");
            return 0;
        }        
                            
        # drop file extension e.g. .SYS from filename
        $file_name =~ m/(\w+).$file_type{$sgxlog_type}/;
        my $endfile = "$1";
        my %filelist;
        
        # Empty startfile, rollSGXLog() not called
        if ( length($startfile) < 5 ){
            $logger->debug(__PACKAGE__ . ".$sub   startfile value incorrect: $startfile");
            $startfile = $endfile;
        }
        $logger->debug(__PACKAGE__ . ".$sub:  startfile:$startfile  endfile:$endfile .$file_type{$sgxlog_type}");

        # Check for Log number wrapping back to 0
        if ($endfile lt $startfile) {
            while ($endfile lt $startfile) {
                $logger->debug(__PACKAGE__ . ".$sub:   endfile = $endfile, startfile = $startfile");
                
                # Create new file name to include testId amd Host Name
                # $file_name will contain 2 values, source_name destination_name
                #                 100001.SYS                            testId-Variant-Timestamp-SGX-BUGS-100001.SYS                 
                $file_name = "$startfile.$file_type{$sgxlog_type} " . " $a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$self->{OBJ_HOSTNAME}-" . "$startfile.$file_type{$sgxlog_type}" ;
                $filelist{$file_name}=1;
                $endfile = SonusQA::GSX::GSXHELPER::hex_inc($endfile);
         
                # Default File Count 32 (decimal), could be obtained from GSX SHOW EVENT LOG ALL ADMIN
                #if ($startfile eq 1000021) {$startfile = 1000001;}
            }
        }
     
        # Add Files to Array   
        while ($startfile le $endfile) {
            $logger->debug(__PACKAGE__ . ".$sub:  startfile = $startfile, endfile = $endfile");
            
            # Create new file name to include testId amd Host Name
            # $file_name will contain 2 values, source_name destination_name
            #                 100001.SYS                            testId-Variant-Timestamp-SGX-BUGS-100001.SYS
            $file_name = "$startfile.$file_type{$sgxlog_type} " . " $a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$self->{OBJ_HOSTNAME}-" . "$startfile.$file_type{$sgxlog_type}" ;
	    $filelist{$file_name}=1;
            $startfile = SonusQA::GSX::GSXHELPER::hex_inc($startfile);
        }

        
          $logger->debug(__PACKAGE__ . ".$sub:  filelist ".Dumper(%filelist)); 
        # Loop and Copy each File
	    foreach $file_name (keys %filelist) {
            # Transfer File
            $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP (
                                                                             $self->{sftp_session},
                                                                             $to_Dir,       # TO Remote directory
                                                                             $from_Dir,     # FROM remote directory
                                                                             $file_name,    # file to transfer
                                                                             $timeout,      # Maximum file transfer time
                                                                             );
                
            # Check status                                                                           
            if ( $file_transfer_status == 1 ) {
                $logger->info(__PACKAGE__ . ".$sub $file_name transfer success");
            } else {
               $logger->error(__PACKAGE__ . ".$sub failed");
               return 0;
            }
            # Return the local file names
            my @tempArr = split(/ /, $file_name);
            push (@returnArr, $tempArr[2]);
        }
    }
    

    #Transfer the SNMP Log.
    if (grep {$_ eq "snmp"} @log_array){
        my $snmpLogName = $self->getLog( -testId    => $a{-testCaseID},
                                         -logType   => "snmp" ,
                                         -path      => "/opt/sonus/sgx/tailf/var/confd/log/" ,
                                         -logDir    => $a{-logDir} ,
                                         -variant   => $a{-variant},
                                         -timeStamp => $a{-timeStamp} );
    
        unless ($snmpLogName) {
            $logger->error(__PACKAGE__ . ".$sub SNMP Log transfer failed");
            return @returnArr;
        }
        $logger->info(__PACKAGE__ . ".$sub SNMP Log transfer success");
    
        # Return the local log file name
        push @returnArr, $snmpLogName;
    }

    return @returnArr;
}

=head2 nameCurrentLogs()

DESCRIPTION:

    This subroutine is used to retrieve the current SGX log names.
    Can also be used to set the SGX log names in the SGX object.

=over 

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    SGX_Obj {DBGfile, SYSfile, ACTfile, TRCfile}

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    Array of file names

=item EXAMPLE:

    @sgxLogFiles = nameCurrentLogs();

=back 

=cut

sub nameCurrentLogs()
{
    my ($self, %args) = @_;
    my $sub = "nameCurrentLogs()";
    my (%a, $add_path, @arr_result, $cmd, $dbglogname, $dbglogfullpath, $trclogfullpath, $trclogname, $syslogname, $audlogname, $seclogname, $syslogfullpath, $actlogname, $actlogfullpath, $audlogfullpath, $seclogfullpath);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE SGX DBG, SYS, TRC, ACT, AUD, SEC LOGS");

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $cmd = "show table eventLog typeStatus";
    unless ($self->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub:  Commit for \'$_\' failed--\n@{$self->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

        
    foreach(@{$self->{CMDRESULTS}})    {
        if (m/(\w+.DBG)/)
                {
            $dbglogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New Debug File Name is $dbglogname");
                }
        if (m/(\w+.SYS)/)
                {
            $syslogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New System File Name is $syslogname");
                }
        if (m/(\w+.TRC)/)
                {
            $trclogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New Trace File Name is $trclogname");
                }
        if (m/(\w+.ACT)/)
                {
            $actlogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New Acct File Name is $actlogname");
                }
        if (m/(\w+.AUD)/)
                {
            $audlogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New Audit File Name is $audlogname");
                }
        if (m/(\w+.SEC)/)
                {
            $seclogname = "$1";
                $logger->debug(__PACKAGE__ . ".$sub The New Security File Name is $seclogname");
                }
    }
        
    # Store start filenames, in case of multiple logs during a tests
    $self->{DBGfile} = $dbglogname; 
    $self->{SYSfile} = $syslogname; 
    $self->{TRCfile} = $trclogname;
    $self->{ACTfile} = $actlogname;
    $self->{AUDfile} = $audlogname;
    $self->{SECfile} = $seclogname;
     
    # Create full path to log....Currently this is set to a STATIC path
    $add_path= $self->{LOG_PATH};    
    $dbglogfullpath = "$add_path/$dbglogname";
    $syslogfullpath = "$add_path/$syslogname";
    $trclogfullpath = "$add_path/$trclogname";
    $actlogfullpath = "$add_path/$actlogname";
    $audlogfullpath = "$add_path/$audlogname";
    $seclogfullpath = "$add_path/$seclogname";

    push (@arr_result, "$dbglogfullpath");
    push (@arr_result, "$syslogfullpath");
    push (@arr_result, "$trclogfullpath");
    push (@arr_result, "$actlogfullpath");
    push (@arr_result, "$audlogfullpath");
    push (@arr_result, "$seclogfullpath");

    # Return file
    return (@arr_result);
}

=head2 grepPattern()

DESCRIPTION:

    This subroutine is used search a pattern in SGX logs

=over 

=item ARGUMENTS:

    1. Search Pattern
    3. File type

=item OPTIONAL ARGUMNET:

    1. -checkCount => pass n pointing nummber of occurrences of $pattern in log file
    2. -getCount  => to get the nummber of occurrences of $pattern in log file

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    $DBGfile, $SYSfile, $ACTfile, $TRCfile

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    $testStatus = grepPattern(-pattern   => $pattern, -logType   => "system");

=back 

=cut

sub grepPattern {
   my ($self, %args ) = @_ ; 
   my $sub        = "grepPattern";
   my $testStatus = 0;
   my %a          = ( -getCount => 0, -checkCount => 0);
   my $filename;
   my (@result);

   my %file_type = (
       system => "SYS",
       debug  => "DBG",
       trace  => "TRC",
       acct   => "ACT",
   );

   if (defined  $self->{POST_8_4} and $self->{POST_8_4}) {
       $file_type{'audit'} = "AUD";
       $file_type{'security'} = "SEC";
   }
       
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");    
   
   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );
   
   # Retrieve logname saved by rollSGXLog()
   if ($a{-logType} eq "system") {
      $filename = $self->{SYSfile};        
   }
   elsif ($a{-logType} eq "debug") {
      $filename = $self->{DBGfile}; 
   }
   elsif ($a{-logType} eq "acct") {
      $filename = $self->{ACTfile};
   }
   elsif ($a{-logType} eq "trace") {
      $filename = $self->{TRCfile};
   }
   elsif ($a{-logType} eq "audit") {
      $filename = $self->{AUDfile};
   }
   elsif ($a{-logType} eq "security") {
      $filename = $self->{SECfile};
   }
   elsif ($a{-logType} eq "snmp") {
      $logger->info(__PACKAGE__ . ".$sub : Log type is snmp ");
   }
   else {
      $logger->info(__PACKAGE__ . ".$sub: -logType not provided");
      $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub : going to match for pattern count") if ($a{-checkCount});  
   $logger->info(__PACKAGE__ . ".$sub : i will return number of occurance ") if ( $a{-getCount});

   my ($fileref, %filehash, @filearray); 

   # Catch any Errors
   eval {
      unless ( $a{-logType} eq "snmp" ) {
         # Determine the log files from the log directory
         $fileref = $self->getSgxLogDetails( -logType => $file_type{$a{-logType}} );
		 
         # Information Returned?
         if ( $fileref ) {
            %filehash = %{$fileref};
            @filearray = @{$filehash{-fileNames}};
            $logger->info(__PACKAGE__ . ".$sub: grep-->@filearray\n");	
            unless(@filearray){
               $logger->info(__PACKAGE__ . ".$sub: cannot retrieve the log file names");	
            }		
         }
         else { 
             $logger->info(__PACKAGE__ . ".$sub : No Data Returned");
             $filearray[0] = $filename; 
         }
      }
   };
   if ($@) {
      $logger->error(".$sub:  : Run-time error: $@");
   }
        
   # Get the SGX object
   my $tmsAlias = $self->{OBJ_HOSTNAME};
   
   # open a shell session
   my $shellSession;
  
   # Reuse same connection when available
   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->info(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias ( 
                                       -tms_alias    => $tmsAlias, 
                                       -obj_port     => 2024, 
                                       -obj_user     => "root", 
                                       -sessionlog   => 1 )) {
         $logger->info(__PACKAGE__ . ".$sub Could not open connection to SGX");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }
   
   $logger->info(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");
   
   $shellSession = $self->{shell_session}->{$tmsAlias};    
   $shellSession->{CMDRESULTS} = undef;

   my $cmdString ;
   if ( $a{-logType} eq "snmp" )  {
       $filename = "snmp.log";
       $cmdString = ($a{-checkCount} or $a{-getCount}) ? "grep -c \"$a{-pattern}\" /opt/sonus/sgx/tailf/var/confd/log/$filename" : "grep \"$a{-pattern}\" /opt/sonus/sgx/tailf/var/confd/log/$filename";
       $logger->info(__PACKAGE__ . ".$sub: executing : $cmdString");

       if ( $shellSession->execShellCmd("$cmdString") ) {
         $logger->info(__PACKAGE__ . ".$sub command '$cmdString' successfully executed\n@{$shellSession->{CMDRESULTS}}");
         if ($a{-checkCount}) {
            $logger->info(__PACKAGE__ . ".$sub $a{-pattern} occured in $shellSession->{CMDRESULTS}[0] times");
            $testStatus = ($shellSession->{CMDRESULTS}[0] == $a{-checkCount}) ? 1 : 0;
         } 
         elsif ($a{-getCount}) {
            $logger->info(__PACKAGE__ . ".$sub $a{-pattern} occured in $shellSession->{CMDRESULTS}[0] times");
            $testStatus = $shellSession->{CMDRESULTS}[0];
         }
         else {
            $testStatus = 1;
         }
       }
   }
   else {
       foreach $filename (@filearray) {
           $cmdString = ($a{-checkCount} or $a{-getCount} ) ? "grep -c \"$a{-pattern}\" $self->{LOG_PATH}/$filename" : "grep \"$a{-pattern}\" $self->{LOG_PATH}/$filename";
   	       $logger->info(__PACKAGE__ . ".$sub: executing $cmdString command");

           if ( $shellSession->execShellCmd("$cmdString") ) {
      	       $logger->info(__PACKAGE__ . ".$sub command '$cmdString' successfully executed\n@{$shellSession->{CMDRESULTS}}");
               if ($a{-checkCount}) {
                  $logger->info(__PACKAGE__ . ".$sub $a{-pattern} occured in $shellSession->{CMDRESULTS}[0] times");
                  $testStatus = ($shellSession->{CMDRESULTS}[0] == $a{-checkCount}) ? 1 : 0;
               }
               elsif ($a{-getCount}) {
                  $logger->info(__PACKAGE__ . ".$sub $a{-pattern} occured in $shellSession->{CMDRESULTS}[0] times");
                  $testStatus += $shellSession->{CMDRESULTS}[0];
               }
               else {
                  $testStatus = 1;
               }           
               last;
           }
       }
   }

   if ( $shellSession->{CMDRESULTS} ) {
       $logger->info(__PACKAGE__ . ".$sub: @{ $shellSession->{CMDRESULTS} }");
   }

   unless($testStatus) {
       $logger->info(__PACKAGE__ . ".$sub pattern not found");	
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [$testStatus]");
   return $testStatus;   
}

=head2 createSS7GttTableEntry()

DESCRIPTION:

   Creates GTT entry in SGX4000 SS7 GTT table 

=over 

=item PACKAGE:

    SonusQA::SGX4000:createSS7GttTableEntry

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=back 

=cut

##################################################################################
sub createSS7GttTableEntry {
    my ($self,%input_hash) = @_ ;
    my $sub_name     = "createSS7GttTableEntry";
    my $logger       = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name:  --> Entered Sub" );

    $logger->debug( __PACKAGE__ . ".$sub_name:  Configuring SS7 GTT Table  $input_hash{-name} " );

    my @cmd = ( "set ss7 gttTable $input_hash{-name}", "set ss7 gttTable $input_hash{-name} state enabled", );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name" ) {
            s/-//;
            $cmd[0] .= " $_ $input_hash{-$_}";
        }
    }

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug( __PACKAGE__ . ".$sub_name: Successfully Configured SS7 GTT Table  $input_hash{-name} " );
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;
}

=head2 deleteSS7GttTableEntry()

DESCRIPTION:

   Deletes a GTT entry in SGX4000 SS7 GTT table 

=over 

=item PACKAGE:

    SonusQA::SGX4000:deleteSS7GttTableEntry

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=back 

=cut

##################################################################################
sub deleteSS7GttTableEntry {
    my ($self,%input_hash) = @_ ;
    my $sub_name     = "deleteSS7GttTableEntry";
    my $logger       = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name:  --> Entered Sub" );

    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode --\n@{$self->{CMDRESULTS}}. " );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

    $logger->debug( __PACKAGE__ . ".$sub_name:  Deleting SS7 GTT Table $input_hash{-name} " );

    my @cmd = ( "set ss7 gttTable $input_hash{-name} state disabled", "delete ss7 gttTable $input_hash{-name}" );

    # Adding args...
    foreach ( keys %input_hash ) {
        if ( $_ ne "-name" ) {
            s/-//;
            $cmd[0] .= " $_ $input_hash{-$_}";
        }
    }

    foreach (@cmd) {
        unless ($self->execCliCmd("$_") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Command '$_' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
        unless ( $self->execCliCmd("commit") ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  'commit' failed --\n@{$self->{CMDRESULTS}}." );
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  'exit' failed --\n@{$self->{CMDRESULTS}}.");
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug( __PACKAGE__ . ".$sub_name: Successfully Deleting SS7 GTT Table $input_hash{-name} " );
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1]");
    return 1;

}



=head2 setsccpConcernedDestination()

DESCRIPTION:

This function is to set ss7 sccpConcernedDestination for a given node.

=over 

=item ARGUMENTS:

Mandatrory:
      -name            	- Mandatory, sccpConcernedDestination name.
      -destination 		- Mandatory, destination name.
      -localNode        - Mandatory, name of the associated local node.
      -localSsn         - Mandatory, value for localSsn.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

     $obj->setsccpConcernedDestination(	-name 			=> 'ssnLocal6',
                                 		-destination	=> 'inet6',
										-localNode		=> 'a7n1',
                                 		-localSsn 		=> 8);

=back 

=cut

sub setsccpConcernedDestination {
    my ($self,%input_hash) = @_;
    my $sub_name = "setsccpConcernedDestination";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ('-name','-destination','-localNode','-localSsn') {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Setting ss7 sccpConcernedDestination
    #****************************************************

	$logger->debug(__PACKAGE__ . ".$sub_name:  Setting ss7 sccpConcernedDestination $input_hash{-name} for (destination=$input_hash{-destination}, localNode=$input_hash{-localNode}, localSsn=$input_hash{-localSsn}).");
    
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

	my @cmd = (
            "set ss7 sccpConcernedDestination $input_hash{-name} destination $input_hash{-destination} localNode $input_hash{-localNode} localSsn $input_hash{-localSsn}",
            "set ss7 sccpConcernedDestination $input_hash{-name} state enabled",
            "set ss7 sccpConcernedDestination $input_hash{-name} mode in",
 	);

    foreach (@cmd) {
        unless ($self->execCliCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed $_ --\nCMDRESULTS : @{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
            return 0;
        }
        unless ($self->execCliCmd("commit")) {
            $logger->error(__PACKAGE__ . ".$sub_name: 'commit' failed --\nCMDRESULTS: @{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: 'exit' failed --\nCMDRESULTS: @{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set ss7 sccpConcernedDestination $input_hash{-name} for localNode: $input_hash{-localNode}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");

    return 1;
}


=head2 setsccpRemoteSubSystem()

DESCRIPTION:

This function is to set ss7 sccpRemoteSubSystem.

=over 

=item ARGUMENTS:

Mandatrory:
      -name            	- Mandatory, sccpRemoteSubSystem name.
      -destination 		- Mandatory, destination name.
      -remoteSsn        - Mandatory, value for remoteSsn.

NOTE: 
 None

=item PACKAGE:

 None

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

     $obj->setsccpRemoteSubSystem(	-name 			=> 'ssnRem6',
                                 	-destination	=> 'inet6',
                                 	-remoteSsn 		=> 6);

=back 

=cut

sub setsccpRemoteSubSystem {
    my ($self,%input_hash) = @_;
    my $sub_name = 'setsccpRemoteSubSystem';

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    #****************************************************
    # step 1: Checking mandatory inputs 
    #****************************************************

    $logger->debug(__PACKAGE__ . ".$sub_name:  Checking mandatory inputs.");
    foreach ('-name', '-destination', '-remoteSsn') {
        unless ( $input_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory $_ input is blank or missing.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
            return 0;
        }
    }

    #****************************************************
    # step 2: Setting ss7 sccpRemoteSubSystem
    #****************************************************

	$logger->debug(__PACKAGE__ . ".$sub_name:  Setting ss7 sccpRemoteSubSystem $input_hash{-name} for (destination=$input_hash{-destination}, remoteSsn=$input_hash{-remoteSsn}).");
    
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config private mode -- \n@{$self->{CMDRESULTS}}. " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0].");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered config private mode.");

	my @cmd = (
            "set ss7 sccpRemoteSubSystem $input_hash{-name} destination $input_hash{-destination} remoteSsn $input_hash{-remoteSsn}",
            "set ss7 sccpRemoteSubSystem $input_hash{-name} state enabled",
            "set ss7 sccpRemoteSubSystem $input_hash{-name} mode in",
 	);

    foreach (@cmd) {
        unless ($self->execCliCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed $_ --\nCMDRESULTS : @{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
            return 0;
        }
        unless ($self->execCliCmd("commit")) {
            $logger->error(__PACKAGE__ . ".$sub_name: 'commit' failed --\nCMDRESULTS: @{$self->{CMDRESULTS}}");
            $self->leaveConfigureSession;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving config private mode.");
    unless ( $self->execCliCmd("exit") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: 'exit' failed --\nCMDRESULTS: @{$self->{CMDRESULTS}}." );
        $self->leaveConfigureSession;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0].");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set ss7 sccpRemoteSubSystem $input_hash{-name} for destination: $input_hash{-destination}.");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [1].");

    return 1;
}

sub AUTOLOAD {
    our $AUTOLOAD;
    my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
    if(Log::Log4perl::initialized()){
        my $logger = Log::Log4perl->get_logger($AUTOLOAD);
        $logger->warn($warn);
    } else {
        Log::Log4perl->easy_init($DEBUG);
        WARN($warn);
    }
}

=head2 startLog()

DESCRIPTION:

    This subroutine is used to start the log of desired type, in the path mentioned of the SGX machine. ( rollover )

=over 

=item ARGUMENTS:

    Mandatory:
    -logType    => Log Type . For example : "snmp"
    -path       => Path where the log file of type logType is located in the SGX.

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    None.

=item EXTERNAL FUNCTIONS USED:

   None.

=item OUTPUT:

    0            - fail
    1     - True (Success)

=item EXAMPLE:

    unless( $self->startLog ( -logType => "snmp",
                              -path    => "/opt/sonus/sgx/tailf/var/confd/log/" ) ) {
        print ( " snmp log file rollover failed \n" );
    }

=back 

=cut

sub startLog {
    my ($self , %args ) = @_;
    my %a = ();
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    my $sub     = "startLog"; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $statusFlag = 1;
    
    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );
    
    # Checking mandatory args;
    unless ($a{-logType}) {
       $logger->warn(__PACKAGE__ . ".$sub LOG TYPE MUST BE DEFINED");
       return 0;
    }
    unless ($a{-path}) {
       $logger->warn(__PACKAGE__ . ".$sub PATH OF LOG FILE MUST BE DEFINED");
       return 0;
    }      
    
    # Accessing TMS data for the object.
    my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $ipaddress  = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    
    # Get the SGX object
    my $tmsAlias = $self->{OBJ_HOSTNAME};
   
    # open a shell session
    my $shellSession;
  
    # Reuse same connection when available
    if (!defined ($self->{shell_session}->{$tmsAlias})) {
        $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

        unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias ( 
                                       -tms_alias    => $tmsAlias, 
                                       -obj_port     => 2024, 
                                       -obj_user     => "root", 
                                       -sessionlog   => 1 )) {
            $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
   
    $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");
   
    $shellSession = $self->{shell_session}->{$tmsAlias};    
    $shellSession->{CMDRESULTS} = undef;
   
    # Change the path to Directory containing the logfile.
    my $cmd = "cd $a{-path}";
    my @output = $shellSession->{conn}->cmd( $cmd );
    unless ( @output ){
        $logger->error(__PACKAGE__ . ".$sub Could not change the path to $a{-path} ");
        $logger->error(__PACKAGE__ . ".$sub Error is @output ");
        $statusFlag = 0;
    }
    
    my $logname = "$a{-logType}.log";
    $self->{SNMPfile} = $logname;
    
    # Roll over the log file by emptying it.
    $logger->debug(__PACKAGE__ . ".$sub ========== The New $a{-logType} File Name is $self->{SNMPfile} ===================== ");
    $cmd = "> $logname";
    unless($shellSession->{conn}->cmd( $cmd )) {
        $logger->error(__PACKAGE__ . ".$sub Could not Roll over the log  $logname of type $a{-logType} ");
        $statusFlag = 0;
    }
    
    unless($statusFlag) {
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: --> Leaving Sub");
    return 1;
}

=head2 getLog()

DESCRIPTION:

    This subroutine is used to get the log from remote SGX machine to the desired directory in the local machine.

=over 

=item ARGUMENTS:

    Mandatory:
    -testCaseID => Test Case Id
    -logDir     => Logs will be stored in this directory in the local machine.
    -logType    => Log Type . For example : "snmp"
    -path       => Path where the log file of type logType is located in the SGX.

   Optional: 

    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item PACKAGE:

    SonusQA::SGX4000

=item GLOBAL VARIABLES USED:

    None.

=item EXTERNAL FUNCTIONS USED:

   1. SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP()

=item OUTPUT:

    0            - fail
    1     - True (Success)

=item EXAMPLE:

    unless ( $self->getLog( -testCaseID => $a{-testId},
                            -logType => "snmp" ,
                            -path => "/opt/sonus/sgx/tailf/var/confd/log/" ,
                            -logDir => $a{-logDir} ,
                            -variant => $a{-variant},
                            -timeStamp => $a{-timeStamp} )) {
        $logger->error(__PACKAGE__ . ".$sub SNMP Log transfer failed");
    }

=back 

=cut

sub getLog {
    my ($self , %args ) = @_;
    
    # Set default values before args are processed
    my %a = ( -variant   => "NONE" , -timeStamp => "00000000-000000" );

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    my $sub     = "getLog"; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $statusFlag = 1;
    
    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );
    
    # Checking mandatory args;
    unless ($a{-testId}) {
       $logger->warn(__PACKAGE__ . ".$sub testId MUST BE DEFINED");
       return 0;
    }
    unless ($a{-logType}) {
       $logger->warn(__PACKAGE__ . ".$sub LOG TYPE MUST BE DEFINED");
       return 0;
    }
    unless ($a{-path}) {
       $logger->warn(__PACKAGE__ . ".$sub PATH OF $a{-logType} LOG FILE MUST BE DEFINED");
       return 0;
    }      
    unless ($a{-logDir}) {
       $logger->warn(__PACKAGE__ . ".$sub   LOG DIR FOR $a{-logType} FILE TRANSFER MUST BE DEFINED");
       return 0;
    }      
    
    # Accessing TMS data for the object.
    my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $ipaddress  = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    
    # Open a session for SFTP   
    if (!defined ($self->{sftp_session})) {
        $logger->debug(__PACKAGE__ . ".$sub starting new SFTP sesssion");
        
        $self->{sftp_session} = new SonusQA::Base( -obj_host       => $ipaddress,
                                                   -obj_user       => "root",
                                                   -obj_password   => $root_password,
                                                   -comm_type      => 'SFTP',
                                                   -obj_port       => 2024,
                                                   -return_on_fail => 1,
                                                 );

        unless ( $self->{sftp_session} ) {
            $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
            $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required SGX \($ipaddress\)");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");      
            return 0;
        }
    }
    
    # construct the log file name and SFTP it to the desired Log Directory.  
    my $fileName = "$a{-logType}.log";
    my $locFile = "$a{-testId}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$self->{OBJ_HOSTNAME}-" . "$fileName" ;
    $fileName = "$fileName "." $locFile";

    my $timeout = 300;
    my $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP (
                                                                             $self->{sftp_session},
                                                                             $a{-logDir},       # TO Remote directory
                                                                             $a{-path},     # FROM remote directory
                                                                             $fileName,    # file to transfer
                                                                             $timeout,      # Maximum file transfer time
                                                                             );
    
    # Check status                                                                           
    if ( $file_transfer_status == 1 ) {
         $logger->info(__PACKAGE__ . ".$sub $fileName transfer success");
    } else {
        $logger->error(__PACKAGE__ . ".$sub for $fileName failed");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Leaving Sub");
    
    #Return Success
    return $locFile;
}

1;
