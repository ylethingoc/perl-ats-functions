package SonusQA::GLSIP;

=head1 NAME

SonusQA::GLSIP - Perl module for GLSIP server.

=head1 AUTHOR


=head1 IMPORTANT

This module is a work in progress, it should work as described, but has not undergone extensive testing.

=head1 DESCRIPTION

This module provides functions to control the GLSIP server.

=head1 METHODS

=cut

use ATS;
use Net::Telnet ;
use SonusQA::Utils qw(:all);
use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use Module::Locate qw /locate/;
our $VERSION = '1.0';
use POSIX qw(strftime);
use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);
our $TESTSUITE;

# INITIALIZATION ROUTINES FOR CLI

=head2 SonusQA::GLSIP::doInitialization()

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
    my ($self , %args) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    my $sub = 'doInitialization' ;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{PROMPT} = '/.*[\$%\}\|\>]$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{DEFAULTTIMEOUT} = 36000;
    $self->{USER} = `id -un`;
    chomp $self->{USER};
    $logger->info("Initialization Complete");
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::GLSIP::setSystem()

  Base module over-ride. This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the GLSIP to enable a more efficient automation environment.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub setSystem {
    my($self, %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    my $sub_name = 'setSystem';
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $self->{conn}->cmd(String => "tlntadmn config timeoutactive=no", Timeout=> $self->{DEFAULTTIMEOUT}); #Disabling the Telnet session timeout
    $logger->debug(__PACKAGE__ . ".setSystem: ENTERED GLINTERGRATION TESTUSER SUCCESSFULLY");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<connectSipServer()>

    This function do:
    # open TCP session with MAPS server.
    # start Testbed.

=over 6

=item Arguments:

    Mandatory:
        -infoBag: The Client object stores all the required information to connect to the MAPS server.
        -ip: IP Address of remote MAPS server.
        -port: TCP Port of remote MAPS server, typically 10024.

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->connectSipServer(-infoBag => 'sip_server', -ip => '47.135.148.57', -port => 10024);

=back

=cut

sub connectSipServer {
    my ($self, %args) = @_;
    my $sub_name = 'connectSipServer';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-infoBag', '-ip', '-port') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->prompt('/>>>/');
    my @command = ("from glmapsSIP import *", "$args{-infoBag} = SipClient(\"$args{-ip}\", $args{-port})", "$args{-infoBag}.connect()", "$args{-infoBag}.start_testbed()", "$args{-infoBag}.load_profile_group()");
    foreach(@command) {
        if (grep /[Ee]rror/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    unless (grep /STARTED/, $self->execCmd("$args{-infoBag}.status")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> connectSipServer  -  FAILED");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<disconnectSipServer()>

    Close TCP session with MAPS server.

=over 6

=item Arguments:

    Mandatory:
        -infoBag: The Client object stores all the required information to connect to the MAPS server.

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->disconnectSipServer(sip_server)

=back

=cut

sub disconnectSipServer {
    my ($self, $infoBag) = @_;
    my $sub_name = 'disconnectSipServer';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless (grep /^0$/, $self->execCmd("$infoBag.disconnect()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't disconnect server");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setLocalVariable()>

    This function set the value of a local variable in server side script.

=over 6

=item Arguments:

    -yourCallName: Name of the call
    -variableName: Name of variable to set.
    -type: variable_type: [ '(i)' | '(s)' | '(f)' ] for int | string | float
    -value: Value to be stored by variable in script.

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->setLocalVariable(-yourCallName => 'uas', -variableName => 'SigPortNumber', -type => 'i', -value => '5');

=back

=cut

sub setLocalVariable {
    my ($self, %args) = @_;
    my $sub_name = "setLocalVariable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-yourCallName', '-variableName', '-type', '-value') {
      #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.set_local_variable(\"$args{-variableName}\", \"($args{-type})\", \"$args{-value}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set local variable");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<setGlobalVariable()>

    This function set the value of a global variable in server side script.

=over 6

=item Arguments:

    -infoBag
    -variableName: Name of variable to set.
    -type: variable_type: [ '(i)' | '(s)' | '(f)' ] for int | string | float
    -value: Value to be stored by variable in script.

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->setGlobalVariable(-infoBag => 'sip_server', -variableName => '_EnableCLI', -type => 'i', -value => '1');

=back

=cut

sub setGlobalVariable {
    my ($self, %args) = @_;
    my $sub_name = "setGlobalVariable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-variableName', '-type', '-value', '-infoBag') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$args{-infoBag}.set_global_variable(\"$args{-variableName}\", \"($args{-type})\", \"$args{-value}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set global variable");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<getCallStatus()>

    This function get call status on the MAPS server.

=over 6

=item Arguments:

    -yourCallName

=item Returns:

    Returns call status - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->getCallStatus('callNumber1');

=back

=cut

sub getCallStatus {
    my ($self, $yourCallName) = @_;
    my $sub_name = "getCallStatus";
    my @cmd_result;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    if (grep /[Ee]rror/, $self->execCmd("$yourCallName.get_call_status()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't get call status");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    sleep(1);
    if (grep /[Ee]rror/, @cmd_result = $self->execCmd("$yourCallName.status")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't get status");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[@cmd_result]");
    return @cmd_result;
}

=head2 B<startCallScript()>

    This starts a new instance of a call control script on the server 
    but does not actually start the call flow. Protocol traffic is generated by
    using the functions of the Call object returned by this method.

=over 6

=item Arguments:

    Mandatory:
        -infoBag
        -yourCallName    
        -callType: [PLACE_CALL | BIND_CALL | REGISTER]

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->startCallScript(-infoBag => "sip_server", -yourCallName => 'callNumber1', -callType => "PLACE_CALL")

=back

=cut

sub startCallScript {
    my ($self, %args) = @_;
    my $sub_name = "startCallScript";
    my @cmd_result;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-infoBag', '-yourCallName', '-callType') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }

    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: #######Start call script#######");
    if ($args{-callType} =~ /PLACE_CALL|BIND_CALL|REGISTER/) {
        if (grep /Error/, $self->execCmd("$args{-yourCallName} = $args{-infoBag}.start_call_script(\"HIGH\", \"$args{-callType}\")")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script $args{-callType}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if (grep /^0$/, $self->execCmd("$args{-yourCallName}.handle")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<stopCallScript()>

    This function terminates the script running on the MAPS server.

=over 6

=item Arguments:

    Mandatory:
        -infoBag
        -yourCallName

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->stopCallScript(-infoBag => 'sip_server', -yourCallName => 'callNumber1')

=back

=cut

sub stopCallScript {
    my ($self, %args) = @_;
    my $sub_name = "stopCallScript";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $flag = 1;
    foreach('-infoBag', '-yourCallName') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: #######Stop call script#######");                                       
    if (grep /[Ee]rror/, $self->execCmd("$args{-infoBag}.stop_call_script($args{-yourCallName})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to stop call script");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<placeCall()>

    This function place call on the MAPS server.

=over 6

=item Arguments:

    -yourCallName
    -timeout

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->placeCall(-yourCallName => 'callNumber1', -timeout => 25);

=back

=cut

sub placeCall {
    my ($self, %args) = @_;
    my $sub_name = 'placeCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-timeout') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    # my @command = ("$args{-yourCallName}.place_call()","$args{-yourCallName}.wait_for_call_connect(\"PLACE_CALL\", $args{-timeout})");
    # foreach(@command) {
    #     unless (grep /^0$/, $self->execCmd($_)) {
    #         $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
    #         $flag = 0;
    #         last;
    #     }
    # }
    my @command = ("$args{-yourCallName}.place_call()");
    foreach(@command) {
        unless (grep /^0$/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<acceptCall()>

    This function accept call on the MAPS server.

=over 6

=item Arguments:

    -yourCallName

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->acceptCall("callNumber1");

=back

=cut

sub acceptCall {
    my ($self, $yourCallName) = @_;
    my $sub_name = "acceptCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$yourCallName.answer_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't accept call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<registerCall()>

    This function instruct a REGISTER script to send a REGISTER message.

=over 6

=item Arguments:

    -yourCallName
    -routeIpAddress: dest IP address to send REGISTER message to
    -contact: Contact address of Registrant
    -addressOfRecord: AOR of Registrant
    -username: auth username
    -password: auth password
    -expiry: expiration time in seconds


=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->registerCall(-yourCallName => "callNumber1", -routeIpAddress => "192.168.153.13", -contact => '1231230001@192.168.153.112', -addressOfRecord => '1231230001@192.168.153.13', -username => "testuser3", -password => "t3st1ng", -expiry => "600");

=back

=cut

sub registerCall {
    my ($self, %args) = @_;
    my $sub_name = "registerCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1 ;
    foreach('-yourCallName', '-routeIpAddress', '-contact', '-addressOfRecord', '-username', '-password', '-expiry') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    
    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.register(\"$args{-routeIpAddress}\", \"$args{-contact}\", \"$args{-addressOfRecord}\", \"$args{-username}\", \"$args{-password}\", \"$args{-expiry}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't register call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<deregisterCall()>

    This function instruct a REGISTER script to deregister.

=over 6

=item Arguments:

    Mandatory:
        -yourCallName

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->deregisterCall("callNumber1");

=back

=cut

sub deregisterCall {
    my ($self, $yourCallName) = @_;
    my $sub_name = 'deregisterCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /^0$/, $self->execCmd("$yourCallName.deregister()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't deregister call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setSDP()>

    This function set the SDP of INVITE for UAC or 200OK for UAS.

=over 6

=item Arguments:

    Mandatory:
        -yourCallName
        -codec_list: list of codecs ordered as they will be in SDP
        -ptime: packetization time in ms (multiple of 10)

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->setSDP(-yourCallName => "callNumber1", -codecList => '["PCMU", "G729", "telephone-event"]', -ptime => '20')

=back

=cut

sub setSDP {
    my ($self, %args) = @_;
    my $sub_name = "setSDP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-codecList', '-ptime') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if (grep /[Ee]rror/, $self->execCmd("$args{-yourCallName}.set_sdp($args{-codecList}, $args{-ptime})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't set SDP");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<bindIncomingCall()>

    Used for manually instantiating a received call.

=over 6

=item Arguments:

    Mandatory:
        -yourCallName
        -request URI

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->bindIncomingCall(-yourCallName => "callNumber1", -requestURI => '1231230001@192.168.153.112')

=back

=cut

sub bindIncomingCall {
    my ($self, %args) = @_;
    my $sub_name = 'bindIncomingCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-requestURI') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.bind_incoming_call(\"$args{-requestURI}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't bind incoming call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<terminateCall()>

    This function terminate call on the MAPS server.

=over 6

=item Arguments:

    Mandatory:
        -yourCallName

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->terminateCall("callNumber1");

=back

=cut

sub terminateCall {
    my ($self, $yourCallName) = @_;
    my $sub_name = 'terminateCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$yourCallName.terminate_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
        last;  
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<getReceivedPayloads()>

    This function get the received RTP packets payload list.

=over 6

=item Arguments:

    -yourCallName

=item Returns:

    Returns payloads - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->getReceivedPayloads("callNumber1");

=back

=cut

sub getReceivedPayloads {
    my ($self, $yourCallName) = @_;
    my $sub_name = 'getReceivedPayloads';
    my @payloads;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (@payloads = $self->execCmd("$yourCallName.get_received_payloads()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't get received payloads");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    return @payloads;
}

=head2 B<detectTones()>

    This function Arm session to listen for incoming tones.

=over 6

=item Arguments:

    -yourCallName
    -frequency1
    -frequency2

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->detectTones(-yourCallName => "callNumber1", frequency1 => "500", frequency2 => "900")

=back

=cut

sub detectTones {
    my ($self, %args) = @_;
    my $sub_name = 'detectTones';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-frequency1', '-frequency2') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.detect_tones(tone_freq_1 = '$args{-frequency1}', tone_freq_2 = '$args{-frequency2}')")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't detect tones");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<sendTones()>

    This function transmit dual or single tone(s) over RTP.

=over 6

=item Arguments:

    -yourCallName
    -frequency1
    -frequency2
    -power1
    -power2
    -ontime
    -offtime
    -iterations: number of on/off cycles to iterate through

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->sendTones(-yourCallName => "callNumber1", frequency1 => "500", frequency2 => "900", -power1 => "6", -power2 => "4", -ontime => "80", -offtime => "80", -iterations => "25")

=back

=cut

sub sendTones {
    my ($self, %args) = @_;
    my $sub_name = 'sendTones';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-frequency1', '-frequency2', '-power1', '-power2', '-ontime', '-offtime', '-iterations') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.send_tones(frequency1 = $args{-frequency1}, frequency2 = $args{-frequency2}, power1 = $args{-power1}, power2 = $args{-power2}, ontime = $args{-ontime}, offtime = $args{-offtime}, iterations = $args{-iterations})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't send tones");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1; 
}

=head2 B<getDetectedTones()>

    This function get the exact freq/power detected.

=over 6

=item Arguments:

    -yourCallName

=item Returns:

    Returns results - If Succeed
        Tone 1 frequency
        Tone 2 frequency
        Tone 1 power
        Tone 2 power
    Reutrns 0 - If Failed

=item Example:

    $obj->getDetectedTones("callNumber1")

=back

=cut

sub getDetectedTones {
    my ($self, $yourCallName) = @_;
    my $sub_name = 'getDetectedTones';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($freq1, $freq2, $power1, $power2);
    if (my @result = $self->execCmd("print $yourCallName.rtp_action.get_detected_tones()")) {
        foreach (@result) {
            if ($_ =~ /^Tone1\sFreq\s\(Hz\)\s=\s(.*)/) {
                $freq1 = $1;
            }
            if ($_ =~ /^Tone2\sFreq\s\(Hz\)\s=\s(.*)/) {
                $freq2 = $1;
            }
            if ($_ =~ /^Tone1\sPower\s\(\-dB\)\s=\s(.*)/) {
                $power1 = $1;
            }
            if ($_ =~ /^Tone2\sPower\s\(\-dB\)\s=\s(.*)/) {
                $power2 = $1;
            }
        }
    }

    else {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command print getDetectedTones");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return ($freq1, $freq2, $power1, $power2);
}

=head2 B<detectDigits()>

    This function Arm session to listen for incoming digits.

=over 6

=item Arguments:
    
    Mandatory:
        digit_type: [ 'dtmf' | 'mf' ]
        digit_band: [ 'inband' | 'outband' ]
        inter_timeout: timeout duration in msec between the digits while digit detection
        total_timeout: timeout duration in msec for total digits while digit detection

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->detectDigits(-yourCallName => "callNumber1", -digitType => "dtmf", -digitBand => "inband", -interTimeout => "1000", -totalTimeout => "5000")

=back

=cut

sub detectDigits {
    my ($self, %args) = @_;
    my $sub_name = 'detectDigits';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-digitType', '-digitBand', '-interTimeout', '-totalTimeout') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless(grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.detect_digits(digit_type=\"$args{-digitType}\", digit_band=\"$args{-digitBand}\", inter_timeout=$args{-interTimeout}, total_timeout=$args{-totalTimeout})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't detect digits");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<sendDigits()>

    This function transmit DTMF/MF digits.

=over 6

=item Arguments:
    Mandatory: 
        yourCallName
        digitType
        digitBand
        digitString
        power1
        power2
        ontime
        offtime

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->sendDigits(-yourCallName => "callNumber1", -digitType => "dtmf", -digitBand => "inband", -digitString => "0123456789ABCD", -power1 => "6", -power2 => "4", -onTime => "80", -offTime => "80")

=back

=cut

sub sendDigits {
    my ($self, %args) = @_;
    my $sub_name = 'detectDigits';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-digitType', '-digitBand', '-digitString', '-power1', '-power2', '-onTime', '-offTime') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.send_digits(digit_type=\"$args{-digitType}\", digit_band=\"$args{-digitBand}\", digit_string=\"$args{-digitString}\", power1=$args{-power1}, power2=$args{-power2}, on_time=$args{-onTime}, off_time=$args{-offTime})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't send digits");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<getDetectedDigits()>

    This function get detected digit string.

=over 6

=item Arguments:

    yourCallName

=item Returns:

    Returns detectedDigits - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->getDetectedDigits("callNumber1")

=back

=cut

sub getDetectedDigits {
    my ($self, $yourCallName) = @_;
    my $sub_name = 'getDetectedDigits';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ($yourCallName) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Mandatory parameter 'yourCallName' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @detectedDigits;
    if (grep /Error/, @detectedDigits = $self->execCmd("$yourCallName.rtp_action.get_detected_digits()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command getDetectedDigits");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return @detectedDigits;
}

=head2 B<sendFile()>

    This function transmit a prerecorded voice file.

=over 6

=item Arguments:

    Mandatory: 
        yourCallName
        digitType
        digitBand
        digitString
        power1
        power2
        ontime
        offtime

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->sendFile(-yourCallName => "callNumber1", -txFileName => "voicefiles\\Send\\G711\\ULAW\\Vijay.glw", -txFileDuration => "10")

=back

=cut

sub sendFile {
    my ($self, %args) = @_;
    my $sub_name = 'sendFile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-txFileName', '-txFileDuration') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.send_file(tx_file_name=\"$args{-txFileName}\", tx_file_duration=\"$args{-txFileDuration}\"")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't send file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<receiveFile()>

    This function record incoming audio to hard disk.

=over 6

=item Arguments:
    
    Mandatory: 
        yourCallName
        rxFileName
        rxFileDuration

=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:

    $obj->sendFile(-yourCallName => "callNumber1", -rxFileName => "C:\\Program Files\\GL Communications Inc\\MAPS-SIP\\VoiceFiles\\Test.glw", -rxFileDuration => "10")

=back

=cut

sub receiveFile {
    my ($self, %args) = @_;
    my $sub_name = 'receiveFile';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-rxFileName', '-rxFileDuration') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /^0$/, $self->execCmd("$args{-yourCallName}.rtp_action.receive_file(rx_file_name=\"$args{-rxFileName}\", rx_file_duration=$args{-rxFileDuration})")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't receive file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<twoWayAudioRTP()>

    This function let user choose between 3 options:
        tone
        digit
        file

=over 6

=item Arguments:
    
    Mandatory:
        yourCallName
        if user chooose tone:
            choice: tone
            freq1
            freq2
            power1
            power2
            ontime
            offtime
            interations
        if user choose digit:
            choice: digit
            digitType
            digitBand
            interTimeout
            totalTimeout
            digitString
            power1
            power2
            ontime
            offtime
        if user choose file:
            choice: file
            txFileName
            txFileDuration


=item Returns:

    Returns 1 - If Succeed
    Reutrns 0 - If Failed

=item Example:
    
    tone:
        $obj->twoWayAudioRTP(-yourCallName => "callNumber1", -choice => "tone", -input => {-freq1 => "500", -freq2 => "1000", -power1 => "5", -power2 => "10", -ontime => "5000", -offtime => "10000", -interations => "1234"})
    digit:
        $obj->twoWayAudioRTP(-yourCallName => "callNumber1", -choice => "digit", -input => {-digitType => "500", -digitBand => "1000", -interTimeout => "5", -totalTimeout => "10", -digitString => "abcdEF123", -power1 => "1234", -power2 => "123125", -onTime => "12", -offTime => "1222"})
    file:
        $obj->twoWayAudioRTP(-yourCallName => "callNumber1", -choice => "file", -input => {-txFileName => "voicefiles\\Send\\G711\\ULAW\\Vijay.glw", -txFileDuration => "10"})

=back

=cut

sub twoWayAudioRTP {
    my ($self, %args) = @_;
    my $sub_name = 'twoWayAudioRTP';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-yourCallName', '-input', '-choice') {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ($args{-choice} =~ /tone/) {
        unless ($self->detectTones(-yourCallName => "$args{-yourCallName}", -frequency1 => "$args{-input}{-freq1}", -frequency2 => "$args{-input}{-freq2}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command detect tones");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless ($self->sendTones(-yourCallName => "$args{-yourCallName}", -frequency1 => "$args{-input}{-freq1}", -power1 => "$args{-input}{-power1}", -frequency2 => "$args{-input}{-freq2}", -power2 => "$args{-input}{-power2}", -ontime => "$args{-input}{-ontime}", -offtime => "$args{-input}{-offtime}", -interations => "$args{-input}{-iterations}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command send tones");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless ($self->getDetectedTones($args{-yourCallName})) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command get detected tones");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;            
        }
    }
    elsif ($args{-choice} =~ /digit/) {
        unless ($self->detectDigits(-yourCallName => "$args{-yourCallName}", -digitType => "$args{-input}{-digitType}", -digitBand => "$args{-input}{-digitBand}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command detect digits");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless ($self->sendDigits(-yourCallName => "$args{-yourCallName}", -digitString => "$args{-input}{-digitString}", -digitBand => "$args{-input}{-digitBand}", -power1 => "$args{-input}{-power1}", -power2 => "$args{-input}{-power2}", -onTime => "$args{-input}{-ontime}", -offTime => "$args{-input}{-offtime}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command send digits");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless ($self->getDetectedDigits($args{-yourCallName})) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command get detected digits");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;            
        }
    }
    elsif ($args{-choice} =~ /file/) {
        unless ($self->sendFile(-yourCallName => "$args{-yourCallName}", -txFileName => "$args{-input}{-txFileName}", -txFileDuration => "$args{-input}{-txFileDuration}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command send file");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless ($self->receiveFile(-yourCallName => "$args{-yourCallName}", -txFileName => "$args{-input}{-txFileName}", -txFileDuration => "$args{-input}{-txFileDuration}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't excecute command receive file");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }         
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Unknowed choice");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    return 1;
}

=head2 C<execCmd()>

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
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
    my(@cmdResults,$timestamp);
    $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub");
    if (!(defined $timeout)) {
        $timeout = $self->{DEFAULTTIMEOUT};
        $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
    }
    else {
        $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
    }
    $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
        $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
        $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
        $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub[0]");
        return 0;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
    return @cmdResults;
}

1;