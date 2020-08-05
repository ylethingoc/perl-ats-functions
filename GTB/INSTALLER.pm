package SonusQA::GTB::INSTALLER;

=head1 NAME

SonusQA::GTB::INSTALLER - Perl module for Sonus Networks TEST BED Installation Routines

=head1 REQUIRES

File::stat, File::Basename, Time::HiRes, vars, Data::Dumper, Net::Telnet, Net::IP, Switch, POSIX, Log::Log4perl

=head1 DESCRIPTION

Provides installation related APIs for various Sonus Testbeds.

=head1 METHODS

=cut

use strict;
use ATS;
use SonusQA::ILOM;
use SonusQA::Base;
use SonusQA::SBX5000;
use SonusQA::SBX5000::SBX5000HELPER;
use SonusQA::SBX5000::INSTALLER;
use SonusQA::PSX::INSTALLER;
use SonusQA::ATSHELPER;
use SonusQA::Utils qw (:all);
use File::stat;
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval usleep);
use vars qw($self);
use Data::Dumper;
use Net::Telnet ();
use Net::IP qw(ip_get_mask ip_bintoip);
use Switch;
use POSIX;
use Log::Log4perl qw(get_logger :levels);

our $TESTSUITE;
our $ccPackage;


my $logger=$Scheduler::g_logger;

=head1 adminDebugSonus()

=over

=item DESCRIPTION:
OBJECT CLI API COMMAND, GENERIC FUNCTION FOR POSITIVE/NEGATIVE TESTING

=item ARGUMENTS:
Mandatory Args:
None

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
cmdResults - results of 'admin debugSonus' command

=item EXAMPLE:
$obj->adminDebugSonus()

=back

=cut

sub adminDebugSonus (){
  my ($self)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $slot);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".adminDebugSonus");
  $cmd ="admin debugSonus";
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/^error/i){
      $logger->warn(__PACKAGE__ . ".adminDebugSonus  CMD RESULT: $_");
      $flag = 0;
      next;
    }
  }
  return @cmdResults;
}


=head1 PingIP()

=over

=item DESCRIPTION:
Pings IP passed as argument.

=item ARGUMENTS:
Mandatory Args:
ip - ip address of node to perform ping

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
cmdResults - result of 'ping -c 4 $ip' command

=item EXAMPLE:
$obj->PingIp('10.54.80.172')

=back

=cut

sub PingIP (){

  my ($self,$ip)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $IP);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "PingIP");
  @cmdResults = ();
  unless(defined($ip)){
    $logger->warn(__PACKAGE__ . ".PingIP  IP MISSING");
    return @cmdResults;
  };
  $cmd = sprintf("ping -c 4 %s ", $ip);
  @cmdResults =  $self->execCmd($cmd);
  foreach(@cmdResults) {
      $logger->info(__PACKAGE__ . ".PingIP SUCCESSFULLY pinging: $_");
  }
}


=head1 ATSInstallGSX()

=over

=item DESCRIPTION:
This subroutine is used to scp the GSX 9000 installable file from the specified server and perform the steps required for loading the build on the NFS server. This method DOES NOT CHANGE THE BUILD ON THE GSX. It only loads the build on the NFS server. To change the build on the GSX, call this interface and execute the cli command to change the build and reboot the GSX.

=item ARGUMENTS:
Mandatory Args:
1. IP Address of the server from where the load file needs to be copied
2. User name to access the server
3. Password of the user
4. Complete path where the build file is present on the server

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
ATSInstallGSX("S2000", "GSX_V08.04.03R000", "10.1.1.2", "autouser", "autouser", "release.gsxV07.03.07S008");

=back

=cut

sub ATSInstallGSX {
 my ( %gargs ) = @_;
    my $sub_name = "ATSInstallGSX";
    my (%ga);
    my $gcc_copy = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    while ( my ($key, $value) = each %gargs ) { $ga{$key} = $value; }

    # Checking mandatory args;
    if ( defined ( $ga{-package} ) ) {
        foreach ( qw/ package primaryGSX / ) {
            unless ( defined $ga{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
        }
    } 
    if ( defined ( $ga{-ccView} ) ) {
        foreach ( qw/ primaryGSX ccHostIp ccView ccUsername ccPassword / ) {
            unless ( defined $ga{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
    	    $gcc_copy = 1;
        }
    } 
     while ( $gcc_copy ) {
        $logger->info(__PACKAGE__ . ".$sub_name: copying and Insalling build from ClearCase server to gsx");
        unless ( SonusQA::GTB::INSTALLER::copyFromCCServerToInstallGSX( -ccHostIp   => $ga{-ccHostIp},
                                                            -ccUsername => $ga{-ccUsername},
                                                            -ccPassword => $ga{-ccPassword},
                                                            -ccView => $ga{-ccView},
                                                            -gsxHost => $ga{-primaryGSX}
                                                                                      ) ) {
            $logger->info(__PACKAGE__ . ".$sub_name: Failed to copy and install the package from ClearCase server to GSX!");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
	$logger->info(__PACKAGE__ . ".$sub_name: Successfully copied the build from $ga{-ccView}!");
	return 1;
	
    }
      
}

=head1 copyFromCCServerToInstallGSX()

=over

=item DESCRIPTION:
This subroutine the logs in to the clearcase machine and execute cpsipqaimages.sh script to install GSX

=item ARGUMENTS:
Mandatory Args:
    1. ccHostIp   -  Ip of the clearcase machine
    2. ccUsername -  username for the clearcase machine 
    3. ccPassword -  password for the clearcase machine	
    4. ccView     -  view of the machine from where the installation package is available
    5. gsxHost    -  hostname of the GSX to which the package is copied

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
ccPackage - package name available in the clearcase machine

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
0 - On Failure
1 - On success

=item EXAMPLE:
copyFromCCServerToInstallGSX(-ccHostIp => "10.1.1.2", -ccUsername => "autouser", -ccPassword => "autouser", -ccView => "release.sbx5000_V03.00.00A054", -gsxHost => "S2000");

=back

=cut

sub copyFromCCServerToInstallGSX {
    my ( %gargs ) = @_;
    my $sub_name = "copyFromCCServerToInstallGSX()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name Entered-");
    my %ga;
    
    # get the arguments
    while ( my ($key, $value) = each %gargs ) { $ga{$key} = $value; }

    # checking for mandatory parameters
    foreach ( qw/ ccHostIp ccUsername ccPassword ccView gsxHost/ ) {
        unless ( defined $ga{-$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
            return 0;
        }
    }

    # Creating a telnet session to clearcase server
    my $ssh_session = new SonusQA::Base(           -obj_host       => $ga{-ccHostIp},
                                                   -obj_user       => $ga{-ccUsername},
                                                   -obj_password   => $ga{-ccPassword},
                                                   -comm_type      => 'SSH',
						   -prompt         => '/.*[\$#%>\}]\s*$/',
                                                   -obj_port       => 22,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

    unless ( $ssh_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to clearcase server");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    unless ( $ssh_session->{conn}->cmd( String  => "sv -f $ga{-ccView}",
					Timeout => "60",
					) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter the ccView");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    sleep 5;

    $ssh_session->{conn}->cmd("bash");

    my $cmd1 = "cpsipqaimages -noconfirm -target all $ga{-gsxHost}";
    my @cmdresults = $ssh_session->{conn}->cmd("$cmd1");

      $logger->info(__PACKAGE__ . ".$sub_name: Executed : $cmd1");
   	sleep 60;
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=head1 ATSInstallSBX()

=over

=item DESCRIPTION:
This API first stops the sbx service in both primary and secondary, then it updates the SBX package from the path /opt/sonus/ after untarring. This API handles incase if the device is singleCE.

=item ARGUMENTS:
Mandatory:

    -primarySBX =>
    -secondarySBX =>

Optional:

    -package =>
    -timeout =>
    -ccHostIp =>
    -ccView =>
    -ccUsername =>
    -ccPassword => 

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
unless ( $self->ATSInstallSBX ( 'sbx-V02.00.07-R000.x86_64.tar.gz', '10.6.82.88', '10.6.82.59' ) ) {
    $logger->error(__PACKAGE__ . " Failed to install the required package ");
    return 0;
}

=back

=cut

sub ATSInstallSBX {
    my ( %args ) = @_;
    my $sub_name = "ATSInstallSBX";
    my $cc_copy = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    # Checking mandatory args;
    foreach ( qw/ build primarySBX / ) {
        unless ( defined $args{-$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
            return 0;
        }
    } 

    my $sbx_alias_hashref = '';
    unless ( $sbx_alias_hashref = SonusQA::Utils::resolve_alias($args{-primarySBX})) {
        $logger->error(__PACKAGE__ . ".$sub_name failed to resolve primary sbx alias..!!! ");
        return 0;
    }
    
    my $secondarySBX = (defined $sbx_alias_hashref->{CE1}->{1}->{HOSTNAME}) ? $sbx_alias_hashref->{CE1}->{1}->{HOSTNAME} : '';

    my %data = ();
    my $package = $args{-build};
    $package =~ s/SBX_/APP_SBC-/i;
    $package = $package . ".tar.gz";
    
    $data{-package} = $package;
    $data{-build} = $args{-build};
    $data{-primarySBXData}->{-ip} = $sbx_alias_hashref->{MGMTNIF}->{1}->{IP};
    $data{-primarySBXData}->{-host_role} = 1;
    $data{-primarySBXData}->{-system_name} = $sbx_alias_hashref->{'NODE'}->{1}->{HOSTNAME} || $sbx_alias_hashref->{CE}->{1}->{HOSTNAME};
    $data{-primarySBXData}->{-host_name} = $sbx_alias_hashref->{CE}->{1}->{HOSTNAME};
    $data{-primarySBXData}->{-ntp_server_ip} = $sbx_alias_hashref->{NTP}->{1}->{IP};
    $data{-primarySBXData}->{-time_zone_index} = $sbx_alias_hashref->{NTP}->{1}->{ZONEINDEX};
    $data{-primarySBXData}->{-peer_host_name} = 'none' unless ($secondarySBX);
    $data{-primarySBXData}->{-primary_mgmt_ip} = $sbx_alias_hashref->{MGMTNIF}->{1}->{IP};
    $data{-primarySBXData}->{-primary_mgmt_netmask} = ip_bintoip(ip_get_mask($sbx_alias_hashref->{MGMTNIF}->{1}->{IPV4PREFIXLEN},4),4);
    $data{-primarySBXData}->{-primary_mgmt_gateway} = $sbx_alias_hashref->{MGMTNIF}->{1}->{DEFAULT_GATEWAY};
    $data{-primarySBXData}->{-secondary_mgmt_ip} = $sbx_alias_hashref->{MGMTNIF}->{2}->{IP} || '0.0.0.0';
    $data{-primarySBXData}->{-secondary_mgmt_netmask} = ip_bintoip(ip_get_mask($sbx_alias_hashref->{MGMTNIF}->{2}->{IPV4PREFIXLEN}||0,4),4) || '0.0.0.0';
    $data{-primarySBXData}->{-secondary_mgmt_gateway} = $sbx_alias_hashref->{MGMTNIF}->{2}->{DEFAULT_GATEWAY} || '0.0.0.0';
    $data{-iSMART} = 1;

    map {$data{-ccData}->{$_} = $args{$_}} ('-ccHostIp', '-ccView', '-ccUsername', '-ccPassword') if (defined ( $args{-ccHostIp} ));

    if ($secondarySBX) {
        my $alias_hashref = SonusQA::Utils::resolve_alias($secondarySBX);
        unless ($alias_hashref) {
            $logger->error(__PACKAGE__ . ".$sub_name failed to resolve secondary sbx alias");
            return 0;
        }
        $data{-primarySBXData}->{-peer_host_name} = $alias_hashref->{CE}->{1}->{HOSTNAME}; 
        $data{-secondarySBXData}->{-ip} = $alias_hashref->{MGMTNIF}->{1}->{IP};
        $data{-secondarySBXData}->{-host_role} = 2;
        $data{-secondarySBXData}->{-system_name} = $data{-primarySBXData}->{-system_name};
        $data{-secondarySBXData}->{-host_name} = $alias_hashref->{CE}->{1}->{HOSTNAME};
        $data{-secondarySBXData}->{-ntp_server_ip} = $alias_hashref->{NTP}->{1}->{IP};
        $data{-secondarySBXData}->{-time_zone_index} = $alias_hashref->{NTP}->{1}->{ZONEINDEX};
        $data{-secondarySBXData}->{-peer_host_name} = $sbx_alias_hashref->{CE}->{1}->{HOSTNAME};
        $data{-secondarySBXData}->{-primary_mgmt_ip} = $alias_hashref->{MGMTNIF}->{1}->{IP};
        $data{-secondarySBXData}->{-primary_mgmt_netmask} = ip_bintoip(ip_get_mask($alias_hashref->{MGMTNIF}->{1}->{IPV4PREFIXLEN},4),4);
        $data{-secondarySBXData}->{-primary_mgmt_gateway} = $alias_hashref->{MGMTNIF}->{1}->{DEFAULT_GATEWAY};
        $data{-secondarySBXData}->{-secondary_mgmt_ip} = $alias_hashref->{MGMTNIF}->{2}->{IP} || '0.0.0.0';
        $data{-secondarySBXData}->{-secondary_mgmt_netmask} = ip_bintoip(ip_get_mask($alias_hashref->{MGMTNIF}->{2}->{IPV4PREFIXLEN}||0, 4),4);
        $data{-secondarySBXData}->{-secondary_mgmt_gateway} = $alias_hashref->{MGMTNIF}->{2}->{DEFAULT_GATEWAY} || '0.0.0.0';
    }

    my $returnCode = SonusQA::SBX5000::SBX5000HELPER::completeInstall(%data);

    if ( $returnCode == 2 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: build is not yet ready returning 2!");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[2]");
        return 2;
    }
    elsif ($returnCode == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: sbx application install failed");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name  i will sleep for 300 secs after the installation");
    sleep 300;

    my $sbxObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $args{-primarySBX}, -ignore_xml => 0, -sessionlog => 1);
    unless ( $sbxObj ) {
        $logger->error(__PACKAGE__ . ".$sub_name: sbx is not up, seems some problem in installation");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

    if ($secondarySBX) {
        my $primary_active;
        $primary_active = $sbxObj->verifyPrimaryActive($args{-primarySBX}); 
    
        unless ( $primary_active ) {
            # Primary is inactive, so restarting secondary so that primary SBX comes up
            $logger->error(__PACKAGE__ . ".$sub_name: Primary is inactive, so restarting secondary to bring up primary!"); 		
        
   	    unless ( $sbxObj->{$self->{ACTIVE_CE}}->{conn}->cmd('service sbx restart') ) {
	        $logger->error(__PACKAGE__ . ".$sub_name: restarting secondary SBX failed!");   
  	        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
	        return 0;
 	    }
	    $logger->info(__PACKAGE__ . ".$sub_name: Successfully restarted Secondary SBX...");
            unless ($sbxObj->verifyPrimaryActive($args{-primarySBX})) {
                $logger->error(__PACKAGE__ . ".$sub_name: Primary SBX status is inactive even after restarting secondary");
                return 0;
            }
        }
        $logger->info(__PACKAGE__ . ".$sub_name: primary SBX is currently active!");

        my %cliHash = ( "Policy Data" => "syncCompleted", "Disk Mirroring" => "SyncCompleted", "Configuration Data" => "SyncCompleted", "Call/Registration Data" => "SyncCompleted" );
        if ( $sbxObj->checkSbxSyncStatus("show status system syncStatus", \%cliHash ) ) {
            $logger->info(__PACKAGE__ . "SBX's Synced & Testbed is Ready for Configuration & Testing ");
            print( "SBX's Synced & Testbed is Ready for Configuration & Testing \n");
            return 1;
        }
        else {
            $logger->error(__PACKAGE__ . " Either of the SBXs is not in Sync State! ");
            return 0;
        }

    }else{
        $logger->info(__PACKAGE__ . ".$sub_name: Skipping secondary upgrade process as the SBX is single CE");
    }
	
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    return 1;	
}

=head1 ATSInstallPSX()

=over

=item DESCRIPTION:
This subroutine is used to scp the PSX 9000 installable file from the specified server and perform the steps required for loading the build on the NFS server. This method DOES NOT CHANGE THE BUILD ON THE GSX. It only loads the build on the NFS server. To change the build on the GSX, call this interface and execute the cli command to change the build and reboot the GSX.

=item ARGUMENTS:
Mandatory:
   1. IP Address of the server from where the load file needs to be copied
   2. User name to access the server
   3. Password of the user
   4. Complete path where the build file is present on the server

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
ATSInstallPSX("soft32", "PSX_V08.04.03R000", "10.1.1.2", "autouser", "autouser", "release.psxV07.03.07A021");

=back

=cut

sub ATSInstallPSX {
 my ( %pargs ) = @_;
    my $sub_name = "ATSInstallPSX";
    my (%pa);
    my $pcc_copy = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    while ( my ($key, $value) = each %pargs ) { $pa{$key} = $value; }

    # Checking mandatory args;
    if ( defined ( $pa{-package} ) ) {
        foreach ( qw/ package primaryPSX / ) {
            unless ( defined $pa{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
        }
    } 
    if ( defined ( $pa{-ccView} ) ) {
        foreach ( qw/ primaryPSX ccHostIp ccView ccUsername ccPassword / ) {
            unless ( defined $pa{-$_} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
                return 0;
            }
    	    $pcc_copy = 1;
        }
    }
    
 if ( $pcc_copy ) {
        $logger->info(__PACKAGE__ . ".$sub_name: copying and Installing build from ClearCase server to psx");
        unless ( SonusQA::GTB::INSTALLER::copyFromCCServerToInstallPSX( -ccHostIp   => $pa{-ccHostIp},
                                                                        -ccUsername => $pa{-ccUsername},
                                                                        -ccPassword => $pa{-ccPassword},
                                                                        -ccView => $pa{-ccView},
                                                                        -psxHost => $pa{-primaryPSX}
                                                                                      ) ) {
            $logger->info(__PACKAGE__ . ".$sub_name: Failed to copy and install the package from ClearCase server to PSX!");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
	
        
    }else
          {
        print "PSX Build is $pa{-package}\n";
        $logger->info(__PACKAGE__ . "PSX Build to be loaded is = $pa{-package}\n");
        my $psx_cp_cmd1 = "cd /sonus/ReleaseEng/PSX";
        my $psx_cp_cmd2 = "tar -cvf /tmp/" . "$pa{-package}" . ".tar " . "$pa{-package}";
        my $psx_cp_cmd3 = "gzip " . "/tmp/$pa{-package}" . ".tar" ;
        
        $pa{-package} = "$pa{-package}" . ".tar.gz";
      #  $rpm =~ s/\.gz//;
       # $rpm =~ s/\.tar//;
      #  $rpm = "$rpm" . "\.rpm";
       # $logger->info(__PACKAGE__ . ".$sub_name: RPM file-->$rpm");
      #  $primary_cmd1 = "\./sbxUpdate\.sh -d -f " . $rpm;
	 
         
               
        $logger->info(__PACKAGE__ . ".$sub_name: Copying the installation package from ATS server to PSX...");
        my $ssh_session = new SonusQA::Base(-obj_host       => "localhost",
                                                   -obj_user       => "autouser",
                                                   -obj_password   => "autouser",
                                                   -comm_type      => 'SSH',
						   -prompt         => '/.*[\$#%>\}]\s*$/',
                                                   -obj_port       => 22,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

               unless ( $ssh_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to clearcase server");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
          }
           
           $ssh_session->{conn}->cmd("$psx_cp_cmd1");
           $ssh_session->{conn}->cmd("$psx_cp_cmd2");
           sleep (120);
           $ssh_session->{conn}->cmd("$psx_cp_cmd3");
           sleep (60);
                
	   my %scpArgs;
           $scpArgs{-hostip} = $pa{-primaryPSX};
           $scpArgs{-hostuser} = 'root';
           $scpArgs{-hostpasswd} = 'sonus';
           $scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:/export/home/ssuser";
           $scpArgs{-sourceFilePath} = "/tmp/" . $pa{-package};
	   unless ($scpArgs{-sourceFilePath}) {
		$logger->info(__PACKAGE__ . ".$sub_name: Source file not identified!");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
           }
           $logger->info(__PACKAGE__ . ".$sub_name: Copying tar file to PSX($pa{-primaryPSX}).....");
           unless( &SonusQA::Base::secureCopy(%scpArgs)){
		$logger->info(__PACKAGE__ . ".$sub_name:  copying package to remote server Failed");
                $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                return 0;	
	   }

    }
      $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
      return 1;        	
}
	       
=head1 copyFromCCServerToInstallPSX()

=over

=item DESCRIPTION:
This subroutine the logs in to the clearcase machine and execute cpsipqaimages.sh script to install GSX

=item ARGUMENTS:
Mandatory:
    1. ccHostIp   -  Ip of the clearcase machine
    2. ccUsername -  username for the clearcase machine 
    3. ccPassword -  password for the clearcase machine	
    4. ccView     -  view of the machine from where the installation package is available
    5. gsxHost    -  hostname of the GSX to which the package is copied

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
ccPackage - package name available in the clearcase machine

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
0 - On Failure
1 - On success

=item EXAMPLE:
copyFromCCServerToInstallGSX( -ccHostIp   => "10.6.40.63", -ccUsername => "autouser", -ccPassword => "autouser", -ccView => "release.sbx5000_V03.00.00A054", -psxHost => "soft32");

=back

=cut  

sub copyFromCCServerToInstallPSX {
    my ( %pargs ) = @_;
    my $sub_name = "copyFromCCServerToInstallPSX()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name Entered-");
    my %pa;
    
    # get the arguments
    while ( my ($key, $value) = each %pargs ) { $pa{$key} = $value; }

    # checking for mandatory parameters
    foreach ( qw/ ccHostIp ccUsername ccPassword ccView psxHost/ ) {
        unless ( defined $pa{-$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter $_ is empty or blank.");
            return 0;
        }
    }

    # Creating a telnet session to clearcase server
    my $ssh_session = new SonusQA::Base(           -obj_host       => $pa{-ccHostIp},
                                                   -obj_user       => $pa{-ccUsername},
                                                   -obj_password   => $pa{-ccPassword},
                                                   -comm_type      => 'SSH',
						   -prompt         => '/.*[\$#%>\}]\s*$/',
                                                   -obj_port       => 22,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

    unless ( $ssh_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to clearcase server");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    unless ( $ssh_session->{conn}->cmd( String  => "sv -f $pa{-ccView}",
					Timeout => "60",
					) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter the ccView");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    sleep 5;

    $ssh_session->{conn}->cmd("bash");

  #  my $cmd1 = "cpsipqaimages -noconfirm -target all $pa{-psxHost}";
  #  my @cmdresults = $ssh_session->{conn}->cmd("$cmd1");

  #    $logger->info(__PACKAGE__ . ".$sub_name: Executed : $cmd1");
   #	sleep 60;
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=head1 stopPsx()

=over

=item DESCRIPTION:
Telnet to PSX and stop

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
STOPPED - On success
ERROR - On failure

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::stopPsx($psxIP);

=back

=cut

sub stopPsx
{
  
  my $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $line;
  my $Timeout=20;

  print "Stopping PSX application on $psx ...\n";

  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  my @lines = $t->cmd("stop.ssoftswitch");
  

  foreach $line(@lines) 
  {
      print "$line";
      if($line =~ m/Done/)
      {
          print "We are done\n";
          $logger->info("Stopped PSX $psx");
          return("STOPPED");
      }
      if($line =~ m/not running/)
      {
          print "Already Stopped\n";
          $logger->info("Already Stopped PSX $psx");
          return("ALREADY"); 
      }
   }
   return("ERROR");
}

=head1 psxUpdateDb()

=over

=item DESCRIPTION:
Telnet to PSX and run UpdateDb

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
STOPPED - On success
ERROR - On failure

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::psxUpdateDb($psxIP);

=back

=cut

sub psxUpdateDb
{
  
  my $psx=shift;
  my $psx_username="root";
  my $psx_password="sonus";
  my $line;
  my $Timeout=20;

  print "Calling command for PSX DB Upgrade on $psx ...\n";

  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login("root","sonus");
  
  my @lines = $t->cmd("cd /export/home/ssuser/SOFTSWITCH/SQL");
  @lines = $t->cmd(Prompt=> '/ $/',Timeout => 30,Errmode=>'die',String =>"./UpdateDb");
  print @lines;
  @lines = $t->cmd(Prompt=> '/# $/',Timeout => 520,Errmode=>'return',String =>"y");
  print @lines;
  
  foreach $line(@lines) 
  {
      print "$line \n";  
      
  }
   return("ERROR");
}
=head1 startPsx()

=over

=item DESCRIPTION:
Telnet to PSX and start 

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
STARTED - If PSX starts successfully
ALREADY - If PSX was already started

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::startPsx($psxIP);

=back

=cut

sub startPsx
{
  
  my $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $line;
  my $Timeout=20;

  print "Starting PSX application on $psx ...\n";

  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  my @lines = $t->cmd("start.ssoftswitch \n");
  @lines = $t->cmd("ls                \n");
  print "Send cmd to n $psx ...\n";
  foreach $line(@lines) 
  {
      if($line =~ m/Started/)
      {
          print "Started PSX\n";
          return("STARTED");
      }
      if($line =~ m/Already Running/)
      {
          print "Already Started\n";
          $t->cmd("n \n");
          return("ALREADY");
      }
  }
  return("OK");
}

=head1 getPsxVer()

=over

=item DESCRIPTION:
Telnet to PSX and get version 

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
version - On success returns PSX version 
ERROR - On failure

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::getPsxVer($psxIP);

=back

=cut

sub getPsxVer
{
  my $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $line;
  my $Timeout=20;


  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  my @lines = $t->cmd("pes -ver \n");

  foreach $line(@lines) 
  {
    if($line =~ m/V/)
    {
        print "$line \n";
        return($line);
    }
  }
  return("ERROR");
}

=head1 uninstallPsx()

=over

=item DESCRIPTION:
Telnet to PSX and get version 

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
GOOD - On successful uninstall
ERROR - On failure

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::uninstallPsx($psxIP);

=back

=cut

sub uninstallPsx
{
  
  my $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $line;
  my $Timeout=20;

  print "Uninstall PSX application on $psx ...\n";

  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);

  $t->login("root","sonus");
  my @lines = $t->cmd(Prompt=> '/] $/',Errmode=>'return',String =>"/export/home/ssuser/SOFTSWITCH/BIN/psxUninstall.sh");
  @lines = $t->cmd(Prompt=> '/] $/',Errmode=>'return',String =>"y");
  @lines = $t->cmd(Prompt=> '/# $/',Errmode=>'return',String =>"y");  
  
  foreach $line(@lines) 
  {
      print "$line \n";  
      if($line =~ m/was successful/)
      {
          print "Uninstall was good!\n";
          return("GOOD");
      } 
 }
 return("ERROR");
}

=head1 installPsx()

=over

=item DESCRIPTION:
Telnet to PSX and install 

=item ARGUMENTS:
Mandatory Args:
psxIP => ip address of psx

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
STARTED - On successful install
DONE - Otherwise

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::installPsx($psxIP);

=back

=cut

sub installPsx
{
  
  my $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $line;
  my $Timeout=20;

  print "Install PSX application on $psx ...\n";

  my $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login("root","sonus");
  
  my @lines = $t->cmd("cd /export/home/ssuser\n");
  @lines = $t->cmd(Prompt=> '/ $/',Timeout => 30,Errmode=>'die',String =>"./psxInstall.sh");
  print @lines;

  #Host Name (default: soft33)...........: 
  @lines = $t->cmd(Prompt=> '/: $/',Errmode=>'die',String =>""); 
  print @lines;

  #Ip Address (default: 10.9.16.239)...........: 
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>""); 
  print @lines;

  #Are the values correct (default:N) [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/.: $/',Errmode=>'die',String =>"y"); 
  print @lines;

  #User Name (default: ssuser) ..........................................: 
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;

  #Group Name (default: ssgroup) ........................................: 
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;

  #Are the values correct (default:N) [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines; 

  #Do you want to automatically start the Sonus SoftSwitch on system startup [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines; 

  #Do you want to automatically stop the Sonus SoftSwitch on system shutdown [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;

  #Base Directory (default: /export/home/ssuser)...........:
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;    
 
  #Is the value correct (default:N) [y|Y,n|N] ?
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  #Do you want to continue with the installation of <SONSss> [y,n,?]
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  # (default: /export/home):
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;   

  #Is this value correct? (default: N) [y|Y,n|N]: y
  @lines = $t->cmd(Prompt=> '/]:? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  #Enter admin account password (default: admin):
  @lines = $t->cmd(Prompt=> '/:? $/',Errmode=>'die',String =>""); 
  print @lines;  

  foreach $line(@lines) 
  {
      print "$line \n";
      if($line =~ m/Starting sonusAgent/)
      {
          print "Started PSX AGENT\n";
           $t->close;
          return("STARTED");
      }
  }
  $t->close;
  return("DONE");
}

=head1 ATSInstallElement()

=over

=item DESCRIPTION:
Generic api to call out for performing installation for various products.

=item ARGUMENTS:
JobId - Id of running job
DUT - PSX/SBX/GSX
nodeIp - node IP where installation to be performed
build - build file name
ccViewLocation - ccView location, W for westford, I for India
ccView - clear case view

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
STARTED - On successful install
DONE - Otherwise

=item EXAMPLE:
my $result = SonusQA::GTB::INSTALLER::ATSInstallElement($JobId, $DUT, $nodeIp, $build, $ccViewLocation, $ccView);

=back

=cut

sub ATSInstallElement {
    my $JobId = shift;
    my $DUT = shift;
    my $primarySBX = shift;
    my $build = shift;
    my $ccViewLocation = shift;
    my $ccView = shift;
    my $primaryGSX = $primarySBX;
    my $primaryPSX = $primarySBX;			
	
    my $sub_name = "ATSInstallElement";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");
    my ( $ccHostIp, $ccUsername, $ccPassword, $sbx_alias_hashref, $sbxSyncObj, $secondarySBX, $gsxObj2, $gsxObj3, $psxObj1, $psxObj2, $psxObj3 );
   
    $logger->info(__PACKAGE__ . ".$sub_name: $JobId, $DUT, $primarySBX, $build, $ccViewLocation, $ccView \n");
	 
    if ( $DUT =~ /^SBX5\d00/) {
        $DUT = "SBX5x00"
    }
              
    switch($ccViewLocation) {
        case "W" {
            $ccHostIp = "10.1.1.2";
            $ccUsername = "autouser";
            $ccPassword = "autouser";
        }
        case "N" {
            $ccHostIp = "10.160.20.64";
            $ccUsername = "autouser";
            $ccPassword = "autouser";
        }
        case "U" {
            $ccHostIp = "10.1.1.19";
            $ccUsername = "autouser";
            $ccPassword = "autouser";
        }
        case "I" {
            $ccHostIp = "water";
            $ccUsername = "autouser";
            $ccPassword = "autouser";
        }
    }  
	
    switch("$DUT") {
        case "SBX5x00" {
 
            my %args = ();
            $args{-build} = $build;
            $args{-primarySBX} = $primarySBX;

            if ($ccView ne "NULL") {
                $logger->info(__PACKAGE__ . " $JobId SBX Install from clear case view - $ccView");
                print (":Version to be loaded in SBX's is from $ccView ");
                $args{-ccHostIp} = $ccHostIp;
                $args{-ccUsername} = $ccUsername;
                $args{-ccPassword} = $ccPassword;
                $args{-ccView} = $ccView;
            }
                
            my $installSBXretCode = ATSInstallSBX(%args);

            if ( $installSBXretCode == 0) {
                $logger->error(__PACKAGE__ . ".$sub_name: Couldn't Install the images on to SBX's!");
                $logger->error(__PACKAGE__ . ".$JobId  failed");
                return 0;
            }
            elsif ( $installSBXretCode == 2) {
                $logger->info(__PACKAGE__ . ".$sub_name: SBX image has not been built and ready, WAIT and TRY AGAIN!");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[2]");
                return 2;
            }

            $logger->info(__PACKAGE__ . "$JobId Testbed is Ready for Configuration & Testing ");
            print( "$JobId  Testbed is Ready for Configuration & Testing \n");    
            print(": SBX Install complete copy image from ccView \n" );
            return 1;
        }

        case "PSX" {

				 	
			$logger->info(" Installing PSX with $ccView");
			print"Inside PSX Install Routine\n";                                   
                        my $package = $build;
                        $package =~ s/PSX_//i;
                        my $Timeout = 20;
                        my $psxTargetVersion = $package;
                        if ($ccView ne "NULL")
                          {
					
	$logger->info(" Installing PSX with $ccView");
	print"Inside PSX Install Routine\n";		
	$logger->info(__PACKAGE__ . ": DUT is Identified as $DUT");	 
        my $package = $build;  
       
       $logger->info(__PACKAGE__ . ":build to be loaded in SBX's is $package ");
	

	$logger->info(__PACKAGE__ . " $JobId GSX Install from CC");
        $logger->info(__PACKAGE__ . " Inside test case");       	
        $logger->info(__PACKAGE__ . ":build to be loaded in SBX's is from $ccView ");
          
         unless ( SonusQA::GTB::INSTALLER::ATSInstallPSX ( -ccHostIp => "$ccHostIp",
                                                -ccUsername => "$ccUsername",
                                                -ccPassword => "$ccPassword",
                                                -ccView => "$ccView",
                                                -primaryPSX => "$primaryPSX",
                                                ) )
                                                                                                                               
            	      {
        $logger->error(__PACKAGE__ . ".$sub_name:  Couldn't Install the images on to PSX");
        $logger->info(__PACKAGE__ . "$JobId  Test case failed ");
        return 0;
               }          
        sleep(5);           

  }else{
       $logger->info(__PACKAGE__ . " $JobId PSX Install from /sonus/ReleaseEng");
       $logger->info(__PACKAGE__ . " Inside test case");
	
        $logger->info(__PACKAGE__ . ": DUT is Identified as $DUT");
	
       #my $package = $build;             
       #$package = $package . ".tar.gz";
       
       $logger->info(__PACKAGE__ . ":Version to be loaded in PSX's is $package ");
       
      
#       unless ($psxObj2 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$primaryPSX", -ignore_xml => 1, -obj_user => 'root', -obj_password => 'sonus', -sessionlog => 1)){	
#     return 0;
#		}
       
          
       unless ( ATSInstallPSX (  -primaryPSX => "$primaryPSX",
                                 -package => "$package") )
                                                                                                                               
              {
       $logger->error(__PACKAGE__ . ".$sub_name:  Couldn't Install the images on to PSX");
       $logger->info(__PACKAGE__ . "$JobId  Test case failed ");
       return 0;
              }
              
                #call install scripts here;
  
        my $psx_cmd2 = "gunzip " . "/export/home/ssuser/" . "$package" . ".tar.gz";
        my $psx_cmd3 = "tar -xvf " . "/export/home/ssuser/" . "$package" . ".tar";
        my $psx_cmd4 = "mv /export/home/ssuser/" . "$package/*" . " /export/home/ssuser";
        my $psx_cmd5 = "/export/home/ssuser/SOFTSWITCH/SQL/UpdateDb";     
        
		
        unless ( stopPsx ("$primaryPSX") )                                                                                                                               
              {
       $logger->error(__PACKAGE__ . ".$sub_name:  Stop PSX failed");
        return 0;
              }
                   
	unless ($psxObj2 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$primaryPSX", -ignore_xml => 1, -sessionlog => 1)){	
    	$logger->info(__PACKAGE__ . ".$sub_name: PSX session creation failed..!!! ");
        return 0;
		}
      
      $psxObj2->{conn}->cmd(String  => "su root");
      $psxObj2->{conn}->cmd(String  => "sonus");
      $psxObj2->{conn}->cmd(String  => "bash");
       	
      $logger->info(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $psx_cmd2");
      my @cmdResult1 = $psxObj2->{conn}->cmd(
                                        String  => $psx_cmd2,
                                        Timeout => $Timeout,
                                      );
        
      $logger->info(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $psx_cmd3");
      @cmdResult1 = $psxObj2->{conn}->cmd(
                                        String  => $psx_cmd3,
                                        Timeout => $Timeout,
                                      ); 
               
       
         
      unless ( uninstallPsx ("$primaryPSX") )                                                                                                                               
              {
      $logger->error(__PACKAGE__ . ".$sub_name:  Un-Installation of PSX failed");
      return 0;
              }


              
      $logger->info(__PACKAGE__ . ".$sub_name: Issuing shell cmd: $psx_cmd4");
      @cmdResult1 = $psxObj2->{conn}->cmd(
                                        String  => $psx_cmd4,
                                        Timeout => $Timeout,
                                      );        
         
      unless ( installPsx ("$primaryPSX") )                                                                                                                               
              {
      $logger->error(__PACKAGE__ . ".$sub_name:  Installation of PSX failed");
      return 0;
              } 

                
      my @lines = $psxObj2->cmd("cd /export/home/ssuser/SOFTSWITCH/SQL");
      @lines = $psxObj2->cmd(Prompt=> '/ $/',Timeout => 30,Errmode=>'die',String =>"./UpdateDb");
      print @lines;
      @lines = $psxObj2->cmd(Prompt=> '/# $/',Errmode=>'return',String =>"y");
      print @lines;
      my $line;
  
         foreach $line(@lines) 
        {
      print "$line \n";  
      if($line =~ m/Database altered./)
      {
          print "DB Update in progress\n";
          
      }
        if($line =~ m/Configuring database for Auto Start and Auto Stop/)
      {
          print "DB Update is Complete\n";
           sleep(10);          
        }
         }
                 
      unless ( startPsx ("$primaryPSX") )                                                                                                                               
              {
      $logger->error(__PACKAGE__ . ".$sub_name:  PSX Start failed");
      return 0;
              }
                
         }
 	
        my $psxInstalledVersion = getPsxVer("$primaryPSX");
        
	print(": PSX Installed Version is $psxInstalledVersion \n" );
	
	if ("$psxTargetVersion" eq "$psxInstalledVersion"){
	           
            print("$JobId  PSX Testbed is Ready for Configuration & Testing \n");
           $logger->info(__PACKAGE__ . "$JobId  PSX Testbed is Ready for Configuration & Testing \n");
           return 1;                        
                                         
        }else{
       print(": PSX Installation failed Check session logs for more details \n" );
	return 0;
	}			 
                }
                
		
		case "GSX" {
				 
                                  my $package = $build;
                                  $package =~ s/GSX_//;
                                  
                                  if ($ccView ne "NULL")
				  {
					
		$logger->info(" Installing GSX with $ccView");
		print"Inside GSX Install Routine\n";
		
       $logger->info(__PACKAGE__ . ": DUT is Identified as $DUT");       
       $logger->info(__PACKAGE__ . ":build to be loaded in GSX's is $package ");

	$logger->info(__PACKAGE__ . " $JobId GSX Install from CC");
        $logger->info(__PACKAGE__ . " Inside test case");       	
        $logger->info(__PACKAGE__ . ":build to be loaded in GSX's is from $ccView ");
          
         unless ( SonusQA::GTB::INSTALLER::ATSInstallGSX ( -ccHostIp => "$ccHostIp",
                                                -ccUsername => "$ccUsername",
                                                -ccPassword => "$ccPassword",
                                                -ccView => "$ccView",
                                                -primaryGSX => "$primaryGSX",
                                                ) )
                                                                                                                               
            	      {
        $logger->error(__PACKAGE__ . ".$sub_name:  Couldn't Install the images on to GSX's");
        $logger->info(__PACKAGE__ . "$JobId  Test case failed ");
        return 0;
               }          
        sleep(5);
          } else
                                  {                                
                                  
                                  
        print "GSX Build is $package";
        $logger->info(__PACKAGE__ . "GSX Build to be loaded is = $package");
       
   # Creating a telnet session to clearcase server
        my $ssh_session = new SonusQA::Base(       -obj_host       => "$ccHostIp",
                                                   -obj_user       => "$ccUsername",
                                                   -obj_password   => "$ccPassword",
                                                   -comm_type      => 'SSH',
						   -prompt         => '/.*[\$#%>\}]\s*$/',
                                                   -obj_port       => 22,
                                                   -return_on_fail => 1,
                                                   -sessionlog     => 1,
                                                 );

    unless ( $ssh_session ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to clearcase server to copy images");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    
    $ssh_session->{conn}->cmd("bash");

    my $cmd1 = "cpsipqaimages -noconfirm -target all $primaryGSX $package";
    my @cmdresults = $ssh_session->{conn}->cmd("$cmd1");

    $logger->info(__PACKAGE__ . ".$sub_name: Executed : $cmd1");
    $logger->info(__PACKAGE__ . ".$sub_name: Successfully copied the build on to GSX!");
    sleep 60;
                                  
        }
   
        my $gsx_cmd2 = "CONFIGURE NODE NVS SHELF 1 PARAMETER MODE DISABLED";
        my $gsx_cmd3 = "CONFIGURE NODE RESTART";
	my $gsxTargetVersion = $package;
#	$gsxTargetVersion ==~ s/GSX_//;
        print "GSX Version to be Installed is $gsxTargetVersion \n";
	
	unless ($gsxObj2 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$primaryGSX", -ignore_xml => 1, -sessionlog => 1)){	
    	$logger->info(__PACKAGE__ . ".$sub_name: GSX session creation failed..!!! ");
        return 0;
		}
        
        my @cmdresults = $gsxObj2->execCmd($gsx_cmd2);
        sleep(60);
        @cmdresults = $gsxObj2->execCmd($gsx_cmd3);              
	sleep(120);
	
	unless ($gsxObj3 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$primaryGSX", -ignore_xml => 1, -sessionlog => 1)){	
    	$logger->info(__PACKAGE__ . ".$sub_name: GSX session creation failed..!!! ");
        return 0;
		}
	my $gsxInstalledVersion = $gsxObj3->{VERSION};
	print(": GSX Installed Version is $gsxInstalledVersion \n" );
	
	if ($gsxTargetVersion eq $gsxInstalledVersion){
	           
        print(": GSX Install completed copied and installed the required Images \n" );
	return 1;
	}else
				  {
	print(": GSX Installation failed Check session logs for more details \n" );
	return 0;
	}			 

		}

	}
}

=head1 dbCmd()

=over

=item DESCRIPTION:
This subroutine is used to execute a sql query, and return an array reference of the data if its a 'SELECT' query.

=item ARGUMENTS:
Mandatory Args:
$query => sql query

=item PACKAGES USED:
None

=item GLOBAL VARIABLES USED:
None

=item EXTERNAL FUNCTIONS USED:
None

=item RETURNS:
Array reference => if its success and a 'SELECT' query
0 - On Failure

=item EXAMPLE:
my $cmd ="select distinct TestBedAlias from ats_sched_testbed, ats_sched_job where ats_sched_testbed.TestBedId = ats_sched_job.TestBedId and ats_sched_job.JobId = '$JobId'";
my $testbedAlias = SonusQA::GTB::INSTALLER::dbCmd($cmd);

=back

=cut

sub dbCmd{
    my($query) = @_;

    my($databaseConn, $databaseConnRead, $databaseConnWrite);

    unless(defined($query)){
        $logger->error("dbCmd QUERY ARGUMENT WAS LEFT EMPTY");
        return 0;
    }
    if($query=~ m/SELECT/i){
        unless($databaseConnRead=SonusQA::Utils::db_connect('RODATABASE')){
            $logger->error("ERROR IN CONNECTING TO READ DB!");
            return 0;
        }
        $databaseConn = $databaseConnRead;
    }
    else{
        unless($databaseConnWrite=SonusQA::Utils::db_connect('DATABASE')){
            $logger->error("ERROR IN CONNECTING TO WRITE DB!");
            return 0;
        }
        $databaseConn = $databaseConnWrite;
    }

    my ($queryHandler,$key, $value,$row, @result);
    eval{
        $queryHandler = $databaseConn->prepare($query);
        $queryHandler->execute();
    };
    if($@){
        $logger->error("DB ERROR: ".$queryHandler->{Statement});
        return 0;
    }

    if($query=~ m/SELECT/i){
        while($row = $queryHandler->fetchrow_hashref()){
            while(($key,$value)=each %{$row}){
                if($value){push(@result,$value);}
                else{push(@result,'NULL');}
            }
        }
    }

    return \@result;
}

=head1 installElement()

=over

=item DESCRIPTION:
This subroutine is to do installation. Its called from SonusQA::GTB::Scheduler and presently using for BISTQ.
Currently support is there for SBC and PSX. 

=item ARGUMENTS:
Mandatory Args:
JobId => Scheduled job id (now for BISTQ)

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
unless(SonusQA::GTB::INSTALLER::installElement($JobId, $DUT, $testbed, $build, $ccViewLocation, $ccView)){
    $logger->error(__PACKAGE__ . ".$sub_name: Installation failed.");
    $logger->info(__PACKAGE__ . ".$sub_name:  Sub[0]-");
    return 0;
}

=back

=cut

sub installElement {
    my $sub_name = "installElement";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    my ($JobId, $DUT, $testbed, $build, $ccViewLocation, $ccView) = @_;

    my ($primary_tb,$secondary_tb) = split(/__/, $testbed);
    $secondary_tb = '' if( $secondary_tb =~ /SA/i );

    #JobId: 18474e36-1d42-11e8-a689-9e71a933126c, DUT: SBX5200, primarySBX: BGDSBCVZW, build: SBC_V05.01.00A014, ccViewLocation: , ccView: /sonus/ReleaseEng/Images/SBX5000/BISTQ/sbc-V05.01.00A014-connexip-os_03.01.00-A014_amd64.iso
    $logger->info(__PACKAGE__ . ".$sub_name: JobId: $JobId, DUT: $DUT, testbed: $testbed, primary: $primary_tb, secondary: $secondary_tb, build: $build, ccViewLocation: $ccViewLocation, ccView: $ccView");

    my $ret = 0;
    if ( $DUT =~ /^SBX/) {
        my ($build_path, $epsx_build_path) = split(',',$build);
        $ret = SonusQA::SBX5000::INSTALLER::doInstallation('-build_path' => $ccView, '-primary_sbx_alias' => $primary_tb, '-secondary_sbx_alias' => $secondary_tb, '-epsx_build_path' => $epsx_build_path, '-build_location' => $ccViewLocation);
    }
    elsif($DUT =~ /^PSX/){
        $ret = SonusQA::PSX::INSTALLER::doInstallation('-build_path' => $ccView, '-primary_testbed' => $primary_tb, '-secondary_testbed' => $secondary_tb, '-build_location' => $ccViewLocation);
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub_name: there is no support for $DUT installation in ATS. Kindly do manually and trigger BISTQ.");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$ret]-");
    return $ret;
}

1;
