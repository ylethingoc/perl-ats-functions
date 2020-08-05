package SonusQA::GLISUP;

=head1 NAME

SonusQA::GLISUP - Perl module for GLISUP server.

=head1 AUTHOR


=head1 IMPORTANT

This module is a work in progress, it should work as described, but has not undergone extensive testing.

=head1 DESCRIPTION

This module provides functions to control the GL ISUP server.

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

=head2 SonusQA::GLISUP::doInitialization()

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
    # $self->{USER} = `id -un`;
    # chomp $self->{USER};
    $logger->info("Initialization Complete");
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::GLISUP::setSystem()

  Base module over-ride. This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the GL ISUP to enable a more efficient automation environment.

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

=head2 B<connectIsupServer()>

    This function do:
    # open TCP session with MAPS server.
    # start Testbed.

=over 6

=item Arguments:

     Mandatory:
            -ip
            -port
            -testbedProfile
            -enableTraffic
=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->connectIsupServer(-ip => '47.133.190.59', -port => 10024, -testbedProfile => 'Protocol_IWK_AC.xml', -enableTraffic => 1);

=back

=cut

sub connectIsupServer {
    my ($self, %args) = @_;
    my $sub_name = 'connectIsupServer';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $self->{conn}->prompt('/>>>/');
    # Set up server session
    my $flag = 1;
    foreach('-ip', '-port', '-testbedProfile'){                                                        #Checking for the parameters in the input hash
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @command = ('from glmaps import *','import time','local_server = IsupClient(\"$args{-ip}\", $args{-port}, \"$args{-testbedProfile}\")');
    foreach(@command){
        unless ($self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @command = ('local_server.connect()','local_server.start_testbed()','local_server.load_profile_group(\"$args{-testbedProfile}\")','local_server.server_health_status_request($args{-enableTraffic})');
    foreach(@command){
        unless (grep /^0$/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    # Enable CLI
    unless ($self->setGlobalVariable(-variableName => '_EnableCLI', -type => 'i', -value => '1')) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't enable CLI");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /STARTED/, $self->execCmd("local_server.status")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> connectIsupServer  -  FAILED");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<disconnectIsupServer()>

    Close TCP session with MAPS server.

=over 6

=item Arguments:

     Mandatory:
            None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->disconnectIsupServer()

=back

=cut

sub disconnectIsupServer {
    my ($self) = @_;
    my $sub_name = 'disconnectIsupServer';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless (grep /^0$/, $self->execCmd("local_server.disconnect()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't disconnect server");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startCallScript()>

    This starts a new instance of a call control script on the server 
    but does not actually start the call flow. Protocol traffic is generated by
    using the functions of the Call object returned by this method.

=over 6

=item Arguments:

     Mandatory:
            
            -callName
            -profile

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->startCallScript(-callName => 'uac', -profile => 'Card8TS31')

=back

=cut

sub startCallScript {
    my ($self, %args) = @_;
    my $sub_name = "startCallScript";
    my @cmd_result;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #Checking for the parameters in the input hash
    my $flag = 1;
    foreach('-callName', '-profile'){                                                        #Checking for the parameters in the input hash
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: #######Start call script#######");
    if ($args{-callName} =~ /uac/) {                                            
        if (grep /Error/, $self->execCmd("callName = local_server.start_call_script\(\"HIGH\", \"PLACE_CALL\", \"$args{-profile}\"\)")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script uac");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    elsif ($args{-callName} =~ /uas/) {
        if (grep /Error/, $self->execCmd("callName = local_server.start_call_script\(\"HIGH\", \"BIND_INCOMING_CALL\", \"$args{-profile}\"\)")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script uas");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if (grep /^0$/, $self->execCmd("callName.handle")) {
      $logger->error(__PACKAGE__ . ".$sub_name: Failed to start call script");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<setLocalVariable()>

    This function set the value of a local variable in server side script.

=over 6

=item Arguments:

    -variableName: Name of variable to set.
    -type: variable_type: [ '(i)' | '(s)' | '(f)' ] for int | string | float
    -value: Value to be stored by variable in script.

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->setLocalVariable(-variableName => 'SigPortNumber', -type => 'i', -value => '5');

=back

=cut

sub setLocalVariable {
    my ($self, %args) = @_;
    my $sub_name = "setLocalVariable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-variableName','-type', '-value') {
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
    unless (grep /^0$/, $self->execCmd("callName.set_local_variable(\"$args{-variableName}\", \"($args{-type})\", \"$args{-value}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set local variable");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
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

            None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->stopCallScript()

=back

=cut

sub stopCallScript {
    my ($self) = @_;
    my $sub_name = "stopCallScript";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: #######Stop call script#######");                                       
    unless (grep /^0$/, $self->execCmd("local_server.stop_call_script(callName)")) {
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

    Timeout

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->placeCall(25);  # timeout will be 25s

=back

=cut

sub placeCall {
    my ($self, $timeout) = @_;
    my $sub_name = 'placeCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    
    my @command = ('callName.place_call()','callName.wait_for_call_connect(\"PLACE_CALL\", $timeout)');
    foreach(@command){
        unless (grep /^0$/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't execute cmd $_");
            $flag = 0;
            last;
        }
    }
    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /ISUP CALL CONNECTED/, $self->getCallStatus()) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't connect call");
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

    None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->acceptCall();

=back

=cut

sub acceptCall {
    my ($self) = @_;
    my $sub_name = "acceptCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    unless (grep /^0$/, $self->execCmd("callName.answer_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't accept call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /ISUP CALL CONNECTED/, $self->getCallStatus()) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't connect call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<terminateCall()>

    This function terminate call on the MAPS server.

=over 6

=item Arguments:

    None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->terminateCall();

=back

=cut

sub terminateCall {
    my ($self) = @_;
    my $sub_name = 'terminateCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    # Terminate
    unless (grep /^0$/, $self->execCmd("callName.terminate_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't terminate call");
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
        called number

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

    $obj->bindIncomingCall('9876543123456') #called number will be 9876543123456

=back

=cut

sub bindIncomingCall {
    my ($self, $bindnumber) = @_;
    my $sub_name = 'bindIncomingCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #Checking for the parameters in the input
    unless ($bindnumber) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $bindnumber not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /^0$/, $self->execCmd("callName.bind_incoming_call\(\"$bindnumber\"\)")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't bind incoming call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<waitForCallConnect()>

    Wait for incomming INVITE message in particular time.

=over 6

=item Arguments:

     Mandatory:
        timeout

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

    $obj->waitForCallConnect('10') #timeout will be 10 seconds

=back

=cut

sub waitForCallConnect {
    my ($self, $timeout) = @_;
    my $sub_name = 'waitForCallConnect';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless (grep /^0$/, $self->execCmd("callName.wait_for_call_connect\(\"BIND_INCOMING_CALL\", $timeout\)")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't wait for call connect");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;

}

=head2 B<suspendCall()>

    This function suspend call on the MAPS server.

=over 6

=item Arguments:

    None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->suspendCall();

=back

=cut

sub suspendCall {
    my ($self) = @_;
    my $sub_name = 'suspendCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    # Terminate
    unless (grep /^0$/, $self->execCmd("callName.suspend_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't suspend call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<resumeCall()>

    This function resume call on the MAPS server.

=over 6

=item Arguments:

    None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->resumeCall();

=back

=cut

sub resumeCall {
    my ($self) = @_;
    my $sub_name = 'resumeCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    # Terminate
    unless (grep /^0$/, $self->execCmd("callName.resume_call()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't resume call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<getCallStatus()>

    This function get call status on the MAPS server.

=over 6

=item Arguments:

    None

=item Returns:

      Returns call status - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->getCallStatus();

=back

=cut

sub getCallStatus {
    my ($self) = @_;
    my $sub_name = "getCallStatus";
    my $cmd_result;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    if (grep /Error/, $self->execCmd("callName.get_call_status()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't get call status");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    sleep(1);
    if (grep /Error/, ($cmd_result) = $self->execCmd("callName.status")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Couldn't get status");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[$cmd_result]");
    return $cmd_result;
}

=head2 B<getTransportStatus()>

    This function get transport status on the MAPS server.

=over 6

=item Arguments:

    None

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->getTransportStatus();

=back

=cut 

sub getTransportStatus {
    my ($self) = @_;
    my $sub_name = 'getTransportStatus';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless (grep /^0$/, $self->execCmd("callName.is_transport_up()")) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Transport down");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;   
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setGlobalVariable()>

    This function set the value of a global variable in server side script.

=over 6

=item Arguments:

    -variableName: Name of variable to set.
    -type: variable_type: [ '(i)' | '(s)' | '(f)' ] for int | string | float
    -value: Value to be stored by variable in script.

=item Returns:

      Returns 1 - If Succeed
      Reutrns 0 - If Failed

=item Example:

      $obj->setGlobalVariable(-variableName => '_EnableCLI', -type => 'i', -value => '1');

=back

=cut

sub setGlobalVariable {
    my ($self, %args) = @_;
    my $sub_name = "setGlobalVariable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-variableName','-type','-value') {
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
    unless (grep /^0$/, $self->execCmd("local_server.set_global_variable(\"$args{-variableName}\", \"\($args{-type}\)\", \"$args{-value}\")")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set global variable");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
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