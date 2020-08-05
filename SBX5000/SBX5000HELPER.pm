package SonusQA::SBX5000::SBX5000HELPER;

=head1 NAME

SonusQA::SBX5000::SBX5000HELPER- Perl module for SBC interaction

=head1 AUTHOR

sonus-ats-dev@sonusnet.com

=head1 REQUIRES

Perl5.8.7, SonusQA::Utils, Log::Log4perl, Data::Dumper, SonusQA::SBX5000, POSIX, List::Util, Sort::Versions

=head1 DESCRIPTION

Provides an interface to interact with the SBC.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use SonusQA::SBX5000;
use POSIX;
use List::Util qw(first);
use List::MoreUtils qw(onlyidx lastidx);
use Sort::Versions;

our ($TESTSUITE,$gsxObjRef,$sbxObjRef, $log_dir,@psxObj);
my ($user_home_dir,$name);

=head2 C< configureNtp >

=over

=item DESCRIPTION:

This subroutine configures the timezone on the network time protocol(NTP) server for the SBC and enables the state of the ntp peerAdmin.

=item ARGUMENTS:

 Mandatory:

        $zone   - Specifies the time zone where the node resides.
        $ip     - Specifies hte ip address of the peerAdmin(The name of this peerAdmin will be the HOSTNAME. It is fetched from the tms alias data of the SBC object. Attribute:  {CE}->{1}->{HOSTNAME}. )

 Optional: NONE

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1   - success.

=item EXAMPLES:

        $sbxObj->configureNtp($zone, $ip);

=back

=cut

sub configureNtp {
     my ($self) = shift;
     my $sub_name = "configureNtp";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

     if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&configureNtp, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
     }
     my($zone,$ip)=@_;
     my $hostname = $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME};
     my $platform = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM};

     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
     $self->execCmd("configure");
     $self->execCliCmd("set ntp timeZone $platform zone $zone");
     $self->execCliCmd("set ntp peerAdmin $hostname $ip state enabled");
     $self->execCliCmd("commit");

     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
     return 1;
}

=head2 C< setNtpServer >

=over

=item DESCRIPTION:

    This subroutine is used for configuring the NTP server for cloud SBC which by default will not have the NTP server configured.

=item ARGUMENTS:

 MANDATORY:
   None

 OPTIONAL:
   1. IP Address of NTP Server - If this value is not passed, we try to take value of ($self->{TMS_ALIAS_DATA}->{NTP}->{1}->{IP} or $self->{TMS_ALIAS_DATA}->{NTP}->{1}->{IPV6}).

=item PACKAGE:

 SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SBX5000::SBX5000HELPER::enterPrivateSession()
 SonusQA::SBX5000::SBX5000HELPER::execCommitCliCmd()
 SonusQA::SBX5000::leaveConfigureSession()

=item RETURNS:

    0   - Fail
    1   - success.

=item EXAMPLE:

        unless ($self->setNtpServer($self->{TMS_ALIAS_DATA}->{NTP}->{1}->{IP})){
            $logger->debug(__PACKAGE__ . ".$sub_name: failed to set NTP Server configuration");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

=back

=cut

sub setNtpServer {
    my $self = shift;
    my $sub_name = "setNtpServer";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&setNtpServer, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

    my $ip = shift;

    $ip ||= $self->{TMS_ALIAS_DATA}->{NTP}->{1}->{IP} || $self->{TMS_ALIAS_DATA}->{NTP}->{1}->{IPV6};
    unless($ip){
        $logger->error(__PACKAGE__ . ".$sub_name: NTP server IP is not provided. Set '{NTP}->{1}->{IP}' or '{NTP}->{1}->{IPV6}' in Testbed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $result = 1;
    unless ( $self->enterPrivateSession() ){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $ntp_server_admin_cmd = "set system ntp serverAdmin ".$ip;
    my $ntp_server_admin_state_enabled_cmd = "set system ntp serverAdmin ".$ip." state enabled";
    unless ($self->execCommitCliCmdConfirm($ntp_server_admin_cmd,$ntp_server_admin_state_enabled_cmd)){ #TOOLS-18009
        $logger->error( __PACKAGE__ . ".$sub_name: Failed to configure NTP server");
        $result = 0;
    }
    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to leave config mode.");
        $result = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$result]");
    return 1;
}

=head2 C< configureNetworkInterface >

=over

=item DESCRIPTION:

 This subroutine configures Network interface according to the signalling if it is internal it configure using internal signalling, else configure the interface using external signalling.

=item ARGUMENTS:

 Mandatory :

    1. $intname                - Specifies the Network interface name.
    2. $type                   - Specifies the type of Network  Interface .
    3. $port                   - Port number.
    4. $ip                     - The primary IP Address of the Interface.
    5. $mask                   - Defines Network mask of the Network Interface.

 Optional: NONE

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SBX5000::execClicmd

=item OUTPUT:

 1 - success.

=item EXAMPLES:

    $sbxObj->configureNetworkInterface("internalintf1","primary","port3","192.168.1.10","255.255.255.0");

=back

=cut


sub configureNetworkInterface {

     my ($self) = shift;
     my $sub_name = "configureNetworkInterface";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

     if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&configureNetworkInterface, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
     }
     my($intname,$type,$port,$ip,$mask)=@_;
     my $hostname = $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME};

     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
     if($intname =~m/internal/){
             $self->execCliCmd("set networkInterface admin $hostname internalSignaling $type interfaceName $intname ipAddress $ip portId $port mask $mask speed speed1000Mbps duplexMode full autoNegotiation on");
     }else{
             $self->execCliCmd("set networkInterface admin $hostname externalSignaling $type interfaceName $intname ipAddress $ip portId $port mask $mask speed speed1000Mbps duplexMode full autoNegotiation on");
     }
     $self->execCliCmd("commit");

     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
     return 1;
}


=head2 C< configureIpInterface >

=over

=item DESCRIPTION:

    This subroutine configures the ipInterface (with a IPv4 primary address of the interface) for the specified ipInterfaceGroup. It sets the following parameters : ipInterface name, ceName,portName, ipAddress and prefix.
    Based on the value provided for the vlan parameter- either the vlan tag is set(if vlan parameter doesn't have colon(:) in it or the altIpAddress and altPrefix are set(if the vlan parameter has colon(:) in it meaning that it is ipv6 address and the next parameter will be the altPrefix. It also enables the state and sets the mode to inService of the ipinterface which was just configured.

=item ARGUMENTS:

 Mandatory :

        $addcontext             - The address context name
        $intgpname              - The group of IP interfaces for the specified address context.
        $intname                - Specifies the IP interface name.
        $ceName                 - The name of the computing element that hosts the port used by this IP interface.
        $portName               - The physical port name used by this IP interface
        $ip                     - The primary IP Address of the Interface.
        $prefix                 - Specifies the IP subnet prefix of this Interface.
        $vlan : If this parameter does not contain a colon(:) then this specifies the vlanTag:
                vlanTag                 - Specifies the VLAN TAG assigned to this physical interface
               If vlan parameter(defined above) contains a colon(:) then this specifies the altIpAddress:
                altIpAddress            - Specifies alternative (secondary) IP address for the configured packet IP interface. (currently only ipv6 works with this subroutine.
        If vlan parameter(defined above) contains a colon(:) then the altPrefix needs to be specified:
        $altprefix               - Alternative IP subnet prefix of this interface.


 Optional: none

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - success

=item EXAMPLES:

    $sbxObj->configureIpInterface($addcontext,$intgpname, $intname,$ceName, $portName,$ip,$prefix,$vlan,$altprefix);

=back

=cut

sub configureIpInterface {
        my($self,$addcontext,$intgpname, $intname,$ceName, $portName,$ip,$prefix,$vlan,$altprefix)=@_;
        # Variables used above are: Interface Group Name, IF Group Index,
        # InterfaceName, CE Name, port Name (pck0/pkt0), IP, prefix
        # (subnet)
        my $sub_name = "configureIpInterface";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
#        $self->execCliCmd("set addressContext $addcontext ipInterfaceGroup $intgpname") ; #TOOLS-8196
        my $cmd = "set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname ceName $ceName portName $portName ipAddress $ip prefix $prefix";
        # Code to enhance passage for IPV6 and altprefix instead of vlan value Cq : SONUS00151321
        my $cmd1;
        # Checking vlan variable whether the same should treat as IPV6
        if ($vlan =~ m/\:/) {
            $cmd1 = "set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname altIpAddress $vlan altPrefix $altprefix";
        } else {
            $cmd .= " vlanTag $vlan" if (defined $vlan and $vlan);
        }
        $self->execCliCmd( $cmd );
        $self->execCliCmd("commit");
        if (defined $cmd1 and $cmd1) {
            $self->execCliCmd( $cmd1 );
            $self->execCliCmd("commit");
        }
        $self->execCliCmd("set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname mode inService state enabled");
        $self->execCliCmd("commit");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;

}

=head2 C< configureIpInterfaceV6 >

=over

=item DESCRIPTION:

 This subroutine configures the ipInterface (with IPv6 primary address of the interface) for the specified ipInterfaceGroup. It sets the following parameters : ipInterface name, ceName,portName, ipAddress,prefix, altIpAddress and altPrefix are set. The vlan tag is also optionally set if the parameter is provided. It also enables the state and sets the mode to inService of the ipinterface which was just configured.

=item ARGUMENTS:

 Mandatory :

        $addcontext,$intgpname, $intname,$ceName, $portName,$ip,$prefix,$vlan,$altprefix
        $addcontext             - The address context name
        $intgpname              - The group of IP interfaces for the specified address context.
        $intname                - Specifies the IP interface name.
        $ceName                 - The name of the computing element that hosts the port used by this IP interface.
        $portName               - The physical port name used by this IP interface
        $ip                     - The primary IP Address of the Interface.
        $prefix                 - Specifies the IP subnet prefix of this Interface.
        $ip_6                   - Specifies alternative (secondary) IP address for the configured packet IP interface. (currently only ipv6 works with this subroutine.
        $alt_prefix             - Alternative IP subnet prefix of this interface.

 Optional:

        $vlan                   - Specifies the VLAN TAG assigned to this physical interface


=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - success.

=item EXAMPLES:

 $sbxObj->configureIpInterfaceV6($addcontext,$intgpname, $intname,$ceName, $portName,$ip,$prefix,$ip_6,$alt_prefix,$vlan);

=back

=cut

sub configureIpInterfaceV6 {
         my($self,$addcontext,$intgpname, $intname,$ceName, $portName,$ip,$prefix,$ip_6,$alt_prefix,$vlan)=@_;
# Variables used above are: Interface Group Name, IF Group Index,
# InterfaceName, CE Name, port Name (pck0/pkt0), IP, prefix
# (subnet)
        my $sub_name = "configureIpInterfaceV6";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
#        $self->execCliCmd("set addressContext $addcontext ipInterfaceGroup $intgpname") ;#TOOLS-8196
        my $cmd = "set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname ceName $ceName portName $portName ipAddress $ip prefix $prefix altIpAddress $ip_6 altPrefix $alt_prefix";

        $cmd .= " vlanTag $vlan" if (defined $vlan and $vlan);
        unless ($self->execCliCmd( $cmd )) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        my @commands = ( "set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname mode inService state enabled") ;
        my $clicmd_pass = 1;
        foreach (@commands) {
            unless ( $self->execCommitCliCmd( $_  )){
                $clicmd_pass = 0;
                last;
            }
        }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$clicmd_pass]");
    return $clicmd_pass;
}

=head2 C< configureCacProfile >

=over

=item DESCRIPTION:

 This subroutine configures a call admission control (CAC) profile providing the ability for each SIP registered to have individualized limits on the number of active calls and the call rate, and enables the administrative state of this SIP CAC Profile

=item ARGUMENTS:

 Mandatory :

    1. profileName           -  $profileName
    2. profileIndex          -  $profileIndex
    3. callIngressRate       -  $ingressCallRate
    4. callIngressRatePeriod -  $ingressCallRatePeriod

 Optional: NONE

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

 1 - success

=item EXAMPLES:

    $sbxObj->configureCacProfile($profileName,$profileIndex, $ingressCallRate, $ingressCallRatePeriod)

=back

=cut

sub configureCacProfile {
        my($self,$profileName, $profileIndex, $ingressCallRate, $ingressCallRatePeriod) = @_;
        my $sub_name = "configureCacProfile";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        $self->execCliCmd("set profiles sipCacProfile $profileName id $profileIndex callIngressRate $ingressCallRate callIngressRatePeriod $ingressCallRatePeriod ");
        $self->execCliCmd("commit");
        $self->execCliCmd("set profiles sipCacProfile $profileName state enabled");
        $self->execCliCmd("commit");

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;

}

=head2 C< configureSipPeerWithCac >

=over

=item DESCRIPTION:

   This subroutine configures SipPeer with call admission control (CAC).

=item ARGUMENTS:

 Mandatory :

 	1. addressContext       - $addr
	2. zone                 - $zone
	3. sipPeer              - $peerName
	4. ipAddress            - $peerIpAddress
	5.cacProfile            - $cacProfile
	6.packetServiceProfileId -$packetServiceProfile
	7.ipSignalingProfileId  - $ipSignalingProfile
	8.description           - $desc
	9.fqdn                  - $fqdn

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

 1 - success

=item EXAMPLES:

        $sbxObj->configureSipPeerWithCac($addr, $zone, $peerName, $peerIpAddress, $cacProfile, $packetServiceProfile, $ipSignalingProfile, $desc, $fqdn);

=back

=cut

sub configureSipPeerWithCac {

        my($self,$addr, $zone, $peerName, $peerIpAddress, $cacProfile, $packetServiceProfile, $ipSignalingProfile, $desc, $fqdn) = @_;
        my $sub_name = "configureSipPeerWithCac";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $self->execCliCmd("set addressContext $addr zone $zone sipPeer $peerName ipAddress $peerIpAddress cacProfile $cacProfile state enabled packetServiceProfileId $packetServiceProfile ipSignalingProfileId $ipSignalingProfile description $desc fqdn $fqdn ");
        $self->execCliCmd("commit");

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
}

=head2 C< configureSipSigPort >

=over

=item DESCRIPTION:

   This subroutine configures Sip Signalling Port for given Zone, finds the IPversion from given IP and uses it configuring SipSigPort.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addrcontext
	2. SipSigPort           - $sigport
	3. zone                 - $zone
	4. zoneId               - $zoneid
	5. ipAddress            - $ip
	6. port                 - $port
	7. transportProtocolsAllowed    - $allowedProtocols

=item PACKAGE:
    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:
    0   - If invalid IpAddress is passed as $ip value, returns '0'
    1

=item EXAMPLES:

 $sbxObj->configureSipSigPort($addcontext,$sigport,$zone,$zoneid,$ip,$port,$allowedProtocols);

=back

=cut

sub configureSipSigPort {

	my($self,$addcontext,$sigport,$zone,$zoneid,$ip,$port,$allowedProtocols)=@_;
	my $sub_name = "configureSipSigPort";
	my $IpType;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        unless (defined $allowedProtocols) {
        $allowedProtocols = "sip-udp";
        }

	if ($ip =~ m/\:/) {
        $IpType = "ipAddressV6";
        } elsif ($ip =~ m/\./) {
        $IpType = "ipAddressV4";
        } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Invalid IP !!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
        }

        $self->execCliCmd("set addressContext $addcontext zone $zone id $zoneid");
        $self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport $IpType $ip portNumber $port transportProtocolsAllowed $allowedProtocols");
	$self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport state enabled");
	$self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureSipSigPortSBC >

=over

=item DESCRIPTION:
   This subroutine configures Sip Signalling Port on given Zone for SBC, finds the IPversion from given IP and uses it configuring SipSigPort.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addrcontext
	2. SipSigPort           - $sigport
	3. zone                 - $zone
	4. zoneId               - $zoneid
	5. ipAddress            - $ip
	6. port                 - $port
	7. ipInterfaceGroupName - $ifName
	8. transportProtocolsAllowed    - $allowedProtocols

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - If invalid IpAddress is passed as $ip value, returns '0'
    1   - success

=item EXAMPLES:

 $sbxObj->configureSipSigPortSBC($addcontext,$sigport,$zone,$zoneid,$ip,$port,$ifName,$allowedProtocols);

=back

=cut

sub configureSipSigPortSBC {

        my($self,$addcontext,$sigport,$zone,$zoneid,$ip,$port,$ifName,$allowedProtocols)=@_;
        my $sub_name = "configureSipSigPortSBC";
        my $IpType;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        unless (defined $allowedProtocols) {
        $allowedProtocols = "sip-udp";
        }

        if ($ip =~ m/\:/) {
        $IpType = "ipAddressV6";
        } elsif ($ip =~ m/\./) {
        $IpType = "ipAddressV4";
        } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Invalid IP !!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
        }

        $self->execCliCmd("set addressContext $addcontext zone $zone id $zoneid");
        $self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport $IpType $ip portNumber $port transportProtocolsAllowed $allowedProtocols ipInterfaceGroupName $ifName");
        $self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport mode inService state enabled");
        $self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureSipSigPortSBCV6  >

=over

=item DESCRIPTION:

   This subroutine configures SIP signalling port for IPV4 or IPV6.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addcontext
	2. sipSigPort           - $sigport
	3. zone                 - $zone
	4. id                   - $zoneid
	5. ip                   - $ip
	6. portNumber           - $port
	7. ipAddressV6          - $ip_v6
	8. ipInterfaceGroupName - $ifName
	9. transportProtocolsAllowed - $allowedProtocols

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - If invalid IpAddress is passed as $ip value, returns '0'
    1   - if success

=item EXAMPLES:

 $sbxObj->configureSipSigPortSBCV6($addcontext,$sigport,$zone,$zoneid,$ip,$port,$ip_v6,$ifName,$allowedProtocols);

=back

=cut

sub configureSipSigPortSBCV6 {

        my($self,$addcontext,$sigport,$zone,$zoneid,$ip,$port,$ip_v6,$ifName,$allowedProtocols)=@_;
        my $sub_name = "configureSipSigPortSBCV6";
        my $IpType;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        unless (defined $allowedProtocols) {
        $allowedProtocols = "sip-udp";
        }

        if ($ip =~ m/\:/) {
        $IpType = "ipAddressV6";
        } elsif ($ip =~ m/\./) {
        $IpType = "ipAddressV4";
        } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Invalid IP !!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
        }

        $self->execCliCmd("set addressContext $addcontext zone $zone id $zoneid");
        $self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport $IpType $ip portNumber $port transportProtocolsAllowed $allowedProtocols ipAddressV6 $ip_v6 ipInterfaceGroupName $ifName");
        $self->execCliCmd("set addressContext $addcontext zone $zone sipSigPort $sigport mode inService state enabled");
        $self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureSipTrunkGroup >

=over

=item DESCRIPTION:

   This subroutine configures SIP trunking group.

=item ARGUMENTS:

 Mandatory :
	1. addressContext               - $addcontext
	2. sipTrunkGroup                - $trunkgp
	3. zone                         - $zone
	4. id                           - $zoneid
	5. ip                           - $ip (should be a string or array reference)
	6. ingressIpPrefix              - $prefix (should be a string or array reference)
	7. mediaIpInterfaceGroupName    - $ifgName

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - success

=item EXAMPLES:

 $sbxObj->configureSipTrunkGroup($addcontext,$trunkgp,$zone,$zoneid,$ip,$prefix,$ifgName);

=back

=cut

sub configureSipTrunkGroup {

	my($self,$addcontext,$trunkgp,$zone,$zoneid,$ip,$prefix,$ifgName)=@_;
	my $sub_name = "configureSipTrunkGroup";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        $self->execCliCmd("set addressContext $addcontext zone $zone sipTrunkGroup $trunkgp media mediaIpInterfaceGroupName $ifgName");
        if(ref $ip eq "ARRAY" and ref $prefix eq "ARRAY" ){
		if ( scalar(@$ip) == scalar(@$prefix)){
                	foreach my $i (0..(scalar(@$ip)- 1)){
                		$self->execCliCmd("set addressContext $addcontext zone $zone sipTrunkGroup $trunkgp ingressIpPrefix $ip->[$i] $prefix->[$i]");
            		}
       		} else {
			$logger->warn(__PACKAGE__ . ".$sub_name: The count of ingress ip and prefix are mismatching. ingressIpPrefix will not be configured");
		}
	}else{
		$self->execCliCmd("set addressContext $addcontext zone $zone sipTrunkGroup $trunkgp ingressIpPrefix $ip $prefix");
	}
	$self->execCliCmd("set addressContext $addcontext zone $zone sipTrunkGroup $trunkgp state enabled mode inService");
	$self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureIpPeerGroup >

=over

=item DESCRIPTION:

   This subroutine configures ip peer group.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addcontext
	2. zone                 - $zone
	3. ipPeer               - $PeerGrpName
	4. ipAddress            - $peerIpAddr
	5. ipPort               - $ipPort

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - success

=item EXAMPLES:

 $sbxObj->configureIpPeerGroup($addcontext,$zone,$PeerGrpName,$peerIpAddr,$ipPort);

=back

=cut

sub configureIpPeerGroup {

        my($self,$addcontext,$zone,$PeerGrpName,$peerIpAddr,$ipPort)=@_;
        my $sub_name = "configureIpPeerGroup";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        $self->execCommitCliCmdConfirm(("set addressContext $addcontext zone $zone ipPeer $PeerGrpName ipAddress $peerIpAddr ipPort $ipPort"));  # this take care of PER-6498(V03.01.00) changes.

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureRoutingLabel >

=over

=item DESCRIPTION:

   This subroutine configures route.

=item ARGUMENTS:

 Mandatory :
	1. routingLabel         - $routingLabel
	2. routingLabelRoute    - $SeqNumber
	3. trunkGroup           - $endPoint1
	4. ipPeer               - $ipPeerGroup

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1

=item EXAMPLES:

 $sbxObj->configureRoutingLabel($routingLabel, $SeqNumber, $endPoint1,$ipPeerGroup);

=back

=cut

sub configureRoutingLabel {

        my($self,$routingLabel, $SeqNumber, $endPoint1,$ipPeerGroup)=@_;
        my $sub_name = "configureRoutingLabel";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
        $self->execCliCmd("set global callRouting routingLabel $routingLabel routingLabelRoute $SeqNumber trunkGroup $endPoint1 ipPeer $ipPeerGroup" );
        $self->execCliCmd("commit");

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
}
=head2 C< configureRouteEntity >

=over

=item DESCRIPTION:

    This subroutine configures route Entities.

=item ARGUMENTS:

 Mandatory :
    1. $routeEntityType         - Specifies the entity type.
                              The possible values are:
                                 . callingNumber
                                 . carrier
                                 . none
                                 . trunkGroup
    2. $routeEntity1           - Specifies the ID1 of the selected entityType. Depending
                             upon the entityType selection, this field will have different values.
                                 . For entityType callingNumber, the value is calling number.
                                 . For entityType carrier, the value is carrier.
                                 . For entityType none, the value is Sonus_NULL.
                                 . For entityType trunkGroup, the value is ingress trunk group
    3. $routeEntity2           - Specifies the ID2 of the selected entityType. Depending
                             upon the entityType selection, this field will have different values.
                                 . For entityType callingNumber, the value is calling country.
                                 . For entityType carrier, the value is Sonus_NULL.
                                 . For entityType none, the value is Sonus_NULL.
                                 . For entityType trunkGroup, the value is system name in upper case.
    4. $routingLabel           - Specifies the Routing Label ID which identifies a set of up to
                             200 Routes (199 or fewer Routes if you want to include an
                             Overflow Number) and/or a Script
    5. $sipMsgType              -  The sip message types are:
                                 . INFO.
                                 . NOTIFY.
                                 . REGISTER.
                                 . SUBSCRIBE.
                                 . none
    6. $destinationNational    - For standard routing,the value is the national number component of the called number.
                                 Leading digits or the complete number can be provisioned
    7. $country                - Specifies the country in which the subscriber resides.
    8. $sipDomain              - to configure the domain name for the carrier.

 Optional:
        NONE

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCliCmd

=item OUTPUT:

    None

=item EXAMPLES:

    $sbxObj->configureRouteEntity("none", "Sonus_NULL", "Sonus_NULL","RL_UNTRUSTED","none", $callednum, "1", "Sonus_NULL");

=back

=cut

sub configureRouteEntity {
        my($self,$routeEntityType, $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType, $destinationNational, $country, $sipDomain) = @_;
        my $sub_name = "configureRouteEntity";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        my $ret_val = $self->execCommitCliCmd("set global callRouting route $routeEntityType $routeEntity1  $routeEntity2 standard $destinationNational $country nationalType subscriberType,nationalType ALL $sipMsgType $sipDomain routingLabel $routingLabel");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
        return $ret_val;

}

=head2 C< configureRouteEntityNone >

=over

=item DESCRIPTION:

    This subroutine is used to configure route for the entity type 'none'.
    Internally, it calls SonusQA::SBX5000::SBX5000HELPER::configureRouteEntity with the entity type as 'none'.

=item ARGUMENTS:

 Mandatory:
    1: callParameterFilterProfile - specify the Call Parameter Filter Profile associated with this route.
    2: destinationNational - for standard routingType, the value is the national number component of the called number.
    3: destinationCountry - for standard routingType, the value is the called country code.
    4: domainName - specify the destination domain name. The destination domain name is a reference to the sipDomain.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

    $sbxObj->configureRouteEntityNone("RL_EAST_TRUSTED-B","none", "9810001234", "1", "Sonus_NULL");

=back

=cut

sub configureRouteEntityNone {
        my($self, $routingLabel, $sipMsgType, $destinationNational, $country, $sipDomain) = @_;
        my $sub_name = "configureRouteEntityNone";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        my $ret_val = $self->configureRouteEntity("none", "Sonus_NULL", "Sonus_NULL", $routingLabel, $sipMsgType,  $destinationNational, $country, $sipDomain);

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
        return $ret_val;
}

=head2 C< configureRouteEntityTrunkGroup >

=over

=item DESCRIPTION:

    This subroutine is used to configure route for the entity type "trunkGroup".
    Internally, it calls SonusQA::SBX5000::SBX5000HELPER::configureRouteEntity with the entity type as "trunkGroup".

=item ARGUMENTS:

=item Mandatory:
    1. elementId1 - specify the ID1 of the selected entityType. For entityType trunkGroup, the value is ingress trunkgroup.
    2. elementId2 - specify the ID2 of the selected entityType. For entityType trunkGroup, the value is system name in upper case.
    3. routingLabel - specify the Routing Label ID which identifies a set of up to 200 Routes (199 or fewer Routes if you want to include an Overflow Number).
    4. callParameterFilterProfile - specify the Call Parameter Filter Profile associated with this route.
    5. destinationNational - for standard routingType, the value is the national number component of the called number.
    6. destinationCountry - for standard routingType, the value is the called country code.
    7. domainName - specify the destination domain name. The destination domain name is a reference to the sipDomain.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

    $sbxObj->configureRouteEntityTrunkGroup("IPTG_UNTRUSTED",uc($sbxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM}),"RL_TRUSTED","none","Sonus_NULL" , "1", "Sonus_NULL");

=back

=cut

sub configureRouteEntityTrunkGroup {
        my($self, $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType, $destinationNational, $country, $sipDomain) = @_;
        my $sub_name = "configureRouteEntityTrunkGroup";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        my $ret_val = $self->configureRouteEntity("trunkGroup", $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType, $destinationNational, $country, $sipDomain);

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
        return $ret_val;
}

=head2 C< configureRouteEntityCarrier >

=over

=item DESCRIPTION:

    This subroutine is used to configure route for the entity type "carrier".
    Internally, it calls SonusQA::SBX5000::SBX5000HELPER::configureRouteEntity with the entity type as "carrier".

=item ARGUMENTS:

 Mandatory:
    1. elementId1 - specify the ID1 of the selected entityType. For entityType carrier, the value is carrier.
    2. elementId2 - specify the ID2 of the selected entityType. For entityType carrier, the value is Sonus_NULL.
    3. routingLabel - specify the Routing Label ID which identifies a set of up to 200 Routes (199 or fewer Routes if you want to include an Overflow Number).
    4. callParameterFilterProfile - specify the Call Parameter Filter Profile associated with this route.
    5. destinationNational - for standard routingType, the value is the national number component of the called number.
    6. destinationCountry - for standard routingType, the value is the called country code.
    7. domainName - specify the destination domain name. The destination domain name is a reference to the sipDomain.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

    $sbxObj->configureRouteEntityCarrier($carrier,'Sonus_NULL','RL_TRUSTED','none','Sonus_NULL','1','Sonus_NULL');

=back

=cut

sub configureRouteEntityCarrier {
        my($self, $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType,  $destinationNational, $country, $sipDomain) = @_;
        my $sub_name = "configureRouteEntityCarrier";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        my $ret_val = $self->configureRouteEntity("carrier", $routeEntity1, "Sonus_NULL", $routingLabel,$sipMsgType,  $destinationNational, $country, $sipDomain);

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
        return $ret_val;
}

=head2 C< configureRouteEntityCallingNumber >

=over

=item DESCRIPTION:

    This subroutine configures Calling numbers route Entities.

=item ARGUMENTS:

 Mandatory :
    1. $routeEntity1           - Specifies the ID1 of the selected entityType. Depending
                             upon the entityType selection, this field will have different values.
                                 . For entityType callingNumber, the value is calling number.
                                 . For entityType carrier, the value is carrier.
                                 . For entityType none, the value is Sonus_NULL.
                                 . For entityType trunkGroup, the value is ingress trunk group
    2. $routeEntity2           - Specifies the ID2 of the selected entityType. Depending
                             upon the entityType selection, this field will have different values.
                                 . For entityType callingNumber, the value is calling country.
                                 . For entityType carrier, the value is Sonus_NULL.
                                 . For entityType none, the value is Sonus_NULL.
                                 . For entityType trunkGroup, the value is system name in upper case.
    3. $routingLabel           - Specifies the Routing Label ID which identifies a set of up to
                             200 Routes (199 or fewer Routes if you want to include an
                             Overflow Number) and/or a Script
    4. $sipMsgType              -  The sip message types are:
                                 . INFO.
                                 . NOTIFY.
                                 . REGISTER.
                                 . SUBSCRIBE.
                                 . none
    5. $destinationNational    - For standard routing,the value is the national number component of the called number.
                             Leading digits or the complete number can be provisioned
    6. $country                - Specifies the country in which the subscriber resides.
    7. $sipDomain              - to configure the domain name for the carrier.

 Optional:
        NONE

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLES:

    $sbxObj->configureRouteEntityCallingNumber("Sonus_NULL", "Sonus_NULL","RL_UNTRUSTED","none", $callednum, "1", "Sonus_NULL");

=back

=cut


sub configureRouteEntityCallingNumber {
        my($self, $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType,  $destinationNational, $country, $sipDomain) = @_;
        my $sub_name = "configureRouteEntityCallingNumber";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        my $ret_val = $self->configureRouteEntity("callingNumber", $routeEntity1, $routeEntity2, $routingLabel, $sipMsgType,  $destinationNational, $country, $sipDomain);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
        return $ret_val;
}

=head2 C< configureStaticRoute >

=over

=item DESCRIPTION:

   This subroutine is used to configure the static route in SBX and executes the command with the parameters passed as input.
   Also it executes commit command after executing the command.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addrcontext (bydefault, value is default)
	2. Endpoint machine Ip  - $remoteIp
	3. Prefix               - $prefix
	4. gateway of SBC       - $nextHop
	5. interface Name       - $ifName
	6. preference           - $pref
	7. interface group      - $ifGroup

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCliCmd

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->configureStaticRoute($addcontext, $remoteIp, $prefix, $nextHop, $ifName,$pref,$ifGroup) ;
         Example : set addressContext default staticRoute 10.70.53.87 32 10.7.1.1 LIF1 PKT0_V4 preference 100 ;

=back

=cut

sub configureStaticRoute {
         my($self,$addcontext, $remoteIp, $prefix, $nextHop, $ifName,$pref,$ifGroup)=@_;
# Variables used above are: Interface Group Name, IF Group Index,

        my $sub_name = "configureStaticRoute";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        unless ($self->execCommitCliCmd("set addressContext $addcontext staticRoute $remoteIp $prefix $nextHop $ifGroup $ifName preference $pref")) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Unable to execute the command");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

    	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    	return 1;
}

=head2 C< configureAltMedia >

=over

=item DESCRIPTION:

        This subroutine configures the alternate media ip address for the specified ipInterfaceGroup. It sets the following parameters : address context, ip interface group name,ip interface name, alternate media ipAddress.

       Added for configuring packet ports during performance activities #JIRA-8949

=item ARGUMENTS:

 Mandatory :

        $addcontext             - The address context name
        $intgpname              - The group of IP interfaces for the specified address context.
        $intname                - Specifies the IP interface name.
        $altMediaIp             - The primary IP Address of the alternate media.


 Optional:
    none

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

    $sbxObj->configureAltMedia($addcontext,$intgpname, $intname,$atlMediaIp);

=back

=cut

sub configureAltMedia {
        my($self,$addcontext,$intgpname, $intname,$atlMediaIp)=@_;
        # Variables used above are: Interface Group Name, IF Group Index,
        my $sub_name = "configureAltMedia";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

       unless ($self->execCommitCliCmd("set addressContext $addcontext ipInterfaceGroup $intgpname ipInterface $intname altMediaIpAddress $atlMediaIp")) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Unable to execute the command");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;

}

=head2 C<configureIPSignalingProfile >

=over

=item DESCRIPTION:
   The subroutine is used to configure the IP signalling profile for the listed profile name passed as parameter.
   It also issues commit command after the signalling command.

=item ARGUMENTS:

 Mandatory :
	1. Profile Name : $profileName

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    1

=item EXAMPLES:

 unless ($sbxObj->configureIPSignalingProfile($profileName)) {
    $logger->error(__PACKAGE__ . ".$sub_name: --> Failed to configure ip signalling profile ");
    return 0 ;
    }

=back

=cut

sub configureIPSignalingProfile {
	my($self,$profileName)=@_;
	my $sub_name = "configureIPSignalingProfile";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


	$logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
	$self->execCliCmd("set profiles signaling ipSignalingProfile $profileName ipProtocolType sipOnly egressIpAttributes transport type1 udp");
	$self->execCliCmd("set profiles signaling ipSignalingProfile $profileName commonIpAttributes optionTagInRequireHeader suppressReplaceTag enable" );
	$self->execCliCmd("set profiles signaling ipSignalingProfile $profileName commonIpAttributes optionTagInSupportedHeader suppressReplaceTag enable");
	$self->execCliCmd("set profiles signaling ipSignalingProfile $profileName commonIpAttributes callTransferFlags handleIpAddressesNotPresentInNetworkSelectorTableNst routeViaTransferringIptg");
        $self->execCliCmd("set profiles signaling ipSignalingProfile $profileName ingressIpAttributes flags sendSdpIn200OkIf18xReliable enable sendSdpInSubsequent18x enable");
        $self->execCliCmd("set profiles signaling ipSignalingProfile $profileName egressIpAttributes flags disable2806Compliance enable");
        $self->execCliCmd("set profiles signaling ipSignalingProfile $profileName egressIpAttributes privacy transparency disable privacyInformation remotePartyId flags includePrivacy enable privacyRequiredByProxy enable");
        $self->execCliCmd("set profiles signaling ipSignalingProfile $profileName egressIpAttributes redirect mode acceptRedirection");
        $self->execCliCmd("set profiles signaling ipSignalingProfile $profileName egressIpAttributes sipHeadersAndParameters includeChargeInformation includeNone flags includeCic enable includeNpi enable includeOlip enable includePstnParameters enable");

	$self->execCliCmd("commit");

	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    	return 1;
}

=head2 C< getRecentLogFiles >

=over

=item DESCRIPTION:

   - the self object points to the root session of the active box
   - logs into the directory : cd /var/log/sonus/sbx/evlog
   - executes the ls -ltr command and grep the latest number of files (as passed as parameter)
   - output is stored in an array and returned in successful case else returns 0.

=item ARGUMENTS:

 Mandatory :
	1. Log Type                         : $log_type  (example DBG, ACT etc)
	2. Number of latest file required   : $numberoffiles

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    @file_name   - success
    0            - failure

=item EXAMPLES:

 @filename = $dut->getRecentLogFiles("DBG",1);

=back

=cut

sub getRecentLogFiles {

    my ($self,$log_type, $numberoffiles) = @_ ;

    my $sub_name = "getRecentLogFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Log_type Undefined; ";
        return 0;
    }

    #checking if D_SBC,
    #execute only for S_SBC as it will contain each type of logs
    #to get the logs for different personality of SBC, the subroutine will be called using appropriate object
    if ($self->{D_SBC}) {
        my $sbc_type = (exists $self->{S_SBC}) ? 'S_SBC' : 'I_SBC';
        $self = $self->{$sbc_type}->{1};
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type)");
    }

    my $ce = $self->{ACTIVE_CE}; # root session name pointing to active CE
    my $cmd="cd /var/log/sonus/sbx/evlog";
    unless ( my ($res) = _execShellCmd($self->{$ce}, $cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd on $ce.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	 $main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd Execution Failed; ";
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the latest $numberoffiles $log_type log files.");

    #redirecting error message to /dev/null, so that it won't affect the output check
    $cmd="ls -ltr *.$log_type* 2> /dev/null |tail -$numberoffiles";
    my @cmd_results;
    unless ( @cmd_results = $self->{$ce}->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@cmd_results.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to get RecentLog; ";
        return 0;
    }

    chomp @cmd_results;
    $self->{CMDRESULTS} = \@cmd_results;

    my @file_name;
    foreach ( @{$self->{CMDRESULTS}} )
    {
        chomp;
        push @file_name,(split /\s+/,$_)[-1];
    }

    unless ( my ($res) = _execShellCmd($self->{$ce}, "cd")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:\'cd\' to get into home directory");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub filenames : @file_name");
    my $return = $#file_name +1;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$return]");
    return @file_name;
}

=head2 C<configureH323SigPortSBC >

=over

=item DESCRIPTION:

   The subroutine is used to configure the signalling port of SBX based on the parameter passed.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addrcontext (bydefault, value is default)
	2. zone                 - $zone
	3. zone id              - $zoneid
	4. H323signalling port  - $sigport
	5. Ip Interface Group   - $interfaceGroupName
	6. IP Address of H245   - $h245ip
	7. IP Address of H225   - $h225ip
	8. port Number          - $port

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success
    0   - failure

=item EXAMPLES:

 unless ($sbxObj->configureH323SigPortSBC($addcontext, $zone, $zoneid, $sigport, $interfaceGroupName, $h225ip, $h245ip, $port) ) {
    $logger->return(__PACKAGE__ . ".$sub_name: --> failed");
    return 0 ;
 }

=back

=cut

sub configureH323SigPortSBC {

    my($self, $addcontext, $zone, $zoneid, $sigport, $interfaceGroupName, $h225ip, $h245ip, $port)=@_;
    my $sub_name = "configureH323SigPort";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");


    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @CliCmdList = (
        "set addressContext $addcontext zone $zone id $zoneid h323SigPort $sigport ipInterfaceGroupName $interfaceGroupName h245IpAddress $h245ip h225IpAddress $h225ip portNumber $port mode inService state enabled",
        'commit',
    );

    foreach (@CliCmdList) {
        unless ( $self->execCliCmd($_) ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Execution of CLI command \'$_\' - FAILED");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        };
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureH323TrunkGroup >

=over

=item DESCRIPTION:

   The subroutine is used to configure the h323 Trunk Group based on the parameter passed.
   it sends a commit command after executing the configuring commands.

=item ARGUMENTS:

 Mandatory :
	1. addressContext       - $addrcontext (bydefault, value is default)
	2. zone                 - $zone
	3. trunk group value    - $trunkgrp
	4. ingress ip           - $ingress_ip
	5. Ingree ip prefix     - $prefix
	6. IP interface group name - $ifgName

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    1   - success
    0   - failure

=item EXAMPLES:

 unless ($sbxObj->configureH323TrunkGroup($addcontext, $zone, $trunkgrp, $ingress_ip, $prefix, $ifgName) ) {
    $logger->return(__PACKAGE__ . ".$sub_name: --> failed to configure");
    return 0 ;
 }

=back

=cut

sub configureH323TrunkGroup {

    my($self, $addcontext, $zone, $trunkgrp, $ingress_ip, $prefix, $ifgName)=@_;
    my $sub_name = "configureH323TrunkGroup";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my $count = 1 ;
    foreach ($addcontext, $zone, $trunkgrp, $ingress_ip, $prefix, $ifgName) {
        unless(defined ($_) && ($_ !~ m/^\s*$/)) {
            $logger->warn(__PACKAGE__ . ".$sub_name: --> couldn't find the value of the \'$count\' parameter");
        }
        $count++ ;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub with ip $ingress_ip");

    #TOOLS-16964 - Changed the order of the cmds..
    my @CliCmdList = (
        "set addressContext $addcontext zone $zone h323TrunkGroup $trunkgrp media mediaIpInterfaceGroupName $ifgName" ,
        "set addressContext $addcontext zone $zone h323TrunkGroup $trunkgrp mode inService state enabled ingressIpPrefix $ingress_ip $prefix",
        'commit',
    );

    foreach (@CliCmdList) {
        unless ( $self->execCliCmd($_) ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Execution of CLI command \'$_\' - FAILED");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        };
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< parsePsxLogFile >

=over

=item DESCRIPTION:

   The subroutine is used to configure the h323 Trunk Group based on the parameter passed.
   it sends a commit command after executing the configuring commands.

=item ARGUMENTS:

 Mandatory :
        1. addressContext       - $addrcontext (bydefault, value is default)
        2. zone                 - $zone
        3. trunk group value    - $trunkgrp
        4. ingress ip           - $ingress_ip
        5. Ingree ip prefix     - $prefix
        6. IP interface group name - $ifgName

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1   - success
    0   - failure

=item EXAMPLES:

 unless ($sbxObj->parsePsxLogFile($addcontext, $zone, $trunkgrp, $ingress_ip, $prefix, $ifgName) ) {
    $logger->return(__PACKAGE__ . ".$sub_name: --> failed to parse Psx Log File");
    return 0 ;
 }

=back

=cut

sub parsePsxLogFile {

    my ($self,$strHash,$locReference) = @_ ;
    my $sub_name = "parsePsxLogFile";
    my %strHash = %$strHash;
    my ($key,$ref,$ref1);
    my $count = 0;
    my $count1 = 0;
    my $length;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $strHash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input Hash Reference is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $locReference ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input location reference is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @logfile = $self->getRecentLogFiles("DBG",1);
    my $cmd="cd /var/log/sonus/sbx/evlog";
    my ($res, @result) = _execShellCmd($self->{$self->{ACTIVE_CE}}, $cmd); #executing using root obj
    unless ($res) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n". Dumper(\@result));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-$cmd Execution Failed; ";
        return 0;
    }

   unless ($logfile[0]){
       $logger->debug(__PACKAGE__ . ".$sub_name: Failed to get the recent DBG log file name, skipping checking for pattern, calling \'leaveDshLinuxShell\' ");
   }else{
       foreach $key (keys %strHash )  {
           my $cmd1 = "grep -A $locReference -m 1 \"$key\" $logfile[0]";
	   my ($res1, @temp) = _execShellCmd($self->{$self->{ACTIVE_CE}}, $cmd1);
           unless ($res1) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n".Dumper(\@temp));
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
           }
           my @temp1 = @{$strHash{$key}};
           $length = @temp1;
           $count1 = $length + $count1;
           $logger->debug(__PACKAGE__ . ".$sub_name: Input Data: @temp1 ");
           foreach $ref1 (@temp) {
               $ref1 =~ s/\s+$//;
               $ref1 =~ s/^\s+//;
               foreach $ref (@temp1) {
                   if ($ref1 =~ m/$ref/) {
                       $logger->debug(__PACKAGE__ . ".$sub_name:   Key: $key    Expected: $ref    Match Success !!");
                       $count++;
                       last;
                   }
               }
           }
       }
   }
   unless ( my ($res) = _execShellCmd($self->{$self->{ACTIVE_CE}}, "cd")) {
       $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:\'cd\' to get into home directory");
   }

    if(($count == 0) || ($count != $count1)){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

}

=head2 C< verifyMultipleCDR >

=over

=item DESCRIPTION:

    This subroutine actually uses the camDecoder.pl file (maintained in the library in the same path of SBX5000HELPER.pm) to decode the ACT file and does CDR matching with the output decode file. This API matches both the Fields and Sub-Fields in the record. This API also works for verifying multiple records.

 Note:

 1. Please do 'svn up camDecoder.pl' in the same path where SBX5000HELPER.pl is stored.
 2. The camDecoder.pl file has to be checked in here each time a Clearcase build results in a new version of this file.

=item ARGUMENTS:

 Optional:

	1. %cdrHash (cdr record hash with index and its corresponding value)

=item EXAMPLE:

 %cdrHash = ( START => {1 =>
	 	           { 6 => "orgCgN=3042010001",
			     7 => "dldNum=3042010004" }
			    },
	     STOP  => {1 =>
			   { 6 => "orgCgN=3042010001" }
			   } );

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)

=item EXAMPLES:
Usage for old one:
 my %cdrHash = ( 'START' => {'0' =>
                             { '6' => 'orgCgN=3042010001',
                               '7' => 'dldNum=3042010004' }
                             },
                'STOP'  => {'0' =>
                             { '6' => 'orgCgN=3042010001' }
                             },
               '-log_type' =>  'CDR');

Usage for newer ones :
 my %cdrHash = ( 'STOP'  => {'0' =>
                             { '231_mediaType1' => 'orgCgN=3042010001' }
                             },
               '-log_type' =>  'CDR');

 $SBXObj->verifyMultipleCDR ( %cdrHash );

=back

=cut

sub verifyMultipleCDR {

    my ($self, %cdrref) = @_ ;
    my $sub_name = "verifyMultipleCDR()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered with args - ", Dumper(\%cdrref));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    my $actfile;
    my $log_type = $cdrref{-log_type} || 'ACT';
    #Get the latest .ACT or .ACT.OPEN file from the SBC
    unless ($actfile = $self->getRecentLogViaCli($log_type)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get the current $log_type logfile" );
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    #Deleting log_type from hash
    delete($cdrref{-log_type});

    $logger->info(__PACKAGE__ . ".$sub_name: Got the Latest $log_type file to perform CDR verification: $actfile");
    
    unless ( %cdrref ) {
        $logger->info(__PACKAGE__ . ".$sub_name: hash reference is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return ({}, 0);
    }

    #checking if D_SBC,
    #By default execute only for S_SBC
    #to verify the CDR for different personality of SBC, call the subroutine with appropriate object
    if ($self->{D_SBC}) {
         my $sbc_type = (exists $self->{S_SBC}) ? 'S_SBC' : 'I_SBC';
         my $index ;
         foreach (keys %{$self->{$sbc_type}}){
             $index = $_ ;
             my $role = $self->{$sbc_type}->{$index}->{'REDUNDANCY_ROLE'};
             last if ($role =~ /ACTIVE/ );
         }
         $self = $self->{$sbc_type}->{$index};
         $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type->$index)");
    }

    my $retry = 1;
    RETRY:

    my ($getcdrresult,$cdr) = $self->getCDR(-actfile     => $actfile,
                                            -returnarray => 1);

    unless($getcdrresult) {
        $logger->error(__PACKAGE__.".$sub_name: Error getting CDR data.");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    my @cdr_record = @$cdr;
    unless( @cdr_record) {
        $logger->error(__PACKAGE__ . ".$sub_name: CDR Record is empty");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    
    chomp @cdr_record;
    #verifying the record index in the temporary camdecoder output file
    my $flag1 = 1;  #sets the return value

    my (@lines, %record_lines); #holds line number of perticular record occurance in decode file

    foreach my $recordtype (keys %cdrref) {
        #grep around decoded content for required record type, store the line numbers
        unless(@{$record_lines{$recordtype}} = grep { $cdr_record[$_] =~ /^Record\s*\d*\s*'($recordtype)'$/} 0..$#cdr_record) {
            $flag1 = 0;
            $logger->debug(__PACKAGE__. ".$sub_name: cdr_record : ". Dumper(\@cdr_record));
            if($retry){
                $retry = 0;
                $logger->warn(__PACKAGE__ . ".$sub_name: No $recordtype Records are presnt in decoded result. Sleeping for 1s and getting cdr again");
                sleep 1;
                goto RETRY;
            }
            $logger->error(__PACKAGE__ . ".$sub_name: No $recordtype Records are presnt in decoded result");
        } else {
            push (@lines, @{$record_lines{$recordtype}}); #gets all records line number into an array
        }
    }

    my (%matchedHash, %unmatchedHash);
    foreach my $recordtype (keys %cdrref) {
        INDEX: foreach my $index (sort keys %{$cdrref{$recordtype}}) {
	    my %notFound = %{$cdrref{$recordtype}{$index}};
            my $start = $record_lines{$recordtype}->[$index]; #sets start line number for the search

            unless (defined $start) {
                $logger->error(__PACKAGE__ . ".$sub_name: No CDR found for $recordtype ->$index");
                $flag1 = 0;
		$unmatchedHash{$recordtype}{$index}{"No CDR"} = "No CDR found for $recordtype -> $index";
		next INDEX;
            }
            my $end = first{ $_ > $start} @lines; # sets the end line number for the search
            $end ||= $#cdr_record; # if no end line number then, ending line number is end of file
            #lets sort both int and decimal part separatly
            foreach my $input_key ( sort { versioncmp($a, $b) } keys %{$cdrref{$recordtype}{$index}} ) {
                my $input_key1 = ($input_key =~ /\./) ? $input_key : $input_key . '.';
                SEARCH: foreach my $key ($start..$end) {
                    my $value = $cdr_record[$key];
                    if ($value =~ /^\s*($input_key1)\s+(.*):\s+(.*)$/i) {
                        my @array = split (' ', $value);
                        my $match = $3;
                        my $field = $2;
                        delete $notFound{$input_key};
                        # avoiding " in pattern
                        $match =~ s/\"//g;
                        my $pattern = $cdrref{$recordtype}{$index}{$input_key};
                        $pattern =~ s/\"//g;
                        if(my $actualsystemname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME} ){ #8520
                            $pattern = $actualsystemname if($input_key =~ /^2\.?$/);
                            unless($self->{ERE} == 1){ #TOOLS-17148 Added ERE support
                                $actualsystemname = uc $actualsystemname;
                                $pattern =~ s/(\S+)\:/$actualsystemname\:/ if(($input_key =~ /^28\.?$/ and $recordtype =~ /ATTEMPT|INTERMEDIATE/i) || ($input_key =~ /^26\.?$/ and $recordtype =~ /START/i) || ($input_key =~ /^31\.?$/ and $recordtype =~ /STOP/i) );
                                $logger->debug(__PACKAGE__ . ".$sub_name: Pattern is changed  to \'$actualsystemname\'");
                            }
                        }  # 8520

			#START TOOLS-18594
			if($self->{'AWS_HFE'}){

#Same changes as in SIPP.pm file for AWS.
#Considering, NODE -> 2 -> IP as Private IP and NODE -> 1 -> IP as Public IP.
#Private IP is changed with Public IP
			    $pattern =~ s/$main::TESTBED{'sipp:1:ce0:hash'}->{NODE}->{2}->{IP}/$main::TESTBED{'sipp:1:ce0:hash'}->{NODE}->{1}->{IP}/ if($input_key =~ /^(126|36)\.?$/);

#SIG_SIP/PKT_NIF -> 1 -> IP is changed to HFE -> 1 -> IP, because Next Hop IP is changed.
			    $pattern =~ s/($self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IP}|$self->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP})/$self->{TMS_ALIAS_DATA}->{HFE}->{1}->{IP}/ if($input_key =~ /^(125|36)\.?$/);
                        }
			#END TOOLS-18594

                        # Check for some Key Words in the text of the pattern
                        # PARTIAL = Allow a match if only some of the field pattern match the string.  For example just the IP is OK, but the port doesn't matter.
                        # RANGE   = Value is numeric and needs to be between two values.
                        my $is_match = 0;            # Default to no match
                        if ( index ($pattern, "PARTIAL") != -1 ) {
                            # This is a partial match, allow it to pass if the text is found anywhere in the string
                            # Strip out the "PARTIAL " keyword
                            $pattern =~ s/PARTIAL//g;
                            if (index($match, $pattern) != -1) {
                                $is_match = 1;
				$matchedHash{$recordtype}{$index}{$input_key} = $pattern;
                            }
                            else {
                                $logger->debug(__PACKAGE__ . ".$sub_name: Did not Match CDR expected for $array[0] Partial Match Field : $pattern CDR Actual : $match at line number " . ($key+1) ." of decoded result file");
				$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR Mismatch; ";
				$unmatchedHash{$recordtype}{$index}{$input_key} = "$field Actual Value -> $match.\t Expected Value -> $cdrref{$recordtype}{$index}{$input_key}";
                            }
                        }
                        elsif ( index ($pattern, "RANGE") != -1 ) {
                            # Allow the value to be in a range of numbers with a lower and upper bound.
                            # Strip out the "RANGE" keyword
                            my $lowerBound;
                            my $upperBound;
                            $pattern =~ s/RANGE//g;
                            ($lowerBound, $upperBound) = split (' ', $pattern);      # Break into lower @ upper bound.
                            if ( $match >= $lowerBound && $match <= $upperBound )  {
                                $is_match = 1;
				$matchedHash{$recordtype}{$index}{$input_key} = $pattern;
                            }
                            else {
                                $logger->debug(__PACKAGE__ . ".$sub_name: Did not Match CDR expected range for $array[0] Allowed Range: $lowerBound to $upperBound CDR Actual : $match at line number " . ($key+1) ." of decoded result file for $recordtype");
				$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR Mismatch; ";
				$unmatchedHash{$recordtype}{$index}{$input_key} = "$field Actual Value -> $match.\t Expected Value -> $cdrref{$recordtype}{$index}{$input_key}";
                            }
                        }
                        elsif(index ($pattern,"REGEX") != -1) {
                          # Allow the value to be in format of the regex.
                          # Strip out the "REGEX" keyword
                          $pattern =~ s/REGEX//g;
                          if ( $match =~ $pattern )  {
                              $is_match = 1;
                              $matchedHash{$recordtype}{$index}{$input_key} = $pattern;
                          }
                          else  {
                            $logger->error(__PACKAGE__ . ".$sub_name: Did not Match CDR expected for $array[0] Regex Field : $pattern CDR Actual : $match at line number " . ($key+1) ." of decoded result file for $recordtype");
                            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR Mismatch; ";
                            $unmatchedHash{$recordtype}{$index}{$input_key} = "$field Actual Value -> $match.\t Expected Value -> $cdrref{$recordtype}{$index}{$input_key}";
                          }
                        }                        
                        # Default - Use and exact string match
                        else  {
                            if ($pattern eq $match) {
                                $is_match = 1;
				$matchedHash{$recordtype}{$index}{$input_key} = $pattern;
                            }
                            else  {

                                $logger->debug(__PACKAGE__ . ".$sub_name: Did not Match CDR expected for $array[0] Exact Match Field : $pattern CDR Actual : $match at line number " . ($key+1) ." of decoded result file for $recordtype");
				$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR Mismatch; ";
				$unmatchedHash{$recordtype}{$index}{$input_key} = "$field Actual Value -> $match.\t Expected Value -> $cdrref{$recordtype}{$index}{$input_key}";
			    }
                        }

                        if ( $is_match ) {
                            $logger->info(__PACKAGE__ . ".$sub_name: Matched CDR expected for $array[0] Field : $pattern CDR Actual : $match, at line number " . ($key+1) ." of decoded result file for $recordtype" );
                            $start = $key; # present line is considered as start line for the search of next CDR input_key of current record type
                            last SEARCH;
                        } else {
                            $flag1 = 0;
                            $start = $key; # present line is considered as start line for the search of next CDR input_key of current record type
                            last SEARCH;
                        }
                    }
                }
	    }
	    foreach my $notFoundKey (keys %notFound) {
		$logger->debug(__PACKAGE__ . ".$sub_name: $recordtype -> $index -> $notFoundKey field is missing from the records!");
		$unmatchedHash{$recordtype}{$index}{$notFoundKey} = "Field is missing from the records!";
		$flag1 = 0;
	    }
	}
    }

    undef @cdr_record;

    if($flag1){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return (\%matchedHash, 1);
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return (\%unmatchedHash, 0);
    }
}


=head2 C< verifyCDR >

=over

=item DESCRIPTION:

    This subroutine actually uses the camDecoder.pl file (maintained in the library in the same path of SBX5000HELPER.pm) to decode the ACT file and does CDR matching with the output decode file. This API matches both the Fields and Sub-Fields in the record. This subroutine internally calls getCDR(found in this package) to get the content of the output decode file.

 Note:

 1. Please do 'svn up camDecoder.pl' in the same path where SBX5000HELPER.pl is stored.
 2. The camDecoder.pl file has to be checked in here each time a Clearcase build results in a new version of this file.

=item ARGUMENTS:

=item Mandatory :
 1. ACT file (for which the records needs to be matched)

=item Optional:
 1. $recordtype (Type of record to be matched ie...START, STOP etc)
 2. %cdrHash (cdr record hash with index and its corresponding value)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)

=item EXAMPLES:

 $SBXObj->verifyCDR($actfile, $recordType, %cdrHash);

=back

=cut

sub verifyCDR {

    my ($self,$actfile, $recordtype,%cdrref,%options,$returnmismatched,$cdrvariation);
    $self = shift;
    $actfile = shift;
    $recordtype = shift;
    $returnmismatched = 0;
    if( ref ( $_[0] ) eq "HASH" ) {
        my $options = shift;
        %options = %$options;
        $returnmismatched = $options{-returnmismatched};
	$cdrvariation = $options{-cdrvariation};
        %cdrref = @_;
    }else{
        %cdrref = @_;
    }
    my (%returnhash,$getcdrresult,$cdr,@inputcdr,@cdr_record,%matchfail);
    if ( defined $cdrref{-cdrvariation} ){
        $cdrvariation = $cdrref{-cdrvariation};
        delete $cdrref{-cdrvariation};
    }
    if ( defined $cdrref{-returnmismatched} ){
        $returnmismatched = $cdrref{-returnmismatched};
        delete $cdrref{-returnmismatched};
    }
    $returnmismatched ||= 0;
    $cdrvariation ||= 0;
    my $sub_name = "verifyCDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered with args - ", Dumper(\%cdrref));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $actfile ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory actfile empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( %cdrref ) {
        $logger->error(__PACKAGE__ . ".$sub_name: hash reference is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }

    #checking if D_SBC,
    #By default execute only for S_SBC
    #to get the CDR for different personality of SBC, call the subroutine with appropriate object
    if ($self->{D_SBC}) {
        my $sbc_type = (exists $self->{S_SBC}) ? "S_SBC" : "I_SBC";
        $self = $self->{$sbc_type}->{1};
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type)");
    }

    map { push @inputcdr,$_} keys %cdrref;

    my $ref_cdr = ref($actfile);
    if($ref_cdr eq 'ARRAY'){
        @cdr_record = @$actfile;
        $logger->debug(__PACKAGE__ . ".$sub_name: Got cdr data from user.");
    }
    elsif($ref_cdr){
        $logger->error(__PACKAGE__ . ".$sub_name: Invalid reference passed for cdr data: $ref_cdr. It should be array reference.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    else{
        ($getcdrresult,$cdr) = $self->getCDR( -actfile     => $actfile,
                                          -recordtype  => $recordtype,
                                          -cdr         => \@inputcdr,
                                          -returnarray => 1
                                        );
        unless( $getcdrresult ){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to get CDR.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to getCDR; ";
            return (0, %returnhash);
        }
        @cdr_record = @$cdr;
	}
    #verifying the record index in the temporary camdecoder output file
    my $flag1 = 1;  #sets the return value
    my $flag = 0;   #indicates the record match
    my $flag2 = 1;      #indicates whether pattern/record exists or not

    for (keys %cdrref) {

        my $input_key = $_;
	my $input_key1 = $input_key;
	my $input_key2 = 0;
        foreach (@cdr_record) {
            chomp $_;
            if ($_ =~ /^Record\s*\d*\s*'(.*)'$/) {
                if($1 eq $recordtype){
                    $flag = 1;
                    next;
                }else{
                    $flag = 0;
                }
            }
            if ($flag) {
		unless ( $input_key2 ) {
	   	    $input_key2 = ($input_key1 =~ s/\./\\\./) ? $input_key1 : $input_key1 . '\.';           # appending "." if not present else escape "."
		}
                if ($_ =~ /^\s*$input_key2\s+(.*):\s+(.*)$/i){
                    my @array = split (' ', $_);
                    my $temp1 = $array[0];
                    my $temp2 = $2;
                    if(my $actualsystemname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME} ){ # 8520
                        $cdrref{$input_key} = $actualsystemname if($input_key =~ /^2\.?$/);
                        unless($self->{ERE} == 1){ #TOOLS-17148 Added ERE support
                            $actualsystemname = uc $actualsystemname;
                            $cdrref{$input_key} =~ s/(\S+)\:/$actualsystemname\:/ if(($input_key =~ /^28\.?$/ and $recordtype =~ /ATTEMPT|INTERMEDIATE/i) || ($input_key =~ /^26\.?$/ and $recordtype =~ /START/i) || ($input_key =~ /^31\.?$/ and $recordtype =~ /STOP/i));
                            $logger->debug(__PACKAGE__ . ".$sub_name: Pattern is changed  to \'$actualsystemname\'");
                        }
                    }#8520

                        #START TOOLS-18594
                        if($self->{'AWS_HFE'}){

#Same changes as in SIPP.pm file for AWS.
#Considering, NODE -> 2 -> IP as Private IP and NODE -> 1 -> IP as Public IP.
#Private IP is changed with Public IP
                            $cdrref{$input_key} =~ s/$main::TESTBED{'sipp:1:ce0:hash'}->{NODE}->{2}->{IP}/$main::TESTBED{'sipp:1:ce0:hash'}->{NODE}->{1}->{IP}/ if($input_key =~ /^(126|36)\.?$/);

#SIG_SIP/PKT_NIF -> 1 -> IP is changed to HFE -> 1 -> IP, because Next Hop IP is changed.
                            $cdrref{$input_key} =~ s/($self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IP}|$self->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP})/$self->{TMS_ALIAS_DATA}->{HFE}->{1}->{IP}/ if($input_key =~ /^(125|36)\.?$/);
                        }
                        #END TOOLS-18594

                    if ( $cdrvariation){
			my ($low,$high);
			$temp2 =~ s/\s//g;
                        $low = $cdrref{$input_key} - (($cdrvariation / 100 ) * $cdrref{$input_key});
                        $high = $cdrref{$input_key} + (($cdrvariation / 100 ) * $cdrref{$input_key});
                        if($temp2 >= $low && $temp2 <= $high){
			    $logger->info(__PACKAGE__ . ".$sub_name: Matched CDR Field : '$array[0]'; Expected Value : '$cdrref{$input_key}'; Actual CDR Value Observed : '$temp2'; Acceptable Percentage variation = '$cdrvariation' %" );
			    $returnhash{$input_key} = $cdrref{$input_key};
                            last;
                        }else{
			    $logger->info(__PACKAGE__ . ".$sub_name: Did not Match CDR Field: '$array[0]'; Expected Value : '$cdrref{$input_key}'; Actual CDR Value Observed : '$temp2'; Acceptable Percentage variation = '$cdrvariation' %. The value is beyond the acceptable percentage variation." );
                            $flag1 = 0;
			    $matchfail{$input_key} = "$1 Actual Value -> $temp2.\t Expected Value -> $cdrref{$input_key}";
                        }
  		    } else {
                        my @cdr_data = (ref($cdrref{$input_key}) eq 'ARRAY') ? @{$cdrref{$input_key}} : $cdrref{$input_key};
                        if(grep $_ eq $temp2,@cdr_data){
                           $logger->info(__PACKAGE__ . ".$sub_name: Matched CDR Field : '$array[0]'; Expected Value : '@cdr_data'; Actual CDR Value Observed : '$temp2' " );
                           $returnhash{$input_key} = $temp2;
                            last;

                        }else{
                            $logger->info(__PACKAGE__ . ".$sub_name: Did not Match CDR Field : '$array[0]'; Expected Value : '@cdr_data'; Actual CDR Value Observed : '$temp2' " );
                            $flag1 = 0;
                            $matchfail{$input_key} = "$1 Actual Value -> $temp2.\t Expected Value -> @cdr_data";

                         }
		    }
		    last;
                }
            }
        }
	if( !defined $returnhash{$input_key} and !defined $matchfail{$input_key} ){
	    $logger->error(__PACKAGE__ . ".$sub_name: Did not Match CDR Field : '$input_key'; Expected Value : '$cdrref{$input_key}'. The key '$input_key' is not found in the decoded ACT file.");
	    $flag2 = 0;
	}
    }
    if( $returnmismatched ){
        # Return hash of mismatched values
        %returnhash = %matchfail;
    }
    if( $flag1 and $flag2 ){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return (1, %returnhash);
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR Mismatch; ";
        return (0, %returnhash);
    }

}

=head2 C< checkforCore >

=over

=item DESCRIPTION:

    - The subroutine checks for any core generated and executed the command for the collection of sysdump logs.
	  Following is the work flow ::

    - for every root object, it will check for *.tar.gz and *.md5 files present in /var/log/sonus/evlog/tmp, and will move them to /var/log/sonus/evlog/tmp/SYSDUMP folder if they exist.

    - Executes the command "sysDump.pl -C 0 -P 0 -I 0" for collection of sysDump.

    - Now the core files present in "coredump" directory are moved to /var/log/sonus/evlog/tmp, Also the trace files are moved to /var/log/sonus/evlog/tmp directory.

    - In /var/log/sonus/evlog/tmp/SYSDUMP, latest 40 files (.tar.gz and .md5 {considering 40 files will contain 20 of each .tar and .gz}) are kept and rest of the files are removed

    - For Version less than V05.00 : The latest sysdump files generated (.tar.gz and .md5) are moved from /tmp  folder to /var/log/sonus/evlog/tmp/SYSDUMP folder.

    - For Version greater than V05.00 : The latest sysdump files generated (.tar.gz and .md5) are moved from /opt/sonus/external  folder to /var/log/sonus/evlog/tmp/SYSDUMP folder.

=item ARGUMENTS:

 Mandatory :
    1. Testcase ID :: $tcid

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLES:

    $sbxObj->checkforCore($tcid,$copyCoreLocation)

=back

=cut

sub checkforCore {

    my ($self) = shift;
    my $sub_name = "checkforCore";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&checkforCore, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my ($tcid ,$copyLocation) = @_ ;
    my @content=();


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $main::core_found = 0;
        my $cmd=($self->{ASAN_BUILD} == 1)?"cd /home/log/sonus/oom":"cd /var/log/sonus/sbx/coredump";#TOOLS-72075

    my %content_ce;
    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        unless ( $self->{$ce}->{conn}->cmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd on $ce");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
            last;
        }

        my $file_size;
        my @corefile=();

        my $cmd1=($self->{ASAN_BUILD} == 1)?"ls -lrt":"ls -lrt newCoredumps";
        unless ( @content = $self->{$ce}->{conn}->cmd($cmd1)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd1 on $ce.");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
            last;
        }

        my $new_core;
        unless(($new_core) = grep {/core/i} @content){
            $logger->warn(__PACKAGE__ . ".$sub_name: Couldn't get newCoredumps size from '$cmd1' output. Checking buffer.");
            $logger->debug(__PACKAGE__ . ".$sub_name: output: ". Dumper(\@content));
            $new_core = ${$self->{$ce}->{conn}->buffer};
            $logger->debug(__PACKAGE__ . ".$sub_name: buffer: $new_core");
            unless($new_core =~/newCoredumps/){
                $logger->error(__PACKAGE__ . ".$sub_name: Couldn't get newCoredumps size from buffer also on $ce.");
                last;
            }
        }

        $file_size    = (split /\s+/,$new_core)[4];
        $logger->debug(__PACKAGE__ . ".$sub_name: file Size: $file_size");
        $logger->debug(__PACKAGE__ . ".$sub_name: new_core: $new_core");

        unless($file_size=~/^\d+$/){
            $logger->error(__PACKAGE__ . ".$sub_name: newCoredumps size is not a number on $ce.");
            last;
        }

        $self->{$ce}->{conn}->buffer_empty; #clearing the buffer before the execution of the command


        if($file_size == 0){
	    $logger->debug(__PACKAGE__ . ".$sub_name: newCoredumps size is 0");
            if ($main::core_found) {
                $logger->debug(__PACKAGE__ . ".$sub_name: No new core generated in $ce");
                last;
            } else {
		$logger->debug(__PACKAGE__ . ".$sub_name: newCoredumps size is 0, so checking any core.* files are present.");
                #redirecting error message to /dev/null, so that it won't affect the output check
                @content = $self->{$ce}->{conn}->cmd('ls -1 core.*  2> /dev/null');
                if($self->{ASAN_BUILD} and scalar @content > 1) {               #TOOLS-72075
                    $self->{$ce}->{conn}->buffer_empty; #clearing the buffer before the execution of the command
                }
                $self->{$ce}->{conn}->buffer_empty; #clearing the buffer before the execution of the command                
                @content = grep /\S/,@content;
                unless (scalar(@content) > 0 ) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: No new core generated in $ce");
		            next;
                }
                $logger->debug(__PACKAGE__. ".$sub_name: Removing old core file.");
                unless ($self->{$ce}->{conn}->cmd("rm -rf $content[-1]")) {             #Removing old core file as the size will be large and can cause stability issues on SBC.
                    $logger->warn(__PACKAGE__. ".$sub_name: Unable to remove old core files");
                }                
            }
        } else {
	    my $cmd3="cat newCoredumps";
            unless ( @content = $self->{$ce}->{conn}->cmd($cmd3)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd3 on $ce.");
                last;
            }
	}

	$logger->info(__PACKAGE__ . ".$sub_name:************** Core Dump Found in $ce !!!*********");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-SBC Cored!; ";
	$main::core_found = 1;
	$content_ce{$ce} = \@content;
    }
    unless($main::core_found){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->info(__PACKAGE__ . ".$sub_name: tcid argument is not passed. So not moving and storing core.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

    # Moving and storing core

    my $sys_path; #to support the sysdump path change - TOOLS-4125
    if ( $self->{'APPLICATION_VERSION'} gt 'V05.00' ) {
        $sys_path = '/opt/sonus/external';
        $logger->debug(__PACKAGE__ . ".$sub_name: the SBC version is greater than V05.00 so the path for the sysdump is $sys_path");
    }else {
        $sys_path = '/tmp';
        $logger->debug(__PACKAGE__ . ".$sub_name: the SBC version is lesser than V05.00 so the path for the sysdump is $sys_path");
    }

    foreach my $ce (@{$self->{ROOT_OBJS}}) {
	$logger->info(__PACKAGE__ . ".$sub_name: core file is/are in $ce ->" . Dumper($content_ce{$ce}));

        $logger->info(__PACKAGE__ . ".$sub_name: Create the SYSDUMP directory in /var/log/sonus/evlog/tmp for storing the Sysdump logs");
	unless ( my ($res) = _execShellCmd($self->{$ce}, "mkdir -p /var/log/sonus/evlog/tmp/SYSDUMP")) {
            $logger->warn(__PACKAGE__ . ".$sub_name: Failed to create the SYSDUMP directory in /var/log/sonus/evlog/tmp for storing the Sysdump logs");
        }

        $logger->info(__PACKAGE__ . ".$sub_name: logging to \'/var/log/sonus/evlog/tmp\' directory to move all the \.tar\.gz and /.md5 files to \'/var/log/sonus/evlog/tmp/SYSDUMP\' ");
        unless ($self->{$ce}->{conn}->cmd("cd /var/log/sonus/evlog/tmp")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to go into the \'/var/log/sonus/evlog/tmp\' directory");
            $logger->debug(__PACKAGE__ . ".$sub_name: wont be able to move the sysDump log files in \'/var/log/sonus/evlog/tmp\' directory") ;
        }
        my $cmd4 = "ls -t | egrep '.tar.gz|.md5' | xargs -I \{\} mv \{\} /var/log/sonus/evlog/tmp/SYSDUMP"  ;
        $logger->info(__PACKAGE__ . ".$sub_name: command to move all the \.tar\.gz files : '$cmd4' ");
        unless ($self->{$ce}->{conn}->cmd($cmd4)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command : \'$cmd4\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: wont be able to move the sysDump log files from \'/var/log/sonus/evlog/tmp\' directory") ;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: logging to \'$sys_path\' directory to move all the \.tar\.gz and /.md5 files in \'/var/log/sonus/evlog/tmp/SYSDUMP\' ");
        unless ($self->{$ce}->{conn}->cmd("cd $sys_path")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to go into the \'$sys_path\' directory");
            $logger->debug(__PACKAGE__ . ".$sub_name: wont be able to move the sysDump log files in \'$sys_path\' directory") ;
        }
        $cmd4 = "ls -t | egrep '.tar.gz|.md5' | xargs -I \{\} mv \{\} /var/log/sonus/evlog/tmp/SYSDUMP"  ;
        $logger->info(__PACKAGE__ . ".$sub_name: command to move all the \.tar\.gz files : '$cmd4' ");
        unless ($self->{$ce}->{conn}->cmd($cmd4)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command : \'$cmd4\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: wont be able to move the sysDump log files from \'$sys_path\' directory") ;
        }

        unless ($self->{$ce}->{conn}->cmd("cd /var/log/sonus/sbx/coredump")) {
            $logger->error(__PACKAGE__ . ".$sub_name: unable to change to '/var/log/sonus/sbx/coredump' directory from $sys_path");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]") ;
            return 0 ;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: executing \'sysDump.pl -C 0 -P 0 -I 0\' to collect all the logs");
        unless ($self->{$ce}->{conn}->print('sysDump.pl -C 0 -P 0 -I 0')) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the \'sysDump.pl -C 0 -P 0 -I 0\' on $ce");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        sleep (60);
        my ($temp_index, $matched) = (1, 0);
        foreach my $match ('Save application cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'y', 'Save .* cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'n', 'Save CPS cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'n', 'Press ENTER to continue, or CTRL-C to quit', '') {
            if (($temp_index % 2) == 0 and $matched) {
                $self->{$ce}->{conn}->print($match);
                $matched = 0;
            } elsif (($temp_index % 2)) {
                my ($prematch, $m) = ('','');
                if (($prematch, $m) = $self->{$ce}->{conn}->waitfor(-match     => "/$match/i",
                                                  -timeout   => $self->{DEFAULTTIMEOUT})) {
                    $matched = 1;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name: dint match for \'$match\'");
                   ($prematch, $m) = $self->{$ce}->{conn}->waitfor(-match     => $self->{$ce}->{PROMPT}, -timeout   => 180);
                    if (grep(/3 or more sysdumps already exist in \/var\/log\/sonus\/evlog\/tmp/, split('\n',$prematch))) {
                         $logger->error(__PACKAGE__ . ".$sub_name: \'sysDump.pl\' says 3 or more sysdumps already exist, please clean them");
                         &error("CMD FAILURE: \'sysDump.pl\'");
                    }
                    $logger->error(__PACKAGE__ . ".$sub_name: \'sysDump.pl\' returned $prematch");
                    $matched = 0;
                    return 0;
                }
            }
            $temp_index++;
        }
        my ($prematch, $match) = ('','');
        unless (($prematch, $match) = $self->{$ce}->{conn}->waitfor(-match => $self->{$ce}->{PROMPT}, -timeout   => 600)) {
            $logger->debug(__PACKAGE__ . ".$sub_name errmsg :.".$self->{$ce}->{conn}->errmsg);
            $logger->error(__PACKAGE__ . ".$sub_name: failed get the prompt back after execution of \'sysDump.pl\' on $ce");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: ".($self->{ASAN_BUILD})?"Removing the core files from /home/log/sonus/oom/":"Moving the core trace files as well to /var/log/sonus/evlog/tmp");
        my $cmdtmp = ($self->{ASAN_BUILD})?"rm -rf /home/log/sonus/oom/*":"mv /var/log/sonus/sbx/coredump/core.* /var/log/sonus/evlog/tmp/";
        $self->{$ce}->{conn}->cmd($cmdtmp);

        #checking the status of the command and logging it
	my ($status_code) = $self->{$ce}->{conn}->cmd('echo $?');
	chomp $status_code;
	unless($status_code == 0){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command, 'mv /var/log/sonus/sbx/coredump/core.* /var/log/sonus/evlog/tmp/' on $ce");
        }

        my @dumpFiles = <*-sysDump-*.tar.gz>  ;
        if (scalar(@dumpFiles) > 20) {
            my $cmd5 = "ls -t | egrep '.tar.gz|.md5' | tail -n +41 | xargs -d '\\n' rm" ;

            $logger->info(__PACKAGE__ . ".$sub_name: command to keep the latest 20 files : $cmd5 ") ;
            unless ($self->{$ce}->{conn}->cmd($cmd5)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command \'$cmd5\', hence not able to delete the older files");
                $logger->debug(__PACKAGE__ . ".$sub_name: Proceeding without clearing the older sysDump files, please check manually") ;
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Going back to same directory to move the generated core files");
        $self->{$ce}->{conn}->cmd("cd -") ;

        $self->{$ce}->{conn}->cmd('chmod -R 555 /var/log/sonus/evlog/tmp/'); #TOOLS-19320

	my @files;
        my @temp_result = grep (/\.tar\.gz/ || /\.md5/, split('\n',$prematch));
        foreach my $file (@temp_result) {
           if ($file =~ /((\S+)\.tar\.gz)/) {
               my $cmd = "mv $sys_path/$1 /var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.tar.gz";
               $logger->info(__PACKAGE__ . " moving core dump \'$1\' file to /var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.tar.gz");
               unless ($self->{$ce}->{conn}->cmd($cmd)) {
                   $logger->error(__PACKAGE__ . " unable perform \'$cmd\'");
               } else {
		    push @files, "/var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.tar.gz";
		}
           }
           if ($file =~ /((\S+)\.md5)/) {
	       my $cmd = "mv $sys_path/$1 /var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.md5" ;
               $logger->info(__PACKAGE__ . " moving core dump \.md5 file to /var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.md5");
               unless ($self->{$ce}->{conn}->cmd($cmd)) {
                   $logger->error(__PACKAGE__ . " unable perform \'$cmd\'");
               } else {
		    push (@files, "/var/log/sonus/evlog/tmp/SYSDUMP/$2-$tcid.md5");
		}
           }
        }
	#store the core dumps TOOLS-11064
        $self->storeCoreDumps($ce, $copyLocation, @files) if (@files);

        ########### Clear "newCoredumps" file ##################
        my $cmd = 'cat /dev/null > /var/log/sonus/sbx/coredump/newCoredumps';
        unless ( $self->{$ce}->{conn}->cmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd on $ce");
        }
    }
    unless ( my ($res) = _execShellCmd($self->{$self->{ACTIVE_CE}}, "cd")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:\'cd\' to get into home directory");
    }

    $logger->warn(__PACKAGE__ . ".$sub_name:************** Cleanup the core files !!!*********");
    $logger->warn(__PACKAGE__ . ".$sub_name:The SYSDUMP files(tar.gz and md5) have been moved to /var/log/sonus/evlog/tmp/SYSDUMP/. But the core and the core trace file contained in the path /var/log/sonus/evlog/tmp/ are still intact. Please cleanup these files. Compress and copy these files to some other server if they are needed.");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< storeCoreDumps >

=over

=item DESCRIPTION:

   This subroutine takes the corefiles as argument and decides where it needs to be saved depending upon $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} value.
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 2 for saving logs on ATS server only
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX
   SonusQA::Base::secureCopy(%scpArgs) subroutine is called for copying file from Remote host to on ATS server.

=item ARGUMENTS:

  1. CEOLinuxObj or CE1LinuxObj - $ce
  2. Name of the files     - @files
  3. CopyLocation         - $copyLocation

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - failure
    1   - success

=item EXAMPLES:

  $sbxObj->storeCoreDumps($ce, $copyLocation, @files);

=back

=cut

sub storeCoreDumps {
    my ($self, $ce, $copyLocation, @files) = @_;
    my $sub_name = "storeCoreDumps";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $hostname = (($ce =~ /ce0/) ? $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME} : $self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME}) || $ce;
    my $store_logs = $self->{STORE_LOGS};
    $store_logs = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
    my %scpArgs = (
                -hostip => $self->{$ce}->{OBJ_HOST},
                -hostuser => 'root',
                -hostpasswd => $self->{$ce}->{ROOT_PASSWORD},
                -scpPort => $self->{$ce}->{OBJ_PORT}
    );

    my $sbc_type = ($self->{SBC_TYPE}) ? "$self->{SBC_TYPE}-$self->{INDEX}_" : ''; # $self->{SBC_TYPE} is only for DSBC and it is S_SBC/M_SBC/T_SBC/I_SBC

    foreach my $file (@files) {
        my $filename = $1 if ($file =~ /.+\/(.+)$/);
        my $dest_file = $sbc_type.$hostname."_".$filename;

        if ($store_logs == 1 || $store_logs == 3) {
            my $cp_cmd = "\\cp $file $copyLocation/$dest_file";
            $logger->debug(__PACKAGE__ . ".$sub_name: copying $file to $copyLocation/$dest_file");
            unless ($self->{$ce}->{conn}->cmd($cp_cmd)) {
                $logger->error(__PACKAGE__ . " unable to do \'$cp_cmd\'");
                $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        elsif ($store_logs == 2 || $store_logs == 3) {
            my $dest_path = $self->{LOG_PATH};
            $dest_path = $main::log_dir if (defined $main::log_dir and $main::log_dir);
            $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.":".$file;
            $scpArgs{-destinationFilePath} = $dest_path."/".$dest_file;

            $logger->debug(__PACKAGE__ . ".$sub_name: copying $file to $scpArgs{-destinationFilePath}");
            unless (&SonusQA::Base::secureCopy(%scpArgs)) {
                $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the $filename file");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                $main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to CopyLogs; ";
                return 0;
            }
        }
    }
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< rollLogs >

=over

=item DESCRIPTION:

    This subroutine is used to roll over the specified logs.

=item ARGUMENTS:

 Optional:
    1. log type - the type of the log.
       If type is not passed, will roll over the logs of types defined in REQUIRED_LOGS (@{$self->{REQUIRED_LOGS}})
       and if REQUIRED_LOGS is not defined, will roll over acct, debug , trace and system logs.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCliCmd

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ( $sbx_obj->rollLogs('acct')) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot roll over the logs.");
        return 0;
    }

=back

=cut

sub rollLogs {
    my ($self) = shift;
    my @logtype = ();
    my $sub_name = "rollLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&rollLogs, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my ($type) = @_ ;
    my %tempLogs = ('CDR' => "acct", 'ACT' => "acct", 'DBG' => "debug", 'SYS' => "system", 'TRC' => "trace", 'AUD' => "audit", 'snmp' => "snmp", 'PKT' => "packet", 'SEC' => "security",'MEM' => "memusage");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if (defined($type)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: trying to roll over $type log");
	push @logtype,$type;

    } elsif (scalar @{$self->{REQUIRED_LOGS}}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: trying to roll over \'" . join (',', @{$self->{REQUIRED_LOGS}}) . "\' logs");
        map {defined $tempLogs{$_} and push (@logtype, $tempLogs{$_})} @{$self->{REQUIRED_LOGS}};
    }else {
        @logtype = ("acct", "debug", "system","trace");
        push (@logtype, "audit", "packet", "security") if ($self->{POST_3_0});
        push @logtype , "memusage" unless ( SonusQA::Utils::greaterThanVersion( 'V07.00.00-A016' , $self->{'APPLICATION_VERSION'}) ) ;
        $logger->debug(__PACKAGE__ . ".$sub_name: so trying to roll over \'" . join (',', @logtype ) . "\' logs");
    }

    foreach (@logtype){
        $logger->debug(__PACKAGE__ . ".$sub_name: rolling over $_ log");
        if ($_ =~ /snmp/i) {
	    unless (my ($res) = _execShellCmd($self->{$self->{ACTIVE_CE}}, 'cat /dev/null > /opt/sonus/sbx/tailf/var/confd/log/snmp.log')) {
                $logger->error(__PACKAGE__ . ".$sub_name: failed to roll the snmp log");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to RollLog; ";
                return 0;
            }
            next;
        }
        my $cmd = "request oam eventLog typeAdmin $_ rolloverLogNow";
    	unless ($self->execCliCmd($cmd) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue $cmd'");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to RollLog; ";
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< compareSystemProcesses >

=over

=item DESCRIPTION:

	Compares the system process Information before and after.

=item ARGUMENTS:

 Mandatory :

	$before,
	$after

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->compareSystemProcesses($before, $after);

=back

=cut

sub compareSystemProcesses {

    my ($self,$before, $after) = @_ ;
    my @logtype = ();
    my $sub_name = "compareSystemProcesses";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @processnames =qw(asp_amf CE_2N_Comp_ChmProcess CE_2N_Comp_FmMasterProcess CE_2N_Comp_CpxAppProc CE_2N_Comp_SmProcess CE_2N_Comp_EnmProcessMain CE_2N_Comp_NimProcess CE_2N_Comp_SsaProcess CE_2N_Comp_PesProcess CE_2N_Comp_ScpaProcess CE_2N_Comp_PipeProcess CE_2N_Comp_PrsProcess CE_2N_Comp_SamProcess CE_2N_Comp_DsProcess CE_2N_Comp_DnsProcess CE_2N_Comp_CamProcess CE_2N_Comp_ImProcess CE_2N_Comp_IpmProcess CE_2N_Comp_PathchkProcess CE_2N_Comp_DiamProcess CE_2N_Comp_ScmProcess_0 CE_2N_Comp_ScmProcess_1 CE_2N_Comp_ScmProcess_2 CE_2N_Comp_ScmProcess_3 CE_2N_Comp_RtmProcess CE_2N_Comp_IkeProcess);


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if(defined($before) && defined($after)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: comparing process info $before and $after");
    }else{
	$before = 1;
	$after = 2;
        $logger->debug(__PACKAGE__ . ".$sub_name: comparing process info $before and $after");
    }

    my $flag = 1;
    foreach (@processnames){
	#check pid is same
	$logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ PID before: $self->{1}->{systemprocess}->{$_}->{PID} PID After: $self->{2}->{systemprocess}->{$_}->{PID}");
	unless($self->{1}->{systemprocess}->{$_}->{PID} eq $self->{2}->{systemprocess}->{$_}->{PID}){
		$flag = 0;
        	$logger->debug(__PACKAGE__ . ".$sub_name: PID has changed for Process : $_");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ PID before: $self->{1}->{systemprocess}->{$_}->{PID} PID After: $self->{2}->{systemprocess}->{$_}->{PID}");
	};

	#check state is same
	 $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ STATE before: $self->{1}->{systemprocess}->{$_}->{STATE} STATE After: $self->{2}->{systemprocess}->{$_}->{STATE}");
	unless($self->{1}->{systemprocess}->{$_}->{STATE} eq $self->{2}->{systemprocess}->{$_}->{STATE}){
		$flag = 0;
        	$logger->debug(__PACKAGE__ . ".$sub_name: STATE has changed for Process : $_");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ STATE before: $self->{1}->{systemprocess}->{$_}->{STATE} STATE After: $self->{2}->{systemprocess}->{$_}->{STATE}");
	};

    } #foreach


    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed in ComparingProcesses; ";
        return 0;
    }

}

=head2 C< getRollbackInfo >

=over

=item DESCRIPTION:

   This subroutine rolls back database to last committed version.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - If the session is killed or if `configure` command fails or if failed to leave config mode.
    1   - If success

=item EXAMPLES:

 $sbxObj->getRollbackInfo();

=back

=cut

sub getRollbackInfo {

    my ($self) = @_ ;

    my $sub_name = "getRollbackInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @content=();
    $self->execCmd("configure");
    sleep(2);
    my $cmd="rollback \t";
    unless ( @content = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Rollback; ";
        return 0;
    }

    foreach (@content){
	$logger->info(__PACKAGE__ . ".$sub_name: $_");
      	if(m/^\s+(0)\s+(-)\s+(\d+-\d+-\d+)\s+(\d+:\d+:\d+)\s+(\w+)/){
        	        $logger->debug(__PACKAGE__ . ".$sub_name: $_");
			$self->{rollback}->{basetimestamp} = $4;
	#		$self->{rollback}->{baseindex} = 0;
	}
    }

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
        #return ($self->{rollback}->{basetimestamp});
}

=head2 C< RollbackTo >

=over

=item DESCRIPTION:

	This subroutine helps to rollback the SBC

=item ARGUMENTS:

 Mandatory :

	$timestamp

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->RollbackTo($timestamp);

=back

=cut

sub RollbackTo {

    my ($self,$timestamp) = @_ ;

    my $sub_name = "RollbackTo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Rolling To TimeStamp : $timestamp");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $timestamp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: timestamp is empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @content=();
    $self->execCmd("configure");
    my $cmd="rollback \t";
    unless ( @content = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Rollback; ";
        return 0;
    }

    my $flag = 0;
    foreach (@content){
      	if(m/^\s+(\d+)\s+(-)\s+(\d+-\d+-\d+)\s+(\d+:\d+:\d+)\s+(\w+)/){
       	        $logger->debug(__PACKAGE__ . ".$sub_name: $_");
		if($4 eq $timestamp){
		    $self->{rollback}->{baseindex} = $1;
		    $flag = 1; #indicates the occurance of the timestamp
       	            $logger->debug(__PACKAGE__ . ".$sub_name: $_");
		    last;
		}
	}
    }

    if($flag){
        if ($self->{rollback}->{baseindex} == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Roll back skipped as the found index is 0 !! ");
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Roll back index found ");
            my $indexNew = $self->{rollback}->{baseindex};
            $indexNew = $indexNew -1;
            $self->execCliCmd("rollback $indexNew");
            $self->execCliCmd("commit");
            $logger->debug(__PACKAGE__ . ".$sub_name: Rolled back to Index : $indexNew"); }
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Roll back info not found");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Rollback; ";
        return 0;
    }

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
 return 1;
}


=head2 C< verifyStatus >

=over

=item Description:

 This function is used to check if the values of the field passed to the function matches the corresponding value in the command output
 This function considers that the output of the command is in order and the hash passed to the function contains values in the same order as well.

=item Arguments:

 $cmd - Command to be executed
 $cliHash - Hash reference(Refernce of a hash with array values)
 $mode - The type of mode

=item Returns:

 0 - If the match fails
 1 - If all the field:value pair match

=item Example:

 $cmd = 'show status global callRemoteMediaStatus';
 $cliHash = {'localRtpPort' => ['1082', '1142', '1082', '1000 - 1050'], 'rtpPacketRecv' => ['654', '70 - 80','2', '417']};
 $mode = 'private';(If command needs to be executed in private mode)
 $self->verifyStatus($cmd, $cliHash, $mode);

=back

=cut

sub verifyStatus {
    my ($self,$cmd,$cliHash,$mode) = @_ ;
    my $sub_name = "verifyStatus";
    my (%statusOut, @output);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CLI command empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cliHash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Array Reference empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my %cliHash = %$cliHash;
    $self->execCmd("configure private") if ($mode =~ m/private/);

    unless (@output = $self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: The command '$cmd' could not be executed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $self->leaveConfigureSession if ($mode =~ m/private/);

=pod

callRemoteMediaStatus 67108888 0 {
    streamId          0;
    resId             116;
    resType           xresUser;
    legId             0;
    nodeGcidAndIpAddr 67108894(fd00:10:6b50:4d50::3);
    localRtpPort      1082;
    remoteRtpPort     8999;
    remoteRtcpPort    9000;
    rtpPacketSent     78;
    rtpPacketRecv     656;
    rtcpPacketSent    0;
    rtcpPacketRecv    0;
    rtpPacketDiscard  0;
}
callRemoteMediaStatus 67108888 1 {
    streamId          0;
    resId             117;
    resType           xresUser;
    legId             0;
    nodeGcidAndIpAddr 67108894(fd00:10:6b50:4d50::3);
    localRtpPort      1140;
    remoteRtpPort     1076;
    remoteRtcpPort    1077;
    rtpPacketSent     656;
    rtpPacketRecv     78;
    rtcpPacketSent    0;
    rtcpPacketRecv    0;
    rtpPacketDiscard  0;
}

=cut

    foreach(@output){
        next if (/.*\{$ | ^\}/);                                           #Removing lines with '}' or '{'
        push(@{$statusOut{$1}}, $2) if (/(\S+)\s+(\S+)\;/);                #Creating a hash of array for each field in the command output
    }
    my $flag = 1;
    foreach my $field (keys %cliHash){
        unless (exists $statusOut{$field}){                      #Check if the passed field exists in the command output
            $logger->error(__PACKAGE__ . ".$sub_name: Key: '$field' is not present in the command output");
            $flag = 0;
            next;
        }
        for (my $i = 0; $i < scalar @{$cliHash{$field}}; $i++){
            if ($cliHash{$field}->[$i] =~ /(.+)-(.+)/) {
                my ($min, $max) = ($1, $2);
                if ($statusOut{$field}[$i] >= $min and $statusOut{$field}[$i] <= $max) {  #Check if the passed hash with array values in range min-max  matches the corresponding field in the created HoA
                    $logger->debug(__PACKAGE__ . ".$sub_name: key: '$field' Value: $statusOut{$field}[$i] is in the range $min and $max MATCH SUCCESS!!");
                }else {
                    $logger->error(__PACKAGE__ . ".$sub_name: key: '$field' Value: $statusOut{$field}[$i] is not in range $min and $max MATCH FAILED!!");
                    $flag = 0;
                }
            }else{
                if($statusOut{$field}[$i] eq $cliHash{$field}->[$i]){             #Check if the passed hash with array values matches the corresponding field in the created HoA
                    $logger->debug(__PACKAGE__ . ".$sub_name: Key: '$field' Actual value: '$statusOut{$field}[$i]' Passed value : '$cliHash{$field}->[$i]' MATCH SUCCESS!!");
                }else{
                    $logger->error(__PACKAGE__ . ".$sub_name: Key: '$field' Actual value: '$statusOut{$field}[$i]' Passed value : '$cliHash{$field}->[$i]' MATCH FAILED!!");
		    $flag = 0;
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< kick_Off >

=over

=item DESCRIPTION:

	It's a wrapper function to kick start the automation by rolling the logs and moving the core files to other directories.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

  $obj->kick_Off();

=back

=cut

sub kick_Off {

    my ($self) = @_ ;
    my ($home_dir,$finalFilename);
    my $sub_name = "kick_Off";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my $retVal = $self->__dsbcCallback(\&kick_Off);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my $sys_path; #creat a variable to support the sysdump path change - TOOLS-4125
    if ( $self->{'APPLICATION_VERSION'} gt 'V05.00' ) {
        $sys_path = '/opt/sonus/external';
    }else {
        $sys_path = '/tmp';
    }
    $self->{WAS_KICKED_OFF} = 0; #to be used in wind_Up to check whether kick_Off is success or not. (Fix for TOOLS-3790)

    if ( $main::TESTSUITE->{USE_CONF_ROLLBACK} =~ /no/i ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Skipping ROLLBACK!");
	$self->{skip_rollback} = 1; # To be used in wind_Up
    }else{
	$self->{skip_rollback} = 0; # set to 0 by default
    }

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    ####### get base config rollback info ######
    unless ($self->{skip_rollback}) {
        unless ( $self->getRollbackInfo) {
            $logger->error(__PACKAGE__ . ".$sub_name: Could not get the base config Roll back info.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    ######## Roll log files ######

    unless ( $self->rollLogs) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot roll logs.");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to RollLogs; ";
        return 0;
    }

    #to find the current log file and set to $self->{STARTING_LOG}
    $self->resetLogsToCurrent();

    #TOOLS-71187
    if($self->{SKIP_ROOT}){
        unless($self->removeCoredump){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not remove coredump");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    #clear coredumps
    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        #TOOLS-71187
        if($self->{SKIP_ROOT}){
            $logger->debug(__PACKAGE__ . ".$sub_name: removing SysDump logs for '$ce'");
            unless($self->{$ce}->{conn}->cmd("rm /opt/sonus/external/*-SysDump-*")){
                $logger->warn(__PACKAGE__ . ".$sub_name: failed to remove SysDump logs for '$ce'");
            }
            next;
        }

        ########### Clear "newCoredumps" file ##################
        my $cmd = 'cat /dev/null > /var/log/sonus/sbx/coredump/newCoredumps';
        unless ( $self->{$ce}->{conn}->cmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd on $ce");
        }
        my $errMode = sub {
	    $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command, '$cmd' on $ce");
        };
        $cmd = "mkdir -p /var/log/sonus/evlog/tmp/";
        ##### Creating /var/log/sonus/evlog/tmp/ to move the old core files to #####
        $self->{$ce}->{conn}->cmd( String => $cmd, Errmode => $errMode );
	$cmd = "mv /var/log/sonus/sbx/coredump/core.* /var/log/sonus/evlog/tmp/";
        ##### moving core files to /var/log/sonus/evlog/tmp/ #####
        $self->{$ce}->{conn}->cmd( String => $cmd, Errmode => $errMode );

        $logger->info(__PACKAGE__ . ".$sub_name: Create the SYSDUMP directory in /var/log/sonus/evlog/tmp for storing the Sysdump logs");
	unless ( my ($res) = _execShellCmd($self->{$ce}, "mkdir -p /var/log/sonus/evlog/tmp/SYSDUMP")) {
            $logger->warn(__PACKAGE__ . ".$sub_name: Failed to create the SYSDUMP directory in /var/log/sonus/evlog/tmp for storing the Sysdump logs");
        }

        $logger->debug(__PACKAGE__ . ".moving the \'.tar.gz\' and \'.md5\' files from $sys_path to /var/log/sonus/evlog/tmp/SYSDUMP");
	#$cmd = "mv $sys_path/*.tar.gz /var/log/sonus/evlog/tmp/SYSDUMP";
        #$self->{$ce}->{conn}->cmd( String => $cmd, Errmode => $errMode );
	#$cmd = "mv $sys_path/*.md5 /var/log/sonus/evlog/tmp/SYSDUMP";
        #$cmd = "find $sys_path -type f -not \\( -name sb\[xc\]-V0\*.tar.gz -o -name sb\[xc\]-V0\*.md5 \\) | xargs -I file mv file /var/log/sonus/evlog/tmp/SYSDUMP";
        $cmd = 'find '.$sys_path.' -type f \( -name \*.tar.gz -o -name \*.md5 \) -not \( -name sb\[xc\]-V0\*.tar.gz -o -name sb\[xc\]-V0\*.md5 \) -exec mv {} /var/log/sonus/evlog/tmp/SYSDUMP \;';
	$self->{$ce}->{conn}->cmd( String => $cmd, Errmode => $errMode );
    }

   ########### Roll GSX Logs ##################
   # Perform GSX Roll Logs only if GSX Object Referance is defined!

   if ( defined $gsxObjRef ) {
      unless ($self->rollGSXlogs) {
           $logger->error(__PACKAGE__ . " $sub_name:   Failed roll GSX Logs.");
       }
   }
   # Roll PSX Logs
  my $psx_logs = (exists $self->{SBC_TYPE})?$self->{PARENT}->{PSX_LOGS}:$self->{PSX_LOGS}; #TOOLS-71652

  if (@psxObj){
    for my $i (0..scalar(@psxObj)-1){#TOOLS-20632
     if(ref (@{$psx_logs}[$i]) eq 'ARRAY'){
        $psxObj[$i]->remove_logs($psx_logs->[$i]);
        }
      else{
        $psxObj[$i]->remove_logs($psx_logs);
      }
    }
  }

#Fix for TOOLS-4628 :  INFO level debug logging needs to be re-enabled in kick_Off( )
#check for Info level logging debug in SBC.
   if ( SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V05.00.000000') ) { #application version should be greater than SBC 5.0+
       unless ($self->enableInfoLevelLogging()) {
           $logger->debug(__PACKAGE__ . ".$sub_name : Could not enable Info Level Logging");
           return 0;
       }
   }
   else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Version is lesser than 'V05.00.000000' so Leaving 'Info level logging' check ");
   } # End of Info level logging debug check in sbc.

    # Used in wind_Up to check whether kick_Off is success or not. wind_Up will fail if its not set.
    # Fix for TOOLS-3790. This will help to avoid creation of same object twise instead of using makeReconnection.
    $self->{WAS_KICKED_OFF} = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
}

=head2 C< wind_Up >

=over

=item DESCRIPTION:

	It's wrapper function, called at the end of the test case to collect the logs and do some validation.
# Made changes to this API , so that the logs are never stored in ATS machine. As a fix for CQ SONUS00127345.

=item ARGUMENTS:

 Mandatory :

	$tcid

 Optional :

	$parselogfiletype - log file type to be used for parsing,
	$searchpattern - pattern to searched in the log file, it can be scalar/array reference/hash reference,
	$actrecordtype - ACT record typw,
	$cdrhash - pass this hash reference to do CDR validation,
	$copyLocation - path where the logs need to be copied,
	$logStoreFlag - store log flag,
		Example:
			$self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
                        $self->{STORE_LOGS} is 2 for saving logs on ATS server only
                        $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX

	$cdrvariation - to do CDR variation value,
	$psxhash - to verify the PSX logs when used along with SBC

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->wind_Up($tcid,$parselogfiletype,$searchpattern,$actrecordtype,$cdrhash,$copyLocation,$logStoreFlag,$cdrvariation,$psxhash);
						or
  $sbxObj->wind_Up($testCaseId,$parseFile,\@parse,$cdrType,\%cdrhash,$TESTSUITE->{PATH},$TESTSUITE->{STORE_LOGS});

=back

=cut

sub wind_Up {

   # my ($self,$tcid,$parselogfiletype,$searchpattern,$actrecordtype,$cdrhash,$copyLocation,$logStoreFlag) = @_ ;
    my $self = shift;
    my $sub_name = "wind_Up";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
			'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&wind_Up, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my $tcid = shift;
    my $parselogfiletype = shift;

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Added the below check to fix TOOLS-3790.
    # Decided to return failure if wind_Up is called without kick_Off.
    unless($self->{WAS_KICKED_OFF}){
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't do wind_Up, since kick_Off is either failed or not called.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Check whether you are called wind_Up for the same object where kick_Off was success. You might created the object again instead of doing 'makeReconnection()'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-wind_Up Error; ";
        return 0;
    }

    my ($searchpattern,@searchpattern,%searchpattern,$cdrhash,%cdrhash,$copyLocation,$logStoreFlag,$cdrvariation,$psxhash);
    if (ref($_[0]) eq 'ARRAY') {
     $searchpattern = shift;
     @searchpattern = @$searchpattern;
    }
    elsif (ref($_[0]) eq 'HASH') {
     $searchpattern = shift;
     %searchpattern = %$searchpattern;
     foreach( keys %searchpattern){
         push @searchpattern,$_;
     }
    }
    else {
     $searchpattern = shift;
     @searchpattern = ("$searchpattern");
    }

    my $actrecordtype;
    if (ref($_[1]) eq 'HASH') {
    $actrecordtype = shift;
    $cdrhash = shift;
    %cdrhash = %$cdrhash;
    ($copyLocation,$logStoreFlag,$cdrvariation,$psxhash) = @_ ;
    }
    else {
    ($copyLocation,$logStoreFlag,$cdrvariation,$psxhash) = @_ ;
    }
    my %psxhash;
    %psxhash = %$psxhash if ($psxhash ne "");
    my $coreflag = 0;
    my $cdrflag = 0;
    my $parseflag = 0;
    my $errorflag = 0;
    my $passed = 0;
    my $rollflag = 0;
    my $psxflag = 0;
    my $ce_flag =0;
    my $numberoflogfiles = 1;
    my @logtype = ('CDR',"ACT", "DBG", "SYS", "TRC"); #Introduced new logtype(PKT) for CQ-SONUS00134252
    push (@logtype, "PKT", "AUD", "SEC") if ($self->{POST_3_0}); #Introduced new logtype(SEC) for CQ-SONUS00149700
    @logtype = @{$self->{REQUIRED_LOGS}} if (scalar @{$self->{REQUIRED_LOGS}});
    my ($copyCoreLocation,$copyLogLocation,@logfilenames,@ce_node_logs);

   unless(defined ($logStoreFlag)){
        $logger->warn(__PACKAGE__ . ".$sub_name: The flag for log storage not defined !! Using Default Value 1 ");
        $logStoreFlag = 1;
   }
  
    unless($copyLocation){
        $copyLocation = ($self->{SKIP_ROOT}) ? '/home/linuxadmin' : ($main::TESTSUITE->{PATH} || $self->{LOG_PATH});
        $logger->info(__PACKAGE__ . ".$sub_name: The location to copy Logs/Corefiles not Defined !! By Default the Logs will be stored at the SBX server at Path => $copyLocation/logs");
    }
    $copyCoreLocation = $copyLocation."/coredump";
    $copyLogLocation = $copyLocation."/logs";

    if($self->{SKIP_ROOT}){ #TOOLS-71187
        @ce_node_logs = ('/home/linuxadmin/sbc_diag_logs/CE_Node2.log','/home/linuxadmin/sbc_diag_logs/CE_Node1.log');
    }
    else{
        @ce_node_logs = ('/var/log/sonus/sbx/openclovis/CE_Node2.log','/var/log/sonus/sbx/openclovis/CE_Node1.log');
    }
    
   foreach my $ce (@{$self->{ROOT_OBJS}}) {
       unless ($self->{$ce}) {
           $logger->error(__PACKAGE__ . ".$sub_name: no root object exist for $ce");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
           return 0;
       }
	#TOOLS-5217, Reconnecting if connection is closed
       if ($self->{$ce}->{conn}->lastline =~ /Connection.*closed/i) { # checking if SBX is connected.
           $logger->debug(__PACKAGE__ . ".$sub_name: Connection to SBX lost. Reconnecting ...");
           unless ($self->makeReconnection()) {
               $logger->error(__PACKAGE__ . ".$sub_name: Reconnect Unsuccessful");
               $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-WindUp_Failed to Reconnect; ";
               return 0;
           }
       }

	unless ( my ($resStatus) = _execShellCmd($self->{$ce}, "mkdir -p $copyLogLocation") ) {
           $logger->warn(__PACKAGE__ . ".$sub_name: Could not create Log Directory ");
           $logStoreFlag = 0 if ($logStoreFlag);
       }
       #TOOLS-19354 :Checking  CENODE.log
    for (my $i=0;$i<2;$i++){
	    $logger->debug(__PACKAGE__ . ".$sub_name: checking $ce_node_logs[$i]");
        #TOOLS-75778
        my ($res ,@result) = _execShellCmd($self->{$ce}, "grep -E '(buffer too small. Need|ERROR : AddressSanitizer : stack-buffer-overflow|ERROR : AddressSanitizer: heap-buffer-overflow|ERROR : LeakSanitizer: detected memory leaks)' $ce_node_logs[$i]");
        if($res){
            $logger->error(__PACKAGE__ . ".$sub_name: Error found in '$ce_node_logs[$i]'",Dumper(\@result));
            $ce_flag=1;
            last;
        } elsif(grep /No such file or directory/,@result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: $ce_node_logs[$i] is not present");
        } else {   
            $logger->debug(__PACKAGE__ . ".$sub_name: No errors found in '$ce_node_logs[$i]'");
            last;
        }
    }
   $logger->debug(__PACKAGE__ . ".$sub_name: CE_NODE_LOGS: ".Dumper(\@ce_node_logs));
   @ce_node_logs= reverse @ce_node_logs; 
   }

    ######## check for core ########################################
    #TOOLS-71187
    if($self->{SKIP_ROOT}){
        my $ce_name;
        if($ce_name = $self->checkCoredump()){
            $logger->error(__PACKAGE__ . " $sub_name: found core in '$ce_name'");
            $coreflag = 1;
            $self->collectSbcDiagLogs(-copy_location => $copyCoreLocation, -tcid => $tcid);
            $self->removeCoredump(-ce_name => $ce_name);
        }
    }
    elsif ($self->checkforCore($tcid,$copyCoreLocation)) {
        $logger->error(__PACKAGE__ . " $sub_name:   found core.");
	#$numberoflogfiles = 2;
	$coreflag = 1;
    }

   if ($self->{CHECK_CORE} == 1) {
      if ($coreflag == 1) {
          $logger->debug(__PACKAGE__ . ".$sub_name: core found");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
          return 1;
      } else {
         $logger->debug(__PACKAGE__ . ".$sub_name: no core found");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
      }
   }

   ################### Get Recent Log Files & Store Logs ##########################
    my (@cmdresults) = ('');
    my %tempLogs = ('CDR' => "acct", 'ACT' => "acct", 'DBG' => "debug", 'SYS' => "system", 'TRC' => "trace", 'AUD' => "audit", 'snmp' => "snmp", 'PKT' => "packet", 'SEC' => "security");
    my @templogtype = ();
    $logger->info(__PACKAGE__ . ".$sub_name: Checking for the logging state of each log type..");
    unless ( @cmdresults = $self->execCmd("show table oam eventLog typeAdmin") ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed while issuing Cli to find the logging state of the logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:log type passed ".Dumper(\@logtype));
    $logger->debug(__PACKAGE__ . ".$sub_name:log type cmd results".Dumper(\@cmdresults));
    for(my $index = 0; $index <= $#logtype; $index ++){
	my $stat = grep { /$tempLogs{$logtype[$index]}\s+enabled/ } @cmdresults;
        if ($stat == 0 and $logtype[$index]!~ /snmp/) {
            $logger->warn(__PACKAGE__ . ".$sub_name:  Log type \'$tempLogs{$logtype[$index]}\' has been disabled on the SBC ");
	}else{
	    push @templogtype, $logtype[$index];
        }
    }
    @logtype = @templogtype;
    $logger->debug(__PACKAGE__ . ".$sub_name: The following log types will be collected : @logtype ");
    foreach my $fileType (@logtype) {
	if ($fileType =~ /snmp/i) {
            push (@logfilenames, 'snmp.log');
        } else {
	    next unless( grep $_ eq $fileType, @templogtype);
            my $ce = $self->{ACTIVE_CE}; # root session name pointing to active CE
	    my $cmd="cd /var/log/sonus/sbx/evlog";
            my (@cmd_results,$logtimestamp) = ('','');
            $numberoflogfiles = 1;
            $logger->debug(__PACKAGE__ . ".$sub_name: File Type : $fileType");
            my ($finalFilename);
	    unless($finalFilename = $self->getRecentLogViaCli($fileType)){
	        $logger->warn(__PACKAGE__ . ".$sub_name: \'$fileType\' logs will not be collected for this testcase because of an error in getting recent log file name ");
		next;
	    }
            $logger->debug(__PACKAGE__ . ".$sub_name: Latest \'$fileType\' log file : \'$finalFilename\'");
            my $startFilename = $self->{STARTING_LOG}->{$fileType};
	    unless($startFilename =~ /error/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: \'$fileType\' Log file at the beginning of the testcase : \'$startFilename\'");
	    } else {
		$logger->warn(__PACKAGE__ . ".$sub_name: \'$fileType\' logs will not be collected for this testcase because of an error in getting recent log file name during kick off ");
		next;
	    }
            unless ( @cmd_results = $self->{$ce}->{conn}->cmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command on $ce :$cmd --\n@cmd_results.");
        	$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
	    $cmd="ls -lrt $startFilename";
            unless ( @cmd_results = $self->{$ce}->{conn}->cmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command on $ce :$cmd --\n@cmd_results.");
      	        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
	    unless( grep /No such file or directory/i , @cmd_results) {
	        chomp @cmd_results;
                foreach my $log (@cmd_results){
                    if($log =~ /(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)/){
                        $self->{STARTING_LOG}->{$startFilename} = $6.$7.$8;
                   }
                }
                if ( $startFilename eq $finalFilename){
                        push (@logfilenames ,$startFilename);
                        next;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Timestamp for \'$self->{STARTING_LOG}->{$fileType}\': \'$self->{STARTING_LOG}->{$startFilename}\' ");
            } else {
		$logger->debug(__PACKAGE__ . ".$sub_name:  \'$startFilename\' log file is missing! ");
	    }
	    my ($collect,$filecount,$firstfiletimestamp) = ("0","0",'');
            $cmd="ls -lrt *$fileType";
            unless ( @cmd_results = $self->{$ce}->{conn}->cmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command on $ce :$cmd --\n@cmd_results.");
        	$logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
       	 	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            chomp @cmd_results;
	    my (@logarray) = ();
            unless( grep /No such file or directory/i , @cmd_results ){
	        foreach my $log (@cmd_results){
	            if($log =~ /(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)\s(.*)/){
		        $log = $9;
		        push(@logarray, $log);
		        $logtimestamp = $6.$7.$8;
		        $firstfiletimestamp = $logtimestamp if(scalar (@logarray) == 1  );
                        $collect = 1  if( $self->{STARTING_LOG}->{$self->{STARTING_LOG}->{$fileType}} eq $logtimestamp);
		        if($collect == 1){
		            push (@logfilenames ,$log);
		            $filecount++;
		        }
	            }
	        }
	    } else {
		$filecount = -1;
	    }
            if( defined $filecount and $filecount == 0 ){
                $logger->warn(__PACKAGE__ . ".$sub_name: Log file id rollover might have occurred for log type \'$fileType\' Not all logs that was generated will be collected for this logtype");
		$logger->warn(__PACKAGE__ . ".$sub_name: All the remaining \'$fileType\' logs will be collected. ");
                push (@logfilenames ,@logarray);
            } elsif( $filecount == -1 ) {
	        $logger->warn(__PACKAGE__ . ".$sub_name: No \'$fileType\' log files are present in the SBC ");
	    }
        }
    }
    unless ($#logfilenames != -1 ) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get the log file names.");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Log files generated for this testcase : @logfilenames ");
    my @cmd_results = '';
    unless ( @cmd_results = $self->{$self->{ACTIVE_CE}}->{conn}->cmd("cd ")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command on \'$self->{ACTIVE_CE}\' :\'cd \' --\n@cmd_results.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$self->{ACTIVE_CE}}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$self->{ACTIVE_CE}}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$self->{ACTIVE_CE}}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######## CHECKING FOR SYS ERRORS,MEMORY LEAKS or MEMORY CORRUPTION  ########
    foreach (@logfilenames){
        if($_ =~m/DBG|SYS/i ){
            my ($matchcount,$result,$verify);
            $logger->info(__PACKAGE__ . " $sub_name: Checking for SYS errors or memory leaks and memory corruption in the log '$_' \n ");
	    $verify = ($_ =~m/DBG/) ? ({"SipsMemFree: corrupted block" => 0,"SYS ERR" => 0}) : ({"SYS ERR" => 0});
            ($matchcount,$result) = $self->parseLogFiles($_,$verify);
            if($result == 0){
	        $logger->warn(__PACKAGE__ . ".$sub_name: *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                $logger->error(__PACKAGE__ . ".$sub_name: FOUND ERRORS IN THE LOG: '$_'");
		$logger->error(__PACKAGE__ . ".$sub_name: Run 'grep \"SYS ERR\" $_' and 'grep \"SipsMemFree: corrupted block\" $_' for more information about the error");
		$logger->warn(__PACKAGE__ . ".$sub_name: *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
                $errorflag = 1;
            }
	}
    }

    ######## STORING THE LOGS ##################################################
    my $store_log  = $self->{STORE_LOGS};
    $store_log = $main::TESTSUITE->{STORE_LOGS} if(defined  $main::TESTSUITE->{STORE_LOGS});
    if (defined $store_log and $store_log) {
    	$self->{$self->{ACTIVE_CE}}->{conn}->cmd("cd /var/log/sonus/sbx/evlog/");
        my $tar_file = "logs_".$tcid.".tar.gz";
        $self->{$self->{ACTIVE_CE}}->{conn}->cmd("tar cf $tar_file @logfilenames");
        unless ($self->storeLogs($tar_file,$tcid,$copyLogLocation) ) {
            $logger->error(__PACKAGE__ . " $sub_name:   Failed to store the log file: $tar_file.");
        }
        $self->{$self->{ACTIVE_CE}}->{conn}->cmd("rm -rf $tar_file");
        $self->{$self->{ACTIVE_CE}}->{conn}->cmd("cd");
    }
   ######## CDR Verification ####################################################
    unless ($self->{SBC_TYPE} and $self->{SBC_TYPE} ne "S_SBC" and $self->{REDUNDANCY_ROLE} ne 'ACTIVE'){
    	if (defined($actrecordtype) && %cdrhash) {
        	my @actlogfilenames;
        	foreach (@logfilenames){
	    	push (@actlogfilenames, $_) if($_ =~ /\.ACT/);
        	}
   		#Introducing a sleep of 1 second to ensure that the SBC has enough time to log the record in the ACT file.
		sleep 1;
        	#Rolling over log to ensure that the content of ACT is completely read.
        	unless ( $self->rollLogs('acct')) {
        	    $logger->error(__PACKAGE__ . ".$sub_name:  Cannot roll over ACT log.");
        	    return 0;
        	}
        	$logger->debug(__PACKAGE__ . " $sub_name: Performing CDR Verification on the following ACT logs : \'@actlogfilenames\' ") unless(scalar @actlogfilenames == 1 );
        	foreach (@actlogfilenames){
	    		$logger->debug(__PACKAGE__ . " $sub_name: Performing CDR Verification on the following ACT log : \'$_\' ");
	    		$cdrhash{-cdrvariation} = $cdrvariation if (defined $cdrvariation);
            		my ($res,%resulthash) = $self->verifyCDR($_,$actrecordtype,%cdrhash);
            		while(my ($key,$val) = each (%resulthash)){
                	delete $cdrhash{$key};
            		}
	    		last if(scalar(keys(%cdrhash)) == 0);
        	}
		delete $cdrhash{-cdrvariation} if (defined $cdrhash{-cdrvariation});
        	if(scalar(keys(%cdrhash)) == 0){
		    $logger->debug(__PACKAGE__ . " $sub_name: CDR Verification success. Successfully matched all the entries from the input CDR Hash");
        	}else{
		    $cdrflag = 1;
        	}
    	}
    	else {
    	   $logger->debug(__PACKAGE__ . " $sub_name: Input CDR Hash or CDR Record Type is empty or undefined. CDR Verification Skipped !!");
    	}


    ######## Parse Logs ######################################################

    	if(defined($parselogfiletype) && @searchpattern){
    		foreach (@logfilenames){
	    		if($_ =~m/$parselogfiletype/i){
                		if( scalar(keys(%searchpattern))){
                			my ($matchcount,$result);
		    			my (@tempsearchpattern) = @searchpattern;
                    			$logger->debug(__PACKAGE__ . " $sub_name: Looking for the following patterns in the log '$_' \n ");
                    			map { $logger->debug("Pattern : '$_' Count : '$searchpattern{$_}'") } keys(%searchpattern);
                    			($matchcount,$result) = $self->parseLogFiles($_,\%searchpattern);
                    			unless($result == 1){
                        			$logger->debug(__PACKAGE__ . " $sub_name: Expected counts of match for the patterns NOT FOUND in the log ,'$_'");
                        			$parseflag = 1 if($passed == 0);
                        			for(my $pat = 0; $pat <= $#$matchcount; $pat++){
                            				$searchpattern{$searchpattern[$pat]} -= $matchcount->[$pat] if(defined $searchpattern{$searchpattern[$pat]});
                            				if($searchpattern{$searchpattern[$pat]} == 0){
                                				delete $searchpattern{$searchpattern[$pat]};
                                				splice @tempsearchpattern, $pat, 1;
                            				}
                        			}
						@searchpattern = @tempsearchpattern;
                        			last unless(scalar(keys(%searchpattern)));
                    			} else {
                        			$passed = 1;
                        			$parseflag = 0;
                        			$logger->debug(__PACKAGE__ . " $sub_name: All patterns are MATCHED in the log,'$_' ");
                        			last;
                    			}
				}else{
                    			$logger->debug(__PACKAGE__ . " $sub_name: Looking for the following patterns in the log '$_'  Patterns: '@searchpattern'");
		    			my ($matchcount,$result,@tempsearchpattern);
    	 	    			($matchcount,$result) = $self->parseLogFiles($_,@searchpattern);
		    			unless($result == 1){
        					$logger->debug(__PACKAGE__ . " $sub_name: All the patterns are NOT FOUND in the log,'$_'");
    		        			$parseflag = 1 if($passed == 0);
                        			for(my $pat = 0; $pat <= $#{$matchcount}; $pat++){
                            				unless( @{$matchcount}[$pat] > 0){
                                				push @tempsearchpattern, $searchpattern[$pat];
                            				}
						}
						@searchpattern = @tempsearchpattern;
                    			} else {
                        			$passed = 1;
                        			$parseflag = 0;
						$logger->debug(__PACKAGE__ . " $sub_name: All the patterns are FOUND in the log,'$_'");
						last;
                    			}
				}
	    		}
   	    	}
        }

    	else {
    		$logger->debug(__PACKAGE__ . " $sub_name: Input Parse log file type or Search Pattern is empty or undefined. Log Verification Skipped !!");
    	}
    }
    else {
       	$logger->debug(__PACKAGE__ . " $sub_name: CDR Verification and Parse Logs  will be Skipped for this '$self->{SBC_TYPE}'");
    }

    ######## cleanup - Rollback to Base Configuration  ###################
    unless ($self->{skip_rollback}) {
        unless ( $self->RollbackTo($self->{rollback}->{basetimestamp})) {
            $logger->error(__PACKAGE__ . ".$sub_name: Rollback to base config failed .");
            $rollflag = 1;
        }
    }


   # Perform GSX Copy Logs only if GSX Object Referance is defined!

   if ( defined $gsxObjRef ) {
        if ( $main::TESTSUITE->{STORE_GSXLOGS_IN_SBX} ){
	    unless( $self->getGSXlogs(-tcid => $tcid, -logFlag => 1, -sbxLogLocation => $copyLocation )) {
                $logger->error(__PACKAGE__ . " $sub_name:   Could not Copy GSX Logs Successfully");
		return 0;
            }
        }
   }
   # collect PSX logs if PSX Object is defined by initPSXObject subroutine

  my $flag =1 ;#TOOLS-20632
  $flag = 0 if(exists $self->{SBC_TYPE} and ($self->{SBC_TYPE}  ne 'S_SBC' or $self->{INDEX} != 1));
  my $psx_logs = (exists $self->{SBC_TYPE})?$self->{PARENT}->{PSX_LOGS}:$self->{PSX_LOGS}; #TOOLS-71652
  if($flag){
   for my $i (0..scalar(@psxObj)-1){#TOOLS-20632
       if(defined $psxObj[$i]){
           #PSX Pattern search
          foreach my $log (keys %psxhash) {
               foreach my $count (keys %{$psxhash{$log}}){
                   my $patterns = $psxhash{$log}{$count};
                   unless( $psxObj[$i]->search_pattern($patterns,$log,$count)) {
                       $psxflag = 1;
                       $logger->error(__PACKAGE__."$sub_name:PSX pattern search fails !!!");
                   }
                }
            }
         my $timeStamp = strftime("%Y%m%d%H%M%S",localtime);
         #collect PSX logs to ATS
         if (ref $psx_logs->[$i] eq 'ARRAY'){
           unless ($psxObj[$i]->getPSXLog(-testId     => $tcid,
                                          -logDir     => $main::log_dir,
                                          -logType    => $psx_logs->[$i],
                                          -timeStamp  => $timeStamp)){
               $logger->error(__PACKAGE__."$sub_name: Could not copy PSX Logs Successfully ");
               return 0;
           }else{
              $logger->debug(__PACKAGE__."$sub_name: Successfully copied PSX Logs to ATS");
           }
          }
          else{
            unless ($psxObj[$i]->getPSXLog(-testId     => $tcid,
                                          -logDir     => $main::log_dir,
                                          -logType    => $psx_logs,
                                          -timeStamp  => $timeStamp)){
               $logger->error(__PACKAGE__."$sub_name: Could not copy PSX Logs Successfully ");
               return 0;
          }else{
                $logger->debug(__PACKAGE__."$sub_name: Successfully copied PSX Logs to ATS");
          }
         }
        }
       }
    } # End of PSX log collection


   if ( $coreflag == 1 || $parseflag == 1 || $cdrflag == 1 || $errorflag == 1 || $rollflag == 1 || $psxflag == 1 || $ce_flag ==1 ){
       $logger->info(__PACKAGE__ . ".$sub_name: FLAGS: core: $coreflag cdr: $cdrflag parse(expected user-specified patterns not found in logs): $parseflag error(unexpected ATS-defined patterns found in logs): $errorflag rollback(Rollback to base config failure): $rollflag parse(expected user-specified patterns not found in psx logs): $psxflag  cenode(ERROR patterns found in CENODE logs:$ce_flag");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
   }else {
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
       return 1;
   }
}


=head2 C< unhideDebug >

=over

=item DESCRIPTION:

    This subroutine is used to reveal debug commands in the SBX5000 CLI. It basically issues the unhide debug command and deals with the prompts that are presented.

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The SBX5000 root user password (needed for 'unhide debug)(sonus1)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SBX5000::SBX5000HELPER::unhideDebug ( $cli_session, $root_password  ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        return 0;
    }

=back

=cut

sub unhideDebug {

    my $cli_session   = shift;

    my $sub_name = "unhideDebug";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($cli_session->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $cli_session->__dsbcCallback(\&unhideDebug, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my $root_password = shift;

    #TOOLS-15088 - to reconnect to standby before executing command
    if($cli_session->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($cli_session->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    my $previous_err_mode = $cli_session->{conn}->errmode("return");
    # Clearing the buffer
    $logger->debug(__PACKAGE__ . ".$sub_name: Clearing the buffer");
    $cli_session->{conn}->buffer_empty;

    # Execute unhide debug
    unless ( $cli_session->{conn}->print( "unhide debug" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-UnhideDebug Login Failed; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'unhide debug\'");

    my ($prematch, $match);
    WAIT_FOR:
    ($prematch, $match) = $cli_session->{conn}->waitfor(
                                    -match     => '/[P|p]assword:/',
                                    -match     => '/\[ok\]/',
                                    -match     => '/\[error\]/',
                                    -match     => $cli_session->{PROMPT},
                                                                ) ;

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched Password: prompt");

        # Give root password
        $cli_session->{conn}->print( $root_password );

        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                			-match => '/\[ok\]/',
                                                			-match => '/\[error\]/i',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-UnhideDebug Login Failed; ";
            return 0;
        }
        if ( $match =~ m/\[error\]/i ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($root_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-UnhideDebug Login Failed; ";
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'unhide debug\'");
        }

    }
    elsif ( $match =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'unhide debug\' accepted without password.");
    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'unhide debug\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-UnhideDebug Login Failed; ";
            return 0;
    }elsif($prematch =~ m/((Enabling|Disabling) updates \-\- read.+access)/) { # TOOLS-12250 & TOOLS-15493 : To handle the prompt "Enabling updates -- read/write access" or "Disabling updates -- read only access"
        $logger->warn(__PACKAGE__ . ".$sub_name:  Got '$1' message, so waiting for the password prompt again");
        goto WAIT_FOR;
    }else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-UnhideDebug Login Failed; ";
        return 0;
    }
    #TOOLS-19312
    unless (($prematch, $match) = $cli_session->{conn}->waitfor(-match => $cli_session->{PROMPT},
                                               -errmode => "return",
                                               -timeout => $cli_session->{DEFAULTTIMEOUT})) {
          $logger->warn(__PACKAGE__ . ".$sub_name:  Unable to get the prompt $cli_session->{PROMPT} ");
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
          return 0;
     };

    $logger->debug(__PACKAGE__ . ".$sub_name: Setting a flag to execute \"unhide debug\" if a session is reconnected");
    $cli_session->{'UNHIDE_DEBUG_SET'} = '1';
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< enterLinuxShellViaDsh >

=over

=item DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the SBX5000 CLI commands.

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh')(sonus)
    3rd Arg    - The SBX5000 root user password (needed for 'unhide debug')(sonus1)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::SBX5000HELPER::unhideDebug

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SBX5000::SBX5000HELPER::enterLinuxShellViaDsh ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        return 0;
    }

=back

=cut

sub enterLinuxShellViaDsh {

    my $cli_session     = shift;

    my $sub_name = "enterLinuxShellViaDsh";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($cli_session->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $cli_session->__dsbcCallback(\&enterLinuxShellViaDsh, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    #TOOLS-15429. Setting {ENTERED_DSH} for cloud sbc as dsh is not supported
    #TOOLS-17402 : Setting {ENTERED_DSH} if APPLICATION_VERSION >= V07.01.00
    if ( $cli_session->{CLOUD_SBC} || SonusQA::Utils::greaterThanVersion( $cli_session->{APPLICATION_VERSION}, 'V07.01.00')){
        $logger->debug(__PACKAGE__ . ".$sub_name: Command will be executed directly using the ACTIVE_CE root object as dsh is disabled");
        $logger->debug(__PACKAGE__ . ".$sub_name: Setting the flag {ENTERED_DSH} to 1");
        $cli_session->{ENTERED_DSH} = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    my $user_password   = shift;
    my $root_password   = shift;

    my $previous_err_mode = $cli_session->{conn}->errmode("return");


    # Execute unhide debug
    unless ( unhideDebug ( $cli_session, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'unhide debug\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($prematch, $match);

    # Execute dsh
    unless ( $cli_session->{conn}->print( "dsh" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'dsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'dsh\'");

     ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                                    -match     => '/[P|p]assword:/',
                                                                    -match     => '/\[error\]/',
                                                                    -match     => '/Are you sure you want to continue connecting [\(\[]yes[\/,]no[\]\)]/',
                                                                    -match     => '/Do you wish to proceed <y\/N>/i',
                                                       );

    if ( $match =~ m/<y\/N>/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched: Do you wish to proceed, entering \'y\'...");
        $cli_session->{conn}->print("y");
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                     -match     => '/Are you sure you want to continue connecting [\(\[]yes[\/,]no[\]\)]/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'y\' to Do you wish to proceed prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
        }
    }

    if ( $match =~ m/yes[\/,]no/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes/no prompt for RSA key fingerprint");
        $cli_session->{conn}->print("yes");
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                                     -match     => '/[P|p]assword:/',
                                                                     -match     => '/\[error\]/',
                                                                    )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after answering \'yes\' to RSA key fingerprint prompt.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
        }
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched password: prompt");
        $cli_session->{conn}->print($user_password);
        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                -match => '/Permission denied/',
                                                -match => '/linuxadmin/',
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
        }
        if ( $match =~ m/Permission denied/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($user_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
        }
        elsif ( $match =~ m/linuxadmin/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password used \$user_password accepted for \'dsh\'");
            }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \($user_password\) for unhide debug was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
        }

    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  dsh debug command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
            return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Login via dsh Failed; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< enterLinuxShellViaDshBecomeRoot >

=over

=item DESCRIPTION:

    This subroutine is used to enter the linux shell via the dsh command available in the SBX5000 CLI commands. Once at the linux shell it will issue the su command to become root.

=item ARGUMENTS:

    1st Arg    - The CLI session object
    2nd Arg    - The user password (needed for 'dsh') (sonus)
    3rd Arg    - The SBX5000 root user password (needed for 'unhide debug' and 'su -')(sonus1)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::SBX5000HELPER::unhideDebug
    SonusQA::SBX5000::SBX5000HELPER::enterLinuxShellViaDsh

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ( SonusQA::SBX5000::SBX5000HELPER::enterLinuxShellViaDshBecomeRoot ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell and become root via Dsh.");
        return 0;
    }

=back

=cut

sub enterLinuxShellViaDshBecomeRoot {

    my $cli_session     = shift;

    my $sub_name = "enterLinuxShellViaDshBecomeRoot";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($cli_session->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $cli_session->__dsbcCallback(\&enterLinuxShellViaDshBecomeRoot, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    #TOOLS-15429. Setting {ENTERED_DSH} for cloud sbc as dsh is not supported
    #TOOLS-17402 : Setting {ENTERED_DSH} if APPLICATION_VERSION >= V07.01.00
    if ( $cli_session->{CLOUD_SBC} || SonusQA::Utils::greaterThanVersion( $cli_session->{APPLICATION_VERSION}, 'V07.01.00')){
        $logger->debug(__PACKAGE__ . ".$sub_name: Command will be executed directly using the ACTIVE_CE root object as dsh is disabled");
        $logger->debug(__PACKAGE__ . ".$sub_name: Setting the flag {ENTERED_DSH} to 1");
        $cli_session->{ENTERED_DSH} = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    my $user_password   = shift;
    my $root_password   = shift;

    my $previous_err_mode = $cli_session->{conn}->errmode("return");


    # Execute enterLinuxShellViaDsh
    unless ( enterLinuxShellViaDsh ( $cli_session, $user_password, $root_password ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot \'enterLinuxShellViaDsh\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered Linux shell");

    # Become Root using `su -`
    unless ( $cli_session->{conn}->print( "su -" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'su -\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'su -\'");

    my ($prematch, $match);
       ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                            -match     => '/[P|p]assword:/',
                                                            -errmode   => "return",
							  );

    if ( $match =~ m/[P|p]assword:/ ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched \'Password:\' prompt");

        $cli_session->{conn}->print( $root_password );

        unless ( ($prematch, $match) = $cli_session->{conn}->waitfor(
                                                -match => '/try again/',
                                                -match => $cli_session->{PROMPT},
                                                -errmode   => "return",
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $cli_session->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $cli_session->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/try again/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \(\"$root_password\"\) for su was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login via dsh Failed; ";
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'su\'");
        }

    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login via dsh Failed; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< _execShellCmd >

=over

=item DESCRIPTION:

    This subroutine is used to execute the passed cmd and return the shell status.

    For e.g. running 2 commands in parallel on different objects and then returning to check completion later, can be first issued with timeout=0 to /just/ send the command - then called again with cmd = "##WAITONLY##"  and the actual timeout to do the waiting and checking. Example of this type of use in cleanStartSBX().

=item ARGUMENTS:

    1st Arg    - The root session sbx object. [ Mandatory ]
    2nd Arg    - The cmd to be executed [ Mandatory ]
    3rd Arg    - Timeout value. [Mandatory]
    4th Arg    - List of strings to be checked for occurance in the cmd output. [ Optional ]

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None.

=item OUTPUT:

    0   - fail
    (1 , command output )  - success

=item EXAMPLE:

    my $cmd = 'service sbx stop';
    my $timeout = 300;
    my $checkRes = [
        'Stopping asp:',
        'Stopping AMF watchdog...',
        'Removing semaphores',
    ];
    my ($cmdStatus , @cmdResult) = _execShellCmd($rootObj,$cmd,$timeout,$checkRes);
    unless ($cmdStatus){
            $logger->error(__PACKAGE__ . ".$sub_name:   $cmd unsuccessful  ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
	}

=back

=cut



sub _execShellCmd {
    my $self    = shift;
    my $cmd     = shift;
    my $timeout = shift;
    my $verifyResults  = shift;
    my $remove_cmd = shift;

    my $sub_name = '_execShellCmd()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    unless ( defined $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument \'cmd\' not present or empty.");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Fix for TOOLS-8479
    my $conn_class = ref($self->{conn});
    $logger->debug(__PACKAGE__ . ".$sub_name: self->{conn} class : $conn_class");

    $cmd = 'sbx'.$1 if ( $cmd =~ /service\s+sbx\s+([a-z]+)/ and SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'}, 'V06.02.00') ) ;   # TOOLS - 13145

    $logger->info(__PACKAGE__ . ".$sub_name: Command to be executed is  : \'$cmd\'");
    #For D-SBC, ref($self->{conn}) should be 'SonusQA::SBX5000', otherwise it will be 'Net::Telnet'
    if($conn_class eq 'SonusQA::SBX5000'){
        my $dsbc_ce = $self->{conn}->{DSBC_CE};
        unless($dsbc_ce){#In case of D-SBC, its ACTIVE_CE or STAND_BY
            $logger->error(__PACKAGE__ . ".$sub_name: Can't proceed, since its not a valid D-SBC object.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        my @final_out;;
        my $final_result = 0;
        $self = $self->{conn}->{DSBC_OBJ};
        my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
        my $role_from_user = ($dsbc_ce =~ /(active|CE0LinuxObj)/i) ? 'ACTIVE' : 'STANDBY'; #possible values for dsbc_ce is ACTIVE_CE or STAND_BY
        my @role_arr = $self->nkRoleLookUp($cmd) if($self->{NK_REDUNDANCY});
        foreach my $personality (@dsbc_arr){
            foreach my $index(keys %{$self->{$personality}}){
                if($self->{NK_REDUNDANCY}){
                    my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'};
                    next unless ($role_from_user =~ /$role/i);
                }

                my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
                my $linux_obj_name = ($dsbc_ce=~/LinuxObj/) ? $dsbc_ce : $self->{$personality}->{$index}->{$dsbc_ce};
                $logger->debug(__PACKAGE__ . ".$sub_name: Calling _execShellCmd for '$alias->$dsbc_ce' ('$personality\-\>$index\-\>$linux_obj_name').");
                my ($result, @cmd_out) = _execShellCmd( $self->{$personality}->{$index}->{$linux_obj_name}, $cmd, $timeout, $verifyResults);
                push (@final_out, @cmd_out); #storing the result of each sbc
                unless($result){
                    $logger->warn(__PACKAGE__ . ".$sub_name: '$cmd' unsuccessful for '$alias->$dsbc_ce' ('$personality\-\>$index\-\>$linux_obj_name').");
                    $logger->debug(__PACKAGE__ . ".$sub_name: command output: ". Dumper(\@cmd_out));
                }
                else{
                    $final_result = $result; #considering its pass, if its pass for any one of the sbc
                }
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub [$final_result]");
        return ($final_result, @final_out);
    }
    # End of fix for TOOLS-8479

    unless ( defined $timeout ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Timeout is not specified. Using default \'$self->{DEFAULTTIMEOUT}\' seconds..");
        $timeout = $self->{DEFAULTTIMEOUT};
    }
    my $cmdFailFlag = 0;
    my $errMode = sub {
        unless ( $cmd =~ /exit/ ) {
            $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
            $logger->error( 'Timeout OR Error for command (' . "$cmd" . ')');
            $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        }
	$cmdFailFlag = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    };

    if ($cmd ne "##WAITONLY##") {
RETRY:
	    $logger->debug(__PACKAGE__ . ".$sub_name: Clearing the buffer.. ");
	    $self->{conn}->buffer_empty;
	    unless( $self->{conn}->print($cmd) ){
	        $logger->error(__PACKAGE__ . ".$sub_name: Unable to enter the command \'$cmd\' ");
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	        $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd unsuccessful; ";
	        return 0;
	    }
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name: ##WAITONLY## specified - no command to execute - waiting for prompt");
    }


    if($timeout eq 0) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Timeout=0 specified - assuming nothing to wait for - Leaving Sub");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }

    my ($prematch, $match);
    unless(($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT},
                                                         -match     => '/.*do you (wish|want) to continue\?\s*[\(\[](y|yes)[,\/](n|no)[\)\]]/i',
                                                         -match     => '/ERR: maapi_apply_trans error 10 the configuration database is locked by session/',
                                                         -match     => '/ERR: Unable to perform the license operation: there are outstanding changes to the database/', 
                                                         -timeout   => $timeout,
  						         -errmode   => $errMode
                                                         )){
        $logger->error(__PACKAGE__ . ".$sub_name: Did not match the expected prompt after entering the command \'$cmd\'");
        $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful  ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: ". $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: ". $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: buffer: ".${$self->{conn}->buffer});
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd unsuccessful; ";
 
        #TOOLS-75843
        #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
        $logger->debug(__PACKAGE__ . ".$sub_name: Sending ctrl+c");
        unless($self->{conn}->cmd(-string => "\cC")){
            $logger->warn(__PACKAGE__ . ".$sub_name: Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);

            #Reconnect in case ctrl+c fails.
            $logger->warn(__PACKAGE__ . ".$sub_name: Trying to reconnect...");
            $self = $self->{OBJ} if(exists $self->{OBJ}); #for SBX

            unless( $self->reconnect() ){
                $logger->warn(__PACKAGE__ . ".$sub_name: Failed to reconnect.");
                &error(__PACKAGE__ . ".$sub_name: CMD ERROR - EXITING");
            }
        }
        else {
            $logger->info(__PACKAGE__ .".$sub_name: Sent ctrl+c successfully.");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @cmdResult;
    if($match =~ /ERR:/){
        $logger->warn(__PACKAGE__ . ".$sub_name :Got error $match");
        $logger->debug(__PACKAGE__ . ".$sub_name:Sleeping for 10 sec before retrying");
        sleep(10);
        goto RETRY;
    }
    if($match =~ /.*do you (wish|want) to continue\?\s*[\(\[](y|yes)[,\/](n|no)[\)\]]/i){
	my $resp = $2 || 'y';
        $logger->debug(__PACKAGE__ . ".$sub_name: Matched for \'$prematch\' \'$match\' Entering \'$resp\' ");
        unless( $self->{conn}->print($resp)){
            $logger->error(__PACKAGE__ . ".$sub_name: Unable to enter \'$resp\'");
            $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd unsuccessful; ";
            return 0;
        }
        unless(($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT},
                                                             -timeout   => $timeout
                                                         )){
            $logger->error(__PACKAGE__ . ".$sub_name: Did not match the expected prompt after entering \'y\' ");
            $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd unsuccessful; ";
            return 0;
        }
	@cmdResult = split ('\n', $prematch);
    }else{
	@cmdResult = split ('\n', $prematch);
    }

    my @cmdStatus;
    my $cmd1 = 'echo $?';
    unless ( @cmdStatus = $self->{conn}->cmd( String =>$cmd1, Errmode => $errMode ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: CMD ERROR. Could not get Shell return code from $cmd1 after $cmd.");
        $logger->error(__PACKAGE__ . ".$sub_name: $cmd1 after $cmd unsuccessful  ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return (0,@cmdResult);
    }
    unless ( $cmdStatus[0] == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name: CMD ERROR: return code $cmdStatus[0] --\n@cmdStatus after $cmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: CMD RESULT: ".Dumper(\@cmdResult));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return (0,@cmdResult);
    }

    my $count = 0;
    if ( ( defined $verifyResults ) &&
         ( @cmdResult ) ) {
        foreach ( @{$verifyResults} ) {
            my $line = $_;
            foreach ( @cmdResult ) {
                if( m/\Q$line\E/ ) {
		    $count++;
        	}
            }
	}
        unless ( $count == scalar @$verifyResults ) {
            $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful  ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	    return (0,@cmdResult);
	}
    }
    if ($cmdFailFlag){
        $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful  ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd unsuccessful; ";
	return (0,@cmdResult);
    }
    shift @cmdResult if($remove_cmd);                        #Removing first line as it contains the command
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub [1]");
    return ( 1 ,@cmdResult  );
}



=head2 C< cleanStartSBX >

=over

=item DESCRIPTION:

    1. This subroutine is used to enter into the linux shell of the machine and execute the list of commands passed.
    2. It is called before starting the configuration of the SBC to have a fresh start by executing '/opt/sonus/sbx/scripts/clearDBs.sh' cmd and according to the value of
license_mode flag installs license.If the user pass a hash reference then no need to pass the license_mode flag because with the key value will deduce the flag value.
    Example : -nwl key will represent NWL license installation
              -legacy key will represent legacy license installation.
=item ARGUMENTS:

    1St Arg    - The timeout value required to execute the service start and stop commands
                 in seconds. [ Default value 300 seconds ] While testing, it was found that
		 at least 300 seconds of timeout value is required in order to execute the stop or
		 start services successfully everytime. Depends on the box, so pass the value accordingly.
    2nd Arg    - Number attempts for synstatus check, each attempt is followed with the dealy of 60 sec's
    3rd Arg    - License mode flag, decides the license intallation.
                 If value is,
                 0 - No license installation.
                 1 - legacy license installtion.
                 2 - NWL (Network Wide License) installation.

                                or
    pass a hash reference.

   -nwl => contains info regarding NWL license (please refer example section here and documentation of configureNWL for usage)
   -legacy => contains info regarding legacy license (please refer example section here and documentation of generateLicense for usage)
   -timeout => refer 1st Arg
   -attempt => refer 2nd Arg

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

1.
    unless($sbxObj->cleanStartSBX( )){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  ");
    }



2.
Userdefined license installtion :

  passing a hash reference as the input.

    a.Legacy license installtion.

        my %hash = (
                      -legacy => {
                                        -licenseTool => 1,-file_name => 'lic_template', -host_id1 => '0000000000', -host_id2 => '1111111111', -bundle_name => 'li_license',
                                 },
                      -attempt => 5,
                      -timeout => 180,
                   );

            unless($sbxObj->cleanStartSBX( \%hash)){
                my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
                $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  ");
            }
    b.NWL license installtion.


        my %license = (
                        'ENCRYPT'     => {minCount => 20,
                                          maxCount => 30},
                        'SBC-POL-E911'=> undef,
                  );
        my %hash = (
                      -nwl => {
                                        -timeout => 180,-license => \%license,
                              },
                      -attempt => 5,
                      -timeout => 180,
                   );

            unless($sbxObj->cleanStartSBX( \%hash)){
                my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
                $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  ");


 Note -> Inorder to retain the old functionality of this function ( one can call the function without object from testsuiteList.pl), below maodifications are made
	- If this function is called without the object ( object stands for -> refrance pointing SonusQA::SBX5000 namespace), it will consider  function call is for stand alone SBX with arguments ip, root password and command list, hence will be internally redirected to cleanStartStandAloneSBX().

 example -

 ***************    BELOW CALL WILL BE REDIRECTED TO cleanStartStandAloneSBX()   ***************************

    my ($host_ip, $rootpwd, $timeout, $commands);
    $host_ip = '10.6.82.44';
    $rootpwd = 'sonus1';
    $timeout = 360;
    $commands = [
        'service sbx stop',
        '/opt/sonus/sbx/scripts/removecdb.sh',
        'cd /opt/sonus/sbx/psx/sql',
        'perl configureDB -install NEW -loglevel 1 -force Y',
        'service sbx start',
    ];
    unless(&SonusQA::SBX5000::SBX5000HELPER::cleanStartSBX( $host_ip , $rootpwd,$commands , $timeout)){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  ");
    }

=back

=cut


sub cleanStartSBX {

    my $sub_name = 'cleanStartSBX';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
 
    # Assumption logic to decide method is called upon the object or not
    unless (ref ($_[0]) eq 'SonusQA::SBX5000' ) {
        $logger->info(__PACKAGE__ . ". Assumption made based on arguments passed,this method is called for stand alone SBX without connection handler, Hence redirected to -> cleanStartStandAloneSBX");
        unless (cleanStartStandAloneSBX(@_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: unable do clean start operation stand alone SBX");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CleanDb unsuccessful; ";
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: successfully performed clean start operation stand alone SBX");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
            return 1;
        }
    }

    my ($self) = shift;
    my ($timeout, $attempt, $license_mode, %args, @nwl_list, @jar_list);
    my $is_nwdl = ($self->{TMS_ALIAS_DATA}->{LICENSE}->{1}->{TYPE} eq 'nwdl')?1:0; #checking if NWDL license is enabled in TMS Alias
    
    if(ref($_[0]) eq 'HASH'){ #TOOLS-16711
        my $input = shift;
        %args = %{$input};
        $timeout = $args{-timeout};
        $attempt = $args{-attempt};
    }else{
        ($timeout, $attempt,$license_mode) = @_;
    }

    unless($main::skip_license_check == 1){
        if ($license_mode == 1 and ! exists $args{-legacy}){ #Permanent License
            @jar_list = $self;
        }elsif($license_mode == 2 or exists $args{-nwl}){ #NWL license
            @nwl_list = $self;
        }else{
#TOOLS-17487 - If user didn't pass license_mode flag and the input for license, we will check SLS->IP/IPv6 of each instance and decide the license mode.
            if ($self->{D_SBC}) {
                foreach my $personality (@{$self->{PERSONALITIES}}) {
                    foreach my $index (keys %{$self->{$personality}}){
                        ($self->{$personality}->{$index}->{TMS_ALIAS_DATA}->{SLS}->{1}->{IP} || $self->{$personality}->{$index}->{TMS_ALIAS_DATA}->{SLS}->{1}->{IPV6}) ? push (@nwl_list, $self->{$personality}->{$index}) : push (@jar_list, $self->{$personality}->{$index}) ;
                    }
                }
            }else{
                ($self->{TMS_ALIAS_DATA}->{SLS}->{1}->{IP} || $self->{TMS_ALIAS_DATA}->{SLS}->{1}->{IPV6}) ? (@nwl_list = $self) : (@jar_list = $self) ;
            }
        }
    }
    
    unless($self->{AWS_LICENSE} or $is_nwdl) #TOOLS-19937 #TOOLS-20303
    {
      foreach my $obj (@jar_list){
          $logger->debug(__PACKAGE__ . ".$sub_name: Permenant license generation");
          unless( $obj->generateLicense( -skip_cleanstart => 1)){ # to install permanent licenses
              $logger->error(__PACKAGE__ . ".$sub_name: ERROR. Installing license failed");
              $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
              $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error Installing License; ";
              return 0;
          }
      }
    }
    if ( $self->{OAM}) {
        my $flag = 1;
        unless ($self->execSystemCliCmd("request system admin vsbcSystem restoreRevision revision 1")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Falied to restore the revision back to 1");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: before reconnect, waiting 5 mins for instances to come up after setting revision to 1");
        sleep(300) ;
        unless ($self->makeReconnection(-timeToWaitForConn => 50))  {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to make reconnect after restoring the revision back to 1");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }else {
        my $cmd  =  '/opt/sonus/sbx/scripts/clearDBs.sh'; 
        $self->{AWS_LICENSE} = 0;#TOOLS-19937
        unless ($self->serviceStopAndExec(-cmd => "$cmd" , -timeout => "$timeout" )) {
            $logger->error(__PACKAGE__ . ".$sub_name unable to Execute clearDB cmd ");
            &error("Unable to Execute clearDB cmd");
        }
    }


    #TOOLS-77874
    #TOOLS-72075
    if($self->{ASAN_BUILD}) {
        my $locallogname = $main::log_dir;
        $logger->debug(__PACKAGE__. ".$sub_name: Copying and Removing logs from the path \"/var/log/sonus/sbx/asp_saved_logs/normal/\"");
        $logger->debug(__PACKAGE__. ".$sub_name: Removing core files from /home/sonus/logs/oom");
        foreach my $ce (@{$self->{ROOT_OBJS}}) {
            my $timestamp = strftime("%Y%m%d%H%M%S",localtime);
            my $file = "CE_NODE_logs_cleanStartSBX_$ce"."_"."$timestamp.tar";
            my ($cmdStatus, @cmdResult) = _execShellCmd($self->{$ce},"tar -czf /tmp/$file /var/log/sonus/sbx/asp_saved_logs/normal/*");
            if($cmdStatus) {
                my %scpArgs;
                $scpArgs{-destinationFilePath} = $locallogname;
                $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."/tmp/$file";
                unless(&SonusQA::Base::secureCopy(%scpArgs)) {
                    $logger->info(__PACKAGE__ . ".$sub_name: Unable to copy the file $file to $locallogname");
                }
                _execShellCmd($self->{$ce},"rm -rf /tmp/$file");
            }
            _execShellCmd($self->{$ce},'rm -rf /var/log/sonus/sbx/asp_saved_logs/normal/*');
            _execShellCmd($self->{$ce},'rm -rf /home/sonus/logs/oom/*');
        }
    }

    if((($self->{AWS} || $self->{CLOUD_PLATFORM} eq 'Google Compute Engine') && SonusQA::Utils::greaterThanVersion($self->{APPLICATION_VERSION},'V07.02.00')) || $is_nwdl ) { #TOOLS-20725 #TOOLS-20303 TOOLS-74827
      $logger->debug(__PACKAGE__.".$sub_name: Enabling admin login with password");
      unless($self->enableAdminPassword()) {
        $logger->error(__PACKAGE__.".$sub_name: Unable to set admin password");
        $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving Sub [0]");
        return 0;
      }
    }    
    
    if($args{-legacy}->{-licenseTool} == 1 or $is_nwdl) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Temporary license generation using LicenseTool");
        unless( $self->generateLicense(%{$args{-legacy}}, -nwdl => $is_nwdl)) { # to install temporary licenses using license tool
            $logger->error(__PACKAGE__ . ".$sub_name: ERROR. Installing license failed");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error Installing License; ";
            return 0;
        }
    }

    foreach my $obj (@nwl_list){
        unless( $obj->configureNWL( %{$args{-nwl}} )){ # To install NWL
            $logger->error(__PACKAGE__ . ".$sub_name: ERROR. Installing license failed");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

        my %cliHash = ( 'Policy Data' => 'syncCompleted',
                        'Disk Mirroring' => 'syncCompleted',
                        'Configuration Data' => 'syncCompleted',
                        'Call/Registration Data' => 'syncCompleted' );

        unless ($self->{HA_SETUP}) {
            $logger->debug(__PACKAGE__ . ".$sub_name: this is not \"HA SETUP\" ");
            map {$cliHash{$_} = 'unprotected'} keys %cliHash;
        }

        unless ($self->checkSbxSyncStatus('show status system syncStatus', \%cliHash, $attempt)) {
            $logger->debug(__PACKAGE__ . ".$sub_name: sync status check failed");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        #TOOLS-18434 and TOOLS-19574 - M/T SBC delay to avoid 'application error'.
        $logger->debug(__PACKAGE__ . ".$sub_name: 130s sleep "); 
	sleep 130;
        
 
        if ((defined $main::TESTSUITE->{SET_FIPS_MODE}) && ($main::TESTSUITE->{SET_FIPS_MODE} == 1)) {
            $logger->info(__PACKAGE__ . ".$sub_name: setting FIPS mode");
            unless ($self->setFipsMode()) {
                $logger->error(__PACKAGE__ . ".$sub_name: failed to set FIPS mode");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving->[0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to set FIPS mode; ";
                return 0;
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Set session idle timeout flag : \'$main::TESTSUITE->{SET_SESSION_TIMEOUT}\' | POST 4.0 flag : \'$self->{POST_4_0}\'");
        if (((!defined $main::TESTSUITE->{SET_SESSION_TIMEOUT} or $main::TESTSUITE->{SET_SESSION_TIMEOUT} != 0 ) and $self->{POST_4_0} == 1) or $main::TESTSUITE->{SET_SESSION_TIMEOUT} == 1 ){
            #Enter this block when atleast one of the conditions hold good : 1. $TESTSUITE->{SET_SESSION_TIMEOUT} is defined in the testsuitelist.pl and it is set to 1
            #					                             2. SBC build is post 4.0 and either $TESTSUITE->{SET_SESSION_TIMEOUT} is not defined or it is set to 1 if it is defined 
            my $sbxName = ($self->{CLOUD_SBC}) ? "vsbcSystem" : $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
            my $idletimeout = defined($main::TESTSUITE->{IDLE_TIMEOUT}) ? $main::TESTSUITE->{IDLE_TIMEOUT} : 120;
            my $maxsessions = defined($main::TESTSUITE->{MAX_SESSIONS}) ? $main::TESTSUITE->{MAX_SESSIONS} : 5;
            $logger->debug(__PACKAGE__ . ".$sub_name: Setting session idle timeout on $sbxName to $idletimeout minutes and maximum no. of sessions to $maxsessions");
            unless ( $self->enterPrivateSession() ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            my @cmds = ("set system admin $sbxName accountManagement sessionIdleTimeout idleTimeout $idletimeout",
                    "set system admin $sbxName accountManagement maxSessions $maxsessions");

            # For D_SBC
            my @prev_personalities;
            if ($self->{D_SBC}) {
                @prev_personalities = ($self->{SELECTED_PERSONALITIES}) ? @{$self->{SELECTED_PERSONALITIES}} : ();
                @{$self->{SELECTED_PERSONALITIES}} = @{$self->{PERSONALITIES}};
            }
            my $error;
            $error = 1 unless ( $self->execCommitCliCmd(@cmds));
            @{$self->{SELECTED_PERSONALITIES}} = @prev_personalities if($self->{D_SBC});
            $error = 1 unless($self->leaveConfigureSession);
            if($error){
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            if ( $self->{CLOUD_SBC}){
                unless ($self->setNtpServer()){
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
    unless($self->{TYPE}=~ /slb|mrfp/ and SonusQA::Utils::greaterThanVersion($self->{APPLICATION_VERSION},'V08.02.00')){
    	#TOOLS-17987
    	unless($self->enableTRC()){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to enable TRC log level4");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
    	}
    }
    $self->{CMD_INFO}->{DSBC_CONFIG} = 0; #tools-8478, will not do DNS configuration if this flag is set.
    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}



=head2 C< checkProcessStatus >

=over

=item DESCRIPTION:

    This subroutine is used to check for the statuses of processes running in the SBX.

=item ARGUMENTS:

Format 1 :
	Calling with Login Credentials,

    1st Arg    - The ip address of the sbx machine. [ Mandatory ]
    2nd Arg    - root password of the machine. [ Mandatory ]
    3rd Arg    - The timeout value required to execute the service sbx status command.
                 Default value of 10 seconds.
    4th Arg    - Time interval required before trying next time for the service status. Default= 10 seconds.
    5th Arg    - Retries No is the no of retry attempts to be done to check for
                 the success of the process statuses. Default = 30.
    6th Arg    - processStatus is the required status of the processes mentioned in procList.
                 Default status = running .
    7th Arg    - processList is the list of processes whose statuses are required to be checked
                 by the user. If not passed, the processes with process id's whose status will
                 be shown when executing status command will be the default list of processes.

Format 2 :
	Calling with SBC object,

        	All the arguments mentioned in Foramt 1 can be passed as a key value pair. check Example 3.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::Base::new

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLES:

 1. With only the mandatory arguments, which means all the processes will be checked for running status with default values of time interval and timeout and retries.
    my $host_ip = '10.6.82.44';
    my $root_password = 'sonus1';
    unless(SonusQA::SBX5000::SBX5000HELPER::checkProcessStatus( $host_ip , $root_password  )){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " Cannot execute the checkProcessStatus routine  ");
    }
 2. With all arguments passed.
    my ($host_ip, $rootpwd, $timeOut, $timeInterval, $noOfRetries, $processStatus, $processList );
    $host_ip = '10.6.82.44';
    $rootpwd = 'sonus1';
    $timeOut = 5;  # in seconds
    $timeInterval = 5 ; # default value of 5
    $noOfRetries = 5;  # default value of 5
    $processStatus = 'running';
    $processList = [
        'asp_amf',
        'CE_2N_Comp_EnmProcessMain',
        'CE_2N_Comp_DsProcess',
        ];

    unless(SonusQA::SBX5000::SBX5000HELPER::checkProcessStatus( $host_ip, $rootpwd , $timeOut ,
        $timeInterval , $noOfRetries ,$processStatus, $processList  )) {
            my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
            $logger->error(__PACKAGE__ . " Cannot execute the checkProcessStatus routine  ");
    }
 3. With SBC object.
    unless($sbc_object->checkProcessStatus( -timeout => 30, -timeInterval => 15, -noOfRetries => 10, -processStatus => 'stopped', -processList => ['CE_2N_Comp_ScpaProcess','CE_2N_Comp_DiamProcess'])){
        $logger->error(__PACKAGE__ . " Cannot execute the checkProcessStatus routine  ");
    }

=back

=cut


sub checkProcessStatus {

    my ($self, %args, $hostip, $rootpwd, $timeout, $timeInterval, $noOfRetries, $processStatus, $processList, $rootObj, @root_obj_arr);

    my $sub_name = 'checkProcessStatus';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    if( ref ($_[0]) eq 'SonusQA::SBX5000' or ref ($_[0]) eq 'SonusQA::Base'){
        $self = shift;
        %args = @_;
        if ($self->{D_SBC}) {
            my %hash = (
                        'args' => [@_]
                );
            my $retVal = $self->__dsbcCallback(\&checkProcessStatus, \%hash);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
            return $retVal;
        }

	    $timeout = $args{-timeout};
        $timeInterval = $args{-timeInterval};
        $noOfRetries = $args{-noOfRetries};
        $processStatus = $args{-processStatus};
        $processList = $args{-processList};

        if(ref ($self) eq 'SonusQA::SBX5000'){
            @root_obj_arr = $self->{$self->{ROOT_OBJS}->[0]};
            push (@root_obj_arr, $self->{$self->{ROOT_OBJS}->[1]}) if(exists $self->{$self->{ROOT_OBJS}->[1]});
        } else {
            @root_obj_arr = $self;
        }

    }else{
        ($hostip, $rootpwd, $timeout, $timeInterval, $noOfRetries, $processStatus, $processList) = @_;

        unless ( defined $hostip and defined $rootpwd) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Host IP[$hostip] or Root Password[$rootpwd] or SBC object not passed or empty.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        # Create SSH session object using root login & port 2024

        unless ( $rootObj = makeRootSession( -obj_host => $hostip, -root_password => $rootpwd, -defaulttimeout => 60)){
            $logger->error(__PACKAGE__ . ".$sub_name: SBX Root object creation unsuccessful");
            return 0;
        }
        $logger->error(__PACKAGE__ . ".$sub_name: SBX Root object creation successful");
        @root_obj_arr = $rootObj;

    }

    # Default Timeout value of 10 secs.
    unless ( defined $timeout ){
        $timeout = 10;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Timeout set to \'$timeout\' seconds.");
    }

    unless ( defined $timeInterval ){
        $timeInterval = 10;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Time Interval between retries set to \'$timeInterval\' seconds.");
    }

    unless ( defined $noOfRetries ){
        $noOfRetries = $self->{ASAN_BUILD}?60:30;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument No. of Retries set to \'$noOfRetries\'.");
    }

    unless ( defined $processStatus ){
        $processStatus = 'running';
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Process Status set to \'$processStatus\'.");
    }

    unless ( defined $processList ){
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Process List is not set so checking for ALL process(s).");
    }

    # Execute 'service sbx status' and check for the status of mentioned processes.

    my $statusFailFlag = 0;
    my $loop = 1;
    foreach my $obj (@root_obj_arr) {
        while ( $loop <= $noOfRetries ) {

            $logger->debug(__PACKAGE__ . ".$sub_name: sleep for ($timeInterval) seconds.");
            sleep ($timeInterval);

            my $cmd = 'service sbx status';
            my ($result,@cmdResult) = _execShellCmd($obj, $cmd, $timeout );

            my %curProcessStatus;
            $statusFailFlag = 0;
            if ( @cmdResult ) {
                foreach ( @cmdResult ) {
	            if ( /(asp_amf|CE_2N_Comp_\w+|Policy server DB|safplus\w+)[\s\S\(\)]*\s+is\s+(\w+)/ ) {
                        $curProcessStatus{$1} = $2;
                    }
                }
            }

            unless (defined $processList){
	        @{$processList} = keys(%curProcessStatus);
            }
            foreach ( @{$processList} ){
                my $process = $_;
                if ( $curProcessStatus{$process} eq $processStatus ) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: Process List \'$process\' is in expected \'$curProcessStatus{$process}\' status.");
	        }
                else {
                    $logger->error(__PACKAGE__ . ".$sub_name: Process List \'$process\' status expected \'$processStatus\' but in $curProcessStatus{$process}.");
                    $statusFailFlag = 1;
	        }
	    }

            if ($processStatus eq 'running'){

                unless ( !$statusFailFlag and $cmdResult[-1] =~ /\*\*\s+Service\s+running\s+\[(active|standby)\]\s+\*\*/ ){
                    $logger->debug(__PACKAGE__ . ".$sub_name: SBC is Not UP, [$cmdResult[-1]]");
                    $statusFailFlag = 1;
                }else{
                    $logger->debug(__PACKAGE__ . ".$sub_name: SBC is UP, [$cmdResult[-1]]");
                }
            }
            unless ($statusFailFlag){
                $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL - loop($loop), all process are in expected status($processStatus).");
                last ;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: UNSUCCESSFUL - loop($loop), all process are not in expected status($processStatus) or SBC is not up.");
            $loop++;
        }#while loop end

    }# for loop end

    # Close SSH session & Destory it.
    if($rootObj){
        $logger->debug(__PACKAGE__ . ".$sub_name: Destroying SBX Root Object created.");
        $rootObj->{conn}->close;
        $rootObj->DESTROY;
    }
    if( $statusFailFlag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UN-SUCCESSFUL.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 C< rebootSBX >

=over

=item DESCRIPTION:

    This is a standalone API which creates a TELNET Object to the host with root as user
    and executes the reboot command.
    Default command 'reboot' is used when not passed by the user.
    After executing the command, API tries to reach the SBX machine
    by pinging.
    This is done in loops, and user is supposed to enter the appropriate values desired
    for the time interval and no of retries for the loop.If not passed default values will
    be used.

=item ARGUMENTS:

    1st Arg    - The ip address of the sbx machine. [ Mandatory ]
    2nd Arg    - root password of the machine. [ Mandatory ]
    3rd Arg    - Reboot Command. Default = 'reboot'.
    4th Arg    - TimeOut for the reboot Command.
    5th Arg    - Time interval to check for the system status, before pinging again.
    6th Arg    - Retries No is the no of retry attempts to be done to check if the
                 system is up after issuing reboot.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::Base::new

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLES:

 1. With only the mandatory arguments,
    my ($hostIp, $rootPwd, $Cmd );
    $hostIp = '10.6.82.44';
    $rootPwd = 'sonus1';
    $Cmd = "reboot";

    unless(SonusQA::SBX5000::SBX5000HELPER::rebootSBX( $hostIp , $rootPwd , $Cmd )){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " rebooting the System with IP $hostIp Failed  ");
    }

 2. With all arguments passed.
    my ($hostIp, $rootPwd, $Cmd, $timeOut, $timeInterval, $noOfRetries);
    $hostIp = '10.6.82.44';
    $rootPwd = 'sonus1';
    $Cmd = "reboot";
    $timeOut = 360;  # in seconds , default = 300
    $timeInterval = 30 ; # default value of 15
    $noOfRetries = 5;  # default value of 5

    unless(SonusQA::SBX5000::SBX5000HELPER::rebootSBX( $hostIp, $rootPwd , $Cmd, $timeOut,
        $timeInterval, $noOfRetries)) {
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
	$logger->error(__PACKAGE__ . " rebooting the System with IP $hostIp Failed ");
    }

=back

=cut

sub rebootSBX {
    my $hostIp = shift;
    my $rootPwd = shift;
    my $rebootCmd = shift;
    my $timeOut = shift;
    my $timeInterval  = shift;
    my $noOfRetries   = shift;

    my $sub_name = 'rebootSBX()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    # Check Mandatory and Optional arguments
    unless ( defined $hostIp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Host IP not passed or empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( defined $rootPwd ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Root Password not passed or empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( defined $rebootCmd ){
        $logger->error(__PACKAGE__ . ".$sub_name: Optional argument Reboot Command set to \'reboot\'");
        $rebootCmd = 'reboot';
    }elsif ($rebootCmd !~ /^reboot/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Reboot Command passed does not start with the keyword \'reboot\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Default Timeout value of 300 secs.
    unless ( defined $timeOut ){
        $timeOut = 300;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Timeout set to \'$timeOut\' seconds.");
    }

    # Default Time interval of 15 seconds between attempts.
    unless ( defined $timeInterval ){
        $timeInterval = 15;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument Time Interval between retries set to \'$timeInterval\' seconds.");
    }

    unless ( defined $noOfRetries ){
        $noOfRetries = 5;
        $logger->debug(__PACKAGE__ . ".$sub_name: Optional argument No. of Retries set to \'$noOfRetries\'.");
    }

    my $rootObj = makeRootSession( -obj_host => $hostIp, -root_password => $rootPwd, -defaulttimeout => 60);

    unless (defined $rootObj){
        $logger->error(__PACKAGE__ . ".$sub_name: SBX Root object creation unsuccessful");
        return 0;
    }
    $logger->error(__PACKAGE__ . ".$sub_name: SBX Root object creation successful");

    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing reboot command : \'$rebootCmd\' ");
    unless ($rootObj->{conn}->cmd(
                                  String =>$rebootCmd ,
                                  Timeout => $timeOut ,
				  )) {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error( ' Reboot Command Issued, but ERROR or Timeout');
        $logger->error( ' Will check if the Node is reachable after reboot ');
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
     }

    #Destroy the root objects created.
    $rootObj->{conn}->close;
    $rootObj->DESTROY;

    # Try to reach the SBX machine after issuing reboot through retry loops.
    my $loop = 1;
    my $rebootFailFlag = 0;
    while ( $loop <= $noOfRetries ) {
        my $cmdFailFlag = 0;
        my $pingSBXOutput = `ping $hostIp -c 1`;
        unless ($pingSBXOutput =~ m/64 bytes from $hostIp/){
            my $sleepTime = $loop * $timeInterval;
            $logger->debug(__PACKAGE__ . ".$sub_name: UNSUCCESSFUL - loop($loop) of pinging, SBX machine is not yet up after Reboot. Sleeping for $sleepTime secs");
            sleep ($sleepTime);
            $logger->debug(__PACKAGE__ . ".$sub_name: UNSUCCESSFUL - loop($loop) of pinging, out of sleep ($sleepTime).");
            $loop++;
            next;
	}
        $rebootFailFlag = 1;
        $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL - loop($loop), SBX machine is up after Reboot.");
        last;
    }

    unless ( $rebootFailFlag) {
        $logger->error(__PACKAGE__ . ".$sub_name: SBX Machine is not up after Reboot");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-SBC reboot failed; ";
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Sleeping for 20 seconds so that all the processes are running after the Reboot.");
    sleep (20);
    return 1;

}

=head2 C< execCliCmdsSBX >

=over

=item DESCRIPTION:

    This is a standalone API which creates a TELNET Object to the host with user as admin
    and executes the CLI commands passed by the user.
    This is class function and can be called from testsuiteList.pl .

=item ARGUMENTS:

    1st Arg    - The ip address of the sbx machine. [ Mandatory ]
    2nd Arg    - admin password of the machine. [ Mandatory ]
    3rd Arg    - The list of CLI commands to be executed. [ Mandatory ]

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::Base::new

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    my ($hostIp, $adminPwd, $cliCommands);
    $hostIp = '10.6.82.44';
    $adminPwd = 'admin';
    $cliCommands = [
        'configure private',  # start a configure private session
        'set system mediaProfile g7xx 50 tone 50',
        'commit',
	'exit',               # come out of configure session after execution of commands.
    ];
    unless(SonusQA::SBX5000::SBX5000HELPER::execCliCmdsSBX( $hostIp , $adminPwd ,$cliCommands)){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " Cannot execute execCliCmdsSBX routine  ");
    }

=back

=cut

sub execCliCmdsSBX    {
    my $hostIp  = shift;
    my $adminPwd = shift;
    my $cmdList = shift;

    my $sub_name = "execCliCmdsSBX";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    # Check Mandatory and Optional arguments
    unless ( defined $hostIp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Host IP not passed or empty.");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( defined $adminPwd ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Admin Password not passed or empty.");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # To check if Command list is passed and is not Empty .
    unless ( defined $cmdList && @{$cmdList } ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Command List not passed or is empty.");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $cmdFailFlag = 0;
    my $errMode = sub {
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
        $logger->error( 'Timeout OR Error for command one of the Commands');
        $logger->warn('  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*');
	$cmdFailFlag = 1;
        return 1;
    };

    my $CliObj = new SonusQA::Base(
                                    -obj_host     => $hostIp,
                                    -obj_user     => 'admin',
                                    -obj_password => $adminPwd,
                                    -comm_type    => 'SSH',
                                    -defaulttimeout => 10,
                                );

    unless (defined $CliObj){
        $logger->error(__PACKAGE__ . ".$sub_name: SBX CLI object creation unsuccessful");
        return 0;
    }
    $logger->error(__PACKAGE__ . ".$sub_name: SBX CLI object creation successful");

    my $cmd;
    # Execute the List of commands Sequentially.
    foreach( @{$cmdList} ) {
        $cmd = $_;
        my @cmdResults = $CliObj->{conn}->cmd(
					      String =>$cmd,
					      Timeout=>$CliObj->{DEFAULTTIMEOUT},
                                              Errmode => $errMode,
                                              );

	foreach ( @cmdResults ) {
            chomp;
	    unless($cmd =~ /^ex/) {
                if ( /^\[error\]/ ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR:-- for CMD $cmd \n CMD RESULT: @cmdResults");
                    $logger->warn(__PACKAGE__ . ".$sub_name:  **ABORT DUE TO CLI FAILURE **");
                    $cmdFailFlag = 1;
		    last;
		}
                elsif ( /^\[ok\]/ ) {
                    last;
		}
	    }else {
                last;
	    }
	}
        if ( $cmdFailFlag ) {
            $logger->error(__PACKAGE__ . ".$sub_name:   cmd \'$cmd\' unsuccessful.");
            last;
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: Executed cmd \'$cmd\' successfully.");
    }

    # Close SSH session & Destory it.
    $logger->debug(__PACKAGE__ . ".$sub_name: Destroying SBX CLI Object created.");
    $CliObj->{conn}->close;
    $CliObj->DESTROY;

    if ( $cmdFailFlag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UN-SUCCESSFUL execution of CLI commands.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFULLY Executed all the CLI Commands.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}
=head2 C< initPSXObject() >

=over

=item DESCRIPTION:

   To collect the GSX logs in ATS when GSX is used as part of testing.
 call the initGSXObject subroutine in the Feature file.

=item Arguments :

   Mandatory :
      GSX Object reference (i.e) $TESTBED{ "gsx:1:ce0" }
      SBC Object reference (i.e) $TESTBED{ "sbx5000:1:ce0" }

   Optional :

      None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

   -$gsxObjRef
   -$sbxObjRef

=item EXTERNAL FUNCTIONS USED:

      None

=item OUTPUT:

      None

=item Example :

   $sbxObj->initGSXObject(-gsxObjRef => $TESTBED{ "gsx:1:ce0" },-sbxObjRef=>$TESTBED{ "sbx5000:1:ce0" });

=back

=cut

sub initGSXObject {
  my ($self, %args) = @_;
   my %a;
   my $sub = "initGSXObject()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    if (exists $a{-gsxObjRef} ) {
        $gsxObjRef = $a{-gsxObjRef};
    }

    if (exists $a{-sbxObjRef} ) {
        $sbxObjRef = $a{-sbxObjRef};
    }
    $logger->debug(__PACKAGE__ . ".$sub: GSX TMS alias : '$gsxObjRef' SBC TMS alias : '$sbxObjRef' ");
}

=head2 C<rollGSXlogs>

=over

=item Description:

     This subroutine is invoked by kick_Off, this shall ROLL logs of GSX instance.
     We shall be executing the ROLLFILE command on GSX terminal.


=item ARGUMENTS:

 Mandatory :

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    $gsxObjRef

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::SonusQA::ATSHELPER::newFromAlias


=item OUTPUT:

    None

=item EXAMPLES:

     $sbxObj->rollGSXlogs;

=back

=cut

sub rollGSXlogs {
    my ($self) = @_;
    my $sub_name = "rollGSXlogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entering sub : GSX = $gsxObjRef");
    my $gsxObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $gsxObjRef);
    my $cmd = "CONFIGURE EVENT LOG ALL ROLLFILE NOW";
    $gsxObj->execCmd($cmd);

    $gsxObj->DESTROY;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
}

=head2 C<getGSXlogs>

=over

=item Description:
     Changes based on the requirement from SONUS00116952
     This Subroutine shall copy the GSX Logs (DBG,SYS & ACT) to the SBX Server location from NFS
     based on the flag "$TESTSUITE->{STORE_LOGS} = 0 or 1" defined in testsuiteList.pl

     made changes to this API so that the logs are never stored in ATS machine, as a FIX for CQ SONUS00127345.
=item ARGUMENTS:

 Mandatory :

	tcid - test case id
        sbxLogLocation - log file location in SBC

 Optional :

	logFlag = to store files under /tmp inside SBC

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    1

=item EXAMPLES:

             unless( $sbcObj->getGSXlogs(-tcid => $tcid, -logFlag => 1, -sbxLogLocation => $copyLocation )) {
                $logger->error(__PACKAGE__ . " $sub_name:   Could not Copy GSX Logs Successfully");
                return 0;
            }

=back

=cut

sub getGSXlogs {
     my ($self,%args) = @_;
     my ($logger,%gsxLogDetails,$dbgLogFile,$sysLogFile,$actLogFile,$home_dir,$a,$file);
     my $sub_name = "getGSXlogs";
          $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

     my $gsxObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $gsxObjRef);
     my $sbxObj = $self;

     my $nfsIp = $gsxObj->{TMS_ALIAS_DATA}->{NFS}->{1}->{IP};
     my $nfsPwd = $gsxObj->{TMS_ALIAS_DATA}->{NFS}->{1}->{PASSWD};
     my $nfsUser = $gsxObj->{TMS_ALIAS_DATA}->{NFS}->{1}->{USERID};

     my $sbxIp = $sbxObj->{OBJ_HOST};
     my $sbxPwd = 'sonus';
     my @logFiles;

     $dbgLogFile = $gsxObj->getCurLogPath("DBG");
     push (@logFiles, $dbgLogFile) unless ($dbgLogFile == 1);  # If the return value is 1, then skip the logfile, CQ - SONUS00137197

     $sysLogFile = $gsxObj->getCurLogPath("SYS");
     push (@logFiles, $sysLogFile) unless ($sysLogFile == 1);

     $actLogFile = $gsxObj->getCurLogPath("ACT");
     push (@logFiles, $actLogFile) unless ($actLogFile == 1);

     my $localcopy = 0;
     if ( $dbgLogFile =~ /sonus\/SonusNFS\//i or $sysLogFile =~ /sonus\/SonusNFS\//i or $actLogFile =~ /sonus\/SonusNFS\//i ) {
          $localcopy = 1;
	  $logger->info(__PACKAGE__ . ".$sub_name: NFS is mounted to the server, So copying the logs locally");
     }

     my $ce = $sbxObj->{ACTIVE_CE};
     foreach my $log (@logFiles) {
          if ( $log =~ /dbg/i ) {
               ($a,$file) = split(/\/DBG\//,$log);
          } elsif ( $log =~ /sys/i ) {
               ($a,$file) = split(/\/SYS\//,$log);
          } elsif ( $log =~ /act/i ) {
               ($a,$file) = split(/\/ACT\//,$log);
          }

          my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
          my $locallogname = $main::log_dir."/".$datestamp."_".$args{-tcid}."_GSX_".$file;
          my $logFileName = $datestamp."_".$args{-tcid}."_GSX_".$file;
          my $sbxLogLocation = "$args{-sbxLogLocation}/logs";

	  unless ( $localcopy ) {
	       my %scpArgs;
               $scpArgs{-hostip} = $nfsIp;
               $scpArgs{-hostuser} = $nfsUser;
               $scpArgs{-hostpasswd} = $nfsPwd;
               $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$log;
               $scpArgs{-destinationFilePath} = $locallogname;
               if(&SonusQA::Base::secureCopy(%scpArgs)){
		 $logger->info(__PACKAGE__ . ".$sub_name: Log file $log copied to $locallogname");
	       }
          }else{
	       my $status = `cp $log $locallogname`;
          }

          $logger->info(__PACKAGE__ . ".$sub_name: LOG FILE $file COPIED TO: $locallogname");

          if ($args{-logFlag}) {

	       my %scpArgs;
               $scpArgs{-hostip} = $sbxIp;
               $scpArgs{-hostuser} = 'linuxadmin';
               $scpArgs{-hostpasswd} = $sbxPwd;
	       $scpArgs{-scpPort} = '2024';
               $scpArgs{-sourceFilePath} = $locallogname;
               $scpArgs{-destinationFilePath} = "/tmp/";
	       if(&SonusQA::Base::secureCopy(%scpArgs)){
                 $logger->info(__PACKAGE__ . ".$sub_name: Log file $locallogname copied to $scpArgs{-hostip}");
               }else{
		 $logger->info(__PACKAGE__ . ".$sub_name: Failed to copy Log file $locallogname to $scpArgs{-hostip}");
               }
               unless ($sbxObj->{$ce}->{conn}->cmd("cp /tmp/$logFileName $sbxLogLocation")) {
                   $logger->error(__PACKAGE__ . ".$sub_name: failed to copy the log from /tmp/ to $sbxLogLocation");
               } else {
                   $logger->info(__PACKAGE__ . ".$sub_name: LOG FILE $file COPIED TO SBX LOCATION: $sbxLogLocation/$logFileName");
               }
          }

          $logger->info(__PACKAGE__ . ".$sub_name: TESTSUITE->{STORE_GSXLOGS_IN_SBX}---> $main::TESTSUITE->{STORE_GSXLOGS_IN_SBX}");
	  unless ( $main::TESTSUITE->{STORE_GSXLOGS_IN_SBX} == 2 ) {       # Introduced to store the logfile in ATS location if the value is 2, CQ - SONUS00137196
              `rm $locallogname`;
              $logger->info(__PACKAGE__ . ".$sub_name: Log file $locallogname removed after copying to ATS.");
	  } else {
	      $logger->info(__PACKAGE__ . ".$sub_name: Log file $locallogname copied to ATS location");
	  }
     }

     $gsxObj->DESTROY;

     return 1;
}


=head2 C< getDecodeRawMessage() >

=over

=item DESCRIPTION:

    provides the Decoded result by runing the decodeTool for given parameter.

    Note - Before calling this API make sure prompt is an shell, if not call "enterLinuxShellViaDsh($root_user,$root_pass)" API to get it to Linuxshell.

=item Arguments :

   Mandatory :
      -sbxLogFile   => "DBG"       can be DBG  or TRC
                      "1000009.DBG,1000009.DBG_hold_reterive_remote_side"       two files passing for comparision, must be separated by ','

					OR
	  -sbxRawData	=> "'01 11 48 00 0a 03 02 0a 08 83 90 89 04 04 00 00 0f 0a 07 03 13 99 54 0"

          -sbxVariant  => "itu"       protocol variant  can be japan,ansi,china,itu,bt etc
					OR
	  -sbxConfigFile=> "Config.txt"  Configuration file(standard text file), pass the path of file excluding the homedirectory

				(configuration file (standard text file) that contains all/combinations of the following: NOTE: The Control Text are the same commands as the GSX CLI.
				PROTOCOL:- <Control Text>
				DEFAULT_PROFILE:- <Control Text>
				REVISION:-  <Control Text>
				Note: If Controls are specified then the text file must be formatted with either SUPPORTED or UNSUPPORTED prefixing the control name:

				CONTROL:- -SUPPORTED- <Control Text>
					Or
				CONTROL:- -UNSUPPORTED- <Control Text> )

	  -sbxString  => "String to be matched in decoded output"

                                should be passed in follwing foramt

                                          '-sbxString' => { 'TYPE1' =>{
                                                                        'SENT' 		=> ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                        'RECEIVED'	=> ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                      },
                                                            'TYPE2' =>{
                                                                        'SENT'          => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                        'RECEIVED'      => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                      },
                                                            'TYPEN' =>{
                                                                        'SENT'          => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                        'RECEIVED'      => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                      },
                                                          },

          -sbxString  => "String to be matched in decoded output"

                                should be passed in follwing foramt

                                          '-sbxString' => { 'TYPE1' =>{
                                                                        'SENT'          => { 'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                                               'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN']},
                                                                        'RECEIVED'      => { 'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                                              'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN']},
                                                                      },
                                                            'TYPEN' =>{
                                                                        'SENT'          => { 'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                                             'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN']},
                                                                        'RECEIVED'      => { 'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN'],
                                                                                              'pameter code1' => ['search string1-val1','search string2-val2',..........,'search stringN-valN']},
                                                                      },
                                                          },

   Optional  :
      -sbxNoRoute   => "1"       no route option can only be used with the no Logfile

=item Return Values :

   0 - Failed
   1 - Success

=item Example :
   my %params = (   -sbxLogFile  => 'DBG',
                   -sbxString    => { 'IAM' => {
						'SENT' 		=> ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
 						'RECEIVED' 	=> ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
					       },
                                      'ACM' => {
						'SENT'		=> ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
						'RECEIVED'	=> ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
					       },
                                      'ANM' => {
						'SENT'		=> ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
					       },
                                    },
                   -sbxVariant   => 'itu',
   );

   $SBXObject->getDecodeRawMessage(%params);

                                                   or

   my %params = (   -sbxLogFile  => 'DBG',
                   -sbxString    => { 'IAM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},
                                               },
                                      'ACM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},},
                                               }
                                    },
                   -sbxVariant   => 'itu',
   );

   $SBXObject->getDecodeRawMessage(%params);


 Example for Raw Data:
   my %params = (   -sbxLogFile  => '01 11 48 00 0a 03 02 0a 08 83 90 89 04 04 00 00 0f 0a 07 03 13 99 54 04 00 00 1d 03 90 90 a3 31 02 00 18 c0 08 06 03 10 99 54 04 00 00 39 04 31 90 c0 84 00',
		    -sbxString    => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
		    -sbxVariant   => 'itu',
                    -sbxNoRoute    => 1
		)

   $SBXObject->getDecodeRawMessage(%params);
=item Author :

 Enhanced by Ramesh Pateel (rpateel@sonusnet.com)

=back

=cut

sub getDecodeRawMessage {
     my ($self) = shift;
     my $flag = 1;
     my $sub_name = "getDecodeRawmessage";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
     if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_],
                        'check_anyone' => 1 #TOOLS-12485
                );
        my $retVal = $self->__dsbcCallback(\&getDecodeRawMessage, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
     }
     my (%args) = @_;
     foreach(keys %args){
         $args{-$1} = delete $args{$_} if(/sbx(.+)/);
     }
     $args{-DecodeTool} = $self->{DECODETOOL};
     $self = $self->{$self->{ACTIVE_CE}};
     my $cmd = 'cd /var/log/sonus/sbx/evlog';
     my ($res, @result) = _execShellCmd($self, $cmd);
     unless ($res) {
         $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n".Dumper(\@result));
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
     }
     if ($args{-LogFile}) {
          unless($args{-LogFile} =~ /\,/) {
               # take the latest log file
              my $list_cmd = "ls -tr \*\.$args{-LogFile} \| grep -v decoded \| tail \-1";
	      ($res, @result) = _execShellCmd($self, $list_cmd);
              unless ($res) {
                  $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$list_cmd --\n".Dumper(\@result));
                  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                  return 0;
              }
              my $log_file = $result[1];
              $log_file =~ s/\s//g;
	      $args{-LogFile} = $log_file;
          }
     }

     unless($self->verifyDecodeMessage(%args)){
          $logger->error(__PACKAGE__ . ".$sub_name: Failed to verify the decode message");
          $flag = 0;
     }
     unless ( my ($res) = _execShellCmd($self, "cd")) {
         $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:\'cd\' to get into home directory");
         $flag = 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
     return $flag;
}

=head2 C< pingMachine() >

=over

=item DESCRIPTION:

	This subroutine will check the ip type and execute ping/ping6 to check the reachability of SBC ip

=item ARGUMENTS:

 Mandatory :

    1st Arg    - The ip address of the sbx machine. [ Mandatory ]

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::enterLinuxShellViaDshBecomeRoot

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    my $sbc_ip = '10.54.51.71';
    unless ($sbx_object->pingMachine($sbc_ip)) {
        $logger->debug(__PACKAGE__ . ".$sub : pingMachine of $sbc_ip Failed");
        return 0;
    }

=back

=cut

sub pingMachine {
    my ($self, $remoteIP) = @_;
    my $sub_name = "pingMachine()";

    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $IP);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    @cmdResults = ();
    unless ( defined ($remoteIP) ) {
        $logger->warn(__PACKAGE__ . ".$sub_name: IP MISSING");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    if ($remoteIP =~ /\d+\.\d+\.\d+\.\d+$/i) {
        $cmd = sprintf("ping -c 4 %s ", $remoteIP);
    }else{
        $cmd = sprintf("ping6 -c 4 %s ", $remoteIP);
    }

    unless ( $self->enterLinuxShellViaDshBecomeRoot ("sonus", "sonus1" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
	$logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    @cmdResults =  $self->execCmd($cmd);

    my $trueFlag = 0;
    foreach(@cmdResults) {
	if ($_ =~ /0\% packet loss/i) {
	    $trueFlag = 1;
	    last;
	}
    }

    unless ($self->leaveDshLinuxShell) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to get out of dsh linux shell.");
        return 0;
    }

    if ($trueFlag) {
        $logger->info(__PACKAGE__ . ".$sub_name: Ping Successful, Host($remoteIP) reachable!");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
	return 1;
    }

    $logger->info(__PACKAGE__ . ".$sub_name Pinging the Host($remoteIP) unsuccessful");
    $logger->info(__PACKAGE__ . ".$sub_name Leaving Sub[0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Ping Unsuccessful; ";
    return 0;

}

=head2 C< handleConfigureCmd >

=over

=item DESCRIPTION:

    This subroutine executes the command string provided

=item ARGUMENTS:

    -cmdString       => The command to be executed

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::enterPrivateSession
    SonusQA::SBX5000::execCommitCliCmd
    SonusQA::SBX5000::leaveConfigureSession

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sbx_object->handleConfigureCmd(-cmdString         => $cmdString)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing config command");
        return 0;
    }

=back

=cut

sub handleConfigureCmd {
   my ($self, %args) = @_;
   my %a;
   my $sub = "handleConfigureCmd()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   unless ( $self->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode--\n @{$self->{CMDRESULTS}}" );
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub cmdString : $a{-cmdString}");

   my $retCode = 1;

   # Execute the CLI
   unless($self->execCommitCliCmdConfirm($a{-cmdString})) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      $retCode = 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

   unless ( $self->leaveConfigureSession() ) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to leave private session--\n @{$self->{CMDRESULTS}}" );
      $retCode = 0;
   }
   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$retCode]");

   #  Return status
   return $retCode;
}


=head2 C< execCommitCliCmdConfirm >

=over

=item DESCRIPTION:

    This subroutine executes the command and if commit requires the confirmation, gives the required input

=item ARGUMENTS:

    Cli Commands

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::configureSigPortAndDNS
    SonusQA::SBX5000::execCmd


=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sbx_object->execCommitCliCmdConfirm(@commands)) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to execute the commands");
        return 0;
    }

=back

=cut

sub execCommitCliCmdConfirm {
   my ($self, @cli_command ) = @_ ;
   my $sub_name = "execCommitCliCmdConfirm" ;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

   unless ( @cli_command ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  No CLI command specified." );
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
   }

   # Assumption: We are already in a configure session
   my $retVal = 1;
   foreach ( @cli_command ) {
     if ($self->{D_SBC}) {
	$self->{CMDRESULTS} = []; #d-sbc CMDRESULTS
        my @dsbc_arr = $self->dsbcCmdLookUp($_);
        my @role_arr = $self->nkRoleLookUp($_) if($self->{NK_REDUNDANCY});
        my %hash = (
                        'args' => [$_],
                        'types'=> [@dsbc_arr],
                        'roles'=> [@role_arr]
                );
	last unless ($retVal = $self->__dsbcCallback(\&execCommitCliCmdConfirm, \%hash));
        #Configuring D_SBC Sig port and DNS for different personalities of SBC
        if ( $_ =~ /set\saddressContext.+ipInterfaceGroup.+ipInterface.+ceName.*portName\spkt0/i and ! $self->{CMD_INFO}->{DSBC_CONFIG}){ #TOOLS-17487
            unless ($self->configureSigPortAndDNS($_)) {
                $logger->error(__PACKAGE__ . ".$sub_name: D_SBC Signaling Port configuration failed.");
                $retVal = 0;
                last;
            }
        }
	next;
     }

      chomp();
      unless ( $self->execCliCmd ( $_ ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot execute command $_:\n@{ $self->{CMDRESULTS} }" );
	 $retVal = 0;
         last;
      }

      $self->{CMDRESULTS} = ();

      # Issue commit and wait for either [ok], [error], or [yes,no]
      unless ( $self->{conn}->print( "commit" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'commit\'");
	 $retVal = 0;
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         last;
      }
      $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'commit\'");

      my ($prematch, $match);

      unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                             -match     => '/yes[\/\.,]no/',
                                                             -match     => '/\[ok\]/',
                                                             -match     => '/\[error\]/',
                                                             -match     => $self->{PROMPT},
                                                             -timeout   => $self->{DEFAULTTIMEOUT},
                                                           )) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'commit\'.");
         push( @{$self->{CMDRESULTS}}, $prematch );
         push( @{$self->{CMDRESULTS}}, $match );
	 $retVal = 0;
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         last;
      }

      push( @{$self->{CMDRESULTS}}, $prematch );
      push( @{$self->{CMDRESULTS}}, $match );
      if (( $match =~ m/yes[\/\.,]no/ ) ){
         $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes,no prompt for discarding changes");

         # Enter "yes"
         $self->{conn}->print( "yes" );

         unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                                -match => $self->{PROMPT},
                                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'");
	    $retVal = 0;
	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
 	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            last;
         }

         if ( $prematch =~ m/\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  \'Yes\' resulted in error\n$prematch\n$match");
	    $retVal = 0;
            last;
         } elsif ( $prematch =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Command Executed with yes");
         } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'\n$prematch\n$match");
	    $retVal = 0;
            last;
         }
      } elsif ( $match =~ m/\[ok\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  command commited.");
         # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );
      } elsif ( $match =~ m/\[error\]/ ) {
	    $logger->debug(__PACKAGE__ . ".$sub_name:  \'commit\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking if ATS can resolve this");
            unless ($self->resolveCommitError($_, [$prematch])) {
                $logger->debug(__PACKAGE__ . ".$sub_name: ATS is not able to resolve the error");
                # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
                # next call to execCmd
                $self->{conn}->waitfor( -match => $self->{PROMPT} );
                $retVal = 0;
                last;
            }
	} else {
	    $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
            $retVal = 0;
            last;
	}
      $logger->debug(__PACKAGE__ . ".$sub_name:  Committed command: $_");
      $self->{LASTCMD} = $_;
    }
    push( @{$self->{PARENT}->{CMDRESULTS}}, @{$self->{CMDRESULTS}} ) if(exists $self->{PARENT});
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
    return $retVal;
}


=head2 C< execRevertCliCmdConfirm >

=over

=item DESCRIPTION:

    This subroutine executes the command "revert" and performs the revert with proper error handling. A simple execCliCmd("revert") will not provide second level input or do the error handling necessary  for this particular command. This subroutine does them.

=item ARGUMENT:

    Cli Commands

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:
 1.
    unless ($sbx_object->execRevertCliCmdConfirm()) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to revert the changes");
        return 0;
    }
 2.
   unless ($sbx_object->execRevertCliCmdConfirm) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to revert the changes");
        return 0;
    }

=back

=cut

sub execRevertCliCmdConfirm {
   my ($self) = @_ ;
   my $sub_name = "execRevertCliCmdConfirm" ;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
   if ($self->{D_SBC}) {
        my $retVal = $self->__dsbcCallback(\&execRevertCliCmdConfirm);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

    #TOOLS-15088 - to reconnect to standby before executing command
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer"); #TOOLS-8398
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command #TOOLS-8398

      $self->{CMDRESULTS} = ();

      # Issue revert and wait for either [ok], [error]
      unless ( $self->{conn}->print( "revert no-confirm" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'revert no-confirm\'");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'revert no-confirm\'");

      my ($prematch, $match);

      unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                             -match     => '/\[ok\]/',
                                                             -match     => '/\[error\]/',
                                                             -match     => $self->{PROMPT},
                                                             -timeout   => $self->{DEFAULTTIMEOUT},
                                                           )) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'revert no-confirm\'.");
         push( @{$self->{CMDRESULTS}}, $prematch );
         push( @{$self->{CMDRESULTS}}, $match );
 	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }

      push( @{$self->{CMDRESULTS}}, $prematch );
      push( @{$self->{CMDRESULTS}}, $match );
      if ( $match =~ m/\[ok\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  Revert complete.");
         # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );;
      } elsif ( $match =~ m/\[error\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  \'revert\' command error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
         # next call to execCmd
         $self->{conn}->waitfor( -match => $self->{PROMPT} );
         return 0;
      } else {
         $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
         return 0;
      }
      $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully reverted the changes.");
      $self->{LASTCMD} = $_;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 C< execCommitCliCmd >

=over

=item DESCRIPTION:

    This subroutine executes the command followed by a commmit

=item ARGUMENTS:

    Cli Commands

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sbx_object->execCommitCliCmd(@commands)) {
        $logger->debug(__PACKAGE__ . ".$sub : Unable to execute the commands");
        return 0;
    }

=back

=cut

sub execCommitCliCmd {
    my  ($self, @cli_command ) = @_ ;
    my  $sub_name = "execCommitCliCmd" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( @cli_command ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  No CLI command specified." );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    # Assumption: We are already in a configure session

    foreach ( @cli_command ) {
        chomp();
        unless ( $self->execCliCmd ( $_ ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot execute command $_:\n@{ $self->{CMDRESULTS} }" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        unless ( $self->execCliCmd ( "commit" ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot commit command $_:\n@{ $self->{CMDRESULTS} }" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            # Set LASTCMD back to the original command, else it will always leave here being 'commit'
            $self->{LASTCMD} = $_;
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Committed command: $_");
        $self->{LASTCMD} = $_;
        #TOOLS-74775 Reconnecting after configuring sesssionIdleTimeout.
        if(/set system admin .+ accountManagement sessionIdleTimeout idleTimeout .+/){            
            $logger->debug(__PACKAGE__. ".$sub_name: Reconnecting.");
            unless($self->reconnect()){
                $logger->error(__PACKAGE__. ".$sub_name Failed to reconnect to admin session. Please check the SBC status.");
                $logger->debug(__PACKAGE__. ".$sub_name <-- Leaving Sub [0]");
                return 0;
            }
            unless ($self->enterPrivateSession()) {
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Error entering private session.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }            
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< enterPrivateSession >

=over

=item DESCRIPTION:

    This subroutine enters configure private mode

=item ARGUMENTS:

    Cli Commands

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   unless ( $sbx_object->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode" );
      return 0;
   }

=back

=cut

sub enterPrivateSession {
    my ($self) = shift;
    my  $sub_name = "enterPrivateSession" ;
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&enterPrivateSession, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my ( %args ) = @_ ;
    my ($attempt) = 0;

    #TOOLS-15088 - to reconnect to standby before executing command
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    RERUN:
    $self->{conn}->buffer_empty;
    unless ( $self->{conn}->print( "configure private no-confirm" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'configure private no-confirm\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'configure private no-confirm\'");
    # Enter private session

    my ($prematch, $match);
    my @avoid_us = ('Stopping user sessions during sync phase\!','Disabling updates \-\- read only access','Enabling updates \-\- read\/write access');
    my $pattern = '(' . join('|',@avoid_us) . ')';


    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        if( grep /IDLE TIMEOUT/i, ${$self->{conn}->buffer}){
            $logger->warn(__PACKAGE__ . ".$sub_name:  There was a session idle timeout. ".${$self->{conn}->buffer});
            $logger->info(__PACKAGE__ . ".$sub_name:  Reconnecting to the SBC.. ");
            unless ($self->makeReconnection()) {
                $logger->error(__PACKAGE__ . ".$sub_name: unable to reconnect");
                &error("Unable to reconnect after trying to reconnect due to session idle timeout");
            } else {
                unless ( $self->{conn}->print( "configure private no-confirm" ) ) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'configure private no-confirm\' after reconnection");
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'configure private no-confirm\' after reconnection");
                unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
                    $logger->error(__PACKAGE__ . ".$sub_name: After reconnection : Could not match expected prompt after \'configure private no-confirm\'.");
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
                    return 0;
                }
            }
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'configure private no-confirm\'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
            return 0;
	}
    }
    if ( $match =~ m/\[ok\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  \'configure private no-confirm\' command success. Checking for private session.");
         $self->{conn}->waitfor( -match => $self->{PROMPT} );;
    }
    elsif ( $match =~ m/\[error\]/ ) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  \'configure private no-confirm\' command error:\n$prematch\n$match");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
         return 0;
    }
    elsif ( ($prematch =~ /$pattern/ or $match =~ /$pattern/) and $attempt <= 4 ){
 	 $logger->debug(__PACKAGE__ . ".$sub_name: Rerunning the command as we got an unwanted message. Prematch: '$prematch' Match : '$match' Retry attempt : '$attempt'");
	 $attempt++;
 	 goto RERUN;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
        return 0;
    }


    # Are we already in a session?
    unless ( $self->execCliCmd( "status" ) ) {
         # This should work if we're in a config session already.
         # If this fails, we're off the reservation
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot enter private configure session" );
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Login Failed; ";
         return 0;
     }

    $logger->info(__PACKAGE__ . ".$sub_name: --> Setting private mode flag value to 1");
    $self->{PRIVATE_MODE} = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< getRecentLogViaCli >

=over

=item DESCRIPTION:

    This subroutine finds and returns the current logs by parsing the output of the CLI Command (show table oam eventLog typeStatus).

=item ARGUMENTS:

    Mandatory:
    - log_type  (log type for which the current file has to be returned).
      ['DBG','SYS','TRC','ACT','SEC','AUD','PKT']

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    current logfilename  - if Success.
	0		 - if failure.

=item EXAMPLE:

   unless ( $sbx_object->getRecentLogViaCli('DBG')) {                   -------------> ['DBG','SYS','TRC','ACT','SEC','AUD','PKT'] pass any one of these logs.
      $logger->error(__PACKAGE__ . ".$sub:  Unable to get the current logfile" );
      return 0;
   }

=back

=cut

sub getRecentLogViaCli {
    my ( $self, $log_type ) = @_ ;

    my $sub_name = "getRecentLogViaCli";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    #checking if D_SBC,
    #execute only for S_SBC as it will contain each type of logs
    #to get the logs for different personality of SBC, the subroutine will be called using appropriate object
 if ($self->{D_SBC}) {
         my $sbc_type = (exists $self->{S_SBC}) ? 'S_SBC' : 'I_SBC';
         my $index ;
         foreach (keys %{$self->{$sbc_type}}){
             $index = $_ ;
             my $role = $self->{$sbc_type}->{$index}->{'REDUNDANCY_ROLE'};
             last if ($role =~ /ACTIVE/ );
         }
         $self = $self->{$sbc_type}->{$index};
         $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type->$index)");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the latest $log_type log files.");

    my @cmdresults;
    my $cmd = "show table oam eventLog typeStatus";

    unless ( @cmdresults = $self->execCmd($cmd) ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Failed issuing Cli: $cmd");
	$logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to get RecentLog; ";
	return 0;
    }

    foreach (@cmdresults) {
        if ($_ =~ /(\w+\.$log_type(\.OPEN)?)/) {
            $logger->info(__PACKAGE__ . ".$sub_name: current $log_type log  : $1");
            $logger->info(__PACKAGE__ . ".$sub_name: Leaving sub[$1]");
	        return $1;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Didn't match the required log file");
    chomp @cmdresults;
    $logger->info(__PACKAGE__ . ".$sub_name: Command output : ". Dumper(\@cmdresults));
    
    $logger->info(__PACKAGE__ . ".$sub_name: Leaving sub[0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to get RecentLog; ";
    return 0;
}

=head2 C< makeRootSession >

=over

=item DESCRIPTION:

    This method will provide a root connection to SBX, Initaily login as linuxadmin and them becomes the root

=item ARGUMENTS:

    Manditory -
        -obj_host => SBX ip address

    Optional -
        -obj_password   => linuxadmin password, default is sonus
        -root_password  => root user password, default is sonus1
        -defaulttimeout => time out for any command execution, default is 60
        -obj_port       => Port, default is 2024
        -comm_type      => Connection Type, default is ssh
        -tshark         => 1 ( To make TSHARK Obj )

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        root object      - if success
	0		 - if failure.

=item EXAMPLE:

   unless ($obj = SonusQA::SBX5000::SBX5000HELPER::makeRootSession( -obj_host => '10.54.6.164',  -obj_password => 'sonus', -sessionlog => 1, -root_password => sonus1)) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to make root connection" );
      return 0;
   }

=back

=cut

sub makeRootSession {
    my ( %args ) = @_;

    my $sub = 'makeRootSession';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my %a = ( -comm_type => 'SSH', -obj_port => 2024, -defaulttimeout => 60, -obj_password => 'sonus', -root_password => 'sonus1');

    map {$a{$_} = $args{$_}} keys %args;
    logSubInfo ( -pkg => __PACKAGE__, -sub => $sub, %a );

    unless ($a{-obj_host}) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument \'$_\' missing or empty");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $a{-obj_user} ||= 'linuxadmin';
    $a{-sessionlog} = 1;

    if (exists $SSH_KEYS{$a{-obj_host}} and $SSH_KEYS{$a{-obj_host}}{$a{-obj_user}} and !$a{-obj_key_file}) {
       $logger->debug(__PACKAGE__ . ".$sub: ssh key is present for this ip");
       $a{-obj_key_file} = $SSH_KEYS{$a{-obj_host}}{$a{-obj_user}};
    }

    my $Obj;
    if ( $a{-tshark} ) {
        require SonusQA::TSHARK;
        $Obj = new SonusQA::TSHARK(%a);
    } else {
        require SonusQA::Base;
        $Obj = new SonusQA::Base(%a);
    }

    unless ($Obj) {
        $logger->error(__PACKAGE__ . ".$sub: Login failed to ip -> \'$a{-obj_host}\' as \'$a{-obj_user}/$a{-obj_password}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
        return 0;
    }
    $Obj->{INSTALLED_ROLE} = 0;
    #TOOLS-19937 start
    if($args{-obj}){
      if(SonusQA::Utils::greaterThanVersion($args{-obj}->{APPLICATION_VERSION},'V07.02.00')){
        $Obj->{SBC_VERSION} = $args{-obj}->{APPLICATION_VERSION};
        $logger->debug(__PACKAGE__ . ".$sub: Checking version and type");
        my ($status,@result) = _execShellCmd($Obj,"sbcDiagnostic 0");
        if($status){
          foreach (@result){
            if ($_ =~/SBC\s+Product\s+Name:\s+(\S+)/){
              $args{-obj}->{CLOUD_PLATFORM} = ($1 =~ /(GCE|GCP)/)?"Google Compute Engine":$1;
            }
            elsif ($_ =~/\s+Service\srunning\s\[(\S+)\]/){  #TOOLS-20820
              $Obj->{INSTALLED_ROLE} =$1;
              last;
            }
          }
          $logger->info(__PACKAGE__.".$sub: $ ,$args{-obj}->{CLOUD_PLATFORM}");
          $logger->debug(__PACKAGE__ . ".$sub: SBC equal to or greater than version V07.02.00");
          if ($args{-obj}->{CLOUD_PLATFORM} eq 'AWS' or $args{-obj}->{CLOUD_PLATFORM} eq 'Google Compute Engine'){
            #TOOLS-71255-we are running sbcDiagnostic 1 to get userData.json
	    ($status,@result) = _execShellCmd($Obj,"sbcDiagnostic 1");
	    unless($status){
	  	$logger->error(__PACKAGE__."$sub: failed to execute sbcDiagnostic 1");
		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
		return 0;
	    } 
            if($args{-obj}->{SKIP_ROOT}){  #TOOLS-20820
                $logger->info(__PACKAGE__ .".$sub:Skipping license installation as skip_root is set");
            }
            elsif($args{-obj}->{AWS_LICENSE}){
              $logger->info(__PACKAGE__."$sub: License is already installed");
            }
            else{
              $args{-obj}->{AWS_LICENSE} = 1;
              unless($args{-obj}->licenseCheck(-requiredlicenses => ['SWE-INSTANCE'])){
                $logger->debug(__PACKAGE__ . ".$sub: License not installed on SBC. Installing license.");
                unless($args{-obj}->generateLicense(-skip_cleanstart=>1)){
                  $logger->error(__PACKAGE__ . ".$sub: License installation failed");
                  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                  return 0;
                }
              }
            }  
          }
        }
      }
    }
    #TOOLS-19937 end

    unless (SonusQA::SBX5000::SBX5000HELPER::becomeRoot($Obj, $a{-root_password})) {
        $logger->error(__PACKAGE__ . ".$sub: unable to enter as root");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }


# Fix for TOOLS-3979
# Set TMOUT value to 0 in autologout.sh. So that it won't log out on inactivity
# Its a new security feature (SBX-36495)
    my @cmd_out = $Obj->{conn}->cmd('echo $TMOUT');
    chomp @cmd_out;
    $logger->debug(__PACKAGE__ . ".$sub:  : TMOUT : $cmd_out[0]");

    if($cmd_out[0]){ # update TMOUT value only if its not 0
        $logger->debug(__PACKAGE__ . ".$sub:  : Updating TMOUT value to 0");
        unless (@cmd_out = $Obj->{conn}->cmd("sed -i '/^TMOUT=/cTMOUT=0' /etc/profile.d/autologout.sh")) {
            $logger->error(__PACKAGE__ . ".$sub: failed to execute \'sed -i '/^TMOUT=/cTMOUT=0' /etc/profile.d/autologout.sh\'");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $Obj->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
            return 0;
        }

        if(grep {/\S+/} @cmd_out){
            $logger->debug(__PACKAGE__ . ".$sub: Can't set autologout value to 0. output: ". Dumper(\@cmd_out));
        }
        else{
            $logger->debug(__PACKAGE__ . ".$sub: autologout value has set to 0. So it won't log out on inactivity now.");
            $logger->debug(__PACKAGE__ . ".$sub: Exiting from root and log in again to get new TMOUT value");
            for(1..2){
		$Obj->{conn}->cmd(String => 'exit', Prompt => $Obj->{DEFAULTPROMPT}); # to exit bash
	    } # to exit root session
            unless (SonusQA::SBX5000::SBX5000HELPER::becomeRoot($Obj, $a{-root_password})) {
                $logger->error(__PACKAGE__ . ".$sub: unable to enter as root");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
        }
    }
    $Obj->{conn}->cmd('echo $TERM');
    $Obj->{conn}->cmd('export TERM=xterm');
    $Obj->{conn}->cmd('echo $TERM');

    my @swinfo;
    unless($Obj->{INSTALLED_ROLE}){
        unless (@swinfo = $Obj->{conn}->cmd('swinfo -v')) {
            $logger->error(__PACKAGE__ . ".$sub: failed to execute \'swinfo\'");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $Obj->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }

        foreach (@swinfo) {
            chomp $_;
            if ($_ =~ /Build Workspace:\s+(\S+)/i){         #TOOLS-72075
                $args{-obj}->{ASAN_BUILD} = 1 if ($1 =~ /asan/i);
                last;
            }            
            
            if ($_ =~ /SBC\:\s*(\S+)/i){
                $Obj->{SBC_VERSION} = $1;
            }elsif ($_ =~ /Installed host role\:\s*(\S+)/i){
                my $role = $1;
                $Obj->{INSTALLED_ROLE} = 'active' if ($role =~ /active/i);
                $Obj->{INSTALLED_ROLE} = 'standby' if ($role =~ /standby/i);
            }
            elsif($_ =~/SBC Type\:\s*(\S+)/){
                my $type =$1;
                $args{-obj}->{TYPE}=$type;
            }
        }
    }

#TOOLS-18508 - Introducing -do_not_touch_sshd flag to skip the /etc/ssh/sshd_config file modifications.
    unless($a{-do_not_touch_sshd}){
        #enable ssh for root
        my @result;
        $logger->debug(__PACKAGE__ . ".$sub: Check if ssh is enabled for root");

        my $grep_cmd = 'grep "AllowUsers.*root\|PermitRootLogin yesi\|#ClientAliveInterval" /etc/ssh/sshd_config';#TOOLS-16162

        unless(@result = $Obj->{conn}->cmd($grep_cmd)){
            $logger->error(__PACKAGE__.".$sub: Failed to run '$grep_cmd' command");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $Obj->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub: Result of \'$grep_cmd\' cmd: ".Dumper(\@result));

        my $ssh_restart = 0;
        #If 'AllowUsers.*root' is not matched then it will add 'root' to 'AllowUsers'
        unless ( grep /AllowUsers.*root/ , @result){
            $logger->debug(__PACKAGE__ . ".$sub: Enabling ssh for root");
            $Obj->{conn}->cmd("sed -i -e 's/AllowUsers/AllowUsers root/g' /etc/ssh/sshd_config"); 
            $ssh_restart = 1;
        }

        #TOOLS-16162
        unless ( grep /PermitRootLogin yes/, @result){
            $logger->debug(__PACKAGE__ . ".$sub: Adding PermitRootLogin yes");
            $Obj->{conn}->cmd("sed -i -e 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config");
            $ssh_restart = 1;
        }

        #TOOLS-75401
        unless ( grep /#ClientAliveInterval/, @result){
            $logger->debug(__PACKAGE__ . ".$sub: commenting out ClientAliveInterval ");
            $Obj->{conn}->cmd("sed -i -e 's/ClientAliveInterval/#ClientAliveInterval/' /etc/ssh/sshd_config");
            $ssh_restart = 1;
        }

         $Obj->{conn}->cmd("service ssh restart") if($ssh_restart);
    }else{
	$logger->debug(__PACKAGE__ . ".$sub: do_not_touch_sshd flag is set ");
    }
    unless ($Obj->{INSTALLED_ROLE}) {
         $logger->error(__PACKAGE__ . ".$sub: failed to get \'INSTALLED_ROLE\' role for \'$a{-obj_host}\'");
    } else {
         $logger->info(__PACKAGE__ . ".$sub: installed role for \'$a{-obj_host}\' is $Obj->{INSTALLED_ROLE}");
    }

    return $Obj;
}

=head2 C< becomeRoot >

=over

=item DESCRIPTION:

    This method will login as root for passed linux session

=item ARGUMENTS:

    Optional -
        -root_password  => root user password, default is sonus1

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        1      - if success
        0                - if failure.
	99 - If the UID was already root (i.e no root session to exit out of later)

=item EXAMPLE:

   unless ($obj = $self->becomeRoot( )) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to enter as root" );
      return 0;
   }

=back

=cut

sub becomeRoot {
    my ($Obj, $rootPassword) = @_;

    my $sub = 'becomeRoot';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $rootPassword ||= 'sonus1';
    # Sanity check - in case we are already root.
    $logger->debug(__PACKAGE__ . ".$sub: Checking current UID");
    my @res = $Obj->{conn}->cmd("id");
    $logger->debug(__PACKAGE__ . ".$sub: id: $res[0]");
    if ($res[0] =~ m/^uid=0\(root\)/) {
        $logger->warn(__PACKAGE__ . ".$sub: Was already root - returning");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [99]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
        return 99;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub: Current user is $res[0] - continuing");
    }

        #TOOLS-71184
    unless($Obj->{SKIP_ROOT}){
        unless ($Obj->{conn}->print('su - root')) {
            $logger->error(__PACKAGE__ . ".$sub: unable to enter as root");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
            return 0;
        }

        my ($prematch, $match) = ('','');

        unless ( ($prematch, $match) = $Obj->{conn}->waitfor(
                                                            -match     => '/[P|p]assword:/',
                                                            -errmode   => "return",
                                                            )) {
            $logger->error(__PACKAGE__ . ".$sub:  Could not match expected Password prompt after \'su - root\'.");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
            return 0;
        }

        if ( $match =~ m/[P|p]assword:/ ) {
            $Obj->{conn}->print($rootPassword);
            unless ( ($prematch, $match) = $Obj->{conn}->waitfor(
                                                    -match => '/incorrect password/',
                                                    -match => '/.*[#>\$%]\s?$/',
                            -match => '/IPv4 Address:/',
                                                    -errmode   => "return",
                                                )) {
                $logger->error(__PACKAGE__ . ".$sub:  Unknown error on password entry.");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
                return 0;
            }
            if ( $match =~ m/incorrect password/ ) {
                $logger->error(__PACKAGE__ . ".$sub:  Password used \'$rootPassword\' for su - root was incorrect.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            elsif($prematch=~/(su: System error|su: Authentication failure)/){ #TOOLS-17460 #TOOLS-74309
                    $logger->warn(__PACKAGE__ . ".$sub: Got \'$1\', trying 'sudo -i -u root'");
                    $Obj->{conn}->print("sudo -i -u root");
                    unless ( ($prematch, $match) = $Obj->{conn}->waitfor(
                                                    -match     => '/[P|p]assword for linuxadmin:/',
                                                    -match => '/.*[#>\$%]\s?$/',
                                                    -errmode   => "return",
                                                )) {
                        $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
                        $logger->error(__PACKAGE__ . ".$sub: Could not match prompt (/.*[#>\$%] \$/) after 'sudo -i -u root'.");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        return 0;
                    }
                    if ( $match =~ m/[P|p]assword for linuxadmin:/ ) {
                        $logger->info(__PACKAGE__ . ".$sub: Trying with linuxadmin password");
                        $Obj->{conn}->print($Obj->{OBJ_PASSWORD});
                        unless ( ($prematch, $match) = $Obj->{conn}->waitfor(
                                                        -match => '/.*[#>\$%]\s?$/',
                                                        -errmode   => "return",
                                                     )) {
                            $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
                            $logger->error(__PACKAGE__ . ".$sub: Could not match prompt (/.*[#>\$%] \$/) after entering password.");
                            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $Obj->{sessionLog1}");
                            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $Obj->{sessionLog2}");
                            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                            return 0;
                        }                        
                    }
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub:  Password accepted for \'su - root\'");
            }
        if ( $match =~ m/IPv4 Address:/ ){
                $logger->info(__PACKAGE__ . ".$sub: After accepting root Password, asking to Enter Primary Management IPv4 Address: [Press Ctrl-C to access root account] ");
                $Obj->{conn}->print("\x03");
            }
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        $main::failure_msg .= "TOOLS:SBX5000HELPER-Root Login Failed; ";
            return 0;
        }
    }
    else{
    $logger->debug(__PACKAGE__ .".$sub: Skipping su - root as SKIP_ROOT is set");
    }

    $Obj->setPrompt;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [rootObj]");

    return 1;
}

=head2 C< cleanStartStandAloneSBX >

=over

=item DESCRIPTION:

    This subroutine is used to create a SBC Object and
    execute the list of commands passed and installs the license.

 Work flow:
    -with the user passed hostip (it should be MGMTNIF->1-> IP or IPV6 )and using the TESTBED hash we will find out the TMS alias of SBC.
    -create the SBC object and set the license_mode flag.
    	license_mode flag values,
		0 - no license
			If skip_license_check flag is set in TESTSUITE file.
		1 - Legacy (Permanent) license
			If no options are provided by default we will install legacy license
		2 - NWL license
			If SLS ip is provided and App version is greater than 6.1
    -Depends on the license_mode value,we will execute the cmds and install the license.
    -destroy the Objects.

=item ARGUMENTS:

    1st Arg    - The ip address of the sbx machine. [ Mandatory ]
    2nd Arg    - root password of the machine. [ Mandatory ]
    3rd Arg    - The list of commands to be executed. [ Mandatory ]
    4th Arg    - The timeout value required to execute the service start and stop commands
                 in seconds. [ Default value 300 seconds ] While testing, it was found that
                 at least 300 seconds of timeout value is required in order to execute the stop or
                 start services successfully everytime. Depends on the box, so pass the value accordingly.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::Base::new

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    my ($host_ip, $rootpwd, $timeout, $commands);
    $host_ip = '10.6.82.44';
    $rootpwd = 'sonus1';
    $timeout = 360;
    $commands = [
        'service sbx stop',
        '/opt/sonus/sbx/scripts/removecdb.sh',
        'cd /opt/sonus/sbx/psx/sql',
        'perl configureDB -install NEW -loglevel 1 -force Y',
        'service sbx start',
    ];
    unless(&SonusQA::SBX5000::SBX5000HELPER::cleanStartStandAloneSBX( $host_ip , $rootpwd,$commands , $timeout)){
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . '.$subroutine_name');
        $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  ");
    }

=back

=cut

sub cleanStartStandAloneSBX    {
    my $hostip  = shift;
    my $rootpwd = shift;
    my $cmdList = shift;
    my $timeout = shift;

    my $sub_name = 'cleanStartStandAloneSBX';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    # Check Mandatory and Optional arguments
    unless ( defined $hostip ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Host IP not passed or empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( defined $rootpwd ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Root Password not passed or empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( defined $cmdList ){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Command List not passed.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    # Set default Timeout value of 300 secs i.e. 5 minutes.
    $timeout ||= 300;
    my ($alias_name, $obj);
#TOOLS-13904 - with the given ip , check the TESTBED hash and find the TMS alias name.
    foreach my $index (1..$main::TESTBED{sbx5000_count}){
	if($hostip =~/^($main::TESTBED{'sbx5000:'.$index.':ce0:hash'}{MGMTNIF}{1}{IP})|($main::TESTBED{'sbx5000:'.$index.':ce0:hash'}{MGMTNIF}{1}{IPV6})$/){
	    $alias_name = $main::TESTBED{'sbx5000:'.$index.':ce0'};
	}
    }
    $logger->info(__PACKAGE__ . ".$sub_name: The TMS alais of ip [$hostip] is $alias_name");
    unless ( $obj = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $alias_name, -sessionlog => 1, -do_not_delete => 1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to create a SBX obj to \'$alias_name\' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000HELPER- SBX Obj Creation Failed; ";
        return 0;
    }

    my $license_mode = 1;
    if($main::skip_license_check == 1){ # To support skip_license_check flag defined in TESTBED file
            $license_mode = 0;
    }elsif( ($obj->{TMS_ALIAS_DATA}->{SLS}->{1}->{IP} || $obj->{TMS_ALIAS_DATA}->{SLS}->{1}->{IPV6}) ){ # To support the suites which needs NWL if SLS ip defined
            $license_mode = 2;
    }

    if ($license_mode == 1){
        unless( $obj->generateLicense(-skip_cleanstart => 1)){ # calling generateLicense() to install permanent licenses. To skip the cleanStartSBX( ) call , passing -skip_cleanstart value as 1.
            $logger->error(__PACKAGE__ . ".$sub_name: ERROR. Installing license failed");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error Installing License; ";
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Legacy License Installation success");
    }

    # Create SSH session object using root login & port 2024
    #my $rootObj = makeRootSession( -obj_host => $hostip, -root_password => $rootpwd, -defaulttimeout => 60);
    my $rootObj = $obj->{CE0LinuxObj};

    my $cmdFailFlag = 0;
    foreach( @{$cmdList} ) {
        my $cmd = $_;
        my ($cmdStatus , @cmdResult) = _execShellCmd($rootObj, $cmd, $timeout );
        unless ( $cmdStatus ) {
            if ($cmd =~ /removecdb\.sh/i ) {
               $logger->warn(__PACKAGE__ . ".$sub_name: cmd \'$cmd\' returned warning");
               next;
            }
            $logger->error(__PACKAGE__ . ".$sub_name:   cmd \'$cmd\' unsuccessful.");
            $cmdFailFlag = 1;
            last;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: Executed cmd \'$cmd\' successfully.");

        # delay required, if want to make a ssh connection to port 22 after running service sbx start .
        if ( $cmd =~ /start/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Sleeping for $timeout seconds so that all the processes are up.");
            unless($obj->checkProcessStatus()){
                $logger->error(__PACKAGE__ . ".$sub_name: SBC is not UP or Processes is not running;");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error SBC is not UP or Processes is not running; ";
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Waking up after $timeout seconds sleep.");
        }
    }

    if( $cmdFailFlag ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UN-SUCCESSFUL.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed in CleanDb; ";
        return 0;
    }

    if ($license_mode == 2){
        unless ($obj->makeReconnection()) {
            $logger->error(__PACKAGE__ . ".$sub_name unable to reconnect after a CleanStart");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error makeReconnection Failed; ";
            return 0;
        }
        unless( $obj->configureNWL()){ # calling configureNWL() to install NWL
            $logger->error(__PACKAGE__ . ".$sub_name: ERROR. Installing license failed");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error Installing License; ";
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: NWL License Installation success");
    }

    # Close SSH session & Destory it.
    $logger->debug(__PACKAGE__ . ".$sub_name: Destroying SBX Object created.");
    $obj->DESTROY;

    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< createUser >

=over

=item DESCRIPTION:

    This method will create a user in sbx by using arguments, make a login to sbc by using user created and random generated password, changes the random password to required password and return session for future use

=item ARGUMENTS:

   mandatory
        -user => username of user to be created
        -group => groupname of user to be created
   optional
        -newpassword  => new password for user created - default value is Sonus@123

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        New user session obj      - if success
        0                         - if failure.

=item EXAMPLE:

   unless ($obj = $sbxObj->createUser(-user => 'calea', -group => 'Calea')) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to enter as root" );
      return 0;
   }

   Note - make sure you are in configure private mode before this API get invoked

=back

=cut

sub createUser {
    my ($self) = shift;

    my $sub_name = 'createUser';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    if ($self->{D_SBC}) {
        my $result = 1;
        my $newObj = bless {}, "SonusQA::SBX5000";

        foreach my $sbcType (@{$self->{PERSONALITIES}}) {
            foreach my $instance (keys %{$self->{$sbcType}}) {
                my $aliasName = $self->{$sbcType}->{$instance}->{OBJ_HOSTNAME};
                $logger->debug(__PACKAGE__ .".$sub_name: '$aliasName' ('$sbcType\-\>$instance' object)");
                unless ($newObj->{$sbcType}->{$instance} = createUser($self->{$sbcType}->{$instance}, @_)) {
                    $logger->debug(__PACKAGE__ .".$sub_name: returned 0 for '$aliasName' ('$sbcType\-\>$instance' object)");
                    $result = 0;
                    last;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Object created for $aliasName ($sbcType\-\>$instance)");
                $newObj->{$sbcType}->{$instance}->{SBC_TYPE} = $sbcType;

                push (@{$newObj->{BANNER}}, @{$newObj->{$sbcType}->{$instance}->{BANNER}});
            }
            last unless $result;
        }

        #return 0 or newObj
        unless ($result) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$result]");
            return $result;
        }

        foreach (qw( D_SBC HA_SETUP NK_REDUNDANCY PKT_ARRAY APPLICATION_VERSION OS_VERSION PROMPT DEFAULTPROMPT ENTEREDCLI POST_4_0 POST_3_0 TMS_ALIAS_DATA PERSONALITIES)){
            $newObj->{$_} = $self->{$_} ;
        }
        $newObj->{conn} = $newObj;
        $newObj->{ACTIVE_CE} = 'DSBC_ACTIVE_CE';
        $newObj->{STAND_BY} = 'DSBC_STAND_BY';
        $newObj->{DSBC_ACTIVE_CE}->{conn} = bless {DSBC_CE => 'ACTIVE_CE', DSBC_OBJ => $newObj}, "SonusQA::SBX5000";
        $newObj->{DSBC_STAND_BY}->{conn} = bless {DSBC_CE => 'STAND_BY', DSBC_OBJ => $newObj}, "SonusQA::SBX5000";
        $newObj->{CE0LinuxObj}->{conn} = bless {DSBC_CE => 'CE0LinuxObj', DSBC_OBJ => $newObj}, "SonusQA::SBX5000";
        $newObj->{CE1LinuxObj}->{conn} = bless {DSBC_CE => 'CE1LinuxObj', DSBC_OBJ => $newObj}, "SonusQA::SBX5000";

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$result]");
        return $newObj;
    }

    my (%args) = @_;

    foreach ('-user','-group') {
       unless ($args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument \'$_\' is empty or blank");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           return 0;
       }
    }

    $args{-newpassword} ||= 'Sonus@123';

    unless ($self->execCliCmd("set oam localAuth user $args{-user} group $args{-group}")) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to create $args{-user} user");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
       return 0;
    }

    unless ($self->execCliCmd("commit")) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to commit after creation of user");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
       return 0;
    }
    my($prematch, $match);
    unless(grep /Password for/i, @{$self->{CMDRESULTS}}){
       unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT}, -timeout   => 30)) {
           $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected match -> $_ ,prematch ->  $prematch,  match ->$match");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           $main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
           return 0;
       }
       push (@{$self->{CMDRESULTS}}, split(/\n/, $prematch));
    }
    my $pass = '';
    foreach (@{$self->{CMDRESULTS} }) {
       next unless ($_ =~ /Password for\s*$args{-user}\s*is (\S+)/i);
       $pass = $1;
       $logger->debug(__PACKAGE__ . ".$sub_name:  new password generated is \$pass");
       last;
    }

    # Fix for TOOLS-6144
    unless ($pass){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get password for -obj_user \'$args{-user}\', may be user is already existed, and for existed user we wont be able to get the login password");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
        return 0;
    }

    my $newSbxObj = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $self->{TMS_ALIAS_NAME}, -obj_user => $args{-user}, -obj_password => $pass, -sessionlog => 1, -newpassword => $args{-newpassword}, -do_not_delete => 1, -templateType => $self->{TEMPLATETYPE});
    unless ($newSbxObj) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to create a session to \'$self->{TMS_ALIAS_NAME}\' using user - \'$args{-user}\' , password - $pass");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
       return 0;
    }
    if($newSbxObj->{SBC_NEWUSER_4_1} == 1){
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
       return $newSbxObj;
    }
    $newSbxObj->{conn}->print("change-password");

    tie (my %print, "Tie::IxHash");
    %print = ( 'Enter old password:' => $pass, 'Enter new password:' => $args{-newpassword}, 'Re-enter new password:' => $args{-newpassword});

    ($prematch, $match) = ('','');
    foreach (keys %print) {
       unless ( ($prematch, $match) = $newSbxObj->{conn}->waitfor(-match => "/$_/i", -match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT})) {
           $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected match -> $_ ,prematch ->  $prematch,  match ->$match");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $newSbxObj->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $newSbxObj->{sessionLog2}");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
           return 0;
       }
       if ($match =~ /$_/i) {
           $logger->info(__PACKAGE__ . ".$sub_name: matched for $_, passing $print{$_} argument");
           $newSbxObj->{conn}->print($print{$_});
       } else {
           $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected prompt $_");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
           return 0;
       }
    }

    unless ( ($prematch, $match) = $newSbxObj->{conn}->waitfor(-match => '/password has been changed/i', -match => '/Password mismatch/i', -timeout   => $self->{DEFAULTTIMEOUT})) {
       $logger->error(__PACKAGE__ . ".$sub_name: dint recive expected msg after changing password , prematch ->  $prematch,  match ->$match");
       ($prematch, $match) = $newSbxObj->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $newSbxObj->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $newSbxObj->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
       return 0;
    }

    if ($match =~ /password has been changed/i) {
       $logger->info(__PACKAGE__ . ".$sub_name: password changed successfully");
       $newSbxObj->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
       return $newSbxObj;
    } elsif ($match =~ /Password mismatch/i) {
       $logger->info(__PACKAGE__ . ".$sub_name: password miss matched");
       $newSbxObj->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-User Creation Failed; ";
       return 0;
    }
}


=head2 C< completeInstall >

=over

=item DESCRIPTION:

 This API will install the build on sbc with by making the user defined setting in runtime, also there is a option to copy the build from clear case server and install

=item ARGUMENTS:

 Mandatory:

    -package => package to be installed on server
	-primarySBXData => A hash ref with all the information of sbc ( primary or standalone)
					   below are the keys of hash
					   manditory
						-ip => ip addres of sbx ( primary or standalone )

					   optional -> these will be input passed during the installation
					     -host_role => local host role of current box
						 -system_name => system name to given during the installation
						 -host_name => host name to given during the installation
						 -peer_host_name => peer host name
						 -ntp_server_ip => ntp server ip
						 -time_zone_index => time zone index number
						 -allow_ssh => y to enable n to disable ssh acces ( default value is y)
						 -apply_config => pass empty to apply above config ( default is empty)
						 -reboot => pass y to reboot ( default is y)

 Optional:

    -secondarySBXData => required hash ref same as -primarySBXData shown above ( for HA)
    -ccData => Hash ref holding clearcase server deatils,
				manditory keys
					-ccHostIp => ip of clear case server
					-ccView => view in clear case
					-ccUsername => clear case username
					-ccPassword => password required to login clear case server
    -timeout => timeout value in seconds required for operation in API ( default is 600secs)


=item OUTPUT:

    0   - fail
    1 - success

=item EXAMPLE:

	my %args = ( -package => 'sbx-V02.00.06-R000.x86_64.tar.gz',
				-primarySBXData => { -ip => '10.6.82.88',
				                     -host_role => 1,
									 -system_name => 'sbx1',
									 -host_name => 'sbx1',
									 -peer_host_name => 'sbx2',
									 -ntp_server_ip => '1.1.1.1',
                                                                         -time_zone_index => 27,
									 },
				-secondarySBXData => { -ip => '10.6.82.88',
				                     -host_role => 1,
									 -system_name => 'sbx1',
									 -host_name => 'sbx1',
									 -peer_host_name => 'sbx2',
									 -ntp_server_ip => '1.1.1.1',
                                                                         -time_zone_index => 27,
									 },
				-ccData	=> { -ccHostIp => '10.2.34.12',
							 -ccView => 'abc.sbx-V02.00.06-R000',
							 -ccUsername => 'autouser',
							 -ccPassword => 'autouser'},
				-timeout => 900);

    unless ( SonusQA::SBX5000::SBX5000HELPER::completeInstall (%args ) ) {
        $logger->error(__PACKAGE__ . " Failed to install the required package ");
        return 0;
    }

=back

=cut

sub completeInstall {
    my ( %args) = @_;

    my $sub_name = 'completeInstall';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    my (%primary, %secondary, %clearcase, $build, $temp_build);

    unless ( defined $args{-package} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter \'-package\' is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    } elsif ( !(defined $args{-primarySBXData}) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: SBX server information missing or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    my $timeout = $args{-timeout} || 300;

    %primary = %{$args{-primarySBXData}};
    my $standalone = 0;

    unless ( defined $args{-secondarySBXData}) {
        $logger->info(__PACKAGE__ . ".$sub_name: \'-secondarySBXData\' is blank, hence considering as standalone");
        $standalone = 1;
    } else {
        %secondary = %{$args{-secondarySBXData}};
    }

    foreach (qw/ip/) {
        unless ( defined $primary{-$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter \'$_\' for primarySBX is empty or missing");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
        next if $standalone;
        unless ( defined $secondary{-$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter \'$_\' for secondarySBX is empty or missing");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
    }

    my $pre_3_1 = 0;
    my $version = '';
    if ( $args{-package} =~ /\S+(V.*-\S+)\.\S+\.tar\.gz/i  or $args{-package} =~ /sb[cx]-(.*)\.(.*)\.tar.gz/i) {
        $temp_build = "$1.$2";
        $temp_build =~ s/x\d.*$//;
        $build = $temp_build;
        if ($temp_build =~ /(V.*)([A-Z].*)/i) {
            $build = "$1-$2";
            my $temp_release = $1;
            if ($temp_release =~ /^\w(\d+\.\d+)\./) {
               $version = $1;
               unless ($1 ge '03.01' ) {
                  $logger->info(__PACKAGE__ . ".$sub_name: you are doing pre-3.1 installation");
                  $pre_3_1 = 1;
               }
           }
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get build info");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
        return 0;
    }

    unless ($version) {
       $logger->error(__PACKAGE__ . ".$sub_name: unable to get version info");
       $logger->error(__PACKAGE__ . ".$sub_name: unable to get build info");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
        return 0;
    }

    tie (my %pattern, "Tie::IxHash");
    %pattern = ( 'host_role' => 'Enter local host role:',
                 'system_name' => 'Enter system name:',
                 'host_name'   => 'Enter local host name:',
                 'peer_host_name' => 'Enter peer host name.*:'
               );
    unless ($version ge '03.01') {
        $pattern{'primary_mgmt_ip'} = 'Enter primary management IP.*:';
        $pattern{'primary_mgmt_netmask'} = 'Enter primary management netmask.*:';
        $pattern{'primary_mgmt_gateway'} = 'Enter primary management gateway IP.*:';
        $pattern{'secondary_mgmt_ip'} = 'Enter secondary management IP.*:';
        $pattern{'secondary_mgmt_netmask'} = 'Enter secondary management netmask.*:';
        $pattern{'secondary_mgmt_gateway'} = 'Enter secondary management gateway IP.*:';
    }

    $pattern{'ntp_server_ip'} = 'Enter NTP time server IP.*:';
    if ($version ge '03.01') {
        $pattern{'time_zone_index'} = 'Enter index of the time zone.*:';
        $pattern{'allow_ssh'} = 'Allow Linux ssh access.*:';
        $pattern{'ere_epx'} = 'Enter routing engine personality.*1-ERE 2-ePSX.*:' if ($version ge '04.00');
    }
    $pattern{'apply_config'} = 'Press <ENTER> to apply configuration or R to re-enter.*';
    $pattern{'reboot'} = 'Reboot using updated installation.*' ;

    my %default = ( 'allow_ssh' => 'y', 'apply_config' => '', 'reboot' => 'y' , 'secondary_mgmt_ip' => '0.0.0.0', 'secondary_mgmt_netmask' => '0.0.0.0', 'secondary_mgmt_gateway' => '0.0.0.0', 'ere_epx' => 1);

    my @sbxHost = $standalone ? ($primary{-ip}) : ($primary{-ip},$secondary{-ip});
    my @data =  $standalone ? ( \%primary) : (\%primary, \%secondary);

    foreach my $sbx_data ( @data) {
        foreach my $key ( keys %pattern) {
            if (!$sbx_data->{-$key} and (! defined $default{$key})) {
                $logger->error(__PACKAGE__ . ".$sub_name: required data $key is missing for " . $sbx_data->{-ip});
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
                return 0;
            }
        }
    }


    my %sbxObjs = ();
    foreach (@sbxHost) {
        unless ($sbxObjs{$_} = SonusQA::SBX5000::SBX5000HELPER::makeRootSession( -obj_host => $_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to create root session to SBX -> \'$_\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
        sleep 1; #i want sllep for a sec else session logs will suck
    }

    if ( defined $args{-ccData} and $args{-ccData}) {
        $logger->info(__PACKAGE__ . ".$sub_name: copying the required pacakge from clear case server");
        %clearcase = %{$args{-ccData}};
        $clearcase{-completeBuild} = 1 if (defined $args{-iSMART});

        foreach (qw/ccHostIp ccView ccUsername ccPassword/) {
            unless ( $clearcase{-$_}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter \'$_\' to copy package from clear case is missing or empty");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                return 0;
            }
        }
        foreach ( @sbxHost) {
            $clearcase{-sbxHost} = $_;
            my $cc_status = 0;
            unless ( $cc_status = SonusQA::SBX5000::SBXLSWUHELPER::copyFileFromRemoteServerToSBX(%clearcase)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to copy the package from ClearCase server -> \'$clearcase{-ccHostIp}\' to SBX -> \'$_\'!");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
                return 0;
            }

            if ($cc_status == 2 and (defined $args{-iSMART})) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Package not Built and Ready! ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[2]");
                return 2;
            }
        }
    }

    my $installScript = "appInstall-${build}.sh";

    foreach my $sbx_data ( @data) {
        my $ip = $sbx_data->{-ip};
        # connection to localhost
        my $localhot = new SonusQA::Base( -obj_host => 'localhost', -obj_user => 'autouser', -obj_password => 'autouser', -comm_type => 'SSH', -prompt => '/.*[\$#%>\}]\s*$/', -return_on_fail => 1, -sessionlog => 1);

        unless($localhot) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to make a session to localhost");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        foreach my $file ("appInstall-${build}.sh", "sbc*-${build}.x86_64.md5", "sbc*-${build}.x86_64.tar.gz", "sonusdb-${build}.x86_64.md5", "sonusdb-${build}.x86_64.rpm") {
            unless (defined $args{-ccData}) {
                $logger->info(__PACKAGE__ . ".$sub_name: getting $file from /sonus/ReleaseEng/Images/SBX5000/");
                my $source_file = "/sonus/ReleaseEng/Images/SBX5000/$temp_build/$file";
                my $scp_cmd = "scp -P 2024 " . $source_file . " linuxadmin\@" . $ip . ":/tmp/";
                $sbxObjs{$ip}->{conn}->cmd("/bin/rm -f /tmp/$file"); #god know if some mess is already present so just i will cleanup :-)
                unless ( $localhot->{conn}->print($scp_cmd) ) {
                    $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command : $scp_cmd");
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $localhot->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $localhot->{sessionLog2}");
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                    return 0;
                }
                my ($prematch, $match);
                unless ( ($prematch, $match) = $localhot->{conn}->waitfor(
                                                                            -match     => '/yes[\/,]no/',
                                                                            -match     => '/password\:/',
                                                                            -match     => '/\[error\]/',
                                                                            )) {
                    $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after issuing SCP command");
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $localhot->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $localhot->{sessionLog2}");
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                    return 0;
                }
                if ( $match =~ m/error/ ) {
                    $logger->info(__PACKAGE__ . ".$sub_name:  Command resulted in error\n$prematch\n$match");
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                    return 0;
                }
                if ( $match =~ m/yes[\/,]no/ ) {
                    $logger->info(__PACKAGE__ . ".$sub_name: Matched 'yes/no' prompt ");
                    $logger->info(__PACKAGE__ . ".$sub_name: Entering 'yes'");
                    unless ( $localhot->{conn}->print( "yes" ) ) {
                       $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the command :\"yes\" ");
                       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $localhot->{sessionLog1}");
                       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $localhot->{sessionLog2}");
                       $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
                       return 0;
                    }
                    unless ( ($prematch, $match) = $localhot->{conn}->waitfor( -match     => '/password\:/', -match     => '/\[error\]/',)) {
                       $logger->info(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after entering \"yes\" ");
                       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $localhot->{sessionLog1}");
                       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $localhot->{sessionLog2}");
                       $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                       return 0;
                    }
                }
                if ( $match =~ /password\:/i ) {
                    $logger->info(__PACKAGE__ . ".$sub_name: Entering password");
                    unless ( $localhot->{conn}->cmd( String   => "sonus",Timeout  => 200)) {
                       $logger->info(__PACKAGE__ . ".$sub_name:  Cannot issue the password:\"sonus\" ");
        	       $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $localhot->{conn}->errmsg);
        		$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $localhot->{sessionLog1}");
	        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $localhot->{sessionLog2}");
                       $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                       return 0;
                    }
                }
                else {
                    $logger->info(__PACKAGE__ . ".$sub_name: didnot get the required prompt");
                    $logger->info(__PACKAGE__ . ".$sub_name: Image copy from /sonus/ReleaseEng Failed");
			$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Copying Image Failed; ";
                    return 0;
                }
            }

            unless ($sbxObjs{$ip}->{conn}->cmd("/bin/cp /tmp/$file /opt/sonus/staging/") ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Error : \'cp /tmp/$args{-package} /opt/sonus/staging/\' failed");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $sbxObjs{$ip}->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $sbxObjs{$ip}->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $sbxObjs{$ip}->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Copying Image Failed; ";
                return 0;
            }
            $sbxObjs{$ip}->{conn}->cmd("/bin/rm -f /tmp/$file");
        }

        $sbxObjs{$ip}->{conn}->cmd("cd /opt/sonus/staging/");

        my @temp = $sbxObjs{$ip}->{conn}->cmd("ls -l $installScript");
        if (grep(/No such file or directory/i, @temp)) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed find $installScript in  SBX -> $ip");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
            return 0;
        }

        $sbxObjs{$ip}->{conn}->cmd("chmod +x $installScript");

        unless ($sbxObjs{$ip}->{conn}->print("./$installScript") ) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to start installation");
            $sbxObjs{$ip}->{conn}->waitfor(-match =>$sbxObjs{$ip}->{PROMPT});
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $sbxObjs{$ip}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $sbxObjs{$ip}->{sessionLog2}");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
            return 0;
        }

        my ($match, $prematch) = ('', '');

        foreach my $key ( keys %pattern) {
            next if (!(defined $sbx_data->{-$key}) and !(defined $default{$key}));
            my $print = $sbx_data->{-$key} || $default{$key};
            unless (($prematch, $match) = $sbxObjs{$ip}->{conn}->waitfor( -match => '/' . $pattern{$key} . '/i', Timeout => $timeout) ) {
               $logger->error(__PACKAGE__ . ".$sub_name: failed to expected match -> \'$pattern{$key}\'");
               $logger->error(__PACKAGE__ . ".$sub_name: match -> $match, prematch -> $prematch");
               $sbxObjs{$ip}->{conn}->cmd("\cC"); # Ctrl-C
               $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $sbxObjs{$ip}->{sessionLog1}");
               $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $sbxObjs{$ip}->{sessionLog2}");
               $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Installation Error; ";
               return 0;
            }

            $sbxObjs{$ip}->{conn}->print($print);
        }

        unless (($prematch, $match) = $sbxObjs{$ip}->{conn}->waitfor( -match => '/Rebooting application service/i', Timeout => $timeout) ) {
            $logger->error(__PACKAGE__ . ".$sub_name: system dint reboot in expected time");
            $sbxObjs{$ip}->{conn}->cmd("\cC"); # Ctrl-C
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $sbxObjs{$ip}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $sbxObjs{$ip}->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        }

        $logger->info(__PACKAGE__ . ".$sub_name: installation is successful on SBX -> $ip");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 C< configureSbxFromTemplate >

=over

=item DESCRIPTION:

 Iterate through template files for tokens, replace all occurrences of the tokens with the values in the supplied hash (i.e. data from TMS).
 For each template file using CLI session do the provisioning.

=item Manditory Arguments :

 - file list (array reference)
      specify the list of file names of template (containing CLI commands)
 - replacement map (hash reference)
      specify the string to search for in the file

=item Optional Argument :

 - timeout value in seconds ( default is $self->{DEFAULTTIMEOUT})

=item Return Values :

 - 0 configuration of sbx using template files failed.
 - 1 configuration of sbx using template files successful.

=item Example :

    my @file_list = (
                        "QATEST/sbx5000/sbxNicCfg.template",
                        "QATEST/sbx5000/sbxANSIM3uaSingleSTPMultiGSX.template",
                    );

    my %replacement_map = (
        # GSX - related tokens
        'GSXMNS11IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},
        'GSXMNS12IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{2}->{IP},
        'GSXMNS21IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{3}->{IP},
        'GSXMNS22IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{4}->{IP},

        # PSX - related tokens
        'PSX0IP1'  => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{IP},
        'PSX0NAME' => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{NAME},

        # sbx5000 - related tokens
        'CE0SHORTNAME' => $TESTBED{'sbx5000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME},
        'CE1SHORTNAME' => $TESTBED{'sbx5000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME},
        'CE0LONGNAME' => "$TESTBED{'sbx5000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME}",
        'CE1LONGNAME' => "$TESTBED{'sbx5000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME}",
        'CE0EXT0IP' => $TESTBED{'sbx5000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{IP},
        'CE0EXT1IP' => $TESTBED{'sbx5000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{IP},
        'CE0INT0IP' => $TESTBED{'sbx5000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{IP},
        'CE0INT1IP' => $TESTBED{'sbx5000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{IP},
        'CE1EXT0IP' => $TESTBED{'sbx5000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{IP},
        'CE1EXT1IP' => $TESTBED{'sbx5000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{IP},
        'CE1INT0IP' => $TESTBED{'sbx5000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{IP},
        'CE1INT1IP' => $TESTBED{'sbx5000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{IP},

        'CE0EXT0NETMASK' => $TESTBED{'sbx5000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
        'CE0EXT1NETMASK' => $TESTBED{'sbx5000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
        'CE0INT0NETMASK' => $TESTBED{'sbx5000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{MASK},
        'CE0INT1NETMASK' => $TESTBED{'sbx5000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{MASK},
        'CE1EXT0NETMASK' => $TESTBED{'sbx5000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
        'CE1EXT1NETMASK' => $TESTBED{'sbx5000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
        'CE1INT0NETMASK' => $TESTBED{'sbx5000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{MASK},
        'CE1INT1NETMASK' => $TESTBED{'sbx5000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{MASK},
    );

    unless ( $sbxObj->configureSbxFromTemplate( \@file_list, \%replacement_map ) ) {
        $TESTSUITE->{$test_id}->{METADATA} .= "Could not configure sbx5000 from Template files.";
        printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$test_id:  Configured sbx5000 from Template files.");

=back

=cut

sub configureSbxFromTemplate {

    my ($self) = shift;
    my $sub_name = "configureSbxFromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");
    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&configureSbxFromTemplate, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my ($file_list_arr_ref, $replacement_map_hash_ref, $timeout) = @_ ;

    unless ( defined $file_list_arr_ref ) {
       $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory file list array reference input is missing or blank.\n");
       $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
       return 0;
    }

    unless ( defined $replacement_map_hash_ref ) {
       $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory replacement map hash reference input is missing or blank.\n");
       $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
       return 0;
    }

    my $ce = $self->{ACTIVE_CE};

    my @file_list = @$file_list_arr_ref;
    my %replacement_map = %$replacement_map_hash_ref;
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = 'linuxadmin';
    $scpArgs{-hostpasswd} = 'sonus';
    $scpArgs{-scpPort} = '2024';

    foreach my $file_name (@file_list) {
       my ( $f, @template_file );
       unless ( open INFILE, $f = "<$file_name" ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open input file \'$file_name\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }

       @template_file  = <INFILE>;
       unless ( close INFILE ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close input file \'$file_name\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }

       # Check to see that all tokens in our input file are actually defined by the user...
       # if so - go ahead and do the processing.
       my @tokens = SonusQA::Utils::listTokens(\@template_file);

       unless (SonusQA::Utils::validateTokens(\@tokens, \%replacement_map) == 0) {
           $logger->error(__PACKAGE__ . ".$sub_name:  validateTokens failed.");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }

       my @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);

       # Now the framework would go write @file_processed either to a new file, for sourcing
       my $out_file;
       if($file_name =~ m/(.*?)\.template/) {
           $out_file = $1;
       }

       my $script_file;
       my $from_path;
       if($file_name =~ m/(.*\/)(.*?)\.template/) {
           $from_path = $1;
           $script_file = $2;
       }

       # open out file and write the content
       $logger->debug(__PACKAGE__ . ".$sub_name: writing \'$out_file\'");
       unless ( open OUTFILE, $f = ">$out_file" ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }

       print OUTFILE (@file_processed);
       unless ( close OUTFILE ) {
           $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close output file \'$out_file\'- Error: $!");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }
       $scpArgs{-sourceFilePath} = $out_file;
       $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."/tmp/$script_file";
       unless (&SonusQA::Base::secureCopy(%scpArgs)) {
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the $out_file to /tmp/$script_file file");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
       }

       unless ($self->{$ce}->{conn}->cmd("/bin/cp /tmp/$script_file /home/Administrator/")) {
           $logger->error(__PACKAGE__ . ".$sub_name: failed copy /tmp/$script_file to /home/Administrator/");
           $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{$ce}->{conn}->errmsg);
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to copy $script_file; ";
           return 0;
       }

       my $attempt = 1;
       my ($prematch, $match) = ('', '');
       REPEATE: while ( $attempt <= 3 ) {
           unless ( $self->execCliCmd("source $script_file", $timeout)) {
              unless ( grep (/Aborted: the configuration database is locked/, @{$self->{CMDRESULTS}})) {
                  $logger->error(__PACKAGE__ . ".$sub_name:  failed to source configuration file - $script_file :\n@{ $self->{CMDRESULTS} }" );
                  $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to source configurations; ";
                  return 0;
              } else {
                  $logger->error(__PACKAGE__ . ".$sub_name: failed to source configuration file  with the msg \'Aborted: the configuration database is locked\' on attempt -> $attempt");
                  $logger->debug(__PACKAGE__ . ".$sub_name: Database Error Encountered. So sleeping for 15 seconds ");
                  sleep (15);

                  unless ( $self->{conn}->print( "exit" ) ) {
                      $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue exit on sbc session");
                      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                      $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                      return 0;
                  }
                  unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/yes[\/,]no/',
                                                                         -match     => '/\[ok\]/',
                                                                         -match     => '/\[error\]/',
                                                                         -match     => $self->{PROMPT} ) ) {
                      $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after \'exit\'.");
        	      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	              $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                      return 0;
                  }

                  if ( $match =~ m/yes[\/,]no/ ) {
                      $logger->debug(__PACKAGE__ . ".$sub_name:  Matched yes,no prompt for discarding changes");
                      $self->{conn}->print( "yes" );
                      unless ( ($prematch, $match) = $self->{conn}->waitfor( -match => $self->{PROMPT} )) {
                          $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'");
                          $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                          $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
				$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                          return 0;
                      }
                      if ( $prematch =~ m/\[error\]/ ) {
                          $logger->error(__PACKAGE__ . ".$sub_name:  \'Yes\' resulted in error\n$prematch\n$match");
                          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                          return 0;
                      } elsif ( $prematch =~ m/\[ok\]/ ) {
                          $logger->debug(__PACKAGE__ . ".$sub_name:  Left private session abandoning modifications");
                      } else {
                          $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'\n$prematch\n$match");
                          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                          return 0;
                      }
                  } elsif ( $match =~ m/\[ok\]/ ) {
                      $logger->debug(__PACKAGE__ . ".$sub_name:  Left private session.");
                      # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
                      # next call to execCmd
                      $self->{conn}->waitfor( -match => $self->{PROMPT} );;
                  } elsif ( $match =~ m/\[error\]/ ) {
                      $logger->debug(__PACKAGE__ . ".$sub_name:  \'exit\' command error:\n$prematch\n$match");
                      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                      $self->{conn}->waitfor( -match => $self->{PROMPT} );
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                      return 0;
                  } else {
                      $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
                      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
			$main::failure_msg .= "TOOLS:SBX5000HELPER-Configuration Error; ";
                      return 0;
                  }
                  $attempt++;
              }
          } else {
              $logger->debug(__PACKAGE__ . ".$sub_name: Sourcing $script_file file on SBX Successful ");
              last REPEATE;
          }
       }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Sourcing configuration files on SBX Successful");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< getOsVersion >

=over

=item DESCRIPTION:

    This method will SBC Os version by running swinfo command on shell session, Also store the Application information in Object variable (APPLICATION_VERSION) for soft/virtual sbc.

=item ARGUMENTS:

   NONE

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        OS vesrion      - if success
        0                - if failure.

=item EXAMPLE:

   unless ($os_version = $self->getOsVersion( )) {
      $logger->error(__PACKAGE__ . ".$sub:  unable to get SBC OSversion" );
      return 0;
   }

=back

=cut

sub getOsVersion {
    my $self = shift;
    my $sub_name = 'getOsVersion()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @swinfo = $self->{$self->{ACTIVE_CE}}->{conn}->cmd("swinfo");
    my ($os_version, $app_version) = ('', '');
    unless (grep(/BIOS\s*\:\s*\S+/, @swinfo)) {
       $self->{SOFT_SBC} = 1;
    }

    foreach my $line ( @swinfo ) {
       if($line =~ /^\s*OS:\s+(\S+)/) {
	  my $ver = $1;
	  unless($ver =~ /^V/){
              $os_version = "OS_V$ver";
	  }else{
	      $os_version = "OS_$ver";
	  }
          $os_version =~ s/-//g;
       } elsif (!$self->{APPLICATION_VERSION} and $self->{SOFT_SBC} and ($line =~ /sbc\-V(\S+)/ or $line =~ /^\s*SBC:\s+(\S+)/i)) {
          $app_version = $1;
          $app_version =~ s/\.x86\_64//i;
          $app_version =~ s/-//;
          $self->{APPLICATION_VERSION} = $app_version;
	  $logger->debug(__PACKAGE__ . ".$sub_name: Got the APPLICATION VERSION : \'$self->{APPLICATION_VERSION}\' ");
       }
       last if ($os_version and $app_version);
    }

    unless ($os_version) {
       $logger->error(__PACKAGE__ . ".$sub_name: unable to get the OS Version info");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-OS version Error; ";
       return 0;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub_name: we are able to get the OS Version info");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$os_version]");
       return $os_version;
    }
}


=head2 C< getCeNames >

=over

=item DESCRIPTION:

    Do a 'show configuration system serverAdmin' and return the ce0 and ce1(if it exists) names.

=item ARGUMENTS:

    none

=item PACKAGE:

  SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

     return value 1 - return status - 0   - fail, 1   - success
     return value 2 - ce0 name (or "NULL" if name not found)
     return value 3 - ce1 name (or "NULL" if name not found)

=item EXAMPLE:

     (statusCode, $sbxCe0Name, $sbxCe1Name) = $sbx_object->getCeNames();

=back

=cut

sub getCeNames {

    my ($self) = @_;
    my $sub_name  = "getCeNames()";
    my $line;
    my $start = 0;
    my @fields;
    my $ce0Name = "NULL";
    my $ce1Name = "NULL";
    my $returnStatus = 1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #checking if D_SBC,
    #execute only for S_SBC as ce name will be same for each type of SBC
    #to get the ce names for different personality of SBC, the subroutine will be called using appropriate object
    my @obj_arr;
    if ($self->{D_SBC}) {
        my $sbc_type = (exists $self->{S_SBC}) ? 'S_SBC' : 'I_SBC';
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for ($sbc_type)");
        if($self->{NK_REDUNDANCY}){
            foreach my $index (keys %{$self->{$sbc_type}}){
                $obj_arr[0] = $self->{$sbc_type}->{$index}  if($self->{$sbc_type}->{$index}->{REDUNDANCY_ROLE} =~ /ACTIVE/i and ! $obj_arr[0]); #pushing 1st active sbc obj into array
                $obj_arr[1] = $self->{$sbc_type}->{$index}  if($self->{$sbc_type}->{$index}->{REDUNDANCY_ROLE} =~ /STANDBY/i and ! $obj_arr[1]);#pushing standby sbc obj into the array
                last if($obj_arr[0] and $obj_arr[1]);
            }
        }else{
            @obj_arr = $self->{$sbc_type}->{1};
        }
    }else{
        @obj_arr = $self;
    }
    my $cmdString = "show configuration system serverAdmin";
    foreach my $obj (@obj_arr){
        unless ($obj->execCliCmd("$cmdString")) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Failed to get the system server info");
            $logger->debug(__PACKAGE__ . ".$sub_name : $cmdString");
            $main::failure_msg .= "TOOLS:SBX5000HELPER-Error Getting CE Names; ";
            $returnStatus = 0;
            last;
        } else {
            my $ceName;
            $logger->debug(__PACKAGE__ . ".$sub_name: Command results are : ".Dumper($obj->{CMDRESULTS}));
            foreach $line ( @{ $obj->{CMDRESULTS}} ) {
                $ceName = $1 if ($line =~ /serverAdmin\s+(.+)\s+\{/i) ;
                $ce0Name = $ceName if($line =~ /[\s\w]+primary;/i);
                $ce1Name = $ceName if($line =~ /[\s\w]+secondary;/i);
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: ce0Name [$ce0Name] and ce1Name [$ce1Name]");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub $returnStatus");
    return ( $returnStatus, $ce0Name, $ce1Name);
}


=head2 C< make_ce0_active >

=over

=item DESCRIPTION:

    check if ce0 (first one in testbeddefinition)  is active, if not then perform switchover to make it active

=item ARGUMENTS:

    none

=item PACKAGE:

   SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

      unless ($sbx_object->make_ce0_active($sbxNameCe0)) {
		$sbxObj->wind_Up($testCaseId,$parseFile,\@parse,$cdrType,\%cdrhash,$TESTSUITE->{PATH},$TESTSUITE->{STORE_LOGS});
		return 0;
	  }

=back

=cut

sub make_ce0_active {
   my ($self) = shift;
   my $sub_name   = "make_ce0_active";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

   if ($self->{D_SBC}) {
       my %hash = (
                         'args' => [@_],
                         'roles'=> ['STANDBY'] #will have meaning only if NK
                 );
         my $retVal = $self->__dsbcCallback(\&make_ce0_active, \%hash);
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$retVal]");
         return $retVal;
   }
   my ($sbxName, $sbxNameCe0, $synchCheckAttempts) = @_;
    if (exists $self->{TMS_ALIAS_DATA}->{CE} and $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}) {
        $logger->info(__PACKAGE__ . ".$sub_name: Changing sbxNameCe0 from $sbxNameCe0 to $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}\(CE->1->HOSTNAME\).");
        $sbxNameCe0 = $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME} ;
    }else {
        $logger->warn(__PACKAGE__ . ".$sub_name: CE->1->HOSTNAME is not defined in tms_alias. So prceeding with $sbxNameCe0");
    }
    my $configResult = 1;

    my @serverStatusCmdAndDisplay =  [ "show table system serverStatus $sbxNameCe0 mgmtRedundancyRole", "mgmtRedundancyRole", "active;" ];

    # check if ce0 is active, if not then perform switchover to make it active
    my $do_switchover = 1;
    #do switchover if NK and current role active and installed role is standby
    if ($self->{PARENT}->{NK_REDUNDANCY}) {
	$do_switchover = 0 if ($self->{CE0LinuxObj}->{INSTALLED_ROLE} =~ /standby/i);
    }
    elsif ($self->check_cli_param_values(\@serverStatusCmdAndDisplay)){
	$do_switchover = 0;
    }

    if ($do_switchover) {
	$logger->info(__PACKAGE__ . ".$sub_name:  Secondary sbx is active - switching back to primary again ");
        $sbxName = "vsbcSystem" if($self->{CLOUD_SBC}) ;
	$configResult &= $self->execSystemCliCmd("request system admin $sbxName switchover");
	sleep 10;

	my @objects = ($self);
	if ($self->{PARENT}->{NK_REDUNDANCY}) { #If NK, makeReconnection should happen for current obj and the object which has installed role as standby
            map {push (@objects, $self->{PARENT}->{$self->{SBC_TYPE}}->{$_}) if ($self->{PARENT}->{$self->{SBC_TYPE}}->{$_}->{CE0LinuxObj}->{INSTALLED_ROLE} =~ /standby/i)} keys (%{$self->{PARENT}->{$self->{SBC_TYPE}}});
        }

	# check that there is redundancy synch after previous switchover
	my %cliHash = ( 'Policy Data' => 'syncCompleted',
                    'Disk Mirroring' => 'syncCompleted',
                    'Configuration Data' => 'syncCompleted',
                    'Call/Registration Data' => 'syncCompleted' );
	$synchCheckAttempts ||= $self->{CLOUD_SBC} ? 8 : 6;

	# need to connect to the SBX again via  management
	foreach my $obj (@objects) {
	    unless ($obj->makeReconnection(-iptype => 'any', -mgmtnif => 1, -timeToWaitForConn => 10, -retry_timeout => 1)) {
		$logger->error(__PACKAGE__ . ".$sub_name:  Could not connect to SBX after swithover ");
		$configResult = 0;
		last;
	    }

	    unless ($obj->checkSbxSyncStatus('show status system syncStatus', \%cliHash, $synchCheckAttempts)) {
		$logger->error(__PACKAGE__ . ".$sub_name:  SBX did not synch  after swithover  ");
		$configResult  = 0;
		last;
	    }
	}
  }
  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$configResult]");
  return ($configResult);
}


=head2 C<check_cli_param_values >

=over

=item DESCRIPTION:

    This subroutine issues the specified CLI show command for a specific parameter
    checks that the displayed parameter value matches the specified value.

=item ARGUMENTS:

      -cmdAndDisplayListRef    =>    Reference to the array containing the show commands and expected param values
                                     each array row should be formatted as in following example
                                       [ "show table m3ua sgpLink $sgplink1 state", "state", "disabled;" ],

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCliCmd()

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

   unless ( $sbxObj->check_cli_param_values( \@policyCmdAndDisplay) ) {
     return 0;
   }

=back

=cut

sub check_cli_param_values {

  my ($self,$cmdAndDisplayRef) = @_;
  my $sub_name = "check_cli_param_values";

  my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
  $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

  my @cmdAndDisplay = @{ $cmdAndDisplayRef };

  my $cmd         = "";
  my $attrName    = "";
  my $attrValue   = "";
  my @fields;
  my $cmdRow      = 0;

  # clear any leftover stuff in cmdresults
  $self->{CMDRESULTS} = ();
  $self->execCliCmd(" ");

  # check all commands and attribute values in the @cmdAndDisplay list
  for $cmdRow ( 0 .. $#cmdAndDisplay ) {

	$cmd =  $cmdAndDisplay[$cmdRow][0];
	$attrName = $cmdAndDisplay[$cmdRow][1];
	$attrValue = $cmdAndDisplay[$cmdRow][2];

	# invoke the show command
	unless ( $self->execCliCmd($cmd)){
	  $logger->error(__PACKAGE__ . ".$sub_name :Failed to execute the command: $cmd --\n@{$self->{CMDRESULTS}}");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	  return 0;
	}

	my @selfArray = ($self);
	if ($self->{D_SBC}) {
            @selfArray = ();
            foreach my $sbcType (@{$self->{LOOKUP_RETURN}}) {
                foreach my $instance (keys %{$self->{$sbcType}}){
	            next if($self->{NK_REDUNDANCY} and ! grep { /$self->{$sbcType}->{$instance}->{REDUNDANCY_ROLE}/} @{$self->{NK_ROLE_LOOKUP_RETURN}});#TOOLS-13995 - Added the NK support
                    push (@selfArray, $self->{$sbcType}->{$instance});
                }
            }
        }

	# check the displayed attribute name and value matches the specified values
	foreach my $selfInstance (@selfArray) {
            $logger->debug(__PACKAGE__ .".$sub_name: ".$selfInstance->{'OBJ_HOSTNAME'}. " object.");
	    $logger->info(__PACKAGE__ . ".$sub_name : ---- Command result = @{$selfInstance->{CMDRESULTS}}[0]");
	    @fields = split(' ',  @{$selfInstance->{CMDRESULTS}}[0] );
	    if(($fields[0] ne $attrName) || ($fields[1] ne $attrValue)) {
		$logger->error(__PACKAGE__ . ".$sub_name :Unexpected results expected: $attrName $attrValue , Actual:  $fields[0] $fields[1] -- from the command: $cmd --\n@{$self->{CMDRESULTS}}");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CLI parameter Mismatch; ";
		return 0;
	    }
	}
  }
  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
  return 1;
}

=head2 C<digAndgetDnsData >

=over

=item DESCRIPTION:

    This subroutine issues the specified domain related data, dig the domain and get the ip details for the passed domains, return failure if a record is missing for any one of the passed domain

=item ARGUMENTS:

      -dnsData  => A array referance having domain details required for the dig
                   example - ["dig abell.ipv4.PCR-4135.com 1 a", "dig abell.ipv6.PCR-4135.com 1 aaaa", "dig abell.ipv14.PCR-4135.com 1 a", "dig abell.ipv16.PCR-4135.com 1 aaaa"]
      -addressContext => addressContext name
      -dnsGroup  => dnsGroup group value

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    execCliCmd()
    execCmd()
    enterPrivateSession
    unhideDebug

=item OUTPUT:

    0      - fail
    Hash with ip details      - True (Success)

=item EXAMPLE:

    my %args = ( -dnsData => ["dig abell.ipv4.PCR-4135.com 1 a", "dig abell.ipv6.PCR-4135.com 1 aaaa", "dig abell.ipv14.PCR-4135.com 1 a", "dig abell.ipv16.PCR-4135.com 1 aaaa"],
             -addressContext => 'ALL_TGS',
             -dnsGroup => 1);
    my %result = $sbxObj1->digAndgetDnsData(%args);

=item Output :
    %result is HoH with domain, record index as respective 2 keys with ip as value.
    Example
    $result{'domain1'}->{1}     -> 10.54.80.7
    $result{'domain1'}->{2}     -> 10.54.80.151
    $result{'domain2'}->{1}     -> 10.54.90.7
    $result{'domain2'}->{2}     -> 10.54.90.151

=back

=cut

sub digAndgetDnsData {
    my ($self,%args) = @_;
    my $sub_name = "digAndgetDnsData";

    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-dnsData', '-addressContext', '-dnsGroup') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter \'$_\' is empty or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
    }

    unless ($self->enterPrivateSession()) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to enter into private mode");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    unless ($self->unhideDebug('sonus1')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to enter in");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    unless ($self->execCliCmd('request sbx dns debug command "clear-cache"')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to clear dns cache");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    
    my @domains = ();
    foreach (@{$args{-dnsData}}) {
        next unless ($_ =~ /dig\s+(\S+)\s+/);
        push (@domains, $1);
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing request sbx dns debug command \"$_\"");
        $self->{conn}->cmd("request sbx dns debug command \"$_\"");
        $self->{conn}->buffer_empty;
	#TOOLS-73278 adding an extra cmd to insert enter to get the prompt back after dig command
        $self->{conn}->cmd(" ");
        $self->{conn}->buffer_empty;

    }

    unless ($self->leaveConfigureSession()) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to come out of private mode");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    my @dnsRecord = ();

    unless (@dnsRecord = $self->execCmd("show status addressContext $args{-addressContext} dnsGroup $args{-dnsGroup} dnsEntryDataStatus")) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get the dns details");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    my %recordFound = ();
    foreach my $domain (@domains) {
        my ($found, $recordIndex) = (0,0);
        foreach (@dnsRecord) {
            if ($_ =~ /dnsEntryDataStatus\s+\S+\s+$domain\s+\d+\s+(\d+).*\{/i) {
                $found = 1;
                $recordIndex = $1;
            }
            next unless $found;
            next if (defined $recordFound{$domain}->{$recordIndex});
            next unless ($_ =~ /ipAddress\s+(\S+)\;/i);
            $recordFound{$domain}->{$recordIndex} = $1;
        }
    }

    foreach (@domains) {
       unless (defined $recordFound{$_}) {
          $logger->error(__PACKAGE__ . ".$sub_name: no record found for the domain \'$_\'");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-DNS Records Not Found; ";
          return 0;
       }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[domain record hash]");
    return %recordFound;
}

=head2 C< setCoredumpProfile >

=over

=item DESCRIPTION:

    This functions is to set the coredump profile to required level

=item ARGUMENTS:

    -profileName    - the coredump profile name, deafult is - default;
    -countLimit    - the coredump count limit;
    -spaceLimit    - the coredump space limit;
    -coredumpLevel    	- the coredump Level, default is sensitive

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	None

=item OUTPUT:

    0  - fail;
    1  - success;

=item EXAMPLE:

    unless $sbxObj->setCoredumpProfile(-profileName => 'default', -countLimit => 10, -spaceLimit => 10, -coredumpLevel => 'sensitive' ) {
        $logger->error(__PACKAGE__ . " ======:   Failed to set coredump profile ");
        return 0;
    }

=back

=cut

sub setCoredumpProfile {
    my ($self, %args)=@_;
    my $sub_name = "setCoredumpProfile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $args{-profileName} ||= 'default';
    $args{-coredumpLevel} ||= 'sensitive';
    $args{-countLimit} ||= 10 ;
    $args{-spaceLimit} ||= 20 ;

    unless ( $self->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = 'set profiles system';

    $cmd .= " coredumpProfile $args{-profileName}";
    $cmd .= " coredumpLevel $args{-coredumpLevel}";
    $cmd .= " coredumpSpaceLimit $args{-spaceLimit}" if (defined $args{-spaceLimit} and $args{-spaceLimit});
    $cmd .= " coredumpCountLimit $args{-countLimit}" if (defined $args{-countLimit} and $args{-countLimit});

    $logger->debug(__PACKAGE__ . ".$sub_name: the coredump command is : \'$cmd\' \n");

    unless ( $self->execCommitCliCmd($cmd)) {

        unless ( $self->leaveConfigureSession ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        }
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to execute '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $self->leaveConfigureSession;
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the '$cmd'.");
    return 1;
}

=head2 C< setFipsMode >

=over

=item DESCRIPTION:

    This functions is to set the FIPS mode after coredump

=item ARGUMENTS:

    -hostName    - the host name, deafult is - current host;
    -fipsMode    - the fips mode to be set

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0  - fail;
    1  - success;

=item EXAMPLE:

    unless ($sbxObj->setFipsMode(-hostName => 'PEUGEOT', -fipsMode => 'fips-140-2' )) {
        $logger->error(__PACKAGE__ . " ======:   Failed to set Fips Mode ");
        return 0;
    }

=back

=cut

sub setFipsMode {
    my $self = shift;
    my $sub_name = "setFipsMode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

     if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&setFipsMode, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my (%args) = @_;

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory cli session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $args{-hostName} ||= $self->{OBJ_HOSTNAME};
    $args{-fipsMode} ||= 'fips-140-2';

    unless ( $self->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to enter config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 0;
    }
    my $hostname = $self->{TMS_ALIAS_DATA}->{'NODE'}->{1}->{HOSTNAME};

    my $cmd = "set global signaling sipSigControls tls v1_0 disabled v1_1 disabled v1_2 enabled";
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue CMD : $cmd ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [2]");
        return 0;
    }
    $cmd = "set profiles security EmaTlsProfile defaultEmaTlsProfile tls v1_0 disabled v1_1 disabled v1_2 enabled";
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue CMD : $cmd ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [2]");
        return 0;
    }

    $cmd = "set oam snmp version v3only";
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue CMD : $cmd ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [2]");
        return 0;
    }

    $cmd = "set system admin $hostname $args{-fipsMode} mode enabled";
    # Execute the command for setting FIPS mode
    unless ( $self->{conn}->print( $cmd ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue CMD : $cmd ");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [2]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed CMD : $cmd");

    unless ( $self->{conn}->print( "commit" ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue \'commit\'");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [3]");
         return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'commit\'");

    my ($prematch, $match);

    ($prematch, $match) = $self->{conn}->waitfor(
                                    -match     => '/\[yes,no\]/',
                                    -match     => $self->{PROMPT},
                                                ) ;
    if ($match =~ m/\[yes,no\]/ ){
    $logger->debug(__PACKAGE__ . ".$sub_name:  Matched [yes,no] prompt for Reboot to take effect the changes");
    # Enter "yes"
    $logger->debug(__PACKAGE__ . ".$sub_name:  Going to reboot.");
    $self->{conn}->print( "yes" );
    unless ( ($prematch, $match) = $self->{conn}->waitfor (
                                    -match => $self->{PROMPT},
                                                          )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error after typing \'yes\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [4]");
            return 0;
        }
    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 7 minutes.. ");
    sleep 420;
    unless ($self->makeReconnection()) {
      $logger->error(__PACKAGE__ . ".$sub_name:  unable to reconnect" );
      return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully set the FIPS mode");
    }
    elsif($prematch =~ m/\[error\]/ ){
    $logger->debug(__PACKAGE__ . ".$sub_name: ERROR while executing 'commit': $_");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
     return 0;
    }
    elsif($prematch =~ m/No modifications to commit/ ){
    $logger->debug(__PACKAGE__ . ".$sub_name: No modifications to commit. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: FIPS mode was already set! ");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 C< changePassword >

=over

=item DESCRIPTION:

    This subroutine will change the password of the username passed as its argument.

=item ARGUMENTS:

   mandatory
	-user        : The username of the SBX for which the password has to be changed.
        -oldpassword : The current password for the username.
        -newpassword : The new password for the username.
  optional
    None

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        1                         - on success
        0                         - on failure.

=item EXAMPLE:

   unless ($change_pass = $sbxObj->changePassword( -user => "newuser163", -oldpassword => "Sonus\@123", -newpassword => "Hello\@321" )) {
      $logger->error(__PACKAGE__ . ".$sub: Failed to change the password. " );
      return 0;
   }

=back

=cut

sub changePassword {

    my ($self) = shift;
    my $sub_name = 'changePassword';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&changePassword, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my (%args) = @_;

    foreach ('-user','-oldpassword','-newpassword') {
       unless ($args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument \'$_\' is empty or blank");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           return 0;
       }
    }
    my $newSbxObj = SonusQA::ATSHELPER::newFromAlias( -tms_alias => $self->{TMS_ALIAS_NAME}, -obj_user => $args{-user}, -obj_password => $args{-oldpassword}, -sessionlog => 1, -newpassword => $args{-newpassword}, -do_not_delete => 1);
    unless ($newSbxObj) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to create a session to \'$self->{TMS_ALIAS_NAME}\' using user - \'$args{-user}\' , password - \'$args{-oldpassword}\'");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    if($newSbxObj->{SBC_NEWUSER_4_1} == 1){
       $newSbxObj->DESTROY;
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
       return 1;
    }

    $newSbxObj->{conn}->print("change-password");
    tie (my %print, "Tie::IxHash");
    my ($prematch, $match) = ('','');
    %print = ( 'The password cannot be changed by a non Administrator group user for more than once a day' => 0, 'Enter old password:' => $args{-oldpassword}, 'Enter new password:' => $args{-newpassword}, 'Re-enter new password:' => $args{-newpassword});

    my $retVal = 1;
    foreach (keys %print) {
       unless ( ($prematch, $match) = $newSbxObj->{conn}->waitfor(-match => "/$_/i", -match =>$newSbxObj->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT})) {
           next if ($_ =~ m/The Password/i);
           $logger->error(__PACKAGE__ . ".$sub_name: Did not match for expected match -> $_ Encountered an unexpected error:  $prematch : $match");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
           $retVal = 0;
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $newSbxObj->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $newSbxObj->{sessionLog2}");
           last;
       }
       if ($_ =~ m/The Password/i) {
           $logger->error(__PACKAGE__ . ".$sub_name: ERROR: $prematch : $match");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
           $retVal = 0;
           last;
       } else{
             if ($match =~ /$_/i) {
                $logger->info(__PACKAGE__ . ".$sub_name: matched for $_, passing $print{$_} argument");
                $newSbxObj->{conn}->print($print{$_});
             }else {
                $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected prompt $_");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
                $retVal = 0;
                last;
             }
       }
    }
    if ($retVal) {
        unless ( ($prematch, $match) = $newSbxObj->{conn}->waitfor(-match => '/password has been changed/i', -match => '/Password mismatch/i', -match => '/error/i', -timeout   => $newSbxObj->{DEFAULTTIMEOUT})) {
           $logger->error(__PACKAGE__ . ".$sub_name: Did not receive expected msg after changing password , prematch ->  $prematch,  match ->$match");
           $logger->error(__PACKAGE__ . ".$sub_name: ERROR: $prematch ::: $match");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $newSbxObj->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $newSbxObj->{sessionLog2}");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
           $retVal = 0;
        }
        else {
           if ($match =~ /password has been changed/i) {
               $logger->info(__PACKAGE__ . ".$sub_name: The password has been changed successfully");
           } elsif ($match =~ /Password mismatch/i) {
               $logger->error(__PACKAGE__ . ".$sub_name: Password mismatched");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
               $retVal = 0;
           } elsif ($match =~ /error/i) {
               $logger->error(__PACKAGE__ . ".$sub_name: ERROR: $prematch $match");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to change Password; ";
               $retVal = 0;
           }
       }
   }
   $newSbxObj->{conn}->waitfor(-match =>$newSbxObj->{PROMPT}, -timeout   => $newSbxObj->{DEFAULTTIMEOUT});
   $newSbxObj->DESTROY;
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$retVal]");
   return $retVal;
}

=head2 C< ipsecConfig >

=over

=item DESCRIPTION:

 This subroutine configures the SBX for basic configuration while setting up the tunnel for ipsec.

=item ARGUMENTS:

   mandatory
        $racoon  :  The racoon object to fetch the parameters from TMS.
        -gateway :  the gateway IP for SBX Configuration.
  optional
        -subnet : value of the subnet, default is 32.

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        1                         - on success
        0                         - on failure.

=item EXAMPLE:

   unless ($result = $sbxObj->ipsecConfig( $racoon, -gateway => '10.54.28.1' , -subnet => 40 )) {
       $logger->error(__PACKAGE__ . ".$sub: Failed to configure the SBX " );
       return 0;
   }

=back

=cut

sub ipsecConfig {

    my ($self ) =  shift ;
    my ($racoon) = shift ;
    my %args = @_ ;
    my $sub_name = "ipsecConfig" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ( @output, @req_arr, $count, $LIF, $LIG, $line)  ;
#IPSEC CONFIG
    my $subnet = (defined $args{-subnet} and $args{-subnet}) ? $args{-subnet} : 32 ;
    $logger->info(__PACKAGE__ . ".$sub_name: value of subnet is : $subnet \n");

    unless ( defined $args{-gateway}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory gateway argument is missing.\n");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    my $gateway = $args{-gateway} ;
    $logger->info(__PACKAGE__ . ".$sub_name: gateway  ip : $gateway \n");

    my $IKE_Profile = $racoon->{TMS_ALIAS_DATA}->{IKE}->{1}->{Profile} ;
    my $IPSEC_Profile = $racoon->{TMS_ALIAS_DATA}->{IPSEC}->{1}->{Profile} ;
    my $PreSharedKey = $racoon->{TMS_ALIAS_DATA}->{IPSEC}->{1}->{REMOTEPASSWD} ;
    my $dpdInterval  = $racoon->{TMS_ALIAS_DATA}->{IPSEC}->{1}->{COMPLETION_TIME} ;
    my $saLifetimeTime = $racoon->{TMS_ALIAS_DATA}->{IPSEC}->{1}->{ORIG_SPAN} ;
    my $saLifetimeByte = $racoon->{TMS_ALIAS_DATA}->{IPSEC}->{2}->{ORIG_SPAN} ;
    my $LIF_IP = $racoon->{TMS_ALIAS_DATA}->{NIF}->{1}->{IP} ;
    my $SIP_SIG = $racoon->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IP} ;
    my $RACOON_IP = $racoon->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} ;

    my $cmd = "show table addressContext default ipInterfaceGroup" ;
    unless (@output = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0 ;
    }

    foreach $line (@output) {
        if ($line =~ /------/) {
            $count = 1 ;
            next ;
        }

        if ($count == 1 ) {
            @req_arr = split (/\s+/ ,$line) ;
            $LIF = $req_arr[0] ;
            $LIG = $req_arr[2] ;
            last ;
        }
        next ;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: The value of LIF:\'$LIF\'  and LIG :\'$LIG\'  ");

    unless ($self->enterPrivateSession()) {
        $logger->error(__PACKAGE__ . ".$sub_name: <-- failed to enter private session");
        return 0 ;
    }

    $self->execCliCmd("set addressContext default ipInterfaceGroup $LIF ipsec enabled") ;

    $self->execCliCmd("set profiles security ikeProtectionProfile $IKE_Profile") ;
    $self->execCliCmd("set profiles security ikeProtectionProfile $IKE_Profile algorithms encryption 3DesCbc integrity hmacSha1") ;
    unless ($self->execCommitCliCmdConfirm("set profiles security ikeProtectionProfile $IKE_Profile dpdInterval $dpdInterval saLifetimeTime $saLifetimeTime")) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the ike configuration on SBC ");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->execCliCmd("set profiles security ipsecProtectionProfile $IPSEC_Profile") ;
    $self->execCliCmd("set profiles security ipsecProtectionProfile $IPSEC_Profile espAlgorithms encryption 3DesCbc integrity hmacSha1") ;
    unless ($self->execCommitCliCmdConfirm("set profiles security ipsecProtectionProfile $IPSEC_Profile saLifetimeByte $saLifetimeByte saLifetimeTime $saLifetimeTime")) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the ipsec configuration on SBC ");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

#FOR THE PEER WE HAVE to give IKE-Protection Profile

    $self->execCliCmd("set addressContext default ipsec peer $IKE_Profile ipAddress $RACOON_IP preSharedKey $PreSharedKey") ;
    $self->execCliCmd("set addressContext default ipsec peer $IKE_Profile localIdentity type ipV4Addr ipAddress $LIF_IP") ;
    $self->execCliCmd("set addressContext default ipsec peer $IKE_Profile remoteIdentity type ipV4Addr ipAddress $RACOON_IP") ;
    $self->execCliCmd("set addressContext default ipsec peer $IKE_Profile protocol ikev1 protectionProfile $IKE_Profile") ;


#for SPD(secure policy db) we assign the ipsecProtectionProfile

    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile precedence 100") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile localIpAddr $SIP_SIG localPort 0 localIpPrefixLen 32") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile remoteIpAddr $RACOON_IP remotePort 0 remoteIpPrefixLen 32") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile protocol 0") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile action protect") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile protectionProfile $IPSEC_Profile") ;
    $self->execCliCmd("set addressContext default ipsec spd $IPSEC_Profile peer $IKE_Profile") ;
    unless ($self->execCommitCliCmdConfirm("set addressContext default ipsec spd $IPSEC_Profile state enabled")) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to execute the ipsec configuration on SBC ");
        $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $self->execCliCmd("set addressContext default staticRoute $RACOON_IP $subnet $gateway $LIF $LIG preference 100") ;

    $logger->debug(__PACKAGE__ . ".$sub_name: Executing the Racoon command ");
    unless ($racoon->runRacoon()) {
       $logger->error(__PACKAGE__ . ".$sub_name: <-- unable to run command on Racoon Object ");
       return 0 ;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 10 secs ");
    sleep 10 ;
    return 1 ;

}

=head2 C< verifyRTP >

=over

=item DESCRIPTION:

	helps to verify the Real-time transport protocol (RTP)  messages in the given tshark or text file

=item ARGUMENTS:

 Mandatory :

	%args - hash containing below keys and its respective values
		-sourceip
		-destinationip
		-patter
		-count
		-packetnumber

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->verifyRTP(%args);

=back

=cut

sub verifyRTP {

    my ($self) = shift;
    my $sub_name = "verifyRTP";
    my $select_packet;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&verifyRTP, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my (%args) = @_;
    $logger->info(__PACKAGE__ . ".$sub_name  Entered with args - ", Dumper(%args));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-sourceip} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -sourceip is  empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-destinationip} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -destinationip is  empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $args{-pattern} or $args{-count} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Either -pattern or -count must be a parameter.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (defined $args{-pattern}){
    unless ( $args{-packetnumber} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -packetnumber is  empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $select_packet = $args{-packetnumber};
    } else {
         $select_packet = $args{-count};
    }

    #getting user home dir
    my $user_home = qx#echo ~#;
    chomp($user_home);

    my $source_path = "/var/log/sonus/sbx/evlog/";
    my $key;

    my $dest_path = "$user_home" . "/ats_repos/lib/perl/SonusQA/SBX5000/";
    my $hostname = $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME};
    my $finalFilename;
    #Get the latest .PKT file from the SBC
    unless ($finalFilename = $self->getRecentLogViaCli('PKT')) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get the current PKT logfile" );
        return 0;
    }
    my $source_file = "$source_path" . "$finalFilename";
    #copying the act file from SBX to local server
    # create connection
    $logger->debug(__PACKAGE__ . ".$sub_name: Transfering \'$finalFilename\' to local server");

    my $dest_file = "$dest_path" . "File.pkt";
    $logger->debug(__PACKAGE__ . ".$sub_name: Source file : $source_file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: destination file : $dest_file ");

    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = 'linuxadmin';
    $scpArgs{-hostpasswd} = 'sonus';
    $scpArgs{-scpPort} = '2024';
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$source_file;
    $scpArgs{-destinationFilePath} = $dest_file;

    # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens
    unless(&SonusQA::Base::secureCopy(%scpArgs)) {
       $logger->error(__PACKAGE__ . ".$sub_name:  SCP actfile to local server Failed");
       $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
       return 0;
    }
    my @result2 = `ls -lrt $dest_file`;
    foreach (@result2){
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($source_file) not transferred ");
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File successfully transferred!!");
        }
    }

    my $temp_file = "$dest_path" . "temp.txt";

    my $cmd1 = `tshark -V -R rtp -r $dest_file  > $temp_file`;
    my @result1 = `ls -lrt $temp_file`;
    my %rtp_frames;
    foreach (@result1){
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($temp_file) not found ");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-File Not Found; ";
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File ($temp_file) found!!");
        }
    }
    open FILE, "<", "$temp_file" or return 0;
    if ( $select_packet eq "count"){
        $logger->debug(__PACKAGE__ . ".$sub_name: Counting number of RTP packets with source IP :\'$args{-sourceip}\' and destination IP:\'$args{-destinationip}\' ");
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Performing pattern matching for the input hash ");
    }

    my @temp_frames = ();
    my $i = 1;
    my $rtp_packet = 0;
    my $target_packet = 0;
    my $rtp_packets_count = 0;
    my %cdrref = %{$args{-pattern}};
    my $sourceip = $args{-sourceip};
    my $destinationip = $args{-destinationip};
    while (my $line = <FILE>) {
	if ($line =~ /Internet Protocol, Src:\s(.*)\s.*\sDst:\s(.*)\s\(/){
        if($sourceip eq $1 and $sourceip eq $2){
            $target_packet = 1;
        } else {
            $target_packet = 0;
        }
        }
        if($line =~ /Real-Time Transport Protocol/ and $target_packet){
            $rtp_packet = 1 if($i == $select_packet);
            $i++;
            $rtp_packets_count++;
        }
	if($rtp_packet){
            push (@temp_frames, $line);
            if($line =~ /Frame/){
                $rtp_packet = 0;
            }
        }
    }
    $rtp_frames{$sourceip} = \@temp_frames;
    if ( $select_packet eq "count"){
        $logger->debug(__PACKAGE__ . ".$sub_name: Number of RTP packets for the PKT  for the source IP- destination IP pair : \'$sourceip\' - \'$destinationip\' is \'$rtp_packets_count\' ");
        my $cmd2 = `rm -rf $dest_file $temp_file`;
        return $rtp_packets_count;
    }
    my $flag1 = 0;
    my $flag = 0;   #indicates the record match
    my @cdr_record = @{$rtp_frames{$sourceip}};
    my $cdr_count = scalar(keys %cdrref);
    foreach (keys %cdrref) {
        my $input_key = $_;
        my $match = $cdrref{$input_key};
        foreach my $line (@cdr_record) {
            chomp $line;
            my @temp = split ('\s',$line);
            $line = join ('',@temp);
            $input_key =~ s/\s+//;
            $match =~ s/\s+//;
            if($line eq $input_key.":".$match){
                $logger->info(__PACKAGE__ . ".$sub_name: Matched the pattern in the RTP packet. Field : \'$input_key\' Value : \'$match\'\n ");
                $flag = 1;
                $flag1++;
            }
        }
    }

    my $cmd2 = `rm -rf $dest_file $temp_file`;
    if($flag and $cdr_count == $flag1){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->info(__PACKAGE__ . ".$sub_name: Did not match all the patterns in the RTP packet. ");
        $logger->info(__PACKAGE__ . ".$sub_name: ".Dumper(@cdr_record));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-RTP Packets Mismatch; ";
        return 0;
    }
}

=head2 C< verifySRTCP >

=over

=item DESCRIPTION:

 This subroutine checks if the Sender and receiver reports in the pcap file have SRTCP.

=item ARGUMENTS:

   mandatory
        $sbxObj :  The SBC object.
        -pcapfile :  the pcap file present in the path /root for which the verification is to be done.
  optional
    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        1                         - on success
        0                         - on failure.

=item EXAMPLE:

   unless ($result = $sbxObj->verifySRTCP( -pcapfile => "tms2305.pcap")) {
       $logger->error(__PACKAGE__ . ".$sub: SRTCP verification failed  " );
   }

=back

=cut

sub verifySRTCP {

    my ($self) = shift;
    my $sub_name = "verifySRTCP";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&verifySRTCP, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my (%args) = @_;
    $logger->info(__PACKAGE__ . ".$sub_name  Entered with args - ", Dumper(%args));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-pcapfile} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter -pcapfileis  empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


    #getting user home dir
    my $user_home = qx#echo ~#;
    chomp($user_home);

    my $source_path = "/root/";
    my $dest_path = "$user_home" . "/ats_repos/lib/perl/SonusQA/SBX5000/";
    my $finalFilename = $args{-pcapfile};
    my $source_file = "$source_path" . "$finalFilename";
    #copying the act file from SBX to local server
    # create connection
    $logger->debug(__PACKAGE__ . ".$sub_name: Transferring \'$finalFilename\' to local server");

    my $dest_file = "$dest_path" . "File.txt";
    $logger->debug(__PACKAGE__ . ".$sub_name: Source file : $source_file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: destination file : $dest_file ");

    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = 'root';
    $scpArgs{-scpPort} = '2024';
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$source_file;
    $scpArgs{-destinationFilePath} = $dest_file;

    # transfer the file, eval here helps to keep the control back with this script, if any untoward incident happens
        unless(&SonusQA::Base::secureCopy(%scpArgs)) {
            $logger->error(__PACKAGE__ . ".$sub_name:  SCP actfile to local server Failed");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    my @result2 = `ls -lrt $dest_file`;
    foreach (@result2){
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($source_file) not transferred ");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-File Not Found; ";
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File successfully transferred!!");
        }
    }

    my $temp_file = "$dest_path" . "Sender_report.txt";

    my $cmd1 = `tshark -x -c 1 -R rtcp -R "rtcp.pt == 200" -r $dest_file  > $temp_file`;
    my @result1 = `ls -lrt $temp_file`;
    foreach (@result1){
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($temp_file) not found ");
		$main::failure_msg .= "TOOLS:SBX5000HELPER-File Not Found; ";
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File ($temp_file) found!!");
        }
    }
    open FILE, "<", "$temp_file" or $logger->logwarn(__PACKAGE__ . ".$sub_name: Error while opening the filtered file : $! ");

    $logger->info(__PACKAGE__ . ".$sub_name: Checking if the sender report has SRTCP.. ");
    my @temp_frames = ();
    my $flag = 0; #sender flag
    my $flag1 = 0; # receiver flag
    my ($ipversion,$byteoffset);
    while (my $line = <FILE>) {
        if($line =~ /^\d{3}\s+\d+\.\d+\s+(.*)$/){
            if ($1 =~ /^\d+\.\d+\.\d+\.\d+\s+/){
                $ipversion = 4;
            }else{
                $ipversion = 6;
            }
        }
        my @a = split(/\s+/, $line);
        chomp @a;
        foreach my $val (@a){
            if ($val =~ /^..$/){
                push (@temp_frames, $val);
            }
        }
    }
    if($ipversion == 4){
        $byteoffset = 95;
        $logger->info(__PACKAGE__ . ".$sub_name: Protocol : IPV4 ");
    }elsif($ipversion == 6){
        $byteoffset = 115;
        $logger->info(__PACKAGE__ . ".$sub_name: Protocol : IPV6 ");
    }
    shift (@temp_frames); # Remove -> from temp_frames
    if( scalar (@temp_frames) > ($byteoffset-1) and $temp_frames[$byteoffset-1] == 80){
        $logger->info(__PACKAGE__ . ".$sub_name: Sender report has SRTCP. The value at $byteoffset th byte is: \'$temp_frames[$byteoffset-1]\' ");
        $logger->info(__PACKAGE__ . ".$sub_name: Bytes : @temp_frames ");
        $flag = 1;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Sender report does not have SRTCP. The value at $byteoffset th byte is: \'$temp_frames[$byteoffset-1]\' ");
        $logger->info(__PACKAGE__ . ".$sub_name: Bytes : @temp_frames ");
        $flag = 0;
    }
    my $cmd2 = `rm -rf $temp_file`;

    $logger->info(__PACKAGE__ . ".$sub_name: Checking if the receiver report has SRTCP.. ");
    @temp_frames = ();
    $temp_file = "$dest_path" . "Receiver_report.txt";
    $cmd1 = `tshark -x -c 1 -R rtcp -R "rtcp.pt == 201" -r $dest_file  > $temp_file`;
    @result1 = `ls -lrt $temp_file`;
    foreach (@result1){
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($temp_file) not found ");
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File ($temp_file) found!!");
        }
    }
    open FILE, "<", "$temp_file" or $logger->logwarn(__PACKAGE__ . ".$sub_name: Error while opening the filtered file : $! ");
    @temp_frames = ();
    while (my $line = <FILE>) {
        my @a = split(/\s+/, $line);
        chomp @a;
        foreach my $val (@a){
            if ($val =~ /^..$/){
                push (@temp_frames, $val);
            }
        }
    }
    shift (@temp_frames); # Remove -> from temp_frames
    if($ipversion == 4){
        $byteoffset = 75;
        $logger->info(__PACKAGE__ . ".$sub_name: Protocol : IPV4 ");
    }elsif($ipversion == 6){
        $byteoffset = 95;
        $logger->info(__PACKAGE__ . ".$sub_name: Protocol : IPV6 ");
    }
    if(scalar (@temp_frames) > ($byteoffset-1) and $temp_frames[$byteoffset-1] == 80){
        $logger->info(__PACKAGE__ . ".$sub_name: Receiver report has SRTCP. The value at $byteoffset th byte is: \'$temp_frames[$byteoffset-1]\' ");
        $logger->info(__PACKAGE__ . ".$sub_name: Bytes : @temp_frames ");
        $flag1 = 1;
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: Receiver report does not have SRTCP. The value at $byteoffset th byte is: \'$temp_frames[$byteoffset-1]\' ");
        $logger->info(__PACKAGE__ . ".$sub_name: Bytes : @temp_frames ");
         $flag1 = 0;
    }
    $cmd2 = `rm -rf  $temp_file`;
    if($flag and $flag1){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->info(__PACKAGE__ . ".$sub_name: One or both of the sender and receiver reports are not SRTCP packets ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-SRTCP Verification Failed; ";
        return 0;
    }
}

=head2 C< getCDR >

=over

=item DESCRIPTION:

    This subroutine actually uses the camDecoder.pl file (maintained in the library in the same path of SBX5000HELPER.pm) to decode the ACT file and finds the patterns for the specified keys with the output decode file.
    This API matches both the Fields and Sub-Fields in the record.

    Note:
    1. Please do 'svn up camDecoder.pl' in the same path where SBX5000HELPER.pl is stored.
    2. The camDecoder.pl file has to be checked in here each time a Clearcase build results in a new version of this file.

=item ARGUMENTS:

   Mandatory :
   1. -actfile	: ACT file (for which the records needs to be matched)
   2. -recordtype  : (Type of record to be matched ie...START, STOP etc)
   3. -cdr		: Array reference containing the list of index values that needs to be matched in the CDR.

   Optional:
   1. -returnarray : Set this to 1 if you just need the output of the camDecoder.pl for the ACT file.
   2. -append_cdr : Pass this parameter with value 1, then output is appended with the CDR values in the return array.
   3. -recordtype_number : Get the field-value pair for the passed cdr from the 'n' th found of the passed -recordtype (n-> value to be passed to -recordtype_number).

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    (1,\%returnhash)   - 1 denoting success and %returnhash is the hash containing the key and its pattern value pairs if all the values mentioned in -cdr have matching values in the output decode file)
    (0,\%returnhash)   - 0 denoting failure (even if one value in -cdr list is not found ) and  %returnhash is the hash containing the key and its pattern value pairs from the -cdr list
    if -returnarray is set to 1:
    (0,\@cdr_record)   - 0 denoting failure (even if one value in -cdr list is not found) and @cdr_record is the content of the output decode file.
    (1,\@cdr_record)   - 1 denoting success and @cdr_record is the content of the output decode file.


=item EXAMPLES:

    my ($getcdrresult,$cdr) = $self->getCDR( -actfile     => $actfile,
                                             -recordtype  => $recordtype,
                                             -cdr         => \@inputcdr,
                                             -recordtype_number => 2                 #-recordtype_number must be greater than zero
                                        );

=back

=cut


sub getCDR {
    my ($self, %args) = @_ ;
    my $sub_name = "getCDR";
    my (%returnhash);
    my ($actfile) = '';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  --> Entered sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-actfile} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-actfile' is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless($args{-returnarray}){
        unless ( $args{-recordtype} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Argument '-recordtype' is mandatory to return hash.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        unless ( $args{-cdr} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Argument '-cdr' is mandatory to return hash.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        if ( $args{-append_cdr} ) {
           $logger->info(__PACKAGE__ . ".$sub_name: Argument '-append_cdr' is passed. Hence appending the Input CDR values to return array");
        }
    }

    #checking if D_SBC,
    #By default execute only for S_SBC
    #to get the CDR for different personality of SBC, call the subroutine with appropriate object
    if ($self->{D_SBC}) {
        my $sbc_type = (exists $self->{S_SBC}) ? 'S_SBC' : 'I_SBC';
        $self = $self->{$sbc_type}->{1};
        $logger->debug(__PACKAGE__ . ".$sub_name: Executing the subroutine only for $self->{OBJ_HOSTNAME} ($sbc_type)");
    }

    $actfile = $args{-actfile};
    my $source_path = "/var/log/sonus/sbx/evlog";

    #Perform decoding on SBC
    my($cmdStatus, @cmdResults) = _execShellCmd($self->{$self->{ACTIVE_CE}},"gscripts");
    unless($cmdStatus){
        $logger->error(__PACKAGE__. ".$sub_name: Error in moving to gscripts folder");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my $cmd = "perl sbxCamDecoder.pl $source_path/$actfile > $source_path/$actfile.txt";
    ($cmdStatus, @cmdResults) = _execShellCmd($self->{$self->{ACTIVE_CE}},$cmd);
    unless($cmdStatus){
        $logger->error(__PACKAGE__. ".$sub_name: Error in executing command $cmd");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = 'root';
    $scpArgs{-scpPort} = '2024';
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$source_path/$actfile.txt";
    $scpArgs{-destinationFilePath} = "$main::log_dir/$actfile.txt";

    unless(SonusQA::Base::secureCopy(%scpArgs)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to scp $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    $cmd = "rm -f $source_path/$actfile.txt";
    ($cmdStatus, @cmdResults) = _execShellCmd($self->{$self->{ACTIVE_CE}},$cmd);
    unless($cmdStatus){
        $logger->error(__PACKAGE__. ".$sub_name: Error in executing command $cmd");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    #reading the decoded act file
    my @cdr_record;
    unless( @cdr_record = `time cat $scpArgs{-destinationFilePath}` ){
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot read $scpArgs{-destinationFilePath} or it is empty");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        if( defined $args{-returnarray} and $args{-returnarray} ){
            return (0,\@cdr_record);
        }else {
            return (0,\%returnhash);
        }
    }
    chomp @cdr_record;

    if( defined $args{-returnarray} and $args{-returnarray} ){
	    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return (1,\@cdr_record);
    }

    my @cdr = @{$args{-cdr}};
    my $recordtype = $args{-recordtype};
    my $recordtype_number = $args{-recordtype_number} || 0; 
    my ($failflag,$flag,$flag1) = (1,0,1);

    $logger->debug(__PACKAGE__ . ".$sub_name: Finding patterns for the input keys.. ");
    foreach my $inputkey ( @cdr ) {
        $failflag = 1;
        my $inputkey_append = $inputkey;
        $inputkey = ($inputkey =~ s/\./\\\./) ? $inputkey : $inputkey . '\.';           # appending "." if not present else escape "."
        my $record_number = 0;
        foreach ( @cdr_record ) {
            if ($_ =~ /^Record\s*\d*\s*'(.*)'$/) {
                if($1 eq $recordtype){
                    $record_number++;
                    $flag = 1;
                    next;
                }else{
                    $flag = 0;
                }
            }
            if ($flag && (!$recordtype_number || $record_number == $recordtype_number)){
                if ($_ =~ /^\s*$inputkey\s+(.*):\s+(.*)$/i){
                    my $ret1 = $1;
                    my $ret2 = $2;
                    $ret1 =~ s/\s+$//;
                    $ret1 = "$inputkey_append $ret1" if ($args{-append_cdr});
                    $returnhash{$ret1} = $ret2;
                    #$logger->debug(__PACKAGE__ . ".$sub_name: Found pattern '$ret1' for the input key '$inputkey'. Value : '$ret2' ");
                    $failflag = 0;
                }
            }
        }
        if ($failflag) {
            $flag1 = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Did not find pattern  for the input key '$inputkey'.");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR pattern NotFound; ";
        }
    }

    if( $flag1 ){
	$logger->debug(__PACKAGE__ . ".$sub_name: Found patterns for all the input keys ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return (1,\%returnhash);
    } else {
	$logger->error(__PACKAGE__ . ".$sub_name: Did not find patterns for all the input keys. ".Dumper(%returnhash));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-CDR pattern Mismatch; ";
        return (0,\%returnhash);
    }
}

=head2 C< getGcids >

=over

=item DESCRIPTION:

    This subroutine uses the cli to get the list of currently GCIDs and returns them in a list. (TOOLS-2810 - Add a getGcids routine to SBX5000HELPER)

=item ARGUMENTS:

 Mandatory :

 Optional:

    $mode - What mode the CLI is in. (E.G.: private)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:


=item EXAMPLES:

    my @gcidlist = $self->getGcids( );

=back

=cut

sub getGcids {
    my ($self,$mode) = @_ ;
    my $sub_name = "getGcids";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @gcids = ();

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if ($self->{D_SBC}) {
        my %hash = (
            'args' => [$mode],
            'types' => ['S_SBC']
        );

        my @retVal = $self->__dsbcCallback(\&getGcids, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[@retVal]");
        return @{values $self->{PARENT}->{GCID_DATA}};
    }

    my $cmd = 'show table global callResourceDetailStatus';
    my @output;

    ########  Execute CLI Command to get the list #########################################
    if ($mode =~m/private/) {
        $self->execCmd("configure private");
        @output = $self->execCmd($cmd);
        $self->leaveConfigureSession;
    }
    else {
        @output = $self->execCmd($cmd);
    }

    # Split output into lines
    foreach my $line (@output) {
        chomp;      # Strip new line;
        # Get the gcid from the line. First value is the gcid if it exists.
        # Check to see if the value is a number.  This will skip over the header of the output and trailing lines since they aren't numbers.
        # Regex means beginning(^) - any digits(\d+) - space - any characters
        if($self->{SBC_TYPE} eq 'S_SBC'){
            if ( $line =~ /(\S+)\((\S+)\)/ ) {
                # Append gcid and ip of msbc into the list.
                #show table global callResourceDetailStatus on the SSBC
                # RES RES CALL LEG NODE GCID AND
                # GCID INDEX ID RES TYPE ID ID IP ADDR
                # -------------------------------------------------------------------
                # 2 0 4 xresUser 2 0 2(10.54.253.159)
                # 2 1 2 aresAmq2Dsp 2 0 2(10.54.253.159)
                # 2 2 6 xresUser 2 1 2(10.54.253.159)
                push (@{$self->{PARENT}->{GCID_DATA}->{$2}},$1);
                push @gcids, $1;
            }
        } elsif ( $line =~ /^(\d+)\s+.*/ ) {
            # Append gcid into the list.
            push @gcids, $1;
        }
    }
    # Output the list of gcids that were found.
    $logger->debug(__PACKAGE__ . ".$sub_name: Found GCIDs: @gcids");
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub ");
    return @gcids;
}


=head2 C< preExecutionChecks >

=over

=item DESCRIPTION:

	This subroutine checks the prerequisites to start the SBC automation.

 Note:
	Moved the license related things to cleanStartSBX()

=item ARGUMENTS:

 Mandatory :

   NONE

 Optional:

   NONE

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:


=item EXAMPLES:

    my $checkresult = $sbxObj->preExecutionChecks();

=back

=cut

sub preExecutionChecks {
# Removed license related codes from here. check TOOLS-8905 for more info.
    my $self = shift;
    my $sub_name = "preExecutionChecks";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    my (%args) = @_;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< enableSSHviaCLI >

=over

=item DESCRIPTION:

    This subroutine is used to enable ssh via CLI for root and linuxadmin login. It calls 'sub enterLinuxShellViaDshBecomeRoot' to become root, and add linuxadmin and root to allowed users list.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 => if success
    0 => for failure

=item EXAMPLES:

    unless ($sbxObj->enableSSHviaCLI()) {
            $logger->error(__PACKAGE__ . ".$sub_name Failed to enable ssh via cli");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

=back

=cut


sub enableSSHviaCLI{
    my $self = shift;
    my $sub_name = 'enableSSHviaCLI';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ( $self->enterLinuxShellViaDshBecomeRoot ("sonus", "sonus1" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }
    my @result;
    my $try = 1;
    VERIFY_ROOTENABLED:
    my $string = "";
    unless(@result = $self->{conn}->cmd('grep "AllowUsers.*" /etc/ssh/sshd_config')){
        $logger->error(__PACKAGE__.".$sub_name Failed to grep run 'AllowUsers\.\*' /etc/ssh/sshd_config command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to EnableSsh; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: result of grep for AllowUsers.* ".Dumper(\@result));
    unless(grep /root/i, @result){
        $logger->debug(__PACKAGE__ . ".$sub_name: root need to be added to AllowUsers list");
        $string .= "root";
    }
    unless(grep /\slinuxadmin\s|\slinuxadmin\s*$/i, @result){  #should not match linuxadmin@127.0.0.1 linuxadmin@::1
        $logger->debug(__PACKAGE__ . ".$sub_name: linuxadmin need to be added to AllowUsers list");
        $string .= ($string) ? " linuxadmin" : "linuxadmin";
    }
    if($try && $string){
        $logger->info(__PACKAGE__ . ".$sub_name: Adding root to AllowUsers list.");
        $self->{conn}->cmd("sed -i -e 's/AllowUsers/AllowUsers $string/g' /etc/ssh/sshd_config; service ssh restart");
        $try--;
        goto VERIFY_ROOTENABLED ;
    }
    unless ($self->leaveDshLinuxShell) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Failed to get out of dsh linux shell.");
        return 0;
    }
    if($string){
        $logger->error(__PACKAGE__.".$sub_name Failed to enable login for $string via CLI");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to EnableSsh; ";
        return 0;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: successfully enabled SSH via CLI");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
        return 1;
    }
}

=head2 C< enableSsh >

=over

=item DESCRIPTION:

    This subroutine is used to enable ssh. Normally it will be used after the installation. It will just run the command "enableSsh" from a bmc root session.

 Note:

=item ARGUMENTS:

 Mandatory :
   -tms_alias => SBX tms alias

=item Optional:

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 => if success
    0 => for failure

=item EXAMPLES:

    unless( SonusQA::SBX5000::SBX5000HELPER::enableSsh(-tms_alias => $sbx)){
        $logger->error(__PACKAGE__ . ".$sub_name: Enabling SSH failed for $primarysbx.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub enableSsh{
        my %args = @_;
        my $sub_name = "enableSsh";
        my $bmcObj;

        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

        unless ( defined $args{-tms_alias} || defined $args{-bmc_ip}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-tms_alias' or '-bmc_ip' is missing ");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
        unless($bmcObj = &makeBmcRootSession(%args,  -sessionlog => 1)){
            $logger->error(__PACKAGE__ . ".$sub_name: Creation of bmc root session to enable ssh failed for '$args{-tms_alias}'.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }

        unless( $bmcObj->{conn}->print("enableSsh")  ) {
            $logger->error(__PACKAGE__.".$sub_name Failed to run command enableSsh");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
        my ($prematch,$match);
        unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/y\/[\[]*n/i',
                                                                -match => '/command not found/',
                                                                -errmode => "return") ) {
            $logger->error(__PACKAGE__.".$sub_name Failed to get y/n prompt after entering enableSsh");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
            $bmcObj->DESTROY;
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }

        if($match=~/command not found/){
            $logger->info(__PACKAGE__.":$sub_name command 'enableSsh' is not found. Looks like app is not installed. Nothing to do more...");
        }
        else{
            unless( $bmcObj->{conn}->print("y")  ) {
                $logger->error(__PACKAGE__.".$sub_name Failed to enter yes after running command enableSsh");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $bmcObj->DESTROY;
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => $bmcObj->{PROMPT},
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.".$sub_name Failed to get  prompt after entering enableSsh");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $bmcObj->DESTROY;
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }
        }

	unless( $bmcObj->{conn}->print('grep "AllowUsers" /etc/ssh/sshd_config')  ) {
            $logger->error(__PACKAGE__.".$sub_name Failed to grep 'AllowUsers'/etc/ssh/sshd_config");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
            $bmcObj->DESTROY;
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                    -match => $bmcObj->{PROMPT},
                                                                    -errmode => "return") ) {
                $logger->error(__PACKAGE__.".$sub_name Failed to get root after reading sshd_config");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $bmcObj->DESTROY;
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
        }

        $bmcObj->{conn}->cmd("sed -i -e 's/AllowUsers/AllowUsers root /g' /etc/ssh/sshd_config; sed -i -e 's/Subsystem/Subsystem root /g' /etc/ssh/sshd_config; service ssh restart") unless($prematch =~ /root/);

        $logger->debug(__PACKAGE__ . ".$sub_name: Added root to AllowUsers in sshd_config");

        my $cnt;
WAITFOR_ROOT:
        #exiting from bash
	    $bmcObj->{conn}->print("exit");

        unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/login:/i',
                                                                -match => '/root\@.+\# $/i',
                                                                -match => '/linuxadmin\@.+(#|\$) $/',
                                                                -match => $bmcObj->{PROMPT},
                                                                -errmode => "return") ) {
            $logger->error(__PACKAGE__.".$sub_name Failed to get root after 'exit'");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
            $bmcObj->DESTROY;
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }

        unless($match=~/login:/i){
            $cnt++;
            if($cnt > 5){ #for safer side
                $logger->error(__PACKAGE__.".$sub_name Couldn't to get login prompt after 'exit' ($cnt times)");
                $bmcObj->DESTROY;
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }

            $logger->info(__PACKAGE__ . ".$sub_name: got match ($match) again. So sending one more 'exit' ($cnt)");
            goto WAITFOR_ROOT;
        }

        $bmcObj->DESTROY;
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
        return 1;
}

=head2 C< makeBmcRootSession >

=over

=item DESCRIPTION:

    This subroutine is used to make a BMC root session. It returns BMC root object if its success.
    (Refer TOOLS-3608 for more information).

 Note:

=item ARGUMENTS:

 Mandatory :
   -bmc_ip => BMC ip of SBC
    or
    -tms_alias => tms alias of SBC

 Optional:
    -sessionlog => 1- if need to enable session log, 0- if not
    -bmc_root_password => password for bmc root login. Default is .superuser'.
                          This will be used if -bmc_ip is passed, else will get from tms alias ({BMC_NIF}->{1}->{ROOTPASSWD})

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    $bmcObj => BMC root object if its success
    0       => if its fail

=item EXAMPLES:

    unless($bmcObj = SonusQA::SBX5000::SBX5000HELPER::makeBmcRootSession(-tms_alias => $args{-tms_alias})){
        $logger->error(__PACKAGE__ . ".$sub_name: Creation of bmc root session failed for '$args{-tms_alias}'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

=back

=cut

sub makeBmcRootSession{
        my %args = @_;
        my $sub_name = "makeBmcRootSession";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");
        if( !defined $args{-bmc_ip} and !defined $args{-tms_alias} ){
                $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-tms_alias' or '-bmc_ip' is missing. (Atleast 1 of these argument is required ) ");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
                return 0;
        }
        my ($sbxObj,$bmchostname,$bmcObj,$sessionlog);
        my $rootpassword = "sonus1";
        my %a = ( -obj_user => 'root', -comm_type => 'SSH', -obj_port => 22, -defaulttimeout => 10, -obj_password => 'superuser', -return_on_fail => 1);
        $a{-sessionlog} = (defined $args{-sessionlog} ) ? 1 : 0 ;

        if( defined $args{-bmc_ip} ) {
            $a{-obj_host} = $args{-bmc_ip};
            $a{-obj_password} = $args{-bmc_root_password} if($args{-bmc_root_password});
            $bmcObj = SonusQA::TOOLS->new(%a);
        }else{
            $sbxObj = SonusQA::Utils::resolve_alias($args{-tms_alias});
            $rootpassword = $sbxObj->{LOGIN}->{1}->{ROOTPASSWD} if($sbxObj->{LOGIN}->{1}->{ROOTPASSWD});
            $a{-obj_password} = $sbxObj->{BMC_NIF}->{1}->{ROOTPASSWD} if($sbxObj->{BMC_NIF}->{1}->{ROOTPASSWD});
            # Below if loop(Chassis power status) is added as per TOOLS-8329
            $bmchostname = (defined $sbxObj->{BMC_NIF}->{1}->{IP}) ? $sbxObj->{BMC_NIF}->{1}->{IP} : $sbxObj->{NODE}->{1}->{HOSTNAME}."-man.eng";
            my $out =`ipmitool -H $bmchostname -I lanplus -U root -P $a{-obj_password} chassis power status`;
            $logger->info(__PACKAGE__.":$sub_name $bmchostname:  $out");
            chomp($out);
            if($out =~/Chassis Power is off/){
                $out=`ipmitool -H $bmchostname -I lanplus -U root -P $a{-obj_password} chassis power on`;
                chomp($out);
                if($out =~/Chassis Power Control: Up\/On/){
                    $logger->info(__PACKAGE__.":$sub_name Waiting 120 seconds after Chassis Power on");
                    sleep(120);
                }
            }

	    if ( defined $sbxObj->{BMC_NIF}->{1}->{IP} ) {
                $a{-obj_host} = $sbxObj->{BMC_NIF}->{1}->{IP};
                $logger->info(__PACKAGE__.":$sub_name Trying to connect to BMC using BMC ip, ". $a{-obj_host});
                $bmcObj = SonusQA::TOOLS->new(%a);
            }

	    unless ( $bmcObj ) {
                $logger->warn(__PACKAGE__.":$sub_name Failed to connect to BMC using bmc ip, ".$sbxObj->{BMC_NIF}->{1}->{IP} )  if ( defined $sbxObj->{BMC_NIF}->{1}->{IP} );
                $bmchostname = $sbxObj->{NODE}->{1}->{HOSTNAME}."-man";
                $a{-obj_host} = $bmchostname;
                $logger->info(__PACKAGE__.":$sub_name Trying to connect to BMC using hostname, $bmchostname");
                $bmcObj = SonusQA::TOOLS->new(%a);
            }
        }

        unless ( $bmcObj ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to connect to BMC");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
        }

        #killing 'solssh' process if its running
        my @cmdRes = $bmcObj->execCmd('ps -ef | grep solssh');

        # possible outputs of 'ps -ef | grep solssh' :
        # root     18875 18827  1 08:52 pts/0    00:00:00 solssh
        #       or
        # 26277 root        768 S   solssh
        # 26291 root        452 S   grep solssh

        my ($ps) = grep { /solssh/ && !/grep solssh/ } @cmdRes;

        if ( $ps=~/^[a-z]*\s*(\d+).*/i ){
            $logger->debug(__PACKAGE__.":$sub_name Killing the running 'solssh' process, $ps. cmd: kill -9 $1");
            $bmcObj->execCmd("kill -9 $1");
        }

        # remove '/tmp/solsessionactive1' file, if its existing
        $logger->debug(__PACKAGE__.":$sub_name Removing /tmp/solsessionactive1 file, if its existing. ");
        $bmcObj->execCmd("rm -f /tmp/solsessionactive1");

        $logger->debug(__PACKAGE__.":$sub_name Running command 'solssh' ");
        unless( $bmcObj->{conn}->print("solssh") ){
                $logger->error(__PACKAGE__.":$sub_name Failed to run solssh");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to run solssh; ";
                return 0;
        }
        my ($prematch,$match);
        unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                               ## -match => '/Hit <Enter><Esc>t to exit solssh/i',
                                                                -match => '/Hit \<Enter\>/i',
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get login prompt after entering solssh ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
        }
        unless ( $match =~ $bmcObj->{PROMPT} ) {
		my $try = 0;
		$logger->info(__PACKAGE__ . ".$sub_name pressing <Enter>");
                $bmcObj->{conn}->print("");
WAITFOR_LOGIN:
                unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/login:/i',
                                                                -match => $bmcObj->{PROMPT},
                                                                -match => '/root\@.+# $/',
                                                                -match => '/linuxadmin\@.+(#|\$) $/',
                                                                -match => '/password for linuxadmin:/',
                                                                -match => '/: empty buffer/',
                                                                -timeout => 60,
                                                                -errmode => "return") ) {
			$logger->error(__PACKAGE__.":$sub_name Failed to get 'login:' or 'root' prompt with 60 seconds.");
			unless($try > 2){
                                $try++;
                                $logger->info(__PACKAGE__.":$sub_name pressing <Enter>, and trying ($try) again");
                                $bmcObj->{conn}->print("");
                                goto WAITFOR_LOGIN;
                        }
        	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
	                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                        $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
                        return 0;
                }
        }


	    if($match=~/empty buffer/){
                $logger->info(__PACKAGE__.":$sub_name we got 'empty buffer' message. So entering 'exit'.");
                $bmcObj->{conn}->print("exit");
                goto WAITFOR_LOGIN;
	    }
        elsif($match =~ /login:/){
            $logger->debug(__PACKAGE__.":$sub_name Matched login prompt. Trying to login as linuxadmin ");
            $bmcObj->{conn}->print("linuxadmin");

            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/Password:/i',
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get password prompt after entering 'linuxadmin'");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
            }

            $bmcObj->{conn}->print("sonus");
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/linuxadmin\@.+(#|\$) $/',
                                                                -match => $bmcObj->{PROMPT},
                                                                -match => $bmcObj->{DEFAULTPROMPT},
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get prompt after entering linuxadmin  password:  sonus");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
            }

            $bmcObj->{conn}->print("su root");
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/Password:/i',
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get password prompt after entering 'root'");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
            }

            $bmcObj->{conn}->print($rootpassword);
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/root.*/',
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get prompt after entering root password ($rootpassword)");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
            }
        }elsif($match =~/password for linuxadmin:/){
            $logger->debug(__PACKAGE__.":$sub_name Matched login prompt. Trying to login as linuxadmin ");
            $bmcObj->{conn}->print("sonus");
            unless( ($prematch,$match)  = $bmcObj->{conn}->waitfor(
                                                                -match => '/linuxadmin\@.+(#|\$) $/',
                                                                -match => $bmcObj->{PROMPT},
                                                                -errmode => "return") ) {
                $logger->error(__PACKAGE__.":$sub_name Failed to get prompt after entering root password ($rootpassword)");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $bmcObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $bmcObj->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-BMC login Failed; ";
                return 0;
            }


        }else{
            $logger->debug(__PACKAGE__.":$sub_name Did not prompt for login ");
        }

        $logger->debug(__PACKAGE__.":$sub_name calling setSystem() to set the prompt");
        $bmcObj->setSystem();

        $logger->debug(__PACKAGE__.":$sub_name Logged in as root successfully");
        $logger->debug(__PACKAGE__ . ":$sub_name <-- Leaving Sub [1]");
        return $bmcObj;
}

=head2 C< decodeGatewayMsg >

=over

=item DESCRIPTION:

 This subroutine is used to decode gateway messages using a tool called GwDecoderTest  , present in SBC.

=item ARGUMENTS:

   -pcapfilname     : name of the .pcap file .
   -pcapfilepath    : Path to store .pacap file , default path will /tmp.
   -decodertoolpath : Path to decoder tool GwDecoderTest.

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

        on Success      mcsDecodeCPC_MEDIA_ADDR_STR:Decoding sin_family
                        mcsDecodeUSHORT: 0x3738: 2(0x2)
                        mcsDecodeCPC_MEDIA_ADDR_STR:Decoding sin_port
                        mcsDecodeUSHORT: 0x373a: 7030(0x1b76)
                        mcsDecodeCPC_MEDIA_ADDR_STR:Decoding s_addr
                        mcsDecodeCPC_MEDIA_ADDR_STR_S_ADDR:Decoding in_addr
                        mcsDecodeIN_ADDR:Decoding in_addr
                        mcsDecodeULONG: 0x373c: 171322946(0xa362e42)
                        mcsDecodeMCS_AUDIO_PARAMS_STR:Decoding rtpPayloadTypes
                        mcsDecodeMCS_RTP_PAYLOAD_STR:Starting

        On Failure      0

=item EXAMPLES:

    my $checkresult = $sbxObj->decodeGatewayMsg(-pcapfilname => 'GwCall.pcap',
                                                -pcapfilepath => '/tmp/sonus/',
                                                -decodertoolpath => '/tmp/GwDecoderTest' );

=back

=cut

sub decodeGatewayMsg{
        my ($self, %args) = @_ ;
        my $sub_name = "decodeGatewayMsg";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

        unless ( $args{-pcapfilname} ) {
                 $logger->debug(__PACKAGE__ . ".$sub_name: '-pcapfilename' is mandatory argument .");
                 $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                 return 0;
        }

        unless ( $args{-pcapfilepath} ) {
                 $logger->debug(__PACKAGE__ . ".$sub_name: '-pcapfilepath' is empty or blank, Saving it in path '/tmp/'.");
                 $args{-pcapfilepath} = '/tmp/';
        }

        unless ( $args{-decodertoolpath} ) {
                 $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-decodertoolpath' is empty or blank.");
                 $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                 return 0;
        }

        my ($prematch, $match);
        #my $source_file =$args{-pcapfilepath} ne "" ? $args{-pcapfilepath} :  "/tmp/GwCall.pcap";

        my $cmd = "tshark -i any -w ".$args{-pcapfilepath}."/".$args{-pcapfilname};
        unless( $self->{conn}->print($cmd) ){
                $logger->error(__PACKAGE__ . ".$sub_name: Unable to enter the command \'$cmd\' ");
                $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to decode GatewayMsg; ";
                return 0;
        }

        unless(($prematch, $match) = $self->{conn}->waitfor(-match     => $self->{PROMPT}, -timeout   => 180)){
                $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to get prompt ");

        }

        $cmd = "cp $args{-decodertoolpath}/GwDecoderTest  $args{-pcapfilepath}";

        unless( $self->{conn}->print($cmd) ){
                $logger->error(__PACKAGE__ . ".$sub_name: Unable to execute the command \'$cmd\' ");
                $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to decode GatewayMsg; ";
                return 0;
        }

        unless(($prematch, $match) = $self->{conn}->waitfor(-match     => $self->{PROMPT}, -timeout   => 180)){
                $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to get prompt ");

        }

        $cmd ="./GwDecoderTest -d --noping --pcapout ".$args{-pcapfilname};
         unless( $self->{conn}->print($cmd) ){
                $logger->error(__PACKAGE__ . ".$sub_name: Unable to execute the command \'$cmd\' ");
                $logger->error(__PACKAGE__ . ".$sub_name: $cmd unsuccessful ");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to decode GatewayMsg; ";
                return 0;
        }

        unless(($prematch, $match) = $self->{conn}->waitfor(-match     => $self->{PROMPT}, -timeout   => 180)){
                $logger->debug(__PACKAGE__ . ".$sub_name:  Failed to get prompt ");

        }

        unless($prematch eq ''){
             $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
             return $prematch;
        }else{
              $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to decode GatewayMsg; ";
              return 0;
        }


}

=head2 C< initPSXObject() >

=over

=item DESCRIPTION:

   To collect the PSX logs in ATS when External PSX is used in SBC.
 call the initPSXObject subroutine in the Feature file.
 PSX logs such as pes,scpa,pgk etc., should be mentioned in PSX_LOGS in testsuiteList.pl file (i.e)TESTSUITE->{PSX_LOGS}=['pes'];

=item Arguments :

   Mandatory :

      $psxObjRef = PSX Object reference (i.e) $TESTBED{ "psx:1:ce0" }

   Optional :

      None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

	SonusQA::ATSHELPER::newFromAlias

=item OUTPUT:

    None

=item Example :

   $sbxObj->initPSXObject($TESTBED{ "psx:1:ce0" });

=back

=cut

sub initPSXObject {
    my ($self,@psxObjRef) = @_;
    my $sub_name = "initPSXObject()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__.".Entered $sub_name");
    foreach my $psxRef (@psxObjRef)#TOOLS-20632
    {
      push (@psxObj, SonusQA::ATSHELPER::newFromAlias(-tms_alias => $psxRef,-usemgmt => $self->{USE_MGMT_PSX}));#TOOLS-71557 Use mgmt port instead of signalling on Slave PSX.
    }

    $logger->info(__PACKAGE__.".PSX Found");
    # PSX log with Enabling option
    my %set_level=( pes     => { cmd => "ssmgmt",
                                 opt => ['14','1','3','5','0'] },
                    scpa    => { cmd => "scpamgmt",
                                 opt => ['1','4','6','3'] },
                    sipe    => { cmd => "sipemgmt",
                                 opt => ['1','3','5'] },
                    slwresd => { cmd => "slwresdmgmt",
                                 opt => ['1','1','3','5'] },
                    ada     => { cmd => "adamgmt",
                                 opt => ['1','4'] },
                    pgk     => { cmd => "pgkmgmt",
                                 opt => ['3','4'] },
                  );
   # Enable logging if logs are to be collected
  my @log;#TOOLS-20632
  $self->{PSX_LOGS} ||= $main::TESTSUITE->{PSX_LOGS}; 
  for my $i (0..scalar(@psxObj)-1){
    if (ref @{$self->{PSX_LOGS}}[$i] eq 'ARRAY'){
      @log = @{$self->{PSX_LOGS}->[$i]};
    }
    else{
      @log = @{$self->{PSX_LOGS}};
    }
   foreach my $log_file (@log){
     unless(exists ($set_level{$log_file})){
       $logger->error(__PACKAGE__ . ": .$log_file . is an invalid PSX log type !!!  ");
       next;
     }
     unless ($psxObj[$i]->set_loglevel($set_level{$log_file}{cmd}, $set_level{$log_file}{opt}) ){
     $logger->error(__PACKAGE__ . ".$sub_name: FAILED TO ENABLE $log_file log. Please set the appropriate logging level for $log_file log manually.");
    }
    }
  }
 }


=head2 C< generateLicense() >

=over

=item DESCRIPTION:

    To generate and install SBC license.
    - Generate the xml in ats (/tmp/sonusLicense.xml) using runTransform.jar
    - Scp it to /external/license.xml both active and stand by SBC
    - Install using licenseFileTool if option passed
    - Else copy /external/license.xml to /opt/sonus/sbx/tailf/var/confd/cdb/ in both active and stand by SBC and do clean start.

=item Arguments :

   Mandatory :

      none

   Optional :

	-licenseTool = to use license bundle
	-file_name   = generate a license file with the user prefered license's
	-host_id1    = host id of the standalone/ active SBC
	-host_id2    = host id of the Standby
	-skip_cleanstart  = if value is 1, skip the cleanStartSBX( ) call. (check cleanStartStandAloneSBX() for usage).
        -bundle_name = Name of the bundle.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::cleanStartSBX

=item OUTPUT:

    0   - fail
    1   - success

=item Example :

    $sbxObj->generateLicense();

    $sbxObj->generateLicense(-licenseTool => 1,-file_name => 'lic_template', -host_id1 => '0000000000', -host_id2 => '1111111111', -bundle_name => 'li_license'); # TOOLS-6317  TOOLS-16711

=back

=cut

sub generateLicense {
    my $self = shift;
    my $sub_name = "generateLicense()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__.".Entered $sub_name");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $result = $self->__dsbcCallback(\&generateLicense, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$result]" );
        return $result;
    }
    my $obj = $self ;

    my %args =@_;
    $args{-bundle_name} ||= 'b1';#TOOLS-16711

    my $opt; #TOOLS-76310
    $opt = ($args{-file_name} =~ /xml/) ? " -f $args{-file_name} " : " -i $args{-file_name} " if($args{-file_name});
    my ($flag, @license_files);

        my $i = @{$obj->{CHASSIS_SERIAL_NUMBERS}} ;
        map{ $opt .= " -$_  $obj->{CHASSIS_SERIAL_NUMBERS}->[$_-1]"  } 1..$i ;

        $opt .= ' -o' unless($obj->{CLOUD_SBC});#Fix for TOOLS-10317
        $opt .= ' -l' if($args{-licenseTool} || $obj->{AWS_LICENSE});
        $opt .= ' -d -l' if($args{-nwdl});#TOOLS-20303
        push @license_files, 'sonusLicense_'. time . '.xml';
        my $cmd = "export MARLIN_ROOT=/ats/tools/SbcLicenseJar/marlin; java -jar /ats/tools/SbcLicenseJar/orca/runTransform.jar $opt localhost $license_files[-1] /tmp dummy";
        $cmd .= " dummy1" if($i == 2);

        $logger->debug(__PACKAGE__ . ".$sub_name:  The Framed cmd is $cmd ");
        my $result= `bash -c '$cmd'`;
        $logger->debug(__PACKAGE__ . ".$sub_name: output of CMD is $result");

        unless(-e "/tmp/$license_files[-1]"){
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error generating License; ";
            $logger->error(__PACKAGE__ . ".$sub_name: Unable to generate license (/tmp/$license_files[-1]). CMD : [bash -c '$cmd']");
            $logger->debug(__PACKAGE__ . ".$sub_name: output of CMD is $result");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $flag = 0;
        my %scp_args = (
            -hostuser => 'linuxadmin',
            -hostpasswd => 'sonus',
            -scpPort => '2024',
            -sourceFilePath => "/tmp/$license_files[-1]",
        );

        if($args{-licenseTool} ){
            $scp_args{-hostip} = $obj->{$obj->{ACTIVE_CE}}->{OBJ_HOST};
            $scp_args{-destinationFilePath} = "$obj->{$obj->{ACTIVE_CE}}->{OBJ_HOST}:/home/linuxadmin/sonusLicense.xml";

            unless(&SonusQA::Base::secureCopy(%scp_args)) {
                $logger->error(__PACKAGE__ . ".$sub_name:  SCP sonusLicense.xml to $obj->{$obj->{ACTIVE_CE}}->{OBJ_HOST} failed");
                $flag = 1;
            }
            $result= `cd /tmp; rm @license_files`;
            if($flag){
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            my ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$obj->{ACTIVE_CE}}, "/opt/sonus/sbx/bin/licenseFileTool delete $args{-bundle_name}",60);
            unless($cmdStatus){
                $logger->error(__PACKAGE__ . ".$sub_name: Deletion of Licensebundle Failed ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$obj->{ACTIVE_CE}},"/opt/sonus/sbx/bin/licenseFileTool install $args{-bundle_name} /home/linuxadmin/sonusLicense.xml");
            unless($cmdStatus){
                $logger->error(__PACKAGE__ . ".$sub_name: License Installation Failed  ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        #TOOLS-19937
        elsif ($obj->{AWS_LICENSE}){
          $scp_args{-hostip} = $obj->{OBJ_HOST};
          $scp_args{-destinationFilePath} = "$obj->{OBJ_HOST}:/opt/sonus/external/sonusLicense.xml";
          $scp_args{-identity_file} = $obj->{OBJ_KEY_FILE};

          unless(&SonusQA::Base::secureCopy(%scp_args)) {
              $logger->error(__PACKAGE__ . ".$sub_name:  SCP sonusLicense.xml to $obj->{OBJ_HOST} failed");
              $flag = 1;
          }
          $result= `cd /tmp; rm @license_files`;
          if($flag){
              $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
              return 0;
          }
          unless($obj->execSystemCliCmd("request system admin $obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} license loadLicenseFile bundleName $args{-bundle_name} fileName sonusLicense.xml"))
          {
            $logger->error(__PACKAGE__ . ".$sub_name: Installation of license through execSystemCliCmd FAILED");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]" );
            return 0;
          }

        }
        #TOOLS-20303
        elsif($args{-nwdl}){
          unless($obj->enterPrivateSession() && $obj->execCommitCliCmd("set system licenseMode mode domain") && $obj->leaveConfigureSession()){
            $logger->error(__PACKAGE__ . " $sub_name: unable to set License Mode.");
            $result= `cd /tmp; rm @license_files`;
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
          }

            $scp_args{-hostip} = $obj->{OBJ_HOST};
            $scp_args{-destinationFilePath} = "$obj->{OBJ_HOST}:/opt/sonus/external/sonusLicense.xml";

            unless(&SonusQA::Base::secureCopy(%scp_args)){
                $logger->error(__PACKAGE__ . ".$sub_name:  SCP sonusLicense.xml to $obj->{OBJ_HOST} failed");
                $flag = 1;
            }
            unless($flag) {
                $scp_args{-sourceFilePath} = "/tmp/$1" if $result =~/\/tmp\/(\S+)$/; #Fetching the Auth token file for authentication of NWDL license. example: sonusLicense_<date>AuthToken.xml
                push @license_files, $scp_args{-sourceFilePath};
                $scp_args{-destinationFilePath} = "$obj->{OBJ_HOST}:/opt/sonus/external/sonusAuth.xml";
                unless(&SonusQA::Base::secureCopy(%scp_args)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  SCP sonusLicense.xml to $obj->{OBJ_HOST} failed");
                    $flag = 1;
                }
            }
            $result= `cd /tmp; rm @license_files`;
            if($flag){
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }

            my ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$obj->{ACTIVE_CE}},"/opt/sonus/sbx/bin/licenseFileTool install $args{-bundle_name} /opt/sonus/external/sonusLicense.xml");
            $logger->info(__PACKAGE__.".$sub_name:     INSTALL COMMAND:          --> @cmdResult");
            my $license_already_exists ;
            unless ($cmdStatus) {
                if (grep (/license bundle b1 already exists/, @cmdResult)) {
                    $logger->info(__PACKAGE__ . ".$sub_name:  license bundle b1 already exists");
                    $license_already_exists = 1;
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name: License Installation Failed  ");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }

            unless ($license_already_exists) {
                my $adminPwd = $obj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};#Fetching admin password from TMS_ALIAS for curl command.
                ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$obj->{ACTIVE_CE}},"curl -k -uadmin:$adminPwd https://localhost/api/config/license -XPOST -H \"Content-type: application/vnd.yang.data+xml\" --data @/opt/sonus/external/sonusAuth.xml"); #Running command to authenticate the installed license.
                $logger->info(__PACKAGE__.".$sub_name:     CURL COMMAND:          --> @cmdResult");
                unless($cmdStatus){
                    $logger->error(__PACKAGE__ . ".$sub_name: License Installation Failed  ");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        else{
            foreach my $ce (@{$obj->{ROOT_OBJS}}){
                $scp_args{-hostip} = $obj->{$ce}->{OBJ_HOST};
                $scp_args{-destinationFilePath} = "$obj->{$ce}->{OBJ_HOST}:/home/linuxadmin/sonusLicense.xml";

                unless(&SonusQA::Base::secureCopy(%scp_args)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  SCP sonusLicense.xml to $obj->{$ce}->{OBJ_HOST} failed");
                    $flag = 1;
                    last;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: rm -f /opt/sonus/sbx/tailf/var/confd/cdb/sonusLicense.xml on $obj->{$ce}->{OBJ_HOST}");
                my ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$ce},'rm -f /opt/sonus/sbx/tailf/var/confd/cdb/sonusLicense.xml');

                $logger->debug(__PACKAGE__ . ".$sub_name: cp /home/linuxadmin/sonusLicense.xml /opt/sonus/sbx/tailf/var/confd/cdb/ on $obj->{$ce}->{OBJ_HOST}");
                ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$ce},'cp /home/linuxadmin/sonusLicense.xml /opt/sonus/sbx/tailf/var/confd/cdb/');
                unless($cmdStatus){
                    $logger->error(__PACKAGE__ . ".$sub_name: cp /home/linuxadmin/sonusLicense.xml /opt/sonus/sbx/tailf/var/confd/cdb/ failed on $obj->{$ce}->{OBJ_HOST}");
                    $flag = 1;
                    last;
                }
                last if($obj->{PARENT}->{NK_REDUNDANCY}); # No need to do for CE1LinuxObj in case of NK
            }
            $result= `cd /tmp; rm @license_files`;
            if($flag){
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }

    unless($args{-licenseTool} == 1 || $args{-skip_cleanstart} == 1 || $args{-nwdl}){
        unless($self->cleanStartSBX( '','',0)){
            $logger->error(__PACKAGE__ . " Cannot execute the cleanStartSBX routine  , after copying license");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]" );
    return 1;
}

=head2 C< enableInfoLevelLogging >

=over

=item DESCRIPTION:

    This subroutine checks the status of 'Info level logging'.
 If 'Info level logging' is Disabled,then it will enable.

=item ARGUMENTS:

    NONE

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    NONE

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($sbx_object->enableInfoLevelLogging) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not enable Info Level Logging");
        return 0;
    }

=back

=cut

sub enableInfoLevelLogging {
    my $self = shift ;
    my (@debug_status,$flag) ;
    my $sub_name = "enableInfoLevelLogging";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    RECHECK:
    unless ( @debug_status =  $self->execCmd('show table oam eventLog typeStatus debug')) { #Running 'show table oam eventLog typeStatus debug' to check the status of 'Info level logging'.
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to executed 'show table oam eventLog typeStatus debug'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . " $sub_name:   Successfully executed 'show table oam eventLog typeStatus debug'.");
    if ( $debug_status[-2] =~ /infoLevelLoggingDisabled\strue\;$/i){ # if 'Info level logging' was disabled i.e true ,then will need to enable it.
        $logger->debug(__PACKAGE__ . ".$sub_name: Info level logging was found to be Disabled ");
	if ( $flag ){
            $logger->error(__PACKAGE__ . " $sub_name:   Failed in Recheck ,while trying to Enable 'Info Level Logging'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Enable Info Level Logging; ";
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: going to Enable the Info level logging Debug ");

        unless (  $self->execCmd('request oam eventLog infoLevelLoggingEnable clearInfoLevelLoggingDisabled')){ # Running 'request oam eventLog infoLevelLoggingEnable clearInfoLevelLoggingDisabled' to enable the 'Info level logging'.
            $logger->error(__PACKAGE__ . " $sub_name:   Failed to executed 'request oam eventLog infoLevelLoggingEnable clearInfoLevelLoggingDisabled'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Enable Info Level Logging; ";
            return 0;
        }
	$logger->debug(__PACKAGE__ . " $sub_name:   Successfully executed 'request oam eventLog infoLevelLoggingEnable clearInfoLevelLoggingDisabled'.");
	$flag = 1;
        $logger->debug (__PACKAGE__ . " $sub_name: Set the Flag and Rechecking the Info Level Logging ");
	goto RECHECK;
    }
    $logger->debug (__PACKAGE__ . " $sub_name: Info Level Logging is in Enable state .");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< parseSippMessages >

=over

=item DESCRIPTION:

 Parse a SIPP message log into its component messages and return an array of messages.

 In order for this routine to work the script MUST be started with a -trace_msg flag so the message log is created.  Since the log files are written into the directory where the scripts are written the permissions for that directory should allow creation of the logs.

 The log file is NOT removed once the parsing is done.   This helps in going back and looking at the results.   So it is a good idea to put in a line in the script start that removes all the old log files.   This prevents the directory from filling up with old log files.

=item Inputs:

    sippPtr                 Handle to the SIPP object that ran this script.
    sippScriptName          Input script name WITHOUT the .xml extension.

=item Output:

    @messages               A array of arrays to the parsed out messages.
                            For example if there were 2 messages in the log file then the array would have 2 entries and each would contain a list of the lines
                            for that message.

=item EXAMPLE:

    1) Make sure directory with the scripts has write permissions.
    2) In the setup of the sipp handle it is a good idea to clean old log files from the previous runs
        $testtool_sipp1->execCmd("cd $SIPPPATH");
        $testtool_sipp1->execCmd("rm -f *.log");

 Example routine that runs a script then checks a message for a valid sdp.

    $sippScriptNameCalled = "myScriptName"

    # Run the script and wait for it to complete.

    # Parse the results into messages.
    @messages  = QATEST::SBX5000::V05_01::testUtils::parseSippMessages ($testtool_sipp1, $sippScriptNameCalled);

    # Validate the SPD in the first message.
    my @testData = (["INVITE", "application/sdp"],          # The header include the word INVITE and a sdp indicator
                    ["m=audio", "a=mid:audio", "!a=rtcp-mux"],   # The audio section include a a=mid:audio but should not include a rtcp-mux line
                    ["m=video", "a=mid:video", "!a=rtcp-mux", "a=content:main"]);   The next media is video and should contain a main content indicator.

    @firstMessage = @{$messages[0]};
    $result = verifySdp (\@firstMessage, \@testData);

=back

=cut

sub parseSippMessages {
    my ($sippPtr, $scriptName) = @_;
    my $sub = "parseSippMessages";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my @messages;
    my @msgLines = [];
    my @logLines;
    my $msgIdx = -1;
    my $lineIdx = 0;
    my $direction;
    my $msgTime;

    # Create file name from the script.  Note that the name does not include the .xml extension
    # Need to use a wildcard for the PID since it isn't know when running in single shot mode.
    my $fileName =  "$scriptName\_*\_messages.log";
    @logLines  = $sippPtr->{ conn }->cmd( String => "cat $fileName" );
    my $lineCnt;
    if ($lineCnt == 1)
    {
        $logger->info(__PACKAGE__. "$sub: Failed to find log at $fileName." );
	$main::failure_msg .= "TOOLS:SBX5000HELPER-$fileName not Found; ";
    }

    $logger->info(__PACKAGE__. "$sub: Parsing SIPP Messages from $fileName, Line Count: $lineCnt" );

    # Walk the lines in the output and look for the segmentation lines
    foreach my $curLine (@logLines) {
        $lineIdx = $lineIdx + 1;
        # Look for separator and get the message time.
        if ( $curLine =~ m/\----------------------------------------------- \S* (\S*).*/ ) {
            # Found a separator line, so push previous message into array and move to next message
            # Starts with a separator, so skip the first push.
            $msgTime = $1;                          # Save time from regex for debug.
            if ($msgIdx != -1) {
                # Append array to list.
                push @messages, [ @msgLines ];
            }
            # Increment to next message and reset the array of line for the message.
            $msgIdx = $msgIdx + 1;
            @msgLines = [];
        }
        # Determine the direction - this is for debug output only.
        if ( (index $curLine, "sent") != -1 ) {
            $direction = "Tx";
        }
        elsif ( (index $curLine, "received") != -1 ) {
            $direction = "Rx";
        }
        # For debug output the message types by matching for a SIP/2.0 but not a VIA
        # This should give the header line for the message.
        elsif ( ((index $curLine, "SIP/2.0") != -1 ) && ((index $curLine, "Via") == -1 )) {
            #Output a message summary line to the log that includes the time, directions and the first message line.
            $logger->info(__PACKAGE__. "$sub: Message $msgIdx, $direction, $msgTime, Header: $curLine" );
        }
        # Push this line into the array of lines for this message.
        # Keep the separator line in with the message in case someone wants to check for "send" or "received"
        push @msgLines, $curLine;
    }
    # Push the last message into the array since the logs doesn't end with a separator.
    push @messages, [ @msgLines ];
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return @messages;
}

=head2 C< validateSdp >

=over

=item DESCRIPTION:

 Validate a SDP.

 The routine is passed in a message and a set of test patterns to check against.   A ! at the beginning of the test pattern means that this pattern should NOT be present in the SDP section and it is a failure if it is found.   Using the ! pattern can be used to check that attributes that were supposed to be stripped are still there.   Since the routine will walk the SDP for every pattern, two patterns can be used for the same line.

 For example : pattern #1 might be "m=audio" and check that the audio line is present and pattern # might be "0 4 9" meaning that codecs G711, G723, and G722 should be present.

 The sections are defined by "m=" lines.  So the first set of patterns will only be checked against the message lines before the first "m=" line then the second set will be checked against the line in the first media section, etc.   Using it allows for checking that strings that might be found more that once (i.e. a=rtcp-mux) are only found in right media sections of the SDP.
 Since the routine is pretty generic it could also be used to validate the SIP headers, in that case all the test patterns would need to be in section #1 since it my never find the "m=" lines.

=item ARGUMENTS:

    sdp            Reference to the message lines.
    testData       Reference to patterns to look for,  Input is a sequence of test strings in a list of lists.  With a ! meaning that this string should not exist.
                    Session Section  (("a=group:BUNDLE", "!b=TIAS"),            These value should either exist or not exist in the session level
                    Media 1 Section ("m=audio","a=mid:audio", "!a=mid:1"),      These values should either exist or not exit in the first media level
                    Media 2 Section ("m=video","a=mid:audio", "!a=mid:1"),)

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Output:

    1 = All verifications passed
    0 = At least one verification failed.   If the test fails it will output the message to the log.

=item Example:

    Typically the message would be set using the parseSippMessage which will break a SIPP log into messages.
    my @testMessage = ( "a=group:BUNDLE audio video",
                        "m=audio 6000 RTP/AVP 0",
                        "a=mid:audio",
                        "m=video 7000 RTP/AVP 31",
                        "a=mid:video");

    my @testData = (["INVITE", "application/sdp"],               # The header includes the word INVITE and a sdp indicator
                    ["m=audio", "a=mid:audio", "!a=rtcp-mux"],   # The audio section include a a=mid:audio but should not include a rtcp-mux line
                    ["m=video", "a=mid:video", "!a=rtcp-mux", "a=content:main"]);   The next media is video and should contain a main content indicator.

    $result = verifySdp (\@testMessage, \@testData);

=back

=cut

sub verifySdp {
    my ($sdpRef, $patternRef) = @_;
    my $sub = "verifySdp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $sdpLen = 0;
    my $sdpLine;
    my $sdpLineNum = 0;
    my $section = 0;
    my $currSection = 0;
    my $found = 1;
    my $Results = 1;        # Default to pass
    my $isNegative;
    my $patt;

    # Start the loop that looks for the patterns
    foreach my $sectionData (@$patternRef) {
        # Walk the list of patterns for the section.
        foreach my $testPattern (@$sectionData) {
            # For each line in message
            $currSection = 0;
            $sdpLineNum = 0;
            $found = 0;
            $isNegative = 0;
            $patt = $testPattern;       # Make a copy so the input pattern desn't get modified.
            # Check to see if this is a negative match
            if ( index ($patt, "!") == 0 ) {
                # This is a negative match meaning that hit pattern should NOT be present in the
                # section.
                $patt =~ s/!//g;        # Remove the ! from the string.
                $isNegative = 1;
            }
            # Walk the lines in the message.
            foreach $sdpLine (@$sdpRef) {
                # If this line contains a "m=" then move to the next sections.
                if ( (index $sdpLine, "m=") != -1 ) {
                   # Found next section
                   $currSection = $currSection + 1;
                }
                # Gone past the section it is currently checking, so exit the loop
                if ( $currSection > $section ) {
                    last;
                }
                # Determine if it is currently in the section of the SDP we want to be matching against.
                if ( $currSection == $section ) {
                    # In the right section so look for a match with the pattern
                    if ( (index $sdpLine, $patt) != -1 ) {
                        # Found match for line
                        $logger->debug(__PACKAGE__."$sub: Section $currSection Line $sdpLineNum: Found a match for $testPattern ");
                        $found = 1;
                        last;           # No need to continue after it was found.
                    }
                }
                $sdpLineNum = $sdpLineNum + 1;
                # ToDO exit when all bytes in SDP are consumed.
            } # End Lines in SDP
            # Check the results - it was found and expected
            if ($found == 0 && $isNegative == 0) {
                $logger->debug(__PACKAGE__."$sub: Could not find match for $testPattern in sdp in section $section");
			$main::failure_msg .= "UNKNOWN:SBX5000HELPER-SDP Pattern Mismatch; ";
                $Results = 0;
            }
            # Is was found but was not supposed to be there.
            elsif  ($found == 1 && $isNegative == 1)
            {
                $logger->debug(__PACKAGE__."$sub: Section $section Line $sdpLineNum: Found a match for $testPattern when it is supposed to be absent.");
                $Results = 0;
            }
            # It wasn't supposed to be there and wasn't found.
            elsif  ($found == 0 && $isNegative == 1)
            {
                $logger->debug(__PACKAGE__."$sub: Section $section: Match, doesn't contain $patt ");
		$main::failure_msg .= "UNKNOWN:SBX5000HELPER-SDP Pattern Mismatch; ";
            }
        } # End matched for section
        $section = $section + 1;
    } # End Sections to look for.
    if ($Results == 1) {
        $logger->debug(__PACKAGE__."$sub: PASSED - Found all expected patterns");
    }
    else
    {
        # Failed - dump the message contents to the log.
        $logger->debug(__PACKAGE__."$sub: FAILED - Did not find all expected patterns");
        $logger->debug(__PACKAGE__."$sub: Input Message:");
        $logger->debug(__PACKAGE__."$sub: @$sdpRef");
	 $main::failure_msg .= "UNKNOWN:SBX5000HELPER-SDP Pattern Mismatch; "
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return $Results;
}

=head2 C< validateMultipleSippMessages >

=over

=item DESCRIPTION:

 Validate multiple SIPP messages at once.  It assumes the log parsing was already done elsewhare and is passed in.
 It will check the messages against the test patterns.

=item ARGUMENTS:

    messagesRef    Reference to the array of messages that was parsesd
    checkRef       Reference to a test block that consists of a array of messages to check and the pattern expected to be in those messages.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Output:

    1 = All verifications passed
    0 = At least one verification failed.

=item Example:

    my @msg0Data = (["INVITE", "application/sdp"],
                    ["m=audio", "a=mid:audio", "!a=rtcp-mux"])
    my @msg3Data = (["OK", "application/sdp"],
                    ["m=audio", "a=mid:audio", "a=rtcp-mux"]);

    my @msgChecks = ( [0, [ @msg0Data ] ],     # Message 0 (INVITE)
                      [3, [ @msg3Data ] ]);    # Message 3 (OK)
    my @messages = parseSippMessages ($sippHdr, $scriptName);
    $result = validateMultipleSippMessages (\@messages, \@msgChecks);

=back

=cut

sub validateMultipleSippMessages {
    my ($messagesRef, $checkRef) = @_;
    my $sub = "validateMultipleSippMessages";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my @checks = @$checkRef;
    my @messages = @$messagesRef;
    my $numMessages = @$messagesRef;
    my $numChecks = @checks;
    my $Result = 1;

    if ($numMessages == 0)
    {
        $logger->info ("$sub: No messages were found to check! - FAILED");
        return 0;       # Nothing to check so just return.
    }
    if ($numChecks == 0)
    {
        return 1;       # Nothing to check so just return.
    }
    # Walk the list of messages to check.  Each check entry consists of the message index and a reference to a test pattern for that message.
    foreach my $checkEntry (@checks) {
        # Dereference the check.
        my @check = @$checkEntry;
        # First value is which message number to check.
        my $msgIdx = $check[0];
        # Second value is a reference to the validations to perform on the message.
        my @testData = @{$check[1]};
        # Set the message from the list of messages.
        my @message =  @{$messages[$msgIdx]};
        $logger->info ("$sub: Validating Message # $msgIdx");
        # Run the messsage validation
        $Result = $Result * verifySdp (\@message, \@testData);
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return $Result;
}

=head2 C< extractFromMessage >

=over

=item DESCRIPTION:

 Given a message array and a sequence of things to match on and extract in regex format, pull out the values and put them into an array that is returned.

=item ARGUMENTS:

    message        Reference to a message to check.
    matchData      Reference to patterns to match against and extract for. They MUST be in order that should be found in.  For example
                   there shouldn't be a SDP match before a Header one.  However, it is legal to have more than one test pattern for a line.
                   And a pattern can have more than one extracted value.
                   i.e. "m=audio.*RTP\/AVP\s(.*)"  would return both the port and the list of codecs

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

	returns a array

=item EXAMPLE:

	my @result = extractFromMessage(\@msg,\@pattern);

=back

=cut

sub extractFromMessage {
    my  ($msgRef, $patternRef) = @_;
    my $sub = "extractFromMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $msgLineNum = 0;
    my $Results = 1;        # Default to pass
    my @matches = @$patternRef;
    my $matchCnt = @matches;
    my $matchIdx = 0;
    my $currMatch = $matches[$matchIdx];
    my @extData = [];                   # Extracted Data

    $logger->debug(__PACKAGE__."$sub: Checking Message and extracting data.");
    foreach my $msgLine (@$msgRef) {
        # Check for a match against the pattern in this line
        while ($msgLine =~ $currMatch) {
            my @matchResults = ($msgLine =~ $currMatch);
            # Found a match so append the results to the results array and move on to the next match pattern.
            push @extData, @matchResults;
            $logger->debug(__PACKAGE__."$sub: Found a match for $currMatch with results = @matchResults in Line $msgLineNum: $msgLine");
            $matchIdx = $matchIdx + 1;
            # Was that the last thing to match for?
            if ($matchIdx == $matchCnt )
            {
                $logger->debug(__PACKAGE__."$sub: Found all expected $matchCnt matches  - Results: @extData.");
                return @extData;
            }
	else
		{
		 $main::failure_msg .= "UNKNOWN:SBX5000HELPER-SIP Msg Pattern Mismatch; ";
		}
            $currMatch = $matches[$matchIdx];
        }
        $msgLineNum = $msgLineNum + 1;
    }
    # Return the extracted data that it did find.
    $logger->debug(__PACKAGE__."$sub: Found $matchIdx of $matchCnt matches, failed on search for $currMatch");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return @extData;
}

=head2 C< extractAllFromMessage >

=over

=item DESCRIPTION:

 Given a message array and a set of things to search for, return all matches.   Each line is tested against all patterns and all extractions are returned.

=item ARGUMENTS:

    message        Reference to a message to check.
    matchData      Reference to patterns to match against and extract for.

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

	returns a array

=item Example:

    my @testMessage = (
    "a=group:BUNDLE audio video",
    "m=audio 6000 RTP/AVP 0",
    "m=video 7000 RTP/AVP 31",
    "c=IN IP4 0.0.0.0");

    my @matchPatterns = ( qr/m=\D* (\d*) .*/);
    my @results = extractAllFromMessage ( \@testMessage, \@matchPatterns);
    Will return results with the ports for the m lines = 6000 7000

=back

=cut

sub extractAllFromMessage {
    my  ($msgRef, $patternRef) = @_;
    my $sub = "extractAllFromMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $msgLineNum = 0;
    my $Results = 1;        # Default to pass

    my @matches = @$patternRef;
    my $matchCnt = @matches;
    my $matchIdx = 0;
    my $currMatch = $matches[$matchIdx];
    my @extData;                   # Extracted Data
    # Walk all the lines in the message.
    foreach my $msgLine (@$msgRef) {
        # Check for a match against the pattern in this line
        foreach $currMatch (@matches) {
            if ($msgLine =~ $currMatch) {
                my @matchResults = ($msgLine =~ $currMatch);
                # Found a match so append the results to the results array and move on to the next match pattern.
                push @extData, @matchResults;
                $logger->debug(__PACKAGE__."$sub: Found a match for $currMatch with results = @matchResults in Line $msgLineNum: $msgLine");
            }
	else
	{
	 $main::failure_msg .= "UNKNOWN:SBX5000HELPER-SIP Msg Pattern Mismatch; ";
	}
        }
        $msgLineNum = $msgLineNum + 1;
    }
    # Return the extracted data that it did find.
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return @extData;
}

=head2 C< createCdrPktHash >

=over

=item DESCRIPTION:

 Create a CDR hash make sure the packet counts are what we expect.

=item ARGUMENTS:

    sbxObj         SBX Connection handle
    pattern        What streams are present in what order
                        A = Audio, V = Main Video, S = Slides video, B = BFCP, F = FECC, M = MSRP
    audioPkts      (Optional) Expected packets for the audio stream
    videoPkts      (Optional) Expected packets for the main video
    video2Pkts     (Optional) Expected packets for the slides video
    entry          (Optional) Which stop record to parse in most calls it is 0, but for refer calls there could be 0 and 1
    legs           (Optional) Which legs are active in the CDR
                        I - Ingress leg has valid entries
                        E - Egress leg has valid entries
    flow           (Optional) Which direction has data flowing.
                        D - Full duplex - data flows in both directions
                        F - Forward - data flows from ingress to egress
                        B - Backwards - Data flows from egress to ingress
    extrahash      (Optional) A array of any extra data that should be verified in the CDR

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Example:

    my %input  = ( -testCaseId                   => "",^M
              -sippScriptNameCalling        => "NULL",^M
                          -sippScriptNameCalled         => "NULL",^M
                          -msgValidation                => "NULL",^M
                          -portValidation               => "NULL",^M
                          -ufragValidation               => "NULL",^M
              -detailsValidation            => "NULL",^M
              -policerValidation            => "NULL",^M
                          -streams                      => "",^M
              -callSteps                    => 1,^M
              -delayMS                      => $updateDelayMS^M
                  );

     SonusQA::SBX5000::SBX5000HELPER::createCdrPktHash(\%input);

=back

=cut

sub createCdrPktHash {
    my $argsRef = shift;
    my $sub = "createCdrPktHash";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my %args = %$argsRef;
    my $Result = 1;
    my %streaminfo;
    my $index = 0;
    my $noVideo = 1;     # Default to true
    my $entry;

    # Set default values before args are processed
    my %a = ( -streams                      => "",
			  -audioPkts                    => 0,
			  -videoPkts                    => 0,
			  -video2Pkts                   => 0,
              -dataPkts                     => 0,
			  -legs                         => "IE",
			  -flow                         => "D",
		  );
    # Process arg to override the defaults.
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    # Set local variables from the hash keys
    my $streams      =  $a{-streams};
    my $audioPkts    =  $a{-audioPkts};
    my $videoPkts    =  $a{-videoPkts};
    my $video2Pkts   =  $a{-video2Pkts};
    my $dataPkts     =  $a{-dataPkts};
    my $legs         =  $a{-legs};
    my $flow         =  $a{-flow};

    # If Entry is set then use it, otherwise assume it is zero for the first STOP record.
    if (! $entry) {
        $entry = 0;
    }
    # If legs is not set then assume both ingress and egress are used.
    if (! $legs) {
        $legs = 'IE';
    }
    # If flows is not set then assume full duples flow is enabled.
    if (! $flow) {
        $flow = 'D';
    }
    $logger->debug(__PACKAGE__. "$sub : Creating CDR values $streams, Legs: $legs, Flow: $flow, Entry: $entry, Audio $audioPkts, Video: $videoPkts, Video2: $video2Pkts" );

    # Initialize all values to 0.
    my $ingAudioTxPkts = 0;
    my $ingAudioRxPkts = 0;

    my $ingVideoTxPkts = 0;
    my $ingVideoRxPkts = 0;
    my $ingVideo2TxPkts = 0;
    my $ingVideo2RxPkts = 0;
    my $egrAudioTxPkts = 0;
    my $egrVideoTxPkts = 0;
    my $egrVideo2TxPkts = 0;
    my $egrAudioRxPkts = 0;
    my $egrVideoRxPkts = 0;
    my $egrVideo2RxPkts = 0;
    my $isIngress = 0;
    my $isEgress = 0;
    my ($forwardAudioPkts,$forwardVideoPkts,$forwardVideo2Pkts,$backwardAudioPkts,$backwardVideoPkts,$backwardVideo2Pkts);
    if($flow eq "D") {
       $forwardAudioPkts = $audioPkts;
       $forwardVideoPkts = $videoPkts;
       $forwardVideo2Pkts = $video2Pkts;
       $backwardAudioPkts = $audioPkts;
       $backwardVideoPkts = $videoPkts;
       $backwardVideo2Pkts = $video2Pkts;
    }elsif($flow eq "F") {
       $forwardAudioPkts = $audioPkts;
       $forwardVideoPkts = $videoPkts;
       $forwardVideo2Pkts = $video2Pkts;
       $backwardAudioPkts = 0;
       $backwardVideoPkts = 0;
       $backwardVideo2Pkts = 0;
    }elsif($flow eq "B") {
       $forwardAudioPkts = 0;
       $forwardVideoPkts = 0;
       $forwardVideo2Pkts = 0;
       $backwardAudioPkts = $audioPkts;
       $backwardVideoPkts = $videoPkts;
       $backwardVideo2Pkts = $video2Pkts;
    }

    # Parse the legs input and set the expected bandwidth values.
    for my $c (split //, $legs) {
        if($c eq  "I")  {
        # Ingress side will still Recive the packet that are going forward, it just won't forward them to egress.
           $ingAudioTxPkts = $backwardAudioPkts;
           $ingAudioRxPkts = $audioPkts;
           $ingVideoTxPkts = $backwardVideoPkts;
           $ingVideoRxPkts = $videoPkts;
           $ingVideo2TxPkts = $backwardVideo2Pkts;
           $ingVideo2RxPkts = $video2Pkts;
           $isIngress = 1;
        }elsif($c eq "E")  {
        # Egress side will still Recive the packet that are going backwards, it just won't forward them.
           $egrAudioTxPkts = $forwardAudioPkts;
           $egrAudioRxPkts = $audioPkts;
           $egrVideoTxPkts = $forwardVideoPkts;
           $egrVideoRxPkts = $videoPkts;
           $egrVideo2TxPkts = $forwardVideo2Pkts;
           $egrVideo2RxPkts = $video2Pkts;
           $isEgress = 1;
        }
    }
    # Order of the field offsets in the stream stats structure in the CDR
    # 0  mediaType1
    # 1  streamIndex1
    # 2  ingress packetSent1
    # 3  ingress packetReceived1
    # 4  ingress octetSent1
    # 5  ingress octetReceived1
    # 6  ingress packetLost1
    # 7  ingress packetDiscarded1
    # 8  egress packetSent1
    # 9  egress packetReceived1
    # 10 egress octetSent1
    # 11 egress octetReceived1
    # 12 egress packetLost1
    # 13 egress packetDiscarded1
    # Build up a hash of the expected values based on the order of the input streams.
    for my $c (split //, $streams) {
            if($c eq "A")  {
                %streaminfo = (%streaminfo,
                    # Stream 1
                    streamStat($index,0)  => 'audio',
                    streamStat($index,2)  => $ingAudioTxPkts,
                    streamStat($index,3)  => $ingAudioRxPkts,
                    streamStat($index,8)  => $egrAudioTxPkts,
                    streamStat($index,9)  => $egrAudioRxPkts, );
            }elsif($c eq "V") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'video',
                    streamStat($index,2)  => $ingVideoTxPkts,
                    streamStat($index,3)  => $ingVideoRxPkts,
                    streamStat($index,8)  => $egrVideoTxPkts,
                    streamStat($index,9)  => $egrVideoRxPkts, );
                    $noVideo = 0;       # Found some video
            }elsif($c eq "S") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'video',
                    streamStat($index,2)  => $ingVideo2TxPkts,
                    streamStat($index,3)  => $ingVideo2RxPkts,
                    streamStat($index,8)  => $egrVideo2TxPkts,
                    streamStat($index,9)  => $egrVideo2RxPkts, );
                    $noVideo = 0;       # Found some video
            }elsif($c eq "B") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'UDP/BFCP',
                    streamStat($index,2)  => '0',
                    streamStat($index,8)  => '0',  );
            }elsif($c eq "F") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'FECC',
                    streamStat($index,2)  =>  '0',
                    streamStat($index,8)  =>  '0', );
            }elsif($c eq "M") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'PARTIAL' . 'TCP/MSRP',
                    streamStat($index,2)  => '0',
                    streamStat($index,8) => '0', );
            }elsif($c eq "D") {
                %streaminfo = (%streaminfo,
                    streamStat($index,0)  => 'PARTIAL' . 'DTLS',
                    streamStat($index,2)  => $dataPkts,
                    streamStat($index,3)  => $dataPkts,
                    streamStat($index,8)  => $dataPkts,
                    streamStat($index,9)  => $dataPkts, );
            }

        $index = $index + 1;
    }

    # Add Extra info if it is passed in
    my %extrahash;
    if (%extrahash)
    {
        %streaminfo = (%streaminfo, %extrahash);
    }

    # Put the hash into the STOP record for the entry.
    my %cdrhash = (
        'STOP' => {
            $entry => {%streaminfo}
        }
    );

    $logger->debug(__PACKAGE__. "$sub : CDR Hash is \%cdrhash" );
    my $cdrRef = \%cdrhash;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return $cdrRef;
}

=head2 C< verifyPolicers >

=over

=item DESCRIPTION:

 This subroutines is used to verify xrm policer statistics for a defined GCID generically used for validating credit rate and bucket rate along with RTP/RTCP packets sent/recieved per leg.
 It will execute the command "request sbx xrm debug command \"xres -stat gcid $gcid\"" and verify the output.

=item ARGUMENTS:

 Mandatory Args:
    $gcid
    $ingressRef - hash reference
    $egressRef - hash reference

 Optional Args:
    NA

=item PACKAGE:

 SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SBX5000::execCmd()

=item RETURNS:

 1 - on success
 0 - on failure

=item EXAMPLE:

 my $gcid1 = 49;
 my $ingressHash = {
                '3' => ['pkt0'],                 # PKT NIF
                '9' => ['12544'],              # 9 - Credit Rate
                '8' => ['4000'],                # 8 - Bucket Size
                '10' => ['400-500'],              # 10- RTP Pkts Sent
                '11' => ['400-500'],              # 11- RTP Pkts recv
                };
 my $egressHash = {
                '3' => ['pkt1'],                 # PKT NIF
                '9' => ['12544'],              # 9 - Credit Rate
                '8' => ['4000'],                # 8 - Bucket Size
                '10' => ['400-500'],              # 10- RTP Pkts Sent
                '11' => ['400-500'],              # 11- RTP Pkts recv
                };
 my $result = $sbx_obj->verifyPolicers($gcid1,$ingressHash,$egressHash);

 Note:
   Here the kyes of ingressHash and egressHash are column numbers of 'request sbx xrm debug command ...' output. We should give the column numbers correctly. It starts from 1.
   E.g. 'request sbx xrm debug command ...' output
       admin@MNODE149461> request sbx xrm debug command "xres -stat gcid 49"

        Dump XRES Stats for GCID 0x31

       -----------------------------------------------------------------------------------------------------------------------
                         Local  Remote  Remote                                       RTP      RTP      RTCP    RTCP    RTP
       XRES   Leg  Pkt   RTP    RTP     RTCP    Policer    Bucket     Credit         Pkts     Pkts     Pkts    Pkts    Pkts
       Id     Id   NIF   Port   Port    Port    Mode       Size       Rate           Sent     Rcv      Sent    Rcv     Discard
       -----------------------------------------------------------------------------------------------------------------------
       200    Ing  pkt0  1330   9692    0       DataRate   4000 byte  12544 byte/s   453      453      0       0       0
       202    Egr  pkt1  1118   9698    0       DataRate   4000 byte  12544 byte/s   453      453      0       0       0
       [ok][2017-07-13 09:10:30]

=back

=cut

sub verifyPolicers {
    my ($sbxObj, $gcid, $ingressRef, $egressRef) = @_;
    my $sub = "verifyPolicers";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    local $[ = 1;  #to set starting  array index as 1, only for this function

    unless($ingressRef || $egressRef){
        $logger->error(__PACKAGE__ . ".$sub: Both ingress and egress inputs are not passed. Atleast one is mandatory. ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

	if ($sbxObj->{D_SBC}) {
		 my $retVal = $sbxObj->verifyPolicersDSBC(-ingerss_ref => $ingressRef, -egress_ref => $egressRef);
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
         return $retVal;
    }	

    #Tools-11462
    #check if refrence is hash or array
    #if it is array, only have to check the pol rate.
    my %inputHash;
    $inputHash{'Ing'} = (ref $ingressRef eq 'HASH') ? $ingressRef : { '9' => $ingressRef } if($ingressRef);
    $inputHash{'Egr'} = (ref $egressRef eq 'HASH') ? $egressRef : { '9' => $egressRef } if($egressRef);

    my %stream_hash = (
		'Ing' => 0,
		'Egr' => 0
	);
    my $result = 1;
    $logger->info(__PACKAGE__ . ".$sub: The input Hash is ".Dumper(\%inputHash));

    $sbxObj->unhideDebug('sonus1');
    my @output = $sbxObj->execCmd("request sbx xrm debug command \"xres -stat gcid $gcid\"");
    $logger->debug(__PACKAGE__ . ".$sub: The command Output is ".Dumper(\@output));

    # Walk the lines in the output and look for valid Xres
    foreach my $curLine (@output) {
        # Tokenize on whitespaces
        #admin@sbx51-15>                   Local  Remote  Remote                                       RTP      RTP      RTCP    RTCP    RTP
        #admin@sbx51-15> XRES   Leg  Pkt   RTP    RTP     RTCP    Policer    Bucket     Credit         Pkts     Pkts     Pkts    Pkts    Pkts
        #admin@sbx51-15> Id     Id   NIF   Port   Port    Port    Mode       Size       Rate           Sent     Rcv      Sent    Rcv     Discard
        #admin@sbx51-15> -----------------------------------------------------------------------------------------------------------------------
        #admin@sbx51-15> 173    Ing    pkt0   1364   9000    9001    DataRate   4000 byte  12544 byte/s   82       82       1       1       0

        next unless ($curLine =~ /Ing|Egr/);
        $curLine =~ s/byte(\/s)?\s//g;
        my @tokens = split /\s+/, $curLine;
        shift @tokens if($tokens[1] =~ /admin.*/i);           #Fix for TOOLS-9412

        if ($tokens[2] =~ /Ing|Egr/) {
	    $stream_hash{$tokens[2]}++;
	    my $stream = $stream_hash{$tokens[2]};
            foreach my $column (keys %{$inputHash{$tokens[2]}}) {
                if ($inputHash{$tokens[2]}{$column}[$stream] =~ /-/) {
                    my ($min, $max) = split('-', $inputHash{$tokens[2]}{$column}[$stream]);
                    unless ($tokens[$column] >= $min and $tokens[$column] <= $max) {
                        $logger->error(__PACKAGE__ . ".$sub: for column - $column, Expected range - $min-$max, Actual - $tokens[$column]");
			$main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed parsing XRES; ";
                        $result = 0;
                    }
                }
                elsif ($tokens[$column] != $inputHash{$tokens[2]}{$column}[$stream]) {
                    $logger->error(__PACKAGE__ . ".$sub: for column - $column, Expected value - $inputHash{$tokens[2]}{$column}[$stream], Actual - $tokens[$column]");
		    $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed parsing XRES; ";
                    $result = 0;
                }
            }
        }
    }

    foreach my $type (keys (%inputHash)) {
        foreach my $column (keys %{$inputHash{$type}}) {
            my $count = @{$inputHash{$type}{$column}};
            unless ($count == $stream_hash{$type}) {
                $logger->error(__PACKAGE__ . ".$sub: FAILED $type, column $column, Expected $count stream found $stream_hash{$type}");
		        $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed parsing XRES; ";
                $result = 0;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
    return $result;
}

=head2 C< verifyPolicersDSBC >

=over

=item DESCRIPTION:

    This subroutine calls verifyPolicers for MSBC instance only in a DSBC setup.

=item ARGUMENTS:

	Mandatory Args:
    -ingress_ref => $ingressHashRef - hash reference
    -egress_ref => $egressHashRef- hash reference

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    NONE

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::__dsbcCallback

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless($sbxObj->verifyPolicersDSBC(-ingress_ref => $ingressHashRef, -egress_ref => $egresHashRef)){
        $logger->error("Verify Policers for DSBC Failed");
        return 0;
    }

=back

=cut
sub verifyPolicersDSBC {
    my ($self, %args) = @_;
    my $sub  = 'verifyPolicersDSBC';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");


    unless($self->{D_SBC}){
        $logger->error(__PACKAGE__. ".$sub: Use verifyPolicers for non DSBC ");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0] ");
        return 0;
    }

    my $flag = 1;
    foreach ('-ingress_ref','-egress_ref'){
        unless($args{$_}){
            $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ not found. ");
            $flag = 0;
            last;            
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0] ");
        return 0;        
    }
    
	my %hash = (
                'args' => [%args],
                'types' => ['M_SBC']
        );


    unless(exists $self->{PARENT}->{GCID_DATA}){
        unless($self->getGcids()){
            $logger->error(__PACKAGE__. ".$sub: Error in getting the GCIDS. ");
            $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0] ");
            return 0;                 
        }

        my $retVal = $self->__dsbcCallback(\&verifyPolicersDSBC, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my $result = 1;
    foreach my $gcid (@{$self->{PARENT}->{GCID_DATA}->{$self->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP}}}){
        $logger->debug(__PACKAGE__. ".$sub Verfiying for GCID: $gcid on IP: $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->​{IP}");        
        unless($self->verifyPolicers($gcid, $args{-ingress_ref}, $args{-egress_ref})){
            $result = 0;
            last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
    return $result;
}

=head2 C< licenseCheck >

=over

=item DESCRIPTION:

    This subroutine checks whether licenses are installed or not.To check particular licenses,licenses array refernce can be passed,while calling this subroutine.

=item ARGUMENTS:

	OPTIONAL :
	   -requiredlicenses => \@requiredlicenses Taken an array reference of the required licenses to check for if it is known that one or more licenses are mandatory

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    NONE

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    $sbx_object->licenseCheck(); # checks for all licenses

    $requiredlicenses = ['SBC-POL-RTU','SBC-POL-ENUM'];
    $sbx_object->licenseCheck(-requiredlicenses => $requiredlicenses ); #checks for licenses mentioned in the $requiredlicenses array reference

=back

=cut

sub licenseCheck {
    my $self = shift;
    my (%args) = @_;
    my (@cmdres,$timestamp,@time,$license,@requiredlicenses);
    my $sub_name = "licenseCheck";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Validating licenses..  ");
    my $flag = 1;
    @requiredlicenses = @{$args{-requiredlicenses}} if(defined($args{-requiredlicenses}));
    unless( @cmdres = $self->execCmd("show status system licenseInfo") ){ # executing 'show status system licenseInfo' cmd to know the License information
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to execute the command \'show status system licenseInfo\' ");
        $logger->error(__PACKAGE__ . ".$sub_name:  ERROR. Failed to get license info.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "TOOLS:SBX5000HELPER-Failed to get License Info; ";
	return 0;
    }

    if( $cmdres[$#cmdres] =~ /^\[ok\]\[(.*)\]$/ ){ # to get current time on SBC
        $timestamp = $1;
        $logger->debug(__PACKAGE__ . ".$sub_name: Current time on SBX : '$timestamp' ");
        @time = `date --utc --date "$timestamp" +%s`;
        chomp @time;
        $timestamp = $time[0];
    }

    # TOOLS-6056 SBC-MSRP license is depreciated above 5.0+
    if ( SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V05.00.000000') ) { #application version should be greater than SBC 5.0+
        $logger->debug(__PACKAGE__ . ".$sub_name: Removing the depreciated \'SBC-MSRP\' license in the list ");
        @cmdres = grep{$_ !~ /SBC-MSRP/}@cmdres;
    } # TOOLS-6056

    if( @requiredlicenses > 0 ){
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking for licenses : '@requiredlicenses' ");
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking for all the licenses ");
    }

    if ( grep { /licenseInfo/ } @cmdres < 2 ) {
        foreach my $line ( @cmdres ) {
            $line =~ s/^\s+//;
            if ( (@requiredlicenses and grep { $line =~ /$_/ } @requiredlicenses) or @requiredlicenses == 0){
                if( $line =~ /^([^\s]+)\s+(\d+)\s+(\d{4}-\d{2}-\d{2})-(\d{2}:\d{2})\s+(\d+)$/ ) {
                    $license = $1;
                    my $licensecount = $5;
                    my $licensetimestamp = $3." ".$4;
                    @time = `date --utc --date "$licensetimestamp" +%s`;
                    chomp @time;
                    $licensetimestamp = $time[0];
                    unless( $licensetimestamp >= $timestamp ) {
                        $logger->error(__PACKAGE__ . ".$sub_name:  ERROR. The license for '$license' has expired. Please install new license or extend the license expiration date ");
                    }
                    unless( $licensecount >= 1 ){
                        $flag = 0;
                        $logger->error(__PACKAGE__ . ".$sub_name:  ERROR. The license for '$license' has not been installed. The automation will not proceed unless all the licenses are installed. ");
                    }
                }elsif(  $line =~ /^([^\s]+)\s+0$/ ) {
                    $license = $1;
                    $logger->error(__PACKAGE__ . ".$sub_name:  ERROR. The license for '$license' has not been installed. The automation will not proceed unless all the licenses are installed. ");
                    $flag = 0;
                }
            }
        }
    }else{
        my $i;
        my %licenseInfo;
        for ( $i = 0; $i < @cmdres; $i++ ) {
            if ( $cmdres[$i] =~ /licenseInfo\s+(.*)\s+(.*)\s+\{\s*$/ ) {
                my $license = $1;
                $licenseInfo{$license}{expdate} = $1 if ($cmdres[$i+1] =~ /expirationDate\s+(.*);$/ );
                $licenseInfo{$license}{usagelimit} = $1 if($cmdres[$i+2] =~ /usageLimit\s+(.*);$/ );
            }
        }
        chomp @requiredlicenses;
        for my $lic ( keys %licenseInfo ){
            if ( @requiredlicenses and !(grep { $lic eq $_ } @requiredlicenses) ) {
            delete $licenseInfo{$lic};
            }
        }
        for ( keys %licenseInfo ){
            my ($date,$hour) = ( $licenseInfo{$_}{expdate} =~ /^(\d{4}-\d{2}-\d{2})-(\d{2}:\d{2})$/ );
            my @time = `date --utc --date "$date $hour"  +%s`;
            chomp @time;
            if( $licenseInfo{$_}{expdate} =~ /\"\"/ and $licenseInfo{$_}{usagelimit} == 0 ) {
                    if ( $licenseInfo{$_}{expdate} =~ /\"\"/ ){
                        $logger->error(__PACKAGE__ . ".$sub_name:  ERROR. The $_ license does not have a expiration date ");
                    }
                    if($licenseInfo{$_}{usagelimit} == 0){
                        $logger->error(__PACKAGE__ . ".$sub_name:  ERROR.  The $_ license has usage limit of 0 ");
                    }
                    $flag = 0;
            }elsif ( $time[0] < $timestamp and $licenseInfo{$_}{expdate} !~ /\"\"/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  ERROR.  The $_ license has expired. $_ license expiration date : '$licenseInfo{$_}{expdate}' ");
                $flag = 0;
            }
        }

       foreach my $req ( @requiredlicenses ) {
           unless ( ( grep { $req eq $_ } keys %licenseInfo ) ) {
               $logger->error(__PACKAGE__ . ".$sub_name:  ERROR.  The $req license is Invalid   ");
               $flag = 0;
	       last ;
            }
        }
    }

    if ( $flag ){
        $logger->debug(__PACKAGE__ . ".$sub_name: License check successful ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: ERROR.  License info : ");
        map {$logger->debug(" \t\t $_")} @cmdres;
        $logger->debug(__PACKAGE__ . ".$sub_name: ERROR. License check Failed ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-License check failed; ";
        return 0;
    }

}

=head2 C< isAdminUser >

=over

=item DESCRIPTION:

    This routine will check if user has admin rights or not by running the following command :
    'show table oam localAuth user group Administrator'

    Example :
    admin@PEUGEOT> show table oam localAuth user group Administrator
                          PASSWORD  ACCOUNT   PASSWORD
                          AGING     AGING     LOGIN     INTERACTIVE  M2M
    NAME   GROUP          STATE     STATE     SUPPORT   ACCESS       ACCESS
    --------------------------------------------------------------------------
    admin  Administrator  enabled   disabled  enabled   enabled      enabled
    test1  Administrator  enabled   enabled   enabled   enabled      enabled
    [ok][2016-02-04 11:21:46]

    Returns 1 if user is listed in the above list, 0 otherwise.

=item ARGUMENTS:

    $username - username to check if it belongs to group Administrator

=item OUTPUT:

    1 - if user has admin rights
    0 - otherwise

=item EXAMPLE:

    unless ($userRights = $self->isAdminUser()) {
      $logger->error(__PACKAGE__ . ".$sub:  user does not belong to group Administrator" );
      return 0;
    }

=back

=cut

sub isAdminUser {

    my $self = shift;
    my $username = shift;
    my $sub_name = 'isAdminUser()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my @administrators = $self->execCmd("show table oam localAuth user group Administrator");

    unless (grep(/$username/, @administrators)) {
       $logger->error(__PACKAGE__ . ".$sub_name: $username does not belong to group Administrator");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	$main::failure_msg .= "UNKNOWN:SBX5000HELPER-AdminUser check failed; ";
       return 0;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub_name: $username belongs to group Administrator");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$username]");
       return 1;
    }
}

=head2 C< resetLogsToCurrent >

=over

=item DESCRIPTION:

    To reset the starting log-file (as detected by kickOff()) to the current log.
    This is mainly for use on Cloud-HA where each CE numbers its logs independently, and will help if the user is doing any switchover and just needs to parse/collect the logs from current active.
    JIRA ID: TOOLS-9532

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1

=item EXAMPLES:

    $sbx_obj->resetLogsToCurrent();

=back

=cut

sub resetLogsToCurrent{
    my $self = shift;
    my $sub_name = "resetLogsToCurrent()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
         my $retVal = $self->__dsbcCallback(\&resetLogsToCurrent);
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
         return $retVal;
    }

    my @valid_logtypes = ('CDR',"ACT", "DBG", "SYS", "TRC");
    push (@valid_logtypes, "PKT", "AUD", "SEC") if ($self->{POST_3_0});
    my @logtypes = (scalar @{$self->{REQUIRED_LOGS}}) ? @{$self->{REQUIRED_LOGS}} : @valid_logtypes;
    $logger->debug(__PACKAGE__ . ".$sub_name: Finding the current log file name");
    my $ce = $self->{ACTIVE_CE}; # root session name pointing to active CE
    foreach my $file_type (@logtypes) {
        unless( grep $_ eq $file_type, @valid_logtypes){
            $logger->warn(__PACKAGE__ . ".$sub_name: '$file_type' is not a valid type, so skipping.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Valid log types: @valid_logtypes");
	    next;
        }

        my $final_filename = $self->getRecentLogViaCli($file_type);
        if ( $final_filename =~ /$file_type/ ){
            $logger->debug(__PACKAGE__ . ".$sub_name: Resetting starting logfile - Log file type: \'$file_type\' File name: \'$final_filename\' ");
            $self->{STARTING_LOG}->{$file_type} = $final_filename;
        } else {
            $logger->warn(__PACKAGE__ . ".$sub_name: Unable to get the current \'$file_type\' log file! File name: '$final_filename'");
            $logger->warn(__PACKAGE__ . ".$sub_name: Log type  \'$file_type\' will not be collected");
            $self->{STARTING_LOG}->{$file_type} = "error";
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 C< configureNWL >

=over

=item DESCRIPTION:

    NWL - Network Wide License
    This subroutine configure the NWL licenses and check the licenses status by polling maximum 3 times with a 20s delay

=item ARGUMENTS:

 Mandatory :

	NONE

 Optional:

       -license = License hash.
       -timeout = time in seconds, To wait before reconnect, once passing restartsbx cmd

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - success
 0 - failure

=item EXAMPLES:

	my %license = (
                        'ENCRYPT'     => {minCount => 20,
                                          maxCount => 30},
                        'SBC-POL-E911'=> undef,
                  );
	$sbxObj->configureNWL(-timeout => 180,-license => \%license);

=back

=cut

sub configureNWL {
    my $self = shift;
    my $sub_name = "configureNWL";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered sub");

    my (%default_licenses, %licenses, @run_in_all) ;

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&configureNWL, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

    my %args = @_ ;
    my $flag = 1;
    my $timeout = $args{-timeout} || 300 ;
    delete $args{-timeout};

    my $state_enabled =" state enabled" unless(SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V06.01.00A042'));
    my $ip_type = ($self->{TMS_ALIAS_DATA}->{SLS}->{1}->{IP})?('IP'):('IPV6');# if both ipv4 and ipv6 are defined will give priority to ipv4.
    @run_in_all = (
                   'set system licenseMode mode network',
                   "set system licenseServer SLS priority 1 serverAddress $self->{TMS_ALIAS_DATA}->{SLS}->{1}->{$ip_type}$state_enabled",
                  );
    push  @run_in_all,"set system licenseServer SLS priority 2 serverAddress $self->{TMS_ALIAS_DATA}->{SLS}->{2}->{$ip_type}$state_enabled" if($self->{TMS_ALIAS_DATA}->{SLS}->{2}->{$ip_type});

    if ( SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V07.00.00') ) {#TOOLS-17377
        my $admin_obj;
        my %a = (-obj_host => $self->{OBJ_HOST},  -obj_password => $self->{OBJ_PASSWORD}, -sessionlog => 1, -obj_user => 'admin', -comm_type => 'SSH', -obj_hostname => $self->{OBJ_HOSTNAME}, -obj_key_file => $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{KEY_FILE}); #TOOLS-18220
        unless( $admin_obj = SonusQA::Base::new('SonusQA::SBX5000', %a)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to create the Admin Session");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless ($admin_obj->unhideDebug('sonus1')) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to enter unhide debug mode");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
        unless ( $admin_obj->enterPrivateSession()) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode" );
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
        unless ($admin_obj->execCommitCliCmd(@run_in_all)) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Unable to execute the commands");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
        }
        @run_in_all = ();

        $admin_obj->leaveConfigureSession;
        $admin_obj->DESTROY;

    }

    $default_licenses{S_SBC}->{$_} = undef for qw(SBC-RTU SBC-POL-RTU SBC-MRF-RTU SBC-PSX-RTU SBC-POL-ENUM SBC-SIPREC SBC-SIP-I SBC-POL-E911 DSP-AMRWB ENCRYPT VDSP-RTU DSP-G722 SRTP SBC-VIDEO SBC-SIP323 DSP-AMRNB DSP-EVRC SWE-INSTANCE POL-BASE) ;
    $default_licenses{M_SBC}->{$_} = undef for qw(SWE-INSTANCE);
    $default_licenses{T_SBC}->{$_} = undef for qw(SWE-INSTANCE);

    if ( SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V07.00.000000') ) {
        #TOOLS-16224 added SBC-LI and SBC-P-DCS-LAES. Removed ENCRYPT
        #TOOLS-16784 added SBC-NICEREC
        #TOOLS-17002 Reverted the deletion of ENCRYPT
        $default_licenses{S_SBC}->{$_} = undef for qw (SBC-LI SBC-P-DCS-LAES SBC-NICEREC);
    }
    $default_licenses{I_SBC} = $default_licenses{S_SBC};

    my $sbc_type;

    if ( $self->{SBC_TYPE} ) {
        $sbc_type = $self->{SBC_TYPE};
    }else {
        $sbc_type = "I_SBC";
        $logger->info(__PACKAGE__ . ".$sub_name: Configuring the licenses for Non-DSBC platform.");
        if ( $self->{HARDWARE_TYPE}=~ /5400/i ){
            if ( $self->{PKT_PORT_SPEED} eq '1Gbps' ) {
                $default_licenses{I_SBC}->{'SBC-4X1GMP'} = undef ;
            }elsif ($self->{PKT_PORT_SPEED} eq '10Gbps') {
                $default_licenses{I_SBC}->{'SBC-1X10GMP'} = undef ;
            }
        }
    }

    if ( $args{-license} ) {
        foreach my $lic ( keys %{$args{-license}}) {
            my $new_license = 1 ;
            if(exists $default_licenses{$sbc_type}->{$lic}){
                $new_license = 0;
                $licenses{$lic} = $args{-license}{$lic};
            }
            $logger->warn(__PACKAGE__ . ".$sub_name: We are skipping the license $lic as it's not part of our license list.") if ($new_license);
        }
        $logger->info(__PACKAGE__ . ".$sub_name: Configuring the user defined licenses:".Dumper(\%licenses));
    }else{
        %licenses = %{$default_licenses{$sbc_type}};
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Configuring the below licenses:".Dumper(\%licenses));

    unless ( $self->enterPrivateSession()) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter config mode" );
        $flag = 0 ;
        last;
    }

    foreach (@run_in_all) {
        unless ($self->execCliCmd($_)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $_");
            $flag = 0;
            last;
        }
    }

    if ( $flag ) {
        my $cmd;
        foreach my $lic ( keys %licenses) {
            $cmd = "set system licenseRequired $lic";
            $cmd .= " minCount $licenses{$lic}{minCount} maxCount $licenses{$lic}{maxCount}" if($licenses{$lic});
            unless($self->execCliCmd($cmd)){
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $cmd");
                last;
            }
        }
    }

    if($flag) {
        $logger->info(__PACKAGE__ . ".$sub_name: successfully executed all the cmds");
        unless ($self->execCliCmd('commit')) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Cannot commit the commands ");
            $flag = 0;
        }
    }

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $flag = 0;
    }

    if ($flag) {
        unless($self->checkLicenseStatus(-license =>[keys %licenses])) {
            $flag = 0;
        }
    }

    if($flag and ! $args{-license} ){
        unless( SonusQA::Utils::greaterThanVersion($self->{'APPLICATION_VERSION'},'V06.01.00A02') ) {      #TOOLS-12631
            unless ( $self->serviceStopAndExec(-cmd => "sbxrestart" , -timeout => $timeout) ){
                $logger->error(__PACKAGE__ . ".$sub_name: Unable to Restart the SBC.");
                $flag = 0;
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}


=head2 C< checkLicenseStatus >

=over

=item DESCRIPTION:

    This subroutine is used to check the status of the licenses using the command "show status system licenseInfo".
    If all the licenses are not installed, then sleep of 20 sec is introduced and again licenses status are checked.
    This will be repeated -max_re_attempts number of times.
    If the licenses are not installed even after -max_re_attempts number of polls then subroutine will return with zero value.
    This will be called from subroutine configureNWL().

=item ARGUMENTS:

 Mandatory :

        -license with license array reference

 Optional:

        -max_re_attempts with some value represent the number of times licenses status need to be checked with 20 sec sleep after each check.

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::SBX5000::execCmd()

=item OUTPUT:

 1 - success
 0 - failure

=item EXAMPLES:

        my @license = (
                        'ENCRYPT',
                        'SBC-POL-E911'
                  );
        $sbxObj->checkLicenseStatus(-license =>\@licenses,-max_re_attempts =>3);

=back

=cut

sub checkLicenseStatus() {
    my ($self,%args) = @_;
    my $sub_name = "checkLicenseStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered sub");
    if(defined $self->{'REDUNDANCY_ROLE'} and $self->{'REDUNDANCY_ROLE'} eq 'STANDBY'){ #TOOLS-17976
        $logger->debug(__PACKAGE__ . ".$sub_name: REDUNDANCY_ROLE is $self->{'REDUNDANCY_ROLE'} and N:K SBC, so no need to check license.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }
    my @licenses = @{$args{-license}};
    my $max_re_attempts = $args{-max_re_attempts} || 9;
    my ($flag , $re_attempts) = 0;

    unless ( $args{-license} and scalar @{$args{-license}} ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:Mandatory argument license array is not passed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
        return $flag;
    }

WHILE_LOOP:
    while( $flag == 0) {
        $flag = 1;
        my @status_results;
        unless (@status_results = $self->execCmd('show status system licenseInfo')) {
            $logger->error(__PACKAGE__ . ".$sub_name:Failed to execute the command \'show table system licenseInfo\'");
            $flag = 0;
            last;
        }
        my (%license_status , $license_name);
        foreach( @status_results ) {
            if (/licenseInfo\s+(\S+)\s+/) {
                $license_name = $1;
            }elsif(/usageLimit\s+(\S+)\;/) {
                $license_status{$license_name} = $1;
            }
        }
        foreach ( @licenses) {
            unless($license_status{$_}) {
                $flag = 0;
                last WHILE_LOOP if($re_attempts == $max_re_attempts);
                $logger->info(__PACKAGE__ . ".$sub_name: The License $_ is not configured yet. Waiting 20 sec. Status will be checked again.");
                sleep(20);
                $re_attempts++;
                last;
            }
        }
     }

    $logger->error(__PACKAGE__ . ".$sub_name: All $self->{SELECTED_PERSONALITIES} licenses are not configured")  unless ($flag);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< deleteLicenses >

=over

=item DESCRIPTION:

    This subroutine delete the NWL licenses .

=item ARGUMENTS:

 Mandatory :

        NONE

 Optional:

       -licenses = License array.
       If the licenses are not passed then all the licenses would be deleted.

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - success
 0 - failure

=item EXAMPLES:
        To delete all the licenses :
        my @license = ( );

        To delete specific licenses:
        my @license = (
                        'ENCRYPT',
                        'SBC-POL-E911'
                  );
        $sbxObj->deleteLicenses(-license =>\@licenses);

=back

=cut

sub deleteLicenses() {                                 #TOOLS -13748
    my ($self,%args) = @_;
    my @licenses = @{$args{-license}};
    my $sub_name = "deleteLicenses";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered sub");

    my $flag = 1;

    my $personalities = $self->{SELECTED_PERSONALITIES};

    my (@cmds,$run_in_all);
    unless(@licenses) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Going to delete all the licenses ");
        $run_in_all = 'delete system licenseRequired';
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Going to delete the licenses ".Dumper(\@licenses));

        foreach (@licenses){
            if(/SWE\-INSTANCE/) {
                $run_in_all = 'delete system licenseRequired SWE-INSTANCE';
            }else{
                push(@cmds,"delete system licenseRequired $_");
            }
        }
    }

    if( $run_in_all) {
        $self->{SELECTED_PERSONALITIES} = $self->{PERSONALITIES};
    }else {
        $self->{SELECTED_PERSONALITIES} = (exists $self->{S_SBC}) ? ['S_SBC'] : ['I_SBC'] ;
    }
    unless ( $self->enterPrivateSession()) {
       $logger->error(__PACKAGE__ . ".$sub_name:  Unable to enter private session" );
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }

    if($run_in_all){
        unless ($self->execCommitCliCmdConfirm($run_in_all)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmd $run_in_all");
            $flag = 0;
        }
    }

    if($flag and @cmds){
        $self->{SELECTED_PERSONALITIES} = (exists $self->{S_SBC}) ? ['S_SBC'] : ['I_SBC'];
        if ($self->execCommitCliCmdConfirm(@cmds)){
            $logger->info(__PACKAGE__ . ".$sub_name: successfully executed all the cmds");
        }else{
            $flag = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the cmds");
        }
    }

    $self->{SELECTED_PERSONALITIES} = $self->{PERSONALITIES} if($run_in_all);

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $flag = 0;
    }

    $self->{SELECTED_PERSONALITIES} = $personalities;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< serviceStopAndExec >

=over

=item DESCRIPTION:

    For HA it will stop service in standby and excute the user passed cmd in both Active and Standby and reconnects to the SBC.
    For StandAlone, it will excute the user passed cmd and reconnects to the SBC.

=item ARGUMENTS:

 Mandatory :

        $cmd - The command which makes SBC to go Down Ex. clearDBsh or restart .

 Optional:

        $timeout - How many seconds to sleep before calling makeReconnection()

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - success
 0 - failure

=item EXAMPLES:

	$sbxObj->serviceStopAndExec(-cmd => 'sbxrestart' , -timeout => 200);

=back

=cut

sub serviceStopAndExec {
    my ($self,%args) = @_;
    my $sub_name = "serviceStopAndExec";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered sub");

    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub_name: SBC Object is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return (0);
    }

    my $timeout = $args{-timeout} ||= 300;
    unless ($args{-cmd}) {
        $logger->error(__PACKAGE__ . ".$sub_name: cmd is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return (0);
    }
    my @obj_arr;
    my $is_ha = ($self->{HA_SETUP})?1:0;
    if ($self->{D_SBC}) {
        foreach my $sbc_type (@{$self->{PERSONALITIES}}) {
            foreach my $index (keys %{$self->{$sbc_type}}){
                push(@obj_arr, $self->{$sbc_type}->{$index}) unless( $self->{$sbc_type}->{$index}->{REDUNDANCY_ROLE} =~ /STANDBY/i);#In N:K we will create a seperate Obj for STANDBY,which is not needed because we will execute the (stop/clearDb/restart) cmd on standby if HA_SETUP flag is set
            }
        }
     }else{
         @obj_arr = ($self);
     }
    my $cmdFailFlag = 0;
    my $waittime = ( $timeout > 300 ) ? $timeout : 300;
    my %cmd_list = (
		     'service sbx stop' => $timeout,
                     $args{-cmd} => 0,
                     '##WAITONLY##' => $waittime
                   );

    foreach my $obj (@obj_arr){
        my @root_obj = ($is_ha) ? ($obj->{STAND_BY},$obj->{ACTIVE_CE}) : ($obj->{ACTIVE_CE});#'service sbx stop' cmd should executed on standby first
        $logger->info(__PACKAGE__ . ".$sub_name: Root Object array is :: ".Dumper(@root_obj));

        foreach my $cmd ('service sbx stop',$args{-cmd},'##WAITONLY##') {
            foreach my $ce (@root_obj) {
                $logger->info(__PACKAGE__ . ".$sub_name: checking for the box : \'$ce\'");
                my $new_cmd = ( $cmd =~ /clearDBs/i) ? $cmd." $obj->{$ce}->{INSTALLED_ROLE}" : $cmd ;
                my ($cmdStatus , @cmdResult) = _execShellCmd($obj->{$ce}, $new_cmd, $cmd_list{$cmd} );
                unless ( $cmdStatus ) {
                    if ( $obj->{'TMS_ALIAS_DATA'}->{MGMTNIF}->{2}->{'IP'} and $cmd eq '##WAITONLY##' ) {
                        unless ($obj->reconnect()) {
                            $logger->error(__PACKAGE__ . ".$sub_name unable to reconnect after a Restart");
                            $cmdFailFlag = 1;
                            last;
                        }
                    }else {
                        $logger->error(__PACKAGE__ . ".$sub_name:  Cmd \'$new_cmd\' on \'$obj->{$ce}->{OBJ_HOST}\' unsuccessful.");
                        $cmdFailFlag = 1;
                        last;
                    }
                }
                #sleep for 30s if the cmd is restart or clearDB
                unless($cmd_list{$cmd}){ #timeout for restart or clearDB is 0
                    $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 30 seconds. ");
                    sleep 30;
                }
            }
            @root_obj = reverse @root_obj if($cmd =~ /service sbx stop/i);#Other cmds should execute on active first so reversing the root_obj array
        }
        if( $cmdFailFlag ) {
            $logger->error(__PACKAGE__ . ".$sub_name: UN-SUCCESSFUL.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    unless($self->checkProcessStatus()){
        $logger->error(__PACKAGE__ . ".$sub_name: SBC is not UP or Processes is not running;");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Error SBC is not UP or Processes is not running; ";
        return 0;
    }
    unless ($self->makeReconnection()) {
        $logger->error(__PACKAGE__ . ".$sub_name unable to reconnect after a Restart");
        &error("Unable to reconnect cleanup");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESSFUL.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< configureSigPortAndDNS >

=over

=item DESCRIPTION:

 To configure the D-SBC Signaling port commands, loadBalancingService for privateIpInterfaceGroup and DNS cluster.

=item ARGUMENTS:

    addContextName      - Name of the addressContext
    ipInterfaceGroupName- Name of the Interface Group
    ipInterfaceName     - Name of Interface
    ipType              - Type of Ip Address
    ipAddress           - Ip Address

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

    1 - Configurations done successfully
    0 - Failure during configuration

=item EXAMPLES:

    unless ($sbx_obj->configureSigPortAndDNS($addContextName, $ipInterfaceGroupName, $ipInterfaceName, $ipType, $ipAddress)) {
        $logger->error(__PACKAGE__ . ".exexCmd: D_SBC Signaling Port configuration failed.");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub");
        return 0;
    }

=back

=cut

sub configureSigPortAndDNS {
    my ($self, $cmd) = @_;

    my $sub_name = "configureSigPortAndDNS()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    #TOOLS-13821
    my @personalities = ( exists $self->{SELECTED_PERSONALITIES} and @{$self->{SELECTED_PERSONALITIES}}) ? @{$self->{SELECTED_PERSONALITIES}} : @{$self->{PERSONALITIES}};#TOOLS-18559
    $logger->debug(__PACKAGE__ . ".$sub_name: personalities: @personalities");
    unless(grep /(S|M|T)_SBC/, @personalities){
        $logger->info(__PACKAGE__ . ".$sub_name: Skipping the configuration, since there is no (S|M|T)_SBC.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

    my ($addContextName, $ipInterfaceGroupName, $ipInterfaceName, $ipType, $ipAddress) = ($1, $2, $3, $4, $5) if ($cmd =~ /set\saddressContext\s(.*)\sipInterfaceGroup\s(.*)\s+ipInterface\s(.*)\sceName.*portName\spkt0\s(\S+)\s(\S+)/i);

    $logger->debug(__PACKAGE__ . ".$sub_name: Executing D_SBC Signalling ports command");
    my @clusterCmd = (
		"set system dsbc dsbcSigPort addressContext $addContextName ipInterfaceGroup $ipInterfaceGroupName $ipType $ipAddress",
                "set system dsbc dsbcSigPort addressContext $addContextName mode inService state enabled", #Signaling port commands for all personalities.
                "set system loadBalancingService privateIpInterfaceGroupName $ipInterfaceGroupName" #TOOLS-11201
    );

    unless ($self->execCommitCliCmd(@clusterCmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Inter-cluster D_SBC signaling port configuration failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".execCmd: Executing D_SBC Cluster Configuration");
    if (exists $self->{TMS_ALIAS_DATA}->{DNS}) {
        unless ($self->clusterConfigForExternalDns($addContextName, $ipInterfaceGroupName, $ipInterfaceName)) {
            $logger->error(__PACKAGE__ . ".$sub_name: D_SBC Cluster Configuration failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    else {
        unless($self->clusterConfigForLocalDns($addContextName, $ipInterfaceGroupName, $ipInterfaceName)) {
            $logger->error(__PACKAGE__ . ".$sub_name: D_SBC Cluster Configuration failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $self->{CMD_INFO}->{DSBC_CONFIG} = 1; # TOOLS-8313
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=head2 C< resolveCommitError >

=over

=item DESCRIPTION:

    Resolving the error produced by specifc commands on commit

=item ARGUMENTS:

    cmd         - Failed cmd
    $result     - Error message

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - Extra command and when failed command runs successfully
    0 - Failed to execute extra and failed command, and when command doesn't match

=item EXAMPLES:

    unless ($sbx_obj->resolveCommitError($cmd, $result)) {
        $logger->error(__PACKAGE__ . ".exexCmd: Failed to run extra command.");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub[0]");
        return 0;
    }

=back

=cut


sub resolveCommitError {
    my ($self, $cmd, $result) = @_;
    my $sub_name = "resolveCommitError()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($flag , @extra_cmd) = (0,());
    if ($cmd =~ /^\s*delete\s+addressContext\s+default\s*$/){ #TOOLS-13127
        #deletion of default addressContext is not allowed as 'zone is configured' by default in it so going to do just 'revert'.
        $flag = 1 if(grep(/Aborted: \'addressContext\': Cannot delete an address context that has a Zone configured./, @$result));
    }
    elsif ($cmd =~ /set\s+addressContext\s+(\S+)\s+ipInterfaceGroup\s+(\S+)\s+ipInterface\s+(\S+)\s+/i and grep (/Aborted.*addressContext default ipInterfaceGroup.*Cannot set.*state is enabled/i, @$result)){
        #Tools-8398
        @extra_cmd = "set addressContext $1 ipInterfaceGroup $2 ipInterface $3 mode outOfService state disabled";
	$flag = 1;
    }
    elsif ($cmd =~ /delete\s+addressContext\s+(\S+)/i) {
        #Tools-8566
        my $addressContext = $1;
        my ($grep) = grep $_ =~ /Aborted\:/,@$result;
	#TOOLS-12447 handling the dependencies while deleting the addressContext/ipInterfaceGroup
	my %error_hash = (
		"Aborted: illegal reference 'system dsbc dsbcSigPort ipInterfaceGroup" =>
						['set system dsbc dsbcSigPort state disabled mode outOfService',
						 'delete system dsbc dsbcSigPort ipInterfaceGroup'],
	        "Aborted: illegal reference 'system loadBalancingService privateIpInterfaceGroupName" =>
						['delete system loadBalancingService privateIpInterfaceGroupName',
				                 'delete system loadBalancingService'],
		"Aborted: 'addressContext': Cannot delete an address context that has a DNS Group configured." =>
						['set system dsbc cluster type policer state disabled',
						 'delete system dsbc',
						 "delete addressContext $addressContext dnsGroup"],
		"Aborted: 'addressContext default dnsGroup local': Cannot delete DNS group that has local record configured." =>
						['delete addressContext default dnsGroup local localRecord'],
	);
        if ($error_hash{$grep}){
            @extra_cmd = @{$error_hash{$grep}} ;#TOOLS-13127
	    $flag = 1;
        }
    }
   #TOOLS-19162
    elsif((grep /the configuration database is locked by session \d+ writeLock/, @$result) && ( $self->{ADMIN_USER})){
       unless ($self->unhideDebug('sonus1')){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to enter unhide debug mode");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
            return 0;
       }
       my $DB_enabled =1;
       #To make overall wait time 180s we are looping for 19 times
       #We will skip the last wait time, so considering 18 * 10s sleep = 180s of overall waittime.
       my $max_try = 19;
       for(my $loop = 1; $loop <= $max_try; $loop++){
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking the DB status.[$loop/$max_try]");
            my ($cmd, @cmd_result) = ('show status oam eventLog confdNbiWriteAccessState', '');
            unless( @cmd_result = $self->execCmd( $cmd )){
            $logger->error(__PACKAGE__ . ".$sub_name: failed to execute: $cmd ");
            last;
       }
       if( grep /confdNbiWriteAccessState enabled/, @cmd_result){
             $logger->debug(__PACKAGE__ . ".$sub_name:  READ/WRITE is enabled");
             $DB_enabled = 1 ;
             last;
       }
       elsif($loop < $max_try){# Why $max_try ? To skip the last loop wait time , which is unnecessary.
             $logger->debug(__PACKAGE__ . ".$sub_name:  sleep 10s, Before trying again... ");
             sleep 10;
       }
       }
       $self->execCmd('hide debug');
       unless ( $DB_enabled ){
             $logger->error(__PACKAGE__ . ".$sub_name:  READ/WRITE is not enabled ");
             $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
             $main::failure_msg .= "TOOLS:SBX5000-READ/WRITE not enabled; ";
             return 0;
       }
       $flag=1;
    }
   #TOOLS-19162
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Cannot resolve error for the cmd - $cmd");
    }
    if ($flag) {
        unless ($self->execRevertCliCmdConfirm) {
            $logger->error(__PACKAGE__ . ".$sub_name : Unable to revert the changes");
            $flag = 0;
        }
        if (@extra_cmd and $flag ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: ATS is executing extra cmd for user".Dumper(\@extra_cmd));
            unless ($self->execCommitCliCmdConfirm(@extra_cmd, $cmd)) {
                $logger->error(__PACKAGE__ . ".$sub_name : Unable to execute the commands");
                $flag = 0;
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< verifyPMStats >

=over

=item DESCRIPTION:

    Validate PM statistics generated by SBC

=item ARGUMENTS:

    %args - Hash with stats name, trunk and header names and values
    max_delay - Max duration to wait for tar file(optional).

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - Data validated successfully
    0 - Data validattion failed or parameters missing

=item EXAMPLES:

    my %args = (
		   max_delay => '300',
                   CallIntervalStats => {
                       TG_CORE1 => {RESPONSE_401 => 2},
                       TG_ACCESS => {RESPONSE_407 => 0}}
               );
    unless ($sbx_obj->verifyPMStats(%args)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Data validation failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

=item SAMPLE_FILE:

        File Name : CallIntervalStats_0_2222_1507284900000.pms

        NODE_ID,TIMESTAMP,ACNAME,ZNAME,NAME,RESPONSE_401,RESPONSE_403,RESPONSE_407,RESPONSE_481
        0,1505810400000,default,ZONE_CORE,TG_CORE1,2,0,2,0
        0,1505810400000,default,ZONE_ACCESS,TG_ACCESS,0,0,0,0

=back

=cut

sub verifyPMStats {
    my ($self,%args)=@_;
    my $sub_name = "verifyPMStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my ($stats_file,$header_name,@row,%header,$tar_file,$res,@result);
    my $flag = 1;
    my $ce = $self->{ACTIVE_CE};
    my $path = "/var/log/sonus/sbx/statistics";
    $args{max_delay} ||= 300;
    $logger->debug(__PACKAGE__ . ".$sub_name: Max delay is ".$args{max_delay});

    my $cmd = "ls -t $path/*.tar | head -n 1";
    while($args{max_delay}) {
        $logger->info(__PACKAGE__ . ".$sub_name: Waiting for 20 seconds.");
        sleep(20);
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking for Tar file.");
        $args{max_delay} -= 20;
        ($res, @result) = _execShellCmd($self->{$ce}, $cmd);
        unless ($res) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n".Dumper(\@result));
	    last;
	}
        elsif ($result[1] !~ /No such file or directory/i) {
	    $tar_file = $result[1];
            last;
        }
    }
    unless ($tar_file) {
        $logger->error(__PACKAGE__ . ".$sub_name: Tar File doesnot exist.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Tar File Name - $tar_file");
    $cmd = "tar -xvf $tar_file -C $path";
    my @extracts;
    ($res, @extracts) = _execShellCmd($self->{$ce}, $cmd);
    unless ($res) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $cmd = "mv $tar_file /tmp";
    $logger->debug(__PACKAGE__ . ".$sub_name: Moving $tar_file to /tmp");
    ($res, @result) = _execShellCmd($self->{$ce}, $cmd);
    unless ($res) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    delete $args{max_delay};
    my $count=0;
STATS_LOOP :
    for my $stats_name(keys %args) {
        my $file_index = lastidx {$_ =~ /^$stats_name\_.*\.pms$/}@extracts;
        if ($file_index<0) {
            $logger->error(__PACKAGE__ . ".$sub_name: Stats File $stats_name doesnot exist .");
            $flag = 0;
            last;
        }
        $stats_file = $extracts[$file_index];
        $logger->debug(__PACKAGE__ . ".$sub_name: Stats File Name - $stats_file");

        $cmd = "cat $path/$stats_file";
        ($res, @row) = _execShellCmd($self->{$ce}, $cmd);
        unless ($res) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
            $flag = 0;
            last;
        }
        shift @row;
        %header = map { $_ => $count++} split /,/, shift @row;

        for my $trunk_name(keys %{$args{$stats_name}}) {
            my @trunks= (split ',', $row[onlyidx {$_ =~ /(^|,)$trunk_name($|,)/}@row]);

            for $header_name(keys %{$args{$stats_name}{$trunk_name}}) {
                unless (exists $header{$header_name}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Header not found.");
                    $flag = 0;
                    last STATS_LOOP;
                }
                unless(($args{$stats_name}{$trunk_name}{$header_name}) eq $trunks[$header{$header_name}]) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  $stats_name -> $header_name -> $trunk_name Expected: $trunks[$header{$header_name}] Recieved: $args{$stats_name}{$trunk_name}{$header_name} MATCH FAILED!! ");
                    $logger->error(__PACKAGE__ . ".$sub_name: Verification Failed");
                    $flag=0;
                    last STATS_LOOP;
                }
                else {
                    $logger->debug(__PACKAGE__ . ".$sub_name: Key: $header_name Expected: $trunks[$header{$header_name}] MATCH SUCCESS!! ");
                }
            }
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Verified Data") if($flag);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< enableTRC >

=over

=item DESCRIPTION:

    To enable TRC log level4 (TOOLS-17987). It is called from cleanStartSBX() to enable by default.

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - success
    0 - failure

=item EXAMPLES:

    unless($sbc_obj->enableTRC()){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enable TRC log level4");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub enableTRC{
    my ($self)=@_;
    my $sub = 'enableTRC';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless($self->enterPrivateSession() ) {
        $logger->error(__PACKAGE__ . ".$sub : Could not enter private mode");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmds = (
        'set global callTrace callTraceTimer 0',
        'set global callTrace callFilter Test state enabled',
        'set global callTrace callFilter Test level level4',
        'set global callTrace callFilter Test match peerIpAddress 255.255.255.255',
        'set global callTrace callFilter Test key peerIpAddress',
    );

    my $ret = 1;
    unless ($self->execCommitCliCmd(@cmds)) {
        $logger->error(__PACKAGE__ . ".$sub : Unable to execute the commands");
        $ret = 0;
    }

    unless($self->leaveConfigureSession()){
        $logger->error(__PACKAGE__ . ".$sub: Could not leave configure mode");
        $ret = 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Enabled TRC log level4") if($ret);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
    return $ret;
}

=head2 C< checkDSP >

=over

=item DESCRIPTION:

    To check DSP25 card is enabled or not. (TOOLS-18641)
    Will execute the command 'show status system daughterBoardStatus productName DSP25' and check 'operationalStatus enabled;' in the output. If yes, it returns 1 and 0 otherwise.

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 - success
    0 - failure

=item EXAMPLES:

    unless($sbc_obj->checkDSP()){
        $logger->error(__PACKAGE__ . ".$sub_name: DSP25 is not enabled");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub checkDSP {
    my ($self)=@_;
    my $sub = 'checkDSP';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $flag = 0;
    my @cmd_output;

    if(@cmd_output = $self->execCmd("show status system daughterBoardStatus productName DSP25")){
        if(grep /operationalStatus\s+enabled;/,@cmd_output) {
            $logger->info(__PACKAGE__ . ".$sub: DSP25 is enabled");
            $flag = 1;
        }
        else{
            $logger->error(__PACKAGE__ . ".$sub: DSP25 is not enabled.");
            $logger->debug(__PACKAGE__ . ".$sub: output: ". Dumper(\@cmd_output));
        }
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute 'show status system daughterBoardStatus productName DSP25'");
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< deleteStaticRoute >

=over

=item DESCRIPTION:

   This subroutine is used to delete the static route in SBX and executes the command with the parameters passed as input.
   Also it executes commit command after executing the command.

=item ARGUMENTS:

 Mandatory :
        1. addressContext       - $addrcontext (bydefault, value is default)
        2. Endpoint machine Ip  - $remoteIp
        3. Prefix               - $prefix
        4. gateway of SBC       - $nextHop
        5. interface Name       - $ifName
        6. preference           - $pref
        7. interface group      - $ifGroup

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::SBX5000HELPER::execCommitCliCmd

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->deleteStaticRoute($addcontext, $remoteIp, $prefix, $nextHop, $ifName,$pref,$ifGroup) ;
         Example : set addressContext default staticRoute 10.70.53.87 32 10.7.1.1 LIF1 PKT0_V4 preference 100 ;

=back

=cut
sub deleteStaticRoute {
         my($self,$addcontext, $remoteIp, $prefix, $nextHop, $ifName,$pref,$ifGroup)=@_;

        my $sub_name = "deleteStaticRoute";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

        unless ($self->execCommitCliCmd("delete addressContext $addcontext staticRoute $remoteIp $prefix $nextHop $ifGroup $ifName")) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Unable to execute the command");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
}

=head2 C< checkCoredump >

=over

=item DESCRIPTION:

   This subroutine is used to check coredump using 'show status system coredumpList' cli 
   As part of TOOLS-71187: AWS: Enhancement of kick_off and wind_up function for linuxadmin user

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execCliCmd

=item OUTPUT:

    1 - ce name where coredump found
    0 - fail

=item EXAMPLES:

 $sbxObj->checkCoredump() ;

=back

=cut

sub checkCoredump{
    my ($self) = @_;

    my $sub_name = 'checkCoredump';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


=sample o/p
    admin@vsbc1> show status system coredumpList
    No entries found.
    [ok][2019-06-18 16:36:39]

####################################
    admin@vsbc1> show status system coredumpList
    coredumpList vsbc1 1 {
        coredumpFileName  core.1.CE_2N_Comp_PrsP_7543.1560868979;
        size              "1173708 KBytes";
        dateAndTime       "Tue Jun 18 10:43:09 2019";
        newSinceLastStart true;
    }
    coredumpList vsbc1 2 {
        coredumpFileName  core.1.CE_2N_Comp_SamP_7652.1560868979;
        size              "720960 KBytes";
        dateAndTime       "Tue Jun 18 10:43:08 2019";
        newSinceLastStart true;
    }
    coredumpList vsbc1 3 {
        coredumpFileName  core.1.CE_2N_Comp_PesP_7412.1560868979;
        size              "523484 KBytes";
        dateAndTime       "Tue Jun 18 10:43:08 2019";
        newSinceLastStart true;
    }
    Aborted: by user
    [ok][2019-06-18 10:46:52]

=cut

   unless($self->execCliCmd('show status system coredumpList')){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not get coredumpList.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $ce_name = 0;

    foreach (@{$self->{CMDRESULTS}}){
        $logger->debug(__PACKAGE__ . ".$sub_name: CMDRESULTS: $_");
        if(/coredumpList\s+(\w+)\s+/){
            $ce_name = $1;
            $logger->debug(__PACKAGE__ . ".$sub_name: coredump found in '$ce_name'");
            last;
        }
    }

    $main::core_found = ($ce_name) ? 1 : 0;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ce_name]");
    return $ce_name;
}

=head2 C< removeCoredump >

=over

=item DESCRIPTION:

   This subroutine is used to remove coredump using 'request system serverAdmin <ce_name> removeCoredump coredumpFileName all' cli
   As part of TOOLS-71187: AWS: Enhancement of kick_off and wind_up function for linuxadmin user

=item ARGUMENTS:

    Optional:
    -ce_name => which ce we need to delete core, if not passed we call checkCoredump and find out the ce

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execSystemCliCmd

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->removeCoredump(-ce_name => 'vsbc1') ;

=back

=cut

sub removeCoredump{
    my ($self, %args) = @_;

    my $sub_name = 'removeCoredump';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $args{-ce_name} ||= $self->checkCoredump();
    unless($args{-ce_name}){
        $logger->info(__PACKAGE__ . ".$sub_name: There is no coredump to remove.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

    unless($self->execSystemCliCmd("request system serverAdmin $args{-ce_name} removeCoredump coredumpFileName all")){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to remove coredump from '$args{-ce_name}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: all cores are removed from '$args{-ce_name}'");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< collectSbcDiagLogs >

=over

=item DESCRIPTION:

   This subroutine is used to collect sbc diagnostic logs using 'sbcDiagnostic 2' command
   As part of TOOLS-71187: AWS: Enhancement of kick_off and wind_up function for linuxadmin user

=item ARGUMENTS:

    -tcid => test case id
    -copy_location => copy core location, 

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SBX5000::execSystemCliCmd

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->collectSbcDiagLogs(-copy_location => $copyCoreLocation, -tcid => $tcid); ;

=back

=cut

sub collectSbcDiagLogs{
    my ($self, %args) = @_;

    my $sub_name = 'collectSbcDiagLogs';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        $logger->info(__PACKAGE__ . ".$sub_name: collecting sbc_diag_logs in $ce");
        $self->{$ce}->{conn}->print('sbcDiagnostic 2');

        my ($temp_index, $matched) = (1, 0);
        foreach my $match ('Save application cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'y', 'Save .* cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'n', 'Save CPS cores to sysdump \(will increase sysdump size\)\? \<y\/Y to save cores\>\:', 'n', 'Press ENTER to continue, or CTRL-C to quit', '') {
            if (($temp_index % 2) == 0 and $matched) {
                $self->{$ce}->{conn}->print($match);
                $matched = 0;
            }
            elsif (($temp_index % 2)) {
                my ($prematch, $m) = ('','');
                if (($prematch, $m) = $self->{$ce}->{conn}->waitfor(-match     => "/$match/i", -timeout   => $self->{DEFAULTTIMEOUT})) {
                    $matched = 1;
                }
                else{
                    $logger->error(__PACKAGE__ . ".$sub_name: dint match for \'$match\'. waiting for ". $self->{$ce}->{PROMPT});
                    ($prematch, $m) = $self->{$ce}->{conn}->waitfor(-match     => $self->{$ce}->{PROMPT}, -timeout   => 180);
                    if (/3 or more sysdumps already exist in/, $prematch) {
                        $logger->error(__PACKAGE__ . ".$sub_name: \'sysDump.pl\' says 3 or more sysdumps already exist, please clean them");
                    }
                    else{
                        $logger->debug(__PACKAGE__ . ".$sub_name: \'sysDump.pl\' returned $prematch");
                    }
                    $flag = 0;
                    last;
                }
            }
            $temp_index++;
        }

        my ($prematch, $match) = ('','');
        unless (($prematch, $match) = $self->{$ce}->{conn}->waitfor(-match => $self->{$ce}->{PROMPT}, -timeout   => 600)) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed get the prompt back after execution of \'sysDump.pl\' on $ce");
            $logger->debug(__PACKAGE__ . ".$sub_name errmsg :.".$self->{$ce}->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$ce}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$ce}->{sessionLog2}");
            $flag = 0;
            last;
        }

        last unless($flag);

        my @files;
        my @temp_result = grep (/\.tar\.gz/ || /\.md5/, split('\n',$prematch));
        foreach my $file (@temp_result) {
            if ($file =~ /((\S+)\.tar\.gz)/) {
                my $cmd = "mv /opt/sonus/external/$1 /opt/sonus/external/$2-$args{-tcid}.tar.gz";
                $logger->info(__PACKAGE__ . " moving /opt/sonus/external/$1 to /opt/sonus/external/$2-$args{-tcid}.tar.gz");
                unless ($self->{$ce}->{conn}->cmd($cmd)) {
                    $logger->warn(__PACKAGE__ . " unable perform \'$cmd\'");
                }
                else {
                    push @files, "/opt/sonus/external/$2-$args{-tcid}.tar.gz";
                }
            }
            if ($file =~ /((\S+)\.md5)/) {
                my $cmd = "mv /opt/sonus/external/$1 /opt/sonus/external/$2-$args{-tcid}.md5" ;
                $logger->info(__PACKAGE__ . " moving core dump \.md5 file to /opt/sonus/external/$2-$args{-tcid}.md5");
                unless ($self->{$ce}->{conn}->cmd($cmd)) {
                    $logger->warn(__PACKAGE__ . " unable perform \'$cmd\'");
                } 
                else {
                    push (@files, "/opt/sonus/external/$2-$args{-tcid}.md5");
                }
            }
        }
        $self->storeCoreDumps($ce, $args{-copy_location}, @files) if (@files);
    }

    $logger->debug(".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< enableExternalPsx >

=over

=item DESCRIPTION:

   This subroutine is used to enable external PSX.

=item ARGUMENTS:

    -psx_name => name of the PSX
    -psx_ip => IP of the PSX, 

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->enableExternalPsx(-psx_name => $psx_1_node_1_hostname, -psx_ip => $psx_1_node_1_ip); ;

=back

=cut


sub enableExternalPsx {
    my($self,%args) = @_;
    my $sub_name = "enableExternalPsx";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless (  $args{-psx_name}  &&  $args{-psx_ip}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: mandatory arguments '-psx_name' and '-psx_ip' not present .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my @cmds = ("set system policyServer localServer PSX_LOCAL_SERVER mode outOfService state disabled",
        "set system policyServer remoteServer $args{-psx_name} ipAddress $args{-psx_ip} action force state enabled mode active");
    my $ret_val = $self->execCommitCliCmd(@cmds);
    unless($ret_val){
        $logger->debug(__PACKAGE__ . ".$sub_name: External PSX enable failed");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$ret_val]");
    return $ret_val;

}

=head2 C< checkPsxStatus >

=over

=item DESCRIPTION:

   This subroutine is used to check the status of the PSX. It will try given number of times if psx status comes as not active.

=item ARGUMENTS:

    -psx_name => name of the PSX
    -max_try => no of times it will check the status if PSX status is not active ,

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER


=item OUTPUT:

    1 - success
    0 - fail

=item EXAMPLES:

 $sbxObj->checkPsxStatus(-psx_name =>  $psx_1_node_1_hostname, -max_try => $max); ;

=back

=cut

sub checkPsxStatus{
    my ($self,%args)= @_;
    my $sub_name = "checkPsxStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ .  ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless (  $args{-psx_name}  &&  $args{-max_try}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: mandatory arguments '-psx_name' and '-max_try' not present .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $is_active =0;
    for(my $loop = 1; $loop <= $args{-max_try}; $loop++){
         $logger->debug(__PACKAGE__ . ".$sub_name: Checking the PSX status.[$loop/$args{-max_try}]");
         $logger->debug(__PACKAGE__ . ".$sub_name:  sleep for 5s");
         sleep 5;
         my ($cmd, @cmd_result) = ("show status system policyServer policyServerStatus $args{-psx_name}", '');
         unless( @cmd_result = $self->execCmd( $cmd )){
             $logger->error(__PACKAGE__ . ".$sub_name: failed to get status: $cmd ");
             last;
         }
         if( grep /operState\s+Active/, @cmd_result){
             $logger->debug(__PACKAGE__ . ".$sub_name:  PSX is in Active state");
             $is_active =1;
             last;
         }
         $logger->debug(__PACKAGE__ . ".$sub_name:  PSX not active");
     }
     unless ( $is_active ){
         $logger->error(__PACKAGE__ . ".$sub_name:  PSX is not Active ");
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$is_active]");
     return $is_active;
 }
 1;
