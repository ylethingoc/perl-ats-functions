package SonusQA::MGTS;

=head1 NAME

SonusQA::MGTS - SonusQA MGTS class

=head1 SYNOPSIS

use ATS;

or:

use SonusQA::MGTS;

=head1 DESCRIPTION

SonusQA::MGTS provides an interface to MGTS by extending SonusQA::Base class and Net::Telnet.

=head1 AUTHORS

The <SonusQA::MGTS> module is written by Pawel Nowakowski <pnowakowski@sonusnet.com>
and updated by Hefin Hamblin <hhamblin@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.


=head1 METHODS

=head2 new()

One MGTS object should be used per shelf (i2000) or MGTS user (p400 or m500)

NOTE: The i2000 uses a central MGTS Solaris server and each shelf is a separate
      item of hardware which only one user can use at any one time. The i2000
      MGTS server must connect with the shelf before any shelf commands can be
      executed.

      The p400 has the MGTS Linux admin server and MGTS boards contained within the
      same hardware chassis. The p400 can contain up to 9 boards and the system is
      multi-user where a user can use one or more boards. Only one user can use a
      board at any one time. The boards are connected to and 'locked-out' during
      the download of the MGTS Network-shelf Assignment.

      The m500 is similar to the p400 but can contain up to 16 boards.

=over

=item Mandatory Arguments:
    -obj_host => <MGTS server IP address or Hostname>
        MGTS server (IP address of MGTS server or hostname if MGTS server is under DNS)
            Valid values:   non-empty string
            Arg example:    -obj_host => "10.31.200.60"   

    -obj_user => <MGTS user name string>
        MGTS user account name
            Valid values:   non-empty string
            Arg example:    -obj_user => "anmgtsuser" 

    -obj_password => <password string>
        MGTS user password
            Valid values:   non-empty string
            Arg example:    -obj_password => "mgtspassword"

    -shelf => <shelf name string>
        Shelf to connect to. Only one MGTS shelf is allowed per MGTS object instance.
        For i2000:
            This is the hostname of the MGTS shelf
        For P400 or M500:
            This is the hostname of the MGTS server (which may be the same value
            as specified in -obj_host argument if DNS used)

            Valid values:    non-empty string.
            Arg example:     -shelf => "mgts-p400-1"

    -display => <display value>
        X-server DISPLAY settings which must be unique per MGTS object created
            Valid values:   non-empty string
            Arg example:    -display => ":3.0"

    -protocol => <MGTS protocol string>
        MGTS signalling protocol variant;
            Valid values:   "ANSI-M3UA",
                            "ANSI-SS7",
                            "ATT-SS7",
                            "AUSTRL-SS7",
                            "CCITT-SS7",
                            "CHINA-SGT",
                            "CHINA-SS7",
                            "ETSI-SS7-3",
                            "ETSI-SS7-4",
                            "GERMN-SS7",
                            "INDIA-SS7",
                            "ITALY-SS7",
                            "ITU-M3UA",
                            "JAPAN-SGT",
                            "JAPAN-SS7",
                            "NATISDN2P",
                            "PNOISC-SS7",
                            "Q931",
                            "SPAIN-SS7",
                            "UK-SS7",
                            "WHITE-SS7"
            Arg example:    -protocol => "WHITE-SS7"  

=item Optional Arguments:

    -obj_commtype => <comm type>
        Communication method to connect to MGTS server
            Valid values: "TELNET" or "SSH"
            Default value: "SSH"
            Arg example: -obj_commtype => "TELNET"

    -shell => <shell name>
        Unix shell for MGTS connection interface
            Valid values:   "csh", "tcsh", "sh", "bash", or "ksh";
            Default value:  "ksh"
            Arg example:    -shell => "bash"   

    -server_version => <server version string>
        MGTS server software version
            Valid values:   10 or 15
            Default value:  15
            Arg example:    -server_version => 10   

    -shelf_version => <shelf version string>
        MGTS shelf version
            Valid values:   "m500", "p400" or "i2000"
            Default value:  "p400"
            Arg example:    -shelf_version => "i2000"

    -assignment => <MGTS Network-Shelf Assignment string>
        MGTS Network-Shelf Assignment that is already loaded on MGTS shelf/board
        and needs to be re-connected to;
            Valid values:   string
            Default value:  "" (empty string)
            Arg example:    -assignment => "mgts1_c7n1_LAUREL"
            NOTE: A new assignment to download is specified in the downloadAssignment() fn.

    -force => <0 or 1>
        Force disconnect from a shelf before connecting;
            Valid values:   0 (don't force) and 1 (force).
            Default Value:  1 (force)
            Arg example:    -force => 0

    -log_level => <log level string>
        Controls the amount of displayed information;
            Valid values:   "DEBUG", "INFO", "WARN", "ERROR" or "FATAL"
            Default value:  defaults to an environment variable LOG_LEVEL or to
                            "INFO" when the variable not defined
            Arg example:    -log_level => "DEBUG"

    -defaulttimeout => <timeout value>
        Default timeout for commands in seconds; defaults to 10
            Valid values:   positive integer > 0
            Default value:  10 (seconds)
            Arg example:    -defaulttimeout => 20

    NOTE: All arguments specified on object instantiation i.e. $mgtsObj->new,
          will be converted to object variables of the form:
            $mgtsObj->{<arg name in uppercase less the '-'}

          e.g. arg -defaulttimeout  with a value of 10 will become
               $mgtsObj->{DEFAULTTIMEOUT}

          Some of the default values for these object variables are defined in
          the doInitialization() fn and are then processed in the new() fn defined
          in SonusQA::Base

=item Returns:

    * An instance of the SonusQA::MGTS class, on success
    * undef, otherwise

=item Examples:

    # For a P400 or M500  system
    my $mgtsObj = new SonusQA::MGTS (-obj_host => 10.31.200.60,
                                     -obj_user => mgtsuser1,
                                     -obj_password => mgtsuser1,
                                     -shelf => mgts-P400-1,
                                     -display => :2.0,
                                     -protocol => WHITE-SS7);

=back

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy  );
use SonusQA::Base;
use SonusQA::UnixBase;
use Module::Locate qw ( locate );
use File::Basename;
use File::Temp qw ( tempfile );
use Net::xFTP;
use Data::Dumper;
use Net::Ping;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::SOCK;
use SonusQA::TRIGGER;
use SonusQA::MGTS::MGTSHELPER;
our $VERSION = "1.0";

use vars qw($self);

# Inherit the two base ATS Perl modules SonusQA::Base and SonusQA::UnixBase
# The functions in this MGTS Perl module extend these two modules.
# Methods new(), doInitialization() and setSystem() are defined in the inherited
# modules and the latter two are superseded by the co-named functions in this module.
our @ISA = qw(SonusQA::Base SonusQA::UnixBase SonusQA::MGTS::MGTSHELPER SonusQA::TRIGGER);

=head2 doInitialization()

    This function is called by Object new() method. Do not need to call it explicitly. 

=cut

sub doInitialization {
    my($self, %args)= @_;
    
    my($temp_file);
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{COMM_TYPE} = "SSH";
    
    $self->{DEFAULTTIMEOUT} = 30;
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%>] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{VERSION} = "UNKNOWN";
    $self->{LOCATION} = locate __PACKAGE__;
    my $package_name = $self->{TYPE};
    $package_name =~ s/\:\:/\//;
    $self->{LOCATION} =~ s/$package_name\.pm//;
  
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
    my $arg_error = 0;
    
    # Check existence of mandatory variables specified when creating the object (new())
    # NOTE: the new() fn is inherited from the SonusQA::Base package and the following
    #       arguments are checked for existence within that function:
    #           -obj_host
    #           -obj_user
    #           -obj_password
    # Mandatory arguments to be checked are:
    #           -shelf
    #           -display
    #           -protocol
    ## Check for mandatory parameters.
    foreach ( qw/ -shelf -display -protocol / ) {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".new (doInitialization) Mandatory \"$_\" parameter not provided or is blank");
            $arg_error++;
        }
    }
    
    # Remove leading whitechars
    foreach ( qw/ -shelf -display -protocol -assignment / ) {
        $args{$_} =~ s/^\s+// if $args{$_};
    }
    
    # Convert shelf_version to lowercase (if defined)
    $args{-shelf_version} = lc($args{-shelf_version}) if $args{-shelf_version};
    
    # Convert log_level to uppercase (if defined)
    $args{-log_level} = uc($args{-log_level}) if $args{-log_level};

    # Convert log_level to uppercase (if defined)
    $args{-obj_commtype} = uc($args{-obj_commtype}) if $args{-obj_commtype};
    
    # Check defined optional arg values
    if ((defined $args{-server_version}) && (($args{-server_version} != 10 )&&($args{-server_version} != 15))) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-server_version\" argument has invalid value of \"$args{-server_version}\". Must be 10 or 15.");        $arg_error++;
    }
    if ((defined $args{-shelf_version}) && (($args{-shelf_version} ne "p400" )&&($args{-shelf_version} ne "m500")&&($args{-shelf_version} ne "i2000")&& ($args{-shelf_version} ne "softshelf"))) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-shelf_version\" argument has invalid value of \"$args{-shelf_version}\". Must be \"p400\", \"m500\" or \"i2000\".");
        $arg_error++;
    }
    else {
        $self->{SHELF_VERSION} = $args{-shelf_version};
    }
    if ((defined $args{-force}) && (($args{-force} < 0 )||($args{-force} > 1))) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-force\" argument has invalid value of \"$args{-force}\". Must be 0 or 1.");
        $arg_error++;
    }
    if ((defined $args{-log_level}) && (($args{-log_level} ne "INFO" ) &&
                                        ($args{-log_level} ne "DEBUG") &&
                                        ($args{-log_level} ne "ERROR") &&
                                        ($args{-log_level} ne "WARN") &&
                                        ($args{-log_level} ne "FATAL"))) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-log_level\" argument has invalid value of \"$args{-log_level}\". Must be either INFO, DEBUG, ERROR, WARN or FATAL.");
        $arg_error++;
    }
    if ((defined $args{-defaulttimeout}) && ($args{-defaulttimeout} <= 0 )) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-defaulttimeout\" argument has invalid value of \"$args{-defaulttimeout}\" seconds. Must be greater than 0.");
        $arg_error++;
    }
    if ((defined $args{-obj_commtype}) && ($args{-obj_commtype} ne "TELNET") && ($args{-obj_commtype} ne "SSH")) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-obj_commtype\" argument has invalid value of \"$args{-obj_commtype}\". Must be either TELNET or SSH.");
        $arg_error++;
    }
    if ((defined $args{-assignment}) && ($args{-assignment} eq "")) {
        $logger->error(__PACKAGE__ . ".new (doInitialization) Optional \"-assignment\" argument cannot be blank.");
        $arg_error++;
    }
    
    if ( $arg_error ) {
        die("FATAL ERROR: $arg_error error(s) with MGTS::new() function arguments. Exiting MGTS.pm ...\n");                  
    }
    # Used to store command output
    $self->{OUTPUT} = "";
    
    # Default Unix shell
    # $self->{SHELL} = "ksh";

    $self->{SHELL} = "csh";

    # MGTS specific data
    
    # Protocol variant specific configuration files:
    $self->{CONFIG_FILE} = {  "ANSI-M3UA"   => "mgts_am3",
                              "ANSI-SS7"    => "mgts_bel",
                              "ATT-SS7"     => "mgts_att",
                              "AUSTRL-SS7"  => "mgts_aui",
                              "CCITT-SS7"   => "mgts_cit",
                              "CHINA-SS7"   => "mgts_chi",
                              "CHINA-SGT"   => "mgts_cst",
                              "ETSI-SS7-3"  => "mgts_ei3",
                              "ETSI-SS7-4"  => "mgts_ei4",
                              "GERMN-SS7"   => "mgts_gei",
                              "INDIA-SS7"   => "mgts_ind",
                              "ITALY-SS7"   => "mgts_its",
                              "ITU-M3UA"    => "mgts_im3",
                              "JAPAN-SGT"   => "mgts_jst",
                              "JAPAN-SS7"   => "mgts_jpn",
                              "NATISDN2P"   => "mgts_ni2p",
                              "PNOISC-SS7"  => "mgts_iup",
                              "Q931"        => "mgts_931",
                              "SPAIN-SS7"   => "mgts_spi",
                              "UK-SS7"      => "mgts_uki",
                              "WHITE-SS7"   => "mgts_whi",
                           };
    
    $self->{MGTS_DATA} = ""; # To store the value of environment variable MGTS_DATA
  
    # To keep track what protocol is being used
    $self->{PROTOCOL} = $args{-protocol};
    
    # To store current assignment
    $self->{ASSIGNMENT} = "";
    
    # Directory to store MGTS logs
    # Will be created if does not exist
    $self->{LOG_DIR} = "~/Logs";
        
    $self->{SERVER_VERSION} = 15; # values: 10, 15
    
    unless ( defined ($self->{SHELF_VERSION}) || $self->{SHELF_VERSION} eq "" ) {
        $self->{SHELF_VERSION} = "p400"; 
    }
 
    # Default forceful MGTS shelf disconnect to 1 (force).
    $self->{FORCE} = 1;
    
    $self->{SHELF} = "";
    
    # Flag to indicate whether MGTS shelf is connected for use with shelfConnect(),
    # shelfDisconnect() and endSession(). 0 = disconnected, 1 = connected.
    $self->{SHELF_CONNECTED} = 0;
    
    # Flag to indicate whether MGTS session exists. Activated in startSession()
    # and deactivated in endSession(). 
    $self->{SESSION_ACTIVE} = 0;

    if ( $args{-fish_hook_port} ) {
        $self->{FISH_HOOK_PORT} = $args{-fish_hook_port};
    } 

    $self->{scpe} = undef;
}

=head2 setSystem()

    This subroutine sets the system information and prompt.

=cut

sub setSystem {
    my($self, %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    my($cmd, @output);
    
    my $conn = $self->{conn};

    $logger->debug(__PACKAGE__ . ".setSystem Starting shell $self->{SHELL}");
        
    my $shell = lc($self->{SHELL});
    
    if ( $shell eq "sh" or $shell eq "bash" or $shell eq "ksh" ) {
        $cmd = "PS1='ats_auto_prompt> '";
        
    } elsif ( $shell eq "csh" or $shell eq "tcsh" ) {
        $cmd = "set prompt=('ats_auto_prompt> ')";
        
    } else {
        fail "Unsupported shell: $shell";
    }
    
    # Verify the shel1 supported on the system
    @output= $conn->cmd( -string           => "$shell -c 'echo shell_present'",
                         -cmd_remove_mode  => 0,
                         -errmode          => "return",
                         -prompt           => '/[^\']shell_present\s/',
                         -timeout          => 5, )
      or fail "Shell $shell not supported on the system: " . $conn->lastline . "\n";
    
    # Start the shell
    $conn->put("$shell\n");
    
    # Give enough time to set the shell, before firing next command
    $conn->waitfor(Match => '/\./', Timeout=>1 );

    $conn->prompt('/ats_auto_prompt> $/');
    
    @output = $conn->cmd( -string           => "$cmd",
                          -cmd_remove_mode  => 0,
                          -prompt           => '/[^\']ats_auto_prompt> $/',
                          -errmode          => "return",
                          -timeout          => 5, )
      or fail "Failed to set prompt: " . $conn->lastline . "\n";
  
  
    unless ( $self->startSession( %args ) ) {
        $logger->fatal(__PACKAGE__ . ".setSystem Failed to start MGTS session");
        die("Unable to start MGTS session. Exiting...");
    }
    if ( $self->{FISH_HOOK_PORT} ) {
        $logger->debug(__PACKAGE__ . ".setSystem Writing fishHook");
        unless ( $self->writeFishHookToDatafiles ) {
            $logger->warn(__PACKAGE__ . ".setSystem Unable to write fishHook");
        }
    }
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head2 _checkShelfVars()

Checks the MGTS object shelf variables are defined and not blank and reports errors if
any of them are. The shelf variables are:
    $mgtsObj->{SHELF}
    $mgtsObj->{SHELF_VERSION}
    $mgtsObj->{SERVER_VERSION}

This function will be called from other functions defined by -sub

=over

=item Mandatory Arguments:
    -sub => <function name as string>
        Name of function where shelf vars are to be checked from
            Valid values:   non-empty string
            Arg example:    -sub => "shelfDisconnect()"   

=item Returns:
    1 - if successful
    0 - otherwise

=back

=cut

sub _checkShelfVars {
    my ($self, %args) = @_;
    my $sub = "_checkShelfVars()";
    my @info = %args;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    unless ($args{-sub}) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-sub\" must be specified and not be blank. '$args{-sub}'");
        return 0;
    } 
    
    # Verify required MGTS object variables defined
    foreach (qw/ SHELF SHELF_VERSION SERVER_VERSION /) {
        unless ( $self->{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub MGTS object variable \$self->{$_} is not defined or blank");
            return 0;
        }
    }
  
    return 1;
}


=head2 _getShelfPasmId()

Figure out the shelf ID for use with the MGTS PASM Scripting commands such as shelfPASM

    Format:
        P400 or M500   - <mgts P400/M500 server hostname>+<mgts assignment name>

        i2000 - <mgts shelf hostname>

=over

=item Returns:
    Shelf ID as a string

=back

=cut

sub _getShelfPasmId {
    my ($self) = @_;
    
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
        return "$self->{SHELF}+$self->{ASSIGNMENT}";
    } else {
        return "$self->{SHELF}";
    }
}


=head2 cmd()

Executes a command on the MGTS and verifies its exit code

=over

=item Mandatory Arguments:
    -cmd => <cmd string>
        Command to be executed on MGTS shelf;
            Valid values:   non-empty string
            Arg example:    -cmd => "ls -ltr"

=item Optional Arguments:
    -timeout => <timeout integer>
        Command timeout, in seconds;
            Valid values:   positive integer > 0
            Default value:  $mgtsObj->{DEFAULTTIMEOUT} which is set at object's instantiation
            Arg example:    -timeout => 20

    -errormode => <"die" or "return">
        Net::Telnet errmoode handler
            Valid values:   "die" or "return".
            Default value:  "return"
            Arg example:    -errormode => "return"

    -exp_exit_code => <expected exit code integer>
        Expected exit code of executed command specified by -cmd argument
            Valid values:   integer
            Default value:  0 (UNIX cmd line success is normally 0)
            Arg example:    -exp_exit_code => 1

=item Returns:

    Command exit code:
    *  0 - success (as cmd exit code matches expected exit code (normally 0))
    * -1 - means command execution failure (e.g., timeout, unexpected eof, missing or invalid args)
    * otherwise exit code of executed command

    Command's output (without the command itself and the closing prompt) is returned in scalar variable $mgtsObj->{OUTPUT}

=item Example:

    if ( my $exit_code = $mgtsObj->cmd( -cmd "hostname", -timeout => 5 ) ) {
        print "Command failure; exit code is: $exit_code\n";
    }

    print "Command output: $mgtsObj->{OUTPUT}\n";

=back

=cut

sub cmd {
    my ($self, %args) = @_;
    my $conn = $self->{conn};
    my $sub = "cmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    # Set default values before args are processed
    my %a = ( -timeout       => $self->{DEFAULTTIMEOUT},
              -errormode     => $conn->errmode,
              -exp_exit_code => 0, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value;}
    
    unless (logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a )) {
        $logger->error(__PACKAGE__ . ".$sub Problem printing argument information via logSubInfo() function.");
        return -1;  
    }   
    unless ($a{-cmd}) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-cmd\" must be specified and not be blank");
        return -1;
    }
    
    # check timeout is a positive integer
    if ($a{-timeout} <= 0) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-timeout\" must be a positive integer");
        return -1;   
    }
    
    if ($a{-errormode} ne "die" && $a{-errormode} ne "return") {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-errormode\" has invalid value of \"$a{-errormode}\". Must be either \"die\" or \"return\".");
        return -1;   
    }
        
    my @buffer;
    
    # Reset cmd output data
    $self->{OUTPUT} = "";
    
    # Execute command
    $logger->debug(__PACKAGE__ . ".$sub Executing '$a{-cmd}'");  
    unless ( @buffer = $conn->cmd( -string => $a{-cmd}, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Command execution failure for command '$a{-cmd}'");
        if ($conn->errmsg =~ /command timed-out/) {
            $logger->error(__PACKAGE__ . ".$sub Command execution for command '$a{-cmd}' got time-out, hence going to kill it");
            unless ($conn->cmd( -string => "\cC", -timeout => $a{-timeout} ) ) {
                $logger->error(__PACKAGE__ . ".$sub unable to kill using Ctrl-C");
            } else {
                $logger->error(__PACKAGE__ . ".$sub killed hung command using Ctrl-C");
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $conn->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return -1;
    }
  
    # Set cmd output data
    $self->{OUTPUT} = join '', @buffer;
  
    $logger->debug(__PACKAGE__ . ".$sub \n$self->{OUTPUT}");
      
    # Check command exit code
    my $exit_code_cmd;
    if ( $self->{SHELL} =~ m/.*csh/ ) {
        $exit_code_cmd = 'echo $status';
    } else {
        $exit_code_cmd = 'echo $?';
    }
  
    unless ( @buffer = $conn->cmd( -string => $exit_code_cmd, -timeout => $a{-timeout}, -cmd_remove_mode => 1 ) )  {
        $logger->error(__PACKAGE__ . ".$sub Command execution failure for command '$exit_code_cmd' (command exit code check)");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $conn->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return -1;
    }
    
    # $logger->debug(__PACKAGE__ . "Command return code ************ : " . Dumper (@buffer) . "\n");

    # Get exit code from output
    my $exit_code = $buffer[$#buffer];
    chomp $exit_code;
    
    # We may want a command to fail without printing an error
    #    (e.g. The 'stop_mgts_script' MGTS cmd always returns 1 - regardless of success or not!).
    # If so set the -exp_exit_code arg to the value of the expected exit code and
    # then the error will not be printed.
    if ( $exit_code == $a{-exp_exit_code} ) {
        return 0;
    } else {
        $logger->error(__PACKAGE__ . ".$sub Command '$a{-cmd}' failed with exit code '$exit_code':\n$self->{OUTPUT}");
        return $exit_code;
    }        
}

=head2 startSession()

Start MGTS session and connect to shelf (if appropriate)

=over

=item Mandatory Arguments:
    -protocol => <protocol string>
        MGTS signalling protocol variant;
            Valid values:   "ANSI-M3UA",
                            "ANSI-SS7",
                            "ATT-SS7",
                            "AUSTRL-SS7",
                            "CCITT-SS7",
                            "CHINA-SGT",
                            "CHINA-SGT",
                            "ETSI-SS7-3",
                            "ETSI-SS7-4",
                            "GERMN-SS7",
                            "INDIA-SS7",
                            "ITALY-SS7",
                            "ITU-M3UA",
                            "JAPAN-SGT",
                            "JAPAN-SS7",
                            "NATISDN2P",
                            "PNOISC-SS7",
                            "Q931",
                            "SPAIN-SS7",
                            "UK-SS7",
                            "WHITE-SS7"
            Arg example:    -protocol => "WHITE-SS7"

    -display => <display string>
        DISPLAY settings;
            Valid value:    non-empty string
            Arg example:    -display => ":3.0"

=item Optional Arguments:
    -assignment => <MGTS Network-Shelf Assignment string>
        MGTS Network-Shelf Assignment that is already loaded on MGTS shelf/board
        and needs to be re-connected to;
            Valid values:   string
            Default value:  $mgtsObj->{ASSIGNMENT} which is set at MGTS object's instantiation. (could be blank!)
            Arg example:    -assignment => "mgts1_c7n1_LAUREL"
            NOTE: A new assignment to download is specified in the downloadAssignment() fn.

    -force => <0 or 1>
        Force disconnect from a shelf before connecting;
            Valid values:   0 (don't force) and 1 (force).
            Default Value:  $mgtsObj->{FORCE} which is set at MGTS object's instantiation. 
            Arg example:    -force => 0

    -timeout => <timeout value>
        Default timeout for commands in seconds;
            Valid values:   positive integer > 0
            Default value:  $mgtsObj->{DEFAULTTIMEOUT} which is set at MGTS object's instantiation.
            Arg example:    -timeout => 20

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise 

=back

=cut

sub startSession {
    my ($self, %args) = @_;
    my $sub = "startSession()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    # Set default values before args are processed
    my %a = ( -force      => $self->{FORCE},
              -timeout    => $self->{DEFAULTTIMEOUT},
              -assignment => $self->{ASSIGNMENT},
            );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    unless (logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a )) {
        $logger->error(__PACKAGE__ . ".$sub Problem printing argument information via logSubInfo() function.");
        return 0;  
    }
    
    foreach ( qw/ -display -protocol / ) {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub Mandatory \"$_\" parameter not provided or is blank");
            return 0;
        }
    }
    
    # Check and get protocol variant specific configuration file
    my $source_cmd;
    my $config_file;
    if  ( $self->{CONFIG_FILE}{$a{-protocol}} ) {
        $self->{PROTOCOL} = $a{-protocol};
        $config_file = $self->{CONFIG_FILE}{$a{-protocol}};
    } else {
        $logger->error(__PACKAGE__ . ".$sub Unknown protocol $a{-protocol}");
        return 0;
    }

    # Setup DISPLAY cmd and to set on MGTS later     
    my $display_cmd;
    if ( $self->{SHELL} eq "csh" or $self->{SHELL} eq "tcsh" ) {
        $config_file = $config_file . "_csh";
        $source_cmd = "source";
        $display_cmd = "setenv DISPLAY $a{-display}"
    } else {
        $config_file = $config_file . "_env";
        $source_cmd = "."; 
        $display_cmd = "DISPLAY=$a{-display}; export DISPLAY";
    }
    
    # Check whether the DISPLAY value is NOT used by anyone else
    my $grepDisplay = "ps -aef | grep \"$a{-display}\"";

    # Set DISPLAY on MGTS
    $self->cmd( -cmd => $grepDisplay, -timeout => $a{-timeout} );
    my $line;

    # trying kill any hung session for the user
    my @killedPS = ();
    foreach $line ( split /\n/, $self->{OUTPUT} ) {
       next if ($line =~ /grep $a{-display}/);
       my @proces = split (/\s+/,$line);
       $logger->debug(__PACKAGE__ . ".$sub killing process id $proces[1]");
       if ($self->cmd( -cmd =>"kill $proces[1]", -timeout => $a{-timeout} )) {
          $logger->debug(__PACKAGE__ . ".$sub \'kill $proces[1]\' failed, might belonging to someone else");
       } else {
         push (@killedPS, $proces[1]);
       }
    }

    if (@killedPS) {
       $self->cmd( -cmd => "ps h -p " . join(' ', @killedPS), -timeout => $a{-timeout});
       foreach $line ( split /\n/, $self->{OUTPUT} ) {
          $line =~ s/^\s+//;
          my @process = split (/\s+/,$line);
          $logger->debug(__PACKAGE__ . ".$sub $process[0] still running lets kill it bye kill -9");
          $self->cmd( -cmd =>"kill -9 $process[0]", -timeout => $a{-timeout} );
       }
    }

    $self->cmd( -cmd => $grepDisplay, -timeout => $a{-timeout} );

    foreach $line ( split /\n/, $self->{OUTPUT} ) {
       if($line =~ m/shelfMgr -display $a{-display}/) {
          $logger->error(__PACKAGE__ . ".$sub The DISPLAY variable set in the TMS alias of MGTS should be unique");
          $logger->error(__PACKAGE__ . ".$sub The current $a{-display} is being used by someone else. Please change the variable to continue the execution");
          $logger->error(__PACKAGE__ . ".$sub : \n$self->{OUTPUT}");
          return 0;
       }
    }

    # Set DISPLAY on MGTS
    if ( $self->cmd( -cmd => $display_cmd, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to set DISPLAY via '$display_cmd':\n$self->{OUTPUT}");
        return 0;
    }    
    # Create log directory if one does not exist
    if ( $self->cmd( -cmd => "test -d $self->{LOG_DIR} || ( mkdir -p $self->{LOG_DIR}  && chmod 777 $self->{LOG_DIR} )" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to create directory '$self->{LOG_DIR}'\n$self->{OUTPUT}");
        return 0;
    }
  
    # Create temporary config file to remove xset lines
    if ( $self->cmd( -cmd => "cat $config_file | sed -e 's/^.*xset/echo \"\" \#xset/g' > ${config_file}_tmp" , -timeout => $a{-timeout}) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to create directory '$self->{LOG_DIR}'\n$self->{OUTPUT}");
        return 0;
    }
  
    # Source MGTS environment config file
    if ( $self->cmd( -cmd => "$source_cmd ${config_file}_tmp", -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to source configuration file:\n$self->{OUTPUT}");
        return 0;
    } 
      
    # Start MGTS scripting session (but first terminate any active session and ignore errors)
    $self->cmd( -cmd => "stop_mgts_script", -exp_exit_code => 1 );
  
    if ( $self->cmd( -cmd => "run_mgts_script", -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to start a new MGTS scripting session");
        return 0;
    } else {
        # Set SESSION_ACTIVE flag as MGTS session is now running
        $self->{SESSION_ACTIVE} = 1;   
    }
    
    # Interpolate any Unix variables in $self->{LOG_DIR}; (S)FTP do not like these
    if ( $self->cmd( -cmd => "echo $self->{LOG_DIR}", -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to echo `$self->{LOG_DIR}` on MGTS");
        return 0;
    }
    chomp( $self->{LOG_DIR} = $self->{OUTPUT} ) ;
    $logger->debug(__PACKAGE__ . ".$sub LOG_DIR is $self->{LOG_DIR}");
  
    # Store the MGTS_DATA variable in the object
    if ( $self->cmd( -cmd => "echo \$MGTS_DATA" , -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to echo MGTS_DATA environment variable on MGTS");
        return 0;
    }
    chomp( $self->{MGTS_DATA} = $self->{OUTPUT} ) ;
    $logger->debug(__PACKAGE__ . ".$sub MGTS_DATA is $self->{MGTS_DATA}");
    
    # Connect to shelf (if we need to connect to a previously downloaded assignment
    # or the MGTS shelf is an i2000)
    if ( $a{-assignment} || $self->{SHELF_VERSION} eq "i2000" ) {
        unless ( $self->shelfConnect( %a, -disconnect => $a{-force} ) )  {
            if ($a{-assignment}) {
                $logger->error(__PACKAGE__ . ".$sub Failed to connect to $self->{SHELF_VERSION} shelf '$self->{SHELF}' to use assignment '$a{-assignment}'");
            } else {
                $logger->error(__PACKAGE__ . ".$sub Failed to connect to $self->{SHELF_VERSION} shelf '$self->{SHELF}'");
            }
            return 0;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub Successfully started MGTS session. Welcome!");
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;
}


=head2 endSession()

Disconnect from shelf and terminate the MGTS session

=over

=item Optional Arguments:

    -force => <0 or 1>
        Force disconnect;
        Values are 0 (don't force) and 1 (force).
        Defaults to 1 (force)

    -timeout => <timeout integer>
        Command timeout, in seconds;
        Defaults to $mgtsObj->{DEFAULTTIMEOUT} inside the called cmd() function and
        20 seconds inside the shelfDisconnect() fn when omitted.

=item Assumptions:

    The following variables are set:
        $mgtsObj->{SHELF_CONNECTED} - initialised at object's instantiation and
            set appropriately in shelfConnect(), downloadAssignment() and shelfDisconnect().
        $mgtsObj->{SESSION_ACTIVE} - initialised at object's instantiation and
            set appropriately in startSession() and this fn.

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise 

=back

=cut

sub endSession {
    my ($self, %args) = @_;
    my $sub = "endSession()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    my %a = (-force => 1);
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Disconnect any connected shelf.
    if ($self->{SHELF_CONNECTED}) {
        unless ($self->shelfDisconnect( %a ) ) {
            $logger->warn(__PACKAGE__ . ".$sub Failed to disconnect from shelf");
        }
    }   

    if ($a{-force} ) {
        $self->{ASSIGNMENT} = "";
    }
    
    # Stop the MGTS session (using expected exit code of 1 as MGTS 'stop_mgts_script' always returns 1)
    if ($self->{SESSION_ACTIVE}) {
        if (($self->cmd( -cmd => "stop_mgts_script", %a, -exp_exit_code => 1 )) == 0) {
            # Update session active flag to 0 (deactive)
            $self->{SESSION_ACTIVE} = 0;
        } else {
            # If any failures reported in the cmd execution output then log an error and return '0'
            $logger->error(__PACKAGE__ . ".$sub Failed to stop MGTS session:\n$self->{OUTPUT}");
            return 0;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub Successfully terminated MGTS session. Bye!");
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;
}


=head2 shelfConnect()

Connect to shelf

=over

=item Optional Arguments:
    -assignment => <MGTS Network-Shelf Assignment string>
        MGTS Network-Shelf Assignment that is already loaded on MGTS shelf/board
        and needs to be re-connected to;
            Valid values:   string
            Default value:  $mgtsObj->{ASSIGNMENT} which is set at MGTS object's instantiation. (could be blank!)
            Arg example:    -assignment => "mgts1_c7n1_LAUREL"
            NOTE: A new assignment to download is specified in the downloadAssignment() fn.

    -disconnect => <0 or 1>
        Disconnect from a shelf before connecting;
            Valid values:   0 (don't disconnect) and 1 (disconnect).
            Default Value:  0 (don't disconnect) 
            Arg example:    -disconnect => 1

    -timeout => <timeout value>
        Default timeout for shelfConnect and shelfDisconnect commands in seconds;
            Valid values:   positive integer > 0
            Default value:  20
            Arg example:    -timeout => 20

=item Assumptions:
    The following variables are set at MGTS object's instantiation and are not blank:
        $mgtsObj->{SHELF}
        $mgtsObj->{SHELF_VERSION}
        $mgtsObj->{SERVER_VERSION}

=item Returns:

    Command exit code:
    * 1 - on success - connected to shelf
    * 0 - otherwise 

=back

=cut

sub shelfConnect {
    my ($self, %args) = @_;
    my $sub = "shelfConnect()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed  
    my %a = ( -disconnect     => 0,
              -timeout        => 20 );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Check the MGTS object shelf variables used later in this fn are not blank.
    unless ($self->_checkShelfVars( -sub => $sub)) {
        $logger->error(__PACKAGE__ . ".$sub Error with mandatory MGTS object shelf variables.");
        return 0;
    }
    
    # check disconnect arg is 0 or 1
    if (($a{-disconnect} < 0) || ($a{-disconnect} > 1)) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-disconnect\" must be 0 or 1");
        return 0;   
    }
    
    # Only disconnect if we are an i2000, the -disconnect == 1 
    if ( ($self->{SHELF_VERSION} eq "i2000" ) and ($a{-disconnect}) ) {
        if ( $self->shelfDisconnect( -force => 1, -timeout => $a{-timeout} ) ) {
            $logger->warn(__PACKAGE__ . ".$sub Failed to disconnect shelf\n$self->{OUTPUT}");
        }
    }

    # Make sure assignment info is up-to-date (if $a{-assignment} defined)
    $self->{ASSIGNMENT} = $a{-assignment} if $a{-assignment};
    
    # Hash of MGTS shelfConnect error codes
    my %shelf_connect_error_codes = (
        1 => "Application was not started in scripting mode.",
        2 => "Invalid shelf name",
        5 => "Invalid or missing command line argument(s)",
        7 => "Unable to connect to shelf",
    );

    # Attempt to connect to shelf  
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
        
        if ( $self->{ASSIGNMENT} ) {
            my $shelf_id = $self->_getShelfPasmId();
            
            $logger->info(__PACKAGE__ . ".$sub Attempting to connect to $self->{SHELF_VERSION} shelf '$shelf_id' to verify if it is already downloaded...");
                
            if ( my $connect_failure_reason = $self->cmd( -cmd => "shelfConnect $shelf_id", -timeout => $a{-timeout}) ) {
                
                # If possible, report failure with actual shelfConnect error messages using
                # shelf_connect_error_codes hash defined above.
                my $failure_reason = "Unknown error code #${connect_failure_reason}";
                if ($shelf_connect_error_codes{$connect_failure_reason}) {
                    $failure_reason = $shelf_connect_error_codes{$connect_failure_reason};
                }
                $logger->error(__PACKAGE__ . ".$sub Unable to connect to $self->{SHELF_VERSION} shelf '$shelf_id'. Failure reason:\"$failure_reason\"\n");
                return 0;
            }
            $logger->info(__PACKAGE__ . ".$sub Successfully connected to pre-downloaded $self->{SHELF_VERSION} shelf '$shelf_id'");
            $self->{SHELF_CONNECTED} = 1; # Update the SHELF_CONNECTED flag to 1 (connected)
            
        } else {
            $logger->info(__PACKAGE__ . ".$sub Skipping shelfConnect on $self->{SHELF_VERSION} shelf '$self->{SHELF} as no assignment defined");
        }
    } else { # Shelf must be an i2000
        if ( my $connect_failure_reason = $self->cmd( -cmd => "shelfConnect $self->{SHELF}", -timeout => $a{-timeout} ) ) {
            
            # If possible, report failure with actual shelfConnect error messages using
            # shelf_connect_error_codes hash defined above.
            my $failure_reason = "Unknown error code #${connect_failure_reason}";
            if ($shelf_connect_error_codes{$connect_failure_reason}) {
                $failure_reason = $shelf_connect_error_codes{$connect_failure_reason};
            }
            $logger->error(__PACKAGE__ . ".$sub Failed to connect to shelf '$self->{SHELF}'. Failure reason:\"$failure_reason\"\n");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub Successfully connected to $self->{SHELF_VERSION} shelf '$self->{SHELF}'");
        $self->{SHELF_CONNECTED} = 1; # Update the SHELF_CONNECTED flag to 1 (connected)
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
   
    return 1;
}


=head2 shelfDisconnect()

Disconnect from shelf

=over

=item Optional Arguments:
    -assignment => <MGTS Network-Shelf Assignment string>
        MGTS Network-Shelf Assignment that is already loaded on MGTS shelf/board
        and needs to be disconnected from;
            Valid values:   string
            Default value:  $mgtsObj->{ASSIGNMENT} which is set at MGTS object's instantiation. (could be blank!)
            Arg example:    -assignment => "mgts1_c7n1_LAUREL"

    -force => <0 or 1>
        Force disconnect from a shelf before connecting;
            Valid values:   0 (don't force) and 1 (force).
            Default Value:  0 (don't force) 
            Arg example:    -force => 1

    -timeout => <timeout value>
        Default timeout for shelfDisconnect commands in seconds;
            Valid values:   positive integer > 0
            Default value:  20
            Arg example:    -timeout => 20

=item Assumptions:
    The following variables are set at MGTS object's instantiation and are not blank:
        $mgtsObj->{SHELF}
        $mgtsObj->{SHELF_VERSION}
        $mgtsObj->{SERVER_VERSION}

=item Returns:

    Command exit code:
    * 1 - on success - disconnected from shelf
    * 0 - otherwise 

=back

=cut

sub shelfDisconnect {
    my ($self, %args) = @_;
    my $sub = "shelfDisconnect()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 
    # Set default values before args are processed
    my %a = ( -force   => 1,
              -timeout => 20 );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Check the MGTS object shelf variables used later in this fn are not blank.
    unless ($self->_checkShelfVars( -sub => $sub)) {
        $logger->error(__PACKAGE__ . ".$sub Error with mandatory MGTS object shelf variables.");
        return 0;
    }
    
    # check force disconnect arg is 0 or 1
    if (($a{-force} < 0) || ($a{-force} > 1)) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-force\" must be 0 or 1");
        return 0;   
    }
      
    # Make sure assignment info is up-to-date
    $self->{ASSIGNMENT} = $a{-assignment} if $a{-assignment};

    my $force_str = "";
    if ( $a{-force} ) { $force_str = "-releaseLicenses -f"; }
    
    # Hash of MGTS shelfDisconnect error codes
    my %shelf_disconnect_error_codes = (
        1 => "Application was not started in scripting mode.",
        2 => "Invalid shelf name",
        3 => "Not connected to specified shelf",
        5 => "Invalid or missing command line argument(s)",
        7 => "Unable to disconnect shelf",
    );
    
    # Attempt to disconnect from  shelf  
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" ) || ( $self->{SHELF_VERSION} eq "Softshelf")) {
        
        if ( $self->{ASSIGNMENT} ) {
            my $shelf_id = $self->_getShelfPasmId();
                                
            if ( my $disconnect_failure_reason = $self->cmd( -cmd => "shelfDisconnect $shelf_id $force_str", -timeout => $a{-timeout} ) ) {
                # If possible, report failure with actual shelfDisconnect error messages using
                # shelf_disconnect_error_codes hash defined above.
                my $failure_reason = "Unknown error code #${disconnect_failure_reason}";
                if ($shelf_disconnect_error_codes{$disconnect_failure_reason}) {
                    $failure_reason = $shelf_disconnect_error_codes{$disconnect_failure_reason};
                }
                
                $logger->error(__PACKAGE__ . ".$sub Unable to disconnect from $self->{SHELF_VERSION} shelf '$shelf_id'. Failure Reason:\"$failure_reason\"\n");
                return 0;
            }
            
            $logger->info(__PACKAGE__ . ".$sub Successfully disconnected from $self->{SHELF_VERSION} shelf '$shelf_id'");
            $self->{SHELF_CONNECTED} = 0; # Update the SHELF_CONNECTED flag to 0 (disconnected)
        } else {
            $logger->info(__PACKAGE__ . ".$sub Skipping shelfDisconnect as MGTS shelf '$self->{SHELF}' is a $self->{SHELF_VERSION} and no assignment defined");
        }
                
    } elsif ( $self->{SHELF_VERSION} eq "i2000" ) { 

        if ( $self->{SERVER_VERSION} =~ /^10/ and $a{-force} ) {
            $force_str = "-f";
        }
      
        if ( my $disconnect_failure_reason = $self->cmd( -cmd => "shelfDisconnect $self->{SHELF} $force_str", -timeout => $a{-timeout} ) ) {
            # If possible, report failure with actual shelfDisconnect error messages using
            # shelf_disconnect_error_codes hash defined above.
            my $failure_reason = "Unknown error code #${disconnect_failure_reason}";
            if ($shelf_disconnect_error_codes{$disconnect_failure_reason}) {
               $failure_reason = $shelf_disconnect_error_codes{$disconnect_failure_reason};
            }
            
            $logger->error(__PACKAGE__ . ".$sub Failed to disconnect from shelf '$self->{SHELF}'. Failure Reason:\"$failure_reason\"\n");
            return 0;
        } 
            
        $logger->info(__PACKAGE__ . ".$sub Successfully disconnected from shelf '$self->{SHELF}'");
        $self->{SHELF_CONNECTED} = 0; # Update the SHELF_CONNECTED flag to 0 (disconnected)
    } else {
        $logger->error(__PACKAGE__ . ".$sub Shelf Version '$self->{SHELF_VERSION}' not recognised\n");   
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;
}


=head2 downloadAssignment()

Compile and download network-shelf assignment to MGTS shelf/board.

NOTE: For p400s/m500s this also connects to the shelf/board.
      For i2000s the shelf should already be connected to before calling this function.

=over

=item Mandatory Arguments:
    -assignment => <MGTS Network-Shelf Assignment string>
        MGTS Network-Shelf Assignment to be compiled and downloaded to shelf
            Valid values: non-empty string
            Arg example:  -assignment => "mgts1_c7n1_LAUREL"

=item Optional Arguments:
    -reset_shelf => <0 or 1>
        Reset shelf before downloading; applies to i2000 and ignored for p400/m500;
            Valid Values:   0 (don't reset) or 1 (reset)
            Default Value:  1 (reset)
            Arg example:    -reset_shelf => 0

    -timeout => <timeout value>
        Command timeout in seconds;
            Valid values:   positive integer > 0
            Default value:  20 seconds
            Arg example:    -timeout => 20

    -alignwait => <align timeout value>
        Wait a specified time (seconds) for alignment to occur.
            Valid values:   positive integer > 0
            Default value:  15 secs for JAPAN-SS7, 10 secs otherwise.
            Arg example:    -alignwait => 18 

     -downloadOption => <assignmennt download option>
        Specify assignmennt download option for the commands 'networkExecuteM5k' or 'networkExecute'
            Valid values  : -download or -noBuild
            Default value : -download
            Example       : -downloadOption => '-noBuild'

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise 

=back

=cut

sub downloadAssignment {
    my ($self, %args) = @_;
    my $sub = "downloadAssignment()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    # Set default values before args are processed
    my %a = ( -reset_shelf    => 1,
              -timeout        => 60,
              -downloadOption => '-download',
            );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    # Check the MGTS object shelf variables used later in this fn are not blank.
    unless ($self->_checkShelfVars( -sub => $sub)) {
        $logger->error(__PACKAGE__ . ".$sub Error with mandatory MGTS object shelf variables.");
        return 0;
    }
    
    # Verify required arguments defined
    unless ( $a{-assignment} ) {
        $logger->error(__PACKAGE__ . ".$sub Mandatory '-assignment' argument required");
        return 0;
    }

    # check force disconnect arg is 0 or 1
    if (($a{-reset_shelf} < 0) || ($a{-reset_shelf} > 1)) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-reset_shelf\" must be 0 or 1");
        return 0;   
    }
    
    # check align wait is a positive integer
    if (defined($a{-alignwait}) && $a{-alignwait} <= 0) {
        $logger->error(__PACKAGE__ . ".$sub Argument \"-alignwait\" must be a positive integer");
        return 0;   
    }
    
    $self->{ASSIGNMENT} = $a{-assignment};
    
    my $shelf_id = $self->_getShelfPasmId();
    
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
       
        if ($self->{ASSIGNMENT} =~ /\.AssignM5k$/) {
            $self->{ASSIGNMENT} =~ s/\.AssignM5k$//; 
        }
        
        if ($shelf_id  =~ /\.AssignM5k$/) {
            $shelf_id =~ s/\.AssignM5k$//; 
        }
        # Get the list of P400/M500 boards used by the assignment.
        # Markup Language notation of the form </slot${slot_num}>
        if ( $self->cmd( -cmd => "grep '<\\\/slot[1-9][0-9]*>' \$MGTS_DATA\/$self->{ASSIGNMENT}.AssignM5k", -timeout => $a{-timeout} ) ) {
            $logger->error(__PACKAGE__ . ".$sub Command execution failure to grep slots used in MGTS assignment grep <\/slot[1-9][0-9]*> \$MGTS_DATA\/$self->{ASSIGNMENT}.AssignM5k");
            return 0;
        }
        
        foreach (split /\n/, $self->{OUTPUT}) {
            chomp;
            # Get the slot number
            my $slot = m/^.*slot([1-9][0-9]*)/;
            $slot=$1;
            
########################################################################################################################
#Commented to use in BLR test beds

#           $logger->debug(__PACKAGE__ . "************* Commented /home/stack2/bin/disconnectMgts command");

            # Ensure the P400/M500 board is free and available for download. i.e. force board disconnection
            # NOTE: This is hard coded to a UK script at the moment. This may change in future

#            $self->cmd( -cmd => "/home/stack2/bin/disconnectMgts $self->{SHELF} $slot", -timeout => $a{-timeout} );
#            $self->cmd( -cmd => "/home/achandrashekar/TEMP/disconnectMgtsSus $self->{SHELF} $slot", -timeout => $a{-timeout} );
#
#            if (!($self->{OUTPUT} =~ m/(Terminated|Command executed)/i )) {
#                $logger->error(__PACKAGE__ . ".$sub Failed to disconnect MGTS $self->{SHELF} in slot $slot");
#            }
#            elsif ( $self->{OUTPUT} =~ m/Host \<$self->{SHELF}\> is not accessible/i ) {
#                # To this point we are relying on the user (or TMS) to specify the right hostname and the right
#                # IP address. There is possibly of a mismatch. This will be picked up here.
#                $logger->error(__PACKAGE__ . ".$sub Failed to access MGTS $self->{SHELF}");
#                $self->cmd( -cmd => "hostname", -timeout => $a{-timeout} );
#                $logger->debug(__PACKAGE__ . ".$sub User specified MGTS is: $self->{SHELF}. Actual hostname is: $self->{OUTPUT}");
#                return 0;
#            }
        }
    } elsif ( $self->{SHELF_VERSION} eq "i2000" ) { # Shelf must be an i2000
        
        if ($self->{ASSIGNMENT} =~ /\.[aA]ssign$/) {
            $self->{ASSIGNMENT} =~ s/\.[aA]ssign$//; 
        }

        if ( $a{-reset_shelf} ) {
            if ( $self->cmd( -cmd => "shelfConfig $shelf_id -c", -timeout => $a{-timeout} ) ) {
                $logger->warn(__PACKAGE__ . ".$sub Failed to reset shelf '$shelf_id'\n$self->{OUTPUT}");
            }
        }
        
        # Re-connect; just to be sure, in case we lost connectivity during reset
        unless ( $self->shelfConnect( -disconnect => 0, -timeout => $a{-timeout} ) ) {
            $logger->error(__PACKAGE__ . ".$sub Lost connection to shelf '$shelf_id'");
            return 0;
        }
    } elsif ( $self->{SHELF_VERSION} eq "Softshelf") {

        if ($self->{ASSIGNMENT} =~ /\.[aA]ssign$/) {
            $self->{ASSIGNMENT} =~ s/\.[aA]ssign$//;
        }

        # Re-connect; just to be sure, in case we lost connectivity during reset
        unless ( $self->shelfConnect( -disconnect => 0, -timeout => $a{-timeout} ) ) {
            $logger->error(__PACKAGE__ . ".$sub Lost connection to shelf '$shelf_id'");
            return 0;
        }
    }

    # Hash of MGTS networkExecute(M5k) error codes
    my %net_execute_error_codes = (
        1  => "Error creating the buildfile",
        2  => "Error encrypting the data",
        3  => "Could not open the assign/shelf/build file",
        4  => "Error reading bits",
        5  => "Unable to open communications with the shelf",
        6  => "Used Ports tag has been modified in the buildfile",
        7  => "Format error of file or packet",
        8  => "Unable to check-out the protocol license",
        9  => "Shelf is not registered or not bound",
        13 => "Protocol license tags in buildfile have been modified",
    );

    my $network_execute_cmd;

    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
        $network_execute_cmd = "networkExecuteM5k $a{-downloadOption} $shelf_id";
    } else {
        $network_execute_cmd = "networkExecute $a{-downloadOption} $a{-assignment}";
    }

    $logger->info(__PACKAGE__ . ".$sub Downloading assignment '$a{-assignment}' on shelf '$self->{SHELF}'");    
    # Compile and download the assignment
    if ( my $net_exec_failure_reason = $self->cmd( -cmd => $network_execute_cmd, -timeout => $a{-timeout} ) ) {
        
        $logger->error(__PACKAGE__ . "************ Failure reason : '$net_exec_failure_reason' \n");

        # If possible, report failure with actual networkExecute(M5k) error messages using
        # the net_execute_error_codes hash defined above.
        my $failure_reason = "Unknown error code #${net_exec_failure_reason}";
        if ($net_execute_error_codes{$net_exec_failure_reason}) {
            $failure_reason = $net_execute_error_codes{$net_exec_failure_reason};
        }  
        
        $logger->error(__PACKAGE__ . ".$sub Failed to compile and download assignment $a{-assignment} to shelf '$self->{SHELF}'. Failure reason:\"$failure_reason\"\n");
        
        if ($net_exec_failure_reason == 14  or $self->{OUTPUT} =~ /Error required boards in use by others/i) {
            $logger->warn(__PACKAGE__ . ".$sub sleep for 30 to make boards available");
            sleep(30);
            $logger->warn(__PACKAGE__ . ".$sub re-downloading assignment '$a{-assignment}' on shelf '$self->{SHELF}'");
            
            if ( my $net_exec_failure_reason = $self->cmd( -cmd => $network_execute_cmd, -timeout => $a{-timeout} ) ) {
                $logger->error(__PACKAGE__ . "************ Failure reason : '$net_exec_failure_reason' \n");
                my $failure_reason = "Unknown error code #${net_exec_failure_reason}";
                if ($net_execute_error_codes{$net_exec_failure_reason}) {
                    $failure_reason = $net_execute_error_codes{$net_exec_failure_reason};
                }
                $logger->error(__PACKAGE__ . ".$sub Failed to compile and re-download assignment $a{-assignment} to shelf '$self->{SHELF}'. Failure reason:\"$failure_reason\"\n");
                $self->{ASSIGNMENT} = "";
                return 0;
           }
        } else {
           $self->{ASSIGNMENT} = "";
           return 0;
        }
    }
    
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" ) ||
        ( $self->{SHELF_VERSION} eq "Softshelf")) {
        $self->{SHELF_CONNECTED} =  1; # Update the connected shelf flag
    }
    
    if( $self->{SHELF_VERSION} ne "Softshelf")
    {
       # Align links
       $logger->info(__PACKAGE__ . ".$sub Aligning links on shelf '$shelf_id'");
    
       # Hash of MGTS shelfAlign error codes
       my %shelf_align_error_codes = (
           1 => "Shelf was not connected",
           2 => "Invalid shelf name",
           3 => "Communication queue with shelf could not be established",
           5 => "Invalid or missing command line argument(s)",
           6 => "An interrupt signal was received",
       );
    
       if ( my $align_failure_reason = $self->cmd( -cmd => "shelfAlign $shelf_id", -timeout => $a{-timeout} ) ) {
        
           # If possible, report failure with actual shelfAlign error messages using
           # the shelf_align_error_codes hash defined above.
           my $failure_reason = "Unknown error code #${align_failure_reason}";
           if ($shelf_align_error_codes{$align_failure_reason}) {
               $failure_reason = $shelf_align_error_codes{$align_failure_reason};
           }
           $logger->warn(__PACKAGE__ . ".$sub Failed to initiate link alignment on shelf '$shelf_id'. Failure reason:\"$failure_reason\"\n");
       } else {
           unless( $a{-alignwait}) {
               if ( $self->{PROTOCOL} =~ m/JAPAN/i ) {
                   $a{-alignwait} = 15;
               } else {
                   $a{-alignwait} = 10;
               }
           }
            
           $logger->info(__PACKAGE__ . ".$sub Pause $a{-alignwait} secs for alignment");
           sleep $a{-alignwait};
       }

    }

    # Ensure seqlist hash is empty after download.
    # Can be re-populated by using getSeqList function
    delete $self->{SEQLIST};
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    
    return 1;
}


=head2 _invalidArgs( sub, valid_arg, invalid_arg_list )

    Takes a hash of invalid arguments and prints an error message for every
    arg in the hash.

=over

=item Mandatory arguments:
    sub              - name of function called from
    valid_arg        - name of valid arg it is specified with. If blank then
                       withold name of valid arg in error message
    invalid_arg_list - hash of invalid arguments

=item Returns:

    * 1 - if invalid args found (i.e. hash was not empty)
    * 0 - otherwise 

=back

=cut

sub _invalidArgs {
    my ($sub, $valid_arg, %invalid_arg_list) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $invalid_arg_found = 0;
    
    for (keys %invalid_arg_list) {
        # Log an error if any invalid arg found
        if ($valid_arg) {
            $logger->error(__PACKAGE__ . ".$sub Invalid arg '$_' (value='$invalid_arg_list{$_}') specified with '$valid_arg' arg");
        } else {
            $logger->error(__PACKAGE__ . ".$sub Invalid arg '$_' (value='$invalid_arg_list{$_}') specified.");
        }
        $invalid_arg_found = 1;
    }
    
    return $invalid_arg_found;
}


=head2 _shelfPasm()

Wrapper function for the MGTS shelfPASM command.

    With the MGTS shelfPASM script command you can do the following:
       * run a PASM node (-run )
       * wait for a state machine to complete (-wait)
       * stop a PASM node (-stop)
       * log output to a file (-log)
       * query pass/fail counts (-passed or -failed)
       * query transmit/receive counts (-status)

NOTE: It is advised that this function is called indirectly via wrapper functions.

=over

=item Optional arguments:

    -nodelist => 1
        List the nodes downloaded to the shelf/board. No further arguments other
        than -timeout should be specified with this argument.

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

    # The following options require the -node arg to be specified as well

    -passed => 1
        Returns list of all downloaded state machines where each state machine
        in the list is prefixed by the number of times it has passed.
        NOTE: Can only be used in conjuction with -node arg

    -failed => 1
        As -passed above except prefixed by the number of times the state machine
        has failed.
        NOTE: Can only be used in conjuction with -node arg

    -qlist => 1
        Displays the queued simulation state machines for a node including the state
        machine currently being executed. Displays nothing if no state machines
        are queued.
        NOTE: Can only be used in conjuction with -node arg

    -seqlist => 1
        Returns a list of state machines downloaded to the node
        NOTE: Can only be used in conjuction with -node arg

    -clearloadstatus => 1
        Clears all reseults (status counters) for a PASM Load node
        NOTE: Has to be used in conjuction with -node arg but can be simultaneously
              used with -run (-machine, -sequence, -wait), -stop, -logfile. 

    -clearsimstatus => 1
        Clears the pass/fail results for a PASM Simulation node
        NOTE: Has to be used in conjuction with -node arg but can be simultaneously
              used with -run (-machine, -sequence, -wait), -stop, -logfile.

    -loadstatus => 1
        Displays current load status. It reports the following:
            * number of transmit state machines started
            * number of receive state machines started
            * number of passed states
            * number of failed states
            * number of inconclusive states
        For PASM simulation nodes this option produces no output
        NOTE: Has to be used in conjuction with -node arg but can be simultaneously
              used with -run (-machine, -sequence, -wait), -stop, -logfile.

    -logfile => <log_name string>
        Starts logging MGTS execution output to a file <log_name> (if specified).
        Decode level should be set by -decode <decode_level>.
        The file is created in $mgtsObj->{LOG_DIR} which defaults to ~/Logs
        If the log name string is blank i.e. "" this stops all current logging.
        NOTE: Has to be used in conjuction with -node arg but can be simultaneously
              used with -run (-machine, -sequence, -wait), -stop, (-clearsimstatus or
              -clearloadstatus).

    -decode => <decode_level>
        Decode level; 0 (no decoding), 1, 2, 3, or 4 (full decodes);
        Used in conjunction with -logfile <log_name>
        NOTE: Has to be used in conjuction with -node and -logfile args but can
              be simultaneously used with -run (-machine, -sequence, -wait),
              -stop, (-clearsimstatus or -clearloadstatus).

    -run => 1
        Executes specified (-machine or -sequence) state machine or whole group
        (if neither are specified)
        NOTE: Has to be used in conjuction with -node arg but can be simultaneously
              used with -machine, -sequence, -wait, -logfile, (-clearsimstatus or
              -clearloadstatus).

    -stop => 1
        Stops the currently running state machine on the specified PASM node
        Has to be used in conjuction with -node arg but can be simultaneously
              used with -machine, -sequence, -logfile, (-clearsimstatus or
              -clearloadstatus).

    -runOnceForLoad => 1
        Runs the specified state machine or sequence Once.
        Has to be used in conjunction with -run arg.
        Used when you want to run a state machine for a definite number of times.
         Reqd Args: -node , -machine or -sequence.

    -sequence => <seq number>
        sequence number of state machine to execute, if "" (or not defined) then either -machine
        or the whole sequence group is executed
        NOTE: Has to be used in conjuction with -node and -run or -stop args but
              can be simultaneously used with -wait, -logfile, (-clearsimstatus or
              -clearloadstatus).

    -machine => <machine name string>
        State machine to execute, if "" (or not defined) then either -sequence
        or the whole sequence group is executed
        NOTE: Has to be used in conjuction with -node and -run or -stop args but
              can be simultaneously used with -wait, -logfile, (-clearsimstatus or
              -clearloadstatus).

    -wait => <0 or 1>
        Waits until the PASM node has finished running its sequence group (or
        single state machine) before exiting;
        Valid values: 0 (don't wait) or 1 (wait)
        Default value: 0 (don't wait) if not specified
        NOTE: Has to be used in conjuction with -node and -run args but can be
              simultaneously used with (-sequence or -machine) and -logfile,
              (-clearsimstatus or -clearloadstatus).

    -timeout => <timeout value>
        How long to wait for the shelfPASM command to complete execution in seconds.
        If the command has not completed by this time then the execution will cease
        and an error will be reported.
        Defaults to 10 seconds if not specified

    -stoplog => ""
        Stop the logging on the MGTS. This flushes the MGTS Log buffer

=item Returns:

    Command exit code:
    * 1 - shelfPASM cmd success
    * 0 - otherwise 

=back

=cut

sub _shelfPasm {
    my ($self, %a) = @_;
    my $sub = "_shelfPasm()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    # Copy hash of args to produce a hash of unprocessed args
    my %unprocessed_args = %a;
    
    # If the -timeout arg is specified remove it from the unprocessed_args hash
    # as this can be used with any arg.
    if (defined $a{-timeout}) {
        delete $unprocessed_args{-timeout} if defined $a{-timeout};
    } else {
        # Default -timeout to 10 seconds if not specified
        $a{-timeout} = 30;
    }
     
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    # Hash of MGTS shelfPASM error codes
    my %shelf_pasm_error_codes = (
        -1 => "MGTS.pm cmd() execution error or possible cmd timeout",
        1  => "Invalid shelf name",
        2  => "Shelf is not registered or not bound",
        3  => "Communications subsystems could not be opened",
        4  => "Socket could not be created",
        5  => "Error connecting to socket",
        6  => "Error on established socket (select failed)",
        7  => "Invalid node name. Node not recognised",
        8  => "Invalid LIC",
        9  => "No state machines known for LIC/board",
        10 => "No such command (client error or unsupported pasmDaemon error)",
        11 => "Node must be specified",
        12 => "Invalid state sequence number",
        13 => "Invalid state machine name",
        14 => "Could not run state machines on the node",
        15 => "Could not stop state machines on the node",
        16 => "Could not align the node",
        17 => "Could not query status of node",
        18 => "Could not query passed states of node",
        19 => "Could not query failed states of node",
        20 => "Too many state machines queued to start",
        21 => "State machine stopped forcefully",
        22 => "Too many clients waiting for state machines",
        23 => "Wait not allowed for PASM load modes",
        24 => "No PASM software found on LIC/board",
        25 => "Specified log file could not be opened",
        26 => "Logging not allowed on non-simulation node",
        27 => "No response to shelf query messages",
        28 => "Scripting daemon (pasmManager) is not running",
        29 => "LIC/board has no queue",
        30 => "State machine has completed already or not queued",
        31 => "Invalid -lic parameter. Format is <lic#> or <lic#>,<node#>",
        32 => "Node not found",
        33 => "Invalid sequence specification",
        34 => "Invalid mode (command only supported for simulation testing",
        35 => "Invalid decode level",
    );
    
    my $shelf_id = $self->_getShelfPasmId();
    my @shelf_pasm_cmds = ();
    my $shelf_pasm_args;;
    
    if ( defined($a{-nodelist}) ) {
        # Doesn't need any other args. Ensure no other args are configured
        # Remove -nodelist from list of unprocessed args
        delete $unprocessed_args{-nodelist};
        
        # Check to ensure no other args are remaining to be processed in the
        # unprocessed_args hash. If so the fn will report an error and return 0
        if (_invalidArgs($sub,"-nodelist",%unprocessed_args)) {
            return 0;
        } else {
            # Add -nodelist to the list of shelfPASM cmds to execute (@shelf_pasm_cmds)
            push(@shelf_pasm_cmds,"-nodelist");
        }
    } elsif ( ! $a{-node} ) {  # Check mandatory -node arg exists if -nodelist arg not specified
        $logger->error(__PACKAGE__ . ".$sub Missing MGTS shelfPASM argument of -node\n");
        return 0;
    } elsif ( defined($a{-qlist}) || defined($a{-seqlist}) || defined($a{-passed}) || defined($a{-failed}) ) {
        # Remove -node from unprocessed_args hash as this has implicitly been
        # processed by previous elsif leg
        delete $unprocessed_args{-node};
        
        # Loop through the args to identify which has been specified. Only one
        # is allowed to be specified with no other args other than -node.
        foreach  (qw /-qlist -seqlist -passed -failed/ ) {
            if ( defined($a{$_}) ) {
                # Remove current arg denoted by $_ from hash of unprocessed args
                delete $unprocessed_args{$_};

                # Check to ensure no other args are specified.
                if (_invalidArgs($sub,"$_",%unprocessed_args)) {
                    return 0;
                } else {
                    # Add the current arg to the list of shelfPASM cmds to
                    # execute (@shelf_pasm_cmds). Note how the -node option is
                    # required too
                    push(@shelf_pasm_cmds,"-node $a{-node} $_");
                    # We have already checked that the other args are not defined
                    # in the _invalidArgs() fn so exit for loop.
                    last;
                }
            }
        }
    } elsif ( defined($a{-loadstatus}) ) {
        # Remove -node from unprocessed_args hash 
        delete $unprocessed_args{-node};
        # Remove -loadstatus from unprocessed_args hash 
        delete $unprocessed_args{-loadstatus};
        
        # Add the -status arg to the list of shelfPASM cmds to execute
        # (@shelf_pasm_cmds). Note how the -node option is required too
        push(@shelf_pasm_cmds,"-node $a{-node} -status");
    } else {
        # Remove -node from unprocessed_args hash 
        delete $unprocessed_args{-node};
        # Check to ensure that both -clearsimstatus and -clearloadstatus are not specified
        if (defined($a{-clearsimstatus}) && defined($a{-clearloadstatus})) {
            $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-clearsimstatus' and '-clearloadstatus' cannot both be specified\n");
            return 0;
        } elsif (defined $a{-clearsimstatus}) {
            # Remove -clearsimstatus from unprocessed_args hash 
            delete $unprocessed_args{-clearsimstatus};
            # Add -refresh to the list of shelfPASM cmds to execute
            # (@shelf_pasm_cmds). Note how the -node option is required too
            push(@shelf_pasm_cmds,"-node $a{-node} -refresh") if $a{-clearsimstatus};
        } elsif (defined $a{-clearloadstatus}) {
            # Remove -clearloadstatus from unprocessed_args hash 
            delete $unprocessed_args{-clearloadstatus};
            # Add -clearstat to the list of shelfPASM cmds to execute
            # (@shelf_pasm_cmds). Note how the -node option is required too
            push(@shelf_pasm_cmds,"-node $a{-node} -clearstat") if $a{-clearloadstatus};
        }
        
        if ( $a{-logfile} ) {
            # Format: -logfile <logname> -decode <decode_level 0-4>
            # Remove -logfile from unprocessed_args hash             
            delete $unprocessed_args{-logfile};            

            # If -logfile does not have full path specified i.e. does not contain '/' then prefix path
            if ( ! ($a{-logfile} =~ m/\//)) {
                $a{-logfile} = "$self->{LOG_DIR}" . "/$a{-logfile}";
            }
            
            if (defined $a{-decode}) {
                if ( $a{-decode} < 0 or $a{-decode} > 4 ) {
                    # Check value of specified -decode is valid
                    $logger->error(__PACKAGE__ . ".$sub Invalid -decode level value ($a{-decode}); expected: 0, 1, 2, 3, or 4");
                    return 0;
                }
            } else {
                # Default value of -decode if undefined
                $a{-decode} = 4;    
            }
                
            # Remove -decode from unprocessed_args hash
            delete $unprocessed_args{-decode} if $unprocessed_args{-decode};

            if ( $self->cmd( -cmd => "touch \"$a{-logfile}\"") ) {
                $logger->error(__PACKAGE__ . ".$sub Unable to create MGTS Log \"$a{-logfile}\"\n");
                return 0;
            }
        
            # Add -log and -decode to the list of shelfPASM cmds to execute
            # (@shelf_pasm_cmds). Note how the -node option is required too
            push(@shelf_pasm_cmds,"-node $a{-node} -log " . "\"$a{-logfile}\"" . " -decode " . $a{-decode});        
        }
        
        # Check to ensure that both -sequence and -machine are not specified          
        if ( $a{-sequence} && $a{-machine} ) {
            $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-sequence' and '-machine' cannot both be specified\n");
            return 0;
        }
        
        if ( defined ($a{-run}) ) {
            # Ensure -stop arg not specified together with -run
            if ( defined($a{-stop}) ) {
                $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-run' and '-stop' cannot both be specified\n");
                return 0;   
            }
            
            # Remove -run from unprocessed_args hash
            delete $unprocessed_args{-run};
            
            if ($a{-machine} ) {
                # Remove -machine from unprocessed_args hash
                delete $unprocessed_args{-machine};
                if (defined $a{-runOnceForLoad}) {
                    delete $unprocessed_args{-runOnceForLoad};
                    $shelf_pasm_args = "-machine " . "\"$a{-machine}\"";
                } else {
                    $shelf_pasm_args = "-machine " . "\"$a{-machine}\"" . " -run";
                }
            } elsif ( $a{-sequence} ) {
                # Remove -sequence from unprocessed_args hash
                delete $unprocessed_args{-sequence};
                if (defined $a{-runOnceForLoad}) {
                    delete $unprocessed_args{-runOnceForLoad};
                    $shelf_pasm_args = "-sequence " . "\"$a{-sequence}\"";
                } else {
                    $shelf_pasm_args = "-sequence " . "\"$a{-sequence}\"" . " -run";
                }
            } else {
                $shelf_pasm_args = "-run";
            }
            
            # Wait for run cmd to terminate before exiting if -wait arg set
            if ( defined $a{-wait} ) {
                # Remove -wait from unprocessed_args hash
                delete $unprocessed_args{-wait};
                if ($a{-wait}) {
                    $shelf_pasm_args = $shelf_pasm_args . " -wait";
                }
            }
            # Add the shelf_pasm_arg cmd for -run to the list of shelfPASM cmds to execute
            # (@shelf_pasm_cmds). Note how the -node option is required too
            push(@shelf_pasm_cmds,"-node $a{-node} ". $shelf_pasm_args);
        } elsif ( defined($a{-stop}) ) {
            # Remove -stop from unprocessed_args hash
            delete $unprocessed_args{-stop};
            
            if ($a{-machine} ) {
                # Remove -machine from unprocessed_args hash
                delete $unprocessed_args{-machine};
                $shelf_pasm_args = "-machine " . "\"$a{-machine}\"" . " -stop";
            } elsif ( $a{-sequence} ) {
                # Remove -sequence from unprocessed_args hash
                delete $unprocessed_args{-sequence};
                $shelf_pasm_args = "-sequence " . $a{-sequence} . " -stop";
            } else {
                $shelf_pasm_args = "-stop";
            }
            # Add the shelf_pasm_arg cmd for -stop to the list of shelfPASM cmds to execute
            # (@shelf_pasm_cmds). Note how the -node option is required too
            push(@shelf_pasm_cmds,"-node $a{-node} " . $shelf_pasm_args);
        }
        
        if (defined $a{-stoplog}) {
                
            delete $unprocessed_args{-stoplog};
            push(@shelf_pasm_cmds,"-node $a{-node} -log");
        }
    }
    
    # Check to ensure there are no other invlid arguments defined.
    if (_invalidArgs($sub,"",%unprocessed_args)) {
        return 0;   
    }
    
    # Ensure there is at least one shelfPASM cmd specified. Error if not.
    if ($#shelf_pasm_cmds < 0 ) {
        $logger->error(__PACKAGE__ . ".$sub Missing argument(s). No valid shelfPASM arguments have been defined\n");
        return 0;
    }
    
    # Loop through all the shelfPASM command arguments, executing each in turn.
    foreach my $shelf_cmd_args (@shelf_pasm_cmds) {
        $logger->debug(__PACKAGE__ . ".$sub Calling shelfPASM for shelf '$shelf_id' with args '$shelf_cmd_args'");
    
#sleep 1;
        # Run the shelfPASM cmd with supplied args defined in $shelf_cmd_args
        if ( my $shelf_pasm_failure_reason = $self->cmd( -cmd => "shelfPASM $shelf_id $shelf_cmd_args", -timeout => $a{-timeout}) ) {
        
            # If possible, report failure with actual shelfPASM error messages using
            # the shelf_pasm_error_codes hash defined above.
            my $failure_reason = "Unknown error code #${shelf_pasm_failure_reason}";
            if (defined $shelf_pasm_error_codes{$shelf_pasm_failure_reason}) {
                $failure_reason = $shelf_pasm_error_codes{$shelf_pasm_failure_reason};
            }
            $logger->error(__PACKAGE__ . ".$sub Unable to execute shelfPASM command for shelf '$shelf_id'. Failure reason:\"$failure_reason\"\n");
            return 0;
        }
        #log is failing if dellay is not put for refresh
        sleep 1 if (($shelf_cmd_args =~ /\-log/) || ($shelf_cmd_args =~ /\-refresh/)) ;
        sleep 1 if ($shelf_cmd_args =~ /\-run/);

        $logger->debug(__PACKAGE__ . ".$sub Successfully executed shelfPASM command for shelf '$shelf_id'. Command: \"shelfPASM $shelf_id $shelf_cmd_args\"");
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;   
}


=head2 startExecWait()

Start execution of simulation state machine(s) and either wait for state machine to complete
execution or if the test is not completed within a specified time period then a timeout occurs.

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional arguments:

    -machine => <state machine name>
        State machine to execute, if "" (or not defined) then either -sequence
        or the whole sequence group is executed
    or
    -sequence => <state sequence number>
        sequence number of state machine to execute, if "" (or not defined) then
        either -machine or the whole sequence group

    -reset_stats => <0 or 1>
        Reset stats before executing state machine(s);
            Valid values:   0 (don't reset) or 1 (reset)
            Default value:  1 (reset)

    -logfile => <log file name>
        Name of the file to log state machine execution; the file is created in
        $mgtsObj->{LOG_DIR} which defaults to ~/Logs

    -decode => <0 to 4>
        MGTS log decode level; 0 (no decoding), 1, 2, 3, or 4 (full decodes);
            Vslid values:   0 to 4
            Default value:  4

    -timeout => <timeout in seconds>
        How long to wait for the state machine(s) to complete execution
            Valid values: positive integer
            Default value: 60 seconds for individual state machines and 60
                           multiplied by number of state machines in seq group
                           for the entire sequence group.

    -stoplog => ""
        Stops MGTS logging. Flushes the MGTS log buffer.

=item Returns:

    Command exit code:
    * 1 - state machine(s) executed
    * 0 - otherwise 

=back

=cut

sub startExecWait {
    my ($self, %args) = @_;
    my $sub = "startExecWait()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed  
    my %a = ( -reset_stats => 1,
              -decode      => 4, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    my $shelf_id = $self->_getShelfPasmId();
    
    my $reset_stats = $a{-reset_stats};
    # Remove -reset_stats key from hash so that we can pass whole hash through
    # to shelfPasm() fn later where -reset_stats is an invalid argument.
    delete $a{-reset_stats};
    
    # Check to ensure that both -sequence and -machine are not specified          
    if ( defined($a{-sequence}) && defined($a{-machine}) ) {
        $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-sequence' and '-machine' cannot both be specified\n");
        return 0;
    } elsif ( $a{-machine} ) {
        $logger->info(__PACKAGE__ . ".$sub Getting state machine '$a{-machine}' ready for execution on shelf '$shelf_id' node '$a{-node}'");
        unless ( $a{-timeout} ) { $a{-timeout} =  60; }
    } elsif ( $a{-sequence} ) {
        $logger->info(__PACKAGE__ . ".$sub Getting state sequence '$a{-sequence}' ready for execution on shelf '$shelf_id' node '$a{-node}'");
        unless ( $a{-timeout} ) { $a{-timeout} =  60; }
    } else {
        $logger->info(__PACKAGE__ . ".$sub Getting the entire sequence group ready for execution on shelf '$shelf_id' node '$a{-node}'");
        unless ( $a{-timeout} ) {
            if ((my $state_count = $self->getSeqList()) > 0) {
                $a{-timeout} =  60 * $state_count;
            } else {
                $logger->error(__PACKAGE__ . ".$sub Failed to find state machine(s) in seq list to execute on shelf '$shelf_id' node '$a{-node}'");
                return 0;    
            }
        }
    }

    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; }
    
    # Run the _shelfPasm fn() with -run, -wait and -clearsimstatus flags
    # Rest of args are passed into the _shelfPasm() fn in the %a hash
    # If any invalid args are specified they will be processed within that fn.
    unless ( $self->_shelfPasm( %a, -run => 1, -wait => 1, -clearsimstatus => $reset_stats) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute state machine on shelf '$shelf_id' node '$a{-node}'");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub Completed execution on shelf '$shelf_id' node '$a{-node}'");            
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;  
}


=head2 startExecContinue()

Start execution of load or simulation state machine(s) without waiting for state
machine(s) to finish.

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional arguments:

    -machine => <state machine name>
        State machine to execute, if "" (or not defined) then either -sequence
        or the whole sequence group is executed
    or
    -sequence => <state sequence number>
        sequence number of state machine to execute, if "" (or not defined) then
        either -machine or the whole sequence group

    -load => <0 or 1>
        Indicates test type whether it is load or simulation
            Valid values:  0 (simulation) or 1 (load)
            Default value: 0 (simulation)

    -reset_stats => <0 or 1>
        Reset stats before executing state machine(s);
            Valid values:   0 (don't reset) or 1 (reset)
            Default value:  1 (reset)

    -logfile => <log file name>
        Name of the file to log state machine execution; the file is created in
        $mgtsObj->{LOG_DIR} which defaults to ~/Logs

    -decode => <0 to 4>
        MGTS log decode level; 0 (no decoding), 1, 2, 3, or 4 (full decodes);
            Vslid values:   0 to 4
            Default value:  4

    -timeout => <timeout in seconds>
        How long to wait for the start (no wait) state machine(s) cmd to complete
        execution.
            Valid value: positive integer
            Default value: defaults to $mgtsObj->{DEFAULTTIMEOUT} inside
                           _shelfPasm fn() if not specified

    -runOnceForLoad => <run the state machine once i.e. without a -run or -stop parameter>
        If required to run a state machine without the -run or -stop parameter,
        this must be set.
           Valid value: 1 , if reqd to run once
                    or  0 , if want to run for an indefinite period.( i.e. with -run parameter )

=item Returns:

    Command exit code:
    * 1 - state machine(s) started
    * 0 - otherwise 

=back

=cut

sub startExecContinue {
    my ($self, %args) = @_;
    my $sub = "startExecContinue()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = (-reset_stats => 1,
             -timeout     => $self->{DEFAULTTIMEOUT},
             -load        => 0, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    my $shelf_id = $self->_getShelfPasmId();
    
    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; }
    
    # Check to ensure that both -sequence and -machine are not specified          
    if ( defined($a{-sequence}) && defined($a{-machine}) ) {
        $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-sequence' and '-machine' cannot both be specified\n");
        return 0;
    } elsif ( $a{-machine} ) {
        $logger->info(__PACKAGE__ . ".$sub Getting state machine '$a{-machine}' ready for execution on shelf '$shelf_id' node '$a{-node}'");
    } elsif ( $a{-sequence} ) {
        $logger->info(__PACKAGE__ . ".$sub Getting state sequence '$a{-sequence}' ready for execution on shelf '$shelf_id' node '$a{-node}'");
    } else {
        $logger->info(__PACKAGE__ . ".$sub Getting the entire sequence group ready for execution on shelf '$shelf_id' node '$a{-node}'");
    }

    my $clear_option;
    my $execution_mode;
    # Have to prevent MGTS logging when running load
    if ( $a{-load} ) {
        foreach (qw/ -logfile -decode /) { unless ( $_ ) { $logger->error(__PACKAGE__ . ".$sub '$_' arg cannot be used under load"); return 0; } }
        
        $clear_option = "-clearloadstatus";
        $execution_mode = "load";
    } else {
        # Set the decode if log file is requested and decode level is not set
        if($a{-logfile}) {
           unless ( exists $a{-decode} ) { $a{-decode} = 4; }
        }
        $clear_option = "-clearsimstatus";
        $execution_mode = "simulation";        
    }

    # Added by Malc - shelfPASM doesn't accept -machine or -sequence for LOAD state machines 
	# Ixia SR 136794 has been raised for this issue... so warn the user
#    if ( $a{-load} ) {
#	    if ( $a{-machine} || $a{-sequence} ) {
#		    $logger->error(__PACKAGE__ . ".$sub -load specified with -machine or -sequence - currently unsupported by Ixia/Catapult - see SR 136794 or Malc for details");
#		    return 0;
#		}
#	}
    
    # Remove -load and -reset_stats keys from hash so that we can pass whole hash
    # through to shelfPasm() fn later where -load and -reset_stats are invalid
    # arguments.
    delete $a{-load};
    my $reset_stats = $a{-reset_stats};
    delete $a{-reset_stats};
    
    # Run the _shelfPasm fn() with -run, and $clear_option flags
    # Rest of args are passed into the _shelfPasm() fn in the %a hash
    # If any invalid args are specified they will be processed within that fn.
    unless ( $self->_shelfPasm( %a, -run => 1, -wait => 0, $clear_option => $reset_stats) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to start state machine(s) on shelf '$shelf_id' node '$a{-node}' in '$execution_mode' mode");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub Started state machine(s) on shelf '$shelf_id' node '$a{-node}' in '$execution_mode' mode");   
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return 1;  
}


=head2 stopExec()

Terminates execution of load or simulation state machine(s)

=over

=item Mandatory Arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional arguments:

    -machine => <state machine name>
        State machine to execute, if "" (or not defined) then either -sequence
        or the whole sequence group is executed
    or
    -sequence => <state sequence number>
        sequence number of state machine to execute, if "" (or not defined) then
        either -machine or the whole sequence group

   -timeout => <timeout in seconds>
        How long to wait for the stop state machine(s) cmd to complete execution.
            Valid value: positive integer
            Default value: defaults to $mgtsObj->{DEFAULTTIMEOUT} inside
                           _shelfPasm fn() if not specified

=item Returns:

    Command exit code:
    * 1 - state machine(s) stopped
    * 0 - otherwise 

=back

=cut

sub stopExec {
    my ($self, %a) = @_;
    my $sub = "stopExec()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; } 

    my $shelf_id = $self->_getShelfPasmId();

    # Check to ensure that both -sequence and -machine are not specified          
    if ( defined($a{-sequence}) && defined($a{-machine}) ) {
        $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-sequence' and '-machine' cannot both be specified\n");
        return 0;
    }
    
    # Stop state machine/sequence group on the node
    # Arg -node and optionally -machine, -sequence and -timeout will pass through via hash '%a'
    # Other args wil be processed for validity in _shelfPasm() fn.
    unless ( $self->_shelfPasm( -stop => 1, %a ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to stop running state machine(s) on shelf '$shelf_id' node '$a{-node}'\n$self->{OUTPUT}");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub Stopped state machine(s) on shelf '$shelf_id' node '$a{-node}'");   
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");   
    return 1;
}


=head2 runStateReturnResult()

Execute a simulation state machine and wait for state machine to complete
execution or if the state machine is not completed within a specified
time period then a timeout occurs and the state is stopped. Reyrn the result of
the execution of the state machine.

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

    -machine => <state machine name>
        State machine to execute, if "" (or not defined) then either -sequence
        or the whole sequence group is executed
    or
    -sequence => <state sequence number>
        sequence number of state machine to execute, if "" (or not defined) then
        either -machine or the whole sequence group

    -logfile => <log file name>
        Name of the file to log state machine execution; the file is created in
        $mgtsObj->{LOG_DIR} which defaults to ~/Logs

=item Optional arguments:

    -timeout => <timeout in seconds>
        How long to wait for the state machine(s) to complete execution
            Valid values: positive integer
            Default value: 60 seconds for individual state machines and 60
                           multiplied by number of state machines in seq group
                           for the entire sequence group.

=item Returns:

    Command exit code:
    *  1 - state machine passed
    *  0 - state machine failed
    * -1 - state machine was not executed or result was inconclusive
    * -2 - error occurred in result processing

=back

=cut

sub runStateReturnResult {
    my ($self, %args) = @_;
    my $sub = "runStateReturnResult()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed  
    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    my $shelf_id = $self->_getShelfPasmId();
        
    # Check to ensure that both -sequence and -machine are not specified          
    if ( ( defined($a{-sequence}) && defined($a{-machine}) ) || (!(defined $a{-sequence} || defined $a{-machine})) ) {
        $logger->error(__PACKAGE__ . ".$sub One (and only one) of the '-sequence' or '-machine' args must be specified\n");
        return -2;
    }

    # Verify required -node argument defined
    foreach (qw/ -node -logfile /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return -2; }}
    
    # Run the startExecWait fn() with -decode and -reset_stats flags
    # Rest of args are passed into the startExecWait() fn in the %a hash
    # If any invalid args are specified they will be processed within that fn.
    unless ( $self->startExecWait( %a, -decode => 4, -reset_stats => 1, -stoplog => 1 ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute state machine on shelf '$shelf_id' node '$a{-node}'");
        return -2;
    } else {
        $logger->info(__PACKAGE__ . ".$sub Completed execution on shelf '$shelf_id' node '$a{-node}'");
    }
    
    if ( $self->areStatesRunning( -node => $a{-node} )) {
        $logger->error(__PACKAGE__ . ".$sub State machine failed as state machine is still executing (possibly on PASM scripting timeout) on shelf '$shelf_id' node '$a{-node}'");
        unless ( $self->ensureNoStatesRunning( -node => $a{-node} )) {
            $logger->error(__PACKAGE__ . ".$sub Failed to forcefully stop execution of state machine on shelf '$shelf_id' node '$a{-node}'");
            return -2;
        }
        # Test failed return 0;
        return 0 ; 
    }
 
    # Get result of test execution. Pass = 1, Fail = 0, Inconclusive = -1.
    my $test_result = $self->checkResult( %a, -readresults => 1);
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function (success)");
    return $test_result;  
}

=head2 getSeqList()

List download state machines (sequences)

=over

=item Mandatory argument:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional argument:

    -timeout => <timeout in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * $test_count - on success returns the total number of state machines in sequence list
                    and a list of sequences is returned in a hash of the form:
                        $mgtsObj->{SEQLIST}->{<node_name>}->{SEQUENCE}{<sequence_no>} = <state_machine_desc>
                    and $mgtsObj->{SEQLIST}->{<node_name>}->{MACHINE}{state_machine_desc>} = <sequence_no>         
    * 0 - otherwise

=back

=cut

sub getSeqList {
    my ($self, %args) = @_;
    my $sub = "getSeqList()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = (-timeout => $self->{DEFAULTTIMEOUT});
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; } 

    my $shelf_id = $self->_getShelfPasmId();
    
    $logger->info(__PACKAGE__ . ".$sub Getting list of downloaded state machines and populating seqlist hash");    

    # List state machines downloaded on the node
    # Args -node and -timeout will pass through via hash '%a'
    unless ( $self->_shelfPasm( -seqlist => 1, %a ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read loaded state machines on shelf '$shelf_id' node '$a{-node}'\n$self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Got seqlist");
    
    }

    # Reset sequence list
    delete $self->{SEQLIST}->{$a{-node}};  
    
    # Process returned seqlist a line at a time
    foreach ( split /\n/, $self->{OUTPUT} ) {
        
        # Get sequence number from seqlist results
        # Normal format of seqlist is:
        #   <seq no> - <state machine>           for p400/m500
        #   <number> <seq no> <state machine>    for i2000 and 10.5/13.0 releases
        #
        if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
            if ( m/^([0-9]+) +- +(.*)$/ ) {
                $logger->debug(__PACKAGE__ . ".$sub Setting \$self->\{SEQLIST\}->\{$a{-node}\}->\{SEQUENCE\}\{$1\} = '$2'");
                $self->{SEQLIST}->{$a{-node}}->{SEQUENCE}{$1} = $2;
                $logger->debug(__PACKAGE__ . ".$sub Setting \$self->\{SEQLIST\}->\{$a{-node}\}->\{MACHINE\}\{$2\} = '$1'");
                $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$2} = $1;
            }   
        } else {
            if ( m/^ +[0-9]+  ([0-9]+) +(.*)$/ ) {
                $logger->debug(__PACKAGE__ . ".$sub Setting \$self->\{SEQLIST\}->\{$a{-node}\}->\{SEQUENCE\}\{$1\} = '$2'");
                $self->{SEQLIST}->{$a{-node}}->{SEQUENCE}{$1} = $2;
                $logger->debug(__PACKAGE__ . ".$sub Setting \$self->\{SEQLIST\}->\{$a{-node}\}->\{MACHINE\}\{$2\} = '$1'");
                $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$2} = $1;
            }
        }
    }   
    
    # Get size of sequence hash which will indicate the number of state machines (sequences)
    my $test_count = keys (%{$self->{SEQLIST}->{$a{-node}}->{SEQUENCE}}) ;
    if ($test_count <= 0) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read format of sequence list. Unable to populate seqlist hash");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    # Return number of state machines
    return $test_count;
}


=head2 getSeqFlavor()

Get the protocol "flavor" of the sequence group file

=over

=item Mandatory argument:

    -seqgrp <name of MGTS sequence group to identify protocol from>
        Sequence group file (without the .sequenceGroup extension)

=item Optional argument:

    -segrp_path <path to seqgrp>
        Full path to sequence group file. If arg is omitted then defaults to $MGTS_DATA

    -timeout => <timeout in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * seq grp flavor string e.g. "ANSI-SS7" etc
    * "" - empty string otherwise

=back

=cut

sub getSeqFlavor {
    my ($self, %args) = @_;
    my $sub = "getSeqFlavor()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = (-seqgrp_path => "\$MGTS_DATA",
             -timeout      => $self->{DEFAULTTIMEOUT});
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required -seqgrp argument defined
    unless ( $a{-seqgrp} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-seqgrp' required"); return ""; } 
    
    $logger->info(__PACKAGE__ . ".$sub Getting protocol flavor of sequence group \"$a{-seqgrp}\"");    

    my $sequence_group = $a{-seqgrp};
    
    unless ( $sequence_group =~ /\.sequenceGroup$/ ) { $sequence_group = "$sequence_group.sequenceGroup";}
     
    if ( $self->cmd( -cmd => "test -e $a{-seqgrp_path}/$sequence_group" )) {
        $logger->error(__PACKAGE__ . ".$sub Sequence group file '$a{-seqgrp_path}/$sequence_group' does not exist");
        return "";
    }        

    if ( $self->cmd( -cmd => "grep FLAVOR= $a{-seqgrp_path}/$sequence_group" )) {
        $logger->error(__PACKAGE__ . ".$sub Failed to get 'FLAVOR' from '$sequence_group': $self->{OUTPUT}");
        return "";
    }
 
    # Find FLAVOR in sequence group file grp output
    my $seq_flavor = "";
    if ( $self->{OUTPUT} =~ /FLAVOR=(.*)/ ) {
        $seq_flavor = "$1";
    } else {
        $logger->error(__PACKAGE__ . ".$sub Sequence group '$sequence_group' does not contain a flavor line");
        return "";
    }
    
    return "$seq_flavor";
}


=head2 _resetStats()

Reset sequence group stats

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional arguments:

    -load => <0 or 1>
        Indicates test type whether it is load or simulation
            Valid values:  0 (simulation) or 1 (load)
            Default value: 0 (simulation)
    -timeout => <timeout in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * 1 - on success
    * 0 - otherwise

=back

=cut

sub _resetStats {
    my ($self, %args) = @_;
    my $sub = "_resetStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = ( -load    => 0,
              -timeout => $self->{DEFAULTTIMEOUT}
            );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; } 

    # load vs. simulation
    my $option;
    if ( $a{-load} ) {
        $option = "-clearloadstatus";
        delete $self->{STATS}->{$a{-node}};
    } else {
        $option = "-clearsimstatus";
        delete $self->{RESULTS}->{$a{-node}};
    }

    my $shelf_id = $self->_getShelfPasmId();

    # Clear stats
    # Args -clearloadstatus or -clearsimstatus passed by $option
    unless ( $self->_shelfPasm(-node => $a{-node}, $option => 1, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to clear stats on shelf '$shelf_id' node '$a{-node}'\n$self->{OUTPUT}");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;    
}


=head2 _readResults()

Retrieve sequence group results

=over

=item Mandatory argument:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional argument:

    -timeout => <timeout in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * number of read results
    * 0 otherwise

    For  node <node> subroutine returns sequence group results in the following hashes:

    * for state machine <machine>:
        $mgtsObj->{RESULTS}->{<node>}->{MACHINE}{<machine>}

    * for sequence <sequence>:
        $mgtsObj->{RESULTS}->{<node>}->{SEQUENCE}{<sequence>}

=back

=cut

sub _readResults {
    my ($self, %args) = @_;
    my $sub = "_readResults()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = (-timeout => $self->{DEFAULTTIMEOUT} );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; } 

    my $shelf_id = $self->_getShelfPasmId();

    # Reset results (if defined)
    delete $self->{RESULTS}->{$a{-node}} if defined $self->{RESULTS}->{$a{-node}};  

    # Read 'passed' results
    unless ( $self->_shelfPasm( -node => $a{-node}, -passed => 1, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read 'passed' results for shelf '$shelf_id' node '$a{-node}'\n$self->{OUTPUT}");
        return 0;
    }   

    # Loop through 'passed' results returned line by line and set hash accordingly
    my $pass_seq_count = 0;
    my @pass_state_name_ary;
    # Set test result to be -1 (inconclusive)
    my $test_result;
    foreach ( split /\n/, $self->{OUTPUT} ) {
        if ( m/^\s+([\d]+)\s+(.*)$/ ) {
            $pass_seq_count += 1;
            
            # set array of state machine names to compare later with failed list
            $pass_state_name_ary[$pass_seq_count] = $2;
            
            # Set test result to 1 (pass) if passed result > 0 or -1 otherwise            
            if ($1 > 0) {
                $test_result = $1;
            } else {
                $test_result = -1;   
            }

            $self->{RESULTS}->{$a{-node}}->{SEQUENCE}{$pass_seq_count} = $test_result;
            $self->{RESULTS}->{$a{-node}}->{MACHINE}{$2} = $test_result;
        }
    }
    
    # Read 'failed' results
    unless ( $self->_shelfPasm( -node => $a{-node}, -failed => 1, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read 'failed' results for shelf '$shelf_id' node '$a{-node}'\n$self->{OUTPUT}");
        # Clear result list due to error
        delete $self->{RESULTS}->{$a{-node}};
        return 0;
    }   

    # Loop through 'failed' results returned line by line and set hash accordingly
    my $fail_seq_count = 0;
    my $current_state_name;
    foreach ( split /\n/, $self->{OUTPUT} ) {
        if ( m/^\s+([\d]+)\s+(.*)$/ ) {
            $fail_seq_count += 1;
            $current_state_name = $2;
            
            # Check to see whether the current state machine name in the failed
            # list matches the name of the state machine in the equivalent
            # position in the passed list. Critical MGTS Error if not.
            if ($current_state_name ne $pass_state_name_ary[$fail_seq_count]) {
                $logger->error(__PACKAGE__ . ".$sub State machine names do not match in shelfPASM -passed and -failed result lists. Please report to MGTS administrator urgently");
                # Clear result list due to error
                delete $self->{RESULTS}->{$a{-node}};
                return 0;   
            }
            
            # Set test result to 0 (fail) if failed result > 0. The RESULT hash
            # will have been initialised in the passed results above.
            if ($1 > 0) {
                $self->{RESULTS}->{$a{-node}}->{SEQUENCE}{$fail_seq_count} = 0;
                $self->{RESULTS}->{$a{-node}}->{MACHINE}{$current_state_name} = 0;
            }
        }
    }
    
    if ($fail_seq_count != $pass_seq_count) {
        $logger->error(__PACKAGE__ . ".$sub The number of state machines do not match in shelfPASM -passed and -failed result lists. Please report to MGTS administrator urgently");
        # Clear result list due to error
        delete $self->{RESULTS}->{$a{-node}};
        return 0;   
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return $pass_seq_count;
}


=head2 checkResult()

Check whether state machine(s) passed, failed or were inconclusive

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

    -machine => <name of state machine>
        State machine to get result for, if "" (or not defined) then either -sequence or the whole sequence group is used
    or
    -sequence => <sequence number of state machine in grp>
        sequence number of state machine to get result for, if "" (or not defined) then either -machine or the whole sequence group is used

=item Optional arguments: 

    -readresults => <0 or 1>
        1 - reads results from the shelf,
        0 - uses results already retrieved from the shelf if the RESULTS hash
            already exists. Otherwise, it will proceed to read results from the
            shelf to populate the RESULTS hash.
        Default value: 1 (read results)

    -timeout => <timeout in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    *  1 or greater than 1 - state machine passed
    *  0 - state machine failed
    * -1 - state machine was not executed or result was inconclusive
    * -2 - error occurred in result processing

=item Examples:

    my $machine = "EUCIC-01_01_01_02-CGU State Machine";

    if ( my $result = $mgtsObj->checkResult( -node => SSP, -machine => $machine) ) {
        print "$machine PASSED\n";
    } elsif ( $result eq 0 ) {
        print "$machine FAILED\n";
    } else {
        print "No results found for $machine\n";
    }

=back

=cut

sub checkResult {
    my ($self, %args) = @_;
    my $sub = "checkResult()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed
    my %a = ( -timeout      => $self->{DEFAULTTIMEOUT},
              -readresults  => 1 );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return -2; } 

    my $shelf_id = $self->_getShelfPasmId();
        
    # Read results especially if the results have not been read before 
    if ( $a{-readresults} or not ( exists $self->{RESULTS}->{$a{-node}} ) ) {
        unless ( $self->_readResults( %a ) ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to read results for shelf '$shelf_id' node '$a{-node}'");
            return -2;
        }
    }   
    
    # Check to ensure that both -sequence and -machine are not specified          
    if ( defined($a{-sequence}) && defined($a{-machine}) ) {
        $logger->error(__PACKAGE__ . ".$sub Invalid argument combination. '-sequence' and '-machine' cannot both be specified\n");
        return -2;
    } elsif ( $a{-machine} ) {
        if ( exists $self->{RESULTS}->{$a{-node}}->{MACHINE}{$a{-machine}} ) {
            $logger->debug(__PACKAGE__ . ".$sub Leaving function");
            return $self->{RESULTS}->{$a{-node}}->{MACHINE}{$a{-machine}};
        } else {
            $logger->error(__PACKAGE__ . ".$sub Failed to read a result for shelf '$shelf_id' node '$a{-node}' state machine '$a{-machine}'");
            return -2;
        }
    } elsif ( $a{-sequence} ) {
        if ( exists $self->{RESULTS}->{$a{-node}}->{SEQUENCE}{$a{-sequence}} ) {
            $logger->debug(__PACKAGE__ . ".$sub Leaving function");
            return $self->{RESULTS}->{$a{-node}}->{SEQUENCE}{$a{-sequence}};
        } else {
            $logger->error(__PACKAGE__ . ".$sub Failed to read a result for shelf '$shelf_id' node '$a{-node}' state sequence '$a{-sequence}'");
            return -2;
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub Missing argument. Either -sequence or -machine must be specified");
        return -2;
    }
}


=head2 _readLoadStatus()

Retrieve status for load test

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional arguments:

    -timeout
        in seconds; defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * 1 on success
    * 0 otherwise

    For shelf <shelf>, node <node> subroutine returns status in the following data structure:
         $mgtsObj->{STATUS}->{<node>}{run_time}                       - total run time

    and for every state machine <machine> the following information is saved:

         $mgtsObj->{STATUS}->{<node>}->{<machine>}{transmitted}  - number of started Tx instances
         $mgtsObj->{STATUS}->{<node>}->{<machine>}{received}     - number of started Rx instances
         $mgtsObj->{STATUS}->{<node>}->{<machine>}{passed}       - number of instances that reported pass
         $mgtsObj->{STATUS}->{<node>}->{<machine>}{failed}       - number of instances that reported failure
         $mgtsObj->{STATUS}->{<node>}->{<machine>}{inconclusive} - number of inconclusive executions
         $mgtsObj->{STATUS}->{<node>}->{<machine>}{inprogress}   - number of instances in progress

=back

=cut

sub _readLoadStatus {
    my ($self, %args) = @_;
    my $sub = "_readLoadStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed 
    my %a = ( -timeout => $self->{DEFAULTTIMEOUT});
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required -node argument defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; } 

    my $shelf_id = $self->_getShelfPasmId();
    
    # Reset results
    delete $self->{STATUS}->{$a{-node}};  

    # Read test load status
    unless  ( $self->_shelfPasm(-node => $a{-node}, -loadstatus => 1, -timeout => $a{-timeout} ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read load status for shelf '$shelf_id' node '$a{-node}'");
        return 0;   
    }

    foreach ( split /\n/, $self->{OUTPUT} ) {
        # Check for state machine status
        if ( m/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+-\s+(.*)$/ ) {
            $self->{STATUS}->{$a{-node}}->{$7}{transmitted}   = $1;
            $self->{STATUS}->{$a{-node}}->{$7}{received}      = $2;
            $self->{STATUS}->{$a{-node}}->{$7}{passed}        = $3;
            $self->{STATUS}->{$a{-node}}->{$7}{failed}        = $4;
            $self->{STATUS}->{$a{-node}}->{$7}{inconclusive}  = $5;
            $self->{STATUS}->{$a{-node}}->{$7}{inprogress}    = $6;
        } elsif ( m/Run Time = ([0-9:]+)/ ) {
            # Check for run time
            $self->{STATUS}->{$a{-node}}{run_time} = $1;
        }
        # else ignore current line.
    }
    $logger->debug(__PACKAGE__ . ".$sub Got load status for shelf '$shelf_id' node '$a{-node}'");
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 machineStatus()

Read status for load test for state machine

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)
    -machine => <state machine name>
        State machine

=item Optional argument:

    -readstatus => <0 or 1>
        1 - reads status from the shelf
        0 - uses status already retrieved from the shelf if already obtained;
            Reads status otherwiase
        Default Value: 0
    -timeout => <MGTS cmd timeout value in seconds>
        Defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * A list of key value pairs, see below
    * empty list, otherwise

    Keys:

         * transmitted  - number of started Tx instances
         * received     - number of started Rx instances
         * passed       - number of instances that reported pass
         * failed       - number of instances that reported failure
         * inconclusive - number of inconclusive executions
         * inprogress   - number of instances in progress

=back

=cut

sub machineStatus {
    my ($self, %args) = @_;
    my $sub = "machineStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed   
    my %a = ( -readstatus => 0, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
  
    # Verify required arguments defined
    foreach (qw/ -node -machine /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return (); } }
    
    my $shelf_id = $self->_getShelfPasmId();
    
    if ( $a{-readstatus} or not ( exists $self->{STATUS}->{$a{-node}} ) ) {
        unless ( _readStatus ( %a ) ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to read status for shelf '$shelf_id' node '$a{-node}'");
            return ();
        }
    }   
    
    unless ( exists $self->{STATUS}->{$a{-node}}->{$a{-machine}} ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to get status for shelf '$shelf_id' node '$a{-node}' state machine '$a{-machine}'");
        return ();
    }   
    
    my @status = %{$self->{STATUS}->{$a{-node}}->{$a{-machine}}};
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return @status;
}


=head2 downloadLog()

Download log from the MGTS server

=over

=item Mandatory Arguments:

    -logfile => <MGTS log filename>
        File to download

=item Optional arguments:

    -local_dir
        Where, on the local machine, the file is to be stored
        Defaults to the current working directory
    -local_name
        Defaults to -logfile
    -delete
        Indicates whether the log is to be deleted on the MGTS server; defaults to 1

=item Returns:

    * 1 on success
    * 0 otherwise

=back

=cut

sub downloadLog {
    my ($self, %args) = @_;
    my $sub = "downloadLog()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed 
    my %a = ( -remote_dir => $self->{LOG_DIR},
              -local_dir  => ".",
              -delete     => 1, );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    $a{-local_name} ||= $a{-logfile};

    # Verify required arguments defined
    foreach (qw/ -logfile -local_name -remote_dir -local_dir/) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0"); return 0; } }

    my $local_path  = $a{-local_dir} . "/" . $a{-local_name};
    my $remote_path = $a{-remote_dir} . "/" . $a{-logfile};

    # ASSUMPTION: It is assumed that the local mount is mounted with the directories
    #             in the same place as those located on the MGTS server
    #             i.e. if MGTS_DATA was /home/mymgtsuser/datafiles on the MGTS server
    #                  then /home/mymgtsuser/datafiles will be on the local ATS server
    unless ( $self->cmd( -cmd => "test -e $remote_path " ) == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to find file '$remote_path' on local server. Using FTP instead");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub MGTS Log file \"$remote_path\" exists");
    }			
   
    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    $scpArgs{-destinationFilePath} = $local_path;
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$remote_path;
    if (&SonusQA::Base::secureCopy(%scpArgs)) {
            $logger->debug(__PACKAGE__ . ".$sub:  $a{-logfile} Copied from MGTS $a{-local_name} ");
    }
    if ( $a{-delete} ) {
        # Remove MGTS log from MGTS server if -delete specified as 1
        $logger->debug(__PACKAGE__ . ".$sub Deleting file '${remote_path}'");
        if ($self->cmd( -cmd => "rm -f ${remote_path}", %a ) ) {
            $logger->warn(__PACKAGE__ . ".$sub Failed to remove MGTS log file '${remote_path}': $!");
        }
    }     

    $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-1");
    return 1;
}


=head2 uploadFromRepository()

Copy MGTS files from a repository account

=over

=item Mandatory arguments:

    -account
        MGTS repository account, e.g., stack2
    -file_to_copy
        File to copy from repository, i.e., an assign file

=item Optional arguments:

    -filepath
        Location of the file, e.g., /home/stack2/datafiles
    -protocol
        MGTS Protocol flavor;
        Default value: $mgtsObj->{PROTOCOL} - the protocol
        used at object's instantiation and/or passed to startSession()

=item Returns:

    * 1 on success
    * 0 otherwise

=back

=cut

sub uploadFromRepository {
    my ($self, %args) = @_;
    my $sub = "uploadFromRepository()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed 
    my %a = ( -protocol => $self->{PROTOCOL}, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    foreach (qw/ -account -file_to_copy /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return 0; } }

    my $tarfile = "$a{-file_to_copy}-$a{-account}";
    
    my $account = $a{-account};

    my $tar_extraction_output;

    # Verify file path arg specified
    if ( exists $a{-filepath} ) {
        
        # Verify path is not blank 
        if ( $a{-filepath} =~ /^\s*$/ ) {
            $logger->error(__PACKAGE__ . ".$sub -filepath argument must not be blank.");
            return 0;    
        }
        
        # Verify file exists in current path
        if ( $self->cmd( -cmd => "ls $a{-filepath}/$a{-file_to_copy}" ) ) { 
            $logger->error(__PACKAGE__ . ".$sub File '$a{-filepath}/$a{-file_to_copy}' does not exist? $self->{OUTPUT}");
            return 0;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Successfully listed file '$a{-filepath}/$a{-file_to_copy}'");     
        }
        
        # Append the path to account username for use with fileManagerS below
        $account = $account . ":" . $a{-filepath};
    }

    if ( $self->cmd( -cmd => "cd \$MGTS_DATA" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to cd into \$MGTS_DATA directory: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully cd'd into \$MGTS_DATA directory");    
    }

    # MGTS work around... need the target file in the directory before you can copy to it!
    if ( $self->cmd( -cmd => "touch $a{-file_to_copy}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to create $a{-file_to_copy}: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully touch'ed '$a{-file_to_copy}' file");     
    }
    
    # Need protocol specified if file to be tarred is a udm file
    my $protocol = "";
    if ( $a{-file_to_copy} =~ m/\.udm$/ ) { $protocol = "-p $a{-protocol}"; }
  
    $logger->info(__PACKAGE__ . ".$sub Copying '$a{-file_to_copy}' file from MGTS account '$account'");

    # Copy the files from the repository  
    if ( $self->cmd( -cmd => "fileManagerS -u $account $protocol -t $tarfile -F $a{-file_to_copy} -f" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to copy file '$a{-file_to_copy}' from account '$account' using fileManagerS: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully tar'ed '$a{-file_to_copy}' file and dependencies using fileManagerS");       
    }
    
    # Extract the tar file    
    if ( $self->cmd( -cmd => "tar -xvf ${tarfile}.tar" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to untar ${tarfile}.tar: $self->{OUTPUT}");
        return 0;
    } else {
        $tar_extraction_output = $self->{OUTPUT}; 
        $logger->info(__PACKAGE__ . ".$sub Successfully copied '$a{-file_to_copy}' file and its dependencies from MGTS account '$account'");    
        $self->cmd( -cmd => "ls -l $a{-file_to_copy}");
    }

    # Remove the tar file 
    if ( $self->cmd( -cmd => "rm -f ${tarfile}.tar" ) ) {
        $logger->warn(__PACKAGE__ . ".$sub Failed to delete ${tarfile}.tar: $self->{OUTPUT}");
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully removed '${tarfile}.tar' file");    
    }
    
    # Ensure we are set to the HOME directory of the MGTS user
    if ( $self->cmd( -cmd => "cd " ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to cd to HOME directory: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully cd'd to HOME directory");
    }
   
    # Setting $self->{OUTPUT} to contents of extracted tar
    $self->{OUTPUT} = $tar_extraction_output;
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    
    return 1;
}


=head2 modifyNetworkMap()

Assigns given sequence group to simulated nodes in the given network map file

=over

=item Mandatory arguments:

    -network
        Network map file; without the .Network extension (overrules -assignment if specified)
    -assignment
        Network-Shelf Assignment name; without the extension.
    -node[1-9]
        Multiple - Name of simulated node to modify corresponding sequence group
    -seqgrp[1-9]
        Multiple - -Name of the sequence group to be assigned for corresponding node name

=item Optional arguments (FTP related):

    -debug
        FTP debug flag; defaults to 1 when $mgtsObj->{LOG_LEVEL} is DEBUG and to 0 otherwise
    -protocol
        Protocol to try first: FTP or SFTP; defaults to FTP when $mgtsObj->{COMM_TYPE} is TELNET and to STFP otherwise
    -host
        Defaults to $mgtsObj->{OBJ_HOST}
    -user
        Defaults to $mgtsObj->{OBJ_USER}
    -password
        Defaults to $mgtsObj->{OBJ_PASSWORD}

    Notes:
        -network takes precedence over -assignment;

=item Returns:

    * 1 on success
    * 0 otherwise

=back

=cut

sub modifyNetworkMap {
    my ($self, %args) = @_;
    my $sub = "modifyNetworkMap()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed 
    my %a = (-host       => $self->{OBJ_HOST},
             -user       => $self->{OBJ_USER},
             -password   => $self->{OBJ_PASSWORD},
            );
    
    if ( $self->{COMM_TYPE} eq "TELNET" ) { $a{-protocol} = "FTP"; } else { $a{-protocol} = "SFTP"; }
    if ( $self->{LOG_LEVEL} eq "DEBUG" ) { $a{-debug} = 1; } else { $a{-debug} = 0; }
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    if ($a{-network}) {
        $self->{NETMAP} = $a{-network};   
    } elsif ($a{-assignment}) { 
        unless ($self->getNetworkMapName( -assignment => $a{-assignment} )) {
            $logger->error(__PACKAGE__ . ".$sub Failed to get Network Map Name from assignment '$a{-assignment}'");
            return 0;
        }
        $a{-network} = $self->{NETMAP};
    } else {
        $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-network' or '-assignment' required");
        return 0;    
    }
    
    # Initialise hash to keep list of node names and their respective seq_grps.
    # Node name will be the hash key.
    my %node_hash;
    
    # Create a hash with pairing of node_name => sequence group name.
    foreach my $node_key (keys %a) {
        #Loop through all the args looking for any args of the form -node[1-9] or -node
        if ($node_key =~ m/^-node([1-9]*)$/) {
            my $node_arg_num = $1;
            
            # Initialise var for seq arg not found
            my $seq_not_found=1;
            
            if ( $a{"-node$node_arg_num"} ) { # node arg exists and is not blank
                my $node_value = $a{"-node$node_arg_num"}; # get node arg value e.g. "SSP"
                
                # Loop through all the args looking for any args of form -seqgrp[1-9] or -seqgrp
                # -node1 <node_name> must correspond to -seqgrp1 <seqgrp_name>
                foreach my $seq_key (keys %a) {  
                    if ($seq_key =~ m/^-seqgrp${node_arg_num}$/) {
                        if ( $a{"-seqgrp$node_arg_num"} ) { # seqgrp arg exists and is not blank
                            $seq_not_found=0;
                            if (exists $node_hash{"$node_value"} ) { # Is the value already specified?
                               $logger->error(__PACKAGE__ . ".$sub Node name '$node_value' for -node${node_arg_num} arg is already specified by another -node[1-9] arg");
                               return 0;
                            }
                            $a{"-seqgrp$node_arg_num"} =~ s/\.sequenceGroup$//g; 
                            $node_hash{"$node_value"} = $a{"-seqgrp$node_arg_num"};
                            last; #Found matching -seqgrp arg. Exit inner for-loop.
                        } else {
                            $logger->error(__PACKAGE__ . ".$sub No value assigned to '-seqgrp${node_arg_num}' argument\n");
                            return 0;
                        }
                    }
                }
                if ($seq_not_found) {
                    # We haven't found a corresponding -seqgrp arg for the node.
                    $logger->error(__PACKAGE__ . ".$sub Missing '-seqgrp${node_arg_num} <seqgrp_name>' arg to pair with '-node$node_arg_num} <node_name>' arg.");
                    return 0;
                }
            } else {
                $logger->error(__PACKAGE__ . ".$sub No value assigned to '-node${node_arg_num}' argument\n");
                return 0;
            }
        }
    }

    if ( $a{-protocol} eq "FTP" ) { $a{-other_protocol} = "SFTP"; } else { $a{-other_protocol} = "FTP"; } 

    # Verify required arguments defined
    foreach (qw/ -network -host -user -password -protocol /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return 0; } }

    my $remote_file;
    if ( $a{-network} =~ /\.Network$/ ) {
        $remote_file = $a{-network};
    } else {
        $remote_file = "$a{-network}.Network";
    }
    my $remote_path = $self->{MGTS_DATA} . "/" . $remote_file;
    
    my $use_ftp_to_copy = 1;
        
    # Before we proceed any further, verify we can write the network map
    if ( $self->cmd( -cmd => "chmod 666 $remote_path" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to change file permissions of '$remote_path' for writing: $self->{OUTPUT}");
        return 0;
    }
    
    # Test if we can access the MGTS file system by local mount to the ATS server
    # If not we need to use FTP to copy the file.
    # ASSUMPTION: It is assumed that the local mount is mounted with the directories
    #             in the same place as those located on the MGTS server
    #             i.e. if MGTS_DATA was /home/mymgtsuser/datafiles on the MGTS server
    #                  then /home/mymgtsuser/datafiles will be on the local ATS server
    if ( -w "$remote_path" ) {
        $use_ftp_to_copy = 0;   
    }
    
    if ($self->cmd( -cmd => "cat $remote_path", %a)) {
        $logger->error(__PACKAGE__ . ".$sub Failed to cat '$remote_path' file: $self->{OUTPUT}");
        return 0;            
    }

    # Create temporary file for Network Map
    my ($tmp_fh, $tmp_filename);
    unless ( ($tmp_fh, $tmp_filename) = tempfile(DIR => "/tmp")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to open temp file for writing: $!");
        return 0;    
    }
        
    my $ssp_node = 0;
    my $stp_node = 0;
    my $isdn_node = 0;
    my $node_name_found = 0;
    my $node_name = "";
    my $seq_name = "";
    my $error_found = 0;

    my $line;
    my %found_node_hash;
    my %available_node_hash;

    # Loop through the Network Map file (now contained in $self->{OUTPUT}) to
    # find the specified nodes and modify the sequence group name appropriately.
    foreach (split /\n/, $self->{OUTPUT}) {
        # Work out which type of node we are currently analysing
        if ( /LAPD : / ) {
          $isdn_node = 1;
          $ssp_node = 0;
          $stp_node = 0;
        } elsif ( /SSP : / ) {
          $ssp_node = 1;
          $isdn_node = 0;
          $stp_node = 0;
        } elsif ( /STP : / ) {
          $ssp_node = 0;
          $isdn_node = 0;
          $stp_node = 1;
        }
        
        if ( (! $stp_node) and /name : +\"(.*)?\"/ ) {
            if ( exists $node_hash{$1} ) {
                $node_name = $1;
                $node_name_found = 1;
                $seq_name = $node_hash{$node_name};
                $found_node_hash{$node_name} = 1;
                
            } else {
                $available_node_hash{$1} = 1;
                $node_name = "";
                $node_name_found = 0;
                $seq_name = "";
            }
        }

        if ( $node_name_found ) {
            
            # Only need to analyse systemType if this is the node
            if ( /systemType : +External/ ) {
                $logger->error(__PACKAGE__ . ".$sub Node '$node_name' is a REAL (Non-simulated MGTS) node so we can't set sequence group");
                $error_found = 1;
                last; # Jump out of loop as there is no point continuing
            }
            
            # Modify the sequence group 
            if ( /(\s*PASM_SEQ_DB : +")(.*)(".*)/s and $ssp_node ) {
                $line = $1 . $seq_name . $3;
                $logger->info(__PACKAGE__ . ".$sub Modifying Node '$node_name' to use Sequence Group '$seq_name'");
                $node_name_found = 0;
            } elsif ( /(\s*sequenceGroup_DB : +")(.*)(".*)/s and $isdn_node ) {
                $line = $1 . $seq_name . $3;
                $logger->info(__PACKAGE__ . ".$sub Modifying Node '$node_name' to use Sequence Group '$seq_name'");
                $node_name_found = 0;
            } else {
                $line = $_;    
            }
        } else {
            $line = $_;
        }
    
        print $tmp_fh $line . "\n";
    }

    close $tmp_fh;
    
    # Ensure all the specified -node[1-9] arguments have been modified else error.
    foreach my $node_key (keys %node_hash) {
        if ( ! $found_node_hash{$node_key} ) {
            my @avail_nodes = (keys %available_node_hash);
            $logger->error(__PACKAGE__ . ".$sub Node '$node_key' was not found in the '$remote_file' Network Map file. Nodes found were: @avail_nodes");
            $error_found = 1;
        }
    }
    
    if ( ! $error_found ) {
        if ( $use_ftp_to_copy ) {
            # Connect
            my $ftp;
        
            $logger->info(__PACKAGE__ . ".$sub Starting FTP session to '$a{-host}'");
        
            unless ( $ftp = Net::xFTP->new( $a{-protocol}, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $a{-debug} ) or
                     $ftp = Net::xFTP->new( $a{-other_protocol}, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $a{-debug} ) ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to connect to $a{-host}\n$@");
                return 0;
            }
        
            # Binary transfer mode
            $ftp->binary();
        
            $logger->debug(__PACKAGE__ . ".$sub Uploading file '$tmp_filename' to '$remote_path' on $a{-host}");
    
            # Put the new network map file
            unless ( $ftp->put( "$tmp_filename", $remote_path ) ) {
                $logger->error(__PACKAGE__ . ".$sub Put failed: ", $ftp->message());
                $error_found = 1;
            }
            
            # Disconnect
            $ftp->quit();
            
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Copying file '${tmp_filename}' to '$remote_path'");
            #unless ( File::Copy::copy("$tmp_filename","$remote_path")) {
            if ( system "/bin/cp", "-f","$tmp_filename","$remote_path" ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to upload Network Map file '$tmp_filename' to '$remote_path'");
                $error_found = 1;
            }
        }
    }    

    # Remove the local file
    if ( system "/bin/rm", "-f", "$tmp_filename" ) {
        $logger->warn(__PACKAGE__ . ".$sub Failed to remove local file: $!");
    }   
    
    # If an error was found above but has not yet returned then return 0
    if ( $error_found ) {
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 areStatesRunning()

Report whether state machine(s) are still running or not
Applies only to PASM Simulation - does NOT apply to load.

=over

=item Mandatory argument:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional argument:

    -timeout
        in seconds; defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    *  1 - if state machine(s) are still running on the node
    *  0 - no state machine(s) running
    * -1 - otherwise

=back

=cut

sub areStatesRunning {
    my ($self, %args) = @_;
    my $sub = "areStatesRunning()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
    # Set default values before args are processed   
    my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return -1; }

    # Test for invalid args in %args hash
    # Must remove -node and -timeout args first
    foreach (qw/ -node -timeout/) {  delete $args{$_} if exists $args{$_} };
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return -1;
    }
    
    my $shelf_id = $self->_getShelfPasmId();
        
    # List any queued or running state machines
    unless ( $self->_shelfPasm(-node => $a{-node}, -qlist => 1, -timeout => $a{-timeout}) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to list state machines queued for execution on shelf '$shelf_id' node '$a{-node}': $self->{OUTPUT}");
        return -1;
    }
    
    # Return 0 if no tests are queued or running, 1 otherwise
    if ( $self->{OUTPUT} eq "" ) {
        $logger->info(__PACKAGE__ . ".$sub no tests are running on node '$a{-node}' on shelf '$shelf_id'");
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 ensureNoStatesRunning()

Make sure there are no active state machines. Will attempt to stop any if active.
Applies only to PASM Simulation - does NOT apply to load.

=over

=item Mandatory argument:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)

=item Optional argument:

    -timeout
        How long to wait for the state machine(s) to stop execution; in seconds; defaults to $mgtsObj->{DEFAULTTIMEOUT}

=item Returns:

    * 1 - any active state machine(s) were successfully stopped
    * 0 - otherwise 

=back

=cut

sub ensureNoStatesRunning {
    my ($self, %args) = @_;
    my $sub = "ensureNoStatesRunning()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 
    # Set default values before args are processed  
    my %a = ( -timeout => $self->{DEFAULTTIMEOUT}, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( $a{-node} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); return 0; }

    # Test for invalid args in %args hash
    # Must remove -node and -timeout args first
    foreach (qw/ -node -timeout/) {  delete $args{$_} if exists $args{$_} };
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }
    
    my $shelf_id = $self->_getShelfPasmId();

    my $stop_attempted = 0;
    
    while (1) {
        # Check if test(s) are running on node $a{-node}
        if ($self->areStatesRunning ( %a ) < 0) {
            $logger->error(__PACKAGE__ . ".$sub Failed to list state machines queued for execution on shelf '$shelf_id' node '$a{-node}': $self->{OUTPUT}");
            return -1;
        } elsif ( $self->{OUTPUT} eq "" ) {
            # no tests are running so exit loop
            last;
        } else {
        
            # We've attempted to stop the tests once already so report failure
            if ( $stop_attempted ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to stop queued state machines on shelf '$shelf_id' node '$a{-node}':\n$self->{OUTPUT}");
                return 0;        
            }
            
            $logger->info(__PACKAGE__ . ".$sub Stopping state machines queued for execution on shelf '$shelf_id' node '$a{-node}':\n$self->{OUTPUT}");
    
            # Attempt to stop the tests on node $a{-node}
            unless ( $self->stop( -node => $a{-node}, -timeout => $a{-timeout}) ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to initiate stop state machine command on shelf '$shelf_id'");
                return 0;
            }
        
            $stop_attempted = 1;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 getSeqNumber()

Get sequence number for state machine

=over

=item Mandatory arguments:

    -node => <node name or point code>
        Network node (Node Name OR Node Point Code). If point code is specified
        then it must be in PC notation as follows:
            ANSI (8-8-8)
            ITU (3-8-3)
            JAPAN (5-4-7)
    -machine
        State machine for which sequence number is to be obtained

=item Optional argument:

    -seqgrp
        Sequence group file (without the .sequenceGroup extension)

    Notes: the first occurrence of the machine in the loaded sequence group is reported
    The procedure checks, in this order, for:
    * <machine>
    * "<machine> State Machine" (if <machine> does not contain " State Machine")
    * description field of the <machine>.states file, where the location of the file is obtained from <seguence_group>

=item Returns:

    * a positive number - sequence number
    * 0 - otherwise 

=back

=cut

sub getSeqNumber {
    my ($self, %args) = @_;
    my $sub = "getSeqNumber()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed  
    my %a = ( );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    foreach (qw/ -node -machine /) { unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return 0; } }
    
    # Test for invalid args in %args hash
    # Must remove -node, -machine and -sequence args first
    foreach (qw/ -node -machine -seqgrp/) {  delete $args{$_} if exists $args{$_} };
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }

    my $shelf_id = $self->_getShelfPasmId();

    # Seqlist=>node hash is emptied on download so if populated
    # we have already got the seqlist. If not populated then
    # get the seqlist and populate hash.
    if ( ! exists($self->{SEQLIST}->{$a{-node}}) ) {
        unless ( $self->getSeqList( -node => "$a{-node}" ) ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to read the sequence list on shelf '$shelf_id' node '$a{-node}'");
            return 0;
        }
    } 

    my $seq_num;

    $logger->debug(__PACKAGE__ . ".$sub Looking for seq_num for node '$a{-node}', machine '$a{-machine}'.");
    $logger->debug(__PACKAGE__ . ".$sub State machine: $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$a{-machine}}");

    if ( $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$a{-machine}} eq "" ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to locate state machine '$a{-machine}' in the download seqlist");
        $logger->error(__PACKAGE__ . ".$sub The state machine at the correct sequence number (8) is $self->{SEQLIST}->{$a{-node}}->{SEQUENCE}{8}");
    
        # If we cannot find the sequence number from the name given, it may well be that the name given is in fact
        # the name of the states file, so we will need to fetch the description
        #
        if ( $a{-seqgrp} ) {
            
            my $sequence_group = $a{-seqgrp};
            unless ( $sequence_group =~ /\.sequenceGroup$/ ) { $sequence_group = "$sequence_group.sequenceGroup";}
            
            $logger->warn(__PACKAGE__ . ".$sub Looking for '$a{-machine}' in sequence group '$sequence_group'");
    
            if ( $self->cmd( -cmd => "cat \$MGTS_DATA/$sequence_group" ) ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to read '$sequence_group': $self->{OUTPUT}");
                return 0;
            }
        
            my $machine_file;
            
            my $pattern = quotemeta $a{-machine};
            
            # Find test (state machine) in sequence group file together with its workgroup
            if ( $self->{OUTPUT} =~ /STATE=(States.*\/$pattern)\s+TYPE=/ ) {
                $machine_file = "$1.states";
            } else {
                $logger->error(__PACKAGE__ . ".$sub Sequence group '$sequence_group' does not contain state machine '$a{-machine}':\n$self->{OUTPUT}");
                return 0;
            }
            
            if ( $self->cmd( -cmd => "cat \$MGTS_DATA/$machine_file" ) ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to read '$machine_file': $self->{OUTPUT}");
                return 0;
            }
    
            my $description;
            
            # Attempt to find test description in states file $mgtsObj->{OUTPUT}
            if ( $self->{OUTPUT} =~ /DESCRIPTION=(.*)\n/ ) {
                $description = $1;
            } else {
                $logger->error(__PACKAGE__ . ".$sub Failed to locate DESCRIPTION information in '$machine_file':\n$self->{OUTPUT}");
                return 0;
            }
    
            # Now attempt to use the $description as a key to find the seq number in the seqlist->node->machine hash
            if ( $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$description} eq "" ) {
                $logger->error(__PACKAGE__ . ".$sub Failed to locate state machine '$description' in the download seqlist after getting name from $machine_file");
                return 0;
            }
            
            # Hash lookup was successful so set $seq_num to value.
            $seq_num = $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$description};
            
        } else {
            $logger->error(__PACKAGE__ . ".$sub Failed to locate state machine as '-seqgrp' option not specified");
            return 0; 
        }
    } else {
        # Hash lookup was successful so set $seq_num to value.
        $seq_num = $self->{SEQLIST}->{$a{-node}}->{MACHINE}{$a{-machine}};
    } 
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    
    # Return seq_num if valid value 1 or greater, 0 otherwise
    if ($seq_num > 0) {
        return $seq_num;
    } else {
        return 0;   
    }
    
}


=head2 getStateTotalTime()

Get the total amount of timers in seconds rounded up to the nearest minute 
from state machine

=over

=item Mandatory arguments:

    -full_statename => <The fully qualified path to the MGTS state machine>

=item Returns:

    * <total time in seconds> - as an integer
    * 0  - otherwise 

=back

=cut

sub getStateTotalTime {
    my ($self,%args) = @_;
    my $sub = "getStateTotalTime()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    # Set default values before args are processed  
    my %a = ( );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( defined($a{-full_statename}) ) { $logger->error(__PACKAGE__ . ".$sub Missing argument, '-full_statename' required"); return 0; } 
    
    # Test for invalid args in %args hash
    foreach (qw/-full_statename/) {  delete $args{$_} if exists $args{$_} };
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }

    my $state_machine = $a{-full_statename};
            
    $logger->debug(__PACKAGE__ . ".$sub Looking for timers in state machine '$state_machine'");
   
    if ( $self->cmd( -cmd => "grep -E \"^VALUE=[0-9]+(m)*s\" $state_machine" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to execute grep cmd: $self->{OUTPUT}");
        return 0;
    }
        
    # Loop through each line of output $self->{OUTPUT}
    my @output_ary = split /\n/, $self->{OUTPUT};
    # Init the timer total 
    my $timer_total = 0;
    foreach my $line (@output_ary) {
        if ($line =~ /^VALUE=([0-9]+)(m?)s/ ) {
            if (defined($2) && ($2 eq "m")) {
                # the timer value is in milliseconds
                my $milli_timer = $1; 
                $logger->debug(__PACKAGE__ . ".$sub Milliseconds = $milli_timer,   Total = $timer_total");
                # Convert milliseconds to seconds by rounding up to the nearest
                # second
                # Add to the current timer total
                $timer_total += ((($milli_timer - ($milli_timer % 1000))/1000) + 1);
                $logger->debug(__PACKAGE__ . ".$sub Milliseconds converted to secs,   Total = $timer_total");
            } else {
                # the timer value is in seconds
                # Add the value to the current total
                $timer_total += $1;
                $logger->debug(__PACKAGE__ . ".$sub Added '$1' to total,   Total = $timer_total");
            }
        }
    }
    # Add 5 seconds to $timer_total just in case it is nearing a minute
    # boundary.
    $timer_total += 5;
    # Work out how many whole minutes are used - rounded up to the nearest
    # minute 
    my $min_timer = ((($timer_total - ($timer_total % 60))/60) + 1) ;
    $logger->debug(__PACKAGE__ . ".$sub Minute timer = $min_timer,   Total secs= $timer_total");

    # Convert whole minutes back to seconds
    my $timer = $min_timer * 60;

    $logger->debug(__PACKAGE__ . ".$sub Timer = $timer");
    return $timer;
}            


=head2 getStateDesc()

Get state machine description from state machine

=over

=item Mandatory arguments:

    -full_statename => <The fully qualified path to the MGTS state machine>

=item Returns:

    * <state machine description> - as a string
    * ""  - blank string otherwise 

=back

=cut

sub getStateDesc {
    my ($self,%args) = @_;
    my $sub = "getStateDesc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    # Set default values before args are processed  
    my %a = ( );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    unless ( defined($a{-full_statename}) ) { $logger->error(__PACKAGE__ . ".$sub Missing argument, '-full_statename' required"); return ""; } 
    
    # Test for invalid args in %args hash
    foreach (qw/-full_statename/) {  delete $args{$_} if exists $args{$_} };
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return "";
    }


    my $state_machine = $a{-full_statename};
            
    $logger->warn(__PACKAGE__ . ".$sub Looking for description in state machine '$state_machine'");
   
    if ( $self->cmd( -cmd => "cat $state_machine" ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to read '$state_machine': $self->{OUTPUT}");
        return "";
    }
        
    # Find description in state machine
    if ( $self->{OUTPUT} =~ / DESCRIPTION=(.+)\n/ ) {
        my $state_description = "$1";
        return $state_description;
    } else {
        $logger->error(__PACKAGE__ . ".$sub State machine '$state_machine' does not contain a description:\n$self->{OUTPUT}");
        return "";
    }
}            

=head2 getStateDescFromSeqNum()

Get the state machine description from the sequence list given the Node and the Sequence Number.

=over

=item Mandatory arguments:

    -nodeName => The name of the Node

    -sequence => The sequence number of the state machine to be executed

=item Returns:

    * <state machine description> - as a string
    * ""  - blank string otherwise

=back

=cut

sub getStateDescFromSeqNum{
    my ($self,%args) = @_;
    my $sub = "getStateDescFromSeqNum()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    # Set default values before args are processed
    my %a = ( );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $self->_info( -sub => $sub, %a );

        $logger->debug(__PACKAGE__ . ".$sub Looking for description in sequence list for node '$a{-nodeName}', number '$a{-sequence}'.");

        my $state_description = "";
        if( ( $state_description = $self->{SEQLIST}->{$a{-nodeName}}->{SEQUENCE}{$a{-sequence}} ) ne "" ) {
            $logger->debug(__PACKAGE__ . ".$sub State description found: $state_description");
        return $state_description;
    } else {
        $logger->error(__PACKAGE__ . ".$sub could not find a description:\n");
        return "";
    }
}

=head2 getNetworkMapName()

Get network map name from specified assignment file

=over

=item Optional argument:

    -assignment
        Defaults to $mgtsObj->{ASSIGNMENT}

=item Returns:

    1 - if successful and populates $mgtsObj->{NETMAP}  with the network map name
    0 - otherwise 

=back

=cut

sub getNetworkMapName {
    my ($self, %args) = @_;
    my $sub = "getNetworkMapName()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 
    # Set default values before args are processed  
    my %a = ( -assignment => $self->{ASSIGNMENT}, );
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
    
    # Test for invalid args in %args hash
    # Must remove -assignmnet arg first
    delete $args{-assignment};
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }

    # Verify required arguments defined
    unless ( $a{-assignment} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-assignment' required"); return 0; } 

    my $assignment_file = $a{-assignment};;
    my $assign_search_pattern = "";
    
    # Set appropriate assignment file extension
    if (( $self->{SHELF_VERSION} eq "p400" ) || ( $self->{SHELF_VERSION} eq "m500" )) {
        if ($assignment_file !~ /\.AssignM5k$/) {
            $assignment_file .= ".AssignM5k";
        }
        $assign_search_pattern = 'networkFile name=\".*\.Network\" path='; 
    } else {
        if ($assignment_file !~ /\.assign$/) {
            $assignment_file .=  ".assign";
        }
        $assign_search_pattern = "^NETWORK=.*\.Network";         
    }
    
    # Check Assignment file exists in $MGTS_DATA directory.
    if ( $self->cmd( -cmd => "ls \$MGTS_DATA\/${assignment_file}", -timeout => 10, ) ) {
            $logger->error(__PACKAGE__ . ".$sub File '\$MGTS_DATA\/${assignment_file}' does not exist? $self->{OUTPUT}");
            return 0;
    }
    
    # Get the network map used by the assignment.
    if ( $self->cmd( -cmd => "grep '${assign_search_pattern}' \$MGTS_DATA\/${assignment_file}", -timeout => 10, -errmode => "return", ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to retrieve Network Map name from '\$MGTS_DATA\/${assignment_file}' file. $self->{OUTPUT}");
        return 0;
    }
    
    my $network_map_name = "";
    # Look for network map name in assignment. Ignore path to network map
    $self->{OUTPUT} =~ m/^.*=(.*\/)?(.*)\.Network/;
    $network_map_name = $2;
    
    # Verify Network Map name not blank;
    if ( ! $network_map_name ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to retrieve Network Map name from grep output. $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Successfully retrieved Network Map '$network_map_name' from assignment file '$assignment_file'\n");
    }
    
    $self->{NETMAP} = "$network_map_name";
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 modifyUkPasmDB()

Modifies the PASM database data based on the UK PSX data dial plan.

=over

=item Mandatory arguments:

    -ing_ptcl
        Protocol of the incoming (ingress) trunk group. Valid values are:
            * ITU
            * ANSI
            * ISDN
            * CAS
            * BT
            * CHINA
            * JAPAN
            * H323
            * SIPANSI
            * SIPITU
            * SIPJAPAN
            * SIPBT
    -eg_ptcl
        Protocol of the outgoing (egress) trunk group.
        Valid values are the same as -ing_ptcl above.

    -ing_gsx
        GSX Number of the originating GSX

    -eg_gsx 
        GSX Number of the destination GSX

=item Optional arguments:

    -mgts_datafiles_dir
        Path to the MGTS user's datafile directory
        Defaults to $self->{MGTS_DATA}

    -bi_dir => <0 or 1>
        Indicates whether the BT databases "BiDir" column should be populated with 0 or 1.
        Defaults to 1 (bi-directional)

    -db_list => comma seperated string of PASM DB names in format "db_name1,db_name2" etc
        List of DB files to modify. If this is not specified then the function will
        attempt to modify every PASM database file in the $MGTS_DATA directory.

=item Other optional arguments (FTP related):

    -debug
        FTP debug flag;
        Default value: defaults to 1 when $mgtsObj->{LOG_LEVEL} is DEBUG and to 0 otherwise

    -protocol
        Protocol to try first: FTP or SFTP;
        Default value: defaults to FTP when $mgtsObj->{COMM_TYPE} is TELNET and to STFP otherwise

    -host
        Defaults to $mgtsObj->{OBJ_HOST}

    -user
        Defaults to $mgtsObj->{OBJ_USER}

    -password
        Defaults to $mgtsObj->{OBJ_PASSWORD} 

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise; 

=back

=cut

sub modifyUkPasmDB {
    my ($self, %args) = @_;
    my $sub = "modifyUkPasmDB()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a = (-mgts_datafiles_dir => $self->{MGTS_DATA},
             -host               => $self->{OBJ_HOST},
             -user               => $self->{OBJ_USER},
             -password           => $self->{OBJ_PASSWORD},
             -bi_dir             => 1 );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
        
    # Verify required arguments defined
    foreach (qw/ -ing_gsx -eg_gsx -ing_ptcl -eg_ptcl/) { delete $args{$_}; unless ( $a{$_} ) { $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); return 0; } }
    
    # Remove optional args from args hash to check for invalid arguments
    foreach (qw/ -local_dir -debug -protocol -host -user -password -mgts_datafiles_dir -bi_dir -db_list/) {
        delete($args{$_});
    }
    # Test for invalid args in %args hash
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }
    
    my %protocol_dig_hash = ( ITU       => "01",
                              ANSI      => "02",
                              ISDN      => "03",
                              CAS       => "04",
                              BT        => "05",
                              CHINA     => "06",
                              JAPAN     => "07",
                              H323      => "08",
                              SIPANSI   => "09",
                              SIPITU    => "10",
                              SIPJAPAN  => "11",
                              SIPBT     => "12",
                              SIPT      => "90",
                            );
    
    foreach (qw/ -ing_ptcl -eg_ptcl /) {
        # Convert -ing_ptcl and -eg_ptcl arg vals to uppercase.
        $a{$_} = uc($a{$_});
    
        # Check protocol is valid value
        unless ( $protocol_dig_hash{"$a{$_}"} ) {
            $logger->error(__PACKAGE__ . ".$sub Invalid protocol specified '$a{$_}' for '$_' arg. Must be one of 'ITU','ANSI','ISDN','BT','JAPAN','CAS','CHINA','H323','SIPANSI','SIPITU','SIPBT','SIPJAPAN' or 'SIPT'");
            return 0;
        }
    }
    
    # Prefix single digit GSX numbers with "0".
    foreach (qw/ -ing_gsx -eg_gsx/) {
        if (length($a{$_}) == 1) {
            $a{$_} = "0" . $a{$_};   
        }
        if ($a{$_} !~ m/^[0-9][0-9]$/) {
            $logger->error(__PACKAGE__ . ".$sub Invalid value '$a{$_}' specified for arg '$_'. Must be two digits.");
            return 0;
        }    
    }
    
    if ($a{-bi_dir} > 1 && $a{-bi_dir} < 0) {
        $logger->error(__PACKAGE__ . ".$sub Invalid value '$a{-bi_dir}' specified for arg '-bi_dir'. Must be 0 or 1.");
        return 0;  
    }
    

    my $ing_gsx_digit_1  = substr($a{-ing_gsx},0,1);
    my $ing_gsx_digit_2  = substr($a{-ing_gsx},1,1);
    my $eg_gsx_digit_1   = substr($a{-eg_gsx},0,1);
    my $eg_gsx_digit_2   = substr($a{-eg_gsx},1,1);
    my $ing_ptcl_digit_1 = substr($protocol_dig_hash{"$a{-ing_ptcl}"},0,1);
    my $ing_ptcl_digit_2 = substr($protocol_dig_hash{"$a{-ing_ptcl}"},1,1);
    my $eg_ptcl_digit_1  = substr($protocol_dig_hash{"$a{-eg_ptcl}"},0,1);
    my $eg_ptcl_digit_2  = substr($protocol_dig_hash{"$a{-eg_ptcl}"},1,1);
    my $eg_ptcl_dig      = $protocol_dig_hash{"$a{-eg_ptcl}"};
    my $ing_ptcl_dig     = $protocol_dig_hash{"$a{-ing_ptcl}"};
   
    ########################################################################################################################################
    #                                                                                                                                      #
    $logger->warn(__PACKAGE__ . ".$sub The following check for database files will change. New function required: getDatabaseForSeqGrp(). ");
    $logger->warn(__PACKAGE__ . ".$sub This will then return an array of databases used by SEGRPS list");                                  #
    #                                                                                                                                      #
    ########################################################################################################################################

    my @db_list;
    if (defined($a{-db_list}) && $a{-db_list} !~ /^\s*$/) {
        @db_list = split /\,/, "$a{-db_list}";
    } else {
        $logger->debug(__PACKAGE__ . ".$sub '-db_list' arg not defined or is empty. Defaulting to editing ALL PASM DB files in '\$MGTS_DATA' directory");
        if ($self->cmd( -cmd => "/bin/ls -1 \$MGTS_DATA/*.pdb" )) {
            $logger->error(__PACKAGE__ . ".$sub Unable to list MGTS PASM Databse files in MGTS_DATA directory");
            return 0;
        }
        @db_list = split /\n/, $self->{OUTPUT};
    }
   
    my $use_ftp_to_copy = 1;
    my $ftp;
    # Test if we can access the MGTS file system by local mount to the ATS server
    # If not we need to use FTP to copy the file.
    # ASSUMPTION: It is assumed that the local mount is mounted with the directories
    #             in the same place as those located on the MGTS server
    #             i.e. if MGTS_DATA was /home/mymgtsuser/datafiles on the MGTS server
    #                  then /home/mymgtsuser/datafiles will be on the local ATS server
    if ( -e "$a{-mgts_datafiles_dir}") {
        $use_ftp_to_copy = 0;   
    } else {
        # Connect
        $logger->info(__PACKAGE__ . ".$sub Starting FTP session to '$a{-host}'");
        my $ftp_debug = 0;
        my $ftp_protocol = "SFTP";
        my $ftp_other_protocol ="FTP";
        if ( $self->{COMM_TYPE} eq "TELNET" ) { $ftp_protocol = "FTP"; }
        if ( $self->{LOG_LEVEL} eq "DEBUG" ) { $ftp_debug = 1; }
        
        #$ftp_other_protocol = "SFTP" if $ftp_protocol eq "FTP";
        $logger->info(__PACKAGE__ . ".$sub Executing 'Net::xFTP->new( $ftp_protocol, $a{-host}, user => $a{-user}, Debug => $ftp_debug'");
        unless ( $ftp = Net::xFTP->new( $ftp_protocol, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $ftp_debug ) or
                 $ftp = Net::xFTP->new( $ftp_other_protocol, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $ftp_debug ) ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to connect to $a{-host}\n$@");
            return 0;
        }

        # Binary transfer mode
        $ftp->binary();
    }
    
    my $error_found = 0;
    my $remote_path;
    
    foreach my $db_name (@db_list) {
        chomp $db_name;
        $db_name =~ s/^.*\///g;
        $db_name =~ s/\.pdb//g;
        
        # Check template exists for the DB
        unless ( -e "$self->{LOCATION}/SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template") {
            $logger->error(__PACKAGE__ . ".$sub Unable to find template for MGTS DB '$db_name'. Please inform the MGTS Administrator");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
            # Move to next DB in list
            next;
        }

        $remote_path = "$a{-mgts_datafiles_dir}/${db_name}.pdb";

        # Below cmd returns 0 on success.
        #
        if( $self->cmd( -cmd => "touch $remote_path && chmod 666 $remote_path") ) {
            $logger->error(__PACKAGE__ . ".$sub Problem with '${db_name}.pdb'.");
            $error_found = 1;
            next;
        }

        unless ( open MGTSTEMP, "< $self->{LOCATION}/SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template" ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to open 'SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template'");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Opened $self->{LOCATION}/SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template file for reading");    
        }

        my @mgts_template_data_ary = <MGTSTEMP>;
        close(MGTSTEMP);
        my $mgts_template_data = join '', @mgts_template_data_ary;
        
        # Check columns in template match columns in DB
        # Get columns in template
        my %template_column_hash = ();
        my %mgts_db_column_hash=();
        my $column_format_error;
        
        my @invalid_columns = grep(/^COLUMN=/, @mgts_template_data_ary);
        if ($#invalid_columns < 0) {
            $logger->error(__PACKAGE__ . ".$sub Unable to find columns in '$db_name' MGTS DB template. Please inform the MGTS Administrator");
            # NOTE we do not want to return as this DB may not be the one we are usin
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $column_format_error = 0;
            foreach (@invalid_columns) {
                chomp;
                if ( m/^COLUMN=(.*) ROWS=[0-9]+ WIDTH=[0-9]+ TYPE=.* SEARCH_DIR=[0-9]+ FLAG=[0-1] GROUP=[0-9]+ SORTED=[0-1]\s*$/ ) {
                    $template_column_hash{$1} = $_;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub Invalid format of COLUMN in MGTS DB Template '${db_name}.mgts_db_template'. Please inform the MGTS administrator.'\n$_");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $column_format_error = 1;
                }
            }
            if ($column_format_error > 0) {
                $error_found = 1;
                # Move to next DB in list
                next;   
            }
        }
        
        # Get columns in MGTS DB in mgts user's $MGTS_DATA dir
        if ($self->cmd( -cmd => "grep \"^COLUMN=\" \$MGTS_DATA/${db_name}.pdb")) {
            $logger->error(__PACKAGE__ . ".$sub Unable to find columns in '$db_name' MGTS DB file. Please inform the MGTS Administrator");
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $column_format_error = 0;
            foreach (split /\n/,$self->{OUTPUT}) {
                chomp ;
                if ( m/^COLUMN=(.*) ROWS=[0-9]+ WIDTH=[0-9]+ TYPE=.* SEARCH_DIR=[0-9]+ FLAG=[0-1] GROUP=[0-9]+ SORTED=[0-1]\s*$/ ) {
                    $mgts_db_column_hash{$1} = $_;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub Invalid format of COLUMN in MGTS DB File '\$MGTS_DATA/${db_name}.pdb'. Please inform the MGTS Administrator\n$self->{OUTPUT}");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $column_format_error = 1;
                }
            }
            if ($column_format_error) {
                $error_found = 1;
                # Move to next DB in list
                next;
            }
        }
        
        # Compare column data
        if (keys(%template_column_hash) != keys( %mgts_db_column_hash)) {
            $logger->error(__PACKAGE__ . ".$sub The number of columns differs between MGTS DB Template and DB file for DB '$db_name'. Please inform the MGTS administrator.");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
        } else {
            while (my ($key, $value) = each %mgts_db_column_hash ) {
                if (exists $template_column_hash{$key}) {
                    if ($value ne $template_column_hash{$key} ) {
                        $logger->error(__PACKAGE__ . ".$sub The template and MGTS DB file differ for column '$key' in DB file '$db_name'. Please inform the MGTS administrator.\n   Template='$template_column_hash{$key}'\n   MGTS DB file='$value'.");
                        # NOTE we do not want to return as this DB may not be the one we are using
                        $error_found = 1;
                    }
                } else {
                    $logger->error(__PACKAGE__ . ".$sub The '$key' column does not exist in the MGTS DB template '${db_name}.mgts_db_template'. Please inform the MGTS administrator.");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $error_found = 1;
                }
            }
        }
        
        # Create temp file
        my ($tmp_fh, $tmp_filename);
#        if ( ($tmp_fh, $tmp_filename) = tempfile("$self->{OBJ_USER}XXXXX", DIR => "$a{-mgts_datafiles_dir}", SUFFIX => ".tmp")) {
        if ( ($tmp_fh, $tmp_filename) = tempfile("$self->{OBJ_USER}XXXXX", DIR => "/tmp", SUFFIX => ".tmp")) {
            $logger->debug(__PACKAGE__ . ".$sub Opened temp file '$tmp_filename' for writing MGTS DB data");
        } else {
            $logger->error(__PACKAGE__ . ".$sub Failed to open temp file for writing: $!");
            $error_found = 1;
            next;  
        }
        
        
        # Modify the digits in the DB template output
        # NOTE: The DB Templates contain the following pattern strings:
        #   #+#ING_GSX#+#       - 2-digit GSX number of ingress GSX. 
        #   #+#ING_GSX_DIG1#+#  - 1st digit of 2-digit GSX number of ingress GSX
        #   #+#ING_GSX_DIG2#+#  - 2nd digit of 2-digit GSX number of ingress GSX
        #   #+#ING_PROTOCOL#+#  - 2-digit protocol number of ingress GSX. 
        #   #+#ING_PROT_DIG1#+# - 1st digit of 2-digit protocol number of ingress GSX
        #   #+#ING_PROT_DIG2#+# - 2nd digit of 2-digit protocol number of ingress GSX
        #   #+#EG_GSX#+#        - 2-digit GSX number of egress GSX. 
        #   #+#EG_GSX_DIG1#+#   - 1st digit of 2-digit GSX number of egress GSX
        #   #+#EG_GSX_DIG2#+#   - 2nd digit of 2-digit GSX number of egress GSX
        #   #+#EG_PROTOCOL#+#   - 2-digit protocol number of egress GSX. 
        #   #+#EG_PROT_DIG1#+#  - 1st digit of 2-digit protocol number of egress GSX
        #   #+#EG_PROT_DIG2#+#  - 2nd digit of 2-digit protocol number of egress GSX
        #   #+#BI_DIR#+#        - sets BT call bi directional flag (0 = uni-directional, 1 = bi-directional)
        $mgts_template_data =~ s/\#\+\#ING_GSX\#\+\#/$a{-ing_gsx}/g;
        $mgts_template_data =~ s/\#\+\#ING_GSX_DIG1\#\+\#/$ing_gsx_digit_1/g;
        $mgts_template_data =~ s/\#\+\#ING_GSX_DIG2\#\+\#/$ing_gsx_digit_2/g;
        $mgts_template_data =~ s/\#\+\#EG_GSX\#\+\#/$a{-eg_gsx}/g;
        $mgts_template_data =~ s/\#\+\#EG_GSX_DIG1\#\+\#/$eg_gsx_digit_1/g;
        $mgts_template_data =~ s/\#\+\#EG_GSX_DIG2\#\+\#/$eg_gsx_digit_2/g;
        $mgts_template_data =~ s/\#\+\#ING_PROTOCOL\#\+\#/$ing_ptcl_dig/g;
        $mgts_template_data =~ s/\#\+\#ING_PROT_DIG1\#\+\#/$ing_ptcl_digit_1/g;
        $mgts_template_data =~ s/\#\+\#ING_PROT_DIG2\#\+\#/$ing_ptcl_digit_2/g;
        $mgts_template_data =~ s/\#\+\#EG_PROTOCOL\#\+\#/$eg_ptcl_dig/g;
        $mgts_template_data =~ s/\#\+\#EG_PROT_DIG1\#\+\#/$eg_ptcl_digit_1/g;
        $mgts_template_data =~ s/\#\+\#EG_PROT_DIG2\#\+\#/$eg_ptcl_digit_2/g;
        $mgts_template_data =~ s/\#\+\#BI_DIR\#\+\#/$a{-bi_dir}/g;
    
        print $tmp_fh $mgts_template_data;
        close $tmp_fh;

        # Change file permssions of temporary file
#        qx{chmod -f 644 $tmp_filename};
                
        # move temp file to MGTS_DATA directory.
        if ($use_ftp_to_copy) {
            $logger->info(__PACKAGE__ . ".$sub Uploading file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb' on $a{-host}");
    
            # Put the DB file
            unless ( $ftp->put( "${tmp_filename}", "$a{-mgts_datafiles_dir}/${db_name}.pdb" ) ) {
                $logger->error(__PACKAGE__ . ".$sub Put failed: ", $ftp->message());
                $error_found = 1;
            }
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Copying file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");
#            unless ( File::Copy::copy("${tmp_filename}" , "$a{-mgts_datafiles_dir}/${db_name}.pdb)") ) {
            if ( qx{cp ${tmp_filename} $a{-mgts_datafiles_dir}/${db_name}.pdb } ) { 
            
                $logger->error(__PACKAGE__ . ".$sub Failed to upload configuration file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");
                $error_found = 1;
            }
            else {
                $self->cmd( -cmd => "chmod 644 \$MGTS_DATA/${db_name}.pdb");
            }
        }
        
        $logger->debug(__PACKAGE__ . ".$sub Successfully uploaded temp file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");

        # Remove the local file
        if ( system "/bin/rm", "-f", "${tmp_filename}" ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to remove local temp file: $!");
            $error_found = 1;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Removed temp file '${tmp_filename}'");
        }    
    }
    
    if ($use_ftp_to_copy) {
        # Disconnect FTP session
        $logger->debug(__PACKAGE__ . ".$sub Closing FTP session'");
        $ftp->quit();
    }
 
    if ( $error_found ) {
        $logger->error(__PACKAGE__ . ".$sub Leaving function with error");
        return 0;   
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}

###################################################

=head2 getNodeList()

This method gets the list of nodes downloaded to the MGTS shelf as defined in the Network Map (*.Network files). 
A "node" in this case is a simulated PASM SSP node.

This method assumes that the MGTS assignment has already been downloaded to the shelf. 

NOTE: A successful download implies that all node names are unique and so this method
will not check for uniqueness in node naming.

=over

=item Mandatory Arguments:

None - This method works directly on the MGTS object.

=item Optional arguments:

None.

=item Returns:

    Command exit code:
    * Number of Nodes found on SUCCESS.
    * 0 - FAILURE

    NOTE: On success, this method also populates the variable: $self->{NODELIST} with the list of MGTS node names

=back

=cut

sub getNodeList() {
    my ($self, %args)   = @_;
    my $sub             = "getNodeList()";
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $mgts_node_list;                                            # Variable to store $self->_shelfPasm(-nodelist => 1)
    my $nodes_found     = 0;                                       # Total number of nodes found

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %args );

    # Initialise Node list array to be empty
    # 
    $self->{NODELIST}   = ();                                               # To contain a list of Node names

    # Get node list from MGTS object
    # _shelfPASM will display debug output of nodelist
    #
    unless ( $self->_shelfPasm(-nodelist => 1) ) {
        # Cannot get nodelist from MGTS
        #
        $logger->error(__PACKAGE__ . ".$sub: ERROR: Failed to get nodelist from MGTS"); 
        $logger->debug(__PACKAGE__ . ".$sub: <--- Leaving $sub");
        return 0;
    }
    else {
        # Store nodelist
        #
        $mgts_node_list = $self->{OUTPUT};

        # Scan output of nodelist call for instances of "NodeName"
        #
        $logger->debug(__PACKAGE__ . ".$sub: Checking Nodelist...");
        if ( $self->{SHELF_VERSION} eq "Softshelf")
        {
          while ( $mgts_node_list =~ /(\S+)\s+(\w+)\s+\S+\s+\S+/sg ) {
                  $logger->debug(__PACKAGE__ . ".$sub: Matched Node: $2");
                  push @{$self->{NODELIST}}, $2;
                  $nodes_found++;
          }
        }
        else
        {
           while ( $mgts_node_list =~ /NodeName=(\S+)\s/sg ) {
                   $logger->debug(__PACKAGE__ . ".$sub: Matched Node: $1");
                   push @{$self->{NODELIST}}, $1;
                   $nodes_found++;
           }
        }

        $logger->error(__PACKAGE__ . ".$sub: ERROR: No Nodes found") unless $nodes_found; 
        $logger->debug(__PACKAGE__ . ".$sub: <--- Leaving $sub");
        return $nodes_found;
    } 
}

=head2 getCleanupState()

This method identifies the FIRST cleanup state machine in a sequence group list. 
Once a cleanup state has been found the function will return.

This method assumes that getSeqList has been run and the SEQLIST array 
populated.

=over

=item Mandatory Arguments:

    -node <MGTS node name>

=item Optional arguments:

None.

=item Returns:

    Command exit code:
    * 1 - CLEANUP state machine identified. Also see NOTE below.
    * 0 - FAILURE

    NOTE: On success, this method also populates the variables:
         $self->{CLEANUP}->{$node}->{MACHINE}  - The state machine name
         $self->{CLEANUP}->{$node}->{SEQUENCE} - The state machine sequence number 

=item Example

    $mgts_obj->getCleanupState(-node => "SSP");        

=back

=cut

sub getCleanupState() {
    my ($self, %args)       = @_;
    my $sub                 = "getCleanupState()";
    my $logger              = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $cleanup_found       = 0;
    my %arg_array;
    my $state_machine_key;              # To contain the keys from $self->{SEQLIST}->{$mgts_node}->{MACHINE} 

    while ( my ($key, $value) = each %args ) { $arg_array{$key} = $value; }
  
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %arg_array );

    # Verify required -node argument defined
    unless ( $arg_array{-node} ) { 
        $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '-node' required"); 
        return 0; 
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub Using MGTS node to $arg_array{-node}"); 
    }

    # SEQLIST->node hash is emptied on download so if populated
    # we have already got the seqlist. If not populated then
    # we need to get the seqlist and populate hash.
    #
    if ( ! exists( $self->{SEQLIST}->{$arg_array{-node}} ) ) {
        unless ( $self->getSeqList(-node => "$arg_array{-node}") ) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to read the sequence list for MGTS node $arg_array{-node}");
            return 0;
        }
    }

    if ( defined( $self->{CLEANUP}->{$arg_array{-node}} ) ) {
        $self->{CLEANUP}->{$arg_array{-node}}  = undef;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Checking Sequence List for CLEANUP state machine...");

    # Run through state machine names by key
    #
    foreach $state_machine_key ( sort ( keys %{ $self->{SEQLIST}->{$arg_array{-node}}->{MACHINE} } ) ) {
        # Check to see if each machine key (ie. state machine name) contains
        # CLEANUP
        # 
        $logger->debug(__PACKAGE__ . ".$sub: Testing key $state_machine_key");

        if ($state_machine_key =~ /CLEANUP/) {
            $cleanup_found  = 1;
            $logger->debug(__PACKAGE__ . ".$sub: CLEANUP state machine $state_machine_key found.");
            $logger->debug(__PACKAGE__ . ".$sub: Setting \$self->{CLEANUP}->{$arg_array{-node}}->{MACHINE}   = $state_machine_key");
            $self->{CLEANUP}->{$arg_array{-node}}->{MACHINE}   = $state_machine_key;
            $logger->debug(__PACKAGE__ . ".$sub: Setting \$self->{CLEANUP}->{$arg_array{-node}}->{SEQUENCE}  = "
                . "$self->{SEQLIST}->{$arg_array{-node}}->{MACHINE}{$state_machine_key}");
            $self->{CLEANUP}->{$arg_array{-node}}->{SEQUENCE}  = 
                $self->{SEQLIST}->{$arg_array{-node}}->{MACHINE}{$state_machine_key};
            last;
        }
    }     
    
    unless ($cleanup_found) {    
        $logger->error(__PACKAGE__ . ".$sub: Failed to find CLEANUP state for MGTS node '$arg_array{-node}'");
    }

    $logger->debug(__PACKAGE__ . ".$sub: <--- Leaving $sub");
    return $cleanup_found;

}

=head2 modifyUkDefDotCsh()

Modifies the $MGTS_DATA/def.csh file. File is used to execute UK MGTS 'control' scripts

=over

=item Mandatory Arguments:

    -gt1 => <Ingress GSX IP address>
        Sets the GSX_TELNET[1,4] flags.

    -gn1 => <Ingress GSX Name string>
        Sets the GSX_NAME[1,4] flags

    -pt1 => <PSX IP address>
        Sets the PSX_TELNET[1-5] flags. 

=item Optional arguments:

    -gt2 => <Egress IP Address>
        Sets the GSX_TELNET[2,3,5] flags.
        Default value: defaults to value specified by -gt1 arg.

    -gn2 => Egress GSX Name string>
        Sets the GSX_NAME[2,3,5] flags.
        Default value:  defaults to value specified by -gn1 arg.

    -cnsred1 => <Ingress CNS redundancy group>
        Sets the CNS_REDUND_GRP1 flag.
        Default value: "CNS"

    -cnsred2 => <Egress CNS redundancy group>
        Sets the CNS_REDUND_GRP2 flag.
        Default value: "CNS"

    -itunode => <ITU ss7 node name>
        Sets the SS7NODE[1-4] flags.
        Default value: "c7n1"

    -btnode => <BT ss7 node name>
        Sets the BT_SS7NODE[1-4] flags.
        Default vslue: "c7n1"

    -ansinode => <ANSI ss7 node name>
        Sets the ANSI_SS7NODE[1-4] flags.
        Default value: "a7n1"

    -chinanode => <CHINA ss7 node name>
        Sets the CHINA_SS7NODE[1-4] flags.
        Default value: "ch7n1"

    -japannode => <Japan ss7 node name>
        Sets the JAPAN_SS7NODE[1-4] flags.
        Default value: "j7n1"

    -snd2grpmsg => <"YES" or "NO">
        Sets the SGX_SENDS_TWO_GRP_MSGS GSX TCL flag.
        Default value: to "NO"

    -local_dir
        Where, on the local machine, the file is to be stored;
        Default value: defaults to the current working directory

=item Other optional arguments (FTP related):

    -debug
        FTP debug flag;
        Default value: defaults to 1 when $mgtsObj->{LOG_LEVEL} is DEBUG and to 0 otherwise

    -protocol
        Protocol to try first: FTP or SFTP;
        Default value: defaults to FTP when $mgtsObj->{COMM_TYPE} is TELNET and to STFP otherwise

    -host
        Defaults to $mgtsObj->{OBJ_HOST}

    -user
        Defaults to $mgtsObj->{OBJ_USER}

    -password
        Defaults to $mgtsObj->{OBJ_PASSWORD}

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise; 

=back

=cut

sub modifyUkDefDotCsh {
    my ($self, %args) = @_;
    my $sub = "modifyUkDefDotCsh()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed
    my %a = (-local_dir => ".",
             -host      => $self->{OBJ_HOST},
             -user      => $self->{OBJ_USER},
             -password  => $self->{OBJ_PASSWORD});
    
    if ( $self->{LOG_LEVEL} eq "DEBUG" ) { $a{-debug} = 1; } else { $a{-debug} = 0; }

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Verify required arguments defined
    foreach (qw/ -gt1 -gn1 -pt1 -host -user -password/) {
        delete($args{$_}) if defined $args{$_};
        unless ( $a{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required."); return 0;
        }
    }

    # Remove optional args from args hash to check for invalid arguments
    foreach (qw/ -gt2 -gn2 -gt3 -gn3 -cnsred1 -cnsred2 -itunode -btnode -ansinode -chinanode -japannode -snd2grpmsg -local_dir -debug -protocol/) {
        delete($args{$_});
    }

    # Test for invalid args in %args hash
    if (_invalidArgs($sub,"",%args)) {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments found");
        return 0;
    }

    my $remote_path = $self->{MGTS_DATA} . "/def.csh";

    # Before we proceed any further, verify we can write the def.csh
    if ( $self->cmd( -cmd => "test -e $remote_path || touch $remote_path && chmod 666 $remote_path " ) ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to change file permissions of '$remote_path' for writing: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Verified $remote_path exists and file permissions have been modified");
    }

    unless ( open DEFCSH, "< $self->{LOCATION}/SonusQA/MGTS/def_csh_template.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub Failed to open $self->{LOCATION}/SonusQA/MGTS/def_csh_template.txt: $self->{OUTPUT}");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Opened $self->{LOCATION}/SonusQA/MGTS/def_csh_template.txt file for reading");
    }

    my @buffer = <DEFCSH>;
    close(DEFCSH);
    $self->{OUTPUT} = join '', @buffer;

    my ($tmp_fh, $tmp_filename);
    if ( ($tmp_fh, $tmp_filename) = tempfile("defcshXXXXX", DIR => "/tmp", SUFFIX => ".tmp")) {
        $logger->debug(__PACKAGE__ . ".$sub Opened temp file '$tmp_filename' for writing def.csh data");
    } else {
        $logger->error(__PACKAGE__ . ".$sub Failed to open temp file for writing: $!");
        return 0;
    }

    # Set default values
    unless ( $a{-gn2} ) { $a{-gn2} = $a{-gn1}; }
    unless ( $a{-gt2} ) { $a{-gt2} = $a{-gt1}; }
    unless ( $a{-gn3} ) { $a{-gn3} = $a{-gn1}; }
    unless ( $a{-gt3} ) { $a{-gt3} = $a{-gt1}; }
    unless ( $a{-cnsred1} ) { $a{-cnsred1} = "CNS"; }
    unless ( $a{-cnsred2} ) { $a{-cnsred2} = "CNS"; }
    unless ( $a{-itunode} ) { $a{-itunode} = "c7n1"; }
    unless ( $a{-btnode} ) { $a{-btnode} = "c7n1"; }
    unless ( $a{-ansinode} ) { $a{-ansinode} = "a7n1"; }
    unless ( $a{-japannode} ) { $a{-japannode} = "j7n1"; }
    unless ( $a{-chinanode} ) { $a{-chinanode} = "c7n1"; }
    unless ( $a{-snd2grpmsg} ) { $a{-snd2grpmsg} = "NO"; }

    # Modify the template output
    $self->{OUTPUT} =~ s/\*GSXNAME1\*/$a{-gn1}/g;
    $self->{OUTPUT} =~ s/\*GSXNAME2\*/$a{-gn2}/g;
    $self->{OUTPUT} =~ s/\*GSXNAME3\*/$a{-gn3}/g;
    $self->{OUTPUT} =~ s/\*GSXTEL1\*/$a{-gt1}/g;
    $self->{OUTPUT} =~ s/\*GSXTEL2\*/$a{-gt2}/g;
    $self->{OUTPUT} =~ s/\*GSXTEL3\*/$a{-gt3}/g;
    $self->{OUTPUT} =~ s/\*PSXTEL1\*/$a{-pt1}/g;
    $self->{OUTPUT} =~ s/\*CNSRED1\*/$a{-cnsred1}/g;
    $self->{OUTPUT} =~ s/\*CNSRED2\*/$a{-cnsred2}/g;
    $self->{OUTPUT} =~ s/\*ITUNODENAME\*/$a{-itunode}/g;
    $self->{OUTPUT} =~ s/\*BTNODENAME\*/$a{-btnode}/g;
    $self->{OUTPUT} =~ s/\*ANSINODENAME\*/$a{-ansinode}/g;
    $self->{OUTPUT} =~ s/\*JAPANNODENAME\*/$a{-japannode}/g;
    $self->{OUTPUT} =~ s/\*CHINANODENAME\*/$a{-chinanode}/g;
    $self->{OUTPUT} =~ s/\*SGXSENDSTWOGRPMSGS\*/$a{-snd2grpmsg}/g;

    # Print output to file.
    print $tmp_fh $self->{OUTPUT};
    close $tmp_fh;

    $logger->debug(__PACKAGE__ . ".$sub The def.csh data has been modified in temp file '$tmp_filename'");

    my $error_found = 0;
    
   my %scpArgs;
    $scpArgs{-hostip} = $a{-host};
    $scpArgs{-hostuser} = $a{-user};
    $scpArgs{-hostpasswd} = $a{-password};
    $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$remote_path;
    $scpArgs{-sourceFilePath} = "${tmp_filename}";
    if (&SonusQA::Base::secureCopy(%scpArgs)) {
	$logger->info(__PACKAGE__ . ".$sub Uploading file '${tmp_filename}' to '$remote_path' on $a{-host} is successfull");  
    } else {
        $error_found = 1;
        $logger->error(__PACKAGE__ . ".$sub Uploading file '${tmp_filename}' to '$remote_path' on $a{-host} has failed");
    }

    # Remove the local file
    if ( system "/bin/rm", "-f", "${tmp_filename}" ) {
        $logger->warn(__PACKAGE__ . ".$sub Failed to remove local temp file: $!");
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Removed temp file '${tmp_filename}'");
    }

    if ( $error_found ) {
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}


=head2 setupRemoteHook()

=over

=item DESCRIPTION:

 This subroutine setups the remoteHook on the current ATS host machine for listening. The port is taken from the MGTS object variable $mgts_object->{FISH_HOOK_PORT}. The sub then makes a call to SonusQA::SOCK->new which opens the Socket. A reference to the socket is then returned.

=item ARGUMENTS:

 None.

=item PACKAGE:

 SonusQA::MGTS

=item GLOBAL VARIABLES USED:
 None

=item OUTPUT:
 $socket - Success
 0       - Failure

=item EXAMPLE:

$obj->setupRemoteHook;

=back

=cut

sub setupRemoteHook {

    my ($self, %args) = @_;

    my $sub_name = "setupRemoteHook";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub"); 
  
    my ($fishhook_port, $listen_port_object);

    # Ensure fishHook port is specified on the MGTS object
    if ( $self->{FISH_HOOK_PORT} && $self->{FISH_HOOK_PORT} ne "" ) {
        $fishhook_port = $self->{FISH_HOOK_PORT};
        $logger->debug(__PACKAGE__ . ".$sub_name:  Setting up remote hook to use port $fishhook_port"); 
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name:  Port is not set in \$self->{FISH_HOOK_PORT}. Please update TMS object for MGTS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
        return 0;
    }

    # Open LISTEN port based on the FISH_HOOK_PORT
    unless ( $listen_port_object = SonusQA::SOCK->new (-port => $fishhook_port) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open remote hook port on port $fishhook_port");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Opened remote hook on port $fishhook_port");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [obj:sock]"); 

    return $listen_port_object;
}

=head2 DESTROY

  PERL default module method Over-rides.
  Typical inner library usage:

  $obj->DESTROY();

=cut

sub DESTROY {
    my ($self, %args) = @_;
    my $sub = "DESTROY()";
    my ($logger);
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }

    my %a = ();
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

	if( $self->{SOCK_INFO} )
	  {	
		$logger->info(__PACKAGE__ . ".DESTROY: Closing socket on port $self->{SOCK_INFO}->{PORT}");		
		$self->{SOCK_INFO}->close();
		$logger->info(__PACKAGE__ . ".DESTROY: Socket Closed, Object Destroyed.");
	  }
    
    $logger->info(__PACKAGE__ . ".$sub [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".$sub [$self->{OBJ_HOST}] Destroying object");
    $self->endSession( %args );
    $logger->debug(__PACKAGE__ . ".sub [$self->{OBJ_HOST}] Destroyed object");
    
    $self->closeConn();    
    return 1;
}


=head2 modifyUkPasmDB()

Modifies the PASM database data based on the UK PSX data dial plan.

=over

=item Mandatory arguments:

    -ing_ptcl
        Protocol of the incoming (ingress) trunk group. Valid values are:
            * ITU
            * ANSI
            * ISDN
            * CAS
            * BT
            * CHINA
            * JAPAN
            * H323
            * SIPANSI
            * SIPITU
            * SIPJAPAN
            * SIPBT

    -eg_ptcl
        Protocol of the outgoing (egress) trunk group.
        Valid values are the same as -ing_ptcl above.

    -ing_gsx
        GSX Number of the originating GSX

    -eg_gsx 
        GSX Number of the destination GSX

=item Optional arguments:

    -mgts_datafiles_dir
        Path to the MGTS user's datafile directory
        Defaults to $self->{MGTS_DATA}

    -bi_dir => <0 or 1>
        Indicates whether the BT databases "BiDir" column should be populated with 0 or 1.
        Defaults to 1 (bi-directional)

    -db_list => comma seperated string of PASM DB names in format "db_name1,db_name2" etc
        List of DB files to modify. If this is not specified then the function will
        attempt to modify every PASM database file in the $MGTS_DATA directory.

=item Other optional arguments (FTP related):

    -debug
        FTP debug flag;
        Default value: defaults to 1 when $mgtsObj->{LOG_LEVEL} is DEBUG and to 0 otherwise

    -protocol
        Protocol to try first: FTP or SFTP;
        Default value: defaults to FTP when $mgtsObj->{COMM_TYPE} is TELNET and to STFP otherwise

    -host
        Defaults to $mgtsObj->{OBJ_HOST}

    -user
        Defaults to $mgtsObj->{OBJ_USER}

    -password
        Defaults to $mgtsObj->{OBJ_PASSWORD} 

=item Returns:

    Command exit code:
    * 1 - on success
    * 0 - otherwise; 

=back

=cut

sub modifyMgtsAssignment {

    my ($self, %args) = @_;
    my $sub = "modifyMgtsAssignment()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my %a = (
             -mgts_datafiles_dir => $self->{MGTS_DATA},
             -host               => $self->{OBJ_HOST},
             -user               => $self->{OBJ_USER},
             -password           => $self->{OBJ_PASSWORD},
            );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
        
    # Verify required arguments defined
    foreach (qw/ -mgts -sgx1 /) { 
        delete $args{$_};  
        unless ( $a{$_} ) { 
            $logger->error(__PACKAGE__ . ".$sub Missing or blank argument, '$_' required"); 
            return 0; 
        } 
    }
  
    # Check for own hash info
    unless ( $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} ) {
        # Resolve alias of self
        $self->{TMS_ALIAS_DATA} = SonusQA::Utils::resolve_alias($a{-mgts});
        $self->{TMS_ALIAS_DATA}->{ALIAS_NAME} = $a{-mgts}; 
    }

    # Default netmask if its not present.
    $self->{TMS_ALIAS}->{SIGNIF}->{1}->{NETMASK} =
    $self->{TMS_ALIAS}->{SIGNIF}->{2}->{NETMASK} = "255.255.255.0";
 
    my %search_replace_hash = (
                                MGTS_SIG_NIF_1      => $self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{IP},
                                MGTS_SIG_NIF_2      => $self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{IP},
                                MGTS_SLOT_NUM       => $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{SLOT},
                                MGTS_SIG_NIF_NETMASK_1  => $self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{NETMASK},
                                MGTS_SIG_NIF_NETMASK_2  => $self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{NETMASK},
                                SGX_CE0_EXT_SIG_NIF_1 => "",
                              );
 

    ########################################################################################################################################
    #                                                                                                                                      #
    $logger->warn(__PACKAGE__ . ".$sub The following check for database files will change. New function required: getDatabaseForSeqGrp(). ");
    $logger->warn(__PACKAGE__ . ".$sub This will then return an array of databases used by SEGRPS list");                                  #
    #                                                                                                                                      #
    ########################################################################################################################################

    my @db_list;
    if (defined($a{-db_list}) && $a{-db_list} !~ /^\s*$/) {
        @db_list = split /\,/, "$a{-db_list}";
    } else {
        $logger->debug(__PACKAGE__ . ".$sub '-db_list' arg not defined or is empty. Defaulting to editing ALL PASM DB files in '\$MGTS_DATA' directory");
        if ($self->cmd( -cmd => "/bin/ls -1 \$MGTS_DATA/*.pdb" )) {
            $logger->error(__PACKAGE__ . ".$sub Unable to list MGTS PASM Databse files in MGTS_DATA directory");
            return 0;
        }
        @db_list = split /\n/, $self->{OUTPUT};
    }
   
    my $use_ftp_to_copy = 1;
    my $ftp;
    # Test if we can access the MGTS file system by local mount to the ATS server
    # If not we need to use FTP to copy the file.
    # ASSUMPTION: It is assumed that the local mount is mounted with the directories
    #             in the same place as those located on the MGTS server
    #             i.e. if MGTS_DATA was /home/mymgtsuser/datafiles on the MGTS server
    #                  then /home/mymgtsuser/datafiles will be on the local ATS server
    if ( -e "$a{-mgts_datafiles_dir}") {
        $use_ftp_to_copy = 0;   
    } else {
        # Connect
        $logger->info(__PACKAGE__ . ".$sub Starting FTP session to '$a{-host}'");
        my $ftp_debug = 0;
        my $ftp_protocol = "SFTP";
        my $ftp_other_protocol ="FTP";
        if ( $self->{COMM_TYPE} eq "TELNET" ) { $ftp_protocol = "FTP"; }
        if ( $self->{LOG_LEVEL} eq "DEBUG" ) { $ftp_debug = 1; }
        
        #$ftp_other_protocol = "SFTP" if $ftp_protocol eq "FTP";
        $logger->info(__PACKAGE__ . ".$sub Executing 'Net::xFTP->new( $ftp_protocol, $a{-host}, user => $a{-user}, Debug => $ftp_debug'");
        unless ( $ftp = Net::xFTP->new( $ftp_protocol, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $ftp_debug ) or
                 $ftp = Net::xFTP->new( $ftp_other_protocol, $a{-host}, user => $a{-user}, password => $a{-password}, Debug => $ftp_debug ) ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to connect to $a{-host}\n$@");
            return 0;
        }

        # Binary transfer mode
        $ftp->binary();
    }
    
    my $error_found = 0;
    my $remote_path;
    
    foreach my $db_name (@db_list) {
        chomp $db_name;
        $db_name =~ s/^.*\///g;
        $db_name =~ s/\.pdb//g;
        
        # Check template exists for the DB
        unless ( -e "$self->{LOCATION}/SonusQA/MGTS/UK_ASSIGN_TEMPLATES/${db_name}.AssignM5k_template") {
            $logger->error(__PACKAGE__ . ".$sub Unable to find template for MGTS Assignment '$db_name'. Please inform the MGTS Administrator");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
            # Move to next DB in list
            next;
        }

        $remote_path = "$a{-mgts_datafiles_dir}/${db_name}.pdb";

        # Below cmd returns 0 on success.
        #
        if( $self->cmd( -cmd => "touch $remote_path && chmod 666 $remote_path") ) {
            $logger->error(__PACKAGE__ . ".$sub Problem with '${db_name}.pdb'.");
            $error_found = 1;
            next;
        }

        unless ( open MGTSTEMP, "< $self->{LOCATION}/SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template" ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to open 'SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template'");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Opened $self->{LOCATION}/SonusQA/MGTS/UK_DB_TEMPLATES/${db_name}.mgts_db_template file for reading");    
        }

        my @mgts_template_data_ary = <MGTSTEMP>;
        close(MGTSTEMP);
        my $mgts_template_data = join '', @mgts_template_data_ary;
        
        # Check columns in template match columns in DB
        # Get columns in template
        my %template_column_hash = ();
        my %mgts_db_column_hash=();
        my $column_format_error;
        
        my @invalid_columns = grep(/^COLUMN=/, @mgts_template_data_ary);
        if ($#invalid_columns < 0) {
            $logger->error(__PACKAGE__ . ".$sub Unable to find columns in '$db_name' MGTS DB template. Please inform the MGTS Administrator");
            # NOTE we do not want to return as this DB may not be the one we are usin
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $column_format_error = 0;
            foreach (@invalid_columns) {
                chomp;
                if ( m/^COLUMN=(.*) ROWS=[0-9]+ WIDTH=[0-9]+ TYPE=.* SEARCH_DIR=[0-9]+ FLAG=[0-1] GROUP=[0-9]+ SORTED=[0-1]\s*$/ ) {
                    $template_column_hash{$1} = $_;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub Invalid format of COLUMN in MGTS DB Template '${db_name}.mgts_db_template'. Please inform the MGTS administrator.'\n$_");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $column_format_error = 1;
                }
            }
            if ($column_format_error > 0) {
                $error_found = 1;
                # Move to next DB in list
                next;   
            }
        }
        
        # Get columns in MGTS DB in mgts user's $MGTS_DATA dir
        if ($self->cmd( -cmd => "grep \"^COLUMN=\" \$MGTS_DATA/${db_name}.pdb")) {
            $logger->error(__PACKAGE__ . ".$sub Unable to find columns in '$db_name' MGTS DB file. Please inform the MGTS Administrator");
            $error_found = 1;
            # Move to next DB in list
            next;
        } else {
            $column_format_error = 0;
            foreach (split /\n/,$self->{OUTPUT}) {
                chomp ;
                if ( m/^COLUMN=(.*) ROWS=[0-9]+ WIDTH=[0-9]+ TYPE=.* SEARCH_DIR=[0-9]+ FLAG=[0-1] GROUP=[0-9]+ SORTED=[0-1]\s*$/ ) {
                    $mgts_db_column_hash{$1} = $_;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub Invalid format of COLUMN in MGTS DB File '\$MGTS_DATA/${db_name}.pdb'. Please inform the MGTS Administrator\n$self->{OUTPUT}");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $column_format_error = 1;
                }
            }
            if ($column_format_error) {
                $error_found = 1;
                # Move to next DB in list
                next;
            }
        }
        
        # Compare column data
        if (keys(%template_column_hash) != keys( %mgts_db_column_hash)) {
            $logger->error(__PACKAGE__ . ".$sub The number of columns differs between MGTS DB Template and DB file for DB '$db_name'. Please inform the MGTS administrator.");
            # NOTE we do not want to return as this DB may not be the one we are using
            $error_found = 1;
        } else {
            while (my ($key, $value) = each %mgts_db_column_hash ) {
                if (exists $template_column_hash{$key}) {
                    if ($value ne $template_column_hash{$key} ) {
                        $logger->error(__PACKAGE__ . ".$sub The template and MGTS DB file differ for column '$key' in DB file '$db_name'. Please inform the MGTS administrator.\n   Template='$template_column_hash{$key}'\n   MGTS DB file='$value'.");
                        # NOTE we do not want to return as this DB may not be the one we are using
                        $error_found = 1;
                    }
                } else {
                    $logger->error(__PACKAGE__ . ".$sub The '$key' column does not exist in the MGTS DB template '${db_name}.mgts_db_template'. Please inform the MGTS administrator.");
                    # NOTE we do not want to return as this DB may not be the one we are using
                    $error_found = 1;
                }
            }
        }
        
        # Create temp file
        my ($tmp_fh, $tmp_filename);
        if ( ($tmp_fh, $tmp_filename) = tempfile("$self->{OBJ_USER}XXXXX", DIR => "/tmp", SUFFIX => ".tmp")) {
            $logger->debug(__PACKAGE__ . ".$sub Opened temp file '$tmp_filename' for writing MGTS DB data");
        } else {
            $logger->error(__PACKAGE__ . ".$sub Failed to open temp file for writing: $!");
            $error_found = 1;
            next;  
        }
        

        # Change template flags for real values        
# NEED TO EDIT THESE FOR SIGTRAN VALUES
# UNCOMMENT WHEN READY

#        $mgts_template_data =~ s/\#\+\#ING_GSX\#\+\#/$a{-ing_gsx}/g;
#        $mgts_template_data =~ s/\#\+\#ING_GSX_DIG1\#\+\#/$ing_gsx_digit_1/g;
#        $mgts_template_data =~ s/\#\+\#ING_GSX_DIG2\#\+\#/$ing_gsx_digit_2/g;
#        $mgts_template_data =~ s/\#\+\#EG_GSX\#\+\#/$a{-eg_gsx}/g;
#        $mgts_template_data =~ s/\#\+\#EG_GSX_DIG1\#\+\#/$eg_gsx_digit_1/g;
#        $mgts_template_data =~ s/\#\+\#EG_GSX_DIG2\#\+\#/$eg_gsx_digit_2/g;
#        $mgts_template_data =~ s/\#\+\#ING_PROTOCOL\#\+\#/$ing_ptcl_dig/g;
#        $mgts_template_data =~ s/\#\+\#ING_PROT_DIG1\#\+\#/$ing_ptcl_digit_1/g;
#        $mgts_template_data =~ s/\#\+\#ING_PROT_DIG2\#\+\#/$ing_ptcl_digit_2/g;
#        $mgts_template_data =~ s/\#\+\#EG_PROTOCOL\#\+\#/$eg_ptcl_dig/g;
#        $mgts_template_data =~ s/\#\+\#EG_PROT_DIG1\#\+\#/$eg_ptcl_digit_1/g;
#        $mgts_template_data =~ s/\#\+\#EG_PROT_DIG2\#\+\#/$eg_ptcl_digit_2/g;
#        $mgts_template_data =~ s/\#\+\#BI_DIR\#\+\#/$a{-bi_dir}/g;
    
        print $tmp_fh $mgts_template_data;
        close $tmp_fh;

        # Change file permssions of temporary file
#        qx{chmod -f 644 $tmp_filename};
                
        # move temp file to MGTS_DATA directory.
        if ($use_ftp_to_copy) {
            $logger->info(__PACKAGE__ . ".$sub Uploading file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb' on $a{-host}");
    
            # Put the DB file
            unless ( $ftp->put( "${tmp_filename}", "$a{-mgts_datafiles_dir}/${db_name}.pdb" ) ) {
                $logger->error(__PACKAGE__ . ".$sub Put failed: ", $ftp->message());
                $error_found = 1;
            }
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Copying file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");
            if ( qx{cp ${tmp_filename} $a{-mgts_datafiles_dir}/${db_name}.pdb } ) { 
            
                $logger->error(__PACKAGE__ . ".$sub Failed to upload configuration file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");
                $error_found = 1;
            }
            else {
                $self->cmd( -cmd => "chmod 644 \$MGTS_DATA/${db_name}.pdb");
            }
        }
        
        $logger->debug(__PACKAGE__ . ".$sub Successfully uploaded temp file '${tmp_filename}' to '$a{-mgts_datafiles_dir}/${db_name}.pdb'");

        # Remove the local file
        if ( system "/bin/rm", "-f", "${tmp_filename}" ) {
            $logger->error(__PACKAGE__ . ".$sub Failed to remove local temp file: $!");
            $error_found = 1;
        } else {
            $logger->debug(__PACKAGE__ . ".$sub Removed temp file '${tmp_filename}'");
        }    
    }
    
    if ($use_ftp_to_copy) {
        # Disconnect FTP session
        $logger->debug(__PACKAGE__ . ".$sub Closing FTP session'");
        $ftp->quit();
    }
 
    if ( $error_found ) {
        $logger->error(__PACKAGE__ . ".$sub Leaving function with error");
        return 0;   
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return 1;
}

=head2 awaitLoadCompletion()

=over

=item DESCRIPTION:

 This subroutine waits for the load status results to show 0 in progress for each specified node, or all nodes if none are specified. 

=item ARGUMENTS:

 -timeout	(optional) Specify the overall time to wait, in seconds, failure is returned if we still have in-progress state machines after this time.
 			Default 60s
 -nodes		(optional) Specify a comma separated string containng node names to be checked - if unspecified - checks all nodes on this card.

=item PACKAGE:

 SonusQA::MGTS

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

$obj->awaitLoadCompletion;

$obj->awaitLoadCompletion( -nodes => "STP1,STP2" ]);

=item AUTHOR:

Malcolm Lashley
mlashley@sonusnet.com

=back

=cut


sub awaitLoadCompletion {

	my ($self, %args) = @_;
	my $sub = "awaitLoadCompletion()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
	# Set default values before args are processed
	my %a = ( -timeout     => 60,
			  -nodes => "all",
			);

	while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

	logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);

	my @nodes;
	if($a{-nodes} eq "all") {
		$self->getNodeList(); 
		@nodes = @{$self->{NODELIST}};
	} else {
		@nodes = split /,/,$a{-nodes};
	}

	$logger->debug(__PACKAGE__ . "DEBUG:\n" . Dumper(\@nodes));

	my $inprogress = 1;
	my $startLoopTime    = [gettimeofday];

	while($inprogress and (tv_interval($startLoopTime) < $a{-timeout})) {
		foreach (@nodes) {
			unless ($self->_readLoadStatus( -node => $_ )) {
				$logger->warn(__PACKAGE__ . ".$sub Unable to get results for Node: $_");
				return 0;
			}
		}
		$inprogress = 0;
#		foreach $node (keys %{$self->{STATUS}}) {
		foreach my $node (@nodes) {
			foreach my $sm (keys %{$self->{STATUS}->{$node}}) {
				unless ($sm eq "run_time") {
				   $logger->debug(__PACKAGE__ . ".$sub Checking node $node FSM $sm for in-progress");
					$inprogress += $self->{STATUS}->{$node}->{$sm}->{inprogress};
				}
	        }
		}
		if($inprogress > 0) {
			   $logger->info(__PACKAGE__ . ".$sub Found $inprogress state machines in progress - sleeping to check again");
				sleep 2; # Pick a number...
		}
	}
	if ($inprogress > 0) {
		$logger->warn(__PACKAGE__ . ".$sub Found $inprogress state machines in progress after timeout.");
		return 0;
	} else {
		$logger->debug(__PACKAGE__ . ".$sub Returning SUCCESS with $inprogress state machines in progress.");
		return 1;
	}

	die "Unreachable!";

}


#------------------------------------------------------#
return 1;
