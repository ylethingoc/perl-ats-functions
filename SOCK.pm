package SonusQA::SOCK;

=head1 NAME

SonusQA::SOCK - SonusQA SOCK class

=head1 SYNOPSIS

use SonusQA::SOCK;

=head1 DESCRIPTION

SonusQA::SOCK a class that wraps IO::Socket::INET for our own custom uses. The current use is to enable ATS callbacks from remote machines where there is no other option ie. from a CLI. The basic premise is to create a "new" object using SonusQA::SOCK->new which will open a reusable tcp LISTEN port based on the port number passed in. From this the user can call a read port will basically wraps the $sock->accept() method. While this is open data can be read until the input separator is hit (newline in this case) then while the read port exists data can be passed back as a simple handshake.

It is not the aim to pass complex and/or large amounts of data through this mechanism.

=head1 AUTHORS

The <SonusQA::SOCK> module has been hacked together by Stuart Congdon (scongdon@sonusnet.com). Standard disclaimers apply ;-)

=head1 METHODS

=cut

use IO::Socket;
use Socket;
use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use SonusQA::Utils qw (:all);
use Sys::Hostname;
use Switch;
use strict;
use English;

=head1 new()

 DESCRIPTION: 
  This subroutine creates an object (class: SonusQA::SOCK) that opens a reusable tcp LISTEN port using IO::Socket::INET and stores the reference in $self->{LISTEN}. The port number that has been passed in is store in $self->{PORT}. The port is opened with a default timeout for read/write operations of 10 seconds. This can be overridden using -timeout.

=over

=item ARGUMENTS:
  -port      - Mandatory port on which to open LISTEN socket.
 [ -timeout ] - Optional timeout value for read/write operations. 

=item PACKAGE:
 SonusQA::SOCK

=item EXTERNAL FUNCTIONS USED:
 IO:Socket::INET::new()
 Socket::inet_ntoa

=item OUTPUT:
     $self - Socket object (ref type: SonusQA::SOCK) with:
     $self->{LISTEN} - LISTEN port (ref type: IO::Socket::INET)
     $self->{PORT}   - port number of LISTEN port
     0     - otherwise, to indicate failure.

=back

=cut

sub new {

    my ($class, %args) = @_;

    my $sub_name = "new";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $self = bless {}, $class;

    $self->{PORT} = $args{ '-port' };
    if ( $self->{PORT} !~ /^\d+/ ) { 
        $logger->error(__PACKAGE__ . ".$sub_name:  Value passed in as a value for local port is not defined or not a number: \'$self->{PORT}\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $self->{LISTEN} = IO::Socket::INET->new( 
                                                 LocalAddr   => inet_ntoa(INADDR_ANY),
                                                 LocalPort   => $self->{PORT},
                                                 Proto       => 'tcp',
                                                 Listen      => SOMAXCONN,
                                                 ReuseAddr   => 1,
                                                 Timeout     => 10,
                                                );

    unless ( $self->{LISTEN} ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to open socket--\n$!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully opened LISTEN port $self->{PORT}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [obj:sock]");
    return $self;
}

=head1 readFromRemote()

 DESCRIPTION: 
  This sub opens a read port connection via $socket->accept(), this connection is stored on the socket object as $socket->{READ_WRITE}. Data is read until either the read operation times out or the input record separator is hit. After a successful read function returns the data that has been read.

=over

=item ARGUMENTS:

[ -timeout ] - Optional timeout value for read/write operations. 

=item PACKAGE:
 SonusQA::SOCK

=item EXTERNAL FUNCTIONS USED:

 Socket::sockaddr_in
 Socket::inet_ntoa
 IO::Socket::timeout
 IO::Socket::accept

=item OUTPUT:

 $data - data read from read port 
 0     - otherwise, to indicate failure.

=back

=cut

sub readFromRemote {

    my $sub_name = "readFromRemote";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my ($self, %args) = @_;

    my $socket = $self->{LISTEN};

    my $timeout = $args{ "-timeout"};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Get type of pointer to ensure its a socket
    my $ref = ref( $socket );

    unless ( defined $socket && $ref =~ /IO::Socket::INET/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Object passes in is not defined as a socket: $socket");
        $logger->error(__PACKAGE__ . ".$sub_name:  Type found is \"$ref\", it should be IO::Socket::INET");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $previous_timeout_value;

    if ( $timeout ) {
        # Ensure timeout is a number and not 0 
        if ( $timeout !~ /^\d+/ or $timeout == 0 ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Value passed in as a value for timeout is not defined or is zero: \'$timeout\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        # Get current value of timeout
        $previous_timeout_value = $socket->timeout();

        if ( $timeout != $previous_timeout_value ) {
            unless ( $socket->timeout( $timeout ) ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Cannot set timeout on socket to $timeout seconds");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name:  Changing timeout for socket operations to $timeout seconds from $previous_timeout_value seconds");
        }
    }

    # Auto-flush
    $|=1;

    my ( @read_info, $client_ip, $accept_socket, $peer_address_info );

    # Create a new listen socket object on the opened socket, necessary for listening/reading
    $logger->debug(__PACKAGE__ . ".$sub_name:  Waiting for data packet...");

    # use unless in case accept just times out.
    unless ( ( $accept_socket, $peer_address_info ) = $socket->accept() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  No data received at LISTEN socket.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Get port and IP address by unpacking peer information
    my ( $client_port, $peer_ip_info ) = sockaddr_in( $peer_address_info );
    $client_ip = inet_ntoa( $peer_ip_info );

    $logger->debug(__PACKAGE__ . ".$sub_name:  Reading data from: $client_ip");

    my $data;
    while (<$accept_socket>) {

        $logger->debug(__PACKAGE__ . ".$sub_name:  Read data: $_");

        $data .= $_;

        # If we see input separator (newline) leave this loop
        if ($_ =~ $\ or $_ =~ $/ ) {
            last;
        }
    }

    if ( $previous_timeout_value ) {
        unless ( $socket->timeout( $previous_timeout_value ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot set timeout on socket to $previous_timeout_value seconds");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Changing timeout back to original value, $previous_timeout_value seconds");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Finshed reading from: $client_ip");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [data]");

    $self->{READ_WRITE} = $accept_socket;

    return $data;
}

=head1 sendToRemote()

 DESCRIPTION: 
  This sub writes the string that has been passed in by the user to the socket object accessed via $socket->{READ_WRITE}

=over

=item ARGUMENTS:
 $data - Data string to be written to read/write socket

=item PACKAGE:
 SonusQA::SOCK

=item EXTERNAL FUNCTIONS USED:
 None

=item OUTPUT:
 1   - Sent string
 0   - Failure

=back

=cut

sub sendToRemote {

    my $sub_name = "sendToRemote";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my ($self, $data) = @_;

    my $socket = $self->{READ_WRITE};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Get type of pointer to ensure its a socket
    my $ref = ref( $socket );

    unless ( defined $socket && $ref =~ /IO::Socket::INET/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Object passes in is not defined as a socket: $socket");
        $logger->error(__PACKAGE__ . ".$sub_name:  Type found is \"$ref\", it should be IO::Socket::INET");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if ( $data eq "" ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Data argument -data is either missing or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Sending $data to socket");
        print $socket $data;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head1 close()

 DESCRIPTION: 
  This sub closes the LISTEN socket stored in $self->{LISTEN}

=over

=item ARGUMENTS:
 None 

=item PACKAGE:
 SonusQA::SOCK

=item EXTERNAL FUNCTIONS USED:
 IO::Socket::close 

=item OUTPUT:
 1   - Socket closed
 0   - Failure

=back

=cut

sub close {

    my $sub_name = "close";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my ($self, %args)  = @_;
    my $socket = $self->{LISTEN};

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Get type of pointer to ensure its a socket
    my $ref = ref( $socket );

    unless ( defined $socket && $ref =~ /IO::Socket::INET/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Object passes in is not defined as a socket: $socket");
        $logger->error(__PACKAGE__ . ".$sub_name:  Type found is \"$ref\", it should be IO::Socket::INET");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    close ( $socket );
    $logger->debug(__PACKAGE__ . ".$sub_name:  Closed Socket");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

1;
