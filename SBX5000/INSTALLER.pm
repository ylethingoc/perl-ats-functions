package SonusQA::SBX5000::INSTALLER;

use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use REST::Client;
use MIME::Base64;
use JSON;
use URI;
use Data::Dumper;

use SonusQA::Utils;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; #using for sbc installation, to avoid ssl verification

my $username = 'admin';
my @passwords = ('Sonus@123', 'admin');
my $client = REST::Client->new();
$client->getUseragent()->ssl_opts(verify_hostname => 0) if ($client->getUseragent()->can('ssl_opts'));
$client->getUseragent()->ssl_opts(SSL_verify_mode => 0) if ($client->getUseragent()->can('ssl_opts'));

my %build_server = (
    'WF' => 'slate',
    'IN' => 'water'
);

=pod

=head3 SonusQA::SBX5000::INSTALLER::doInstallation()

    DESCRIPTION:

    This subroutine do the installation. It will support both iso and application installation. 
	iso installation is doing using '/sonus/p4/bin/isoSbx'. Refer http://wiki.sonusnet.com/display/SBXPROJ/SBX+ISO+Installation+Automation+and+Improvement  
	Application installation is via REST. 

=over
	
=item ARGUMENTS:

	Mandatory :
		-build_path => complete path of '.iso' or '.tar.gz' file . (e.g.: /sonus/ReleaseEng/Images/SBX5000/V05.00.00A093/sbc-V05.00.00A093-connexip-os_03.00.00-A093_amd64.iso or /sonus/ReleaseEng/Images/SBX5000/V05.00.00A093/sbc-V05.00.00-A093.x86_64.tar.gz)
        -primary_sbx_alias	=> Test Bed Element Alias of primary SBX

	Optional:
        -secondary_sbx_alias =>	Test Bed Element Alias of secondary SBX, if its a HA pair
		-epsx_build_path => complete path of epsx build file (e.g.: /sonus/ReleaseEng/Images/EPX/V09.03.00R000/ePSX-V09.03.00R000.ova)
		-build_location => build server location abbreviation, only if we need to install epsx. See %build_server hash for all the avaible servers. (e.g.: WF for westford, IN for India)

=item PACKAGE

    SonusQA::SBX5000:INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    1 => on success
	0 => on failure

=item EXAMPLE(s)

	unless(SonusQA::SBX5000::INSTALLER::doInstallation('-build_path' => '/sonus/ReleaseEng/Images/SBX5000/V05.00.00A093/sbc-V05.00.00-A093.x86_64.tar.gz', '-primary_sbx_alias' => 'sbx51-21', '-secondary_sbx_alias' => 'sbx51-26', '-build_location' => 'WF')){
        $logger->error(__PACKAGE__ . ".$sub_name: SBX installation failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub doInstallation{
	my %args = @_;
	
	my $sub_name = "doInstallation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");


	unless( $args{-build_path} ){
        $logger->error(__PACKAGE__. ".$sub_name: Mandatory argument '-build_path' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }


    my $primarySbxAliasData;
    if($args{-primary_sbx_tms_data}){
        $primarySbxAliasData = $args{-primary_sbx_tms_data};
    }
    elsif($args{-primary_sbx_alias}){
        $logger->debug(__PACKAGE__. ".$sub_name: Getting tms data from tms alias '$args{-primary_sbx_alias}'");
	    $primarySbxAliasData = SonusQA::Utils::resolve_alias($args{-primary_sbx_alias});
    }
    else{
        $logger->error(__PACKAGE__.":$sub_name Either '--primary_sbx_tms_data' or '-primary_sbx_alias' is mandatory.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
	
	my $primarySbxIp = $primarySbxAliasData->{MGMTNIF}->{1}->{IP};
	
	my $systemName = $primarySbxAliasData->{NODE}->{1}->{HOSTNAME};	
	my $primarySbxHostname = $primarySbxAliasData->{CE}->{1}->{HOSTNAME};


    my ($secondarySbxAliasData, $secondarySbxIp, $secondarySbxHostname);


    if($args{-secondary_sbx_tms_data}){
        $secondarySbxAliasData = $args{-secondary_sbx_tms_data};
    }
    elsif($args{-secondary_sbx_alias}){
	    $secondarySbxAliasData = SonusQA::Utils::resolve_alias($args{-secondary_sbx_alias});
    }
	$secondarySbxIp = $secondarySbxAliasData->{MGMTNIF}->{1}->{IP};
	$secondarySbxHostname = $secondarySbxAliasData->{CE}->{1}->{HOSTNAME};    

	my $build;
							  
	if($args{-build_path} =~ /([a-zA-Z]+)\-([^-]+)\-*([ARSFEB]\d{3})/){
		$build = "$1_$2-$3";		
        $logger->info(__PACKAGE__ . ".$sub_name: Parsed the build ($build) from build file name ($args{-build_path})");
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub_name: Build file name is not valid. Valid format is '[a-zA-Z]+\-[^-]+\-*[ARSFEB]\\d{3}.+'");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
	

	if($args{-build_path} =~/\.iso$/){
        my (%pids, $pid, $out_file);
       	($pid, $out_file) = &doISOinstallation(-tms_data => $primarySbxAliasData, -iso => $args{-build_path});
	unless($pid){
            $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation on primary SBX ($primarySbxIp) failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
		$logger->info(__PACKAGE__ . ".$sub_name: ISO Installation on primary SBX ($primarySbxIp) started, process id is $pid.");
        $pids{$pid} = $out_file;
		
        if($secondarySbxIp){
            ($pid, $out_file) = &doISOinstallation(-tms_data => $secondarySbxAliasData, -iso => $args{-build_path});
            unless($pid){
                $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation on secondary SBX ($secondarySbxIp) failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }
			$logger->info(__PACKAGE__ . ".$sub_name: ISO Installation on secondary SBX ($secondarySbxIp) started, process id is $pid.");
            $pids{$pid} = $out_file;
        }
        unless(&waitforISOinstallation(%pids)){
            $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    if(($args{-build_path} =~/\.tar\.gz$/) or ($args{-epsx_build_path})){
        $logger->info(__PACKAGE__ . ".$sub_name: copying build to primary SBX ($primarySbxIp)");

        unless(&SonusQA::SBX5000::INSTALLER::copyBuildAndVerify(
                    -buildpath => $args{-build_path},
                    -ePSXbuildpath => $args{-epsx_build_path},
                    -sbxip       => $primarySbxIp,
                    -sbxusername => 'root',
                    -sbxpassword => $primarySbxAliasData->{LOGIN}->{1}->{ROOTPASSWD} || 'sonus1')){
                $logger->error(__PACKAGE__ . ".$sub_name: copying build to primary SBC ($primarySbxIp) failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
        }

        if($secondarySbxIp){
            $logger->info(__PACKAGE__ . ".$sub_name: copying build to secondary SBX ($secondarySbxIp).");

            unless(&SonusQA::SBX5000::INSTALLER::copyBuildAndVerify(
                    -buildpath   => $args{-build_path},
                    -ePSXbuildpath => $args{-epsx_build_path},
                    -sbxip       => $secondarySbxIp,
                    -sbxusername => 'root',
                    -sbxpassword => $secondarySbxAliasData->{LOGIN}->{1}->{ROOTPASSWD} || 'sonus1')){
                $logger->error(__PACKAGE__ . ".$sub_name: copying build to secondary SBC ($secondarySbxIp) failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }
        }
    }

	unless(&checkBuild(-tms_data => $primarySbxAliasData, -build => $build)){
        $logger->error(__PACKAGE__ . ".$sub_name: Build ($build) doesn't exist in primary SBX ($primarySbxIp).");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    if($secondarySbxIp){
        unless(&checkBuild(-tms_data => $secondarySbxAliasData, -build => $build)){
            $logger->error(__PACKAGE__ . ".$sub_name: Build ($build) doesn't exist in secondary SBX ($secondarySbxIp).");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    my $installQuery1 = &validateInstallFields(-tms_data => $primarySbxAliasData, -build => $build);
    unless($installQuery1){
        $logger->error(__PACKAGE__ . ".$sub_name: Validating install fields failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
	
	
	my ($status1, $status2, $ready_seen1, $ready_seen2);
	
	if($secondarySbxIp){
        my $installQuery2 = "$installQuery1&haState=2&sysName=$systemName&locName=$secondarySbxHostname&peerName=$primarySbxHostname&role=2";
        $installQuery1.= "&haState=2&sysName=$systemName&locName=$primarySbxHostname&peerName=$secondarySbxHostname&role=1";

        $logger->debug("installQuery1 : '$installQuery1'");
        $logger->debug("installQuery2 : '$installQuery2'");
        $logger->info("Installing on primary SBX ($primarySbxIp)");

        unless(&startInstallation('-sbx_ip' => $primarySbxIp, '-install_query' => $installQuery1)){
                $logger->error(__PACKAGE__ . ".$sub_name: Installation on primary SBX ($primarySbxIp) failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 15 Seconds before installing on secondary SBX.");
        sleep 15;

        $logger->info(__PACKAGE__ . ".$sub_name: Installing on seconday SBX ($secondarySbxIp)");
        unless(&startInstallation('-sbx_ip' => $secondarySbxIp, '-install_query' => $installQuery2)){
            $logger->error(__PACKAGE__ . ".$sub_name: Installation on secondary SBX ($secondarySbxIp) failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }
    else{
        $status2 = 'ready';
        $ready_seen2 = 2;
        $installQuery1.= "&haState=1&sysName=$systemName&locName=$primarySbxHostname&peerName=none&role=1";
        $logger->debug("installQuery1 : '$installQuery1' ");
        $logger->info("Installing on primary SBX ($primarySbxIp)");

        unless(&startInstallation('-sbx_ip' => $primarySbxIp, '-install_query' => $installQuery1)){
            $logger->error(__PACKAGE__ . ".$sub_name: Installation on primary SBX ($primarySbxIp) failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    #Get Status
    # will wait max 18 mins (18 * 60 = 1080s) to complete the installation
    my ($delay, $max_delay) = (0, 1080);
    my $error=0;
    $logger->info(__PACKAGE__ . ".$sub_name: Checking the status of installation of an interval of 10s. We will wait maximum ${max_delay}s.");

    #we check the status to be 'ready' twice to wait if reboot happens after first 'ready'
    while($delay <= $max_delay && ($ready_seen1 < 2 || $ready_seen2 < 2)){
        $delay+=10;
        $logger->info("Waiting 10 Seconds for checking status (delay = $delay)");
        sleep 10;
        if($ready_seen1 < 2){
            $status1 = &getStatus('-sbx_ip' => $primarySbxIp);
            unless($status1){
                $logger->error(__PACKAGE__ . ".$sub_name: Error during primary sbx($primarySbxIp) installation.");
                $error = 1;
                last;
            }
            if($status1=~/ready/i){
                $ready_seen1++;
                $logger->info(__PACKAGE__ . ".$sub_name: primary sbx($primarySbxIp) is in ready state ($ready_seen1)");
            }
            elsif($status1 eq 'connect failed'){
                $logger->info(__PACKAGE__ . ".$sub_name: Not able to connect to primary sbx($primarySbxIp). Looks like it went for rebooting.");
            }
        }

        if($ready_seen2 < 2){
            $status2 = &getStatus('-sbx_ip' => $secondarySbxIp);
            unless($status2){
                $logger->error(__PACKAGE__ . ".$sub_name: Error during secondary sbx($secondarySbxIp) installation.");
                $error = 1;
                last;
            }

            if($status2=~/ready/i){
                $ready_seen2++;
                $logger->info(__PACKAGE__ . ".$sub_name: Secondary sbx($secondarySbxIp) is active now ($ready_seen2)");
            }
            elsif($status2 eq 'connect failed'){
                $logger->info(__PACKAGE__ . ".$sub_name: Not able to connect to primary sbx($primarySbxIp). Looks like it went for rebooting.");
            }
        }
    }

    if($status1 =~/ready/i && $status2=~/ready/i){
        unless(SonusQA::SBX5000::SBX5000HELPER::enableSsh(-bmc_ip => $primarySbxAliasData->{BMC_NIF}->{1}->{IP})){
            $logger->error(__PACKAGE__ . ".$sub_name: Enabling SSH failed for $primarySbxIp (-bmc_ip => $primarySbxAliasData->{BMC_NIF}->{1}->{IP}).");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }

        if($secondarySbxIp){
            unless(SonusQA::SBX5000::SBX5000HELPER::enableSsh(-bmc_ip => $secondarySbxAliasData->{BMC_NIF}->{1}->{IP})){
                $logger->error(__PACKAGE__ . ".$sub_name: Enabling SSH failed for $secondarySbxIp (-bmc_ip => $secondarySbxAliasData->{BMC_NIF}->{1}->{IP}).");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }
        }


        # install ePSX if personality == 2
        # timezone=27&version=sbc_V05.00.00-A045&ntpServer=10.54.51.16&personality=1&systemType=standardSBC&sigFail=1
        if($installQuery1=~/personality=2/){
            $logger->info(__PACKAGE__ . ".$sub_name: personality is set as 2, so starting ePSX installation for primary sbx ($primarySbxIp).");

            my $epsx_testbed_alias = $primarySbxAliasData->{EPXTESTBED}->{1}->{NAME};
			(my $epsx_build = $args{-epsx_build_path}) =~s/.+\/(.+\.ova)$/$1/;
			
            unless(&installEPX('-sbx_ip' => $primarySbxIp, '-epsx_testbed_alias' => $epsx_testbed_alias, '-epsx_build' => $epsx_build)){
                $logger->error(__PACKAGE__ . ".$sub_name: installing ePSX failed for primary sbx ($primarySbxIp).");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }

            if($secondarySbxIp){
                #ePSX on secondary sbx can install only if primary sbx is 'running'
                #so checking the app status of primary sbx

                my $header1 = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[0])};
                my $header2 = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[1])};



                my $app_state;
                $delay = 0;
                while($delay < 600){ # maximum 10 minutes ??
                    $logger->info(__PACKAGE__ . ".$sub_name: sleeping 30s");
                    sleep 30;
                    $delay+=30;

                    #getAppStatus
                    my $response;
                    unless($response = &processREST('-url' => "https://$primarySbxIp:444/pm/api/Admin/getAppStatus")){
                        $logger->info(__PACKAGE__ . ".$sub_name : getAppStatus for $primarySbxIp failed.");
                        next;
                    }

                    #$logger->info(__PACKAGE__ . ".$sub_name: getAppStatus : Response content: ". Dumper($response));

                    $app_state = $response->{results}->{state};
                    if($app_state =~/running/i){
                        $logger->info(__PACKAGE__ . ".$sub_name: Application in primary sbx ($primarySbxIp) is running now.");
                        last;
                    }
                }

                unless($app_state =~/running/i){
                    $logger->error(__PACKAGE__ . ".$sub_name : Application in primary sbx ($primarySbxIp) is not yet started running (AppStatus: $app_state). So can't install ePSX on secondary sbx ($secondarySbxIp)");
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                    return 0;
                }

                $epsx_testbed_alias = $secondarySbxAliasData->{EPXTESTBED}->{1}->{NAME};
                $logger->info(__PACKAGE__ . ".$sub_name: Starting ePSX installation on seconday sbx ($secondarySbxIp).");

                unless(&installEPX('-sbx_ip' => $secondarySbxIp, '-epsx_testbed_alias' => $epsx_testbed_alias, '-epsx_build' => $epsx_build)){
                    $logger->error(__PACKAGE__ . ".$sub_name: installing ePSX failed on seconday sbx ($secondarySbxIp).");
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                    return 0;
                }
            }
        }
    }

    if($error == 1){
        $logger->info(__PACKAGE__ . ".$sub_name: Installation is failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    unless($status1 =~/ready/i){
        $logger->error(__PACKAGE__ . ".$sub_name: Installation on primary sbx($primarySbxIp) is not completed with in ${max_delay}s. status: $status1");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    unless($status2=~/ready/i){
        $logger->error(__PACKAGE__ . ".$sub_name: Installation on secondary sbx($secondarySbxIp) is not completed with in ${max_delay}s. status: $status2");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }


    $ENV{'I_JUST_ISOd'} = 1; # 1 = I just did iso skip cleanStartSBX for first suite, 
    $logger->info(__PACKAGE__ . ".$sub_name: Installation is completed successfully.");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return 1;	
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::waitforISOinstallation()

    DESCRIPTION:

    This subroutine wait maximum 1 hour for the background installation process to complete. Once it completes it returns 0, if the output file contains any errorm else it returns 1. Also it delete the file. If the process is not completed in 1 hour, it kills the process and return 0.

=over

=item ARGUMENTS:

    Mandatory :
    A hash with pid as the key and output file name as the value. (E.G.: %pids = ($pid => $out_file);)

    Optional:
    None

=item PACKAGE:

    SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED

	None

=item Returns

    1 => on success
    0 => on failure

=item EXAMPLE(s)
    
    unless(SonusQA::SBX5000::INSTALLER::waitforISOinstallation(%pids)){
        $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub waitforISOinstallation{
    my %args = @_;

    my $sub_name = "waitforISOinstallation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    my ($cnt, $error);

    while($cnt <= 3600){ #waits max 1 hour
        $logger->info(__PACKAGE__ . ".$sub_name: checking pidof expect.");
        my $out = `pidof expect`;
        chomp($out);
        my @pids = split(/\s+/, $out);
    
        foreach my $pid (keys %args){
            unless(grep {$pid} @pids){
                my @out = `cat $args{$pid}`;
                $logger->info(__PACKAGE__ . ".$sub_name: Process $pid. Output was : @out");
                unlink $args{$pid};
                delete $args{$pid};
                if(grep {/ERROR/i} @out){
                    $logger->error(__PACKAGE__ . ".$sub_name: Got error for process $pid. Output: @out");
                    $error = 1;
                }
            }
        }

        last unless(keys %args);
        $cnt+=60;
        $logger->info(__PACKAGE__ . ".$sub_name: Sleeping 60s.");
        sleep 60;
    } 

    if(keys %args || $error){
        foreach my $pid (keys %args){
            $logger->error(__PACKAGE__ . ".$sub_name: Installation is not completed in 1 hour for process id, $pid. So killing it.");
            `kill $pid`;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: Installation completed succesfully for all the process.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
        return 1;
    }
}

=pod

=head2 SonusQA::SBX5000::INSTALLER::doISOinstallation()

    DESCRIPTION:

    This subroutine do the iso installation, using '/sonus/ReleaseEng/Images/SBX5000/iso_process/isoSbx' in background, and returns the process id and output file name. 
	Refer http://wiki.sonusnet.com/display/SBXPROJ/SBX+ISO+Installation+Automation+and+Improvement  	

=over
	
=item ARGUMENTS:

	Mandatory :
		-iso => complete path of '.iso'. (e.g.: /sonus/ReleaseEng/Images/SBX5000/V05.00.00A093/sbc-V05.00.00A093-connexip-os_03.00.00-A093_amd64.iso)
        -tms_data => Resolved test bed element alias hash
		or
		-tms_alias => Test Bed Element Alias of SBX

	Optional:
        Either -tms_data or -tms_alias is mandatory

=item PACKAGE:

    SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    ($pid, $out_file) => on success
	0 => on failure

=item EXAMPLE(s)

    my ($pid, $out_file) = SonusQA::SBX5000::INSTALLER::doISOinstallation(-tms_alias => 'sbx51-21', -iso => '/sonus/ReleaseEng/Images/SBX5000/V05.00.00A093/sbc-V05.00.00A093-connexip-os_03.00.00-A093_amd64.iso');
    unless($pid){
        $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation on SBX failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub doISOinstallation{
    my %args = @_;

    my $sub_name = "doISOinstallation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");


    unless( defined $args{-iso} ){
        $logger->error(__PACKAGE__. ".$sub_name: Mandatory argument '-iso' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    unless (-e $args{-iso}){
        $logger->error(__PACKAGE__.":$sub_name iso ($args{-iso}) is not existing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    #tms_data	
    my $sbx_alias_hash;
    if($args{-tms_data}){
        $sbx_alias_hash = $args{-tms_data}; 
    }
    elsif($args{-tms_alias}){
        $logger->debug(__PACKAGE__. ".$sub_name: Getting tms data from tms alias '$args{-tms_alias}'");
        $sbx_alias_hash = SonusQA::Utils::resolve_alias($args{-tms_alias});
    }
    else{
        $logger->error(__PACKAGE__. ".$sub_name: Either '-tms_alias' or '-tms_data' is mandatory.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $mgmt_ip = $sbx_alias_hash->{MGMTNIF}->{1}->{IP};
    my $root_password = $sbx_alias_hash->{LOGIN}->{1}->{ROOTPASSWD} || 'sonus1';
    my $bmc_ip = $sbx_alias_hash->{BMC_NIF}->{1}->{IP};
    my $bmc_password = $sbx_alias_hash->{BMC_NIF}->{1}->{PASSWD} || 'superuser';

    unless($bmc_ip){
        $logger->error(__PACKAGE__.":$sub_name Couldn't get BMC IP from tms. Set BMC_NIF->1->IP for tms_alias, $args{-tms_alias}.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $out_file = "$ENV{ HOME }/iso_out_${mgmt_ip}_". time;
    # See "isoSbx -h" for list of options used.
    my $cmd = "/sonus/p4/bin/isoSbx -i $args{-iso} -r $root_password -b $bmc_password -M $mgmt_ip -B $bmc_ip -e 2>&1 > $out_file".' & echo $!';


    $logger->debug(__PACKAGE__ . ".$sub_name: executing iso installation command: $cmd");

    my $pid = `$cmd`;
    chomp($pid);
    $logger->debug(__PACKAGE__ . ".$sub_name: pid: $pid");

    if ($pid=~/(\d+)/){
        $logger->debug(__PACKAGE__ . ".$sub_name: got the process id, $1");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
        return($1, $out_file);
    }
    else{
        $logger->debug(__PACKAGE__ . ".$sub_name: couldn't get the process id.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return(0);
    }
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::checkBuild

    DESCRIPTION:

    This subroutine check whether the passed build is existing in SBC or not using the REST API, listInstallCandidates.  	

=over
	
=item ARGUMENTS:

	Mandatory :
		-build => existing sbc build name (e.g.: sbc_V05.00.00-A093)
        -tms_data => Resolved test bed element alias hash
		or
		-tms_alias => Test Bed Element Alias of SBX

	Optional:
        Either -tms_data or -tms_alias is mandatory

=item PACKAGE:

    SonusQA::SBX5000:INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    1 => on success
	0 => on failure

=item EXAMPLE(s)

	unless(SonusQA::SBX5000:INSTALLER::checkBuild(-tms_alias => 'sbx51-21', -build => 'sbc_V05.00.00-A093')){
        $logger->error(__PACKAGE__ . ".$sub_name: Build ($build) doesn't exist in SBX.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub checkBuild {
    my %args = @_;

    my $sub_name = "checkBuild";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless( defined $args{-build} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-build' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $sbx_alias_hash;
    if($args{-tms_data}){
        $sbx_alias_hash = $args{-tms_data};
    }
    elsif($args{-tms_alias}){
        $logger->debug(__PACKAGE__. ".$sub_name: Getting tms data from tms alias '$args{-tms_alias}'");
        $sbx_alias_hash = SonusQA::Utils::resolve_alias($args{-tms_alias});
    }
    else{
        $logger->error(__PACKAGE__.":$sub_name Either '-tms_alias' or '-tms_data' is mandatory.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }


    my $mgmt_ip = $sbx_alias_hash->{MGMTNIF}->{1}->{IP};
    my $host_name = $sbx_alias_hash->{CE}->{1}->{HOSTNAME};
    my $system_name = $sbx_alias_hash->{NODE}->{1}->{HOSTNAME};

    if(($host_name eq $system_name)){
        $logger->error(__PACKAGE__ . ".$sub_name : SBX Host Name ($host_name) and System Name($system_name) are same, hence can't proceed..");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $url = "https://$mgmt_ip:444/pm/api/SbcInstall/listInstallCandidates";
    $logger->debug(__PACKAGE__ . ".$sub_name: API URL: $url");
	my $response;
	
	unless($response = &processREST('-url' => $url)){
        $logger->error(__PACKAGE__ . ".$sub_name : listInstallCandidates for $mgmt_ip failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Response Body " . Dumper($response));

    my $FLAG=0;
    foreach my $row (@{$response->{'aaData'}}) {
        if($row->[1] eq $args{'-build'}){
            $FLAG=1;
            last;
        }
    }

    if($FLAG == 1){
        $logger->info(__PACKAGE__ . ".$sub_name: Found build ($args{-build})");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
        return 1;
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't find the build ($args{-build})");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
        return 0;
    }
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::validateInstallFields()

    DESCRIPTION:

    This subroutine validate the installation fields and return the installation query on success, using the REST API, getInstallForm.  	

=over
	
=item ARGUMENTS:

	Mandatory :
		-build => existing sbc build name (e.g.: sbc_V05.00.00-A093)
        -tms_data => Resolved test bed element alias hash
		or
		-tms_alias => Test Bed Element Alias of SBX

	Optional:
        Either -tms_data or -tms_alias is mandatory

=item PACKAGE:

    SonusQA::SBX5000:INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    install query 	=> on success
	0				=> on failure

=item EXAMPLE(s)

	my $installQuery = SonusQA::SBX5000:INSTALLER::validateInstallFields(-tms_alias => 'sbx51-21', -build => 'sbc_V05.00.00-A093');
    unless($installQuery){
        $logger->error(__PACKAGE__ . ".$sub_name: Validating install fields failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub validateInstallFields{
    my %args = @_;

    my $sub_name = "validateInstallFields";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless( defined $args{-build} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-build' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $sbx_alias_hash;
    if($args{-tms_data}){
        $sbx_alias_hash = $args{-tms_data};
    }
    elsif($args{-tms_alias}){
        $logger->debug(__PACKAGE__. ".$sub_name: Getting tms data from tms alias '$args{-tms_alias}'");
        $sbx_alias_hash = SonusQA::Utils::resolve_alias($args{-tms_alias});
    }
    else{
        $logger->error(__PACKAGE__.":$sub_name Either '-tms_alias' or '-tms_data' is mandatory.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $mgmt_ip = $sbx_alias_hash->{MGMTNIF}->{1}->{IP};
    my $host_name = $sbx_alias_hash->{CE}->{1}->{HOSTNAME};
    my $system_name = $sbx_alias_hash->{NODE}->{1}->{HOSTNAME};


    my $url = "https://$mgmt_ip:444/pm/api/SbcInstall/getInstallForm?id=$args{-build}";
    $logger->debug(__PACKAGE__ . ".$sub_name: API URL: $url");
	my $response;
	
	unless($response = &processREST('-url' => $url)){
        $logger->error(__PACKAGE__ . ".$sub_name : getInstallForm for $mgmt_ip failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
	
    $logger->debug(__PACKAGE__ . ".$sub_name: Response Body " . Dumper($response));


    # we will skip following fields during the validation.
    # we will get those values just before the installation from Testbed
    # so that we will get currect values even if there is a switch over before installation
    my %skip_field = (haState =>1, sysName => 1, locName =>1,  peerName =>1,  role =>1);

    my %user_input = (
        sbctype => 'isbc', # Fix for TOOLS-11416. New field is introduced in cloud/main merge builds (got it in 'sbc_V06.01.00-A001'). Setting it as isbc for now, we have to think for D-SBC (options are ' isbc', ' ssbc', ' msbc'. )
        personality => ($sbx_alias_hash->{EPXTESTBED}->{1}->{NAME}) ? 2 : 1, #1-ERE or external PSX, 2-ePSX
        ntpServer => $sbx_alias_hash->{NTP}->{1}->{IP},
        timezone => $sbx_alias_hash->{NTP}->{1}->{ZONEINDEX},
        emarest => 'enabled',
        emacore => 'enabled',
        troubleshooting => 'enabled'
    );

    my %install_data=();
    foreach my $result(@{$response->{'results'}}){
        next if($skip_field{$result->{'name'}} );

        if($result->{'type'} eq "hidden"){
            $install_data{$result->{'name'}}=$result->{'value'};
        }
        elsif($result->{'opts'}){
            foreach my $hash(@{$result->{'opts'}}){
                if($user_input{$result->{'name'}} eq $hash->{'value'}){
                    $install_data{$result->{'name'}}=$user_input{$result->{'name'}};
                    last;
                }
                else{
                    $install_data{$result->{'name'}}="NULL";
                }
            }
        }
        else{
            $install_data{$result->{'name'}}= $user_input{$result->{'name'}} || 'NULL';
        }
    }

    my $flag=0;
    my $query;
    foreach my $key ( keys %install_data ) {
        if($install_data{$key} eq  'NULL'){
            $flag=1;
            $logger->error("'$key' doesn't have a valid value ($user_input{$key}).");
        }
        else{
            $query.="$key=".$install_data{$key}.'&';
        }
    }
    chop $query; #removing the last character '&'
     if($flag == 1){
        $logger->error("Installation validation failed");
        $logger->info(" <-- Leaving Sub[0]");
        return 0;
    }
    else{
        $logger->info("Installation validation is success!");
        $logger->info("Leaving Sub[1]-");
        return $query;
    }
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::startInstallation()

    DESCRIPTION:

    This subroutine starts the installation, using the REST API 'startInstall'.  	

=over
	
=item ARGUMENTS:

	Mandatory :

		-sbx_ip => management ip of the sbx
        -install_query => complete installation query (e.g.: timezone=19&version=sbc_V05.00.00-A093&ntpServer=10.1.1.2&personality=1&systemType=standardSBC&sigFail=1&haState=2&sysName=SBX51-21&locName=sbx51-21.eng.sonusnet.com&peerName=sbx51-26.eng.sonusnet.com&role=1 )
		
	Optional:
	
	None
	
=item PACKAGE:

    SonusQA::SBX5000:INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    1 => on success
	0 => on failure

=item EXAMPLE(s)

	unless(SonusQA::SBX5000:INSTALLER::startInstallation('-sbx_ip' => '10.6.82.151', '-install_query' => 'timezone=19&version=sbc_V05.00.00-A093&ntpServer=10.1.1.2&personality=1&systemType=standardSBC&sigFail=1&haState=2&sysName=SBX51-21&locName=sbx51-21.eng.sonusnet.com&peerName=sbx51-26.eng.sonusnet.com&role=1')){
		$logger->error(__PACKAGE__ . ".$sub_name: Installation on SBX.");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
		return 0;
	}

=back

=cut

sub startInstallation{
     my %args = @_;

    my $sub_name = "startInstallation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    unless( $args{-sbx_ip} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-sbx_ip' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
    
    unless( $args{-install_query} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-install_query' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $url = "https://$args{-sbx_ip}:444/pm/api/SbcInstall/startInstall";
	
    my $response;
	unless($response = &processREST('-url' => $url, '-method' => 'POST', '-query' => $args{-install_query})){
		$logger->error(__PACKAGE__ . ".$sub_name: Installation on SBX ($args{-sbx_ip}) failed.");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
		return 0;
	}

    $logger->info(__PACKAGE__ . ".$sub_name: Installation started successfully");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return 1;
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::getStatus()

    DESCRIPTION:

    This subroutine is used to get the status of SBX installation using REST api, 'SbcInstall/getStatus'

=over

=item ARGUMENTS:

    Mandatory :
    -sbx_ip         => Management ip of SBX

    Optional:
    None

=item PACKAGE:

    SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    status 	=> on success
    0 		=> on failure

=item EXAMPLES(s)

	my $status = SonusQA::SBX5000::INSTALLER::getStatus('-sbx_ip' => '10.6.82.151');

=back

=cut

sub getStatus{
    my %args = @_; 

    my $sub_name = "getStatus";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    unless( $args{-sbx_ip} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-sbx_ip' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $header1 = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[0])};
    my $header2 = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[1])};
    
    # The underlying LWP/HTTP modules will generate a 500 ersponse for certain errors with connections - catch those for special handling (retry)
    my $connectFailedRegex = "(connection refused|connect failed|connection timed out|Server closed connection without sending any data back|No route to host)";
    
    $client->GET("https://$args{-sbx_ip}:444/pm/api/SbcInstall/getStatus", $header1);
    my $response_code = $client->responseCode();
    $logger->info(__PACKAGE__ . ".$sub_name: Response Code : ".$response_code);

    my $response_json=$client->responseContent();
    
	my $response;	
	
    eval{
        $response= decode_json $response_json;
    };
    if($@){
        $logger->info(__PACKAGE__ . ".$sub_name : response: $response_json");
        if($response_json =~/$connectFailedRegex/i){
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
            return 'connect failed';
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    if($response->{'error'} =~ /Authentication error/i){
	$logger->error(__PACKAGE__. ".$sub_name: Got authentication error.. with password: $passwords[0]");
        $logger->info(__PACKAGE__ . ".$sub_name: Got authentication error..!! Trying with the second password");
        @passwords = reverse @passwords; # Flip the order so we try the presumably 'good' one first next time
        $client->GET("https://$args{-sbx_ip}:444/pm/api/SbcInstall/getStatus", $header2);
        $response_code = $client->responseCode();
        $logger->info(__PACKAGE__ . ".$sub_name: Response Code : ".$response_code);
        $response_json=$client->responseContent();
        eval{
            $response= decode_json $response_json;
        };
        if($@){
            $logger->info(__PACKAGE__ . ".$sub_name : response: $response_json");
            if($response_json =~/$connectFailedRegex/i){
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
                    return 'connect failed';
            }else{
                    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                    return 0;
            }
        }
    }

    if($response->{'error'}){
        $logger->error(__PACKAGE__ . ".$sub_name: Error during installation : ". $response->{error});
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
    elsif($response_code != 200){
        $logger->error(__PACKAGE__ . ".$sub_name: Got $response_code response code. So exiting.");
        $logger->info(__PACKAGE__ . ".$sub_name: Response content: ". Dumper($response));
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

	
    $logger->info(__PACKAGE__ . ".$sub_name: status : ". Dumper($response->{'results'}->{'status'}));
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return(ref $response->{'results'}->{'status'} eq "HASH" ? $response->{'results'}->{'status'}->{'status'} : $response->{'results'}->{'status'});
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::installEPX()

    DESCRIPTION:

    This subroutine is used to do ePSX installation using REST api.
    It will do following process:
        - Virtualization/listInstalledVM: List currently installed virtual machines
        - delete ePSX if its existing
        - Virtualization/listOVA : List Virtual Machine Containers available for install
        - Virtualization/unpackOVA :  Unpack the selected virtual machine container for installation
        - Virtualization/getUnpackStatus : Retrieve the status of the virtual machine container unpack process
        - Virtualization/getConfigOptions : Retrieve a list of configuration options
        - Virtualization/installOVA : Validate supplied configuration paramaters and start installation. Input parameters are conditional to the configuration type selected. Options can be listed with the 'getConfigOptions' method.
        - Virtualization/getInstallStatus : Retrieve status of the virtual machine installation operation


    It is calling from installSBC(), after the installation of SBC.

    Note:

=over

=item ARGUMENTS:

    Mandatory :
    -sbx_ip             => Management ip of SBX
    -epsx_testbed_alias  => ePSX Test Bed Alias
    -epsx_build      => ePSX build name

    Optional:
    None

=item PACKAGE:

    SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns

    1 => on success
    0 => on failure

=item EXAMPLES(s)

	unless(SonusQA::SBX5000::INSTALLER::installEPX('-sbx_ip' => '10.6.82.151', '-epsx_testbed_alias' => 'sbx51-21-epsx', '-epsx_build' => 'ePSX-V09.03.00A031.ova')){
		$logger->error(__PACKAGE__ . ".$sub_name: installing ePSX failed");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
		return 0;
	}

=back

=cut

sub installEPX{
    my %args = @_;

    my $sub_name = "installEPX";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    unless( $args{-sbx_ip} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-sbx_ip' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    unless( $args{-epsx_testbed_alias} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-epsx_testbed_alias' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    unless( $args{-epsx_build} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-epsx_build' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }


    my ($sbxIp, $epsx_testbed_alias, $ePSXbuild) = ($args{-sbx_ip}, $args{-epsx_testbed_alias}, $args{-epsx_build});


    my $epsx_testbed_alias_data = SonusQA::Utils::resolve_alias($epsx_testbed_alias);

	my $install_param = {
		mgt0_ip => $epsx_testbed_alias_data->{MGMTNIF}->{1}->{IP},
		mgt0_net => 24,
		mgt1_ip => $epsx_testbed_alias_data->{MGMTNIF}->{2}->{IP},
		mgt1_net => 24,
		epxsystemname => $epsx_testbed_alias_data->{NODE}->{1}->{NAME},
		hostname => $epsx_testbed_alias_data->{NODE}->{1}->{HOSTNAME},
		mastersysname => $epsx_testbed_alias_data->{MASTER}->{1}->{NAME},
		masteripaddress => $epsx_testbed_alias_data->{MASTER}->{1}->{IP}
	};

    $logger->debug(__PACKAGE__ . ".$sub_name : install params : ". Dumper($install_param));

    my $response;

    # listInstalledVM
    $logger->debug(__PACKAGE__ . ".$sub_name : API : listInstalledVM");

    unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/listInstalledVM")){
        $logger->error(__PACKAGE__ . ".$sub_name : listInstalledVM for $sbxIp failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Response Body for $sbxIp : ". Dumper($response));

    if($response->{iTotalRecords}){
        $logger->info(__PACKAGE__ . ".$sub_name: ePSX is already installed in $sbxIp. So deleting it ...");       

        my $sbx_root_obj;

        unless ($sbx_root_obj = SonusQA::SBX5000::SBX5000HELPER::makeRootSession( -obj_host => $sbxIp,  -obj_password => 'sonus', -root_password => 'sonus1')) {
          $logger->error(__PACKAGE__ . ": Unable to make root connection for $sbxIp" );
          return 0;
        }

        my $error = 0;
        foreach my $cmd ('sbxstop', 'ovfinstall.sh delete ePSX', 'sbxstart'){
            unless(SonusQA::SBX5000::execCmd($sbx_root_obj, $cmd)){
                $logger->error(__PACKAGE__ . ".$sub_name: Couldn't execute the command '$cmd' in $sbxIp");
                $error = 1;
                last;
            }
        }

        unless($error){
            unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/listInstalledVM")){
                $logger->error(__PACKAGE__ . ".$sub_name : listInstalledVM for $sbxIp failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }

            $logger->debug(__PACKAGE__ . ".$sub_name: listInstalledVM: Response Body for $sbxIp : ". Dumper($response));

            if($response->{iTotalRecords}){
                $logger->error(__PACKAGE__ . ".$sub_name: Installed VM in $sbxIp is not deleted successfully");   
                $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
                return 0;
            }
        }
        else{
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
            return 0;
        }
    }

    # listOVA
    # List Virtual Machine Containers available for install
    $logger->debug(__PACKAGE__ . ".$sub_name : API : listOVA");
    $logger->info(__PACKAGE__ . ".$sub_name : Checking whether the given build ($ePSXbuild) is available or not.");

    unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/listOVA")){
        $logger->error(__PACKAGE__ . ".$sub_name : listOVA for $sbxIp failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: listOVA : Response Body for SBC :$sbxIp : ". Dumper($response));

    my $ePSX_found = 0;
    #{"results":[{"type":"ePSX","version":"V09.03.00A031","filename":"ePSX-V09.03.00A031.ova"}]}
    foreach my $result (@{$response->{results}}){
        if($result->{filename} eq $ePSXbuild){
            $ePSX_found = 1;
            $logger->info(__PACKAGE__ . ".$sub_name: Found the given build ($ePSXbuild) for installation SBC :$sbxIp");
            last;
        }
    }

    unless($ePSX_found){
        $logger->error(__PACKAGE__ . ".$sub_name : Couldn't find the given build ($ePSXbuild) for installation in SBC :$sbxIp");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    # unpackOVA
    # Unpack the selected virtual machine container for installation
    $logger->debug(__PACKAGE__ . ".$sub_name : API : unpackOVA");
    $logger->info(__PACKAGE__ . ".$sub_name : Unpacking $ePSXbuild in  SBC $sbxIp");

    unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/unpackOVA?id=$ePSXbuild")){
        $logger->error(__PACKAGE__ . ".$sub_name : unpackOVA for $sbxIp failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    # getUnpackStatus
    # Retrieve the status of the virtual machine container unpack process
    $logger->debug(__PACKAGE__ . ".$sub_name : API : getUnpackStatus");

    # Max 5 mins will keep checking the status
    my $unpack_status;
    my $unpack_wait = 0;
    $logger->info(__PACKAGE__ . ".$sub_name : Checking the unpack status in SBC :$sbxIp.");
    while($unpack_wait <= 300){
        $logger->info(__PACKAGE__ . ".$sub_name : Waiting 60s");

        sleep 60;
        $unpack_wait += 60;

        unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/getUnpackStatus")){
            $logger->error(__PACKAGE__ . ".$sub_name : getUnpackStatus for $sbxIp failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: Response content: ". Dumper($response));

        #status can be active or inactive
        if($response->{results}->{status} eq 'inactive'){ #process is completed
            # checking there is any error message in 'details'
            # E.G. o/p : {"results":{"status":"inactive","details":["Set up the installation environment","Locate and unpack the package","ERROR: Package path '\/opt\/sonus\/external\/ePSX-V09.03.00S000.ova' was not found.","EXIT: Unable to locate and unpack the package"],"version":"ePSX-V09.03.00S000"}}

            if(grep {/ERROR/i} @{$response->{results}->{details}}){
                $logger->error(__PACKAGE__ . ".$sub_name : unpacking $ePSXbuild failed in SBC, $sbxIp.");
                $logger->debug(__PACKAGE__ . ".$sub_name : details :". Dumper($response->{results}->{details}));  
            }

            # E.G. success o/p:
            # {"results":{"status":"inactive","details":["SUCCESS: Package 'epx-V09.03.00A031' has been validated","Extract the guest system name, file references, etc.","Extract deployment options","Extract the guest system properties.","ProductVersion=9.0","ProductFullVersion=V09.03.00A031","WARNING: Platform support matrix has not yet been reviewed","WARNING: VM resource limits checking is not yet implemented","SUCCESS: Package 'epx-V09.03.00A031' has been unpacked and validated","EXIT: Unpack was successful"],"version":"ePSX-V09.03.00A031"}}

            $unpack_status = 1;
            last;
        }
        else{ #active => process is not completed, checking the status again
            # E.G.: {"results":{"status":"active","details":["Set up the installation environment","Locate and unpack the package","Unpacking package contents may take a while. Please wait.","Validate the package","Validating package contents may take a while. Please wait."],"version":"ePSX-V09.03.00A031"}}

            $logger->debug(__PACKAGE__ . ".$sub_name : Status is active");
            next;
        }

        }

    unless($unpack_status){
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }


    #getConfigOptions
    unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/getConfigOptions")){
        $logger->error(__PACKAGE__ . ".$sub_name : getConfigOptions for $sbxIp failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    #$logger->info(__PACKAGE__ . ".$sub_name: configOpts : ". Dumper($response->{results}->{configOpts}));

    my $master_repilca;;

    if($install_param->{mastersysname} && $install_param->{masteripaddress}){
        $logger->info(__PACKAGE__ . ".$sub_name: installing ePSX as replica mode, since mastersysname ($install_param->{mastersysname}) and masteripaddress ($install_param->{masteripaddress}) are defined");
        $master_repilca = 'r';
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: installing ePSX as master mode, since mastersysname ($install_param->{mastersysname}) or masteripaddress ($install_param->{masteripaddress}) is not defined");
        $master_repilca = 'm';
    }

     my $query;

    foreach my $type (keys %{$response->{results}{configOpts}}){ #m1/m2/m7 or r1/r2/r7
        next unless($type=~/^$master_repilca/);
        $query = "type=$type";
        foreach my $config_type (keys %{$response->{results}{configOpts}{$type}{form}}){
            foreach my $config (@{$response->{results}{configOpts}{$type}{form}{$config_type}}){
                if($config->{value} =~ /^\s*$/){
                    $config->{value} = $install_param->{$config->{label}};
                }
                $query .= "&$config->{label}=$config->{value}";
            }
        }
    }
    #chop($query);
    $logger->info(__PACKAGE__ . ".$sub_name: installOVA : query: $query");


    unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/installOVA")){
        $logger->error(__PACKAGE__ . ".$sub_name : installOVA for $sbxIp failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name : Installlation started succesffuly.");

    $logger->info(__PACKAGE__ . ".$sub_name: getInstallStatus");

    my $status = 'active';
    my $sleep = 0;

    while($status eq 'active'){ #till the status is inactive
        if($sleep > 1800){ #30 mins
            $logger->info(__PACKAGE__ . ".$sub_name: Installation is not completed in 30 mins.");
            last;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: sleeping 10s");
        sleep 10;
        $sleep+=10;

        #getInstallStatus
        unless($response = &processREST('-url' => "https://$sbxIp:444/pm/api/Virtualization/getInstallStatus")){
            $logger->error(__PACKAGE__ . ".$sub_name : getInstallStatus for $sbxIp failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name : response : " .Dumper( $response));

        if(grep {/ERROR/i} @{$response->{results}->{details}}){
            $logger->error(__PACKAGE__ . ".$sub_name : Installation failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name : details :". Dumper($response->{results}->{details}));
            $status = '';
            last;
        }

        $status = $response->{results}->{status};
        $logger->debug(__PACKAGE__ . ".$sub_name : status : $status");
    }

    if($status eq 'inactive'){
        $logger->info(__PACKAGE__ . ".$sub_name: Installation is completed");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
        return 1;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
}

=pod
    
=head3 SonusQA::SBX5000::INSTALLER::processREST()

    DESCRIPTION:

    This subroutine is used to send a rest api request and return the response on success. This is designed basically for SBX REST APIs and its internally called from SonusQA::SBX5000::INSTALLER.

    Note:

=over

=item ARGUMENTS:

    Mandatory :
   -url : rest api url

    Optional:
   -method : pass the value as 'POST' for post request. By default it takes as 'GET'
   -query : query string for 'POST' request

=item PACKAGE:

   SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED:

   NONE

=item Retruns

    response hash reference => on success
    0 						=> on failure

=item EXAMPLES(s)

    unless($response = SonusQA::SBX5000::INSTALLER::processREST("https://10.6.82.151:444/pm/api/SbcInstall/listInstallCandidates")){
        $logger->debug(__PACKAGE__ . ".$sub_name : listInstallCandidates failed");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

=back

=cut

sub processREST{
    my %args = @_;

    my $sub_name = 'processREST';

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");


    unless( $args{-url} ){
        $logger->error(__PACKAGE__.":$sub_name Mandatory argument '-url' is missing.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    my $header = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[0])};

    my $uri_query;
    if($args{-method}=~/POST/i){
        unless( $args{-query} ){
            $logger->error(__PACKAGE__.":$sub_name Argument '-query' is mandatory if '-method' is 'POST'.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }

        my $uri = URI->new($args{-url});
        $uri->query($args{-query});
        $uri_query = $uri->query();
        $logger->info(__PACKAGE__ . ".$sub_name: POST : $args{-url}, $uri_query ");
        $client->POST($args{-url}, $uri_query, $header);
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: GET : $args{-url} ");
        $client->GET($args{-url},$header);
    }
    my $response_code = $client->responseCode();
    $logger->debug(__PACKAGE__ . ".$sub_name: Response Code : ".$response_code);

    my $response_json=$client->responseContent();
    my $response;
    eval{
        $response= decode_json $response_json;
    };
    if($@){
        $logger->error(__PACKAGE__ . ".$sub_name: decode json failed.");
        $logger->info(__PACKAGE__ . ".$sub_name : response: $response_json");
		
		
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    if($response->{'error'} =~ /Authentication error/i){
        $logger->warn(__PACKAGE__ . ".$sub_name: Got authentication error with the password: $passwords[0]. Re-trying with alternate 'default'");

        $header = {'Content-Type' => 'application/x-www-form-urlencoded', Authorization => 'Basic ' . encode_base64($username . ':' . $passwords[1])};
        @passwords = reverse @passwords; # Flip the order so we try the presumably 'good' one first next time

        if($args{-method}=~/POST/i){
            $client->POST($args{-url}, $uri_query, $header);
        }
        else{
            $client->GET($args{-url}, $header);
        }

        $response_code = $client->responseCode();
        $logger->debug(__PACKAGE__ . ".$sub_name: Response Code : $response_code");
        $response_json=$client->responseContent();
        eval{
            $response= decode_json $response_json;
        };
        if($@){
            $logger->error(__PACKAGE__ . ".$sub_name: decode json failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name : responseContent: $response_json");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    ##$logger->debug(__PACKAGE__ . ".$sub_name: response: ". Dumper($response));

    if($response->{'error'}){
        $logger->error(__PACKAGE__ . ".$sub_name: Error: ". Dumper($response->{error}));
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    elsif($response_code != 200){
        $logger->error(__PACKAGE__ . ".$sub_name:  Response code = $response_code");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
        return 0;
    }


    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub-");
    return $response;
}

=pod

=head3 SonusQA::SBX5000::INSTALLER::CopyBuildAndVerify()

    DESCRIPTION:

    This subroutine is used to copy SBC build (tar.gz) and/or ePSX build from build server to SBC for installation. Also will validate the md5sum after copying SBC build.

    Note:

=over

=item ARGUMENTS:

    Mandatory :
   -sbxip         => SBC IP address
   -sbxusername   => SBC login Username
   -sbxpassword   => SBC login Password

    Optional:
	-buildpath     => SBX build path
	-ePSXbuildpath  => ePSX build path
	
	either '-buildpath' or '-ePSXbuildpath' are mandatory. 

=item PACKAGE
	SonusQA::SBX5000::INSTALLER

=item GLOBAL VARIABLES USED:

    None

=item Returns
	
	1 => on success
	0 => on failure

=item EXAMPLES(s)

	unless(&SonusQA::SBX5000::INSTALLER::copyBuildAndVerify(
					-buildpath   => $configValues{buildFullPath},
					-ePSXbuildpath  => $configValues{ePSXbuildFullPath},
					-sbxip       => $primarySbxIp,
					-sbxusername => $primarySbxUserName,
					-sbxpassword => $primarySbxPasswd)){
		$logger->error(__PACKAGE__ . ".$sub_name: copying build to SBC failed.");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
		return 0;
	}    

=back

=cut

sub copyBuildAndVerify(){
    my %args = @_;
    my $sub_name = "copyBuildAndVerify()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub-");

    unless($args{-sbxip}){
            $logger->error(__PACKAGE__ . ".$sub_name: SBX IP is mandatory");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
            return 0;
    }
    unless($args{-sbxusername}){
            $logger->error(__PACKAGE__ . ".$sub_name: SBX username is mandatory");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
            return 0;
    }
    unless($args{-sbxpassword}){
            $logger->error(__PACKAGE__ . ".$sub_name: SBX password in needed");
            $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
            return 0;
    }

    my ($build, $mainfile, $md5file, $signaturefile);

    #need to scp only if its .tar.gz. No need to scp if its .iso
    if($args{-buildpath} =~ /(.*\/){0,1}(.*\.gz)$/){
        my $path = $1;
        ( $build ) = $2 =~ m/(.*)\.tar\.gz$/i;
        $mainfile = $args{-buildpath};
        $signaturefile = "$path$build.signature";
        $md5file = "$path$build.md5";
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: sbc build ($args{-buildpath}) is not a .gz file. So we will not scp.");    
    }

    $logger->info(__PACKAGE__ . ".$sub_name: build $mainfile $signaturefile $md5file $args{-ePSXbuildpath}");

    unless($mainfile || $args{-ePSXbuildpath}){
        $logger->error(__PACKAGE__ . ".$sub_name: sbc build ($args{-buildpath}) is not a .gz file and ePSX build (-ePSXbuildpath) is not passed");
        $logger->info(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub[0]");
        return 0;
    } 

    my %scpArgs;
    foreach my $file ($mainfile , $signaturefile, $md5file, $args{-ePSXbuildpath}){
        if(defined $file and length $file){
            $scpArgs{-sourceFilePath} = $file;
            $scpArgs{-destinationFilePath} = "/opt/sonus/external/";
            $scpArgs{-hostip} = $args{-sbxip};
            $scpArgs{-hostuser} = 'root';
            $scpArgs{-hostpasswd} = $args{-sbxpassword};
            $scpArgs{-scpPort} = 2024;
            $scpArgs{-timeout} = 60;

            $logger->info(__PACKAGE__ . ".$sub_name: copying $file");
            unless(&SonusQA::Base::secureCopy(%scpArgs)){
               $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the files");
               $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
               return 0;
            }
        }
    }

    if($mainfile){
        $logger->info(__PACKAGE__ . ".$sub_name: Finished copying build files. Verifying md5sum..... ");

        my $sbxObj = SonusQA::TSHARK->new(-obj_host => $args{-sbxip}, -obj_commtype => "SSH", -obj_user => $args{-sbxusername}, -obj_password => $args{-sbxpassword} , -return_on_fail => 1, -obj_port=>2024, sessionlog => 1);
        my $res = $sbxObj->execCmd("cat /opt/sonus/external/$build.md5");
        my $res1 = $sbxObj->execCmd("md5sum /opt/sonus/external/$build.tar.gz");
        @{$res}[0] =~ s/ $build\.tar\.gz//g;
        @{$res1}[0] =~ s/ \/opt\/sonus\/external\/$build\.tar\.gz//g;

        unless( @{$res}[0] eq @{$res1}[0]){
            $logger->error(__PACKAGE__ . ".$sub_name: MD5SUM did not match error in copied files");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Build files copied successfully ");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}


=head3

Time Zones Values using for installation

1 - Kwajalein
2 - MidwayIsland
3 - Hawaii
4 - Alaska
5 - Pacific-US
6 - Arizona
7 - Mountain
8 - Central-US
9 - Mexico
10 - Saskatchewan
11 - Bogota
12 - Eastern-US
13 - Indiana
14 - Atlantic-Canada
15 - Caracas
16 - BuenosAires
17 - MidAtlantic
18 - Azores
19 -
20 - Berlin
21 - Athens
22 - Moscow
23 - Tehran
24 - AbuDhabi
25 - Kabul
26 - Islamabad
27 - Kolkata(Calcutta)
28 - Dhaka
29 - Bangkok
30 - HongKong
31 - Tokyo
32 - Adelaide
33 - Guam
34 - Magadan
35 - Fiji
36 - London

=cut



1;
