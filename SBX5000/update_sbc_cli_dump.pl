# Purpose:
#   Mainly used by System Test team. To modify the sbx cli dump file by using the values given in the user csv temmplate file.
#   The modified cli dump file can later use to configure the user sbx. 
#
# Usage: perl update_sbc_cli_dump.pl <cli dump file> <csv template file> <output cli dump file>
#   <output cli dump file> is optional. If not passed output cli dump file with the prefix 'new' will be generated in the working directory.
#
# JIRA: TOOLS-6364 - Need modification to ATS framework to accommodate System Test Scenarios
# Author: Aneesh Karattil

use strict;

unless($ARGV[0] && $ARGV[1]){
    print "Madatory arguments, cli dump file name / csv template file name is/are not passed.\n";
    print "Usage: perl update_sbc_cli_dump.pl <cli dump file> <csv template file> <output cli dump file> \n";
    print "\t<output cli dump file name> is optional. If not passed output cli dump file with the prefix 'new' will be generated in the working directory.\n";
    exit;
}

my $cli_dump_file = $ARGV[0];
my $input_csv_file = $ARGV[1];
my $updated_cli_dump_file = $ARGV[2] || "new_$cli_dump_file";

my (@remote_servers, %remote_server, $remote_server_flag, $ip_interface_flag, %ip_interface, %static_route, %sip_sig, %ingress_ip_prefix, $prev_grp, $prev_zone);

open (IN,"$input_csv_file") or die "Couldn't open '$input_csv_file'";
while(<IN>){
    chomp;
    next if(/^\s*$/);
    if(/remoteServer/){
        $remote_server_flag = 1;
        next;
    }
    if(/ipInterfaceGroup/){
        $remote_server_flag = 0;
        $ip_interface_flag = 1;
        next;
    }
    if($remote_server_flag){
        my @data = split(",");
        push @remote_servers, [@data];
    }
    elsif($ip_interface_flag){
        my ($group, $interface, $port, $ip, $prefix, $vlan, $static_ip, $static_prefix, $nexthop, $zone, $sipsig, $ip4, $sip_trunk, @ingress) = split(",");
        if($group){
            $ip_interface{$group}->{$interface} = {
                portName => $port,
                ipAddress => $ip,
                prefix => $prefix,
                vlanTag => $vlan
            };

            $static_route{$group}->{$interface} = {
                ipAddress => $static_ip,
                prefix => $static_prefix,
                nexthop => $nexthop
            };
            $prev_grp = $group;
        }
        $group ||=  $prev_grp;
        if($zone){
            $sip_sig{$group}->{$zone} = {
                sipSigPort => $sipsig,
                ipAddressV4 => $ip4
            };
            $prev_zone = $zone;
        }

        $zone ||= $prev_zone;
        if($sip_trunk){
            $ingress_ip_prefix{$zone}->{$sip_trunk} = \@ingress;
        }
    }
}

close IN;

open (OUT,">$updated_cli_dump_file") or die "Couldn't open '$updated_cli_dump_file'";
open (IN,"$cli_dump_file") or die "Couldn't open '$cli_dump_file'";
while(<IN>){
    ($remote_server_flag, $ip_interface_flag) = (0,0);

    if(/set system policyServer remoteServer ".+" ipAddress ".+" (portNumber ".+" state ".+") mode ".+" (action ".+" transactionTimer ".+" keepAliveTimer ".+" retryTimer ".+" retries ".+" subPortNumber ".+")/){
        my ($server, $ip, $mode) = @{shift(@remote_servers)};
        print OUT "set system policyServer remoteServer \"$server\" ipAddress \"$ip\" $1 mode \"$mode\" $2\n";
        next;
    }


    if(/(set addressContext ".+") ipInterfaceGroup "(.+)" ipInterface "(.+)" (ceName ".+") portName ".+" ipAddress ".+" prefix ".+" (mode ".+" action ".+" dryupTimeout ".+" state ".+" bwContingency ".+") vlanTag ".+" (bandwidth ".+")/){
        next unless($ip_interface{$2}->{$3});
        print OUT "$1 ipInterfaceGroup \"$2\" ipInterface \"$3\" $4 portName \"$ip_interface{$2}->{$3}->{portName}\" ipAddress \"$ip_interface{$2}->{$3}->{ipAddress}\" prefix \"$ip_interface{$2}->{$3}->{prefix}\" $5 vlanTag \"$ip_interface{$2}->{$3}->{vlanTag}\" $6\n";
        delete $ip_interface{$2}->{$3};
        next;
    }

    if(/(set addressContext ".+") zone "(.+)" sipSigPort ".+" ipInterfaceGroupName "(.+)" ipAddressV4 ".+" (portNumber ".+" state ".+ tcpConnectTimeout ".+" dscpValue ".+" tlsProfileName ".+" transportProtocolsAllowed ".+\s?")/){
        next unless($sip_sig{$3}->{$2});
        print OUT "$1 zone \"$2\" sipSigPort \"$sip_sig{$3}->{$2}->{sipSigPort}\" ipInterfaceGroupName \"$3\" ipAddressV4 \"$sip_sig{$3}->{$2}->{ipAddressV4}\" $4\n";
        delete $sip_sig{$3}->{$2};
        next;
    }

    if(/(set addressContext ".+") zone "(.+)" sipTrunkGroup "(.+)" ingressIpPrefix ".+" (".+")/){
        next unless(@{$ingress_ip_prefix{$2}->{$3}});
        my $prefix = shift @{$ingress_ip_prefix{$2}->{$3}};
        print OUT "$1 zone \"$2\" sipTrunkGroup \"$3\" ingressIpPrefix \"$prefix\" $4\n";
        next;
    }

    if(/(set addressContext ".+") staticRoute ".+" ".+" ".+" "(.+)" "(.+)" (preference .+)/){
        next unless($static_route{$2}->{$3});
        print OUT "$1 staticRoute \"$static_route{$2}->{$3}->{ipAddress}\" \"$static_route{$2}->{$3}->{prefix}\" \"$static_route{$2}->{$3}->{nexthop}\" \"$2\" \"$3\" $4\n";
        delete $static_route{$2}->{$3};
        next;
    }

    print OUT "$_";
}
close IN;
close OUT;


print "\n\nCheck the updated file, '$updated_cli_dump_file'\n\n";

