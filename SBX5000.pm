package SonusQA::SBX5000;

=head1 NAME

SonusQA::SBX5000 - Perl module for SBX5000 interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::SBX5000->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]',
                               -OBJ_PORT => '<port>'
                               );

   NOTE: port 2024 can be used during dev. for access to the Linux shell 

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus SBX5000.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw(locate);
use File::Basename;
use XML::Simple;
use Data::GUID;
use Tie::File;
use Sub::Identify ':all';
use Hash::Merge ;
use String::CamelCase qw(camelize decamelize wordsplit); 
use SonusQA::SBX5000::DSBC_LOOKUP;
use JSON qw( decode_json );
use feature qw(state);
use Net::Netmask;

our $VERSION = "1.0";

our %packetPorts = (
                SBX5100 => ['pkt0', 'pkt1'],
                SBX5200 => ['pkt0', 'pkt2', 'pkt1', 'pkt3'],
                SBX7000 => ['pkt0', 'pkt1'],
                );

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SBX5000::SBX5000HELPER SonusQA::SBX5000::SBXLSWUHELPER SonusQA::SBX5000::SLBHELPER);

#TOOLS-8397 - To support SR-IOV (single root input/output virtualization) setup configuration.
our $nonCe2Ce = {
#TOOLS-12807
               'V4' => { 'ip'        => 'ipVarV4',
                         'prefix'    => 'prefixVarV4',
                       },
               'V6' => { 'ip'        => 'ipVarV6',
                         'prefix'    => 'prefixVarV6',
                       },
               'vlanTag'             => 'vlanTagVar',
               'altMediaIpAddress'   => 'altIpVars', #TOOLS-16023
               'altMediaIpAddresses' => 'altIpVars', #TOOLS-8533,
               'gwSigPort'           => 'ipVar', #TOOLS-19735
               'pktIpAddress'        => 'pktIpVar', #TOOLS-77571
               'relayPort'           => 'ipVar' #TOOLS-71360
       };

my %oam_functions = ('configureNtp' => 1, 'setNtpServer' => 1 ,'enterPrivateSession' => 1,'leaveConfigureSession' => 1, 'generateLicense' =>1,'enableAdminPassword' => 1);
my %oam_sbc_functions = ( 'execCommitCliCmdConfirm' => 1, 'execRevertCliCmdConfirm' => 1,  'changePassword' => 1, 'execSystemCliCmd' => 1, 'closeConn' => 1, 'reconnect' => 1, 'DESTROY' => 1,'makeReconnection' => 1 ) ;

our $meta_var; 

=head2  doInitialization 

=over

=item DESCRIPTION:

 Routine to set object defaults and session prompt

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=back

=cut

######################
sub doInitialization {
######################
    my ( $self, %args ) = @_;
    my $logger          = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES}          = ["SSH"];
    $self->{TYPE}               = __PACKAGE__;
    $self->{CLITYPE}            = "sbx5000";    # Is there a real use for this?
    $self->{conn}               = undef;
    $self->{PROMPT}             = '/.*[#>\$%] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{REVERSE_STACK}      = 1;
    $self->{LOCATION}           = locate __PACKAGE__;
    $self->{CHECK_CORE}         = 0;
  
    my ( $name, $path, $suffix )    = fileparse($self->{LOCATION},"\.pm"); 
  
    $self->{DIRECTORY_LOCATION}     = $path;
    $self->{IGNOREXML}              = 1;
    $self->{SESSIONLOG}             = 1;
    $self->{DEFAULTTIMEOUT}         = 60;
    $self->{DECODETOOL}             = '/opt/sonus/sbx/bin/decodetool';
    $self->{ROOT_OBJS}              = [];

    $self->{PRIVATE_MODE}           = 0;
    $self->{STORE_LOGS}             = 0;
    $self->{BANNER_ACK}             = 'yes';
    $self->{REQUIRED_LOGS}          = [];
    $self->{SOFT_SBC}               = 0;
    $self->{EXTRABANNER}            = 1; # CQ SONUS00155022
    $self->{DEFAULT_PASSWORD}       = "admin";
    $self->{MGMT_LOGICAL}           = "MGMTNIF";     #TOOLS- 13882
    $self->{MGMTNIF}                = 1;
    $self->{TIMEOUT_COUNTER} = 0;
    $self->{CLOUD_PLATFORM} = '';
    $self->{CHECK_SYNCSTATUS} = 1; #TOOLS-75516
    
    if (keys (%main::packetPorts) ) {
	$logger->debug(__PACKAGE__ . ".doInitialization : packet ports from testbedDefinition: ". Dumper(\%main::packetPorts));
        foreach my $type (keys %main::packetPorts){
	    $logger->debug(__PACKAGE__ . ".doInitialization : overriding packet ports of $type from testbedDefinition file");
	    $packetPorts{$type} = $main::packetPorts{$type};
	}
	$logger->debug(__PACKAGE__ . ".doInitialization : new packet ports : ". Dumper(\%packetPorts));
    }

    foreach ( keys %args ) {
        # Checks for -obj_hostname being set    
        #
        if ( /^-?obj_hostname$/i ) {   
            $self->{OBJ_HOSTNAME} = $args{ $_ };
        } 
	#Check for -sbc_type being set (D_SBC)
        #
        if ( /^-?sbc_type$/i ) {
            $self->{SBC_TYPE} = $args{ $_ };
        }
        # Checks for -obj_port being set    
        #
        if ( /^-?obj_port$/i ) {  
            # Attempting to set ENTEREDCLI
            # based on PORT number
            #
            $self->{OBJ_PORT} = $args{ $_ };

            if ( $self->{OBJ_PORT} == 2024 ) {      # In Linux shell
                $self->{ENTEREDCLI} = 0;
            }
            elsif ( $self->{OBJ_PORT} == 22 ) {     # Explicitly specified default ssh port
                $self->{ENTEREDCLI} = 1;
            }
            else {                                  # Other port. Not the CLI. Maybe an error.
                $self->{ENTEREDCLI} = 0;
            }
            last;                                   # Don't forget to stop the search!
        }
    }
    if ( !$self->{OBJ_PORT} ) {                     # No PORT set, default port is CLI
                $self->{ENTEREDCLI} = 1;
    }    
}

=head2  new 

=over

=item DESCRIPTION:

    This subroutine will differtiate if SBC type is I_SBC and D_SBC. Depending on the type, it will decide, how the different Object is created.
    The subroutine will return SBX5000 object which contain individual component SBC object.
    When Object type is D_SBC, we can access a individual component like this --
        $self->{SBC_TYPE}->{index},  where SBC_TYPE is M_SBC/T_SBC/S_SBC and index is numbered instance i.e. 1,2,3...etc
    and sbx_ce hash will have S_SBC values.

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=back

=cut

###########
sub new {
###########
    my $sub = "new";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my ($class,%args) = @_;
    my $self;
    if ($args{-d_sbc}){ # D_sbc
        delete $args{-d_sbc};
        $self = bless {}, $class;
        $self->{D_SBC} = 1;
        my %tms_alias_data = %{$args{-tms_alias_data}};
        delete $args{-tms_alias_data};

        #For HA
        my $female = ($main::TESTSUITE->{STANDALONE}) ? '' : SonusQA::ATSHELPER::getMyHaPair($args{-tms_alias_name});
        my $tms_alias_data_female = '';
        if($female){
            $tms_alias_data_female = SonusQA::Utils::resolve_alias($female);
            $self->{HA_SETUP} = 1;
        }
        my $logs = $args{-sessionLog};
        if ($tms_alias_data{S_OAM} or $tms_alias_data{M_OAM}) {
            $self->{OAM} = 1;
            $args{-oam} = 1 ;
        }
        my $cinder_no = 0;
        $logger->debug(__PACKAGE__ . ".$sub: SBC type is D-SBC. Creating object for each component of D-SBC ");
        foreach my $sbc ( 'S_OAM', 'S_SBC', 'M_OAM', 'M_SBC', 'T_OAM', 'T_SBC', 'I_SBC','SLB' ){
	    next unless ($tms_alias_data{$sbc});
            my $sbc_rgip='';
            foreach my $index (sort {$a <=> $b} keys %{$tms_alias_data{$sbc}}){          #TOOLS-15450
                my $aliasname = $tms_alias_data{$sbc}->{$index}->{'NAME'};
                my $aliasname_female = ($tms_alias_data_female) ? $tms_alias_data_female->{$sbc}->{$index}->{'NAME'} : '';
		$logger->debug(__PACKAGE__ . ".$sub: Creating object for $aliasname ($sbc->$index)");
		$args{-sbc_type} = $sbc; #We will set the SBC type in doInitilization()
                if($logs) {
                    $args{-sessionLog} = ($logs == 1) ? $sbc.'-'.$index : $logs.'-'.$sbc.'-'.$index;
                }
                if($tms_alias_data{NODE}->{1}->{TYPE} and $tms_alias_data{NODE}->{1}->{TYPE} =~ /\s*NK\s*/i){
                    $self->{HA_SETUP} = 1;
                    $self->{NK_REDUNDANCY} = 1;
                    $args{sbc_rgIp} = $sbc_rgip;
                }
		my $ce = $main::TESTBED{$main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}->{GUI}->{1}->{NAME}};
		$args{ems_ip} = $main::TESTBED{$ce.":hash"}->{NODE}->{1}->{IP} || $main::TESTBED{$ce.":hash"}->{NODE}->{1}->{IPV6} if($ce);
		if(exists $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}->{GUI}->{1}->{IP} || exists $args{ems_ip}){
			$args{-coam} = 1;
			my $temp = $1 if($sbc =~ /(S|M)_OAM/);
	                my $subtype = lc $temp."sbc" if($temp);
        	        my $identifier = $temp ? "$aliasname$temp" : $aliasname;
                	$identifier =~ s/_//g;
	                my %form_fields = (
                            'ems' => $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}->{GUI}->{1}->{IP} || $args{ems_ip},
                            'op' => 'createCluster',
                            'cluster_name' => "$identifier",
                            'cluster_ident' => "$identifier",
                            'Reachability_polling_interval' => '1',
                            'Registration_Complete_interval' => '20',
                            'Offline_reachability_polling_interval' => '24',
                            'Unregistered_node_interval' => '7'
        	        );
			$form_fields{'cluster_type'} = $temp ? 'SBC SWe' : 'SLB';
			if($temp) { 
			    $form_fields{'cluster_subtype'} = $subtype;
                            $form_fields{'cluster_configtype'} = 'OAM';
			}	
	                $args{'cluster_id'} = SonusQA::ATSHELPER::clusterOperation(%form_fields);
        	        unless($args{'cluster_id'}){
	                        $logger->debug(__PACKAGE__ . ".$sub: Failed to create cluster for OAM $aliasname");
        	                $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub[0]");
                	        return 0;
	                }
		}
                $args{-PARENT} = $self; #using in setSystem for set the CE1LinuxObj of actives
                $args{-INDEX} = $index;
                if($args{-nested}){
		    $self->{NESTED} = 1;
		    $main::TESTBED{$aliasname} = "sbx5000:1:ce0:$sbc:$index";
		    $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"} = $tms_alias_data{$sbc}{$index};
		    $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}{'__OBJTYPE'} = $tms_alias_data{'__OBJTYPE'};
		    my $getUser = `whoami`;
		    chomp($getUser);
		    $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}{'LOGIN'}{1}{KEY_FILE} = "/home/$getUser/ats_repos/lib/perl/SonusQA/cloud_ats.key";
		    $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}{'LOGIN'}{1}{PASSWD} = $tms_alias_data{LOGIN}->{1}->{PASSWD} if(exists $tms_alias_data{LOGIN}->{1}->{PASSWD});
                    $main::TESTBED{"sbx5000:1:ce0:$sbc:$index:hash"}{'NTP'}{1}{IP} = '10.128.254.67';
		}
                $args{-cinder_id} = $args{-cinder}[$cinder_no] if exists($args{-cinder});
                unless ($self->{$sbc}->{$index} = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $aliasname, -tms_alias_female => $aliasname_female, %args)) {
                    $logger->debug(__PACKAGE__ . ".$sub Failed to create the object of '$aliasname'");
                    $main::failure_msg .= "TOOLS:SBX5000-SBC object creation failure; ";
                    $self = 0;
                    last;
                }
                $cinder_no++;
		$logger->debug(__PACKAGE__ . ".$sub: Object created for $aliasname ($sbc->$index)");		

                # Setting PKT_ARRAY(TOOLS-6292), APPLICATION_VERSION (TOOLS-6292), PROMPT(TOOLS-8184) for D_SBC
                foreach (qw(PKT_ARRAY APPLICATION_VERSION OS_VERSION PROMPT DEFAULTPROMPT ENTEREDCLI POST_4_0 POST_3_0 CLOUD_SBC)){
                    unless (exists $self->{$_}) {
                        $self->{$_} = $self->{$sbc}->{$index}->{$_};
                        $logger->debug(__PACKAGE__ . ".$sub: Setting $_ from $sbc -> $index : ". Dumper($self->{$_}));
                    }
                }
                # TOOLS-8509: Adding 'BANNER' to D_SBC object
                push (@{$self->{BANNER}}, @{$self->{$sbc}->{$index}->{BANNER}});
                $sbc_rgip = $self->{$sbc}->{$index}->{'TMS_ALIAS_DATA'}->{'SBC_RGIP'};
		delete $args{-coam};
            }
            last unless $self;
            unless ( $sbc =~ /S_OAM|M_OAM|T_OAM/ ){
                push (@{$self->{PERSONALITIES}}, $sbc) ;#to reduce the hard coding of "M_SBC, T_SBC, S_SBC | I_SBC"
                unless (exists $self->{TMS_ALIAS_DATA} ){
                    my $hash_merger = Hash::Merge->new('RIGHT_PRECEDENT');
                    %{$self->{TMS_ALIAS_DATA}} = %{ $hash_merger->merge( $self->{$sbc}->{1}->{TMS_ALIAS_DATA}, \%tms_alias_data ) };
                    $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME} = $self->{$sbc}->{1}->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME};
                    $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} =$self->{$sbc}->{1}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
		    delete $self->{TMS_ALIAS_DATA}->{VM_CTRL} unless($args{-nested}); #TOOLS-75480 - To prevent spawning of DSBC again as we add SSBC data to DSBC
		    delete $self->{TMS_ALIAS_DATA}->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE} unless($args{-nested});# TOOLS-75480 - To prevent treating DSBC as nested when newFromAlias is called twice
                }
            }
        }

        #TOOLS-8184
        if($self){
            $self->{conn} = $self;
            $self->{ACTIVE_CE} = 'DSBC_ACTIVE_CE';
            $self->{STAND_BY} = 'DSBC_STAND_BY';
            $self->{DSBC_ACTIVE_CE}->{conn} = bless {DSBC_CE => 'ACTIVE_CE', DSBC_OBJ => $self}, $class;
            $self->{DSBC_STAND_BY}->{conn} = bless {DSBC_CE => 'STAND_BY', DSBC_OBJ => $self}, $class;

            # Fix for TOOLS-12508 :  some times they call directly with CE0LinuxObj / CE1LinuxObj, then we don't need to find the which LinuxObj is ACTIVE_CE / STAND_BY
            $self->{CE0LinuxObj}->{conn} = bless {DSBC_CE => 'CE0LinuxObj', DSBC_OBJ => $self}, $class;
            $self->{CE1LinuxObj}->{conn} = bless {DSBC_CE => 'CE1LinuxObj', DSBC_OBJ => $self}, $class;
        }
        else{
            $logger->error(__PACKAGE__ . ".$sub Failed to create D-SBC object for '$args{-tms_alias_name}'");
        }
    }
    else {# I_sbc
        $self = SonusQA::Base::new($class, %args);
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
    return $self;
}


=head2  setSystem 

=over

=item DESCRIPTION:

    This function sets the system information. The following variables are set if successful:

                $self->{CE_NAME_LONG}         = long CE name, ie. the domain name of the CE
                $self->{HARDWARE_TYPE}        = hardware_type, the physical box
                $self->{SERIAL_NUMBER}        = serial number
                $self->{PART_NUMBER}          = part number
                $self->{MANUFACTURE_DATE}     = manufacture date
                $self->{PLATFORM_VERSION}     = platform version
                $self->{APPLICATION_VERSION}  = application version
                $self->{MGMT_RED_ROLE}        = platform management redundancy role, ie. active or standby
    The command "show status system serverStatus" is run on the SBC and using its output the above variables are set.
    Additionally it also performs the following:
	1. Creation of root object. ( 2 root objects in case of HA - one to active and the other to standby). It is stored in @{$self->{ROOT_OBJS}}.  $self->{ROOT_OBJS} = ['CE0LinuxObj'] for standalone and  $self->{ROOT_OBJS} = ['CE0LinuxObj', 'CE1LinuxObj'] for HA. It also sets the root objects to $self->{ACTIVE_CE} and $self->{STAND_BY} for the active and standby objects respectively. Only $self->{ACTIVE_CE} is set in case of stand alone devie.
	2. It sets the packet port array. $self->{PKT_ARRAY} 
	3. It sets the os version  $self->{OS_VERSION}.
	4. It sets the coredump profile on the SBC if the flag $self->{SET_COREDUMP_PROFILE} is set in the testsuitelist

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

=back

=cut

#################
sub setSystem() {
#################
    my $version_check_cmd       = "show status system serverStatus";
    my $get_node_hostname_cmd       = "show status system admin";
    my $get_ethernert_port_cmd  = "show table system ethernetPort portMonitorStatus";

    my ($key,@value,$value,@output,%output);
    my ($self) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my ( $cmd, $prompt, $prevPrompt, @results, @version_info, $hw_Type1);

    if($self->{SKIP_LINUXADMIN}){ #TOOLS-74857
        $logger->warn(__PACKAGE__. ".$sub_name: Not connecting to linuxadmin as SKIP_LINUXADMIN flag is set.");
        $logger->debug(__PACKAGE__. ".$sub_name <-- Leaving Sub [1]");
        return 1;
    }

    my $lastline = $self->{conn}->lastline;

    if ((scalar(@{$self->{BANNER}}) < 1) and  $lastline !~ m/(connected|Last.*login)/i ) { #TOOLS-15390 (eg. Your last successful login was from 10.54.81.88)
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".$sub_name:  This session does not seem to be connected. Skipping System Information Retrieval");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $main::failure_msg .= "TOOLS:SBX5000-SBC login error; ";
        return 0;
    }

    unless ( $self->{ENTEREDCLI} ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".$sub_name:  Not in CLI (PORT=$self->{OBJ_PORT}), sbx5000 version information not set.");
        unless ($self->becomeRoot('sonus1')) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to become a root using password sonus1");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "TOOLS:SBX5000-SBC login error; ";
            return 0;
        }
        return 1;
    }
    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        #
        $logger->warn(__PACKAGE__ . ".$sub_name:  Hostname variable (via -obj_hostname) not set.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $main::failure_msg .= "TOOLS:SBX5000-SBC login error; ";
        return 0;
    }

     #TOOLS-19885 
     my $flag =1;
     foreach my $set_terminal_cmd ("set paginate false", "set screen width 512", "set complete-on-space false") {
          unless ($self->{conn}->cmd($set_terminal_cmd)) {
              	
              $logger->error(__PACKAGE__ . ".execCmd failed to execute :". $set_terminal_cmd. "\nerrmsg: ". $self->{conn}->errmsg);
              $flag =0;
              last;
          }
     }
     if($flag == 0){
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
     }

     $self->{ADMIN_USER} = $self->isAdminUser($self->{OBJ_USER});

    # Enhancement: TOOLS-9697
    # return without creating root sessions and not setting version information, packet port array, coredump profile if $self->{TMS_ALIAS_DATA} not exists.
    # mainly this happens if we call SonusQA::SBX5000->new() directly, instead of SonusQA::ATSHELPER::newFromAlias()
    # it helps the people to create only admin session
        unless(exists $self->{TMS_ALIAS_DATA}){
            $logger->warn(__PACKAGE__ . ".$sub_name:  self->{TMS_ALIAS_DATA} is not exists (looks like SonusQA::SBX5000->new() is called directly). So not creating root sessions and not setting version information, packet port array, coredump profile");
            $logger->warn(__PACKAGE__ . ".$sub_name: If need complete SBX5000 object, call SonusQA::ATSHELPER::newFromAlias()");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
            return 1;
        }

    if($self->{ADMIN_USER}){

	unless($self->{RE_CONNECTION}){
        #TOOLS-74955: added checkSbxSyncStatus to make sure stand by to come up. We have seen such occurence for newly spawned instances 
        #TOOLS-75516: skip checkSbxSyncStatus if CHECK_SYNCSTATUS == 0
        if ($self->{HA_SETUP} and ! $self->{PARENT}->{NK_REDUNDANCY} and $self->{CHECK_SYNCSTATUS}) {
            my %cliHash = ( 'Policy Data' => 'syncCompleted',
                        'Disk Mirroring' => 'syncCompleted',
                        'Configuration Data' => 'syncCompleted',
                        'Call/Registration Data' => 'syncCompleted' 
            );

            unless ($self->checkSbxSyncStatus('show status system syncStatus', \%cliHash)) {
                $logger->error(__PACKAGE__ . ".$sub_name: sync status check failed");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
            }
        }

            @version_info = $self->{conn}->cmd($version_check_cmd);
            foreach ( @version_info ) {
                if ($_ =~ /^\s+hwType\s+(.*)\;$/i) {
                    unless ($1 =~ /Unknown/i) {
                        $hw_Type1 = $1;
                    }
                }

                $output{'serverStatus'} = $1 if( $_ =~ /^\s*serverStatus\s+(.*)\s+\{$/i && not exists $output{'serverStatus'} ); #TOOLS-19937
                next unless($hw_Type1);
                $_ =~ s/\s+\{\s*//;
                $_ =~ s/\}\s*\n//;
                $_ =~ s/\[ok\].*//s;
                $_ =~ s/^\n$//;
                $_ =~ s/^\s+//;
                $_ =~ s/\;//;
                ($key, @value) = split /\s+/, $_;
                $value = join " ", @value;
                
                push (@{$self->{CHASSIS_SERIAL_NUMBERS}}, $value) if ($key eq 'serialNum');#TOOLS-19937
                
                $output{$key} = $value unless defined $output{$key};
            }     
            $self->{CLOUD_SBC} = ($output{'hwSubType'} =~ /virtualCloud/) ? 1 : 0;
            $main::TESTSUITE->{SBX_HWSUBTYPE} = $output{'hwSubType'} unless ($main::TESTSUITE->{SBX_HWSUBTYPE}) ;
	}
    #TOOLS-17818 - Added 'sessionIdleTimeout' cmd 
        return 0 unless ( $self->enterPrivateSession() );
        my $idletimeout = defined($main::TESTSUITE->{IDLE_TIMEOUT}) ? $main::TESTSUITE->{IDLE_TIMEOUT} : 120;
	$self->{SKIP_CMDFIX} = 1;
        unless ($self->{OAM}) {
            my $command = ($self->{CLOUD_SBC}) ? "set system admin vsbcSystem accountManagement sessionIdleTimeout idleTimeout $idletimeout" : "set system admin $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} accountManagement sessionIdleTimeout idleTimeout $idletimeout";
            unless($self->execCmd($command)){
	        $logger->error(__PACKAGE__ . ".$sub_name failed to execute [$command]");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
	    }
        }
        if(exists $self->{SBC_TYPE} and $self->{SBC_TYPE} =~ /T_SBC/ and $self->{CLOUD_SBC}){
	    my $command = "set system admin vsbcSystem accountManagement maxSessions 5";

            unless($self->execCommitCliCmdConfirm(($command,"set system sweActiveProfile name standard_transcoding_profile"))){
		$logger->error(__PACKAGE__ . ".$sub_name Failed to convert to T_SBC.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	        return 0;
	    }
            if(grep $_ =~ /No modifications to commit/i,@{$self->{CMDRESULTS}}) {
                    return 0 unless ( $self->leaveConfigureSession );
            }
            else {
                sleep(10);
                if ( $self->reconnect(-retry_timeout => 420)){ #As per TOOLS-71294, increased -retry_timeout to 420 from 300
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
                    return 1;
                }
            }
        }
        else{
            return 0 unless ( $self->leaveConfigureSession );
        }
	$self->{SKIP_CMDFIX} = 0;
    }
    unless ($self->{RE_CONNECTION}){
=for comment
# heat template to spawn SBC cloud instance
#	    if ($self->{CLOUD_SBC} and !$self->{HA_SETUP})
	    if (($self->{CLOUD_SBC}) and ($self->{TMS_ALIAS_DATA}->{$self->{TMS_ALIAS_DATA}->{CE_NAME}} eq "nova")){
                unless ($self->enableSSHviaCLI()) {
                    $logger->error(__PACKAGE__ . ".$sub_name Failed to enable ssh via cli");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
=cut

            $logger->info(__PACKAGE__ . ".$sub_name:  ATTEMPTING TO RETRIEVE SBX SYSTEM INFORMATION FROM CLI");
            if ( $version_info[$#version_info] =~ /^\[error\]/ ) {
                # CLI command is wrong
                $logger->warn(__PACKAGE__ . ".$sub_name:  SYSTEM INFO NOT SET. CLI COMMAND ERROR. CMD: \'$version_check_cmd\'.\n ERROR:\n @version_info");
                # return 0;
            }
            $self->{CE_NAME_LONG}       = $output{serverStatus};
            $self->{HARDWARE_TYPE}      = $output{hwType};
            $self->{SERIAL_NUMBER}      = $output{serialNum};
            $self->{PART_NUMBER}        = $output{partNum};
            $self->{PLATFORM_VERSION}   = $output{platformVersion};
            $self->{APPLICATION_VERSION}= $output{applicationVersion};
            $self->{MGMT_RED_ROLE}      = $output{mgmtRedundancyRole};
            $self->{RESTART_REASON}     = $output{lastRestartReason};

            ( $self->{PKT_PORT_SPEED}   = $output{pktPortSpeed} ) =~ s/^speed//i; #removing 'speed' from the pktPortSpeed Fix for TOOLS-5221

            $logger->info(__PACKAGE__ . ".$sub_name:  \'$self->{OBJ_HOSTNAME}\': Platform/Application Versions: $self->{PLATFORM_VERSION} / $self->{APPLICATION_VERSION}");

    }
# checking user wished to make connection using ipv4/ipv6 and MGMTNIF->1/MGMTNIF->2
    my $logical_or_mgmt =$self->{MGMT_LOGICAL};             #TOOLS - 13882
    my $ip_index = $self->{$logical_or_mgmt};
    my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
    $self->{ROOT_OBJS} = ['CE0LinuxObj'];

    #Storing the key file in global hash %SSH_KEYS when sbc instance is spawned using ssh keys for linuxadmin user.
    #This key will be used when user calls SBX5000::SBX5000HELPER::makeRootSession and Base::secureCopy
    if ($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE}) {
	$logger->debug(__PACKAGE__ . ".$sub_name: storing keys for ".$self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}." and user 'linuxadmin'");   #TOOLS - 13882
        $SSH_KEYS{$self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}}{'linuxadmin'} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE};  
    }
    if ($self->{HA_SETUP} and ! $self->{PARENT}->{NK_REDUNDANCY} ) {
        my $linuxObj = ($self->{TMS_ALIAS_DATA}->{CE1}->{1}->{HOSTNAME}) ? 'CE0LinuxObj' : 'CE1LinuxObj';

#TOOLS-18508 - Introducing -do_not_touch_sshd flag to skip the changes in /etc/ssh/sshd_config
	unless ($self->{$linuxObj} = SonusQA::SBX5000::SBX5000HELPER::makeRootSession(-obj=>$self, -obj_host => $self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}, -obj_key_file => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE}, -return_on_fail => $self->{RETURN_ON_FAIL}, -do_not_touch_sshd => $self->{DO_NOT_TOUCH_SSHD} , -skip_root =>$self->{SKIP_ROOT})) { #TOOLS - 13882
            $logger->error(__PACKAGE__ . ".$sub_name: unable to create root session to \'$self->{TMS_ALIAS_NAME}\'");
        } else {
            $self->{$linuxObj}->{APPLICATION_VERSION} = $self->{APPLICATION_VERSION};   #TOOLS - 13145
            $logger->debug(__PACKAGE__ . ".$sub_name: successfully created root session to \'$self->{TMS_ALIAS_NAME}\'");
        }

        my $secondary = ($self->{TMS_ALIAS_NAME} eq $self->{HA_ALIAS}->[0]) ? $self->{HA_ALIAS}->[1] : $self->{HA_ALIAS}->[0];
	my $alias_hashref;
        my $ce = $main::TESTBED{$secondary};
        %{$alias_hashref} = %{$main::TESTBED{$ce.":hash"}};
        $linuxObj = ($linuxObj eq 'CE0LinuxObj') ? 'CE1LinuxObj' : 'CE0LinuxObj';

	#Storing SSH_KEYS for stand_by instance
        if ($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE}) {
            $logger->debug(__PACKAGE__ . ".$sub_name: storing keys for ".$alias_hashref->{$logical_or_mgmt}->{$ip_index}->{$ip_type}." and user 'linuxadmin'");      #TOOLS - 13882
            $SSH_KEYS{$alias_hashref->{$logical_or_mgmt}->{$ip_index}->{$ip_type}}{'linuxadmin'} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE};                
        }

#TOOLS-18508 - Introducing -do_not_touch_sshd flag to skip the changes in /etc/ssh/sshd_config
	unless ($self->{$linuxObj} = SonusQA::SBX5000::SBX5000HELPER::makeRootSession(-obj=>$self, -obj_host => $alias_hashref->{$logical_or_mgmt}->{$ip_index}->{$ip_type}, -obj_key_file => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE}, -return_on_fail => $self->{RETURN_ON_FAIL}, -do_not_touch_sshd => $self->{DO_NOT_TOUCH_SSHD} , -skip_root =>$self->{SKIP_ROOT})) { #TOOLS - 13882
            $logger->error(__PACKAGE__ . ".$sub_name: unable to create root session to \'$secondary\'");
        } else {
            $self->{$linuxObj}->{APPLICATION_VERSION} = $self->{APPLICATION_VERSION};     #TOOLS - 13145
            $logger->debug(__PACKAGE__ . ".$sub_name: successfully created root session to \'$secondary\'");
        }

        if (ref $self->{CE0LinuxObj} and grep (/\Q$self->{CE0LinuxObj}->{OBJ_HOST}\Q/, @{$self->{OBJ_HOSTS}})) {
            $logger->debug(__PACKAGE__ . ".$sub_name: root session pointing to active CE is -> CE0LinuxObj");
            $self->{ACTIVE_CE} = 'CE0LinuxObj';
            $self->{STAND_BY} = 'CE1LinuxObj';
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: root session pointing to active CE is -> CE1LinuxObj");
            $self->{ACTIVE_CE} = 'CE1LinuxObj';
            $self->{STAND_BY} = 'CE0LinuxObj';
        }

        push(@{$self->{ROOT_OBJS}}, 'CE1LinuxObj');
    } else {
#TOOLS-18508 - Introducing -do_not_touch_sshd flag to skip the changes in /etc/ssh/sshd_config
        unless ($self->{CE0LinuxObj} = SonusQA::SBX5000::SBX5000HELPER::makeRootSession(-obj=>$self, -obj_host => $self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}, -return_on_fail => $self->{RETURN_ON_FAIL}, -obj_key_file => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE}, -do_not_touch_sshd => $self->{DO_NOT_TOUCH_SSHD} , -skip_root =>$self->{SKIP_ROOT})) { #TOOLS - 13882
            $logger->error(__PACKAGE__ . ".$sub_name: failed to create \'CE0LinuxObj\' root session to \'$self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}\'");
        } else {
            $self->{CE0LinuxObj}->{APPLICATION_VERSION} = $self->{APPLICATION_VERSION};  #TOOLS- 13145
            $logger->debug(__PACKAGE__ . ".$sub_name: successfully created \'CE0LinuxObj\' root session to \'$self->{TMS_ALIAS_DATA}->{$logical_or_mgmt}->{$ip_index}->{$ip_type}\'");
            $self->{ACTIVE_CE} = 'CE0LinuxObj';
        }
    }
    if ($self->{CLOUD_SBC}){
                    if( $version_info[0] =~ /serverStatus\s+(.+)\s+\{/i){
                        $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME} = $1; # TOOLS-17844
                        $logger->info(__PACKAGE__ . ".$sub_name: CE Hostname: $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}");
                    }
                    #Get the NODE HOSTNAME value form 'show status system admin' command
                    my @showStatusSysAdminRslt = $self->execCmd($get_node_hostname_cmd); #tools-8875 Changed from $self->{conn}->cmd()
                    if($showStatusSysAdminRslt[0] =~ /admin\s+(.+)\s+\{/i){
                        $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} = $1;
                        $logger->info(__PACKAGE__ . ".$sub_name: NODE Hostname: $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}");
                    }
                    $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME} =  $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} = $1 if($showStatusSysAdminRslt[1] =~ /actualSystemName\s+(.+);/);
                    $logger->info(__PACKAGE__ . ".$sub_name: NODE Actual Systemname: $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ACTUALSYSTEMNAME}");
    }
    unless($self->{RE_CONNECTION}){
      #TOOLS-19937
      unless($self->{CLOUD_PLATFORM}){
        my ($platform) = $self->{CE0LinuxObj}->{conn}->cmd('hwinfo | grep -E \'Platform\s+:.+\'');
        $self->{CLOUD_PLATFORM} = $1 if($platform =~/Platform\s+:\s+(.+)/);
        $logger->info(__PACKAGE__ . ".$sub_name: \$self->{CLOUD_PLATFORM}= $self->{CLOUD_PLATFORM}");
      }      

        # why dont we store os version, also get the application version for soft/virtual sbc
            $self->{OS_VERSION} = $self->getOsVersion();
            if ( $self->{SOFT_SBC} ) {
                $logger->info(__PACKAGE__ . ".$sub_name:  its a SOFT/VIRTUAL SBC.");
#                $self->{PKT_ARRAY} = $main::packetPorts{'SBX5100'}; #just an assumption
                $self->{PKT_ARRAY} = $packetPorts{'SBX5100'}; #just an assumption
	        $logger->info(__PACKAGE__ . ".$sub_name: PacketPorts for soft sbc : @{$packetPorts{'SBX5100'}}");
                if ($self->{CLOUD_SBC}){
                    if($self->{ADMIN_USER}){
                    #NTP server configuration for cloud SBC
                    unless($self->{OAM}) {
                        unless ($self->setNtpServer()){
                            $logger->error(__PACKAGE__ . ".$sub_name: failed to set NTP Server configuration");
                            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                            $main::failure_msg .= "TOOLS:SBX5000-Failed to set NTP; ";
                            return 0;
                        }
                    }
                    unless ( $self->getMetaDetails ) {
                        $logger->info(__PACKAGE__ . ".$sub_name:  Failed to get the META VAR details");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        $main::failure_msg .= "TOOLS:SBX5000-Failed to get metavar details; ";
                        return 0;
                    }

                    #TOOLS-20640
                    my $path = "/opt/sonus/conf/userData.json";
                    if($self->{CLOUD_PLATFORM} =~ /(AWS|Google Compute Engine)/ and SonusQA::Utils::greaterThanVersion($self->{APPLICATION_VERSION},'V07.02.00')){
                      $path = "/home/linuxadmin/sbc_diag_logs/userData.json";
                    }
                    #AWS - TOOLS-18594
                    if( @output = $self->{$self->{ACTIVE_CE}}->{conn}->cmd("cat $path")){
                        unless( grep /No such file or directory/,@output){ #TOOLS-18823
                            chomp(@output);
                            my $data =  join("\n", @output);
                            $data = $1 if($data =~ /(\{((.*[{\n}])+)\s*})/);
                            my $aws_hash = decode_json($data);
                            $self->{$self->{CLOUD_PLATFORM}} = 1 if($aws_hash->{ActiveRoleMgtId} =~ /eni/ or $self->{CLOUD_PLATFORM} =~ /(AWS|Google Compute Engine)/);
                            $self->{$self->{CLOUD_PLATFORM}."_HFE"} = 1 if ($aws_hash->{HFE} or $aws_hash->{HfeInstanceName});
                            $self->{$self->{CLOUD_PLATFORM}."_HA"} = $aws_hash->{IAM_ROLE};
                        }
                    }

                    my $ce = $main::TESTBED{$self->{TMS_ALIAS_NAME}} if ($main::TESTBED{$self->{TMS_ALIAS_NAME}}); 
                    if ($self->{AWS_HFE} or $self->{'Google Compute Engine_HFE'}) {
                        foreach my $number ('1', '2') {                      #Populating PKT_NIF->(1 and 2)->IP
                            unless ($main::TESTBED{$ce.":hash"}->{HFE}->{$number}->{IP}) {
                                $logger->info(__PACKAGE__ . ".$sub_name:  Populating {HFE}->{$number}->{IP}");
                                if ($self->{METAVARIABLE}->{"HFE_IF".($number+1).".FIPV4"}){
                                    $main::TESTBED{$ce.":hash"}->{HFE}->{$number}->{IP} = $self->{TMS_ALIAS_DATA}->{HFE}->{$number}->{IP} = $self->{METAVARIABLE}->{"HFE_IF".($number+1).".FIPV4"} ;
                                    last ;
                                }
                            }
                        }          
                    }

                    foreach my $number ('1', '2') {                      #Populating PKT_NIF->(1 and 2)->IP
                        unless ($main::TESTBED{$ce.":hash"}->{PKT_NIF}->{$number}->{IP}) {
                            $logger->info(__PACKAGE__ . ".$sub_name:  Populating {PKT_NIF}->{$number}->{IP}");
                            my @metaVar_arr ;
                            unless ($self->{AWS_HFE} or $self->{'Google Compute Engine_HFE'}) {
                                push (@metaVar_arr,"ALT_Pkt".($number-1)."_00.FIPV4") ;
                                push (@metaVar_arr,"IF".($number+1).".FIPV4") ;
                            }
                            push (@metaVar_arr, "ALT_Pkt".($number-1)."_00.IP") ;
                            push (@metaVar_arr , "IF".($number+1).".IPV4") ;
                            foreach ( @metaVar_arr ) {
                                if ($self->{METAVARIABLE}->{$_}){
                                    $main::TESTBED{$ce.":hash"}->{PKT_NIF}->{$number}->{IP} = $main::TESTBED{$ce.":hash"}->{SIGNIF}->{$number}->{IP} = $main::TESTBED{$ce.":hash"}->{SIG_SIP}->{$number}->{IP}= $self->{METAVARIABLE}->{$_} ;
                                    $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{$number}->{IP} = $self->{TMS_ALIAS_DATA}->{SIGNIF}->{$number}->{IP} = $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{$number}->{IP} = $self->{METAVARIABLE}->{$_} ;
                                    last ;
                                }
                            } 
                        }
                    }
                    my %temp_hash = (  'GW' => 'DEFAULT_GATEWAY', 'Prefix' => 'IPV4PREFIXLEN') ;
                    foreach my $key (keys %{$self->{METAVARIABLE}}) {
                        if ( $key =~ /IF(2|3)\.(GW|Prefix)V4/ ) {
                            my $num = $1 -1 ;
                            unless($main::TESTBED{$ce.":hash"}->{PKT_NIF}->{$num}->{$temp_hash{$2}} ){
                                $main::TESTBED{$ce.":hash"}->{PKT_NIF}->{$num}->{$temp_hash{$2}} = $self->{METAVARIABLE}->{$key} ;
                                $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{$num}->{$temp_hash{$2}} = $self->{METAVARIABLE}->{$key} ;
                            }
                        }
                    }
                    } 
                }
       } else {

                my $output = [];
                if (keys (%packetPorts) ) {
                    if ($hw_Type1 =~ /51[01]0/i) { 	# Need to Match 5100 and 5110 (same below for 5200, 5210)
                        $output = $packetPorts{'SBX5100'};
                    }elsif ($hw_Type1 =~ /52[01]0/i) {
                        $output = $packetPorts{'SBX5200'};
                    }elsif ($hw_Type1 =~ /7000/i) {
                        $output = $packetPorts{'SBX7000'} ;
                    }elsif ($hw_Type1 =~ /5400/i) {#TOOLS-17239
                        if ($self->{PKT_PORT_SPEED} eq '1Gbps'){
                            $output = ['pkt0','pkt2','pkt1','pkt3'];
                        }
                        elsif ($self->{PKT_PORT_SPEED} eq '10Gbps'){#TOOLS-17573 : pkt0 and pkt1 from 7.1.0 onwards.
                             $output = (SonusQA::Utils::greaterThanVersion( $self->{APPLICATION_VERSION}, 'V07.01.00')) ? ['pkt0','pkt1'] : ['pkt0','pkt0'];
                        }
                    }
                    $self->{PKT_ARRAY} = $output;
                    $logger->info(__PACKAGE__ . ".$sub_name: pktarray--> @{$output}");
                }

                unless ( $self->{CE_NAME_LONG} ) {
                   $logger->warn(__PACKAGE__ . ".$sub_name:  System information for hostname '$self->{OBJ_HOSTNAME}' not found, Version Info:\n@version_info"); 
                   #return 0;
                }
            }
            my @port_res = $self->execCmd($get_ethernert_port_cmd);
            for(my $i =0 ; $i < @{$self->{PKT_ARRAY}}; $i++){
                push (@{$self->{REDUNDANT_PORTS}[$i]}, "@{$self->{PKT_ARRAY}}[$i]_p") if( grep (/@{$self->{PKT_ARRAY}}[$i]_p/ , @port_res));
                push (@{$self->{REDUNDANT_PORTS}[$i]}, "@{$self->{PKT_ARRAY}}[$i]_s") if( grep (/@{$self->{PKT_ARRAY}}[$i]__s/, @port_res));
            }
            $logger->debug(__PACKAGE__ . ".$sub_name:PORT.".Dumper($self->{REDUNDANT_PORTS}));

        # Check to see if there was any luck...
        if ($self->{APPLICATION_VERSION} =~ /^\w(\d+\.\d+)\./) { 
            if ($1 ge '03.00' ) {
                $self->{POST_3_0} = 1;
                $logger->debug(__PACKAGE__ . ".$sub_name SBX5000 POST_3_0 flag is set");
            }
            if ($1 ge '04.00' ) {
                $self->{POST_4_0} = 1;
                $logger->debug(__PACKAGE__ . ".$sub_name SBX5000 POST_4_0 flag is also set");
            }
        }

        unless($main::TESTSUITE->{SBX5000_APPLICATION_VERSION}){
            $main::TESTSUITE->{SBX5000_APPLICATION_VERSION} = 'SBX_'.$self->{APPLICATION_VERSION};
            $logger->debug(__PACKAGE__ . ".$sub_name: Setting 'TESTSUITE->{SBX5000_APPLICATION_VERSION}' as $main::TESTSUITE->{'SBX5000_APPLICATION_VERSION'}");
        }    
        if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
            if (defined $self->{APPLICATION_VERSION}) {
                $main::TESTSUITE->{DUT_VERSIONS}->{"SBX,$self->{TMS_ALIAS_NAME}"} = $self->{APPLICATION_VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"SBX,$self->{TMS_ALIAS_NAME}"});
            } else {
                $logger->warn(__PACKAGE__ . ".$sub_name unable to get Aplication Version");
            }
            if (defined $self->{OS_VERSION} and $self->{OS_VERSION}) {
                $main::TESTSUITE->{OS_VERSION}->{"SBX,$self->{TMS_ALIAS_NAME}"} = $self->{OS_VERSION} unless ($main::TESTSUITE->{OS_VERSION}->{"SBX,$self->{TMS_ALIAS_NAME}"});
            } else {
                $logger->warn(__PACKAGE__ . ".$sub_name unable to get OS version");
            }
        }

        if ((defined $main::TESTSUITE->{SET_COREDUMP_PROFILE} and $main::TESTSUITE->{SET_COREDUMP_PROFILE} == 0) or (!$self->{ADMIN_USER})){
            $logger->info(__PACKAGE__ . ".$sub_name setCoredumpProfile is skkiped");
        } else {
            $logger->info(__PACKAGE__ . ".$sub_name setting core dump profile");
            unless ($self->setCoredumpProfile()) {
                $logger->error(__PACKAGE__ . ".$sub_name failed to set coredump profile");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving->[0]");
                $main::failure_msg .= "UNKNOWN:SBX5000-setCoredumpProfile failure; ";
                return 0;
            }
        }
        if(exists $self->{SBC_TYPE} and $self->{SBC_TYPE} =~ /S_SBC/){ #TOOLS-17148 starts
	    $logger->debug(__PACKAGE__ . ".$sub_name Entered to set ERE flag");
	    my ($cmd,@cmdresult) = ('show status system policyServer policyServerStatus PSX_LOCAL_SERVER operState',());
	    unless ( @cmdresult = $self->execCmd($cmd) ) {
                $logger->error(__PACKAGE__ . ".$sub_name failed to execute [$cmd]");
                $main::failure_msg .= "UNKNOWN:SBX5000-Failed to set ERE flag; ";
                return 0;			
            }
	    $self->{ERE} = 1 if(grep /\s+Active/, @cmdresult);
	    $logger->debug(__PACKAGE__ . ".$sub_name ERE flag is $self->{ERE} ");
        }# TOOLS-17148 ends
      }

        if( $self->{PARENT}->{NK_REDUNDANCY} ){
            my $sbc_type = $self->{SBC_TYPE};
            if( $self->execCliCmd("show table system serverStatus $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME} mgmtRedundancyRole")){
                $self->{REDUNDANCY_ROLE} = uc $1 if ($self->{CMDRESULTS}->[0] =~ /^\S+\s+(active|standby)\;/i);
                # TOOLS-13381. set the STANDBY_ROOT to CE0LinuxObj of NEW_STANDBY_INDEX
                if(my $new_sb_index = $self->{PARENT}->{NEW_STANDBY_INDEX}->{$sbc_type}){
                    $logger->debug(__PACKAGE__ . ".$sub_name setting STANDBY_ROOT as CE0LinuxObj of NEW_STANDBY_INDEX ($new_sb_index) for $sbc_type, ${sbc_type}_STANDBY_TMS: $main::TESTBED{ $self->{PARENT}->{$sbc_type}->{$new_sb_index}->{TMS_ALIAS_NAME} }");
                    $self->{PARENT}->{STANDBY_ROOT}->{$sbc_type} = $self->{PARENT}->{$sbc_type}->{$new_sb_index}->{CE0LinuxObj};
                    $self->{PARENT}->{$sbc_type."_STANDBY_TMS"} = $main::TESTBED{ $self->{PARENT}->{$sbc_type}->{$new_sb_index}->{TMS_ALIAS_NAME} };
                }
        elsif ($self->{REDUNDANCY_ROLE} =~ /STANDBY/i) {
            $logger->debug(__PACKAGE__ . ".$sub_name setting STANDBY_ROOT as CE0LinuxObj for $sbc_type, since REDUNDANCY_ROLE is STANDBY");
		    $self->{PARENT}->{STANDBY_ROOT}->{$sbc_type} = $self->{CE0LinuxObj};
		    $self->{PARENT}->{$sbc_type."_STANDBY_TMS"} = $main::TESTBED{ $self->{TMS_ALIAS_NAME} };
		}

		#  push to (S/M/T)SBC_list array
                push (@{$self->{PARENT}->{$sbc_type.'_LIST'}},$self->{INDEX} );

		#can't do this inside else, what if standby is last one
		#$self->{PARENT}->{STANDBY_ROOT}->{$sbc_type} is set for standBy and assign it to actives
		if ($self->{PARENT}->{STANDBY_ROOT}->{$sbc_type}) {
		    my $key = my $newKey = $self->{PARENT}->{$sbc_type."_STANDBY_TMS"}; #eg - $key = "SBX5000:1:ce0:M_SBC:3" where 3 is for standBy
		    $newKey =~ s/(.+:.+):ce0:(.+:).+/$1:ce1:$2/; #eg - $newKey = "SBX5000:1:ce1:M_SBC:" 

		    foreach my $index (@{$self->{PARENT}->{$sbc_type.'_LIST'}}){
                        #Setting the CE1LinuxObj and adding it into ROOT_OBJS array  
                        my $obj = ( exists $self->{PARENT}->{$sbc_type}->{$index}) ? ($self->{PARENT}->{$sbc_type}->{$index}) : ($self);
                        $obj->{CE1LinuxObj} = $self->{PARENT}->{STANDBY_ROOT}->{$sbc_type};
                        push (@{$obj->{ROOT_OBJS}},'CE1LinuxObj');
                        $obj->{STAND_BY} = 'CE1LinuxObj';
                        
			            my $tmp_key = "$newKey$index";
			            $main::TESTBED{ $tmp_key } = $main::TESTBED{ $key };		    #eg - TESTBED{'SBX5000:1:ce1:M_SBC:1'} = name of standby sbc
			            $main::TESTBED{ $tmp_key.":hash" } = $main::TESTBED{ $key.":hash" }; #eg - TESTBED{'SBX5000:1:ce1:M_SBC:1:hash'} = tms hash of standby sbc
		    }
		    undef $self->{PARENT}->{$sbc_type.'_LIST'}; #undef, so that, we dont have to undef it in makeReconnection or reconnect
		}
            }else{
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get NK Redundancy Role ");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                $main::failure_msg .= "UNKNOWN:SBX5000-Unable to get NK Redundancy Role; ";
                return 0;
            } 
       }

    @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = $self->{$self->{ACTIVE_CE}}->{conn}->cmd('uname');

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}
    
=head2  execCmd 

=over

=item DESCRIPTION:

 The function is the generic function to issue a command to the SBX5000. It utilises the mechanism of issuing a command and then waiting for the prompt stored in $self->{PROMPT}. 

 The following variable is set on execution of this function:

 $self->{LASTCMD} - contains the command issued

 As a result of a successful command issue and return of prompt the following variable is set:

 $self->{CMDRESULTS} - contains the return information from the CLI command

 There is no failure as such. What constitutes a "failure" will be when the expected prompt is not returned. It is highly recommended that the user parses the return from execCmd for both the expected string and error strings to better identify any possible cause of failure.

=item ARGUMENTS:

 1. The command to be issued to the CLI
 2. Timeout.

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 @cmdResults - either the information from the CLI on successful return of the expected prompt, or an empty array on timeout of the command.

=item EXAMPLE:

 my @result = $obj->execCmd( "show table sigtran sctpAssociation" , 10 );

=back

=cut


sub execCmd {
  
    my ($self, $cmd, $timeOut )=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
    my(@cmdResults);
    my $sub_name = 'execCmd';
    $logger->debug(__PACKAGE__ . ".execCmd: --> Entered Sub");

    my $last_cmd = $self->{LASTCMD};
    $self->{LASTCMD}    = $cmd;
    $self->{CMDRESULTS} = (); #TOOLS-8457, Emptying the CMDRESULT, to get the output of current command.

    if(exists $self->{ASAN_BUILD_FAILURE} && $self->{ASAN_BUILD_FAILURE}) {
        $logger->error(__PACKAGE__. ".$sub_name:  ASAN Build Failure DETECTED");
        $self->{CMDRESULTS} = ['[error]'];
        return ();
    }
    
    if($cmd =~ /rm \-rf (\/opt\/sonus\/external\/)\*/){
        $logger->info(__PACKAGE__ . ".$sub_name: Removing the files in '$1' except 'sonuscert.p12'");
        my $newcmd = "find $1 ! -name \'sonuscert.p12\' -type f -exec rm -f {} +";
        $cmd = $newcmd;
    }
    elsif ($cmd =~ /set oam eventLog typeAdmin audit state disabled/i && SonusQA::Utils::greaterThanVersion($self->{APPLICATION_VERSION},'V07.01.00')) {# TOOLS-18769 Skip this cmd for version above 7.1
	$logger->debug(__PACKAGE__ . ".execCmd: Skipping cmd \'$cmd\' as $self->{APPLICATION_VERSION} version is greater than 7.1");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub");
	return ('[ok]');
    }

#TOOLS-18716 - AWS SBC doesn't support IPV6 configurations
    if($cmd =~ /^set\s+addressContext.*(ingressIpPrefix|staticRoute)\s(\S+)/){
      unless($2 =~ /\.|:/){
        $logger->info(__PACKAGE__ . ".$sub_name: $cmd is skipped since IPV6 is not defined");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub");
        return ('[ok]');
      }
    }
    if($cmd =~ /ipAddress\s+ipPort/){
      $logger->info(__PACKAGE__ . ".$sub_name: $cmd is skipped since IP is not defined");
      $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub");
      return ('[ok]');
    }


    if($self->{D_SBC}){ #when the SBC type is D_SBC
        my $flag = 1;
	my @finalResults = ();
        my @dsbc_arr = $self->dsbcCmdLookUp($cmd); 
        my @role_arr = $self->nkRoleLookUp($cmd) if($self->{NK_REDUNDANCY});
        
        foreach my $personality (@dsbc_arr){
            foreach my $index(keys %{$self->{$personality}}){
                my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
                if($self->{NK_REDUNDANCY}){
                    my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'};
                    unless ($personality =~ /OAM/ ) {
                        next unless (grep /$role/i, @role_arr);
                    } else {
                        next unless ($role =~ /active/i)  ;
                    }
                }
                $logger->debug(__PACKAGE__ . ".execCmd: --> Executing '$cmd' for '$alias' ('$personality\-\>$index' object).");
		$self->{$personality}->{$index}->{SKIP_CMDFIX} = $self->{SKIP_CMDFIX}; #TOOLS-18215 To avoid __cmdFix call
		unless (@cmdResults = $self->{$personality}->{$index}->execCmd($cmd, $timeOut)){
		    @finalResults = ();
		    $flag = 0;
		    last;
		}
                $self->{$personality}->{$index}->{"SAVEANDACTIVE"} = 1 if ($self->{OAM} and $cmd =~/^(delete|set).+/) ;
		$logger->debug(__PACKAGE__ . ".execCmd: Executed command for '$alias' ('$personality\-\>$index' object).");
		push(@finalResults,@cmdResults);
            }
            last unless $flag;
        }
        #TOOLS-12478-if the cmd 'delete addressContext ipInterfaceGroup' is successfully executed, we are unsetting the DSBC_CONFIG flag to call the configureSigPortAndDNS() function.
        $self->{CMD_INFO}->{DSBC_CONFIG} = 0 if ($cmd =~ /delete\s+addressContext\s+(\S+)\s+ipInterfaceGroup/i and $flag);
	#Configuring D_SBC Sig port and DNS for different personalities of SBC TOOLS-6098, TOOLS-6220, TOOLS-6322
	if ($cmd =~ /set\saddressContext.+ipInterfaceGroup.+ipInterface.+ceName.*portName\spkt0/i and !$self->{CMD_INFO}->{DSBC_CONFIG}) { #TOOLS-8313 #TOOLS-17487
            unless ($self->configureSigPortAndDNS($cmd)) {
                $logger->error(__PACKAGE__ . ".exexCmd: D_SBC Signaling Port configuration failed.");
                $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving Sub");
                return 0;
            }
        }
	push( @{$self->{CMDRESULTS}}, @finalResults );
	$logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub");
        return @finalResults;
    }

    #TOOLS-18721 On SWE and Cloud platform, mediaProfile cmd is skipped.
    if( $cmd =~ / mediaProfile/g and $self->{SOFT_SBC} ){
        $logger->debug(__PACKAGE__ . ".execCmd: since it is SWE/CLOUD SBC, [$cmd] is skipped");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [1]");
        return ('[ok]'); #execCliCmd( ) has ok/error check so sending [ok] 
    }

    #TOOLS-15429. Checking {ENTERED_DSH} in case of cloud sbc
    if($self->{ENTERED_DSH}){
        $logger->debug(__PACKAGE__ . ".$sub_name: {ENTERED_DSH} flag has been set");
        my $remove_cmd = 1;
        my ($res, @return_result) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$self->{ACTIVE_CE}}, $cmd, 60, undef, $remove_cmd);
        unless($res){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd on 'ACTIVE_CE'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000HELPER-$cmd Execution Failed; ";
            return @return_result; #TOOLS-18509
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Successfully executed the cmd $cmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
        push( @{$self->{CMDRESULTS}}, @return_result );
        (@return_result) ? return @return_result : return ('');
    }
    # TOOLS-13381 - Before executing the command, calling makeReconnection if REDUNDANCY_ROLE is 'STANDBY' and NEW_STANDBY_INDEX is same as the current index.
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->debug(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    my $timestamp = $self->getTime();

    if ( $self->{ENTEREDCLI} ) {
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CLI CMD: $cmd");    
    }
    else { 
        $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
    }
    unless( defined $timeOut) {
        $timeOut = $self->{DEFAULTTIMEOUT};
    }
    my $abortFlag =0;

    my @avoid_us = ('Request Timeout','Stopping user sessions during sync phase\!','Disabling updates \-\- read only access','Enabling updates \-\- read\/write access','Message from.+at');
    my $try = 1;
    EXECUTE:
    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");
          
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command  
    
    $self->{PRIVATE_MODE} = 1 if ($cmd eq 'configure private');

    $cmd = $self->__cmdFix($cmd) unless($self->{SKIP_CMDFIX}); #TOOLS-18215 To avoid __cmdFix call
    unless($cmd){
       $logger->error(__PACKAGE__ . ".execCmd Failed to fix the command");
       $logger->debug(__PACKAGE__. ".execCmd:<-- Leaving sub [0]");
       return ();
    }
    $logger->debug(__PACKAGE__ . ".execCmd newCmd [$cmd]");
    unless ($self->{conn}->print($cmd)) {
        $logger->error(__PACKAGE__ . ".execCmd: Couldn't issue $cmd");
	$logger->debug(__PACKAGE__ . ".execCmd: Session Dump Log is : $self->{sessionLog1}");
	$logger->debug(__PACKAGE__ . ".execCmd: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
        return 0;
    }
    WAITFOR:
    my ($prematch, $match);
    unless (($prematch, $match) = $self->{conn}->waitfor(
                                              -match => $self->{conn}->prompt,
					      -match => '/An IP Peer with the same IP Address exists\. Do you want to continue\?/',
					      -match => '/Enter value in the range of \(0 \.\. 255\)\.\>\):/',
                                              -timeout => $timeOut
                                      )) {
        # Entered due to a timeout on receiving the correct prompt. What reasons would lead to this?
        # Reboot?

        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  UNKNOWN CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  errmsg: ". $self->{conn}->errmsg);
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	$logger->debug(__PACKAGE__ . ".execCmd: Session Dump Log is : $self->{sessionLog1}");
	$logger->debug(__PACKAGE__ . ".execCmd: Session Input Log is: $self->{sessionLog2}");

        if( $self->{conn}->errmsg =~ /pattern match timed-out/) {
            if ( ++$self->{TIMEOUT_COUNTER} == 10 ){
                $logger->error(__PACKAGE__ . "Stopping the feature execution, since we got $self->{TIMEOUT_COUNTER} consecutive \"pattern match timed-out\" errors.");
                &error("Stopping the feature execution, since we got $self->{TIMEOUT_COUNTER} consecutive \"pattern match timed-out\" errors.");
            }
        } else {
            $self->{TIMEOUT_COUNTER} = 0;
        }

        my ($do_reconnect, $re_exec);

        # Fix for TOOLS-4420. Added an option to skip coredump check. Just reconnect and return on failure.
        # User need to set 'RECONNECT_AND_RETURN_ON_FAILURE' before calling execCmd() and unset it after the use.
	if($self->{RECONNECT_AND_RETURN_ON_FAILURE}){
            $logger->debug(__PACKAGE__ . ".execCmd 'RECONNECT_AND_RETURN_ON_FAILURE' is set.");
            $logger->debug(__PACKAGE__ . ".execCmd lastline: ". $self->{conn}->lastline);
	    ($do_reconnect, $re_exec) = (1,1);
        }
        else{
            my $tcid = ($self->{ASAN_BUILD})?"ASAN":"";
            if( grep /IDLE TIMEOUT/, ${$self->{conn}->buffer}){
                $logger->warn(__PACKAGE__ . ".execCmd No coredump found. There was a session idle timeout. ".${$self->{conn}->buffer}." Trying to reconnect..");
                ($do_reconnect, $re_exec) = (1, 1);
            }
            elsif ($self->checkforCore($tcid)){
                $logger->warn(__PACKAGE__ . ".execCmd *****************$cmd execution failed because of core dump*****************");
	            $do_reconnect = 1;
            } 
	}
    if ($self->{ASAN_BUILD}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: SBC is a ASAN build. Checking SBC status");
        if($self->checkAsanBuildFailure()) {
            $logger->debug(__PACKAGE__. ".$sub_name:  ASAN Build failure.");
            $self->{ASAN_BUILD_FAILURE} = 1;
            $main::failure_msg .= "ASAN Build failure; ";
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub []");
            return ();
        }
    }
	if($do_reconnect){
            unless ($self->makeReconnection(-timeToWaitForConn => 15)) {
                $logger->error(__PACKAGE__ . ".execCmd unable to reconnect");
                &error("Unable to reconnect after CMD FAILURE: $cmd");
            }
            $logger->debug(__PACKAGE__ . ".execCmd reconnection made sucessfully");
            unless($re_exec){
                $logger->debug(__PACKAGE__ . ".execCmd <-- Leaving sub []");
                return ();
            }
            if ($self->{PRIVATE_MODE} == 1 and ($cmd ne 'configure private')) {
                $logger->debug(__PACKAGE__ . ".execCmd entering into private mode after the reconnection");
                $logger->error(__PACKAGE__ . ".execCmd unable to run \'configure private\'") unless ($self->{conn}->cmd(String =>"configure private"));
            }
		    $self->{conn}->buffer_empty;
            $logger->debug(__PACKAGE__ . ".execCmd re-executing \'$cmd\' after the reconnection");
            unless (@cmdResults = $self->{conn}->cmd( String =>$cmd, Timeout=>$self->{DEFAULTTIMEOUT})) {
                $logger->error(__PACKAGE__ . ".execCmd \'$cmd\' re-execution failed after the reconnection");
                $abortFlag =1;
            } 
		    else{
                $logger->debug(__PACKAGE__ . ".execCmd re-executed \'$cmd\' successfully after the reconnection");
            }
            
        }
        
    }else{
        $self->{TIMEOUT_COUNTER} = 0;
    }
 # End waitfor

    if($match =~ m/An IP Peer with the same IP Address exists\. Do you want to continue\?/i) {#TOOLS-18718
        unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Proceed\? \[yes,no\]/')) {
	    $logger->warn(__PACKAGE__ . ".execCmd [$self->{OBJ_HOST}] Did not get the expected prompt " . $self->{conn}->lastline);
            $logger->debug(__PACKAGE__ . ".execCmd: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".execCmd: Session Input Log is: $self->{sessionLog2}");

        }
	$self->{conn}->print('yes') if($match =~ m/Proceed\? \[yes,no\]/i);
        goto WAITFOR;
    }
    
    if($match =~ /Enter value in the range of \(0 \.\. 255\)\.\>\):/i && $prematch =~ /Priority of the  Enum Service/i){ #TOOLS-18756
	$self->{conn}->print('0');
	goto WAITFOR;
    }

    @cmdResults = split("\n", $prematch) if ($prematch);

    foreach my $line (@avoid_us) {
	if( ${$self->{conn}->buffer} =~ /$line/i and $try <= 5){
            $logger->debug(__PACKAGE__ . ".execCmd Attempt $try  failed due to \'$line\'. Retrying..");
            $try++;
            goto EXECUTE;
        }
	if ((grep /$line/i, @cmdResults) and ($try <= 5)) {
            $logger->debug(__PACKAGE__ . ".execCmd Attempt $try failed due to \'$line\' in cmd result. waiting ...");
            $try++;
            goto WAITFOR;
	}
    }

    my $lastline = $self->{conn}->lastline;
    chomp $lastline;

    if( $lastline =~ /system deactivation/i ) {
        $logger->debug(__PACKAGE__ . ".execCmd SBC has returned \'$lastline\' ");
        $logger->warn(__PACKAGE__ . ".execCmd  The system was either restarted or switched over. Reconnecting to the SBC..");
        unless ($self->makeReconnection()) {
            $logger->error(__PACKAGE__ . ".execCmd unable to reconnect");
            &error("Unable to reconnect after trying to reconnect due to system deactivation");
        } else {
            $logger->info(__PACKAGE__ . ".execCmd Reconnection successful ");
            unless ( @cmdResults = $self->execCmd( $cmd , $timeOut ) ) {
                $logger->error(__PACKAGE__ . ".execCmd  \'$cmd\' execution failed after the reconnection");
                $logger->warn(__PACKAGE__ . ".execCmd  **ABORT DUE TO CLI FAILURE **");
                $abortFlag =1;
            }
        }
    }
    elsif( $lastline =~ /Timeout detected -- Forcing read\/write access/i ) { #TOOLS-14528
        $logger->warn(__PACKAGE__ . ".execCmd GOT '$lastline' as lastline. CHECK WHETHER IT IS AN ISSUE. Assuming it is a log and waiting for the prompt again to get the actual output.");
        $logger->debug(__PACKAGE__ . ".execCmd Refer TOOLS-14023 for more info.");
        goto WAITFOR;
    }
 
    # Added the following if condition for "request sbx" commands. The output of these commands return the prompt multiple times. As a result only a partial output was getting captured(immediately after the detection of the first prompt). So they need a special treatment.
    if ($cmd =~ q/^request sbx/ ){
        while(1){
            my @gettrail;
            last unless(@gettrail = $self->{conn}->getlines(All => "", Timeout=> 1));
            push (@cmdResults, @gettrail);
        }
    }

    if ( @cmdResults and ((!$self->{ENTEREDCLI} and grep /^\[ok|error\]/i, @cmdResults) or grep /syntax error: unknown command/is, @cmdResults or $cmdResults[$#cmdResults] =~ /^\[error\]/i or $cmdResults[$#cmdResults - 2] =~ /^\[error\]/i)){
        # CLI command has produced an error. This maybe intended, but the least we can do is warn 
        $logger->warn(__PACKAGE__ . ".execCmd  CLI COMMAND ERROR. CMD: \'$cmd\'.\n ERROR:\n @cmdResults");
	if ($cmd =~ /commit/i) {
            $logger->debug(__PACKAGE__ . ".execCmd: Checking if ATS can resolve the error");
            unless ($self->resolveCommitError($last_cmd, \@cmdResults)) {
                $logger->debug(__PACKAGE__ . ".execCmd: ATS is not able to resolve the error");
                $abortFlag = 1;
            }
        }
	else {
	    $abortFlag =1;
	}
    }
    if ($abortFlag) {
        if ( defined $ENV{CMDERRORFLAG} and $ENV{CMDERRORFLAG} ) {
            $logger->warn(__PACKAGE__ . ".execCmd  ABORT_ON_CLI_ERROR ENV FLAG IS POSITIVE - CALLING ERROR ");
            &error("CMD FAILURE: $cmd");
        }
    }

    # Fix for TOOLS-8799. Waiting PSX to become active.
    # Added an option to skip PSX status check. User need to set $ENV{SKIP_PSX_STATUS_CHECK} = 1,  before calling execCmd() and unset it after the use.
    if($self->{REDUNDANCY_ROLE} ne 'STANDBY' and !$ENV{SKIP_PSX_STATUS_CHECK} and $cmd =~ /commit/i and $last_cmd =~ /set\s+system\s+policyServer\s+remoteServer\s+(\S+)\s+mode\s+active/ and $GATEWAY_ID{$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}}){
                $logger->debug(__PACKAGE__. ".$sub_name: Checking whether the PSX is active");
                my $active = 0;
                my @cmd_result_new;
                my $wait = 180; # waiting for max 180 seconds (TOOLS-8799)
                my $error_msg = "PSX status is not Active. Hence terminating";
                $self->leaveConfigureSession;
                while (!$active) {
                        unless (@cmd_result_new = $self->execCmd( "show table system policyServer policyServerStatus" )) {
                                $error_msg = "Show command execution failed.Hence Terminating";
                                last;
                        }
                        if (grep /Active.*/i,@cmd_result_new){
                                $logger->debug(__PACKAGE__. ".$sub_name: Status of PSX is ACTIVE .");
                                $active = 1;
                                last;
                        }
                        else {
                                $logger->debug(__PACKAGE__. ".$sub_name: Status of PSX is NOT ACTIVE ");
                                $wait -= 15;
                                last unless ($wait);

                                $logger->info(__PACKAGE__ . ".$sub_name: Waiting for 15 seconds for PSX status to become Active");
                                sleep 15;
                        }
                }

                &error($error_msg)  unless ($active);
                $self->execCliCmd("configure private");
    }

    chomp(@cmdResults);
    shift @cmdResults if ($prematch); #removes the first line because its cmd

    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array

    push( @{$self->{CMDRESULTS}}, @cmdResults );
#    push( @{$self->{HISTORY}}, "$timestamp :: $cmd" );
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return @cmdResults;
}

=head2  execCliCmd() 

=over

=item DESCRIPTION:

 The function is a wrapper around execCmd that also parses the output to look for SBX5000 CLI specific strings: [ok] and [error]. It will then return 1 or 0 depending on this. In the case of timeout 0 is returned. The CLI output from the command is then only accessible from $self->{CMDRESULTS}. The idea of this function is to remove the parsing for ok and error from every CLI command call. 

=item ARGUMENTS:

 1. The command to be issued to the CLI
 2. Timeout.
 3. string should be matched on command output, Ex -> "Aborted: too many 'system ntp serverAdmin'"

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - [ok] found in output
 0 - [error] found in output or the CLI command timed out.

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

=item EXAMPLE:

 my $result = $obj->execCliCmd( "show table sigtran sctpAssociation" , 10 );

                    OR

 my $result = $obj->execCliCmd( "show table sigtran sctpAssociation" , 10 , "Aborted: too many 'system ntp serverAdmin'");

=back

=cut

sub execCliCmd {

    # Due to the frequency of running this command there will only be log output 
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execCliCmd";
    my ($self,$cmd, $timeOut, $lookForString) = @_;
    my $logger      = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my (@result);
    my $foundstring = 0;

    unless ( @result = $self->execCmd( $cmd , $timeOut ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR. No return information");
        $logger->warn(__PACKAGE__ . ".$sub_name:  **ABORT DUE TO CLI FAILURE **");
        return 0;
     }

    foreach ( @result ) {
        chomp;
        if ( defined $lookForString and /\Q$lookForString\E/i) {
                $logger->info(__PACKAGE__ . ".$sub_name:  $cmd output contains string -> '$lookForString'");
		$foundstring = 1;
                last;
        } elsif ( defined $lookForString and $_ !~ /\Q$lookForString\E/i and $foundstring == 0 and $_ eq $result[ $#result ]) {
                $logger->info(__PACKAGE__ . ".$sub_name:  $cmd output does not contain string -> '$lookForString'");
                $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
		return 0;
        } elsif ( /^\[error\]/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR");
            $logger->warn(__PACKAGE__ . ".$sub_name:  **ABORT DUE TO CLI FAILURE **");
            if( defined $ENV{CMDERRORFLAG} &&  $ENV{CMDERRORFLAG} ) {
                $logger->warn(__PACKAGE__ . ". $sub_name: CMDERRORFLAG flag set -CALLING ERROR ");
                &error("CMD FAILURE: $cmd");
            }
            $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
            return 0;
        }
        elsif ( /^\[ok\]/ ) {
            last;
        }
        elsif ( $_ eq $result[ $#result ] ) {
            # Reached end of result without error or ok
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR: Neither \[error\] or \[ok\] returned from cmd --\n@result");
           $logger->warn(__PACKAGE__ . ".$sub_name:  **ABORT DUE TO CLI FAILURE **");
            if( defined $ENV{CMDERRORFLAG} &&  $ENV{CMDERRORFLAG} ) {
                $logger->warn(__PACKAGE__ . ". $sub_name: CMDERRORFLAG flag set -CALLING ERROR ");
                &error("CMD FAILURE: $cmd");
            }
            $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
            return 0;
        }
    }
    return 1;
}

=head2  leaveConfigureSession 

=over

=item DESCRIPTION:

        This subroutine leaves the Config (private) mode of SBC and sets the PRIVATE_MODE flag as 0

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

	$Sbc_Obj->leaveConfigureSession();

=back

=cut

sub leaveConfigureSession {
    my ($self) = shift;
    my  $sub_name = "leaveConfigureSession";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{'D_SBC'}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&leaveConfigureSession, \%hash);
        if ( $self->{OAM} ) {
            unless($self->doOAMvalidation() ) {
                $logger->error(__PACKAGE__ . ".$sub_name: OAM configuration failed.");
                $retVal = 0 ;
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$retVal]");
        return $retVal;
    }
    if ( $self->{'OAM'} and $self->{'SAVEANDACTIVE'} ) {
        $self->{'SAVEANDACTIVE'} = 0;
        unless ($self->{conn}->cmd( String => "request system admin vsbcSystem saveAndActivate",
                                    Timeout => 100 )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command \"request system admin vsbcSystem saveAndActivate\" ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    my  ( %args ) = @_;

    #TOOLS-15088 - to reconnect to standby before executing command
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Issue exit and wait for either [ok], [error]
    $self->{PRIVATE_MODE} = 0;
    $logger->debug(__PACKAGE__ . ".$sub_name: Clearing the buffer");

    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command 'exit'

    unless ( $self->{conn}->print( "exit no-confirm" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot issue \'exit no-confirm\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000 - Exit command error; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'exit no-confirm\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not match expected prompt after \'exit\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
        return 0;
    }

    if ( $match =~ m/\[ok\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Left private session.");
            # Clearing buffer as if we've matched ok, then the prompt is still left and maybe matched by
            # next call to execCmd
            $self->{conn}->waitfor( -match => $self->{PROMPT} );;
    }
    elsif ( $match =~ m/\[error\]/ ) {
            $logger->debug(__PACKAGE__ . ".$sub_name:  \'exit\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            # Clearing buffer as if we've matched error, then the prompt is still left and maybe matched by
            # next call to execCmd
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            $main::failure_msg .= "UNKNOWN:SBX5000-Exit command error; ";
            return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 doOAMvalidation 

=over

=item DESCRIPTION:

        This subroutine is to validate OAM configuration.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

        $Sbc_Obj->doOAMvalidation();

=back

=cut


sub doOAMvalidation  {
    my ($self) = shift;
    my  $sub_name = "doOAMvalidation";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach my $oam_type ('S_OAM', 'M_OAM','T_OAM') {
        next unless  ($self->{$oam_type} ) ;
        foreach my $instance (keys %{$self->{$oam_type}}){
            if($self->{NK_REDUNDANCY}){
                my $role = $self->{$oam_type}->{$instance}->{'REDUNDANCY_ROLE'};
                next unless ($role =~ /active/i)  ;
            }
            my ( @cmd_results , $oam_revision );
            unless (@cmd_results = $self->{$oam_type}->{$instance}->{conn}->cmd( "show table system activeRevision" )) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to run \'activeRevision\' command on $oam_type\->{$instance}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$oam_type}->{1}->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$oam_type}->{1}->{sessionLog2}");
                $flag = 0;
                last;
            }
            foreach (@cmd_results){
                if (/activeRevision\s*(\d+)\;/){
                    $oam_revision = $1 ;
                    last ;
                }
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: OAM _revision $oam_revision for $oam_type\->{$instance}");

            unless (@cmd_results = $self->{$oam_type}->{$instance}->{CE0LinuxObj}->{conn}->cmd( "/opt/sonus/sbx/tailf/bin/confd_load -P /node/nodeName | xmllint --format - | grep nodeName | sed 's;.*<nodeName>\\(.*\\)</nodeName>.*;\\1;'" )) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to get nodes for  $oam_type\->{$instance}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$oam_type}->{1}->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$oam_type}->{1}->{sessionLog2}");
                $flag = 0;
                last;
            }
            my $sleep_count = 1;
   
            foreach (@cmd_results) {
                my ($node_revision ,@node_cmd_results);
                my $oam_node = $1  if (/(\S+)\s*/) ;
      RETRY:    unless (@node_cmd_results = $self->{$oam_type}->{$instance}->{conn}->cmd( "show table node $oam_node system activeRevision" )) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to get activeRevision number for $oam_node on $oam_type\->{$instance}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{$oam_type}->{1}->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{$oam_type}->{1}->{sessionLog2}");
                    $flag = 0;
                    last;
                }
                foreach (@node_cmd_results){
                    if (/activeRevision\s*(\d+)\;/){
                        $node_revision = $1 ;
                        last ;
                    }
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Node _revision $node_revision for $oam_type\->{$instance}\->$oam_node");
                unless ($oam_revision == $node_revision) {
                    $logger->warn(__PACKAGE__ . ".$sub_name: OAM revision and node revision are not matching for  \'$oam_node\' on $oam_type\->{$instance} ");
                    if ($sleep_count) {
                        $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 15 secs, Nodes activeRevision will be reverfiied after timeout");
                        sleep(15) ;
                        $sleep_count = 0;
                        goto RETRY ;
                    }
                    $flag = 0 ;
                    last;
                }
            }
            if ($flag) {
                $logger->info(__PACKAGE__ . ".$sub_name: Configurations are successfully pushed on all $oam_type\->{$instance} SBCs ");
            }else {
                last;
            }
        }
        last unless ($flag) ;
    }
    if ($flag) {
        $logger->info(__PACKAGE__ . ".$sub_name: Waiting for 5 secs, so that all the configurations will be reflected in SBCs. ");
        sleep(5) ;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
}
=head2  leaveDshLinuxShell 

=over

=item DESCRIPTION:

        This subroutine leaves DSH linux shell of SBC.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

        $Sbc_Obj->leaveDshLinuxShell();

=back

=cut

sub leaveDshLinuxShell {

    my ($self) = shift;
    my  $sub_name = "leaveDshLinuxShell";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&leaveDshLinuxShell, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$retVal]");
        return $retVal;
    }
    #TOOLS-15429. dsh not supported in cloud sbc
    if($self->{ENTERED_DSH}){
        $logger->debug(__PACKAGE__ . ".$sub_name: Unsetting {ENTERED_DSH} flag");
        $self->{ENTERED_DSH} = 0;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    my  ( %args ) = @_ ;

    #TOOLS-15088 - to reconnect to standby before executing command
    if($self->{REDUNDANCY_ROLE} =~ /STANDBY/){
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    my $previous_err_mode = $self->{conn}->errmode("return");

    # Issue exit and wait for either [ok], [error]
    unless ($self->{conn}->print( "exit" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot issue \'exit\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Exit command error; ";
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name:  Executed \'exit\'");

    my ($prematch, $match);

    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/\[ok\]/',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not match expected prompt after \'exit\'.");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name:  Match :$match");
    if ( $match =~ m/linuxadmin/i ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Dsh is in root");

        # Enter one more exit to get out of linux shell

    	unless ($self->{conn}->print( "exit" ) ) {
        	$logger->error(__PACKAGE__ . ".$sub_name: Cannot issue \'exit\'");
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                $main::failure_msg .= "UNKNOWN:SBX5000-Exit command error; ";
        	return 0;
    	} 

        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                               -match => $self->{PROMPT},
                                                             )) {
            $logger->error(__PACKAGE__ . ".$sub_name: Unknown error after typing \exit\'");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
            return 0;
        }
        
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
 
}


=head2  getSystemProcessInfo 

=over

=item DESCRIPTION:

    This function checks if the SBX5000 system is running on the specified CE server.

=item ARGUMENTS:

    1st Arg    - the shell session that connects to the CE server on which the SBX5000 system is running;

=item PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:


=item OUTPUT:

    -1  - function failure; 
    0   - the SBX5000 system is not up;
    1   - the SBX5000 system is up;

=item EXAMPLE:
        $result=SonusQA::SBX5000::SBX5000HELPER::getSystemProcessInfo($shell_session);
        if ( $result == 0 ) {
            $logger->debug(__PACKAGE__ . " ======: The SBX5000 system is not up yet.");
            return 0;
        } elsif ( $result == 1) {
            $logger->debug(__PACKAGE__ . " ======: The SGX system is up.");
            return 0;
        } else {
            $logger->debug(__PACKAGE__ . " ======: Failure in checking the SBX5000 system running status.");
            return 0;
        }

=back

=cut

sub getSystemProcessInfo {

    my ( $self, $numberofrun )=@_;
    my $hashref = [];
    my $sub_name = "getSystemProcessInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Mandatory input: shell session is empty or blank.");
        return -1;
    }
	$hashref = $self;

    my ($cmd_status ,@return_result) =  SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self,'service sbx status');# TOOLS 13145
    unless ($cmd_status){
        $logger->error(__PACKAGE__ . ".$sub_name: command \"service sbx status\" unsuccessful  ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    foreach (@return_result){

      	if(m/^(\w+)\s+(\(pid)\s+(\d+)(\))\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : $3 status: $6");
	    $hashref->{systemprocess}->{$1}->{PID} = $3;					
	    $hashref->{systemprocess}->{$1}->{STATE} = $6;
	}elsif(m/^(\w+)\s+(\(pid)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)(\))\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : $3 status: $9");
            $hashref->{systemprocess}->{$1}->{PID} = $3;
            $hashref->{systemprocess}->{$1}->{STATE} = $9;
	}elsif(m/^(\w+)\s+(\w+)\s+(\w+)/){
	    $logger->debug(__PACKAGE__ . ".$sub_name: process :$1  pid : None status: $3");
	    $hashref->{systemprocess}->{$1}->{PID} = "None";					
	    $hashref->{systemprocess}->{$1}->{STATE} = $3;
	}
    	if (defined($numberofrun)) {
		$self->{$numberofrun}= $hashref;
    	}
    }
    return 1;
}

=head2  execSystemCliCmd 

=over

=item DESCRIPTION:

 This function is a wrapper to execute a system or server admin command through CLI. It checks the (yes/no) after issuing a system command. If the prompt is (yes/no), this function will issue 'yes' and then it will check the [ok] and [error] messages. Note that the screen width should be set to 512, otherwise the '(yes/no)' prompt may be splitted into different lines.

=item ARGUMENTS:

 The system or server admin CLI command.

=item NOTE: 

 None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  0 - fail
  1 - success

=item EXAMPLE:

  For example, to execute a system restart command
  $obj->execSystemCliCmd("request system admin name restart");

=back

=cut

sub execSystemCliCmd {
    my ($self) = shift;
    my ($cmd) = shift;
    my  $sub_name = "execSystemCliCmd";
    my  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{CLOUD_SBC} and $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}) {
        $cmd =~ s/$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}/vsbcSystem/ ;
    }
    if ($self->{D_SBC}) {
        my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
	my @role_arr = $self->nkRoleLookUp($cmd) if ($self->{NK_REDUNDANCY});
        unshift (@_, $cmd);
        my %hash = (
                        'args' => [@_],
                        'types'=> [@dsbc_arr],
			'roles'=> [@role_arr]
                );
        my $retVal = $self->__dsbcCallback(\&execSystemCliCmd, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$retVal]");
        return $retVal;
    }
    my  ( %args ) = @_ ;

    if (exists $self->{REDUNDANCY_ROLE} and $cmd =~ /switchover/){
        $self = $self->getSwitchOverObject();
    }
    elsif($self->{REDUNDANCY_ROLE} =~ /STANDBY/){  #TOOLS-15088 - to reconnect to standby before executing command
        unless($self->__checkAndReconnectStandby()){
            $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
            $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Executing the system command:'$cmd'");
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of the command
    unless ( $self->{conn}->print( $cmd ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue $cmd" );
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	 $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         $main::failure_msg .= "UNKNOWN:SBX5000-$cmd execution failed; ";
         return 0;
    }

    # wait for (yes/no), [ok] or [error].

    my ($prematch, $match);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/(yes|no)[\/,](no|yes)/', #TOOLS-15393
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        if( grep /IDLE TIMEOUT/i, ${$self->{conn}->buffer}){
           $logger->warn(__PACKAGE__ . ".$sub_name: There was a session idle timeout. ".${$self->{conn}->buffer}." Trying to reconnect and then rerun the command..");
           unless ($self->makeReconnection()) {
               $logger->error(__PACKAGE__ . ".$sub_name: unable to reconnect");
               &error("Unable to reconnect after CMD FAILURE: $cmd");
           } else {
               $logger->debug(__PACKAGE__ . ".$sub_name: Reconnection made sucessfully");
               unless ( $self->{conn}->print( $cmd ) ) {
                   $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue $cmd after reconnection" );
		   $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
		   $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                   $main::failure_msg .= "UNKNOWN:SBX5000-$cmd execution failed; ";
                   return 0;
               } else {
                   $logger->debug(__PACKAGE__ . ".$sub_name: \'$cmd\' executed after the reconnection");
                   unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => '/(yes|no)[\/,](no|yes)/', #TOOLS-15393
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                         )) {
                       $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after '$cmd'.");
		       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
		       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                       $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
                       return 0;
                   }
               }
           }
        }else{
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not match expected prompt after '$cmd'.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: prematch and match : $prematch $match");
    if ( $match =~ m/(yes|no)[\/,](no|yes)/ ) { #TOOLS-15393
        $logger->debug(__PACKAGE__ . ".$sub_name:  Matched required prompt.");

	my $promptoption;
	if(defined $args{-prompt}){
	    $promptoption = "yes" if($args{-prompt} =~ /^y(es?)?$/i );
	    $promptoption = "no" if($args{-prompt} =~ /^n(o?)?$/i );
	    unless(defined $promptoption){
	        $logger->warn(__PACKAGE__ . ".$sub_name:  You have not entered an acceptable argument for '-prompt'. Only yes/y/Y/YES or no/n/N/NO are accepted. Entering 'no' and proceeding..");
	        $promptoption = "no";
	    }
	}   
	$promptoption ||= "yes";
        unless ( $self->execCliCmd($promptoption) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  '$promptoption' resulted in error -- \n@{$self->{CMDRESULTS}}");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving Sub [0]");
            return 0;
        }

        my $failure_flag=0;
        foreach ( @{$self->{CMDRESULTS}} ) {
            chomp;
            if( /result\s+failure/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Result failure after typing 'yes'.");
                $failure_flag=1;
            }
            if ( $failure_flag &&  /^reason/ ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  The failure message is:'$_'");
                last;
            }
        }

        if ( $failure_flag ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000-command error; ";
            return 0;
        }
    }
    elsif ( $match =~ m/\[error\]/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not execute '$cmd'.\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $self->{conn}->waitfor( -match => $self->{PROMPT} );
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Didn't match expected prompt. Unknown error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Failed to match prompt; ";
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2  closeConn 

=over

=item DESCRIPTION:

  Overriding the Base.closeConn due to it thinking us using port 2024 means we're on the console.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000  

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    None

=item EXAMPLE:

  $obj->closeConn();


=back

=cut

sub closeConn {
    my $sub = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub Closing SBX5000 connection...");
 
    my ($self) = @_;
    if ($self->{D_SBC}) { #DSBC
        delete $self->{STANDBY_ROOT} if (exists $self->{STANDBY_ROOT});
         my $retVal = $self->__dsbcCallback(\&closeConn);
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
         return $retVal;
    }

    foreach my $ce (@{$self->{ROOT_OBJS}}) {
        next unless $self->{$ce};
        next if ($self->{PARENT}->{NK_REDUNDANCY} and ( $ce eq 'CE1LinuxObj' ) ); #TOOLS-17818 
        $logger->debug(__PACKAGE__ . ".$sub: closing $ce");
        if($self->{$ce}->{conn}){
            $self->{$ce}->{conn}->print("exit");
            $self->{$ce}->{conn}->close;
        }
        delete $self->{$ce};
    }
    if ($self->{conn}) {
        $logger->debug(__PACKAGE__ . ".$sub SBX5000 connection exists ");
        $self->{conn}->print("exit");
        $self->{conn}->close;
	undef $self->{conn}; #this is a proof that i closed the session
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
}

=head2  reconnect 

=over

=item DESCRIPTION:

 Adding this subroutine to handle reconnect D_sbc

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::Base::reconnect

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->reconnect();


=back

=cut

sub reconnect {
    my $self = shift;
    my $sub = "reconnect";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ .".$sub: -->Entered Sub");
    if ($self->{D_SBC}) {
        my %hash = (
                'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&reconnect, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    $logger->debug(__PACKAGE__. ".$sub: Calling Base reconnect()");
    unless (SonusQA::Base::reconnect($self, @_)) {
        $logger->error(__PACKAGE__. ".$sub: Base reconnect failed");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Unable to reconnect; ";
        return 0;
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2  DESTROY 

=over

=item DESCRIPTION:

 Adding this subroutine to handle DESTROY of D_sbc

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

  $obj->DESTROY();


=back

=cut

sub DESTROY {
    my $self = shift;
    my $sub = "DESTROY";
    my $logger;

    if (Log::Log4perl::initialized()) {
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    }else{
      Log::Log4perl->easy_init($DEBUG);
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    }
    $logger->debug(__PACKAGE__ .".$sub: -->Entered Sub");
    if ($self->{D_SBC} and !$self->{NESTED}) {
        my $retVal = $self->__dsbcCallback(\&DESTROY);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[$retVal]");
        return $retVal;
    }

    #TOOLS-76344
    #TOOLS-72075
    if($self->{ASAN_BUILD}) {
        $logger->debug(__PACKAGE__. ".$sub: ASAN build detected adding CE_Node logs to the required log files array $main::log_dir");
        my $timestamp = strftime("%Y%m%d%H%M%S",localtime);
        my $ce_node_log = "CE_NODE_logs"."_"."$timestamp.tar";
        my ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$self->{ACTIVE_CE}},"tar -cvf /tmp/$ce_node_log /var/log/sonus/sbx/asp_saved_logs/normal/");
        unless ($self->storeLogs("$ce_node_log","CE_NODE_LOGS",$main::log_dir,"/tmp") ) {
            $logger->warn(__PACKAGE__ . " $sub:   Failed to store the log file: $ce_node_log.");
        }
        ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$self->{ACTIVE_CE}},"rm -rf /var/log/sonus/sbx/asp_saved_logs/normal/*");
        ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$self->{ACTIVE_CE}},"rm -rf /tmp/*");
    }

    $logger->debug(__PACKAGE__. ".$sub: Calling Base DESTROY()");
    unless (SonusQA::Base::DESTROY($self)) {
        $logger->error(__PACKAGE__. ".$sub: Base DESTROY failed");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Unable to destroy; ";
        return 0;
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2  dsbcCmdLookUp 

=over

=item DESCRIPTION:

 This function will looks for the command in DSBC_LOOKUP.pm file and will finds out in which personalities the command can be run.

=item ARGUMENTS:

 $cmd - Command to be checked.

=item NOTE:

 None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

 LOOKUP_RETURN

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  Array of SBC personalities

=item EXAMPLE:

  For example, to check "show table oam eventLog typeStatus debug" command
  my @sbc_arr = $obj->dsbcCmdLookUp("show table oam eventLog typeStatus debug");

=back

=cut

sub dsbcCmdLookUp {
    my ($self,$cmd) = @_;
    my $sub = "dsbcCmdLookUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ($cmd) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory command is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[0]");
        $main::failure_msg .= "TOOLS:SBX5000-Mandatory command missing; ";
        return 0;
    }


    my @sbc_arr;
    if ($self->{SELECTED_PERSONALITIES} and scalar @{$self->{SELECTED_PERSONALITIES}}){
        @sbc_arr = @{$self->{SELECTED_PERSONALITIES}};
        $logger->debug(__PACKAGE__ . ".$sub: SELECTED_PERSONALITIES : @sbc_arr");
    }elsif(exists $self->{S_SBC}){
            my %look_up = %SonusQA::SBX5000::DSBC_LOOKUP::cmd_list;
            foreach my $personality (keys %look_up){
                foreach my $common_cmd (keys %{$look_up{$personality}}){
                    my $to_match = $common_cmd.'(.+)?\s('.join('|',@{$look_up{$personality}{$common_cmd}}).')';
                    if($cmd =~ /$to_match/i){
                        $logger->debug(__PACKAGE__. ".$sub: The cmd '$cmd' can be run in '$personality'");
                        push (@sbc_arr,$personality);
                        last;
                }
            }
        }

    }
    unless (@sbc_arr){
        $logger->debug(__PACKAGE__. ".$sub: The cmd '$cmd' can be run in all three personalities.") unless($self->{OAM}) ;
        @sbc_arr = @{$self->{PERSONALITIES}};
        #@sbc_arr = ('S_SBC', 'M_SBC', 'T_SBC');
    }
    if ($self->{OAM} and $cmd =~/^(delete|set|commit|config|.+saveAndActivate|.+restoreRevision)/) {
        my @oam_arr = ();
        foreach (@sbc_arr) {
            if ( /(S|M|T)_SBC/) {
                push (@oam_arr, $1."_OAM" );
            }
        }
        @sbc_arr = @oam_arr ;
    }
    $logger->debug(__PACKAGE__. ".$sub: The cmd '$cmd' runs on these @sbc_arr personalities .") if($self->{OAM}) ;
    $self->{LOOKUP_RETURN} = \@sbc_arr;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
    return @sbc_arr;
}

=head2  nkRoleLookUp 

=over

=item DESCRIPTION:

 This function will look for the command in DSBC_LOOKUP.pm file and will finds out in which roles the command can be run.

=item ARGUMENTS:

 $cmd - Command to be checked.

=item NOTE:

 None

=item PACKAGE:

 SonusQA::SBX5000

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

  Array of roles(ACTIVE, STANDBY or both)

=item EXAMPLE:

  For example, to check "show table oam eventLog typeStatus debug" command
  my @sbc_arr = $obj->nkRoleLookUp("show table oam eventLog typeStatus debug");

=back

=cut

sub nkRoleLookUp {
    my ($self,$cmd) = @_;
    my $sub = "nkRoleLookUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ($cmd) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory command is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[0]");
        $main::failure_msg .= "TOOLS:SBX5000-Mandatory command missing; ";
        return 0;
    }

    my %look_up = %SonusQA::SBX5000::DSBC_LOOKUP::cmd_list_nk_role;

    my (@sbc_arr);
    if ($cmd =~ /request system admin.+switchover/i) {
	@sbc_arr = ('STANDBY');
    }
    else {
	foreach my $role (keys %look_up){
            my $to_match = join('|',@{$look_up{$role}});
            if($to_match and $cmd =~ /$to_match/i){
                $logger->debug(__PACKAGE__. ".$sub: The cmd '$cmd' can be run in '$role'");
                push (@sbc_arr,$role);
                last;
            }
	}
    }
    unless (@sbc_arr){
        $logger->debug(__PACKAGE__. ".$sub: The cmd '$cmd' can be run in both active and standby.");
        @sbc_arr = ('ACTIVE', 'STANDBY');
    }
    $self->{NK_ROLE_LOOKUP_RETURN} = \@sbc_arr; #storing the roles
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
    return @sbc_arr;
}

=head2  __dsbcCallback 

=over

=item DESCRIPTION:

    This function calls the calling function for all personalities of sbc type.
    This is a private function.

=item ARGUMENTS:

    1st Arg    - The function reference of the calling function [ Mandatory ]
    2nd Arg    - A hash reference which cantains all the arguments of the calling function and if a cmd has to be run, then, SBC personalities [ Mandatory ]
                                -check_anyone = 1 #TOOLS-12485-if any one element of DSBC personality (S/M/T) returns success(1),then fucntion call should be success(1)

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
    my %hash = (
                'args' => [@_],
                'types' => [@dsbc_arr]
        );

    my $retVal = $self->__dsbcCallback(\&wind_Up, \%hash);

=back

=cut

sub __dsbcCallback {
    my ($self, $function, $hash) = @_;
    my $sub_name = "__dsbcCallback()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ($function) {
        $logger->info(__PACKAGE__ .".$sub_name: Mandatory function reference is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        $main::failure_msg .= "TOOLS:SBX5000-Mandatory function reference missing; ";
        return 0;
    }

    my $function_name = sub_name($function);
    unless ( $hash->{types} ){
#if we already know, where to run the cmds, give $self->{SELECTED_PERSONALITIES} array to skip the dsbcCmdLookUp
        @{$hash->{types}} = ($self->{SELECTED_PERSONALITIES} and scalar @{$self->{SELECTED_PERSONALITIES}}) ? @{$self->{SELECTED_PERSONALITIES}} : @{$self->{PERSONALITIES}};  #PERSONALITIES will be set in new(), eg- S_SBC, M_SBC | I_SBC ;
        if ( $self->{OAM} ) {
            if ($oam_functions{$function_name} ){
                $hash->{types} = ['S_OAM', 'M_OAM', 'T_OAM'] ;
            } elsif ( $oam_sbc_functions{$function_name}) {
                @{$hash->{types}} = ( ("S_OAM", "M_OAM", "T_OAM"), @{$hash->{types}} ) ;
            }
        }
    }

    my $result = 0;
    $hash->{check_anyone} ||= 0 ;
    foreach my $sbcType (@{$hash->{types}}){
	next unless($self->{$sbcType}); #moving on , if the personality is not part of the given DSBC - TOOLS-13351.
        foreach my $instance (keys %{$self->{$sbcType}}){
	    $self->{$sbcType}->{$instance}->{SKIP_CMDFIX} = $self->{SKIP_CMDFIX} if(exists $self->{SKIP_CMDFIX} );  #TOOLS-75736	    
            my $aliasName = $self->{$sbcType}->{$instance}->{'OBJ_HOSTNAME'};
            if ( $self->{NK_REDUNDANCY} ) {
                my $role = $self->{$sbcType}->{$instance}->{REDUNDANCY_ROLE};
                if ($sbcType =~ /OAM/ and $function_name ne "makeReconnection" ) {
                    next unless($role =~ /active/i);                       
                } else {
		    $hash->{roles} ||= ['ACTIVE', 'STANDBY'];
                    next unless (grep /$role/i, @{$hash->{roles}});
                }
            }
            $logger->debug(__PACKAGE__ .".$sub_name: '$aliasName' ('$sbcType\-\>$instance' object)");
            unless ($function->($self->{$sbcType}->{$instance}, @{$hash->{args}})) {
                $logger->debug(__PACKAGE__ .".$sub_name: returned 0 for '$aliasName' ('$sbcType\-\>$instance' object)");
                $result = 0;
                last unless ($hash->{check_anyone});#if check_anyone flag is enabled, dont last if function call failed.
            }else{
	         $result = 1;
		 last if ($hash->{check_anyone});#if check_anyone flag is enabled, last if function call passed.
	    }
        }
#if both result and check_anyone flag value is same we'll last else continue.
        last if (($result == $hash->{check_anyone} ) );
        
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$result]");
    return $result;
}

=head2  clusterConfigForLocalDns 

=over

=item DESCRIPTION:

    This function will get the MGMT and PKT ip from M_SBC and T_SBC and do the DSBC Cluster configurations for local DNS.

=item ARGUMENTS:

    1st Arg    - addContextName
    2nd Arg    - ipInterfaceGroupName
    3rd Arg    - ipInterfaceName

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ($dsbcObj->clusterConfigForLocalDns($addContextName, $ipInterfaceGroupName, $ipInterfaceName) {
        $logger->debug(__PACKAGE__ . ".$sub_name: D_SBC Cluster Configuration failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

=back

=cut

sub clusterConfigForLocalDns {
 my ($self, $addContextName, $ipInterfaceGroupName, $ipInterfaceName) = @_;
    my $sub_name = "clusterConfigForLocalDns";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entering Sub");

    my $pktIpCmd = "show status addressContext $addContextName ipInterfaceGroup $ipInterfaceGroupName ipInterfaceStatus";
    my $mgmtIpCmd = "show status system mgmtIpInterfaceGroup mgmtIpInterface";

    my %cmdHash;
    my $dnsGroup = "local";
    my $ret = 1;

    # For normal DSBC, not sure how it works for multiple S/M/T, so taking only first instance
    # Ideally going forward it will be N:K
    my @indexes = (1);
    my @types = ($self->{OAM}) ? ("M_OAM", "T_OAM") : ("M_SBC", "T_SBC") ;

    foreach my $type (@types) {
        next unless($self->{$type}) ;
        (my $temp_type = $type) =~s/_/-/; #ideally hostname should not have '_'. But our $type has '_', e.g: M_SBC
        my $localRecord = $type."-test";
        my $groupName = "lbs.$temp_type.com";
        my $clusterType = ($type eq 'T_SBC') ? 'dsp' : 'policer';

        @indexes = keys %{$self->{$type}} if($self->{NK_REDUNDANCY});
        foreach my $index (@indexes){
            next unless($self->{$type}->{$index});
            if($self->{OAM} and $self->{NK_REDUNDANCY}){
                my $role = $self->{$type}->{$index}->{'REDUNDANCY_ROLE'};
                next unless ($role =~ /active/i)  ;
            } 
            my $obj = $self->{$type}->{$index};
            my $alias = $obj->{OBJ_HOSTNAME};

            $logger->debug(__PACKAGE__ . ".$sub_name: Executing state enabled cmd for $alias ($type -> $index)");
            unless ($obj->execCommitCliCmd("set addressContext $addContextName ipInterfaceGroup $ipInterfaceGroupName ipInterface $ipInterfaceName mode inService state enabled")) {
                $logger->error(__PACKAGE__ . ".$sub_name: <-- state enabled cmd for $alias ($type -> $index) failed");
                $ret = 0;
                last;
            }

            $logger->debug(__PACKAGE__ . ".$sub_name: leaving configure session for $alias ($type -> $index) as show commands has to be run in cli mode");
            unless ($self->leaveConfigureSession()) {
                $logger->error(__PACKAGE__ . ".$sub_name: <-- Not able to leave conf session for $alias ($type -> $index)");
                $ret = 0;
                last;
            }
            if ($self->{OAM}) {
                my $sbc_type = ($type =~ /M_OAM/)? "M_SBC" : "T_SBC" ;
                my $sbc_index = 1;
                if ($self->{NK_REDUNDANCY}){ 
                    foreach $sbc_index (keys %{$self->{$sbc_type}}){
                        my $role = $self->{$sbc_type}->{$sbc_index}->{'REDUNDANCY_ROLE'};
                        next unless ($role =~ /active/i)  ;
                        last;
                    }
                }
                $obj = $self->{$sbc_type}->{$sbc_index};
            }
            foreach my $cmd ($pktIpCmd, $mgmtIpCmd) {
                my (@ipv4, @ipv6) ;

                if($obj->{CLOUD_SBC}){
                    my @result;
                    unless (@result = $obj->execCmd($cmd)) {
                        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute '$cmd' for $alias ($type -> $index)");
                        $ret = 0;
                        last;
                    }
                    foreach (@result) {
                        push (@ipv4, $1) if (($_ =~ /fixedIpV4\s+(.*);/i) and ($_ !~ /fixedIpV4\s+(0\.){3}0/));
                        push (@ipv6, $1) if (($_ =~ /fixedIpV6\s+(.*)\;/) and ($_ !~ /fixedIpV6\s+\:\:\;/));
                    }
                }else{
#TOOLS-11545-For HW SBC , ip's should be picked from TMS (coz, the cmd o/p differs for HW and cloud SBC)
                    my $attribute = ($cmd =~ /addressContext/)?('PKT_NIF'):('MGMTNIF');
                    push (@ipv4,$obj->{TMS_ALIAS_DATA}->{$attribute}->{1}->{IP})if($obj->{TMS_ALIAS_DATA}->{$attribute}->{1}->{IP});
                    push (@ipv6,$obj->{TMS_ALIAS_DATA}->{$attribute}->{1}->{IPV6})if($obj->{TMS_ALIAS_DATA}->{$attribute}->{1}->{IPV6});
                }

                my (@ip, $dType);
                if (@ipv4) {
                    @ip = @ipv4;
                    $dType = 'a';
                }
                else {
                    @ip = @ipv6;
                    $dType = 'aaaa';
                }
              if (scalar @ip) {
                unless ($cmd =~ /addressContext/) {
                    if (@ipv6 and ($dType ne 'aaaa')) {
                        @ip = @ipv6;
                        $dType = 'aaaa';
                    }
                    push(@{$cmdHash{$type}}, "set addressContext $addContextName dnsGroup $dnsGroup localRecord $localRecord hostName $groupName data ". ($index - 1) ." ipAddress $ip[0] type $dType priority 0 state enabled");
                    if ($obj->{HA_SETUP} and ! $self->{NK_REDUNDANCY}){ #Tools-8480
                        push(@{$cmdHash{$type}}, "set addressContext $addContextName dnsGroup $dnsGroup localRecord $localRecord hostName $groupName data 1 ipAddress $ip[1] type $dType priority 0 state enabled");
                    }
                }
                else {
                    $logger->debug(__PACKAGE__ . ".$sub_name: NK_REDUNDANCY: $self->{NK_REDUNDANCY}, REDUNDANCY_ROLE: $obj->{'REDUNDANCY_ROLE'}");
                    if(!$self->{NK_REDUNDANCY} or $obj->{'REDUNDANCY_ROLE'} eq 'ACTIVE'){
                        my $cmd_type = ($self->{OAM}) ? "S_OAM" : "S_SBC" ;
                        push(@{$cmdHash{$cmd_type}}, "set addressContext $addContextName dnsGroup $dnsGroup localRecord $localRecord hostName sbc01.$temp_type.com data ". ($index - 1) ." ipAddress $ip[0] type $dType priority 0 state enabled");
                    }
                }
              }
            }
            last unless($ret);
            $logger->debug(__PACKAGE__ . ".$sub_name: Entering private session for $alias ($type -> $index)");
            unless ($self->enterPrivateSession()) {
                $logger->error(__PACKAGE__ . ".$sub_name: <-- Error entering private session for $alias ($type -> $index)");
                $ret = 0;
                last;
            }
        }
        last unless($ret);
        if(exists $cmdHash{$type}){
            push(@{$cmdHash{$type}}, "set system loadBalancingService groupName $groupName");
            my $cmd_type = ($self->{OAM}) ? "S_OAM" : "S_SBC" ;
            push(@{$cmdHash{$cmd_type}}, "set system dsbc cluster type $clusterType dnsGroup $dnsGroup fqdn sbc01.$temp_type.com state enabled");
        }
    }
    if($ret){
        ($self->{OAM})? push (@types, "S_OAM" ):push (@types, "S_SBC" ); 
        foreach my $type (@types) {
            next unless($self->{$type}) ;
            @indexes = keys %{$self->{$type}} if($self->{NK_REDUNDANCY});
            foreach my $index (@indexes){
                next unless($self->{$type}->{$index});
                if($self->{OAM} and $self->{NK_REDUNDANCY}){
                    my $role = $self->{$type}->{$index}->{'REDUNDANCY_ROLE'};
                    next unless ($role =~ /active/i)  ;
                }
                my $obj = $self->{$type}->{$index};
                my $alias = $obj->{OBJ_HOSTNAME};
                $logger->debug(__PACKAGE__ . ".$sub_name: Executing the DNS Configuration Commands for $alias ($type -> $index)");
                unless ($obj->execCommitCliCmd(@{$cmdHash{$type}})){
                    $logger->error(__PACKAGE__ . ".$sub_name: D_SBC Cluster configuration failed for $alias ($type -> $index)");
                    $ret = 0;
                    last;
                }
            }
            last unless($ret);
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
    return $ret;
}

=head2  clusterConfigForExternalDns 

=over

=item DESCRIPTION:

    This function will get the MGMT and PKT ip from M_SBC and T_SBC and do the DSBC Cluster configurations for External DNS.

=item ARGUMENTS:

    1st Arg    - addContextName
    2nd Arg    - ipInterfaceGroupName
    3rd Arg    - ipInterfaceName

=item PACKAGE:

    SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ($dsbcObj->clusterConfigForExternalDns($addContextName, $ipInterfaceGroupName, $ipInterfaceName) {
        $logger->debug(__PACKAGE__ . ".$sub_name: D_SBC Cluster Configuration failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

=back

=cut

sub clusterConfigForExternalDns {
    my ($self, $addContextName, $ipInterfaceGroupName, $ipInterfaceName) = @_;
    my $sub_name = "clusterConfigForExternalDns";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entering Sub");

    my $pktIpCmd = "show status addressContext $addContextName ipInterfaceGroup $ipInterfaceGroupName ipInterfaceStatus";
    my $mgmtIpCmd = "show status system mgmtIpInterfaceGroup mgmtIpInterface";

    my ($dnsObj, %ipHash, @S_Sbc_cmds);
    unless ($dnsObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $self->{TMS_ALIAS_DATA}->{DNS}->{1}->{NAME}, -sessionLog => 1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: --> Could not create DNS object");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        return 0;
    }

    my $dnsGroup = "SWeDNS";
    my $dnsIp = 0;
    my ($gateway_ip, $next_hop);
    my @cmds = ("set addressContext $addContextName dnsGroup $dnsGroup", "set addressContext $addContextName dnsGroup $dnsGroup server $dnsGroup ipAddress $dnsIp", "set addressContext $addContextName dnsGroup $dnsGroup type ip interface $ipInterfaceGroupName", "set addressContext $addContextName dnsGroup $dnsGroup server $dnsGroup state enabled");
    my @types = ($self->{OAM}) ? ("M_OAM", 'S_OAM', "T_OAM") : ('M_SBC', 'S_SBC', 'T_SBC') ;
    foreach my $type (@types) {
        my $type1 = $type;
        $type1 =~ s/\_//g; #$type1 is $type without underscore. As underscore are not allowed in names in DNS Server.
        my $extraData;
        next unless(exists $self->{$type});
        my $alias = $self->{$type}->{OBJ_HOSTNAME};
        #$logger->debug(__PACKAGE__ . ".$sub_name: keys %{$self->{$type}}" . Dumper(keys %{$self->{$type}}));
        #$logger->debug(__PACKAGE__ . ".$sub_name: self type dump %{$self->{$type}}" . Dumper( $self->{$type}));
        foreach my $index (keys %{$self->{$type}}){
            my $obj = $self->{$type}->{$index};
            

            $logger->debug(__PACKAGE__ . ".$sub_name: Executing state enabled cmd for $alias ($type) $index");
            unless ($obj->execCommitCliCmd("set addressContext $addContextName ipInterfaceGroup $ipInterfaceGroupName ipInterface $ipInterfaceName mode inService state enabled")) {
                $logger->error(__PACKAGE__ . ".$sub_name: State enabled cmd for $alias ($type) $index failed");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }
            
           
	        $logger->debug(__PACKAGE__ . ".$sub_name: Executing static route cmd for $alias ($type) $index");
            if( defined $dnsObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6} )
            {
                $next_hop = '::';
                $gateway_ip = $obj->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{DEFAULT_GATEWAY_V6};
            }else
            {
                $next_hop = '0.0.0.0';
                $gateway_ip = $obj->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{DEFAULT_GATEWAY};
            }
                
            #$logger->debug(__PACKAGE__ . ".$sub_name: \$obj->{TMS_ALIAS_DATA}" .Dumper($obj->{TMS_ALIAS_DATA}));
            unless ($obj->execCommitCliCmd("set addressContext $addContextName staticRoute $next_hop 0 $gateway_ip $ipInterfaceGroupName $ipInterfaceName preference 100")) {
                $logger->error(__PACKAGE__ . ".$sub_name: Static route cmd for $alias ($type) $index failed");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
		        return 0;
            }

            $logger->debug(__PACKAGE__ . ".$sub_name: leaving Conf session for $alias ($type) $index as show commands has to be run in cli mode");
            unless ($obj->leaveConfigureSession()) {
                $logger->error(__PACKAGE__ . ".$sub_name: Not able to leave conf session for $alias ($type) $index");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }

            #Get the pkt and mgmt ip for T_SBC and M_SBC
            foreach my $cmd ($pktIpCmd, $mgmtIpCmd) {
                next if($obj->{REDUNDANCY_ROLE} eq 'STANDBY' and $cmd eq $pktIpCmd);
                my (@result, @ipv4, @ipv6);
                $logger->debug(__PACKAGE__ . ".$sub_name: Executing '$cmd' for $alias ($type) $index");
                unless (@result = $obj->execCmd($cmd)) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: $type $index cmd result is " . Dumper(\@result));

                foreach (@result) {
                    push (@ipv4, $1) if (($_ =~ /fixedIpV4\s+(.*);/i) and ($_ !~ /fixedIpV4\s+(0\.){3}0/));
                    push (@ipv6, $1) if (($_ =~ /fixedIpV6\s+(.*)\;/) and ($_ !~ /fixedIpV6\s+\:\:\;/));
                }
            

                my $network = ($cmd =~ /addressContext/) ? 'PKT' : 'MGMT';
            

                if (@ipv6) {
                    $ipHash{$type}{$network}{ips}{$index} = \@ipv6;
                    $ipHash{$type}{$network}{dns_type} = 'AAAA';
                }
                else {
                    $ipHash{$type}{$network}{ips}{$index} = \@ipv4;
                    $ipHash{$type}{$network}{dns_type} = 'A';
                }
            }

            $logger->debug(__PACKAGE__ . ".$sub_name: ipHash is ".Dumper(\%ipHash));
        
            #add DNS Record for M_SBC and T_SBC
            $extraData .= "," if $extraData;
            $extraData .= $type1."lbs IN $ipHash{$type}{MGMT}{dns_type} $ipHash{$type}{MGMT}{ips}{$index}[0]" if $ipHash{$type}{MGMT}{ips}{$index}[0];

            $extraData .= ",$type1 IN $ipHash{$type}{PKT}{dns_type} $ipHash{$type}{PKT}{ips}{$index}[0]" if $ipHash{$type}{PKT}{ips}{$index}[0];
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: extra data is $extraData");
        
        $dnsIp = ($ipHash{$type}{PKT}{ips}{1}[0] =~ /:/) ? $dnsObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6} : $dnsObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
        
        my $domain_name = $dnsObj->{TMS_ALIAS_DATA}->{DNS}->{1}->{DOMAIN} || $ipHash{$type}{PKT}{ips}{1}[0];
        $domain_name =~ s/\:|\.com$//g;
        my %dnsHash = (
                        -domainName     => $domain_name.".com",
                        -nameServerHost => $dnsObj->{TMS_ALIAS_DATA}->{DNS}->{1}->{NAME},
                        -nameServerIp   => $dnsIp,
                        -aRecords       => '0.0.0.0,0::0',
                        -extraData      => $extraData,
                        -nameServerUser => 'hostmaster',
                        -zoneFile       => "forward.".$domain_name
        );
        $logger->debug(__PACKAGE__ . ".$sub_name: Dns hash is ".Dumper(\%dnsHash));
        unless ($dnsObj->addDnsRecord(%dnsHash)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Not able to add DNS record for $alias ($type)");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
        
        foreach my $index (keys %{$self->{$type}}){
            my $obj = $self->{$type}->{$index};
            #Entering private session
            $logger->debug(__PACKAGE__ . ".$sub_name: Entering private session for $alias ($type) $index");
            unless ($obj->enterPrivateSession()) {
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Error entering private session for $alias ($type) $index");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
             }

            #DNS and load balacing commands for M_SBC and T_SBC
            my @cmdArray = ("set system loadBalancingService groupName ".$type1."lbs.$domain_name.com");
            unshift (@cmdArray, @cmds);
            $cmdArray[1] = "set addressContext $addContextName dnsGroup $dnsGroup server $dnsGroup ipAddress $dnsIp";
            $logger->debug(__PACKAGE__ . ".$sub_name: cmds - ".Dumper (\@cmdArray));

            $logger->debug(__PACKAGE__ . ".$sub_name: Executing configure Dns and load balancing commands for $alias ($type) $index");
            unless ($obj->execCommitCliCmd(@cmdArray)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Not able to execute configure Dns and load balancing commands for $alias ($type) $index");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }

            if(defined $self->{REDUNDANCY_ROLE} && $self->{REDUNDANCY_ROLE} eq 'ACTIVE')
            {
                $logger->debug(__PACKAGE__ . ".$sub_name: leaving Conf session for $alias ($type) as sub digAndgetDnsData enters the private session");
                unless ($obj->leaveConfigureSession()) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Not able to leave conf session for $alias ($type) $index");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                    return 0;
                }
    
                #dig and check if dns is being resolved
                my %digHash = (
                                -dnsData        => ["dig ${type1}lbs.$domain_name.com $dnsGroup ".lc $ipHash{$type}{PKT}{dns_type}],
                                -addressContext => $addContextName,
                                -dnsGroup       => $dnsGroup
                );
                unless ($obj->digAndgetDnsData(%digHash)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Not able to get Dns data after dig for $alias ($type) $index");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                    return 0;
                }

                $logger->debug(__PACKAGE__ . ".$sub_name: Entering private session for $alias ($type) $index");
                unless ($obj->enterPrivateSession()) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Error entering private session for $alias ($type) $index");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                    return 0;
                }
            }
        }
        #Gathering S_SBC commands
        my $cluster = (($type =~ /M_SBC/) ? "policer" : "dsp");
        push (@S_Sbc_cmds, "set system dsbc cluster type $cluster dnsGroup $dnsGroup fqdn ".$type1.".$domain_name.com state enabled");
    }

    #Configure Dns on S_SBC with policier and dsp
    unshift (@S_Sbc_cmds, @cmds);
    $S_Sbc_cmds[1] = "set addressContext $addContextName dnsGroup $dnsGroup server $dnsGroup ipAddress $dnsIp";
    $logger->debug(__PACKAGE__ . ".$sub_name: cmds - ".Dumper (\@S_Sbc_cmds));

    my $cmd_type = ($self->{OAM}) ? "S_OAM" : "S_SBC" ;
    my $sObj = $self->{$cmd_type}->{1};
    unless ($sObj->execCommitCliCmd(@S_Sbc_cmds)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to execute configure Dns commands for $sObj->{OBJ_HOSTNAME} ($cmd_type)");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

# TOOLS-8184 & TOOLS-12508

=head2  cmd 

=over

=item DESCRIPTION:

 Added below subroutine 'cmd' to make the suites work for d-sbc, if the feature pm is using {conn} object directly to execute commands.

=item ARGUMENTS:

 Mandatory :

	- command to execute.

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=back

=cut

sub cmd{
    my ($self, @args) = @_;
    my $sub = "cmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my %arg;
    if(@args > 1){
        %arg = @args;
    }
    else{
        $arg{String} = $args[0];
    }

    $logger->debug(__PACKAGE__ . ".$sub: arg: ". Dumper(\%arg));

    my @finalResults = ();
    my $dsbc_ce = $self->{DSBC_CE};
    unless($dsbc_ce){ #we need to run CLIs, else in root session
        $logger->debug(__PACKAGE__ . ".$sub: Running command in CLI");
        unless(@finalResults = $self->execCmd($arg{String}, $arg{Timeout})){
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute $arg{String} in D-SBC");
             $main::failure_msg .= "UNKNOWN:SBX5000-$arg{String} execution failed; ";
        }
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
        return @finalResults;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Running command in root sessions");
    # for shell commands
    $self = $self->{DSBC_OBJ};

    my $role_from_user = ($dsbc_ce =~ /(active|CE0LinuxObj)/i) ? 'ACTIVE' : 'STANDBY'; #possible values for dsbc_ce is ACTIVE_CE or STAND_BY
    my $flag = 1;
    my @dsbc_arr = $self->dsbcCmdLookUp($arg{String});

    foreach my $personality (@dsbc_arr){
        foreach my $index(keys %{$self->{$personality}}){
            my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
            # TOOLS-12508 - some times they call directly with CE0LinuxObj / CE1LinuxObj, then we don't need to find the which LinuxObj is ACTIVE_CE / STAND_BY
            my $linux_obj_name = ($dsbc_ce=~/LinuxObj/) ? $dsbc_ce : $self->{$personality}->{$index}->{$dsbc_ce};

            my @cmdResults;
            if($self->{NK_REDUNDANCY}){
                my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'};
		next unless ($role_from_user =~ /$role/i);
            }
            $logger->debug(__PACKAGE__ . ".$sub: Executing '$arg{String}' in '$linux_obj_name' ($dsbc_ce) for '$alias' ('$personality\-\>$index' object).");

	    my $obj = $self->{$personality}->{$index}->{$linux_obj_name};
            unless (@cmdResults = $obj->{conn}->cmd(%arg)){
                @finalResults = ();
                $flag = 0;
    		$logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $obj->{conn}->errmsg);
		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $obj->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $obj->{sessionLog2}");
                last;
            }
            $logger->debug(__PACKAGE__ . ".$sub: Executed '$arg{String}' for '$alias' ('$personality\-\>$index' object).");
            push(@finalResults,@cmdResults);
        }
        last unless $flag;
    }
    $self->{CMD_INFO}->{DSBC_CONFIG} = 0 if ($arg{String} =~ /clearDBs\.sh/i); #tools-8478, to make dsbc configuration after clear db

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
    return @finalResults;
}

=head2  print 

=over

=item DESCRIPTION:

 Added below subroutine 'print' to make the suites work for d-sbc, if the feature pm is using {conn} object directly to execute commands.

=item ARGUMENTS:

 Mandatory :

	- command to execute.

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=back

=cut

sub print{
    my ($self, $cmd) = @_;
    my $sub = "print";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $dsbc_ce = $self->{DSBC_CE}; #Possible values for $dsbc_ce is ACTIVE_CE or STAND_BY
    $self = $self->{DSBC_OBJ}  if($dsbc_ce);

    my $ret = 1;
    my $temp_self;

    my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
    my @role_arr;
    if ($self->{NK_REDUNDANCY}) {
        if ($dsbc_ce) { # for root session
            @role_arr = ($dsbc_ce =~ /(active|CE0LinuxObj)/i) ? ('ACTIVE') : ('STANDBY'); # Possible values for role_arr is ACTIVE and STANDBY
	        $self->{NK_ROLE_LOOKUP_RETURN} = \@role_arr;
	    }
	    else {
	        @role_arr = $self->nkRoleLookUp($cmd); 
	    }
    }
    foreach my $personality (@dsbc_arr){
        foreach my $index(keys %{$self->{$personality}}){
            my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
            my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'}; #Possible value for role is active or standby
            if(@role_arr){
                next unless (grep /$role/i, @role_arr);
            }

            if($dsbc_ce){ #root session
                # TOOLS-12508 - some times they call directly with CE0LinuxObj / CE1LinuxObj, then we don't need to find the which LinuxObj is ACTIVE_CE / STAND_BY
                my $linux_obj_name = ($dsbc_ce=~/LinuxObj/) ? $dsbc_ce : $self->{$personality}->{$index}->{$dsbc_ce};
                $logger->debug(__PACKAGE__ . ".$sub: Executing '$cmd' in '$linux_obj_name' ($dsbc_ce) for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index}->{$linux_obj_name};
            }
            else{ #cli session
                $logger->debug(__PACKAGE__ . ".$sub: Executing '$cmd' in CLI session for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index};
                #TOOLS-15088 - to reconnect to standby before executing command
                if($role =~ /STANDBY/){
                    unless($temp_self->__checkAndReconnectStandby()){
                        $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
                        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
                        return 0;
                    }
                }

            }

            unless ($temp_self->{conn}->print($cmd)){
                $logger->error(__PACKAGE__ . ".$sub: Failed to send '$cmd' for '$alias' ('$personality\-\>$index' object).");
                $ret = 0;
                $main::failure_msg .= "UNKNOWN:SBX5000-$cmd execution failed; ";
                last;
            }
            $logger->debug(__PACKAGE__ . ".$sub: Successfully sent '$cmd' for '$alias' ('$personality\-\>$index' object).");
        }
        last unless $ret;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
    return $ret;
}

=head2  waitfor 

=over

=item DESCRIPTION:

 Added below subroutine 'waitfor' to make the suites work for d-sbc, if the feature pm is using {conn} object directly to execute commands.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    success - match and prematch

=back

=cut

sub waitfor{
    my ($self, %arg) = @_;
    my $sub = "waitfor";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: arg : ". Dumper(\%arg));

    my $dsbc_ce = $self->{DSBC_CE};
    $self = $self->{DSBC_OBJ}  if($dsbc_ce);

    my ($final_prematch, $final_match, $prematch, $match) = ('','','','');
    my $ret = 1;
    my $temp_self;

    my @dsbc_arr = @{$self->{LOOKUP_RETURN}}; #to get what are the sbcs the last print() has run
    $logger->debug(__PACKAGE__ . ".$sub: LOOKUP_RETURN : ". Dumper(\@dsbc_arr));

    foreach my $personality (@dsbc_arr){
        foreach my $index(keys %{$self->{$personality}}){
            my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
	    if ($self->{NK_REDUNDANCY}) {
		my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'}; #Possible value for role is active or standby
                next unless (grep /$role/i, @{$self->{NK_ROLE_LOOKUP_RETURN}});
	    }
            if($dsbc_ce){ #root session
                #TOOLS-12508 -  some times they call directly with CE0LinuxObj / CE1LinuxObj, then we don't need to find the which LinuxObj is ACTIVE_CE / STAND_BY
                my $linux_obj_name = ($dsbc_ce=~/LinuxObj/) ? $dsbc_ce : $self->{$personality}->{$index}->{$dsbc_ce};
                $logger->debug(__PACKAGE__ . ".$sub: in '$linux_obj_name' ($dsbc_ce) for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index}->{$linux_obj_name};
            }
            else{ #cli session
                $logger->debug(__PACKAGE__ . ".$sub: in CLI session for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index};
            }
            unless (($prematch, $match) = $temp_self->{conn}->waitfor(%arg)){
                $logger->error(__PACKAGE__ . ".$sub: Failed for '$alias' ('$personality\-\>$index' object).");
                $main::failure_msg .= "UNKNOWN:SBX5000-CLI command error; ";
                $final_prematch = $final_match = '';
                last;
            }
            $final_prematch .= "$prematch\n";
            $final_match .= "$match\n";
        }
        last unless $final_match;
    }

    chomp $final_prematch;
    chomp $final_match;

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$final_prematch, $final_match]");
    return ($final_prematch, $final_match);
}

=head2  prompt 

=over

=item DESCRIPTION:

 Added below subroutine prompt to make the suites work for d-sbc, if the feature pm is using {conn} object directly to execute commands.

=item ARGUMENTS:

 Mandatory :

	prompt

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success

=back

=cut


sub prompt{
    my ($self, $prompt) = @_;
    my $sub = "prompt";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: prompt : $prompt");

    my ($dsbc_ce, $role_from_user);
    if($dsbc_ce = $self->{DSBC_CE}){ #Possible values for $dsbc_ce is ACTIVE_CE or STAND_BY
        $self = $self->{DSBC_OBJ};
        if ($self->{NK_REDUNDANCY}) {
            $role_from_user = ($dsbc_ce =~ /(active|CE0LinuxObj)/i) ? 'ACTIVE' : 'STANDBY'; #possible values for dsbc_ce is ACTIVE_CE or STAND_BY
        }
        $logger->debug(__PACKAGE__ . ".$sub: dsbc_ce : $dsbc_ce");
    }

    my $ret = 1;
    my $temp_self;

    my @dsbc_arr = @{$self->{PERSONALITIES}};

    foreach my $personality (@dsbc_arr){
        foreach my $index(keys %{$self->{$personality}}){
            my $alias = $self->{$personality}->{$index}->{'OBJ_HOSTNAME'};
            my $role = $self->{$personality}->{$index}->{'REDUNDANCY_ROLE'}; #Possible value for role is active or standby
            if($role_from_user){
                next unless ($role_from_user =~/$role/i);
            }

            if($dsbc_ce){ #root session
                # some times they call directly with CE0LinuxObj / CE1LinuxObj, then we don't need to find the which LinuxObj is ACTIVE_CE / STAND_BY
                my $linux_obj_name = ($dsbc_ce=~/LinuxObj/) ? $dsbc_ce : $self->{$personality}->{$index}->{$dsbc_ce};
                $logger->debug(__PACKAGE__ . ".$sub: Setting '$prompt' in '$linux_obj_name' ($dsbc_ce) for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index}->{$linux_obj_name};
            }
            else{ #cli session
                $logger->debug(__PACKAGE__ . ".$sub: Setting '$prompt' in CLI session for '$alias' ('$personality\-\>$index' object).");
                $temp_self = $self->{$personality}->{$index};
                #TOOLS-15088 - to reconnect to standby before executing command
                if($role =~ /STANDBY/){
                    unless($temp_self->__checkAndReconnectStandby()){
                        $logger->error(__PACKAGE__ . ".execCmd: __checkAndReconnectStandby failed");
                        $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
                        return 0;
                    }
                }
            }

            unless ($temp_self->{conn}->prompt($prompt)){
                $logger->error(__PACKAGE__ . ".$sub: Failed to set '$prompt' for '$alias' ('$personality\-\>$index' object).");
                $ret = 0;
                $main::failure_msg .= "UNKNOWN:SBX5000-prompt setting failed; ";
                last;
            }
            $logger->debug(__PACKAGE__ . ".$sub: Successfully set '$prompt' for '$alias' ('$personality\-\>$index' object).");
        }
        last unless $ret;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
    return $ret;
}

# End of TOOLS-8184

=head2  getMetaDetails 

=over

=item DESCRIPTION:

	Executes 'show table system metaVariable' cmd and frame a Meta hash with ip/prefix/vlan as key and respective meta variables as value.
 This is used by execCmd() to reframe a Legacy SBC cmd's passed by feature file to compatible for Cloud SBC supporting formate cmd.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

	meta_var - Hash reference

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

	hash Reference

=item EXAMPLE:

  $obj->getMetaDetails();


=back

=cut

sub getMetaDetails {
    my ($self) = @_;
    my $sub_name = "getMetaDetails";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $get_meta_details_cmd       = 'show status system metaVariable';
    my (@metaData,%hash);
    unless( @metaData = $self->execCmd($get_meta_details_cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Execution of $get_meta_details_cmd failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

=pod

#  5.1
admin@vsbc1> show status system metaVariable
.
.
.
metaVariable IF2.IPV4 {
    value 172.31.12.203;
}
.
.
.

# 6.2.1 => due to N:1 feature o/p has 'vsbc1-192.168.3.9'
admin@vsbc1> show status system metaVariable
.
.
.
metaVariable vsbc1-192.168.3.9 IF2.IPV4 {
    value 10.54.253.55;
}
.
.
.

=cut

    my $metaval;
    foreach my $metaValue (@metaData){
        if($metaValue =~ /metaVariable.*\s+(\S+)\s*\{$/){
            $metaval = $1;
        }elsif($metaValue =~ /\s*value\s*(\S+)\;/){
            $meta_var->{uc $1} = $metaval;                       #ipv6 may have capital/small letters so commonly changing it to uppercase
            $self->{METAVARIABLE}->{$metaval} = uc $1 ;
            $metaval = '';
        }
    }
    $logger->info(__PACKAGE__ . ".$sub_name: meta hash is ".Dumper($meta_var));
    return 1;
}

=head2  cmdFix 

=over

=item DESCRIPTION:

	This subroutine is called by execCmd() to frame the given cmd according to the SBC type.
	Its a Private function.

=item ARGUMENTS:

 Mandatory :

	cmd - Command to be changed

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    cmd

=item EXAMPLE:

  $obj->__cmdFix();

=back

=cut

sub __cmdFix {
    my ($self, $cmd) = @_;
    my $sub = 'cmdFix';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
if ($self->{PERSONALITIES} and scalar @{$self->{PERSONALITIES}}) {
$logger->debug(__PACKAGE__ . ".$sub: PERSONALITIES: --> @{$self->{PERSONALITIES}}");
}
    #For Cloud SBC, commands for configuring 'ipInterfaceGroup|sipSigPort|diamNode' is different, need to remove/change 'ipAddress|prefix|vlanTag|altIpAddress|altPrefix' flags in the command
    my @cmd_list;
    if ($cmd =~ /set addressContext \S+ ipInterfaceGroup \S+ ipInterface/ and $cmd =~ /portName (\w+)/){
	my ($port,$portName) = ($1,$1);
	map { $port = $_ if( $self->{'PKT_ARRAY'}->[$_] eq $port)} 0..$#{$self->{'PKT_ARRAY'}};
	if(exists $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{$port+1}->{LAN} and $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{$port+1}->{LAN}){
	        my $vlan = $self->{TMS_ALIAS_DATA}->{PKT_NIF}->{$port+1}->{LAN}; 
		if($cmd !~ /vlanTag/){
        	    $cmd .= " vlanTag $vlan"; 
		    $logger->warn(__PACKAGE__ . ".$sub: Configuring vlan since PKT_NIF->". $port+1 ."->LAN is passed in TMS.");
		}
		$VLAN_TAGS{$self->{OBJ_HOST}}{$portName} = $vlan;
	}
    }

    #TOOLS-75735
    #set addressContext $addcontext zone $zone sipTrunkGroup $trunkgp ingressIpPrefix $ip $prefix
    if ($cmd =~ /set addressContext .+ zone .+ sipTrunkGroup .+ ingressIpPrefix (.+) (.+)/){
        my ($ip, $prefix, $block) = (lc($1), $2, undef);
        if($block = new2 Net::Netmask ("$1/$2")){
            my $base = $block->base();
            $cmd=~s/ingressIpPrefix $ip/ingressIpPrefix $base/;
            $logger->debug(__PACKAGE__ . ".$sub: replaced $ip with $base");
        }
        else{
            $logger->warn(__PACKAGE__ . ".$sub: failed to mask ip, error: ". Net::Netmask::errstr);
        }
    }

    if ( $self->{CLOUD_SBC}){
        my $newCmd = '';
        my @temp = split '\s+',$cmd;
        if ( ($cmd =~ /\s+diamNode\s+/) and ($cmd !~ /peer/)){
            for (my $i = 0; $i <= $#temp; $i++ ){
                unless($temp[$i] =~ /^(ip(V4|V6)Address)$/){
                    $newCmd .= $temp[$i].' ';
                }else{
                    $i += 1 if($temp[$i+1] =~ /\d+|[\d\.]+|\w+\:/);
                }
            }
            $newCmd =~ s/\s$//;
            $cmd = $newCmd;
        }elsif($cmd =~ /\s+(ipInterfaceGroup|sipSigPort|gwSigPort|relayPort)\s+/){
            my $cmd_tmp = $1;
            $logger->debug(__PACKAGE__ . ".$sub cmd is $cmd_tmp, so using meta_var");
            my ($ip_type,$interface);
            for(my $i = 0; $i<=$#temp; $i++){
                if($temp[$i] =~ /^(ipAddressV?[46]?|altIpAddress|altMediaIpAddress(es)?|pktIpAddress)$/){
                    next if($temp[$i] =~ /^(ipAddressV6|altIpAddress)$/ and not ($temp[$i+1] =~ /\.|:/)); #TOOLS-18716                
                    $interface = $1 if ( $meta_var->{ uc $temp[$i+1]} =~ /(\S+)\./ );#ipv6 may have capital/small letters so commonly changing it to uppercase
                    #TOOLS-12807
                    $ip_type = ($temp[$i+1] =~ /:/)?('V6'):('V4');
                    my $match = ( ($cmd_tmp =~ /gwSigPort/) || ($cmd_tmp =~ /relayPort/) ) ? $nonCe2Ce->{$cmd_tmp} 
                                                          : ( ($temp[$i] =~ /media|pktIpAddress/i) ? ($nonCe2Ce->{$temp[$i]}) : ($nonCe2Ce->{$ip_type}->{'ip'}) ) ;
                    my $type = ($interface =~ /ALT/i) ? '': $ip_type ;
                    if($meta_var->{ uc $temp[$i+1]} =~ /\.FIP(\S+)/){
                        $newCmd .= $match." $interface.IP$type ipPublicVarV4 ".$meta_var->{ uc $temp[$i+1]}." ";#TOOLS-11300
                    }else{
                        $newCmd .= $match." ".$meta_var->{ uc $temp[$i+1]}." ";
                    }
                    if($interface =~ /ALT/i){
                        foreach(keys %{$meta_var}){
                            if($meta_var->{$_} =~ /$interface\.IFName/){
                                $interface = $_ ;
                                $logger->debug(__PACKAGE__ . ".$sub The New interface is $interface");
                                last;
                            }
                        }
                    }
                    ++$i;
                }elsif($temp[$i] =~ /^(altPrefix|prefix|vlanTag)$/){
                    my $match = ($temp[$i] =~ /prefix/i) ? ($nonCe2Ce->{$ip_type}->{'prefix'}) : ($nonCe2Ce->{$temp[$i]});#TOOLS-12807
                    $newCmd .=$match." ".$interface.".".$1." " if ($meta_var->{$temp[$i+1]} =~ /\.(\S+)/);
                    ++$i;
                }else{
                    $newCmd .=$temp[$i]." ";
                }
            }

#TOOLS-18594 - For ingress configuration of ipInterfaceGroup and sipSigPort command, appending 'ipPublicVarV4 HFE->1->IP'.

            if( $self->{AWS_HFE} and ($newCmd =~ /portName pkt0.+ipVarV4\s+(\S+)/ or ($self->{CMD_INFO}->{INGRES}->{1}->{META_VAR} and $newCmd =~ /$self->{CMD_INFO}->{INGRES}->{1}->{META_VAR}/))){#TOOLS-18594 TOOLS-19356
                $self->{CMD_INFO}->{INGRES}->{1}->{META_VAR} = $1 unless($self->{CMD_INFO}->{INGRES}->{1}->{META_VAR}); 
	        $newCmd .= ' ipPublicVarV4 '.$meta_var->{$self->{TMS_ALIAS_DATA}->{HFE}->{1}->{IP}};
            }
            if ($self->{'Google Compute Engine_HFE'} and ($newCmd =~ /ipVarV4\s+(\S+)/)) {
                $newCmd .= ' ipPublicVarV4 '.$meta_var->{$self->{TMS_ALIAS_DATA}->{HFE}->{$1-1}->{IP}} if ($interface =~ /IF(\d+)/);
            }

            $newCmd =~ s/\s$//;
            $cmd = $newCmd;
        }
        elsif ( $cmd =~ /\s+addressContext\s+\S+\s+staticRoute\s+(\S+)\s+\S+\s+(\S+)\s+/){ # TOOLS-7028 #TOOLS-8193 #TOOLS-12443-To support deletion of staticRoute
            $logger->info(__PACKAGE__ . ".$sub : matched command \"$cmd\"");
            my ($ip,$gateway_ip)  = ($1 , $2);
            if ($self->{CLOUD_PLATFORM} eq 'Google Compute Engine') {            # For TOOLS-18774, to check the GCP(Google Cloud Platform)
                push(@cmd_list,$cmd);
                $cmd =~ s/$ip\s+\S+\s+$gateway_ip/$gateway_ip 32 0.0.0.0/;
                $logger->info(__PACKAGE__ . ".$sub : $ip, $gateway_ip");
                unshift(@cmd_list,$cmd);
            }else{
                $cmd =~ s/$ip\s+(\S+)\s+/0.0.0.0 0 / if( $ip=~/\./); # ipv4 check
                $cmd =~ s/$ip\s+(\S+)\s+/:: 0 / if( $ip=~/\:/); # ipv6 check
            }
        }
        #TOOLS-71156 && TOOLS-71230
        elsif($cmd =~ /set\s+system\s+policyServer\s+remoteServer\s+(\S+)\s+ipAddress\s+(\S+)/ && exists $main::TESTBED{"$main::TESTBED{$1}:hash"} && exists $main::TESTBED{"$main::TESTBED{$1}:hash"}{SLAVE_CLOUD}){
            my $ip =$2;
            my $psx = $main::TESTBED{$1};
            my $ip_type = ($ip=~ /:/) ? 'IPV6' :'IP';
           
            if($main::TESTBED{"$psx:hash"}->{SLAVE_CLOUD}->{1}->{$ip_type}){
                $cmd =~ s/$ip/$main::TESTBED{"$psx:hash"}->{SLAVE_CLOUD}->{1}->{$ip_type}/;
            }else{
                 $logger->error(__PACKAGE__. ".$sub {SLAVE_CLOUD}->{1}->{$ip_type} is not present in TESTBED");
                 $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub(0)"); 
                 return () ;
             }

        }
        $cmd =~ s/$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}/VSBCSYSTEM/ if( $cmd =~ /(set|delete) profiles digitParameterHandling numberTranslationCriteria/) ;#TOOLS-71100
	$cmd =~ s/$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}/VSBCSYSTEM/ if( $cmd =~ /((set|delete) global callRouting route trunkGroup)/) ;#TOOLS-20806
	$cmd =~ s/$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}/vsbcSystem/ if( $cmd =~ /((set|request|show table) system (admin|ntp))/) ;
        $logger->info(__PACKAGE__ . ".$sub : commands :@cmd_list");
       
        if( @cmd_list) {
            $cmd = pop @cmd_list;
            $self->{SKIP_CMDFIX} = 1;
            unless($self->execCommitCliCmdConfirm(@cmd_list)){
                $self->{SKIP_CMDFIX} = 0;
                $logger->error(__PACKAGE__ . ".execCmd: Unable to execute cmd.");
                $logger->debug(__PACKAGE__ . ".execCmd: <-- Leaving sub [0]");
                return 0;
            }
            $self->{SKIP_CMDFIX} = 0;
        }

        #TOOLS-18757 fix
        if($self->{AWS_HFE} && $cmd=~/set addressContext default zone (.+) sipTrunkGroup .+ ingressIpPrefix (.+)\s+\d+/){
            my ($zone, $ip) = ($1, $2);
            foreach(keys %{$main::TESTBED{'sipp:1:ce0:hash'}->{NODE}}){
                if($main::TESTBED{'sipp:1:ce0:hash'}->{NODE}->{$_}->{IP} eq $ip && exists $main::TESTBED{'sipp:1:ce0:hash'}->{PUBLIC}->{$_}->{IP}){
                    $cmd=~ s/$ip/$main::TESTBED{'sipp:1:ce0:hash'}->{PUBLIC}->{$_}->{IP}/;
                    $self->{CMD_INFO}->{ZONE}->{$zone}->{$ip} = $main::TESTBED{'sipp:1:ce0:hash'}->{PUBLIC}->{$_}->{IP};
                    $logger->debug(__PACKAGE__ . ".$sub: CMD_INFO->ZONE->$zone->$ip = ". $self->{CMD_INFO}->{ZONE}->{$zone}->{$ip});
                    last;
                }
            }
        }
       
       if(exists $self->{CMD_INFO}->{ZONE} && $cmd=~/set addressContext default zone (.+) ipPeer .+ ipAddress (.+) ipPort .+/ && exists $self->{CMD_INFO}->{ZONE}->{$1}->{$2}){
           my ($zone, $ip) = ($1, $2);
           $logger->debug(__PACKAGE__ . ".$sub: replacing $ip to CMD_INFO->ZONE->$zone->$ip, ". $self->{CMD_INFO}->{ZONE}->{$zone}->{$ip});
           $cmd=~ s/$ip/$self->{CMD_INFO}->{ZONE}->{$zone}->{$ip}/;
       } 
       #End of TOOLS-18757 fix

        $cmd =~ s/( ipsec\s+spd.+)localIpAddr\s+(\S+)\s+(.*)/$1localIpAddrVar $meta_var->{uc $2} $3/;      #12098 support metaVar for ipsec peer and ipsec spd commands 
        $cmd =~ s/( ipsec\s+peer.+localIdentity.+)ipAddress\s+(\S+)/$1ipAddressVar $meta_var->{uc $2}/;
        $cmd =~ s/\ssystem admin \S+\s/ system admin vsbcSystem /g if( $cmd !~ /show table system admin contact/); #Added condition check for TOOLS-15862
        $cmd =~ s/ destinationIpAddress(.+)destinationAddressPrefixLength / destIpAddress$1destIpAddressPrefixLength /;#TOOLS-12529
    }
    if( $self->{SBC_TYPE}){ # TOOLS-8196: if a sbc is M/S/T sbc it will have SBC_TYPE flag.Added the SBC_TYPE check to find whether it is DSBC.

        # to get first occurence of address context
        $self->{ADDRESS_CONTEXT} = $1 if ( !$self->{ADDRESS_CONTEXT} and $cmd =~ /\s+addressContext\s+(\S+)\s+.*/i ); #TOOLS-8611 removed 'portName pkt0' ,coz check fails if some other cmd is issued first.

        $cmd =~ s/addressContext\s+$self->{ADDRESS_CONTEXT}/addressContext default/ if($self->{ADDRESS_CONTEXT}); # changing the first occured addresscontext to default.
#TOOLS-11545
        my %cmd_fix = (
                       'ipAddress' => 'IP',
                       'ipAddressV4' => 'IP',
                       'ipAddressV6' => 'IPV6',
                       'prefix'    => 'IPV4PREFIXLEN',
                       'altIpAddress' => 'IPV6',
                       'altPrefix' => 'IPV6PREFIXLEN',
                       'vlanTag' => 'LAN'
                       );
        unless($self->{CLOUD_SBC}){

            $cmd =~ s/ceName (\S+)/ceName $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}/;

            if($cmd =~ /\s+(ipInterfaceGroup)\s+/){
                my $port;
                if ($cmd =~ /portName\s+(\S+)/){
                    $port = $1;
                    map { $port = $_ if( $self->{'PKT_ARRAY'}->[$_] eq $port)} 0..$#{$self->{'PKT_ARRAY'}};
                    $self->{CMD_INFO}->{pkt_index} = $port;
                }elsif(defined $self->{CMD_INFO}->{pkt_index}){
                     $port = $self->{CMD_INFO}->{pkt_index} ;
                }
                foreach my $parameter (keys %cmd_fix){
                    $cmd =~ s/$parameter (\S+)/$parameter $self->{'TMS_ALIAS_DATA'}->{'PKT_NIF'}->{$port+1}->{$cmd_fix{$parameter}}/;
                } 
            }
          #TOOLS-20150
            if($cmd =~ /\s+sipSigPort\s+\d+\s+ipInterfaceGroupName/){
	        state $sig_port =0;
		foreach my $parameter (keys %cmd_fix){
                    $cmd =~ s/$parameter (\S+)/$parameter $self->{'TMS_ALIAS_DATA'}->{'SIG_SIP'}->{$sig_port+1}->{$cmd_fix{$parameter}}/;
                }
		$sig_port++;
		
            }
            
        }#TOOLS-11545 - ENDS
    }
    

    my @cli_command;
    if(SonusQA::Utils::greaterThanVersion($self->{APPLICATION_VERSION}, 'V07.01.00')){
    	if ($cmd =~ /set oam eventLog typeAdmin audit filterLevel (minor|major|critical|noevents)/i) { # TOOLS-18769
	    $cmd =~ s/$1/Info/;
 	    $logger->debug(__PACKAGE__ . ".$sub: Changed $cmd to Info as $self->{APPLICATION_VERSION} is greater than 7.1");
    	}
    	elsif($cmd =~ /show configuration oam eventLog platform(\w+) auditLog(\w+)/) {
	    my $temp = $2;
	    my $replace_temp = lcfirst($temp);
	    $cmd =~ s/$1/Rsyslog servers server1/ if($1 =~ /AuditLogs/);
	    $cmd =~ s/auditLog//;
	    $cmd =~ s/$temp/$replace_temp/;
        }
        elsif($cmd =~ /set oam eventLog typeAdmin (\w+) syslogRemoteHost (.*) syslogRemoteProtocol tcp syslogRemotePort (\d+)(.*)/) {
            my $new_cmd = $4;
            my $type = $1;
            $cmd =~ s/$new_cmd// if($new_cmd);
            $new_cmd =~ s/state \w+ // if($type eq "audit");
            $cmd =~ s/syslogRemoteHost/servers server1 syslogRemoteHost/;
	    push(@cli_command, $cmd);
            push(@cli_command, "set oam eventLog typeAdmin $type$new_cmd");
        }
        elsif($cmd =~ /set oam eventLog platformAuditLogs auditLogRemoteHost (.*) state enabled/) {
            push(@cli_command, "set oam eventLog platformRsyslog linuxLogs platformAuditLog enabled");
            push(@cli_command, "set oam eventLog platformRsyslog syslogState enabled");
            push(@cli_command, "set oam eventLog platformAuditLogs state enabled");
        }
        elsif($cmd =~ /set oam eventLog platformAuditLogs auditLogRemoteHost (.*) auditLogProtocolType tcp auditLogPort (\d+) state disabled/) {
           push(@cli_command, "set oam eventLog platformAuditLogs disabled");
           push(@cli_command, "set oam eventLog platformRsyslog servers server1 remoteHost $1 protocolType tcp port $2");
           push(@cli_command, "set oam eventLog platformRsyslog linuxLogs platformAuditLog disabled");
        }
    }
    if($#cli_command > 0) {
	$cmd = pop @cli_command;
	$self->{SKIP_CMDFIX} = 1;
	unless($self->execCommitCliCmdConfirm(@cli_command)){
            $logger->error(__PACKAGE__ . ".execCmd: Unable to execute cmd.");
	    $cmd = '';
        }
	$self->{SKIP_CMDFIX} = 0;
    }
if ($self->{PERSONALITIES} and scalar @{$self->{PERSONALITIES}}) {
$logger->debug(__PACKAGE__ . ".$sub: PERSONALITIES: --> @{$self->{PERSONALITIES}}");
}
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$cmd]");
    return $cmd ;
}

=head2 __checkAndReconnectStandby

=over

=item DESCRIPTION:

    This subroutine is called by several subroutines internally to check and reconnect to stand by for N:1 setup.
    Its a Private function.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    cmd

=item EXAMPLE:

  $obj->__checkAndReconnectStandby();

=back

=cut

sub __checkAndReconnectStandby{
    my $self = shift;
    my $sub = '__checkAndReconnectStandby';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    # TOOLS-13381 - Before executing the command, calling makeReconnection if NEW_STANDBY_INDEX is same as the current index.
    if($self->{PARENT}->{NEW_STANDBY_INDEX}->{$self->{SBC_TYPE}} == $self->{INDEX}){
        $self->{PARENT}->{NEW_STANDBY_INDEX}->{$self->{SBC_TYPE}} = 0;
        $logger->info(__PACKAGE__ . ".$sub: since NEW_STANDBY_INDEX == INDEX ($self->{INDEX}), calling makeReconnection for '$self->{SBC_TYPE}\-\>$self->{INDEX}' object.");
        unless($self->makeReconnection(-timeToWaitForConn => 30)){
            $logger->error(__PACKAGE__ . "$sub. makeReconnection failed.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }

        # TOOLS-18474 - Updating CE1LinuxObj reference after reconnection
        foreach my $index (keys %{$self->{PARENT}->{$self->{SBC_TYPE}}}){
            next if($self->{PARENT}->{$self->{SBC_TYPE}}->{$index}->{REDUNDANCY_ROLE} =~ /STANDBY/i);
            $logger->debug(__PACKAGE__ . ".$sub: changing CE1LinuxObj of $self->{SBC_TYPE} -> $index to STANDBY_ROOT");
            $self->{PARENT}->{$self->{SBC_TYPE}}->{$index}->{CE1LinuxObj} = $self->{PARENT}->{STANDBY_ROOT}->{$self->{SBC_TYPE}};
        }
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub: No need to call makeReconnection for '$self->{SBC_TYPE}\-\>$self->{INDEX}' object, since NEW_STANDBY_INDEX ($self->{PARENT}->{NEW_STANDBY_INDEX}->{$self->{SBC_TYPE}}) != INDEX ($self->{INDEX})");
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 AUTOLOAD

=over

=item DESCRIPTION:

 This subroutine will be called if any undefined subroutine is called.

=back

=cut

sub AUTOLOAD {
  our $AUTOLOAD;
  my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
  if(Log::Log4perl::initialized()){
    my $logger = Log::Log4perl->get_logger($AUTOLOAD);
    $logger->warn($warn);
  }else{
    Log::Log4perl->easy_init($DEBUG);
    WARN($warn);
  }
}

=head2 enableAdminPassword

=over

=item DESCRIPTION:

    This subroutine is called to enable password login for admin.(TOOLS-18600)

=item ARGUMENTS:

    newpassword(optional) - The password to set when changing password for admin. If not passed password is set as LOGIN-1-PASSWD

=item PACKAGE:

    SonusQA::SBX5000

=item OUTPUT:

    1 - Success
    0 - Failure 

=item EXAMPLE:

  $obj->enableAdminPassword("Sonus@123");

=back

=cut

sub enableAdminPassword {
    my ($self) = shift;
    my $sub = 'enableAdminPassword';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    if ($self->{D_SBC}) {
        my $result = 1;
        my %hash = (
                        'args' => [@_]
                );
        $result = $self->__dsbcCallback(\&enableAdminPassword, \%hash);
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
        return $result;
    }
    my($newpassword)=@_;
    $newpassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} unless($newpassword);

    my $cmd = "set oam localAuth user admin passwordLoginSupport enabled";
    unless ( $self->enterPrivateSession() ) {
	$logger->debug(__PACKAGE__ . ".$sub: --> Leaving Sub[0]");
	return 0;
    }
    my $temp_pass;
    my $flag = 1;
    unless($self->execCommitCliCmd($cmd)) {
	$logger->error(__PACKAGE__ . ".$sub : Could not enable password login for admin."); 
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }
    my ($prematch, $match);
    $flag = 0 if(${$self->{CMDRESULTS}}[0] =~ m/No modifications to commit./i);
    if($flag){
        unless (($prematch, $match) = $self->{conn}->waitfor(
                                              -match => $self->{PROMPT}
                                      )) {
            $logger->error(__PACKAGE__ . ".$sub : Didn't get expected match -> $_ ,prematch ->  $prematch,  match ->$match");
            $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
        }
        $temp_pass = $1 if($prematch =~ /Password for admin is (.*)/);
        $logger->debug(__PACKAGE__ . ".$sub: Temporary password generated is $temp_pass" );
    }
    unless ( $self->leaveConfigureSession ) {
            $logger->debug(__PACKAGE__ . ".$sub: --> Leaving Sub[0]");
            return 0;
    }
    if($flag){
        tie (my %print, "Tie::IxHash");
        %print = ( 'Enter old password' => $temp_pass, 'Enter new password' => $newpassword, 'Re-enter new password' => $newpassword);
        $self->{conn}->print('change-password');
    	foreach (keys %print) {
      	    unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT}, -match => "/$_/i")) {
                $logger->error(__PACKAGE__ . ".$sub : Didn't get expected match -> $_ ,prematch ->  $prematch,  match ->$match");
                $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            	return 0;
            }
            if ($match =~ /$_/i) {
                $logger->info(__PACKAGE__ . ".$sub : matched for $_, passing $print{$_} argument");
                $self->{conn}->print($print{$_});
            } else {
            	$logger->error(__PACKAGE__ . ".$sub : dint match for expected prompt $_");
                $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $self->{sessionLog2}");
            	$logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            	return 0;
            }
        }
	unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT})) {
                $logger->error(__PACKAGE__ . ".$sub : Didn't get expected match -> $_ ,prematch ->  $prematch,  match ->$match");
                $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
                return 0;
        }
	if($prematch =~ m/\[Error\]/i) { 
            $logger->error(__PACKAGE__ . ".$sub : Password change error \n $prematch");
	    $logger->debug(__PACKAGE__ . ".$sub : --> Leaving Sub[0]");
	    return 0;
	}
    }
    $logger->debug(__PACKAGE__ . ".$sub : Password is already enabled.") unless($flag);
    $logger->debug(__PACKAGE__ . ".$sub : Password suucessfully changes to $newpassword.");
    $logger->debug(__PACKAGE__ . ".$sub : --> Leaving Sub[1]");
    return 1;
} 

=head2 checkAsanBuildFailure

=over

=item DESCRIPTION:

    This subroutine is called to check for ASAN Build Failure.(TOOLS-72075)

=item ARGUMENTS:

    none

=item PACKAGE:

    SonusQA::SBX5000

=item OUTPUT:

    1 - Success
    0 - Failure 

=item EXAMPLE:

  $obj->checkAsanBuildFailure();

=back

=cut

sub checkAsanBuildFailure {
    my ($self) = shift;
    my $sub = "checkAsanBuildFailure";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");


    unless($self->checkProcessStatus(-noOfRetries => '1')) {
        $logger->error(__PACKAGE__  . ".$sub: SBC is not UP or Processes are not running;");
        $logger->debug(__PACKAGE__.".$sub: Copying the logs for ASAN Build");
        my %scpArgs;
        my $timestamp = strftime("%Y%m%d%H%M%S",localtime);
        my $locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
        my ($cmdStatus, @cmdResult);
        $scpArgs{-hostip} = $self->{OBJ_HOST};
        $scpArgs{-hostuser} = "root";
        $scpArgs{-hostpasswd} = "sonus1";
        $scpArgs{-scpPort} = "2024";
        $scpArgs{-chown} = 1;
        
        #TAR here tar -czf /tmp/CE_NODE_logs.tar /var/log/sonus/sbx/asp_saved_logs/normal/
        foreach my $ce (@{$self->{ROOT_OBJS}}) {
            my $file = "CE_NODE_logs_$ce"."_"."$timestamp.tar";
            
            ($cmdStatus, @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$ce},"tar -czf /tmp/$file /var/log/sonus/sbx/asp_saved_logs/normal/*");
            if($cmdStatus) {
                $scpArgs{-destinationFilePath} = $locallogname;
                $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."/tmp/$file";
                $main::asan_build_failure = '';
                if(&SonusQA::Base::secureCopy(%scpArgs)) {
                    $main::asan_build_failure.= "$locallogname/$file.\t";
                    $logger->info(__PACKAGE__ . ".$sub: Log file $file copied to $locallogname");
                }
                ($cmdStatus, @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($self->{$ce},"rm -rf /tmp/$file");
            }
        }
        $logger->debug(__PACKAGE__.".$sub: Performing Clear DB on the SBC");
        my $cmd  =  '/opt/sonus/sbx/scripts/clearDBs.sh';     
        if($self->serviceStopAndExec(-cmd => "$cmd")) {
            $logger->debug(__PACKAGE__. ".$sub: clearDB successful");
        }
        else {
            $logger->info(__PACKAGE__."Clean start failed. SBC is not accessible. Please check the SBC");
        }
        $main::asan_build_failure = 1 unless($main::asan_build_failure);
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving sub [1]");
        return 1;
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving sub [0]");
    return 0;
}



1;
