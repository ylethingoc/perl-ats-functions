package SonusQA::SBX5000::DSBC_LOOKUP;

=head1 NAME

SonusQA::SBX5000::DSBC_LOOKUP

=head1 AUTHOR

sonus-ats-dev@sonusnet.com

=head1 REQUIRES

Perl5.8.7.

=head1 DESCRIPTION

   This module provides the hash which is used to lookup the SBX5000 commands.
   Refer the wiki "http://wiki.sonusnet.com/display/SBXPROJ/Classic+Distributed+SBC+FSD".

=head2 Variable

   %cmdList - The hash contains the keywords of commands for each personality of SBC.
   %cmd_list_nk_role - The hash contains the keywords of commands, which runs only in active or standby for N:K SBC.

=cut

our %cmd_list = 
(
S_SBC=>{
	'addressContext' => [
		'cacOffenderStatus',
		'diamNode',
		'dynamicBlackList',
		'enhancedDBL',
		'natDirectMediaGroup',
		'rtpServerTable',
		'sipActiveGroupRegStatus',
		'sipActiveGroupRegSummaryStatus',
		'sipActiveRegisterNameStatus',
		'sipDeletedRegStatus',
		'sipDeletedRegisterNameStatus',
		'sipRegCountStatistics',
		'sipSubCountStatistics',
		'sipSubscriptionStatus',
		'surrRegCountStatistics',
		'zone',
		'zoneCurrentStatistics',
		'zoneIntervalStatistics',
		'zoneStatus',
        'ipInterfaceGroupName', #TOOLS-71545
        'signaling', #TOOLS-71545
        'mediationServerSignalingStatus', #TOOLS-71545
		],
	'global' => [
		'cac',	
		'callDetailStatus',
		'callRouting',	
		'callTrace',	
		'callTraceStatus',	
		'carrier',	
		'country',	
		'globalTrunkGroupStatus',	
		'monitorEndpoint',	
		'monitorEndpointStatus',	
		'monitorTarget',	
		'monitorTargetStatus',	
		'npaNxx',	
		'ocsCallCountStatus',	
		'policyServer',	
		'qoeCallRouting',	
		'script',	
		'security',	
		'signaling',	
		'sipDomain',	
		'siprecStatus',	
		'subscriber',	
		'callCountStatus',
	        'callCountCurrentInterval',
        	'callCountInterval',
		'callSummaryStatus',
		'callMediaStatus'
		],
	'global servers' => [
		'e911',	
		'e911VpcDevice',	
		'enumDomainName',	
		'enumDomainNameLabel',	
		'enumService',	
		'lwresdProfile',
        'srsGroupProfile', #TOOLS-76252
        'srsGroupCluster', #TOOLS-76252
        'callRecordingCriteria', #TOOLS-76252
		],
	'oam' => [	
		'accounting',	
		],
	'profiles' =>[
		'callParameterFilterProfile',	
		'callRouting',	
		'digitParameterHandling',	
		'digitProfile',	
		'dtmfTrigger',	
		'featureControlProfile',	
		'ipSignalingPeerGroup',	
		'services',	
		'signaling',	
		'sipCacProfile',	
		],
	'profiles media' => [
		'codecEntry',	
		'codecListProfile',	
		'codecRoutingPriority',	
		'mediaQosKpiProfile',	
		'packetServiceProfile',
                'toneCodecEntry',#TOOLS-17753	
                'toneAsAnnouncementProfile',#TOOLS-12814	
		],	
	'profiles security' => [
		'cryptoSuiteProfile',	
		'dtlsProfile',	
		'ikeProtectionProfile',	
		'ipsecProtectionProfile',	
		'ocspProfile',	
		'tlsProfile',	
		],
	'system' => [
		'jsrcServer',	
                'dsbc',
		'policyServer',	
		'certificate',
		],
},
M_SBC=>{
	'oam alarms' => [
		'mediaSrtpErrAlarm',
		'mediaSrtpErrAlarmStatus'
		],
	'oam traps' => [
		'dspAdmin'
		],
	'system' => [
		'dspPad',
		'dspRes',
		'dspStatus',
		'media ',
		'mediaProfile',
                'dsbc',
		'loadBalancingService\s+privateIpInterfaceGroupName'    	
		],
    'addressContext .+ intercept ' => [
        'mediaIpInterfaceGroupName', # TOOLS-71545
        'media ', # TOOLS-71545
        'mediationServerMediaStatus', # TOOLS-71545
        'rtcpInterception', # TOOLS-71545
        ],
},
T_SBC=>{
	'system' => [
                'dsbc',
		'loadBalancingService\s+privateIpInterfaceGroupName'    	
		    ],
},
);

our %cmd_list_nk_role = 
(
ACTIVE=>[
        'callMediaStatus',
        'callCountStatus',
        'callCountReset',#TOOLS-71214 
	'callCountCurrentInterval',
	'callCountInterval',
        'callSummaryStatus',
        'callResourceDetailStatus',
        'callDetailStatus',
        'callTraceStatus',
        'nodeStatus', 
        'cacNonRegEndPointRemoveEntry', #TOOLS-14828
        'licenseInfo',            #TOOLS - 14023
	'networkProcessorStatistics', #TOOLS-71201
	'request sbx dns debug command clearCache',#TOOLS-71317
	'show status addressContext default enhancedDBL trackingEntryStatus',#TOOLS-72087
],
STANDBY=>[
        'show table system standbySyncStatus'
        ]
);
1;
