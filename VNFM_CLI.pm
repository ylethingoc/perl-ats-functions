package SonusQA::VNFM_CLI;

=head1 NAME

  SonusQA::VNFM_CLI

=head1 AUTHOR

  Toshima Saxena - tsaxena@rbbn.com

=head1 IMPORTANT

  B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

  use ATS;           # This is the base class for Automated Testing Structure
  my $obj = SonusQA::VNFM_CLI->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                              );

=head1 REQUIRES

  Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper

=head1 DESCRIPTION

  This module provides an interface for Any TOOL installed on Linux server.

=head1 METHODS

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Net::Telnet;

our @ISA = qw(SonusQA::Base);

=head2 doInitialization

=over

=item DESCRIPTION:

  Routine to set object defaults and session prompt.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::VNFM_CLI

=item OUTPUT:

  None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
}

=head2 setSystem

=over

=item DESCRIPTION:

  This function sets the system information.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::VNFM_CLI

=item OUTPUT:

  None

=back

=cut

sub setSystem {
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");
    my($cmd, $prevPrompt);

    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd("unalias ls");
    $self->{conn}->cmd("unalias grep");
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->last_prompt);
    $self->{LOG_PATH} = '/var/log';
    $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub[1]");
    return 1;
}

=head2 execCmd

=over

=item DESCRIPTION:

  This function enables user to execute any command on VNFM_CLI.

=item ARGUMENTS:

  1. Command to be executed.
  2. Timeout in seconds (optional).

=item PACKAGE:

  SonusQA::VNFM_CLI

=item OUTPUT:

  1-succesful execution of command
  0-execution of command failed

=item Example:

  my @results = $obj->execCmd("allstart");
  This would execute the command "allstart" on the session and return the output of the command.

=back

=cut

sub execCmd{
   my ($self,$cmd,$timeout)=@_;
   my $sub = "execCmd()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my @cmdResults;
   $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub Timeout specified as $timeout seconds ");
   }

   $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
 unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->error(__PACKAGE__ . ".$sub  COMMAND EXECTION ERROR OCCURRED");
      $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub  lastline : ". $self->{conn}->lastline);
      $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
   }

   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub cmd result : ".Dumper \@cmdResults);
   $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub");
   return @cmdResults;
}

1;

