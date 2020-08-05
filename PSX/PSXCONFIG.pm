
package SonusQA::PSX::PSXCONFIG;
use SonusQA::PSX;
use SonusQA::SessUnixBase;
use SonusQA::PSX::PSXHELPER;
use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;

use vars qw($self);

=pod

=head3 SonusQA::PSX::PSXCONFIG::Sigtran()

	sigtran Subroutine is to COnfigure PSX Sigtran Configuration

=over

=item Arguments

	$SUA_PP,$SUA_NA,$NET_APP,$psxn$SUA_PP,$SUA_NA,$NET_APP,$psxname,$psx_ip,$sgxname,$sgx_ip,$SUA_PORT_SGX,$SUA_PORT_PSX,$SCTP_ASSC,$SUASP_LABEL,$PC1,$localssn,$TCAP_REG,$TCAP_REG1,$SCPID,$scpssn,$DEFAULT_TCAP_PP

	All Scalar values

=item Returns

	Nothing

=item Example(s):
 
	$emsCliObj->SonusQA::PSX::PSXCONFIG::Sigtran($SUA_PP,$SUA_NA,$NET_APP,$psxname,$psx_ip,$sgxname,$sgx_ip,$SUA_PORT_SGX,$SUA_PORT_PSX,$SCTP_ASSC,$SUASP_LABEL,$PC1,$localssn,$TCAP_REG,$TCAP_REG1,$SCPID,$scpssn)

=back

=cut

sub Sigtran{

	my($self,$SUA_PP,$SUA_NA,$NET_APP,$psxname,$psx_ip,$sgxname,$sgx_ip,$SUA_PORT_SGX,$SUA_PORT_PSX,$SCTP_ASSC,$SUASP_LABEL,$PC1,$localssn,$TCAP_REG,$TCAP_REG1,$SCPID,$scpssn,$DEFAULT_TCAP_PP)=@_;
	my $sub_name = "Sigtran";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	my $hostname = $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME};

#SUA_PP is thr protocol profile Name for PSX (SIGTRAN Configuration)


	$self->execFuncCall("createSUAProtocolProfile",{
			'sua_protocol_profile_id' => $SUA_PP,
			'sua_max_local_sp' => '100',
			'sua_max_sccp_conn' => '50',
			'sua_switchover_count' => '20',
			'sua_max_peer_sp' => '100',
			'sua_max_pc_node' => '50',
			'sua_max_ip_node' => '50',
			'sua_max_ss_node' => '50',
			'sua_max_msg_retrans' => '20',
			'sua_max_as' => '50',
			'sua_max_sg' => '50',
			'sua_msg_retran_time_high'=>  '5',
			'sua_max_co_buff'=> '50',
			'sua_daud_timer'=>   '5000',
			'sua_max_local_as' => '50',
			'sua_max_conn'     => '100',
			'sua_cong_timer'   => '3000',
			'sua_max_tid_node' => '50',
			'sua_msg_retran_time_low' => '2',
			'sua_max_nw_appr'  => '50',
			'Sua_Daud_Timer'   => '5000',
			'Sua_Cong_Timer'   => '3000',


	});

	$self->execFuncCall("createSUANetworkAppearance",{

			'Sua_Network_Appearance_Id'=> $SUA_NA,
			'Network_Appearance'       => $NET_APP,
			'Network_Standard'         => '2',
			'Network_Identity'         => '2',
			'Sua_Protocol_Profile_Id'  => $SUA_PP,


			});

	$self->execFuncCall("createSctpIpAddress",{

			'Sctp_Ip_Address_Id'     => $psxname,
			'Ip_Address_1'           => $psx_ip,
			'Ip_Address_2'           => '0.0.0.0',
			'Ip_Address_3'           => '0.0.0.0',
			'Ip_Address_4'           => '0.0.0.0',
			'IpV6_Address_1'         => '""',
			'IpV6_Address_2'         => '""',
			'IpV6_Address_3'         => '""',
			'IpV6_Address_4'         => '""',
			'SCTP_Host_Ip_Attributes'=> '0',
			});
	$self->execFuncCall("createSctpIpAddress",{

			'Sctp_Ip_Address_Id'     => $sgxname,
			'Ip_Address_1'           => $sgx_ip,
			'Ip_Address_2'           => '0.0.0.0',
			'Ip_Address_3'           => '0.0.0.0',
			'Ip_Address_4'           => '0.0.0.0',
			'IpV6_Address_1'         => '""',
			'IpV6_Address_2'         => '""',
			'IpV6_Address_3'         => '""',
			'IpV6_Address_4'         => '""',
			'SCTP_Host_Ip_Attributes'=> '0',
			});
	$self->execFuncCall("createSUASP",{

			'Sua_Sp_Id'              => '0',
			'Description'            => $sgxname,
			'Sp_Type'                => '1',
			'Sctp_Ip_Address_Id'     => $sgxname,
			'Port_Number'            => $SUA_PORT_SGX,
			'Sp_Role'                => '1',
			'Tid_Label'              => '64',
			'Sua_Protocol_Profile_Id'=> $SUA_PP,
			});
	$self->execFuncCall("createSUASP",{



			'Sua_Sp_Id'              => '1',
			'Description'            => $psxname,
			'Sp_Type'                => '0',
			'Sctp_Ip_Address_Id'     => $psxname,
			'Port_Number'            => $SUA_PORT_PSX,
			'Sp_Role'                => '0',
			'Tid_Label'              => '30',
			'Sua_Protocol_Profile_Id'=> $SUA_PP,
			});

	$self->execFuncCall("createSCTPAssociation",{

			'Sctp_Association_Id' => $SCTP_ASSC,
			'Source_Sua_Sp_Id'    => '1',
			'Destination_Sua_Sp_Id'=> '0',
			'Max_In_Streams'       => '17',
			'Max_Out_Streams'      => '17',
			'Attributes'           => '1',

			});

	$self->execFuncCall("createSUASPLabel",{

			'Sua_Sp_Label_Id'=> $sgxname,
			'Sua_Sp_Id'      => '0'
			});

	$self->execFuncCall("createSUASPLabelData",{

			'Sua_Sp_Label_Id'=> $sgxname,
			'Sua_Sp_Id'      => '0'
			});
	$self->execFuncCall("createSUASPLabel",{

			'Sua_Sp_Label_Id'=> $SUASP_LABEL,
			'Sua_Sp_Id'      => '1'
			});

	$self->execFuncCall("createSUASPLabelData",{

			'Sua_Sp_Label_Id'=> $SUASP_LABEL,
			'Sua_Sp_Id'      => '1'
			});
	$self->execFuncCall("createSigtranLocalAS",{

			'Sigtran_Local_As_Id'      => '0',
			'Description'              => $SUASP_LABEL,
			'As_Mode'                  => '2',
			'Sua_Sp_Label_Id'          => $SUASP_LABEL,
			'Point_Code'               => $PC1,
			'Sub_System_Number'        => $localssn,
			'Sua_Network_Appearance_Id'=> $SUA_NA,
			'Sua_Protocol_Profile_Id'  => $SUA_PP,
			});
	$self->execFuncCall("createSigtranTCAPRegistration",{

			'Sigtran_Tcap_Registration_Id' => $TCAP_REG,
			'Sigtran_Tcap_Protocol_Variant'=> '1',
			'Tcap_Logical_User_Id'         => '2',
			'Sigtran_Local_As_Id'          => '0',
			'Tcap_Min_Dialog_Id'           => '1',
			'Tcap_Max_Dialog_Id'           => '10',
			'Sigtran_Application_Protocols'=> '24',

			});

	$self->execFuncCall("createSigtranTCAPRegistration",{

			'Sigtran_Tcap_Registration_Id' => $TCAP_REG1,
			'Sigtran_Tcap_Protocol_Variant'=> '2',
			'Tcap_Logical_User_Id'         => '1',
			'Sigtran_Local_As_Id'          => '0',
			'Tcap_Min_Dialog_Id'           => '1',
			'Tcap_Max_Dialog_Id'           => '2',
			'Sigtran_Application_Protocols'=> '3',

			});


	$self->execFuncCall("createSigtranSG",{
			'Sigtran_Sg_Id'          => '0',
			'Description'            => $sgxname,
			'Sg_Mode'                => '2',
			'Sua_Sp_Label_Id'        => $sgxname,
			'Sua_Protocol_Profile_Id'=> $SUA_PP,
			'Sg_Priority'            => 1,

			});
	$self->execFuncCall("createSigtranSG",{
			'Sigtran_Sg_Id'          => '1',
			'Description'            => $SUASP_LABEL,
			'Sg_Mode'                => '2',
			'Sua_Sp_Label_Id'        => $SUASP_LABEL,
			'Sua_Protocol_Profile_Id'=> $SUA_PP,
			'Sg_Priority'            => 1,

			});




	return 1;
}

=pod

=head3 SonusQA::PSX::PSXCONFIG::ProcessEnable()

	Below function is used to enable PSX Process.

=over 

=item Arguments

    Optional: 
        enume => 1, it enables enume if its passed. Bu default it enables slwresd

=item Returns

	NOTHING

=item Example(s):

    $obj->SonusQA::PSX::PSXCONFIG::ProcessEnable(); # it enables slwresd
    $obj->SonusQA::PSX::PSXCONFIG::ProcessEnable(enume => 1); # it enables enume

=back

=cut

sub ProcessEnable {
	my($self, %args)=@_;

    my $sub = 'ProcessEnable';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $process_order = ($self->{CLOUD_PSX})? '19' : '17' ; #TOOLS-74821
    my @sqls = (
        "DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'pes' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '0' AND PROCESS_ORDER = '3';",
        "DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'scpa' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '1' AND PROCESS_ORDER = '2';",
        "DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'sipe' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '2' AND PROCESS_ORDER = '6';",
        "DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'slwresd' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '9' AND PROCESS_ORDER = '15';",
        "DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'enume' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '12' AND PROCESS_ORDER = '14';",
	"DELETE FROM SS_PROCESS WHERE PROCESS_MANAGER_ID = 'DEFAULT' AND PROGRAM_NAME = 'httpc' AND PROCESS_TYPE = '0' AND PROCESS_SUBTYPE = '17' AND PROCESS_ORDER = '$process_order';",
    "DELETE FROM SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = 'HTTPC_DEFAULT_CFG';", #TOOLS-78636

	"INSERT INTO SS_PROCESS VALUES ('DEFAULT','httpc',0,17,$process_order,'HTTPC Client',1,'HTTPC_DEFAULT_CFG','','httpc.log',4,'-C 1 -F 1 -S 1',1000,2000000000,'',15);",
        "INSERT INTO SS_PROCESS VALUES ('DEFAULT','pes',0,0,3,'Policy Execution Server',1,'PES_DEFAULT_CFG','','pes.log',4,'-a',1000,2000000000,'',31);",
        "INSERT INTO SS_PROCESS VALUES ('DEFAULT','scpa',0,1,2,'SCP Adapter',1,'SCPA_DEFAULT_CFG','','scpa.log',4,'',1000,2000000000,'',15);",
        "INSERT INTO SS_PROCESS VALUES ('DEFAULT','sipe',0,2,6,'SIP Engine',1,'SIPE_DEFAULT_CFG','','sipe.log',4,'',1000,2000000000,'',15);",
    );

    if($args{enume}){
        push @sqls, (
            "INSERT INTO SS_PROCESS VALUES ( 'DEFAULT','slwresd',0,9,15,'DNS-ENUM Resolver',0,'SLWRESD_DEFAULT_CFG','','slwresd.log','4','-c slwresd.conf',1000,2000000000,'',0);", #disable slwresd
            "INSERT INTO SS_PROCESS VALUES ( 'DEFAULT','enume',0,12,14,'ENUM Engine',1,'','','','-1','-c enume.conf -f',1000,2000000000,'',0);" #enable enume
        );
        $logger->debug(__PACKAGE__ . ".$sub Enabling 'enume'");
    }
    else{
        push @sqls, (
            "INSERT INTO SS_PROCESS VALUES ( 'DEFAULT','enume',0,12,14,'ENUM Engine',0,'','','','-1','-c enume.conf -f',1000,2000000000,'',0);", # disable enume
            "INSERT INTO SS_PROCESS VALUES ( 'DEFAULT','slwresd',0,9,15,'DNS-ENUM Resolver',1,'SLWRESD_DEFAULT_CFG','','slwresd.log','4','-c slwresd.conf',1000,2000000000,'',0);", #enable slwresd
        );
        $logger->debug(__PACKAGE__ . ".$sub Enabling 'slwresd'");
    }

    push @sqls, (
        "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('PES_DEFAULT_CFG',3,0,1,'PES_SCPA_DEVICE');",
        "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('PES_DEFAULT_CFG',3,0,1,'SIPE_PES_DEVICE');",
        "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',3,0,1,'PES_SCPA_DEVICE');",
        "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',3,0,1,'SIPE_PES_DEVICE');",
	"INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('PES_DEFAULT_CFG',3,0,1,'PES_HTTP_DEVICE');"
	
    );

    foreach (@sqls){
        $self->sqlplusCommand($_);
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
}

=pod

=head3 SonusQA::PSX::PSXCONFIG::SqlScpa()

	Adding Subtypes for PSX Process

=over

=item Arguments

	$TCAP_REG1,$SUA_PP,$SCTP_ASSC,$DEFAULT_TCAP_PP
	<All Scalar Values>

=item Returns

	NOTHING

=back

=cut

sub SqlScpa {


	my($self,$TCAP_REG1,$SUA_PP,$SCTP_ASSC,$DEFAULT_TCAP_PP)=@_;
	my $sub_name = "SqlScpa";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

	my $sql1 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,217,1,'$TCAP_REG1');";
	my $sql2 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,215,1,'$SUA_PP');";
	my $sql3 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,218,1,'$SCTP_ASSC');";
	my $sql4 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,222,1,0);";
	my $sql5 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,216,1,'$DEFAULT_TCAP_PP');";
	my $sql6 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,221,1,1);";
	my $sql7 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,219,1,1);";
	my $sql8 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',0,205,1,60);";
	my $sql9 = "INSERT INTO SS_PROCESS_CONFIG_PARAMS VALUES ('SCPA_DEFAULT_CFG',4,220,1,1);";

	$self->{CMDERRORFLAG} = 0;
	$self->sqlplusCommand($sql1);
	$self->sqlplusCommand($sql2);
	$self->sqlplusCommand($sql3);
	$self->sqlplusCommand($sql4);
	$self->sqlplusCommand($sql5);
	$self->sqlplusCommand($sql6);
	$self->sqlplusCommand($sql7);
	$self->sqlplusCommand($sql8);
	$self->sqlplusCommand($sql9);



	$self->{CMDERRORFLAG} = 0;

}




1; # Do not remove
