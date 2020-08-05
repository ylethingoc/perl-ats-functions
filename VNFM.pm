package SonusQA::VNFM;

=head1 NAME

SonusQA::VNFM - Perl module for RESTAPI interaction

=head1 SYNOPSIS

use ATS;   

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, Data::Dumper,LWP::UserAgent, HTTP::Response, HTTP::Request::Common, HTTP::Cookies

=head1 DESCRIPTION

   This module provides the interface for rest API call for VNFM object.

=head1 AUTHORS

The <SonusQA::VNFM> module has been created by Naresha Venkatasubramani (nvenkatasubramani@sonusnet.com).

=head1 METHODS

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common qw(POST GET PUT DELETE);
use HTTP::Cookies;
use Data::Dumper;
use JSON qw( encode_json decode_json);

use SonusQA::Utils qw (:all);

=head2 new()

=over

=item DESCRIPTION:

This function creates the object of SonusQA::VNFM and login in to VNF Manager.

=item ARGUMENTS:

Specific to new:
-username => username for VNFM login ,
-password => password for VNFM login ,
-loginurl => URL for VNFM login,
-logouturl => URL for VNFM logout,
-baseurl => base URL like - http://172.23.243.84:8080/ ,
-bodyParam => username and password in the below format.

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None 

=item RETURNS:

$self  -  vnfm object if successful 
exit   -  otherwise

=item EXAMPLE:

    my $vnfmObj = SonusQA::VNFM->new(-username => $uname ,
                                        -password => $passwd ,
                                        -loginurl => $loginurl,
                                        -logouturl => $logouturl,
                                        -baseurl => $baseURL ,
                                        -bodyParam => "Username=$uname" . "&Password=$passwd");

=back

=cut

sub new {
    my ($class , %args) = @_ ;  
    my $sub = "new" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ") ;
 
    my $self; 
    foreach (keys %args) {
        my $var = uc($_);
        $var =~ s/^-//i;
        $self->{$var} = $args{$_};
    }
    $self->{OBJ_HOST} = $args{-ip} if(exists $args{-ip} and $args{-ip});
    bless $self, $class ; 
        
    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
    $ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    $self->{COOKIE_JAR} =  $cookie_jar;
    $self->{UA} = $ua;
	$self->{BASEURL} = "https://$self->{OBJ_HOST}:$self->{PORT}/"; #TOOLS-19433
    unless($self->login($args{-username}, $args{-password})){
        $logger->error(__PACKAGE__ . ".$sub: Failure while logging ");
        $logger->error(__PACKAGE__ . " $sub: object creation failed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [exit]"); 
	exit ;
    }
 
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return $self;
} 

=head2 login()

=over

=item DESCRIPTION:

This function is used for login in to VNF Manager.

=item ARGUMENTS:

$username   - username for login 
$password   - password for login 

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0   -  if login fails
1   -  if login successful

=item EXAMPLE:

    $vnfmObj->login($username, $password)

=back

=cut

sub login {
    my ($self, $username, $password) = @_;
    my $sub = "login";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    my ( $request, $response ) ;

    $request = POST "$self->{BASEURL}/vnfm-ui", [ username => $username, password => $password];
    $self->{COOKIE_JAR}->add_cookie_header( $request );
    $response = $self->{UA}->request( $request );
    
    unless ( $response->{_rc} == 302 ) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to login");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
 
    $self->{COOKIE_JAR}->extract_cookies( $response );

    $logger->info(__PACKAGE__ . ".$sub: login successful");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}
													   
=head2 processRequest()

=over

=item DESCRIPTION:

This function is used to execute any rest API.

=item ARGUMENTS:

-method      - HTTP operation type ( like GET, POST etc )
-url         - rest API
-accept      - API accept header
-contenttype - API contenttype header
-output      - Return the decoded JSON response _content as a reference.

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - if fails
1 - if success

=item EXAMPLE:

    $vnfmObj->processRequest(-method => "GET",-url => "CloudMgr/v1/gui/vim/nfvstatus", -accept => 'application/json' );

=back

=cut

sub processRequest {
    my ($self, %args) = @_;
    my $sub = "processRequest";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    unless ( $args{-url} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument URL is not passed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $args{-accept} ||= 'application/json';
    $args{-contenttype} ||= 'application/json';

    my ($request , $response);
    $logger->debug(__PACKAGE__ . ".$sub: Performing $args{-method} Request");
    if($args{-method} eq "GET"){
        $request = GET $self->{BASEURL}."$args{-url}";
    }elsif($args{-method} eq "PUT"){
        $request = PUT $self->{BASEURL}."$args{-url}";
    }elsif($args{-method} eq "POST"){
        $request = POST $self->{BASEURL}."$args{-url}";
    }elsif($args{-method} eq "DELETE"){
        $request = DELETE $self->{BASEURL}."$args{-url}";
    }else{
        $logger->debug(__PACKAGE__ . ".$sub: Invalid $args{-method} Request");
        $logger->debug(__PACKAGE__ .". $sub: <-- Leaving sub [0]");
        return 0;
    }
    $request->header('Content-Type' => 'application/json');
    $request->header('Accept' => 'application/json');
    if($args{-bodyParam}){
        my $json = encode_json($args{-bodyParam});
        $request->content($json);
    }

    $self->{COOKIE_JAR}->add_cookie_header( $request );
    $response = $self->{UA}->request( $request );

    $logger->debug(__PACKAGE__ .". $sub: Executed Rest API $args{-method} URL : ".$self->{BASEURL}."/$args{-url}");
    $self->{RESPONSE} = $response ;

    my $content = decode_json($self->{RESPONSE}->{_content}) if($args{-output});
    my $result  = ($self->{RESPONSE}->{_rc} =~ /^2\d{2}$/)?1:0; #TOOLS-18463 - Made all 2xx response as success 
    $logger->debug(__PACKAGE__ .". $sub: Response code is $self->{RESPONSE}->{_rc}");
    $logger->debug(__PACKAGE__ .". $sub: <-- Leaving sub [$result]");
    return ($result,$content);
}

=head2 logout()

=over

=item DESCRIPTION:

This function is used to logout.

=item ARGUMENTS:

none

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0   -  if logout fails
1   -  if logout successful

=item EXAMPLE:

    $vnfmObj->logout()

=back

=cut

sub logout {
    my $self = shift;
    my $sub = "logout";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    my ($request, $response);  

    $request = GET "$self->{BASEURL}/CloudMgr/logout";
    $response = $self->{UA}->request( $request );
   
    unless( $response->{_rc} == 200 or $response->{_previous}->{_rc} == 302 ) {
        $logger->error(__PACKAGE__ . "Failed to do logout from VNFM manager");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 DESTROY()

=over

=item DESCRIPTION:

This function is used to Destroy the VNFM object created.

=item ARGUMENTS:

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1   

=item EXAMPLE:

    $vnfmObj->DESTROY();

=back

=cut

sub DESTROY {
    my $self = shift;
    my $sub = 'DESTROY';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    $logger->debug(__PACKAGE__ . ".$sub: Logging out ");
    $self->logout();

    my $vmCtrlAlias = $self->{TMS_ALIAS_DATA}->{VM_CTRL}->{1}->{NAME};
    $vm_ctrl_obj{$vmCtrlAlias}->deleteInstance($self->{'CE_NAME'}) if ($vmCtrlAlias and !$self->{DO_NOT_DELETE});

    $logger->debug(__PACKAGE__ . ".$sub: [$self->{OBJ_HOST}] Destroyed object");
    undef $self;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}
1;
