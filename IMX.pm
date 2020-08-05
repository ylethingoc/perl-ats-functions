package SonusQA::IMX;

=pod

=head1 NAME

SonusQA::IMX - Perl module for IMX CLI interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $dsi = SonusQA::NISTnet->new(-OBJ_HOST => '<host name | IP Adress>',
                                   -OBJ_USER => '<cli user name>',
                                   -OBJ_PASSWORD => '<cli user password>',
                                  -OBJ_COMMTYPE => "<TELNET|SSH>",
                                );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Linux NISTnet interaction.

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES


=cut


use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use Net::FTP;
use Net::SFTP::Foreign;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase SonusQA::IMX::IMXSCP);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#:]\s$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{IMX_PATH} = "/opt/sonus/imx";
  $self->{GOAHEAD_PATH} = $self->{IMX_PATH} . "/goahead";
  # Note: For SuSE Linux, the following line had to be changed
  # Orginal Line: test -x /usr/bin/tset && /usr/bin/tset -I -Q 
  # New Line    : test -x /usr/bin/tset && /usr/bin/tset -I -Q -m network:vt100
  # SuSE Linux and possibly others do not like 'network';
}

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  # Switch to sh shell - easier to set prompting and no special characters
  $self->{conn}->cmd("sh");
  # Unalias everything - linux tends to set colorization via aliases - this in turn sends control characters back to the session
  $self->{conn}->cmd("unalias -a");
  $self->{conn}->cmd("set bell-style none");
  # Change prompt to something very specific
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}


sub execCmd {  
  my ($self,$cmd)=@_;
  my($flag, $logger, @cmdResults,$timestamp,$prevBinMode,$lines,$last_prompt, $lastpos, $firstpos);
  $flag = 1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  foreach(@cmdResults) {
    if(m/(Permission|Error)/i){
        if($self->{CMDERRORFLAG}){
          $logger->warn(__PACKAGE__ . ".execCmd  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
          &error("CMD FAILURE: $cmd");
        }
        $flag = 0;
        last;
    }
  }
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
  if(Log::Log4perl::initialized()){
    my $logger = Log::Log4perl->get_logger($AUTOLOAD);
    $logger->warn($warn);
  }else{
    Log::Log4perl->easy_init($DEBUG);
    WARN($warn);
  }
}

1;
