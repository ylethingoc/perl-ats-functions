package SonusQA::EMS::INSTALLER;

=head1 NAME

SonusQA::EMS::INSTALLER - Perl module for EMSRAC ISO installation

=head1 REQUIRES

Log::Log4perl, Data::Dumper, SonusQA::ILOM

=head1 DESCRIPTION

This module provides APIs for EMS ISO installation

=head1 AUTHORS

Rakesh kumar jha <rajha@rbbn.com>

=head1 METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::ILOM;
use Time::HiRes qw(gettimeofday tv_interval usleep);
use SonusQA::TOOLS;


=head2 C< installISOonG8ForRAC >

=over

=item DESCRIPTION:

Install emsrac ISO on G8 box

=item ARGUMENTS:

Mandatory Args:
$iso_path =>  Path of the ISO to be installed
$ilom_ip  =>  ILOM IP. This is where we will vsp to trigger installation
$mgmt_ip  =>  IP to be assigned to a box
$gateway  =>  gateway ip
$netmask  =>  netmask
$hostname => EMS box hostname
$dns_ip  =>  DNS IP
$dns_spath => Primary DNS Serch Path
$ntpserver  => NTP server IP details
$time_zone => Time zone

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - On Failure
$obj - On success

=item EXAMPLE:

unless( SonusQA::EMS::INSTALLER::installISOonG8ForRAC(
                        -ilom_ip =>  10.54.40.80,
                        -mgmt_ip =>  10.54.13.80,
                        -gateway =>  10.54.13.1,
                        -netmask =>  255.255.255.0,
                        -iso_path =>  http://10.70.56.120:8080/examples/servlets/iso1/emsrac-V12.00.00A003-RHEL7-07.02.09.00A001-x86_64.iso ,
                        -hostname =>  midas,
                        -ntpservers =>  10.128.254.67,
                        -timezone =>  Asia/Kolkata,
                        -primary_dns =>  10.128.254.105,
                        -dns_search_path =>  emsrac.com
        )){
                $logger->error(__PACKAGE__ . ".$sub_name: Installation on primary G8 box failed.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
                }

=back

=cut


sub installISOonG8ForRAC {

    my (%args) = @_;
    my $obj;
    my $sub_name = "installISOonG8ForRAC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered Sub");
    

    unless ( $obj = SonusQA::ILOM->new(
            -OBJ_HOST     => $args{-ilom_ip},
            -OBJ_USER     => 'Administrator',
            -OBJ_PASSWORD => 'Sonus!@#',
            -OBJ_COMMTYPE => "SSH",
            -sessionlog   => 1,
          )){
            $logger->error( __PACKAGE__ . ".$sub_name: Failed to create ilo connection object" );
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
            }

    my ($prematch, $match, $max_attempts);

    my @cmds = (
        'vm cdrom insert ' . $args{-iso_path},
        'vm cdrom set boot_once',
        'vm cdrom get',
        'power reset'
        );
	 
    foreach (@cmds) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Entering $_");
        unless ($obj->{conn}->cmd($_)){
            $logger->error( __PACKAGE__ . ".$sub_name: Failed to execute $_" );
            $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }
	
   $logger->debug(__PACKAGE__ . " Sending 'vsp'");
  
    unless ($obj->{conn}->print('vsp')){
        $logger->error( __PACKAGE__ . ".$sub_name: Failed to send vsp" );
        $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
 
    $logger->debug( __PACKAGE__ . ".$sub_name: Waiting for VSP to start..." );
   
    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -match   => '/Press \'ESC \(\' to return to the CLI Session./',
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . ".$sub_name: Error on wait for vsp. PREMATCH: $prematch\nMATCH: $match");
        $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
  
    $logger->debug(__PACKAGE__ . ".$sub_name: VSP started - Waiting for ANSI 'query-device' term command" );

    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -string => "\x1b\x5b5n",
            -match  => $obj->{PROMPT},
            -Timeout => 300,  # Server pre-BIOS initialization can take some time...
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . ".$sub_name: Error on wait for ansi term cmd.." );
        $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
 
    unless ( $obj->{conn}->print("\x1b\x5b0n") ) {
        $logger->error( __PACKAGE__ . ".$sub_name: Failed to send '\x1b\x5b0n'" );
        $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
  
    $logger->debug( __PACKAGE__ . " Waiting for boot prompt" );
    my $a = "\x1b" . '\[\d+;\d+H'; # ANSI 'cursor position' code regexp - note - odd-looking quoting is intentional here..
    my $boot_regexp = "/b${a}${a}o${a}${a}o${a}${a}t/";

    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -match   => $boot_regexp,
            -Timeout => 300,            # BIOS initialization can take some time...
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . ".$sub_name: Error on wait for boot prompt.." );
        $logger->error( __PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
          }
 
    $logger->debug( __PACKAGE__ . ".$sub_name: Found boot prompt: $match" );
    $logger->debug( __PACKAGE__ . ".$sub_name: Entering 1" );
 
    my $cmd = "1 ip=$args{-mgmt_ip} netmask=$args{-netmask} gateway=$args{-gateway} hostname=$args{-hostname} dns_ip=$args{-primary_dns} dns_spath=$args{-dns_search_path} ntpserver=$args{-ntpservers} timezone=$args{-timezone} console=ttyS1,19200\n";

    # Sending the command in 1 go overloads the serial console... Send it char-by-char every 100ms
    my $c;

    for $c ( split( //, $cmd ) ) {
        usleep 100000;
        $logger->info( __PACKAGE__ . ".$sub_name: Sending: $c" );
        $obj->{conn}->put($c);
    }
	
    $logger->debug( __PACKAGE__ . ".$sub_name: Should now be booting..." );
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-"); 

    return $obj;
}



=head1 C<checkBootCompletedForBothG8 >

=over

=item DESCRIPTION:

This subroutine will check whether boot completed on both G8 boxes during emsrac iso install.

=item ARGUMENTS:

Mandatory Args:

$objConn_1 => primary ilo connection object
$objConn_2 => secondary ilo connection object

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - On Failure
1 - On success

=item EXAMPLE:

unless(SonusQA::EMS::INSTALLER::checkBootCompletedForBothG8 ( -obj_primary => $objConn_1 , -obj_secondary => $objConn_2)){
        $logger->error(__PACKAGE__ . ".$sub_name: Installation on G8 box failed.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
        }

=back

=cut

sub checkBootCompletedForBothG8 {
    my (%args) = @_;

    my $sub_name = "checkBootCompletedForBothG8";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($prematch, $match, $max_attempts);

    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");
    my $objConn_1 = $args{-obj_primary};
    my $objConn_2 = $args{-obj_secondary};

    $logger->info( __PACKAGE__ . ".$sub_name: Sleeping 1200 seconds" );
    sleep 1200;

    $logger->debug( __PACKAGE__ . ".$sub_name: Waiting for login prompt..." );

    my @objList = ($objConn_1, $objConn_2);
    foreach my $obj (@objList) {
    $max_attempts = 30;
    for (my $attempt = 1 ; $attempt <= $max_attempts ; $attempt++){
        if (( $prematch, $match ) = $obj->{conn}->waitfor(
                -match   => '/.*login: $/',
                -Timeout => 300,
                -errmode => "return"
            )){
            $logger->debug( __PACKAGE__ . ".$sub_name: Prompt matched. Boot complete." );
            last;
             }
        else {
              if ($attempt < $max_attempts){
                $logger->warn( __PACKAGE__ . ".$sub_name: Attempt $attempt failed. Error on wait for login prompt. PREMATCH: $prematch\nMATCH: $match");
                $logger->warn(__PACKAGE__ . ".$sub_name: Error Msg  : " . $obj->{conn}->errmsg );
                $logger->warn( __PACKAGE__ . ".$sub_name: Attempting again... " );
              }else 
                  {
                $logger->error( __PACKAGE__ . ".$sub_name: Reached max attempts($max_attempts). Installation failed. Manual intervention required.");
                $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
                 }
            }
    }

   }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return 1;

}



=head1 C<loginAndChangeRootPswd >

=over

=item DESCRIPTION:
login to both primary and secondary ems servers as root and change the paswd back to old one.

=item ARGUMENTS:

Mandatory Args:
$primary_ems_ip => primary ems ip
$secondary_ems_ip => secondary ems ip
$rootPaswd => ems root password

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - On Failure
1 - On success

=item EXAMPLE:

unless(SonusQA::EMS::INSTALLER::loginAndChangeRootPswd( -primary => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{1}->{IP},
                                                               -secondary => $TESTBED{'ems_sut:1:ce0:hash'}->{NODE}->{2}->{IP},
                                                               -ROOTPASSWD => $TESTBED{'ems_sut:1:ce0:hash'}->{LOGIN}->{1}->{ROOTPASSWD}
                 )){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to login and change root paswd for ems servers.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
        }else {
                 $logger->info(__PACKAGE__ . ".$sub_name: login and change root paswd successful on both ems servers");
                }

=back

=cut


sub loginAndChangeRootPswd {
  my (%args) = @_;
  my $sub_name = "loginAndChangeRootPswd";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");   
  my $secondary_ems_ip = $args{-secondary};	
  my $primary_ems_ip = $args{-primary};
  my $rootPaswd = $args{-ROOTPASSWD};
  $logger->debug(__PACKAGE__ . ".$sub_name: Entered Sub");
 
  my ($self_primary , $self_secondary );

  unless ( $self_primary = SonusQA::TOOLS->new(  -OBJ_HOST => $primary_ems_ip,
                                        -OBJ_USER => 'admin',
                                        -OBJ_PASSWORD => 'admin',
                                        -ROOTPASSWD => $rootPaswd,
                                        -NEWROOTPASSWD => $args{-NEWROOTPASSWD},
                                        -OBJ_COMMTYPE => 'SSH',
                                        -sessionlog   => 1,
        )) {
           $logger->error(__PACKAGE__ . ".$sub_name: failed to create  TOOLS object for host ip $primary_ems_ip");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
           return 0;
           }

  
  unless ( $self_primary->enterRootSessionViaSU()) {
          $logger->error(__PACKAGE__ . ".$sub_name: failed to login to EMS $primary_ems_ip using root user");
          $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
          return 0;
  }else{
          $logger->debug(__PACKAGE__ . ".$sub_name: Success: successfully logged in to the EMS $primary_ems_ip using root user");
       }


  unless ( $self_secondary = SonusQA::TOOLS->new(  -OBJ_HOST => $secondary_ems_ip,
                                        -OBJ_USER => 'admin',
                                        -OBJ_PASSWORD => 'admin',
                                        -ROOTPASSWD => $rootPaswd,
                                        -NEWROOTPASSWD => $args{-NEWROOTPASSWD},
                                        -OBJ_COMMTYPE => 'SSH',
                                        -sessionlog   => 1,
        )){
           $logger->error(__PACKAGE__ . ".$sub_name: failed to create  TOOLS object for host ip $secondary_ems_ip");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
           return 0;
          }


  unless ( $self_secondary->enterRootSessionViaSU()) {
          $logger->error(__PACKAGE__ . ".$sub_name: failed to login to EMS $secondary_ems_ip using root user");
          $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
          return 0;
  }else{
          $logger->debug(__PACKAGE__ . ".$sub_name: Success: successfully logged in to the EMS $secondary_ems_ip using root user");
          $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[1]");
       }

     return 1;	
}

1;
