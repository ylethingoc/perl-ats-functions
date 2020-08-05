package SonusQA::SGX4000::SGX4000HELPER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Switch;
use WWW::Curl::Easy;
use SonusQA::ILOM;

=head1 NAME

SonusQA::SGX4000::SGX4000HELPER class

=head1 SYNOPSIS

use SonusQA::SGX4000:SGX4000HELPER;

=head1 DESCRIPTION

SonusQA::SGX4000::SGX4000HELPER provides a SGX4000 infrastructure on top of what is classed as base SGX4000 functions. These functions are SGX4000 specific. It maybe that functions here are also for SGX4000 automation harness use. In this case, as the harness infrastructure becomes more generic, those functions will be taken out of this helper module.

=head1 AUTHORS

Stuart Congdon (scongdon@sonusnet.com)

=head2 connectAny()

DESCRIPTION:

    This subroutines takes an array of SGX4000 CEs and tries to connect to each alternately in order to find any connection to the system. The idea is to try and find the connection to the CLI. The IP address information is taken from TMS, so each entry in the array should be a tms alias. The login user and password are also taken from TMS as this function uses SGX4000::newFromAlias to handle the connection and resolution of the tms alias.

=over 

=item ARGUMENTS:

    -devices    - An array of tms aliases. The array should ideally represent a single or dual CE.
    -debug      - Should you want to enable session logs, use this flag.
    -timeToWaitForConn - optional time in seconds to keep retrying if connect attempts to both CEs fail. Will retry every 5 seconds during this time. By default will not retry. 

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::newFromAlias

=item OUTPUT:

    0      - fail
    $obj   - on success the reference to the connection object is returned

=item EXAMPLE:

    unless ( my $cli_session = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => ["asterix", "obelix"], -debug => 1 )) {
        $logger->debug(__PACKAGE__ . " ======: Could not open session object to required SGX4000");
        return 0;
    }

=back 

=cut

sub connectAny {

    my %args = @_;

    my @device_list = @{ $args{ -devices } } if defined $args{ -devices };
    my $debug_flag  = $args{ -debug   };
    my $user        = $args{ -user   };
    my $timeout;

    my $sub_name = "connectAny";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Check if $ats_obj_type is defined and not blank
    unless ( $#device_list >= 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Error with array -devices:\n@device_list" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ( defined ( $args{-debug} ) && $args{-debug} == 1 ) {
        $debug_flag = $args{-debug};
    }
    else {
        $debug_flag = 0;
    }

    if ( defined ( $args{-user} ) ) {
        $user = $args{-user};
    }
    else {
        $user = "admin";
    }

    if ( defined ( $args{-defaulttimeout} ) ) {
       $timeout = $args{-defaulttimeout};
    } else {
       $timeout = 60;
    }


	my $connAttempts = 1;  # default number of connection attempts
	my $retryInterval = 5; 

    if ( defined $args{-timeToWaitForConn}) {
        # convert time in seconds to number of attempts required
        if ($args{-timeToWaitForConn} >= $retryInterval) {
        $connAttempts = int($args{-timeToWaitForConn} / $retryInterval);
    }
    } else {
        $connAttempts = 12;
        $logger->debug(__PACKAGE__ . ".$sub_name: No user specifified setting - Setting connection attempts to $connAttempts");
    }

	while ( $connAttempts > 0 ) {
	  foreach ( @device_list ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Attempting connection to ${_}.");		
		if ( my $connection = SonusQA::SGX4000::newFromAlias( 
															 -tms_alias      => $_, 
															 -obj_type       => "SGX4000", 
															 -return_on_fail => 1,
															 -sessionlog     => $debug_flag,
															 -user           => $user,
															 -defaulttimeout => $timeout,
                                                                                                                         -obj_hostname => "$_",
															)
		   ) {
                  $connection->{HA_ALIAS} = \@device_list;
		  $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $_ successful.");
		  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [obj:$_]");
		  return $connection; 
        }
        else {
		  $logger->debug(__PACKAGE__ . ".$sub_name:  Connection attempt to $_ failed.");
        }
	  }

	  if ( --$connAttempts > 0) {
		$logger->error(__PACKAGE__ . ".$sub_name:  Waiting $retryInterval seconds before retrying connection attempt -- Attempts remaining = $connAttempts ");
		sleep $retryInterval;
	  }
	}	

	$logger->error(__PACKAGE__ . ".$sub_name:  Connection attempt to all hosts failed.");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return 0;
}

=head2 unhideDebug()

DESCRIPTION:

    This subroutine is used to reveal debug commands in the SGX4000 CLI. It basically issues the unhide debug command and deals with the prompts that are presented.

=over 

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The SGX4000 root user password (needed for 'unhide debug')

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::unhideDebug ( $cli_session, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        return 0;
    }

=back

=cut

sub unhideDebug {

    my $cli_session   = shift;
    my $root_password = shift;

    my $sub_name = "unhideDebug";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $cli_session->{conn}->errmode("return");

    # Execute unhide debug 
    unless ( $cli_session->{conn}->print( "unhide debug" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'unhide debug\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[ok\]/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => $cli_session->{PROMPT},
                                                                )) {    
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'unhide debug\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched Password: prompt");

        # Give root password
        $cli_session->{conn}->print( $root_password );

        unless ( $cli_session->{conn}->waitfor( 
                                                -match => '/\[ok\]/',   
                                                -match => '/\[error\]/', 
                                              )) {    
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
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

=head2 enterLinuxShellViaDsh()

DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the SGX4000 CLI commands.

=over 

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh')
    3rd Arg    - The SGX4000 root user password (needed for 'unhide debug')

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGXHELPER::unhideDebug

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::enterLinuxShellViaDsh ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        return 0;
    }

=back 

=cut

sub enterLinuxShellViaDsh {

    my $cli_session     = shift;
    my $user_password   = shift;
    my $root_password   = shift;

    my $sub_name = "enterLinuxShellViaDsh";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $cli_session->{conn}->errmode("return");

    # Execute unhide debug 
    unless ( unhideDebug ( $cli_session, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($prematch, $match);

    # Execute dsh 
    unless ( $cli_session->{conn}->print( "dsh" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'dsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'dsh\'");

    unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
                                                                    -match     => '/Do you wish to proceed <y\/N>/i',
                                                                )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'dsh\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/<y\/N>/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched: Do you wish to proceed, entering \'y\'...");
        $cli_session->{conn}->print("y");
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                     -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'y\' to Do you wish to proceed prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/\(yes\/no\)/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes/no prompt for RSA key fingerprint");
        $cli_session->{conn}->print("yes");
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'yes\' to RSA key fingerprint prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched password: prompt");
        $cli_session->{conn}->print($user_password);
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                -match => '/Permission denied/',   
                                                -match => '/linuxadmin/', 
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/Permission denied/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($user_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        elsif ( $match =~ m/linuxadmin/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password used \$user_password accepted for \'dsh\'");
            }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($user_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
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

=head2 enterLinuxShellViaDshBecomeRoot()

DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the SGX4000 CLI commands. Once at the linux shell it will issue the su command to become root.

=over 

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh')
    3rd Arg    - The SGX4000 root user password (needed for 'unhide debug' and 'su -')

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGXHELPER::unhideDebug
    SonusQA::SGX4000::SGXHELPER::enterLinuxShellViaDsh

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::enterLinuxShellViaDshBecomeRoot ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell and become root via Dsh.");
        return 0;
    }

=back 

=cut

sub enterLinuxShellViaDshBecomeRoot {

    my $cli_session     = shift;
    my $user_password   = shift;
    my $root_password   = shift;

    my $sub_name = "enterLinuxShellViaDshBecomeRoot";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $cli_session->{conn}->errmode("return");

    # Execute enterLinuxShellViaDsh
    unless ( enterLinuxShellViaDsh ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot \'enterLinuxShellViaDsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered Linux shell");

    # Become Root using `su -`
    unless ( $cli_session->{conn}->print( "su -" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'su -\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'su -\'");
    
    my ($prematch, $match);
    unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                                    -match     => '/[P|p]assword:/',
                                                                    -errmode   => "return",
                                                                )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected Password prompt after \'su -\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched \'Password:\' prompt");

        $cli_session->{conn}->print( $root_password );

        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                -match => '/try again/',
                                                -match => $cli_session->{PROMPT},
                                                -errmode   => "return",
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/try again/ ) {
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

=head2 clearSgxConfigDatabase()

DESCRIPTION:

    This subroutine is used to clear the configuration database on the named CEs. This function is intended for use on a Single CE or a Dual CE system. When clearing the database on a Dual CE, it is important to ensure both CEs are brought down, configuration wiped and brought back up in a coordinated manner. At present the way this is done is through the Linux shell of each box using the removecdb.sh script.

=over 

=item ARGUMENTS:

    1st Arg    - Array of tms aliases that compose the SGX4000 system 

=item PACKAGE:

    SonusQA::SGX4000::SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::ATSHELPER::newFromAlias
    SonusQA::SGX4000::execShellCmd

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::clearSgxConfigDatabase( "asterix", "obelix" ) ) {
        $logger->error(__PACKAGE__ . " ======: Could not clear the CE database."); 
        return 0;
    }

=back

=cut

sub clearSgxConfigDatabase {

    my @tms_aliases = @_;

    my $sub_name = "clearSgxConfigDatabase";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my %ce;     # Hash for storing CE information
    my ( @ce_shell_sessions, $shell_session );

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( @tms_aliases ) { 
        $logger->error(__PACKAGE__ . ".$sub_name:  Please provide at least one tms alias");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if (@tms_aliases > 2 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Please only provide 1 or 2 tms aliases, ie. a single or dual CE");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    # Login into the Linux shell as root 
    foreach ( @tms_aliases ) {
        my $alias_hashref = SonusQA::Utils::resolve_alias($_);
        unless ( $shell_session = SonusQA::TOOLS->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$alias_hashref->{CONFIG}->{1}->{HOSTNAME}",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
					     -sys_hostname 	=> "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             -sessionlog        => 1,
                                            ) ) {
            closeSGXSSHConnections(@ce_shell_sessions);
            $logger->error(__PACKAGE__ . " ======: Could not open a shell session to $_");
            return 0;
        }
        push @ce_shell_sessions, $shell_session;
    }

    my $ce_index = 0;

    foreach ( @ce_shell_sessions ) {
        
        my $cli_session = $_;

        # Get ceName and peerName
        unless ( SonusQA::SGX4000::execShellCmd( $cli_session, "cat /opt/sonus/sgx.conf" ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot execute command: $cli_session->{LASTCMD}\n@{ $cli_session->{CMDRESULTS}}.");
            closeSGXSSHConnections(@ce_shell_sessions);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        

        foreach ( @{ $cli_session->{CMDRESULTS} } ) {
            if ( /systemName=(\S+)\s*$/ ) {
                $ce{ $ce_index.":system" } = $1;
            }
            elsif ( /ceName=(\S+)\s*$/ ) {
                $ce{ $ce_index.":name" } = $1;
            }
            elsif ( /^peerCeName=(\S*)\s*$/ ) {  
                $ce{ $ce_index.":peer" } = $1;
                unless ( $ce{ $ce_index.":peer" } ) {
                    $ce{ $ce_index.":peer" } = "NONE";
                    $ce{ $ce_index.":type" } = "single";
                    if ( $ce_index ) {
                        # We are onto the 2nd round here
                        if ( $ce{ "0:type" } eq "dual" ) {
                            $logger->error(__PACKAGE__ . ".$sub_name:  One of these systems is marked as a Dual CE, the other is not.");
                            $logger->debug(__PACKAGE__ . ".$sub_name:        CE name\t/ CE peer");
                            $logger->debug(__PACKAGE__ . ".$sub_name:  CE0:  ".$ce{ "0:name" }."\t/ ".$ce{ "0:peer" });
                            $logger->debug(__PACKAGE__ . ".$sub_name:  CE1:  ".$ce{ "1:name" }."\t/ ".$ce{ "1:peer" });
                            closeSGXSSHConnections(@ce_shell_sessions);
                            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                            return 0;
                        }
                        else {
                            # This means we have 2 single CEs best make sure they're not the same machine
                            if ( ( $ce{ "0:name" } eq $ce{ "1:name" } ) and ( $ce{ "0:system" } eq $ce{ "1:system" } ) ) {
                                $logger->error(__PACKAGE__ . ".$sub_name:  The same single CE has been specified twice.");
                                closeSGXSSHConnections(@ce_shell_sessions);
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                                return 0;
                            }
                        }
                    } # End if ce1
                    else {
                        # Still on 1st time through for single CE... nothing to check.
                    }
                } # End if peerCE is blank

                else { # peerCE is not blank
                    $ce{ $ce_index.":type" } = "dual";
                    if ( $ce_index ) {
                        $logger->debug(__PACKAGE__ . ".$sub_name:  \"Cougar: I'm gonna break high and right, see if he's really alone.\"");
                        # We are onto the 2nd round here
                        if ( $ce{ "0:type" } eq "single" ) {
                            $logger->error(__PACKAGE__ . ".$sub_name:  One of these systems is marked as a Dual CE, the other is not.");
                            $logger->debug(__PACKAGE__ . ".$sub_name:        CE name\t/ CE peer");
                            $logger->debug(__PACKAGE__ . ".$sub_name:  CE0:  ".$ce{ "0:name" }."\t/ ".$ce{ "0:peer" });
                            $logger->debug(__PACKAGE__ . ".$sub_name:  CE1:  ".$ce{ "1:name" }."\t/ ".$ce{ "1:peer" });
                            closeSGXSSHConnections(@ce_shell_sessions);
                            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                            return 0;
                        }
                        else {
                            # Dual CE and we have both CEs, best make sure they match up
                            unless ( ( $ce{ "0:name" } eq $ce{ "1:peer" } ) && ( $ce{ "1:name" } eq $ce{ "0:peer" } ) && ( $ce{ "0:system" } eq $ce{ "1:system" } ) ) { 
                                $logger->error(__PACKAGE__ . ".$sub_name:  These 2 systems do not match up as a Dual CE.");
                                $logger->debug(__PACKAGE__ . ".$sub_name:        CE name\t/ CE peer\t/ System name");
                                $logger->debug(__PACKAGE__ . ".$sub_name:  CE0:  ".$ce{ "0:name" }."\t/ ".$ce{ "0:peer" }."\t/ ".$ce{ "0:system" });
                                $logger->debug(__PACKAGE__ . ".$sub_name:  CE1:  ".$ce{ "1:name" }."\t/ ".$ce{ "1:peer" }."\t/ ".$ce{ "1:system" });
                                closeSGXSSHConnections(@ce_shell_sessions);
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                                return 0;
                            }    
                        } #-> End else not single CE
                    } #-----> End if ce1
                } #---------> End else peerCE not blank
            } #-------------> End elseif peerCE regexp match
        } #-----------------> End scan of CEs sgx.conf

        unless ( $ce{ $ce_index.":name" } && $ce{ $ce_index.":peer" } ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not find name or peerName from sgx.conf\n@{ $cli_session->{CMDRESULTS} }");
            closeSGXSSHConnections(@ce_shell_sessions);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Found ".$ce{ $ce_index.":type" }." CE: ".$ce{ $ce_index.":name" }." with Peer CE: ".$ce{ $ce_index.":peer" });
        $ce_index++;    
    } # End foreach CE

    # If we're here, we should have either 2 different single CEs or a matching Dual CE system. So we should be good to wipe them
    # Check status of CEs
    foreach ( @ce_shell_sessions ) {
        my $cli_session = $_;
        if ( SonusQA::SGX4000::execShellCmd($cli_session, "service sgx status" ) ) {
            $ce{ $cli_session->{OBJ_HOSTNAME} } = "RUNNING";   
            $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} \n  @{ $cli_session->{CMDRESULTS} }");
        }
        else {

            # TO DO: service sgx status returns a variety of return codes
            # To make things more comprehensive, and if these codes are standardised
            # we can operate on them.

            $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} \n  @{ $cli_session->{CMDRESULTS} }");

            foreach ( @{ $cli_session->{CMDRESULTS} } ) {
                if ( /NimProcess is stopped/ ) {
                    $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} is STOPPED");
                    $ce{ $cli_session->{OBJ_HOSTNAME} } = "STOPPED";   
                }   
            }       
        }
        unless ( $ce{ $cli_session->{OBJ_HOSTNAME} } ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot query service sgx status on CE: $cli_session->{OBJ_HOSTNAME}\n@{ $cli_session->{CMDRESULTS} }");
            closeSGXSSHConnections(@ce_shell_sessions);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }      

    #
    # Clear database
    #

    $logger->debug(__PACKAGE__ . ".$sub_name:  \"Maverick: I'll hit the brakes, he'll fly right by.\"");

    # First stop the service

    my $cmdString = "service sgx stop";
    # Each command needs to happen on each CE one at a time.
    foreach ( @ce_shell_sessions ) {

       my $cli_session = $_;

# REMOVED AS PER CQ-SONUS00130566 
####################################################################
#       if (  $ce{ $cli_session->{OBJ_HOSTNAME} } eq "STOPPED"  ) {
#          # Do not stop it if its already stopped
#          next;
#       }
####################################################################

       $logger->debug(__PACKAGE__ . ".$sub_name: Executing $cmdString");
       SonusQA::SGX4000::execShellCmd($cli_session, "$cmdString" );

       $logger->debug(__PACKAGE__ . ".$sub_name: cmd results \n @{ $cli_session->{CMDRESULTS} }");

       #Wait for a second and check the status
       sleep 1;

       my $index = 0;
       my $serviceStopped = 0;

       while ($index < 6) {
          SonusQA::SGX4000::execShellCmd($cli_session, "service sgx status");

          $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} \n  @{ $cli_session->{CMDRESULTS} }");
          foreach ( @{ $cli_session->{CMDRESULTS} } ) {
             if ( /NimProcess is stopped/ ) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} is STOPPED");
                $ce{ $cli_session->{OBJ_HOSTNAME} } = "STOPPED";
                last;
             }
          }
          if (  $ce{ $cli_session->{OBJ_HOSTNAME} } eq "STOPPED"  ) {
             last;
          }
          $index++;
          $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} Services are not stopped. Waiting for 10secs. Attempt $index");
          sleep 10;
       }
    }

    my @clear_db_cmds = (
                            "/opt/sonus/sgx/scripts/removecdb.sh",
                            "service sgx start",
                        ); 


    foreach ( @clear_db_cmds ) {
        my $command = $_;
        # Each command needs to happen on each CE one at a time.
        foreach ( @ce_shell_sessions ) {
            
            my $cli_session = $_;

            if ( $ce{ $cli_session->{OBJ_HOSTNAME} } ne "STOPPED" ) {
               $logger->error(__PACKAGE__ . ".$sub_name:  Unable stop the sevice");
               return 0;
            }
            my $default_timeout = $cli_session->{DEFAULTTIMEOUT};

            $cli_session->{DEFAULTTIMEOUT} = 30;

            # Issue removecdb or start
            unless ( SonusQA::SGX4000::execShellCmd( $cli_session, "$command" ) ) {
                foreach ( @{ $cli_session->{CMDRESULTS} } ) {
                    if ( /remove \`\*\.xml\'/ or /cannot remove \`\*\.cdb\'/ ) {
                        # This is an acceptable error which can be seen on the 
                        # standby CE
                        $logger->debug(__PACKAGE__ . ".$sub_name:  \"rm: cannot remove `*.xml' or rm: cannot remove `*.cdb': No such file or directory\" is an acceptable error");
                        last;
                    }
                    elsif ( $_ = @{ $cli_session->{CMDRESULTS} }[-1] ) {
                        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to execute command: $command\n@{$cli_session->{CMDRESULTS}}");
                        closeSGXSSHConnections(@ce_shell_sessions);
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                        return 0;
                    }             
                } 
            }
            $logger->debug(__PACKAGE__ . ".$sub_name:  Executed $command on $cli_session->{OBJ_HOSTNAME}"); 
            $ce{ $cli_session->{OBJ_HOSTNAME} } = "STOPPED";   
            $cli_session->{DEFAULTTIMEOUT} = $default_timeout;
            
            # To avoid confD coredump on sgx start. Possible timing issue only seen by ATS.
            sleep(2);
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Waiting 15s for all the SGX processes to come up");
    sleep 15; # Wait for some of the SGX processes to come up
  
 
    # Now wait for NimProcess to start.
    foreach ( @ce_shell_sessions ) {
        my $cli_session = $_;

        # We will be waiting for a max of 35 more seconds (7 x 5secs)
        my $timer_index = 7;
        my $waiting = 1;

        while ( $timer_index and $waiting ) {
            if ( SonusQA::SGX4000::execShellCmd($cli_session, "service sgx status" ) ) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} \n  @{ $cli_session->{CMDRESULTS} }");
                foreach ( @{ $cli_session->{CMDRESULTS} } ) {
                    if ( /NimProcess \(pid \d+\) is running.../ ) {
                        $logger->debug(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} is now running.");
                        $ce{ $cli_session->{OBJ_HOSTNAME} } = "RUNNING";   
                        $waiting = 0;
                    }       
                }       
            }
            elsif ( $cli_session->{RETURNCODE} ) { # retry again if the command returns any error code. error code has set in execShellCmd()
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Waiting for CE: $cli_session->{OBJ_HOSTNAME} to come up...");
                    sleep 5;
            }    
            else {
                $logger->error(__PACKAGE__ . ".$sub_name:  Cannot query service sgx status on CE: $cli_session->{OBJ_HOSTNAME}\n@{ $cli_session->{CMDRESULTS} }");
                closeSGXSSHConnections(@ce_shell_sessions);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            $timer_index--;
        }

        $logger->error(__PACKAGE__ . ".$sub_name:  CE: $cli_session->{OBJ_HOSTNAME} has not restarted successfully after service sgx start")
            unless ( $timer_index );
    }

    # Ensure both CEs are RUNNING
    foreach ( @ce_shell_sessions ) {
        unless ( $ce{ $_->{OBJ_HOSTNAME} } eq "RUNNING" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CE: $_->{OBJ_HOSTNAME} is not running.");
            closeSGXSSHConnections(@ce_shell_sessions);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    closeSGXSSHConnections(@ce_shell_sessions);
    # Done.
    $logger->debug(__PACKAGE__ . ".$sub_name:  CE database clearing complete.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
        
}

=head2 waitForSystemProcessRunning()

DESCRIPTION:

    This function checks a SGX4000 process's status. If it is not running, this function will wait for the given timeout time;

=over 

=item ARGUMENTS:

    1st Arg    - the shell session that the process will be run on;
    2nd Arg    - the process name;
    3rd Arg    - the optional timeout value ( 30 seoonds by default ), its unit is second;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGX4000HELPER::isSystemProcessRunning;

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::waitForSystemProcessRunning($shell_session,$process_name, 50) ) {
        $logger->error(__PACKAGE__ . " ======:   Failure in waiting for the $process_name process to be running.");
        return 0;
    }

=back 

=cut

sub waitForSystemProcessRunning {
    my ($shell_session,$process_name, $timeout )=@_;

    my $sub_name = "waitForSystemProcessRunning";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $cmd;
    my $process_id=undef;

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $process_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory process name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $timeout ) {
        $timeout = 30;
    }

    my ($timeout_left, $times,$result);
    $times=1;
    unless ( $timeout<10 ) {
        $times = eval $timeout/10;
        $timeout = $timeout - $times * 10 ;
    }

    for (1..$times) {
        $result= isSystemProcessRunning($shell_session,$process_name);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is not running, wait ...");
            sleep 10;
        } 
        elsif ( $result == -1 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to check the $process_name process status.");
            return 0;
        } 
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is running.");
            return 1;
        }
    }

    unless ( $timeout ) {
        $result= isSystemProcessRunning($shell_session,$process_name);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is not running, wait ...");
            sleep $timeout;
        } 
        elsif ( $result == -1 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to check the $process_name process status.");
            return 0;
        } 
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Success - the system is running.");
            return 1;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Failed - The system is running yet.");
    return -1;
}

=head2 isSystemUP()

DESCRIPTION:

    This function checks if the SGX4000 system is running on the specified CE server.

=over 

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which the SGX4000 system is running;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    -1  - function failure; 
    0   - the SGX4000 system is not up;
    1   - the SGX4000 system is up;

=item EXAMPLE:

        $result=SonusQA::SGX4000::SGX4000HELPER::isSystemUP($shell_session);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . " ======: The SGX4000 system is not up yet.");
            return 0;
        } elsif ( $result == 1) {
            $logger->debug(__PACKAGE__ . " ======: The SGX system is up.");
            return 0;
        } else {
            $logger->debug(__PACKAGE__ . " ======: Failure in checking the SGX4000 system running status.");
            return 0;
        }

=back 

=cut

sub isSystemUP {
    my ( $shell_session )=@_;

    my $sub_name = "isSystemUP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input: shell session is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    # Have tested the command manually, if the "echo ?" eq 1 or 127 , it is definitely command error.
    unless ( $shell_session->execShellCmd("service sgx status")) {
    	$logger->error(__PACKAGE__ . ".$sub_name: Failed to execute 'service sgx status'");
        $logger->debug('CMDRESULTS: '. Dumper($shell_session->{CMDRESULTS}));
        $logger->debug('RETURNCODE: '. Dumper($shell_session->{RETURNCODE}));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }
    my $ret = 1;
    foreach (@{$shell_session->{CMDRESULTS}}){
        unless ( /running/) {
            $logger->warn(__PACKAGE__ . ".$sub_name: The system is not completely up yet ");
            $logger->debug(__PACKAGE__ . ".$sub_name: $_");
            $ret = 0;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Success - the system is running.") if($ret);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
    return $ret;
}


=head2 isSystemProcessRunning()

DESCRIPTION:

    This function checks if a specified SGX4000 system process is running or not.

=over 

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which the SGX4000 system is running;
    2nd Arg    - the process name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    -1          - function failure; 
    0           - the process is not running;
    $process_id - the process is running and returns its process id;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isSystemProcessRunning($shell_session,$process_name);

=back 

=cut

sub isSystemProcessRunning {
    my ($shell_session,$process_name)=@_;

    my $sub_name = "isSystemProcessRunning";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $cmd;
    my $process_id=undef;

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    unless ( $process_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory process name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }


    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the $process_name process is running ... "); 
    $cmd=sprintf("service sgx status|grep %s",(split /_/,$process_name)[-1]);

    unless ( $shell_session->execShellCmd($cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute '$cmd' or the process name is incorect --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [-1]");
        return -1;
    }

    chomp (@{$shell_session->{CMDRESULTS}});
    if ( ${$shell_session->{CMDRESULTS}}[0] =~ /stopped/i )  {
        $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is not running.");
        return 0;
    }
    elsif ( ${$shell_session->{CMDRESULTS}}[0] =~ /\(pid\s+(\d+)\)\s+\w+\s+running/i )  {
        # NimProcess (pid 18037) is running...
        $process_id = $1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: The process information is neither in running nor stopped status");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is running and its id is:$process_id.");
    return $process_id;
}

=head2 getCoreFileInformation()

DESCRIPTION:

    This function gets the core file name and core file size data after generating a core file.

=over

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which a core file is generated;
    2nd Arg    - the core file path;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0           - fail;
    $corefile_data - an array contains a generated core file's name and size;

=item EXAMPLE:

    unless ( @corefile_data=SonusQA::SGX4000::SGX4000HELPER::getCoreFileInformation($shell_session,$corefile_path)) {
        $logger->error(__PACKAGE__ . " ======:   Failed to get core file information.");
        return 0;    
    }

=back 

=cut

sub getCoreFileInformation {

    my ($shell_session,$corefile_path) = @_;
    my $sub_name = "getCoreFileInformation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $corefile_path ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory corefile path input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if there is a core file in $corefile_path.");

    my $cmd="ls -ltr $corefile_path/core.*";
    unless ( $shell_session->execShellCmd($cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:'$cmd'--\n@{$shell_session->{CMDRESULTS}}.");
        return 0;
    }

    my @corefile_data;
    my $file_size;
    foreach (@{$shell_session->{CMDRESULTS}}) {
        chomp;
        # .trace may be attached to the corefile name;
        if ( !/trace/i and /(core\.\S+(\.\d+){1,2})/i ) {
            #                          ^-1-^
            #                ^---------2---------^
            #                $1=core file name; $2=timestamp + process id
            $file_size    = (split /\s+/,$_)[4];
            push @corefile_data,"$file_size $1";
        }
    }

    unless ( @corefile_data ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't find the expected core dump file in the $corefile_path directory.");
        return 0;
    }
    my $corefile_name = (split /\s+/,$corefile_data[-1])[-1];
    $logger->debug(__PACKAGE__ . ".$sub_name: Found the core file $corefile_name");
    return @corefile_data ;
}

=head2 killSystemProcessViaSIGILL()

DESCRIPTION:

    This function simply to kill a SGX4000 system process via 'kill -SIGILL <pid>';

=over 

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which the specified process is running;
    2nd Arg    - the process name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000:SGX4000HELPER::isSystemProcessRunning;

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::killSystemProcessViaSIGILL($shell_session,$process_name) ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to kill the $process_name process via SIGILL.");
        return 0;
    }

=back

=cut

sub killSystemProcessViaSIGILL {

    my ($shell_session,$process_name)=@_;
    
    my $sub_name = "killSystemProcessViaSIGILL";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $process_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory process name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    my $cmd;
    my $process_id;

    # when it returns 0 or -1 ... means failure...
    $process_id =isSystemProcessRunning($shell_session,$process_name);
    if ( $process_id==0 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is not in running status.");
        return 0;
    }
    elsif ( $process_id==-1 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to check the system process status.");
        return 0;
    }

    $cmd="kill -SIGILL $process_id";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending the SIGILL signal to $process_name \($process_id\):$cmd.");
    unless ($shell_session->execShellCmd($cmd)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:'$cmd'--\n@{$shell_session->{CMDRESULTS}}.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the '$cmd'");
    return 1;
}

=head2 C< getCoreFilePath >

DESCRIPTION:

    This function is to get core file path from the system table;

=over 

=item ARGUMENTS:

    1st Arg    - the current active cli session ;
    2nd Arg    - the current active CE name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000:SGX4000HELPER::getCoredumpProfileName;

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    unless (  $corefile_path = SonusQA::SGX4000::SGX4000HELPER::getCoreFilePath($cli_session,$active_ce) ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to retrieve the corefile path from the system coredumpProfile table.");
        return 0;
    }

=back 

=cut

sub getCoreFilePath {
    
    my ($cli_session,$active_ce) = @_;
    my $sub_name = "getCoreFilePath";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $active_ce ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory active ce input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Retrieve the corefile profile;

    my $coredump_profile;
    unless ( $coredump_profile=getCoredumpProfileName($cli_session,$active_ce) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory active ce input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
     my $corefile_path=undef;
    if ( $cli_session->{PLATFORM_VERSION} =~ /^V(\d{2})\.(\d{2})/ ) {
        if ( $1 == 8 ) {
           if ( $2 > 2 ) {
                 $corefile_path = "/var/log/sonus/sgx/coredump";
                 $logger->debug(__PACKAGE__ . ".$sub_name: Retrieved the core file path for Rel Ver V08.04 or higher than that.:$corefile_path.");
                 return $corefile_path;
           }
        } elsif ( $1 > 8 ) {
                 $corefile_path = "/var/log/sonus/sgx/coredump";
                 $logger->debug(__PACKAGE__ . ".$sub_name: Retrieved the core file path for Rel Ver V08.04 or higher than that.:$corefile_path.");
                 return $corefile_path;
        }
    } 

    my $cmd="show table system coredumpProfile $coredump_profile";
        $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the core file path.");
    unless ( $cli_session->execCliCmd($cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute CLI command:$cmd.--\n@{$cli_session->{CMDRESULTS}}");
        return 0;
    }

    $corefile_path=undef;
    foreach (@{$cli_session->{CMDRESULTS}}) {
        chomp;
        s/;//g;
        if (/^coredumpPath\s+(\S+)/ ) {
            #                 ^^^
            #               $1=path
            $corefile_path=$1;
            last;
        }
    }

    unless ( defined $corefile_path ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't retrieve the corefile path from the system coredumpProfile table.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieved the core file path:$corefile_path.");
    return $corefile_path;
}

=head2 retrieveDiskUsageInformation()

DESCRIPTION:

    This function is simply to retrieve the information for the disk that is used to stored the core files.

=over 

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the given CE server on which the core files are stored;
    2nd Arg    - the current active CE name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0 - fail;
    ($disk_used_space,$disk_avail_space,$disk_used_percentage,$disk_size) - success;

=item EXAMPLE:

    unless ( @corefile_disk_info=SonusQA::SGX4000::SGX4000HELPER::retrieveDiskUsageInformation($local_shell_session,$corefile_path)) {
        $logger->error(__PACKAGE__ . " ======:   Failed to retrieve the core file disk data.");
        return 0;
    }

=back 

=cut

sub retrieveDiskUsageInformation {
    my ($shell_session,$corefile_path)=@_;
    my $sub_name = "retrieveDiskUsageInformation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory input shell session is empty or blank");
        return 0;
    }
    unless ( $corefile_path ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory core file path input is empty or blank");
        return 0;
    }

    # Checking the initial disk space;

    unless ( $shell_session->execShellCmd("df --block-size=1K $corefile_path;")) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute 'df --block-size=1K'\n@{$shell_session->{CMDRESULTS}}"); 
        return 0;
    }
    
    #-------------------------------------------------------
    #[root@asterix sonus]# df --block-size=1K
    #Filesystem           1K-blocks      Used Available Use% Mounted on
    #/dev/mapper/VolGroup00-LogVol00
    #                     136010792 119204360   9785888  93% /
    #/dev/sda1               101086     15664     80203  17% /boot
    #tmpfs                  8156372       272   8156100   1% /dev/shm
    #-------------------------------------------------------

    my $disk_size=undef;
    my $disk_used_space=undef;
    my $disk_avail_space=undef;
    my $disk_used_percentage=undef;

    my %disk_info;

    foreach (@{$shell_session->{CMDRESULTS}}) {
        chomp;
        if (/\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\%)\s+/i) {
            $disk_size=$1;
            $disk_used_space=$2;
            $disk_avail_space=$3;
            $disk_used_percentage=$4;
            last;
        }
    }
    unless ( defined $disk_used_space and defined $disk_avail_space and defined $disk_used_percentage and defined $disk_size) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to get the disk information");
        return 0;
    }
    return ($disk_used_space,$disk_avail_space,$disk_used_percentage,$disk_size);
}

=head2 waitForSystemRunning()

DESCRIPTION:

    This function firstly is to check if the SGX4000 system is running on a specified CE server.
    If it is not running, this fucntion will wait for the given timeout time.

=over 

=item ARGUMENTS:

    1st Arg    - the active tms alias;
    2nd Arg    - optional timeout input, if it is not specfied, the default value is 120 seconds;
    3rd Arg    - optional time unit for each waiting period, its default value is 6 seconds;
                 For the timeout that equals 120 seconds, the loop times will be 20 (120/6);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item Output:

    -1 - function fail;
    0  - the system is not running after waiting (eg: 120 seconds by default);
    1  - the system is running after waiting (eg: 120 seconds by default);

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::waitForSystemRunning($tms_alias);

=back 

=cut

sub waitForSystemRunning {
    my ($tms_alias,$timeout,$time_unit)=@_;

    my $sub_name = "waitForSystemRunning";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($running_flag,$result,$shell_session,$loop_times);

    unless ( $tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tms alias input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return -1;
    }

    unless ( $timeout ) { $timeout = 120; }
    unless ( $time_unit ) { $time_unit=6; }

    $loop_times=1;
    unless ( $timeout<$time_unit) {
        $loop_times = eval $timeout/$time_unit;
        $timeout = $timeout - $loop_times*$time_unit;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Open a new shell session to $tms_alias");
    my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);
    unless ( $shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$tms_alias",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            ) )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't login linux shell to $tms_alias as root.");
        $shell_session->DESTROY;
        return -1;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully entered linux shell to $tms_alias via root");

    for (1..$loop_times) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the SGX4000 system is running on $tms_alias: $_ .");
        $result=isSystemUP($shell_session);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: The SGX4000 system\(on CE:$tms_alias\) is not completely running yet,waiting $time_unit seconds ...");
            sleep $time_unit;
        }
        elsif ( $result == 1) {
            $running_flag=1;    
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failure in checking the system status \(isSystemUP\).");
            $shell_session->DESTROY;
            return -1;
        }
    }

    unless ( $running_flag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed - the SGX4000 system is still not running on $tms_alias.");
        $shell_session->DESTROY;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Success - the SGX4000 system is running on $tms_alias.");
    $shell_session->DESTROY;
    return 1;
}

=head2 C< waitForRedundancySync >

DESCRIPTION:

    This function checks if the SGX4000 system is ready for Configuration after a stop/start.
    Need to wait for Redundancy Sync complete before CLI allows any commands.
    If it is not ready, this function will wait for the given timeout time.

=over 

=item ARGUMENTS:

    1st Arg    - optional timeout input, if it is not specfied, the default value is 120 seconds;
    2nd Arg    - optional time unit for each waiting period, its default value is 6 seconds;
                 For the timeout that equals 120 seconds, the loop times will be 20 (120/6);
    -addExtraWait     - pass as 1 to sleep for 30 secs before returing true from API, 30 seconds sleep is needed to ensure that the CEs are indeed in-sync.

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000.grepPattern()

=item OUTPUT:

    0  - the system is not running after waiting (eg: 120 seconds by default);
    1  - the system is running after waiting (eg: 120 seconds by default);

=item EXAMPLE:

    unless ( $sgx_obj->waitForRedundancySync() ) {
       $logger->debug(__PACKAGE__ . ".$sub : SGX Not Ready ".$TESTBED{ "sgx4000:1" }[0]. " / ".$TESTBED{"sgx4000:1" }[1]);
       return 0;        
    }

=back 

=cut

sub waitForRedundancySync {
    my ($self,%args)=@_;
    my ($running_flag,$result,$loop_times,$timeout,$time_unit);
    my $sub_name = "waitForRedundancySync";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my %a        = (-timeout => 120, -time_unit => 6, -addExtraWait => 1);
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub_name, %a );

    # Build current
    if ( length($self->{SYSfile}) <5 ) {
        $self->nameCurrentLogs();
    }

    # Get the SGX object
    my $tms_alias = $self->{OBJ_HOSTNAME};
      
    $timeout = $a{-timeout}; 
    $time_unit = $a{-time_unit};

    $loop_times=1;
    unless ( $timeout<$time_unit) {
        $loop_times = eval $timeout/$time_unit;
        $timeout = $timeout - $loop_times*$time_unit;
    }

    # Loop until Redundancy Sync or Timeout
    for (1..$loop_times) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the SGX4000 system is running on $tms_alias: $_ .");
        #$result=isSystemUP($shell_session);
        $result = $self->grepPattern(-pattern => "System redundancy group has full redundancy protection", -logType => "system");
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: The SGX4000 system\(on CE:$tms_alias\) is not completely running yet,waiting $time_unit seconds ...");
            sleep $time_unit;
        }
        elsif ( $result == 1) {
            $running_flag=1;    
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failure in checking the system status \(isSystemUP\).");
            return -1;
        }
    }

    unless ( $running_flag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed - the SGX4000 system is still not running on $tms_alias.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return 0;
    }

    if ($a{-addExtraWait} == 1) {
       $logger->debug(__PACKAGE__ . ".$sub_name: i will sleep for 30 seconds");
       sleep 30;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Success - the SGX4000 system is running on $tms_alias.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
    return 1;
}

=head2 openNewCliSession()

DESCRIPTION:

    This function opens a new CLI session to the current active CE server.

=over 

=item ARGUMENTS:

    1st Arg    - the current active tms alias;
    2nd Arg    - the hash reference linked with the TESTBED hash;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000:SGX4000HELPER::waitForSystemRunning;

=item OUTPUT:

    0  - fail;
    $testbed_hash->{"sgx4000:1:obj"} - success (the new cli session object);

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::openNewCliSession($active_ce,\%TESTBED) ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to open a new CLI session.");
        return 0;
    }

=back 

=cut

sub openNewCliSession {
    my ($tms_alias, $testbed_hash ) = @_;
    my $sub_name = "openNewCliSession";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tms alias for the current active CE server is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $testbed_hash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory TESTBED hash input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if all the sytem processes are running on the NEW ACTIVE CE server: $tms_alias");
    my $result =  waitForSystemRunning($tms_alias);
    unless ( $result == 1 ) {
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: The SGX4000 system is not running on the $tms_alias CE server.");
        } elsif ( $result == -1) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to check the SGX4000 system running status.");
        }
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: The system is going to connect to $tms_alias, waiting 5 seconds.");
    sleep 5;
    my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);
    unless( $testbed_hash->{"sgx4000:1:obj"}= SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$tms_alias",
                                             -obj_user          => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "22",
                                             -sessionlog        => 1,
                                            ) )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to open the CLI session via $tms_alias");
        return 0;
    }

    my $active_ce = $testbed_hash->{"sgx4000:1:obj"}->{OBJ_HOSTNAME};
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully opened a session to $testbed_hash->{$active_ce} \($active_ce\)."); 
    return $testbed_hash->{"sgx4000:1:obj"};
}

=head2 waitForFileWriteComplete()

DESCRIPTION:

    This functions firstly checks if the given file has been completely generated. Otherwise it will wait until timeout expires.

=over 

=item ARGUMENTS:

    1st Arg    - the shell session;
    2nd Arg    - the file name;
    3rd Arg    - optional timeout input (default waiting time = 60 seconds);
    4th Arg    - optional waiting time value for each waiting circle (default value = 10 seconds);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000:SGX4000HELPER::waitForSystemRunning;

=item OUTPUT:

    0  - fail;
    1  - success;

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::waitForFileWriteComplete($remote_shell_session,"$corefile_path/$corefile_name"))
        $logger->error(__PACKAGE__ . " ======:   Failed to wait for the core file's writing to be completed.");
        return 0;
    }

=back 

=cut

sub waitForFileWriteComplete {

    my ($shell_session,$file_name,$timeout,$time_unit)=@_;
    my $sub_name = "waitForFileWriteComplete";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking the initial disk space;

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file namen input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $timeout ) { $timeout = 60; }
    unless ( $time_unit ) { $time_unit=10; }

    my $times=1;
    unless ( $timeout<$time_unit) {
        $times = eval $timeout/$time_unit;
        $timeout = $timeout - $times*$time_unit;
    }

    # if the $timeout == 1, the running times self increase once;
    unless ( $timeout eq 0 ) {
        $times++;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the $file_name has been completely generated");

    my $cmd="ls -ltr $file_name";
    my $initial_size=0;
    my $current_size;
    
    my $default_timeout = $shell_session->{DEFAULTTIMEOUT};
    
    $shell_session->{DEFAULTTIMEOUT} = 120;
	my $loop_number;
    for(1..$times) {
        # When the disk is full (eg 100%), the response time is maybe longer than the default Timeout;
		$loop_number=$_;	
        unless ( $shell_session->execShellCmd($cmd) ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        foreach (@{$shell_session->{CMDRESULTS}}) {
            chomp;
            $current_size = (split /\s+/,$_)[4];
            if ( $initial_size eq $current_size ) {
            	if (( $current_size ne 0 ) and ($loop_number <=2 )) {
                	$logger->debug(__PACKAGE__ . ".$sub_name: The file size is still 0, waiting for $time_unit.");
                	sleep $time_unit;
				}
				else {
                    $logger->debug(__PACKAGE__ . ".$sub_name: The $file_name writing has completed as its size is not growing.");
                    $shell_session->{DEFAULTTIMEOUT}=$default_timeout;
                    return 1;
				}
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub_name: The $file_name writing is not completed yet and its size is $current_size,waiting $time_unit seconds...");
                $initial_size=$current_size;
                sleep $time_unit;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Failed to wait ${file_name}'s writing to be coemplted.");
    return 0;
}

=head2 getCoredumpProfileName()

DESCRIPTION:

    This functions is to get the coredump profile name for the current active CE.

=over 

=item ARGUMENTS:

    1st Arg    - the current active cli session;
    2nd Arg    - the active CE server name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0  - fail;
    1  - success;

=item EXAMPLE:

    unless ( $coredump_profile_name=SonusQA::SGX4000::SGX4000HELPER::getCoredumpProfileName($cli_session,$active_ce)) {
        $logger->error(__PACKAGE__ . " ======:   Failed to get the coredump profile name.");
        return 0;
    }

=back 

=cut

sub getCoredumpProfileName {

    my ( $cli_session,$active_ce) = @_;
    my $sub_name = "getCoredumpProfileName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $active_ce ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory active ce input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd="show all system serverAdmin";
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the coredump profile");
    unless ( $cli_session->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n@{$cli_session->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $ce_name = $cli_session->{CE_NAME_LONG};
    my $coredump_profile=undef;
    my $flag = 0;
    foreach ( @{$cli_session->{CMDRESULTS}}    ) {
        $flag = 1 if ($_ =~ /serverAdmin\s+(\Q$active_ce\E|\Q$ce_name\E)\s+\{/i);
        next unless $flag;
        next unless ($_ =~ /coredumpProfile\s+(\S+)\;/i);
        $coredump_profile = $1;
        last;
    }

    unless ( defined $coredump_profile ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get core dump profile --\n@{$cli_session->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the coredump profile:$coredump_profile.");
    return $coredump_profile;
}

=head2 C< getCoredumpProfileSetting >

DESCRIPTION:

    This functions is to get the coredump setting data (coredump count and space limits).

=over 

=item ARGUMENTS:

    1st Arg    - the current active cli session;
    2nd Arg    - the coredump profile name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0  - fail;
    ($coredump_count_limit,$coredump_space_limit) - success;

=item EXAMPLE:

    unless ( @coredump_data=SonusQA::SGX4000::SGX4000HELPER::getCoredumpProfileSetting($cli_session,$coredump_profile)) {
        $logger->error(__PACKAGE__ . " ======:   Failed to get the coredump profile name.");
        return 0;
    }

=back 

=cut

sub getCoredumpProfileSetting {

    my ($cli_session,$coredump_profile)=@_;
    my $sub_name = "getCoredumpProfileSetting";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $coredump_profile ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory coredump profile input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the current coredump count and space limits");
    my ($coredump_count_limit,$coredump_space_limit);
    
    my $cmd="show table system coredumpProfile $coredump_profile";
    #the commands have become the same in both pre and post 8.4 releases.
    # If version higher than or equal to V08.04 , change the command
#    if ( $cli_session->{PLATFORM_VERSION} =~ /^V(\d{2})\.(\d{2})/ ) {
#        if ( $1 == 8 ) {
#           if ( $2 > 2 ) {
#                 $cmd="show table profiles system coredumpProfile $coredump_profile";
#           }
#        } elsif ( $1 > 8 ) {
#                 $cmd="show table profiles system coredumpProfile $coredump_profile";
#        }
#    }

    unless ( $cli_session->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'--\n@{$cli_session->{CMDRESULTS}}" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach ( @{$cli_session->{CMDRESULTS}}    ) {
        if ( /^coredumpSpaceLimit\s+(\d+);/ ) {
            $coredump_space_limit=$1;
        }
        if ( /^coredumpCountLimit\s+(\d+);/ ) {
            $coredump_count_limit=$1;
        }
    }

    unless ( $coredump_space_limit ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't get $coredump_space_limit data.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $coredump_count_limit ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't get $coredump_count_limit data.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got coredump profile setting data: $coredump_count_limit\(count limit\) and $coredump_space_limit\(space limit\).");
    return ($coredump_count_limit,$coredump_space_limit);
}

=head2 setCoredumpProfile()

DESCRIPTION:

    This functions is to get the coredump setting data (coredump count and space limits).

=over 

=item ARGUMENTS:

    1st Arg    - the current active cli session;
    2nd Arg    - the coredump profile name;
    3rd Arg    - the coredump count limit;
    4th Arg    - the coredump space limit;
    5th Arg    - the coredump Level, default is normal

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0  - fail;
    1  - success;

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::setCoredumpProfile($cli_session,$coredump_profile_name,10,20, $coredump_level) ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to set coredump profile $coredump_profile_name count limit to $coredump_count_        limit and space limit to $coredump_space_limit.");
        return 0;
    }

=back 

=cut

sub setCoredumpProfile {

    my ($cli_session,$coredump_profile,$coredump_count_limit,$coredump_space_limit, $coredump_level)=@_;
    my $sub_name = "setCoredumpProfile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $coredump_profile ||= 'default';
    $coredump_level   ||= 'normal';
    
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = 'set system';
#the commands have become the same in both pre and post 8.4 releases.
#    if ($cli_session->{APPLICATION_VERSION} =~ /^\w(\d+\.\d+)\./) {
#        $cmd = 'set profiles system' if ($1 ge '08.04' );
#    }
	
    $cmd .= " coredumpProfile $coredump_profile";
    $cmd .= " coredumpLevel $coredump_level";
    $cmd .= " coredumpSpaceLimit $coredump_space_limit" if $coredump_space_limit;
    $cmd .= " coredumpCountLimit $coredump_count_limit" if $coredump_count_limit;
   
    unless ( $cli_session->execCommitCliCmd($cmd)) {

        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $cli_session->leaveConfigureSession;
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the '$cmd'.");
    return 1;
}

=head2 generateCoreFileViaLinuxShell()

DESCRIPTION:

    This function performs the core file genration funcationality via the 'kill -SIGILL process' command. It firstly removes all the files in the core file directory (/var/log/sonus/sgx/coredump), then checks if the disk empty space is larger than the given required amount (eg 2Gbytes) and the specified process is running. If these conditions are met, this function will send a SIGILL signal to the specified process.

=over 

=item ARGUMENTS:

    1st Arg    - the current active cli session;
    2nd Arg    - the process name;
    3rd Arg    - the hash reference linked with TESTBED;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000:SGX4000HELPER::getCoreFilePath;
    SonusQA::SGX4000:SGX4000HELPER::retrieveDiskUsageInformation;
    SonusQA::SGX4000:SGX4000HELPER::isSystemProcessRunning;
    SonusQA::SGX4000:SGX4000HELPER::waitForSystemRunning;
    SonusQA::SGX4000:SGX4000HELPER::killSystemProcessViaSIGILL;
    SonusQA::SGX4000:SGX4000HELPER::getCoreFileInformation;
    SonusQA::SGX4000:SGX4000HELPER::openNewCliSession;

=item OUTPUT:

    0  - fail;
    "$corefile_path:$corefile_name"  - Success;

=item EXAMPLE:

    unless ( $core_file=SonusQA::SGX4000::SGX4000HELPER::generateCoreFileViaLinuxShell($cli_session, $process_name,\%TESTBED)) {
        $logger->error(__PACKAGE__ . " ======:   Failed to generate a core file.");
        return 0;
    }

=back 

=cut

sub generateCoreFileViaLinuxShell {

    my ($cli_for_core_generation_session,$process_name,$testbed_hash)=@_;

    my $sub_name = "generateCoreFileViaLinuxShell";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    my ($shell_session, $active_ce, $cmd, $corefile_path, $tms_alias,$process_id);

    unless ( $cli_for_core_generation_session ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        return 0;
    }

    unless ( $process_name ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory process name input is empty or blank.");
        return 0;
    }

    ###############################################
    # STEP 1: Login the remote CE server as root and open a new shell session;
    ###############################################

    # Get the tms alias name before generating core file;
    $tms_alias = $cli_for_core_generation_session->{TMS_ALIAS_DATA}->{ALIAS_NAME};
    $active_ce = $cli_for_core_generation_session->{OBJ_HOSTNAME};
    my $ce_hostname = $cli_for_core_generation_session->{SYS_HOSTNAME};
    unless ( $tms_alias ) { $tms_alias=$active_ce; }

    my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);
    unless ( $shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$tms_alias",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                            ) )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't login linux shell as root.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered linux shell to $tms_alias via root");

    ###############################################
    # STEP 2: Run the testing commands:
    #   1) get the coredump path from 'show table system coredumpProfile';
    #    2) 'rm -rf /var/log/sonus/sgx/*' to clear all the fiels in this directory;
    #   3) 'ps -ef' to get the process id;
    #   4) check if the standby CE is up;
    #    5) 'kill -SIGILL $process_id';
    #    6) 'date' as to check the time when the signal sent out;
    #    7) 'ls -ltr /var/log/sonus/sgx/coredump' to check if the coredump file is here;
    ###############################################

    # Retrieve the core file path of the remote host;
    unless (  $corefile_path = getCoreFilePath($cli_for_core_generation_session,$active_ce) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to retrieve the corefile path from the system coredumpProfile table.");
        return 0;
    }

    # removing all the files from the corefile path;
    $logger->debug(__PACKAGE__ . ".$sub_name: Removing all the core files in $corefile_path");
    $cmd="rm -rf $corefile_path/core.*";    
    unless ( $shell_session->execShellCmd($cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute command:$cmd.--\n@{$shell_session->{CMDRESULTS}}");
        $shell_session->DESTROY;
        return 0;
    }

    # Checking if the disk size larger than 2Gbytes (Note: setting the block to 1k)

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the free disk size is larger than 2Gbytes.");
    my @disk_info;
    unless ( @disk_info=retrieveDiskUsageInformation($shell_session,$corefile_path)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute command:$cmd.--\n@{$shell_session->{CMDRESULTS}}");
        $shell_session->DESTROY;
        return 0;
    }
     
    unless ( $disk_info[1] >= 200000 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current disk's empty space is less than 2G, which is maybe not enough for a core file");
        $shell_session->DESTROY;
        return 0;
    }

    my $result =isSystemProcessRunning($shell_session,$process_name);
    if ( $result==0 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: The $process_name process is not in running status.");
        unless ( waitForSystemProcessRunning($shell_session,$process_name, 50) ) { 
            $logger->debug(__PACKAGE__ . ".$sub_name: Failure in waiting for the $process_name process to be running.");
            return 0;
        }
    }
    elsif ( $result==-1 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to check the system process status.");
        return 0;
    }

    #########################################
    # It is important to check if the standby CE is up;
    # Otherwise, 1) when we kill the process, the active CE will not be able to switch over to the standby CE;
    #            2) There is a possibility that the active CE becomes available ealier than the standby CE;
    #               Then the system will not be switched over, which means the cli session will be in the wrong order.
    # Checking if the standby CE is completely up;
    #########################################

    my $second_tms_alias = $testbed_hash->{"sgx4000:1:ce0"};
    unless ( $second_tms_alias ne $active_ce ) {
        $second_tms_alias = $testbed_hash->{"sgx4000:1:ce1"};
    }

    unless ( waitForSystemRunning($second_tms_alias) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: The SGX4000 system is not running on the $second_tms_alias CE server.");
        $shell_session->DESTROY;
        return 0;
    }

    # Kill the system process when the standby CE is completely up;

    unless ( killSystemProcessViaSIGILL($shell_session,$process_name) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to kill the $process_name process via SIGILL");
        $shell_session->DESTROY;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: The system is switching over, waiting 5 seconds ... ");
    sleep 5;

    $cli_for_core_generation_session->DESTROY;
    unless ( openNewCliSession($second_tms_alias,$testbed_hash) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to open a new CLI session after generating a core file on $active_ce");
        $shell_session->DESTROY;
        return 0;
    }

    # Is the core dump file in the /var/log/sonus/sgx/coredump directory...?
    my @corefile_data;
    unless ( @corefile_data = getCoreFileInformation($shell_session,$corefile_path)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't find the core file in the expected $corefile_path directory after issuing the SIGILL signal.");
        $shell_session->DESTROY;
        return 0;
    }

    # Expecting only one core file as we have already 'rm -rf *' ....
    unless ( scalar(@corefile_data) eq 1 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Expecting only one core file - @corefile_data.");
        $shell_session->DESTROY;
        return 0;
    }

    my $corefile_name=(split /\s+/,$corefile_data[0])[-1];
    $logger->debug(__PACKAGE__ . ".$sub_name: Found the core file:$corefile_name in the $corefile_path directory after issuing the SIGILL signal.");
    $shell_session->DESTROY;
    return "$corefile_path:$corefile_name";
}

=head2 generateNTPLogs()

DESCRIPTION:

  This function is to generate NTP logs via enabling and disabling ntp services on the specified CE server;
  And, it is able to generate three levels of system log events: Info, Minor and Major;

=over 

=item ARGUMENTS:

    1st Arg  - the cli session;
    2nd Arg  - the SGX4000 CE name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0  - fail;
    1  - Success;

=item EXAMPLE:

    unless (SonusQA::SGX4000::SGX4000HELPER::generateNTPLogs($cli_session,"asterix")) {
        $logger->error(__PACKAGE__ . " ======:   Failed to generate a core file.");
        return 0;
    }

=back 

=cut

sub generateNTPLogs {

    my ($cli_session,$ce_name) = @_ ;

    my $sub_name = "generateNTPLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    # Step 1: to get the ce name , inital state and ip address;

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CE name is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    my $cmd="show table ntp peerAdmin";
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the ntp setting data via '$cmd'"); 
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my ($ntp_ce_name,$ntp_ip);

    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /$ce_name/ ) {
            my @ntp_result=split;
            $ntp_ce_name   = $ntp_result[0];
            $ntp_ip        = $ntp_result[1];
            last;    
        }
    }

    unless ( $ntp_ce_name and $ntp_ip ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to retrieve the complete ntp setting data on the $ce_name server: ce name=$ntp_ce_name, ip=$ntp_ip.");
        return 0;
    }
    
    # Step 2: Enabling ntp and disabling ntp;

    #-----------------------------------------------
    #  After disabling/enabling NTP service, it should generated three levels of log events: 
    #        Info, Minor and Major;
    #-----------------------------------------------
    #152 06172009 100914.08834:1.01.08834.Minor   .CHM: *new_validate daemon id: 0, session id: 19442, worker id: 7
    #141 06172009 100914.08835:1.01.08835.Minor   .CHM: *close_validate daemon id: 0, session id: 19442
    #214 06172009 100915.08836:1.01.08836.Minor   .SM: Local server asterix.uk.sonusnet.com: NTP peer server IP address ....
    #195 06172009 100915.08837:1.01.08837.MAJOR   .SM: Local server asterix.uk.sonusnet.com: Network Timing Protocol Down. 
    #164 06172009 100915.08838:1.01.08838.MAJOR   .SM: Local server asterix.uk.sonusnet.com: All NTP servers are Out Of Sync.
    #152 06172009 100919.08839:1.01.08839.Minor   .CHM: *new_validate daemon id: 0, session id: 19443, worker id: 7
    #141 06172009 100919.08840:1.01.08840.Minor   .CHM: *close_validate daemon id: 0, session id: 19443
    #203 06172009 100919.08841:1.01.08841.Info    .SM: Local server asterix.uk.sonusnet.com: NTP peer server IP address 10.1.1.2 ...
    #174 06172009 100929.08842:1.01.08842.Minor   .SM: Local server asterix.uk.sonusnet.com: In sync with NTP server IP address ....
    #159 06172009 100929.08843:1.01.08843.Info    .SM: Local server asterix.uk.sonusnet.com: Network Timing Protocol Up.
    #----------------------------------------------------------

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $cmd = "set ntp peerAdmin $ntp_ce_name $ntp_ip state disabled";
    unless ( $cli_session->execCommitCliCmd($cmd)) {

        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }

        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $cmd = "set ntp peerAdmin $ntp_ce_name $ntp_ip state enabled";
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Left the config private mode.");

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully generated the NTP logs");
    return 1;
}

=head2 getTimestampBySecond()

DESCRIPTION:
  This function is to get the time stamp for a specified CE, which is the number of seconds since the epoch ( which is 1970-01-01 00:00:00 UTC ).

=over

=item ARGUMENTS:

   1st Arg - the shell session attached to the CE server;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0 - fail;
    $timestamp - success;

=item EXAMPLE:

    unless ($timestampe = SonusQA::SGX4000::SGX4000HELPER::getTimestampBySecond($shell_session) ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to get the time stamp.");
        return 0;
    }

=back 

=cut

sub getTimestampBySecond {

    my ($shell_session) = @_ ;

    my $sub_name = "getTimestampBySecond";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Using date to generate the current time;
    # blai@mallrats:/home/blai/ats_repos/test/Net> date +%Y-%m-%d@%H:%M:%S
    # 2009-06-09@11:59:21

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd="date +%Y-%m-%d@%H:%M:%S";

    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $current_time;
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;
        if ( /@/ ) {
            # changing the format of '2009-06-09@11:59:21' to '2009-06-09 11:59:21';
            s/@/ /g;
            $current_time=$_;
        }
    }

    unless ( $current_time ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the current time by '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # blai@mallrats:/home/blai/ats_repos/test/Net> date --date='2009-06-09 11:57:58' +%s
    # 1244545078

    $cmd="date --date='$current_time' +%s";

    $logger->debug(__PACKAGE__ . ".$sub_name: Running '$cmd' as to get time stamp informaton.");

    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $timestamp;
    unless ( $timestamp=${$shell_session->{CMDRESULTS}}[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the time stamp data via '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the time stamp data\($timestamp seconds\).");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [timestamp]");

    return $timestamp;
}

=head2 getLastTwoLogFiles()

DESCRIPTION:

 This function simply copies the last two log files into the /tmp directory and returns the file name. If there is only one log file in the log directory (var/log/sonus/sgx), it will only copy one file. This function does not involve the checking of the file count value in the eventLog table. The latest two files are known throught the command 'ls -ltr *.DBG/SYS/TRC/ACT";

=over 

=item ARGUMENTS:

   1st Arg - the shell session attached to the CE server;
   2nd Arg - the log event type ( SYS, DBG etc);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0 - fail;
    $log_file_name - success;

=item EXAMPLE:

    unless ($log_file_name = SonusQA::SGX4000::SGX4000HELPER::getLastTwoLogFiles($shell_session,$log_type) ) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get the log files.");
        return 0;
    }

=back 

=cut

sub getLastTwoLogFiles {

    my ($shell_session,$log_type) = @_ ;

    my $sub_name = "getLastTwoLogFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Step 1: check the latest log file;
#    my $latest_log_file_name="/tmp/latest.$log_type";
    my $latest_log_file_name="\/tmp\/latest.$log_type";

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    
    my $cmd="cd /var/log/sonus/sgx";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the latest two $log_type log files."); 
    
    # to check the version of SGX and go to the appropriate path.
    $cmd = "rpm -qa | grep sgx4000";
    $shell_session->execShellCmd($cmd);
    my @count = @{$shell_session->{CMDRESULTS}};
    chomp $count[0];
    $logger->debug(__PACKAGE__ . ".$sub_name: The SGX package installed is $count[0] ");
    if ( $count[0] =~ /sgx4000-V(\d{2}).(\d{2}).\d{2}-\w+\d{3}/ ) {
       if ( $1 == 8 ) {
           if ( $2 > 2 ) {
                 $cmd = 'cd /evlog';
                 $logger->debug(__PACKAGE__ . ".$sub_name: SGX package is V08.04 or higher than that. Logs Path: /var/log/sonus/sgx/evlog");
                 $shell_session->execShellCmd($cmd);
           }
        } elsif ( $1 > 8 ) {
             $cmd = 'cd /evlog';
             $logger->debug(__PACKAGE__ . ".$sub_name: SGX package is V08.04 or higher than that. Logs Path: /var/log/sonus/sgx/evlog");
             $shell_session->execShellCmd($cmd);
        }
    }

    $cmd="rm -f $latest_log_file_name";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $cmd="ls -1tr 10*.$log_type|tail -2";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @file_name;
    foreach ( @{$shell_session->{CMDRESULTS}} ) 
    {
        chomp;
        push (@file_name, $_);
    }

    if ( scalar(@file_name) eq 2 ) 
    {
        $cmd="cat $file_name[0] $file_name[1] \> $latest_log_file_name";
        unless ( $shell_session->execShellCmd($cmd)) 
        {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } 
    elsif ( scalar(@file_name) eq 1 ) 
    {
        unless ( SonusQA::SGX4000::SGX4000HELPER::removeCommandAliasSetting($shell_session,"cp") ) { 
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to removed the command alias setting for 'cp'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $cmd="cp -f @file_name $latest_log_file_name";
        unless ( $shell_session->execShellCmd($cmd)) 
        {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to locate the $log_type file.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Successfully got the latest log file: $latest_log_file_name.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [log file name]");
    return $latest_log_file_name;
}

=head2 nameLastLogFile()

DESCRIPTION:

 This function simply finds filename of the last log file and returns the file name. 

=over 

=item ARGUMENTS:

   1st Arg - the log event type ( SYS, DBG etc);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0 - fail;
    $log_file_name - success;

=item EXAMPLE:

    unless ($log_file_name = SonusQA::SGX4000::SGX4000HELPER::nameLastLogFile($log_type) ) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get the log files.");
        return 0;
    }

=back 

=cut

sub nameLastLogFile {

    my ($self,$log_type) = @_ ;

    my $sub_name = "nameLastLogFile";
    my $latest_log_file_name;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get the SGX object
    my $tmsAlias = $self->{OBJ_HOSTNAME};

    # Reuse same connection when available
    if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub_name : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias (
                                       -tms_alias    => $self->{OBJ_HOSTNAME},
                                       -obj_port     => 2024,
                                       -obj_user     => "root",
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub_name Could not open connection to SGX");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
      };
    }
    $logger->debug(__PACKAGE__ . ".$sub_name : Opened session object to $tmsAlias");
    my $shell_session = $self->{shell_session}->{$tmsAlias};
    $shell_session->{CMDRESULTS} = undef;

    my $cmd="cd $self->{LOG_PATH}";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the latest two $log_type log files.");

    $cmd="ls -ltr 10*.$log_type|tail -2";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my %checkTime;
    my %logName;
    my $count = 1;

    # In case if the timestamp matches in both the log files, return the log file with highest number. # Refer CQ - SONUS00131950
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        if ( $_ =~ /\s+(\S+)\s+(\S+)\.$log_type/i ) {
            $checkTime{$count} = $1;
            $logName{$count} = $2;
            $count += 1;
        }
    }
    if ( $checkTime{'1'} == $checkTime{'2'} ) {
        my $log_file;
        if ( $logName{1} gt $logName{2} ) {
            $log_file = $logName{1};
        } else {
            $log_file = $logName{2};
        }

        # Handle the log file rollover
        # Assumed the max filecount as 32.
        if ( $log_file == "1000020" and ( $logName{1} == "1000001" || $logName{2} == "1000001" ) ) {
            $log_file = "1000001";
        }

        $log_file = $log_file . "\." . $log_type;
        $logger->info(__PACKAGE__ . ".$sub_name: Successfully got the Current log file: $log_file.");
        return $log_file;
    }

    # Reverse order to make latest file first in list.
    foreach ( reverse @{$shell_session->{CMDRESULTS}} ) {
        chomp;
        if ( $_ =~ /\s+(\S+\.$log_type)/i ) {
            $latest_log_file_name = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: $latest_log_file_name");
        }

        if ( length($latest_log_file_name) eq 11) {
            last;
        }
    }
    if ( length($latest_log_file_name) ne 11)  {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to locate the $log_type file.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Successfully got the latest log file: $latest_log_file_name.");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [log file name]");
    return $latest_log_file_name;
}


=head2 isLogEventGenerated()

DESCRIPTION:

 This function is going to check if logs are generated according to the given key word within the specified time period (it is 60 seconds by default);
 Note, the need of using time period is that the system could delay the generation of log messages.

=over 

=item ARGUMENTS:

  1st Arg - the shell session;
  2nd Arg - the log keyword (eg Ntp );
  3rd Arg - the time stamp data;
  4th Arg - the log file name that stores the event logs;
  5th Arg - the optional checking time period;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    -1 - function fail;
     0 - log not generated;
     1 - success, log generated;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isLogEventGenerated($active_shell_session,"(Delete|Add)NtpPeer",$time_stamp,$log_file_name); 

=back 

=cut

sub isLogEventGenerated {

    my ($shell_session,$log_keyword,$time_stamp,$file_name,$checking_time_period) = @_ ;

    my $sub_name = "isLogEventGenerated";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    # Step 1: Checking mandatory args;

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        return -1;
    }

    unless ( $log_keyword ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log_keyword input is empty or blank.");
        return -1;
    }

    unless ( $time_stamp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory time stamp input is empty or blank.");
        return -1;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        return -1;
    }

    # one minute should be the default value ;
    unless ( $checking_time_period ) {
        # Setting the checking time period to the default 60 seconds;
        $checking_time_period=60;
    }

    # Step 2: Searching log information;

    my $cmd="tail -50 $file_name";
    $logger->debug(__PACKAGE__ . ".$sub_name:  Searching the log $log_keyword in the lastest log file via '$cmd'.");
    unless ( $shell_session->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        return -1;
    }
    my @cmd_result=@{$shell_session->{CMDRESULTS}};

    # Check the return code; when $? == 0, success;otherwise when $? == 1, failure;

    my @result;
    unless ( @result = $shell_session->execCmd( "echo \$?" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        return -1;
    }
    my $first_element_of_result=(split / /,$result[0])[0];
    unless ( $first_element_of_result eq 0  ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0] --\n@result");
        return -1;
    }

    @{$shell_session->{CMDRESULTS}}=@cmd_result;

    my ($time_info,@log_info);
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;
        if ( /$log_keyword/i and $_ =~ /^\d+\s+\d+\s+\d+\.\d+/ ) {
            @log_info=split;
            $time_info="$log_info[1]$log_info[2]";
        }
    }

    unless ($time_info) {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't retrieve any message matched with $log_keyword in $file_name.");
        return 0;
    }

    $time_info =~ s/(..)(..)(....)(..)(..)(..)(\S+)/$3-$1-$2 $4:$5:$6/g;

    # blai@mallrats:/home/blai/ats_repos/test/Net> date --date='2009-06-09 11:57:58' +%s
    # 1244545078

    $cmd="date --date='$time_info' +%s";
    $logger->debug(__PACKAGE__ . ".$sub_name: Running '$cmd' as to get the log time stamp.");
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        return 0;
    }

    my $log_time_stamp;
    unless ( $log_time_stamp=${$shell_session->{CMDRESULTS}}[0] ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the log time stamp data via '$cmd'");
        return 0;
    }

    my $time_diff = abs($log_time_stamp - $time_stamp );

    $logger->debug(__PACKAGE__ . ".$sub_name: Found the log $log_keyword and the time difference is:$time_diff seconds");

    unless ( $time_diff <= $checking_time_period ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to find the expected log $log_keyword in the $file_name.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully found the log $log_keyword in the $file_name.");
    return 1;
}

=head2 setSystemZoneToGmt()

DESCRIPTION:

  This function is simply to set the system zone to GMT.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     0 - fail;
     1 - success;

=item EXAMPLE:

    unless ( $system_zone = SonusQA::SGX4000::SGX4000HELPER::setSystemZoneToGmt($cli_session)) {
        $logger->error( "Failed to set the system zone to gmt." );
        return 0;
    }

=back 

=cut

sub setSystemZoneToGmt {

    my ($cli_session) = @_ ;

    my $sub_name = "setSystemZoneToGmt";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    # Step 1: Retrieving system name...

    my $system_name;

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    unless ( $system_name=$cli_session->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        return 0;
    }
    
    # Step 2: Set the GMT zone;

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        return 0;
    }

    my $cmd = "set ntp timeZone $system_name zone gmt";
    $logger->debug(__PACKAGE__ . ".$sub_name:  Setting the system name to gmt via '$cmd'...");
    unless ( $cli_session->execCommitCliCmdConfirm($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        return 0;
    }

    $cli_session->leaveConfigureSession;
    $logger->debug(__PACKAGE__ . ".$sub_name: Left the config private mode.");
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully set $system_name zone to gmt.");
    return 1;
}

=head2 getSystemZoneInfo()

DESCRIPTION:

  This function is simply to get system zone information.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     0 - fail;
     $zone_info - success;

=item EXAMPLE:

    unless ( $zone_info = SonusQA::SGX4000::SGX4000HELPER::getSystemZoneInfo($cli_session)) {
        $logger->error( __PACKAGE__ . " $sub_name: "Failed to get the time zone data." );
        return 0;
    }

=back 

=cut

sub getSystemZoneInfo {

    my ($cli_session) = @_ ;

    my $sub_name = "getSystemZoneInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Step 1: Retrieving system name...
    my $system_name;
    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the system name...");
    unless ( $system_name=$cli_session->retrieveSystemName() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve the system name.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    # Step 2: Set the GMT zone time;
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the $system_name zone information.");

    my $cmd = "show table ntp timeZone $system_name zone";
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $zone_info;
    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /zone/i ) {
            s/;//g;
            $zone_info= ( split /\s+/,$_)[-1];
            last;
        }
    }

    unless ( $zone_info ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to retrieve $system_name zone data.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully retrieved $system_name zone data:$zone_info.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [zone_info]");
    return $zone_info;
}


sub enterSFTPConnection {

    my ( $shell_session, $sftp_login_cmd, $password ) = @_;
    my $sub_name = "enterSFTPConnection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $sftp_login_cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory sftp login command input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $password ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory sftp password input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp login with cmd \'$sftp_login_cmd\' and password \$password.");

    unless ( $shell_session->{conn}->prompt('/sftp> $/') ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to set the 'sftp> ' prompt.");
        return 0;
    }

    my $failures = 0;
    my $failures_threshold = 2;

    while ( $failures < $failures_threshold ) {
    
	unless ( $shell_session->{conn}->print( "$sftp_login_cmd" ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute \'$sftp_login_cmd\'");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
 
	my ($prematch, $match);
	unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
								    -match     => '/Host key verification failed/',
                                                                    -errmode   => "return",
                                                                   ) ) {
	    $logger->error(__PACKAGE__ . ".$sub_name:  Unexpected prompt - after executing \'$sftp_login_cmd\'");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

	if ( $match =~ /Host key verification failed/) {
            if ( $failures ){
                $logger->error(__PACKAGE__ . ".$sub_name: Host key verification failed.Failed to connect to host using sftp");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
	    }
            $logger->warn(__PACKAGE__ .".$sub_name: Host key verification failed.Remove the entry from known_hosts and retry ");
            my $cmd = " cat \"\">$ENV{ \"HOME\" }/.ssh/known_hosts ";
            system( $cmd );
            $logger->info(__PACKAGE__ . ".$sub_name: command $cmd executed ");
            $failures += 1;
            next;
        }

        if ( $match =~ m/\(yes\/no\)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes/no prompt for RSA key fingerprint");
            $shell_session->{conn}->print("yes");
            unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                    )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'yes\' to RSA key fingerprint prompt.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }

        if ( $match =~ m/[P|p]assword:/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Matched password: prompt");
            $shell_session->{conn}->print($password);
            unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                -match => '/Permission denied/',
                                                -match => $shell_session->{PROMPT},
                                              )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            if ( $match =~ m/Permission denied/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($password\) for sftp login was incorrect.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'$sftp_login_cmd\'");
            }

        }
        elsif ( $match =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  command \'$sftp_login_cmd\' error:\n$prematch\n$match.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        last;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Sucessfull sftp login.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 getFileToLocalDirectoryViaSFTP()

DESCRIPTION:

  This function is to get a specified file from the named directory on remote host to a local machine.

=over 

=item ARGUMENTS:

    1st Arg  -  the shell session name;
    2nd Arg  -  the local directory where the log file will be stored after sftp;
    3rd Arg  -  the remote directory where the log file store (in the CE server);
    4th Arg  -  the log file name;
    5th Ard  -  timeout (optional) - default is 300 secs

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     -1  - function fail;
     0  - fail (permission denied);
     1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP($local_shell_session,$local_log_directory,$sftp_log_directory,$file_name);

=back 

=cut

sub getFileToLocalDirectoryViaSFTP {

	my ($shell_session,$local_directory,$remote_directory,$file_name,$timeout)=@_;
    my $sub_name = "getFileToLocalDirectoryViaSFTP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $local_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory local directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $remote_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory remote directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   unless ( $timeout ) {
	 $timeout = 300;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name file from $remote_directory directory to $local_directory directory.");

    unless ( $shell_session->{conn}->prompt('/sftp> $/') ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to set the 'sftp> ' prompt.");
        return -1;
    }

    $shell_session->{CMDRESULTS} = ();

    my $cmd="lcd $local_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd($cmd);        # The expected return should be empty;
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
    }

    $shell_session->{CMDRESULTS} = ();
    $cmd="cd $remote_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd("$cmd");
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            return -1;
        }
    }

    $cmd="get $file_name";
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name, wait...");
    unless ( @{$shell_session->{CMDRESULTS}}=$shell_session->{conn}->cmd(
                                                            String => $cmd,
                                                            Prompt => '/sftp> /',
                                                            Timeout => $timeout,
                                                        ))
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $shell_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: execCmd Session Input Log is: $shell_session->{sessionLog2}");
        return -1;
    }

    # Checking the possible get output message;
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;
        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to get $file_name:'No such file or directory'.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /(couldn't|Permission denied)/i ){
            $logger->debug(__PACKAGE__ . ".$sub_name: Permission denied...\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /\S+\s+100%\s+\d+/ ) {
            # If successful, the result looks like:
            # /var/log/sonus/sgx/coredump/core.CE_2N_Comp_N 100%  473MB  43.0MB/s   00:11

            $logger->debug(__PACKAGE__ . ".$sub_name: Successfully completed the file transfer - 100%.");
            last;
        }
        # Otherwise, the return should be the transfering messages.
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the $file_name via sftp.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< putFileToRemoteDirectoryViaSFTP >

DESCRIPTION:

  This function is to put a specified file from the named directory in local machine to remote host.

=over 

=item ARGUMENTS:

    1st Arg  -  the shell session name;
    2nd Arg  -  the local directory where the log file will be stored after sftp;
    3rd Arg  -  the remote directory where the log file store (in the CE server);
    4th Arg  -  the log file name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     -1  - function fail;
     0  - fail (permission denied);
     1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::putFileToRemoteDirectoryViaSFTP($local_shell_session,$local_log_directory,$sftp_log_directory,$file_name);

=back 

=cut

sub putFileToRemoteDirectoryViaSFTP {

    my ($shell_session,$local_directory,$remote_directory,$file_name)=@_;
    my $sub_name = "putFileToRemoteDirectoryViaSFTP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $local_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory local directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $remote_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory remote directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name file from $local_directory directory to $remote_directory directory.");

    unless ( $shell_session->{conn}->prompt('/sftp> $/') ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to set the 'sftp> ' prompt.");
        return -1;
    }

    my $cmd="lcd $local_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd($cmd);        # The expected return should be empty;
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}.");
            return -1;
        }
    }

    $cmd="cd $remote_directory";
    @{$shell_session->{CMDRESULTS}} = $shell_session->{conn}->cmd("$cmd");
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;

        if(!defined $_ || $_ eq "") {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }

        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }.");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: No such file or directory after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( // ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  sftp command executed successfully \'$cmd\'.");
            last;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Unknown return after the command $cmd.\n@{$shell_session->{CMDRESULTS}}");
            return -1;
        }
    }

    # Setting the timeout to 300 seconds as the default timeout is too short to transfer a large coredump file size.
    $cmd="put $file_name";
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to sftp the $file_name, wait...");
    unless ( @{$shell_session->{CMDRESULTS}}=$shell_session->{conn}->cmd(
                                                            String => $cmd,
                                                            Prompt => '/sftp> /',
                                                            Timeout=> 300,
                                                        ))
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $shell_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: execCmd Session Input Log is: $shell_session->{sessionLog2}");
        return -1;
    }

    # Checking the possible get output message;
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;
        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:$cmd.\n@{$shell_session->{CMDRESULTS} }");
            return -1;
        }
        elsif ( /(No such file or directory|not found)/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Failed to get $file_name:'No such file or directory'.\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /(couldn't|Permission denied)/i ){
            $logger->debug(__PACKAGE__ . ".$sub_name: Permission denied...\n@{$shell_session->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        elsif ( /\S+\s+100%\s+\d+/ ) {
            # If successful, the result looks like:
            # /var/log/sonus/sgx/coredump/core.CE_2N_Comp_N 100%  473MB  43.0MB/s   00:11

            $logger->debug(__PACKAGE__ . ".$sub_name: Successfully completed the file transfer - 100%.");
            last;
        }
        # Otherwise, the return should be the transfering messages.
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the $file_name via sftp.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 leaveSFTPConnection()

DESCRIPTION:

  This function is simply to leave a sftp connection and sets the default prompt before the leave.

=over 

=item ARGUMENTS:

    1st Arg  -  the shell session name;
    2nd Arg  -  the default prompt;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None 

=item OUTPUT:

     0  - fail;
     1  - success;

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::leaveSFTPConnection($shell_session, $default_prompt ) )
    {
        $logger->error( __PACKAGE__ . " $sub_name: "  The failed attempt to leave the sftp connection.");
        return 0;
    }

=back 

=cut

sub leaveSFTPConnection {

    my ($shell_session,$default_prompt)=@_;

    my $sub_name = "leaveSFTPConnection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session->{conn}->prompt($default_prompt) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to set the prompt to $default_prompt");
        return 0;
    }

    unless ( $default_prompt ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory default prompt input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Disconnecting the SFTP connection.");
    $shell_session->execCmd("quit");
    foreach ( @{$shell_session->{CMDRESULTS} } ) {
        chomp;
        if ( /Invalid\s+command/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid command:quit.\n@{$shell_session->{CMDRESULTS}}.");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully disconnectted the SFTP connection.");
    return 1;
}

=head2 calculateFileChecksum()

DESCRIPTION:

  This function is to calculate a file's checksum and returns the checksum value.

=over 

=item ARGUMENTS:

    1st Arg  -  the shell session name;
    2nd Arg  -  the directory where the file is stored;
    3rd Arg  -  the file name

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0  - fail;
    $file_checksum  - success;

=item EXAMPLE:

    unless ( $file_checksum = SonusQA::SGX4000::SGX4000HELPER::calculateFileChecksum($shell_session,$file_directory,$file_name)
    {
        $logger->error( __PACKAGE__ . " $sub_name: "Failed to calculate the file checksum value");
        return 0;
    }

=back 

=cut

sub calculateFileChecksum {
    my ($shell_session,$file_directory,$file_name)=@_;

    my $sub_name = "calculateFileChecksum";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_directory ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file directory input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd="cd $file_directory";
    unless ( $shell_session->{conn}->cmd($cmd) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd\n");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $shell_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: execCmd Session Input Log is: $shell_session->{sessionLog2}");
        return 0;
    }

    $cmd="cksum $file_name";
    unless ( @{$shell_session->{CMDRESULTS}}=$shell_session->{conn}->cmd( $cmd ) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CDMRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $shell_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: execCmd Session Input Log is: $shell_session->{sessionLog2}");
        return 0;
    }

    my $file_checksum;
    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        if ( /(\d+)\s+(\d+)\s+$file_name/ ) {
        #      ^^^     ^^^
        #  $1=cheksum  $2=file size
            $file_checksum=$1;
        }
    }

    unless ( $file_checksum ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to calculate the file checksum value.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully calcuated the file checksum value: $file_checksum for $file_name.");
    return $file_checksum;
}

=head2 isProcessRunning()

DESCRIPTION:

  This function is simply to check if the given process is running.

=over 

=item ARGUMENTS:

    1st Arg  -  the shell session name;
    2nd Arg  -  the process name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     -1  - functino fail;
      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isProcessRunning($shell_session,$process_name);

=back 

=cut

sub isProcessRunning {

    my ($shell_session,$process_name) = @_ ;

    my $sub_name = "isProcessRunning";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $process_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory process name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    # Step 1: check the process name status
    
    my $cmd="ps -ef|grep $process_name|grep -v grep";
    unless ( $shell_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
        return -1;
    }

    my $found_flag;
    for ( @{$shell_session->{CMDRESULTS}}) {
        if (/$process_name$/) {
            $found_flag = 1;    
        }
    }

    unless(    $found_flag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: The $process_name is not running.");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Success - the $process_name process is running.");
    return 1;
}

=head2 enableEventLogAdminState()

DESCRIPTION:

  This function is simply to set the event log admin state to 'enabled' for the specified event type (eg system or debug).

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;
    2nd Arg  -  the event log type (system, debug)

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::enableEventLogAdminState($cli_session,"system");

=back 

=cut

sub enableEventLogAdminState {

    my ($cli_session,$event_type) = @_ ;

    my $sub_name = "enableEventLogAdminState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ####################################################
    # Step 1: Checking the mandatory inputs
    ####################################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory cli session input is missing or blank.");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory event log type input is missing or blank.");
        return 0;
    }


    ####################################################
    # Step 2: Checking the current state status for the given event type;
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the current $event_type event type's state status is 'enabled'.");
    my $result=checkEventLogTableInfo($cli_session,$event_type,"state","enabled");
    if ( $result == -1 )
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the admin setting for $event_type event log in the eventLog table");
        return 0;
    }
    elsif ( $result == 1 )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current $event_type status is already in the 'enabled' status.");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current $event_type event log status is 'disabled'.");
    }

    ####################################################
    # Step 3: Setting the event log 
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        return 0;
    }

    my $cmd = "set eventLog typeAdmin $event_type state enabled";
    $logger->debug(__PACKAGE__ . ".$sub_name:  Setting the $event_type event log state to 'enabled'");
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving the config private mode.");
    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave configuration mode '$cmd'.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully set $event_type log event state to the 'enabled' status");
    return 1;
}

=head2 C< checkEventLogTableInfo >

DESCRIPTION:

  This function is going to check if the specified eventLog status matches the current setting.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the log type (Eg DBG, SYS etc);
    3rd Arg - the table checking_field, (eg state, filter level);
    4th Arg - the table checking_field's value, (eg enabled, disabled );

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    -1 - function fail;
     0 - fail;
     1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::checkEventLogTableInfo($cli_session,"system");

=back 

=cut

sub checkEventLogTableInfo {

    my ($cli_session,$log_type,$checking_field,$status) = @_;
    my $sub_name = "checkEventLogTableInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #######################################
    # Step 1: Check the mandatory inputs
    #######################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $checking_field ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory checking field input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $status ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory status input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #######################################
    # Step 2: Checking the specified field's status in the eventLog table;
    #######################################

    my $cmd="show table eventLog typeAdmin $log_type $checking_field";
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the eventLog table data via '$cmd'"); 
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        return -1;
    }


    my @log_info;
    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /$checking_field/i ) {
            s/;//g;
            @log_info = split;
            unless ( $log_info[1] eq $status ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to match the given status:$status");
                return 0;
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success - the current setting matched the specified status.");
    return 1;
}

=head2 disableEventLogAdminState()

DESCRIPTION:

  This function is simply to  set the event log admin state to 'disabled' for the specified event type (eg system or debug).

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;
    2nd Arg  -  the event log type (system, debug)

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::disableEventLogAdminState($cli_session,"system");

=back 

=cut

sub disableEventLogAdminState {

    my ($cli_session,$event_type) = @_ ;

    my $sub_name = "disableEventLogAdminState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ####################################################
    # Step 1: Checking the mandatory inputs
    ####################################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory cli session input is missing or blank.");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory event log type input is missing or blank.");
        return 0;
    }


    ####################################################
    # Step 2: Checking the current state status for the given event type;
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the current $event_type event type's state status is 'disabled'.");
    my $result=checkEventLogTableInfo($cli_session,$event_type,"state","disabled");
    if ( $result == -1 )
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the admin setting for $event_type event log in the eventLog table");
        return 0;
    }
    elsif ( $result == 1 )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current $event_type status is already in the 'disabled' status.");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current $event_type event log status is 'disabled'.");
    }

    ####################################################
    # Step 3: Setting the event log 
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        return 0;
    }

    my $cmd = "set eventLog typeAdmin $event_type state disabled";
    $logger->debug(__PACKAGE__ . ".$sub_name:  Setting the $event_type event log state to 'disabled'");
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving the config private mode.");
    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave configuration mode '$cmd'.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully set $event_type log event state to the 'disabled' status");
    return 1;
}

=head2 enableDebugEventLogAdminState()

DESCRIPTION:

  This function is simply to enable the debug log event admin state.

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::enableDebugEventLogAdminState($cli_session);

=back 

=cut

sub enableDebugEventLogAdminState {

    my ($cli_session) = @_ ;

    my $sub_name = "enableDebugEventLogAdminState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ####################################################
    # Step 1: Checking the mandatory inputs
    ####################################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Mandatory cli session input is missing or blank.");
        return 0;
    }
    
    ####################################################
    # Step 2: Checking the current admin state status; 
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the current debug event type's state status is 'enabled'.");
    my $result=checkEventLogTableInfo($cli_session,"debug","state","enabled");
    if ( $result == -1 )
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the admin setting for debug event log in the eventLog table");
        return 0;
    }
    elsif ( $result == 1 )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current debug status is already in the 'enabled' status.");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: The current debug event log status is 'disabled'.");
    }


    ####################################################
    # Step 3: Set 'enabled' and catch the prompt: [yes,no]
    ####################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        return 0;
    }

    my $cmd="set eventLog typeAdmin debug state enabled";
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:'$cmd' --\n@{$cli_session->{CMDRESULTS}}.");
        return 0;
    }

    unless ( $cli_session->{conn}->print("commit")) 
    {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue commit " );
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Setting the prompt with \[yes,no\].");
     
    my ($prematch, $match);
    unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                           -match     => '/\[yes,no\]/i',
                                                           -match    => $cli_session->{PROMPT},
                                                         ))
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Unexpected prompt - after executing 'commit'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the prompt: $match, expecting the '\[yes,no]'.");
    unless ( $match =~ m/\[yes,no\]/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Unexpected prompt - after executing 'commit'.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Matched the fingerprint \[yes,no] prompt after 'commit'.");
    unless ( $cli_session->execCliCmd("yes") ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:'yes'--\n@{$cli_session->{CMDRESULTS}}.");
        return 0;
    }

    ####################################################
    # Step 4: Leave the configure private session;
    ####################################################

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to leave private config mode.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Sucessfully enabled the debug log event admin state.");
    return 1;
}

=head2 setLogEventFilterLevel()

DESCRIPTION:

  This function is to set filter level for a specified log event type;

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;
    2nd Arg  - the log event type;
    3rd Arg  - the filter level;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::setLogEventFilterLevel($cli_session,"system","info");

=back 

=cut

sub setLogEventFilterLevel {
 
    my ($cli_session,$event_type,$filter_level) = @_ ;
    my $sub_name = "setLogEventFilterLevel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $filter_level ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory fliter level input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->enterPrivateSession() ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        return 0;
    }
    my $cmd = "set eventLog typeAdmin $event_type filterLevel $filter_level";
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to exectute '$cmd'.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the '$cmd'.");

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to leave private config session.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully set the filter level to $filter_level for the $event_type log event type.");
    return 1;
}

=head2 getLogEventData()

DESCRIPTION:

  This function is to get all the log events from the named log file after the specified time stamp;

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;
    2nd Arg  -  the time stamp data;
    3rd Arg  -   the log file name that stores the event logs;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

      0  - fail;
      @log_event_data  - success;

=item EXAMPLE:

    @log_event_data = SonusQA::SGX4000::SGX4000HELPER::getLogEventData($cli_session,$time_stamp,$file_name);

=back 

=cut

sub getLogEventData {

    my ($shell_session,$time_stamp,$file_name) = @_ ;

    my $sub_name = "getLogEventData";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    my ($time_info,@log_event_data,@log_info,$log_time_stamp,$the_log_position_found_flag);


    ####################################################
    # Step 1: Checking mandatory args;
    ####################################################

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        return 0;
    }

    unless ( $time_stamp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory time stamp input is empty or blank.");
        return 0;
    }

    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file name input is empty or blank.");
        return 0;
    }

    ####################################################
    # Step 2: Retrieving the data via 'cat xxx' with the buffer limit 11,000
    ####################################################
    
    # Set the log data upper limit to 11,000 lines as there is a limit setting in the  Net::Telnet Buffer;

    my $cmd="cat $file_name|tail -11000";
    unless ( @{$shell_session->{CMDRESULTS}}=$shell_session->{conn}->cmd(
                                                            String => $cmd,
                                                            Timeout=> 120,
                                                        ))
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd --\n@@{$shell_session->{CMDRESULTS}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $shell_session->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: execCmd Session Input Log is: $shell_session->{sessionLog2}");
        return -1;
    }

    my @cmd_result=@{$shell_session->{CMDRESULTS}};

    # Check the return code
    my @result;
    unless ( @result = $shell_session->execCmd( "echo \$?" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        return 0;
    }

    # when $? == 0, success;
    # otherwise when $? == 1, failure;

    my $first_element_of_result=(split / /,$result[0])[0];
    unless ( $first_element_of_result eq 0  ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0] --\n@result");
        return 0;
    }
    @{$shell_session->{CMDRESULTS}}=@cmd_result;

    ####################################################
    # Step 3: Retrieving the data only after the specified timestamp;
    ####################################################

    foreach ( @{$shell_session->{CMDRESULTS}} ) {
        chomp;
        if ( ! $the_log_position_found_flag and $_ =~ /^\d+\s+\d+\s+\d+\.\d+/ ) {
            @log_info=split;
            $time_info="$log_info[1]$log_info[2]";
            $time_info =~ s/(..)(..)(....)(..)(..)(..)(\S+)/$3-$1-$2 $4:$5:$6/g;
            # blai@mallrats:/home/blai/ats_repos/test/Net> date --date='2009-06-09 11:57:58' +%s
            # 1244545078
        
            $cmd="date --date='$time_info' +%s";
            unless ( $shell_session->execShellCmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$shell_session->{CMDRESULTS}}.");
                return 0;
            }
        
            unless ( $log_time_stamp=${$shell_session->{CMDRESULTS}}[0] ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the log time stamp data via '$cmd'");
                return 0;
            }
            unless ( $log_time_stamp < $time_stamp ) {
                push @log_event_data,$_;
                $the_log_position_found_flag=1;
            }
        }
        elsif ( $_ =~ /^\d+\s+\d+\s+\d+\.\d+/ ) {
            push @log_event_data,$_;
        }
    }

    unless ( scalar(@log_event_data)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the log event data since the time $time_stamp.");
        return 0;    
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully got the log event data since the time $time_stamp.");
    return @log_event_data;
}

=head2 isLogEventSeverityLevelMatched()

DESCRIPTION:

  This function checks the log event severity levels from the given the log event data;

=over 

=item ARGUMENTS:

    1st Arg  -  the cli session ;
    2nd Arg  -  the reference of a log event data array;
    3rd Arg  -  the expected level data;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

     -1  - function fail;
      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isLogEventSeverityLevelMatched($cli_session,$event_data,$level_data);

=back 

=cut

sub isLogEventSeverityLevelMatched {

    my ($shell_session,$event_data,$level_data) = @_;

    my $sub_name = "isLogEventSeverityLevelMatched";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ########################################################
    # Step 1: Checking mandatory args;
    ########################################################

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        return -1;
    }

    unless ( $event_data ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event data input is empty or blank.");
        return -1;
    }

    ########################################################
    # Step 2: Check if the severity level matched;
    # Note: The Critical message looks like:
    #         190 06162009 161615.08276:1.01.08276.CRITICAL.CHM: *validate error application, "... "
    #
    ########################################################

    my %severity_hash;
    foreach (@{$event_data}) {
        if (/\d+\s+\d+\s+\d+\.\d+:\d\.\d+\.\d+\.(\w+)(\s+|\.)/) {
            $severity_hash{$1}=1;
        }
    }

    foreach (@{$level_data}) {
        unless ( defined $severity_hash{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to find the '$_' severity level log event.");
            return 0;
        }
    }

    my $expected_item_flag=0;
    my $item;
    foreach $item ( keys %severity_hash ) {
        $expected_item_flag=0;
        foreach ( @{$level_data} ) {
            if ( $item =~ /^$_/i ) {
                $expected_item_flag=1;
            }
        }
        unless ( $expected_item_flag ) {
            $logger->error(__PACKAGE__ . ".$sub_name: There is an unexpected serverity level '$item' found.");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Success - the checked log event data matched the log serverity levels\(@{$level_data}\).");
    return 1;
}

=head2 generateMajorDebugLogEvent()

DESCRIPTION:

  This function is to generate the major log events for DEBUG type by setting the wrong licence value.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

   SonusQA::SGX4000::SGX4000HELPER::generateMajorDebugLogEvent($cli_session);

=back 

=cut

sub generateMajorDebugLogEvent {

    my ($cli_session )=@_;

    my $sub_name = "generateMajorDebugLogEvent";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ############################################
    # Step 1: Checking mandatory args;
    ############################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "set license bundle bundle \"wrong licence for the purpose of generating debug type log event only\"";

    unless ( $cli_session->execCommitCliCmd($cmd)) {
        #$logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        #$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        #return 0;
        if ( @{$cli_session->{CMDRESULTS}} ) {    
            if ( /Aborted:/ ) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Found the expected error result: $_");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                last;
            }
        }
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully generated major debug type log event.");
    return 1;
}

=head2 setEventLogTableToDefaultStatus()

DESCRIPTION:
  This function is simply to set the eventLog admin to the default status for a specified event log type (system, debug, trace).

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the event type;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::setEventLogTableToDefaultStatus($cli_session,"system");

=back

=cut

sub setEventLogTableToDefaultStatus {

    my ($cli_session,$event_type )=@_;

    my $sub_name = "setEventLogTableToDefaultStatus";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ##################################################
    # Step 1: Checking mandatory args;
    ##################################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ##################################################
    # Step 2: Set the default eventLog values;
    ##################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Step 2: Setting the default values;

    my $cmd="set eventLog typeAdmin $event_type filterLevel major fileCount 32 fileSize 2048 state enabled";

    $logger->debug(__PACKAGE__ . ".$sub_name: Setting the $event_type type eventLog table to the default values - '$cmd'.");
    $cmd="set eventLog typeAdmin $event_type filterLevel major fileCount 32 fileSize 2048 saveTo disk state enabled";
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n@{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $cmd = "show eventLog typeAdmin system";
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n@{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $action_flag="stop"; # If there is no rollover action, it is set to "stop";
    my $action_time="";

    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        s/;//;
        if ( /^rolloverAction\s+(\S+)/ ) { $action_flag = $1; }
        if ( /^rolloverStartTime\s+(\S+)/ ) { $action_time = $1; }
    }

    unless ( $action_flag eq "stop" ) {
        $cmd="set eventLog typeAdmin $event_type rolloverStartTime $action_time rolloverAction stop";
        $logger->debug(__PACKAGE__ . ".$sub_name: Stopping the rolloveraction: $cmd ");
        unless ( $cli_session->execCommitCliCmd($cmd)) {

            unless ( $cli_session->leaveConfigureSession ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
            }

            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n@{$cli_session->{CMDRESULTS}}.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");

            return 0;
        }
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully set the eventLog\($event_type\) table to the default value.");
    return 1;
}

=head2 enableEventClassWithSpecifiedEventTypeAndFilterLevel()

DESCRIPTION:

  This function is simply to set the filter class with the specified filter level on the given CE server.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the ce name;
    3rd Arg - the event type;
    4th Arg - the event class;
    5th Arg - the filter level;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::enableEventClassWithSpecifiedEventTypeAndFilterLevel($cli_session,"asterix","system","sysmgmt","info");

=back 

=cut

sub enableEventClassWithSpecifiedEventTypeAndFilterLevel {

    my ($cli_session,$ce_name, $event_type, $event_class, $filter_level )=@_;

    my $sub_name = "enableEventClassWithSpecifiedEventTypeAndFilterLevel";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #############################################
    # Step 1: Checking mandatory args;
    #############################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory ce name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_class ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event class input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $filter_level ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filter level input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #############################################
    # Step 2: Retrieving the server name
    #############################################

    my ($cmd,$server_name);

    unless ( $server_name =  retrieveServerName($cli_session,$ce_name) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to find the server name for $ce_name.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #############################################
    # Step 3: Set the filter level
    #############################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $cmd = "set eventLog filterAdmin $server_name $event_type $event_class level $filter_level state on";
    $logger->debug(__PACKAGE__ . ".$sub_name: Enabling the $event_type event filter for event class '$event_class' via '$cmd'");
    unless ( $cli_session->execCommitCliCmd($cmd)) {

        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }

        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully enabled the $event_type event filter for the event class '$event_class'.");
    return 1;
}

=head2 disableEventLogSysmgmt()

DESCRIPTION:

  This function is simply to disable event filter for sysmgmt for the specified CE server;

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the CE server name;
    3rd Arg - the log event type,
    4th Arg - the filter level;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail;
      1  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::disableEventLogSysmgmt($cli_session,$second_tms_alias,"system","info");

=back 

=cut

sub disableEventLogSysmgmt {

    my ($cli_session,$ce_name, $event_type ,$filter_level )=@_;

    my $sub_name = "disableEventLogSysmgmt";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #############################################
    # Step 1: Checking mandatory args;
    #############################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory ce name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $filter_level ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filter level input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #############################################
    # Step 2: Retrieving the server name
    #############################################

    my ($cmd,$server_name);

    unless ( $server_name =  retrieveServerName($cli_session,$ce_name) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to find the server name for $ce_name.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
    unless ( $cli_session->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #############################################
    # Step 3: Turning the filter off
    #############################################

    $cmd = "set eventLog filterAdmin $server_name $event_type sysmgmt level $filter_level state off";
    $logger->debug(__PACKAGE__ . ".$sub_name: Disabling the $event_type event filter for sysmgmt via '$cmd'");
    unless ( $cli_session->execCommitCliCmd($cmd)) {
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully enabled the $event_type event filter for sysmgmt.");
    return 1;
}

=head2 retrieveServerName()

DESCRIPTION:

  This function is to retrieve the server name for a specified CE.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the CE server name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail;
      $server_name  - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::retrieveServerName($cli_session,$ce_name);

=back 

=cut

sub retrieveServerName {

    my ($cli_session,$ce_name)=@_;

    my $sub_name = "retrieveServerName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ##########################################
    # Step 1: Checking mandatory args;
    ##########################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory ce name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ##########################################
    # Step 2: Retrieving the server name
    ##########################################

    my ($cmd,$server_name);
    $cmd = "show table system serverAdmin";
    $logger->info(__PACKAGE__ . ".$sub_name:  Retrieving the server name for the CE '$ce_name' via '$cmd'.");
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@{$cli_session->{CMDRESULTS}}) {
        if (/^$ce_name\s+\W/i ) {
            $server_name= ( split /\s+/,$_)[0];
        } elsif ( /^$ce_name\s+\w/i ) {
            $server_name= ( split /\s+/,$_)[0];
        }
    }

    unless ($server_name) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to find the server name \(with domain\) via '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully retrieved the server name: $server_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [server name]");
    return $server_name;
}

=head2 isEventClassEnabled()

DESCRIPTION:

  This function checks if an event class has been enabled for the specified event type and filter level on the named CE server.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the CE server name;
    3rd Arg - the log event type;
    4th Arg - the filter event class (sysmgmt);
    5th Arg - the filter level (info, major etc);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

     -1  - function fail;
      0  - fail (disabled);
      1  - success (enabled);

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isEventClassEnabled($cli_session,$active_ce,$event_type,"netmgmt","info");

=back 

=cut

sub isEventClassEnabled {

    my ($cli_session,$ce_name, $event_type,$event_class,$filter_level) = @_;

    my $sub_name = "isEventClassEnabled";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    #####################################
    # Step 1: Checking mandatory args;
    #####################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        return -1;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        return -1;
    }

    unless ( $event_class ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event class input is empty or blank.");
        return -1;
    }

    unless ( $filter_level ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filter level input is empty or blank.");
        return -1;
    }

    #####################################
    # Step 2: Retrieving the server name;
    #####################################


    my ($cmd,$server_name);

    unless ( $server_name =  retrieveServerName($cli_session,$ce_name) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to find the server name for $ce_name.");
        return -1;
    }

    #####################################
    # Step 3: Checking the state status
    #####################################

    $cmd = "show table eventLog filterAdmin $server_name system";
    $logger->info(__PACKAGE__ . ".$sub_name:  Retrieving the event class information:$event_class.");

    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        return -1;
    }

    my $event_class_flag = 0;
    foreach (@{$cli_session->{CMDRESULTS}}) {
        if (/^$event_type\s+$event_class\s+$filter_level\s+/) {
            $event_class_flag = 1;
        }
    }

    unless ( $event_class_flag ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The $event_class event class has not been enabled yet.");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Success - the $event_class event class for the event type $event_type and the filter level $filter_level on $ce_name is in the enabled status");
    return 1;
}

=head2 retrieveCurrentLogFileName()

DESCRIPTION:

  This function is to retrieve the current log file name for the given log event type;

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the log event type;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

      0  - fail ;
      $file_name  - success;

=item EXAMPLE:

    $file_name=SonusQA::SGX4000::SGX4000HELPER::retrieveCurrentLogFileName($cli_session,"system");

=back 

=cut

sub retrieveCurrentLogFileName {

    my ($cli_session,$event_type)=@_;

    my $sub_name = "retrieveCurrentLogFileName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ##########################################
    # Step 1: Checking mandatory args;
    ##########################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ##########################################
    # Step 2: Get the current log file name
    ##########################################

    my ($cmd,$file_name);
    $cmd = "show table eventLog typeStatus";
    $logger->debug(__PACKAGE__ . ".$sub_name:  Retrieving the current log file name via '$cmd'");
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@{$cli_session->{CMDRESULTS}}) {
        if (/^$event_type\s+/) {
            $file_name=(split /\s+/,$_)[1];
            last;
        }
    }

    unless ($file_name) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to find the file name via '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    return $file_name;
}

=head2 calculateRolloverLogFileNamecalculateRolloverLogFileName()

DESCRIPTION:

  This function is to calculate the rollover log file names after a new file count has been set.
  For example (for the system type log event): 
        1) If the current log file is "1000009.SYS" and the file count is 5, then the rollover sequence will be:
            1000009.SYS 1000001.SYS 1000002.SYS 1000003.SYS 1000004.SYS 1000005.SYS 1000001.SYS

        2) If the current log file is "1000002.SYS" and the file count is 5, then the rollover sequence will be:
            1000002.SYS 1000003.SYS 1000004.SYS 1000005.SYS 1000001.SYS 1000002.SYS

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the log event type; 
    3rd Arg - the file count number;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail;
    \@rollover_names - success;

=item EXAMPLE:

    $rollover_name=SonusQA::SGX4000::SGX4000HELPER::calculateRolloverLogFileName($cli_session,"system",3);

=back 

=cut

sub calculateRolloverLogFileName {

    my ($cli_session,$event_type,$file_count) = @_ ;

    my $sub_name = "calculateRolloverLogFileName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ( $cur_file_number,$starting_file_number,$max_number,@rollover_names);

    my %file_type = (
            system => "SYS",
            debug => "DBG",
            trace => "TRC",
            acct => "ACT",
            audit => "AUD",
            security => "SEC",
        );

    ################################################
    # Step 1: Checking mandatory args;
    ################################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        return -1;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory event type input is empty or blank.");
        return -1;
    }

    unless ( $file_count ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory file count input is empty or blank.");
        return -1;
    }

    ################################################
    # Step 2: check the latest log file;
    ################################################

    my $file_name;
    unless ( $file_name=retrieveCurrentLogFileName ($cli_session,$event_type) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't retrieve the current log file name ");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieved the current log file name: $file_name");

    ################################################
    # Step 3: calculate the rollover file names;
    ################################################

    $file_name =~ s/\.$file_type{$event_type}//g;
    $cur_file_number = hex($file_name);
    $file_name =~ s/./0/g;
    $file_name =~ s/^0/1/g;

    $starting_file_number = hex($file_name) +1 ;
    $max_number = hex($file_name)+$file_count;

    if ( $cur_file_number <= $max_number ) {
        for ( $cur_file_number..$max_number ) {
            push @rollover_names, sprintf("%X.%s",$_,$file_type{$event_type});
        }

        for ( $starting_file_number..$cur_file_number ) {
            push @rollover_names, sprintf("%X.%s",$_,$file_type{$event_type});
        }
    } else {
        push @rollover_names,sprintf("%X.%s",$cur_file_number,$file_type{$event_type});
        for ( $starting_file_number..$max_number ) {
            push @rollover_names, sprintf("%X.%s",$_,$file_type{$event_type});
        }
        push @rollover_names, sprintf("%X.%s",$starting_file_number,$file_type{$event_type});
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Success - the rollover sequence will be:@rollover_names");
    return \@rollover_names;
}

=head2 rollOverLogFileByGeneratingNTPLogs()

DESCRIPTION:

  This function is to fill log files up by enabling and disabling NTP service.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the CE server name;
    3rd Arg - the log event type;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail;
    \@rollover_names - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::rollOverLogFileByGeneratingNTPLogs($cli_session,$active_ce,$event_type);

=back 

=cut

sub rollOverLogFileByGeneratingNTPLogs {

    my ($cli_session,$active_ce,$log_file_type ) = @_;

    my $sub_name = "rollOverLogFileByGeneratingNTPLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($cmd,$server_name, $file_name,$file_size,$old_file_size, $loop_times, $old_file_name);

    ##############################################
    # Step 1: Checking mandatory args;
    ##############################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $active_ce ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory active ce name is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_file_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log file type is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ##############################################
    # Step 2: Checking NTP setting
    ##############################################

    $cmd="show table ntp peerAdmin";
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the ntp setting data via '$cmd'"); 
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my ($ntp_ce_name,$ntp_ip);

    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /$active_ce/ ) {
            my @ntp_result=split;
            $ntp_ce_name   = $ntp_result[0];
            $ntp_ip        = $ntp_result[1];
            last;    
        }
    }

    my @ntp_cmd;
    $ntp_cmd[0] = "set ntp peerAdmin $ntp_ce_name $ntp_ip state disabled";
    $ntp_cmd[1] = "set ntp peerAdmin $ntp_ce_name $ntp_ip state enabled";

    ##############################################
    # Step 3: Generating the NTP logs until the log file has been filled up or maximum 1000 times ;
    ##############################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Filling the '$log_file_type' log file by generating NTP logs.");
    $old_file_size = 0;
    $loop_times =0;

    $cmd = "show table eventLog typeStatus";
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /^$log_file_type\s+(\S+)\s+\d+\s+(\d+)\s+/ ) {
            $file_name = $1;
            $file_size = $2;
            last;
        }
    }

    unless ( $file_name and $file_size ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the latest log file name and its size.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $old_file_name = $file_name;
    $old_file_size = $file_size;
    $logger->debug(__PACKAGE__ . ".$sub_name: the current log file is: $file_name \(size=$file_size\) ");

    ##############################################
    # Step 4: Generating enough log events as to fill up the log files;
    ##############################################

    for ( 1..100 ) {

        unless ( $_ == 1 ) {
            $cmd = "show table eventLog typeStatus";
            unless ( $cli_session->execCliCmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute '$cmd' --\n @{$cli_session->{CMDRESULTS}}.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            foreach ( @{$cli_session->{CMDRESULTS}} ) {
                chomp;
                if ( /^$log_file_type\s+(\S+)\s+\d+\s+(\d+)\s+/ ) {
                    $file_name = $1;
                    $file_size = $2;
                    last;
                }
            }
            unless ( $file_name and $file_size ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the latest log file name and its size.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }

        unless ( $file_name eq $old_file_name ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Success - the '$log_file_type' log file has been rolled over from $old_file_name to $file_name.");
            last;
        }

        # For the first time of the loop, the old file size equals the current file size;
        unless ( $file_size >= $old_file_size ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Success - the '$log_file_type' log file has been overrided: $old_file_size => $file_size");
            last;
        }


        # ------------------------------------------------------
        # 1) The two commands yield 247 bytes as follows;
        # 164 07022009 133618.40969:1.01.40969.Info    .CHM: *CLI 'set ntp peerAdmin asterix.uk.sonusnet.com 10.1.1.2 state enabled'
        # 165 07022009 133618.40970:1.01.40970.Info    .CHM: *CLI 'set ntp peerAdmin asterix.uk.sonusnet.com 10.1.1.2 state disabled'
        # 
        # 2) 100 * 247 = 24,700 ( 24.7 Kbytes ) 
        # ------------------------------------------------------

        $logger->debug(__PACKAGE__ . ".$sub_name: Generating NTP logs to fill up the log files '$file_name': -- $_ -- ");
        unless ( $cli_session->enterPrivateSession() ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    
        for (1..100) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Sending the NTP command to CLI: $_ ");
                foreach ( @ntp_cmd) {            
                unless ( $cli_session->execCliCmd("$_") ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute NTP log generation command.");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
        unless ( $cli_session->execCliCmd("commit")) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute NTP log generation command.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
            }
        }


        unless ( $cli_session->leaveConfigureSession ){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute NTP log generation command.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the NTP log generation command.");

        $old_file_name= $file_name;
        $old_file_size= $file_size;
        $loop_times++;
    }

    unless ( $loop_times < 100 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to fill the $file_name log file up.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully rolled the '$file_name' log file over by generating NTP logs.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [log file name]");
    return $file_name;
}

=head2 turnFilterAdminOff()

DESCRIPTION:

  This function turns off all the filter admin setting.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::turnFilterAdminOff($cli_session,$active_ce,$event_type);

=back

=cut

sub turnFilterAdminOff {

    my ($cli_session )=@_;

    my $sub_name = "turnFilterAdminOff";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #########################################
    # Step 1: Checking mandatory args;
    #########################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #########################################
    # Step 2: Retrieve the filter admin setting;
    #########################################

    my $cmd = "show table eventLog filterAdmin";
    $logger->debug(__PACKAGE__ . ".$sub_name: Retrieving the filterAdmin setting data:$cmd");
    unless ( $cli_session->execCliCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute: $cmd --\n@{$cli_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @filter_cmd;

    foreach ( @{$cli_session->{CMDRESULTS}} ) {
        chomp;
        if ( /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+on/ ) {
            $cmd="set eventLog filterAdmin $1 $2 $3 level $4 state off";
            push @filter_cmd,$cmd;
        }
    }

    #########################################
    # Step 3: Setting the default values;
    #########################################


    unless ( scalar(@filter_cmd) == 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Entering the config private mode.");
        unless ( $cli_session->enterPrivateSession() ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    
        foreach $cmd ( @filter_cmd ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: disabling the filter admin:'$cmd'.");
            unless ( $cli_session->execCommitCliCmd($cmd)) {
                unless ( $cli_session->leaveConfigureSession ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
                }
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd' --\n@{$cli_session->{CMDRESULTS}}.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
    
        unless ( $cli_session->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully disabled all the filterAdmin setting.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 isSNMPConfiguredForDiskUsageWarning()

DESCRIPTION:

  This function checks if SNMP tables have been configured for disk usage warning.
  For example: the following 4 snmp files should be sourced in the CLI: snmpCommunity.cli  snmpNotification.cli  snmpTarget.cli  snmpViewBasedAcm.cli;

=over 

=item ARGUMENTS:

    1st Arg - the cli session;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

   -1 - function fail;
    0 - fail;
    1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::isSNMPConfiguredForDiskUsageWarning($cli_session);

=back 

=cut

sub isSNMPConfiguredForDiskUsageWarning {

    my ($cli_session )=@_;

    my $sub_name = "isSNMPConfiguredForDiskUsageWarning";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ###########################################
    # Step 1: Checking mandatory args;
    ###########################################

    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return -1;
    }

    # -------------------------------------------------------
    # Step 2: Checking the SNMP tables
    #         1) Checking the SNMP COMMUNITY table by:
    #             "show table SNMP-COMMUNITY-MIB snmpCommunityTable snmpCommunityEntry"
    #              it should give "^all-rights"
    #              it should give "^standard trap"
    #
    #         2) Checking the SNMP-NOTIFICATION-MIB table by:
    #              "show table SNMP-NOTIFICATION-MIB snmpNotifyTable snmpNotifyEntry"
    #              it should give "^std_trap"
    #              it should give "^std_v1_trap"
    #        
    #          3) Checking the SNMP-TARGET-MIB table by: 
    #              "show table SNMP-TARGET-MIB snmpTargetAddrTable snmpTargetAddrEntry"
    #              expecting: "^targetV1"
    #              expecting: "^targetV2"
    #              
    #             "show table SNMP-TARGET-MIB snmpTargetParamsTable snmpTargetParamsEntry"
    #              expecting: "^target_v1"
    #              expecting: "^target_v2"
    #
    #
    #          4) Checking the SNMP-VIEW-BASED-ACM-MIB table by:
    #              "show table SNMP-VIEW-BASED-ACM-MIB vacmSecurityToGroupTable vacmSecurityToGroupEntry
    #              expecting: "all-rights"
    # 
    #              "show table SNMP-VIEW-BASED-ACM-MIB vacmViewTreeFamilyTable vacmViewTreeFamilyEntry
    #             expecting "^internet"
    #
    #              "show table SNMP-VIEW-BASED-ACM-MIB vacmAccessTable vacmAccessEntry"
    #              expecting "^all-rights"
    #
    # -------------------------------------------------------


    my %checking_hash = (
        "show table SNMP-COMMUNITY-MIB snmpCommunityTable snmpCommunityEntry" => ["^all-rights","^standard\\s+trap"],
        "show table SNMP-NOTIFICATION-MIB snmpNotifyTable snmpNotifyEntry"    => ["std_trap","std_v1_trap"],
        "show table SNMP-TARGET-MIB snmpTargetAddrTable snmpTargetAddrEntry"  => ["^targetV1","^targetV2"],
        "show table SNMP-TARGET-MIB snmpTargetParamsTable snmpTargetParamsEntry" => ["^target_v1","^target_v2"],
        "show table SNMP-VIEW-BASED-ACM-MIB vacmSecurityToGroupTable vacmSecurityToGroupEntry" =>["all-rights"],
        "show table SNMP-VIEW-BASED-ACM-MIB vacmViewTreeFamilyTable vacmViewTreeFamilyEntry"  => ["^internet"],
        "show table SNMP-VIEW-BASED-ACM-MIB vacmAccessTable vacmAccessEntry"   => ["^all-rights"],
    );

    ###########################################
    # Step 2: Checking the key words of snmp setting;
    ###########################################

    my ($tbl_name, $cmd, $keyword, $keyword_found_flag );

    foreach $cmd ( keys %checking_hash ) {
        $tbl_name=(split /\s+/,$cmd)[2];
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the command: $cmd ");
        unless ( $cli_session->execCliCmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute: $cmd --\n@{$cli_session->{CMDRESULTS}}.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return -1;
        }

        foreach $keyword ( @{$checking_hash{$cmd}} ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking if $tbl_name is configured by checking the keyword: $keyword.");
            $keyword_found_flag =0;
            foreach ( @{$cli_session->{CMDRESULTS}} ) {
                if ( /$keyword/ ) {
                    $keyword_found_flag =1;
                    last;
                }
            }
            unless ( $keyword_found_flag ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Can't find the keyword $keyword in the '$tbl_name' table -- \n  @{$cli_session->{CMDRESULTS}}.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Successfully found the $keyword in the '$tbl_name'.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully valdiated that the SNMP table '$tbl_name' has been configured.");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Success - all the SNMP tables have been configured for disk usage warning setting.");
    return 1;
}

=head2 generateLogEventsByRestartingStandbyCESystem()

DESCRIPTION:

  This function is to generate log events by restarting the standby CE server and returns the log event data. The generated log events are expected to include Info, Minor, Major and CRITICAL log events for the SYSTEM type and include Info, Minor and Major log events for the DEBUG event type.

=over 

=item ARGUMENTS:

    1st Arg - the cli session;
    2nd Arg - the tms alias of the active CE;
    3rd Arg - the tms alias of the standby CE;
    4th Arg - the log event type (eg DBG or SYS);

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGX4000HELPER::getTimestampBySecond($active_shell_session)) {
    SonusQA::SGX4000::SGX4000HELPER::waitForSystemRunning;
    SonusQA::SGX4000::SGX4000HELPER::getLastTwoLogFiles;
    SonusQA::SGX4000::SGX4000HELPER::getLogEventData;

=item OUTPUT:

    0 - fail;
    \@log_event_datat - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::generateLogEventsByRestartingStandbyCESystem($cli_session);

=back 

=cut

sub generateLogEventsByRestartingStandbyCESystem {

    my ($cli_session,$tms_alias, $second_tms_alias , $event_type )=@_;

    my $sub_name = "generateLogEventsByRestartingStandbyCESystem";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($active_shell_session, $second_shell_session, $time_stamp, $old_log_file_name, $current_log_file_name, $log_file_name, @log_event_data, $cmd);
    my %type_hash = (
            DBG => "debug",
            SYS => "system",
            TRC => "trace",
            ACT => "acct",
        );


    ######################################
    # Step 1: Checking mandatory args;
    ######################################
    unless ( $cli_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tms alias for the active CE is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $second_tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory second tms alias for the standby CE is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $event_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);
    unless ( $active_shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$tms_alias",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            ) )
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't log in linux shell to $tms_alias as root");
        return 0;
    }

    ######################################
    # Step 2: Open new shell sessions;
    ######################################

    $alias_hashref = SonusQA::Utils::resolve_alias($second_tms_alias);
    unless ( $second_shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$second_tms_alias",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            ) )

    {
        $logger->error(__PACKAGE__ . ".$sub_name: Can't log in linux shell to $second_tms_alias as root");
        $active_shell_session->DESTROY;
        return 0;
    }

    ######################################
    # Step 3: Checking if the standby CE is running, get the time stamp and current log file name;
    ######################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the standby CE is running: '$second_tms_alias' before restarting the standby CE.");
    my $result=SonusQA::SGX4000::SGX4000HELPER::waitForSystemRunning($second_tms_alias);
    unless ( $result == 1 ) {
        if ( $result == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub_name: The SGX4000 system is not running on the $second_tms_alias CE server \(waiting for generating log events\).");
        } 
        elsif ( $result == -1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed in checking the SGX4000 system running status on the $second_tms_alias CE server \(waiting for generating log events\).");
        }
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }


    unless ($time_stamp=SonusQA::SGX4000::SGX4000HELPER::getTimestampBySecond($active_shell_session)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the time stamp for $tms_alias.");
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }
    
    ############################################################
    # Step 4: Restarting the standby CE server;
    ############################################################

    #Setting the timeout to 120 seconds

    $second_shell_session->{DEFAULTTIMEOUT} = 120;

    $cmd="service sgx restart";
    $logger->debug(__PACKAGE__ . ".$sub_name: Restarting the sgx system by $cmd on '$second_tms_alias'");
    unless ( $second_shell_session->execShellCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$second_shell_session->{CDMRESULTS}}.");
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }

    # get the lastest log file;

    ############################################################
    # Step 5: Get the log data;
    ############################################################

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking if the standby CE is running: '$second_tms_alias' before retrieving the log event data.");
    $result=SonusQA::SGX4000::SGX4000HELPER::waitForSystemRunning($second_tms_alias);
    unless ( $result == 1 ) {
        if ( $result == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub_name: The SGX4000 system is not running on the $second_tms_alias CE server \(waiting for generating log events\).");
        } 
        elsif ( $result == -1 ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed in checking the SGX4000 system running status on the $second_tms_alias CE server \(waiting for generating log events\).");
        }
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }


    unless ( $log_file_name=SonusQA::SGX4000::SGX4000HELPER::getLastTwoLogFiles($active_shell_session,"$event_type")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the latest log information.");
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }

    unless ( @log_event_data=SonusQA::SGX4000::SGX4000HELPER::getLogEventData($active_shell_session,$time_stamp,$log_file_name)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to retrieve the log event data.");
        $active_shell_session->DESTROY;
        $second_shell_session->DESTROY;
        return 0;
    }

    $active_shell_session->DESTROY;
    $second_shell_session->DESTROY;
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully generated the log event data by restarting the standby CE: $second_tms_alias.");
    return \@log_event_data;
}

=head2 removeCommandAliasSetting()

DESCRIPTION:

  This function removes the alias setting for the specified command if the alias has been set.

=over 

=item ARGUMENTS:

    1st Arg - the shell session;
    2nd Arg - the command name;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::removeCommandAliasSetting($shell_session,$cmd_name);

=back 

=cut

sub removeCommandAliasSetting {

    my ($shell_session,$cmd_name)=@_;

    my $sub_name = "removeCommandAliasSetting";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ######################################
    # Step 1: Checking mandatory args;
    ######################################

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory command name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######################################
    # Step 2: Removing the alias setting;
    ######################################
    unless ( $shell_session->execShellCmd( "alias")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute 'alias' command--\n@{ $shell_session->{CMDRESULTS} }");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } 

    foreach ( @{ $shell_session->{CMDRESULTS} } ) {
        unless ( ! /^alias\s+$cmd_name=/ ) {
            unless ( $shell_session->execShellCmd( "unalias $cmd_name")) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute 'unalias $cmd_name' command--\n@{ $shell_session->{CMDRESULTS} }");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 reInstallCe()

DESCRIPTION:

 This function re-installs the named CE, or CEs, by using port 2024 to get to the linux shell as root, going to the /opt/sonus
 directory and installs the latest name .rpm file based on the information already in sgx.conf. As a backup, the sgx.conf
 file is copied to sgx.conf.<timestamp> in case of failure. Where failure occurs, the function exits and copies back the 
 backup sgx.conf file to sgx.conf.

=over 

=item ARGUMENTS:

   Mandatory:
   1. -ceNames -- An array of tms aliases. (the CE Names)
   Optional:
   2. -rpmPackages -- An array of RPM Packages, for the CEs passed, respectively. If not passed, current version will be reinstalled.
   3. -sshAccess   -- y/n for the Linux shell Access. ( By default 'y')
   4. -sshCliPortIs22 -- y/n to Allow CLI access via ssh port 22 

=item PACKAGE:

 SonusQA::SGX4000::SGX4000HELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1      - success 
 0      - failure

=item EXAMPLE:

 SonusQA::SGX4000::SGX4000HELPER::reInstallCe ( -ceNames => ["asterix", "obelix"],
                                                -rpmPackages => ['sgx4000-V08.02.00-R000.x86_64.rpm', 'sgx4000-V08.02.00-A014.x86_64.rpm'],
                                                -sshAccess => "y",
                                                -sshCliPortIs22 => "y" );

=back 

=cut

sub reInstallCe {
    my (%args) = @_;
    # Get list of CE names
    my @ce_name  = @{$args{-ceNames }};
    #Default value of 'y' for Linux Shell Access.
    unless (defined $args{-sshAccess}) {
        $args{-sshAccess} = "y";
    }
   
    if (defined $args{-sshCliPortIs22} and $args{-sshCliPortIs22} !~ /(y|n)/) {
        delete $args{-sshCliPortIs22};
    }

    my $sub_name = "reInstallCe";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name:  Installing the following machines: @ce_name");
    
    unless (defined $args{-rpmPackages}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: RPM Packages for CEs not passed so the current build will be reinstalled ");
        $args{-rpmPackages} = [];
    }
    
    my ( $ce_for_install, @results, $match_line, $cmd );
    my %install_question;   # To store the values of the expected questions per sgx.conf param
    my %install_parameter;  # To store the values of the params expected in sgx.conf per question
    my %sgx_conf;           # To store the values of the params found in sgx.conf

    my $my_install_path_cmd = "cd /opt/sonus";

    my $error = 0;

    # Keys/Question
    #
    # The $index below represents the question order number the index is incremented in the hash var enter the IP Version for the Management Interface
    # declaration in case the order of questions change, new questions are added or questions
    # are removed. 
    my $index = 1;

    $install_parameter { $index }                         = "role";
    $install_question  { $install_parameter{ $index++ } } = "Enter local host role";

    $install_parameter { $index }                         = "systemName";
    $install_question  { $install_parameter{ $index++ } } = "Enter system name";

    $install_parameter { $index }                         = "ceName";
    $install_question  { $install_parameter{ $index++ } } = "Enter local CE name";

    $install_parameter { $index }                         = "peerCeName";
    $install_question  { $install_parameter{ $index++ } } = "Enter peer CE name";
    
    $install_parameter { $index }                         = "VersionType";
    $install_question  { $install_parameter{ $index++ } } = "enter the IP Version for the Management Interface";
    
    $install_parameter { $index }                         = "gatewayIpaddr";
    $install_question  { $install_parameter{ $index++ } } = "Enter default gateway IP";

    $install_parameter { $index }                         = "nif1Ipaddr";
    $install_question  { $install_parameter{ $index++ } } = "Enter nif1 primary management IP";

    $install_parameter { $index }                         = "nif1Netmask";
    $install_question  { $install_parameter{ $index++ } } = "Enter nif1 primary management netmask"; 

    $install_parameter { $index }                         = "nif5Ipaddr";
    $install_question  { $install_parameter{ $index++ } } = "Enter nif5 secondary management IP";

    $install_parameter { $index }                         = "nif5Netmask";
    $install_question  { $install_parameter{ $index++ } } = "Enter nif5 secondary management netmask";

    $install_parameter { $index }                         = "ntpServerIpaddr";
    $install_question  { $install_parameter{ $index++ } } = "Enter NTP time server IP";
    
    $install_parameter { $index }                         = "allowSshAccess";
    $install_question  { $install_parameter{ $index++ } } = "Allow Linux ssh access";
	
    $install_parameter { $index }                         = "sshCliPort";
    $install_question  { $install_parameter{ $index++ } } = "Allow CLI access via ssh port 22";
    
    # Using questions as keys to the ids in the sgx.conf for later use.
    foreach ( keys ( %install_question )) {
        $install_parameter{ $install_question{ $_ } } = $_; 
    }
    
    #
    # Questions following:
    #  / Ok to apply configuation or R to re-enter? <y/N/R>
    #  / System reboot required. Reboot using updated configuation? <y/N>
    #  / Rebooting in 1sec...
    #  / [root@betty sonus]#

	# Checking the mandatory input;

    unless ( @ce_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CE name input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $number_of_expected_keys = keys ( %install_question );   # Should be number of entries in sgx.conf as each question key is a param in sgx.conf    

    # $match_line will be populated with the questions we are expecting through the install process
    # later on during population | (or) lines will be added between values ready for the waitfor when matching the
    # prompt while actually answering the questions

    # Check CE names
    my $ceNo = -1;
    foreach $ce_for_install ( @ce_name ) {

        # reset index for use in the next loop
        $index = 1;
        $ceNo++;
        # Open session to the linux shell - opening with session logs in case of error.
        my $alias_hashref = SonusQA::Utils::resolve_alias($ce_for_install);
        my $linux_shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$ce_for_install",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            );
        my $previous_err_mode = $linux_shell_session->{conn}->errmode("return");

        unless ( $linux_shell_session->execShellCmd( $my_install_path_cmd )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Could not execute \`$linux_shell_session->{LASTCMD}\` --\n@{ $linux_shell_session->{CMDRESULTS} }");
            $logger->debug(__PACKAGE__ . ".$sub_name: Abandoning install of $ce_for_install");
            $linux_shell_session->DESTROY;
            next;
        } 
        
	# Checking if the sgx.conf file exists - to generate the explicit log mesasges;
	$cmd = "perl -e '{if(-e \"sgx.conf\"){print \"sgx.conf\\n\"}}'";
	unless ( $linux_shell_session->execShellCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not find the sgx.conf file --\n@{ $linux_shell_session->{CMDRESULTS} }");
        $logger->debug(__PACKAGE__ . ".$sub_name: Abandoning install of $ce_for_install");
        $linux_shell_session->DESTROY;
        next;
        }

        unless ( $linux_shell_session->execShellCmd( "cat sgx.conf" )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Could not execute \`$linux_shell_session->{LASTCMD}\` --\n@{ $linux_shell_session->{CMDRESULTS} }");
            $logger->debug(__PACKAGE__ . ".$sub_name: Abandoning install of $ce_for_install");
            $linux_shell_session->DESTROY;
            next;
        }

        # Iterate through the contents of sgx.conf looking for the params needed for install
        # eg. systemName=SGX_barney_betty

        foreach ( @{ $linux_shell_session->{CMDRESULTS} } ) {
            # Strip off comments - if any.
            $_ =~ s/\s*#.*$//;

            # If any blank entries are present in the sgx.conf 
            # the regexp here will not populate a key, so if the number
            # of keys is not what we expect, either there are missing
            # keys, or blank keys.

            # Modify the pattern matching;
            if ( /^(\S+)=(\S+)($|\s+)/ ) {
                # Param and Value found
                # Double check the param found has an expected question in the install
                if ( exists( $install_question{ $1 } ) ) {
                    if ($1 eq "allowSshAccess"){ 
                        $sgx_conf{ $1 } = $args{-sshAccess};
                    } elsif ($1 eq 'sshCliPort') {
                       $sgx_conf{ $1 } = $args{-sshCliPortIs22} ? $args{-sshCliPortIs22} : ($2 eq "22") ? 'y' : 'n';
                    } else {
                        $sgx_conf{ $1 } = $2;
                    }
                }
                else {
                    $logger->warn(__PACKAGE__ . ".$sub_name: Param problem with $1. This doesn't seem to be recognised.");
                    next;
                } 
            }
            elsif ( /^(\S+)=$/ ) {
                # Param with blank value found
                # Try to divine the value 
                $logger->warn(__PACKAGE__ . ".$sub_name: Found a blank key: $1, please check its value in sgx.conf.");
                next;
            }
            
        }

        $sgx_conf{'sshCliPort'} ||= 'y'; #considering 22 as cli port incase of sshCliPort is not present in conf file

        # Check we have the full set
        my $number_of_keys = keys ( %sgx_conf );
        
        unless ( $number_of_keys  <= $number_of_expected_keys ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Number of keys \($number_of_keys\) found in sgx.conf was not sufficent for configuration \($number_of_expected_keys\)");
            $logger->error(__PACKAGE__ . ".$sub_name:  @{ $linux_shell_session->{CMDRESULTS} }");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
            $linux_shell_session->DESTROY;
            next;
        }

        # Back up current sgx.conf file
        my @local_time = localtime(); 
        $local_time[5] += 1900 ;    # Year
        $local_time[4] += 1 ;       # Month
        my $date_stamp = sprintf ("%d%02d%02d_%02d%02d%02d", $local_time[5], $local_time[4], $local_time[3], $local_time[2], $local_time[1], $local_time[0]);

        # Checking if there is the alias setting for 'cp', remove the prompt when we copy the files;
        unless ( SonusQA::SGX4000::SGX4000HELPER::removeCommandAliasSetting($linux_shell_session,"cp") ) { 
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to removed the command alias setting for 'cp'.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
            $linux_shell_session->DESTROY;
            next;
        }

        unless ( $linux_shell_session->execShellCmd( "cp -f sgx.conf sgx.conf.$date_stamp" )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not copy sgx.conf to a backup file --\n@{ $linux_shell_session->{CMDRESULTS} }");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
            $linux_shell_session->DESTROY;
            next;
        } 

        my $backup_file = "sgx.conf.$date_stamp";
        $logger->debug(__PACKAGE__ . ".$sub_name:  Backed up sgx.conf on $ce_for_install to $backup_file");
        #
        # Reinstall...
        #
        # Find last listed rpm.
        my @rpmPackages = @{$args{-rpmPackages}};
        my $rpm_for_install ;
		my $isInstallVersion73="no";
        unless(defined $rpmPackages[$ceNo]){
            unless ( $linux_shell_session->execShellCmd( "rpm -qa | grep sgx4000" )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute \`$linux_shell_session->{LASTCMD}\` --\n@{ $linux_shell_session->{CMDRESULTS} }");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                next;
            }
            unless ( $linux_shell_session->{CMDRESULTS}[0] =~ /sgx4000/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Could not find any rpm File in the SGX box "); 
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                $linux_shell_session->DESTROY;
                next;
            }
            $rpm_for_install = $linux_shell_session->{CMDRESULTS}[0];
            $rpm_for_install .= ".x86_64.rpm";
        } else  {
            $linux_shell_session->execShellCmd( "ls | grep $rpmPackages[$ceNo]" );
            unless($linux_shell_session->{CMDRESULTS}[0] eq $rpmPackages[$ceNo] ) {
                $logger->error(__PACKAGE__ . ".$sub_name: The rpm package name passed for the CE $ce_for_install does not exist in /opt/sonus dir");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                next;
            }
            $rpm_for_install = $rpmPackages[$ceNo];
            $logger->debug(__PACKAGE__ . ".$sub_name:  RPM Package Passed $rpm_for_install is Valid ");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Installing the following rpm: $rpm_for_install");
       if($rpm_for_install =~/V07.03/)
        {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Skipping Management IP version prompts for 07.03.xx versions");
			$isInstallVersion73="yes";
        }

        
        # Pull the trigger.
        unless ( $linux_shell_session->{conn}->print( "./sgxInstall.sh -f $rpm_for_install" ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'./sgxInstall.sh -f $rpm_for_install\'");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
            # Ctrl-C
            $linux_shell_session->{conn}->cmd("\cC");
            $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
            $linux_shell_session->DESTROY;
            next;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'./sgxInstall.sh -f $rpm_for_install\'");

        # Loop through the sgx_conf hash in order
        my ($prematch, $match);

		#The Management IP version is not present for 7.3.6 release, so reduce one prompt
		if(lc($isInstallVersion73) eq "yes")
		{
			$number_of_keys--;
		}


        for (1..$number_of_keys) {
            # $match_line below is populated with the install questions separated by |
            # the var is populated as part of the %sgx_conf config
            unless ( ($prematch, $match) = $linux_shell_session->{conn}->waitfor(
                                                                     -match     => '/Enter local host role/',
                                                                     -match     => '/Enter system name/',
                                                                     -match     => '/Enter local CE name/',
                                                                     -match     => '/Enter peer CE name/',
                                                                     -match     => '/enter the IP Version for the Management Interface/',
                                                                     -match     => '/Enter default gateway IP/',
                                                                     -match     => '/Enter nif1 primary management IP/',
                                                                     -match     => '/Enter nif1 primary management netmask/',
                                                                     -match     => '/Enter nif5 secondary management IP/',
                                                                     -match     => '/Enter nif5 secondary management netmask/',
                                                                     -match     => '/Enter NTP time server IP/',
                                                                     -match     => '/Allow Linux ssh access/',
                                                                     -match     => '/Allow CLI access via ssh port 22/',
                                                                     -Timeout   => 180,
                                                                )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Did not receive the expected install prompt. $linux_shell_session->dump_log()");
                if ( $match ) {
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Last prompt: $match");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                $error = 1;
                last;
            }

            # Answer prompt by the function of 'print';
            # sgx_conf hash: 1) to get the question from the $match;
            #                2) to link the keyword (sgx.conf) from the question;
            #                3) to get the key value from the sgx.conf;
            # 
            if (($match =~ /enter the IP Version for the Management Interface/) ){
                $linux_shell_session->{conn}->print( "v4" );
                $logger->debug(__PACKAGE__ . ".$sub_name:  Entering v4 at the \'$match\' prompt");
            }
            else {
                $linux_shell_session->{conn}->print( $sgx_conf{ $install_parameter{ $match } } );
                $logger->debug(__PACKAGE__ . ".$sub_name:  Entering $sgx_conf{ $install_parameter{ $match } } at the \'$match\' prompt ");
            }
        }
        unless ( $error ) {
            # Now we expect Ok to apply configuation or R to re-enter
            unless ( ($prematch, $match) = $linux_shell_session->{conn}->waitfor(
                                                    -match => '/Ok to apply configuration or R to re-enter/',
                                                  )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Did not receive \'Ok to apply configuration or R to re-enter\'prompt.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                next;
            }

            $linux_shell_session->{conn}->print( "y" );
            $logger->debug(__PACKAGE__ . ".$sub_name:  Entering \'y\' at the \'$match\' prompt");

            # Now we expect Ok to apply configuation or R to re-enter
            unless ( $linux_shell_session->{conn}->waitfor(
                                                    -match => '/System reboot required. Reboot using updated configuration/',
                                                  )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Did not receive \'System reboot required. Reboot using updated configuration\'prompt.");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                next;
            }

            # Note: if we use the execShellCmd("y"), the returning code of 'echo $?' is:'[root@heckle sonus]# echo $? 0ts/1) (Thu Jul 23 14:20:45 2009)';
            # So execShellCmd is not used here;

            # Sending 'y' command and expecting the countdown of 5 seconds before rebooting;

            $logger->debug(__PACKAGE__ . ".$sub_name:  Entering \'y\' at the \'System reboot required\' prompt and expecting the countdown of 5 seconds.");
            $linux_shell_session->{conn}->print( "y" );
            unless ( $linux_shell_session->{conn}->waitfor(
                                                    -match => '/Rebooting\s+in\s+1sec\.\.\./',
                                                  )) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Did not receive the expected reboot prompt: 'Rebooting in 1sec...'");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Abandoning install of $ce_for_install");
                # Ctrl-C
                $linux_shell_session->{conn}->cmd("\cC");
                $linux_shell_session->execShellCmd( "cp -f sgx.conf.$date_stamp sgx.conf" );
                $linux_shell_session->DESTROY;
                next;
            }

        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  SUCCESS. $ce_for_install has been re-booted to complete the install");
    
    } # END foreach ce name

    if ( $error ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Errors found in installing one or more machines");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
}


=head2 switchSystemFromDualToSingle()

DESCRIPTION:

  This function changes a pair of SGX4000 systemm from dual to single. It copies the original sgx.conf to sgx.dual.conf and changes the peerCeName to none and the role to 1 and then overrides the sgx.conf. 

=over 

=item ARGUMENTS:

    Mandatory:
   1. -ceNames -- An array of tms aliases. (the CE Names)
   Optional:
   2. -rpmPackages -- An array of RPM Packages, for the CEs passed, respectively. If not passed, current version will be reinstalled.
   3. -sshAccess   -- y/n for the Linux shell Access. ( By default 'y')

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGX4000HELPER::reInstallCe;

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::switchSystemFromDualToSingle(
                                                -ceNames => ["asterix", "obelix"],
                                                -rpmPackages => ['sgx4000-V08.02.00-R000.x86_64.rpm', 'sgx4000-V08.02.00-A014.x86_64.rpm'],
                                                -sshAccess => "y");

=back 

=cut

sub switchSystemFromDualToSingle {
    my (%args) = @_;
    my @tms_alias = @{$args{-ceNames }};
  
    my $sub_name = "switchSystemFromDualToSingle";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    #Default value of 'y' for Linux Shell Access.
    unless (defined $args{-sshAccess}) {
        $args{-sshAccess} = "y";
    }
    unless (defined $args{-rpmPackages}) {
        $args{-rpmPackages} = [];
    }
    
    my $install_path="/opt/sonus";
    my (@linux_shell_session,$shell_session, $cmd);

    ######################################
    # Step 1: Checking mandatory args;
    ######################################

    unless ( @tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory the tms alias input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######################################
    # Step 2: Open shell sessions to both CEs;
    ######################################


	foreach (@tms_alias ) {
        my $alias_hashref = SonusQA::Utils::resolve_alias($_);
        unless ( $shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$_",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            ) )
        {
            $logger->error(__PACKAGE__ . ".$sub_name: Can't log in linux shell to $_ as root");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
		push @linux_shell_session,$shell_session;
    	$logger->debug(__PACKAGE__ . ".$sub_name: Logged into the $_ root and opened a new shell session.");
	}

    ############################################################
    # Step 3: Backup the sgx.file and changed it to single system config;
    ############################################################

	foreach $shell_session ( @linux_shell_session ) {
        # Checking if there is the alias setting for 'cp', remove the prompt when we copy the files;
        unless ( SonusQA::SGX4000::SGX4000HELPER::removeCommandAliasSetting($shell_session,"cp") ) { 
        	$logger->error(__PACKAGE__ . ".$sub_name: Failed in removing alias setting for the 'cp' command.");
        	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
			return 0;
		}
		
    	# copy and changed the sgx.conf file
    	# Changing the role to 1 and peerCeName to none;
    	foreach $cmd (  "cd $install_path",
    					"cp -f sgx.conf sgx.dual.conf",
    					"perl -ane 'if(/(role)=\\d+/){print \"\$1=1\\n\"}else{print \$_}' sgx.dual.conf>sgx.tmp",
    					"perl -ane 'if(/(peerCeName)=\\w+/){print \"\$1=none\\n\"}else{print \$_}' sgx.tmp>sgx.conf",
    					"rm -f sgx.tmp",
    				)
    	{
    		unless ( $shell_session->execShellCmd($cmd)) {
            	$logger->error(__PACKAGE__ . ".$sub_name: Failed to execute $cmd --\n@{$shell_session->{CMDRESULTS}}.");
            	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    			return 0;
            }
    	}
	}

    ############################################################
    # Step 4: Re-Install both CEs and reboot both CEs and waiting it to be on;
    #         Checking if they are on the single system
    ############################################################

	unless ( SonusQA::SGX4000::SGX4000HELPER::reInstallCe(-ceNames => $args{-ceNames }, -rpmPackages => $args{-rpmPackages }, -sshAccess => $args{-sshAccess } )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to re-install the @tms_alias");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully re-installed the ce: @tms_alias");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 switchSystemFromSingleToDual()

DESCRIPTION:

  This function changes a pair of SGX4000 systemm from single to dual. It copies the backup file 'sgx.dual.conf' and overwrites the sgx.conf.
  It only works with the condition that the system was initially running on the dual mode as this sub requires the sgx.dual.conf file which was copied from sgx.conf when it was changed from dual mode to single mode.

=over 

=item ARGUMENTS:

    1st Arg - the tms alias array;

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::SGX4000HELPER::reInstallCe;

=item OUTPUT:

    0 - fail;
    1 - success;

=item EXAMPLE:

    SonusQA::SGX4000::SGX4000HELPER::switchSystemFromSingleToDual(
                                                    -ceNames => ["asterix", "obelix"],
                                                    -rpmPackages => ['sgx4000-V08.02.00-R000.x86_64.rpm', 'sgx4000-V08.02.00-A014.x86_64.rpm'],
                                                    -sshAccess => "y");

=back 

=cut

sub switchSystemFromSingleToDual {

    my (%args) = @_;
    my (@tms_alias) = @{$args{-ceNames }};

    my $sub_name = "switchSystemFromSingleToDual";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    #Default value of 'y' for Linux Shell Access.
    unless (defined $args{-sshAccess}) {
        $args{-sshAccess} = "y";
    }
    unless (defined $args{-rpmPackages}) {
        $args{-rpmPackages} = [];
    }
    
    my $install_path="/opt/sonus";
    my (@linux_shell_session,$shell_session, $cmd);

    ######################################
    # Step 1: Checking mandatory args;
    ######################################

    unless ( @tms_alias ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory the tms alias input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######################################
    # Step 2: Open shell sessions to both CEs;
    ######################################


	foreach (@tms_alias ) {
        my $alias_hashref = SonusQA::Utils::resolve_alias($_);
        unless ( $shell_session = SonusQA::SGX4000->new(-obj_hosts  => [
                                                                    "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                    "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                   ],
                                             -obj_hostname      => "$_",
                                             -obj_user          => "root",
                                             -obj_password      => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype      => "SSH",
                                             -obj_port          => "2024",
                                             -sessionlog        => 1,
                                            ) )
        {
            $logger->error(__PACKAGE__ . ".$sub_name: Can't log in linux shell to $_ as root");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
		push @linux_shell_session,$shell_session;
    	$logger->debug(__PACKAGE__ . ".$sub_name: Logged into the $_ root and opened a new shell session.");
	}

    ############################################################
    # Step 3: Backup the sgx.file and changed it to single system config;
    ############################################################

	foreach $shell_session ( @linux_shell_session ) {
        # Checking if there is the alias setting for 'cp', remove the prompt when we copy the files;
        unless ( SonusQA::SGX4000::SGX4000HELPER::removeCommandAliasSetting($shell_session,"cp") ) { 
        	$logger->error(__PACKAGE__ . ".$sub_name: Failed in removing alias setting for the 'cp' command.");
        	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
			return 0;
		}
		
    	# copy and changed the sgx.conf file
    	# Changing the role to 1 and peerCeName to none;
    	foreach $cmd (  "cd $install_path",
    					"cp -f sgx.dual.conf sgx.conf",
    				)
    	{
    		unless ( $shell_session->execShellCmd($cmd)) {
            	$logger->error(__PACKAGE__ . ".$sub_name: Failed to execute $cmd --\n@{$shell_session->{CMDRESULTS}}.");
            	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    			return 0;
            }
    	}
	}

    ############################################################
    # Step 4: Re-Install both CEs and reboot both CEs and waiting it to be on;
    #         Checking if they are on the single system
    ############################################################

	unless ( SonusQA::SGX4000::SGX4000HELPER::reInstallCe(-ceNames => $args{-ceNames }, -rpmPackages => $args{-rpmPackages }, -sshAccess => $args{-sshAccess }) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to re-install the @tms_alias");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully re-installed the ce: @tms_alias, from Single to Dual");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

sub installLicense {

    my $cli_session = shift;

    my $license_cmd = "set license bundle bundle \"<licenseBundle hash=\\\"C654B512CBD12C457A986090831B1EF9842B7CF2\\\"><version>V01.00.00</version><licenseInfo><featureId>SGX-SS7</featureId><usageLimit>1</usageLimit></licenseInfo><licenseInfo><featureId>SGX-SIG</featureId><usageLimit>1</usageLimit></licenseInfo><licenseInfo><featureId>SGX-CAP-SM</featureId><usageLimit>1</usageLimit></licenseInfo><licenseInfo><featureId>SGX-CAP-SM-TO-MED</featureId><usageLimit>1</usageLimit></licenseInfo><licenseInfo><featureId>SGX-CAP-MED-TO-LRG</featureId><usageLimit>1</usageLimit></licenseInfo><licenseInfo><featureId>SGX-DUAL-CE</featureId><usageLimit>1</usageLimit></licenseInfo></licenseBundle>\"";

    my $sub_name = "installLicense";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $cli_session ) { 
        $logger->error(__PACKAGE__ . ".$sub_name: SGX4000 connection object missing from function call"); 
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->enterPrivateSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot enter private session");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->execCommitCliCmd( $license_cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot enter private session");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cli_session->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot leave configure session");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Created license");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 setNewTimeZone()

DESCRIPTION:

    This subroutine is used to reveal debug commands in the SGX4000 CLI. It basically issues the unhide debug command and deals with the prompts that are presented.

=over

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The SGX4000 root user password 

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

   None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SGX4000::SGX4000HELPER::unhideDebug ( $cli_session, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        return 0;
    }

=back 

=cut

sub setNewTimeZone {

    my $cli_session     = shift;
    my $sgx_system_name = shift;
    my $time_zone       = shift;

    my $sub_name = "setNewTimeZone";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $previous_err_mode = $cli_session->{conn}->errmode("return");

    # set ntp timeZone SGX_asterix_obelix zone gmt
    my $cli_command = "set ntp timeZone $sgx_system_name zone $time_zone";
    unless ( $cli_session->{conn}->print( $cli_command ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'$cli_command\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'$cli_command\'");

    my ($prematch, $match);
    unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                                    -match => '/\[ok\]/',
                                                                    -match => '/\[error\]/',
                                                                    -match => $cli_session->{PROMPT},
                                                                )) {    
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'$cli_command\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/\[ok\]/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched ok: prompt");

        # execute "commit" - to set the new time zone
        $cli_session->{conn}->print( "commit" );

        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                -match => '/Do you wish to continue/',   
                                                -match => '/No modifications to commit/',
                                                -match => '/\[ok\]/',   
                                                -match => '/\[error\]/', 
                                              )) {    
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on \'commit\'.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/Do you wish to continue/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  commit generated warning for \'$cli_command\'");

            $cli_session->{conn}->print( "yes" );
            unless ( ($prematch, $match) = $cli_session->{conn}->waitfor( 
                                                    -match => '/\[ok\]/',   
                                                    -match => '/\[error\]/',
                                                    -match => $cli_session->{PROMPT},
                                                  )) {    
print "\nNO MATCH after entering YES - match=$match, prematch=$prematch\n";
                $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on \'commit\'.");
        	$logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $cli_session->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            if ( $match =~ m/\[ok\]/ ) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  New time set and commited successfully.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            }
            elsif ( $match =~ m/\[error\]/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  commit used to set new time zone caused error.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            elsif ( $match =~ m/$cli_session->{PROMPT}/ ) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  New time set and commited successfully.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }
        elsif ( $match =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  $cli_command used to set new time zone caused error.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }   
        else {
print "\nmay be \'No modifications to commit\' or \'OK\'\n";
print "\ncommit over - match=$match, prematch=$prematch\n";
            $logger->debug(__PACKAGE__ . ".$sub_name:  commit accepted for \'$cli_command\'");
            # TBD
        }

    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'$cli_command\' command error:\n$prematch\n$match");
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

=head2 getEthInterfaceFromIfconfig()

DESCRIPTION:

 This function uses ifconfig to match the mac addres and retreive the eth interface.

=over 

=item ARGUMENTS:

   1st Arg - the root session attached to the CE server;
   2nd Arg - mac address of the port, for which the interface to be retreived.

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None    

=item OUTPUT:

    0 - fail;
    $eth_interface - success;

=item EXAMPLE:

    unless ($eth_interface = SonusQA::SGX4000::SGX4000HELPER::getEthInterfaceFromIfconfig($root_session,$mac_address) ) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get the eth interface from ifconfig.");
        return 0;
    }

=back 

=cut

sub getEthInterfaceFromIfconfig {

    my ($root_session,$mac_address) = @_ ;

    my $sub_name = "getEthInterfaceFromIfconfig";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $interface;

    unless ( $root_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory root session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $mac_address ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory mac address input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd="ifconfig -a | grep HWaddr";

    unless ( $root_session->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd --\n@{$root_session->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }  

    foreach ( @{$root_session->{CMDRESULTS}} ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: $_");
    #           eth4      Link encap:Ethernet  HWaddr 00:21:28:05:D4:2E
        if ( /^(eth\d+)\s+Link encap\:(\S+)\s+HWaddr\s+(\S+\:\S+\:\S+\:\S+\:\S+\:\S+)/i ) {
            #   ^- 1 -^                ^2^              ^------------ 3 ------------^
            # $1  - interface
            # $3  - link
            # $3  - MAC Address
            my $tmp = $1;

            if ( ($2 eq "Ethernet") && ($3 =~ m/$mac_address/i) ) {
                $interface = $tmp;
                #print "\ninterface = $tmp\n";
            }
        }
    }

    unless (defined $interface) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to find eth interface for given mac address in ifconfig.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    else {
        $logger->info(__PACKAGE__ . ".$sub_name: Successfully got the eth interface name: $interface.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [eth interface name]");
        return $interface;
    }

}


sub enterSSHConnection {

    my ( $shell_session, $server_ip, $login_id, $password, $ssh_ver ) = @_;
    my $sub_name = "enterSSHConnection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    unless ( $shell_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $server_ip ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory SSH server IP input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $login_id ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory SSH login ID input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $password ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory SSH login password input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $ssh_ver ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory SSH version input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $cmd;
    if ( $ssh_ver == 1 ) {
        $cmd = "ssh -1 $login_id\@$server_ip";
    } elsif ( $ssh_ver == 2 ) {
        $cmd = "ssh $login_id\@$server_ip";
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Starting to SSH connection with cmd \'$cmd\' and password \$password.");

    my @result;
    unless ( $shell_session->{conn}->print( "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
 
    my ($prematch, $match);
    unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => '/Are you sure you want to continue connecting \(yes\/no\)/',
                                                                    -errmode   => "return",
                                                                   ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unexpected prompt - after executing \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if ( $match =~ m/\(yes\/no\)/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes/no prompt for RSA key fingerprint");
        $shell_session->{conn}->print("yes");
        unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'yes\' to RSA key fingerprint prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched password: prompt");
        $shell_session->{conn}->print($password);
        unless ( ($prematch, $match) = $shell_session->{conn}->waitfor(
                                                -match => '/Permission denied/',
                                                -match => $shell_session->{PROMPT},
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $shell_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $shell_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if ( $match =~ m/Permission denied/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($password\) for SSH login was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'$cmd\'");
        }

    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  command \'$cmd\' error:\n$prematch\n$match.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Sucessfull SSH login.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 emsLicense()

DESCRIPTION:

    This subroutine is used to push license from EMS to the target device

=over 

=item ARGUMENTS:

    1st Arg    - CLI session
    2nd Arg    - EMS IP address
    3rd Arg    - Device Name in EMS

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    &SonusQA::EMS::EMSHELPER::emsLicense()

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( $sgx_object->emsLicense($emsIP, $sgxNameInEms) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot push the license from EMS");
        return 0;
    }

=back 

=cut

sub emsLicense {

   my ($self, $emsIp, $sgxNameInEms) = @_;
   
   my $sub_name = "emsLicense";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

   ##################################################
   # Step 1: Checking mandatory args;
   ##################################################

   unless ( defined $emsIp ) {
      $logger->error(__PACKAGE__ . ".$sub_name: Mandatory EMS IP address input is empty or blank.");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
   }

    unless ( defined $sgxNameInEms ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter - SGX name in EMS input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    MAIN: foreach my $attempt (1..3) {
    	unless(&SonusQA::EMS::EMSHELPER::emsLicense($self,-deviceName => $sgxNameInEms, -deviceType => 'SGX4000', -emsIP => $emsIp)){
            $logger->error(__PACKAGE__ . ".$sub_name:  Unable to push license on the EMS for SGX \'$sgxNameInEms\' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

	my $cmdString = "show table license info";

        $logger->debug(__PACKAGE__ . ".$sub_name cmdString : $cmdString");

        # Execute the CLI
        unless($self->execCliCmd($cmdString)) {
            $logger->error (__PACKAGE__ . ".$sub_name Failed CLI execution");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name Output : " . Dumper ($self->{CMDRESULTS}));

        $cmdString = "show table license timeStamp";

        $logger->debug(__PACKAGE__ . ".$sub_name cmdString : $cmdString");

        # Execute the CLI
        unless($self->execCliCmd($cmdString)) {
            $logger->error (__PACKAGE__ . ".$sub_name Failed CLI execution");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name Output : " . Dumper ($self->{CMDRESULTS}));

        my @output = @{$self->{CMDRESULTS}};
        foreach (@output) {
            if (/No entries found/){
                unless ($attempt == 3) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to push the license to SGX on attempt $attempt. Let's try again");
                    next MAIN;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to push the license to SGX after $attempt attempts");
                    return 0;
                }
            }
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully pushed the license to SGX");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: All 3 attempts to push the license to SGX have failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
}

=head2 checkSGXcoreOnBothCE()

DESCRIPTION:

    This subroutine is used to check the presence of core file on Both CEs

=over 

=item ARGUMENTS:

    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1
    -testId         => Test case ID

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( $sgx_object->checkSGXcoreOnBothCE ( -sgxAliasCe0 => $sgxAliasCe0,
                                                 -sgxAliasCe1 => $sgxAliasCe1,
                                                 -testId      => $testId ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Error in checking core file, or core file present");
        return 0;
    }

=back 

=cut

sub checkSGXcoreOnBothCE {
   my ($self, %args) = @_;
   my %a   = {-expectCore => 0};
   my $sub = "checkSGXcoreOnBothCE()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $foundCoreOnCE0 = 0;
   my $foundCoreOnCE1 = 0;

   # Check the core file in CE0
   unless($self->checkSGXcore(-sgxAlias   => $a{-sgxAliasCe0},
                              -testId     => $a{-testId},
                              -expectCore => $a{-expectCore})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in checking core file in CE0 SGX");
      $foundCoreOnCE0 = 1;
   }

   # Check the core file in CE1
   unless($self->checkSGXcore(-sgxAlias   => $a{-sgxAliasCe1},
                              -testId     => $a{-testId},
                              -expectCore => $a{-expectCore})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in checking core file in CE1 SGX");
      $foundCoreOnCE1 = 1;
   }

   if(($foundCoreOnCE0 eq 1) or ($foundCoreOnCE1 eq 1)) {
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   # There is no core file present.
   $logger->debug(__PACKAGE__ . ".$sub Leaving sub successful. There is no core dump present in SGX");
   return 1;
}

=head2 checkSGXcore()

DESCRIPTION:

    This subroutine is used to check the presence of core file on CE

=over 

=item ARGUMENTS:

    -sgxAlias    => SGX alias
    -testId      => Test case ID

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::ATSHELPER::newFromAlias
    SonusQA::SGX4000::execCmd

=item OUTPUT:

    0   - fail 
    1   - success

=item EXAMPLE:

    unless ( $sgx_object->checkSGXcore (-sgxAlias => $sgxAlias,
                                        -testId   => $testId) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Error in checking core file, or core file present");
        return 0;
    }

=back 

=cut

sub checkSGXcore {
   my ($self,%args) = @_;
   my %a   = {-expectCore => 0, -expectCoreCnt => 1};
   my $sub = "checkSGXcore()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   
   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $active_ce = $self->{OBJ_HOSTNAME};
   my $expectCount;
   my $core_path;
   if(defined $a{-corePath}){
      $core_path = $a{-corePath};
   }else{ 
      unless ($core_path = $self->getCoreFilePath( $active_ce)) {
	$logger->error(__PACKAGE__ . ".$sub : unable to get the core file path");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub : core file path => $core_path");

   # Get the SGX object
   my $tmsAlias = $a{-sgxAlias};

   $logger->debug(__PACKAGE__ . ".$sub : open a session to $tmsAlias");

   # open a shell session
   my $shellSession;

   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias ( 
                                       -tms_alias    => $tmsAlias, 
                                       -obj_port     => 2024, 
                                       -obj_user     => "root", 
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub Error in logging in linux shell as root");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }

   $shellSession = $self->{shell_session}->{$tmsAlias};

   $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");

   $shellSession->execShellCmd("mkdir -p /tmp/ATS_Cores");
		   
   $logger->debug(__PACKAGE__ . ".$sub : Made a Directory /tmp/ATS_Cores");
		 	   		 
   my $cmdString = "cd $core_path";
  
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Into the Core Directory Location......");

   $cmdString = "ls -l";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   unless ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub ls -l out put : @{$shellSession->{CMDRESULTS}}");
   my $count = 0;
   my $coreFileName;
   my @coreFileNames;
   my $line;

   # Parse the output for the required string
   foreach $line ( @{ $shellSession->{CMDRESULTS}} ) {
      chomp $line;
      # get the core file name. If trace is attached leave it
      if(!($line =~ /trace/i )) {
	 if($line =~ m/(core\.\d?\.?CE_.*_.*\.[0-9]+)/i) {
            $coreFileName = $1;
            $logger->error(__PACKAGE__ . ".$sub There is a core... => $coreFileName");

            # store the core file name
            push(@coreFileNames, $coreFileName);
            $count++;
         }
      } else {
         $logger->error(__PACKAGE__ . ".$sub contains trace.");
      }
   }
   if ($self->{CHECK_CORE} == 1) {
      if ($count > 0) {
          $logger->debug(__PACKAGE__ . ".$sub: core found");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
          return 1;
      } else {
         $logger->debug(__PACKAGE__ . ".$sub: no core found");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }
   }   

   # move the core file name to $testId_core_xxx_000 format. So that next test case
   # won't identify this as a new core generated
   foreach $coreFileName (@coreFileNames) {

      # store the core file name for later use
      my $orgCoreFileName = $coreFileName;
      my $newCoreFileName;

      # Change the core file name to core_xxx_0000
      $coreFileName =~ s/\./\_/g;

      # Coredump Expected?, how many
      if (( $a{-expectCore} eq 1 ) && ($expectCount <= $a{-expectCoreCnt})) {
          # Add the test ID
          $newCoreFileName = "ATS_" . $a{-testId} . "_" . $coreFileName;
          $count--;
          $expectCount++;
      }
      else {
          # Add the test ID
          $newCoreFileName = $a{-testId} . "_" . $coreFileName;
      }

      # move the core file to the new name
      $cmdString = "mv $orgCoreFileName /tmp/ATS_Cores/$newCoreFileName";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");
      if ($shellSession->execCmd("$cmdString")) {
         $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
		 $logger->error(__PACKAGE__ . ".$sub WARNING: A \"mv\" command fail may cause a testcase to invalidly fail, due to the same coredump being found again");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }
   }

   if($count eq 0) {
      $logger->debug(__PACKAGE__ . ".$sub Leaving sub successful. There is no core dump");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
      return 1;
   }

   $logger->error(__PACKAGE__ . ".$sub: Core file present in SGX");
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
   return 0;
}

=head2 handleConfigureCmd()

DESCRIPTION:

    This subroutine executes the command string provided

=over 

=item ARGUMENTS:

    -cmdString       => The command to be executed

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::enterPrivateSession
    SonusQA::SGX4000::execCommitCliCmd
    SonusQA::SGX4000::leaveConfigureSession

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sgx_object->handleConfigureCmd(-cmdString         => $cmdString)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing config command");
        return 0;
    }

=back 

=cut

sub handleConfigureCmd {
   my ($self, %args) = @_;
   my %a;
   my $sub = "handleConfigureCmd()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   unless ( $self->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode--\n @{$self->{CMDRESULTS}}" );
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub cmdString : $a{-cmdString}");

   my $retCode = 1;

   # Execute the CLI
   unless($self->execCommitCliCmdConfirm($a{-cmdString})) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      $retCode = 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

   unless ( $self->leaveConfigureSession() ) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to leave private session--\n @{$self->{CMDRESULTS}}" );
      $retCode = 0;
   }
   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$retCode]");

   #  Return status
   return $retCode;
}

=head2 setSs7IsupProfileValue()

DESCRIPTION:

   Uses the profileName, element and value passed in to set a value in the isup profile on the SGX

=over 

=item ARGUMENTS:

    -sgxCommand => The command received which contains the required information

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000HELPER::handleConfigureCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=back 

=cut

##################################################################################
sub setSs7IsupProfileValue {
##################################################################################

  my ($self, %args) = @_;
  my $sub = "set Ss7IsupProfileValue()";
  my %a;
  my $cmdString;

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  my ($type, $command, $profileName, $element, $value) = split ( /_/, $a{-sgxCommand});

  $logger->info(-pkg => __PACKAGE__, -sub => $sub, %a );

  $logger->info(__PACKAGE__ . ".$sub profileName $profileName element $element value $value \n");
  $cmdString = "set ss7 isupProfile $profileName $element $value";
  
  # Execute the CLI
  unless($self->handleConfigureCmd(-cmdString => $cmdString)) {
	$logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
	return 0;
  }

 return 1; 
}

=head2 getSs7IsupProfileValue()

DESCRIPTION:

   Uses the profileName, element and value passed in to get a value in the isup profile on the SGX

=over 

=item ARGUMENTS:

    -profileName => The name of the ss7 Isup profile
    -element     => Element number - 7
    -value       => Element value - yes

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000HELPER::handleConfigureCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    NAME          INDEX  STATE    SUPPORT  SUPPORT  OUTAGE  CGBS   BASE CIC    RANGE       RESPONSE TBL        
    -----------------------------------------------------------------------------------------------------------
    itu           6      enabled  no       yes      yes     yes    no          no          ituMsgRes           

    # Check Send2CGBS is yes
    $sgx_obj->getSs7IsupProfileValue(-profileName => "itu", -element => 7, -value => "yes" );

=back 

=cut

##################################################################################
sub getSs7IsupProfileValue {
##################################################################################

    my ($self, %args) = @_;
    my $sub = "getSs7IsupProfileValue()";
    my %a;
    my ($cmdString, $return_value);

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $return_value = 0;

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->info(__PACKAGE__ . ".$sub: --> Entered");
    $logger->info(__PACKAGE__ . ".$sub profileName $a{-profileName} element $a{-element} value $a{-value} \n");
    
    # Reduce by 1 because of Array reference
    $a{-element} = $a{-element} - 1;
    
    $cmdString = "show table ss7 isupProfile";

    # Execute the CLI
    unless($self->execCliCmd($cmdString)) {
        $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
        $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));
        $return_value = 0;
    }
    else {
        $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));
        foreach(@{$self->{CMDRESULTS}}){

           # Line starts with Profile name
           if(m/^$a{-profileName}/){
               my @elements = split(/\s+/, $_);
               $logger->info(__PACKAGE__ . ".$sub Value of Element is :$elements[$a{-element}]");
               if ( $elements[$a{-element}] eq $a{-value} ) {
                   $return_value = 1;
               }
               last;
           }
        }       
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving");   
    return $return_value; 
}

=head2 sgxClearCicPersistentTable()

DESCRIPTION:

   Clears all entries from the cicPersistentTable on the SGX

=over 

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::execCliCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=back 

=cut

##################################################################################
sub sgxClearCicPersistentTable {
##################################################################################

  my ($self, %args) = @_;
  my $sub = "sgxClearCicPersistentTable()";
  my %a;
  my ($cmdString, $line);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $cmdString = "show table m3ua cicPersistentTable";

  $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

  unless($self->execCliCmd($cmdString)){
	$logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
	return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

  my @fields;
  my $dataStr;
  my $skipLines = 0;

  my @result = @{$self->{CMDRESULTS}};
  my $retStatus = 1;

  foreach $line ( @result ) {
	if($skipLines lt 2) {
	  $skipLines = $skipLines + 1;
	  next;
	}
	if($line =~ m/------/) {
	  next;
	}
	if($line =~ "[ok]") {
	  last;
	}

	@fields = split(' ', $line);

	$cmdString = "request m3ua cicPersistentTable $fields[0] $fields[1] $fields[2] $fields[3] $fields[4] $fields[5] delete";
	$logger->info(__PACKAGE__ . ".$sub line : $cmdString");

	unless($self->execSystemCliCmd($cmdString)){
	  $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
	  return 0;
	}

        if (grep(/result\s+failure/, @{$self->{CMDRESULTS}})) {
           $logger->error(__PACKAGE__ . ".$sub \'$cmdString\' command execution failed");
           $logger->error(__PACKAGE__ . ".$sub" . Dumper($self->{CMDRESULTS}));
           $retStatus = 0;
        }
  }
  $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub [$retStatus]");
  return $retStatus;
}

=head2 closeSGXSSHConnections()

DESCRIPTION:

    This subroutine closes an array of connections provided.

=over 

=item ARGUMENTS:

    1st Arg - The array of object references

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sgx_object->closeSGXSSHConnections(@ce_shell_sessions)) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to close SGX connections");
        return 0;
    }

=back 

=cut

sub closeSGXSSHConnections {
   my (@openConnections) = @_;
   my $sub = "closeSGXSSHConnections()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->debug(__PACKAGE__ . ".$sub: Closing SGX4000 connections");

   foreach ( @openConnections ) {
      my $cli_session = $_;

      $logger->debug(__PACKAGE__ . ".$sub: closing the connection $cli_session->{OBJ_HOSTNAME}");
      $cli_session->DESTROY;
      $cli_session = undef;
      $logger->debug(__PACKAGE__ . ".$sub: closed the connection");
   }

   $logger->debug(__PACKAGE__ . ".$sub: Leaving the sub");
   return 1;
}

=head2 execCommitCliCmdConfirm()

DESCRIPTION:

    This subroutine executes the command and if commit requires the confirmation, gives the required input

=over 

=item ARGUMENTS:

    Cli Commands

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sgx_object->execCommitCliCmdConfirm(@commands)) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to execute the commands");
        return 0;
    }

=back 

=cut

sub execCommitCliCmdConfirm {
   my ($self, @cli_command ) = @_ ;
   my $sub_name = "execCommitCliCmdConfirm" ;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

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
         return 0;
      }

      $self->{CMDRESULTS} = ();
      
      # Issue commit and wait for either [ok], [error], or [yes,no]
      unless ( $self->{conn}->print( "commit" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'commit\'");
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
      }

      $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'commit\'");
      
      my ($prematch, $match);

      unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                             -match     => '/\[yes,no\]/',
                                                             -match     => '/\[yes\.no\]/',
                                                             -match     => '/\[ok\]/',
                                                             -match     => '/\[error\]/',
                                                             -match     => $self->{PROMPT},
                                                             -timeout   => $self->{DEFAULTTIMEOUT},
                                                           )) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'commit\'.");
         push( @{$self->{CMDRESULTS}}, $prematch );
         push( @{$self->{CMDRESULTS}}, $match );
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }

      push( @{$self->{CMDRESULTS}}, $prematch );
      push( @{$self->{CMDRESULTS}}, $match );
      if (( $match =~ m/\[yes,no\]/ ) or ( $match =~ m/\[yes\.no\]/ )){
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
         } elsif ( $prematch =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Command Executed with yes");
         } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
         }
      } elsif ( $match =~ m/\[ok\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  command commited.");
         # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );;
      } elsif ( $match =~ m/\[error\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  \'commit\' command error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );
         return 0;
      } else {
         $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub_name:  Committed command: $_");
      $self->{LASTCMD} = $_;

    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 execCommitCliCmdConfirmWithDelay()

DESCRIPTION:

    This subroutine executes the command and if commit requires the confirmation, gives the required input, and sleeps for the required amount of seconds as passed to it. This is basically written to slow down the fast execution of the mtp2 link inservice and outofService commands.

=over 

=item ARGUMENTS:

    Cli Commands

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sgx_object->execCommitCliCmdConfirmWithDelay(-cliCommands => \@cliCommand, -sleepTimer => 10)) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to execute the commands");
        return 0;
    }

=back 

=cut

sub execCommitCliCmdConfirmWithDelay {
   my ($self, %args) = @_;
   my $sub_name = "execCommitCliCmdConfirmWithDelay" ;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   my %a;
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my @cli_command = @{$a{-cliCommands}};
   my $sleepTimer = $a{-sleepTimer};

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
         return 0;
      }

      $self->{CMDRESULTS} = ();
      
      # Issue commit and wait for either [ok], [error], or [yes,no]
      unless ( $self->{conn}->print( "commit" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'commit\'");
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
      }

      $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'commit\'");
      
      my ($prematch, $match);

      unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                             -match     => '/\[yes,no\]/',
                                                             -match     => '/\[yes\.no\]/',
                                                             -match     => '/\[ok\]/',
                                                             -match     => '/\[error\]/',
                                                             -match     => $self->{PROMPT},
                                                             -timeout   => $self->{DEFAULTTIMEOUT},
                                                           )) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'commit\'.");
         push( @{$self->{CMDRESULTS}}, $prematch );
         push( @{$self->{CMDRESULTS}}, $match );
         $logger->debug(__PACKAGE__ . ".$sub_name:  Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }

      push( @{$self->{CMDRESULTS}}, $prematch );
      push( @{$self->{CMDRESULTS}}, $match );
      if (( $match =~ m/\[yes,no\]/ ) or ( $match =~ m/\[yes\.no\]/ )){
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
         } elsif ( $prematch =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Command Executed with yes");
         } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
         }
      } elsif ( $match =~ m/\[ok\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  command commited.");
         # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );;
      } elsif ( $match =~ m/\[error\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  \'commit\' command error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );
         return 0;
      } else {
         $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub_name:  Committed command: $_");
      $self->{LASTCMD} = $_;
      if ( $sleepTimer ) { 
         sleep $sleepTimer; 
      }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}



=head2 getLinkStat()

DESCRIPTION:

    This subroutine gets the statistics of the requested links

=over 

=item ARGUMENTS:

    -linkInfo   => Link information. Refer the example section for more information
    -cmdString  => CLI command to be executed

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    The statistics count

=item EXAMPLE:

   #Define a hash reference
   my $linkStatInfo = {};

   # Set the required information
   # $linkStatInfo->{"linkName"}->{"fieldName"} = undef;

   $linkStatInfo->{"gsxRoobarbCE0Active"}->{"regRequestReceived"} = undef;
   $linkStatInfo->{"gsxRoobarbCE0Active"}->{"regResponseTransmitted"} = undef;

   $linkStatInfo->{"gsxRoobarbCE0Standby"}->{"regRequestReceived"} = undef;
   $linkStatInfo->{"gsxRoobarbCE0Standby"}->{"regResponseTransmitted"} = undef;

   # Get the current statistics
   my %result = $sgxObject->getLinkStat(-cmdString => "show all details m3ua sgpLinkMeasurementCurrentStatistics",
                                        -linkInfo  => $linkStatInfo);
   The '%result' will be the same linkStatInfo hash with the 'undef' replaced with the corresponding statistics count

=back 

=cut

sub getLinkStat {
   my ($self, %args) = @_;
   my $sub = "getLinkStat()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->debug(__PACKAGE__ . ".$sub: command string : $a{-cmdString}");

   # Run the CLI
   unless ( $self->execCliCmd($a{-cmdString}) ) {
      $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$a{-cmdString}.--\n@{$self->{CMDRESULTS}}");
      return 0;
   }


   #Get the link information
   my %linkInfo = %{$args{-linkInfo}};

   $logger->debug(__PACKAGE__ . ".$sub: Received link information : " . Dumper(\%linkInfo));

   # Get the link names
   my @linkNames = keys(%linkInfo);

   my $resultLine;
   my $checkField = 0;
   my $link;
   my $fieldName;
   my $linkIndex;

   # Now we will take a result line and check for the retired patterns
   foreach $resultLine (@{$self->{CMDRESULTS}}) {

      # If a link name is already identified, check for the fields
      if($checkField eq 0) {
         foreach $link (@linkNames) {
            if($resultLine =~ m/$link/) {
               $logger->debug(__PACKAGE__ . ".$sub: Matching the link name => $resultLine");

               $resultLine =~ m/\S+\s+\S+\s+(\S+)/;
               my $tempLinkName = $1;
               if ($link eq $tempLinkName) {
                  $logger->debug(__PACKAGE__ . ".$sub: Got the link name : $resultLine => $link");

                  # Got the link name. Now we have to check for the fields
                  $checkField = 1;

                  # Save the link name
                  $linkIndex = $link;
               }
            }
         }
      } else {
         # Get the field names
         my @fieldKeys = keys(%{$linkInfo{$linkIndex}});

         # Check each field name is matching with the result line
         foreach $fieldName (@fieldKeys) {

            if($resultLine =~ m/$fieldName/) {
               $logger->debug(__PACKAGE__ . ".$sub: Got the field info : \'$resultLine\' ...... and link $linkIndex");

               # Get the statistics
               $resultLine =~ m/\S+\s+(\d+)/;

               # Store the statistics
               $linkInfo{$linkIndex}->{$fieldName} = $1;
            } elsif ($resultLine =~ m/}/) {
               # End of the link. Needs to check for the next link
               $checkField = 0;
            }
         }
      }
   }
   # return the updated link statistics information
   return %linkInfo;
}

=head2 getUpgradeLogsFromBothCEs()

DESCRIPTION:

    This subroutine gets upgrade logs upgrade.out and revert.out from /opt/sonus/staging/

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1
    -testCaseID     => Test Case Id
    -logDir         => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   my $ce0Alias = $TESTBED{ "sgx4000:1:ce0" };
   my $ce1Alias = $TESTBED{ "sgx4000:1:ce1" };

   my @fileNames = $sgx_object->getUpgradeLogsFromBothCEs( -sgxAliasCe0     => $ce0Alias,
                                                           -sgxAliasCe1     => $ce1Alias,
                                                           -testCaseID      => $testId,
                                                           -logDir          => "/home/ssukumaran/ats_user/logs",
                                                           -timeStamp       => $timestamp);

=item OUTPUT:

    0      - fail
    The log file names

=item EXAMPLE:

=back 

=cut

sub getUpgradeLogsFromBothCEs {
   my ($self, %args) = @_;
   my $sub = "getUpgradeLogsFromBothCEs()";
   my %a   = ( -variant   => "NONE",
               -timeStamp => "00000000-000000" );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    ##########################################
    # Step 1: Checking mandatory args;
    ##########################################
    unless ( $a{-sgxAliasCe0} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE0 is empty or blank.");
        return 0;
    }

    unless ( $a{-sgxAliasCe1} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE1 is empty or blank.");
        return 0;
    }

    unless ( $a{-testCaseID} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory test case ID is empty or blank.");
        return 0;
    }

    unless ( $a{-logDir} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
        return 0;
    }

    my @returnArray;

    #Get the log file names from each CE
    my @ce0FileNames = $self->getUpgradeLogs(-testCaseID    => $a{-testCaseID},
                                             -logDir        => $a{-logDir},
                                             -sgxAlias      => $a{-sgxAliasCe0},
                                             -variant       => $a{-variant},
                                             -timeStamp     => $a{-timeStamp});

    $logger->info(__PACKAGE__ . ".$sub: Got @ce0FileNames from CE0");

    my @ce1FileNames = $self->getUpgradeLogs(-testCaseID    => $a{-testCaseID},
                                             -logDir        => $a{-logDir},
                                             -sgxAlias      => $a{-sgxAliasCe1},
                                             -variant       => $a{-variant},
                                             -timeStamp     => $a{-timeStamp});

    $logger->info(__PACKAGE__ . ".$sub: Got @ce1FileNames from CE1");

   push(@returnArray, @ce0FileNames);
   push(@returnArray, @ce1FileNames);

   return @returnArray;
}

=head2 getUpgradeLogs()

DESCRIPTION:

    This subroutine gets upgrade logs upgrade.out and revert.out from /opt/sonus/staging/

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAlias    => SGX alias
    -testCaseID  => Test Case Id
    -logDir      => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    The log file names

=item EXAMPLE:

    my @ce1FileNames = $self->getUpgradeLogs(-testCaseID    => $a{-testCaseID},
                                             -logDir        => $a{-logDir},
                                             -sgxAlias      => $a{-sgxAliasCe1},
                                             -variant       => $a{-variant},
                                             -timeStamp     => $a{-timeStamp});

=back 

=cut

sub getUpgradeLogs {
   my ($self, %args) = @_;
   my $sub = "getUpgradeLogs()";
   my %a   = ( -variant   => "NONE", 
               -timeStamp => "00000000-000000" );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    ##########################################
    # Step 1: Checking mandatory args;
    ##########################################
    unless ( $a{-testCaseID} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory -testCaseID is empty or blank.");
        return 0;
    }
    unless ( $a{-logDir} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
        return 0;
    }
    unless ( $a{-sgxAlias} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX alias name is empty or blank.");
        return 0;
    }

    # TMS Data
    my $hashInfo = $main::TESTBED{$a{-sgxAlias}};
    $hashInfo = "$hashInfo" . ":hash";

    my $root_password = $main::TESTBED{$hashInfo}->{LOGIN}->{1}->{ROOTPASSWD};
    my $sftpadmin_ip  = $main::TESTBED{$hashInfo}->{MGMTNIF}->{1}->{IP};

    unless ($sftpadmin_ip) {
       $logger->warn(__PACKAGE__ . ".$sub MGMT IP Address MUST BE DEFINED");
       return 0;
    }
    unless ($root_password) {
       $logger->warn(__PACKAGE__ . ".$sub SFTP Password MUST BE DEFINED");
       return 0;
    }
    ####################################################
    # Step 2: Create SFTP session;
    ####################################################
    my $timeout = 300;

    # Open a session for SFTP
    if (!defined ($self->{sftp_session_for_ce}->{$a{-sgxAlias}})) {
        $logger->debug(__PACKAGE__ . ".$sub starting new SFTP sesssion");

        $self->{sftp_session_for_ce}->{$a{-sgxAlias}} = new SonusQA::Base( -obj_host       => $sftpadmin_ip,
                                                                    -obj_user       => "root",
                                                                    -obj_password   => $root_password,
                                                                    -comm_type      => 'SFTP',
                                                                    -obj_port       => 2024,
                                                                    -sessionLog     => 1,
                                                                    -return_on_fail => 1,
                                                                  );

        unless ( $self->{sftp_session_for_ce}->{$a{-sgxAlias}} ) {
            $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
            $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required SGX \($sftpadmin_ip\)");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    my $sftp_session = $self->{sftp_session_for_ce}->{$a{-sgxAlias}};

    ##########################################
    # Step 3: Get the current log file name and SFTP
    ##########################################
    my $file_name;
    my $from_Dir = "/opt/sonus/staging/";
    my $to_Dir = $a{-logDir};
    my $file_transfer_status;

    my @returnArr;
    my @fileList;

    $file_name = "upgrade.out" . " $a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$a{-sgxAlias}-" . "upgrade.out" ;
    push @fileList, ($file_name);

    $file_name = "revert.out" . " $a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$a{-sgxAlias}-" . "revert.out" ;
    push @fileList, ($file_name);

    # Loop and Copy each File
    foreach $file_name (@fileList) {
       # Transfer File
       $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP (
                                                                             $sftp_session,
                                                                             $to_Dir,       # TO Remote directory
                                                                             $from_Dir,     # FROM remote directory
                                                                             $file_name,    # file to transfer
                                                                             $timeout,      # Maximum file transfer time
                                                                             );

       # Check status
       if ( $file_transfer_status == 1 ) {
          $logger->info(__PACKAGE__ . ".$sub $file_name transfer success");

          # Return the local file names
          my @tempArr = split(/ /, $file_name);
          push (@returnArr, $tempArr[1]);
       } else {
          $logger->error(__PACKAGE__ . ".$sub failed to get file");
       }
    }

    # Return file list
    return @returnArr;
}

=head2 getSarLogsFromBothCEs()

DESCRIPTION:

    This subroutine gets SAR logs from /home/Administrator/SARLOGS directory
    Also this subroutine executes ./get.sar_new before taking the logs

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1
    -testCaseID     => Test Case Id
    -logDir         => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"
    -loadType   => CPS which can be used as part of tar file name.It can be call rate like 10K or message length like
                   20BYTES.

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    The log file names

=item EXAMPLE:

   my $ce0Alias = $TESTBED{ "sgx4000:1:ce0" };
   my $ce1Alias = $TESTBED{ "sgx4000:1:ce1" };

   my @fileNames = $sgx_object->getSarLogsFromBothCEs( -sgxAliasCe0     => $ce0Alias,
                                                       -sgxAliasCe1     => $ce1Alias,
                                                       -testCaseID      => $testId,
                                                       -logDir          => "/home/ssukumaran/ats_user/logs",
                                                       -timeStamp       => $timestamp);

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! NOTES !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !!  This subroutine expects $self->{sar_start_time}->{$tmsAlias} and             !!
   !!  $self->{sar_end_time}->{$tmsAlias} are filled before calling this subroutine.!!
   !!  Use getTimeForSarLogsFromBothCEs with START and END to fill these values.    !!
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! END   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

=back 

=cut

sub getSarLogsFromBothCEs {
   my ($self, %args) = @_;
   my $sub = "getSarLogsFromBothCEs()";
   my %a   = ( -variant   => "NONE",
               -timeStamp => "00000000-000000",
               -loadType  => '0' );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    ##########################################
    # Checking mandatory args;
    ##########################################
    unless ( defined $a{-sgxAliasCe0} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE0 is empty or blank.");
        return 0;
    }

    unless ( defined $a{-sgxAliasCe1} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE1 is empty or blank.");
        return 0;
    }

    unless ( defined $a{-testCaseID} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory test case ID is empty or blank.");
        return 0;
    }

    unless ( defined $a{-logDir} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
        return 0;
    }

    my @returnArray;

    #Get the log file names from each CE
    my $ce0FileName = $self->getSarLogs(-testCaseID    => $a{-testCaseID},
                                         -logDir        => $a{-logDir},
                                         -sgxAlias      => $a{-sgxAliasCe0},
                                         -variant       => $a{-variant},
                                         -timeStamp     => $a{-timeStamp},
                                         -loadType      => $a{-loadType});

    $logger->info(__PACKAGE__ . ".$sub: Got $ce0FileName from CE0");

    unless ($ce0FileName) {
        $logger->error(__PACKAGE__ . ".$sub: unable to get SAR file name from CE0");
        return 0;
    }

    my $ce1FileName = $self->getSarLogs(-testCaseID    => $a{-testCaseID},
                                         -logDir        => $a{-logDir},
                                         -sgxAlias      => $a{-sgxAliasCe1},
                                         -variant       => $a{-variant},
                                         -timeStamp     => $a{-timeStamp},
                                         -loadType      => $a{-loadType});

    $logger->info(__PACKAGE__ . ".$sub: Got $ce1FileName from CE1");

   unless ($ce1FileName) {
        $logger->error(__PACKAGE__ . ".$sub: unable to get SAR file name from CE1");
        return 0;
    }

   push(@returnArray, $ce0FileName);
   push(@returnArray, $ce1FileName);

   return @returnArray;
}

=head2 getSarLogs()

DESCRIPTION:

    This subroutine gets SAR logs from /home/Administrator/SARLOGS directory
    Also this subroutine executes ./get.sar_new before taking the logs

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAlias    => SGX alias
    -testCaseID  => Test Case Id
    -logDir      => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"
    -loadType   => CPS which can be used as part of tar file name.It can be call rate like 10K or message length like
                   20BYTES.
=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    The log file names

=item EXAMPLE:

    my @ce1FileNames = $self->getSarLogs(-testCaseID    => $a{-testCaseID},
                                         -logDir        => $a{-logDir},
                                         -sgxAlias      => $a{-sgxAliasCe1},
                                         -variant       => $a{-variant},
                                         -timeStamp     => $a{-timeStamp});

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! NOTES !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !!  This subroutine expects $self->{sar_start_time}->{$tmsAlias} and             !!
   !!  $self->{sar_end_time}->{$tmsAlias} are filled before calling this subroutine.!!
   !!  Use getTimeForSarLogsFromBothCEs with START and END to fill these values.    !!
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! END   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

=back 

=cut

sub getSarLogs {
   my ($self, %args) = @_;
   my $sub = "getSarLogs()";
   my %a   = ( -variant   => "NONE",
               -timeStamp => "00000000-000000",
               -loadType  => '0' );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-testCaseID} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory -testCaseID is empty or blank.");
       return 0;
   }
   unless ( defined $a{-logDir} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
       return 0;
   }
   unless ( defined $a{-sgxAlias} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX alias name is empty or blank.");
       return 0;
   }

   # TMS Data
   my $hashInfo = $main::TESTBED{$a{-sgxAlias}};
   $hashInfo = "$hashInfo" . ":hash";

   my $root_password = $main::TESTBED{$hashInfo}->{LOGIN}->{1}->{ROOTPASSWD};
   my $sftpadmin_ip  = $main::TESTBED{$hashInfo}->{MGMTNIF}->{1}->{IP};

   unless ($sftpadmin_ip) {
      $logger->warn(__PACKAGE__ . ".$sub MGMT IP Address MUST BE DEFINED");
      return 0;
   }
   unless ($root_password) {
      $logger->warn(__PACKAGE__ . ".$sub SFTP Password MUST BE DEFINED");
      return 0;
   }

   my $tmsAlias = $a{-sgxAlias};
   ####################################################
   # Create SSH session;
   ####################################################
   my $shellSession;

   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias (
                                       -tms_alias    => $tmsAlias,
                                       -obj_port     => 2024,
                                       -obj_user     => "root",
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub Error in logging in linux shell as root");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }

   $shellSession = $self->{shell_session}->{$tmsAlias};

   $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");

   my $toolsDir = "/home/Administrator/TOOLS";
   my $from_Dir = "/home/Administrator/SARLOGS";

   if ($shellSession->execShellCmd("test -d $toolsDir")) {
       $logger->debug(__PACKAGE__ . ".$sub: TOOLS directory already exists");
   } else {
       $logger->debug(__PACKAGE__ . ".$sub: TOOLS directory does not exist");
       $logger->debug(__PACKAGE__ . ".$sub: Creating TOOLS directory");
       unless ($shellSession->execShellCmd("mkdir $toolsDir")) {
           $logger->error(__PACKAGE__ . ".$sub: Failed to create TOOLS directory");
           return 0;
       }
   }

   if ($shellSession->execShellCmd("test -d $from_Dir")) {
       $logger->debug(__PACKAGE__ . ".$sub: SARLOGS directory already exists");
       $logger->debug(__PACKAGE__ . ".$sub: Clearing SARLOGS directory");
       unless ($shellSession->execShellCmd("rm -rf $from_Dir/*")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to clear SARLOGS directory");
            return 0;
       }
   } else {
       $logger->debug(__PACKAGE__ . ".$sub: SARLOGS directory does not exists");
       $logger->debug(__PACKAGE__ . ".$sub: Creating SARLOGS directory");
       unless ($shellSession->execShellCmd("mkdir $from_Dir")) {
           $logger->error(__PACKAGE__ . ".$sub: Failed to create SARLOGS directory");
           return 0;
       }
   }

   ####################################################
   # Create SFTP session;
   ####################################################
   my $timeout = 300;

   # Open a session for SFTP
   if (!defined ($self->{sftp_session_for_ce}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub starting new SFTP sesssion");

      $self->{sftp_session_for_ce}->{$tmsAlias} = new SonusQA::Base( -obj_host       => $sftpadmin_ip,
                                                                    -obj_user       => "root",
                                                                    -obj_password   => $root_password,
                                                                    -comm_type      => 'SFTP',
                                                                    -obj_port       => 2024,
                                                                    -return_on_fail => 1,
                                                                    -sessionLog     => 1
                                                                  );

      unless ( $self->{sftp_session_for_ce}->{$tmsAlias} ) {
         $logger->error(__PACKAGE__ . ".$sub Could not open connection to SGX");
         $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required SGX \($sftpadmin_ip\)");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
      }
   }

   my $sftp_session = $self->{sftp_session_for_ce}->{$tmsAlias};

   #copy 'get.sar_ats' file from version controled path to TOOLS directory
   my $userHomeDir = qx#echo \$HOME#;
   chomp($userHomeDir);
   my $sarScriptPath = "${userHomeDir}/" . "ats_repos/lib/perl/SonusQA/SGX4000/";

   my $sarScriptName = 'get.sar_ats';
   my $fileTransferStatus = SonusQA::SGX4000::SGX4000HELPER::putFileToRemoteDirectoryViaSFTP ($sftp_session, $sarScriptPath, $toolsDir, $sarScriptName, $timeout);

   if ($fileTransferStatus == 1) {
       $logger->debug(__PACKAGE__ . ".$sub: Successfully copied \'get.sar_ats\' to $toolsDir");
   } else {
       $logger->error(__PACKAGE__ . ".$sub: Failed to copy \'get.sar_ats\' to $toolsDir");
       return 0;
   }

   # Change the dir
   my $cmdString = "cd $toolsDir";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   # Update the sartimes
   unless (defined($self->{sar_start_time}->{$tmsAlias}) or defined($self->{sar_end_time}->{$tmsAlias})) {
      $logger->warn(__PACKAGE__ . ".$sub start and end times are not available");
      return 0;
   }

   my $startAndEndTime = "$self->{sar_start_time}->{$tmsAlias} $self->{sar_end_time}->{$tmsAlias}";

   my $sartimeFile = "/home/Administrator/TOOLS/sartimes";

   $logger->debug(__PACKAGE__ . ".$sub: Sar log startTime --> $self->{sar_start_time}->{$tmsAlias} and endTime --> $self->{sar_end_time}->{$tmsAlias}");

   $cmdString = "echo \"$startAndEndTime\" > $sartimeFile";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   # Create new Sar logs
   $cmdString = "./get.sar_ats";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");
   $logger->debug(__PACKAGE__ . ".$sub: SATRT TIME --> $self->{sar_start_time}->{$tmsAlias} and END TIME --> $self->{sar_end_time}->{$tmsAlias}");
   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString' got following error mesages");
      foreach (@{$shellSession->{CMDRESULTS}}) {
          $logger->error(__PACKAGE__ . ".$sub: $_");
      }
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   #Get the sar logs
   $cmdString = "cd $from_Dir";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Into the SAR log Location......");

   $cmdString = "\\ls -l *.sar";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   unless ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub: ls -l *.sar out put");

   foreach (@{$shellSession->{CMDRESULTS}}) {
       $logger->debug(__PACKAGE__ . ".$sub: $_");
   }
   my @sarLogs;
   my $skipLines = 1;
   my $line;

   foreach $line (@{$shellSession->{CMDRESULTS}}) {
      chomp $line;
      if($skipLines eq 1) {
         $skipLines = 0;
         next;
      }

      if($line =~ m/.*\s+(\w+\.sar)$/) {
         push (@sarLogs, $1);
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub got the file names" . Dumper(\@sarLogs));

   #Check the size of *.sar files
   foreach my $sarFileName (@sarLogs) {
       my @cmdResult = $shellSession->execCmd("stat -c %s $sarFileName");
       unless ($cmdResult[0] > 0) {
           $logger->error(__PACKAGE__ . ".$sub: Size of the file \'$sarFileName\' is $cmdResult[0]");
           return 0;
       }
   }

   ##########################################
   # Get the current log file name and SFTP
   ##########################################

   #Copy the TOP command file to SARLOGS directory
   $cmdString = "mv /home/Administrator/ats_top*.log $from_Dir";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   } else {
      $logger->debug(__PACKAGE__ . ".$sub : Copying TOP command file is successful");
   }

   my $tarFileName = "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "SGX-" . "$tmsAlias-" . "$a{-loadType}-" . "SAR" . "\.tar";
   my $to_Dir = $a{-logDir};
   my $file_transfer_status;

   # Change the dir
   $cmdString = "cd $from_Dir";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   if ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   my $tarCommand = "tar -cvf $tarFileName *";

   $logger->debug(__PACKAGE__ . ".$sub : executing $tarCommand command");

   $shellSession->{CMDRESULTS} = undef;
   unless ($shellSession->execCmd("$tarCommand")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$tarCommand'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   unless ($shellSession->execShellCmd("test -f $tarFileName")) {
       $logger->debug(__PACKAGE__ . ".$sub: Unable to tar the files present SARLOGS directory");
       return 0;
   }

   $file_transfer_status = SonusQA::SGX4000::SGX4000HELPER::getFileToLocalDirectoryViaSFTP ($sftp_session, $to_Dir, $from_Dir, $tarFileName, $timeout);

   if ( $file_transfer_status == 1 ) {
       $logger->info(__PACKAGE__ . ".$sub : \'$tarFileName\' file transfer success");
       $logger->debug(__PACKAGE__ . ".$sub: Clearing SARLOGS directory");
       unless ($shellSession->execShellCmd("rm -rf $from_Dir/*")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to clear SARLOGS directory");
            return 0;
       }
   } else {
       $logger->error(__PACKAGE__ . ".$sub : \'$tarFileName\' file transfer failed");
       return 0;
   }

   # Return file list
   return $tarFileName;
}

=head2 getTimeForSarLogsFromBothCEs()

DESCRIPTION:

    This subroutine gets SGX time in the way sartimes required

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1

   Optional:
    -timeInfo       => Start or End Time. Valid values are "START" and "END"
                       Default => "START"
    -timeInterval => Next time interval to which we need to do roundoff
                     e.g. If '-timeInterval' is 10 and the actual time is XX:00 thru 09 (hrs:mins) then the start time
                     will be XX:10. Similarly times will be rounded up to XX:20, XX:30, XX:40, XX:50 & XX:00 as required.
                     In the latter case this time would be used if the actual time was (XX-1):50 thru 59.

                     Default => '10'

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

   my $ce0Alias = $TESTBED{ "sgx4000:1:ce0" };
   my $ce1Alias = $TESTBED{ "sgx4000:1:ce1" };

   $sgx_object->getTimeForSarLogsFromBothCEs( -sgxAliasCe0     => $ce0Alias,
                                              -sgxAliasCe1     => $ce1Alias,
                                              -timeInfo        => "START");

=back 

=cut

sub getTimeForSarLogsFromBothCEs {
   my ($self, %args) = @_;
   my $sub = "getTimeForSarLogsFromBothCEs()";
   my %a   = ( -timeInfo     => "START",
               -timeInterval => '10');

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    ##########################################
    # Checking mandatory args;
    ##########################################
    unless ( defined $a{-sgxAliasCe0} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE0 is empty or blank.");
        return 0;
    }

    unless ( defined $a{-sgxAliasCe1} ) {
        $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE1 is empty or blank.");
        return 0;
    }

    unless ( ($a{-timeInfo} eq "START") or ($a{-timeInfo} eq "END")) {
        $logger->warn(__PACKAGE__ . ".$sub: The valid values for -timeInfo is START and END");
        return 0;
    }

    #Get the time from each CE
    $self->getTimeForSarLogs(-sgxAlias      => $a{-sgxAliasCe0},
                             -timeInfo      => $a{-timeInfo},
                             -timeInterval  => $a{-timeInterval});

    $self->getTimeForSarLogs(-sgxAlias      => $a{-sgxAliasCe1},
                             -timeInfo      => $a{-timeInfo},
                             -timeInterval  => $a{-timeInterval});

   return 1;
}

=head2 getTimeForSarLogs()

DESCRIPTION:

    This subroutine gets SGX time in the way sartimes required

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAlias    => SGX alias

   Optional:
    -timeInfo       => Start or End Time. Valid values are "START" and "END"
                       Default => "START"
    -timeInterval => Next time interval to which we need to do roundoff
                     e.g. If '-timeInterval' is 10 and the actual time is XX:00 thru 09 (hrs:mins) then the start time
                     will be XX:10. Similarly times will be rounded up to XX:20, XX:30, XX:40, XX:50 & XX:00 as required.
                     In the latter case this time would be used if the actual time was (XX-1):50 thru 59.

                     Default => "10"

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $self->getTimeForSarLogs( -sgxAlias      => $a{-sgxAliasCe1},
                              -timeInfo      => "START");

=back 

=cut

sub getTimeForSarLogs {
   my ($self, %args) = @_;
   my $sub = "getTimeForSarLogs()";
   my %a   = (-timeInfo     => "START",
              -timeInterval => '10');

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-sgxAlias} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX alias name is empty or blank.");
       return 0;
   }

   unless ( ($a{-timeInfo} eq "START") or ($a{-timeInfo} eq "END")) {
      $logger->warn(__PACKAGE__ . ".$sub: The valid values for -timeInfo is START and END");
      return 0;
   }

   my $tmsAlias = $a{-sgxAlias};
   ####################################################
   # Create SSH session;
   ####################################################
   my $shellSession;

   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias (
                                       -tms_alias    => $tmsAlias,
                                       -obj_port     => 2024,
                                       -obj_user     => "root",
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub Error in logging in linux shell as root");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }

   $shellSession = $self->{shell_session}->{$tmsAlias};

   $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");

   my $cmdString = "date +\'%T %F\'";
   $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

   $shellSession->{CMDRESULTS} = undef;
   unless ($shellSession->execCmd("$cmdString")) {
      $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   my $line;
   foreach $line (@{$shellSession->{CMDRESULTS}}) {
      chomp $line;
      $logger->debug(__PACKAGE__ . ".$sub: Command Output --> $line");
      if(($a{-timeInfo} eq "START")) {
         $line = $self->roundOffTimeAndDate( -string => "$line", -timeInterval => $a{-timeInterval});
         unless ($line) {
             $logger->error(__PACKAGE__ . ".$sub : Failed to roundoff the given time");
             return 0;
         }
         $self->{sar_start_time}->{$tmsAlias} = $line;
      } else {
         $self->{sar_end_time}->{$tmsAlias} = $line;
      }
   }

   return 1;
}

=head2 handleTopCommandForBothCEs()

DESCRIPTION:

    This subroutine starts and stops top command for a process

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1

   Optional:
    -cmdInfo        => Start or End of top command. Valid values are "START" and "STOP"
                       The STOP option stops all the top commands currently running
                       Default => "START"
    -processInfo    => The process name for which the top command to be started
                       NOT valid for the STOP option.
                       Default => "CE_2N_Comp_SigGatewayProcess"
    -delay         => Delay between screen updates (i.e. time interval for -d option)
                       Default => "60".

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

   my $ce0Alias = $TESTBED{ "sgx4000:1:ce0" };
   my $ce1Alias = $TESTBED{ "sgx4000:1:ce1" };

   $sgx_object->handleTopCommandForBothCEs( -sgxAliasCe0     => $ce0Alias,
                                            -sgxAliasCe1     => $ce1Alias,
                                            -cmdInfo         => "START",
                                            -processInfo     => "CE_2N_Comp_SigGatewayProcess");

=back 

=cut

sub handleTopCommandForBothCEs {
   my ($self, %args) = @_;
   my $sub = "handleTopCommandForBothCEs()";
   my %a   = ( -cmdInfo        => "START",
               -processInfo    => "CE_2N_Comp_SigGatewayProcess",
               -delay          => "60",);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-sgxAliasCe0} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE0 is empty or blank.");
      return 0;
   }

   unless ( defined $a{-sgxAliasCe1} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE1 is empty or blank.");
      return 0;
   }

   unless ( ($a{-cmdInfo} eq "START") or ($a{-cmdInfo} eq "STOP")) {
      $logger->warn(__PACKAGE__ . ".$sub: The valid values for -cmdInfo is START and STOP");
      return 0;
   }

   #Get the time from each CE
   unless ($self->handleTopCommand(-sgxAlias      => $a{-sgxAliasCe0},
                                   -cmdInfo       => $a{-cmdInfo},
                                   -processInfo   => $a{-processInfo},
                                   -delay         => $a{-delay})
   ){
       $logger->error(__PACKAGE__ . ".$sub: Failed to execute TOP command on CE0");
       return 0;
   }

   unless ($self->handleTopCommand(-sgxAlias      => $a{-sgxAliasCe1},
                                   -cmdInfo       => $a{-cmdInfo},
                                   -processInfo   => $a{-processInfo},
                                   -delay         => $a{-delay})
   ){
       $logger->error(__PACKAGE__ . ".$sub: Failed to execute TOP command on CE1");
       return 0;
   }

   return 1;
}

=head2 handleTopCommand()

DESCRIPTION:

    This subroutine starts and stops top command for a process

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAlias    => SGX alias

   Optional:
    -cmdInfo        => Start or End Time. Valid values are "START" and "STOP"
                       The STOP option stops all the top commands currently running
                       Default => "START"
    -processInfo    => The process name for which the top command to be started
                       NOT valid for the STOP option.
                       Default => "CE_2N_Comp_SigGatewayProcess"
    -delay          => Delay between screen updates (i.e. time interval for -d option)
                       Default => "60".

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $self->handleTopCommand( -sgxAlias      => $a{-sgxAliasCe1},
                             -cmdInfo      => "START",
                             -processInfo  => "CE_2N_Comp_SigGatewayProcess",
                             -delay        => "90");

=back 

=cut

sub handleTopCommand {
   my ($self, %args) = @_;
   my $sub = "handleTopCommand()";
   my %a   = (-cmdInfo        => "START",
              -processInfo    => "CE_2N_Comp_SigGatewayProcess",
              -delay          => "60");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-sgxAlias} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX alias name is empty or blank.");
       return 0;
   }

   unless ( ($a{-cmdInfo} eq "START") or ($a{-cmdInfo} eq "STOP")) {
      $logger->warn(__PACKAGE__ . ".$sub: The valid values for -cmdInfo is START and STOP");
      return 0;
   }

   my $tmsAlias = $a{-sgxAlias};
   ####################################################
   # Create SSH session;
   ####################################################
   my $shellSession;

   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias (
                                       -tms_alias    => $tmsAlias,
                                       -obj_port     => 2024,
                                       -obj_user     => "root",
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub Error in logging in linux shell as root");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }

   $shellSession = $self->{shell_session}->{$tmsAlias};

   $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");

   my $cmdString;
   my $line;
   my $logFIleName = "/home/Administrator/ats_top_$a{-processInfo}.log";
   if ($a{-cmdInfo} eq "START") {

      # Check whether this is a valid process name
      $cmdString = "ps -aef |grep $a{-processInfo} |grep -v grep";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

      $shellSession->{CMDRESULTS} = undef;
      unless ($shellSession->execCmd("$cmdString")) {
         $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }

      my $foundProcess = 0;
      foreach $line (@{$shellSession->{CMDRESULTS}}) {
         chomp $line;
         if ($line =~ m/$a{-processInfo}/) {
            $foundProcess = 1;
            last;
         }
      }

      if($foundProcess eq 0) {
         $logger->error(__PACKAGE__ . ".$sub the $a{-processInfo} is not running now!!");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }

      # If log file is present, delete it
      $cmdString = "\\rm $logFIleName";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

      $shellSession->execCmd("$cmdString");
      $logger->debug(__PACKAGE__ . ".$sub @{$shellSession->{CMDRESULTS}}");

      # Start the top command
      $cmdString = "top -d $a{-delay} -Hb | grep $a{-processInfo} | grep -v \"S  0.0 \" >> $logFIleName &";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

      $shellSession->{CMDRESULTS} = undef;
      $shellSession->execCmd("$cmdString");
      $logger->debug(__PACKAGE__ . ".$sub @{$shellSession->{CMDRESULTS}}");
   } else {
      # Get the top process ids
      $cmdString = "ps -aef |grep top| grep -v grep";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

      $shellSession->{CMDRESULTS} = undef;
      unless ($shellSession->execCmd("$cmdString")) {
         $logger->error(__PACKAGE__ . ".$sub Failed execute the command '$cmdString'\n@{$shellSession->{CMDRESULTS}}");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }

      foreach $line (@{$shellSession->{CMDRESULTS}}) {
         chomp $line;
         if ($line =~ m/\S+\s+(\d+).*/) {
            # Kill the process
            $cmdString = "kill -9 $1";
            $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

            $shellSession->{CMDRESULTS} = undef;
            $shellSession->execCmd("$cmdString");
            $logger->debug(__PACKAGE__ . ".$sub @{$shellSession->{CMDRESULTS}}");
         }
      }
   }

   return 1;
}

=head2 verifyCpuUsageForBothCEs()

DESCRIPTION:

    This subroutine verify SGX CPU usage

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAliasCe0    => SGX alias for CE0
    -sgxAliasCe1    => SGX alias for CE1

   Optional:
    -cpuUsage       => The expected Maximum CPU usage in %
                       The default value is set as 80%
    -noOfTimes      => Number of times the sub needs to check the CPU usage
                       The default value is 5
    -interval       => Time to wait between attempts
                       The default value is 60secs

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

\=item EXAMPLE:

   my $ce0Alias = $TESTBED{ "sgx4000:1:ce0" };
   my $ce1Alias = $TESTBED{ "sgx4000:1:ce1" };

   $sgx_object->verifyCpuUsageForBothCEs( -sgxAliasCe0     => $ce0Alias,
                                          -sgxAliasCe1     => $ce1Alias);

=back 

=cut

sub verifyCpuUsageForBothCEs {
   my ($self, %args) = @_;
   my $sub = "verifyCpuUsageForBothCEs()";
   my %a   = ( -cpuUsage      => 80,
               -noOfTimes     => 5,
               -interval      => 60 );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-sgxAliasCe0} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE0 is empty or blank.");
      return 0;
   }

   unless ( defined $a{-sgxAliasCe1} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX Alias name for CE1 is empty or blank.");
      return 0;
   }

   #Get the time from each CE
  unless( $self->verifyCpuUsage(-sgxAlias      => $a{-sgxAliasCe0},
                         -cpuUsage      => $a{-cpuUsage},
                         -noOfTimes     => $a{-noOfTimes},
                         -interval      => $a{-interval},
                        )) {
       $logger->debug(__PACKAGE__ . ".$sub : CPU Usage is more than the prescribed Limit or Error for \' $a{-sgxAliasCe0}\' ");
       $logger->debug(__PACKAGE__ . ".$sub : Leaving Sub [0] ");
       return 0;
  }

  unless( $self->verifyCpuUsage(-sgxAlias      => $a{-sgxAliasCe1},
                         -cpuUsage      => $a{-cpuUsage},
                         -noOfTimes     => $a{-noOfTimes},
                         -interval      => $a{-interval},
                        )) {
       $logger->debug(__PACKAGE__ . ".$sub : CPU Usage is more than the prescribed Limit or Error for \' $a{-sgxAliasCe1}\' ");
       $logger->debug(__PACKAGE__ . ".$sub : Leaving Sub [0] ");
       return 0;
  }

   return 1;
}

=head2 verifyCpuUsage()

DESCRIPTION:

    This subroutine starts and stops top command for a process

=over 

=item ARGUMENTS:

   Mandatory:
    -sgxAlias    => SGX alias

   Optional:
    -cpuUsage       => The expected Maximum CPU usage in %
                       The default value is set as 80%
    -noOfTimes      => Number of times the sub needs to check the CPU usage
                       The default value is 5
    -interval       => Time to wait between attempts
                       The default value is 60secs

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

   $self->verifyCpuUsage(-sgxAlias      => $a{-sgxAliasCe1},

=back

=cut

sub verifyCpuUsage {
   my ($self, %args) = @_;
   my $sub = "verifyCpuUsage()";
   my %a   = ( -cpuUsage      => 80,
               -noOfTimes     => 5,
               -interval      => 60 );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   ##########################################
   # Checking mandatory args;
   ##########################################
   unless ( defined $a{-sgxAlias} ) {
       $logger->warn(__PACKAGE__ . ".$sub: Mandatory SGX alias name is empty or blank.");
       return 0;
   }

   my $tmsAlias = $a{-sgxAlias};
   ####################################################
   # Create SSH session;
   ####################################################
   my $shellSession;

   if (!defined ($self->{shell_session}->{$tmsAlias})) {
      $logger->debug(__PACKAGE__ . ".$sub : Opening a new connection to $tmsAlias");

      unless ( $self->{shell_session}->{$tmsAlias}=SonusQA::ATSHELPER::newFromAlias (
                                       -tms_alias    => $tmsAlias,
                                       -obj_port     => 2024,
                                       -obj_user     => "root",
                                       -sessionlog   => 1 )) {
         $logger->error(__PACKAGE__ . ".$sub Error in logging in linux shell as root");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      };
   }

   $shellSession = $self->{shell_session}->{$tmsAlias};

   $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $tmsAlias");

   my $retCode = 1;
   my $noOfTimes = 0;
   while ($noOfTimes < $a{-noOfTimes}) {
      my $cmdString;
      $retCode = 1;

      # Start the top command
      $cmdString = "top -Hb -n 1 | head -n 20";
      $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

      $shellSession->{CMDRESULTS} = undef;
      $shellSession->execCmd("$cmdString");

      my $line;
      my $skipLines = 1;

      my $cpuUsage = 0;
      foreach $line (@{$shellSession->{CMDRESULTS}}) {
         if($skipLines eq 1) {
            if($line =~ m/^\s+PID.*/) {
               $skipLines = 0;
            }
            next;
         }

         if(($line =~ m/^\s+\d+\s+\S+\s+\d+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\d+).\d+.*/) or
            ($line =~ m/^\d+\s+\S+\s+\d+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\d+).\d+.*/)) {
            $cpuUsage = $1;

            if ($cpuUsage > $a{-cpuUsage}) {
               $logger->debug(__PACKAGE__ . ".$sub : The current CPU usage is $cpuUsage, which is greater than $a{-cpuUsage}");
               $logger->debug(__PACKAGE__ . ".$sub : $line");
               $retCode = 0;
            } else {
               $logger->debug(__PACKAGE__ . ".$sub : The current CPU usage is $cpuUsage, which is lesser than $a{-cpuUsage}");
            }
         } else {
             $logger->error(__PACKAGE__ . ".$sub : unable to parse the line");
             $logger->error(__PACKAGE__ . ".$sub : $line");
             $retCode = 0;
         }
         last;
      }

      if ($retCode eq 1) {
         last;
      }
      sleep $a{-interval};
      $noOfTimes++;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Leaving the sub with $retCode");
   return $retCode;
}

=head2 getSgxTableStat()

DESCRIPTION:

   This subroutine returns status of the required table in a hash table

=over 

=item ARGUMENTS:

   Mandatory:
      -tableInfo    => Table information
                       - "SS7_DEST"              executes "show all details ss7 destinationStatus"
                       - "SS7_MTP2"              executes "show all details ss7 mtp2SignalingLinkStatus"
                       - "M3UA_SGP"              executes "show all details m3ua sgpLinkStatus"
                       - "SUA_SGP"               executes "show all details sua sgpLinkStatus"
                       - "SS7_MTP2_LINK"         executes "show all details ss7 mtp2LinkStatus"
		       - "SS7_MTP2_LINK_CONG"    executes "show all details ss7 mtp2LinkCongestionProfile"
                       - "SS7_ROUTE_STAT"        executes "show all details ss7 routeStatus"
                       - "M3UA_ASP"              executes "show all details m3ua aspLinkStatus";
                       - "SIGTR_SCTP_STAT"       executes "show all details sigtran sctpAssociationStatus"
                       - "M2PA_LINK_STAT"        executes "show all details m2pa m2paLinkStatus"
                       - "SS7_MTP2_LINKSET_STAT" executes "show all details ss7 mtp2SignalingLinkSetStatus"
                       - "SIGTR_SCTP"            executes "show all details sigtran sctpAssociation"
                       - "M3UA_ASP_LINK"         executes "show all details m3ua aspLink";
                       - "M3UA_ASP_LINK_SET"     executes "show all details m3ua aspLinkSet";
                       - "SS7_ROUTE"             executes "show all details ss7 route"
                       - "SS7_DEST_TAB"          executes "show all details ss7 destination"
                       - "M2PA_LINK"             executes "show all details m2pa link"
                       - "SS7_MTP2_SIG"          executes "show all details ss7 mtp2SignalingLink"
                       - "SS7_MTP2_LINKSET"      executes "show all details ss7 mtp2SignalingLinkSet"
                       - "SS7_MTP2_SIG_STAT"     executes "show all details ss7 mtp2SignalingLinkStatus"
                       - "M3UA_SGP_LINK"         executes "show all details m3ua sgpLink"
                       - "SUA_SGP_LINK"          executes "show all details sua sgpLink"
                       - "SS7_MTP2_LINK_TAB"     executes "show all details ss7 mtp2Link"
                       - "M3UA_SGP_REG"          executes "show all details m3ua sgpRegistrationsStatus"
                       - "SS7_SCCP_REM"          executes "show all ss7 sccpRemoteSubSystem"
                       - "SS7_SCCP_REM_STAT"     executes "show all ss7 sccpRemoteSubSystemStatus"
                       - "SS7_SCCP_CON_DEST"     executes "show all ss7 sccpConcernedDestination"
                       - "SUA_SGP_REG_STAT"      executes "show all sua sgpRegistrationsStatus"
                       - "M3UA_INTERSGX_LINK_STAT"  executes "show all m3ua interSgxLinkStatus"

      -statusInfo   => Hash reference

   Optional:

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    On success a hash reference with link names and status is returned
    0      - fail

=item OUTPUT FORMAT :-

    Most of the tables output will be return as hash having "linkname"->"fieldname" format

    Below tables output returned in specific format.
   	SS7_SCCP_REM_STAT -> "linkname"->"node"->"fieldname"
        SUA_SGP_REG_STAT   -> "ceName-node-linkName-localSSN-tidLable"->"fieldname"

=item EXAMPLE:

   my %statInfo;
   unless ($retStatus = $self->getSgxTableStat(-statusInfo   => \%statInfo)) {
      $logger->error(__PACKAGE__ . ".$sub: Error in getting SS7 Destination status");
      return 0;
   }

=back 

=cut

sub getSgxTableStat {

   my ($self, %args) = @_;
   my $sub = "getSgxTableStat()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Checking mandatory args;
   unless ( defined $a{-tableInfo} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory table info parameter is empty or blank.");
       return 0;
   }

   unless ( defined $a{-statusInfo} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory status info parameter is empty or blank.");
       return 0;
   }

   my $retData = $a{-statusInfo};

   my $cmdString;

   if ($a{-tableInfo} eq "SS7_DEST") {
      $cmdString = "show all details ss7 destinationStatus";
   } elsif ($a{-tableInfo} eq "SS7_MTP2") {
      $cmdString = "show all details ss7 mtp2SignalingLinkStatus";
   } elsif ($a{-tableInfo} eq "M3UA_SGP") {
      $cmdString = "show all details m3ua sgpLinkStatus";
   } elsif ($a{-tableInfo} eq "SUA_SGP") {
      $cmdString = "show all details sua sgpLinkStatus";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK") {
      $cmdString = "show all details ss7 mtp2LinkStatus";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK_CONG") {
      $cmdString = "show all details ss7 mtp2LinkCongestionProfile";
   } elsif ($a{-tableInfo} eq "SS7_ROUTE_STAT") {
      $cmdString = "show all details ss7 routeStatus";
   } elsif ($a{-tableInfo} eq "M3UA_ASP") {
      $cmdString = "show all details m3ua aspLinkStatus";
   } elsif ($a{-tableInfo} eq "SIGTR_SCTP_STAT") {
      $cmdString = "show all details sigtran sctpAssociationStatus";
   } elsif ($a{-tableInfo} eq "M2PA_LINK_STAT") {
      $cmdString = "show all details m2pa m2paLinkStatus";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINKSET_STAT") {
      $cmdString = "show all details ss7 mtp2SignalingLinkSetStatus";
   } elsif ($a{-tableInfo} eq "SIGTR_SCTP") {
      $cmdString = "show all details sigtran sctpAssociation";
   } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK") {
      $cmdString = "show all details m3ua aspLink";
   } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK_SET") {
      $cmdString = "show all details m3ua aspLinkSet";
   } elsif ($a{-tableInfo} eq "SS7_ROUTE") {
      $cmdString = "show all details ss7 route";
   } elsif ($a{-tableInfo} eq "SS7_DEST_TAB") {
      $cmdString = "show all details ss7 destination";
   } elsif ($a{-tableInfo} eq "M2PA_LINK") {
      $cmdString = "show all details m2pa link";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_SIG") {
      $cmdString = "show all details ss7 mtp2SignalingLink";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINKSET") {
      $cmdString = "show all details ss7 mtp2SignalingLinkSet";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_SIG_STAT") {
      $cmdString = "show all details ss7 mtp2SignalingLinkStatus";
   } elsif ($a{-tableInfo} eq "M3UA_SGP_LINK") {
      $cmdString = "show all details m3ua sgpLink";
   } elsif ($a{-tableInfo} eq "SUA_SGP_LINK") {
      $cmdString = "show all details sua sgpLink";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK_TAB") {
      $cmdString = "show all details ss7 mtp2Link";
   } elsif ($a{-tableInfo} eq "M3UA_SGP_REG") {
      $cmdString = "show all details m3ua sgpRegistrationsStatus";
   } elsif ($a{-tableInfo} eq "SS7_SCCP_REM") {
      $cmdString = "show all ss7 sccpRemoteSubSystem";
   } elsif ($a{-tableInfo} eq "SS7_SCCP_REM_STAT") {
      $cmdString = "show all ss7 sccpRemoteSubSystemStatus";
   } elsif ($a{-tableInfo} eq "SS7_SCCP_CON_DEST") {
      $cmdString = "show all ss7 sccpConcernedDestination";
   } elsif ($a{-tableInfo} eq "SUA_SGP_REG_STAT") {
      $cmdString = "show all sua sgpRegistrationsStatus";
   } elsif ($a{-tableInfo} eq "M3UA_INTERSGX_LINK_STAT") {
      $cmdString = "show all m3ua interSgxLinkStatus";
   } else {
      $logger->error(__PACKAGE__ . ".$sub: Invalid table info passed");
      return 0;
   }

   if ( defined $a{-checkSpecific} ) {	
	   $cmdString .=" $a{-checkSpecific}";
   }

   # Run the command
   unless ( $self->execCliCmd($cmdString) ) {
      $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmdString.--\n@{$self->{CMDRESULTS}}");
      return 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub: \n" . Dumper(\@{$self->{CMDRESULTS}}));

   my $resultLine;
   my ($name, $node, $key);
   $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;
   foreach $resultLine (@{$self->{CMDRESULTS}}) {
      if ($a{-tableInfo} eq "SS7_DEST") {
           if ($resultLine =~ /^destinationStatus (\S+) \{$/) {
              $name = $1;
           } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/) {
               switch ( $1 ) {
                  case "state"                               { $retData->{$name}->{STATE}  = $2; }
                  case "mode"                                { $retData->{$name}->{MODE}   = $2; }
                  case "node"                                { $retData->{$name}->{NODE}   = $2; }
                  case "pointCode"                           { $retData->{$name}->{POINT_CODE}  = $2; }
                  case "destinationType"                     { $retData->{$name}->{DEST_TYPE}  = $2; }
                  case "overAllPcStatus"                     { $retData->{$name}->{OVER_ALL_PC_STATUS}  = $2; }
                  case "overAllPcCongestionLevel"            { $retData->{$name}->{OVER_ALL_PC_CONG_LEVEL} = $2; }
                  case "overAllUserPartAvailableList"        { $retData->{$name}->{OVER_ALL_USER_PART_AVA_LIST}  = $2; }
                  case "m3uaPcStatus"                        { $retData->{$name}->{M3UA_PC_STATUS} = $2; }
                  case "m3uaUserPartAvailableList"           { $retData->{$name}->{M3UA_USER_PART_AVA_LIST} = $2; }
                  case "m3uaPcCongestionLevel"               { $retData->{$name}->{M3UA_PC_CONG_LEVEL}  = $2; }
                  case "mtpPcStatus"                         { $retData->{$name}->{MTP_PC_STATUS} = $2; }
                  case "mtpUserPartAvailableList"            { $retData->{$name}->{MTP_USER_PART_AVA_LIST} = $2; }
                  case "formattedPointCode"                  { $retData->{$name}->{FORMATTED_POINT_CODE} = $2; }
                  case "mtpPcCongestionLevel"                { $retData->{$name}->{MTP_PC_CONG_LEVEL} = $2; }
            }
           } elsif ( $resultLine =~ /^\{$/){
	     $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;
             next;
           }
      } elsif (($a{-tableInfo} eq "SS7_MTP2") or
               ($a{-tableInfo} eq "SS7_MTP2_SIG_STAT")) {
        if ($resultLine =~ /^mtp2SignalingLinkStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "mtp2SignalinglinkSetName"        { $retData->{$name}->{LINKSET_NAME}  = $2; }
              case "status"                          { $retData->{$name}->{STATUS}        = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){

            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
    } elsif (($a{-tableInfo} eq "M3UA_SGP") or 
               ($a{-tableInfo} eq "SUA_SGP")) {
         if ($resultLine =~ /^sgpLinkStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "state"                           { $retData->{$name}->{STATE}  = $2; }
              case "mode"                            { $retData->{$name}->{MODE}   = $2; }
              case "sctpAssociationName"             { $retData->{$name}->{ASSOC_NAME} = $2; }
              case "status"                          { $retData->{$name}->{STATUS}  = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
      } elsif (($a{-tableInfo} eq "SS7_MTP2_LINK") or
               ($a{-tableInfo} eq "M2PA_LINK_STAT") or
               ($a{-tableInfo} eq "SS7_MTP2_LINKSET_STAT")) {
         if ( ($resultLine =~ /^mtp2SignalingLinkSetStatus (\S+) \{$/) or ($resultLine =~ m/^m2paLinkStatus (\S+) \{$/)
                  or ($resultLine =~ m/^mtp2LinkStatus (\S+) \{$/) ){
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "status"                           { $retData->{$name}->{STATUS}  = $2; }
	      case "locallyCongested"                 { $retData->{$name}->{LOCALLY_CONGESTED}  = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
      } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK_CONG") {
         if ($resultLine =~ /^mtp2LinkCongestionProfile (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s+(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "congestionSupport"               { $retData->{$name}->{CONGESTION_SUPPORT}  = $2; }
              case "linkUtilizationThreshold"        { $retData->{$name}->{LINK_UTILIZATION_THRESHOLD}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;
            next;
         }
      } elsif ($a{-tableInfo} eq "SS7_ROUTE_STAT") {
         if ($resultLine =~ /^routeStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "typeOfRoute"                     { $retData->{$name}->{TYPE}  = $2; }
              case "linkSetName"                     { $retData->{$name}->{LINK_SET}   = $2; }
              case "destinationName"                 { $retData->{$name}->{DEST} = $2; }
              case "status"                          { $retData->{$name}->{STATUS}  = $2; }
              case "priority"                        { $retData->{$name}->{PRI}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
      } elsif ($a{-tableInfo} eq "M3UA_ASP") {
         if ($resultLine =~ /^aspLinkStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "state"                            { $retData->{$name}->{STATE}  = $2; }
              case "mode"                             { $retData->{$name}->{MODE}   = $2; }
              case "m3uaAspLinkSetName"               { $retData->{$name}->{LINK_SET} = $2; }
              case "sctpAssociationName"              { $retData->{$name}->{ASSOC}  = $2; }
              case "status"                           { $retData->{$name}->{STATUS}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SIGTR_SCTP_STAT") {
         if ($resultLine =~ /^sctpAssociationStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "sctpStatus"                            { $retData->{$name}->{STATUS}  = $2; }
              case "primaryPathIp"                             { $retData->{$name}->{PRIM_IP}   = $2; }
              case "primaryPathPort"               { $retData->{$name}->{PRIM_PORT} = $2; }
              case "currentPathIp"              { $retData->{$name}->{CURR_IP}  = $2; }
              case "currentPathPort"                           { $retData->{$name}->{CURR_PORT}   = $2; }
              case "maxOutboundStream"           { $retData->{$name}->{MAX_STREAM}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SIGTR_SCTP") {
         if ($resultLine =~ /^sctpAssociation (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                            { $retData->{$name}->{INDEX}  = $2; }
              case "state"                             { $retData->{$name}->{STATE}   = $2; }
              case "mode"               { $retData->{$name}->{MODE} = $2; }
              case "localIpAddress1"              { $retData->{$name}->{LOC_IP_ADDR1}  = $2; }
              case "localIpAddress2"                           { $retData->{$name}->{LOC_IP_ADDR2}   = $2; }
              case "localPort"           { $retData->{$name}->{LOC_PORT}   = $2; }
              case "remoteIpAddress1"              { $retData->{$name}->{REM_IP_ADDR1}  = $2; }
              case "remoteIpAddress2"                           { $retData->{$name}->{REM_IP_ADDR2}   = $2; }
              case "remotePort"           { $retData->{$name}->{REM_PORT}   = $2; }
              case "maxInboundStream"     { $retData->{$name}->{MAX_IN}   = $2; }
              case "maxOutboundStream"                           { $retData->{$name}->{MAX_OUT}   = $2; }
              case "sctpProfileName"           { $retData->{$name}->{SCTP_PROF_NAME}   = $2; }
              case "connectionMode"     { $retData->{$name}->{CONN_MODE}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;           
            next;
         }
     } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK") {
        if ($resultLine =~ /^aspLink (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                             { $retData->{$name}->{INDEX}  = $2; }
              case "state"                             { $retData->{$name}->{STATE}   = $2; }
              case "mode"                              { $retData->{$name}->{MODE} = $2; }
              case "sctpAssociationName"               { $retData->{$name}->{ASSOC}  = $2; }
              case "m3uaAspLinkSetName"                { $retData->{$name}->{LINK_SET} = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
      } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK_SET") {
        if ($resultLine =~ /^aspLinkSet (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                             { $retData->{$name}->{INDEX}  = $2; }
              case "state"                             { $retData->{$name}->{STATE}   = $2; }
              case "mode"                              { $retData->{$name}->{MODE} = $2; }
              case "nodeName"                          { $retData->{$name}->{NODE_NAME}  = $2; }
              case "nodeIndex"                         { $retData->{$name}->{NODE_INDEX} = $2; }
              case "dynamicRegistration"               { $retData->{$name}->{DYN_REG}  = $2; }
              case "remoteHostName"                    { $retData->{$name}->{REM_HOST_NAME} = $2; }
              case "sendNetworkAppearance"             { $retData->{$name}->{SEND_NET_APP}  = $2; }
              case "processReceivedNetworkAppearance"  { $retData->{$name}->{PROC_RECVD_NET_APP} = $2; }
              case "routingContextTableName"           { $retData->{$name}->{ROUT_TAB_NAME} = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_ROUTE") {
         if ($resultLine =~ /^route (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                            { $retData->{$name}->{INDEX}  = $2; }
              case "state"                            { $retData->{$name}->{STATE}   = $2; }
              case "mode"                             { $retData->{$name}->{MODE} = $2; }
              case "destination"                      { $retData->{$name}->{DEST} = $2; }
              case "node"                             { $retData->{$name}->{NODE}   = $2; }
              case "routeMode"                        { $retData->{$name}->{ROUTE_MODE} = $2; }
              case "typeOfRoute"                      { $retData->{$name}->{ROUTE_TYPE}  = $2; }
              case "linkSetName"                      { $retData->{$name}->{LINKSET}   = $2; }
              case "formattedPointCode"               { $retData->{$name}->{FORM_PC} = $2; }
              case "pointCodeDecimalValue"            { $retData->{$name}->{PC_DEC}  = $2; }
              case "priority"                         { $retData->{$name}->{PRI}   = $2; }
              case "uniquePriority"                   { $retData->{$name}->{UNQ_PRI}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_DEST_TAB") {
        if ($resultLine =~ /^destination (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "pointCode"                      { $retData->{$name}->{PC} = $2; }
              case "node"                           { $retData->{$name}->{NODE}   = $2; }
              case "pointCodeFormat"                { $retData->{$name}->{PC_FORM} = $2; }
              case "nodeIndex"                      { $retData->{$name}->{NODE_INDEX}  = $2; }
              case "pointCodeDecimalValue"          { $retData->{$name}->{PC_DEC}   = $2; }
              case "destinationType"                { $retData->{$name}->{DEST_TYPE} = $2; }
              case "isupProfile"                    { $retData->{$name}->{ISUP_PROF}  = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
      } elsif ($a{-tableInfo} eq "M2PA_LINK") {
        if ($resultLine =~ /^link (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "sctpAssociationName"            { $retData->{$name}->{ASSOC}   = $2; }
              case "m2paTimerProfile"               { $retData->{$name}->{M2PA_TIMER}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_MTP2_SIG") {
        if ($resultLine =~ /^mtp2SignalingLink (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "activationType"                 { $retData->{$name}->{ACT_TYPE}   = $2; }
              case "linkSet"                        { $retData->{$name}->{LINK_SET}   = $2; }
              case "slc"                            { $retData->{$name}->{SLC}   = $2; }
              case "sltPeriodicTest"                { $retData->{$name}->{SLT_TEST}   = $2; }
              case "srtPeriodicTest"                { $retData->{$name}->{SRT_TEST}   = $2; }
              case "blockMode"                      { $retData->{$name}->{BLK_MODE}   = $2; }
              case "inhibitMode"                    { $retData->{$name}->{INHI_MODE}   = $2; }
              case "level2LinkType"                 { $retData->{$name}->{LINK_TYPE}   = $2; }
              case "level2Link"                     { $retData->{$name}->{LINK}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;          
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_MTP2_LINKSET") {
        if ($resultLine =~ /^mtp2SignalingLinkSet (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "activationType"                 { $retData->{$name}->{ACT_TYPE}   = $2; }
              case "type"                           { $retData->{$name}->{TYPE}   = $2; }
              case "nodeName"                       { $retData->{$name}->{NODE_NAME}   = $2; }
              case "destination"                    { $retData->{$name}->{DEST}   = $2; }
              case "autoSlt"                        { $retData->{$name}->{AUTO_SLT}   = $2; }
              case "autoSrt"                        { $retData->{$name}->{AUTO_SRT}   = $2; }
              case "japanRoutingType"               { $retData->{$name}->{JP_RT_TYPE}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif (($a{-tableInfo} eq "M3UA_SGP_LINK") or
               ($a{-tableInfo} eq "SUA_SGP_LINK")) {
        if ($resultLine =~ /^sgpLink (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "sctpAssociationName"            { $retData->{$name}->{ASSOC_NAME}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK_TAB") {
        if ($resultLine =~ /^mtp2Link (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "index"                          { $retData->{$name}->{INDEX}  = $2; }
              case "state"                          { $retData->{$name}->{STATE}   = $2; }
              case "mode"                           { $retData->{$name}->{MODE} = $2; }
              case "trunkName"                      { $retData->{$name}->{TRUNK_NAME}   = $2; }
              case "timeSlot"                       { $retData->{$name}->{TIME_SLOT}   = $2; }
              case "protocolType"                   { $retData->{$name}->{PROTO_TYPE}   = $2; }
              case "timerProfileName"               { $retData->{$name}->{TMR_PROF_NAME}   = $2; }
              case "linkSpeed"                      { $retData->{$name}->{LINK_SPEED}   = $2; }
              case "errorCorrectionMode"            { $retData->{$name}->{ERR_CORR_MODE}   = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "M3UA_SGP_REG") {
        if ($resultLine =~ /^sgpRegistrationsStatus\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\{$/) {
            $name = $1;
            $retData->{$1}->{OPC}                = $2;
            $retData->{$1}->{DPC}                = $3;
            $retData->{$1}->{NETWORK_APPEARANCE} = $4;
            $retData->{$1}->{CIC_START}          = $5;
            $retData->{$1}->{CIC_END}            = $6;
            $retData->{$1}->{SERVICE}            = $7;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
           switch ($1) {
              case "associatedNode"                { $retData->{$name}->{ASSOCIATED_NODE}    = $2; }
              case "trafficMode"                   { $retData->{$name}->{TRAFFIC_MODE}       = $2; }
              case "routingContextId"              { $retData->{$name}->{ROUTING_CONTEXT_ID} = $2; }
              case "aspStatus"                     { $retData->{$name}->{ASP_STATUS}         = $2; }
              case "formattedOPC"                  { $retData->{$name}->{FORMATTED_OPC}      = $2; }
              case "formattedDPC"                  { $retData->{$name}->{FORMATTED_DPC}      = $2; }
           }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_SCCP_REM") {
         if ($resultLine =~ /^sccpRemoteSubSystem (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
            switch ($1) {
               case "index"                         { $retData->{$name}->{INDEX}              = $2; }
               case "state"                         { $retData->{$name}->{STATE}              = $2; }
               case "mode"                          { $retData->{$name}->{MODE}               = $2; }
               case "destination"                   { $retData->{$name}->{DEST}               = $2; }
               case "node"                          { $retData->{$name}->{NODE}               = $2; }
               case "remoteSsn"                     { $retData->{$name}->{REM_SSN}            = $2; }
            }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "SS7_SCCP_REM_STAT") {
         if ($resultLine =~ /^sccpRemoteSubSystemStatus (\S+) (\S+) \{$/) {
            $name = $1;
            $node = $2;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
            switch ($1) {
               case "state"                         { $retData->{$name}->{$node}->{STATE}     = $2; }
               case "mode"                          { $retData->{$name}->{$node}->{MODE}      = $2; }
               case "destination"                   { $retData->{$name}->{$node}->{DEST}      = $2; }
               case "status"                        { $retData->{$name}->{$node}->{STAT}      = $2; }
               case "remoteSsn"                     { $retData->{$name}->{$node}->{REM_SSN}   = $2; }
            } 
         } elsif ( $resultLine =~ /^\{$/){          
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         } 
     } elsif ($a{-tableInfo} eq "SS7_SCCP_CON_DEST") {
         if ($resultLine =~ /^sccpConcernedDestination (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
            switch ($1) {
               case "index"                         { $retData->{$name}->{INDEX}              = $2; }
               case "state"                         { $retData->{$name}->{STATE}              = $2; }
               case "mode"                          { $retData->{$name}->{MODE}               = $2; }
               case "localNode"                     { $retData->{$name}->{LOCAL_NODE}         = $2; }
               case "nodeIndex"                     { $retData->{$name}->{NODE_INDEX}         = $2; }
               case "localSsn"                      { $retData->{$name}->{LOCAL_SSN}          = $2; }
               case "destination"                   { $retData->{$name}->{DEST}               = $2; }
            }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         } 
     } elsif ($a{-tableInfo} eq "SUA_SGP_REG_STAT") {
         if ($resultLine =~ /^sgpRegistrationsStatus (\S+) (\S+) (\S+) (\S+) (\S+) \{$/) {
            $key = "$1-$2-$3-$4-$5";
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
            switch ($1) {
               case "state"                         { $retData->{$key}->{STATE}          = $2; }
               case "interSgxCE0State"              { $retData->{$key}->{INTER_CE0}      = $2; }
               case "interSgxCE1State"              { $retData->{$key}->{INTER_CE1}      = $2; }
               case "indInterSgxCE0State"           { $retData->{$key}->{INDINTER_CE0}   = $2; }
               case "indInterSgxCE1State"           { $retData->{$key}->{INDINTER_CE1}   = $2; }
            }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } elsif ($a{-tableInfo} eq "M3UA_INTERSGX_LINK_STAT") {
         if ($resultLine =~ /^interSgxLinkStatus (\S+) \{$/) {
            $name = $1;
         } elsif ( $resultLine =~ /^\s*(\S+)\s+(\S+);$/ ) {
            switch ($1) {
               case "state"                         { $retData->{$name}->{STATE}         = $2; }
               case "mode"                          { $retData->{$name}->{MODE}          = $2; }
               case "sctpAssociationName"           { $retData->{$name}->{ASSOC_NAME}    = $2; }
               case "status"                        { $retData->{$name}->{STATUS}        = $2; }
            }
         } elsif ( $resultLine =~ /^\{$/){
            $name = defined $a{-checkSpecific} ? $a{-checkSpecific} : undef;            
            next;
         }
     } else {
         $logger->error(__PACKAGE__ . ".$sub: Invalid table info passed");
         return 0;
     }
   }
 return $retData;
}

=head2 waitForSgxStatusChange()

DESCRIPTION:

   This subroutine waits till the link status is changed to the requested status

=over 

=item ARGUMENTS:

   Mandatory:
      -tableInfo    => Table information
                       - "SS7_DEST"              executes "show table ss7 destinationStatus"
                       - "SS7_MTP2"              executes "show table ss7 mtp2SignalingLinkStatus"
                       - "M3UA_SGP"              executes "show table m3ua sgpLinkStatus"
                       - "SUA_SGP"               executes "show table sua sgpLinkStatus"
                       - "SS7_MTP2_LINK"         executes "show table ss7 mtp2LinkStatus"
                       - "SS7_ROUTE_STAT"        executes "show table ss7 routeStatus"
                       - "M3UA_ASP"              executes "show table m3ua aspLinkStatus";
                       - "SIGTR_SCTP_STAT"       executes "show table sigtran sctpAssociationStatus"
                       - "M2PA_LINK_STAT"        executes "show table m2pa m2paLinkStatus"
                       - "SS7_MTP2_LINKSET_STAT" executes "show table ss7 mtp2SignalingLinkSetStatus"

      -linkNames    => Referrence to array of link names
      -status       => Referrence to hash with key and values
                       Note : Its not mandatory to fill all these values. Please fill in what ever required

                       For "SS7_DEST" table
                          - STATE
                          - MODE
                          - NODE
                          - POINT_CODE
                          - DEST_TYPE
                          - OVER_ALL_PC_STATUS
                          - OVER_ALL_PC_CONG_LEVEL
                          - OVER_ALL_USER_PART_AVA_LIST
                          - M3UA_PC_STATUS
                          - M3UA_USER_PART_AVA_LIST
                          - M3UA_PC_CONG_LEVEL
                          - MTP_PC_STATUS
                          - MTP_PC_CONG_LEVEL
                          - MTP_USER_PART_AVA_LIST
                          - FORMATTED_POINT_CODE

                       For "SS7_MTP2" table
                          - LINKSET_NAME
                          - STATUS

                       For "M3UA_SGP" and "SUA_SGP"
                          - STATE
                          - MODE
                          - ASSOC_NAME
                          - STATUS

                       For "SS7_MTP2_LINK"" and "M2PA_LINK_STAT" and "SS7_MTP2_LINKSET_STAT"
                          - STATUS

                       For "SS7_ROUTE_STAT"
                          - TYPE 
                          - LINK_SET
                          - DEST
                          - PRI
                          - STATUS

                       For "M3UA_ASP"
                          - STATE
                          - MODE
                          - LINK_SET
                          - ASSOC
                          - STATUS

                       For "SIGTR_SCTP_STAT"
                          - STATUS
                          - PRIM_IP
                          - PRIM_PORT
                          - CURR_IP
                          - CURR_PORT
                          - MAX_STREAM
   Optional:
      -interval     => Status check interval
                       Default is 10secs
      -attempts     => Number of attempts
                       Default is 6

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    1      - Success. The links are in the requested state
    0      - fail

=item EXAMPLE:

   my @linkNames = qw(Dest1141 stpMgts2);

   my $statInfo = {};
   $statInfo->{OVER_ALL_PC_STATUS} = "available";
   $statInfo->{OVER_ALL_USER_PART_AVA_LIST} = "sccpTupIsup";
   $statInfo->{OVER_ALL_PC_CONG_LEVEL} = 0;

   my $retData = $sgxObject->waitForSgxStatusChange(-tableInfo  => "SS7_DEST",
                                                    -linkNames  => \@linkNames,
                                                    -status     => $statInfo);

=back 

=cut

sub waitForSgxStatusChange {
   my ($self, %args) = @_;
   my $sub = "waitForSgxStatusChange()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my %a = (-interval    => 10,
            -attempts    =>  6);

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Checking mandatory args;
   unless ( defined $a{-tableInfo} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory table info parameter is empty or blank.");
       return 0;
   }

   unless ( defined $a{-linkNames} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory link names parameter is empty or blank.");
       return 0;
   }

   unless ( defined $a{-status} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory status parameter is empty or blank.");
       return 0;
   }

  my $noOfLinks = scalar @{$a{-linkNames}};
  my %requestedStat = %{$a{-status}};

  $logger->debug(__PACKAGE__ . ".$sub: The link names received @{$a{-linkNames}}");
  $logger->debug(__PACKAGE__ . ".$sub: The key values received \n" . Dumper(\%requestedStat));

   my $attempt = 0;
   # Check the status for the requested number of attempts or the status is changed
   while ($attempt < $a{-attempts}) {

      # Get the status
      my %statInfo;
      my $retStatus;

      # Check the result
      my $linkName;
      my $validLinks = 0;
      my $checkAll = 0;

      foreach $linkName (@{$a{-linkNames}}) {

            if(defined $a{-checkSpecific} and $a{-checkSpecific} == 1) {
            # Get the current status
               unless ($retStatus = $self->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                           -checkSpecific=> $linkName,
                                                           -statusInfo   => \%statInfo)) {
                    $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
                     return 0;
                  }
           }else{
              if($checkAll == 0){
                   unless ($retStatus = $self->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                                 -statusInfo   => \%statInfo)) {
                   $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
                   return 0;
                   }
                  $checkAll = 1;
                 }
            }

         unless (defined ($retStatus->{$linkName})) {
            $logger->error(__PACKAGE__ . ".$sub: This link name looks like wrong \'$linkName\'. Its not part of the display");
            return 0;
         }
         my $tempStat = 1;
         my $key;
         foreach $key (keys %requestedStat) {
            unless (defined $retStatus->{$linkName}->{$key}) {
               $logger->error(__PACKAGE__ . ".$sub: the \'$key\' is unavailable");
               return 0;
            }

            if($retStatus->{$linkName}->{$key} eq $requestedStat{$key}) {
               $logger->debug(__PACKAGE__ . ".$sub: Good. Link \'$linkName\' key \'$key\' is in \'$retStatus->{$linkName}->{$key}\' state");
            } else {
               $tempStat = 0;
               $logger->debug(__PACKAGE__ . ".$sub: Not yet ready . Link \'$linkName\' key \'$key\' is in \'$retStatus->{$linkName}->{$key}\' state");
               last;
            }
         }
         if($tempStat eq 1) {
            $validLinks++;
         }
      }

      if($noOfLinks eq $validLinks) {
         $logger->debug(__PACKAGE__ . ".$sub: all links are in the requested state");
         return 1;
      }

      $attempt++;

      $logger->debug(__PACKAGE__ . ".$sub: The links are not up. Waiting for \'$a{-interval}\' and Attempt no \'$attempt\' ");
      # Sleep for the interval time
      sleep $a{-interval};
   }

   $logger->error(__PACKAGE__ . ".$sub: Request timed out");
   return 0;
}

=head2 setModeIsv()

DESCRIPTION:

   This subroutine sets the table entry to Inservice. If the state to be set as enabled, set the optional argument

=over 

=item ARGUMENTS:

   Mandatory:
      -tableInfo    => Table information
                       - "SIGTR_SCTP"            executes "set sigtran sctpAssociation <name> state enabled"
                                                 executes "set sigtran sctpAssociation <name> mode inService"
                       - "M3UA_ASP_LINK"         executes "set m3ua aspLink <name> state enabled"
                                                 executes "set m3ua aspLink <name> mode inService"
                       - "M3UA_ASP_LINK_SET"     executes "set m3ua aspLinkSet <name> state enabled"
                                                 executes "set m3ua aspLinkSet <name> mode inService"
                       - "SS7_ROUTE"             executes "set ss7 route <name> state enabled"
                                                 executes "set ss7 route <name> mode inService"
                       - "SS7_DEST_TAB"          executes "set ss7 destination <name> state enabled"
                                                 executes "set ss7 destination <name> mode inService"
                       - "M2PA_LINK"             executes "set m2pa link <name> state enabled"
                                                 executes "set m2pa link <name> mode inService"
                       - "SS7_MTP2_SIG"          executes "set ss7 mtp2SignalingLink <name> state enabled"
                                                 executes "set ss7 mtp2SignalingLink <name> mode inService"
                       - "SS7_MTP2_LINKSET"      executes "set ss7 mtp2SignalingLinkSet <name> state enabled"
                                                 executes "set ss7 mtp2SignalingLinkSet <name> mode inService"
                       - "M3UA_SGP_LINK"         executes "set m3ua sgpLink <name> state enabled"
                                                 executes "set m3ua sgpLink <name> mode inService"
                       - "SUA_SGP_LINK"          executes "set sua sgpLink <name> state enabled"
                                                 executes "set sua sgpLink <name> mode inService"
                       - "SS7_MTP2_LINK_TAB"     executes "set ss7 mtp2Link <name> state enabled"
                                                 executes "set ss7 mtp2Link <name> mode inService"

      -name        => Name of the entity.
                      Link Name, Linkset Name etc

   Optional:
      -setState    => Set state flag
                      The values are 0 and 1
                      Default is set to 0

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    1      - Success
    0      - fail

=item EXAMPLE:

   unless ($retCode = $sgx_object->setModeIsv(-tableInfo    => $a{-tableInfo},
                                              -name         => $name,
                                              -setState     => 1)) {
      $logger->error(__PACKAGE__ . ".$sub: Error in setting required status");
      return 0;
   }

=back 

=cut

sub setModeIsv {
   my ($self, %args) = @_;
   my $sub = "setModeIsv()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my %a = (-setState    => 0);

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Checking mandatory args;
   unless ( defined $a{-tableInfo} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory table info parameter is empty or blank.");
       return 0;
   }

   unless ( defined $a{-tableInfo} ) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory table info parameter is empty or blank.");
       return 0;
   }

   my $name = $a{-name};

   my $stateCmdString;
   my $modeCmdString;

   if ($a{-tableInfo} eq "SIGTR_SCTP") {
      $stateCmdString = "set sigtran sctpAssociation $name state enabled";
      $modeCmdString  = "set sigtran sctpAssociation $name mode inService";
   } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK") {
      $stateCmdString = "set m3ua aspLink $name state enabled";
      $modeCmdString  = "set m3ua aspLink $name mode inService";
   } elsif ($a{-tableInfo} eq "M3UA_ASP_LINK_SET") {
      $stateCmdString = "set m3ua aspLinkSet $name state enabled";
      $modeCmdString  = "set m3ua aspLinkSet $name mode inService";
   } elsif ($a{-tableInfo} eq "SS7_ROUTE") {
      $stateCmdString = "set ss7 route $name state enabled";
      $modeCmdString  = "set ss7 route $name mode inService";
   } elsif ($a{-tableInfo} eq "SS7_DEST_TAB") {
      $stateCmdString = "set ss7 destination $name state enabled";
      $modeCmdString  = "set ss7 destination $name mode inService";
   } elsif ($a{-tableInfo} eq "M2PA_LINK") {
      $stateCmdString = "set m2pa link $name state enabled";
      $modeCmdString  = "set m2pa link $name mode inService";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_SIG") {
      $stateCmdString = "set ss7 mtp2SignalingLink $name state enabled";
      $modeCmdString  = "set ss7 mtp2SignalingLink $name mode inService";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINKSET") {
      $stateCmdString = "set ss7 mtp2SignalingLinkSet $name state enabled";
      $modeCmdString  = "set ss7 mtp2SignalingLinkSet $name mode inService";
   } elsif ($a{-tableInfo} eq "M3UA_SGP_LINK") {
      $stateCmdString = "set m3ua sgpLink $name state enabled";
      $modeCmdString  = "set m3ua sgpLink $name mode inService";
   } elsif ($a{-tableInfo} eq "SUA_SGP_LINK") {
      $stateCmdString = "set sua sgpLink $name state enabled";
      $modeCmdString  = "set sua sgpLink $name mode inService";
   } elsif ($a{-tableInfo} eq "SS7_MTP2_LINK_TAB") {
      $stateCmdString = "set ss7 mtp2Link $name state enabled";
      $modeCmdString  = "set ss7 mtp2Link $name mode inService";
   } else {
      $logger->error(__PACKAGE__ . ".$sub: Invalid table info passed");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub: Entering the config private mode.");
   unless ($self->enterPrivateSession() ) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to enter config mode.");
      return 0;
   }

   if($a{-setState} eq 1) {
      $logger->debug(__PACKAGE__ . ".$sub: Setting the state to enabled using \'$stateCmdString\' ");
      unless ($self->execCommitCliCmd($stateCmdString)) {
         unless ($self->leaveConfigureSession) {
            $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
         }
         $logger->error(__PACKAGE__ . ".$sub:  Failed to execute '$stateCmdString'.");
         return 0;
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub: Setting the mode to inService using \'$modeCmdString\' ");
   unless ($self->execCommitCliCmd($modeCmdString)) {
      unless ($self->leaveConfigureSession) {
         $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
      }
      $logger->error(__PACKAGE__ . ".$sub:  Failed to execute '$modeCmdString'.");
      return 0;
   }

   unless ($self->leaveConfigureSession) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub: Left the config private mode.");

   return 1;
}


=head2 roundOffTimeAndDate()

DESCRIPTION:

    This subroutine starts and stops top command for a process

=over 

=item ARGUMENTS:

   Mandatory:
    -string       => String obtained from the command "date +'%T %F'"

   Optional:
    -timeInterval => Next time interval to which we need to do roundoff
                     e.g. If '-timeInterval' is 10 and the actual time is XX:00 thru 09 (hrs:mins) then the start time
                     will be XX:10. Similarly times will be rounded up to XX:20, XX:30, XX:40, XX:50 & XX:00 as required.
                     In the latter case this time would be used if the actual time was (XX-1):50 thru 59.

                     Default => 10 min

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    0       - fail
    $string - Success

=item EXAMPLE:

   $sgx_object->roundOffTimeAndDate( -string       => $string,
                                     -timeInterval => '10',);

=back 

=cut

sub roundOffTimeAndDate {

    my ($self, %args) = @_;
    my $sub = "roundOffTimeAndDate()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $returnString;

    my %a = (-timeInterval => '10');

    #get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    #Checking mandatory args
    unless ((exists $a{-string}) || ($a{-string} !~ /^([0-9]+:){2}/)) {
        $logger->debug("$sub: Time string --> $a{-string}");
        $logger->error("$sub: Mandatory time string is empty or blank or its not in the required format");
        return 0;
    }

    $logger->debug("$sub: =========================================");
    $logger->debug("$sub: = -string       => $a{-string}");
    $logger->debug("$sub: = -timeInterval => $a{-timeInterval}");
    $logger->debug("$sub: =========================================");

    #Separate date and time
    my ($timeString, $dateString) = split (/\s/, $a{-string});

    #Split $timeString into hour, min and sec
    my ($hour, $min, $sec) = split (/:/, $timeString);
    $hour =~ s/^0//;
    $min  =~ s/^0//;

    #Split $dateString into year, month and day
    my ($year, $month, $day) = split (/\-/, $dateString);
    $month =~ s/^0//;
    $day   =~ s/^0//;

    #Check whether given year is a leap year and  then construct array with number of days in a month
    my (@numOfDaysInAMonth, $leapYearStatus);

    if($year % 400 == 0 || ($year % 100 != 0 && $year % 4 == 0)) {
        $leapYearStatus = 1;
    }

    unless ($leapYearStatus) {
        @numOfDaysInAMonth = qw(31 28 31 30 31 30 31 31 30 31 30 31);
    } else {
        @numOfDaysInAMonth = qw(31 29 31 30 31 30 31 31 30 31 30 31);
    }

    #Make roundoff to next time interval
    $min += $a{-timeInterval} - ($min % $a{-timeInterval});

    if ($min == 60) {
        $hour += 1;
        $min   = "00";
    }

    if ($hour == 24) {
        $day += 1;
        $hour = 0;
        $min  = "00";
    }

    if ($day > $numOfDaysInAMonth[$month - 1]) {
        $month += 1;
        $day    = 1;
    }

    if ($month > 12) {
        $year += 1;
        $month = 1;
        $day   = 1;
    }

    #Put leading zeros to hour, date and month if required
    if ($hour < 10) {
        $hour = "0$hour";
    }

    if ($day < 10) {
        $day = "0$day";
    }

    if ($month < 10) {
        $month = "0$month";
    }

    #Construct return value
    $returnString = "${hour}:" . "${min}:" . "00 " . "$year" . "-" . "$month" . "-" . "$day";

    $logger->debug("$sub: Return value --> $returnString");

    return "$returnString";
}

=head2 createDirForLogs()

DESCRIPTION:

   This subroutine creates a directory in the path desired by the user for logging purpose, specific to a testcase.
   It returns the newly created directory path, when successful.

=over 

=item ARGUMENTS:

  Mandatory:
  1.-testCaseID  -   Test Case ID.
  2.-logDir      -   Log Directory Path - Path where you want the Logs to be created.
  3.-loadType    -   Load type. It can be either call rate or message length.
  Optional:
  1.-timeStamp   -   Time Stamp.

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

=item OUTPUT:

    Directory Path      - Success
    0                   - fail

=item EXAMPLE:

   unless (my $dirPath = $sgx_object->createDirForLogs(   -testCaseID      => $testId,
                                                          -logDir          => "/home/wmohammed/ats_user/logs",
                                                          -loadType        => "10K",
                                                          -timeStamp       => $timestamp,                      )){
      $logger->error(__PACKAGE__ . ".$sub: Error in collecting statistics for Load");
      return 0;
   }

=back 

=cut

sub createDirForLogs {
   my ($self, %args) = @_;
   my $sub = "createDirForLogs()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my %a = ( -timeStamp => "00000000-000000" );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Checking mandatory args;
   foreach ( qw / testCaseID logDir loadType / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
      }
   }

   my  $dirName =  "$a{-testCaseID}-" . "$a{-timeStamp}-" . "SGX-" ."$a{-loadType}"."-LOGS" ;
   unless( mkdir ("$a{-logDir}/$dirName" , 0777)) {
       $logger->error(__PACKAGE__ . ".$sub:  Could not create statistics Log directory in the path $a{-logDir} - Error: $! ");
       $logger->debug(__PACKAGE__ . ".$sub:------>  Leaving Sub [0]");
       return 0;
   }

   $a{-logDir} = "$a{-logDir}/$dirName";

   return $a{-logDir};
}


=head2 collectStatsForLoad()

DESCRIPTION:

   This subroutine collects statistics for a Load, and puts them into a Directory specific for the Load.

Note:
    To be called after calling "createDirForLogs()".

=over 

=item ARGUMENTS:

Mandatory:
1.  -logDir       -  Log Directory - The log directory path which is returned after calling "createDirForLogs() API"
2.  -loadType     -  load type - The load type can be either in the form of call rate like 10K or 8K , or in the form of
                     message length like 20BYTES, 30BYTES.
3.  -loadStatus   -  Tells, when is this subroutine called.At the start of a Load( "start" ) or after the load has been run or stopped( "stop" ).

Optional:
1.-internal   -     Internal Statistics command keys.
2.-external   -     External Statistics command keys.

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1      - Success
    0      - fail

=item EXAMPLE:

   unless ( $dirPath = $sgx_object->createDirForLogs(      -testCaseID      => $testId,
                                                          -logDir          => "/home/wmohammed/ats_user/logs",
                                                          -timeStamp       => $timestamp,                      )){
      $logger->error(__PACKAGE__ . ".$sub: Error in collecting statistics for Load");
      return 0;
   }

   unless ( $sgx_object->collectStatsForLoad(             -logDir          => $dirPath,
                                                          -loadType        => "10K",
                                                          -loadStatus      => "start",
                                                          -internal        => ["M3UA","SUA"],
                                                          -external        => ["MTP2","M3UA"],                           )){
      $logger->error(__PACKAGE__ . ".$sub: Error in collecting statistics for Load");
      return 0;
    }

=back 

=cut

sub collectStatsForLoad {
   my ($self, %args) = @_;
   my $sub = "collectStatsForLoad()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my %a = (  );

    # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

   # Checking mandatory args;
   foreach ( qw / logDir loadType loadStatus / ) {
      unless ( defined ( $args{"-$_"} ) ) {
         $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0;
     }
   }

   my $statsFileName = "$a{-logDir}/Statistics-$a{-loadType}.log";
   if ( $a{-loadStatus} =~ /start/) {
       unless ( open OUTFILE, ">$statsFileName" ) {
             $logger->error(__PACKAGE__ . ".$sub:  Cannot open output file \'$statsFileName\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub:  Perhaps you forgot to call createDirForLogs\(\) API before calling this ?");
             $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
             return 0;
       } 
   } else {
       unless ( open OUTFILE, ">>$statsFileName" ) {
             $logger->error(__PACKAGE__ . ".$sub:  Cannot open output file \'$statsFileName\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub:  Perhaps you forgot to call createDirForLogs\(\) API before calling this ?");
             $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
             return 0;
       }
   }

   my @cmdStrings = ( "show table networkInterface statistics", );

   if ( defined $a{-external} ) {
      my @externalCmds = @{$a{-external}};
      foreach ( @externalCmds ) {
          if (/MTP2/) {
              push @cmdStrings,"show table ss7 mtp2LinkMeasurementCurrentStatistics";
              push @cmdStrings,"show table ss7 mtp2LinkMeasurementIntervalStatistics";
          } elsif (/M2PA/) {
              push @cmdStrings,"show table m2pa m2paLinkMeasurementCurrentStatistics";
              push @cmdStrings,"show table m2pa m2paLinkMeasurementIntervalStatistics";
          } elsif (/M3UA/) {
              push @cmdStrings,"show table m3ua aspLinkMeasurementCurrentStatistics";
              push @cmdStrings,"show table m3ua aspLinkMeasurementIntervalStatistics";
          }
      }
   }
   if ( defined $a{-internal}) {
       my @internalCmds = @{$a{-internal}};
       foreach ( @internalCmds ) {
          if (/SUA/) {
              push @cmdStrings,"show table sua sgpLinkMeasurementCurrentStatistics";
              push @cmdStrings,"show table sua sgpLinkMeasurementIntervalStatistics";
          } elsif (/M3UA/) {
              push @cmdStrings,"show table m3ua sgpLinkMeasurementCurrentStatistics";
              push @cmdStrings,"show table m3ua sgpLinkMeasurementIntervalStatistics";
          }
      }
   }
   
   if ( $a{-loadStatus} =~ /start/) {
       print OUTFILE "================= Statistics of internal and external sides Logged ============="."\n";
       print OUTFILE "=================           before the START of the Load           ============="."\n";
   } elsif ( $a{-loadStatus} =~ /stop/) {
       print OUTFILE "================= Statistics of internal and external sides Logged ============="."\n";
       print OUTFILE "=================            after the STOP of the Load            ============="."\n";
   }

   foreach ( @cmdStrings ) {
       print OUTFILE "$_"."\n\n";
       unless ( $self->execCliCmd ( "$_" ) ) {
           $logger->error(__PACKAGE__ . ".$sub:  Cannot execute command $_:\n@{ $self->{CMDRESULTS} }" );
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
       }
       print OUTFILE "@{$self->{CMDRESULTS}}"."\n";
   }

   unless ( close OUTFILE ) {
           $logger->error(__PACKAGE__ . ".$sub:  Cannot close output file \'$statsFileName\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
   }

   return 1;
}


=head2 m3uaSgpRegCheckForCIC()

DESCRIPTION:

   This API is used to determine if a range of CICs is registered on the SGX or not.
   The API parses through the m3ua sgpRegistrationStatus table and finds if the specified range is present or not.

=over 

=item ARGUMENTS:

   Mandatory:
    -OPC       => OPC Range.
    -DPC       => DPC Range.
    -linkNames  => a list containing the M3UA SGP Link Names.
    -CICRange  => The Range of CIC Values to be checked for their presence or absence in the Table. Ex: "1,50" means range 1 to 50.

=item Optional:

    -checkFor  => this parameter specifies if you are checking for the presence or absence of a CIC range and for checking the status of a link either active or inactive.
                  It takes either of these values "presence", "absence", "active" and "inactive" . DEFAULT : "presence"

=item PACKAGE:

    SonusQA::SGX4000:SGX4000HELPER

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE USE:

   unless ( $sgx_object->m3uaSgpRegCheckForCIC(      -OPC       => "0x282828",
                                                     -DPC       => "0x10128",
                                                     -linkNames => "gsxSNOWYCE0Active,gsxSNOWYCE1Active",
                                                     -CICRange  => "1,50",   ---> (pass it either "1,50" or "1-50")
                                                     -checkFor  => "presence" )){
      $logger->error(__PACKAGE__ . ".$sub: Error in finding CIC Registration ");
      return 0;
   }

=back

=cut

sub m3uaSgpRegCheckForCIC {
    my ($self, %args) = @_;
    my $sub = "m3uaSgpRegCheckForCIC()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a;
    my @absence ;
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    # Checking mandatory args;
    foreach ( qw/ OPC DPC linkNames CICRange / ) { 
        unless ( defined $a{-$_} ) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter $_ is empty or blank.");
            return 0;
        }
    }
    
    unless ( defined $a{-checkFor} ) {
        $logger->debug(__PACKAGE__ . ".$sub: checkFor parameter not defined, so set it to \"presence\" ");
        $a{-checkFor} = "presence";
    }
    
    my $cmdString = "show all details m3ua sgpRegistrationsStatus";
    unless ( $self->execCliCmd($cmdString) ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmdString.--\n@{$self->{CMDRESULTS}}");
        return 0;
    }

    my @cicRange;
    if ( $a{-CICRange} =~ /\,/i ) {
	@cicRange = split /,/,$a{-CICRange};
    } elsif ( $a{-CICRange} =~ /\-/i ) {
	@cicRange = split /-/,$a{-CICRange};
    }
 
    my @links = split /,/,$a{-linkNames};
   
    my $checkStatus = 0;
    my $falseFlag = 0;	 
   
    my ( $resultLine, @result, $link, $i, $linkMatch );
    for ( $i =0; $i < scalar (@links) ; $i++ ) {
        $result[$i] = 0;
    }
   
    $i =0;
    foreach $link ( @links ) {
	$linkMatch = 0;
        foreach $resultLine (@{$self->{CMDRESULTS}}) { 
            if ($resultLine =~ /^sgpRegistrationsStatus\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\{$/i) {
	        if ($a{-checkFor} eq "presence" or $a{-checkFor} eq "absence") {
                    if ( ( $link eq $1 ) and ( $a{-OPC} eq $2 ) and ( $a{-DPC} eq $3 ) ) {
                        my $cicStart          = $5;
                        my $cicEnd            = $6;
                        if ( $a{-checkFor} =~ "presence" ){
                            if (  ( $cicRange[0] >= $cicStart ) and ( $cicRange[1] <= $cicEnd ) ) {
                                $logger->debug(__PACKAGE__ . ".$sub: The CIC Range $cicRange[0] - $cicRange[1]  is present in the Range $cicStart to $cicEnd ");
                                $result[$i] = 1;
                                last;
                            }
                        } elsif ( $a{-checkFor} =~ "absence" ) {
                            $logger->debug(__PACKAGE__ . ".$sub: BUT $cicRange[0] NOT  equals $cicEnd \n");
                            if ( ( ( $cicRange[0] <= $cicStart ) and ( $cicRange[1] <= $cicStart ) )  or ( $cicRange[0] >= $cicEnd )  ) {
                                $logger->debug(__PACKAGE__ . ".$sub: The CIC Range $cicRange[0] - $cicRange[1]  is absent in the Range $cicStart to $cicEnd ");
                                $result[$i] = 1;
                                last;
                            } elsif ( ( ( $cicRange[0] >= $cicStart ) and ( $cicRange[0] <= $cicEnd ) )  or ( ( $cicRange[1] >= $cicStart ) and ( $cicRange[1] <= $cicEnd ) ) ) {
                                $logger->error(__PACKAGE__ . ".$sub: The CIC Range $cicRange[0] - $cicRange[1]  is present in the Range $cicStart to $cicEnd ");
                                $logger->debug(__PACKAGE__ . ".$sub: Leaving sub -------> [ Failure ] ");
                                return 0;
                            }
                        } 
                    } else {
                        $absence[$i] = 1 if($a{-checkFor} eq "absence");
                    }
	        }
		if ($a{-checkFor} eq "active" or $a{-checkFor} eq "inactive") {
		    if ( ( $link eq $1 ) and ( $a{-OPC} eq $2 ) and ( $a{-DPC} eq $3 ) ) {
			if ( ( $cicRange[0] >= $5 ) and ( $cicRange[1] <= $6 ) ) {
			    $checkStatus = 1;	
			    $linkMatch = 1;	
			    $logger->info(__PACKAGE__ . ".$sub: Entries with Link Name: $link, CIC range: $cicRange[0]-$cicRange[1], OPC: $a{-OPC}, DPC: $a{-DPC} Exists!!");
			}else{
			    next;	
			}
		    }else{
			next;
		    }
		}	
            }elsif ($checkStatus) {
		if ($a{-checkFor} eq "active") {
		    if ($resultLine =~ /\s+aspStatus\s+(.*)\;$/i) {
			$checkStatus = 0;
			if ($1 =~ /asActive/i) {
  		    	    $logger->info(__PACKAGE__ . ".$sub: Link($link) is active");
			}else{
			    $logger->info(__PACKAGE__ . ".$sub: Link($link) is not active, actual: $1, Expected: asActive");	
			    $falseFlag = 1;
			}
    		    }
		}
		if ($a{-checkFor} eq "inactive") {
		    if ($resultLine =~ /\s+aspStatus\s+(.*)\;$/i) {
			$checkStatus = 0;
			if ($1 =~ /asInactive/i) {
			    $logger->info(__PACKAGE__ . ".$sub: Link($link) is inactive");
			}else{
			    $logger->info(__PACKAGE__ . ".$sub: Link($link) is not inactive, actual: $1, Expected: asInactive");
			    $falseFlag = 1;
			}
		    }
		}
	    }else {
                  next;
            }
        }
	if ($a{-checkFor} eq "active" or $a{-checkFor} eq "inactive") {	
  	    unless ($linkMatch) {
	        $logger->info(__PACKAGE__ . ".$sub: Entries with Link Name: $link, CIC range: $cicRange[0]-$cicRange[1], OPC: $a{-OPC}, DPC: $a{-DPC} does'nt Exist!");
	        $falseFlag = 1;
	    }
	}
        $i++;
    }
   
    if ($a{-checkFor} =~ /inactive/i or $a{-checkFor} =~ /active/i) {
	if ($falseFlag) {
	    $logger->info(__PACKAGE__ . ".$sub: Leaving Sub[Failure]");
	    return 0;	
	}
	$logger->info(__PACKAGE__ . ".$sub: Leaving Sub[Success]");
	return 1;
    }		


    $i = 0;
    foreach (@result) {
        unless ( $_ ) {
            if ($absence[$i] == 1 and $a{-checkFor} eq "absence") {
               $i++;
               next;
            }
            $logger->error(__PACKAGE__ . ".$sub: Failure. Possibly the Link Name $links[$i] is not present in table OR the Range was present/absent.");
            $logger->debug(__PACKAGE__ . ".$sub: Leaving sub -------> [ Failure ] ");
            return 0;
        }
        $i++;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub -------> [ Success ] ");
    return 1;
   
}



=head2 loginViaILOM()

DESCRIPTION:

  This subroutine Logs into the SGX via ILOM.User passes the ILOM IP and this sub connects to the
  ILOM, gets into the root of SGX and returns the object. Steps followed :
  1. Login to the ILOM
  ssh root@10.30.242.220
  password: changeme

  2.  Execute 'start SP/console'
  This gives console access
  give admin/admin as username and password,

  3. su as root (password is sonus1)

=over 

=item Arguments:

   Mandatory :

   1. ILOM IP     - User has to pass the ILOM IP of the SGX.

=item External  Functions Used :

  startConsole() , consoleLogin () and executeSu () of Package SonusQA::ILOM

=item Returns:

    - 1, on success
    - 0, otherwise

=item Example:

   my $ilomSgxRootObj;
   unless ( $ilomSgxRootObj = SonusQA::SGX4000::SGX4000HELPER::loginViaILOM(  -ilomIp => "10.30.242.220" ,
                                       )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to connect to the root of SGX via ILOM ");
        return 0;
    }

=back 

=cut

sub loginViaILOM {

    my  %args  = @_;
    my $sub = "loginViaILOM()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a   = ( );

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__, -sub => $sub, %a );
 
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");
    
    unless ( defined  $a{-ilomIp} ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for ILOM IP has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my ( $ilomObj, $obj );

    # Create an ILOM session via SonusQA::ILOM
    unless( $obj = SonusQA::ILOM->new(-OBJ_HOST => "$a{-ilomIp}",
	                              -OBJ_USER => 'root',
	                              -OBJ_PASSWORD => 'changeme',
	                              -OBJ_COMMTYPE => "SSH",
	)) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to create a ILOM Object for IP $a{-ilomIp} ");
        return 0;
    }
    
    $ilomObj = $obj->{conn};
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfully connected to ILOM IP $a{-ilomIp} ");
    
    unless ( $obj->startConsole() ) {
        $logger->error(__PACKAGE__ . ".$sub: [ $a{-ilomIp} ] Could not start SP/console ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $obj->consoleLogin( "admin" , "admin" ) ) {
        $logger->error(__PACKAGE__ . ".$sub: [ $a{-ilomIp} ] Could not login to admin ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ( $obj->executeSu( "root" , "sonus1" ) ) {
        $logger->error(__PACKAGE__ . ".$sub: [ $a{-ilomIp} ] Could not execute su ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Entered root session via ILOM ");
    $logger->debug(__PACKAGE__ . ".$sub: Successfully created SGX root session via ILOM IP $a{-ilomIp} " );
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [ILOM OBJ]" );
    return $obj;
}


=head2  sgxRootPermitViaILOM ()

DESCRIPTION:

   This API changes the root login permit in file /etc/ssh/sshd_config by replacing 'PermitRootLogin no' with 'PermitRootLogin yes'.
   The ILOM Object is passed as an argument. 
   Destroys the ILOM object passed after the Root login Permit change :) .

=over 

=item Arguments:

   Mandatory :

   1. ILOM Obj    - User has to pass the ILOM Object created via loginViaILOM () API.

=item Returns:

    - 1, on success
    - 0, otherwise

=item Example:

   my $ilomSgxRootObj;
   unless ( $ilomSgxRootObj = SonusQA::SGX4000::SGX4000HELPER::loginViaILOM(  -ilomIp => "10.30.242.220" ,
                                       )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to connect to the root of SGX via ILOM ");
        return 0;
    }
   unless ( SonusQA::SGX4000::SGX4000HELPER::sgxRootPermitViaILOM(  $ilomSgxRootObj 
                                       )) {
        $logger->error(__PACKAGE__ . ".$sub : Failed to change the root permission through sgxRootPermitViaILOM API ");
        return 0;
    }

=back

=cut

sub sgxRootPermitViaILOM {

    my $obj = shift;
    my $sub = "sgxRootPermitViaILOM()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");
    
    unless ( (defined  $obj) && $obj ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for ILOM Object has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $ilomObj = $obj->{conn};
    
    $ilomObj->print(" ");
    
    $logger->debug(__PACKAGE__ . ".$sub: Changing directory to /etc/ssh ");
    
    $obj->execConsoleCmd('cd /etc/ssh/');
    $obj->execConsoleCmd('sed -i "s/PermitRootLogin no/PermitRootLogin yes/" sshd_config ');
    $obj->execConsoleCmd("exit");
    $obj->{conn}->print("exit");
    
    SonusQA::Base::DESTROY($obj);
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfully changed SGX Root Permit Via ILOM  " );
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return 1;
    
}

=head2  checkM3uaCicPersistentTableEntries ()

DESCRIPTION:

     This API works for three functionalities depending on the flag set,
     1. checks for no entries in the table

        Mandatory arguments:
	1. -checkFor

	here, returns 1 (if no entries in the table)
	      returns 0 (else) 

     2. checks for the presence of specified valued entries in the table(entries with specified CIC range, optional (OPC and DPC)),

        Mandatory arguments:
        1. -checkFor
	2. -CIC_start 
	3. -CIC_end

	Optional arguments:
	1. -OPC
	2. -DPC

	here, returns 1 (if the entry exists in the table)
	      returns 0 (else)	

     3. checks for the absence of specified valued entries in the table(entries with specified CIC range, optional (OPC and DPC)),

=over 

=item Mandatory arguments:
	1. -checkFor
        2. -CIC_start 
        3. -CIC_en

	Optional arguments:
        1. -OPC
        2. -DPC

        here, returns 1 (if the entry does'nt exist in the table)
              returns 0 (else)  


=item Example:

   $sgxobj->checkM3uaCicPersistentTableEntries(  -CIC_start => 0,
	   					 -CIC_end   => 30,
						 -OPC 	    => "1-1-1",
						 -DPC       => "1-2-1",
						 -checkFor  => "presence",   --------->Any of these three ["presence", "absence", "no-entries"]
                                      			);

   $sgxobj->checkM3uaCicPersistentTableEntries(  -CIC_start => 0,
                                                 -CIC_end   => 30,
                                                 -OPC       => "1-1-1",
                                                 -DPC       => "1-2-1",
                                                 -checkFor  => "absence",  
                                                        );

   $sgxobj->checkM3uaCicPersistentTableEntries(  -checkFor  => "no-entries",
							);; 

=item Author:

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back 

=cut

sub checkM3uaCicPersistentTableEntries {

    my ($self, %args) = @_;
    my $sub = "checkM3uaCicPersistentTableEntries()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");    		
    $logger->info(__PACKAGE__ . ".$sub: ", Dumper(%args));

    #check for the Mandatory arguments
    unless ( keys %args ) {
        $logger->debug(__PACKAGE__ . ".$sub: Mandatory hash is EMPTY OR UNDEFINED!");
	return 0;
    }

    unless (defined ($args{-CIC_start})) {
	$logger->info(__PACKAGE__ . ".$sub: -CIC_start not specified");
    }  	

    unless (defined ($args{-CIC_end})) {
        $logger->info(__PACKAGE__ . ".$sub: -CIC_end not specified");
    }

    my $strict_validation = 0;
    my $extraMsg = '';
    if( defined $args{-OPC} and defined $args{-DPC} ) {
	$strict_validation = 1;
        $extraMsg = ", for OPC($args{-OPC}), DPC($args{-DPC})";
	$logger->info(__PACKAGE__ . ".$sub: strict validation");
    }

    my $cmd = "show table m3ua cicPersistentTable";	

    unless ( $self->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmd");
	$logger->debug(__PACKAGE__ . ".$sub: Failure results : @{$self->{CMDRESULTS}}");
	return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Output : " . Dumper ($self->{CMDRESULTS}));

    my @fields;
    my $dataStr;
    my $skipLines = 0;
    my $flag = 0; #set to check for no entries in the table
    my $presence;
    my $absence;	
    my $noentry;

    if($args{-checkFor} =~ /no-entries/){
        $noentry = 1;
    }
    if($args{-checkFor} =~ /presence/){
        $presence = 1;
    }
    if($args{-checkFor} =~ /absence/){
        $absence = 1;
    }

    foreach my $line ( @{ $self->{CMDRESULTS}} ) {
        
        if($flag) {
            if($noentry){
  	        if($line =~ /^\[ok\]/i) {
		    $logger->info(__PACKAGE__ . ".$sub: No entries in the table");
  		    $logger->info(__PACKAGE__ . ".$sub: leaving sub [1]");
		    return 1;
                }else{
		    $logger->info(__PACKAGE__ . ".$sub: entries exists in the table");
		    $logger->info(__PACKAGE__ . ".$sub: leaving sub [0]");
		    return 0;
	        }
	    }
	    $flag = 0;
        }

        if($skipLines lt 2) {
            $skipLines = $skipLines + 1;
            next;
        }

        if($line =~ m/------/) {
	    $skipLines = $skipLines + 1;
	    $flag = 1;
            next;
        }

	if($line =~ /^\[ok\]/i) {
	    last;
  	}        
	
        @fields = split(' ', $line);

	if ($strict_validation) {
            if ( $args{-CIC_start} == $fields[3] and $args{-CIC_end} == $fields[4] and $args{-OPC} == $fields[7] and $args{-DPC} == $fields[8] ) {
		$logger->info(__PACKAGE__ . ".$sub: Found the entry with cic-range($fields[3]-$fields[4]), OPC($args{-OPC}), DPC($args{-DPC})");
		if($args{-checkFor} =~ /presence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");	
		    return 1;	
		}    
                if($args{-checkFor} =~ /absence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [0]");
		    return 0;	
                } 	
	    }
	}else{
	    if($args{-CIC_start} == $fields[3] and $args{-CIC_end} == $fields[4]) {
        	$logger->info(__PACKAGE__ . ".$sub: Found the entry with cic-range($fields[3]-$fields[4]) in the table");
	        if($args{-checkFor} =~ /presence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");
		    return 1;
                }
                if($args{-checkFor} =~ /absence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [0]");
		    return 0;
                }	
            }
	}
    }

    
    if($absence){
	$logger->info(__PACKAGE__ . ".$sub: Entries with cic-range ($args{-CIC_start}-$args{-CIC_end}) $extraMsg not present in the table");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving sub [1]");
        return 1;
    }
    if($presence){
	$logger->info(__PACKAGE__ . ".$sub: Entries with cic-range ($args{-CIC_start}-$args{-CIC_end}) $extraMsg not present in the table ");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving sub [0]");
        return 0;
    }
}

=head2 checkM3uaSgpRegistrationsStatus ()

DESCRIPTION:

     This API works for three functionalities depending on the flag set,
     1. checks for no entries in the table,

        Mandatory arguments:
        1. -checkFor

        here, returns 1 (if no entries in the table)
              returns 0 (else) 

    2. checks for the presence of specified valued entries in the table(entries with specified CIC range, optional (OPC and DPC)),

        Mandatory arguments:
        1. -checkFor
        2. -CIC_start 
        3. -CIC_end

        Optional arguments:
        1. -OPC
        2. -DPC

        here, returns 1 (if the entry exists in the table)
              returns 0 (else)  

     3. checks for the absence of specified valued entries in the table(entries with specified CIC range, optional (OPC and DPC)),

=over 

=item  Mandatory arguments:
        1. -checkFor
        2. -CIC_start 
        3. -CIC_end

=item  Optional arguments:
        1. -OPC
        2. -DPC

        here, returns 1 (if the entry does'nt exist in the table)
              returns 0 (else)  
   - Comman optional arguments
       -attempts  - Number of attempts, check the sgpRegistrationStatus table as many times as specified (default is 1).
       -delay     - delay between the attempts (Default is 5 seconds when the attempts > 1).

=item Example:

   $sgxobj->checkM3uaSgpRegistrationsStatus( -CIC_start => 0,
                                             -CIC_end   => 30,
                                             -OPC       => "1-1-1",
                                             -DPC       => "1-2-1",
   					     -checkFor  => "presence",   --------->Any of these three ["presence", "absence", "no-entries"]	
                                             -attempts  => 3,
                                             -delay     => 2,
                                                       ); 

   $sgxobj->checkM3uaSgpRegistrationsStatus( -CIC_start => 0,
                                             -CIC_end   => 30,
                                             -OPC       => "1-1-1",
                                             -DPC       => "1-2-1",
                                             -checkFor  => "absence",       
                                             -attempts  => 3,
                                             -delay     => 2,
                                                       ); 


   $sgxobj->checkM3uaSgpRegistrationsStatus( -checkFor  => "no-entries",
							);	


=item Author:

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back 

=cut

sub checkM3uaSgpRegistrationsStatus {

    my ($self, %args) = @_;
    my $sub = "checkM3uaSgpRegistrationsStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");    		
    $logger->info(__PACKAGE__ . ".$sub: ", Dumper(%args));

    #check for the Mandatory arguments
    unless ( keys %args ) {
        $logger->debug(__PACKAGE__ . ".$sub: Mandatory hash is EMPTY OR UNDEFINED!");
	return 0;
    }
    unless (defined ($args{-CIC_start})) {
	$logger->debug(__PACKAGE__ . ".$sub: -CIC_start not specified");
    }  	
    unless (defined ($args{-CIC_end})) {
        $logger->debug(__PACKAGE__ . ".$sub: -CIC_end not specified");
    }

    my $strict_validation = 0;
    if( defined $args{-OPC} and defined $args{-DPC} ) {
	$strict_validation = 1;
	$logger->info(__PACKAGE__ . ".$sub: strict validation");
    }

    my $presence;
    my $absence;
    my $noentry;

    if($args{-checkFor} =~ /no-entries/){
        $noentry = 1;
    }
    if($args{-checkFor} =~ /presence/){
        $presence = 1;
    }
    if($args{-checkFor} =~ /absence/){
        $absence = 1;
    }

    my $cmd = "show table m3ua sgpRegistrationsStatus";	

    if (defined ($args{-attempts})) {
        $logger->error(__PACKAGE__ . ".$sub: Number of attempts = $args{-attempts}");
        $args{-delay} ||= 5;
    }

    $args{-attempts} ||= 1;

    foreach my $attempt (1..$args{-attempts}) {
    unless ( $self->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmd");
	$logger->debug(__PACKAGE__ . ".$sub: Failure results : @{$self->{CMDRESULTS}}");
	return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Output : " . Dumper ($self->{CMDRESULTS}));

    my @fields;
    my $dataStr;
    my $skipLines = 0;
    my $flag = 0; #set to check for no entries in the table


    foreach my $line ( @{ $self->{CMDRESULTS}} ) {
        
        if($flag) {
            if($noentry){
  	        if($line =~ /^\[ok\]/i) {
		    $logger->debug(__PACKAGE__ . ".$sub: No entries in the table");
  		    $logger->debug(__PACKAGE__ . ".$sub: leaving sub [1]");
		    return 1;
                }else{
		    $logger->debug(__PACKAGE__ . ".$sub: entries exists in the table");
		    $logger->debug(__PACKAGE__ . ".$sub: leaving sub [0]");
		    return 0;
	        }
	    }
	    $flag = 0;
        }

        if($skipLines lt 3) {
            $skipLines = $skipLines + 1;
            next;
        }

        if($line =~ m/------/) {
	    $skipLines = $skipLines + 1;
	    $flag = 1;
            next;
        }

	if($line =~ /^\[ok\]/i) {
	    last;
  	}        
	
        @fields = split(' ', $line);

	if ($strict_validation) {
            if ( ($args{-CIC_start} eq $fields[4]) && ($args{-CIC_end} eq $fields[5]) && ($args{-OPC} eq $fields[11]) && ($args{-DPC} eq $fields[12]) ) {
		$logger->debug(__PACKAGE__ . ".$sub: Found the entry with cic-range($fields[4]-$fields[5]), OPC($args{-OPC}), DPC($args{-DPC})");
		if($args{-checkFor} =~ /presence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");	
		    return 1;	
		}    
                if($args{-checkFor} =~ /absence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [0]");
		    return 0;	
                } 	
	    }
	}else{
	    if( ($args{-CIC_start} eq $fields[4]) and ($args{-CIC_end} eq $fields[5])) { 
		$logger->debug(__PACKAGE__ . ".$sub: Found the entry with cic-range($fields[4]-$fields[5])");
                if($args{-checkFor} =~ /presence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");
		    return 1;
                }
                if($args{-checkFor} =~ /absence/i){
		    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [0]");
		    return 0;
                }	
            }
	}
    }
    sleep ($args{-delay}) if ($args{-delay});
    }

    if($absence){
	$logger->info(__PACKAGE__ . ".$sub: Entries($args{-CIC_start}-$args{-CIC_end}) not present in the table");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving sub [1]");
        return 1;
    }
    if($presence){
	$logger->info(__PACKAGE__ . ".$sub: Entries($args{-CIC_start}-$args{-CIC_end}) not in table ");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving sub [0]");
        return 0;
    }
}

=head2  checkM3uaSgpLinkStatus ()

DESCRIPTION:

     This API works for three functionalities depending on the flag set,
     1. checks for no entries in the table,

	Mandatory arguments:
	1. -checkFor

        here, returns 1 (if no entries in the table)
              returns 0 (else) 

    2. checks whether the link status is up,

        Mandatory arguments:
	1. -checkFor
	2. -LinkName

        here, returns 1 (if the link status is up)
              returns 0 (else)  

     3. checks whether the link status is down,

        Mandatory arguments:
        1. -checkFor
        2. -LinkName

        here, returns 1 (if the link status is down)
              returns 0 (else)  

=over 

=item Example:

   $sgxobj->checkM3uaSgpLinkStatus( -LinkName => "gsxJAYCE0Active",
                                    -checkFor => "Link-up",   --------->Any of these three ["Link-up", "Link-down", "no-entries"]
                                                ); 


   $sgxobj->checkM3uaSgpLinkStatus( -LinkName => "gsxJAYCE0Active",
                                    -checkFor => "Link-down",   
                                                ); 

   $sgxobj->checkM3uaSgpLinkStatus( -checkFor => "no-entries",
						);

=item Author:

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back 

=cut

sub checkM3uaSgpLinkStatus {

    my ($self, %args) = @_;
    my $sub = "checkM3uaSgpLinkStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");
    $logger->info(__PACKAGE__ . ".$sub: ", Dumper(%args));

    #check for the Mandatory arguments
    unless ( keys %args ) {
        $logger->debug(__PACKAGE__ . ".$sub: Mandatory hash is EMPTY OR UNDEFINED!");
        return 0;
    }

    unless (defined ($args{-LinkName})) {
        $logger->debug(__PACKAGE__ . ".$sub: Mandatory parameter -LinkName not specified");
    }

    my $cmd = "show all m3ua sgpLinkStatus";

    unless ( $self->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmd");
        $logger->debug(__PACKAGE__ . ".$sub: Failure results : @{$self->{CMDRESULTS}}");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Output : " . Dumper ($self->{CMDRESULTS}));

    my $Link_up = 0;
    my $Link_down = 0;	

    if($args{-checkFor} =~ /Link-up/){
        $Link_up = 1;
    }
    if($args{-checkFor} =~ /Link-down/){
        $Link_down = 1;
    }

    if($args{-checkFor} =~ /no-entries/) {
        if (grep (/No entries found/i, @{ $self->{CMDRESULTS}})) {
            $logger->debug(__PACKAGE__ . ".$sub: No entries in the table");
            $logger->debug(__PACKAGE__ . ".$sub: leaving sub [1]");
            return 1;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub: entries exists in the table");
            $logger->debug(__PACKAGE__ . ".$sub: leaving sub [0]");
            return 0;
        }
    }

    my ($link_name, $link_status) = ('','');
    foreach my $line ( @{ $self->{CMDRESULTS}} ) {
        chomp $line;
        if ($line =~ /sgpLinkStatus (\S+) \{/) {
            $link_name = $1;
        }
        undef $link_name if ($line =~ /^\{$/);
        if ($args{-LinkName} eq $link_name) {
           $logger->debug(__PACKAGE__ . ".$sub: Found the Link $link_name in the sgpLinkStatus table");
        } else {
           next;
        }
        if ($line =~ /status\s+(\S+)\;/i) {
           $link_status = $1;
           if (($link_status =~ /linkStateUp/i) and $Link_up) {
               $logger->debug(__PACKAGE__ . ".$sub: Link ($link_name) state is UP");
               $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");
               return 1;
           }
           if (($link_status =~ /linkStateDown/i) and $Link_down) {
               $logger->debug(__PACKAGE__ . ".$sub: Link ($link_name) state is DOWN");
               $logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");
               return 1;
           }
           last;
        }
    }

    unless($link_name ){
	$logger->info(__PACKAGE__ . ".$sub: Link($args{-LinkName}) not present in the table");
    }

    if($Link_up and $link_name){
	$logger->info(__PACKAGE__ . ".$sub: Link($args{-LinkName}) is not UP");
    }
    
    if($Link_down and $link_name){
	$logger->info(__PACKAGE__ . ".$sub: Link($args{-LinkName}) is not down");
    }

    $logger->info(__PACKAGE__ . ".$sub: Leaving sub [0]");
    return 0;
}

=pod

=head2 getSgxLogDetails()

    This API gets the logtype as input and it returns the array containing list of all the files corresponding to that specified log(In case if the script produces 2 or more ACT/DBG/SYS log files for one single tests ).

=over 

=item Arguments :

        -logType => ['SYS','DBG','ACT'].

=item Return Values :

  0 if fail
  1 if success

=item Example :

            $gsx_obj->getSgxLogDetails(-logType => 'SYS');

=item Author :

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back 

=cut

sub getSgxLogDetails{

    my ($self,%args) = @_;
    my $sub = "getSgxLogDetails";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my($cmd,$remoteFlag,$logpath,$serialnumber,@cmdresults,$NFSFlag,$dbglogname,$actlogname,$syslogname,$audlogname,$seclogname,$startDBGfile,$startACTfile,$startSYSfile,$startSECfile,$startAUDfile);
    my(@logList);
    my %logDetails;

    $logger->info(__PACKAGE__ . ".$sub Entered");

    #check if mandatory argument specified
    unless(defined ($args{-logType})){
        $logger->info(__PACKAGE__ . ".$sub -logType not specified");
        return 0;
    }

    $cmd = "show table eventLog typeStatus";
    unless ( $self->execCliCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute CLI command:$cmd");
        $logger->debug(__PACKAGE__ . ".$sub: Failure results : @{$self->{CMDRESULTS}}");
        return 0;
    }

    foreach(@{$self->{CMDRESULTS}}) {

        if (m/(\w+).DBG/) {
            $dbglogname = "$1";
            if($args{-logType} =~ m/DBG/){ 
		$logger->info(__PACKAGE__ . ".$sub current DBGlog  : $dbglogname");

		# getting the log files if start log is present
                if($self->{DBGfile} =~ m/(\w+).DBG/){ 
                	my $startDBGfile = $1;
                	$logger->info(__PACKAGE__ . ".$sub starting DBGlog  : $startDBGfile");

                	while ($startDBGfile le $dbglogname) {
                    		push @logList, ($startDBGfile. ".DBG");
                    		$startDBGfile = hex_inc($startDBGfile);
                	}
		}
		# get the current log if start log is not present
		else {
			$logger->warn(__PACKAGE__ . ".$sub Pushing only current DBGlog since starting DBGlog is not present.");
			push @logList, ($dbglogname. ".DBG");
		}
	    }
        }
        if (m/(\w+).ACT/) {
            $actlogname = "$1";

            if($args{-logType} =~ m/ACT/){
		$logger->info(__PACKAGE__ . ".$sub current ACTlog  : $actlogname");
		
		# getting the log files if start log is present
                if($self->{ACTfile} =~ m/(\w+).ACT/){
	                my $startACTfile = $1;
			$logger->info(__PACKAGE__ . ".$sub starting ACTlog  : $startACTfile");

                	while ($startACTfile le $actlogname) {
	                    push @logList, ($startACTfile. ".ACT");
        	            $startACTfile = hex_inc($startACTfile);
                	}
		}
		# get the current log if start log is not present
                else {
			$logger->warn(__PACKAGE__ . ".$sub Pushing only current ACTlog since starting ACTlog is not present.");
                        push @logList, ($actlogname. ".ACT");
		}
	    }
        }
        if (m/(\w+).SYS/) {
            $syslogname = "$1";

            if($args{-logType} =~ m/SYS/){
		$logger->info(__PACKAGE__ . ".$sub current SYSlog  : $syslogname");

		# getting the log files if start log is present
		if($self->{SYSfile} =~ m/(\w+).SYS/){
	                my $startSYSfile = $1;
		        $logger->info(__PACKAGE__ . ".$sub starting SYSlog  : $startSYSfile");

                	while ($startSYSfile le $syslogname) {
	                    push @logList, ($startSYSfile. ".SYS");
        	            $startSYSfile = hex_inc($startSYSfile);
               	 	}
		}
		# get the current log if start log is not present
                else {
			$logger->warn(__PACKAGE__ . ".$sub Pushing only current SYSlog since starting SYSlog is not present.");
                        push @logList, ($syslogname. ".SYS");
		}

	    }
	}
        if (m/(\w+).AUD/) {
            $audlogname = "$1";

            if($args{-logType} =~ m/AUD/){
                $logger->info(__PACKAGE__ . ".$sub current AUDlog  : $audlogname");

		# getting the log files if start log is present
                if($self->{AUDfile} =~ m/(\w+).AUD/){
	               my $startAUDfile = $1;
        	       $logger->info(__PACKAGE__ . ".$sub starting AUDlog  : $startAUDfile");

                	while ($startAUDfile le $audlogname) {
	                    push @logList, ($startAUDfile. ".AUD");
        	            $startAUDfile = hex_inc($startAUDfile);
                	}
		}
		# get the current log if start log is not present
                else {
			$logger->warn(__PACKAGE__ . ".$sub Pushing only current AUDlog since starting AUDlog is not present.");
                        push @logList, ($audlogname. ".AUD");

		}
            }
        }
        if (m/(\w+).SEC/) {
            $seclogname = "$1";

            if($args{-logType} =~ m/SEC/){
                $logger->info(__PACKAGE__ . ".$sub current SEClog  : $seclogname");

		# getting the log files if start log is present
                if($self->{SECfile} =~ m/(\w+).SEC/){
	                my $startSECfile = $1;
        	        $logger->info(__PACKAGE__ . ".$sub starting SEClog  : $startSECfile");

                	while ($startSECfile le $seclogname) {
	                    push @logList, ($startSECfile. ".SEC");
        	            $startSECfile = hex_inc($startSECfile);
               	 	}
		}
		# get the current log if start log is not present
                else {
                        $logger->warn(__PACKAGE__ . ".$sub Pushing only current SEClog since starting SEClog is not present.");
                        push @logList, ($seclogname. ".SEC");

                }
            }
        }
    }

    %logDetails = ( -fileNames => \@logList );

    $logger->info(__PACKAGE__ . ".$sub filenames : @logList") ;
    return {%logDetails};
}


sub hex_inc {
    my ($hextail, $hexhead, $remember_tail_zeros, $tail_len, $remember_head_zeros, $head_len);
    my $hexstring = shift;
    my $len = length $hexstring;
    if ($len > 5) {
        $hextail = substr $hexstring, -5;
        $hexhead = substr $hexstring, 0, ($len-5);
    }
    else {
        $hextail = $hexstring;
        $hexhead = -1;
    }
    
    $remember_tail_zeros = "";
    $hextail =~ /^([0]*)(.*)/;
    $remember_tail_zeros = $1;
    $hextail = $2;
    
    if (!defined($hextail) | ($hextail eq "")) {
        $hextail = 0;
        $remember_tail_zeros = substr $remember_tail_zeros, 0, ((length $remember_tail_zeros) -1);
    }
    
    $tail_len = length $hextail;
    $hextail = hexaddone ($hextail);
    
    if ((length $hextail > $tail_len) && ($remember_tail_zeros ne "" )) {
        $remember_tail_zeros = substr $remember_tail_zeros, 0, ((length $remember_tail_zeros) -1);
    }
    
    $remember_head_zeros = "";
    if ((length $hextail > 5) && ($hexhead != -1)) {
        $remember_head_zeros = "";
        $hexhead=~ /^([0]*)(.*)/;
        $remember_head_zeros = $1;
        $hexhead = $2;
        if (!defined($hexhead) | ($hexhead eq "")) {
            $hexhead = 0;
            $remember_head_zeros = substr $remember_head_zeros, 0, ((length $remember_head_zeros) -1);
        }
        
        $head_len = length $hexhead;
        $hexhead = hexaddone ($hexhead);
    
        if ((length $hexhead > $head_len) && ($remember_head_zeros ne "" )) {
            $remember_head_zeros = substr $remember_head_zeros, 0, ((length $remember_head_zeros) -1);
        }
    
        $hextail = substr $hextail, -5;
    }
    
    if ($hexhead == -1) {
        $hexstring = $remember_tail_zeros . $hextail;
    }
    else {
        $hexstring = $remember_head_zeros . $hexhead . $remember_tail_zeros . $hextail;
    }
    
    return $hexstring;
}


sub hexaddone {
    my $hexin = shift;
    my $hex = '0x'.$hexin;
    my $dec = hex($hex);
    $dec++;
    my $hexout = sprintf "%X", $dec;
    return $hexout;
}

=head2 reconnectAny()

DESCRIPTION:

    This method will make cli reconnection(Active CE of HA setup)

=over 

=item ARGUMENTS:

    Optional - 
       timeToWaitForConn => time to wait for connection, based up on this value number of re-attempt is calculated
       -retry_timeout    => <maximum time to try reconnection (all attempts)
       -retryInterval    => retry interval, which definds the number of attempts, sleep between each attempt

=item OUTPUT:

        1      - if success
        0      - if failure.

=item EXAMPLE:

   unless ($self->reconnectAny( )) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to reconnect" );
      return 0;
   } 

=back 

=cut

sub reconnectAny {
    my ($self, %args) = @_;

    my $sub_name = "reconnectAny";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @device_list =  @{$self->{HA_ALIAS}};
    @device_list = reverse @device_list if( $device_list[0] eq $self->{TMS_ALIAS_NAME});

    my $connAttempts = 1;  # default number of connection attempts
    my $retryInterval = $args{-retryInterval} || 5;
    $args{-retry_timeout} ||= 30;

    if ( defined $args{-timeToWaitForConn}) {
        $connAttempts = int($args{-timeToWaitForConn} / $retryInterval) if ($args{-timeToWaitForConn} >= $retryInterval);
    }

    $self->closeConn();
    $self->{curl}               = undef;
    
    while ( $connAttempts > 0 ) {
       foreach ( @device_list ) {
           my $alias_hashref = SonusQA::Utils::resolve_alias($_);
           $self->{OBJ_HOSTS} = ["$alias_hashref->{MGMTNIF}->{1}->{IP}","$alias_hashref->{MGMTNIF}->{2}->{IP}"];
           $self->{OBJ_HOSTNAME} = $_;
           $self->{SYS_HOSTNAME} = $alias_hashref->{CONFIG}->{1}->{HOSTNAME};
           $self->{TMS_ALIAS_DATA} = $alias_hashref;
           $self->{TMS_ALIAS_NAME} = $_;
           $self->{CMDRESULTS} = [];
           undef $self->{conn};
           undef $self->{LASTCMD};

           $logger->debug(__PACKAGE__ . ".$sub_name:  Attempting re-connection to $_.");
           if ( $self->reconnect(-retry_timeout => $args{-retry_timeout}) ) {
               $logger->debug(__PACKAGE__ . ".$sub_name:  Re-connection attempt to $_ successful.");
               return 1;
           } else {
               $logger->debug(__PACKAGE__ . ".$sub_name:  Re-connection attempt to $_ failed.");
           }
       }

       if ( --$connAttempts > 0) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Waiting $retryInterval seconds before retrying connection attempt -- Attempts remaining = $connAttempts ");
           sleep $retryInterval;
       }
    }

    $logger->error(__PACKAGE__ . ".$sub_name:  Re-connection attempt to all hosts failed.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
    return 0;
}

1;
__END__

