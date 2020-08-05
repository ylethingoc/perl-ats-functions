package SonusQA::BTBC ;

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper ; 
use LWP::UserAgent ;
our $VERSION = "1.0";

use vars qw($self); 

sub new { 
    my ($class , %args) = @_ ;  
    my %tms_alias = () ; 
    my $sub = "new" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub ") ;   

    my $alias = $args{-tms_alias_name} ; 
    my $tms_alias = &SonusQA::Utils::resolve_alias($alias) ; 
    
    my $self = { HOST_NAME => $tms_alias->{NODE}->{1}->{IP},
		 PORT      => $tms_alias->{NODE}->{1}->{PORT}, 
		 __OBJTYPE => $tms_alias->{__OBJTYPE} ,
		 NUMBER    => $tms_alias->{NODE}->{1}->{NUMBER},
               } ; 

    bless $self, $class ; 

    unless($self->doInitialization(%args)){
        $logger->error(__PACKAGE__ . ".$sub: Failure while Initialising the values."); 
        return 0 ;
    } 
    $logger->debug(__PACKAGE__ . ".$sub --> Dumper of object :".Dumper($self) ) ;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return $self;
} 

sub doInitialization {
    my ($self , %args) = @_ ; 
    my $sub = "doInitialization" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
   
    $self->{CALL_TYPE} = 'VoIPCall' ;  
}

=head1 performAction()

 The function is used to do required action on btbc clients.

=over

=item ARGUMENTS:
 Mandatory Args:
    $url - URL to send HTTP request

 Optional Args:
    NONE
  e.g:
    unless ($self->performAction($url)) {
        $logger->error("__PACKAGE__ . ".$subName: performAction failed");
        return 0;
    }

=item PACKAGES USED:
 LWP::UserAgent 

=item GLOBAL VARIABLES USED:
 None

=item EXTERNAL FUNCTIONS USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=back

=cut

sub performAction {
    my ($self, $url) = @_;
    my $sub          = 'performAction';
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
 
    my $lwp ;
    unless (defined $lwp) {
        $lwp = new LWP::UserAgent ;
    }

    my $response = $lwp->get($url) ;

    # getting response code and response content 
    my $response_code = $response->code() ;
    $logger->info(__PACKAGE__ . ".$sub: --> Response code is : $response_code " );

    my $response_content = $response->content() ;
    $logger->info(__PACKAGE__ . ".$sub: --> Response content is : $response_content " );

    unless ( $response_code == 200 ) {
        $logger->error(__PACKAGE__ . ".$sub : ERROR ::  Expected 200 OK response -but got $response_code");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Required action performed successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return 1;    
}

=head1 makeCall()

 The function is used to make a out-going call from .

=over

=item ARGUMENTS:
 Mandatory Args:
    The object of the party being called (example lync or polycom or any other third party element).

=item PACKAGES USED:
 None

=item GLOBAL VARIABLES USED:
 None

=item EXTERNAL FUNCTIONS USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE:  
    unless ($btbcClient1->makeCall($otherClient )) {
        $logger->error("__PACKAGE__ . ".$subName: makeCall failed for the btbc client");
        return 0;
    } 

=back

=cut 

sub makeCall {
    
    my ($self)     = shift ; 
    my ($self1)    = shift ; 
    my $sub        = 'makeCall';
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my ($number, $call_type, $session_id, $params) ; 
    
    $number = $self1->{NUMBER} ; 
    $call_type = $self->{CALL_TYPE} ; 
    $session_id = $self->{SESSION_ID} ; 

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=StartCommunication" ; 
 
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";  

    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable make out-going call");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    } 

    sleep 2 ; 

    $logger->debug(__PACKAGE__ . ".$sub : Successfuly made out-going call");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    return 1;        
}


=head1 answerCall()

 The function is used to accept the incoming call.

=over

=item ARGUMENTS:
 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGES USED:
 None

=item GLOBAL VARIABLES USED:
 None

=item EXTERNAL FUNCTIONS USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE: 
    unless ($btbcClient1->answerCall()) {
        $logger->error("__PACKAGE__ . ".$subName: answerCall failed");
        return 0;
    }

=back

=cut

sub answerCall {
    
    my ($self) = shift ; 
    my ($self1) = shift ;  
    my $sub    = 'answerCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");   
    my ($number, $call_type, $session_id, $params) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallAnswer" ;

    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to accept incoming call");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
 
    $logger->debug(__PACKAGE__ . ".$sub : Successfuly accepted the call"); 
    $logger->debug(__PACKAGE__ . ".$sub : sleeping for two seconds"); 
    sleep 2 ; 

    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    return 1;        
}

=head1 disconnectCall()

 The function is used to end the call.

=over

=item ARGUMENTS:
 Mandatory Args:
    object of the other party with whom the call has to be disconnected. (example : BTBC object or Lync object or Polycom Object).

 Optional Args:
    None

=item RETURNS:

 1 - Success
 0 - Failure

=item EXAMPLE: 
    unless ($btbcClient1->disconnectCall($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: disconnectCall failed");
        return 0;
    }

=back

=cut


sub disconnectCall {
    
    my ($self)  = shift ; 
    my ($self1)   = shift ; 
    my $sub        = 'disconnectCall';
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
       
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    
    my ($number, $call_type, $session_id, $params) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallHangup" ;

    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params"; 
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 
 
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to end the call");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
     
    $logger->debug(__PACKAGE__ . ".$sub : Successfuly disconnected the call");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1;        
}

=head1 holdCall()

 - The function is used to hold the call for the respective client upon which it is being called. 

=over

=item ARGUMENTS:
 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGES USED:
 None

=item GLOBAL VARIABLES USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE:  
    unless ($btbcClient1->holdCall($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: call hold failed for BTBC client");
        return 0;
    }    

=back

=cut


sub holdCall {
    my $self = shift  ;  
    my $self1 = shift ; 
    my $sub = "holdCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    my ($number, $call_type, $session_id, $params, $url) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallHold&hold=1" ;

    $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 
     
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to hold the call");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub : Successfuly done the call hold with $self1->{NUMBER} "); 
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 unholdCall()

 - The function is used to unhold the call for the respective client which is in hold. 

=over

=item ARGUMENTS:
 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGES USED:
 None

=item GLOBAL VARIABLES USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE:  
    unless ($btbcClient1->unholdCall($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: call unhold failed");
        return 0;
    }    

=back

=cut

sub unholdCall {
    my ($self) = shift ; 
    my $self1 = shift ; 
    my $sub = "unholdCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    my ($number, $call_type, $session_id, $params, $url) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallHold&hold=0" ;

    $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 
    
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to unhold the call");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    } 
 
    $logger->info(__PACKAGE__ . ".$sub : Successfuly done the call unhold for $self1->{NUMBER} ");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 muteCall() 

 - The function is used to mute the call for the respective client upon which this subrutine is being called. 

=over

=item ARGUMENTS:
 Mandatory Args:
    None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE:  
    unless ($btbcClient1->muteCall()) {
        $logger->error("__PACKAGE__ . ".$subName: call mute failed");
        return 0;
    }    

=back

=cut



sub muteCall {
    my ($self) = shift ; 
    my ($self1) = shift ;  
    my $sub = "muteCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
	
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    my ($number, $call_type, $session_id, $params, $url) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallMute&mute=1" ;

    $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 
    	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to mute the participant $self1->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub : Successfuly muted the participant $self1->{NUMBER}"); 
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 unmuteCall()

 - The function is used to unmute the call for the respective client upon which this subroutine is being called. 

=over

=item ARGUMENTS:
 Mandatory Args:
    None

 Optional Args:
    None

=item PACKAGES USED:
 None

=item RETURNS:
 1 - Success
 0 - Failure

=item EXAMPLE:  
    unless ($btbcClient1->unmuteCall()) {
        $logger->error("__PACKAGE__ . ".$subName: call unmute failed");
        return 0;
    }     

=back

=cut



sub unmuteCall {
    my ($self) = shift ; 
    my ($self1) = shift ;     
    my $sub = "unmuteCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
	
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 
    my ($number, $call_type, $session_id, $params, $url) ;

    $number = $self1->{NUMBER} ;
    $call_type = $self->{CALL_TYPE} ;
    $session_id = $self->{SESSION_ID} ;

    $params = "addr=$number&type=$call_type&session_id=$session_id&cmd=CallMute&mute=0" ;

    $url = "http://$self->{HOST_NAME}:$self->{PORT}/api?$params";
    $logger->info(__PACKAGE__ . ".$sub: --> URL is : \'$url\' "); 
    
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to unmute the participant $self1->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub : Successfuly unmuted the participant $self1->{NUMBER}");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1; 
}

1;
