package SonusQA::LYNCSERVER ; 

use strict ; 
use warnings ; 
use Log::Log4perl qw(get_logger :easy) ; 
use Data::Dumper ; 
use LWP::UserAgent ; 

our $VERSION = "1.0" ; 
use vars qw($self) ; 

sub new {
    my ($class , %args) = @_ ; 
    my %tms_alias = () ; 
    my $sub = "new" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->debug(__PACKAGE__ . ".$sub --> Entered sub ") ; 

    my $alias = $args{-tms_alias_name} ; 
    my $tms_alias = &SonusQA::Utils::resolve_alias($alias) ; 

    my $self = { HOST_NAME => $tms_alias->{NODE}->{1}->{IP}, 
                 PORT => $tms_alias->{NODE}->{1}->{PORT}, 
                 GATEWAY => $tms_alias->{NODE}->{1}->{GATEWAY},
     } ; 

     bless $self, $class ; 
  
     unless($self->doInitialization(%args)){
        $logger->error(__PACKAGE__ . ".$sub: Failure while Initialising the values in LYNCSERVER.");
        return 0 ;
     }

     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1] ")  ;
     return $self ;  
}

sub doInitialization {
    my ($self , %args) = @_ ; 
    my $sub = "doInitialization" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 

    $self->{GATEWAY_PSTN} = "PstnGateway"."%3a".$self->{GATEWAY} ; 
    $self->{DEFAULT_IDENTITY} = "Global" ; 

    ## checking whether connection is live or not ;     
    my $params = "identity=$self->{DEFAULT_IDENTITY}" ; 
    my $action = "TestConnection" ; 
    my $url    = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params"; 
    
    unless ($self->performAction($url)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable To check the connection status of server"); 
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ($self->{CONTENT} =~ /established/) {
        $logger->error(__PACKAGE__ . ".$sub : Connection with server doesn't exist, check the server settings");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;

    } else {
        $logger->info(__PACKAGE__ . ".$sub : <-- Connection is successfully connected"); 
    }    
    return 1 ; 

}

sub performAction {
    my ($self , $url ) = @_ ; 
    my $sub = 'performAction' ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub"); 

    my $lwp ; 
    unless (defined $lwp) { 
        $lwp = new LWP::UserAgent ;    
    } 
    
    $logger->info(__PACKAGE__ . ".$sub: URL is : \'$url\' ");
    my $response = $lwp->get($url) ; 
  
    # getting response code and response content 
    my $response_code = $response->code() ;
    $logger->info(__PACKAGE__ . ".$sub: --> Response code is : $response_code " ); 

    my $response_content = $response->content() ;
    $logger->info(__PACKAGE__ . ".$sub: --> Response content is : $response_content " );

    $self->{CONTENT} = $response_content ; 

    unless ( $response_code == 200 ) {
        $logger->error(__PACKAGE__ . ".$sub : ERROR ::  Expected 200 OK response -but got $response_code");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub : Required action performed successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return 1;
}

=head1 getSRTPMode()

=over

=item DESCRIPTION:

It is used to get the SRTP mode of the lync server.   

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

$self->{CONTENT}   ::  mode value 
0 - Failure

=item EXAMPLE: 

unless ($status =  $lyncServer->getSRTPMode()) {
    $logger->error("__PACKAGE__ . ".$subName: failed to get SRTP mode");
    return 0;
}

=back

=cut


sub getSRTPMode {
    my $self = shift ;  
    my $sub = "getSRTPMode" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ") ; 
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub" ) ; 

    my $action = "GetSRTPMode" ; 
    my $params = "identity=$self->{GATEWAY_PSTN}" ;  
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ; 

    unless ($self->performAction($url) and $self->{CONTENT} =~ /Required|Optional|NotSupported/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to get SRTP Mode") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub : Successfuly Got SRTP Mode : $self->{CONTENT}");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return $self->{CONTENT} ;    
}

=head1 setSRTPMode()

=over

=item DESCRIPTION:

It is used to set the SRTP mode of the lync server. The following options can be given as parameter : 
- Optional 
- NotSupported 
- Required 
 

=item ARGUMENTS:

Mandatory Args:
$mode - the value of the srtp mode to be set. (The available modes are mentioned in description).

Optional Args:
None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS: 

1 - success
0 - Failure

=item EXAMPLE: 

unless ($lyncServer->setSRTPMode($mode)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to set the SRTP mode");
    return 0;
}

=back

=cut

sub setSRTPMode {
    my ($self, $mode) = @_ ;  
    my $sub = "setSRTPMode"  ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ") ; 
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub" ) ;
    
    unless (defined $mode && ($mode !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Mode\' not defined ") ; 
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]"); 
         return 0 ; 
    }
 
    my $action = "SetSRTPMode" ; 
    my $params = "identity=$self->{GATEWAY_PSTN}&SRTPMode=$mode" ; 
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ; 

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to set the SRTP Mode") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub : Set SRTP mode successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    $logger->debug(__PACKAGE__ . ".$sub : Waiting for 70 seconds for Lync server to come up ...............");
    sleep (70);

    return 1;

}
=head1 getRefer()

=over

=item DESCRIPTION:

It retrieves the status of REFER support (true or false). 

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

$self->{CONTENT}   ::  REFER support value. 
0 - Failure

=item EXAMPLE: 

unless ($status =  $lyncServer->getRefer()) {
    $logger->error("__PACKAGE__ . ".$subName: failed to get REFER mode");
    return 0;
}

=back

=cut

sub getRefer {
    my $self = shift ;
    my $sub = "getRefer" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub" ) ;

    my $action = "GetRefer" ;
    my $params = "identity=$self->{GATEWAY_PSTN}" ;
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) and $self->{CONTENT} =~ /True|False/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to get Refer status") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Successfuly Got Refer Mode : $self->{CONTENT}");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return $self->{CONTENT} ;     

}  

=head1 setRefer ()

=over

=item DESCRIPTION:

It is used to set the REFER support of the lync server. The following options can be given as parameter : 
- True
- False
 

=item ARGUMENTS:

Mandatory Args:
$value  : the value of the REFER support to be set. (The available values are mentioned in description).

Optional Args:
None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS: 

1 - success
0 - Failure

=item EXAMPLE: 

unless ($lyncServer->setRefer($mode)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to set the REFER mode");
    return 0;
}

=back

=cut

sub setRefer {
    my ($self , $value) = @_ ; 
    my $sub = "setRefer" ;  
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub ") ;  

    unless (defined $value && ($value !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Value for REFER\' not defined ") ;
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0 ;
    }

    my $action = "SetRefer" ;
    my $params = "identity=$self->{GATEWAY_PSTN}&refer_support_true_or_false=$value" ; 
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to set the value for REFER") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : REFER Value Set successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    $logger->debug(__PACKAGE__ . ".$sub : Waiting for 70 seconds for Lync server to come up ...............");
    sleep (70);
    return 1;
}

=head1 getMusicOnHold()

=over

=item DESCRIPTION:

It is used to get the Music on hold status of the lync server.(values retrieved will be either true or false )

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

$self->{CONTENT}   ::  mode value 
0 - Failure

=item EXAMPLE: 

unless ($status =  $lyncServer->getMusicOnHold()) {
    $logger->error("__PACKAGE__ . ".$subName: failed to get Music on hold status");
    return 0;
}

=back

=cut

sub getMusicOnHold {
    my $self = shift ;
    my $sub = "getMusicOnHold" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub" ) ;

    my $action = "GetMusicOnHold" ; 
    my $params = "identity=$self->{DEFAULT_IDENTITY}" ;
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) and $self->{CONTENT} =~ /True|False/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to get Music on hold status") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Successfuly Got Music on hold status : $self->{CONTENT}");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return $self->{CONTENT} ;
}

=head1 setMusicOnHold ()

=over

=item DESCRIPTION:

It is used to set the Music on hold status of the lync server. The following options can be given as parameter : 
- True
- False
 

=item ARGUMENTS:

Mandatory Args:
$value  : the value of the Music on hold to be set. (The available values are mentioned in description).

Optional Args:
None

=item PACKAGES USED:

 None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS: 

1 - success
0 - Failure

=item EXAMPLE: 

unless ($lyncServer->setMusicOnHold($value)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to set the REFER mode");
    return 0;
}

=back

=cut

sub setMusicOnHold {
    my ($self , $value) = @_ ;
    my $sub = "setMusicOnHold" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub ") ;

    unless (defined $value && ($value !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Value for MusicOnHold\' not defined ") ;
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0 ;
    }

    my $action = "SetMusicOnHold" ; 
    my $params = "identity=$self->{DEFAULT_IDENTITY}&media_on_hold_true_or_false=$value" ;
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to set the value for Music on Hold") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Music on hold Value Set successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    $logger->debug(__PACKAGE__ . ".$sub : Waiting for 70 seconds to Lync server come up ...............");
    sleep (70);
    return 1;

}

=head1 getMediaBypass()

=over

=item DESCRIPTION:

It is used to get the Media by pass status of the lync server. (value will be either true or false).

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

$self->{CONTENT}   ::  mode value 
0 - Failure

=item EXAMPLE: 

unless ($status =  $lyncServer->getMediaBypass()) {
    $logger->error("__PACKAGE__ . ".$subName: failed to get media by pass mode");
    return 0;
}

=back

=cut

sub getMediaBypass {
    my $self = shift ;
    my $sub = "getMediaBypass" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub" ) ;

    my $action = "GetMediaBypass" ; 
    my $params = "identity=$self->{GATEWAY_PSTN}" ; 
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) and $self->{CONTENT} =~ /True|False/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to get Media by pass status") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Successfuly Got Media by pass status : $self->{CONTENT}");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return $self->{CONTENT} ;
}

=head1 setMediaBypass()

=over

=item DESCRIPTION:

It is used to set the Media by pass status of the lync server. The following options can be given as parameter : 
- True
- False

=item ARGUMENTS:

Mandatory Args:
$mode - the value of the media by pass status to be set. (The available modes are mentioned in description).

Optional Args:

None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - success
0 - Failure

=item EXAMPLE:

unless ($lyncServer->setMediaBypass($value)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to set Media by pass status");
    return 0;
}

=back

=cut

sub setMediaBypass {
    my ($self , $value) = @_ ;
    my $sub = "setMediaByPass" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub ") ;

    unless (defined $value && ($value !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Value for Media By Pass\' not defined ") ;
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0 ;
    }

    my $action = "SetMediaBypass"  ;
    my $params = "identity=$self->{GATEWAY_PSTN}&media_bypass_true_or_false=$value" ;
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to set the value for Media By Pass") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Media By Pass Value Set successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    $logger->debug(__PACKAGE__ . ".$sub : Waiting for 70 seconds to Lync server come up ...............");
    sleep (70);
    return 1;

}

=head1 startMediationServer()

=over

=item DESCRIPTION:

This subroutine starts the mediation server by taking the computer name as the parameter.  

=item ARGUMENTS:

Mandatory Args:
=>  $computerName - name of the computer for mediation server.

Optional Args:

None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS: 

1 - success
0 - Failure

=item EXAMPLE: 

unless ($lyncServer->startMediationServer($computerName)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to start the mediation server");
    return 0;
}

=back

=cut

sub startMediationServer {
    my ($self , $computerName) = @_ ;
    my $sub = "startMediationServer" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub ") ;

    unless (defined $computerName && ($computerName !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Computer Name\' not defined ") ;
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0 ;
    }

    my $action = "StartMediationServer"  ; 
    my $params = "ComputerName=$computerName" ; 
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to start Mediation Server") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Mediation Server started successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return 1;
}

=head1 stopMediationServer()

=over

=item DESCRIPTION:

This subroutine stops the mediation server by taking the computer name as the parameter.  

=item ARGUMENTS:

Mandatory Args:
=>  $computerName - name of the computer for mediation server.

Optional Args:

None

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS: 

1 - success
0 - Failure

=item EXAMPLE: 

unless ($lyncServer->stopMediationServer($computerName)) {
    $logger->error("__PACKAGE__ . ".$subName: failed to stop the mediation server");
    return 0;
}

=back

=cut

sub stopMediationServer {
    my ($self , $computerName) = @_ ;
    my $sub = "stopMediationServer" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    $logger->debug(__PACKAGE__ . ".$sub : Entered Sub ") ;

    unless (defined $computerName && ($computerName !~ /^\s*$/)) {
         $logger->error(__PACKAGE__ . ".$sub : Mandatory Parameter \'Computer Name\' not defined ") ;
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0 ;
    }

    my $action = "StopMediationServer"  ;
    my $params = "ComputerName=$computerName" ;
    my $url = "http://$self->{HOST_NAME}:$self->{PORT}/$action?$params" ;

    unless ($self->performAction($url) && $self->{CONTENT} =~ /\{1\}/) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to stop Mediation Server") ;
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]") ;
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : Mediation Server stopped successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");

    return 1;

}


1; 





























