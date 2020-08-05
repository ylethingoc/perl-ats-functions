package SonusQA::CRS;

=head1 NAME

 SonusQA::CRS - Perl module for CRS

=head1 AUTHOR

 Vishwas Gururaja - vgururaja@rbbn.com

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::CRS->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate

=head1 DESCRIPTION

 This module provides an interface to run basic calls using a CRS box.

=head1 METHODS

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Module::Locate qw /locate/;

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
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{conn}->cmd("bash");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
     unless ($self->{conn}->cmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<getSession()>

    This function takes a hash containing the IP, port, crs_ip, crs_port and opens a telnet connection. 
    It is also obtains the session id and stores it in the object as Obj->{CRS_SESSION_ID}

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        port
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-ip => '10.250.193.140' , -port => 15678, -crs_ip => ['10.250.185.150', '10.250.185.151', '10.250.185.152'], -crs_port => [100, 101, 102]);
 $Obj->getSession(%args);
 ######NOTE###### 
 Make sure to provide same number of IPs and Ports. Even when there is only 1 IP and multiple ports, provide the same IP always and vice versa
 my %args = (-ip => '10.250.193.140' , -port => 15678, -crs_ip => ['10.250.185.150', '10.250.185.150', '10.250.185.150'], -crs_port => [100, 101, 102]);

=back

=cut

sub getSession {
    my ($self, %args) = @_;
    my $sub_name = "getSession";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-ip', '-port', '-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to telnet to $args{-ip} with port $args{-port}");
    unless($self->{conn}->print("telnet $args{-ip} $args{-port}")){                              #telnet to the host
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not telnet to $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->waitfor(-timeout => 15);
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully telnet to ip $args{-ip}");
    if(scalar@{$args{-crs_ip}} != scalar@{$args{-crs_port}}){
        $logger->error(__PACKAGE__ . ".$sub_name:   Mismatch in number of CRS IPs and ports");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $cmd = 'get-session ';
    my $i = 0;
    while($i != scalar@{$args{-crs_ip}}){
        $cmd .= ${$args{-crs_ip}}[$i] . ' ' . ${$args{-crs_port}}[$i] . ' ';
        $i++;
    }
    unless($self->{conn}->print($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter command '$cmd' to get CRS session ID");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS\:\s*(\d+)\s*/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully Obtained the CRS Session ID: $1");
        $self->{CRS_SESSION_ID} = $1;
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to get the CRS session ID");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->initializeCRS(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to initialize the CRS Ips and ports");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<initializeCRS()>

    This function initializes all the CRS IPs and ports.
    This is called from getSession(). Need not call it separately.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => ['10.250.185.150', '10.250.185.151', '10.250.185.152'], -crs_port => [100, 101, 102]);
 $Obj->initializeCRS(%args);
 ######NOTE######
 Make sure to provide same number of IPs and Ports. Even when there is only 1 IP and multiple ports, provide the same IP always and vice versa
 my %args = (-crs_ip => ['10.250.185.150', '10.250.185.150', '10.250.185.150'], -crs_port => [100, 101, 102]);

=back

=cut

sub initializeCRS {
    my ($self, %args) = @_;
    my $sub_name = "initializeCRS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    if(scalar@{$args{-crs_ip}} != scalar@{$args{-crs_port}}){
        $logger->error(__PACKAGE__ . ".$sub_name:   Mismatch in number of CRS IPs and ports");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $i = 0;
    while($i != scalar@{$args{-crs_ip}}){
        my $cmd = $self->{CRS_SESSION_ID};
        $cmd .= ' ' . ${$args{-crs_ip}}[$i] . ' ' . ${$args{-crs_port}}[$i] . ' init';
        $logger->debug(__PACKAGE__ . ".$sub_name: Initializing CRS IP ${$args{-crs_ip}}[$i] and port ${$args{-crs_port}}[$i]");
        unless($self->{conn}->print($cmd)){
            $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter command $cmd");
            $flag = 0;
            last;
        }
        my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
        if ($match =~ /SUCCESS/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: Successfully initialized CRS IP ${$args{-crs_ip}}[$i] and CRS port ${$args{-crs_port}}[$i]");
            $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
        }elsif( $match =~ /ERROR/i) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to initialize CRS IP ${$args{-crs_ip}}[$i] and CRS port ${$args{-crs_port}}[$i]");
            $flag = 0;
            last;
        }
        $i++;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}

=head2 B<changeRegion()>

    This function changes the region for originating CRS.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100);
 $Obj->changeRegion(%args);

=back

=cut

sub changeRegion {
    my ($self, %args) = @_;
    my $sub_name = "changeRegion";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Changing the region for originating CRS");
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} change-region $args{-region}")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter command to change region to $args{-region}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully changed region to $args{-region}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to change region to $args{-region}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
    
}

=head2 B<offHook()>

    This function puts the CRS IP and port off hook

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100);
 $Obj->offHook(%args);

=back

=cut

sub offHook {
    my ($self, %args) = @_;
    my $sub_name = "offHook";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} off-hook")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter off-hook command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed off-hook command for IP: $args{-crs_ip} and port: $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute off-hook command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectDialTone()>

    This function detects a dial tone on the CRS IP and port

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100);
 $Obj->detectDialTone(%args);

=back

=cut

sub detectDialTone {
    my ($self, %args) = @_;
    my $sub_name = "detectDialTone";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} detect-tone dial")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter command to detect dial tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed command to detect dial tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute command to detect dial tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;	
}

=head2 B<dialNumber()>

    This function Is used to dial a number using the given dial_type

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port
        dial_num
 Optioanl:
        dial_type(Default - DTMF)

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100, -dial_type => 'DTMF', -dial_num => 4411061);
 $Obj->dialNumber(%args);

=back

=cut

sub dialNumber {
    my ($self, %args) = @_;
    my $sub_name = "dialNumber";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port', '-dial_num'){                                                        #Checking for the parameters in the input hash
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
    my $dial_type = ($args{-dial_type}) ? $args{-dial_type} : 'DTMF';

    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} dial $dial_type $args{-dial_num}")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to dial $dial_type number: $args{-dial_num} for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully dialled $dial_type number: $args{-dial_id} for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while dialing $dial_type number: $args{-dial_id} for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectRingbackTone()>

    This function Is used to detect a ringback tone

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port
 Optioanl:
        detect_tone(Default - 'audible\ ringing resync=True check_done=0')

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100, -detect_tone => 'audible\ ringing resync=True check_done=0');
 $Obj->detectRingbackTone(%args);

=back

=cut

sub detectRingbackTone {
    my ($self, %args) = @_;
    my $sub_name = "detectRingbackTone";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    my $detect_tone = ($args{-detect_tone}) ? $args{-detect_tone} : 'audible\ ringing resync=True check_done=0';

    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} detect-tone $detect_tone")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter command to detect the tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully detected the tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while detecting tone for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectRinging()>

    This function Is used to detect ring

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port
        ring_on
        ring_off

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150', -crs_port => 100, -ring_on => 1000, -ring_off => 4000);
 $Obj->detectRinging(%args);

=back

=cut

sub detectRinging {
    my ($self, %args) = @_;
    my $sub_name = "detectRinging";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port', '-ring_on', '-ring_off'){                                                        #Checking for the parameters in the input hash
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
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} detect-ring usr_cadence=$args{-ring_on}_$args{-ring_off} tolerance=200")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to enter detect-ring command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed detect-ring command for IP $args{-crs_ip} and port $args{-crs_port}]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while executing detect-ring command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectSpeechPath()>

    This function sends a test tone using the originating and terminating CRS IPs and ports provided as input

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port
 Optional:
        dial_type
        detect_tone

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

 my %args = (-crs_ip => ['10.250.185.150', '10.250.185.151'], -crs_port => [100, 101]);
 $Obj->detectSpeechPath(%args);

=back

=cut

sub detectSpeechPath {
    my ($self, %args) = @_;
    my $sub_name = "detectSpeechPath";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    ${$args{-crs_ip}}[1] = ${$args{-crs_ip}}[0] unless ${$args{-crs_ip}}[1];
    ${$args{-crs_port}}[1] = ${$args{-crs_port}}[0] unless ${$args{-crs_port}}[1];
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[0] ${$args{-crs_port}}[0] send-tone quiet")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to send quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully sent quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while sending quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[0] ${$args{-crs_port}}[0] send-tone 1025Hz")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to send tone of freq 1025Hz to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully send tone of freq 1025Hz to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while sending tone of freq 1025Hz to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[1] ${$args{-crs_port}}[1] detect_test_tone 990 1030 4000")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to detect test tone on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully detected test tone on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while detecting test tone on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[0] ${$args{-crs_port}}[0] send-tone quiet")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to send quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully sent quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while sending quiet tone to IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<detectDigitPath()>

    This function sends a test tone using the originating and terminating CRS IPs and ports provided as input

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port
 Optional:
        dial_type
        dial_num
        timeout

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If Failed

=item Example:

 my %args = (-crs_ip => ['10.250.185.150', '10.250.185.151'], -crs_port => [100, 101], -dial_type => 'DTMF', -dial_num => '1234567890#', -timeout => 50);
 $Obj->detectDigitPath(%args);

=back

=cut

sub detectDigitPath {
    my ($self, %args) = @_;
    my $sub_name = "detectDigitPath";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    ${$args{-crs_ip}}[1] = ${$args{-crs_ip}}[0] unless ${$args{-crs_ip}}[1];
    ${$args{-crs_port}}[1] = ${$args{-crs_port}}[0] unless ${$args{-crs_port}}[1];
    my $dial_type = ($args{-dial_type}) ? $args{-dial_type} : 'DTMF';
    my $dial_num = ($args{-dial_num}) ? $args{-dial_num} : '1234567890#';
    my $timeout = ($args{-timeout}) ? $args{-timeout} : '50';
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[1] ${$args{-crs_port}}[1] buffer-digits $dial_type 12 ")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to assign buffer digits to IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully assigned buffer digits to IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while assigning buffer digits to IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[0] ${$args{-crs_port}}[0] send_digit $dial_type $dial_num")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to send $dial_type $dial_num from IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully sent $dial_type $dial_num from IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while sending $dial_type $dial_num from IP ${$args{-crs_ip}}[0] and port ${$args{-crs_port}}[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} ${$args{-crs_ip}}[1] ${$args{-crs_port}}[1] request-digits timeout=$timeout")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to receive the $dial_type number on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully received the $dial_type number on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while receiving the $dial_type number on IP ${$args{-crs_ip}}[1] and port ${$args{-crs_port}}[1]");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<onHook()>

    This function ends the call for a given CRS IP and port

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        crs_ip
        crs_port

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If Failed

=item Example:

 my %args = (-crs_ip => '10.250.185.150' -crs_port => 100);
 $Obj->onHook(%args);

=back

=cut

sub onHook {
    my ($self, %args) = @_;
    my $sub_name = "onHook";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-crs_ip', '-crs_port'){                                                        #Checking for the parameters in the input hash
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Ending the call for $args{-crs_ip} $args{-crs_port}");
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} on-hook")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to execute on-hook command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed on-hook command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while executing on-hook command for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print("$self->{CRS_SESSION_ID} $args{-crs_ip} $args{-crs_port} init")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to end call for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully ended the call for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while ending call for IP $args{-crs_ip} and port $args{-crs_port}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<cleanupCall()>

    This function releases the call session using the session id stored in the object

=over 6

=item Arguments:

    None

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If Failed

=item Example:

 $Obj->releaseSession();

=back

=cut

sub cleanupCall {
    my ($self) = @_;
    my $sub_name = "cleanupCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Deleting the session $self->{CRS_SESSION_ID}");
    unless($self->{conn}->print("delete-session $self->{CRS_SESSION_ID}")){
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to delete session $self->{CRS_SESSION_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;

    }
    my ($prematch, $match) = $self->{conn}->waitfor(-match => '/SUCCESS.*/i', -match => '/ERROR.*/i', -timeout => $self->{DEFAULTTIMEOUT});
    if ($match =~ /SUCCESS/i){
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully deleted session $self->{CRS_SESSION_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched prompt is: $match");
    }elsif( $match =~ /ERROR/i) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Command error:\n$prematch\n$match");
        $logger->error(__PACKAGE__ . ".$sub_name: Error while deleteing session $self->{CRS_SESSION_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
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
    $logger->debug(__PACKAGE__ . ".$sub_name: Exiting from telnet without issuing exit. Will update the function later");
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

1;
