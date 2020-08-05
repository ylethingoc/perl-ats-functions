package SonusQA::SST;

=head1 NAME

 SonusQA::SST - Perl module for SST

=head1 AUTHOR

 nthuong2 - nthuong2@tma.com.vn

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::SST->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Module::Locate

=head1 DESCRIPTION
 SST software provides call media and signaling interoperability capabilities. On all platforms, the primary application supported by the SST software is the Session Initiated Protocol (SIP) Gateway. It only works with SIP protocol.
 This module implements some functions that support on SST.

=head1 METHODS

=cut

use strict;
use warnings;
use Data::Dumper;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;

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
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/'; #/.*[\$%\}\|\>]$/   /.*[\$%#\}\|\>\]].*$/
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
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    
    $self->{PROMPT} = '/[\$%#\}\|\>\]].*$/'; 
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{conn}->prompt($self->{DEFAULTPROMPT});
    
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10);
    
    if (grep/cli/, $self->execCmd("")) {
        unless ($self->execCmd("cli-session modify timeout 1410")) {		
            $logger->error(__PACKAGE__ . ".$sub_name: cannot modify timeout for cli session");		
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");		
            return 0;		
        }
        unless ($self->execCmd("sh")) {		
            $logger->error(__PACKAGE__ . ".$sub_name: cannot command 'sh'");		
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");		
            return 0;		
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<startSp2ktrace()>

    This function takes a hash containing the prtcache option for start sp2ktrace logs in SST

=over 6

=item Arguments:

 Optional:
        
        - prtcache : (Y/N): Option to select prtcache into sp2ktrace or not. Default: N (get SIP message)

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-prtcache => 'N'); 
        $obj->startSp2ktrace(%args);

=back

=cut

sub startSp2ktrace {
    my ($self, %args) = @_;
    my $sub_name = "startSp2ktrace";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless(exists $args{-prtcache}){#if $args{-prtcache} is not exists, $args{-prtcache} = "N";
        $args{-prtcache} = "N";
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Select prtcache is: $args{-prtcache} ");
 
    # Access root to start sp2ktrace log
    unless ($self->enterRootSessionViaSU()) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot enter root session ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $prev_prompt = $self->{conn}->prompt('/\>/');                                     #Changing the prompt to System.+> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to /\>/");
    unless (grep/SIPTRACE/, $self->execCmd("sp2ktrace")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'sp2ktrace' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    unless (grep/All siplinks selected/, $self->execCmd("set 1 127")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'set 1 127' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $self->{conn}->print("start");
    unless($self->{conn}->waitfor(-match => '/default yes/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get 'default yes' prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    my @cmdResult = $self->execCmd($args{-prtcache});
    #Trace was dumped into file: /opt/apps/logs/siptrace.20190123.root.32268.txt
    foreach (@cmdResult) {
        if ($_ =~ /Trace was dumped into file:\s\s*(.+)/) {
             $self->{sp2ktrace_logs} = $1;
             last;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name: <-- sp2ktrace logs is: $self->{sp2ktrace_logs} ");       

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Start sp2ktrace log successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$self->{sp2ktrace_logs}]");  
    return $self->{sp2ktrace_logs};
}

=head2 B<stopSp2ktrace()>

    This function is used to stop sp2ktrace log in SST.

=over 6

=item Arguments:

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->stopSp2ktrace();

=back

=cut

sub stopSp2ktrace {
    my ($self) = @_;
    my $sub_name = "stopSp2ktrace";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    unless ($self->execCmd("stop")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'stop' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
  
    $self->{conn}->prompt('/AUTOMATION[#>]/');
    unless (grep /bye/,$self->execCmd("quit")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }    
    
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Stop sp2ktrace log successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");    
    return 1;
}

=head2 B<verifySp2ktraceMessage()>

    This function is used to match and verify the pattern present in the log file. 
 
=over 6

=item Arguments:

        Object Reference
        -pattern  - The pattern to verify not present in the log file
        -start_boundary
        Optional:
        -end_boundary

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

         my %input = (-start_boundary => ['INVITE', 'SIP/2.0'],
                     -pattern =>  ['200 OK', 'Src:  CP_CALLM_ID'],
                    ); 

        $obj->verifySp2ktraceMessage(%input);

=back

=cut

sub verifySp2ktraceMessage {
    my ($self, %input) = @_;
    my $sub = "verifySp2ktraceMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $flag = 1;
    foreach ('-pattern', '-start_boundary') {
        unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my ($file) = $self->{sp2ktrace_logs}; 
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    
    #my $prev_prompt = $self->{conn}->prompt('/SESSION ENDED/');                                     #Changing the prompt to /SESSION ENDED/ 
    #$logger->debug( __PACKAGE__ . ".$sub: Changing the prompt to /SESSION ENDED/");
    my @logFile;
    #Reading the DBG File
    unless( @logFile = $self->execCmd("cat $file") ){
        $logger->debug(__PACKAGE__ . ".$sub: Cannot read the file ($file)");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my ($header, %count, %content);
    my @pattern = @{$input{-pattern}};
    my $temp_pattern = join ('|', ${$input{-start_boundary}}[0]);
    unless(exists $input{-end_boundary}){
        $input{-end_boundary} = "Content-Length";
    }
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
    unless (keys %content) {
        $logger->error(__PACKAGE__ . ".$sub: there is no message in the captured data file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;     
    }
    $logger->debug(__PACKAGE__ . Dumper(\%content));
    
   my $result;
    foreach my $ptn (@pattern) {
        $logger->debug(__PACKAGE__ . ": pattern: $ptn ");
        foreach my $msg (keys %content) {
            foreach my $occurrence (keys %{$content{$msg}}) {
                $logger->debug(__PACKAGE__ . "occurrence: $occurrence");
                unless (grep /$ptn/, @{$content{$msg}->{$occurrence}}) {
                    delete $content{$msg}{$occurrence};
                    $result = 0;
                    next;
                } else {
                    $result = 1;
                    $logger->debug(__PACKAGE__ . ".$sub: === Found $ptn in the message"); 
                    last;
                }
            }
            last if ($result == 1);
        }
        last if ($result == 0);
    }
    
    if($result == 1){
        $logger->info(__PACKAGE__ . ".$sub: all patterns found in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    } else {
        $logger->info(__PACKAGE__ . ".$sub: not all patterns  found in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 B<verifyNoSp2ktraceMessage()>

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
                     -pattern =>  ['ID_GENERIC_ADDRESS  TOA_UPADDR_NOT_SCREENED NATIONAL SCR_USER_PROVIDED_NOT_VER PRES_RSTR_ALLOWED NPI_ISDN TI_NOT_TEST_CALL 1234567890 10'],
                    ); 

        $obj->verifyNoSp2ktraceMessage(%input);

=back

=cut

sub verifyNoSp2ktraceMessage {
    my ($self, %input) = @_;
    my $sub = "verifyNoSp2ktraceMessage";
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
    my ($file) = $self->{sp2ktrace_logs}; 
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    
    my $prev_prompt = $self->{conn}->prompt('/SESSION ENDED/');                                     #Changing the prompt to /SESSION ENDED/ 
    $logger->debug( __PACKAGE__ . ".$sub: Changing the prompt to /SESSION ENDED/");
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
    unless(exists $input{-end_boundary}){
        $input{-end_boundary} = "Content-Length";
    }
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
                unless (grep /$definedMsg/, @{$content{$msg}->{$occurrence}}) {
                    delete $content{$msg}{$occurrence};
                    next;
                }
                unless (@expected_msg) {
                    @expected_msg = @{$content{$msg}{$occurrence}};
                }
            }
        }
    }
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

=head2 B<deleteSp2ktraceMessage()>

    This function is used to delete sp2ktrace log in SST.

=over 6

=item Arguments:

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->deleteSp2ktraceMessage();

=back

=cut

sub deleteSp2ktraceMessage {
    my ($self) = @_;
    my $sub_name = "deleteSp2ktraceMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my ($file) = $self->{sp2ktrace_logs}; 
    unless($file){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Got the log file to verify the Message: $file");
    }    
    
    # Delete logs file
    $self->{conn}->prompt('/AUTOMATION# $/');
    $logger->debug( __PACKAGE__ . ".$sub_name: changing the prompt to /AUTOMATION# \$/");
    $self->execCmd('export PS1="AUTOMATION# "');  
    unless ($self->execCmd("rm -rf $file")) {
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Failed to Delete sp2ktrace log ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");    
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Delete sp2ktrace log successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");    
    return 1;
}

=head2 B<loginCore()>

    This function takes a hash containing the username and password for login into C20 core.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        - username 
        - password

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

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
    foreach('-username', '-password'){                                                        #Checking for the parameters in the input hash
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
 
    $self->{conn}->print("sh");
    $self->{conn}->waitfor(-match => '/WARNING/', -timeout => 10);
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 10);
    
    my $prevPrompt = $self->{conn}->prompt('/>/');
    my $result = 0;
    for (my $i=0; $i < $#{$args{-username}}+1; $i++) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Trying to login into core using command 'telnet cm' [$i]");
        $self->{conn}->print("telnet cm");#Enter username and password , CHAR MODE.
        unless ($self->{conn}->waitfor(-match => '/CHAR MODE/', -timeout => 10)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Didn't get 'Enter username and password' prompt after entering 'telnet cm'");
            last;
        }
        $self->{conn}->waitfor(-match => '/>/', -timeout => 10);
        my @output = $self->{conn}->cmd("$args{-username}[$i] $args{-password}[$i]");
        $logger->debug(__PACKAGE__ . ".$sub_name: ".Dumper(\@output));
        if (grep/Logged in on/, @output) {
            $result = 1;
            $logger->debug(__PACKAGE__ . ".$sub_name: Login into C20 core successfully");
            unless ($self->execCmd("servord")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'servord' ");
                $result = 0;
            }
            last;
        } elsif (grep/Invalid user name or password/, @output) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Invalid user name or password. Please try with other user");
        } elsif (grep /User logged in on another device, please try again./, @output) {
            $logger->debug(__PACKAGE__ . ".$sub_name: User logged in on another device, please try again..");
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Cannot login into C20 core ");
            last;
        }
    } 
	unless($result){
		$logger->error(__PACKAGE__ . ".$sub_name: Cannot login into C20 core");
	}
	
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<startCalltrak()>

    This function takes a hash containing the logutil type.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        -traceType : msgtrace, pgmtrace, gwctrace, evtrace
        -trunkName
 Optional:
        -dialedNumber
        
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-traceType => ['msgtrace','pgmtrace'], -trunkName => [], -dialedNumber => []); 
        $obj->startCalltrak(%args);

=back

=cut

sub startCalltrak {
    my ($self, %args) = @_;
    my $sub_name = "startCalltrak";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    unless ($args{-traceType}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $args{-traceType} not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless (grep/CallTrak:/, $self->execCmd("calltrak")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'calltrak' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    # enable trace type
    if (grep /msgtrace/, @{$args{-traceType}}) {
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
    if (grep /pgmtrace/, @{$args{-traceType}}) {
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
    if (grep /gwctrace/, @{$args{-traceType}}) {
        unless (grep /GWCTRACE:\s*On/, $self->execCmd("gwctrace on")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'gwctrace on' ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    if (grep /evtrace/, @{$args{-traceType}}) {
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
    if ($args{-trunkName}) {
        foreach (@{$args{-trunkName}}) {
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
            } else {
                unless ($self->execCmd("select DPT CLLI $_")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'select DPT CLLI $_' ");
                    $result = 0;
                    last;
                }
            }
        }
        unless ($result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    unless ($self->execCmd("quit")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'quit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->execCmd("start")) {
    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'start' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
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

=head2 B<verifyCalltrakLOgs()>

    This function is used to match and verify the pattern present in a given header in the log file. 

=over 6

=item Arguments:

     Mandatory:
        Object Reference
        - pattern 
        - tcid
        - start_boundary
        - end_boundary

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:
        my %input = (-pattern => { 'INCOMING' => { 1 => ['ISUP_IAM PART', 'CALLING PARTY CATEGORY:  \#E0 - ISUP_CPC_EMERGENCY_CALL'],
                                        }
                                 },
                     -tcid => $tcid,
                     -start_boundary => 'Undefined',
                     -end_boundary => 'ADDRESS_INFORMATION'
                    );
        $sbxObj->verifyCalltrakLOgs(%input);

=back

=cut

sub verifyCalltrakLOgs {
    my ($self, %input) = @_;
    my $sub = "verifyCalltrakLOgs";
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
    my ($header, $pdu_start, %count, %content, %returnhash, $resultvalidator);
    my %pattern = %{$input{-pattern}};
    my $temp_pattern = join ('|', keys%pattern); # i need to this make regex match circus
    my $start_boundary = $input{-start_boundary}; #defined boundary or i will take default
    my $end_boundary = $input{-end_boundary};
    foreach my $line (@{$input{-log_Call}}) {
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

=head2 startCustDesignLogs()

=over

=item DESCRIPTION:

    This subroutine starts capturing logs by executing command: tail -f designlog or tail -f custlog

=item ARGUMENTS:

   Mandatory:
    -logType     => custlog or designlog
    -tcId 

=item Returns:

        $logFile: this variable is used in verifyCust_DesignLOgs().

=item EXAMPLE:

    $logFile = $obj->startCustDesignLogs(-logType => "custlog", -tcId => "TC001");

=back

=cut

sub startCustDesignLogs {
    my ($self, %args) = @_;
    my $sub_name = "startCustDesignLogs";
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
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    # Access root to start cust_design log
    unless ($self->enterRootSessionViaSU()) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot enter root session ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{'LOG_PATH'} = "/var/log/";
    my $tcId = $args{-tcId};
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $datestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    my $logFile = $tcId."_".$args{-logType}."_".$datestamp;
    my $cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Capturing the log file: $logFile");
    unless(($cmd_result) = $self->execCmd("tail -f $self->{'LOG_PATH'}$args{-logType} | tee $self->{'LOG_PATH'}$logFile > /dev/null &")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to capture the $args{-logType} message");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{PROCESS_ID} = $1 if  ($cmd_result =~ /\[\d\]\s+(.+)\s*/);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub ");
    return $logFile;
}

=head2 stopCustDesignLogs()

=over

=item DESCRIPTION:

    This subroutine is used to stop capturing logs

=item ARGUMENTS:

=item PACKAGE:

    SonusQA::SST

=item OUTPUT:

    0      - fail
    1      - Success

=item EXAMPLE:

    $obj->stopCustDesignLogs();

=back

=cut

sub stopCustDesignLogs {
    my ($self, $tcid, $copyLocation) = @_;
    my $sub_name = "stopCustDesignLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub_name: Killing the process");
    unless(@cmd_result = $self->execCmd("kill -9 $self->{PROCESS_ID}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to kill the process $self->{PROCESS_ID}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyCustDesignLOgs()>

    This function is used to match and verify the pattern present in a given header in the log file. 
    This function calls Base::parseLogFiles() to verify the pattern.

=over 6

=item Arguments:

        -logFile => "TC001_custlog_20190129-035401"  (It is returned from startCust_DesignLogs())
        -patterns => ["m=audio .* RTP/AVP 96 8 18 9 116 99 126 100", "LYNCCTI Switch"]

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $sbxObj->verifyCustDesignLOgs(-logFile => $logFile, -patterns => ["m=audio .* RTP/AVP 96 8 18 9 116 99 126 100", "LYNCCTI Switch"]);

=back

=cut

sub verifyCustDesignLOgs {
    my ($self, %args) = @_ ;
    my $sub_name = "verifyCustDesignLOgs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $flag = 1;
    foreach ('-logFile', '-patterns') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    #verify logs using Base:parseLogFiles
    $logger->info(__PACKAGE__ . ".$sub_name: Start verify log file: $args{-logFile}");
    unless ($self->parseLogFiles($args{-logFile}, @{$args{-patterns}})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to verify logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $flag = 0;
    }
    #delete logs file after verify
    $self->copyLogToATS($args{-logFile});
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}

=head2 B<copyLogToATS()>

    This function is used to transfer log file to local logs . 
    It then deletes log file from the server

=over 6

=item Arguments:

        $logFile: (/var/log/TC001_custlog_20190129-035401)

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        $obj->copyLogToATS($logFile);

=back

=cut
 
sub copyLogToATS {
    my ($self, $logFile) = (@_);
    my $sub_name = "copyLogToATS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $datestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
  
    my $locallogname = $main::log_dir;
    my $flag = 1;
    my %scpArgs;
    $logFile = $self->{'LOG_PATH'}.$logFile;
    $logger->debug(__PACKAGE__ . ".$sub_name: Copying logs file: $logFile to local path: $locallogname");
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$logFile";
    $scpArgs{-destinationFilePath} = $locallogname;
    $logger->debug(__PACKAGE__ . ".$sub_name: scp log $logFile to $locallogname");
   
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the $logFile file");
        $flag = 0;
    }
    my $cmd = "rm -f $logFile";
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

=head2 B<warmSwactSST()>

    This function to warm-swact SST.

=over 6

=item Arguments:

 Mandatory:
        $sg_name: Name of Service Unit you would like to take action on

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->warmSwactSST($sg_name);

=back

=cut

sub warmSwactSST {
    my ($self, $sg_name) = @_;
    my $sub_name = "warmSwactSST";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
	unless ($sg_name) {
		$logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'sg_name' not present");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		return 0;
	}
    my $prevPrompt = $self->{conn}->prompt('/>/');
    $logger->debug(__PACKAGE__ . ".$sub_name: -->sg-name: $sg_name");
    # check unit active
    my (@pre_check, @alarm_check);
    unless (@pre_check = $self->execCmd("aim si-assignment show $sg_name")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Faild to execute command 'aim si-assignment show $sg_name' before warm-swact ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @pre_check = grep !/^\s*$/, @pre_check;
    pop(@pre_check);
    my $active_unit = "0";
    if ($pre_check[2] =~ /standby/) {
        $active_unit = "1";
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: +++ active unit +++ : $active_unit ");
    unless ($self->execCmd("aim service-unit swact $sg_name $active_unit", 300)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Faild to execute command 'aim service-unit swact $sg_name $active_unit' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    # check 2 unit in-sync after warm-swact
    my $result = 0; 
	for (my $index =0; $index <= 10; $index ++) {
		unless ( grep /SIP Gateway Application Mtc Out Of Sync/, @alarm_check = $self->execCmd("fm alarm show all")) {
            $result = 1;
            $logger->info(__PACKAGE__ . ".$sub_name: 2 units in SST are in-sync ");
            last
        }
		$logger->debug(__PACKAGE__ . ".$sub_name: Wait 30s for 2 units in SST to be in-sync ");
        sleep(30);
	}
    unless($result){
		$logger->error(__PACKAGE__ . ".$sub_name: Failed to warm-swact SST ");
	}
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return $result;
}

=head2 B<provisioningOnSOAPUI()>

    This function read xml file, replace value from input and save on _new file. Then execute SOAPUI cammand to provisioning on A2.

=Arguments:

 Mandatory:
        Object Reference
        ip
        port
        password
        users
        xmlfile
        others variables depend on xml file. 
=Returns:
        Returns 1 - If succeeds
        Reutrns 0 - If Failed
=Example:
        my %args = (
        -ip => '10.250.182.112',
        -port => '8443',
        -username => '',
        -password => '',
        -dbversion => 120,
        -xmlfile => 'SSTXMLApplication.xml',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename => 'SIPP',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud => 'Info',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod => 'N',        
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod => 'N',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue => '5',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr => 'Y',        
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat => 'Compact',        
        -usr_SIPSERVER_ModifyTuple_servername => 'TEST000',
        -usr_SIPSERVER_ModifyTuple_domainname => 'NULL',
        -usr_SIPSERVER_ModifyTuple_dnsport => 'UDP',
        -usr_SIPSERVER_ModifyTuple_servertype => 'SESSIONSERVER',
        -usr_SERVICESPROFILE_ModifyTuple_servicesProfilename => 'AUTO_PROFILE1',
        -usr_SERVICESPROFILE_ModifyTuple_acceptencapisup => 'AUTO_PROFILE1',
        -usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp => 'AUTO_PROFILE1',
        -usr_SERVICESPROFILE_ModifyTuple_emct => 'Y',
        -usr_SERVICESPROFILE_ModifyTuple_bufferacm => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_connmode => 'Y',
        -usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange => 'Update',
        -usr_SERVICESPROFILE_ModifyTuple_teleprof => 'Y',
        -usr_SERVICESPROFILE_ModifyTuple_psdp => 'Y',
        -usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok => 'Y',
        
        -usr_ACCESSLINK_DeleteTuple_linkname => 'TMA19SSTFEDORA01',  
         
        -usr_ACCESSLINK_AddTuple_linkname => 'TMA19SSTFEDORA01',
        -usr_ACCESSLINK_AddTuple_teleprof => 'TGRPTEST',
        -usr_ACCESSLINK_AddTuple_sipserver => 'AUTO_SIPP',
        -usr_ACCESSLINK_AddTuple_ccaidx => 'DEFAULT',   
                          
        );
        $obj->provisioningOnSOAPUI(%args);
        
=cut

sub provisioningOnSOAPUI {
    my ($self, %args_temp) = @_;
    my $sub_name = "provisioningOnSOAPUI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    ### Mandatory fields ####
    
    #        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename => 'SIPP',
    #        -usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud => 'Info', 
    #        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue => '5',
    #        -usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat => 'Compact',  
    
    #        -usr_SIPSERVER_ModifyTuple_servername => 'AUTO_SIPP',
    #        -usr_SIPSERVER_ModifyTuple_servertype => 'SESSIONSERVER',
    #        -usr_SIPSERVER_ModifyTuple_domainname => 'NULL',
    #        -usr_SIPSERVER_ModifyTuple_dnsport => '5060',        
    #        -usr_SIPSERVER_ModifyTuple_dnsprotocol => 'UDP',        
    #        -usr_SIPSERVER_ModifyTuple_serverProfile => 'AUTO_PROFILE',        
    #        -usr_SIPSERVER_ModifyTuple_ipaddress => $sipp_ip,  
    
    #        -usr_SERVICESPROFILE_ModifyTuple_servicesProfilename => 'AUTO_PROFILE1',
    #        -usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange => 'Update',
    
    #        -usr_ACCESSLINK_DeleteTuple_linkname => 'TMA19SSTFEDORA01',  
         
    #        -usr_ACCESSLINK_AddTuple_linkname => 'TMA19SSTFEDORA01',
    #        -usr_ACCESSLINK_AddTuple_teleprof => 'TGRPTEST',
    #        -usr_ACCESSLINK_AddTuple_sipserver => 'AUTO_SIPP',
    #        -usr_ACCESSLINK_AddTuple_ccaidx => 'DEFAULT', 
    
	#Create default fields. Please replace the right value for each Testcases, otherwsise the default value  will be used to provisioning
    my %args = (
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod => 'N',        
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod => 'N',
        -usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr => 'N',
        
        -usr_SIPSERVER_ModifyTuple_dnsenabled => 'N',
        -usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled => 'N',
        
        -usr_SERVICESPROFILE_ModifyTuple_acceptencapisup => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_allowe164 => 'N',        
        -usr_SERVICESPROFILE_ModifyTuple_emct => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_bufferacm => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_connmode => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_teleprof => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_psdp => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_ccdigits => '0',
        -usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling => 'N',
        -usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok => 'N',
	        );
   
     while ( my ($key, $value) = each %args_temp ) { 
		$args{$key} = $value; 
	} 

    #Check existance of mandatory parameters
    foreach ('-ip','-port','-username','-password','-dbversion','-xmlfile') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    #Verify the xml file
    unless ($args{-xmlfile}=~m[.xml]) {
        $logger->error(__PACKAGE__ . ".$sub_name: Input file is not an xml file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmdResults;
    my $cmdResult;
    
    my $line;
    
    my @fileName = split(/.xml/, $args{-xmlfile});
    my $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/SST/SOAP_UI_FILE/".$args{-xmlfile};
    my $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/SST/SOAP_UI_FILE/".$fileName[0]."_new.xml";
    
    unless ( open(IN, "<$in_file")) {
        $logger->error( __PACKAGE__ . ".$sub_name: Can not open $in_file " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Open input file $in_file \n");
    
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub_name: Can not create $out_file " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new xml file $out_file \n");
    
    my $flag;
    while ( $line = <IN> ) {
    #Replace IP:port provisioning
        if ($line =~ s/ip_Port/$args{-ip}:$args{-port}/) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace IP:port with $args{-ip}\:$args{-port} \n");
        }
    #Replace username to authentication provisioning
        if ($line =~ s/userName/$args{-username}/) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace Username with $args{-username} \n");
        }
    #Replace password to authentication provisioning
        if ($line =~ s/passWord/$args{-password}/) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace Password with $args{-password} \n");
        }		
    #Replace Header through out the file
		if ($line =~ m/<soapenv:Header\/>/) {
			#$logger->debug(__PACKAGE__ . ".$sub_name: Replace Header \n");        
			$line =~ s/<soapenv:Header\/>/\t<soapenv:Header>\n\t\t<ns1:DBVERSION soapenv:actor=\"http:\/\/schemas.xmlsoap.org\/soap\/actor\/next\" soapenv:mustUnderstand=\"0\" xsi:type=\"ns1:vmprofileDnType\" xmlns:ns1=\"urn:spi\">$args{-dbversion}<\/ns1:DBVERSION>\n\t<\/soapenv:Header>/;
		}		
		
        $flag = 1;
#SIPPROTOCOLPROFILE_ModifyTuple        
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sipProtocolProfilename_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_callingpartycategory
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_callingpartycategory} && $line =~ s/<callingpartycategory>usr_SIPPROTOCOLPROFILE_ModifyTuple_callingpartycategory<.*>/<callingpartycategory>$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_callingpartycategory}<\/callingpartycategory>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace callingpartycategory_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_callingpartycategory} \n");
        }    
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_historyinfohdr
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_historyinfohdr} && $line =~ s/<historyinfohdr>usr_SIPPROTOCOLPROFILE_ModifyTuple_historyinfohdr<.*>/<historyinfohdr>$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_historyinfohdr}<\/historyinfohdr>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace historyinfohdr_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_historyinfohdr} \n");
        }             
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud} && $line =~ s/<longcallaud>usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud<.*>/<longcallaud>$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud}<\/longcallaud>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace longcallaud_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud} \n");
        }     
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud} && $line =~ s/<overlapmethod>usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud<.*>/<overlapmethod>$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud}<\/overlapmethod>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace overlapmethod_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_longcallaud} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sessiontimervalue_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sessiontimervalue} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace updatemethod_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_updatemethod} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace infomethod_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_infomethod} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_remotepartyidhdr
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_remotepartyidhdr} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_remotepartyidhdr/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_remotepartyidhdr}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace remotepartyidhdr_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_remotepartyidhdr} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace passertidentifyhdr_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_passertidentifyhdr} \n");
        } 
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_diversionhdr
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_diversionhdr} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_diversionhdr/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_diversionhdr}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace diversionhdr_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_diversionhdr} \n");
        }   
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sipheaderformat_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_routingnumber
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_routingnumber} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_routingnumber/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_routingnumber}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace routingnumber_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_routingnumber} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_jurisdictionidparam
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_jurisdictionidparam} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_jurisdictionidparam/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_jurisdictionidparam}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace jurisdictionidparam_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_jurisdictionidparam} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_rncontext
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_rncontext} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_rncontext/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_rncontext}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace rncontext_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_rncontext} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sipheaderformat_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_sipheaderformat} \n");
        }
            #Replace usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod
        if (exists $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod} && $line =~ s/usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod/$args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace overlapmethod_SIPPROTOCOLPROFILE_ModifyTuple: $args{-usr_SIPPROTOCOLPROFILE_ModifyTuple_overlapmethod} \n");
        }
          
#SIPSERVER_ModifyTuple          
            #Replace usr_SIPSERVER_ModifyTuple_servername         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_servername} && $line =~ s/usr_SIPSERVER_ModifyTuple_servername/$args{-usr_SIPSERVER_ModifyTuple_servername}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace servername_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_servername} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_domainname         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_domainname} && $line =~ s/usr_SIPSERVER_ModifyTuple_domainname/$args{-usr_SIPSERVER_ModifyTuple_domainname}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace domainname_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_domainname} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_dnsport         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_dnsport} && $line =~ s/>usr_SIPSERVER_ModifyTuple_dnsport/>$args{-usr_SIPSERVER_ModifyTuple_dnsport}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsport_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_dnsport} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_dnsprotocol         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_dnsprotocol} && $line =~ s/usr_SIPSERVER_ModifyTuple_dnsprotocol/$args{-usr_SIPSERVER_ModifyTuple_dnsprotocol}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsprotocol_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_dnsprotocol} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_serverProfile         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_serverProfile} && $line =~ s/usr_SIPSERVER_ModifyTuple_serverProfile/$args{-usr_SIPSERVER_ModifyTuple_serverProfile}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace serverProfile_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_serverProfile} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_ipaddress         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_ipaddress} && $line =~ s/usr_SIPSERVER_ModifyTuple_ipaddress/$args{-usr_SIPSERVER_ModifyTuple_ipaddress}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ipaddress_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_ipaddress} \n");
        }
            #Replace usr_SIPSERVER_ModifyTuple_servertype         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_servertype} && $line =~ s/usr_SIPSERVER_ModifyTuple_servertype/$args{-usr_SIPSERVER_ModifyTuple_servertype}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace servertype_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_servertype} \n");
        }
            #Replace usr_SIPSERVER_ModifyTuple_dnsenabled         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_dnsenabled} && $line =~ s/usr_SIPSERVER_ModifyTuple_dnsenabled/$args{-usr_SIPSERVER_ModifyTuple_dnsenabled}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsenabled_SIPSERVER_ModifyTuple: $args{-usr_SIPSERVER_ModifyTuple_dnsenabled} \n");
        }
        
#SIPSERVER_ModifyTuple_2IPs          
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_servername         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_servername} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_servername/$args{-usr_SIPSERVER_ModifyTuple_2IPs_servername}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace servername_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_servername} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_domainname         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_domainname} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_domainname/$args{-usr_SIPSERVER_ModifyTuple_2IPs_domainname}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace domainname_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_domainname} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_dnsport         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsport} && $line =~ s/>usr_SIPSERVER_ModifyTuple_2IPs_dnsport/>$args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsport}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsport_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsport} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_dnsprotocol         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsprotocol} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_dnsprotocol/$args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsprotocol}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsprotocol_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsprotocol} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_serverProfile         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_serverProfile} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_serverProfile/$args{-usr_SIPSERVER_ModifyTuple_2IPs_serverProfile}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace serverProfile_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_serverProfile} \n");
        }      
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_ipaddress         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddress} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_ipaddress/$args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddress}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ipaddress_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddress} \n");
        }
                 #Replace usr_SIPSERVER_ModifyTuple_2IPs_ipaddres1s         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddres1s} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_ipaddres1s/$args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddres1s}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ipaddres1s_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_ipaddres1s} \n");
        }
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_servertype         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_servertype} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_servertype/$args{-usr_SIPSERVER_ModifyTuple_2IPs_servertype}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace servertype_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_servertype} \n");
        }
            #Replace usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled         
        if (exists $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled} && $line =~ s/usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled/$args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace dnsenabled_SIPSERVER_ModifyTuple_2IPs: $args{-usr_SIPSERVER_ModifyTuple_2IPs_dnsenabled} \n");
        }

#SERVICESPROFILE_ModifyTuple          
            #Replace usr_SERVICESPROFILE_ModifyTuple_servicesProfilename         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_servicesProfilename} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_servicesProfilename/$args{-usr_SERVICESPROFILE_ModifyTuple_servicesProfilename}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace servicesProfilename_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_servicesProfilename} \n");
        }      

            #Replace usr_SERVICESPROFILE_ModifyTuple_acceptencapisup         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_acceptencapisup} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_acceptencapisup/$args{-usr_SERVICESPROFILE_ModifyTuple_acceptencapisup}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace acceptencapisup_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_acceptencapisup} \n");
        }  

            #Replace usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp/$args{-usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace acceptearlysdp_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_acceptearlysdp} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_maptodnis         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_maptodnis} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_maptodnis/$args{-usr_SERVICESPROFILE_ModifyTuple_maptodnis}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace maptodnis_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_maptodnis} \n");
        }
        
            #Replace usr_SERVICESPROFILE_ModifyTuple_allowe164         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_allowe164} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_allowe164/$args{-usr_SERVICESPROFILE_ModifyTuple_allowe164}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace allowe164_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_allowe164} \n");
        }  

            #Replace usr_SERVICESPROFILE_ModifyTuple_emct         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_emct} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_emct/$args{-usr_SERVICESPROFILE_ModifyTuple_emct}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace emct_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_emct} \n");
        } 

            #Replace usr_SERVICESPROFILE_ModifyTuple_bufferacm         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_bufferacm} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_bufferacm/$args{-usr_SERVICESPROFILE_ModifyTuple_bufferacm}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace bufferacm_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_bufferacm} \n");
        }

            #Replace usr_SERVICESPROFILE_ModifyTuple_connmode         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_connmode} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_connmode/$args{-usr_SERVICESPROFILE_ModifyTuple_connmode}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace connmode_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_connmode} \n");
        }  

            #Replace usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange/$args{-usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace postAnsMediaExchange_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_postAnsMediaExchange} \n");
        }  

            #Replace usr_SERVICESPROFILE_ModifyTuple_teleprof         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_teleprof} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_teleprof/$args{-usr_SERVICESPROFILE_ModifyTuple_teleprof}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace teleprof_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_teleprof} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_alignencapsulatedisupsip         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_alignencapsulatedisupsip} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_alignencapsulatedisupsip/$args{-usr_SERVICESPROFILE_ModifyTuple_alignencapsulatedisupsip}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace alignencapsulatedisupsip_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_alignencapsulatedisupsip} \n");
        }  
            #Replace usr_SERVICESPROFILE_ModifyTuple_PrecedenceSipIsup         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_PrecedenceSipIsup} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_PrecedenceSipIsup/$args{-usr_SERVICESPROFILE_ModifyTuple_PrecedenceSipIsup}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace PrecedenceSipIsup_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_PrecedenceSipIsup} \n");
        }  
        
            #Replace usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp/$args{-usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace accptinvwosdp_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_accptinvwosdp} \n");
        }         

            #Replace usr_SERVICESPROFILE_ModifyTuple_psdp         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_psdp} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_psdp/$args{-usr_SERVICESPROFILE_ModifyTuple_psdp}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace psdp_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_psdp} \n");
        } 
        
            #Replace usr_SERVICESPROFILE_ModifyTuple_ccdigits         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_ccdigits} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_ccdigits/$args{-usr_SERVICESPROFILE_ModifyTuple_ccdigits}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ccdigits_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_ccdigits} \n");
        } 
        
            #Replace usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling/$args{-usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace enhancedretryafterhandling_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_enhancedretryafterhandling} \n");
        } 
            #Replace usr_SERVICESPROFILE_ModifyTuple_sip503Relcausehandle         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_sip503Relcausehandle} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_sip503Relcausehandle/$args{-usr_SERVICESPROFILE_ModifyTuple_sip503Relcausehandle}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sip503Relcausehandle_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_sip503Relcausehandle} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_oliinterworking         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_oliinterworking} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_oliinterworking/$args{-usr_SERVICESPROFILE_ModifyTuple_oliinterworking}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace oliinterworking_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_oliinterworking} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_olivalues         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_olivalues} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_olivalues/$args{-usr_SERVICESPROFILE_ModifyTuple_olivalues}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace olivalues_SERVICESPROFILE_ModifyTuple: $args{-usr_SERVICESPROFILE_ModifyTuple_olivalues} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok/$args{-usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace psdp_SERVICESPROFILE_noSDPIn200Ok: $args{-usr_SERVICESPROFILE_ModifyTuple_noSDPIn200Ok} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_tgrpsupport         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_tgrpsupport} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_tgrpsupport/$args{-usr_SERVICESPROFILE_ModifyTuple_tgrpsupport}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_tgrpsupport: $args{-usr_SERVICESPROFILE_ModifyTuple_tgrpsupport} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_trunkcontex         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_trunkcontex} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_trunkcontex/$args{-usr_SERVICESPROFILE_ModifyTuple_trunkcontex}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_trunkcontex: $args{-usr_SERVICESPROFILE_ModifyTuple_trunkcontex} \n");
        } 
            #Replace usr_SERVICESPROFILE_ModifyTuple_nationalDialingPrefixSupport         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_nationalDialingPrefixSupport} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_nationalDialingPrefixSupport/$args{-usr_SERVICESPROFILE_ModifyTuple_nationalDialingPrefixSupport}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_nationalDialingPrefixSupport: $args{-usr_SERVICESPROFILE_ModifyTuple_nationalDialingPrefixSupport} \n");
        } 
            #Replace usr_SERVICESPROFILE_ModifyTuple_teleprof         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_teleprof} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_teleprof/$args{-usr_SERVICESPROFILE_ModifyTuple_teleprof}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_teleprof: $args{-usr_SERVICESPROFILE_ModifyTuple_teleprof} \n");
        } 
            #Replace usr_SERVICESPROFILE_ModifyTuple_ACMCPGmappingperQ1912_5         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_ACMCPGmappingperQ1912_5} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_ACMCPGmappingperQ1912_5/$args{-usr_SERVICESPROFILE_ModifyTuple_ACMCPGmappingperQ1912_5}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_ACMCPGmappingperQ1912_5: $args{-usr_SERVICESPROFILE_ModifyTuple_ACMCPGmappingperQ1912_5} \n");
        }
            #Replace usr_SERVICESPROFILE_ModifyTuple_inbandringbackwithPMA         
        if (exists $args{-usr_SERVICESPROFILE_ModifyTuple_inbandringbackwithPMA} && $line =~ s/usr_SERVICESPROFILE_ModifyTuple_inbandringbackwithPMA/$args{-usr_SERVICESPROFILE_ModifyTuple_inbandringbackwithPMA}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace SERVICESPROFILE_inbandringbackwithPMA: $args{-usr_SERVICESPROFILE_ModifyTuple_inbandringbackwithPMA} \n");
        } 
#ACCESSLINK_ModifyTuple          
            #Replace usr_ACCESSLINK_ModifyTuple_linkname         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_linkname} && $line =~ s/usr_ACCESSLINK_ModifyTuple_linkname/$args{-usr_ACCESSLINK_ModifyTuple_linkname}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace linkname_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_linkname} \n");
        } 
            #Replace usr_ACCESSLINK_ModifyTuple_teleprof         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_teleprof} && $line =~ s/usr_ACCESSLINK_ModifyTuple_teleprof/$args{-usr_ACCESSLINK_ModifyTuple_teleprof}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace teleprof_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_teleprof} \n");
        } 
            #Replace usr_ACCESSLINK_ModifyTuple_sipserver         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_sipserver} && $line =~ s/usr_ACCESSLINK_ModifyTuple_sipserver/$args{-usr_ACCESSLINK_ModifyTuple_sipserver}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sipserver_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_sipserver} \n");
        }  
            #Replace usr_ACCESSLINK_ModifyTuple_ccaidx         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_ccaidx} && $line =~ s/usr_ACCESSLINK_ModifyTuple_ccaidx/$args{-usr_ACCESSLINK_ModifyTuple_ccaidx}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ccaidx_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_ccaidx} \n");
        } 
            #Replace usr_ACCESSLINK_ModifyTuple_teluri         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_teluri} && $line =~ s/usr_ACCESSLINK_ModifyTuple_teluri/$args{-usr_ACCESSLINK_ModifyTuple_teluri}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace teluri_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_teluri} \n");
        }
            #Replace usr_ACCESSLINK_ModifyTuple_formatPCV         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_formatPCV} && $line =~ s/<ACCESSLINK_formatPCV>usr_ACCESSLINK_ModifyTuple_formatPCV<.*>/<ACCESSLINK_formatPCV>$args{-usr_ACCESSLINK_ModifyTuple_formatPCV}<\/ACCESSLINK_formatPCV>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace formatPCV_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_formatPCV} \n");
        }
            #Replace usr_ACCESSLINK_ModifyTuple_RCCconditions302         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_RCCconditions302} && $line =~ s/usr_ACCESSLINK_ModifyTuple_RCCconditions302/$args{-usr_ACCESSLINK_ModifyTuple_RCCconditions302}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace RCCconditions302_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_RCCconditions302} \n");
        } 
            #Replace usr_ACCESSLINK_ModifyTuple_ACCESSLINK_pcv         
        if (exists $args{-usr_ACCESSLINK_ModifyTuple_ACCESSLINK_pcv} && $line =~ s/<ACCESSLINK_pcv>usr_ACCESSLINK_ModifyTuple_ACCESSLINK_pcv<.*>/<ACCESSLINK_pcv>$args{-usr_ACCESSLINK_ModifyTuple_ACCESSLINK_pcv}<\/ACCESSLINK_pcv>/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace pcv_ACCESSLINK_ModifyTuple: $args{-usr_ACCESSLINK_ModifyTuple_ACCESSLINK_pcv} \n");
        }

#ACCESSLINK_DeleteTuple          
            #Replace usr_ACCESSLINK_DeleteTuple_linkname         
        if (exists $args{-usr_ACCESSLINK_DeleteTuple_linkname} && $line =~ s/usr_ACCESSLINK_DeleteTuple_linkname/$args{-usr_ACCESSLINK_DeleteTuple_linkname}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace linkname_ACCESSLINK_DeleteTuple: $args{-usr_ACCESSLINK_DeleteTuple_linkname} \n");
        } 

#ACCESSLINK_AddTuple          
            #Replace usr_ACCESSLINK_AddTuple_linkname
        if (exists $args{-usr_ACCESSLINK_AddTuple_linkname} && $line =~ s/usr_ACCESSLINK_AddTuple_linkname/$args{-usr_ACCESSLINK_AddTuple_linkname}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace linkname_ACCESSLINK_AddTuple: $args{-usr_ACCESSLINK_AddTuple_linkname} \n");
        }    
 
            #Replace usr_ACCESSLINK_AddTuple_teleprof         
        if (exists $args{-usr_ACCESSLINK_AddTuple_teleprof} && $line =~ s/usr_ACCESSLINK_AddTuple_teleprof/$args{-usr_ACCESSLINK_AddTuple_teleprof}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace teleprof_ACCESSLINK_AddTuple: $args{-usr_ACCESSLINK_AddTuple_teleprof} \n");
        }  

            #Replace usr_ACCESSLINK_AddTuple_sipserver         
        if (exists $args{-usr_ACCESSLINK_AddTuple_sipserver} && $line =~ s/usr_ACCESSLINK_AddTuple_sipserver/$args{-usr_ACCESSLINK_AddTuple_sipserver}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace sipserver_ACCESSLINK_AddTuple: $args{-usr_ACCESSLINK_AddTuple_sipserver} \n");
        }  
 
            #Replace usr_ACCESSLINK_AddTuple_ccaidx         
        if (exists $args{-usr_ACCESSLINK_AddTuple_ccaidx} && $line =~ s/usr_ACCESSLINK_AddTuple_ccaidx/$args{-usr_ACCESSLINK_AddTuple_ccaidx}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace ccaidx_ACCESSLINK_AddTuple: $args{-usr_ACCESSLINK_AddTuple_ccaidx} \n");
        } 
#SERVERPROFILE_ModifyTuple
            #Replace usr_SERVERPROFILE_ModifyTuple_serverProfilename         
        if (exists $args{-usr_SERVERPROFILE_ModifyTuple_serverProfilename} && $line =~ s/usr_SERVERPROFILE_ModifyTuple_serverProfilename/$args{-usr_SERVERPROFILE_ModifyTuple_serverProfilename}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace serverProfilename_SERVERPROFILE_ModifyTuple: $args{-usr_SERVERPROFILE_ModifyTuple_serverProfilename} \n");
        } 
            #Replace usr_SERVERPROFILE_ModifyTuple_jipProfile         
        if (exists $args{-usr_SERVERPROFILE_ModifyTuple_jipProfile} && $line =~ s/usr_SERVERPROFILE_ModifyTuple_jipProfile/$args{-usr_SERVERPROFILE_ModifyTuple_jipProfile}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace jipProfile_SERVERPROFILE_ModifyTuple: $args{-usr_SERVERPROFILE_ModifyTuple_jipProfile} \n");
        } 
#JIPPROFILE_ModifyTuple
            #Replace usr_JIPPROFILE_ModifyTuple_jipProfilename
        if (exists $args{-usr_JIPPROFILE_ModifyTuple_jipProfilename} && $line =~ s/usr_JIPPROFILE_ModifyTuple_jipProfilename/$args{-usr_JIPPROFILE_ModifyTuple_jipProfilename}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace jipProfilename_JIPPROFILE_ModifyTuple: $args{-usr_JIPPROFILE_ModifyTuple_jipProfilename} \n");
        }
            #Replace usr_JIPPROFILE_ModifyTuple_diversionrnjip
        if (exists $args{-usr_JIPPROFILE_ModifyTuple_diversionrnjip} && $line =~ s/usr_JIPPROFILE_ModifyTuple_diversionrnjip/$args{-usr_JIPPROFILE_ModifyTuple_diversionrnjip}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace diversionrnjip_JIPPROFILE_ModifyTuple: $args{-usr_JIPPROFILE_ModifyTuple_diversionrnjip} \n");
        }
            #Replace usr_JIPPROFILE_ModifyTuple_jipdiversionrn
        if (exists $args{-usr_JIPPROFILE_ModifyTuple_jipdiversionrn} && $line =~ s/usr_JIPPROFILE_ModifyTuple_jipdiversionrn/$args{-usr_JIPPROFILE_ModifyTuple_jipdiversionrn}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace jipdiversionrn_JIPPROFILE_ModifyTuple: $args{-usr_JIPPROFILE_ModifyTuple_jipdiversionrn} \n");
        }
#NPINOAMAP_AddTuple
            #Replace usr_NPINOAMAP_AddTuple_NPINOAMAP_idx
        if (exists $args{-usr_NPINOAMAP_AddTuple_NPINOAMAP_idx} && $line =~ s/usr_NPINOAMAP_AddTuple_NPINOAMAP_idx/$args{-usr_NPINOAMAP_AddTuple_NPINOAMAP_idx}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace NPINOAMAP_idx_NPINOAMAP_AddTuple: $args{-usr_NPINOAMAP_AddTuple_NPINOAMAP_idx} \n");
        }
            #Replace usr_NPINOAMAP_AddTuple_npi
        if (exists $args{-usr_NPINOAMAP_AddTuple_npi} && $line =~ s/usr_NPINOAMAP_AddTuple_npi/$args{-usr_NPINOAMAP_AddTuple_npi}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace npi_NPINOAMAP_AddTuple: $args{-usr_NPINOAMAP_AddTuple_npi} \n");
        }
            #Replace usr_NPINOAMAP_AddTuple_noa
        if (exists $args{-usr_NPINOAMAP_AddTuple_noa} && $line =~ s/usr_NPINOAMAP_AddTuple_noa/$args{-usr_NPINOAMAP_AddTuple_noa}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace noa_NPINOAMAP_AddTuple: $args{-usr_NPINOAMAP_AddTuple_noa} \n");
        }
            #Replace usr_NPINOAMAP_AddTuple_phonecontext
        if (exists $args{-usr_NPINOAMAP_AddTuple_phonecontext} && $line =~ s/usr_NPINOAMAP_AddTuple_phonecontext/$args{-usr_NPINOAMAP_AddTuple_phonecontext}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace phonecontext_NPINOAMAP_AddTuple: $args{-usr_NPINOAMAP_AddTuple_phonecontext} \n");
        }
#NPINOAMAP_DeleteTuple
            #Replace usr_NPINOAMAP_DeleteTuple_NPINOAMAP_idx
        if (exists $args{-usr_NPINOAMAP_DeleteTuple_NPINOAMAP_idx} && $line =~ s/usr_NPINOAMAP_DeleteTuple_NPINOAMAP_idx/$args{-usr_NPINOAMAP_DeleteTuple_NPINOAMAP_idx}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace NPINOAMAP_idx_NPINOAMAP_DeleteTuple: $args{-usr_NPINOAMAP_DeleteTuple_NPINOAMAP_idx} \n");
        }
            #Replace usr_NPINOAMAP_AddTuple_npi
        if (exists $args{-usr_NPINOAMAP_DeleteTuple_npi} && $line =~ s/usr_NPINOAMAP_DeleteTuple_npi/$args{-usr_NPINOAMAP_DeleteTuple_npi}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace npi_NPINOAMAP_DeleteTuple: $args{-usr_NPINOAMAP_DeleteTuple_npi} \n");
        }
            #Replace usr_NPINOAMAP_AddTuple_noa
        if (exists $args{-usr_NPINOAMAP_DeleteTuple_noa} && $line =~ s/usr_NPINOAMAP_DeleteTuple_noa/$args{-usr_NPINOAMAP_DeleteTuple_noa}/) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name: Replace noa_NPINOAMAP_DeleteTuple: $args{-usr_NPINOAMAP_DeleteTuple_noa} \n");
        }
        
    	print OUT $line;
    	last unless ($flag == 1);
    }
    
    close IN;
    close OUT;
    $logger->debug(__PACKAGE__ . ".$sub_name: Close xml file");
    return 0 if ($flag == 0);
    
	my @required_titles;
	for (keys %args){
		if ($_ =~ /usr_SIPPROTOCOLPROFILE_ModifyTuple_sipProtocolProfilename|usr_SIPSERVER_ModifyTuple_servername|usr_SERVICESPROFILE_ModifyTuple_servicesProfilename|usr_ACCESSLINK_DeleteTuple_linkname|usr_ACCESSLINK_AddTuple_linkname|usr_SIPSERVER_ModifyTuple_2IPs_servername|usr_JIPPROFILE_ModifyTuple_jipProfilename|usr_NPINOAMAP_AddTuple_npi|usr_NPINOAMAP_DeleteTuple_npi|usr_ACCESSLINK_ModifyTuple_linkname/){
			push @required_titles, $_;
		}
	}
    
	my (@titles, @unique_titles);
	for (@required_titles){
		if ($_ =~ m/-usr_(.*)_\w/){
			push @titles, $1;
		}	
	}
	my %temp_hash; 
	grep !$temp_hash{$_}++, @titles;
	@unique_titles = keys %temp_hash;
	
	my @failed_commands;
	
	for (@unique_titles){
	    #run xml file
	    unless (@cmdResults = $self->{conn}->cmd("/opt/SoapUI-5.4.0/bin/testrunner.sh -c $_ -r $out_file")) {
	        $logger->error(__PACKAGE__ . ".$sub_name:   Could not execute command: /opt/SoapUI-5.4.0/bin/testrunner.sh -c $_ -r $out_file");
	        return 0;
	    }    
	    $logger->debug(__PACKAGE__ . ".$sub_name: Run xml file");
	    
    	$cmdResult = join("",@cmdResults);
    	$logger->debug(__PACKAGE__ . ".$sub_name: $cmdResult");	    
	    unless ($cmdResult =~ m[Receiving response\: HTTP\/1.1 200]) {
	        $logger->error(__PACKAGE__ . ".$sub_name: Execute command failed: /opt/SoapUI-5.4.0/bin/testrunner.sh -c $_ -r $out_file");
			push @failed_commands, "$_";
	    }	
	}

	unless ($#failed_commands < 0){
		$logger->error(__PACKAGE__ . ".$sub_name: Could not execute these : ". Dumper (\@failed_commands));
		return 0;
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );	
	}
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}	

=head2 B<SOAPUI()>

    This function read xml file, replace value from input and save on _new file. Then send SOAPUI request using LWP module in Perl.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        port
        username
        password
        xmlfile
        parameters 

    Optional:
        timeout: if not set, timeout = 60s
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        my %args = (
        ip => $provHost,
        port => $prov_port,
        username => $provUserName,
        password => $provPasswd,
        xmlfile => 'addServiceForUser.xml',
        parameters => {
                        usr_profileName => 'auto_test_callgrabber',
                        usr_fromRegisteredClients => 'true',
                        usr_fromTrustedNodes => 'true',
                    }
        );
        
        $obj->SOAPUI(%args);

=back

=cut

sub SOAPUI {
    my ($self, %args) = @_;
    my $sub_name = "SOAPUI";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{timeout} = $args{timeout} || 60;
    
    my $flag = 1;
    foreach ('ip', 'port', 'username', 'password', 'xmlfile') { 
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
     
    
    my @path = split(/.xml/, $args{xmlfile});
    my $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/SST/SOAP_UI_FILE/".$args{xmlfile};
    my $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/SST/SOAP_UI_FILE/".$path[0]."_new.xml";
    
    unless ( open(IN, "<$in_file")) {
        $logger->error( __PACKAGE__ . ".$sub_name: Open $in_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
 
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new xml file '$out_file' \n");
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub_name: Open $out_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    
    my ($line, $url);
    while ($line = <IN>) {
        if ($line =~ /<!--\s*URL:\s*(.+)\s*--/) {
            $url = $1;
            $url =~ s/ProvisioningHost/$args{ip}:$args{port}/;
        }
        elsif ($line =~ /<.*DBVERSION.*>/){
            $line =~ s/DBVersion/$args{dbversion}/;
        }
        elsif ($line =~ /<.+>(.+)<\/.+>/ && exists $args{parameters}{$1}) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace parameter '$1' with value '$args{parameters}{$1}' \n");
            my $k = $1;
            $line =~ s/$k/$args{parameters}{$k}/;
        }
        print OUT $line;        
    }
    
    close IN;
    close OUT;
    return 0 unless ($flag);
    $logger->debug(__PACKAGE__ . ".$sub_name: URL: $url "); 
    
    my @message = $self->execCmd("cat $out_file");  
    $logger->debug(__PACKAGE__ . ".$sub_name ...... : " .Dumper(\@message));
    my $userAgent = LWP::UserAgent->new(keep_alive => 1 );
    $userAgent->ssl_opts(verify_hostname => 0);
    $userAgent->ssl_opts( SSL_verify_mode => 0 );
    
    my $message = join("",@message);
    $logger->debug(__PACKAGE__ . ".$sub_name ...... : " .$message);
    my  $request = HTTP::Request->new(POST => $url);
    
    $request->header('Authorization',  "Basic " . MIME::Base64::encode("$args{username}:$args{password}", '') );
    $request->header(SOAPAction => "");
    $request->content_type("application/xml");
    $request->content($message);
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Run SOAPUI request  ");
    my $response = $userAgent->request($request);
    
    $logger->info(__PACKAGE__ . ".$sub_name: --> Run file $args{xmlfile} completely. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub  ");
    return $response;
}

=head2 B<suMtcOneUnit()>

    This function perform action (load/lock/unload/unlock) on MTC Service Units. 

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
    my $flag=1;

    my $prevPrompt = $self->{conn}->prompt('/>/');
    if (grep /sg to query does not exist/, $self->execCmd("aim service-unit show $args{-SU}")){
        $logger->error(__PACKAGE__ . ".$sub_name: $args{-SU} does not exist in the database");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
		return 0;
    }
    sleep(3); 
    if ($args{-action} =~ /lock/) {
        my $cmd = ($args{-seti} =~ /y/) ? "aim service-unit $args{-action} $args{-SU} $args{-unit} i" : "aim service-unit $args{-action} $args{-SU} $args{-unit}";
		if (grep/\%Error/, @cmd_result = $self->execCmd($cmd, 300)){
		    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
		} 	
        if (grep/continue\?/, @cmd_result) {
		    if (grep/\%Error/, $self->execCmd("y", 300)){
		        $logger->error(__PACKAGE__ . ".$sub_name: Cannot confirm continue");
                $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
                return 0;
		    }		
        }
    } else {
        my $cmd = ($args{-seti} =~ /y/) ? "aim service-unit $args{-action} $args{-SU} $args{-unit} i" : "aim service-unit $args{-action} $args{-SU} $args{-unit}";
		if (grep/\%Error/, @cmd_result = $self->execCmd($cmd, 300)){
		    $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd' ");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
		}
    }
    if($args{-action} =~ /unlock/){
        my $i = 0;
        my $j = 5;
        do {
            sleep(30);
            @cmd_result = $self->execCmd("aim si-assignment show $args{-SU}");
            $command_result = join ' ', @cmd_result;
            if(($command_result =~ /standby/) && ($command_result =~ /active/)){
                $i = 1;
            } else {
                $j--;
            }
        } while ($i == 0 && $j > 0);
        if($i == 0 && $j <=0){
            $logger->error(__PACKAGE__ . ".$sub_name: Cannot get unit active after unlock ");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
        }
    }
    sleep(5);
    unless(@cmd_result = $self->execCmd("aim service-unit show $args{-SU}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command 'aim service-unit show $args{-SU}' ");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
		return 0;
    }
	foreach (@cmd_result) {
		$unit_info = $1 if $_ =~ m/($args{-SU}\s+$args{-unit}.*)/;
	}	
    $logger->error(__PACKAGE__ . ".$sub_name: ##################$unit_info");
	unless ($unit_info) {
		$logger->error(__PACKAGE__ . ".$sub_name: Cannot get unit info ");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
		return 0;		
	}	
    if ($args{-action} =~ /^[lock|load]/) {
		unless (grep /locked     enabled    out-of-service/, $unit_info){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to lock $args{-SU}");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
        }
	}
    if ($args{-action} =~ /unload/) {
		unless (grep /offline    disabled   out-of-service/, $unit_info){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to unload $args{-SU}");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
        }
	}
    if ($args{-action} =~ /unlock/) {
		unless (grep /unlocked   enabled    in-service/, $unit_info){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to unlock $args{-SU}");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
            return 0;
        }
	}
    $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
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

sub execCmd{
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
      $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
      return 0;
   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub_name ...... : @cmdResults");
   $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub ");
   return @cmdResults;
}

1;












