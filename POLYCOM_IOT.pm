package SonusQA::POLYCOM_IOT;

=head1 NAME

SonusQA::POLYCOM_IOT - Perl module for BROADSOFT POLYCOM phone interaction in an environment which has different types of end points like POLYCOM, LYNC, BTBC etc.  

=head1 SYNOPSIS

use ATS;  # This is the base class for Automated Testing Structure

my $obj = SonusQA::POLYCOM_IOT->new();


=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 AUTHORS

Ravi Kumar Krishnaraj <rkrishnaraj@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

This module provides an interface for interoperability between BROADSOFT POLYCOM phones and other end points like LYNC and BTBC. Many of the operations performed on the  phone such a dialing and answering call, transferring call, call hold and unhold, rebooting phone, making conference call, sending voicemail and many more operations can   be performed using this module.

=head1 METHODS

=cut


use strict;
use Data::Dumper;
use LWP::UserAgent;
use SonusQA::Utils;
use IO::Socket::INET;
use XML::Simple;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use threads;
use threads::shared;
our ($spipx_path);
require Exporter;
our @ISA = qw(Exporter SonusQA::POLYCOM SonusQA::Base);
use SonusQA::POLYCOM::HTTPSERVER;
our ($socket,$client_socket);
our ($peer_address,$peer_port,$data): shared;
our ($HTTP_SERVER_IP_TEMP,$HTTP_SERVER_PORT_TEMP);
our @EXPORT =  qw( handleResponse  $socket $client_socket );
use vars qw( %polycomObjects %polycomObjectsData ); 

=head2 SonusQA::POLYCOM_IOT::new()

  This function will create a new object of POLYCOM_IOT

=over

=item Arguments

  None

=item Returns

  object of the POLYCOM_IOT

=back

=cut

sub new{
	my ( $class,  %args) = @_; 
	my %tms_alias = ();
	my $sub_name = "new";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	my $alias = $args{-tms_alias_name};
	my $tms_alias = &SonusQA::Utils::resolve_alias($alias);
	my $self = {
		PHONEIP => $tms_alias->{NODE}{1}{IP},
		PHONEPORT =>  $tms_alias->{NODE}{1}{PORT},
		PUSHUSERID => $tms_alias->{LOGIN}{1}{USERID},
		PUSHPASSWORD => $tms_alias->{LOGIN}{1}{PASSWD},
		SPIPUSERID => $tms_alias->{LOGIN}{2}{USERID},
		SPIPPASSWORD => $tms_alias->{LOGIN}{2}{PASSWD},
		LWP =>  LWP::UserAgent->new(),
		HTTP_SERVER_IP => $tms_alias->{HTTPSERVER}{1}{IP},
		HTTP_SERVER_PORT => $tms_alias->{HTTPSERVER}{1}{PORT},
		HTTP_SERVER_PATH => $tms_alias->{HTTPSERVER}{1}{BASEPATH},
		NUMBER => $tms_alias->{NODE}{1}{NUMBER}
	};
	bless $self, $class;
	unless($self->doInitialization(%args)){
		$logger->error(__PACKAGE__ . ".$sub_name: Failed in Initialization");
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return $self;
}

=head2 SonusQA::POLYOCM_IOT::makeCall()

  This function is used to make a call

=over

=item Arguments

  args <hash>

=item Returns

  1 - Call is successful
  0 - Call is unsuccessful

=back

=cut

sub makeCall{

        my ($self) = shift;
        my ($self1) = shift;
        my (%args) = @_;
        my %a     = (-callForward => 0);
        my ($phone_no);
        my ($failures) = 1;
        my ($content,$response,$out,$spipxfilename,@numbers,$filename);
        my $sub_name = "makeCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $phone_no = $self1->{NUMBER};
        while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $logger->error(__PACKAGE__ . ".$sub_name: Attempting a call from \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') to \n'$self1->{TMS_ALIAS_NAME}'('$self1->{PHONEIP}')");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "DIAL_$phone_no".".spipx";
        @numbers = split("",$phone_no);
        $out = "Key:SoftKey1\n";
        foreach my $digit (@numbers){
                $out .= "Key:DialPad$digit\n";
        }
        $out .= "Key:SoftKey1";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call to $self1->{PHONEIP}");
                return 0;
        }
        while ($failures <= 5 ){
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->getState() eq "RINGING" or $a{-callForward}){
                                $logger->debug(__PACKAGE__ . ".$sub_name: MAKE CALL success : $phone_no is ringing");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 5 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call to $self1->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP} in 10 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
                        }
                        return 0;
		}
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 2 seconds.. Attempt: $failures");
                sleep 2;
	}
}

=head2 SonusQA::POLYOCM_IOT::answerCall()

  The function is used to answer the call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is answered successfully
  0 - call is not answered successfully

=back

=cut

sub answerCall{
        my $self = shift;
        my $self1 = shift;
        my ($content,$response,$out,$spipxfilename,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my $sub_name = "answerCall";
        my ($calltype) = "NORMAL";
        my (@states) = ("INCOMING" , "RINGING", "OUTGOING");
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        my $sleep_time = $args{-sleeptime};
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        if(defined $args{-blind} and $args{-blind} == 1){
                @states = ("INCOMING","RINGING","CONNECTED","OUTGOING");
                $logger->debug(__PACKAGE__ . ".$sub_name: Answering blind transferred call..");
        }
        unless (defined $args{-checkRinging}) { $args{-checkRinging} = 0;}
	while ($failures <= 10){
        	if( ($self->getState() ne $states[0] and $failures > 9) ){
                	$logger->debug(__PACKAGE__ . ".$sub_name:   $self->{PHONEIP} is not in the expected state.");
			$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
            		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                	return 0;
        	} elsif ($args{-checkRinging} and $self->{STATE} eq $states[1]){
                         last;
                } elsif (($args{-checkRinging} eq 0) and ( $self->{STATE} eq $states[0] or $self->{STATE} eq $states[1])){
			last;
		} else {
			$logger->debug(__PACKAGE__ . ".$sub_name: Sleeping for 2 seconds as the Phone was not in the expected state");
			$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");  
			sleep 2;
			$failures++;
		}
	}
	$failures = 1;

        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to answer call on \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') from $self1->{PHONEIP} ");
	$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "ANSWER_$self->{PHONEIP}".".spipx";
        if(defined $args{-callWait} and $args{-callWait} == 1) {
            $out  = "Key:ArrowDown\n";
            $out .= "Key:SoftKey1\n";
        } else {
            $out = "Key:SoftKey1\n";
        }

        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name: Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in answer call. Calling phone: $self1->{PHONEIP} Called phone: $self->{PHONEIP}\n");
                return 0;
        }
        while ($failures <= 5 ){
                @states = ("CONNECTED","OUTGOING");
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if(($self->getState() eq $states[0] or (defined $args{-callWait} and $args{-callWait}))){
                            $sleep_time ||= 10;
                            $logger->debug(__PACKAGE__ . ".$sub_name: The call is answered. Sleeping for $sleep_time seconds.");
                            sleep $sleep_time;
                            if(($self->getState() eq $states[0] or (defined $args{-callWait} and $args{-callWait}))){
                                    $logger->debug(__PACKAGE__ . ".$sub_name: The call is still in the connected state after '$sleep_time' seconds..");
                                    $logger->debug(__PACKAGE__ . ".$sub_name: ANSWER CALL success");
				    $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
                                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                    return 1;
                                } else {
                                        $logger->debug(__PACKAGE__ . ".$sub_name: The call was disconnected in 10 seconds..");
                                        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                                        return 0;
                                }
                        } elsif($failures == 5 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to answer call from $self1->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
				$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
				$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 2 seconds.. Attempt: $failures");
                sleep 2;
        }
}

=head2 SonusQA::POLYOCM_IOT::disconnectCall()

  The function is used to disconnect the call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is disconnected successfully
  0 - call is not disconnected successfully

=back

=cut

sub disconnectCall{
        my $self = shift;
        my $self1 = shift;
        my ($content,$response,$out,$spipxfilename,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my $sub_name = "disconnectCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $self->getState();
        if(($self->{STATE} eq "ON_HOOK" or $self->{STATE} eq "DISCONNECTED") ){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect the call from $self1->{PHONEIP} The call is not in the connected state. Check the phone status below..");
		$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
        }
        if(defined $args{-conferencecall} and $args{-conferencecall} == 1){
                $logger->debug(__PACKAGE__ . ".$sub_name: This is a conference call..");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to disconnect call on \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') ");
	$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "DISCONNECT_$self->{PHONEIP}".".spipx";
        $out = "Key:SoftKey2\n";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name: Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure while disconnecting the call: Disconnect called from: $self1->{PHONEIP}");
                return 0;
        }
        while ($failures <= 5 ){
                if ($response->is_success and ${$response}{_rc} == 200) {
                        $self->getState();
                        if(($self->{STATE} eq "ON_HOOK" or $self->{STATE} eq "DISCONNECTED") ){
                                $logger->debug(__PACKAGE__ . ".$sub_name: DISCONNECT CALL success ");
				$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 5 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect the call from $self1->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
				$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 2 seconds.. Attempt: $failures");
                sleep 2;
        }
}

=head2 SonusQA::POLYOCM_IOT::holdCall()

  The function is used to hold the call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is held successfully
  0 - call is not held successfully

=back

=cut

sub holdCall{
        my $self = shift;
        my ($content,$response,$out,$spipxfilename,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my (@states) = ("CALLHOLD","CALLHELD");
        my $sub_name = "holdCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $self->getState();
        unless($self->{STATE} eq "CONNECTED" ){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do a call hold on $self->{PHONEIP} The phone is not in the 'CONNECTED' state.");
		$logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                return 0;
        }
        if(defined $args{-musiconhold} and $args{-musiconhold} == 1){
                $logger->error(__PACKAGE__ . ".$sub_name: Music on hold is enabled on $self->{PHONEIP}");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a call hold on '$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "HOLD_$self->{PHONEIP}".".spipx";
        $out = "Key:Hold\n";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name: Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure while doing a call hold  on : $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 5 ){
                $self->getState();
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->{STATE} eq $states[0] ){
                                $logger->debug(__PACKAGE__ . ".$sub_name: HOLD CALL success ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 5 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do call hold on $self->{PHONEIP}");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 2 seconds.. Attempt: $failures");
                sleep 2;
        }
}

=head2 SonusQA::POLYOCM_IOT::unholdCall()

  The function is used to unhold the call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is unheld successfully
  0 - call is not unheld successfully

=back

=cut

sub unholdCall{
        my $self = shift;
        my ($content,$response,$out,$spipxfilename,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my (@states) = ("CALLHOLD","CALLHELD");
        my $sub_name = "unholdCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        if(defined $args{-musiconhold} and $args{-musiconhold} == 1){
                $logger->error(__PACKAGE__ . ".$sub_name: Music on hold is enabled on $self->{PHONEIP}");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $self->getState();
        unless($self->{STATE} eq $states[0] or (defined $args{-callWait} and $args{-callWait} == 1)){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do a call unhold on $self->{PHONEIP} The phones are not in the expected state.");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a call unhold on '$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "HOLD_$self->{PHONEIP}".".spipx";
        $out = "Key:Hold\n";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name: Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure while doing a call unhold/resume on : $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 5 ){
                $self->getState();
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->{STATE} eq "CONNECTED" ){
                                $logger->debug(__PACKAGE__ . ".$sub_name: UNHOLD CALL success ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 5 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do call unhold on $self->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
                        }
                        return 0;
                }
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 2 seconds.. Attempt: $failures");
                sleep 2;
        }
}

=head2 SonusQA::POLYOCM_IOT::getState()

  The function is used to get the state of the call

=over

=item Arguments

  None

=item Returns

  state of the call

=back

=cut

sub getState{
    my ($self) = shift;
    $self->{STATE} = $polycomObjects{$self->{PHONEIP}};
    return $self->{STATE};
}

=head2 SonusQA::POLYOCM_IOT::transferCall()

  The function is used to transfer the call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is transferred successfully
  0 - call is not transferred successfully

=back

=cut

sub transferCall{

        my ($self) = shift;
        my ($self1) = shift;
        my ($self2) = shift;
        my ($failures) = 1;
        my ($content,$response,$out,$spipxfilename,@numbers,$filename,$phone_no);
        my (%args) = @_;
        my ($transfertype);
        my $sub_name = "transferCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $phone_no = $self2->{NUMBER};
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        if (defined $args{-blind} and $args{-blind} == 1){
                $logger->debug(__PACKAGE__ . ".$sub_name: This is a blind transfer call..");
                $transfertype = "BLIND";
        } else {
                $logger->debug(__PACKAGE__ . ".$sub_name: This is an attended transfer call..");
                $transfertype = "ATTENDED";
        }
        unless($self->getState eq "CONNECTED"){
                $logger->error(__PACKAGE__ . ".$sub_name: '$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') is not in the CONNECTED state. \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'  ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a call transfer on '$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- '$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "TRANSFER_CALL_$phone_no".".spipx";
        $out = "Key:Transfer\n";
        $out .= "Key:SoftKey4\n" if($transfertype eq "BLIND");
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do a call transfer on $self->{PHONEIP} from $self1->{PHONEIP} to $self2->{PHONEIP} ");
                return 0;
        }
        while ($failures <= 2 ){
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 5 seconds.. Attempt: $failures");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->getState eq "CALLHOLD"){
                                $logger->debug(__PACKAGE__ . ".$sub_name: Transferring call.. (Transfer type : $transfertype). Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
                                last;
                        } elsif($failures == 2 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer to $self2->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}')");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
        }
        $failures = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: Dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
        $out = undef;
        $phone_no = $self2->{NUMBER};
        @numbers = split("",$phone_no);
        foreach my $digit (@numbers){
                $out .= "Key:DialPad$digit\n";
        }
        $spipxfilename = "TRANSFER_CALL_DIAL_$phone_no".".spipx";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer on $self->{PHONEIP} to $self2->{PHONEIP} after dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 2 ){
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 5 seconds.. Attempt: $failures");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        my $checkstate;
                        if($transfertype eq "BLIND"){
                                $checkstate = "ON_HOOK";
                        } elsif ($transfertype eq "ATTENDED"){
                                $checkstate = "OUTGOING";
                        }
                        if($self->getState eq $checkstate ){
                                $logger->debug(__PACKAGE__ . ".$sub_name: TRANSFER CALL success. Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
                                $logger->debug(__PACKAGE__ . ".$sub_name:  '$self2->{PHONEIP}' is ringing. You can now answer the call on '$self2->{PHONEIP}' ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 2 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer to $self2->{PHONEIP} after dialing $self2->{PHONEIP}'s number. ");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
        }
}

=head2 SonusQA::POLYOCM_IOT::answerAttendedTransferCall()

  The function is used to answer the attended transfer call

=over

=item Arguments

  args <hash>

=item Returns

  1 - call is answered successfully
  0 - call is not answered successfully

=back

=cut

sub answerAttendedTransferCall{

        my ($self) = shift;
        my ($self1) = shift;
        my ($self2) = shift;
        my ($failures) = 1;
        my ($content,$response,$out,$spipxfilename,@numbers,$filename,$phone_no);
        my (%args) = @_;
        my $sleep_time = $args{-sleeptime};
        my $sub_name = "answerAttendedTransferCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $phone_no = $self->{NUMBER};
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        unless($self->getState eq "INCOMING" ){
                $logger->error(__PACKAGE__ . ".$sub_name: The phones are not in the expected state. Phone Status: \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
        }
        $logger->error(__PACKAGE__ . ".$sub_name: Initial status- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."' ");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "TRANSFER_CALL_ANSWER$phone_no".".spipx";
        $out = "Key:SoftKey1\n";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to answer call  on $self->{PHONEIP} from $self1->{PHONEIP} transferred from $self2->{PHONEIP} ");
                return 0;
        }
        while ($failures <= 2 ){
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 5 seconds.. Attempt: $failures");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->getState eq "CONNECTED"){
                        $sleep_time ||= 10;
                        $logger->debug(__PACKAGE__ . ".$sub_name: The call is answered. Sleeping for $sleep_time seconds.");
                                sleep $sleep_time;
                                if($polycomObjects{$self2->{PHONEIP}} eq "OUTGOING" and $self->getState eq "CONNECTED" and $self1->getState eq "CALLHELD"){
                                    $logger->debug(__PACKAGE__ . ".$sub_name: The call is still in the connected state after 10 seconds..");
                                    $logger->debug(__PACKAGE__ . ".$sub_name: ANSWER CALL success after attended transfer.. Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                    last;
                                } else {
                                        $logger->debug(__PACKAGE__ . ".$sub_name: The call was disconnected in $sleep_time seconds..");
                                        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                                        return 0;
                                }
                        } elsif($failures == 2 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer to $self2->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
        }
        $failures = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: Dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
        $out = "Key:Transfer\n";
        $spipxfilename = "ATTEND_TRANSFER_CALL_RETRANSFER_$phone_no".".spipx";
        unless($filename = $self2->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self2->{LWP}->post("http://$self2->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer on $self2->{PHONEIP} from $self1->{PHONEIP} to $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 2 ){
                $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Sleeping for 5 seconds.. Attempt: $failures");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if($self->getState eq "CONNECTED"){
                                $logger->debug(__PACKAGE__ . ".$sub_name: ATTENDED TRANSFER CALL success. Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                        } elsif($failures == 2 ) {
                                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call transfer to $self->{PHONEIP} from  $self1->{PHONEIP} ");
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                #$logger->debug(__PACKAGE__ . ".$sub_name: Rebooting $self2->{PHONEIP} ");
                #$self2->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401){
                                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
                        }
                        return 0;
                }
        }

}

=head2 SonusQA::POLYOCM_IOT::reboot()

  The function is used to reboot the phone

=over

=item Arguments

  None

=item Returns

  1 - Phone is rebooted successfully
  0 - Phone is not rebooted successfully

=back

=cut

sub reboot{

        my ($self) = shift;
        my (%args) = @_;
        my ($phone_no) = "32456";;
        my ($failures) = 1;
        my ($regeventcount) = 0;
        my ($content,$response,$out,$spipxfilename,@numbers,$filename);
        my $sub_name = "reboot";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a reboot on \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone State- \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}') : '".$self->getState."'");
        unless($self->authenticate()){
                $logger->error(__PACKAGE__ . ".$sub_name: Failure in authentication");
        }
        $spipxfilename = "DIAL_$phone_no".".spipx";
        @numbers = split("",$phone_no);
        $out = "Key:Menu\n";
        foreach my $digit (@numbers){
                $out .= "Key:DialPad$digit\n";
        }
        $out .= "Key:SoftKey1\n";
        $out .= "Key:DialPad3\n";
        $out .= "Key:SoftKey4\n";
        unless($filename = $self->createSpipxFile($spipxfilename,$out)){
                $logger->error(__PACKAGE__ . ".$sub_name:Error while creating spipx file : $spipxfilename");
                return 0;
        }
        $polycomObjectsData{$self->{PHONEIP}} = undef;
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')){
                $logger->error(__PACKAGE__ . ".$sub_name: Failed while trying to reboot \n'$self->{TMS_ALIAS_NAME}'('$self->{PHONEIP}')");
                return 0;
        }        

        $logger->debug(__PACKAGE__ . ".$sub_name: --> Waiting for 90 seconds to phone come up after reboot");
        sleep (90);
       
        return 1;
}
1;
