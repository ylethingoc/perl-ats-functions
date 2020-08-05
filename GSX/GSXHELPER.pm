package SonusQA::GSX::GSXHELPER;

=head1 NAME

 SonusQA::GSX::GSXHELPER - Perl module for Sonus Networks GSX 9000 interaction

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Utils, Data::Dumper, POSIX

=head1 METHODS

=cut

use SonusQA::Utils qw(:all logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use File::stat;
use File::Basename;
use Text::CSV;
use Time::HiRes qw(gettimeofday tv_interval);
use Tie::IxHash;
use Time::Local;
our $VERSION = "6.1";
our $resetPort = 0;
our $portType;

use vars qw($self);
# INITIALIZATION ROUTINES FOR CLI
# -------------------------------

sub ICMUsage (){
  my ($self,$mKeyVals)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $slot);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".ICMUsage");
  unless(defined($mKeyVals)){
    $logger->warn(__PACKAGE__ . ".ICMUsage  MANADATORY KEY VALUE PAIRS ARE MISSING.");
    return 0;
  };
  unless(defined($mKeyVals->{'slot'})){
    $logger->warn(__PACKAGE__ . ".ICMUsage  MANADATORY KEY [slot] IS MISSING.");
    return 0;
  };
  $cmd = sprintf("icmusage %s ", $mKeyVals->{'slot'});
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/^error/i){
      $logger->warn(__PACKAGE__ . ".ICMUsage  CMD RESULT: $_");
      $flag = 0;
      next;
    }
  }
  return @cmdResults;
}

=head1 adminDebugSonus({'<key>' => '<value>', ...})

Example: 

$obj->adminDebugSonus()

Mandatory Key Value Pairs:
        none

Optional Key Value Pairs:
       none

BASE COMMAND:	 icmusage <slot>

=cut

# ROUTINE: adminDebugSonus
# Purpose: OBJECT CLI API COMMAND, GENERIC FUNCTION FOR POSITIVE/NEGATIVE TESTING
sub adminDebugSonus (){
  my ($self)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $slot);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".adminDebugSonus");
  $cmd ="admin debugSonus";
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/^error/i){
      $logger->warn(__PACKAGE__ . ".adminDebugSonus  CMD RESULT: $_");
      $flag = 0;
      next;
    }
  }
  return @cmdResults;
}

sub DSPSlotStat (){
  my ($self,$mKeyVals)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $slot);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DSPSlotStat");
  unless(defined($mKeyVals)){
    $logger->warn(__PACKAGE__ . ".DSPSlotStat  MANADATORY KEY VALUE PAIRS ARE MISSING.");
    return 0;
  };
  unless(defined($mKeyVals->{'slot'})){
    $logger->warn(__PACKAGE__ . ".DSPSlotStat  MANADATORY KEY [slot] IS MISSING.");
    return 0;
  };
  $cmd = sprintf("dspslotstat slot %s ", $mKeyVals->{'slot'});
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/^error/i){
      $logger->warn(__PACKAGE__ . ".DSPSlotStat  CMD RESULT: $_");
      $flag = 0;
      next;
    }
  }
  return @cmdResults;
}

sub PingIP (){

  my ($self,$ip)=@_;
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $IP);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "PingIP");
  @cmdResults = ();
  unless(defined($ip)){
    $logger->warn(__PACKAGE__ . ".PingIP  IP MISSING");
    return @cmdResults;
  };
  $cmd = sprintf("ping -c 4 %s ", $ip);
  @cmdResults =  $self->execCmd($cmd);
  foreach(@cmdResults) {
      $logger->info(__PACKAGE__ . ".PingIP SUCCESSFULLY pinging: $_");
  }
}

sub getVersion () {
  # Uses puts $VERSION on GSX CLI to determine version of product
  # Typically output: V07.01.00 A014
  # Process will try to determine major, minor, maintenance and build information first,
  my ($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getVersion");
  my(@cmdResults,$cmd);
  $cmd = 'puts $VERSION';
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/.*V(\d+)\.(\d+)\.(\d+)\s+(.*)/i){
      $_ =~ s/\s//g;
      $logger->info(__PACKAGE__ . ".getVersion  SUCCESSFULLY RETRIEVED VERSION: $_");
      $self->{VERSION} = $_;
      #$self->{VERSION} = sprintf("V%s.%s.%s%s",$1,$2,$3,$4);
      $self->{VERSION} =~ tr/A-Za-z0-9\. //cd;
    }
  }
}

sub getProductType () {
  my ($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getProductType");
  my(@cmdResults,$cmd);
  $self->{PRODUCTTYPE} = "UNKNOWN";
  $cmd = 'puts $PRODUCT';
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/.*GSX(\d+)/i){
      my $type = $_;
      $type =~ tr/A-Z/a-z/;
      $self->{PRODUCTTYPE} = $type;
      $self->{PRODUCTTYPE} =~ tr/A-Za-z0-9//cd;
      $logger->info(__PACKAGE__ . ".getProductType  SUCCESSFULLY RETRIEVED PRODUCT TYPE: $self->{PRODUCTTYPE}");
    }
  }
}

sub cns30ISUPcics () {
    my($self,$service, $slot, $cicstart, $portStart, $portEnd)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".cns30ISUPcics");
    $logger->info(__PACKAGE__ . ".cns30ISUPcics   CREATING CNS30 ISUP CICS");
    my $startcic = $cicstart;
    my $endcic = $startcic+23; 
    for(my $x=$portStart;$x<=$portEnd;$x++){
        $self->execFuncCall('createIsupCircuitServiceCic',{'sonusIsupsgCircuitServiceName'=> $service, 'cic' => "$startcic-$endcic"});
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", "sonusIsupsgCircuitPortName" => "T1-1-$slot-1-$x", "sonusIsupsgCircuitChannel" => '1-24'});  
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitDirection'=> 'twoway'});
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitProfileName'=> 'default'});
        $self->execFuncCall('configureIsupCircuitServiceCicState',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitAdminState'=> 'enabled'});
        $self->execFuncCall('configureIsupCircuitServiceCicMode',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'mode'=> 'unblock'});
        $startcic ++;
        $endcic = $startcic+23;
    }
}

sub cns10ISUPcics () { 
    my($self,$service, $slot, $cicstart, $portStart, $portEnd)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".cns10ISUPcics");
    $logger->info(__PACKAGE__ . ".cns10ISUPcics   CREATING CNS10 ISUP CICS");
    my $startcic = $cicstart;
    my $endcic = $startcic+23; 
    for(my $x=$portStart;$x<=$portEnd;$x++){
	my $starttrunkmember = $startcic + 1000;
        my $endtrunkmember = $endcic + 1000;
        $self->execFuncCall('createIsupCircuitServiceCic',{'sonusIsupsgCircuitServiceName'=> $service, 'cic' => "$startcic-$endcic"});
	$self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", "sonusIsupsgCircuitPortName" => "T1-1-$slot-$x", "sonusIsupsgCircuitChannel" => '1-24'});  
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitTrunkMember'=> "$starttrunkmember-$endtrunkmember"});
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitDirection'=> 'twoway'});
        $self->execFuncCall('configureIsupCircuitServiceCic',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitProfileName'=> 'default'});
        $self->execFuncCall('configureIsupCircuitServiceCicState',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'sonusIsupsgCircuitAdminState'=> 'enabled'});
        $self->execFuncCall('configureIsupCircuitServiceCicMode',{'isup circuit service'=> $service, 'cic' => "$startcic-$endcic", 'mode'=> 'unblock'});
        $startcic ++;
        $endcic = $startcic+23;
    }
}


sub getHWInventory() {
    my($self, $shelf)=@_;
    $shelf ||= 1;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getHWInventory");
    $logger->info(__PACKAGE__ . ".getHWInventory   Retrieving GSX HW inventory");
    if($self->execCmd("show Inventory Shelf $shelf Summary")) {
      $bFlag = 1;  # the command executed  - so that is a start
      foreach(@{$self->{CMDRESULTS}}){
          if(m/^(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)/){
              $logger->debug(__PACKAGE__ . ".getHWInventory   Inventory Item: $_");
              $self->{'hw'}->{$1}->{$2}->{'SERVER'} = $3;
              $self->{'hw'}->{$1}->{$2}->{'SERVER-STATE'} = $4;
              $self->{'hw'}->{$1}->{$2}->{'ADAPTOR'} = $5;
              $self->{'hw'}->{$1}->{$2}->{'ADAPTOR-STATE'} = $6;
          }
      }
    }
    return $bFlag;
}

sub getmgmtNIFStatus() {
    my($self, $shelf)=@_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getmgmtNIFStatus");
    $logger->info(__PACKAGE__ . ".getmgmtNIFStatus Retrieving GSX MGMT NIF Status");
    if($self->execFuncCall('showMgmtNifShelfStatus',{'mgmt nif shelf'=>$shelf})) {
      $bFlag = 1;  # the command executed  - so that is a start
      foreach(@{$self->{CMDRESULTS}}){
          if(m/^(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)/){
              $logger->debug(__PACKAGE__ . ".getmgmtNIFStatus: $_");
              $self->{'hw'}->{$1}->{$2}->{'SHELF'} = $3;
              $self->{'hw'}->{$1}->{$2}->{'SLOT'} = $4;
              $self->{'hw'}->{$1}->{$2}->{'PORT'} = $5;
              $self->{'hw'}->{$1}->{$2}->{'INDEX'} = $6;
          }
      }
    }
    return $bFlag;
}

sub getTGInventory() {
    my($self, $shelf)=@_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getTGInventory");
    $logger->info(__PACKAGE__ . ".getTGInventory   Retrieving GSX Trunk Group inventory");
    if($self->execFuncCall('showTrunkGroupAllStatus')) {
      foreach(@{$self->{CMDRESULTS}}){
          if(m/^(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)/){
              $logger->debug(__PACKAGE__ . ".getTGInventory   Inventory Item: $_");
              $self->{'tg'}->{$1}->{'conf'} = $2;
              $self->{'tg'}->{$1}->{'avail'} = $3;
              $self->{'tg'}->{$1}->{'resv'} = $4;
              $self->{'tg'}->{$1}->{'usage'} = $5;
              $self->{'tg'}->{$1}->{'no-pri'} = $6;
              $self->{'tg'}->{$1}->{'pri'} = $7;
              $self->{'tg'}->{$1}->{'field8'} = $8;
              $self->{'tg'}->{$1}->{'state'} = $9;
          }	
      }
    }
    return $bFlag;
}

sub getICMUsage(){
    my($self)=@_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getICMUsage");
    $logger->info(__PACKAGE__ . ".getICMUsage   Retrieving ICM usage for all known slots");
    foreach my $slot (sort keys %{$self->{'hw'}->{'1'}} ) {
	if( $self->{'hw'}->{'1'}->{$slot}->{'SERVER'} ne 'UNKNOWN'){
	    @results = $self->ICMUsage( {'slot' => $slot} );
            foreach(@{$self->{CMDRESULTS}}){
                chomp($_);
                if($_ =~ m/InUseCount\s+(\d+)/){		
                   $self->{'hw'}->{'1'}->{$slot}->{'ICMUSAGE'} = $1; 
                }
            }
	}
    }
}


sub getCallCounts(){
    my($self)=@_;
    my(@results,$inventory);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getCallCounts");
    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    $logger->info(__PACKAGE__ . ".getCallCounts   Retrieving Call Counts");
    foreach my $slot (sort keys %{$self->{'hw'}->{'1'}} ) {
	if($self->{'hw'}->{'1'}->{$slot}->{'SERVER'} ne 'UNKNOWN'){
	    if($self->execFuncCall('showCallCountsShelfSlot',{'call counts shelf' => '1', 'slot' => $slot})){
              foreach(@{$self->{CMDRESULTS}}){
                  chomp($_);
                  if($_ =~ m/\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/){
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-ATTEMPTS'} = $3;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-COMPLETIONS'} = $4;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-ACTIVE'} = $5;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-STABLE'} = $6;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-TOTAL'} = $7;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-ACTIVE-SIGNAL-CHANNELS'} = $8;
                     $self->{'hw'}->{'1'}->{$slot}->{'CALLCOUNTS'}->{'CALL-STABLE-SIGNAL-CHANNELS'} = $9;
                     
                  }
              }
            }
	}
    }
}


sub getDSPStats(){
    my($self)=@_;
    my(@results,$inventory);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getDSPStats");
    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    $logger->debug(__PACKAGE__ . ".getDSPStats   Retrieving DSP Statistics for all known slots");
    foreach my $slot (sort keys %{$self->{'hw'}->{'1'}} ) {
	if($self->{'hw'}->{'1'}->{$slot}->{'SERVER'} =~ m/^CNS/i){
	    my @results = $self->DSPSlotStat({'slot' => $slot});
	    foreach(@results){
		chomp($_);
		if($_ =~ m/\s+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)/){
		   $self->{'hw'}->{'1'}->{$slot}->{'DSPSTATS'}->{$1}->{'TYPE'} = $2;
		   $self->{'hw'}->{'1'}->{$slot}->{'DSPSTATS'}->{$1}->{'CHANNEL'} = $3;
		   $self->{'hw'}->{'1'}->{$slot}->{'DSPSTATS'}->{$1}->{'MAP'} = $4;
		}
	    }
	}
    }
}

# Only call this method when all functionality exists:  getDSPStats does not work in GSX 5.1.x.
sub gatherStats(){
    my($self)=@_;
    if($self->can("getICMUsage")){
	$self->getICMUsage();
    }
    if($self->can("getCallCounts")){
	$self->getCallCounts();
    }
    if($self->can("getDSPStats")){
	$self->getDSPStats();
    }
}

sub resetNode(){
    my($self,%args)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".resetNode");
    my %a = ( -nowSleep => 1 );

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->info(__PACKAGE__ . ".resetNode   CHECKING OBJECT RESET FLAG");
    if($self->{RESET_NODE}){
	$logger->info(__PACKAGE__ . ".resetNode   CHECKING OBJECT RESET FLAG");
	$logger->info(__PACKAGE__ . ".resetNode   RESET FLAG IS TRUE.  RESET NODE");
	$self->{conn}->cmd("set NO_CONFIRM 0");
	$self->{conn}->cmd("set NO_CONFIRM 1");

        # Sometimes, this update is taking more time and the 'configure node restart' waits for the input from the
        # user. Adding a delay for the update to happen before the 'configure node restart' is executed
        sleep 5;

        $logger->info(__PACKAGE__ . ".resetNode   CHECKING NVSDISABLED FLAG");
        if(defined($self->{NVSDISABLED}) && $self->{NVSDISABLED}){
          $logger->info(__PACKAGE__ . ".resetNode   NVSDISABLED IS TRUE.  ATTEMPTING TO DISABLE PARAMETER MODE");
          $self->execFuncCall('configureNodeNvsShelf',{'sonusbparamshelfindex' => '1', 'sonusBparamParamMode' => 'DISABLED'});
        }else{
          $logger->info(__PACKAGE__ . ".resetNode   NVSDISABLED IS FALSE.  PARAMETER MODE WILL NOT BE TOUCHED");
        }
        $self->{conn}->print("configure node restart");
        $self->{conn}->waitfor('');

        if ( $a{-nowSleep} eq 1) {
            $logger->info(__PACKAGE__ . ".resetNode   RESET ISSUED - SLEEPING FOR 60 AFTER RESET");
            foreach(1..60){
                sleep(1);
            }
        }
    }else{
	$logger->info(__PACKAGE__ . ".resetNode   RESET FLAG IS FALSE.  SKIPPING RESET NODE");
    }
    
}

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


sub getNTPTime(){
    my($self)=@_;
    my(@cmdResults,$cmd,$y,$mo, $d, $h, $min, $s );
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getNTPTime");
    $y=$mo=$d=$h=$min=$s=0;
    $logger->debug(__PACKAGE__ . ".getNTPTime   Retrieving NTP Time");
    $cmd = 'show ntp time';
    @cmdResults = $self->execCmd($cmd);
    foreach(@cmdResults) {
      if(m/.*Date: (\d{4})\/(\d{2})\/(\d{2})\s+(\d{2})\:(\d{2})\:(\d{2}).*/){
        $logger->info(__PACKAGE__ . ".getNTPTime   Discovered NTP Time");
        $y=$1;$mo=$2;$d=$3;$h=$4;$min=$5;$s=$6;
        last;
      }
    }
    # Remove leading zeros from day and month strings
    $mo =~ s/^0*//;
    $d =~ s/^0*//;

    return ($y, $mo, $d, $h, $min, $s);
}
##################################################################################
##################################################################################
# The following procedures were introduced as part of AJ9 CIE testing ############
#  The first fetches the user profile and returns it                             # 
#  The second reboots GSX without checking the object's RESET FLAG               #
##################################################################################
##################################################################################

=head1 B<getUserProfile()>

 ##################################################################################
 #purpose      : returns the profile name defined as a USER PROFILE this in turn  #
 #can be used to determine what configuration has been applied to the GSX         #
 #Parameters   : flag (if set to 1, this will return an array of all user profiles)
 #Return values: Name of the profile(s)
 ##################################################################################

=cut

sub getUserProfile(){
    my($self,$flag)=@_;
    my(@cmdResults,$cmd,$profilename, @profilenames, $diff, $i, $j);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getUserProfile");
    if (!(defined($flag))){
    	$logger->debug(__PACKAGE__ . ".getUserProfile FLAG NOT DEFINED");
    	$flag=0;
    }
        
    $profilename=0;
    $logger->debug(__PACKAGE__ . ".getUserProfile   Retrieving User Profile");
    $cmd = 'show user profile summary';
    @cmdResults = $self->execCmd($cmd);
    my $cmdResultsLength;
    $cmdResultsLength = @cmdResults;
    my $count =1;
    foreach(@cmdResults) {
	if(m/.*User\sProfile\sName.*/){
 		last;
	}
    	$count++;
    }
    if($flag eq 0) {
      	$profilename=$cmdResults[$count];
      	$logger->debug(__PACKAGE__ . ".RETURNING A SCALAR");
        return ($profilename);
    }
    else {
      	my $diff = $cmdResultsLength - $count;
      	for ($i = 0; $i <= $diff; $i++) {
    		push @profilenames, $cmdResults[$count+$i];
    	}
    	$logger->debug(__PACKAGE__ . ".RETURNING AN ARRAY");
    	return @profilenames;
    }   
}

=head1 B<resetNode2()>

 ##################################################################################
 #purpose      : resets the GSX using conf node res without checking reset flag
 #Parameters   : none
 #Return values: nothing 
 ##################################################################################

=cut

sub resetNode2(){
    my($self,%args)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".resetNode2");
    my %a = ( -nowSleep => 1 );
    $logger->info(__PACKAGE__ . ".resetNode2   CHECKING OBJECT RESET FLAG");
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

	$self->{conn}->cmd("set NO_CONFIRM 0");
	$self->{conn}->cmd("set NO_CONFIRM 1");
        $logger->info(__PACKAGE__ . ".resetNode2   CHECKING NVSDISABLED FLAG");
        if(defined($self->{NVSDISABLED}) && $self->{NVSDISABLED}){
          $logger->info(__PACKAGE__ . ".resetNode2   NVSDISABLED IS TRUE.  ATTEMPTING TO DISABLE PARAMETER MODE");
          $self->execFuncCall('configureNodeNvsShelf',{'sonusbparamshelfindex' => '1', 'sonusBparamParamMode' => 'DISABLED'});
        }else{
          $logger->info(__PACKAGE__ . ".resetNode2   NVSDISABLED IS FALSE.  PARAMETER MODE WILL NOT BE TOUCHED");
        }
        $self->{conn}->print("configure node restart");
        $self->{conn}->waitfor('');

    if ( $a{-nowSleep} eq 1 ) {
        $logger->info(__PACKAGE__ . ".resetNode2   RESET ISSUED - SLEEPING FOR 60 AFTER RESET");
        foreach(1..60){
            sleep(1);
        }
    }

}

=head1 B<getCDRfield()>

 ##################################################################################
 # Purpose      : To retrieve the CDR for a call from the GSX's NFS mount point,
 #               and parse through for the field number of interest
 # Parameters   : 1. type of CDR record (START, STOP, ATTEMPT, etc.),
 #               2. number of record type (i.e. 1st START, 2nd STOP, etc.)
 #               3. field number of interest
 # Return values: value in field of interest
 # Author      : Shawn Martin
 # Disclaimer  : The following procedures are used only by PSX QA. Others 
 #	        may use the procedures at their own risk.
 ##################################################################################

=cut

sub getCDRfield() {
    my ($self, $recordtype, $recordnumber, $fieldnumber, $gsxname)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, 
        $acctlogname, $acctlogfullpath, @acctlog, @acctrecord, $acctrecord, $csv, 
        @acctsubrecord, $acctsubrecord, $arraysize, $dsiObj);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getCDRfield");
    $logger->info(__PACKAGE__ . ".getCDRfield  RETRIEVING AND PARSING CDR");

    # Get node name. If the optional 'gsxname' parameter is passed, use it as
    # the node name, otherwise grab it from the chassis itself.
    ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    if (defined($gsxname)) {
        $nodename = $gsxname;
    }

    if (!defined($nodename)) { $logger->warn(__PACKAGE__ . ".getCDRfield NODE NAME MUST BE DEFINED"); return $nodename; }

    # Remove node name if present
    $nfsmountpoint =~ s|$nodename||;

    # Get chassis serial number
    $cmd = "show chassis status";
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active ACT log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
    	if (m/(\w+.ACT)/) {
    	    $acctlogname = "$1";
    	}
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $acctlogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$acctlogname";
	$logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$acctlogname = $acctlogname \n\$acctlogfullpath = $acctlogfullpath");
        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;
        
        # Create DSI object and get log		
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);
	    $self->{dsiObj} = $dsiObj;
        }
        @acctlog = $self->{dsiObj}->getLog($acctlogfullpath);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $acctlogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$acctlogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$acctlogname = $acctlogname \n\$acctlogfullpath = $acctlogfullpath");
        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);
	    $self->{dsiObj} = $dsiObj;
        }
        @acctlog = $self->{dsiObj}->getLog($acctlogfullpath);
    }

    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/) || ($nfsmountpoint =~ m/SipQANFS1/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $acctlogfullpath = "/sonus/SonusQANFS/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$acctlogname";
        }
        else {
            $acctlogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$acctlogname";
        }

        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;
        
        # Create DSI object and get log		
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => 'talc',
                -OBJ_USER => 'autouser',
                -OBJ_PASSWORD => 'autouser',
                -OBJ_COMMTYPE => "SSH",);
	    $self->{dsiObj} = $dsiObj;
        }
        @acctlog = $self->{dsiObj}->getLog($acctlogfullpath); 
    }
    $logger->debug("\$acctlogfullpath = $acctlogfullpath");
    # Parse each START/STOP/ATTEMPT record is placed into an array element,
    my $count = 1;

    #creating TEXT::CSV object
    $csv = Text::CSV->new();

    foreach(@acctlog) {
        if ( $_ =~ m/$recordtype/ ) {
            if ($count == $recordnumber) {
                $csv->parse($_);
                @acctrecord = $csv->fields;
                last;
            }
            else {
                $count++;
            }
        }
    }
  
    # If user is looking for a subfield (ie. ##.#)
    if ($fieldnumber =~ m/(\w+)\.(\w+)/) {
        $acctsubrecord = $acctrecord[$1-1];
        $csv->parse($acctsubrecord);
        @acctsubrecord = $csv->fields;
        $arraysize = @acctsubrecord;
	if ($2 > $arraysize) { # looking for array out-of-bounds situation
            $logger->warn(__PACKAGE__ . ".getCDRfield SUBFIELD DOES NOT EXIST IN ACT LOG");
            return "ERROR - SUBFIELD DOES NOT EXIST";
        }
        else {
            return $acctsubrecord[$2-1];
        }
    }
    else {
        $arraysize = @acctrecord;
        if ($fieldnumber > $arraysize) { 
            $logger->warn(__PACKAGE__ . ".getCDRfield FIELD DOES NOT EXIST IN ACT LOG");
            return "ERROR - FIELD DOES NOT EXIST";
        }
        else { 
            return $acctrecord[$fieldnumber-1]; 
        }
    }
}

=head1 B<getSYSlog()>

 ##################################################################################
 #Purpose      : To retrieve the active GSX SYS log for a call from the GSX's NFS 
 #               mount point.
 #Return values: GSX SYS log
 # Author      : Devaraj GM 
 # Disclaimer  : The following procedures are used only by PSX QA. Others 
 #               may use the procedures at their own risk.
 ##################################################################################

=cut

sub getSYSlog() {
    my ($self)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, 
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getSYSlog");
    $logger->info(__PACKAGE__ . ".getSYSlog RETRIEVING ACTIVE GSX SYS LOG");

    ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    if (!defined($nodename)) { $logger->warn(__PACKAGE__ . ".getSYSlog NODE NAME MUST BE DEFINED"); return $nodename; }

    # Get chassis serial number
    $cmd = "show chassis status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active SYS log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
        if (m/(\w+.SYS)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$dbglogname";
    
        # Create DSI object and get log         
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => $self->{NFSUSERID},
            -OBJ_PASSWORD => $self->{NFSPASSWD},
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
        
    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$dbglogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$dbglogname = $dbglogname \n\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);
        
           @dbglog = $dsiObj->getLog($dbglogfullpath);
    }



 
    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/) || ($nfsmountpoint =~ m/SipQANFS1/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = "/sonus/SonusQANFS/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$dbglogname";
        }
    
        # Create DSI object and get log         
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
    return @dbglog;
}

=head1 B<getTRClog()>

 ##################################################################################
 #Purpose      : To retrieve the active GSX TRC log for a call from the GSX's NFS 
 #               mount point.
 #Return values: GSX TRC log
 # Author      : Devaraj GM 
 # Disclaimer  : The following procedures are used only by PSX QA. Others 
 #	        may use the procedures at their own risk.
 ##################################################################################

=cut

sub getTRClog() {
    my ($self)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, 
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getTRClog");
    $logger->info(__PACKAGE__ . ".getTRClog RETRIEVING ACTIVE GSX TRC LOG");

    ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    # Get node name and NFS details
    if (!defined($nodename)) { $logger->warn(__PACKAGE__ . ".getTRClog NODE NAME MUST BE DEFINED"); return $nodename; }

    # Get chassis serial number
    $cmd = "show chassis status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active TRC log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
    	if (m/(\w+.TRC)/) {
    	    $dbglogname = "$1";
    	}
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/TRC/" . "$dbglogname";
    
        # Create DSI object and get log		
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => $self->{NFSUSERID},
            -OBJ_PASSWORD => $self->{NFSPASSWD},
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
        
    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/TRC/" . "$dbglogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$dbglogname = $dbglogname \n\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);
        
           @dbglog = $dsiObj->getLog($dbglogfullpath);
    }



 
    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/) || ($nfsmountpoint =~ m/SipQANFS1/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = "/sonus/SonusQANFS/" . "$nodename" . "/evlog/" . "$serialnumber" . "/TRC/" . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/TRC/" . "$dbglogname";
        }
    
        # Create DSI object and get log		
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
    return @dbglog;
}

=head1 B<getDBGlog()>

 ##################################################################################
 #Purpose      : To retrieve the active GSX DBG log for a call from the GSX's NFS 
 #               mount point.
 #Return values: GSX DBG log
 # Author      : Shawn Martin
 # Disclaimer  : The following procedures are used only by PSX QA. Others 
 #	        may use the procedures at their own risk.
 ##################################################################################

=cut

sub getDBGlog() {
    my ($self)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, 
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getDBGlog");
    $logger->info(__PACKAGE__ . ".getDBGlog RETRIEVING ACTIVE GSX DBG LOG");

    # Get node name and NFS details
    ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    if (!defined($nodename)) { $logger->warn(__PACKAGE__ . ".getDBGlog NODE NAME MUST BE DEFINED"); return $nodename; }

    # Get chassis serial number
    $cmd = "show chassis status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active DBG log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);    
    foreach(@cmdresults) {
    	if (m/(\w+.DBG)/) {
    	    $dbglogname = "$1";
    	}
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
    
        # Create DSI object and get log		
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => $self->{NFSUSERID},
            -OBJ_PASSWORD => $self->{NFSPASSWD},
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
    
    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$dbglogname = $dbglogname \n\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);

           @dbglog = $dsiObj->getLog($dbglogfullpath);
    }
  


    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/) || ($nfsmountpoint =~ m/SipQANFS1/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = "/sonus/SonusQANFS/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        }
    
        # Create DSI object and get log		
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => "SSH",);
    
        @dbglog = $dsiObj->getLog($dbglogfullpath); 
    }
    return @dbglog;
}


##################################################################################
##################################################################################
# The following procedures are used only by the GSX QA Automation  Group. Others #
# can use the procedures at their own risk.							 
##################################################################################
##################################################################################

=head1 B<getAvailcic()>

 ##################################################################################
 #purpose      : returns the availabe cics for the trunk group supplied
 #Parameters   : trunk group
 #Return values: cic
 ##################################################################################

=cut

sub getAvailcic() {
    my($self, $mytg)=@_;
    my $mycics = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getAvailcic");
    $logger->info(__PACKAGE__ . ".getAvailcic   Retrieving cics for Trunkgroup");
    if($self->execFuncCall('showTrunkGroupStatus',{'trunk group'=> $mytg})){
      foreach(@{$self->{CMDRESULTS}}){
      	if(m/^(\w+)\s+(\w*|\d*)\s+(\w*|\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w)/){
	  if($1 eq $mytg){
	    $logger->info(__PACKAGE__ . ".getAvailcicall.. The available cics for the trunkgroup $mytg is $3" );	    
	    $mycics = $3;
	  }
	} 
      }
}
return $mycics;
}

=head1 B<chkAvailcic()>

 ##################################################################################
 #purpose       : help to make a decision based on available and required cics for calls
 #parameters    : trunk group, required cics
 #return values : returns 0 if  availabe cics == needed cics
 #                -1 if  availabe cics < needed cics
 #                 1 if  availabe cics > needed cics     
 #                -1 if  no trunk group found
 ##################################################################################

=cut

sub chkAvailcic() {
    my($self, $mytg, $needcic)=@_;
    my $decide = -1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".chkAvailcic");
    $logger->info(__PACKAGE__ . ".chkAvailcic   Retrieving cics for Trunkgroup");
    if($self->execFuncCall('showTrunkGroupStatus',{'trunk group'=> $mytg})){
      foreach(@{$self->{CMDRESULTS}}){
      	if(m/^(\w+)\s+(\w*|\d*)\s+(\w*|\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w)/){
	  if($1 eq $mytg){
	    $decide = ($3 <=> $needcic);					
	  }
	} 
      }
}
return $decide;
}

=head1 B<bringupServers()>

 ##################################################################################
 #purpose       : bring up all the server cards in the chassis.
 #Parameters    : none
 #Return Values : none
 ##################################################################################

=cut

sub bringupServers() {
  my( $self, %args ) = @_;  
  $self->getHWInventory(1);
  my $server = ""; 
  my $i = my $cmdSuccess = 0;
  my $adapter = "";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".bringupServers");
    for ($i = 3; $i <= 16; $i++) {
      if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/NS/){
        if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/CNS4/ and (defined $args{-cnsfunction})) {
                  $server = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};
                  $adapter =  $self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'};
		  my $function = $args{-cnsfunction};
		  unless( $function =~ /(e1|t1)/i ){
		      $logger->error(__PACKAGE__ . ".bringupServers  The argument passed for parameter -cnsfunction is invalid. You have passed '$function'. (Valid values are : t1 or e1 ). The CNS CARD FOUND IN SLOT '$i' will not be brought up. ");
		      next;
		  }
		  my $redundancytype = ( $adapter =~ /0$/ ) ? "NORMAL" : "REDUNDANT";
                  $logger->info(__PACKAGE__ . ".bringupServers  CNS CARD FOUND IN SLOT '$i' is '$server' adapter '$adapter' function : '$function' redundancytype : '$redundancytype' ");
                  $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server adapter $adapter FUNCTION $function $redundancytype");
	 	  $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i mode inservice");
                  $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
                  if ($cmdSuccess) {
                        $logger->info(__PACKAGE__ . ".bringupServers command result is $cmdSuccess");
                  }
        }elsif ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} !~ m/CNA0/ ) {
		  $server = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};		  
		  $adapter =  $self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'};
		  $logger->info(__PACKAGE__ . ".bringupServers  CNS CARD FOUND IN SLOT $i is $server and adapter $adapter");
		  $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server adapter $adapter NORMAL");
		  $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
		  if ($cmdSuccess) {
			$logger->info(__PACKAGE__ . ".bringupServers command result is $cmdSuccess"); 
		  }
		  if ( $server =~ /(CNS60|CNS80|CNS85)/i ){
		       $logger->info(__PACKAGE__ . ".bringupServers Enabling T3 for CNS60/CNS80/CNS85 cards ");
		       $self->execCmd("CONFIGURE T3 T3-1-$i-1 STATE ENABLED ");
		       $self->execCmd("CONFIGURE T3 T3-1-$i-1 MODE INSERVICE"); 
		       $self->execCmd("CONFIGURE T3 T3-1-$i-2 STATE ENABLED ");
		       $self->execCmd("CONFIGURE T3 T3-1-$i-2 MODE INSERVICE"); 
		       $self->execCmd("CONFIGURE T3 T3-1-$i-3 STATE ENABLED ");
		       $self->execCmd("CONFIGURE T3 T3-1-$i-3 MODE INSERVICE");
		  }
        }elsif ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/UNKNOWN/ ) {
		  $server = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};		  	  
		  $adapter =  $self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'};
		  $logger->info(__PACKAGE__ . ".bringupServers  CNS CARD FOUND IN SLOT $i is $server and does not have any adapter $adapter");
		}else {
		  $server = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};	
		  $adapter =  $self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'};
		  $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server adapter $adapter REDUNDANT");
		  $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
		  $logger->info(__PACKAGE__ . ".bringupServers  REDUN CNS CARD FOUND IN SLOT $i and server $server and adapter $adapter");
		}
      }elsif ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/SPS/){
		$server = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};		  		
		  $logger->info(__PACKAGE__ . ".bringupServers  SPS CARD FOUND IN SLOT $i is $server");
		  $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server NORMAL");
		  $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
	  }
  }
}

=head1 B<getIsupService()>

 ##################################################################################
 #purpose       : get isup service names.
 #Parameters    : none
 #Return Values : Array of isup service names
 ##################################################################################

=cut

sub getIsupService() {
    my($self)=@_;
    my @services =();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".chkAvailcic");
    $logger->info(__PACKAGE__ . ".getIsupService   Retrieving Isup service Name");
    if($self->execFuncCall('showIsupServiceAllStatus')){
     foreach(@{$self->{CMDRESULTS}}){
      	if(m/^(\w+)\s+(\d-?\d-?\d)\s+(\w+)/){
	  push @services, $1;
        } 
      }
}
    return @services;
}

=head1 B<getIsupPointcode()>

 ##################################################################################
 #purpose       : get isup service Point code for given isup service name.
 #Parameters    : isup service
 #Return Values : point code
 ##################################################################################

=cut

sub getIsupPointcode() {
    my($self, $service)=@_;
    my $pointcode = "";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".chkAvailcic");
    $logger->info(__PACKAGE__ . ".getIsupPointcode   Retrieving point code for Isup service");
   if ($self->execFuncCall('showIsupServiceAllStatus')){
      foreach(@{$self->{CMDRESULTS}}){
      	if(m/^(\w+)\s+(\d-?\d-?\d)\s+(\w+)/){
	  if($1 eq $service){
	    $pointcode = $2;
	    }
        } 
      }
}
    return $pointcode;
}

=head1 B<getNIFs()>

 ##################################################################################
 #purpose       : get all NIFs provisioned on the SLOT
 #Parameters    : shelf,SLOT no
 #Return Values : Array of nifs on the slot
 ##################################################################################

=cut

sub getNIFs() {
    my($self, $shelf, $slot)=@_;
    my @nifs =();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getNIFs");
    $logger->info(__PACKAGE__ . ".getNIFs   Retrieving NIF Names");
     if ($self->execFuncCall('showNifShelfSlotStatus',{'nif shelf' => $shelf, 'slot' => $slot})){
      foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\d-?\d+)\s+(\d)\s+(\w+-?\d-?\d+-?\d*)\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)/){
	  push @nifs, $3;
        } 
      }
     }
    return @nifs;
}

=head1 B<getallSlotnum()>

 ##################################################################################
 #purpose: return slot number for the given Server(if a PNS40/PNA40 is in slots 4,5,6, 
 #	    this proc returns 4,5,6
 #Parameters    : shelf,server, adaptor
 #Return Values : slot number
 ##################################################################################

=cut

sub  getallSlotnum() {
	my($self, $shelf, $server, $adapter)=@_;
	my $i = 0; 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "getallSlotnum  SEARCHING FOR $server CARD");
	$self->getHWInventory(1);

	# Search through slots 3 -16  
	# Changed the search from slot 1 thru 16 to accomodate gsx4000 test cases
	my @slot = ();
	for ($i = 1; $i <= 16; $i++) {

		if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/$server/ ){

			if (($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} eq "SPS70" ) || ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} eq "SPS80" ))       {
				push @slot, $i;
				$logger->info(__PACKAGE__ . ".getallSlotnum  $server CARD FOUND IN SLOT $i");
				next;
			}

			#check if Adaptor is present in the same slot            
			if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/$adapter/ ){
				push @slot, $i;
				$logger->info(__PACKAGE__ . ".getSlotnum  $server CARD FOUND IN SLOT $i");
				#last;
			}else{ 
				## checking for multiple adaptors for a give server card ##
				##   CNS20  |  CNA20, CNA21
				##   CNS30  |  CNA30, CNA33
				##   CSN71  |  CNA70
				##   PNS30  |  PNA30, PNA35
				##   PNS40  |  PNA40, PNA45
				##   PNS41  |  PNA40, PNA45

				my @AAdapter = ();
				switch ($server) 
				{
					case "CNS20"	{ @AAdapter = "CNA21"; }
					case "CNS30"	{ @AAdapter = ("CNA33", "CNA03"); }
					case "CNS71"	{ @AAdapter = "CNA70"; }
					case "PNS30"	{ @AAdapter = "PNA35"; }
					case "PNS40"	{ @AAdapter = "PNA45"; }
					case "PNS41"     { @AAdapter = ("PNA40", "PNA45"); }
					else { $logger->debug(__PACKAGE__ . ".getallSlotnum  $adapter CARD NOT FOUND"); } #out case 
 				}
	
				foreach $a (@AAdapter)
				{
					if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/$a/ ) {
						push @slot, $i;
						$logger->info(__PACKAGE__ . ".getallSlotnum  $server CARD FOUND IN SLOT $i");
						#last;
					}
				}
			}
		}
	}
	return @slot; 
}

=head1 B<getSlotnum()>

 ##################################################################################
 #purpose: return slot number for the given Server(if a PNS40/PNA40 is in slots 4,5,6, 
 #	    this proc returns only 4.
 #Parameters    : shelf,server, adaptor
 #Return Values : slot number
 ##################################################################################

=cut

sub  getSlotnum() {
	my($self, $shelf, $server, $adapter)=@_;
	my @singleslot =(); 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "getSlotnum  ");
	@singleslot = $self->getallSlotnum($shelf, $server, $adapter);
      return $singleslot[0];
}

=head1 B<verifySIF()>

 ##################################################################################
 #purpose: Verify that the given SIF is created.
 #Parameters    : shelf, SIF
 #Return Values : 0 if sif is not provisioned
 #			1 if sif is provisioned
 ##################################################################################

=cut

sub verifySIF() {
   my($self, $shelf, $sifname)=@_;
   my $found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". verifySIF");
    $logger->info(__PACKAGE__ . ".verifySIF   Verifying Provisioned SIF \n");
     if ($self->execFuncCall('showNifSubinterfaceStatus',{'nif subinterface' => $sifname})){
      foreach(@{$self->{CMDRESULTS}}){
            if(m/$sifname/){
	      $found = 1;
  		 last;
        } 
      }
     }
    return $found;
}

=head1 B<getshowheader()>

 ##################################################################################
 #
 #purpose: Parse the header information for Show commands in gsx for all versions
 #Parameters    : shelf
 #Return Values : 2 dimensional array of the header
 #
 # This proc is currently tested for the followng Show commands
 # SHOW NIF <nif> STATUS
 # SHOW NIF <nif> ADMIN
 # SHOW NIF ALL STATUS
 # SHOW NIF ALl ADMIN
 # SHOW NIF SUB <sif> STATUS
 # SHOW NIF SUB <sif> ADMIN
 # SHOW NIF SUB ALL STATUS
 # SHOW NIF SUB ALL ADMIN
 ##################################################################################

=cut

sub getshowheader() {
	my($self)=@_;
    	my @line1 = my @line2 = my @line3 = my @line4 = my @line5 = my @line6 = my @line7 = my @line8 =();
    	my @arr =();
    	## The array addback is used to hold Header words that will be added to the previous header word
	## Example:The word "rate" usually comes after PVP or DGP and is merged to a single word "PVPrate" or "DGPrate"

    	my @addback = qw(rate bucket address reason); #more words can be added in future

    	## The array addbfront is used to hold Header words whose next header word will be added to them.
	## Example: The word that usually comes after the header word "cur" is "bw" and is merged to a single word "curbw"
      

    	my @addfront = qw(cur act max ins); #more words can be added in future

    	my $i= my $j= 0;
    	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getshowheader");
    	$logger->info(__PACKAGE__ . ".getshowheader   Retrieving Header Information");
       
	foreach(@{$self->{CMDRESULTS}}){
      	if(m/^(\-+)/){           #stop when we get to ------
      	last;
	      }
	      if(m/Bandwidth Units/){  #skip this line if present.
		next;
		 }
    
		if (($i > 1) ){
        		$j = $i-2;  #skip the first two lines in the header
			switch ($j) {

				case 0	{ @line1 =split; $arr[$j] = \@line1; }
                		case 1  	{ @line2 =split; $arr[$j] = \@line2; }
                		case 2 	{ @line3 =split; $arr[$j] = \@line3; }
                		case 3   	{ @line4 =split; $arr[$j] = \@line4; }
                		case 4	{ @line5 =split; $arr[$j] = \@line5; }
                		case 5    	{ @line6 =split; $arr[$j] = \@line6; }
                		case 6    	{ @line7 =split; $arr[$j] = \@line7; }
                		case 7   	{ @line8 =split; $arr[$j] = \@line8; }
				else		{ $logger->debug(__PACKAGE__ . ".getshowheader header goes beyond line 8"); }
			}

        		my $k = 0;
        		for($k =0; $k <= $#{$arr[$j]}; $k++){
                       foreach(@addback){
                 			if(m/@{$arr[$j]}[$k]/){
						@{$arr[$j]}[$k-1] = "@{$arr[$j]}[$k-1]"."@{$arr[$j]}[$k]";
						splice(@{$arr[$j]}, $k, 1);
					}
				}#foreach
        		}#for $k

        		for($k =0; $k <= $#{$arr[$j]}; $k++){
                      	foreach(@addfront){
                 			if(m/@{$arr[$j]}[$k]/){
                 		            @{$arr[$j]}[$k] = "@{$arr[$j]}[$k]"."@{$arr[$j]}[$k+1]";
						splice(@{$arr[$j]}, $k+1, 1);
					}
				}#foreach
        		}#for $k

        		#$logger->debug(__PACKAGE__ . ".getshowheader  $j , $#{$arr[$j]} , @{$arr[$j]} \n");

		}#if
        	$i++; #increment to next $_
      }#foreach CMDRESULT

	# now change all the header words to Uppercase
      for($i = 0; $i <= $#arr; $i++){
		for ($j = 0; $j <= $#{$arr[$i]}; $j++) {
            @{$arr[$i]}[$j] =uc @{$arr[$i]}[$j];
            $logger->debug(__PACKAGE__ . ".getshowheader       @{$arr[$i]}[$j]           \n");
		}
	}
	return @arr; #two dimensional array of header.
}

=head1 B<getconfigvalues()>

 ##################################################################################
 #
 #purpose: Populate a particular nif's/sif's config values
 #Parameters    : shelf, nif/sif
 #Return Values : None
 #			
 ##################################################################################

=cut

sub getconfigvalues() {
	my($self, $niforsif, @arra)=@_;
    	my @val =();
    	my ($i, $j, $flag) = (0, 0, 0);

    	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getconfigvalues");
    	$logger->info(__PACKAGE__ . ".getconfigvalues   Populating Config  Information");
      foreach (@{$self->{CMDRESULTS}}){
      	if(m/$niforsif/){
      	        $logger->debug(__PACKAGE__ .".getconfigvalues  $_ \n");
      	        $flag = 1;
             }
            if($flag == 1){
			@val =();
                 if($i <= $#arra){
				@val = split;
	                 if($#val == $#{$arra[$i]}) {
					for($j = 0; $j <= $#{$arra[$i]}; $j++){
						      $self->{$niforsif}->{@{$arra[$i]}[$j]} = $val[$j] ;
                                        $logger->debug(__PACKAGE__ . ".getconfigvalues   @{$arra[$i]}[$j]      $val[$j] \n") ;
					} #for j
				} #if val
			 $i = $i +1 ;
                 } #if i
		} #if flag		
       } #foreach

}

=head1 B<getNIFadminvalues()>

 ##################################################################################
 #
 #purpose: Populate a particular nif's Admin values
 #Parameters    : shelf, nif
 #Return Values : None
 #			
 ##################################################################################

=cut

sub getNIFadminvalues() {
    my($self, $nif)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getNIFconfigvalues");
    $logger->info(__PACKAGE__ . ".getNIFadminvalues   Retrieving NIF Admin Information"); 
    $self->execFuncCall('showNifAdmin', {'nif' => $nif});
    $self->getconfigvalues( $nif, $self->getshowheader());
}

=head1 B<getNIFstatusvalues()>

 ##################################################################################
 #
 #purpose: Populate a particular nif's status values
 #Parameters    : shelf, nif
 #Return Values : None
 #			
 ##################################################################################

=cut

sub getNIFstatusvalues() {
    my($self, $nif)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getNIFstatusvalues");
    $logger->info(__PACKAGE__ . ".getNIFstatusvalues   Retrieving NIF Status Information"); 
    $self->execFuncCall('showNifAllStatus');
    $self->getconfigvalues( $nif, $self->getshowheader());
}

=head1 B<getSIFadminvalues()>

 ##################################################################################
 #
 #purpose: Populate a particular sif's Admin values
 #Parameters    : shelf, sif
 #Return Values : None
 #			
 ##################################################################################

=cut

sub getSIFadminvalues() {
    my($self, $sif)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getSIFadminvalues");
    $logger->info(__PACKAGE__ . ".getSIFadminvalues   Retrieving SIF Admin Information"); 
    $self->execFuncCall('showNifSubinterfaceAdmin',{'nif subinterface' => $sif});
    $self->getconfigvalues( $sif, $self->getshowheader());
}

=head1 B<verifyIProutes()>

 ##################################################################################
 #
 #purpose: Verify IP routes provisioned for a SIF
 #Parameters    : shelf, slot, nexthop
 #Return Values : None
 #			
 ##################################################################################

=cut

sub verifyIProutes() {
    my($self, $slot, $nh)=@_;
    my $found =0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyIProutes");
    $logger->info(__PACKAGE__ . ".verifyIProutes   Verify IP Routes"); 
    $self->execFuncCall('showIpRoutesShelfSlot', {'ip routes shelf' => 1, 'slot' => $slot });
    foreach(@{$self->{CMDRESULTS}}){
    		if(/$nh/) {
			$logger->info(__PACKAGE__ . ".verifyIProutes The IP route is found \n");
			$found = 1;
                 last;
			}
	}
    return $found;
}

=head1 B<verifyNIF()>

 ##################################################################################
 #purpose: Verify that the given NIF is created.
 #Parameters    : shelf, NIF
 #Return Values : 0 if nif is not provisioned
 #             	1 if nif is provisioned
 ##################################################################################

=cut

sub verifyNIF() {
   my($self, $shelf, $nifname)=@_;
   my $found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". verifyNIF");
    $logger->info(__PACKAGE__ . ".verifyNIF   Verifying  NIF \n");
     if ($self->execFuncCall('showNifStatus',{'nif' => $nifname})){
      foreach(@{$self->{CMDRESULTS}}){
            if(m/$nifname/){
	      $found = 1;
  		 last;
        } 
      }
     }
    return $found;
}

=head1 B<verifyNIFgroup()>

 ##################################################################################
 #purpose: Verify that the given NIFGroup is created.
 #Parameters    : shelf, NIFGroup
 #Return Values : 0 if nif is not provisioned
 #		1 if nif is provisioned
 ##################################################################################

=cut

sub verifyNIFgroup() {
   my($self, $shelf, $nifg)=@_;
   my $found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". verifyNIFgroup");
    $logger->info(__PACKAGE__ . ".verifyNIFgroup   Verifying  NIF Group \n");
     if ($self->execFuncCall('showNifgroupSummary')){
      foreach(@{$self->{CMDRESULTS}}){
            if(m/$nifg/){
	      $found = 1;
  		 last;
        } 
      }
     }
    return $found;
}

=head1 B<verifyNIFgroupmem()>

 ##################################################################################
 #purpose: Verify that the given member is in the NIFGROUP.
 #Parameters    : shelf, NIFGroup, sif
 #Return Values : 0 if nif is not provisioned
 #		1 if nif is provisioned
 ##################################################################################

=cut

sub verifyNIFgroupmem() {
   my($self, $shelf, $nifg, $sif)=@_;
   my $found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". verifyNIFgroupmem");
    $logger->info(__PACKAGE__ . ".verifyNIFgroupmem   Verifying  NIF Group member \n");
     $self->{CMDERRORFLAG} =0;
     if ($self->execFuncCall('showNifgroupAdmin',{'nifgroup' => $nifg})){
      foreach(@{$self->{CMDRESULTS}}){
            if(m/$sif/){
	      $found = 1;
  		 last;
        } 
      }
     }
     $self->{CMDERRORFLAG} =1;     
    return $found;
}

=head1 B<getSlotnummns()>

 ##################################################################################
 #purpose: return slot number for the given Server(if a MNS/MNA is in slots 1,2 
 #	    this proc returns only 1.)
 #Parameters    : shelf,server, adaptor
 #Return Values : slot number
 ##################################################################################

=cut

sub getSlotnummns() {
	my($self, $shelf, $server, $adapter)=@_;
	my $i = 0;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "getSlotnummns  SEARCHING FOR $server CARD");
	$self->getHWInventory(1);

	# Search through slots 1 -2 for a MNS and MNA card
	my $slot = 0;
	for ($i = 1; $i <= 2; $i++) {
		if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/$server/ ) {
			#check if MNA is present in the same slot
           
			if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/$adapter/ ) {
				$slot = $i;
				$logger->info(__PACKAGE__ . ".getSlotnummns  $server CARD FOUND IN SLOT $i");
				last;

			## checking for multiple adaptors for a give server card ##
			##   MNS11  |  MNA10
			##   MNS20  |  MNA20, MNA21, MNS25
			} elsif ($server eq "MNS11")	{
				if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/"MNA10"/ ){			
					$slot = $i;
					$logger->info(__PACKAGE__ . ".getSlotnum  $server CARD FOUND IN SLOT $i");
					last;
				} elsif ($server eq "MNS20" )  {
					if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/"MNA21"/ ) {			
						$slot = $i;
						$logger->info(__PACKAGE__ . ".getSlotnum  $server CARD FOUND IN SLOT $i");
						last;
					} elsif ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/"MNA25"/ ) {			
						$slot = $i;
						$logger->info(__PACKAGE__ . ".getSlotnum  $server CARD FOUND IN SLOT $i");
						last;
					} 
				}
			}
		}
	}
	return $slot;
}

=head1 B<verifyElement()>

 ##################################################################################
 # purpose: Verify that the given Element is configured in the CMDRESULTS.
 # Parameters    : element
 # Return Values : 	0 if port is not provisioned
 #				1 if port is provisioned
 ##################################################################################

=cut

sub verifyElement()
{
	my($self,$element)=@_;
	my $found = 0;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". verifyElement");
	$logger->info(__PACKAGE__ . ".verifyElement  Verify Element \n");
	foreach(@{$self->{CMDRESULTS}})
	{
		if(m/$element/)
		{
			$found = 1;
			last;
		} 
	}
	     
	return $found;
}


##################################################################################
# purpose: Count the total number of Stable calls that match with the Called Party Number.
# Parameters    : cdpn - 10 digits
# Return Values : n total number of the Stable calls that match with the CDPN
#
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::countStableCalls(<cdpn>)

 Routine to count the total number of the stable calls that match with the called party number  

=over

=item Arguments

  cdpn <Scalar>
  teh called party number

=item Returns

  Number
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a numberical value

=item Example(s):

  &$gsxObj->countStableCalls(<$cdpn>);

=back

=cut

sub countStableCalls()
{
	my($self,$cdpn)=@_;
	my $stable = 0;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". countStableCalls");
	$logger->info(__PACKAGE__ . ".countStableCalls:  Count Stable Calls \n");

	if ($self->execFuncCall('showCallSummaryAll')){
		foreach(@{$self->{CMDRESULTS}}){
			if((/Stable/) && (/$cdpn/)){
				$stable++;
			}
		} 
	}
	$logger->info(__PACKAGE__ . ".countStableCalls Total Stable calls :  $stable");
	return $stable;
}

##################################################################################
# purpose: Delete All Calls
# Parameters    : None
# Return Values : 	0 no call deleted
#				n total number of calls deleted
##################################################################################
=pod

=head1 SonusQA::GSX::GSXLTT::deleteAllCallsESTNAME>)

 Routine to delete all calls  

=over

=item Arguments

  None

=item Returns

  Number
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a numberical value.

=item Example(s):

  &$gsxObj->deleteLoadTest();

=back

=cut

sub deleteAllCalls()
{
  my($self)=@_;
  my $deleted;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". deleteAllCalls");
  $logger->info(__PACKAGE__ . ".deleteAllCalls:  Delete All Calls");

  my @cmdResults = $self->execCmd('show Call Summary All');	
  foreach(@cmdResults) {
    if (/\s?(\w+)\s+\d+\s+\d+\s+\d+\s+\w+/)	{
      if ($self->execCliCmd("CONFIGURE CALL GCID $1 DELETE")){
        $deleted++;
      } else {
        $logger->error(__PACKAGE__ . ".deleteAllCalls:  DELETE CALL  $1  FAILED");
      }
    }
  } 

  $logger->info(__PACKAGE__ . ".deleteAllCalls: Total Calls Deleted: $deleted");
  return $deleted;
}

######################################################################################
# purpose: Get Accounting Summary Statistics
# Parameters    : None
# Return Values : 	an array value of [Attempts Completions Failures Rate Seconds]
#				
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getAccountingSummary()

 Routine to retrieve accounting summary for the calls.  

=over

=item Arguments

  none

=item Returns

  An Array of the following elements:
  Total Number of Call Attempts, Total Numbers of Call Completions, Total Number of Call Attempt Failures, Busy Hour Call Attempt Rate, Calls per Second, Call Duration in Seconds.

=item Example(s):

  &$gsxObj->getAccountingSummary()

=back

=cut

sub getAccountingSummary()
{
	my($self)=@_;
	my @contents = ("Attempts:","Completions:","Failures:","Rate:","Minute:","seconds");
	my @statistic =();
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getAccountingSummary");
	$logger->info(__PACKAGE__ . ".getAccountingSummary:  Retrieving Accounting Summary Statistics \n");

	if ($self->execCmd('SHOW ACCOUNTING SUMMARY'))	{
		my $linecount = 1;
		my $count		= 1;
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			my $column 	= 0;
			for($column=0; $column<=$#array; $column++)	{
				my $index = 0;
				foreach(@contents)		{
					if ($array[$column] eq $contents[$index])		{
##						$logger->info(__PACKAGE__ . ".getAccountingSummary: Column= ", $column, " Index= ", $index, " Line= ", $linecount, " Count= ", $count,"  \n");
##						push @statistic,$count;	
						if ($array[$column] eq "seconds")	{
							push @statistic, $array[$column+2];
						} else {
							push @statistic, $array[$column+1];	
						}
						$count++;
					}
					$index++;
				}
			}	
			$linecount++;
		} 
	}
	return @statistic;
}

######################################################################################
# purpose		  : Verify Call Tolerance Rate
# Parameters    : trate
# Return Values : 	passed = 1
#				failed = 0
#				
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::verifyToleranceRate(<trate>)

 Routine to verify completion rate against the tolerance rate.  

=over

=item Arguments

  trate <Scalar>
  A number that will be used to compare with the sucessful completion rate

=item Returns

  Boolean
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a true of false Boolean.

=item Example(s):

  &$gsxObj->verifyToleranceRate(0.9);

=back

=cut

sub verifyToleranceRate()
{
	my($self,$trate)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyToleranceRate");
    $logger->info(__PACKAGE__ . ".verifyToleranceRate   Calculate Tolerance Rate"); 

	my $passed = 0;
	my @statistic = $self->getAccountingSummary();
	if ($#statistic == -1)
	{
		$logger->info(__PACKAGE__ . ".verifyToleranceRate:   ACCOUNTING SUMMARY REPORT NOT AVAILABLE \n");
	} else {
		my $sucessfulcallrate 	= 0;
		if ($statistic[0] > 0)	{
			$sucessfulcallrate = ($statistic[1])/$statistic[0];
			$logger->info(__PACKAGE__ . ".verifyToleranceRate:   THE TOTAL NUMBER OF CALL ATTEMPTS IS ", $statistic[0], ", AND CALL COMPLETIONS IS ",  $statistic[1], ". \n");
			my $tolerate = (1 - $trate);
			if (($sucessfulcallrate) >= $tolerate)	{
				$logger->info(__PACKAGE__ . ".verifyToleranceRate:   COMPLETED ", $sucessfulcallrate*100, "% ABOVE/MEET THE TOLERANCE RATE OF ", $tolerate*100,"% PASSED \n");
				$passed = 1;
			} else {
				$logger->info(__PACKAGE__ . ".verifyToleranceRate:   COMPLETED ", $sucessfulcallrate*100, "% BELOW THE TOLERANCE RATE OF ", $tolerate*100,"% FAILED \n");
			}
		}
	}
	return $passed;
}	

######################################################################################
# purpose: Roll the GSX log file to start a new log before the call
# Parameters: (see below)
# Return Value: a string with teh full path name of the log
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::rollLogFile( <logFileType>, <gsxNodeName>, <sonicId>)

 Routine that rolls a particular log file, and returns the path to the current log file (after the log was rolled).

=over

=item Arguments

 logFileType <Scalar>
 A string that determines the type of log to affect. Must be one of DEBUG, ACCT, SYSTEM or TRACE. 
 gsxNodeName <Scaler>
 Name of the GSX node. Needs to be uppercase to match the path of the file on the NFS mount. Should normally be $gsx1->{NODE}->{1}->{NAME}
 sonicId <Scaller>
 Sonid Id of the node. Should normally be $gsx1->{NODE}->{1}->{SONICID}

=item Returns

 full path to the log file <Scaller>
 This is the path from root of the log file, including the NFS mount.

=item Example(s):

 my $gsxLogFile = $gsxObj->rollLogFile( 'DEBUG', $gsx1->{NODE}->{1}->{NAME}, $gsx1->{NODE}->{1}->{SONICID});

=back

=cut

sub rollLogFile()
{
    my( $self, $logType, $nodeName, $sonicId )=@_;
    my $logFileName;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyToleranceRate");
    $logger->debug(__PACKAGE__ . ".rollLogFile   Rolling log files and returning path."); 
    $self->execFuncCall("configureEventLogRollfileNow",
            { 'sonusEvLogType'  => $logType });

    # validate and get the correct path name depending on the log type.
    my $logTypevalid = 0;
    my $fullLogType = $logType;
    if( $logType =~ s/DEBUG/DBG/ ) { $logTypevalid = 1; }
    if( $logType =~ s/ACCT/ACT/ ) { $logTypevalid = 1; }
    if( $logType =~ s/SYSTEM/SYS/ ) { $logTypevalid = 1; }
    if( $logType =~ s/TRACE/TRC/ ) { $logTypevalid = 1; }
    unless( $logTypevalid ) {
       $logger->warn(__PACKAGE__ . ".rollLogFile  Log Type must be one of 'DEBUG|ACCT|SYSTEM|TRACE'.");
       return $logFileName;
    }

    $self->execFuncCall("showNfsShelfSlotStatus", {
        'nfs shelf' => '1',
        'slot'      => '1',
    });
    my @cmdResults = @{$self->{CMDRESULTS}};
    my ($activeNFS, $mountPoint);
    foreach (@cmdResults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/ ) {
            $activeNFS = $1;
        }
        if ( defined $activeNFS ) {
            if( m|($activeNFS).*(/sonus/\w+)|i ) {
                $mountPoint = $2 . "/";
                last;
            }
        }
    }
    unless ( defined $mountPoint ) {
       $logger->warn(__PACKAGE__ . ".rollLogFile  FAILED TO DETERMINE ACTIVE NFS MOUNT.");
       return $logFileName;
    }
    
    # now, look for the actual file name
    $self->execFuncCall("showEventLogShelfStatus",
        { 'sonusEvLogType'  => $fullLogType,
          'shelf'           => '1', });

    @cmdResults = @{$self->{CMDRESULTS}};
    my $actualLog;
    foreach (@cmdResults) {
        if( m/($fullLogType)\s+ENABLED\s+(\w+\.$logType)/ ) {
            $actualLog = $2;;
            last;
        }
    }
    unless ( defined $actualLog ) {
       $logger->warn(__PACKAGE__ . ".rollLogFile  FAILED TO DETERMINE CURRENT $fullLogType FILE NAME.");
       return $logFileName;
    }

    $logFileName = $mountPoint . $nodeName . "/evlog/" .
        $sonicId . '/' . $logType . '/' . $actualLog;

    return $logFileName;
}

######################################################################################
# purpose: 	Retrieve the Total Play counts for a given Segment ID
# Parameters: Shelf, Slot and Segment ID
# Return Value: an array of Current Play and Total Play Counts
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getAnnouncementSummary(<shelf, slot, segid>)

 Routine to retrieve Status Count of a Segment ID .  

=over

=item Arguments

  Shelf 	- 1 <Scalar>
  Slot 	- CSN Slot Number
  Segment ID - Announcement file that is used to play accouncement

=item Return

  Total Play Count

=item Example(s):

  &$gsxObj->getAnnouncementSummary($segid);

=back

=cut

sub getAnnouncementSummary() {
	my	($self, $shelf, $slot, $segid)=@_;
	my	$result	=0;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getAnnouncementSummary");
	$logger->info(__PACKAGE__ . ".getAnnouncementSummary:  Retrieve Announcement Summary Report ");
	if($self->execFuncCall('showAnnouncementSegmentShelfSlotSummary', {'announcement segment shelf' => $shelf, 'slot' => $slot} )) 	{
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			if ($#array >= 6)		{
				if ($array[2] == $segid)		{
					$result = $array[6];	
					$logger->info(__PACKAGE__ . ".getAnnouncementSummary:  TOTAL PLAY COUNT FOR SEGMENT ID:", $segid, " SLOT:", $slot,  " IS ", $array[6], " \n");		
					last;	
				}	
			} 	
		}
	}
    return $result;
}

##################################################################################
# purpose: Save and restore the NVS param file.
# Parameters    : resolved gsx, nvs parm filename, flag
# Return Values : 	0 if file is not copied 
#				1 if file is copied
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::modifyNvsparm(<gsx, file, saveorrestore>)

 Routine to retrieve Status Count of a Segment ID .  

=over

=item Arguments

  gsx 	- reference
  filename 	- scalar(string)
  saveorrestore- flag to write into or read from

=item Return

  0 if file is not copied 
  1 if file is copied

=item Example(s):

  &$gsxObj->modifyNvsparm($gsx1, "example", 1);

=back

=cut

sub modifyNvsparm()
{
	my($self, $gsx, $file, $saveorrestore)=@_;
	my $flag = 0;
	my $cmd = "";     
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". modifyNvsparm");
	$logger->info(__PACKAGE__ . ".modifyNvsparm  moving files......... \n");
     	my $dsiobj = SonusQA::DSI->new(
                                        -OBJ_HOST => $gsx->{'NFS'}->{'1'}->{'IP'},
                                        -OBJ_USER => $self->{NFSUSERID},
                                        -OBJ_PASSWORD => $self->{NFSPASSWD},
                                        -OBJ_COMMTYPE => "SSH",
                                        );
	if($saveorrestore){
		$cmd = "/usr/bin/cp"." ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/param/"."gsxrestore.prm"." ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/param/"."$file";
	}else{
		$cmd = "/usr/bin/cp"." ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/param/"."$file"." ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/param/"."gsxrestore.prm";
	}
	$logger->info($testcase->{TESTCASE_ID} . ".main $cmd ");
	if($dsiobj->execCmd($cmd)){
		$flag = 1;
	}
	return $flag;
}

##################################################################################
#
#purpose: Verify if Bandwidth for NIF is 0
#Parameters    : slot
#Return Values :  0 if bw is not equal to 0
#			 1 if bw is equal to 0
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::verifyBwusage(<slot>)

 Routine to retrieve Status Count of a Segment ID .  

=over

=item Arguments

  slot 	- scalar

=item Return

  0 if bandwidth is 0 
  1 if bandwidth is not 0

=item Example(s):

  &$gsxObj->verifyBwusage(3);

=back

=cut

sub verifyBwusage() {
    my($self, $slot)=@_;
    my @nifnames = ();
    my $flag = 1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyBwusage");
    $logger->info(__PACKAGE__ . ".verifyBwusage   Retrieving NIFs from slot $slot"); 
    @nifnames = $self->getNIFs(1,$slot);
    foreach(@nifnames){
    		$logger->info(__PACKAGE__ .  ".verifyBwusage Retrieving NIFs Bandwidth \n");
    		$self->getNIFstatusvalues($_);
		$logger->info(__PACKAGE__ . ".verifyBwusage Verifying BW information \n"); 
		if($self->{$_}->{'CURBW'} ne "0"){
			$flag = 0;
          		$logger->info(__PACKAGE__ . ".verifyBwusage .. Bandwidth for $_ is $self->{$_}->{'CURBW'} \n");
		}
    }    
    return $flag;
}

######################################################################################
# purpose: 	Retrieve the memory usage for given slot
# Parameters: Slot
# Return Value: Total memory used in byte
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getmemusage(<slot>)

 Routine to retrieve total memory usage from a card slot (or) total memory usage  

=over

=item Arguments

  Slot 	- PNS40 Slot Number

=item Return

  Total memory in use

=item Example(s):

  $memusage = $gsxObj->getmemusage($pnsslot), $memusage = $gsxObj->getmemusage()

=back

=cut

sub getmemusage() {
	my	($self, $slot)=@_;
	my	$memusage	= 0;
	my $cmd ="";

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getmemusage");
	$logger->info(__PACKAGE__ . ".getmemusage   Retrieve Memory Usage ");
	$self->execCmd("admin debugSonus");
	if(defined($slot)){
		$cmd = "memusage slot $slot all";
	}else {
		$cmd = "memusage all";		 
	}
	if ($self->execCmd($cmd))	{
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			if ($#array >= 4)		{
				my $string = $array[0]." ".$array[1]." ".$array[2]." ".$array[3]; # concatenate first 4 words into a string
				if ($string eq "Total size in use:")		{
					$memusage = $array[4];	
				$logger->info(__PACKAGE__ . ".getmemusage:   ", $string,  $memusage," Bytes\n");					
				}
			}
		} 
	}
    return $memusage;
}

######################################################################################
# purpose: 	Retrieve the CPU usage for given slot
# Parameters: Slot
# Return Value: % of the CPU Availability
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getcpuusage(<slot>)

 Routine to retrieve total CPU usage from a card slot (or) total cpu usage   

=over

=item Arguments

  Slot 	- PNS40 Slot Number

=item Return

  Total % of the CPU available

=item Example(s):

  $cpuusage = $gsxObj->getcpuusage($pnsslot), $cpuusage = $gsxObj->getcpuusage()

=back

=cut

sub getcpuusage() {
	my	($self, $slot)=@_;
	my	$cpuusage	= 0;
	my $cmd = "";

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getcpuusage");
	$logger->info(__PACKAGE__ . ".getcpuusage   Retrieve CPU Usage \n");
	$self->execCmd("admin debugSonus");

      if(defined($slot)){
		$cmd = "cpuusage slot $slot all";
	}else {
		$cmd = "cpuusage all";		 
	}
	if ($self->execCmd($cmd))	{
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			if ($#array >= 2)		{
				if ($array[0] eq "IDLE:Invld")		{
					$cpuusage = $array[2];	
					$logger->info(__PACKAGE__ . ".getcpuusage:   Available CPU : ", $cpuusage,"%  \n");			
				}
			}
		} 
	}
    return $cpuusage;
}

######################################################################################
# purpose: 		Verify Tone Resource Usage
# Parameters: 	Slot
# Return Value: 	0 if resource is not release/failure
#					1 if resource is 0
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::verifyToneResourceUsage(<slot>)

 Routine to retrieve the status of the PAD resource from a card slot.  

=over

=item Arguments

  Slot 	- CNS30 Slot Number

=item Return

 	0 if resource is not release/failure
	1 if resource is 0

=item Example(s):

  $toneusage = $gsxObj->verifyToneResouceUsage($cnsslot);

=back

=cut

sub verifyToneResourceUsage() {
	my	($self, $slot)=@_;
	my	$toneusage	 = 0;
	my	$shelf = 1;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyToneResourceUsage");
	$logger->info(__PACKAGE__ . ".verifyToneResourceUsage:   Verify Resource Pad Usage \n");
	if($self->execFuncCall('showResourcePadShelfSlotStatus', {'resource pad shelf' => $shelf, 'slot' => $slot} )) 	{
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			if ($#array >= 3)		{
				if ($array[0] eq "Tone:")	{
					if ($array[2] == 0)	{
						if ($array[3] == 0	)	{
							$toneusage	 = 1;
							last;
						} else {
							$logger->info(__PACKAGE__ . ".verifyToneResourceUsage:   Allocation Failures = ", $array[3], "%  \n");
						}
					} else {
						$logger->info(__PACKAGE__ . ".verifyToneResourceUsage:   Utilization = ", $array[2], "%  \n");
					}
					$logger->info(__PACKAGE__ . ".verifyToneResourceUsage:   DSP Resource Status: Utilitzation = ",$array[2],", Allocation Failures = ",$array[3], " \n");
				}
			}
		}
	}
    return $toneusage;
}


######################################################################################
# purpose: Configure Rate parameters for the given overload profile
# Parameters: name, setcallrate, clearcallrate, setduration, clearduration
# Return Value: 1 if successful 0 otherwise
######################################################################################

=pod

=head1 SonusQA::GSX::GSXHELPER::configOverloadProfrate(<profilename, setcallrate , clearcallrate, setduration, clearduration>)

 Routine to configure overload profile.  

=over

=item Arguments

  profilename 	- scalar(string)
  setcallrate    - scalar
  clearcallrate  - scalar
  setduration    - scalar  
  clearduration  - scalar 

=item Return

  flag 1 if successful 0 otherwise

=item Example(s):

  $gsxObj->configOverloadProfrate("defaultMC1", 5, 3, 1, 10);

=back

=cut

sub configOverloadProfrate() {
   my($self, $name, $setcallrate, $clcallrate, $setduration, $clduration)=@_;
   my $flag = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". configOverloadProfrate");
    $logger->info(__PACKAGE__ . ".configOverloadProfrate   Configuring Overload Profile $name ");
    $self->execFuncCall('configureOverloadProfileState',{'overload profile' => $name, 'sonusOverloadProfileAdminState' => "disabled"});
    $self->execFuncCall('configureOverloadProfileThreshold',{'overload profile' => $name, 'sonusOverloadProfileCallRateSetThreshold' => $setcallrate, 'sonusOverloadProfileCallRateClearThreshold' => $clcallrate});
    $self->execFuncCall('configureOverloadProfileDuration',{'overload profile' => $name, 'sonusOverloadProfileCallRateSetDuration' => $setduration, 'sonusOverloadProfileCallRateClearDuration' => $clduration});
    if ($self->execFuncCall('configureOverloadProfileState',{'overload profile' => $name, 'sonusOverloadProfileAdminState' => "enabled"})){
	      $flag = 1;
    }
    return $flag;
}

######################################################################################
# purpose: 	Retrieve the Total Use Count for a given Segment ID
# Parameters: Shelf, Slot and Segment ID
# Return Value: Total Use Count
######################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getAnnouncementStatus(<shelf, slot, segid>)

 Routine to retrieve Status Count of a Segment ID .  

=over

=item Arguments

  Shelf 	- 1 <Scalar>
  Slot 	- CSN Slot Number
  Segment ID - Announcement file that is used to play accouncement

=item Return

  Total Play Count

=item Example(s):

  $gsxObj->getAnnouncementStatus($shelf, $slot, $segid);

=back

=cut

sub getAnnouncementStatus() {
	my	($self, $shelf, $slot, $segid, $content)=@_;
	my	$result	=0;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getAnnouncementStatus");
	$logger->info(__PACKAGE__ . ".getAnnouncementStatus:  Retrieve Announcement Status Report ");
	if($self->execFuncCall('showAnnouncementSegmentShelfSlotStatus', {'shelf' => $shelf, 'slot' => $slot, 'announcement segment' => $segid,} )) 	{
		foreach(@{$self->{CMDRESULTS}})	{
			my @array 	= split;
			if ($#array >= 3)		{
				my $string = $array[0]." ".$array[1]." ".$array[2]; # concatenate first 3 words into a string
				if ($string eq $content)		{
					$result = $array[3];	
					$logger->info(__PACKAGE__ . ".getAnnouncementStatus:  ",$content," FOR SEGMENT ID:",$segid," SLOT:",$slot," IS ",$result," \n");						
				}
			}
		} 
	}
    return $result;
}

##################################################################################
# purpose: Retrieve the value from the CMDRESULTS.
# Parameters    : element
# Return Values : content of the element
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getElementValue(<element>)

 Routine to retrieve content of the element.  

=over

=item Arguments

  Content - Element String of the element

=item Return

  Content of the element

=item Example(s):

  $result = $gsxObj->getElementValue("Trunk Group Type");

=back

=cut

sub getElementValue()
{
	my($self,$element)=@_;
	my $content = 0;
	my @words = split (" ",$element);
	my $wsize = $#words;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getElementValue");
	$logger->debug(__PACKAGE__ . ".getElementValue:  Retrieve Value for $element \n");

	foreach(@{$self->{CMDRESULTS}})	{
		$logger->debug(__PACKAGE__ . ".verifyElement:  $_ \n");
		my @array 	= split;
		my $column = 0;
		if ($#array >= ($wsize+1))		{
			my $string = $array[0];
			for ($column = 1; $column <= $wsize; $column++)	{
				$string = $string." ".$array[$column];
			}
			if ($string eq $element)	{
				$content = $array[$wsize+1];	
				$logger->debug(__PACKAGE__ . ".getElementValue:  THE VALUE FOR ",$element," IS ",$content," \n");			
				last;		
			}
		}
	} 	     
	return $content;
}

##################################################################################
#
# purpose: Retrieve GSX Trunk Group Bandwidth Status
# Parameters    : None
# Return Values : bool
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getTGbandwidth()

 Routine to retrieve GSX Trunk Group Bandwidth Status  

=over

=item Arguments

  Content - none

=item Return

  bool

=item Example(s):

  $gsxObj->getTGbandwidth();

=back

=cut

sub getTGbandwidth() {
	my($self, $shelf)=@_;
	my(@results,$inventory, $bFlag);
	$bFlag = 0;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getTGbandwidth");
	$logger->info(__PACKAGE__ . ".getTGbandwidth   Retrieving GSX Trunk Group Bandwidth Status");
	if($self->execFuncCall('showTrunkGroupBandwidthAllStatus')) {
		foreach(@{$self->{CMDRESULTS}}){
			if(m/^(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)/){
				$logger->debug(__PACKAGE__ . ".getTGbandwidth   Item: $_");
              $self->{'tg'}->{$1}->{'bwalloc'} 		= $2;
              $self->{'tg'}->{$1}->{'callalloc'} 	= $3;
              $self->{'tg'}->{$1}->{'bwlimit'} 		= $4;
              $self->{'tg'}->{$1}->{'bwavail'} 		= $5;
              $self->{'tg'}->{$1}->{'inboundbw'} 	= $6;
              $self->{'tg'}->{$1}->{'outboundbw'} 	= $7;
          }	
		}
	}
	return $bFlag;
}

##################################################################################
#
# purpose: Retrieve GSX Redundancy Group information
# Parameters    : Redundancy Group Name
# Return Values : bool
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getRedgroupinfo()

 Routine to Retrieve GSX Redundancy Group information  

=over

=item Arguments

  redundancygroup -scalar (string)

=item Return

  none

=item Example(s):

  $gsxObj->getRedgroupinfo("MNS20-1");

=back

=cut

sub getRedgroupinfo() {
	my($self, $redgroup)=@_;
	my(@arr,$lastline, $i,$numofclients);
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getRedgroupinfo");
	$logger->info(__PACKAGE__ . ".getRedgroupinfo   Retrieving $redgroup state");

	$self->execFuncCall('showRedundancyGroupStatus', {'redundancy group' => $redgroup} );
	$self->{$redgroup}->{'redslot'} 		= $self->getElementValue("Redundant Slot:");
	$self->{$redgroup}->{'redslotstate'} 	= $self->getElementValue("Redundant Slot State:");
	$self->{$redgroup}->{'syncclients'} 		= $numofclients = $self->getElementValue("Number of Synced Clients:");
	$self->{$redgroup}->{'swreason'} 		= $self->getElementValue("Last Switchover Reason:");
	$logger->debug(__PACKAGE__ .  ".getRedgroupinfo    $#{$self->{CMDRESULTS}} \n");
   	
	$numofclients = 0;
      foreach(@{$self->{CMDRESULTS}}){
		if(m/(\d+)\s+(\w+)\s+/){
				$numofclients++;
		}
	}

	$self->{$redgroup}->{'clients'} = $numofclients;

	for($i=0; $i < $numofclients; $i++){ 
		$lastline = ${$self->{CMDRESULTS}}[$#{$self->{CMDRESULTS}} - $i];
		@arr =split(' ', $lastline);
		$self->{$redgroup}->{$numofclients-$i}->{'clentslot'} 			= $arr[0];
		$self->{$redgroup}->{$numofclients-$i}->{$arr[0]}->{'clentstate'} 	= $arr[1];
		$logger->info(__PACKAGE__ . ".getRedgroupinfo .....$arr[0] ......$arr[1]...");
	}
}

##################################################################################
# purpose: Retrieve the value from the CMDRESULTS.
# Parameters    : Service Group, Trunk Group Name
# Return Values : Service Name
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getServiceName(<servicegroup, trunkgroup)

 Routine to retrieve Service Group Name for a given Trunk Group Name.  

=over

=item Arguments

  Content - String of the Service Group 
			- String of the Trunk Group Name

=item Return

  Service Name

=item Example(s):

  $servicegroupname = $gsxObj->getServiceName("SIP", "TrunkGroupName");

=back

=cut

sub getServiceName()		{
	my($self,$servicegroup, $trunkgroup)=@_;
	my $content = 0;
	my $i = 0;
	my $TgName = "Trunk Group :";
	my $servicegroupname = $servicegroup." Service :";
	my @words = split (" ",$servicegroupname);
	my $wsize = $#words;
	my $servicename	= "";
	my $nil = "";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getServiceName");
	$logger->debug(__PACKAGE__ . ".getServiceName:  Retrieve $servicegroup Service Name for $trunkgroup \n");
	
	my $tgfound = 0;
	foreach(@{$self->{CMDRESULTS}})	{ 	
		$i++;
		$logger->debug(__PACKAGE__ . ".$i  getServiceName:  $_ \n");
		my @array 	= split;			
		my $column = 0;
		if ($#array >= ($wsize+1))		{
			my $string = $array[0];
			for ($column = 1; $column <= $wsize; $column++)	{
				$string = $string." ".$array[$column];
			}
			
			if ($string eq $servicegroupname)		{
				$servicename = $array[$wsize+1];
				$logger->debug(__PACKAGE__ . ".getServiceName:   SERVICE NAME: ",$servicename, " \n");	
			}
			if (($string eq $TgName) and ($array[$wsize+1] eq $trunkgroup)) {		
				$logger->debug(__PACKAGE__ . ".getServiceName:   TRUNK GROUP: ",$trunkgroup," IS ",$servicename," \n");		
				$tgfound = 1;	
				last;	
			}
		}
	} 	
	if ($tgfound == 1) 	{     
		return $servicename;
	}	else {
		return $nil
	}
}


##################################################################################
# purpose: Retrieve  Resource Pad summary
# Parameters    : shelf
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getRPADSummary(<shelf>)

 Routine to retrieve Resource pad summary.  

=over

=item Arguments

  Content -Scalar( shelf number)

=item Return

 None

=item Example(s):

 $gsxObj->getRPADSummary(1);

=back

=cut

sub getRPADSummary()		{
    my($self, $shelf)=@_;
    my $mycics = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getRPADSummary");
    $logger->info(__PACKAGE__ . ".getRPADSummary   Retrieving Resource PAD summary");
    if($self->execFuncCall('showResourcePadShelfSummary',{'resource pad shelf'=> $shelf})){
      foreach(@{$self->{CMDRESULTS}}){
      	if(m/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/){
			$self->{'dsp'}->{$1}->{'G711'}->{'util'} = $3;
			$self->{'dsp'}->{$1}->{'G711'}->{'fail'} = $4;
			$self->{'dsp'}->{$1}->{'HDLC'}->{'util'} = $6;
			$self->{'dsp'}->{$1}->{'HDLC'}->{'fail'} = $7;
			$self->{'dsp'}->{$1}->{'TONE'}->{'util'} = $9;
			$self->{'dsp'}->{$1}->{'TONE'}->{'fail'} = $10;
			$self->{'dsp'}->{$1}->{'CONF'}->{'util'} = $12;
			$self->{'dsp'}->{$1}->{'CONF'}->{'fail'} = $13;
			$self->{'dsp'}->{$1}->{'COMP'}->{'util'} = $15;
			$self->{'dsp'}->{$1}->{'COMP'}->{'fail'} = $16;
		} 
      }
    }
}


##################################################################################
# purpose: Retrieve  Redundancy group  Name
# Parameters    : shelf
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getRedungroupName(<shelf>)

 Routine to get Redundancy group  Name.  

=over

=item Arguments

  Content -Scalar(hardware type)

=item Return

 scalar -redindancy group name (string)

=item Example(s):

 $gsxObj->getRedungroupName("CNS");

=back

=cut

sub getRedungroupName(){
    my($self, $type)=@_;
    my @arr =();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getRedungroupName");
    $logger->info(__PACKAGE__ . ".getRedungroupName   Retrieving Redundancy summary");
    if($self->execFuncCall('showRedundancyGroupSummary')){
      foreach(@{$self->{CMDRESULTS}}){
		$logger->debug(__PACKAGE__ . ".getRedungroupName $_");
      	if(m/$type/){
			@arr = split;
		} 
      }
    }
    return $arr[0];
}


##################################################################################
# purpose: Configure  Redundancy group  Clients
# Parameters    : CNS card type or "all"
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::configCNSRedunclients(<shelf>)

 Routine to Configure  Redundancy group Clients .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 None

=item Example(s):

 $gsxObj->configCNSRedunclients("all");

=back

=cut


sub configCNSRedunclients() {
    my($self, $type)=@_;
    my $server = my $redunserver = my $redgroup = "";
    my $i = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".configCNSRedunclients");
    $logger->info(__PACKAGE__ . ".configCNSRedunclients   Retrieving NIF Admin Information"); 
    if ($type eq "all"){
		$server  = "CNS";
    }else{
		$server = $type;
    }	
	$self->getHWInventory(1);
    	for ($i = 3; $i <= 16; $i++) {
		if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/CNA0/ ) {
	      	if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/$server/){
				$redunserver = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};
				$redgroup = $self->getRedungroupName($redunserver);
				my $j = 0;
    				for($j = 3; $j < $i; $j++) {
					if($self -> {'hw'} -> {'1'} -> {$j} -> {'SERVER'} eq "$redunserver" ){
						$logger->debug(__PACKAGE__ . ".configCNSRedunclients $j");
						$self->execFuncCall("createRedundancyClientGroupSlot",{'redundancy client group' => $redgroup, 'slot' => $j});
						$self->execFuncCall("configureRedundancyClientGroupSlotState",{'redundancy client group' => $redgroup, 'slot' => $j, 'sonusRedundClientAdmnState' => "enabled"});
					}
				}
				$self->execFuncCall("configureRedundancyGroupState",{'redundancy group' => $redgroup, 'sonusRedundGroupAdmnState' => "enabled"});									
			}
		}
	}

}


##################################################################################
# purpose: Get the slot number and type of card in the slot 
# Parameters    : CNS, PNS or all
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getSlotinfo(<cardtype>)

 Routine to Configure  Redundancy group Clients .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Hash

=item Example(s):

 $gsxObj->getSlotinfo("ALL");

=back

=cut


sub getSlotinfo () {
	my($self, $type)=@_;
	my $i = 0; 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getSlotinfo");
	my @types = ();
	if($type eq "ALL"){
		$type = "[A-Z]";
	}
	$self->getHWInventory(1);
	for ($i = 3; $i <= 16; $i++) {

		my $server = $self->{'hw'} -> {'1'} -> {$i} -> {'SERVER'};
	  	my $adapter = $self->{'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'};
 		
      	if ($server ne "UNKNOWN" && $server =~m/$type/){
			if ($server =~m/SPS/){
				$adapter = "NONE";
			}
			if ($adapter !~ m/CNA0/ && $adapter !~ m/UNKNOWN/) {
          			$logger->info(__PACKAGE__ . ".getSlotinfo server $server and adapter $adapter CARD FOUND IN SLOT $i");
		  		push @types, ($i => [$server, $adapter]);
        		} 
      	}
    	}
	return @types;
}

=pod

=head1 SonusQA::GSX::GSXHELPER::getServerFunction(<slot>)

 Routine to get the configured Server Function value from a Show Screen.  

=over

=item Arguments		

 Content: Scalar(slot number) 

=item Return

 Values: "E1" or "T1"

=item Example(s):

 $self->getServerFunction(-slot => $slot);

=back

=cut

sub getServerFunction() {
    my($self, %args)=@_;
    my(@results,$inventory, $slotType, %a);
    $slotType = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getServerFunction");
    $logger->info(__PACKAGE__ . ".getServerFunction   Retrieving a Slots Server Function");
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    if (!defined $a{-slot}) {
        $logger->warn(__PACKAGE__ . ".getServerFunction slot NOT set");
        return $slotType;
    }
     
    if($self->execCmd("show server shelf 1 slot $a{-slot} admin")) {

      foreach(@{$self->{CMDRESULTS}}){
          if($_ =~ /Server Function/){	
              chomp($_);	
              ($0,$slotType) = split(/\:/,$_,2);
          }
      }
    }
    
    $slotType = trim($slotType);
    $logger->info(__PACKAGE__ . ".getServerFunction   Returning: $slotType");
    return $slotType;
}

=pod

=head1 SonusQA::GSX::GSXHELPER::getOpticalPayload(<slot>)

 Routine to get the Optical Paylod Map value from a Show Screen.  

=over

=item Arguments		

 Content: Scalar(slot number)  

=item Return

 Values: "E1" or "T1"

=item Example(s):

 $self->getOpticalPayload(-slot => $slot);

=back

=cut

sub getOpticalPayload() {
    my($self, %args)=@_;
    my(@results,$inventory, $payloadType, %a);
    $payloadType = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getOpticalPayload");
    $logger->info(__PACKAGE__ . ".getOpticalPayload   Retrieving Optical Payload");
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    if (!defined $a{-slot}) {
        $logger->warn(__PACKAGE__ . ".getOpticalPayload  slot NOT set");
        return $payloadType;
    }
     
    if($self->execCmd("show optical interface opt$a{-slot} line upper admin")) {

      foreach(@{$self->{CMDRESULTS}}){
          if($_ =~ /Payload Mapping/){	
              $logger->info(__PACKAGE__ . ".getOpticalPayload  $_");
              chomp($_);	
              ($0,$payloadType) = split(/\:/,$_,2);
          }
      }
    }
    
    $payloadType = trim($payloadType);
    $logger->info(__PACKAGE__ . ".getOpticalPayload   Returning: $payloadType");
    return $payloadType;
}

##################################################################################
# purpose: Get the type of interface from the  adapter
# Parameters    : Adapter
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getInterfaceFromAdapter(<cardtype> <adapter>)

 Routine to Configure  Redundancy group Clients .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getInterfaceFromAdapter(1,"CNA30",$slot);

=back

=cut

sub getInterfaceFromAdapter () {
 my ($self, $shelf,$adapter,$slot)=@_;
 my @InterfaceType;
 my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getInterfaceFromAdapter");

 if (!defined $adapter) {
    $logger->warn(__PACKAGE__ . ".getInterfaceFromAdapter  $adapter NOT set");
 }
	         
 switch ($adapter) 	{
                                     #Span Min, Max, Port, Channels
	  case "GNA15"	{ @InterfaceType = ("T1", 1, 12, 1, 24); }
	  case "GNA10"	{ @InterfaceType = ("T1", 1, 12, 1, 24); }
	  case "CNA10"	{ @InterfaceType = ("T1", 1, 12, 1, 24); }
	  case "CNA20"  { @InterfaceType = ("E1", 1,  8, 1, 31); }
	  case "CNA25"  { @InterfaceType = ("E1", 1, 12, 1, 31); }
	  case "CNA30"	{ @InterfaceType = ("T3", 1, 28, 1, 24); }
	  case "CNA31"	{ @InterfaceType = ("T3", 1, 28, 1, 24); }
	  case "CNA21"  { @InterfaceType = ("E1", 1, 12, 1, 31); }
	  case "CNA40"	{ 
	      if (!defined $slot) {
	          $logger->warn(__PACKAGE__ . ".getInterfaceFromAdapter  slot NOT set");
	      }
	      
	      # CNA40 Can be configured as either T1 or E1
	      my $port_type = $self->getServerFunction(-slot => $slot);
	      if ($port_type eq "T1") {
	          @InterfaceType = ("T3", 1, 36, 1, 24); 
	      }
	      elsif ($port_type eq "E1") {
	          @InterfaceType = ("E1", 1, 36, 1, 31);
	      } 
	      else {
	          $logger->warn(__PACKAGE__ . ".getInterfaceFromAdapter  port_type NOT set");
	      }
	  }
	  
	  case "CNA60"	{ @InterfaceType = ("T3", 1, 28, 3, 24); }
	  case ["CNA70","CNA81"]	{ 
          # Determine if Optical Interface configured as T1 or E1       
          my $payload = $self->getOpticalPayload(-slot => $slot);
          switch ( $payload ) {
              case ["DS3ASYNC", "STFRAME", "T1BITASYNC"] {
                  @InterfaceType = ("T1",1, 84, 1, 24);                   
              }
              case "E1BITASYNC" {
                  @InterfaceType = ("E1",1, 63, 1, 31); 
              }
              else {
                  $logger->warn(__PACKAGE__ . ".getInterfaceFromAdapter  Optical port NOT set, payload was : $payload");
              }
          }
	  }
	  
	  case "CNA80"	{ @InterfaceType = ("T3",1, 28, 3, 24); }
	  
	  else { 
	      $logger->debug(__PACKAGE__ . ".getInterfaceFromAdapter  $adapter CARD NOT FOUND"); 
	  }
	}
  return @InterfaceType;
}


##################################################################################
# purpose: Get the get number of circuits based on adapter slot number
# Parameters    : Adapter
# Return Values : None
#				
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getAdapterCircuitNr(<slot>))

 Routine to calculate maximum number of circuits or channels available
 on a specified CNA card.  

=over

=item Arguments

  Content -Scalar(String)   e.g. "CNA10"			

=item Return

 Decimal Value: 0, 200 

=item Example(s):

 $gsxObj->getAdapterCircuitNr("CNA10");

=back

=cut

sub  getAdapterCircuitNr() {

  my($self,$adapter)=@_;
  my $i = 0; 
  my $j = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getAdapterCircuitNr");
  my $circuits = 0;
  my @interface;

  $logger->info(__PACKAGE__ . ".getAdapterCircuitNr on card: $adapter");
  
  # Check MANDATORY Argument
  if (!defined $adapter) {
    $logger->warn(__PACKAGE__ . ".getAdapterCircuitNr  \$adapter NOT set");
    return $circuits;
  }
   
  @interface = $self->getInterfaceFromAdapter(1,$adapter,0);
  
  for ($i = 0; $i < $interface[1]; $i++) {
   for ($j = 0; $j < $interface[2]; $j++) {
     # Number of circuits differ on T1 and E1 ports, use value obtained from $interface  
	 $circuits = $circuits + $interface[4];
   }
  }
  $logger->debug(__PACKAGE__ . ".getAdapterCircuitNr number of circuits $circuits");
  return $circuits; 
}


##################################################################################
# purpose:
# Parameters    : 
# Return Values : 
#				
##################################################################################
=pod

=head1 sourceGsxTclFile()

 Executes a tcl file in the gsx and checks for a completion string "SUCCESS".If string is present ,then this subroutine returns 1.For this method to return 1 on successful completion , include (puts "SUCCESS") at the end of the tcl script which u need to execute and remove the word "SUCCESS" if present in other parts of the tcl file.

Assumption :

 It is assumed that NFS is mounted on the machine from where this method is invoked.

Arguments :

 -tcl_file
    name of the tcl file
 -location
   directory location where the tcl file is present
 -gsx_hostname
   specify the hostname of the gsx
 -nfs_mount
   specify the NFS mount directory -default is /sonus/SonusNFS

Return Values :

 1 - success ,when tcl file is executed without errors and end tag "SUCCESS" is reached
 0 - failure , error occurs during execution or inputs are not specified or copy of file failed

Example :

 \$obj->SonusQA::GSX::GSXHELPER::sourceGsxTclFile(-tcl_file => "ansi_cs.tcl",-location => "/userhome/ats/feature/gsx_files",-gsx_hostname => "VIPER");

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub sourceGsxTclFile() {

    my($self,%args) = @_;
    my $sub = "sourceGsxTclFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $tcl_file = $args{-tcl_file};
    my $location = $args{-location};
    my $gsx = uc($args{-gsx_hostname});

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount (defined in GSXHELPER.pm::".__PACKAGE__ . ") does not exist");
        return 0;
    }

    # Error if tcl_file is not set
    unless (defined $tcl_file && $tcl_file !~ /^\s*$/ ) {
        
        $logger->error(__PACKAGE__ . ".$sub tcl file is not specified or is blank");
        return 0;
    }

    # Error if location is not specified
    unless (defined $location && $location !~ /^\s*$/ ) {
 
        $logger->error(__PACKAGE__ . ".$sub location is not specified or is blank");
        return 0;
    }

    # Error if gsx hostname is not specified
    unless (defined $gsx && $gsx !~ /^s*$/ ) {
   
        $logger->error(__PACKAGE__ . ".$sub gsx hostname is not specified or is blank");
        return 0;
    }

    # Set "From path"
    my $from_path = $location . "/" . $tcl_file;
    $logger->debug(__PACKAGE__ . ".$sub From Path is $from_path");

    # Set "To Path" ie NFS
    my $to_path = "$nfs_mount/$gsx/cli/scripts";
    $logger->debug(__PACKAGE__ . ".$sub To Path is $to_path");

    # Copy file from "From Path" to "To Path" 
    if ( system("/bin/cp","-f","$from_path","$to_path")) {

        $logger->error(__PACKAGE__ . ".$sub Copy failed from $from_path to $to_path");
        return 0;
    } 
    else {

        $logger->debug(__PACKAGE__ . ".$sub Copy was successful from $from_path to $to_path");

        my $cmd = "source ../$gsx/cli/scripts/$tcl_file";
        
        # Source the tcl file in gsx
        my $default_timeout = $self->{DEFAULTTIMEOUT};
        $self->{DEFAULTTIMEOUT} = 400;
        my @cmdresults = $self->execCmd($cmd); 
        $self->{DEFAULTTIMEOUT} = $default_timeout;
        $logger->debug(__PACKAGE__ . ".$sub @cmdresults");

        foreach(@cmdresults) {

            chomp($_);
            # Checking for SUCCESS tag
 
            if (m/^SUCCESS/) {
                $logger->debug(__PACKAGE__ . ".$sub CMD RESULT: $_");

                # Remove the tcl file from NFS directory
                if ($location ne "$nfs_mount/$gsx/cli/scripts") {
                    if (system("rm -rf $nfs_mount/$gsx/cli/scripts/$tcl_file")) {
                        $logger->error(__PACKAGE__ . ".$sub Remove failed for $nfs_mount/$gsx/cli/scripts/$tcl_file");
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$sub Removed $tcl_file in $nfs_mount/$gsx/cli/scripts");
                } 
                
                $logger->debug(__PACKAGE__ . ".$sub Successfully sourced GSX TCL file: $tcl_file");
                return 1;
            }
            elsif (m/^error/) {
                unless (m/^error: Unrecognized input \'3\'.  Expected one of: VERSION3 VERSION4/) {
                    $logger->error(__PACKAGE__ . ".$sub Error occurred during execution : $_");
                    return 0;
                }
            }

        } # End foreach 

        # If we get here, script has not been successful
        $logger->error(__PACKAGE__ . ".$sub SUCCESS string not found, nor error string. Unknown failure.");
        return 0;
    }  
}

=pod

=head1 getM3UAGateway()

 Checks the M3UA gateway status in GSX and reports on the status of host specified.This functions is only for M3UA links and will not work for Client Server connections.

=over 

=item Arguments :

 -sgx_hostname
     specify sgx hostname for which we need to check m3ua status

=item Return Values :

 State of the Host - Host specified is found in the command result and state is returned 
 0 - Failure ,no hostname specified or command execution returns no gateway or if specified host is not found in command result

=item Example :

 \$obj->SonusQA::GSX::GSXHELPER::getM3UAGateway(-sgx_hostname => "calvin");

=item Notes:
 Executes "SHOW SS7 GATEWAY ALL STATUS" and checks for state for specified hostname.

=item Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getM3UAGateway() {

    my ($self,%args) = @_;
    my $sub = "getM3UAGateway()";
    my $cmd = 'SHOW SS7 GATEWAY ALL STATUS';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $sgx_hostname = $args{-sgx_hostname};
    
    # Error if sgx hostname not set 
    if (!defined $sgx_hostname) {
        $logger->error(__PACKAGE__ . ".$sub Hostname is not specified");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Retrieving GSX SS7 Gateway ALL status");

    # Execute TCL command on GSX 
    if ($self->execCmd($cmd)) {
      
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);
            # Error if error string returned  
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                return 0;
            }
         
            # Match sgx hostname name from gateway status output from GSX 
            if ($_ =~ m/.*($sgx_hostname)\s+(\d+).(\d+)\s(\d+).(\d+)\s(\d+).(\d+).(\d+).(\d+)\s+(\w+)/i) {

                $logger->debug(__PACKAGE__ . ".$sub State of Host $1 is $10");
       
                my $state = $10;     
                # Return current status of host 
                return $state;
            } 
        } # End foreach
        $logger->error(__PACKAGE__ . ".$sub Host specified $sgx_hostname is not found in CMD RESULT");
        return 0;
    } 
} # End sub getM3UAGateway

=pod

=head1 checkM3UAGateway()

 Checks if M3UAGateway is in specified state and returns 1 if state matches.

Arguments :

 -sgx_hostname
 -state
  specify state of the association - example - ASPUP

Return Values :

 1 - Success
 0 - Failure

Example :
 \$obj->SonusQA::GSX::GSXHELPER::checkM3UAGateway(-sgx_hostname => "calvin",-state => "ASPUP");

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub checkM3UAGateway {
    my($self,%args) = @_;
    my $sub = "checkM3UAGateway()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $sgx_hostname = undef;
    my $state = undef;

    $sgx_hostname = $args{-sgx_hostname};
    $state = $args{-state};

    # Error if sgx hostname not set
    if (!defined $sgx_hostname) {
        $logger->error(__PACKAGE__ . ".$sub Hostname is not specified");
        return 0;
    } 

    # Error if state not set
    if (!defined $state) {
        $logger->error(__PACKAGE__ . ".$sub State is not specified");
        return 0;
    } 

    my $result = $self->SonusQA::GSX::GSXHELPER::getM3UAGateway(-sgx_hostname => $sgx_hostname, -state => $state);
  
    if ($result =~ /$state/) {
        $logger->debug(__PACKAGE__ . ".$sub Host $sgx_hostname is in specified state $state");
        return 1;
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Host $sgx_hostname is not in specified state $state");
        return 0;
    } # End if

} # End sub checkM3UAGateway

=pod

=head1 getSS7GatewayLink()

 Checks the link status and mode for the specified ip address in "SHOW SS7 NODE <specified node name> STATUS" and returns the link state and mode.This function is for Client Server connections to the SGX and will not work for M3UA links.

=over 

=item Arguments :

 -sgx_ip
     specify the sgx ip address for which we need to check the link status
 -node_name
     specify the node name (example - a7n1)

=item Return Values :

 State  and mode of the Link for  Host specified is found in the command result - Success
 0 - Failure ,no ip specified or no node name specified or command execution returns no node status or if specified host is not found in command result

=item Example :

  \$obj->SonusQA::GSX::GSXHELPER::getSS7GatewayLink(-sgx_ip => "10.31.240.7",-node_name => "a7n1");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getSS7GatewayLink() {
    my($self,%args) = @_;
    my $sub = "getSS7GatewayLink()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @retvalues;

    my $node = $args{-node_name};
    my $sgx_ip = $args{-sgx_ip}; 

    # Error if sgx ip not set
    unless ($sgx_ip) {
        $logger->error(__PACKAGE__ . ".$sub SGX ip is not specified");
        return 0;
    }
   
    # Error if node name not set
    unless ($node) {
        $logger->error(__PACKAGE__ . ".$sub Node Name is not specified");
        return 0;
    }
    
    my $cmd = "SHOW SS7 NODE $node STATUS";
    $logger->debug(__PACKAGE__ . ".$sub Retrieving GSX SS7 NODE $node STATUS");

    # Execute TCL command on GSX
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                return 0;
            }

            # Match sgx ip from node status output from GSX
            if ($_ =~ m/.*($sgx_ip)\s+(\w+)\s+(\w+)/) {

                my $state = $2;
                my $mode = $3;
                $logger->debug(__PACKAGE__ . ".$sub Link State of Host $1 is $state");
                $logger->debug(__PACKAGE__ . ".$sub Link mode of Host $1 is $mode");

                # Return current status and mode of host
                push @retvalues,$state;
                push @retvalues,$mode;
                return @retvalues;
            }
        } # End foreach
        $logger->error(__PACKAGE__ . ".$sub Host specified $sgx_ip is not found in CMD RESULT");
        return 0;
    } 
} # End sub getSS7GatewayLink

=pod

=head1 checkSS7GatewayLink()

 This function checks if the state and mode of the SS7 Gateway link is same as that specified.

=over 

=item Arguments :

 -sgx_ip
 -node_name
 -link_state
  specify link state which u need to check for - example - AVAILABLE
 -link_mode
  specify link mode which u need to check for - example - ACTIVE

=item Return Values :

 1 - Success
 0 - Failure

=item Example :

 \$obj->SonusQA::GSX::GSXHELPER::checkSS7GatewayLink(-sgx_ip => "10.31.240.7",-node_name => "a7n1",-link_state => "AVAILABLE",-link_mode => "ACTIVE");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSS7GatewayLink {

    my($self,%args) = @_;
    my $sub = "checkSS7GatewayLink()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $node = undef;
    my $sgx_ip = undef;
    my $link_state = undef;
    my $link_mode = undef;

    $node = $args{-node_name};
    $sgx_ip = $args{-sgx_ip};
    $link_state = $args{-link_state};
    $link_mode = $args{-link_mode};

    # Error if sgx ip not set
    if (!defined $sgx_ip) {
        $logger->error(__PACKAGE__ . ".$sub SGX ip is not specified");
        return 0;
    } 

    # Error if node name not set
    if (!defined $node) {
        $logger->error(__PACKAGE__ . ".$sub Node Name is not specified");
        return 0;
    } 

    # Error if link_state not set
    if (!defined $link_state) {
        $logger->error(__PACKAGE__ . ".$sub Link State is not specified");
        return 0;
    } 

    # Error if link_mode not set
    if (!defined $link_mode) {
        $logger->error(__PACKAGE__ . ".$sub Link Mode is not specified");
        return 0;
    } 

    my @values = $self->SonusQA::GSX::GSXHELPER::getSS7GatewayLink(-sgx_ip => $sgx_ip,-node_name => $node);

    if ($values[0] =~ /$link_state/) {
        $logger->debug(__PACKAGE__ . ".$sub Link state is $link_state");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Link state is not $link_state");
        return 0;
    } # End if

    if ($values[1] =~ /$link_mode/) {
        $logger->debug(__PACKAGE__ . ".$sub Link mode is $link_mode");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Link mode is not $link_mode");
        return 0;
    } # End if
    return 1;

} # End sub checkSS7GatewayLink

=pod

=head1 getSpecifiedIsupServiceState()

 Checks for the status of isup service in gsx and returns the state.

=over 

=item Arguments :

 -service_name

=item Return Values :

 State of the isup service  - Service name specified is found in the command result
 0 - Failure ,no service name specified or command execution returns no status or if specified service is not found in command result

=item Example :

 \$obj->SonusQA::GSX::GSXHELPER::getSpecifiedIsupServiceState(-service_name => "ss71");

=item Notes:

 Executes the command "SHOW ISUP SERVICE <service-name> STATUS" and checks if status is available

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getSpecifiedIsupServiceState {

    my($self,%args) = @_;
    my $sub = "getSpecifiedIsupServiceState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $service = undef;

    $service = $args{-service_name};

    # Error if service_name not set
    if (!defined $service) {

        $logger->error(__PACKAGE__ . ".$sub service name is not specified");
        return 0;
    }
 
    my $cmd = "SHOW ISUP SERVICE $service STATUS";
    $logger->debug(__PACKAGE__ . ".$sub Retrieving GSX ISUP SERVICE $service STATUS");

    # Execute TCL command on GSX
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                return 0;
            } 

            # Match service name in command output from GSX
            if ($_ =~ m/.*($service)\s+(\d+)-(\d+)-(\d+)\s+(\w+)/i) {

                $logger->debug(__PACKAGE__ . ".$sub State of service $1 is $5");
 
                my $state = $5;
                # Return current status of service 
                return $state;
            } 

        } # End foreach
        $logger->error(__PACKAGE__ . ".$sub Service specified $service is not found in CMD RESULT");
        return 0;
    } 
} # End sub getSpecifiedIsupServiceState     

=pod

=head1 checkSpecifiedIsupServiceState()

 Checks if isup service is in the specified state.

=over 

=item Arguments :

 -service_name 
 -state
   specify the state to check for -example : AVAILABLE

=item Return Values :

 1 - Success 
 0 - Failure

=item Example :

 \$obj->SonusQA::GSX::GSXHELPER::checkSpecifiedIsupServiceState(-service_name => "SS71",-state => "AVAILABLE");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSpecifiedIsupServiceState() {

    my($self,%args) = @_;
    my $sub = "checkSpecifiedIsupServiceState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $service = undef;
    my $state = undef;

    $state = uc($args{-state});
    $service = $args{-service_name};

    # Error if service_name not set
    if (!defined $service) {
        $logger->error(__PACKAGE__ . ".$sub service name is not specified");
        return 0;
    } 

    # Error if state not set
    if (!defined $state) {
        $logger->error(__PACKAGE__ . ".$sub state is not specified");
        return 0;
    } 
   
    my $result = $self->SonusQA::GSX::GSXHELPER::getSpecifiedIsupServiceState(-service_name => $service);

    if ($result =~ /$state/) {
        $logger->debug(__PACKAGE__ . ".$sub ISUP Service state is $state");
        return 1;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub ISUP Service state is not $state");
        return 0;
    } # End if
} # End sub checkSpecifiedIsupServiceState

=pod

=head1 cnsIsupSgDebugSetMask()

   This function sets the mask of a cns card using the isupsgdebug command with options -s for slot and -m for mask.
Value 256 for mask stops the card from responding and 0 restores the card to respond.

Arguments :

 -cns_slot
 -mask
    256 - stop the card from responding
    0 - restore the card to continue responding

Return Values :

 1-Success if prompt returned
 0-Failure if error message has been printed on executing the debug command or cns_state not specified or cns_slot not specified or cns_state specified is invalid(other than 0 or 1)

Example :

 \$obj->SonusQA::GSX::GSXHELPER::cnsIsupSgDebugSetMask(-cns_slot => 2,-mask => 0);

Notes :

 Executes the following commands in gsx to stop the card from responding
 %admin debugSonus
 %isupsgdebug -s <cns_slot> -m 256
 Executes the following commands in gsx to restore the card
 %admin debugSonus
 %isupsgdebug -s <cns_slot> -m 0

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub cnsIsupSgDebugSetMask() {

    my($self,%args) = @_;
    my($string);
    my $sub = "cnsIsupSgDebugSetMask()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $cns_slot = undef;
    my $mask = undef;

    $cns_slot = $args{-cns_slot};
    $mask = $args{-mask};

    # Error if cns_slot not set
    if (!defined $cns_slot) {

        $logger->error(__PACKAGE__ . ".$sub cns_slot is not specified");
        return 0;
    }

    # Error if cns_state not set
    if (!defined $mask) {

        $logger->error(__PACKAGE__ . ".$sub mask is not specified");
        return 0;
    }

    # Check for mask value and error if not 256 or 0
    if ($mask !~ /(256|0)/) {
        $logger->error(__PACKAGE__ . ".$sub mask $mask is invalid");
        return 0;
    }
   
    my $cmd = "admin debugSonus";
    $logger->debug(__PACKAGE__ . ".$sub Executing admin debugSonus");

    my @cmdresults = $self->execCmd($cmd);

    foreach(@cmdresults) {

        chomp($_);

        # Error if error string returned
        if (m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            return 0;
        }

    } # End foreach

    # debug command is prepared 
    $cmd = "isupsgdebug -s $cns_slot -m $mask";
    $string = "isupsgdebug command for slot $cns_slot changes state to $mask";
 
    $logger->debug(__PACKAGE__ . ".$sub Executing $cmd");
    
    @cmdresults = $self->execCmd($cmd);
  
    foreach(@cmdresults) {

        chomp($_);

        # Error if error string returned
        if (m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            return 0;
        }

    } # End foreach

    $logger->info(__PACKAGE__ . ".$sub $string"); 
    return 1;
 
} # End sub cnsIsupSgDebugSetMask

=pod

=head1 switchoverGsxSlot()

 This method performs switchover of GSX cards (CNS or MNS) and reverts based on the slot state.The mandatory parameters are red_group and slot.Default value for wait_for_switch is 1,meaning the function will wait for the switchover to get completed and then report on final slot state.But if we want to exit the function immediately after switchover command is issued,we can specify wait_for_switch as 0.We can use the function getProtectedSlotState in the test script to check for the slot state and use this function again to restore the slot state.

Arguments :

 -red_group
    specify the cns/mns redundancy group for which switchover /revert switchover needs to be done
 -slot
    specify the slot number of the card
 -wait_for_switch
    If we need to wait for the switchover to get completed ,then specfify -wait_for_switch => 1, else specify -wait_for_switch => 0.When this flag is 0 , the switchover command will be issued and then subroutine will exit.
 -mode
    If we need to do forced switchover or revert then specify -mode => forced else default will be normal 

Return Values :

 1 -Success if card state is STANDBY after switchover and ACTIVESYNCED after revert if -wait_for_switch => 1.If -wait_for_switch => 0, then return 1 if client state is RESET
 0 -Failure if command execution fails or inputs not specified

Example :

 \$obj->SonusQA::GSX::GSXHELPER::switchoverGsxSlot(-red_group => "cns60",-cns_slot => 2,-wait_for_switch => 1);

Notes :

 "CONFIGURE REDUNDANCY GROUP <redgroup> SWITCHOVER CLIENT SLOT <slot>" command is executed to perform the switchover.Then "SHOW REDUNDANCY GROUP <cns_redgroup> SLOT <cns_slot>" command is used to check the status of the slot.CONFIGURE REDUNDANCY GROUP <redgroup> REVERT FORCED is used to revert the switchover.If it is mns switchover , after issuing the switchover command , we will lose the connection,so we will exit this subroutine.So it is advised to check for status of the slot in the test script which calls this function.

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub switchoverGsxSlot() {

    my($self,%args) = @_;
    my $sub = "switchoverGsxSlot()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd,$mode);
    my $red_group = undef;
    my $slot = undef;
    my $revert;
    my $wait = 1;

    $red_group = $args{-red_group};
    $slot = $args{-slot};
    $wait = $args{-wait_for_switch};
    $mode = $args{-mode};
    
    # Error if red_group is not set
    if (!defined $red_group) {

        $logger->error(__PACKAGE__ . ".$sub redundancy group is not specified");
        return 0;
    }

    # Error if slot is not set or if not in range of 1 to 16
    if (!defined $slot) {
        
        $logger->error(__PACKAGE__ . ".$sub slot is not specified");
        return 0;
    }
    elsif (($slot < 1) || ($slot > 16)) {
        $logger->error(__PACKAGE__ . ".$sub Slot number specified is not in range of 1 to 16");
        return 0;
    }

    # Fetch slot state using getProtectedSlotState
    my $slotstate = $self->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);

    # Set revert flag based on slot state
    if ($slotstate eq "STANDBY") {
        $revert = 1;
        $logger->info(__PACKAGE__ . ".$sub Slot State is STANDBY,so revert will be done");
    }
    elsif ($slotstate eq "ACTIVESYNCED") {
        $revert = 0;
        $logger->info(__PACKAGE__ . ".$sub Slot State is ACTIVESYNCED,so switchover will be done");
    }
    elsif ($slotstate eq "ACTIVENOTSYNCED") {
        $logger->error(__PACKAGE__ . ".$sub Slot State is ACTIVENOTSYNCED,so switchover is not possible");
        return 0;
    }
    elsif ($slotstate eq "RESET") {
        $logger->error(__PACKAGE__ . ".$sub Slot State is RESET,so switchover is not possible");
        return 0;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub Invalid slot state ,so switchover is not possible");
        return 0;
    }

    # Error if wait_for_switch is not specified or if value is not 0 or 1
    if (!defined $wait) {
 
        $logger->error(__PACKAGE__ . ".$sub wait_for_switch is not specified");
        return 0;
    }
    elsif (($wait ne 0) && ($wait ne 1)) {
        $logger->error(__PACKAGE__ . ".$sub Value for wait_for_switch is invalid , set to 0 or 1");
        return 0;
    }

    # Mode value should be either forced or normal 
    if ((!defined $mode) || ($mode ne "forced")) {
        $mode = "normal";
    } 

    # Prepare command to be executed
    if ($revert eq 0) {
        $cmd = "CONFIGURE REDUNDANCY GROUP $red_group SWITCHOVER $mode CLIENT SLOT $slot";
        
        if($self->execCmd($cmd)) {
            foreach(@{$self->{CMDRESULTS}}) {
                
                chomp($_);
                $logger->debug(__PACKAGE__ . ".$sub $_");   
                # Error if error string returned
                if (m/^error/i) {
                    $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                    return 0;
                }
            }  # End foreach    
        } # Endif
        unless ($self->reconnect( -retry_timeout => 180, -conn_timeout  => 10 )) {
                logger->error(__PACKAGE__ . ".$sub : Failed to reconnect to GSX object ");
                return 0;
        }

        if ($wait eq 1) {
            my $timeout = 180;

            while ($timeout >= 0 ) { 
                my $slotstate = $self->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);
                if ($slotstate eq "STANDBY") {
                    $logger->info(__PACKAGE__ . ".$sub State of slot $slot is $slotstate,Switchover was successful");
                    return 1;
                }
                sleep(45);
                $timeout = $timeout - 45;
            } # End while for timeout
    
            $logger->error(__PACKAGE__ . ".$sub Timeout occurred switchover not complete");
            return 0;

        } # End if for wait eq 1
        elsif ($wait eq 0) {

            # Check for status
            my $slotstate = $self->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);
            if ($slotstate eq "RESET") {
                $logger->info(__PACKAGE__ . ".$sub State of slot $slot is $slotstate");
                return 1;
            } 
        } # End if for wait 0
    } # End if for revert eq 0 

    elsif ($revert eq 1) {
    
        $cmd = "CONFIGURE REDUNDANCY GROUP $red_group REVERT $mode";

        if($self->execCmd($cmd)) {
            foreach(@{$self->{CMDRESULTS}}) {

                chomp($_); 
                $logger->debug(__PACKAGE__ . ".$sub $_");
                # Error if error string returned
                if (m/^error/i) {
                    $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                    return 0;
                } 
            } # End foreach
        } 
        unless ($self->reconnect( -retry_timeout => 180, -conn_timeout  => 10 )) {
                logger->error(__PACKAGE__ . ".$sub : Failed to reconnect to GSX object ");
                return 0;
        }
       
        if ($wait eq 1) { 
            my $timeout = 180;

            while ($timeout >= 0) {
                my $slotstate = $self->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);
                if ($slotstate eq "ACTIVESYNCED") {
                    $logger->info(__PACKAGE__ . ".$sub State of slot $slot is $slotstate,Revert was successful");
                    return 1;
                }  
                sleep(45);
                $timeout = $timeout - 45;
            } # End while
            
            $logger->error(__PACKAGE__ . ".$sub Timeout occurred Revert not complete");
            return 0;

        } # End if for wait eq 1
        elsif ($wait eq 0) {
            # Check for status
            sleep(3); # Wait for status change since sometimes it does not happen immediately
            my $slotstate = $self->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);
            if ($slotstate =~ /ACTIVENOTSYNCED/) {
                $logger->info(__PACKAGE__ . ".$sub State of slot $slot is $slotstate");
                return 1;
            } 

        } # End if for wait 0
    }   # End elsif for revert=1

$logger->error(__PACKAGE__ . ".$sub Switchover was not successful");
return 0;

} # End sub switchoverGsxSlot

=pod

=head1 checkCicsState()

 Checks the cic status for the specified cic range and reports success if cics are in specified state and failure if cics are not in specified state.service,cic_start and cic_end are mandatory.

Arguments :

 -service
     specify the isup service name
 -cic_start
     specify the start of the cic range  -example : "2"
 -cic_end
     specify the end of the cic range -example : "13"
 -ckt_state
     specify the status of cic we need to check for in command output - example : "IDLE" 
     specify multiple states as "IDLE|OUT-BUSY"
     choose from IDLE , OUT-BUSY , IN-BUSY , SETUP , RELEASE , IN-CONT, OUT-CONT , UNEQUIP
 -hw_lstate
     specify the local status of hardware we need to check for in command output - example : "UNBLK"
     specify multiple states as "UNBLK|TRN-B"
     choose from UNBLK , BLK , TRN-U ,TRN-B 
 -hw_rstate
     specify the remote status of hardware we need to check for in command output- example : "UNBLK"
     specify multiple states as "UNBLK|TRN-B"
     choose from UNBLK , BLK , TRN-U ,TRN-B
 -maint_lstate
     same as hw_lstate
 -maint_rstate
     same as maint_rstate
 -cot_state
     specify the cot status we need to check for in command output -example : "ABORT"
     specify multiple states as "ABORT|FAIL"
     choose from ABORT, FAIL, LPA_F, N/A, PA, PE, PR
 -servicetype 
     specify ISUP/BT.This is optional parameter,default is ISUP.

Return Values :

 1 - Success , when cic specified are matching the state specified
 0 - Failure , when cic specified are not matching the state specified - Prints error message stating why failure is reported - or execCmd failed.
 -1 - If CIC does not exist

Example :

 \$obj->SonusQA::GSX::GSXHELPER::checkCicsState(-service => "SS71",-cic_start => "2",-cic_end => "13",-ckt_state => "IDLE",-hw_lstate => "UNBLK", -hw_rstate => "UNBLK", -maint_lstate => "UNBLK", -maint_rstate => "UNBLK");

Notes :

 Executes the following command
 SHOW ISUP CIRCUIT SERVICE <service name specified> CIC <cic range specified> STATUS

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub checkCicsState {

    my($self,%args) = @_;
    my($string);
    my $sub = "checkCicsState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($i,$cmd,$flag,$cmd_result);

    # Initialise states if user does not specify any state specific values
    my $ckt_state = "IDLE";
    my $hw_lstate = "UNBLK";
    my $hw_rstate = "UNBLK";
    my $maint_lstate = "UNBLK";
    my $maint_rstate = "UNBLK";
    my $cot_state = "N/A";
    my $admin_mode = "UNBLOCK";
    my $servicetype = "ISUP";

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %args );

    # Check if service and cic_start are specified if not return 0
    foreach (qw/ -service -cic_start/) { unless ( defined $args{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

    # Check if cic_start is lesser than cic_end and error otherwise
    if ( defined $args{-cic_end} ) {
        if ($args{-cic_start} > $args{-cic_end}) {
            $logger->error(__PACKAGE__ . ".$sub CIC Range specified is incorrect");
            return 0;
        }
    }
    else {
        $args{-cic_end} = $args{-cic_start};
    }     

    # Read user inputs for the different states if specified
    $ckt_state = uc($args{-ckt_state}) if $args{-ckt_state};
    $hw_lstate = uc($args{-hw_lstate}) if $args{-hw_lstate};
    $hw_rstate = uc($args{-hw_rstate}) if $args{-hw_rstate};
    $maint_lstate = uc($args{-maint_lstate}) if $args{-maint_lstate};
    $maint_rstate = uc($args{-maint_rstate}) if $args{-maint_rstate};
    $cot_state = uc($args{-cot_state}) if $args{-cot_state};
    $admin_mode = uc($args{-admin_mode}) if $args{-admin_mode};
    $servicetype = uc($args{-servicetype}) if $args{-servicetype};

    my $failcics = 0;
   
    # Command to be executed in GSX
    if ( $args{-cic_start} eq $args{-cic_end} ) {
        $cmd = "SHOW $servicetype CIRCUIT SERVICE $args{-service} CIC $args{-cic_start} STATUS";
    }
    else {
        $cmd = "SHOW $servicetype CIRCUIT SERVICE $args{-service} CIC $args{-cic_start}-$args{-cic_end} STATUS";
    }

    unless ($self->execCmd($cmd)) {
		$logger->error(__PACKAGE__ . ".$sub Unable to execute command '$cmd'");
		return 0;
	}
    $flag = 0; # Assume cic states are not matching the user specified states

    for ($i=$args{-cic_start};$i<=$args{-cic_end};$i++) {

		LINE: foreach(@{$self->{CMDRESULTS}}) {

			chomp($_);

			# Error if error string returned
			if (m/^error/i) {
				$logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
				return 0;
			}
               
			if(m/^($i)/) {
				# We found our cic
				$cmd_result = $_;
				# Match cic status , hw status and maint status from command output from GSX
				#                                   Circuit  Admin   Maint Maint HW    HW    Man
                # CIC   Port                     Ch Status   Mode    Local Remot Local Remot Cot
                # ----- ------------------------ -- -------- ------- ----- ----- ----- ----- -----
				# 36    E1-1-9-1-1               1  IDLE     UNBLOCK UNBLK UNBLK UNBLK UNBLK N/A
				if ($servicetype eq "BT"){
				    if ($_ =~ m/^($i)\s+(\w+|(\w+)(-\d+)+)\s+(\d+)\s+($ckt_state)\s+($admin_mode)\s+($maint_lstate)\s+($maint_rstate)\s+($hw_lstate)\s+($hw_rstate)/) {
					$flag = 1;
				    }elsif ($_ =~ m/^\s+N\/A\s+N\/A\s+N\/A\s+N\/A\s+N\/A/) {
                                        $logger->debug(__PACKAGE__ . ".$sub CIC $i does not exist");
                                        return -1;
                                    }
                                    # Break out of the foreach LINE loop.
                                    last LINE;	
				}
				elsif ($servicetype eq "ISUP"){
				    if ($_ =~ m/^($i)\s+(\w+|(\w+)(-\d+)+)\s+(\d+)\s+($ckt_state)\s+($admin_mode)\s+($maint_lstate)\s+($maint_rstate)\s+($hw_lstate)\s+($hw_rstate)\s+($cot_state)/) {
					$flag = 1;
				    }elsif ($_ =~ m/^\s+N\/A\s+N\/A\s+N\/A\s+N\/A\s+N\/A\s+N\/A/) {
                                        $logger->debug(__PACKAGE__ . ".$sub CIC $i does not exist");
                                        return -1;
                                    }
                                    # Break out of the foreach LINE loop.
                                    last LINE;
				}  
			}
		} # End foreach

		# Return 0 if circuit state does not match specified states.        
		if ($flag == 0) {

			$logger->debug(__PACKAGE__ . ".$sub Circuit State for CIC $i does not match with specified circuit state");
			$logger->info(__PACKAGE__ . ".$sub The state of CIC $i is \n $cmd_result");
			$failcics++;
		}

    } # End for loop for cic range

    if ($failcics > 0) {
        $logger->debug(__PACKAGE__ . ".$sub $failcics CICS dont match with specified circuit state");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Cics are in specified states");
    return 1;

} # End sub checkCicsState

=pod

=head1 getProtectedSlotState ()

 This method returns the state of the protected slot from "SHOW REDUNDANCY GROUP <red group> STATUS" command output.

Arguments :

 -red_group
    specify the cns/mns redundancy group
 -slot
    specify the slot number of the protected cns/mns card

Return Values :

 State of the card - Success 
 0 - Inputs not specified , card specified not found in output, command error

Example :

 \$obj->SonusQA::GSX::GSXHELPER::getProtectedSlotState(-red_group => "cns60",-cns_slot => 6);

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub getProtectedSlotState {

    my($self,%args) = @_;
    my $sub = "getProtectedSlotState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $cmd;

    my $red_group = undef;
    my $slot = undef;

    $red_group = $args{-red_group};
    $slot = $args{-slot};

    # Error if red_group is not set
    if (!defined $red_group) {

        $logger->error(__PACKAGE__ . ".$sub redundancy group is not specified");
        return 0;
    }

    # Error if slot is not set or if not in range of 1 to 16
    if (!defined $slot) {

        $logger->error(__PACKAGE__ . ".$sub slot is not specified");
        return 0;
    }
    elsif (($slot < 1) || ($slot > 16)) {
        $logger->error(__PACKAGE__ . ".$sub Slot number $slot specified is not in range of 1 to 16");
        return 0;
    }

    $cmd = "SHOW REDUNDANCY GROUP $red_group STATUS";

    if($self->execCmd($cmd)) {

        $logger->debug(__PACKAGE__ . ".$sub Retrieving slot state for card $slot");
        
        # Wait for command result
        sleep(10);

        foreach(@{$self->{CMDRESULTS}}) {
            chomp($_);
            # Error if error string returned
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                return 0;
            }

            # Check for status

            if (($_ =~ m/.*($slot)\s+(\w+)/) && ($_ !~ m/Date/)) {
                $logger->debug(__PACKAGE__ . ".$sub State of slot $1 is $2");
                my $state = $2;
                return $state;
            }
        } # End foreach
    } 
    $logger->error(__PACKAGE__ . ".$sub Commmand execution of $cmd was not successful");
    return 0; 
} # End sub getProtectedSlotState

=pod

=head1 gsxLogStart()

 gsxLogStart method is used to start capture of logs per testcase in GSX.ACT/SYS/DBG/TRC logs are captured.The name of the log file will be of the format <Testcase-id>_GSX_<ACT/DBG/SYS/TRC>_<GSX hostname>_timestamp.log.Timestamp will be of format yyyymmdd_HH:MM:SS.log
The mandatory arguments are test_case ,hostname.Default for NFS mount directory will be "/sonus/SonusNFS".After using gsxLogStart , use gsxLogStop function in the test script to kill the processes.

 NOTE :----The logs in ACT folder in NFS needs to be cleared by the test script since roll file does not happen for ACT folder.

Assumptions made :
 It is assumed that NFS is mounted on the machine from where we run the test script which invokes this function.If NFS is not mounted ,please mount it and then start the test script.

Arguments :

 -test_case
     specify testcase id for which log needs to be generated.
 -host_name
     specify the sgx/gsx hostname
 -nfs_mount
     specify the NFS mount directory,default is /sonus/SonusNFS
 -log_dir
     specify the logs directory where logs will be locally stored without ending with / - example - "/home/test/Logs"

Return Values :

 Array of pid in the order ACT,DBG,SYS,TRC followed by filesnames of log files -Success 
 0-Failure

Example :

 \$obj->SonusQA::GSX::GSXHELPER::gsxLogStart(-test_case => "15804",-host_name => "VIPER",-nfs_mount => "/sonusNFS",-log_dir => "/home/test2/Logs");

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub gsxLogStart {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "gsxLogStart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my (@split,$pid,@result,@retvalues,$cmd,@dbg_file,$rest_of_result);
    my $nfs_mount = "/sonus/SonusNFS";

    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    
    my $id = `id -un`;
    chomp($id);

    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -test_case -host_name -log_dir/) {
      unless ($args{$_} ) {
        $logger->error(__PACKAGE__ . ".$sub $_ required");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
      }
    }

    # Settings nfs mount 
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});
    $args{-host_name} = uc($args{-host_name});
    $nfs_mount = "$nfs_mount" . "/" . $args{-host_name};

    $logger->debug(__PACKAGE__ . ".$sub Starting Logs for testcase $args{-test_case} in $nfs_mount");

    # Prepare timestamp format
    my $timestamp = `date \'\+\%F\_\%H\:\%M\:\%S\'`;
    chomp($timestamp);

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    }

    # Test if $args{-log_dir} exists
    if (!(-e $args{-log_dir})) {
        $logger->error(__PACKAGE__ . ".$sub Directory $args{-logdir} does not exist");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    }

    # Clear ACT logs folder
    if (system("rm -f $nfs_mount/evlog/*/ACT/*.ACT")) {
        $logger->error(__PACKAGE__ . ".$sub Unable to remove ACT logs");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    }

    $cmd = "CONFIGURE EVENT LOG ALL ROLLFILE NOW";

    # Execute TCL command on GSX for rollfile
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
                return 0;
            }
        } # End foreach
    } 

    # Execute TCL command on GSX for getting trace files in log folder
    $cmd = "CONFIGURE EVENT LOG TRACE SAVETO BOTH";
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
                return 0;
            }
        } # End foreach
    } 

    # Start xtail for ACT file and push pid into @retvalues
    my $actlogfile = join "_",$args{-test_case},"GSX","ACT",$args{-host_name},$timestamp;
    $actlogfile = join ".",$actlogfile,"log";

    if (system("/ats/bin/xtail $nfs_mount/evlog/*/ACT/* > $args{-log_dir}/$actlogfile &")) {
        $logger->error(__PACKAGE__ . ".$sub Unable to Start ACT logs");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    }
    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep ACT | grep -v grep`;
        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for ACT log - process id is $pid");
        push @retvalues,$pid;
    } # End if
  
    # Start xtail for DBG file and push pid into @retvalues
    my $dbglogfile = join "_",$args{-test_case},"GSX","DBG",$args{-host_name},$timestamp;
    $dbglogfile = join ".",$dbglogfile,"log";

    if (system("/ats/bin/xtail $nfs_mount/evlog/*/DBG/* > $args{-log_dir}/$dbglogfile &")) {
        $logger->error(__PACKAGE__ . ".$sub Unable to Start DBG logs");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } 
    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep DBG | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for DBG log - process id is $pid");
        push @retvalues,$pid;
    } # End if
 
    # Start xtail for SYS file and push pid into @retvalues
    my $syslogfile = join "_",$args{-test_case},"GSX","SYS",$args{-host_name},$timestamp;
    $syslogfile = join ".",$syslogfile,"log";

    if (system("/ats/bin/xtail $nfs_mount/evlog/*/SYS/* > $args{-log_dir}/$syslogfile &")) {
        $logger->error(__PACKAGE__ . ".$sub Unable to start SYS logs");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } 

    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep SYS | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for SYS log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    # Start xtail for TRC file and push pid into @retvalues
    my $trclogfile = join "_",$args{-test_case},"GSX","TRC",$args{-host_name},$timestamp;
    $trclogfile = join ".",$trclogfile,"log";
 
    if (system("/ats/bin/xtail $nfs_mount/evlog/*/TRC/* > $args{-log_dir}/$trclogfile &")) {
        $logger->error(__PACKAGE__ . ".$sub Unable to start TRC logs");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } 

    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep TRC  | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for TRC log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    push @retvalues,$actlogfile;
    push @retvalues,$dbglogfile;
    push @retvalues,$syslogfile;
    push @retvalues,$trclogfile;
    
    $logger->debug(__PACKAGE__ . ".$sub Return Values - @retvalues");
    $logger->debug(__PACKAGE__ . ".$sub Leaving function");
    return @retvalues;

} # End sub gsxLogStart()

=pod

=head1 gsxLogStop()

 gsxLogStop method is used to kill the xtail processes started by gsxLogStart.
The mandatory argument is process_list.

Arguments :
 -process_list
    List of processes seperated by comma 

Return Values :

 1-Success
 0-Failure

Example :

 \$obj->SonusQA::GSX::GSXHELPER::gsxLogStop(-process_list => "24761,27567");

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub gsxLogStop {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "gsxLogStop()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $flag = 1; # Assume sub will return success

    # Check if process list is specified ,if not error
    if (!defined $args{-process_list}) {

        $logger->error(__PACKAGE__ . ".$sub Process list is not specified");
        return 0;
    }

    # Kill processes specified in process list    
    my @list = split /,/,$args{-process_list};

    foreach (@list) {
        if (system("kill $_")) {
            $logger->debug(__PACKAGE__ . ".$sub Unable to kill process $_");
            $flag = 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub Killing process $_");
        }
    } # End foreach
    return $flag;
} # End sub gsxLogStop

=pod

=head1 gsxCoreCheck()

 gsxCoreCheck checks for cores generated by GSX.The mandatory arguments are testcase,hostname of gsx.Cores in gsx are checked if present in <gsxname>/coredump directory in NFS.When core is found ,it is renamed to testcase_core in same directory for future reference.

Assumption : 
 We assume that NFS is mounted on the machine from where this method is being called from.This function assumes that in coredump directory there are no files starting with "core".So if files are present starting with "core" ,please rename to filename which does not start with "core" before calling this function.

Arguments :

 -host_name
    specify hostname
 -test_case
 -nfs_mount
    specify the NFS mount directory - default is /sonus/SonusNFS

Return Values :
 Success - Number of cores found
 0 - Core not Found

Example :

 $res = $gsxobj->SonusQA::GSX::GSXHELPER::gsxCoreCheck(-host_name => "VIPER",-test_case => "17461");

Author :
 P.Uma Maheswari
 ukarthik@sonusnet.com

=cut

sub gsxCoreCheck {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "gsxCoreCheck()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;
    my $corecount = 0;

    # Error if testcase is not set
    if (!defined $args{-test_case}) {

        $logger->error(__PACKAGE__ . ".$sub Test case is not specified");
        return 0;
    }

    # Error if hostname is not set
    if (!defined $args{-host_name}) {

        $logger->error(__PACKAGE__ . ".$sub Host name is not specified");
        return 0;
    }

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        return 0;
    }
    
    my $host = uc($args{-host_name});
    
    # Check if cores are present in $nfs_mount/$host/coredump/ directory
    my @cores = `ls  -1 $nfs_mount/$host/coredump/core*`;
    $logger->debug(__PACKAGE__ . ".$sub @cores");
    my $numcore = $#cores + 1;

    if ($numcore eq 0) {

            $logger->info(__PACKAGE__ . ".$sub No cores found");
            return 0;
    }
    else {
        $logger->info(__PACKAGE__ . ".$sub Number of cores in GSX is $numcore");

        foreach (@cores) {
            
            my $core_timer = 0;
            chomp($_);
            my $file_name = $_;

            while ($core_timer < 120) {

                #start_size of the core file
                my $start_file_size = stat($file_name)->size;
                $logger->debug(__PACKAGE__ . ".$sub Start File size of core is $start_file_size");
                
                sleep(5);
                $core_timer = $core_timer + 5;

                #end_size of the core file;
                my $end_file_size = stat($file_name)->size; 
                $logger->debug(__PACKAGE__ . ".$sub End File size of core is $end_file_size");

                if ($start_file_size == $end_file_size) {                
                    $file_name =~ s/$nfs_mount\/$host\/coredump\///g;
                    my $name = join "_",$args{-test_case},$file_name;

                    # Rename the core to filename with testcase specified
                    my $res = `mv $nfs_mount/$host/coredump/$file_name $nfs_mount/$host/coredump/$name`;
                    $logger->info(__PACKAGE__ . ".$sub Core found in $nfs_mount/$host/coredump/$name");
                    last;
                }
            }
        }

        # Return the number of cores available
        return $numcore;
    }

} # End sub gsxCoreCheck

=pod

=head1 removeGsxCore()

 This functions removes core files starting with "core" in GSX coredump directory.

=over 

=item Arguments :

 -host_name
 -nfs_mount 
   This is optional , default value will be /sonus/SonusNFS.If NFS directory is different ,please specify

=item Return Values :

 1- Success
 0 -Failure

=item Example :

 $res = $gsxobj->SonusQA::GSX::GSXHELPER::removeGsxCore(-host_name => "VIPER");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub removeGsxCore {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "removeGsxCore()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    # Error if hostname is not set
    if (!defined $args{-host_name}) {

        $logger->error(__PACKAGE__ . ".$sub Host name is not specified");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } 

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } 

    my $host = uc($args{-host_name});

    # Remove cores in $nfs_mount/$host/coredump/ directory
    my @result = `rm -f $nfs_mount/$host/coredump/core*`;
    
    # Check if cores are present in $nfs_mount/$host/coredump/ directory
    my @cores = `ls $nfs_mount/$host/coredump/core*`;
    my $numcore = $#cores + 1;

    if ($numcore eq 0) {

        $logger->info(__PACKAGE__ . ".$sub No cores found");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-1");
        return 1;
    } 
    else {
        $logger->info(__PACKAGE__ . ".$sub Number of cores in GSX is $numcore");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
        return 0;
    } # End if
} # End sub removeGsxCore

##################################################################################
#
#purpose: Populate a particular Input IP Filter's Admin values
#Parameters    : shelf, filtername
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getFilteradminvalues(<filtername>)

 Routine to Show the FilterAdminValues .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getFilteradminvalues("Sec_Filter_1");

=back

=cut

sub getFilteradminvalues() {
    my($self, $filtername)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getFilterconfigvalues");
    $logger->info(__PACKAGE__ . ".getFilteradminvalues   Retrieving Input IP Filter Admin Information"); 
    $self->execFuncCall('showIpInputFilterAllAdmin');
    $self->getconfigvalues( $filtername, $self->getshowheader());
}

##################################################################################
#
#purpose: Populate a particular Output IP Filter's values
#Parameters    : shelf, filtername
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getOutputFiltervalues()

 Routine to Show the Ip Output filter Values .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getOutputFiltervalues();

=back

=cut

sub getOutputFiltervalues() {
    my($self, $filtername)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getFilterconfigvalues");
    $logger->info(__PACKAGE__ . ".getFilteradminvalues   Retrieving Output IP Filter Admin Information"); 
    $self->execFuncCall('showIpOutputFilterAll');
    $self->getconfigvalues( $filtername, $self->getshowheader());
}


##################################################################################
#
#purpose: Populate a particular Input IP Filter's status values
#Parameters    : shelf, filtername
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getFilterstatusvalues(<filtername>)

 Routine to Show the Ip Input Filter Status Values .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getFilterstatusvalues();

=back

=cut

sub getFilterstatusvalues() {
    my($self, $filtername)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getFilterstatusvalues");
    $logger->info(__PACKAGE__ . ".getFilterstatusvalues   Retrieving Input IP Filter Status Information"); 
    $self->execFuncCall('showIpInputFilterStatus', {'ip input filter' => $filtername});
    $self->getconfigvalues( $filtername, $self->getshowheader());
}

##################################################################################
#
#purpose: Populate a particular Session's Summary values
#Parameters    : shelf, nif
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getSessionsummvalues()

 Routine to Show the Security SSH Session Summary Values .  

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getSessionsummvalues();

=back

=cut

sub getSessionsummvalues() {
    my($self, $ip)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getSessionsummvalues");
    $logger->info(__PACKAGE__ . ".getSessionsummvalues   Retrieving Session summary Information"); 
    $self->execFuncCall('showSecuritySshSessionSummary');
    $self->getconfigvalues( $ip, $self->getshowheader());
}

##################################################################################
#
#purpose: Populate a particular management nif's Admin values
#Parameters    : shelf, nif, slot, port
#Return Values : None
#
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getMgmtNIFadminvalues(<shelf>, <slot>, <port>)

 Routine to get the management NIF Admin Values .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Array

=item Example(s):

 $gsxObj->getMgmtNIFadminvalues();

=back

=cut

sub getMgmtNIFadminvalues() {
    my($self, $shelf, $slot, $port, $nif)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getNIFconfigvalues");    $logger->info(__PACKAGE__ . ".getMgmtNIFadminvalues	  Retrieving Mgmt NIF Admin Information");
    $self->execFuncCall('showMgmtNifShelfSlotPortAdmin', {'mgmt nif shelf' => $shelf, 'slot'=> $slot, 'port'=> $port});
    $self->getconfigvalues( $nif, $self->getshowheader());
}

##################################################################################
#
#purpose: retrieve policer discard rate profile values for a policer
#Parameters    : discard rate profile, policer type
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getPolicerDRprof()

 Routine retrieve policer discard rate profile values for a policer . 

=over

=item Arguments

   discard rate profile-Scalar(String)
   policer type-Scalar(String)			

=item Return

  None

=item Example(s):

 $gsxObj->getPolicerDRprof("AUTOPROF","Rogue Media Mid Call Bad Dest");

=back

=cut


sub getPolicerDRprof()
{
	my($self,$profile,$type)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getPolicerDRprof");
	$logger->info(__PACKAGE__ . ".getPolicerDRprof:  Retreive Discard Rate Profile info \n");

	if ($self->execCmd("SHOW POLICER DISCARD RATE PROFILE $profile ADMIN")){
		foreach(@{$self->{CMDRESULTS}})	{
			if(m/State/){
				my @temp = split;
				$self->{$profile}->{state} = $temp[$#temp];
				$logger->debug(__PACKAGE__ . ".getPolicerDRprof: $temp[$#temp]");
			}
			if(m/^$type/){
				if (m/^(\w+\s*\w*\s*\w*\s*\w*\s*\w*\s*\w*\s+\:)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)	{
						$logger->debug(__PACKAGE__ . ".getPolicerDRprof: $_");

						$self->{$profile}->{$type}->{SETTH} = $2;
						$self->{$profile}->{$type}->{CLEARTH} = $3;
						$self->{$profile}->{$type}->{SETDU} = $4;
						$self->{$profile}->{$type}->{CLEARDU} = $5;
					}
			}
		} 
	}
}

##################################################################################
#
#purpose: retrieve Policer system alarm status for a particular policer type
#Parameters    : policer type
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::getPolicerSysAlarmstatus()

 Routine to Show the Security SSH Session Summary Values .  

=over

=item Arguments

  Policer type -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->getPolicerAlarmstatus("White");

=back

=cut


sub getPolicerSysAlarmstatus()
{
	my($self,$type)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". getPolicerSysAlarmstatus");
	$logger->info(__PACKAGE__ . ".getPolicerSysAlarmstatus:  Retreive Discard Rate Profile info \n");

	if ($self->execCmd("SHOW POLICER ALARM SYSTEM ALL STATUS")){
		foreach(@{$self->{CMDRESULTS}})	{
			if(m/$type/){
				if (m/^(\s*\w+\s*\w*)\s+(\:\w+)\s+(\d+)\s+(\d+)\s+(\d*)\s+(\d+)/){
						$logger->debug(__PACKAGE__ . ".getPolicerSysAlarmstatus: $_");
						$self->{$type}->{ALALEVEL} = $2;
						$self->{$type}->{ALADUR} = $3;
						$self->{$type}->{DISRATE} = $4;
						$self->{$type}->{PACACCEPT} = $5;
						$self->{$type}->{PACDISCARD} = $6;
						$self->{$type}->{ALALEVEL} =~s/\://g;
					}
			}
		} 
	}
}

##################################################################################
#
#purpose: disable redundnacy group and delete clients
#Parameters    : CNSX,PNSX,SPSX
#Return Values : None
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::deleteRedunclients()

 Routine to diable and delete redundnacy clients.  

=over

=item Arguments

  Redundancy group name -Scalar(String)

=item Return

 Array

=item Example(s):

 $gsxObj->deleteRedunclients("CNS71");

=back

=cut

sub deleteRedunclients() {
  my($self, $type)=@_;
  my $server = my $redunserver = my $redgroup = "";
  my $i = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteRedunclients");
  $logger->info(__PACKAGE__ . ".deleteRedunclients   Retrieving NIF Admin Information"); 
  if ($type eq "all"){
	$server  = "CNS";
  }else{
	$server = $type;
  }	
  $logger->info(__PACKAGE__ . ".deleteRedunclients   server is $server"); 

  $self->getHWInventory(1);
  for ($i = 3; $i <= 16; $i++) {
	if ($self -> {'hw'} -> {'1'} -> {$i} -> {'ADAPTOR'} =~ m/CNA0/ ) {
	  if ($self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'} =~ m/$server/){
		$redunserver = $self -> {'hw'} -> {'1'} -> {$i} -> {'SERVER'};
		$redgroup = $self->getRedungroupName($redunserver);
		my $j = 0;
		$logger->debug(__PACKAGE__ . ".deleteRedunclients OUT servers:groups $redunserver : $redgroup and slot $i");
	$self->execFuncCall("configureRedundancyGroupState",{'redundancy group' => $redgroup, 'sonusRedundGroupAdmnState' => "disabled"});	
		for($j = 3; $j < $i; $j++) {
		  if($self -> {'hw'} -> {'1'} -> {$j} -> {'SERVER'} eq "$redunserver" ){
			$logger->debug(__PACKAGE__ . ".deleteRedunclients IN servers:groups $redunserver : $redgroup and slot $i");
			$logger->debug(__PACKAGE__ . ".deleteRedunclients $j");
			$self->execFuncCall("configureRedundancyClientGroupSlotState",{'redundancy client group' => $redgroup, 'slot' => $j, 'sonusRedundClientAdmnState' => "disabled"});
			$self->execFuncCall("deleteRedundancyClientGroupSlot",{'redundancy client group' => $redgroup, 'slot' => $j});
		  }
		}

	  }
	}
  }
  
}

##################################################################################
# purpose: Backup the command history in NFS as a tcl file
# Parameters    : resolved gsx
# Return Values : none
#			
##################################################################################
=pod

=head1 SonusQA::GSX::GSXHELPER::backupGsxConfig(<gsx>)

 Routine to Backup the command history in NFS as a tcl file.  

=over

=item Arguments

  gsx 	- reference

=item Return

none

=item Example(s):

  &$gsxObj->backupGsxConfig($gsx1);

=back

=cut


sub backupGsxConfig(){
    my($self, $gsx)=@_;
    my(@history);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._backupGsxConfig");
    @history = @{$self->{HISTORY}};
    if($#history > 0){
     		my $dsiobj = SonusQA::DSI->new(
					-OBJ_HOST => $gsx -> {'NFS'} -> {'1'} -> {'IP'},
					-OBJ_USER => $self->{NFSUSERID},
					-OBJ_PASSWORD => $self->{NFSPASSWD},
					-OBJ_COMMTYPE => "SSH",
					);
		my $nfscleancmd =  "/usr/bin/cat /dev/null > ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/cli/scripts/gsxconf.tcl";
		$dsiobj->execCmd($nfscleancmd);
		while (@history) {
	     		my $cmdstring = shift @history;
           		my $cmd  = substr $cmdstring, 23;
			if($cmd =~ m/PUTS/i){
				next;
			}
			$logger->debug(__PACKAGE__ . "._  $cmd");
			my $nfscmd = "echo "."$cmd  >> ".$gsx->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}."/cli/scripts/gsxconf.tcl";
			$dsiobj->execCmd($nfscmd);
		}
    }
}

#Function to remove leading/trailing spaces.
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

=pod

=head1 getSS7CicRangesForSrvGrp()

  This function lists the cics for a given service group
  and calculates and returns an array of the cic ranges.

Arguments :

  -protocol => <SS7 protocol type (ISUP or BT)>
  -service  => <SS7 service name>

Return Values :

  [<array of cic ranges>] if successful.
  [] . empty array otherwise


Example :
 $res = $gsxobj->SonusQA::GSX::GSXHELPER::getSS7CicRangesForSrvGrp(-protcol => 'ISUP',
                                                                   -service => 'SS71' );

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getSS7CicRangesForSrvGrp {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cicRangeArray;
    my @cmdResult;
    my $sub = "getSS7CicRangesForSrvGrp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($protocol, $service, $cmd, $current_cic, $start_cic, $end_cic, $previous_cic, $cic_not_found);

    $cic_not_found = 1;

    $logger->debug("Entered $sub with args - ", Dumper(%args));

    $protocol = trim( $args{-protocol} );
    $service  = trim( $args{-service} );

    # Error if -protocol/-service is not set
    if ( (!defined $args{-protocol}) ||
          ($protocol eq "")          ||
          $protocol !~ /BT|ISUP/i ) {

        $logger->error(__PACKAGE__ . ".$sub missing/invalid \"protocol\" value [should be BT/ISUP].");
        $logger->debug("Leaving $sub");
        return @cicRangeArray; # return empty array as failure
    }
    if ( (!defined $args{-service}) ||
         ($service eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"service\" is not specified.");
        $logger->debug("Leaving $sub");
        return @cicRangeArray; # return empty array as failure
    }

    # Get CIC-Status
    $cmd = "SHOW $protocol CIRCUIT SERVICE $service CIC ALL STATUS";
    if ($self->execCmd($cmd)) {

        my @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug("Leaving $sub");
        return @cicRangeArray;
    }

    foreach( @cmdResult ) {

        if ( m/^(\d+)\s+\S+\s+\d+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+/i ) {
            $current_cic = $1;
            if ( $cic_not_found == 1 )
            {
                $start_cic = $current_cic;
                $previous_cic = $current_cic;
                $cic_not_found = 0;
            }
            elsif( $current_cic != ($previous_cic + 1) )
            {
                $end_cic = $previous_cic;
                if ( $start_cic != $end_cic ) {
                    push (@cicRangeArray, "${start_cic}-${end_cic}" );
                }
                else {
                    push (@cicRangeArray, ${start_cic});
                }
                $start_cic = $current_cic;
            }
            $previous_cic = $current_cic;
        }
        elsif(m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            $logger->debug("Leaving $sub");
            return @cicRangeArray;
        }
    } # end foreach

    if ($cic_not_found == 1)
    {
        $logger->error(__PACKAGE__ . ".$sub No CIC's found for service-grp - $service.");
    }
    else {
        $end_cic = $previous_cic;

        if ( $start_cic != $end_cic ){
            push (@cicRangeArray, "${start_cic}-${end_cic}" );
        }
        else {
            push (@cicRangeArray, "${start_cic}" );
        }
        $logger->debug("Leaving $sub");
    }

   return @cicRangeArray;

}

=pod

=head1 getSS7CicStatus()

  This function checks the circuit status for a given SS7 service group and cic range
  and populates the results against the gsx object as follows foreach circuit:

    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{STATUS}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{ADMIN}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{L_MAINT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{R_MAINT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{L_HW}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{R_HW}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{COT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{OVERALL}

Arguments :

  -protocol  => <SS7 protocol type (ISUP or BT)>
  -service   => <SS7 service name>
  -cic_range => <SS7 cic range>

Return Values :

   1 - success
   0 - otherwise

Example :
   $gsxobj->getSS7CicStatus(-protocol  => 'BT',
                            -service   => 'SS72',
                            -cic_range => '60-64')

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getSS7CicStatus {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $sub = "getSS7CicStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($protocol, $service, $cicrange, $cmd);
    my ($cic_start, $cic_end, $current_cic , $cic_found);
    my ($status, $admin, $l_maint, $r_maint, $l_hw, $r_hw, $cot);

    $logger->debug("Entered $sub with args - ", Dumper(%args));

    $protocol = uc(trim( $args{-protocol} ));
    $service  = uc(trim( $args{-service} ));
    $cicrange = trim( $args{-cic_range} );

    $service  =~ s/[^\w\d]//g;

    # Error if -protocol/-service is not set
    if ( (!defined $args{-protocol}) ||
          ($protocol eq "")        ||
          $protocol !~ /BT|ISUP/i ) {

        $logger->error(__PACKAGE__ . ".$sub missing/invalid \"protocol\" value [should be BT/ISUP].");
        $logger->debug("Leaving $sub");
        return 0;
    }
    if ( (!defined $args{-service}) ||
         ($service eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"service\" is not specified.");
        $logger->debug("Leaving $sub");
        return 0;
    }
    if ( (!defined $args{-cic_range}) ||
         ($cicrange eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"cicrange\" is not specified.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    # Check cic_range format
    if ( $cicrange =~ /([0-9]+)[-]([0-9]+)/) {
        $cic_start = $1;
        $cic_end   = $2;

        $cmd = "SHOW ISUP CIRCUIT SERVICE $service CIC $cic_start-$cic_end STATUS";
    }
    elsif( $cicrange =~ /^([0-9]+)$/ ) {
        $cic_start = $cic_end = $1;
        $cmd = "SHOW ISUP CIRCUIT SERVICE $service CIC $cic_start STATUS";
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub \"cicrange\" has incorrect format [should be cic_number OR a range (start_cic-end_cic) ].");
        $logger->debug("Leaving $sub");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub running command - $cmd");

    if ($self->execCmd($cmd)) {
        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    for ( $current_cic = $cic_start; $current_cic <= $cic_end; $current_cic++)
    {
        $cic_found = 0;
        $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic] = undef;

        foreach( @cmdResult ) {

            if ( m/^($current_cic)\s+\S+\s+\d+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {

                $cic_found = 1;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{STATUS}  = $status  = $2;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{ADMIN}   = $admin   = $3;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_MAINT} = $l_maint = $4;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_MAINT} = $r_maint = $5;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_HW}    = $l_hw    = $6;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_HW}    = $r_hw    = $7;
                $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{COT}     = $cot     = $8;

                if ( $status =~ /IDLE/i &&
                     $l_maint =~ /UNBLK/ &&
                     $r_maint =~ /UNBLK/ &&
                     $l_hw =~ /UNBLK/ &&
                     $r_hw =~ /UNBLK/ ) {

                     $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{OVERALL} = 'IDLE';
                }
                else {
                     $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{OVERALL} = 'NON-IDLE';
                }

                last;
            }
            elsif(m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                $logger->debug("Leaving $sub");
                return 0;
            }
        }

        if ( $cic_found == 0) {
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{STATUS}  = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{ADMIN}   = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_MAINT} = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_MAINT} = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_HW}    = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_HW}    = "NOT_PROVISIONED";
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{COT}     = "NOT_PROVISIONED";

            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{OVERALL} = "NOT_PROVISIONED";
        }

    }

    $logger->debug("Leaving $sub");
    return 1;
}

=pod

=head1 verifyImageVersion()

   This function compares the images loaded on a GSX to the version passed in as an argument.
   If they all match the function returns 1 (success) otherwise it returns 0 (failure). 
   GSX server cards that have their status to .N/A. are ignored


Arguments :

   -version => <GSX Image version name e.g. .V06.04.12 A004.>

Return Values :

   1 - success
   0 - otherwise

Example :
   $gsxobj->verifyImageVersion(-version => .V06.04.12 A004.)

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub verifyImageVersion {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $sub = "verifyImageVersion()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd, $version , $slot, $hwType, $loadedVersion, $nonMatchingImageFound);
    $nonMatchingImageFound = 1;

    $logger->debug(__PACKAGE__ . ".$sub Entered function");

    unless (defined($args{-version}) &&  $args{-version} !~ /^\s*$/ ) {
        $logger->error(__PACKAGE__ . ".$sub missing/invalid \"-version\" value.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0");
        return 0;
    }
    
    $version = $args{-version};
    
    $logger->debug(__PACKAGE__ . ".$sub Checking software version of server cards against '$version'.");

    $cmd = "SHOW SOFTWARE UPGRADE SHELF 1 SUMMARY";
    if ($self->execCmd($cmd)) {
        @cmdResult = @{$self->{CMDRESULTS}};

      foreach( @cmdResult ) {

            chomp($_);
        if( (m/^\d+\s+(\d+)\s+(\S+)\s+\S+\s+(\S+)\s(\S+)\s+/) ||
            (m/^\d+\s+(\d+)\s+(\S+)\s+\S+\s+(\S+)\s+/) ) {

            $slot          = $1;
            $hwType        = $2;
            if (defined $4) {
                $loadedVersion = $3 . " $4";
            }
            else {
                $loadedVersion = $3;
            }

            if ( ($hwType =~ /UNKNOWN/) || ($loadedVersion =~ /N\/A/) ) { # Skip for these two conditions
                next;
            }
            else {
                if ( $loadedVersion ne $version) {
                    $logger->error(__PACKAGE__ . ".$sub loaded image '$loadedVersion' in slot $slot does not match specified image '$version'." );
                    $nonMatchingImageFound = 0;
                }
            }
        }
        elsif(m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0");
                return 0;
         }
      } # End foreach
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-$nonMatchingImageFound");
    return $nonMatchingImageFound;
}

=pod

=head1 areServerCardsUp()

    This function checks that all the server cards in a GSX are in the state .RUNNING., .EMPTY. or .HOLDOFF.. 
    If so the function returns 1 (success) otherwise it will loop around re-checking every 5 seconds until it succeeds 
    or specified timeout value is reached. On timeout the function will return 0 failure.

Arguments :

    -timeout => <maximum length of time GSX should be checked>

Return Values :

    1 - success
    0 - otherwise

Example :
    $gsxobj->areServerCardsUp()

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub areServerCardsUp {

    my ($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $sub = "areServerCardsUp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($timeout, $cmd, $nonMatchingStatus, $timeElapsed, $t0, $t1, $t0_t1);
    my ($slot, $hwType, $serverStatus, $oneMismatch, $matchingStatus);

    $nonMatchingStatus = 0;
    $timeout = 60;

    $logger->debug("Entered $sub with args - ", Dumper(%args));

    if ( (!defined $args{-timeout}) ||
          ($args{-timeout} eq "") ) {

        $logger->debug(__PACKAGE__ . ".$sub missing \"timeout\" value, continuing with default (60 secs).");
    }
    else {
        $timeout = $args{-timeout};
    }

    $cmd = "SHOW INVENTORY SHELF 1 SUMMARY";
    $logger->debug(__PACKAGE__ . ".$sub running command - $cmd");
    $t0 = [gettimeofday];

    do {
        
        if ($self->execCmd($cmd)) {

            @cmdResult = @{$self->{CMDRESULTS}};
            $oneMismatch = 0;
            $nonMatchingStatus = 0;
            $matchingStatus = 0;

            foreach( @cmdResult ) {

                chomp($_);
                if( m/^\d+\s+(\d+)\s+(\S+)\s+(\S+)\s+\S+\s+\S+/i )  {

                    $slot         = $1;
                    $hwType       = $2;
                    $serverStatus = $3;

                    #$logger->debug(__PACKAGE__ . ".$sub slot - $slot / hwType - $hwType / serverStatus - $serverStatus.");
                    if ( $hwType =~ /UNKNOWN/i ) {
                        $logger->debug(__PACKAGE__ . ".$sub IGNORE SLOT - Hardware Type is UNKNOWN in Slot $slot.");
                        next;
                    }

                    if ( $serverStatus !~ /EMPTY|HOLDOFF|RUNNING/  ) {
                        $oneMismatch = 1;
                        $logger->debug(__PACKAGE__ . ".$sub MISMATCH - Server Status in slot $slot does not match one of EMPTY|HOLDOFF|RUNNING. Currently set to '$serverStatus'.");
                    } else {
                        $logger->debug(__PACKAGE__ . ".$sub MATCH - Server Status in slot $slot set to '$serverStatus'.");
                        # Make sure more than one card is running
                        $matchingStatus++;
                    }
                }
                elsif (m/^error/i) {
                    $logger->error(__PACKAGE__ . ".$sub Found error in commnad execution. CMD RESULT: $_");
                    $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0");
                    return 0;
                }
            }

            if (($oneMismatch == 1) || ($matchingStatus == 1)) {

                $nonMatchingStatus = 0;
                $logger->debug(__PACKAGE__ . ".$sub Not all server cards are ready, retrying after 5 secs.");
                sleep (5);
            }
            else {

               $nonMatchingStatus = 1;
            }
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub Failed to execute command - $cmd.");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0");
            return 0;
        }

    } while ( ($nonMatchingStatus == 0) && (tv_interval($t0) <= $timeout) );

    $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-$nonMatchingStatus");
    return $nonMatchingStatus;
}

=pod

=head1 getISDNChanRangesForSrvGrp()

    This function lists the ISDN channels for a given service group and calculates and 
    returns an array of arrays containing the ISDN service group name,
    interface and channel range. 

=over 

=item Arguments :

    -service  => <ISDN service name>

=item Return Values :

    [<array of triples where each triple is ISDN service name, ISDN interface, channel range>] if successful.
    [] . empty array otherwise

=item Example :

    $gsxobj->getISDNChanRangesForSrvGrp(-service => 'is1')

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub getISDNChanRangesForSrvGrp {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @chanRangeArray;
    my @cmdResult;
    my $sub = "getISDNChanRangesForSrvGrp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($interface, $service, $cmd, $current_chan, $start_chan, $end_chan, $previous_chan, $chan_not_found);
    my $pushString = "";

    $chan_not_found = 1;
    $previous_chan  = 0;

    $logger->debug("Entered $sub with args - ", Dumper(%args));

    $service  = trim( $args{-service} );

    if ( (!defined $args{-service}) ||
         ($service eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"service\" is not specified.");
        $logger->debug("Leaving $sub");
        return @chanRangeArray; # return empty array as failure
    }

    # Get CHAN-Status
    $cmd = "SHOW ISDN BCHANNEL SERVICE $service STATUS";
    if ($self->execCmd($cmd)) {

        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug("Leaving $sub");
        return @chanRangeArray;
    }

    foreach( @cmdResult ) {

        chomp($_);
        if ( m/^$service\s+(\d+)\s+(\d+)\s+\S+\s+\S+\s+\S+\s+\S+/i ) {

            $interface    = $1;
            $current_chan = $2;
            if ( $chan_not_found == 1 )
            {
                $start_chan = $current_chan;
                $previous_chan = $current_chan;
                $chan_not_found = 0;
            }
            elsif( $current_chan != ($previous_chan + 1) )
            {
                $end_chan = $previous_chan;
                if ( $start_chan != $end_chan ) {
                    $pushString = $service . "," . $interface . "," . "${start_chan}-${end_chan}";
                    push (@chanRangeArray, $pushString );
                }
                else {
                    $pushString = $service . "," . $interface . "," . $start_chan;
                    push (@chanRangeArray, $pushString );
                }
                $start_chan = $current_chan;
            }
            $previous_chan = $current_chan;
        }
        elsif(m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            $logger->debug("Leaving $sub");
            return @chanRangeArray;
        }
    } # end foreach

    if ($chan_not_found == 1)
    {
        $logger->error(__PACKAGE__ . ".$sub No CHAN's found for service-grp - $service.");
    }
    else {
        $end_chan = $previous_chan;

        if ( $start_chan != $end_chan ){
            $pushString = $service . "," . $interface . "," . "${start_chan}-${end_chan}";
            push (@chanRangeArray, $pushString );
        }
        else {
            $pushString = $service . "," . $interface . "," . $start_chan;
            push (@chanRangeArray, $pushString );
        }
    }

   $logger->debug("Leaving $sub");
   return @chanRangeArray;

}

=pod

=head1 getISDNChannelStatus()

    This function checks the ISDN channel status for a given ISDN service group and channel range 
    and populates the results against the gsx object as follows foreach circuit:

    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{USAGE}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{L_ADMIN}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{L_HW}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{R_MAINT}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{OVERALL}

    The existing {CHANSTATE}->{<srv_grp>,<interface>} hash will be deleted before re-populating.

Arguments :

    -service      => <ISDN service name>
    -chan_range   => <ISND channel range>

Return Values :

   1 - success
   0 - otherwise

Example :
    $gsxobj->getISDNChannelStatus(-service    => 'is1', 
                                  -chan_range => '1-15')

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getISDNChannelStatus {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $sub = "getISDNChannelStatus()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($service, $interface, $chanrange, $cmd);
    my ($chan_start, $chan_end, $current_chan , $chan_found);
    my ($usage, $l_admin, $r_maint, $l_hw);

    $logger->debug("Entered $sub with args - ", Dumper(%args));

    $service  =  uc (trim( $args{-service} ));
    $chanrange = trim( $args{-chan_range} );

    $service =~ s/[^\w\d]//g;

    # Error if -chanrange/-service is not set
    if ( (!defined $args{-service}) ||
         ($service eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"service\" is not specified.");
        $logger->debug("Leaving $sub");
        return 0;
    }
    if ( (!defined $args{-chan_range}) ||
         ($chanrange eq "") ) {

        $logger->error(__PACKAGE__ . ".$sub \"chanrange\" is not specified.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    # Check chan_range format
    if ( $chanrange =~ /([0-9]+)[-]([0-9]+)/) {

        $chan_start = $1;
        $chan_end   = $2;
    }
    elsif( $chanrange =~ /^([0-9]+)$/ ) {
        $chan_start = $chan_end = $1;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub \"chanrange\" has incorrect format [should be chan_number OR a range (start_chan-end_chan) ].");
        $logger->debug("Leaving $sub");
        return 0;
    }

    $cmd = "SHOW ISDN BCHANNEL SERVICE " . $service ." STATUS";
    $logger->debug(__PACKAGE__ . ".$sub running command - $cmd");

    if ($self->execCmd($cmd)) {
        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    for ( $current_chan = $chan_start; $current_chan <= $chan_end; $current_chan++)
    {
        $chan_found = 0;

        foreach( @cmdResult ) {

            if ( m/$service\s+(\S+)\s+$current_chan\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {

                $chan_found = 1;
                $interface = $1;
                $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan] = undef;

                $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{USAGE}   = $usage   = $2;
                $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{L_ADMIN} = $l_admin = $3;
                $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{L_HW}    = $l_hw    = $4;
                $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{R_MAINT} = $r_maint = $5;

                if ( $usage =~ /IDLE/i &&
                     $l_admin =~ /IS/ &&
                     $r_maint =~ /IS/ &&
                     $l_hw =~ /IS/ ) {

                     $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{OVERALL} = 'IDLE';
                }
                else {
                     $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{OVERALL} = 'NON-IDLE';
                }
                last;
            }
            elsif(m/^error/i) {
                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                $logger->debug("Leaving $sub");
                return 0;
            }
        }

        if ( $chan_found == 0) {
            $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{USAGE}   = "NOT_PROVISIONED"; 
            $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{L_ADMIN} = "NOT_PROVISIONED";
            $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{L_HW}    = "NOT_PROVISIONED";
            $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{R_MAINT} = "NOT_PROVISIONED";

            $self->{CHANSTATE}->{$service . ',' . $interface}[$current_chan]->{OVERALL} = "NOT_PROVISIONED";
        }
    }

    $logger->debug("Leaving $sub");
    return 1;
}

=pod

=head1 getGsxConfigFromTG()

    This function identifies the circuits or channels tied to a 
    service group for all trunk groups of the GSX object. 

Arguments :

    None

Return Values :

    1 - success
    0 - otherwise

    GSX object has the $gsxobj->{TG_CONFIG} hash populated.

Example :
    $gsxobj->getGsxConfigFromTG()

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getGsxConfigFromTG 
{
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @allTGCmdResult;
    my @allSGCmdResult;
    my @sgStatus;
    my @cmdStatus;
    my @ss7NodeResult;
    my $sub = "getGsxConfigFromTG()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd, $tgName, $sgName, $sgType ,$isupOrBT, $ss7NodeName );
    my $suitableTrunkGroupFound=0;

    $self->{TG_CONFIG} = undef;

    $logger->debug("Entered $sub.");
    
    $cmd = "SHOW TRUNK GROUP ALL STATUS";
    if ($self->execCmd($cmd)) {
        @allTGCmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    foreach(@allTGCmdResult)
    {
        chomp($_);
        if(m/^(\S+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\S+/)
        {
            if ( $2 > 0 ) # The given tg has cic's/channels
            {
                $tgName = trim($1);
                $logger->debug(__PACKAGE__ . ".$sub TGNAME - $tgName");
                $suitableTrunkGroupFound=1;

                #Get ss7Node
                $cmd = "SHOW TRUNK GROUP $tgName ADMIN";
                if ($self->execCmd($cmd))
                {
                    chomp($_);
                    @cmdStatus = @{$self->{CMDRESULTS}};
                    foreach( @cmdStatus )
                    {
                        chomp($_);
                        $ss7NodeName = "";
                        if( m/Isup Node\s+(\S+)/)
                        {
                            $ss7NodeName = trim($1);
                            if ( $ss7NodeName ne "" ) # ss7
                            {
                                #$self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}; #define KEY
                                
                                # Get own point code and protocol
                                $cmd = "SHOW SS7 NODE $ss7NodeName ADMIN";
                                if ($self->execCmd($cmd))
                                {
                                    @ss7NodeResult = @{$self->{CMDRESULTS}};
                                    my $gwName="";
                                    my $altGwName="";
                                    my $svrProto;
                                    my @gwArray;

                                    foreach ( @ss7NodeResult )
                                    {
                                        chomp($_);
                                        if ( m/Point Code.*[:]\s(\d+[-]\d+[-]\d+).*/ )
                                        {
                                            $self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{OPC} = trim($1);
                                        }
                                        elsif ( m/Protocol Type.*[:]\s(\S+)/ )
                                        {
                                            $self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{PROTOCOL} = trim($1);
                                        }
                                        elsif ( m/Server Protocol.*[:]\s(\S+)/ )
                                        {
                                            $svrProto = trim($1);
                                            $self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{SERVER_PROTOCOL} = $svrProto;
                                        }
                                        elsif ( m/Gateway Assignment.*[:]\s(\S+)/ )
                                        {
                                            $gwName = trim($1);
                                            @{$self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{GATEWAYS}->{$gwName}} = (); # Create the key
                                            push(@gwArray, $gwName);
                                        }
                                        elsif ( m/Alternate Gateway.*[:]\s(\S+)/ )
                                        {
                                            $altGwName = trim($1);
                                            @{$self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{GATEWAYS}->{$altGwName}} = (); # Create the key
                                            push(@gwArray, $altGwName);
                                        }
                                        elsif ( m/^error/i )
                                        {
                                            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                                            $logger->debug("Leaving $sub");
                                            return 0;
                                        }
                                    }

                                    if ( ($svrProto !~ /LOCAL/i) && ($gwName eq "") )
                                    {
                                        $logger->error(__PACKAGE__ . ".$sub unable to get gateway assignment for $ss7NodeName.");
                                        $logger->debug("Leaving $sub retCode - 0.");
                                        return 0;
                                    }
                                    elsif ( ($svrProto =~ /M3UA/i) && ($altGwName eq "") )
                                    {
                                        $logger->error(__PACKAGE__ . ".$sub unable to get alternate gateway assignment for $ss7NodeName.");
                                        $logger->debug("Leaving $sub retCode - 0.");
                                        return 0;
                                    }

                                    foreach my $GW ( @gwArray )
                                    {
                                        $cmd = "SHOW SS7 GATEWAY $GW ADMIN";
                                        my @gwData;
                                        if ($self->execCmd($cmd)) {
                                            @gwData = @{$self->{CMDRESULTS}};
                                        }
                                        else {
                                            $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                                            $logger->debug("Leaving $sub");
                                            return 0;
                                        }

                                        foreach ( @gwData )
                                        {
                                            if ( m/Host Name[:]\s+(\S+).*/)
                                            {
                                                push( @{$self->{TG_CONFIG}->{$tgName}->{SS7_NODE}->{$ss7NodeName}->{GATEWAYS}->{$GW}}, , $1);
                                            }
                                            elsif ( m/^error/i )
                                            {
                                                $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                                                $logger->debug("Leaving $sub retCode - 0");
                                                return 0;
                                            }
                                        }
                                    } # foreach - GW
                                }
                                else
                                {
                                    $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                                    $logger->debug("Leaving $sub");
                                    return 0;
                                }

                            }
                        }
                        elsif(m/^error/i)
                        {
                            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                            $logger->debug("Leaving $sub");
                            return 0;
                        }
                    }
                }
                else
                {
                    $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                    $logger->debug("Leaving $sub");
                    return 0;
                }

                $cmd = "SHOW TRUNK GROUP $tgName SERVICEGROUPS";
                if ($self->execCmd($cmd)) 
                {
                    @allSGCmdResult = @{$self->{CMDRESULTS}};
                }
                else {
                    $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                    $logger->debug("Leaving $sub");
                    return 0;
                }

             foreach(@allSGCmdResult)
             {
                chomp($_);
                if(m/$tgName\s+(\S+)\s+(\S+)/)
                {

                    $sgName = uc($1);
                    $sgType = uc($2);

                    if ( $sgType =~ /ss7/i) 
                    {

                        # Check ISUP/BT - Try ISUP first
                        $cmd = "SHOW ISUP SERVICE $sgName STATUS";
                        $isupOrBT = 'ISUP';
                        if ($self->execCmd($cmd))
                        {
                            @sgStatus = @{$self->{CMDRESULTS}};
                            if ( $sgStatus[0] =~ /error/i )
                            {
                                 # Try BT
                                 $cmd = "SHOW BT SERVICE $sgName STATUS";
                                 if ($self->execCmd($cmd))
                                 {
                                     @sgStatus = @{$self->{CMDRESULTS}};
                                     if ( $sgStatus[0] =~ /error/i )
                                     {
                                         $logger->error(__PACKAGE__ . ".$sub unidentified sg-group $sgName.");
                                         $logger->debug("Leaving $sub");
                                         return 0;
                                     }
                                     $isupOrBT = 'BT';
                                 }
                                 else 
                                 {
                                     $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                                     $logger->debug("Leaving $sub");
                                     return 0;
                                 }
                            }

                            # sgStatus array is suitably populated (iusp/bt)
                            foreach( @sgStatus )
                            {
                                if (m/$sgName\s+(\d+[-]\d+[-]\d+)\s+\S+/i) # Assign RPC
                                {
                                    $self->{TG_CONFIG}->{$tgName}->{$isupOrBT . ',' . $sgName}->{RPC} = $1;
                                }
                                elsif(m/^error/i)
                                {
                                    $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                                    $logger->debug("Leaving $sub");
                                    return 0;
                                }
                            }

                            
                            @{$self->{TG_CONFIG}->{$tgName}->{$isupOrBT . ',' . $sgName}->{CIC_RANGES}} = 
                                                  $self->getSS7CicRangesForSrvGrp(-protocol => $isupOrBT,
                                                                                  -service  => $sgName );
                        }
                        else
                        {
                            $logger->error(__PACKAGE__ . ".$sub failed to execute command - $cmd.");
                            $logger->debug("Leaving $sub");
                            return 0;
                        }
                    }
                    elsif ( $sgType =~ /isdn/i ) {

                        @{$self->{TG_CONFIG}->{$tgName}->{'ISDN' . ',' . $sgName}->{CHANNEL_RANGES}} =
                                                 $self->getISDNChanRangesForSrvGrp(-service => $sgName);
                    }
                    else {
                        $logger->error(__PACKAGE__ . ".$sub unsupported service-group type $sgType");
                        $logger->debug("Leaving $sub");
                        return 0;
                    }
                }
                elsif(m/^error/i) 
                {
                    $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
                    $logger->debug("Leaving $sub");
                    return 0;
                }
              }
            }
        }
        elsif(m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            $logger->debug("Leaving $sub");
            return 0;
        }

    } # foreach allTGCmdResult

    if ($suitableTrunkGroupFound==0)
    {
        $logger->error(__PACKAGE__ . ".$sub no suitable trunk group found");
        $logger->debug("Leaving $sub");
        return 0;
    }

    $logger->debug("Leaving $sub");
    return 1;
}


=pod

=head1 isCleanupOrRebootRequired()

    Assumes GSX object has been populated after TCL configuration 
    using getGsxConfigFromTG() function.

    Function identifies whether circuits/channels need cleaning up 
    or if some circuits or channels have been deleted then signifies a reboot is required

=over 

=item Arguments :

    None

=item Return Values :

    0 - no cleanup required
    1 - cleanup required
    2 - reboot needed

=item Example :

    $gsxobj->isCleanupOrRebootRequired()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub isCleanupOrRebootRequired
{
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "isCleanupOrRebootRequired()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd);

    $logger->debug("Entered $sub.");

    @{$self->{CIC_CLEANUP_ARRAY}}  = ();
    @{$self->{CHAN_CLEANUP_ARRAY}} = ();
    # DEBUG - Added this init
    %{$self->{CLEANUP_REASON}} = ();
  
    unless (defined($self->{'TG_CONFIG'})) {
        $logger->warn(__PACKAGE__,".$sub No GSX config found on this GSX. Has the getGsxConfigFromTG() function been executed successfully?");
    }
    
    foreach my $tGroup (sort keys %{$self->{'TG_CONFIG'}} ) # outer
    {
        foreach my $sgTandN ( sort keys %{$self->{'TG_CONFIG'}->{$tGroup}} ) # inner
        {
            if ( $sgTandN =~ /,/) # Need to skip other keys
            {
                my ($serviceType, $serviceName) = split(/,/, $sgTandN); 

                if ( $serviceType =~ /ISUP|BT/i)
                {
                    foreach my $cicRange ( @{%{$self->{'TG_CONFIG'}->{$tGroup}->{$sgTandN}->{CIC_RANGES}}})
                    {
                        my $cicStart = (split(/-/, $cicRange))[0];
                        my $cicEnd   = (split(/-/, $cicRange))[1];
                        $cicEnd = ($cicEnd eq "") ? $cicStart : $cicEnd; # Single CIC specified
                        
                        #print "\nCalling getSS7CicStatus serviceType-$serviceType , serviceName - $serviceName, cicRange - $cicRange\n";
                        if ( $self->getSS7CicStatus(-protocol => $serviceType,
                                                    -service => $serviceName,
                                                    -cic_range => $cicRange) )
                        {
                            for(my $cic=$cicStart; $cic <= $cicEnd; $cic++)
                            {

                                my $overAllState = $self->{CICSTATE}->{$serviceType . "," . $serviceName}[$cic]->{OVERALL};
                                if ( $overAllState eq "NON-IDLE" )
                                {
                                    my $pushData = $serviceType . "," . $serviceName . "," . $cic;
                                    push(@{$self->{CIC_CLEANUP_ARRAY}}, $pushData);

                                    $self->{CLEANUP_REASON}->{$serviceType . "," . $serviceName}[$cic] =
                                                               "$serviceType CIC $cic in service group $serviceName is in state: \n" .
                                                               "CIC STATUS = " . $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{STATUS} . "\n" .
                                                               "LOCAL MAINT = ". $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{L_MAINT}. "\n" .
                                                               "REMOTE MAINT = ". $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{R_MAINT}. "\n" .
                                                               "LOCAL HARDWARE = ". $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{L_HW}."\n" .
                                                               "REMOTE HARDWARE = ". $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{R_HW}."\n";

                                }
                                elsif( $overAllState eq "NOT_PROVISIONED")
                                {
                                    $self->{RESET_NODE} = 1;
                                    $self->{CLEANUP_REASON}->{$serviceType . "," . $serviceName}[$cic] = "$serviceType CIC $cic" .
                                                                                 " in service group $serviceName is NOT PROVISIONED.";
                                }
                            }
                        }
                        else
                        {
                            $self->{RESET_NODE} = 1;
                            $logger->error("Failed to get circuit status for cic range $cicRange service-$serviceName.\n");
                        }
                    }
                }
                elsif( $serviceType =~ /ISDN/i)
                {
                    foreach my $chanRange ( @{%{$self->{TG_CONFIG}->{$tGroup}->{$sgTandN}->{CHANNEL_RANGES}}})
                    {
                        my $interface = (split(/,/, $chanRange))[1];
                        $chanRange    = (split(/,/, $chanRange))[2];

                        my $chanStart = (split(/-/, $chanRange))[0];
                        my $chanEnd   = (split(/-/, $chanRange))[1];
                        $chanEnd = ($chanEnd eq "") ? $chanStart : $chanEnd; # Single CHAN specified

                        if ( $self->getISDNChannelStatus( -service    => $serviceName,
                                                          -chan_range => $chanRange) )
                        {
                            for(my $chan=$chanStart; $chan <= $chanEnd; $chan++)
                            {
                                my $overAllState = $self->{CHANSTATE}->{$serviceName . ',' . $interface}[$chan]->{OVERALL};
                               
                                if ( $overAllState eq "NON-IDLE" )
                                {
                                    my $pushData = $serviceType . "," . $serviceName . "," . $chan;
                                    push(@{$self->{CHAN_CLEANUP_ARRAY}}, $pushData);

                                    $self->{CLEANUP_REASON}->{$serviceType . "," . $serviceName}[$chan] =
                                                               "$serviceType CHAN $chan in service group $serviceName is in state: \n" .
                                                               "USAGE = " . $self->{CHANSTATE}->{$serviceName . ','. $interface}[$chan]->{USAGE} . "\n" .
                                                               "LOCAL ADMIN = ". $self->{CHANSTATE}->{$serviceName . ',' . $interface}[$chan]->{L_ADMIN}. "\n" .
                                                               "REMOTE MAINT = ". $self->{CHANSTATE}->{$serviceName . ',' . $interface}[$chan]->{R_MAINT}. "\n" .
                                                               "LOCAL HARDWARE = ". $self->{CHANSTATE}->{$serviceName . ',' .$interface}[$chan]->{L_HW}."\n";

                                }
                                elsif( $overAllState eq "NOT_PROVISIONED")
                                {
                                    $self->{RESET_NODE} = 1;
                                    $self->{CLEANUP_REASON}->{$serviceName . ',' . $interface}[$chan] = "ISDN b-channel $chan" .
                                                                                 " in service group $serviceName is NOT PROVISIONED.";
                                }
                            }
                        }
                        else
                        {
                            $self->{RESET_NODE} = 1;
                            $logger->error("Failed to get ISDN B-channel status for chan range $chanRange.\n");
                        }
                    }
                }
                else
                {
                    $logger->debug(__PACKAGE__,".$sub unrecognized serviceType-$serviceType.");
                }
            }
        } # foreach inner
    } # foreach outer

    if ($self->{RESET_NODE}) 
    {
        $logger->debug(__PACKAGE__,".$sub Leaving with retcode-2 (indicating GSX REBOOT required)");
        return 2; # REBOOT
    }
    elsif( ( $#{$self->{CIC_CLEANUP_ARRAY}} > -1) || ( $#{$self->{CHAN_CLEANUP_ARRAY}} > -1) )
    {
        $logger->debug(__PACKAGE__,".$sub Leaving with retcode-1 (indicating GSX CLEANUP required)");
        return 1; # CLEANUP
    }

    $logger->debug(__PACKAGE__,".$sub Leaving with retcode-0 (indicating that NO CLEANUP is required on the GSX");
    return 0; # NO-CLEANUP
}


=pod

=head1 getProtectedSlot()

    Returns the protected slot number.

Arguments :

    card-type.

Return Values :

    "" - failure
    else the slot.

Example :
    $gsxobj->getProtectedSlot("MNS11-1")

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getProtectedSlot
{
    my($self, $card) = @_;
    my $sub = "getProtectedSlot()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $cmd;

    if ( (! defined $card) || ($card eq ""))
    {
        $logger->error(__PACKAGE__,".$sub card not defined.");
        return "";
    }

    $cmd = "SHOW REDUNDANCY GROUP $card STATUS";
    my @cmdResult = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub [$cmd] result [@cmdResult].");
    my $swFlag=0;
    foreach ( @cmdResult )
    {
                chomp($_);
                if ( m/^\s*Protected Slot:\s+(\S+)\s*$/i )
                {
                    return $1;
                }
                elsif ( m/^error/i )
                {
                    $logger->error(__PACKAGE__ . ".$sub [$cmd] failure.");
                    $logger->debug("Leaving $sub.");
                    return "";
                }
    }

    return "";
}

=pod

=head1 getRedundantSlotState()

    Returns the redundant slot state.

Arguments :

    Card-type.

Return Values :

    0 - failure
    else the state.

Example :
    $gsxobj->getRedundantSlotState("MNS11-1");

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub getRedundantSlotState
{
    my($self, $card) = @_;
    my $sub = "getRedundantSlotState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $cmd;

    if ( (! defined $card) || ($card eq ""))
    {
        $logger->error(__PACKAGE__,".$sub card not defined.");
        return 0;
    }

    $cmd = "SHOW REDUNDANCY GROUP $card STATUS";
    my @cmdResult = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub [$cmd] result [@cmdResult].");
    my $swFlag=0;
    foreach ( @cmdResult )
    {
                chomp($_);
                if ( m/^\s*Redundant Slot State:\s+(\S+)\s*$/i )
                {
                    $logger->debug("Leaving $sub with retCode-'$1'.");
                    return $1;
                }
                elsif ( m/^error/i )
                {
                    $logger->error(__PACKAGE__ . ".$sub [$cmd] failure.");
                    $logger->debug("Leaving $sub retCode-2.");
                    return 0;
                }
    }

    return 0;
}

=pod

=head1 detectSwOverAndRevert()

    Detects a s/w and if and reverts back.

Arguments :

    None

Return Values :

    0 - s/w happened
    1 - no s/w happened
    2 - command failure

Example :
    $gsxobj->detectSwOverAndRevert()

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub detectSwOverAndRevert
{
    my($self) = @_;
    my $sub = "detectSwOverAndRevert()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $swOverNotFound=1;

    $logger->debug("Entered $sub.");

    my $cmd = "SHOW REDUNDANCY GROUP SUMMARY";
    my @result = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub [$cmd] result [@result].");
    foreach ( @result )
    {
        chomp($_);
        if ( m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+ENABLED\s*$/i )
        {
            my $cardType = $1;
            my $redSlotState = $self->getRedundantSlotState($cardType);
            $logger->debug(__PACKAGE__ . ".$sub Card type found = $cardType. Redundant slot state = $redSlotState");
            if ( $redSlotState eq 0 )
            {
                $logger->error(__PACKAGE__ . ".$sub unable to find red-slot info.");
                $logger->debug("Leaving $sub retCode-2.");
                return 2;
            }

            if ( $redSlotState !~ /STANDBY/i )
            {
                $swOverNotFound=0;
                my $protSlot = $self->getProtectedSlot($cardType);
                $logger->debug(__PACKAGE__ . ".$sub Card type found = $cardType. Redundant slot state = $redSlotState. Protected Slot = $protSlot");
                push(@{$self->{SWITCHEDOVER}}, "$cardType, $protSlot");

                my $redSlotState = $self->getRedundantSlotState($cardType);

                my $timeout = 1800;
                my $t0 = [gettimeofday];
                while ( ($redSlotState !~ /ACTIVESYNCED|ACTIVESYNCING/i) &&
                        (tv_interval($t0) <= $timeout) )
                {
                    $logger->debug(__PACKAGE__ . ".$sub redSlotState-$redSlotState, sleeping for 5 secs.");
                    sleep(5);
                    $redSlotState = $self->getRedundantSlotState($cardType);
                }
                if ( ($redSlotState !~ /ACTIVESYNCED|ACTIVESYNCING/i) )
                {
                    # Timer has expired
                    $logger->error(__PACKAGE__ . ".$sub red-slot failed to synch within 5 mins.");
                    $self->{RESET_NODE} = 1;
                }

                $cmd = "CONFIGURE REDUNDANCY GROUP $cardType REVERT";
                my @cResult = $self->execCmd($cmd);
                if ( $self->reconnect() == 0 )
                {
                    $logger->error(__PACKAGE__ . ".$sub could not reconnect after REVERT.");
                    $self->{RESET_NODE} = 1;
                    return 0;
                }
                $redSlotState = $self->getRedundantSlotState($cardType);
                while ( ($redSlotState !~ /STANDBY/i) &&
                        (tv_interval($t0) <= $timeout) )
                {
                    $logger->debug(__PACKAGE__ . ".$sub REVERT redSlotState-$redSlotState, sleeping for 5 secs.");
                    sleep(5);
                    $redSlotState = $self->getRedundantSlotState($cardType);
                }
                if ( $redSlotState !~ /STANDBY/i )
                {
                    $logger->error(__PACKAGE__ . ".$sub red-slot failed to STANDBY mode within 5 mins.");
                    $self->{RESET_NODE} = 1;
                }
            }
        }
        elsif ( m/^error/i )
        {
            $logger->error(__PACKAGE__ . ".$sub [$cmd] failure result - [@result].");
            $logger->debug("Leaving $sub retCode-2.");
            return 2;
        }
    }
 
    $logger->debug("Leaving $sub retCode-$swOverNotFound.");
    return $swOverNotFound;
}

=head1 waitAllRoutingKeys()

    Waits for all M3UA routing keys on the device to reach a specified state.

=over 

=item Arguments : (all optional)

    -timeout					- Default 60s - Overall time to wait for the routing keys to get into the requested state - in seconds.
	 -geographic_redundancy - Default 0   - Set to 1 to select the default pattern match for Goegraphic redundant setup, 0 selects the default pattern for Dual-CE and is the default
	 -custom_match				- Specify a custom match string which all routing keys must match e.g.

		 "act oos oos oos.*ava una una una" - RKeys are registered only to the primary CE, and the destination(s) are available
		 ":282828: 10128:.*act act oos oos.*ava una una una" - Only check RKEYs between PC 40-40-40 and 1-1-40 (ANSI format), RKeys are registered to the primary and secondary CE, but only the primary CE reports the destination as available
		 "txR txR oos oos" - RKeys are attempting to register to the SGX, but no positive response has been received.		 

=item Return Values :

    0 - Failure (timed out before routing keys detected in requested state.
    1 - Success

=item Examples:

    $gsxobj->waitAllRoutingKeys()
    $gsxobj->waitAllRoutingKeys(-timeout => 15, -custom_match => "txR txR oos oos.*una una una una")
    $gsxobj->waitAllRoutingKeys(-geographic_redundancy => 1)

=item Author :

 Malcolm Lashley
 mlashley@sonusnet.com

=back

=cut

sub waitAllRoutingKeys {

	my ($self, %args) = @_;
	my $sub = "waitAllRoutingKeys()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    
	# Set default values before args are processed
	my %a = ( -geographic_redundancy => 0,
             -timeout     => 60,
				 -custom_match => "act act oos oos.*ava ava una una",
			);

	while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
# Todo - someone should move sub _info() from MGTS.pm to Base.pm as its a generically useful debug tool to dump the args passed into a function...
#	$self->_info( -sub => $sub, %a );

	if(defined $args{-geographic_redundancy} and defined $args{-custom_match}) {
		$logger->warn(__PACKAGE__ . ".$sub Invalid arguments supplied: -geographic_redundancy overrides -custom_match with a default active/available string, please make your checks");
		return 0;
	}

	# For GR - we have 4 remote SGP's with which to register, check PC reachability.
	if($a{-geographic_redundancy}) {
		$a{-custom_match} = "act act act act.*ava ava ava ava";
	}

	$self->adminDebugSonus;

   my $startLoopTime    = [gettimeofday];
	my $notready = 1;
	my @rkstates;
	LOOP: while (($notready) and (tv_interval($startLoopTime) < $a{-timeout})) {
		@rkstates = $self->execCmd("m3uark");
		# Strip header/footer
		my @rkstates2;
		foreach (@rkstates) {
			push @rkstates2, $_ unless (m/netApp.*:lpc.*:rpc/) or (m/---:---/) or (m/^$/);
		}
	   $logger->info (__PACKAGE__ . ".$sub Waiting for active/available routing keys... time remaining " . ($a{-timeout} - tv_interval($startLoopTime)));
		$notready = 0;
		foreach (@rkstates2) {
			if (m/$a{-custom_match}/) {
			   $logger->debug(__PACKAGE__ . ".$sub Found matching routing keys [ $_ ]");
			} else {
			   $logger->info(__PACKAGE__ . ".$sub Found non-matching routing key - will recheck [ $_ ]"); 
				$notready += 1 ;
			}
		}
		sleep 2 if $notready;
	}
	if ($notready) {
		$logger->error(__PACKAGE__ . ".$sub Unable to get all routing keys active at GSX - Timed out. Current state:\n" . Dumper(\@rkstates));
		return 0;
	}

	return 1;

}

#=pod
#
#=head1 clearLog()
#
#    Start over the log before a test case starts
#
#Arguments :
#
#    None
#
#Return Values :
#
#    0 - Failed
#    1 - Completed
#
#Example :
#    $gsxobj->clearLog()
#
#Author :
#
#Avinash Chandrashekar (achandrashekar@sonusnet.com)
#Susanth Sukumaran (ssukumaran@sonusnet.com)
#
#=cut
#
sub clearLog {
   my($self) = @_;
   my $sub = "clearLog()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub CLEARING GSX LOG");

   my $r_cmd1="CONFIGURE EVENT LOG ALL ROLLFILE NOW";

   $logger->info(__PACKAGE__ . ".$sub Executing $r_cmd1");

   if ($self->execCmd($r_cmd1)) {
      # Check the command execution status

     foreach(@{$self->{CMDRESULTS}}) {

         chomp($_);
         # Error if error string returned
         if (m/^error/i) {
            $logger->error(__PACKAGE__ . ".$sub CMD RESULT: $_");
            $logger->debug(__PACKAGE__ . ".$sub Leaving function retcode-0");
            return 0;
         }
      } 
   }

   $logger->info(__PACKAGE__ . ".$sub command output \n@{$self->{CMDRESULTS}}");


   my $ref_ar = $self->nameCurrentFiles;
   my ($ACTfile, $DBGfile, $SYSfile, $TRCfile) = @$ref_ar;
  
   $self->{DBGfile}            = $DBGfile;
   $self->{SYSfile}            = $SYSfile;
   $self->{ACTfile}            = $ACTfile;
   $self->{TRCfile}            = $TRCfile;

   $logger->info( "GSX LOG FILES ROLLED");
   
   return 1;
}

=pod

=head1 getGSXLog()

    Get the GSX logs File ACT DBG and SYS 

Arguments :
	None

Return Values :


  0 if file is not copied
  1 if file is copied

Example :
            $gsx_obj->getGSXLog;

Author :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=cut

sub getGSXLog {
   my ($self)=@_;
   my $sub = "getGSXLog()";
   my ($atsloc, $path, @cmdresults, @dbglog, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, $dbglogname, $dbglogfullpath, $dsiObj, $dbgfile, $syslogname, $syslogfullpath, $sysfile, $actlogname, $actlogfullpath, $actfile);
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE GSX DBG LOG");

   # Get node name
   $cmd = "show node admin";
   @cmdresults = $self->execCmd($cmd);
   foreach (@cmdresults) {
      if ( m/Name:\s+(\w+)/ ) {
         $nodename = $1;
         $nodename =~ tr/[a-z]/[A-Z]/;
      }
   }

   $nodename = uc($nodename);
   $logger->info(__PACKAGE__ . ".$sub node name : $nodename");

   if (!defined($nodename)) {
      $logger->warn(__PACKAGE__ . ".$sub NODE NAME MUST BE DEFINED");
      return $nodename;
   }

   $logger->info(__PACKAGE__ . ".$sub Got the Node Name = $nodename");

   # Get IP address and path of active NFS
   $cmd = "show nfs shelf 1 slot 1 status";
   @cmdresults = $self->execCmd($cmd);
   foreach (@cmdresults) {
      if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/ ) {
         $activenfs = $1;
      }
      if (defined $activenfs) {
         if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
            $nfsipaddress = $2;
            $nfsmountpoint = $3;
	$logger->info(__PACKAGE__ . ".$sub NFS IP Address => $nfsipaddress and NFS MOUNT POINT => $nfsmountpoint");
            last;
         }
      }
   }

   # Get chassis serial number
   $cmd = "show chassis status";
   @cmdresults = $self->execCmd($cmd);
   foreach(@cmdresults) {
      if(m/Serial Number:\s+(\d+)/) {
         $serialnumber = $1;
	$logger->info(__PACKAGE__ . ".$sub Log Serial No. => $serialnumber ");
      }
   }

   # Determine name of active DBG log
   $cmd = "show event log all status";
   @cmdresults = $self->execCmd($cmd);

   foreach(@cmdresults) {
      if (m/(\w+).DBG/) {
         $dbglogname = "$1";
      }
      if (m/(\w+).SYS/) {
         $syslogname = "$1";
      }
      if (m/(\w+).ACT/) {
         $actlogname = "$1";
      }
   }
   
   
  $self->{ACTfile} =~ m/(\w+).ACT/;
  my $startACTfile = $1;
  $self->{DBGfile} =~ m/(\w+).DBG/;
  my $startDBGfile = $1;
  $self->{SYSfile} =~ m/(\w+).SYS/;
  my $startSYSfile = $1;
  
  my (@ACTlist, @DBGlist, @SYSlist);

  while ($startACTfile le $actlogname) {
    $logger->debug(__PACKAGE__ . ".$sub $startACTfile = $startACTfile");
    push @ACTlist, ($startACTfile. ".ACT");
    $startACTfile = hex_inc($startACTfile);
  }
  
  while ($startDBGfile le $dbglogname) {
    $logger->debug(__PACKAGE__ . ".$sub $startDBGfile = $startDBGfile");
    push @DBGlist, ($startDBGfile. ".DBG");
    $startDBGfile = hex_inc($startDBGfile);
  }

  while ($startSYSfile le $syslogname) {
    $logger->debug(__PACKAGE__ . ".$sub $startSYSfile = $startSYSfile");
    push @SYSlist, ($startSYSfile. ".SYS");
    $startSYSfile = hex_inc($startSYSfile);
  }

   if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {
      my $add_path="/sonus";
      # Create full path to log
	      	#$dbgfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname" . ".DBG";
      		#$actfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$actlogname" . ".ACT";
      		#$sysfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$syslogname" . ".SYS";
		   my $timeout = 300;
		   my $ats_dir = "/home/autouser/gsxlogs/";




		   # Open a session for SFTP
		   my $sftp_session = new SonusQA::Base( -obj_host       => '10.128.96.76',
                                         -obj_user       => "autouser",
                                         -obj_password   => "autouser",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                       );
		   unless ( $sftp_session ) {
		      $logger->error(__PACKAGE__ . ".$sub Could not open connection to mallrats");
		      return 0;
		   }
		   
	  foreach $dbglogname (@DBGlist) {
	    $dbgfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname" ;
	    $atsloc = "$ats_dir" ."$dbglogname" ;
	    if ( $sftp_session->{conn}->cmd("/bin/cat $dbgfile > $atsloc")) {
	        $logger->debug(__PACKAGE__ . ".$sub $path transfer success");
	        $logger->debug(__PACKAGE__ . ".$sub Executed the CMD ==> /bin/cat $dbgfile > $atsloc");
      		  sleep 5;
	        }
	    else {
	        $logger->error(__PACKAGE__ . ".$sub failed to copy the GSX DBG log file");
	        }
	  }
	  
	  foreach $actlogname (@ACTlist) {
	    $actfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$actlogname" ;
	    $atsloc = "$ats_dir" ."$actlogname" ;
		   if ( $sftp_session->{conn}->cmd("/bin/cat $actfile > $atsloc")) {
        		$logger->info(__PACKAGE__ . ".$sub $path transfer success");
        		$logger->info(__PACKAGE__ . ".$sub Executed the CMD ==> /bin/cat $actfile > $atsloc");
        		sleep 5;
        		}
		   else {
        		$logger->error(__PACKAGE__ . ".$sub failed to copy the GSX ACT log file");
        		}
	  }

	  foreach $syslogname (@SYSlist) {  
	    $sysfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$syslogname" ;
	    $atsloc = "$ats_dir" ."$syslogname" ; 
   		if ( $sftp_session->{conn}->cmd("/bin/cat $sysfile > $atsloc")) {
        		$logger->info(__PACKAGE__ . ".$sub $path transfer success");
        		$logger->info(__PACKAGE__ . ".$sub Executed the CMD ==> /bin/cat $sysfile > $atsloc");
        		sleep 5;
        		}
		   else {
        		$logger->error(__PACKAGE__ . ".$sub failed to copy the GSX SYS log file");
        		}
	  }
	  
	$sftp_session->DESTROY; 
        return (@DBGlist, @ACTlist, @SYSlist);
	}
else {
        $logger->warn(__PACKAGE__ . "NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2..");
        return 0;
        }

    return (@DBGlist, @ACTlist, @SYSlist);
}

=pod

=head1 deleteGSXLog()

    Delete the GSX logs File ACT DBG and SYS

Arguments :

        None

Return Values :

  0 if file is not deleted
  1 if file is deleted

Example :
            $gsx_obj->deleteGSXLog;

Author :

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut

sub deleteGSXLog {
    my ($self)=@_;
    my $sub = "deleteGSXLog()";
    my ($atsloc, $path, @cmdresults, @dbglog, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, $dbglogname, $dbglogfullpath, $dsiObj, $dbgfile, $syslogname, $syslogfullpath, $sysfile, $actlogname, $actlogfullpath, $actfile);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub DELETING ACTIVE GSX DBG LOG");
    my $nfsSessObj;
   
    #get SYSLOG files lists
    my $logDetails = $self->getGsxLogDetails(-logType =>'SYS');
    my %logDetails = %{$logDetails};
    $logger->info(".$sub \nNFS-IP: $logDetails{-nfsIp} \nLOG-PATH: $logDetails{-logPath} \nREMOTE-COPY: $logDetails{-remoteCopy} \nNODE-NAME: $logDetails{-nodeName} \nNfsMountPoint: $logDetails{-nfsMountPoint} \nSerial number : $logDetails{-serialNumber}");
    $logger->info(".$sub SYS LOG-FILES: @{$logDetails{-fileNames}} ");
    my @SYSlist = @{$logDetails{-fileNames}};

    $nfsipaddress = $logDetails{-nfsIp};
    $nfsmountpoint = $logDetails{-nfsMountPoint};
    $serialnumber = $logDetails{-serialNumber};
    $nodename = $logDetails{-nodeName};
    my $serverFlag = $logDetails{-remoteCopy};
    

    #get DBGLOG files lists
    $logDetails = $self->getGsxLogDetails(-logType =>'DBG');
    %logDetails = %{$logDetails};
    $logger->info(".$sub  DBG-LOG-FILES: @{$logDetails{-fileNames}} ");
    my @DBGlist = @{$logDetails{-fileNames}};

    #get ACTLOG files lists
    $logDetails = $self->getGsxLogDetails(-logType =>'ACT');
    %logDetails = %{$logDetails};
    $logger->info(".$sub  ACT-LOG-FILES: @{$logDetails{-fileNames}} ");
    my @ACTlist = @{$logDetails{-fileNames}};


    if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {

        if($serverFlag eq 1){
     	    #my $add_path="/sonus";
      	    # Create full path to log
            #$dbgfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname" . ".DBG";
            #$actfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$actlogname" . ".ACT";
            #$sysfile = "$add_path$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$syslogname" . ".SYS";

            my $nfsUserId = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
  	    my $nfsPasswd = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};

	    #Now make SFTP to NFS server
	    $nfsSessObj = new Net::SFTP( $nfsipaddress,
                                      user     => $nfsUserId,
                                      password => $nfsPasswd,
                                      debug    => 0,);

            unless ($nfsSessObj) {
                $logger->error("Could not open sftp connection to NFS server --> $nfsipaddress");
                return 0;
            }
            $logger->info("SFTP connection to NFS server  $nfsipaddress is successfull");
	}

        foreach $dbglogname (@DBGlist) {
            if($serverFlag eq 0){
                $dbgfile = "$nfsmountpoint" ."/" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname" ;
                qx#rm -rf $dbgfile#;
                if(-e $dbgfile){
                    $logger->info(__PACKAGE__ . ".$sub log file $dbgfile not deleted");
		    return 0;
                }else{
              	    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $dbgfile");
                }
            }elsif($serverFlag eq 1){
                $dbgfile = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname" ;
                if($nfsSessObj->do_remove($dbgfile)){
                    $logger->info(__PACKAGE__ . ".$sub log file $dbgfile not deleted");
	            return 0;
                }else{
                    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $dbgfile");
                }
            }
        }    

        foreach $actlogname (@ACTlist) {
            if($serverFlag eq 0){
                $actfile = "$nfsmountpoint" ."/" . "/evlog/" . "$serialnumber" . "/ACT/" . "$actlogname" ;
                qx#rm -rf $actfile#;
                if(-e $actfile){
                    $logger->info(__PACKAGE__ . ".$sub log file $actfile not deleted");
                    return 0;
                }else{
                    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $actfile");
                }
            }elsif($serverFlag eq 1){
                $actfile = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/ACT/" . "$actlogname" ;
                if($nfsSessObj->do_remove($actfile)){
                    $logger->info(__PACKAGE__ . ".$sub log file $actfile not deleted");
                    return 0;
                }else{
                    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $actfile");
                }
            }
        }
        foreach $syslogname (@SYSlist) {
            if($serverFlag eq 0){
                $sysfile = "$nfsmountpoint" ."/" . "/evlog/" . "$serialnumber" . "/SYS/" . "$syslogname" ;
                qx#rm -rf $sysfile#;
                if(-e $sysfile){
                    $logger->info(__PACKAGE__ . ".$sub log file $sysfile not deleted");
                    return 0;
                }else{
                    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $sysfile");
                }
            }elsif($serverFlag eq 1){
                $sysfile = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/SYS/" . "$syslogname" ;
                if($nfsSessObj->do_remove($sysfile)){
                    $logger->info(__PACKAGE__ . ".$sub log file $sysfile not deleted");
                    return 0;
                }else{
                    $logger->info(__PACKAGE__ . ".$sub successfully deleted the log file $sysfile");
              	}
            }
        }
        return 1;
    }   
    else {
        $logger->warn(__PACKAGE__ . "NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2..");
        return 0;
    }
}

=pod

=head1 getGsxLogDetails()

    This API gets the logtype as input and it returns the array containing list of all the files corresponding to that specified log(In case if the script produces 2 or more ACT/DBG/SYS log files for one single tests ),along with the NFS details.

Arguments :

        -logType => ['SYS','DBG','ACT'].

Return Values :

  0 if fail
  1 if success

Example :
            $gsx_obj->getGsxLogDetails(-logType => 'SYS');

Author :

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut


sub getGsxLogDetails{

    my ($self,%args) = @_;
    my $sub = "getGsxLogDetails";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my($cmd,$remoteFlag,$logpath,$serialnumber,@cmdresults,$NFSFlag,$dbglogname,$actlogname,$syslogname,$startDBGfile,$startACTfile,$startSYSfile);
    my(@logList);
    my %logDetails;

    $logger->info(__PACKAGE__ . ".$sub Entered sub getGsxLogFileList ");

    #check if mandatory argument specified
    unless(defined ($args{-logType})){
        $logger->info(__PACKAGE__ . ".$sub -logType not specified");
        return 0;
    }

    my($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    $logger->info(__PACKAGE__ . ".$sub Node : $nodename,  NFS-IP: $nfsipaddress,  MOUNTPOINT: $nfsmountpoint");

    if (!defined($nodename || !defined($nfsipaddress) || !defined($nfsmountpoint))) {
        $logger->warn(__PACKAGE__ . ".$sub NODE NAME MUST BE DEFINED IN GSX");
        return 0;
    }

    #Get chassis serial number
    $cmd = "show chassis status";
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
       if(m/Serial Number:\s+(\d+)/) {
           $serialnumber = $1;
           $logger->info(__PACKAGE__ . ".$sub Log Serial No. => $serialnumber ");
       }
    }


    if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {

        $NFSFlag = 0;
        if($nfsmountpoint =~ /^\/vol/){
            my $basePath = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};
            if ($basePath =~ /SonusNFS/) {
                $logger->info("Base path mentiond in TMS is --> $basePath");
                $nfsmountpoint = $basePath;
                $logger->info(__PACKAGE__ . ".$sub   NFSMOUNTPOINT : $nfsmountpoint ");
                $NFSFlag = 1;
            }else {
                $logger->error("Unable to get base path from TMS");
                $logger->error("Check your TMS entry for BASEPATH");
                return 0;
            }
        }
    }

    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);

    $logger->info(__PACKAGE__ . ".$sub Command output : @cmdresults");	

    foreach(@cmdresults) {

        if (m/(\w+).DBG/) {
            $dbglogname = "$1";

            if($args{-logType} =~ m/DBG/){ 
                $self->{DBGfile} =~ m/(\w+).DBG/;
                my $startDBGfile = $1;
		$logger->info(__PACKAGE__ . ".$sub current DBGlog  : $dbglogname");
                $logger->info(__PACKAGE__ . ".$sub starting DBGlog  : $startDBGfile");

                while ($startDBGfile le $dbglogname) {
                    push @logList, ($startDBGfile. ".DBG");
                    $startDBGfile = hex_inc($startDBGfile);
                }
	    }
        }
        if (m/(\w+).ACT/) {
            $actlogname = "$1";
	    if ( $self->{ACTfile} ) {
                if($args{-logType} =~ m/ACT/){
                    $self->{ACTfile} =~ m/(\w+).ACT/;
                    my $startACTfile = $1;
	    	    $logger->info(__PACKAGE__ . ".$sub current ACTlog  : $actlogname");
		    $logger->info(__PACKAGE__ . ".$sub starting ACTlog  : $startACTfile");

                    while ($startACTfile le $actlogname) {
                        push @logList, ($startACTfile. ".ACT");
                        $startACTfile = hex_inc($startACTfile);
                    }
	        }
	    } else {
		$logger->info(__PACKAGE__ . ".$sub getting the latest ACT log..");
		my $ACT_file = $self->getCurLogPath("ACT");	
		push @logList, $ACT_file;
	    }
        }
        if (m/(\w+).SYS/) {
            $syslogname = "$1";

            if($args{-logType} =~ m/SYS/){
                $self->{SYSfile} =~ m/(\w+).SYS/;
                my $startSYSfile = $1;
		$logger->info(__PACKAGE__ . ".$sub current SYSlog  : $syslogname");
	        $logger->info(__PACKAGE__ . ".$sub starting SYSlog  : $startSYSfile");

                while ($startSYSfile le $syslogname) {
                    push @logList, ($startSYSfile. ".SYS");
                    $startSYSfile = hex_inc($startSYSfile);
                }
	    }
	}
    }

    if($NFSFlag eq 1){
        $logpath = "$nfsmountpoint" ."/" . "/evlog/" . "$serialnumber" . "/$args{-logType}/" ;
        $logger->info(__PACKAGE__ . ".$sub  LogPath : $logpath ");
        $remoteFlag = 0;
    }else{
        $logpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/$args{-logType}/";
        $logger->info(__PACKAGE__ . ".$sub  LogPath : $logpath ");
        $remoteFlag = 1;
    }

    %logDetails = ( -nfsIp         => $nfsipaddress,
                    -logPath       => $logpath,
                    -fileNames     => \@logList,
                    -remoteCopy    => $remoteFlag,
                    -nodeName      => $nodename,
		    -nfsMountPoint => $nfsmountpoint,
		    -serialNumber  => $serialnumber,
                         );

    $logger->info(__PACKAGE__ . ".$sub $logDetails{'-nfsIp'}, $logDetails{'-logPath'},  $logDetails{'-remoteCopy'} , $logDetails{'-nodeName'}") ;
    return {%logDetails};
}




sub nameCurrentFiles {
  my $self = shift;
  my $sub = "nameCurrentFiles()";
  my ($dbglogname, $syslogname, $actlogname, $trclogname, $cmd, @cmdresults);
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub Getting current log names");
   # Determine name of active file names
   $cmd = "show event log all status";
   @cmdresults = qw();
   @cmdresults = $self->execCmd($cmd);
 
   $logger->debug(__PACKAGE__ . ".$sub  command result \n@cmdresults\n");

   foreach(@cmdresults) {
      if (m/(\w+.DBG)/) {
         $dbglogname = "$1";
      }
      if (m/(\w+.SYS)/) {
         $syslogname = "$1";
      }
      if (m/(\w+.ACT)/) {
         $actlogname = "$1";
      }
      if (m/(\w+.TRC)/) {
         $trclogname = "$1";
      }
   }
  # if ACT is not available just return INVALID.
  if( !defined ($actlogname) ) {
     $actlogname = "INVALID_ACT";
  }

  if( !defined ($trclogname) ) {
     $trclogname = "INVALID_TRC";
  }

  $logger->debug(__PACKAGE__ . ".$sub $actlogname, $dbglogname, $syslogname, $trclogname");

  my @retval = ("$actlogname", "$dbglogname", "$syslogname", "$trclogname");
  return \@retval;
}

sub hex_inc {
    my ($hextail, $hexhead, $remember_tail_zeros, $tail_len, $remember_head_zeros, $head_len);
    my $hexstring = shift;
    my $len = length $hexstring;
    if ($len > 5) {
        $hextail = substr $hexstring, -5;
        $hexhead = substr $hexstring, 0, ($len-5);
    }
    else {
        $hextail = $hexstring;
        $hexhead = -1;
    }
    
    $remember_tail_zeros = "";
    $hextail =~ /^([0]*)(.*)/;
    $remember_tail_zeros = $1;
    $hextail = $2;
    
    if (!defined($hextail) | ($hextail eq "")) {
        $hextail = 0;
        $remember_tail_zeros = substr $remember_tail_zeros, 0, ((length $remember_tail_zeros) -1);
    }
    
    $tail_len = length $hextail;
    $hextail = hexaddone ($hextail);
    
    if ((length $hextail > $tail_len) && ($remember_tail_zeros ne "" )) {
        $remember_tail_zeros = substr $remember_tail_zeros, 0, ((length $remember_tail_zeros) -1);
    }
    
    $remember_head_zeros = "";
    if ((length $hextail > 5) && ($hexhead != -1)) {
        $remember_head_zeros = "";
        $hexhead=~ /^([0]*)(.*)/;
        $remember_head_zeros = $1;
        $hexhead = $2;
        if (!defined($hexhead) | ($hexhead eq "")) {
            $hexhead = 0;
            $remember_head_zeros = substr $remember_head_zeros, 0, ((length $remember_head_zeros) -1);
        }
        
        $head_len = length $hexhead;
        $hexhead = hexaddone ($hexhead);
    
        if ((length $hexhead > $head_len) && ($remember_head_zeros ne "" )) {
            $remember_head_zeros = substr $remember_head_zeros, 0, ((length $remember_head_zeros) -1);
        }
    
        $hextail = substr $hextail, -5;
    }
    
    if ($hexhead == -1) {
        $hexstring = $remember_tail_zeros . $hextail;
    }
    else {
        $hexstring = $remember_head_zeros . $hexhead . $remember_tail_zeros . $hextail;
    }
    
    return $hexstring;
}


sub hexaddone {
    my $hexin = shift;
    my $hex = '0x'.$hexin;
    my $dec = hex($hex);
    $dec++;
    my $hexout = sprintf "%X", $dec;
    return $hexout;
}
=pod

=head1 sourceTclFile()

This subroutine is same as sourceGsxTclFile. This subroutine needs to be used, when the test case is been run from a system, where mount can not be done.

Assumption :

   None

Arguments :

 -tcl_file
    name of the tcl file
 -doNotUseC
    Optional : set as 1, if ../C/ not to be used with the TCL file


Return Values :

 1 - success ,when tcl file is executed without errors and end tag "SUCCESS" is reached
 0 - failure , error occurs during execution or inputs are not specified

Example :

 \$obj->sourceGsxTclFile(-tcl_file => "ansi_cs.tcl");

Author :

Susanth Sukumaran (ssukumaran@sonusnet.com)

=cut

sub sourceTclFile() {

   my($self,%args) = @_;
   my $sub = "sourceTclFile()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %a = (-doNotUseC => 0);

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $tcl_file = $a{-tcl_file};

   # Error if tcl_file is not set
   unless (defined $tcl_file && $tcl_file !~ /^\s*$/ ) {
      $logger->error(__PACKAGE__ . ".$sub tcl file is not specified or is blank");
      return 0;
   }

   my $cmd;
   
   if($a{-doNotUseC} eq 0) {
      $cmd = "source ../C/$tcl_file";
   } else {
      $cmd = "source $tcl_file";
   }
        
   # Source the tcl file in gsx
   my $default_timeout = $self->{DEFAULTTIMEOUT};
   $self->{DEFAULTTIMEOUT} = 400;
   my @cmdresults = $self->execCmd($cmd); 
   $self->{DEFAULTTIMEOUT} = $default_timeout;

   # $logger->debug(__PACKAGE__ . ".$sub @cmdresults");

   foreach(@cmdresults) {

      chomp($_);

      # Checking for SUCCESS tag
      if (m/^SUCCESS/) {
         $logger->debug(__PACKAGE__ . ".$sub CMD RESULT: $_");
         $logger->debug(__PACKAGE__ . ".$sub Successfully sourced GSX TCL file: $tcl_file");
         return 1;
      } elsif (m/^error/) {
         unless (m/^error: Unrecognized input \'3\'.  Expected one of: VERSION3 VERSION4/) {
            $logger->error(__PACKAGE__ . ".$sub Error occurred during execution : $_");
            return 0;
         }
      }
   } # End foreach 

   # If we get here, script has not been successful
   $logger->error(__PACKAGE__ . ".$sub SUCCESS string not found, nor error string. Unknown failure.");
   return 0;
}

=pod

=head1 checkCore()

This subroutine is similar to gsxCoreCheck. This subroutine needs to be used, when the test case is been run from a system, where NFS is not mounted

Assumption :

   None

Arguments :
     -testCaseID => Test case ID

Optional Arguments:
     -dsp => Set this to 1 if you are checking for dsp trace files instead of coredump file

Return Values :
     Number of core files generated, if any.
     -1 - Incase there was an error in determining if Core files were generated or not
      0 - Incase no core files were generated

Example :


Author :

Rodrigues, Kevin (krodrigues@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

Modified By : Sowmya Jayaraman(sjayaraman@sonusnet.com)

=cut

sub checkCore {
   my ($self, %args) = @_;
   my $sub = "checkCore()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
   $logger->debug(__PACKAGE__ . ".$sub: Entered Sub -->");

   # Set default values before args are processed
   my %a;
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my ($cmd,$conn1,$dsiObj,@coreFiles,$numcore);

   if (!defined ($self->{nfs_session})) {
     $conn1 = $self->connectToNFS();
     if ($conn1 == 0)
     {
       $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [-1]");
       return -1;
     }
   }

   if (!defined ($self->{CORE_DIR})) {
     my $GsxSWPath = $self->findGsxSWPath();
     unless($GsxSWPath) {
       $logger->error(__PACKAGE__ . ".$sub Unable to find Software Path from GSX");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [-1]");
       return -1;
     }
     my $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};

     $self->{CORE_DIR} = "$nfsmountpoint/$GsxSWPath/coredump";
     # Remove double slashes if present
     $self->{CORE_DIR} =~ s|//|/|;    
   }
   my $core;
   if (defined $a{-dsp} and $a{-dsp} == 1){
     $cmd = "ls -1 $self->{CORE_DIR}/dsp*"; 
     $logger->debug(__PACKAGE__. ".$sub Checking for dsp trace files ");
     $core = "DSP trace";
   }else {
     $cmd = "ls -1 $self->{CORE_DIR}/core*";
     $core = "core";
   }

   $logger->debug(__PACKAGE__ . ".$sub Executing command $cmd");

   $dsiObj = $self->{nfs_session};
   @coreFiles = $dsiObj->{conn}->cmd($cmd);

   $logger->debug(__PACKAGE__ . ".$sub @coreFiles");

   foreach(@coreFiles) {
      if(m/No such file or directory/i) {
         $logger->info(__PACKAGE__ . ".$sub No $core found");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
      }
   }

   # Get the number of core files
   $numcore = $#coreFiles + 1;

   $logger->info(__PACKAGE__ . ".$sub Number of $core files in GSX is $numcore");

   # Move all core files
   foreach (@coreFiles) {
      if($_ =~ /$cmd/) {
         #skip the first line. It may the command
         $logger->info(__PACKAGE__ . ".$sub Omitting the commmand as it is not a $core file");
         next;
      }
      my $core_timer = 0;
      chomp($_);
      my $file_name = $_;

      # wait till core file gets generated full
      while ($core_timer < 120) {
         # get the file size
         $cmd = "ls -l $file_name";

         my @fileDetail = $dsiObj->{conn}->cmd($cmd);

         $logger->info(__PACKAGE__ . ".$sub @fileDetail");

         my $fileInfo;

         #start_size of the core file
         my $start_file_size;

         foreach $fileInfo (@fileDetail) {
            if($fileInfo =~ /$cmd/) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;

            $start_file_size = $1;
         }

         $logger->debug(__PACKAGE__ . ".$sub Start File size of $core is $start_file_size");

         sleep(5); 
         $core_timer = $core_timer + 5;

         #end_size of the core file;
         my $end_file_size;
         @fileDetail = $dsiObj->{conn}->cmd($cmd);

         foreach $fileInfo (@fileDetail) {
            if($fileInfo =~ /$cmd/) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;

            $end_file_size = $1;
         }

         $logger->debug(__PACKAGE__ . ".$sub End File size of $core is $end_file_size");

         if ($start_file_size == $end_file_size) {
            $file_name =~ s/$self->{CORE_DIR}\///g;
            my $name = join "_",$args{-testCaseID},$file_name;

            # Rename the core to filename with testcase specified
            $cmd = "mv $self->{CORE_DIR}/$file_name $self->{CORE_DIR}/$name";
            my @retCode = $dsiObj->execCmd($cmd);
            $logger->error(__PACKAGE__ . ".$sub $core found in $self->{CORE_DIR}/$name");
            last;
         }
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$numcore]");
   return $numcore;
} 

=pod

=head1 getGSXLog2()

    This is same as getGSXLog subroutine. This subroutine to be used when the NFS
    is not mounted in the system being test case is run
    WILL FAIL IF FILE ALREADY EXISTS AT DESTINATION

=over 

=item Arguments :

   Mandatory :
      -testCaseID  => test case id
      -logDir      => Logs are stored in this directory
   Optional :
      -variant     => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
      -logType     => Log Types to copy e.g. 'system','debug','trace', 'account'
                   Default => ["system", "debug"]

      -timeStamp   => Time stamp
                   Default => "00000000-000000"

=item Return Values :

   0 - if file is not copied
   (@arr1, @arr2) - file Names

=item Example :

   $gsx_obj->getGSXLog2(-testCaseID => $testId,
                        -logDir     => $log_dir);
   $gsx_obj->getGSXLog2(-testCaseID => $testId,
                        -logDir     => $log_dir,
                        -variant    => "ANSI",
                        -timeStamp  => "20101005-080937",
                        -logType    => ["account", "debug"]);

=item Author :

 Rodrigues, Kevin (krodrigues@sonusnet.com)
 Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub getGSXLog2 {
   my ($self, %args)=@_;
   my $sub = "getGSXLog2()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE GSX DBG LOG");

   # Set default values before args are processed
   my %a = ( -variant   => "NONE",
             -timeStamp => "00000000-000000",
             -logType   => ["system", "debug"]);

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my @logTypes = @{$a{-logType}};
   my $cmd;
   my @cmdresults;
   my $nfsipaddress  = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
   my $NFS_userid    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
   my $NFS_passwd    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
   my $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};       

   $logger->info(__PACKAGE__ . ".$sub NFS IP Address => $nfsipaddress and NFS MOUNT POINT => $nfsmountpoint");

   ####################################################
   # Step 1: Checking mandatory args;
   ####################################################
   unless ($nfsipaddress) {
      $logger->warn(__PACKAGE__ . ".$sub NFS IP Address MUST BE DEFINED");
      return 0;
   }
   unless ($NFS_userid) {
      $logger->warn(__PACKAGE__ . ".$sub NFS User ID MUST BE DEFINED");
      return 0;
   }
   unless ($NFS_passwd) {
      $logger->warn(__PACKAGE__ . ".$sub NFS Password MUST BE DEFINED");
      return 0;
   }         
   unless ($nfsmountpoint) {
      $logger->warn(__PACKAGE__ . ".$sub NFS Mount Point MUST BE DEFINED");
      return 0;
   }

   ####################################################
   # Step 2: Obtain data from GSX;
   ####################################################
   # Get chassis serial number
   $cmd = "show chassis status";
   $logger->debug(__PACKAGE__ . ".$sub Executing command $cmd");
   @cmdresults = $self->execCmd($cmd);
   $logger->debug("------------------ COMMAND OUTPUT -----------------------");
   foreach (@cmdresults) {
       $logger->debug("$_");
   }
   $logger->debug("-------------- COMMAND OUTPUT ENDS ----------------------");
   my $serialnumber;
   foreach(@cmdresults) {
      if(m/Serial Number:\s+(\d+)/) {
         $serialnumber = $1;
         $logger->debug(__PACKAGE__ . ".$sub Log Serial No. => $serialnumber ");
      }
   }

   # Check NFS path
   if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {
      $logger->debug(__PACKAGE__ . ".$sub got the mount point. $nfsmountpoint");
   } else {
      $logger->warn(__PACKAGE__ . "NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2..");
      return 0;
   }

   # Determine name of active DBG log
   $cmd = "show event log all status";
   $logger->debug(__PACKAGE__ . ".$sub Executing command $cmd");
   @cmdresults = $self->execCmd($cmd);
   $logger->debug("------------------ COMMAND OUTPUT -----------------------");
   foreach (@cmdresults) {
       $logger->debug("$_");
   }
   $logger->debug("-------------- COMMAND OUTPUT ENDS ----------------------");

   my $dbglogname;
   my $syslogname;
   my $actlogname;
   my $trclogname;

   foreach (@cmdresults) {
      if (m/(\w+).DBG/) {
         $dbglogname = "$1";
      }
      if (m/(\w+).SYS/) {
         $syslogname = "$1";
      }
      if (m/(\w+).ACT/) {
         $actlogname = "$1";
      }
      if (m/(\w+).TRC/) {
         $trclogname = "$1";
      }
   }

   # Populated?
   foreach (@logTypes) {
       if ( (!$dbglogname) && (m/debug/i) ) {
           $logger->error(__PACKAGE__ . ".$sub: DEBUG logs are not activated in GSX");
           return 0;
       }

       if ( (!$syslogname) && (m/system/i) ) {
           $logger->error(__PACKAGE__ . ".$sub: SYSTEM logs are not activated in GSX");
           return 0;
       }

       if ( (!$actlogname) && (m/account/i) ) {
           $logger->error(__PACKAGE__ . ".$sub: ACCOUNTING logs are not activated in GSX");
           return 0;
       }

       if ( (!$trclogname) && (m/trace/i) ) {
           $logger->error(__PACKAGE__ . ".$sub: TRACE logs are not activated in GSX");
           return 0;
       }

   }
   $logger->debug(__PACKAGE__ . ".$sub The Start file names => $self->{DBGfile}, $self->{SYSfile}, $self->{ACTfile}, $self->{TRCfile}");

   #######################################################
   # Step 3: Call &SonusQA::Base::secureCopy to SCP files
   #######################################################

   # Create full path to log
   my $timeout = 300;
   my $ats_dir = $a{-logDir};

   # Start filename
   my ($gsxLogType, $startLogFile, $endLogFile, $remainder, @logFileList, $logName);

   foreach $gsxLogType (@logTypes) {
       if ( $gsxLogType eq "debug") {
           $self->{DBGfile} =~ m/(\w+).(DBG)/;
           $startLogFile = $1;
           $endLogFile   = $dbglogname;
           $remainder    = 'DBG';
           # Empty $startDBGfile
           if ( length($startLogFile) < 5 ){
               $logger->debug(__PACKAGE__ . ".$sub  startDBGfile not set");
               $startLogFile = $dbglogname;
           } 
       } elsif ( $gsxLogType eq "system") {
           $self->{SYSfile} =~ m/(\w+).(SYS)/;
           $startLogFile = $1;
           $endLogFile   = $syslogname;
           $remainder    = 'SYS';
           # Empty $startSYSfile
           if ( length($startLogFile) < 5 ){
               $logger->debug(__PACKAGE__ . ".$sub  startSYSfile not set");
               $startLogFile = $syslogname;
           }
       } elsif ( $gsxLogType eq "account") {
           $self->{ACTfile} =~ m/(\w+).(ACT)/;
           $startLogFile = $1;
           $endLogFile   = $actlogname;
           $remainder    = 'ACT';
           # Empty $startACTfile
           if ( length($startLogFile) < 5 ){
               $logger->debug(__PACKAGE__ . ".$sub  startACTfile not set");
               $startLogFile = $actlogname;
           }
       }  elsif ( $gsxLogType eq "trace") {
           $self->{ACTfile} =~ m/(\w+).(TRC)/;
           $startLogFile = $1;
           $endLogFile   = $trclogname;
           $remainder    = 'TRC';
           # Empty $startTRCfile
           if ( length($startLogFile) < 5 ){
               $logger->debug(__PACKAGE__ . ".$sub  startTRCfile not set");
               $startLogFile = $trclogname;
           }
       } else {
           $logger->error(__PACKAGE__ . ".$sub: Invalid log type");
           return 0;
       }

       $logger->debug(__PACKAGE__ . ".$sub: LogType -> $gsxLogType, startFile -> $startLogFile, endFile -> $endLogFile remainder -> $remainder"); 

       # Check for Log number wrapping back to 0
       if ($endLogFile lt $startLogFile) {
           # Max File Count 32, could be obtained from GSX SHOW EVENT LOG ALL ADMIN
           while ($endLogFile lt $startLogFile) {
               push @logFileList, ($startLogFile . "\.$remainder");
               $startLogFile = hex_inc($startLogFile);
               # Default File Count 32 (Decimal), could be obtained from GSX SHOW EVENT LOG ALL ADMIN
                if ($startLogFile eq 1000021) {$startLogFile = 1000001;}
           }
       }

       # Add logs
       while ($startLogFile le  $endLogFile) {
           $logger->debug(__PACKAGE__ . ".$sub startFile -> $startLogFile, endFile -> $endLogFile");
           push @logFileList, ($startLogFile . "\.$remainder");
           $startLogFile = hex_inc($startLogFile);
       }
   }

   $logger->debug(__PACKAGE__ . ".$sub LogFileList -> @logFileList");

   my %scpArgs;
   $scpArgs{-hostip} = $nfsipaddress;
   $scpArgs{-hostuser} = $NFS_userid;
   $scpArgs{-hostpasswd} = $NFS_passwd;
 
   #Start copying the log files to given ATS server location
   foreach $logName (@logFileList) {
        $logName =~ /\w+\.(\w+)/;
        $remainder = $1;
        my $nfsLogFile  = "$nfsmountpoint" . "/evlog/" . "$serialnumber" . "/$remainder/" . "$logName";
        my $atsLocation = "$ats_dir/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}" . "-GSX-" . "$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}-" . "$logName";
        
	$atsLocation =~ s/\s//g;
        
        $logger->debug(__PACKAGE__ . ".$sub Transferring $nfsLogFile to $atsLocation");
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$nfsLogFile;
        $scpArgs{-destinationFilePath} = $atsLocation;

        unless(&SonusQA::Base::secureCopy(%scpArgs)) {
            $logger->error(__PACKAGE__ . ".$sub:  SCP $nfsLogFile to $atsLocation Failed");
        }
    }

   # Return ATS Location of files to allow parsing
   return (@logFileList);
}

=pod

=head1 gsxMnsSwitchover()

    This function does not need to know the card or redundancy group. 
    It switches over the MNS card and reconnects.
    A flag to indicate we should wait for the cards to re-synch can be used.

Arguments (Optional):
   -waitForSynch => boolean value to determine if we should wait for the cards to synch

=cut

##################################################################################
sub gsxMnsSwitchover {
##################################################################################

  my ($self, %args) = @_;
  my $sub = "gsxMnsSwitchover()";
  my %a = ( -waitForSynch => 0 );
  my $redundGroup = "";
  my $redundSynch = 0;
  my $timeout = 500;
  my ($line, $t0, $cmdString);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $scr_logger = Log::Log4perl->get_logger("SCREEN");

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  my $gsx_name = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

  # run the CLI
  $cmdString = "show redundancy group summary";

  $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString for GSX $a{-gsxNo}");

  unless($self->execCmd($cmdString)) {
	$logger->error(__PACKAGE__ . ".$sub Error in executing the CLI");
	return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

  my @fields;

  foreach $line ( @{ $self->{CMDRESULTS}} ) {
	@fields = split(' ', $line);
	if(($fields[3] =~ "MNS") && ($fields[5] eq "ENABLED")) {
	  $redundGroup = $fields[0];

	  $cmdString = "configure redundancy group $redundGroup switchover";
	  $logger->info(__PACKAGE__ . ".$sub line : $cmdString");
	  my $gsx_timeout = $self->{DEFAULTTIMEOUT};
	  $self->{DEFAULTTIMEOUT} = 5;
		
	  $t0 = [gettimeofday];
	  if($self->execCmd($cmdString)) {
		$logger->error(__PACKAGE__ . ".$sub Error in executing MNS SWITCHOVER: " . Dumper($self->{CMDRESULTS}));
		foreach $line ( @{ $self->{CMDRESULTS}} ) {
		  if($line =~ "not synced to the standby") {
			while((tv_interval($t0) <= $timeout) && ($redundSynch == 0)) {
			  sleep 30;
			  if($self->execCmd($cmdString)) {
				$logger->error(__PACKAGE__ . ".$sub Error in executing MNS SWITCHOVER : " . Dumper($self->{CMDRESULTS}));
			  }
			  else {
				$logger->info(__PACKAGE__ . ".$sub MNS Switchover successful");
				$redundSynch = 1;
			  }
			}
			if(!$redundSynch) {
			  $logger->error(__PACKAGE__ . ".$sub MNS Switchover unsuccessful");
			  return 0;
			}
		  }
		  else {
			return 0;
		  }
		}
	  }
		
	  $scr_logger->debug(__PACKAGE__ . ".$sub : Reconnecting to GSX '$gsx_name'");
	  unless ($self->reconnect( -retry_timeout => 180, -conn_timeout  => 10, )) {
		$scr_logger->error(__PACKAGE__ . ".$sub : Failed to reconnect to GSX object '$gsx_name' to GSX within 3 minutes of rebooting. Exiting...");
		return 0;
	  }
	 $self->{DEFAULTTIMEOUT} = $gsx_timeout;

	  # Wait for Active and Redundant slots to synch
	  $redundSynch = 0;
	  if($a{-waitForSynch}) {
		$t0 = [gettimeofday];
		while((tv_interval($t0) <= $timeout) && ($redundSynch == 0)) {
		  sleep 30;
		  $cmdString = "show redundancy group $redundGroup status";
		  $self->execCmd($cmdString);
		  foreach $line ( @{ $self->{CMDRESULTS}} ) {
			chomp($line);
			if($line =~ m/^\s*Number of Synced Clients:\s+1\s*$/i ) {	
			  $logger->info(__PACKAGE__ . ".$sub Active synched to Standby");
			  $redundSynch = 1;
			  last;
			}
			elsif($line =~ m/^\s*Number of Synced Clients:\s+0\s*$/i ) {	
			  $logger->info(__PACKAGE__ . ".$sub Waiting for Active to synch with Standby");
			}
		  }
		}
		if(!$redundSynch) {
		  $logger->info(__PACKAGE__ . ".$sub Active NOT synched with Standby - timeout");
		}
	  }
	  return 1;
	}
  }
  return 0;
}

=pod

=head1 gsxSlotFromPort() 

    This function takes the GSX port and returns the card on which it is configured.

=over 

=item Arguments (Optional):

   -port => port # Name of the Port
   -type => port_type # E1 or T1 etc

=back

=cut

##################################################################################
sub gsxSlotFromPort {
##################################################################################

  my ($self, %args) = @_;
  my $sub = "gsxSlotFromPort()";
  my $redundGroup = "";
  my %a;
  my ($line, $cmdString);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $scr_logger = Log::Log4perl->get_logger("SCREEN");

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  if((!defined $a{-port}) or (!defined$a{-type})) {
	$logger->error(__PACKAGE__ . ".$sub Error - required values of port and type not defined $a{-port} $a{-type}");
	return 0;
  }
	
  $cmdString = "SHOW $a{-type} $a{-port} STATUS";

  # run the CLI
  unless($self->execCmd($cmdString)) {
	$logger->error(__PACKAGE__ . ".$sub Error in executing the CLI");
	return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

  my @fields;

  foreach $line ( @{ $self->{CMDRESULTS}} ) {
	@fields = split(' ', $line);
	if($fields[2] =~ "Slot:") {
	  return $fields[3];
	}
  }
  return 0;
}

=pod

=head1 gsxPortNumFromPort()

    This function takes the GSX port and returns the Port Number on which it is configured.

Arguments (Optional):
   -port => port # Name of the Port
   -type => port_type # E1 or T1 etc

=cut

##################################################################################
sub gsxPortNumFromPort {
##################################################################################

  my ($self, %args) = @_;
  my $sub = "gsxPortNumFromPort()";
  my %a;
  my ($line, $cmdString);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my $scr_logger = Log::Log4perl->get_logger("SCREEN");

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  if((!defined $a{-port}) or (!defined$a{-type})) {
	$logger->error(__PACKAGE__ . ".$sub Error - required values of port and type not defined $a{-port} $a{-type}");
	return 0;
  }
	
  $cmdString = "SHOW $a{-type} $a{-port} STATUS";

  # run the CLI
  unless($self->execCmd($cmdString)) {
	$logger->error(__PACKAGE__ . ".$sub Error in executing the CLI");
	return 0;
  }

  $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

  my @fields;

  foreach $line ( @{ $self->{CMDRESULTS}} ) {
	@fields = split(' ', $line);
	if($fields[4] =~ "Port:") {
	  return $fields[5];
	}
  }
  return 0;
}

=pod

=head1 searchDBGlog()

    This subroutine is used to find the number of occurrences of a list of patterns in the GSX DBG log

Arguments :
   Array containing the list of patterns to be searched on the GSX debug log

Return Values :
   Hssh containing the pattern being searched as the key and the number of occurrences of the same in the DBG log as the value

Example :
  my @patt = ("msg","msg =","abc");
  my %res = $gsxobj->searchDBGlog(\@patt);

Author :
 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub searchDBGlog {
    my ($self,$patterns)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog, %returnHash);
    my @pattArray = @$patterns;
    my ($tmpStr, $cmd1, $string, @tmp1, $retVal,$patt);

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".searchDBGlog");
    $logger->info(__PACKAGE__ . ".searchDBGlog RETRIEVING ACTIVE GSX DBG LOG");

    # Get node name and NFS details
    ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

    if (!defined($nodename)) { $logger->warn(__PACKAGE__ . ".searchDBGlog NODE NAME MUST BE DEFINED"); return $nodename; }

    # Get chassis serial number
    $cmd = "show chassis status"; 
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active DBG log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.DBG)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
                                                -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => $self->{NFSUSERID},
            -OBJ_PASSWORD => $self->{NFSPASSWD},
            -OBJ_COMMTYPE => "SSH",);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\$nfsmountpoint = $nfsmountpoint \n\$nodename = $nodename \n\$serialnumber = $serialnumber \n\$dbglogname = $dbglogname \n\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => $self->{NFSUSERID},
                -OBJ_PASSWORD => $self->{NFSPASSWD},
                -OBJ_COMMTYPE => "SSH",);
    }

    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/) || ($nfsmountpoint =~ m/SipQANFS1/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = "/sonus/SonusQANFS/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber" . "/DBG/" . "$dbglogname";
        }

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => "SSH",);
    }

    foreach $patt (@pattArray){
        $cmd1 = 'grep -c "'.$patt.'" '. $dbglogfullpath ;

        my @cmdResults;
            unless (@cmdResults = $dsiObj->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
              $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECUTION ERROR OCCURRED");
            }

        $string = $cmdResults[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $logger->debug(__PACKAGE__ . ".searchDBGlog Number of occurrences of the string \"$patt\" in $dbglogfullpath is $string");
        unless($string){
           $logger->error(__PACKAGE__ . ".searchDBGlog No occurrence of $patt in $dbglogfullpath");
           $string = 0;
           };
        $returnHash{$patt} = $string;
    }
    return %returnHash;

} 


=pod

=head1 checkCardConfig()

   This Subroutine checks whether the CNS card is already configured. If already configured, then it returns the type of the card(T1 or E1).

Arguments :

   Mandatory :   Adaptertype
                 slot (in which the adapter is found)
                 shelf

Return Values :

   $value( Either T or E ) - if already configured.
   0 - if not configured.

Example :

  $self->checkCardConfig(1,"CNA81",$slot);

Author :

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut

sub checkCardConfig {
    my($self, $shelf,$adapter,$slot)=@_;
    my $sub = "checkCardConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".checkCardConfig");
    my $value = 0;

    if (!defined $adapter) {
        $logger->debug(__PACKAGE__ . "$sub  mandatory argument 'adapter' is missing ");
        return 0;
    }

    if (!defined $slot) {
        $logger->debug(__PACKAGE__ ."$sub  mandatory argument 'slot' is missing");
        return 0;
    }

    switch ($adapter)      {
          #Span Min, Max, Port, Channels
          case [ "GNA15", "GNA10", "CNA10", "CNA30", "CNA31", "CNA60", "CNA80" ]  {
              $self->execCmd("SHOW T1 SHELF 1 SLOT $slot SUMMARY");
          }

          case [ "CNA20", "CNA21", "CNA25" ]  {
              $self->execCmd("SHOW E1 SHELF 1 SLOT $slot SUMMARY");
          }

          case "CNA40"  {
              # CNA40 Can be configured as either T1 or E1
              my $port_type = $self->getServerFunction(-slot => $slot);

              if ($port_type) {
                  $self->execCmd("SHOW $port_type SHELF 1 SLOT $slot SUMMARY");
              }
              else {
                  $logger->warn(__PACKAGE__ . "$sub  port_type NOT set");
                  return 0;
              }
          }

          case [ "CNA70", "CNA81" ]        {
              # Determine if Optical Interface configured as T1 or E1
              my $payload = $self->getOpticalPayload(-slot => $slot);
              switch ( $payload ) {
                  case ["DS3ASYNC", "STFRAME", "T1BITASYNC"] {
                      $self->execCmd("SHOW T1 SHELF 1 SLOT $slot SUMMARY");
                  }
                  case "E1BITASYNC" {
                      $self->execCmd("SHOW E1 SHELF 1 SLOT $slot SUMMARY");
                  }
                  else {
                      return 0;
                  }
              }
          }
          else {
              $logger->debug(__PACKAGE__ . "$sub Adapter : $adapter CARD NOT FOUND");
              return 0;
          }
     }

     foreach ( @{$self->{CMDRESULTS}} ){
         if( $_ =~ /((T|E))\d.*ENABLED/i ){
             $value = $1;
             last ;
         }
     }

     $logger->info(__PACKAGE__ . "$sub slot : $slot ----> ($value) Card ");
     $value ? return $value : return 0 ;

}

=pod

=head1 configureEnablePorts()

     Loops around all ports in a CNS Card , adding the portname to a list stored in the object.
     The subroutine previously also enabled all the Ports on the GSX, but that could take
     10 minutes on a HD when only 1 port was used for testing.  Now port is enabled on
     Circuit creation.

Arguments :

   Mandatory :    None

   Optional  :    -protocol    The Protocol for configuring the Optical cards
                  -enablePort  Enable ALL ports within this subroutine

Return Values :

   0 - Failed

   Array of portnames - Success

Description :

   # Rename ports
   $self->configureEnablePorts( -protocol => ANSI,-starting_slot => 1,-port_type => T

Author :

Modified by : Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut

sub configureEnablePorts {
    my ($self, %args) = @_;
    my $sub = "configureEnablePorts()";
    my %a   = (-enablePort => 0 );
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    my (@interface, $slot, $port, $span, $port_type, $port_name, $network_type, $payload_map, @portsNames, $key, $value);
    my $total_enabled    = 0;
    my $port_delay       = 0;
    my $isCardConfigured = 0;
    my $cardCount        = 0;
    my $flag             = 0;

    # get the arguments
    while (  ($key, $value) = each %args ) {
        $a{$key} = $value;
    }
    $logger->info(__PACKAGE__ . ".$sub  Entered ", Dumper(\%a));

    # Stored GSX Hardware configuration
    $self->getHWInventory(1);

    # Extra Configuration required before enabling Ports
    for ($slot = $args{-starting_slot}; $slot <= 16; $slot++) {

        # Find active CNS Cards
        if ( ($self->{'hw'}->{'1'}->{$slot}->{'SERVER'} =~ m/CNS/ ) &&
            ($self->{'hw'}->{'1'}->{$slot}->{'SERVER-STATE'} =~ m/RUNNING/ ) &&
            ($self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR-STATE'} =~ m/PRESENT/ ) ) {


            $isCardConfigured = $self->checkCardConfig(1,$self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR'},$slot);

            unless($isCardConfigured){

                switch ( $self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR'} )  {
                    case ["CNA70","CNA81"] {
                        $logger->info(__PACKAGE__ . ".$sub  Optical Configuration Slot:$slot $a{-protocol} ");
                        switch ($a{-protocol} ) {
                            case ["ANSI"] {
                                $network_type = "SONET";
                                $payload_map = "T1BITASYNC";
                            }
                            case ["ITU","BT","CHINA"] {
                                $network_type = "SDH";
                                $payload_map = "E1BITASYNC";
                            }
                            case ["JAPAN"] {
                                $network_type = "SDH";
                                $payload_map = "STFRAME";
                            }
                            else {
                                $logger->debug(__PACKAGE__ . ".$sub  Unknown protocol type: $a{-protocol}");
                                next;
                            }
                        }

                        # In Service Interfaces
                        $self->execCmd("CONFIGURE OPTICAL INTERFACE optical-1-$slot-1 NETWORK TYPE $network_type");
                        $self->execCmd("CONFIGURE OPTICAL INTERFACE optical-1-$slot-1 PAYLOAD MAPPING $payload_map");
                        $self->execCmd("CONFIGURE OPTICAL INTERFACE optical-1-$slot-1 NAME opt$slot");
                        $self->execCmd("CONFIGURE OPTICAL INTERFACE opt$slot STATE ENABLED");
                        $self->execCmd("CONFIGURE OPTICAL INTERFACE opt$slot MODE INSERVICE");
                        $port_delay = 1;
                    }
                }

                # Delay while optical ports created
                if ( $port_delay eq 1) {
                    $logger->info(__PACKAGE__ . ".$sub  Delay 10s while Optical Ports Created");
                    sleep(20);
                }
            }

            # Is this Card In-Service
            # Determine Port Type, Number of Ports
            @interface = $self->getInterfaceFromAdapter(1,$self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR'},$slot);

	    # No details found for this slot, skip	
            if (!defined ($interface[0]) ){
                next;
            }
	    
	    $logger->info(__PACKAGE__ . ".$sub  Type:$interface[0] min:$interface[1] max:$interface[2] port:$interface[3] channels:$interface[4]");	
		
            if( $isCardConfigured ){
                if( $args{-port_type} ne $isCardConfigured ){
		    $logger->debug(__PACKAGE__ . ".$sub Requested Port -->$args{-port_type} ");
		    $logger->debug(__PACKAGE__ . ".$sub Current Port --> $isCardConfigured ");
                    next;
                }
		else{
		    $logger->debug(__PACKAGE__ . ".$sub Ports Matched!!");
		    ++$flag; #indicates the current logical slot	
		}
            }else{
                # Did User specify to only use E1 or T1 Ports
                if ( defined($a{-port_type}) ) {
                    if ( $a{-port_type} ne substr($interface[0], 0, 1) ) {
		        $logger->debug(__PACKAGE__ . ".$sub Requested Port -->$args{-port_type} ");
			$logger->debug(__PACKAGE__ . ".$sub Current Port --> substr($interface[0], 0, 1) ");
	                next;
                    }else{
			$logger->debug(__PACKAGE__ . ".$sub Ports Matched!!");	
			++$flag; #indicates the current logical slot
		    }	
                }
	    }	

	    #check whether the card is on the requested slot 	
            if ($args{-slot_defined} == 1) {
                unless ($flag == $args{-req_slot}) {
		    $logger->debug(__PACKAGE__ . ".$sub Current Card is not on the requested slot");
                    next;
                }
		$logger->debug(__PACKAGE__ . ".$sub Requested Slot Identified");
		$logger->debug(__PACKAGE__ . ".$sub Configuring CICs on the Matched Card");
            }

            # Loop for every port in this slot
            for ($port = 1; $port <= $interface[3]; $port++) {

                unless($isCardConfigured){
                    # Enable T3 where required
                    if ( $interface[0] eq "T3") {
                        $port_name = "T3-1-$slot-$port";
                        $self->execCmd("CONFIG T3 $port_name STATE enable");
                        $self->execCmd("CONFIG T3 $port_name MODE IN");
                    }
                }

                # Loop for every span in this port
                for ($span = $interface[1]; $span <= $interface[2]; $span++) {

                    $port_type = substr($interface[0], 0, 1);

                    if ($port_type eq "T") {
                        switch ( $self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR'} )  {
                            case ["CNA10","CNA40"]   {
                                $port_name = "T1-1-$slot-$span";
                            }
                            case ["CNA30","CNA33","CNA70","CNA81"]     {
                                # port is the T3 index (always 1 for CNS30/CNS31/CNS71/CNS81/CNS86)
                                $port_name = "T1-1-$slot-1-$span";
                            }
                            case ["CNA60","CNA80"] {
                                $port_name = "T1-1-$slot-$port-$span";
                            }
                            else {
                                $logger->debug(__PACKAGE__ . ".$sub  UNKNOWN card type");
                                next;
                            }
                        }
                    }
                    elsif ($port_type eq "E"){
                        # E1 Ports
                        switch ( $self->{'hw'}->{'1'}->{$slot}->{'ADAPTOR'} )  {
                            case ["CNA20","CNA21","CNA25","CNA40"]   {
                                $port_name = "E1-1-$slot-$span";
                            }
                            case ["CNA70","CNA81"]   {
                                # port is the T3 index (always 1 for CNS30/CNS31/CNS71/CNS81/CNS86)
                                $port_name = "E1-1-$slot-1-$span";
                            }
                            else {
                                $logger->debug(__PACKAGE__ . ".$sub  UNKNOWN card type");
                                next;
                            }
                        }
                    }
                    else {
                        $logger->error(__PACKAGE__ . ".$sub  Unable to determine port_type $port_type");
                        return 0;
                    }

                    push @portsNames, $port_name;

                    unless( $isCardConfigured ){
                        # Mark Port as unused
                        $self->{GsxPorts}->{$port_name} = "UNUSED";
                        $total_enabled++;
                    }
                } # Loop all spans on Card
            }# Loop all ports on Card
            unless( $isCardConfigured ){
                # Return Success when ports enabled
                if ($total_enabled > 0) {
                    $logger->info(__PACKAGE__ . ".$sub total ports enabled : $total_enabled ");
                    return \@portsNames;
                }
                else {
                    $logger->error(__PACKAGE__ . ".$sub Port is not enabled");
                    return 0;
                }
            }

            if($a{-port_type} eq $isCardConfigured){
                $logger->info(__PACKAGE__ . ".$sub slot $slot : Requested Card($isCardConfigured) card available");
		return \@portsNames;	
            }
        }
    }
    $logger->info(__PACKAGE__ . ".$sub  No Cards available further!!!");
    return 0;

}# End of configureEnablePorts()


=pod

=head1 configureDeletePorts()

    Remove all entries from Port Hash.

=over 

=item Arguments :

   Mandatory :    None
   Optional  :    None

=item Return Values :

   0 - Failed
   1 - Success

=item Example :

   # Delete ports
   $self->configureDeletePorts();

=back

=cut

sub configureDeletePorts {
    my ($self, %args) = @_;
    my $sub = "configureDeletePorts()";
    my %a;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));
    my $port_size = scalar keys %{$self->{GsxPorts}};
    $logger->debug(__PACKAGE__ . ".$sub  GsxPorts Entries: $port_size ");
        
    # Remove all Port Entries
    for my $key ( keys %{$self->{GsxPorts}} ) {
        #my $value = ${$self->{GsxPorts}}{$key}; 
        #$logger->info(__PACKAGE__ . ".$sub $key => $value\n");
        delete ${$self->{GsxPorts}}{$key};
    }

    $port_size = scalar keys %{$self->{GsxPorts}};
    $logger->debug(__PACKAGE__ . ".$sub  GsxPorts Entries: $port_size ");
           
    return;
}

=pod

=head1 configureISUPPorts()

    Loops around all CNS cards and ports, creating ISUP Circuits.
    Can be configued to create Circuits on both E1 and T1 Ports in the same GSX . 
    There are no boundary checking for maximum circuits per ISUP Service or Trunk Group,
    it will fail silently without errors.  The checkConfig() is expected to fail as the
    required number of circuits are not configured.  

=over

=item Arguments :

   Mandatory :    None
   Optional  :
      -isup_serv   => "SS71"       Only creats circuits on SS71 Service
      -port_type   => "E" or "T"   Only create circuits on E1 Ports
      -total_ports => 1            Only create circuits on 1 Port
      -total_cics  => 20           Only create 20 circuits
      -protocol    => "ITU"
      -startCIC    => 100          only create circuits starting from 100 	

=item Return Values :

   0 - Failed
   1 - Success

=item Example :

   # Creates ISUP Circuits on ALL ports
   $gsx_session->configureISUPPorts();   
   # Creates ISUP Circuits only on the E1 ports, for SS71
   $gsx_session->configureISUPPorts(-isup_serv => "SS71", -port_type => "E");
   # Creates ISUP Circuits only on the T1, T3 ports
   $gsx_session->configureISUPPorts(-isup_serv => "SS71", -port_type => "T", -protocol => "ANSI");
   # Create 20 ISUP Circuits on E1 port
   $gsx_session->configureISUPPorts(-isup_serv => "SS71", -port_type => "E", -protocol => "ITU", -total_cics => 20)

=item Modified by,

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub configureISUPPorts {
    my ($self, %args) = @_;
    my $sub = "configureISUPPorts()";
    my %a   = (-isup_serv => "SS71", -serv_profile => "circ_serv_prof1", -total_ports => 1000, -protocol => "ITU", -port_type => "E"); 
    my ($max_cic, $end_chan, $port_name, $port_value, $chan_max, $cic_req, $next_slot, @total_spans, $total_ports, $total_spans, $spans_available, @port_values, $startingCICRange );
    my $start_cic = 0;
    my $configured_ports = 0;
    my $checkNextAvailableCard = 0;
 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    
    $logger->debug(__PACKAGE__ . ".$sub  Entered with args - ", Dumper(%a));

    if ( $resetPort eq 0 ) {
        $self->configureDeletePorts();
        $resetPort = 1;
    }

    my $size = scalar keys %{$self->{GsxPorts}};
    $logger->debug(__PACKAGE__ . ".$sub $size");

    if ( defined ($a{-startCIC}) ){
	$start_cic = $a{-startCIC};
	$startingCICRange = 1;
    } 

    if ( defined($a{-total_cics}) ) {
        $cic_req = $a{-total_cics};
    }

    while( 1 ) { 

        if($checkNextAvailableCard eq 1){
            $next_slot = $port_values[2] + 1;
            $logger->info(__PACKAGE__ . ".$sub No Unused Ports available ");
            $logger->info(__PACKAGE__ . ".$sub Checking for next available CNS Card");
            $total_ports = $self->configureEnablePorts ( -protocol => $a{-protocol}, -starting_slot => $next_slot, -port_type => $a{-port_type}, -slot_defined => 0 );
        }else{
            $total_ports = $self->configureEnablePorts ( -protocol => $a{-protocol}, -starting_slot => 1, -port_type => $a{-port_type}, -slot_defined => 0 );
        }

        # Catch Error
        unless( $total_ports ) { return 0;}

        @total_spans = @{$total_ports};
        $total_spans = @total_spans;
        $logger->debug(__PACKAGE__ . ".$sub total ports available in the CNS card  : $total_spans  ");

        my $size = scalar keys %{$self->{GsxPorts}};

        #finding unused spans in the card
	my $spans_available = 0;
        foreach (@total_spans){
            if( ${$self->{GsxPorts}}{$_} eq "UNUSED" ){
                $spans_available += 1;
            }
        }

        $logger->info(__PACKAGE__ . ".$sub Unused Ports in the Card : $spans_available ");
        # If no Spans available look on next slot
        if ( $spans_available eq 0 ) {
            $checkNextAvailableCard = 1;
            @port_values = split( '-', $total_spans[0] ); 
            next;
        }

        # Keep CIC numbers Unique on the same SS7 Node
	
	unless( $startingCICRange ) {
            if($a{-port_type} eq "T"){
                $start_cic = $self->{LastIsupCicT} if ($self->{LastIsupCicT});
            } else{
	        $start_cic = $self->{LastIsupCicE} if ($self->{LastIsupCicE});
    	    } 
	}

        unless( $checkNextAvailableCard ) { 
            if ( defined($a{-total_cics}) ) {
                $cic_req = $a{-total_cics};
            }            
	}           

        # Loop all Enabled Ports
        foreach my $key (@total_spans)  {   
    
            $port_name = $key;
            $port_value = ${$self->{GsxPorts}}{$key};
            $logger->debug(__PACKAGE__ . ".$sub $key => $port_value");
        
            # Did User specify to only use E1 or T1 Ports
            if ( defined($a{-port_type}) ) {
                if ( $a{-port_type} ne substr($port_name, 0, 1) ) {
                    next;
                }
            }   
        
            # Find Available Port 
            if ($port_value eq "USED" ) { 
                next;
            }
  
            @port_values = split( '-', $port_name );
            $logger->info(__PACKAGE__ . ".$sub  current slot : $port_values[2]" );

            # Max Channels for Port type
            if (substr($port_name, 0, 1) eq "T") {
                $chan_max = 24;
            }
            else {
                $chan_max = 31;
            }
                
            # Determine Number of Circuits and Channels      
            if ( defined($a{-total_cics}) ) {          
                # More than 1 ports worth of circuits                    
                if ( $cic_req > $chan_max) {
                    $max_cic  = $start_cic + ($chan_max - 1);
                    $end_chan = $chan_max;                    
                }
                else {
		    $logger->debug(__PACKAGE__ . ".$sub cic_req -> $cic_req ");
		    $logger->debug(__PACKAGE__ . ".$sub start_cic -> $max_cic");
                    # Only create remaining circuits
                    $max_cic  = $start_cic + ($cic_req - 1);
                    $end_chan = $cic_req;
                }
                $logger->debug(__PACKAGE__ . ".$sub  end_chan -> $end_chan ");

                # Store Remaining Circuits to create
                $cic_req = $cic_req - $end_chan;
            }
            else {
                # Create full port of Circuits
                $max_cic  = $start_cic + ($chan_max - 1);
                $end_chan = $chan_max;              
            }        
  
            # Mark Port as used
            $self->{GsxPorts}->{$port_name} = "USED";
        
            # Seperate values from T1-1-10-1-1
            my @port_values = split( '-', $port_name );

            # Enable Port
            $self->execCmd("CONFIG $port_values[0] $port_name AVAIL CHANNELS 1-$end_chan");
            $self->execCmd("CONFIG $port_values[0] $port_name STATE enable");
            $self->execCmd("CONFIG $port_values[0] $port_name MODE IN");        
        
	    $logger->debug(__PACKAGE__ . ".$sub CIC_range --> $start_cic-$max_cic");		

            # Create Circuits
            $self->execCmd("CREATE ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic");
            $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic PORT $port_name CHANNEL 1-$end_chan");
            $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic DIRECTION TWOWAY");
            $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic SERVICEPROFILENAME $a{-serv_profile}");
            $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic STATE ENABLED");
            $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $start_cic-$max_cic MODE UNBLOCK");
         
            # Increase start_cic number
            $start_cic = $start_cic + $end_chan;
            $configured_ports++ ;

            $portType = substr ($port_name, 0, 1);
	    if($portType eq "T"){
		$self->{LastIsupCicT} = $start_cic;
	    }else{
		$self->{LastIsupCicE} = $start_cic;
	    }

            # If User Specified only using x ports
            if ( $a{-total_ports} eq $configured_ports ) {
		if($portType eq "T"){
                    $logger->debug(__PACKAGE__ . ".$sub  Total Configured Ports:$configured_ports   Circuits:$self->{LastIsupCicT}");
		}else{
                    $logger->debug(__PACKAGE__ . ".$sub  Total Configured Ports:$configured_ports   Circuits:$self->{LastIsupCicE}");
		}
		return 1;
            }
        
            # If User Specified number of circuits
            if ( defined($a{-total_cics}) ) {
                if ( $cic_req eq 0 ) {
                    if($portType eq "T"){
                        $logger->debug(__PACKAGE__ . ".$sub  Total Configured Ports:$configured_ports   Circuits:$self->{LastIsupCicT}");
		    }else{
			$logger->debug(__PACKAGE__ . ".$sub  Total Configured Ports:$configured_ports   Circuits:$self->{LastIsupCicE}");
		    }	        
                    return 1;
                }
            }
        }
	$startingCICRange = 0;
        $checkNextAvailableCard = 1;
    }                
}



=pod

=head1 configureISUPCircuits()

    Creates ISUP Circuits on first available CNS Port matching parameters.

Arguments :
   Mandatory :
      -cic_range   => "1-20"       Circuit range
      -chan_range  => "1-20"       Using Channels

   Optional  :
      -isup_serv   => "SS71"       Only creats circuits on SS71 Service
      -port_type   => "E" or "T"   Only create circuits on E Ports

Return Values :

   0 - Failed
   1 - Success

Example :
   #creates 20 ISUP Circuits on first E1 port, for SS71
   $gsx_session->configureISUPCircuits(-cic_range => "1-20", -chan_range => "1-20");
   $gsx_session->configureISUPCircuits(-isup_serv => "SS71", -port_type => "E", -cic_range => "1-20", -chan_range => "1-20");

   # Creates ISUP Circuits on second slot with E1 ports, for SS71
   # Second slot could be slot 4, 6, etc+, which ever has unused E1 slots
   $gsx_session->configureISUPCircuits(-isup_serv => "SS71", -port_type => "E",-cic_range => "1-20", -chan_range => "1-20");

   # Creates ISUP Circuits on second slot with T1 ports, for SS71
   $gsx_session->configureISUPCircuits(-isup_serv => "SS71", -port_type => "T", -protocol => "ANSI", -cic_range => "1-20", -chan_range => "1-20");


Author :

Modified by:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut

sub configureISUPCircuits {
    my ($self, %args) = @_;
    my $sub = "configureISUPCircuits()";
    my %a = (-isup_serv => "SS71", -protocol => "ITU", -port_type => "E", -serv_profile => "circ_serv_prof1");
    my ( $end_chan, $start_chan, $CICs_required, @CIC_range, @channel_range, $CICSineachspan, @port_values, $port_name, $port_value, $matchFound, $total_ports, @total_spans, $next_slot, $slotDefined );
    my $checkNextAvailableCard = 0;
    my $spans_available        = 0;
    my $TPortFlag = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->info(__PACKAGE__ . ".$sub  Args - ", Dumper(\%a));

    if ( $resetPort eq 0 ) {
	$self->configureDeletePorts();
	$resetPort = 1;
    } 

    my $size = scalar keys %{$self->{GsxPorts}};
    $logger->debug(__PACKAGE__ . ".$sub $size");

    #if($a{-port_type} eq "T"){
    #     $CICSineachspan = 24;
    #	$TPortFlag = 1;
    # } else{
    #	$CICSineachspan = 31;
    # }

    @channel_range = split ( '-', $a{-chan_range});
    my $total_chan = $channel_range[1] - $channel_range[0] + 1;	

    #if ($self->{LastIsupService}) {
    #    if ($self->{LastIsupService} ne $a{-isup_serv}){
    #	    $logger->info(__PACKAGE__ . ".$sub Isupservice changes, configuring the CICs from the next unused port");	
    #	    ${$self->{GsxPorts}}{$self->{LastCICPort}} = "USED";	    
    #	    $logger->info(__PACKAGE__ . ".$sub $self->{LastCICPort} -> ${$self->{GsxPorts}}{$self->{LastCICPort}}\n" );	
    #    }
    #}

    while( 1 ){

        if($checkNextAvailableCard eq 1){
            $next_slot = $port_values[2] + 1;
            $total_ports = $self->configureEnablePorts ( -protocol => $a{-protocol},-starting_slot => $next_slot,-port_type => $a{-port_type}, -slot_defined => 0 );
        }else{
            if ( defined ($a{-slot}) ){
                $total_ports = $self->configureEnablePorts( -protocol => $a{-protocol}, -starting_slot => 1, -port_type => $a{-port_type}, -slot_defined => 1, -req_slot => $a{-slot} );
	    } else{
                $total_ports = $self->configureEnablePorts( -protocol => $a{-protocol},-starting_slot => 1,-port_type => $a{-port_type}, -slot_defined => 0 );
	    }
        }

        unless($total_ports){
            $logger->debug(__PACKAGE__ . ".$sub Port not found!!! ");
            return 0;
        }

        @total_spans = @{$total_ports};

        #finding unused spans in the card
        foreach (@total_spans){
            if( ${$self->{GsxPorts}}{$_} eq "UNUSED" ){
                $spans_available += 1;
            }
        }

        $logger->info(__PACKAGE__ . ".$sub Unused Ports in the Card : $spans_available ");

        # Seperate out slot value from T1-1-10-1-1
        @port_values = split( '-', $total_spans[1] );

        $logger->debug(__PACKAGE__ . ".$sub  curr slot:$port_values[2] ");

        if($spans_available){
            $logger->debug(__PACKAGE__ . ".$sub Ports are available for configuring the requested CICs!!!  ");
            $logger->info(__PACKAGE__ . ".$sub Configuring CICs on the same card... ");
	    last;
        }
        else{
            $logger->info(__PACKAGE__ . ".$sub No Unused Ports available ");
            $logger->info(__PACKAGE__ . ".$sub Checking for next available CNS Card");
            $checkNextAvailableCard = 1;
        }
    }#end of while loop


    foreach (@total_spans) {

        $port_name = $_;
        chomp($port_name);
        $port_value  = ${$self->{GsxPorts}}{$port_name};
        $logger->info(__PACKAGE__ . ".$sub $port_name => $port_value");

        # Did User specify to only use E1 or T1 Ports
        if ( defined($a{-port_type}) ) {
            if ( $a{-port_type} ne substr($port_name, 0, 1) ) {
                next;
            }
        }
        # Find UNUSED Port's
        if ($port_value eq "USED" ) {
            next;
        }else{
            $matchFound = 1;
        } 
        # Seperate out slot value from T1-1-10-1-1
        @port_values = split( '-', $port_name );
        $logger->info(__PACKAGE__ . ".$sub  current slot : $port_values[2]" );
        last;

    }

    if($matchFound){
        # Create Circuits on selected Port
  	
	chomp($channel_range[1]);
	$self->{GsxPorts}->{$port_name} = "USED";
	#to be done if required 
	#avoids wastage of Channels in each port i.e. each port will be marked as used only if all the available channels are utilized.

 	#$logger->info(__PACKAGE__ . ".$sub end channel : $channel_range[1]");
	#if ($TPortFlag) {
 	#    if( $channel_range[1] =~ /^2[34]/  ) {
        #         $self->{GsxPorts}->{$port_name} = "USED";
	#        $logger->info(__PACKAGE__ . ".$sub Port ($port_name) --> marked as used");
	#    }
	#}else{
        #     if( $channel_range[1] =~ /^3[01]/  ) {
        #         $self->{GsxPorts}->{$port_name} = "USED";
        #         $logger->info(__PACKAGE__ . ".$sub Port ($port_name) --> marked as used");
        #     }	    
	#}
        
	#$self->{LastCICPort} = $port_name;
	#$self->{LastIsupService} = $a{-isup_serv};

        $logger->info(__PACKAGE__ . ".$sub Current port -> $port_name");
	
        # Enable Port
        unless ( $port_name eq $self->{previousPort} ) {
	    $logger->info(__PACKAGE__ . ".$sub previous port -> $self->{previousPort}");
            $logger->info(__PACKAGE__ . ".$sub Enabling all the channels in the port($port_name)");
            my $channel_range;
            if ( $port_values[0] =~ /T/i ) {
                $channel_range = "1-24";
            } elsif ( $port_values[0] =~ /E/i ) {
                $channel_range = "1-31";
            } 
            $self->execCmd("CONFIG $port_values[0] $port_name AVAIL CHANNELS $channel_range");
            $self->execCmd("CONFIG $port_values[0] $port_name STATE enable");
            $self->execCmd("CONFIG $port_values[0] $port_name MODE IN");
        }
        $self->{previousPort} = $port_name;


        # Create Circuits
        $self->execCmd("CREATE ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range}");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} PORT $port_name CHANNEL $a{-chan_range}");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} DIRECTION TWOWAY");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} SERVICEPROFILENAME $a{-serv_profile}");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATE ENABLED");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} MODE UNBLOCK");

	undef $self->{CMDRESULTS}; 	
        # Check Configuration
        $self->execCmd("SHOW ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATUS");
        foreach ( @{ $self->{CMDRESULTS}} ) {
            $logger->info(__PACKAGE__ . ".$sub  $_");
        }

        # To be done - if required
        # Create Secondary Circuit Range within same Port e.g. creating unused channels between configured circuits
        # if ( defined($a{-cic_range2}) &&  defined($a{-chan_range2}) )
        return 1;
    }

}

=pod

=head1 configureBTCircuits()

    Creates BT Circuits on first available CNS Port matching parameters.

Arguments :
   Mandatory :
      -cic_range   => "1-20"       Circuit range
      -chan_range  => "1-20"       Using Channels

   Optional  :
      -isup_serv   => "SS71"       Only creats circuits on SS71 Service

Return Values :

   0 - Failed
   1 - Success

Example :
   #creates 20 BT Circuits for SS71
   $gsx_session->configureBTCircuits(-cic_range => "1-20", -chan_range => "1-20");
   $gsx_session->configureBTCircuits(-isup_serv => "SS71", -cic_range => "1-20", -chan_range => "1-20");

Author :

Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut

sub configureBTCircuits {
    my ($self, %args) = @_;
    my $sub = "configureBTCircuits()";
    my %a = (-isup_serv => "SS71", -protocol => "ITU", -port_type => "E", -serv_profile => "circ_serv_prof1");
    my ( $end_chan, $start_chan, $CICs_required, @CIC_range, @channel_range, @port_values, $port_name, $port_value, $matchFound, $total_ports, @total_spans, $next_slot, $slotDefined );
    my $checkNextAvailableCard = 0;
    my $spans_available        = 0;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->info(__PACKAGE__ . ".$sub  Args - ", Dumper(%a));

    if ( $resetPort eq 0 ) {
        $self->configureDeletePorts();
        $resetPort = 1;
    }

    my $size = scalar keys %{$self->{GsxPorts}};
    $logger->debug(__PACKAGE__ . ".$sub $size");

    @channel_range = split ( '-', $a{-chan_range});
    my $total_chan = $channel_range[1] - $channel_range[0] + 1;

#    if ($self->{LastBTService}) {	
#        if ($self->{LastBTService} ne $a{-isup_serv}){
#            $logger->info(__PACKAGE__ . ".$sub BT Service changes, configuring the CICs from the next unused port");
#            ${$self->{GsxPorts}}{$self->{LastCICPort}} = "USED";
#            $logger->info(__PACKAGE__ . ".$sub $self->{LastCICPort} -> ${$self->{GsxPorts}}{$self->{LastCICPort}}\n" );
#        }
#    }

    while( 1 ){

        if($checkNextAvailableCard eq 1){
            $next_slot = $port_values[2] + 1;
            $total_ports = $self->configureEnablePorts ( -protocol => $a{-protocol},-starting_slot => $next_slot,-port_type => $a{-port_type}, -slot_defined => 0 );
        }else{
            if ( defined ($a{-slot}) ){
                $total_ports = $self->configureEnablePorts( -protocol => $a{-protocol}, -starting_slot => 1, -port_type => $a{-port_type}, -slot_defined => 1, -req_slot => $a{-slot} );
            } else{
                $total_ports = $self->configureEnablePorts( -protocol => $a{-protocol},-starting_slot => 1,-port_type => $a{-port_type}, -slot_defined => 0 );
            }
        }

        unless($total_ports){
            $logger->debug(__PACKAGE__ . ".$sub Port not found!!! ");
            return 0;
        }

        @total_spans = @{$total_ports};

        #finding unused spans in the card
        foreach (@total_spans){
            if( ${$self->{GsxPorts}}{$_} eq "UNUSED" ){
                $spans_available += 1;
            }
        }

        $logger->info(__PACKAGE__ . ".$sub Unused Ports in the Card : $spans_available ");

        # Seperate out slot value from T1-1-10-1-1
        @port_values = split( '-', $total_spans[1] );

        $logger->debug(__PACKAGE__ . ".$sub  curr slot:$port_values[2] ");

        if($spans_available){
            $logger->debug(__PACKAGE__ . ".$sub Ports are available for configuring the requested CICs!!!  ");
            $logger->info(__PACKAGE__ . ".$sub Configuring CICs on the same card... ");
            last;
        }
        else{
            $logger->info(__PACKAGE__ . ".$sub No Unused Ports available ");
            $logger->info(__PACKAGE__ . ".$sub Checking for next available CNS Card");
            $checkNextAvailableCard = 1;
        }
    }#end of while loop


    foreach (@total_spans) {

        $port_name = $_;
        chomp($port_name);
        $port_value  = ${$self->{GsxPorts}}{$port_name};
        $logger->info(__PACKAGE__ . ".$sub $port_name => $port_value");

        # Find UNUSED Port's
        if ($port_value eq "USED" ) {
            next;
        }else{
            $matchFound = 1;
        }
        # Seperate out slot value from T1-1-10-1-1
        @port_values = split( '-', $port_name );
        $logger->info(__PACKAGE__ . ".$sub  current slot : $port_values[2]" );
        last;

    }

    if($matchFound){

        # Create Circuits on selected Port
#        chomp($channel_range[1]);

	$self->{GsxPorts}->{$port_name} = "USED";
	
        $logger->info(__PACKAGE__ . ".$sub port -> $port_name marked as used!");

#	$self->{LastBTPort} = $port_name;

#        if( $channel_range[1] =~ /^3[01]/  ) {
#            $self->{GsxPorts}->{$port_name} = "USED";
#            $logger->info(__PACKAGE__ . ".$sub Port ($port_name) --> marked as used");
#        }

#	$self->{LastBTService} = $a{-isup_serv};

        $logger->info(__PACKAGE__ . ".$sub Current port -> $port_name");

        # Enable Port
        unless ( $port_name eq $self->{previousPort}  )  {
            $logger->info(__PACKAGE__ . ".$sub previous port -> $self->{previousPort}");
            $logger->info(__PACKAGE__ . ".$sub Enabling all the channels in the port($port_name)");
            my $channel_range = "1-31";
            $self->execCmd("CONFIG $port_values[0] $port_name AVAIL CHANNELS $channel_range");
            $self->execCmd("CONFIG $port_values[0] $port_name STATE enable");
            $self->execCmd("CONFIG $port_values[0] $port_name MODE IN");
        }
        $self->{previousPort} = $port_name;

        # Create Circuits
        $self->execCmd("CREATE BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range}");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} PORT $port_name CHANNEL $a{-chan_range}");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} DIRECTION TWOWAY");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} SERVICEPROFILENAME $a{-serv_profile}");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATE ENABLED");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} MODE UNBLOCK");

        undef $self->{CMDRESULTS};
        # Check Configuration
        $self->execCmd("SHOW BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATUS");
        foreach ( @{ $self->{CMDRESULTS}} ) {
            $logger->info(__PACKAGE__ . ".$sub  $_");
        }

        # To be done - if required
        # Create Secondary Circuit Range within same Port e.g. creating unused channels between configured circuits
        # if ( defined($a{-cic_range2}) &&  defined($a{-chan_range2}) )
        return 1;
    }
}

=pod

=head1 deleteISUPCircuits()

    Delete ISUP Circuits on Specified Service Group. 

=over

=item Arguments :

   Mandatory :
      -cic_range   => "1-20"       Circuit range      
   Optional  :
      -isup_serv   => "SS71"       Only delete circuits from SS71 Service
      -free_port   => 0            Do not free Port for reuse, partial deletion of circuits

=item Return Values :

   0 - Failed
   1 - Success

=item Example :   

   # Deletes ISUP Circuits on SS71
   $gsx_obj->deleteISUPCircuits(-isup_serv => "SS71", -cic_range => "1-24");

=back

=cut

sub deleteISUPCircuits {
    my ($self, %args) = @_;
    my $sub = "deleteISUPCircuits()";
    my %a   = (-isup_serv => "SS71", -free_port => 1); 
    my ($port_name, $skipLines, $line);
    my @fields; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
        
    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
 
    $logger->debug(__PACKAGE__ . ".$sub  Args - ", Dumper(%a));

    # Are Ports Enabled
    my $size = scalar keys %{$self->{GsxPorts}};    
    if ( $size eq 0 ) {
        $logger->error( __PACKAGE__ . ".$sub Error no Ports Enabled :$size:" );
        return 0;       
    }

    # Check Configuration
    unless ($self->execCmd("SHOW ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} ADMIN")) {
        $logger->error( __PACKAGE__ . ".$sub Error in executing CLI : $self->{CMDRESULTS}" );
        return 0;
    }

    $skipLines = 0;
        
    # Parse the output for the required string
    foreach $line ( @{ $self->{CMDRESULTS} } ) {
        if ( $skipLines lt 1 ) {
            if ( $line =~ m/----- ---/ ) {
                $skipLines = $skipLines + 1;
                $logger->debug( __PACKAGE__ . ".$sub skipping " );
            }
            next;
        }

        # Split with space as delimitter
        @fields = split( ' ', $line );
        $logger->debug( __PACKAGE__ . ".$sub $line " );

        if ( $fields[1] ) {
            $logger->debug( __PACKAGE__ . ".$sub ISUP CIRCUITS FOUND" );
            last;          
        }
    }  
	  
    # Delete Circuits if they exist
    if ($fields[1]) {
        # Create Circuits     
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} MODE BLOCK");
        $self->execCmd("CONFIG ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATE DISABLE");
        $self->execCmd("DELETE ISUP CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range}");
        $logger->debug(__PACKAGE__ . ".$sub Cmd Results:" . Dumper($self->{CMDRESULTS}));
            if(grep /^error/, @{$self->{CMDRESULTS}}){
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		return 0;
            }  
        # Mark Port as UNUSED
        if ($a{-free_port} eq 1) {
            $logger->debug(__PACKAGE__ . ".$sub Port $fields[1] UNUSED" );
            $self->{GsxPorts}->{$fields[1]} = "UNUSED";
        }
        return 1;
    }
                 
    return 0;
}

=pod

=head1 deleteBTCircuits()

    Delete ISUP Circuits on Specified Service Group. 

=over 

=item Arguments :

   Mandatory :
      -cic_range   => "1-20"       Circuit range
   Optional  :
      -isup_serv   => "SS71"       Only delete circuits from SS71 Service
      -free_port   => 0            Do not free Port for reuse, partial deletion of circuits

=item Return Values :

   0 - Failed
   1 - Success

=item Example :   

   # Deletes ISUP Circuits on SS71
   $gsx_obj->deleteBTCircuits(-isup_serv => "SS71", -cic_range => "1-24");

=back

=cut

sub deleteBTCircuits {
    my ($self, %args) = @_;
    my $sub = "deleteBTCircuits()";
    my %a   = (-isup_serv => "SS71", -free_port => 1);
    my ($port_name, $skipLines, $line);
    my @fields;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub  Args - ", Dumper(%a));

    # Are Ports Enabled
    my $size = scalar keys %{$self->{GsxPorts}};
    if ( $size eq 0 ) {
        $logger->error( __PACKAGE__ . ".$sub Error no Ports Enabled :$size:" );
        return 0;
    }

    # Check Configuration
    unless ($self->execCmd("SHOW BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} ADMIN")) {
        $logger->error( __PACKAGE__ . ".$sub Error in executing CLI : $self->{CMDRESULTS}" );
        return 0;
    }

    $skipLines = 0;

    # Parse the output for the required string
    foreach $line ( @{ $self->{CMDRESULTS} } ) {
        if ( $skipLines lt 1 ) {
            if ( $line =~ m/----- ---/ ) {
                $skipLines = $skipLines + 1;
                $logger->debug( __PACKAGE__ . ".$sub skipping " );
            }
            next;
        }

        # Split with space as delimitter
        @fields = split( ' ', $line );
        $logger->debug( __PACKAGE__ . ".$sub $line " );

        if ( $fields[1] ) {
            $logger->debug( __PACKAGE__ . ".$sub BT CIRCUITS FOUND" );
            last;
        }
    }

    # Delete Circuits if they exist
    if ($fields[1]) {
        # Create Circuits     
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} MODE BLOCK");
        $self->execCmd("CONFIG BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATE DISABLE");
        $self->execCmd("DELETE BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range}");
        $logger->debug(__PACKAGE__ . ".$sub Cmd Results:" . Dumper($self->{CMDRESULTS}));

        # Mark Port as UNUSED
        if ($a{-free_port} eq 1) {
            $logger->debug(__PACKAGE__ . ".$sub Port $fields[1] UNUSED" );
            $self->{GsxPorts}->{$fields[1]} = "UNUSED";
        }
	$self->execCmd("SHOW BT CIRCUIT SERVICE $a{-isup_serv} CIC $a{-cic_range} STATUS");
        foreach ( @{ $self->{CMDRESULTS}} ) {
            $logger->info(__PACKAGE__ . ".$sub  $_");
        }
        return 1;
    }

    return 0;
}

=pod

=head1 connectToNFS()

    This subroutine is used to find the active nfs server and connect to it using ssh with the credentials mentioned in TMS.

=over 

=item Arguments :

    None.

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub connectToNFS()
{

  my ($self) = @_;
  my $sub = "connectToNFS()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  my ($nfsipaddress,$nfsmountpoint,@cmdresults,$activenfs,$nodename);

  if (defined ($self->{nfs_session})) {
    $logger->info(__PACKAGE__ . ".$sub Already connected to NFS");
    return 1;
  }

  ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

  # Create a connection to NFS
  my $NFS_userid    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
  my $NFS_passwd    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};

  $logger->info(__PACKAGE__ . ".$sub NFS IP Address => $nfsipaddress and NFS MOUNT POINT => $nfsmountpoint");

  unless ($nfsipaddress) {
    $logger->warn(__PACKAGE__ . ".$sub Unable to find NFS IP Address");
    $nfsipaddress = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    unless ($nfsipaddress) {
      $logger->error(__PACKAGE__ . ".$sub NFS IP ADDRESS MUST BE DEFINED in TMS for the GSX");
      return 0;
    }
  }
  unless ($NFS_userid) {
    $logger->warn(__PACKAGE__ . ".$sub NFS User ID MUST BE DEFINED in TMS for the GSX");
    return 0;
  }
  unless ($NFS_passwd) {
    $logger->warn(__PACKAGE__ . ".$sub NFS Password MUST BE DEFINED in TMS for the GSX");
    return 0;
  }
  unless ($nfsmountpoint) {
    $logger->warn(__PACKAGE__ . ".$sub Unable to find NFS Mount point");
    $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};
    unless ($nfsmountpoint) {
      $logger->warn(__PACKAGE__ . ".$sub NFS Mount Point MUST BE DEFINED in TMS for the GSX");
      return 0;
    }
  }
  $self->{nfs_session} = SonusQA::DSI->new(
                                  -OBJ_HOST     => $nfsipaddress,
                                  -OBJ_USER     => $NFS_userid,
                                  -OBJ_PASSWORD => $NFS_passwd,
                                  -OBJ_COMMTYPE => "SSH",);
  unless ( $self->{nfs_session} ) {
    $logger->error(__PACKAGE__ . ".$sub Could not open connection to NFS");
    $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required SonusNFS \($nfsipaddress\)");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
    return 0;
  }

  $logger->debug(__PACKAGE__ . ".$sub Connected to NFS");
  return 1;

}

=pod

=head1 findGsxSWPath()

   This subroutine is used to find the software path of the GSX.

=over 

=item Arguments :

    None.

=item Return Values :

    Returns the GSX software path

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub findGsxSWPath()
{
  my ($self) = @_;
  my $sub = "findGsxSWPath";
  my ($softwarePath, $cmd,@cmdResults);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

  # get the software path                  
  $cmd = "SHOW NFS SHELF 1 ADMIN";
  $logger->debug(__PACKAGE__ . ".$sub Executing command $cmd");

  @cmdResults = $self->execCmd($cmd);

  foreach(@cmdResults) {
    if(m/Software Path:\s+(\S+)/) {
      $softwarePath = $1;
      last;
    }
  }

  # If we couldn't get the Software path, return from here
  if(!defined($softwarePath)) {
    $logger->error(__PACKAGE__ . ".$sub Unable to get software path");
  }
  else {
    $logger->debug(__PACKAGE__ . ".$sub Got the software path : $softwarePath");
  }

  return $softwarePath;
}

=pod

=head1 renameOldCoreFiles()

    This subroutine is used to rename the existing core files are old_core*.

=over 

=item Arguments :

    None.

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub renameOldCoreFiles()
{

   my ($self) = @_;
   my $sub = "renameOldCoreFiles()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

   my ($cmd,$conn1,$dsiObj,@coreFiles,$numcore);

   if (!defined ($self->{nfs_session})) {
     $conn1 = $self->connectToNFS();
     if ($conn1 == 0)
     {
       $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
       return 0;
     }
   }

   if (!defined ($self->{CORE_DIR})) {
     my $GsxSWPath = $self->findGsxSWPath();
     unless($GsxSWPath) {
       $logger->error(__PACKAGE__ . ".$sub Unable to find Software Path from GSX");
       return 0;
     }
     my $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};
     $self->{CORE_DIR} = "$nfsmountpoint/$GsxSWPath/coredump";
     # Remove double slashes if present
     $self->{CORE_DIR} =~ s|//|/|;
   }

   $dsiObj = $self->{nfs_session};
   $cmd = "cd $self->{CORE_DIR}";
   $dsiObj->{conn}->cmd($cmd);

   $cmd = "ls -1 core*";
   @coreFiles = $dsiObj->{conn}->cmd($cmd);

   $logger->info(__PACKAGE__ . ".$sub @coreFiles");

   foreach(@coreFiles) {
      if(m/No such file or directory/i) {
         $logger->info(__PACKAGE__ . ".$sub There are no existing core files on the NFS");
         return 1;
      }
   }

   my $newfileNm;
   # Move all core files
   foreach (@coreFiles) {
       chomp($_);
       $newfileNm = $_;
       $newfileNm =~ s/core/old_core/;
       $cmd = "mv $_ $newfileNm";
       $logger->info(__PACKAGE__ . ".$sub Renaming existing core file $_ as $newfileNm");
       $dsiObj->{conn}->cmd($cmd);
   }
   return 1;
}

=pod

=head1 createSecurityDirOnNFS()

    This subroutine is used to create the security directories on the NFS server. It creates a directory named security under the mount path and under mount path/nodename.

=over 

=item Arguments :

    None.

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Author :

Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub createSecurityDirOnNFS() {

  my ($self)=@_;
  my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $conn1);
  my $sub = "createSecurityDirOnNFS";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Get node name and NFS details
  ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

  if (!defined($nodename)) {
    $logger->error(__PACKAGE__ . ".$sub NODE NAME MUST BE DEFINED");
    return 0;
  }

  if (!defined($nfsmountpoint)) {
    $logger->error(__PACKAGE__ . ".$sub Unable to determine the NFS Mount Path");
    return 0;
  }
  if (!defined ($self->{nfs_session})) {
     $conn1 = $self->connectToNFS();
     if ($conn1 == 0)
     {
       $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
       return 0;
     }
  }

  # Check if a / is required to be added
  if ($nfsmountpoint !~ "\/\$") {
    $logger->info(__PACKAGE__ . ".$sub $nfsmountpoint does not contain a / at the end");
    $nfsmountpoint = $nfsmountpoint . '/';
  } 

  # Execute commands to create the security directories
  $cmd = "mkdir $nfsmountpoint"."security";
  @cmdresults = $self->{nfs_session}->{conn}->cmd($cmd);
  $logger->info(__PACKAGE__ . ".$sub Executed Command $cmd on NFS");
  $logger->info(__PACKAGE__ . ".$sub @cmdresults");

  $cmd = "mkdir $nfsmountpoint$nodename\/security";
  @cmdresults = $self->{nfs_session}->{conn}->cmd($cmd);
  $logger->info(__PACKAGE__ . ".$sub Executed Command $cmd on NFS");
  $logger->info(__PACKAGE__ . ".$sub @cmdresults");

  return 1;
}  

=pod

=head1 initializeLSWU()

    This subroutine is used to initialize the live software upgrade process after checking for the prerequisites

=over

=item Arguments :

   1. Name of the software directory where the images and other files can be found.
   2. Call Accounting Manager Patch version(optional)

=item Return Values :

   1 - If the software upgrade was successfully started
   0 - If the software upgrade could not be initialized

=item Example :

  my $res = initializeLSWU("V07.03.05R001");

  ****************************************************************************************
  # Sample code to automate the complete LSWU procedure
  my $res = $gsxObj->initializeLSWU("V07.03.05R001");
  unless ($res) {
    # Fail the test case since an error was encountered while initializing the upgrade
    print "\nSoftware Upgrade Initialize failed\n";
    return 0;
  }

  my $i = 0;
  my $result = 0;
  for ($i = 0; $i <= 30; $i++) {
    $res = $gsxObj->monitorLSWU();

    ###### ADD ANY ADDITIONAL CHECKS THAT MIGHT BE REQUIRED TO BE DONE DURING THE UPGRADE

    $res = $gsxObj->commitLSWU();
    if ($res == 0) {
      print "\nSoftware Upgrade in progress\n";
      sleep(60);
    } else {
      print "\nSoftware Upgrade completed and committed\n";
      $result = 1;
      last;
    }
  }

  if ($result == 0) {
    print "\nSoftware Upgrade Failed\n";
    return 0;
  }

  $res = $gsxObj->revertSWPath("V07.03.05R000");
  unless ($res) {
    # Fail the test case since an error was encountered while reverting the software path
    $result = 0;
  }
  ****************************************************************************************

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub initializeLSWU {

  my ($self,$software_path, $cam_version)=@_;
  my (@res,@res1,$res2,@res3,$init_status,$i,$sh,$sl,$fail,$threshold);
  my $sub = "initializeLSWU";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  my ($tmp,$redGrpName);

  # Check if the redundant groups are in ACTIVESYNCED state
  @res1 = $self->execCmd("SHOW REDUNDANCY GROUP SUMMARY");
  foreach $tmp ( @res1 )
  {
     chomp($tmp);
     if ( $tmp =~ m/^\s*(\S+)\s+\d+\s+\d+\s+\S+\s+\S+\s+\S+\s*$/ ) {
       $redGrpName = $1;
       # Check if the redundant group has achieved synchronization
       @res = $self->execCmd("SHOW REDUNDANCY GROUP $redGrpName STATUS");
       $res2 = grep("ACTIVESYNCED",@res);
       if ($res2 == 0) {
         $logger->error(__PACKAGE__ . ".$sub Redundancy Group $redGrpName is not in ACTIVESYNCED STATE");
         return 0;
       } else {
         $logger->info(__PACKAGE__ . ".$sub Redundancy Group $redGrpName is in ACTIVESYNCED STATE");
       }

       # If the redundant slot state in any of the non-MNS redundant group is ACTIVE, then REVERT
       if ($redGrpName !~ "^MNS") {
         $res2 = grep(/Redundant Slot State:\s+ACTIVE/,@res);
         if ($res2 != 0) {
           $logger->error(__PACKAGE__ . ".$sub Redundancy slot is in ACTIVE STATE for group $redGrpName...Performing REVERT");
           @res = $self->execCmd("CONFIGURE REDUNDANCY GROUP $redGrpName REVERT");
           $i = 0;
           sleep(60);
           $res2 = grep(/Redundant Slot State:\s+STANDBY/,@res);
           while(($res2 == 0) && ($i < 12)) { 
             sleep(10);
             # Check if the redundant slot state is STANDBY 
             @res = $self->execCmd("SHOW REDUNDANCY GROUP $redGrpName STATUS");
             $res2 = grep(/Redundant Slot State:\s+STANDBY/,@res);
             $i++;
           }
           if ($res2 == 0) {
             $logger->error(__PACKAGE__ . ".$sub Redundancy slot is not in STANDBY state for group $redGrpName");
             return 0;
           }
           sleep(90);
         } else {
           $logger->info(__PACKAGE__ . ".$sub Redundancy slot is not in ACTIVE STATE for group $redGrpName");
         }
       }
     }
  }

  # Update the directory path for the upgrade
  @res = $self->execCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 DIRECTORY $software_path");
  $logger->info(__PACKAGE__ . ".$sub Executed Command: CONFIGURE SOFTWARE UPGRADE SHELF 1 DIRECTORY $software_path");
  sleep(20); # Wait for the parameter to be written before proceeding
  if (defined $cam_version) {
    @res = $self->execCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 ACCOUNTING PATCHVERSION $cam_version");
    $logger->info(__PACKAGE__ . ".$sub Executed Command: CONFIGURE SOFTWARE UPGRADE SHELF 1 ACCOUNTING PATCHVERSION $cam_version");
    sleep(20); # Wait for the parameter to be written before proceeding
  }

  # Check for link failures
  @res = $self->execCmd("SHOW LINK FAILURE STATISTICS ALL");
  @res1 = $self->execCmd("SHOW LINK DETECTION GROUP ALL ADMIN");
  foreach (@res) {
    if ( m/\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ) {
      if ($4 > 0) { 
        $sh = $1;
        $sl = $2;
        $fail = $4;
        $logger->info(__PACKAGE__ . ".$sub There are $fail port failures in the slot $sl and shelf $sh");
        @res3 = grep(/\s+\d+\s+\S+\s+$sh\s+$sl\s+\d+/, @res1);
        if ($#res3 > 0) {
          $threshold = $res3[0];
          $res3[0] =~ s/\s+\d+\s+\S+\s+$sh\s+$sl\s+//;
          chomp($res3[0]);
          $res3[0] =~ s/\s+//g;
          $logger->info(__PACKAGE__ . ".$sub The configured threshold port failures for the slot and shelf is $res3[0]");
          if ($fail > $res3[0]) {
            $logger->error(__PACKAGE__ . ".$sub The port failures is more than the configured threshold for the slot and shelf");
            return 0;
          }
        }
        else {
          $logger->info(__PACKAGE__ . ".$sub Threshold is not configured for the given slot and shelf");
        }
      } 
    }
  }

  # Initialize Upgrade
  $res2 = $self->execCliCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 INITIALIZE");
  if ($res2 == 0) {
    $i = 0;
    while(($res2 == 0) && ($i < 5)) {
      sleep(2);
      $logger->error(__PACKAGE__ . ".$sub Software Upgrade Initialize Failed");
      $res2 = $self->execCliCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 INITIALIZE");
      $i++;
    }
    if (($res2 == 0) && ($i == 5)) {
      $logger->error(__PACKAGE__ . ".$sub Software Upgrade Initialize Failed");
    }
  }

  # Check if initialization was successful
  @res = $self->execCmd("SHOW SOFTWARE UPGRADE SHELF 1 STATUS"); 
  $init_status = 0;
  foreach(@res) {
    if ( m/Current State:\s+(\S+)/i ) {
      if ($1 eq "INIT") {
        $logger->info(__PACKAGE__ . ".$sub Software Upgrade Initialize succeeded");
        $init_status = 1;
      }
      else {
        $logger->error(__PACKAGE__ . ".$sub Software Upgrade Initialize Failed");
      }
      last;
    }
  }

  if ($init_status == 0) {
    @res1 = grep(/Last Reason/,@res);
    $logger->error(__PACKAGE__ . ".$sub CONFIGURE SOFTWARE UPGRADE SHELF 1 INITIALIZE - FAILED");
    $logger->error(__PACKAGE__ . ".$sub $res1[0]");
    return 0;
  }   

  $self->execCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 UPGRADE NOW");

  $logger->info(__PACKAGE__ . ".$sub Software Upgrade started successfully");
  print "\nSoftware Upgrade started successfully\n";
  return 1;

}

=pod

=head1 monitorLSWU()

    This subroutine is used to log the Software upgrade status during LSWU.

=over 

=item Arguments :

   None

=item Return Values :

   1 - If the software upgrade status was successfully logged
   0 - If any errors were encountered while reconnecting to the GSX (if the connection was lost)

=item Example :

  my $res = monitorLSWU();

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut 

sub monitorLSWU() {

  my ($self)=@_;
  my (@res,$res1,$res2);
  my $sub = "monitorLSWU";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Log the upgrade status
  @res = $self->execCmd("SHOW SOFTWARE UPGRADE SHELF 1 STATUS");

  # Check if the connection is lost and if so, reconnect to the GSX
  $res1 = $self->{conn}->lastline;
  if ($res1 =~ m/Connection.*closed/i) {
    $res2 = $self->reconnect();
    if ($res2 == 0) {
      $logger->error(__PACKAGE__ . ".$sub Unable to reconnect to the GSX!!!");
      return 0;
    }
    @res = $self->execCmd("SHOW SOFTWARE UPGRADE SHELF 1 STATUS");
  }

  $logger->info(__PACKAGE__ . ".$sub STATUS OF UPGRADE");
  foreach (@res) {
    $logger->info(__PACKAGE__ . ".$sub $_");
  }

  return 1;
}

=pod

=head1 commitLSWU()

    This subroutine is used to complete the live software upgrade procedure by commiting the upgrade directory. The directory will be committed only if the upgrade is complete, otherwise, an error is returned. It also logs if the software of all the cards have been upgraded if LSWU was successful.

=over

=item Arguments :

   None

=item Return Values :

   1 - If the command "CONFIGURE SOFTWARE UPGRADE SHELF 1 COMMIT DIRECTORY" was successful
   0 - If upgrade is not complete or if any errors were encountered during the execution of command - "CONFIGURE SOFTWARE UPGRADE SHELF 1 COMMIT DIRECTORY"

=item Example :

  my $res = commitLSWU();

=item Author :

 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub commitLSWU() {

  my ($self)=@_;
  my ($res,@res1,$dir,$dir1,$sh,$sl);
  my $sub = "commitLSWU";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  my $stat1 = 0;
  my $stat2 = 0;

  # Check if the upgrade is complete
  @res1 = $self->execCmd("SHOW SOFTWARE UPGRADE SHELF 1 STATUS");

  $logger->info(__PACKAGE__ . ".$sub STATUS OF UPGRADE");
  foreach (@res1) {
    if ( m/Status:\s+COMMITREQUIRED/i ) {
      $stat1 = 1;
    } elsif (m/Last Reason:\s+SUCCESSFULCOMPLETION/i) {
      $stat2 = 1;
    }
  }

  if (($stat1 == 0) || ($stat2 == 0)) {
    $logger->error(__PACKAGE__ . ".$sub UPGRADE HAS NOT BEEN COMPLETED and hence cannot be committed");
    return 0;
  }

  # If the upgrade is complete, check if the software version of all the slots have been upgraded
  foreach (@res1) {
    if (m/Directory:\s+(\S+)/i) {
      $dir = $1; 
      $logger->info(__PACKAGE__ . ".$sub Software Upgrade Directory : $dir");
      last;
    }
  }

  @res1 = $self->execCmd("SHOW SERVER SHELF 1 STATUS SUMMARY");
  foreach (@res1) {
    if (m/^(\d+)\s+(\d+)\s+(V.*)V/i) {
      $sh = $1;
      $sl = $2;
      $dir1 = $3;

      # Remove the spaces
      $dir1 =~ s/\s+//g;

      # Check if the cards have been upgraded to the specified version
      if ($dir eq $dir1) {
        $logger->info(__PACKAGE__ . ".$sub Software Upgraded for card in Shelf $sh Slot $sl");
      } else {
        $logger->error(__PACKAGE__ . ".$sub Software NOT Upgraded for card in Shelf $sh Slot $sl");
      }
    }
  }

  # Commit the directory since the upgrade is complete
  $res = $self->execCliCmd("CONFIGURE SOFTWARE UPGRADE SHELF 1 COMMIT DIRECTORY");

  if ($res == 1) {
    $logger->info(__PACKAGE__ . ".$sub Software Upgrade Commit directory was successful");
    return 1;
  }
  else {
    $logger->info(__PACKAGE__ . ".$sub Software Upgrade Commit directory failed");
    return 0;
  }
}

=pod

=head1 revertSWPath()
    This subroutine is used to revert the software path of the GSX.

Arguments :
   Software Path

Return Values :
   1 - If the command "CONFIGURE NFS SHELF 1 SOFTWARE PATH " was successful
   0 - If any errors were encountered during the execution of command - "CONFIGURE NFS SHELF 1 SOFTWARE PATH "

Example :
  my $res = revertSWPath("V07.03.05R000");

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub revertSWPath {

  my ($self,$swpath)=@_;
  my $res;
  my $sub = "revertSWPath";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  $res = $self->execCliCmd("CONFIGURE NFS SHELF 1 SOFTWARE PATH $swpath");

  if ($res == 1) {
    $logger->info(__PACKAGE__ . ".$sub Successfully set the Software path to $swpath");
    return 1;
  }
  else {
    $logger->error(__PACKAGE__ . ".$sub Could not set the Software path to $swpath");
    return 0;
  }

}


=pod

=head1 getCurLogPath()
   This subroutine is used to get the full path of the current DBG/SYS/TRC/ACT log file.

Arguments :
   Log type(Should be one of the following - DBG, SYS, TRC or ACT).

Return Values :
   Returns the full log file path.

Example :
   my $dbgLogPath = $gsxObj->getCurLogPath("DBG");

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub getCurLogPath() {
    my ($self,$logtype)=@_;
    my (@cmdresults, $cmd, $log_name, $logname, $logfullpath);
    my $sub = "getCurLogPath";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entered Sub -->");
    $logger->info(__PACKAGE__ . ".$sub RETRIEVING ACTIVE GSX $logtype LOG");
    unless($self->getLogDir()){
        $logger->error(__PACKAGE__ . ".$sub Unable to get the Log Directory");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub[0]");
        return 0;
    }
    $log_name = "SYSTEM" if ($logtype =~ /SYS/i);
    $log_name = "DEBUG" if ($logtype =~ /DBG/i);	
    $log_name = "TRACE" if ($logtype =~ /TRC/i);
    $log_name = "ACCT" if ($logtype =~ /ACT/i);
    $log_name = "CLI" if ($logtype =~ /CLI/i);

    # Determine name of current log
    $cmd = "show event log all status";
    @cmdresults = $self->execCmd($cmd);
    $self->{$logtype.'_PATH'} = '';
    $self->{$logtype.'_NAME'} = '';
    foreach(@cmdresults) {
        if (m/(\w+.$logtype)/) {
            $logname = "$1";
	    $logfullpath = $self->{LogDir}."/$logtype/"."$logname";
            $self->{$logtype.'_PATH'} = $self->{LogDir}."/$logtype";
            $self->{$logtype.'_NAME'} = $logname;
	    $logger->info(__PACKAGE__ . ".$sub Got the current $logtype log file path $logfullpath");
        } elsif (m/\S+\s+($log_name)\s+\S+\s+RECOVERING/) {          # Introduced to skip the logfile capture if the string is encountered , CQ - SONUS00137197 
	    $logger->info(__PACKAGE__ . ".$sub filename is still recovering, skipping the logfile");	
	    $logfullpath = 1;
	} 
    }
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub [$logfullpath]");
    return $logfullpath;
}

=pod

=head1 searchSYSlog()
    This subroutine is used to find the number of occurrences of a list of patterns in the GSX SYS log

Arguments :
   Array containing the list of patterns to be searched on the GSX sys log

Return Values :
   Hssh containing the pattern being searched as the key and the number of occurrences of the same in the sys log as the value

Example :
  my @patt = ("msg","msg =","abc");
  my %res = $gsxobj->searchSYSlog(\@patt);

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub searchSYSlog() {

    my ($self,$patterns)=@_;
    my %retHash;

    %retHash = $self->searchLog("SYS",$patterns);
    return %retHash;

}

=pod

=head1 searchTRClog()
    This subroutine is used to find the number of occurrences of a list of patterns in the GSX TRC log

Arguments :
   Array containing the list of patterns to be searched on the GSX trc log

Return Values :
   Hash containing the pattern being searched as the key and the number of occurrences of the same in the trc log as the value

Example :
  my @patt = ("msg","msg =","abc");
  my %res = $gsxobj->searchTRClog(\@patt);

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub searchTRClog() {

    my ($self,$patterns)=@_;
    my %retHash;

    %retHash = $self->searchLog("TRC",$patterns);
    return %retHash;

}

=pod

=head1 searchCLIlog()
    This subroutine is used to find the number of occurrences of a list of patterns in the GSX CLI log

Arguments :
   Array containing the list of patterns to be searched on the GSX cli log

Return Values :
   Hash containing the pattern being searched as the key and the number of occurrences of the same in the trc log as the value

Example :
  my @patt = ("msg","msg =","abc");
  my %res = $gsxobj->searchCLIlog(\@patt);


=cut

sub searchCLIlog() {

    my ($self,$patterns)=@_;
    my %retHash;

    %retHash = $self->searchLog("CLI",$patterns);
    return %retHash;

}


sub searchLog() {

    my ($self,$logtype,$patterns)=@_;
    my @pattArray = @$patterns;
    my ($conn1,$logfullpath,%returnHash,$cmd1,$patt,$string);
    my $sub = "searchLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Connect to the NFS server
    $conn1 = $self->connectToNFS();
    if ($conn1 == 0) {
        $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS Server");
        return %returnHash;
    }

    # Get the name of the latest log file
    $logfullpath = $self->getCurLogPath($logtype);

    # Find the number of occurences of the patterns in the sys log
    foreach $patt (@pattArray){
        $cmd1 = 'grep -c "'.$patt.'" '. $logfullpath ;

        my @cmdResults;
        unless (@cmdResults = $self->{nfs_session}->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
            $logger->warn(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
	    $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{nfs_session}->{conn}->errmsg);
    	    $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{nfs_session}->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{nfs_session}->{sessionLog2}");
            return %returnHash;
        }

        $string = $cmdResults[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $logger->debug(__PACKAGE__ . ".$sub Number of occurrences of the string \"$patt\" in $logfullpath is $string");
        unless($string){
            $logger->info(__PACKAGE__ . ".$sub No occurrence of $patt in $logfullpath");
            $string = 0;
        };
        $returnHash{$patt} = $string;
    }
    return %returnHash;

}


=pod

=head1 copyGSXLogToServer()

    This subroutine is used to copy the specified GSX log (such as SYS, DBG, ACT or TRC) file from GSX to specified server and path.
    If server is not mentioned, it will copy the log to the server where you are running the test and at the path you mentioned in 
    'destDir'. If the directory is not mentioned then it will copy to the path where you are running the test.

=over 

=item Arguments :

    $GSXObj->copyGSXLogToServer(logType             => ['SYS', 'DBG', 'ACT', 'TRC'],
                                [destServerIP       => $destServerIP],
                                [destServerUserName => $destServerUserName],
                                [destServerPasswd   => $destServerPasswd],
                                [destDir            => $destDir],
                                [destFileName       => $destFileName],
                       		[testCaseId         => $testcaseid],
					);
    $GSXObj->copyGSXLogToServer(logType => 'SYS', testCaseId => $testcaseid);

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Author :

 Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub copyGSXLogToServer() {
    my ($self, %args) = @_;
    my $sub = "copyGSXLogToServer()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $destFileName = "";
    my $dest_path;   
    my ($currentDirPath, $tarFileName);    

    if (not exists $args{logType}) {
        $logger->error("logType is missing. This is a mandatory argument");
        return 0;
    } 
    
    $logger->info("Log Type Is: $args{logType}");
    
    my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
    $year  += 1900;
    $month += 1;
    my $timeStamp; 

    if(defined ($args{testCaseId})){
        $timeStamp = $args{testCaseId} . "-" . $args{logType} . "-" . $hour . $min . $sec . "-" . $day . $month . $year ;
    }else{
	$timeStamp = "NONE" . "-" . $args{logType} . "-" .  $hour . $min . $sec . "-" . $day . $month . $year ;
    }	
    
    #If you specified destination server then you must specify username password and directory of that server in %args
    if (exists $args{destServerIP}) {
        $logger->info("Destination Server User name: $args{destServerUserName}");
        $logger->info("Destination Server Password : \$args{destServerPasswd}");
        $logger->info("Destination Directory       : $args{destDir}");
        
        unless (exists $args{destServerUserName} && exists $args{destServerPasswd} && exists $args{destDir}) {
            $logger->error("Either destServerUserName or destServerPasswd or destDir is missing");
            return 0;
        }
                                
        $logger->info("GSX $args{logType} logs will be copied to,");
        $logger->info("server    --> $args{destServerIP}");
        $logger->info("File Name --> $args{destDir}/$destFileName");
            
    } 

    my $user_home = qx#echo ~#;
    chomp($user_home);
    my $logDetails = $self->getGsxLogDetails(-logType =>$args{logType});
    unless ($logDetails) {
        $logger->error("Unable to get log details for GSX log type $args{logType}");
        return 0;
    }
    
    my %logDetails = %{$logDetails};
    $logger->info("\nNFS-IP: $logDetails{-nfsIp} \nLOG-PATH: $logDetails{-logPath} \nLOG-FILES: @{$logDetails{-fileNames}} \nREMOTE-COPY: $logDetails{-remoteCopy} \nNODE-NAME: $logDetails{-nodeName}");

    #Now get the log path in NFS server
    my $nfsSessObj;
    my @fileNameList = @{$logDetails{-fileNames}};
    my $srcLogDir = $logDetails{-logPath};
    my $nfsipaddress = $logDetails{-nfsIp};
    $logger->info("$args{logType} log path is: $srcLogDir");

    if ($logDetails{-remoteCopy}) {
        #Now get the NFS server IP
        
        my $nfsUserId = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
        my $nfsPasswd = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
    
        #Now make SFTP to NFS server
        $nfsSessObj = new Net::SFTP( $nfsipaddress,
                                    user     => $nfsUserId,
                                    password => $nfsPasswd,
                                    debug    => 0,);

        unless ($nfsSessObj) {
            $logger->error("Could not open sftp connection to NFS server --> $nfsipaddress");
            return 0;
        }

        $logger->info("SFTP connection to NFS server  $nfsipaddress is successfull");
    }

    #Start copying the files
    my ($destPath, $destDir, $srcLogPath);

    if (exists $args{destDir}) {
        $destDir = "$args{destDir}" . '/' . "$logDetails{-nodeName}" .'-' . "$timeStamp";
    } else {
	$dest_path = "$user_home/ats_user/logs";
	if(-e $dest_path ){
	    $currentDirPath = $dest_path;
	}else{  
	    qx#mkdir -p $user_home/ats_user/logs#;
	    $currentDirPath = $dest_path;
	} 
	
        chomp ($currentDirPath);
        $destDir = "$currentDirPath" . '/' . "$logDetails{-nodeName}" .'-' . "$timeStamp";
    }
    foreach my $fileName (@fileNameList) {
        $srcLogPath = "$srcLogDir" . "$fileName";
        if ($logDetails{-remoteCopy}) {
            $nfsSessObj->get($srcLogPath, $fileName);
        } else {
            my $status = `cp $srcLogPath $fileName`;
        }
    
        if (-e $fileName) {
            $logger->info("Successfully copied the file $fileName");
        } else {
            $logger->info("Unable to copy the to local server");  
            return 0;
        } 
    }

    #zip all the log files and copy to destination path
    $tarFileName = "$destDir" . '.tar';
    $logger->info("Tar file name will be --> $tarFileName"); 
    my $status = `/bin/tar -czvPf $tarFileName @fileNameList`;
    $status = `rm -rf @fileNameList`;
    unless (-e $tarFileName) {
        $logger->error(__PACKAGE__ . ".$sub: Zipping logfile is failed");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Zipping logfile is successful !!!");

    if (not exists $args{destServerIP}) {
        $logger->info("Successfully copied $args{logType} to your local server at --> $tarFileName");
        return 1;
    }

    #Now make SFTP connection to destination server(If you want to copy logs from your local server to any other remote server)
    my $destServerSess = new Net::SFTP( $args{destServerIP},
                                       user     => $args{destServerUserName},
                                       password => $args{destServerPasswd},
                                       debug    => 0,);

    unless ( $destServerSess ) {
        $logger->error("Could not open sftp connection to destination server --> $args{destServerIP}");         
        return 0;
    }   

    $logger->info("SFTP connection to destination server  $args{destServerIP} is successfull");
    
    #Now copy the local copy of file to destination server
    my $localCopy      = $tarFileName;
    my $destServerFile = "$args{destDir}/";
     
    unless ($destServerSess -> put($localCopy, $destServerFile)) {
        $logger->error("Unable to copy to destination server --> $args{destServerIP}");
        $logger->error("Check the directory you mentioned is present on server, if present check the permissions");                 
        return 0;
    }   

    $logger->info("Successfully copied file to destination server --> $args{destServerIP} at the path --> $destServerFile");
    
    #Now remove the local copy
    qx#rm -rf $localCopy#;
    
    unless (-e $tarFileName) {
        $logger->info("Successfully removed the local copy");
    } else {
        $logger->info("Unable to remove the local copy");
    }

    return 1;  
}

=pod

=head1 resetCallCounts()

    Reset call counts

Arguments :
   Mandatory :    None

   Optional  :    None

Return Values :

   0 - Failed
   1 - Success

Example :
   $gsx_object->resetCallCounts();

Author :

=cut

sub resetCallCounts {
    my ($self, %args) = @_;
    my $sub = "resetCallCounts()";
    my %a;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

    $logger->debug(__PACKAGE__ . ".$sub Resetting call counts");
    my @CommandResults = $self->execCmd("CONFIGURE CALL COUNTS SHELF 1 RESET");
    $logger->debug(__PACKAGE__ . ".$sub command return : @CommandResults");

    $logger->debug(__PACKAGE__ . ".$sub Resetting accounting summary");
    @CommandResults = $self->execCmd("CONFIGURE ACCOUNTING SUMMARY RESET");
    $logger->debug(__PACKAGE__ . ".$sub command return : @CommandResults");

    return 1;
}

=pod

=head1 getCallCountsAll()

    Reset call counts

Arguments :
   Mandatory :    None

   Optional  :    None

Return Values :

   0 - Failed
   1 - Success

Example :
   $gsx_object->getCallCountsAll();

Author :

=cut

sub getCallCountsAll {
    my ($self, %args) = @_;
    my $sub = "getCallCountsAll()";
    my %a;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

    my @commandResults = $self->execCmd("SHOW CALL COUNTS ALL");

    foreach(@{$self->{CMDRESULTS}}){
       chomp($_);
       if($_ =~ m/\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/){
          $self->{CALL_COUNTS}{$1}{$2}{CALL_ATTEMPTS} = $3;
          $self->{CALL_COUNTS}{$1}{$2}{COMPLETIONS} = $4;
          $self->{CALL_COUNTS}{$1}{$2}{ACTIVE_CALLS} = $5;
          $self->{CALL_COUNTS}{$1}{$2}{STABLE_CALLS} = $6;
          $self->{CALL_COUNTS}{$1}{$2}{TOTAL_CALLS} = $7;
          $self->{CALL_COUNTS}{$1}{$2}{ACTIVE_NON_CALL_SIGNAL_CHANNELS} = $8;
          $self->{CALL_COUNTS}{$1}{$2}{STABLE_NON_CALL_SIGNAL_CHANNELS} = $9;
       }
    }

    return 1;
}

=pod

=head1 resetAllCICs()

    Reset ALL CICs

Arguments :
   Mandatory :
      -serviceName     => ISUP service Name

   Optional  :    None

Return Values :

   0 - Failed
   1 - Success

Example :
   $gsx_object->resetAllCICs( -serviceName   => "ss71");

Author :

=cut

sub resetAllCICs {
    my ($self, %args) = @_;
    my $sub = "resetAllCICs()";
    my %a;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

    if(!defined ($a{-serviceName})) {
       $logger->error(__PACKAGE__ . ".$sub needs service name");
       return 0;
    }

    $self->{conn}->cmd("set NO_CONFIRM 1");

    # Sometimes, this update is taking more time
    # Adding a delay for the update to happen before we execute the commands
    sleep 5;

    my @commandArray = ( "CONFIGURE ISUP CIRCUIT SERVICE $a{-serviceName} CIC ALL MODE reset",
                         "CONFIGURE ISUP CIRCUIT SERVICE $a{-serviceName} CIC ALL MODE blo",
                         "CONFIGURE ISUP CIRCUIT SERVICE $a{-serviceName} CIC ALL MODE unblo"
                       );

    my $cmdString;
    foreach $cmdString (@commandArray) {
       $logger->debug(__PACKAGE__ . ".$sub Executing $cmdString");

       my @commandResults = $self->execCmd($cmdString);
       $logger->debug(__PACKAGE__ . ".$sub Command results @commandResults");
    }

    return 1;
}

=head1 getSlotNos()

    Get slot numbers

Arguments :
   Mandatory :
      -serviceName     => ISUP service Name

   Optional  :
      -type            => Type
                          Default : T1
Return Values :

   0 - Failed
   Array of slot numbers

Example :
   my @slotNos = $gsx_object->getSlotNos( -serviceName   => "ss71");

Author :

=cut

sub getSlotNos {
   my ($self, %args) = @_;
   my $sub = "getSlotNos()";
   my %a = (-type     => "T1");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

   if(!defined ($a{-serviceName})) {
      $logger->error(__PACKAGE__ . ".$sub needs service name");
      return 0;
   }

   my $cmdString = "SHOW ISUP CIRCUIT SERVICE $a{-serviceName} CIC ALL ADMIN";

   $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
   my @commandResults = $self->execCmd($cmdString);

   my $line;
   my @portNames = ();
   my $skipLines = 2;
   my $found;

   foreach $line (@commandResults) {
      if($skipLines gt 0) {
         if($line =~ m/----------/) {
            $skipLines = $skipLines - 1;
         }
         next;
      }

      if($line =~ m/\d+\s+(\S+).*/) {
         $found = 0;
         foreach (@portNames) {
            if($_ eq $1) {
               $found = 1;
               last;
            }
         }
         if($found eq 0) {
            push(@portNames, $1);
         }
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub got the port names as @portNames");

   my @slotNos = ();
   my $slot;

   foreach (@portNames) {
      $cmdString = "SHOW $a{-type} $_ ADMIN";
      $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
      @commandResults = $self->execCmd($cmdString);

      foreach $line (@commandResults) {
         if($skipLines eq 1) {
            if($line =~ m/----------/) {
               $skipLines = 0;
            }
            next;
         }

         if($line =~ m/^\S+\s+\d+\s+\S+\s+(\d+).*/) {
            $slot = $1;
            $logger->debug(__PACKAGE__ . ".$sub got slot as $slot. From $line");
            last;
         }
      }

      $found = 0;
      foreach (@slotNos) {
         if($_ eq $slot) {
            $found = 1;
            last;
         }
      }
      if($found eq 0) {
         push(@slotNos, $slot);
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub got the slot numbers as @slotNos");

   return @slotNos;
}

=head1 getSysStat()

    Get System Status

Arguments :
   Mandatory :
    -slotNumbers => Set of slot numbers
    -testCaseID  => Test Case Id
    -logDir      => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

Return Values :

   0 - Failed
   Log file name

Note :
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !! Needs to execute "admin debugSonus" prior to calling this   !!
    !! subroutine.                                                 !!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Example :

Author :

=cut

sub getSysStat {
   my ($self, %args) = @_;
   my $sub = "getSysStat()";
   my %a = (-variant   => "NONE",
            -timeStamp => "00000000-000000");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

   unless ( $a{-slotNumbers} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Slot numbers is empty or blank.");
      return 0;
   }

   unless ( $a{-testCaseID} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Test Case ID is empty or blank.");
      return 0;
   }
   unless ( $a{-logDir} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
      return 0;
   }

   my $tmsAlias = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   # Make the log file
   my $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "GSX-" . "$tmsAlias-" . "slotSysInfo.log" ;

   # Remove double slashes if present
   $logFile =~ s|//|/|;

   $logger->info(__PACKAGE__ . ".$sub Opening log file $logFile");

   # Open log file
   unless (open(PROCESSLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   my $markerLine = "----------------------- " . localtime(time) . " -----------------------";

   print PROCESSLOG $markerLine . "\n";

   my $cmdString = "SHOW NTP TIME";

   $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
   my @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> $self->{DEFAULTTIMEOUT} );

   print PROCESSLOG "@commandResults" . "\n";

   my $slot;
   foreach $slot (@{$a{-slotNumbers}}) {
      $cmdString = "cpuusage slot $slot";

      $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
      @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> $self->{DEFAULTTIMEOUT} );

      print PROCESSLOG "@commandResults" . "\n";

      $cmdString = "cpuh slot $slot";

      $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
      @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> $self->{DEFAULTTIMEOUT} );

      print PROCESSLOG "@commandResults" . "\n";

      $cmdString = "memusage slot $slot";

      $logger->debug(__PACKAGE__ . ".$sub Executing command $cmdString");
      @commandResults = $self->{conn}->cmd(String =>$cmdString, Timeout=> $self->{DEFAULTTIMEOUT} );

      print PROCESSLOG "@commandResults" . "\n";
   }

   #Close the log file
   $logger->info(__PACKAGE__ . ".$sub Closing log file");
   close(PROCESSLOG);

   return $logFile;
}

=pod

=head1 getAndInstallGSX()
    This subroutine is used to scp the GSX 9000 installable file from the specified server and perform the steps required for loading the build on the NFS server. This method DOES NOT CHANGE THE BUILD ON THE GSX. It only loads the build on the NFS server. To change the build on the GSX, call this interface and execute the cli command to change the build and reboot the GSX.

Arguments :
   1. IP Address of the server from where the load file needs to be copied
   2. User name to access the server
   3. Password of the user
   4. Complete path where the build file is present on the server

Return Values :
   0 - On Failure
   1 - On success

Example :
  my $result = $gsxObj->getAndInstallGSX("10.128.254.68","autouser","autouser","/sonus/ReleaseEng/Rsync/GSX-RELEASE.V08.02.00A011.tar_2011-02-06-22_23");

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub getAndInstallGSX() {

  my ($self,$svrIP,$svrUser,$svrPwd,$absLoadFilePath)=@_;
  my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $conn1,$prematch,$match,@cmdList);
  my $sub = "getAndInstallGSX";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Get node name and NFS details
  ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();

  if (!defined($nodename)) {
    $logger->error(__PACKAGE__ . ".$sub NODE NAME MUST BE DEFINED");
    return 0;
  }

  if (!defined($nfsmountpoint)) {
    $logger->error(__PACKAGE__ . ".$sub Unable to determine the NFS Mount Path");
    return 0;
  }
  if (!defined ($self->{nfs_session})) {
     $conn1 = $self->connectToNFS();
     if ($conn1 == 0)
     {
       $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
       return 0;
     }
  }

  # Check if a / is required to be added
  if ($nfsmountpoint !~ "\/\$") {
    $logger->info(__PACKAGE__ . ".$sub $nfsmountpoint does not contain a / at the end");
    $nfsmountpoint = $nfsmountpoint . '/';
  } 

  # SFTP the load file to the NFS server
  my @tmpArr = split /\//,$absLoadFilePath;
  $cmd = "scp $svrUser\@$svrIP:$absLoadFilePath /tmp/$tmpArr[-1]";
  $self->{nfs_session}->{conn}->print($cmd);
  unless (($prematch, $match) = $self->{nfs_session}->{conn}->waitfor(-match => '/[P|p]assword/i', -match => $self->{nfs_session}->{PROMPT}, -errmode => "return") ) {
    $logger->error(__PACKAGE__ . ".$sub Unable to scp file from server to the NFS - $prematch");
    $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{nfs_session}->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{nfs_session}->{sessionLog2}");
    return 0;
  }

  if ($match =~ /[P|p]assword/i) {
    @cmdresults = $self->{nfs_session}->{conn}->cmd($svrPwd);
    $logger->info(__PACKAGE__ . ".$sub scp output - @cmdresults");
  }

  # Check if the file has been transferred
  $cmd = "ls /tmp/$tmpArr[-1]";
  @cmdresults = $self->{nfs_session}->{conn}->cmd($cmd);
  $logger->info(__PACKAGE__ . ".$sub ls output - @cmdresults");
  @cmdresults = $self->{nfs_session}->{conn}->cmd("echo \$?"); 
  chomp($cmdresults[0]);
  if ("$cmdresults[0]" eq "0" ){
    $logger->info(__PACKAGE__ . ".$sub File has been successfully scped");
  } else {
    $logger->error(__PACKAGE__ . ".$sub Failed to SCP file $absLoadFilePath from remote server!");
    return 0;
  }

  # Install the GSX load file on the NFS
  @cmdList = ( "cd /tmp",
               "rm -rf SONUS_GSX",
               "tar -xvf $tmpArr[-1]",
               "chmod 777 SONUS_GSX",
               "cd SONUS_GSX" );

  foreach (@cmdList) {
    @cmdresults = $self->{nfs_session}->{conn}->cmd($_);
    $logger->info(__PACKAGE__ . ".$sub Output of $_ - @cmdresults");
  }

  # Find the name of the load tar file
  @cmdresults = $self->{nfs_session}->{conn}->cmd("ls GSX9000-INSTALL*");
  chomp($cmdresults[0]);
  $logger->info(__PACKAGE__ . ".$sub Install File Name - $cmdresults[0]");
  $cmd = "./install-gsx.sh $cmdresults[0] $nfsmountpoint$nodename";
  @cmdresults = $self->{nfs_session}->{conn}->cmd($cmd);
  $logger->info(__PACKAGE__ . ".$sub @cmdresults");
  $logger->info(__PACKAGE__ . ".$sub Successfully installed the GSX load on the NFS server");
  return 1;

}

=head1 checkGsxM3uarkStatus()

   This subroutine check the status of given point code and returns the result
Arguments :
   Mandatory :
      -pointCode       => Point code
                          E.g., 1-1-2 for ANSI
                                2-1-1 for JAPAN
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

      -statusInfo      => Reference Array of the status

   Optional:
      - netApp       => value of the netApp parameter.
                        E.g -> 1 or 2

      - lpc          => value of the local point code.
                         E.g., same as point code with different parameter.

Return Values :

   1 - The point code is in the requested status
   0 - Failed or the point code is not in the requested status

Example :

Author :

   my @statInfo  = qw(una una una ava);  For GR where 2 SGX clusters are used
              OR
   my @statInfo  = qw(una ava);   Normal scenario

   my $retCode = $gsx_session->checkGsxM3uarkStatus(-pointCode    => "1-1-40",
                                                    -protocolType => "ANSI",
                                                    -statusInfo   => \@statInfo); 
                                                    -netApp       => "1",
                                                    -lpc          => "1-1-30");

=cut

sub checkGsxM3uarkStatus {
   my ($self, %args) = @_;
   my $sub = "checkGsxM3uarkStatus()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->debug(__PACKAGE__ . ".$sub  Entered ", Dumper(%a));

   unless ( $a{-pointCode} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Point code is empty or blank.");
      return 0;
   }
   unless ( $a{-protocolType} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory protocol type is empty or blank.");
      return 0;
   }
   unless ( $a{-statusInfo} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory reference to status array is empty or blank.");
      return 0;
   }

   # Convert the point code
   my $pcInHex = SonusQA::TRIGGER::getHexFromPC(-pointCode    => $a{-pointCode},
                                                -protocolType => $a{-protocolType});
   if($pcInHex eq 0) {
      $logger->error(__PACKAGE__ . ".$sub Error in converting point code");
      return 0;
   }

   # Convert the Local Point Code
   my $lpcInHex ;

   if (defined $a{-lpc}) {
       $lpcInHex = SonusQA::TRIGGER::getHexFromPC(-pointCode    => $a{-lpc},
                                                  -protocolType => $a{-protocolType});
       if($lpcInHex eq 0) {
          $logger->error(__PACKAGE__ . ".$sub Error in converting local point code");
          return 0;
       }
   }

   my $grMode = 0;
   my $noStats = scalar @{$a{-statusInfo}};

   if($noStats eq 4) {
      $grMode = 1;
   }

   my $cmdString = "m3uark";

   unless($self->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI => $cmdString");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($self->{CMDRESULTS}));

   my $skipLines = 0;
   my $line;

   # Parse the output for the required string
   foreach $line ( @{ $self->{CMDRESULTS}} ) {
      $logger->info(__PACKAGE__ . ".$sub Checking in the following line : $line");
      if($skipLines lt 1) {
         $skipLines = $skipLines + 1;
         next;
      }

      if($line =~ m/----/) {
         next;
      }

      $logger->info(__PACKAGE__ . ".$sub line : $line");

      # Remove : from the line
      $line =~ s/:/ /g;
      # Get the point code and status
      if($line =~ m/\s+(\S+)\s+(\S+)\s+(\w+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)/) {
         my $netApp = $1 ;
         my $lpc = $2 ;
         my $pointCode = $3;
         my $stat1 = $4;
         my $stat2 = $5;
         my $stat3 = $6;
         my $stat4 = $7;

        my $count = 0 ;
         #get the netapp value if its defined by the user ;
         if (defined $a{-netApp}) {
            $logger->info(__PACKAGE__ . ".$sub value defined for Net App parameter");
            if ($netApp eq $a{-netApp}) {
               $logger->info(__PACKAGE__ . ".$sub found the mentioned instance of NetApp parameter, hence checking for other parameters.");
               $count = 1 ;

            } else {
               $logger->info(__PACKAGE__ . ".$sub Skipping to the next iteration of the loop");
               next ;
            }
            if ($count == 0){
               $logger->error(__PACKAGE__ . ".$sub Net App field is not matching for given value ");
               $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [0]");
               return 0;
            }

         }

         # get the lpc value if it's defined by user.
         if (defined $a{-lpc}) { 
            $count = 0 ;
            $logger->info(__PACKAGE__ . ".$sub value defined for lpc parameter");
            if ($lpc eq $lpcInHex) {
               $logger->info(__PACKAGE__ . ".$sub found the mentioned instance of lpc parameter, hence checking for other parameters.");
               $count ++ ;

            } else {
               next ;
            }
            if ($count == 0){
               $logger->error(__PACKAGE__ . ".$sub Local point Code field is not matching for given value ");
               $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [0]");
               return 0;
            }
         }

         # get the point code
         if ( $pointCode eq $pcInHex) {
            $logger->info(__PACKAGE__ . ".$sub point code is matching $pointCode");

            my $index = 0;
            my $stat;
            foreach $stat (@{$a{-statusInfo}}) {
               my $matchStat = 0;
               if($index eq 0) {
                  if($stat1 eq $stat) {
                     $matchStat = 1;
                  }
               } elsif ($index eq 1) {
                  if($stat2 eq $stat) {
                     $matchStat = 1;
                  }
               }
               # Check the next field for GR where 2 SGX clusters are present
               if ($grMode eq 1) {
                  if ($index eq 2) {
                     if($stat3 eq $stat) {
                        $matchStat = 1;
                     }
                  } elsif ($index eq 3) {
                     if($stat4 eq $stat) {
                        $matchStat = 1;
                     }
                  }
               }

               if($matchStat eq 0) {
                  $logger->error(__PACKAGE__ . ".$sub The status is not matching for index => $index");
                  return 0;
               }

               # Check the status check is completed
               if (($grMode eq 1 ) and ($index eq 3)) {
                  # All the 4 status are checked. Now we can return success
                  $logger->info(__PACKAGE__ . ".$sub All the 4 status are in required state.");
                  return 1;
               } elsif (($grMode eq 0) and ($index eq 1)) {
                  # All the 4 status are checked. Now we can return success
                  $logger->info(__PACKAGE__ . ".$sub All the 2 status are in required state.");
                  return 1;
               }

               $index++;
            }
         }
      }
   }

   # We are not supposed to reach here.
   $logger->info(__PACKAGE__ . ".$sub Unknown error happened while checking the status");
   return 0;
}

=pod

=head1 getCDR()
    This subroutine is used to get all the cdrs from the latest cdr file. It returns the cdrs as an array. The CDRs returned by this function can be parsed and the individual field values can be retrieved by using the getFieldFromCDRs() interface.

Return Values :
   Returns an array containing the cdrs.

Example :
  my @cdrs = $gsxObj->getCDR();

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub getCDR() {

    my ($self)=@_;
    my ($conn1,$logfullpath,$cmd1,$csv,@acctrecord,@cmdResults);
    my $sub = "getCDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    @{$self->{CDRS}} = ();

    # Connect to the NFS server
    $conn1 = $self->connectToNFS();
    if ($conn1 == 0) {
        $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS Server");
        return @acctrecord;
    }

    # Get the name of the latest log file
    $logfullpath = $self->getCurLogPath("ACT");

    # Get the contents of the cdr file
    $cmd1 = "cat " . $logfullpath;

    unless (@cmdResults = $self->{nfs_session}->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
        $logger->error(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{nfs_session}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{nfs_session}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{nfs_session}->{sessionLog2}");
        return @acctrecord;
    }

    chomp(@cmdResults);

    foreach(@cmdResults) {
        # Return only the CDRs and ignore the other lines in the file
        if ( $_ =~ m/START|STOP|ATTEMPT|INTERMEDIATE/i ) {
            push @acctrecord, $_;
        }
    }

    push(@{$self->{CDRS}},@acctrecord);
    return @acctrecord;

}

=pod

=head1 getFieldFromCDRs()
    This subroutine is used to return the value of the specified field in the specified call detail record of the specified type. This interface simply parses the CDR file contents returned by the getCDR function. Hence getCDR function should be called before this function.

PRE-REQUISITE :
    getCDR function should be called before this interface. This subroutine simply parses the cdrs. The actual cdr file contents are read by the getCDR function and hence NEEDS to be called before this function without which this function will not work.

Arguments :

    1. Type of CDR - Should be one of START/STOP/INTERMEDIATE/ATTEMPT.
    2. Record Number - Call detail record number whose field value is to be returned.
    3. Field Number - Field in the CDR whose value is to be returned.

Return Values :
   Returns the value of the cdr field given the CDR type, record number and the field number.

Example :
  $gsxObj->getCDR(); - This will read the contents of the latest cdr file.
  $gsxObj->getFieldFromCDRs("START",1,7); - This will return the 7th field in the first START record.
  $gsxObj->getFieldFromCDRs("ATTEMPT",2,5); - This will return the 5th field in the second ATTEMPT record.

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub getFieldFromCDRs() {

    my ($self,$cdrType,$recordNumber,$fieldnumber) = @_;
    my ($csv,$acctsubrecord,@acctsubrecord,$subrecord,$count,$arraylen,@acctrecord);
    my $sub = "getFieldFromCDRs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    if (!defined $self->{CDRS}) {
        $logger->error(__PACKAGE__ . ".$sub Call getCDR function before this function is called!");
        return "UNABLE TO GET VALUE OF CDR";
    }

    $count = 1;
    $csv = Text::CSV->new();
    foreach (@{$self->{CDRS}}) {
        if ( $_ =~ m/$cdrType/i ) {
            if ($count == $recordNumber) {
                if ($fieldnumber =~ m/(\w+)\.(\w+)/) {
		    $csv->parse($_);
		    @acctrecord = $csv->fields;
		    $acctsubrecord = $acctrecord[$1-1];
                    $csv->parse($acctsubrecord);
                    @acctsubrecord = $csv->fields;
                    $arraylen = @acctsubrecord;
                    if ($2 > $arraylen) { # looking for array out-of-bounds situation
                        $logger->warn(__PACKAGE__ . ".$sub SUBFIELD DOES NOT EXIST IN ACT LOG");
                        return "ERROR - SUBFIELD DOES NOT EXIST";
                    } else {
                        $logger->debug(__PACKAGE__ . ".$sub Value of SUBFIELD $2 of FIELD $1 of RECORD $recordNumber of TYPE $cdrType = $acctsubrecord[$2-1]");
                        return $acctsubrecord[$2-1];
                    }
                } else {
                    $csv = Text::CSV->new();
                    $csv->parse($_);
                    @acctrecord = $csv->fields;
                    $arraylen = @acctrecord;
                    if ($fieldnumber > $arraylen) {
                        $logger->warn(__PACKAGE__ . ".$sub FIELD DOES NOT EXIST IN ACT LOG");
                        return "ERROR - FIELD DOES NOT EXIST";
                    } else {
                        $logger->debug(__PACKAGE__ . ".$sub Value of FIELD $fieldnumber of RECORD $recordNumber of TYPE $cdrType = $acctrecord[$fieldnumber-1]");
                        return $acctrecord[$fieldnumber-1];
                    }
                }
            } else {
                $count ++;
            }
        }
    }
    return "UNABLE TO GET VALUE OF CDR"; 
}

=pod

=head1 getNodeNameAndNFSDetails()
    This subroutine is used to return the value of Node Name and NFS server ip address and the mount path on the NFS server.

Return Values :
   Returns the value of Node Name, NFS server IP address and the mount path on the NFS server.

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut

sub getNodeNameAndNFSDetails() {

  my ($self) = @_;
  my ($ip,$mountpoint,$cmd,@cmdresults,$activenfs,$nodename);
  my $sub = "getNodeNameAndNFSDetails";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  # Get node name
  $cmd = "SHOW NFS SHELF 1 ADMIN"; # Get the node name from the "load path" rather than node name from "show node admin" because Load path and Node name could be different in certain situations and what we actually need here is the former.
  @cmdresults = $self->execCmd($cmd);
  foreach (@cmdresults) {
    if ( m/Load Path:\s+(\w+)/ ){
      $nodename = $1;
      $nodename =~ tr/[a-z]/[A-Z]/;
    }
  }

  # Get IP address and path of active NFS
  $cmd = "show nfs shelf 1 slot 1 status";
  @cmdresults = $self->execCmd($cmd);
  foreach (@cmdresults) {
    if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
      $activenfs = $1;
    }
    if (defined $activenfs) {
      if(m|($activenfs).*\s+(\d+.\d+.\d+.\d+)\s+(\S+)|i) {
        $ip = $2;
        $mountpoint = $3;
        last;
      }
    }
  }

  # On GSX version V08.02.00 A021, the output of "show nfs shelf 1 slot 1 status" is different
  my $i = 0;
  if (! defined $ip) {
    for ($i = 0; $i < $#cmdresults; $i++) {
      if( $cmdresults[$i] =~ (m/($activenfs).*\s+(\d+\.\d+\.\d+\.\d+)\s*$/i) ) {
        $ip = $2;
        $mountpoint = $cmdresults[$i+1];
        $mountpoint =~ s/\s+//g;
        last;
      }
    }
  }    

  $logger->info(__PACKAGE__ . ".$sub NodeName=$nodename ; Active NFS=$activenfs ; NFS IP=$ip ; NFS Mount Point=$mountpoint");
  return ($nodename,$ip,$mountpoint);

}

=pod

=head1 findTimeDiffBetPattInDBGLog()
    This subroutine is used to find the time difference in seconds between the last occurrence of two patterns found in GSX DBG log.

Arguments :

    1. Pattern1 - first pattern to be searched for.
    2. Pattern2 - second pattern to be searched for.

Return Values :
   Returns the time difference in seconds between the last occurrence of two patterns found in GSX DBG log.
   Returns -1 in case of error.

Example :
  $gsxObj->findTimeDiffBetPattInDBGLog("msg = INVITE","msg = BYE");

Author :
Sowmya Jayaraman (sjayaraman@sonusnet.com)

=cut


sub findTimeDiffBetPattInDBGLog() {

    my ($self,$patt1,$patt2)=@_;
    my (%retHash,$conn1,$tmp1,$tmp2,$logfullpath,@cmdResults,$date1,$date2,$time1,$time2,@d1,@d2,$cmd1,$mon1,$timeDiff);
    my $sub = "findTimeDiffBetPattInDBGLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Connect to the NFS server
    $conn1 = $self->connectToNFS();
    if ($conn1 == 0) {
        $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS Server");
        return -1;
    }

    $logfullpath = $self->getCurLogPath("DBG");

    # Find the last occurrence of the first pattern in the log file
    $cmd1 = "grep \"$patt1\" $logfullpath | tail -1f";

    unless (@cmdResults = $self->{nfs_session}->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
        $logger->error(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{nfs_session}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{nfs_session}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{nfs_session}->{sessionLog2}");
        return -1;
    }

    chomp(@cmdResults);
    $tmp1 = $cmdResults[0];
    if ($tmp1 =~ m/\S+\s+(\d+)\s+(\d+)\.(\d+)\:.*/ ) {
        $date1 = $1;
        $time1 = $2;
        # Split time into hours,minutes and seconds
        if ($time1 =~ m/(\d{2})(\d{2})(\d{2})/) {
            push @d1,($3,$2,$1);
        } else {
            $logger->error(__PACKAGE__ . ".$sub Unable to decode time for the pattern $patt1");
            return -1;
        }
        if ($date1 =~ m/(\d{2})(\d{2})(\d{4})/) {
            # Deduct month by 1 since the months start with 0 for localtime
            $mon1 = $1-1;
            push @d1,($2,$mon1,$3);
        } else {
            $logger->error(__PACKAGE__ . ".$sub Unable to decode month date and year for the pattern $patt1");
            return -1;
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub Unable to find time stamp for pattern $patt1 in DBG log");
        return -1;
    }

    # Find the last occurrence of the second pattern in the log file
    $cmd1 = "grep \"$patt2\" $logfullpath | tail -1f";

    unless (@cmdResults = $self->{nfs_session}->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
        $logger->error(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
        $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{nfs_session}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{nfs_session}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{nfs_session}->{sessionLog2}");
        return -1;
    }

    chomp(@cmdResults);
    $tmp1 = $cmdResults[0];
    if ($tmp1 =~ m/\S+\s+(\d+)\s+(\d+)\.(\d+)\:.*/ ) {
        $date2 = $1;
        $time2 = $2;
        # Split time into hours,minutes and seconds
        if ($time2 =~ m/(\d{2})(\d{2})(\d{2})/) {
            push @d2,($3,$2,$1);
        } else {
            $logger->error(__PACKAGE__ . ".$sub Unable to decode time for the pattern $patt2");
            return -1;
        }
        if ($date2 =~ m/(\d{2})(\d{2})(\d{4})/) {
            # Deduct month by 1 since the months start with 0 for localtime
            $mon1 = $1-1;
            push @d2,($2,$mon1,$3);
        } else {
            $logger->error(__PACKAGE__ . ".$sub Unable to decode month date and year for the pattern $patt2");
            return -1;
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub Unable to find time stamp for pattern $patt2 in DBG log");
        return -1;
    }

    # Convert the time into epoch time
    $tmp1 = timelocal($d1[0],$d1[1],$d1[2],$d1[3],$d1[4],$d1[5]);
    $tmp2 = timelocal($d2[0],$d2[1],$d2[2],$d2[3],$d2[4],$d2[5]);

    $timeDiff = $tmp2-$tmp1;
    $logger->debug(__PACKAGE__ . ".$sub Date for pattern1 = $date1 ; pattern2 = $date2 ; Time for pattern1 = $time1 ; pattern2 = $time2");
    $logger->debug(__PACKAGE__ . ".$sub Epoch Time for pattern1 = $tmp1 ; Epoch Time for pattern2 - $tmp2");
    $logger->debug(__PACKAGE__ . ".$sub Time difference = $timeDiff");

    if ($timeDiff < 0) {
        $logger->debug(__PACKAGE__ . ".$sub Pattern $patt2 occured ".abs($timeDiff)." seconds after $patt1"); 
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Pattern $patt1 occured $timeDiff seconds after $patt2"); 
    }

    return abs($timeDiff);
}

        
=pod

=head1 searchDBGLogInAGivenNfs()

    This is same as  searchDBGlog() subroutine. This subroutine to be used when the NFS is not
    mounted in the system(GSX) being test. It will take NFS details like node name, IP and
    mount path from TMS.

Arguments :

Return Values :

   0      - if file is not copied
   \%hash - On success returns referance to hash containing 'pattern' as key and number of occurrences as member

Example :
   my @pattern = ("msg","msg =","abc");
   my $hashRef = $gsxobj->searchDBGLogInAGivenNfs(\@pattern);

Author :

Shashidhar Hayyal (shayyal@sonusnet.com)

=cut


sub searchDBGLogInAGivenNfs {
    my ($self, $refToArray) = @_;
    my %returnHash;
    my $sub = "searchDBGLogInAGivenNfs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".searchDBGLogInAGivenNfs");

    my @arrayContainingPattern = @{$refToArray};

    #Get NFS details from TMS
    my $nodeName     = $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'NAME'};
    my $nfsIPAddress = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    my $nfsUserID    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
    my $nfsPasswd    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
    my $nfsMountPath = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};

    $logger->debug("$sub : ***********************************************");
    $logger->debug("$sub : * NODE NAME   : $nodeName");
    $logger->debug("$sub : * NFS IP      : $nfsIPAddress");
    $logger->debug("$sub : * User ID     : $nfsUserID");
    $logger->debug("$sub : * Password    : TMS_ALIAS->NFS->1->PASSWD");
    $logger->debug("$sub : * MOUNT POINT : $nfsMountPath");
    $logger->debug("$sub : ***********************************************");

    unless ($nfsIPAddress) {
        $logger->error("$sub : NFS IP address must be defined in TMS");
        return 0;
    }
    unless ($nfsUserID) {
        $logger->error("$sub : NFS user ID must be defined in TMS");
        return 0;
    }
    unless ($nfsPasswd) {
        $logger->error("$sub : NFS password must be defined in TMS");
        return 0;
    }
    unless ($nfsMountPath) {
        $logger->error("$sub : NFS base path must be defined in TMS");
        return 0;
    }

    #Get the chassis serial number
    my $cmd = "show chassis status";
    $logger->debug("$sub : Executing command --> $cmd");

    my @cmdResults = $self->execCmd($cmd);

    $logger->debug("$sub : ------------------ COMMAND OUTPUT -----------------------");
    foreach (@cmdResults) {
        $logger->debug("$sub : $_");
    }
    $logger->debug("$sub : -------------- COMMAND OUTPUT ENDS ----------------------");

    my $serialNumber;
    foreach(@cmdResults) {
       if(m/Serial Number:\s+(\d+)/) {
          $serialNumber = $1;
          $logger->debug("$sub : Chassis Serial Number => $serialNumber ");
       }
    }

    unless ($serialNumber) {
        $logger->error("$sub : Unable to get chassis serial number from GSX");
        return 0;
    }

    #Check NFS path
    if (($nfsMountPath =~ m/SonusNFS/) || ($nfsMountPath =~ m/SonusNFS2/)) {
        $logger->debug("$sub : Got the NFS mount point --> $nfsMountPath");
    } else {
        $logger->error("$sub : NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2");
        return 0;
    }

    #Determine name of active DBG log
    my $dbgLogName;
    $cmd = "show event log all status";
    $logger->debug("$sub : Executing command --> $cmd");

    @cmdResults = $self->execCmd($cmd);
    $logger->debug("$sub : ------------------ COMMAND OUTPUT -----------------------");
    foreach (@cmdResults) {
        $logger->debug("$sub : $_");
    }
    $logger->debug("$sub : -------------- COMMAND OUTPUT ENDS ----------------------");

    foreach (@cmdResults) {
        if (m/(\w+)\.DBG/) {
            $dbgLogName = "$1";
            last;
        }
    }

    unless ($dbgLogName) {
        $logger->error("$sub : DEBUG logs are not activated in GSX");
        return 0;
    }

    #Create connection to NFS
    my $nfsObj = SonusQA::DSI->new(-OBJ_HOST     => $nfsIPAddress,
                                   -OBJ_USER     => $nfsUserID,
                                   -OBJ_PASSWORD => $nfsPasswd,
                                   -OBJ_COMMTYPE => "SSH");

    unless ($nfsObj) {
        $logger->error("$sub : Unable to connect to server --> $nfsIPAddress");
        return 0;
    }

    $logger->debug("$sub : Successfully connected to server --> $nfsIPAddress");

    #Now construct DBG log path
    my $dbgLogFile = "$nfsMountPath" ."/" . "/evlog/" . "$serialNumber" . "/DBG/" . "$dbgLogName" . "\.DBG";
    $logger->debug("$sub : DBG log full path  --> $dbgLogFile");

    #Do a grep on DBG log file for given patterns
    foreach my $pattern (@arrayContainingPattern){
        my @cmdResults;
        my $count;

        my $cmd = 'grep -c "' . $pattern . '" ' . $dbgLogFile ;

        unless (@cmdResults = $nfsObj->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT} )) {
            $logger->error("$sub : execCmd  COMMAND EXECUTION ERROR OCCURRED");
	    $logger->debug(__PACKAGE__ . ".$sub : errmsg: " . $nfsObj->{conn}->errmsg);
    	    $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $nfsObj->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $nfsObj->{sessionLog2}");
            return 0;
        }

        $count = $cmdResults[0];
        $count =~ s/^\s+//;
        $count =~ s/\s+$//;

        unless ($count =~ /^[0-9]+$/) {
            $logger->error("$sub : Unable to get the number of occurrences of the pattern");
            $logger->error("$sub : Error Message: $count");
            return 0;
        }

        unless($count){
            $logger->error("$sub :  No occurrence of \"$pattern\" in $dbgLogFile");
            return 0;
        }

        $logger->debug("$sub : Number of occurrences of the pattern  \"$pattern\" in $dbgLogFile is $count");

        $returnHash{$pattern} = $count;
    }

    return \%returnHash;

}

=pod

=head1 searchLogInAGivenNfs()

    This is same as searchTRClog() subroutine. This subroutine to be used when the NFS is not
    mounted in the system(GSX) being test. It will take NFS details like node name, IP and
    mount path from TMS.

Arguments :

Return Values :

   0      - if file is not copied
   \%hash - On success returns referance to hash containing 'pattern' as key and number of occurrences as member

Example :
   my @pattern = ("msg","msg =","abc");
   my $hashRef = $gsxobj->searchLogInAGivenNfs(\@pattern);

Author :

Shashidhar Hayyal (shayyal@sonusnet.com)

=cut

sub searchLogInAGivenNfs {
    my ($self, $logType, $refToArray) = @_;
    my %returnHash;
    my $sub = "searchLogInAGivenNfs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my @arrayContainingPattern = @{$refToArray};

    #Get NFS details from TMS
    my $nodeName     = $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'NAME'};
    my $nfsIPAddress = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    my $nfsUserID    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
    my $nfsPasswd    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
    my $nfsMountPath = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};

    $logger->debug("$sub : ***********************************************");
    $logger->debug("$sub : * NODE NAME   : $nodeName");
    $logger->debug("$sub : * NFS IP      : $nfsIPAddress");
    $logger->debug("$sub : * User ID     : $nfsUserID");
    $logger->debug("$sub : * Password    : $nfsPasswd");
    $logger->debug("$sub : * MOUNT POINT : $nfsMountPath");
    $logger->debug("$sub : * Log Type    : $logType");
    $logger->debug("$sub : ***********************************************");

    unless ($nfsIPAddress) {
        $logger->error("$sub : NFS IP address must be defined in TMS");
        return 0;
    }
    unless ($nfsUserID) {
        $logger->error("$sub : NFS user ID must be defined in TMS");
        return 0;
    }
    unless ($nfsPasswd) {
        $logger->error("$sub : NFS password must be defined in TMS");
        return 0;
    }
    unless ($nfsMountPath) {
        $logger->error("$sub : NFS base path must be defined in TMS");
        return 0;
    }
    unless ($logType) {
        $logger->error("$sub : Log Type must be defined");
        return 0;
    }

    #Get the chassis serial number
    my $cmd = "show chassis status";
    $logger->debug("$sub : Executing command --> $cmd");

    my @cmdResults = $self->execCmd($cmd);

    $logger->debug("$sub : ------------------ COMMAND OUTPUT -----------------------");
    foreach (@cmdResults) {
        $logger->debug("$sub : $_");
    }
    $logger->debug("$sub : -------------- COMMAND OUTPUT ENDS ----------------------");

    my $serialNumber;
    foreach(@cmdResults) {
       if(m/Serial Number:\s+(\d+)/) {
          $serialNumber = $1;
          $logger->debug("$sub : Chassis Serial Number => $serialNumber ");
       }
    }

    unless ($serialNumber) {
        $logger->error("$sub : Unable to get chassis serial number from GSX");
        return 0;
    }

    #Check NFS path
    if (($nfsMountPath =~ m/SonusNFS/) || ($nfsMountPath =~ m/SonusNFS2/)) {
        $logger->debug("$sub : Got the NFS mount point --> $nfsMountPath");
    } else {
        $logger->error("$sub : NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2");
        return 0;
    }

    #Determine name of active DBG log
    my $logName;
    $cmd = "show event log all status";
    $logger->debug("$sub : Executing command --> $cmd");

    @cmdResults = $self->execCmd($cmd);
    $logger->debug("$sub : ------------------ COMMAND OUTPUT -----------------------");
    foreach (@cmdResults) {
        $logger->debug("$sub : $_");
    }
    $logger->debug("$sub : -------------- COMMAND OUTPUT ENDS ----------------------");

    foreach (@cmdResults) {
        if (m/(\w+)\.$logType/) {
            $logName = "$1";
            last;
        }
    }

    unless ($logName) {
        $logger->error("$sub : $logType logs are not activated in GSX");
        return 0;
    }

    #Create connection to NFS
    my $nfsObj = SonusQA::DSI->new(-OBJ_HOST     => $nfsIPAddress,
                                   -OBJ_USER     => $nfsUserID,
                                   -OBJ_PASSWORD => $nfsPasswd,
                                   -OBJ_COMMTYPE => "SSH");

    unless ($nfsObj) {
        $logger->error("$sub : Unable to connect to server --> $nfsIPAddress");
        return 0;
    }

    $logger->debug("$sub : Successfully connected to server --> $nfsIPAddress");

    #Now construct log path
    my $logFile = "$nfsMountPath" ."/" . "/evlog/" . "$serialNumber" . "/" . "$logType" . "/" . "$logName" . "\." . "$logType";
    $logger->debug("$sub : $logType log full path  --> $logFile");

    #Do a grep on log file for given patterns
    foreach my $pattern (@arrayContainingPattern){
        my @cmdResults;
        my $count;

        my $cmd = 'grep -c "' . $pattern . '" ' . $logFile ;

        unless (@cmdResults = $nfsObj->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT} )) {
            $logger->error("$sub : execCmd  COMMAND EXECUTION ERROR OCCURRED");
            $logger->debug(__PACKAGE__ . ".$sub : errmsg: " . $nfsObj->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub : Session Dump Log is : $nfsObj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub : Session Input Log is: $nfsObj->{sessionLog2}");
            return 0;
        }

        $count = $cmdResults[0];
        $count =~ s/^\s+//;
        $count =~ s/\s+$//;

        unless ($count =~ /^[0-9]+$/) {
            $logger->error("$sub : Unable to get the number of occurrences of the pattern");
            $logger->error("$sub : Error Message: $count");
            return 0;
        }

        unless($count){
            $logger->error("$sub :  No occurrence of \"$pattern\" in $logFile");
            $returnHash{$pattern} = 0;
        }

        $logger->debug("$sub : Number of occurrences of the pattern  \"$pattern\" in $logFile is $count");

        $returnHash{$pattern} = $count;
    }

    return \%returnHash;

}

=head1 B< verifyMultipleCDR >

=over

=item DESCRIPTION:

    This subroutine actually uses the camDecoder.pl file (maintained in the library in the same path of GSXHELPER.pm) to decode the ACT file and does CDR matching with the output decode file. This API matches both the Fields and Sub-Fields in the record. This API also works for verifying multiple records.

=item Note:

 1. Please do 'svn up camDecoder.pl' in the same path where GSXHELPER.pl is stored.
 2. The camDecoder.pl file has to be checked in here each time a Clearcase build results in a new version of this file.

=item ARGUMENTS:

    Optional:

      1. %cdrHash (cdr record hash with index and its corresponding value)
      eg : 
      %cdrHash = ( START => {0 =>
                           { 6 => "orgCgN=3042010001", 
                             7 => "dldNum=3042010004" }
                            },
             STOP  => {0 =>
                           { 6 => "orgCgN=3042010001" }  
                           } );

=item PACKAGE:

    SonusQA::GSX::GSXHELPER;

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)

=item EXAMPLES:

my %cdrHash = ( 'START' => {'1' =>
                             { '6' => 'orgCgN=3042010001', 
                               '7' => 'dldNum=3042010004' }
                             },
                'STOP'  => {'1' =>
                             { '6' => 'orgCgN=3042010001' }  
                             } );

 $GSXObj->verifyMultipleCDR ( %cdrHash );

=item AUTHOR:

 Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut


sub verifyMultipleCDR {
    my ($self, %cdrref) = @_ ;
    my $sub_name = "verifyMultipleCDR()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name  Entered with args - ", Dumper(%cdrref));

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
   
    my $user_home = qx#echo ~#;
    chomp($user_home); 
    my $logDetails = $self->getGsxLogDetails(-logType => 'ACT');
    unless ($logDetails) {
        $logger->info(__PACKAGE__ . ".$sub_name: Unable to get details for GSX ACT log");
        return 0;
    }

    my %logDetails = %{$logDetails};
    $logger->info(__PACKAGE__ . ".$sub_name: \nNFS-IP: $logDetails{-nfsIp} \nLOG-PATH: $logDetails{-logPath} \nLOG-FILES: @{$logDetails{-fileNames}} \nREMOTE-COPY: $logDetails{-remoteCopy} \nNODE-NAME: $logDetails{-nodeName}");

    #Now get the log path in NFS server
    my ($nfsSessObj, $ACT_file);
    my @fileNameList = @{$logDetails{-fileNames}};
    my $sourcelogpath = $logDetails{-logPath};

#    if ($sourcelogpath =~ m/export/) {
#	$ACT_file = $fileNameList[-1];
#    } else {
        $ACT_file = "$sourcelogpath" . "$fileNameList[-1]";
#    }

    my $nfsipaddress = $logDetails{-nfsIp};
    
    my $destDir = "$user_home" . "/ats_repos/lib/perl/SonusQA/GSX/";
    my $destfile = $destDir . 'ACTFILE.ACT';

    if ($logDetails{-remoteCopy}) {

	#Now get the NFS server IP
	my %scpArgs;
	$scpArgs{-hostip} = $nfsipaddress;
	$scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
	$scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
	$scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$ACT_file;	
	$scpArgs{-destinationFilePath} = $destfile;
	unless(&SonusQA::Base::secureCopy(%scpArgs)) {
                $logger->error(__PACKAGE__ . ".$sub_name:  SCP actfile to local server Failed");
                $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
                return 0;
        }
	$logger->info(__PACKAGE__ . ".$sub_name:  SCP actfile to local server is success");
    }else{
        my $status = `cp $ACT_file $destfile`;
    }  
     
    my @result2 = `ls -lrt $destfile`;

    foreach (@result2){
        if($_ =~ /No such file or directory/i){
            $logger->error(__PACKAGE__ . ".$sub_name: File ($ACT_file) not transferred ");
            return 0;
        }else{
            $logger->info(__PACKAGE__ . ".$sub_name: File successfully transferred!!");
        }
    }

    my $decode_file = "$destDir" . "camDecoder.pl";
    $decode_file =~ s/\/GSX\//\/SBX5000\//;
    my $temp_file = "$destDir" . "temp.txt";

    my $cmd1 = `perl $decode_file $destfile  > $temp_file`;
    my @result1 = `ls -lrt $temp_file`;
    my @cdr_record;

    foreach (@result1) {
        if($_ =~ /No such file or directory/i){
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($temp_file) not found ");
            return 0;
        }else{
            $logger->debug(__PACKAGE__ . ".$sub_name: File ($temp_file) found!!");
        }
    }

    #reading the temp act file
    unless( @cdr_record = `cat $temp_file` ){
        $logger->debug(__PACKAGE__ . ".$sub_name: cannot read the File($temp_file)");
        return 0;
    }

    #verifying the record index in the temporary camdecoder output file
    my $flag1 = 1;  #sets the return value 
    my $flag = 0;   #indicates the record match 
    my $recordcount = 0;
    my ($index, $recordtype, $value, $index1);
    my $Field_identified = 0;
    foreach $recordtype (keys %cdrref) {
        $flag = 0 if ($flag);
        $recordcount = 0 if ($recordcount);
        foreach $index ( keys %{$cdrref{$recordtype}} ) {
            $index1 = $index + 1;
            foreach (@cdr_record) {
                $value = $_;
                chomp ($value);
                if ($_ =~ /^Record\s*\d*\s*'($recordtype)'$/) {
                    $recordcount += 1;
                    if ($recordcount eq $index1) {
                        $flag = 1;
                        $logger->info(__PACKAGE__ . ".$sub_name: Matched record -> $1 and newindex -> $index1");
                    }else{
                        $flag = 0;
                    }
                }elsif ($_ =~ /^Record\s*\d*\s*'(.*)'$/) {
                    $flag = 0 if ($1 ne $recordtype);
                }

                if ($flag) {
                    foreach my $input_key ( keys %{$cdrref{$recordtype}{$index}} ) {
                        my $input_key1 = ($input_key =~ /\./) ? $input_key : $input_key . '.';
                        if ($value =~ /^\s*($input_key1)\s+(.*):\s+(.*)$/i) {
                            my @array = split (' ', $value);
                            my $temp1 = $array[0];
                            my $temp2 = $3;
                            if ( $cdrref{$recordtype}{$index}{$input_key} eq $temp2) {
                                $logger->info(__PACKAGE__ . ".$sub_name: Matched CDR expected for $array[0] Field : $cdrref{$recordtype}{$index}{$input_key} CDR Actual : $temp2 " );
                                $Field_identified += 1;
                            }else{
                                $logger->debug(__PACKAGE__ . ".$sub_name: Did not Match CDR expected for $array[0] Field : $cdrref{$recordtype}{$index}{$input_key} CDR Actual : $temp2 " );
                                $flag1 = 0;
                                $Field_identified += 1;
                            }
                        }
                    }
                }
            }
        }
    }
    my $cmd2 = `rm -rf $destfile $temp_file`;

    my $Field_Input = 0;
    my ($recordType2, $index2, $input_key1);

    foreach $recordType2 ( keys (%cdrref) ) {
        foreach $index2 ( keys %{$cdrref{$recordType2}} ) {
            foreach $input_key1 ( keys %{$cdrref{$recordType2}{$index2}} ) {
                $Field_Input += 1;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: input Fields -> $Field_Input and  Fields Identified -> $Field_identified");
    if ($Field_identified != $Field_Input) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Some Fields are missing from the record!");
        $logger->info(__PACKAGE__ . ".$sub_name: Leaving Sub[0]");
        return 0;
    }

    if($flag1){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
}

=head1 B<makeInfoLevelLog>
DESCRIPTION:

    This subroutine execute few commands to make the log level as INFO.

ARGUMENTS:

Optional:

PACKAGE:

    SonusQA::GSX::GSXHELPER;

GLOBAL VARIABLES USED:

    None

OUTPUT:

    0   - fail (failed to execute any one command)
    1   - success (if all the commands are successfully executed)
EXAMPLES:
        $gsx_obj->makeInfoLevelLog();
=cut

sub makeInfoLevelLog {
    my $self = shift;
    my $sub = "makeInfoLevelLog()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . ".$sub Entered sub");

    my @cmds =('CONFIGURE EVENT LOG ALL LEVEL INFO',
               'admin debugSonus',
               'ds diameter en',
               'sipfesetprintpdu on',
               'h323 sgdebug 0xff7e7bf5',
               'debugindicator 1');
    foreach(@cmds)
    {
	$self->execCmd($_);	
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head1 B<windUp>
DESCRIPTION:

    This is a wrapper function to do the following things,
           1. check the coredump and if coredump occurred SYS logs will be copied to new location then set the return flag to 0.
           2. call validateLogs() to check the SYS ERRORS, MEMORY LEAKS or MEMORY CORRUPTION in DBG and SYS logs then set the return flag to 0.

ARGUMENTS:

Optional:
        -coreCheck => Flag ,decides whether to proceed corecheck or not
PACKAGE:

    SonusQA::GSX::GSXHELPER;

GLOBAL VARIABLES USED:

    None

OUTPUT:

    0   - fail (if coredump occurred/validateLogs() failed)
    1   - success (No coredump and validateLogs() passed)
EXAMPLES:
        $gsx_obj->windUp();
        $gsx_obj->windUp(-coreCheck => 1);
=cut

sub windUp{
    my $self = shift;
    my %args = @_;
    my $flag = 1;
    my $core;
    my $sub = "windUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
    $logger->debug(__PACKAGE__ . ".$sub Entered sub");
    if ($args{-coreCheck} == 1) {
        sleep(20);                    # GSx takes time to create a core file, hence waiting
        $core = $self->checkCore(-testCaseID => $args{-tcaseid});
        if($core == -1) {
            $logger->warn(__PACKAGE__.".$sub Unable to determine if CORE file has been generated or not");
        }
        elsif ($core == 0 ) {
            $logger->info(__PACKAGE__.".$sub NO CORE FILES were generated by Test Case $args{-tcaseid}");
        }else{
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
    	    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

            # Copy SYS log file
            my $syslogFile = $self->getCurLogPath("SYS");
            if($syslogFile){
	        if (!defined ($self->{nfs_session})) {
	            unless ($self->connectToNFS())
	            {
	                $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
	                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	                return 0;
		    }
		}
                my @tmpName = split(/\//, $syslogFile);
                $tmpName[-1] = "core_".$args{-tcaseid}.$args{-filename}.$timestamp."_".$tmpName[-1];
                my $newName = join "/",@tmpName;
                unless($self->{nfs_session}->{conn}->cmd("cp $syslogFile $newName")){
                    $logger->error(__PACKAGE__ . ".$sub SYS log copy from \'$syslogFile\' to \'$newName\' Failed");
                }
                $logger->info(__PACKAGE__.".$sub  $core CORE FILE(S) WAS(WERE) FOUND ");
                $logger->info(__PACKAGE__.".$sub SYS file has been copied as $newName");
            }
            $flag = 0;
        }
    }
    unless($self->validateLogs()){
        $logger->error(__PACKAGE__.".$sub Log validation Failed");
        $flag = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return ($flag,$core);

}

=head1 B<waitForSlotUp>
DESCRIPTION:

    This subroutine checks the status of the cored slot and wait for slot to come up till a specified time .

ARGUMENTS:

Optional:
    core_slot -> cored slot number.
    wait_time -> how long to wait if slot is not up.

PACKAGE:

    SonusQA::GSX::GSXHELPER;

GLOBAL VARIABLES USED:

    None

OUTPUT:

    0   - fail (core slot is not in running state)
    1   - success (core slot is in running state)
EXAMPLES:
        $gsx_obj->waitForSlotUp();
        $gsx_obj->waitForSlotUp(-core_slot => '8',-wait_time => 600);
=cut

sub waitForSlotUp{
    my $self = shift;
    my %args = @_;
    my $sub = "waitForSlotUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . ".$sub Entered sub");
    my ($flag,$count) = (0,0);
    unless($args{-wait_time}){
        $logger->info(__PACKAGE__."$sub : Timeout is not Specified,so taking 900s (15 mins)");
        $args{-wait_time} = 900;
    }
    unless($args{-core_slot}){
        $args{-core_slot} = $self->getCoredSlot();
    }
    if ($args{-core_slot} > 0){
        $logger->debug(__PACKAGE__ . ".$sub \'$args{-core_slot}\' is the cored slot");
        $args{-core_slot} =~ s/^0//;
        while($count <= $args{-wait_time}){
            my @cmdResults = $self->execCmd("SHOW SERVER SHELF 1 SLOT $args{-core_slot} STATUS");
            if ( grep /Hardware Type:                      N\/A/,@cmdResults) {
                $logger->warn(__PACKAGE__ . ".$sub The cored slot is not in RUNNING state waiting for 60sec");
                $count += 60;
                sleep 60;
            }else{
                $logger->debug(__PACKAGE__ . ".$sub The cored slot is in RUNNING state");
                $flag = 1;
                last;
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;

}
=head1 B<getCoredSlot>

=over 

=item DESCRIPTION:

    This subroutine find the slot where coredumb is occurred .

=item PACKAGE:

    SonusQA::GSX::GSXHELPER;

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (failed to find the cored slot)
    1   - success (if cored slot is found)
    -1  - Unable to get the cored slot

=item EXAMPLES:

    $gsx_obj->getCoredSlot();

=back

=cut

sub getCoredSlot {
   my ($self) = @_;
   my $sub = "getCoredSlot()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

   $logger->debug(__PACKAGE__ . ".$sub Entered sub");
    if (!defined ($self->{nfs_session})) {
        unless ($self->connectToNFS())
        {
            $logger->error(__PACKAGE__ . ".$sub Unable to connect to NFS");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

   my $GsxSWPath = $self->findGsxSWPath();
   unless($GsxSWPath) {
     $logger->error(__PACKAGE__ . ".$sub Unable to find Software Path from GSX");
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [-1]");
     return -1;
   }

   my $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};

   my $coredir = "$nfsmountpoint/$GsxSWPath/coredump";
   # Remove double slashes if present
   $coredir =~ s|//|/|;

   my @cmdresults = $self->{nfs_session}->{conn}->cmd("ls -l $coredir");

   if ($cmdresults[-1] =~ m/core.\d+.\d+.(\d+).\d+$/) {
        $logger->info(__PACKAGE__ . ".$sub The cored Slot is : $1 ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return $1;
   }else{
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
   }
}

=head1 B<validateLogs>

=over 

=item DESCRIPTION:

    This subroutine validate SYS ERRORS, MEMORY LEAKS or MEMORY CORRUPTION in DBG and SYS logs.

=item PACKAGE:

    SonusQA::GSX::GSXHELPER;

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all are valid)

=item EXAMPLES:

    $gsx_obj->validateLogs();

=back

=cut

sub validateLogs {
    my ($self) = @_;
    my $sub = "validateLogs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);

    $logger->debug(__PACKAGE__ . ".$sub Entered sub");

    my $flag = 1;# Flag to check pass/fail
    my %loghash = ( DBG => ["SipsMemFree: corrupted block","SYS ERR"],SYS => ["SYS ERR"]);
    foreach my $log (keys %loghash){
        my $PATH = $self->getCurLogPath("$log");
        my %rescheck = $self->searchLog($log,$loghash{$log});
        foreach my $pattern (@{$loghash{$log}}){
            unless($rescheck{"$pattern"} ) {
                $logger->info(__PACKAGE__." .$sub \"$pattern\" Not found in $PATH ");
            }else {
                $logger->info(__PACKAGE__." .$sub \"$pattern\" found in $PATH : Count of Matches -> $rescheck{$pattern}");
                $flag = 0;
            }
        }
    }# foreach End

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

=pod

=head1 getLogDir

   This subroutine is used to get the directory path of the current DBG/SYS/TRC/ACT log file.

Arguments :

   Called from getCurLogPath()
   Log type(Should be one of the following - DBG, SYS, TRC or ACT).

Return Values :

   Returns log directory on successfully getting the directory path

=cut

sub getLogDir {
    my ($self)=@_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, $logfullpath);
    my $sub = "getLogDir";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered Sub -->");

    if (!defined ($self->{LogDir})) {
        $logger->debug(__PACKAGE__ . ".$sub: Log directory not defined. Getting the path details");
        # Get node name and NFS details
        ($nodename,$nfsipaddress,$nfsmountpoint) = $self->getNodeNameAndNFSDetails();
        $self->{NFS}->{IP} = $nfsipaddress;
        $self->{NFS}->{NODENAME} = $nodename;
        $self->{NFS}->{MOUNTPOINT} = $nfsmountpoint;
        if (!defined($nodename)) {
          $logger->warn(__PACKAGE__ . ".$sub NODE NAME MUST BE DEFINED");
          return $nodename;
        }

        if (! defined $nfsmountpoint) {
          $logger->warn(__PACKAGE__ . ".$sub Unable to find active NFS!");
          return $logfullpath;
        }

        # Get chassis serial number
        $cmd = "show chassis status";
        @cmdresults = $self->execCmd($cmd);
        foreach(@cmdresults) {
            if(m/Serial Number:\s+(\d+)/) {
                $serialnumber = $1;
                last;
            }
        }

        if ( $nfsmountpoint =~ /^\/vol/i ) {
            my $basePath;
            if ( defined ( $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'} ) ) {
                $basePath = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};
            } else {
                $logger->info(__PACKAGE__ . ".$sub: BASEPATH not defined in TMS");
                return 0;
            }
            if ($basePath =~ /SonusNFS/) {
                $logger->info("Base path mentiond in TMS is --> $basePath");
                $nfsmountpoint = $basePath;
                $logger->info(__PACKAGE__ . ".$sub   NFSMOUNTPOINT : $nfsmountpoint ");
            } else {
                $logger->error("Unable to get base path from TMS");
                $logger->error("Check your TMS entry for BASEPATH");
                return 0;
            }
            $self->{LogDir} = "$nfsmountpoint" . "/evlog/" . "$serialnumber";
        } else {
            $self->{LogDir} = "$nfsmountpoint" ."/" . "$nodename" . "/evlog/" . "$serialnumber";
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$self->{LogDir}]");
    return $self->{LogDir};
}

=pod

=head1 deleteACTLogsfromNFS

    This subroutine is used to delete the ACT logs from the NFS. Fix for TOOLS-12328.

Arguments :

   None

Return Values :

   1 - If ACT files removed
   0 - Failed to remove files

=cut

sub deleteACTLogsfromNFS {
    my ($self)=@_;
    my $sub = "deleteACTLogsfromNFS";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub Entered Sub -->");
    my $nfsUserId = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
    my $nfsPasswd = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};

    my $log_dir = $self->getLogDir();
    $logger->debug(__PACKAGE__ . ".$sub log_dir: $log_dir, NFS->IP: $self->{NFS}->{IP}, user : $nfsUserId, password : $nfsPasswd");

    #Now make SFTP to NFS server
    my $nfsSessObj;
    my $retry = 1;
RETRY:
    eval{
        $nfsSessObj = new Net::SFTP( $self->{NFS}->{IP},
                                 user     => $nfsUserId,
                                 password => $nfsPasswd,
                                 debug    => 1,);
    };
    if ($@){
        $logger->warn("Could not open sftp connection to NFS server --> $self->{NFS}->{IP}, error: $@");
        if($retry){
            $logger->info(__PACKAGE__ . ".$sub retry connect again after 30s");
            sleep 30;
            $retry = 0;
            goto RETRY;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub nfsSessObj created status: ". $nfsSessObj->status);
    unless ($nfsSessObj) {
        $logger->error("Could not open sftp connection to NFS server --> $self->{NFS}->{IP}");
        $logger->info(__PACKAGE__ . ".$sub Leaving sub[0]");
        return 0;
    }
    $logger->info("SFTP connection to NFS server  $self->{NFS}->{IP} is successfull");
    $logger->info(__PACKAGE__ . ".$sub Deleting ACT Logs from NFS");
    my $ref = $nfsSessObj->ls("$log_dir/ACT");
    my @cmdResult = @{$ref};
    foreach(@cmdResult){
        my @result = $nfsSessObj->do_remove("$log_dir/ACT/$_->{filename}") if($_->{filename} =~ /.*\.ACT/i);
        if(grep /No such file or directory/i, @result){
            $logger->debug(__PACKAGE__ . ".$sub Unable to remove the ACT file \'$_->{filename}\'");
        }
    }
    $logger->info(__PACKAGE__ . ".$sub Leaving sub[1]");
    return 1;
}
1;
