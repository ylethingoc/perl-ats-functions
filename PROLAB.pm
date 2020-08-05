package SonusQA::PROLAB;

=head1 NAME

SonusQA::PROLAB- Perl module for PROLAB application control  using XML/SOAP interface.

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION

This module provides an xml/soap interface for the PROLAB test tool.
One can able to perform any operation on prolab tool using the API's of this module.

=head2 METHODS

=cut

use strict;
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use IO::Socket::INET;
use Data::Dumper;
use XML::DOM;
use File::Basename;
use Module::Locate qw(locate);
use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);

=pod

=head3 SonusQA::PROLAB::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.
  This routine discovers correct path for XML library loading.  It uses the package location for forumulation of XML path.

  This routine is automatically called prior to SESSION creation, and parameter or flag parsing.


=over

=item Argument

  args <Hash>

=item Returns

  NOTHING

=back

=cut

sub doInitialization {
   my($self, %args)=@_;
	
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

   $self->{COMMTYPES} = ["TELNET", "SSH"];
   $self->{TYPE} = __PACKAGE__;
   $self->{conn} = undef;
   $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
   $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)

   $self->{LOCATION} = locate __PACKAGE__ ;

}

=pod

=head3 SonusQA::PROLAB::setSystem()

    This function sets the system information. The following variables are set if successful:
         - $self->{XML_HEAD} pointing to deafult xml/soap header which will be prepended to any xml input
         - $self->{XML_TAIL} pointing to deafult xml/soap tailer will be appended to any xml input
         - start the Prolab test manager
         - $self->{SOCKET} holds the SOCKET created for agent operation
         - $self->{PROLAB_SESSION} a telnet session to prolab pc

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut

sub setSystem(){
   my($self)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
   $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
   my($cmd,$prompt, $prevPrompt);
   $self->{conn}->cmd("bash");
   $self->{conn}->cmd("");
   $self->{conn}->last_prompt("");
   $self->{DEFAULTTIMEOUT} = 30;
   $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
   $self->{PROTOCOL} ||= 'tcp';
   $self->{DEFAULT_BUFFER} = 5000;

   # this will prepended to any xml input
   $self->{XML_HEAD} = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\
<SOAP-ENV:Envelope\
xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"\
xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\"\
xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\
xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\
xmlns:ns=\"urn:prolab\">\
<SOAP-ENV:Body SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">\
";
   # this will be appended to any xml input
   $self->{XML_TAIL} = "</SOAP-ENV:Body>\
</SOAP-ENV:Envelope>";

   unless ($self->startManager()) {
      $logger->error(__PACKAGE__ . ".setSystem: unable to start manager");
      $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [0]");
      return 0;
   }

   # SOCKET creation for agent operation
   $self->{SOCKET}= new IO::Socket::INET ( PeerHost => $self->{PROLAB_HOST}, PeerPort => $self->{AGENT_PORT}, Proto => $self->{PROTOCOL});

   unless ($self->{SOCKET} ) {
      $logger->error(__PACKAGE__ . ".setSystem: failed to create $self->{PROTOCOL} socket to host -> $self->{PROLAB_HOST} with port -> $self->{AGENT_PORT}, for Agent operation");
      $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [0]");
      return 0;
   }

   $self->{PROLAB_SESSION} = new SonusQA::Base (-OBJ_HOST => $self->{PROLAB_HOST}, -OBJ_USER => $self->{PROLAB_USER}, -OBJ_PASSWORD => $self->{PROLAB_PASSWORD}, -comm_type => 'TELNET', -prompt => '/.*[\$#%>]\s*$/', -sessionlog => 1, -OUTPUT_RECORD_SEPARATOR => "\n");

   unless ($self->{PROLAB_SESSION}) {
      $logger->error(__PACKAGE__ . ".setSystem: failed to creat telnet session to prolab machine -> $self->{PROLAB_HOST}, you wont be able to collect log and verify");
      $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [0]");
      return 0;
   }

   $self->{PROLAB_SESSION}->{conn}->prompt('/AUTOMATION\% $/');
   $self->{PROLAB_SESSION}->{conn}->cmd("prompt AUTOMATION% ");

   $self->{conn}->waitfor(Match => '/AUTOMATION%  $/', Timeout => 2);

   $logger->info(__PACKAGE__ . ".setSystem: created $self->{PROTOCOL} socket to host -> $self->{PROLAB_HOST} with port -> $self->{AGENT_PORT}, for Agent operation");
   $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [1]");
   return 1;
}

=pod

=head3 SonusQA::PROLAB::sendXMLData()

    This function enables user to send any xml/soap data to PROLAB machine.

=over

=item Arguments

    1. xml input except deafault header and tailer.
    2. option argument socket or else uses deafault socket created during setSystem
    3. maximum buffer length to capture the response of xml/soap action -> optional, default is 5000 ($self->{DEFAULT_BUFFER})

=item Return Value

    success - xml response of action.
    failure - 0

=item Example(s)

    my $xml_data = '<ns:RV-Get-H323-Agents></ns:RV-Get-H323-Agents>';
    my $response = $Obj->sendXMLData($xml_data);

=back

=cut

sub sendXMLData {
   my ($self, $xml, $socket, $buffer_length) = @_;

   my $sub_name = 'sendXMLData()';
   my $response = '';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   unless ( defined $xml) {
      $logger->error(__PACKAGE__ . ".$sub_name: manditory argument action xml input is missing or empty");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   $buffer_length ||= $self->{DEFAULT_BUFFER}; # setting to deafult value 5000
   $socket ||= defined $self->{SOCKET} ? $self->{SOCKET} :  new IO::Socket::INET ( PeerHost => $self->{PROLAB_HOST}, PeerPort => $self->{AGENT_PORT}, Proto => $self->{PROTOCOL}); # $self->{SOCKET}; #if no socket is passed use the deafult socket
   $xml = $self->{XML_HEAD} . "$xml" . $self->{XML_TAIL}; #adding head and tail to input xml

   $logger->info(__PACKAGE__ . ".$sub_name: sending xml data -> $xml");
   unless ($socket->send($xml)) {
      $logger->error(__PACKAGE__ . ".$sub_name:  failed to send xml data");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   
   $socket->recv($response, $buffer_length);

   unless ($response) {
      $logger->error(__PACKAGE__ . ".$sub_name: din't recive any response for xml msg, $xml");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   $logger->info(__PACKAGE__ . ".$sub_name: recived below response");
   $logger->debug(__PACKAGE__ . ".$sub_name: $response");
   return $response;
}

=pod

=head3 SonusQA::PROLAB::getAgentInfo()

    This function return the agent info specified agent type.

=over

=item Arguments:

    1. agent type -> example (H323).
    

=item Returns

    success - hash reference having agent information
    failure - 0

=item Example(s):
   
    my $agent_deatils = $Obj->sendXMLData('H323');

=back
    
=cut

sub getAgentInfo {
   my ($self, $agentType) = @_;
   my $sub_name = 'getAgentInfo()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
   $logger->info(__PACKAGE__ . ".$sub_name: --> no agentType is passed hence taking H323 as default") unless (defined $agentType);
   $agentType ||= 'H323'; #if no agentType is passes setting it default H323 

   my $xmlData = "<ns:RV-Get-$agentType-Agents></ns:RV-Get-$agentType-Agents>";
   my $response = '';   
   unless ($response = $self->sendXMLData($xmlData) ) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to get agent info");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   my $parser = new XML::DOM::Parser;
   my $data = $parser->parse($response);
   my %return = ();
   foreach my $agent ($data->getElementsByTagName("Agent")) {
      my $name = $agent->getElementsByTagName("AgentName")->item(0)->getFirstChild->getData;
      chomp $name;
      foreach ($agent->getChildNodes) {
          my $content = $_->toString;
          chomp $content;
          if ( $content =~ /\<(.+)\>(.+)\<\/.+\>/) {
              $return{$name}{$1} = $2;
          }
      }
   }

   return \%return;
}

=pod

=head3 SonusQA::PROLAB::setAgentLogDir()

    This function set the log directory for the specified Agent ID.

=over

=item Arguments

    Hash with agent deatils
		- Manditory
		-AgentID
		-LogEventsPath
		-LogMessageAnalyzerPath    

=item Returns

    1 - on success
    0 - on failure

=item Example(s):
    my %agentInfo = (-CallChannels => 1, -ErrorEvents => 1, -Media_Statistics => 1, -MessageStatistics => 1, -NetworkStatus => 1, -LogEventsSize => 100, -LogMessageAnalyzerSize => 100, -LogRTCPSize => 100, -LogEventsPath => 'Z:\Prolab\logs\sender', -LogMessageAnalyzerPath => 'Z:\Prolab\logs\sender', -LogRTCPPath => 'Z:\Prolab\logs\sender', -AgentID => 2);
	
    my $result = $Obj->setAgentLogDir(%agentInfo);

=back
    
=cut

sub setAgentLogDir {
   my ($self, %args) = @_;
   my $sub_name = 'setAgentLogDir()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $xmlData = '<ns:RV-Register_Agent_Monitoring>';
   my $response = '';
   foreach ('-AgentID', '-LogEventsPath', '-LogMessageAnalyzerPath') {
      unless (defined $args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
         return 0;
      }
   }

   foreach (keys %args) {
      my $temp = $_;
      $temp =~ s/^-//;
      $xmlData .= "<$temp>" . $args{$_} . "</$temp>";
   }
   $xmlData .= '</ns:RV-Register_Agent_Monitoring>';

   unless ($response = $self->sendXMLData($xmlData)) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed set directory info for AgentID -> $args{-AgentID}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   my $result = index($response, '<retval>OK');

   if ( $result > 0) {
      $logger->info(__PACKAGE__ . ".$sub_name: successfully set the directory info for AgentID -> $args{-AgentID}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      return 1;
   } else {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to set the directory info for AgentID -> $args{-AgentID}, server returned below information");
      $logger->debug(__PACKAGE__ . ".$sub_name: $response");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

}

=pod

=head3 SonusQA::PROLAB::startManager()

    This function will start prolab test manager

=over

=item Arguments

    Hash with required details -> Optional
	Example  -> -port => 7050, default value is ($self->{TEST_MANAGER_PORT}) passed during the object creation

=item Returns

    1 - on success
    0 - on failure

=item Example(s):
    
    $Obj->startManager();

=back
    
=cut

sub startManager {
   my ($self, %args) = @_;
   my $sub_name = 'startManager()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $xmlData = "<ns:RV-Remote-Start-Manager>\ 
</ns:RV-Remote-Start-Manager>";
   my $response = '';
   $args{-port} ||= $self->{TEST_MANAGER_PORT};
   $self->{MANAGER_SOCKET} = new IO::Socket::INET ( PeerHost => $self->{PROLAB_HOST}, PeerPort => $args{-port}, Proto => $self->{PROTOCOL}) unless (defined $self->{MANAGER_SOCKET});

   unless ($self->{MANAGER_SOCKET} ) {
      $logger->error(__PACKAGE__ . ".setSystem: failed to create $self->{PROTOCOL} socket to host -> $self->{PROLAB_HOST} with port -> $args{-port}");
      $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [0]");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".setSystem: created $self->{PROTOCOL} socket to host -> $self->{PROLAB_HOST} with port -> $args{-port}");

   unless ($response = $self->sendXMLData($xmlData, $self->{MANAGER_SOCKET})) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to start manager");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   my $result = index($response, '<retval>OK');
   if ( $result > 0) {
      $logger->info(__PACKAGE__ . ".$sub_name: successfully started manager");
      $logger->debug(__PACKAGE__ . ".$sub_name: sleeping for 10 secs, after starting Manager");
      sleep 10;
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      return 1;
   } 

   $result = index($response, 'Error already running') if ( $result == -1 );

   if ( $result > 0) {
      $logger->info(__PACKAGE__ . ".$sub_name: manager is already running");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      return 1;
   }
  
   $logger->error(__PACKAGE__ . ".$sub_name: failed to start manager, server returned below information");
   $logger->debug(__PACKAGE__ . ".$sub_name: $response");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
   return 0;
}

=pod

=head3 SonusQA::PROLAB::stopManager()

    This function will stop prolab test manager

=over

=item Arguments

    Hash with required details -> Optional
		Example  -> -port => 7050, default value is ($self->{TEST_MANAGER_PORT}) passed during the object creation

=item Returns

    1 - on success
    0 - on failure

=item Example(s):
    
    $Obj->stopManager();

=back
    
=cut

sub stopManager {
   my ($self, %args) = @_;
   my $sub_name = 'stopManager()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $xmlData = '<ns:RV-Remote-Stop-Manager></ns:RV-Remote-Stop-Manager>';
   my $response = '';
   $args{-port} ||= $self->{TEST_MANAGER_PORT};
   $self->{MANAGER_SOCKET} = new IO::Socket::INET ( PeerHost => $self->{PROLAB_HOST}, PeerPort => $args{-port}, Proto => $self->{PROTOCOL}) unless (defined $self->{MANAGER_SOCKET});

   unless ($self->{MANAGER_SOCKET} ) {
      $logger->error(__PACKAGE__ . ".setSystem: failed to create $self->{PROTOCOL} socket to host -> $self->{PROLAB_HOST} with port -> $args{-port}");
      $logger->debug(__PACKAGE__ . ".setSystem:  <-- Leaving sub. [0]");
      return 0;
   }

   unless ($response = $self->sendXMLData($xmlData, $self->{MANAGER_SOCKET})) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to stoped manager");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   if ($self->{SOCKET}) {
      $self->{SOCKET}->close;
      undef $self->{SOCKET};
   }

   $self->{MANAGER_SOCKET}->close;
   undef $self->{MANAGER_SOCKET};

   my $result = index($response, '<retval>OK'); 
   if ( $result > 0) {
      $logger->info(__PACKAGE__ . ".$sub_name: successfully stoped manager");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      return 1;
   } else {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to stop manager, server returned below information");
      $logger->debug(__PACKAGE__ . ".$sub_name: $response");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
}

=pod

=head3 SonusQA::PROLAB::runScenario()

    This function will run specified scenario of the agent

=over

=item Arguments

    Hash with required details 
	Manditory
 		-AgentID
		-ScenarioName

=item Returns

    1 - on success
    0 - on failure

=item Example(s):

    my %input = ( -AgentID => 2, -ScenarioName => HD_1400k_H264_G711_Reef);
    $Obj->runScenario(%input);

=back

=cut

sub runScenario {
   my ($self, %args) = @_;
   my $sub_name = 'runScenario()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $response = '';
   foreach ('-AgentID', '-ScenarioName') {
      unless (defined $args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
         return 0;
      }
   }

my $attempts = $args{-attempt} || 25;
my $waitfor = $args{-waitfor} || 5;
   #framing the xml data
   my $xmlData .= "<ns:RV-Run-Scenario><AgentID>". $args{-AgentID} . "</AgentID><ScenarioName>" . $args{-ScenarioName} . "</ScenarioName></ns:RV-Run-Scenario>";

foreach (1..$attempts) {
sleep $waitfor;

   unless ($response = $self->sendXMLData($xmlData)) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to run scenario");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   my $result = index($response, '<retval>OK');
   if ( $result > 0) {
      $logger->info(__PACKAGE__ . ".$sub_name: successfully ran scenario");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      sleep $waitfor;
      return 1;
   }

   if (grep(/running/, split("\n", $response))) {
      $logger->info(__PACKAGE__ . ".$sub_name: scenario is already up");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      sleep $waitfor;
      return 1;
   }

   if (grep(/Siteup/, split("\n", $response))) {
      $logger->info(__PACKAGE__ . ".$sub_name: scenario is already up");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
      sleep $waitfor;
      return 1;
   }
}

   $logger->error(__PACKAGE__ . ".$sub_name: failed to run scenario, server returned below information");
   $logger->debug(__PACKAGE__ . ".$sub_name: $response");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
   return 0;

}

=pod

=head3 SonusQA::PROLAB::stopAgent()

    This function will stop specified scenario of the agent

=over

=item Arguments

    Hash with required details 
		Manditory
			-AgentID
			-ScenarioName

=item Returns

    1 - on success
	0 - on failure

=item Example(s):
    my %input = ( -AgentID => 2, -ScenarioName => HD_1400k_H264_G711_Reef);
    $Obj->stopAgent(%input);

=back    

=cut

sub stopAgent {
   my ($self, %args) = @_;
   my $sub_name = 'stopAgent)';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $response = '';
   foreach ('-AgentID', '-ScenarioName') {
      unless (defined $args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
         return 0;
      }
   }
   #framing the xml data
   my $attempts = $args{-attempt} || 50;
   my $waitfor = $args{-waitfor} || 1;
   my $xmlData .= "<ns:RV-Stop-Agent><AgentID>". $args{-AgentID} . "</AgentID><ScenarioName>" . $args{-ScenarioName} . "</ScenarioName></ns:RV-Stop-Agent>";

   foreach (1..$attempts) {

      unless ($response = $self->sendXMLData($xmlData)) {
         $logger->error(__PACKAGE__ . ".$sub_name: failed to stop agent -> $args{-AgentID}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
         return 0;
      }

      my $result = index($response, '<retval>OK');
      if ( $result > 0) {
         $logger->info(__PACKAGE__ . ".$sub_name: successfully stoped agent -> $args{-AgentID}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
         return 1;
      } 
      # what if its already stoped :-)
      $result = index($response, 'Agent is already down') if ( $result == -1 );
      if ($result > 0) {
         $logger->info(__PACKAGE__ . ".$sub_name: agent is already stoped");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
         return 1;
      }
   }
      
   $logger->error(__PACKAGE__ . ".$sub_name: failed to stop agent -> $args{-AgentID}, server returned below information");
   $logger->debug(__PACKAGE__ . ".$sub_name: $response");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
   return 0;
}

=pod

=head3 SonusQA::PROLAB::execCmd()

    This function enables user to execute any command on the SEAGULL server.

=over

=item Arguments

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Returns

    Output of the command executed.

=item Example(s)

    my @results = $obj->execCmd("ls /ats/NBS/sample.csv");
    This would execute the command "ls /ats/NBS/sample.csv" on the session and return the output of the command.

=back

=cut

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
   my(@cmdResults,$timestamp);
   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
   }
   $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      return @cmdResults;
   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   return @cmdResults;
}

=pod

=head3 SonusQA::PROLAB::getAgentlogs()

    This function used to get prolab logs and store in ATS machine

=over

=item Arguments

    Hash with required details 
          Manditory
              -AgentName
              -serverLogPath     -> path of prolab log in prolab machine
              -storeLogPath      -> path of ats machine , where the prolab logs will be stored
              -testId            -> testcase id

=item Returns

    1 - on success
    0 - on failure

Note - On complition $self->{$args{-AgentName}}->{EventLog}, $self->{$args{-AgentName}}->{MessageLog} will hold path and name of Event, Message logs respectively

=item Example(s):
    my %input = (AgentName => 'sender', -serverLogPath => 'C:\Prolab\logs\sender', -storeLogPath => "\/home\/rpateel", -testId => '123'); 
    $Obj->getAgentlogs(%input);

=back
    
=cut

sub getAgentlogs {
   my ($self, %args) = @_;
   my $sub_name = 'getAgentlogs';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

   my $response = '';
   foreach ('-AgentName', '-serverLogPath', '-storeLogPath', '-testId') {
      unless (defined $args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub_name: manditory argument $_ is blank");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
         return 0;
      }
   }

   unless ($self->{PROLAB_SESSION}->{conn}->cmd("cd $args{-serverLogPath}")) {
      $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $args{-serverLogPath}");
      $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{PROLAB_SESSION}->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{PROLAB_SESSION}->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{PROLAB_SESSION}->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }

   my @output = ();
   
   unless (@output = $self->{PROLAB_SESSION}->{conn}->cmd("dir /O:-D /b Log_*_$args{-AgentName}*") ) {
      $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log files");
      $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{PROLAB_SESSION}->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{PROLAB_SESSION}->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{PROLAB_SESSION}->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   chomp @output;
   my %logs = ();
   foreach ( @output ) {
      last if ($logs{EventLog} and $logs{MessageLog});
      $logs{EventLog} = $_ if ($_ =~ /^Log_Events/);
      $logs{MessageLog} = $_ if ($_ =~ /^Log_Message/);
   }

   if ( !$logs{EventLog} or !$logs{MessageLog}) {
      $logger->error(__PACKAGE__ . ".$sub_name: unable to find prolab logs");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   $self->{$args{-AgentName}}->{EventLog} = "$args{-storeLogPath}/Prolab-EventLog-$args{-AgentName}-$args{-testId}-$datestamp";
   $self->{$args{-AgentName}}->{MessageLog} = "$args{-storeLogPath}/Prolab-MessageLog-$args{-AgentName}-$args{-testId}-$datestamp";
   
   # i dont like to force user to enable ftp and telnet both, hence forcing my self to go with type command
   my $data = '';

   unless ( @output = $self->{PROLAB_SESSION}->{conn}->cmd("type $logs{EventLog}")) {
      $logger->error(__PACKAGE__ . ".$sub_name: unable to get EventLog content");
      $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{PROLAB_SESSION}->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{PROLAB_SESSION}->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{PROLAB_SESSION}->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   chomp @output;
   my $f;
   unless ( open LOGFILE, $f = ">$self->{$args{-AgentName}}->{EventLog}" ) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to open file $self->{$args{-AgentName}}->{EventLog}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   print LOGFILE join("\n", @output);
   unless ( close LOGFILE ) {
      $logger->error("$self->{MODULE} :  Cannot close output file \'$self->{$args{-AgentName}}->{EventLog}\'- Error: $!");
      $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
      return 0;
   }

   unless ( @output = $self->{PROLAB_SESSION}->{conn}->cmd("type $logs{MessageLog}")) {
      $logger->error(__PACKAGE__ . ".$sub_name: unable to get MessageLog content");
      $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{PROLAB_SESSION}->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{PROLAB_SESSION}->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{PROLAB_SESSION}->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   chomp @output;

   unless ( open LOGFILE, $f = ">$self->{$args{-AgentName}}->{MessageLog}" ) {
      $logger->error(__PACKAGE__ . ".$sub_name: failed to open file $self->{$args{-AgentName}}->{EventLog}");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
      return 0;
   }
   print LOGFILE join("\n", @output);
   unless ( close LOGFILE ) {
      $logger->error("$self->{MODULE} :  Cannot close output file \'$self->{$args{-AgentName}}->{MessageLog}\'- Error: $!");
      $logger->debug("$self->{MODULE} : <-- Leaving sub. [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: sucessfully got EventLog and MessageLog");
   $logger->debug(__PACKAGE__ . ".$sub_name: EventLog name is stored to \$self->{$args{-AgentName}}->{EventLog} , MessageLog name is stored to \$slef->{$args{-AgentName}}->{MessageLog}");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
   return 1;
}

=pod

=head3 SonusQA::PROLAB::closeConn()

  This routine is called by the object destructor.  It closes the communications (TELNET|SSH) session.
  This is done by simply calling close() on the session object

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut
   
sub closeConn {
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn");
   $logger->debug(__PACKAGE__ . ".closeConn Closing PROLAB connection...");
   my ($self) = @_;

   $self->stopManager(); #just stoping the manager

   if ($self->{conn}) {
      $self->{conn}->print("exit");
      $self->{conn}->close;
   }

   if ( $self->{PROLAB_SESSION}->{conn} ) {
      $self->{PROLAB_SESSION}->{conn}->print("exit");
      $self->{PROLAB_SESSION}->{conn}->close;
   }

}

1;
