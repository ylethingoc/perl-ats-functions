package SonusQA::SBX5000::SLBHELPER;

=head1 NAME

SonusQA::SBX5000::SLBHELPER - Perl module for SLB Interaction

=head1 AUTHOR

ribbon-ats-dev@rbbn.com

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, Data::Dumper, SonusQA::SBX5000, POSIX, List::Util

=head1 DESCRIPTION

Provides and interface to interact with the SLB

=head1 METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::SBX5000;

=head2 C< configureIpInterfaceSLB >

=over

=item DESCRIPTION

 This subroutine configures the ipInterface (with IPv6 primary address of the interface) for the specified ipInterfaceGroup. It sets the following parameters : ipInterface name, ceName,portName, ipAddress,prefix and altPrefix are set. The vlan tag is also optionally set if the parameter is provided. It also enables the state and sets the mode to inService of the ipinterface which was just configured.

=item ARGUMENTS:

 Mandatory :

        -address_context                   - The address context name (addressContext)
        -interface_group_name              - The group of IP interfaces for the specified address context
        -interface_name                    - Specifies the IP interface name.
        -ce_name                           - The name of the computing element that hosts the port used by this IP interface.
        -port_name                         - The physical port name used by this IP interface
        -ip_v4|-ip_v6 or both              - The primary IP Address(es) of the Interface.
        -prefix                            - Specifies the IP subnet prefix of this Interface.
        -ipv4_prefix|-ipv6_prefix or both  - Alternative IP subnet prefix of this interface.

 Optional:

        -vlan                              - Specifies the VLAN TAG assigned to this physical interface
        -alt_ip                            - The Secondary IP when V4 primary IP is specified (altIpVars)

=item PACKAGE:

 SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 0 - Failure (either a mandatory parameter not passed or empty or command execution failed)
 1 - success.

=item EXAMPLES:

 $sbxObj->configureIpInterfaceSLB(
                                -address_context      => 'default',
                                -interface_group_name => 'LIG1',
                                -interface_name       => 'LIF1',
                                -ce_name              => '',
                                -port_name            => 'pkt0',
                                -ip_v4                => 'IF2.IPV4',
                                -ip_v6                => 'IF2.IPV6',
                                -ipv4_prefix          => 'IF2.PrefixV4',
                                -ipv6_prefix          => 'IF2.PrefixV6',
                                -vlan                 => 'IF2.VlanId'
);

=back

=cut

sub configureIpInterfaceSLB {
    my ($self, %args)= @_;
    my $sub_name = 'configureIpInterfaceSLB';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $ret = 1;
    for my $param ( '-address_context', '-interface_name', '-interface_group_name', '-port_name' ) {
        unless($args{$param}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $param not passed or empty");
            $ret = 0;
            last;
        }
    }
    unless( ($ret == 1) && ( ($args{-ip_v4} && $args{-ipv4_prefix}) || ($args{-ip_v6} && $args{-ipv6_prefix}) ) ){
        $ret = 0;
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument IP, either ip_v4 or ip_v6 not passed or empty");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
        return $ret;
    }

    my @commands = "set addressContext $args{-address_context} ipInterfaceGroup $args{-interface_group_name} ipInterface $args{-interface_name} portName $args{-port_name}";
    $commands[0] .= " ipVarV4 $args{-ip_v4} prefixVarV4 $args{-ipv4_prefix}" if ($args{-ip_v4} && $args{-ipv4_prefix});
    $commands[0] .= " ipVarV6 $args{-ip_v6} prefixVarV6 $args{-ipv6_prefix}" if ($args{-ip_v6} && $args{-ipv6_prefix});
    
    $commands[0] .= " altIpVars $args{-alt_ip}" if($args{-alt_ip});
    $commands[0] .= " vlanTagVar $args{-vlan}" if($args{-vlan});

    push (@commands, "set addressContext $args{-address_context} ipInterfaceGroup $args{-interface_group_name} ipInterface $args{-interface_name} mode inService state enabled");
    unless ($ret = $self->execCommitCliCmd(@commands)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to configure IpInterface in SLB");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
    return $ret;
}

=head2 C< configureSipSigPortSLB >

=over

=item DESCRIPTION:
   This subroutine configures Sip Signalling Port on given Zone for SLB, finds the IPversion from given IP and uses it configuring SipSigPort.

=item ARGUMENTS:

 Mandatory :
	1. addressContext               = -address_context
	2. sipSigPort                   = -sig_port
	3. zone                         = -zone
	4. zoneId                       = -zone_id
	5. ipVarV4|ipVarV6 or both      = -ip_v4|-ip_v6 or both
	6. portNumber                   = -port
	7. ipInterfaceGroupName         = -interface_group_name
	8. transportProtocolsAllowed    = -allowed_protocols

 Optional:

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - Failure(either a mandatory parameter not passed or empty or command execution failed)
    1   - success

=item EXAMPLES:

 $sbxObj->configureSipSigPortSLB(
                                -address_context      => 'default',
                                -sig_port             => '3',
                                -zone                 => 'ZONE_AS',
                                -zone_id              => '3',
                                -port                 => '5060',
                                -ip_v4                => 'IF2.IPV4',
                                -interface_group_name => 'LIG2',
                                -allowed_protocols    => 'sip-udp,sip-tcp'
 );

=back

=cut

sub configureSipSigPortSLB {
    my ($self, %args) = @_;

    my $sub_name = 'configureSipSigPortSLB';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless(defined $args{-allowed_protocols}) {
        $args{-allowed_protocols} = 'sip-udp';
    }
    my $ret = 1;
    for my $param ( '-address_context', '-sig_port', '-interface_group_name', '-port', '-zone', '-zone_id' ) {
        unless($args{$param}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $param not passed or empty");
            $ret = 0;
            last;
        }
    }
    unless( ($ret == 1) && ($args{-ip_v4} || $args{-ip_v6}) ){
        $ret = 0;
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument IP, either ip_v4 or ip_v6 not passed or empty");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
        return $ret;
    }
    my @commands = "set addressContext $args{-address_context} zone $args{-zone} id $args{-zone_id}";
    $commands[1] = "set addressContext $args{-address_context} zone $args{-zone} sipSigPort $args{-sig_port} portNumber $args{-port} transportProtocolsAllowed $args{-allowed_protocols} ipInterfaceGroupName $args{-interface_group_name}";
    $commands[1] .= " ipVarV4 $args{-ip_v4}" if($args{-ip_v4});
    $commands[1] .= " ipVarV6 $args{-ip_v6}" if($args{-ip_v6});

    push (@commands, "set addressContext $args{-address_context} zone $args{-zone} sipSigPort $args{-sig_port} mode inService state enabled");

    unless( $ret = $self->execCommitCliCmd(@commands) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to configure SipSigPort of SLB");
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
    return $ret;
}

=head2 C< configureCommInterfaceSLB >

=over

=item DESCRIPTION:
   This subroutine configures Sip Signalling Port on given Zone for SLB, finds the IPversion from given IP and uses it configuring SipSigPort.

=item ARGUMENTS:

 Mandatory :
	1. addressContext               = -address_context
	2. ipVarV4|ipVarV6              = -ip
	3. ipInterfaceGroup             = -interface_group_name

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item OUTPUT:

    0   - Failure(either a mandatory parameter not passed or empty or command execution failed)
    1   - success

=item EXAMPLES:

 $sbxObj->configureCommInterfaceSLB(
                                -address_context      => 'default',
                                -ip                   => 'IF2.IPV4',
                                -interface_group_name => 'LIG2'
 );

=back

=cut

sub configureCommInterfaceSLB {
    my ($self, %args) = @_;
    my $sub_name = 'configureCommInterfaceSLB';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $ret = 1;
    for my $param ( '-address_context', '-ip', '-interface_group_name' ) {
        unless($args{$param}) {
            $ret = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $param not passed or empty");
            last;
        }
    }

    $ret = $self->execCommitCliCmd("set system slb commInterface addressContext $args{-address_context} ipInterfaceGroup $args{-interface_group_name} pktIpVar $args{-ip}") if($ret);

    $logger->error(__PACKAGE__ . ".$sub_name: Failed to configure CommInterface in SLB") unless($ret);
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
    return $ret;
}

1;