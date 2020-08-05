package SonusQA::SWITCH;

=head1 NAME

SonusQA::SWITCH- Perl module for any switch

=head1 AUTHOR

Rohit Baid - rbaid@sonusnet.com

=head1 IMPORTANT

This module has only been tested with ProCurve switch. Might not work for other switches.

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::SWITCH->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name >',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               );

=head1 REQUIRES

Log::Log4perl, SonusQA::Base  

=head1 DESCRIPTION

This module provides an interface for Any SWITCH installed on Linux server.

=head2 METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper qw(Dumper);
our @ISA = qw(SonusQA::Base);


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
    my($self)=@_;
    my $sub="doInitialization()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Entered sub");

    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*\-.*\-.*#/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; 
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub");
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
   my $sub = "execCmd()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my(@cmdResults,$timestamp);
   $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
   unless($timeout) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub Timeout not specified. Using DEFAULTTIMEOUT, $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub Timeout specified as $timeout seconds ");
   }
 
   $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
   unless ( @cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return" )) {
      $logger->error(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
      $logger->error(__PACKAGE__ . ".$sub errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");

      #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
      $logger->error(__PACKAGE__ . ".$sub  Sending ctrl+c");
      unless($self->{conn}->cmd(-string => "\cC")){
        $logger->warn(__PACKAGE__ . ".$sub  Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);

        #Reconnect in case ctrl+c fails.
        $logger->warn(__PACKAGE__ . ".$sub  Trying to reconnect...");
        unless( $self->reconnect() ){
            $logger->warn(__PACKAGE__ . ".$sub Failed to reconnect.");
            &error(__PACKAGE__ . ".$sub CMD ERROR - EXITING");
        }
      }
      else {
        $logger->info(__PACKAGE__ .".$sub Sent ctrl+c successfully.");
      }
   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub : ". Dumper \@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub  <-- Leaving sub");
   return @cmdResults;
}

=head2 C< enablePort()>

    This function enables the specified port.

=over

=item Arguments:

    1. -port

=item Return Value:

    1 - If Success 
    0 - If Failure

=item Example:

    unless($switch_obj->enablePort(-port => 'A7')) {
        $logger->error(__PACKAGE__ . ".$subName:  Could not enable port");
        return 0;
    }

=back

=cut

sub enablePort {
   my($self,%args)=@_; 
   my $sub = "enablePort()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Entered sub");
   
   unless($args{-port}) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory argument port not specified.");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
       return 0;
   }
   my $flag=0;

   my @cmd=("configure","interface $args{-port} enable","exit");
   for (@cmd) {
       $logger->debug(__PACKAGE__ . ".$sub : Executing $_");
       unless($self->execCmd($_)) {
           $logger->error(__PACKAGE__ . ".$sub: Failed to execute command - $_.");
  	   $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[$flag]");
 	   $flag=-1;
           last;
       }
   }
   return 0 if($flag==-1);

   my $status;
   foreach (1..5) {
       $logger->debug(__PACKAGE__ . ".$sub : Waiting for one second.");
       sleep(1);
       $logger->debug(__PACKAGE__ . ".$sub : Checking if port is enabled.");
       unless($status=$self->getPortStatus(%args)) {
	   $logger->error(__PACKAGE__ . ".$sub: Failed to get status.");
	   last;
       }
       if($status =~ /Up/i){
	   $flag=1;
           last;
       }
   } 
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[$flag]");
   return $flag;
}

=head2 C< disablePort() >

    This function disables the specified port.

=over

=item Arguments:

    1. -port

=item Return Value:

    1 - If Success
    0 - If Failure 

=item Example:

    unless($switch_obj->disablePort(-port => 'A7')) {
        $logger->error(__PACKAGE__ . ".$subName:  Could not disable port");
       return 0;
   }

=back

=cut

sub disablePort {
   my($self,%args)=@_;
   my $sub = "disablePort()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Entered sub");

   unless($args{-port}) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory argument port not specified.");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
       return 0;
   } 
   my $flag = 0;

   my @cmd=("configure","interface $args{-port} disable","exit"); 
   for (@cmd) {
       $logger->debug(__PACKAGE__ . ".$sub : Executing $_\n");
       unless($self->execCmd($_)) {
           $logger->error(__PACKAGE__ . ".$sub: Failed to execute command - $_.");
	   $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[$flag]");
           $flag = -1;
           last;
       }
   }
   return 0 if($flag == -1);

   my $status;
   foreach (1..5) {
       $logger->debug(__PACKAGE__ . ".$sub : Waiting for one sec.");
       sleep(1);
       $logger->debug(__PACKAGE__ . ".$sub : Checking if port is disabled.");
       unless($status=$self->getPortStatus(%args)) {
           $logger->error(__PACKAGE__ . ".$sub: Failed to get status.");
           last;
       }
       if($status =~ /Down/i) {
	   $flag = 1;
	   last;
       }	
   }
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[$flag]");
   return $flag;
}

=head2 C< getPortStatus>
   
    This function checks status of specified port.

=over

=item Arguments:

    1. -port 

=item Return Value:

    Status(Up or Down) - If Success
    0 - If Failure

=item Example:

    unless($status = $self->getPortStatus(-port => 'A7')){
       $logger->debug(__PACKAGE__ . ".$sub: Failed to get status.");
       return 0;
    }

=back

=cut 

sub getPortStatus {
   my ($self,%args)=@_;
   my $sub = "getPortStatus()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Entered sub");
   
   unless($args{-port}) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory argument port not specified.");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
       return 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub: Getting status for port $args{-port}");	  

   my @cmdResult = $self->execCmd("show int custom $args{-port} status");
   my $status = (@cmdResult) ? $cmdResult[-2] : 0;
   $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[$status]");
   return $status;
}

1;
