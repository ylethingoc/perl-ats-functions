# Purpose: 
#   Mainly used by System Test team. To generate the csv template from the user given customer sbx cli dump file.
#   Mostly this will be one time job. 
#   Once the csv template can be modified depends on our setup and update the customer cli dump using update_sbc_cli_dump.pl 
#
# Usage: perl generate_sbc_config_template.pl <cli dumpe file> <output csv template file>
#   <output csv template file> is optional. If not passed csv template file with name 'sbc_config_template.csv' will be generated in the working directory.
#
# JIRA: TOOLS-6364 - Need modification to ATS framework to accommodate System Test Scenarios
# Author: Aneesh Karattil


use strict;

unless($ARGV[0]){
    print "Madatory argument, cli dump file is not passed.\n";
    print "Usage: perl generate_sbc_config_template.pl <cli dumpe file> <output csv template file> \n";
    print "\t<output csv template file> is optional. If not passed csv template file with name 'sbc_config_template.csv' will be generated in the working directory.\n";
    exit;
}

my $in_file = $ARGV[0];
my $out_file = $ARGV[1] || 'sbc_config_template.csv';
my (%ip_interface, %sip_sig, %sip_trunk, %static_route);

open (OUT,">$out_file") or die "Couldn't create $out_file, $!\n";
print OUT "remoteServer,ipAddress,mode\n";

open (IN,$in_file) or die "Couldn't open $in_file, $!\n";
while(<IN>){
    if(/set system policyServer remoteServer "(.+)" ipAddress "(.+)" portNumber "(.+)" state "(.+)" mode "(.+)" action "(.+)" transactionTimer "(.+)" keepAliveTimer "(.+)" retryTimer "(.+)" retries "(.+)" subPortNumber "(.+)"/){
        print OUT "$1,$2,$5\n";
    }
    elsif(/set addressContext "(.+)" ipInterfaceGroup "(.+)" ipInterface "(.+)" ceName "(.+)" portName "(.+)" ipAddress "(.+)" prefix "(.+)" mode "(.+)" action "(.+)" dryupTimeout "(.+)" state "(.+)" bwContingency "(.+)" vlanTag "(.+)" bandwidth "(.+)"/){
        $ip_interface{$2}->{$3} = {   
                                portName => $5,
                                ipAddress => $6,
                                prefix => $7,
                                vlanTag => $13
        };
    }
    elsif(/set addressContext "(.+)" zone "(.+)" sipSigPort "(.+)" ipInterfaceGroupName "(.+)" ipAddressV4 "(.+)" portNumber "(.+)" state "(.+) tcpConnectTimeout "(.+)" dscpValue "(.+)" tlsProfileName "(.+)" transportProtocolsAllowed "(.+)\s?"/){ 
        $sip_sig{$4}->{$2} = {
                            sipSigPort => $3,
                            ipAddressV4 => $5
        };
    }
    elsif(/set addressContext "(.+)" zone "(.+)" sipTrunkGroup "(.+)" ingressIpPrefix "(.+)" ".+"/){ 
        push (@{$sip_trunk{$2}->{$3}}, $4);
    }
    elsif(/set addressContext ".+" staticRoute "(.+)" "(.+)" "(.+)" "(.+)" "(.+)" preference .+/){
        $static_route{$4}->{$5} = {
                                ipaddress => $1,
                                prefix => $2,
                                nexthop => $3
        };
    }
}
close IN;

print OUT "\nipInterfaceGroup,ipInterface,portName,ipAddress,prefix,vlanTag,staticRouteIP,staticRoutePrefix,staticRouteNexthop,zone,sipSigPort,ipAddressV4,sipTrunkGroup,ingressIpPrefix";

foreach my $grp (keys %ip_interface){
    foreach my $interface (keys %{$ip_interface{$grp}}){
        print OUT "\n$grp,$interface,$ip_interface{$grp}->{$interface}->{portName},$ip_interface{$grp}->{$interface}->{ipAddress},$ip_interface{$grp}->{$interface}->{prefix},$ip_interface{$grp}->{$interface}->{vlanTag},$static_route{$grp}->{$interface}->{ipaddress},$static_route{$grp}->{$interface}->{prefix},$static_route{$grp}->{$interface}->{nexthop}";
        my ($flag_z, $flag_s) = (0,0);
        foreach my $zone (keys %{$sip_sig{$grp}}){
            print OUT "\n,,,,,,,," if($flag_z);
            print OUT ",$zone,$sip_sig{$grp}->{$zone}->{sipSigPort},$sip_sig{$grp}->{$zone}->{ipAddressV4}";
            $flag_z = 1;
            foreach my $sipTrunkGroup (keys %{$sip_trunk{$zone}}){
                print OUT "\n,,,,,,,,,,," if($flag_s);
                $flag_s = 1;
                print OUT ",$sipTrunkGroup,".join(',',@{$sip_trunk{$zone}->{$sipTrunkGroup}});
            }
            $flag_s=0;
        }
    }
}

close OUT;

print "\n\nCheck the csv file, $out_file \n\n";

