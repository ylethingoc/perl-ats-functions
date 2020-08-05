package SonusQA::GLCAS;

=head1 NAME

SonusQA::GLCAS - Perl module for GLCAS application control.

=head1 AUTHOR


=head1 IMPORTANT

This module is a work in progress, it should work as described, but has not undergone extensive testing.

=head1 DESCRIPTION

This module provides an interface for the GLCAS test tool.
Control of command input is up to the QA Engineer implementing this class
allowing the engineer to specific which attributes to use.

=head1 METHODS

=cut

use ATS;
use Net::Telnet ;
use SonusQA::Utils qw(:all);
# use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use Module::Locate qw /locate/;
our $VERSION = '1.0';
use POSIX qw(strftime);
use vars qw($self);
use File::Basename;
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);
our $TESTSUITE;

# INITIALIZATION ROUTINES FOR CLI

=head2 SonusQA::GLCAS::doInitialization()

    Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
    use to set Object specific flags, paths, and prompts.

=over

=item Arguments

    None

=item Returns

    Nothing

=back

=cut

sub doInitialization {

    my ($self , %args)=@_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    my $sub = 'doInitialization' ;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{PROMPT} = '/.*[\$%\}\|\>]$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{DEFAULTTIMEOUT} = 3600;
    $self->{USER} = `id -un`;
        chomp $self->{USER};
    $logger->info("Initialization Complete");
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::GLCAS::setSystem()

    Base module over-ride.  This routine is responsible to completeing the connection to the object.
    It performs some basic operations on the GLCAS to enable a more efficient automation environment.

=over

=item Arguments

    None

=item Returns

    Nothing

=back

=cut

sub setSystem {

    my( $self, %args )=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    my $sub = 'setSystem';
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    $self->{conn}->cmd(String => "tlntadmn config timeoutactive=no", Timeout=> $self->{DEFAULTTIMEOUT}); #Disabling the Telnet session timeout

    $logger->debug(__PACKAGE__ . ".setSystem: ENTERED GLCAS SERVER SUCCESSFULLY");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< execCmd() >

    This function enables user to execute any command on the server.

=over

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Return Value:

    Output of the command executed.

=item Example:

    my @results = $obj->execCmd("cat test.txt");
    This would execute the command "cat test.txt" on the session and return the output of the command.

=back

=cut

sub execCmd {
    my ($self,$cmd, $timeout)=@_;
    my $sub_name = "execCmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name  ...... ");
    my @cmdResults;
    $logger->debug(__PACKAGE__ . ".$sub_name --> Entered Sub");
    unless (defined $timeout) {
        $timeout = $self->{DEFAULTTIMEOUT};
        $logger->debug(__PACKAGE__ . ".$sub_name: Timeout not specified. Using $timeout seconds ");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Timeout specified as $timeout seconds ");
    }

    $logger->info(__PACKAGE__ . ".$sub_name ISSUING CMD: $cmd");
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        $logger->error(__PACKAGE__ . ".$sub_name:  COMMAND EXECTION ERROR OCCURRED");
      $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug (__PACKAGE__ . ".$sub_name:  errmsg : ". $self->{conn}->errmsg);
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [0]");
        return 0;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".$sub_name ...... : @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return @cmdResults;
}

=head2 B<execCmdsNValidateNull()>

    This function executes commands and validate "Null" for command 'Set' in GLCAS subroutines

=over 6

=item Arguments:

    Mandatory:
      - list of command

=item Returns:

    Returns 1 - If succeeds
    Returns 0 - If Failed

=item Example:
    my @cmd = (
                "GetInfo 1 17 Offhook",
                'set Offhook "Null"',
                "maps cmd 1 UserEvent 17 {\"Offhook\"}",
                "waitforevent 1 17 Offhook 30 sec",
                );
    $obj->execCmdsNValidateNull(@cmd);

=back

=cut

sub execCmdsNValidateNull {
    my ($self, @cmd) = @_;
    my $sub_name = "execCmdsNValidateNull";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($#cmd >= 1){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmd_results;
    my $flag = 1;
    foreach (@cmd) {
        @cmd_results = $self->execCmd($_);
        if (/\"Null\"/) {
            unless (grep /Null/, @cmd_results) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$_' ");
                $flag = 0;
                last;
            }
        } else {
            unless (@cmd_results) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$_' ");
                $flag = 0;
                last;
            }
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<validateSetCmd()>

    This function validates command 'Set ...'

=over 6

=item Arguments:

    Mandatory:
      - Type of set

=item Returns:

    Returns 1 - If succeeds
    Returns 0 - If Failed

=item Example:

    $obj->validateSetCmd("set Onhook"); 
    $obj->validateSetCmd("puts \$DetectBusyTone");

=back

=cut

sub validateSetCmd {
    my ($self, $cmd) = @_;
    my $sub_name = "validateSetCmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my @output = $self->execCmd($cmd);
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $result_code;
    my %status_cmd = (
                        0 => 'Pass',
                        1 => 'Timeout',
                        10 => 'Invalid digit type',
                        20 => 'Invalid region',
                        30 => 'Fax out of rates',
                        31 => 'Fax invalid data rate',
                        32 => 'Fax frame check error',
                        33 => 'Fax failure',
                        34 => 'Fax another session active',
                        35 => 'Fax T1 timeout',
                        36 => 'Fax cannot open TIFF file',
                        37 => 'Fax TIFF file name missing',
                    );
    foreach (@output) {
        if (/(\d+)/) {
            $result_code = $1;
            $logger->debug(__PACKAGE__.".$sub_name: \$result_code is $result_code");
            last;
        }
    }

    if ($result_code eq ""|| grep /Null/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: command '$cmd' does not return result code ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if ($result_code){
        $logger->error(__PACKAGE__ . ".$sub_name: Fail reason is $status_cmd{$result_code} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 B<initializeCAS()>

    This function connect to GLCAS server and do initialization.

=over 6

=item Arguments:

    Mandatory:
      -cas_port: CAS server port
      -cas_ip: CAS server IP
      -list_port: List port to initilize

=item Returns:

    Returns 1 - If succeeds
    Returns 0 - If Failed

=item Example:

    my %args = (-cas_ip => '10.250.185.232', -cas_port => '10024', -list_port => ['17', '18', '19']); 
    $obj->initializeCAS(%args);

=back

=cut

sub initializeCAS {
    my ($self, %args) = @_;
    my $sub_name = "initializeCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $prevPrompt = $self->{conn}->prompt('/%\s?/');
    my @lineName =  (
              "Card1TS00", "Card1TS01", "Card1TS02", "Card1TS03", "Card1TS04", "Card1TS05", "Card1TS06", "Card1TS07",
              "Card1TS08", "Card1TS09", "Card1TS10", "Card1TS11", "Card1TS12", "Card1TS13", "Card1TS14", "Card1TS15",
              "Card1TS16", "Card1TS17", "Card1TS18", "Card1TS19", "Card1TS20", "Card1TS21", "Card1TS22", "Card1TS23",
              "Card2TS00", "Card2TS01", "Card2TS02", "Card2TS03", "Card2TS04", "Card2TS05", "Card2TS06", "Card2TS07",
              "Card2TS08", "Card2TS09", "Card2TS10", "Card2TS11", "Card2TS12", "Card2TS13", "Card2TS14", "Card2TS15",
              "Card2TS16", "Card2TS17", "Card2TS18", "Card2TS19", "Card2TS20", "Card2TS21", "Card2TS22", "Card2TS23",
                    );

    my $flag = 1;
    foreach ('-cas_ip', '-cas_port', '-list_port') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmd = (
                "tclsh85",
                "load mapsclientifc.dll",
                "maps connect 1 $args{-cas_ip} $args{-cas_port}",
                'maps cmd 1 {Start "TestBedDefault.xml"}',
                'maps cmd 1 {LoadProfile "CAS_Profiles.xml"}',
                );
    foreach (@cmd) {
        unless ($self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$_' ");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Initialize ports
    foreach(@{$args{-list_port}}){
        my $timeslot = $_ - 1;
        unless ($self->execCmd("maps cmd 1 StartScript $_ {\"cli_cas.gls\" \"$lineName[$timeslot]\"} 1")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot start script port $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Initialize GLCAS successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;  
}


=head2 B<onhookCAS()>

    This function goes onhook the testhead line specified.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds) 

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->onhookCAS(%args);

=back

=cut

sub onhookCAS {
    my ($self, %args) = @_;
    my $sub_name = "onhookCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '{-line_port}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} Onhook",
                'set Onhook "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Onhook\"}",
                "waitforevent 1 $args{-line_port} Onhook $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set Onhook")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set Onhook' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: onhook line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectDialToneCAS()>

    This function detects the presence of the dial tone on the testhead within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    Belgium (BE) — 450 — Continuous
    Brazil (BR) — 425 — Continuous
    China (CN) — 450 — Continuous
    Finland (FI) — 425 — Continuous
    France (FR) — 440 — Continuous
    Germany (DE) — 435 — Continuous
    Israel (IL) — 400 — Continuous
    Italy (IT) — 425 — 0.6 on, 1 off, 0.2 on, 0.2 off
    Japan (JP) — 400 — Continuous
    The Netherlands (NL) — 150 + 450 — Continuous
    Norway (NO) — 425 — Continuous
    Singapore (SG) — 270 + 320 — Continuous
    South Korea (KR) — 350 + 440 — Continuous
    Spain (ES) — 400 — Continuous
    Sweden (SE) — 425 — Continuous
    Switzerland (CH) — 425 — Continuous
    Taiwan (TW) — 350 + 440 — Continuous
    United Kingdom (UK) — 350 + 440 — Continuous
    United States (US) — 350 + 440 — Continuous

    Note: TONE_TYPE must be set to ‘1’ to enable the duration parameter feature

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -dial_tone_duration: Dial tone duration (miliseconds)
        -cas_timeout: CAS timeout (default: 20000 ms)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -dial_tone_duration => '2000', -cas_timeout => '50000',-wait_for_event_time => 30); 
    $obj->detectDialToneCAS(%args);

=back

=cut

sub detectDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-dial_tone_duration} ||= 0;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectDialTone",
                'set DetectDialTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Dial Tone\"} # DIAL_TONE_DURATION = $args{-dial_tone_duration} , TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectDialTone $args{-wait_for_event_time} sec"
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->validateSetCmd("set DetectDialTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectDialTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectDialTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setToneDetectionCAS()>

    This function set tone detection for the testhead line specified.
    Set tone detection mode:
        - Tone type 0: Detect tone presence only.
        - Tone type 1: Verify tone is present for specified duration (Implemented for dial tone, busy tone, and reorder tone).

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -tone_type: Tone type:  
            0 - set tone type detection to presence only (Default)
            1 - Verify tone is present for a specified duration (used in Dial Tone, Busy Tone and Reorder Tone detection)
      -wait_for_event_time: Wait for event time (deafault: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -tone_type => 0,-wait_for_event_time => 30); 
    $obj->setToneDetectionCAS(%args);

=back

=cut

sub setToneDetectionCAS {
    my ($self, %args) = @_;
    my $sub_name = "setToneDetectionCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '{-line_port}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-tone_type} ||= 0;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} SetToneDetection",
                'set SetToneDetection "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Set Tone Detection\"} # TONE_TYPE = $args{-tone_type}",
                "waitforevent 1 $args{-line_port} SetToneDetection $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set SetToneDetection")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set SetToneDetection' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Set Tone Detection line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 B<cleanupCAS()>

    This function cleans up the CAS session, shutdowns the scripts that were started, stops the testbed and closes the MAPS Session

=over 6

=item Arguments:

    Mandatory:
      -list_port: List port

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-list_port => ['17', '18', '19']); 
    $obj->cleanupCAS(%args);

=back

=cut

sub cleanupCAS {
    my ($self, %args) = @_;
    my $sub_name = "cleanupCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless (@{$args{-list_port}}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$args{-list_port}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $flag = 1;
    foreach (@{$args{-list_port}}) {
        unless ($self->execCmd("maps cmd 1 StopScript $_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'maps cmd 1 StopScript $_' ");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->execCmd("maps disconnect 1")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'maps disconnect 1' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: cleanup GL-CAS successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setRegionCAS()>

    This function Set region for call progress tone detection.
    Region (Code) — Call Progress Tones Supported:
    ------------------------------------------
    Belgium (BE) — Busy, Dial, Ring
    Brazil (BR) — Busy, Dial, Ring
    China (CN) — Busy, Call Waiting, Dial, Ring
    Finland (FI) — Busy, Dial, Ring
    France (FR) — Call in Progress, Call Waiting, Congestion, Dial, Ring, Special Dial, Special Information
    Germany (DE) — Busy, Dial, Ring
    Israel (IL) — Busy, Dial, Ring
    Italy (IT) — Busy, Dial, Ring
    Japan (JP) — Busy, Dial, Ring
    The Netherlands (NL) — Busy, Dial, Ring
    Norway (NO) — Busy, Dial, Ring
    Singapore (SG) — Busy, Dial, Ring
    South Korea (KR) — Busy, Dial, Ring
    Sweden (SE) — Busy, Dial, Ring
    Switzerland (CH) — Busy, Dial, Ring
    Spain (ES) — Busy, Dial, Ring
    Taiwan (TW) — Busy, Dial, Ring
    United Kingdom (UK) — Busy, Call Waiting, Dial, Ring
    United States (US) — Busy, Call Waiting, Confirmation, Dial, Reorder, Ring, Special Dial

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
      -region_code: Region code (Ex: US, BR, TW, UK,...)
    Optional:
      -wait_for_event_time: Wait for event time (defaut: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -region_code => 'US',-wait_for_event_time => 30); 
    $obj->setRegionCAS(%args);

=back

=cut

sub setRegionCAS {
    my ($self, %args) = @_;
    my $sub_name = "setRegionCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-line_port', '-region_code') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} SetRegion",
                'set SetRegion "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Set Region\"} # REGION = {\"$args{-region_code}\"}",
                "waitforevent 1 $args{-line_port} SetRegion $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->validateSetCmd("set SetRegion")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set SetRegion' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Set region line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<initializeCall()>

    This function is for basic call between 2 CAS Lines.

=over 6

=item Arguments:

    Mandatory:
      -cas_server: CAS server info
      -list_port: List port
    Optional:
      -tone_type: Tone type:
            0 - set tone type detection to presence only (default)
            1 - Verify tone is present for a specified duration (used in Dial Tone, Busy Tone and Reorder Tone detection)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -cas_server => ['10.250.185.232','10024'],
                -list_port => ['17','18','19'],
                -tone_type => 0
                ); 
    $obj->initializeCall(%args);

=back

=cut

sub initializeCall {
    my ($self, %args) = @_;
    my $sub_name = "initializeCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-cas_server', '-list_port') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-tone_type} ||= 0;
    my $wait_for_event_time = 30;

    unless ($self->initializeCAS (-cas_ip => $args{-cas_server}[0], -cas_port => $args{-cas_server}[1], -list_port => $args{-list_port})) {
        unless($self->cleanupCAS (-list_port => $args{-list_port})) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cleanup GL-CAS");
        }
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Initialize GL-CAS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
    }

    foreach (@{$args{-list_port}}) {
        unless ($self->onhookCAS (-line_port => $_, -wait_for_event_time => $wait_for_event_time)) {
            unless ($self->cleanupCAS (-list_port => $args{-list_port})) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to cleanup GL-CAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to onhook line $_ ");
            $flag = 0;
            last;
        }

        unless ($self->setToneDetectionCAS (-line_port => $_, -tone_type => $args{-tone_type}, -wait_for_event_time => $wait_for_event_time)) {
            unless ($self->cleanupCAS (-list_port => $args{-list_port})) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to cleanup GL-CAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to set tone detection line $_ ");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Initialize call successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<offhookCAS()>

    This function goes offhook the testhead line specified.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->offhookCAS(%args);

=back

=cut

sub offhookCAS {
    my ($self, %args) = @_;
    my $sub_name = "offhookCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '{-line_port}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} Offhook",
                'set Offhook "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Offhook\"}",
                "waitforevent 1 $args{-line_port} Offhook $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set Offhook")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set Offhook' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Offhook line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<sendDigitsWithDurationCAS()>

    This function sends the specified DTMF or MF digits on the circuit.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
      -dialed_number: Dialed number
    Optional:
      -digit_on: Digit on duration (miliseconds) (default: 80)
      -digit_off: Digit off duration (miliseconds) (default: 80)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -line_port => '17',
                -dialed_number => '1514004315',
                -digit_on => 300,
                -digit_off => 300,
                -wait_for_event_time => 30
                ); 
    $obj->sendDigitsWithDurationCAS(%args);

=back

=cut

sub sendDigitsWithDurationCAS {
    my ($self, %args) = @_;
    my $sub_name = "sendDigitsWithDurationCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-line_port', '-dialed_number') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-digit_on} ||= 80;
    $args{-digit_off} ||= 80;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set SendDigits "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Send Digits\"} # DIGITS = {\"$args{-dialed_number}\"} , DIGIT_ON = $args{-digit_on}, DIGIT_OFF = $args{-digit_off}, TIMEOUT = 20000",
                "waitforevent 1 $args{-line_port} SendDigits $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set SendDigits")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set SendDigits' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: SendDigits line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectRingbackToneCAS()>

    This Function detects the presence of the ringback tone on the testhead within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    Belgium (BE) — 450 — 1 on, 3 off
    Brazil (BR) — 425 — 1 on, 4 off
    China (CN) — 450 — 1 on, 4 off
    Finland (FI) — 425 — 1 on, 4 off
    France (FR) — 440 — 1.5 on, 1.5 off
    Germany (DE) — 435 — 1 on, 4 off
    Israel (IL) — 400 + 450 — 1 on, 3 off
    Italy (IT) — 425 — 1 on, 4 off
    Japan (JP) — 384 + 416 — 1 on, 2 off
    The Netherlands (NL) — 425 — 1 on, 4 off
    Norway (NO) — 425 — 1 on, 4 off
    Singapore (SG) — 400 — 0.4 on, 0.4 off, 0.2 on, 0.2 off
    South Korea (KR) — 440 + 480 — 1 on, 2 off
    Spain (ES) — 425 — 1.5 on, 3 off
    Sweden (SE) — 425 — 1 on, 4 off
    Switzerland (CH) — 425 — 1 on, 4 off
    Taiwan (TW) — 440 + 480 — 1 on, 2 off
    United Kingdom (UK) — 400 + 450 — 0.4 on, 0.2 off
    United States (US) — 440 + 480 — 2 on, 2 off

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -ring_count: Ring count (default: 2)
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -ring_count => 2, -cas_timeout => 50000, -wait_for_event_time => 30); 
    $obj->detectRingbackToneCAS(%args);

=back

=cut

sub detectRingbackToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectRingbackToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-ring_count} ||= 2;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectRingbackTone",
                'set DetectRingbackTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Ringback Tone\"} # RING_COUNT = $args{-ring_count}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectRingbackTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectRingbackTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectRingbackTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectRingbackTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectRingingSignalCAS()>

    This Function detects the presence of the ringing signal on the testhead within a specified timeout (ms) period

    Inputs:
    RING_COUNT int (opt) Number of rings to detect 2
    RING_ON float (opt) On duration of ring 2000.00 (ms)
    RING_OFF float (opt) Off duration of ring 4000.00 (ms)
    TIMEOUT int (opt) General timeout value 20000 (ms)

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -ring_count: Ring count (default: 2)
      -ring_on: RingOn duration (default: 0 ms)
      -ring_off: RingOff duration (default: 0 ms)
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -line_port => '17',
                -ring_count => 1,
                -ring_on => 2000,
                -ring_off => 4000,
                -cas_timeout => 50000,
                -wait_for_event_time => 30,
                );
    $obj->detectRingingSignalCAS(%args);

=back

=cut

sub detectRingingSignalCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectRingingSignalCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-ring_count} ||= 2;
    $args{-ring_on} ||= 0;
    $args{-ring_off} ||= 0;
    $args{-ring_on} += 0.01;
    $args{-ring_off} += 0.01;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectRingingSignal",
                'set DetectRingingSignal "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Ringing Signal\"} # RING_COUNT = $args{-ring_count}, RING_ON = $args{-ring_on}, RING_OFF = $args{-ring_off}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectRingingSignal $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectRingingSignal")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectRingingSignal' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectRingingSignal line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 B<detectDistinctiveRingingSignalCAS()>

    This Function detects the presence of an user-defined distinctive ringing signal on the test-head within a specified timeout (milliseconds) period.
    Supports up to 4 distinctive ring on/offs per ring cycle.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -ring_count: Ring count (default: 2)
      -ring_on1: RingOn duration 1 (default: 0 ms)
      -ring_off1: RingOff duration 1 (default: 0 ms)
      -ring_on2: RingOn duration 2 (default: 0 ms)
      -ring_off2: RingOff duration 2 (default: 0 ms)
      -ring_on3: RingOn duration 3 (default: 0 ms)
      -ring_off3: RingOff duration 3 (default: 0 ms)
      -ring_on4: RingOn duration 4 (default: 0 ms)
      -ring_off4: RingOff duration 4 (default: 0 ms)
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -line_port => '17',
                -ring_count => 1,
                -ring_on1 => 2000,
                -ring_off1 => 4000,
                -ring_on2 => 2000,
                -ring_off2 => 4000,
                -ring_on3 => 2000,
                -ring_off3 => 4000,
                -ring_on4 => 0,
                -ring_off4 => 0,
                -cas_timeout => 50000,
                -wait_for_event_time => 30,
                );
    $obj->detectDistinctiveRingingSignalCAS(%args);

=back

=cut

sub detectDistinctiveRingingSignalCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectDistinctiveRingingSignalCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-ring_count} ||= 2;

    foreach ('-ring_on1','-ring_off1','-ring_on2','-ring_off2','-ring_on3','-ring_off3','-ring_on4','-ring_off4'){
        unless ($args{$_}){
            $args{$_} = 0;
        }
        $args{$_} += 0.01;
    }
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectDistinctiveRingingSignal",
                'set DetectDistinctiveRingingSignal "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Distinctive Ringing Signal\"} # RING_COUNT = $args{-ring_count}, RON1 = $args{-ring_on1}, ROFF1 = $args{-ring_off1}, RON2 = $args{-ring_on2}, ROFF2 = $args{-ring_off2}, RON3 = $args{-ring_on3}, ROFF3 = $args{-ring_off3}, RON4 = $args{-ring_on4}, ROFF4 = $args{-ring_off4}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectDistinctiveRingingSignal $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectDistinctiveRingingSignal")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectDistinctiveRingingSignal' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Distinctive Ringing Signal line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectBusyToneCAS()>

    This function detects the presence of the busy tone on the test head within a specified timeout (milliseconds) period.
    Notes:  TONE_TYPE must be set to 1 to enable duration of of tone feature.

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    Belgium (BE) — 450 — 0.15 on, 0.15 off, repeat
    Brazil (BR) — 425 — 0.5 on, 0.5 off, repeat
    China (CN) — 450 — 0.35 on, 0.35 off, repeat
    Finland (FI) — 425 — 0.3 on, 0.3 off, repeat
    France (FR) — 440 — 0.5 on, 0.5 off, repeat
    Germany (DE) — 435 — 0.5 on, 0.5 off, repeat
    Israel (IL) — 400 — 0.5 on, 0.5 off, repeat
    Italy (IT) — 425 — 0.5 on, 0.5 off, repeat
    Japan (JP) — 400 — 0.5 on, 0.5 off, repeat
    The Netherlands (NL) — 425 — 0.5 on, 0.5 off, repeat
    Norway (NO) — 425 — 0.5 on, 0.5 off, repeat
    Singapore (SG) — 270 + 320 — 0.75 on, 0.75 off, repeat
    South Korea (KR) — 480 + 620 — 0.5 on, 0.5 off, repeat
    Spain (ES) — 435 — 0.2 on, 0.2 off, repeat
    Sweden (SE) — 425 — 0.25 on, 0.25 off, repeat
    Switzerland (CH) — 425 — 0.5 on, 0.5 off, repeat
    Taiwan (TW) — 480 + 620 — 0.5 on, 0.5 off, repeat
    United Kingdom (UK) — 400 — 0.4 on, 0.4 off, repeat
    United States (US) — 480 + 620 — 0.5 on, 0.5 off, repeat

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -busy_tone_duration: Busy tone duration (miliseconds)
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -busy_tone_duration => 2000, -cas_timeout => 50000,-wait_for_event_time => 30); 
    $obj->detectBusyToneCAS(%args);

=back

=cut

sub detectBusyToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectBusyToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-busy_tone_duration} ||= 1;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectBusyTone",
                'set DetectBusyTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Busy Tone\"} # BUSY_TONE_DURATION = $args{-busy_tone_duration} , TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectBusyTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("puts \$DetectBusyTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'puts \$DetectBusyTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectBusyTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectTestToneCAS()>

    Start the detector for test tone. Use "stopDetectTestToneCAS" to receive result.
    Detect the presence of the 1004 Hz test tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -cas_timeout => 50000); 
    $obj->startDetectTestToneCAS(%args);

=back

=cut

sub startDetectTestToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectTestToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectTestTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Test Tone\"} # TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectTestTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectTestToneCAS()>

    This function detect the presence of the 1004 Hz test tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectTestToneCAS(%args);

=back

=cut

sub stopDetectTestToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectTestToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectTestTone "Null"',
                "waitforevent 1 $args{-line_port} DetectTestTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectTestTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectTestTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectTestTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<sendTestToneCAS()>

    This function sends the 1004 Hz, 0 dBm test tone on the circuit for a user-defined duration (milliseconds)

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -test_tone_duration: Test tone duration (default: 3000 miliseconds)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -test_tone_duration => '3000', -wait_for_event_time => 30); 
    $obj->sendTestToneCAS(%args);

=back

=cut

sub sendTestToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "sendTestToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-test_tone_duration} ||= 3000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} SendTestTone",
                'set SendTestTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Send Test Tone\"} # TONE_DURATION = $args{-test_tone_duration}",
                "waitforevent 1 $args{-line_port} SendTestTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set SendTestTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set SendTestTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: SendTestTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectNoTestToneCAS()>

    This function detects there is not the presence of the 1004 Hz test tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -cas_timeout => 50000, -wait_for_event_time => 30);
    $obj->detectNoTestToneCAS(%args);

=back

=cut

sub detectNoTestToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectNoTestToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 50000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectTestTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Test Tone\"} # TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectTestTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @output = $self->execCmd("set DetectTestTone");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'set DetectTestTone' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $result_code;
    my %status_cmd = (
                        0 => 'Pass',
                        1 => 'Timeout',
                        10 => 'Invalid digit type',
                        20 => 'Invalid region',
                        30 => 'Fax out of rates',
                        31 => 'Fax invalid data rate',
                        32 => 'Fax frame check error',
                        33 => 'Fax failure',
                        34 => 'Fax another session active',
                        35 => 'Fax T1 timeout',
                        36 => 'Fax cannot open TIFF file',
                        37 => 'Fax TIFF file name missing',
                    );
    foreach (@output) {
        if (/(\d+|Null)/) {
            $result_code = $1;
            $logger->debug(__PACKAGE__.".$sub_name: \$result_code is $result_code");
            last;
        }
    }

    if ($result_code eq "") {
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectTestTone' does not return result code ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if ($result_code eq '0'){
        $logger->error(__PACKAGE__ . ".$sub_name: Speechpath is still not down");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($result_code eq '1' || grep /Null/, @output){
        $logger->error(__PACKAGE__ . ".$sub_name: Fail reason is $status_cmd{$result_code} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect No Test Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<sendAndReceiveDigitsCAS()>

    This function for Sending and Verifying Digits received

=over 6

=item Arguments:

    Mandatory:
      -list_port: List port (['{DN to receive}','{DN to send}'])
      -digits: Digits to send (ex: 1234567890)
    Optional:
      -digit_type: Digit type (default: dtmf)
      -cas_timeout: CAS timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-list_port => ['9','17'], -digits => '1234567890', -digit_type => 'dtmf', -cas_timeout => 50000, -wait_for_event_time => 30);
    $obj->sendAndReceiveDigitsCAS(%args);

=back

=cut

sub sendAndReceiveDigitsCAS {
    my ($self, %args) = @_;
    my $sub_name = "sendAndReceiveDigitsCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-list_port', '-digits') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-digit_type} ||= 'dtmf';
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    unless ($self->execCmd("maps cmd 1 UserEvent $args{-list_port}[1] {\"Detect Digits\"} # DIGIT_TYPE = dtmf , TIMEOUT = $args{-cas_timeout}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'maps cmd 1 UserEvent $args{-list_port}[1] {\"Detect Digits\"}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    sleep(2);

    my @cmd = (
                'set SendDigits "Null"',
                "maps cmd 1 UserEvent $args{-list_port}[0] {\"Send Digits\"} # DIGITS = {\"$args{-digits}\"} , TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-list_port}[0] SendDigits $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set SendDigits")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set SendDigits' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    @cmd = (
            'set DetectDigits "Null"',
            "waitforevent 1 $args{-list_port}[1] DetectDigits $args{-wait_for_event_time} sec",
            );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectDigits")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectDigits' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    @cmd = (
            'set DetectedDigits "Null"',
            "waitforevent 1 $args{-list_port}[1] DetectedDigits $args{-wait_for_event_time} sec",
            );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @output = $self->execCmd("set DetectedDigits");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'set DetectedDigits' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $detectedDigits;
    foreach (@output) {
        if (/(\d+)/) {
            $detectedDigits = $1;
            $logger->debug(__PACKAGE__.".$sub_name: \$detectedDigits is $detectedDigits");
            last;
        }
    }
    unless ($detectedDigits =~ /$args{-digits}/) {
        $logger->error(__PACKAGE__ . ".$sub_name: DetectedDigits $detectedDigits is not matched with $args{-digits}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Send and receive digits successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<flashWithDurationCAS()>

    This Function flash hook the testhead

    Region                  Flash Duration (msec)
    Finland (FI)                    90
    Germany (DE)                    90
    Israel (IL)                     350
    The Netherlands (NL)            90
    Norway (NO)                     110
    Singapore (SG)                  80
    Spain (ES)                      500
    Sweden (SE)                     90
    United Kingdom (UK)             600
    United States (US)              600

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -flash_duration: Flash duration (default: 600)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -flash_duration => 600, -wait_for_event_time => 30); 
    $obj->flashWithDurationCAS(%args);

=back

=cut

sub flashWithDurationCAS {
    my ($self, %args) = @_;
    my $sub_name = "flashWithDurationCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-flash_duration} ||= 600;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set Flash "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Flash\"} # FLASH_DURATION = $args{-flash_duration}, TIMEOUT = 20000",
                "waitforevent 1 $args{-line_port} Flash $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set Flash")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set Flash' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Flash hook line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<checkSpeechPathCAS()>

    This function check speech path all lines input (>= 2 lines)
        - A sends test tone -> B detects test tone
        - A sends digits -> B detects digits

=over 6

=item Arguments:

    Mandatory:
      -list_port: List port (must be >= 2 ports)
    Optional:
      -checking_type: Checking type:
            'TESTTONE': Send/Detect Test Tone
            'DIGITS': Send & Receive Digits (DTMF)
      -test_tone_duration: Test tone duration (default: 3000 ms)
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-list_port => ['9','17'], -checking_type => ['TESTTONE'], -tone_duration => 2000, -cas_timeout => 50000);
    $obj->checkSpeechPathCAS(%args);

=back

=cut

sub checkSpeechPathCAS {
    my ($self, %args) = @_;
    my $sub_name = "checkSpeechPathCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless (@{$args{-list_port}} >= 2){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-list_port' is less than 2 ports");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (@{$args{-checking_type}}){
        @{$args{-checking_type}} = ('TESTTONE','DIGITS');
    }
    $args{-cas_timeout} ||= 20000;
    $args{-tone_duration} ||= 3000;

    my $dtmf_num = '123';
    my $wait_for_event_time = 30;
    my @list_receive_port = @{$args{-list_port}};

    my $flag = 1;
    foreach my $send_port (@{$args{-list_port}}) {
        shift (@list_receive_port);
        foreach my $receive_port(@list_receive_port) {
            if (grep /TESTTONE/, @{$args{-checking_type}}) {
                unless ($self->startDetectTestToneCAS (-line_port => $receive_port, -cas_timeout => $args{-cas_timeout})) {
                    $logger->error(__PACKAGE__ . ".$sub_name: failed at starting detect test tone line $receive_port");
                    $flag = 0;
                    last;
                }
                unless ($self->sendTestToneCAS (-line_port => $send_port, -test_tone_duration => $args{-tone_duration}, -wait_for_event_time => $wait_for_event_time)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: failed at send test tone $send_port");
                    $flag = 0;
                    last;
                }
                unless ($self->stopDetectTestToneCAS (-line_port => $receive_port, -wait_for_event_time => $wait_for_event_time)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: failed at stop detect test tone $receive_port");
                    $flag = 0;
                    last;
                }
            }
            if (grep /DIGITS/, @{$args{-checking_type}}) {
                unless ($self->sendAndReceiveDigitsCAS(
                                                        -list_port => [$receive_port, $send_port],
                                                        -digits => $dtmf_num,
                                                        -digit_type => 'dtmf',
                                                        -cas_timeout => $args{-cas_timeout},
                                                        -wait_for_event_time => $wait_for_event_time
                                                        )){
                    $logger->error(__PACKAGE__ . ".$sub_name: failed at sending and receiving digits between $receive_port \& $send_port");
                    $flag = 0;
                    last;
                }
            }
        }
        unless ($flag){
            last;
        }
        push (@list_receive_port, $send_port);
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Check speech path successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectSpecialDialToneCAS()>

    This function is used to start the detector for special dial tone. Use "stopDetectSpecialDialToneCAS" to receive result.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -cas_timeout => 50000); 
    $obj->startDetectSpecialDialToneCAS(%args);

=back

=cut

sub startDetectSpecialDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectSpecialDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectSpecialDialTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Special Dial Tone\"} # TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectSpecialDialTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectSpecialDialToneCAS()>

    This function detects the special dial tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectTestToneCAS(%args);

=back

=cut

sub stopDetectSpecialDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectSpecialDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectSpecialDialTone "Null"',
                "waitforevent 1 $args{-line_port} DetectSpecialDialTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->validateSetCmd("set DetectSpecialDialTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectSpecialDialTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectSpecialDialTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectConfirmationToneCAS()>

    This function is used to start the detector for confirmation tone. Use "stopDetectConfirmationToneCAS" to receive result.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -cas_timeout => 50000); 
    $obj->startDetectConfirmationToneCAS(%args);

=back

=cut

sub startDetectConfirmationToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectConfirmationToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectConfirmationTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Confirmation Tone\"} # TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectConfirmationTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectConfirmationToneCAS()>

    This function detects the spacial dial tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectConfirmationToneCAS(%args);

=back

=cut

sub stopDetectConfirmationToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectConfirmationToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectConfirmationTone "Null"',
                "waitforevent 1 $args{-line_port} DetectConfirmationTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectConfirmationTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectConfirmationTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Confirmation Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<makeCall()>

    This function is used for basic call between 2 CAS Lines and more optional.
    Input:
        - Line port A
        - Line port B
        - Region line A
        - Region line B
        - Check dial tone: 'y' : It will off-hook and detect dial tone on Line A. Default is y.
        - Dialed number
        - Digit on: Digit on duration in msec, Default is 80 (ms).
        - Digit off: Digit off duration in msec, Default is 80 (ms).
        - Detection type:
            'DELAY 2' : Delay 2 s before checking ringback/ringing tone.
            'RINGBACK' : Detect Ringback Tone on A
            'RINGBACK 480 440': Detect Ringback Tone with specific frequencies. The fisrt frequency must be greater than the second one
            'RINGING' : Detect Ringing Tone on B
            'BUSY' : Detect Busy Tone on A
        - Ring on:
            On duration of ring in msec - example 2000 (ms)
            Default is 0.
        - Ring off
            On duration of ring in msec - example 4000 (ms)
            Default is 0.
        - OnOff hook
            ['offB'] : it will off-hook B.
            ['onA', 'offB'] : it will on-hook A and then off-hook B.
            ['offB', 'onA'] : it will off-hook B and then on-hook A.
            ['NONE']: skip OnOff hook part
        - Send and receive: 
            'TESTTONE' : Send / Detect Test Tone with default duration 3000ms (Speech Path)
            'TESTTONE 100' : Send / Detect Test Tone with duration 100ms (Speech Path)
            'NO TESTTONE' : Send and Detect no Test Tone
            'DIGITS' : Send & Receive default Digits '1234567890' (DTMF)
            'DIGITS 123_456' : A sends B digits '123' and B sends A digits '456'
        - Flash scenario:
            'A' : A will dial flash once.
            'AA' : A will dial flash twice.
            'B' : B will dial flash once.
            'BB' : B will dial flash twice.

=over 6

=item Arguments:

    Mandatory:
      -lineA: Line port A
      -lineA: Line port B
      -dialed_number: Dialed number
    Optional:
      -regionA: Region line A (default US)
      -regionB: Region line B (default US)
      -check_dial_tone (y or n)
      -digit_on: Digit on
      -digit_off: Digit off
      -detect
      -ring_on: Ring on
      -ring_off: Ring off
      -on_off_hook
      -send_receive
      -flash

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -lineA => '9',
                -lineB => '17',
                -regionA => 'US',
                -regionB => 'US',
                -check_dial_tone => 'y',
                -dialed_number => '1514004315',
                -digit_on => 300,
                -digit_off => 300,
                -detect => ['RINGBACK','RINGING'],
                -ring_on => [2000],
                -ring_off => [4000],
                -on_off_hook => ['offB'],
                -send_receive => ['TESTTONE','DIGITS'],
                -flash => 'A'
                );
    $obj->makeCall(%args);

=back

=cut

sub makeCall {
    my ($self, %args) = @_;
    my $sub_name = "makeCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $wait_for_event_time = 30;
    my $dial_tone_duration = 2000;
    my $cas_timeout = 50000;
    my $ring_count = 1;
    my $busy_tone_duration = 0;
    my $flash_duration = 600;
    my $dtmf_type = 'dtmf';
    my $digit_check_type;
    my ($dtmf_num, $test_tone_duration, $str, %input);

    my $flag = 1;
    foreach ('-lineA','-lineB','-dialed_number') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-regionA} ||= 'US';
    $args{-regionB} ||= 'US';
    $args{-check_dial_tone} ||= 'y';
    unless ($args{-digit_on} ne ""|| $args{-digit_off} ne "") {
        $args{-digit_on} = $args{-digit_off} = 80;
    }
    unless (@{$args{-ring_on}} || @{$args{-ring_off}}){
        @{$args{-ring_on}} = (0);
    }
    unless (@{$args{-ring_off}}){
        @{$args{-ring_off}} = (0);
    }
    $args{-on_off_hook} ||= 'offB';
    
    # set region
    unless ($self->setRegionCAS(-line_port => $args{-lineA}, -region_code => $args{-regionA}, -wait_for_event_time => $wait_for_event_time)){
        $logger->error(__PACKAGE__ . ".$sub_name: cannot set region for line $args{-lineA} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->setRegionCAS(-line_port => $args{-lineB}, -region_code => $args{-regionB}, -wait_for_event_time => $wait_for_event_time)){
        $logger->error(__PACKAGE__ . ".$sub_name: cannot set region for line $args{-lineB} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # check dial tone line A
    if ($args{-check_dial_tone} =~ /y[e]*[s]*/i){
        unless ($self->offhookCAS(-line_port => $args{-lineA},-wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot offhook line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        %input = (
                    -line_port => $args{-lineA},
                    -dial_tone_duration => $dial_tone_duration,
                    -cas_timeout => $cas_timeout,
                    -wait_for_event_time => $wait_for_event_time
                    );
        unless ($self->detectDialToneCAS(%input)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot detect dial tone line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # line A dials
    if ($args{-dialed_number}) {
        %input = (
                -line_port => $args{-lineA},
                -dialed_number => $args{-dialed_number},
                -digit_on => $args{-digit_on},
                -digit_off => $args{-digit_off},
                -wait_for_event_time => $wait_for_event_time
                ); 
        unless ($self->sendDigitsWithDurationCAS(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: line $args{-lineA} cannot dial $args{-dialed_number}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # Delay
    if (grep /DELAY/, @{$args{-detect}}) {
        foreach (@{$args{-detect}}) {
            if (/DELAY (\d+)/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Delay $1 s");
                sleep($1);
                last;
            }
        }
    }

    # Detect Ringback tone line A
    if (grep /RINGBACK/, @{$args{-detect}}) {
        my $ringback_flag = 0;
        my ($f1, $f2);
        foreach (@{$args{-detect}}) {
            if (/RINGBACK \d+/) {
                ($f1) = ($_ =~ /RINGBACK (\d+)/);
                ($f2) = ($_ =~ /RINGBACK \d+ (\d+)/);
                $ringback_flag = 1;
                last;
            }
        }

        if ($ringback_flag) {
            $f2 ||= 0;
            %input = (
                -line_port => $args{-lineA}, 
                -freq1 => $f1,
                -freq2 => $f2,
                -tone_duration => 100,
                -cas_timeout => $cas_timeout, 
                -wait_for_event_time => $wait_for_event_time
                );
            unless ($self->detectSpecifiedToneCAS(%input)){
                $logger->error(__PACKAGE__ . ".$sub_name: cannot detect ringback tone line $args{-lineA} with Frequency1 = $f1 and Frequency2 = $f2");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $logger->debug(__PACKAGE__ . ".$sub_name: Detect ringback tone line $args{-lineA} with Frequency1 = $f1 and Frequency2 = $f2 successfully");
            }
        } else {
            %input = (
                    -line_port => $args{-lineA},
                    -ring_count => $ring_count,
                    -cas_timeout => $cas_timeout,
                    -wait_for_event_time => $wait_for_event_time,
                 );  
            unless ($self->detectRingbackToneCAS(%input)){
                $logger->error(__PACKAGE__ . ".$sub_name: cannot detect ringback tone line $args{-lineA} ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }
    }

    # Detect Ringing signal line B
    if (grep /RINGING/, @{$args{-detect}}) {
        if (@{$args{-ring_on}} == 1 && @{$args{-ring_off}} == 1) {
            # Detect normal ringing signal
            %input = (
                        -line_port => $args{-lineB},
                        -ring_count => $ring_count,
                        -ring_on => $args{-ring_on}[0],
                        -ring_off => $args{-ring_off}[0],
                        -cas_timeout => $cas_timeout,
                        -wait_for_event_time => $wait_for_event_time,
                     );
            unless ($self->detectRingingSignalCAS(%input)){
                $logger->error(__PACKAGE__ . ".$sub_name: cannot detect ringing signal line $args{-lineB} ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }else{
            # Detect distinctive ringing signal
            if (@{$args{-ring_on}} < 4) {
                for (my $comp = @{$args{-ring_on}}; $comp < 4; $comp++) {
                    $args{-ring_on}[$comp] = 0;
                }
            }
            if (@{$args{-ring_off}} < 4) {
                for (my $comp = @{$args{-ring_off}}; $comp < 4; $comp++) {
                    $args{-ring_off}[$comp] = 0;
                }
            }
            %input = (
                        -line_port => $args{-lineB},
                        -ring_count => $ring_count,
                        -ring_on1 => $args{-ring_on}[0],
                        -ring_off1 => $args{-ring_off}[0],
                        -ring_on2 => $args{-ring_on}[1],
                        -ring_off2 => $args{-ring_off}[1],
                        -ring_on3 => $args{-ring_on}[2],
                        -ring_off3 => $args{-ring_off}[2],
                        -ring_on4 => $args{-ring_on}[3],
                        -ring_off4 => $args{-ring_off}[3],
                        -cas_timeout => $cas_timeout,
                        -wait_for_event_time => $wait_for_event_time,
                     );
            unless ($self->detectDistinctiveRingingSignalCAS(%input)){
                $logger->error(__PACKAGE__ . ".$sub_name: cannot detect distinctive ringing signal line $args{-lineB} ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }   
    }

    # Detect Busy tone
    if (grep /BUSY/, @{$args{-detect}}) {
        %input = (
                    -line_port => $args{-lineA},
                    -busy_tone_duration => $busy_tone_duration,
                    -cas_timeout => $cas_timeout,
                    -wait_for_event_time => $wait_for_event_time
                 ); 
        unless ($self->detectBusyToneCAS(%input)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot detect busy tone line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    
    # OnOff hook
    if ($args{-on_off_hook}[0] =~ /onA/i) {# onhook A before offhook B
        unless ($self->onhookCAS(-line_port => $args{-lineA},-wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot onhook line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    if (grep /offB/, @{$args{-on_off_hook}}){
        unless ($self->offhookCAS(-line_port => $args{-lineB}, -wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot offhook line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    if ($args{-on_off_hook}[1] =~ /onA/i) {# onhook A after offhook B
        unless ($self->onhookCAS(-line_port => $args{-lineA},-wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot onhook line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # check speech path
    # A send Test tone to B and vice versa
    if (grep /^TESTTONE/, @{$args{-send_receive}}){
        foreach (@{$args{-send_receive}}) {
            if (/TESTTONE (\d+)/i) {
                $test_tone_duration = $1;
                last;
            }
        }     
        %input = (
                    -list_port => [$args{-lineA},$args{-lineB}], 
                    -checking_type => ['TESTTONE'], 
                    -tone_duration => $test_tone_duration, 
                    -cas_timeout => $cas_timeout
                 );
        unless ($self->checkSpeechPathCAS(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Test tone");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # check no test tone
    my ($lineA, $lineB);
    if (grep /NO TESTTONE/, @{$args{-send_receive}}){
        $test_tone_duration = 3000;
        foreach ('-lineA','-lineB'){
            $lineA = $args{-lineA};
            $lineB = $args{-lineB};
            if (/\-lineB/i) {
                $lineA = $args{-lineB};
                $lineB = $args{-lineA};
            }
            unless ($self->sendTestToneCAS(-line_port => $lineA, -test_tone_duration => $test_tone_duration, -wait_for_event_time => $wait_for_event_time)) {
                $logger->error(__PACKAGE__ . ".$sub_name: line $lineA cannot send test tone ");
                $flag = 0;
                last;
            }
            unless ($self->detectNoTestToneCAS(-line_port => $lineB, -cas_timeout => $cas_timeout, -wait_for_event_time => $wait_for_event_time)) {
                $logger->error(__PACKAGE__ . ".$sub_name: line $lineB cannot detect no test tone ");
                $flag = 0;
                last;
            }
            sleep(2);
        }
        unless($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # A send digits to B and vice versa
    if (grep /DIGITS/, @{$args{-send_receive}}){
        foreach (@{$args{-send_receive}}) {
            if (/(DIGITS.*)/i) {
                $digit_check_type = $1;
                last;
            }
        }
        %input = (
                    -lineA => $args{-lineA}, 
                    -lineB => $args{-lineB},
                    -checking_type => $digit_check_type, 
                    -cas_timeout => $cas_timeout
                );
        unless ($self->checkDigits(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Digits");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # flash with duration
    my $flash_line;
    if ($args{-flash} =~ /^(\w)/i) {
        if ($1 =~ /A/i) {
            $flash_line = $args{-lineA};
        }else{
            $flash_line = $args{-lineB};
        }
        sleep(5);
        unless ($self->flashWithDurationCAS(-line_port => $flash_line, -flash_duration => $flash_duration, -wait_for_event_time => $wait_for_event_time)) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot flash hook line $flash_line ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ($args{-flash} =~ /^\w{2}/i) {
            sleep(5);
            unless ($self->flashWithDurationCAS(-line_port => $flash_line, -flash_duration => $flash_duration, -wait_for_event_time => $wait_for_event_time)) {
                $logger->error(__PACKAGE__ . ".$sub_name: cannot flash hook line $flash_line second time ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
            # check speech path after hold + resume
            # check test tone
            if (grep /^TESTTONE/, @{$args{-send_receive}}){
                %input = (
                            -list_port => [$args{-lineA},$args{-lineB}], 
                            -checking_type => ['TESTTONE'], 
                            -tone_duration => $test_tone_duration, 
                            -cas_timeout => $cas_timeout
                        );
                unless ($self->checkSpeechPathCAS(%input)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Test tone after hold + resume");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                    return 0;
                }
            }
            # check digits
            if (grep /DIGITS/, @{$args{-send_receive}}){
                %input = (
                            -lineA => $args{-lineA}, 
                            -lineB => $args{-lineB},
                            -checking_type => $digit_check_type, 
                            -cas_timeout => $cas_timeout
                        );
                unless ($self->checkDigits(%input)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Digits hold + resume");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                    return 0;
                }
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Make call successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<recordSessionCAS()>

    This function creates PCM trace files and return the file paths

=over 6

=item Arguments:

    Mandatory:
        -list_port
    Optional:
        -home_directory: (S)FTP home directory of GLCAS server. default: C:\

=item Returns:

    Returns list of file names - If Passed
    Returns empty array - If Failed

=item Example:

    my @list_file_name = $obj->recordSessionCAS(-list_port => [9, 17], -home_directory => "C:\\");

=back

=cut

sub recordSessionCAS {
    my ($self, %args) = @_;
    my $sub_name = "recordSessionCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless (@{$args{-list_port}}) {
        $logger->error(__PACKAGE__ . ".$sub_name: mandatory parameter '-list_port' is not presented");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
		return ();
    }
    $args{-home_directory} ||= "C:\\";
    my $recv_file_dir = "C:\\Recordings\\";
    my @recv_file_name;
    my $recv_file_duration = 1000000;

    unless ($recv_file_dir =~ /C:/) {
        $logger->error(__PACKAGE__ . ".$sub_name: The folder contains PCM files must be a subfolder of (S)FTP home directory.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
		return ();
    }

    my ($datestring,$str,@cmd);
    for (my $i = 0; $i < @{$args{-list_port}}; $i++) {
        $datestring = strftime "%Y_%m_%d_%H_%M_%S", localtime;
        $recv_file_name[$i] = $recv_file_dir . $datestring . '_Line' . $args{-list_port}[$i] . "\.pcm";

        @cmd = (
                "GetInfo 1 $args{-list_port}[$i] ReceiveFile",
                "maps cmd 1 UserEvent $args{-list_port}[$i] {\"Receive File\"} # RX_PATH = {\"$recv_file_name[$i]\"} , FILE_DURATION =$recv_file_duration",
                );
        unless ($self->execCmdsNValidateNull(@cmd)){
            $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return ();
        }
        $recv_file_name[$i] =~ s/C:\\/\//;
        $recv_file_name[$i] =~ s/\\/\//;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: list of file names" . Dumper(\@recv_file_name));
    unless (@recv_file_name) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot get PCM file name");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
		return ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: get PCM file name successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return @recv_file_name;
}

=head2 B<basicCallGLCAS()>

    This function is used for basic call between 2 CAS Lines and more optional.
    Input:
        - CAS server: [CAS_Server_IP, CAS_Server_Port]. Default is ['47.133.148.58', '10024']
        - Line port A
        - Line port B
        - Region line A
        - Region line B
        - Dialed number
        - Digit on: Digit on duration in msec, Default is 80 (ms).
        - Digit off: Digit off duration in msec, Default is 80 (ms).
        - Detection type:
            'DELAY 2' : Delay 2 seconds before checking ringback/ringing tone.
            'RINGBACK' : Detect Ringback Tone on A (default)
            'RINGING' : Detect Ringing Tone on B (default)
            'RINGTIME 20' : Time for waiting after checking ringing tone (default is 0)
            'PCM' : capture PCM file and put to local folder "C:\PCM"
        - Ring on:
            On duration of ring in msec - example 2000 (ms)
            Default is 0.
        - Ring off:
            On duration of ring in msec - example 4000 (ms)
            Default is 0.
        - Send and receive: 
            'NoOffB' : Do not offhook Line B (Offhook B is default)
            'TESTTONE' : Send / Detect Test Tone - Speech Path (default)
            'DIGITS' : Send & Receive Digits - DTMF (default)
            'DURATION 7200': Waiting for 7200 seconds (2 hours) to check Speech Path / DTMF again. Default is 0.

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port A
        -line_port: Line port B
        -dialed_number: Dialed number
    Optional:
        -regionA: Region line A (default US)
        -regionB: Region line B (default US)
        -cas_server
        -digit_on: Digit on
        -digit_off: Digit off
        -detect
        -ring_on: Ring on
        -ring_off: Ring off
        -send_receive

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (
                -cas_server => ['10.250.185.232', '10024'],
                -lineA => '9',
                -lineB => '17',
                -regionA => 'US',
                -regionB => 'US',
                -dialed_number => '1514004315',
                -digit_on => 300,
                -digit_off => 300,
                -detect => ['RINGBACK','RINGING'],
                -ring_on => 0,
                -ring_off => 0,
                -send_receive => ['TESTTONE','DIGITS'],
                );
    $obj->basicCallGLCAS(%args);

=back

=cut

sub basicCallGLCAS {
    my ($self, %args) = @_;
    my $sub_name = "basicCallGLCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $wait_for_event_time = 30;
    my $dial_tone_duration = 2000;
    my $cas_timeout = 50000;
    my $ring_count = 1;
    my $dtmf_type = 'dtmf';
    my $dtmf_num = '1234567890';
    my $test_tone_duration = 3000;
    my $sftp_user = 'gbautomation';
    my $sftp_pass = '12345678x@X';
    my $tone_type = 0;
    my $duration = 0;
    my $cleanup = 1;
    my ($str, %input);

    my $flag = 1;
    foreach ('-lineA','-lineB','-dialed_number') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (@{$args{-cas_server}}) {
        @{$args{-cas_server}} = ('10.250.185.232','10024');
    }
    $args{-regionA} ||= 'US';
    $args{-regionB} ||= 'US';
    $args{-digit_on} ||= 80;
    $args{-digit_off} ||= 80;
    unless (@{$args{-detect}}) {
        @{$args{-detect}} = ('RINGBACK','RINGING');
    }
    $args{-ring_on} ||= 0;
    $args{-ring_off} ||= 0;
    unless (@{$args{-send_receive}}) {
        @{$args{-send_receive}} = ('TESTTONE','DIGITS');
    }

    # initialize GLCAS
    unless($self->initializeCAS(-cas_ip => $args{-cas_server}[0], -cas_port => $args{-cas_server}[1], -list_port => [$args{-lineA}, $args{-lineB}])) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot initialize GLCAS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @list_file_name = $self->recordSessionCAS(-list_port => [$args{-lineA}, $args{-lineB}], -home_directory => "C:\\");
    unless(@list_file_name) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot start record PCM");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    foreach ('-lineA','-lineB'){
        # Onhook line A & B
        unless ($self->onhookCAS(-line_port => $args{$_},-wait_for_event_time => $wait_for_event_time)){
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: cannot onhook line $args{$_} ");
            $flag = 0;
            last;
        }
        # Set tone detection for line A and B
        unless ($self->setToneDetectionCAS(-line_port => $args{$_}, -tone_type => $tone_type, -wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot set tone detection line $args{$_} ");
            $flag = 0;
            last;
        }
    }
    unless ($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Set region for line A and B
    foreach ('-lineA','-lineB') {
        unless ($self->setRegionCAS(-line_port => $args{$_}, -region_code => $args{-regionA}, -wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot set region for line $args{$_} ");
            $flag = 0;
            last;
        }
    }
    unless ($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Check dial tone line A
    unless ($self->offhookCAS(-line_port => $args{-lineA},-wait_for_event_time => $wait_for_event_time)){
        unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
        }
        $logger->error(__PACKAGE__ . ".$sub_name: cannot offhook line $args{-lineA} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    %input = (
                -line_port => $args{-lineA},
                -dial_tone_duration => $dial_tone_duration,
                -cas_timeout => $cas_timeout,
                -wait_for_event_time => $wait_for_event_time
                );
    unless ($self->detectDialToneCAS(%input)){
        unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
        }
        $logger->error(__PACKAGE__ . ".$sub_name: cannot detect dial tone line $args{-lineA} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    %input = (
                -line_port => $args{-lineA},
                -dialed_number => $args{-dialed_number},
                -digit_on => $args{-digit_on},
                -digit_off => $args{-digit_off},
                -wait_for_event_time => $wait_for_event_time
            ); 
    unless ($self->sendDigitsWithDurationCAS(%input)) {
        unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
        }
        $logger->error(__PACKAGE__ . ".$sub_name: line $args{-lineA} cannot dial $args{-dialed_number}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Delay
    if (grep /DELAY/, @{$args{-detect}}) {
        foreach (@{$args{-detect}}) {
            if (/DELAY (\d+)/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Delay $1 s after checking dial tone");
                sleep($1);
                last;
            }
        }
    }

    # Check Ringback tone Line A
    if (grep /RINGBACK/, @{$args{-detect}}) {
        unless ($self->setRegionCAS(-line_port => $args{-lineA}, -region_code => $args{-regionA}, -wait_for_event_time => $wait_for_event_time)){
            $logger->error(__PACKAGE__ . ".$sub_name: cannot set region for line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        %input = (
                    -line_port => $args{-lineA},
                    -ring_count => $ring_count,
                    -cas_timeout => $cas_timeout,
                    -wait_for_event_time => $wait_for_event_time,
                 );
        unless ($self->detectRingbackToneCAS(%input)){
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: cannot detect ringback tone line $args{-lineA} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # Check Ringing tone line B
    if (grep /RINGING/, @{$args{-detect}}) {
        %input = (
                    -line_port => $args{-lineB},
                    -ring_count => $ring_count,
                    -ring_on => $args{-ring_on},
                    -ring_off => $args{-ring_off},
                    -cas_timeout => $cas_timeout,
                    -wait_for_event_time => $wait_for_event_time,
                 );
        unless ($self->detectRingingSignalCAS(%input)){
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: cannot detect ringing signal line $args{-lineB} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # Ring time
    if (grep /RINGTIME/, @{$args{-detect}}) {
        foreach (@{$args{-detect}}) {
            if (/RINGTIME (\d+)/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Delay $1 s for ring time");
                sleep($1);
                last;
            }
        }
    }

    # offhook B
    unless (grep /NoOffB/, @{$args{-send_receive}}) {
        unless ($self->offhookCAS(-line_port => $args{-lineB},-wait_for_event_time => $wait_for_event_time)){
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: cannot offhook line $args{-lineB} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # A send Test tone to B and vice versa
    if (grep /TESTTONE/, @{$args{-send_receive}}){
        %input = (
                    -list_port => [$args{-lineA},$args{-lineB}], 
                    -checking_type => ['TESTTONE'], 
                    -tone_duration => $test_tone_duration, 
                    -cas_timeout => $cas_timeout
                 );
        unless ($self->checkSpeechPathCAS(%input)) {
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Test tone");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # Line A sends digits to line B and vice versa
    if (grep /DIGITS/, @{$args{-send_receive}}){
        %input = (
                    -lineA => $args{-lineA}, 
                    -lineB => $args{-lineB},
                    -checking_type => 'DIGITS', 
                    -cas_timeout => $cas_timeout
                );
        unless ($self->checkDigits(%input)) {
            unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Digits");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # Delay before check speech path again. Skip if $duration = 0
    if (grep /DURATION/, @{$args{-send_receive}}) {
        foreach (@{$args{-send_receive}}) {
            if (/DURATION (\d+)/i) {
                $duration = $1;
                $logger->debug(__PACKAGE__ . ".$sub_name: Delay $duration s for long call");
                sleep($duration);
                last;
            }
        }
    }

    # Case long call - check speech path again
    unless ($duration) {
        # A send Test tone to B and vice versa
        if (grep /TESTTONE/, @{$args{-send_receive}}){
            %input = (
                        -list_port => [$args{-lineA},$args{-lineB}], 
                        -checking_type => ['TESTTONE'], 
                        -tone_duration => $test_tone_duration, 
                        -cas_timeout => $cas_timeout
                    );
            unless ($self->checkSpeechPathCAS(%input)) {
                unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Test tone");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }

        # Line A sends digits to line B and vice versa
        if (grep /DIGITS/, @{$args{-send_receive}}){
            %input = (
                        -lineA => $args{-lineA}, 
                        -lineB => $args{-lineB},
                        -checking_type => 'DIGITS', 
                        -cas_timeout => $cas_timeout
                    );
            unless ($self->checkDigits(%input)) {
                unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Fail at send and receive Digits");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }
    }

    # Cleanup call
    unless ($self->onhookCAS(-line_port => $args{-lineA},-wait_for_event_time => $wait_for_event_time)){
        $logger->error(__PACKAGE__ . ".$sub_name: cannot onhook line $args{-lineA} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->onhookCAS(-line_port => $args{-lineB},-wait_for_event_time => $wait_for_event_time)){
        $logger->error(__PACKAGE__ . ".$sub_name: cannot onhook line $args{-lineB} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->cleanupCAS(-list_port => [$args{-lineA},$args{-lineB}])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot cleanup GLCAS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		return 0;
    }
    %input = (
            -remoteip => $args{-cas_server}[0],
            -remoteuser => $sftp_user,
            -remotepasswd => $sftp_pass,
            -localDir => '/home/ptthuy/PCM',
            -remoteFilePath => [@list_file_name]
            );
    if (@list_file_name) {
        unless(&SonusQA::Utils::sftpFromRemote(%input)) {
            $logger->error(__PACKAGE__ . ": ERROR COPYING FILES to the local machine");
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Make a basic GLCAS call successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<checkDigits()>

    This function checks send and receive digits between 2 lines

=over 6

=item Arguments:

    Mandatory:
      -lineA: Line port A
      -lineB: Line port B
    Optional:
      -checking_type: Checking type:
            'DIGITS': Send & Receive Digits (default: 1234567890)
            'DIGITS 123_456': Send & Receive Digits (A sends 123, B sends 456)
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-lineA => '9', -lineB => '17', -checking_type => 'DIGITS 123_456', -cas_timeout => 50000); 
    $obj->checkDigits(%args);

=back

=cut

sub checkDigits {
    my ($self, %args) = @_;
    my $sub_name = "checkDigits";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-lineA','-lineB') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-checking_type} ||= 'DIGITS';
    $args{-cas_timeout} ||= 20000;
    my ($dtmf_num, $lineA, $lineB);
    my $dtmf_type = 'dtmf';
    my $wait_for_event_time = 30;
    my $numA = '1234567890';
    my $numB = '1234567890';

    if ($args{-checking_type} =~ /DIGITS (\d+)\_(\d+)/i) {
        $numA = $1;
        $numB = $2;
    }
    
    foreach ('-lineA','-lineB'){
        $lineA = $args{-lineA};
        $lineB = $args{-lineB};
        $dtmf_num = $numA;
        if (/\-lineB/i) {
            $lineA = $args{-lineB};
            $lineB = $args{-lineA};
            $dtmf_num = $numB;
        }
        my %input = (
                    -list_port => [$lineB,$lineA], 
                    -digits => $dtmf_num, 
                    -digit_type => $dtmf_type, 
                    -cas_timeout => $args{-cas_timeout}, 
                    -wait_for_event_time => $wait_for_event_time
                    );
        unless ($self->sendAndReceiveDigitsCAS(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed at sending and receiving digits between line $lineA and line $lineB ");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Sending and receiving digits between line $lineA and line $lineB successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectCallWaitingToneCAS()>

    This function detects the presence of the call waiting tone on the test head within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    China (CN) — 450 — 0.4 on, 4 off
    France (FR) — 440 — 0.3 on, 10 off
    United Kingdom (UK) — 400 — 0.1 on, 2 off
    United States (US) — 440 — 0.3 on, 10 off

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -callwaiting_tone_duration: call waiting tone duration (default: 300 miliseconds)
      -cas_timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -callwaiting_tone_duration => 3000,
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                ); 
    $obj->detectCallWaitingToneCAS(%input);

=back

=cut

sub detectCallWaitingToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectCallWaitingToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-callwaiting_tone_duration} ||= 300;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectCallWaitingTone",
                'set DetectCallWaitingTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Call Waiting Tone\"} # CALL_WAITING_TONE_DURATION = $args{-callwaiting_tone_duration}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectCallWaitingTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectCallWaitingTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectCallWaitingTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectCallWaitingTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectCongestionToneCAS()>

    Detect the presence of the congestion tone on the testhead within a specified timeout (milliseconds) period
    Note: REGION must be set to “FR” to activate congestion tone detection

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    France (FR) — 440 — 0.5 on, 0.5 off

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17',
                -cas_timeout => 50000,
                -wait_for_event_time => 30,
                );
    $obj->detectCongestionToneCAS(%input);

=back

=cut

sub detectCongestionToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectCongestionToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectCongestionTone",
                'set DetectCongestionTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Congestion Tone\"} # TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectCongestionTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectCongestionTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectCongestionTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectCongestionTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectDistinctiveCallWaitingToneCAS()>

    Detect the presence of an user-defined call waiting tone on the test head within a specified timeout

    Input:
    Parameter           Type         Description                                        Default
    CALL_WAITING_MOE    int (opt)    Margin of error for call waiting tone in msec      50 (ms)
    CW1                 int (opt)    First cadence duration                             300 (ms)
    CW2                 int (opt)    Second cadence duration                            0 (ms)
    CW3                 int (opt)    Third cadence duration                             0 (ms)
    CW4                 int (opt)    Fourth cadence duration                            0 (ms)
    TIMEOUT             int (opt)    General timeout value in msec                      20000 (ms)

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -cw1: 1st cadence duration (msec)
        -cw2: 2nd cadence duration (msec)
        -cw3: 3rd cadence duration (msec)
        -cw4: 4th cadence duration (msec)
        -cas_timeout (default: 20000 miliseconds)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                    -line_port => '17',
                    -cw1 => 300,
                    -cw2 => 0,
                    -cw3 => 0,
                    -cw4 => 0,
                    -cas_timeout => 50000, 
                    -wait_for_event_time => 30); 
    $obj->detectDistinctiveCallWaitingToneCAS(%input);

=back

=cut

sub detectDistinctiveCallWaitingToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectDistinctiveCallWaitingToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cw1} ||= 300;
    foreach ('-cw2','-cw3','-cw4'){
        unless ($args{$_}){
            $args{$_} = 0;
        }
    } 
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectDistinctiveCallWaitingTone",
                'set DetectDistinctiveCallWaitingTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Distinctive Call Waiting Tone\"} # CW1 = $args{-cw1}, CW2 = $args{-cw2}, CW3 = $args{-cw3}, CW4 = $args{-cw4}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectDistinctiveCallWaitingTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectDistinctiveCallWaitingTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectDistinctiveCallWaitingTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Distinctive Call Waiting Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectHowlerToneCAS()>

    Detect the presence of the howler tone on the testhead within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) — Cadence (Sec)
    ------------------------------------------
    United States (US) — 1400 + 2060 + 2450 + 2600 — 0.25 on, 0.25 off

    Note: TONE_TYPE must be set to a '1' to enable the duration parameter

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -howler_tone_duration: The Expected duration of the Howler tone to detect.
                                Will return false if the actual dial tone duration is shorter or longer than expected duration.
                                TONE_TYPE must be set to 1 to enable this feature
        -cas_timeout (default: 20000 ms)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -howler_tone_duration => 3000,
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                );
    $obj->detectHowlerToneCAS(%input);

=back

=cut

sub detectHowlerToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectHowlerToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-howler_tone_duration} ||= 0;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectHowlerTone",
                'set DetectHowlerTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Howler Tone\"} # HOWLER_TONE_DURATION = $args{-howler_tone_duration}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectHowlerTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->validateSetCmd("set DetectHowlerTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectHowlerTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectHowlerTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectReorderToneCAS()>

    Detect the presence of the reorder (fast busy) tone on the testhead within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) – Cadence (Sec)
    ------------------------------------------------------
    United States (US) – 480 + 620 – 0.25 on, 0.25 off

    Note:  TONE_TYPE must be set to ‘1’ to enable duration parameter

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -reorder_tone_duration: The Expected duration of the Reorder tone to detect.
                                Will return false if the actual dial tone duration is shorter or longer than expected duration.
                                TONE_TYPE must be set to 1 to enable this feature
        -cas_timeout (default: 20000 ms)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -reorder_tone_duration => 1000,
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                );
    $obj->detectReorderToneCAS(%input);

=back

=cut

sub detectReorderToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectReorderToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-reorder_tone_duration} ||= 0;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectReorderTone",
                'set DetectReorderTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Reorder Tone\"} # REORDER_TONE_DURATION = $args{-reorder_tone_duration}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectReorderTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->validateSetCmd("set DetectReorderTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectReorderTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectReorderTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectRingSplashCAS()>

    This function detects the presence of the ring splash on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -cas_timeout (default: 20000 ms)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                );
    $obj->detectRingSplashCAS(%input);

=back

=cut

sub detectRingSplashCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectRingSplashCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectRingSplash",
                'set DetectRingSplash "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Ring Splash\"} # TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectRingSplash $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->validateSetCmd('puts $DetectRingSplash')){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'puts \$DetectRingSplash' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectRingSplash line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectStutterDialToneCAS()>

    This function detects the presence of the stutter dial tone on the testhead within a specified timeout (milliseconds) period
    
    Region                  Frequencies (Hz)    Cadence (Sec)    
    United States (US)      350 + 440           0.1 on, 0.1 off, 0.1 on, 0.1 off,
                                                0.1 on, 0.1 off, 0.1 on, 0.1 off,
                                                0.1 on, 0.1 off

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout (default: 20000 ms)
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                ); 
    $obj->detectStutterDialToneCAS(%input);

=back

=cut

sub detectStutterDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectStutterDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectStutterDialTone",
                'set DetectStutterDialTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Stutter Dial Tone\"} # DIAL_TONE_DURATION = 1000 , TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectStutterDialTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectStutterDialTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectStutterDialTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: DetectStutterDialTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectSpeechPathOneWayPairedLI()>

    This function is used in Lawful Intercept PAIRED MODE

=over 6

=item Arguments:

    Mandatory:
      -list_recv_port: list of ports which are in conference call with sent port receive testtone from sent port
      -sent_port: This port is monitored by LEA, it sends test tone
      -lea_port: This port plays LEA in Lawful Intercept.
    Optional:
      -cas_timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -list_recv_port => [17,31],
                -sent_port => 9,
                -cas_timeout => 50000,
                -lea_port => 35,
                ); 
    $obj->detectSpeechPathOneWayPairedLI(%input);

=back

=cut

sub detectSpeechPathOneWayPairedLI {
    my ($self, %args) = @_;
    my $sub_name = "detectSpeechPathOneWayPairedLI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-list_recv_port', '-sent_port', '-lea_port') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    my $wait_for_event_time = 30;
    my $test_tone_duration = 1000;

    # Detect speech path
    foreach (@{$args{-list_recv_port}}, $args{-lea_port}) {
        unless ($self->startDetectTestToneCAS (-line_port => $_, -cas_timeout => $args{-cas_timeout})) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed at starting detect test tone line $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->sendTestToneCAS (-line_port => $args{-sent_port}, -test_tone_duration => $test_tone_duration, -wait_for_event_time => $wait_for_event_time)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed at send test tone port $args{-sent_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@{$args{-list_recv_port}}, $args{-lea_port}) {
        unless ($self->stopDetectTestToneCAS (-line_port => $_, -wait_for_event_time => $wait_for_event_time)) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot detect speech path from port $_ to port $args{-sent_port}");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Detect no speech path
    unless ($self->sendTestToneCAS (-line_port => $args{-lea_port}, -test_tone_duration => $test_tone_duration, -wait_for_event_time => $wait_for_event_time)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed at send test tone port $args{-lea_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach ($args{-list_recv_port}[0], $args{-lea_port}) {
        unless ($self->detectNoTestToneCAS(-line_port => $_, -cas_timeout => '', -wait_for_event_time => $wait_for_event_time)) {
            $logger->error(__PACKAGE__ . ".$sub_name: still can detect speech path between port $_ and port $args{-lea_port}");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Check one way speech path in LI paired mode successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<detectSpeechPathOneWayLI()>

    This function is used to check speech path one way incase LEA hears conversation between A and B( C, D,...)but A, B(, C, D,...) can not hear from LEA. 
    This function is used in Lawful Intercept COMBINED MODE, and it can use in PAIRED MODE when LEA2 monitor conference's parties (B, C, D,... not include A because A is monitored by LEA1) as well.

=over 6

=item Arguments:

    Mandatory:
      -list_port: list of ports are in conference call.
      -lea_port: This port plays LEA in Lawful Intercept.
    Optional:
      -cas_timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -list_port => [17,31],
                -cas_timeout => 50000,
                -lea_port => 35,
                ); 
    $obj->detectSpeechPathOneWayLI(%input);

=back

=cut

sub detectSpeechPathOneWayLI {
    my ($self, %args) = @_;
    my $sub_name = "detectSpeechPathOneWayLI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    my $flag = 1;
    foreach ('-list_port', '-lea_port') {
        unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    my $wait_for_event_time = 30;
    my $test_tone_duration = 1000;
    my @list_receive_port = @{$args{-list_port}};

    foreach my $send_port (@{$args{-list_port}}) {
        shift (@list_receive_port);

        # Detect speech path
        foreach (@list_receive_port, $args{-lea_port}) {
            unless ($self->startDetectTestToneCAS (-line_port => $_, -cas_timeout => $args{-cas_timeout})) {
                $logger->error(__PACKAGE__ . ".$sub_name: failed at starting detect test tone line $_");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            last;
        }

        unless ($self->sendTestToneCAS (-line_port => $send_port, -test_tone_duration => $test_tone_duration, -wait_for_event_time => $wait_for_event_time)) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed at send test tone port $send_port");
            $flag = 0;
            last;
        }

        foreach (@list_receive_port, $args{-lea_port}) {
            unless ($self->stopDetectTestToneCAS (-line_port => $_, -wait_for_event_time => $wait_for_event_time)) {
                $logger->error(__PACKAGE__ . ".$sub_name: cannot detect speech path from port $_ to port $send_port");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            last;
        }
        
        # Detect no speech path
        unless ($self->sendTestToneCAS (-line_port => $args{-lea_port}, -test_tone_duration => $test_tone_duration, -wait_for_event_time => $wait_for_event_time)) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed at send test tone port $args{-lea_port}");
            $flag = 0;
            last;
        }
        foreach (@list_receive_port, $send_port) {
            unless ($self->detectNoTestToneCAS(-line_port => $_, -cas_timeout => $args{-cas_timeout}, -wait_for_event_time => $wait_for_event_time)) {
                $logger->error(__PACKAGE__ . ".$sub_name: still can detect speech path between port $_ and port $args{-lea_port}");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            last;
        }
        sleep(3); # wait a little bit before continuing checking speech path
        push (@list_receive_port, $send_port);
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Check one way speech path in LI combined mode successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<startDetectCongestionToneCAS()>

    This function is used to start the detector for congestion tone. Use "stopDetectCongestionToneCAS" to receive result.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (-line_port => '17', -cas_timeout => 50000); 
    $obj->startDetectCongestionToneCAS(%args);

=back

=cut

sub startDetectCongestionToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectCongestionToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectCongestionTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Congestion Tone\"} # TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectCongestionTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectCongestionToneCAS()>

    This function detects the congestion tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectCongestionToneCAS(%args);

=back

=cut

sub stopDetectCongestionToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectCongestionToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectCongestionTone "Null"',
                "waitforevent 1 $args{-line_port} DetectCongestionTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectCongestionTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectCongestionTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Congestion Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectSpecialInformationToneCAS()>

    This function is used to start the detector for special information tone. Use "stopDetectSpecialInformationToneCAS" to receive result.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -cas_timeout => 50000); 
    $obj->startDetectSpecialInformationToneCAS(%args);

=back

=cut

sub startDetectSpecialInformationToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectSpecialInformationToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectSpecialInformationTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Special Information Tone\"} # TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectSpecialInformationTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectSpecialInformationToneCAS()>

    This function detects the spaecial Information tone on the testhead within a specified timeout (milliseconds) period

    Region — Frequencies (Hz) — Cadence (Sec)
    --------------------------------------------------------
    All — 950, 1400, 1800 — Varies

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectSpecialInformationToneCAS(%args);

=back

=cut

sub stopDetectSpecialInformationToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectSpecialInformationToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectSpecialInformationTone "Null"',
                "waitforevent 1 $args{-line_port} DetectSpecialInformationTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->validateSetCmd("set DetectSpecialInformationTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectSpecialInformationTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Special Information Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectStutterDialToneCAS()>

    This function is used to start the detector for stutter dial tone. Use "stopDetectStutterDialToneCAS" to receive result.

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -tone_duration: Dial tone duration. Note: TONE_TYPE must be set to ‘1’ to enable -tone_duration parameter
      -cas_timeout: CAS timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -tone_duration => 1000, -cas_timeout => 50000); 
    $obj->startDetectStutterDialToneCAS(%args);

=back

=cut

sub startDetectStutterDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectStutterDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-cas_timeout} ||= 20000;
    $args{-tone_duration} ||= 0;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectStutterDialTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Stutter Dial Tone\"} # DIAL_TONE_DURATION = $args{-tone_duration} , TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectStutterDialTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectStutterDialToneCAS()>

    This function detect the presence of the stutter dial tone on the testhead within a specified timeout (milliseconds) period
    
    Region                  Frequencies (Hz)        Cadence (Sec)
    United States (US)      350 + 440               0.1 on, 0.1 off, 0.1 on, 0.1 off,
                                                    0.1 on, 0.1 off, 0.1 on, 0.1 off,
                                                    0.1 on, 0.1 off

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %args = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectStutterDialToneCAS(%args);

=back

=cut

sub stopDetectStutterDialToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectStutterDialToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectStutterDialTone "Null"',
                "waitforevent 1 $args{-line_port} DetectStutterDialTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->validateSetCmd("set DetectStutterDialTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectStutterDialTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Stutter Dial Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectSpecifiedToneCAS()>

    This function detects the presence of a user-specified tone on the testhead within a specified timeout (milliseconds) period.
    Note: TONE_TYPE must be set to a '1' to enable the duration parameter in setToneDetectionCAS()

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -freq1: The first of two tones to send/detect on the CAS Line
                Refer to chart below for Tone to Key mappings: Freq1 across top and Freq2 down left
                            1209 Hz	   1336 Hz    1477 Hz
                697 Hz	     1  	     2     	    3
                770 Hz	     4       	 5      	6
                852 Hz	     7      	 8       	9
                941 Hz	     *     	     0       	#
                Note that Freq1 should always be greater than Freq2
        -freq2: The second of two tones to send/detect on the CAS Line
                Refer to chart below for Tone to Key mappings: Freq1 across top and Freq2 down left
                            1209 Hz	   1336 Hz    1477 Hz
                697 Hz	     1  	     2     	    3
                770 Hz	     4       	 5      	6
                852 Hz	     7      	 8       	9
                941 Hz	     *     	     0       	#
                Note that Freq1 should always be greater than Freq2
        -tone_duration: Duration of tone in ms (Min = 25ms, max = 2000ms)
        -cas_timeout (default: 20000 ms)
        -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -freq1 => 440,
                -freq2 => 350,
                -tone_duration => 100,
                -cas_timeout => 50000, 
                -wait_for_event_time => 30
                );
    $obj->detectSpecifiedToneCAS(%input);

=back

=cut

sub detectSpecifiedToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "detectSpecifiedToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($args{-freq1} > $args{-freq2}) {
        $logger->error(__PACKAGE__ . ".$sub_name: parameter -freq1 is not greater than parameter -freq2");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-tone_duration} ||= 0;
    $args{-cas_timeout} ||= 20000;
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectTone",
                'set DetectTone "Null"',
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Tone\"} # FREQ1 = $args{-freq1}, FREQ2 = $args{-freq2}, TONE_DURATION = $args{-tone_duration}, TIMEOUT = $args{-cas_timeout}",
                "waitforevent 1 $args{-line_port} DetectTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->validateSetCmd("set DetectTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Specified Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startDetectSpecifiedToneCAS()>

    This function starts the detector for user-defined tone. Use "stopDetectSpecifiedToneCAS()" to receive result.
    Detect the presence of a user-specified tone on the testhead within a specified timeout (milliseconds) period.
    Note: TONE_TYPE must be set to a '1' to enable the duration parameter in setToneDetectionCAS()

=over 6

=item Arguments:

    Mandatory:
        -line_port: Line port
    Optional:
        -freq1: The first of two tones to send/detect on the CAS Line
                Refer to chart below for Tone to Key mappings: Freq1 across top and Freq2 down left
                            1209 Hz	   1336 Hz    1477 Hz
                697 Hz	     1  	     2     	    3
                770 Hz	     4       	 5      	6
                852 Hz	     7      	 8       	9
                941 Hz	     *     	     0       	#
                Note that Freq1 should always be greater than Freq2
        -freq2: The second of two tones to send/detect on the CAS Line
                Refer to chart below for Tone to Key mappings: Freq1 across top and Freq2 down left
                            1209 Hz	   1336 Hz    1477 Hz
                697 Hz	     1  	     2     	    3
                770 Hz	     4       	 5      	6
                852 Hz	     7      	 8       	9
                941 Hz	     *     	     0       	#
                Note that Freq1 should always be greater than Freq2
        -tone_duration: Duration of tone in ms (Min = 25ms, max = 2000ms)
        -cas_timeout (default: 20000 ms)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (
                -line_port => '17', 
                -freq1 => 440,
                -freq2 => 350,
                -tone_duration => 100,
                -cas_timeout => 50000, 
                );
    $obj->startDetectSpecifiedToneCAS(%input);

=back

=cut

sub startDetectSpecifiedToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "startDetectSpecifiedToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($args{-freq1} > $args{-freq2}) {
        $logger->error(__PACKAGE__ . ".$sub_name: parameter -freq1 is not greater than parameter -freq2");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-tone_duration} ||= 0;
    $args{-cas_timeout} ||= 20000;

    my @cmd = (
                "GetInfo 1 $args{-line_port} DetectTone",
                "maps cmd 1 UserEvent $args{-line_port} {\"Detect Tone\"} # FREQ1 = $args{-freq1}, FREQ2 = $args{-freq2}, TONE_DURATION = $args{-tone_duration}, TIMEOUT = $args{-cas_timeout}",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: start DetectTone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopDetectSpecifiedToneCAS()>

    This function detects the presence of a user-specified tone on the testhead within a specified timeout (milliseconds) period

=over 6

=item Arguments:

    Mandatory:
      -line_port: Line port
    Optional:
      -wait_for_event_time: Wait for event time (default: 30 seconds)

=item Returns:

    Returns 1 - If Passed
    Returns 0 - If Failed

=item Example:

    my %input = (-line_port => '17', -wait_for_event_time => 30); 
    $obj->stopDetectSpecifiedToneCAS(%args);

=back

=cut

sub stopDetectSpecifiedToneCAS {
    my ($self, %args) = @_;
    my $sub_name = "stopDetectSpecifiedToneCAS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    unless ($args{-line_port}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-line_port' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-wait_for_event_time} ||= 30;

    my @cmd = (
                'set DetectTone "Null"',
                "waitforevent 1 $args{-line_port} DetectTone $args{-wait_for_event_time} sec",
                );
    unless ($self->execCmdsNValidateNull(@cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: execute command in $sub_name unsuccessfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->validateSetCmd("set DetectTone")){
        $logger->error(__PACKAGE__ . ".$sub_name: command 'set DetectTone' does not return 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Detect Specified Tone line $args{-line_port} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

1;