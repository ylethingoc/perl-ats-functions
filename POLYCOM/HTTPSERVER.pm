package SonusQA::POLYCOM::HTTPSERVER;

=head1 NAME

SonusQA::POLYCOM::HTTPSERVER - Perl module for Polycom Httpserver control

=head1 DESCRIPTION

This module provides an interface for the POLYCOM  test tool.

=head1 METHODS

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use SonusQA::POLYCOM;
use vars qw($http_server_status $runHttpServer $thr  $client_socket $socket );
use threads;
use threads::shared;
our $http_server_status :shared;
our (%polycomObjects);
our (%polycomObjectsData);
share (%polycomObjectsData);
share (%polycomObjects);
our ($thr);
use Log::Log4perl qw(get_logger :easy);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT =  qw( %polycomObjects $http_server_status $thr %polycomObjectsData);
our ($HTTP_SERVER_IP,$HTTP_SERVER_PORT) :shared;

=head2 SonusQA::POLYCOM::HTTPSERVER::getHttpServerInstance()

  This function creates a thread to run Http Server

=over

=item Arguments

  HTTP_SERVER_IP_TEMP   -  Http Server Ip
  HTTP_SERVER_PORT_TEMP -  Http Server Port

=item Returns

  1 - thread is created or already running
  0 - thread failed to create

=back

=cut

sub getHttpServerInstance{
	my $sub_name = "getHttpServerInstance";
	my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	my ($HTTP_SERVER_IP_TEMP, $HTTP_SERVER_PORT_TEMP) = @_;
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	unless($http_server_status == 1){
		unless($thr = threads->create(\&runHttpServer,$HTTP_SERVER_IP_TEMP, $HTTP_SERVER_PORT_TEMP)){
			$logger->error(__PACKAGE__ . ".$sub_name: Unable to run the http server ");
			$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			return 0;
		}
		$logger->debug(__PACKAGE__ . ".$sub_name: Created a thread to run http server. Server IP: $HTTP_SERVER_IP_TEMP PORT: $HTTP_SERVER_PORT_TEMP");
		$http_server_status = 1;
	}else{
		$logger->debug(__PACKAGE__ . ".$sub_name: The http server is already running. Server IP: $HTTP_SERVER_IP_TEMP PORT: $HTTP_SERVER_PORT_TEMP");
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return $http_server_status;

}	

=head2 SonusQA::POLYCOM::HTTPSERVER::getHttpServerInstance()

  creating object interface of IO::Socket::INET modules which internally does
  socket creation, binding and listening at the specified port address.

=over

=item Argumnets

  HTTP_SERVER_IP_TEMP   - http server ip
  HTTP_SERVER_PORT_TEMP - http server port

=item Returns

  Nothing

=back

=cut

sub runHttpServer{

	$| = 1;
	$http_server_status = 1;
	my $sub_name = "runHttpServer";
	my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	my ($HTTP_SERVER_IP_TEMP, $HTTP_SERVER_PORT_TEMP) = @_;
	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	# creating object interface of IO::Socket::INET modules which internally does
	# socket creation, binding and listening at the specified port address.
	my $HTTP_SERVER_IP = $HTTP_SERVER_IP_TEMP;
	my $HTTP_SERVER_PORT = $HTTP_SERVER_PORT_TEMP;

	eval{
		$socket = new IO::Socket::INET (
				LocalHost => $HTTP_SERVER_IP,
				LocalPort => $HTTP_SERVER_PORT,
				Proto => 'tcp',
				Listen => 5,
				Reuse => 1
				) or die ("Error in socket creation : $!");
	};

	if($@){
		$logger->error(__PACKAGE__ . ".$sub_name: ERROR: $@ ");
		die;
	}
	$http_server_status = 1;
	$logger->debug(__PACKAGE__ . ".$sub_name: SERVER waiting for client connection on port $HTTP_SERVER_PORT");

ACCEPT: while(1)
	{
		last if(scalar( keys %polycomObjects) == 0);
		$logger->debug(__PACKAGE__ . ".$sub_name: Waiting in accept() ...");
        	# waiting for new client connection.
		$client_socket = $socket->accept();
		&SonusQA::POLYCOM::handleResponse($client_socket);
		next ACCEPT;
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: Terminating HTTP server..");
	$http_server_status = 0;
	$socket->close();
}

1;
