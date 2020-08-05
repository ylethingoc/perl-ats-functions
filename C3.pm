package SonusQA::C3;

=head1 NAME

 SonusQA::C3 - Perl module for C3

=head1 AUTHOR

 Vishwas Gururaja - vgururaja@rbbn.com

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::C3->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate

=head1 DESCRIPTION

 This module provides an interface to telnet to MSC and PAC cards and execute basic commands on them.

=head1 METHODS

=cut

use strict;
use warnings;
use Storable;
use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;
use Data::Dumper;

our $VERSION = "1.0";
our @ISA = qw(SonusQA::Base);

=head2 B<doInitialization()>

=over 6

=item DESCRIPTION:

 Routine to set object defaults and session prompt.

=item Arguments:

 Object Reference

=item Returns:

 None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{STORE_LOGS} = 2;
    $self->{'LOG_PATH'} = '/space/Santera';
    $self->{LOCATION} = locate __PACKAGE__ ;
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<setSystem()>

    This function sets the system information and Prompt.

=over 6

=item Arguments:

        Object Reference

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=back

=cut

sub setSystem{
    my ($self) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    $self->{conn}->cmd("bash");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub_name  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    unless ($self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<doTelnet()>

    This function takes a hash containing the IP, port, user and password and opens a telnet connection.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        user
        password
 Optional:
        port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-ip => '10.250.14.10', -user => 'root', -password => 'root');
        $obj->doTelnet(%args);

=back

=cut

sub doTelnet{
    my ($self, %args) = @_;
    my $sub_name = "doTelnet";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-ip', '-user', '-password'){                                                        #Checking for the parameters in the input hash
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to telnet to $args{-ip} with user $args{-user} and password $args{-password}");
    unless($self->{conn}->print("telnet $args{-ip} $args{-port}")){                              #telnet to the host
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not telnet to $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->waitfor(-match => '/Login\:\s*/')){                                    #waiting for login and password prompts and entering the inputs
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Login prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print($args{-user})){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter username");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->waitfor(-match => '/Password\:\s*/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Password prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print($args{-password})){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter password");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    my $prev_prompt = $self->{conn}->prompt('/>/');                                       #Changing the prompt to System.+> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to />/");
    $self->{conn}->waitfor(-match => '/>/');
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Telnet successful"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
    
}

=head2 B<doSSH()>

    This function takes a hash contining the IP, port, user and password and opens a ssh connection by ssh user@ip.

=over 6

=item Arguments:

     Mandatory:
            Object Reference
            ip
            user
            password
     Optional:
            port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-ip => '10.250.14.10', -user => 'root', -password => 'root');
        $obj->doSSH(%args);

=back

=cut

sub doSSH{
    my ($self, %args) = @_;
    my $sub_name = "doSSH";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    my $cmd_ssh = "ssh ".$args{-user}."@".$args{-ip};
    foreach('-ip', '-user', '-password'){                                                                 #Checking for the parameters in the input hash
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to ssh to $args{-ip} with user $args{-user} and password $args{-password}");
    unless($self->{conn}->print($cmd_ssh)){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter username");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->waitfor(-match => '/assword\:/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get password prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print($args{-password})){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter password");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }  
    my $prev_prompt = $self->{conn}->prompt('/>/');                                       #Changing the prompt to System.+> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to />/");
    $self->{conn}->waitfor(-match => '/>/');
    $logger->debug(__PACKAGE__ . ".$sub_name: SSH successful");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<dis_appmgr_all()>

    This function is used to check/login to the active MSC,and get all AppMgrs information using CLI command dis_appmgr_all.
    
    Step: - Login to MSC1, check active state using command dis_appmgr_all
                if (active) => return session and list of AppMgr
                else: login to MSC2 => check Active state and return List of AppMgr

=over 6

=item Arguments:

     Mandatory:
            -tms_alias => TMS alias Name (Info MSC1) 
            -tms_alias => TMS alias Name (Info MSC2)
        
=item Returns:

        Returns 2 variables:
            1: session C3
            2: List of AppMgrs

=item Example:

        ($ses_c3, @cmd_result) = SonusQA::C3::dis_appmgr_all(-value_MSC1 => $TESTBED{"c3:1:ce0"}, -value_MSC2 => $TESTBED{"c3:2:ce0"}))

=back

=cut

sub dis_appmgr_all {
    my ( %args) = @_;
    my ($ses_C3, $value_MSC1, $value_MSC2, @cmd_result); 
    my $sub_name = "dis_appmgr_all";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    # connect to MSC1 to check state standby/active
    my $flag = 0;
    foreach my $msc_value ($args{-value_MSC1},  $args{-value_MSC2}) {
        unless ($ses_C3 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $msc_value)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to MSC ");
            last;
        }
        @cmd_result = $ses_C3->execCmd("dis_appmgr_all");
        if (grep /OamFault is STANDBY|Error getting SM pointer/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- This is Standby node. Please login in other node");
            $ses_C3->DESTROY; # destroy session that connect to MSC1  
        } else {
            # Transform to return AppMgrList vector
            my $str_result = join('', @cmd_result);
            my @separated = split(/-\s\s*/, $str_result);
            $str_result = $separated[1];
            $str_result =~ s/RESET\s/RESET\r\n/g;
            @cmd_result = split(/\r\n/, $str_result); # vector appMgrList   
            $flag = 1;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return ($ses_C3, @cmd_result);
}

=head2 B<getActiveNode()>

    This function is used to check/login to the active Node using CLI command telnet 0 9999.
    
    Step: - Login to MSC1, check active state using command telnet 0 9999 -> 12
                if (active) => return session
                else: login to MSC2 => check Active state

=over 3

=item Arguments:

    Mandatory:
        -value_MSC1 : <Info MSC1> 
        -value_MSC2 : <Info MSC2>
    Optional:
        - sessionLog => 'File name'

=item Returns:

        Returns 3 variables:
            1: session C3
            3: active_MSC_value 

=item Example:

        ($ses_c3, $active_MSC_value) = SonusQA::C3::getActiveNode(-value_MSC1 => $TESTBED{"c3:1:ce0"}, -value_MSC2 => $TESTBED{"c3:2:ce0"}, -sessionLog => 'FileName'))

=back

=cut

sub getActiveNode {
    my ( %args) = @_;
    my ($ses_C3, $active_MSC_value); 
    my $sub_name = "getActiveNode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $prev_prompt;
    my $flag = 0;
    foreach my $msc_value ($args{-value_MSC1}, $args{-value_MSC2}) {
        unless ($ses_C3 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $msc_value, -sessionLog => $args{-sessionLog})) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to MSC - $msc_value ");
            next;
        }
        $prev_prompt = $ses_C3->{conn}->prompt('/>/');
        $ses_C3->execCmd("telnet 0 9999");
        if (grep /^server status: In Service Active/, $ses_C3->execCmd("12")) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- This is Active node.");
            $active_MSC_value = $msc_value;
            $ses_C3->{conn}->print("exit");
            $flag = 1;
            last;
        }
    }
    if ($flag == 0) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot find the Node active ");
        return 0;
    }
    $prev_prompt = $ses_C3->{conn}->prompt('/.*[\$%#\}\|\>\]].*$/');
    $ses_C3->{conn}->waitfor(-match => $prev_prompt);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return ( $ses_C3,$active_MSC_value); # return msc active, sesstion
}

=output of the command
    <function> <getActiveNode>
    
        santera@tampamsc1% telnet 0 9999
        Trying 0.0.0.0...
        Connected to 0.
        Escape character is '^]'.
        > 12
        server version: Release 21.00.00.13 build 21.00.00.13.20180818
        server status: In Service Active ===> Active node
        Peer server: tampamsc2
        peer server status: In Service Standby
        > 
        
=cut

=head2 B<checkCoreDump()>

   This function is to check if core dump occurs or not in C3.

=over 6

=item Argument:

        Object Reference

=item Returns:

        Returns list core dump
        
=item Example:

        $obj->checkCoreDump();
        
=back

=cut

sub checkCoreDump {
    my ($self) = @_;
    my $sub_name = "checkCoreDump";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@cmd_result, @total);
 
    $self->execCmd("cd /stats/core");     # cd to path /stats/core                                                                         
    @cmd_result= $self->execCmd("ls -lrt /stats/core");     # run command ls -lrt /stats/core
    # Transform list core dump
    foreach my $i (0 .. $#cmd_result) {                                                                            
        if ($cmd_result[$i] =~ /total/) {
            @total = split(/total/, $cmd_result[$i]);
            $total[1] =~ s/^\s+|\s+$//g;
            if ($total[1] == 0) {
                @cmd_result = (0);
            } else {
                splice (@cmd_result, $i, 1) ; # remove line that contain "total"
            }
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name cmd_result : ". Dumper(\@cmd_result));
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub");
    return @cmd_result;  #return array of elements
}

=head2 B<telnetConsole()>

    This function takes a hash containing the IP, port, account and opens a telnet connection
	And: set event=off, alarm=off; prompt=off

=over 6

=item Arguments:

     Mandatory:
            Object Reference
            ip
            account <array>
     Optional:
            port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:	

        my %args = (-ip => '10.250.14.10',-port => 5400, -account => ['user1', 'passwd1', 'user2', 'passwd2']);
        
=back

=cut

sub telnetConsole() {
    my ($self, %args) = @_;
    my $sub_name = "telnetConsole";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-ip', '-account') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }         
    unless ($self->{conn}->print("telnet $args{-ip} $args{-port}")) {                            #telnet to the host
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not telnet to $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->{conn}->waitfor(-match => '/Login\:\s*/')) {                                    #waiting for login and password prompts and entering the inputs
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Login prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $result = 1;
    my $length = scalar (@{$args{-account}}) - 1; 
    for (my $i = 0; $i <= $#{$args{-account}}; $i = $i+2 ) {
        $logger->debug(__PACKAGE__ . "enter username: $args{-account}[$i]");# enter username
        $self->{conn}->print($args{-account}[$i]);
        unless ($self->{conn}->waitfor(-match => '/Password/')) {                                 #waiting for login and password prompts and entering the inputs
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Password prompt");
            $result = 0;
            last;
        }
        $self->{conn}->print($args{-account}[$i+1]);        # enter password
        $logger->debug(__PACKAGE__ . "enter password: $args{-account}[$i+1]");
        
        if ($self->{conn}->waitfor(-match => '/Maximum Number/', -timeout => 3)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Maximum Number of Attempts reached. Logged out User ");
            $result = 0;
            last;
        } elsif ($self->{conn}->waitfor(-match => '/User is already in session/', -timeout => 3)) {
            if (($length - ($i + 1)) == 0) {
                $logger->error(__PACKAGE__ . ".$sub_name: User is already in session. ");
                $result = 0;
            } else {
                $logger->debug(__PACKAGE__ . ".$sub_name: User is already in session. Please try with other user");
            }
        }  elsif ($self->{conn}->waitfor(-match => '/Invalid user name or password/', -timeout => 3)) {
            if (($length - ($i + 1)) == 0) {
                $logger->error(__PACKAGE__ . ".$sub_name: Invalid username or password. ");
                $result = 0;
            } else {
                $logger->debug(__PACKAGE__ . ".$sub_name: Invalid username or password. Please try with other user");
            }
        } elsif ($self->{conn}->waitfor(-match => '/System/')) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Telnet successful");       
            unless ($self->{conn}->cmd(-string => "set event=off", -prompt => '/Command Completed/')) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to set event = off parameters");
                $result = 0;
                last;
            }
            unless ($self->{conn}->cmd(-string => "set prompt=off", -prompt => '/Command Completed/')) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to set prompt=off parameters");
                $result = 0;
                last;
            }
            unless ($self->{conn}->cmd(-string => "set alarm=off", -prompt => '/.*\>/')) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to set alarm =off parameters");
                $result = 0;
                last;
            }
            my $prev_prompt = $self->{conn}->prompt('/>/');                                  #Changing the prompt to System.+> to match this so as to run further commands
            $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to />/");
            $self->{conn}->waitfor(-match => '/>/');
            last;
            
         } else {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot telnet CLI ");
            $result = 0;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]"); 
    return $result;
}

=head2 B<addVoIP()>

    This function is to add new VOIP and its sub VOIP trunk group

=over 

=item Arguments:

     Mandatory:
            Object Reference
            path
            cmdAddVoIP
            cmdAddSubVoIP
            GrpID
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->addVoIP(-path => '/Nodes/MG-Nodes/1-G9MGNODE/VoIP', -cmdAddVoIP => 'ADD VOIPTRUNKGROUP trunkGroupId=1205', -cmdAddSubVoIP => 'ADD VOIPMGSUBTRUNKGROUP chans=10, ipAddress=172.20.47.197', -GrpID => '1205');

=back

=cut

sub addVoIP{
    my ($self, %args) = @_;
    my $sub_name = "addVoIP";
    my $trkGroupId;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-path', '-cmdAddVoIP','-cmdAddSubVoIP') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($trkGroupId) = $args{-cmdAddVoIP} =~ /trunkGroupId\=(\d\d*)/;
    $trkGroupId = $trkGroupId."-VOIPTRUNKGROUP";
    unless ($self->runCmd(-path => $args{-path}, -cmd => [$args{-cmdAddVoIP}])) {                                             #run command add VoIP
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add VoIP with command $args{-cmdAddVoIP}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("unlock $trkGroupId")) {                                                                                                   #run command unlock
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to unlock $trkGroupId");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->runCmd(-path => $trkGroupId, -cmd => [$args{-cmdAddSubVoIP}])) {                                                  #run command add sub VoIP
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add sub VoIP with command: $args{-cmdAddSubVoIP}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("unlock 1-VOIPMGSUBTRUNKGROUP")) {                                                                                                   #run command unlock
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to unlock 1-VOIPMGSUBTRUNKGROUP");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<getLaescaseId()>

    This function is used to execute command add Laescase4  using CLI in C3 and then return LaescaseC4 Id

=over 3

=item Arguments:

 Mandatory:

        - command to add Laescasec4

=item Returns:

        Returns LaescaseC4 Id

=item Example:
        $cmd = "add LAESCASEC4 rmtMontAgency=1,profileId=1,routeListInd=1,routeTo=135,agencyEarDN=0123456789,agencyMouthDN=0987654321,caseName=Auto1,agency=Auto2,caseId=Auto3,restriction=0,monitoringType=2,trunkGrp=503,endTrunkGrp=504,deliveryType=0,cdcProtocol=1,tcpConnectId=253,startTime=\"2018-07-10 00:00:00\",endTime=\"2020-01-01 00:00:00\"";
        $obj->getLaescaseId($cmd);

=back

=cut

sub getLaescaseId {
    my ($self, $cmd) = @_;
    my $sub_name = "getLaescaseId";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    #Checking for the parameters in the input hash
    unless ($cmd) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter not present. Please put cmd to add LAESCASEC4 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd /Trunk-Options/Lawful-Intercept")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to '/Trunk-Options/Lawful-Intercept' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my (@cmd_result, $laescaseId);

    @cmd_result = $self->execCmd($cmd);
    if (grep /Command Completed/, @cmd_result) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Execute command : $cmd successfully");
        #Added Lawful Intercept Case : Auto1-1-LAESCASEC4 Successfully.
        foreach (@cmd_result) {
            if ($_ =~ /Added Lawful Intercept Case\s*\:\s*(.+)\s*Successfully/) {
                $laescaseId = $1;
                $logger->debug(__PACKAGE__ . ".$sub_name: LaescaseC4 ID: $laescaseId");
                last;
            }
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0] ");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$laescaseId] ");
    return $laescaseId;
}

=head2 B<getTrunkInfo()>

    This function is used to get  values (adminState, inServiceTrunks, outOfServiceTrunks) of trunkGroupId (isup, sip-dal or sip-trunk)
=over

=item Arguments:

 Mandatory:
        - filePath : path to save the result file
        - path: path to trunk group
 Optional:
        - trunkGroupId: if not defined, default query all trunk groups in the path
  
=item Returns:

        Output: a array is list of optionValue.

=item Example:

        $obj->getTrunkInfo(-filePath => '', -path => '/Groups/ISUP/Groups'); => check all trunk 
     or $obj->getTrunkInfo(-filePath => '', -path => '/Groups/ISUP/Groups', -trunkGroupId => ['51-ISUPGROUP']); => check trunk 51-ISUPGROUP

=back

=cut

sub getTrunkInfo {
    my ($self, %args) = @_;
    my $sub_name = "getTrunkInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    my (@vector_list, @cmd_result, %hashResult);                                                                                                  
    my ($adminStateValue, $inServiceTrunkValue, $outOfServiceTrunkValue);
    my $flag = 1;
    foreach ('-path', '-filePath') {#Checking for parameters in the input hash
        unless ($args{$_}) {     
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                        # changing directory to the specified one
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($args{-trunkGroupId}) {
        @vector_list = $self->listElements(-path => $args{-path});
    } else {
        @vector_list = @{$args{-trunkGroupId}};
    }
    $logger->debug(__PACKAGE__. ".$sub_name: Changing the prompt to /Completed/");
    my $prev_prompt = $self->{conn}->prompt('/Completed/');
    foreach my $i (0 .. $#vector_list) {
        my $hashTmp;
        @cmd_result = $self->execCmd("query $vector_list[$i]");
        if (grep /Command Not/, @cmd_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute cmd: query $vector_list[$i] ");
            last;
        }
        foreach my $j (0 .. $#cmd_result) {   
            if ($cmd_result[$j] =~ /adminState/) {
                ($adminStateValue) = $cmd_result[$j] =~ /\].......\w\w*\s\-\>\s(\d\d*)/; 
                $hashTmp->{adminState} = $adminStateValue;
            }
            if ($cmd_result[$j] =~ /inServiceTrunks/) {
                ($inServiceTrunkValue) = $cmd_result[$j] =~ /\].......(\d\d*)/; 
                $hashTmp->{inServiceTrunks} = $inServiceTrunkValue;
            }
            if ($cmd_result[$j] =~ /outOfServiceTrunks/) {
                ($outOfServiceTrunkValue) = $cmd_result[$j] =~ /].......(\d\d*)/; 
                $hashTmp->{outOfServiceTrunks} = $outOfServiceTrunkValue;
            }
        }
        $hashResult{$vector_list[$i]} = $hashTmp;
    }
  
    $logger->debug(__PACKAGE__. ".$sub_name: Changing the prompt back to />/");
    $prev_prompt = $self->{conn}->prompt('/>/');
    $self->{conn}->waitfor(-match => '/>/');
    $logger->debug(__PACKAGE__. ".$sub_name:  Hash result: ".Dumper(\%hashResult));
    store \%hashResult, $args{-filePath};
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub ");
    return %hashResult;
}

=head2 B<listElements()>

    This function is used to list all elements of an input path using CLI in C3.

=over 

=item Arguments:

     Mandatory:
            Object Reference
            path
            
=item Returns:

        Output of the command executed.

=item Example:

        $obj->listElements(-path => '/Nodes/MG-Nodes/1-G9MGNODE/VoIP');

=back

=cut

sub listElements {
    my ($self, %args) = @_;
    my $sub_name = "listElements";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@cmd_result,@list_result);
    
    #Checking for the parameters in the input hash
    unless ($args{-path}) {                                                                                                      
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-path' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    # changing directory to the specified one
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                                   
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @cmd_result= $self->execCmd("list"); #run command list
    for (my $i=0; $i < $#cmd_result; $i++) {
        unless (($cmd_result[$i] eq "")||($cmd_result[$i] =~ m/Command Completed/)) {                                                                                         
            push @list_result, $cmd_result[$i]; #push elements into array
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name cmd_result : ". Dumper(\@list_result));
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub");
    return @list_result;
}

=output of the command 
    <function> <listElements>
    cd /Nodes/MG-Nodes/1-G9MGNODE/VoIP

    Command Completed

    >list
    1-VOIPCODECRTPTIMEOUT
    1-VOIPPROFILE
    1-VOIPTRUNKGROUP
    2-VOIPTRUNKGROUP
    3-VOIPTRUNKGROUP

    Command Completed
    => @list_result = ['1-VOIPCODECRTPTIMEOUT', '1-VOIPPROFILE', '1-VOIPTRUNKGROUP', '2-VOIPTRUNKGROUP', '3-VOIPTRUNKGROUP']
=cut
=head2 B<filterList()>

    This function is used to filter from an input list which one has option name equals to option value. It can be used to find active PACCARD  slot

=over 

=item Arguments:

 Mandatory:
        Object Reference
        path
        inputList: <array>
        optionName: option name in query command
        optionValue: value of the option
=item Returns:
        Output filtered  list
=item Example:

        $obj->filterList(-path => '/Nodes/MG-Nodes/1-G9MGNODE/Slots', -inputList=> [@PACCARD_Slots], -optionName => 'standbyState', -optionValue => 'Active');
        => check active PACCARD depend on '-optionName' contain '-optionValue'
        => output: return active PACCARD_Slot
=back
=cut

sub filterList {
    my ($self, %args) = @_;
    my $sub_name = "filterList";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my (@query_result, @filteredList_result, @tmp, $optionName, $optionValue);
    $optionName = $args{-optionName};
    $optionValue = $args{-optionValue};
    my $flag = 1;
    foreach ('-path', '-inputList', '-optionName', '-optionValue') {                                                        #Checking for the parameters in the input hash
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to /Completed/");
    my $prev_prompt = $self->{conn}->prompt('/Completed/');
    
    my $result = 1;
    foreach my $i (0 .. $#{$args{-inputList}}) {
        if (grep /Command Not/, @query_result = $self->execCmd("query $args{-inputList}[$i] ")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute cmd: query $args{-inputList}[$i] ");
            $result = 0;
            last;
        }
        # transform to compare with optionValue
        foreach (@query_result) {
            if ($_ =~ m/$optionName/) {
                @tmp = split($optionName,$_);
                @tmp = split('].......',$tmp[1]);
                if ($tmp[1] =~ m/$optionValue/) {
                    push(@filteredList_result, $args{-inputList}[$i]);
                }
            }
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt back to />/");
    $prev_prompt = $self->{conn}->prompt('/>/');
    $self->{conn}->waitfor(-match => '/>/');
    $logger->debug(__PACKAGE__ . ".$sub_name filteredList_result : ". Dumper(\@filteredList_result));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub ");
    return @filteredList_result;
}

=output of command
    <function> <filterList>
    cd /Nodes/MG-Nodes/1-G9MGNODE/Slots
    Command Completed
    >query 7-1-PACKETANDCONTROLCARD
     PACKETANDCONTROLCARD:-
    Identification:
    mgNode  [MG Node].......1
    slot  [Slot].......7
    card  [Card].......1
    type  [Type].......Packet/Control Card -> 64
    actualType  [Actual Type].......Undefined -> 65535
    Status:
    adminState  [Admin State].......Unlocked -> 2
    operState  [Operating State].......Unknown -> 0
    Protection:
    group  [Group].......20
    Mfg. Info:
    functVer  [Functional Ver].......
    partNum  [Part Number].......8050080142
    serialNum  [Serial Number].......11350512
    hardwareRevision  [Hardware Revision].......0C
    cleiCode  [CLEI Code].......nocleicode
    manufacturedDate  [Manufacture Date].......Sep 1, 2011
    Secondary Status:
    availState  [Availability Status].......Unknown -> 999
    alarmState  [Alarm Status].......Unknown -> 999
    standbyState  [Standby Status].......Unknown -> 999
    Software Upgrade:

    swVersion  [Package Dir].......20.00.00.22
    updateLevel  [G9 Software Dir].......2000.00.08
    swUpgrading  [SW Upgrade Flag].......N->0
    Command Completed
    ==> expected output: if standbyState  [Standby Status].......Active 
    @filteredList_result = ['7-1-PACKETANDCONTROLCARD']

=cut

=head2 B<runCmd()>

    This function is used to execute command (Ex: Shutdown/ Lock/ Unlock/ Switchover/ Modify Trunk/...) using CLI in C3
    It call execCmd() and then verify output that returned from execCmd().

=over 6

=item Arguments:

    Mandatory:
        - Object Reference
        - path 
        - cmd

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->runCmd(-path => 'Nodes/MG-Nodes/2-G9MGNODE', -cmd => ['mod Ip2IpSwitching=1', 'mod Ip2IpSwitchingUnLimited=1']);

=back

=cut

sub runCmd {
    my ($self, %args) = @_;
    my $sub_name = "runCmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-path', '-cmd') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @cmd_result;
    my $result = 1;
    foreach (@{$args{-cmd}}) {     	#Running commands one by one
        if ($_  =~ m/^query$/) {
            my $prev_prompt = $self->{conn}->prompt('/Completed/');
            $self->{conn}->waitfor(-match => $prev_prompt);
            if (grep /Command Not/, $self->execCmd($_)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd : $_ ");
                $result = 0;
                last;
            }
            $prev_prompt = $self->{conn}->prompt('/>/');
        } else {
            @cmd_result = $self->execCmd($_);
            if (grep /Command Completed/, @cmd_result) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Execute command : $_ successfully");
            } elsif (grep /Please try again/, @cmd_result) {                                            #If 'Please try again' is found in the output of the command, it is re-run
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $_. Trying again");
                unless (grep /Command Completed/,$self->execCmd($_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd: $_ again");
                    $result = 0;                                                                   #If the prompt is not obtained, flag is set and we return 0
                    last;
                }
            } elsif (grep /already exists|already assigned|already used|Only one VoIP Trunk subgroup can be created/, @cmd_result) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Please skip this command: $_ . Field is already exists ");
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $_.");
                $result = 0;
                last;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<getvalue()>

    This function is used to get one/multiple value(s) of an option from the input matrix using CLI in C3
    
=over

=item Arguments:

        Mandatory:
            - Object Reference
            - path
            - vector_list
            - optionName
            
=item Returns:

        Output: a array is list of optionValue.

=item Example:

        $obj->getValue(-path => '/Nodes/MG-Nodes/1-G9MGNODE/Slots', -vector_list => ['7-1-PACKETANDCONTROLCARD','8-1-PACKETANDCONTROLCARD'], -optionName => 'standbyState');

=back

=cut

sub getValue {
    my ($self, %args) = @_;
    my $sub_name = "getValue";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@cmd_result, @tmp, @optionValue);
    my $flag = 1;                                                                                                    
    foreach ('-path', '-vector_list','-optionName') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                        # changing directory to the specified one
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__. ".$sub_name: Changing the prompt to /Completed/");
    my $prev_prompt = $self->{conn}->prompt('/Completed/');
    foreach my $i (0 .. $#{$args{-vector_list}}) {
        @cmd_result= $self->execCmd("query $args{-vector_list}[$i]");
        if (grep /Command Not/, @cmd_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute cmd: query $args{-inputList}[$i] ");
            last;
        }
        foreach $i (0 .. ($#cmd_result)) {                                                                      #transform array
            if ($cmd_result[$i] =~ /$args{-optionName}/) {
                @tmp = split(/]......./, $cmd_result[$i]);
                if ($tmp[1] =~ /->/) {
                    @tmp = split(/->/, $tmp[1]);
                    $tmp[1] =~ s/^\s+|\s+$//g;
                    push @optionValue, $tmp[1];
                }
		else{
                    push @optionValue, $tmp[1];
                }
            } 
        }
    }
    $logger->debug(__PACKAGE__. ".$sub_name: Changing the prompt back to />/");
    $prev_prompt = $self->{conn}->prompt('/>/');
    $self->{conn}->waitfor(-match => '/>/');
    $logger->debug(__PACKAGE__ . ".$sub_name optionValue : ". Dumper(\@optionValue));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub ");
    return @optionValue;
}

=output of command
    <function> <getValue>
    cd /Nodes/MG-Nodes/1-G9MGNODE/Slots
    Command Completed
    >query 7-1-PACKETANDCONTROLCARD
     PACKETANDCONTROLCARD:-
    Identification:
    mgNode  [MG Node].......1
    slot  [Slot].......7
    card  [Card].......1
    type  [Type].......Packet/Control Card -> 64
    actualType  [Actual Type].......Undefined -> 65535
    Status:
    adminState  [Admin State].......Unlocked -> 2
    operState  [Operating State].......Unknown -> 0
    Protection:
    group  [Group].......20
    Mfg. Info:
    functVer  [Functional Ver].......
    partNum  [Part Number].......8050080142
    serialNum  [Serial Number].......11350512
    hardwareRevision  [Hardware Revision].......0C
    cleiCode  [CLEI Code].......nocleicode
    manufacturedDate  [Manufacture Date].......Sep 1, 2011
    Secondary Status:
    availState  [Availability Status].......Unknown -> 999
    alarmState  [Alarm Status].......Unknown -> 999
    standbyState  [Standby Status].......Unknown -> 999
    Software Upgrade:

    swVersion  [Package Dir].......20.00.00.22
    updateLevel  [G9 Software Dir].......2000.00.08
    swUpgrading  [SW Upgrade Flag].......N->0
    Command Completed
    ==> expected output: if standbyState  [Standby Status].......Unknown -> 999 
    @optionValue = ['999']

=cut

=head2 B<getActiveStandbyApp()>

    This function is used to check/login to the active MSC, and get all ACTIVE/STANDBY AppMgrs  information using CLI command dis_appmgr_index.
    
    Step: - Login to MSC1, check active state using command dis_appmgr_index
                if (active) => return session and list of ACTIVE/STANDBY AppMgr
                else: login to MSC2 => check Active state and return List of ACTIVE/STANDBY AppMgr

=over 3

=item Arguments:

    Mandatory:
        -value_MSC1 : <Info MSC1> 
        -value_MSC2 : <Info MSC2>
    Optional:
        - sessionLog => 'File name'

=item Returns:

        Returns 2 variables:
            1: active_MSC_value
            2: session C3
            3: List of ACTIVE/STANDBY AppMgrs
            

=item Example:

        ($ses_C3,$active_MSC_value, @cmd_result) = SonusQA::C3::getActiveStandbyApp(-value_MSC1 => $TESTBED{"c3:1:ce0"}, -value_MSC2 => $TESTBED{"c3:2:ce0"}, -sessionLog => 'FileName'))

=back

=cut

sub getActiveStandbyApp {
    my ( %args) = @_;
    my ($ses_C3, @cmd_result, $active_MSC_value); 
    my $sub_name = "getActiveStandbyApp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 0;
    foreach my $msc_value ($args{-value_MSC1}, $args{-value_MSC2}) {
        unless ($ses_C3 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $msc_value, -sessionLog => $args{-sessionLog})) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to MSC ");
            last;
        }
        @cmd_result = $ses_C3->execCmd("dis_appmgr_index");
        if (grep /OamFault is STANDBY|Error getting SM pointer/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- This is Standby node. Please login in other node");
            $ses_C3->DESTROY; # destroy session that connect to MSC1  
        } else {
            # Transform to return ACTIVE/STANDBY AppMgrList vector
            my $str_result = join('', @cmd_result);
            my @separated = split(/-\s\s*/, $str_result);
            $str_result = $separated[1];
            $str_result =~ s/NO\s/NO\r\n/g;
            @cmd_result = split(/\r\n/, $str_result); # vector appMgrList
            $active_MSC_value = $msc_value;
            $flag = 1;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name cmd_result : ". Dumper(\@cmd_result));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return ($ses_C3,$active_MSC_value, @cmd_result); # return sesstion and array of STANDBY/ACTIVE AppMgr
}

=head2 B<getVoipTrgp()>

    This function is to get VoIP Trunk Group.

=over 6

=item Arguments:

    Mandatory:
            path
            groupType
            sipTrunkGroup
            
=item Returns:

        Output: array by verify to groupType and sipTrunkGroup.

=item Example:

        $obj->getVoipTrgp(-path => '/Nodes/MG-Nodes/1-G9MGNODE/VoIP', -groupType => '1', -sipTrunkGroup => '16');

=back

=cut

sub getVoipTrgp {
    my ($self, %args) = @_;
    my $sub_name = "getVoipTrgp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@cmd_result, @tmp, @result_list, $voipTrkGroup, $path2VoipTrkgrp);
    my $flag = 1;
    foreach ('-path','-groupType','-sipTrunkGroup') {                                                                                   #Checking for the parameters in the input hash
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 
    @cmd_result= $self->listElements(-path => $args{-path});                                                          # list elements at /Nodes/MG-Nodes/1-G9MGNODE/VoIP
    foreach my $i (0 .. ($#cmd_result)) {                                                                                                   
        if ($cmd_result[$i] =~ /VOIPTRUNKGROUP/) {
            $path2VoipTrkgrp = $args{-path}."/".$cmd_result[$i];
            @tmp = $self->listElements(-path => $path2VoipTrkgrp);
            foreach my $j (0 .. ($#tmp)) {
                if ($tmp[$j] eq $args{-groupType}.'-'.$args{-sipTrunkGroup}.'-VOIPMGCTRUNKGROUP') {                                                                                                       
                    $logger->info(__PACKAGE__ . ".$sub_name: Verify $tmp[$j] successfully");
                    $voipTrkGroup = $cmd_result[$i];
                    $path2VoipTrkgrp = $path2VoipTrkgrp.'/'.$tmp[$j];
                    @result_list = ($voipTrkGroup, $path2VoipTrkgrp);
                    last;
                }
            }
        }
        last if (@result_list);
    }   
    $logger->debug(__PACKAGE__ . ".$sub_name result_list : ". Dumper(\@result_list));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return @result_list;                    
}

=output of command
    <function> <getVoipTrgp>
    cd /Nodes/MG-Nodes/1-G9MGNODE/VoIP
    Command Completed
    >list
    1-VOIPCODECRTPTIMEOUT
    1-VOIPPROFILE
    1-VOIPTRUNKGROUP
    2-VOIPTRUNKGROUP
    3-VOIPTRUNKGROUP
    
    cd /Nodes/MG-Nodes/1-G9MGNODE/VoIP/1-VOIPTRUNKGROUP
    Command Completed
    >list
    1-113-VOIPMGCTRUNKGROUP
    1-1500-VOIPMGCTRUNKGROUP
    1-5067-VOIPMGCTRUNKGROUP
    1-VOIPMGSUBTRUNKGROUP
    2-12-VOIPMGCTRUNKGROUP
    ==> expected output: if 1-5067-VOIPMGCTRUNKGROUP 
    @result_list = ['1-VOIPTRUNKGROUP','/Nodes/MG-Nodes/1-G9MGNODE/VoIP/1-VOIPTRUNKGROUP/1-5067-VOIPMGCTRUNKGROUP']
    
=cut

=head2 B<addRemoteHost()>

    This function is used to add Remotehost

=over 

=item Arguments:

 Mandatory:
 
        path
        addRHcmd - command to add remote host
        
=item Returns:
        
        0 - failed
        1 - pass 
        
=item Example:

        $obj->addRemoteHost(-path => '/IP-Signaling/SIP-Signaling/SIP-Gateway/1-SIPGATEWAY/SIP-Remote-Host', -addRHcmd=> 'add SIPREMOTEHOST RemoteHostID=7979, RemoteHostName=ADQ-587_7979,RemoteHostIPAddr=172.20.248.141, RemoteHostDomainName=c3.com, RemoteHostPort=7979,RemoteHostRxPort=7979,RemoteHostProtocol=1');

=back

=cut

sub addRemoteHost {
    my ($self, %args) = @_;
    my $sub_name = "addRemoteHost";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-path', '-addRHcmd'){                                                        #Checking for the parameters in the input hash
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    my @cmd_result = $self->execCmd("$args{-addRHcmd}");
    my $result = 1;
    if (grep /SIPREMOTEHOST Successfully/, @cmd_result) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Add remotehost successfully with command: $args{-addRHcmd} " );
    } elsif (grep /already exists/, @cmd_result) {
        $logger->debug(__PACKAGE__ . ".$sub_name: SIP Remote Host already exists. Please skip this step " );
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add remote host with command:  $args{-addRHcmd}");
        $result = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<getCoreDumpCount()>

    This function is used to count a number of core dumps.

=over

=item Arguments:
            
=item Returns:

          Returns count of coredumps  - If succeeds
          Reutrns -1                  - If Failed

=item Example:

        $obj->getCoreDumpCount();

=back

=cut

sub getCoreDumpCount {
    my ($self) = @_;
    my $sub_name = "getCoreDumpCount";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $count_result = 0;
    
    unless ($self->execCmd("cd /stats/core")) {                                             #cd to path
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd /stats/core");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [-1]");
        return -1;
    }    
    unless (($count_result) = $self->execCmd("ls -ltr | wc -l")) {                                       # run command ls -ltr | wc -l
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to run cmd ls -ltr | wc -l");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [-1]");
        return -1;
    }
    $count_result = $count_result - 1;
    $logger->debug(__PACKAGE__ . ".$sub_name count_result : $count_result");
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [$count_result]");
    return $count_result;
}

=output of command
    <function> <getCoreDumpCount>
    cd /stats/core
     ls -ltr | wc -l
        4
    => $count_result = 3
=cut

=head2 B<deleteRemoteHost()>

    This function is used to delete Remotehost

=over 

=item Arguments:

        Mandatory:

            path
            remoteHostID 
            
=item Returns:

        0 - failed
        1 - pass 
        
=item Example:

        $obj->deleteRemoteHost(-path => '/IP-Signaling/SIP-Signaling/SIP-Gateway/1-SIPGATEWAY/SIP-Remote-Host', -remoteHostID => ['7980-SIPREMOTEHOST', '7979-SIPREMOTEHOST']);

=back

=cut

sub deleteRemoteHost {
    my ($self, %args) = @_;
    my $sub_name = "deleteRemoteHost";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-path', '-remoteHostID'){                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")){                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    my ( @cmd_result, @tmp, $path, $sipGrp );
    my $result = 1;
    foreach my $i (0 .. $#{$args{-remoteHostID}}) {
        @cmd_result = $self->execCmd("del $args{-remoteHostID}[$i]");
        if (grep /Command Completed/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Delete remote host: $args{-remoteHostID}[$i] successfully");
            next;
        } elsif (grep /Unable to retrieve data/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Failed to delete remote host: $args{-remoteHostID}[$i] ");
            $result = 0;
            last;
        }
        foreach (@cmd_result) {
            my $sipGrpID;
            if (!$path && /This SIP Remote Host cannot be deleted, it is used by (.+)/){ # it is used by SIP DAL Group or  SIP Group => delete SIP-Dal or SIPTrunk using funtion deleteTrunkGroup()   
                $path = ($1=~/SIP DAL Group/) ? '/Groups/SIP-Dal' : '/Groups/SIP-Trunk';   
            } 
            next unless $path;
            
            if (/SIP DAL Group ID:\s*(\d+)/) {                    
                $sipGrp = "$1-SIPDALGROUP";                    
                $path = "/Groups/SIP-Dal";       
            } elsif (/SIP Group ID:\s*(\d+)/) {                    
                $sipGrp = "$1-SIPGROUP"; 
                $path = "/Groups/SIP-Trunk";
            } elsif (/ID:\s*(\d+)/) {    
                $sipGrpID = $1;
                $sipGrp= ($path=~/SIP-Dal/) ? "$sipGrpID-SIPDALGROUP" : "$sipGrpID-SIPGROUP";
            }
            if($sipGrp){
                unless ($self->deleteTrunkGroup(-path => $path, -trunkGrpID => [$sipGrp])) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to delete SIP-Trunk: $sipGrp ");
                    $result = 0;
                    last;
                }
                $sipGrp = '';
            }
        }
        unless($path){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to delete remoteHostID: $args{-remoteHostID}[$i] ");
            $result = 0;
            last;
        }
        unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")){                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
            $result = 0;
            last;
        }
        unless (grep /Command Completed/, $self->execCmd("del $args{-remoteHostID}[$i]")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to delete remoteHostID: $args{-remoteHostID}[$i] ");
            $result = 0;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<addTrunkGroup()>

    This function is used to add SIPDALGROUP or SIP Trunk

=over 

=item Arguments:

     Mandatory:
     
            path
            addTrunkGroup - command to add trunk group
        
=item Returns:

        0 - failed
        1 - pass 
        
= steps: 
        - cd path
        - add trunkGrp
        - unlock trunkGrp
        
=item Example:

        $obj->addTrunkGroup(-path => '/groups/sip-dal', -addTrunkGroup=> 'add SIPDALGROUP trunkGrp=124,groupName=Tuc_7024,customerGroup=0,casDalTransGrp=1,SipGatewayID=1,remoteHostID=124,maxCicNumber=100');

=back

=cut

sub addTrunkGroup {
    my ($self, %args) = @_;
    my $sub_name = "addTrunkGroup";
    my (@tmp, $path, $addTrunkGroupCmd, $trunkGrpId);
    $addTrunkGroupCmd = $args{-addTrunkGroup};
    $path = uc $args{-path};
    
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-path', '-addTrunkGroup'){                                                        #Checking for the parameters in the input hash
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $path")) {                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $path");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
    }
    my @cmd_result =  $self->execCmd($addTrunkGroupCmd);
    my $result = 1;
    if (grep /Successfully/, @cmd_result) {
        # transform to get trunkGrp id
        if ($addTrunkGroupCmd =~ /trunkGrp\s*\=\s*(\d\d*)/) {
            $trunkGrpId = $1;
        }
        
        # check SIP-TRunk or SIP-Dal
        if ($path =~ m/SIP-DAL/) {
            $trunkGrpId = $trunkGrpId."-SIPDALGROUP";
        } elsif ($path =~ m/SIP-TRUNK/) {
            $trunkGrpId = $trunkGrpId."-SIPGROUP";
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name: Path is invalid:  $path ");
            $result = 0;
        }
        # cd to trunkGrp id
        if (grep /Command Not Completed/, $self->execCmd("cd $trunkGrpId")) {                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd trunk group:  $trunkGrpId ");
            $result = 0;
        } else {	#unlock trunkGrp
            unless(grep /Command Completed/, $self->execCmd("unlock")) {                                                   # changing directory to the specified one
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to unlock trunk group: $trunkGrpId");
                $result = 0;
            }
        }
    } elsif (grep /already exists/, @cmd_result) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Trunk group already exists ");
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add trunk group with command:  $addTrunkGroupCmd");
        $result = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<deleteTrunkGroup()>

    This function is used to delete Trunk group (SIP-DAL or SIP-Trunk)

=over 

=item Arguments:

     Mandatory:
            
            path : path to SIP-DAL or SIP-Trunk
            trunkGrpID : trunkgroup that need to delete
            
=item Returns:

        0 - failed
        1 - pass 
        
=item Example:

        $obj->deleteTrunkGroup(-path => '/Groups/SIP-DAL', -trunkGrpID => ['7979-SIPDALGROUP', '7981-SIPDALGROUP']);
        
=back

=cut

sub deleteTrunkGroup {
    my ($self, %args) = @_;
    my $sub_name = "deleteTrunkGroup";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my (@cmd_result, $mgNode, $voipGrpID, $voipMGCtrunkGrp, $groupIndex, $path, $prev_prompt);
    my $flag = 1;
    foreach ('-path', '-trunkGrpID') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {                                                   # changing directory to the specified one
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $result = 1;
    foreach my $i (0 .. $#{$args{-trunkGrpID}}) {
        $prev_prompt = $self->{conn}->prompt('/Completed/');
        if (grep/Unlocked -> 2/, $self->execCmd("query $args{-trunkGrpID}[$i]")) {
            
            if (grep /Command Not/, $self->execCmd("shutdown $args{-trunkGrpID}[$i]")) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to shutdown $args{-trunkGrpID}[$i]");
                return 0;
            }
            if (grep /Command Not/, $self->execCmd("lock $args{-trunkGrpID}[$i]")) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to lock $args{-trunkGrpID}[$i]");
                return 0;
            }
        }
        $prev_prompt = $self->{conn}->prompt('/>/');
        $self->{conn}->waitfor(-match => '/>/');
        @cmd_result = $self->execCmd("del $args{-trunkGrpID}[$i] ");
        if (grep /Command Completed/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Delete trunkgroup: $args{-trunkGrpID}[$i]  successfully ");
            next;
        } elsif (grep /is not found/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name:   Trunkgroup: $args{-trunkGrpID}[$i]  is not found. Please skip this command");
            next;
        } elsif (grep /Failed to perform Delete/, @cmd_result) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Failed to delete trunkgroup: $args{-trunkGrpID}[$i] ");
            last;
        }
        foreach (@cmd_result) { #MsfNode = 2,   GroupType = System Group,   GroupId = [10],   GroupIndex = 7998
            if (/MsfNode\s*\=\s*(\d\d*)\,\s*GroupType\s*\=\s*System Group\,\s*GroupId\s*\=\s*\[(\d\d*)\]\,\s*GroupIndex\s*\=\s*(\d\d*)/) {  
                $mgNode = $1;
                $voipGrpID = $2;
                $groupIndex = $3;
                $path = "/Nodes/MG-Nodes/".$mgNode."-G9MGNODE/VoIP/".$voipGrpID."-VOIPTRUNKGROUP"; # path to VOIPTRUNKGROUP
                $voipMGCtrunkGrp = "1-".$groupIndex."-VOIPMGCTRUNKGROUP";
                unless (grep /Command Completed/, $self->execCmd("cd $path")) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to cd to VOIPMGCTRUNKGROUP with path: $path ");
                    $result = 0;
                    last;
                }
                unless (grep /Command Completed/, $self->execCmd("del $voipMGCtrunkGrp")) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Failed to delete  VOIPMGCTRUNKGROUP: $voipMGCtrunkGrp ");
                    $result = 0;
                    last;
                }
                # after delete voipMGCtrunkGrp => delete trunkgroup
                unless (grep /Command Completed/, $self->execCmd("cd $args{-path}")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
                    $result = 0;
                    last;
                } 
                unless (grep /Command Completed/, $self->execCmd("del $args{-trunkGrpID}[$i] ")) {
                    $logger->error(__PACKAGE__ . ".$sub_name:   Failed to delete trunkgroup: $args{-trunkGrpID}[$i] ");
                    $result = 0;
                    last;
                }
                last;
            }
        }
        last unless($result);
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<addRouteList()>

    This function used to add addRouteList 

=over 6

=item Arguments:

     Mandatory:
            - routeListId - identifier Type:Integer, Min:1, Max:4096
            - type1 - Identifies the type of route Type:Enumeration
            - value1 - meaning of parameter depends upon type. Type:Integer, Min:1, Max:2147483647 
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addRouteList(routeListId => '4072', type1 => '1', value1 => '7997');

=back

=cut

sub addRouteList {
    my ($self, %args) = @_;
    my $sub_name = "addRouteList";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdAddRouteList;
    foreach ('routeListId', 'type1', 'value1') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 
    $cmdAddRouteList = "add MGCROUTELIST ";
    foreach my $key (keys %args) {
        $cmdAddRouteList = $cmdAddRouteList.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/Route-List', -cmd => [$cmdAddRouteList])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add route list with command: $cmdAddRouteList ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<addOrigRouteDescriptor()>

    This function used to add Orig Route Descriptor Definition 

=over 6

=item Arguments:

     Mandatory:
            - descriptorIndex -  Type:Integer, Min:1, Max:1500
            - routeDescriptor - Specifies a string that uniquely identifies a digit descriptor. Type is CHAR(64)
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addOrigRouteDescriptor(descriptorIndex => '1472', routeDescriptor => 'Huong_7997');

=back

=cut

sub addOrigRouteDescriptor {
    my ($self, %args) = @_;
    my $sub_name = "addOrigRouteDescriptor";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdAddOrigRouteDescriptor;
    foreach ('descriptorIndex', 'routeDescriptor') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 
    $cmdAddOrigRouteDescriptor = "add DIGITDESCRIPTOR ";   
    foreach my $key (keys %args) {
        $cmdAddOrigRouteDescriptor = $cmdAddOrigRouteDescriptor.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/Orig-Routing/Orig-Route-Descriptor-Definition', -cmd => [$cmdAddOrigRouteDescriptor])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add Add Orig Route Descriptor with command: $cmdAddOrigRouteDescriptor ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<addOrigRouteModification()>

    This function used to add Orig Route Modification

=over 6

=item Arguments:

     Mandatory:
            - descriptorIndex - Specifies input Route index descriptor that is assigned in NOA, Prefix Translation, National Translation, or International Country Code. Type:Integer, Min:1, Max:1500
            - amaIndex - Specifies the AMA translation index value (range 1 - 255). This is used in BAF record generation. Type:Integer, Min:1, Max:255
            - digitType - Specifies the type of the digit string.
            - routeActionType - Specifies the type of action to be taken when processing.. Type:Enumeration
            - routeActionIndex - Specifies the route action value. Type:Integer, Min:0, Max:2147483647
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addOrigRouteModification(descriptorIndex => '1472', amaIndex => 'Huong_7997', digitType => '', routeActionType => '', routeActionIndex => '');

=back

=cut

sub addOrigRouteModification {
    my ($self, %args) = @_;
    my $sub_name = "addOrigRouteModification";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdAddOrigRouteModification;
    foreach ('descriptorIndex', 'amaIndex', 'digitType', 'routeActionType', 'routeActionIndex') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 
    $cmdAddOrigRouteModification = "add ORIGROUTE ";   
    foreach my $key (keys %args) {
        $cmdAddOrigRouteModification = $cmdAddOrigRouteModification.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/Orig-Routing/Orig-Route-Modification/1-1-ORIGROUTEMODIFIER', -cmd => [$cmdAddOrigRouteModification])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add Orig Route Modification with command: $cmdAddOrigRouteModification ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<addNationalTranslation()>

    This function used to add National Translation

=over 6

=item Arguments:

     Mandatory:
            - digitPattern - Specifies a prefix digit string.  This is the longest match of the digit string Type is CHAR(32)
            - routeActionType - Specifies the type of action to be taken when processing this digit string
            - routeActionIndex - Specifies the cause code or route index to use to process the call based on the action type.
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addNationalTranslation(digitPattern => 'Huong_7997', routeActionType => '', routeActionIndex => '');

=back

=cut

sub addNationalTranslation {
    my ($self, %args) = @_;
    my $sub_name = "addNationalTranslation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdaddNationalTranslation;
    foreach ('digitPattern', 'routeActionType', 'routeActionIndex') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 

    $cmdaddNationalTranslation = "add DIGITTRANSLATION ";   
    foreach my $key (keys %args) {
        $cmdaddNationalTranslation = $cmdaddNationalTranslation.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/National-Translation', -cmd => [$cmdaddNationalTranslation])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add National Translation with command: $cmdaddNationalTranslation ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<addDigitFence()>

    This function used to add Digit Fence

=over 6

=item Arguments:

     Mandatory:
            - digitFenceIndex - Specifies the prefix digit profile number. Type:Integer, Min:1, Max:10000
            - digitStringType - Specifies the type of the prefix digit string
            - terminationType - Specifies the termination type that is defined by the service provider to be used for Call Screening. Type:Integer, Min:1, Max:255
            - routeAction - Specifies the type of action to be taken when processing this digit string
            
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addDigitFence(digitFenceIndex => 'Huong_7997', digitStringType => '', terminationType => '', routeAction => '');

=back

=cut

sub addDigitFence {
    my ($self, %args) = @_;
    my $sub_name = "addDigitFence";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdaddDigitFence;
    foreach ('digitFenceIndex', 'digitStringType', 'terminationType', 'routeAction') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag); 
    #add DIGITFENCE , transGrpId=1,digitFenceIndex=987,description=Tuc_987,digitStringType=4,terminationType=8,routeAction=0
    # Added Digit Fence: 1-987-10-DIGITFENCE Successfully.
    #  Command Completed

    $cmdaddDigitFence = "add DIGITFENCE ";   
    foreach my $key (keys %args) {
        $cmdaddDigitFence = $cmdaddDigitFence.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/Digit-Fence', -cmd => [$cmdaddDigitFence])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to add Digit Fence with command: $cmdaddDigitFence ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<addPrefixTranslation()>

    This function used to Add Prefix Translation

=over 6

=item Arguments:

     Mandatory:
            - digitPattern - Specifies a prefix digit string (up to 32 digits). Type is CHAR(32)
            - digitFenceIndex - Specifies the index into the Digit Fence table. Type:Integer, Min:1, Max:10000

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        
        $obj->addPrefixTranslation(digitPattern => '1472', digitFenceIndex => 'Huong_7997');

=back

=cut

sub addPrefixTranslation {
    my ($self, %args) = @_;
    my $sub_name = "addPrefixTranslation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    my $cmdaddPrefixTranslation;
    foreach ('digitPattern', 'digitFenceIndex') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag);  
    #add PREFIXTRANSLATOR digitPattern=987,digitFenceIndex=987,description=Tuc_987

    $cmdaddPrefixTranslation = "add PREFIXTRANSLATOR ";   
    foreach my $key (keys %args) {
        $cmdaddPrefixTranslation = $cmdaddPrefixTranslation.",".$key."=".$args{$key};   
    }
    unless ($self->runCmd (-path => '/Office-Parameters/Routing-and-Translation/Prefix-Translation/1-1-PREFIX', -cmd => [$cmdaddPrefixTranslation])) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Add Prefix Translation with command: $cmdaddPrefixTranslation ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return 1;
}

=head2 B<getActivePACcard()>

    This function is used to check/login to the active Pac card using the command dm_node_view.

=over 6

=item Arguments:
        Mandatory:
            -g9Node
            -pac7IP
            -pac8IP   
            -username : user to login PACCARD
            -password  : password to login PACCARD  

=item Returns:

        - active slot (7/8)

=item Example:
        
        $obj->getActivePACcard(-g9Node => '1', -pac7IP => '172.20.203.107', -pac8IP => '172.20.203.108', -username => 'root', -password => 'root');

=back

=cut

sub getActivePACcard {
    my ($self, %args) = @_;
    my $sub_name = "getActivePACcard";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    foreach ('-g9Node', '-pac7IP', '-pac8IP', '-username', '-password') {
        unless (exists $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless($flag);  
   
    my ($g9_state, $pac7_state, $pac8_state, $active_slot, $active_ip);
    my $result = 1;
    my @output = $self->{conn}->cmd("dm_node_view");
    foreach (@output) {
        if ($_ =~ /MSF\s*$args{-g9Node}\s*(\w+)\s*/) {
            $logger->debug(__PACKAGE__ . ".$sub_name: +++ G9 node +++ : $_ ");
            $g9_state = $1;
            $_ =~ /A:\s*(\w+)\s*\w+\s*\((\w)\)\s*B:\s*(\w+)\s*\w+\s*\((\w)\)\s*/;
            $pac7_state = $1;
            $pac8_state = $3;  
            if ($g9_state ne "UNLOCKED") {
                $logger->error(__PACKAGE__ . ".$sub_name: G9 Node is LOCKED state ");
                $result = 0;
            } else {
                if ($pac7_state eq "DISABLED" && $pac8_state eq "DISABLED") {
                    $logger->error(__PACKAGE__ . ".$sub_name: Both PAC7 and PAC8 are  DISABLED ");
                    $result = 0;
                } elsif ($pac7_state eq "ENABLED" && $pac8_state eq "DISABLED") {
                    $active_slot = 7;
                    $active_ip = $args{-pac7IP};
                } elsif ($pac7_state eq "DISABLED" && $pac8_state eq "ENABLED") {
                    $active_slot = 8;
                    $active_ip = $args{-pac8IP};
                } elsif ($pac7_state eq "ENABLED" && $pac8_state eq "ENABLED") {
                    if ($2 eq "A") {
                        $active_slot = 7;
                        $active_ip = $args{-pac7IP};
                    } elsif ($4 eq "A") {
                        $active_slot = 8;
                        $active_ip = $args{-pac8IP};
                    }
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name: States of PAC7 and PAC8 are $pac7_state and $pac8_state ");
                    $result = 0;
                }
            }
            last;    
        }
    }
    if ($result == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [$result]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Active PACCARD is: $active_slot ");
    ### SSH/TELNET to ACTIVE PACCARD ###
    my %input = (-ip => $active_ip, -user => $args{-username}, -password => $args{-password});
    unless ($self -> doSSH(%input)) {
        $logger->info(__PACKAGE__ . ".$sub_name: Cannot ssh to PACCARD. Please telnet to it. ");
        unless ($self -> doTelnet(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot ssh/telnet to active paccard ");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [0]");
            return 0;
        } 
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Ssh/Telnet to Active PACCARD successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [$active_slot]");
    return $active_slot;
}

=head2 B<captureLocal0Log()>

    This function is used to capture the log messages by tailing tail -f /var/log/local0log and writing it to var/log/local0Log_tcid file

=over 6

=item Arguments:

    Mandatory:
            $tcid - the testcase id with which the log will be stored
            
=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->captureLocal0Log($tcid);

=back

=cut

sub captureLocal0Log {
    my ($self, $tcid) = @_;
    my $sub_name = "captureLocal0Log";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Capturing the local 0 log");
    unless(($cmd_result) = $self->execCmd("tail -f /var/log/local0log  | tee /space/Santera/local0Log_$tcid > /dev/null &")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to capture the local 0 log");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{PROCESS_ID} = $1 if  ($cmd_result =~ /\[\d\]\s+(.+)\s*/);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$cmd_result]");
    return $cmd_result;
}

=head2 B<stopLocal0Log()>

    This function is used to kill the capture process. The log file names are then written into the object(self->{CAPTURE_MSG_FILES})

=over 6

=item Arguments:

    Mandatory:
        $tcid - the testcase id with which the log will be stored

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->stopLocal0Log($tcid);

=back

=cut

sub stopLocal0Log {
     my ($self, $tcid) = @_;
    my $sub_name = "stopLocal0Log";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    # check whether the process is there or not
    unless (grep/$self->{PROCESS_ID}/, $self->execCmd("ps -ef |grep local0Log")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Don't find  the process $self->{PROCESS_ID}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Killing the process");
    $self->execCmd("kill -9 $self->{PROCESS_ID}");
    if (grep/$self->{PROCESS_ID}/, $self->execCmd("ps -ef |grep local0Log")) {  
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to kill the process $self->{PROCESS_ID}");
        return 0;
    }
    push(@{$self->{CAPTURE_MSG_FILES}},"/space/Santera/local0Log_$tcid"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyLocal0Log()>

    This function is used to match and verify the pattern present in the log file. 
    (Should use Base::parseLogFiles() to verify)

=over 6

=item Arguments:
    
    Mandatory
        -tcid - the testcase id with which the log will be stored. this id is used to obtain the file and match the pattern in it
        -filterStr: grep Events
        -patterns - The pattern to be matched in the log file

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        my %input = (-filterStr => 'EVT_INBOUND_FQDN', -patterns => ['remoteHostId = 124'],-tcid => 11001);

        $obj->verifyLocal0Log(%input);

=back

=cut

sub verifyLocal0Log {
    my ($self, %input) = @_;
    my $sub = "verifyLocal0Log";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $flag = 1;
    foreach ('-filterStr', '-patterns', '-tcid') {
        unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my ($file) = grep /.+$input{-tcid}/, @{$self->{CAPTURE_MSG_FILES}};
    unless($file) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @logFile;
    #Reading the DBG File
    unless( @logFile = $self->execCmd("cat $file |grep $input{-filterStr}")) {
        $logger->debug(__PACKAGE__ . ".$sub: Cannot read the file ($file)");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $result = 1;
    foreach my $i (0 .. $#{$input{-patterns}}) {
        unless (grep /$input{-patterns}[$i]/, @logFile) {
            $logger->error(__PACKAGE__ . ".$sub: Cannot found patterns :  = $input{-patterns}[$i] = in the captured data");
            $result = 0;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
    return $result;
}

=head2 B<capturePcap()>

    This function is used to capture the pcap file. (ex: /usr/sbin/tcpdump -n -nn -N -O -s 2500 -i any) and writing it to /space/Santera/$tcid.pcap file

=over 6

=item Arguments:

        Mandatory:
            - tcId 
            - interface
        Optional:
            - agruments

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->capturePcap(-tcId => $tcid, -interface => 'any', -agruments => ['-n', '-N']);

=back

=cut

sub capturePcap {
    my ($self, %args) = @_;
    my $sub_name = "capturePcap";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-tcId', '-interface') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    #/usr/sbin/tcpdump -n -nn -N -O -s 2500 -i any -w /space/Santera/TC001.pcap > /dev/null &
    my $cmd = "/usr/sbin/tcpdump -i ".$args{-interface};
    if($args{-agruments}) {
        foreach (@{$args{-agruments}}) {
            $cmd = $cmd." ".$_;
        }
    }
    $cmd = $cmd." -w /space/Santera/$args{-tcId}.pcap > /dev/null &";
    
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to /#/");
    my $prev_prompt = $self->{conn}->prompt('/#/');
    my $cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Capturing the pcap file ");
    unless(($cmd_result) = $self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to capture the pcap file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{PROCESS_ID} = $1 if  ($cmd_result =~ /\[\d\]\s+(.+)\s*/);
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$cmd_result]");
    return $cmd_result;
}

=head2 B<stopCapturePcap()>

    This function is used to kill the capture Pcap process. The log file names are then written into the object(self->{CAPTURE_MSG_FILES})

=over 6

=item Arguments:

    Mandatory:
        $tcid - the testcase id with which the log will be stored

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->stopCapturePcap($tcid);

=back

=cut

sub stopCapturePcap {
    my ($self, $tcid) = @_;
    my $sub_name = "stopCapturePcap";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Killing the process");
    unless (grep/$self->{PROCESS_ID}/, $self->execCmd("ps -ef |grep tcpdump")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Don't find  the process $self->{PROCESS_ID}");
        return 0;
    }
    $self->execCmd("kill -9 $self->{PROCESS_ID}");
    if (grep/$self->{PROCESS_ID}/, $self->execCmd("ps -ef |grep tcpdump")) {  
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to kill the process $self->{PROCESS_ID}");
        return 0;
    }
    push(@{$self->{CAPTURE_MSG_FILES}},"/space/Santera/$tcid.pcap");  
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyPcapFile()>

    This function is used to match and verify the field present in the pcap file. Example: ip, protocol,... 
    

=over 6

=item Arguments:
    
    Mandatory
        -tcid - the testcase id with which the log will be stored. this id is used to obtain the file and match the pattern in it
        -filterString - string to filter in Tshark
        -start_boundary
        -definedMsg
        -pattern
        -end_boundary

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:
         tshark -nr /space/Santera/CGE183_06.pcap -R sip.Status-Code==488 -V -T text
        my %input = (-tcid => 'TC001', 
                     -filterString => 'sip',
                     -start_boundary => ['INVITE', 'SIP/2.0'],
                     -definedMsg => ['Src:  CP_CALLM_ID', 'ID_CHANNEL_ID  SIP_TRUNK 20408'],
                     -pattern =>  ['ID_GENERIC_ADDRESS  TOA_UPADDR_NOT_SCREENED NATIONAL SCR_USER_PROVIDED_NOT_VER PRES_RSTR_ALLOWED NPI_ISDN TI_NOT_TEST_CALL 1234567890 10'],
                     -end_boundary => '----------',
                    );
        $obj->verifyPcapFile(%input);

=back

=cut

sub verifyPcapFile {
    my ($self, %input) = @_;
    my $sub = "verifyPcapFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $flag = 1;
    foreach ('-tcid', '-filterString', '-start_boundary', '-definedMsg', '-pattern', '-end_boundary') {
         unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my ($file) = grep /.+$input{-tcid}/, @{$self->{CAPTURE_MSG_FILES}};
    unless($file) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @logFile;
    # Covert PCAP file to text 
    unless( @logFile = $self->execCmd("tshark -nr $file -R $input{-filterString} -V -T text") ){
        $logger->debug(__PACKAGE__ . ".$sub: Cannot convert the file ($file) to text");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($header, %count, %content);
    my @pattern = @{$input{-pattern}};
    my $temp_pattern = join ('|', ${$input{-start_boundary}}[0]); # i need to this make regex match circus
    my $end_boundary = $input{-end_boundary};
    foreach my $line (@logFile) {
        chomp $line;
		 #if we match for required header i will count them, also i store data in array
        if (!$header && $line =~ /${$input{-start_boundary}}[1]/i && $line =~ /($temp_pattern)/) {
            $header = $1;
            $count{$header}++;
        } 

        $header ='' if ( $line =~ /$end_boundary/);
                  
        next unless $header;
        
        push (@{$content{$header}{$count{$header}}}, $line);
        
    }
     
    my @expected_msg;
    foreach my $definedMsg (@{$input{-definedMsg}}) {
        foreach my $msg (keys %content) {
            foreach my $occurrence (keys %{$content{$msg}}) {
                $logger->debug(__PACKAGE__ . ".$sub: msg " . $definedMsg);
                unless (grep /$definedMsg/, @{$content{$msg}->{$occurrence}}) {
                    delete $content{$msg}{$occurrence};
                    next;
                }
                if ($definedMsg eq ${$input{-definedMsg}}[-1]) {
                     push (@expected_msg, @{$content{$msg}{$occurrence}});
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: " . Dumper(\@expected_msg));
    unless (@expected_msg) {
        $logger->error(__PACKAGE__ . ".$sub:  Can not found  definedMsg : ". Dumper(@{$input{-definedMsg}}) ."in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my $result = 1;
    foreach my $msg (@pattern) {
        unless (grep/$msg/, @expected_msg) {
            $logger->info(__PACKAGE__ . ".$sub:  Not found  pattern $msg in the captured data.");
            $result = 0;
            last;
        }
    }
    if($result == 1){
        $logger->info(__PACKAGE__ . ".$sub: All patterns found in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 B<connectToMSC()>

    This function first opens a telnet connection to the MSC IP and then executes the commands passed in the input hash 
    and finally exits from the telnet conn.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        user
        password
 Optional:
        port
        cmd
        path

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->connectToMSC(-ip => '127.0.0.1', -port => 5400, -user => 'test1', -password => 'admin1', -path => 'Nodes/MG-Nodes/2-G9MGNODE', -cmd => ['mod Ip2IpSwitching=1', 'mod Ip2IpSwitchingUnLimited=1']);

=back

=cut

sub connectToMSC{
    my ($self, %args) = @_;
    my $sub_name = "connectToMSC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($self->doTelnet(%args)){                                                                #Telnet to MSC with IP and port
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to telnet to server $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $prev_prompt = $self->{conn}->prompt('/System.+\>/');                                     #Changing the prompt to System.+> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to /System.+>/");
    $self->{conn}->waitfor(-match => '/System\>/');
    unless($self->{conn}->cmd(-string => "set event=off", -prompt => '/.*\>/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set basic parameters");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->cmd(-string => "set prompt=off", -prompt => '/.*\>/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set basic parameters");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->cmd(-string => "set alarm=off", -prompt => '/.*\>/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set basic parameters");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->cmd(-string => "set prompt=on", -prompt => '/System\>/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set basic parameters");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if($args{-path}){
        unless($self->execCmd("cd $args{-path}")){                                                   # changing directory to the specified one
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to cd to $args{-path}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    my @cmd_result;
    my $flag = 1;
    if($args{-cmd}){
        foreach(@{$args{-cmd}}){                                                                     #Running commands one by one
            @cmd_result = $self->execCmd($_);
            if(grep /Please try again/, @cmd_result){                                            #If 'Please try again' is found in the output of the command, it is re-run
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $_. Trying again");
                unless($self->execCmd($_)){
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd again");
                    $flag = 0;                                                                   #If the prompt is not obtained, flag is set and we return 0
                    last;
                }
            }
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->prompt($prev_prompt);                                                         #Changing the prompt back to original one before issuing exit
    unless($self->execCmd("exit")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to exit from MSC");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<connectToPAC()>

    This function first opens a telnet connection to the PAC IP and then connects to slot 7 to check the state(active or standby)
    If the state is standby, then we connect to slot 8 1 else we connect to slot 7 1 and run the ip2ip 0 command 
    to check for the Active Connect

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        user
        password
 Optional:
        port

=item Returns:

        Returns 0 - If failed
        Reutrns 1 - If success

=item Example:

        $obj->connectToPAC(-ip => '10.250.14.10', -user => 'root', -password => 'root');

=back

=cut

sub connectToPAC{
    my ($self, %args) = @_;
    my $sub_name = "connectToPAC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to telnet to $args{-ip} with user $args{-user} and password $args{-password}");
    unless($self->doTelnet(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to telnet to server $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @cmd_result;
    my $prev_prompt = $self->{conn}->prompt('/N02\-.+\>/');                                      #Changing the prompt to match /N02\-.+\>/
    $self->{conn}->waitfor(-match => $self->{conn}->prompt);
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to connect to slot 7");  
    unless(@cmd_result = $self->execCmd("conn 7 0;mc")){                                         #Connecting to slot 7 and checking for the state
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to slot 7");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

=pod

N02-M107-1901.01.06-TNT0700>conn 7 0;mc

  MSF Node:2 Slot:7, SW:ACTIVE(Normal,Normal), HW:Active, CmcInitState:SystemReady-Phase II(6)
  Current coreDumpFlag : Duplex_CoreDump_Only . Current coreDumpState : No_CoreDump(--).

=cut

    $self->execCmd('disconnect');
    if(grep /standby/i, @cmd_result){                                                            #If the state is standby, disconnecting from slot 7 and connecting to slot 8
        $logger->debug(__PACKAGE__ . ".$sub_name: Slot 7 is Standby. Connecting to slot 8");
        unless($self->{conn}->print("conn 8 1")){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to slot 8 1");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Slot 7 is Active");
        unless($self->{conn}->print("conn 7 1")){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to connect to slot 7 1");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyConn()>

    This function is used to run the ip2ip 0 command to check for the number of Active Connections

=over 6

=item Arguments:

        Object Reference
        conn - number of active connections to be checked in the output of ip2ip 0 command

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->verifyConn(-conn => 0);

=back

=cut

sub verifyConn{
    my ($self, %args) = @_;
    my $sub_name = "verifyConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmd_result;
    unless(@cmd_result = $self->execCmd("ip2ip 0")){                                              #Checking the active connections
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the active connections");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @result = @cmd_result;
    my $flag = 1;

=pod

Dumper(\@cmd_result) = [
          'ip2ip 0',
          ' ----- IP-TO-IP Switching Configuration -----',
          '   Feature Status : Enabled',
          '        Max Limit : 0',
          ' --- IP-TO-IP Switching Current Statistics ---',
          '           ActiveConn    EnterAtt   EnterSucc   EnterFail',
          '                    0           0           0           0',
          '             BreakAtt   BreakSucc   BreakFail  MaxReached   UnsuppCfg',
          '                    0           0           0           0           0',
          ' --- IP-TO-IP Switching Accumulative Statistics ---',
          '           Connection    EnterAtt   EnterSucc   EnterFail',
          '                    0           0           0           0',
          '             BreakAtt   BreakSucc   BreakFail  MaxReached   UnsuppCfg',
          '                    0           0           0           0           0'
        ];

=cut

    while(my $line = shift@result){                                                                #Taking every line of the output into the variable
        if($line =~ /ActiveConn/){                                                                 #Checking if the line contains the string 'ActiveConn'
            my @array = split(/\s+/, $line);                                                       #Split the current line and the next line to find the number of active connections
            my @next = split(/\s+/, shift@result);
            if($next[1] == $args{-conn}){
                $logger->debug(__PACKAGE__ . ".$sub_name: Number of ActiveConn is same as input: $next[1]");
            }else{
                $logger->debug(__PACKAGE__ . ".$sub_name: Number of ActiveConn is $next[1] and input is $args{-conn}");
                $flag = 0;
                last;
            }
            last;
        }
    }   
    $self->execCmd('disconnect');
    $self->{conn}->prompt('/AUTOMATION# $/');
    $self->execCmd('exit');
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}

=head2 B<captureMessage()>

    This function is used to capture the log messages by tailing /space/Santera/msg file and writing it to /space/Santera/msg_tcid file

=over 6

=item Arguments:

        Object Reference
        $tcid - the testcase id with which the log will be stored

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->captureMessage($tcid);

=back

=cut

sub captureMessage {
    my ($self, $tcid) = @_;
    my $sub_name = "captureMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Capturing the messages");
    unless(($cmd_result) = $self->execCmd("tail -f /space/Santera/msg  | tee /space/Santera/msg_$tcid > /dev/null &")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to capture the message");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{PROCESS_ID} = $1 if  ($cmd_result =~ /\[\d\]\s+(.+)\s*/);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$cmd_result]");
    return $cmd_result;
}

=head2 B<stopMessage()>

    This function is used to kill the capture process. The log file names are then written into the object(self->{CAPTURE_MSG_FILES})

=over 6

=item Arguments:

        Object Reference
        $tcid - the testcase id with which the log will be stored

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->stopMessage($tcid);

=back

=cut

sub stopMessage {
    my ($self, $tcid, $copyLocation) = @_;
    my $sub_name = "stopMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Killing the process");
    unless(@cmd_result = $self->execCmd("kill -9 $self->{PROCESS_ID}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to kill the process $self->{PROCESS_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    push(@{$self->{CAPTURE_MSG_FILES}},"/space/Santera/msg_$tcid"); 

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyMessage()>

    This function is used to match and verify the pattern present in a given header in the log file. 
    This inturn calls ATSHELPER::validator() to verify the pattern.

=over 6

=item Arguments:

        Object Reference
        -tcid - the testcase id with which the log will be stored. this id is used to obtain the file and match the pattern in it
        -pattern - The header and pattern to be matched in the log file

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        my %input = (-pattern => { 'INVITE' => { 1 => ['CSeq: 1 INVITE', 'Subject: Performance Test'],
                                        },
                          '100 Trying' => { 1 => ['Call-ID: 1-18473@172.20.248.141', 'Content-Length: 0'],
                                         }
                                 },
                     -tcid => 11001,
                     -start_boundary => 'SIP/2.0'
                    );

        $obj->verifyMessage(%input);

=back

=cut

sub verifyMessage {
    my ($self, %input) = @_;
    my $sub = "verifyMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless (%input) {
        $logger->error(__PACKAGE__ . ".$sub: Input Hash is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($file) = grep /.+$input{-tcid}/, @{$self->{CAPTURE_MSG_FILES}};
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }else{
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @logFile;
    #Reading the DBG File
    unless( @logFile = $self->execCmd("cat $file") ){
        $logger->debug(__PACKAGE__ . ".$sub: Cannot read the file ($file)");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($header, $pdu_start, %count, %content, %returnhash, $resultvalidator);
    my %pattern = %{$input{-pattern}};
    my $temp_pattern = join ('|', keys%pattern); # i need to this make regex match circus
    my $start_boundary = $input{-start_boundary}; #defined boundary or i will take default
    my $end_boundary = '-----------';
    foreach my $line (@logFile) {
        chomp $line;
		 #if we match for required header i will count them, also i store data in array
        if (!$header && $line =~ /$start_boundary/i && $line =~ /($temp_pattern)/) {
            $header = $1;
            $count{$header}++;
        } 

        $header ='' if ( $line =~ /$end_boundary/);
                  
        next unless $header;
        
        push (@{$content{$header}{$count{$header}}}, $line);
    }
    unless (keys %content) {
        $logger->error(__PACKAGE__ . ".$sub: there is no message in the captured data file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;     
    }
    my $flag;
    foreach my $msg ( keys %pattern) {
        foreach my $occurrence ( keys %{$pattern{$msg}}) {
            $flag = 1;
            $resultvalidator = SonusQA::ATSHELPER::validator($pattern{$msg}->{$occurrence}, $content{$msg});
            unless ( $resultvalidator ) {
                $logger->error(__PACKAGE__ . ".$sub: not all the pattern of $occurrence occurrence of $msg present in captured data");
                $main::failure_msg .= "TOOLS:TSHARK- Pattern Count MisMatch; ";
                $flag = 0;
                last;
            }
        }
        last unless($flag == 1);
    }
    if($flag == 1){
        $logger->info(__PACKAGE__ . ".$sub: you found all patterns in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub: Not all patterns found in captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 B<verifyNoMessage()>

    This function is used to verify the patterns not present in the log file. 

=over 6

=item Arguments:

        Object Reference
        -tcid - the testcase id with which the log will be stored. this id is used to obtain the file and match the pattern in it
        -pattern - The pattern to verify not present in the log file
        -definedMsg: define the message needed to verify patterns
        -start_boundary: 
        
=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        my %input = (-start_boundary => ['INVITE', 'SIP/2.0'], 
                             -definedMsg => ['Src:  CP_CALLM_ID', 'ID_CHANNEL_ID  SIP_TRUNK 20408'],
                             -pattern =>  ['ID_GENERIC_ADDRESS  TOA_UPADDR_NOT_SCREENED NATIONAL SCR_USER_PROVIDED_NOT_VER PRES_RSTR_ALLOWED NPI_ISDN TI_NOT_TEST_CALL 1234567890 10'],,
                             -tcid => $tcid
                    ); 

        $obj->verifyNoMessage(%input);

=back

=cut

sub verifyNoMessage {
    my ($self, %input) = @_;
    my $sub = "verifyNoMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless (%input) {
        $logger->error(__PACKAGE__ . ".$sub: Input Hash is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($file) = grep /.+$input{-tcid}/, @{$self->{CAPTURE_MSG_FILES}};
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @logFile;
    #Reading the DBG File
    unless( @logFile = $self->execCmd("cat $file") ){
        $logger->debug(__PACKAGE__ . ".$sub: Cannot read the file ($file)");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($header, %count, %content);
    my @pattern = @{$input{-pattern}};
    my $temp_pattern = join ('|', ${$input{-start_boundary}}[0]); # i need to this make regex match circus
    my $end_boundary = '-----------';
    foreach my $line (@logFile) {
        chomp $line;
		 #if we match for required header i will count them, also i store data in array
        if (!$header && $line =~ /${$input{-start_boundary}}[1]/i && $line =~ /($temp_pattern)/) {
            $header = $1;
            $count{$header}++;
        } 

        $header ='' if ( $line =~ /$end_boundary/);
                  
        next unless $header;
        
        push (@{$content{$header}{$count{$header}}}, $line);
        
    }
        
    my @expected_msg;
    foreach my $definedMsg (@{$input{-definedMsg}}) {
        foreach my $msg (keys %content) {
            foreach my $occurrence (keys %{$content{$msg}}) {
                unless (grep /$definedMsg/, @{$content{$msg}->{$occurrence}}) {
                    delete $content{$msg}{$occurrence};
                    next;
                }
                if ($definedMsg eq ${$input{-definedMsg}}[-1]) {
                     push (@expected_msg, @{$content{$msg}{$occurrence}});
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: " . Dumper(\@expected_msg));
    unless (@expected_msg) {
        $logger->error(__PACKAGE__ . ".$sub:  Can not found  definedMsg : ". Dumper(@{$input{-definedMsg}}) ."in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my $flag = 1;
    foreach my $msg (@pattern) {
        if (grep/$msg/, @expected_msg) {
            $logger->info(__PACKAGE__ . ".$sub:  Found  pattern $msg in the captured data. Expected: Not found");
            $flag = 0;
            last;
        }
    }
    if($flag == 1){
        $logger->info(__PACKAGE__ . ".$sub: All patterns not found in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 B<getSpecificMessage()>

    This function is used to get a message package in the log file. Ex: Invite message, 200 ok, ... 

=over 6

=item Arguments:

        -tcid - the testcase id with which the log will be stored. this id is used to obtain the file and match the pattern in it
        -definedMsg: define the message needed to verify patterns
        -start_boundary: 
        
=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        my %input = (-start_boundary => ['INVITE', 'SIP/2.0'], 
                             -definedMsg => ['Src:  CP_CALLM_ID', 'ID_CHANNEL_ID  SIP_TRUNK 20408'],
                             -tcid => $tcid
                    ); 

        $obj->getSpecificMessage(%input);

=back

=cut

sub getSpecificMessage {
    my ($self, %input) = @_;
    my $sub = "getSpecificMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $flag = 1;
    foreach ('-tcid', '-start_boundary', '-definedMsg') {
         unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my ($file) = grep /.+$input{-tcid}/, @{$self->{CAPTURE_MSG_FILES}};
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @log_content;
    #Reading the DBG File
    unless( @log_content = $self->execCmd("cat $file") ){
        $logger->debug(__PACKAGE__ . ".$sub: Cannot read the file ($file)");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($header, %count, %content);
    my $temp_pattern = join ('|', ${$input{-start_boundary}}[0]); # i need to this make regex match circus
    my $end_boundary = '-----------';
    foreach my $line (@log_content) {
        chomp $line;
		 #if we match for required header i will count them, also i store data in array
        if (!$header && $line =~ /${$input{-start_boundary}}[1]/i && $line =~ /($temp_pattern)/) {
            $header = $1;
            $count{$header}++;
        } 

        $header ='' if ( $line =~ /$end_boundary/);
                  
        next unless $header;
        
        push (@{$content{$header}{$count{$header}}}, $line);
        
    }
        
    my @expected_msg;
    my $defined_msg = shift @{$input{-definedMsg}};
    my $found = 0;

    foreach my $msg (keys %content) {
        foreach my $occurrence (keys %{$content{$msg}}) {                        
            if (grep /$defined_msg/, @{$content{$msg}->{$occurrence}}) {
                $found = 1;
                @expected_msg = @{$content{$msg}->{$occurrence}};
                foreach my $defined_msg1 (@{$input{-definedMsg}}) {
                    unless(grep /$defined_msg1/, @expected_msg) {
                        $logger->error(__PACKAGE__ . ".$sub:  Can not found $defined_msg1 in the occurrence $occurrence. ");
                        @expected_msg = ();
                        $found = 0;
                        last;
                    }
                    $logger->info(__PACKAGE__ . ".$sub:  Found $defined_msg1 in the occurrence $occurrence. ");
                }
                last if ($found);
            }
        }
        last if ($found);
    }
    
    unless (@expected_msg) {
        $logger->error(__PACKAGE__ . ".$sub:  Can not found the required message in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub: Get a specific message successfully.".Dumper(\@expected_msg));
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [@expected_msg]");
    return @expected_msg;
}

=head2 B<copyLogToATS()>

    This function is by default called during object destroy from closeConn(). This function does a tar of all the log files and then copies it to ATS to the path mentioned in 
    TESTSUITE->{PATH}. It then deletes the tar files from the server

=over 6

=item Arguments:

        Object Reference

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->copyLogToATS();

=back

=cut
 
sub copyLogToATS {
    my ($self, %args) = @_;
    my $sub_name = "copyLogToATS";
    my $tcid;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $datestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

    unless($self->{CAPTURE_MSG_FILES}){
           $logger->debug(__PACKAGE__ . ".$sub_name: There are no captured files to copy to ATS");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
           return 1;
    }
    my $log_files = join(' ', @{$self->{CAPTURE_MSG_FILES}});
    if ($log_files =~ /space\/Santera\/(.+)/) { #/space/Santera/TC001.pcap
        $tcid = $1;
    }
    my $tar_file = "/tmp/CAPTURE_MSG_FILES_".$tcid."_".$datestamp.".tgz";
    $logger->info(__PACKAGE__ . ".$sub_name: Tar File will be --> $tar_file");
    my @tar_res;
    unless(@tar_res = $self->execCmd("tar \-czf $tar_file $log_files")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute 'tar \-czf $tar_file $log_files'");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    if(grep(/No such file or directory/,@tar_res)){
        $logger->error(__PACKAGE__ . ".$sub_name: Capture file does not exist");
        $self->execCmd("rm -f $tar_file");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    my $locallogname = $main::log_dir;
    my $flag = 1;
    my %scpArgs;
    $logger->debug(__PACKAGE__ . ".$sub_name: Copying tar file to local path: $locallogname");
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$tar_file";
    $scpArgs{-destinationFilePath} = $locallogname;
    $logger->debug(__PACKAGE__ . ".$sub_name: scp log $tar_file to $locallogname");
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the $tar_file file");
        $flag = 0;
    }
    my $cmd = "rm -f $tar_file $log_files";
    $logger->debug(__PACKAGE__ . ".$sub_name: Executing command $cmd");
    unless ( my @cmd_result = $self->{conn}->cmd($cmd))  {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@cmd_result.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
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

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
   my(@cmdResults,$timestamp);
   $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub ");
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

sub closeConn {
    my $self = shift;
    my $sub_name = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ .".$sub_name: -->Entered Sub");
    unless (defined $self->{conn}) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    $self->copyLogToATS();
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=head2 C< destroyDB() >

    This function is used for destroying DB on C3.

=over

=item Arguments:

   Mandatory :
	1. oam1 node
	2. oam2 node
   	3. callp1 node
   	4. callp2 node

=item Return Value:

    0 - If failed
    1 - If success

=item Example:

    $oam1->destroyDB($oam2,$callp1,$callp2);

=back

=cut

sub destroyDB {
    my ($self,$self2,$self3,$self4)=@_;
    my $sub = 'destroyDB()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub".$self);

    my @cmdResults;
    my ($flag, $flag1) = (1,1);
    my @cmds = ("su - ttadmin",
		"teardownBiRep node1 node2 -all -stop -force",
		"destroyDb -all",
		"exit"
	       );
    $self->execCmd("svcmgmt disable platform");
    $self2->execCmd("svcmgmt disable platform");
    $self3->execCmd("svcmgmt disable platform");
    $self4->execCmd("svcmgmt disable platform");
    my @objects = ($self, $self2);
    foreach my $cmd(@cmds) {
	last unless($flag1);
	foreach my $obj (@objects) {
	    $flag = 1 ;
	    $flag1 = 1;
	    my $prompt = "/ttadmin\\@".$obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}."\%/";
	    my @prompts = ($prompt, $obj->{PROMPT});
	    my $final_cmd = $cmd;
	    $obj->{conn}->prompt($prompts[0]) if($cmd =~ /su - ttadmin/);
	    $obj->{conn}->prompt($prompts[1]) if($cmd =~ /exit/i);
	    $final_cmd =~ s/node1 node2/$obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} $obj->{TMS_ALIAS_DATA}->{NODE}->{2}->{NAME}/ if($cmd =~ /teardownBiRep/);
	    
RERUN :
	    $logger->debug(__PACKAGE__ . ".$sub: CMD : $final_cmd");
		
	    unless(@cmdResults = $obj->execCmd($final_cmd)){
		$logger->error(__PACKAGE__ . ".$sub: Could not execute $final_cmd");
		$logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $obj->{conn}->errmsg);
	        $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $obj->{conn}->last_prompt);
	        $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $obj->{conn}->lastline);
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $obj->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $obj->{sessionLog2}");
        	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	        return 0 ;
	    }
	    if(grep /failed to destroy/i, @cmdResults) {
	        unless($flag){
              	    $logger->debug(__PACKAGE__ . ". Failed to destroy db.");
                    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $obj->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $obj->{sessionLog2}");
		    $flag1 = 0;
            	    last;
            	}
            	$flag = 0;
	    	$logger->debug(__PACKAGE__ . ".$sub: Destroy db failed. Waiting for 180 secs before retring destroyDb");
	    	sleep(180);
       	    	goto RERUN;
    	    }
	}
    }
    $logger->debug(__PACKAGE__ . ".$sub --> Leaving Sub[$flag1]");
    return $flag1;
}

=head2 C< createDB() >

    This function is used for creating DB on C3.

=over

=item Arguments:

   Mandatory :
	1. oam1 object
        2. oam2 object

=item Return Value:

    0 - If failed
    1 - If success

=item Example:

    $oam1->createDB($oam2);

=back

=cut

sub createDB {
    my ($self,$self1)=@_;
    my $sub = 'createDB()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
    
    my $cmd = "/opt/VNF/active/bin/setupfdb.pl";
    $logger->debug(__PACKAGE__ . ".$sub: Sending command $cmd");
    $self->{conn}->print($cmd);
    my ($prematch, $match);
PROMPTS :
    unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter the Host Name for First MSC node \[.*\]:/',
				  -match => '/Enter the Node Number for First MSC node \[1\]:/',
                                  -match => '/Enter the Host Name for Second MSC node \[.*\]:/',
                                  -match => '/Enter the Node Number for Second MSC node \[2\]:/',
                                  -match => '/Configure the two OAM nodes into different core node groups \(Y\/N\) \[\]:/',
				  -match => '/Enter the node group for core site 1 \[1-32\], default=1:/',
				  -match => '/Enter the Cluster Id for this site \[1\]:/',
				  -match => '/Enter the Cluster Description \(120 character max\) for this site \[\]:/',
				  -match => '/Configure cluster as OAM\/CC separated \(Y\/N\) \[\]:/',
				  -match => '/Enter CallMgr Config Param max calls \[\d+\]:/',
				  -match => '/Delete CpMgcpm from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:/',
				  -match => '/Delete SgwBicc from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:/',
				  -match => '/Delete SgwSip from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:/',
				  -match => '/Select a market from the list above \[14\]:/',
				  -match => '/Enter the switch class type \(class4\/class5\) \[class5\]:/',
				  -match => '/Enter the protocol type \(H248-Text\/H248-Binary\/EGCP\) \[EGCP\]:/',			 
				  -match => '/Do you want to reenter the information\? \(Y\/N\) \[N\]:/',
				  -match => '/Begin configuration\? \(Y\/N\) \[Y\]:/',
				  -match => '/Keep these clocks\? \(Y\/N\) \[N\]:/',
				  -match => '/Keep this timezone\? \(Y\/N\) \[N\]:/',
                     		  -match => $self->{PROMPT},
				  -timeout => 600,
				  -errmode => 'return' 
				)){
	$logger->warn(__PACKAGE__ . ".$sub [$self->{OBJ_HOST}] Did not get one of expected patterns: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");	
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }    
    $logger->debug(__PACKAGE__ . ".$sub: Matched Prompt : $match");
    if($match =~ m/Enter the Host Name for First MSC node \[.*\]:|Enter the Node Number for First MSC node \[1\]:|Enter the Node Number for Second MSC node \[2\]:|Enter the Host Name for Second MSC node \[.*\]:|Enter CallMgr Config Param max calls \[\d+\]:|Enter the Cluster Id for this site \[1\]:|Delete CpMgcpm from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:|Delete SgwBicc from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:|Delete SgwSip from SANTERA\.MSCAPPMGRCONFIG\? \(Y\/N\) \[N\]:|Do you want to reenter the information\? \(Y\/N\) \[N\]:|Begin configuration\? \(Y\/N\) \[Y\]:|Enter the node group for core site 1 \[1-32\], default=1:/i){
	$self->{conn}->print('');
	goto PROMPTS;
   }
   elsif($match =~ m/Configure the two OAM nodes into different core node groups \(Y\/N\) \[\]:|Configure cluster as OAM\/CC separated \(Y\/N\) \[\]:/i){
   	$self->{conn}->print('n');
	goto PROMPTS;
   }
   elsif($match =~ m/Enter the Cluster Description \(120 character max\) for this site \[\]:/i){
        $self->{conn}->print($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME});
        goto PROMPTS;
   }
   elsif($match =~ m/Select a market from the list above \[14\]:/i){
        $self->{conn}->print('5');
        goto PROMPTS;
   }
   elsif($match =~ m/Enter the switch class type \(class4\/class5\) \[class5\]:/i){
        $self->{conn}->print('class4');
        goto PROMPTS;
   }
   elsif($match =~ m/Enter the protocol type \(H248-Text\/H248-Binary\/EGCP\) \[EGCP\]:/i){
        $self->{conn}->print('H248-Text');
        goto PROMPTS;
   }
   elsif($match =~ m/Keep these clocks\? \(Y\/N\) \[N\]:|Keep this timezone\? \(Y\/N\) \[N\]:/i){
        $self->{conn}->print('y');
        goto PROMPTS;
   }
   $self->execCmd("svcmgmt enable platform");
   $self1->execCmd("svcmgmt enable platform");
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1 ;
}


=head2 C< addCallpNode() >

    This function add the CallP nodes if not listed.
    CallP nodes come 3rd and 4th of 'list' command output.(TOOLS - 18612)

=over

=item Arguments:

    Mandatory :
	Node name
    Optional :
	None

=item Return Value:

    0 - If failed
    1 - If success

=item Example:

    $obj->addNode('C3MGCNODE');

=back

=cut

sub addCallpNode{
    my ($self)=@_;
    my $sub = 'addCallpNode';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    unless($self->execCmd('cd /Nodes/MGC-Nodes')){
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute 'cd /Nodes/MGC-Nodes'");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    my @list_out;
    unless(@list_out = $self->execCmd('list')){
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute 'list'");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

=pod
>list
Common-Static-Route
Release-Management
1-C3MGCNODE
2-C3MGCNODE
3-C3MGCNODE
4-C3MGCNODE

Command Completed
>
=cut

    my ($node, $count);
    map{ $node = $2 and $count++ if(/^(1|2|3|4)-(\w+)/) } @list_out;
    # No need to add node if already 4 are there
    if($count >= 4){
        $logger->error(__PACKAGE__ . ".$sub: CallP Nodes are already present.");
        $logger->debug(__PACKAGE__ . ".$sub: list output ". Dumper(\@list_out));
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
        return 1;
    }


    unless($self->{conn}->cmd(-string => "set prompt=on", -prompt => '/System\/Nodes\/MGC-Nodes\>/')){
        $logger->error(__PACKAGE__ . ".$sub: Failed to set prompt=on");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my $flag = 1;
    for ($count + 1 .. 4){
        $logger->debug(__PACKAGE__ . ".$sub: Creating node '$_-$node'");
        unless($self->{conn}->print("add $node")){
            $logger->error(__PACKAGE__ . ".$sub: couldn't execute 'add $node'");
            $flag = 0;
            last;
        }
        while(1){
            my ($prematch, $match);
            unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/\(Default:.+\)\s+:/', -match => '/System\/Nodes\/MGC-Nodes\>/')){
                $logger->error(__PACKAGE__ . ".$sub: Failed to get Default or Command Completed prompt");
                $flag = 0;
                last;
            }

            # pressing enter for default
            if($match=~/Default/){
                unless($self->{conn}->print('')){
                    $logger->error(__PACKAGE__ . ".$sub: couldn't execute 'enter'");
                    $flag = 0;
                    last;
                }
            }
            else{
                if($prematch =~/Command Completed/){
                    $logger->info(__PACKAGE__ . ".$sub: Node added successfully");
                }
                else{
                    $logger->error(__PACKAGE__ . ".$sub: Not completed successfully");
                    $logger->debug(__PACKAGE__ . ".$sub: prematch: $prematch");
                    $flag = 0;
                }
                last;
            }

        }
        last unless($flag);
    }
    unless ($self->execCmd('set prompt=off')) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to set prompt=off");
        $flag = 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

1;
