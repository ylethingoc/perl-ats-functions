package SonusQA::IAC;

use strict;
use warnings;
use SonusQA::Base ;
use SonusQA::SBX5000::SBX5000HELPER ;
use Data::Dumper;
use JSON qw( decode_json ) ;
use YAML::Tiny;
use Log::Log4perl;
our @ISA = qw(SonusQA::Base ) ;
use SonusQA::Utils;

sub doInitialization {
    my ( $self, %args ) = @_;
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES}          = ["SSH"];
    $self->{TYPE}               = __PACKAGE__;
    $logger->debug(__PACKAGE__ . ".doInitialization : Leaving Sub [1]" );
    return 1;
}

=head2  setSystem

=over

=item DESCRIPTION:

    This function sets the AUTOMATION prompt.

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   Base::setPrompt()

=item OUTPUT:

   1 - success
   0 - failure 

=item EXAMPLE:
   
   $self->setSystem;

=back

=cut

sub setSystem {
    my ($self) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ($self->setPrompt) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to set AUTOMATION prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 resolveCloudInstance

=over

=item DESCRIPTION:

    This function is used to spawn the IAC instance and populate the MGMTNIF and other PKT IPs..

=item ARGUMENTS:

    Mandatory: 

     None
    
    Optional: 

     -alias_hashref => resolved TMS alias data

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   IAC::spawnInstance()

=item OUTPUT:
  
   returns the hash reference with MGMTNIF, PKT_NIF, SIGNIF and SIG_SIP IPs.

=item EXAMPLE:

   $self->resolveCloudInstance(-alias_hashref=> $alias_hashref);

=back

=cut


sub resolveCloudInstance {
    my ($self, %args) = @_ ;
    my $sub_name = 'resolveCloudInstance';
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".resolveCloudInstance");
    $logger->debug(__PACKAGE__ . ".$sub_name : Enetered sub" );

    my $resolveAlias = ($args{-alias_hashref}) ? $args{-alias_hashref} : {} ;
    my $resolveAliasFemale = $args{-alias_hashref_female} if ($args{-alias_hashref_female});
    $self->{MGMTNIF_IP} = $resolveAlias->{MGMTNIF}->{1}->{IP} ;
   
    if ( $resolveAlias->{VM_HOST} ) {
        $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{IMAGE} = $resolveAlias->{CLOUD_INPUT}->{1}->{IMAGE} ;
   
        my $vmhost_obj ;
        unless ( $vmhost_obj = SonusQA::Base->new(-obj_host => $resolveAlias->{VM_HOST}->{1}->{IP},
                                                  -obj_user => $resolveAlias->{VM_HOST}->{1}->{USERID},
                                                  -comm_type => "SSH",
                                                  -obj_password => $resolveAlias->{VM_HOST}->{1}->{PASSWD}
                                                 )) {
            $logger->error(__PACKAGE__ . ".$sub_name : Failed to Create the VM_HOST object" );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        }
    
        $logger->info(__PACKAGE__ . ".$sub_name : Executing command 'esxcli vm process list' to get the process list" );
        my @prcess_list = $vmhost_obj->{conn}->cmd('esxcli vm process list') ;
        my $instance_found = 0 ;
        my $world_id ;
        my $instance_name = uc $resolveAlias->{name} ;
        foreach my $line (@prcess_list) {
            unless ( $instance_found ) {
                $instance_found = 1 if ($line =~ /$instance_name/)  ;
            }elsif( $line =~ /World ID:\s+(\d+)/)  {
                $world_id = $1 ;
                last ;
            }
        }
        unless ( $instance_found ) {
            $logger->info(__PACKAGE__ . ".$sub_name : Instance not found in the list." );
        }else {
            $logger->info(__PACKAGE__ . ".$sub_name : Killing the instance $instance_name\'s process with World ID $world_id" );
            unless ($vmhost_obj->{conn}->cmd("esxcli vm process kill --type=soft --world-id=$world_id") ) {
                $logger->error(__PACKAGE__ . ".$sub_name : Unable to kill the process." );
                $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name : Waiting for 2s for the killed process to complete." );
            sleep(2) ;
            $logger->info(__PACKAGE__ . ".$sub_name : Executing command 'vim-cmd vmsvc/getallvms' to get the instances list" );
            my @instances_list = $vmhost_obj->{conn}->cmd('vim-cmd vmsvc/getallvms') ;
            my $instance_vmid ;
            foreach(@instances_list) {
                if ($_ =~ /(\d+)\s+$instance_name\s+/) {
                    $instance_vmid = $1;
                    last ;
                }
            }
            $logger->info(__PACKAGE__ . ".$sub_name : Killing the instance $instance_name with vmid $instance_vmid" );
            unless ($vmhost_obj->{conn}->cmd("vim-cmd vmsvc/destroy $instance_vmid")) {
                $logger->error(__PACKAGE__ . ".$sub_name : Unable to delete the instance." );
                $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
                return 0;
            }
        }
        $vmhost_obj->DESTROY ;
    }
    
    my $ips_ref = $self->spawnInstance( -resolveAlias => $resolveAlias) ;
    unless ( $ips_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name : Failed to spawn the instance" );
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }

     unless ( $resolveAlias->{VM_HOST} ) { 
        if ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH} =~ /aws/) {
            if ($ips_ref->{'active_mgt_eip_list'}) {
                $resolveAlias->{MGMTNIF}->{1}->{IP} = $ips_ref->{'active_mgt_eip_list'} ;
                $_ = $ips_ref->{'active_pkt0_eip_list'} for ($resolveAlias->{PKT_NIF}->{1}->{IP}, $resolveAlias->{SIGNIF}->{1}->{IP}, $resolveAlias->{SIG_SIP}->{1}->{IP});
                $_ = $ips_ref->{'active_pkt1_eip_list'} for ($resolveAlias->{PKT_NIF}->{2}->{IP}, $resolveAlias->{SIGNIF}->{2}->{IP}, $resolveAlias->{SIG_SIP}->{2}->{IP});
            }else {
                $resolveAlias->{MGMTNIF}->{1}->{IP} = $ips_ref->{'active_eip_list'} ;
                $resolveAliasFemale->{MGMTNIF}->{1}->{IP} = $ips_ref->{'standby_eip_list'} ;
            }
        }elsif ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH} =~ /gcp/) {
            if ($ips_ref->{'sbc_stand_alone_mgt0_public_ip'}) {
                $resolveAlias->{MGMTNIF}->{1}->{IP} = $ips_ref->{'sbc_stand_alone_mgt0_public_ip'} ;
            }else {
                $resolveAlias->{MGMTNIF}->{1}->{IP} = $ips_ref->{'sbc_active_mgt0_public_ip'} ;
                $resolveAliasFemale->{MGMTNIF}->{1}->{IP} = $ips_ref->{'sbc_standby_mgt0_public_ip'} ;
            }
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name : Waiting for 5 mins for the instance to come up" );
    sleep(300);
    my $root_obj;
    $logger->info(__PACKAGE__ . ".$sub_name : Checking the instance status." );
    unless ($root_obj = SonusQA::SBX5000::SBX5000HELPER::makeRootSession(-obj_host => $resolveAlias->{MGMTNIF}->{1}->{IP}, -obj_key_file => $resolveAlias->{LOGIN}->{1}->{KEY_FILE} )) {
        $logger->error(__PACKAGE__ . ".$sub_name : Failed to create the root object for the spawned instance" );
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }
    unless(SonusQA::SBX5000::SBX5000HELPER::checkProcessStatus($root_obj,-timeInterval => 30, -noOfRetries => 60)) {
        $logger->error(__PACKAGE__ . ".$sub_name : SBC instance failed to come up." );
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[1]" );
    return (($resolveAliasFemale) ? ($resolveAlias, $resolveAliasFemale) : $resolveAlias); 
}

=head2 spawnInstance

=over

=item DESCRIPTION:

    This function is used to spawn the IAC instance and collect the MAGNIF and other PKT IPs..

=item ARGUMENTS:

    Mandatory:

     None

    Optional:

     -args hash => terraform fields to be replaced can be given in key-value format

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   IAC::update_tfvars()

=item OUTPUT:

   returns the hash reference with MGMTNIF and PKT_NIF IPs.

=item EXAMPLE:

   $self->spawnInstance('filed'=> 'value');

=back

=cut

sub spawnInstance {
    my ($self, %args) = @_ ;
    my $sub_name = 'spawnInstance';
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".spawnInstance");
    $logger->debug(__PACKAGE__ . ".$sub_name : Enetered sub" );
    my $resolveAlias = $args{-resolveAlias} ;
    delete $args{-resolveAlias} ;

    my ( $ova_file_name, $template_file) ;   
    unless ($resolveAlias->{VM_HOST}) {  # VM_HOST attribute should be present for VMware IAC
        unless ( $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE}) {
            $logger->error(__PACKAGE__ . ".$sub_name : Mandatory iac tar file is not passed in tms_alias." );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        }
        unless ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH}) {
            $logger->error(__PACKAGE__ . ".$sub_name : Mandatory terraform directory is not passed in tms_alias." );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        }
        unless ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{ENV_FILE}) {
            $logger->error(__PACKAGE__ . ".$sub_name : Mandatory terraform.tfvars file is not passed in tms_alias." );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
           return 0;
        }
        $template_file = $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE} ;
    }else {
        unless ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{IMAGE}) {
            $logger->error(__PACKAGE__ . ".$sub_name : Mandatory ova file is not passed in tms_alias." );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        }
        if ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{IMAGE} =~ /.+\/(sbc.+)\.ova/) {
            $ova_file_name = $1 ;
        }
#Downloaded tar file /ats/utils/iac-1.1-20200330-094006.tar.gz from https://artifact1.eng.sonusnet.com:8443/artifactory/IaC-generic-prod-westford/development/lastSuccessfulBuild/iac-1.1-20200330-094006.tar.gz
        $template_file = $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE} || '/ats/utils/iac-1.1-20200330-094006.tar.gz' ;
    }
    my $tarfile ;
    if ($template_file =~ /.+\/(iac.+[\.\-]tar([\.\-]gz)?)/) {
        $tarfile = $1 ;
    }else {
        $logger->error(__PACKAGE__ . ".$sub_name : tar file $template_file is not ended with the expected extention." );
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }

    if ($resolveAlias->{VM_HOST}) {
        $self->{conn}->cmd('virtualenv ~/iacenv') ;
        $self->{conn}->cmd('source ~/iacenv/bin/activate') ;
        $self->{conn}->cmd('pip install --force pyvmomi') ;
    }else {
        $self->{conn}->cmd('source ~/iacenv/bin/activate') ;
    }

    my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
    my $new_dir = "terraform-$timestamp" ;

    $self->{conn}->cmd("mkdir ~/$new_dir") ;
    $self->{conn}->cmd("cp  $template_file ~/$new_dir/") ;
    if ($tarfile =~ /(.+)[\.\-]gz/) {
        $logger->debug(__PACKAGE__ . ".$sub_name : Untarring the tar file $tarfile" );
        $self->{conn}->cmd("tar xvzf ~/$new_dir/$tarfile -C ~/$new_dir/") ;
    }else {
        $self->{conn}->cmd("tar -C ~/$new_dir/  -xvf ~/$new_dir/$tarfile") ;
    }

    my $iac_path ;
    unless($resolveAlias->{VM_HOST}) {
        $iac_path = "~/$new_dir/$self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH}" ;
        $logger->info(__PACKAGE__ . ".$sub_name : Doing source key.sh operation." );
        unless ( $self->execShellCmd('source ~/key.sh')) {
            $logger->error(__PACKAGE__ . ".$sub_name : Failed to source the key file" );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        }
    }else {
        $iac_path = "$ENV{ HOME }/$new_dir/iac/orchestration/vmware/esxi_deployment/sbc" ;
        $self->{VMDK_PATH} = "$iac_path/$ova_file_name\.vmdk" ;
        $logger->debug(__PACKAGE__ . ".$sub_name : Untarring the ova file $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{IMAGE}" );
        $self->{conn}->cmd("tar -xvf $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{IMAGE} -C $iac_path/.") ;
    }
        
    $self->{conn}->cmd("cd $iac_path") ;
    $self->{conn}->cmd("cp $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{ENV_FILE} .") ;

    if ($resolveAlias->{VM_HOST}) {
        my @env_cmds = ("export VSPHERE_USER=$resolveAlias->{VM_HOST}->{1}->{USERID}", "export VSPHERE_PASSWORD=$resolveAlias->{VM_HOST}->{1}->{PASSWD}", "export VSPHERE_SERVER=$resolveAlias->{VM_HOST}->{1}->{IP}", 'export VSPHERE_ALLOW_UNVERIFIED_SSL=True');
        my $flag = 1;
        foreach my $cmd (@env_cmds) {
            unless ($self->{conn}->cmd($cmd) ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to run command $cmd");
                $flag = 0;
                last;
            } 
        }
        unless ($flag) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }        
    }
    $self->{conn}->cmd("cd $iac_path") ;
    $self->{conn}->cmd("cp $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{ENV_FILE} .") ;
    
    if (keys %args) {
        $args{'path'} = "$iac_path/terraform.tfvars" ;
        unless ($self->update_tfvars(%args ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name : Failed to update the tfvars file." );
            $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
            return 0;
        } 
    }

    my ($flag, $tipc_id ) = (1, 0) ;
    my $key ;

    foreach my $char (split('', reverse $resolveAlias->{MGMTNIF}->{1}->{IP})) {
        unless ($char =~ /\./  ) {
            $tipc_id = $tipc_id *10 + $char ;
        }
        last if (length($tipc_id) == 4) ;
    }
    $tipc_id = reverse $tipc_id ;
    
    foreach $key ('init', 'plan', 'apply') {
        $logger->info(__PACKAGE__ . ".$sub_name : Doing \'terraform $key\' operation" );
        my $cmd ;
        if ( $resolveAlias->{VM_HOST} and $key eq 'apply' ) {
            $cmd = "terraform $key -var \'vmdk_file_path = \"$self->{VMDK_PATH}\"\' -var \'ha_mode = \"1to1\"\' -var \'ce_role_list = [ \"active\"]\' -var \'ce_name_list = [ \"".(uc $resolveAlias->{name})."\"]\' -var \'system_name = \"$resolveAlias->{NODE}->{1}->{HOSTNAME}\"\'  -var \'peer_ce_name_list = [ \"none\"]\'  -var \'mgt0_ipv4_address_list = [ \"$resolveAlias->{MGMTNIF}->{1}->{IP}\" ]\' -var \'mgt0_ipv4_gateway = \"$resolveAlias->{MGMTNIF}->{1}->{DEFAULT_GATEWAY}\"\' -var \'tipc_id = $tipc_id\'  -var \'vm_count = \"1\"\' -var \'ha0_ipv4_address_list = [ \"$resolveAlias->{CE}->{1}->{IP}\"]\' -var \'rg_ip_list = [ \"$resolveAlias->{CE0}->{1}->{IP}\"]\' -var \'vm_numa_node_affinity_list = [ \"0\"]\' -var \'pci_device_list = [ [\"\", \"\"] ]\' -var \'create_network = \"false\"\' -var \'select_network_port_group_names = [  [\"$resolveAlias->{MGMTNIF}->{1}->{NAME}\",\"$resolveAlias->{CE0}->{1}->{NAME}\",\"$resolveAlias->{PKT_NIF}->{1}->{NAME}\",\"$resolveAlias->{PKT_NIF}->{2}->{NAME}\"], ]\' -var \'linuxadmin_ssh_key = \"ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==\"\' -var \'admin_ssh_key = \"ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA4oGIi+0mRS9Q25ln5/gKe1mmR7cfVuFxRQONVbjq8y+JB0g2T49b1Bf8xRhyhkKgdbIbEWdcmboSpTegt6zM0rz6Yw/73c3NVy60CX47t55GCCFYXxt3uwgRlN/9KX1mETCYOSD5AZ7e9YXvbd6/hUKkK/o8Zrhch9ckR2nVSe0v1wob4MMhmC1e9LV5tvk6zAIdmTWOYcrg0Yd6yHRQbNjlVFpQ147TPGy12+tDytqEW+09DQZqvhuiwSyxk3lBlNJYfCT2VidsS2+MQYD+t2REc65vcq/EvXuyuwpvv/IIjX2BBMCG7fMXkGh0wnIPoHbUCNfq1Zr2JGqZ6D8GIQ==\"\' " ;
$logger->info(__PACKAGE__ . ".$sub_name : terraform apply command : \n $cmd" );
        }else {
            $cmd = "terraform $key" ;
        }            
        unless ($self->execShellCmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub_name : Failed doing \'terraform $key\' operation" );
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        my $destroy_status = 1;
        if ($key eq "apply"){
            $logger->info(__PACKAGE__ . ".$sub_name : Since terraform apply failed, doing terraform destroy." );
            $self->execCmd("terraform destroy");
        }
        $self->{conn}->cmd("deactivate") ;
        $self->{conn}->cmd("rm -rf ~/iacenv") if ($self->{TMS_ALIAS_DATA}->{VM_HOST}) ;
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }
    my @cmd_results = $self->{conn}->cmd("terraform output") ;
$logger->debug(__PACKAGE__ . ".$sub_name : terraform output results".Dumper(\@cmd_results) );
    my %ips_list ;

    my $active_ip_key ;
    if ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH} =~ /aws/) {
        for (my $i=0; $i<=$#cmd_results; $i++) {
            if ($cmd_results[$i] =~ /(active_mgt_eip_list|active_pkt0_eip_list|active_pkt1_eip_list|active_eip_list|standby_eip_list)/) {
                my $ip_type = $1 ;
                $ips_list{$ip_type} =  ($cmd_results[$i+1] =~ /\s*(\d+\.\d+\.\d+\.\d+)/) ? $1 : '' ;
            }
        }
        $active_ip_key =  ($ips_list{'active_mgt_eip_list'})? 'active_mgt_eip_list' : 'active_eip_list' ;
    } elsif ($self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{BASEPATH} =~ /gcp/) {
        for (my $i=0; $i<=$#cmd_results; $i++) {
            if ($cmd_results[$i] =~ /(sbc_stand_alone_mgt0_public_ip|sbc_active_mgt0_public_ip|sbc_standby_mgt0_public_ip)/) {
                my $ip_type = $1 ;
                $ips_list{$ip_type} =  ($cmd_results[$i] =~ /.+\=\s*(\d+\.\d+\.\d+\.\d+)/) ? $1 : '' ;
            }       
        }
        $active_ip_key =  ($ips_list{'sbc_stand_alone_mgt0_public_ip'})? 'sbc_stand_alone_mgt0_public_ip' : 'sbc_active_mgt0_public_ip' ;
    }else {
        $active_ip_key = 'mgt0_public_ip' ;
        $ips_list{$active_ip_key} = $self->{MGMTNIF_IP};
    }
    $self->{'MGMTIP_PATH'}->{$ips_list{$active_ip_key}} = $iac_path ;

$logger->debug(__PACKAGE__ . ".$sub_name : Spawn output".Dumper(\%ips_list) ); 
    $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[1]" );
    return \%ips_list ;
}

=head2 execCmd

=over

=item DESCRIPTION:

    This function executes the command.

=item ARGUMENTS:

   1. Command to be executed.

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

   1 - success
   0 - failure

=item EXAMPLE:

   $self->execCmd('terraform init');

=back

=cut

sub execCmd {
    my ($self, $cmd , $timeout) = @_;
    my $sub_name = "execCmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if (!(defined $timeout)) {
        $timeout = $self->{DEFAULTTIMEOUT};
        $logger->debug(__PACKAGE__ . ".$sub_name Timeout not specified. Using $timeout seconds ");
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name Timeout specified as $timeout seconds ");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: --> ISSUING CMD:$cmd");
    $self->{conn}->print($cmd) ;
    my ($prematch, $match) ;
    unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter a value\:/i', -match => $self->{conn}->prompt, -timeout => $timeout ) ){
        $logger->error(__PACKAGE__ . ".$sub_name : Did not get the expected prompt " );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my (@cmd_results, @cmd_results1) ;
    @cmd_results = split("\n", $prematch) ;
    shift @cmd_results ;
    if ($match =~ /Enter a value/i){
        $self->{conn}->print('yes') ;
        unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{conn}->prompt, -timeout => 300 )){
            $logger->error(__PACKAGE__ . ".$sub_name : $cmd is taking more than 200secs" );
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        @cmd_results1 = split("\n", $prematch) ;
        shift @cmd_results1 ;
        push(@cmd_results, @cmd_results1);
    }
    chomp(@cmd_results);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return @cmd_results;
}

=head2  updateTfvars

=over

=item DESCRIPTION:

    This function is used to update the terraform.tfvars file with user passed field-values.

=item ARGUMENTS:

    -args hash => terraform fields to be replaced can be given in key-value format. 

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None 

=item OUTPUT:

    1 - success
    0 - failure

=item EXAMPLE:

    $self->updateTfvars('field'=>'value');

=back

=cut

sub updateTfvars {
    my ($self, %args) = @_ ;
    my $sub_name = 'updateTfvars';
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".update_tfvars");
    $logger->debug(__PACKAGE__ . ".$sub_name : Enetered sub" );

    my @terraform_cat = $self->{conn}->cmd('cat terraform.tfvars') ;
    pop @terraform_cat ;
    my $temp_file = $ENV{ HOME }."/temp.tfvars" ;
    unless( open(DATA, ">", $temp_file)) {
        $logger->error(__PACKAGE__ . "couldn't open the file $temp_file.") ;
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }

    foreach(@terraform_cat) {
        if( /(\S+)(\s*)\=\s*\S+/) {
            my $attribute = $1 ;
            if ($args{$attribute}) {
                print DATA "$attribute$2\= \"$args{$attribute}\"\n" ;
                next;
            }
        }
        print DATA $_ ;
    }
    close DATA;

    my %scp_args;
    $scp_args{-hostip} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{IP};
    $scp_args{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scp_args{-timeout} = '30';
    $scp_args{-identity_file} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE};
    $scp_args{-sourceFilePath} = $temp_file ;
    $scp_args{-destinationFilePath} = $scp_args{-hostip}.':'.$args{'path'};

    unless(&SonusQA::Base::secureCopy(%scp_args) ) {
        $logger->error(__PACKAGE__ . "Failed to do secure copy") ;
        system("rm $temp_file") ;
        $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[0]" );
        return 0;
    }
    system("rm $temp_file") ;
    $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[1]" );
    return 1;
}

=head2 deleteInstance

=over

=item DESCRIPTION:

    This function is used to destroy the single/multiple IAC instances.

=item ARGUMENTS:

    Mandatory:

     'mgmtip_list' => list of the IAC instance's IPs to be destroyed.

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

   1 - Success
   0 - Failure

=item EXAMPLE:

   $self->deleteInstance(-mgmtip_list=>[$mgmtip1, $mgmtip2]);

=back

=cut

sub deleteInstance {
    my ($self, %args) = @_ ;
    my $sub_name = 'deleteInstance';
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteInstance");
    $logger->debug(__PACKAGE__ . ".$sub_name : Enetered sub" );

    my @mgmt_ips = @{$args{-mgmtip_list}} ;
    my $destroy_status = 1; 
    foreach( @mgmt_ips ) {
        my $mgmt_ip = $_ ;
        $logger->info(__PACKAGE__ . ".$sub_name : Deleting the instance $mgmt_ip" );
        my $instance_path = $self->{'MGMTIP_PATH'}->{$mgmt_ip} ;
        $self->{conn}->cmd("cd $instance_path") ;

        $destroy_status = 0 unless ( $self->execShellCmd('terraform destroy'));
    }
    $self->{conn}->cmd("deactivate") ;
    $self->{conn}->cmd("rm -rf ~/iacenv") if ($self->{TMS_ALIAS_DATA}->{VM_HOST}) ;
    $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[$destroy_status]" );
    return $destroy_status;
}

=head2 updateYaml

=over

=item DESCRIPTION:

    This function is used to update the aws_access.yml, gcp_access.yml and upgrade.yml files.

=item ARGUMENTS:

    Mandatory:

     %args => should contain yml file names and fields to be updated.

=item PACKAGE:

    SonusQA::IAC

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   None

=item OUTPUT:

   1 - Success
   0 - Failure

=item EXAMPLE:

   my %args = ( 'upgrade.yml'    => '{ "image_id" : "ami-0043353da1f575b52",
                                      "upgrade_tag": "IAC_TEST_Upgrade",
                                      "instances": ["i-0ec6390ceb625b51d","i-04360fa283797665e"] }',
                'aws_access.yml' => '{ "region" : "us-east-1",
                                      "zone" : "us-east-1c",
                                      "username" : "admin",
                                      "password"  "myAdminPassword" ,
                                      "instance_id" : ["i-04360fa283797665e", "i-0ec6390ceb625b51d"],
                                      "instance_ip" : ["52.73.94.60", "3.209.225.15"] }',
                'gcp_access.yml' => '{ "region" : "us-central1",
                                      "zone" : "us-central1-c",
                                      "gcp_auth_kind" : "serviceaccount",
                                      "gcp_service_account_file" : "my_account_file_location",
                                      "gcp_project" : "myproject_id",
                                      "username" : "admin",
                                      "password" : "myAdminPassword" ,
                                      "instance_id" : ["i-04360fa283797665e", "i-0ec6390ceb625b51d"],
                                      "instance_ip" ; ["52.73.94.60", "3.209.225.15"] }'                        
               );
   $self->updateYaml(%args);

=back

=cut

sub updateYaml {
    my ($self, %args) = @_ ;
    my $sub_name = 'updateYaml';
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".updateYaml");
    $logger->debug(__PACKAGE__ . ".$sub_name : Enetered sub" );

    my %scp_args;
    $scp_args{-hostip} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{IP};
    $scp_args{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scp_args{-identity_file} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE};

    unless( $self->enterRootSessionViaSU('sudo su')) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter root session.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    my $flag = 1;
    foreach my $file (keys %args) {
        $scp_args{-sourceFilePath} = "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{IP}:$self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{STATS_PATH}"."/$file"; # file path should be added here
        $scp_args{-destinationFilePath} = $ENV{HOME}.'/.' ;
       unless(&SonusQA::Base::secureCopy(%scp_args)){
            $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the files from IAC server to ATS server");
            $flag = 0;
            last;
        }

        $logger->info(__PACKAGE__ . ".$sub_name:  Updating the yaml file $file");
        my $yaml = YAML::Tiny->read( "$ENV{HOME}/$file" );
        my $fields = decode_json  $args{$file} ;
        if ($file =~ /(aws|gcp)/) {
            $yaml->[0]->{region} = $fields->{region} ;
            $yaml->[0]->{zone} = $fields->{zone} ;
            my $redundency_group = 'redundancy_group';
            if ($yaml->[0]->{provider} =~ /gcp/){
                $yaml->[0]->{access_data}->{gcp_auth_kind} = $fields->{gcp_auth_kind} ;
                $yaml->[0]->{access_data}->{gcp_service_account_file} = $fields->{gcp_service_account_file} ;
                $yaml->[0]->{access_data}->{gcp_project} = $fields->{gcp_project} ;
                $redundency_group = 'redundancy_group1';
            }

            $yaml->[0]->{login_details}->{username} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ; 
            $yaml->[0]->{login_details}->{password} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} ;
            $yaml->[0]->{$redundency_group}->{instance1}->{instance_id} = $fields->{instance_id}->[0] ;
            $yaml->[0]->{$redundency_group}->{instance1}->{instance_ip} = $fields->{instance_ip}->[0] ; 
            $yaml->[0]->{$redundency_group}->{instance1}->{login_details}->{username} = $fields->{username};
            $yaml->[0]->{$redundency_group}->{instance1}->{login_details}->{password} = $fields->{password};
            
            if ( scalar @{$fields->{instance_id}} > 1 ) {
                $yaml->[0]->{$redundency_group}->{instance2}->{instance_id} = $fields->{instance_id}->[1] ;
                $yaml->[0]->{$redundency_group}->{instance2}->{instance_ip} = $fields->{instance_ip}->[1] ;   # active ip
                $yaml->[0]->{$redundency_group}->{instance2}->{login_details}->{username} = $fields->{username};
                $yaml->[0]->{$redundency_group}->{instance2}->{login_details}->{password} = $fields->{password};
            } else {
                delete $yaml->[0]->{$redundency_group}->{instance2} ;
            }
        }else {
            $yaml->[0]->{image_id} = $fields->{image_id} ;
            $yaml->[0]->{upgrade_tag} = $fields->{upgrade_tag} ;
            $yaml->[0]->{tasks}->{upgradeGroup1}->{instances} = [$fields->{instances}->[0], ] ;
        
            if ( scalar @{$fields->{instances}} > 1 ) {
                $yaml->[0]->{tasks}->{upgradeGroup2}->{instances} = [$fields->{instances}->[1], ] ; ;
            }else {
                delete $yaml->[0]->{tasks}->{upgradeGroup2} ;
            }
        }
        $yaml->write( "$ENV{HOME}/$file" );

        $scp_args{-sourceFilePath} = $ENV{ HOME}."/$file";
        $scp_args{-destinationFilePath} = "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{IP}:/tmp/$file";
        unless(&SonusQA::Base::secureCopy(%scp_args)){
            $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the updated files from ATS server to IAC server");
            $flag = 0;
            last;
        }
        $logger->info(__PACKAGE__ . ".$sub_name:  Copying file from /tmp/$file to $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{STATS_PATH}/$file");
        $self->{conn}->cmd('unalias cp') ;
        unless ($self->{conn}->cmd("cp /tmp/$file $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{STATS_PATH}/$file")) {
            $logger->error(__PACKAGE__ . ".$sub_name : Failed to copy. Error observed - $self->{conn}->errmsg" );
            $logger->debug(__PACKAGE__ . ".$sub_name : Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name : Session Input Log is: $self->{sessionLog2}");
            $flag = 0;
            last ;
        }
    }
    $flag = $self->leaveRootSession( ) ;  

    $logger->debug(__PACKAGE__ . ".$sub_name : Leaving sub[$flag]" );
    return $flag;
}

