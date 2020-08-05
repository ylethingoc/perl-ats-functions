package SonusQA::SPECTRA2;

=head1 NAME

SonusQA::SPECTRA2 - SonusQA Spectra2 class

=head1 SYNOPSIS

use ATS;

or:

use SonusQA::SPECTRA2;

=head1 DESCRIPTION

SonusQA::SPECTRA2 provides an interface to Spectra2 by extending SonusQA::Base class and Net::Telnet.

=head1 AUTHORS

The C<SonusQA::SPECTRA2> module is written by Avinash Chandrashekar <achandrashekar@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.

=head1 METHODS

=head1 new()

=over 

=item Arguments:

    -obj_host
        Spectra2 unit
    -defaulttimeout
        Default timeout for commands; in seconds; defaults to 10

     Other arguments:

    -obj_user
        Defaults to SYSADMIN
    -obj_password
        Defautls to SYSADMIN
    -batch_script
        Defaults to BCHMODE.TXT
    -batch_script_delay
        Defaults to 30; in secods
    -batch_log
        Defaults to BATCHLOG.TXT
    -dir
        Defaults to /c:/spectra/api

     Note: the above arguments should not be modified.

=item Returns:

    * An instance of the SonusQA::SPECTRA2 class, on success
    * undef, otherwise

=item Examples:

    my $spectra2Obj = new SonusQA::SPECTRA2 ( -obj_host => spectra2_1.in.sonusnet.com,
                                              -defaulttimeout => 20, );

=back 

=cut

use ATS;
use strict;
use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Module::Locate qw ( locate );
use File::Basename;
use Data::Dumper;
use Net::Telnet;
use Net::FTP;
use POSIX qw(strftime);
use Data::GUID;
use Data::UUID;
use File::Basename;
use Switch;
use File::Path qw(mkpath);

our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base);
our @arr_result = ();
my $hostuser = 'administrator';         #Default SPECTRA User Name
my $hostpwd = "spectra2";               #Default SPECTRA Password
my $hostip;
my $spectra_ftp_loc = 'C:\Inetpub\ftproot';     #Default FTP Path
my $result_loc = 'C:\Spectra\printLog';         #Default location of storage of results
#my $new_loc = '/export/home/autouser/inet/results'; #Default Location for storage of Spectra2 Test Results....
my $new_loc = '/export/home/autouser/spectra2/results'; #Default Location for storage of Spectra2 Test Results....

#Log::Log4perl->easy_init($DEBUG);  ## SPECTRA2

use vars qw($self);



# Inherit the two base ATS Perl modules SonusQA::Base and SonusQA::UnixBase
# The functions in this MGTS Perl module extend these two modules.
# Methods new(), doInitialization() and setSystem() are defined in the inherited
# modules and the latter two are superseded by the co-named functions in this module.
#our @ISA = qw(SonusQA::Base SonusQA::UnixBase);
our ($build, $release, $test_result);


###################################################
# doInitialization
###################################################

sub doInitialization {
    my($self, %args)= @_;

    my($temp_file);
    $self->{COMMTYPES} = ["TELNET"];
    $self->{COMM_TYPE} = "TELNET";
    $self->{OBJ_PORT} = 10001;

    $self->{DEFAULTTIMEOUT} = 10;
    $self->{TYPE} = __PACKAGE__;
    $self->{CLITYPE} = "SPECTRA2";
    $self->{conn} = undef;
    $self->{PROMPT} = "/Spectra2\>/";
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{BINMODE} = 0;
    $self->{OUTPUT_RECORD_SEPARATOR} = "\n";

    $self->{VERSION} = "UNKNOWN";
    $self->{LOCATION} = locate __PACKAGE__;
    my $package_name = $self->{TYPE};
    my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm");
    $self->{DIRECTORY_LOCATION} = $path;


    if( exists $ENV{LOG_LEVEL} ) {
        $self->{LOG_LEVEL} = uc $ENV{LOG_LEVEL};
    } else {
        $self->{LOG_LEVEL} = "INFO";
    }

    if ( ! Log::Log4perl::initialized() ) {
        if (  ${self}->{LOG_LEVEL} eq "DEBUG" ) {
            Log::Log4perl->easy_init($DEBUG);
        } elsif (  ${self}->{LOG_LEVEL} eq "INFO" ) {
            Log::Log4perl->easy_init($INFO);
        } elsif (  ${self}->{LOG_LEVEL} eq "WARN" ) {
            Log::Log4perl->easy_init($WARN);
        } elsif (  ${self}->{LOG_LEVEL} eq "ERROR" ) {
            Log::Log4perl->easy_init($ERROR);
        } elsif (  ${self}->{LOG_LEVEL} eq "FATAL" ) {
            Log::Log4perl->easy_init($FATAL);
        } else {
            # Default to INFO level logging
            Log::Log4perl->easy_init($INFO);
        }
    }

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{OBJ_USER}      = "SYSADMIN";
    $self->{OBJ_PASSWORD}  = "SYSADMIN";
  
#    $self->{BATCH_SCRIPT}        = 'BCHMODE.TXT';
#    $self->{BATCH_SCRIPT_DELAY}  = 30;
#    $self->{BATCH_LOG}           = 'BATCHLOG.TXT';
#    $self->{DIR}                 = '/c:/spectra';
#    $self->{ID} = "";  # Current batch script id

#    $self->{OUTPUT} = "";
    $self->{LASTCMD}    = (); 
    $self->{CMDRESULTS} = [];

    # Directory to store SPECTRA2 logs
    # Will be created if does not exist
#    $self->{LOG_DIR} = "~/Logs";
1;
}


###################################################
# setSystem
###################################################

sub setSystem {
my($self, %args) = @_;
my $subName = "setSystem()";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my @cmdList = ( 
                    'Prompt on',  # Turns on the prompt.
                    'Verbose on', # Turns on verbose return information.
                  );

    foreach (@cmdList) {

        $logger->debug(__PACKAGE__ . ".$subName: exec cmd \($_\)");
#        $logger->debug(__PACKAGE__ . ".$subName: prompt set to \'$self->{PROMPT}\'");

        unless ( $self->execCmd(
                             '-cmd'     => "$_",
                             '-timeout' => 30,
                           ) ) {
            $logger->error(__PACKAGE__ . ".$subName: Command \'$_\' Failed");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Command \'$_\' execution Failed; ";
            return 0; # FAIL
        }
        $logger->debug(__PACKAGE__ . ".$subName: Command \'$_\' Successfully Executed");
    }

    $logger->debug(__PACKAGE__ . ".$subName: Success - prompt set to \'$self->{PROMPT}\' on the SPECTRA_2 Box");
    $logger->debug(__PACKAGE__ . ".$subName: Success - verbose set on the SPECTRA_2 Box");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}



###################################################
# openWorkspace
###################################################

=head2 openWorkspace()

Open the workspace with the User Account.
Creates a new instance of the Spectra2 client.

=over 

=item Arguments:

     -username
        the login assigned to the user by the system administrator.
        Name of the user for the new Spectra2 client instance.

     -password
        password for the specifed user.

     -workspace
        workspace path and name to open.

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->openWorkspace(
                                          '-username'  => $username,
                                          '-password'  => $password,
                                          '-workspace' => $workspace,
                                        ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to open the workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - Able to open the workspace on Spectra2");

=back 

=cut

sub openWorkspace {
my ($self, %args) = @_;
my $subName = 'openWorkspace()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ username password workspace / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Mandatory parameters are not passed; ";
            return 0; # FAIL
        }
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd(
                             '-cmd'     => "Open $a{-username} $a{-password} $a{-workspace}",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to \'Open\' the workspace username\($a{-username}\), password\($a{-password}\), workspace\($a{-workspace}\) on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to \'Open\' the workspace username\($a{-username}\), password\($a{-password}\), workspace\($a{-workspace}\) on Spectra2; ";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - Opened Workspace successfully on Spectra2");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}

###################################################
# runWorkspace
###################################################

=head2 runWorkspace()

Open the workspace with the User Account.

=over

=item Arguments:

     -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->runWorkspace() ) {
        $logger->error(__PACKAGE__ . "testId: Unable to \'Run\' the workspace \($workspaceFilename\) on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . "testId: Success - Able to \'Run\' the workspace \($workspaceFilename\) on Spectra2");

=back 

=cut

sub runWorkspace {
my ($self, %args) = @_;
my $subName = 'runWorkspace()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd( '-cmd' => 'Run', '-timeout' => $a{'-timeout'} )) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to run the workspace on Spectra2...");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to run the workspace on Spectra2; ";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - Workspace is Running on Spectra2 :");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}

###################################################
# stopWorkspace
###################################################

=head2 stopWorkspace()

Open the workspace with the User Account.

=over 

=item Arguments:

     -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->stopWorkspace() ) {
        $logger->error(__PACKAGE__ . "testId: Unable to \'Stop\' the workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . "testId: workspace \'Stop\'ed on Spectra2");

=back 

=cut

sub stopWorkspace {
my ($self, %args) = @_;
my $subName = 'stopWorkspace()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd( '-cmd' => 'Stop', '-timeout' => $a{'-timeout'} )) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to Stop the workspace on Spectra2.");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to Stop the workspace on Spectra2; ";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - Workspace is Stoped on Spectra2.");

    sleep 3;

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}



###################################################
# closeWorkspace
###################################################

=head2 closeWorkspace()

Open the workspace with the User Account.

=over 

=item Arguments:

     -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->closeWorkspace() ) {
        $logger->error(__PACKAGE__ . "testId: Unable to \'Close\' the workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . "testId: workspace \'Close\'ed on Spectra2");

=back 

=cut

sub closeWorkspace {
my ($self, %args) = @_;
my $subName = 'closeWorkspace()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd( '-cmd' => 'Close', '-timeout' => $a{'-timeout'} )) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to Close the workspace on Spectra2.");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to Close the workspace on Spectra2; ";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - Workspace is Closed on Spectra2.");

    sleep 3;

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}


###################################################
# runTestscript
###################################################

=head2 runTestscript()

Runs a specified tester script on given workspace.

=over 

=item Arguments:

     -scriptname
        Name of the tester script to be run.

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->runTestscript(
                                          '-scriptname' => $scriptname,
                                          '-timeout'    => $timeout,
                                        ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to run testscript \'$scriptname\' in workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - Able to execute testscript \'$scriptname\' in workspace on Spectra2");

=back 

=cut

sub runTestscript {
my ($self, %args) = @_;
my $subName = 'runTestscript()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $args{'-scriptname'} ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Argument -scriptname not defined or empty.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Scriptname not defined or empty; ";	
        return 0; # FAIL
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd(
                             '-cmd' => "Tester run $a{-scriptname}",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to execute tester script \'$a{-scriptname}\' in workspace on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to execute tester script \'$a{-scriptname}\' in workspace on Spectra2";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - executed tester script \'$a{-scriptname}\' in workspace on Spectra2");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}


###################################################
# stopTestscript
###################################################

=head2 stopTestscript()

Stops a specified tester script on given workspace.

=over 

=item Arguments:

     -scriptname
        Name of the tester script to stop.

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->stopTestscript(
                                          '-scriptname' => $scriptname,
                                          '-timeout'    => $timeout,
                                        ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to stop testscript \'$scriptname\' in workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - Able to stop testscript \'$scriptname\' in workspace on Spectra2");

=back 

=cut

sub stopTestscript {
my ($self, %args) = @_;
my $subName = 'stopTestscript()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $args{'-scriptname'} ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Argument -scriptname not defined or empty.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Script name not defined or empty";
        return 0; # FAIL
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd(
                             '-cmd' => "Tester Stop $a{-scriptname}",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to stop tester script \'$a{-scriptname}\' in workspace on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to stop tester script \'$a{-scriptname}\' in workspace on Spectra2";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - stopped tester script \'$a{-scriptname}\' in workspace on Spectra2");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}


###################################################
# getTestscriptStatus
###################################################

=head2 getTestscriptStatus()

Gets a specified tester script status on given workspace.

=over 

=item Arguments:

     -scriptname
        Name of the tester script to get status.

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->getTestscriptStatus(
                                          '-scriptname' => $scriptname,
                                          '-timeout'    => $timeout,
                                        ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to get testscript \'$scriptname\' status in workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - Able to get testscript \'$scriptname\' status in workspace on Spectra2");

=back 

=cut

sub getTestscriptStatus {
my ($self, %args) = @_;
my $subName = 'getTestscriptStatus()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
my $testResult = 0;
my $isTestscriptRunning = 1;

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $args{'-scriptname'} ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Argument -scriptname not defined or empty.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Script name not defined or empty";
        return 0; # FAIL
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );
    my $iteration = $a{'-timeout'};
    while ($isTestscriptRunning == 1 and $iteration) {
        unless ( $self->execCmd(
                                 '-cmd'     => "Tester Status $a{-scriptname}",
                                 '-timeout' => $a{'-timeout'},
                               ) ) {
            $logger->error(__PACKAGE__ . ".$subName: Unable to get tester script \'$a{-scriptname}\' status in workspace on Spectra2");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Unable to get tester script \'$a{-scriptname}\' status in workspace on Spectra2";
            return 0; # FAIL
        }
        #$logger->debug(__PACKAGE__ . ".$subName: Success - got tester script \'$a{-scriptname}\' status in workspace on Spectra2");

        # Parse the output for PASS / FAIL test result
        foreach ( @{ $self->{CMDRESULTS}} ) {
            if ( /^Tester script\s+\'$a{-scriptname}\'\s+[\S\s]+\s+Result\:\s+(\S+)$/ ) {
                $isTestscriptRunning = 0;
                if ( $1 eq 'Failed' ) {
                    $logger->debug(__PACKAGE__ . ".$subName: Got the tester script results - Failed");
                    $testResult = 0;
                }
                elsif ( $1 eq 'Passed' ) {
                    $logger->debug(__PACKAGE__ . ".$subName: Got the tester script results - Passed");
                    $testResult = 1;
                }
                last;
            }
            #        Tester script 'CQ92760_1' is running, elapsed time 000:00:00:01      
            elsif ( /^Tester script\s+\'$a{-scriptname}\'\s+\S+\s+running/ ) {
                $isTestscriptRunning = 1;
		$iteration--;
                $logger->debug(__PACKAGE__ . ".$subName: Pattern Match - Test Script still Running");
                sleep (1);
                last;
            }
        }
    } # WHILE - end

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$testResult]");
    return $testResult;
}



###################################################
# runTestscriptandGetResult
###################################################

=head2 runTestscriptandGetResult()

Runs a specified tester script on given workspace.

=over 

=item Arguments:

     -scriptname
        Name of the tester script to be run.

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->runTestscriptandGetResult(
                                          '-scriptname' => $scriptname,
                                          '-timeout'    => $timeout,
                                        ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to run testscript \'$scriptname\' in workspace on Spectra2");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - Able to execute testscript \'$scriptname\' in workspace on Spectra2");

=back 

=cut

sub runTestscriptandGetResult {
my ($self, %args) = @_;
my $subName = 'runTestscriptandGetResult()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
my $result;

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $args{'-scriptname'} ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Argument -scriptname not defined or empty.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Script name not defined or empty";
        return 0; # FAIL
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    unless ( $self->execCmd(
                             '-cmd'     => "Tester Run $a{-scriptname}",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to execute tester script \'$a{-scriptname}\' in workspace on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to execute tester script \'$a{-scriptname}\' in workspace on Spectra2";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - executed tester script \'$a{-scriptname}\' in workspace on Spectra2");

    unless ( $self->execCmd(
                             '-cmd'     => "Tester Status $a{-scriptname}",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Unable to get status of tester script \'$a{-scriptname}\' in workspace on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Unable to get status of tester script \'$a{-scriptname}\' in workspace on Spectra2";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - Got the status of tester script \'$a{-scriptname}\' in workspace on Spectra2");

    # Parse the output for PASS / FAIL test result
    foreach ( @{ $self->{CMDRESULTS}} ) {
        if ( /^Tester script\s+\'$a{-scriptname}\'\s+[\S\s]+\s+Result\:\s+(\S+)$/ ) {
            if ( $1 eq "Failed" ) {
                $logger->debug(__PACKAGE__ . ".$subName: Got the tester script results - Failed");
                $result = 0;
            }
            elsif ( $1 eq "Passed" ) {
                $logger->debug(__PACKAGE__ . ".$subName: Got the tester script results - Passed");
                $result = 1;
            }
            last;
        }
        else {
        }
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$result]");
    return $result;
}


###############################################################################

=head2 generatorRun()

Runs a specified generator model

NOTE: Uses Spectra2 API(s) 'Generator Run <modelname>' command.

=over

=item Arguments:

     Mandatory Argument(s):
         -modelname
             Name of the Generator model to be run.
             Model name are case-sensitive

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->generatorRun(
                                          '-modelname' => $modelname,
                                          '-timeout'   => $timeout,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to run generator model($modelname) on Spectra2";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - run generator model($modelname) on Spectra2");

=back 

=cut

###################################################
sub generatorRun {
###################################################
my ($self, %args) = @_;
my $subName = 'generatorRun()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ modelname / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA-  The mandatory argument for -$_ has not been specified or is blank; ";
            return 0; # FAIL
        }
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    my $cmd = "Generator Run $a{'-modelname'}";
    unless ( $self->execCmd(
                             '-cmd'     => "$cmd",
                             '-timeout' => $a{'-timeout'},
                           ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to execute command \'$cmd\' on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Failed to execute command \'$cmd\' on Spectra2; ";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Success - executed command \'$cmd\' on Spectra2");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 generatorStop()

Stop a running generator model

NOTE: Uses Spectra2 API(s) 'Generator Stop <modelname>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -modelname
             Name of the Generator model to be stop.
             Model name are case-sensitive

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->generatorStop(
                                          '-modelname' => $modelname,
                                          '-timeout'   => $timeout,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to stop generator model($modelname) on Spectra2";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - stop generator model($modelname) on Spectra2");

=back 

=cut

###################################################
sub generatorStop {
    my ($self, %args) = @_;

    my $subName = 'generatorStop()';    
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ modelname / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA-  The mandatory argument for -$_ has not been specified or is blank; ";
            return 0; # FAIL
        }
    }

    my %a = ( '-timeout' => $self->{DEFAULTTIMEOUT} );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    # stop only if generator is running (TOOLS-3865)
    my $cmd = "Generator Status $a{'-modelname'}";
    $logger->debug(__PACKAGE__ . ".$subName: Checking whether generator is running or not.");
    unless ( $self->execCmd( '-cmd'     => "$cmd", '-timeout' => $a{'-timeout'}) ){
        $logger->error(__PACKAGE__ . ".$subName: Failed to execute command \'$cmd\' on Spectra2");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Failed to execute command \'$cmd\' on Spectra2; ";
        return 0; 
    }

    if(grep(/^Generator model\s+\'$a{'-modelname'}\'\s+\S+\s+running/, @{$self->{CMDRESULTS}})){
        $logger->debug(__PACKAGE__ . ".$subName: Generator is running. So stopping it...");
        $cmd = "Generator Stop $a{-modelname}";
        unless ( $self->execCmd('-cmd'     => "$cmd", '-timeout' => $a{'-timeout'}) ){
            $logger->error(__PACKAGE__ . ".$subName: Failed to execute command \'$cmd\' on Spectra2");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Failed to execute command \'$cmd\' on Spectra2; ";
            return 0; # FAIL
        }
        $logger->debug(__PACKAGE__ . ".$subName: Success - executed command \'$cmd\' on Spectra2");
    }
    else{
        $logger->debug(__PACKAGE__ . ".$subName: Generator is not running.");
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 getGeneratorModelStatus()

Gets a specified generator model status on given workspace.

NOTE: Uses Spectra2 API(s) 'Generator Status <modelname>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -modelname
             Name of the Generator model to get status.
             Model name are case-sensitive

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->getGeneratorModelStatus(
                                          '-modelname' => $modelname,
                                          '-timeout'    => $timeout,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to get modelname($modelname) status in workspace on Spectra2";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - Able to get modelname($modelname) status in workspace on Spectra2");

=back 

=cut

###################################################
sub getGeneratorModelStatus {
###################################################
my ($self, %args) = @_;
my $subName = 'getGeneratorModelStatus()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
my $testResult = 0;
my $isGeneratorModelRunning = 1;

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ modelname / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- The mandatory argument for -$_ has not been specified or is blank; ";
            return 0; # FAIL
        }
    }

    my %a = (
              '-timeout' => $self->{DEFAULTTIMEOUT},
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    my $starttime = time;
    my $isGeneratorModelRunningAfterStop = 0;
#    $self->_info( -subName => $subName, %a );

    my $cmd = "Generator Status $a{'-modelname'}";
    while ($isGeneratorModelRunning == 1) {
        unless ( $self->execCmd(
                                 '-cmd'     => "$cmd",
                                 '-timeout' => $a{'-timeout'},
                               ) ) {
            $logger->error(__PACKAGE__ . ".$subName: Failed to execute command \'$cmd\' on Spectra2");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Failed to execute command \'$cmd\' on Spectra2";
            return 0; # FAIL
        }

        # Parse the output for PASS / FAIL test result
        foreach ( @{ $self->{CMDRESULTS}} ) {
            #      Generator model 'Model-0' has completed. Result: Passed
            if ( /^Generator model\s+\'$a{'-modelname'}\'\s+[\S\s]+\s+Result\:\s+(\S+)$/ ) {
                $isGeneratorModelRunning = 0;
                if ( $1 eq 'Failed' ) {
                    $logger->debug(__PACKAGE__ . ".$subName: Generator Model($a{'-modelname'}) results - Failed");
                    $testResult = 0;
                }
                elsif ( $1 eq 'Passed' ) {
                    $logger->debug(__PACKAGE__ . ".$subName: Generator Model($a{'-modelname'}) results - Passed");
                    $testResult = 1;
                }
                last;
            }
            #        Generator model 'Model-0' is running, elapsed time 000:00:00:09
            elsif ( /^Generator model\s+\'$a{'-modelname'}\'\s+\S+\s+running/ ) {
                $isGeneratorModelRunning = 1;
                $logger->debug(__PACKAGE__ . ".$subName: Generator Model($a{'-modelname'}) still Running");
                my $currenttime = time;
                my $runningtime = $currenttime - $starttime;
                if(  $runningtime > $a{'-timeout'} ){
                    if( $isGeneratorModelRunningAfterStop == 1 ){
                        $logger->error(__PACKAGE__ . ".$subName:   Generator Model($a{'-modelname'}) seems to be running even after forcefully stopping it. Exiting.. ");
                        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SPECTRA- Generator Model($a{'-modelname'}) seems to be running even after forcefully stopping it. Exiting..";
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$subName: Generator Model($a{'-modelname'}) did not stop in '$a{'-timeout'}' seconds. Stopping the generator forcefully ");
                    unless ( $self->generatorStop(
                                          '-modelname' => $a{'-modelname'},
                                          '-timeout'   => $a{'-timeout'},
                                        ) ) {
                        $logger->error(__PACKAGE__ . ".$subName: Failed to stop the Generator Model($a{'-modelname'}) ");
                        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SPECTRA- Failed to stop the Generator Model($a{'-modelname'})";
                        return 0;
                    }
                    sleep 2;
                    $logger->debug(__PACKAGE__ . ".$subName: Stopped generator model($a{'-modelname'}) on Spectra2");
                    $isGeneratorModelRunningAfterStop = 1;
                }
                sleep (1);
                last;
            }
        }
    } # WHILE - end

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$testResult]");
    return $testResult;
}

###############################################################################

=head2 setEventLogLevel()

The setEventLogLevel() turns on or off the Event Log Level

NOTE: Uses Spectra2 API(s) 'EventLog Info/Error/Warning/AllLevels on/off' command.

=over 

=item Arguments:

    Mandatory Argument(s):
         -level
             The Event Log Level options:
             Info      - information messages in the event log area
             Error     - error messages in the event log area
             Warning   - warning messages in the event log area
             AllLevels - all message types in the event log area

         -state
             The state options:
             on  - enables you to turn on Event Log Level messages.
             off - enables you to turn off Event Log Level messages.

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $level = 'AllLevels';
    my $state = 'on';
    unless ( $spectra2Obj->setEventLogLevel(
                                          '-level' => $level,
                                          '-state' => $state,
                                      ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to set Event Log Level($level), state ($state) on Spectra2.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - set Event Log Level($level), state ($state) on Spectra2.");

=back 

=cut

###################################################
sub setEventLogLevel {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'setEventLogLevel()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ level state / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA- Madatory parameters are not passed; ";
            return 0; # FAIL
        }
    }

    # Checking Event Log Level
    my $validFlag = 0;
    my @validLevels = qw( Info Error Warning AllLevels );
    foreach ( @validLevels ) {
        if ( $_ eq $args{'-level'} ) {
            $validFlag = 1;
            last;
        }
    }
    unless ( $validFlag ) {
        $logger->error(__PACKAGE__ . ".$subName:  Invalid Event Log Level used \'$args{'-level'}\', valid levels(@validLevels).");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Invalid Event Log Level used \'$args{'-level'}\', valid levels(@validLevels);";
        return 0; # FAIL
    }

    if ( ($args{'-state'} ne 'on') && ($args{'-state'} ne 'off') ) {
        $logger->error(__PACKAGE__ . ".$subName:  Invalid state used \'$args{'-state'}\', valid states(on off).");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA- Invalid state used \'$args{'-state'}\', valid states(on off) ;";
        return 0; # FAIL
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "EventLog $a{'-level'} $a{'-state'}";

    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 clearEventLog()

The clearEventLog() clears the Event Log

NOTE: Uses Spectra2 API 'EventLog Clear' command.

=over 

=item Arguments:

    NIL

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->clearEventLog() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to clear Event Log on Spectra2.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - cleared Event Log on Spectra2.");

=back 

=cut

###################################################
sub clearEventLog {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'clearEventLog()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = 'EventLog Clear';

    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS: Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 setEventLogNotification()

The setEventLogNotification() turns on or off the event log notifications, sends all on level event log messages to the specified port and server.

NOTE: Uses Spectra2 API(s) 'EventLog Notification <state> <serverIp> <serverPort>' command.

=over 

=item Arguments:

    Mandatory Argument(s):
         -state
             The state options:
             on  - enables you to turn on Event Log Notifications
             off - enables you to turn off Event Log Notifications

         -ip
             IP address of the server that is to receive the notification messages

         -port
             Port number on the server that is to receive the notification messages

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->setEventLogNotification(
                                          '-state' => $state,
                                          '-ip'    => $serverIp,
                                          '-port'  => $serverPort,
                                      ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to set Event Log Notification($state), server IP($serverIp) port($serverport).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - set Event Log Notification($state), server IP($serverIp) port($serverport).");

=back 

=cut

###################################################
sub setEventLogNotification {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'setEventLogNotification()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ state ip port / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    if ( ($args{'-state'} ne 'on') && ($args{'-state'} ne 'off') ) {
        $logger->error(__PACKAGE__ . ".$subName:  Invalid state used \'$args{'-state'}\', valid states(on off).");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Invalid state used \'$args{'-state'}\', valid states(on off).";
        return 0; # FAIL
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "EventLog Notification $a{'-state'} $a{'-ip'} $a{'-port'}";

    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 exportEventLogFile()

The exportEventLogFile() turns on or off the event log notifications, sends all on level event log messages to the specified port and server.

NOTE: Uses Spectra2 API 'EventLog Export [filename]' command.

=over 

=item Arguments:

     Optional Argument(s):
         -filename - file name to save event log information to a .csv file.
                     Default location "C:\Program Files\Tektronix\Spectra2\ImportExport"
                     Default filename "EventLog.csv"

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filename = 'C:\Inetpub\ftproot\EL111111.csv'
    unless ( $spectra2Obj->exportEventLogFile(
                                          '-filename' => $filename,
                                          '-timeout'  => $30,
                                      ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export Event Log file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export Event Log file($filename).");

=back 

=cut

###################################################
sub exportEventLogFile {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'exportEventLogFile()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout'  => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd;
    if ( defined ( $a{'-filename'} ) ) {
        $cmd = "EventLog Export $a{'-filename'}";
    }
    else {
        $cmd = 'EventLog Export';
    }

    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 reserveBoard()

The reserveBoard() enables to reserve either the hardware in the specific slot number OR reserve all resources in a workspace.

NOTE: Uses Spectra2 API 'Config Reserve <1/All>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -slot - specific slot number to reserve the hardware (OR)
                 'All' to reserve all resources in a workspace

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $slot = 1;
    unless ( $spectra2Obj->reserveBoard(
                                          '-slot' => $slot,
                                      ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to reserve the hardware on specific slot($slot).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - reserved the hardware on specific slot($slot).");

=back 

=cut

###################################################
sub reserveBoard {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'reserveBoard()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ slot / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "Config Reserve $a{'-slot'}";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 unreserveBoard()

The unreserveBoard() enables to unreserve either the hardware in the specific slot number OR unreserve all resources in a workspace.

NOTE: Uses Spectra2 API 'Config Unreserve <1/All>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -slot - specific slot number to unreserve the hardware (OR)
                 'All' to unreserve all resources in a workspace

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $slot = 1;
    unless ( $spectra2Obj->unreserveBoard(
                                          '-slot' => $slot,
                                      ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to unreserve the hardware on specific slot($slot).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - unreserved the hardware on specific slot($slot).");

=back 

=cut

###################################################
sub unreserveBoard {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'unreserveBoard()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ slot / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "Config Unreserve $a{'-slot'}";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 clearFilters()

The clearFilters() clears the current post-capture filter.

NOTE: Uses Spectra2 API 'Filters Clear' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->clearFilters() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to clear current post-capture filters.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - cleared current post-capture filters.");

=back 

=cut

###################################################
sub clearFilters {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'clearFilters()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "Filters Clear";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head1 setFilter()

The setFilter() clears the current post-capture filter.

NOTE: Uses Spectra2 API 'Filters Set <filtername>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -filtername - activate a specific post-capture filter.
                       Filter name is case-sensitive as it appears in the workspace

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filtername = 'Profile-0'
    unless ( $spectra2Obj->setFilter(
                                        '-filtername' => $filtername,
                                    ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to set post-capture filter($filtername).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - set post-capture filter($filtername).");

=back

=cut

###################################################
sub setFilter {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'setFilter()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ filtername / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "Filters Set $a{'-filtername'}";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head1 getFiltername()

The getFiltername() get name of the current post-capture filter.

NOTE: Uses Spectra2 API 'Filters Get' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * name of post-capture filter, on success
    * 0, otherwise

=item Examples:

    my $filtername = $spectra2Obj->getFiltername();
    unless ( $filtername ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to get name of the post-capture filter.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - got name of the post-capture filter($filtername).");

=back 

=cut

###################################################
sub getFiltername {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'getFiltername()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = 'Filters Get';
    
    my $filtername = $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        );

    unless ( $filtername ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\', filter name \'$filtername\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return $filtername; # SUCCESS
}

###############################################################################

=head1 resetStatistics()

The resetStatistics() resets all statistics

NOTE: Uses Spectra2 API 'Stats Reset' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->resetStatistics() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to reset statistics.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - Reset Statistics.");

=back 

=cut

###################################################
sub resetStatistics {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'resetStatistics()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = 'Stats Reset';
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 exportStatistics()

The exportStatistics() exports a statistics to a specified file name.

NOTE: Uses Spectra2 API 'Stats Export <statsname> [filename]' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -statsname - specify the statistic you want to export to a file.
                      The name is case sensitive as it appears in the workspace
                      and requires the name of the statistic as it appears in the tree view,
                      including a path to the statistic determined by the vertical bar symbol "|".
                      e.g. 'Level 1|T1/E1', 'Media|RTP Total', 'SS7|ISUP|Total'
		      NEW: You can pass as array reference which contains the list of stats to be exported

     Optional Argument(s):
         -filename  - specify a .csv file to which you transfer statistical data.
                      Default path "C:\Program Files\Tektronix\Spectra2\ImportExport"
                      e.g. 'Level 1-T1-E1.csv'

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

1.
    my $statsname = 'Level 1|T1/E1';
    my $filename  = 'Level_1-T1-E1.csv';
    unless ( $spectra2Obj->exportStatistics( 
                                            '-statsname' => $statsname, # Mandatory Argument
                                            '-filename'  => $filename,  # Optional Argument
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export statistic($statsname) to specified file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export statistic($statsname) to specified file($filename).");

2.
    my @spectra2stats = ( "Level 1|T1/E1", "Level 1|Ethernet" , "SS7|Level 2|MTP", "SS7|ISUP|Total");
    my $statsname = \@spectra2stats;
    my $folderpath = "Isuptest";
    unless ( $spectra2Obj->exportStatistics(
                                            '-statsname' => $statsname, # Mandatory Argument
                                            '-folderpath'  => $folderpath,  # Optional Argument
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export statistics(@spectra2stats) ";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export statistics(@spectra2stats) ");

=back 

=cut

###################################################
sub exportStatistics {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'exportStatistics()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ statsname / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );
    my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
    my $createcmd;
    my ($folderpath);
    my $flag = 1;
    if(defined $args{-folderpath}){
	$folderpath = $args{-folderpath};
        $logger->debug(__PACKAGE__ . ".$subName: Exporting the statistics to \'$folderpath\' ");
    } else {
	$logger->debug(__PACKAGE__ . ".$subName: Exporting the statistics to C:\\Program Files\\Tektronix\\Spectra2\\ImportExport\\ ");
    }
    my $cmd;
    my $statsref = $a{'-statsname'};
    if ( ref($statsref) eq "ARRAY" ){
	my @statsarray = @$statsref;
 	foreach my $stats (@statsarray){
		my $filename = $stats;
		$filename =~ s"\s+ | \| | /""xg;
	        if ( defined ( $folderpath ) ) {
        	    $cmd = "Stats Export \"$stats\" $folderpath\\$filename.csv";
     		    }
    		else {
        	    $cmd = "Stats Export \"$stats\" $filename.csv";
    		}
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        #$logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
        $flag = 0; # FAIL
	next;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
    }
    } else { 	
    if ( defined ( $a{'-filename'} ) ) {
        $cmd = "Stats Export $a{'-statsname'} $a{'-filename'}";
    }
    else {
        $cmd = "Stats Export $a{'-statsname'}";
    }
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
    }
    if($flag){
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
        return 1; # SUCCESS
    } else {
	$logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0; # FAIL
    }
}

###############################################################################

=head2 retrieveStatistics()

The retrieveStatistics() exports a specified statistic to the telnet prompt

NOTE: Uses Spectra2 API 'Stats Retrieve <statsname>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -statsname - specify the statistic you want to export to a file.
                      The name is case sensitive as it appears in the workspace
                      and requires the name of the statistic as it appears in the tree view,
                      including a path to the statistic determined by the vertical bar symbol "|".
                      e.g. 'Level 1|T1/E1', 'Media|RTP Total', 'SS7|ISUP|Total'

     Optional Argument(s):
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $statsname = 'Level 1|T1/E1';
    unless ( $spectra2Obj->retrieveStatistics( 
                                            '-statsname' => $statsname,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export specified statistic($statsname) to the telnet prompt.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export specified statistic($statsname) to the telnet prompt.");

=back 

=cut

###################################################
sub retrieveStatistics {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'retrieveStatistics()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    foreach ( qw/ statsname / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - The mandatory argument for -$_ has not been specified or is blank.";
            return 0; # FAIL
        }
    }

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = "Stats Retrieve $a{'-statsname'}";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 clearCapture()

The clearCapture() clears the capture buffer

NOTE: Uses Spectra2 API 'Capture Clear' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->clearCapture() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to clear the capture buffer.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - clear the capture buffer.");

=back 

=cut

###################################################
sub clearCapture {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'clearCapture()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub", Dumper(\%a));
#    $self->_info( -subName => $subName, %a );

    my $cmd = "Capture Clear";
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 saveCaptureBuffertoFile()

The saveCaptureBuffertoFile() saves the capture buffer to a file (i.e. file.cap).

NOTE: Uses Spectra2 API 'Capture Save [filename]' command.

=over 

=item Arguments:

     Optional Argument(s):
         -filename - export capture data to a .cap file.
                     The default path "C:\Program Files\Tektronix\Spectra2\ImportExport", you can enter a path to another location.
                     The default filename "CaptureSave.cap"
                     e.g. 'mycapture.cap', 'C:\mycapturebuffer.cap'

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filename = 'mycapture.cap';
    unless ( $spectra2Obj->saveCaptureBuffertoFile( 
                                            '-filename' => $filename,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export capture buffer data to file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export capture buffer data to file($filename).");

=back 

=cut

###################################################
sub saveCaptureBuffertoFile {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'saveCaptureBuffertoFile()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my %a = (
        -timeout => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub", Dumper(\%a));
#    $self->_info( -subName => $subName, %a );

    my $cmd;
    if ( defined( $a{-filename} )) {
	chomp($a{-filename});
        $cmd = "Capture Save " . $a{-filename};
    }
    else {
        $cmd = "Capture Save";
    }
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head1 exportCaptureBuffertoCSV()

The exportCaptureBuffertoCSV() saves the capture buffer to a CSV file (i.e. file.csv).

NOTE: Uses Spectra2 API 'Capture ExportToCSV [filename]' command.

=over 

=item Arguments:

     Optional Argument(s):
         -filename - export capture data to a .csv file.
                     The default path "C:\Program Files\Tektronix\Spectra2\ImportExport", you can enter a path to another location.
                     The default filename "CaptureExport.csv"
                     e.g. 'mycapture.csv', 'C:\mycapturebuffer.csv'

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filename = 'mycapture.csv';
    unless ( $spectra2Obj->exportCaptureBuffertoCSV( 
                                            '-filename' => $filename,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export capture buffer data to CSV file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export capture buffer data to CSV file($filename).");

=back 

=cut

###################################################
sub exportCaptureBuffertoCSV {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'exportCaptureBuffertoCSV()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd;
    if ( defined( $a{'-filename'} )) {
        $cmd = "Capture ExportToCSV a{'-filename'}";
    }
    else {
        $cmd = 'Capture ExportToCSV';
    }
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 exportCaptureBuffertoText()

The exportCaptureBuffertoText() saves the capture buffer to a Text file (i.e. file.txt).

NOTE: Uses Spectra2 API 'Capture ExportToText [filename]' command.

=over 

=item Arguments:

     Optional Argument(s):
         -filename - export capture data to a .txt file.
                     The default path "C:\Program Files\Tektronix\Spectra2\ImportExport", you can enter a path to another location.
                     The default filename "CaptureExport.txt"
                     e.g. 'mycapture.txt', 'C:\mycapturebuffer.txt'

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filename = 'mycapture.txt';
    unless ( $spectra2Obj->exportCaptureBuffertoText( 
                                            '-filename' => $filename,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export capture buffer data to text file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export capture buffer data to text file($filename).");

=back 

=cut

###################################################
sub exportCaptureBuffertoText {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'exportCaptureBuffertoText()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd;
    if ( defined( $a{'-filename'} )) {
        $cmd = "Capture ExportToText a{'-filename'}";
    }
    else {
        $cmd = 'Capture ExportToText';
    }
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 startCallTrace()

The startCallTrace() turns ON the capture call trace option.

NOTE: Uses Spectra2 API 'CallTrace Start' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->startCallTrace() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to turn ON the capture call trace option.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - turn ON the capture call trace option.");

=back 

=cut

###################################################
sub startCallTrace {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'startCallTrace()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = 'CallTrace Start';
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 stopCallTrace()

The stopCallTrace() turns OFF the capture call trace option.

NOTE: Uses Spectra2 API 'CallTrace Stop' command.

=over 

=item Arguments:

    -NIL-

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->stopCallTrace() ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to turn OFF the capture call trace option.";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - turn OFF the capture call trace option.");

=back 

=cut

###################################################
sub stopCallTrace {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'stopCallTrace()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd = 'CallTrace Stop';
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################

=head2 exportCallTracetoCSV()

The exportCallTracetoCSV() export call trace to a CSV file (i.e. file.csv).

NOTE: Uses Spectra2 API 'CallTrace ExportToCSV [filename]' command.

=over 

=item Arguments:

     Optional Argument(s):
         -filename - export call trace data to a .csv file.
                     The default path "C:\Program Files\Tektronix\Spectra2\ImportExport", you can enter a path to another location.
                     The default filename "CalltraceExport.csv"
                     e.g. 'mycalltrace.csv', 'C:\calltracedata.csv'

         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    my $filename = 'mycalltrace.csv';
    unless ( $spectra2Obj->exportCallTracetoCSV( 
                                            '-filename' => $filename,
                                        ) ) {
        $TESTSUITE->{$testId}->{METADATA} .= "FAILED - to export call trace data to CSV file($filename).";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - export call trace data to CSV file($filename).");

=back 

=cut

###################################################
sub exportCallTracetoCSV {
###################################################

    my ( $self, %args ) = @_;
    my $subName = 'exportCallTracetoCSV()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    my %a = (
        '-timeout' => $self->{DEFAULTTIMEOUT},
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -subName => $subName, %a );

    my $cmd;
    if ( defined( $a{'-filename'} )) {
        $cmd = "CallTrace ExportToCSV a{'-filename'}";
    }
    else {
        $cmd = 'CallTrace ExportToCSV';
    }
    
    unless ( $self->execCmd(
                            '-cmd'     => "$cmd",
                            '-timeout' => $a{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1; # SUCCESS
}

###############################################################################



###################################################
# execCmd
###################################################

=head2 execCmd()

Execute command and verify its exit code

=over 

=item Arguments:

    -cmd
        Command to be executed; defaults to ""
    -timeout
        Command timeout, in seconds; defaults to $spectra2Obj->{DEFAULTTIMEOUT} 
        which is 10 by default and is set at object's creation time
    -errormode
        Net::Telnet errmoode handler, defaults to "return"

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - on failure,
      error code -  (e.g., Failed, Access Denied, ...)

    Command's output (without the command itself and the closing prompt) 
    is returned in scalar variable $spectra2Obj->{CMDRESULTS}

=item Example:

    unless ( $spectra2Obj->execCmd(
                        -cmd => "Tester Run $script",
                        -timeout => 400,
                    ) ) {
        $logger->error(__PACKAGE__ . ".$testId: Unable to run the test script $script on workspace $workspaceFilename");
        $TESTSUITE->{$testId}->{METADATA} .= "Unable to run the test script $script:--\n@{ $spectra2Obj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: Success - $script has been started on Workspace $workspaceFilename :");

=back 

=cut

sub execCmd {

my ($self, %args) = @_;
my $subName = 'execCmd()';
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    #$logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $args{'-cmd'} ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Argument -cmd not defined or empty.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - ArgArgument -cmd not defined or empty. ;";
        return 0; # FAIL
    }

    $self->{LASTCMD}    = $args{-cmd}; 
    $self->{CMDRESULTS} = [];
    # discard all data in object's input buffer
    $self->{conn}->buffer_empty;

    my $retValue = 0;
    my %a = (
              '-cmd' => "",
              '-timeout' => $self->{DEFAULTTIMEOUT},
              '-errmode' => "return",
              '-cmd_remove_mode' => 0,
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( -subName => $subName, %a );

    # Execute command
    $logger->debug(__PACKAGE__ . ".$subName: Executing \'$a{-cmd}\'");

    # discard all data in object's input buffer
    $self->{conn}->buffer_empty;

    my @cmdResults = $self->{conn}->cmd(
                                 String  => $a{'-cmd'},
                                 Timeout => $a{'-timeout'},
                                 Cmd_remove_mode => $a{'-cmd_remove_mode'},
                                 Errmode => $a{'-errmode'},
                                 Prompt  => $self->{PROMPT},
                            );

    foreach (@cmdResults) {
        # Processing only the first line of command response
        if ( $_ =~ /(\d+)\s*:\s*([\s\w]+)/ ) { # if verbose is ON
            my $API_ErrorCode        = $1;
            my $API_ErrorDescription = $2;
            $API_ErrorDescription =~ s/\s*$//g;

            if ( $API_ErrorCode eq '0000' ) {
                #$logger->debug(__PACKAGE__ . ".$subName: Command '$a{-cmd}' Successfully Executed - \($API_ErrorDescription\)");
                $retValue = 1;
            }
            else {
                $logger->error(__PACKAGE__ . ".$subName: Command '$a{-cmd}' Failed - Error Code $API_ErrorCode - \($API_ErrorDescription\)");
            }

            last;
        }
        elsif ( $_ =~ /(\d+)/ ) { # if verbose is OFF
            my $API_ErrorCode        = $1;

            if ( $API_ErrorCode eq '0000' ) {
                #$logger->debug(__PACKAGE__ . ".$subName: Command '$a{-cmd}' Successfully Executed");
                $retValue = 1;
            }
            else {
                $logger->error(__PACKAGE__ . ".$subName: Command '$a{-cmd}' Failed");
            }

            last;
        }
    }


    chomp (@cmdResults);
    push(@{$self->{CMDRESULTS}},@cmdResults);
    #$logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [$retValue]");
    return $retValue;
}

###############################################################################

=head2 retriveGeneratorModeldata()

Retrieve the current genrator model data or sepecifed

NOTE: Uses Spectra2 API(s) 'Generator Retrieve <modelname>' command.

=over 

=item Arguments:

     Mandatory Argument(s):
         -pattern
             Validation pattern to confirm test is passed

     Optional Argument(s):
	     -modelname
		     Name of the Generator model to retrive data
         -timeout
             In seconds; Defaults to $spectra2Obj->{DEFAULTTIMEOUT} which is 10 s by default

=item Returns:

    * 1, on success
    * 0, otherwise

=item Examples:

    unless ( $spectra2Obj->retriveGeneratorModeldata(
                                          '-modelname' => $modelname,
                                          '-timeout'    => $timeout,
					  '-pattern'   => 'Scenario-0,Inc_INAP_callCount,1,1'
                                        ) ) {
        printFailTest (__PACKAGE__, $testId, "$TESTSUITE->{$testId}->{METADATA}");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$testId: SUCCESS - Able to Retrieve modelname($modelname) data in workspace on Spectra2");

=back 

=cut

sub retriveGeneratorModeldata {
###################################################
   my ($self, %args) = @_;
   my $subName = 'retriveGeneratorModeldata()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

   $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Check Mandatory Argument(s)
    unless ( defined ( $args{'-pattern'} )  and $args{'-pattern'}) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for \'pattern\'  has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA -  The mandatory argument for \'pattern\'  has not been specified or is blank.";
            return 0; # FAIL
    }

    my $cmd = "Generator Retrieve";
    $cmd .= " $args{'-modelname'}"  if (defined $args{'-modelname'} and $args{'-modelname'});
    $args{-timeout} ||= $self->{DEFAULTTIMEOUT};

    my @result = ();
    unless ( @result = $self->{conn}->cmd(
                            'String'     => "$cmd",
                            'Timeout' => $args{'-timeout'},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SPECTRA - Failed to execute command \'$cmd\' ;";
        return 0; # FAIL
    }

    chomp @result;

    my @found = ();
    unless (@found = grep (/$args{-pattern}/i, @result)) {
       $logger->error(__PACKAGE__ . ".$subName:  Failed to find \"$args{-pattern}\" in ->"  . Dumper(\@result));
       $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [0]");
       $main::failure_msg .= "TOOLS:SPECTRA - Failed to find \"$args{-pattern}\" in ->";
       return 0;
    }

    $logger->info(__PACKAGE__ . ".$subName: pattern found -> " . Dumper(\@found));
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving sub [1]");
    return 1;
}

###################################################
# _info
###################################################

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '_info');

    unless ($args{-subName}) {
        $logger->error(__PACKAGE__ . "._info Argument \"-subName\" must be specified and not be blank. $args{-subName}");
	$main::failure_msg .= "TOOLS:SPECTRA - Argument \"-subName\" must be specified and not be blank. $args{-subName}";
        return 0; # FAIL
    }

    $logger->debug(__PACKAGE__ . ".$args{-subName} Entering $args{-subName} function");
    $logger->debug(__PACKAGE__ . ".$args{-subName} ====================");

    if ( $args{-subName} eq 'execCmd()' ) {
        foreach ( qw/ -cmd -timeout -cmd_remove_mode / ) {
            if (defined $args{$_}) {
                $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => $args{$_}");
            } else {
                $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => undef");
            }
        }
    }
    else {
        foreach ( keys %args ) {
            if (defined $args{$_}) {
                $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => $args{$_}");
            } else {
                $logger->debug(__PACKAGE__ . ".$args{-subName}\t$_ => undef");
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$args{-subName} ====================");

    return 1; # SUCCESS
}


###################################################
# copyStats
###################################################

=head2 copyStats()

Copies the Spectra Stats from Spectra server to local server at the specfied path through FTP.

=over 

=item Arguments:

     -stats
        Optional. Reference to array containing SPECTRA stats files to be copied. 
        If not specified, default SPECTRA stats  of PT will be copied.

     -local_dir
        Optional. This is taken only if $self->{result_path} is not specified.

=item Returns:

    * 1, on success
    * 0, otherwise

=back 

=cut

sub copyStats {
    my ($self, %args) = @_;
    my $sub="copyStats";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.copyStats');
    my $statsref = $args{-stats};
    my @stats = @$statsref;
    my $result = 1; #setting the result to pass by default and set to 0 if some operations fails .The final  value of the same is returned at the end
    my $local_dir=$self->{result_path};

    unless(@stats) {
        $logger->info( __PACKAGE__ . "Reference to stats not explicitly defined. Taking default PT Stats");
        @stats = ( "Level 1|Ethernet" , "Level 1|T1/E1", "Level 2|MTP", "Level 2|MTP Link State" , "Level 3|Link Statistics - ANSI" , "Level 3|Link Status" , "Level 3|SLS Distribution" , "Level 3|Congestion Per DPC" , "SCCP Message Type|Total", "SCCP Segment|Total", "TCAP Message Type|Total" , "Local Opcode|Total" , "Global Opcode|Total" , "M3UA|Total" );
    }
    unless(defined $self->{result_path}) {
        $logger->info( __PACKAGE__ . "Result Path is not set as spectra object attribute. Taking from sub argument");
        if(!defined $args{-local_dir}) {
            $logger->error(__PACKAGE__ . ".$sub:  Result path not specified in sub call also");
            $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
	    $main::failure_msg .= "TOOLS:SPECTRA - Result path not specified in sub call also";
            return 0;
        } else {
            $local_dir=$args{-local_dir}."/inet_DATA/";
            $logger->info(__PACKAGE__ . ".$sub: Taking result path as $local_dir");
        }
    } else {
        $logger->info( __PACKAGE__ . "Result Path is set as spectra object attribute");
    }

    unless (mkpath($local_dir)) {
        $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir $local_dir");
    } else {
        $logger->info(__PACKAGE__ . ".$sub: Successfully made dir $local_dir");
    }

    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SFTP_ID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SFTPPASSWD};
    my $ftp;
    if ( $ftp = Net::FTP->new("$hostIp", Debug => 0) ) {
        $logger->info("Connected to the Remote Host for FTP");
    } else {
        $logger->error(__PACKAGE__ . ".$sub:  Failed to open FTP session");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
        return 0;
    }
    if ( $ftp->login("$hostUser","$hostPwd") ) {
      $logger->info("FTP LOGIN SUCCESSFUL");
    } else {
      my @ftpmsg = $ftp->message;
      $logger->warn("FTP LOGIN NOT SUCCESSFUL");
      $logger->warn("SERVICE_MSG: @ftpmsg");
      $ftp->close();
      return 0;
    }
    foreach(@stats) {
        $_ =~ s"\s+ | \| | /""xg;
        if ( $ftp->get($_.".csv", $local_dir."/".$_.".csv") ) {
            $logger->info("FTP RESULT FILE $_ =SUCCESSFUL");
        } else {
            my @ftpmsg = $ftp->message;
            $logger->error("FTP RESULT FILE $_ = NOT SUCCESSFUL");
            $logger->error("SERVICE_MSG: @ftpmsg");
	    $main::failure_msg .= "TOOLS:SPECTRA - FTP RESULT FILE $_ = NOT SUCCESSFUL";
            $result = 0;
        }
    }
$ftp->close();
$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$result]");
return $result;
}

###############################################################################

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
