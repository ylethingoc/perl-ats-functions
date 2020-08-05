package SonusQA::IXIA;

=head1 NAME

SonusQA::IXIA- Perl module to Interact with IXIA Server.

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION
This modules will give a interface to invoke IXIA tcl commands

=head1 METHODS

=cut

use Exporter;
use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw /locate/;
use File::Basename;
use SonusQA::Base;

our $VERSION = '1.0';
our @ISA = qw(Exporter SonusQA::Base);
our @EXPORT = qw(setIxiaParam);#adding subroutine setIxiaParam to export as this subroutine was earlier there at the path SONUSQA::SBX5000::PERFHELPER.pm


=head1 doInitialization()

=over

=item DESCRIPTION:

This function is to set object defaults

=back

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    my $sub = 'doInitialization' ;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{PROMPT} = '/.*[\$%#\}\|\>] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{TCLSHELL} = 1;
    $self->{LOCATION} = locate __PACKAGE__ ;
    $self->{DEFAULTTIMEOUT} = 60;
    $self->{PATH}  = "";
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head1 setSystem()

=over

=item DESCRIPTION:

This function sets the system variables and Prompt.

=back

=cut

sub setSystem(){
   my($self)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
   my $sub = 'setSystem';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   my($cmd,$prompt, $prevPrompt);
   $self->{conn}->cmd("bash");
  
   $self->{conn}->cmd('export PATH=$PATH:/ats/tools/IXIA_6.60GA/bin');
   $self->{conn}->cmd('export IXIA_HOME=/ats/tools/IXIA_6.60GA/');
   $self->{conn}->cmd('export IXIA_VERSION=6.60');
   $self->{conn}->cmd('export TCLLIBPATH=${IXIA_HOME}/lib/');
   $self->{conn}->cmd('export IXLOAD_6_40_59_6_INSTALLDIR=/ats/tools/IXIA_6.60GA/lib/IxLoad6.40-GA/');

   my @basic_cmd = ('tclsh', 'package req IxTclHal', "ixConnectToTclServer $self->{IXIA_SERVER}", "ixConnectToChassis $self->{IXIA_SERVER}");
   foreach (@basic_cmd) {
       unless ($self->{conn}->cmd(String => $_, Timeout => $self->{DEFAULTTIMEOUT},Prompt => '/% /')) {
           $logger->error(__PACKAGE__ . ".$sub: failed run \'$_\'");
           $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
           $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
       }
   }

   my @temp_result = ();
   unless (@temp_result = $self->{conn}->cmd(String => "chassis cget -id", Timeout => $self->{DEFAULTTIMEOUT},Prompt => '/% /')) {
       $logger->error(__PACKAGE__ . ".$sub: failed get chassis id");
       $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
   }

   chomp @temp_result;
   $self->{chasID} = $temp_result[0];
   $self->{chasID} =~ s/\s//g;

   unless ($self->{chasID} =~ /^\d+$/) {
       $logger->error(__PACKAGE__ . ".$sub: failed get chassis id, returned value $self->{chasID}");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub got the chassis id - $self->{chasID}");
   $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->last_prompt);
   $self->{conn}->cmd('set +o history');
   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 execCmd()

=over

=item DESCRIPTION: 

The function is used to execute any command

=item ARGUMENTS:
    Mandatory Args:
        1st arg - command to be executed

    Optional Args:
        timeout for the execution of command

=item RETURNS:

array - Command output 
0 - Failure

=item EXAMPLE: 

unless ( $liObj->execCmd('port set 1 2 2') ) {
    $logger->error("__PACKAGE__ . ".$subName: failed execute port set 1 2 2");
    return 0;
}

=back

=cut

sub execCmd{
    my ($self,$cmd, $timeout)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
    my(@cmdResults,$timestamp);

    $timeout ||= $self->{DEFAULTTIMEOUT};

    $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");

    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command 
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        return @cmdResults;
    }
    sleep 1;  #adding a sleep of 1 sec after execution of command ( IXIA need a sleep of least 1 sec)
    chomp @cmdResults;
    @cmdResults = grep /\S/, @cmdResults;
    $logger->info(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    $logger->info(__PACKAGE__ . ".execCmd: <-- Leaving Sub [output]");
    return @cmdResults;
}

=head1 execIxiaCmd()

=over

=item DESCRIPTION: 

The function is used to execute any IXIA tcl commands, last line of the output is zero states the succesful execution of command

=item ARGUMENTS:

    Mandatory Args:
    1st arg - command to be executed

    Optional Args:
    Array of possible errors which definds the failure of command

=item RETURNS:

1/Array - Command output 
0 - Failure

=item EXAMPLE: 

my $cmd = "port write 1 2 2";
my @errors = ('No connection to a chassis', 'Invalid port number', 'The port is being used by another user', 'Network error between the client and chassis');

unless ($self->execIxiaCmd($cmd, @errors) ) {
  $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub execIxiaCmd() {
   my ($self, $cmd, @errors) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execIxiaCmd");
   my $sub = 'execIxiaCmd';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   unless ($cmd ) {
      $logger->error(__PACKAGE__ . ".$sub: manditory argument command is empty");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   my $pattern = '';
   $pattern = '(' . join('|',@errors) . ')' if (@errors);

   unless ( $self->{conn}->put(-string => $cmd. $self->{conn}->output_record_separator , -timeout   => $self->{DEFAULTTIMEOUT})) {
      $logger->error(__PACKAGE__ . ".$sub: unable to execute \'$cmd\'");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   my ($prematch, $match, @output);

   if (@errors) {
      unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/' . $pattern. '/i',
                                                             -match     => $self->{PROMPT},
                                                             -timeout   => $self->{DEFAULTTIMEOUT})){
         $logger->error(__PACKAGE__ . ".$sub: could not match for any expected prompt after the excution of \'$cmd\'");
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
      }
   } else {
      unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT})){
         $logger->error(__PACKAGE__ . ".$sub: could not match for any expected prompt after the excution of \'$cmd\'");
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
      }
   }

   if ($pattern and $match =~ /$pattern/i) {
      $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' failed with error \'$1\'");
      $self->{conn}->waitfor( -match     => $self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   } elsif ( $match =~ /.*[\$%#\}\|\>].*$/) {
      @output = split('\n', $prematch);
      chomp @output;
      @output = grep /\S/, @output;
   } else {
      $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' failed with unknown error");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   unless ($output[-1] == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' failed with return code $output[-1]");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub: \'$cmd\' output is -> ". Dumper(\@output));
   sleep 1;  #adding a sleep of 1 sec after execution of command ( IXIA need a sleep of least 1 sec)
   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1/output]");
   return (wantarray ? @output : 1);
}

=head1 portProfileLoad()

=over

=item DESCRIPTION: 

This function is used to import configuration on required card and port, and write the configuration to hardware

=item ARGUMENTS:

    Mandatory Args:
        -file => config file to import
        -cardID => cardid
        -portID => portid

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE: 

unless ($self->portProfileLoad(-file => '/home/rpateel/Ramesh_Anh_test.prt', -cardID => 2, -portID => 2) ) {
  $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub portProfileLoad() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".portProfileLoad");
   my $sub = 'portProfileLoad';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-file', '-cardID', '-portID') {
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
      }
   }

   my $cmd = "port import $args{-file} $self->{chasID} $args{-cardID} $args{-portID}";
   my @errors = ('No connection to a chassis', 'Invalid port', 'The card is owned by another user', 'fileName does not exist');

   unless ($self->execIxiaCmd($cmd, @errors) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to port");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $cmd = "port write $self->{chasID} $args{-cardID} $args{-portID}";
   @errors = ('No connection to a chassis', 'Invalid port number', 'The port is being used by another user', 'Network error between the client and chassis');

   unless ($self->execIxiaCmd($cmd, @errors) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $cmd = "ixTakeOwnership [list [list $self->{chasID} $args{-cardID} $args{-portID}]]";
   unless ($self->execIxiaCmd($cmd)) {
      $logger->error(__PACKAGE__ . ".$sub: failed to execut \'$cmd\'");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
   }

   $cmd = "set portlist [list [list $self->{chasID} $args{-cardID} $args{-portID}]]";
   $self->{port_data} = "$self->{chasID} $args{-cardID} $args{-portID}";
   unless ($self->execCmd($cmd)) {
      $logger->error(__PACKAGE__ . ".$sub: failed to execut \'$cmd\'");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
   }

   $logger->info(__PACKAGE__ . ".$sub successfully loaded the profile");
   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 portCleanUp()

=over

=item DESCRIPTION: 

This function is used to cleanup previous port configuration

=item ARGUMENTS:

NONE

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE:

unless ($self->portProfileLoad() ) {
  $logger->error(__PACKAGE__ . ".$sub: portProfileLoad failed");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub portCleanUp() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".portCleanUp");
   my $sub = 'portCleanUp';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   my $cmd = "port reset $self->{port_data}";
   my @errors = ('No connection to a chassis', 'Invalid port number', 'The port is being used by another user');

   unless ($self->execIxiaCmd($cmd, @errors) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   } 

   $cmd = "ixWriteConfigToHardware portlist";
   unless ($self->execIxiaCmd($cmd)) {
      $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 cardProfileLoad()

=over

=item DESCRIPTION: 

This function is used to import configuration on required card, and write the configuration to hardware

=item ARGUMENTS:

    Mandatory Args:
        -file => config file to import
        -cardID => cardid

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE: 

unless ($self->cardProfileLoad(-file => '/home/rpateel/Ramesh_Anh_test.prt', -cardID => 2) ) {
  $logger->error(__PACKAGE__ . ".$sub: failed to import the configuration to card");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub cardProfileLoad() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".portCleanUp");
   my $sub = 'portCleanUp';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-file', '-cardID') {
      unless ($args{$_}) {
          $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
          $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
          return 0;
      }
   }

   my $cmd = "card import $args{-file} $self->{chasID} $args{-cardID}";
   my @errors = ('No connection to a chassis', 'Invalid card', 'The card is owned by another user', 'fileName does not exist');

   unless ($self->execIxiaCmd($cmd, @errors) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to card");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $cmd = "card write $self->{chasID} $args{-cardID}";     
   unless ($self->execIxiaCmd($cmd) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to card");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 cardCleanUp()

=over

=item DESCRIPTION: 

This function is used to cleanup the previous card configuration

=item ARGUMENTS:

    Mandatory Args:
        NONE

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE: 

unless ($self->cardCleanUp() ) {
  $logger->error(__PACKAGE__ . ".$sub: cardCleanUp failed");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub cardCleanUp() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".portCleanUp");
   my $sub = 'portCleanUp';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");


   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 startTransmit()

=over

=item DESCRIPTION: 

This function is used to start the packet transmission from required card,port, Check the link state before transmission

=item ARGUMENTS:

    Mandatory Args:
        -cardID => cardid
        -portID => portid

=item RETURNS:

    1 - Success 
    0 - Failure

=item EXAMPLE: 

unless ($self->startTransmit() ) {
  $logger->error(__PACKAGE__ . ".$sub: failed start transmission");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub startTransmit() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startTransmit");
   my $sub = 'startTransmit';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-cardID', '-portID') {
      unless ($args{$_}) {
          $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
          $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
          return 0;
      }
   }

   my @cmd = ("ixCheckLinkState [list [list $self->{chasID} $args{-cardID} $args{-portID}]]", "ixClearPortStats $self->{chasID} $args{-cardID} $args{-portID}", "ixStartPortTransmit $self->{chasID} $args{-cardID} $args{-portID}");

   foreach my $command (@cmd) {
      unless ($self->execIxiaCmd($command)) {
         $logger->error(__PACKAGE__ . ".$sub: failed to run command -> $command");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
      }
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 stopTransmit()

=over

=item DESCRIPTION: 

This function is used to stop the packet transmission from required card,port

=item ARGUMENTS:

    Mandatory Args:
        -cardID => cardid
        -portID => portid

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE: 

unless ($self->stopTransmit() ) {
  $logger->error(__PACKAGE__ . ".$sub: failed stop transmission");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub stopTransmit() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".stopTransmit");
   my $sub = 'stopTransmit';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-cardID', '-portID') {
      unless ($args{$_}) {
          $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
          $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
          return 0;
      }
   }

   my $cmd = "ixStopPortTransmit $self->{chasID} $args{-cardID} $args{-portID}";
   unless ($self->execIxiaCmd($cmd) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to card");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 checkTransmitStatus()

=over

=item DESCRIPTION: 

This function is used to check the packet transmission status of required card,port

=item ARGUMENTS:

    Mandatory Args:
        -cardID => cardid
        -portID => portid

=item RETURNS:

1 - Success 
0 - Failure

=item EXAMPLE: 

unless ($self->checkTransmitStatus() ) {
  $logger->error(__PACKAGE__ . ".$sub: failed get transmission status");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

=back

=cut

sub checkTransmitStatus() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".checkTransmitStatus");
   my $sub = 'checkTransmitStatus';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-cardID', '-portID') {
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
      }
   }

   my $cmd = "ixCheckPortTransmitDone $self->{chasID} $args{-cardID} $args{-portID}";
   unless ($self->execCmd($cmd) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to card");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 statsCollect()

=over

=item DESCRIPTION: 

This function is used collect the required stats of operation

=item ARGUMENTS:

    Mandatory Args:
        -cardID => cardid
        -portID => portid
        -stats => array referance indicating required stats

=item RETURNS:

hash - of all required stats 
0 - Failure

=item EXAMPLE: 

    unless ($self->statsCollect(-cardID => 2, -portID => 2, -stats => ['bytesSent', 'framesReceived', 'framesSent', 'oversize']) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to get required stats");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
    }

=back

=cut


sub statsCollect() {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".statsCollect");
   my $sub = 'statsCollect';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-cardID', '-portID') {
      unless ($args{$_}) {
          $logger->error(__PACKAGE__ . ".$sub: manditory argument \'$_\' empty");
          $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
          return 0;
      }
   }

   my @stats = @{$args{-stats}};

   unless (@stats) {
      $logger->error(__PACKAGE__ . ".$sub: manditory argument $args{-stats} is empty");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   my $cmd = "statList get $self->{chasID} $args{-cardID} $args{-portID}";
   unless ($self->execIxiaCmd($cmd) ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to load the profile to card");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
      return 0;
   }

   my %result = ();
   foreach (@stats) {
      my @temp = ();
      unless (@temp = $self->execCmd("statList cget -$_")) {
          $logger->error(__PACKAGE__ . ".$sub: failed to get $_ stats");
          return 0;
      }
      if (grep (/Invalid statistic for this port type/, @temp)) {
          $logger->error(__PACKAGE__ . ".$sub: failed to get $_ stats");
          return 0;
      }
      $result{$_} = join(',', @temp);
   }

   $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return %result;
}

=head1 setIxiaParam()

=over

=item DESCRIPTION:

This subroutine helps to load the ixia profile and change some of the ixia profile parameters and save the changes,
The following are the various tasks done by the subroutine

1. loads ixiaProfile accourding the profile path, card id and the port id passed in the hash to the subroutine.
2. gets the current Stream configuration 
3. sets the stream parameters i.e  destination MAC address, frame size, DoS packets pumping rate in either fps rate or bps rate or in percent packet rate accourding to the stream parameters passed in hash to the subroutine  
4. gets the current IP configuration
5. sets IP parameters accourding to the IP version passed in the hash, if the parameter IPversion is not passed, the subroutine sets for ipv4.
6. sets the Ip parameters i.e destinatio Ip Address, destination Ip Mask, destination Ip Address Repeat Count, source Ip Addrress, source Ip Mask, source Ip Address Repeat Count accourding to the ip parameters passed in hash to the subroutine the keys for ipv4 IP parameters are:
    destIpAddr, destIpAddrMode, destIpMask, destIpAddrRepeatCount,sourceIpAddrMode, sourceIpAddr, sourceIpMask, sourceIpAddrRepeatCount.
    the keys for ipv6 IP parameters are:
    destAddr sourceAddr sourceAddrMode destAddrMode destMask sourceMask sourceStepSize destStepSize sourceAddrRepeatCount destAddrRepeatCount
7. gets the current ipProtocol(udp or tcp) configuration accourding to the ipProtocol parameter passed if its not passed ipProtocol udp is selected
8. set the udp or tcp parameters that is the destination port and the source port accourding to the parameters passed.
9. saves the ip parameter, ipProtocol parameter and the stream parametes and writes the configuration to hardware

The ixia object and $ixiaSpecificData which is passed as a hash are inputs to the subroutine SonusQA::SBX5000::PERFHELPER::setIxiaParam

=item ARGUMENTS:

    Mandatory Args:
        '-ixiaSpecificData' => $ixiaSpecificData
         $ixiaSpecificData is a hash, the mandatory key parameters to be passed into this hash are:
         cardId, portId, streamId, chasId, ixiaProfile(path of the saved profile)

    optional key parameters which can be passed are:
          da, percentPacketRate, fpsRate, bpsRate, rateMode, framesize, 
          destIpAddr, destIpAddrMode, destIpMask, destIpAddrRepeatCount, sourceIpAddrMode, sourceIpAddr, sourceIpMask, sourceIpAddrRepeatCount,
          destAddr, sourceAddr, sourceAddrMode, destAddrMode, destMask, sourceMask, sourceStepSize, destStepSize, sourceAddrRepeatCount, destAddrRepeatCount,
          destPort, sourcePort
    Note: pass only those optional key parameters which have to be set eg passing of destIpMask, while destIpAddMode is fixed might lead to an error.

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ($self->setIxiaParam('-ixiaSpecificData' => $ixiaSpecificData ){ 
  $logger->error(__PACKAGE__ . ".$sub: failed to set the ixia parameters");
  $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
  return 0;
}

the format of $ixiaSpecificData must be as follws
my $ixiaSpecificData = {
       'ixiaProfile'  => $path,       #ixia profile path with file to be loaded
       'chasId'       => '1',         # specify the sip signaling address of DUT
       'cardId'       => $cardId,     # ixia card assigned for this test
       'portId'       => $portId,     # ixia port assigned for this test
       'streamId'     => $streamId,   # ixia stream id default 1
       'ipProtocol'   =>"udp"         # mention the the ip protocol required 
       'da'           => $da,         # specify the mac address of DUT
       'sa'           => $sa,         # specify the source MAC address
       'framesize'    => "64",        # specify the frame size of the packet to be pumped (supports fixed frame size) 
       'IPVersion'    => "IPV4",      # supports IP version to be IPV4 or IPV6
       'destIpAddr'   => $destIpAddr, # specify the sip signaling address of DUT
       'fpsRate'      => $ixiarate,   # include this key parameter only if ratemode is Fps i.e "streamRateModeFps"
       'rateMode'     => 'streamRateModeFps', #defines the rate mode, it can be even "streamRateModeBps" or "streamRateModePercentRate" depending on the choice  
       'destIpAddrMode'  =>"ipIdle",   #specify the destination ipaddress mode
       'sourceIpAddrMode'=>"ipIncrHost",#specify the source ipaddress mode
       'sourceIpAddr' =>$sourceIpAddr, #specify the sourceIpAddr mode if required
       'sourceIpMask' => $sourceIpMask,#specify the destination IP mask if required
       'sourceIpAddrRepeatCount'=>$sourceIpAddrRepeatCount, #specify the source ip addr repeat count
     };

the supported values for (ipv4)sourceIpAddrMode or destIpAddrMode are "ipRandom", "ipIdle", "ipIncrHost", "ipDecrHost", "ipContIncrHost", "ipContDecrHost".
the supported values for (ipv6)sourceAddrMode or destAddrMode are "ipV6Idle", "ipV6IncrHost", "ipV6DecrHost", "ipV6IncrNetwork", "ipV6DecrNetwork".

note: if any of the optional key parameters are not passed, saved parameters in the profile remain

=back

=cut

sub setIxiaParam {
   my ($self, %args) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setIxiaParam");
   my $sub = 'setIxiaParam';
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   my @ixiaStreamInputData  = qw/ da sa percentPacketRate fpsRate bpsRate rateMode framesize /;
   my @ixiaIpInputData  = qw/ destIpAddr destIpAddrMode destIpMask sourceIpAddrMode sourceIpAddr sourceIpMask sourceIpAddrRepeatCount /;
   my @ixiaIpV6InputData  = qw/ destAddr sourceAddr sourceAddrMode destAddrMode destMask sourceMask sourceStepSize destStepSize sourceAddrRepeatCount destAddrRepeatCount /;
   my @ixiaProtocolInputData  = qw/ destPort sourcePort /;
   my @ixiaVlanInputData  = qw/ vlanID userPriority cfi mode repeat step maskval protocolTagId /;
   my @ixiaMandatoryData  = qw/ cardId portId streamId chasId ixiaProfile/;
   my %ixiaSpecificData;

   if ( defined ($args{"-ixiaSpecificData"}) ) {
       %ixiaSpecificData  = %{ $args{'-ixiaSpecificData'} };
   } else {
       $logger->error("  ERROR: The mandatory DATA argument -ixiaSpecificData is not defined.");
       return 0;
   }

# validate Input data
   foreach ( @ixiaMandatoryData ) {
       unless ( defined ( $ixiaSpecificData{$_} ) ) {
           $logger->error("  ERROR: The mandatory  DATA argument for \'$_\' has not been specified.");
           $logger->debug(" <-- Leaving Sub [0]");
           return 0;
       }
       $self->{$_} = $ixiaSpecificData{$_};
       $logger->debug("  ixiaSpecificData\{$_\}\t- $ixiaSpecificData{$_}");
   }
# get the ipProtocol
   my $protocol;
   if ( defined ( $ixiaSpecificData{"ipProtocol"})){
       $protocol = $ixiaSpecificData{"ipProtocol"};
   }else{
       $protocol = "udp";
   }  
 
## load ixiaProfile
    $logger->info(__PACKAGE__ . ".$sub: \n \n Loading profile to IXIA  \n \n");
    unless ($self->portProfileLoad( -file => $ixiaSpecificData{ixiaProfile}, -cardID => $ixiaSpecificData{cardId}, -portID => $ixiaSpecificData{portId})) {
         $logger->error(__PACKAGE__ . ".$sub: failed to write the configuration to port");
         $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]");
         return 0;
    }
    else {
         $logger->debug(" SUCCESS - executed Load profile for IXIA  \'$ixiaSpecificData{ixiaProfile}\'");
    }


###Gets the current Stream configuration
###set the stream param
    my $cmd = 'stream config';
    foreach ( @ixiaStreamInputData ) {
        unless ( defined ( $ixiaSpecificData{$_} ) ) {
            $logger->debug("  INFO: The \'$_\' has not been specified.");
        } else {
          $cmd .= " -$_ \"$ixiaSpecificData{$_}\"";
        }
    }

    my @commands = ("stream get $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId} $ixiaSpecificData{streamId}", $cmd);

## Gets the current IP configuration
   if ($ixiaSpecificData{IPVersion} eq "IPV6"){
        $cmd = "ipV6 get $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";
   } else{
        $cmd = "ip get $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";
   }

   push @commands , $cmd; 

###set the ip param
    my @IPData;
    my $cmd1 = "protocol setDefault";
    my $cmd3 = "protocol config -ethernetType ethernetII";
    my $cmd4 = "ip config -ipProtocol $protocol";
    my ($cmd2, $cmd5, $command1);
    if ($ixiaSpecificData{IPVersion} eq "IPV6"){
        $cmd2 = "protocol config -name ipV6";
        $cmd5 = "ipV6 config -trafficClass 3";
        push @commands, $cmd1, $cmd2, $cmd3, $cmd4, $cmd5;
        @IPData = @ixiaIpV6InputData;
        $command1 = "ipV6 config"
    }else{
        $cmd2 = "protocol config -name ipV4";
        push @commands, $cmd1, $cmd2, $cmd3, $cmd4;
        @IPData = @ixiaIpInputData;
        $command1 = "ip config";
    }

    foreach ( @IPData ) {
        unless ( defined ( $ixiaSpecificData{$_} ) ) {
            $logger->debug("  INFO: The \'$_\' has not been specified.");
        }else {
            $command1 .= " -$_ \"$ixiaSpecificData{$_}\"";
        }
    }

    push @commands, $command1;

#Gets the current UDP configuration
   push @commands, "$protocol get $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";

###set the  protocol param
    $cmd="$protocol config";
    foreach ( @ixiaProtocolInputData ) {
        unless ( defined ( $ixiaSpecificData{$_} ) ) {
            $logger->debug("  INFO: The \'$_\' has not been specified.");
        } else {
          $cmd .= " -$_ \"$ixiaSpecificData{$_}\"";
        }
    }

    push @commands, $cmd;

#save the ip parameter
   if ($ixiaSpecificData{IPVersion} eq "IPV6"){
       push @commands, "ipV6 set $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";
   }else{
       push @commands, "ip set $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";
   }
#save the ipProtocol parameter
    push @commands, "$protocol set $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";

#save the stream param
    push @commands, "stream set $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId} $ixiaSpecificData{streamId}";

#vlan parameters - TOOLS-14510
    if($ixiaSpecificData{vlanID}){
	$cmd='vlan config';
        foreach ( @ixiaVlanInputData ) {
            unless ( defined ( $ixiaSpecificData{$_} ) ) {
                $logger->debug("  INFO: The \'$_\' has not been specified.");
            } else {
                $cmd .= " -$_ \"$ixiaSpecificData{$_}\"";
            }
        }
        push @commands, "vlan get $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}", $cmd, "vlan set $ixiaSpecificData{chasId} $ixiaSpecificData{cardId} $ixiaSpecificData{portId}";
    }

#write to hardware
    push @commands, 'ixWriteConfigToHardware portlist';

    my @errors = ('No connection to a chassis', 'Invalid port', 'The card is owned by another user');
    my $ret = 1;
    foreach $cmd (@commands){
        unless ($self->execIxiaCmd($cmd, @errors)) {
            $logger->error(__PACKAGE__ . ".$sub: failed to execut \'$cmd\'");
            $ret = 0;
            last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [$ret]");
    return $ret;
}

sub closeConn {

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn");
    $logger->debug(__PACKAGE__ . ".closeConn Closing IXIA connection...");

    my ($self) = @_;

    if ($self->{conn}) {
      $self->{conn}->cmd("ixDisconnectFromChassis $self->{IXIA_SERVER}");
      $self->{conn}->cmd("ixDisconnectTclServer $self->{IXIA_SERVER}");
      $self->{conn}->cmd("exit");
      $self->{conn}->cmd("exit");
      $self->{conn}->close;
      undef $self->{conn};
    }
}

sub DESTROY{
    my ($self) = @_;
    my $sub = 'DESTROY';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $result = 1;
    unless ($self->stopTransmit('-cardID' => $self->{cardId},'-portID' => $self->{portId})){
        $logger->error(__PACKAGE__ . ".$sub: failed to stop transmission");
        $result = 0;
    }else{
        unless ($self->checkTransmitStatus('-cardID' => $self->{cardId},'-portID' => $self->{portId})){
            $logger->error(__PACKAGE__ . ".$sub: failed to IXIA transmission status");
            $result = 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub calling closeConn sub to destroy the connection object.");
    $self->closeConn;
    $logger->info(__PACKAGE__ . ".$sub: Leaving Sub [$result]");
    return $result;
}

1;
