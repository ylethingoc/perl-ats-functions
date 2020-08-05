package SonusQA::VMCTRL;


=head1 NAME

SonusQA::VMCTRL - Perl module for interacting with Open Stack VM Controller.

=head1 SYNOPSIS

   my $vmCtrlObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'VM_Instance', -sessionLog => 1);

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, Module::Locate 

=head1 AUTHORS

Naresh Kumar Anthoti <nanthoti@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

   This module provides an interface for Open Stack VM Controller.
   having APIs to create, rebuild, delete and resolve the Cloud Instance with its tmsAlias name.
   using execCmd subroutine, we can run any command on Open Stack VM Controller and get that commands output back as result.


=head1 METHODS

=cut

use strict;
use warnings;
use SonusQA::Utils qw(%vm_ctrl_obj);
use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw(locate);
use Data::Dumper;
use SonusQA::Base;
use Clone 'clone';
use JSON;
use Net::IP;
use Sort::Naturally 'nsort';
use List::Util qw[min max];
our @ISA = qw(SonusQA::Base);

#hash values will be added dynamically by parsing template in resolveCloudInstance()
my %netHash = ();
my %subnetHash = (
    #Since, Template might not have subnet parameters, so keeping the default SBX5000 subnet parameters
        'SBX5000' => {
            'MGT0' => "private_subnet_mgt0",
            'MGT1' => "private_subnet_mgt1",#TOOLS-17907
            'PKT0' => "private_subnet_pkt0",
            'PKT1' => "private_subnet_pkt1",
            'HA0'  => "private_subnet_ha"
        },
        'EMS_SUT' => {
            'MGT0' => "ManagementSubnetId",
            'LI' => "ManagementSubnetIdLI"
        },
        'PSX' => {
            'MGT0' => 'subnet_mgt0',
            'SIG' => 'subnet_sig'
        },
        'VNFM' => {
            'private_mgt0' => 'subnet_private',
            'public_mgt0' => 'subnet_public'
        },
	'TOOLS' => {
	    'MGT0' => 'subnet_mgt0'
	}
    );

my %noDhcpHash = ();

my %checkStatusHash = (
		'PSX' => { 
			-userid => 'admin',
			-passwd => 'admin',
			-type => 'PSX',
			-pass_phrase => 'Starting softswitch|Initial Recovery PSX setup complete', #TOOLS-18101
			-fail_phrase =>  'EMS Registration failed|Invalid PSX volume configuration found' ,
			-log => '/var/log/metadata-psx.log',
			-wait => '60',
		},
		'EMS_SUT' => {
			-userid => 'insight',
			-passwd => 'insight',
			-type => 'EMS',
			-pass_phrase => 'Sonus Insight has been started',
			-fail_phrase =>  'Could not start the Sonus Insight server' ,
			-wait => '60',
			-log => '/opt/sonus/ems/emsRestart.log',
		},

		'SBX5000' => { 
			-userid => 'linuxadmin',
			-passwd => 'sonus',
			-root_password => 'sonus1',
			-port => '2024',
			-type => 'SBX5000',
            -pass_phrase => 'SBC service is now running|Instance is started in non-DVR mode', #TOOLS-17790
            -fail_phrase => 'Registration was not successful',
			-log => '/var/log/sonus/lca/lca.log',                          #TOOLS - 14445
		},

		);

my %versions = (
    'glance' => '2.0.0',
    'openstack' => '2.3.0',
);

=head2 SonusQA::VMCTRL::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]]\s?$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{DEFAULTTIMEOUT} = 120; #TOOLS-78335 Increase the default timeout

    $self->{LOCATION} = locate __PACKAGE__ ;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::setSystem()

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the SEAGULL to enable a more efficient automation environment.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub setSystem(){
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my($cmd,$prompt, $prevPrompt, @results,$match, $prematch);    
 
    $self->{conn}->cmd("bash");
    if($self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'ENV_FILE'}){
        $self->{conn}->cmd("source $self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'ENV_FILE'}");
    }else{
        $self->{conn}->cmd("export OS_TENANT_NAME=\'$self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'TENANT_NAME'}\'");
        $self->{conn}->cmd("export OS_USERNAME=\'$self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'USERID'}\'"); 
        $self->{conn}->cmd("export OS_PASSWORD=\'$self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'PASSWD'}\'"); 
        $self->{conn}->cmd("export OS_AUTH_URL=\'$self->{'TMS_ALIAS_DATA'}{'VM_CTRL'}{1}{'AUTH_URL'}\'"); 
    }
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    @results = $self->{conn}->cmd($cmd);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 5);
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
    $self->{conn}->cmd("unalias grep"); #to remove the colour from grep output

    #Compare controller versions
    foreach (keys %versions) {
	($self->{$_."_version"}) = $self->execCmd($_ ." --version");
        $self->{$_."_version"} =~ s/[a-zA-Z]|\s//g;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::initiateCloudInstance()

  The subroutine is to create, and configure the CE-Instance, this subroutine is called from 'subroutine resolveCloudInstance'.

=over

=item Arguments

  Mandatory Args:
    -ce_name:  need to pass '-ce_name' as argument, it creates the new CE-Instance with given '-ce_name' value.

=item Returns

  1 - Instance created successfully
  0 - Instance creation failed

=item Example

    unless($self->initiateCloudInstance(\%args)){
        $logger->error(__PACKAGE__ . ".$sub: Creating Cloud Instance has failed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub initiateCloudInstance{
    my ($self,$args) = @_;
    my $sub = "initiateCloudInstance";
    my ($result,$ceName,@cmdResult,%interfacesInfo,%IntNetwork,%extNetwork);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    $ceName = $args->{-ce_name};    
    %IntNetwork = %{$args->{-int_net}};    
    %extNetwork = %{$args->{-ext_net}};
    $args->{-interfaces_info} = \%interfacesInfo;
    unless ($result = $self->validateCloudInstanceInput($args)){
        $logger->error(__PACKAGE__ . ".$sub: Input validation failed for Cloud-Instance.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless (@cmdResult = $self->execCmd( "nova show $ceName", -return_error => 1 )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the Cloud-Instance details");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if(grep(/ERROR.*Multiple server matches found .*$ceName/i,@cmdResult)){
        $logger->error(__PACKAGE__. ".$sub: Multiple server matches found for \'$ceName\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }elsif(grep(/ERROR.*No server with a name.*$ceName/i,@cmdResult)){
        $logger->debug(__PACKAGE__. ".$sub: Need to create an Cloud Instance with name \'$ceName\'");
    #call CreateInstance
        $result = $self->createCloudInstance($args);
    }elsif($args->{-force_rebuild}){   # If we want to re-build the CE-Instance with same build, with some updates.
        $logger->debug(__PACKAGE__ . ".$sub: -force_rebuild is enabled, going to rebuild $ceName");
        $result = $self->rebuildCloudInstance($ceName,$args->{-image});
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
        return $result; 
    } else{
        $logger->debug(__PACKAGE__. ".$sub: Cloud Instance already exists, need to decide weather to SkipCreation or to ReBuildInstance ");
        my $existedImage;
        map {$existedImage = $1 if ($_ =~/^\|\simage\s+\|\s(\S+)\s/)}@cmdResult;

	my @image_result;
        unless (@image_result = $self->execCmd("nova image-show $args->{-image}")) {
            $logger->error(__PACKAGE__ .".$sub: Failed to execute the command image-show");
            $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[0]");
            return 0;
        }
        my $rebuild = 1;
        foreach (@image_result) {
            #checking if image matches with name or id
            if ($_ =~ /\|\s+(id|name)\s+\|\s+($existedImage)\s+\|/) {
                $logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$ceName\' is already installed with Image: [$existedImage], no need to re-install with the same Image again, Skipping the Installation");
                $self->{CE_EXIST} = 1; # Cloud instance already exists with this ce_name, Created/re-builded cloud Instances taking some time, for application to come up, we are using this flag for waiting.  
	        $rebuild = 0;
	    }
	}
	unless ($rebuild) {
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
            return 1;
        }else{
            $logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$ceName\' has \'$existedImage\' image, now going to rebuild with Image \'$args->{-image}\'");
            $result = $self->rebuildCloudInstance($ceName,$args->{-image});
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
            return $result;
        } 
    }
    unless($result){
        $logger->error(__PACKAGE__. ".$sub: Failed to create a Cloud Instance with the name of \'$ceName\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }else{
        $logger->debug(__PACKAGE__. ".$sub: Verify Cloud Instance creation is successful or not.");
        unless (@cmdResult = $self->execCmd("nova show $ceName")){
            $logger->error(__PACKAGE__ . ".$sub: Failed to create a Cloud Instance with the name of \'$ceName\'");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        else{
            $logger->debug(__PACKAGE__. ".$sub: Successfully created a Cloud Instance with the name of \'$ceName\', need to be configured ");
            $self->{CE_CREATED} = 1; #created a Cloud Instance, need to be configured, this flag is to delete the CE, if configuration fails.
            `touch /home/$ENV{ USER }/ats_user/logs/.${ceName}_$main::job_uuid` if($main::job_uuid);
        }
    }
#Before we proceed, need to confirm cloudInstance is in active state
    $logger->debug(__PACKAGE__. ".$sub: checking instance spawning completed or not");
    my $active = 1;
    my $wait = 1800; #Some times its taking much time for spawning a instnace, waiting for 5mins max.
    while ($active && $wait){
        unless (@cmdResult = $self->execCmd( "nova show $ceName" )){
            $logger->error(__PACKAGE__ . ".$sub: Failed to get result for nova show command");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        if (grep /task_state[\s\|]+spawning/i,@cmdResult){
            $logger->debug(__PACKAGE__. ".$sub: $ceName Instance is still in \'spawning state\', waiting 10sec for spawning to complete ");
            sleep 10;
            $wait -= 10;
        }elsif(grep /vm_state[\s\|]+active/i,@cmdResult){
            $logger->debug(__PACKAGE__. ".$sub: $ceName Instance is ACTIVE and in Running state.");
            $active = 0  ;
        }else{
            $logger->debug(__PACKAGE__. ".$sub: command result didn't match spawning/active state.".Dumper(\@cmdResult));
            last;
        }
    }
    if($active){
        $logger->error(__PACKAGE__. ".$sub: Instance didn't come to \'active state\', after waiting for 300sec");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
    }
    #Get the Internal IPs assigned to the instance.
    foreach my $interface (keys %IntNetwork){
        my $allIPs;
        map {$allIPs = $1 if ($_ =~ /^\|\s$IntNetwork{$interface}\snetwork\s+\|\s([\w.:,\s]+)/)} @cmdResult;
        if($allIPs){
            $allIPs =~ s/\s//g;
            my @ipList = split ",", $allIPs;
            $logger->debug(__PACKAGE__ . ".$sub: Internal IP list for $IntNetwork{$interface} network: [@ipList]");
            foreach my $ip (@ipList){
                $interfacesInfo{uc $interface}{'internalIpAdd'} = $ip if($ip =~ /^[\d.]+$/);
            }
        }else{
            $logger->debug(__PACKAGE__ . ".$sub: failed to get the internal IP addresses for \'$IntNetwork{$interface}\' interface");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    #Get the floating IP addresses
    unless ($self->getFloatingIPs(\%extNetwork, \%interfacesInfo)){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the list of floatingIPs.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    #Associate Floating IPs with Internal IPs of instance
    foreach my $ext (keys %extNetwork){
        my $try = 1;
        do{
            foreach my $freeIp (@{$interfacesInfo{uc $ext}{'freeFloatingIPs'}}){
                my $cmd = "nova floating-ip-associate --fixed-address ". $interfacesInfo{uc $ext}{'internalIpAdd'}." ". $ceName ." ". $freeIp;
		unless ($self->execCmd( "$cmd" )){
                    $logger->error(__PACKAGE__ . ".$sub: Failed to associate associate floating IP \'$freeIp\' to \'" . uc $ext ."\' interface");
                }else{
                    $logger->debug(__PACKAGE__. ".$sub: Successfully associated FloatingIp \'$freeIp\' to \'". uc $ext. "\' interface") ;
                    $interfacesInfo{uc $ext}{'floatingIpAdd'} = $freeIp;
                    $try = 0;
                    last;
                }
            }
            if( (! $interfacesInfo{uc $ext}{'floatingIpAdd'}) && $try ){
                $logger->debug(__PACKAGE__. ".$sub: failed to associate FloatingIP for \'". uc $ext. "\' interface, get free floating IPs once agian") ;
                unless ($self->getFloatingIPs(\%extNetwork, \%interfacesInfo)){
                    $logger->error(__PACKAGE__ . ".$sub: Failed to get the list of floatingIPs.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }  
            }  
        }while($try--);
        unless($interfacesInfo{uc $ext}{'floatingIpAdd'}){
            $logger->error(__PACKAGE__. ".$sub: failed to associate FloatingIP for \'". uc $ext. "\' interface");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0; 
        }
    }
    #Create Meta data for the instance
    if (scalar (keys %extNetwork)){
        $logger->debug(__PACKAGE__. ".$sub: Creating Meta data for the $ceName instance.");
        foreach my $interface ('MGT0','PKT0','PKT1'){
            if ($interfacesInfo{$interface}{'floatingIpAdd'}){ #There is no floating IP support for IPv6 unlike IPv4(Source: TOOLS-5896). Here we are creating meta data for flotingIps, so hard coded prefix to IPv4_PREFIX
                my $cmd = "nova meta $ceName set FloatingIPv4". ucfirst lc $interface."=\'$interfacesInfo{$interface}{'floatingIpAdd'}"."/"."$interfacesInfo{$interface}{'IPv4_PREFIX'}\'";
		unless ($self->execCmd( "$cmd" )){
                    $logger->error(__PACKAGE__ . ".$sub: Failed to create meta data ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
    }
    $logger->debug(__PACKAGE__. ".$sub: Instance Creation has completed");
    $self->{interfacesInfo} = {%interfacesInfo};
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::getFloatingIPs()

  The subroutine is to get the floating Ips for the instance 

=over

=item Arguments

  $extNetwork - Hash reference
  $interfacesInfo - Hash reference

=item Returns

  1 - Got the floating Ips
  0 - Did Not get the floating Ips

=back

=cut

sub getFloatingIPs{
    my ($self, $extNetwork, $interfacesInfo) = @_;
    my $sub = "getFloatingIp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__ . ".$sub: ---> Entered Sub");
    my (@ipList, %floatingIPs, @cmdResult);
    unless (@ipList = $self->execCmd( "nova floating-ip-list" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to fetch floating-ip-list ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    foreach my $line (@ipList){
        $line =~ s/\s//g;
        push @{$floatingIPs{$2}}, $1 if ($line =~ /(?:\|[\w-]+)?\|([\d.]+)(?:\|-){2}\|([\w-]+)\|/); 
    }
    foreach my $ext (keys %$extNetwork){
        if ($floatingIPs{$extNetwork->{$ext}}){
            $logger->debug(__PACKAGE__ . ".$sub: Interface $ext name is [$extNetwork->{$ext}] and available free floating IPs are [@{$floatingIPs{$extNetwork->{$ext}}}]");
            @{$interfacesInfo->{uc $ext}{'freeFloatingIPs'}} = @{$floatingIPs{$extNetwork->{$ext}}};
        }else{
            $logger->debug(__PACKAGE__ . ".$sub: need to create the flaoting IP for $ext, network name is \'$extNetwork->{$ext}\'");
            my $cmd = "neutron floatingip-create ". $extNetwork->{$ext};
            unless (@cmdResult = $self->execCmd( "$cmd" )){
                $logger->error(__PACKAGE__ . ".$sub: Failed to get command result for creating floating IP");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
           if(grep /No more IP addresses available/,@cmdResult){
               $logger->error(__PACKAGE__. ".$sub: Failed to create floatingIP for \'$extNetwork->{$ext}\' Network, getting \'No more IP addresses available\' error.");
               $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
               return 0;
           }elsif(grep /Quota exceeded for resources/,@cmdResult){
               $logger->error(__PACKAGE__. ".$sub: Failed to create floatingIP for \'$extNetwork->{$ext}\' Network, getting \'Quota exceeded for resources\' error.");
               $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
               return 0;
           }else{
               foreach my $line (@cmdResult){
                   $line =~ s/\s+//g;
                   if($line =~ /\|floating_ip_address\|([\d\.]+)\|/){
                       $logger->debug(__PACKAGE__. ".$sub: Floating IP Address for $ext is [$1]");
                       push @{$interfacesInfo->{uc $ext}{'freeFloatingIPs'}}, $1;
                   }
               }
           }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;     
}

=head2 SonusQA::VMCTRL::validateCloudInstanceInput()

  The subroutine is to validate all the input for cloud instance, like flavor, image, security_groups, and networks checks user input values, actually exist on openstack controller.

=over

=item Arguments

  None

=item Returns

  1 - If Validation is successful
  0 - If Validation is not successful

=item Example

    unless ($result = $self->validateCloudInstanceInput($args)){
        $logger->error(__PACKAGE__ . ".$sub: Input validation failed for Cloud-Instance.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub validateCloudInstanceInput{
    my ($self, $args) = @_;
    my $sub = "validateCloudInstanceInput";
    my (%IntNetwork,%extNetwork,%subNetwork);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    %IntNetwork = %{$args->{-int_net}};
    %extNetwork = %{$args->{-ext_net}};
 
    my @glanceList;
    unless (@glanceList = $self->execCmd( "glance image-list" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the list of available images");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless (grep /\|\s+$args->{-image}\s+\|/,@glanceList){
        $logger->debug(__PACKAGE__ . ".$sub: There is no image named \'$args->{-image}\' on openstack ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my @flavorList;
    unless (@flavorList = $self->execCmd( "nova flavor-list" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the list of available flavors");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless (grep /\|\s+$args->{-flavor}\s+\|/,@flavorList){
        $logger->debug(__PACKAGE__ . ".$sub: There is no flavor named \'$args->{-flavor}\' on openstack ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my @secGrpList;
    unless (@secGrpList = $self->execCmd( "nova secgroup-list" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the list of available security_groups");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless (grep /\|\s+$args->{-security_groups}\s+\|/,@secGrpList){
        $logger->debug(__PACKAGE__ . ".$sub: There is no security_group named \'$args->{-security_groups}\' on openstack ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my @cmdResult;
    unless (@cmdResult = $self->execCmd("neutron net-list --tenant-id $args->{-tenant_id}")){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the net-list details of -tenant-id \'$args->{-tenant_id}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my %netListHash;
    for ( my $i = 0; $i <= $#cmdResult; $i++){
        my ($key,$ip,$prefix);
        if($cmdResult[$i] =~ /^\|\s+([\w\-]+)\s+\|\s+([\w\-]+)\s+\|\s+([\w\-]+)\s([\w.:]+)\/(\d+)/){
            ($key,$ip,$prefix) = ($2,$4,$5);
            $netListHash{$key}{'NET_ID'} = $1;
            $netListHash{$key}{'SUBNET_ID'} = [$3];
            ($ip =~ /^[\d\.]+$/) ? ($netListHash{$key}{'IPv4_PREFIX'} = $prefix) : ( $netListHash{$key}{'IPv6_PREFIX'} = $prefix );
        }
        if(($cmdResult[$i+1]) && ($cmdResult[$i+1] =~ /^\|\s+\|\s+\|\s+([\w\-]+)\s([\w.:]+)\/(\d+)/)){
            ($ip,$prefix) = ($2,$3);
            push @{$netListHash{$key}{'SUBNET_ID'}}, $1;
            ($ip =~ /^[\d\.]+$/) ? ($netListHash{$key}{'IPv4_PREFIX'} = $prefix) : ( $netListHash{$key}{'IPv6_PREFIX'} = $prefix );
            $i = $i++;
        }
    }
    foreach my $usrGivenNW (keys %IntNetwork){
        if ($netListHash{$IntNetwork{$usrGivenNW}}){
            %{$args->{-interfaces_info}{uc $usrGivenNW}} = %{$netListHash{$IntNetwork{$usrGivenNW}}};
        }else{
            $logger->debug(__PACKAGE__. ".$sub: Internal network \'$IntNetwork{$usrGivenNW}\' doesn't exist in openStack net-list --tenant-id $args->{-tenant_id}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    unless (@cmdResult = $self->execCmd("neutron net-list")){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the net-list details");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    foreach my $key (keys %extNetwork){
        my $extnet; 
        unless(($extnet) = grep (/\|\s+$extNetwork{$key}\s+\|/, @cmdResult)){
            $logger->debug(__PACKAGE__. ".$sub: external network \'$extNetwork{$key}\' doesn't exist in openStack net-list");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        if ($extnet =~ /^\|\s+[\w\-]+\s+\|\s+[\w\-]+\s+\|\s+([\w\-]+)\s[\d.]+\/(\d+)/){
            $args->{-interfaces_info}{uc $key}{'SUBNET_ID'} = [$1];
            $args->{-interfaces_info}{uc $key}{'IPv4_PREFIX'} = $2;   #As of now external networks dont have IPv6, so directly assigning to 'IPv4_PREFIX' 
        }
    }
    if($args->{-availability_zone}){
        unless (@cmdResult = $self->execCmd("nova availability-zone-list")){
            $logger->error(__PACKAGE__ . ".$sub: Failed to get availability-zone-list details");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        unless (grep /^\|\s$args->{-availability_zone}\s+\|/,@cmdResult){
            $logger->debug(__PACKAGE__ . ".$sub: There is no availability-zone named \'$args->{-availability_zone}\' on openstack ");
            $logger->debug(__PACKAGE__ . ".$sub: List of existed availability-zones on openstack are " . Dumper(\@cmdResult));
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
} 

=head2 SonusQA::VMCTRL::createCloudInstance()

  This subroutine is called from 'initiateCloudInstance' subroutine to create the CE-Instance.
  --image name is taken from the 'TESTED_RELEASE', and 'BUILD_VERSION' values of testsuiteList.pl file.
  --flavor, --security-groups, --user-data can be passed as argument, otherwise it takes these values from the testbedDefinition.pl file.

=over

=item Arguments

  Mandatory Args:
    -ce_name:  we need the -ce_name as the argument, creates the new CE-Instance with -ce_name value.
    -interfaces_info: Its a hash ref, which will contain the net-id values for nic interfaces. 

=item Returns

  0   - Failed to create CE-Instance;
  1   - CE-Instance creation has started;

=item Example

    $result = self->createCloudInstance($args);

=back

=cut

sub createCloudInstance{
    my ($self, $args) = @_; 
    my $sub = "createCloudInstance";
    my (@cmdResult,$interfacesInfo,$userData,$cmd,$ceName,$flavor,$image,$securityGrp);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    $interfacesInfo = $args->{-interfaces_info};
    $ceName = $args->{-ce_name};
    $flavor = $args->{-flavor};
    $image = $args->{-image};
    $securityGrp = $args->{-security_groups};
    $logger->debug(__PACKAGE__. ".$sub: ce_input: flavor [$flavor], image [$image]");
    my $novaBootCmd = "nova boot $ceName --flavor $flavor --image $image --security-groups $securityGrp";
    $novaBootCmd = $novaBootCmd . ' --availability-zone '.$args->{-availability_zone} if ($args->{-availability_zone});
    $novaBootCmd .= " --key-name $args->{-key_name}" if($args->{-key_name});
    $userData = ($args->{-user_data}) ? $args->{-user_data} : "";
    if ($userData){
    # Creating User Data File
        $userData =~ s/([\"\{\}\\])/\\$1/g; 
        $userData =~ s/\s|\n//g;
        $logger->debug(__PACKAGE__. ".$sub: UserData Value: [$userData]");
        $self->execCmd("mkdir userData");
        my $userDataFile = "userData/". $ceName ."\.txt";
        $logger->debug(__PACKAGE__. ".$sub: UserData File name: [$userDataFile]");
        $cmd = 'echo -e ' ."$userData". ' > '.$userDataFile;
        $args->{-floating_ip_count} = ($userData =~ /floating_ip_count[\\\":]+(\d+)/i) ? $1 : 0; 
        $args->{-userdata_file} = $userDataFile;
        $self->execCmd($cmd);
        $novaBootCmd = $novaBootCmd . ' --user-data '.$userDataFile;
    }
    #Creating the instance, By running the 'nova boot' command
    foreach my $key ('MGT0','HA','PKT0','PKT1'){
        $novaBootCmd = $novaBootCmd . ' --nic net-id='.$interfacesInfo->{uc $key}{'NET_ID'} if (grep /$key/i, keys %{$args->{-int_net}});
    }
    unless (@cmdResult = $self->execCmd( "$novaBootCmd" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get result for nova boot command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep (/usage: nova boot/i,@cmdResult)){
        $logger->error(__PACKAGE__. ".$sub: \'nova boot\'command which was entered is wrong, check values are passed for all the mandatory options for \'nova boot\'command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::rebuildCloudInstance()

  This subroutine is called to rebuild the CE-Instance.
  Image name is combination of 'TESTED_RELEASE', and 'BUILD_VERSION' values which are given in testsuiteList.pl file.

=over

=item Arguments

  Mandatory Args:
    -ce_name:  we need the -ce_name as the argument to rebuild that CE-Instance.

=item Returns

  0   - After rebuild, If CE-Instance Image value didn't update with new Image value, we return 0;
  1   - If CE-Instance Image value is updated, we return 1;

=item Example

  $result = $self->rebuildCloudInstance($ceName);

=back

=cut

sub rebuildCloudInstance{
    my ($self,$ceName,$image)=@_;
    my $sub = "rebuildCloudInstance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    my ( $cmd,$installedImage, $result,@cmdResult);
    $cmd = "nova rebuild " . $ceName ." ". $image; 
    unless (@cmdResult = $self->execCmd( "$cmd" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get result for nova rebuild command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: verify the status of rebuild ");
    unless (@cmdResult = $self->execCmd( "nova show $ceName" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get result for nova show command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    while(grep (/rebuilding/i,@cmdResult)){
        $logger->debug(__PACKAGE__ . ".$sub: CE-Instance is in 'rebuilding' state, waiting for 10sec");
        sleep 10;
        unless (@cmdResult = $self->execCmd( "nova show $ceName" )){
            $logger->error(__PACKAGE__ . ".$sub: Failed to get result for nova show command");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    map {$installedImage = $1 if ($_ =~/^\|\simage\s+\|\s(\S+)\s/)}@cmdResult;
    if ($installedImage eq "$image"){
        $logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$ceName\' rebuilded successfully with Image: \'$installedImage\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->error(__PACKAGE__. ".$sub: Failed to rebuild Cloud Instance \'$ceName\' with \'$main::TESTSUITE->{BUILD_VERSION}\' image.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }   
}

=head2 SonusQA::VMCTRL::resolveCloudInstance()

  This is the 1st subroutine which is being called, to create a Cloud Instance, and to get the details of newly created CE-Instance.
  It calls initiateCloudInstance subroutine to create and configure the CE-Instance.

=over

=item Arguments

  Mandatory Args:
    -ce_name:  Need to pass -ce_name as the argument, creates the new CE-Instance with -ce_name value.
  Optional Args
    -alias_hashref: we will resolve the cloud instance and assign the values to this variable.

=item Returns

  0   - If Fails at any stage of creation/rebuild, configuring and reaching the CE-Instance;
  $resolveAlias   - we will return the resolved hash, when CE-Instance creation/rebuild is successful and able to reach the Cloud Instance;

=item Example

  When user want to create and test the CE-Instance with different %CE_INPUT values in his FEATURE file, then this subroutine can be called directly from the FEATURE file, to create/rebuild the CE-Instance. 
  When user directly calls this subroutine and dont pass any of the %CE_INPUT fields, those field values are taken from %CE_INPUT hash defined in testbedDefinition.pl 


  my $scalar = '{
                 "floating_ip_count" : "0",
                 "virtual_ip_count" : "0",
                 "sonus_sbc_instance_name" : "SBC-INSTANCE",
                 "sonus_sbc_system_name" : "CLOUDSBC"
              }' ;

  my %CE_INPUT = ( -ce_name => 'ats-ram',
                 -flavor => 'm1.large',
                 -security_groups => 'ceSg',
                 -int_net => {'MGT0'=> 'mgmt-net',
                             'HA' => 'ha-net',
                             'PKT0'=> 'PKT0-net',
                             'PKT1'=> 'PKT1-net'
                            },
                 -ext_net => {'MGT0'=> 'ext-net',
                             'PKT0'=> 'ext-pkt0',
                             'PKT1'=> 'ext-pkt1'
                            },
                 -user_data => $scalar
               );     


  my $ceValues;
  unless ($ceValues = $vmCtrlObj->resolveCloudInstance(%CE_INPUT)){
    print "Failed to resolve Cloud Instance, Value is :".Dumper($ceValues);
    $logger->debug(" <-- Leaving Sub [0]");
    return 0;
  }

=back

=cut

sub resolveCloudInstance {
    my $self = shift;
    my %args = @_;
    my $sub = "resolveCloudInstance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: ---> Entered Sub");

    my $resolveAlias = ($args{-alias_hashref}) ? $args{-alias_hashref} : {} ;
    my $resolveAliasFemale;
    $args{-obj_type} ||= $args{-alias_hashref}{__OBJTYPE};
    unless($args{-obj_type}) {
        $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-obj_type\' is not passed as a argument to subroutine.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $getUser = `whoami`;
    chomp($getUser);
    $args{-template_file} ||= $resolveAlias->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE};  
    if ($args{-obj_type} =~ /SBX/ and defined ($args{-templateType})) {
         $args{-templateType} = uc($args{-templateType});
         $args{-template_file} = "/home/$getUser/ats_repos/lib/perl/QATEST/SBX5000/YAMLTEMPLATE/$args{-templateType}.yaml" unless($args{-template_file}); #TOOLS-15349: Fix added to support template types. Currently We have SRIOV and PRVN as template types for SBX
         if( ! -e $args{-template_file}){
             $logger->error(__PACKAGE__ . ".$sub: <-- User has selected template type $args{-templateType}, But ATS did not find $args{-template_file}");
             $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
             return 0;
         }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Template file being used : $args{-template_file} ");


    my $parameter_bk = $args{-parameter};# to retain the parameter passed in newFromAlias 
    if (($args{-obj_type} =~ /(EMS|CDA)/i) and (!$args{-template_file})) {
	$resolveAlias = $self->novaBoot(%args);
        return ($resolveAlias);
    }
    else { #for instance spawning using heat template

	my (%argHash, %networks, $type,);
        if($args{-obj_type} eq 'VNFM'){ #TOOLS-17452
            $resolveAlias->{VNFM_TYPE} = $type = (exists $resolveAlias->{CLOUD_INPUT}->{2}) ? $args{-obj_type}.'_HA' : $args{-obj_type}.'_SIMPLEX';

            #If No /template and key file/ is from User, then we will assign Default template.     
            $args{-template_file} = ($type =~ /HA/) ? "/home/$getUser/ats_repos/lib/perl/SonusQA/VNFMHA.yaml" : "/home/$getUser/ats_repos/lib/perl/SonusQA/VNFMSIMPLEX.yaml" unless($args{-template_file} || $resolveAlias->{LOGIN}->{1}->{KEY_FILE});#TOOLS-17733
        }else{
            $type = $args{-obj_type};
        }

	my $isSubnetPresent = 0; #use this scalar to know if subnet parameters are being used in template file
        #Create the Global hashes (%netHash, %noDhcpHash, %subnetHash) for each obj_type
        $self->getParametersFromTemplate($args{-template_file}, \$isSubnetPresent, $args{-obj_type},$resolveAlias->{CLOUD_INPUT}->{1}->{TYPE});

        #TOOLS-19317
        $isSubnetPresent = 1 if($args{-obj_type} =~ /EMS|VNFM/i);#EMS template supports subnet details
        $args{-isSubnetPresent} = $isSubnetPresent;
        unless(%args = $self->frameParameterList(\%args)){
            $logger->debug(__PACKAGE__. ".$sub: Failed to Frame the cmd");
            $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

	my $user_home = qx#echo ~#;
	chomp ($user_home);
	$user_home =~ /\/.+\/(.+)$/;
	$args{-user} = $1;
	my $source_path = $user_home."/ats_repos/lib/perl/SonusQA";
        my $key_name = "cloud_ats.key";
        $args{-key_from_user} = 0;
	my $ceName = $args{-ce_name};
	if ($resolveAlias->{LOGIN}->{1}->{KEY_FILE} || $args{-key_file}) { #private key file path is passed by user
            $args{-key_file} = $resolveAlias->{LOGIN}->{1}->{KEY_FILE} || $args{-key_file};
            $args{-key_from_user} = 1;

            #template file also has to be passed by user
	    unless (exists $main::TESTBED{$main::TESTBED{$ceName}.':hash'}->{-default_key}) {
                unless ($args{-template_file}) {
                    $logger->error(__PACKAGE__ . ".$sub: Key file is passed by user, but not the template and env file.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
	    }   
        }elsif( $resolveAlias->{LOGIN}->{2}->{KEY_FILE})  {
            $logger->error(__PACKAGE__. ".$sub: Set {LOGIN}->{1}->{KEY_FILE} in TMS for linuxadmin since only {LOGIN}->{2}->{KEY_FILE} for admin is set");
            $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
            return 0 ;
        }
	$args{-key_from_user} = 0 if(exists $main::TESTBED{$main::TESTBED{$ceName}.':hash'}->{-default_key});
	$args{-key_file} ||= $source_path."/".$key_name if ($args{-obj_type} =~ /SBX|PSX|VNFM/ and !$args{-configurator});
	if ($args{-key_file}) {
	    unless ($self->mandatoryKeyPair(\%args)) {
                $logger->error(__PACKAGE__. ".$sub: unable to add mandatory keypair");
                $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
                return 0;
            }
	    $resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file};
            if($resolveAlias->{LOGIN}->{2}->{KEY_FILE}) { #TOOLS-17944
		unless ($self->mandatoryKeyPair({-key_file => $resolveAlias->{LOGIN}->{2}->{KEY_FILE}})) {
                    $logger->error(__PACKAGE__. ".$sub: unable to add mandatory keypair");
                    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
                    return 0;
                }
	    }
            else {#TOOLS-18056 TOOLS-18032
		$resolveAlias->{LOGIN}->{2}->{KEY_FILE} = $args{-key_file};
	    }
	    $main::TESTBED{$main::TESTBED{$ceName}.':hash'}->{-default_key} = 1;
	}

        if ($args{-template_file}) {
            $args{-template_from_user} = 1;

            if ($resolveAlias->{CLOUD_INPUT}->{1}->{ENV_FILE} || $args{-env_file}) {
                $args{-env_file} = $args{-env_file} || $resolveAlias->{CLOUD_INPUT}->{1}->{ENV_FILE}; #TOOLS-17632
                $args{-env_name} = $1 if ($args{-env_file} =~ /\/.+\/(.+)$/);
            }
        }

        foreach my $attGroup (keys %{$netHash{$type}}) {
            foreach my $attIndex (keys %{$netHash{$type}{$attGroup}}) {
                $argHash{$netHash{$type}{$attGroup}{$attIndex}} = $self->{TMS_ALIAS_DATA}->{$attGroup}->{$attIndex}->{NAME} || $args{-$netHash{$type}{$attGroup}{$attIndex}};
            }
        }
	$argHash{tenant_id} = $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{TENANT_ID} || $args{-tenant_id};
	unless (%networks = $self->getNetworkIdName(\%argHash)) {
            $logger->error(__PACKAGE__ . ".$sub: Didnot get the network name and id");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

	my @pingArr;
	my %output;
	$output{type} = $args{-obj_type};
        my $valid = 1;
        $argHash{image} = $main::TESTSUITE->{QCOW2_PATH} || $resolveAlias->{CLOUD_INPUT}->{1}->{IMAGE} || $args{-image} || $args{-Image};
	$argHash{image} = $main::TESTSUITE->{QCOW2_PATH} || $resolveAlias->{SLAVE_CLOUD}->{1}->{IMAGE} || $args{-image} || $args{-Image} if($args{-slave});
        # to create glance image from qcow2
        if($argHash{image}=~/\.qcow2$/){ #TOOLS-17209
            unless ($argHash{image} = $self->createGlanceImage(-qcow2_path => $argHash{image})){
                $logger->error(__PACKAGE__ . ".$sub: Failed to create glance image from '$argHash{image}'");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }

        unless($args{-obj_type} =~ /(SBX|TOOLS|VMCCS)/){
            $argHash{Image} = $argHash{image};
            delete $argHash{image};
        }

    #Setting the -skip_check_instance flag in checkStatusHash to prevent skipping of wait time and instance ping TOOLS-77394
    $self->{SKIP_CHECK_INSTANCE} = $args{-skip_check_instance}; 
	if ($args{-obj_type} =~ /SBX/) {
            $argHash{security_group} = $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITY_GROUPS} || $args{-security_groups};
            $argHash{flavor} = $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-flavor};
            $resolveAlias->{sbc_active_name} = $resolveAlias->{CE}->{1}->{HOSTNAME} || $args{-sbc_active_name} unless (exists $resolveAlias->{sbc_active_name}); #TOOLS-18160 #TOOLS-17844
            $argHash{sbc_active_name} = $resolveAlias->{sbc_active_name};

            unless ($args{-env_file}) {
                $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                #check if mandatory arguments are present or not
                foreach ( 'image', 'flavor', 'security_group' ) {
                    unless ($argHash{$_}) {
                        $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in SBX alias");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        $valid = 0;
                        last;
                    }
                }
                return 0 unless ($valid) ;
            }

	    if ($args{-alias_hashref_female}) { #For HA
		$logger->debug(__PACKAGE__ . ".$sub: Considering the setup as HA.");
		$resolveAliasFemale = $args{-alias_hashref_female};
		$resolveAliasFemale->{sbc_standby_name} = $resolveAliasFemale->{CE}->{1}->{HOSTNAME} || $args{-sbc_standby_name} unless(exists $resolveAliasFemale->{sbc_standby_name});
		$argHash{sbc_standby_name} = $resolveAliasFemale->{sbc_standby_name};
		$args{-ce_name} ||= "$resolveAlias->{name}__$resolveAliasFemale->{name}";
		$logger->debug(__PACKAGE__ . ".$sub: CE_NAME : $args{-ce_name} \nActive ce_name : $resolveAlias->{name} \nStandby ce_name : $resolveAliasFemale->{name}");
		$resolveAliasFemale->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file};
	    }
	    else {
		$args{-ce_name} ||= $args{-tms_alias};
                foreach my $dsbc ('S_OAM','S_SBC','M_OAM','M_SBC','T_OAM','T_SBC'){
                       next unless ($args{-alias_hashref}->{$dsbc}); # TOOLS-15502 To avoid creation of empty hash for SSBC,MSBC,TSBC
                       foreach my $index (sort keys %{$args{-alias_hashref}->{$dsbc}}){
                              push (@{$output{instance}},$args{-alias_hashref}->{$dsbc}->{$index}->{NAME});
                       }
                }
                $logger->debug(__PACKAGE__ . ".$sub: CE_NAME : $args{-ce_name} \nOutput hash: ".Dumper \%output);
                $output{instance} = [$args{-ce_name}] unless(exists $output{instance});
	    }

            $argHash{sbc_rgIp} = $args{sbc_rgIp}; # argHash will have the parameters for create heat stack command
	    unless ($self->heatStackCreate(\%args,\%argHash)) {
		$logger->error(__PACKAGE__ . ".$sub:  unable to create the cloud instance");
                $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                return 0;
	    }
            $resolveAlias->{SBC_RGIP} = $args{sbc_rgIp};
	    $resolveAlias->{CE1}->{1}->{HOSTNAME} ||= $args{-hostname}{standby};

	    $output{instance} = [$args{instance_name}{1}, $args{instance_name}{2}] if ($resolveAliasFemale);
	    #pass the private network names to get the ips

	    $output{$networks{$netHash{$args{-obj_type}}{INT_NIF}{1}}{name}}     = 'MGT0' if (exists $networks{$netHash{$args{-obj_type}}{INT_NIF}{1}}{name});
            $output{$networks{$netHash{$args{-obj_type}}{INT_NIF}{2}}{name}}     = 'MGT1' if (exists $networks{$netHash{$args{-obj_type}}{INT_NIF}{2}}{name});#TOOLS-17907
            $output{$networks{$netHash{$args{-obj_type}}{INT_SIG_NIF}{1}}{name}} = 'PKT0' if (exists $networks{$netHash{$args{-obj_type}}{INT_SIG_NIF}{1}}{name});
	    $output{$networks{$netHash{$args{-obj_type}}{INT_SIG_NIF}{2}}{name}} = 'PKT1' if (exists $networks{$netHash{$args{-obj_type}}{INT_SIG_NIF}{2}}{name});
            $output{$networks{$netHash{$args{-obj_type}}{INTER_CE_NIF}{1}}{name}} = 'HA0' if (exists $networks{$netHash{$args{-obj_type}}{INTER_CE_NIF}{1}}{name});
	    my @ips;
	    unless (@ips = $self->fetchIps(%output)) {
		$logger->error(__PACKAGE__ . ".$sub:  unable to fetch the ips");
                $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                return 0;
	    }

	    my %subnet;
	    if ($args{-parameter} =~ /subnet/i) {
                unless (%subnet = $self->getSubNetDetails($args{-parameter}, $args{-obj_type})) {
                    $logger->error(__PACKAGE__ . ".$sub:  unable to get the subnet details");
                    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                    return 0;
                }
            }

	    my @sbxArray;
	    #sbxArray populating for Nested template 
            foreach my $dsbc ('S_OAM','S_SBC','M_OAM','M_SBC','T_OAM','T_SBC'){
                  next unless ($resolveAlias->{$dsbc}); # TOOLS-15502 To avoid creation of empty hash for SSBC,MSBC,TSBC
                  foreach my $index(sort keys %{$resolveAlias->{$dsbc}}){
                      push(@sbxArray,$resolveAlias->{$dsbc}->{$index});
                  }
            }
            #sbxArray populating for non-nested template
            @sbxArray = $resolveAlias unless (scalar @sbxArray); #TOOLS-15200
	    push (@sbxArray, $resolveAliasFemale) if ($resolveAliasFemale);

        my (@interfaces, @alternate_media_ipv4_list, @alternate_media_ipv6_list, @vlanids, @gateway_v4, @gateway_v6, @prefix_v4, @prefix_v6, @ipv4, @ipv6);

	    for (my $i = 0; $i <= $#sbxArray; $i++) {
                my $net = (exists $ips[$i]{MGT1}) ? 'MGT1' : 'MGT0' ; #TOOLS-17907
                push (@pingArr, $ips[$i]{$net}{PUBLIC}{IP}) if ($ips[$i]{$net}{PUBLIC}{IP});
                push (@pingArr, $ips[$i]{$net}{PUBLIC}{IPV6}) if ($ips[$i]{$net}{PUBLIC}{IPV6});
		#Map the IPs to the resolved alias, which will be used to create sbx object.
		#if conditions are added so that, warnings can be avoided and values will not be undef when RHS things are not defined.
                my $j;
                foreach my $pkt_type ('PKT0', 'PKT1') {
                  $j = ($pkt_type eq 'PKT0')?1:2;
                  

                    # use metadata to fetch alternate media ips and vlan ids
                    foreach my $element (keys %{$ips[$i]{metadata}}){
                        push(@interfaces, $element) if($element =~ /^IF[0-9]+/);
                    }

                    foreach my $interface (nsort @interfaces){
                        foreach my $element (nsort keys %{$ips[$i]{metadata}}){
                            if($element =~ /ALT_/ and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type and $ips[$i]{metadata}{$element}{'IFName'} eq $interface ){
                                push(@alternate_media_ipv6_list, $ips[$i]{metadata}{$element}{IP}) if ($ips[$i]{metadata}{$element}{IP} =~ /:/);
                                push(@alternate_media_ipv4_list, $ips[$i]{metadata}{$element}{IP}) if ($ips[$i]{metadata}{$element}{IP} =~ /\./);
                            }
                            if($ips[$i]{metadata}{$interface}{VlanId} and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type){
                                push(@vlanids, $ips[$i]{metadata}{$interface}{VlanId}) if(!grep $_ eq $ips[$i]{metadata}{$interface}{VlanId}, @vlanids);
                            }
                        }

                        if(exists $ips[$i]{metadata}{$interface}{IPV6} and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type){
			      my @arr = split ("/", $ips[$i]{metadata}{$interface}{IPV6});	
                              push(@ipv6, $arr[0]) if( ( !grep $_ eq $arr[0], @ipv6));
			      push @prefix_v6,$arr[1];
                        }

                        if(exists $ips[$i]{metadata}{$interface}{IPV4} and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type){
			      my @arr = split ("/", $ips[$i]{metadata}{$interface}{IPV4});	
                              push(@ipv4, $arr[0]) if( ( !grep $_ eq $arr[0], @ipv4));
			      push @prefix_v4,$arr[1];
                        }
                        if(exists $ips[$i]{metadata}{$interface}{GWV6} and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type){
                            push(@gateway_v6, $ips[$i]{metadata}{$interface}{GWV6}) if ($ips[$i]{metadata}{$interface}{GWV6} =~ /:/);
                        }
                        if(exists $ips[$i]{metadata}{$interface}{GWV4} and uc $ips[$i]{metadata}{$interface}{Port} eq $pkt_type){
                            push(@gateway_v4, $ips[$i]{metadata}{$interface}{GWV4}) if ($ips[$i]{metadata}{$interface}{GWV4} =~ /\./);
                        }

                    }
#if SBC is spawned with DHCP pkt network, metadata info from 'nova show' cmd doesn't contain the pkt details so fetching prefix and gateway info from subnet details
		    unless(@ipv6 || @ipv4){
                        $logger->debug(__PACKAGE__ . ".$sub:  metadata doesn't contain pkt ip's, so populating it.. ");
                        foreach my $key (@{$subnet{$pkt_type}}) {
                            if ($key->{ip_version} =~ /4/) {
                                push @prefix_v4, (split("/", $key->{cidr}))[1] if ($key->{cidr});
                                push @gateway_v4, $key->{gateway_ip} if ($key->{gateway_ip});
				push @ipv4, $ips[$i]{$pkt_type}{PRIVATE}{IP} if ($ips[$i]{$pkt_type}{PRIVATE}{IP});
                            }
                            elsif ($key->{ip_version} =~ /6/) {
                                push @prefix_v6, (split("/", $key->{cidr}))[1] if ($key->{cidr});
                                push @gateway_v6, $key->{gateway_ip} if ($key->{gateway_ip});
                                push @ipv6, $ips[$i]{$pkt_type}{PRIVATE}{IPV6} if ($ips[$i]{$pkt_type}{PRIVATE}{IPV6});
                            }
                        }
		    }

                    $sbxArray[$i]->{PKT_NIF}->{$j}->{ALTERNATE_MEDIA_IP4_LIST} = join(',', @alternate_media_ipv4_list);
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{ALTERNATE_MEDIA_IP6_LIST} = join(',', @alternate_media_ipv6_list);                    
                    $sbxArray[$i]->{INT_SIG_NIF}->{$j}->{IP} = $ips[$i]{$pkt_type}{PRIVATE}{IP} if ($ips[$i]{$pkt_type}{PRIVATE}{IP});
                    $sbxArray[$i]->{INT_SIG_NIF}->{$j}->{IPV6} = $ips[$i]{$pkt_type}{PRIVATE}{IPV6} if ($ips[$i]{$pkt_type}{PRIVATE}{IPV6});
                    #TOOLS-71331
                    my $index = 0;
                    do{
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{IPV4PREFIXLEN} = $prefix_v4[$index] if ($prefix_v4[$index]); #TOOLS-15222-to pick just one value instead of comma seperated values
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{DEFAULT_GATEWAY} = $gateway_v4[$index] if ($gateway_v4[$index]);
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{IPV6PREFIXLEN} = $prefix_v6[$index] if ($prefix_v6[$index]);
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{DEFAULT_GATEWAY_V6} = $gateway_v6[$index] if($gateway_v6[$index]);
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{LAN } = $vlanids[$index] if($vlanids[$index]);#TOOLS-16148 instead of comma sepereated LAN values ,needed one LAN value.
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{IPV6} = $ipv6[$index] if($ipv6[$index]);
                    $sbxArray[$i]->{PKT_NIF}->{$j}->{IP} = $ipv4[$index] if($ipv4[$index]);
		    $sbxArray[$i]->{PKT_NIF}->{$j}->{PORT} ||= '5060';
                    $index++;
                    $j=$j+2;
                    }while($index < max(scalar(@ipv4),scalar(@ipv6)));

                    undef @alternate_media_ipv4_list;
                    undef @alternate_media_ipv6_list;
                    undef @interfaces;
                    undef @vlanids;
                    undef @gateway_v4;
                    undef @gateway_v6;
                    undef @prefix_v4;
                    undef @prefix_v6;
                    undef @ipv4;
                    undef @ipv6;
                }
                #TOOLS-17907 - mgt1 support
                my %mgt_hash = (
			         MGT0 => 1,
                  	         MGT1 => 2,
			       );
                foreach my $mgt_type (keys %mgt_hash){
                    next unless( exists $ips[$i]{$mgt_type}); #TOOLS-17907
                    foreach my $key (@{$subnet{MGT0}}) {
                        if ($key->{ip_version} =~ /4/) {
                            $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{IPV4PREFIXLEN} = (split("/", $key->{cidr}))[1] if ($key->{cidr});
                            $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{DEFAULT_GATEWAY} = $key->{gateway_ip} if ($key->{gateway_ip});
                        }
                        elsif ($key->{ip_version} =~ /6/) {
                            $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{IPV6PREFIXLEN} = (split("/", $key->{cidr}))[1] if ($key->{cidr});
                            $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{DEFAULT_GATEWAY_V6} = $key->{gateway_ip} if ($key->{gateway_ip});
                        }
                    }	

                    #ipv4
                    $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{IP} = $ips[$i]{$mgt_type}{PUBLIC}{IP} if ($ips[$i]{MGT0}{PUBLIC}{IP});

                    #private
                    $sbxArray[$i]->{INT_NIF}->{$mgt_hash{$mgt_type}}->{IP} = $ips[$i]{$mgt_type}{PRIVATE}{IP}     if ($ips[$i]{MGT0}{PRIVATE}{IP});

                    #ipv6
                    $sbxArray[$i]->{MGMTNIF}->{$mgt_hash{$mgt_type}}->{IPV6} = $ips[$i]{$mgt_type}{PUBLIC}{IPV6} if ($ips[$i]{MGT0}{PUBLIC}{IPV6});
  
                    #private
                    $sbxArray[$i]->{INT_NIF}->{$mgt_hash{$mgt_type}}->{IPV6} = $ips[$i]{$mgt_type}{PRIVATE}{IPV6}     if ($ips[$i]{MGT0}{PRIVATE}{IPV6});
                }
                  
                #HA
                $sbxArray[$i]->{INTER_CE_NIF}->{1}->{IP} = $ips[$i]{HA0}{PRIVATE}{IP} if ($ips[$i]{HA0}{PRIVATE}{IP});
                $sbxArray[$i]->{INTER_CE_NIF}->{1}->{IPV6} = $ips[$i]{HA0}{PRIVATE}{IPV6} if ($ips[$i]{HA0}{PRIVATE}{IPV6});

                $sbxArray[$i]->{LOGIN}->{1}->{ROOTPASSWD} ||= 'sonus1';
                $sbxArray[$i]->{LOGIN}->{1}->{USERID} ||= 'admin';
                $sbxArray[$i]->{LOGIN}->{1}->{PASSWD} ||= 'admin';
                $sbxArray[$i]->{SIG_GW} = $sbxArray[$i]->{SIG_H323} = $sbxArray[$i]->{SIG_SIP} = clone($sbxArray[$i]->{PKT_NIF});
                $sbxArray[$i]->{metadata} = $ips[$i]{metadata}   if ($ips[$i]{metadata}); #the additional ips TOOLS-8950
	    }
        
	}# sbx if ends
	elsif ($args{-obj_type} =~ /PSX/i) {
	    delete $argHash{$netHash{$args{-obj_type}}{SIGNIF}{1}};
	    delete $argHash{$netHash{$args{-obj_type}}{NIF}{1}}; #TOOLS-15000 - SRv4 PSX
            if (($resolveAlias->{MASTER}->{1}->{NAME} || (!$resolveAlias->{SLAVE_CLOUD})) && !$args{-slave} and !$args{-gr}) { #TOOLS-12929 Moved the check inside master's condition to avoid it in case of just slave
                $argHash{"Flavor"} = $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-Flavor};
                $argHash{"SecurityGroup"} = $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITY_GROUPS} || $args{-security_groups} ;

                unless ($args{-env_file}) {
                    $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                    foreach ( 'Image', 'Flavor', 'SecurityGroup' ) {
                        unless ($argHash{$_}) {
                            $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in TMS alias");
                            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                            $valid = 0;
                            last;
                        } 
                    }
                    return 0 unless ($valid) ;
                }

                my %args_m = %args;
                $args_m{-ce_name} = $resolveAlias->{MASTER}->{1}->{NAME} || $args{-tms_alias};
                unless ($args{-template_from_user}) { #default template 
                    $logger->debug(__PACKAGE__ . ".$sub: Using default template for Master PSX");
                    $args_m{-template_file} = $source_path."/".$args{-obj_type}."/psx_master.yaml";
                }

                unless ( $self->heatStackCreate(\%args_m,\%argHash) ){
                    $logger->error(__PACKAGE__ . ".$sub: Instance creation failed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub: Instance creation successfull");

                #getting the ips
                $logger->debug(__PACKAGE__. ".$sub: Getting the external IPs for different networks");
		$output{'instance'} = ["$args_m{-ce_name}"];
		$output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
                my @ips;
                unless (@ips = $self->fetchIps(%output)) {
                    $logger->error(__PACKAGE__ . ".$sub: Faield to fetch ip's so unable to proceed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if($ips[0]{MGT0}{PUBLIC}{IP});
                push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if($ips[0]{MGT0}{PUBLIC}{IPV6});


#                $self->{PSX_MASTER} = "$args_m{-ce_name}";#PSX_MASTER is used to delete the instance when master is created
                $resolveAlias->{MGMTNIF}->{1}->{IP} = $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if( $ips[0]{MGT0}{PUBLIC}{IP});
                $resolveAlias->{MGMTNIF}->{1}->{IPV6} = $resolveAlias->{NODE}->{1}->{IPV6} = $ips[0]{MGT0}{PUBLIC}{IPV6} if( $ips[0]{MGT0}{PUBLIC}{IPV6});
                $resolveAlias->{NODE}->{1}->{HW_PLATFORM} = 'Linux';
                $resolveAlias->{NODE}->{1}->{INTERFACE} ||= 'e1000g0';
            }
            #GR CREATION STARTS
            if(exists $resolveAlias->{CLOUD_INPUT}->{2} && !$args{-slave}){
                delete $argHash{$netHash{$args{-obj_type}}{SIGNIF}{1}};
                delete $argHash{$netHash{$args{-obj_type}}{NIF}{1}};$args{-gr} = 1;
                #Removed a line which prefers SLAVE_CLOUD input against the parameters from newFromAlias
                if (($resolveAlias->{VM_CTRL}->{3}->{NAME} && ($resolveAlias->{VM_CTRL}->{3}->{TYPE} eq 'OpenStack')) && !$args{-flag}) { #TOOLS-12934
                    my $vmCtrlObj3;
                    $logger->debug(__PACKAGE__ . ".$sub: creating VMCTRL3 Object");
                    $resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file} = '';
                    my $vmCtrlAlias = $resolveAlias->{VM_CTRL}->{3}->{NAME};
                    unless ($vm_ctrl_obj{$vmCtrlAlias}) {
                        unless($vmCtrlObj3 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $vmCtrlAlias, -ignore_xml => 0, -sessionLog => 1, -iptype => 'any', -return_on_fail => 1)) {
                            $logger->debug(__PACKAGE__ . ".$sub: Failed to create VMCTRL3 Object");
                            return 0;
                        }
                    }
                    else {
                        $logger->debug(__PACKAGE__ . ".$sub: VMCTRL3 obj is already present");
                        $vmCtrlObj3 = $vm_ctrl_obj{$vmCtrlAlias};
                    }
                    $vmCtrlObj3->{CE_CREATED} = $self->{CE_CREATED};
                    $vmCtrlObj3->{CE_EXIST} = $self->{CE_EXIST};
                    $self = $vmCtrlObj3;
                }
                unless($args{-flag}) {
                    $args{-parameter} = $parameter_bk; #retaining the parameters passed in newFromAlias
                    unless ($resolveAlias->{CLOUD_INPUT}->{2}->{TEMPLATE_FILE}) {
                        $logger->debug(__PACKAGE__ . ".$sub: Using default template for Slave PSX");
                        $args{-template_file} = $source_path."/".$args{-obj_type}."/dualv4.yaml";
                        $args{-template_from_user} = 0;
                    }
                    else {
                        $args{-template_file} = $resolveAlias->{CLOUD_INPUT}->{2}->{TEMPLATE_FILE} if (exists $resolveAlias->{CLOUD_INPUT}->{2}->{TEMPLATE_FILE});
                        $logger->debug(__PACKAGE__ . ".$sub: Template provided from User for Slave PSX");
                        $args{-template_from_user} = 1;
                        if ($resolveAlias->{CLOUD_INPUT}->{2}->{ENV_FILE}) {
                            $args{-env_file} = $resolveAlias->{CLOUD_INPUT}->{2}->{ENV_FILE} || $args{-env_file};
                            $args{-env_name} = $1 if ($args{-env_file} =~ /\/.+\/(.+)$/);
                        }
                    }
                    $args{-flag} = 1;
                    unless ($self->resolveCloudInstance(%args)) {
                        $logger->error(__PACKAGE__ . ".$sub: Failed to fetch Cloud Instance details from VmCtrl3");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        return 0;
                    }
                    return $resolveAlias;
                }
                $args{-flag}=0;
                $args{-ce_name} = $resolveAlias->{MASTER}->{2}->{NAME} || $args{-tms_alias};
                #get the mandatory arguments

                $argHash{"Image"} =  $resolveAlias->{CLOUD_INPUT}->{2}->{IMAGE} || $resolveAlias->{CLOUD_INPUT}->{1}->{IMAGE} || $args{-Image};
                $argHash{"Flavor"} =  $resolveAlias->{CLOUD_INPUT}->{2}->{FLAVOR} || $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-Flavor};
                $argHash{"SecurityGroup"} =  $resolveAlias->{CLOUD_INPUT}->{2}->{SECURITY_GROUPS} || $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITY_GROUPS} || $args{-security_groups} ;

                unless ($args{-env_file}) {
                    $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                    foreach ( 'Image', 'Flavor', 'SecurityGroup'  ) {
                        unless ($argHash{$_}) {
                            $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in TMS alias");
                            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                            $valid = 0;
                            last;
                        }
                    }
                    return 0 unless ($valid) ;
                }
                
                $argHash{MasterHostname} =  ($resolveAlias->{MASTER}->{1}->{NAME} || $resolveAlias->{MASTER}->{1}->{HOSTNAME}) || $args{-master_hostname};
                $argHash{MasterIP} = $resolveAlias->{NODE}->{1}->{IP} || $resolveAlias->{NODE}->{1}->{IPV6} || $args{-master_ip} || $main::TESTBED{$main::TESTBED{$argHash{MasterHostname}}.":hash"}{NODE}{1}{IP}; # TOOLS - 12929 If Master Ip is unknown, can pick it from TESTBED

#               just to make sure if Master PSX is up or not

                $checkStatusHash{$args{-obj_type}}->{-identity_file} =$resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file};#TOOLS-15336
                $checkStatusHash{$args{-obj_type}}->{-resolveAlias} = $resolveAlias;
                $checkStatusHash{$args{-obj_type}}->{-ip} = $argHash{MasterIP};
                $checkStatusHash{$args{-obj_type}}->{-instance} = $argHash{MasterHostname};
                
                unless ($self->checkInstanceStatus($args{-obj_type})) {
                    $logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$argHash{MasterHostname}] -> [$argHash{MasterIP}] is not up");
                    $logger->warn(__PACKAGE__ . ".$sub: Keeping the instance for debugging.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            
                $logger->debug(__PACKAGE__ . ".$sub: Master Cloud Instance is reachable");
                $self->{CE_CREATED} = 0;
                $self->{CE_EXIST} = 0;
                $logger->debug(__PACKAGE__ . ".$sub: Fetching the Master PSX Cloud Instance SSH Keys");
                my %sshKeysArgs = (
                                -ip => $argHash{MasterIP},
                                -userid => 'ssuser',
                                -passwd => 'ssuser',
                                -identity_file => $args{-key_file},
                                );

                unless ( $argHash{MasterSshKey} = SonusQA::ATSHELPER::getSshKey( \%sshKeysArgs ) ) {
                        $logger->error(__PACKAGE__ . ".$sub: Couldn't get Master PSX Cloud Instance $argHash{MasterHostname} SSH keys.");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        return 0;
                }
                unless ( $self->heatStackCreate(\%args,\%argHash) ){
                    $logger->error(__PACKAGE__ . ".$sub: Instance creation failed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub: Instance creation successfull");

                #getting the ips
                $logger->debug(__PACKAGE__. ".$sub: Getting the external IPs for different networks");
                $output{'instance'} = ["$args{-ce_name}"];
                $output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
                my @ips;
                unless (@ips = $self->fetchIps(%output)) {
                    $logger->error(__PACKAGE__ . ".$sub: Faield to fetch ip's so unable to proceed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if($ips[0]{MGT0}{PUBLIC}{IP});
                push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if($ips[0]{MGT0}{PUBLIC}{IPV6});


#                $self->{PSX_MASTER} = "$args_m{-ce_name}";#PSX_MASTER is used to delete the instance when master is created
                $resolveAlias->{NODE}->{1}->{IP} = $resolveAlias->{GR}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if( $ips[0]{MGT0}{PUBLIC}{IP});#TOOLS-18101
                $resolveAlias->{NODE}->{1}->{IPV6} = $resolveAlias->{GR}->{1}->{IPV6} = $ips[0]{MGT0}{PUBLIC}{IPV6} if( $ips[0]{MGT0}{PUBLIC}{IPV6});
                $argHash{GrIP} = $resolveAlias->{GR}->{1}->{IP} || $resolveAlias->{GR}->{1}->{IPV6};
                $argHash{GrHostname} =  ($resolveAlias->{MASTER}->{2}->{NAME} || $resolveAlias->{MASTER}->{2}->{HOSTNAME});
                $checkStatusHash{$args{-obj_type}}->{-identity_file} = $resolveAlias->{LOGIN}->{2}->{KEY_FILE} = $args{-key_file};#TOOLS-15336
                $checkStatusHash{$args{-obj_type}}->{-resolveAlias} = $resolveAlias;
                $checkStatusHash{$args{-obj_type}}->{-ip} = $argHash{GrIP};
                $checkStatusHash{$args{-obj_type}}->{-instance} = $argHash{GrHostname};
                unless ($self->checkInstanceStatus($args{-obj_type})) {
                    $logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$argHash{GrHostname}] -> [$argHash{GrIP}] is not up");
                    $logger->warn(__PACKAGE__ . ".$sub: Keeping the instance for debugging");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }

                $logger->debug(__PACKAGE__ . ".$sub: GR Cloud Instance is reachable");
                $self->{CE_CREATED} = 0;
                $self->{CE_EXIST} = 0;
                $args{-gr}=0;
            }

            #SLAVE CREATION STARTS
            if(exists $resolveAlias->{SLAVE_CLOUD} && !$args{-gr}){
                $args{-slave} = 1;
		#Removed a line which prefers SLAVE_CLOUD input against the parameters from newFromAlias
                if (($resolveAlias->{VM_CTRL}->{2}->{NAME} && ($resolveAlias->{VM_CTRL}->{2}->{TYPE} eq 'OpenStack')) && !$args{-flag}) { #TOOLS-12934
                    my $vmCtrlObj2;
                    $logger->debug(__PACKAGE__ . ".$sub: creating VMCTRL2 Object");
                    $resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $resolveAlias->{LOGIN}->{2}->{KEY_FILE} = $args{-key_file} = '';
                    my $vmCtrlAlias = $resolveAlias->{VM_CTRL}->{2}->{NAME};
                    unless ($vm_ctrl_obj{$vmCtrlAlias}) {
                        unless($vmCtrlObj2 = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $vmCtrlAlias, -ignore_xml => 0, -sessionLog => 1, -iptype => 'any', -return_on_fail => 1)) {
                            $logger->debug(__PACKAGE__ . ".$sub: Failed to create VMCTRL2 Object");
                            return 0;
                        }
                    }
                    else {
                        $logger->debug(__PACKAGE__ . ".$sub: VMCTRL2 obj is already present");
                        $vmCtrlObj2 = $vm_ctrl_obj{$vmCtrlAlias};
                    }
		    $vmCtrlObj2->{CE_CREATED} = $self->{CE_CREATED};
		    $vmCtrlObj2->{CE_EXIST} = $self->{CE_EXIST};
		    $self = $vmCtrlObj2;
		}
                unless($args{-flag}) {
                    $args{-parameter} = $parameter_bk; #retaining the parameters passed in newFromAlias
            	    unless ($resolveAlias->{SLAVE_CLOUD}->{1}->{TEMPLATE_FILE}) {
                        $logger->debug(__PACKAGE__ . ".$sub: Using default template for Slave PSX");
                        $args{-template_file} = $source_path."/".$args{-obj_type}."/dualv4.yaml";
                        $args{-template_from_user} = 0;
                    }
                    else {
	                $args{-template_file} = $resolveAlias->{SLAVE_CLOUD}->{1}->{TEMPLATE_FILE};
                        $logger->debug(__PACKAGE__ . ".$sub: Template provided from User for Slave PSX");
                        $args{-template_from_user} = 1;
                        if ($resolveAlias->{SLAVE_CLOUD}->{1}->{ENV_FILE}) {
                            $args{-env_file} = $resolveAlias->{SLAVE_CLOUD}->{1}->{ENV_FILE} || $args{-env_file};
                            $args{-env_name} = $1 if ($args{-env_file} =~ /\/.+\/(.+)$/);
                        }
                    }
		    $args{-flag} = 1;
		    unless ($self->resolveCloudInstance(%args)) {
                   	$logger->error(__PACKAGE__ . ".$sub: Failed to fetch Cloud Instance details from VmCtrl2");
                   	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                   	return 0;
               	    }
               	    return $resolveAlias;
                }
                $argHash{$netHash{$args{-obj_type}}{SIGNIF}{1}} = $networks{$netHash{$args{-obj_type}}{SIGNIF}{1}}{id};
                $argHash{$netHash{$args{-obj_type}}{NIF}{1}} = $networks{$netHash{$args{-obj_type}}{NIF}{1}}{id};#TOOLS-15000 - SRv4 PSX
                $args{-ce_name} = $args{-tms_alias};
                #get the mandatory arguments

                $argHash{"Flavor"} = $resolveAlias->{SLAVE_CLOUD}->{1}->{FLAVOR} || $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-Flavor};
                $argHash{"SecurityGroup"} = $resolveAlias->{SLAVE_CLOUD}->{1}->{SECURITY_GROUPS} || $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITY_GROUPS} || $args{-security_groups} ;

                unless ($args{-env_file}) {
                    $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                    foreach ( 'Image', 'Flavor', 'SecurityGroup'  ) {
                        unless ($argHash{$_}) {
                            $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in TMS alias");
                            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                            $valid = 0;
                            last;
                        }
                    }
                    return 0 unless ($valid) ;
                }

                $argHash{MasterHostname} =  ($resolveAlias->{MASTER}->{1}->{NAME} || $resolveAlias->{MASTER}->{1}->{HOSTNAME}) || $args{-master_hostname};
                $argHash{MasterIP} = $resolveAlias->{NODE}->{1}->{IP} || $resolveAlias->{NODE}->{1}->{IPV6} || $args{-master_ip} || $main::TESTBED{$main::TESTBED{$argHash{MasterHostname}}.":hash"}{NODE}{1}{IP}; # TOOLS - 12929 If Master Ip is unknown, can pick it from TESTBED 

#		just to make sure if Master PSX is up or not
#              MGMTNIF-1-IP is set only for master. So, in case of only slave we shouldn't wait 4 mins for master, so setting CE_EXIST to 1.
		$self->{CE_EXIST} = 1 unless(exists $resolveAlias->{MGMTNIF}->{1}->{IP}); #TOOLS-17932
		$checkStatusHash{$args{-obj_type}}->{-identity_file} =$resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file};#TOOLS-15336
		$checkStatusHash{$args{-obj_type}}->{-resolveAlias} = $resolveAlias;
		$checkStatusHash{$args{-obj_type}}->{-ip} = $argHash{MasterIP};
        $checkStatusHash{$args{-obj_type}}->{-instance} = $argHash{MasterHostname};

        unless ($self->checkInstanceStatus($args{-obj_type})) {
            $logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$argHash{MasterHostname}] -> [$argHash{MasterIP}] is not up");
            $logger->warn(__PACKAGE__ . ".$sub: Keeping the intance for debugging");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        
        $logger->debug(__PACKAGE__ . ".$sub: Master Cloud Instance is reachable");
        $self->{CE_CREATED} = 0;
		$self->{CE_EXIST} = 0;
		$logger->debug(__PACKAGE__ . ".$sub: Fetching the Master PSX Cloud Instance SSH Keys");
		my %sshKeysArgs = ( 
				-ip => $argHash{MasterIP},
				-userid => 'ssuser',
				-passwd => 'ssuser',
				-identity_file => $args{-key_file},
				);

		unless ( $argHash{MasterSshKey} = SonusQA::ATSHELPER::getSshKey( \%sshKeysArgs ) ) {
			$logger->error(__PACKAGE__ . ".$sub: Couldn't get Master PSX Cloud Instance $argHash{MasterHostname} SSH keys.");
			$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
			return 0;
		}
#             If psx configuration is required after Spawning the instance
                if ( $resolveAlias->{ CONFIG }->{ 1 }->{ NAME } =~ /(^\S+\/)(\S+.tar.*$)/im ) {
			$logger->debug( __PACKAGE__ . ".$sub: Configuring Master PSX using $2 dump file at location $1" );
			my $masterObj = undef;

#             Args required for creating master psx object
			my %masterArgs = (
					-obj_user       => 'ssuser',
					-obj_password   => 'ssuser',
					-comm_type      => 'SSH',
					-obj_host       => $argHash{ MasterIP },
					-sessionLog     => 1,
					-return_on_fail => 1,
					-ROOTPASSWD     => 'sonus'
					);
			unless ( $masterObj = SonusQA::PSX->new(%masterArgs) ) {
				$logger->error( __PACKAGE__ . ".$sub: PSX Obj Creation FAILED for $argHash{MasterIP}" );
				$logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [0]" );
				return 0;
			}

#             Args required for configurePSXFromDump sub routine
			my %args = (
					-dumpFileName     => $2,
					-localDir         => $1,
					-ip               => $argHash{ MasterIP },
					-userid           => 'ssuser',
					-password         => 'ssuser',
					-rootpasswd       => 'sonus',
					-key              => $args{ -key_file },
					-ConfigureTimeout => 5,
				   );

			unless ( $masterObj->configurePSXFromDump(%args) ) {
				$logger->error( __PACKAGE__ . ".$sub: configurePSXFromDump failed" );
				$logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [0]" );
				return 0;
			}
			$masterObj->closeConn;
 		} 
  		unless ( $self->heatStackCreate(\%args,\%argHash) ){
                    $logger->error(__PACKAGE__ . ".$sub: Instance creation failed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }

                #getting the ips
                $logger->debug(__PACKAGE__. ".$sub: Getting the external IPs for different networks");
    	        $output{instance} = ["$args{-ce_name}"];
	        $output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
	        $output{$networks{$netHash{$args{-obj_type}}{SIGNIF}{1}}{name}} = 'SIG';
	        $output{$networks{$netHash{$args{-obj_type}}{NIF}{1}}{name}} = 'ENUM'; #TOOLS-15000 - SRv4 PSX 
                my @ips;
                unless (@ips = $self->fetchIps(%output)){
                    $logger->error(__PACKAGE__ . ".$sub: Faield to fetch ip's so unable to proceed");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                @pingArr = ();
		if($args{-usemgmt}) {  # TOOLS-17872
                    push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if ($ips[0]{MGT0}{PUBLIC}{IP});
                    push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if ($ips[0]{MGT0}{PUBLIC}{IPV6});
                }
                else {
                    push (@pingArr, $ips[0]{SIG}{PUBLIC}{IP}) if ($ips[0]{SIG}{PUBLIC}{IP});
                    push (@pingArr, $ips[0]{SIG}{PUBLIC}{IPV6}) if ($ips[0]{SIG}{PUBLIC}{IPV6});
                }

                $resolveAlias->{SLAVE_CLOUD}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if($ips[0]{MGT0}{PUBLIC}{IP});
                $resolveAlias->{SLAVE_CLOUD}->{2}->{IP} = $ips[0]{SIG}{PUBLIC}{IP} if($ips[0]{SIG}{PUBLIC}{IP});
                $resolveAlias->{SLAVE_CLOUD}->{3}->{IP} = $ips[0]{ENUM}{PUBLIC}{IP} if($ips[0]{ENUM}{PUBLIC}{IP});#TOOLS-15000 - SRv4 PSX

                $resolveAlias->{SLAVE_CLOUD}->{1}->{IPV6} = $ips[0]{MGT0}{PUBLIC}{IPV6} if($ips[0]{MGT0}{PUBLIC}{IPV6});
                $resolveAlias->{SLAVE_CLOUD}->{2}->{IPV6} = $ips[0]{SIG}{PUBLIC}{IPV6} if($ips[0]{SIG}{PUBLIC}{IPV6});
                $resolveAlias->{SLAVE_CLOUD}->{3}->{IPV6} = $ips[0]{ENUM}{PUBLIC}{IPV6} if($ips[0]{ENUM}{PUBLIC}{IPV6});#TOOLS-15000 - SRv4 PSX

                $resolveAlias->{SLAVE_CLOUD}->{1}->{USERID} ||= 'ssuser';
                $resolveAlias->{SLAVE_CLOUD}->{1}->{PASSWD} ||= 'ssuser';
                $resolveAlias->{SLAVE_CLOUD}->{1}->{HOSTNAME} = $resolveAlias->{NODE}->{1}->{NAME} = $resolveAlias->{NODE}->{1}->{HOSTNAME} ||= $args{-tms_alias};
                $resolveAlias->{DO_NOT_DELETE} = $args{-do_not_delete};

                # TOOLS-77465 fetching gw from metada
=sample
                 'metadata' => {
                            'IF2' => {
                                       'IPV4' => '10.34.151.119/23',
                                       'GWV4' => '10.34.150.1',
                                       'FIPV4' => '',
                                       'Port' => 'eth1'
                                     },
                              'IF1' => {
                                       'GWV4' => '10.34.148.177/23',
                                       'IPV4' => '10.34.148.1',
                                       'FIPV4' => '',
                                       'Port' => 'eth0'
                                     }
                          }

                'metadata' => {
                            'IF2' => {
                                       'IPV6' => 'fd00:10:6b50:5c50::b/60',
                                       'GWV6' => 'fd00:10:6b50:5c50::1',
                                       'Port' => 'eth1'
                                     },
                              'IF1' => {
                                       'GWV6' => 'fd00:10:6b50:5c30::1',
                                       'IPV6' => 'fd00:10:6b50:5c30::13/60',
                                       'FIPV6' => '',
                                       'Port' => 'eth0'
                                     }
                          }
=cut

                $resolveAlias->{SLAVE_CLOUD}->{1}->{DEFAULT_GATEWAY} = $ips[0]{metadata}{IF1}{GWV4} if($ips[0]{metadata}{IF1}{GWV4});
                $resolveAlias->{SLAVE_CLOUD}->{2}->{DEFAULT_GATEWAY} = $ips[0]{metadata}{IF2}{GWV4} if($ips[0]{metadata}{IF2}{GWV4});
                $resolveAlias->{SLAVE_CLOUD}->{1}->{DEFAULT_GATEWAY_V6} = $ips[0]{metadata}{IF1}{GWV6} if($ips[0]{metadata}{IF1}{GWV6});
                $resolveAlias->{SLAVE_CLOUD}->{2}->{DEFAULT_GATEWAY_V6} = $ips[0]{metadata}{IF2}{GWV6} if($ips[0]{metadata}{IF2}{GWV6});

            }
        }
	elsif ($args{-obj_type} =~ /EMS/i) {
            $argHash{"Image"} =  $resolveAlias->{CLOUD_INPUT}->{1}->{IMAGE} || $args{-Image};
            $argHash{"Flavor"} = $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-Flavor};
            unless ( $args{-env_file}) {
                $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                foreach ( 'Flavor','Image' ) {
                    unless ( $argHash{$_} ) {
                        $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\ 'is neither passed as a argument directly, nor defined in TMS alias");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        $valid = 0;
                        last;
                    }
                }
                return 0 unless ($valid) ;
            }
            $args{-ce_name} ||= $args{-tms_alias};
            unless ($self->heatStackCreate(\%args, \%argHash)) {
                $logger->error(__PACKAGE__ . ".$sub: Unable to create the cloud instance");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }

	    $output{instance} = [$args{-ce_name}];
	    $output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
            my @ips;
            unless (@ips = $self->fetchIps(%output)) {
                $logger->error(__PACKAGE__ . ".$sub: unable to fetch the Ips");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }

            push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if ($ips[0]{MGT0}{PUBLIC}{IP});
	    push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if ($ips[0]{MGT0}{PUBLIC}{IPV6});
            $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if ($ips[0]{MGT0}{PUBLIC}{IP});
	    $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IPV6} if ($ips[0]{MGT0}{PUBLIC}{IPV6});
        }
        elsif ($args{-obj_type} =~ /CDA/i) {
            $argHash{"Image"} =  $resolveAlias->{CLOUD_INPUT}->{1}->{IMAGE} || $args{-Image};
            $argHash{"Flavor"} = $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-Flavor};
            $argHash{"SecurityGroup"} = $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITYGROUP} || $args{-SecurityGroup} ;
            unless ( $args{-env_file}) {
                $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
                foreach ( 'Flavor','Image', 'SecurityGroup' ) {
                    unless ( $argHash{$_} ) {
                        $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in TMS alias");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        $valid = 0;
                        last;
                    }
                }
                return 0 unless ($valid) ;
            } 
            $args{-ce_name} ||= $args{-tms_alias};
            unless ($self->heatStackCreate(\%args, \%argHash)) {
                $logger->error(__PACKAGE__ . ".$sub: Unable to create the cloud instance");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }

	    $output{instance} = [$args{-ce_name}];
	    $output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
            my @ips;
            unless (@ips = $self->fetchIps(%output)) {
                $logger->error(__PACKAGE__ . ".$sub: unable to fetch the Ips");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }

            push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if ($ips[0]{MGT0}{PUBLIC}{IP});
            push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if ($ips[0]{MGT0}{PUBLIC}{IPV6});
            $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if ($ips[0]{MGT0}{PUBLIC}{IP});
            $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IPV6} if ($ips[0]{MGT0}{PUBLIC}{IPV6});

        }
        elsif ($args{-obj_type} =~ /VNFM/i) {
            delete $argHash{Image};#TOOLS-18015
            my %temp = (
	                   VNFM_SIMPLEX => {IMAGE => ['image_id'], FLAVOR => ['flavor']},        #TOOLS-19317
                           VNFM_HA => {
                                   IMAGE => ['app_image_id', 'db_image_id', 'lb_image_id'],#TOOLS-18016
                                   FLAVOR => ['app_flavor_id', 'db_flavor_id', 'lb_flavor_id'],
                           }
                       );
  
            my $valid = 1;
	    foreach (keys %{$temp{$type}}){
                    for(my $i=0; $i <= $#{$temp{$type}{$_}}; $i++ ){

                        $argHash{$temp{$type}{$_}->[$i]} = $resolveAlias->{CLOUD_INPUT}->{$i+1}->{$_} || $args{-$_}->[$i];
                        unless($argHash{$temp{$type}{$_}->[$i]}){
                            $logger->error(__PACKAGE__ . ".$sub: ERROR: Mandatory argumernt $temp{$type}{$_}->[$i] is neither passed as a argument directly, nor defiend in TMS alias");                                     
                            $valid = 0;
                        }
                    }                    
            }
	    unless($valid){
		$logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
	        return 0;
            }		

	    $args{-ce_name} ||= $args{-tms_alias};

	    unless ($self->heatStackCreate(\%args,\%argHash)) {
		$logger->error(__PACKAGE__. ".$sub: Unable to create VNFM Instance ");
		$logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
		return 0;
	    }

	    $output{instance} = [$args{-ce_name}];
            my @ips;
            if($type eq 'VNFM_HA'){ #TOOLS-17452
                $output{'lb_vip_v4'} = ['MGT0','PUBLIC','IP'];
                $output{'lb_vip_v6'} = ['MGT0','PUBLIC','IPV6'];
                unless( @ips = $self->fetchIpsHeat(%output)){
	            $logger->error(__PACKAGE__ . ".$sub: Unable to fetch the Ips of VNFM HA");
                    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
   		    return 0;
	        }
                
            }elsif($type eq 'VNFM_SIMPLEX'){
                $output{VnfmAccessIpV6} = ['MGT0','PUBLIC','IPV6']; 			 #Enhancement for TOOLS-19326
                $output{VnfmAccessIpV4} = ['MGT0','PUBLIC','IP'];
            unless( @ips = $self->fetchIpsHeat(%output)){
                $logger->error(__PACKAGE__ . ".$sub: Unable to fetch the Ips");
                $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
                return 0;
                }
            }

            push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IP}) if ($ips[0]{MGT0}{PUBLIC}{IP});
            push (@pingArr, $ips[0]{MGT0}{PUBLIC}{IPV6}) if ($ips[0]{MGT0}{PUBLIC}{IPV6});
	    $resolveAlias->{MGMTNIF}->{1}->{IPV6} = $ips[0]{MGT0}{PUBLIC}{IPV6};
            $resolveAlias->{MGMTNIF}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} || $ips[0]{MGT0}{PUBLIC}{IPV6}; #TOOLS-19326
            $resolveAlias->{MGMTNIF}->{1}->{PORT} ||= ($type eq 'VNFM_HA')? 443 : 8443;#TOOLS-17452  #TOOLS-19433
            $resolveAlias->{LOGIN}->{1}->{USERID} ||= 'sysadmin';
            $resolveAlias->{LOGIN}->{1}->{PASSWD} ||= 'sysadmin!!';	

	    if ( $self->{CE_CREATED} ){
                my $sleep_time = ($type eq 'VNFM_HA') ? 960 : 60;
                $logger->debug(__PACKAGE__. ".$sub: Sleep $sleep_time seconds");
  	        sleep $sleep_time;	
            }
        }
	elsif($args{-obj_type} eq 'TOOLS' or $args{-obj_type} eq 'VMCCS'){
        $argHash{"flavor"} = $resolveAlias->{CLOUD_INPUT}->{1}->{FLAVOR} || $args{-flavor};
        $argHash{"security_group"} = $resolveAlias->{CLOUD_INPUT}->{1}->{SECURITY_GROUPS} || $args{-security_groups} ;

        unless ($args{-env_file}) {
            $logger->debug(__PACKAGE__ . ".$sub: env file is not passed, checking if mandatory arguments are provided");
            foreach ( 'image', 'flavor', 'security_group' ) {
                unless ($argHash{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in TMS alias");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    $valid = 0;
                    last;
                }
            }
            return 0 unless ($valid) ;
        }
    
        $args{-ce_name} ||= $args{-tms_alias};
 
	    unless ( $self->heatStackCreate(\%args,\%argHash) ){
            $logger->error(__PACKAGE__ . ".$sub: Instance creation failed");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub: Instance creation successfull");

        #getting the ips
        $logger->debug(__PACKAGE__. ".$sub: Getting the external IPs for different networks");
        $output{'instance'} = ["$args{-ce_name}"];
        if($args{-obj_type} eq 'VMCCS') {
            $output{'private_net_mgmt'} = $networks{$netHash{$args{-obj_type}}{EXT_NIF}{1}}{name} if (exists $networks{$netHash{$args{-obj_type}}{EXT_NIF}{1}}{name});
            $output{'private_net_sig'} = $networks{$netHash{$args{-obj_type}}{EXT_SIG_NIF}{1}}{name} if (exists $networks{$netHash{$args{-obj_type}}{EXT_SIG_NIF}{1}}{name});            
        } else {
            $output{$networks{$netHash{$args{-obj_type}}{MGMTNIF}{1}}{name}} = 'MGT0';
        }
        my @ips;
        unless (@ips = $self->fetchIps(%output)) {
            $logger->error(__PACKAGE__ . ".$sub: Faield to fetch ip's so unable to proceed");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

        $resolveAlias->{MGMTNIF}->{1}->{IP} = $resolveAlias->{NODE}->{1}->{IP} = $ips[0]{MGT0}{PUBLIC}{IP} if( $ips[0]{MGT0}{PUBLIC}{IP});
        $resolveAlias->{SIG}->{1}->{IP} = $ips[0]{SIG}{PUBLIC}{IP} if ($ips[0]{SIG}{PUBLIC}{IP});

 	    push (@pingArr, $resolveAlias->{NODE}->{1}->{IP}) if ($resolveAlias->{NODE}->{1}->{IP});
 	

        if($args{-obj_type} eq 'VMCCS'){
            $resolveAlias->{MGMTNIF}->{1}->{PORT} ||= '22';
            $resolveAlias->{LOGIN}->{1}->{USERID} ||= 'linuxadmin';
            $resolveAlias->{LOGIN}->{1}->{PASSWD} ||= 'sonus';            
        }
        unless($self->pingCloudInstance($pingArr[0])) {
            $logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$resolveAlias->{NODE}->{1}->{IP}] is not reachable");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
            return 0;
        }
	} else {
	    $logger->error(__PACKAGE__ . ".$sub: Unknown Object type \'$args{-obj_type}\'");
	    return 0;
	}
	$resolveAlias->{'CE_NAME'} = $args{-ce_name};
        unless($args{-obj_type} eq 'VNFM' or $args{-obj_type} eq 'TOOLS' or $args{-obj_type} eq 'VMCCS'){
	    #check status of the instance
            $checkStatusHash{$args{-obj_type}}->{-identity_file} = $resolveAlias->{LOGIN}->{1}->{KEY_FILE};
            $checkStatusHash{$args{-obj_type}}->{-ip} = $pingArr[0];
            $checkStatusHash{$args{-obj_type}}->{-failures_threshold} = $args{-failures_threshold} ; #TOOLS-15398
            $checkStatusHash{$args{-obj_type}}->{-instance} = $args{-ce_name};
            unless ($self->checkInstanceStatus($args{-obj_type})) {
		$logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$args{-ce_name}] -> [ $pingArr[0] ] is not up");
		$logger->warn(__PACKAGE__ . ".$sub: Keeping the instance for debugging");
		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
		return 0;
	     }   
	     else {
		 $logger->debug(__PACKAGE__.".$sub: Cloud Instance is reachable and is up and running!");
	     }
        }
        $self->{CE_CREATED} = 0; #Once CE-Instance is reachable, Deleting the Instance depends on $self->{DONOTDELETE} Flag, This line is required, to prevent calling subroutine deleteInstance, from subroutine closeConn
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
	return (($resolveAliasFemale) ? ($resolveAlias, $resolveAliasFemale) : $resolveAlias);
    }
}

=head2 SonusQA::VMCTRL::pingCloudInstance()

  This subroutine checks weather CE-Instance is reachable or not.
  It keep on pooling for max of 180 sec,to reach the host. 

=over

=item Arguments

  Mandatory Args:
    $hostIp:  Its the Ip of CE-Instance which we want to connect.

=item Returns

  0   - Fails to reach CE-Instance with in 60secs
  1   - CE-Instance is reachable.

=item Example

    unless($self->pingCloudInstance($resolveAlias->{MGMTNIF}{1}{'IP'})){
        $logger->error(__PACKAGE__ . ".$sub: Cloud Instance \'$resolveAlias->{MGMTNIF}{1}{'IP'} \' is not reachable ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub pingCloudInstance{
    my ($self, @hostIp) = @_;
    my $sub = "pingCloudInstance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__. "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    my $wait = 180;
    my $reachable;
    my $ip;

    foreach (@hostIp) {
	$ip = $_;
	$reachable = 0;
        $logger->debug(__PACKAGE__ . ".$sub: Check Cloud instance \'$ip\' is reachable or not ");

	my $ping = 'ping6';
	$ping = 'ping' if ($ip =~ /^\d+\.\d+\.\d+\.\d+$/i);
	while (1) {
	    my @pingResult = `$ping -c 4 $ip`;
            if (grep (/\s0\% packet loss/i, @pingResult) or grep (/is alive/i, @pingResult)) {
        	$logger->debug(__PACKAGE__ . ".$sub: CE-Instance [$ip] is reachable");
        	$reachable = 1;
		last;
	    }
	    $wait -= 10;
	    ($wait >= 0) ? sleep 10 : last;
	}
    }

    unless ($reachable){
        $logger->error(__PACKAGE__ . ".$sub: Host \'$ip\' is not reachable ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::deleteInstance()

  This subroutine is to delete the CE-Instance and free the FloatingIps created for that instance.

=over

=item Arguments

  Mandatory Args:
    tmsAlias:  deletes the CE-Instance of tmsAlias name.

  Optional Args:
     delete_cinder = 1 , if need to delete, 0 if not

=item Example

    $self->deleteInstance($ceName); 

=back

=cut

sub deleteInstance{
    my ($self,$ceName, $delete_instance)=@_;
    my $sub = "deleteInstance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    my @cmdResult;
    
    unless ($ceName){
        $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter \$ceName does not exist. Cannot delete instance");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    if($delete_instance){
        $logger->debug(__PACKAGE__. ".$sub: Removing cinder volume attached to the instance $ceName");
        $self->cinderDelete(-name => $ceName);
    }

    if ($self->{$ceName} eq 'nova') {
        unless(@cmdResult = $self->execCmd( "nova delete $ceName" )){
            $logger->error(__PACKAGE__ . ".$sub: Got error while deleting the Cloud Instance");
        }
        if(grep(/Request.*accepted/, @cmdResult)){
            $logger->debug(__PACKAGE__. ".$sub: Request accepted to delete the cloud instance \'$ceName\'");
            $logger->debug(__PACKAGE__. ".$sub: verify deleting cloud instance \'$ceName\' completed or not");
        }
        unless(@cmdResult = $self->execCmd( "nova show $ceName", -return_error => 1 )){
            $logger->error(__PACKAGE__ . ".$sub: Failed to get the information about Cloud Instance");
        }
        if (grep(/ERROR.*/, @cmdResult)){
            $logger->debug(__PACKAGE__. ".$sub: successfully deleted the cloud instance \'$ceName\' ");
        }else{
            $logger->debug(__PACKAGE__. ".$sub: cloud instance \'$ceName\' is not yet deleted, wiating 60 sec for that deletion to complete");
            sleep 60;
        }
        $logger->debug(__PACKAGE__. ".$sub:  Delete the floatingIps for the \'$ceName\' Cloud Instance");
        foreach my $netList (keys %{$self->{interfacesInfo}}){
            if ($self->{interfacesInfo}{$netList}{'floatingIpAdd'}){
                $logger->debug(__PACKAGE__. ".$sub: deleting floatingIp of [$netList]");
                @cmdResult = $self->execCmd("neutron floatingip-delete $self->{interfacesInfo}{$netList}{'floatingIpAdd'} ");
             }
        }
    }
    else {
	my ($prematch, $match);
	my $new_cmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack stack " : "heat stack-";
	unless ($self->{conn}->print($new_cmd."delete ".$ceName)) {
	    $logger->error(__PACKAGE__ . ".$sub: Couldn't issue 'heat stack-delete command'");
	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	    return 0;
	}
	unless (($prematch, $match) = $self->{conn}->waitfor (
						-match => $self->{PROMPT},
						-match => '/y\/N/i',
						-errmode => "return",
						-timeout => 60
				)) {
	    $logger->error(__PACKAGE__ . ".$sub: Didnot get the expected patterns: ". $self->{conn}->lastline);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	    return 0;
	}
	if ($match =~ m/y\/N/i) {
	    $self->{conn}->print("y");
	    unless (($prematch, $match) = $self->{conn}->waitfor(
						-match => $self->{PROMPT},
						-errmode => "return",
						-timeout => 60	
				)) {
		$logger->error(__PACKAGE__.".$sub: failed to delete the instance");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
		$logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	}

	unless (@cmdResult = $self->execCmd( $new_cmd."show ".$ceName)) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to get the information about Cloud Instance");
        }
        if (grep(/Stack not found:.*/, @cmdResult)){
            $logger->debug(__PACKAGE__. ".$sub: successfully deleted the cloud instance \'$ceName\' ");
        }
    }
    $self->{CE_CREATED} = 0;
   `rm /home/$ENV{ USER }/ats_user/logs/.${ceName}_$main::job_uuid` if($main::job_uuid);
 
    $main::TESTBED{$main::TESTBED{$ceName}.':hash'}->{RESOLVE_CLOUD} = 0 if(exists $main::TESTBED{$main::TESTBED{$ceName}.':hash'}->{RESOLVE_CLOUD}); #if PSX instance is deleted RESOLVE_CLOUD flag should be 0  
    if(exists $self->{DELETE_IMAGE}){
        $self->execCmd("glance image-delete @{$self->{DELETE_IMAGE}}");
        delete $self->{DELETE_IMAGE};
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::execCmd()

  This function enables user to execute any command on the server, and looks for the 'ERROR' message in command result, if 'ERROR' is found it returns '0', else returns '@cmdResults' array.
  If user want to get the '@cmdResults' array, even when 'ERROR' message found in command result, they can pass '-return_erro' flag as argument, see the below e.g. 

=over

=item Arguments

  1. Command to be executed.
  2. Timeout in seconds (optional).

=item Returns

  Output of the command executed.

=item Example

    my @cmdResult= $self->execCmd("nova delete $ceName");
      This would execute the command "nova delete $ceName" on the Open Stack VM_CTRL and return the output of the command.
            (OR)
    unless (@cmdResult = $self->execCmd( "nova show $ceName", -timeout => 100, -return_error => 1 )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the Cloud-Instance details");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 

=back

=cut

sub execCmd{
   my ($self,$cmd,%args)=@_;
   my $sub = "execCmd";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
   my(@cmdResults,$timestamp);
   $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
   my $timeout = ($args{-timeout}) ? $args{-timeout} : $self->{DEFAULTTIMEOUT};
   $logger->debug(__PACKAGE__ . ".$sub Using $timeout seconds as timeout.");
   $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->warn(__PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".$sub  CLI ERROR DETECTED, CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".$sub  $cmd");
      $logger->error(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);

      $logger->warn(__PACKAGE__ . ".$sub  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".$sub \t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      return @cmdResults;
   }
   if($cmdResults[0] =~ /WARNING/){
       $logger->debug(__PACKAGE__ . ".$sub: Removing [$cmdResults[0]] from \@cmdResults as its a warning");
       shift(@cmdResults);
   }
   $self->{CMDRESULTS} = \@cmdResults;
   if ((grep(/ERROR.*/i, @cmdResults)) && (! $args{-return_error})){
        $logger->error(__PACKAGE__. ".$sub: ERROR message came, command issued: $cmd  ");
        $logger->error(__PACKAGE__. ".$sub: ERROR messge: ". Dumper(\@cmdResults));
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ()");
        return ();
   }else{
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ");
       return @cmdResults;
   }
}

=head2 SonusQA::VMCTRL::closeConn()

  This subroutine overrides the Base.closeConn, calls deleteInstance subroutine to delete CE-Instance, 

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub closeConn {
    my ($self) = @_;
    my $sub = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    if ($self->{conn}){
        $self->{conn}->print("exit");
        $self->{conn}->close;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ");
}

=head2 SonusQA::VMCTRL::addKeysToTemplate()

  This subroutine adds ssh-keys to the template file.

=over

=item Arguments

  Mandatory Args:
    - file -    The path of the template file in VM Controller

=item Returns

  1 - When keys are added 

=back

=cut

sub addKeysToTemplate {
    my ($self, $file) = @_;
    my $sub = "addKeysToTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: ---> Entered Sub");

    my ($result) = $self->execCmd("grep -e \"ssh[_|-]authorized[_|-]keys:\" $file");
    my $backupfile = $file."_backup";

    if ( $result =~ /ssh_authorized_keys/ ) {
	    $logger->debug(__PACKAGE__.".$sub: Adding ssh keys in PSX template");
	    my $command = "- ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==";
	    $self->execCmd( "awk '{print} /: EmsSshKey1/{ print substr(\$0,1,match(\$0,/[^[:space:]]/)-1) \"$command\" }' $file > $backupfile");
	    $self->execCmd( "yes | mv $backupfile $file");
    }
    elsif ($result =~ /ssh-authorized-keys/) {
        $logger->debug(__PACKAGE__.".$sub: Some ssh keys are present");
        my $command = "- ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==";
        $command=~ s/\//\\\//g;
        $self->execCmd("sed -i \"s/- ssh-rsa.*==/$command/g\" $file");
    }else {
        $logger->debug(__PACKAGE__.".$sub: No ssh keys are present");
        my @getSpaces= $self->execCmd("grep '#cloud-config' $file");
        my $space;
        if($getSpaces[0] =~ /(.*)#cloud-config/){
           $space = $1;
        }
        my $command = "\\n$space"."users:\\n$space  - name: linuxadmin\\n$space    ssh-authorized-keys:\\n$space      - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==\\n";
        $command .= "\\n$space  - name: admin\\n$space    ssh-authorized-keys:\\n$space      - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==\\n";
        $command=~ s/\//\\\//g;
        $self->execCmd("sed -i \"s/#cloud-config/\\n$space#cloud-config$command/g\" $file");
    }
    $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2 SonusQA::VMCTRL::addKeypair()

  This subroutine adds the keypair in the VM Controller.

=over

=item Arguments

  Mandatory Args:
      - key_name -    The name of the keypair
      - key_file -    The path of the keyfile in ats server

=item Returns

  1 - When keypair is added successfully
  0 - When error while adding the keypair

=back

=cut

sub addKeypair{
    my ($self, $key_name, $key_file)=@_;
    my $sub = 'addKeypair';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    my @cmdResults;

    my $dest_file = $key_file;
    my ($ls_out)=$self->execCmd("ls -l $key_file");
    if ($ls_out =~ /No such file or directory/) {
        $logger->debug(__PACKAGE__ . ".$sub: No such file or directory");
        my $user_home = qx#echo ~#;
        chomp ($user_home);
        my $user = $1 if ($user_home =~ /\/.+\/(.+)$/);
        my $time = time;
        $dest_file = "/tmp/".$user."_".$key_name."_".$time.".key.pub";

        my %scpArgs = (
                        -hostip         => $self->{OBJ_HOST},
                        -hostuser       => $self->{OBJ_USER},
                        -hostpasswd     => $self->{OBJ_PASSWORD},
                        -sourceFilePath => $key_file
                );
        $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$dest_file;

	$logger->debug(__PACKAGE__ . ".$sub: Secure copy the key file");
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy key file");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ .".$sub: The destination key file is $dest_file");

    my @result;
    #TOOLS-18776 - command is working in openstack 3.2.0, 3.14.2 and 2.2.0. so no need of version check.
    unless(@result = $self->execCmd("openstack keypair create --public-key $dest_file $key_name", -return_error => 1)){
        $logger->error(__PACKAGE__. ".$sub: Unable to add keypair for $key_name");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (0)");
        return 0;
    }

    if (my ($line) = grep /ERROR/, @result) {
        my $return = 0;
        if ($line =~ /already exists/i) {
            $logger->debug(__PACKAGE__ . ".$sub: keypair $key_name already exist");
            $return = 1;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub: Unknown error while adding keypair");
            $logger->error(__PACKAGE__ . ".$sub: error - $line");
        }
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$return]");
        return $return;
    }

    $logger->info(__PACKAGE__ . ".$sub: Added keypair for $key_file successfully.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (1)");
    return 1;
}

=head2 SonusQA::VMCTRL::validateKeypair()

  This subroutine checks if given keypair is present in the VM Controller.

=over

=item Arguments

  Mandatory Args:
    - key_name -    The name of the keypair
    - key_file -    The path of the keyfile in ats server

=item Returns

  1 - When keypair is found and finger_print is matched
  0 - When keypair is found but finger_print is not matched
 -1 - When keypair is not found

=back

=cut

sub validateKeypair{
    my ($self, $key_name, $key_file)=@_;

    my $sub = 'validateKeypair';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my @out;
    unless(@out = $self->execCmd("nova keypair-show $key_name", -return_error => 1)){
        $logger->error(__PACKAGE__. ".$sub: Unable to get keypair info for $key_name");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (0)");
        return 0;
    }

    my $finger_print;
    foreach(@out){
        if(/fingerprint\s\|\s(.+)\s\|/){
            $finger_print = $1;
            last;
        }
    }

    unless($finger_print){
        $logger->error(__PACKAGE__. ".$sub: keypair $key_name not found");
        $logger->debug(__PACKAGE__ . ".$sub: output: ". Dumper(\@out));
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (-1)");
	return -1;
    }

    my $ats_finger_print = `ssh-keygen -lf $key_file`;

#TOOLS-11020.. Finger prints are mentioned below for reference, 
#$finger_print is e1:ff:cc:4a:f9:18:1d:73:fe:36:64:68:22:fe:1b:ab
#$ats_finger_print, without '-E md5' is 2048 SHA256:V5T+ApDgwKn+IK7coOkSFoyLjAN59zRNkAUknsmbEFI no comment (RSA)
#$ats_finger_print, when using '-E md5' is 2048 MD5:e1:ff:cc:4a:f9:18:1d:73:fe:36:64:68:22:fe:1b:ab no comment (RSA)

    if($ats_finger_print =~ /\s+SHA256:/){
       $logger->debug(__PACKAGE__ . ".$sub: \$ats_finger_print is $ats_finger_print");
       $logger->debug(__PACKAGE__ . ".$sub: Fingerprint is derived from SHA so we'll try with md5");
       $ats_finger_print = `ssh-keygen -E md5 -lf $key_file`;
    }

    unless($ats_finger_print =~/(\s+|MD5:)$finger_print\s+/){
        $logger->error(__PACKAGE__. ".$sub: fingerprint is not matching for $key_name.");
        $logger->debug(__PACKAGE__ . ".$sub: finger_print: $finger_print, ats_finger_print: $ats_finger_print");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (0)");
        return 0;
    }

    $logger->info(__PACKAGE__. ".$sub: fingerprint is matching for $key_name.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (1)");
    return 1;
}

=head2 SonusQA::VMCTRL::fetchIps()

  This subroutine will get the ips of the created instance using the nova show comamnd.

=over

=item Arguments

  Mandatory Args
      - arg:          Hash of the network named and the instance name

=item Returns

  values - Hash refernce of the hash containing the ips.

=back

=cut

sub fetchIps {
    my $self = shift;
    my %params = @_;
    my $sub = "fetchIps";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");

    my @values = ();
    my $nu = 0;
    my @instances = @{$params{instance}};
    my $type = $params{type};
    delete $params{type};
    delete $params{'instance'};
    foreach (@instances) {
        my @result;
        unless (@result = $self->execCmd("nova show $_")) {
            $logger->error(__PACKAGE__ . ".$sub:  unable to execute nova show command");
            @values = ();
            last;
        }
        my $flag=0;
        my $metadata;
        foreach (@result) {
            if ($_ =~ /\|\s*(.*)\s+network\s*\|(.*)\|/) {
                my ($net, $ip) = ($1, $2);
                $net =~ s/\s//g;
                $ip =~ s/\s//g;
		        my @ipArr = split (',', $ip);

                #prefered is metadata
                if ($params{$net}) {
                    $values[$nu]{$params{$net}}{PUBLIC}{IP} = $values[$nu]{$params{$net}}{PUBLIC}{IP} || $ipArr[1] || $ipArr[0];
                    $values[$nu]{$params{$net}}{PRIVATE}{IP} = $ipArr[0];
                } elsif($type =~ /VMCCS/){
                    if($net =~/mgmt/){
                        $values[$nu]{MGT0}{PUBLIC}{IP} = $ipArr[1] || $ipArr[0];
                        $values[$nu]{MGT0}{PRIVATE}{IP} = $ipArr[0];
                    } elsif ($net =~/sig/){
                        $values[$nu]{SIG}{PUBLIC}{IP} = $ipArr[1] || $ipArr[0];
                        $values[$nu]{SIG}{PRIVATE}{IP} = $ipArr[0];                        
                    }
                }
            } 
            elsif (/\|\s*metadata\s+\|\s(.+)\s\|/ or $flag==1){
                if($_ =~ /^\|\s+(metadata|)\s*\|(.+)\|$/) {
                    $metadata=$metadata.$2;
                    $flag=1;
                    next;
                }
                $flag=0;
                my $hash = decode_json($metadata);
                my %all;
                foreach my $key (keys %$hash) {
                    my $key1 = ($key =~ /IF/) ? 'IF' : 'VIP';
                #TOOLS-13351. Added eval to prevent execution getting aborted when the $hash->{$key} is not in JSON format.
                    eval { $all{$key1}{$key} = decode_json($hash->{$key}) };
                    if($@){
                            $logger->warn(__PACKAGE__ . ".$sub:  Skipping $key, since the values is not in JSON format");
                            next;
                        }
                    $values[$nu]{metadata}{$key} = $all{$key1}{$key}; #TOOLS-8950
                }
                foreach my $ipKey (keys %{$all{IF}}){
                    next unless(exists $all{IF}{$ipKey}{Port});
                    $values[$nu]{uc $all{IF}{$ipKey}{Port}}{PUBLIC}{IP} = (split('/',$all{IF}{$ipKey}{IPV4}))[0] if(exists $all{IF}{$ipKey}{IPV4});
                    $values[$nu]{uc $all{IF}{$ipKey}{Port}}{PUBLIC}{IPV6} = (split('/',$all{IF}{$ipKey}{IPV6}))[0] if(exists $all{IF}{$ipKey}{IPV6});
                }
                foreach my $vipKey (keys %{$all{VIP}}) {
                    last unless ($all{IF});
                    next unless(exists $all{VIP}{$vipKey}{IFName});
                    next if ($all{IF}{$all{VIP}{$vipKey}{IFName}}{Port} =~ /mgt/i);
                    $values[$nu]{uc $all{IF}{$all{VIP}{$vipKey}{IFName}}{Port}}{PUBLIC}{IP} = $all{VIP}{$vipKey}{FIPV4}[0];
                }
	        }			
        }
	#for ipv6 and dual stack
        foreach my $val (values %params) {
            #dual stack START
            if (($values[$nu]{$val}{PRIVATE}{IP} =~ /:/) and ($values[$nu]{$val}{PUBLIC}{IP} =~ /\./)) {
                $values[$nu]{$val}{PUBLIC}{IPV6} = $values[$nu]{$val}{PRIVATE}{IP};
                delete $values[$nu]{$val}{PRIVATE} if (exists $values[$nu]{$val}{PRIVATE} );
            }
            elsif (($values[$nu]{$val}{PRIVATE}{IP} =~ /\./) and ($values[$nu]{$val}{PUBLIC}{IP} =~ /:/)) {
                $values[$nu]{$val}{PUBLIC}{IPV6} = $values[$nu]{$val}{PUBLIC}{IP};
                $values[$nu]{$val}{PUBLIC}{IP} = $values[$nu]{$val}{PRIVATE}{IP};
                delete $values[$nu]{$val}{PRIVATE} if (exists $values[$nu]{$val}{PRIVATE} );
            }
            #dual stack END

            #ipv6 START
            if ($values[$nu]{$val}{PUBLIC}{IP} =~ /:/) {
                $values[$nu]{$val}{PUBLIC}{IPV6} = $values[$nu]{$val}{PUBLIC}{IP};
                delete $values[$nu]{$val}{PUBLIC}{IP} if (exists $values[$nu]{$val}{PUBLIC}{IP} );
            }
            if ($values[$nu]{$val}{PRIVATE}{IP} =~ /:/) {
                $values[$nu]{$val}{PRIVATE}{IPV6} = $values[$nu]{$val}{PRIVATE}{IP};
                delete $values[$nu]{$val}{PRIVATE}{IP} if (exists $values[$nu]{$val}{PRIVATE}{IP});
            }
            #ipv6 END
        }
        $nu++;
    }

    $logger->debug(__PACKAGE__.".$sub: The ips for the instance are ".Dumper(\@values));
    $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub");
    return @values;
}

=head2 SonusQA::VMCTRL::fetchIpForNoDhcp()

  This subroutine will get the free ips from the provider's network for NODHCP.

=over

=item Arguments

  $hash: Hash reference of the subnet network names 
    For eg - my %hash = (
                'pkt0' => 'PKT0_PRIVATE_SUBNET',
                'pkt1' => 'PKT1_PRIVATE_SUBNET',
                'mgt0' => 'MGMT_PRIVATE_SUBNET',
                'ha0'  => 'HA_PRIVATE_SUBNET'
      )
  $ha - 
    1 - If the instance is HA
    0 - If the instance is SA
  $objType - The Object type of the instance.

=item Returns

  values - Hash refernce of the hash containing the ips.

=back

=cut

sub fetchIpForNoDhcp {
    my ($self, $ha, $subnets, $objType) = @_;
    my $sub = "fetchIpForNoDhcp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");
    my (@port, %values);

    unless (@port = $self->execCmd("neutron port-list")) {
        $logger->error(__PACKAGE__.".$sub: Couldn't get the port-list");
        $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my %used_hash;
    #get all the used Ips from the port list
    foreach (@port) {
        if ($_ =~ /"ip_address":\s+"(.*)"/) { #get the used ip addresses for the network
            my $version = Net::IP::ip_get_version($1);
            my $expanded_ip = Net::IP::ip_expand_address($1, $version);
            $used_hash{$expanded_ip} = 1;
        }
    }

    my $ini_count = ($ha) ? 1 : 0;

    my %output;
    unless (%output = $self->getSubNetDetails($subnets, $objType)) {
        $logger->error(__PACKAGE__.".$sub: Didnot get Subnet details");
        $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $pass = 1;
    my %count;
    foreach my $net (sort keys %output) {
        my ( $ips_count, $alt_ip_count ) = ( 0 , 0 );
        my @ips_count = split (";", $self->{ips_count}->{$net}) if (exists $self->{ips_count}->{$net});
        my @alt_ip_count = split (";", $self->{alt_ips}->{$net}) if (exists $self->{alt_ips}->{$net});
        foreach my $group ('IPADDRESS','ALT_IPS') {
            foreach my $subnet_hash (@{$output{$net}}) {
                $count{$group} = $ini_count;
                if (defined $ips_count[$ips_count] and $group eq 'IPADDRESS') {
                    $count{$group} = ($ha) ? ($ips_count[$ips_count] + 2) : ($ips_count[$ips_count]) - 1;
                    $ips_count[$ips_count+1] = $ips_count[$ips_count] unless (defined $ips_count[$ips_count+1]);
                    $ips_count++;
                }
                if (defined $alt_ip_count[$alt_ip_count] and $group eq 'ALT_IPS') {
                    $count{$group} = ($ha) ? ($alt_ip_count[$alt_ip_count] + 2) : ($alt_ip_count[$alt_ip_count]) - 1;
                    $alt_ip_count[$alt_ip_count+1] = $alt_ip_count[$alt_ip_count] unless (defined $alt_ip_count[$alt_ip_count+1]);
                    $alt_ip_count++;
                }
                next unless ($count{$group} >= 0);

                my $type = $subnet_hash->{ip_version};
                if($group eq 'IPADDRESS'){
                    $values{$net}{GATEWAY} .= "$subnet_hash->{gateway_ip},";  #10.54.222.1   #tools-8774
                    $values{$net}{PREFIX}  .= (join ',' ,(split("/", $subnet_hash->{cidr}))[1]).','; #24
                    $values{$net}{CIDR}    .= "$subnet_hash->{cidr},";
                    $values{$net}{NETMASK} .= (join ',' ,(split("/", $subnet_hash->{cidr}))[1]).','; #TOOLS-17907
                }

                my ($start, $end) = ($1, $2) if ($subnet_hash->{allocation_pools} =~ /{"start":\s*"(.+)",\s*"end":\s*"(.+)"}/);  #{"start":"fd00:10:6b50:4d20::2", "end": "fd00:10:6b50:4d2f:ffff:ffff:ffff:ffff}

                my $ipObj = '';
                unless ($ipObj = new Net::IP("$start - $end")) {
                    $logger->error(__PACKAGE__.".$sub: Unable to create IP Object");
                    $pass = 0;
                    last;
                }
                my $ip_allocated = 0;
                my $j = 0;
                foreach my $ip_state (keys %{$noDhcpHash{$group}{$objType}{$net}}){
                  { #this block will catch the last, since last/next/redo doesn't work for do-while loop
                      do {
                          my $ip = $ipObj->ip();
                          unless (exists ($used_hash{$ip})) { #if the ip address is used or not
                              my $version = Net::IP::ip_get_version($ip);
                              $used_hash{$ip} = 1;
                              $ip = Net::IP::ip_compress_address ($ip, $version);
                              $ip_allocated = 1;
                              $values{$net}{$ip_state} .= "$ip,";
                              $logger->debug(__PACKAGE__.".$sub: free ip for $net  $ip_state and IPV$type is '$ip'");
                              last if ($j == $count{$group});                              
                              $j++;
                          }
                      } while(++$ipObj);
                  }
                    unless ($ip_allocated) {
                        $logger->error(__PACKAGE__.".$sub: No free IP available for $net IPV$type $ip_state");
                        $pass = 0;
                        last;
                    }                
                }
            }  
        }
        last unless $pass;
    }
    $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub [$pass]");
    return ($pass) ? \%values : 0;
}

=head2 SonusQA::VMCTRL::heatStackCreate()

  This subroutine will be called from resolveCloudInstance to run the create/rebuild command and check if instance is up or not.
  It is a internal function.

=over

=item Arguments

  Mandatory Args
    - arg:		Hash reference of the user provided args
    - argsHash:	Hash reference of the argHash created in resolveCloudInstance

=item Returns

  1: When the instance creation/rebuild is successful
  0: When the instance creation/rebuild is not successful

=back

=cut

sub heatStackCreate{
    my $self = shift;
    my $arg = shift;
    my $argsHash = shift;
    my %args = %$arg;
    my %argHash = %$argsHash;
    my $sub = "heatStackCreate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: ---> Entered Sub");

    my @cmdResult;
    my $newCmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack stack show" : "heat stack-show";
    unless (@cmdResult = $self->execCmd( "$newCmd $args{-ce_name}" )) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to get instance details");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $resolveAlias = $args{-alias_hashref};
    if ($args{-obj_type} =~ /SBX/ and !$args{-template_from_user}) { #default template
        $args{-template_file} = "/sonus/p4/ws/release/sbx5000_".$main::TESTSUITE->{TESTED_RELEASE}."/orca/install/";
        if ($resolveAlias->{CLOUD_INPUT}->{1}->{TYPE} =~ /nodhcp/i) { #noDhcp
            $args{-template_file} .= ($args{-alias_hashref_female}) ? "heatHA11templateNoDhcp" : "heatStandaloneTemplateNoDhcp.yaml";
        }
        else {
            $args{-template_file} .= ($args{-alias_hashref_female}) ? "heatHA11template.yaml" : "heatStandaloneTemplate.yaml";
        }
    }

    my $time = time;
    $args{-template_name} = $1 if ($args{-template_file} =~ /\/.+\/(.+)$/);
    $args{-template_name} = $args{-user}."_".$args{-template_name}."_".$time; #the name in vmctrl

    my $rebuild = 0;
    my $image = ($args{-obj_type} =~ /(SBX|TOOLS|VMCCS)/) ? 'image' : 'Image';
    $image = 'image_id' if ($args{-obj_type} eq 'VNFM');
    if(exists $args{-parameter1} and $args{-parameter1} =~ /image_standby/){
       $argHash{image_active} = $argHash{$image}; #TOOLS-13759 : if `image_standby` is in parameter then make the key `image` to `image_active` and delete `image` key from command.
       delete $argHash{$image};
       $image = 'image_active';
    }
    $argHash{$image} =~ s/^\s+|\s+$//g ; 
    if (grep (/Stack not found.*$args{-ce_name}/i, @cmdResult)) { #heat stack-show will not throw ERROR, when instance is not present
        $logger->debug(__PACKAGE__. ".$sub: Need to create an Cloud Instance with name \'$args{-ce_name}\'");
	unless ($self->copyTemplateEnvFile(\%args)) {
            $logger->error(__PACKAGE__. ".$sub: Unable to copy the files");
            $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
            return 0;
        }

	#for noDhcp
	if (($resolveAlias->{CLOUD_INPUT}->{1}->{TYPE} =~ /nodhcp/i) || ($args{-nodhcp})) {
	    my ($resolveAliasFemale, $ha, $ip_hash) = ('', 0, '');
	    if ($args{-alias_hashref_female}) {
		$logger->debug(__PACKAGE__. ".$sub: It is a noDhcp HA instance.");
		$resolveAliasFemale = $args{-alias_hashref_female};
		$ha = 1 unless $noDhcpHash{'HA'};
	    }
	    unless($ip_hash = $self->fetchIpForNoDhcp($ha, $args{-parameter}, $args{-obj_type})) {
		$logger->error(__PACKAGE__. ".$sub: Failed to get the Ips for noDhcp");
		$logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
		return 0;
	    }
      
	    foreach my $param (sort keys %noDhcpHash) {   #TOOLS-19243
            next if ($param eq 'HA');
            foreach my $net (sort keys %$ip_hash) {
                foreach  (keys %{$noDhcpHash{$param}{$args{-obj_type}}{$net}}) {
                    my $chopper;
                    $chopper = ($param =~/IPADDRESS|ALT_IPS/ )?$ip_hash->{$net}->{$_}:$ip_hash->{$net}->{$param};
                    $chopper =~ s/.$//g;                                                                            #Removing the last comma (,)
                    $args{-parameter1} .= " -P $_=$chopper";
                    }
                }
            }

	    $args{-parameter1} .= " -P oam_ip_1=$ip_hash->{HA0}->{IPADDRESS}"  if(exists $args{-coam} and $args{-sbc_type} =~ /OAM/);
	    $args{-parameter1} =~ s/;/,/g;

	    #returning back the Ips in sbx object
	    $resolveAlias->{NODHCP} = $ip_hash;
	    $resolveAliasFemale->{NODHCP} = $ip_hash if ($resolveAliasFemale);
        }

        #create the heat command.
	my ($createCmd, $delimiter) = ("heat stack-create $args{-ce_name} -f $args{-template_file}", '-P');
	if ($self->{openstack_version} ge $versions{openstack}) {
            $createCmd = "openstack stack create $args{-ce_name} -t $args{-template_file}";
            $delimiter = '--parameter';
        }
        $createCmd .= " -e $args{-env_file}" if ($args{-env_file});

	if ($args{-parameter1}) {
	    $args{-parameter1} =~ s/-P/$delimiter/g if ($self->{openstack_version} ge $versions{openstack});
            $logger->debug(__PACKAGE__ . ".$sub: parameter is $args{-parameter1}");
            $createCmd .= "$args{-parameter1}";
        }
	else {
	    $logger->warn(__PACKAGE__ . ".$sub: No parameter is passed");
	}

        $createCmd .= " $delimiter ConfigDrive=True" if ($args{-obj_type} =~ /PSX/); #TOOLS-12934
	$createCmd .= " $delimiter cluster_id=$args{cluster_id}" if (exists $args{cluster_id});
        $createCmd .= " $delimiter cinder_volume_id=$args{-cinder_id}" if (exists $args{-cinder_id});
        $createCmd .= " $delimiter ems_ip_1=$args{ems_ip}" if (exists $args{ems_ip});
        foreach my $param (keys %argHash) {
	    $createCmd .= " $delimiter $param=$argHash{$param}" if ($argHash{$param});
        }

        unless (@cmdResult = $self->execCmd( "$createCmd" )) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute create command");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $self->{CE_CREATED} = 1; #created a HA Instance, need to be configured, this flag is to delete the CE, if configuration fails.
        `touch /home/$ENV{ USER }/ats_user/logs/.${args{-ce_name}}_$main::job_uuid` if($main::job_uuid);
    }
    elsif($resolveAlias->{VNFM_TYPE} eq 'VNFM_HA'){
        $logger->debug(__PACKAGE__. ".$sub: No need to check for Rebuild because its VNFM HA");
    }
    elsif (my ($line) = grep (/stack_status\s+/, @cmdResult)) {
        if ($line =~ /(CREATE|UPDATE)_COMPLETE/i) {
            $logger->debug(__PACKAGE__. ".$sub: Cloud Instance already exists, need to decide weather to SkipCreation or to ReBuild instance ");
	    $rebuild = 1;
            #check if force_rebuild flag is set or not
            if ($args{-force_rebuild}) { # If we want to re-build the HA-Instance with same build, with some updates.
                $logger->debug(__PACKAGE__ . ".$sub: -force_rebuild is enabled, going to rebuild $args{-ce_name}");
            }
            else {
                my $existedImage;
		map {$existedImage = $1 if ($_ =~ /\s*"?$image"?:\s"?(\S+)"?/i)} @cmdResult;
		$existedImage =~ s/[",]//g;
		$logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$args{-ce_name}\' is installed with image  \'$existedImage\'");

		my @result;
                #TOOLS-18776 - command is working in openstack 3.2.0, 3.14.2 and 2.2.0. so no need of version check.
                unless (@result = $self->execCmd("openstack image show $argHash{$image}")) {
                    $logger->error(__PACKAGE__ .".$sub: Failed to execute the command image-show");
                    $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[0]");
                    return 0;
                }
                foreach (@result) {
                    #checking if image matches with name or id
		    if ($_ =~ /\|\s+(id|name)\s+\|\s+($existedImage)\s+\|/) {
                    $logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$args{-ce_name}\' is already installed with Image: [$existedImage], no need to re-install with the same Image again, Skipping the Installation");
                    $self->{CE_EXIST} = 1; # Cloud instance already exists with this ce_name, Created/re-builded cloud Instances taking some time, for application to come up, we are using this flag for waiting.
		    $rebuild = 0;
		    last;
		    }
	        }
	    }
        }
        else {
            $logger->debug(__PACKAGE__. ".$sub: It seems Stack creation failed, rebuilding again.");
            $rebuild = 1;
        }
    }
    else { 
        $logger->error(__PACKAGE__. ".$sub: Some unknown error occurred.");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if ($rebuild) {
	unless ($self->copyTemplateEnvFile(\%args)) {
            $logger->error(__PACKAGE__. ".$sub: Unable to copy the files");
            $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
            return 0;
        }
	#TOOLS-15656
	if($args{-volume_name}) {
	    $self->cinderDelete(-name => $args{-ce_name});
	    my $newcinderID = $self->cinderCreate(-name => $args{-volume_name}, -size => $args{-volume_size});
	    unless($newcinderID) {
		$logger->error(__PACKAGE__ . ".$sub: Failed to create new volume");
		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	    $logger->debug(__PACKAGE__. ".$sub: Attaching new volume");
	    my $cinderCmd = "nova volume-attach " . $args{-ce_name} . " " . $newcinderID;
	    unless ($self->execCmd($cinderCmd)) {
             	$logger->error(__PACKAGE__ . ".$sub: Attaching volume failed.");
            	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            	return 0;
            }
	}
	my $rebuildCmd;
	$logger->debug(__PACKAGE__. ".$sub: Rebuilding cloud Instance \'$args{-ce_name}\' with $image \'$argHash{$image}\'");
	if ($self->{openstack_version} ge $versions{openstack}){
	    $args{-rollback} ||=  "enabled";
            $rebuildCmd = "openstack stack update $args{-ce_name} --rollback $args{-rollback} --parameter $image=$argHash{$image} --existing -t $args{-template_file}";	
	}
	else{
            $args{-rollback} ||=  "yes";	    
	    $rebuildCmd  = "heat stack-update $args{-ce_name} --rollback $args{-rollback} -P $image=$argHash{$image} -x -f $args{-template_file}";
	}
        unless ($self->execCmd($rebuildCmd)) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to get result for heat update command");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $self->{CE_CREATED} = 1;
        `touch /home/$ENV{ USER }/ats_user/logs/.${args{-ce_name}}_$main::job_uuid` if($main::job_uuid);
    }

    if ($self->{CE_CREATED}) {
        $logger->debug(__PACKAGE__. ".$sub: Successfully executed create/rebuild cmd for \'$args{-ce_name}\'");

        #Before we proceed, need to confirm Instance creation is completed.
        $logger->debug(__PACKAGE__. ".$sub: checking instance spawning completed or not");
        my $active = 0;
        my $wait = 3000; #Some times its taking much time for spawning a instnace, waiting for max 50 mins (TOOLS-75462)
        while (!$active && $wait) {
	    unless (@cmdResult = $self->execCmd( "$newCmd $args{-ce_name}" )) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to get result for heat show command");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            if (grep /stack_status[\s\|]+\s(CREATE|UPDATE)_IN_PROGRESS.*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: $args{-ce_name} Instance is still in \'(CREATE|UPDATE)_IN_PROGRESS\' state, waiting 10sec for spawning to complete ");
                sleep 10;
                $wait -= 10;
            }
            elsif (grep /stack_status[\s\|]+\s(CREATE|UPDATE)_COMPLETE.*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: $args{-ce_name} Instance is created/updated and in Running state.");
                $active = 1;
            }
            else {
                $logger->debug(__PACKAGE__. ".$sub: command result didn't match (CREATE|UPDATE)_IN_PROGRESS/(CREATE|UPDATE)_COMPLETE state.".Dumper(\@cmdResult));
                last;
            }
        }

        unless ($active) {
            $logger->error(__PACKAGE__. ".$sub: Instance didn't come to \'(CREATE|UPDATE)_COMPLETE\' state, after waiting for ${wait}sec");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

        if ($rebuild) { #check if rebuilt instance is build with new image
            my $installedImage;
	    map {$installedImage = $1 if ($_ =~/\s"?image"?:\s"?(\S+)"?/i)}@cmdResult;
	    $installedImage =~ s/[",]//g;
            unless ($installedImage eq $argHash{$image}) {
                $logger->error(__PACKAGE__. ".$sub: Failed to create/rebuild Cloud Instance \'$args{-ce_name}\' with \'$argHash{$image}\' image.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__. ".$sub: Cloud Instance \'$args{-ce_name}\' created/rebuilded successfully with Image: \'$installedImage\'");
        }
    }

    #delete the files copied before creation
    $self->execCmd("rm -f $args{-template_file}") if ($args{-template_file} =~ /^\/tmp/);
    $self->execCmd("rm -f $args{-env_file}") if (($args{-env_file}) and ($args{-env_file} =~ /^\/tmp/));

    if ($newCmd =~ /openstack/) {
          my $key_found = 0;
	  foreach (@cmdResult) {
		if ($_ =~ /\|\s*\|\s*output_key\:\s*instance(\d)_name.*\|/) {
		    $key_found = $1;
		}
		elsif ($_ =~ /\s*sbc_(active|standby)_name:\s+(\S+)/) {
		    #get the host name for the instances.
		    $arg->{-hostname}->{$1} = $2;
		}
                elsif ($_ =~ /\|\s*\|\s*"*ha0IPAddress"*\:\s*"*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"*,*\s*\|/) {
                    $arg->{sbc_rgIp} = $1;
                }
		if (($key_found) and ($_ =~ /\|\s*\|\s*output_value\:\s*(\S+)\s*\|/)) {
		    $arg->{instance_name}->{$key_found} = $1;
		    $key_found = 0;
		}
	  }
    }
    else {
	    my $val = '';
         foreach (@cmdResult) {
	        if ($_ =~ /\|\s*\|\s*"output_value"\:\s*"(.*)"\,\s*\|/) {
		    $val = $1;
                }
		elsif ($_ =~ /\|\s*\|\s*"output_key"\:\s*"instance(\d)_name".*\|/) {
		    $arg->{instance_name}->{$1} = $val;
		}
		elsif ($_ =~ /\s*"sbc_(active|standby)_name":\s+"(.+)"/) {
                    #get the host name for the instances.
		    $arg->{-hostname}->{$1} = $2;
		}
                elsif ($_ =~ /\|\s*\|\s*"ha0IPAddress"\:\s*"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})",\s*\|/){
                    $arg->{sbc_rgIp} = $1;
                }
	 }
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::novaBoot()

  The subroutine is used to create the cloud instance using nova.

=over

=item Arguments

  Mandatory Args
    - arg:		Hash reference of the user provided args

=item Returns

  1: When the instance creation/rebuild is successful
  0: When the instance creation/rebuild is not successful

=back

=cut

sub novaBoot {
    my $self = shift;
    my %args = @_;
    my $sub = "novaBoot";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    $logger->info(__PACKAGE__.".$sub: ---> Entered Sub");

    my (@cmdResult, @subNetListResult, %nifMap, %IntNetwork, %subNetwork,%argsHash);
    $args{-ce_name} ||= $args{-tms_alias};
    my $resolveAlias = ($args{-alias_hashref}) ? $args{-alias_hashref} : {};
    $args{-key_file} ||= $resolveAlias->{LOGIN}{1}{KEY_FILE};

    #get the mandatory arguments
    foreach (qw/ ce_name image flavor security_groups tenant_id /) {
        $args{"-$_"} = (($_ !~ 'tenant_id') ? $args{-alias_hashref}->{CLOUD_INPUT}->{1}->{uc $_} : $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{uc $_}) || $args{-$_};
        $logger->debug(__PACKAGE__ . ".$sub: $_ is $args{-$_}");
        unless ($args{-$_}) {
            $logger->error(__PACKAGE__ . ".$sub:  ERROR: The mandatory argument \'-$_\' is neither passed as a argument directly, nor defined in SBX alias");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

    #these arguments are not mandatory
    if ($args{-alias_hashref}->{CLOUD_INPUT}->{1}->{USER_DATA} or $args{-user_data}) {
        $args{"-user_data"} = $args{-alias_hashref}->{CLOUD_INPUT}->{1}->{USER_DATA} || $args {-user_data};
    }

    if ($args{-alias_hashref}->{CLOUD_INPUT}->{1}->{ZONE} or $args{-zone}) {
        $args{"-availability_zone"} = $args{-alias_hashref}->{CLOUD_INPUT}->{1}->{ZONE} || $args{-zone}
    }

    #get the internal and external network interface names
    $args{-int_net}{MGT0} = $self->{TMS_ALIAS_DATA}->{INT_NIF}->{1}->{NAME} || $args{-int_net}{MGT0};

    #External MGT is not mandatory
    if ($self->{TMS_ALIAS_DATA}->{EXT_NIF}->{1}->{NAME} || $args{-ext_net}{MGT0}) {
        $args{-ext_net}{MGT0} = $self->{TMS_ALIAS_DATA}->{EXT_NIF}->{1}->{NAME} || $args{-ext_net}{MGT0};
    }
    if ($args{-obj_type} =~ /SBX/) {
        %nifMap = ('MGT' => 'MGMTNIF', 'PKT' => 'PKT_NIF');
        #Internal Networks
        $args{-int_net}{PKT0} = $self->{TMS_ALIAS_DATA}->{INT_SIG_NIF}->{1}->{NAME} || $args{-int_net}{PKT0};
        $args{-int_net}{PKT1} = $self->{TMS_ALIAS_DATA}->{INT_SIG_NIF}->{2}->{NAME} || $args{-int_net}{PKT1};
        $args{-int_net}{HA} = $self->{TMS_ALIAS_DATA}->{INTER_CE_NIF}->{1}->{NAME} || $args{-int_net}{HA};
        #External Networks are not mandatory.
        if ($self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{1}->{NAME} || $args{-ext_net}{PKT0}) {
            $args{-ext_net}{PKT0} = $self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{1}->{NAME} || $args{-ext_net}{PKT0};
        }
        if ($self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{2}->{NAME} || $args{-ext_net}{PKT1}) {
            $args{-ext_net}{PKT1} = $self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{2}->{NAME} || $args{-ext_net}{PKT1};
        }
    }
    else {
        %nifMap = ('MGT' => 'NODE');
    }

    ##ssh key
    if($args{-key_file}){
        $resolveAlias->{LOGIN}->{1}->{KEY_FILE} = $args{-key_file};
        $args{-public_key_file} = $args{-key_file} .'.pub';
        $args{-key_name} = (split("/",$args{-key_file}))[-1];
        $args{-key_name} =~s/\.key//;

        my $ret;
        unless($ret = $self->validateKeypair($args{-key_name}, $args{-public_key_file})){
            $logger->error(__PACKAGE__ . ".$sub:  Couldn't validate keypair for $args{-key_name}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

        if($ret == -1){ #need to add keypair
            unless($self->addKeypair($args{-key_name}, $args{-public_key_file})){
                $logger->error(__PACKAGE__ . ".$sub:  Couldn't add keypair for $args{-key_name}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }
    }
    #initiateCloudInstance()
    unless($self->initiateCloudInstance(\%args)){
        $logger->error(__PACKAGE__ . ".$sub: Creating Cloud Instance has failed");
        $self->deleteInstance($args{-ce_name}) if ($self->{CE_CREATED});
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $self->{$args{-ce_name}} = "nova"; #to specify that it is a stand alone instance, will be used in deleting
    $resolveAlias->{CE_NAME} = $args{-ce_name};
    $resolveAlias->{$resolveAlias->{CE_NAME}} = "nova"; #to specify it is created using nova for the sbx instance
    $logger->debug(__PACKAGE__ . ".$sub: Get the CE-Instance details");
    unless (@cmdResult = $self->execCmd( "nova show $args{-ce_name}" )){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the Cloud-Instance details");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    %IntNetwork = %{$args{-int_net}};
    foreach my $interface (keys %IntNetwork){
        my $allIPs;
        map {$allIPs = $1 if ($_ =~ /^\|\s$IntNetwork{$interface}\snetwork\s+\|\s([\w.:,\s]+)/)} @cmdResult;
        if($allIPs){
            $allIPs =~ s/\s//g;
            my @ipList = split ",", $allIPs;
            $logger->debug(__PACKAGE__ . ".$sub: IP list for $IntNetwork{$interface} network: [@ipList]");
            foreach my $ip (@ipList){
                if($interface =~ /([a-zA-Z]+)(\d)/){
                    my ($name,$no) = ($1,$2);
                    ($ip =~ /^[\w:]+$/) ? $resolveAlias->{$nifMap{uc $name}}{$no+1}{'IPV6'} = $ip : $resolveAlias->{$nifMap{uc $name}}{$no+1}{'IP'} = $ip;
                }
            }
        }else{
            $logger->debug(__PACKAGE__ . ".$sub: Network entry \'$IntNetwork{$interface}\' given for \'$interface\' interface in CE_INPUT{-int_net}, is not among the networks which are used to spawn the \'$args{-ce_name}\' Cloud-Instance");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    foreach my $interface (keys %{$args{-interfaces_info}}){
        if ($interface !~ /HA/){
            foreach my $subNetId (@{$args{-interfaces_info}{$interface}{'SUBNET_ID'}}){
                my ($gwIp,@snShow);
                unless(@snShow = $self->execCmd( "neutron  subnet-show $subNetId" )){
                    $logger->error(__PACKAGE__ . ".$sub: Failed to get details of \'$subNetwork{$interface}\' sub-network");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
                map {$gwIp = $1 if($_ =~ /^\|\sgateway_ip\s+\|\s([\w.:]+)\s+\|/)} @snShow;
                if($interface =~ /([a-zA-Z]+)(\d)/){
                    my ($name,$no) = ($1,$2);
                    ($gwIp =~ /^[\w:]+$/) ? $resolveAlias->{$nifMap{uc $name}}{$no+1}{'DEFAULT_GATEWAY_V6'} = $gwIp : $resolveAlias->{$nifMap{uc $name}}{$no+1}{'DEFAULT_GATEWAY'} = $gwIp ;
                }

            }
        }
    }
#checking whethere the below values are there in TMS ,if not it will assign it to default values
    if ($args{-obj_type} =~ /SBX/){
        $resolveAlias->{LOGIN}->{1}->{ROOTPASSWD} ||= 'sonus1' ;
        $resolveAlias->{LOGIN}->{1}->{USERID} ||= 'admin' ;
        $resolveAlias->{LOGIN}->{1}->{PASSWD} ||= 'admin';
        $resolveAlias->{SIG_SIP} = clone($resolveAlias->{PKT_NIF});
        $resolveAlias->{SIG_SIP}->{1}->{PORT} ||= '5060' ;
        $resolveAlias->{SIG_SIP}->{2}->{PORT} ||= '5060' if($resolveAlias->{PKT_NIF}->{2});
    }
    $logger->debug(__PACKAGE__ . ".$sub:  Fetched Required information about CE-Instance ");
    $logger->debug(__PACKAGE__ . ".$sub:  Check Cloud instance is reachable or not ");
    unless($self->pingCloudInstance($resolveAlias->{$nifMap{MGT}}{1}{'IP'})){
        $logger->error(__PACKAGE__ . ".$sub: Cloud Instance \'$resolveAlias->{MGMTNIF}{1}{'IP'} \' is not reachable ");
        $self->deleteInstance($args{-ce_name}) if($self->{CE_CREATED} && (! $args{-do_not_delete})); # deleting CE-Instance, only if we created it and -doNotDelete flag is not set.
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{CE_EXIST}){
        $logger->debug(__PACKAGE__ . ".$sub: Cloud Instance is reachable but it takes some time to connect after Creation/re-build, waiting for 60sec");
        sleep 60;
        delete $self->{CE_EXIST};
    }
    $self->{CE_CREATED} = 0; #Once CE-Instance is reachable, Deleting the Instance depends on $self->{DONOTDELETE} Flag, This line is required, to prevent calling subroutine deleteInstance, from sub closeConn
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return $resolveAlias;
}

=head2 SonusQA::VMCTRL::createGlanceImage()

  This subroutine is used to create glance image from the qcow2 path.

=over

=item Arguments

  Mandatory Args
    -qcow2_path : absolute path of qcow2 image
  Optional Args
    -keep_image: we will resolve the cloud instance and assign the values to this variable. By default image will be deleted from closeConn()

=item Returns

  glance image id: created glance image id for success
  0 : when it fails to derive glance image name or glance image-create fails

=item Example

    qcow2 build path
    /sonus/p4/ws/release/sbx5000_V05.00.01A782/orca/rel/sbc-V05.00.01A782-connexip-os_03.00.03-A782_amd64-cloud.qcow2
     /sonus/p4/ws/dmccracken/dsbc_cloud_merge/orca/rel/sbc-V05.00.01A783-connexip-os_03.00.03-A783_amd64-cloud.qcow2
     glance image should be sbc-dmccracken-dsbc_cloud_merge-V05.00.01A783-os_03.00.03-A783
     <product>-<workspace>-<app version>-<os version>

    unless ($glance_image = $vmctrl_obj->createGlanceImage(-qcow2_path => $qcow2_path, -keep_image => 1)){
        $logger->error(__PACKAGE__ . ".$sub: Failed to create glance image from '$qcow2_path'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub createGlanceImage{
    my ($self, %arg)=@_;
    my $qcow2_path = $arg{-qcow2_path};
    my $keep_image = $arg{-keep_image};

    my $sub = 'createGlanceImage';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    unless($qcow2_path){
        $logger->error(__PACKAGE__ . ".$sub: Mandatory argument qcow2_path is missing.");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    my $glance_image;

    unless($glance_image = deriveGlanceImage($qcow2_path)){
        $logger->error(__PACKAGE__ . ".$sub:  Couldn't derive glance image from '$qcow2_path'.");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }
    
    my (@image_create_out, $image_id);
    @image_create_out = $self->execCmd("openstack image show $glance_image | grep -w \"id\"");
    if($image_create_out[0] =~ /Could not find resource/i){

	    # checking whether the source path is mounted
	    my $destination_file = $qcow2_path;
	    my ($ls_out)=$self->execCmd("ls -l $destination_file");
	    if($ls_out=~/No such file or directory/){
	        $destination_file = "/tmp/$glance_image.qcow2";
	
	        my %scpArgs = (
	            -hostip => $self->{OBJ_HOST},
	            -hostuser => $self->{OBJ_USER},
	            -hostpasswd => $self->{OBJ_PASSWORD},
	            -sourceFilePath => $qcow2_path,
	            -destinationFilePath => $self->{OBJ_HOST}.":$destination_file"
	        );

	        unless(&SonusQA::Base::secureCopy(%scpArgs)){
        	    $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy qcow2");
	            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
	            return 0;
	        }
	    }
    
	    my $glance_cmd = "glance image-create --name $glance_image --disk-format qcow2 --container-format bare --is-public true --file $destination_file --progress";
	    $glance_cmd =~ s/--is-public true/--visibility public/ if ($self->{glance_version} ge $versions{glance});
	
	    unless(@image_create_out = $self->execCmd($glance_cmd, -timeout => 900)){
	        $logger->error(__PACKAGE__. ".$sub: Unable to create glance image, $glance_image from $destination_file");
	        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub (0)");
	        return 0;
	    }

	    foreach (@image_create_out){
        	if (/^\|\s+id\s+\|\s(.+)\s+\|/) {
	            $image_id = $1;
	            last;
	        }
	    }	

	    unless($image_id){
        	$logger->error(__PACKAGE__. ".$sub: glance image creation failed. Output: ". Dumper(\@image_create_out));
	    }
	    else{
        	$logger->info(__PACKAGE__ . ".$sub: Successfully created glance image, $glance_image ($image_id) from $destination_file");
	    }

	    unless($self->execCmd("rm -f $destination_file")){
	        $logger->error(__PACKAGE__. ".$sub: Unable to remove $destination_file");
	    }

	    push (@{$self->{DELETE_IMAGE}}, $image_id) unless($keep_image); #to delete glance image

	    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ($image_id)");
    }
    else{
	$image_id = $1 if($image_create_out[0] =~ /^\|\s+id\s+\|\s(.+)\s+\|/);	
    }
    return $image_id;
}

=head2 SonusQA::VMCTRL::deriveGlanceImage()

  This subroutine is used to derive the glance image name from the qcow2 path.

=over

=item Arguments

  Mandatory Args
    - qcow2_path : absolute path of qcow2 image

=item Returns

  glance image : derived glance image name for success
  '' : when it fails to derive glance image name

=item Example

  qcow2 build path
  /sonus/p4/ws/release/sbx5000_V05.00.01A782/orca/rel/sbc-V05.00.01A782-connexip-os_03.00.03-A782_amd64-cloud.qcow2
  /sonus/p4/ws/dmccracken/dsbc_cloud_merge/orca/rel/sbc-V05.00.01A783-connexip-os_03.00.03-A783_amd64-cloud.qcow2
  glance image should be sbc-dmccracken-dsbc_cloud_merge-V05.00.01A783-os_03.00.03-A783
  <product>-<workspace>-<app version>-<os version>

=back

=cut

sub deriveGlanceImage{
    my ($qcow2_path) = @_;

    my $sub = 'deriveGlanceImage';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my $glance_image = '';
    # <product>-<workspace>-<app version>-<os version>
    if($qcow2_path=~ /ws\/(.+)\/orca.+\/(.+)-([^-]+\-*[ARSFEB]\d{3}).+(os_.+)_.+\.qcow2$/){
        $glance_image = "$2-$1-$3-$4";
        $glance_image=~s/\//-/g;
    }
    elsif($qcow2_path=~ /.*\/(.+)\.qcow2$/){
        $glance_image = "$ENV{'USER'}-$1";
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub:  Couldn't derive glance image from '$qcow2_path'.");
    }
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$glance_image]");
    return $glance_image;
}

=head2 SonusQA::VMCTRL::getNetworkIdName()

  This subroutine is used to get the network's id and name using neutron net-list command and tenant-id.

=over

=item Arguments

  Mandatory Args
    - argHash : Hash reference containing the names of the networks.

=item Returns

  %networks : Hash containing the name and id of each network.

=item Example

  $argHash{mgt0_ext_network}     = $self->{TMS_ALIAS_DATA}->{EXT_NIF}->{1}->{NAME};
  $argHash{pkt0_ext_network}     = $self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{1}->{NAME};
  $argHash{pkt1_ext_network}     = $self->{TMS_ALIAS_DATA}->{EXT_SIG_NIF}->{2}->{NAME};
  $argHash{private_network_mgt0} = $self->{TMS_ALIAS_DATA}->{INT_NIF}->{1}->{NAME};
  $argHash{private_network_pkt0} = $self->{TMS_ALIAS_DATA}->{INT_SIG_NIF}->{1}->{NAME};
  $argHash{private_network_pkt1} = $self->{TMS_ALIAS_DATA}->{INT_SIG_NIF}->{2}->{NAME};
  $argHash{private_network_ha}   = $self->{TMS_ALIAS_DATA}->{INTER_CE_NIF}->{1}->{NAME};

  my %networks;
  unless (%networks = $self->getNetworkIdName($argHash)) {
      $logger->error(__PACKAGE__ . ".$sub: Failed to get the network names and ids");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
  }

=back

=cut

sub getNetworkIdName {
    my ($self, $argHash) = @_;
    my $sub = "getNetworkIdName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my (@cmdResult, %networks) = ((), ());
    #TOOLS-18776 - command is working in openstack 3.2.0, 3.14.2 and 2.2.0. so no need of version check.
    my $cmd = 'openstack network list';

    $cmd .= " --tenant_id $argHash->{tenant_id}" if($argHash->{tenant_id});
    delete $argHash->{tenant_id};

    unless (@cmdResult = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the output of neutron net-list command");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    foreach my $network (keys (%$argHash)) {
        next unless ($argHash->{$network});
        $logger->debug(__PACKAGE__ . ".$sub: Value of $network is ".$argHash->{$network});
        my @grep_result = grep /\s+$argHash->{$network}\s+/, @cmdResult;
        my $no = @grep_result;
        unless ($no == 1) {
            $logger->error(__PACKAGE__ . ".$sub: There are too many or too few networks present for ".$argHash->{$network});
            $logger->debug(__PACKAGE__ . ".$sub: Result after grep is ".Dumper(\@grep_result));
            %networks = ();
            last;
        }
        my $line = $grep_result[0];
        (undef, $networks{$network}{id}, $networks{$network}{name}) = split(/\|/, $line);
        $networks{$network}{id} =~ s/\s//g;
        $logger->debug(__PACKAGE__ . ".$sub: id $networks{$network}{id}");
        $networks{$network}{name} =~ s/\s//g;
        $logger->debug(__PACKAGE__ . ".$sub: name $networks{$network}{name}");
        $argHash->{$network} = $networks{$network}{id}; #will use id to create the instance
    }
    $logger->debug(__PACKAGE__ . ".$sub: networks are ".Dumper(\%networks));
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
    return %networks;
}

=head2 SonusQA::VMCTRL::getSubNetDetails()

  This subroutine is used to get the subnet details.

=over

=item Arguments

  Mandatory Args
    - $parameter - Hash reference containig the subnet names/id
    - $objType  -  Type of instance

=item Returns

  %output : Hash containing the subnet details of each subnet


=back

=cut

sub getSubNetDetails{
    my ($self, $parameter, $objType) = @_;

    my $sub = 'getSubNetDetails';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my (%hash, @result, %output) = ((), (), ());

    my @array1;
    if($parameter=~/\|/){
        @array1 = split('\|', $parameter);
    }
    else{
         @array1 = split(',', $parameter);
    }

    foreach my $param (@array1) {
        next unless ($param =~ /subnet/i);
        my @array2 = split("=", $param);
	map {$hash{$_} = $array2[1] if ($array2[0] eq $subnetHash{$objType}{$_})} keys (%{$subnetHash{$objType}});
    }

    $logger->debug(__PACKAGE__. ".$sub: subnet Hash is ".Dumper(\%hash));
    foreach my $net(keys %hash){
        my @subnets = split(";", $hash{$net}); #for dual stack
        foreach my $subnet (@subnets) {
            my $ip_range = "{\"start\": \""."$1"."\", \"end\": \""."$2"."\"}" if $subnet =~ s/\[(\S+?)-(\S+?)\]//; #TOOLS-20177
            unless (@result = $self->execCmd("neutron subnet-show $subnet")) {
                $logger->error(__PACKAGE__.".$sub: Couldn't get the $subnet subnet information");
                %output = ();
                last;
            }
            my %out = ();
            foreach (@result) {
                if ($_ =~ /^\|\s+(.+)\s+\|\s(.+)\s+\|/) {
                    my ($match1,$match2) = ($1,$2);
                    $match1 =~ s/\s+//;
                    $match2 =~ s/\s+//;
                    $out{$match1} = ($match1 eq 'allocation_pools' and defined $ip_range)?$ip_range:$match2; #TOOLS-20177
                }
            }
	    push (@{$output{uc $net}}, \%out);
        }
        last unless (%output);
    }
    $logger->debug(__PACKAGE__. ".$sub: <--- Leaving Sub");
    return %output;
}

=head2 SonusQA::VMCTRL::mandatoryKeyPair()

  This subroutine is used to check and add the keyPair in Vm_controller.

=over

=item Arguments

  Mandatory Args
    - args - Hash reference containing the user provided data

=item Returns

  Nothing

=back

=cut

sub mandatoryKeyPair {
    my ($self, $args) = @_;
    my $sub = "mandatoryKeyPair";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");

    my $key_name = $1 if ($args->{-key_file} =~ /\/.+\/(.+)$/);
    $key_name =~ s/\.key//;

    my $ret;
    unless($ret = $self->validateKeypair($key_name, $args->{-key_file}.".pub")) {
        $logger->error(__PACKAGE__ . ".$sub:  Couldn't validate keypair for $key_name");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    if ($ret == -1){ #need to add keypair
        unless($self->addKeypair($key_name, $args->{-key_file}.".pub")){
            $logger->error(__PACKAGE__ . ".$sub:  Couldn't add keypair for $key_name");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2 SonusQA::VMCTRL::copyTemplateEnvFile()

  This subroutine is used to check and copy the template and env file to vm_controller
  It also calls the subroutine which add keys to template.

=over

=item Arguments

  Mandatory Args
    - args - Hash reference containing the user provided data

=item Returns

  Nothing

=back

=cut

sub copyTemplateEnvFile {
    my ($self, $args) = @_;
    my $sub = "copyTemplateEnvFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");

    my $path = "/tmp";
    my %scpArgs = (
                -hostip     => $self->{OBJ_HOST},
                -hostuser   => $self->{OBJ_USER},
                -hostpasswd => $self->{OBJ_PASSWORD}
        );

    my $ls_out;
    if ($args->{-env_file}) {
        ($ls_out) = $self->execCmd("ls -l $args->{-env_file}");
        if ($ls_out =~ /No such file or directory/) {
            $logger->debug(__PACKAGE__ . ".$sub: No such file or directory");
            $scpArgs{-sourceFilePath} = $args->{-env_file}; #bats server
            $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$path."/".$args->{-env_name}; #in VMCTRL
            $logger->debug(__PACKAGE__ . ".$sub: copying file '$args->{-env_name}' to VM_CTRL");

            unless(&SonusQA::Base::secureCopy(%scpArgs)){
                $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy file '$args->{-env_name}' to VM_CTRL");
                $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                return 0;
            }
            $args->{-env_file} = $path."/".$args->{-env_name};
        }
    }

    ($ls_out) = $self->execCmd("ls -l $args->{-template_file}");
    if ($ls_out =~ /No such file or directory/) {
        $logger->debug(__PACKAGE__ . ".$sub: No such file or directory");

        $scpArgs{-sourceFilePath} = $args->{-template_file}; #bats server
        $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$path."/".$args->{-template_name}; #in VMCTRL

        $logger->debug(__PACKAGE__ . ".$sub: secure copying file '$args->{-template_name}' to VM_CTRL");
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy file '$args->{-template_name}' to VM_CTRL");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub: Copying file '$args->{-template_name}' to VM_CTRL");
        unless ($self->execCmd("cp $args->{-template_file} $path/$args->{-template_name}")) {
            $logger->error(__PACKAGE__ . ".$sub:  failed to copy file '$args->{-template_name}' to VM_CTRL");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
    }
    $args->{-template_file} = $path."/".$args->{-template_name};

    if ( ( ($args->{-obj_type} =~ /SBX/) or ($args->{-obj_type} =~ /PSX/) ) and (!$args->{-key_from_user}) and (!$args->{-configurator}) ) { #TOOLS-12934
        $logger->debug(__PACKAGE__. ".$sub: Adding keys to template file");
#        $self->addKeysToTemplate($args->{-template_file});
         my @getChildTemplate = $self->execCmd("grep -i 'type.*yaml' $args->{-template_file}");
        if($getChildTemplate[0] =~ /yaml/){ #TOOLS-12934 Matches for yaml in result as grep might return empty string 
            $logger->debug(__PACKAGE__. ".$sub: Looks like this is NESTED template. ATS will add keys to child templates");
            my $getUser = `whoami`;
            chomp($getUser);
            foreach(@getChildTemplate){
                chomp($_);
                next if($_ =~ /.*#.*yaml/);
                if($_ =~ /type:\s*(.*yaml)/){
                   my $childTemplate= $1;
                   my @childTemplate = split('/',$childTemplate);
		   my $child_template = $scpArgs{-sourceFilePath};
		   $child_template =~ s/$1/$childTemplate[$#childTemplate]/ if($child_template =~ /([\w-]+\.yaml)/); 
                   ($ls_out) = $self->execCmd("ls -l $path/$childTemplate[$#childTemplate]");
                       if ($ls_out =~ /No such file or directory/){
                           $scpArgs{-sourceFilePath} = "$child_template"; #bats server
                           $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'.$path."/".$childTemplate[$#childTemplate]; #in VMCTRL

                           $logger->debug(__PACKAGE__ . ".$sub: secure copying child template file '$childTemplate[$#childTemplate]' to VM_CTRL");
                           unless(&SonusQA::Base::secureCopy(%scpArgs)){
                                 $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy child template file '$childTemplate[$#childTemplate]' to VM_CTRL");
                                 $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                                 return 0;
                         }
                    }
                   $logger->debug(__PACKAGE__. ".$sub: Looks like this is NESTED template. ATS will add keys to child templates");
                   $self->addKeysToTemplate("$path/$childTemplate[$#childTemplate]");
                }

            }
        }else{
             $self->addKeysToTemplate($args->{-template_file});
        }
    }

    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::VMCTRL::getParametersFromTemplate()

  This subroutine used to parse parameters from yaml template.
  It is a internal function.

=over

=item Arguments

  Mandatory Args
    - templatePath:  Path to N:1 yaml Template
    - isSubnetPresentRef: Reference to know if subnet parameters are present in Template 
				(will be used in resolveCloudInstance())
    - obj_type: Type of instance.

=item Returns

  1: When the parsing is successful
  0: When the parsing is not successful

=back

=cut

sub getParametersFromTemplate {
    my ($self, $templatePath, $isSubnetPresentRef, $obj_type, $type) = @_;
    my $sub = "getParametersFromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");
    %netHash = (
        'PSX' => {
            'MGMTNIF' => {
                1 => "ManagementNetworkId"
            },
            'SIGNIF' => {
                1 => "SignalingNetworkId"
            }
        },
        'EMS_SUT' => {
            'MGMTNIF' => {
                1 => "ManagementNetworkId"
            },
            'EXT_NIF' => {
                1 => "ExternalNetworkId"
            }
        },
	    'VNFM_SIMPLEX' => {
	        'INT_NIF' => {
	            1 => 'private_network'
            },
            'EXT_NIF' => {
		        1 => 'public_net'
	        },
	    },
        'VNFM_HA' => {
            'EXT_NIF' => {
                1 => 'public_net_v4'
            },
        },
	    'TOOLS' => {
            'MGMTNIF' => {
                1 => "ManagementNetworkId"
            }
	    }
    );
    $netHash{'PSX'}{'EXT_NIF'}{1} = "ExternalNetworkId" unless($type =~ /nodhcp/i);

# TOOLS - 71103, removing the PSX parametsrs from hash since parameters are read directly from template . 
    %noDhcpHash = (
        'IPADDRESS' => {
            'EMS_SUT' => {
                'MGT0' => {'ManagementFixedIP' => 1 },
                'LI' => {'ManagementFixedIPLI' => 1 }
            },
            'VNFM' => {
                'PRIVATE_MGT0' => {'private_network_ip' => 1},
            },
	        'TOOLS' => {
		        'MGT0' => {'ManagementIP' => 1 }
	        }
        },
        'GATEWAY' => {
            'EMS_SUT' => {
                'MGT0' => {'ManagementGateway' => 1},
                'LI' => {'ManagementGatewayLI' => 1}
            },
            'VNFM' => {
                'PRIVATE_MGT0' => {'private_network_gateway' => 1},

            },
	        'TOOLS' => {
		        'MGT0' => {'ManagementGateway' => 1},
	        }
        },
        'PREFIX' => {
            'EMS_SUT' => {
                'MGT0' => {'ManagementFixedIPPrefix' => 1},
                'LI' => {'ManagementFixedIPPrefixLI' => 1}
            }
        },
	    'NETMASK' => {
	        'TOOLS' => {
		        'MGT0' => {'ManagementNetmask' => 1},
	        }
	    },
        'CIDR' => {
            'VNFM' => {
                'PRIVATE_MGT0' => {'private_network_cidr' => 1},
            }
        }
    );

    #TOOLS-17907 - Added mgt1 for SBX5000
    my %networks = ( SBX5000 => ['mgt0', 'pkt0', 'pkt1', 'ha', 'mgt1'],
                     PSX => {management => 'mgt0', signaling => 'sig'},
                     VMCCS => ['mgmt','sig'],
                   );
    my %tmsMapping = (
         SBX5000 => {
        'mgt0' => {
                    'ext'       => ['EXT_NIF', 1],
                    'private'   => ['INT_NIF', 1],
                    'provider'  => ['INT_NIF', 1]
                },
#TOOLS-17907
        'mgt1' => {
                    'ext'       => ['EXT_NIF', 2],
                    'private'   => ['INT_NIF', 2],
                    'provider'  => ['INT_NIF', 2]
                },
        'pkt0' => {
                    'ext'       => ['EXT_SIG_NIF', 1],
                    'private'   => ['INT_SIG_NIF', 1],
                    'provider'  => ['INT_SIG_NIF', 1]
                },
        'pkt1' => {
                    'ext'       => ['EXT_SIG_NIF', 2],
                    'private'   => ['INT_SIG_NIF', 2],
                    'provider'  => ['INT_SIG_NIF', 2]
                },
        'ha0' => {
                    'private'   => ['INTER_CE_NIF', 1],
                    'provider'  => ['INTER_CE_NIF', 1]
                }
        },
        PSX => {
            'mgt0' => {
                     'management' => ['MGMTNIF',1],

                   },
            'sig' => {
                    'signaling' => ['SIGNIF',1],
                 },
        },
        VMCCS => {
            'mgmt' => {
                        'mgmt' => ['EXT_NIF', 1],
                     },
            'sig' => {
                        'sig'  => ['EXT_SIG_NIF',1],
                     },
        },
    );
   
    #TOOLS-18090 - Enhanced the code to work to parse the PSX template. 
    if ($obj_type =~ /(SBX|PSX|VMCCS)/) {
	    $logger->debug(__PACKAGE__. ".$sub: Parsing the template for parameters");
	    my @output = `sed -n '/^parameter/,/^parameter/p' $templatePath`;

    if (grep (/active|standby/i, @output )) { #TOOLS-71349
        $noDhcpHash{'HA'} = 1;
    }

	foreach my $param (@output){
	    chomp($param);
	    next unless($param =~ /^\s+-.*/);
	    $param =~ s/^\s+-\s*//;
        $param =~ s/\r//g;

        my $net = "";
        if( $obj_type =~ /PSX/ and ($net) = grep ( $param =~ /$_/i, keys %{$networks{$obj_type}} )){
            $net = $networks{$obj_type}{$net};
        } elsif($obj_type =~ /SBX|VMCCS/ and ($net) = grep ( $param =~ /$_/, @{$networks{$obj_type}} )) {
        }
	    $net = 'mgt0' if ($param =~ /logicalManagement/i);
	    $net .= '0' if (defined $net and $net =~ /ha/);

        if($net){
            if($param =~ /network/i){
                my $pos = "";
                chomp($param);
                foreach(keys %{$tmsMapping{$obj_type}{$net}}){
                    if($param =~ /$_/i ){
                        $pos = $_;
                        last;
                    }
                }
                $netHash{$obj_type}{$tmsMapping{$obj_type}{$net}{$pos}[0]}{$tmsMapping{$obj_type}{$net}{$pos}[1]} = $param;
            }

            elsif ($param =~ /(ipaddress|gateway|prefix|alt_ips|vips|AdditionalIps|additional_Fips|netmask|ip|cidr)/i) {
                my $key = $1;
                $key = 'ALT_IPS' if ($param =~ /alt_ips|vips|AdditionalIps|additional_Fips/i);
                $key = 'ipaddress' if ($key =~ /^ip$/i);
                $noDhcpHash{uc $key}{$obj_type}{uc $net}{$param} = 1;
            }
	    #TOOLS-19080 - For PSX we are not considering the Subnet info from Template.	    
            elsif( $obj_type !~ /PSX/ and $param =~ /subnet/i){ 
		$$isSubnetPresentRef = 1 ;
                $subnetHash{$obj_type}{uc $net} = $param;
            }
	    }
	}
	if($self->{TMS_ALIAS_DATA}->{NIF}->{1}->{NAME} and ( $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{PARAMETER} =~ /subnet_enum/i or $self->{TMS_ALIAS_DATA}->{SLAVE_CLOUD}->{1}->{PARAMETER} =~ /subnet_enum/i ) ){ #TOOLS-15000 - SRv4 PSX ## TOOLS-18778 Only Slave Cloud Spawning with Enum Interface Details
	    $subnetHash{PSX}{Enum} = 'subnet_enum';
	    $netHash{PSX}{NIF}{1} = 'EnumNetworkId';
	    $noDhcpHash{IPADDRESS}{PSX}{ENUM} = {'EnumIP' => 1};
        $noDhcpHash{GATEWAY}{PSX}{ENUM} = {'EnumGateway' => 1};
        $noDhcpHash{PREFIX}{PSX}{ENUM} = {'EnumPrefixLength' => 1};
	    }#End TOOLS-15000 - SRv4 PSX
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head2 B<frameParameterList>

    To Frame the parameter list from the data taken from TMS or user

=over

=item Arguments:

        -Object Reference
        -resolveAlias     =  TMS data of the instance
        -args             =  User given data

=item Returns:

        None

=item Example:

        unless($vmctrlObj->frameParameterList($resolveAlias,$args)){
            $logger->debug(__PACKAGE__. ".$sub: Failed to Frame the cmd");
            return 0;
        }

=back

=cut

sub frameParameterList{

    my ($self, $args) = @_;
    my $sub = "frameParameterList";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");
    #to get parameters from all the places
    my $attribute = ( $args->{-slave} )?('SLAVE_CLOUD'):('CLOUD_INPUT');
    my $index = ($args->{-gr}) ? '2' : '1';
    my $temp = "$args->{-parameter}";
    $temp .= ",$args->{-alias_hashref}->{$attribute}->{$index}->{PARAMETER}" if (exists $args->{-alias_hashref}->{$attribute}->{$index}->{PARAMETER});
    $temp .= ",$self->{TMS_ALIAS_DATA}->{$attribute}->{$index}->{PARAMETER}" if (exists $self->{TMS_ALIAS_DATA}->{$attribute}->{$index}->{PARAMETER});
    my $delimiter;
    if ($temp =~ /\|/) {
        #Using this demiliter for PSX and Configurator, because ',' is being used in the value.
        $args->{-parameter} .= "|$args->{-alias_hashref}->{$attribute}->{$index}->{PARAMETER} " if (exists $args->{-alias_hashref}->{$attribute}->{$index}->{PARAMETER});
        $args->{-parameter} .= "|$self->{TMS_ALIAS_DATA}->{$attribute}->{$index}->{PARAMETER} " if (exists $self->{TMS_ALIAS_DATA}->{$attribute}->{$index}->{PARAMETER});
        $delimiter = '\|';
    }
    else {
        $args->{-parameter} = $temp;
        $delimiter = ',';
    }
    $args->{-parameter} =~ s/^$delimiter+//;
    my @arr1 = split(/$delimiter/, $args->{-parameter});

    $args->{-parameter1} = $args->{-parameter} = '';
    #args{-parameter} will be used to fetch the subnet details and ips for no_dhcp and args{-parameter1} will be used in the heat stack create command
    foreach (@arr1) {
        my ($key, $value) = split(/=/);
        #TOOLS-11184, checking if alternate ips are required
        if ($key =~ /alt_ips_(.+)_count/i) {
            $self->{alt_ips}->{uc $1} = $value;
            next;
        }

        if ($key =~ /(.+)_ips_count/i) {
            $self->{ips_count}->{uc $1} = $value;
            next;
        }
        next if ($args->{-parameter} =~ /,?$key=/); #will not add any duplicate entries
        $args->{-parameter} .= "$_,";
        s/;.+// if (/;/); #for dual stack, need only 1 subnet
        s/\[\S+?-\S+?\]//; #TOOLS-77395 - to strip out IP range
        next if( $args->{-isSubnetPresent} == 0  and $_ =~ /subnet/);
        $args->{-parameter1} .= " -P $_";
    }

    $args->{-parameter1} =~ s/"/\\"/g if($args->{-obj_type} !~ /PSX|EMS/i);  #if quotes are in the value, then escaping it so create cmd doesn't remove quotes.
    $args->{-parameter} =~ s/,$//;

    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [1]");
    return %$args;

}


=pod

=head2 B<cinderDelete>

    To delete a particular Cinder Volume or whichever is free if no volume specified

=over

=item Arguments:

	-id (optional hash): Cinder Volume ID

=item Returns:

        1 - Success
	0 - Failure

=item Example:

	$self->cinderDelete;
        $self->cinderDeletei(-id => \@volumes);
	
=back

=cut

sub cinderDelete {
	my $sub = 'cinderDelete';
	my ( $self,%id ) = @_;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");
	@{$self->{CMDRESULTS}} = (); # To clear the previous results ( if the session is killed before cinderDelete is called, then some times CMDRESULTS will contain the previous results which will be looped in foreach. So to avoid this, CMDRESULTS are cleared )
	my $cmd;
	if($id{-name}){
            unless ($id{-id} = $self->cinderDetach(-name => $id{-name})) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to detach cinder volume $id{-id}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }		
	}
        unless($id{-id}) { #TOOLS-15656 #TOOLS-18789
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub : Missing mandatory parameter instance name.");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
            return 0;
        }
        $cmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack volume " : "cinder "; #TOOLS-15656
	foreach my $volume ( @{$id{-id}} ) {
		next unless ( $volume =~ /\s+/ ); # To skip the output containing empty results
		$cmd .= 'delete '.$volume;
		$self->execCmd($cmd);
	}
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[1] ");
	return 1;
} ## --- end sub cinderDelete

=pod

=head2 B<cinderCreate>

	To create a new Cinder Volume 

=over

=item Arguments:

	-name : name of cinder volume
	-size : size of cinder volume 

=item Returns:

        cinderID - SUCCESS
        0 - FAIL

=item Example:

        $self->cinderCreate(-name => "EMS" , -size => 90);

=back

=cut

sub cinderCreate {
        my $sub = 'cinderCreate';
        my ( $self, %args ) = @_;

        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");
	
	unless($args{-name}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory argument name not specified.");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
            return 0;
        }   
        
        unless($args{-size}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory argument size not specified.");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
            return 0;
        }

        my $cmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack volume create --size $args{-size} $args{-name}" : "cinder create --name $args{-name} $args{-size}";
        $cmd .= " | grep -w id";
	my @cmdResult = $self->execCmd($cmd);
	my $cinderID = (split('\|',$cmdResult[0]))[-2];
	my $active=0;
	my $wait=60;
	$cmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack volume show " : "cinder show ";
        while (!$active && $wait) {
            unless (@cmdResult = $self->execCmd( "$cmd $cinderID | grep -w status" )) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to get result for volume show command");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            if (grep /status[\s\|]+\s(creating).*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: Volume is still in \'creating\' state, waiting 2sec for volume creation to complete ");
                sleep 2;
                $wait -= 2;
            }
            elsif (grep /status[\s\|]+\s(available).*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: Volume is in available state.");
                $active = 1;
            }
            else {
                $logger->debug(__PACKAGE__. ".$sub: command result didn't match (creating)/(available) state.".Dumper(\@cmdResult));
                last;
            }
        }

        unless ($active) {
            $logger->error(__PACKAGE__. ".$sub: Volume didn't come to \'available\' state, after waiting for 60sec");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[$cinderID] ");
        return $cinderID;
} ## --- end sub cinderCreate

=pod

=head2 B<cinderDetach>

        To detach Cinder Volume associated with instance

=over

=item Arguments:

        -name : Name of instance

=item Returns:

        id - SUCCESS
        0  - FAIL

=item Example:

        $self->cinderDetach(-name => "jenkins_automation_instance", -id => "11540f89-bae0-4b6f-a15e-96e67cadb41f");

=back

=cut

sub cinderDetach {
        my $sub = 'cinderDetach';
        my ( $self, %args ) = @_;

        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");

        unless($args{-name}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory argument name of instance not specified.");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[0]");
            return 0;
        }

	my @cmdResult;
	my $cinderCmd = ($self->{openstack_version} ge $versions{openstack}) ? 'openstack volume list' : 'cinder list';
        $cinderCmd .= ' | grep -w '.$args{-name};
        unless (@cmdResult = $self->execCmd($cinderCmd)) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to get result for $cinderCmd command");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        $args{-id} = (split('\|',$cmdResult[0]))[1];        
        $logger->debug(__PACKAGE__.".$sub: Detaching cinder volume $args{-id} attached to $args{-name}");
        my $cmd = ($self->{openstack_version} ge $versions{openstack}) ? 'openstack server remove volume' : 'nova volume-detach'; 
        $cmd .= " $args{-name} $args{-id}"; 
	unless ($self->execCmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to detach cinder volume $args{-id}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
        }

        my $active=0;
        my $wait=60;

        $cmd = ($self->{openstack_version} ge $versions{openstack}) ? "openstack volume show " : "cinder show ";
        while (!$active && $wait) {
            unless (@cmdResult = $self->execCmd( "$cmd $args{-id} | grep -w status" )) {
                $logger->error(__PACKAGE__ . ".$sub: Failed to get result for volume show command");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            if (grep /status[\s\|]+\s(detaching).*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: Volume is still in \'detaching\' state, waiting 2sec for volume detach to complete ");
                sleep 2;
                $wait -= 2;
            }
            elsif (grep /status[\s\|]+\s(available).*/i,@cmdResult){
                $logger->debug(__PACKAGE__. ".$sub: Volume is in \'available\' state.");
                $active = 1;
            }
            else {
                $logger->debug(__PACKAGE__. ".$sub: command result didn't match (detaching)/(available) state.".Dumper(\@cmdResult));
                last;
            }
        }

        unless ($active) {
            $logger->error(__PACKAGE__. ".$sub: Volume didn't come to \'available\' state, after waiting for 60sec");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[$args{-id}]");
        return [$args{-id}];
} ## --- end sub cinderDetach

=pod

=head2 B<checkInstanceStatus>

    To check the instance status if its services are in running state or not 

=over

=item Arguments:

	Mandatory Args
	- obj_type: Type of instance.

=item Returns:

        1 if instance came up successfully, 0 if instance didn't come up & -1 if it exceeded the time limit to check the status

=item Example:

	$self->checkInstanceStatus($args{-obj_type});

=back

=cut
sub checkInstanceStatus {
	my $sub = 'checkInstanceStatus';
	my ( $self, $obj_type ) = @_;
    my ($checkStatusResult, $checkStatusCmdResult);
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");

        if ( ($obj_type =~ /^(SBX5000|PSX|EMS_SUT)$/) and ($self->{CE_CREATED} or not $self->{CE_EXIST}) ) { #TOOLS-15912
	# Sleeping for 240s for SBX5000 Obj Type due to issue SBX-62051 only if ATS is creating Stack and proceed if Stack already exist
	     $logger->debug(__PACKAGE__. ".$sub: Sleeping for 4 mins for $obj_type ");
             sleep (240);
	}

	unless($self->pingCloudInstance($checkStatusHash{$obj_type}->{-ip})) {
		$logger->error(__PACKAGE__ . ".$sub: Cloud Instance [$checkStatusHash{$obj_type}->{-ip}] is not reachable");
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
		return 0;
	}

    # TOOLS-77394
    if($self->{SKIP_CHECK_INSTANCE}){
        $logger->debug(__PACKAGE__. ".$sub: Skipping instance check. ");
   		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[1] ");
        return 1;
    }

    if($obj_type =~ /^(SBX5000)/){
        my $root_obj;
        $checkStatusResult = 1;
        $checkStatusResult = 0 unless ($root_obj = SonusQA::SBX5000::SBX5000HELPER::makeRootSession(-obj_host => $checkStatusHash{$obj_type}->{-ip}, -obj_key_file => $checkStatusHash{$obj_type}->{-identity_file}));
        $checkStatusResult = 0 unless(SonusQA::SBX5000::SBX5000HELPER::checkProcessStatus($root_obj,-timeInterval => 30, -noOfRetries => 60));
     } elsif ($obj_type =~ /^(EMS_SUT)/) {
        my $ems_obj;
        $checkStatusResult = 1;
        if($ems_obj = SonusQA::EMS->new(
                                        -obj_host => $checkStatusHash{$obj_type}->{-ip}, 
                                        -obj_user => 'admin', 
                                        -obj_password => 'admin', 
                                        -comm_type => 'SSH',
                                        -obj_port       => 22,
                                        -sessionlog => 1,
                                        -DO_NOT_TOUCH_SSHD => 1,
                                     )){
            $checkStatusResult = $ems_obj->status_ems(-noOfRetries => 40);
            $ems_obj->DESTROY();
        }
        else{
            $checkStatusResult = 0;
            $logger->debug(__PACKAGE__."$sub: Unable to create EMS Object.");
        }
    } else {
        ($checkStatusResult, $checkStatusCmdResult) = SonusQA::ATSHELPER::checkStatus( $checkStatusHash{$obj_type} );

        if ( $checkStatusResult == 1 ) {
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Success!.".Dumper($checkStatusCmdResult));
        } elsif ( $checkStatusResult == 0 ) {
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Failure!.".Dumper($checkStatusCmdResult));
        } elsif ( $checkStatusResult == -1 ) {
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Not Found.Ran out of time!.".Dumper($checkStatusCmdResult));
            $checkStatusResult = 0;
        } else {
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Not Sure What Happened! Check the arguments provided!");
            $checkStatusResult = 0;
        }

    }
    $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[$checkStatusResult] ");
    return $checkStatusResult;
} ## --- end sub checkInstanceStatus


=head2 SonusQA::VMCTRL::fetchIpsHeat()

=over

=item DESCRIPTION:

  This subroutine will get the ips of the created instance using the openstack or heat stack- show comamnd.
  Created as part of TOOLS-17452 Enhancement.

=over

=item Arguments

  Mandatory Args
      - arg:          Hash of the network named and the instance name

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns

  values - Array refernce of the hash containing the ips.

=back

=cut

sub fetchIpsHeat {
    my ($self, %args) = @_;
    my $sub = "fetchIpsHeat";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__.'->'.__LINE__. "::$sub: --> Entered Sub");
 
    my (@result, @values, $index,$new_cmd,);
    my @instances = @{$args{instance}};
    delete $args{instance};
    delete $args{type};
    if($self->{openstack_version} ge $versions{openstack}){                            #TOOLS-19326
        $new_cmd = "openstack stack show";
       $index = 1;
    }
    else{
       $new_cmd = "heat stack-show";
       $index = -1;
    }

    my $i = 0;
    foreach (@instances){
        unless (@result = $self->execCmd("$new_cmd $_")) {
                $logger->error(__PACKAGE__ . ".$sub:  unable to execute  $new_cmd $_ command");
                @values = ();
                last;
        }
        foreach my $pos (0..$#result){            
	    last unless(keys %args); 
                if($result[$pos] =~ /\"?output_key\"?\: \"?([\w\_\d\-]+):?\"?/){
                my $net = $1;
                if($args{$net}){
                   $pos += $index;
                   $values[$i]{$args{$net}->[0]}{$args{$net}->[1]}{$args{$net}->[2]} = $1 if($result[$pos] =~ /\"?output_value\"?\: \"?(\S+)\"?/) ;
                   delete $args{$net};
               }
           }
        }
        $i++;
    }
    unless(scalar @values){
        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub: <-- Leaving Sub[0] ");
        return 0;	
    }
    $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub: The ips for the instance are ".Dumper(\@values));
    $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub: <-- Leaving Sub[1] ");
    return @values;	
}
1;
