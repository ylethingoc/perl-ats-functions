package SonusQA::YEALINK;

=head1 NAME

SonusQA::YEALINK - Perl module for YEALINK application control.

=head1 AUTHOR

=head1 IMPORTANT

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION

This module provides an interface for the YEALINK test tool.
Control of command input is up to the QA Engineer implementing this class
allowing the engineer to specific which attributes to use.

=head1 METHODS

=cut

use strict;
use warnings;

use LWP::UserAgent;
use SonusQA::Utils;
use IO::Socket::INET;
use XML::Simple;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use threads;
use threads::shared;
use SonusQA::YEALINK::HTTPSERVER;
use vars qw( %yealinkObjects); 
require Exporter;
our @ISA = qw(Exporter);
our ($spipx_path);
our ($socket,$client_socket);
our ($peer_address,$peer_port,$data): shared;
our ($HTTP_SERVER_IP_TEMP,$HTTP_SERVER_PORT_TEMP);
our @EXPORT =  qw( handleResponse  $socket $client_socket );


=head2 SonusQA::YEALINK::new()

  To create the Yealink object

=over

=item Arguments

  args <hash>

=item Returns

  1 - Object is created
  0 - Object creation fails

=back

=cut

sub new {
    my ( $class,  %args) = @_; 
    my %tms_alias        = ();
    my $sub_name         = "new";
    my $logger           = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");    
    my $alias            = $args{-tms_alias_name};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $tms_alias = &SonusQA::Utils::resolve_alias($alias);
    my $self = {
        PHONEIP          => $tms_alias->{NODE}{1}{IP},
        USER_ID          => $tms_alias->{LOGIN}{1}{USERID},
        PASSWD           => $tms_alias->{LOGIN}{1}{PASSWD},
        HTTP_SERVER_IP   => $tms_alias->{HTTPSERVER}{1}{IP},
        HTTP_SERVER_PORT => $tms_alias->{HTTPSERVER}{1}{PORT},
        NUMBER           => $tms_alias->{NODE}{1}{NUMBER},
        LWP              =>  LWP::UserAgent->new()
    };

    bless $self, $class;
    $logger->debug(__PACKAGE__ . ".$sub_name:Passing the arguments in doINIT ".Dumper(\%args)); 
    unless($self->doInitialization(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed in Initialization");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $self;
}

=head2 SonusQA::YEALINK::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub doInitialization {
    my($self, %args) = @_;
    my $sub_name     = "doInitialization";
    my $phone_type   = "YEALINK";
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ( exists $ENV{LOG_LEVEL} ) {
        $self->{LOG_LEVEL} = uc $ENV{LOG_LEVEL};
    } else {
        $self->{LOG_LEVEL} = 'DEBUG';
    }
    
    $yealinkObjects{$self->{PHONEIP}} = "ON_HOOK";
    $self->{OBJ_HOST}                 = $self->{PHONEIP};
    $HTTP_SERVER_IP_TEMP              = $self->{HTTP_SERVER_IP};
    $HTTP_SERVER_PORT_TEMP            = $self->{HTTP_SERVER_PORT}; 

    my $httpserverinstance;
    $logger->debug(__PACKAGE__ . ".$sub_name: HttpIP:[$HTTP_SERVER_IP_TEMP] and HttpPort[$HTTP_SERVER_PORT_TEMP]");
    $logger->debug(__PACKAGE__ . ".$sub_name: HttpIP:[$HTTP_SERVER_IP_TEMP] and HttpPort[$HTTP_SERVER_PORT_TEMP] and \$phone_type $phone_type "); #sh
    $logger->debug(__PACKAGE__ . ".$sub_name: yealinkObjects : ". Dumper(\%yealinkObjects));
    unless($httpserverinstance = &SonusQA::YEALINK::HTTPSERVER::getHttpServerInstance($HTTP_SERVER_IP_TEMP,$HTTP_SERVER_PORT_TEMP,$phone_type)){
        $logger->debug(__PACKAGE__ . ".$sub_name: Failure in getting the HTTP server instance.. '$httpserverinstance' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: httpserverinstance status: '$httpserverinstance' ");
    $logger->debug(__PACKAGE__ . ".$sub_name: yealinkObjects : ". Dumper(\%yealinkObjects));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 SonusQA::YEALINK::makeCall()

  This function is used to make a out-going call

=over

=item ARGUMENTS

  Mandatory Args:
  Called party phone object

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

  unless ($phoneA1Obj->makeCall($phoneA2Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: makeCall failed");
        return 0;
  }

=back

=cut

sub makeCall {
    my ($self)   = shift;
    my ($self1)  = shift;
    my (%args)   = @_;
    my $failures = 1;
    my $sub_name = "makeCall";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($phone_no,%a,$url,$response);
    $phone_no    = $self1->{NUMBER};  
    my $callPickupFlag = 0;
    my $callForward  = 0;

    if (defined $args{-callPickup}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: call pickup flag is set");
        $callPickupFlag = $args{-callPickup};
    }
    
    if (defined $args{-callForward}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: call forward flag is set");
        $callForward = $args{-callForward};
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Number To Dial ----> $phone_no");
        
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }    
    $logger->error(__PACKAGE__ . ".$sub_name: Attempting a call from $self->{PHONEIP} to $self1->{PHONEIP}"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: Calling phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");

    #Frame URL to make a call
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?number=<DestinationNum>&outgoing_uri=<Account>
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?number=$phone_no&outgoing_uri=Account1";
    
    # Below URLs will be used in case of failure
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

   $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for make a call");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 10 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Got success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state");
            $logger->debug(__PACKAGE__ . ".$sub_name: dumper: ". Dumper(\%yealinkObjects));
            if(($yealinkObjects{$self->{PHONEIP}} eq "outgoingCall" or $callPickupFlag) and ($yealinkObjects{$self1->{PHONEIP}} eq "incomingCall" or $callForward)) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Make a call is success : $phone_no is ringing");
                $logger->debug(__PACKAGE__ . ".$sub_name: Calling phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 10) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to make a call to $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from $self1->{PHONEIP}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Calling phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
                $self->{LWP}->post($endCallURL1);
                $self1->{LWP}->post($endCallURL2);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else { 
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));                
            }
            $self->{LWP}->post($endCallURL1);
            $self1->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::answerCall()

  This function is used to answer the incomming call

=over

=item ARGUMENTS

  Mandatory Args:
  Calling party phone object

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

  unless ($phoneA2Obj->answerCall($phoneA1Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to answer the call");
        return 0;
  }

=back

=cut

sub answerCall {
    my $self       = shift;
    my $self1      = shift;
    my (%args)     = @_;
    my $sub_name   = "answerCall";  
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($failures) = 1;
    my (@states)   = ("incomingCall", "outgoingCall");
    my $sleep_time = $args{-sleeptime}; 
    my ($url, $response);
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial phone status......"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: Calling phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");

    # Below URLs will be used in case of failure
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    unless( ($yealinkObjects{$self->{PHONEIP}} eq $states[0]) or ($yealinkObjects{$self1->{PHONEIP}} eq $states[1])){
        $logger->debug(__PACKAGE__ . ".$sub_name: Phones are not in the initial expected state");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to answer call on $self->{PHONEIP} from $self1->{PHONEIP}"); 
    
    #Frame URL to answer the call
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=OK
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=OK"; 
   
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for answer call");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        @states = ("callEstablished");
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Got success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state");
            if(($yealinkObjects{$self->{PHONEIP}} eq $states[0]  and $yealinkObjects{$self1->{PHONEIP}} eq $states[0])){
                $sleep_time ||= 10;
                $logger->debug(__PACKAGE__ . ".$sub_name: Call has been answered. Sleeping for $sleep_time seconds");
                sleep $sleep_time;
                last;
             } elsif($failures == 5 ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to answer call from $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Calling phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL1);
                $self1->{LWP}->post($endCallURL2);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
             } else {
                $failures++;
             }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response for HTTP request".Dumper($response));
            }
            $self->{LWP}->post($endCallURL1);
            $self1->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 SonusQA::YEALINK::disconnectCall()

  This function is used to end the existing call

=over

=item ARGUMENTS

  Mandatory Args:
  Phone object other than the the phone from where you want to end the call

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

  unless ($phoneA1Obj->disconnectCall($phoneA2Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to end the call");
        return 0;
  }

=back

=cut

sub disconnectCall {
    my $self       = shift;
    my $self1      = shift;
    my (%args)     = @_;
    my $sub_name   = "disconnectCall";        
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($failures) = 1;
    my ($url, $response);

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");
    
    # Below URLs will be used in case of failure
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    unless(($yealinkObjects{$self->{PHONEIP}} eq "outgoingCall" or $yealinkObjects{$self->{PHONEIP}} eq "callEstablished") or ($yealinkObjects{$self1->{PHONEIP}} eq "incomingCall" or $yealinkObjects{$self1->{PHONEIP}} eq "callEstablished" )){
        $logger->error(__PACKAGE__ . ".$sub_name: Phones are not in initial expected state");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to disconnect call on $self->{PHONEIP}");
    
    #Frame URL to disconnect the call
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=CALLEND
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for disconnecting the call");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state .....");    
            if(($yealinkObjects{$self->{PHONEIP}} eq "outgoingCall" or $yealinkObjects{$self->{PHONEIP}} eq "callTerminated" ) and ($yealinkObjects{$self1->{PHONEIP}} eq "incomingCall" or $yealinkObjects{$self1->{PHONEIP}} eq "callTerminated")){
                $logger->debug(__PACKAGE__ . ".$sub_name: Successfully disconnected the call");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 5) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect the call from $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from phones");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL1);
                $self1->{LWP}->post($endCallURL2);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
            }
            $self->{LWP}->post($endCallURL1);
            $self1->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::holdCall()

  This function is used to HOLD the existing call

=over

=item ARGUMENTS

  Mandatory Args:
  Phone object other than the the phone from where you want to HOLD the call

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA1Obj->holdCall($phoneA2Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to HOLD the call");
        return 0;
    }

=back

=cut

sub holdCall {
    my $self     = shift;
    my $self1    = shift;
    my (%args)   = @_;
    my $sub_name = "holdCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@states) = ("callHold");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");

    # Below URLs will be used in case of failure
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    unless(($yealinkObjects{$self->{PHONEIP}} eq "callEstablished" or $yealinkObjects{$self->{PHONEIP}} eq "callUnHold")and ($yealinkObjects{$self1->{PHONEIP}} eq "callEstablished" or $yealinkObjects{$self1->{PHONEIP}} eq "callUnHold" )){
        $logger->error(__PACKAGE__ . ".$sub_name: Both the phones are not in the initail expected state");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
     
    if(defined $args{-musiconhold} and $args{-musiconhold} == 1){
        $logger->error(__PACKAGE__ . ".$sub_name: Music on hold is enabled on $self->{PHONEIP}");
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a call hold on $self->{PHONEIP} ");
    
    #Frame the uRL to HOLD the call
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=F_HOLD
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_HOLD";    

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to HOLD the call");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state ....."); 
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Call HOLD successful");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 5) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do call hold on $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL1);
                $self1->{LWP}->post($endCallURL2);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status- $self->{PHONEIP} : '$yealinkObjects{$self->{PHONEIP}}' $self1->{PHONEIP} : '$yealinkObjects{$self1->{PHONEIP}}' ");
            }
            $self->{LWP}->post($endCallURL1);
            $self1->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::unholdCall()

  This function is used to RESUME the held call

=over

=item ARGUMENTS

  Mandatory Args:
    Phone object other than the the phone from where you put call on HOLD

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA1Obj->unholdCall($phoneA2Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to RESUME the held call");
        return 0;
    }

=back

=cut

sub unholdCall {
    my $self     = shift;
    my $self1    = shift;
    my (%args)   = @_;
    my $sub_name = "unholdCall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@states) = ("callUnHold");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");

    # Below URLs will be used in case of failure
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    unless($yealinkObjects{$self->{PHONEIP}} eq "callHold"){
        $logger->error(__PACKAGE__ . ".$sub_name: Phone not in initial expected state");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a call Unhold on $self->{PHONEIP} ");

    #Frame the uRL to UNHOLD the call
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=F_HOLD
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_HOLD";
    
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to UNHOLD the call");
        $self->{LWP}->post($endCallURL1);
        $self1->{LWP}->post($endCallURL2);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state ....."); 
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Call UNHOLD successful");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 5) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to do call Unhold on $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL1);
                $self1->{LWP}->post($endCallURL2);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status- $self->{PHONEIP} : '$yealinkObjects{$self->{PHONEIP}}' $self1->{PHONEIP} : '$yealinkObjects{$self1->{PHONEIP}}' ");
            }
            $self->{LWP}->post($endCallURL1);
            $self1->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::blindTransferCall()

  This function is used to blind(unattended) transfer the call

=over

=item ARGUMENTS

  Mandatory Args:
    1st Arg --> Tranferee phone object
    2nd Arg --> Destination endpoint (Transfer Target)

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->blindTransferCall($phoneA1Obj, $phoneA3Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Blind transfer failed");
        return 0;
    }

=back

=cut

sub blindTransferCall {
    my $self     = shift;
    my $self1    = shift;
    my $self2    = shift;
    my (%args)   = @_;
    my $sub_name = "blindTransferCall";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Below URLS will be used in case of failure
    my $endCallURL = "http://$self2->{USER_ID}:$self2->{PASSWD}\@$self2->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    my (@states) = ("incomingCall", "callEstablished", "callTerminated");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");

    unless($yealinkObjects{$self->{PHONEIP}} eq "callEstablished" or ($yealinkObjects{$self1->{PHONEIP}} eq "ON_HOOK" or $yealinkObjects{$self1->{PHONEIP}} eq "callTerminated")){
        $logger->error(__PACKAGE__ . ".$sub_name: Both the phones are not in the expected initial state");
        $self2->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to do a blindtransfer call on $self->{PHONEIP} ");

    #Frame the URL to press the 'transfer' key on the phone
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=F_TRANSFER    
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_TRANSFER";

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to transfer the call");
        $self2->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (3);

    # Dial the destination number
    my $phone_no = $self2->{NUMBER};
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?number=$phone_no&outgoing_uri=Account1"; 
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for make a call");
        $self2->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (3);

    # Again press the 'transfer' key on the phone
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_TRANSFER";
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to send transfer key");
        $self2->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (3);

    # Answer the call
    unless ($self2->answerBlindTransferCall($self1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Blind call transfer failed");
        $self2->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Blind call transfer successful");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;    
}


=head2 SonusQA::YEALINK::answerBlindTransferCall()

  This function is used to answer the blind(unattended) transfer the call

=over

=item ARGUMENTS

  Mandatory Args:
    Tranferee phone object

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA3Obj->answerBlindTransferCall($phoneA1Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to answer the blind transfered call");
        return 0;
    }

=back

=cut

sub answerBlindTransferCall {
    my $self       = shift;
    my $self1      = shift;
    my (%args)     = @_;
    my $sub_name   = "answerBlindTransferCall";
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $sleep_time = $args{-sleeptime}; 
    my ($url, $response);
    my ($failures) = 1;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@states) = ("incomingCall", "callEstablished");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of the phone....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    unless($yealinkObjects{$self->{PHONEIP}} eq "incomingCall"){
        $logger->error(__PACKAGE__ . ".$sub_name: Phone is not in the expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting answer the call on $self->{PHONEIP} ");
    
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=OK";
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to answer the call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        @states = ("callEstablished");
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Got success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
                $sleep_time ||= 10;
                $logger->debug(__PACKAGE__ . ".$sub_name: Call has been answered. Sleeping for $sleep_time seconds");
                sleep $sleep_time;
                last;
             } elsif($failures == 5 ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to answer call from $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Called phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
             } else {
                $failures++;
             }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response for HTTP request".Dumper($response));
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 SonusQA::YEALINK::addConferenceCall()

  This function is used to add the another user to conference

=over

=item ARGUMENTS

  Mandatory Args:
    1st Arg --> Other phone object who is already in the call
    2nd Arg --> Destination endpoint whom you want to add to conference

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->addConferenceCall($phoneA1Obj, $phoneA3Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to add A3 to conference");
        return 0;
    }

=back

=cut

sub addConferenceCall {
    my $self       = shift;
    my $self1      = shift;
    my $self2      = shift;
    my (%args)     = @_;
    my $sub_name   = "addConferenceCall";
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $sleep_time = $args{-sleeptime}; 
    my ($url,$response);
    my ($failures) = 1;
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my (@states) = ("incomingCall", "callEstablished", "callTerminated");
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");

    # Below URL will be used in case of failure
    my $endCallURL = "http://$self2->{USER_ID}:$self2->{PASSWD}\@$self2->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    unless($yealinkObjects{$self->{PHONEIP}} eq "callEstablished" and $yealinkObjects{$self1->{PHONEIP}} eq "ON_HOOK"){
        $logger->error(__PACKAGE__ . ".$sub_name: Both the phones are not in expected state");
        $self->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to add a user to conference call on $self->{PHONEIP} ");            

    #Frame the URL to press the 'conference' key on the phone
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=F_CONFERENCE
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_CONFERENCE";

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to press conference key");
        $self->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (3);

    # Dial the destination number
    my $phone_no = $self1->{NUMBER};
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?number=$phone_no&outgoing_uri=Account1"; 
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for make a call");
        $self->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (3);

    # Answer the call
    unless ($self1->answerCall($self, -sleeptime => 5)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Confernce call failed");
        $self->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Again press the 'conference' key on the phone
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=F_CONFERENCE";
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to press conference key again");
        $self->{LWP}->post($endCallURL);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }  
    
    sleep (3);

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        @states = ("callEstablished", "callUnHold");
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Got success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0] and $yealinkObjects{$self1->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: All the users are in conference");
                $sleep_time ||= 10;
                sleep $sleep_time;
                last;
             } elsif($failures == 5 ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to answer call from $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self2->{PHONEIP} status: $yealinkObjects{$self2->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
             } else {
                $failures++;
             }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response for HTTP request".Dumper($response));
            }
            $self->{LWP}->post($endCallURL);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->error(__PACKAGE__ . ".$sub_name: Conference call successfull");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;    
}


=head2 SonusQA::YEALINK::endConferenceCall()

  This function is used to end the conference call

=over

=item ARGUMENTS

  Mandatory Args:
    1st Arg --> Other phone object who is already in the call
    2nd Arg --> Destination endpoint whom you want to add to conference

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->endConferenceCall($phoneA1Obj, $phoneA3Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to end conference call");
        return 0;
    }

=back

=cut

sub endConferenceCall {
    my $self     = shift;
    my $self1    = shift;
    my $self2    = shift;
    my (%args)   = @_;
    my $sub_name = "endConferenceCall";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url, $response);
    my ($failures) = 1;
    my @states     = ("callUnHold", "callEstablished");
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking initial state of both the phones....");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} state: $yealinkObjects{$self1->{PHONEIP}}");

    unless($yealinkObjects{$self->{PHONEIP}} eq $states[1] and $yealinkObjects{$self1->{PHONEIP}} eq $states[1]){
        $logger->error(__PACKAGE__ . ".$sub_name: Phones are not in the expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: Now attempting disconnect the call on $self->{PHONEIP} ");    
    my $endCallURL1 = "http://$self1->{USER_ID}:$self1->{PASSWD}\@$self1->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    my $endCallURL2 = "http://$self2->{USER_ID}:$self2->{PASSWD}\@$self2->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    my $flag = 1;
    foreach $url ($endCallURL1, $endCallURL2) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL ---> $url");
        sleep (2);
        unless($response = $self->{LWP}->post($url)){
            $flag = 0;
        }
    }

    unless ($flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to end the conference call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 10 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 4;
        @states = ("callTerminated");
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Got success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0] and $yealinkObjects{$self1->{PHONEIP}} eq $states[0] and $yealinkObjects{$self2->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Calls have been terminated");
                last;
             } elsif($failures == 10 ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to end the call from $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} status: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self1->{PHONEIP} status: $yealinkObjects{$self1->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self2->{PHONEIP} status: $yealinkObjects{$self2->{PHONEIP}}");
                $self1->{LWP}->post($endCallURL1);
                $self2->{LWP}->post($endCallURL2);
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
             } else {
                $failures++;
             }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response for HTTP request".Dumper($response));
            }
            $self1->{LWP}->post($endCallURL1);
            $self2->{LWP}->post($endCallURL2);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 SonusQA::YEALINK::reboot()

  This function is used to reboot the phone

=over

=item ARGUMENTS

  None

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->reboot()) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to reboot the phone");
        return 0;
    }

=back

=cut

sub reboot {
    my $self     = shift;
    my (%args)   = @_;
    my $sub_name = "reboot";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @states = ("rebooted", "registered");
    $logger->debug(__PACKAGE__ . ".$sub_name: Rebooting the phone $self->{PHONEIP}, it will take aprox 90 sec please wait......");

    #Frame the URL to reboot the phone
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=Reboot
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=Reboot";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to reboot the phone");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 60 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state .....");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[1]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone rebooted successful");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                $yealinkObjects{$self->{PHONEIP}} = 'ON_HOOK';
                $logger->debug(__PACKAGE__ . ".$sub_name: AFTER REBOOT Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                return 1;
            } elsif($failures == 60) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to reboot the phone $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                $logger->debug(__PACKAGE__ . ".$sub_name: AFTER REBOOT Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $yealinkObjects{$self->{PHONEIP}} = 'ON_HOOK';
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status- $self->{PHONEIP} : '$yealinkObjects{$self->{PHONEIP}}'");
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $yealinkObjects{$self->{PHONEIP}} = 'ON_HOOK';
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::enableDND()

  This function is used to enable the DND on phone

=over

=item ARGUMENTS

  None

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->enableDND()) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to enable DND on phone");
        return 0;
    }

=back

=cut

sub enableDND {
    my $self     = shift;
    my (%args)   = @_;
    my $sub_name = "enableDND";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @states = ("enableDND");
    $logger->debug(__PACKAGE__ . ".$sub_name: Rebooting the phone $self->{PHONEIP}, it will take aprox 90 sec please wait......");

    #Frame the URL to enableDND the phone
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=DNDOn
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=DNDOn";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to enableDND the phone");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 60 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state .....");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone enabled DND successful");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 60) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to enable DND on the phone $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status- $self->{PHONEIP} : '$yealinkObjects{$self->{PHONEIP}}'");
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::disableDND()

  This function is used to disable DND on phone

=over

=item ARGUMENTS

  None

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->disableDND()) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to disable DND on phone");
        return 0;
    }

=back

=cut

sub disableDND {
    my $self     = shift;
    my (%args)   = @_;
    my $sub_name = "disableDND";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @states = ("disableDND");
    $logger->debug(__PACKAGE__ . ".$sub_name: Rebooting the phone $self->{PHONEIP}, it will take aprox 90 sec please wait......");

    #Frame the URL to disableDND the phone
    #http://<username:password>@<PhoneIP>/cgi-bin/ConfigManApp.com?key=DNDOff
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=DNDOff";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to disableDND the phone");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 60 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state .....");
            if($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone disabled DND successfuly");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 60) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to disable DND on the phone $self->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status- $self->{PHONEIP} : '$yealinkObjects{$self->{PHONEIP}}'");
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::leaveVoiceMessage()

  This function is used to leave message when user wont answers the call

=over

=item ARGUMENTS

  Phone object for which you want to leave voice message

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->leaveVoiceMessage($phoneA3Obj)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to leave voice message");
        return 0;
    }

=back

=cut

sub leaveVoiceMessage {
    my $self     = shift;
    my $self1    = shift;
    my (%args)   = @_;
    my $sub_name = "leaveVoiceMessage";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    my @states     = ("ON_HOOK", "callEstablished");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking initial state of the phones
    unless($yealinkObjects{$self->{PHONEIP}} eq $states[0]){
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone is not in the initial expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Make a call
    unless ($self->makeCall($self1)) {
        $logger->error("__PACKAGE__ . "."$sub_name: Failed to make a call from $yealinkObjects{$self->{PHONEIP}} to $yealinkObjects{$self1->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $flag = 1;
    while ($failures <= 15 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking the phones state .....");
        if($yealinkObjects{$self->{PHONEIP}} eq $states[1]){
            $logger->debug(__PACKAGE__ . ".$sub_name: Call is established with voice mail server");
            $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for some more time to check call is still in 'established' state .....");
            sleep (15);
            unless ($yealinkObjects{$self->{PHONEIP}} eq $states[1]){
                $logger->debug(__PACKAGE__ . ".$sub_name: It looks like call is terminated with voice mail server...");
                $flag = 0;                  
            }
            last;
        } elsif($failures == 15) {
            $logger->error(__PACKAGE__ . ".$sub_name: Did not connect to voice mail server");
            $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        } else {
            $failures++;
        } 
    }

    unless ($flag) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to leave voice message to $self1->{PHONEIP}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
        $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Phone is still connected with voice mail server so leaving the message now........");
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=POUND";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending a URL ---> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for leavingthe voice message");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ($response->is_success and ${$response}{_rc} == 200) {
        $logger->error(__PACKAGE__ . ".$sub_name: Got failure response for sent HTTP request");
        if (${$response}{_rc} == 401){
            $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
        }
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Disconnecting call to voice mail server...");
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending a URL ---> $endCallURL1");
    sleep (5);
    unless($response = $self->{LWP}->post($endCallURL1)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request to disconnect the call to voice mail server");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $failures = 0;

    while ($failures <= 5 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 2;
        if ($response->is_success and ${$response}{_rc} == 200) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Received success response for sent HTTP request");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking phones state .....");    
            if($yealinkObjects{$self->{PHONEIP}} eq "callTerminated") {
                $logger->debug(__PACKAGE__ . ".$sub_name: Successfully disconnected the call to voice mail server");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                return 1;
            } elsif($failures == 5) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect the call from $self1->{PHONEIP}");
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response from phones");
                $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
                $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
                $self->{LWP}->post($endCallURL1);
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            } else {
                $failures++;
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name: Got failure for sent HTTP request");
            if (${$response}{_rc} == 401){
                $logger->error(__PACKAGE__ . ".$sub_name: Authorization failed. Check your phone credentials on the TMS.".Dumper($response));
            } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Did not get a successful response. ".Dumper($response));
            }
            $self->{LWP}->post($endCallURL1);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
}


=head2 SonusQA::YEALINK::dailToVoicePortal()

  This function is used to dial the voiceportal

=over

=item ARGUMENTS

  voicePortalNum => Voice portal number

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->dailToVoicePortal(-voicePortalNum => $voicePortalNum, -voicePortalPasswd => $passwd)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to dial to voice portal");
        return 0;
    }

=back

=cut

sub dailToVoicePortal {
    my $self     = shift;
    my (%args)   = @_;
    my $sub_name = "dailToVoicePortal";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    my @states     = ("ON_HOOK", "callTerminated", "callEstablished");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory parameters
    unless (defined $args{-voicePortalNum} and defined $args{-voicePortalPasswd}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameters are missing");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Checking initial state of the phones
    unless(($yealinkObjects{$self->{PHONEIP}} eq $states[0]) or ($yealinkObjects{$self->{PHONEIP}} eq $states[1])) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone is not in the initial expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Dialing voice portal number
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?number=$args{-voicePortalNum}&outgoing_uri=Account1";
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";

    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for make a call to voice portal");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 15 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking the phones state .....");
        if($yealinkObjects{$self->{PHONEIP}} eq $states[2]){
            $logger->debug(__PACKAGE__ . ".$sub_name: Call is established with voice mail server");
            $logger->debug(__PACKAGE__ . ".$sub_name: Got the expected response from phone");
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            last;
        } elsif($failures == 15) {
            $logger->error(__PACKAGE__ . ".$sub_name: Did not connect to voice mail server");
            $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
            $self->{LWP}->post($endCallURL1);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        } else {
            $failures++;
        } 
    }

    # Waiting for initial announcement to complete
    sleep (10);

    # Sending voice portal password
    foreach my $num (split('', "$args{-voicePortalPasswd}")) {      
        $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=$num";
        $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");    
        unless($response = $self->{LWP}->post($url)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending voice portal password");
            $self->{LWP}->post($endCallURL1);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        sleep(2);
    }

    # Sending POUND (or #)
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=POUND";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending POUND key");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    return 1;
}

=head2 SonusQA::YEALINK::retrieveVoiceMessage()

  This function is used to retrieve message

=over

=item ARGUMENTS

  Mandatory Args:
    -voicePortalNum    => Voice portal number
    -voicePortalPasswd => voice portal password

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->retrieveVoiceMessage(-voicePortalNum => $voicePortalNum, -voicePortalPasswd => $password)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to leave voice message");
        return 0;
    }

=back

=cut

sub retrieveVoiceMessage {
    my $self     = shift;
    my (%a)      = @_;
    my $sub_name = "retrieveVoiceMessage";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response,%args);
    my ($failures) = 1;
    my @states     = ("ON_HOOK", "callTerminated", "callEstablished");

    while ( my ($key, $value) = each %a) { $args{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $endCallURL1 = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND"; 
    # Checking mandatory parameters
    unless (defined $args{-voicePortalNum} and defined $args{-voicePortalPasswd}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameters are missing");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Checking initial state of the phones
    unless(($yealinkObjects{$self->{PHONEIP}} eq $states[0]) or ($yealinkObjects{$self->{PHONEIP}} eq $states[1])) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone is not in the initial expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Dial to voice portal
    unless($self->dailToVoicePortal(-voicePortalNum => $args{-voicePortalNum}, -voicePortalPasswd => $args{-voicePortalPasswd})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in dialing to voice portal");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
        
    sleep (15);

    # Press 1 to enter to voice mail account
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=1";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending a key '1'");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (15);

    # Retrieve the 1st message by pressing 1
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=1";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending a key '1' while retrieving mesage");
        $self->{LWP}->post($endCallURL1);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Waiting till retrieving of 1st message completes
    sleep (10);

    # Disconnect the call
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for disconnecting the call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 15 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking the phones state .....");
        if($yealinkObjects{$self->{PHONEIP}} eq $states[1]){
            $logger->debug(__PACKAGE__ . ".$sub_name: Call is terminated with voice mail server");            
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Retrieval of voice message is successful");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        } elsif($failures == 15) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect voice mail server");
            $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        } else {
            $failures++;
        } 
    } 
}


=head2 SonusQA::YEALINK::deleteAllVoiceMessages()

  This function is used to delete all the voice messages

=over

=item ARGUMENTS

  Mandatory Args:
    -voicePortalNum    => Voice portal number
    -voicePortalPasswd => voice portal password

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->deleteAllVoiceMessages(-voicePortalNum => $voicePortalNum, -voicePortalPasswd => $password)) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to leave voice message");
        return 0;
    }

=back

=cut

sub deleteAllVoiceMessages {
    my $self     = shift;
    my (%a)      = @_;
    my $sub_name = "deleteAllVoiceMessages";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($url,$response);
    my ($failures) = 1;
    my %args       = (-allreadyInCallWithVoicePrtl => 0);
    my @states     = ("ON_HOOK", "callTerminated", "callEstablished");

    while ( my ($key, $value) = each %a) { $args{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
  
    # Checking mandatory parameters
    unless (defined $args{-voicePortalNum} and defined $args{-voicePortalPasswd}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameters are missing");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Checking initial state of the phones
    unless(($yealinkObjects{$self->{PHONEIP}} eq $states[0]) or ($yealinkObjects{$self->{PHONEIP}} eq $states[1])) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone is not in the initial expected state");
        $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Dial to voice portal
    unless($self->dailToVoicePortal(-voicePortalNum => $args{-voicePortalNum}, -voicePortalPasswd => $args{-voicePortalPasswd})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in dialing to voice portal");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    sleep (15);

    # Press 1 to acees voice mail account
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=1";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending a key '1'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (28);

    # Delete all the voice messages by pressing 7
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=7";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending a key '1' while retrieving mesage");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (8);

    # Press 1 to confirm the deletion of all messages
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=1";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");

    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for sending a key '1' while retrieving mesage");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    sleep (10);

    # Disconnect the call
    $url = "http://$self->{USER_ID}:$self->{PASSWD}\@$self->{PHONEIP}/cgi-bin/ConfigManApp.com?key=CALLEND";
    $logger->debug(__PACKAGE__ . ".$sub_name: Sending URL --> $url");
    unless($response = $self->{LWP}->post($url)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failure in sending HTTP request for disconnecting the call");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    while ($failures <= 15 ){
        $logger->error(__PACKAGE__ . ".$sub_name: Waiting for a response.. Attempt: $failures");
        sleep 3;
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking the phones state .....");
        if($yealinkObjects{$self->{PHONEIP}} eq $states[1]){
            $logger->debug(__PACKAGE__ . ".$sub_name: Call is terminated with voice mail server");            
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Retrieval of voice message is successful");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        } elsif($failures == 15) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to disconnect voice mail server");
            $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected response");
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone $self->{PHONEIP} state: $yealinkObjects{$self->{PHONEIP}}");
            $logger->error(__PACKAGE__ . ".$sub_name: Got the response: ".Dumper($response));
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        } else {
            $failures++;
        } 
    } 
}

    
=head2 SonusQA::YEALINK::handleResponse()

  This function is used to read the notifications comming on the socket

=over

=item ARGUMENTS

  None

=item RETURNS

  1 - Success
  0 - Failure

=item EXAMPLE

    unless ($phoneA2Obj->handleResponse()) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to read the notifications from socket");
        return 0;
    }

=back

=cut

sub handleResponse {
    my (%args)     = @_;
    $client_socket = shift;
    my $sub_name   = "handleResponse";
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $found;
               
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # get the host and port number of newly connected client.
    $peer_address = $client_socket->peerhost();
    $peer_port    = $client_socket->peerport();
    $logger->debug(__PACKAGE__ . ".$sub_name: Accepted New Client Connection From: $peer_address, $peer_port");

    # read operation on the newly accepted client
    $data = undef;
    $client_socket->recv($data,2048);

    $logger->debug(__PACKAGE__ . ".$sub_name: Received from Client : $data");
    my @arr = split( /\n/, $data);
    
    foreach my $line (@arr){
        if($line =~ /GET\s+\/(\S+)\/ip=(\S+)\s+HTTP/){
            $logger->debug(__PACKAGE__ . ".$sub_name:  Matched 1:[$1] and 2:[$2]");
            $yealinkObjects{"$2"} = "$1";
            $logger->debug(__PACKAGE__ . ".$sub_name: Phone Status".Dumper(\%yealinkObjects));
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Closing the client socket after handling the response..");    
    $client_socket->close();
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 SonusQA::YEALINK::DESTROY()

  This function is used to destroy the YEALINK object

=over

=item ARGUMENTS

  None

=item RETURNS

  Nothing

=back

=cut

sub DESTROY{
    my ($self) = @_;
    my $sub_name  = 'DESTROY';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Destroying object");
    while ( my $key = each %yealinkObjects ) {
        if($key eq $self->{PHONEIP}){
            $logger->debug(__PACKAGE__ . ".$sub_name Deleting $key from the yealink objects hash.");
            delete $yealinkObjects{$key};
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name yealinkObjects after destroying [$self->{OBJ_HOST}] ".Dumper(\%yealinkObjects));
    $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Destroyed object");
    sleep 5;
}

1;
