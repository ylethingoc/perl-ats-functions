package SonusQA::TOOLS;

=head1 NAME

SonusQA::TOOLS- Perl module for any tools

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::TOOLS->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               );

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for Any TOOL installed on Linux server.

=head2 METHODS

=cut



use strict;
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use File::Basename;
use Module::Locate qw(locate);
use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase SonusQA::TOOLS::TOOLSHELPER);

=head2 C< doInitialization >

    Routine to set object defaults and session prompt.

=over

=item Arguments:

        Object Reference

=item Returns:

        None 

=back

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{DECODETOOL} ||= '/usr/local/bin/decodetool';
    $self->{CLOUD_PLATFORM} = '';
    $self->{LOCATION} = locate __PACKAGE__ ;

}

=head2 C< setSystem >

    This function sets the system information and Prompt.

=over

=item Arguments:

	Object Reference

=item Returns:

	Returns 0 - If succeeds 
	Reutrns 1 - If Failed

=back

=cut

sub setSystem(){
    my($self)=@_;
    my $subName = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName:  <-- Entering sub");
    my($cmd,$prompt, $prevPrompt);
    #TOOLS-71109:Checking for windows server
    my @res = $self->{conn}->cmd("bash");
    if(grep /'bash'\sis\snot\srecognized.*\s+.*/ ,@res){
        $logger->debug(__PACKAGE__. "$subName:Skipping set prompt and other commands as it is a windows server");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
        return 1; 
    }
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    #changed cmd() to print() to fix, TOOLS-4974
    unless($self->{conn}->print($cmd)){
        $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }

    unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->last_prompt);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $self->{conn}->cmd("TMOUT=72000"); 
    $self->{conn}->cmd("stty cols 150");
    $self->{conn}->cmd('echo $TERM');
    $self->{conn}->cmd('export TERM=xterm');
    $self->{conn}->cmd('echo $TERM');
    #Setting the Platform type 
    my @platform = $self->{conn}->cmd('uname');
    $self->{PLATFORM} =  ($platform[0] =~ /Linux/i) ? 'linux' : 'SunOS';
    my ($platform)=$self->execCmd("dmidecode -s system-product-name");
    $logger->debug(__PACKAGE__ . ".$subName: \$platform=$platform");
    if ($platform =~ /hvm|c5|m5/i){
        $self->{CLOUD_PLATFORM}= "AWS";
    }
    elsif($platform =~ /openstack/i){
        $self->{CLOUD_PLATFORM}= "OpenStack";
    }
    elsif($platform=~ /google/i){
        $self->{CLOUD_PLATFORM}= "Google Compute Engine";
    }
    $logger->debug(__PACKAGE__ . ".$subName:\$self->{CLOUD_PLATFORM}=$self->{CLOUD_PLATFORM}");
    #removing alias if any exists 
    $self->execCmd("unalias rm"); 
    $self->execCmd('unalias grep'); #TOOLS-71616

    # Fix to TOOLS-4696. The default value is India Time Server. Please add NTP->1->IP and NTP->1->TIMEZONE in case you don't have to use default values.   
     if ($self->{NTP_SYNC} =~ m/y(?:es)?|1/i) {                                     #Fix to TOOLS-4696
        my $ntpserver = $self->{NTP_IP} || "10.128.254.67";
        my $ntptimezone = $self->{NTP_TZ} || "Asia/Calcutta";
        $self->{conn}->cmd("export TZ=$ntptimezone");
        if ($self->{PLATFORM} eq 'linux' ) {
            $cmd = "sudo ntpdate -s $ntpserver";
            } else {
            $cmd = "sudo /usr/sbin/ntpdate -u $ntpserver";
            } 
        my @r = ();
        unless ( @r = $self->{conn}->cmd($cmd) ) {
	    $logger->error(__PACKAGE__ . ".$subName: Could not execute command for NTP sync. errmsg: " . $self->{conn}->errmsg); 
        }
        $logger->info(__PACKAGE__ . ".$subName: NTP sync was successful");
    }
    $self->{conn}->cmd("set +o history");
    $logger->debug(__PACKAGE__ . ".$subName:  <-- Leaving sub[1]");
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

   my $retries = 0;
   RETRY:
   $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
      $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
      $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);

      #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
      $logger->debug(__PACKAGE__ . ".execCmd  Sending ctrl+c");
      unless($self->{conn}->cmd(-string => "\cC")){
        $logger->warn(__PACKAGE__ . ".execCmd  Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);

        #Reconnect in case ctrl+c fails.
        $logger->warn(__PACKAGE__ . ".execCmd  Trying to reconnect...");
        unless( $self->reconnect() ){
            $logger->warn(__PACKAGE__ . ".execCmd Failed to reconnect.");
	    &error(__PACKAGE__ . ".execCmd CMD ERROR - EXITING");
        }
      }
      else {
        $logger->info(__PACKAGE__ .".exexCmd Sent ctrl+c successfully.");
      }

      if (!$retries && $self->{RETRYCMDFLAG}) {
          $retries = 1;
          goto RETRY;
      }
   }
   chomp(@cmdResults);
   @cmdResults = grep /\S/, @cmdResults;
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
   return @cmdResults;
}

=head2 C< DETSROY() >

    This function does same as the DETSROY in Base.pm , except that it kills all the process started in this shell

=over

=item Arguments:

 Object Reference

=item Return Value:

 None

=item Example:

    $obj->DESTRY();

=back

=cut


sub DESTROY {
    my ($self)=@_;
    my ($logger);
    my $sub = 'DESTROY';
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    #if($self->can("gatherStats")){
    #   $self->gatherStats();
    #}
    unless($self->{OBJ_USER} eq "root"){
        $logger->debug(__PACKAGE__ . ".$sub: Killing all the process started in this shell");
        $self->execCmd("ps | grep -v \'ps\\\|PID\\\|grep\\\|tcsh\\\|awk\\\|bash\' | awk \'{print \$1}\' | xargs kill -2");
    }

    if($self->can("_DUMPSTACK") && defined($self->{DUMPSTACK}) && $self->{DUMPSTACK}){
        $self->_DUMPSTACK();
    }else{
         $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE DUMPSTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    if($self->can("_REVERSESTACK")  && defined($self->{STACK}) && @{$self->{STACK}}){
        $self->_REVERSESTACK();
    }else{
         $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE REVERSESTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }

    if($self->can("_COMMANDHISTORY") && defined($self->{HISTORY}) && @{$self->{HISTORY}}){
        $self->_COMMANDHISTORY();
    }else{
         $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE COMMANDHISTORY METHOD (OR NO HISTORY IS AVAILABLE)");
    }

    if($self->can("resetNode")){
        $self->resetNode();
    }
    $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

=head2 C< startDNSServerScript() >

    Start DNS simulation script.

=over

=item Arguments:

    Hash with below details
        - Mandatory
	        -hostip               : IP of the host to where dns script has to be copied and started
            -hostpasswd           : Password of the remote host
	        -sourceFilePath       : Local path to DNS script
        - Optional 
	        -identity_file        : Path to key file if password in not specified above

=item Return Value:

    1 - On successful start of DNS script.
    0 - Failure

=item Example:

	my $obj = SonusQA::ATSHELPER::newFromAlias(
									-tms_alias => 'bats12_npalleda', 
									-ignore_xml => 0, -sessionLog => 1, 
									-iptype => 'any', 
									-return_on_fail => 1);

    my %args;
    $args{-hostip} = 'bats12';
    $args{-sourceFilePath} = '/tmp/dnsserver_1.pl';
    $args{-identity_file} = '/home/npalleda/.ssh/id_rsa';

    unless($obj->startDNSServerScript(%args)){
	    $logger->info(__PACKAGE__ . ".$sub Unable to start DNS script."); 
        return 0;
    }

=back

=cut

sub startDNSServerScript {
	my ($self, %args) = @_;

	my $result;
	my $sub = "startDNSServerScript";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->info(__PACKAGE__ . " Entered $sub.");

	my $dirname = "dns_" . time();
	my $cmd = "mkdir -p /tmp/$dirname";
	my @output = $self->execCmd($cmd);

	# We may get the request to implement below command. 
	# sed '/new Net::DNS::Nameserver.*/i $Myaddress = 10.54.81.11; $Myport = 5353;' /tmp/dnsserver_1.pl

	my %scpArgs;
	$scpArgs{-hostip} = $args{-hostip};
	$scpArgs{-hostuser} = $args{-hostuser};
	$scpArgs{-hostpasswd} = $args{-hostpasswd};
	$scpArgs{-sourceFilePath} = $args{-sourceFilePath};
	$scpArgs{-destinationFilePath} = $args{-hostip} . ":/tmp/$dirname/dnsserver.pl";
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
	    $logger->error(__PACKAGE__ . ".$sub Could not scp file " . $scpArgs{-sourceFilePath}); 
		return 0;
	}

	$cmd = "nohup perl /tmp/$dirname/dnsserver.pl > /tmp/$dirname/dnsserver.log 2>&1 &";
	@output = $self->execCmd($cmd);
	$logger->info(@output);

	# It takes couple of seconds to dns script to bind
	sleep(5);

	$cmd = "cat /tmp/$dirname/dnsserver.log";
	@output = $self->execCmd($cmd);
    if(grep /- done./, @output){
	    $logger->info(__PACKAGE__ . ".$sub Started DNS script."); 
		$result = 1;
    }else{
	    $logger->error(__PACKAGE__ . ".$sub Failed to start dns script."); 
		$result = 0;
	}

	$logger->info(__PACKAGE__ . " Leaving $sub [$result].");
	return $result;
}

=head2 C< stopDNSServerScript() >

    Stop DNS simulation script.

=over

=item Arguments:

    None

=item Return Value:

    1 - On successful stop of DNS script.
    0 - Failure

=item Example:

	my $obj = SonusQA::ATSHELPER::newFromAlias(
									-tms_alias => 'bats12_npalleda', 
									-ignore_xml => 0, -sessionLog => 1, 
									-iptype => 'any', 
									-return_on_fail => 1);

    unless($obj->stopDNSServerScript){
	    $logger->info(__PACKAGE__ . ".$sub Unable to stop DNS script."); 
        return 0;
    }

=back

=cut

sub stopDNSServerScript {
	my ($self, %args) = @_;

	my $sub = "stopDNSServerScript";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->info(__PACKAGE__ . " Entered $sub.");

	my $cmd = "kill -9 \$(pgrep -f dnsserver.pl)";
	my @output = $self->execCmd($cmd);
	$logger->info(@output);

	# We assume only one dnsserver.pl will be run per server, because they want to bind to only port 53
	$cmd = "pgrep -f dnsserver.pl | wc -l";
	@output = $self->execCmd($cmd);
	if($output[0] > 0){
	    $logger->info(__PACKAGE__ . " Leaving $sub [0].");
	    return 0;
    }

	$logger->info(__PACKAGE__ . " Leaving $sub [1].");
	return 1;
}


1;
