package SonusQA::WSX;

=pod

=head1 NAME

SonusQA::WSX- Perl module for WSX Unix side interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::WSX->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH|SFTP|FTP>",
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for the WSX Unix side.
   It provides methods for both postive and negative testing, most cli methods returning true or false (0|1).
   Control of command input is up to the QA Engineer implementing this class, most methods accept a key/value hash, 
   allowing the engineer to specific which attributes to use.  Complete examples are given for each method.


=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use Log::Log4perl qw(get_logger :easy);


our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);

=head1 METHODS

=head2 doInitialization()

=over

=item Description:

    Routine to set object defaults and session prompt.
    This subroutine is called by SonusQA::Base.pm 

=back

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%\}\|\>]\s?$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
}

=head2 setSystem()

=over

=item Description: 

    Routine to set the Platform type, and Version details.

=back

=cut

sub setSystem(){
    my($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
    my($cmd,$prompt, $prevPrompt, @results, @version_info);
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd(""); 
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    @results = $self->{conn}->cmd($cmd);
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
 

    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
 
    #Setting the Platform type 
    my @platform = $self->{conn}->cmd('uname');
    $self->{PLATFORM} =  ($platform[0] =~ /Linux/i) ? 'linux' : 'SunOS';

    unless (@version_info = $self->{conn}->cmd('rpm -qa | grep wrtc')) {
        $logger->error(__PACKAGE__ . ".setSystem CMD: \'rpm -qa | grep wrtc\' failed");
    } else {
        chomp @version_info;
        my $VERSION = $1 if($version_info[0] =~ /wrtc-(.*)\.x86/);
        $VERSION =~ s/-//; 
        $self->{VERSION} = $VERSION;
        if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
            $main::TESTSUITE->{DUT_VERSIONS}->{"WSX,$self->{TMS_ALIAS_NAME}"} = $self->{VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"WSX,$self->{TMS_ALIAS_NAME}"});
        }
    }
    $self->{conn}->cmd("TMOUT=72000");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::WSX::execCmd()

=over

=item Description: 

  This routine is responsible for executing commands.  Commands can enter this routine via straight call 
  It performs some basic operations on the results set to attempt verification of an error.

=item Arguments:

  cmd <Scalar> : A string of command parameters and values
  timeout <optional> : timeout value in seconds

=item Returns:

  Array
  This return will be an empty array if:
    1. The command executes successfully (no error statement is return)
    2. And potentially empty if the command times out (session is lost)

  The assumption is made, that if a command returns directly to the prompt, nothing has gone wrong.

=item Example(s):

    $Obj1->execCmd("netstat -anp | grep ESTABLEISHED|wc -l");

=back

=cut

sub execCmd {  
  my ($self,$cmd, $timeout)=@_;
  my($flag, $logger, @cmdResults,$timestamp,$prevBinMode,$lines,$last_prompt, $lastpos, $firstpos);
  $flag = 1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();

  $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");
  $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command
  $timeout ||= $self->{DEFAULTTIMEOUT};
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $timeout )) {
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

  return @cmdResults;
}
