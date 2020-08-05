package SonusQA::ATSHELPER;
require Exporter;
use JSON::XS ;

=head1 NAME

SonusQA::ATSHELPER - SonusQA ATSHELPER class

=head1 SYNOPSIS

use ATS;

or:

use SonusQA::ATSHELPER;

=head1 DESCRIPTION

SonusQA::ATSHELPER provides a common interface for acting on all objects types such as GSX, PSX, EMSCLI, SGX, MGTS and GBL.

=head1 AUTHORS

The <SonusQA::ATSHELPER> module has been created by P.Uma Maheswari(ukarthik@sonusnet.com).

=head1 METHODS
          
=cut

use strict;
use warnings;
use SonusQA::Utils qw (:all);
use Sys::Hostname;
use Log::Log4perl qw(get_logger :easy);
use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use HTTP::Cookies;
$HTTP::Headers::TRANSLATE_UNDERSCORE = 0;
use JSON qw( decode_json );
#Log::Log4perl->easy_init($DEBUG);
#use Net::Telnet;
#use XML::Simple; # qw(:strict);
use Data::Dumper;
use Socket;
#use ATS;
#use Data::GUID;
#use Data::UUID;
use DBI;
use Switch;
use SonusQA::SGX;
use SonusQA::SGX4000;
use SonusQA::GSX;
use SonusQA::Utils;
use SonusQA::MGTS;
use SonusQA::PSX;
use SonusQA::EMSCLI;
use SonusQA::EMS;
use SonusQA::ASX;
use SonusQA::GBL;
use SonusQA::SILKTEST;
use SonusQA::SELENIUM;
use SonusQA::NetEm;
use SonusQA::BGF;
use SonusQA::MSX;
use SonusQA::BSX;
use SonusQA::FORTISSIMO;
use SonusQA::MGW9000;
use SonusQA::NAVTEL;
use SonusQA::SDIN;
#use SonusQA::DSC;
use SonusQA::LYNC;

use IO::Socket; 
use English;
use Time::HiRes qw(gettimeofday tv_interval);
use SOAP::Lite;
use Data::Validate::IP qw(is_ipv4 is_ipv6);

our @ISA    = qw( Exporter );
our @EXPORT = qw( printStartTest printFailTest printPassTest );

our @skipped_ces; #it is used to populate the skipped optional elements by checkRequiredConfiguration. And used by SonusQA::Utils::mail

# Variable(s) for calculating test execution time - private to module
my $test_start_time = 0;
my $test_exec_time  = 0;
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

=head2 newFromAlias()

=over

=item DESCRIPTION:

This function attempts to resolve the TMS Test Bed Management alias passed in as the first argument and creates an instance of the ATS object based on the object type passed in as the second argument. This argument is optional. If not specified the OBJTYPE will be looked up from TMS. As an additional check it will double check that the OBJTYPE in TMS corresponds with the user's entry. If not it will error. It will also add the TMS alias data to the object as well as the resolved alias name. It will return the ATS object if successful or undef otherwise. In addition, if the user specifies extra flags not recognised by newFromAlias, these will all be passed to Base::new on creation of the session object. That subroutine will handle the parsing of those arguments. This is primarily to enable the user to override default flags.

=item ARGUMENTS:

 Mandatory:

	-tms_alias => TMS alias Name
	-target_instance =>  EMS target instance when object type is "EMSCLI"

 Optional:

	-obj_type => ATS object type. 
				Example: EMS
	-ignore_xml => xml library ignore flag , Values - 0 or OFF ,defaults to 1
	-iptype  => Login IP version preference (currently PSX/BRX, EMS and SBX5000 has this support). 
			To login to IPv4, pass : 'v4'
			To login to IPv6, pass : 'v6'
			To login to either IPv6 or IPv4,  pass : 'any'
	-obj_user => Login Username. 
				Example : linuxadmin
	-obj_password => Login Password. 
				Example : sonus
	-sessionlog => Flag to decide the Session log.By default it is Enabled.
			To disable the sessionlog, pass : 0
			To have customized file name, pass : any string 
				Example : 'SERVER' while calling newFromAlias for SIPP server. It helps to differentiate the SIPP server and client log.
	-do_not_delete => Used for Cloud Instance to, not delete the instance in DESTROY()
			To retain the Instance after automation completed, pass : 1
			To delete the Instance after automation completed, pass : 0
	-obj_key_file => To login with key file without password.
			Pass : keyfile name along with correct path.
			Example : /home/user_name/ats_repos/lib/perl/SonusQA/cloud_ats.key
	-obj_commtype => typically: SSH, SFTP, TELNET or FTP - see specific object documentation for details
	-failures_threshold => Specifies how many reattempts to make if the login failed.By Default 2 attempts are made.
				Example: 5
    -alias_file => pass the hash reference file if need to resolve alias from the file
    -alias_hashref => pass the hash reference if need to use it

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

SonusQA::Utils::resolve_alias()
SonusQA::GSX::new()
SonusQA::PSX::new()
SonusQA::EMSCLI::new()
SonusQA::SGX::new()SonusQA::MGTS::new()
SonusQA::MGTS::new()
SonusQA::GBL::new()
Switch

=item RETURNS:

$ats_obj_ref - ATS object if successful
Adds - $ats_obj_ref->{TMS_ALIAS_DATA} and $ats_obj_ref->{TMS_ALIAS_DATA}->{ALIAS_NAME}
exit         - otherwise

=item EXAMPLE:

my $gsx_obj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => <tms alias> , -obj_type => "GSX");
my $sgx4000_obj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => <tms alias>);

=back

=cut

sub newFromAlias {

    my (%args) = @_;
    my ( $value, $tms_alias, %refined_args, $ats_obj_type, $ems_target_inst, $sbxObjradius, $alias_file, $alias_file_female, $ce, $alias_hashref, $alias_hashref_female);
    my $ats_obj_ref;
    my $ignore_xml = 1; # default value

    # Iterate through the args that are passed in and remove tms_alias and
    # obj_type
    foreach ( keys %args ) {
        if ( $_ eq "-tms_alias" ) { 
            $tms_alias = $args{-tms_alias};
            $refined_args{-tms_alias_name} = uc $args{-tms_alias};
        }
        elsif ( $_ eq "-obj_type" ) {
            $ats_obj_type = $args{-obj_type};
        }
        elsif ( $_ eq "-target_instance" ) {
            $ems_target_inst = $args{-target_instance};
        }
        elsif ( $_ eq "-ignore_xml" ) {
            $ignore_xml = $args{-ignore_xml};
        }
	elsif ( $_ eq "-sbxObj") {
	    $sbxObjradius = $args{-sbxObj};
	    delete $args{-sbxObj};
	}
        elsif ( $_ eq "-alias_file") {
            if(ref($args{-alias_file}) eq 'ARRAY'){
                ($alias_file, $alias_file_female) = @{$args{-alias_file}};
            }
            else{
                $alias_file = $args{-alias_file};
            }
            delete $args{-alias_file};
        }
        elsif ( $_ eq '-alias_hashref') { #TOOLS-19488
            $alias_hashref = $args{-alias_hashref};
            delete $args{-alias_hashref};
        }
        else {
            # Populate a hash with other flags passed in. This will then be
            # passed to Base::new where that function will
            # process remaining hash entries.
            $refined_args{ $_} = $args{ $_ } unless ($_ eq '-tms_alias_name'); #we have already set it above just ignore if some thing coming from previous value
        } 
    }

    my $sub_name = "newFromAlias";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered $sub_name");  

    # Check if $tms_alias is defined and not blank
    unless ( defined($tms_alias) && ($tms_alias !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Value for -tms_alias undefined or is blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving $sub_name [exit]");
        exit;
    }

    $tms_alias=~s/^\s+//; #Fix for TOOLS-71323
    $logger->debug(__PACKAGE__ . ".$sub_name:  Resolving Alias '$tms_alias'"); 

    # Set ignore_xml flag to user specified value if $args{-ignore_xml} specified
    if ( defined($ignore_xml) && ($ignore_xml !~ m/^\s*$/)) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Ignore XML flag is blank");
    }

    if (keys ( %$alias_hashref )) { #TOOLS-19488
        $logger->info(__PACKAGE__ . ".$sub_name: getting alias data from passed hash reference (-alias_hashref)");
    }
    else{
        # TOOLS-13408 - we don't do resolve_alias if its already resolved. 
        if($alias_file && -e $alias_file){ #TOOLS-15041
            $logger->debug(__PACKAGE__ . ".$sub_name:  getting resolve_alias from alias_file, $alias_file");
            $alias_hashref = do $alias_file;
        }
        else{
            $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);
        }
    }
    # Check if $alias_hashref is empty 
    unless (keys ( %$alias_hashref )) {
        $logger->error(__PACKAGE__ . ".$sub_name:  \$alias_hashref for TMS alias $tms_alias empty. This element does not seem to be in the database.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving $sub_name [exit]");
        exit;
    }

    # Check for root entry. If password is not hardcoded we can get this from the 
    # tms alias hash
    if ( exists( $refined_args{ "-obj_user" } ) && $refined_args{ "-obj_user" } eq "root" ) {
        unless ( exists( $refined_args{ "-obj_password" } )) {
            $refined_args{ "-obj_password" } = $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD};
        }
    }


    # Check for __OBJTYPE. If this is blank and -obj_type is not defined error. If
    # -obj_type is different to __OBJTYPE error.


    if ( defined( $ats_obj_type ) && ( $ats_obj_type !~ m/^\s*$/ )) {
        unless ( $ats_obj_type eq $alias_hashref->{__OBJTYPE} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Value for -obj_type ($ats_obj_type) does not match TMS OBJTYPE ($alias_hashref->{__OBJTYPE})");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving $sub_name [exit]");
            exit;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Object Type (from cmdline) is $ats_obj_type");
    }
    else {
        if ( $alias_hashref->{__OBJTYPE} eq "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Value for -obj_type and TMS OBJTYPE undefined or is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving $sub_name [exit]");
            exit;
        }
        else {
            $ats_obj_type = $alias_hashref->{__OBJTYPE};
            $logger->debug(__PACKAGE__ . ".$sub_name:  Object Type (from TMS) is $ats_obj_type");
        }
    }

    #check if the SBC is D_SBC
    $ats_obj_type = "D_SBC" if (grep(/M_SBC|S_SBC|T_SBC|I_SBC|SLB/, keys %{$alias_hashref}));
    $refined_args{-nested} =1 if(exists $alias_hashref->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE} and $alias_hashref->{CLOUD_INPUT}->{1}->{TEMPLATE_FILE} =~ /.*\.yaml/);

    my $vmCtrlObj;
    my $resolve_cloud = 0;
    my $threshold = 10;
    my ($ce1);
    my $female = $refined_args{-tms_alias_female}; #for D-SBC HA
    $female ||= &getMyHaPair($tms_alias) if ($ats_obj_type =~ /SBX/ and !$refined_args{-ha_setup} and !$main::TESTSUITE->{STANDALONE} and (not exists $refined_args{-obj_port} or $refined_args{-obj_port} != 2024));

    $alias_hashref->{name} = $tms_alias;
    if ($female) {
        # TOOLS-74531 - Enhancement: There should be new parameter to pass -alias_file for standby_sbc in case of HA pair
        if($alias_file_female && -e $alias_file_female){
            $logger->debug(__PACKAGE__ . ".$sub_name:  getting resolve_alias from alias_file_female, $alias_file_female");
            $alias_hashref_female = do $alias_file_female;
        }
        else{
            $alias_hashref_female = SonusQA::Utils::resolve_alias($female);
        }
        $alias_hashref_female->{name} = $female;
        $args{-alias_hashref_female} = $alias_hashref_female;
    }
   

    if ($alias_hashref->{VM_CTRL}->{1}->{NAME} ) {
        $ce = $main::TESTBED{$args{-tms_alias}}; #TOOLS-17907
        #TOOLS-71259
        if ($refined_args{-ha_setup} or (exists $main::TESTBED{$ce.':hash'} and $main::TESTBED{$ce.':hash'}->{RESOLVE_CLOUD})) {
	    #If PSX instance(TOOLS-5085) or HA instance is already resolved ..skipping resolveCloudInstance( ) 	
            $logger->debug(__PACKAGE__ . ".$sub_name: we already have vm_ctrl_obj and has already resolved cloud HA instance");
            %{$alias_hashref} = %{$main::TESTBED{$ce.":hash"}}; #assign resolved cloud alias to alias_hashref (to create SBX obj)
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name: creating VMCTRL Object");
            my $vmCtrlAlias = $alias_hashref->{VM_CTRL}->{1}->{NAME};

            unless ($vm_ctrl_obj{$vmCtrlAlias}) {
                my $iac_hash_ref ;
                if ($alias_hashref->{VM_CTRL}->{1}->{IP}) {
                    $iac_hash_ref->{LOGIN}->{1}->{IP} = $alias_hashref->{VM_CTRL}->{1}->{IP} ;
                    $iac_hash_ref->{LOGIN}->{1}->{USERID} = $alias_hashref->{VM_CTRL}->{1}->{USERID} ;
                    $iac_hash_ref->{LOGIN}->{1}->{KEY_FILE} = $alias_hashref->{VM_CTRL}->{1}->{KEY_FILE} ;
                    $iac_hash_ref->{__OBJTYPE} = 'IAC' ;
                }
                unless($vmCtrlObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $vmCtrlAlias, -alias_hashref => $iac_hash_ref, -ignore_xml => 0, -sessionLog => 1, -iptype => 'any', -return_on_fail => 1)) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: Failed to create VMCTRL Object");
                    return 0;
                }
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub_name: VMCTRL obj is already present");
                $vmCtrlObj = $vm_ctrl_obj{$vmCtrlAlias};
            }

            my $ce_oam = $main::TESTBED{'sbx5000:1:ce0:'.$1.'_OAM:1:hash'}->{SBC_RGIP} if(exists $args{-sbc_type} and $args{-sbc_type} =~ /(S|M)_SBC/ and $args{-oam});
            $alias_hashref->{CLOUD_INPUT}->{1}->{PARAMETER} .= "|oam_ip_1=$ce_oam" if($ce_oam);
	    $args{-flag}=0; #TOOLS-12934
            $args{-alias_hashref} = $alias_hashref;
            unless ($vmCtrlObj->resolveCloudInstance(%args)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to fetch Cloud Instance details from VmCtrl");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            $resolve_cloud = 1; # setting it to avoid calling resolveCloudInstance() again from SonusQA::ATSHELPER::newFromAlias()
        }
        $refined_args{-do_not_delete} = 1 if ($alias_hashref->{RESOLVE_CLOUD}) ;
    }

    %{$main::TESTBED{$ce.":hash"}} = %{$alias_hashref} if ($ce = $main::TESTBED{$args{-tms_alias}}); # Fix for TOOLS-71106
    %{$main::TESTBED{$ce1.":hash"}} = %{$alias_hashref_female} if ($alias_hashref_female and $ce1 = $main::TESTBED{$female});


    # Use KEY_FILE for login, if {LOGIN}->{1}->{KEY_FILE} is set in TMS
    $refined_args{ '-obj_key_file' } = $alias_hashref->{LOGIN}->{1}->{KEY_FILE} if($alias_hashref->{LOGIN}->{1}->{KEY_FILE});
    # some conditional circus for IPTYPE check

    my %converted_args = map {lc $_,$refined_args{$_}} keys %refined_args;
    my @ipType = ('IP','IPV6');
    if ( defined $converted_args{-iptype} ){
        if ($converted_args{-iptype} =~ /V4/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: connection is estabilished using IPV4 address");
            @ipType = ('IP');
        } elsif ($converted_args{-iptype} =~ /V6/i) {
            $logger->debug(__PACKAGE__ . ".$sub_name: connection is estabilished using IPV6 address");
            @ipType = ('IPV6');
        } elsif ($converted_args{-iptype} =~ /any/i) {
            $logger->debug(__PACKAGE__ . ".$sub_name: connection is estabilished using IPV4 or IPV6 address");
            @ipType = ('IP', 'IPV6');
        } else {
            $logger->error(__PACKAGE__ . ".$sub_name: unknown iptype passed as argument");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
            exit;
         }
     }

    switch ($ats_obj_type) 
    {
        case /^GSX/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{MGMTNIF}->{3}->{IP},$alias_hashref->{MGMTNIF}->{2}->{IP},$alias_hashref->{MGMTNIF}->{4}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS GSX object.If unsuccessful ,exit will be called from SonusQA::GSX::new function
            $ats_obj_ref = SonusQA::GSX->new(-obj_hosts => ["$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                            "$alias_hashref->{MGMTNIF}->{3}->{IP}",
                                                            "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                            "$alias_hashref->{MGMTNIF}->{4}->{IP}"],
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -IGNOREXML => $ignore_xml,
                                             -obj_commtype => "TELNET",
                                             -sys_hostname => "$alias_hashref->{NODE}->{1}->{NAME}",
                                             %refined_args,
                                            );
           #Below lines of code to get NFS user name and password are added to replace the
           #hardcoded user name and password in GSXHELPER.pm
           my $NFSUSERID = $alias_hashref->{'NFS'}->{'1'}->{'USERID'};
           my $NFSPASSWD = $alias_hashref->{'NFS'}->{'1'}->{'PASSWD'};

           unless (defined $NFSUSERID && defined $NFSPASSWD) {
               $ats_obj_ref->{NFSUSERID} = 'root';
               $ats_obj_ref->{NFSPASSWD} = 'sonus';
               $logger->info(__PACKAGE__ . ".$sub_name: In TMS NFS user name and password is not added so taking the following default credentials");
               $logger->info(__PACKAGE__ . ".$sub_name: NFS user name --> $ats_obj_ref->{NFSUSERID} and password --> $ats_obj_ref->{NFSPASSWD}");
           } else {
               $ats_obj_ref->{NFSUSERID} = $NFSUSERID;
               $ats_obj_ref->{NFSPASSWD} = $NFSPASSWD;
               $logger->info(__PACKAGE__ . ".$sub_name: Following NFS user name and password are taken from TMS");
               $logger->info(__PACKAGE__ . ".$sub_name: NFS user name --> $ats_obj_ref->{NFSUSERID} and password --> TMS_ALIAS->NFS->1->PASSWD");
           }
        }

        case /(PSX|BRX)/
        {
            if (exists $alias_hashref->{SLAVE_CLOUD}){# Master Slave set-up
                $logger->debug(__PACKAGE__ . ".$sub_name: Copying cloud PSX management and signalling IP's");
                foreach $value ($alias_hashref->{SLAVE_CLOUD}->{1}->{USERID},$alias_hashref->{SLAVE_CLOUD}->{1}->{PASSWD}) {
                     unless (defined($value) && ($value  !~ m/^\s*$/)) {
                         $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters for cloud psx  could not be obtained for alias $tms_alias of object type $ats_obj_type");
                         $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                         exit;
                     }
                }
		if($args{-usemgmt}) { # TOOLS-17872
		    $alias_hashref->{NODE}->{1}->{IP}       = $alias_hashref->{SLAVE_CLOUD}->{1}->{IP} if(defined $alias_hashref->{SLAVE_CLOUD}->{1}->{IP});
                    $alias_hashref->{NODE}->{1}->{IPV6}     = $alias_hashref->{SLAVE_CLOUD}->{1}->{IPV6} if(defined $alias_hashref->{SLAVE_CLOUD}->{1}->{IPV6});
		} # {SLAVE_CLOUD}->{1}->{IP} - MGMT Ip and {SLAVE_CLOUD}->{2}->{IP} - Signalling Ip
		else {	
                    $alias_hashref->{NODE}->{1}->{IP}       = $alias_hashref->{SLAVE_CLOUD}->{2}->{IP} if(defined $alias_hashref->{SLAVE_CLOUD}->{2}->{IP});
                    $alias_hashref->{NODE}->{1}->{IPV6}     = $alias_hashref->{SLAVE_CLOUD}->{2}->{IPV6} if(defined $alias_hashref->{SLAVE_CLOUD}->{2}->{IPV6});
		}
                $alias_hashref->{LOGIN}->{1}->{USERID}  = $alias_hashref->{SLAVE_CLOUD}->{1}->{USERID};
                $alias_hashref->{LOGIN}->{1}->{PASSWD}  = $alias_hashref->{SLAVE_CLOUD}->{1}->{PASSWD};
                $alias_hashref->{NODE}->{1}->{HOSTNAME} = $alias_hashref->{SLAVE_CLOUD}->{1}->{HOSTNAME};
                $alias_hashref->{PKT_NIF}->{1}->{IP}    = $alias_hashref->{NODE}->{1}->{IP};
                $refined_args{-do_not_delete} = $alias_hashref->{DO_NOT_DELETE} unless (exists $refined_args{-do_not_delete});
		delete $alias_hashref->{DO_NOT_DELETE};
            }

            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            my $package = "SonusQA::$ats_obj_type";
            $package =~ s/\s//g; # removing all spaces just to be on safer side

            $refined_args{ "-rootpasswd" } = $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD};
            #TOOLS-17912
            my ($user,$password)  = ('admin',$alias_hashref->{LOGIN}->{3}->{PASSWD}||'admin');
            $refined_args{ '-obj_key_file' } = $alias_hashref->{LOGIN}->{2}->{KEY_FILE};

            #Have both IPV4 and IPV6 support TOOLS-9060
            my @objHosts = ();
            
            foreach my $ip_type (@ipType) {
                push (@objHosts, $alias_hashref->{NODE}->{1}->{$ip_type}) if defined $alias_hashref->{NODE}->{1}->{$ip_type};
                push (@{$alias_hashref->{MASTER_OBJHOSTS}}, $alias_hashref->{MGMTNIF}->{1}->{$ip_type}) if defined $alias_hashref->{MGMTNIF}->{1}->{$ip_type};
            }

            unless (@objHosts) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get host address");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            } 
            # Attempt to create ATS PSX object.If unsuccessful ,exit will be called from SonusQA::PSX::new function
            $ats_obj_ref = $package->new(-obj_hosts => \@objHosts, #TOOLS-9060
                                         -obj_user => $user,
                                         -obj_password => $password,
                                         -obj_commtype => "SSH",
                                         -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                         -tms_alias_data     => $alias_hashref,
                                         %refined_args,
                                         );
        }

        case /^(EMS_ASX|EMS_SUT)$/
        {
            # Check TMS alias login parameters are defined and not blank
            my ($objPassword, $userid, $newpassword) = ( $ats_obj_type =~/EMS_SUT/ )?($alias_hashref->{LOGIN}->{3}->{PASSWD}||'admin','admin', $alias_hashref->{LOGIN}->{3}->{NEWPASSWD}):($alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}, '');#TOOLS-17912

            foreach $value ( $alias_hashref->{NODE}->{1}->{IP} ,$alias_hashref->{LOGIN}->{1}->{USERID},$objPassword) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
	    $refined_args{ "-rootpasswd" } = $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD};
            $refined_args{ '-obj_key_file' } = $alias_hashref->{LOGIN}->{2}->{KEY_FILE};

            # Attempt to create ATS EMS object.If unsuccessful ,exit will be called from SonusQA::EMS::new function
            $ats_obj_ref = SonusQA::EMS->new(-obj_host =>  $alias_hashref->{NODE}->{1}->{IP},
                                             -obj_user => $userid,
                                             -obj_password => $objPassword,
                                             -newpassword => $newpassword,
                                             -obj_scriptDir => "$alias_hashref->{NODE}->{1}->{SCRIPT_DIR}",
                                             -obj_exeScript => "$alias_hashref->{NODE}->{1}->{EXECUTION_SCRIPT}",
                                             -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             -obj_commtype => "SSH",
                                             -IGNOREXML => $ignore_xml,
                                             %refined_args,
                                             -tms_alias_data     => $alias_hashref, #TOOLS-15398
                                            );
        }

     	case /^SILKTEST/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD})
                {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SILKTEST object.If unsuccessful ,exit will be called from SonusQA::ASX::new function
            $ats_obj_ref = SonusQA::SILKTEST->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_silkPath => "$alias_hashref->{NODE}->{1}->{SILKTEST_LOCATION}",
                                             -obj_commtype => "TELNET",
                                             %refined_args,
                                            );
        }
        case /^IAC/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ('IP','USERID')
                {
                unless (defined($alias_hashref->{LOGIN}->{1}->{$value}) && ($alias_hashref->{LOGIN}->{1}->{$value}  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameter {LOGIN}->{1}->{$value} is not passed for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SILKTEST object.If unsuccessful ,exit will be called from SonusQA::ASX::new function
            $ats_obj_ref = SonusQA::IAC->new(-obj_host => "$alias_hashref->{LOGIN}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_commtype => "SSH",
                                             -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             %refined_args,
                                            );
            $vm_ctrl_obj{$tms_alias} = $ats_obj_ref;
        }

        case /^EMS$/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD},$alias_hashref->{NODE}->{1}->{PORT}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
	    my $psx_alias = $ems_target_inst;
            # Check EMSCLI target instance is specified as 3rd argument
            unless ( defined($ems_target_inst) && ($ems_target_inst !~ m/^\s*$/)) {
                $logger->error(__PACKAGE__ . ".$sub_name:  \$ems_target_inst undefined or is blank");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            } else {
                my $ce = $main::TESTBED{$ems_target_inst};
                if( exists $main::TESTBED{$ce.":hash"}{'MASTER'} && $main::TESTBED{$ce.":hash"}{'MASTER'}{1}{NAME} ){ # For cloud PSX, will get slave name as target so changing it to master name
                    $ems_target_inst =  $main::TESTBED{$ce.":hash"}{'MASTER'}{1}{NAME} ;
                    $logger->debug(__PACKAGE__ . ".$sub_name: changing the target instance from $ems_target_inst to ".$main::TESTBED{$ce.":hash"}{'MASTER'}{1}{NAME});
                }
            }
            my @objHosts = ();
            foreach my $ip_type (@ipType) {
                push (@objHosts, $alias_hashref->{NODE}->{1}->{$ip_type}) if(exists $alias_hashref->{NODE}->{1}->{$ip_type});
            }
            unless (@objHosts) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get host address");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }
            # Attempt to create ATS EMSCLI object.If unsuccessful ,exit will be called from SonusQA::EMSCLI::new function
            $ats_obj_ref = SonusQA::EMSCLI->new(-obj_hosts => \@objHosts,
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             -IGNOREXML => $ignore_xml,
                                             -obj_port => "$alias_hashref->{NODE}->{1}->{PORT}",
                                             -obj_target => "$ems_target_inst",
                                             -psx_alias => $psx_alias,
					     -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
					     -associate_license=>1, 	
                                             %refined_args,
                                            );
        }

     case /^ASX/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{NAME},$alias_hashref->{LOGIN}->{1}->{PASSWD})
                {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS ASX object.If unsuccessful ,exit will be called from SonusQA::ASX::new function
            $ats_obj_ref = SonusQA::ASX->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{2}->{NAME}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{2}->{PASSWD}",
                                             -obj_commtype => "TELNET",
                                             -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             %refined_args,
                                            );
        }                                                                 

        case /^SGX$/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SGX object.If unsuccessful ,exit will be called from SonusQA::SGX::new function
            $ats_obj_ref = SonusQA::SGX->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                             );
        }

	#sasinha: Added DSC resolve alias lines
        case /^DSC$/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS DSC object.If unsuccessful ,exit will be called from SonusQA::DSC::new function
            $ats_obj_ref = SonusQA::DSC->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "root",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}",
                                             -obj_commtype => "SSH",
                                             -obj_hostname => "$alias_hashref->{CE}->{1}->{HOSTNAME}",
					     %refined_args,
                                             );
        }

        # scongdon: Added SGX4000 resolve alias lines.

        case /^SGX4000$/ {
            # Check TMS alias parameters are defined and not blank
            my %sgx4k_TmsAttributes = (

            # FOLLOWING are not used in existing scripts,
            # May be used in future scripts
            #    "CE_1_DOMAIN"            => $alias_hashref->{CE}->{1}->{DOMAIN}, #CE Domain
            #    "CE_1_LAB_ID"            => $alias_hashref->{CE}->{1}->{LAB_ID}, #Lab ID (If used)
            #    "CE_1_HW_PLATFORM"       => $alias_hashref->{CE}->{1}->{HW_PLATFORM}, #Hardware Type
            #    "CONFIG_1_IP"            => $alias_hashref->{CONFIG}->{1}->{IP}, #
            #    "CONFIG_1_HOSTNAME"      => $alias_hashref->{CONFIG}->{1}->{HOSTNAME}, #
            #    "CONFIG_1_ALOM_IP"       => $alias_hashref->{CONFIG}->{1}->{ALOM_IP}, #
            #    "CONFIG_1_ALOM_HOSTNAME" => $alias_hashref->{CONFIG}->{1}->{ALOM_HOSTNAME}, #
            #    "NODE_1_DISPLAY"         => $alias_hashref->{NODE}->{1}->{DISPLAY}, #
            #    "INTER_CE_NIF_1_IP"      => $alias_hashref->{INTER_CE_NIF}->{1}->{IP}, #Primary Inter CE NIF
            #    "INTER_CE_NIF_2_IP"      => $alias_hashref->{INTER_CE_NIF}->{2}->{IP}, #Secondary Inter CE NIF

            # Following are used in SGX4000 test suites - Mandatorly present in TMS
                "CE_1_HOSTNAME"          => $alias_hashref->{CE}->{1}->{HOSTNAME}, #CE Hostname
                "CONFIG_1_NAME"          => $alias_hashref->{CONFIG}->{1}->{NAME}, #Alias name present in EMS	
                "EXT_SIG_NIF_1_MASK"     => $alias_hashref->{EXT_SIG_NIF}->{1}->{MASK}, #Primary External Signaling NIF mask
                "EXT_SIG_NIF_1_IP"       => $alias_hashref->{EXT_SIG_NIF}->{1}->{IP}, #Primary External Signaling NIF
                "EXT_SIG_NIF_2_MASK"     => $alias_hashref->{EXT_SIG_NIF}->{2}->{MASK}, #Secondary External Signaling NIF mask
                "EXT_SIG_NIF_2_IP"       => $alias_hashref->{EXT_SIG_NIF}->{2}->{IP}, #Secondary External Signaling NIF
                "INT_SIG_NIF_1_MASK"     => $alias_hashref->{INT_SIG_NIF}->{1}->{MASK}, #Primary Internal Signaling NIF mask
                "INT_SIG_NIF_1_IP"       => $alias_hashref->{INT_SIG_NIF}->{1}->{IP}, #Primary Internal Signaling NIF
                "INT_SIG_NIF_2_MASK"     => $alias_hashref->{INT_SIG_NIF}->{2}->{MASK}, #Secondary Internal Signaling NIF mask
                "INT_SIG_NIF_2_IP"       => $alias_hashref->{INT_SIG_NIF}->{2}->{IP}, #Secondary Internal Signaling NIF
                "LOGIN_1_SERIALPASSWD"   => $alias_hashref->{LOGIN}->{1}->{SERIALPASSWD}, #Serial port password
                "LOGIN_1_SFTPPASSWD"     => $alias_hashref->{LOGIN}->{1}->{SFTPPASSWD}, #SFTP password
                "LOGIN_1_SFTP_ID"        => $alias_hashref->{LOGIN}->{1}->{SFTP_ID}, #SFTP login user ID
                "LOGIN_1_ROOTPASSWD"     => $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}, #root password for linux shell
                "LOGIN_1_USERID"         => $alias_hashref->{LOGIN}->{1}->{USERID}, #Admin user ID
                "LOGIN_1_REMOTE_ID"      => $alias_hashref->{LOGIN}->{1}->{REMOTE_ID}, #ATS server (Belur) remote user ID
                "LOGIN_1_PASSWD"         => $alias_hashref->{LOGIN}->{1}->{PASSWD}, #Admin password
                "LOGIN_1_DSHPASSWD"      => $alias_hashref->{LOGIN}->{1}->{DSHPASSWD}, #password for dsh / linuxadmin login
                "LOGIN_1_REMOTEPASSWD"   => $alias_hashref->{LOGIN}->{1}->{REMOTEPASSWD}, #ATS server (Belur) remote login password
                "MGMTNIF_1_IP"           => $alias_hashref->{MGMTNIF}->{1}->{IP}, #Primary Management NIF
                "MGMTNIF_2_IP"           => $alias_hashref->{MGMTNIF}->{2}->{IP}, #Secondary Management NIF
                "NODE_1_HOSTNAME"        => $alias_hashref->{NODE}->{1}->{HOSTNAME}, #ATS server (Belur) remote host
                "NODE_1_IP"              => $alias_hashref->{NODE}->{1}->{IP}, #ATS server (Belur) Remote IP
                "NODE_2_IP"              => $alias_hashref->{NODE}->{2}->{IP}, #Serial Port IP address
                "NODE_3_IP"              => $alias_hashref->{NODE}->{3}->{IP}, #NTP server 1 IP (bennevis)
                "NODE_4_IP"              => $alias_hashref->{NODE}->{4}->{IP}, #NTP server 2 IP (penfold)
                "NODE_5_IP"              => $alias_hashref->{NODE}->{5}->{IP}, #NTP server 3 IP (water)
                "NODE_6_IP"              => $alias_hashref->{NODE}->{6}->{IP}, #NTP server 4 IP (gwailor)
            );

            my @missingTmsValues;
            my $TmsAttributeFlag = 0;
            while ( my($key, $value) = each(%sgx4k_TmsAttributes) ){
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $TmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $TmsAttributeFlag == 1 ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }

            unless ( defined( $refined_args{ "-obj_user" } ) ) {
                $refined_args{ "-obj_user" } = $alias_hashref->{LOGIN}->{1}->{USERID};
                $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_user set to \'$refined_args{ -obj_user }\'");
            }

            if ( $refined_args{ "-obj_user" } eq "root" ) {
                unless ( defined( $refined_args{ "-obj_password" } ) ) {
                    $refined_args{ "-obj_password" } = $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD};
                    $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_password set to TMS_ALIAS->LOGIN->1->ROOTPASSWD");
                }
                unless ( defined( $refined_args{ "-obj_port" } ) ) {
                    $refined_args{ "-obj_port" } = 2024;
                    $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_port set to \'$refined_args{ -obj_port }\'");
                }
            }
            elsif ( $refined_args{ "-obj_user" } eq "$alias_hashref->{LOGIN}->{1}->{USERID}" ) {
                unless ( defined( $refined_args{ "-obj_password" } ) ) {
                    $refined_args{ "-obj_password" } = $alias_hashref->{LOGIN}->{1}->{PASSWD};
                    $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_password set to TMS_ALIAS->LOGIN->1->PASSWD");
                }
                unless ( defined( $refined_args{ "-obj_port" } ) ) {
                    $refined_args{ "-obj_port" } = 22;
                    $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_port set to \'$refined_args{ -obj_port }\'");
                }
            }

            unless ( defined( $refined_args{ "-obj_commtype" } ) ) {
                $refined_args{ "-obj_commtype" } = "SSH";
                $logger->debug(__PACKAGE__ . ".$sub_name:  -obj_commtype set to \'$refined_args{ -obj_commtype }\'");
            }


            # Attempt to create ATS SGX object.If unsuccessful ,exit will be called from SonusQA::SGX::new function
            $ats_obj_ref = SonusQA::SGX4000->new(-obj_hosts    => [
                                                                   "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                   "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                  ],
                                                 -obj_hostname => "$tms_alias",
                                                 -sys_hostname => "$alias_hashref->{CONFIG}->{1}->{HOSTNAME}",
                                                 %refined_args,
                                                );
        }

	    case /^D_SBC/ {
            $ats_obj_ref = SonusQA::SBX5000->new(
                                                 -tms_alias_data     => $alias_hashref,
                                                 -d_sbc              => 1,
                                                  %refined_args,
                                                );
        
	        #The sbx5000:1:ce0:hash should also have Signaling SBC and D_SBC testbed elements.
            if($ats_obj_ref){
                my $sbx_ce = $main::TESTBED{ $args{-tms_alias} };
                %{$main::TESTBED{$sbx_ce.":hash"}} = %{$ats_obj_ref->{TMS_ALIAS_DATA}} if(exists $ats_obj_ref->{TMS_ALIAS_DATA});
            }
        }

        case /^SBX5000$/ {
            $refined_args{-tms_alias_name} = $args{-tms_alias};
	    #The above statement is NOT redundant though it has been executed in line 119. As per revision 19015, line 119 was modified and it has dependency on this module and EMSCLI.pm as well
	    #So either EMSCLI or this module has to be modified accordingly. The latter was chosen.

            # TOOLS-17460: Use KEY_FILE for login, if {LOGIN}->{2}->{KEY_FILE} is set in TMS
            $refined_args{ '-obj_key_file' } = $alias_hashref->{LOGIN}->{2}->{KEY_FILE} if($alias_hashref->{LOGIN}->{2}->{KEY_FILE} && $alias_hashref->{LOGIN}->{1}->{USERID} eq 'admin');

            # some conditional circus for MGMTNIF check
            my @objHosts = ();
            my @mgmtNIF = (1,2);
                
            if ( defined $converted_args{-mgmtnif}) {
                if ($converted_args{-mgmtnif} =~ /(1|2|3|4)/) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: connection will made using only MGMTNIF->$1->IP");
                    @mgmtNIF = ($1);
                } else {
                    $logger->debug(__PACKAGE__ . ".$sub_name: unknow MGMTNIF value passed");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit 
                }
            }

            foreach my $ip_type (@ipType) {
                foreach (@mgmtNIF) {
                    push (@objHosts, $alias_hashref->{MGMTNIF}->{$_}->{$ip_type}) if defined $alias_hashref->{MGMTNIF}->{$_}->{$ip_type};
                }
            }

            unless (@objHosts) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to get host address");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            $refined_args{-do_not_delete} = 1 if ($alias_hashref->{VM_HOST}->{1}->{IP}) ;
            #HA setup
            if (!$refined_args{-ha_setup} and $female ) {
                $refined_args{-ha_setup} = 1;
                $ats_obj_ref = SonusQA::SBX5000::SBXLSWUHELPER::connectTOActive( -devices => [$tms_alias, $female], -debug => $refined_args{-sessionlog}, %refined_args);

            } else {
            # Attempt to create ATS SBX object.If unsuccessful ,exit will be called from SonusQA::SBX::new function
                $ats_obj_ref = SonusQA::SBX5000->new(-obj_hosts         => \@objHosts, 
                                                     -obj_hostname      => "$tms_alias",
                                                     -obj_user          => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                                     -obj_password      => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                                     -obj_commtype      => "SSH",
                                                     -sys_hostname      => "$alias_hashref->{CE}->{1}->{HOSTNAME}",
                                                     -tms_alias_data    => $alias_hashref,
                                                     -return_on_fail    => 1,
                                                     -failures_threshold => $threshold,
                                                     %refined_args,
                                                    );

            }
        }

     case /^SBCEDGE/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{LOGIN}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}){

                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SBCEDGE object.If unsuccessful ,exit will be called from SonusQA::SBCEDGE::new function
            $ats_obj_ref = SonusQA::SBCEDGE->new(-obj_baseurl => "https://".$alias_hashref->{LOGIN}->{1}->{IP}."/",
                                             -obj_user => $alias_hashref->{LOGIN}->{1}->{USERID},
                                             -obj_password => $alias_hashref->{LOGIN}->{1}->{PASSWD},
                                             -tms_alias_data    => $alias_hashref,
                                             %refined_args,
                                            );
        }

     case /^BGF$/ {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS BGF object.If unsuccessful ,exit will be called from SonusQA::SBX::new function
            $ats_obj_ref = SonusQA::BGF->new(-obj_hosts         => [
                                                                        "$alias_hashref->{NODE}->{1}->{IP}",
                                   #                                     "$alias_hashref->{MGMTNIF}->{2}->{IP}",
                                                                       ],
                                                 -obj_hostname      => "$tms_alias",
                                                 -obj_user          => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                                 -obj_password      => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                                 -obj_commtype      => "SSH",
                                                 %refined_args,
                                                );
        }

        case /^EAST$/ {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS EAST object.If unsuccessful ,exit will be called from SonusQA::EAST::new function
            $ats_obj_ref = SonusQA::EAST->new(   -obj_host          => "$alias_hashref->{NODE}->{1}->{IP}",
                                                 -obj_user          => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                                 -obj_password      => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                                 -obj_commtype      => "SSH",
                                                 %refined_args,
                                                );
        }

        case /MGTS/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD},$alias_hashref->{NODE}->{1}->{HOSTNAME},$alias_hashref->{NODE}->{1}->{DISPLAY}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Populate fish_hook if it exists
            if ( defined ( $alias_hashref->{FISH_HOOK}->{1}->{PORT} ) && ( $alias_hashref->{FISH_HOOK}->{1}->{PORT} !~ m/^\s*$/ ) ) {
                $refined_args{ -fish_hook_port } = $alias_hashref->{FISH_HOOK}->{1}->{PORT};
            }

            # Attempt to create ATS MGTS object.If unsuccessful ,exit will be called from SonusQA::MGTS::new function
            $ats_obj_ref = SonusQA::MGTS->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -shelf => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             -shelf_version => "$alias_hashref->{NODE}->{1}->{HW_PLATFORM}",
                                             -display => "$alias_hashref->{NODE}->{1}->{DISPLAY}", 
                                             -protocol => "ANSI-SS7",
                                             -sys_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                             %refined_args,
                                            );
        }

        case /(SIPP|LISERVER|SEAGULL|DNS|TOOLS|RADIUS|SWITCH|RSM|POSTMAN|VNFM_CLI|VMCCS)/
        {
	    my @userid = qx#id -un#;
	    chomp @userid;
            unless ( $alias_hashref->{LOGIN}->{1}->{USERID} ){
                $alias_hashref->{LOGIN}->{1}->{USERID} = $userid[0];
            }
	    my @requiredattributes = ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID});
	    unless ( $alias_hashref->{LOGIN}->{1}->{USERID} eq $userid[0] || $refined_args{'-obj_key_file'} ){
		push @requiredattributes, $alias_hashref->{LOGIN}->{1}->{PASSWD};
	    }
            # Check TMS alias login parameters are defined and not blank
            foreach $value (@requiredattributes) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SIPP/LISERVER/SEAGULL/DNS/RSM/POSTMAN object.If unsuccessful ,exit will be called from SonusQA::[SIPP|LISERVER|SEAGULL|DNS]::new function
            my $package = "SonusQA::$ats_obj_type";
            $package =~ s/\s//g; # removing all spaces just to be on safer side
	    if ($ats_obj_type eq 'TOOLS'){
	        $refined_args{-basepath} ||= "$alias_hashref->{NODE}->{1}->{BASEPATH}" if (exists $alias_hashref->{NODE}->{1}->{BASEPATH});
		$refined_args{-ntp_ip}  ||= "$alias_hashref->{NTP}->{1}->{IP}" if (exists $alias_hashref->{NTP}->{1}->{IP});
	        $refined_args{-ntp_tz}  ||= "$alias_hashref->{NTP}->{1}->{TIMEZONE}" if (exists $alias_hashref->{NTP}->{1}->{TIMEZONE});
		$refined_args{-ntp_sync}  ||= "$alias_hashref->{NTP}->{1}->{SYNC}" if (exists $alias_hashref->{NTP}->{1}->{SYNC});	
	    }
	    my $port = $alias_hashref->{NODE}->{1}->{PORT} || 22; 
            #Taking {MGMTNIF}->{1}->{IP} as the first preference to fix TOOLS-5898
            my $threshold = ($ats_obj_type eq 'VMCCS')?5:2 ; #Making failure threshold as 5 since VMCCS doesn't come up after 2 retries
             my $obj_host = ($ats_obj_type eq 'SIPP' and $alias_hashref->{MGMTNIF}->{1}->{IP}) ? $alias_hashref->{MGMTNIF}->{1}->{IP} : $alias_hashref->{NODE}->{1}->{IP};
            $ats_obj_ref = $package->new(-obj_host => $obj_host, 
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_login_type => $alias_hashref->{LOGIN}->{1}->{TYPE},
                                             -obj_node_type => $alias_hashref->{NODE}->{1}->{TYPE},
                                             -obj_commtype => "SSH",
					     -obj_port => $port,
                                            -failures_threshold => $threshold,
                                             %refined_args,
        	                                    );
             #TOOLS-6277
	     if (defined $sbxObjradius and $ats_obj_type eq "RADIUS") {
			$logger->debug(__PACKAGE__ . ".$sub_name:  Assigning IP's and Hostname from SBX object");
			$alias_hashref->{MGMTNIF}->{1}->{IP} = $sbxObjradius->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP} if($sbxObjradius->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP});
			$alias_hashref->{MGMTNIF}->{2}->{IP} = $sbxObjradius->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{IP} if($sbxObjradius->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{IP});
			if($sbxObjradius->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}){
				$alias_hashref->{NODE}->{1}->{HOSTNAME} = $sbxObjradius->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}."_mgt0";
				$alias_hashref->{NODE}->{2}->{HOSTNAME} = $sbxObjradius->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME}."_mgt1";
	    		}	 
	    }
	}

        case /DIAMAPP/
        {              
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                   $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                   $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                   exit;
                }
         }    

            # Attempt to create ATS DIAMAPP object.If unsuccessful ,exit will be called from SonusQA::DIAMAPP::new function
            $ats_obj_ref = SonusQA::DIAMAPP->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                              -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                              -obj_commtype => "SSH",
                                              %refined_args,
                                            );
        }

        
        case /ROUTER/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS ROUTER object.If unsuccessful ,exit will be called from SonusQA::ROUTER::new function
            $ats_obj_ref = SonusQA::ROUTER->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "TELNET",
                                             %refined_args,
                                            );
        }
               
        case /GBL/
        {
            my @userid = qx#id -un#;
            chomp @userid;
	    unless ( $alias_hashref->{LOGIN}->{1}->{USERID} ){
		$alias_hashref->{LOGIN}->{1}->{USERID} = $userid[0];		
	    }	
            my @requiredattributes = ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID});
            unless ( $alias_hashref->{LOGIN}->{1}->{USERID} eq $userid[0] ){
                push @requiredattributes, $alias_hashref->{LOGIN}->{1}->{PASSWD};
            }
            # Check TMS alias login parameters are defined and not blank
            foreach $value (@requiredattributes) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS GBL object.If unsuccessful ,exit will be called from SonusQA::GBL::new function
            $ats_obj_ref = SonusQA::GBL->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );

        }
	case /VIGIL/
        {
            foreach $value ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            $ats_obj_ref = SonusQA::VIGIL->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );

        }

        case /GLCAS/
        {
            my $package = "SonusQA::$ats_obj_type";
            $package =~ s/\s//g;
            # check TMS alias login parameters are defined and not blank
            foreach $value($alias_hashref->{NODE}->{1}->{IP}, $alias_hashref->{LOGIN}->{1}->{USERID}, $alias_hashref->{LOGIN}->{1}->{PASSWD}) {

                unless (defined ($value) && ($value !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS Selenium Object.  If unsuccessful, exit will be called from SonusQA::Selenium::new function

            $ats_obj_ref = $package->new(
                                        -obj_host => "$alias_hashref->{NODE}->{1}->{IP}" ,
                                        -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                        -obj_password  => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                        -obj_commtype => "TELNET",
                                        %refined_args,
                                        ) ;

        }

        case /(C3|CRS|AMA|NDM|AS|SST|C20|GVPP|SDIN)/
        {
            my $package = "SonusQA::$ats_obj_type";
            $package =~ s/\s//g;
            foreach $value ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters ({MGMTNIF}->{1}->{IP},{LOGIN}->{1}->{USERID},{LOGIN}->{1}->{PASSWD}) could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            $refined_args{-rootpasswd} = "$alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}" if ($ats_obj_type =~ /NDM/);
            $ats_obj_ref = $package->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_port => $alias_hashref->{MGMTNIF}->{1}->{PORT} || 22,
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );

        }
        case /NETEM/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS NETEM object.If unsuccessful ,exit will be called from SonusQA::NETEM::new function
            $ats_obj_ref = SonusQA::NetEm->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );
        }
        case /^MSX$/
        {

            # Check TMS alias parameters are defined and not blank
            my %MSX_TmsAttributes = (
                "NODE_IP"          => $alias_hashref->{NODE}->{1}->{IP},
                "NODE_HOSTNAME"    => $alias_hashref->{NODE}->{1}->{HOSTNAME},
                "NODE_HW_PLATFORM" => $alias_hashref->{NODE}->{1}->{HW_PLATFORM},
                "LOGIN_USERID"     => $alias_hashref->{LOGIN}->{1}->{USERID},
                "LOGIN_PASSWD"     => $alias_hashref->{LOGIN}->{1}->{PASSWD},
                "TL1_USERID"       => $alias_hashref->{TL1}->{1}->{USERID},
                "TL1_PASSWD"       => $alias_hashref->{TL1}->{1}->{PASSWD},
                "CONSOLE_USERID"   => $alias_hashref->{CONSOLE}->{1}->{USERID},
                "CONSOLE_PASSWD"   => $alias_hashref->{CONSOLE}->{1}->{PASSWD},
            );

            my @missingTmsValues;
            my $missingTmsAttributeFlag = 0;
            while ( my($key, $value) = each(%MSX_TmsAttributes) ){
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $missingTmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $missingTmsAttributeFlag == 1 ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }

            # Attempt to create ATS MSX object.If unsuccessful, exit will be called from SonusQA::MSX::new function
            $ats_obj_ref = SonusQA::MSX->new(
                                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                              -obj_commtype => "SSH",
                                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                              %refined_args,
                                            );
        }
        #Ameritec - Fortissimo DS3 model call generator tool
       case /FORTISSIMO/
        {
            # Check TMS alias parameters are defined and not blank
            my %FORTISSIMO_TmsAttributes = (
                "NODE_IP"          => $alias_hashref->{NODE}->{1}->{IP},

            );

            my @missingTmsValues;
            my $missingTmsAttributeFlag = 0;
            while ( my($key, $value) = each(%FORTISSIMO_TmsAttributes) ){  #check the madatory attributes from TMS
                     unless (defined($value) && ($value  !~ m/^\s*$/)) {
                        $missingTmsAttributeFlag = 1;
                        push ( @missingTmsValues, $key );
                }
            }

            if ( $missingTmsAttributeFlag == 1 ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }

            # Attempt to create ATS FORTISSIMO object.If unsuccessful, exit will be called from SonusQA::FORTISSIMO::new function
            $ats_obj_ref = SonusQA::FORTISSIMO->new(
                                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                              -obj_commtype => "TELNET",
                                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                              %refined_args,
                                            );
        }  #End FORTISSIMO Switch-Case
        case /^BSX$/
        {

            # Check TMS alias parameters are defined and not blank
            my %BSX_TmsAttributes = (
                "NODE_IP"          => $alias_hashref->{NODE}->{1}->{IP},
                "NODE_HOSTNAME"    => $alias_hashref->{NODE}->{1}->{HOSTNAME},
                "NODE_HW_PLATFORM" => $alias_hashref->{NODE}->{1}->{HW_PLATFORM},
                "LOGIN_USERID"     => $alias_hashref->{LOGIN}->{1}->{USERID},
                "LOGIN_PASSWD"     => $alias_hashref->{LOGIN}->{1}->{PASSWD},
                "TL1_USERID"       => $alias_hashref->{TL1}->{1}->{USERID},
                "TL1_PASSWD"       => $alias_hashref->{TL1}->{1}->{PASSWD},
                "CONSOLE_USERID"   => $alias_hashref->{CONSOLE}->{1}->{USERID},
                "CONSOLE_PASSWD"   => $alias_hashref->{CONSOLE}->{1}->{PASSWD},
            );

            my @missingTmsValues;
            my $missingTmsAttributeFlag = 0;
            while ( my($key, $value) = each(%BSX_TmsAttributes) ){
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $missingTmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $missingTmsAttributeFlag == 1 ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }

            # Attempt to create ATS BSX object.If unsuccessful, exit will be called from SonusQA::BSX::new function
            $ats_obj_ref = SonusQA::BSX->new(
                                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                              -obj_commtype => "SSH",
                                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",
                                              -obj_port     => 2024,
                                              %refined_args,
                                            );
        }
        case /^MGW9000/
        {
            # Check TMS alias parameters are defined and not blank
            my %MGW9000_TmsAttributes = (
                # Login - Details
                'LOGIN_1_USERID' => $alias_hashref->{LOGIN}->{1}->{USERID},
                'LOGIN_1_PASSWD' => $alias_hashref->{LOGIN}->{1}->{PASSWD},

                # Management Network Interface - Details
                'MGMTNIF_1_SLOT'            => $alias_hashref->{MGMTNIF}->{1}->{SLOT},
                'MGMTNIF_1_MASK'            => $alias_hashref->{MGMTNIF}->{1}->{MASK},
                'MGMTNIF_1_IP'              => $alias_hashref->{MGMTNIF}->{1}->{IP},
                'MGMTNIF_1_DEFAULT_GATEWAY' => $alias_hashref->{MGMTNIF}->{1}->{DEFAULT_GATEWAY},
                'MGMTNIF_1_INTERFACE'       => $alias_hashref->{MGMTNIF}->{1}->{INTERFACE},
#                $alias_hashref->{MGMTNIF}->{3}->{IP},
#                $alias_hashref->{MGMTNIF}->{2}->{IP},
#                $alias_hashref->{MGMTNIF}->{4}->{IP},

                # NFS - Details
                'NFS_1_NFSTYPE'         => $alias_hashref->{NFS}->{1}->{NFSTYPE},
                'NFS_1_LOCAL_BASE_PATH' => $alias_hashref->{NFS}->{1}->{LOCAL_BASE_PATH},
                'NFS_1_BASEPATH'        => $alias_hashref->{NFS}->{1}->{BASEPATH},
                'NFS_1_IP'              => $alias_hashref->{NFS}->{1}->{IP},
                'NFS_1_HOSTNAME'        => $alias_hashref->{NFS}->{1}->{HOSTNAME},

                # NIF - Details
                'NIF_1_SLOT'            => $alias_hashref->{NIF}->{1}->{SLOT},
                'NIF_1_MASK'            => $alias_hashref->{NIF}->{1}->{MASK},
                'NIF_1_TYPE'            => $alias_hashref->{NIF}->{1}->{TYPE},
                'NIF_1_DEFAULT_GATEWAY' => $alias_hashref->{NIF}->{1}->{DEFAULT_GATEWAY},
                'NIF_1_IP'              => $alias_hashref->{NIF}->{1}->{IP},
                'NIF_1_INTERFACE'       => $alias_hashref->{NIF}->{1}->{INTERFACE},

                # Node Details
                'NODE_1_SONICID'     => $alias_hashref->{NODE}->{1}->{SONICID},
                'NODE_1_TYPE'        => $alias_hashref->{NODE}->{1}->{TYPE},
                'NODE_1_NAME'        => $alias_hashref->{NODE}->{1}->{NAME},
#                'NODE_1_LOGICAL_IP'  => $alias_hashref->{NODE}->{1}->{LOGICAL_IP},
                'NODE_1_HW_PLATFORM' => $alias_hashref->{NODE}->{1}->{HW_PLATFORM},

                # SPAN - Origination & Termination spans used for physical loopback
                'NODE_1_ORIG_SPAN'    => $alias_hashref->{NODE}->{1}->{ORIG_SPAN},
                'NODE_1_TERM_SPAN'    => $alias_hashref->{NODE}->{1}->{TERM_SPAN},

                # Signalling Gateway - Details
#                'SIG_GW_1_PORT'      => $alias_hashref->{SIG_GW}->{1}->{PORT},
#                'SIG_GW_1_INTERFACE' => $alias_hashref->{SIG_GW}->{1}->{INTERFACE},
#                'SIG_GW_1_IP'        => $alias_hashref->{SIG_GW}->{1}->{IP},
            );
            
            my @missingTmsValues;
            my $missingTmsAttributeFlag = 0;
            while ( my($key, $value) = each(%MGW9000_TmsAttributes) ) {
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $missingTmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $missingTmsAttributeFlag == 1 ) {
                $logger->error(" FAILED - TMS alias parameters for alias $tms_alias of type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(" FAILED - TMS attribute $key is not present OR empty");
                }
                $logger->debug(" Leaving $sub_name [exit]");
                exit;
            }

            # Attempt to create ATS MGW9000 object.If unsuccessful,
            # exit will be called from SonusQA::MGW9000::new function
            $ats_obj_ref = SonusQA::MGW9000->new(
                            -obj_hosts => [
                                            "$alias_hashref->{MGMTNIF}->{1}->{IP}",
#                                            "$alias_hashref->{MGMTNIF}->{3}->{IP}",
#                                            "$alias_hashref->{MGMTNIF}->{2}->{IP}",
#                                            "$alias_hashref->{MGMTNIF}->{4}->{IP}",
                                          ],
                            -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                            -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                            -IGNOREXML    => $ignore_xml,
                            -obj_commtype => "TELNET",
                            %refined_args,
                        );
        }
        case /^NAVTEL$/
        {

            # Check TMS alias parameters are defined and not blank
            my %NAVTEL_TmsAttributes = (
                "NODE_IP"          => $alias_hashref->{NODE}->{1}->{IP},
                "LOGIN_USERID"     => $alias_hashref->{LOGIN}->{1}->{USERID},
                "LOGIN_PASSWD"     => $alias_hashref->{LOGIN}->{1}->{PASSWD},
                "NODE_HOSTNAME"    => $alias_hashref->{NODE}->{1}->{HOSTNAME},
            );

            my @missingTmsValues;
            my $missingTmsAttributeFlag = 0;
            while ( my($key, $value) = each(%NAVTEL_TmsAttributes) ){
             
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                     $missingTmsAttributeFlag = 1;
                     push ( @missingTmsValues, $key );
                }
            }

            if ( $missingTmsAttributeFlag == 1 ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                foreach my $key (@missingTmsValues) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS value for attribute $key is not present OR empty");
                }
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                exit;
            }

            # Attempt to create ATS NAVTEL object.If unsuccessful, exit will be called from SonusQA::NAVTEL::new function
            $ats_obj_ref = SonusQA::NAVTEL->new(
                                              -obj_host     => "$alias_hashref->{NODE}->{1}->{IP}",
                                              -obj_user     => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                              -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                              -obj_commtype => "TELNET",
                                              -obj_hostname => "$alias_hashref->{NODE}->{1}->{HOSTNAME}",                                              %refined_args,
                                            );
        }
        case /IXIA/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD},$alias_hashref->{DUT}->{1}->{IP}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS IXIA object.If unsuccessful ,exit will be called from SonusQA::IXIA::new function
            $ats_obj_ref = SonusQA::IXIA->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -ixia_server => $alias_hashref->{DUT}->{1}->{IP},
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );
        }
        case /IXLOAD/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD},$alias_hashref->{DUT}->{1}->{IP}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS IXLOAD object.If unsuccessful ,exit will be called from SonusQA::IXLOAD::new function
            $ats_obj_ref = SonusQA::IXLOAD->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             %refined_args,
                                            );
        }
        case /SELENIUM|GLISUP/
        {
            my $package = "SonusQA::$ats_obj_type";
            $package =~ s/\s//g;
            # check TMS alias login parameters are defined and not blank
            foreach $value($alias_hashref->{NODE}->{1}->{IP}, $alias_hashref->{LOGIN}->{1}->{USERID}, $alias_hashref->{LOGIN}->{1}->{PASSWD}) {

                unless (defined ($value) && ($value !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS Selenium Object.  If unsuccessful, exit will be called from SonusQA::Selenium::new function

            $ats_obj_ref = $package->new(
                                            -obj_host => "$alias_hashref->{NODE}->{1}->{IP}" ,
                                            -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                            -obj_password  => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                            -obj_port => "$alias_hashref->{NODE}->{1}->{PORT}", 
                                            -obj_commtype => "TELNET",
                                            %refined_args,
                                            ) ;

        }

        case /RACOON/
        {
            # check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP}, $alias_hashref->{LOGIN}->{1}->{USERID}, $alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined ($value) && ($value !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS RACOON Object.  If unsuccessful, exit will be called from SonusQA::RACOON::new function
            $ats_obj_ref = SonusQA::RACOON->new(
                                            -obj_host => "$alias_hashref->{NODE}->{1}->{IP}" ,
                                            -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                            -obj_password  => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                            -preshared_key => "$alias_hashref->{IPSEC}->{1}->{REMOTEPASSWD}",
                                            -racoon_ip => "$alias_hashref->{NODE}->{1}->{IP}",
                                            -nif_ip => "$alias_hashref->{NIF}->{1}->{IP}",
                                            -sipsig_ip => "$alias_hashref->{SIG_SIP}->{1}->{IP}",
                                            -obj_commtype => "SSH",
                                            %refined_args,
                                            ) ;
        } 

        case /^LYNC$/
        {
            $refined_args{-tms_alias_name} = $args{-tms_alias};
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP}, $alias_hashref->{NODE}->{1}->{PORT}, $alias_hashref->{LOGIN}->{1}->{USERID}, $alias_hashref->{LOGIN}->{1}->{PASSWD}, $alias_hashref->{NODE}->{1}->{NUMBER}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS LYNC object.If unsuccessful ,exit will be called from SonusQA::LYNC::new function
            $ats_obj_ref = SonusQA::LYNC->new(
                                               -obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                               -obj_user => "$alias_hashref->{NODE}->{1}->{USERID}" ,
                                                -obj_password =>  "$alias_hashref->{NODE}->{1}->{PASSWD}",
                                                -comm_type => 'SSH',
                                                -tms_alias_data     => $alias_hashref,
                                                %refined_args,
                                             );

        }

        case /^LYNCSERVER$/
        {
            $refined_args{-tms_alias_name} = $args{-tms_alias};
            # Check TMS alias login parameters are defined and not blank
            foreach $value ( $alias_hashref->{NODE}->{1}->{IP}, $alias_hashref->{NODE}->{1}->{PORT}, $alias_hashref->{NODE}->{1}->{GATEWAY} ) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS LYNCSERVER object.If unsuccessful ,exit will be called from SonusQA::LYNCSERVER::new function
            $ats_obj_ref = SonusQA::LYNCSERVER->new(
                                             %refined_args,
                                             );

        }

        case /PROLAB/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD},$alias_hashref->{TERMINAL_SERVER}->{1}->{IP},$alias_hashref->{TERMINAL_SERVER}->{1}->{USERID},$alias_hashref->{TERMINAL_SERVER}->{1}->{PASSWD},$alias_hashref->{TERMINAL_SERVER}->{1}->{PORT},$alias_hashref->{TERMINAL_SERVER}->{2}->{PORT}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS PROLAB object.If unsuccessful ,exit will be called from SonusQA::PROLAB::new function
            $ats_obj_ref = SonusQA::PROLAB->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                                -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                                -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                                -prolab_host => "$alias_hashref->{TERMINAL_SERVER}->{1}->{IP}",
                                                -prolab_user => "$alias_hashref->{TERMINAL_SERVER}->{1}->{USERID}",
                                                -prolab_password => "$alias_hashref->{TERMINAL_SERVER}->{1}->{PASSWD}",
                                                -agent_port => "$alias_hashref->{TERMINAL_SERVER}->{2}->{PORT}",
                                                -test_manager_port => "$alias_hashref->{TERMINAL_SERVER}->{1}->{PORT}",
                                                -obj_commtype => "SSH",
                                                %refined_args,
                                               );
        }
        case /DSI/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS DSI object.If unsuccessful ,exit will be called from SonusQA::DSI::new function
            $ats_obj_ref = SonusQA::DSI->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             -tms_alias_data    => $alias_hashref,
                                             %refined_args,
                                            );
        }
        case /SPECTRA2/
        {
            # Check TMS alias login parameters are defined and not blank, using for loop just incase manditory records increses
            foreach $value ($alias_hashref->{NODE}->{1}->{IP}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS SPECTRA2 object.If unsuccessful ,exit will be called from SonusQA::SPECTRA2::new function
            $ats_obj_ref = SonusQA::SPECTRA2->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_commtype => "TELNET",
                                             %refined_args,
                                            );
        }
        case /VALID8/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }

            # Attempt to create ATS VALID8 object.If unsuccessful ,exit will be called from SonusQA::VALID8::new function
            $ats_obj_ref = SonusQA::VALID8->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_commtype => "NONE",
                                             %refined_args,
                                            );
        }
        case /^VM_CONTROLLER$/ {
	    chomp (my ($userid) = qx#id -un#);
            unless ( $alias_hashref->{LOGIN}->{1}->{USERID} ){
                $alias_hashref->{LOGIN}->{1}->{USERID} = $userid;
            }

            my @requiredattributes = ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID});
            unless ( $alias_hashref->{LOGIN}->{1}->{USERID} eq $userid || $refined_args{'-obj_key_file'} ){
                push @requiredattributes, $alias_hashref->{LOGIN}->{1}->{PASSWD};
            }
            # Check TMS alias login parameters are defined and not blank
            foreach $value (@requiredattributes) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS VM_CONTROLLER object.If unsuccessful ,exit will be called from SonusQA::VMCTRL::new function
            $ats_obj_ref = SonusQA::VMCTRL->new(-obj_hosts         => [
                                                                       "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                                                       ],
                                                 -obj_hostname      => "$tms_alias",
                                                 -obj_user          => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                                 -obj_password      => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                                 -obj_commtype      => "SSH",
                                                 -tms_alias_data    => $alias_hashref,
                                                 %refined_args,
                                                );
           $vm_ctrl_obj{$tms_alias} = $ats_obj_ref;
        }
        case /^CDA$/
        {
            # Check TMS alias login parameters are defined and not blank
            foreach $value ($alias_hashref->{NODE}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}, $alias_hashref->{LOGIN}->{1}->{ROOTPASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
            # Attempt to create ATS CDA object.If unsuccessful ,exit will be called from SonusQA::CDA::new function
            my $port = $alias_hashref->{NODE}->{1}->{PORT} || 22;
            $ats_obj_ref = SonusQA::CDA->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_commtype => "SSH",
                                             -obj_port     => $port,
                                             -tms_alias_data    => $alias_hashref,
                                             %refined_args,
                                            );
        }
	case /^POLYCOM$/
	{
	    $refined_args{-tms_alias_name} = $args{-tms_alias};

	    # Attempt to create ATS POLYCOM object.If unsuccessful ,exit will be called from SonusQA::POLYCOM::new function
	    $ats_obj_ref = SonusQA::POLYCOM->new(-phoneip          => "$alias_hashref->{NODE}{1}{IP}",
						 -phoneport        => "$alias_hashref->{NODE}{1}{PORT}",
 					         -pushuserid       => "$alias_hashref->{LOGIN}{1}{USERID}",
        					 -pushpassword     => "$alias_hashref->{LOGIN}{1}{PASSWD}",
        					 -spipuserid       => "$alias_hashref->{LOGIN}{2}{USERID}",
					         -spippassword     => "$alias_hashref->{LOGIN}{2}{PASSWD}",
        					 -http_server_ip   => "$alias_hashref->{HTTPSERVER}{1}{IP}",
        					 -http_server_port => "$alias_hashref->{HTTPSERVER}{1}{PORT}",
        					 -http_server_path => "$alias_hashref->{HTTPSERVER}{1}{BASEPATH}",
        					 -number           => "$alias_hashref->{NODE}{1}{NUMBER}",
						 %refined_args,
						);
	}
	case /^QSBC$/
        {
            # Attempt to create ATS  object.If unsuccessful ,exit will be called from SonusQA::POLYCOM::new function
            $ats_obj_ref = SonusQA::QSBC->new(-obj_host         => "$alias_hashref->{MGMTNIF}{1}{IP}",
                                              -obj_port         => "22",
                                              -obj_user         => "$alias_hashref->{LOGIN}{1}{USERID}",
                                              -obj_password     => "$alias_hashref->{LOGIN}{1}{PASSWD}",
                                              -obj_commtype     => "SSH",
                                              -tms_alias_data   => $alias_hashref,
                                              %refined_args,
                                             );
        }
        case /VNFM/
        {
            foreach $value ($alias_hashref->{MGMTNIF}->{1}->{IP},$alias_hashref->{LOGIN}->{1}->{USERID},$alias_hashref->{LOGIN}->{1}->{PASSWD}) {
                unless (defined($value) && ($value  !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name:  TMS alias login parameters could not be obtained for alias $tms_alias of object type $ats_obj_type");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
                    exit;
                }
            }
	     my $package = "SonusQA::$ats_obj_type";
	     
             $ats_obj_ref = $package->new(-obj_host          => $alias_hashref->{MGMTNIF}->{1}->{IP},
					       -port              => $alias_hashref->{MGMTNIF}->{1}->{PORT},
                                               -username          => $alias_hashref->{LOGIN}->{1}->{USERID},
                                               -password          => $alias_hashref->{LOGIN}->{1}->{PASSWD},
                                               -tms_alias_data    => $alias_hashref,
                                               %refined_args,
                                            );
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Invalid object type $ats_obj_type specified");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name [exit]");
            exit;
        }
    } # End switch
    unless($ats_obj_ref){
	my $vmCtrlAlias = $alias_hashref->{VM_CTRL}->{2}->{NAME} || $alias_hashref->{VM_CTRL}->{1}->{NAME};
        if ($vmCtrlAlias and !$refined_args{DO_NOT_DELETE} and $alias_hashref->{CE_CREATED}) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Deleting the Cloud Instance ".$alias_hashref->{'CE_NAME'});
            $vm_ctrl_obj{$vmCtrlAlias}->deleteInstance($alias_hashref->{'CE_NAME'});
            $logger->debug(__PACKAGE__ . ".$sub_name: Cloud Instance deleted");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed to create ats_obj_ref");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $main::TESTBED{$ce.':hash'}->{RESOLVE_CLOUD} = 1 if ($resolve_cloud) ;
    if ($alias_hashref->{CE_NAME}){
        $ats_obj_ref->{CE_NAME} = $alias_hashref->{CE_NAME};
    }
    # Add TMS alias data to the newly created ATS object for later use
    $ats_obj_ref->{TMS_ALIAS_DATA} = $alias_hashref unless ($ats_obj_ref->{TMS_ALIAS_DATA});

    # Add the TMS alias name to the TMS ALAIAS DATA
    $ats_obj_ref->{TMS_ALIAS_DATA}->{ALIAS_NAME} =  $tms_alias;

    $logger->debug(__PACKAGE__ . ".$sub_name Leaving $sub_name [obj:$ats_obj_type]");    
    return $ats_obj_ref;

} # End sub newFromAlias

=head2 resolveHashFromAliasArray()

=over

=item DESCRIPTION:

This function takes an input array of tms aliases, iterates though them and returns back to the user a hash of all resolved tms aliases. The leg work of this process is done by the function populateTestbedHashFromAliasList(). For further details on the format of the return hash, please see that function.

=item ARGUMENTS:

An array of tms aliases
@TESTBED = (
               [ asterix, obelix ],    <-- SGX4000 Dual CE
               loner,                  <-- SGX4000 Single CE
               viper,                  <-- GSX
               tomcat,                 <-- GSX
           );
The order in which the like devices are specfied will be the order in which they are referenced
once resolved. 

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

SonusQA::ATSHELPER::populateTestbedHashFromAliasList()

=item RETURNS:

%TESTBED - TESTBED hash
0        - otherwise

=item EXAMPLE:

my %TESTBED = SonusQA::ATSHELPER::resolveHashFromAliasArray( -input_array  => \@TESTBED );

=back

=cut

sub resolveHashFromAliasArray {

    my %args        = @_;

    my $resolved_alias;         # to store resolve_alias return
    my $tms_alias;              # for iterating thorugh array
    my @object_array;           # Contains the input array of tms aliases

    my %TESTBED;                # Hash to build and then return

    my $sub_name = "resolveHashFromAliasArray";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered sub");  

    if ( defined ( $args{-input_array} ) ) {
        @object_array = @{ $args{-input_array} };
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name:  No ARGS defined");  
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
        return 0;       # Maybe consider an exit here...
    }

    # Iterate through array of objects to be resolved
    #
    for ( my $object_index = 0; $object_index <= $#object_array; $object_index++ ) {
        # Determine whether the entry is an array or not
        if ( defined ( $object_array[$object_index] ) ) { 

            unless ( populateTestbedHashFromAliasList ( -input_hash => \%TESTBED, -alias_list => $object_array[$object_index] ) ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Not able to populate the testbed array");  
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
                return 0;
            }
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  No object defined in array");  
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
            return 0;
        }
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [\%TESTBED]");  
    return %TESTBED;
}

=head2 populateTestbedHashFromAliasList()

=over

=item DESCRIPTION:

This function takes a list of one or more tms aliases, checks for the presence of the devices and if they exists, populates the hash %TESTBED with the tms alias information. 
The order in which the like devices are specified will be the order in which they are referenced once resolved. For all devices there is the notion of CEs (Computing Elements). The first device specified (for example the SGX4000 CE asterix) becomes CE0, the second device specified (obelix) is CE1, they are both referred to as the first SGX4000. For single CE systems, eg. the GSXs or Single CE SGXs, they will just be refered to as CE0 for that system.
The resulting hash per test object will be for SGXs for example:

    $TESTBED{ "sgx:1:ce0:hash" }  =  resolved alias hash for asterix;
    $TESTBED{ "sgx:1:ce0"      }  = "asterix";
    $TESTBED{ "asterix"        }  = "sgx:1:ce0"; 
    $TESTBED{ "sgx:1:ce1:hash" }  =  resolved alias hash for obelix;
    $TESTBED{ "sgx:1:ce1"      }  = "obelix";
    $TESTBED{ "obelix"         }  = "sgx:1:ce1"; 
    $TESTBED{ "sgx:1"          }  = [ asterix, obelix ]

NOTE: Single CEs will always be ce0.

The resulting hash will be for GSXs for example:

    $TESTBED{ "gsx:1:ce0:hash" }  =  resolved alias hash for viper;
    $TESTBED{ "gsx:1:ce0       }  = "viper";
    $TESTBED{ "viper"          }  = "gsx:1:ce0";
    $TESTBED{ "gsx:1"          }  = [ viper ];

So populated in the hash is a means to get:
*   all aliases for that system, ie. sgx:1 contains asterix and obelix, 
*   the names of the CEs from the index of the equipment
*   the TMS information for each CE

=item ARGUMENTS:

-alias_list  -  A list of tms aliases, eg. 

           ['asterix', 'obelix']    <-- SGX4000 Dual CE
           ['viper']                  <-- GSX

-input_hash  - A reference to the hash that is to be populated with the device information

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

SonusQA::ATSHELPER::resolve_alias()

=item RETURNS:

1  - aliases successfully resolved to hash
0  - otherwise

=item EXAMPLE:

populateTestbedHashFromAliasList ( -input_hash => \%TESTBED, -alias_list => [asterix, obelix] )
populateTestbedHashFromAliasList ( -input_hash => \%TESTBED, -alias_list => ["viper"])

=back

=cut

sub populateTestbedHashFromAliasList {

    my %args        = @_;

    my $testbed_hash_ref;       # to store testbed hash reference
    my $alias_list;             

    my ($tms_alias, $resolved_alias, $object_type, $device_count, @device_array);

    my $sub_name = "populateTestbedHashFromAliasList";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name:");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered sub");  

    if ( defined ( $args{-input_hash} ) ) {
        $testbed_hash_ref   = $args{-input_hash};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name:  Input hash ref not defined");  
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
        return 0;       
    }

    unless ( defined ( $args{-alias_list} ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  TMS Alias list not defined");  
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
        return 0;       
    }
    $args{-alias_list} = [$args{-alias_list}] unless (ref $args{-alias_list});
    if ( $#{$args{-alias_list}} > 1 ) {
            $logger->warn(__PACKAGE__ . ".$sub_name:  An array with more than 2 entities has been specified. If this is wrong, please exit and correct.");
        }
    @device_array = @{ $args{-alias_list} };
    my $ce_index            = 0;
    my $previous_obj_type   = undef; # For use in the foreach loop to make sure the list isn't a mixed list

    my $pass = 1;
    foreach ( @device_array ) {

        $tms_alias      = $_;
        if ( $_ eq "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Blank item found. Please correct testbed array");  
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");  
        }

        $logger->debug(__PACKAGE__ . ".$sub_name:  Resolving $tms_alias");  

        $resolved_alias = SonusQA::Utils::resolve_alias( $tms_alias );

        unless ( defined ( $object_type    = lc( $resolved_alias->{__OBJTYPE} ) ) && $resolved_alias->{__OBJTYPE} ne "" ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  No object type found for $tms_alias");  
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
            return 0;
        }                
        $logger->debug(__PACKAGE__ . ".$sub_name:  Object Type: $object_type");  

        if ( defined ( $previous_obj_type ) ) {
            unless ( $previous_obj_type eq $object_type ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Object type found for $tms_alias \($object_type\) is not the same as the previous object in list \($previous_obj_type\)");  
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
                return 0;
            }
        }

        unless ( defined ( $testbed_hash_ref->{ "${object_type}_count" } ) ) {
            $testbed_hash_ref->{ "${object_type}_count" } = 0;
        }

        if ( $ce_index == 0 ) {                         # Only for the 1st item
            $device_count    = ++$testbed_hash_ref->{ "${object_type}_count" }; 
        }
        my $device_index    = "${object_type}:${device_count}";

        my $index           = "${device_index}:ce${ce_index}";


        $logger->debug(__PACKAGE__ . ".$sub_name:  Index: $device_index \[$ce_index\] / $index");  
        push @{ $testbed_hash_ref->{ "${device_index}" } }, $tms_alias;

        $testbed_hash_ref->{ "${index}:hash" }  = $resolved_alias;
        $testbed_hash_ref->{ "${index}"      }  = $tms_alias;

        if ( exists ( $testbed_hash_ref->{ "${tms_alias}" } )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  This TMS alias has already been allocated to resource ".$testbed_hash_ref->{ "${tms_alias}" }.".");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");  
            return 0;
        }
        else {
            $testbed_hash_ref->{ "${tms_alias}"  }  = $index;
        }

        $ce_index++;                            # Increment for next iteration if required
        $previous_obj_type  = $object_type;     

	#if DSBC, Resolving alias for each SBC type
	foreach my $sbc ('S_OAM','M_OAM','T_OAM', 'S_SBC', 'M_SBC', 'T_SBC', 'I_SBC', 'SLB') {
	    next unless (exists $resolved_alias->{$sbc});
	    foreach my $no (keys (%{$resolved_alias->{$sbc}})) {
		my $name = $resolved_alias->{$sbc}->{$no}->{NAME};
		if (exists ($testbed_hash_ref->{ $name })) {
		    $logger->error(__PACKAGE__ . ".$sub_name:  This $name has already been allocated to resource ".$testbed_hash_ref->{ $name });
		    $pass = 0;
		    last;
		}
		$logger->debug(__PACKAGE__ . ".$sub_name: Resolving alias for $name");
		my $resolved = SonusQA::Utils::resolve_alias( $name );
		my $actual_index = $index.":".$sbc.":".$no;  #sbx5000:1:ce0:S_SBC:1
		$logger->debug(__PACKAGE__ . ".$sub_name: index: $index \[$sbc\] \[$no\] / $actual_index");
		$testbed_hash_ref->{ $name }  = $actual_index;
		$testbed_hash_ref->{ $actual_index.":hash" } = $resolved;
		$testbed_hash_ref->{ $actual_index }  = $name;
	    }
	    last unless ($pass);
	}
	last unless ($pass);
    } # foreach (@device_array)

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$pass]");
    return $pass;
}



=head2 checkRequiredConfiguration()

=over 

=item DESCRIPTION:

This function verifies that the REQUIRED number of objects for the suite are available from the current TESTBED hash. This function depends on the TESTBED hash being of the format output from the resolveHashFromAliasArray function. The function ensures that the number of each device required is not more than the current count of that object type.
Modiifed the subroutine to allow for "optional" elements in the REQUIRED array(CQ: SONUS00158768). So that if an optional element is missing from the testbed, it doesnt fail. Check the below example for how to define an optional array and usage.

=item ARGUMENTS:

1. A hash reference to the REQUIRED objects hash
An array of the following form will be passed in: 

%REQUIRED = (
			"PSX"     => [1], # means psx needs at least 1 CE.
			"GSX"     => ['0-1'], # means gsx could be skipped or could have 1 CE(making it optional) 
			"SBX5000" => ['1-2','0-1'], # means sbx1 needs at least 1 CE but could have 2, and sbx2 could be skipped or could have 1 CE
			"SGX4000" => [2,2] # means both clusters need at least 2 CEs	
         );

Here the quoted string is the object type as taken from TMS, the array reflects the required number of devices. 

The array is of the form: 
number of elements = number of device clusters; 
value of element   = number of computing elements required in that cluster. 

So [2,1] refers to 2 required clusters, each with 2 computing elements. Ie. for the SGX4000, this would imply 2 Dual CE systems are required.

2. A hash reference to the TESTBED hash
This hash is created by the resolveHashFromAliasArray function. Please see that function in this module for more information.

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

SonusQA::ATSHELPER::checkRequiredConfiguration ( \%REQUIRED, \%TESTBED );

=back

=cut

sub checkRequiredConfiguration {
    my ($equipment_req_hash_ref, $testbed_hash_ref)  = @_;

    my $sub_name = "checkRequiredConfigration";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

	@skipped_ces = (); #resetting each time

    while (( my $key, my $value ) = each %{ $equipment_req_hash_ref }) {
        # key = equipment type, value = array of required devices of that type.
        # Size of value array must be >= to the device count. Value of each element
        # in the value array >= to the computing element (ce) count for that device.

        my $device        = lc( $key );
        my @element_array = @{ $value };
#        my $minimum_number = eval ( $#{@element_array} + 1 );
        my $minimum_number = eval ( $#element_array + 1 );

        $logger->debug(__PACKAGE__ . ".$sub_name:  Checking for $minimum_number $key cluster\(s\).");
	my $present_ces;
		# check each cluster for required number of CEs
        my $cluster_number = 1;
        foreach ( @element_array ) {

            my ($min, $max) = split(/-/);
	    if ( $min > 0 and not exists $testbed_hash_ref->{ $device . "_count" } ){
	        $logger->error(__PACKAGE__ . ".$sub_name:  There are no available $key devices.");
	        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
    	        return 0;
	    }

	    $logger->debug(__PACKAGE__ . ".$sub_name: $_  Check $min ".$testbed_hash_ref->{ $device . "_count" }."cluster\(s\).");
            unless($testbed_hash_ref->{"$device:$cluster_number"}){
                $logger->error(__PACKAGE__ . ".$sub_name:  \"$device:$cluster_number\" does not contain any value in the Testbed");
                $present_ces = 0;
	    }

	    else{
                $present_ces = scalar @{$testbed_hash_ref->{"$device:$cluster_number"}};
	    }

            if( $present_ces < $min ){
		$logger->debug(__PACKAGE__ .".$sub_name: present_ces($present_ces) < min($min), checking if device type is NK");

                unless ($testbed_hash_ref->{"$device:$cluster_number:ce0:hash"}->{NODE}->{1}->{TYPE} and $testbed_hash_ref->{"$device:$cluster_number:ce0:hash"}->{NODE}->{1}->{TYPE} eq 'NK') {
		    $logger->error(__PACKAGE__ . ".$sub_name:  Number of CEs present ($present_ces) in $key cluster $cluster_number is less than minimum required \($min\)");
		    $logger->error(__PACKAGE__ . ".$sub_name:  Please check testbed definition file");
		    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
		    return 0;
		}
    	    }

	    if(defined  $present_ces){
		if( defined $max and $present_ces < $max ){
		    $logger->warn(__PACKAGE__ . ".$sub_name: Some tests may fail, since $key cluster $cluster_number doesn't have enough CEs. Number of CEs present is $present_ces and maximum number is set as $max .");
		}
		else{
       		    $logger->info(__PACKAGE__ . ".$sub_name: $key cluster $cluster_number has enough CEs.");
        	}
	    }
	    elsif(!$min){
		$logger->warn(__PACKAGE__ . ".$sub_name:  Some tests may fail, since $key cluster $cluster_number is missing. But it is considered as optional.");
		push @skipped_ces, "$device:$cluster_number";
	    }
#			elsif( defined $max and $present_ces < $max ){
	    elsif( defined $max){
      	    $logger->warn(__PACKAGE__ . ".$sub_name: Some tests may fail, since $key cluster $cluster_number doesn't have any CEs. Maximum number is set as $max .");			
	    }

	    $cluster_number++;
	}
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[1\]");
    return 1;
}


=head2 getTCInfoFromTMS()

=over

=item DESCRIPTION:

This function resolves testcase alias and returns the test case related information from the TMS 

=item ARGUMENTS:

testcase_alias 

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item OUTPUT:

Array of testcase details
0 - Failure

=item EXAMPLE:

my @output = SonusQA::ATSHELPER::getTCInfoFromTMS($testcase_alias)

=item AUTHOR:

Rahul Sasikumar<rsasikumar@sonusnet.com>

=back

=cut

sub getTCInfoFromTMS {

my ($tc_alias)=@_;

my $sub = "getTCInfoFromTMS";

my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

my @output;
my $host =  `hostname`;
my $db_name = "ats";
my $username = "ats";
my $password = "ats";
my $dsn = "DBI:mysql:database=$db_name;host=$host";

unless(defined ($tc_alias))
{
$logger->error(__PACKAGE__ . ".$sub. TEST CASE ALIAS NOT SPECIFIED");
return 0;
}

my $dbh = DBI->connect($dsn, $username, $password);

if(!$dbh)
{
$logger->error(__PACKAGE__ . ".$sub. ATTEMPT TO CONNECT TO DATABASE FAILED");
return 0; 
}

my $cmd = "SELECT sons\_testcase\_title\,sons\_testcase\_procedure\,sons\_testcase\_expected\_results,sons\_testcase\_automation\_flag  from sons\_testcase where sons\_testcase\_alias \="."\'".$tc_alias."\'";


my $sth=$dbh->prepare($cmd);

unless($sth->execute()){
$logger->error(__PACKAGE__ . ".$sub. DB QUERY FAILED");
return 0;
};

@output=$sth->fetchrow;

return @output;

}

=head2 getIPFromLocalHost()

=over

=item DESCRIPTION:

This function resolves the IP address(es) from current ATS host machine (eg. mallrats, masterats) that function is run on. Currently this is limited by the underlying C structure used by perl to the first match only.

=item ARGUMENTS:

None

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item OUTPUT:

Array of IP addresses for local machine.
0 - Failure

=item EXAMPLE:

my @ip_address = SonusQA::ATSHELPER::getIPFromLocalHost;

=back

=cut

sub getIPFromLocalHost {

    my $sub_name = "getIPFromLocalHost";
    my $logger   = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my ( $resolved_ip, @resolved_ip_array );

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");  
  
    # Get hostname 
    chomp ( my $hostname = `hostname`); #TOOLS-13168

    unless ( $hostname ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  No hostname found. \$ENV{ \'HOSTNAME\' } is not set.");  
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");  
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name:  Resolving IP address(es) for $hostname");  
 
    # Get IP addresses
    my @ip_address = gethostbyname( $hostname );
 
    my $index = 0; 
    # The 5th entry of the ip_address array contains the IP addresses 
    foreach ( $ip_address[4] ) {
        $resolved_ip = inet_ntoa( $_ );
        $logger->debug(__PACKAGE__ . ".$sub_name:  Found IP address: $resolved_ip");  
        $resolved_ip_array[ $index ] = $resolved_ip; 
        $index++;
    }
    unless ( @resolved_ip_array ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  No IP addresses found for $hostname");  
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");  
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [array:ip addrs]");  
    return @resolved_ip_array;
}



# TEST TOOLS
sub printFailTest {

    my $package         = shift;
    my $test_id         = shift;
    my $error_message   = shift;
    my $logger          = Log::Log4perl->get_logger( $package );

    if ( $error_message ) {
        $logger->error($package . ".$test_id:  $error_message");
    }
    $logger->error($package . ".$test_id: TEST $test_id FAILED");
    if ( $test_start_time ) {
        $test_exec_time = int tv_interval ($test_start_time);
        $logger->info($package . ".$test_id: Testcase Execution Time $test_exec_time seconds");
        $logger->info($package . ".$test_id: -------------------------------------------------");
    }
    else {
        $logger->warn($package . ". $test_id: Execution time can't be calculated because \"printStartTest()\" is not called ");

    }
}

sub printPassTest {

    my $package         = shift;
    my $test_id         = shift;
    my $debug_message   = shift;
    my $logger          = Log::Log4perl->get_logger( $package );

    if ( $debug_message ) {
        $logger->debug($package . ".$test_id:  $debug_message");
    }
    $logger->info($package . ".$test_id: TEST $test_id PASSED");
    if ( $test_start_time ) {
        $test_exec_time = int tv_interval ($test_start_time);
        $logger->info($package . ".$test_id: Testcase Execution Time $test_exec_time seconds");
        $logger->info($package . ".$test_id: -------------------------------------------------");
    }
    else {
        $logger->warn($package . ". $test_id: Execution time can't be calculated because \"printStartTest()\" is not called ");

    }
}

sub printStartTest {

    my $package     = shift;
    my $test_id     = shift;
    my $logger      = Log::Log4perl->get_logger( $package );

    $logger->info($package . ".$test_id: -------------------------------------------------");
    $logger->info($package . ".$test_id: STARTING TEST $test_id");

    $test_start_time = [Time::HiRes::gettimeofday];
}


=head2 startLogs()

=over

=item DESCRIPTION:

Start the logs for the objects provided.

=item ARGUMENTS:

Mandatory :
    -objectArray     => Array of object references to start the log
                        Refer E.g., for more information

Optional :
    -snmpRoll        => for the Rollover of SGX snmp.log file.Set to 1 for rollover.
    -timeStamp       => Time stamp to be appended with the log files
                        If not defined the current time is taken
=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item OUTPUT:

None

=item EXAMPLE:

# Get the object references
my $gsx_obj = $TESTBED{ "gsx:1:obj" };
my $sgx_obj = $TESTBED{ "sgx4000:1:obj" };
my $psx_obj = $TESTBED{ "psx:1:obj" };

# Set log types required. This needs to be done only once if there are
# no change in the log files required for each test cases
my @logs = ("scpa");
push (@{$psx_obj->{REQUIRED_LOGS}}, @logs);
my @logTypes = ("system", "debug");
push (@{$sgx_obj->{REQUIRED_LOGS}}, @logTypes);

# Store the object references in an array
my @objectArr;
push (@objectArr, $gsx_obj);
push (@objectArr, $sgx_obj);
push (@objectArr, $psx_obj);

SonusQA::ATSHELPER::startLogs(-objectArray   => \@objectArr);

=item NOTES:

- If not provided, time stamp is taken per call to this sub
- The log file types are taken from REQUIRED_LOGS field of the object

=back

=cut

sub startLogs {
   my (%args) = @_;
   my %a;
   my $sub    = "startLogs()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $timeInfo;
   if (defined ($a{-timeStamp})) {
      $timeInfo = $a{-timeStamp};
   } else {
      # Needs to store the log start time
      my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
      $timeInfo = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
   }

   my $ObjeRefs = $a{-objectArray};
   my $objRef;
   # Start loggin for each objects
   foreach $objRef (@{$ObjeRefs}) {
      my $logs = undef;
      $objRef->{LOG_TIME_STAMP} = $timeInfo;

      # Check the object type
      if($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "GSX") {
         $logger->debug(__PACKAGE__ . ".$sub: Rolling over GSX logs");

         $objRef->clearLog();

      } elsif ($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "SGX4000") {
         $logger->debug(__PACKAGE__ . ".$sub: Rolling over SGX4000 logs");

         $objRef->rollSGXLog(-snmpRoll => $a{-snmpRoll});

      } elsif ($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "PSX") {
         $logger->debug(__PACKAGE__ . ".$sub: Removing PSX logs");
         if(defined ($objRef->{REQUIRED_LOGS})) {
            $logs = $objRef->{REQUIRED_LOGS};
         } else {
            $logs = ['scpa'];
         }
         $objRef->remove_logs($logs);
      } else {
         $logger->debug(__PACKAGE__ . ".$sub: Invalid object type");
         return 0;
      }
   }

   return 1;
}


=head2 getLogs()

=over

=item DESCRIPTION:

This subroutine gets the logs from the given objects. startLogs SHOULD be called before using this sub routine

=item ARGUMENTS:

Mandatory :
    -objectArray     => Array of object references to start the log
                        Refer E.g., for more information
    -testId          => test case id
    -logDir          => Logs are stored in this directory

Optional :
    -variant         => Test case variant "ANSI", "ITU" etc
                        Default => "NONE"

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item OUTPUT:

None

=item EXAMPLE:

SonusQA::ATSHELPER::getLogs(-objectArray   => \@objectArr,
                           -testId        => $testID,
                           -logDir        => $logDir);

$gsxObj->{REQUIRED_LOGS} = ["account", "trace"];
SonusQA::ATSHELPER::getLogs(-objectArray   => \@objectArr,
                           -testId        => $testID,
                           -logDir        => $logDir);

=back

=cut

sub getLogs {
   my (%args) = @_;
   my $sub    = "getLogs()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a = ( -variant   => "NONE");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined ($a{-objectArray})) {
       $logger->error(__PACKAGE__ . ".$sub: Needs object references to proceed");
       return 0;
   }

   unless (defined ($a{-testId})) {
       $logger->error(__PACKAGE__ . ".$sub: Test ID is not provided");
       return 0;
   }

   unless (defined ($a{-logDir})) {
       $logger->error(__PACKAGE__ . ".$sub: Log Directory is not provided");
       return 0;
   }

   my $timeInfo;
   my $ObjeRefs = $a{-objectArray};
   my $objRef;
   # Start loggin for each objects
   foreach $objRef (@{$ObjeRefs}) {
      my $logs = undef;

      # Get the time stamp saved during the log start
      $timeInfo = $objRef->{LOG_TIME_STAMP};

      # Clear the log file names are already existing
      $objRef->{LOG_FILE_NAMES} = undef;
      # Check the object type
      if($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "GSX") {
         $logger->debug(__PACKAGE__ . ".$sub: Retrieving GSX logs");
         my $logs;
         if(defined ($objRef->{REQUIRED_LOGS})) {
            $logs = $objRef->{REQUIRED_LOGS};
         } else {
            $logs = ["system", "debug"];
         }

         my @logFiles = $objRef->getGSXLog2(-testCaseID => $a{-testId},
                                                       -logDir     => $a{-logDir},
                                                       -variant    => $a{-variant},
                                                       -timeStamp  => $timeInfo,
                                                       -logType    => $logs);

         $logger->debug(__PACKAGE__ . ".$sub: List of GSX file -> @logFiles");
         unless($logFiles[0]) {
            $logger->error(__PACKAGE__ . ".$sub: There are no files for GSX");
         } else {
             # Save the log files
            push (@{$objRef->{LOG_FILE_NAMES}}, @logFiles);
         }

      }  elsif ($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "SGX4000") {
         $logger->debug(__PACKAGE__ . ".$sub: Retrieving SGX4000 logs");
         if(defined ($objRef->{REQUIRED_LOGS})) {
            $logs = $objRef->{REQUIRED_LOGS};
         } else {
            $logs = ["system", "debug"];
            push (@{$logs}, 'audit') if ($objRef->{POST_8_4});
         }
         my @logFiles = $objRef->getSGXLogs(-testCaseID => $a{-testId},
                                            -logDir     => $a{-logDir},
                                            -variant    => $a{-variant},
                                            -timeStamp  => $timeInfo,
                                            -logType    => $logs);
         unless($logFiles[0]) {
            $logger->error(__PACKAGE__ . ".$sub: There are no files for SGX");
         } else {
             # Save the log files
            push (@{$objRef->{LOG_FILE_NAMES}}, @logFiles);
         }
      } elsif ($objRef->{TMS_ALIAS_DATA}->{__OBJTYPE} eq "PSX") {
         $logger->debug(__PACKAGE__ . ".$sub: Retrieving PSX logs");
         if(defined ($objRef->{REQUIRED_LOGS})) {
            $logs = $objRef->{REQUIRED_LOGS};
         } else {
            $logs = ['scpa'];
         }
         # Collect the log files
         my @logFiles = $objRef->getPSXLog(-testId     => $a{-testId},
                                           -logDir     => $a{-logDir},
                                           -variant    => $a{-variant},
                                           -timeStamp  => $timeInfo,
                                           -logType    => $logs);

         unless($logFiles[0]) {
            $logger->error(__PACKAGE__ . ".$sub: There are no files for PSX");
         } else {
             # Save the log files
            push (@{$objRef->{LOG_FILE_NAMES}}, @logFiles);
         }
      } else {
         $logger->debug(__PACKAGE__ . ".$sub: Invalid object type");
         return 0;
      }
   }
   return 1;
}

=head2 checkRequiredConfOnDevices()

=over

=item DESCRIPTION:

This subroutine checks the required configuration on devices passed by the user, like GSX, SGX and MGTS.
It can check the CNS cards and its type present in the GSX, type of board installed in SGX and slot type of MGTS.
This was created as an enhancement FIX for the CQ SONUS00125733.

=item ARGUMENTS:

Optional :
In a hash :
     KEY                                  VALUE 
  GSX Object      =>    Reference to Hash having the required GSX card details.
                    like ( "CNS" => 4 ) means 4 CNS cards required.
  MGTS Object     =>    Reqd slot type in MGTS. Ex: "ETHERNET"
  SGX Object      =>    T1 board installed or not. Ex: "T1"

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

None

=item EXAMPLE:

my %gsx1_card_details = ("CNS"   => 4,    # 4 CNS cards required
                "CNST1" => 3,    # 3 CNS cards must support T1 circuits
                "CNSE1" => 1,    # 1 CNS card must support E1 circuits
                "CNS25" => 1,);  # 1 CNS25 card must be present

# Package used to pass the objects as hash keys
use Tie::RefHash;
tie my %h, 'Tie::RefHash';

%h = ( $gsxObj1   =>   \%gsx1_card_details ,       # Reqd Conf on GSX1
      $mgts_obj =>  "ETHERNET" ,   # Reqd slot type in MGTS
      $sgxRootObj1    =>   "T1",     # T1 board installed. checking via SGX root Object.
    );

my $conf_result = SonusQA::ATSHELPER::checkRequiredConfOnDevices ( %h );

=item AUTHOR:

Wasim Mohd.  < wmohammed@sonusnet.com >

=back

=cut

sub checkRequiredConfOnDevices {
   use Tie::RefHash;
   tie my %args, 'Tie::RefHash';

   %args = @_;
   my $sub    = "checkRequiredConfOnDevices()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a = ();
   my ( $key, $value , $key1 , $key2, $value1,  $cmd , @cmdResult , $sgxFlag );
   $sgxFlag = 0;
   
   # get the arguments
   while ( ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
   
   # start with the configuration check on devices.
   foreach $key ( keys %args ) {
       if ( defined $key->{TYPE} ) {
           if ( $key->{TYPE} =~ /SGX4000/ ) {
               $logger->debug(__PACKAGE__ . ".$sub: SGX4K Root Object found in the argument. Checking if T1 board is installed. ");
               $cmd = "/opt/iphwae/tools/iphDumpCardList";
               @cmdResult = $key->execCmd ( $cmd );
               foreach (@cmdResult) {
                   if ( /quad T1/ ) {
                       $logger->debug(__PACKAGE__ . ".$sub: T1 board is installed in the SGX4000  ");
                       $sgxFlag = 1;
                       last;
                    }
                }
                unless ( $sgxFlag ) {
                   $logger->error(__PACKAGE__ . ".$sub: T1 board is not installed in the SGX4000  ");
                   $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                   return 0;
                }
            } elsif (  $key->{TYPE} =~ /GSX/  ) {
                $logger->debug(__PACKAGE__ . ".$sub: GSX CLI Object found in the argument. Checking for the reqd cards one by one. ");
                my %cardReq = %{$args{$key}};
                while ( ( $key1 , $value1) = each %cardReq ) {
                    if ( $key1 eq "CNS" || $key1 =~ /CNS(\d+)/ ) {
                        my $cnsNo;
                        unless ( $key1 eq "CNS" ) { $cnsNo = $1; } 
                        my $cnsCnt = 0;
                        my $cnsName ;
                        if ( $key1 eq "CNS" ) { $cnsName = "CNS"; } else { $cnsName = "CNS$cnsNo"; }
                        $logger->debug(__PACKAGE__ . ".$sub: Checking for the No of $cnsName cards PRESENT and RUNNING");
                        if( $key->execCmd('show Inventory Shelf 1 Summary') ) {
                            foreach(@{$key->{CMDRESULTS}}){
                                if( $_ =~ /^(\d+)\s+(\d+)\s+CNS(\d+)\s+(\w+)\s+(\w+)\s+(\w+)/){
                                    if ( defined $cnsNo ) {
                                        if ( ( $3 eq $cnsNo ) && ( $4 eq "RUNNING" ) &&  ( $6 eq "PRESENT" ) ) {
                                            $cnsCnt++;
                                        }
                                    } else {
                                        if ( ( $4 eq "RUNNING" ) &&  ( $6 eq "PRESENT" ) ) {
                                            $cnsCnt++;
                                        }
                                    }
                                }
                            }
                        } else {
                            $logger->error(__PACKAGE__ . ".$sub: Failure to run the command in GSX CLI. ");
                            $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                            return 0;
                        }
                    
                        if ( $cnsCnt < $value1 ) {
                            $logger->error(__PACKAGE__ . ".$sub: Reqd No of $cnsName cards PRESENT and RUNNING \"$value1\" is greater than available \"$cnsCnt\"");
                            $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                            return 0;
                        }
                        $logger->debug(__PACKAGE__ . ".$sub: Reqd No of $cnsName cards PRESENT and RUNNING \"$value1\" is equal/less than available \"$cnsCnt\" ");
                    } elsif ( $key1 eq "CNST1" || $key1 eq "CNSE1" ) {
                        my ( $cirType , $cirCnt );
                        $cirCnt = 0;
                        if ( $key1 eq "CNST1" ) { $cirType = "T1" ; } else { $cirType = "E1" ; }
                        $logger->debug(__PACKAGE__ . ".$sub: Checking for the No of CNS cards that support $cirType circuits");
                        foreach ( my $i =1; $i <= 16 ; $i++ ) {
                            if($key->execCmd("show server shelf 1 slot $i admin")) {
                                foreach(@{$key->{CMDRESULTS}}){
                                    if ( $key1 eq "CNST1" ) {
                                        if( ($_ =~ /Server Function: T1/) || ( $_ =~ /Server Function: T3/ ) || ( $_ =~ /Server Function: STM1OC3/ ) ){	
                                            $cirCnt++;
                                        } 
                                    } else {
                                        if( ( $_ =~ /Server Function: E1/ ) || ( $_ =~ /Server Function: STM1OC3/ )){	
                                            $cirCnt++;
                                        } 
                                    }
                                }
                            }
                        }
                        if ( $cirCnt < $value1 ) {
                            $logger->error(__PACKAGE__ . ".$sub: Reqd No of CNS cards with $cirType Circuits \"$value1\" is greater than available \"$cirCnt\"");
                            $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                            return 0;
                        }
                        $logger->debug(__PACKAGE__ . ".$sub: Reqd No of CNS cards with $cirType Cirs \"$value1\" is equal/less than available \"$cirCnt\" ");
                    } else {
                        $logger->error(__PACKAGE__ . ".$sub: Unknown card Type $key1 Passed !!!!! " ) ;
                        $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                        return 0;
                    }
                }
            } elsif ( $key->{TYPE} =~ /MGTS/ ) {
                $logger->debug(__PACKAGE__ . ".$sub: MGTS Object found in the argument. Checking if $args{$key} slot is present in it.");
                my $slot = $key->{TMS_ALIAS_DATA}->{NODE}->{1}->{SLOT_TYPE};
                my $reqslot = $args{$key};
                if ( $slot =~ /$reqslot/i ) {
                    $logger->debug(__PACKAGE__ . ".$sub: MGTS has the required slot type $args{$key} . Slot Found : $slot ");
                }
                else {
                    $logger->error(__PACKAGE__ . ".$sub: MGTS does not has the required slot type \"$args{$key}\" ");
                    $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
                    return 0;
                }
            }
       }
       else {
            $logger->error(__PACKAGE__ . ".$sub: Unrecognised Object type \"$key\" passed.  ");
            $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [0] ");
            return 0;
       }
    }
   
    $logger->debug(__PACKAGE__ . ".$sub: SUCCESS: All the devices have the desired Configuration ");
    $logger->debug(__PACKAGE__ . ".$sub: ----> Leaving Sub [1] ");
    return 1;
}

=head2 getRequiredTestBedHash()

=over

=item DESCRIPTION:

This subroutine gets the required testbed hash for the script, depend on input %REQUIRED hash

=item ARGUMENTS:

Mandatory:
A hash reference to the REQUIRED objects hash

=item PACKAGE:

SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

@TESTBED, %TESTBED from main script

=item RETURNS:

None

=item EXAMPLE:

my %REQUIRED = (
            "SGX4000"   => [2],
            "EMS"       => [1],
            "MGTS" => [1],
            "IPMGTS" => [1],
            "TDMMGTS" => [1]
           );

unless (SonusQA::ATSHELPER::getRequiredTestBedHash( \%REQUIRED) ) {
  $logger->error(__PACKAGE__ . ".$sub_name: unable to get the required testbed hash");
  return 0;
}

=item AUTHOR:

Ramesh Pateel

=back

=cut

sub getRequiredTestBedHash {
    my $equipment_req_hash_ref  = shift;

    my $sub_name = "getRequiredTestBedHash";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $testbed_array = \@main::TESTBED;

    my %orig_testbed = ();
    unless (%orig_testbed = SonusQA::ATSHELPER::resolveHashFromAliasArray( -input_array  => $testbed_array ) ) {
         $logger->error(__PACKAGE__ . ".$sub_name: unable to get resolve original testbed array to hash");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
         return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: got the original testbed resolved hash");

    my @new_testbed_array = ();
    while (( my $device, my $value ) = each %{ $equipment_req_hash_ref }) {
        $device = lc $device;
        my $count = scalar @{ $value };
        foreach my $index (1..$count) {
            unless ($device =~ /MGTS/i) {
                if (defined $orig_testbed{"$device:$index"} and $orig_testbed{"$device:$index"}) {
                     if ($value->[$count - 1] > 1 ) {
                        push (@new_testbed_array, $orig_testbed{"$device:$index"});
                     } else {
                        push (@new_testbed_array, $orig_testbed{"$device:$index"}->[0]);
                     }
                } else {
                     $logger->error(__PACKAGE__ . ".$sub_name: testbed hash doesnt have required number $device devices");
                     $logger->error(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
                     return 0;
                }
            }
        }
    }

    my %mgts_data = ();
    my $required_mgts = {};

    foreach my $hash_index (1..$orig_testbed{"mgts_count"}) {
    CE: foreach my $ce ('ce0', 'ce1') {
            my $key = "mgts:$hash_index:$ce:hash";
            next CE unless (defined $orig_testbed{$key});
            my $mgts_type = 'MGTS';
            if ($orig_testbed{$key}->{NODE}->{2}->{SLOT_TYPE} =~ /(PPCI_ETHERNET|PPCI_GIGE_9018)/) {
                $mgts_type = 'IPMGTS';
            } elsif ($orig_testbed{$key}->{NODE}->{2}->{SLOT_TYPE} =~ /PPCI_J1E1T1/) {
                $mgts_type = 'TDMMGTS';
            }
            next CE unless (defined $equipment_req_hash_ref->{$mgts_type});
            my $temp = shift @{$equipment_req_hash_ref->{$mgts_type}};
            next CE unless $temp;
            push (@{$required_mgts->{$mgts_type}}, $temp);
            ($temp > 1 ) ? push (@{$mgts_data{$mgts_type}->{'testbed'}}, $orig_testbed{"mgts:$hash_index"}) : push (@{$mgts_data{$mgts_type}->{'testbed'}}, $orig_testbed{"mgts:$hash_index"}->[0]);
            push (@{$mgts_data{$mgts_type}->{'count'}}, $temp); #for new REQUIRED hash
        }
    }

    $equipment_req_hash_ref->{"MGTS"} = [] if (@{$equipment_req_hash_ref->{'MGTS'}});
    foreach my $mgts (keys %{ $equipment_req_hash_ref }) {
        next unless ($mgts =~ /MGTS/i);
        my $required = scalar @{$required_mgts->{$mgts}};
        push (@{$equipment_req_hash_ref->{"MGTS"}}, @{$required_mgts->{$mgts}});
        my $present = scalar @{$mgts_data{$mgts}->{'count'}};
        if ($required > $present) {
            $logger->error(__PACKAGE__ . ".$sub_name: testbed hash doesnt have required number $mgts devices");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
            return 0;
        }
        push (@new_testbed_array, @{$mgts_data{$mgts}->{'testbed'}});
    }

    delete $equipment_req_hash_ref->{"TDMMGTS"} if ($equipment_req_hash_ref->{"TDMMGTS"});
    delete $equipment_req_hash_ref->{"IPMGTS"} if ($equipment_req_hash_ref->{"IPMGTS"});

    $logger->debug(__PACKAGE__ . ".$sub_name: prepared the required testbed array ->" . Dumper(\@new_testbed_array));

    undef %main::TESTBED;
    unless (%main::TESTBED = SonusQA::ATSHELPER::resolveHashFromAliasArray( -input_array  =>\@new_testbed_array)) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to resolve required test bed array to hash");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Success - got the required testbed hash");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[1\]");
    return 1;
}

=head2 getMyHaPair()

=over

=item DESCRIPTION

This subroutine will get the ha pair for passed ce name (tms alias).

=item ARGUMENTS:

Mandatory:
    one of the ce name (tms alias)

=item RETURNS :

tms alias of other ce - success
0 - Failur

=item EXAMPLE :

my $female = $self->getMyHaPair( "sbx39");

=back

=cut

sub getMyHaPair {
    my $male = shift;

    my $sub_name = "getMyHaPair()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ($male) {
       $logger->error(__PACKAGE__ . ".$sub_name: one of the ce name should be passed as a argument");
       return 0;
    }

    foreach my $count (1..$main::TESTBED{sbx5000_count}) {
       next unless ((scalar @{$main::TESTBED{"sbx5000:$count"}}) > 1);
       if ($main::TESTBED{"sbx5000:$count"}->[0] =~ /^$male$/i) {
           $logger->debug(__PACKAGE__ . ".$sub_name: Success - got the HA pair for \'$male\' -> $main::TESTBED{\"sbx5000:$count\"}->[1]");
           return $main::TESTBED{"sbx5000:$count"}->[1];
       } elsif ( $main::TESTBED{"sbx5000:$count"}->[1] =~ /^$male$/i) {
           $logger->debug(__PACKAGE__ . ".$sub_name: Success - got the HA pair for \'$male\' -> $main::TESTBED{\"sbx5000:$count\"}->[0]");
           return $main::TESTBED{"sbx5000:$count"}->[0];
       }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: unable to get HA pair for \'$male\', Hence considering it as standalone");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
    return 0;
}

=head2 generateSafenetLicenses()

=over

=item DESCRIPTION:

Generates safenet license for given list of features.

=item ARGUMENTS:

Mandatory :
-fingerPrints: Array of fingerprints. To find EMS fingerPrint refer Find License Server Fingerprint
-deviceType : Type of the device (PSX/SBC/INSIGHT/ASX/SGX4000/BRX). 
-featureHash: It should contain list of features for which license needs to be generated along with quantity.
gracePeriodDays and gracePeriodHours: grace period in days and hours respectively. Defaults to 10 days and 240 hours if not passed.
quantity, type and expirationDate - number of licenses, type of license( 0 --> BASE, 1 --> FLOATING, 2 --> LEGACY, 3 --> FIXED) and license expiry date respectively

=item RETURNS: 

XML license bundle file path

=item EXAMPLE:

my %featureHash = (
    'POL-SWE-BASE-SW-100CPS' => { quantity => 1, type => 2, expirationDate => '2016-10-20T00:00:00',gracePeriodDays => '20', gracePeriodHours => '480' }
    'POL-SIPASI' => { quantity => 1, type => 2, expirationDate => '2016-10-20T00:00:00', gracePeriodDays => '20', gracePeriodHours => '480' },
);

my @fingerPrints = ('2000-*1LUCBSJ8HVYLMEB', '2000-*2LUCBSJ8HVYLMEB');
my $license = SonusQA::ATSHELPER::generateSafenetLicenses(-fingerPrints => \@fingerPrints ,-deviceType => 'PSX',-featureHash => \%featureHash);

=back

=cut

sub generateSafenetLicenses {

    my $sub_name = "generateSafenetLicenses";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered $sub_name"); 

    my (%args) = @_;
    my (@elements, @features, $feature, $adminInfo, $lsInfo, $client, $method, $response, $license, $licenseFile, $randomNumber, @fingerPrints, $fingerPrint);
    my $licenseServerIp = 'http://10.6.50.118:8080';

    unless ( defined($args{-fingerPrints}) && defined($args{-featureHash}) && defined($args{-deviceType}) ) {
        $logger->error('Argument missing. Required aruguments are -fingerPrints, -featureHash, -deviceType');
        exit;
    }

    $randomNumber = 1 + int rand(2147483647);

    # required params, if not defined, will set to some default value
    $args{-licenseId} ||= $randomNumber;
    $args{-purchaseOrderId} ||= $randomNumber;
    $args{-usageLimit} ||= '1';
    $args{-licenseType} ||= '0';
    $args{-sharingType} ||= '0';

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $currentTime = sprintf "%4d-%02d-%02dT%02d:%02d:%02d.000-04:00", $year+1900, $mon+1, $mday, $hour, $min, $sec;
    $args{-generationDate} ||= $currentTime;

    # optional params, can be ignored for generating soap message
    $args{-customerName} ||= 'sonus';
    $args{-privateVendorInfo} ||= 'Sonus';
    $args{-publicVendorInfo} ||= 'Sonus';
    $args{-description} ||= 'Test License.';
    $args{-effectiveDate} ||= $currentTime;

    foreach my $value (@{$args{-fingerPrints}}) {
        $fingerPrint = SOAP::Data->name('item' => $value)->prefix('lic');
        push(@fingerPrints, $fingerPrint);
    }

    $adminInfo = SOAP::Data
                ->name('lsAdminInfo' => \SOAP::Data->value(
                      SOAP::Data->name('customerName' => $args{-customerName})->prefix('mod'),
                      SOAP::Data->name('generationDate' => $args{-generationDate})->prefix('mod')->type('xsd:dateTime'),
                      SOAP::Data->name('hostid' => \@fingerPrints)->prefix('mod'),
                      SOAP::Data->name('licenseId' => $args{-licenseId})->prefix('mod'),
                      SOAP::Data->name('purchaseOrderId' => $args{-purchaseOrderId})->prefix('mod'),
                ))
                ->prefix('mod');

    $args{-lineId} = $randomNumber - 100;
    foreach my $key (keys %{$args{-featureHash}}) {
        $args{-featureHash}{$key}{type} ||= '0';
        $args{-featureHash}{$key}{quantity} ||= '1';
        $args{-featureHash}{$key}{gracePeriodDays} ||= '10';
        $args{-featureHash}{$key}{gracePeriodHours} ||= '240';        
        
        $feature = SOAP::Data->name('item' => \SOAP::Data->value(
                            SOAP::Data->name('description' => $args{-description})->prefix('mod'),
                            SOAP::Data->name('deviceType' => $args{-deviceType})->prefix('mod'),
                            SOAP::Data->name('expirationDate' => $args{-featureHash}{$key}{expirationDate})->prefix('mod'),
                            SOAP::Data->name('featureId' => $key)->prefix('mod'),
                            SOAP::Data->name('gracePeriodDays' => $args{-featureHash}{$key}{gracePeriodDays})->prefix('mod'),
                            SOAP::Data->name('gracePeriodHours' => $args{-featureHash}{$key}{gracePeriodHours})->prefix('mod'),
                            SOAP::Data->name('licenseType' => $args{-licenseType})->prefix('mod'),
                            SOAP::Data->name('lifetime' => '0')->prefix('mod'),
                            SOAP::Data->name('lifetimeUnit' => '0')->prefix('mod'),
                            SOAP::Data->name('lineId' => $args{-lineId})->prefix('mod'),
                            SOAP::Data->name('privateVendorInfo' => $args{-privateVendorInfo})->prefix('mod'),
                            SOAP::Data->name('publicVendorInfo' => $args{-publicVendorInfo})->prefix('mod'),
                            SOAP::Data->name('redundant' => 'false')->prefix('mod'),
                            SOAP::Data->name('sharingType' => $args{-sharingType})->prefix('mod'),
                            SOAP::Data->name('trialDuration' => '0')->prefix('mod'),
                            SOAP::Data->name('trialLimit' => '0')->prefix('mod'),
                            SOAP::Data->name('type' => $args{-featureHash}{$key}{type})->prefix('mod'),
                            SOAP::Data->name('usageLimit' => $args{-featureHash}{$key}{quantity})->prefix('mod'),
                            SOAP::Data->name('version' => '0')->prefix('mod')
                        ))
                      ->prefix('lic');

        push(@features, $feature);
        $args{-lineId}++;
    }

    $lsInfo = SOAP::Data->name('lsInfo' => \@features)->prefix('mod');

    push(@elements, $adminInfo);
    push(@elements, $lsInfo);

    $logger->debug('Generating license with : '. Dumper(\%args));

    $client = SOAP::Lite->proxy( $licenseServerIp . '/axis/services/LicenseGeneratorService?wsdl')->autotype(0);
    $method = SOAP::Data->name('in0' => \@elements)->attr({ #TOOLS-16783
                    'xmlns' => 'http://schemas.xmlsoap.org/wsdl/soap/', 
                    'xmlns:lic' => 'http://www.sonusnet.com/licensegenerator/api/LicenseGeneratorService',
                    'xmlns:mod' => 'http://www.sonusnet.com/licensegenerator/api/model'
                })->prefix('lic');
     $response = $client->call($method => @elements);

    if($response->fault){
        $logger->error('License generation failed'); 
        $logger->error('faultcode: '. $response->faultcode);
        $logger->error('faultstring: '. $response->faultstring);
        $logger->error('faultdetail: '. Dumper(\$response->faultdetail));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        exit;
    }

    $license = $response->valueof('//generateSafenetLicensesReturn/licXml');
    
    $licenseFile = $ENV{"HOME"}."/ats_user/licenseFile_" . time .".xml";

    unless(open(LICENSEFILE,">", $licenseFile)){
        $logger->error("Failed to create license file " . $!);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    print LICENSEFILE $license;

    close(LICENSEFILE); 
    `sed -i 's/T00:00:00/-00:00/g' $licenseFile`;#TOOLS-16711 - Fix for 1st problem in Description
    $logger->debug('Successfully generated license : '. Dumper($licenseFile));
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");  
    return $licenseFile;
}

=head2 generateLicense()

=over

=item DESCRIPTION

Generates legacy or NWDL license for give set of features.
For Legacy license use -hostids mandatory parameter and for NWDL License use -domainPublicKey parameter

=item ARGUMENTS:

Mandatory:
    -featureHash: It should contain list of features for which license needs to be generated along with quantity.
    gracePeriodDays and gracePeriodHours: grace period in days and hours respectively. Defaults to 10 days and 240 hours if not passed.
    quantity, type and expirationDate - number of licenses, type of license( 0 --> BASE, 1 --> FLOATING, 2 --> LEGACY, 3 --> FIXED) and license expiry date respectively.

    Atleast one of '-hostids' and '-domainPublicKey' is mandatory
    -hostids : Array of hostids. To find hostid refer Find License Server Fingerprint
    -domainPublicKey : Public Key for NWDL license generation

=item RETURNS: 

XML license bundle file path

=item EXAMPLE:

my %featureHash = (
    'POL-SWE-BASE-SW-100CPS' => { quantity => 1, type => 2, expirationDate => '2016-10-20T00:00:00', gracePeriodDays => '20', gracePeriodHours => '480' }
    'POL-IS41-100CPS' => { quantity => 3, type => 2, expirationDate => '2016-10-20T00:00:00', gracePeriodDays => '20', gracePeriodHours => '480' },
    );
my $domainPublicKey = "<your public key>";
my @hostids = ('2CCBCBCA4079EB02F858AEB8F3CC88FA', '4DABCBCA4079EB02F858A9B8230C382C');
my $licenseFilePath = SonusQA::ATSHELPER::generateLicense(-hostids => \@hostids,-featureHash => \%featureHash);
                                    (or)
my $licenseFilePath = SonusQA::ATSHELPER::generateLicense(-domainPublicKey => $domainPublicKey,-featureHash => \%featureHash);

=back

=cut

sub generateLicense {

    my $sub_name = "generateLicense";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered $sub_name"); 

    my (%args) = @_;

    unless ( defined($args{-featureHash}) ) {
        $logger->error('Missing Mandatory arugument -featureHash');
        $logger->info(__PACKAGE__ . ".$sub_name: <-- leaving Sub [0]");
        return 0;
    }
    my $cmd = 'java';
    if(defined($args{-hostids})){
        $cmd .= " -DsourceHash=$args{-hostids}->[0]";
        if(@{$args{-hostids}}[1]){
            $cmd .= " -DtargetHash=$args{-hostids}->[1]";
        }
    }elsif(defined $args{-domainPublicKey}){
        $cmd .= " -DdomainPublicKey=$args{-domainPublicKey}";
    }else{
        $logger->error(__PACKAGE__ . ".$sub_name: ERROR: Neither '-domainPublicKey' nor '-hostids' passed. Atleast one is mandatory.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $required_licenses;
    for my $license (keys %{$args{-featureHash}}){
        $required_licenses .= "$license=$args{-featureHash}{$license}{quantity};";
    }

    my $licenseFile = $ENV{"HOME"}."/ats_user/licenseFile_" . time .".xml";
    `rm $licenseFile` if(-e $licenseFile);
    $cmd .= " -DrequiredLicenses=\"$required_licenses\" -DoutputFile=$licenseFile -jar /ats/tools/LicenseGeneratorWebService/LicenseGenerator.jar";

    $logger->debug(__PACKAGE__ . ".$sub_name: Executing command: '$cmd'");
    my $cmdResult = `$cmd`;

    unless(-e $licenseFile){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to generate License File. $cmdResult");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug('Successfully generated license : '. $licenseFile);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");  
    return $licenseFile;
}

=head2 loginToEMSGUI()

=over

=item DESCRIPTION

Helper function to login to ems GUI before registering/unregistering PSX node from EMS

=item ARGUMENTS:

Mandatory : 
    $ems_ip - ip on which psx needs to be registered
    $username - ems gui login username
    $password - ems gui login password
    $ua - user agent object
    $cookie_jar - cookie jar to store cookie

=item RETURNS:

($ua, $cookie_jar) - if successfully
0 - otherwise

=item EXAMPLE:

SonusQA::ATSHELPER::loginToEMSGUI()

=back

=cut

sub loginToEMSGUI {

    my ($ems_ip, $username, $password, $ua, $cookie_jar) = @_;
    my $sub_name = "loginToEMSGUI";
    my ($response, $request);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");


    $ems_ip = "[$ems_ip]" if ($ems_ip !~ m/^\[.+\]$/ && $ems_ip =~ m/:/); #TOOLS-17561
    $request = GET "https://$ems_ip/emxAuth/auth/getInfo" ;
    $response = $ua->request( $request);
    $cookie_jar->extract_cookies( $response );
    $ua->{EMS_VERSION} = ($response->{'_content'} =~ /\"version\":\"([A-Z0-9\.]+)\"/) ? $1 : '' ;

    if ( SonusQA::Utils::greaterThanVersion( $ua->{EMS_VERSION}  , 'V12.00.00') ) {
        $request = GET "https://$ems_ip/";
        $response = $ua->request( $request);
        $cookie_jar->extract_cookies( $response ); 
    } else {
        $request = GET "https://$ems_ip/coreGui/ui/logon/launch.jsp";
        $response = $ua->request( $request);
        $cookie_jar->extract_cookies( $response );
    }

    # if we are able to fetch cookie, then is reachable & responding
    unless($cookie_jar->as_string =~ /JSESSIONID/ ){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the cookie(JSESSIONID). Check if server is reachable.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $request = POST "https://$ems_ip/coreGui/ui/logon/j_security_check", [ j_username => $username, j_password => $password, j_security_check => ' Log In '];
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );
    # if response contains 'j_username', login failed & promting to enter credentials again.
    if($response->decoded_content =~ /name="j_username"/ ){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to sign into EMS.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $request = GET "https://$ems_ip/coreGui/ui/logon/";
    $response = $ua->request( $request);
    $cookie_jar->extract_cookies( $response );


    # ems needs JSESSIONIDSSO for subsequent requests
    unless($cookie_jar->as_string =~ /JSESSIONIDSSO/ ){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the cookie(JSESSIONIDSSO). Sign in failed.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $request = GET "https://$ems_ip/coreGui/ui/logon/launch.jsp";
    $response = $ua->request( $request);
    $cookie_jar->extract_cookies( $response );

    # ems needs VIRTUALSESSIONID for subsequent requests
    unless($cookie_jar->as_string =~ /VIRTUALSESSIONID/ ){
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the cookie(VIRTUALSESSIONID). Sign in failed.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $authorisation_value ;
    unless ( $response->{_rc} == 200 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Response code is $response->{_rc}. coreGui/ui/logon/launch.jsp is not supported from 10.3 EMS version."); 
        $request = GET "https://$ems_ip/emxAuth/auth/getAuthSession";
        $response = $ua->request( $request);
        $response->{'_content'} =~ /.+token\"\:\"([a-zA-Z0-9]+)\"/ ;
        $authorisation_value = $1 ;
        $ua->default_header( 'Authorization'   => $authorisation_value );
    }

    $logger->debug("Successfully logged into EMS GUI");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return ($ua, $cookie_jar, $authorisation_value);
}

sub uploadLicenseBundle {

    my ($ems_ip, $licenseFile) = @_;
    my (%form_fields, $username, $password, $decoded_message, $license, $request, $response);

    $ems_ip = is_ipv6($ems_ip) ? "[$ems_ip]" : $ems_ip;
    my $sub_name = "uploadLicenseBundle";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");

    my $ua = LWP::UserAgent->new( keep_alive => 1);
    $ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
    $ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    $username = 'admin'; # to be decided whether to set dynamically
    $password = 'admin'; # to be decided whether to set dynamically

    ($ua, $cookie_jar) = &loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);

    `sed -i 's/T00:00:00/-00:00/g' $licenseFile`;
    $license = `cat $licenseFile`;
     
    $logger->debug("Uploading licenses : $license "); 
    if (SonusQA::Utils::greaterThanVersion( $ua->{EMS_VERSION} , 'V13.00.00')) {
        %form_fields = ('lic_xml_data' => $license);
        my $payload = encode_json \%form_fields;
        $request = POST "https://$ems_ip/licmgmt/v1.0/license/uploadLicenseData";
        $request->content_type('application/json');
        $request->content($payload);
    } else {
        %form_fields = (
            'lic_xml_data' => $license,
            'op' => 'uploadLicenseDetails',
            'checkRevokeCase' => 'true'
            );

        $request = POST "https://$ems_ip/licmgr/LicenseServlet?op=uploadLicenseDetails", \%form_fields;
    }
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }
    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    if (defined $decoded_message->{Error}){
        $logger->error("License upload failed : ". Dumper(\$decoded_message->{Error}));
        return 0;
    }

    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 associateLicensesV13()

=over

=item DESCRIPTION

  This subroutine used to associate licenses for EMS version 13.0 onwards (TOOLS-75432)
  It is called internally from associateLicenses if EMS version is >= 13.00.00

=item Arguments

Mandatory Args:
  ems_ip => ip of ems
  node_name => name of node
  featureHash => hash of licenses/featutes to associate 
  ua => user agent reference
  cookie_jar => cookie jar reference
 
Optional Args:
  None

=item Returns

  1  - for success
  0  - for failure

=item Example

  my $ret = associateLicensesV13(ems_ip => $ems_ip, node_name => $node_name, featureHash => \%featureHash, ua => $ua, cookie_jar => $cookie_jar);

=back

=cut

sub associateLicensesV13{
    my %args = @_;

    my $sub_name = "associateLicensesV13";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    $logger->debug(__PACKAGE__ .".$sub_name: args ". Dumper(\%args));

    # fetch node details
    $logger->debug(__PACKAGE__ . ".$sub_name: Fetching node details");

    my $request = GET "https://$args{ems_ip}/licmgmt/v1.0/licenseTargets";
    $args{cookie_jar}->add_cookie_header( $request );
    my $response = $args{ua}->request( $request );
    $args{cookie_jar}->extract_cookies( $response );

    unless ($response->is_success) {
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to fetch node details");
        $logger->debug(__PACKAGE__ . ".$sub_name: Request: GET https://$args{ems_ip}/licmgmt/v1.0/licenseTargets");
        $logger->debug(__PACKAGE__ . ".$sub_name: Response Status Line : ". $response->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: Response Content : ". $response->decoded_content);
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
        return 0;
    }

    my $decoded_message = decode_json($response->decoded_content);
    my @nodes = @{ $decoded_message->{aaData} };

    my ($node_ip, $node_id, $node_type);
    foreach my $node (@nodes){
        if ($node->[2] eq $args{node_name}) {
            $node_ip = $node->[3];
            $node_id = $node->[0];
            $node_type = $node->[1];
            last;
        }
    }

    unless($node_ip){
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to find node, $args{node_name}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Nodes: ". Dumper(\@nodes));
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
        return 0;
    }

# fetch all unassigned licenses
    my %form_fields = (
            'deviceType' => $node_type,
            'targetOid' => $node_id,
            'nodeIp' => $node_ip
        );

    $logger->debug(__PACKAGE__ . ".$sub_name: form fields for unAssignedLicenses: ". Dumper(\%form_fields));

    my $json = encode_json(\%form_fields);
    $request= POST "https://$args{ems_ip}/licmgmt/v1.0/unAssignedLicenses";
    $request->header('Content-Type' => 'application/json');
    $request->content($json);
    $args{cookie_jar}->add_cookie_header( $request );
    $response = $args{ua}->request( $request );

    unless ($response->is_success) {
      $logger->error(__PACKAGE__ . ".$sub_name: Unable to fetch unassigned licenses");
      $logger->debug(__PACKAGE__ . ".$sub_name: Request: POST https://$args{ems_ip}/licmgmt/v1.0/unAssignedLicenses");
      $logger->debug(__PACKAGE__ . ".$sub_name: Response Status Line : ". $response->status_line);
      $logger->debug(__PACKAGE__ . ".$sub_name: Response Content : ". $response->decoded_content);
      $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
      return 0;
    }

    $decoded_message = decode_json($response->decoded_content);
    my @unassignedLicenses = @{ $decoded_message->{aaData} };

    # associate or dis-associate licenses
    %form_fields = (
            'nodeType' => $node_type,
            'targetOid' => $node_id,
            'checkedOid' => '',
            'uncheckedOid' => ''
        );

    my %featureHash = %{$args{featureHash}};
    my %licenseCount;
    foreach my $feature (keys %featureHash) {
        $licenseCount{$feature} = 0;
    }

    foreach my $unassignedLicense (@unassignedLicenses){
        # which licenses need to be associated.
        if ((exists $featureHash{$unassignedLicense->[1]}) and ($licenseCount{$unassignedLicense->[1]} < $featureHash{$unassignedLicense->[1]})) {
            $form_fields{'checkedOid'} .= $unassignedLicense->[10]->[1]->{optionValue} . ',';
            $licenseCount{$unassignedLicense->[1]}++;
        }else {
            $form_fields{'uncheckedOid'} .= $unassignedLicense->[10]->[1]->{optionValue} . ',';
        }
        $form_fields{'featureIdType'} = $unassignedLicense->[11];
    }
        
    my $flag = 1;
    foreach my $feature (keys %featureHash) {
        if ($licenseCount{$feature} < $featureHash{$feature}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Requested number of licenses are not available. Requested : " . $featureHash{$feature} . ". Available : " . $licenseCount{$feature});
            $logger->debug(__PACKAGE__ . ".$sub_name: unassignedLicenses : ". Dumper(\@unassignedLicenses));
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
            $flag = 0;
            last;
        }
    }

    return 0 unless($flag);


    $json = encode_json(\%form_fields);
    $logger->debug("\$params: $json");
    $request= POST "https://$args{ems_ip}/licmgmt/v1.0/license/associateOrDissociate";
    $request->header('Content-Type' => 'application/json');
    $request->content($json);
    $args{cookie_jar}->add_cookie_header( $request );
    $response = $args{ua}->request( $request );

    unless ($response->is_success) {
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to associate licenses");
        $logger->debug(__PACKAGE__ . ".$sub_name: Request: POST https://$args{ems_ip}/licmgmt/v1.0/license/associateOrDissociate");
        $logger->debug(__PACKAGE__ . ".$sub_name: Response Status Line : ". $response->status_line);
        $logger->debug(__PACKAGE__ . ".$sub_name: Response Content : ". $response->decoded_content);
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
        return 0;
    }

    $decoded_message = decode_json($response->decoded_content);
    $logger->debug(__PACKAGE__ . ".$sub_name: Response Content : ". Dumper($decoded_message));

    if (exists $decoded_message->{Error}){
        $logger->error(__PACKAGE__ . ".$sub_name: License association failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: Request: POST https://$args{ems_ip}/licmgmt/v1.0/license/associateOrDissociate");
        $logger->debug(__PACKAGE__ . ".$sub_name: Error: ". Dumper($decoded_message->{Error}));
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [1]");
    return 1;
}


sub associateLicenses {

    my ($ems_ip, $node_name, %featureHash) = @_;
    my ($node_id, $node_ip, $node_type, %form_fields, $decoded_message, @nodes, @unassignedLicenses, %licenseCount, $version);

    $ems_ip = is_ipv6($ems_ip) ? "[$ems_ip]" : $ems_ip;
    my $sub_name = "associateLicenses";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");

    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0);
    $ua->ssl_opts( SSL_verify_mode => 0 );

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    my $username = 'admin';
    my $password = 'admin';

    ($ua, $cookie_jar) = &loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);

    unless($ua){
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub [0]");
        return 0;
    }

    #TOOLS-75432 changes in EMS V13.00.00
    if (SonusQA::Utils::greaterThanVersion( $ua->{EMS_VERSION} ,'V13.00.00')) {
        my $ret = associateLicensesV13(ems_ip => $ems_ip, node_name => $node_name, featureHash => \%featureHash, ua => $ua, cookie_jar => $cookie_jar);
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub [$ret]");
        return $ret;
    }

    # fetch node details
    $logger->debug("Fetching node details");
    %form_fields = (
            'op' => 'getLicenseTargetNodeList'
        );
    my $request = POST "https://$ems_ip/licmgr/LicenseServlet?op=getLicenseTargetNodeList&ts", \%form_fields;
    $cookie_jar->add_cookie_header( $request );
    my $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }

    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);

    eval{ 
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    @nodes = @{ $decoded_message->{aaData} };

    foreach my $node (@nodes){
        if ($node->[2] eq $node_name) {
            $node_ip = $node->[3];
            $node_id = $node->[0];
            $node_type = $node->[1];
        }
    }

    # fetch all unassigned licenses
    %form_fields = (
            'op' => 'getUnassignedLicenses',
            'deviceType' => $node_type,
            'targetOid' => $node_id,
            'nodeIp' => $node_ip
        );

    $logger->debug("Fetching all unassigned licenses" . Dumper(\%form_fields));
    $request = POST "https://$ems_ip/licmgr/LicenseServlet", \%form_fields;
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }
    $logger->debug("Response Status Line : ". $response->status_line);

    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    @unassignedLicenses = @{ $decoded_message->{aaData} };

    # associate or dis-associate licenses
    %form_fields = (
            'op' => 'assocOrDissocMultipleLicense',
            'nodeType' => $node_type,
            'targetOid' => $node_id,
            'nodeIp' => $node_ip,
            'checkedOid' => '',
            'uncheckedOid' => ''
        );

    foreach my $feature (keys %featureHash) {
        $licenseCount{$feature} = 0;
    }

    foreach my $unassignedLicense (@unassignedLicenses){
        # which licenses need to be associated.
        if ((exists $featureHash{$unassignedLicense->[1]}) and ($licenseCount{$unassignedLicense->[1]} < $featureHash{$unassignedLicense->[1]})) {
            $form_fields{'checkedOid'} .= $unassignedLicense->[10]->[1]->{optionValue} . ',';
            $licenseCount{$unassignedLicense->[1]}++;
        }else {
            $form_fields{'uncheckedOid'} .= $unassignedLicense->[10]->[1]->{optionValue} . ',';
        }
        $form_fields{'featureIdType'} = $unassignedLicense->[11];
    }

    foreach my $feature (keys %featureHash) {
        if ($licenseCount{$feature} < $featureHash{$feature}) {
            $logger->error("Requested number of licenses are not available. Requested : " . $featureHash{$feature} . ". Available : " . $licenseCount{$feature});
            return 0;            
        }
    }

    $logger->debug("Associating licenses" . Dumper(\%form_fields));
    $request = POST "https://$ems_ip/licmgr/LicenseServlet", \%form_fields;
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }

    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }


    if (defined $decoded_message->{Error}){
        $logger->error("License association failed : ". Dumper(\$decoded_message->{Error}));
        return 0;
    }

    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

#TOOLS-19244
sub associateLicenseDLL{
    my ($ems_ip, $node_name, %featureHash) = @_;
    my ($node_id, $node_ip, $node_type, %form_fields, $decoded_message, @nodes, @unassignedLicenses, %licenseCount, $request, $response);
    $ems_ip = is_ipv6($ems_ip) ? "[$ems_ip]" : $ems_ip;
    my $sub_name ="associateLicenseDLL";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");
    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0);
    $ua->ssl_opts( SSL_verify_mode => 0 );

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    my $username = 'admin';
    my $password = 'admin';
    ($ua, $cookie_jar) = &loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);

    # fetch node details
    $logger->debug("Fetching node details");
    %form_fields = (
            'op' => 'getLicenseTargetNodeList'
        );
    if (SonusQA::Utils::greaterThanVersion( $ua->{EMS_VERSION} , 'V12.00.00' )) {
        $request = GET "https://$ems_ip/licmgr/LicenseServlet?op=getLicenseTargetNodeList&ts", \%form_fields;
    } else {
        $request = POST "https://$ems_ip/licmgr/LicenseServlet?op=getLicenseTargetNodeList&ts", \%form_fields;
    }
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
        $logger->error("Response Status Line : ". $response->status_line);
        $logger->error("Response Content : \n". $response->decoded_content);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);
    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    @nodes = @{ $decoded_message->{aaData} };

    foreach my $node (@nodes){
        if (lc($node->[2]) eq lc($node_name)) {
            $node_ip = $node->[3];
            $node_id = $node->[0];
            $node_type = $node->[1];
        }
    }
    %form_fields = (
            'op' => 'instancesToAllocate',
            'deviceType' => $node_type,
            'targetOid' => $node_id,
            'nodeIp' => $node_ip
        );
    $request=GET "https://$ems_ip/licmgmt/v1.0/NWDLLicenses/$node_type";
    $cookie_jar->add_cookie_header( $request );
    $request->header('Content-Type' => 'application/json');
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }
    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);
    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    @unassignedLicenses = @{ $decoded_message->{aaData} };
    my $json;
    my $i = 0;    
    for my $unassignedLicense( sort{ lc($a->[3]) cmp lc($b->[3]) } @unassignedLicenses ){
        if ((exists $featureHash{$unassignedLicense->[1]}) and ($unassignedLicense->[2] >= $featureHash{$unassignedLicense->[1]}) and !(exists $licenseCount{$unassignedLicense->[1]})) {
                $licenseCount{$unassignedLicense->[1]} =1;
                $json.="{\"key\":\"$unassignedLicense->[8]\",\"value\":\"$featureHash{$unassignedLicense->[1]}\"}" . ',';
		$i++;           
        }
        if($i > keys %featureHash){
           last;
        }

    }
     $json =~ /^(.*),$/;
     $json = $1;
    $json="{\"nodeType\":\"$node_type\",\"targetOid\":\"$node_id\",\"instancesToAllocate\":[$json]}";
    $logger->debug("Associating licenses" . Dumper(\%form_fields));
    $request= POST "https://$ems_ip/licmgmt/v1.0/license/associateNWDL";
    $request->header('Content-Type' => 'application/json');
    $request->content($json);
     $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Response Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
      return 0;
    }

    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }


    if (defined $decoded_message->{Error}){
        $logger->error("License association failed : ". Dumper(\$decoded_message->{Error}));
        return 0;
    }

    $logger->debug("Response Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 checkStatus()

=over

=item DESCRIPTION

This is the subroutine which is being called to check the status of the created Cloud Instance or any process status.
Can be used only if there is any log file to be checked ( eg. /var/log/sonus/lca.log in SBX5000 to check the service status).

=item Arguments

Mandatory Args:
    -log: Need to pass -log as an argument, full path of the log must be provided.
    -pass_phrase: Need to pass -pass_phrase as an scalar argument, this field will be treated as the base for success of the status of the instance
    -fail_phrase: Need to pass -fail_phrase as an argument, this field will be treated as the base for failure of the status of the instance (can be passed as scalar or array reference if multiple failure phrases needs to be checked)

    if root object of the instance is already defined, then 
      -obj: Need to pass -obj as the argument, root object of the instance
    else
      -ip: Need to pass -ip as the argument, Ip of the instance
      -userid: Need to pass -userid as the argument, userid of the instance
      -passwd: Need to pass -passwd as the argument, password of the instance

    Optional Args
      -identity_file: Need to pass -identity_file as the argument, if any keys are used to connect to the instance
      -port: Need to pass -port as the argument, default is 22
      -wait: Need to pass -wait as the argument, default is 30 seconds
      -loop: Need to pass -loop as the argument, default is 20 repeatition

=item Returns

0  - If Fails at any stage of status check 
1  - If Passes at any stage of status check 
-1  - If Neither Failure nor Success and we run out of specified loop
%cmdResult   - hash referance will be returned containing the last 15 lines from where the match has occurred.

=item Example

my %args = (
    -ip => $ip,
    -userid => $userid,
    -passwd => $passwd,
    -pass_phrase => $pass_phrase,
    -fail_phrase => $fail_phrase,
    -log => $log,
);

Pass the Reference of the Arguments Hash ( eg. my %args = (); SonusQA::ATSHELPER::checkStatus(\%args); )

    my ($checkStatusResult, $checkStatusCmdResult) = SonusQA::ATSHELPER::checkStatus( \%args );

    if ( $checkStatusResult == 1 ) {
	$logger->debug(__PACKAGE__.'->'.__LINE__.":: $sub Status of the instance is up and running.");
    } elsif ( $checkStatusResult == 0 ) {
	$logger->debug(__PACKAGE__.'->'.__LINE__.":: $sub Status of the instance is down.".Dumper($checkStatusCmdResult));
    } else {
	$logger->debug(__PACKAGE__.'->'.__LINE__.":: $sub Not Found.Ran out of time!.".Dumper($checkStatusCmdResult));
    }

=back

=cut

sub checkStatus {
	my $sub = 'checkStatus';
	my ($args) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Entered Sub -->");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Args : ".Dumper($args));

# 	Default values for loop and wait to 20 (times) and 30 seconds respectively
	$args->{-loop} ||= 60;
	$args->{-wait} ||= 30;

	my @mandatory = ( 'pass_phrase', 'fail_phrase', 'log' );
	my $mandate_flag = 1;
	foreach ( @mandatory ) {
		unless ( defined ( $args->{-$_} ) ) {
			$mandate_flag = 0;
			$logger->error(__PACKAGE__.'->'.__LINE__."::$sub $_ is not present");
			last;
		}
	}
	unless ( $mandate_flag ) {
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
			return 0;
	}
#  	Object Creation
	my $obj = $args->{-obj};
	unless ( $obj ) {
		@mandatory = ( 'ip', 'userid' );
		$mandate_flag = 1;
		foreach ( @mandatory ) {
			unless ( defined ( $args->{-$_} ) ) {
				$mandate_flag = 0;
				$logger->error(__PACKAGE__.'->'.__LINE__."::$sub $_ is not present");
				last;
			}
		}
		unless ( $mandate_flag ) {
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
			return 0;
		}
		my %args = (
				-obj_user => $args->{-userid},
				-comm_type => 'SSH',
				-obj_host => $args->{-ip},
				-sessionlog => 1,
				-return_on_fail => 1,
				-obj_password => $args->{-passwd},
				-obj_port => $args->{-port},
				-obj_key_file => $args->{-identity_file},
                                -failures_threshold => $args->{-failures_threshold}, #TOOLS-15398
			   );

#	delete $args{-obj_password} if $args{-obj_key_file};
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub base args : ".Dumper(\%args));
		unless ( $obj = SonusQA::Base->new (%args) ) {
			$logger->error_warn(__PACKAGE__.'->'.__LINE__."::$sub Obj Creation for ip [$args->{-ip}] FAILED");
			$logger->error_warn(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
			return 0;
		}
#	For SBX5000, becoming root fixes the prompt issue.
        if ( $args->{-root_password} ){
            unless (SonusQA::SBX5000::SBX5000HELPER::becomeRoot($obj, $args->{-root_password})) {
                $logger->error(__PACKAGE__ . ".$sub: unable to enter as root");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
        }
        if ( ( $args->{-type} eq 'PSX') and !$obj->enterRootSessionViaSU('sudo') ) {
            $logger->debug(__PACKAGE__. ".$sub: Failed to enter root session");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
	}
        my $retry_flag = 1;
        RETRY: #TOOLS-16097 - EMS connection closed by remote host.
	my @cmdResult = ();
	my $match;

#	Initializing while exit, number of loop times and result of the searched pattern to 1, 0 & 0 respectively
	my ( $loop, $result, $flag  ) = ( 0, -1 , 0);
        my $cmd = "tail $args->{-log} ";

	while ( $result == -1 and $loop <= $args->{-loop}) {

#  	Dumping last 10 line from the file
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub executing cmd : $cmd");
		unless (@cmdResult = $obj->{conn}->cmd(String => $cmd, Timeout => 300)) {
			$logger->error(__PACKAGE__.'->'.__LINE__."::$sub Failed to execute the shell command:$cmd ".Dumper(\@cmdResult));
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub errmsg: " . $obj->{conn}->errmsg);
                        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub lastline: " . $obj->{conn}->lastline);
                        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Buffer : " . $obj->{conn}->buffer);

                        if( ${$obj->{conn}->buffer} =~ /Connection to $args->{-ip} closed by remote host/g and $retry_flag ){
                               $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Got \'Connection to $args->{-ip} closed by remote host\' so reconnecting to $args->{-ip}");
                               unless($obj->reconnect){
                                       $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Failed to reconnect ..");
                                       $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0]");
                                       return 0;
                               }
                               $retry_flag = 0; #Only once we will reconnect.
                               goto RETRY;
                        }
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Dump Log is : $obj->{sessionLog1}");
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Input Log is: $obj->{sessionLog2}");
                        last ;
		}

                if ((!$flag and $cmd =~ /lca\.log/) and ($cmdResult[0] =~ /tail: cannot open.+$args->{-log}.+for reading: No such file or directory/))  {              #TOOLS - 14445
                            $flag = 1;
                            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub '$args->{-log}' is not found, so changing the lca.log file to '/var/log/sonus/lca.log'");
                            $cmd = 'tail /var/log/sonus/lca.log';
                            next;
                }
  
		chomp(@cmdResult);

#  	Searching for pass_phrase/fail_phrase in the cmdResult and setting result to 1/0 if grep passed/failed
		for ( my $i=0;$i<=$#cmdResult;$i++) {
			$match = $i;
                        $result = 0 if ( $cmdResult[$i] =~ /$args->{-fail_phrase}/i); #TOOLS-17790
                        $result = 1 if ( $cmdResult[$i] =~ /$args->{-pass_phrase}/i);
			last if ( $result != -1 );
		}

#  	Waiting for -wait seconds
		if ( $result == -1 ) {
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub waiting for $args->{-wait}s!");
			sleep $args->{-wait};
		}
		$loop++;
	}
#  	To check how much time it took to search the pass_phrase/fail_phrase in the log file
	my $waited = $args->{-wait} * $loop;

#  	Splicing the cmdResult to the last 15 lines from where match is found
	@cmdResult = @cmdResult[($match-15)..($match)];
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Failure observed while checking the status log. Last 15 lines from where the failure match was found".Dumper(\@cmdResult)) unless ( $result );
    $obj->{-instance} = $args->{-instance};
    SonusQA::PSX::getCloudPsxLogs( -obj => $obj, -file_prefix => $args->{-instance}) if( ($args->{-type} eq 'PSX') and ($result =~ /^[01]$/) );
    $obj->leaveRootSession() if ($args->{-type} eq 'PSX');
#  	Destroying Object ( if not provided in the args of -obj )
	$obj->DESTROY unless ( $args->{-obj} );
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub waited for $waited seconds ");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[$result] ");
	return ($result, \@cmdResult);
} ## --- end sub checkStatus

=head2 getSshKey()

=over

=item DESCRIPTION

This is the subroutine which is being called to get the ssh key for the provided user

=item Arguments

Mandatory Args:
if root object of the instance is already defined, then 
    -obj: Need to pass -obj as the argument, linux session object of the instance
else
    -ip: Need to pass -ip as the argument, Ip of the instance
    -userid: Need to pass -userid as the argument, userid of the instance
    -passwd: Need to pass -passwd as the argument, password of the instance

Optional Args
    -identity_file: Need to pass -identity_file as the argument, if any keys are used to connect to the instance
    -port: Need to pass -port as the argument, default is 22

=item Returns

$string   - string will be returned 

=item Example

my %args = (
    -ip => $ip,
    -userid => $userid,
    -passwd => $passwd,
    -identity_file => $identity_file,
);

Pass the Reference of the Arguments Hash ( eg. my %args = (); SonusQA::ATSHELPER::getSshKey(\%args); )

    my $sshKey = SonusQA::ATSHELPER::getSshKey( \%args );

    unless ( $sshKey = SonusQA::ATSHELPER::getSshKey( \%args )) {
    }

=back

=cut

sub getSshKey {
	my $sub = 'getSshKey';
	my ($args) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Entered Sub -->");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Args : ".Dumper($args));

#  	Object Creation
	my @mandatory = ( 'ip', 'userid', 'passwd');
	my $mandate_flag = 1;
	my $obj = $args->{-obj};
	unless ( $obj ) {
		foreach ( @mandatory ) {
			unless ( defined ( $args->{-$_} ) ) {
				$mandate_flag = 0;
				$logger->error(__PACKAGE__.'->'.__LINE__."::$sub $_ is not present");
				last;
			}
		}
		unless ( $mandate_flag ) {
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
			return 0;
		}
		my %args = (
				-obj_user => $args->{-userid},
				-comm_type => 'SSH',
				-obj_host => $args->{-ip},
				-sessionlog => 1,
				-return_on_fail => 1,
				-obj_password => $args->{-passwd},
				-obj_port => $args->{-port},
				-obj_key_file => $args->{-identity_file},
			   );

		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub base args : ".Dumper(\%args));
		unless ( $obj = SonusQA::Base->new (%args) ) {
			$logger->error_warn(__PACKAGE__.'->'.__LINE__."::$sub Obj Creation for ip [$args->{-ip}] FAILED");
			$logger->error_warn(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[0] ");
			return 0;
		}
#	For SBX5000, becoming root fixes the prompt issue.
		$obj->becomeUser( -userName => 'root', -password => $args->{-root_password}) if ( $args->{-root_password} );
	}
	my $public_file = '~/.ssh/id_rsa.pub';
	my @cmdResult = ();
	my $getSshKey = "'";

	my $cmd = "ls $public_file";
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub executing cmd : $cmd");
	unless (@cmdResult = $obj->{conn}->cmd($cmd)) {
		$logger->error(__PACKAGE__.'->'.__LINE__."::$sub Failed to execute the shell command:$cmd ".Dumper(\@cmdResult));
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub errmsg: " . $obj->{conn}->errmsg);
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Dump Log is : $obj->{sessionLog1}");
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Input Log is: $obj->{sessionLog2}");
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub [0]");
		return 0;
	}
	chomp(@cmdResult);
	unless ( grep /id_rsa.pub/, @cmdResult ) {
		$logger->error(__PACKAGE__.'->'.__LINE__."::$sub $public_file not found!");
		$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub creating public file using ssh-keygen utility");
		$cmd = "ssh-keygen -t rsa -P oldrsapassphrase -N newrsapassphrase -f id_rsa";
		unless (@cmdResult = $obj->{conn}->cmd($cmd)) {
			$logger->error(__PACKAGE__.'->'.__LINE__."::$sub Failed to execute the shell command:$cmd ".Dumper(\@cmdResult));
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub errmsg: " . $obj->{conn}->errmsg);
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Dump Log is : $obj->{sessionLog1}");
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Input Log is: $obj->{sessionLog2}");
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub [0]");
			return 0;
		}
		chomp(@cmdResult);
	}
	if ( grep /id_rsa.pub/, @cmdResult ) {
		$cmd = "cat $public_file";
		unless (@cmdResult = $obj->{conn}->cmd($cmd)) {
			$logger->error(__PACKAGE__.'->'.__LINE__."::$sub Failed to execute the shell command:$cmd ".Dumper(\@cmdResult));
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub errmsg: " . $obj->{conn}->errmsg);
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Dump Log is : $obj->{sessionLog1}");
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Input Log is: $obj->{sessionLog2}");
			$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub [0]");
			return 0;
		}
		chomp(@cmdResult);
	}
	$getSshKey .= $cmdResult[-1];
	$getSshKey .= "'";

#  	Destroying Object ( if not provided in the args of -obj )
	$obj->DESTROY unless ( $args->{-obj} );
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub ssh keys are $getSshKey");
	$logger->debug(__PACKAGE__.'->'.__LINE__."::$sub <-- Leaving Sub[1] ");
	return $getSshKey;
} ## --- end sub getSshKey

=head2 createAliasFile()

=over

=item DESCRIPTION

This subroutine used to get data from %main::TESTBED for the passed alias and store it in to file. 
This file can be passed to SonusQA::ATSHELPER::newFromAlias() to read data from the passed file instead of TMS. 
Presently it is using in SonusQA::TOOLS::TOOLSHELPER when perfLogger.pl is called. Because in perfLogger.pl we can't access %main::TESTBED, and instead of that we can read the data from alias file.
Refer TOOLS-15041 for more information.

=item Arguments

Mandatory Args:
    -alias : alias name
    -path : complete path to create alias file. File will be created in the working directory if not passed.
Optional Args:
    None

=item Returns

$alias_file - for success
0           - for failure

=item Example

my $alias_file = SonusQA::ATSHELPER::createAliasFile(-alias => $alias_name, -path => '/tmp/'); 

=back

=cut

sub createAliasFile{
    my %args = @_;

    my $sub_name = "createAliasFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    my $flag;
    foreach (qw(-alias -path)){
         unless ($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument $_ is not passed.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 1;
            last;
        }
    }

    return 0 if($flag);

    my $ce;
    unless($ce = $main::TESTBED{$args{-alias}}){
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to resolve $args{-alias} from main::TESTBED");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub \[0\]");
        return 0;
    }

    my $alias_file = "$args{-path}/$args{-alias}.pl";
    unless(open (OUT, ">$alias_file")){
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't open '$alias_file' for writting.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    print OUT Dumper($main::TESTBED{"$ce:hash"});
    close OUT;

    $logger->info(__PACKAGE__ . ".$sub_name: resolved $args{-alias} from main::TESTBED{$ce:hash} and stored in '$alias_file'");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$alias_file]");
    return $alias_file;
}

=head2 validator()

=over

=item DESCRIPTION:

    Internal use only. Used by verifyCapturedMsg()
    Used to match the patter present in array referance and also goes recursive untill we get array referance.

=item ARGUMENTS:

    Mandatory:
    - pattern : array reference of patterns to match
    - data : either array reference or hash reference
    - start_msg : if empty search will start from the first line

    Optional:
    - returnpattern : 1 or 0. 0 by default

=item PACKAGE:

    SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

    None

=item FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search patterns found)
    (1, $return_value) - return hash reference of the values if returnpattern is 1 and if all of the search patterns found.

=item EXAMPLE:

    my ($resultvalidator, $returnvalidator) = SonusQA::ATSHELPER::validator($input{$msg}->{$occurrence}, $content{$msg}{$occurrence},"",1);
    unless ( $resultvalidator ) {
        $logger->error(__PACKAGE__ . ".$sub: not all the pattern of $occurrence occurrence of $msg present in captured data");
    }

=back

=cut

sub validator {
    my ($pattern, $data, $start_msg, $returnpattern) = @_;
    
    my $sub = "validator()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $returnpattern ||= 0;
    my %returnvalues;
    $logger->debug(__PACKAGE__ . ".$sub: pattern===== ". Dumper($pattern));
    $logger->debug(__PACKAGE__ . ".$sub: data ======== ". Dumper($data));
    $logger->debug(__PACKAGE__ . ".$sub: start_msg ======== $start_msg");
    $logger->debug(__PACKAGE__ . ".$sub: returnpattern ===  $returnpattern");
    #TOOLS-18561
    if(ref($data) eq 'HASH') {
        my ($resultvalidator, $returnvalidator);
        $logger->debug(__PACKAGE__ . ".$sub: going for recursive to validate in any occurrence, since data passed is a hash reference");
        foreach my $occurrence (sort { $a <=> $b } keys %{$data}){
            $logger->debug(__PACKAGE__ . ".$sub: calling recurrsive for $occurrence th occurrence");
            ($resultvalidator, $returnvalidator) = SonusQA::ATSHELPER::validator($pattern, $data->{$occurrence}, '', $returnpattern);
            if ( $resultvalidator ) {
                $logger->info(__PACKAGE__ . ".$sub: found all the patterns in $occurrence th occurrence");
                last;
            }
        }
        unless($resultvalidator){
            $logger->error(__PACKAGE__ . ".$sub: not all the patterns are present in captured data");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        if( $returnpattern){
            return (1, $returnvalidator);
        }
        else{
            return 1;
        }
    }
    #TOOLS-18561

    unless (ref($pattern)eq 'ARRAY') {
        $logger->debug(__PACKAGE__ . ".$sub: its not direct data validation, have a key hence going for recursive call of verifyCapturedMsg()");
        foreach my $key (keys %{$pattern}) {
            $logger->debug(__PACKAGE__ . ".$sub: calling recurrsive for msg header $key");
            my ($resultvalidator, $returnvalidator) = SonusQA::ATSHELPER::validator($pattern->{$key}, $data, $key, $returnpattern); 
            unless ( $resultvalidator ) {
                $logger->error(__PACKAGE__ . ".$sub: not all the pattern of $key present in captured data");
                $main::failure_msg .= "TOOLS:TSHARK- Pattern NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            $returnvalues{$key} = $returnvalidator;
            $logger->info(__PACKAGE__ . ".$sub: found all the pattern of $key");
        }
    } else {
        my $msg_found = 0;
        my $start_index = 0;
        if (defined $start_msg and $start_msg) {
            my @presence = grep { $data->[$_] =~ /$start_msg/} 0..$#$data;
            unless (scalar @presence) {
                $logger->error(__PACKAGE__ . ".$sub: msg line $start_msg not found");
                $main::failure_msg .= "TOOLS:TSHARK- MsgLine $start_msg NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            $start_index = $presence[0];
        }

	my %matched =  map { $_ => 1 } @{$pattern}; #dereferencing and storing keys in a hash
        foreach my $index ( $start_index..$#$data) {
			
	foreach my $required_mtach (keys %matched){
            if ($data->[$index] =~ /$required_mtach/i) {
                if( $returnpattern ){
                    if( $data->[$index] =~ /(^\s+)(.*):\s(.*)$/ ){
                        my ($k,$v);
                        $k = $2;
                        $v = $3;
                        chomp $k;
                        $k =~ s/^[^a-zA-Z]//g;
                        chomp $v;
                        $v =~ s/\]//g;
                        $returnvalues{$k} = $v;
		    }
                }
                $logger->info(__PACKAGE__ . ".$sub: pattern \'$required_mtach\' found");
	    delete $matched{$required_mtach};
	    last;
            }
			}
			last unless(keys %matched);
        }

		
        foreach ( keys %matched) {
                $logger->error(__PACKAGE__ . ".$sub: pattern $_ not found in captured data");
               $main::failure_msg .= "TOOLS:TSHARK- Pattern NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
        }
		
    }
    
    $logger->info(__PACKAGE__ . ".$sub: found all the pattern for msg -> $start_msg") if (defined $start_msg);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    if( defined $returnpattern and $returnpattern){
        return (1,\%returnvalues);
    }else{
        return 1;
    }  
}

=head2 clusterOperation()

=over

=item DESCRIPTION:

    Function to perform cluster related operations like create, delete.

=item ARGUMENTS:

    args hash - parameters required for cluster operation

=item PACKAGE:

    SonusQA::ATSHELPER

=item GLOBAL VARIABLES USED:

    None

=item FUNCTIONS USED:

    loginToEMSGUI

=item OUTPUT:

    0 - fail 
    cluster_name - Success 

=item EXAMPLE:

    my %form_fields = (
                            'ems' => $ems,
                            'op' => 'createCluster',
                            'cluster_name' => "oamcluster",
                            'cluster_ident' => "oamcluster",
                            'cluster_type' => 'SBC SWe',
                            'cluster_subtype' => 'ssbc',
                            'cluster_configtype' => 'OAM',
                            'Reachability_polling_interval' => '1',
                            'Registration_Complete_interval' => '20',
                            'Offline_reachability_polling_interval' => '24',
                            'Unregistered_node_interval' => '7'
                        );
    $args{'cluster_id'} = SonusQA::ATSHELPER::clusterOperation(%form_fields);
    unless($args{'cluster_id'}){
        $logger->debug(__PACKAGE__ . ".$sub: Failed to create cluster for OAM $aliasname");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub[0]");
        return 0;
    }

=back

=cut

sub clusterOperation {
    my %args = @_;
    my $sub = "clusterOperation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub".Dumper \%args);
    my $decoded_message;
    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0);
    $ua->ssl_opts( SSL_verify_mode => 0 );

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );
    my $ems_ip = $args{ems};
    delete $args{ems};
    my $username = 'admin';
    my $password = 'admin';
    ($ua, $cookie_jar) = &loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);

    $ems_ip = "[$ems_ip]" if($ems_ip =~ /:/);

    my $request = GET "https://$ems_ip/cluster/ClusterServlet?op=getClusterList";
    $cookie_jar->add_cookie_header( $request );
    my $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
        $logger->debug("Request \'/cluster/ClusterServlet?op=getClusterList\' failed");
        $logger->error("Response Status Line : ". $response->status_line);
        $logger->debug("Response Content : \n". $response->decoded_content);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }

    my $oamList = $decoded_message->{aaData};
    foreach my $oams(@$oamList){
        if ( grep( /^$args{cluster_name}$/, @$oams) ) {
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub ".Dumper $oams);
                return @$oams[1];
        }
    }

    if (SonusQA::Utils::greaterThanVersion( $ua->{EMS_VERSION} , 'V13.00.00')) {
        $request = GET "https://$ems_ip/cluster/JavaScriptServlet";
        $cookie_jar->add_cookie_header( $request );
        $response = $ua->request( $request );
        $cookie_jar->extract_cookies( $response );

        if ($response->{'_content'} =~ /\"OWASP_CSRFTOKEN\", \"(.+)\"/ ) {
            $ua->default_header( "OWASP_CSRFTOKEN"   => $1 );
        }else {
            $logger->debug("Request \'/cluster/JavaScriptServlet\' failed");
            $logger->error("Response Status Line : ". $response->status_line);
            $logger->debug("Response Content : \n". $response->decoded_content);
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $ua->default_header( 'X-Requested-With' => 'XMLHttpRequest, OWASP CSRFGuard Project');
    }

    $request = POST "https://$ems_ip/cluster/ClusterServlet", \%args;
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );
    unless ($response->is_success) {
        $logger->debug(" Post Request \'/cluster/ClusterServlet\' failed");
        $logger->error("Response Status Line : ". $response->status_line);
        $logger->debug("Response Content : \n". $response->decoded_content);
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    eval{
    $decoded_message = decode_json($response->decoded_content);
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->decoded_content));
    }


    my @results = $decoded_message->{results};
    if($results[0][0][0] =~ /Success/i){
        my $res = ($args{'op'} =~ /create/) ? $results[0][1]->{clusterIdentifier} : 1;
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$res]");
        return $args{cluster_name};
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
}

=head1 B<SonusQA::EMSCLI::registerPSXNodeNew()>

  Helper function for registering PSX or insight node in EMS 10.3 versions and above.

=over 6

=item Arguments :

  Mandatory :
      -ua - user agent object
      -cookie_jar - cookie jar to store cookie
      -ems_ip - ip on which psx needs to be registered
      -node_ip - ip to be registered.
      -node_name - name to be registered
  Optional :
      -ssh_login - EMS login username
      -ssh_passwd - EMS login password

=item Return Values :

  1 - if successfully
  0 - otherwise

=item Example :

  SonusQA::ATSHELPER::registerPSXNodeNew( 'ua' => $ua, 'cookie_jar' => $cookie_jar, 'ems_ip' => $ems_ip,'node_ip' => $node_ip,'node_name' => $node_name, 'ssh_login' => $ssh_login, 'ssh_passwd' => $ssh_passwd )

=back

=cut

sub registerPSXNodeNew {
    my %args = @_;
    my $ua = $args{'ua'} ;
    my $cookie_jar = $args{'cookie_jar'} ;

    my $sub_name = "registerPSXNodeNew";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");

    my ($url , $request , $response, $response_id_ref, %response_id, $master_node_id) ;
    my $ems_ip = $args{'ems_ip'};
    $args{ems_ip} = "[$args{ems_ip}]" if($args{ems_ip} =~ /:/);
    $args{'node_type'} = 'PSX6000' if ($args{'node_type'} =~ /PSX/);
    my %form_fields =(
                  "name" => "$args{'node_name'}",
                  "trapDestinationConfiguredDisplay" => "Not Configured",
                  "reachabilityPollingMillis" => "60000",
                  "slave" => "false",
                  "mgmtUsername" => "admin",
                  "mgmtPassword" => "ServerPopulated",
                  "mgmtPort" => "4330",
                  "testDBMgmtPort" => "0",
                  "ssreqPort" => "3091",
                  "serverNifIp" => "$ems_ip",
                  "agentLogin" => "admin",
                  "agentPassword" => "ServerPopulated",
                  "snmpReadCommunity" => "ServerPopulated",
                  "snmpPort" => "161",
                  "databaseSid" => "SSDB",
                  "databaseUsername" => "insightuser",
                  "databasePassword" => "ServerPopulated",
                  "databasePort" => "1521",
                  "haEnabled" => "false",
                  "ip1" => "$args{'node_ip'}",
                  "ip" => "$args{'node_ip'}",
                  "sshEnabled" => "true",
                  "sshLogin" => "$args{'ssh_login'}",
                  "sshPassword" => "$args{'ssh_passwd'}",
                  "enabledAlternates" => "false",
                  "type" => "$args{'node_type'}",
                  "ftpLogin" => "root",
                  "platformType" => "Linux x86_64"
              );
    
    if ($args{'master_node'}){
        $url = "https://$args{'ems_ip'}/nodeMgmt/v1.0/nodes/getPsxMasterNodes" ;
        $request = HTTP::Request->new( 'GET', $url );
        $response = $ua->request( $request );
        $cookie_jar->extract_cookies( $response );
        eval{   
        $response_id_ref  = decode_json($response->{_content}) ;
        };
        if($@){
    	$logger->error(" ERROR: COULD NOT DECODE JSON");
    	$logger->error(" RESPONSE: ".Dumper($response->{_content}));
	}

        %response_id = %{$response_id_ref} ;
        foreach (@{$response_id{"items"}}){
            if ($_->{"displayName"} eq $args{'master_node'}) {
                 $master_node_id = $_->{'id'};
                 last;
            }
        }
        $form_fields{"slave"} = "true" ;
        $form_fields{"masterNodeId"} = $master_node_id;
        $request->method('POST') ;
        $request->uri("https://$args{'ems_ip'}/nodeMgmt/v1.0/nodes" );
    }else {
        $url = "https://$args{'ems_ip'}/nodeMgmt/v1.0/nodes" ;
        $request = HTTP::Request->new( 'POST', $url );
    }

    $request->header( 'Content-Type' => 'application/json' );
    my $json = encode_json(\%form_fields) ;
    $request->content($json); ;
    $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    if ( $response->{_content} =~ /already exists/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name: The node is already registered ");
        $logger->error(__PACKAGE__ . ".$sub_name: $response->{_content} ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;
    }
    eval{
    $response_id_ref  = decode_json($response->{_content}) ;
    };
    if($@){
    $logger->error(" ERROR: COULD NOT DECODE JSON");
    $logger->error(" RESPONSE: ".Dumper($response->{_content}));
    }

    %response_id = %{$response_id_ref} ;
    my $node_id = $response_id{'id'} ;

    $request->method('PUT') ;
    $request->uri("https://$args{'ems_ip'}/nodeMgmt/v1.0/nodes/$node_id/actions/registerNode" );
    $response = $ua->request( $request );

    $request->method('PUT') ;
    $request->uri("https://$args{'ems_ip'}/nodeMgmt/v1.0/nodes/$node_id/actions/discoverNode") ;
    %form_fields = (
                "nodeId"=> "$node_id",
                "name"=> "$args{'node_name'}",
                "type"=> "$args{'node_type'}",
                "displayType"=> "PSX Policy Server",
                "version"=> "Unknown",
                "ip"=> "$args{'node_ip'}",
                "snmpPort"=> "161",
                "snmpReadCommunity"=> "ServerPopulated",
                "snmpWriteCommunity"=> "ServerPopulated",
                "snmpTrapCommunity"=> "ServerPopulated",
                "serverNifIp"=> "$ems_ip",
                "lastChangeTime"=> "1520492572345",
                "enabled"=> "true",
                "perfDataCollecting"=> "false",
                "perfDataPollingMillis"=> "900000",
                "perfDataRetentionMillis"=> "0",
                "reachabilityPollingMillis"=> "60000",
                "trapDestinationConfigured"=> "1",
                "trapDestinationConfiguredDisplay"=> "Not Configured",
                "sshEnabled"=> "true",
                "pmLastCollection"=> "0",
                "pmLastCollectionStatus"=> "false",
                "snmpVersion"=> "1",
                "restSupported"=> "false",
                "nodeStatus"=> "Registered - Offline",
                "nodeState"=> "Offline",
                "standalone"=> "true",
                "mgmtPort"=> "4330",
                "mgmtUsername"=> "admin",
                "mgmtPassword"=> "ServerPopulated",
                "slave"=> "false",
                "databaseSid"=> "SSDB",
                "databasePort"=> "1521",
                "databaseUsername"=> "insightuser",
                "databasePassword"=> "ServerPopulated",
                "acctSyncStatus"=> "1",
                "epx"=> "false",
                "provisionOnlyMaster"=> "false",
                "ssreqPort"=> "3091",
                "agentLogin"=> "admin",
                "agentPassword"=> "ServerPopulated",
                "haEnabled"=> "false",
                "sshLogin"=> "ssuser",
                "sshPassword"=> "ServerPopulated",
                "ip1"=> "$args{'node_ip'}"
            );
    $json = encode_json(\%form_fields) ;
    $request->content($json);
    $response = $ua->request( $request );

    my $return_flag = ($response->is_success) ? 1: 0 ;

    $logger->debug("Resonse Status Line : ". $response->status_line);
    $logger->debug("Response Content : \n". $response->decoded_content);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$return_flag]");
    return $return_flag;
}

1;

__END__

Tests for newFromAlias:
1. Call with only valid -tms_alias => Uses __OBJTYPE from TMS
2. Call with only invalid -tms_alias => Finds __OBJTYPE to be blank and errors
3. Call with valid -tms_alias and incorrect -obj_type => Errors when mismatch of obj types found
4. Call with invalid -tms_alias and any valid -obj_type => Empty alias_hash found.
5. Passed in various extra args to see they took affect:
    i)   -obj_user
    ii)  -sessionlog
    iii) -return_on_fail
    iv)  -obj_password
    v)   -obj_port
    => all flags successfully passed to Base::new 
