package SonusQA::FAXLAB;


=head1 NAME

SonusQA::FAXLAB - Perl module for FAXLAB interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::FAXLAB->new();


=head1 REQUIRES

Perl5.8.7, IO::Socket, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper

=head2 AUTHORS

Naresh Kumar Anthoti <nanthoti@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

   This module provides an interface for FAXLAB Machine. 
   start, stop, config and newdb ations can be performed on FAXLAB using this ATS module.

=head1 METHODS

=over

=cut


use strict;
use IO::Socket;
use Data::Dumper;
use SonusQA::Utils;
use SonusQA::Base;
use Log::Log4perl qw(get_logger :easy);

our @ISA = qw(SonusQA::Base);
my $receivedData;
my (%FAXLAB_SW_INF,%FAX_MANAGER);

#  FaxLab Software Commands
$FAXLAB_SW_INF{-cmdStartChanneltraps} 	=  "start" ;
$FAXLAB_SW_INF{-cmdStopChanneltraps}   	=  "stop" ;
$FAXLAB_SW_INF{-cmdConfigChanneltrap}  	=  "config" ;
$FAXLAB_SW_INF{-cmdChanneltrapNewdb}   	=  "newdb" ;
$FAXLAB_SW_INF{-tcpSocket}  =  '-1' ;
$FAXLAB_SW_INF{-gotOrigResponse} = 0;
$FAXLAB_SW_INF{-gotAnsResponse}  = 0;
$FAXLAB_SW_INF{-faxlabResult} = 0;

=item B<new>

    Constructure subroutine to create FAXLAB object.

    Arguments:
        -tms_alias : testbed element alias

    Return Value:
        object reference.

    Usage:
        my $obj = SonusQA::FAXLAB->new(-tms_alias => 'faxlab_test');

=cut

sub new{
   my($class, %args) = @_;
   my $sub = "new";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
   my $alias = $args{-tms_alias};
   my $tms_alias = &SonusQA::Utils::resolve_alias($alias); 
   my $self = {
	WIN_IP => $tms_alias->{NODE}{1}{IP},
	WIN_PORT => $tms_alias->{NODE}{1}{PORT},
	CHANNEL_TRAP_ANS_IP => $tms_alias->{CHANNEL_TRAP}{1}{ANS_IP},
	CHANNEL_TRAP_ORIG_IP => $tms_alias->{CHANNEL_TRAP}{1}{ORIG_IP},
	IAD_ANS_IP => $tms_alias->{IAD}{1}{ANS_IP},
	IAD_ANS_TYPE => $tms_alias->{IAD}{1}{ANS_TYPE},
	IAD_ORIG_IP => $tms_alias->{IAD}{1}{ORIG_IP},
	IAD_ORIG_TYPE => $tms_alias->{IAD}{1}{ORIG_TYPE}
   };
   bless($self,$class);
   $self->{TYPE}  = __PACKAGE__;   
   my %sessionLogInfo;
   $self->getSessionLogInfo(-sessionLogInfo  => \%sessionLogInfo);
   $self->{sessionLog1} = $sessionLogInfo{sessionDumpLog};
   $self->{sessionLog2} = $sessionLogInfo{sessionInputLog};
   $logger->debug(" FaxLab object Created");
   $logger->debug(__PACKAGE__ . ".$sub sessionDumpLog [$self->{sessionLog1}]");
   $logger->debug(__PACKAGE__ . ".$sub sessionInLog [$self->{sessionLog2}]"); 
   return $self;
}

=item B<faxlabSendMessage>

    This subroutine send message.

    Arguments:
        - The message to send

    Return Value:
        response value on success
        0 - on failure

    Usage:
        my $result = $Obj->faxlabSendMessage($msg);
=cut

sub faxlabSendMessage {

   my ($self,$msg)= @_;
   my ($sub,$response);
   $sub = "faxlabSendMessage";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my ($fhDump,$fhInput);
   unless (open $fhDump,'>>',$self->{sessionLog1}) {
      $logger->debug("Failed to open session Log $self->{sessionLog1} $!");
      return 0;
   }
   print $fhDump "Sending: $msg\n";
   unless (open $fhInput,'>>',$self->{sessionLog2}){
      $logger->debug("Failed to open session Log $self->{sessionLog2} $!");
      return 0;
   }   
   print $fhInput "Sending: $msg\n"; 
   close $fhDump;
   close $fhInput;
   if (!($response = $FAXLAB_SW_INF{-tcpSocket}->send($msg))) {
      $logger->debug( "Could not write [$msg] at FAXLAB server's socket. Terminating application !!");
      return 0;
   } 
   return  $response;
}

=item B<faxlabStartChanneltrap>

    This subroutine start channel trap.

    Arguments:
        - The message to send

    Return Value:
        response value on success
        0 - on failure

    Usage:
        my $result = $Obj->faxlabStartChanneltrap($msg);
=cut

sub faxlabStartChanneltrap {

   my $self = shift;
   my ($sub,$msg);
   $sub = "faxlabStartChanneltrap";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug("Starting the ChannelTraps");
   $msg = "$FAXLAB_SW_INF{-cmdStartChanneltraps} $FAXLAB_SW_INF{-Originator}->[0],$FAXLAB_SW_INF{-Answerer}->[0]" ;
   return ($self->faxlabSendMessage($msg));
}

=item B<faxlabStopChanneltrap>

    This subroutine stop channel trap.

    Arguments:
        None

    Return Value:
        response value on success
        0 - on failure

    Usage:
        my $result = $Obj->faxlabStopChanneltrap();
=cut

sub faxlabStopChanneltrap {
   my $self = shift;
   my ($sub,$msg);
   $msg = "$FAXLAB_SW_INF{-cmdStopChanneltraps}" ;
   return ($self->faxlabSendMessage ($msg));
}

=item B<faxlabSetChanneltrapConfig>

    This subroutine set channel trap configuration.

    Arguments:
        - channel trap id
        - configuration file

    Return Value:
        response value on success
        0 - on failure

    Usage:
        my $result = $obj->faxlabSetChanneltrapConfig($channeltrapid,$cfgfile);
=cut

sub faxlabSetChanneltrapConfig {
   my ($self,$channeltrapId,$cfgFile) = @_;
   my $msg =  "$FAXLAB_SW_INF{-cmdConfigChanneltrap} $channeltrapId $cfgFile" ;
   return ($self->faxlabSendMessage($msg)) ;
}

=item B<faxlabProcessConfigResponse>

    This subroutine check the configuration response.

    Arguments:
        - message

    Return Value:
        1 - if message contain the text 'successfully'
        0 - unless

    Usage:
        my $result = $obj->faxlabProcessConfigResponse($msg);
=cut

sub faxlabProcessConfigResponse{
   my $msg = shift;
#  ChannelTrap Id is configured Successfully.
   if ($msg =~ m/successfully/i) {
      return 1 ;
   } else {
#  Error in configuration.
   return 0 ;
   }
}

=item B<faxlabCreateNewdb>

    This subroutine create new database.

    Arguments:
        - database name

    Return Value:
        response value on success
        0 - on failure

    Usage:
        my $result = $obj->faxlabCreateNewdb($dbname);
=cut

sub faxlabCreateNewdb {
   my ($self,$dbname) = @_;
   my $msg = "$FAXLAB_SW_INF{-cmdChanneltrapNewdb} $dbname" ;
   return ($self->faxlabSendMessage($msg)) ;
}

=item B<faxlabProcessNewdbResponse>

    This subroutine check new database response.

    Arguments:
        - message

    Return Value:
        1 - if the message contain the text 'successfully' or 'already exists'
        0 - unless

    Usage:
        my $result = $obj->faxlabProcessNewdbResponse($msg);
=cut

sub faxlabProcessNewdbResponse{
   my $msg = shift;
   my $sub = "faxlabProcessNewdbResponse";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
#  Database <databasefilename> successfully created.
   if ($msg =~ m/successfully/i) {
      $logger->debug( " $msg");
      return 1 ;
   }elsif($msg =~ m/already exists/i) {
      $logger->debug( " $msg");
      return 1;
   }elsif($msg =~ /Cannot create database/){
      $logger->debug( " $msg");
      return 0;
   }
}

=item B<faxlabProcessInitResponse>

    This subroutine process init response.

    Arguments:
        - response

    Return Value:
        1 - on success
        0 - on failure

    Usage:
        my $result = $obj->faxlabProcessInitResponse($response);

=cut

sub faxlabProcessInitResponse{
   my ($self,$response) = @_;
   my $sub = "faxlabProcessInitResponse";
   my($ansID,$origID);
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug("Socket Init response [$response]");

=for comment
  Channel traps connected to host nanthoti-ind: 2
  Channel trap: 10.54.104.120, ID: 500041, status: STOPPED
  Channel trap: 10.54.104.119, ID: 500042, status: STOPPED  
=cut

   $FAXLAB_SW_INF{-ChannelTrapsCount} = $1 if ($response =~ m/Channel traps connected.*:\s+(\d)/i);
   $logger->debug("NO.Of Channel traps Connected : $FAXLAB_SW_INF{-ChannelTrapsCount}") ;
   if ($FAXLAB_SW_INF{-ChannelTrapsCount} == 2){
       $ansID = $1 if ($response =~ /$self->{CHANNEL_TRAP_ANS_IP},\s+ID:\s+(\d+),/);     
       $origID = $1 if ($response =~ /$self->{CHANNEL_TRAP_ORIG_IP},\s+ID:\s+(\d+),/);     
       unless ($ansID || $origID){
           $logger->error("Not able to get the ChannelTrap IDs, check ANS_IP/ORIG_IP values given on TMS matches with the actual channelTrap IPs connected to system");
           return 0;
       }
       $FAXLAB_SW_INF{-Answerer}   = [$ansID,$self->{CHANNEL_TRAP_ANS_IP}];
       $FAXLAB_SW_INF{-Originator} = [$origID,$self->{CHANNEL_TRAP_ORIG_IP}];
       $logger->debug( "Originator details: @{$FAXLAB_SW_INF{-Originator}}");
       $logger->debug("Answerer details: @{$FAXLAB_SW_INF{-Answerer}}");
   }else{
       $logger->debug("Two ChannelTraps required to run the test");
       return 0; 
   }
   return 1;
}

=item B<parseMessage>

    This subroutine parse the message and return the result.

    Arguments:
        - response

    Return Value:
        - result

    Usage:
        my $result = $obj->parseMessage($response);

=cut

sub parseMessage{
   my ($self,$response) = @_;
   my $sub = "parseMessage";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my @temp = split(',',$response);
   my $profile = $temp[1];
   my $result = $temp[2];
   my ($mode, $description) = split(':',$temp[0]);

   $logger->debug("==========================================");
   $logger->debug("TestCaseId :$FAX_MANAGER{-testcaseId}");
   $logger->debug("Mode : $mode");
   $logger->debug( "Profile : $profile");
   $logger->debug("Result : $result");
   $logger->debug("==========================================") ;

# TOOLS-16540 - The Response will be in below formate,
#
# Answering End:
# $response = 'Ans: RX 5 Pg ECM MH V.34 33.6k 200x100,Xerox WorkCentre Pro 575,Passed,2,03/23/18,19:17:13,10.54.51.143,3333,5550123,1085'

# Originating End:
# $response = 'Orig: TX 5 Pg ECM MH V.34 33.6k 200x100,Xerox WorkCentre Pro 575,Passed,4,03/23/18,19:17:13,10.54.51.142,3333,5550123,1086'

   $self->{RECEIVED_DATA}->{$mode} = {
					Description    => $description,
					Profile        => $temp[1],
					Result         => $temp[2],
					FOM            => $temp[3],
					Date           => $temp[4],
					Time           => $temp[5],
					'Channel Trap' => $temp[6],
					Answerer       => $temp[7],
					Originator     => $temp[8],
					ID             => $temp[9],
				     };

   return $result ;
}

=item B<faxlabProcessStartResponse>

    This subroutine process the start response.

    Arguments:
        - response

    Return Value:
        1 - on success
        0 - on failure

    Usage:
        my $result = $obj->faxlabProcessStartResponse($response);

=cut

sub faxlabProcessStartResponse{
   my ($self,$response) = @_; 
   my $sub = "faxlabProcessStartResponse";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   if ($response =~ m/^Orig/){
      $FAXLAB_SW_INF{-gotOrigResponse} = 1;
      $FAXLAB_SW_INF{-orgResult} = $self->parseMessage($response);
      if($FAXLAB_SW_INF{-orgResult} eq "Failed"){
	$logger->debug("Orig ChannelTrap is Failed Aborting the FaxCall");
	$self->faxlabStopChanneltrap();
        return 0;		
      }
      if($FAXLAB_SW_INF{-orgResult} eq "Passed" && $FAXLAB_SW_INF{-ansResult} eq "Passed"){
        $FAXLAB_SW_INF{-faxlabResult} = 1 ;
      }
   }
   if ($response =~ m/^Ans/){
      $FAXLAB_SW_INF{-gotAnsResponse} = 1;
      $FAXLAB_SW_INF{-ansResult} = $self->parseMessage($response);
      if($FAXLAB_SW_INF{-ansResult} eq "Failed"){
        $logger->debug("Ans ChannelTrap is Failed Aborting the FaxCall");
        $self->faxlabStopChanneltrap();
        return 0;
      }
      if ($FAXLAB_SW_INF{-orgResult} eq "Passed" && $FAXLAB_SW_INF{-ansResult} eq "Passed"){
	 $FAXLAB_SW_INF{-faxlabResult} = 1 ;
      }
   }

}

=item B<faxlabResponseHandler>

    This subroutine handle the response.

    Arguments:
        None

    Return Value:
        1 - on success
        0 - on failure

    Usage:
        my $result = $obj->faxlabResponseHandler();

=cut

sub faxlabResponseHandler{
   my $self = shift;
   my $sub = "faxlabResponseHandler";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $id;
   $FAXLAB_SW_INF{-tcpSocket}->recv($receivedData,1024);
   $receivedData =~ s/^\s+|\s+$//g;
   return -1 if(length $receivedData <= 1 );
   my $fhDump;
   unless (open $fhDump,'>>',$self->{sessionLog1}) {
      $logger->debug("Failed to open session Log $self->{sessionLog1} $!");
      return 0;
   }
   print $fhDump "Received: $receivedData\n";
   close $fhDump;
   if ($FAXLAB_SW_INF{-faxlabState} eq  "INIT"){
      return 0 unless($self->faxlabProcessInitResponse($receivedData));
      return 0 unless ($self->faxlabCreateNewdb ($FAX_MANAGER{-dbFile})); 
      $FAXLAB_SW_INF{-faxlabState} = "NEW_DB";
      return 1;
   }
   elsif($FAXLAB_SW_INF{-faxlabState} eq  "NEW_DB"){
      return 0 if(!faxlabProcessNewdbResponse($receivedData));
      $id = $FAXLAB_SW_INF{-Originator}->[0] ;
      return 0 unless ($self->faxlabSetChanneltrapConfig($id,$FAX_MANAGER{-cfgOrg}));
      $FAXLAB_SW_INF{-faxlabState} = "CONFIG_ORIG";
      return 1;
   }
   elsif($FAXLAB_SW_INF{-faxlabState} eq  "CONFIG_ORIG"){
      if (!faxlabProcessConfigResponse($receivedData)) {
#       Not able to configure, so no point in going ahead with the test
	$logger->debug("Error in $FAXLAB_SW_INF{-faxlabState} ErrMsg: $receivedData");
	return 0;
      }else{
	$logger->debug("$FAXLAB_SW_INF{-faxlabState}: $receivedData");
      }
      $id =  $FAXLAB_SW_INF{-Answerer}->[0] ;
      return 0 unless ($self->faxlabSetChanneltrapConfig($id,$FAX_MANAGER{-cfgAns}));
      $FAXLAB_SW_INF{-faxlabState} = "CONFIG_ANS" ;
      return 1;
   }
   elsif($FAXLAB_SW_INF{-faxlabState} eq  "CONFIG_ANS"){
      if(!faxlabProcessConfigResponse($receivedData)) {
#       Not able to configure, so no point in going ahead with the test
	$logger->debug("Error in $FAXLAB_SW_INF{-faxlabState} ErrMsg: $receivedData");
	return 0;
      }else{
        $logger->debug("$FAXLAB_SW_INF{-faxlabState}: $receivedData");
      }
#      Fax Test Initialization Complete. Starting Channel Traps...DONE" ;
      return 0 unless ($self->faxlabStartChanneltrap());
      $FAXLAB_SW_INF{-faxlabState} = "START" ;
      return 1;
   }
   elsif($FAXLAB_SW_INF{-faxlabState} eq  "START"){
      return($self->faxlabProcessStartResponse($receivedData));
   }
}

=item B<initFaxlabInterface>

    This subroutine create INET connection.

    Arguments:
        None

    Return Value:
        1 - on success
        0 - on failure

    Usage:
        my $result = $obj->initFaxlabInterface();

=cut

sub initFaxlabInterface {
   my $self = shift;
   %FAX_MANAGER = @_;
   my ($sockFd,$returnValue);
   $FAX_MANAGER{-maxTime} |= "300";
   my $sub = "initFaxlabInterface";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug("");
   $logger->debug("FaxCall Initiated for testcaseId: $FAX_MANAGER{-testcaseId} ");

   eval{
	$sockFd = IO::Socket::INET->new(Proto  => "tcp",
                           PeerAddr  => $FAX_MANAGER{-winHost},
                           PeerPort  => $FAX_MANAGER{-winPort}) or die "can't connect to port $FAX_MANAGER{-winPort} on $FAX_MANAGER{-winHost}: $!";
   };
   if($@){
	$logger->debug("Failed to create the socket with host $FAX_MANAGER{-winHost} and port $FAX_MANAGER{-winPort}, check FaxLab RemoteControl is opened or not");
	print "Failed to create the socket with host $FAX_MANAGER{-winHost} and port $FAX_MANAGER{-winPort}, check FaxLab RemoteControl is opened or not\n";
	return 0;
   }
   $FAXLAB_SW_INF{-faxlabState} =  "INIT" ; 
   $FAXLAB_SW_INF{-tcpSocket} = $sockFd;
   my ($fhDump,$fhInput);
   unless (open $fhDump,'>>',$self->{sessionLog1}) {
      $logger->debug("Failed to open session Log $self->{sessionLog1} $!");
      return 0;
   }
   print $fhDump "FAXLAB session started for TestCase Id : $FAX_MANAGER{-testcaseId}\n";
   unless (open $fhInput,'>>',$self->{sessionLog2}){
      $logger->debug("Failed to open session Log $self->{sessionLog2} $!");
      return 0;
   }   
   print $fhInput "FAXLAB session started for TestCase Id : $FAX_MANAGER{-testcaseId}\n";
   close $fhDump;
   close $fhInput;
   my @faxStates = ("INIT","NEW_DB","CONFIG_ORIG","CONFIG_ANS");
   while(grep { $FAXLAB_SW_INF{-faxlabState} eq $_ } @faxStates ){
      $returnValue = $self->faxlabResponseHandler();
      if($returnValue == -1){
	$logger->debug("No response received from FaxLab socket \n");
	teardownFaxlabInterface();
	return -1;
      }
      if($returnValue == 0){
	teardownFaxlabInterface();
        return 0;
      }
   }
   my ($timeTaken,$timeOut);
   $timeOut = 0;
   if($FAXLAB_SW_INF{-faxlabState} eq "START"){
      do{
	my @startTime = (localtime(time()))[2,1,0];
	$self->faxlabResponseHandler();
	my @verifyTimeOut = (localtime(time()))[2,1,0];
	$timeTaken = $timeTaken + (($verifyTimeOut[0]*3600) + ($verifyTimeOut[1]*60)+$verifyTimeOut[2])-(($startTime[0]*3600) + ($startTime[1]*60)+$startTime[2]);
        $timeOut = 1 if($timeTaken >= $FAX_MANAGER{-maxTime});	
      }while(!$FAXLAB_SW_INF{-gotOrigResponse} | !$FAXLAB_SW_INF{-gotAnsResponse} && !$timeOut);
   }
   if($timeOut && !$FAXLAB_SW_INF{-faxlabResult}){
      $logger->debug(" TimedOut Aborting the FaxCall for testCaseId $FAX_MANAGER{-testcaseId}");
      $self->terminateFaxTestSession();
      return 0;
   }
   if($FAXLAB_SW_INF{-faxlabResult}){
      $logger->debug(" Fax call result for testCaseId $FAX_MANAGER{-testcaseId}: Passed");
      $self->terminateFaxTestSession();
      return 1;
   }else{ 
      $logger->debug(" Fax call result for testCaseId $FAX_MANAGER{-testcaseId}: Failed");
      $self->terminateFaxTestSession();
      return 0;
   }
}

=item B<teardownFaxlabInterface>

    This subroutine close socket connection with Faxlab.

    Arguments:
        None

    Return Value:
        None

    Usage:
        $obj->teardownFaxlabInterface();

=cut

sub teardownFaxlabInterface{
   my $sub = "teardownFaxlabInterface";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug("Closing Socket connection with Faxlab");
   $FAXLAB_SW_INF{-gotOrigResponse} = $FAXLAB_SW_INF{-gotAnsResponse} = $FAXLAB_SW_INF{-faxlabResult} = 0;
#  Close TCP Socket
   close $FAXLAB_SW_INF{-tcpSocket} ;
}

=item B<terminateFaxTestSession>

    This subroutine terminate fax test session.

    Arguments:
        None

    Return Value:
        None

    Usage:
        $obj->terminateFaxTestSession();

=back

=cut

sub terminateFaxTestSession{
   my $self = shift;
   my $sub = "terminateFaxTestSession";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   if(!$self->faxlabStopChanneltrap()){
      $logger->debug("Failed to stop channelTraps");
   }else{
      $logger->debug("Stoped ChannelTraps"); 
   }
   teardownFaxlabInterface();
}

1;
