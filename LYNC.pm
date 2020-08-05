package SonusQA::LYNC;

=head1 NAME

SonusQA::LYNC- Perl module for LYNC Integration with ATS framework.

=head1 AUTHOR

Mayank Garg - <mgarg@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, LWP::UserAgent, URI.

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION

This module provides the APIs for Lync for handling its interaction with the other third party products as Polycom, BTBC etc. 
It takes care of the basic call flows, call transfer, call hold/unhold, call mute/unmute etc. 

=head1 METHODS

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper ; 
use LWP::UserAgent ; 
use URI ;     # used for encoding the URL strings  
our $VERSION = "1.0";
our @ISA = qw(SonusQA::Base);
use vars qw($self); 

sub doInitialization {
    my ($self , %args) = @_ ; 
    my $sub = "doInitialization" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
    
    $self->{PHONEIP} = $self->{HOST_NAME} ;    # for Polycom  
    $self->{PREFIX_NAME} = "sip:" ;   
    $self->{PREFIX_NUM}  = "tel:+1"  ;
    $self->{HOST_NAME} = $args{-tms_alias_data}->{NODE}->{1}->{IP};
    $self->{PORT}     = $args{-tms_alias_data}->{NODE}->{1}->{PORT};
    $self->{__OBJTYPE} = $args{-tms_alias_data}->{__OBJTYPE};
    $self->{USER_NAME} = $args{-tms_alias_data}->{LOGIN}->{1}->{USERID};
    $self->{USER_DOMAIN} = $args{-tms_alias_data}->{LOGIN}->{1}->{DOMAIN};
    $self->{PASSWORD} = $args{-tms_alias_data}->{LOGIN}->{1}->{PASSWD};
    $self->{NUMBER}   = $args{-tms_alias_data}->{NODE}->{1}->{NUMBER};
    $self->{OutputDataPath} =  $args{-tms_alias_data}->{NODE}->{3}->{EXECPATH};
    $self->{MediaAppsPath} =  $args{-tms_alias_data}->{NODE}->{2}->{EXECPATH};
    $self->{InputDataPath}  =  $args{-tms_alias_data}->{NODE}->{1}->{EXECPATH};
    $self->{USERID}    = $args{-tms_alias_data}->{NODE}->{1}->{USERID};
    $self->{PASSWD} = $args{-tms_alias_data}->{NODE}->{1}->{PASSWD};
    
    unless ($self->userSignIn()) {
        $logger->error(__PACKAGE__ . ".$sub: userSignIn failed"); 
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]"); 
        return 0 ;         
    }
    
}

=head1 performAction()

=over

=item DESCRIPTION: 

The function is used to do required action on Lync clients(it is called internally by other functions) . 

=item ARGUMENTS:

Mandatory Args:
$url - URL to send HTTP request

Optional Args:

NONE

=item PACKAGES USED:

LWP::UserAgent

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

    unless ($self->performAction($url)) {
        $logger->error("__PACKAGE__ . ".$subName: performAction failed");
        return 0;
    }

=back

=cut

sub performAction {
    my ($self, $url ) = @_;
    my $sub          = 'performAction';
    my $logger       = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
	
    my $lwp ;
     
    unless (defined $lwp) {
        $lwp = new LWP::UserAgent;       
    } 
    my $response = $lwp->get($url) ;  

    my $response_code = $response->code() ; 
    $logger->info(__PACKAGE__ . ".$sub: --> Response code is : $response_code " );

    my $response_content = $response->content() ; 
    $logger->info(__PACKAGE__ . ".$sub: --> Response content is : $response_content " ); 
    
    $self->{CONTENT} = $response_content ; 
           
    unless ($response_code == 200 and $response_content =~ /\{1\}/ ) {
        $logger->error(__PACKAGE__ . ".$sub: ERROR ::  Expected 200 OK response -and got $response_code");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;     
    } 
    $logger->debug(__PACKAGE__ . ".$sub: Required action performed successfully");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;      
}


=head1 userSignIn()

=over

=item DESCRIPTION: 

- The function is used to signin to Lync clients.
- It is called internally by the framework while creating the Lync object. (i.e. upon creating the lync object, it gets signed in automatically)

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

    unless ($lyncClient1->userSignIn()) {
        $logger->error("__PACKAGE__ . ".$subName: userSignIn failed");
        return 0;
    }

=back

=cut

sub userSignIn {    
    my ($self) = @_;
    my $sub    = 'userSignIn';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub"); 

    my $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN};

    my $url = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/UserSignIn") ; 

    $url->query_form('username' => $userName, 'password' => $self->{PASSWORD}) ;   
    
    $logger->info(__PACKAGE__ . ".$sub: URL is : \'$url\' "); 

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable signin for client $self->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly signed-in for client $self->{NUMBER}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;        
}

=head1 userSignOut()

=over

=item DESCRIPTION: 

The function is used to signout from Lync clients.

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

    unless ($lyncClient1->userSignOut()) {
        $logger->error("__PACKAGE__ . ".$subName: userSignOut failed");
        return 0;
    }

=back

=cut

sub userSignOut {    
    my ($self) = @_;
    my $sub    = 'userSignOut';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    
    my $url    = "http://$self->{HOST_NAME}:$self->{PORT}/UserSignOut";
    
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable signout for $self->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly signed-out for $self->{NUMBER}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;        
}


=head1 makeCall()

=over

=item DESCRIPTION: 

The function is used to make a out-going call.

=item ARGUMENTS:

Mandatory Args:
The object of the party being called (example lync or polycom or any other third party element).

Optional Args:
-removePlusOne => to check whether call is working without +1 also.  
# by default the value of the flag is 0. 

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

    unless ($lyncClient1->makeCall($otherClient )) {
        $logger->error("__PACKAGE__ . ".$subName: makeCall failed for the client");
        return 0;
    } 

    unless ($lyncClient1->makeCall($otherClient, -removePlusOne => 1 )) {
        $logger->error("__PACKAGE__ . ".$subName: makeCall failed for the client");
        return 0;
    }

=back

=cut

sub makeCall {
    
    my ($self)     = shift ; 
    my ($self1)    = shift ; 
    my (%args)     = @_ ; 
    my $sub        = 'makeCall';
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($number, $url) ;
    
    my $removePlusOne = (defined $args{-removePlusOne}) ? $args{-removePlusOne} : 0 ; 

    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    $logger->info(__PACKAGE__ . ".$sub:  flag value is: $removePlusOne");    
    
    $logger->info(__PACKAGE__ . ".$sub:  making a call with $self1->{NUMBER}");


    $number = ($removePlusOne) ? $self1->{NUMBER} : $self->{PREFIX_NUM}.$self1->{NUMBER}  ;	

    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/MakeOutGoingCall"); 
    $url->query_form('callee' => $number) ;

    $logger->info(__PACKAGE__ . ".$sub: URL is : $url "); 

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable make out-going call");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 

    sleep 2 ; 

    $logger->debug(__PACKAGE__ . ".$sub: Successfuly made out-going call");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;        
}

=head1 isCallAlerting()

=over

=item DESCRIPTION: 

- The function is used to check the call alerting status for Lync clients. 
- if failed, it will check for three times in loop. 

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

    unless ($lyncClient1->isCallAlerting()) {
        $logger->error("__PACKAGE__ . ".$subName: call alerting failed");
        return 0;
    }

=back

=cut

sub isCallAlerting {
    my ($self) = @_ ; 
    my $sub = "isCallAlerting" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my $result = 0 ; 
    my ($i, $url) ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $url  = "http://$self->{HOST_NAME}:$self->{PORT}/IsCallAlerting" ;  

    for ( $i = 0 ; $i < 3 ; ++$i ) {
        unless ($self->performAction($url)) {
            $logger->error(__PACKAGE__ . ".$sub : Unable to check for call alerting");
            sleep 1 ;     
        } else {
		    $result = 1 ; 
		    last ; 		
	       }
    } 

    if ($result) {	
        $logger->debug(__PACKAGE__ . ".$sub: Successfuly checked for call alerting");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]"); 

    } else {  
         $logger->error(__PACKAGE__ . ".$sub: Call Alerting failed "); 
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0 ; 
    }  
		
    return 1;
}


=head1 answerCall()

=over

=item DESCRIPTION: 

The function is used to accept the incomming call.

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

    unless ($lyncClient1->answerCall()) {
        $logger->error("__PACKAGE__ . ".$subName: answerCall failed");
        return 0;
    }

=back

=cut

sub answerCall {
    
    my ($self) = @_;
    my $sub    = 'answerCall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $result = 0; 
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
 
    my $url  = "http://$self->{HOST_NAME}:$self->{PORT}/AcceptIncomingCall";    
    
    for (my $i = 0; $i <= 5; ++$i) {
        unless ($self->performAction($url)) {
            $logger->error(__PACKAGE__ . ".$sub : Unable accept the call, trying again after 1 sec ......");
            sleep (1);
        } else {
            $result = 1;
            last;
        }           
    }    
    unless ($result) {
        $logger->error(__PACKAGE__ . ".$sub: failed to accept the call");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly accepted the call");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;        
}

=head1 isCallConnected()

=over

=item DESCRIPTION: 

The function is used to test call connectivity between two clients.

=item ARGUMENTS:

Mandatory Args:
Object of the other party with whom the status has to checked. (example : Lync object or Polycom Object). 

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

    unless ($lyncClient1->isCallConnected(callee => $other_party_username)) {
        $logger->error("__PACKAGE__ . ".$subName: isCallConnected failed");
        return 0;
    }

=back

=cut

## no response 
## exists  not active 
## exists and active 
## doesnt exist 
# print the state.

sub isCallConnected {    
    my ($self)     = shift ; 
    my ($self1)      = shift ; 
    
    my $sub        = 'isCallConnected';
    my $result     = 0; 
    my $logger     = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($number, $url );
        
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    
    $number = $self->{PREFIX_NUM}.$self1->{NUMBER} ; 
    $url    = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/GetConversationStatus") ;  
    $url->query_form('callee' => $number) ; 

    $logger->info(__PACKAGE__ . ".$sub: URL is $url ");
    
    for (my $i = 0; $i < 2 ; ++$i) {
        unless ($self->performAction($url)) {
            $logger->error(__PACKAGE__ . ".$sub: Still call has not connected yet, Checking again after 2 secs......");
            sleep (2);
        } else {
            $result = 1;
            last;
        }           
    }
    
    unless ($result) {
        $logger->error(__PACKAGE__ . ".$sub: Oh! call hasn't connected");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly disconnected the call");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;        
}

=head1 disconnectCall()

=over

=item DESCRIPTION: 

The function is used to end the call.

=item ARGUMENTS:

Mandatory Args:
object of the other party with whom the call has to be disconnected. (example : Lync object or Polycom Object).   

Optional Args:
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

    unless ($lyncClient1->disconnectCall($otherClient)) {
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
    my ($number, $url);
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    
    $number = $self->{PREFIX_NUM}.$self1->{NUMBER} ;  
    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/EndCall"); 
    $url->query_form('endCallUri' => $number) ;  
 
    $logger->info(__PACKAGE__ . ".$sub: URL is $url");
    
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable end the call");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
     
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly disconnected the call");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;        
}


=head1 disconnectAllCalls()

=over

=item DESCRIPTION: 

The function is used to end all the calls active on the client.

=item ARGUMENTS:

No argument required

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

    unless ($lyncClient1->disconnectAllCalls()) {
        $logger->error("__PACKAGE__ . ".$subName: disconnectAllCalls failed");
        return 0;
    }

=back

=cut


sub disconnectAllCalls {
    my ($self) = @_ ; 
    my $sub = "disconnectAllCalls" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");    

    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/EndAllCalls" ;  
        
    $logger->info(__PACKAGE__ . ".$sub: URL is : $url ");

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to end all the calls");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Successfuly disconnected all the calls");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");

    return 1;
}

=head1 presenceStatus()

=over

=item DESCRIPTION: 

The function is used to check the presence status of the client. (only applicable for LYNC Client)

=item ARGUMENTS:

Mandatory Args:
- object of the other party whose status has to be checked. (example : Lync object)

Optional Args:
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

    unless ($lyncClient1->presenceStatus($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: failed to check the status of client");
        return 0;
    }

=back

=cut

sub presenceStatus {
    my ($self) = @_ ;
    my $sub = "presenceStatus" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered sub");
     
    my $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN}; 
 
    my $url = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/GetClientPresenceStatus") ;	
    $url->query_form('forContact' => $userName) ; 	

    $logger->info(__PACKAGE__ . ".$sub: URL is $url "); 

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to get the status of the client");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly got the status of the client");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;  
}

=head1 changeStatus()

=over

=item DESCRIPTION: 
- The function is used to change the status of the client.
- supported modes in status of the client are : 

Parameter   ::   Actual Status  
======================================    
busy     ::   Busy
available  ::  Available 
donotdisturb  ::  Do Not Disturb 
away      ::  Appear Away      

=item ARGUMENTS:

Mandatory Args: 
$status : the value of the status .

Optional Args: 
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:    

    unless ($lyncClient1->changeStatus($status)) {
        $logger->error("__PACKAGE__ . ".$subName: failed to change the status of client");
        return 0;
    }

=back

=cut

sub changeStatus {
    my ($self , $status) = @_ ;
    my $sub = "changeStatus" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered sub");
	
    my $url = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/ChangeStatus") ;
    $url->query_form('status' => $status) ; 

    $logger->info(__PACKAGE__ . ".$sub: URL is $url \n"); 

    unless ($self->performAction($url)) {
	$logger->error(__PACKAGE__ . ".$sub : Unable to change the status of the client to $status");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;    
	}
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly changed the status of the client to $status");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 

}

=head1 forwardCall()

=over

=item DESCRIPTION: 

The function is used to forward the call to the mentioned client.

=item ARGUMENTS:

Mandatory Args: 
- object of the other party to whom call has to be transferred. (example : Lync object or Polycom Object) 

Optional Args: 
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:    

    unless ($lyncClient1->forwardCall($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: failed to forward the call to object $otherClient");
        return 0;
    } 

=back

=cut

sub forwardCall {
    my ($self) = shift;
    my $self1 = shift ; 
    my $sub = "forwardCall" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($params, $action, $number, $url) ; 
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 
	
    $number = $self->{PREFIX_NUM}.$self1->{NUMBER}  ;
 
    $url = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/CallForward") ; 
    $url->query_form('forwardclient' => $number) ; 
    
    $logger->info(__PACKAGE__ . ".$sub: URL is $url \n ") ;
	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : unable to forward the call to $self1->{NUMBER}") ; 
	$logger->debug(__PACKAGE__ . ".$sub: Leaving Sub [0]") ;
	return 0 ;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub Successfuly forwarded the call to $self1->{NUMBER}") ;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 	
}

=head1 rejectCall()

=over

=item DESCRIPTION: 

The function is used to reject the call before answering.

=item ARGUMENTS:

No arguments

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:    

    unless ($lyncClient1->rejectCall()) {
        $logger->error("__PACKAGE__ . ".$subName: failed to reject the call");
        return 0;
    }

=back

=cut

sub rejectCall {
    my ($self) = @_ ; 
    my $sub = "rejectCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 
	
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/RejectCall" ;

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to reject the call");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 

    $logger->debug(__PACKAGE__ . ".$sub Successfuly rejected the call") ;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");   
    return 1;
}

=head1 blindTransferCall()

=over

=item DESCRIPTION: 

The function is used for blind transfer of the call to the listed number.

=item ARGUMENTS:

Mandatory Args:
- two objects of the parties involved in blind Transfer, 
- $object1 : calling party object 
- $object2 : transfer party object 
- Both the objects can either be Lync or Polycom.  

Optional Args: 
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:    

    unless ($lyncClient1->blindTransferCall($object1, $object2)) {
        $logger->error("__PACKAGE__ . ".$subName: failed to blindTransfer the Call");
        return 0;
    }    

=back

=cut

sub blindTransferCall {
    my $self = shift ; 
    my $self1 = shift ; 
    my $self2 = shift ; 

    my $sub = "blindTransferCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($userName, $caller, $transfer, $url ) ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN};
    $caller = ($self1->{__OBJTYPE} eq 'LYNC') ? $userName : $self->{PREFIX_NUM}.$self1->{NUMBER} ; 
    $transfer =  $self->{PREFIX_NUM}.$self2->{NUMBER} ;
      
    $url  =  URI->new("http://$self->{HOST_NAME}:$self->{PORT}/BlindTransfer") ; 
    $url->query_form( 'callerUri' => $caller, 'transferUri' => $transfer) ;   

    $logger->info(__PACKAGE__ . ".$sub: URL is $url \n  ") ;
	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to perform blind transfer to the client \'$self2->{NUMBER}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly done the blind transfer to \'$self2->{NUMBER}\'");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1;  
}

=head1 attendedTransferCall() 

=over

=item DESCRIPTION: 

The function is used for attended transfer of the call to the listed number.

=item ARGUMENTS:

Mandatory Args:
- two objects of the parties involved in attended Transfer, 
- $object1 : calling party object 
- $object2 : transfer party object 
- Both the objects can either be Lync or Polycom.  

- Internally, the call will be made and answered from the second object from the object on which attended transfer is initiated. 
- after successfully accepting the call, transfer will be done. 

Optional Args: 
None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:    

    unless ($lyncClient1->attendedTransferCall($object1, $object2)) {
        $logger->error("__PACKAGE__ . ".$subName: failed while doing attended transfer for the call");
        return 0;
    }

=back

=cut

## Naveen to check 

sub attendedTransferCall {
    my $self = shift ; 
    my $self1 = shift ; 
    my $self2 = shift ; 
    my $sub = "attendedTransferCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($userName, $caller, $transfer, $url ) ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    unless ($self->makeCall($self2))  {
        $logger->error(__PACKAGE__ . ".$sub: failed to make a call with $self2->{NUMBER}") ;  
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;         
    } 
    $logger->debug(__PACKAGE__ . ".$sub: Make Call Successful with $self2->{NUMBER} ") ;

    unless ($self2->answerCall($self))  {
         $logger->error(__PACKAGE__ . ".$sub: failed to answer call with $self2->{NUMBER}") ;
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
         return 0 ; 
    } 
    $logger->debug(__PACKAGE__ . ".$sub: Answer Call Successful with $self2->{NUMBER} ") ;  
    
    sleep 5 ;

    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN}; 
    $caller = ($self1->{__OBJTYPE} eq 'LYNC') ? $userName : $self->{PREFIX_NUM}.$self1->{NUMBER} ; 
    $transfer = ($self2->{__OBJTYPE} eq 'LYNC') ? $userName : $self->{PREFIX_NUM}.$self2->{NUMBER} ;
      		
    $url = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/ConsultativeTransfer") ;	 
    $url->query_form( 'callerUri' => $caller , 'transferUri' => $transfer)  ; 

    $logger->info(__PACKAGE__ . ".$sub: URL is $url \n") ; 
	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to perform consultative transfer to the client $self2->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly done the consultative transfer to $self2->{NUMBER}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 holdCall()

=over

=item DESCRIPTION: 
- The function is used to hold the call for the respective client upon which it is being called. 

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

    unless ($lyncClient1->holdCall($otherClient)) {
        $logger->error("__PACKAGE__ . ".$subName: call hold failed");
        return 0;
    }

=back

=cut

sub holdCall {
    my $self = shift  ;  
    my $self1 = shift ; 
    my $sub = "holdCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($userName, $url , $number ) ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 
     
    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN};    
    
    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/CallHold") ;	 
    $url->query_form('callee' => $userName) ;  

    $logger->info(__PACKAGE__ . ".$sub: --> URL is : $url ") ;
             	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to hold the call for $self1->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Successfuly done the call hold with $self1->{NUMBER} "); 
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 unholdCall()

=over

=item DESCRIPTION: 
- The function is used to unhold the call for the respective client which is in hold. 

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

    unless ($lyncClient1->unholdCall($otherClient)) {
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
    my ($userName, $url  )  ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN}; 
 
    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/CallUnHold") ;  
    $url->query_form('callee' => $userName) ;	

    $logger->info(__PACKAGE__ . ".$sub: --> URL is : $url ") ;	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to unhold the call for $self->{NUMBER}");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
     
    $logger->info(__PACKAGE__ . ".$sub : Successfuly done the call unhold for $self->{NUMBER} ");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    
    return 1; 
}


=head1 muteCall() 

=over

=item DESCRIPTION: 

The function is used to mute the call for the respective client upon which this subrutine is being called. 

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

    unless ($lyncClient1->muteCall()) {
        $logger->error("__PACKAGE__ . ".$subName: call mute failed");
        return 0;
    }

=back

=cut

sub muteCall {
    my $self= @_ ; 
    my $sub = "muteCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($userName, $url) ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN}; 
    
    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/MuteParticipant") ; 
    $url->query_form('participant' => $userName ) ; 	

    $logger->info(__PACKAGE__ . ".$sub: URL is $url ") ; 
	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to mute the participant $self->{USER_NAME}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly muted the participant $self->{USER_NAME}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 unmuteCall()

=over

=item DESCRIPTION: 

The function is used to unmute the call for the respective client upon which this subroutine is being called. 

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

    unless ($lyncClient1->unmuteCall()) {
        $logger->error("__PACKAGE__ . ".$subName: call unmute failed");
        return 0;
    }

=back

=cut

sub unmuteCall {
    my $self = @_ ; 
    my $sub = "unmuteCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    my ($userName, $url)  ;
	
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ; 

    $userName = $self->{PREFIX_NAME} . $self->{USER_NAME} . "@" . $self->{USER_DOMAIN}; 
   
    $url  = URI->new("http://$self->{HOST_NAME}:$self->{PORT}/UnMuteParticipant") ;	 
    $url->query_form( 'participant' => $userName) ; 

    $logger->info(__PACKAGE__ . ".$sub: URL is $url ") ; 
	
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to unmute the participant $self->{USER_NAME}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Successfuly unmuted the participant $self->{USER_NAME}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    
    return 1; 
}

=head1 conferenceCall() 

=over

=item DESCRIPTION: 

The function is used to add participents to a conference call

=item ARGUMENTS:

Mandatory Args:
 participants

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

    unless ($lyncClient1->conferenceCall(@participants)) {
        $logger->error("__PACKAGE__ . ".$subName: unable to add conference call to the client");
        return 0;
    }

=back

=cut

sub conferenceCall {
    my ( $self , @participants )  = @_  ;
    my $sub = "conferenceCall" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    my ($url, $call_entity, @numbers) ;
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ") ;

    foreach (@participants) {
        $call_entity = $self->{PREFIX_NUM}.$_->{NUMBER} ;
        $logger->info(__PACKAGE__ . ".$sub: Call Entity is : $call_entity ") ;
        push (@numbers , $call_entity) ;
    }

    $url  =  URI->new("http://$self->{HOST_NAME}:$self->{PORT}/ConferenceCall") ;
    $url->query_form( 'participants' => "@numbers" ) ;

    $logger->info(__PACKAGE__ . ".$sub: URL is $url \n  ") ;

    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to add conference call to the client \'$self->{NUMBER}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Successfuly made the conference call to \'$self->{NUMBER}\'");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");

    return 1;
}

=head1 playMedia() 

=over

=item DESCRIPTION: 

The function is used to mute the call for the respective client upon which this subrutine is being called. 

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

    unless ($lyncClient1->playMedia()) {
        $logger->error("__PACKAGE__ . ".$subName: play media failed");
        return 0;
    }

=back

=cut

sub playMedia {
    my ($self)  = shift ;
    my $subname = "playMedia" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subname") ;
    $logger->debug(__PACKAGE__ . ".$subname: --> Entered Sub");    
    my $url    = "$self->{MediaAppsPath}" . 'play.exe -r 8000 ' . "$self->{InputDataPath}" . 'Allin1.wav -d' ;

    $logger->info(__PACKAGE__ . ".$subname: URL is : $url ");  

    unless ($self->{conn}->cmd($url)) {
        $logger->error(__PACKAGE__ . ".$subname: Unable to play media on skype client");
        $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$subname: Successfuly started playing media on skype client");
    $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [1]");    

    return 1;

}

=head1 startRecordingMedia() 

=over

=item DESCRIPTION: 

The function is used to mute the call for the respective client upon which this subrutine is being called. 

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

    unless ($lyncClient1->startRecordingMedia()) {
        $logger->error("__PACKAGE__ . ".$subName: could not record media on skype client");
        return 0;
    }

=back

=cut

sub startRecordingMedia {
    my ($self) = shift;
    my $subname = "startRecordingMedia" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subname") ;
    $logger->debug(__PACKAGE__ . ".$subname: --> Entered Sub");    

    my $url= "$self->{MediaAppsPath}" . "rec.exe -r 8000 -c 1 -d ".$self->{OutputDataPath}."Music_Skype_Rec.wav" ;

    $logger->info(__PACKAGE__ . ".$subname: URL is : $url ");

    unless ($self->{conn}->print($url)) {
        $logger->error(__PACKAGE__ . ".$subname: Unable to record media on skype client");
        $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$subname: Successfuly started recording media on skype client");
    $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [1]");    

    return 1;

}

=head1 stopRecordingMedia() 

=over

=item DESCRIPTION: 

The function is used to mute the call for the respective client upon which this subrutine is being called. 

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

    unless ($lyncClient1->stopRecordingMedia()) {
        $logger->error("__PACKAGE__ . ".$subName: could not stop recording media on skype client");
        return 0;
    }

=back

=cut

sub stopRecordingMedia{
    my ($self)= shift ;
    my $subname = 'stopRecordingMedia()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subname") ;
    $logger->debug(__PACKAGE__ . ".$subname: --> Entered Sub");    
    
    unless($self->{conn}->cmd(-string => "\cC")){
        $logger->error(__PACKAGE__ . ".$subname: Failed to stop recording media on skype client");
        $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [0]");    
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$subname: Successfuly stoped recording media on skype client");
    $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving Sub [1]");    
    return 1;
} 

=head1 getSkypePesq() 

=over

=item DESCRIPTION: 

The function is used to copy PESQ file from windows machine to BATS server. 

=item ARGUMENTS:

Mandatory Args:
-destFilePath

Optional Args:
None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

PESQ score

=item EXAMPLE:  

    unless ($lyncClient1->getSkypePesq(-destFilePath => $SkyperecWaveFilePath) {
        $logger->error("__PACKAGE__ . ".$subName: Failed to copy PESQ file from windows machine to BATS server");
        return 0;
    }

=back

=cut

sub getSkypePesq {
    my ($self, %args)=@_ ;
    my $destinationFilePath = $args{-destFilePath};
    my %tms_alias = () ; 

    my $subname = "getSkypePesq" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subname") ;
    $logger->debug(__PACKAGE__ . ".$subname: --> Entered Sub");

    $logger->info(__PACKAGE__ . "Copying Files from Windows Server Skype Host to bats server");    

    my $winMachineMediaFilePath = "$self->{HOST_NAME}" . ':' . "$self->{OutputDataPath}" . '*';    

    my %scpArgs = (-hostip              => $self->{HOST_NAME},
                   -hostuser            => $self->{USERID},
                   -hostpasswd          => $self->{PASSWD},
                   -scpPort             => '22',
                   -sourceFilePath      => $winMachineMediaFilePath,
                   -destinationFilePath => $destinationFilePath,
                  );
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$subname: Failed to copy recorded files from skype windows machine to BATS server");
        $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving sub [0]");
        return 0;
    }

    $self->{conn}->cmd("$self->{MediaAppsPath}\\pesq.exe $self->{InputDataPath}\\Allin1.wav $self->{OutputDataPath}\\Music_Skype_Rec.wav +8000 > $self->{OutputDataPath}\\SkypeMOS.txt");

    my $winMachinePesqFilePath = "$self->{HOST_NAME}" . ':' . "$self->{OutputDataPath}" . '*.txt';    

    %scpArgs = (   -hostip              => $self->{HOST_NAME},
                   -hostuser            => $self->{USERID},
                   -hostpasswd          => $self->{PASSWD},
                   -scpPort             => '22',
                   -sourceFilePath      => $winMachinePesqFilePath,
                   -destinationFilePath => $destinationFilePath,
               );

    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$subname: Failed to copy PESQ file from windows machine to BATS server");
        $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving sub [0]");
        return 0;
    }

    my $SkypeMOS = qx#tail -1 $destinationFilePath."/SkypeMOS.txt" | awk -F"=" '{print \$2}' | awk -F" " '{print \$1}'#;        

    $logger->info(__PACKAGE__ . "The Skype Client MOS Score is: $SkypeMOS");

    $logger->debug(__PACKAGE__ . ".$subname: <-- Leaving sub [$SkypeMOS]");    

    return $SkypeMOS;

} 
1;
