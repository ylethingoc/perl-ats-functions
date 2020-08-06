package SonusQA::C20;

=head1 NAME

 SonusQA::C20 - Perl module for C20

=head1 AUTHOR

 nthuong2 - nthuong2@tma.com.vn

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::C20->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Module::Locate

=head1 DESCRIPTION
 C20 software provides call media and signaling interoperability capabilities. On all platforms, the primary application supported by the C20 software is the Session Initiated Protocol (SIP) Gateway. It only works with SIP protocol.
 This module implements some functions that support on C20.

=head1 METHODS

=cut

# use strict;
use warnings;
use Data::Dumper;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw/locate/;
use List::Util qw(min max);
use List::MoreUtils qw(uniq);

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
    my ($self, %args) = @_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{COMMTYPES} = [ "SSH" ];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%\}\|\>]$/';     #/.*[\$%\}\|\>]$/   /.*[\$%#\}\|\>\]].*$/
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{STORE_LOGS} = 2;
    $self->{LOCATION} = locate __PACKAGE__;
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
        Returns 0 - If Failed

=back

=cut

sub setSystem {
    my ($self) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");

    $self->{PROMPT} = '/[\$%#\}\|\>\]]\s*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{conn}->prompt($self->{DEFAULTPROMPT});

    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10);

    if (grep /cli/, $self->execCmd("")) {
        unless ($self->execCmd("cli-session modify timeout 1410")) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot modify timeout for cli session");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        unless ($self->execCmd("sh")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Can't execute command 'sh'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{conn}->prompt($self->{DEFAULTPROMPT});
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

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
    my ($self, $cmd, $timeout) = @_;
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
        $logger->debug(__PACKAGE__ . ".$sub_name:  errmsg : " . $self->{conn}->errmsg);
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [0]");
        return 0;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".$sub_name ...... : @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub [1]");
    return @cmdResults;
}


=head2 B<coreLineGetStatus()>

    This function gets status of Line (Ex: IDL, MB, SB,...)

=over 6

=item Arguments:

 Mandatory:
        - Line Dial Number

=item Returns:

        Returns status of Line
        Returns 0 - If Failed

=item Example:

        $line_status = $obj->coreLineGetStatus("1514004314");

=back

=cut

sub coreLineGetStatus {
    my ($self, $line_DN) = @_;
    my $sub_name = "coreLineGetStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $line_status;

    unless ($line_DN) {
        #Checking for the parameters in the input
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '\$line_DN' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my @post_result = $self->execCmd("mapci nodisp; mtc; lns; ltp; post d $line_DN print");
    unless (@post_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot post line in MAPCI");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    foreach (@post_result) {
        if (/\d+\s+([A-Z]+)\s+/) {
            $line_status = $1;
            last;
        }
    }

    my $flag = 1;
    foreach ('abort', 'quit all') {
        unless ($self->execCmd("$_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot command $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($line_status) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to get Line status");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $line_status;
}


=head2 B<loginCore()>

    This function takes a hash containing the username and password for loginto C20 core.

=over 6

=item Arguments:

 Mandatory:
        - username 
        - password

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If Failed

=item Example:

        my %args = ( -username => ['testshell1', 'testshell2'], -password => ['automation', 'automation']);
        $obj->loginCore(%args);

=back

=cut

sub loginCore {
    my ($self, %args) = @_;
    my $sub_name = "loginCore";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-username', '-password') { #Checking for the parameters in the input hash
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

    my $result = 0;
    for (my $i = 0; $i < $#{$args{-username}} + 1; $i++) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Trying to loginto core using command 'telnet cm' [$i]");
        $self->{conn}->print("telnet cm"); # Enter username and password , CHAR MODE. telnet terminal type
        unless ($self->{conn}->waitfor(-match => '/CHAR MODE|telnet terminal type/', -timeout => 10)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Didn't get 'Enter username and password' prompt after entering 'telnet cm'");
            last;
        }
        $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
        my @output = $self->{conn}->cmd("$args{-username}[$i] $args{-password}[$i]");
        $logger->debug(__PACKAGE__ . ".$sub_name: " . Dumper(\@output));

        if (grep /Logged in on/, @output) {
            $result = 1;
            $logger->debug(__PACKAGE__ . ".$sub_name: Loginto C20 core successfully");
            unless ($self->execCmd("servord")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'servord' ");
                $result = 0;
            }
            last;
        }
        elsif (grep /Invalid user name or password/, @output) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid user name or password. Please try with other user");
            $self->{conn}->print("\x03");
            $self->{conn}->print("");
            $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10);
        }
        elsif (grep /User logged in on another device, please try again./, @output) {
            $logger->debug(__PACKAGE__ . ".$sub_name: User logged in on another device, please try again..");
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Cannot loginto C20 core ");
            last;
        }
    }
    unless ($result) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot loginto C20 core");
    }

    $self->{conn}->prompt('/.*[%\}\|\>\]].*$/'); # prevPrompt is /.*[\$%#\}\|\>\]].*$/
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<getCUSTGRPnFETXLA()>

    This function gets CUSTGRP and FETXLA from a Line DN

=over 6

=item Arguments:

 Mandatory:
        - Line Dial Number

=item Returns:

    Returns:
        - CUSTGRP
        - FETXLA
    Returns 0 - If Failed

=item Example:

        ($custgrp, $fetxla) = $obj->getCUSTGRPnFETXLA("1514004314");

=back

=cut

sub getCUSTGRPnFETXLA {
    my ($self, $line_DN) = @_;
    my $sub_name = "getCUSTGRPnFETXLA";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($custgrp, $fetxla);

    unless ($line_DN) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $line_DN not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @qdn_result = $self->execCmd("qdn $line_DN");
    unless (@qdn_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: QDN is not worked properly");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@qdn_result) {
        if (/CUSTGRP:\s+(\w+)\s/) {
            $custgrp = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$custgrp is $custgrp");
            last;
        }
    }

    unless ($self->execCmd("table custhead")) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot command table custhead");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my @pos_result = $self->execCmd("pos $custgrp");
    unless (@pos_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot pos the CUSTGRP");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@pos_result) {
        if (/FETXLA\s+(\w+)\)/) {
            $fetxla = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$fetxla is $fetxla");
            last;
        }
    }

    my $flag = 1;
    foreach ('abort', 'quit all') {
        unless ($self->execCmd("$_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot command $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub ($custgrp, $fetxla)");
    return $custgrp, $fetxla;
}

=head2 B<getAccessCode()>

    This function is used to get the access code for call feature.
    Function will get xlaname in NCOS and CUSTHEAD tables.
    Get xlaname in both tables: CUSTHEAD and NCOS
    In table IBNXLA, search the AccessCode of feature based on NCOS xlaname first. If no accesscode is found, CUSTHEAD xlaname will be used for the next search.

=over 6

=item Arguments:

 Mandatory:
        - Table name (Table where to find feature code)
        - Line Dial Number
        - Last column (feature name)

=item Returns:

        Returns access code
        Returns 0 - If Failed

=item Example:

        my %args = (-table => 'IBNXLA', -dialNumber => '1514004314', -lastColumn => 'CHD');
        $access_code = $obj->getAccessCode(%args);

=back

=cut

sub getAccessCode {
    my ($self, %args) = @_;
    my $sub_name = "getAccessCode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($ncos, $featxla, $accessCode);

    my $flag = 1;
    foreach ('-table', '-dialNumber', '-lastColumn') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get custgrp
    my ($custgrp, $fetxla) = $self->getCUSTGRPnFETXLA($args{-dialNumber});
    unless ($custgrp) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get CUSTGRP from Line DN");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get NCOS
    my @qdn_result = $self->execCmd("qdn $args{-dialNumber}");
    unless (@qdn_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: QDN is not worked properly");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@qdn_result) {
        if (/NCOS:\s+(\d+)/) {
            $ncos = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$ncos is $ncos");
            last;
        }
    }
    unless ($ncos ne "") {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get NCOS from QDN command");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get FEATXLA
    foreach ('table ncos', "pos $custgrp $ncos") {
        unless ($self->execCmd("$_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot command $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep /N TO QUIT/, $self->execCmd("cha")) {
        unless ($self->execCmd("y")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command y to confirm");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $var = 1;
    for (my $comp = 0; $comp <= 10; $comp++) {
        my @result = $self->execCmd("");
        if (grep /FEATXLA/, @result) {
            foreach (@result) {
                if (/FEATXLA:\s+(\w+)\s*/) {
                    $featxla = $1;
                    $logger->debug(__PACKAGE__ . ".$sub_name: \$featxla is $featxla");
                    $var = 0;
                    last;
                }
            }
        }
        unless ($var) {
            last;
        }
    }
    unless ($featxla) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- cannot get FEATXLA from table NCOS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    foreach ('abort', 'quit all') {
        unless ($self->execCmd("$_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot command $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get access code
    if (grep /UNKNOWN TABLE/, $self->execCmd("table $args{-table}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Table name is incorrect. Please check again.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @output = $self->{conn}->cmd("format pack");
    $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
    unless (grep /line length/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- cannot command format pack");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @output = $self->execCmd("lis all (1 eq '$featxla *')");
    unless (grep /$featxla/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- cannot command lis all (1 eq '$featxla *')");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    foreach (@output) {
        if (/$featxla\s+(\d+)\s+.*\s$args{-lastColumn}/) {
            $accessCode = $1;
            last;
        }
    }
    unless ($accessCode) {
        my @output = $self->execCmd("lis all (1 eq '$fetxla *')");
        unless (grep /$fetxla/, @output) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- cannot command lis all (1 eq '$fetxla *')");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        foreach (@output) {
            if (/$fetxla\s+(\d+)\s+.*$args{-lastColumn}/) {
                $accessCode = $1;
                last;
            }
        }
    }

    foreach ('abort', 'quit all') {
        unless ($self->execCmd("$_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Cannot command $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($accessCode) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- No feature code found for this service. Please check again.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: access code is $accessCode");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $accessCode;
}


=head2 B<startLogutil()>

    This function takes a hash containing type of Logutil to clear before starting Logutil on Core

=over 6

=item Arguments:

 Mandatory:
        - Core account
        - Logutil type

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If failed

=item Example:

        my %args = (-username => ['testshell1', 'testshell2'], -password => ['automation', 'automation'], -logutilType => ['SWERR', 'TRAP', 'AMAB']); 
        $obj->startLogutil(%args);

=back

=cut

sub startLogutil {
    my ($self, %args) = @_;
    my $sub_name = "startLogutil";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-username', '-password', '-logutilType') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->loginCore(%args{-username}, %args{-password})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot login to Core ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /LOGUTIL:/, $self->execCmd("logutil")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'logutil' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    #delete inactive devices
    my @listDev_result = $self->execCmd("listdevs");
    unless (@listDev_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'listdevs' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if (grep /Inactive/, @listDev_result) {
        foreach (@listDev_result) {
            if (/\d\s+(\w+)\s+Inactive/) {
                unless ($self->execCmd("deldevice $1")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command deldevice $1");
                    $flag = 0;
                    last;
                }
            }
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #clear logutil type
    foreach (@{$args{-logutilType}}) {
        unless (grep /Done/, $self->execCmd("clear $_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command clear $_");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #vptrace enable
    if (grep /VAMP/, @{$args{-logutilType}}) {
        unless ($self->execCmd("vptrace enable")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command vptrace enable");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    # start Logutil
    $self->{conn}->cmd("start");
    $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopLogutil()>

    This function is used to stop Logutil log in core.

=over 6

=item Arguments:

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If failed

=item Example:

        $obj->stopLogutil();

=back

=cut

sub stopLogutil {
    my ($self) = @_;
    my $sub_name = "stopLogutil";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $self->{conn}->cmd("stop");
    unless ($self->{conn}->waitfor(-match => '/stopped/', -timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'stop' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->waitfor(-match => '/>/', -timeout => 10);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Stop logUtil log successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<getAuthenCode()>

    This function gets authencation code for DISA call

=over 6

=item Arguments:

 Mandatory:
        - Line Dial Number

=item Returns:

        Returns authencation code
        Returns 0 - if failed

=item Example:

        $authen_code = $obj->getAuthenCode("1514004314");

=back

=cut

sub getAuthenCode {
    my ($self, $line_DN) = @_;
    my $sub_name = "getAuthenCode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($custgrp, $authen_code, $authen_code_length);

    unless ($line_DN) {
        #Checking for the parameters in the input
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '\$line_DN' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Get CUSTGRP
    my @qdn_result = $self->execCmd("qdn $line_DN");
    unless (@qdn_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: QDN is not worked properly");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@qdn_result) {
        if (/CUSTGRP:\s+(\w+)\s/) {
            $custgrp = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$custgrp is $custgrp");
            last;
        }
    }
    unless ($custgrp) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get CUSTGRP from QDN command");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get authen code
    unless ($self->execCmd("table authcde")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command table authcde");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my @output = $self->{conn}->cmd("format pack;lis all");
    $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command lis all in table authcde");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@output) {
        if (/^$custgrp\s+(\d+)\s/) {
            $authen_code = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$authen_code is $authen_code");
            last;
        }
    }

    unless ($authen_code) {
        #Get authen code length
        unless ($self->execCmd("table authpart")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command table authpart");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        @output = $self->{conn}->cmd("format pack;lis all");
        $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
        unless (@output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command lis all in table authpart");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        foreach (@output) {
            if (/$custgrp\s+\w+\s+(\d+)\s/) {
                $authen_code_length = $1;
                $logger->debug(__PACKAGE__ . ".$sub_name: \$authen_code_length is $authen_code_length");
                last;
            }
        }
        unless ($authen_code_length) {
            $logger->error(__PACKAGE__ . ".$sub_name: Table AUTHPART is not datafilled for customer group $custgrp");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        # Add new authen code
        $authen_code = '1';
        for (my $comp = 0; $comp < ($authen_code_length - 1); $comp++) {
            $authen_code = $authen_code . "1";
        }
        $self->execCmd("table authcde");
        unless (grep /Y TO CONFIRM/, $self->execCmd("add $custgrp $authen_code IBN 0 N \$ SW \$")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot add new authen code to table authcde");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /Y TO CONFIRM/, $self->execCmd("y")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'y' after adding new tuple");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /TUPLE ADDED/, $self->execCmd("y")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot add new tuple in table authcde");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /$custgrp.*$authen_code/, $self->execCmd("pos $custgrp $authen_code")) {
            $logger->error(__PACKAGE__ . ".$sub_name: New authen code has not added to table authcde");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: authen code is $authen_code");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $authen_code;
}

=head2 B<callFeature()>

    This function is used to add/delete call feature to/from the line.

=over 6

=item Arguments:

 Mandatory:
        - Feature name (EX: CFU N, CNDB, CXR CTALL N STD,...)
        - Line Dial Number
        - Delete feature (Yes for deleting, No for adding)

=item Returns:

        Returns 1 - if passed
        Returns 0 - if failed

=item Example:

    Add CFU to 1514004314:
        $obj->callFeature(-featureName => 'CFU N', -dialNumber => '1514004314', -deleteFeature => 'No');
    Delete CFU from 1514004314:
        $obj->callFeature(-featureName => 'CFU', -dialNumber => '1514004314', -deleteFeature => 'Yes');

=back

=cut

sub callFeature {
    my ($self, %args) = @_;
    my $sub_name = "callFeature";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-featureName', '-dialNumber', '-deleteFeature') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $servordCmd;
    unless ($args{-deleteFeature} =~ /N[oO]*/) {
        $servordCmd = 'DEO';
    }
    else {
        $servordCmd = 'ADO';
    }

    unless ($self->execCmd("servord")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'servord' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @output = $self->execCmd("$servordCmd \$ $args{-dialNumber} $args{-featureName} \$ Y");
    if (grep /NOT AN EXISTING OPTION|ALREADY EXISTS|INCONSISTENT DATA/, @output) {
        unless ($self->execCmd("N")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'N' to reject ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    if (grep /Y OR N|Y TO CONFIRM/, @output) {
        @output = $self->execCmd("Y");
        unless (@output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'Y' to confirm ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if (grep /Y OR N|Y TO CONFIRM/, @output) {
            unless ($self->execCmd("Y")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'Y' to confirm ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
    }
    unless ($self->execCmd("abort")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'abort' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my ($expected_result, $feature, $str);
    @output = $self->execCmd("qdn $args{-dialNumber}");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'qdn $args{-dialNumber}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $str = join("\n", @output);
    ($expected_result) = ($str =~ /OPTIONS:(.*)/s);
    unless ($expected_result) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get options from 'qdn' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-featureName} .= " ";
    $args{-featureName} =~ /^(\w+)\s/;
    $feature = uc($1);

    if ($servordCmd =~ /DEO/) {
        # servord command is DEO
        if ($expected_result =~ /OFFICE OPTIONS:.*\n.*$feature.*\n/) {
            $logger->error(__PACKAGE__ . ".$sub_name: $feature in office option, cannot delete ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if ($expected_result =~ /$feature/) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot remove $feature from line ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Delete feature successfully");
    }
    else {
        # servord command is ADO
        unless ($expected_result =~ /$feature/) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot add $feature to line");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Add feature successfully");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<execTRKCI()>

    This function is used to execute command and get result in trkci mode.

=over 6

=item Arguments:

 Mandatory:
        - command ( TrkMemDisp / TMD : Displays Member data for a specified trunk group and member
                    TrkDisp / TD : Displays data for a specified trunk group
                    TrkNumDisp / TND : Displays data for a trunk group number
                    TrkDispAll / TDA : Displays a summary for all trunk groups
                    NetDispAll / NDA : Displays a summary for all Networks
                    NetDisp / ND : Displays network data for a specified trunk group
                    NOdeDispAll / NODA : Displays a summary for all Nodes
                    NOdeDisp / NOD : Displays node data for a specified trunk group).
        - Parameter next to command

=item Returns:

        Returns Output result - if passed
        Returns empty array - if failed

=item Example:

        @output_result = $obj->execTRKCI(-cmd => 'TMD', -nextParameter => 'OTT14SSLTRAFV2');

=back

=cut

sub execTRKCI {
    my ($self, %args) = @_;
    my $sub_name = "execTRKCI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-cmd', '-nextParameter') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    my @trkci_output = $self->execCmd("quit all;trkci");
    unless (@trkci_output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'trkci' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    if ($args{-cmd} =~ /TRKDISPALL|TDA|NETDISPALL|NDA|NODEDISPALL|NODA/i) {
        $args{-nextParameter} = "";
    }

    my @cmd_output = $self->execCmd("$args{-cmd} $args{-nextParameter};quit all");
    unless (@cmd_output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'trkci' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    $logger->debug(__PACKAGE__ . " .$sub_name : " . Dumper(\@cmd_output));

    if (grep /NO COMMAND|Undefined command|Invalid|Incorrect|retry/, @cmd_output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Please check command and parameter");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    my @output_result;
    if ($args{-cmd} =~ /TDA|TRKDISPALL|ND|NETDISP|NDA|NETDISPALL/i) {
        @output_result = grep {/tk_|of trunks/} @cmd_output;
        unless (@output_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: command '$args{-cmd}' return impropely");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }
    elsif ($args{-cmd} =~ /TD|TRKDISP|TND|TRKNUMDISP/i) {
        @output_result = grep {/number of tk/} @cmd_output;
        unless (@output_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: command '$args{-cmd}' return impropely");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }
    else {
        @output_result = @cmd_output;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return @output_result;
}

=head2 B<addLineGroupDNH()>

    This function is used to create and add pilot line, member lines to DNH group
    Note: These lines are used for this function must be assigned.

=over 6

=item Arguments:

 Mandatory:
        -pilotDN: Pilot Line DN
        -addMem: Add member DNH group (Yes or No)
 Optional:
        -listMemDN: List Member Line DN (Note: input this field if 'add member' = Yes)

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        my %args = (-pilotDN => '1514004314', -addMem => 'Yes', -listMemDN => ['1514004315','1514004016']);
        $obj->addLineGroupDNH(%args);

=back

=cut

sub addLineGroupDNH {
    my ($self, %args) = @_;
    my $sub_name = "addLineGroupDNH";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-pilotDN', '-addMem') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->execCmd("servord")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'servord' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # out line first
    my (@list_line, @qdn_result);
    my ($len, $lcc, $custgrp, $subgrp, $ncos);
    my %line_info;
    unless ($args{-addMem} =~ /[Yy][Ee]*[Ss]*/) {
        @list_line = $args{-pilotDN};
    }
    else {
        unless (@{$args{-listMemDN}}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-listMemDN' not present ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        @list_line = ($args{-pilotDN}, @{$args{-listMemDN}});
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: " . Dumper(\@list_line));
    foreach (@list_line) {
        @qdn_result = $self->execCmd("qdn $_");
        unless (@qdn_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot execute 'qdn $_' ");
            $flag = 0;
            last;
        }
        if (grep /UNASSIGNED/, @qdn_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: line $_ is unassigned please check again");
            $flag = 0;
            last;
        }

        foreach (@qdn_result) {
            if (/LINE EQUIPMENT NUMBER:\s+(.+)\s+$/) {
                $len = $1;
            }
            elsif (/CUSTGRP:\s+(\w+)\s+SUBGRP:\s+(\d+)\s+NCOS:\s+(\d+)/) {
                $custgrp = $1;
                $subgrp = $2;
                $ncos = $3;
            }
            elsif (/LINE CLASS CODE:\s+(\w+)\s/) {
                $lcc = $1;
            }
            elsif (/CARDCODE:/) {
                last;
            }
        }
        unless ($len && $lcc && $custgrp && $subgrp ne "" && $ncos ne "") {
            $logger->error(__PACKAGE__ . ".$sub_name: QDN command is not work properly");
            $flag = 0;
            last;
        }

        if (grep /XLAPLAN KEY/, @qdn_result) {
            $line_info{$_} = {
                -lcc     => $lcc,
                -custgrp => $custgrp,
                -subgrp  => $subgrp,
                -ncos    => $ncos,
                -len     => $len,
                -lata    => 'NILLATA 0'
            };
        }
        else {
            $line_info{$_} = {
                -lcc     => $lcc,
                -custgrp => $custgrp,
                -subgrp  => $subgrp,
                -ncos    => $ncos,
                -len     => $len,
                -lata    => ''
            };
        }

        if (grep /ERROR|INCONSISTENT DATA/, $self->execCmd("out \$ $_ $len bldn y y")) {
            foreach ('abort', 'quit all') {
                unless ($self->execCmd("$_")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot command $_");
                    last;
                }
            }
            $logger->error(__PACKAGE__ . ".$sub_name: command 'out' error");
            $flag = 0;
            last;
        }
        unless (grep /UNASSIGNED/, $self->execCmd("qdn $_")) {
            # check line is unassigned after out line
            $logger->error(__PACKAGE__ . ".$sub_name: line $_ is not unassigned after out");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: " . Dumper(\%line_info));

    # add line to DNH group
    my $pilot_dn = $args{-pilotDN};
    my $est_cmd = "est \$ DNH $pilot_dn $line_info{$pilot_dn}{-lcc} $line_info{$pilot_dn}{-custgrp} $line_info{$pilot_dn}{-subgrp} $line_info{$pilot_dn}{-ncos} $line_info{$pilot_dn}{-lata} $line_info{$pilot_dn}{-len} +";
    unless ($self->execCmd("$est_cmd")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'est .... +' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($args{-addMem} =~ /[Nn][Oo]/) {
        foreach (@{$args{-listMemDN}}) {
            $est_cmd = "$_ $line_info{$_}{-len} $line_info{$_}{-lcc} +";
            unless ($self->execCmd("$est_cmd")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '.... +' for member ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
    }
    $est_cmd = "\$ \$ 10 y y";
    unless ($self->execCmd("$est_cmd")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'est' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (grep /HUNT GROUP/, $self->execCmd("qdn $pilot_dn")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot create DNH group");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: create DNH group successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 B<getDISAnMONAnumber()>

    This function gets DISA or MONA number from table DNROUTE

=over 6

=item Arguments:

 Mandatory:
        -lineDN: Line DN to get custgrp
        -featureName: Feature name (DISA or MONA)

=item Returns:

        Returns DISA or MONA number - If Passed
        Returns 0 - If Failed

=item Example:

        my %args = (-lineDN => '1514004314', -featureName => 'DISA');
        $disaNumber = $obj->getDISAnMONAnumber(%args);

=back

=cut

sub getDISAnMONAnumber {
    my ($self, %args) = @_;
    my $sub_name = "getDISAnMONAnumber";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-lineDN', '-featureName') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $custgrp;
    unless ($args{-featureName} =~ /MONA/i) {
        # Get CUSTGRP
        my @qdn_result = $self->execCmd("qdn $args{-lineDN}");
        unless (@qdn_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: QDN is not worked properly");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        foreach (@qdn_result) {
            if (/CUSTGRP:\s+(\w+)\s/) {
                $custgrp = $1;
                $logger->debug(__PACKAGE__ . ".$sub_name: \$custgrp is $custgrp");
                last;
            }
        }
        unless ($custgrp) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get CUSTGRP from QDN command");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ($self->execCmd("table dnroute")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command table dnroute");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $self->{conn}->print("format pack");
    $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
    my @output = $self->execCmd("lis all");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command lis all in table dnroute");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $featureNumber;
    foreach (@output) {
        if (/(\d+)\s+(\d+)\s+(\d+)\s+.*$args{-featureName}\s+$custgrp/) {
            $featureNumber = $1 . $2 . $3;
            $logger->debug(__PACKAGE__ . ".$sub_name: \$featureNumber is $featureNumber");
            last;
        }
    }
    unless ($featureNumber) {
        $logger->error(__PACKAGE__ . ".$sub_name: $args{-featureName} number for customer group $custgrp does not exist under table DNROUTE");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Get $args{-featureName} number successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$featureNumber]");
    return $featureNumber;
}

=head2 B<resetLine()>

    This function is used to 'out' or 'new' line or both
    Input:
        - Function: ['OUT','NEW']: out then new line (default)
                    ['OUT']: out line
                    ['NEW']: new line
        - Line dial number
        - Line type: 'ANA': line analog (default)
                     'SIP': line SIP
        - Line equipment number (ex: V52 00 0 00 14)
        - New line information: information was used for New line. Include: 
                                    LINEATTR_KEY
                                    XLAPLAN_KEY
                                    RATEAREA_KEY
                                    CUSTGRP
                                    SUBGRP
                                    NCOS
                                    LATANAME
                                Example:
                                    For IBN line: IBN AUTO_GRP 0 0 NILLATA 0
                                    For 1FR line: 3 212_AUTO L212_NILLA_0

=over 6

=item Arguments:

 Mandatory:
        -lineDN
        -lineInfo
 Optional:
        -function
        -lineType (Note: input this field if using OUT or NEW function)
        -len (Note: input this field if using OUT or NEW function)

=item Returns:

        Returns line equipment number - If Passed
        Returns 0 - If Failed

=item Example:

        my %args = (-function => ['OUT','NEW'], -lineDN => '1514004314', -lineType => '', -len => '', -lineInfo => 'IBN AUTO_GRP 0 0');
        $len = $obj->resetLine(%args);

=back

=cut

sub resetLine {
    my ($self, %args) = @_;
    my $sub_name = "resetLine";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ($args{-lineDN}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-lineDN' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (@{$args{-function}} < 3) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-function' does not set properly");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (@{$args{-function}}) {
        @{$args{-function}} = ('OUT', 'NEW');
    }

    unless (@{$args{-function}} == 2) {
        my $flag = 1;
        foreach ('-lineType', '-len') {
            unless ($args{$_}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    my $len = $args{-len};

    unless ($self->execCmd("quit all")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command quit all");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    # my @output = $self->execCmd("imagename");
    # unless(@output){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'imagename'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # my $char;
    # foreach (@output) {
    # if (/using\s+\w{3}(\w).*/) {
    # $char = $1;
    # $logger->debug(__PACKAGE__.".$sub_name: the fourth character is $char");
    # last;
    # }
    # }
    # unless($char){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot get the fourth character from 'imagename' command");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # my @cmd = (
    # 'REP SO_PROMPT_FOR_LTG Y',
    # 'REP SO_PROMPT_FOR_CABLE_PAIR N',
    # 'REP XLAPLAN_RATEAREA_SERVORD_ENABLED MANDATORY_PROMPTS',
    # 'REP SO_PROMPT_FOR_CABLE_PAIR N',
    # 'REP SO_DNC_MODE_TRANSP N',
    # );
    # unless ($char =~ /w/) {
    # unless($self->execCmd("rwok on")){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'rwok on'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # my @output = $self->{conn}->cmd("table ofcvar;format pack");
    # $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
    # unless (@output){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'table ofcvar;format pack'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # for (my $comp = 0; $comp < $#cmd; $comp++) {
    # if ($comp == 3) {
    # @output = $self->{conn}->cmd("table ofceng;format pack");
    # $self->{conn}->waitfor(-match => '/>$/', -timeout => 10);
    # unless (@output){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'table ofceng;format pack'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # }
    # @output = $self->execCmd("$cmd[$comp]");
    # unless(@output){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command '$cmd[$comp]'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # if (grep /Y OR N|Y TO CONFIRM/, @output) {
    # @output = $self->execCmd("Y");
    # unless(@output) {
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'Y' to confirm ");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # if (grep /Y OR N|Y TO CONFIRM/, @output) {
    # unless ($self->execCmd("Y")) {
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'Y' to confirm ");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # }
    # }
    # unless($self->execCmd("abort")){
    # $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'abort'");
    # $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    # return 0;
    # }
    # }
    # }

    unless (grep /SO:/, $self->execCmd("quit all;servord")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot enter SERVORD mode");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # function OUT
    my ($str, $options, @qdn_result);
    if (grep /OUT/, @{$args{-function}}) {
        @qdn_result = $self->execCmd("qdn $args{-lineDN}");
        unless (@qdn_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: QDN is not worked properly");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $str = join("\n", @qdn_result);
        ($options) = ($str =~ /OPTIONS:(.*)/s);
        unless ($options) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get options from 'qdn $args{-lineDN}' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        ($len) = ($str =~ /LINE EQUIPMENT NUMBER:\s+(.+)\s+\n/);
        unless ($len) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get LEN from 'qdn $args{-lineDN}' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if ($options =~ /DPL.*SIP/) {
            $args{-lineType} = 'SIP';
        }
        @output = $self->execCmd("out \$ $args{-lineDN} $len bldn y y y");
        if (grep /INCONSISTENT DATA|ERROR/, @output) {
            unless ($self->execCmd("abort")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot command abort after OUT fail");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot out line $args{-lineDN} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /UNASSIGNED/, $self->execCmd("qdn $args{-lineDN}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Line is not 'unassigned' after OUT");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: OUT line $args{-lineDN} successfully");
    }
    # function NEW
    if (grep /NEW/, @{$args{-function}}) {
        unless ($args{-lineInfo}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-lineInfo' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless ($len) {
            $logger->error(__PACKAGE__ . ".$sub_name: Missing Line equipment number");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless ($args{-lineType} =~ /SIP/i) {
            $options = 'DGT';
        }
        else {
            $options = 'DGT DPL Y 10';
        }

        $self->execCmd("new \$ $args{-lineDN} $args{-lineInfo} \+");
        @output = $self->execCmd("$len $options \$ y y");
        if (grep /INCONSISTENT DATA|ERROR/, @output) {
            unless ($self->execCmd("abort")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot command abort after NEW fail");
            }
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot NEW line $args{-lineDN} ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /LINE EQUIPMENT NUMBER/, $self->execCmd("qdn $args{-lineDN}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Line is unassigned after NEW");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: NEW line $args{-lineDN} successfully");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$len]");
    return $len;
}

=head2 B<clearSwerrTrapGWC()>

    This function clears swerr and trap on GWC before maintenance action. 

=over 6

=item Arguments:

    Mandatory:
        -gwc_ip
        -gwc_user
        -gwc_pwd
    Optional:
        -lab_type

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        my %input = (
                        -gwc_ip => '10.10.1.17',
                        -gwc_user => 'cmtg',
                        -gwc_pwd => 'cmtg', 
                        -lab_type => 'aTCA'
                    );
        $obj->clearSwerrTrapGWC(%input);

=back

=cut

sub clearSwerrTrapGWC {
    my ($self, %args) = @_;
    my $sub_name = "clearSwerrTrapGWC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-gwc_ip', '-gwc_user', '-gwc_pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-lab_type} ||= 'HT';

    my %input = (
        -gwc_ip   => $args{-gwc_ip},
        -gwc_user => $args{-gwc_user},
        -gwc_pwd  => $args{-gwc_pwd},
    );
    unless ($self->loginGWC(%input)) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot login to $args{-gwc_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmd = ('expert', 'swerr', 'expert', 'clear', 'list');
    my @match_pattern = (
        'You are now in EXPERT mode',
        'swerr',
        'You are now in EXPERT mode',
        'clear',
        'list',
    );
    my @failed_reason = (
        'Cannot use expert mode',
        'Cannot execute command swerr',
        'Cannot use expert mode',
        'Cannot execute command clear',
        'Cannot execute command list'
    );
    for (my $i = 0; $i <= $#cmd; $i++) {
        unless (grep /$match_pattern[$i]/, $self->execCmd($cmd[$i])) {
            $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($args{-lab_type} =~ /aTCA/i) {
        @cmd = ('*', 'debug', 'cl', 't');
        @match_pattern = ('GWCUP', 'DEBUG', '.*', '.*');
        @failed_reason = (
            'Cannot return GWCUP mode',
            'Cannot jump in DEBUG mode',
            'Cannot execute command cl',
            'Cannot execute command t',
        );
        for (my $i = 0; $i <= $#cmd; $i++) {
            unless (grep /$match_pattern[$i]/, $self->execCmd($cmd[$i])) {
                $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    unless ($self->execCmd("logout")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'logout' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: clear swerr trap on $args{-gwc_ip} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<dumpSwerrTrapGWC()>

    This function dumps swerr and trap on GWC after maintenance action. 

=over 6

=item Arguments:

    Mandatory:
        -gwc_ip
        -gwc_user
        -gwc_pwd
    Optional:
        -lab_type

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        my %input = (
                        -gwc_ip => '10.10.1.17',
                        -gwc_user => 'cmtg',
                        -gwc_pwd => 'cmtg', 
                        -lab_type => 'aTCA'
                    );
        $obj->dumpSwerrTrapGWC(%input);

=back

=cut

sub dumpSwerrTrapGWC {
    my ($self, %args) = @_;
    my $sub_name = "dumpSwerrTrapGWC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-gwc_ip', '-gwc_user', '-gwc_pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $args{-lab_type} ||= 'HT';

    my %input = (
        -gwc_ip   => $args{-gwc_ip},
        -gwc_user => $args{-gwc_user},
        -gwc_pwd  => $args{-gwc_pwd},
    );
    unless ($self->loginGWC(%input)) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot login to $args{-gwc_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmd = ('expert', 'swerr');
    my @match_pattern = ('You are now in EXPERT mode', 'swerr');
    my @failed_reason = (
        'Cannot use expert mode',
        'Cannot execute command swerr',
    );
    for (my $i = 0; $i <= $#cmd; $i++) {
        unless (grep /$match_pattern[$i]/, $self->execCmd($cmd[$i])) {
            $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @output = $self->execCmd("dump");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'dump'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @swerr;
    my $cnt = 0;
    while ($cnt < @output) {
        if ($output[$cnt] =~ /^SWERR Sequence #\s+\d+\s+$/) {
            push(@swerr, @output[$cnt .. $cnt + 4]);
            $cnt += 4;
        }
        $cnt++;
    }

    my ($str, $trap_act, $trap_inact);
    unless ($args{-lab_type} =~ /aTCA/i) {
        @cmd = ('*', 'debug');
        @match_pattern = ('GWCUP', 'DEBUG');
        @failed_reason = (
            'Cannot return GWCUP mode',
            'Cannot jump in DEBUG mode',
        );
        for (my $i = 0; $i <= $#cmd; $i++) {
            unless (grep /$match_pattern[$i]/, $self->execCmd($cmd[$i])) {
                $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        @output = $self->execCmd("t");
        unless (@output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 't'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $str = join("\n", @output);
        ($trap_act) = ($str =~ /REGION 0 :.*traps.*Active/);
        ($trap_inact) = ($str =~ /REGION 1 :.*tr/);

        @cmd = ('Last', '*');
        @match_pattern = ('Trapinfo', 'GWCUP');
        @failed_reason = (
            'Cannot execute command Last',
            'Cannot return GWCUP mode',
        );
        for (my $i = 0; $i <= $#cmd; $i++) {
            unless (grep /$match_pattern[$i]/, $self->execCmd($cmd[$i])) {
                $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    unless ($self->execCmd("logout")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'logout' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep /SWERR Sequence/, @swerr) {
        $logger->error(__PACKAGE__ . ".$sub_name: there are some swerrs on GWC $args{-gwc_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: swerr on GWC " . Dumper(\@swerr));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ($trap_act || $trap_inact) {
        $logger->error(__PACKAGE__ . ".$sub_name: there are some traps on GWC $args{-gwc_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: trap on GWC " . Dumper(\@output));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: clear swerr trap on $args{-gwc_ip} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<loginGWC()>

    This function telnets to login to a element with IP

=over 6

=item Arguments:

    Mandatory:
        -gwc_ip
        -gwc_user
        -gwc_pwd

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        my %input = (
                        -gwc_ip => '10.10.1.17',
                        -gwc_user => 'cmtg',
                        -gwc_pwd => 'cmtg', 
                    );
        $obj->loginGWC(%input);

=back

=cut

sub loginGWC {
    my ($self, %args) = @_;
    my $sub_name = "loginGWC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-gwc_ip', '-gwc_user', '-gwc_pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if (grep /cli/, $self->execCmd("")) {
        unless ($self->execCmd("sh")) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot execute command 'sh'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $self->{conn}->print("telnet $args{-gwc_ip}");
    sleep(5);
    unless ($self->{conn}->waitfor(-match => '/login\:\s?/', -timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: cannot telnet $args{-gwc_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmd = ("$args{-gwc_user}", "$args{-gwc_pwd}", "");
    my @match_pattern = ('/assword\:\s*/', '/GWCUP>/', '/GWCUP>\s?$/');
    my @failed_reason = (
        'gwc_user may be wrong',
        'gwc_password may be wrong',
        'GWCUP is not ready',
    );
    for (my $i = 0; $i <= $#failed_reason; $i++) {
        $self->{conn}->print($cmd[$i]);
        unless ($self->{conn}->waitfor(-match => $match_pattern[$i], -timeout => 10)) {
            $logger->error(__PACKAGE__ . ".$sub_name: $failed_reason[$i]");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<getTableInfo()>

    This function returns info of specific table.

=over 6

=item Arguments:

    Mandatory:
        -table_name
    Optional:
        -column_name
        -column_value

=item Returns:

        Returns table info - If Passed
        Returns empty array - If Failed

=item Example:

        my %input = (
                        -table_name => 'TRKMEM',
                        -column_name => 'CLLI',
                        -column_value => 'T2MG6PRIQSIG2W', 
                    );
        $obj->getTableInfo(%input);

=back

=cut

sub getTableInfo {
    my ($self, %args) = @_;
    my $sub_name = "getTableInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ($args{-table_name}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-table_name' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    if (grep /UNKNOWN/, $self->execCmd("table $args{-table_name}")) {
        unless ($self->execCmd("abort")) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot command 'abort'");
        }
        $logger->error(__PACKAGE__ . ".$sub_name: table $args{-table_name} is unknown");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    $self->{conn}->print("format pack");
    unless ($self->{conn}->waitfor(-match => '/>$/', -timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'format pack'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    my (@output, $cmd);
    if (!$args{-column_name} && $args{-column_value}) {
        @output = $self->execCmd("pos $args{-column_value}");
        unless (@output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'pos $args{-column_value}'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }
    else {
        $cmd = "lis all";
        $cmd .= " \($args{-column_name} eq '$args{-column_value}'\)" if ($args{-column_name} && $args{-column_value});
        @output = $self->execCmd($cmd);
        unless (grep /BOTTOM/, @output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'lis all '");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }

    unless ($self->execCmd("quit")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return @output;
}

=head2 B<startTapiTerm()>

    This function enables Tapi/Term trace using gwctraci on Core with unlimited numbers of GWCs but it only supports for level 2.
    Input:
        - List Core username
        - List Core password
        - Testbed
        - GWC user name
        - GWC password
        - List dialed number: is used for getting tapi/term trace on Line GWC. All DNs must be on the same lab.
        - List Trunk CLLI: is used for getting tapi/term trace on Trunk GWC. All CLLI trunk names must be on the same lab.
    Output:
        - GWC_ID, GWC_IP and Terminal number: this output is used for stopTapiTerm() function.

=over 6

=item Arguments:

    Mandatory:
        -username: Core username
        -password: Core password
        -testbed
        -gwc_user
        -gwc_pwd
    Optional:
        -list_dn
        -list_trk_clli

=item Returns:

        Returns output for stopTapiTerm function - If Passed
            Ex: %args = (
                        3 =>  { 
                                -gwc_ip => '10.250.41.20',
                                -terminal_num => ['22 17','22 18'],
                                -int_term_num => [4411, 4412],
                                },
                        15 => {
                                -gwc_ip => '10.250.41.28',
                                -terminal_num => ['23 05'],
                                -int_term_num => [4315],
                                },
                        4 => {
                                -gwc_ip => '10.250.41.32',
                                -terminal_num => [],
                                -int_term_num => [1805,1806],
                                },
                        )
        Returns empty hash - If Failed

=item Example:

        my %input = (
                        -username => ['testshell1', 'testshell2'],
                        -password => ['automation', 'automation'],
                        -testbed => $TESTBED{"c20:1:ce0"},
                        -gwc_user => 'cmtg',
                        -gwc_pwd => 'cmtg',
                        -list_dn => [1514004314, 1514004315],
                        -list_trk_clli => ['T2MG6PRIQSIG2W', 'T2G6STM1C7ANSI2W'],
                    );
        $obj->startTapiTerm(%input);

=back

=cut

sub startTapiTerm {
    my ($self, %args) = @_;
    my $sub_name = "startTapiTerm";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-username', '-password', '-gwc_user', '-gwc_pwd', '-testbed') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    # Login Core
    unless ($self->loginCore(%args{-username}, %args{-password})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot login to Core ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    unless (grep /GWCDEBUG:/, $self->execCmd("gwcdebug")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'gwcdebug' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    my @output = $self->execCmd("show all");
    unless (grep /GWC/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'show all'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    my %gwc_info;
    foreach (@output) {
        if (/GWC\s+(\d+)\s.*INSV.*\s(\d+\.\d+\.\d+\.\d+)/) {
            $gwc_info{$1} = $2;
        }
    }

    # Get line terminal number
    my ($len, $pm_num, $gwc_id, %input, %info_for_stop);
    if ($args{-list_dn}) {
        for (my $i = 0; $i <= $#{$args{-list_dn}}; $i++) {
            @output = $self->execCmd("qdn $args{-list_dn}[$i]");
            unless (@output) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'qdn $args{-list_dn}[$i]' ");
                $flag = 0;
                last;
            }
            foreach (@output) {
                if (/LINE EQUIPMENT NUMBER:\s+(.+)\s+$/) {
                    $len = $1;
                }
                if (/PM NODE NUMBER.*\s(\d+)/) {
                    $pm_num = "$1 ";
                }
                if (/PM TERMINAL NUMBER.*\s(\d+)/) {
                    $pm_num .= $1;
                    last;
                }
            }
            %input = (
                -table_name   => 'LGRPINV',
                -column_name  => '',
                -column_value => $len,
            );
            @output = $self->getTableInfo(%input);
            unless (grep /GWC/, @output) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot pos LEN of DN $args{-list_dn}[$i] in table LGRPINV to get GWC ID");
                $flag = 0;
                last;
            }
            foreach (@output) {
                if (/GWC\s+(\d+)/) {
                    $gwc_id = $1;
                    last;
                }
            }

            unless (exists($info_for_stop{$gwc_id})) { # check GWC_id existence, if yes just add $pm_num to -terminal_num
                $info_for_stop{$gwc_id} = { -gwc_ip => $gwc_info{$gwc_id}, -terminal_num => [ $pm_num ], -int_term_num => [] };
            }
            else {
                push(@{$info_for_stop{$gwc_id}{-terminal_num}}, $pm_num);
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }

        # Login to each GWC to get INTERNAL TERMINAL NUMBER
        my $ses_gwc;
        unless ($ses_gwc = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $args{-testbed}, -sessionLog => "$sub_name\_GWCSessionLog")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Could not create C20 object for tms_alias => $args{-testbed}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
        $ses_gwc->{conn}->prompt('/[\>\$]\s?$/');
        foreach my $id (keys %info_for_stop) {
            %input = (
                -gwc_ip   => $info_for_stop{$id}{-gwc_ip},
                -gwc_user => $args{-gwc_user},
                -gwc_pwd  => $args{-gwc_pwd},
            );
            unless ($ses_gwc->loginGWC(%input)) {
                $logger->error(__PACKAGE__ . ".$sub_name: cannot login to $info_for_stop{$id}{-gwc_ip}");
                $flag = 0;
                last;
            }
            unless (grep /You are now in EXPERT mode/, $ses_gwc->execCmd("expert")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'expert'");
                $flag = 0;
                last;
            }

            foreach my $term_num (@{$info_for_stop{$id}{-terminal_num}}) {
                @output = $ses_gwc->execCmd("cp e $term_num");
                unless (grep /cp e/, @output) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'cp e $term_num'");
                    $flag = 0;
                    last;
                }
                foreach (@output) {
                    if (/INTERNAL TERMINAL NUMBER.*\s(\d+)/) {
                        push(@{$info_for_stop{$id}{-int_term_num}}, $1);
                        last;
                    }
                }
                unless ($ses_gwc->execCmd('**')) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot return to GWCUP mode");
                    $flag = 0;
                    last;
                }
            }
            unless ($flag) {
                last;
            }
            unless ($ses_gwc->execCmd("logout")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'logout' ");
                $flag = 0;
                last;
            }
        }
        $ses_gwc->DESTROY();
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }

    # Get Trunk terminal number
    my ($aud_id, $aud_gwc_id);
    if ($args{-list_trk_clli}) {
        for (my $i = 0; $i <= $#{$args{-list_trk_clli}}; $i++) {
            %input = (
                -table_name   => 'TRKMEM',
                -column_name  => 'CLLI',
                -column_value => $args{-list_trk_clli}[$i],
            );
            @output = $self->getTableInfo(%input);
            unless (@output) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot pos CLLI $args{-list_trk_clli}[$i] in table TRKMEM to get MEMVAR");
                $flag = 0;
                last;
            }
            if (grep /GWC/, @output) {
                foreach (@output) {
                    if (/GWC\s+(\d+).*\s(\d+)\s*$/) {
                        $gwc_id = $1;
                        unless (exists($info_for_stop{$gwc_id})) { # check GWC_id existence, if yes just add to -int_term_num
                            $info_for_stop{$gwc_id} = {
                                -gwc_ip       => $gwc_info{$gwc_id},
                                -terminal_num => [],
                                -int_term_num => [ $2 ]
                            };
                        }
                        else {
                            push(@{$info_for_stop{$gwc_id}{-int_term_num}}, $2);
                        }
                    }
                }
                # add one more -int_term_num by increasing the last value with 1
                push(@{$info_for_stop{$gwc_id}{-int_term_num}}, $info_for_stop{$gwc_id}{-int_term_num}[-1] + 1);
            }
            else {
                # CLLI is not a trunk name
                %input = (
                    -table_name   => 'ANNMEMS',
                    -column_name  => 'ANNMEM',
                    -column_value => "$args{-list_trk_clli}[$i] \*",
                );
                @output = $self->getTableInfo(%input);
                unless (@output) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot pos CLLI $args{-list_trk_clli}[$i] in table ANNMEM");
                    $flag = 0;
                    last;
                }
                foreach (@output) {
                    if (/AUD\s+(\d+)\s*$/) {
                        $aud_id = $1;
                        last;
                    }
                }
                %input = (
                    -table_name   => 'SERVSINV',
                    -column_name  => '',
                    -column_value => '',
                );
                @output = $self->getTableInfo(%input);
                unless (@output) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot get all tuple in table SERVSINV");
                    $flag = 0;
                    last;
                }
                foreach (@output) {
                    if (/\s$aud_id\s+GWC\s+(\d+)\s/) {
                        $aud_gwc_id = $1;
                        last;
                    }
                }
                unless (exists($info_for_stop{$aud_gwc_id})) { # check GWC_id existence, if yes just add to -int_term_num
                    $info_for_stop{$aud_gwc_id} = {
                        -gwc_ip       => $gwc_info{$aud_gwc_id},
                        -terminal_num => [],
                        -int_term_num => [ '0', '32766' ],
                    };
                }
                else {
                    unless (grep /32766/, @{$info_for_stop{$aud_gwc_id}{-int_term_num}}) {
                        push(@{$info_for_stop{$aud_gwc_id}{-int_term_num}}, ('0', '32766'));
                    }
                }
            }
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
            return ();
        }
    }

    # Enable tapiterm on Core
    unless (keys %info_for_stop) {
        $logger->error(__PACKAGE__ . ".$sub_name: No ternimal number for tapiterm ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    @output = $self->execCmd("gwctraci");
    unless (grep /GWCTRACI:/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'gwctraci' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    if (grep /count exceeded/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot use 'gwctraci' due to 'count exceeded' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    my ($min, $max);
    foreach my $id (keys %info_for_stop) {
        $min = min @{$info_for_stop{$id}{-int_term_num}};
        $max = max @{$info_for_stop{$id}{-int_term_num}};
        @output = $self->execCmd("define both gwc $id $min $max");
        unless (@output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'define both gwc $id $min $max' ");
            $flag = 0;
            last;
        }
        if (grep /This will clear existing trace buffers/, @output) {
            unless ($self->execCmd("y")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'y' ");
                $flag = 0;
                last;
            }
        }
        unless ($self->execCmd("enable both gwc $id")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'enable both gwc $id' ");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return %info_for_stop;
}

=head2 B<stopTapiTerm()>

    This function disables TapiTerm trace using gwctraci on Core with unlimited numbers of GWCs but it only supports for level 2.
    Input:
        - Testbed
        - GWC user name
        - GWC password
        - Log file path
        - Terminal number: Output from function startTapiTerm
        - TC ID: use for log file name
    Output:
        - list of Tapi/Term trace output: this output is used for stopTapiTerm() function.

=over 6

=item Arguments:

    Mandatory:
        -testbed
        -gwc_user
        -gwc_pwd
        -terminal_num
    Optional:
        -log_path
        -tcid
        

=item Returns:

        Returns list for Tapi/Term trace output - If Passed
            Ex: %tapiterm_output = {
                                    '3' => {
                                            '1805' => 'term trace ......',
                                            '1806' => 'term trace.......',
                                            },
                                    '4' => {
                                            '4411' => 'tapi trace ......',
                                            '4412' => 'tapi trace ......',
                                            },
                                    '15' => '-entire' => 'term trace .....',
                                    }
        Returns empty hash - If Failed

=item Example:
        my %info = $obj->startTapiTerm(%args);
        my %input = (
                        -testbed => $TESTBED{"c20:1:ce0"},
                        -gwc_user => 'cmtg',
                        -gwc_pwd => 'cmtg',
                        -log_path => '/home/ptthuy/PCM/',
                        -term_num => \%info,
                        -tcid => 'TC_001',
                    );
        $obj->stopTapiTerm(%input);

=back

=cut

sub stopTapiTerm {
    my ($self, %args) = @_;
    my $sub_name = "stopTapiTerm";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my %info = %{$args{-term_num}};
    my $flag = 1;
    foreach ('-gwc_user', '-gwc_pwd', '-testbed', '-term_num') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    $args{-log_path} ||= '/home/ptthuy/TapiTerm';

    # Disable trace on GWC
    unless (grep /GWCTRACI/, $self->execCmd("gwctraci")) {
        $logger->error(__PACKAGE__ . ".$sub_name: it is not in gwctraci mode ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    $self->{conn}->waitfor(-match => '/>$|Warning/', -timeout => 10);
    foreach (keys %info) {
        unless ($self->execCmd("disable both gwc $_")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'disable both gwc $_' ");
            $flag = 0;
            last;
        }
    }
    sleep(5); # wait for disabling trace completely

    # Login each GWC to get Tapi/Term trace output.
    my ($ses_gwc, %input, @output, %tapiterm_output);
    my $n_flag = 1;
    unless ($ses_gwc = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $args{-testbed}, -sessionLog => "$args{-tcid}\_$sub_name\_GWCSessionLog")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not create C20 object for tms_alias => $args{-testbed}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    $ses_gwc->{conn}->prompt('/[\>\$]\s?$/');
    foreach my $id (keys %info) {
        %input = (
            -gwc_ip   => $info{$id}{-gwc_ip},
            -gwc_user => $args{-gwc_user},
            -gwc_pwd  => $args{-gwc_pwd},
        );
        unless ($ses_gwc->loginGWC(%input)) {
            $logger->error(__PACKAGE__ . ".$sub_name: cannot login to $info{$id}{-gwc_ip}");
            $flag = 0;
            last;
        }
        unless (grep /You are now in EXPERT mode/, $ses_gwc->execCmd("expert")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'expert'");
            $flag = 0;
            last;
        }
        unless (grep /trm/, $ses_gwc->execCmd("trm")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'trm'");
            $flag = 0;
            last;
        }

        if (@{$info{$id}{-int_term_num}} == 1) {
            foreach (@{$info{$id}{-int_term_num}}) {
                if ($_ >= 0 && $_ <= 32766) {
                    $n_flag = 0;
                    last;
                }
            }
        }

        unless ($n_flag) {
            @output = $ses_gwc->execCmd("print dump 0 32766");
            unless (@output) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'print dump 0 32766'");
                $flag = 0;
                last;
            }
            push(@{$tapiterm_output{$id}{'entire'}}, @output);
            unless ($ses_gwc->execCmd("\*")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot return Trmtrc mode");
                $flag = 0;
                last;
            }
        }
        else {
            foreach (@{$info{$id}{-int_term_num}}) {
                @output = $ses_gwc->execCmd("print dump $_ $_");
                unless (@output) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'print dump 0 32766'");
                    $flag = 0;
                    last;
                }
                push(@{$tapiterm_output{$id}{$_}}, @output);
                unless ($ses_gwc->execCmd("\*")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot return Trmtrc mode");
                    $flag = 0;
                    last;
                }
            }
            unless ($flag) {
                last;
            }
        }

        foreach ("kill", '**', "calls tapi") {
            unless ($ses_gwc->execCmd($_)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$_'");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            last;
        }
        $ses_gwc->{conn}->prompt('/TApi_trace\>\s?$/');
        unless ($n_flag) {
            @output = $ses_gwc->execCmd("dumpall"); #DUMPTn 0 32766
            unless (@output) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'DUMPTn 0 32766'");
                $flag = 0;
                last;
            }
            push(@{$tapiterm_output{$id}{'entire'}}, @output);
        }
        else {
            foreach (@{$info{$id}{-int_term_num}}) {
                @output = $ses_gwc->execCmd("DUMPTn $_ $_");
                unless (@output) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'DUMPTn $_ $_'");
                    $flag = 0;
                    last;
                }
                push(@{$tapiterm_output{$id}{$_}}, @output);
            }
            unless ($flag) {
                last;
            }
        }
        $ses_gwc->{conn}->prompt('/[\>\$]\s?$/');
        foreach ("kill", '**', "logout") {
            unless ($ses_gwc->execCmd($_)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$_'");
                $flag = 0;
                last;
            }
        }
        unless ($flag) {
            last;
        }
    }
    $ses_gwc->DESTROY();
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    #quit gwctraci
    @output = $self->execCmd("quit");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return ();
    }
    if (grep /Please confirm/, @output) {
        unless ($self->execCmd("Y")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'Y' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
            return ();
        }
    }

    # Get tapi/term trace Log
    my ($new_trace_log, $str);
    foreach my $id (keys %tapiterm_output) {
        foreach my $tn (keys %{$tapiterm_output{$id}}) {
            if (@{$tapiterm_output{$id}{$tn}} > 40) {
                $new_trace_log = $args{-log_path} . "GWC$id\_TN$tn\.log";
                unless (open(OUT, ">$new_trace_log")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: open $new_trace_log failed ");
                    $flag = 0;
                    last;
                }
                $str = join("\n", @{$tapiterm_output{$id}{$tn}});
                print OUT $str;
            }
            else {
                delete $tapiterm_output{$id}{$tn};
            }
        }
        unless ($flag) {
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return %tapiterm_output;
}

=head2 B<verifyTapi()>

    This function verifies some info in tapi/term trace
    Input:
        - list tapi/term trace log
        - Timeout: the timeout needs to verify
        - Verified information: the info needs to verify
            -'collectdigit' : Collect digits which used to dial plan
            -'timeout': get timeout which showed in tapi log
            -'cycletime': Get period time between two times play cwt tone.
        - Tone type: Input the type of tone need to verify
            Ex: 'cw' : call waiting tone
    Output:
        - Output result time out: Output of the time out was got in Trace logs.
        - Collected digits: Collected digits in Trace logs
        - Tone pattern 1: Contain message tone pattern 1
        - Tone pattern 2: Contain message tone pattern 2
        - Tone cycle time: Contain the perior time between two times play tone

=over 6

=item Arguments:

    Mandatory:
        -trace_log
    Optional:
        -timeout
        -verified_info
        -tone_type  

=item Returns:

        Returns list of verified results - If Passed
            Ex: %verified_result = {
                                    -timeout_result => [],
                                    -collected_digits => '671',
                                    -tone_pattern1 => [],
                                    -tone_pattern1 => [],
                                    -tone_cycle_time => [],
                                    }
        Returns empty hash - If Failed

=item Example:

        my @trace_log = (
                        'print dump 4411 4411 ......',
                        ...
                        'print dump 4412 4412 ......',
                        ...
                        'print dump 126 126 ......',
                        ...
                        );
        my %input = (
                        -trace_log => [@trace_log],
                        -timeout => 20,
                        -verified_info => ['collectdigit','timeout'],
                        -tone_type => 'cw',
                    );
        $obj->verifyTapi(%input);

=back

=cut

sub verifyTapi {
    my ($self, %args) = @_;
    my $sub_name = "verifyTapi";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless (@{$args{-trace_log}}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-trace_log' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }
    my %verified_result;

    # Verify timeout
    if (grep /timeout/, @{$args{-verified_info}}) {
        $args{-timeout} ||= 0;
        foreach (@{$args{-trace_log}}) {
            if (/(.*DM=\{T:$args{-timeout}.*)/) {
                push(@{$verified_result{-timeout_result}}, $1);
            }
        }
    }

    # Verify collected digits
    my @line_digits;
    if (grep /collectdigit/, @{$args{-verified_info}}) {
        foreach (@{$args{-trace_log}}) {
            if (/(.*XDD\/XCE[\s]*\{[\s]*DS[\s]*=[\s]*\"[0-9-\#-\*]*\".*)/) {
                push(@line_digits, $1);
            }
        }
        foreach (@line_digits) {
            if (/DS=\"([0-9-\#-\*]*)\"/) {
                $verified_result{-collected_digits} .= $1;
            }
            if (/EXTRA[\s]*=[\s]*"([0-9-\#-\*]*)"/) {
                $verified_result{-collected_digits} .= $1;
            }
        }
    }

    # Verify cycle time
    my ($str, $index, %input);
    $verified_result{-tone_pattern1} = [ '' ];
    $verified_result{-tone_pattern2} = [ '' ];
    if (grep /cycletime/, @{$args{-verified_info}}) {
        for (my $i = 0; $i <= $#{$args{-trace_log}}; $i++) {
            if ($args{-trace_log}[$i] =~ /(.*alert\/[$args{-tone_type}]*\{patte.*rn=1.*)/) {
                $verified_result{-tone_pattern1}[$index] = "$args{-trace_log}[$i - 1]\n" . $1;
                $index++;
            }
            if ($args{-trace_log}[$i] =~ /(.*alert\/[$args{-tone_type}]*\{patte.*rn=2.*)/) {
                $verified_result{-tone_pattern2}[$index] = "$args{-trace_log}[$i - 1]\n" . $1;
                $index++;
            }
        }
        %input = (
            -tone_pattern1 => [ @{$verified_result{-tone_pattern1}} ],
            -tone_pattern2 => [ @{$verified_result{-tone_pattern2}} ],
        );
        @{$verified_result{-tone_cycle_time}} = $self->getToneCycleTime(%input);
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return %verified_result;
}

=head2 B<getToneCycleTime()>

    This function returns list of tone cycle times.

=over 6

=item Arguments:

    Optional:
        - tone pattern 1 from trace log
        - tone pattern 2 from trace log

=item Returns:

        Returns list of tone cycle times - If Passed
        Returns empty array - If Failed

=item Example:

        @tone_pattern1 = (
                        '000:08:42:32.07[...alert\ri{pattern=1...',
                        '000:08:43:24.76[...alert\ri{pattern=1...',
                        '000:08:49:11.22[...alert\ri{pattern=1...',
                        );
        @tone_pattern2 = (
                        '000:08:50:32.07[...alert\ri{pattern=2...',
                        '000:08:52:24.76[...alert\ri{pattern=2...',
                        '000:09:00:11.22[...alert\ri{pattern=2...',
                        );
        $obj->getToneCycleTime(-tone_pattern1 => [@tone_pattern1], -tone_pattern2 => [@tone_pattern2)];

=back

=cut


sub getToneCycleTime {
    my ($self, %args) = @_;
    my $sub_name = "getToneCycleTime";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@list_hour, @list_min, @list_sec, $temp, $str_time, @tone_cycle_time);
    foreach my $tp ('-tone_pattern1', '-tone_pattern2') {
        foreach (@{$args{$tp}}) {
            if (/\:(\d{2})\:(\d{2})\:(\d{2}\.\d{2})\[.*/) {
                push(@list_hour, $1);
                push(@list_min, $2);
                push(@list_sec, $3);
            }
        }
    }

    if (@list_hour > 1) {
        for (my $i = 0; $i <= $#list_hour - 1; $i++) {
            $temp = $list_sec[$i + 1] - $list_sec[$i];
            if ($temp < 0) {
                $temp = 60 + $temp;
                $list_min[$i + 1]--;
            }
            $str_time = $temp;

            $temp = $list_min[$i + 1] - $list_min[$i];
            if ($temp < 0) {
                $temp = 60 + $temp;
                $list_hour[$i + 1]--;
            }
            $str_time = "$temp\:" . $str_time;

            $temp = $list_hour[$i + 1] - $list_hour[$i];
            $str_time = "$temp\:" . $str_time;
            push(@tone_cycle_time, $str_time);
        }
    }

    unless (@tone_cycle_time) {
        $logger->error(__PACKAGE__ . ".$sub_name: do not get any tone cycle times");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return ();
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return @tone_cycle_time;
}


=head2 startGVBMLogs()

=over

=item DESCRIPTION:

    This subroutine is made generic to start capturing GVBM logs (messages, informational, raosend, swadm.log)

=item ARGUMENTS:

   Mandatory:
    -logType	=> Type of log: swadm.log, messages, informational or raosend.
    -tcId 		=> Testcase ID
    -outputDes 		=> Output Destination
	
=item Returns:

        $self->{'LOG_FILE'}: used to verify log.

=item EXAMPLE:

    $logFile = $obj->startGVBMLogs(-logType => "swadm.log", -tcId => "TC001");

Note: If the  log type is raosend, -outputDes is mandatory.

	$logFile = $obj->startGVBMLogs(-logType => "raosend", -tcId => "TC001", -outputDes => "Bill17");
	
=back

=cut

sub startGVBMLogs {
    my ($self, %args) = @_;
    my $sub_name = "startGVBMLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach ('-logType', '-tcId') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($args{-logType} =~ /raosend/) {
        unless ($args{-outputDes}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-outputDes' not present");
            $flag = 0;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if ($args{-logType} =~ /messages|informational|raosend/) {
        $self->{'LOG_PATH'} = "/telesci/logs/";
    }
    elsif ($args{-logType} =~ /swadm.log/) {
        $self->{'LOG_PATH'} = "/var/log/ccm/";
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Invalid type of log");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my ($datestamp, $cmd);

    if ($args{-logType} =~ /raosend/) {
        $datestamp = sprintf "%4d%02d%02d", $year + 1900, $mon + 1, $mday;
        $self->{'LOG_FILE'} = $args{-tcId} . "_" . $datestamp;
        $cmd = "tail -f $self->{'LOG_PATH'}$args{-logType}_$args{-outputDes}_$datestamp.log | tee $self->{'LOG_PATH'}$self->{'LOG_FILE'} > /dev/null &";
    }
    else {
        $datestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
        $self->{'LOG_FILE'} = $args{-tcId} . "_" . $args{-logType} . "_" . $datestamp;
        $cmd = "tail -f $self->{'LOG_PATH'}$args{-logType} | tee $self->{'LOG_PATH'}$self->{'LOG_FILE'} > /dev/null &";
    }

    $self->{conn}->prompt('/.*\]#.*$/');

    my $cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Start capturing $args{-logType} log: $self->{'LOG_FILE'}");
    unless (($cmd_result) = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to capture $args{-logType} log");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->{PROCESS_ID} = $1 if ($cmd_result =~ /\[\d\]\s+(.+)\s*/);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$self->{'LOG_FILE'}]");
    return $self->{'LOG_FILE'};
}

=head2 stopGVBMLogs()

=over

=item DESCRIPTION:

    This subroutine is used to stop capturing GVBM logs

=item ARGUMENTS:

=item PACKAGE:

    SonusQA::C20

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $obj->stopGVBMLogs();

=back

=cut

sub stopGVBMLogs {
    my ($self) = @_;
    my $sub_name = "stopGVBMLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Killing the process");
    unless (@cmd_result = $self->execCmd("kill -9 $self->{PROCESS_ID}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to kill the process $self->{PROCESS_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $cmd = "cat $self->{'LOG_PATH'}$self->{'LOG_FILE'}";
    $logger->debug(__PACKAGE__ . ".$sub_name: Executing command $cmd");
    unless ($self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  COMMAND EXECTION ERROR OCCURRED");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $cmd = "rm -f $self->{'LOG_PATH'}$self->{'LOG_FILE'}";
    $logger->debug(__PACKAGE__ . ".$sub_name: Executing command $cmd");
    unless ($self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  COMMAND EXECTION ERROR OCCURRED");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 exportAMAFile()

=over

=item DESCRIPTION:

    This subroutine is used to export ama file.

=item ARGUMENTS:
    Mandatory: 
                -ndmSession: this session is on Core.
                -cbmgSession: this session is on CBMG
                -dn : list of calling DN
                -tcId: tcid

=item PACKAGE:

    SonusQA::C20

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:
    %args = (-ndmSession => $ndmSession,
             -cbmgSession => $cbmgSession,
             -dn => ['6468310000']
             -tcId => 'TC001',
             );
    $amaFilePath = &SonusQA::C20::exportAMAFile(%args);
    *** Note ***: Have to 'clear ama' before using this function
=back

=cut

sub exportAMAFile {
    my (%args) = @_;
    my $sub = "exportAMAFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $flag = 1;
    foreach ('-ndmSession', '-cbmgSession', '-dn', '-tcId') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);

    ## get connect time value in NDM session 
    my @openAmaOutput = $args{-ndmSession}->execCmd("open amab;back all");
    unless (grep /CONNECT TIME/, @openAmaOutput) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute command 'open amab;back all' in NDM session. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my @cntTimeValue = ();
    my $tmp;
    for (@openAmaOutput) {
        if (/CONNECT TIME\s*\=\s*(\d\d*)\s*/) {
            $tmp = $1;
            next;
        }
        if (/CALLING DN\s*\=\s*(\d\d*)\s*/) {
            if (grep /^$1$/, @{$args{-dn}}) {
                push(@cntTimeValue, $tmp);
            }
        }
    }
    @cntTimeValue = uniq(@cntTimeValue);
    $logger->info(__PACKAGE__ . ".$sub: Connect time values from calling DN is: " . Dumper(\@cntTimeValue));

    ## Dump ama value in CBMG session
    if (grep /No such file or directory/, $args{-cbmgSession}->execCmd("cd /opt/data/cbmg/sba/ama/open")) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute command 'cd /opt/data/cbmg/sba/ama/open' in CBMG session. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my @amaFileName;
    unless (grep /AMA/, @amaFileName = $args{-cbmgSession}->execCmd("ls")) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to find AMA file in CBMG session. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $args{-cbmgSession}->{conn}->prompt('/AMADUMP>>\s*\r*(\x02)*(AMADUMP>>)*|More...\s*\r*(\x02)*(More...)*/');
    unless ($args{-cbmgSession}->execCmd("amadump ama")) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute command 'amadump ama' in CBMG session. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my $dumpCmd;
    for (my $i = 0; $i <= $#cntTimeValue; $i++) {
        my $cnt = 9 - $i;
        unless (grep /Successful addition/, $args{-cbmgSession}->execCmd("filter add $cnt CONNECT_TIME == \"$cntTimeValue[$i]\"")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute command: filter add $cnt CONNECT_TIME == \"$cntTimeValue[$i]\" in CBMG session. ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
        if ($i == 0) {
            $dumpCmd = "dump details sum fNAME $amaFileName[0] filter \"" . "%$cnt";
            next;
        }
        $dumpCmd = $dumpCmd . " || %$cnt";
    }
    $dumpCmd = $dumpCmd . "\"";
    return 0 unless ($flag);

    my @result = ();
    unless (@result = $args{-cbmgSession}->execCmd($dumpCmd)) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute command '$dumpCmd' in CBMG session. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    # execute 'enter' command to get full output
    my @enterOutput;
    for (my $i = 0; $i < 20; $i++) {
        unless (@enterOutput = $args{-cbmgSession}->execCmd("")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute ($i+1)st/nd 'enter' command  ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
        push(@result, @enterOutput);
        last if (grep /Total_Records_Searched/, @enterOutput);
    }
    return 0 unless ($flag);

    $logger->debug(__PACKAGE__ . ".$sub: <-- Output result: " . Dumper(\@result));
    $args{-cbmgSession}->{conn}->prompt($args{-cbmgSession}->{PROMPT});

    #write to file
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $datestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;

    my @path = split(/\/\w*\-\w*/, $args{-cbmgSession}->{sessionLog2});

    my $amaFilePath = $path[0] . "/" . $args{-tcId} . "_AMABilling_" . $datestamp . ".txt";
    unless (open(OUT, ">$amaFilePath")) {
        $logger->error(__PACKAGE__ . ".$sub: Open $amaFilePath failed ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    for (@result) {
        if (/Record data:/) {
            $flag = 0;
        }
        if ($flag == 0) {
            print OUT $_;
            print OUT "\n";
        }
    }
    close OUT;

    $logger->info(__PACKAGE__ . ".$sub: <-- Completed export ama billing file successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$amaFilePath]");
    return $amaFilePath;
}

=head2 B<suMtcOneUnit()>		
    This function perform action (load/lock/unload/unlock/swact) on MTC Service Units. 		
=over 6		
=item Arguments:		
   Mandatory:		
    -action	: Action to perform on MTC Service Units.		
    -SU 	: Service Unit name		
   Optional:		
    -unit 	: Unit index (0/1). 0 by default.		
    -seti	: set i flag. n by default.		
=item Returns:		
        Returns 1 - If Passed		
        Returns 0 - If Failed		
=item Example:		
     my %args;		
     $args{-action}      = "load";		
     $args{-SU}    = "VCA";		
     $args{-unit}    = "0";		
     $args{-seti}  = "n";		
     		
=back		
=cut		
sub suMtcOneUnit {
    my ($self, %args) = @_;
    my $sub_name = "suMtcOneUnit";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $args{-seti} = $args{-seti} || "n";
    $args{-unit} = $args{-unit} || 0;

    my (@cmd_result);
    my ($active_unit, $active_unit1, $command_result, $unit_info);
    my $flag = 1;
    $self->{conn}->print("cli");
    unless ($self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'cli' ");
        return 0;
    }
    if (grep /sg to query does not exist/, $self->execCmd("aim service-unit show $args{-SU}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: $args{-SU} does not exist in the database");
        $flag = 0;
        goto EXIT;
    }

    if ($args{-action} =~ /swact/) {
        unless (grep /su/, @cmd_result = $self->execCmd("aim si-assignment show $args{-SU}")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'aim si-assignment show $args{-SU}' ");
            $flag = 0;
            goto EXIT;
        }
        for (@cmd_result) {
            $active_unit = $1 if $_ =~ m/$args{-SU}\s+(\d+).*active/;
        }
        unless (defined $active_unit) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get active unit ");
            $flag = 0;
            goto EXIT;
        }
        my $cmd = ($args{-seti} =~ /y/) ? "aim service-unit $args{-action} $args{-SU} $active_unit i" : "aim service-unit $args{-action} $args{-SU} $active_unit";
        if (grep /\%Error/, @cmd_result = $self->execCmd($cmd, 180)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
            $flag = 0;
            goto EXIT;
        }

        if (grep /continue\?/, @cmd_result) {
            if (grep /\%Error/, $self->execCmd("y", 180)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot confirm continue");
                $flag = 0;
                goto EXIT;
            }
        }
    }
    elsif ($args{-action} =~ /^lock|unlock|^load|unload/) {
        if ($args{-action} =~ /lock/) {
            my $cmd = ($args{-seti} =~ /y/) ? "aim service-unit $args{-action} $args{-SU} $args{-unit} i" : "aim service-unit $args{-action} $args{-SU} $args{-unit}";
            if (grep /\%Error/, @cmd_result = $self->execCmd($cmd, 300)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
                $flag = 0;
                goto EXIT;
            }

            if (grep /continue\?/, @cmd_result) {
                if (grep /\%Error/, $self->execCmd("y", 300)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot confirm continue");
                    $flag = 0;
                    goto EXIT;
                }
            }
        }
        else {
            my $cmd = ($args{-seti} =~ /y/) ? "aim service-unit $args{-action} $args{-SU} $args{-unit} i" : "aim service-unit $args{-action} $args{-SU} $args{-unit}";
            if (grep /\%Error/, @cmd_result = $self->execCmd($cmd, 300)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
                $flag = 0;
                goto EXIT;
            }
        }
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Wrong action input");
        $flag = 0;
        goto EXIT;
    }
    if ($args{-action} =~ /swact|unlock/) {
        my $sleep_time;
        if ($args{-SU} =~ /mdm/) {
            $sleep_time = 100;
        }
        elsif ($args{-SU} =~ /gsec/) {
            $sleep_time = 150;
        }
        elsif ($args{-SU} =~ /gvm/) {
            $sleep_time = 300;
        }
        else {
            $sleep_time = 30;
        }

        my $i = 15;
        do {
            sleep($sleep_time);
            @cmd_result = $self->execCmd("aim si-assignment show $args{-SU}");
            $command_result = join ' ', @cmd_result;
            $i--;
        } while (($command_result !~ /standby/) && ($command_result !~ /active/) && $i > 0);
        for (@cmd_result) {
            $active_unit1 = $1 if $_ =~ m/$args{-SU}\s+(\d+).*active/;
        }
        unless (defined $active_unit1) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get active unit after swact/unlock ");
            $flag = 0;
            goto EXIT;
        }
    }

    unless (@cmd_result = $self->execCmd("aim service-unit show $args{-SU}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'aim service-unit show $args{-SU}' ");
        $flag = 0;
        goto EXIT;
    }
    for (@cmd_result) {
        $unit_info = $1 if $_ =~ m/($args{-SU}\s+$args{-unit}.*)/;
    }
    unless (defined $unit_info) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get unit info ");
        $flag = 0;
        goto EXIT;
    }
    # Analyze Results
    if ($args{-action} =~ /swact/) {
        $flag = 0 if ($active_unit == $active_unit1 || grep /out-of-service|\slocked/, @cmd_result);
    }
    elsif ($args{-action} =~ /^[lock|load]/) {
        $flag = 0 if (grep /in-service|unlocked|disabled/, $unit_info);
    }
    elsif ($args{-action} =~ /unload/) {
        $flag = 0 if (grep /in-service|online/, $unit_info);
    }
    else {
        if (grep /in-service|unlocked/, $unit_info) {
            if ($args{-action} =~ /mdm/) {
                $flag = 0 unless ($command_result =~ /active/ && $command_result =~ /0/ && $command_result =~ /1/);
            }
            else {
                $flag = 0 unless ($command_result =~ /active/ && $command_result =~ /standby/);
            }
        }
        else {
            $flag = 0;
        }
    }
    $logger->error(__PACKAGE__ . ".$sub_name: Failed to $args{-action} Unit ") unless ($flag);
    EXIT:
    unless ($self->{conn}->cmd("exit")) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to execute 'exit'");
        $flag = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}
=head2 B<checkSUState()>		
    This function checks status of Service Units. 		
=over 6		
=item Arguments:		
   Mandatory:		
    -statusUnit0	: Status of Unit0		
    -statusUnit1 	: Status of Unit0		
   Optional:		
    -ne		: Service Unit.			
    -si		: i flag			
    		
=item Returns:		
        Returns 1 - If Passed		
        Returns 0 - If Failed		
=item Example:		
     my %args;		
     $args{-statusUnit0}      = "lock";		
     $args{-statusUnit1}      = "unlock";		
     $args{-ne}    = "VCA";		
     $args{-si}    = "n";		
     		
=back		
=cut		
sub checkSUState {
    my ($self, %args) = @_;
    my $sub_name = "checkSUState";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $args{-si} = $args{-si} || "n";
    $args{-statusUnit0} = $args{-statusUnit0} || "";
    $args{-statusUnit1} = $args{-statusUnit1} || "";

    my (@cmd_result, @unit_info, @ha_info);
    my ($service_cmd, $si_cmd, $command_result);
    my $flag = 1;

    if (length($args{-statusUnit0}) != 0 && length($args{-statusUnit1}) != 0) {
        $service_cmd = "aim service-unit show $args{-ne}";
        $si_cmd = "aim si-assignment show $args{-ne}";
    }
    elsif (length($args{-statusUnit0}) != 0) {
        $service_cmd = "aim service-unit show $args{-ne} 0";
        $si_cmd = "aim si-assignment show $args{-ne} 0";
    }
    elsif (length($args{-statusUnit1}) != 0) {
        $service_cmd = "aim service-unit show $args{-ne} 1";
        $si_cmd = "aim si-assignment show $args{-ne} 1";
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Did you forget to input the Unit status?");
        return 0;
    }
    $self->{conn}->print("cli");
    unless ($self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'cli' ");
        return 0;
    }
    if (grep /sg to query does not exist/, @cmd_result = $self->execCmd($service_cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: $args{-SU} does not exist in the database");
        $flag = 0;
        goto EXIT;
    }
    for (@cmd_result) {
        push(@unit_info, $1) if $_ =~ m/($args{-ne}\s+\d+.*)/;
    }
    unless (@unit_info) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get unit info ");
        $flag = 0;
        goto EXIT;
    }
    if ($#unit_info == 0) {
        if (length($args{-statusUnit0}) != 0) {
            if ($args{-statusUnit0} =~ /unlocked/) {
                $flag = 0 unless ($unit_info[0] =~ /unlocked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /in-service/);
            }
            elsif ($args{-statusUnit0} =~ /offline/) {
                $flag = 0 unless ($unit_info[0] =~ /offline/ && $unit_info[0] =~ /disabled/ && $unit_info[0] =~ /out-of-service/);
            }
            elsif ($args{-statusUnit0} =~ /^locked/) {
                $flag = 0 unless ($unit_info[0] =~ /^locked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /out-of-service/);
            }
            else {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Wrong input Unit status - $args{-statusUnit0} ");
            }
        }
        else {
            if ($args{-statusUnit1} =~ /unlocked/) {
                $flag = 0 unless ($unit_info[0] =~ /unlocked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /in-service/);
            }
            elsif ($args{-statusUnit1} =~ /offline/) {
                $flag = 0 unless ($unit_info[0] =~ /offline/ && $unit_info[0] =~ /disabled/ && $unit_info[0] =~ /out-of-service/);
            }
            elsif ($args{-statusUnit1} =~ /^locked/) {
                $flag = 0 unless ($unit_info[0] =~ /^locked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /out-of-service/);
            }
            else {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Wrong input Unit status - $args{-statusUnit1} ");
            }
        }
    }
    else {
        if ($args{-statusUnit0} =~ /unlocked/) {
            $flag = 0 unless ($unit_info[0] =~ /unlocked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /in-service/);
        }
        elsif ($args{-statusUnit0} =~ /offline/) {
            $flag = 0 unless ($unit_info[0] =~ /offline/ && $unit_info[0] =~ /disabled/ && $unit_info[0] =~ /out-of-service/);
        }
        elsif ($args{-statusUnit0} =~ /^locked/) {
            $flag = 0 unless ($unit_info[0] =~ /^locked/ && $unit_info[0] =~ /enabled/ && $unit_info[0] =~ /out-of-service/);
        }
        else {
            $flag = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Wrong input Unit status - $args{-statusUnit0} ");
        }
        if ($args{-statusUnit1} =~ /unlocked/) {
            $flag = 0 unless ($unit_info[1] =~ /unlocked/ && $unit_info[1] =~ /enabled/ && $unit_info[1] =~ /in-service/);
        }
        elsif ($args{-statusUnit1} =~ /offline/) {
            $flag = 0 unless ($unit_info[1] =~ /offline/ && $unit_info[1] =~ /disabled/ && $unit_info[1] =~ /out-of-service/);
        }
        elsif ($args{-statusUnit1} =~ /^locked/) {
            $flag = 0 unless ($unit_info[1] =~ /^locked/ && $unit_info[1] =~ /enabled/ && $unit_info[1] =~ /out-of-service/)
        }
        else {
            $flag = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Wrong input Unit status - $args{-statusUnit1} ");
        }
    }
    if (($args{-si} =~ /n/) || ($args{-statusUnit0} !~ /unlocked/ && $args{-statusUnit1} !~ /unlocked/)) {
        $logger->info(__PACKAGE__ . ".$sub_name: Skip checking ha status ");
    }
    else {
        my $i = 10;
        do {
            @cmd_result = $self->execCmd($si_cmd);
            $command_result = join ' ', @cmd_result;
            $i--;
        } while (($command_result !~ /standby/) && ($command_result !~ /active/) && $i > 0);

        for (@cmd_result) {
            push(@ha_info, $1) if $_ =~ m/$args{-ne}\s+(\d+)\s+.*/;
        }
        unless (@unit_info) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get ha info ");
            $flag = 0;
            goto EXIT;
        }
    }

    if ($#ha_info == 0) {
        $flag = 0 if ($args{-statusUnit0} =~ /unlocked/ && $ha_info[0] != 0);
        $flag = 0 if ($args{-statusUnit1} =~ /unlocked/ && $ha_info[0] != 1);
    }
    else {
        $flag = 0 if ($args{-statusUnit0} !~ /unlocked/ && $args{-statusUnit1} !~ /unlocked/);
    }
    EXIT:
    $logger->error(__PACKAGE__ . ".$sub_name: Failed to check Unit status ") unless ($flag);

    unless ($self->{conn}->cmd("exit")) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to execute 'exit'");
        $flag = 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}

=head2 B<warmSwactGWC()>

    This function implements warm-swact for specific GWC

=over 6

=item Arguments:

 Mandatory:
        - GWC ID
 Optional:
        - timeout (seconds)

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        $obj->warmSwactGWC(-gwc_id => 22, -timeout => 120);

=back

=cut

sub warmSwactGWC {
    my ($self, %args) = @_;
    my $sub_name = "warmSwactGWC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($active_unit, $timeout_flag, @output);

    unless ($args{-gwc_id}) {
        #Checking for the parameters in the input
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$args{-gwc_id}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $args{-timeout} ||= 120;
    $args{-gwc_id} = 'gwc' . $args{-gwc_id};

    unless ($self->execCmd("cli")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'cli'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    @output = $self->execCmd("aim service-unit show $args{-gwc_id}");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'aim service-unit show $args{-gwc_id}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $count = 0;
    foreach (@output) {
        if (/0\s+unlocked\s+enabled\s+in/) {
            $count++;
        }
        if (/1\s+unlocked\s+enabled\s+in/) {
            $count++;
        }
    }
    unless ($count == 2) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check $args{-gwc_id} status before warm swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $count = 0;
    @output = $self->execCmd("aim si-assignment show $args{-gwc_id}");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'aim si-assignment show $args{-gwc_id}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@output) {
        if (/standby/) {
            $count++;
        }
        if (/$args{-gwc_id}\s+(\d)\s+.*\sactive/) {
            $active_unit = $1;
            $count++;
        }
    }
    unless ($count == 2 && $active_unit ne '') {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check both $args{-gwc_id} units before warm swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ($self->execCmd("aim service-unit swact $args{-gwc_id} $active_unit", $args{-timeout})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'aim service-unit swact $args{-gwc_id} $active_unit'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $timeout_flag = 0;
    for (my $i = 0; $i < 12; $i++) {
        @output = $self->execCmd("aim si-assignment show $args{-gwc_id}");
        $count = 0;
        foreach (@output) {
            if (/standby|active/) {
                $count++;
            }
        }
        if ($count == 2) {
            $timeout_flag = 1;
            last;
        }
        sleep(5);
    }
    unless ($timeout_flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check both $args{-gwc_id} units after warm swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $timeout_flag = 0;
    for (my $i = 0; $i < 12; $i++) {
        @output = $self->execCmd("aim service-unit show $args{-gwc_id}");
        $count = 0;
        foreach (@output) {
            if (/0\s+unlocked\s+enabled\s+in/) {
                $count++;
            }
            if (/1\s+unlocked\s+enabled\s+in/) {
                $count++;
            }
        }
        if ($count == 2) {
            $timeout_flag = 1;
            last;
        }
        sleep(5);
    }

    unless ($timeout_flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check $args{-gwc_id} status after warm swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Warm swact $args{-gwc_id} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<coldSwactGWC()>

    This function implements cold-swact for specific GWC

=over 6

=item Arguments:

 Mandatory:
        - GWC ID
 Optional:
        - timeout (seconds)

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        $obj->coldSwactGWC(-gwc_id => 22, -timeout => 120);

=back

=cut

sub coldSwactGWC {
    my ($self, %args) = @_;
    my $sub_name = "coldSwactGWC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($active_unit, $timeout_flag, @output);

    unless ($args{-gwc_id}) {
        #Checking for the parameters in the input
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$args{-gwc_id}' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $args{-timeout} ||= 180;
    $args{-gwc_id} = 'gwc' . $args{-gwc_id};
    $self->{conn}->prompt('/.*[\>\$].*$/');

    unless ($self->execCmd("cli")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'cli'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    @output = $self->execCmd("aim service-unit show $args{-gwc_id}");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'aim service-unit show $args{-gwc_id}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $count = 0;
    foreach (@output) {
        $count++ if (/(0|1)\s+unlocked\s+enabled\s+in/);
    }
    unless ($count == 2) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check $args{-gwc_id} status before cold swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $count = 0;
    @output = $self->execCmd("aim si-assignment show $args{-gwc_id}");
    unless (@output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'aim si-assignment show $args{-gwc_id}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (@output) {
        if (/standby/) {
            $count++;
        }
        if (/$args{-gwc_id}\s+(\d)\s+.*\sactive/) {
            $active_unit = $1;
            $count++;
        }
    }
    unless ($count == 2 && $active_unit ne '') {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check both $args{-gwc_id} units before cold-swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless (grep /This command forces a complete/, $self->execCmd("gwc gwc-sg-mtce cold-swact $args{-gwc_id}", 20)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'gwc gwc-sg-mtce cold-swact $args{-gwc_id}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless (grep /In the event that this command terminates/, $self->execCmd("y", 20)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'y'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->execCmd("y", $args{-timeout})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot command 'y' to start cold-swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Wait 60s after cold-swact");
    sleep(60);
    $timeout_flag = 0;
    for (my $i = 0; $i < 12; $i++) {
        @output = $self->execCmd("aim si-assignment show $args{-gwc_id}");
        $count = 0;
        foreach (@output) {
            if (/standby|active/) {
                $count++;
            }
        }
        if ($count == 2) {
            $timeout_flag = 1;
            last;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Wait 5s for next unit checking");
        sleep(5);
    }
    unless ($timeout_flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check both $args{-gwc_id} units after cold-swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $timeout_flag = 0;
    for (my $i = 0; $i < 12; $i++) {
        @output = $self->execCmd("aim service-unit show $args{-gwc_id}");
        $count = 0;
        foreach (@output) {
            $count++ if (/(0|1)\s+unlocked\s+enabled\s+in/);
        }
        if ($count == 2) {
            $timeout_flag = 1;
            last;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Wait 5s for next unit status checking");
        sleep(5);
    }

    unless ($timeout_flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check $args{-gwc_id} status after cold-swact");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Cold-swact $args{-gwc_id} successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<loginNPM()>

    This function is used to login NPM mode. This also does switch unit if cannot execute "NPM" command

=over 6

=item Arguments:

 Mandatory:
        - username
		- password

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        $obj->loginNPM(-user => 'cmtg', -pwd => 'cmtg');

=back

=cut

sub loginNPM {
    my ($self, %args) = @_;
    my $sub_name = "loginNPM";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($unit, $cur_dir, @output, $cmd);

    my $flag = 1;
    foreach ('-user', '-pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);

    unless (grep /\/root/, @output = $self->execCmd("pwd")) {
        foreach (@output) {
            if (/(\/[\w\/]+)/) {
                $cur_dir = $1;
                last;
            }
        }
    }

    $self->{conn}->prompt('/(>\s?$)|(login:\s?$)|(assword:\s?$)/');
    unless (@output = $self->execCmd("npm")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to execute 'npm'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Enter the NPM/, @output) {
        foreach (@output) {
            if (/-unit(\d):/) {
                $unit = $1;
                last;
            }
        }
        if ($unit eq '0') {
            $cmd = "t1";
        }
        elsif ($unit eq '1') {
            $cmd = "t0";
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name: Fail to get current unit of lab");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        $self->execCmd($cmd);
        if ($cur_dir) {
            $self->execCmd("cd $cur_dir");
        }

        unless (@output = $self->execCmd("npm")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Fail to execute 'npm' after switching unit");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless (grep /Enter the NPM/, @output) {
            $logger->error(__PACKAGE__ . ".$sub_name: Fail to access NPM after switching unit");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    $self->execCmd($args{-user});
    @output = $self->execCmd($args{-pwd});
    if (grep /Invalid UserId\/Password/, @output) {
        $self->{conn}->print("\x03");
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to login info is wrong");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /Entering shell mode/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to login NPM");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->{conn}->prompt('/.*[\$#\>\]]\s?$/');
    $logger->debug(__PACKAGE__ . ".$sub_name: Login NPM successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<loginOssgate()>

    This function is used to login cmtg Ossgate.

=over 6

=item Arguments:

 Mandatory:
        - username
		- password

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        $obj->loginOssgate(-user => 'cmtg', -pwd => 'cmtg');

=back

=cut

sub loginOssgate {
    my ($self, %args) = @_;
    my $sub_name = "loginOssgate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @output;
    my $flag = 1;
    foreach ('-user', '-pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);

    unless (grep /Enter username and password/, @output = $self->execCmd("telnet cmtg 10023")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to execute 'telnet cmtg 10023'");
        $logger->error(__PACKAGE__ . ".$sub_name: Failed output: " . Dumper(\@output));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /CMTg-OSS Gateway/, @output = $self->execCmd("$args{-user} $args{-pwd}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to execute 'telnet cmtg 10023'");
        $logger->error(__PACKAGE__ . ".$sub_name: Failed output: " . Dumper(\@output));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Login CMTg-OSS Gateway successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<loginBPT()>

    This function is used to login BPT mode.

=over 6

=item Arguments:

 Mandatory:
        - username
		- password

=item Returns:

        Returns 1 - If Passed
        Returns 0 - If Failed

=item Example:

        $obj->loginBPT(-user => 'cmtg', -pwd => 'cmtg');

=back

=cut

sub loginBPT {
    my ($self, %args) = @_;
    my $sub_name = "loginOssgate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @output;
    my $flag = 1;
    foreach ('-user', '-pwd') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);

    unless ($self->execCmd("cli")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to execute cli");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->{conn}->prompt('/([>\]]\s?$)|(Username:\s?$)|(assword:\s?$)/');
    unless (grep /Batch Provisioning Tool/, $self->execCmd("c20mm cmtg bpt")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to access BPT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->execCmd($args{-user});
    @output = $self->execCmd($args{-pwd});
    if (grep /Invalid Username \/ Password \/ Unauthorized Group/, @output) {
        $self->{conn}->print("\x03");
        $logger->error(__PACKAGE__ . ".$sub_name: Login info is wrong");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (grep /You are currently logged in as : $args{-user}/, @output) {
        $logger->error(__PACKAGE__ . ".$sub_name: Fail to login BPT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Login BPT successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<startCalltrak()>

    This function takes a hash containing the logutil type.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        -traceType : msgtrace or: pgmtrace, gwctrace, evtrace
        -trunkName
 Optional: 
        -dialedNumber
        
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-traceType => 'msgtrace', trunkName => [], -dialedNumber => []); 
        $obj->startCalltrak(%args);

=back

=cut

sub startCalltrak {
    my ($self, %args) = @_;
    my $sub_name = "startCalltrak";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-traceType', '-trunkName') { #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $flag = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $args{$_} not present");
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep /CallTrak:/, $self->execCmd("calltrak")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'calltrak' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    # enable trace type
    if ($args{-traceType} =~ /msgtrace/) {
        unless (grep /MSGTRACE:/, $self->execCmd("msgtrace on")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'msgtrace on' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless (grep /Buffersize:/, $self->execCmd("msgtrace bufsize short 230 long 65")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'msgtrace bufsize short 230 long 65' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless (grep /Display Opts: TIMESORT/, $self->execCmd("msgtrace displayopts set timesort")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'msgtrace displayopts set timesort' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

    }
    elsif ($args{-traceType} =~ /pgmtrace/) {
        unless (grep /PGMTRACE:/, $self->execCmd("pgmtrace on")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'pgmtrace on' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless (grep /Buffersize:/, $self->execCmd("PGMTRACE bufsize 64512")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'PGMTRACE bufsize 64512' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        unless (grep /Display Opts: TIMESORT/, $self->execCmd("PGMTRACE displayopts set retaddr edition timesort")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'PGMTRACE displayopts set retaddr edition timesort' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    elsif ($args{-traceType} =~ /gwctrace/) {
        unless (grep /GWCTRACE:\s*On/, $self->execCmd("gwctrace on")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'gwctrace on' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    elsif ($args{-traceType} =~ /evtrace/) {
        unless (grep /EVTrace:\s*On/, $self->execCmd("evtrace on")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'evtrace on' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    #select DN
    my $result = 1;
    if ($args{-dialedNumber}) {
        foreach (@{$args{-dialedNumber}}) {
            unless ($self->execCmd("select dn $_")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'select dn $_' ");
                $result = 0;
                last;
            }
        }
        unless ($result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    $self->{conn}->print("TABLE DPTRKMEM; format pack");
    unless ($self->{conn}->waitfor(-match => '/first column>/', -timeout => 10)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Didnt get 'first column>' prompt ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->waitfor(-match => '/>/', -timeout => 3);
    # select trunk
    foreach (@{$args{-trunkName}}) {
        unless ($_ =~ /LINE/) {
            if (grep /ERROR|NOT FOUND|INCORRECT/, $self->execCmd("pos $_")) {
                unless ($self->execCmd("abort")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'abort' ");
                    $result = 0;
                    last;
                }
                unless ($self->execCmd("select TRK $_")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'select TRK $_' ");
                    $result = 0;
                    last;
                }
            }
            else {
                unless ($self->execCmd("select DPT CLLI $_")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'select DPT CLLI $_' ");
                    $result = 0;
                    last;
                }
            }
        }
    }
    unless ($result) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->execCmd("quit")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->prompt('/.*[\$#>]\s?$/');
    unless ($self->execCmd("start")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'start' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    sleep(3);
    unless (grep /Tracing started/, $self->execCmd("y")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot start tracing ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<stopCalltrak()>

    This function is used to stop calltrak log in core.

=over 6

=item Arguments:

=item Returns:

        @callTrakLogs

=item Example:

        my @callTrakLogs = $obj->stopCalltrak();

=back

=cut

sub stopCalltrak {
    my ($self) = @_;
    my $sub_name = "stopCalltrak";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @callTrakLogs;
    unless (grep /Already in CALLTRAK/, $self->execCmd("calltrak")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'calltrak' to stop calltrak logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->execCmd("stop")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'stop' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless (@callTrakLogs = $self->execCmd("display merge", 1800)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'display merge' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ($self->execCmd("quit")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Stop calltrak log successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return @callTrakLogs;
}


=head1 B<datafillTable()>

    This function is used to datafill in table.

=over 6

=item Arguments:

=item Returns:

        Returns 1 - If succeeds
        Returns 0 - If Failed

=item Example:

        %args = (
                    -table => "TRKSGRP",
                    -action => "REP",
                    -cmd => ['SIPPBX_SIPP 0 DS1SIG ISDN 20 20 96ISOQSIG 2 N STAND +',
                            'NETWORK PT_PT USER N UNEQ 160 N DEFAULT GWC 13 33 +', 
                            '2700 64K HDLC $ $']
                );
        $obj->datafillTable(%args);

        %args = (
                -table => 'TRKMEM',
                -action => 'REP',
                -cmd => ['1->a; 2701->b;repeat 8(rep SIPPBX_SIPP a 0 GWC 13 33 b;a+1->a;b+1->b)']
                );
        $obj->datafillTable(%args);
=back

=cut


sub datafillTable {
    my ($self, %args) = @_;
    my $sub_name = "datafillTable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $self->{conn}->prompt('/\>/');

    my $flag = 1;
    my $exist = 1;
    my $count = 1;
    my $repeat = 0;
    my $repeat_time = 0;
    my (@cmd_result, $tuple_key, $prompt);
    foreach ('-table', '-action', '-cmd') { #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ($self->execCmd("quit all")) {
        $logger->error(__PACKAGE__ . " : Failed to quit all");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ($self->execCmd("table $args{-table}")) {
        $logger->error(__PACKAGE__ . " : Failed to access into TABLE $args{-table}");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $self->execCmd("abort");
        return 0;
    }

    unless (grep /VERIFY OFF/, $self->execCmd("ove;ver off")) {
        $logger->error(__PACKAGE__ . " : Failed to ove;ver off in TABLE $args{-table}");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ($args{-cmd}[0] =~ /(\d+)\-\>b\;repeat\s+(\d+)\(/) {
        $repeat_time = $2;
        $prompt = $1 + $2 - 1;
        $repeat = 1;
    }
    elsif ($args{-cmd}[0] =~ /(.*)\(.*/) {
        $tuple_key = $1;
    }
    elsif ($args{-cmd}[0] =~ /^(\S+\s\S+\s\S+).*/) {
        $tuple_key = $1;
    }
    elsif ($args{-cmd}[0] =~ /^(\S+\s\S+).*/) {
        $tuple_key = $1;
    }
    elsif ($args{-cmd}[0] =~ /([\d|\d+]).*/) {
        $tuple_key = $1;
    }
    else {
        $logger->error(__PACKAGE__ . " : Failed to find the key in TABLE $args{-table}");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ("$args{-action}" eq "DEL") {
        if (grep /TUPLE DELETED/, @cmd_result = $self->execCmd("DEL $args{-cmd}[0]")) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Delete tuple in TABLE $args{-table} successfully");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
        elsif (grep /NOT FOUND|DISABLED/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Tuple does not exist in TABLE $args{-table}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to delete tuple in TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    unless ($repeat) {
        if (grep /NOT FOUND/, @cmd_result = $self->execCmd("pos $tuple_key")) {
            $exist = 0;
        }
        elsif (grep /ERROR/, @cmd_result) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- An ERROR occured in TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        }
    }
    else {
        $self->{conn}->prompt("/$prompt/");
        unless (@cmd_result = $self->execCmd("$args{-cmd}[0]\n")) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        }

        $logger->info(__PACKAGE__ . ".$sub_name:" . Dumper(\@cmd_result));
        foreach (@cmd_result) {
            if (/TUPLE ADDED|TUPLE REPLACED|INB/) {
                $count += 1;
            }
        }

        unless ($count == $repeat_time) {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        else {
            return 1;
        }
    }

    if ($exist) {
        $args{-cmd}[0] = "REP " . $args{-cmd}[0];
        for (my $i = 0; $i < $#{$args{-cmd}} + 1; $i++) {
            if ($i == 0 || $args{-cmd}[$i] =~ /.*\+$/ || $args{-cmd}[$i - 1] =~ /.*\+$/) {
                unless (@cmd_result = $self->execCmd("$args{-cmd}[$i]")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                }
            }
            else {
                unless (@cmd_result = $self->execCmd("REP $args{-cmd}[$i]")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                }
            }
            sleep(2);
        }

        if (grep /TUPLE REPLACED|INB|permitted/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Rep tuple into TABLE $args{-table} successfully ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to add tuple into TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    else {
        $args{-cmd}[0] = "ADD " . $args{-cmd}[0];
        for (my $i = 0; $i < $#{$args{-cmd}} + 1; $i++) {
            if ($i == 0 || $args{-cmd}[$i] =~ /.*\+$/ || $args{-cmd}[$i - 1] =~ /.*\+$/) {
                unless (@cmd_result = $self->execCmd("$args{-cmd}[$i]")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                }
            }
            else {
                unless (@cmd_result = $self->execCmd("ADD $args{-cmd}[$i]")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to execute command into TABLE $args{-table}");
                    $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                }
            }
            sleep(2);
        }

        if (grep /TUPLE ADDED/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Add tuple into TABLE $args{-table} successfully ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
        elsif (grep /EXISTS/, @cmd_result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            $exist = 1;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Failed to add tuple into TABLE $args{-table}");
            $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}





1;
