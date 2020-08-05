package SonusQA::ASX;

=pod

=head1 NAME

SonusQA::ASX - Perl module for Sonus Networks ASX interaction

=head1 SYSOPSIS

 use ATS; # This is the base class for Automated Testing Structure

 my $obj = SonusQA::ASX->new(
                             #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name >',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_COMMTYPE => "<TELNET >",
                             );
 PARAMETER DESCRIPTIONS:
    OBJ_HOST
      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_USER
      The user name or ID that is used to 'login' to the device.
    OBJ_PASSWORD
      The user password that is used to 'login' to the device.
    OBJ_COMMTYPE
      The session or connection type that will be established.

=head1 DESCRIPTION


=head1 AUTHORS

   See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=head1 METHODS

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw(locate);
use File::Basename;

require SonusQA::ASX::ASXHELPER;


our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::ASX::ASXHELPER SonusQA::Base);

# INITIALIZATION ROUTINES FOR CLI^M
# -------------------------------^M

=head2 SonusQA::ASX::doInitialization

  Routine to set object defaults and session prompt.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  $self->{DEFAULTTIMEOUT} = 120;
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  $logger->debug(__PACKAGE__ . ".doInitialization Initialization Complete");
}

=head2 SonusQA::ASX::setSystem()

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the ASX to enable a more efficient automation environment.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd("");
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  $logger->debug(__PACKAGE__ . ".setSystem  ENTERED ASXUSER SUCCESSFULLY");
  $self->{conn}->print("export TMOUT=0");
  $logger->debug(__PACKAGE__ . ".setSystem CHANGING THE TELNET TIMEOUT TO 0");

  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

  my @version = $self->{conn}->cmd('pkginfo -l SONSasx');

  my $Ver;
  foreach (@version){
      if (/VERSION:[\s\t]*(\S+)\s*.*/){
         $Ver = $1;
         $Ver =~ s/\s+//g;
         last;
      }
  }

  $logger->debug(__PACKAGE__ . ".setSystem ASX version -> $Ver");

  if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
     $main::TESTSUITE->{DUT_VERSIONS}->{"ASX,$self->{TMS_ALIAS_NAME}"} = $Ver unless ($main::TESTSUITE->{DUT_VERSIONS}->{"ASX,$self->{TMS_ALIAS_NAME}"});
  }
  @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = $self->{conn}->cmd('uname');
  $logger->debug(__PACKAGE__ . ".setSystem <-- Leaving sub [1]");
  return 1;

}  


=pod 

=head2 SonusQA::ASX::execCmd()

  This routine is responsible for executing commands.  Commands can enter this routine 
  Via a straight call (if script is not using XML libraries, this would be the perferred method
  in this instance)


  It performs some basic operations on the results set to attempt verification of an error.

=over

=item Arguments

  cmd <Scalar>
  A string of command parameters and values
  timeout<optional>
  timeout value in seconds

=item Returns

  Array
  This return will be an empty array if:
    1. The command executes successfully (no error statement is return)
    2. And potentially empty if the command times out (session is lost)

  The assumption is made, that if a command returns directly to the prompt, nothing has gone wrong.
  The GSX product done not return a 'success' message.

=item Example(s):

    &$obj->execCmd("");

=back

=cut

sub execCmd {
  my ($self,$cmd,$timeout)=@_;
  my($logger, @cmdResults);
  my($prompt, $prevPrompt, @results);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $timeout ||= $self->{DEFAULTTIMEOUT};
  my $prom = '/\.*' . ']/'; 
  my $prom1 = '/\.*' .  '>/';
 
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $self->{CMDRESULTS} = [];
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=> $timeout )) {
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    push(@{$self->{CMDRESULTS}},@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".execCmd: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".execCmd: Session Input Log is: $self->{sessionLog2}");
    if(grep /Error/is, @cmdResults){
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    }else{
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  UNKNOWN ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    }
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  push(@{$self->{HISTORY}},$cmd);
  $self->{conn}->print("exit");
  $self->{conn}->waitfor(-match => $prom,
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
  or &error(__PACKAGE__ . ".execCmd  UNABLE TO GET TO ASXUSER PROMPT");
  $logger->debug(__PACKAGE__ . ".execCmd  ENTERED ASXUSER SUCCESSFULLY");

  return @cmdResults;
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
