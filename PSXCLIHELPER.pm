package SonusQA::PSXCLIHELPER;
 
=pod

=head1 NAME

SonusQA::PSXEMSCLI - Perl module for Sonus Networks PSX EMS CLI interaction

=head1 SYNOPSIS

  use ATS;  # This is the base class for Automated Testing Structure

=head2 SUB-ROUTINES

=cut


use strict;
use warnings;
use SonusQA::Utils qw(:errorhandlers :utilities);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;
use XML::Simple;
use Switch;
use Data::UUID;
use Tie::File;
use Fcntl 'O_RDWR', 'O_RDONLY', 'O_CREAT';
use DBM::Deep;
use Data::GUID;
use SonusQA::EMSCLI::EMSCLIHELPER;
require SonusQA::EMSCLI;

our $VERSION = "1.0";

use vars qw($self @ISA $AUTOLOAD @EXPORT_OK %EXPORT_TAGS );
our @ISA = qw(SonusQA::Base);

@EXPORT_OK = (); # keys %methods  -> this would be the xml function names.
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);





=head2 SonusQA::PSXCLIHELPER::createTrunkGroup()
This routine shall create a Trunk Group on PSX 

=over

=item Arguments

Arguments to be passed are to be in the order given below 
TrunkGroupId
GatewayId
CarrierId
CountryId

=item Returns

0 - Error
1 - Success

=item Usage 

$psxObj->createTrunkGroup("In_TG","IN_SS","1001","1")

=item Author 

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createTrunkGroup {

my ($self,$trunkgroupid,$gatewayid,$carrierid,$countryid)=@_;

my $sub="createTrunkGroup";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($trunkgroupid))
{
$logger->error(__PACKAGE__." $sub . TrunkGroup NAME not specified ");
return 0;
}
unless(defined ($gatewayid))
{
$logger->error(__PACKAGE__." $sub . Gateway or Sip Server NAME not specified ");
return 0;
}
unless(defined ($carrierid))
{
$logger->error(__PACKAGE__." $sub . CarrierID not specified ");
return 0;
}
unless(defined ($countryid))
{
$logger->error(__PACKAGE__." $sub . CountryID not specified ");
return 0;
}

unless ($self->execFuncCall("createTrunkgroup",{
                                                'trunkgroup_id' => $trunkgroupid,
                                                'carrier_id'    => $carrierid,
                                                'gateway_id'    => $gatewayid,
                                                'country_id'    => $countryid,
                                                'element_attributes' => '0x100000', 
                                                'signaling_flag'=> '8',
                                         'Destination_Switch_Type' => '1',
                                                  }))

{
$logger->error(__PACKAGE__ ." $sub . TRUNK GROUP CREATION FAILED ");
return 0;
}

$logger->debug(__PACKAGE__ ." $sub . TRUNK GROUP CREATED ");
return 1;

}

=head2 SonusQA::PSXCLIHELPER::createRoutingLabel()

This routine shall create a routing label 

=over

=item Arguments

Arguments to be passed are to be in the order given below
Routing Label Id

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->createRoutingLabel("PSX1_RL")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createRoutingLabel {

my ($self,$routinglabelid,$action,$pm_rule_id)=@_;

my $sub ="createRoutingLabel";

my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

$logger->debug(__PACKAGE__." $sub . CREATING ROUTING LABEL");

unless(defined ($routinglabelid))
{
$logger->error(__PACKAGE__." $sub Routing Label Name not specified ");
return 0;
}

if(defined ($action) ) {

  if(defined ($pm_rule_id) ) {

      unless($self->execFuncCall("createRoutingLabel",{
                'routing_label_id'=>$routinglabelid,
                'Action' => $action,
                 'Pm_Rule_Id' => $pm_rule_id,
       })){
            $logger->error(__PACKAGE__." $sub . FAILED TO CREATE ROUTING LABEL $routinglabelid");
           return 0;
       }
       $logger->debug(__PACKAGE__." $sub . CREATED ROUTING LABEL $routinglabelid");
       return 1;

}

}


unless($self->execFuncCall("createRoutingLabel",{
                'routing_label_id'=>$routinglabelid,
})){
$logger->error(__PACKAGE__." $sub . FAILED TO CREATE ROUTING LABEL $routinglabelid");
return 0;
}
$logger->debug(__PACKAGE__." $sub . CREATED ROUTING LABEL $routinglabelid");
return 1;
}



=head2 SonusQA::PSXCLIHELPER::deleteRoutingLabel()

This routine shall delete a routing label 

=over

=item Arguments

Arguments to be passed are to be in the order given below
Routing Label Id

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->deleteRoutingLabel("PSX1_RL")

=item Author

Rahul Sasikumar <rsasikumar@sonusnet.com>

=back

=cut



sub deleteRoutingLabel{

my ($self,$routinglabelid)=@_;

my $sub ="deleteRoutingLabel";

my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

$logger->debug(__PACKAGE__." $sub . DELETE ROUTING LABEL");

unless(defined ($routinglabelid))
{
$logger->error(__PACKAGE__." $sub Routing Label Name not specified ");
return 0;
}

unless($self->execFuncCall("deleteRoutingLabel",{
                'routing_label_id'=>$routinglabelid,
})){
$logger->error(__PACKAGE__." $sub . FAILED TO DELETE ROUTING LABEL $routinglabelid");
return 0;
}
$logger->debug(__PACKAGE__." $sub .DELETED ROUTING LABEL $routinglabelid");
return 1;



}

=head2 SonusQA::PSXCLIHELPER::createCarrier()

This routine shall create a carrier with the carrier id passed

=over

=item Arguments

Arguments to be passed are to be in the order given below
CarrierId

=item Returns

0 - Error
1 - Success

=item Usage 

$psxObj->createCarrier("1001")

=item Author 

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut


sub createCarrier {

my ($self,$carrierid)=@_;
my $sub = "createCarrier";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($carrierid)){
$logger->error(__PACKAGE__." $sub CarrierID not specified ");
return 0;
}

unless ($self->execFuncCall('createCarrier',{
                                                'carrier_id' => '1001',
                                                 'partition_id' => 'DEFAULT'}))
{

$logger->error(__PACKAGE__ ." $sub . CARRIER CREATION FAILED ");
return 0;
}

$logger->debug(__PACKAGE__ ." $sub . CARRIER CREATED ");
return 1;

}

=head3 SonusQA::PSXCLIHELPER::createZoneindexProfile()

This routine shall create a zone index profile 

=over

=item Arguments

Arguments to be passed are to be in the order given below
Zone Id
Zone Index

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->createZoneindexProfile("INTERNAL","1")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createZoneIndexProfile {

my ($self,$zoneid,$zoneindex)=@_;
my $sub = "createZoneIndexProfile";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($zoneid)){
$logger->error(__PACKAGE__." $sub . ZONE ID NOT SPECIFIED");
return 0;
}

unless(defined ($zoneindex)){
$logger->error(__PACKAGE__." $sub . ZONE INDEX NOT SPECIFIED");
return 0;
}

unless($self->execFuncCall("createZoneIndexProfile",{
                     'Zone_Index_Profile_Id' => $zoneid,
  			'Zone_Index' => $zoneindex,
	           	})){
$logger->error(__PACKAGE__." $sub . ZoneIndexProfile CREATION FAILED ");
return 0;
}

$logger->debug(__PACKAGE__." $sub . ZoneIndexProfile CREATED ");
return 1;
}

=head3 SonusQA::PSXCLIHELPER::createRLRoute()

This routine shall create routing label Routes

=over

=item Arguments

Arguments to be passed are to be in the order given below
RoutingLabelId (Routing Label name to which the route needs to be added)
RouteType
RouteSequence     
endpoint1
endpoint2(Mandatory when RL type 1 or type 2 is to be created)

=item Returns

0 - Error
1 - Success

=item Usage 

$psxObj->createRLRoute("PCR_RL","5","1","TEST_RL1")
$psxObj->createRLRoute("PCR_RL","1","2",$trunkgroup,$gatewayid)
$psxObj->createRLRoute("PCR_RL","2","4",$trunkgroup,$sipserver)

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut


sub createRLRoute {

my ($self,$routinglabelid,$routetype,$routesequence,$endpoint1,$endpoint2)=@_;
my $sub = "createRLRoute";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($routinglabelid)){
$logger->error(__PACKAGE__." $sub . Routing Label NAME not specified ");
return 0;
}

unless(defined ($routetype)){
$logger->error(__PACKAGE__." $sub . Routing Type not specified ");
return 0;
}

unless(defined ($routesequence)){
$logger->error(__PACKAGE__." $sub . Routing Sequence not specified ");
return 0;
}
unless(defined ($endpoint1)){
$logger->error(__PACKAGE__." $sub . EndPoint1 is not specified ");
return 0;
}

if($routetype == "5")
{

$logger->debug(__PACKAGE__." $sub . Creating routing type ROUTING LABEL");

$self->execFuncCall("createRoutingLabelRoutes",{
        'routing_label_id' => $routinglabelid,
        'route_type'       => $routetype,
        'route_sequence'   => $routesequence,
	'route_endpoint1' => $endpoint1,
    });
return 1;
}

else

{
unless(defined ($endpoint2)){
$logger->error(__PACKAGE__." $sub . Gateway or Sipserver not specified ");
return 0;
}
if($routetype == "1")
{
$logger->debug(__PACKAGE__." $sub . Creating routing type GATEWAY");
}
if($routetype == "2")
{
$logger->debug(__PACKAGE__." $sub . Creating routing type SIPSERVER");
}
unless($self->execFuncCall("createRoutingLabelRoutes",{
        'routing_label_id' => $routinglabelid, 
        'route_type'       => $routetype,
        'route_sequence'   => $routesequence,
        'route_endpoint1'  => $endpoint1,
        'route_endpoint2'  => $endpoint2 
    })){
$logger->error(__PACKAGE__. " $sub FAILED to create route on $routinglabelid ");
return 0;
}
$logger->debug(__PACKAGE__. " $sub CREATED Route for $routinglabelid ");
return 1;
}

}

=head2 SonusQA::PSXCLIHELPER::deleteRLRoute()

This routine shall delete routing label Routes

=over

=item Arguments

Arguments to be passed are to be in the order given below
RoutingLabelId (Routing Label name to which the route needs to be added)
RouteType
RouteSequence
endpoint1
endpoint2(Mandatory when RL type 1 or type 2 is to be created)

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->deleteRLRoute("PCR_RL","5","1","TEST_RL1")
$psxObj->deleteRLRoute("PCR_RL","1","2",$trunkgroup,$gatewayid)
$psxObj->deleteRLRoute("PCR_RL","2","4",$trunkgroup,$sipserver)

=item Author

Rahul Sasikumar <rsasikumar@sonusnet.com>

=back

=cut

sub deleteRLRoute {

my ($self,$routinglabelid,$routesequence)=@_;
my $sub = "deleteRLRoute";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($routinglabelid)){
$logger->error(__PACKAGE__." $sub . Routing Label NAME not specified ");
return 0;
}

unless(defined ($routesequence)){
$logger->error(__PACKAGE__." $sub . Routing Sequence not specified ");
return 0;
}


unless($self->execFuncCall("deleteRoutingLabelRoutes",{
        'routing_label_id' => $routinglabelid,
        'route_sequence'   => $routesequence,
    })){
$logger->error(__PACKAGE__. " $sub FAILED to delete route on $routinglabelid ");
return 0;
}
$logger->debug(__PACKAGE__. " $sub deleted Route for $routinglabelid ");
return 1;
}

=head2 SonusQA::PSXCLIHELPER::createStandardRoute

This functions creates Standard Route 

Default Values Set 
call_processing_element_id set to Sonus_NULL
Partition_id is set to DEFAULT

=over

=item Arguments

Arguments to be passed are to be in the order given below
Routin label Id
National
Destination Number 

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->createStandardRoute("PSX_RL","1","234566")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createStandardRoute {

my ($self,$routinglabel,$country,$destination)=@_;
my $sub="createStandardRoute";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($routinglabel)){
$logger->error(__PACKAGE__." $sub . ROUTING LABEL NOT SPECIFIED");
return 0;
}

unless(defined ($country)){
$logger->error(__PACKAGE__." $sub . COUNTRY NOT SPECIFIED");
return 0;
}


unless(defined ($destination)){
$logger->error(__PACKAGE__." $sub . DESTINATION NUMBER NOT SPECIFIED");
return 0;
}

unless($self->execFuncCall("createRoute",{
        'call_processing_element1_id' => 'Sonus_NULL',
        'call_processing_element2_id' => 'Sonus_NULL',
        'call_processing_element3_id' => 'Sonus_NULL',
        'call_processing_element4_id' => 'Sonus_NULL',
        'call_processing_element_type' => '0',
        'routing_type'            => '3',
        'destination_national_id' => $destination,  
        'destination_country_id'  => $country, 
        'partition_id'            => 'DEFAULT',
        'calltype'                => '3072',        # 1+ & IDDD
        'routing_label_id'        => $routinglabel, 
        'transmission_medium'     => '0x1ff',
        'user_call_type'          => 0,
        'digit_type'              => '0x7FFFFFFF', #'2147483647', # optional
        'time_range_profile_id'   => 'ALL',
	})){
$logger->error(__PACKAGE__."$sub . FAILED TO CREATE STANDARD ROUTE");
return 0;
}
$logger->debug(__PACKAGE__."$sub . CREATED STANDARD ROUTE");
return 1;
}

=head2 SonusQA::PSXCLIHELPER::createPMCriteria

This functions creates PM Criteria 

Default Values Set

=over

=item Arguments

=item Returns

0 - Error
1 - Success

=item Usage

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createPMCriteria {

my ($self,$criteriaid,$ruletype,$paramtype)=@_;
my $sub="createPMCriteria";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($criteriaid)){
$logger->error(__PACKAGE__." $sub . Criteria ID not specified ");
return 0;
}

unless(defined ($ruletype)){
$logger->error(__PACKAGE__." $sub . Rule Type not specified ");
return 0;
}


unless(defined ($paramtype)){
$logger->error(__PACKAGE__." $sub . Parameter Type not specified ");
return 0;
}

unless($self->execFuncCall("createPMCriteria",{
				'pm_criteria_id' => $criteriaid,
				'rule_type' => $ruletype,
				'parameter_type' => $paramtype,

})){

$logger->error(__PACKAGE__."$sub . FAILED TO CREATE PMCriteria $criteriaid ");

return 0;
}

$logger->debug(__PACKAGE__."$sub . CREATED PMCriteria $criteriaid ");
return 1;

}

=head2 SonusQA::PSXCLIHELPER::createPMRule

This functions creates PM Rule

=over

=item Arguments

ruleid <rule name>
subruleid <Sequence number >
pmcriteria <criteria created previously>

=item Returns

0 - Error
1 - Success

=item Usage

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut


sub createPMRule {

my($self,$ruleid,$subruleid,$pmCriteria,$value)=@_;
my $sub="createPMRule";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($ruleid)){
$logger->error(__PACKAGE__." $sub . DMPM Rule Name not specified ");
return 0;
}

unless(defined ($subruleid)){
$logger->error(__PACKAGE__." $sub . Sub Rule Sequence not specified ");
return 0;
}

unless(defined ($pmCriteria)){
$logger->error(__PACKAGE__." $sub . Criteria ID not specified ");
return 0;
}
if(defined ($value) ) {
$logger->debug(__PACKAGE__."$sub . Insidee...");

unless($self->execFuncCall("createPMRule",{
                            'pm_rule_id' => $ruleid,
                            'pm_subrule_id' => $subruleid,
                            'pm_criteria_id' =>$pmCriteria,
                            'Const_Rep_Value' =>$value,

})){

$logger->error(__PACKAGE__."$sub . FAILED TO CREATE DM/PM Rule $ruleid");
return  0;
};

$logger->debug(__PACKAGE__."$sub . CREATED DM/PM Rule $ruleid");
return 1;

}



unless($self->execFuncCall("createPMRule",{
                            'pm_rule_id' => $ruleid,
			    'pm_subrule_id' => $subruleid,
			    'pm_criteria_id' =>$pmCriteria,

})){

$logger->error(__PACKAGE__."$sub . FAILED TO CREATE DM/PM Rule $ruleid");
return  0;
};

$logger->debug(__PACKAGE__."$sub . CREATED DM/PM Rule $ruleid");
return 1;

}

=head2 SonusQA::PSXCLIHELPER::createSipServer

This functions creates sip server

=over

=item Arguments

sip server name 
ip adress 
port number

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->createSipServer("PSX_SS","10.128.254.68","4567")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut


sub createSipServer {

my($self,$sipserverid,$ip,$port)=@_;
my $sub="createSipServer";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($sipserverid)){
$logger->error(__PACKAGE__." $sub . SIP SERVER NAME NOT SPECIFIED");
return 0;
}

unless(defined ($ip)){
$logger->error(__PACKAGE__." $sub . IP FOR SERVER NOT SPECIFIED");
return 0;
}
unless(defined ($port)){
$logger->error(__PACKAGE__." $sub . PORT FOR SERVER NOT SPECIFIED");
return 0;
}
unless($self->execFuncCall("createGateway",{
        'gateway_type' => 2,
        'gateway_id' => $sipserverid,
        'ip_address' => '0.0.0.0',
        'switch_id' => 'Switch',
        'sip_ip_sh' => $port,
        'sip_ip_st' => $ip,
       'gateway_group_id' => 'DEFAULT'
    })){

$logger->error(__PACKAGE__." $sub . FAILED TO CREATE SIP SERVER $sipserverid");
return 0;
}

$logger->debug(__PACKAGE__." $sub . CREATED SIP SERVER $sipserverid");
return 1;
}

=head2 SonusQA::PSXCLIHELPER::createIPSignalingProfile

This functions creates IP Signaling Profile

=over

=item Arguments

IP Signaling profile Name 

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->createIPSignalingProfile("PSX_IPSP")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut

sub createIPSignalingProfile {

my ($self,$ipsigprof)=@_;

my $sub="createIPSignalingProfile";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($ipsigprof)){
$logger->error(__PACKAGE__." $sub . IP SIGNALING PROFILE NAME NOT SPECIFIED");
return 0;
}


unless($self->execFuncCall("createIpSignalingProfile",{
        'ip_signaling_profile_id' => "$ipsigprof",
        'protocol_type' => "0",
        'ip_sig_attributes1' => 0x00000001,
        'ip_sig_attributes2' => 0x00000001,
        'sip_signaling_type_version_id' =>"0" ,
        'sip_signaling_type' =>"0" ,
        'sip_signaling_treatment' => "0" ,
        'sip_signaling_redirect_purge' => "0",
        'sip_signaling_redirect_reject' => "0",
        'sip_header_privacy_info' => "1",
        'sip_signaling_transport_type' => "4",
        'sip_originating_tg' => "1",
        'sip_destination_tg' => "1" ,
        'sip_dcs_charge_info' => "0",

        })){
$logger->error(__PACKAGE__ . " $sub . FAILED TO CREATE IPSP : $ipsigprof ");
return 0;
}
$logger->debug(__PACKAGE__ . " $sub . CREATED IPSP : $ipsigprof ");
return 1;

}

=head2 SonusQA::PSXCLIHELPER::FeatureControlProfile

This functions creates Feature Control Profile

=over

=item Arguments

Feature Control Profile ID

=item Returns

0 - Error
1 - Success

=item Usage

$psxObj->FeatureControlProfile("psx_fcp")

=item Author

Sangeetha Siddegowda <ssiddegowda@sonusnet.com>

=back

=cut


sub createFeatureControlProfile {

my ($self,$fcpid)=@_;

my $sub="createFeatureControlProfile";

my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

unless(defined ($fcpid)){
$logger->error(__PACKAGE__." $sub . FEATURE CONTROL PROFILE NAME NOT SPECIFIED");
return 0;
}

unless($self->execFuncCall("createFeatureControlProfile" ,{
                        'feature_control_profile_id' => $fcpid ,

})){

$logger->error(__PACKAGE__ ." $sub . FAILED TO CREATE FCP ");
return 0;
}
$logger->debug(__PACKAGE__ ." $sub . CREATED FCP ");
return 1;

}

=head2 deleteSigtranData()

DESCRIPTION:
    Remove all Sigtran data from PSX

=over 

=item ARGUMENTS:

    None

=item PACKAGE:

    SonusQA::PSXCLIHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    $ems_obj->clearPsxSigtranData();

=back 

=cut

sub deleteSigtranData {
    my ($self, %args) = @_;
    my %a;
    my $sub    = "deleteSigtranData()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # get the arguments
    while ( my ( $key, $value ) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    # #############################
    # Make sure the entries have been removed from the SCPA Configuration
    # before executing this function.
    # #############################
    
    # Sigtran DPC Route
    if($self->execFuncCall("findSigtranDPCRoute", {} )) {
        my ($line, $pc, $prior, $sg, $App);
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            #$logger->debug(__PACKAGE__.".$sub :  $line");
            if ( $line =~ "Sigtran_Destination_Point_Code") {            
                my @fields = split(': ', $line); 
                $pc = $fields[1];
            }
            if ( $line =~ "Sigtran_Dpc_Priority") {            
                my @fields = split(': ', $line); 
                $prior = $fields[1];
            }
            if ( $line =~ "Sigtran_Sg_Id") {            
                my @fields = split(': ', $line); 
                $sg = $fields[1];
            }
            if ( $line =~ "Sua_Network_Appearance_Id") {            
                my @fields = split(': ', $line); 
                $App = $fields[1];
                unless ($self->execFuncCall("deleteSigtranDPCRoute", {
                                            'sigtran_destination_point_code' => $pc,      
                                            'sigtran_dpc_priority'           => $prior,
                                            'sigtran_sg_id'                  => $sg,
                                            'sua_network_appearance_id'      => $App,} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting Sigtran DPC");
                }
            }
        }
    }
    else {
        $logger->debug(__PACKAGE__."  Error in Find Sigtran DPC Routes");
    } 

    # Sigtran SG                                       
    if ($self->execFuncCall("findSigtranSG" )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sigtran_Sg_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSigtranSG", {'sigtran_sg_id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting Sigtran SG");
                }            
            }
        }         
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding Sigtran SG");
    }

    # Sigtran TCAP Registration
    if ($self->execFuncCall("findSigtranTCAPRegistration"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sigtran_Tcap_Registration_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSigtranTCAPRegistration", {'Sigtran_Tcap_Registration_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SigtranTCAPRegistration");
                }            
            }
        }
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SigtranTCAPRegistration");
    }

    # Sigtran Local AS
    if ($self->execFuncCall("findSigtranLocalAS" )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sigtran_Local_As_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSigtranLocalAS", {'Sigtran_Local_As_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SigtranLocalAS");
                }            
            }
        }         
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SigtranLocalAS");
    }

    # SUA SP Label
    if ($self->execFuncCall("findSUASPLabel"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sua_Sp_Label_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSUASPLabel", {'Sua_Sp_Label_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SUASP Label");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SUASP Label");
    }

    # SCTP Associations
    if ($self->execFuncCall("findSCTPAssociation"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sctp_Association_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSCTPAssociation", {'Sctp_Association_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SCTPAssociation");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SCTPAssociation");
    } 

    # SUA SP
    if ($self->execFuncCall("findSUASP"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sua_Sp_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSUASP", {'Sua_Sp_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SUA SP");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SUA SP");
    }

    # SCTP IP ADDRESS
    if ($self->execFuncCall("findSctpIpAddress"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sctp_Ip_Address_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSctpIpAddress", {'Sctp_Ip_Address_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SCTP IP ADDRESS");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SCTP IP ADDRESS");
    }

    # SUA Network Appearance
    if ($self->execFuncCall("findSUANetworkAppearance"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sua_Network_Appearance_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSUANetworkAppearance", {'Sua_Network_Appearance_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SUA Network Appearance");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SUA Network Appearance");
    }

    # SUA Protocol Profile
    if ($self->execFuncCall("findSUAProtocolProfile"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Sua_Protocol_Profile_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteSUAProtocolProfile", {'Sua_Protocol_Profile_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting SUA Protocol Profile");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error in finding SUA Protocol Profile");
    }

    # TCAP Protocol Profile
    if ($self->execFuncCall("findTCAPProtocolProfile"  )) {
        my $line;
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
            if ( $line =~ "Tcap_Protocol_Profile_Id") {            
                my @fields = split(': ', $line); 
                $logger->debug(__PACKAGE__.".$sub :  $fields[1]");
                unless($self->execFuncCall("deleteTCAPProtocolProfile", {'Tcap_Protocol_Profile_Id' => $fields[1]} )) {
                    $logger->debug(__PACKAGE__."  Error Deleting TCAP Protocol Profile");
                }            
            }
        }        
    }
    else {
        $logger->debug(__PACKAGE__."  Error finding TCAP Protocol Profile");
    }
                                        
    $logger->debug(__PACKAGE__ . ".$sub:  Finished Deleting PSX Sigtran data");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

1;
