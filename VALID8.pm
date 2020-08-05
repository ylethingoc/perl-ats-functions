package SonusQA::VALID8;

=head1 NAME

SonusQA::VALID8 - Perl module for VALID8 automation

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::VALID8->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX, JSON, LWP::UserAgent, LWP::Simple

=head2 AUTHORS

Ravi Kumar Krishnaraj <rkrishnaraj@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

   This module provides an interface for VALID8 interaction. It performs actions on the VALID8 such as loading the application, unloading the application, loading server and client, start/stop server and client, get current state of the application and fetching the report for a run. It requires working testscripts and the application to be created on the VALID8 GUI in advance before launching it through ATS. 


=head1 METHODS

=cut

use SonusQA::Utils qw(:all :errorhandlers :utilities);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use JSON;
use LWP::UserAgent;
use LWP::Simple;
use vars qw($self);
our @ISA = qw(SonusQA::Base);

=head2 new

=over

=item DESCRIPTION:

    Constructor subroutine to create object.

=item EXAMPLE:

    use ATS;
    my $obj = SonusQA::VALID8->new(
                -OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                -OBJ_USER => '<cli user name>',
                -OBJ_PASSWORD => '<cli user password>',
            );

=back

=cut

sub new{
        my ( $class,  %args) = @_;
        my $sub_name = "new";
	my $self = bless {}, $class;
 	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        foreach (keys %args) {
            # #Everything is just assigned back to the object
            my $var = uc($_);
            $var =~ s/^-//i;
            $self->{$var} = $args{$_};
        }
	&error(__PACKAGE__ . ".new Mandatory \"-obj_host\" parameter not provided") unless $self->{OBJ_HOST};
        $self->doInitialization(%args);
        $logger->info(__PACKAGE__ . ".new Connection Information:");
        $self->descSelf();
	push (@cleanup, $self);
        return $self;
}

=head2 doInitialization

=over

=item DESCRIPTION:

    Routine to set object defaults.

=back

=cut

sub doInitialization {
    my $self = shift;
    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->agent("MyApp/0.1 ");
    $self->{COMMTYPES}          = ["NONE"];
    $self->{TYPE}               = __PACKAGE__;
    $self->{OBJ_USER}           = "user"; # OBJ_USER and OBJ_PASSWORD are not necessary. We are setting htem here anyway just not to leave their output blank in descSelf
    $self->{OBJ_PASSWORD}       = "user";
    $self->{json} = JSON->new->allow_nonref;
}

=head2 unloadApplication

=over

=item DESCRIPTION:

    Routine to unload application.
    It will send http delete rquest to unload the application.
    $$self->{ua}->request( HTTP::Request->new(DELETE => 'http://'.$self->{OBJ_HOST}.'/api/1/application') );

=item ARGUMENTS:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub unloadApplication {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "unloadApplication";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Unloading application.. ");
    # Create a request
    $self->{request} = HTTP::Request->new(DELETE => 'http://'.$self->{OBJ_HOST}.'/api/1/application');
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 10 seconds."); # We need to give a delay here. If we do not then subsequent subroutine calls will fail.
    sleep 10; # Unloading the application takes about 5-7 seconds. Let's sleep for 10 seconds to be on the safer side.
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Unload application SUCCESSFUL ");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");	
	return 1;
    }
    else {
	$logger->debug(__PACKAGE__ . ".$sub_name: Unload application failure. ".$self->{result}->status_line);
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return 0;
    }
}

=head2 loadApplication

=over

=item DESCRIPTION:

    To load given application.
    It will send http put request to load application.
    $self->{ua}>request( HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/application/'.$application) );

=item ARGUMENTS:

    -application 

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub loadApplication {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "loadApplication";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless( defined $args{-application} ){
	$logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-application' is missing ");
	return 0;
    }
    my $application = $args{-application};
    unless($application =~ /(H323)|(SIP)|(VoIP)/){
	$application = "VoIP/Interworking/".$application;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Loading application : '$application' ");
    # Create a request
    $self->{request} = HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/application/'.$application);
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 30 seconds."); #We need to give a delay here. If we do not, then the subsequent subroutine calls will fail.
    sleep 30; # loading the application takes over 20 seconds. Let's sleep for 30 seconds to be on the safer side.
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load application SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load application failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return 0;
    }
}

=head2 loadClient

=over

=item DESCRIPTION:

    To load client.
    It will send http post request with the testcases data.

    my $req =  HTTP::Request->new( 'POST', 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/campaign' );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( '{"port":0,"testSuite":"'.$args{-testSuite}.'", "testCases":["'.$testCases.'"]  }' );
    $req->method('PUT');
    $self->{result} = $self->{ua}->request(HTTP::Request->new( $req );

=item ARGUMENTS:

    -testSuite
    -testCases : hash reference or array reference or scalar

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub loadClient {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "loadClient";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless( defined $args{-testSuite} ){
	$logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-testSuite' is missing ");
	return 0;
    }
    unless( defined $args{-testCases} ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-testCases' is missing ");
        return 0;
    }
    my (@testCases,$testCases);
    if( ref $args{-testCases} eq "HASH" ){
	while( my ($key,$value) = each (%{$args{-testCases}})){
	    for my $testcase (@$value){
		push (@testCases, $key."/".$testcase);
	    }
	}
	$testCases  = join ( ',' ,@testCases);
    }elsif(  ref $args{-testCases} eq "ARRAY" ){
	$testCases  = join ( ',' , @{$args{-testCases}} );
    }else{
        $testCases  = join ( ',' , $args{-testCases} );
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Loading the client to run the following testcases: ".Dumper($args{-testCases}));
    my $uri = 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/campaign';
    my $json = '{"port":0,"testSuite":"'.$args{-testSuite}.'", "testCases":["'.$testCases.'"]  }';
    # Create a request
    $self->{request} = HTTP::Request->new( 'POST', $uri );
    my $req = $self->{request};
    my $ua = $self->{ua};
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( $json );
    $req->method('PUT');
    #$logger->debug(__PACKAGE__ . ".$sub_name: REQUEST : ".$req->as_string);
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load client SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load client failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 loadServer

=over

=item DESCRIPTION:

    To load server.
    It will send http post request with the testcases data.

    $self->{request} = HTTP::Request->new( 'POST', 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/campaign' );
    my $req = $self->{ HTTP::Request->new( 'POST', 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/campaign' ) };
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( '{"port":0,"testSuite":"'.$args{-testSuite}.'", "testCases":["'.$testCases.'"]  }' );
    $req->method('PUT');
    $self->{result} = $self->{ua}->request($req);

=item ARGUMENTS:

    -testSuite
    -testCases : hash reference or array reference or scalar

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub loadServer {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "loadServer";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my (@testCases,$testCases);
    if( ref $args{-testCases} eq "HASH" ){
        while( my ($key,$value) = each (%{$args{-testCases}})){
            for my $testcase (@$value){
                push (@testCases, $key."/".$testcase);
            }
        }
        $testCases  = join ( ',' ,@testCases);
    }elsif(ref $args{-testCases} eq "ARRAY" ){
        $testCases  = join ( ',' , @{$args{-testCases}} );
    }else{
	$testCases  = join ( ',' , $args{-testCases} );
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Loading the server to run the following testcases: ".Dumper($args{-testCases}));
    my $uri = 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/campaign';
    my $json = '{"port":0,"testSuite":"'.$args{-testSuite}.'", "testCases":["'.$testCases.'"]  }';
    # Create a request
    $self->{request} = HTTP::Request->new( 'POST', $uri );
    my $req = $self->{request};
    my $ua = $self->{ua};
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( $json );
    $req->method('PUT');
    #$logger->debug(__PACKAGE__ . ".$sub_name: REQUEST : ".$req->as_string);
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($req);
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load server SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Load server failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 startServer

=over

=item DESCRIPTION:

    To start server.
    It will send http put request to start server.

    $self->{result} = $self->{ua}->request(HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/start'));

=item ARGUMENTS:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub startServer {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "startServer";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Starting the server..");
    # Create a request
    $self->{request} = HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/start');
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 5 seconds.."); #We need to give a delay here to ensure that the server is running before the client starts. If we do not, then the subsequent startClient subroutine call will fail.
    sleep 5;
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Start server SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Start server failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 startClient

=over

=item DESCRIPTION:

    To start client.
    It will send http put request to start client.

    $self->{result} = $self->{ua}->request(HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/start'));

=item ARGUMENTS:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub startClient {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "startClient";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Starting the client..");
    # Create a request
    $self->{request} = HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/start');
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Start client SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Start client failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 stopClient

=over

=item DESCRIPTION:

    To stop client.
    It will send http put request to stop client.

    $self->{result} = $self->{ua}->request(HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/stop'));

=item ARGUMENTS:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub stopClient {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "stopClient";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Stopping the client..");
    # Create a request
    $self->{request} = HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/client/stop');
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Stop client SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Stop client failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 stopServer

=over

=item DESCRIPTION:

    To stop server.
    It will send http put request to stop server.

    $self->{result} = $self->{ua}->request(HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/stop'));

=item ARGUMENTS:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=back

=cut

sub stopServer {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "stopServer";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Stopping the server..");
    # Create a request
    $self->{request} = HTTP::Request->new(PUT => 'http://'.$self->{OBJ_HOST}.'/api/1/control/server/stop');
    my $ua = $self->{ua};
    # Pass request to the user agent and get a response back
    $self->{result} = $ua->request($self->{request});
    # Check the outcome of the response
    if ($self->{result}->is_success ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Stop server SUCCESSFUL ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Stop server failure. ".$self->{result}->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
}

=head2 getState

=over

=item DESCRIPTION:

    To get state.
    It will send http get request to get the state.

    $self->{result} = get("http://".$self->{OBJ_HOST}."/api/1/state");

=item ARGUMENTS:

    None

=item RETURNS:

    state - Success
    0 - Failure

=back

=cut

sub getState {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "getState";
    my  $result;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Fetching the current state of the application..");
    #get state
    unless( $self->{result} = get("http://".$self->{OBJ_HOST}."/api/1/state")){
        $logger->debug(__PACKAGE__ . ".$sub_name: Encountered failure while trying to get the state. ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else{
 	$result = $self->{json}->decode($self->{result});	
	$logger->debug(__PACKAGE__ . ".$sub_name: STATE : ".Dumper($result));
	return $result;
    }
}

=head2 getReport

=over

=item DESCRIPTION:

    To get report.
    It will send http get request to get the report.

    $self->{result} = get("http://".$self->{OBJ_HOST}."/api/1/report")

=item ARGUMENTS:

    None

=item RETURNS:

    report - Success
    0 - Failure

=back

=cut

sub getReport {
    my  ($self, %args ) = @_ ;
    my  $sub_name = "getReport";
    my  $report;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Getting the report from the application..");
    #get state
    unless( $self->{result} = get("http://".$self->{OBJ_HOST}."/api/1/report")){
        $logger->debug(__PACKAGE__ . ".$sub_name: Encountered failure while trying to get the report. ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }else{
	$report = $self->{json}->decode($self->{result});
	$logger->debug(__PACKAGE__ . ".$sub_name: REPORT : ".Dumper($report));
	return $report;
    }
}

1;
