package SonusQA::Inet;

=head1 NAME

SonusQA::Inet - SonusQA Inet class

=head1 SYNOPSIS

use ATS;

or:

use SonusQA::Inet;

=head1 DESCRIPTION

SonusQA::Inet provides an interface to Inet by extending SonusQA::Base class and Net::Telnet.

=head1 AUTHORS

The C<SonusQA::Inet> module is written by Pawel Nowakowski <pnowakowski@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.

=head1 METHODS

=head1 new()


Arguments:

    -obj_host
        Inet unit
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

Returns:

    * An instance of the SonusQA::Inet class, on success
    * undef, otherwise

Examples:

    my $inet = new SonusQA::Inet ( -obj_host => inet1.in.sonusnet.com,
                                   -defaulttimeout => 20, );

=cut

use ATS;
use SonusQA::Utils qw(:errorhandlers :utilities);
use Module::Locate qw ( locate );
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

our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base);
our @arr_result = ();
my $hostuser = 'administrator';         #Default INET User Name
my $hostpwd = "spectra2";               #Default INET Password
my $hostip;
my $spectra_ftp_loc = 'C:\Inetpub\ftproot';     #Default FTP Path
my $result_loc = 'C:\Spectra\printLog';         #Default location of storage of results
my $new_loc = $ENV{HOME} . "/inet/results"; #Default Location for storage of Inet Test Results....

#Log::Log4perl->easy_init($DEBUG);  ## INET

use vars qw($self);



# Inherit the two base ATS Perl modules SonusQA::Base and SonusQA::UnixBase
# The functions in this MGTS Perl module extend these two modules.
# Methods new(), doInitialization() and setSystem() are defined in the inherited
# modules and the latter two are superseded by the co-named functions in this module.
#our @ISA = qw(SonusQA::Base SonusQA::UnixBase);
our ($build, $release);


###################################################
# doInitialization
###################################################

sub doInitialization {
    my($self, %args)= @_;

    my($temp_file);
    $self->{COMMTYPES} = ["TELNET"];
    $self->{COMM_TYPE} = "TELNET";
    $self->{OBJ_PORT} = 4000;

    $self->{DEFAULTTIMEOUT} = 10;
    $self->{TYPE} = __PACKAGE__;
    $self->{CLITYPE} = "inet";

    $self->{conn} = undef;
    $self->{PROMPT} = '/.*>$/';
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

  $self->{BATCH_SCRIPT}        = 'BCHMODE.TXT';
  $self->{BATCH_SCRIPT_DELAY}  = 30;
  $self->{BATCH_LOG}           = 'BATCHLOG.TXT';
  $self->{DIR}                 = '/c:/spectra';
  $self->{ID} = "";  # Current batch script id

#    $self->{OUTPUT} = "";


    # Directory to store INET logs
    # Will be created if does not exist
#    $self->{LOG_DIR} = "~/Logs";
1;
}


###################################################
# setSystem
###################################################

sub setSystem {
    my($self, %args) = @_;
    my $sub = "setSystem()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");

    my $conn = $self->{conn};

    $logger->debug(__PACKAGE__ . ".setSystem Starting shell ");

  # Set new prompt
  $self->{PROMPT} = '/ats_auto_prompt> $/';
  $conn->prompt( $self->{PROMPT} );


  unless ( $conn->cmd( -string => 'prompt "ats_auto_prompt> "', -cmd_remove_mode => 1 ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to set prompt: " . $conn->lastline);
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $conn->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
        return 0;
  } else {
        $logger->debug(__PACKAGE__ . ".$sub Success - prompt set");
  }

  $logger->debug(__PACKAGE__ . ".$sub Success");
  1;

}

###################################################
# check_for_spacebar
###################################################

=head1 check_for_spacebar()

Check whether a test script prompts for spacebar

Arguments:

    -timeout
        How long to wait for the prompt; in seconds; defaults to 20

Returns:

    * 1, prompt detected
    * 0, otherwise

Examples:

    if ( $obj->check_for_spacebar( -timeout 15 ) ) {
        $obj->press_spacebar();
    } else {
        print "Failure: no spacebar prompt received";
    }

=cut

sub check_for_spacebar {
  my ($self, %args) = @_;
  my $sub = "check_for_spacebar()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -timeout => 20 );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my $result = 0;

  if ( $self->cmd( -cmd => "NOTIFY SPACEBAR CONTINUOUS 1" ) ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to enable spacebar notification:\n$self->{output}");
	return $result;
  }

  unless ( $self->{conn}->waitfor( -match => '/Spectra .* on SpaceBar/', -timeout => $a{-timeout}, -errmode => 'return', ) ) {
	$logger->error(__PACKAGE__ . ".$sub No spacebar prompt detected after $a{-timeout} s");
  } else {
	$logger->debug(__PACKAGE__ . ".$sub Success - spacebar prompt detected");
	$result = 1;
  }

  if ( $self->cmd( -cmd => "NOTIFY SPACEBAR OFF", %a ) ) {
	$logger->warn(__PACKAGE__ . ".$sub Failed to turn off spacebar notification");
  }

  $logger->debug(__PACKAGE__ . ".$sub Returning $result");
  return $result;
}

###################################################
# press_spacebar
###################################################

=head1 press_spacebar()

Send the 'press spacebar' command

Arguments:

    -timeout
        In seconds; Defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * 1, on success
    * 0, otherwise

=cut

sub press_spacebar {
  my ($self, %args) = @_;
  my $conn = $self->{conn};
  my $sub = "press_spacebar()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -timeout => $self->{DEFAULTTIMEOUT} );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  if ( $self->cmd( -cmd => "KEYBOARD SPACEBAR", %a ) ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to send a 'press spacebar' command");
	return 0;
  }

  $logger->debug(__PACKAGE__ . ".$sub Success");
  return 1;
}

###################################################
# keyboard lock
###################################################

=head1 lock_keyboard()

Lock the Spectra system keyboard

Arguments:
    None    

Returns:
    None

Examples:

    $obj->lock_keyboard()

=cut

sub lock_keyboard {
  my ($self, %args) = @_;
  my $sub = "lock_keyboard()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my $result = 0;

  if ( $self->cmd( -cmd => 'KBOARD LOCK' ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to Lock the Spectra Keyboard");
        return $result;
  }
  else {
        $logger->debug(__PACKAGE__ . ".$sub Success - Locked the Spectra keyboard ");
        $result = 1;
  }
  return $result;
}

###################################################
# keyboard unlock
###################################################

=head1 unlock_keyboard()

UnLock the Spectra system keyboard

Arguments:
    None

Returns:
    None

Examples:

    $obj->unlock_keyboard()

=cut

sub unlock_keyboard {
  my ($self, %args) = @_;
  my $sub = "unlock_keyboard()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my $result = 0;

  if ( $self->cmd( -cmd => "KBOARD UNLOCK" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to UnLock the Spectra Keyboard");
        return $result;
  }
  else {
        $logger->debug(__PACKAGE__ . ".$sub Success - UnLocked the Spectra keyboard ");
        $result = 1;
  }
  return $result;
}

###################################################
# pause_spectra
###################################################


=head1 pause_spectra()

Time (in Seconds) to provide the Spectra to complete the Current Test Assignment. This is the pause option set for the Telnet Session

Arguments:

    -seconds
        How long to wait for the current test to be completed; defaults to 5

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    $obj->pause_spectra( -seconds "15" )

=cut

sub pause_spectra {
  my ($self, %args) = @_;
  my $sub = "pause_spectra()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -seconds => 5 );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my $result = 0;

  if ( $self->cmd( -cmd => "PAUSE $a{-seconds}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to set the Pause period to $a{-seconds}:\n:$self->{output}");
        return $result;
  }
  else {
        $logger->debug(__PACKAGE__ . ".$sub Success - paused for $a{-seconds} ");
        $result = 1;

        # PAUSE command returns success or failure immediately,
        # So sleeping for 'pause' command to complete
        sleep $a{-seconds};
  }
  return $result;
}

###################################################
# configure_spectra
###################################################

=head1 configure_spectra()

Recall the Config file for the Test execition.
Note: The config file is present under C:\SPECTRA\CONFIG

Arguments:

    -config
        config file name to be set on the spectra system;

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    $obj->configure_spectra( -config "1-1.784" )

=cut

sub configure_spectra {
  my ($self, %args) = @_;
  my $sub = "configure_spectra()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -config => "" );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my $result = 0;

  if ( $self->cmd( -cmd => "CONFIGURE $a{ -config }" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to set the Configure file $a{-config}:\n:$self->{output}");
        return $result;
  }
  else {
        $logger->debug(__PACKAGE__ . ".$sub Success - Configuration $a{-config} applied on spectra...");
        $result = 1;
  }
	sleep 10; ## Allow some time for the Inet to Load the config on the Boards
  return $result;
}

###################################################
# start_exec
###################################################

=head1 start_exec()

Run the Test Script on the Spectra on the defined Mode.

Note: The script file is stored under the following Location for the Specified Protocols

=over 4

		SS7: C:\SPECTRA\SS7
		ISDN: C:\SPECTRA\ISDN
		X.25: C:\SPECTRA\X25
		ATM, M3UA, SUA and SCTP: C:\SPECTRA\SS7\TESTER

For MODE => SS7

=over 8

			SOFF (MODE OFF)
			SMON (MONITOR MODE)
			SCP  (SCP EMULATOR MO DE)
			TGEN (TCAP GENERATOR)
			STP  (STP EMULATOR)
			IGEN (ISUP/TUP GENERATOR)
			PROG (PROGRAMMERS MODE)
			GSM  (GSM GENERATOR)
			LVL 2(CVR TESTERS, LEVEL 2 TESTER)
			LVL 3(CVR TESTERS, LEVEL 3 TESTER)
			TUP  (CVR TESTERS, TUP TESTER)
			ISUP (CVR TESTERS, ISUP TESTER)
			TCAP (CVR TESTERS, ICAP TESTER)
			MAN  (CVR TESTERS, MANIPULATOR MODE)
			BATCH(CVR TESTERS, BATCH TEST BUILDER)
			SS7T (CVR TESTERS, SS7 TESTER)
			ATM T(ATM/SAAL LEVEL 2 TESTER)
			SCTPT(SCTP TESTER)
			M3UAT(M3UA TESTER)
			SUAT (SUA TESTER)
			SG   (SG EMULATOR MODE)

=back


For MODE => ISDN

=over 8

			IOFF (MODE OFF)
			IMON (MONITOR)
			CGEN (CALL GENERATOR)
			IPROG(PROGRAMMERS MODE)
			ITST (ISDN TESTER)

=back


For MODE => X.25

=over 8

			XOFF (MODE OFF)
			XMON (MONITOR)
			XTST (X.25 TESTER)
			XPROG(PROGRAMMERS MODE)

=back


=back

Arguments:

    -mode
        Mode in which the tests are to be executed
     -scripts
        Script to execute
     -timeout
        In seconds; defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * 1, on success
    * 0, otherwise

Examples:

     $obj->start_exec( -mode => $mode,
                           -script => $script, );

=cut

sub start_exec{
  my ($self, %args) = @_;
  my $sub = "start_exec()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my $result = 0;

  if ( $self->cmd( -cmd => "MODE $a{-mode} $a{-script}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to set the MODE to $a{-mode}:\n:$self->{output}");
        return $result;
  	}
  else {
	if ( $self->cmd( -cmd => "START" ) ) {
        	$logger->error(__PACKAGE__ . ".$sub Failed to START the script $a{-script}:\n:$self->{output}");
        	return $result;
        	}
	else {
        	$logger->debug(__PACKAGE__ . ".$sub Success - Started the $a{-script} on spectra...");
        	$result = 1;
	}
  }
  return $result;

}

###################################################
# stop_exec
###################################################

=head1 stop_exec()

Stop the Test Script running on the Spectra.

Arguments:

     -scripts
        Script to execute

Returns:

    * 1, on success
    * 0, otherwise

Examples:

     $obj->stop_exec( -script => $script, );

=cut

sub stop_exec{
  my ($self, %args) = @_;
  my $sub = "stop_exec()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my $result = 0;

  $logger->debug(__PACKAGE__ . ".$sub Result file format specified --> $a{-fileFormat}");

  if ( $self->cmd( -cmd => "STOP" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to STOP the SCRIPT => $a{ -script }:\n:$self->{output}");
        return $result;
  }
  else {
        if ( $self->cmd( -cmd => "PRINT_CAPTURE $a{-script}" ) ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to Capture the Result for the script $a{-script}:\n:$self->{output}");
                return $result;
        }
	else {
        	$logger->debug(__PACKAGE__ . ".$sub Success - Result captured for the SCRIPT => $a{-script}...");
        	$result = 1;
	}
  }
  
  if ($a{-fileFormat} eq 'E') {
      $logger->debug(__PACKAGE__ . ".$sub Creating result file in expanded format as well");
      my $newFileName = "$a{-script}" . 'e';
      if ( $self->cmd( -cmd => "PRINT_CAPTURE  $a{-fileFormat} $newFileName" ) ) {
          $logger->error(__PACKAGE__ . ".$sub Failed to Capture the Result in expanded format for the script $a{-script}:\n:$self->{output}");
          return 0;
      } else {
          $logger->debug(__PACKAGE__ . ".$sub Success - Result captured in expanded format as well for the SCRIPT => $a{-script}...");
          $logger->debug(__PACKAGE__ . ".$sub File name is --> $newFileName");
      }
  }

  return $result;
}


###################################################
# start_spectra_loader
###################################################

=head1 start_spectra_loader()

Stop the Test Script running on the Spectra.

Arguments:

     -scripts
        Script to execute

Returns:

    * 1, on success
    * 0, otherwise

Examples:

     SonusQA::Inet::start_spectra_loader(-ip => $inet_ip);

=cut

sub start_spectra_loader{
  my (%args) = @_;
  my $sub = "start_spectra_loader()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $t;
  my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );


        my $batchFile="C:\\WINDOWS\\start_spectra.bat";
        my $hostip = $a { -ip };
  	if ( $t = new Net::Telnet( Timeout => 15, Host => $hostip, Errmode => "return") ) {
        $logger->debug(__PACKAGE__ . ".$sub Connected to the INET $hostip...");
        }
        else {
        $logger->error(__PACKAGE__ . ".$sub Failed to CONNECT to the Inet windows PC");
        }

  	if ( $t->login( $hostuser, $hostpwd )) {
                $logger->error(__PACKAGE__ . ".$sub Failed to login into the Inet windows PC");
        }
        else {
                $logger->debug(__PACKAGE__ . ".$sub Success - Logged into the Inet PC...");
        }
        sleep 2; # Wait for login to happen
       
	if ( $t->cmd("$batchFile")) {
                $logger->error(__PACKAGE__ . ".$sub Spectra Loader already Running");
        }
        else {
                $logger->debug(__PACKAGE__ . ".$sub Success - Spectra Loader Started....");
        }
        sleep(8); # Wait for batch file to execute/load
        unless ($t->close) {
        $logger->error(__PACKAGE__ . ".$sub = Failed to Disconnect the Remote Host...");
        }
        $logger->debug(__PACKAGE__ . ".$sub = Successfully Disconnected from the Remote Host...");
  return 1;
}




###################################################
# copy_Result_File
###################################################

=head1 copy_Result_File()

Capture the Print Screen output of the Test Script executed and parse for the test result if Passed or Failed

Arguments:

     -scripts
        Script to execute

     -ip
        IP of the INET, this is required as the result file will be stored under C:\SPECTRA\Printlog and needs to be FTP'd from the Location C:\Inetpub\FTPROOT. This is a Forced Limitation from SPECTRA 

     -testid
        Test case ID

Returns:

    * 1, if the Test is passed
    * 0, if the Test fails

Examples:

     SonusQA::Inet::copy_Result_File( -script => $script, -ip => $inet_ip, -testid => $testid);

=cut

sub copy_Result_File {
  my (%args) = @_;
  my $sub = "copyResultFile()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my ($ftp, $testid, $t, $t_result, %a, $filename);
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
	$hostip = $a { -ip };
	$filename = $a {-script} . ".prt";
	$testid = $a { -testid};
  if ( $t = new Net::Telnet( Timeout => 15, Host => $hostip, Errmode => "return") ) {
        $logger->debug(__PACKAGE__ . ".$sub Connected to the INET $hostip..."); 
	}
        else {
        $logger->error(__PACKAGE__ . ".$sub Failed to CONNECT to the Inet windows PC");
        }

  if ( $t->login( $hostuser, $hostpwd )) {
                $logger->error(__PACKAGE__ . ".$sub Failed to login into the Inet windows PC");
        }
        else {
                $logger->debug(__PACKAGE__ . ".$sub Success - Logged into the Inet PC...");
        }

  if ( $t->cmd("cd $spectra_ftp_loc")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute the command cd $spectra_ftp_loc");
        }
        else {
        $logger->debug(__PACKAGE__ . ".$sub Success - executed the command cd $spectra_ftp_loc...");
        }

  if ( $t->cmd("del $filename")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute the command del $filename");
        }
        else {
        $logger->debug(__PACKAGE__ . ".$sub Success - executed the command del $filename...");
        }

  if ( $t->cmd("cd $result_loc")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute the command cd $result_loc");
        }
        else {
        $logger->debug(__PACKAGE__ . ".$sub Success - executed the command cd $result_loc...");
        }

  if ( $t->cmd("copy $filename $spectra_ftp_loc")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute the command copy $filename $spectra_ftp_loc");
        }
        else {
        $logger->debug(__PACKAGE__ . ".$sub Success - executed the command copy $filename $spectra_ftp_loc..");
        }

        unless ($t->close) {
        $logger->error(__PACKAGE__ . ".$sub = Failed to Disconnect the Remote Host...");
        }
        $logger->debug(__PACKAGE__ . ".$sub = Successfully Disconnected from the Remote Host...");

  if ( $ftp = Net::FTP->new("$hostip", Debug => 0) or print "Cannot connect to $hostip: $@")  {
        $logger->debug(__PACKAGE__ . ".$sub Connected to the FTP host...");
        }
        else {
        $logger->error(__PACKAGE__ . ".$sub Failed to CONNECT to the FTP host.......");
        }
  if ( $ftp->login("$hostuser","$hostpwd") or print "Cannot login ", $ftp->message  ) {
                $logger->debug(__PACKAGE__ . ".$sub Success - FTP into the system...");
        }
        else {
                $logger->error(__PACKAGE__ . ".$sub Failed to login using the FTP credential");
        }
  eval { `mkdir -p $new_loc` };
  if ($@) {
      $logger->error(__PACKAGE__ . ".$sub Couldn't create $new_loc: $@");
      return 0;
  }
  if ( $ftp->get("$filename", "$new_loc/$filename") or print "get failed ", $ftp->message ) {
        $logger->debug(__PACKAGE__ . ".$sub Success in getting the file");
        }
        else {
        $logger->error(__PACKAGE__ . ".$sub Failed to issue the get command");
        }

        unless ($ftp->quit) {
        $logger->error(__PACKAGE__ . ".$sub = Failed to Disconnect from the Remote Host...");
        }
        $logger->debug(__PACKAGE__ . ".$sub = Successfully Disconnected from the Remote Host...");

        my $r_file = "$new_loc/$filename";
	$t_result = 0;
        $logger->debug(__PACKAGE__ . ".$sub = Parsing the file $r_file for the Test Result...");

        open (FH, '<', $r_file) or print $!;

        while (defined(my $line = <FH>)) {
            if ($line =~ /Test Passed/) {
                $t_result = 1;
                $logger->debug("$filename => TEST PASSED ");
            }
            if ($line =~ /Test Failed/) {
                $t_result = 0;
                $logger->debug("$filename => TEST FAILED ");
            }
        }
        close FH;
return $t_result;
}


###################################################
# cmd
###################################################

=head1 cmd()

Execute command and verify its exit code

Arguments:

    -cmd
        Command to be executed; defaults to ""
    -timeout
        Command timeout, in seconds; defaults to $obj->{DEFAULTTIMEOUT} 
        which is 10 by default and is set at object's creation time
    -errormode
        Net::Telnet errmoode handler, defaults to "return"

Returns:

    Command exit code:
    * 0 - on success
    * error code - otherwise; -99 means command execution failure 
      (e.g., timeout, unexpected eof)

    Command's output (without the command itself and the closing prompt) 
    is returned in scalar variable $obj->{output}

Example:

    if ( my $exit_code = $obj->cmd( -cmd => "ls" ) ) {
        print "Command failure; exit code is: $exit_code\n";
    }

    print "Command output: $obj->{output}\n";

=cut

sub cmd {
  my ($self, %args) = @_;
  my $conn = $self->{conn};
  my $sub = "cmd()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -cmd => "",
			-timeout => $self->{DEFAULTTIMEOUT},
			-errmode => $conn->errmode, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  my @buffer;

  # Execute command
  #
  $logger->debug(__PACKAGE__ . ".$sub Executing '$a{-cmd}'");

  # discard all data in object's input buffer
  $self->{conn}->buffer_empty;

  $self->{output} = "";

  unless ( @buffer = $conn->cmd( -string => $a{-cmd}, -timeout => $a{-timeout}, -cmd_remove_mode => 0 ) ) {
    $logger->error(__PACKAGE__ . ".$sub Command execution failure for command '$a{-cmd}'");
    $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $conn->errmsg);
    $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
    return -1;
  }

  $self->{output} = join '', @buffer;
  $logger->debug(__PACKAGE__ . ".$sub Command output:\n$self->{output}");

  # Check command exit code
  #
  my $exit_code = -99;

  if ( $self->{output} =~ m/ISHELL: unable to evaluate/ ) {
	$logger->error(__PACKAGE__ . ".$sub Command '$a{-cmd}' failed:\n$self->{output}");
	return $exit_code;
  }

  unless ( $self->{output} =~ m/(.*)ReturnValue: 0x\w+,(-?\d+)\s*/s ) {
	$logger->error(__PACKAGE__ . ".$sub Command '$a{-cmd}' did not display return value:\n$self->{output}");
	return $exit_code;
  } else {
	$self->{output} = $1;
	$exit_code = $2;
	$logger->debug(__PACKAGE__ . ".$sub Command exit code is '$exit_code'");
  }

  if ( $exit_code ne "0" ) {
	$logger->error(__PACKAGE__ . ".$sub Command '$a{-cmd}' failed:\n$self->{output}");
  } else {
	$logger->debug(__PACKAGE__ . ".$sub Command executed successfully");
  }
  return $exit_code;
}


###################################################
# start_scripts
###################################################

=head1 start_scripts()

Start test scripts on Inet BATCH MODE

Arguments:

    -mode
        Mode in which the tests are to be executed
     -config
        Configuration file to be used to execute the tests
        Note: the configuration file has to be defined on the unit
     -scripts
        Scripts to execute; an array reference
     -timeout
        In seconds; defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * 1, on success
    * 0, otherwise

Examples:

     my @scripts = qw/ script1 script2  script3 /;

     $obj->start_scripts( -mode => $mode,
                           -config => $config,
                           -scripts => \@scripts, );

=cut

sub start_scripts {
  my ($self, %args) = @_;
  my $sub = "start_scripts()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );
  # Verify required arguments defined
  foreach (qw/ -mode -config -scripts /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  # When to kick off the tests on the Inet
  $a{-time} = strftime "%m/%d/%y", localtime(time + $self->{BATCH_SCRIPT_DELAY});
  $a{-date} = strftime "%H:%M:%S", localtime(time + $self->{BATCH_SCRIPT_DELAY});

  my $time = strftime "%m/%d/%y", localtime(time);
  my $date = strftime "%H:%M:%S", localtime(time);

  $logger->debug(__PACKAGE__ . ".$sub Local time: $date $time Test kick off time: $a{-date} $a{-time}");

  # New ID for the scripts
  $self->{ID} = "";
  my $ug = new Data::UUID();
  my $uuid = $ug->create_str();

  unless ( $self->_build_batch_script( %a, -file => "/tmp/$uuid-$self->{BATCH_SCRIPT}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to build batch file"); return 0;
  }

  foreach ( "STOP", "rm $self->{DIR}/$self->{BATCH_LOG}", "SET_DATE $date", "SET_TIME $time" ) {
        if ( $self->cmd( -cmd => "$_" ) ) {
          $logger->error(__PACKAGE__ . ".$sub A test setup action '$_' failed"); 
          return 0;
        }
  }

  unless ( $self->_upload_batch_script( %a, -local_file => "/tmp/$uuid-$self->{BATCH_SCRIPT}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to upload batch script"); return 0;
  }

  $self->{ID} = $uuid;
  $self->{SCRIPTS} = $a{-scripts};
  $logger->debug(__PACKAGE__ . ".$sub ID <- '$uuid' SCRIPTS <- '@{$a{-scripts}}'");

  $logger->debug(__PACKAGE__ . ".$sub Success");
  1;
}

###################################################
# test_results
###################################################

=head1 test_results()

Read test results from the Inet unit and pair them with the test list
Any old results are purged

Arguments:

    -scripts
        List of scripts to be matched with the list of script results; defaults to scriopts that were executed last
    -timeout
        In seconds; defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * number of test results, on success
    * 0, otherwise

     Resutls are returned in hash: $obj->{results} where the result
     for test <test> is stored in $obj->{results}{<test>}

Examples:

     my @scripts = qw/ script1 script2  script3 /;

     $obj->start_scripts( -mode => $mode,
                           -config => $config,
                           -tests => \@scripts, );

     if ( $obj->test_results( -tests => \@scripts, ) ) {
          foreach ( @scripts ) {
              print "Script: $_ Result: $obj->{results}{$_}\n";
          }
     }

=cut

sub test_results {
  my ($self, %args) = @_;
  my $sub = "test_results()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -scripts => $self->{SCRIPTS},
                        -timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -scripts /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  delete $self->{results}; # Reset results

  my $number_of_scripts = @{$a{-scripts}};
  unless ( $number_of_scripts ) {
        $logger->error(__PACKAGE__ . ".$sub The list of scripts is empty: '@{$a{-scripts}}'"); return 0;
  }
  $logger->debug(__PACKAGE__ . ".$sub scripts == '@{$a{-scripts}}'");

  unless ( $self->{ID} ) {
        $logger->warn(__PACKAGE__ . ".$sub Internal script batch ID not set; start_scripts() either not called or failed");
        my $ug = new Data::UUID();
        $self->{ID} = $ug->create_str();
  }
  my $uuid = $self->{ID};
  $logger->debug(__PACKAGE__ . ".$sub ID == '$uuid'");

  unless ( $self->_download_batch_log( -local_file => "/tmp/$uuid-$self->{BATCH_LOG}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to download batch log"); return 0;
  }

  my @results = ();
  unless ( @results = $self->_get_results_from_batch_log( -file => "/tmp/$uuid-$self->{BATCH_LOG}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Error parsing batch log or no results found"); return 0;
  }

  my $number_of_results = @results;

  if ( $number_of_scripts != $number_of_results) {
        $logger->error(__PACKAGE__ . ".$sub Can't match scripts with results: # of scripts ($number_of_scripts) different than # of results ($number_of_results)"); return 0;
  }

  my $i = 0;
  foreach ( @{$a{-scripts}} ) {
        $self->{results}{$_} = $results[$i++];
  }

  $logger->debug(__PACKAGE__ . ".$sub Success - number of resuls: $i");
  $i;
}



###################################################
# _upload_batch_script
###################################################

=head1 _upload_batch_script()

Uploads batch script to the Inet unit

Arguments:

    -local_file
        The absolute name
    -remote_file
        The absolute name; defaults to $self->{DIR}/$self->{BATCH_SCRIPT}
    -timeout
         In seconds; Defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * 1, on success
    * 0, otherwise

=cut

sub _upload_batch_script {
  my ($self, %args) = @_;
  my $sub = "_upload_batch_script()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -remote_file => "$self->{DIR}/$self->{BATCH_SCRIPT}",
			-timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -local_file -remote_file /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  return $self->_transfer_text_file( %a, -action => 'put' );
}

###################################################
# _download_batch_log
###################################################

=head1 _download_batch_log()

Copy the contents of the batch log from the Inet unit to a local file

Arguments:

    -local_file
        The absolute name
    -remote_file
        The absolute name; defaults to $self->{DIR}/$self->{BATCH_LOG}
    -timeout
        Defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

Returns:

    * 1, on success
    * 0, otherwise

=cut

sub _download_batch_log {
  my ($self, %args) = @_;
  my $sub = "_download_batch_log()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -remote_file => "$self->{DIR}/$self->{BATCH_LOG}",
			-timeout => $self->{DEFAULTTIMEOUT}, );
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -local_file -remote_file /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  # Pawel
  # Commented out due to the limited functionality of the Inet FTP server
  # return $self->_transfer_text_file( %a, -action => 'get' );

  if ( $self->cmd( -cmd => "cat $a{-remote_file}" ) ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to read batch log '$a{-remote_file}'");
        return 0;
  }

  unless ( open LOG, "> $a{-local_file}" ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to open local batch log '$a{-local_file}' for writing: $!"); return 0;
  }

  # Pawel
  # I've noticed that upload -> downlod of the same file was resulting with an extra new line at the end of the file
  chomp $self->{output};

  print LOG $self->{output};

  close LOG;

  $logger->debug(__PACKAGE__ . ".$sub Success");
  1;
}

###################################################
# _transfer_text_file
###################################################

=head1 _transfer_text_file()

Transfer a text file to/from the Inet unit

Arguments:

    -local_file
        The absolute name
    -remote_file
        The absolute name
    -action
        put or get
    -timeout
        Defaults to $obj->{DEFAULTTIMEOUT} which is 10 s by default

    Notes:
    FTP server on Inet appears to have limited functionality and fails 
    to execute the get command.

Returns:

    * 1, on success
    * 0, otherwise

=cut

sub _transfer_text_file {
  my ($self, %args) = @_;
  my $sub = "_transfer_text_file()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ( -host => $self->{OBJ_HOST},
			-user => $self->{OBJ_USER},
			-password => $self->{OBJ_PASSWORD},
			-timeout => $self->{DEFAULTTIMEOUT}, );
  if ( $self->{LOG_LEVEL} eq "DEBUG" ) { $a{-debug} = 1; } else { $a{-debug} = 0; }
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -host -user -password -local_file -remote_file -action /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  if ( $a{-action} ne "put" and $a{-action} ne "get" ) { $logger->error(__PACKAGE__ . ".$sub Invalid -action '$a{-action}'; expected put or get"); return 0; }

  my ($ftp, $cmd, $output, @output);

  # Connect
  unless ( $ftp = new SonusQA::Base( -obj_host => $a{-host}, -obj_user => $a{-user}, -obj_password => $a{-password}, 
									 -comm_type => 'FTP', DEFAULTTIMEOUT => $a{-timeout} ) ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to connect to $a{-host}\n$@");
	return 0;
  }
  $logger->debug(__PACKAGE__ . ".$sub FTP connection established");

  # Text transfer mode
  unless ( $cmd eq "ascii" and @output = $ftp->{conn}->cmd($cmd) ) { 
	$logger->error(__PACKAGE__ . ".$sub Failed to execute '$cmd'"); $ftp->DESTROY;
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $ftp->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $ftp->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $ftp->{sessionLog2}");
	return 0;
  } else {
	$output = join '', @output;
	$logger->debug(__PACKAGE__ . ".$sub Command output for command '$cmd':\n$output");
  }

  unless ( $output =~ /(^|\s+)200 Type set to A/s ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to change tranfer mode to ascii:\n$output"); $ftp->DESTROY; return 0;
  }

  # File transfer
  unless ( $cmd = "$a{-action} $a{-local_file} $a{-remote_file}" and @output = $ftp->{conn}->cmd($cmd) ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to execute '$cmd'"); 
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $ftp->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $ftp->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $ftp->{sessionLog2}");
	$ftp->DESTROY; return 0;
  } else {
	$output = join '', @output;
	$logger->debug(__PACKAGE__ . ".$sub Command output for command '$cmd':\n$output");
  }

  unless ( $output =~ /(^|\s+)200 PORT command successful.*\s+226 Transfer complete/s ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to transfer file:\n$output"); $ftp->DESTROY; return 0;
  } else {
	$logger->debug(__PACKAGE__ . ".$sub File transfer successful");
  }

  $ftp->DESTROY;

  $logger->debug(__PACKAGE__ . ".$sub Success");
  1;
}

###################################################
# _build_batch_script
###################################################

=head1 _build_batch_script()

Build batch mode file to execute test scripts

Arguments:

    -mode
        Predefined Inet mode used in the MODE section of a batch test set
    -config
        User defined Inet configuration used in the CONFIG section of a batch test set
    -tests
        List of test script names used in the MODE section of a batch test set
    -date
        Start date; format: mm/dd/yy
    -time
        Start time; format: hh:mm:ss
        Start date and start time specify when to start script execution
     -file
        Name of the file to be created

Returns:

    * 1, on success
    * 0, otherwise

=cut

sub _build_batch_script {
  my ($self, %args) = @_;
  my $sub = "_build_batch_script()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my %a = ();
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -mode -config -tests -date -time -file /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

  unless ( open SCRIPT, "> $a{-file}" ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to open batch script $a{-file} for writing: $!"); return 0;
  }

  my $first = 1;

  foreach ( @{$a{-tests}} ) {

		if ( $first ) {

			 print SCRIPT "
BATCH_BEGIN
MODE:$a{-mode},$_
START:ONCE;$a{-time},$a{-date}
CONFIG:$a{-config}
BATCH_END
";
			$first = 0;
		} else {

			print SCRIPT "
BATCH_BEGIN
MODE:$a{-mode},$_
CONFIG:$a{-config}
BATCH_END
";
		  }
	  }

  close SCRIPT;

  $logger->debug(__PACKAGE__ . ".$sub Success");
  1;
}

###################################################
# _get_results_from_batch_log
###################################################

=head1 _get_results_from_batch_log()

Read test result from batch log

Arguments:

    -log
        Batch log to parse; the full path

        Resutls are returned in hash: $obj->{results} where for test <test> $obj->{results}{<test>} is set to 0
        or 1 for fail and pass, respectively.

Returns:

    * a list of results, on success
    * empty list, otherwise

=cut

sub _get_results_from_batch_log {
  my ($self, %args) = @_;
  my $sub = "_get_results_from_batch_log()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my @results = ();

  my %a = ();
  if ( $self->{ID} ) { $a{-log} = "/tmp/$self->{ID}-$self->{BATCH_LOG}"; }
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -log /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return @results; } }

  unless ( open LOG, "< $a{-log}" ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to open batch log  $a{-log} for reading: $!"); return @results;
  }

  while ( local $_ = <LOG> ) {
	chomp;
	$logger->debug(__PACKAGE__ . ".$sub Line: $_");
	if ( /Result\s+:\s+Test\s+(\w.*\w)\s*$/ ) {
	  push @results, $1;
	  $logger->debug(__PACKAGE__ . ".$sub Result: $1");
	}
  }

  close LOG;

  $logger->debug(__PACKAGE__ . ".$sub Returning: '@results'");
  return @results;
}

###################################################
# _get_tests_from_batch_script
###################################################

=head1 _get_tests_from_batch_script()

Read test script names from batch script

Arguments:

    -batch
        Batch script to parse

Returns:

    * a list of scripts, on success
    * empty list, otherwise

=cut

sub _get_scripts_from_batch_script {
  my ($self, %args) = @_;
  my $sub = "_get_scripts_from_batch_script()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my @scripts = ();

  my %a = ();
  if ( $self->{ID} ) { $a{-batch} = "/tmp/$self->{ID}-$self->{BATCH_SCRIPT}"; }
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  $self->_info( -sub => $sub, %a );

  # Verify required arguments defined
  foreach (qw/ -batch /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return @scripts; } }

  unless ( open BATCH, "< $a{-batch}" ) {
	$logger->error(__PACKAGE__ . ".$sub Failed to open batch log  $a{-batch} for reading: $!"); return @scripts;
  }

  while ( local $_ = <BATCH> ) {
	chomp;
	$logger->debug(__PACKAGE__ . ".$sub Line: $_");
	if ( /MODE:\w+,(\S+)\s*$/ ) {
	  push @scripts, $1;
	  $logger->debug(__PACKAGE__ . ".$sub Script: $1");
	}
  }

  close BATCH;

  $logger->debug(__PACKAGE__ . ".$sub Returning: '@scripts'");
  return @scripts;
}

=head1 _info()

Prints debug level information about the arguments passed into the function
denoted by -sub argument.

Mandatory Arguments:
    -sub => <function name as string>
        Name of function to print the argument information on
            Valid values:   non-empty string
            Arg example:    -sub => "shelfDisconnect()"

Optional Arguments:
    remaining function arguments to print the information on in for <arg> => <arg value>

Returns:
    1 - if successful
    0 - otherwise

=cut


###################################################
# _info
###################################################

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "_info");

    unless ($args{-sub}) {
        $logger->error(__PACKAGE__ . "._info Argument \"-sub\" must be specified and not be blank. $args{-sub}");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$args{-sub} Entering $args{-sub} function");
    $logger->debug(__PACKAGE__ . ".$args{-sub} ====================");

    if ( $args{-sub} eq "cmd()" ) {
        foreach ( qw/ -cmd -timeout / ) {
            if (defined $args{$_}) {
                $logger->debug(__PACKAGE__ . ".$args{-sub}\t$_ => $args{$_}");
            } else {
                $logger->debug(__PACKAGE__ . ".$args{-sub}\t$_ => undef");
            }
        }
    } else {
        foreach ( keys %args ) {
            if (defined $args{$_}) {
                $logger->debug(__PACKAGE__ . ".$args{-sub}\t$_ => $args{$_}");
            } else {
                $logger->debug(__PACKAGE__ . ".$args{-sub}\t$_ => undef");
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$args{-sub} ====================");

    return 1;
}

###############################################################################

=head1 parse_capture_result()

Capture the Print Screen output of the Test Script executed and parse for the test result if Passed or Failed

Arguments:

     -filename
        Capture filename

     -inetip
        IP of the INET, this is required as the result file will be stored under C:\SPECTRA\Printlog and needs to be FTP'd from the Location C:\Inetpub\FTPROOT. This is a Forced Limitation from SPECTRA 

     -testid
        Test case ID

     -timeout (OPTIONAL)
        FTP timeout: default to 10 seconds ($self->{DEFAULTTIMEOUT})

     -inetId (OPTIONAL)
        Test case ID which is used as part of file name. By default it will be set to '00'

Returns:

    * 1, if the Test is passed
    * 0, if the Test fails

Examples:

    unless ( $inetObj->parse_capture_result(
                            '-filename' => "$InetData{testid}" . ".prt", # Capture filename
                            '-inetip'   => "$InetData{ip}",
                            '-testid'   => $InetData{testid},
                            '-timeout'  => 30,
                            '-inetId'     => '1-8'
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Test case \'$subName\' Result - FAILED");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Test Case Result - PASSED");

=cut

###################################################
sub parse_capture_result {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "parse_capture_result()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'filename', 'inetip', 'testid' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = ( '-timeout' => $self->{DEFAULTTIMEOUT}, '-inetId' => '00' );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    my ( $inetIp, $filename, $testId, $timeout, $sleeptime , $attempt);
    $filename = $a {'-filename'};
    $testId   = $a { '-testid' };
    $inetIp   = $a { '-inetip' };
    $timeout  = $a { '-timeout'};
    $sleeptime= $a {'-sleeptime'} || 5 ;
    $attempt  = $a {'-attempt'} || 5 ;

    #######################################################################
    # Login to INET as Administrator / spectra2
    # Copy the capture file from C:\SPECTRA\PRINTLOG to INET FTP directory
    #######################################################################
    my $errMode = sub {
        $logger->warn (__PACKAGE__ . ' *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error(__PACKAGE__ . '  INET ERROR: Timeout OR Error happened.');
        $logger->warn (__PACKAGE__ . ' *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        return 1;
    };

    my $administratorObj = new Net::Telnet( 
                            Timeout => $timeout,
                            Host    => $inetIp,
                            Prompt  => '/C\:.*\>/',
                            Errmode => $errMode,
                    );

    unless ( defined $administratorObj ) { 
        $logger->error(__PACKAGE__ . ".$subName:  Failed to CONNECT to the Inet windows PC");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Connected to the INET $inetIp...");
    
    sleep ($sleeptime) ; 
    my $success = 0 ;

    for (my $count=1 ; $count<=$attempt; $count++){
        unless ( $administratorObj->login( $hostuser, $hostpwd )) {
            $logger->error(__PACKAGE__ . ".$subName:  Failed to login into the Inet windows PC in $count attempt.");
            next ;
        }
        $success = 1 ;
        $logger->debug(__PACKAGE__ . ".$subName: <-- successfully made connection in $count attempt.");
        last ;
    }
    unless ($success) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to login into the Inet windows PC even after trying for $attempt attempts.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
        
   $logger->debug(__PACKAGE__ . ".$subName:  Success - Logged into the Inet PC...");

    my (@cmdList, $newFileName);

    if ($a{-fileFormat} eq 'E') {
        $newFileName = $filename;
        $newFileName =~ s/([0-9]+)/${1}e/g;
        @cmdList = (
            # Delete if capture file exists in INET FTP directory
            "del C\:\\Inetpub\\ftproot\\$filename",
            "del C\:\\Inetpub\\ftproot\\$newFileName",
            # Copy the capture file from C:\SPECTRA\PRINTLOG to INET FTP directory
            "copy \/Y C\:\\Spectra\\printlog\\$filename C\:\\Inetpub\\ftproot\\$filename",
            "copy \/Y C\:\\Spectra\\printlog\\$newFileName C\:\\Inetpub\\ftproot\\$newFileName",
        );
    } else {
        @cmdList = (
            # Delete if capture file exists in INET FTP directory
            "del C\:\\Inetpub\\ftproot\\$filename",
            # Copy the capture file from C:\SPECTRA\PRINTLOG to INET FTP directory
            "copy \/Y C\:\\Spectra\\printlog\\$filename C\:\\Inetpub\\ftproot\\$filename",
        );
    }
  
    my $promptString = $administratorObj->prompt;
    $administratorObj->prompt($promptString);

    foreach my $cmd ( @cmdList ) {
        unless ( $administratorObj->cmd( $cmd ) ) {
            if ( $cmd =~ /^del / ) {
                $logger->debug(__PACKAGE__ . ".$subName: cmd \'$cmd\' failed, maybe the file is not present, so continue . . .");
                next;
            }
            $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
            next;
        }
    }

    #$administratorObj->close;

    #######################################################################
    # FTP the Capture file from INET FTP directory to ATS server
    # ~/ats_user/logs/ directory
    #######################################################################
    # Create timestamp for INET capture file
    my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;

    my $local_dir  = "$ENV{HOME}" . '/ats_user/logs/';
    my $local_file = $local_dir . $filename . '_' . "$a{-inetId}" . '_' . $timestamp;

    my $ftpObj;
    unless ( $ftpObj = Net::FTP->new("$inetIp", Debug => 0) or print "Cannot connect to $inetIp: $@")  {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to CONNECT to the FTP host.......");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Connected to the FTP host...");

    unless ( $ftpObj->login("$hostuser","$hostpwd") or print "Cannot login ", $ftpObj->message  ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to login using the FTP credential");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success - FTP into the system...");

    unless ( $ftpObj->ascii() ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to set mode \'ascii\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success mode set to \'ascii\'");

    unless ( $ftpObj->get($filename) or print "get failed ", $ftpObj->message ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to issue the get command");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Success in getting the file");

    # move the capture file from current directory to
    # ~/ats_user/logs/ directory
    system("mv $filename $local_file");

    $self->{'InetLogFile'} = $local_file;
    $logger->debug(__PACKAGE__ . ".$subName:  Saved Inet Log File in the INET object " . $self->{'InetLogFile'} );

    #Copy the capture file which is in expanded format
    if ($a{-fileFormat} eq 'E') {
        unless ( $ftpObj->get($newFileName) or print "get failed ", $ftpObj->message ) {
            $logger->error(__PACKAGE__ . ".$subName:  Failed to issue the get command");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName:  Success in getting the file --> $newFileName");
        my $newLocalFile = "$local_file" . '\.' . 'expanded';

        # move the capture file from current directory to
        # ~/ats_user/logs/ directory
        $logger->debug(__PACKAGE__ . ".$subName: Renaming file from $newFileName to $newLocalFile");
        system("mv $newFileName $newLocalFile");

        $self->{'InetLogFileExpanded'} = $newLocalFile;
        $logger->debug(__PACKAGE__ . ".$subName:  Saved Inet Log File in the INET object " . $self->{'InetLogFileExpanded'} );
        $logger->debug(__PACKAGE__ . ".$subName: Deleting a file $newFileName from INET");
        my $delCmd = "del C\:\\Spectra\\printlog\\$newFileName";
        $administratorObj->cmd( $delCmd );
    }

    $administratorObj->close;

    unless ($ftpObj->quit) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to Disconnect from the Remote Host...");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName:  Successfully Disconnected from the Remote Host...");

    $logger->debug(__PACKAGE__ . ".$subName:  Success - FTP to \'get $filename\' from INET ($inetIp) to $local_dir");

    #######################################################################
    # Parse the capture file for PASS/FAIL
    #######################################################################
    $logger->debug(__PACKAGE__ . ".$subName:  Parsing the file $local_file for the Test Result...");

    open (FH, "$local_file") || print ("error opening $local_file: $!\n");

    while ( <FH> ) {
        my $line = $_;
        if ($line =~ /Test Passed/) {
            $result = 1; # PASS
            $logger->debug(__PACKAGE__ . ".$subName: Script $filename => TEST PASSED ");
            last;
        }
        elsif ($line =~ /Test Failed/) {
            $result = 0; # FAIL
            $logger->debug(__PACKAGE__ . ".$subName: Script $filename => TEST FAILED ");
            last;
        }
        else {
            next;
        }
    }

    close (FH);
    
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

=head1 check_Traffic_Loss()

Parse the INET Log file to determine the traffic loss

Arguments:

     -filename
        INET log file

Returns:

    * 0 if 0 Message Loss
    * Number of Messages lost if there is traffic loss (positive number)
    * -1 if any errors

Examples:

    $TrafficLoss=$inetObj->check_Traffic_Loss(
                            '-filename' => "$inetObj->{'InetLogFile'}", # INET log filename
                        ) )
    $logger->debug(__PACKAGE__ . ".$subName: Traffic Loss =$TrafficLoss");

=cut

###################################################
sub check_Traffic_Loss {

    my ( $self, %args ) = @_;
    my $subName = "check_Traffic_Loss()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    # Check Mandatory Parameters
    unless ( defined ( $args{'-filename'} ) ) {
          $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -filename is blank.");
          $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
          return -1;
    }

    my $local_file  = $args { '-filename'};

    $logger->debug(__PACKAGE__ . ".$subName:  Parsing the file $local_file for the traffic loss");

    unless(open (FH, "$local_file"))
    {
	$logger->error(__PACKAGE__ . ".$subName: Could not open the file");
	return -1;
    }

    my $line;
    my %Traffic=();

    while(<FH>)
    {
        $line = $_;
        chomp($line);
	if($line=~m/([TR]X)\s+(\d+)\s+(\d+)\s+(\w+\.\w+)\s+(\d-\d-\d)\s+(\d-\d-\d)/)
	{
		$logger->debug(__PACKAGE__ . ".$subName: File $local_file =>  TX/RX= $1, Link number= $2, Count= $3, Message = $4, OPC = $5, DPC= $6");
                $Traffic{$1}+=$3;

	}

    }
    close FH;

    my ($txrx, $count);
   
    #To help debugging
    while(($txrx, $count) =each %Traffic)
    {
	$logger->debug(__PACKAGE__ . ".$subName: File $local_file =>  TX/RX =  $txrx,  Count =  $count");
    }

    $logger->info(__PACKAGE__ . ".$subName: File $local_file =>  TX = " . $Traffic{"TX"} . ", RX= " . $Traffic{"RX"} );

    if($Traffic{"TX"} eq  $Traffic{"RX"})
    {
	$logger->info(__PACKAGE__ . ".$subName: No Traffic Loss");
        return 0;
    }
    elsif ($Traffic{"TX"} >  $Traffic{"RX"})
    {
	my $lost =0;
	$lost =$Traffic{"TX"} - $Traffic{"RX"};
	$logger->info(__PACKAGE__ . ".$subName: Traffic Loss = $lost"); 
	return $lost;
    }
    else
    {
	#RX count more than TX count not possible
	$logger->error(__PACKAGE__ . ".$subName: Could not figure out the traffic loss");
        return -1;
    }

}

=head1 checkTrafficReceived()

    This subroutine is used to check whether traffic is received on any link other 
    than a given link. If it receives traffic on any other link will return false else true.

Arguments:

     -filename
        INET log file
     -linkNum
         Array of Link numbers

Returns:

    * 0 If it receives traffic on a link other than given one.
    * 1 if otherwise.

Examples:

    $status=$inetObj->checkTrafficReceived('-filename' => "$inetObj->{'InetLogFile'}", 
                                           '-linkNum'   => ['02'],);
                                           
    $status=$inetObj->checkTrafficReceived('-filename' => "$inetObj->{'InetLogFile'}", 
                                           '-linkNum'   => ['01', '02', '03'],);                                           
=cut

###################################################
sub checkTrafficReceived {

    my ( $self, %args ) = @_;
    my $subName = "checkTrafficReceived()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    
    # Check Mandatory Parameters
    unless ( defined ( $args{-filename} ) ) {
        $logger->error(__PACKAGE__ . "$subName:  The mandatory argument for -filename is blank.");
        $logger->debug(__PACKAGE__ . "$subName: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ( defined ( $args{-linkNum} ) ) {
        $logger->error(__PACKAGE__ . "$subName:  The mandatory argument for -linkNum is blank.");
        $logger->debug(__PACKAGE__ . "$subName: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $localFile = $args { '-filename'};
    my @linkNums  = @{$args { '-linkNum'}};
    
    $logger->debug(__PACKAGE__ . "$subName: Checking for traffic flowing through links other than --> @linkNums");
    
    unless(open (FH, "$localFile")) {
        $logger->error(__PACKAGE__ . "$subName: Could not open the file");
        $logger->error(__PACKAGE__ . "$subName: Error Message --> $!");
        return 0;
    }
      
    $logger->debug(__PACKAGE__ . "$subName: Opening a $localFile is successful !!!!");
    
    my ($linkNum, $line);    
    my @fileContent = <FH>;
    
    foreach $linkNum (@linkNums) {    
        #Now check any other RX line contains traffic
        foreach $line (@fileContent) {
            chomp $line;
            if($line =~ m/RX\s+([0-9]+)\s+[0-9]+/) {
                unless (grep {$1 =~ /$_/} @linkNums) {                   
                    $logger->error(__PACKAGE__ . "$subName: Traffic is flowing through other link details as below,"); 
                    $logger->error(__PACKAGE__ . "$subName: Link --> $1"); 
                    $logger->error(__PACKAGE__ . "$subName: Line --> $line"); 
                    close FH;
                    return 0;
                }
            }    
        }
    }
    
    $logger->debug(__PACKAGE__ . "$subName: Traffic is not flowing through any other links"); 
    $logger->debug(__PACKAGE__ . "$subName: Verification successful !!!!");    
    close FH;
    
    return 1;
}


###############################################################################

=head1 execInetScript()

Execute the Inet script and parse the capture buffer for 'Test Passed/Failed',
return SUCCESS(1) if Inet testscript passed else return FAILURE(0)

Arguments:

     -inetObj
        Inet Object

     -inetData
        Inet data containing the following
        - Inet IP address
        - Inet Config script
        - Inet Mode
        - Inet Pause time
        - Inet Script execution time
        - TMS Test Case ID
     
Returns:

    * 1, if the Inet test script executed & passed
    * 0, otherwise

Examples:

    my %InetData = (
        ip       => $inetIp,
        config   => 'SGX2K-CH',
        mode     => 'LVL2',
        script   => '1-1',
        pause    => 5,     # seconds
        execTime => 20,    # seconds
        testid   => $TestId,
        sleeptime => 5,
        attempts => 5         
    );

    unless ($inetObj->execInetScript(
                                        '-inetData' => \%InetData,
                                    ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to execute Inet script ($InetData{script}) - Mode ($InetData{mode})";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: PASSED to execute Inet script ($InetData{script}) - Mode ($InetData{mode})");

=cut

###################################################
sub execInetScript {
###################################################
    my  ($self, %args ) = @_ ;

    my $subName = "execInetScript()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".tms195407");
    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub");

    # Checking mandatory args;
    foreach ( "inetData" ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %InetData = %{$args{'-inetData'}};

    # Checking mandatory INET data;
    foreach ( qw/ ip config mode script pause execTime testid / ) {
        unless ( defined ( $InetData{$_} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory INET data for \'$_\' has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $option;
    if (defined $InetData{fileFormat}) {
        $option = uc($InetData{fileFormat});
        $option =~ s/\s+//g;
    } else {
        $option = 'C';
    }

    # Lock the Spectra system keyboard
    unless ( $self->lock_keyboard() ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to Lock the Spectra system keyboard");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Locked the Spectra system keyboard");

    # Configure the Spectra system (i.e. Recall and Apply configuration),
    # By default takes config file from path - C:\SPECTRA\CONFIG
    unless ( $self->configure_spectra(
                            '-config' => $InetData{config},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to Configure the Spectra system:-- $InetData{config}");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        $self->unlock_keyboard();
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Configured the Spectra system:-- $InetData{config}");

    # Set the operational MODE of the Spectra system and
    # load the test suite (i.e. inet script).
    # for SS7 protocol the test suite are in path - c:\SPECTRA\SS7
    # START the loaded test suite.
    unless ( $self->start_exec(
                            '-mode'   => $InetData{mode},
                            '-script' => $InetData{script},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to set MODE ($InetData{mode}) or LOAD\/START test suite ($InetData{script}) i.e. Inet Script");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        $self->unlock_keyboard();
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: set MODE ($InetData{mode}) and LOAD\/START test suite ($InetData{script}) i.e. Inet Script");

    # PAUSE the ongoing telnet connection session for given time in seconds.
    unless ( $self->pause_spectra(
                            '-seconds' => $InetData{pause},
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to PAUSE Inet telnet connection session for $InetData{pause} seconds");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        $self->unlock_keyboard();
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: PAUSE Inet telnet connection session for $InetData{pause} seconds");

    # Allow the Inet to execute the test suite
    $logger->debug(__PACKAGE__ . ".$subName: Sleeping for $InetData{execTime} seconds, for test script to exec.\n");
    sleep $InetData{execTime}; # Allow the Inet to execute the test suite

    # STOP the test suite (i.e. Inet Script) running on the Spectra system and
    # save the content of capture buffer into the file in path c:\SPECTRA\PRINTLOG
    unless ( $self->stop_exec(
                            '-script'     => $InetData{testid},
                            '-fileFormat' => $option,
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to STOP Inet test suite file $InetData{script}. ");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        $self->unlock_keyboard();
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: STOP Inet test suite file $InetData{script}.");

    sleep 5; # sleep 5 seconds i.e. wait for capture file to be written

    # Unlock the Spectra system keyboard
    unless ( $self->unlock_keyboard() ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to Unlock the Spectra system keyboard");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Unlocked the Spectra system keyboard");

    # FTP & save the capture buffer file to ~/ats_user/logs
    # parse the capture buffer file for test suite (i.e. Inet script) result 'Test Passed' or 'Test Failed'
    unless ( $self->parse_capture_result(
                            '-filename'   => "$InetData{testid}" . ".prt", # Capture filename
                            '-inetip'     => "$InetData{ip}",
                            '-testid'     => $InetData{testid},
                            '-timeout'    => 30,
                            '-inetId'     => $InetData{script},
                            '-fileFormat' => $option,
			    '-sleeptime'  => $InetData{sleeptime},
                            '-attempts'   => $InetData{attempts}
                        ) ) {
        $logger->error(__PACKAGE__ . ".$subName: Test case \'$subName\' Result - FAILED");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0; # FAIL
    }
    $logger->debug(__PACKAGE__ . ".$subName: Test Case Result - PASSED");
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");

    return 1; # PASS
}


###############################################################################

=head1 keyboard_command()

The KEYBOARD commands that mimic local keyboard input

NOTE: Each KEYBOARD command accepts only one argument.

Arguments:

     -cmd
        The following are the command options:
        UP          - 'Up' arrow key
        DOWN        - 'Down' arrow key
        RIGHT       - 'Right' arrow key
        LEFT        - 'Left' arrow key
        HOME        - Home key
        END         - End key
        PGUP        - Page Up key
        PGDN        - Page Down key
        ENTER       - Enter key
        ESCAPE      - Esc key
        SPACEBAR    - Spacebar key
        BACKSPACE   - Backspace key
        PLUS        - + key
        MINUS       - - key
        F1          - F1 Setup function
        F2          - F2 Run function
        F3          - F3 Stats function
        F4          - F4 Alarms & Reports function
        F5          - F5 Print function
        F6          - F6 Edit function
        F7          - F7 Remote function
        F8          - F8 Tools function
        F9          - F9 Xamine function
        F10         - F10 Help function

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->keyboard_command(
                            '-cmd' => 'F8', # F8 Tools Function
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to executed Inet KEYBOARD command \'F8\'";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS executed Inet KEYBOARD command \'F8\'");

=cut

###################################################
sub keyboard_command {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "keyboard_command()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'cmd' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my @validKbCmds = qw(UP DOWN RIGHT LEFT HOME END PGUP PGDN ENTER ESCAPE SPACEBAR BACKSPACE PLUS MINUS F1 F2 F3 F4 F5 F6 F7 F8 F9 F10);
    my $cmdFoundFlag = 0;
    foreach (@validKbCmds) {
        if ( $_ eq $args{'-cmd'}) {
            $cmdFoundFlag = 1;
            last;
        }
    }

    unless ($cmdFoundFlag) {
        $logger->error(__PACKAGE__ . ".$subName:  Invalid keyboard command \'$args{'-cmd'}\' used.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    my %a = ( '-cmd' => '' );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    if ( $self->cmd( -cmd => 'KEYBOARD ' . uc($a{'-cmd'}) ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute KEYBOARD command \'$a{-cmd}\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed KEYBOARD command \'$a{-cmd}\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 keyboard_char_command()

The KEYBOARD CHAR command that transmits ASCII characters or character strings that mimic local keyboard input.

NOTE: Each KEYBOARD CHAR command accepts single character and character stings.

Arguments:

     -cmd
        The following are the command options:
        Single character
        OR
        Character string

        NOTE: Character strings are limited to 24 characters

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $cmd = 'MODE';
    unless ( $inetObj->keyboard_char_command(
                            '-cmd' => $cmd,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to executed Inet KEYBOARD CHAR command \'$cmd\'";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS executed Inet KEYBOARD CHAR command \'$cmd\'");

=cut

###################################################
sub keyboard_char_command {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "keyboard_char_command()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'cmd' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = ( '-cmd' => '' );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );
    my $cmdString = uc($a{'-cmd'});
    my $cmd = "KEYBOARD CHAR($cmdString)";

    if ( $self->cmd( -cmd => $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'${cmd}\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'${cmd}\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################


=head1 ss7_send_MSU()

The ss7_send_MSU transmits the given signal unit with given OPC, DPC and protocol

NOTE: Uses Inet Spectra API 'SEND_MSU' command, which emulates the "TRANSMIT MSU THROUGH LEVEL 3" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -signalUnit
         MSU you want to transmit.

     -opc
         Originiation Point Code in decimal or net-member-cluster format

     -dpc
         Destination Point Code in decimal or net-member-cluster format

     -protocol
         ANSI. RED, BLUE, WHITE, etc., of the MSU to send


Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_send_MSU(
                            '-signalUnit' => 'BLO',
                            '-opc'        => '1-1-1',
                            '-dpc'        => '1-2-1',
                            '-protocol'   => 'ANSI',
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to send MSU \'BLO\'.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS  - sent MSU \'BLO\'");

=cut

###################################################
sub ss7_send_MSU {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_send_MSU()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'signalUnit', 'opc', 'dpc', 'protocol', ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SEND_MSU ' . uc($a{'-signalUnit'}) . ', ' . uc($a{'-opc'}) . ', ' . uc($a{'-dpc'}) . ', ' . uc($a{'-protocol'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_send_link_SU()

The ss7_send_link_SU transmits the given signal unit with given OPC, DPC and protocol

NOTE: Uses Inet Spectra API 'SENDL_SU' command, which emulates the "TRANSMIT SU OUT SPECIFIED LINK" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number from which to send the signal unit.

     -signalUnit
         MSU you want to transmit.

     -opc
         Originiation Point Code in decimal or net-member-cluster format

     -dpc
         Destination Point Code in decimal or net-member-cluster format

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_send_link_SU(
                            '-link'       => 1,
                            '-signalUnit' => 'BLO-784',
                            '-opc'        => '1-1-1',
                            '-dpc'        => '1-2-1',
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to send MSU \'BLO-784\' on link 1.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - sent MSU \'BLO-784\' on link 1");

=cut

###################################################
sub ss7_send_link_SU {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_send_link_SU()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link', 'signalUnit', 'opc', 'dpc' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SENDL_SU ' . "$a{'-link'}" . ', ' . uc($a{'-signalUnit'}) . ', ' . uc($a{'-opc'}) . ', ' . uc($a{'-dpc'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_link_up()

The ss7_link_up automatically activates, within a normal proving period, the given link.

NOTE: Uses Inet Spectra API 'LINK_UP' command, which emulates the "LINK ACTIVATE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command activates.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_link_up(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to activate link($linkNumber) up.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - activate link($linkNumber) up.");

=cut

###################################################
sub ss7_link_up {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_link_up()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LINK_UP ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_link_up_emergency_align()

The ss7_link_up_emergency_align automatically activates emergency alignment procedure on the given link.

NOTE: Uses Inet Spectra API 'LINK_UP_E' command, which emulates the "LINK ACTIVATE" (EMERGENCY ALIGNMENT) command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command activates.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_link_up_emergency_align(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to emergency alignment link($linkNumber) up.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - emergency alignment link($linkNumber) up.");

=cut

###################################################
sub ss7_link_up_emergency_align {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_link_up_emergency_align()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LINK_UP_E ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_link_down()

The ss7_link_down automatically deactivates the given link.

NOTE: Uses Inet Spectra API 'LINK_DOWN' command, which emulates the "LINK DEACTIVATE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command deactivates.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_link_down(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to deactivate link($linkNumber) down.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - deactivate link($linkNumber) down.");

=cut

###################################################
sub ss7_link_down {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_link_down()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LINK_DOWN ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_link_inhibit()

The ss7_link_inhibit inhibits the given link by sending a Link Inhibit Message (LIN).

NOTE: Uses Inet Spectra API 'L_INHIBIT' command, which emulates the "LINK INHIBIT" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command inhibits.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_link_inhibit(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to inhibit link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - inhibit link($linkNumber).");

=cut

###################################################
sub ss7_link_inhibit {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_link_inhibit()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'L_INHIBIT ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_link_uninhibit()

The ss7_link_uninhibit uninhibits the given link by sending a Link Uninhibit Message (LUN).

NOTE: Uses Inet Spectra API 'L_UNINHIBIT' command, which emulates the "LINK UNINHIBIT" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command uninhibits.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_link_uninhibit(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to uninhibit link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - uninhibit link($linkNumber).");

=cut

###################################################
sub ss7_link_uninhibit {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_link_uninhibit()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'L_UNINHIBIT ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_linkset_up()

The ss7_linkset_up activates the given signaling linkset.

NOTE: Uses Inet Spectra API 'LSET_UP' command, which emulates the "LINKSET ACTIVATE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -linkset
         linkset number for which command activates.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linksetNumber = 1;
    unless ( $inetObj->ss7_linkset_up(
                            '-linkset' => $linksetNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to activate link($linksetNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - activate link($linksetNumber).");

=cut

###################################################
sub ss7_linkset_up {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_linkset_up()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'linkset' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LSET_UP ' . "$a{'-linkset'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_linkset_down()

The ss7_linkset_down deactivates the given signaling linkset.

NOTE: Uses Inet Spectra API 'LSET_DOWN' command, which emulates the "LINKSET DEACTIVATE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -linkset
         linkset number for which command deactivates.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linksetNumber = 1;
    unless ( $inetObj->ss7_linkset_down(
                            '-linkset' => $linksetNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to deactivate link($linksetNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - deactivate link($linksetNumber).");

=cut

###################################################
sub ss7_linkset_down {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_linkset_down()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'linkset' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LSET_DOWN ' . "$a{'-linkset'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_set_processor_outage()

The ss7_set_processor_outage creates a local processor outage for the given signaling link.

NOTE: Uses Inet Spectra API 'SET_PRC_OUT' command alerts the adjacent terminal by transmitting a Status Indicator-Processor Outage (SIPO) signal. The 'SET_PRC_OUT' command, which emulates the "SET LOCAL PROCESSOR OUTAGE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command sets a local processor outage.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_set_processor_outage(
                            '-linkset' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to set Local Processor Outage for the signaling link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - set Local Processor Outage for the signaling link($linkNumber).");

=cut

###################################################
sub ss7_set_processor_outage {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_set_processor_outage()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SET_PRC_OUT ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_clear_processor_outage()

The ss7_clear_processor_outage clears a local processor outage for the given signaling link.

NOTE: Uses Inet Spectra API 'CLR_PRC_OUT' command, which emulates the "CLEAR LOCAL PROCESSOR OUTAGE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         link number for which command clear a local processor outage.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $linkNumber = 1;
    unless ( $inetObj->ss7_clear_processor_outage(
                            '-linkset' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to Clear Local Processor Outage for the signaling link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - Clear Local Processor Outage for the signaling link($linkNumber).");

=cut

###################################################
sub ss7_clear_processor_outage {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_clear_processor_outage()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( 'link' ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'CLR_PRC_OUT ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_connect_vsp_to_stp()

The ss7_connect_vsp_to_stp connects the given Virtual Signaling Point (VSP) to the given Signaling Transfer Point (STP).

NOTE: Uses Inet Spectra API 'CON_VSP_SP' command, which emulates the "CONNECT VSP TO STP" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -vsp
         Virtual Signaling Point (VSP)

     -stp
         Signaling Transfer Point (STP)

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_connect_vsp_to_stp(
                            '-vsp' => $vsp,
                            '-stp' => $stp,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to connect VSP ($vsp) to STP ($stp).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - connect VSP ($vsp) to STP ($stp).");

=cut

###################################################
sub ss7_connect_vsp_to_stp {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_connect_vsp_to_stp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ vsp stp / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'CON_VSP_SP ' . uc($a{'-vsp'}) . ', ' . uc($a{'-stp'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_disconnect_vsp_from_stp()

The ss7_disconnect_vsp_from_stp disconnects the given Virtual Signaling Point (VSP) from the given Signaling Transfer Point (STP).

NOTE: Uses Inet Spectra API 'DISC_VSP_SP' command, which emulates the "DISCONNECT VSP FROM STP" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -vsp
         Virtual Signaling Point (VSP)

     -stp
         Signaling Transfer Point (STP)

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_disconnect_vsp_from_stp(
                            '-vsp' => $vsp,
                            '-stp' => $stp,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to disconnect VSP ($vsp) from STP ($stp).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - disconnect VSP ($vsp) from STP ($stp).");

=cut

###################################################
sub ss7_disconnect_vsp_from_stp {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "ss7_disconnect_vsp_from_stp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ vsp stp / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'DISC_VSP_SP ' . uc($a{'-vsp'}) . ', ' . uc($a{'-stp'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_connect_c_link()

The ss7_connect_c_link connects the virtual C-Links of the Inet Spectra system.

NOTE: Uses Inet Spectra API 'CONNECT_C' command, which emulates the "CONNECT C-LINK" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     None

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_connect_c_link() ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to connect virtual C-links of the Inet Spectra.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - connect virtual C-links of the Inet Spectra.");

=cut

###################################################
sub ss7_connect_c_link() {
###################################################

    my ( $self ) = @_;
    my $subName = "ss7_connect_c_link()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    my $cmd = 'CONNECT_C';
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 ss7_disconnect_c_link()

The ss7_disconnect_c_link disconnects the virtual C-Links of the Inet Spectra system.

NOTE: Uses Inet Spectra API 'DISCONN_C' command, which emulates the "DISCONNECT C-LINK" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     None

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->ss7_disconnect_c_link() ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to disconnect virtual C-links of the Inet Spectra.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - disconnect virtual C-links of the Inet Spectra.");

=cut

###################################################
sub ss7_disconnect_c_link() {
###################################################

    my ( $self ) = @_;
    my $subName = "ss7_disconnect_c_link()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    my $cmd = 'DISCONN_C';
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - SS7 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - SS7 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 send_ISDN_SU() - ISDN Tools

The send_ISDN_SU transmits the given ISDN signal unit on the given link. This API uses the given Service Access Point Identifier (SAPI) and Terminal Endpoint Identifier (TEI)

NOTE: Uses Inet Spectra API 'SEND_ISDNSU' command, which emulates the "TRANSMIT SU OUT SPECIFIED LINK" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number on which to send ISDN signal unit

     -signalUnit
         MSU to transmit

     -sapi
         Service Access Point Identifier (SAPI)

     -tei
         Terminal Endpoint Identifier (TEI)

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->send_ISDN_SU(
                            '-link'       => $linkNumber,
                            '-signalUnit' => $ISDN_MSU,
                            '-sapi'       => $sapi,
                            '-tei'        => $tei,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to send ISDN SU($ISDN_MSU) on link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - send ISDN SU($ISDN_MSU) on link($linkNumber).");

=cut

###################################################
sub send_ISDN_SU {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "send_ISDN_SU()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link signalUnit sapi tei / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SEND_ISDNSU ' . "$a{'-link'}" . ', ' . uc($a{'-signalUnit'}) . ', ' . uc($a{'-sapi'}) . ', ' . uc($a{'-tei'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - ISDN Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - ISDN Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 send_ISDN_linkcontrol_message() - ISDN Tools

The send_ISDN_linkcontrol_message transmits the given ISDN signal unit on the given link. This API uses the given Service Access Point Identifier (SAPI) and Terminal Endpoint Identifier (TEI)

NOTE: Uses Inet Spectra API 'LINK_CONTRL' command, which emulates the "TERMINAL LINK CONTROL" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number on which to send ISDN link control command signal

     -command
         Following are available link control command option:
             TEI_EST  - Establish TEI
             TEI_DISC - Disconnect TEI
             LINK_EST - Establish link
             LINK_DSC - Disconnect link

     -sapi
         Service Access Point Identifier (SAPI)

     -tei
         Terminal Endpoint Identifier (TEI)

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->send_ISDN_linkcontrol_message(
                            '-link'    => $linkNumber,
                            '-command' => $linkControlCmd,
                            '-sapi'    => $sapi,
                            '-tei'     => $tei,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to send ISDN link control command($linkControlCmd) on link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - send ISDN link control command($linkControlCmd) on link($linkNumber).");

=cut

###################################################
sub send_ISDN_linkcontrol_message {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "send_ISDN_linkcontrol_message()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link command sapi tei / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SEND_ISDNSU ' . "$a{'-link'}" . ', ' . uc($a{'-command'}) . ', ' . uc($a{'-sapi'}) . ', ' . uc($a{'-tei'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - ISDN Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - ISDN Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 send_BRI_command_msg() - ISDN Tools

The send_BRI_command_msg sends the Basic Rate Interface (BRI) command message (state) to set the link state for the ISDN Network Termination (NT) interface on the given link.

NOTE: Uses Inet Spectra API 'INFO_STATE' command, which emulates the "BASIC RATE INTERFACE COMMANDS" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -state
         The state option specifies which BRI command message to send for setting the Information State (IF) for the NT side.
         Following are available state option:
             DONTCARE - Bring link back into sync
             INFO0    - No line signal
             INFO2    - Continue BRI activation (NT-to-TE)
             INFO4    - Activate BRI (NT-to-TE)
             INFOX    - Take link out of sync

     -link
         The link number on which to send BRI command

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->send_BRI_command_msg(
                            '-state' => $state,
                            '-link'  => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to send BRI command state($state) on link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - send BRI command state($state) on link($linkNumber).");

=cut

###################################################
sub send_BRI_command_msg {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "send_BRI_command_msg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ state link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'INFO_STATE ' . uc($a{'-state'}) . ', ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - ISDN Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - ISDN Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_link_inservice()

The x25_link_inservice brings into service the given X.25 link.

NOTE: Uses Inet Spectra API 'LINK_IS' command, which emulates the "BRING LINK IN SERVICE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of link to bring into service

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_link_inservice(
                            '-link'  => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to bring X.25 link($linkNumber) in-service.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - X.25 link($linkNumber) in-service.");

=cut

###################################################
sub x25_link_inservice {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_link_inservice()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LINK_IS ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_link_outofservice()

The x25_link_outofservice takes out of service the given X.25 link.

NOTE: Uses Inet Spectra API 'LINK_OOS' command, which emulates the "TAKE LINK OUT OF SERVICE" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of link to take out of service

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_link_outofservice(
                            '-link'  => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to take X.25 link($linkNumber) out of service.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - X.25 link($linkNumber) out of service.");

=cut

###################################################
sub x25_link_outofservice {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_link_outofservice()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'LINK_OOS ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_pvc_reset()

The x25_pvc_reset resets the given Permanent Virtual Circuit (PVC) on the given X.25 link.

NOTE: Uses Inet Spectra API 'PVC_RESET' command, which emulates the "PVC RESET" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which PVC reset

     -pvc
         Permanent Virtual Circuit (PVC)

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_pvc_reset(
                            '-link' => $linkNumber,
                            '-pvc'  => $pvc,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to reset X.25 link($linkNumber) for PVC($pvc).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - reset X.25 link($linkNumber) for PVC($pvc).");

=cut

###################################################
sub x25_pvc_reset {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_pvc_reset()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link pvc / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'PVC_RESET ' . "$a{'-link'}" . ', ' . uc($a{'-pvc'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_pvc_restart()

The x25_pvc_restart restarts the given Permanent Virtual Circuit (PVC)s on the given X.25 link.

NOTE: Uses Inet Spectra API 'PVC_RESTART' command, which emulates the "PVC RESTART" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which PVCs restarts

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_pvc_restart(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to restart X.25 link($linkNumber) for PVCs.";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - restart X.25 link($linkNumber) for PVCs.");

=cut

###################################################
sub x25_pvc_restart {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_pvc_restart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'PVC_RESTART ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_svc_establish()

The x25_svc_establish establishes Switching Virtual Circuit (SVC)s on the given X.25 link.

NOTE: Uses Inet Spectra API 'SVC_EST' command, which emulates the "ESTABLISH A SVC CALL" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which SVCs establishes

     -svc
         The name assigned to an Switching Virtual Circuit(SVC) call

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_svc_establish(
                            '-link' => $linkNumber,
                            '-svc'  => $svc,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to establish X.25 link($linkNumber) for SVC($svc).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - establish X.25 link($linkNumber) for SVC($svc).");

=cut

###################################################
sub x25_svc_establish {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_svc_establish()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link svc / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    # cmd - 'SVC_EST LINK SVC'  - i.e. no comma between LINK & SVC
    # Reference - Spectra API Guide - Version 5.5 - Page 56
    my $cmd = 'SVC_EST ' . "$a{'-link'}" . ' ' . uc($a{'-svc'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_close_svc()

The x25_close_svc closes Switching Virtual Circuit (SVC)s on the given X.25 link.

NOTE: Uses Inet Spectra API 'CLOSE_SVC' command, which emulates the "CLOSE A SVC CALL" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which SVC closes

     -svc
         The name assigned to an Switching Virtual Circuit(SVC) call

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_close_svc(
                            '-link' => $linkNumber,
                            '-svc'  => $svc,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to close X.25 link($linkNumber) for SVC($svc).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - closed X.25 link($linkNumber) for SVC($svc).");

=cut

###################################################
sub x25_close_svc {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_close_svc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link svc / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    # cmd - 'CLOSE_SVC LINK SVC'  - i.e. no comma between LINK & SVC
    # Reference - Spectra API Guide - Version 5.5 - Page 56
    my $cmd = 'CLOSE_SVC ' . "$a{'-link'}" . ' ' . uc($a{'-svc'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_establish_all_svc()

The x25_establish_all_svc establishes all Switching Virtual Circuit (SVC)s on the given X.25 link.

NOTE: Uses Inet Spectra API 'EST_ALL_SVC' command, which emulates the "ESTABLISH ALL SVC CALLS" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which all SVC calls establishes

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_establish_all_svc(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to establish all SVC calls on link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - establish all SVC calls on link($linkNumber).");

=cut

###################################################
sub x25_establish_all_svc {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_establish_all_svc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'EST_ALL_SVC ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 x25_close_all_svc()

The x25_close_all_svc closes all Switching Virtual Circuit (SVC)s on the given X.25 link.

NOTE: Uses Inet Spectra API 'CLS_ALL_SVC' command, which emulates the "CLOSE ALL SVC CALLS" command under the F8 Tools option of the Inet Spectra system.

Arguments:

     -link
         The link number of the link on which closes all SVC calls

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    unless ( $inetObj->x25_close_all_svc(
                            '-link' => $linkNumber,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to close all SVC calls on link($linkNumber).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - close all SVC calls on link($linkNumber).");

=cut

###################################################
sub x25_close_all_svc {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "x25_close_all_svc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ link / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'CLS_ALL_SVC ' . "$a{'-link'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute (F8 - X.25 Tools) command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed (F8 - X.25 Tools) command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 set_date_time()

The set_date_time sets the Date & Time on Inet Spectra system.

NOTE: Uses Inet Spectra API 'SET_DATE' and 'SET_TIME' commands.

Arguments:

     -date
         The date in MM/DD/YY format

     -time
         The time in HH:MM:SS format

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $date = strftime "%m/%d/%y", localtime(time);
    my $time = strftime "%H:%M:%S", localtime(time);

    unless ( $inetObj->set_date_time(
                            '-date' => $date,
                            '-time' => $time,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to set date($date), time($time).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - set date($date), time($time).");

=cut

###################################################
sub set_date_time {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "set_date_time()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ date time / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SET_DATE ' . "$a{'-date'}";
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");

        $cmd = 'SET_TIME ' . "$a{'-time'}";
        if ( $self->cmd( -cmd => "$cmd" ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
        }
        else {
            $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
            $result = 1;
        }
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 reset_statistics()

The reset_statistics resets the given type of Spectra statistics.

NOTE: Uses Inet Spectra API 'RESET_STATS' command.

Arguments:

    Mandatory Argument:
         -statType
             The type of Spectra statistics

    Optional Argument:
         -resetType
             The reset type options are as follows:
             M - Master reset (link level statistics reset)
             G - Global reset (all levels for all links statistics reset)
             NOTE: default to (G) all statistics reset.

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $statType  = 'SS7ALL';
    my $resetType = 'G';
    unless ( $inetObj->reset_statistics(
                            '-statType'  => $statType,
                            '-resetType' => $resetType,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to reset statistics type($statType), reset type($resetType).";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - reset statistics type($statType), reset type($resetType).");

=cut

###################################################
sub reset_statistics {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "reset_statistics()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ statType resetType / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = (
        '-resetType' => 'G',
    );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'RESET_STATS ' . uc($a{'-statType'}) . ', ' . uc($a{'-resetType'});
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

=head1 formatCaptureScreen()

 The subroutine turns ON or OFF parameters appearing on the capture screen,
 eliminating the necessity of post-processing data from the saved compressed capture.
 i.e. formatting screen to set to display SS7/ISDN/X.25/SCTP protocol specific traffic.

 NOTE: Uses INET Spectra API 'SCREEN_FORMAT <STATE> <CHARACTERS>'

Arguments:

     -state
        The following are the STATE options:
        ON  - Turns on the corresponding column
              represented by a character or character string.
        OFF - Turns off the corresponding column
              represented by a character or character string.

     -column
        To turn ON/OFF following options for the COLUMN:
        M  - Display of the time (in 1 millisecond resolution).
        _M - Display of the date & time.
        D  - Dual screen mode.
        F  - Display of the inter-signal unit flag count.
        C  - Display of the count of identical messages consecutively transmitted/received.
        B  - Display of the BSN/FSN/BIB/FIB.
        O  - Display of the SIO/SF and DPC/OPC.
        L  - Display of the length indicator field of the signal unit.
        Y  - Display of the link type (as defined in level 1 parameter screen).
        p  - Toggle display of the DPC/OPC between name(s) and code(s).

Returns:

    * 1, on success
    * 0, otherwise

Examples:

    # ************************************************************
    # Do the Following to initialize INET capture screen options
    # For Complete testsuite
    # ************************************************************

    #========================================
    # Initialize INET capture screen options
    #========================================
    my @captureScreenOptions = (
        # Turn OFF - all INET capture screen options
        { column => '_M', state=> 'OFF' }, # Turn OFF - Display of Date & Time
        { column => 'M', state => 'OFF' }, # Turn OFF - Display of Time
        { column => 'D', state => 'OFF' }, # Turn OFF - Dual screen mode
        { column => 'F', state => 'OFF' }, # Turn OFF - Display of Inter-signal unit flag count
        { column => 'C', state => 'OFF' }, # Turn OFF - Display of Count of identical messages
        { column => 'B', state => 'OFF' }, # Turn OFF - Display of BSN/FSN
        { column => 'O', state => 'OFF' }, # Turn OFF - Display of SIO/SF and DPC/OPC
        { column => 'L', state => 'OFF' }, # Turn OFF - Display of length indicator field of SU
        { column => 'Y', state => 'OFF' }, # Turn OFF - Display of link type
        { column => 'P', state => 'OFF' }, # Turn OFF - Toggle display of DPC/OPC between name & code

        # Init only required INET capture screen options
        { column => '_M', state=> 'ON' },  # Turn ON  - Display of Date & Time
        { column => 'M', state => 'OFF' }, # Turn OFF - Display of Time
        { column => 'B', state => 'ON' },  # Turn ON  - Display of BSN/FSN
        { column => 'C', state => 'ON' },  # Turn ON  - Display of Count of identical messages
        { column => 'P', state => 'ON' },  # Turn ON  - Toggle display of DPC/OPC between name & code
    );

    foreach ( @captureScreenOptions ) {
        print ("\tINET capture screen option \'$_->{column}\', state being set \'$_->{state}\'\n");
        unless ( $InetObj->formatCaptureScreen(
                            '-state' => $_->{state}, # turn ON display/mode on capture screen
                            '-column' => $_->{column}, # Display of the time (in 1 millisecond resolution).
                        ) ) {
            $logger->error(__PACKAGE__ . " ======: FAILED to format INET Capture Screen for option \'$_->{column}\', state \'$_->{state}\'.");
            return 0;
        }
        $logger->debug(__PACKAGE__ . " ======: SUCCESS executed format INET Capture Screen for option \'$_->{column}\', state \'$_->{state}\'");
    }

    OR

    # ************************************************************
    # For test case specific requirement
    # ************************************************************
    unless ( $inetObj->formatCaptureScreen(
                            '-state' => 'ON', # turn ON display/mode on capture screen
                            '-column' => 'O', # Display of SIO/SF and DPC/OPC
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to format INET Capture Screen for option \'O\', state \'ON\'";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS executed format INET Capture Screen for option \'O\', state \'ON\'");

=cut

###################################################
sub formatCaptureScreen {
###################################################

    my ( $self, %args ) = @_;
    my $subName = "formatCaptureScreen()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL

    # Check Mandatory Parameters
    foreach ( qw/ state column / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a = ( '-state' => 'ON' );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( '-sub' => $subName, %a );

    my $cmd = 'SCREEN_FORMAT ' . uc($a{'-state'}) . ' ' . uc($a{'-column'});
    if ( $self->cmd( -cmd => $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed - executing SCREEN_FORMAT command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed SCREEN_FORMAT command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

=head1 reset_io()

The reset_io resets the given system I/O interface board.

NOTE: Uses Inet Spectra API 'RESET_IO' command.

Arguments:

    Mandatory Argument:
         -board
             board need to be reseted
Returns:

    * 1, on success
    * 0, otherwise

Examples:

    my $board  = 'board number';
    unless ( $inetObj->reset_io(
                            '-board'  => $board,
                        ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "FAILED to reset the given system I/O interface board";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$TestId: SUCCESS - the given system I/O interface board.");

=cut

###################################################

sub reset_io {

    my ( $self, %args ) = @_;
    my $subName = "reset_io()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my $result = 0; # FAIL
    # Check Mandatory Parameters
    unless ($args{-board}) {
        $logger->error(__PACKAGE__ . ".$subName:  Manditory argument \$args{-board} is empty or missing");
        return 0;
    }
    
    $self->_info( '-sub' => $subName, %args );

    my $cmd = 'RESET_IO ' . $args{-board};
    if ( $self->cmd( -cmd => "$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to execute command \'$cmd\'");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$subName:  Success - executed command \'$cmd\'");
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [$result]");
    return $result;
}

###############################################################################

1;
