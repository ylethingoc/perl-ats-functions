package SonusQA::ORACLE;

=pod

=head1 NAME

SonusQA::ORACLE - Perl module for SQLPlus (ORACLE) interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $dsi = SonusQA::ORACLE->new(-OBJ_HOST => '<host name | IP Adress>',
                                  [-OBJ_USER => '<cli user name>',]                 # Defaults to ssuser
                                  [-OBJ_PASSWORD => '<cli user password>',]         # Defaults to ssuser
                                  [-ORACLE_USER => '<oracle user name>',]           # Defaults to dbimpl
                                  [-ORACLE_PASSWORD => '<oracle user password>',]   # Defaults to dbimpl
                                  -OBJ_COMMTYPE => "<TELNET|SSH>",
                                );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for SQLPlus (ORACLE) interaction (PSX connection).  Connection to PSX server as ssuser,
   with connection to oracle (defaulting to dbimpl/dbimpl

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;
use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase  SonusQA::ORACLE::ORACLEHELPER);

=pod

=head3 SonusQA::ORACLE::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.
   
Arguments

  NONE 

Returns

  NOTHING   

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = "ORACLE";
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#].*$/';
  #$self->{PROMPT} = '/.*[#\$%]/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{cnistnet} = "/usr/local/bin/cnistnet";
  # Note: For SuSE Linux, the following line had to be changed
  # Orginal Line: test -x /usr/bin/tset && /usr/bin/tset -I -Q 
  # New Line    : test -x /usr/bin/tset && /usr/bin/tset -I -Q -m network:vt100
  # SuSE Linux and possibly others do not like 'network';
  $self->{OBJ_USER} = "ssuser";
  $self->{OBJ_PASSWORD} = "ssuser";
  $self->{ORACLE_USER} = "dbimpl";
  $self->{ORACLE_PASSWORD} = "dbimpl";
}

=head1 setSystem()

DESCRIPTION: 
    This subroutine sets the system variables and Prompt.

=cut


sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results, $line, $oracle_home, @settings);
  @settings = ("set HEAD OFF","set PAGES 0","set FEEDBACK 0");
  $logger->info(__PACKAGE__ . ".setSystem  ATTEMPTING TO DETERMINE ORACLE HOME (SHOULD BE IN SSUSER ENV)");
  $cmd = "env | grep ORACLE_HOME ";
  ($line) = $self->{conn}->cmd($cmd);
  &error(__PACKAGE__ . ".setSystem  LINE DOES NOT CONTAIN TYPICAL ORACLE PATH: $line") unless $line =~ /oracle/i;
  ($oracle_home) = (split "=",$line)[1,2];
  chomp($oracle_home);
  $logger->info(__PACKAGE__ . ".setSystem  ORACLE PATH: $oracle_home");
  $self->{ORACLE_PATH} = $oracle_home;
  $self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/SQL>\s$/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  $cmd = "$self->{ORACLE_PATH}/bin/sqlplus $self->{ORACLE_USER}/$self->{ORACLE_PASSWORD}"; 
  $self->{conn}->cmd($cmd);
  $self->{conn}->cmd("");
  foreach(@settings){
    $logger->info(__PACKAGE__ . ".setSystem  EXECUTING: $_");
    $self->{conn}->cmd($_);
  }
  $logger->info(__PACKAGE__ . ".setSystem  SQLPLUS SESSION ESTABLISHED");
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}

=head2 execCmd()

DESCRIPTION:
    This function enables user to execute any command on the server.

ARGUMENTS:
    1. Command to be executed.

OUTPUT:
    0 - Error executing the command.
    1 - Command executed Successfully.
    Output of the command executed will be  returned in array.

EXAMPLE:
    unless ($self->execCmd("Select * from table")){
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute the command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=cut

sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
  #cmdResults = $self->{conn}->cmd($cmd);
  #return @cmdResults;
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd)) {
    # Section for commnad execution error handling - CLI hangs, etc can be noted here.
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd DSI CLI CMD ERROR - EXITING");
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  return @cmdResults;
}

=head3 retrieveUserTableListing()

DESCRIPTION:
    This function is used to get the table list.

ARGUMENTS:
    None

OUTPUT:
    Output of the command executed will be returned in array

EXAMPLE:
    unless ($self->retrieveUserTableListing()){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get table list");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=cut


sub retrieveUserTableListing(){
  my ($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".retrieveUserTableListing");
  my($cmd, @results);
  $cmd = "select table_name from user_tables;";
  @results = $self->execCmd($cmd);
  return @results;
}

=head4 retrieveTableDesc()

DESCRIPTION:
    This function is used to get the table discription.

ARGUMENTS:
    None

OUTPUT:
    Output of the command executed will be returned in array

EXAMPLE:
    unless ($self->retrieveTableDesc()){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get table list");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
=cut

sub retrieveTableDesc(){
  my ($self,$table)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".retrieveTableDesc");
  my($cmd, @results);
  $cmd = "desc $table;";
  @results = $self->execCmd($cmd);
  return @results;
}

=head4 AUTOLOAD() 

DESCRIPTION:
    This function is called when invalid method is called 

=cut

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
