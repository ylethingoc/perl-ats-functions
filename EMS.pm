package SonusQA::EMS;

=pod

=head1 NAME

 SonusQA::EMS - Perl module for Sonus Networks EMS interaction

=head1 SYSOPSIS

 use ATS; # This is the base class for Automated Testing Structure

 my $obj = SonusQA::EMS->new(
                             #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<user name >',
                              -OBJ_PASSWORD => '<user password>',
                              -OBJ_COMMTYPE => "<TELNET >",
                             );
 PARAMETER DESCRIPTIONS:
    OBJ_HOST
      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_USER
      The user name or ID that is used to 'login' to the device.
    OBJ_PASSWORD
      The user password that is used to 'login' to the device.
    OBJ_COMMTYPE
      The session or connection type that will be established.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=cut

use SonusQA::Utils qw(:all);
require SonusQA::EMS::EMSHELPER;
use Expect;
use Tie::IxHash;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;
our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::EMS::EMSHELPER);

my (%smsEntries,%smsEntriesNew,$csv);
my $oldSmsHash = tie (%smsEntries,Tie::IxHash);
my $newSmsHash = tie (%smsEntriesNew,Tie::IxHash);

%smsEntries = (    action=>'',
                PIPE1 => '|',
                subscribersubKey=>'',
                subscribersalutation=>'',
                subscriberfirst=>'',
                subscribermiddle=>'',
                subscriberlast => '',
                subscribersuffix=>'',
                subscriberpincode=>'',
                subscriberadminState=>'',
                subscriberadminCode=>'',
                subscriberadminReason=>'',
    	            notes => '',
        	        PIPE2 => '|', 
                subContactsaluation => '',
                subContactfirst => '',
                subContactmiddle => '',
                subContactlast => '',
                subContactsuffix => '',
                subContactcompany => '',
                subContactaddr1 => '',
                subContactaddr2 => '',
                subContactaddr3 => '',
                subContactcity => '',
                subContactstate => '',
                subContactpostal => '',
                subContactcountry => '',
                subContactphoneNbr => '',
                subContactemailAddr => '',
           		    PIPE3 => '|', 
                subscriberBillingrating => '', 
                subscriberBillingbillingid => '', 
                subscriberBillingbillingid2 => '', 
                subscriberBillingbillingCountry => '', 
                subscriberBillingbillingTimeZone => '', 
                subscriberBillingbillingTimeZoneId => '', 
	                PIPE4 => '|', 
                devicedevKey => '',
                devicedevName => '',
                deviceasxName => '',
                devicedevType => '',
                deviceprotocolType => '',
                devicehardwareType => '',
                devicenbrPorts => '',
                deviceaddress => '',
                deviceudpPort => '',
		devicecontactAddrType => '',
    	    	devicecontactAddr   => '',
	  	devicecontactAddrPort => '',
        	deviceinactivityTimeout => '',
		deviceh248EncodingType => '',
		deviceppAudit => '',
		deviceacAudit => '',
		deviceacAuditFreq => '',	
		devicemaintState => '',	
		devicemaintCode => '',
		devicemaintReason => '',	
		deviceservingRouterId => '',	
		devicesecurity => '',
		deviceccIdReasons => '',
		deviceccwTone	=> '',
		deviceexpJcPackage => '',
		devicenotes => '',
		devicemgcType=>'',
		deviceh248LineSignalingPackage => '',
		deviceh248CollectCallStats => '',
		deviceh248OverloadRateWeight => '',
		devicesipTransportParameter=> '',	
		devicegr303=>'',
		deviceendpointLocalNameTemplate=>'',
        	        PIPE5 => '|', 
                deviceLocationaddr1 => '',	
                deviceLocationaddr2 => '',	
		deviceLocationaddr3 => '',
		deviceLocationcity  => '',	
		deviceLocationstate => '',
		deviceLocationpostal => '',
		deviceLocationcountry => '',	
 			START_PIPE => '|',
	                COMA => '',
    	            PIPE6 => '|',
                DNepType => '',
                DNbgid  => '',
                DNcc  => '',
                DNnumber => '',	
                DNsubKey => '',
                DNdevKey => '',
                DNdevPort => '',	
                DNdnGrade  => '',	
                DNasxName => '',	
                DNblid => '',
                DNintraLataCarrier => '',	
                DNlocalCarrier	 => '',
                DNinternationalCarrier => '',
                DNinterLataCarrier => '',
                DNoerp	 => '',
                DNprimaryDnFlag => '',
                DNolipDigits => '',
                DNserviceGroupId => '',
                DNprivateCallerIdDn => '',
                DNcallerIdName => '',
                DNClassOfService => '',	
                DNringingCadence => '',
                DNadminState => '',	
                DNadminCode => '',
                DNadminReason => '',	
                DNnotes => '',	
                DNtimeZone => '',
                DNtimeZoneId => '',
                DNsipRealmId => '',
                DNsipUser => '',	
                DNsipPass => '',
                DNsipContactUri => '',
                DNsipContactPath => '',
                DNrtpRtcp => '',	
                DNcallCtrlParams => '',
                DNfeatureNameToScript => '',
                DNsipSvcParams => '',	
                DNvoiceCodecParams => '',
                DNcallCrankbackParams => '',
                DNprefPktSvcProfile => '',
                DNcalledForcedRouting => '',
                DNforcedOnNetDN => '',	
                DNforcedOnNetCC => '',
                DNsrLabel => '',	
                DNsrPartition => '',
                DNprLabel => '',
                DNprPartition => '',
                DNdevProfile => '',
                DNcongestionControlParameters => '',
                DNfeatureToCauseCodeMapping => '',
                DNcallingNumberSource => 'None',	
                DNpublicCallerIdDn => '',
                DNcallPickupGroup => '',
                DNpuiSupport => '',	
                DNpuiList	 => '',
                DNcallingPartyCategory=> 'None',
                DNdnType => '',	
                DNgroupRegistrationType => '',	
                DNgroupMain => '',	
                DNpreferredServingASX => '',
                DNddiSupportType => 'None',	
                DNddiNumberRangeList => '',
                        PIPE7 => '|',
                cfv  => 'i',
                cfvDestType=> '',
                cfvDest=> '',
                cfvRingr=> '',
                cfbl=> 'i',
                cfblDestType=> '',
                cfblDest=> '',
                cfda=> 'i',
                cfdaDestType=> '',
                cfdaDest=> '',
                cfdaTimeout=> '',
                cw=> 'i',
                cwToneType=> '',
                cwIntv=> '',
                cwca=> '',
                cwDATimeout=> '',
                cwUASC=> '',
                ch=> 'i',
                chTimeout=> '',
                ct=> 'i',
                ctES=> '',     # New Field included Based on the Patch for CQ SONUS00100066 
                ctRest=> '',
                cid=> 'i',
                cidLocPrefixRemoval=> '',
                cidcw=> 'i',
                cidcp=> 'i',
                cidcpSettings=> '',
                twc=> 'i',
                acr=> 'i',
                mwi=> 'i',
                mwiFlags=> '',
                mwiServer=> '',
                cidwn=> 'i',
                cidwncw=> 'i',
                rcf=> 'i',
                rcfDest=> '',
                scf=> 'i',
                scfMax=> '',
                scfList=>'',     # New Field included Based on the Patch for CQ SONUS00100066 
                hgc=> '',
                hgcVSC=> '',
                hgcHg=> '',
                hgmb=> 'i',
                hgmmb=> 'i',
                fmc=> 'i',
                gcf=> 'i',
                gcfMaxHop=> '5',
                gcfScript=> '',
                gcfDAScript=> '',
                gcfBLScript=> '',
                gcfCdsl=> '',
                gcfCidWithRR=> '',
                gcfACFR=> '',
                gcfVol=> '',
                gmc=> 'i',
                gmcUseMgcp=> '',
                gmcUseSip=> '',
                gmcCdsl=> '',
                gmcUASC=> '',
                gmcSOCTAM=> '',
                gmcDeluxFP=> '',
                sce=> 'i',
                scePe=> '',
                cct=> 'i',
                cctIntraASX=> '',
                cctInterASX=> '',
                cctASXToGSX=> '',
                cctASXToAppServer=> '',
                nwc=> 'i',
                nwcSize=> '',
                nwcPersistOpt=> '',
                sp1=> 'i',
                sp1Size=> '',
                sp1DL=>'',      # New Field included Based on the Patch for CQ SONUS00100066 
                sp2=> 'i',
                sp2Size=> '',
                sp2DL=>'',     # New Field included Based on the Patch for CQ SONUS00100066 
                dr=> 'i',
                drScreeningList=>'',     # New Field included Based on the Patch for CQ SONUS00100066 
                dnd=> 'i',
		dndExp=> '',
		dndOverride=> '',
		dndPIN=> '',
		dndRing=> '',
		dndDest=> '',
		dndAnnPat=> '',
		fmfm=> 'i',
		fmfmTreatment=> '',
		fmfmSearch=> '',
		fmfmDest=> '',
		fmfmTimeout=> '',
		fmfmAnsSup=> '',
                fmfmLocationList=>'',     # New Field included Based on the Patch for CQ SONUS00100066 
		fmfmIndicator=> '',
		fmfmLocation=> '',
		fmfmLabel=> '',
		ctd=> 'i',
		ctdIntratoInter=> '',
		ctdIntratoIntra=> '',
                ctdPrefixList=> '',     # New Field included Based on the Patch for CQ SONUS00100066 
		ac=> 'i',
		acCdsl=> '',
		ar=> 'i',
		arCdsl=> '',
		arNum=> '',
		arNumInCalls=> '',
		arPrompt=> '',
		arDate=> '',
		arGroup=> '',
		bb=> 'i',
		bbRing=> '',
		bbCdsl=> '',
		sca=> 'i',
		scaMax=> '',
                scaSCSL=>'',    # New Field included Based on the Patch for CQ SONUS00100066 
		scaPin=> '',
		scaDest=> '',
		scaRedir=> '',
		scr=> 'i',
		scrMax=> '',
                scrSCSL=>'',   # New Field included Based on the Patch for CQ SONUS00100066
		scrRedir=> '',
		moh=> 'i',
		mohMusic=> '',
		ims=> 'i',
		oms=> 'i',
		vmsi=> '',
		vmsiDest=> '',
		ccf=> 'i',
		ccfDATO=> '',
		ccfRR=> '',
		ccfATC=> '',
		ccfATFP=> '',
		ccfFWU=> '',
		ccfSCHO=> '',
		ccfActive=> '',
		ccfRegNumbers=> '',
		ccfMaxSCSL=> '',
		ccfSCSL=> '',
		rfc=> '',
		rfcACS=> '',
		mcid=> 'i',
		mcidAWC=> '',
		mcidTAC=> '',
		rbwf=> 'i',
		rbwfUP=> '',
		rbwfRing=> '',
		rbwfCDSL=> '',
		rbwfMaxReqs=> '',
		rbwfq=> 'i',
		rbwfqMaxReqs=> '',
		ocr=> 'i',
		ocrPIN=> '',
		ocrType=> '',
		ocrNGIL=> '',
		msc=> 'i',
		mscpKey=> '',
		cfu=> 'i',
		cfuDestType=> '',
		cfuDestination=> '',
		cfuDontAnswerTimeout=> '',
		cfuForwardAllIncompleteCalls=> '',
		cfuAnnouncementToCaller=> '',
		cfuAnnouncementToForwardParty=> '',
		dcp=> 'i',
		bgfc=> 'i',
		bgfcDirectedCallPickup=> '',
		bgfcPickupWaitingCalls=> '',
		bgfcCallOffer=> '',
		bgcfCOOCCW=> '',
		bgfcCallPickup=> '',
		bgfcCOASC=> '',
		bgfcCOCWT=> '',
		bgfcCOII=> '',
		bgfcCODAT=> '',
		bgfcMaxParkedCalls=> '',
		bgfcCallParkOrbit=> '',
		bgfcAllowSIPDialogEvents=> '',
		presentationNumber=> 'i',
		presentationNumberSource=> '',
		presentationNumberPrivacy=> '',
		alarmCall=> 'i',
		alarmCallCallWaiting=> '',
		alarmCallMaxAlarms=> '',
                alarmCallList=> '',   # New Field included Based on the Patch for CQ SONUS00100066
		co=> 'i',
		coAutoEnable=> '',
		cp=> 'i',
		pnh=> 'i',
		pnhPresentation=> '',
		pnhAlg=> '',
		pnhList=> '',
		hl=> 'i',
		hlDestType=> '',
		hlDest=>'',
		wl=> 'i',
		wlDestType=> '',
		wlDest=> '',
		wlFirstDigitTimeout=> '',
		wlMinDigitsToRoute=> '',
	 		COMMA => '',
			PIPEE =>'|',

);
	%smsEntriesNew = %smsEntries;


# INITIALIZATION ROUTINES FOR CLI^M
# -------------------------------^M
# ROUTINE: doInitialization^M
# Routine to set object defaults and session prompt

=head1 B<sub doInitialization()>

=over 6

=item DESCRIPTION:

 Object session specific initialization.  Object session initialization function that is called automatically, use to set Object
 specific flags, paths, and prompts.

=item PACKAGE:

 SonusQA::EMS

=item ARGUMENTS:

 NONE

=item RETURN:

 NONE

=back

=cut


sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);

  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$\%\#\}\|\>\]] $/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  $self->{DEFAULTTIMEOUT} = 180;
  $self->{LOCATION} = locate __PACKAGE__;
  $self->{BASEPATH} = '';
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  $logger->debug(__PACKAGE__ . ".doInitialization Initialization Complete");
}

=head1 B<sub setSystem()>

=over 6

=item DESCRIPTION:

 This routine is responsible to completeing the connection to the object. It performs some basic operations to enable a more efficient automation environment.

 Some of the items or actions it is performing:
    Sets Unix SHELL to 'bash'
    Sets PROMPT to AUTOMATION#

=item PACKAGE:

 SonusQA::EMS

=item ARGUMENTS:

 NONE

=item RETURN:

 NONE

=back

=cut


sub setSystem {
  my($self,%args)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results,$emstarget,$smsExe);
#TOOLS-17812 - STARTS
  @results = $self->execCmd('ls -l /opt/sonus/metadata.json');
  $self->{CLOUD_EMS} = 1 unless (grep /No such file or directory/, @results); 	
  @results = $self->{conn}->cmd('rpm -q SONSems');
  $results[0] =~ /(V[\d\.]+)\-(\w\d+)/g;
  $self->{VERSION} = $1;
  $self->{VERSION} =~ s/-//g;
  $self->{SU_CMD} = 'sudo -i -u ' if ( $self->{CLOUD_EMS}  and SonusQA::Utils::greaterThanVersion( $self->{VERSION},'V11.01.00' )); #TOOLS-18508
  $self->{sonusEms} = (SonusQA::Utils::greaterThanVersion( $self->{VERSION},'V13.00.00' )) ? 'emsMgmt' : 'sonusEms'; #TOOLS-76255

  if( $self->{OBJ_USER} eq 'admin'){ #TOOLS-18810
      unless($self->becomeUser(-password => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} ,-userName => $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID})){
          $logger->error(__PACKAGE__ . ".setSystem: unable to enter as $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}");
          return 0;
      }

      $self->{OBJ_USER} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} if($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID});#TOOLS-18820
      $self->{OBJ_PASSWORD} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} if($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD});
  }
#TOOLS-17812 - ENDS

  $logger->debug(__PACKAGE__ . ".setSystem  ENTERED EMSUSER SUCCESSFULLY");

  $emstarget = $args{-obj_scriptDir};
  $smsExe = $args{-obj_exeScript};

  if ($self->{SESSION_TIMEOUT}) {
      $self->{conn}->cmd("export TMOUT=$self->{SESSION_TIMEOUT}");
      $logger->debug(__PACKAGE__ . ".setSystem CHANGING THE TELNET TIMEOUT TO $self->{SESSION_TIMEOUT}");
  }
  if ($self->{OBJ_USER} =~ /root/ and $self->{OBJ_PASSWORD} =~ /l0ngP\@ss/){
     unless ($self->changePasswd($self->{OBJ_OLD_PASSWORD})){
         $logger->warn(__PACKAGE__ . ".setSystem Failed to change password from \'$self->{OBJ_PASSWORD}\' to \'$self->{OBJ_OLD_PASSWORD}\'");
	 $main::failure_msg .= "UNKNOWN:EMS - Failed to change password. ";
     }       
  }
  my @platform = $self->{conn}->cmd('uname');
  @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = @platform;
  chomp @platform;
  my @version = ();
  my $Ver = '';
  if ($platform[0] =~ /Linux/i) {
      $self->{PLATFORM} = 'linux';
      $logger->info(__PACKAGE__ . ".setSystem ******* this is a Linux platform*****");
      @version = $self->{conn}->cmd('rpm -q SONSems');
      chomp @version;
      $Ver =  $version[0];
      $Ver =~ s/(SONSems-|\s)//ig;
      # Fix for TOOLS-2635. We are getting DUT_VERSION as V09.02.00-R000.x86_64, which is not a valid format. So its failing to log result. 
      # Changing it to valid format
      $Ver=~s/(V[1-9][0-9]|[0-9][1-9]\.\d\d\.\d\d)-?([ARSFEB]\d\d\d).*/$1$2/; # V09.02.00R000
      $self->{BASEPATH} = '/opt/sonus/ems/';
  } else {
      $logger->info(__PACKAGE__ . ".setSystem ******* this is a SunOS platform*****");
      $cmdVer = 'pkginfo -l SONSems';					# Get the EMS version from the Server

      $self->{PLATFORM} = 'SunOS';
      @version = $self->{conn}->cmd($cmdVer);
      $self->{BASEPATH} = '/export/home/ems/';

      foreach (@version){
          if (/VERSION:[\s\t]?(.*)/){
              $Ver = $1;
              $Ver =~ s/\s+//g;
              last;
         }
      }
  }
  #Initialising the Metrcis
  $self->{THREADSPERCORE} = 0;
  $self->{CORESPERSOCKET} = 0;
  $self->{NUMOFSOCKETS} = 0;
  $self->{HYPERVISOR} = "BAREMETAL"; #By default we assume the hardware is BareMetal
  $self->{NUMOFCORES} = 0;
  $self->{CPUMODEL} = '';


  #Read lscpu&/proc/cpuinfo for threads,Socket,cores,Hypervisor & CPU model  details
  my @r = ();
  if ($self->{PLATFORM} eq 'linux' ) {
     unless ( @r =  $self->{conn}->cmd('lscpu') ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed for \"lscpu \", data maybe incomplete, result: " . Dumper(\@r));
     }

     chomp @r;
     foreach $line (@r) {
         $self->{THREADSPERCORE} = $1 if ($line =~ m/Thread\(s\)\s+per\s+core\s*:\s+(\d+)/i);
         $self->{CORESPERSOCKET} = $1 if ($line =~ m/Core\(s\)\s+per\s+socket\s*:\s+(\d+)/i);
         $self->{NUMOFSOCKETS} = $1 if ($line =~ m/Socket\(s\)\s*:\s+(\d+)/i);
         $self->{HYPERVISOR} = $1 if ($line =~ m/Hypervisor\s+vendor\s*:\s+([a-zA-Z]+)/i);
     }

     unless ( @r =  $self->{conn}->cmd('cat /proc/cpuinfo') ) {
         $logger->error(__PACKAGE__ . "$sub Remote command \"cat /proc/cpuinfo \" execution failed, data maybe incomplete, result: " . Dumper(\@r));
     }

     chomp @r;
     foreach $line (@r) {
         $self->{NUMOFCORES} = $1 if ($line =~ m/processor\s+:\s+(\d+)/i);
         $self->{CPUMODEL} = $1 if ($line =~ m/model\s+name\s*:\s+.*\s+CPU\s+([a-zA-Z0-9\-_\s]+)/i);
         $self->{CPUMODEL} =  $1 if ( ( $line =~ m/model\s+name\s*:\s+.*[CPU]*\s+([a-zA-Z0-9]+[\-_\s]*)\s.+/i)  && ( $self->{HYPERVISOR} eq 'KVM'));
     }
     $self->{NUMOFCORES}++; # /proc/cpuinfo is zero-based.
   } else {
        unless ( @r =  $self->{conn}->cmd('uname -i') ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed for \"uname -i \", data maybe incomplete, result: " . Dumper(\@r));
     }
      chomp @r;
      $self->{CPUMODEL} = $1 if ($r[0] =~ m/.*,(.*)/i);
  }

  # No specific bulk loader for 8.4 and 8.5, so using the same 8.3 bulkloader 
  if ($Ver =~ /(.*\.)0[45](\..*)/i) {
     $Ver = "$1" . "03" . "$2";
  }

  if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
     $main::TESTSUITE->{DUT_VERSIONS}->{"EMS,$self->{TMS_ALIAS_NAME}"} = $Ver unless ($main::TESTSUITE->{DUT_VERSIONS}->{"EMS,$self->{TMS_ALIAS_NAME}"});
  }

  $majVer = substr $Ver,0,6;
  $minVer = substr $Ver,0,9;

  $logger->debug(__PACKAGE__ . ".setSystem  EMS MAJOR VERSION IS: $majVer");
  $logger->debug(__PACKAGE__ . ".setSystem  EMS MINOR VERSION IS: $minVer");

  unless($self->{DO_NOT_TOUCH_SSHD}){ #TOOLS-18508
      unless ( $self->setClientAliveInterval() ) {
          $logger->error( __PACKAGE__ . " : Could not set ClientAliveinterval to 0." );
          $logger->info( __PACKAGE__ . ".setSystem: <-- Leaving sub [0]" );
          return 0;
      }
  }else{
      $logger->debug(__PACKAGE__ . ".setSystem  do_not_touch_sshd flag is set ");
  }

  $self->{VERSION} = substr $Ver,0,14;
  $self->{VERSION} =~ s/-//g;
  
  $self->{conn}->cmd("TMOUT=72000");

  $self->checkSmsBulkLoader($emstarget,$smsExe) if ($emstarget and $smsExe);
  #TOOLS-15398
  $self->execCmd('hostname');
  $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME} = $self->{CMDRESULTS}->[0];
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}

=pod

=head1 B<sub checkSmsBulkLoader()>

=over 6

=item DESCRIPTION:

 This Subroutine is Invoked by setSystem to check if the BulkLoader Executable and supporting JAR files are available.
 If Not available as expected ATS shall perform the "make" action to create the bulkLoader KIT.

=back

=cut

sub checkSmsBulkLoader {
    my ($self,$emstarget,$smsExe)=@_;
	my $sub_name = "checkSmsBulkLoader";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub_name .");
	
        my $minVerCust2 = $self->{OBJ_EXESCRIPT}; 
	if ( defined $minVerCust2 ){
		if( $minVerCust2 =~ /smsBulkLoader(.*)$/ ) {
			$minVerCust2 = $1;
			$logger->debug(__PACKAGE__ . ".$sub_name Fetched the Minor Version from TMS. Minor Version Before:  $minVerCust2");
			$minVerCust2 =~ s/^_//g;
		}else{
                        $logger->error(__PACKAGE__ . ".$sub_name The bulk loader script \'$minVerCust2\' in the tms testbed alias data {NODE}->{1}->{EXECUTIOM_SCRIPT} is expected to be in the following format : smsBulkLoader_build eg: smsBulkLoader_9_0, smsBulkLoader_7_3_7 ");
                        $logger->error(__PACKAGE__ . ".$sub_name Correct the attribute value for the above attribute and retry.");
                        return 0;
		}
	} else{
		$minVerCust2 = $minVer;
        	$logger->debug(__PACKAGE__ . ".$sub_name Minor Version Before:  $minVerCust2");
        	if ( $minVerCust2 =~ /V\d\d\.\d\d\.\d\d/ ) {
                	$minVerCust1 = $minVerCust2;
                	$minVerCust2 =~ s/V0//;
                	$minVerCust2 =~ s/\.0/_/g;
                	$minVerCust1 =~ s/V//;
                	$minVerCust1 =~ s/\./_/g;
        	} elsif ( $minVerCust2 =~ /V\d\d\.\d\d/ ) {
                	$minVerCust1 = $minVerCust2;
                	$minVerCust2 =~ s/V0//;
                	$minVerCust2 =~ s/\.0/_/g;
                	$minVerCust1 =~ s/V//;
                	$minVerCust1 =~ s/\./_/g;
        	} elsif ( $minVerCust2 =~ /^(V\d\d)$/) {
                	$minVerCust2 =~ s/V0//;
                	$minVerCust2 .= '_0';
        	}
	}

     $logger->debug(__PACKAGE__ . ".$sub_name Minor Version After:  $minVerCust2");
	
    $self->{conn}->cmd( "cd $emstarget" );
    my @pwd = $self->{conn}->cmd( "pwd" );
    my @listJars = $self->{conn}->cmd( "ls *.jar | head" );

	$file = 0;

	foreach ( @listJars ) {
		if ( $_ =~ "axis.jar" ) { $file++; } elsif ( $_ =~ "bulkLoader.jar" ) { $file++; } elsif ( $_ =~ "bulkLoaderSources_r$minVerCust1.jar" ) { $file++; } 
			elsif ( $_ =~ "commons-discovery.jar" ) { $file++; } elsif ( $_ =~ "commons-logging.jar" ) { $file++; } elsif ( $_ =~ "jaxrpc.jar" ) { $file++; } 
				elsif ( $_ =~ "saaj.jar" ) { $file++; } elsif ( $_ =~ "wsdl4j.jar" ) { $file++; } elsif ( $_ =~ "xercesImpl.jar" ) { $file++; }
					elsif ( $_ =~ "xml-apis.jar" ) { $file++; } ;
	}

	if ($file == "10") {
    	$logger->debug(__PACKAGE__ . ". $sub_name FOUND ALL Relevant JAR Files");
	} else {
    	$logger->warn(__PACKAGE__ . ". $sub_name NOT ALL Relevant JAR Files FOUND, Performing BULKLOADER Make...!");
    	$logger->warn(__PACKAGE__ . ". $sub_name SOME JAR FILE's are MISSING");
    	$logger->warn(__PACKAGE__ . ". $sub_name *********************************************");
		$self->{conn}->cmd("cd /export/home/ems/conf");
		my $smsMake = "makeSmsBulkLoaderKit$minVerCust2";

		@cmdOutput = $self->{conn}->cmd("./$smsMake");
    	$logger->warn(__PACKAGE__ . ". $sub_name . @cmdOutput :: $minVerCust2");
		
	}

}

=head1 B<sub execCmd()>

=over 6

=item DESCRIPTION:

 This routine is a wrapper for executing Unix commands.  It will attempt to submit and store the results from a command.  The results are stored in a buffer for
 access post execCmd call. This routine will attempt to return the Unix signal from the command execution using the simple check 'print $?', which will be executed
 immediately after the command.

 The results of the command can be obtained by directory accessing $obj->{CMDRESULTS} as an array.
 The syntax for doing this:  @{$obj->{CMDRESULTS}

=item PACKAGE:

 SonusQA::EMS

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item ARGUMENTS:

 -cmd <Scalar>
  A string of command parameters and values
 
 -timeout

=item RETURN:

 Boolean
 This will attempt to return the Unix CLI command signal. If the command to determine this signal fails - 0 is returned by default

=back

=cut

sub execCmd {
  my ($self,$cmd,$timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults, $errorFlag);
  $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub");
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $self->{CMDRESULTS} = [];
  $timeout ||= $self->{DEFAULTTIMEOUT};
  $self->{conn}->buffer_empty;

  my $retries = 0;
  RETRY:
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=> $timeout )) {
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    push(@{$self->{CMDRESULTS}},@cmdResults);
    $errorFlag = 1;
    $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
    $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
    $main::failure_msg .= "UNKNOWN:EMS - Execution of command failed ";

    #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
    $logger->debug(__PACKAGE__ . ".execCmd  Sending ctrl+c");
    unless($self->{conn}->cmd(-string => "\cC")){
        $logger->warn(__PACKAGE__ . ".execCmd  Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);
	$main::failure_msg .= "UNKNOWN:EMS - Prompt not received after ctrl+C ";

        #Reconnect in case ctrl+c fails.
        $logger->warn(__PACKAGE__ . ".execCmd  Trying to reconnect...");
        unless( $self->reconnect() ){
            $logger->warn(__PACKAGE__ . ".execCmd Failed to reconnect.");
	    $main::failure_msg .= "UNKNOWN:EMS - Reconnection failed ";
	    &error(__PACKAGE__ . ".execCmd CMD ERROR - EXITING");
        }
    }
    else {
        $logger->info(__PACKAGE__ .".exexCmd Sent ctrl+c successfully.");
    }
    if (!$retries && $self->{RETRYCMDFLAG}) {
	$errorFlag = 0;
        $retries = 1;
        goto RETRY;
    }
  };

  if($errorFlag){
  	if($self->{CMDERRORFLAG} || $ENV{CMDERRORFLAG}){
		$logger->warn(__PACKAGE__ . ".execCmd  CMDERRORFLAG IS ON - CALLING error()");
		$main::failure_msg .= "UNKNOWN:EMS - Command execution failed. ";
        	&error("CMD FAILURE: $cmd");
  	}
	else {
  		return 0;	
  	}
  }
	
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  # Remove the escape character that seems to populate each response...
  foreach(@cmdResults){
    $_ =~ s/\e//g;
  } 
  push(@{$self->{CMDRESULTS}},@cmdResults);
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  push(@{$self->{HISTORY}},$cmd);
  $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
  return @cmdResults;
}

=head1 B<sub setValues()>

=over 6

=item DESCRIPTION:
 
 This function is used to set values from the hash passed to the function into the file specified in $filename.

=item PACKAGE:

 SonusQA::EMS

=item GLOBAL VARIABLES USED:

 None

=item ARGUMENTS:

 1. $filename - File to which the values must be set
 2. %hashChanges - Hash containing the changes

=back
  
=cut

sub setValues {
  	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setValues");
        my ($filename,%hashChanges)=@_;
	my $sub_name = "setValues";

	system ("mkdir -p Temp");

	$csv = $filename;

        open MYFILE, ">> Temp/$filename" or die $!;

	# Reseting to the Original Hash Entries as Defined
	%smsEntries = %smsEntriesNew;

	# Original smsHash is defined on 8.0 BulkLoader, thus modifying the below fields based on the specific Release

	if ($majVer eq 'V08.01' || $majVer eq 'V08.02')
	{
		@hashIndex = $oldSmsHash->Indices('subscriberBillingbillingid2');
		$oldSmsHash->Splice($hashIndex[0]+1,0, subscriberBillingchargePlan => '');

		@hashIndex = $oldSmsHash->Indices('DNpreferredServingASX');
		$oldSmsHash->Splice($hashIndex[0]+1,0, DNalternateServingASX => '');
	} elsif ($minVer eq 'V07.03.05' || $minVer eq 'V07.03.06') {
		$oldSmsHash->Delete('DNsipContactUri','DNsipContactPath','DNpreferredServingASX','DNalternateServingASX','DNprLabel','DNprPartition','DNddiSupportType','DNddiNumberRangeList','ctES','sp1DL','sp2DL','scaSCSL','scrSCSL','scfList','drScreeningList','fmfmLocationList','ctdPrefixList','alarmCallList');
		@hashIndex = $oldSmsHash->Indices('DNsipPass');
		$oldSmsHash->Splice($hashIndex[0]+1,0, DNnumberOfSIPContacts => '');

		@hashIndex = $oldSmsHash->Indices('DNgroupMain');
		$oldSmsHash->Splice($hashIndex[0]+1,0, DNmaxTotalSimultaneousCalls => '');

		@hashIndex = $oldSmsHash->Indices('DNnumberOfSIPContacts');
		$oldSmsHash->Splice($hashIndex[0]+1,0, DNsipContactList => '');

		@hashIndex = $oldSmsHash->Indices('alarmCallMaxAlarms');
		$oldSmsHash->Splice($hashIndex[0]+1,0, alarmCallTrType => '');

		@hashIndex = $oldSmsHash->Indices('wlMinDigitsToRoute');
		$oldSmsHash->Splice($hashIndex[0]+1,0, callNt => '');

		@hashIndex = $oldSmsHash->Indices('callNt');
		$oldSmsHash->Splice($hashIndex[0]+1,0, callNtAddressList => '');

		@hashIndex = $oldSmsHash->Indices('callNtAddressList');
		$oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSLMax => '');

		@hashIndex = $oldSmsHash->Indices('callNtSCSLMax');
		$oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSL => '');

	} elsif ( $majVer eq 'V08.03' or $majVer eq 'V09.00') {
           #Modified as per SONUS00120953
           @hashIndex = $oldSmsHash->Indices('DNsipPass');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNnumberOfSIPContacts => '');

           @hashIndex = $oldSmsHash->Indices('DNgroupMain');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNmaxTotalSimultaneousCalls => '');

           if ($majVer eq 'V09.00') {
               $oldSmsHash->Delete('DNsipContactUri','DNsipContactPath');
           } elsif ($majVer eq 'V08.03') {
               $oldSmsHash->Delete('DNsipContactUri','DNsipContactPath','DNprLabel','DNprPartition');
           }

           @hashIndex = $oldSmsHash->Indices('DNnumberOfSIPContacts');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNsipContactList => '');

           @hashIndex = $oldSmsHash->Indices('alarmCallList');
           $oldSmsHash->Splice($hashIndex[0]+1,0, alarmCallTrType => '');

           @hashIndex = $oldSmsHash->Indices('wlMinDigitsToRoute');
           $oldSmsHash->Splice($hashIndex[0]+1,0, callNt => '');

	   @hashIndex = $oldSmsHash->Indices('callNt');
    	   $oldSmsHash->Splice($hashIndex[0]+1,0, callNtAddressList => '');

           @hashIndex = $oldSmsHash->Indices('callNtAddressList');
	   $oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSLMax => '');

    	   @hashIndex = $oldSmsHash->Indices('callNtSCSLMax');
           $oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSL => '');

           @hashIndex = $oldSmsHash->Indices('mohMusic');
           $oldSmsHash->Splice($hashIndex[0]+1,0, mr => '');

           @hashIndex = $oldSmsHash->Indices('mr');
           $oldSmsHash->Splice($hashIndex[0]+1,0, mrrbaDev => '', mrrhdFirst => '', mrhdrTimeout => '', mrmlaosDevice => '');

           @hashIndex = $oldSmsHash->Indices('cfvRingr');
           $oldSmsHash->Splice($hashIndex[0]+1,0, cfvocffwdtoDN => '');

           # including as part of the V8.1 changes

    	   @hashIndex = $oldSmsHash->Indices('subscriberBillingbillingid2');
           $oldSmsHash->Splice($hashIndex[0]+1,0, subscriberBillingchargePlan => '');

           @hashIndex = $oldSmsHash->Indices('DNpreferredServingASX');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNalternateServingASX => '');

           #8.3 Specific
           @hashIndex = $oldSmsHash->Indices('DNddiNumberRangeList');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNhuntGroup => '');

           @hashIndex = $oldSmsHash->Indices('DNhuntGroup');
           $oldSmsHash->Splice($hashIndex[0]+1,0, DNvirtualDNType => '');

        } elsif ( $minVer eq 'V07.03.07') {
        $oldSmsHash->Delete('DNsipContactUri','DNsipContactPath','DNpreferredServingASX','DNalternateServingASX','DNprLabel','DNprPartition','DNddiSupportType','DNddiNumberRangeList','ctES','sp1DL','sp2DL','scaSCSL','scrSCSL','scfList','drScreeningList','fmfmLocationList','ctdPrefixList','alarmCallList');
        @hashIndex = $oldSmsHash->Indices('DNsipPass');
        $oldSmsHash->Splice($hashIndex[0]+1,0, DNnumberOfSIPContacts => '');

        @hashIndex = $oldSmsHash->Indices('DNgroupMain');
        $oldSmsHash->Splice($hashIndex[0]+1,0, DNmaxTotalSimultaneousCalls => '');

        @hashIndex = $oldSmsHash->Indices('DNnumberOfSIPContacts');
        $oldSmsHash->Splice($hashIndex[0]+1,0, DNsipContactList => '');

		@hashIndex = $oldSmsHash->Indices('mohMusic');
        $oldSmsHash->Splice($hashIndex[0]+1,0, mr => '', rejAnyDev => '', ringHome => '', homedevtimeout => '');

        @hashIndex = $oldSmsHash->Indices('alarmCallMaxAlarms');
        $oldSmsHash->Splice($hashIndex[0]+1,0, alarmCallTrType => '');

        @hashIndex = $oldSmsHash->Indices('wlMinDigitsToRoute');
        $oldSmsHash->Splice($hashIndex[0]+1,0, callNt => '');

        @hashIndex = $oldSmsHash->Indices('callNt');
        $oldSmsHash->Splice($hashIndex[0]+1,0, callNtAddressList => '');

        @hashIndex = $oldSmsHash->Indices('callNtAddressList');
        $oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSLMax => '');

        @hashIndex = $oldSmsHash->Indices('callNtSCSLMax');
        $oldSmsHash->Splice($hashIndex[0]+1,0, callNtSCSL => '');

    }

	# Setting the Hash values based on the user defined Hash

    while (($key,$value) = each %hashChanges) {
                    $smsEntries{$key}=$value;
    }

	# Printing the hash as a CSV file

	while (($k,$v) = each %smsEntries) {
		if($k eq 'START_PIPE') {
			print MYFILE "|-|,";
			&printCommas(162);
#Naresh: 15/03/2011: Changed the Delimitter from "|+" to "\" as per the latest fix among 8.02 and 7.3.7 onwards. Since this Delimitter was already supported among Old BulkLoader, no special changes needed.
			print MYFILE "\\\n";
		}
		else {
			if ($k eq 'wlMinDigitsToRoute' && ( $majVer eq 'V08.01' || $majVer eq 'V08.00' || $majVer eq 'V08.02') )	{
				print MYFILE "$v,\\\n";
				}
			elsif ($k eq 'callNtSCSL' && ( $minVer eq 'V07.03.05' || $minVer eq 'V07.03.06' || $minVer eq 'V07.03.07' || $majVer eq 'V08.03' ) )	{
				print MYFILE "$v,\\\n";
				}
			else {
				print MYFILE "$v,";
				}
		}
	}
	&printCommas(60);
	print MYFILE "|";
	&printCommas(191);
	print MYFILE "\n";

    $logger->debug(__PACKAGE__ . ".$sub_name: Values Set Successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
close (MYFILE);

}

sub printCommas {
        
    my($count) = @_;
    for(my $i=0;$i<$count;$i++){
        print MYFILE ",";
    }
}

sub resetValues{
  while(($key,$value) = each %smsEntries) {
   $smsEntries{$key}='';
   }
}

=head1 B<sub commitValues()>

=over 6

=item DESCRIPTION:

 This function is used to commit the changed values and copy the failed files into SMS_ERROR_LOGS/

=item PACKAGE:

 SonusQA::EMS

=item GLOBAL VARIABLES USED:

 None

=item ARGUMENTS:
 1. $tcid - testcase ID
 2. $smsuser - username
 3. $smspwd - Password

=item OUTPUT:
 Boolean 1 for success and 0 for failure

=back

=cut

sub commitValues {

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".commitValues");
    my($self,$tcid,$smsuser,$smspwd)=@_;
	
    my $sub_name = "commitValues";

    my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $hostip = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostuser = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostpwd = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    my $emstarget = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{SCRIPT_DIR};
    my $smsExe = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{EXECUTION_SCRIPT};

    $logger->warn(__PACKAGE__ . ".$sub_name:  Commiting Changed Values");

    $ftp = Net::FTP->new($hostip,Debug => 0);
    $ftp->login("$hostuser","$hostpwd");
    $ftp->cwd("$emstarget");
    $ftp->put("Temp/$csv");
    $ftp->quit;

    my $file_size;
	my @errrorfile=();
    my @content=();
	
    my $cmd1="cd $emstarget";
    my $cmd2="./$smsExe $csv $hostname $smsuser $smspwd";
    my $cmd3="ls -lrt $csv.errors";

    unless ($self->{conn}->cmd($cmd1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd1 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	$main::failure_msg .= "UNKNOWN:EMS - Execution of command $cmd1 failed ";
        return 0;
    }

	if (@smsContents = $self->{conn}->cmd($cmd2)) {
        $logger->info(__PACKAGE__ . ".$sub_name: command success :$cmd2 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: @smsContents \n");
	} else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd2 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	$main::failure_msg .= "UNKNOWN:EMS - Execution of command $cmd2 failed ";
        return 0;
    }
      
	$logger->info(__PACKAGE__ . ".$sub_name:  Checking for Failures while Committing!");

	if (@content = $self->{conn}->cmd($cmd3)) {
        $logger->info(__PACKAGE__ . ".$sub_name: command success :$cmd3 ");
	} else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command:$cmd3 ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	$main::failure_msg .= "UNKNOWN:EMS - Execution of command $cmd3 failed ";
        return 0;
    }

	if (grep(/No such file or directory/,@content))
	{
        $logger->error(__PACKAGE__ . ".$sub_name: Error File Not Found! ");
        return 0;
    } else {		
    foreach(@content){
            $file_size = (split /\s+/,$_)[4];
            $logger->debug(__PACKAGE__ . ".$sub_name: file Size: $file_size");
        last;
    		}
	}


    if($file_size == 0){
		sleep 5;
        $logger->debug(__PACKAGE__ . ".$sub_name: Values Committed Successfully");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        system ("rm -rf Temp");
        return 1;
    } else {
        $logger->warn(__PACKAGE__ . ".$sub_name: Error While Committing Values!");

        my $errorFile = "$csv.errors";
        my $failedFile = "$csv.failed";
    
        my $newErrorFile = "$tcid"."_$errorFile";
        my $newFailedFile = "$tcid"."_$failedFile";
        my $cmd4="cp $errorFile SMS_ERROR_LOGS/$newErrorFile";
        my $cmd5="cp $failedFile SMS_ERROR_LOGS/$newFailedFile";
    
        $self->{conn}->cmd("mkdir -p SMS_ERROR_LOGS");
    
        unless ( @content = $self->{conn}->cmd($cmd4)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to Copy the Error File .");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Error file $errorFile renamed to $newErrorFile");
        $logger->debug(__PACKAGE__ . ".$sub_name: PLEASE CHECK \"$newErrorFile\" FOR FAILURES UNDER \"$emstarget\"");
            
        unless ( @content = $self->{conn}->cmd($cmd5)) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to Copy the Failed File .");
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Failed file $failedFile renamed to $newFailedFile");
        system ("rm -rf Temp");
        
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
}

#########################################################################################################


=head1 B<sub parseLogFile()>

=over 6

=item DESCRIPTION:

 This function parses the log file in EMS, for given list of pattern(s).
 If all the pattern(s) are found in log file returns SUCCESS (1). If any of the pattern not found in log file returns FAILURE (0)

=item ARGUMENTS:

 1. Log filename to parse
 2. Log file path
 3. List of patterns to search in log file

=item PACKAGE:

 SonusQA::EMS

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 in log file
 1 - All pattern(s) found in log file.
 0 - Failure: Any of the pattern not found in log file.


=item EXAMPLE:

 my $emsObj = $TESTBED{"ems:1:obj"};
 my ($result, $refHash) = $emsObj->parseLogFile(
                                 -file => 'sonustrap.log',
                                 -path => '/export/home/netcool/omnibus/log',
                                 -patterns => [
                                     'SCCP Remote Subsystem congestion level change',
                                     'MTP2 link mtp2ItuLink3 state change',
                                  ],
                             );
 unless ( $result ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Parse log file FAILED";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        return 0;
 }

=back

=cut

sub parseLogFile {
    my ( $self, %args ) = @_;

    my $sub_name = "parseLogFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    # Checking mandatory args;
    foreach ( "file", "path", "patterns" ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	    $main::failure_msg .= "UNKNOWN:EMS - Mandatory arguement has not been specified or is blank. ";
            return 0;
        }
    }

    my ($log_file_name, @patterns);
    $log_file_name = "$args{'-path'}\/$args{'-file'}";
    @patterns      = @{$args{'-patterns'}};

    my %resultHash;
    foreach (@patterns) {
        my @output = $self->execCmd( "grep -s \"$_\" $log_file_name" );

        if (@output) {
            $resultHash{$_} = \@output;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name:  FAILED: In file \'$log_file_name\' - Pattern \`$_\` not available");
	    $main::failure_msg .= "UNKNOWN:EMS - Pattern \'$_\' not found in file \'$log_file_name\' ";
        }
    }

    my $result = 0;
    if ( ($#patterns + 1) == (scalar keys %resultHash) ) {
        $result = 1;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$result]");
    return ( $result, \%resultHash );
}

=head1 B<sub emsTrapLogStart()>

=over 6

=item DESCRIPTION:

 This subroutine is used to start capture of sonustrap logs per testcase in EMS and stores the logfilename and the process id in an object.

=item ARGUMENTS:

 optional:
    1. Temporary Log filename
    2. Log file path
    3. testCaseId

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 Return value : 1   if tail successful
                0   if tail unsuccessful

=item EXAMPLE:

 my $pid = $emdobj->emsTrapLogStart( -file => $file,
                                     -path => '/export/home/netcool/omnibus/log',
                                     -testCaseId => $tcaseid );
 
=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub emsTrapLogStart {

    my ($self, %args) = @_;
    my $sub = "emsTrapLogStart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub entering function.");
    my (@result,$pid,$procid,@result1);
    my @retvalues;
    my $destFileName;

    my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
    $year  += 1900;
    $month += 1;

    if( defined ($args{-file}) ){
        $destFileName = $args{-file};
    } else{
        $destFileName = SONUSTRAP;
    }

    # Prepare $log name
    my $source_path = ($self->{PLATFORM} eq 'linux') ? '/opt/sonus/netcool/omnibus/log' : '/export/home/netcool/omnibus/log';
    if( defined ($args{-path}) ) {
        $log = "$args{-path}/$destFileName";
    } else{
        $log = "$source_path/$destFileName";
    }
    $logger->debug(__PACKAGE__ . "$sub destination log filename : $log ");

    @result = $self->execCmd("tail -f $source_path/sonustrap.log > $log &");
    $logger->debug(__PACKAGE__ . "$sub Result : @result");
    chomp($result[0]);

    @result1 = $self->execCmd("echo \$?");

    chomp($result1[0]);
        $logger->debug(__PACKAGE__ . ".$sub RESULT : @result1");

    if ($result1[0] =~ /^0$/) {
        if ($result[0] =~ /\]/) {
            my @pid = split /\]/,$result[0];
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[0]) =~ s/^\s+//g;
            $procid = $result[0];
        }
        $logger->info(__PACKAGE__ . ".$sub Started tail for $log - process id is $procid");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start tail for $log,Process id set to null");
	$main::failure_msg .= "UNKNOWN:EMS - Process id is not set, hence failed to start tail for $log ";
        $procid = 0;
        # Setting logname to null as we couldn't start xtail.
        $log = "null";
        return 0;
    } # End if

    $self->{LogFileName} = $log;
    $self->{Pid} = $procid;
    return 1;

} # End sub emsTrapLogStart

=head1 B<sub emsTrapLogStop()>

=over 6

=item DESCRIPTION:

 This subroutine is used to kill the tail process started by emsLogStart

=item ARGUMENTS:

 Process id of tail process started by emsTrapLogStart

=item GLOBAL VARIABLES USED:

 None

=item EXAMPLE:

 $emsObj->emsTrapLogStop( -pid => $pid);

=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub emsTrapLogStop {

    my ($self, %args ) = @_ ;
    my $sub = "emsTrapLogStop()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");

    my (@result, $log_pid);
    my $flag = 1; # Assume success

    if( defined ($self->{Pid}) ) {
        $log_pid = $self->{Pid};
        $logger->debug(__PACKAGE__ . "$sub Process Id : $log_pid");
    }else{
        $logger->debug(__PACKAGE__ . "$sub Process Id not Found!!");
	$main::failure_msg .= "UNKNOWN:EMS - Not able to find process Id $log_pid ";
        return 0;
    }

    if ($log_pid ne "null") {
        @result = $self->execCmd("ps -p $log_pid");
        @result = $self->execCmd("echo \$?");
        chomp($result[0]);
        if ($result[0] =~ /^0$/) {
            @result = $self->execCmd("kill -9 $log_pid");
            @result = $self->execCmd("echo \$?");
            chomp($result[0]);

            if ($result[0]) {
                $logger->error(__PACKAGE__ . ".$sub Process $log_pid has not been killed");
		$main::failure_msg .= "UNKNOWN:EMS - $log_pid process has not been killed ";
                $flag = 0;
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub Process $log_pid has been killed");
		$main::failure_msg .= "UNKNOWN:EMS - $log_pid process has been killed ";
            } # End if
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub Process $log_pid does not exist");
	    $main::failure_msg .= "UNKNOWN:EMS - Process $log_pid does not exist ";
            $flag =0;
        } # End if
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub Process id is null");
    } # End if

    undef $self->{Pid};
    $logger->info(__PACKAGE__ . ".$sub leaving with retcode-$flag.");
    return $flag;

} # End emsTrapLogStop


=head1 B<sub DESTROY()>

=over 6

=item DESCRIPTION:

 This subroutine is used to kill the tail process started by emsLogStart

=item GLOBAL VARIABLES USED:

 None

=item EXAMPLE:

 $emsObj->DESTROY();

=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub DESTROY {

    my ($self, %args) = @_;
    my $sub = "DESTROY()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub Entering function.");

    if ( defined $self->{Pid} and $self->{Pid}) {
        unless( $self->emsTrapLogStop() ){
           $logger->error(__PACKAGE__ . ".$sub Process ($self->{Pid}) is not killed");
	   $main::failure_msg .= "UNKNOWN:EMS - Not able to kill ($self->{Pid}) process ";
           return 0;
        } else {
           $logger->info(__PACKAGE__ . ".$sub Process ($self->{Pid}) successfully killed!!");
        }
    }

    # Fall thru to regular Base::DESTROY method.
    $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    SonusQA::Base::DESTROY($self);
    $self->{root_session}->closeConn() if (defined $self->{root_session});
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

=head1 B<sub copyTrapLogsToServer()>

=over 6 

=item DESCRIPTION:

 This subroutine is used to copy the Trap Logs (generated by emsTrapLogStart()) from the EMS Server.

=item OPTIONAL:

 1. testcaseid
 2. logs directory
 3. Destination File Name

=item GLOBAL VARIABLES USED:

 None

=item EXAMPLE:

 $emsObj->copyTrapLogsToServer ( -testCaseId   => $id,
                                 -log_Dir      => $path,
                                 -destFileName => $file );

=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub copyTrapLogsToServer {

    my ($self, %args) = @_;
    my $sub = "copyTrapLogsToServer()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");

    my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
    $year  += 1900;
    $month += 1;
    my ($timeStamp, $destFileName, $destFile, $currentDirPath, $scpe, $EmsPath);

    if( defined ($args{-testCaseId}) ) {
        $timeStamp = $args{-testCaseId} . "-" . $hour . $min . $sec . "-" . $day . $month . $year ;
    }else{
        $timeStamp = "NONE" . "-" . $hour . $min . $sec . "-" . $day . $month . $year ;
    }

    #TMS alias details
    my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $hostip = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostuser = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostpwd = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};

    if ( defined ($self->{LogFileName}) ){
        $EmsPath = "$self->{LogFileName}";
    }else{
        $logger->error(__PACKAGE__ . ".$sub LogFileName Not Found!!");
	$main::failure_msg .= "UNKNOWN:EMS - Not able to find LogFileName ";
        return 0;
    }

    #Framing the destination file name
    if( defined ($args{-destFileName}) ) {
        $destFileName = "$timeStamp" . "-" . "EMS" . "-" . "$hostname" . "-" . "$args{-destFileName}";
    }else{
        $destFileName = "$timeStamp" . "-" . "EMS" . "-" . "$hostname" . "-" . "SONUSTRAP";
    }
    $logger->debug(__PACKAGE__ . ".$sub Destination FileName : $destFileName");

    my $user_home = qx#echo ~#;
    chomp($user_home);

    if (defined $args{-log_Dir} && exists $args{-log_Dir}) {
        $destFile = "$args{-log_Dir}" . "/" . "$destFileName";
    }else {
        $dest_path = "$user_home/ats_user/logs";
        if(-e $dest_path ){
            $currentDirPath = $dest_path;
        }else{
            qx#mkdir -p $user_home/ats_user/logs#;
            $currentDirPath = $dest_path;
        }
        chomp ($currentDirPath);
        $destFile = "$currentDirPath" . "/" . "$destFileName";
    }
    $logger->info(__PACKAGE__ . ".$sub destination file : $destFile");

#    #creating SFTP connection to EMS
#    $logger->info(__PACKAGE__ . ".$sub :  Opening SFTP session to EMS, ip = \'$hostip\', user = \'$hostuser\', passwd = TMS_ALIAS->LOGIN->1->ROOTPASSWD");
#    $sftp_session_EMS = new Net::SFTP( $hostip,
#                                     user     => $hostuser,
#                                     password => $hostpwd,
#                                     debug    => 0,
#                                             );
#
#    unless( $sftp_session_EMS ) {
#        $logger->error(__PACKAGE__ . ".$sub : cannot create SFTP connection ");
#        return 0;
#    }
#    $logger->info(__PACKAGE__ . ".$sub : SFTP Connection to EMS Successful!!");
#    $logger->debug(__PACKAGE__ . ".$sub : EMS logpath : $EmsPath");
#
#    #copying logs from EMS to local path
#    $sftp_session_EMS->get("$EmsPath", "$destFile");
    my %scpArgs;
    $scpArgs{-hostip} = $hostip;
    $scpArgs{-hostuser} = "$hostuser";
    $scpArgs{-hostpasswd} = "$hostpwd";
    $scpArgs{-scpPort} = "22";
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$EmsPath;
    $scpArgs{-destinationFilePath} = $destFile;

    unless(&SonusQA::Base::secureCopy(%scpArgs)){
       $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
       return 0;
    }

    if( -e $destFile ) {
       $logger->info(__PACKAGE__ . ".$sub : Successfully copied the logs from EMS Server to $destFile");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
       return 1;
    }else {
       $logger->error(__PACKAGE__ . ".$sub : Error while copying the logs from the EMS Server!! ");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
       return 0;
    }
}

=head1 B<sub deleteTrapLogsfromEms()>

=over 6

=item DESCRIPTION:

 This subroutine is used to delete the TrapLogs (generated by emsTrapLogStart()) from the EMS Server.

=item GLOBAL VARIABLES USED:

 None

=item EXAMPLE:

 $emsObj->deleteTrapLogsfromEms();

=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut


sub deleteTrapLogsfromEms {

    my ($self, %args) = @_;
    my $sub = "deleteTrapLogsfromEms()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");
    my $EmsLog;

    if( defined ($self->{LogFileName}) ){
        $EmsLog = "$self->{LogFileName}";
    }else{
        $logger->error(__PACKAGE__ . ".$sub LogFileName Not Found!!");
	$main::failure_msg .= "UNKNOWN:EMS - Not able to find LogFileName ";
        return 0;
    }

    $self->execCmd("rm -rf $EmsLog");
    @result = $self->execCmd("ls $EmsLog");

    if(grep (/No such file or directory/i, @result)){
        $logger->info(__PACKAGE__ . ".$sub TrapLogFile ($EmsLog) successfully deleted");
        return 1;
    }else{
        $logger->error(__PACKAGE__ . ".$sub TrapLogFile ($EmsLog) not deleted");
	$main::failure_msg .= "UNKNOWN:EMS - Not able to delete TrapLogFile ($EmsLog) ";
        return 0;
    }
}

=head1 B<sub execSqlplusCommand()>

=over 6

=item DESCRIPTION:

 This function executes the sql plus command and returns the command result as a reference to array of hashes

=item ARGUMENTS:
    
 SqlPlus CMD and timeout

=item GLOBAL VARIABLES USED:

 None

=item EXAMPLE:

 $emsObj->execSqlplusCommand();

=item AUTHOR:

 Naresh Kumar Anthoti (nanthoti@sonusnet.com)

=back

=cut

sub execSqlplusCommand{
    my ($self, $sqlQuery)=@_;
    my ($sqlServer,$dbh,$sth,$hashRef,$finalResult);
    my $sub = "execSqlplusCommand";
    $sqlServer = $self->{OBJ_HOST};
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    if(!defined $sqlQuery) {
	$logger->warn(__PACKAGE__ . ".$sub  MISSING - REQUIRED");
	return 0;
    };
    eval {
        $dbh =  DBI->connect("dbi:Oracle:host=$sqlServer;sid=SIDB",'dbimpl','dbimpl');
    };
    unless ($@) {
	$logger->info(__PACKAGE__ . ".$sub  Preparing SQL COMMAND $sqlQuery");
	$sth = $dbh->prepare($sqlQuery);
	$logger->info(__PACKAGE__ . ".$sub  EXECUTE SQL COMMAND $sqlQuery");
	unless ($sqlQuery =~ /^SELECT\s/i)
	{
		$sth->execute() or die $dbh->errstr;
		$logger->info(__PACKAGE__ . ".$sub SQL COMMAND $sqlQuery Executed successfully");
		$sth->finish();
		$dbh->commit or die $dbh->errstr;
		$logger->info(__PACKAGE__ . ".$sub COMMIT of $sqlQuery successful");
		return 1; #Return success (1) from subroutine
	}
	$sth->execute;
	while($hashRef = $sth->fetchrow_hashref())
	{
	    if(defined $hashRef){
		push(@{$finalResult},$hashRef);
	    }else{
		$logger->error(__PACKAGE__ . ".$sub:  ERROR while fetching Query Result:". $sth->err );
		$main::failure_msg .= "UNKNOWN:EMS - Fetching query result failed. ";
	    }
	}
	return $finalResult;	
    }else{
	$logger->error(__PACKAGE__ . ".$sub:  failed to connect to oracle Server :$@ ");
	$main::failure_msg .= "UNKNOWN:EMS - Connection to oracle server failed. ";
	return 0;
    }
}

=head1 B<sub enableCalea>

=over 6

=item DESCRIPTION:

 Subrotuine to enable calea user.

=item PACKAGE:

 SonusQA::EMS

=item ARGUMENTS:

 NONE

=item RETURN:

 0 - Failure to enable calea user
 1 - Successfully enable calea user

=item EXAMPLE:

 unless($self->enableCalea()){
    $logger->error(__PACKAGE__ . ".$sub : Failed to enable calea.");
    return 0;
 }

=back

=cut


sub enableCalea {
    my $self = shift;
    my $sub = 'enableCalea';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entering sub.");

    unless($self->becomeUser()){
       $logger->error(__PACKAGE__ . ".$sub: Unable to enter as insight");
       $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub -> [0]"); 
       return 0;
    }
    $self->execCmd('cd /export/home/ems/weblogic/sonusEms/data/sys');
    $self->execCmd('echo defaultCaleaUser=true >> SystemConfig.txt');
    
    unless ($self->stopInsight ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to stop insight");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub -> [0]");
      return 0;
    }

    unless ($self->startInsight ) {
      $logger->error(__PACKAGE__ . ".$sub: failed to start insight");
      $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub -> [0]");
      return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub -> [1]");
    return 1;

}

1;
