package SonusQA::ILOM;

=head1 NAME

SonusQA::ILOM - Perl module for interaction with ILOM as found on Sun hardware (X4250, T5520 et. al.)

=head1 SYNOPSIS

use SonusQA::ILOM;  # This is the class for the ATS interface to a Sun hardware platform's ILOM processor.

my $netem = SonusQA::ILOM->new(-OBJ_HOST => '<host name | IP Adress>',
	-OBJ_USER => '<cli user name>',
	-OBJ_PASSWORD => '<cli user password>',
	-OBJ_COMMTYPE => "<TELNET|SSH>",
	);

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface to a Sun hardware platform's ILOM processor.
Tested with ILOM firmware v3.x on X4250 and ILOM firmware 2.x on T5220.
It is assumed that the user of this module is familiar with the Sun ILOM documentation - if not please consult the relevant version for your firmware on the Sun website. 
If however you really just want a unix shell via this interface - call new(), startConsole(), consoleLogin() - then use execConsoleCmd("shell command")

=head2 AUTHORS

Malcolm Lashley <mlashley@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See inline documentation for additional contributors.

=head2 Test/Example code

Example/Test code is included in the perl-pod at the bottom of the module - please ensure this runs correctly when submitting changes.

=head1 SUB-ROUTINES

The following subroutines make up the public interfaces of this implementation.

startConsole()
stopConsole()
execCmd()
execConsoleCmd()
consoleLogin()
executeSu()

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;

use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
	my($self)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
	my($temp_file);
	$self->{COMMTYPES} = ["SSH"];
	$self->{TYPE} = "ILOM";
	$self->{conn} = undef;
        $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
        $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
	$self->{SESSIONLOG} = 1; # Set to 1 to enable session logs dumped to /tmp 
	$self->{IN_CONSOLE} = 0; # Used internally to determine if we have started /SP/console redirection or not.
}

sub setSystem(){
	my($self)=@_;
	my $sub_name = ".setSystem";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	my($cmd,@results);
	@results = $self->{conn}->cmd("cd /SP");
        if ( grep(/FAILED/i, @results )) {
            $logger->debug(__PACKAGE__ . "$sub_name: Looks like a HP Proliant Gen X series");
        } else {
	    @results = $self->{conn}->cmd("show hostname");
	    foreach(@results) {
		if (m/hostname = /) {
			$logger->info(__PACKAGE__ . "$sub_name ILOM reports $_");
		}
	    }
	    @results = $self->{conn}->cmd("show system_description");
	    foreach(@results) {
		if (m/system_description =/) {
			$logger->info(__PACKAGE__ . "$sub_name ILOM reports $_");
		}
	    }
        }
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
}

=head1 execConsoleCmd()

=over

=item DESCRIPTION: 

Execute a command on the /SP/console (which is assumed already started - if it is not started - error out)

=item ARGUMENTS: 

as per execCmd()

=item AUTHOR: Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut 

sub execConsoleCmd {
	my ($self,$cmd)=@_;
	my $sub_name = ".execConsoleCmd";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
#	$logger->debug(__PACKAGE__ . ".sub_name Entered");
	if ($self->{IN_CONSOLE}) {
		my @cmdResults = $self->execCmd($cmd);
		return @cmdResults;
	} else {
		&error(__PACKAGE__ . "$sub_name called, but /SP/console not started - logical error - fix your code...");
	}
}

=head1 execCmd()

=over

=item DESCRIPTION: 

Execute a command on the ILOM CLI. 

=item ARGUMENTS:

$obj->execCmd("command to execute");

=item RETURNS:

Array with the results of the command (SUCCESS)
Calls &error if an error is detected - the ILOM is so low-level that if interaction with it is broken - we cannot continue testing using it. If you really want to handle errors yourself - wrap the call in an eval{} block and check $@

=item AUTHOR: Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut 

sub execCmd {  
	my ($self,$cmd)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
	my(@cmdResults,$timestamp);
	$logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
	$timestamp = $self->getTime();
	unless (@cmdResults = $self->{conn}->cmd(String =>$cmd)) {
	# Section for command execution error handling - CLI hangs, etc can be noted here.
		$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
		$logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
		$logger->warn(__PACKAGE__ . ".execCmd  $cmd");
		$logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
		chomp(@cmdResults);
		map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
		$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
		&error(__PACKAGE__ . ".execCmd CLI CMD ERROR - EXITING");
	};
	chomp(@cmdResults);
	@cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
	push(@{$self->{HISTORY}},"$timestamp :: $cmd");

	return @cmdResults;

}

=head1 startConsole() 

=over

=item DESCRIPTION: 

Start /SP/console to allow access to the hosts linux/unix shell running on the main CPU.

=item ARGUMENTS: 

None

=item AUTHOR: Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut

sub startConsole {
	my ($self)=@_;
	my $sub_name = ".startConsole";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
	$logger->debug(__PACKAGE__ . "$sub_name --> Entered");
	$self->{conn}->print("start -f /SP/console");
	$logger->debug(__PACKAGE__ . "$sub_name Trying to start /SP/console - waiting for confirmation question");
	unless($self->{conn}->waitfor(String => 'Are you sure you want to start /SP/console (y/n)?')) {
		$logger->error(__PACKAGE__ . "$sub_name FAILED to get confirmation question [Return 0]");
        	$logger->debug(__PACKAGE__ . ".$sub_name Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name Session Input Log is: $self->{sessionLog2}");
		return 0;
	}
	$logger->debug(__PACKAGE__ . "$sub_name Got confirmation question - sending affirmative response");
	$self->{conn}->print("y");
	my ($prematch,$match) = $self->{conn}->waitfor(String => 'Serial console started.  To stop, type ESC (',
                                                 String => 'Serial console started.  To stop, type #.');

	if ($match =~ m/ESC \(/) {
		$logger->debug(__PACKAGE__ . "$sub_name Detected ILOM v3.x firmware - Setting console stop command to ESC (");
		$self->{STOPCMD1} = ''; # ESC
		$self->{STOPCMD2} = '(';
	} elsif ($match =~ m/\#\./) {
		$logger->debug(__PACKAGE__ . "$sub_name Detected ILOM v2.x firmware - Setting console stop command to #.");
		$self->{STOPCMD1} = '#'; 
		$self->{STOPCMD2} = '.';
	} else {
		$logger->error(__PACKAGE__ . "$sub_name FAILED to start /SP/console [Return 0]");
		$logger->debug(__PACKAGE__ . "$sub_name prematch: $prematch match: $match");
		return 0;
	}

	$logger->info(__PACKAGE__ . "$sub_name Serial console is started - SUCCESS");
	$self->{IN_CONSOLE} = 1;
	return 1;
}

=head1 stopConsole() 

=over

=item DESCRIPTION:

Stop /SP/console and fall-back to allow access to ILOM CLI interface.
Sends either "ESC (" or "#." depending on which ILOM firmware version was detected in startConsole(), 
this should drop back to the ILOM prompt

=item ARGUMENTS:

None

=item RETURNS:

1 if the ILOM prompt is detected and /SP/console stopped
0 otherwise.

If called when startConsole has not been previously called - the command will detect this logical error by the caller and &error out to allow the user to fix their code :)

=item AUTHOR: 

Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut

sub stopConsole {
	my ($self)=@_;
	my $sub_name = ".stopConsole";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
	$logger->debug(__PACKAGE__ . "$sub_name --> Entered");
	if($self->{IN_CONSOLE}) {
		$self->{IN_CONSOLE} = 0;
		$logger->info(__PACKAGE__ . "$sub_name Stopping /SP/console - falling back to ILOM prompt");
		$self->{conn}->put(Telnetmode => 0, String => $self->{STOPCMD1}); 
		$self->{conn}->put(Telnetmode => 0, String => $self->{STOPCMD2});
		my $retval = $self->{conn}->waitfor('/-> /'); 
		$logger->info(__PACKAGE__ . "$sub_name <-- Returning [$retval]");
	} else {
		&error(__PACKAGE__ . "$sub_name called, but have not started /SP/console - check your code");
	}
		
}

=head1 consoleLogin()

=over

=item DESCRIPTION:

This subroutine performs the (linux/solaris) console login via the ILOM object. Since this is a persistent serial console, it may be left logged in or in a strange state by the previous user. This function attempts to work around common scenarios to get the caller to a unix prompt as the requested user.

=item ARGUMENTS:

$obj->consoleLogin($user,$pass); # Linux/Solaris username/password.

=item RETURNS:

1 - Success - The object is at the shell prompt logged in as the requested user.
0 - Failure - Many reasons - see event log output.

=item AUTHOR:

Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut

sub consoleLogin {

	my ($self, $shell_user, $shell_password) = @_;
	my $sub_name = ".consoleLogin";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	unless($self->{IN_CONSOLE}) {
			&error(__PACKAGE__ . "$sub_name Have not switched to /SP/console (did you forget to call startConsole()?")
	}

	my $mainMaxIter = 3; # Chosen to allow us to exit an su'd shell, the main shell, and have a 3rd iteration to successfully log in. No-one should *need* more nested shells than that - but then again - no-one should leave the console in a funky state in the first place ;-)

	MAINLOOP: while ($mainMaxIter) {
	# First - let's look for a login: prompt. Giving the serial console a few prods to wake it up.

		my $loginMaxIter = 3;
		$self->{conn}->print(""); # May need to send CR to awaken console
		while($loginMaxIter and not $self->{conn}->waitfor(Match => '/login:/i', Timeout => 1)) {
			$logger->debug(__PACKAGE__ . "$sub_name Waiting for login prompt... ($loginMaxIter)");
			$self->{conn}->print(""); # Send CR to awaken console/or get back to 'login:' prompt if we were at 'password:' prompt.
			$loginMaxIter -= 1;
		}
		if($loginMaxIter) {
			$logger->debug(__PACKAGE__ . "$sub_name Got login prompt - sending '$shell_user' and waiting for password prompt");
			$self->{conn}->print($shell_user); 
			if($self->{conn}->waitfor('/password:/i')) {
				$logger->debug(__PACKAGE__ . "$sub_name Got password prompt - sending \$shell_password and waiting for shell prompt");
				unless($self->{conn}->cmd($shell_password)) { 
				# Use of CMD above is intentional - as we should match a shell prompt on success
					$logger->error(__PACKAGE__ . "$sub_name Failed to find shell prompt after password entry - FAILED");
				        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
				        $logger->debug(__PACKAGE__ . ".$sub_name Session Dump Log is : $self->{sessionLog1}");
				        $logger->debug(__PACKAGE__ . ".$sub_name Session Input Log is: $self->{sessionLog2}");
					return 0;
				} else { 
					last MAINLOOP;
				}
			} else {
				$logger->error(__PACKAGE__ . "$sub_name  Didn't find password prompt after login: - FAILED");
				return 0;
			}
		} else {
			$logger->warn(__PACKAGE__ . "$sub_name Didn't find login prompt, exhausted retries - checking if we're already in an existing shell");
			$self->{conn}->print('echo $0');
			if ($self->{conn}->waitfor('/sh/')) { # Will match sh, bash, ksh, tcsh etc.
				$logger->info(__PACKAGE__ . "$sub_name Found existing shell session - sending exit and starting over");
				$self->{conn}->print('exit');
				$mainMaxIter -= 1;
				next MAINLOOP;
			} else {
				$logger->error(__PACKAGE__ . "$sub_name Login failed and didn't find existing shell session - unable to figure out state - FAILED");
			        $logger->debug(__PACKAGE__ . ".$sub_name Session Dump Log is : $self->{sessionLog1}");
			        $logger->debug(__PACKAGE__ . ".$sub_name Session Input Log is: $self->{sessionLog2}");
				return 0
			}

		}
	}

	if($mainMaxIter) {
	# If we get here - we're at the linux shell as $shell_user
		$logger->info(__PACKAGE__ . "$sub_name <-- Exit : SUCCESS");
		return 1;
	} else {
		$logger->warn(__PACKAGE__ . "$sub_name <-- Exit : FAILED");
		return 0;
	}
	die "Unreachable";

}
=head1 executeSu()

=over

=item DESCRIPTION:

Execute 'su - <user>' to become some other user (e.g. root)

=item ARGUMENTS:

$obj->executeSu($user,$pass) 
Where user/pass are the username and password for the desired user

=item RETURNS:

1 - Success (You are now the requested user)
0 - Failure

=item AUTHOR:

Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut

sub executeSu {
	my ($self, $root_user, $root_password) = @_;
	my $sub_name = ".executeSu";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	unless($self->{IN_CONSOLE}) {
		&error(__PACKAGE__ . "$sub_name Have not switched to /SP/console (did you forget to call startConsole()?")
	}
	$logger->info(__PACKAGE__ . "$sub_name : Attempting su - $root_user with password \$root_password");
	$self->{conn}->print("su - $root_user"); 
	if($self->{conn}->waitfor('/password:/i')) {
		$logger->debug(__PACKAGE__ . "$sub_name : Got password prompt");
		$self->{conn}->print($root_password); 
		my ($prematch, $match);
		unless ( ($prematch, $match) = $self->{conn}->waitfor(
								-match => '/incorrect password/',
								-match => $self->{PROMPT},
								-errmode   => "return",
								)) {
			$logger->error(__PACKAGE__ . "$sub_name:  Unknown error on password entry.");
        		$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
		        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
			$logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [0]");
			return 0;
		}
		if ( $match =~ m/incorrect password/ ) {
			$logger->error(__PACKAGE__ . "$sub_name:  Password used \(\"$root_password\"\) for su was incorrect.");
			$logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [0]");
			return 0;
		}
		else {
			$logger->info(__PACKAGE__ . "$sub_name:  Password accepted for \'su\' - SUCCESS");
			$logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [1]");
			return 1;
		}
	} else {
		$logger->error(__PACKAGE__ . "$sub_name Didn't find password prompt after su -");
		$logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [0]");
		return 0;
	}
	die "Unreachable";
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

# Override the DESTROY method inherited from Base.pm in order to remove any config if we bail out.

sub DESTROY {
				my ($self,@args)=@_;
				my ($logger);
				my $sub_name = ".DESTROY";
				if(Log::Log4perl::initialized()){
								$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
				}else{
								$logger = Log::Log4perl->easy_init($DEBUG);
				}
				$logger->info(__PACKAGE__ . "$sub_name <-- Entered");

				if($self->{IN_CONSOLE}) {
								$self->stopConsole;
				}

#TOOLS-5980 fix begin
#Given that there is a max limit on number of SSH connections set to 5 for iLO on HP servers, we will be resettin the iLO before destroying the object to ensure that no stale connection remains. 
#This will render the iLO unusable for 10-15s. Considering that the lack of this will restrict the number of successive testcases which access iLO to 5, the tradeoff here seems reasonable at this point.
        			my($cmd,@results);
			        @results = $self->{conn}->cmd("cd /SP");
			        if ( grep(/FAILED/i, @results )) {
					unless ( $self->execCmd("cd /map1") ){
						$logger->error(__PACKAGE__ . "$sub_name:  Failed to change the directory to \[/map1\]");
                                	        $logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [0]");
                                	        return 0;
					}
                			$self->{conn}->print("reset");
                			my ($prematch, $match);
                			unless ( ($prematch, $match) = $self->{conn}->waitfor(
                			                                                -match => '/CLI session stopped/',
                			                                                -errmode   => "return",
                			                                                )) {
                			        $logger->error(__PACKAGE__ . "$sub_name:  Failed to kill ssh connection by resetting the iLO.");
					        $logger->debug(__PACKAGE__ . ".$sub_name:Session Dump Log is : $self->{sessionLog1}");
					        $logger->debug(__PACKAGE__ . ".$sub_name:Session Input Log is: $self->{sessionLog2}");
                			        $logger->debug(__PACKAGE__ . "$sub_name: <-- Leaving sub [0]");
                			        return 0;
                			}
					$logger->info(__PACKAGE__ . "$sub_name: Successfully killed SSH connection to iLO");
				}
#TOOLS-5980 fix ends

# Fall thru to regulare Base::DESTROY method.
				SonusQA::Base::DESTROY($self);
				$logger->info(__PACKAGE__ . "$sub_name --> Exiting");
}

1;

=head1 TEST CODE 

	The following code can be extracted and used to test the module - it is included here as additional examples of how (not) to use this module:

	Please change the IP address before attempting to execute it!

=cut

# vim: set ts=2:

