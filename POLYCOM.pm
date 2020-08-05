package SonusQA::POLYCOM;

=head1 NAME

    SonusQA::POLYCOM - Perl module for Polycom phones

=head1 REQUIRES

    Log::Log4perl, SonusQA::Base, LWP::UserAgent, SonusQA::Utils, SonusQA::POLYCOM::HTTPSERVER 

=head1 DESCRIPTION

    This module is required for communication over Polycom phones.

=head1 METHODS

=cut

use strict;
use warnings;
use Data::Dumper;
use LWP::UserAgent;
use SonusQA::Utils;
use IO::Socket::INET;
use XML::Simple;
use Log::Log4perl qw(:easy);
use threads;
use threads::shared;
use SonusQA::POLYCOM::HTTPSERVER;
use vars qw( %polycomObjects %polycomObjectsData );
require Exporter;
our @ISA = qw(Exporter);

our ($spipxPath);
our ($socket, $client_socket);
our ($peer_address, $peer_port, $data): shared;
our ($HTTP_SERVER_IP_TEMP,$HTTP_SERVER_PORT_TEMP);
our @EXPORT =  qw( handleResponse  $socket $client_socket );
 
=head2 C< new >

DESCRIPTION:

    To create POLYCOM object.

ARGUMENTS:

    -phoneip          => Phone's ip
    -phoneport        => Phone's port
    -pushuserid       => Push userid 
    -pushpassword     => Push password
    -spipuserid       => SPIP userid
    -spippassword     => SPIP password
    -http_server_ip   => Httpserver ip
    -http_server_port => Httpserver port
    -http_server_path => Httpserver path
    -number           => Number to dial

PACKAGE:

    SonusQA::POLYCOM 

OUTPUT:

    Object Reference - SUCCESS
    0 - FAIL    

EXAMPLE:

    $ats_obj_ref = SonusQA::POLYCOM->new(-phoneip          => "$alias_hashref->{NODE}{1}{IP}",
                                         -phoneport        => "$alias_hashref->{NODE}{1}{PORT}",
                                         -pushuserid       => "$alias_hashref->{LOGIN}{1}{USERID}",
                                         -pushpassword     => "$alias_hashref->{LOGIN}{1}{PASSWD}",
                                         -spipuserid       => "$alias_hashref->{LOGIN}{2}{USERID}",
                                         -spippassword     => "$alias_hashref->{LOGIN}{2}{PASSWD}",
                                         -http_server_ip   => "$alias_hashref->{HTTPSERVER}{1}{IP}",
                                         -http_server_port => "$alias_hashref->{HTTPSERVER}{1}{PORT}",
                                         -http_server_path => "$alias_hashref->{HTTPSERVER}{1}{BASEPATH}",
                                         -number           => "$alias_hashref->{NODE}{1}{NUMBER}",
                                        );
    
=cut

sub new {
    my ( $class,  %args) = @_; 
    my $subName          = "new";
    my $logger           = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <--- Entered Sub");

    my $self = bless {}, $class;
    unless ($self->doInitialization(%args)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed in Initialization");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return $self;
}

=head2 C< doInitialization >

DESCRIPTION:

    Routine to set object defaults. It is a private subroutine called by new().

ARGUMENTS:

    args (Hash)

PACKAGE:

    SonusQA::POLYCOM

OUTPUT:

    1 - SUCCESS
    0 - FAIL  

EXAMPLE:

    unless ($self->doInitialization(%args)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed in Initialization");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

=cut

sub doInitialization {
    my($self, %args)= @_;
    my $subName     = "doInitialization";
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my $httpserverinstance;
    my $flag = 1;

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    if ( exists $ENV{LOG_LEVEL} ) {
        $self->{LOG_LEVEL} = uc $ENV{LOG_LEVEL};
    }
    else {
        $self->{LOG_LEVEL} = 'DEBUG';
    }
    
    foreach (keys %args) {
	unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$subName: $_ is undefined."); 
	    $flag=0;
	    last;
	}
        my $var = uc($_);
        $var =~ s/^-//i;
        $self->{$var} = $args{$_};
    }
    
    unless($flag) {
	$logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $self->{LWP}                      = LWP::UserAgent->new();
    $self->{STATE}                    = "ON_HOOK";
    $self->{COMM_TYPE}                = "NONE";
    $polycomObjects{$self->{PHONEIP}} = "ON_HOOK";
    $self->{OBJ_HOST}                 = $self->{PHONEIP};
    $HTTP_SERVER_IP_TEMP              = $self->{HTTP_SERVER_IP};
    $HTTP_SERVER_PORT_TEMP            = $self->{HTTP_SERVER_PORT};
    $spipxPath                        = $self->{HTTP_SERVER_PATH};
    
    # Start HTTP server to receive notifications from phone
    unless ($httpserverinstance = &SonusQA::POLYCOM::HTTPSERVER::getHttpServerInstance($HTTP_SERVER_IP_TEMP, $HTTP_SERVER_PORT_TEMP)) {
        $logger->debug(__PACKAGE__ . ".$subName: Failure in getting the HTTP server instance.. '$httpserverinstance' ");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: httpserverinstance state: '$httpserverinstance' ");
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;
}

=head2 C< authenticate >

DESCRIPTION:
    
    To perform PUSH Authentication and SPIP Configuration.

ARGUMENTS:

    None 

PACKAGE:

    SonusQA::POLYCOM

OUTPUT:

    Object Reference 

EXAMPLE:
    
    $self->authenticate();
    
=cut

sub authenticate {

    my $self    = shift;
    my $subName = "authenticate";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    $logger->debug(__PACKAGE__ . ".$subName: Performing PUSH Authentication and SPIP Configuration");
    $self->{LWP}->credentials("$self->{PHONEIP}:$self->{PHONEPORT}", 'PUSH Authentication', $self->{PUSHUSERID} => $self->{PUSHPASSWORD});
    $self->{LWP}->credentials("$self->{PHONEIP}:$self->{PHONEPORT}", 'SPIP Configuration', $self->{SPIPUSERID} => $self->{SPIPPASSWORD});

    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return $self;
}

sub makeCall {

    my $self     = shift;
    my $self1    = shift;
    my %args     = @_;
    my $subName  = "makeCall";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");    
    my %a        = (-callForward => 0, -doNotPressSoftKey => '0');
    my $failures = 1;
    my $flag = 1;
    
    my ($phoneNum, $content, $response, $out, $spipxFileName, @numbers, $filename);
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    $phoneNum = $self1->{NUMBER};
    $logger->debug(__PACKAGE__ . ".$subName: Number to dial  : $phoneNum");            
    $logger->error(__PACKAGE__ . ".$subName: Calling from $self->{PHONEIP} to $self1->{PHONEIP}"); 
    $logger->debug(__PACKAGE__ . ".$subName: Initial phone state of  $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} and $self1->{PHONEIP} : $polycomObjects{$self1->{PHONEIP}}");

    # Authenticate with phone to send commands
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }

    $logger->debug(__PACKAGE__ . ".$subName: Authentication is successful");

    # Create spipx file
    $spipxFileName = "DIAL_$phoneNum" . ".spipx";
    @numbers       = split("",$phoneNum);

    # In some cases where involves the dialing feature code followed by phone number
    # in those cases we need to press softkey
    unless ($a{-doNotPressSoftKey}) {
        $out = "Key:SoftKey1\n";
    }

    foreach my $digit (@numbers) {
        $out .= "Key:DialPad$digit\n";
    }

    unless ($a{-doNotPressSoftKey}) {
        $out .= "Key:SoftKey1";
    }

    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to create spipx file : $spipxFileName");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Creation of spipx file is successful");

    # Send commands to phone
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
RETRY:
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName:[FAILURE]  Failed to send commands to $self->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Sending commands to phone is successful");
    sleep (5);

    while ($failures <= 40) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
            my $callingPhoneState = "$polycomObjects{$self->{PHONEIP}}";
            my $calledPhoneState  = "$polycomObjects{$self1->{PHONEIP}}";         
            my $state1            = ($callingPhoneState eq "RINGING" or $callingPhoneState eq "RINGBACK" or $callingPhoneState eq "OUTGOING" or $a{-doNotPressSoftKey});
            my $state2            = ($calledPhoneState eq "INCOMING" or $a{-callForward});
            $logger->debug(__PACKAGE__ . ".$subName: Calling phone IP: $self->{PHONEIP} and Phone state: $callingPhoneState");
            $logger->debug(__PACKAGE__ . ".$subName: Called phone IP : $self1->{PHONEIP} and Phone state: $calledPhoneState");
            $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1 \$state2: $state2");
                        
            if ($state1 and $state2) {
                $logger->debug(__PACKAGE__ . ".$subName: Make call is successfull.................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 40) {
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} or $self1->{PHONEIP}");
                $logger->debug(__PACKAGE__ . ".$subName: Make call is failed.................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else { 
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Authentication failure".Dumper($response));
		if($flag) {#TOOLS-18105 
		    $flag = 0;		
		    $logger->debug(__PACKAGE__ . ".$subName: Resending request again.");
		    goto RETRY;
		}	
            } else {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to send commands to phone".Dumper($response));
            }
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
}

sub answerCall {
    my $self    = shift;
    my $self1   = shift;
    my %args    = @_;
    my $subName = "answerCall";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    my ($content,$response,$out,$spipxFileName,$filename);
    my $failures  = 1;
    my $sleepTime = $args{-sleeptime};   
    my @states    = ("INCOMING", "RINGING", "RINGBACK", "OUTGOING");
    my $flag = 1;
           
    # Check whether to answer blind transfered call
    if (defined $args{-blind} and $args{-blind} == 1) {
        @states = ("INCOMING", "RINGING", "CONNECTED", "OUTGOING", "CALLHELD");
        $logger->debug(__PACKAGE__ . ".$subName: Answering blind transferred call..");
    } elsif (defined $args{-phoneConnected} and $args{-phoneConnected} == 1) {
        @states = ("INCOMING", "RINGING", "CONNECTED", "OUTGOING", "CALLHELD");
        $logger->debug(__PACKAGE__ . ".$subName: Calling phone is already is in connecyted state");
    }   

    # Check the initial state of the phones
    my $calledPhoneState  = "$polycomObjects{$self->{PHONEIP}}";
    my $callingPhoneState = "$polycomObjects{$self1->{PHONEIP}}";         
    my $state1            = ($calledPhoneState eq $states[0] or $calledPhoneState eq $states[1]);
    my $state2            = ($callingPhoneState eq $states[1] or $callingPhoneState eq $states[2] or $callingPhoneState eq $states[3] or $callingPhoneState eq $states[4]);
    $logger->debug(__PACKAGE__ . ".$subName: Calling phone IP: $self1->{PHONEIP} and Phone state: $callingPhoneState");
    $logger->debug(__PACKAGE__ . ".$subName: Called phone IP : $self->{PHONEIP} and Phone state: $calledPhoneState");
    $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1 \$state2: $state2");

    unless (($state1 and $state2) or (defined $args{-autoCallBack} and $args{-autoCallBack})) {
        $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Failed to answer call at $self->{PHONEIP} because phones are not in initial expected state");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$subName: Phones are in initial expected state, now answering the call at $self->{PHONEIP}");

    # Authenticate with phone to send commands
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }

    $logger->debug(__PACKAGE__ . ".$subName: Authentication is successful");

    # Create spipx file
    $spipxFileName = "ANSWER_$self->{PHONEIP}" . ".spipx";

    if (defined $args{-callWait} and $args{-callWait} == 1) {
        $out  = "Key:ArrowDown\n";
        $out .= "Key:SoftKey1\n";
    } elsif (defined $args{-answerWithLine} and $args{-answerWithLine} != 0) {
        $out  = "Key:Line$args{-answerWithLine}\n";
    } else {
        $out = "Key:SoftKey1\n";
    }

    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName"); 
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Creation of spipx file is successful");

    # Send commands to phone (to press 'Answer' key)
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
RETRY:
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to send commands to $self->{PHONEIP}\n");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Sending commands to phone is successful");
    sleep (3);

    while ($failures <= 20 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 1;
        # In case of shared call event phone will send "OFF_HOOK" only and not "CONNECTED"
        @states = ("CONNECTED", "OUTGOING", "OFF_HOOK");        
        if ($response->is_success and ${$response}{_rc} == 200) {
            my $calledPhoneState  = "$polycomObjects{$self->{PHONEIP}}";
            my $callingPhoneState = "$polycomObjects{$self1->{PHONEIP}}";         
            my $state1            = ($calledPhoneState eq $states[0] or $calledPhoneState eq $states[2] or (defined $args{-callWait} and $args{-callWait}));
            my $state2            = ($callingPhoneState eq $states[0] or $callingPhoneState eq $states[1] or (defined $args{-autoCallBack} and $args{-autoCallBack}));
            $logger->debug(__PACKAGE__ . ".$subName: Calling phone IP: $self1->{PHONEIP} and Phone state: $callingPhoneState");
            $logger->debug(__PACKAGE__ . ".$subName: Called phone IP : $self->{PHONEIP} and Phone state: $calledPhoneState");
            $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1 \$state2: $state2");

            if ($state1 and $state2) {
                $sleepTime ||= 10;
                $logger->debug(__PACKAGE__ . ".$subName: The call is answered waiting for $sleepTime seconds");
                sleep $sleepTime;
                # Again check the call state because in some cases call will disconnect automatically after few seconds
                my $calledPhoneState  = "$polycomObjects{$self->{PHONEIP}}";
                my $callingPhoneState = "$polycomObjects{$self1->{PHONEIP}}";
                my $state1            = ($calledPhoneState eq $states[0] or $calledPhoneState eq $states[2] or (defined $args{-callWait} and $args{-callWait}) or (defined $args{-autoCallBack} and $args{-autoCallBack}));
                my $state2            = ($callingPhoneState eq $states[0] or $callingPhoneState eq $states[1] or (defined $args{-autoCallBack} and $args{-autoCallBack}));
                $logger->debug(__PACKAGE__ . ".$subName: Phone state afterwaiting for $sleepTime seconds");
                $logger->debug(__PACKAGE__ . ".$subName: Calling phone IP: $self1->{PHONEIP} and Phone state: $callingPhoneState");
                $logger->debug(__PACKAGE__ . ".$subName: Called phone IP : $self->{PHONEIP} and Phone state: $calledPhoneState");
                $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1 \$state2: $state2");
                
                if ($state1 and $state2) {
                    $logger->debug(__PACKAGE__ . ".$subName: The call is still in the connected state after $sleepTime seconds");
                    $logger->debug(__PACKAGE__ . ".$subName: Answered the call successfuly..................");
                    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                    return 1;
                } else {
                    $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] The call was disconnected in $sleepTime seconds");
                    $logger->debug(__PACKAGE__ . ".$subName: Answering a call is failed..................");
                    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                    return 0;
                }
            } elsif ($failures == 20) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to answer call at $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} or $self1->{PHONEIP}");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                if($flag) {#TOOLS-18105
                    $flag = 0;
                    $logger->debug(__PACKAGE__ . ".$subName: Resending request again.");
                    goto RETRY;
                }
            } else {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Did not get a successful response. ".Dumper($response));
            }
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
}

sub disconnectCall {
    my $self    = shift;
    my $self1   = shift;
    my %a       = @_;
    my $subName = "disconnectCall"; 
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    my %args     = (-conferencecall => '0', -sharedCall => '0');
    my $failures = 1;
    while ( my ($key, $value) = each %a ) { $args{$key} = $value; }
    my ($content,$response,$out,$spipxFileName,$filename);

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    
    # Check the initial state of the phone  
    my $phoneStatus1 = "$polycomObjects{$self->{PHONEIP}}";  
    my $phoneStatus2 = "$polycomObjects{$self1->{PHONEIP}}"; 
    my $state1       = ($phoneStatus1 eq "ON_HOOK" or $phoneStatus1 eq "DISCONNECTED");
    my $state2       = ($phoneStatus2 eq "ON_HOOK" or $phoneStatus2 eq "DISCONNECTED");
    $logger->debug(__PACKAGE__ . ".$subName: Disconnect call at $self->{PHONEIP}");
    $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} and Phone state: $phoneStatus1");
    $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} and Phone state: $phoneStatus2");
    $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1  \$state2: $state2");

    if ($state1 or $state2) {
        if ($args{-conferencecall} or $args{-sharedCall}) {
            $logger->debug(__PACKAGE__ . ".$subName: Its a conferenece call or shared call");
        } else {
            $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Phones are not in initial expected state");
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
       }
    }

    # Authenticate with phone to send commands
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }

    # Create spipx file
    $spipxFileName = "DISCONNECT_$self->{PHONEIP}" . ".spipx";
    $out = "Key:SoftKey2\n";

    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName");
        return 0;
    }

    # Send commands to phone (to press 'End Call' key)
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to send commands to $self->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    while ($failures <= 20 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
             my $phoneStatus1 = "$polycomObjects{$self->{PHONEIP}}";  
             my $phoneStatus2 = "$polycomObjects{$self1->{PHONEIP}}"; 
             my $state1       = ($phoneStatus1 eq "ON_HOOK" or $phoneStatus1 eq "DISCONNECTED");
             my $state2       = ($phoneStatus2 eq "ON_HOOK" or $phoneStatus2 eq "DISCONNECTED" or $args{-conferencecall} == 1);
             $logger->debug(__PACKAGE__ . ".$subName: Disconnect call at $self->{PHONEIP}");
             $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} and Phone state: $phoneStatus1");
             $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} and Phone state: $phoneStatus2");
             $logger->debug(__PACKAGE__ . ".$subName: \$state1: $state1  \$state2: $state2");
            if ($state1 and $state2) {
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: Disconnecting the call is successful.................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 20) {
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} or $self1->{PHONEIP}");
                $logger->debug(__PACKAGE__ . ".$subName: Disconnecting the call is failed.................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Did not get a successful response. ".Dumper($response));
            }
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
}

sub holdCall {
    my $self = shift;
    my $self1 = shift;
    my ($content,$response,$out,$spipxFileName,$filename);
    my ($failures) = 1;
    my (%args) = @_;
    my (@states) = ("CALLHOLD", "CALLHELD");
    my $subName = "holdCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    # In case of shared call scenarion VVX phones wont send 'CONNECTED' notification it will send only 'OFF_HOOK' evenet
    unless (($polycomObjects{$self->{PHONEIP}} eq "CONNECTED" or defined $args{-sharedCall} and $args{-sharedCall} == 1) and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
        $logger->error(__PACKAGE__ . ".$subName: Failed to do a call hold on $self->{PHONEIP} Both the phones are not in the 'CONNECTED' state.");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
        return 0;
    }
    if (defined $args{-musiconhold} and $args{-musiconhold} == 1) {
        $logger->error(__PACKAGE__ . ".$subName: Music on hold is enabled on $self->{PHONEIP}");
    }
    $logger->debug(__PACKAGE__ . ".$subName: Attempting to do a call hold on $self->{PHONEIP} ");  
    $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "HOLD_$self->{PHONEIP}" . ".spipx";
    $out = "Key:Hold\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failure while doing a call hold  on : $self->{PHONEIP}");
        return 0;
    }
    while ($failures <= 10 ) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if (($polycomObjects{$self->{PHONEIP}} eq $states[0] or defined $args{-sharedCall} and $args{-sharedCall} == 1)and ($polycomObjects{$self1->{PHONEIP}} eq $states[1] or $args{-musiconhold})) {
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: Call HOLD is successful............");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 10 ) {
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: Call HOLD is failed............");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
}

sub unholdCall {
    my $self = shift;
    my $self1 = shift;
    my ($content,$response,$out,$spipxFileName,$filename);
    my ($failures) = 1;
    my (%args) = @_;
    my (@states) = ("CALLHOLD", "CALLHELD");
    my $subName = "unholdCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    if (defined $args{-musiconhold} and $args{-musiconhold} == 1) {
        $logger->error(__PACKAGE__ . ".$subName: Music on hold is enabled on $self->{PHONEIP}");
    }
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ((($polycomObjects{$self->{PHONEIP}} eq $states[0] or defined $args{-sharedCall} and $args{-sharedCall} == 1) and ($polycomObjects{$self1->{PHONEIP}} eq $states[1] or $args{-musiconhold})) or (defined $args{-callWait} and $args{-callWait} == 1)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to do a call unhold on $self->{PHONEIP} The phones are not in the expected state.");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
        return 0;
    }
        $logger->debug(__PACKAGE__ . ".$subName: Attempting to do a call unhold on $self->{PHONEIP} ");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "HOLD_$self->{PHONEIP}" . ".spipx";
    if (defined $args{-unHoldUsingLine} and $args{-unHoldUsingLine} != 0) {
        $out = "Key:Line$args{-unHoldUsingLine}\n"; 
    } else {
        $out = "Key:Hold\n";
    }
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failure while doing a call unhold/resume on : $self->{PHONEIP}");
        return 0;
    }
    while ($failures <= 10) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if (($polycomObjects{$self->{PHONEIP}} eq "CONNECTED" or defined $args{-sharedCall} and $args{-sharedCall} == 1) and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: Call UNHOLD is successful................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 10 ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to do call unhold on $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
}


sub transferCall {
    my $self    = shift;
    my $self1   = shift;
    my $self2   = shift;
    my %args    = @_;
    my $subName = "transferCall";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");   
    my ($transferType, $content, $response, $out, $spipxFileName, @numbers, $filename, $phoneNum);

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    # Check whether phones are in initial expected state 
    # Both the phones involved in initial call must be in 'CONNECTED' state
    unless ($polycomObjects{$self->{PHONEIP}} eq "CONNECTED" and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Phones are not in initial expected state");
        $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} Phone State: $polycomObjects{$self->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} Phone State: $polycomObjects{$self1->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->error(__PACKAGE__ . ".$subName: Phones are in initial expected state, now transfering the call......");

    $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} Phone State: $polycomObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} Phone State: $polycomObjects{$self1->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self2->{PHONEIP} Phone State: $polycomObjects{$self2->{PHONEIP}}");

    # Check transfer type
    $transferType = (defined $args{-blind} and $args{-blind} == 1) ? 'BLIND' : 'ATTENDED';
    $logger->error(__PACKAGE__ . ".$subName: Transfer Type ---> $transferType");
    
        
    # Authenticate with phone to send commands
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failure in authentication");
    }

    # Create spipx file
    $spipxFileName = "TRANSFER_CALL_$self2->{NUMBER}" . ".spipx";
    $out           = "Key:Transfer\n";

    unless ($filename = $self->createSpipxFile($spipxFileName, $out)) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to create spipx file : $spipxFileName");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    # Send commands to phone (to press 'Transfer' key)
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to send commands to phone $self->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->error(__PACKAGE__ . ".$subName: Successfuly sent commands to phone i.e. command to press 'Transfer' key, now waiting for responses");

    # Check the responses getting from phones after pressing the 'Transfer' key
    my $failures = 1;
    while ($failures <= 20 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self1->{PHONEIP}} eq "CALLHELD" or $polycomObjects{$self->{PHONEIP}} eq "CALLHOLD") {
                $logger->debug(__PACKAGE__ . ".$subName: Phones are in expected state after pressing the 'Transfer' key");
                $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} Phone State: $polycomObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} Phone State: $polycomObjects{$self1->{PHONEIP}}");
                last;
            } elsif ($failures == 20 ) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Phones are not in expected state after pressing the 'Transfer' key");
                $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self->{PHONEIP} Phone State: $polycomObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$subName: Phone IP: $self1->{PHONEIP} Phone State: $polycomObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
            }
            ++$failures;
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Authorization failed. Check your PUSH and SPIP credentials on the TMS");
            } else {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Did not get a successful response for HTTP request".Dumper($response));                
            }
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$subName: Pressing a 'Transfer' key is successful");
    sleep (3);

    # If it's a blind transfer press 'Blind' key on phone first
    if ($transferType eq "BLIND") {
        $out = undef;
        my $keyToPress = (defined $args{-vvx} and $args{-vvx} == 1) ? 'SoftKey4' : 'SoftKey4';
        $logger->debug(__PACKAGE__ . ".$subName: Key to press ---> $keyToPress");
        $out = "Key:$keyToPress\n";
        $spipxFileName = "BLIND_KEY_PRESS" . ".spipx";
        # Create SPIPX file
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
            $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }

        # Send commands to phone (to press 'Blind' key on phone)
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
            $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to send commands to phone $self->{PHONEIP} --  For pressing 'Blind' key");
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Pressing of 'Blind' key is successful, now dialing $self2->{NUMBER}");
        sleep (3);
    }

    # Now dial destination number
    # Create SPIPX file (For dialing destination number)
    $out     = undef;
    @numbers = split("", $self2->{NUMBER});

    foreach my $digit (@numbers) {
        $out .= "Key:DialPad$digit\n";
    }

    if (defined $args{-vvx} and $args{-vvx} == 1) {
        $out .= "Key:SoftKey1\n";
    }    

    $spipxFileName = "TRANSFER_CALL_DIAL_$phoneNum" . ".spipx";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    # Send commands to phone (to dial destination number)
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Failed to send commands to phone $self->{PHONEIP} --  For dialing destination number");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->error(__PACKAGE__ . ".$subName: Successfuly sent commands to dial destination number, now waiting for responses");

    # Check the responses getting from phones
    $failures = 1;
    my ($phoneState1, $phoneState2, $phoneState3);
    
    while ($failures <= 20 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {   
            if ($transferType eq "BLIND") {
                $phoneState1 = ($polycomObjects{$self->{PHONEIP}} eq "ON_HOOK" and ($polycomObjects{$self1->{PHONEIP}} eq "CONNECTED" or $polycomObjects{$self1->{PHONEIP}} eq "CALLHELD"));
                $phoneState2 = $polycomObjects{$self2->{PHONEIP}} eq "INCOMING";
            } else {
                $phoneState1 =($polycomObjects{$self->{PHONEIP}} eq "OUTGOING" and ($polycomObjects{$self1->{PHONEIP}} eq "CONNECTED" or $polycomObjects{$self1->{PHONEIP}} eq "CALLHELD"));
                $phoneState2 = $polycomObjects{$self2->{PHONEIP}} eq "INCOMING";
            }

            $logger->debug(__PACKAGE__ . ".$subName: \$phoneState1 = $phoneState1 and \$phoneState2 = $phoneState2");

            if ($phoneState1 and $phoneState2) {
                $logger->debug(__PACKAGE__ . ".$subName: Call transfer is successful...................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 20 ) {
                $logger->error(__PACKAGE__ . ".$subName: \$phoneState1 = $phoneState1 and \$phoneState2 = $phoneState2");
                $logger->debug(__PACKAGE__ . ".$subName: Call transfer is failed...................");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
            } 
            $failures++;
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: [FAILURE] Did not get a successful response. ".Dumper($response));                
            }
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
}

sub blindTransferCall{
    my $self    = shift; # Phone on which you wnat to initiate blind transfer
    my $self1   = shift; # Other phone which is in call with above one
    my $self2   = shift; # Destination phone where the call needs to be transfered
    my %args    = @_;
    my $subName = "blindTransferCall";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    $logger->debug(__PACKAGE__ . ".$subName: Blind transfer a call from $self->{PHONEIP} to $self2->{PHONEIP}");
        
    # Check for VVX1500 phone
    my $state;
    if (defined $args{-vvx}) {
        $state = $self->transferCall($self1, $self2, -blind => 1, -vvx => 1);
    } else {
        $state = $self->transferCall($self1, $self2, -blind => 1);
    }

    unless ($state) {
        $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Blind transfer call from $self->{PHONEIP} to $self2->{PHONEIP} is failed");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: [SUCCESS] Blind tarnsfer call from $self->{PHONEIP} to $self2->{PHONEIP} is successful");
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;
}

sub attendedTransferCall{
    my $self    = shift; # Phone on which you wnat to initiate blind transfer
    my $self1   = shift; # Other phone which is in call with above one
    my $self2   = shift; # Destination phone where the call needs to be transfered
    my %args    = @_;
    my $subName = "attendedTransferCall";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    $logger->debug(__PACKAGE__ . ".$subName: Attended transfer a call from $self->{PHONEIP} to $self2->{PHONEIP}");

   my $state;
    if (defined $args{-vvx}) {
        $state = $self->transferCall($self1, $self2, -vvx => 1);
    } else {
        $state = $self->transferCall($self1, $self2);
    }

    unless ($state) {
        $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Attended transfer call from $self->{PHONEIP} to $self2->{PHONEIP} is failed");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$subName: [SUCCESS] Attended tarnsfer call from $self->{PHONEIP} to $self2->{PHONEIP} is successful");
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;
}

sub answerBlindTransferCall{
    my $self    = shift;
    my $self1   = shift;
    my %args    = @_;
    my $subName = "answerBlindTransferCall";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    my $sleepTime = $args{-sleeptime};
    unless ($self->answerCall($self1, -blind => 1, $sleepTime)) {
        $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Answering Blind Transfer call failed at $self->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: [SUCCESS] Successfuly answered the call at $self->{PHONEIP} after blind transfer");
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;
}

sub disconnectBlindTransferCall{

    my ($self) = shift;
    my ($self1) = shift;
    my $subName = "disconnectBlindTransferCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ($self->disconnectCall($self1)) {
        $logger->debug(__PACKAGE__ . ".$subName: Disconnecting Blind Transfer call failed.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
}
sub disconnectAttendedTransferCall{

    my ($self) = shift;
    my ($self1) = shift;
    my $subName = "disconnectAttendedTransferCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ($self->disconnectCall($self1)) {
        $logger->debug(__PACKAGE__ . ".$subName: Disconnecting Attended Transfer call failed.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
}

sub disconnectConferenceCall{

    my ($self) = shift;
    my ($self1) = shift;
    my $subName = "disconnectConferenceCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ($self->disconnectCall($self1, -conferencecall => 1)) {
        $logger->debug(__PACKAGE__ . ".$subName: Disconnecting Conference call failed.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
}

sub answerAttendedTransferCall{

    my ($self) = shift;
    my ($self1) = shift;
    my ($self2) = shift;
    my ($failures) = 1;
    my ($content,$response,$out,$spipxFileName,@numbers,$filename,$phoneNum);
    my (%args) = @_;
    my $sleepTime = $args{-sleeptime};
    my $subName = "answerAttendedTransferCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $phoneNum = $self->{NUMBER};
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ($polycomObjects{$self->{PHONEIP}} eq "INCOMING" and $polycomObjects{$self1->{PHONEIP}} eq "CALLHELD" and $polycomObjects{$self2->{PHONEIP}} eq "OUTGOING") {
        $logger->error(__PACKAGE__ . ".$subName: The phones are not in the expected state. Phone Status: $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
    $logger->error(__PACKAGE__ . ".$subName: Initial state- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}'  '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}'");
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "TRANSFER_CALL_ANSWER$phoneNum" . ".spipx";
    $out = "Key:SoftKey1\n"; 
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to answer call  on $self->{PHONEIP} from $self1->{PHONEIP} transferred from $self2->{PHONEIP} ");
        return 0;
    }
    while ($failures <= 2 ) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 5;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self2->{PHONEIP}} eq "OUTGOING" and $polycomObjects{$self->{PHONEIP}} eq "CONNECTED" and $polycomObjects{$self1->{PHONEIP}} eq "CALLHELD") {
            $sleepTime ||= 10;
                $logger->debug(__PACKAGE__ . ".$subName: The call is answered. Sleeping for $sleepTime seconds.");
                sleep $sleepTime;
                if ($polycomObjects{$self2->{PHONEIP}} eq "OUTGOING" and $polycomObjects{$self->{PHONEIP}} eq "CONNECTED" and $polycomObjects{$self1->{PHONEIP}} eq "CALLHELD") {
                    $logger->debug(__PACKAGE__ . ".$subName: The call is still in the connected state after 10 seconds..");
                    $logger->debug(__PACKAGE__ . ".$subName: ANSWER CALL success after attended transfer.. Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                    last;
                } else {
                    $logger->debug(__PACKAGE__ . ".$subName: The call was disconnected in 10 seconds..");
                    $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                    return 0;
                }
            } elsif ($failures == 2 ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a call transfer to $self2->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self1->{PHONEIP} in 40 seconds.. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
    $failures = 1;
    $logger->debug(__PACKAGE__ . ".$subName: Dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
    $out = "Key:Transfer\n";
    $spipxFileName = "ATTEND_TRANSFER_CALL_RETRANSFER_$phoneNum" . ".spipx";
    unless ($filename = $self2->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self2->{LWP}->post("http://$self2->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to make a call transfer on $self2->{PHONEIP} from $self1->{PHONEIP} to $self->{PHONEIP}");
        return 0;
    }
    while ($failures <= 20 ) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 1;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self->{PHONEIP}} eq "CONNECTED" and $polycomObjects{$self2->{PHONEIP}} eq "ON_HOOK" and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
                $logger->debug(__PACKAGE__ . ".$subName: ATTENDED TRANSFER CALL success. Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;
            } elsif ($failures == 20 ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a call transfer to $self->{PHONEIP} from  $self1->{PHONEIP} ");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self2->{PHONEIP} ");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
}

sub conferenceCall{

    my ($self) = shift;
    my ($self1) = shift;
    my ($self2) = shift;
    my ($failures) = 1;
    my ($content,$response,$out,$spipxFileName,@numbers,$filename,$phoneNum);
    my (%args) = @_;
    my ($makenewcall);
    my $subName = "conferenceCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $phoneNum = $self2->{NUMBER};
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    if (defined $args{-existingcall} and $args{-existingcall} == 1) {
        $logger->debug(__PACKAGE__ . ".$subName: There is already a call established between $self->{PHONEIP} and $self1->{PHONEIP}. Phone Status- '$self->{PHONEIP}' : $polycomObjects{$self->{PHONEIP}} '$self1->{PHONEIP}' : '$polycomObjects{$self1->{PHONEIP}}' ");
        $makenewcall = "NO";
    } else {
        $logger->debug(__PACKAGE__ . ".$subName: There is no call in progress. First we establish a call between $self->{PHONEIP} and $self1->{PHONEIP} and then make a conference on '$self->{PHONEIP}' to '$self2->{PHONEIP}'. ");
        $makenewcall = "YES";
    }
    if ($makenewcall eq "YES") {
        $logger->debug(__PACKAGE__ . ".$subName: Attempting a makeCall from $self1->{PHONEIP} to $self->{PHONEIP} ");
        unless ($self1->makeCall($self)) {
            $logger->debug(__PACKAGE__ . ".$subName: Failed to make a call from $self1->{PHONEIP} to $self->{PHONEIP} ");
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Answering the call from $self1->{PHONEIP} on $self->{PHONEIP} ");
        unless ($self->answerCall($self1)) {
            $logger->debug(__PACKAGE__ . ".$subName: Failed to answer call from $self1->{PHONEIP} on $self->{PHONEIP} ");
            $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$subName: Verifying if both the phones are in the expected states(Both must be in the CONNECTED state) ");
    unless ($polycomObjects{$self->{PHONEIP}} eq "CONNECTED" and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
        $logger->error(__PACKAGE__ . ".$subName: Both $self->{PHONEIP} and $self1->{PHONEIP} are not in the CONNECTED state. '$self->{PHONEIP}' : $polycomObjects{$self->{PHONEIP}} '$self1->{PHONEIP}' : '$polycomObjects{$self1->{PHONEIP}}' ");
        $logger->error(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Verification success: $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
    $logger->debug(__PACKAGE__ . ".$subName: $self->{PHONEIP} and $self1->{PHONEIP} are in a call now. Making a conference call to '$self2->{PHONEIP}' ");
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "CONFERENCE_CALL_$phoneNum" . ".spipx";
    $out = "Key:Conference\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to do a conference call on $self->{PHONEIP} ");
        return 0;
    }
    while ($failures <= 8 ) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 5;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self1->{PHONEIP}} eq "CALLHELD" or $polycomObjects{$self->{PHONEIP}} eq "CALLHOLD" or $polycomObjects{$self->{PHONEIP}} eq "OFF_HOOK") {
                $logger->debug(__PACKAGE__ . ".$subName: Entered conference mode on $self->{PHONEIP}. Phone Status- '$self->{PHONEIP}' : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}'");
                last;
            } elsif ($failures == 8 ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a conference call on $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                #$self->reboot();
                #$self1->reboot() if ($makenewcall eq "YES");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
    $failures = 1;
    $logger->debug(__PACKAGE__ . ".$subName: Dialing $self2->{PHONEIP}'s number i.e. $self2->{NUMBER} on $self->{PHONEIP}");
    $out = undef;
    $phoneNum = $self2->{NUMBER};
    @numbers = split("",$phoneNum);
    foreach my $digit (@numbers) {
        $out .= "Key:DialPad$digit\n";
    }
    $out .= "Key:SoftKey1\n";
    $spipxFileName = "CONFERENCE_CALL_DIAL_$phoneNum" . ".spipx";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to make a conference call on $self->{PHONEIP} to $self2->{PHONEIP} after dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
        return 0;
    }
    while ($failures <= 8 ) {
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        sleep 5;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self->{PHONEIP}} eq "OUTGOING" or $polycomObjects{$self2->{PHONEIP}} eq "INCOMING") {
                $logger->debug(__PACKAGE__ . ".$subName:  '$self2->{PHONEIP}' is ringing. '$self2->{PHONEIP}' is ready to answer");
                $logger->debug(__PACKAGE__ . ".$subName: . Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                last;
            } elsif ($failures == 8 ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a conference call on $self->{PHONEIP} to $self2->{PHONEIP} after dialing $self2->{PHONEIP}'s number. ");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                #$self->reboot();
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
            }
            return 0;
        }
    }
    sleep 3;
    $logger->debug(__PACKAGE__ . ".$subName: Answering the call on $self2->{PHONEIP}");
    unless ($self2->answerCall($self)) {
        $logger->debug(__PACKAGE__ . ".$subName: Failed to answer conference call from $self->{PHONEIP} on '$self2->{PHONEIP}' ");
        if ($makenewcall eq "YES") {
                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self1->{PHONEIP} ");
                #$self1->reboot();
        }
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
        return 0;
    }
#   $logger->debug(__PACKAGE__ . ".$subName:  CONFERENCE CALL success. All the 3 phones are in a conference call now");
    $logger->debug(__PACKAGE__ . ".$subName: '$self2->{PHONEIP}' has successfully answered the call. Entering conference again on $self->{PHONEIP} to establish conference between the 3 phones.. ");
    $logger->debug(__PACKAGE__ . ".$subName: . Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");

    $phoneNum = $self->{NUMBER};
        $out = "Key:Conference\n";
    $spipxFileName = "CONFERENCE_CALL_ESTABLISH_$phoneNum" . ".spipx";
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a conference call on $self->{PHONEIP} to $self2->{PHONEIP} after dialing $self2->{PHONEIP}'s number on $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 8 ) {
                $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
                $logger->error(__PACKAGE__ . ".$subName: Waiting for conference to complete......");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if (($polycomObjects{$self->{PHONEIP}} eq "OFF_HOOK" or $polycomObjects{$self->{PHONEIP}} eq "CONNECTED") and $polycomObjects{$self1->{PHONEIP}} eq "CONNECTED") {
                                $logger->debug(__PACKAGE__ . ".$subName: CONFERENCE CALL success. All the 3 phones are in a conference call now");
                                $logger->debug(__PACKAGE__ . ".$subName: . Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                return 1;   
                        } elsif ($failures == 8 ) {
                                $logger->error(__PACKAGE__ . ".$subName: Failed to make a conference call on $self->{PHONEIP} to $self2->{PHONEIP} after pressing 'Conference' key on $self->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' '$self2->{PHONEIP}' : '$polycomObjects{$self2->{PHONEIP}}' ");
                                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                        if ($makenewcall eq "YES") {
                                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self1->{PHONEIP} ");
                                #$self1->reboot();
                        }
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401) {
                                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                        }
                        return 0;
                }
        }
}

sub addConferenceCall{

        my ($self) = shift;
        my ($self1) = shift;
    my ($self2) = shift;
        my $subName = "addConferenceCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        unless ($self->conferenceCall($self1, $self2, -existingcall => 0)) {
                $logger->debug(__PACKAGE__ . ".$subName: Adding a new call to conference  failed.");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
}

sub reboot{

        my ($self) = shift;
        my (%args) = @_;
        my ($pass);
        my ($failures) = 1;
        my ($regeventcount) = 0;
        my $count = 1;
        my ($content,$response,$out,$spipxFileName,@numbers,$filename);
        my $subName = "reboot";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        $logger->debug(__PACKAGE__ . ".$subName: Attempting to do a reboot on $self->{PHONEIP} ");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");

        if ($args{-lineregistrationcount}) {
            $count = $args{-lineregistrationcount};
        }
        $logger->debug(__PACKAGE__ . ".$subName: Registration count to check: $count");

        unless ($self->authenticate()) {
                $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
        }
        $spipxFileName = "REBOOT_".$self->{NUMBER}.".spipx";
        $pass = $self->{SPIPPASSWORD};
        @numbers = split("",$pass);
        $out = "Key:Menu\n";
        if ($args{-vvx}) {
            unless ($self->rebootVvxPhone(%args)) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to reboot the phone.....");
                return 0;
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Successfuly rebooted the phone.....");
                return 1;
            }           
       } else {  
        $out .= "Key:DialPad3\n";
        $out .= "Key:DialPad2\n";
        foreach my $digit (@numbers) {
                $out .= "Key:DialPad$digit\n";
        }
        $out .= "Key:SoftKey1\n";
        $out .= "Key:DialPad3\n";
        $out .= "Key:SoftKey4\n";
       }
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $polycomObjectsData{$self->{PHONEIP}} = undef;
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Failed while trying to reboot $self->{PHONEIP}");
                return 0;
        }
        while ($failures <= 180 ) {
                $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 3 seconds.. Attempt ---> $failures");
                sleep 2;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if ($polycomObjectsData{$self->{PHONEIP}} eq "LINE_REGISTRATION") {
                                $regeventcount++;
                                $logger->debug(__PACKAGE__ . ".$subName: Line registration event count : $regeventcount "); 
                                if ( $regeventcount != $count and ( defined $args{-lineregistrationcount} and $args{-lineregistrationcount} == $count) ) {
                                    $polycomObjectsData{$self->{PHONEIP}} = undef;
                    $logger->debug(__PACKAGE__ . ".$subName: Checking for 2 line registration events. Count : $regeventcount ");
                                    next;
                                }
                                $self->{STATE} = "ON_HOOK";
                                $polycomObjects{$self->{PHONEIP}} = "ON_HOOK";
                                $logger->debug(__PACKAGE__ . ".$subName: PHONE REBOOT success ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
                                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                                $polycomObjectsData{$self->{PHONEIP}} = undef;
                                sleep (20) if ($args{-vvx});
                                return 1;
                        } elsif ($failures == 180 ) {
                                $logger->error(__PACKAGE__ . ".$subName: The phone with IP $self->{PHONEIP} has not sent a line registration event.");
                                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 150 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                                $polycomObjectsData{$self->{PHONEIP}} = undef;
                                return 0;
                        } else {
                                $failures++;
                        }
                 } else {
                        if (${$response}{_rc} == 401) {
                                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                        }
                        $polycomObjectsData{$self->{PHONEIP}} = undef;
                        return 0;
                }
        }
}

sub createSpipxFile{

    my $self                  = shift;
    my ($spipxFileName, $out) = @_;
    my $subName               = "createSpipxFile";
    my $logger                = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    # Create spipx file
    my $filename = "$spipxPath/$spipxFileName";
    open(my $fh, '>', $filename) or return 0;
    print $fh $out;
    close $fh;

    $logger->debug(__PACKAGE__ . ".$subName: Successfully created spipx file : $filename");
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return $spipxFileName;
}

sub handleResponse {
    my %args       = @_;
    $client_socket = shift;
    my $subName    = "handleResponse";
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    
    # Get the host and port number of newly connected client.
    $peer_address = $client_socket->peerhost();
    $peer_port    = $client_socket->peerport();
    $logger->debug(__PACKAGE__ . ".$subName: Accepted New Client Connection From : $peer_address, $peer_port");

    # Read the received data and put it to an array
    $data = undef;
    $client_socket->recv($data,2048);

    my @arr = split( /\n/, $data);
    for (my $i=0;$i<7;$i++) {
        shift @arr;
    }

    #$logger->debug("**********************************************Received from Client ****************************************");
    #$logger->debug(__PACKAGE__ . ".$subName: Received from Client : $data");
    #$logger->debug("***********************************************************************************************************");
    
    # Check the notifications comming from phones
    foreach my $line (@arr) {
        if ($line =~ /OutgoingCallEvent>/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'OutgoingCallEvent' from $peer_address");
            $polycomObjects{$peer_address} = "OUTGOING";
            last;
        }

        if ($line =~ /IncomingCallEvent>/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'IncomingCallEvent' from $peer_address");
            $polycomObjects{$peer_address} = "INCOMING";
            last;
        }

        if ($line =~ /OffHookEvent>/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'OffHookEvent' from $peer_address");
            $polycomObjects{$peer_address} = "OFF_HOOK";
            last;
        }

        if ($line =~ /LineRegistrationEvent>/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'LineRegistrationEvent' from $peer_address");
            $polycomObjectsData{$peer_address} = "LINE_REGISTRATION";
            last;
        }

        if ($line =~ /CallState\=\"Connected\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'Connected' from $peer_address");
            $polycomObjects{$peer_address} = "CONNECTED";
            last;
        }

        if ($line =~ /CallState\=\"CallHeld\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'CallHeld' from $peer_address");
            $polycomObjects{$peer_address} = "CALLHELD";
            last;
        }

        if ($line =~ /CallState\=\"CallHold\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'CallHeld' from $peer_address");
            $polycomObjects{$peer_address} = "CALLHOLD";
            last;
        }

        if ($line =~ /OnHookEvent>/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'OnHookEvent' from $peer_address");
            $polycomObjects{$peer_address} = "ON_HOOK";
            last;
        }

        if ($line =~ /CallState\=\"Disconnected\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'Disconnected' from $peer_address");
            $polycomObjects{$peer_address} = "ON_HOOK";
            last;
        }

        if ($line =~ /CallState\=\"RingBack\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'RingBack' from $peer_address");
            $polycomObjects{$peer_address} = "RINGBACK";
            last;
        }

        if ($line =~ /CallState\=\"Ringing\">/) {
            $logger->debug(__PACKAGE__ . ".$subName: Got 'Ringing' from $peer_address");
            $polycomObjects{$peer_address} = "RINGING";
            last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$subName:  Closing the client socket after handling the response");    
    $client_socket->close();
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;

}

sub resetPhone{

    my ($self) = shift;
    my (%args) = @_;
    my ($phoneNum);
    my ($failures) = 1;
    my ($content,$response,$out,$spipxFileName,$filename);
    my $subName = "resetPhone";    
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $phoneNum = $self->{NUMBER};
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "RESET_$phoneNum" . ".spipx";
    $out = "Key:SoftKey2\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to reset phone : $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
    return 1;
}


sub enterKeys{

        my ($self) = shift;
        my (%args) = @_;
        my ($phoneNum, $key);
        my ($failures) = 1;
        my ($content,$response,$out,$spipxFileName,$filename,@numbers);
        my $subName = "enterKeys";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        unless ( defined $args{-keys} ) {
            $logger->error(__PACKAGE__ . ".$subName: Mandatory argument -keys is missing ");
            return 0;
        }
        if ($args{-keys} =~ /^[a-zA-Z]/) {
            @numbers = ($args{-keys});
        } else {
            @numbers = split("",$args{-keys});
        }
        $logger->debug(__PACKAGE__ . ".$subName: You have entered the numbers --->@numbers");
        foreach my $digit (@numbers) {
        $logger->debug(__PACKAGE__ . ".$subName: sending a key ---> $digit");
        unless ($self->authenticate()) {
                $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
        }
        $spipxFileName = "enterKeys.spipx";
        if ($digit =~ /^\*/) { 
            $key = "Key:DialpadStar";
        } elsif ($digit =~ /^\#/) { 
            $key = "Key:DialpadPound";
        } elsif ($digit =~ /^[0-9]/) {
            $key = "Key:Dialpad$digit";
        } elsif ($digit =~ /^[a-zA-Z]/) {
            $key = "Key:$digit";
        } else {
            $logger->error(__PACKAGE__ . ".$subName: Invalid key");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Sending a command ---> $key");
        $out .= "$key\n";
        }
        $logger->debug(__PACKAGE__ . ".$subName: Keys: $out");
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to enter key \'$key\' on $self->{PHONEIP}");
                return 0;
        }
        sleep 2;
        $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
        if ($response->is_success and ${$response}{_rc} == 200) {
                $logger->debug(__PACKAGE__ . ".$subName: Entering key \'$key\' success ");
        } else {
               if (${$response}{_rc} == 401) {
                       $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                       return 0;
               } else {
                       $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                       $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                       return 0;
               }
        }
        #--- End
        $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
        return 1;
}

sub makeVoiceMailCall {

        my ($self) = shift;
        my ($self1) = shift;
        my (%args) = @_;
        my ($phoneNum, $endCmd);
        my ($failures) = 1;
        my ($content,$response,$out,$spipxFileName,@numbers,$filename);
        my $subName = "makeVoiceMailCall";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
        $phoneNum = $self1->{NUMBER};
        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        $logger->error(__PACKAGE__ . ".$subName: Attempting a call from $self->{PHONEIP} to $self1->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
        unless ($self->authenticate()) {
                $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
        }
        if ($phoneNum =~ /^[0-9]+/) {
            $spipxFileName = "DIAL_$phoneNum" . ".spipx";
            $out = "Key:SoftKey1\n";
            $endCmd = "Key:SoftKey1"; 
        } elsif ($phoneNum =~ /^\*([0-9]{1,})/) {
            $spipxFileName = "DIAL_$1" . ".spipx";
            $out = "Key:DialPadStar\n";
            $phoneNum = $1;
            $endCmd = "Key:SoftKey2"; 
        } else {
            $logger->error(__PACKAGE__ . ".$subName: Invalid phone number. Please check the number you have dialed");
            return 0
        }

        @numbers = split("",$phoneNum);
        foreach my $digit (@numbers) {
                $out .= "Key:DialPad$digit\n";
        }
        $out .= "$endCmd";
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to make a call to $self1->{PHONEIP}");
                return 0;
        }
        while ($failures <= 90 ) {
                $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
                sleep 1;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if ($polycomObjects{$self->{PHONEIP}} eq "CONNECTED") {
                                $logger->debug(__PACKAGE__ . ".$subName: MAKE CALL success : $phoneNum is ringing");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                                return 1;
                        } elsif ($failures == 90 ) {
                                $logger->error(__PACKAGE__ . ".$subName: Failed to make a call to $self1->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self1->{PHONEIP} in 10 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                                #$self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401) {
                                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} $self1->{PHONEIP} : '$polycomObjects{$self1->{PHONEIP}}' ");
                        }
                        return 0;
                }
        }
                                  
}

sub disconnectVoiceMail{

        my $self = shift;
        my ($content,$response,$out,$spipxFileName,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my $subName = "disconnectVoiceMail";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        if ( $polycomObjects{$self->{PHONEIP}} eq "ON_HOOK" or $polycomObjects{$self->{PHONEIP}} eq "DISCONNECTED" ) {
                $logger->error(__PACKAGE__ . ".$subName: Failed to disconnect the call on $self->{PHONEIP} The call is not in the connected state. Check the phone state below..");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}  ");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [0]");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Attempting to disconnect call on $self->{PHONEIP} ");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
        unless ($self->authenticate()) {
                $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
        }
        $spipxFileName = "DISCONNECT_$self->{PHONEIP}" . ".spipx";
        $out = "Key:SoftKey2\n";
        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Failure while disconnecting the call");
                return 0;
        }
        while ($failures <= 2 ) {
                $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 5 seconds.. Attempt ---> $failures");
                sleep 5;
                if ($response->is_success and ${$response}{_rc} == 200) {
                        if ( $polycomObjects{$self->{PHONEIP}} eq "ON_HOOK" or $polycomObjects{$self->{PHONEIP}} eq "DISCONNECTED" ) {
                                $logger->debug(__PACKAGE__ . ".$subName: DISCONNECT CALL success ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                                return 1;
                        } elsif ($failures == 2 ) {
                                $logger->error(__PACKAGE__ . ".$subName: Failed to disconnect the call on $self->{PHONEIP}");
                                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 40 seconds.. ");
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Rebooting $self->{PHONEIP} ");
                                $self->reboot();
                                return 0;
                        } else {
                                $failures++;
                        }
                } else {
                        if (${$response}{_rc} == 401) {
                                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
                        } else {
                                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}  ");
                        }
                        return 0;
                }
        }
}

sub doNotDisturb{
        my $self = shift;
        my ($content,$response,$out,$spipxFileName,$filename);
        my ($failures) = 1;
        my (%args) = @_;
        my $subName = "doNotDisturb";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
        unless ($polycomObjects{$self->{PHONEIP}} eq "ON_HOOK" or $polycomObjects{$self->{PHONEIP}} eq "DISCONNECTED") {
                $logger->error(__PACKAGE__ . ".$subName: Failed to change state of 'Do Not Disturb' on $self->{PHONEIP} The phone is not in the 'DISCONNECTED'/'ON_HOOK' state.");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$subName: Attempting to change 'Do Not Disturb' state on $self->{PHONEIP} ");
        $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
        unless ($self->authenticate()) {
                $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
        }
        $spipxFileName = "DND_$self->{PHONEIP}" . ".spipx";
        if ($args{-vvx}) {
            $logger->debug(__PACKAGE__ . ".$subName: Its a VVX phone");
            $out .= "Key:DoNotDisturb\n";
        } else { 
            $out = "Key:Menu\n";
            $out .= "Key:DialPad1\n";
            $out .= "Key:DialPad1\n";
            $out .= "Key:SoftKey3\n";
            $out .= "Key:SoftKey3\n";
        }

        unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
                $logger->error(__PACKAGE__ . ".$subName:  Failed to create spipx file : $spipxFileName");
                return 0;
        }
        $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
                $logger->error(__PACKAGE__ . ".$subName: Encountered failure while attempting to change 'Do Not Disturb' state on : $self->{PHONEIP}");
                return 0;
        }
        if (${$response}{_rc} == 401) {
            $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
        return 0;
        } else {
                $logger->debug(__PACKAGE__ . ".$subName: Successfully change the 'Do Not Disturb' state on $self->{PHONEIP}. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
        return 1;
        }
}

=head2 C< rebootVvxPhone >

DESCRIPTION:
    
    This API is used to reboot Polycom VVX phones only (video phones)

ARGUMENTS:

    -lineregistrationcount (optional, default it will be 1)
 
PACKAGE:

    SonusQA::POLYCOM

OUTPUT:
 
    0 - Fail 
    1 - Success

EXAMPLE:
    unless ($phoneObj->rebootVvxPhone(-lineregistrationcount => '1')) {
      $logger->error(__PACKAGE__ . "::$subName:[FAILURE] Failed to reboot the phone");
    }
    
=cut

sub rebootVvxPhone{
    my ($self) = shift;
    my (%args) = @_;
    my $pass;
    my ($failures, $regeventcount, $count) = (1, 0, 1);
    my ($content, $response, $out, $spipxFileName, @numbers, $filename);
    my $subName = "rebootVvxPhone";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    $logger->debug(__PACKAGE__ . ".$subName: Rebooting the phone: $self->{PHONEIP} ");

    if ($args{-lineregistrationcount}) {
        $count = $args{-lineregistrationcount};
    }
    $logger->debug(__PACKAGE__ . ".$subName: Registration count to check: $count");

    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "REBOOT_".$self->{NUMBER}.".spipx";
    $pass = $self->{SPIPPASSWORD};
    @numbers = split("",$pass);

    # -------- Press 'Menu' button --------
    $out = "Key:Menu\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $polycomObjectsData{$self->{PHONEIP}} = undef;
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to rebootVvxPhone $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Pressing the 'Menu' button is successful");
    sleep (3);   
    
    # -------- Select 'Setting' option --------
    $out  = "";
    $out .= "Key:ArrowRight\n";
    $out .= "Key:ArrowRight\n";
    $out .= "Key:Select\n";

    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $polycomObjectsData{$self->{PHONEIP}} = undef;
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to rebootVvxPhone $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Selected the settings.....");
    sleep (3);

    # -------- Select 'Advanced' option --------
    $out  = "";
    $out .= "Key:ArrowDown\n";
    $out .= "Key:Select\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    #$polycomObjectsData{$self->{PHONEIP}} = undef;
    $polycomObjectsData{$self->{PHONEIP}} = "";
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to rebootVvxPhone $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Selected the admin settings.....");
    sleep (3);

    # -------- Eneter password --------
    $out  = "";
    foreach my $digit (@numbers) {
        $out .= "Key:DialPad$digit\n";
    }
    $out .= "Key:Select\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $polycomObjectsData{$self->{PHONEIP}} = undef;
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to rebootVvxPhone $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Entered the password.....");
    sleep (3);

    # -------- Select 'Reboot Phone' and then press 'Yes' --------
    $out  = "";
    $out .= "Key:DialPad3\n";
    $out .= "Key:SoftKey4\n";
    unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    $polycomObjectsData{$self->{PHONEIP}} = undef;
    $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to rebootVvxPhone $self->{PHONEIP}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subName: Rebooting the phone.....");
    sleep (3);

    $logger->error(__PACKAGE__ . ".$subName: Waiting for a response from phone ...........");

    while ($failures <= 90 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ----> $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjectsData{$self->{PHONEIP}} eq "LINE_REGISTRATION") {
                $regeventcount++;
                $logger->debug(__PACKAGE__ . ".$subName: Line registration event count : $regeventcount "); 
                if ( $regeventcount != $count and ( defined $args{-lineregistrationcount} and $args{-lineregistrationcount} == $count) ) {
                    $polycomObjectsData{$self->{PHONEIP}} = undef;
                    $logger->debug(__PACKAGE__ . ".$subName: Checking for 2 line registration events. Count : $regeventcount ");
                    next;
                }
                $self->{STATE} = "ON_HOOK";
                $polycomObjects{$self->{PHONEIP}} = "ON_HOOK";
                $logger->debug(__PACKAGE__ . ".$subName: PHONE REBOOT success ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                $polycomObjectsData{$self->{PHONEIP}} = undef;
                sleep (20);
                return 1;
            } elsif ($failures == 90 ) {
                $logger->error(__PACKAGE__ . ".$subName: The phone with IP $self->{PHONEIP} has not sent a line registration event.");
                $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 150 seconds.. ");
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                $polycomObjectsData{$self->{PHONEIP}} = undef;
                return 0;
            } else {
                $failures++;
            }
         } else {
            if (${$response}{_rc} == 401) {
                $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
            }
            $polycomObjectsData{$self->{PHONEIP}} = undef;
            return 0;
        }
    }
}


=head2 C< bringPhoneToNormalState >

DESCRIPTION:
    
    This API is used to bring phone to noraml state (is case of test cases filure)

ARGUMENTS:

    Phone Objet's
 
PACKAGE:

    SonusQA::POLYCOM

OUTPUT:
 
    0 - Fail 
    1 - Success

EXAMPLE:
    unless ($phoneA1Obj->bringPhoneToNormalState($phoneA2Obj)) {
      $logger->error(__PACKAGE__ . "::$subName:[FAILURE] Failed to bring phone to normal state");
    }
    
=cut

sub bringPhoneToNormalState{
    my $self          = shift;
    my (@phoneObects) = @_;    
    my $subName       = "bringPhoneToNormalState";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    # Check the phone state of each phone
    my ($obj, $actionButtons);
    my $result = 1;
    foreach $obj ($self, @phoneObects) {
        $actionButtons = "";
        $logger->debug(__PACKAGE__ . ".$subName: Checking the phone state of \"$obj->{PHONEIP}\"");
        if ($polycomObjects{$obj->{PHONEIP}} eq "ON_HOOK" or $polycomObjects{$obj->{PHONEIP}} eq "DISCONNECTED") {
            $logger->debug(__PACKAGE__ . ".$subName: Phone \"$obj->{PHONEIP}\" is in normal state");
            next;
        }

        if ($polycomObjects{$obj->{PHONEIP}} eq "CONNECTED" or $polycomObjects{$obj->{PHONEIP}} eq "OUTGOING" or $polycomObjects{$obj->{PHONEIP}} eq "OFF_HOOK" or $polycomObjects{$obj->{PHONEIP}} eq "CALLHELD") {
            $logger->debug(__PACKAGE__ . ".$subName: Current phone state of \"$obj->{PHONEIP}\" : $polycomObjects{$obj->{PHONEIP}}");
            $actionButtons = "Key:SoftKey2\n";
            unless ($obj->performAction(-keys => "$actionButtons")) {
                $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Failed to bring phone \"$obj->{PHONEIP}\" to normal state");
                $result = 0;
            }
            $logger->debug(__PACKAGE__ . ".$subName: [SUCCESS] Brought phone \"$obj->{PHONEIP}\" to normal state");
            next;
        }

        if ($polycomObjects{$obj->{PHONEIP}} eq "CALLHOLD") {
            $logger->debug(__PACKAGE__ . ".$subName: Current phone state of \"$obj->{PHONEIP}\" : $polycomObjects{$obj->{PHONEIP}}");
            $actionButtons = "Key:Hold\n";
            $actionButtons .= "Key:SoftKey2\n";
            unless ($obj->performAction(-keys => "$actionButtons")) {
                $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Failed to bring phone \"$obj->{PHONEIP}\" to normal state");
                $result = 0;
            }
            $logger->debug(__PACKAGE__ . ".$subName: [SUCCESS] Brought phone \"$obj->{PHONEIP}\" to normal state");
            next;
        }
    }

    $logger->debug(__PACKAGE__ . ".$subName: Now bringing the phone to home screen if its in different screen");
    $actionButtons  = "";
    $actionButtons .= "Key:Handsfree\n";
    foreach $obj ($self, @phoneObects) {
        unless ($obj->bringToHomeScreen(-keys => "$actionButtons")) {
            $logger->debug(__PACKAGE__ . ".$subName: [FAILURE] Failed to bring phone \"$obj->{PHONEIP}\" to home screen");
            $result = 0;
        }
    }

    $logger->debug(__PACKAGE__ . "::$subName: --> Leaving sub [$result]");

    return $result;
}



=head2 C< performAction >

DESCRIPTION:
    
    This API is used to send commands to phone

ARGUMENTS:

    Phone Objet's
 
PACKAGE:

    SonusQA::POLYCOM

OUTPUT:
 
    0 - Fail 
    1 - Success

EXAMPLE:
    unless ($phoneA1Obj->performAction(-keys => "$actionButtons")) {
      $logger->error(__PACKAGE__ . "::$subName:[FAILURE] Failed to send commands to phone");
    }
    
=cut

sub performAction{
    my $self    = shift;
    my %args    = @_;    
    my $subName = "performAction";
    my $result  = '1';
    my %a;

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    # Authenticate with phone
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }

    # Create SPIPX file
    my ($fileName, $spipxFileName, $content, $response);
    $spipxFileName = "NORMAL_STATE" . '.spipx';

    unless ($fileName = $self->createSpipxFile($spipxFileName, $a{-keys})) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    
    $polycomObjectsData{$self->{PHONEIP}} = undef;
    $content = "<PolycomIPPhone><URL priority=\"critical\">$fileName</URL></PolycomIPPhone>";
    unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while sending commands to phone \"$self->{PHONEIP}\"");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subName: Waiting response from phone.....");
    my $failures = 0;
    while ($failures <= 5 ) {
        $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
        sleep 3;
        if ($response->is_success and ${$response}{_rc} == 200) {
            if ($polycomObjects{$self->{PHONEIP}} eq "ON_HOOK" or $polycomObjects{$self->{PHONEIP}} eq "DISCONNECTED") {
                $logger->debug(__PACKAGE__ . ".$subName: Successfuly performed required action on phone");
                $logger->debug(__PACKAGE__ . "::$subName: --> Leaving sub [1]");
                return 1;
            }
        } elsif ($failures == 5) {
            $logger->debug(__PACKAGE__ . ".$subName: Failed to perform required action on phone");
            $logger->debug(__PACKAGE__ . "::$subName: --> Leaving sub [0]");
            return 0;
        }
        ++$failures;
    }
}


=head2 C< bringToHomeScreen >

DESCRIPTION:
    
    This API is used to bring the phone to home screen

ARGUMENTS:

    Phone Objet's
 
PACKAGE:

    SonusQA::POLYCOM

OUTPUT:
 
    0 - Fail 
    1 - Success

EXAMPLE:
    unless ($phoneA1Obj->bringToHomeScreen(-keys => "$actionButtons")) {
      $logger->error(__PACKAGE__ . "::$subName:[FAILURE] Failed to send commands to phone");
    }
    
=cut

sub bringToHomeScreen{
    my $self    = shift;
    my %args    = @_;    
    my $subName = "bringToHomeScreen";
    my %a       = (-bringToHomeScreen => 0);

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");

    # Authenticate with phone
    unless ($self->authenticate()) {
        $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }

    # Create SPIPX file
    my ($fileName, $spipxFileName, $content, $response);
    $spipxFileName = "NORMAL_STATE" . '.spipx';

    unless ($fileName = $self->createSpipxFile($spipxFileName, $a{-keys})) {
        $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
        return 0;
    }
    
    my $result = 0;
    for (my $i = 0; $i < 3; ++$i) {
        $logger->debug(__PACKAGE__ . ".$subName: Count ---> $i");
        $polycomObjectsData{$self->{PHONEIP}} = undef;
        $content = "<PolycomIPPhone><URL priority=\"critical\">$fileName</URL></PolycomIPPhone>";
        unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
            $logger->error(__PACKAGE__ . ".$subName: Failed while sending commands to phone \"$self->{PHONEIP}\"");
            return 0;
        }

        sleep (4);

        $logger->debug(__PACKAGE__ . ".$subName: Waiting response from phone.....");
        my $failures = 0;
        while ($failures <= 2 ) {
            $logger->error(__PACKAGE__ . ".$subName: Attempt ---> $failures");
            sleep (4);
            if ($response->is_success and ${$response}{_rc} == 200) {
                if ($polycomObjects{$self->{PHONEIP}} eq "OUTGOING" or $polycomObjects{$self->{PHONEIP}} eq "OFF_HOOK") {
                    $logger->debug(__PACKAGE__ . ".$subName: Its in \'OFF_HOOK\' state now");
                    last;
                } elsif ($polycomObjects{$self->{PHONEIP}} eq "DISCONNECTED" or $polycomObjects{$self->{PHONEIP}} eq "ON_HOOK") {
                    $logger->debug(__PACKAGE__ . ".$subName: Its in \'OFF_HOOK\' state now");
                    $result = 1;
                    last;
                }
            }
            ++$failures;
        } 

        if ($result) {
            $logger->debug(__PACKAGE__ . ".$subName: Successfuly brought a phone to home screen");
            last;
        }
            
    } # End of for

    $logger->debug(__PACKAGE__ . "::$subName: --> Leaving sub [$result]");
    return $result;
}


sub updateConfiguration{

    my ($self) = shift;
    my (%args) = @_;
    my ($pass);
    my ($failures) = 1;
    my ($regeventcount) = 0;
    my $count = 1;
    my ($content,$response,$out,$spipxFileName,@numbers,$filename);
    my $subName = "updateConfiguration";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Entered Sub");
    $logger->debug(__PACKAGE__ . ".$subName: Attempting to do a update the config on $self->{PHONEIP} ");
    $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");

    if ($args{-lineregistrationcount}) {
        $count = $args{-lineregistrationcount};
    }
    $logger->debug(__PACKAGE__ . ".$subName: Registration count to check: $count");

    unless ($self->authenticate()) {
            $logger->error(__PACKAGE__ . ".$subName: Failure in authentication");
    }
    $spipxFileName = "UPDATE_CONFIGURATION_".$self->{NUMBER}.".spipx";
    $out = "Key:Menu\n";
    if ($args{-vvx}) {
       $out .= "Key:DialPad3\n";
       $out .= "Key:DialPad1\n";
       $out .= "Key:DialpadPound\n";
       $out .= "Key:DialpadPound\n";
       $out .= "Key:ArrowDown\n";
       $out .= "Key:Select\n";
       $out .= "Key:SoftKey4\n";
        
   } else {
       $out .= "Key:DialPad3\n";
       $out .= "Key:DialPad1\n";
       $out .= "Key:DialPad7\n";
       $out .= "Key:SoftKey4\n";
   }

   unless ($filename = $self->createSpipxFile($spipxFileName,$out)) {
      $logger->error(__PACKAGE__ . ".$subName: Failed to create spipx file : $spipxFileName");
      return 0;
   }
   
   $polycomObjectsData{$self->{PHONEIP}} = undef;
   $content = "<PolycomIPPhone><URL priority=\"critical\">$filename</URL></PolycomIPPhone>";
   unless ($response = $self->{LWP}->post("http://$self->{PHONEIP}/push", Content => $content, 'Content-Type' => 'application/x-com-polycom-spipx')) {
        $logger->error(__PACKAGE__ . ".$subName: Failed while trying to update the config $self->{PHONEIP}");
        return 0;
   }

   while ($failures <= 30 ) {
       $logger->error(__PACKAGE__ . ".$subName: Waiting for a response.. Sleeping for 3 seconds.. Attempt ---> $failures");
       sleep 2;
       if ($response->is_success and ${$response}{_rc} == 200) {
           if ($polycomObjectsData{$self->{PHONEIP}} eq "LINE_REGISTRATION") {
                   $regeventcount++;
                   $logger->debug(__PACKAGE__ . ".$subName: Line registration event count : $regeventcount ");
                   if ( $regeventcount != $count and ( defined $args{-lineregistrationcount} and $args{-lineregistrationcount} == $count) ) {
                       $polycomObjectsData{$self->{PHONEIP}} = undef;
                       $logger->debug(__PACKAGE__ . ".$subName: Checking for 2 line registration events. Count : $regeventcount ");
                       next;
                   }
                   $self->{STATE} = "ON_HOOK";
                   $polycomObjects{$self->{PHONEIP}} = "ON_HOOK";
                   $logger->debug(__PACKAGE__ . ".$subName: PHONE REBOOT success ");
                   $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}}");
                   $logger->debug(__PACKAGE__ . ".$subName: --> Leaving sub [1]");
                   $polycomObjectsData{$self->{PHONEIP}} = undef;
                   sleep (20) if ($args{-vvx});
                   return 1;
           } elsif ($failures == 30 ) {
                   $logger->error(__PACKAGE__ . ".$subName: The phone with IP $self->{PHONEIP} has not sent a line registration event.");
                   $logger->error(__PACKAGE__ . ".$subName: Did not get the expected response from $self->{PHONEIP} in 150 seconds.. ");
                   $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
                   $logger->error(__PACKAGE__ . ".$subName: Got the response: ".Dumper($response));
                   $polycomObjectsData{$self->{PHONEIP}} = undef;
                   return 0;
           } else {
                   $failures++;
           }
    } else {
           if (${$response}{_rc} == 401) {
                   $logger->error(__PACKAGE__ . ".$subName: Authorization failed. Check your PUSH and SPIP credentials on the TMS.".Dumper($response));
           } else {
                   $logger->error(__PACKAGE__ . ".$subName: Did not get a successful response. ".Dumper($response));
                   $logger->debug(__PACKAGE__ . ".$subName: Phone Status- $self->{PHONEIP} : $polycomObjects{$self->{PHONEIP}} ");
           }
           $polycomObjectsData{$self->{PHONEIP}} = undef;
           return 0;
            }
    }
}

sub DESTROY{

    my ($self)=@_;
    my ($logger);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    while ( my $key = each %polycomObjects ) {
        if ($key eq $self->{PHONEIP}) { 
            $logger->debug(__PACKAGE__ . ".DESTROY Deleting $key from the polycom objects hash.");
            delete $polycomObjects{$key};
        }
    }
    $logger->debug(__PACKAGE__ . ".DESTROY polycomObjects after destroying [$self->{OBJ_HOST}] ".Dumper(%polycomObjects));
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
    sleep 5;
}

1;
