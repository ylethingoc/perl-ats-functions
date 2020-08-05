package SonusQA::MGW9000::MGW9000HELPER;

#########################################################################################################

=head1 COPYRIGHT

                              Sonus Networks, Inc.
                         Confidential and Proprietary.

                     Copyright (c) 2010 Sonus Networks
                              All Rights Reserved
Use of copyright notice does not imply publication.
This document contains Confidential Information Trade Secrets, or both which
are the property of Sonus Networks. This document and the information it
contains may not be used disseminated or otherwise disclosed without prior
written consent of Sonus Networks.

=head1 DATE

2010-10-19

=cut

#########################################################################################################

=head1 NAME

    SonusQA::MGW9000::MGW9000HELPER - Perl module for Sonus Networks MGW 9000 interaction

=head1 SYNOPSIS


=head1 REQUIRES

    Perl5.8.6, Log::Log4perl, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

    This module provides an interface for the MGW9000 switch.

=head1 AUTHORS

    See Inline documentation for contributors.

=head2 SUB-ROUTINES

    ICMUsage()
    adminDebugSonus()
    DSPSlotStat()
    PingIP()
    getVersion()
    getProductType()
    cns30ISUPcics()
    cns10ISUPcics()
    getHWInventory()
    getmgmtNIFStatus()
    getTGInventory()
    getICMUsage()
    getCallCounts()
    getDSPStats()
    gatherStats()
    resetNode()
    getNTPTime()
    getUserProfile()
    resetNode2()
    getCDRfield()
    getSYSlog()
    getTRClog()
    getDBGlog()
    getAvailcic()
    chkAvailcic()
    bringupServers()
    getIsupService()
    getIsupPointcode()
    getNIFs()
    getallSlotnum()
    getSlotnum()
    verifySIF()
    getshowheader()
    getconfigvalues()
    getNIFadminvalues()
    getNIFstatusvalues()
    getSIFadminvalues()
    verifyIProutes()
    verifyNIF()
    verifyNIFgroup()
    verifyNIFgroupmem()
    getSlotnummns()
    verifyElement()
    countStableCalls()
    deleteAllCalls()
    getAccountingSummary()
    verifyToleranceRate()
    rollLogFile()
    getAnnouncementSummary()
    modifyNvsparm()
    verifyBwusage()
    getmemusage()
    getcpuusage()
    verifyToneResourceUsage()
    configOverloadProfrate()
    getAnnouncementStatus()
    getElementValue()
    getTGbandwidth()
    getRedgroupinfo()
    getServiceName()
    getRPADSummary()
    getRedungroupName()
    configCNSRedunclients()
    getSlotinfo()
    getInterfaceFromAdapter()
    getAdapterCircuitNr()
    sourceTclFileFromNFS()
    getM3UAGateway()
    checkM3UAGateway()
    getSS7GatewayLink()
    checkSS7GatewayLink()
    getSpecifiedIsupServiceState()
    checkSpecifiedIsupServiceState()
    cnsIsupSgDebugSetMask()
    switchoverSlot()
    checkCicsState()
    getProtectedSlotState()
    logStart()
    logStop()
    coreCheck()
    removeCore()
    getFilteradminvalues()
    getOutputFiltervalues()
    getFilterstatusvalues()
    getSessionsummvalues()
    getMgmtNIFadminvalues()
    getPolicerDRprof()
    getPolicerSysAlarmstatus()
    deleteRedunclients()
    backupConfig()
    trim($)()
    getSS7CicRangesForSrvGrp()
    getSS7CicStatus()
    verifyImageVersion()
    areServerCardsUp()
    getISDNChanRangesForSrvGrp()
    getISDNChannelStatus()
    getConfigFromTG()
    isCleanupOrRebootRequired()
    getProtectedSlot()
    getRedundantSlotState()
    detectSwOverAndRevert()
    waitAllRoutingKeys()
    clearLog()
    getLog()
    nameCurrentFiles()
    hex_inc()
    hexaddone()
    sourceTclFile()
    checkCore()
    getLog2()
    MnsSwitchover()
    getSlotFromPort()
    searchDBGlog()
    AUTOLOAD()

=cut

#########################################################################################################

use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use File::stat;
use File::Basename;
use Text::CSV;
use Time::HiRes qw(gettimeofday tv_interval);

use vars qw( $VERSION );
our $VERSION = "1.0";

use vars qw($self);
our ($DBGfile, $SYSfile, $ACTfile);

#########################################################################################################

#################################################
sub ICMUsage {
#################################################
    my ($self,$mKeyVals) = @_;
    my $subName = 'ICMUsage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my(@cmdResults, $cmd, $flag, $key, $value, $cmdTmp, $slot);

    unless(defined($mKeyVals)){
        $logger->warn(' MANADATORY KEY VALUE PAIRS ARE MISSING.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    unless(defined($mKeyVals->{'slot'})){
        $logger->warn('  MANADATORY KEY [slot] IS MISSING.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $cmd = sprintf("icmusage %s ", $mKeyVals->{'slot'});
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    foreach(@cmdResults) {
        if(m/^error/i){
            $logger->warn("  CMD RESULT: $_");
            $flag = 0;
            next;
        }
    }

    $logger->debug('<-- Leaving Sub [1]');
    return @cmdResults;
}

#########################################################################################################

=head3 $obj->adminDebugSonus({'<key>' => '<value>', ...});

Example:

$obj->adminDebugSonus()

Mandatory Key Value Pairs:
        none

Optional Key Value Pairs:
       none

BASE COMMAND:     icmusage <slot>

=cut

# ROUTINE: adminDebugSonus
# Purpose: OBJECT CLI API COMMAND, GENERIC FUNCTION FOR POSITIVE/NEGATIVE TESTING
#################################################
sub adminDebugSonus {
#################################################
    my ($self) = @_;
    my $subName = 'adminDebugSonus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my(@cmdResults, $cmd, $flag, $key, $value, $cmdTmp, $slot);

    $cmd = 'admin debugSonus';
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    foreach(@cmdResults) {
        if(m/^error/i) {
            $logger->warn(" CMD RESULT: $_");
            $flag = 0;
            next;
        }
    }
    $logger->debug('<-- Leaving Sub');
    return @cmdResults;
}

#########################################################################################################

#################################################
sub DSPSlotStat {
#################################################
    my ( $self, $mKeyVals ) = @_;
    my $subName = 'DSPSlotStat()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my(@cmdResults, $cmd, $flag, $key, $value, $cmdTmp, $slot);

    unless( defined($mKeyVals) ) {
        $logger->warn(' MANADATORY KEY VALUE PAIRS ARE MISSING.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    unless( defined($mKeyVals->{'slot'}) ) {
        $logger->warn(' MANADATORY KEY [slot] IS MISSING.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $cmd = sprintf("dspslotstat slot %s", $mKeyVals->{'slot'});
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd( $cmd );
    foreach( @cmdResults ) {
        if( m/^error/i ) {
            $logger->warn(" CMD RESULT: $_");
            $flag = 0;
            next;
        }
    }

    $logger->debug('<-- Leaving Sub [1]');
    return @cmdResults;
}
#########################################################################################################

#################################################
sub PingIP {
#################################################
    my ( $self, $ip ) = @_;
    my $subName = 'PingIP()';
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my(@cmdResults, $cmd, $flag, $key, $value, $cmdTmp, $IP);

    @cmdResults = ();
    unless( defined($ip) ) {
        $logger->warn(' IP MISSING');
        return @cmdResults;
    }

    $cmd = sprintf("ping -c 4 %s", $ip);
    @cmdResults =  $self->execCmd( $cmd );
    foreach( @cmdResults ) {
        $logger->info(" SUCCESSFULLY pinging: $_");
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

#################################################
sub getVersion {
#################################################
    # Uses puts $VERSION on MGW9000 CLI to determine version of product
    # Typically output: V07.01.00 A014
    # Process will try to determine major, minor, maintenance and build information first,
    my ( $self ) = @_;
    my $subName = 'getVersion()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my( @cmdResults, $cmd );
    $cmd = 'puts $VERSION';
    @cmdResults = $self->execCmd( $cmd );
    foreach(@cmdResults) {
        if(m/.*V(\d+)\.(\d+)\.(\d+)\s+(.*)/i){
            $_ =~ s/\s//g;
            $logger->info(" SUCCESSFULLY RETRIEVED VERSION: $_");
            $self->{VERSION} = $_;
            #$self->{VERSION} = sprintf("V%s.%s.%s%s",$1,$2,$3,$4);
            $self->{VERSION} =~ tr/A-Za-z0-9\. //cd;
        }
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

#################################################
sub getProductType {
#################################################
    my ($self) = @_;
    my $subName = 'getProductType()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my(@cmdResults,$cmd);
    $self->{PRODUCTTYPE} = "UNKNOWN";
    $cmd = 'puts $PRODUCT';
    @cmdResults = $self->execCmd($cmd);
    foreach(@cmdResults) {
    #    if(m/.*GSX(\d+)/i){
        if(m/.*MGW9000(\d+)/i){
            my $type = $_;
            $type =~ tr/A-Z/a-z/;
            $self->{PRODUCTTYPE} = $type;
            $self->{PRODUCTTYPE} =~ tr/A-Za-z0-9//cd;
            $logger->info(" SUCCESSFULLY RETRIEVED PRODUCT TYPE: $self->{PRODUCTTYPE}");
        }
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

#################################################
sub cns30ISUPcics {
#################################################
    my($self,$service, $slot, $cicstart, $portStart, $portEnd) = @_;
    my $subName = 'cns30ISUPcics()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  CREATING CNS30 ISUP CICS');
    my $startcic = $cicstart;
    my $endcic = $startcic + 23;
    for( my $x = $portStart; $x <= $portEnd; $x++ ) {
        $self->execFuncCall(
                    'createIsupCircuitServiceCic',
                    {
                        'sonusIsupsgCircuitServiceName' => $service,
                        'cic' => "$startcic\-$endcic",
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        "sonusIsupsgCircuitPortName" => "T1-1-$slot-1-$x",
                        "sonusIsupsgCircuitChannel" => '1-24',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service'=> $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitDirection'=> 'twoway',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitProfileName' => 'default',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCicState',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitAdminState' => 'enabled',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCicMode',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'mode'=> 'unblock',
                    },
                );

        $startcic++;
        $endcic = $startcic + 23;
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

#################################################
sub cns10ISUPcics {
#################################################
    my($self,$service, $slot, $cicstart, $portStart, $portEnd) = @_;
    my $subName = 'cns10ISUPcics()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' CREATING CNS10 ISUP CICS');
    my $startcic = $cicstart;
    my $endcic = $startcic + 23;
    for( my $x = $portStart; $x <= $portEnd; $x++ ) {
        my $starttrunkmember = $startcic + 1000;
        my $endtrunkmember = $endcic + 1000;
        $self->execFuncCall(
                    'createIsupCircuitServiceCic',
                    {
                        'sonusIsupsgCircuitServiceName' => $service,
                        'cic' => "$startcic\-$endcic",
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        "sonusIsupsgCircuitPortName" => "T1-1-$slot-$x",
                        "sonusIsupsgCircuitChannel" => '1-24',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitTrunkMember' => "$starttrunkmember-$endtrunkmember",
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitDirection' => 'twoway',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCic',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitProfileName' => 'default',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCicState',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'sonusIsupsgCircuitAdminState' => 'enabled',
                    },
                );

        $self->execFuncCall(
                    'configureIsupCircuitServiceCicMode',
                    {
                        'isup circuit service' => $service,
                        'cic' => "$startcic\-$endcic",
                        'mode'=> 'unblock',
                    },
                );

        $startcic++;
        $endcic = $startcic + 23;
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################


#################################################
sub getHWInventory {
#################################################
    my($self, $shelf) = @_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $subName = 'getHWInventory()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving MGW9000 HW inventory');
    if($self->execCmd('show Inventory Shelf 1 Summary', {'inventory shelf' => $shelf})) {
        $bFlag = 1;  # the command executed  - so that is a start
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)/){
                $logger->debug("  Inventory Item: $_");
                $self->{'hw'}->{$1}->{$2}->{'SERVER'} = $3;
                $self->{'hw'}->{$1}->{$2}->{'SERVER-STATE'} = $4;
                $self->{'hw'}->{$1}->{$2}->{'ADAPTOR'} = $5;
                $self->{'hw'}->{$1}->{$2}->{'ADAPTOR-STATE'} = $6;
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$bFlag]");
    return $bFlag;
}
#########################################################################################################

#################################################
sub getmgmtNIFStatus {
#################################################
    my($self, $shelf) = @_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $subName = 'getmgmtNIFStatus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving MGW9000 MGMT NIF Status');
    if($self->execFuncCall('showMgmtNifShelfStatus',{'mgmt nif shelf'=>$shelf})) {
        $bFlag = 1;  # the command executed  - so that is a start
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)/){
                $logger->debug("$_");
                $self->{'hw'}->{$1}->{$2}->{'SHELF'} = $3;
                $self->{'hw'}->{$1}->{$2}->{'SLOT'} = $4;
                $self->{'hw'}->{$1}->{$2}->{'PORT'} = $5;
                $self->{'hw'}->{$1}->{$2}->{'INDEX'} = $6;
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$bFlag]");
    return $bFlag;
}
#########################################################################################################

#################################################
sub getTGInventory {
#################################################
    my($self, $shelf) = @_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $subName = 'getTGInventory()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving MGW9000 Trunk Group inventory');
    if($self->execFuncCall('showTrunkGroupAllStatus')) {
      foreach(@{$self->{CMDRESULTS}}){
          if(m/^(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)/){
              $logger->debug(" Inventory Item: $_");
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
    $logger->debug("<-- Leaving Sub [$bFlag]");
    return $bFlag;
}

#########################################################################################################

#################################################
sub getICMUsage {
#################################################
    my($self) = @_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    my $subName = 'getICMUsage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving ICM usage for all known slots');
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
    $logger->debug('<-- Leaving Sub');
}


#########################################################################################################

#################################################
sub getCallCounts {
#################################################
    my($self) = @_;
    my(@results,$inventory);
    my $subName = 'getCallCounts()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    $logger->info(' Retrieving Call Counts');
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
    $logger->debug('<-- Leaving Sub');
}


#########################################################################################################

#################################################
sub getDSPStats {
#################################################
    my($self) = @_;
    my(@results,$inventory);
    my $subName = 'getDSPStats()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    # ::FIX:: A check for size or something to verify $self->{'hw'}->{'1'}... are populated
    $logger->debug(' Retrieving DSP Statistics for all known slots');
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
    $logger->debug('<-- Leaving Sub');
}

# Only call this method when all functionality exists:  getDSPStats does not work in MGW9000 5.1.x.
#########################################################################################################

#################################################
sub gatherStats {
#################################################
    my($self) = @_;
    my $subName = 'gatherStats()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    if($self->can("getICMUsage")){
        $self->getICMUsage();
    }
    if($self->can("getCallCounts")){
        $self->getCallCounts();
    }
    if($self->can("getDSPStats")){
        $self->getDSPStats();
    }

    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

#################################################
sub resetNode {
#################################################
    my($self) = @_;
    my $subName = 'resetNode()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' CHECKING OBJECT RESET FLAG');
    if($self->{RESET_NODE}){
        $logger->info(' CHECKING OBJECT RESET FLAG');
        $logger->info(' RESET FLAG IS TRUE.  RESET NODE');
        $self->{conn}->cmd('set NO_CONFIRM 0');
        $self->{conn}->cmd('set NO_CONFIRM 1');
        $logger->info('  CHECKING NVSDISABLED FLAG');

        if(defined($self->{NVSDISABLED}) && $self->{NVSDISABLED}){
            $logger->info(' NVSDISABLED IS TRUE.  ATTEMPTING TO DISABLE PARAMETER MODE');
            $self->execFuncCall('configureNodeNvsShelf',{'sonusbparamshelfindex' => '1', 'sonusBparamParamMode' => 'DISABLED'});
        }else{
            $logger->info(' NVSDISABLED IS FALSE.  PARAMETER MODE WILL NOT BE TOUCHED');
        }

        $self->{conn}->print('configure node restart');
        $self->{conn}->waitfor('');
        $logger->info(' RESET ISSUED - SLEEPING FOR 60 AFTER RESET');

        foreach(1..60){
            sleep(1);
        }

    }else{
        $logger->info(' RESET FLAG IS FALSE.  SKIPPING RESET NODE');
    }
    $logger->debug('<-- Leaving Sub');
}


#########################################################################################################

#################################################
sub getNTPTime {
#################################################
    my($self) = @_;
    my(@cmdResults,$cmd,$y,$mo, $d, $h, $min, $s );
    my $subName = 'getNTPTime()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $y=$mo=$d=$h=$min=$s=0;
    $logger->debug(" Retrieving NTP Time");
    $cmd = 'show ntp time';
    @cmdResults = $self->execCmd($cmd);
    foreach(@cmdResults) {
      if(m/.*Date: (\d{4})\/(\d{2})\/(\d{2})\s+(\d{2})\:(\d{2})\:(\d{2}).*/){
        $logger->info(' Discovered NTP Time');
        $y=$1;$mo=$2;$d=$3;$h=$4;$min=$5;$s=$6;
        last;
      }
    }
    # Remove leading zeros from day and month strings
    $mo =~ s/^0*//;
    $d =~ s/^0*//;

    $logger->debug('<-- Leaving Sub');
    return ($y, $mo, $d, $h, $min, $s);
}
#########################################################################################################

##################################################################################
##################################################################################
# The following procedures were introduced as part of AJ9 CIE testing ############
#  The first fetches the user profile and returns it                             #
#  The second reboots MGW9000 without checking the object's RESET FLAG           #
##################################################################################
##################################################################################

##################################################################################
#purpose      : returns the profile name defined as a USER PROFILE this in turn  #
#can be used to determine what configuration has been applied to the MGW9000     #
#Parameters   : flag (if set to 1, this will return an array of all user profiles)
#Return values: Name of the profile(s)
##################################################################################

#################################################
sub getUserProfile {
#################################################
    my($self,$flag) = @_;
    my(@cmdResults,$cmd,$profilename, @profilenames, $diff, $i, $j);
    my $subName = 'getUserProfile()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    if ( !( defined($flag) ) ) {
        $logger->debug(' FLAG NOT DEFINED');
        $flag=0;
    }

    $profilename=0;
    $logger->debug(' Retrieving User Profile');
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

    if($flag == 0) {
        $profilename = $cmdResults[$count];
        $logger->debug(' RETURNING A SCALAR');
        $logger->debug('<-- Leaving Sub');
        return ($profilename);
    } else {
        my $diff = $cmdResultsLength - $count;
        for ($i = 0; $i <= $diff; $i++) {
            push @profilenames, $cmdResults[$count + $i];
        }
        $logger->debug(' RETURNING AN ARRAY');
        $logger->debug('<-- Leaving Sub');
        return @profilenames;
    }
}


#########################################################################################################

##################################################################################
#purpose      : resets the MGW9000 using conf node res without checking reset flag
#Parameters   : none
#Return values: nothing
##################################################################################

#################################################
sub resetNode2 {
#################################################
    my($self) = @_;
    my $subName = 'resetNode2()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' CHECKING OBJECT RESET FLAG');

    $self->{conn}->cmd('set NO_CONFIRM 0');
    $self->{conn}->cmd('set NO_CONFIRM 1');
    $logger->info(' CHECKING NVSDISABLED FLAG');
    if(defined($self->{NVSDISABLED}) && $self->{NVSDISABLED}){
        $logger->info('  NVSDISABLED IS TRUE.  ATTEMPTING TO DISABLE PARAMETER MODE');
        $self->execFuncCall('configureNodeNvsShelf',{'sonusbparamshelfindex' => '1', 'sonusBparamParamMode' => 'DISABLED'});
    }else{
        $logger->info(' NVSDISABLED IS FALSE.  PARAMETER MODE WILL NOT BE TOUCHED');
    }
    $self->{conn}->print('configure node restart');
    $self->{conn}->waitfor('');
    $logger->info(' RESET ISSUED - SLEEPING FOR 60 AFTER RESET');

    foreach(1..60){
        sleep(1);
    }
    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

##################################################################################
# Purpose      : To retrieve the CDR for a call from the MGW9000's NFS mount point,
#               and parse through for the field number of interest
# Parameters   : 1. type of CDR record (START, STOP, ATTEMPT, etc.),
#               2. number of record type (i.e. 1st START, 2nd STOP, etc.)
#               3. field number of interest
# Return values: value in field of interest
# Author      : Shawn Martin
# Disclaimer  : The following procedures are used only by PSX QA. Others
#            may use the procedures at their own risk.
##################################################################################

#################################################
sub getCDRfield {
#################################################
    my ($self, $recordtype, $recordnumber, $fieldnumber, $mgwname) = @_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $acctlogname, $acctlogfullpath, @acctlog, @acctrecord, $acctrecord, $csv,
        @acctsubrecord, $acctsubrecord, $arraysize, $dsiObj);
    my $subName = 'getCDRfield()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' RETRIEVING AND PARSING CDR');

    # Get node name. If the optional 'mgwname' parameter is passed, use it as
    # the node name, otherwise grab it from the chassis itself.
    if (defined($mgwname)) {
        $nodename = $mgwname;
    }
    else {
        $cmd = 'show node admin';
        @cmdresults = $self->execCmd($cmd);
        foreach (@cmdresults) {
            if ( m/Node:\s+(\w+)/ ){
                $nodename = $1;
                $nodename =~ tr/[a-z]/[A-Z]/;
            }
        }
    }

    if (!defined($nodename)) {
        $logger->warn(' NODE NAME MUST BE DEFINED');
        $logger->debug('<-- Leaving Sub');
        return $nodename;
    }

    # Get IP address and path of active NFS
    $cmd = 'show nfs shelf 1 slot 1 status';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
            $activenfs = $1;
        }
        if (defined $activenfs) {
            if( m|($activenfs).*\s+(\d+.\d+.\d+.\d+)\s+(\S+)|i ) {
                $nfsipaddress = $2;
                $nfsmountpoint = $3;
                last;
            }
        }
    }

    # Remove node name if present
    $nfsmountpoint =~ s|$nodename||;

    # Get chassis serial number
    $cmd = 'show chassis status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active ACT log
    $cmd = 'show event log all status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.ACT)/) {
            $acctlogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
#        $acctlogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$acctlogname";
        $acctlogfullpath = "$nfsmountpoint\/$nodename\/evlog\/$serialnumber\/ACT\/$acctlogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$acctlogname = $acctlogname \n\t\$acctlogfullpath = $acctlogfullpath");
        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                                    -OBJ_HOST => $nfsipaddress,
                                    -OBJ_USER => 'root',
                                    -OBJ_PASSWORD => 'sonus',
                                    -OBJ_COMMTYPE => 'SSH',
                                );
        }
        @acctlog = $dsiObj->getLog($acctlogfullpath);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
#        $acctlogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$acctlogname";
        $acctlogfullpath = "$nfsmountpoint\/$nodename\/evlog\/$serialnumber\/ACT\/$acctlogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$acctlogname = $acctlogname \n\t\$acctlogfullpath = $acctlogfullpath");
        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                                    -OBJ_HOST => $nfsipaddress,
                                    -OBJ_USER => 'root',
                                    -OBJ_PASSWORD => 'sonus',
                                    -OBJ_COMMTYPE => 'SSH',
                                );
        }
        @acctlog = $dsiObj->getLog($acctlogfullpath);
    }

    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
#            $acctlogfullpath = '/sonus/SonusQANFS/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$acctlogname";
            $acctlogfullpath = "\/sonus\/SonusQANFS\/$nodename\/evlog\/$serialnumber\/ACT\/$acctlogname";
        }
        else {
#            $acctlogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$acctlogname";
            $acctlogfullpath = "$nfsmountpoint\/$nodename\/evlog\/$serialnumber\/ACT\/$acctlogname";
        }

        # Remove double slashes if present
        $acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
        unless (defined $self->{dsiObj}) {
            $dsiObj = SonusQA::DSI->new(
                                    -OBJ_HOST => 'talc',
                                    -OBJ_USER => 'autouser',
                                    -OBJ_PASSWORD => 'autouser',
                                    -OBJ_COMMTYPE => 'SSH',
                                );
        }
        @acctlog = $dsiObj->getLog($acctlogfullpath);
    }
    $logger->debug(" \$acctlogfullpath = $acctlogfullpath");
    # Parse each START/STOP/ATTEMPT record is placed into an array element,
    my $count = 1;
    foreach(@acctlog) {
        if ( $_ =~ m/$recordtype/ ) {
            if ($count == $recordnumber) {
                $csv = Text::CSV->new();
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
        $acctsubrecord = $acctrecord[$1 - 1];
        $csv->parse($acctsubrecord);
        @acctsubrecord = $csv->fields;
        $arraysize = @acctsubrecord;
        if ($2 > $arraysize) { # looking for array out-of-bounds situation
            $logger->warn(' SUBFIELD DOES NOT EXIST IN ACT LOG');
            $logger->debug('<-- Leaving Sub');
            return 'ERROR - SUBFIELD DOES NOT EXIST';
        }
        else {
            return $acctsubrecord[$2 - 1];
        }
    }
    else {
        $arraysize = @acctrecord;
        if ($fieldnumber > $arraysize) {
            $logger->warn(' FIELD DOES NOT EXIST IN ACT LOG');
            $logger->debug('<-- Leaving Sub');
            return 'ERROR - FIELD DOES NOT EXIST';
        }
        else {
            $logger->debug('<-- Leaving Sub');
            return $acctrecord[$fieldnumber - 1];
        }
    }
}

#########################################################################################################

##################################################################################
#Purpose      : To retrieve the active MGW9000 SYS log for a call from the MGW9000's NFS
#               mount point.
#Return values: MGW9000 SYS log
# Author      : Devaraj GM
# Disclaimer  : The following procedures are used only by PSX QA. Others
#               may use the procedures at their own risk.
##################################################################################

#################################################
sub getSYSlog {
#################################################
    my ($self) = @_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $subName = 'getSYSlog()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' RETRIEVING ACTIVE MGW9000 SYS LOG');

    # Get node name
    $cmd = 'show node admin';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if ( m/Node:\s+(\w+)/ ){
            $nodename = $1;
            $nodename =~ tr/[a-z]/[A-Z]/;
        }
    }
    if (!defined($nodename)) {
        $logger->warn(' NODE NAME MUST BE DEFINED');
        $logger->debug('<-- Leaving Sub');
        return $nodename;
    }

    # Get IP address and path of active NFS
    $cmd = 'show nfs shelf 1 slot 1 status';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
            $activenfs = $1;
        }
        if (defined $activenfs) {
            if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
                $nfsipaddress = $2;
                $nfsmountpoint = $3;
                last;
            }
        }
    }

    # Get chassis serial number
    $cmd = 'show chassis status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active SYS log
    $cmd = 'show event log all status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.SYS)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$dbglogname";

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => 'root',
            -OBJ_PASSWORD => 'sonus',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = '/export/home'."$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$dbglogname";
        $logger->debug("\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$dbglogname = $dbglogname \n\t\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
                    -OBJ_HOST => $nfsipaddress,
                    -OBJ_USER => 'root',
                    -OBJ_PASSWORD => 'sonus',
                    -OBJ_COMMTYPE => 'SSH',
                );
        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }

    if ( ($nfsmountpoint =~ m/MarlinQANFS/ ) || ( $nfsmountpoint =~ m/SonusQANFS/ ) ) {
        if ( $nfsmountpoint =~ m/MarlinQANFS/ ) {
            $dbglogfullpath = '/sonus/SonusQANFS/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$dbglogname";
        }

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }
    $logger->debug('<-- Leaving Sub');
    return @dbglog;
}



#########################################################################################################

##################################################################################
#Purpose      : To retrieve the active MGW9000 TRC log for a call from the MGW9000's NFS
#               mount point.
#Return values: MGW9000 TRC log
# Author      : Devaraj GM
# Disclaimer  : The following procedures are used only by PSX QA. Others
#            may use the procedures at their own risk.
##################################################################################

#################################################
sub getTRClog {
#################################################
    my ($self) = @_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $subName = 'getTRClog()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' RETRIEVING ACTIVE MGW9000 TRC LOG');

    # Get node name
    $cmd = 'show node admin';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if ( m/Node:\s+(\w+)/ ){
            $nodename = $1;
            $nodename =~ tr/[a-z]/[A-Z]/;
        }
    }
    if (!defined($nodename)) {
        $logger->warn(' NODE NAME MUST BE DEFINED');
        $logger->debug('<-- Leaving Sub');
        return $nodename;
    }

    # Get IP address and path of active NFS
    $cmd = 'show nfs shelf 1 slot 1 status';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
            $activenfs = $1;
        }
        if (defined $activenfs) {
            if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
                $nfsipaddress = $2;
                $nfsmountpoint = $3;
                last;
            }
        }
    }

    # Get chassis serial number
    $cmd = 'show chassis status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active TRC log
    $cmd = 'show event log all status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.TRC)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/TRC/' . "$dbglogname";

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => 'root',
            -OBJ_PASSWORD => 'sonus',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = '/export/home'."$nfsmountpoint\/$nodename" . '/evlog/' . "$serialnumber" . '/TRC/' . "$dbglogname";
        $logger->debug("\t\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$dbglogname = $dbglogname \n\t\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => 'root',
                -OBJ_PASSWORD => 'sonus',
                -OBJ_COMMTYPE => 'SSH',);

           @dbglog = $dsiObj->getLog($dbglogfullpath);
    }

    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = '/sonus/SonusQANFS/' . "$nodename" . '/evlog/' . "$serialnumber" . '/TRC/' . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/TRC/' . "$dbglogname";
        }

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }
    $logger->debug('<-- Leaving Sub');
    return @dbglog;
}

#########################################################################################################

##################################################################################
#Purpose      : To retrieve the active MGW9000 DBG log for a call from the MGW9000's NFS
#               mount point.
#Return values: MGW9000 DBG log
# Author      : Shawn Martin
# Disclaimer  : The following procedures are used only by PSX QA. Others
#            may use the procedures at their own risk.
##################################################################################

#################################################
sub getDBGlog {
#################################################
    my ($self) = @_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog);
    my $subName = 'getDBGlog()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' RETRIEVING ACTIVE MGW9000 DBG LOG');

    # Get node name
    $cmd = 'show node admin';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if ( m/Node:\s+(\w+)/ ){
            $nodename = $1;
            $nodename =~ tr/[a-z]/[A-Z]/;
        }
    }
    if (!defined($nodename)) {
        $logger->warn(' NODE NAME MUST BE DEFINED');
        $logger->debug('<-- Leaving Sub');
        return $nodename;
    }

    # Get IP address and path of active NFS
    $cmd = 'show nfs shelf 1 slot 1 status';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
            $activenfs = $1;
        }
        if (defined $activenfs) {
            if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
                $nfsipaddress = $2;
                $nfsmountpoint = $3;
                last;
            }
        }
    }

    # Get chassis serial number
    $cmd = 'show chassis status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active DBG log
    $cmd = 'show event log all status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.DBG)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => 'root',
            -OBJ_PASSWORD => 'sonus',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = '/export/home'."$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        $logger->debug("\t\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$dbglogname = $dbglogname \n\t\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => 'root',
                -OBJ_PASSWORD => 'sonus',
                -OBJ_COMMTYPE => 'SSH',);

           @dbglog = $dsiObj->getLog($dbglogfullpath);
    }



    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = '/sonus/SonusQANFS/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        }

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => 'SSH',);

        @dbglog = $dsiObj->getLog($dbglogfullpath);
    }
    $logger->debug('<-- Leaving Sub');
    return @dbglog;
}


#########################################################################################################

##################################################################################
##################################################################################
# The following procedures are used only by the MGW9000 QA Automation  Group. Others #
# can use the procedures at their own risk.
##################################################################################
##################################################################################

##################################################################################
#purpose      : returns the availabe cics for the trunk group supplied
#Parameters   : trunk group
#Return values: cic
##################################################################################


#################################################
sub getAvailcic {
#################################################
    my($self, $mytg) = @_;
    my $mycics = 0;
    my $subName = 'getAvailcic()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving cics for Trunkgroup');
    if($self->execFuncCall('showTrunkGroupStatus',{'trunk group'=> $mytg})){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\w+)\s+(\w*|\d*)\s+(\w*|\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w)/){
                if($1 eq $mytg){
                    $logger->info(" .. The available cics for the trunkgroup $mytg is $3" );
                    $mycics = $3;
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$mycics]");
    return $mycics;
}

#########################################################################################################

##################################################################################
#purpose       : help to make a decision based on available and required cics for calls
#parameters    : trunk group, required cics
#return values : returns 0 if  availabe cics == needed cics
#                -1 if  availabe cics < needed cics
#                 1 if  availabe cics > needed cics
#                -1 if  no trunk group found
##################################################################################
#################################################
sub chkAvailcic {
#################################################
    my($self, $mytg, $needcic) = @_;
    my $decide = -1;
    my $subName = 'chkAvailcic()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving cics for Trunkgroup');
    if($self->execFuncCall('showTrunkGroupStatus',{'trunk group'=> $mytg})){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\w+)\s+(\w*|\d*)\s+(\w*|\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w)/){
                if($1 eq $mytg){
                    $decide = ($3 <=> $needcic);
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$decide]");
    return $decide;
}

#########################################################################################################

##################################################################################
#purpose       : bring up all the server cards in the chassis.
#Parameters    : none
#Return Values : none
##################################################################################
#################################################
sub bringupServers {
#################################################
  my($self) = @_;
  my $subName = 'bringupServers()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug('--> Entered Sub');

  $self->getHWInventory(1);
  my $server = "";
  my $i = my $cmdSuccess = 0;
  my $adapter = "";

    for ($i = 3; $i <= 16; $i++) {
      if ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/NS/){
        if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} !~ m/CNA0/ ) {
          $server = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
          $adapter =  $self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'};
          $logger->info(" CNS CARD FOUND IN SLOT $i is $server and adapter $adapter");
          $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server adapter $adapter NORMAL");
          $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
          if ($cmdSuccess) {
            $logger->info("command result is $cmdSuccess");
          }
        }elsif ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/UNKNOWN/ ) {
          $server = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
          $adapter =  $self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'};
          $logger->info(" CNS CARD FOUND IN SLOT $i is $server and does not have any adapter $adapter");
        }else {
          $server = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
          $adapter =  $self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'};
          $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server adapter $adapter REDUNDANT");
          $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
          $logger->info(" REDUN CNS CARD FOUND IN SLOT $i and server $server and adapter $adapter");
        }
      }elsif ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/SPS/){
        $server = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
          $logger->info(" SPS CARD FOUND IN SLOT $i is $server");
          $cmdSuccess = $self->execCmd("CREATE SERVER SHELF 1 SLOT $i HWTYPE $server NORMAL");
          $cmdSuccess = $self->execCmd("CONFIGURE SERVER SHELF 1 SLOT $i state enabled");
      }
    }

    $logger->debug('<-- Leaving Sub');
}

#########################################################################################################

##################################################################################
#purpose       : get isup service names.
#Parameters    : none
#Return Values : Array of isup service names
##################################################################################
#################################################
sub getIsupService {
#################################################
    my($self) = @_;
    my @services =();
    my $subName = 'getIsupService()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving Isup service Name');
    if($self->execFuncCall('showIsupServiceAllStatus')){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\w+)\s+(\d-?\d-?\d)\s+(\w+)/){
                push @services, $1;
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
    return @services;
}

#########################################################################################################

##################################################################################
#purpose       : get isup service Point code for given isup service name.
#Parameters    : isup service
#Return Values : point code
##################################################################################
#################################################
sub getIsupPointcode {
#################################################
    my($self, $service) = @_;
    my $pointcode = "";
    my $subName = 'getIsupPointcode()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving point code for Isup service');
    if ($self->execFuncCall('showIsupServiceAllStatus')){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\w+)\s+(\d-?\d-?\d)\s+(\w+)/){
                if($1 eq $service){
                    $pointcode = $2;
                }
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
    return $pointcode;
}

#########################################################################################################

##################################################################################
#purpose       : get all NIFs provisioned on the SLOT
#Parameters    : shelf,SLOT no
#Return Values : Array of nifs on the slot
##################################################################################
#################################################
sub getNIFs {
#################################################
    my($self, $shelf, $slot) = @_;
    my @nifs =();
    my $subName = 'getNIFs()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving NIF Names');
    if ($self->execFuncCall('showNifShelfSlotStatus',{'nif shelf' => $shelf, 'slot' => $slot})){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\d-?\d+)\s+(\d)\s+(\w+-?\d-?\d+-?\d*)\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)/){
                push @nifs, $3;
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
    return @nifs;
}

#########################################################################################################

##################################################################################
#purpose: return slot number for the given Server(if a PNS40/PNA40 is in slots 4,5,6,
#        this proc returns 4,5,6
#Parameters    : shelf,server, adaptor
#Return Values : slot number
##################################################################################
#################################################
sub getallSlotnum {
#################################################
    my($self, $shelf, $server, $adapter) = @_;
    my $i = 0;
    my $subName = 'getallSlotnum()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $self->getHWInventory(1);

    # Search through slots 3 -16
    # Changed the search from slot 1 thru 16 to accomodate gsx4000 test cases
    my @slot = ();
    for ($i = 1; $i <= 16; $i++) {

        if ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/$server/ ){

            if (($self->{'hw'}->{'1'}->{$i}->{'SERVER'} eq 'SPS70' ) || ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} eq 'SPS80' ))       {
                push @slot, $i;
                $logger->info(" $server CARD FOUND IN SLOT $i");
                last;
            }

            #check if Adaptor is present in the same slot
            if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/$adapter/ ){
                push @slot, $i;
                $logger->info(" $server CARD FOUND IN SLOT $i");
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
                    case 'CNS20' { @AAdapter = 'CNA21'; }
                    case 'CNS30' { @AAdapter = ('CNA33', 'CNA03'); }
                    case 'CNS71' { @AAdapter = 'CNA70'; }
                    case 'PNS30' { @AAdapter = 'PNA35'; }
                    case 'PNS40' { @AAdapter = 'PNA45'; }
                    case 'PNS41' { @AAdapter = ('PNA40', 'PNA45'); }
                    else { $logger->debug(" $adapter CARD NOT FOUND"); } #out case
                 }

                foreach $a (@AAdapter)
                {
                    if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/$a/ ) {
                        push @slot, $i;
                        $logger->info(" $server CARD FOUND IN SLOT $i");
                        #last;
                    }
                }
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
    return @slot;
}

#########################################################################################################

##################################################################################
#purpose: return slot number for the given Server(if a PNS40/PNA40 is in slots 4,5,6,
#        this proc returns only 4.
#Parameters    : shelf,server, adaptor
#Return Values : slot number
##################################################################################
#################################################
sub getSlotnum {
#################################################
    my($self, $shelf, $server, $adapter) = @_;
    my @singleslot =();
    my $subName = 'getSlotnum()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    @singleslot = $self->getallSlotnum($shelf, $server, $adapter);
    $logger->debug('<-- Leaving Sub');
    return $singleslot[0];
}

#########################################################################################################

##################################################################################
#purpose: Verify that the given SIF is created.
#Parameters    : shelf, SIF
#Return Values : 0 if sif is not provisioned
#            1 if sif is provisioned
##################################################################################
#################################################
sub verifySIF {
#################################################
    my($self, $shelf, $sifname) = @_;
    my $found = 0;
    my $subName = 'verifySIF()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Verifying Provisioned SIF');
    if ($self->execFuncCall('showNifSubinterfaceStatus',{'nif subinterface' => $sifname})){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/$sifname/){
                $found = 1;
                last;
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
    return $found;
}

#########################################################################################################

##################################################################################
#
#purpose: Parse the header information for Show commands in mgw9000 for all versions
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

#################################################
sub getshowheader {
#################################################
    my($self) = @_;
    my $subName = 'getshowheader()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my @line1 = my @line2 = my @line3 = my @line4 = my @line5 = my @line6 = my @line7 = my @line8 =();
    my @arr =();
    ## The array addback is used to hold Header words that will be added to the previous header word
    ## Example:The word "rate" usually comes after PVP or DGP and is merged to a single word "PVPrate" or "DGPrate"

    my @addback = qw(rate bucket address reason); #more words can be added in future

    ## The array addbfront is used to hold Header words whose next header word will be added to them.
    ## Example: The word that usually comes after the header word "cur" is "bw" and is merged to a single word "curbw"

    my @addfront = qw(cur act max ins); #more words can be added in future

    my $i= my $j= 0;

    $logger->info('  Retrieving Header Information');

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
                case 0    { @line1 =split; $arr[$j] = \@line1; }
                case 1    { @line2 =split; $arr[$j] = \@line2; }
                case 2    { @line3 =split; $arr[$j] = \@line3; }
                case 3    { @line4 =split; $arr[$j] = \@line4; }
                case 4    { @line5 =split; $arr[$j] = \@line5; }
                case 5    { @line6 =split; $arr[$j] = \@line6; }
                case 6    { @line7 =split; $arr[$j] = \@line7; }
                case 7    { @line8 =split; $arr[$j] = \@line8; }
                else {
                    $logger->debug(' header goes beyond line 8');
                }
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
                        @{$arr[$j]}[$k] = "@{$arr[$j]}[$k]"."@{$arr[$j]}[$k + 1]";
                        splice(@{$arr[$j]}, $k + 1, 1);
                    }
                }#foreach
            }#for $k

            #$logger->debug(__PACKAGE__ . ".getshowheader  $j , $#{$arr[$j]} , @{$arr[$j]}");
        }#if

        $i++; #increment to next $_

    }#foreach CMDRESULT

    # now change all the header words to Uppercase
    for($i = 0; $i <= $#arr; $i++){
        for ($j = 0; $j <= $#{$arr[$i]}; $j++) {
            @{$arr[$i]}[$j] =uc @{$arr[$i]}[$j];
            $logger->debug("      @{$arr[$i]}[$j]");
        }
    }

    $logger->debug('<-- Leaving Sub');
    return @arr; #two dimensional array of header.
}

##################################################################################
#
#purpose: Populate a particular nif's/sif's config values
#Parameters    : shelf, nif/sif
#Return Values : None
#
##################################################################################
#################################################
sub getconfigvalues {
#################################################
    my($self, $niforsif, @arra) = @_;
    my @val =();
    my ($i, $j, $flag) = (0, 0, 0);

    my $subName = 'getconfigvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Populating Config  Information');
    foreach (@{$self->{CMDRESULTS}}){
        if(m/$niforsif/){
            $logger->debug("     $_");
            $flag = 1;
        }
        if($flag == 1){
            @val =();
            if($i <= $#arra){
                @val = split;
                if($#val == $#{$arra[$i]}) {
                    for($j = 0; $j <= $#{$arra[$i]}; $j++){
                         $self->{$niforsif}->{@{$arra[$i]}[$j]} = $val[$j] ;
                         $logger->debug("  @{$arra[$i]}[$j]      $val[$j]") ;
                    } #for j
                } #if val
                $i = $i + 1 ;
            } #if i
        } #if flag
    } #foreach
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular nif's Admin values
#Parameters    : shelf, nif
#Return Values : None
#
##################################################################################
#################################################
sub getNIFadminvalues {
#################################################
    my($self, $nif) = @_;
    my $subName = 'getNIFadminvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving NIF Admin Information');
    $self->execFuncCall('showNifAdmin', {'nif' => $nif});
    $self->getconfigvalues( $nif, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular nif's status values
#Parameters    : shelf, nif
#Return Values : None
#
##################################################################################
#################################################
sub getNIFstatusvalues {
#################################################
    my($self, $nif) = @_;
    my $subName = 'getNIFstatusvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving NIF Status Information');
    $self->execFuncCall('showNifAllStatus');
    $self->getconfigvalues( $nif, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular sif's Admin values
#Parameters    : shelf, sif
#Return Values : None
#
##################################################################################
#################################################
sub getSIFadminvalues {
#################################################
    my($self, $sif) = @_;
    my $subName = 'getSIFadminvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->info('  Retrieving SIF Admin Information');
    $self->execFuncCall('showNifSubinterfaceAdmin',{'nif subinterface' => $sif});
    $self->getconfigvalues( $sif, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Verify IP routes provisioned for a SIF
#Parameters    : shelf, slot, nexthop
#Return Values : None
#
##################################################################################
#################################################
sub verifyIProutes {
#################################################
    my($self, $slot, $nh) = @_;
    my $found =0;
    my $subName = 'verifyIProutes()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Verify IP Routes');
    $self->execFuncCall('showIpRoutesShelfSlot', {'ip routes shelf' => 1, 'slot' => $slot });
    foreach(@{$self->{CMDRESULTS}}){
        if(/$nh/) {
            $logger->info(' verifyIProutes The IP route is found');
            $found = 1;
            last;
        }
    }
    $logger->debug("<-- Leaving Sub [$found]");
    return $found;
}

##################################################################################
#purpose: Verify that the given NIF is created.
#Parameters    : shelf, NIF
#Return Values : 0 if nif is not provisioned
#            1 if nif is provisioned
##################################################################################
#################################################
sub verifyNIF {
#################################################
    my($self, $shelf, $nifname) = @_;
    my $found = 0;
    my $subName = 'verifyNIF()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Verifying  NIF');
    if ($self->execFuncCall('showNifStatus',{'nif' => $nifname})){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/$nifname/){
                $found = 1;
                last;
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$found]");
    return $found;
}

##################################################################################
#purpose: Verify that the given NIFGroup is created.
#Parameters    : shelf, NIFGroup
#Return Values : 0 if nif is not provisioned
#            1 if nif is provisioned
##################################################################################
#################################################
sub verifyNIFgroup {
#################################################
    my($self, $shelf, $nifg) = @_;
    my $found = 0;
    my $subName = 'verifyNIFgroup()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Verifying  NIF Group');
    if ($self->execFuncCall('showNifgroupSummary')){
        foreach(@{$self->{CMDRESULTS}}){
            if(m/$nifg/){
                $found = 1;
                 last;
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$found]");
    return $found;
}

##################################################################################
#purpose: Verify that the given member is in the NIFGROUP.
#Parameters    : shelf, NIFGroup, sif
#Return Values : 0 if nif is not provisioned
#            1 if nif is provisioned
##################################################################################
#################################################
sub verifyNIFgroupmem {
#################################################
    my($self, $shelf, $nifg, $sif) = @_;
    my $found = 0;
    my $subName = 'verifyNIFgroupmem()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Verifying  NIF Group member');
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
     $logger->debug("<-- Leaving Sub [$found]");
     return $found;
}

##################################################################################
#purpose: return slot number for the given Server(if a MNS/MNA is in slots 1,2
#        this proc returns only 1.)
#Parameters    : shelf,server, adaptor
#Return Values : slot number
##################################################################################
#################################################
sub getSlotnummns {
#################################################
    my($self, $shelf, $server, $adapter) = @_;
    my $i = 0;
    my $subName = 'getSlotnummns()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $self->getHWInventory(1);

    # Search through slots 1 -2 for a MNS and MNA card
    my $slot = 0;
    for ($i = 1; $i <= 2; $i++) {
        if ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/$server/ ) {
            #check if MNA is present in the same slot

            if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/$adapter/ ) {
                $slot = $i;
                $logger->info(" $server CARD FOUND IN SLOT $i");
                last;

            ## checking for multiple adaptors for a give server card ##
            ##   MNS11  |  MNA10
            ##   MNS20  |  MNA20, MNA21, MNS25
            }
            elsif ($server eq 'MNS11') {
                if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/"MNA10"/ ){
                    $slot = $i;
                    $logger->info(" $server CARD FOUND IN SLOT $i");
                    last;
                } elsif ($server eq 'MNS20' )  {
                    if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/"MNA21"/ ) {
                        $slot = $i;
                        $logger->info(" $server CARD FOUND IN SLOT $i");
                        last;
                    } elsif ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/"MNA25"/ ) {
                        $slot = $i;
                        $logger->info(" $server CARD FOUND IN SLOT $i");
                        last;
                    }
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$slot]");
    return $slot;
}

##################################################################################
# purpose: Verify that the given Element is configured in the CMDRESULTS.
# Parameters    : element
# Return Values :     0 if port is not provisioned
#                1 if port is provisioned
##################################################################################
#################################################
sub verifyElement {
#################################################
    my($self,$element) = @_;
    my $found = 0;
    my $subName = 'verifyElement()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Verify Element');
    foreach(@{$self->{CMDRESULTS}})
    {
        if(m/$element/)
        {
            $found = 1;
            last;
        }
    }

    $logger->debug("<-- Leaving Sub [$found]");
    return $found;
}


##################################################################################
# purpose: Count the total number of Stable calls that match with the Called Party Number.
# Parameters    : cdpn - 10 digits
# Return Values : n total number of the Stable calls that match with the CDPN
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::countStableCalls(<cdpn>)

 Routine to count the total number of the stable calls that match with the called party number

=over

=item Arguments

  cdpn <Scalar>
  teh called party number

=item Returns

  Number
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a numberical value

=item Example(s):

  &$mgw9000Obj->countStableCalls(<$cdpn>);

=back

=cut

#################################################
sub countStableCalls {
#################################################
    my($self,$cdpn) = @_;
    my $stable = 0;
    my $subName = 'countStableCalls()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    if ($self->execFuncCall('showCallSummaryAll')){
        foreach(@{$self->{CMDRESULTS}}){
            if((/Stable/) && (/$cdpn/)){
                $stable++;
            }
        }
    }
    $logger->info("Total Stable calls :  $stable");
    $logger->debug("<-- Leaving Sub [$stable]");
    return $stable;
}

##################################################################################
# purpose: Delete All Calls
# Parameters    : None
# Return Values :     0 no call deleted
#                n total number of calls deleted
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::deleteAllCallsESTNAME>)

 Routine to delete all calls

=over

=item Arguments

  None

=item Returns

  Number
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a numberical value

=item Example(s):

  &$mgw9000Obj->deleteLoadTest();

=back

=cut

#################################################
sub deleteAllCalls {
#################################################
    my($self) = @_;
    my $deleted = 0;
    my $subName = 'deleteAllCalls()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Delete All Calls');

    if ($self->execFuncCall('showCallSummaryAll')) {
        foreach(@{$self->{CMDRESULTS}}) {
            if (m/^(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)/) {
                if ($self->execFuncCall(
                          'configureCallGcidDelete',
                          {
                              'call gcid' => $1,
                          },
                      ) ) {
                    $deleted++;
                }
                else {
                    $logger->info(" DELETE CALL  $1  FAILED");
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$deleted]");
    return $deleted;
}

######################################################################################
# purpose: Get Accounting Summary Statistics
# Parameters    : None
# Return Values :     an array value of [Attempts Completions Failures Rate Seconds]
#
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getAccountingSummary()

 Routine to retrieve accounting summary for the calls.

=over

=item Arguments

  none

=item Returns

  An Array of the following elements:
  Total Number of Call Attempts, Total Numbers of Call Completions, Total Number of Call Attempt Failures, Busy Hour Call Attempt Rate, Calls per Second, Call Duration in Seconds.

=item Example(s):

  &$mgw9000Obj->getAccountingSummary()

=back

=cut

#################################################
sub getAccountingSummary {
#################################################
    my($self) = @_;
    my @contents = ('Attempts:','Completions:','Failures:','Rate:','Minute:','seconds');
    my @statistic =();
    my $subName = 'getAccountingSummary()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving Accounting Summary Statistics');

    if ($self->execCmd('SHOW ACCOUNTING SUMMARY')) {
        my $linecount = 1;
        my $count        = 1;
        foreach(@{$self->{CMDRESULTS}}) {
            my @array     = split;
            my $column     = 0;
            for($column=0; $column<=$#array; $column++) {
                my $index = 0;
                foreach(@contents) {
                    if ($array[$column] eq $contents[$index]) {
##                        $logger->info("Column= $column, Index= $index, Line= $linecount, Count= $count");
##                        push @statistic,$count;
                        if ($array[$column] eq 'seconds') {
                            push @statistic, $array[$column + 2];
                        } else {
                            push @statistic, $array[$column + 1];
                        }
                        $count++;
                    }
                    $index++;
                }
            }
            $linecount++;
        }
    }
    $logger->debug('<-- Leaving Sub');
    return @statistic;
}

######################################################################################
# purpose       : Verify Call Tolerance Rate
# Parameters    : trate
# Return Values :     passed = 1
#                     failed = 0
#
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::verifyToleranceRate(<trate>)

 Routine to verify completion rate against the tolerance rate.

=over

=item Arguments

  trate <Scalar>
  A number that will be used to compare with the sucessful completion rate

=item Returns

  Boolean
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a true of false Boolean.

=item Example(s):

  &$mgw9000Obj->verifyToleranceRate(0.9);

=back

=cut

#################################################
sub verifyToleranceRate {
#################################################
    my($self,$trate) = @_;
    my $subName = 'verifyToleranceRate()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Calculate Tolerance Rate');

    my $passed = 0;
    my @statistic = $self->getAccountingSummary();
    if ($#statistic == -1)
    {
        $logger->info('  ACCOUNTING SUMMARY REPORT NOT AVAILABLE');
    } else {
        my $sucessfulcallrate     = 0;
        if ($statistic[0] > 0) {
            $sucessfulcallrate = ($statistic[1])/$statistic[0];
            $logger->info('  THE TOTAL NUMBER OF CALL ATTEMPTS IS '. "$statistic[0]". ', AND CALL COMPLETIONS IS '. "$statistic[1]");
            my $tolerate = (1 - $trate);
            if (($sucessfulcallrate) >= $tolerate) {
                $logger->info('  COMPLETED '. "$sucessfulcallrate*100" . '% ABOVE/MEET THE TOLERANCE RATE OF '. "$tolerate*100" . '% PASSED');
                $passed = 1;
            } else {
                $logger->info('  COMPLETED '. "$sucessfulcallrate*100" . '% BELOW THE TOLERANCE RATE OF ' . "$tolerate*100" . '% FAILED');
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$passed]");
    return $passed;
}

######################################################################################
# purpose: Roll the MGW9000 log file to start a new log before the call
# Parameters: (see below)
# Return Value: a string with teh full path name of the log
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::rollLogFile( <logFileType>, <mgwNodeName>, <sonicId>)

 Routine that rolls a particular log file, and returns the path to the current log file (after the log was rolled).

=over

=item Arguments

 logFileType <Scalar>
 A string that determines the type of log to affect. Must be one of DEBUG, ACCT, SYSTEM or TRACE.

 mgwNodeName <Scaler>
 Name of the MGW9000 node. Needs to be uppercase to match the path of the file on the NFS mount. Should normally be $mgw1->{NODE}->{1}->{NAME}

 sonicId <Scaller>
 Sonid Id of the node. Should normally be $mgw1->{NODE}->{1}->{SONICID}

=item Returns

 full path to the log file <Scaller>
 This is the path from root of the log file, including the NFS mount.

=item Example(s):

 my $mgwLogFile = $mgw9000Obj->rollLogFile( 'DEBUG', $mgw1->{NODE}->{1}->{NAME}, $mgw1->{NODE}->{1}->{SONICID});

=back

=cut

#################################################
sub rollLogFile {
#################################################
    my( $self, $logType, $nodeName, $sonicId ) = @_;
    my $logFileName;

    my $subName = 'rollLogFile()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->debug(' Rolling log files and returning path.');
    $self->execFuncCall('configureEventLogRollfileNow',
            { 'sonusEvLogType'  => $logType });

    # validate and get the correct path name depending on the log type.
    my $logTypevalid = 0;
    my $fullLogType = $logType;
    if( $logType =~ s/DEBUG/DBG/ ) { $logTypevalid = 1; }
    if( $logType =~ s/ACCT/ACT/ ) { $logTypevalid = 1; }
    if( $logType =~ s/SYSTEM/SYS/ ) { $logTypevalid = 1; }
    if( $logType =~ s/TRACE/TRC/ ) { $logTypevalid = 1; }
    unless( $logTypevalid ) {
       $logger->warn(' Log Type must be one of DEBUG|ACCT|SYSTEM|TRACE.');
       $logger->debug("<-- Leaving Sub [$logFileName]");
       return $logFileName;
    }

    $self->execFuncCall('showNfsShelfSlotStatus', {
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
                $mountPoint = $2 . '/';
                last;
            }
        }
    }
    unless ( defined $mountPoint ) {
       $logger->warn(' FAILED TO DETERMINE ACTIVE NFS MOUNT.');
       $logger->debug("<-- Leaving Sub [$logFileName]");
       return $logFileName;
    }

    # now, look for the actual file name
    $self->execFuncCall('showEventLogShelfStatus',
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
       $logger->warn(" FAILED TO DETERMINE CURRENT $fullLogType FILE NAME.");
       return $logFileName;
    }

    $logFileName = $mountPoint . $nodeName . '/evlog/' .
        $sonicId . '/' . $logType . '/' . $actualLog;

    $logger->debug("<-- Leaving Sub [$logFileName]");
    return $logFileName;
}

######################################################################################
# purpose:     Retrieve the Total Play counts for a given Segment ID
# Parameters: Shelf, Slot and Segment ID
# Return Value: an array of Current Play and Total Play Counts
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getAnnouncementSummary(<shelf, slot, segid>)

 Routine to retrieve Status Count of a Segment ID .

=over

=item Arguments

  Shelf     - 1 <Scalar>
  Slot     - CSN Slot Number
  Segment ID - Announcement file that is used to play accouncement

=item Return

  Total Play Count

=item Example(s):

  &$mgw9000Obj->getAnnouncementSummary($segid);

=back

=cut

#################################################
sub getAnnouncementSummary {
#################################################
    my    ($self, $shelf, $slot, $segid) = @_;
    my    $result    =0;

    my $subName = 'getAnnouncementSummary()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieve Announcement Summary Report ');
    if($self->execFuncCall('showAnnouncementSegmentShelfSlotSummary', {'announcement segment shelf' => $shelf, 'slot' => $slot} )) {
        foreach(@{$self->{CMDRESULTS}}) {
            my @array     = split;
            if ($#array >= 6) {
                if ($array[2] == $segid) {
                    $result = $array[6];
                    $logger->info(" TOTAL PLAY COUNT FOR SEGMENT ID: $segid, SLOT: $slot IS $array[6]");
                    last;
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$result]");
    return $result;
}

##################################################################################
# purpose       : Save and restore the NVS param file.
# Parameters    : resolved mgw, nvs parm filename, flag
# Return Values : 0 if file is not copied
#                 1 if file is copied
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::modifyNvsparm(<mgw, file, saveorrestore>)

 Routine to retrieve Status Count of a Segment ID .

=over

=item Arguments

  mgw9000     - reference
  filename     - scalar(string)
  saveorrestore- flag to write into or read from

=item Return

  0 if file is not copied
  1 if file is copied

=item Example(s):

  &$mgw9000Obj->modifyNvsparm($mgw1, "example", 1);

=back

=cut

#################################################
sub modifyNvsparm {
#################################################
    my($self, $mgw, $file, $saveorrestore) = @_;
    my $flag = 0;
    my $cmd = "";
    my $subName = 'modifyNvsparm()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' moving files.........');
    my $dsiobj = SonusQA::DSI->new(
                                    -OBJ_HOST => $mgw->{'NFS'}->{'1'}->{'IP'},
                                    -OBJ_USER => 'root',
                                    -OBJ_PASSWORD => 'sonus',
                                    -OBJ_COMMTYPE => 'SSH',
                                  );
    if($saveorrestore){
        $cmd = '/usr/bin/cp '."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/param/'.'mgwrestore.prm'.' '."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/param/'."$file";
    }else{
        $cmd = '/usr/bin/cp '."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/param/'."$file".' '."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/param/mgwrestore.prm';
    }
    $logger->info($testcase->{TESTCASE_ID} . ".main $cmd ");
    if($dsiobj->execCmd($cmd)){
        $flag = 1;
    }
    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
}

##################################################################################
#
#purpose       : Verify if Bandwidth for NIF is 0
#Parameters    : slot
#Return Values :  0 if bw is not equal to 0
#                 1 if bw is equal to 0
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::verifyBwusage(<slot>)

 Routine to retrieve Status Count of a Segment ID .

=over

=item Arguments

  slot     - scalar

=item Return

  0 if bandwidth is 0
  1 if bandwidth is not 0

=item Example(s):

  &$mgw9000Obj->verifyBwusage(3);

=back

=cut

#################################################
sub verifyBwusage {
#################################################
    my($self, $slot) = @_;
    my @nifnames = ();
    my $flag = 1;
    my $subName = 'verifyBwusage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(" Retrieving NIFs from slot $slot");
    @nifnames = $self->getNIFs(1,$slot);
    foreach(@nifnames){
        $logger->info(' verifyBwusage Retrieving NIFs Bandwidth');
        $self->getNIFstatusvalues($_);
        $logger->info(' Verifying BW information');

        if($self->{$_}->{'CURBW'} ne "0"){
            $flag = 0;
            $logger->info(" .. Bandwidth for $_ is $self->{$_}->{'CURBW'}");
        }
    }
    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
}

######################################################################################
# purpose:     Retrieve the memory usage for given slot
# Parameters: Slot
# Return Value: Total memory used in byte
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getmemusage(<slot>)

 Routine to retrieve total memory usage from a card slot (or) total memory usage

=over

=item Arguments

  Slot     - PNS40 Slot Number

=item Return

  Total memory in use

=item Example(s):

  $memusage = $mgw9000Obj->getmemusage($pnsslot), $memusage = $mgw9000Obj->getmemusage()

=back

=cut

#################################################
sub getmemusage {
#################################################
    my    ($self, $slot) = @_;
    my    $memusage    = 0;
    my $cmd ="";

    my $subName = 'getmemusage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieve Memory Usage ');
    $self->execCmd('admin debugSonus');

    if(defined($slot)){
        $cmd = "memusage slot $slot all";
    }else {
        $cmd = 'memusage all';
    }

    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {
            my @array     = split;
            if ($#array >= 4) {
                # concatenate first 4 words into a string
                my $string = $array[0].' '.$array[1].' '.$array[2].' '.$array[3];
                if ($string eq 'Total size in use:') {
                    $memusage = $array[4];
                    $logger->info(" $string,  $memusage Bytes");
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$memusage]");
    return $memusage;
}

######################################################################################
# purpose:     Retrieve the CPU usage for given slot
# Parameters: Slot
# Return Value: % of the CPU Availability
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getcpuusage(<slot>)

 Routine to retrieve total CPU usage from a card slot (or) total cpu usage

=over

=item Arguments

  Slot     - PNS40 Slot Number

=item Return

  Total % of the CPU available

=item Example(s):

  $cpuusage = $mgw9000Obj->getcpuusage($pnsslot), $cpuusage = $mgw9000Obj->getcpuusage()

=back

=cut

#################################################
sub getcpuusage {
#################################################
    my    ($self, $slot) = @_;
    my    $cpuusage    = 0;
    my $cmd = "";

    my $subName = 'getcpuusage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieve CPU Usage');
    $self->execCmd('admin debugSonus');

    if(defined($slot)){
        $cmd = "cpuusage slot $slot all";
    }else {
        $cmd = 'cpuusage all';
    }

    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {
            my @array = split;
            if ($#array >= 2) {
                if ($array[0] eq 'IDLE:Invld') {
                    $cpuusage = $array[2];
                    $logger->info(" Available CPU : $cpuusage\%");
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$cpuusage]");
    return $cpuusage;
}

######################################################################################
# purpose:        Verify Tone Resource Usage
# Parameters:     Slot
# Return Value:   0 if resource is not release/failure
#                 1 if resource is 0
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::verifyToneResourceUsage(<slot>)

 Routine to retrieve the status of the PAD resource from a card slot.

=over

=item Arguments

  Slot     - CNS30 Slot Number

=item Return

     0 if resource is not release/failure
    1 if resource is 0

=item Example(s):

  $toneusage = $mgw9000Obj->verifyToneResouceUsage($cnsslot);

=back

=cut

#################################################
sub verifyToneResourceUsage {
#################################################
    my    ($self, $slot) = @_;
    my    $toneusage     = 0;
    my    $shelf = 1;

    my $subName = 'verifyToneResourceUsage()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Verify Resource Pad Usage');
    if($self->execFuncCall(
                            'showResourcePadShelfSlotStatus',
                            {
                                'resource pad shelf' => $shelf,
                                'slot' => $slot,
                            }
                        ) ) {
        foreach(@{$self->{CMDRESULTS}}) {
            my @array = split;
            if ($#array >= 3) {
                if ($array[0] eq 'Tone:') {
                    if ($array[2] == 0) {
                        if ($array[3] == 0 ) {
                            $toneusage = 1;
                            last;
                        }
                        else {
                            $logger->info("  Allocation Failures = $array[3]\%");
                        }
                    }
                    else {
                        $logger->info("  Utilization = $array[2]\%");
                    }
                    $logger->info("  DSP Resource Status: Utilitzation = $array[2], Allocation Failures = $array[3]");
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$toneusage]");
    return $toneusage;
}


######################################################################################
# purpose: Configure Rate parameters for the given overload profile
# Parameters: name, setcallrate, clearcallrate, setduration, clearduration
# Return Value: 1 if successful 0 otherwise
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::configOverloadProfrate(<profilename, setcallrate , clearcallrate, setduration, clearduration>)

 Routine to configure overload profile.

=over

=item Arguments

  profilename     - scalar(string)
  setcallrate    - scalar
  clearcallrate  - scalar
  setduration    - scalar
  clearduration  - scalar

=item Return

  flag 1 if successful 0 otherwise

=item Example(s):

  $mgw9000Obj->configOverloadProfrate("defaultMC1", 5, 3, 1, 10);

=back

=cut

#################################################
sub configOverloadProfrate {
#################################################
    my($self, $name, $setcallrate, $clcallrate, $setduration, $clduration) = @_;
    my $flag = 0;
    my $subName = 'configOverloadProfrate()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(" Configuring Overload Profile $name ");
    $self->execFuncCall ( 'configureOverloadProfileState',
                            {
                                'overload profile' => $name,
                                'sonusOverloadProfileAdminState' => "disabled",
                            }
                        );

    $self->execFuncCall ( 'configureOverloadProfileThreshold',
                            {
                                'overload profile' => $name,
                                'sonusOverloadProfileCallRateSetThreshold' => $setcallrate,
                                'sonusOverloadProfileCallRateClearThreshold' => $clcallrate,
                            }
                        );

    $self->execFuncCall ( 'configureOverloadProfileDuration',
                            {
                                'overload profile' => $name,
                                'sonusOverloadProfileCallRateSetDuration' => $setduration,
                                'sonusOverloadProfileCallRateClearDuration' => $clduration,
                            }
                        );

    if ($self->execFuncCall ( 'configureOverloadProfileState',
                                {
                                    'overload profile' => $name,
                                    'sonusOverloadProfileAdminState' => "enabled",
                                }
                            ) ) {
          $flag = 1;
    }
    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
}

######################################################################################
# purpose:     Retrieve the Total Use Count for a given Segment ID
# Parameters: Shelf, Slot and Segment ID
# Return Value: Total Use Count
######################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getAnnouncementStatus(<shelf, slot, segid>)

 Routine to retrieve Status Count of a Segment ID .

=over

=item Arguments

  Shelf     - 1 <Scalar>
  Slot     - CSN Slot Number
  Segment ID - Announcement file that is used to play accouncement

=item Return

  Total Play Count

=item Example(s):

  $mgw9000Obj->getAnnouncementStatus($shelf, $slot, $segid);

=back

=cut

#################################################
sub getAnnouncementStatus {
#################################################
    my    ($self, $shelf, $slot, $segid, $content) = @_;
    my    $result    =0;

    my $subName = 'getAnnouncementStatus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieve Announcement Status Report');
    if( $self->execFuncCall ( 'showAnnouncementSegmentShelfSlotStatus',
                                {
                                    'shelf' => $shelf,
                                    'slot' => $slot,
                                    'announcement segment' => $segid,
                                }
                            ) ) {
        foreach( @{$self->{CMDRESULTS}} ) {
            my @array     = split;
            if ($#array >= 3) {
                # concatenate first 3 words into a string
                my $string = $array[0].' '.$array[1].' '.$array[2];
                if ($string eq $content) {
                    $result = $array[3];
                    $logger->info(" $content FOR SEGMENT ID: $segid, SLOT: $slot IS $result");
                }
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$result]");
    return $result;
}

##################################################################################
# purpose: Retrieve the value from the CMDRESULTS.
# Parameters    : element
# Return Values : content of the element
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getElementValue(<element>)

 Routine to retrieve content of the element.

=over

=item Arguments

  Content - Element String of the element

=item Return

  Content of the element

=item Example(s):

  $result = $mgw9000Obj->getElementValue("Trunk Group Type");

=back

=cut

#################################################
sub getElementValue {
#################################################
    my($self,$element) = @_;
    my $content = 0;
    my @words = split (" ",$element);
    my $wsize = $#words;
    my $subName = 'getElementValue()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->debug(" Retrieve Value for $element ");

    foreach(@{$self->{CMDRESULTS}}) {
        $logger->debug(" $_ ");
        my @array     = split;
        my $column = 0;
        if ($#array >= ($wsize + 1)) {
            my $string = $array[0];
            for ($column = 1; $column <= $wsize; $column++) {
                $string = $string." ".$array[$column];
            }
            if ($string eq $element) {
                $content = $array[$wsize + 1];
                $logger->debug(" THE VALUE FOR $element IS $content");
                last;
            }
        }
    }
    $logger->debug("<-- Leaving Sub [$content]");
    return $content;
}

##################################################################################
#
# purpose: Retrieve MGW9000 Trunk Group Bandwidth Status
# Parameters    : None
# Return Values : bool
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getTGbandwidth()

 Routine to retrieve MGW9000 Trunk Group Bandwidth Status

=over

=item Arguments

  Content - none

=item Return

  bool

=item Example(s):

  $mgw9000Obj->getTGbandwidth();

=back

=cut

#################################################
sub getTGbandwidth {
#################################################
    my($self, $shelf) = @_;
    my(@results,$inventory, $bFlag);
    $bFlag = 0;
    my $subName = 'getTGbandwidth()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving MGW9000 Trunk Group Bandwidth Status');
    if($self->execFuncCall('showTrunkGroupBandwidthAllStatus')) {
        foreach(@{$self->{CMDRESULTS}}){
            if(m/^(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)/){
                $logger->debug(" Item: $_");
              $self->{'tg'}->{$1}->{'bwalloc'}         = $2;
              $self->{'tg'}->{$1}->{'callalloc'}     = $3;
              $self->{'tg'}->{$1}->{'bwlimit'}         = $4;
              $self->{'tg'}->{$1}->{'bwavail'}         = $5;
              $self->{'tg'}->{$1}->{'inboundbw'}     = $6;
              $self->{'tg'}->{$1}->{'outboundbw'}     = $7;
          }
        }
    }
    $logger->debug("<-- Leaving Sub [$bFlag]");
    return $bFlag;
}

##################################################################################
#
# purpose: Retrieve MGW9000 Redundancy Group information
# Parameters    : Redundancy Group Name
# Return Values : bool
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getRedgroupinfo()

 Routine to Retrieve MGW9000 Redundancy Group information

=over

=item Arguments

  redundancygroup -scalar (string)

=item Return

  none

=item Example(s):

  $mgw9000Obj->getRedgroupinfo("MNS20-1");

=back

=cut

#################################################
sub getRedgroupinfo {
#################################################
    my($self, $redgroup) = @_;
    my(@arr,$lastline, $i,$numofclients);
    my $subName = 'getRedgroupinfo()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(" Retrieving $redgroup state");

    $self->execFuncCall('showRedundancyGroupStatus', {'redundancy group' => $redgroup} );
    $self->{$redgroup}->{'redslot'}         = $self->getElementValue("Redundant Slot:");
    $self->{$redgroup}->{'redslotstate'}     = $self->getElementValue("Redundant Slot State:");
    $self->{$redgroup}->{'syncclients'}         = $numofclients = $self->getElementValue("Number of Synced Clients:");
    $self->{$redgroup}->{'swreason'}         = $self->getElementValue("Last Switchover Reason:");
    $logger->debug(" $#{$self->{CMDRESULTS}}");

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
        $self->{$redgroup}->{$numofclients-$i}->{'clentslot'} = $arr[0];
        $self->{$redgroup}->{$numofclients-$i}->{$arr[0]}->{'clentstate'} = $arr[1];
        $logger->info(".....$arr[0] ......$arr[1]...");
    }
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
# purpose: Retrieve the value from the CMDRESULTS.
# Parameters    : Service Group, Trunk Group Name
# Return Values : Service Name
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getServiceName(<servicegroup, trunkgroup)

 Routine to retrieve Service Group Name for a given Trunk Group Name.

=over

=item Arguments

  Content - String of the Service Group
            - String of the Trunk Group Name

=item Return

  Service Name

=item Example(s):

  $servicegroupname = $mgw9000Obj->getServiceName("SIP", "TrunkGroupName");

=back

=cut

#################################################
sub getServiceName {
#################################################
    my($self,$servicegroup, $trunkgroup) = @_;
    my $content = 0;
    my $i = 0;
    my $TgName = "Trunk Group :";
    my $servicegroupname = $servicegroup." Service :";
    my @words = split (" ",$servicegroupname);
    my $wsize = $#words;
    my $servicename    = "";
    my $nil = "";
    my $subName = 'getServiceName()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->debug(" Retrieve $servicegroup Service Name for $trunkgroup");

    my $tgfound = 0;
    foreach(@{$self->{CMDRESULTS}}) {
        $i++;
        $logger->debug(" $i  getServiceName:  $_");
        my @array     = split;
        my $column = 0;
        if ($#array >= ($wsize + 1)) {
            my $string = $array[0];
            for ($column = 1; $column <= $wsize; $column++) {
                $string = $string.' '.$array[$column];
            }

            if ($string eq $servicegroupname) {
                $servicename = $array[$wsize + 1];
                $logger->debug(" SERVICE NAME: $servicename");
            }
            if (($string eq $TgName) and ($array[$wsize + 1] eq $trunkgroup)) {
                $logger->debug(" TRUNK GROUP: $trunkgroup, IS $servicename");
                $tgfound = 1;
                last;
            }
        }
    }

    if ($tgfound == 1) {
        $logger->debug("<-- Leaving Sub [$servicename]");
        return $servicename;
    }
    else {
        $logger->debug("<-- Leaving Sub [$nil]");
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

=head3 SonusQA::MGW9000::MGW9000HELPER::getRPADSummary(<shelf>)

 Routine to retrieve Resource pad summary.

=over

=item Arguments

  Content -Scalar( shelf number)


=item Return

None

=item Example(s):

 $mgw9000Obj->getRPADSummary(1);

=back

=cut

#################################################
sub getRPADSummary {
#################################################
    my($self, $shelf) = @_;
    my $mycics = 0;
    my $subName = 'getRPADSummary()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving Resource PAD summary');
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
    $logger->debug('<-- Leaving Sub');
}


##################################################################################
# purpose: Retrieve  Redundancy group  Name
# Parameters    : shelf
# Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getRedungroupName(<shelf>)

 Routine to get Redundancy group  Name.

=over

=item Arguments

  Content -Scalar(hardware type)

=item Return

 scalar -redindancy group name (string)

=item Example(s):

 $mgw9000Obj->getRedungroupName("CNS");

=back

=cut

#################################################
sub getRedungroupName {
#################################################
    my($self, $type) = @_;
    my @arr =();
    my $subName = 'getRedungroupName()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving Redundancy summary');
    if($self->execFuncCall('showRedundancyGroupSummary')){
      foreach(@{$self->{CMDRESULTS}}){
        $logger->debug(" $_");
          if(m/$type/){
            @arr = split;
        }
      }
    }
    $logger->debug("<-- Leaving Sub [$arr[0]]");
    return $arr[0];
}


##################################################################################
# purpose: Configure  Redundancy group  Clients
# Parameters    : CNS card type or "all"
# Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::configCNSRedunclients(<shelf>)

 Routine to Configure  Redundancy group Clients .

=over

=item Arguments

 Content -Scalar(String)

=item Return

 None

=item Example(s):

 $mgw9000Obj->configCNSRedunclients("all");

=back

=cut


#################################################
sub configCNSRedunclients {
#################################################
    my($self, $type) = @_;
    my $server = my $redunserver = my $redgroup = '';
    my $i = 0;
    my $subName = 'configCNSRedunclients()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retrieving NIF Admin Information');
    if ($type eq 'all'){
        $server  = 'CNS';
    }else{
        $server = $type;
    }
    $self->getHWInventory(1);
    for ($i = 3; $i <= 16; $i++) {

        if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/CNA0/ ) {

            if ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/$server/) {

                $redunserver = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
                $redgroup = $self->getRedungroupName($redunserver);
                my $j = 0;

                for($j = 3; $j < $i; $j++) {
                    if($self->{'hw'}->{'1'}->{$j}->{'SERVER'} eq $redunserver ) {
                        $logger->debug(" $j");
                        $self->execFuncCall(
                                    'createRedundancyClientGroupSlot',
                                    {
                                        'redundancy client group' => $redgroup,
                                        'slot' => $j,
                                    },
                                );
                        $self->execFuncCall(
                                    'configureRedundancyClientGroupSlotState',
                                    {
                                        'redundancy client group' => $redgroup,
                                        'slot' => $j,
                                        'sonusRedundClientAdmnState' => 'enabled',
                                    },
                                );
                    }
                }
                $self->execFuncCall(
                            'configureRedundancyGroupState',
                            {
                                'redundancy group' => $redgroup,
                                'sonusRedundGroupAdmnState' => 'enabled',
                            },
                        );
            }
        }
    }

    $logger->debug('<-- Leaving Sub');
}


##################################################################################
# purpose: Get the slot number and type of card in the slot
# Parameters    : CNS, PNS or all
# Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getSlotinfo(<cardtype>)

 Routine to Configure  Redundancy group Clients .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Hash

=item Example(s):

 $mgw9000Obj->getSlotinfo("ALL");

=back

=cut


#################################################
sub getSlotinfo {
#################################################
    my($self, $type) = @_;
    my $i = 0;
    my $subName = 'getSlotinfo()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my @types = ();
    if($type eq 'ALL'){
        $type = '[A-Z]';
    }
    $self->getHWInventory(1);
    for ($i = 3; $i <= 16; $i++) {

        my $server = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
          my $adapter = $self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'};

          if ($server ne 'UNKNOWN' && $server =~m/$type/){
            if ($server =~m/SPS/){
                $adapter = 'NONE';
            }
            if ($adapter !~ m/CNA0/ && $adapter !~ m/UNKNOWN/) {
                      $logger->info(" server $server and adapter $adapter CARD FOUND IN SLOT $i");
                  push @types, ($i => [$server, $adapter]);
                }
          }
        }
    $logger->debug('<-- Leaving Sub');
    return @types;
}


##################################################################################
# purpose: Get the type of interface from the  adapter
# Parameters    : Adapter
# Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getInterfaceFromAdapter(<cardtype> <adapter>)

 Routine to Configure  Redundancy group Clients .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->getInterfaceFromAdapter("CNA30");

=back

=cut

#################################################
sub getInterfaceFromAdapter {
#################################################
 my ($self, $shelf,$adapter) = @_;
 my @InterfaceType;
 my $subName = 'getInterfaceFromAdapter()';
 my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
 $logger->debug('--> Entered Sub');

 switch ($adapter) {
      case "GNA15" { @InterfaceType = ('T1', 1, 12); }
      case "GNA10" { @InterfaceType = ('T1', 1, 12); }
      case "CNA10" { @InterfaceType = ('T1', 1, 12); }
      case "CNA30" { @InterfaceType = ('T3', 1, 28); }
      case "CNA60" { @InterfaceType = ('T3', 3, 28); }
      case "CNA70" { @InterfaceType = ('OPTICAL',1, 84); }
      else {
          $logger->debug("  $adapter CARD NOT FOUND");
      }
  }
  $logger->debug('<-- Leaving Sub');
  return @InterfaceType;
}


##################################################################################
# purpose: Get the get number of circuits based on adapter slot nr
# Parameters    : Adapter
# Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getAdapterCircuitNr(<slot>))

 Routine to Configure  Redundancy group Clients .

=over

=item Arguments

 Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $mgw9000Obj->getAdapterCircuitNr(5);

=back

=cut

#################################################
sub getAdapterCircuitNr {
#################################################

  my($self,$adapter) = @_;
  my $i = 0;
  my $j = 0;
  my $subName = 'getAdapterCircuitNr()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug('--> Entered Sub');

  my $circuits = 0;
  my @interface;

  @interface = $self->getInterfaceFromAdapter(1,$adapter);

  for ($i = 0; $i < $interface[1]; $i++) {
   for ($j = 0; $j < $interface[2]; $j++) {
     $circuits = $circuits + 24;
   }
 }
 $logger->debug(" number of circuits $circuits");

  $logger->debug("<-- Leaving Sub [$circuits]");
  return $circuits;
}


##################################################################################
# purpose:
# Parameters    :
# Return Values :
#
##################################################################################

=pod

=head3 sourceTclFileFromNFS()

 Executes a tcl file in the mgw9000 and checks for a completion string "SUCCESS".If string is present ,then this subroutine returns 1.For this method to return 1 on successful completion , include (puts "SUCCESS") at the end of the tcl script which u need to execute and remove the word "SUCCESS" if present in other parts of the tcl file.

=over

=item Assumption :

 It is assumed that NFS is mounted on the machine from where this method is invoked.

=item Arguments :

 -tcl_file
    name of the tcl file
 -location
   directory location where the tcl file is present
 -mgw_hostname
   specify the hostname of the mgw9000
 -nfs_mount
   specify the NFS mount directory -default is /sonus/SonusNFS

=item Return Values :

 1 - success ,when tcl file is executed without errors and end tag "SUCCESS" is reached
 0 - failure , error occurs during execution or inputs are not specified or copy of file failed

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::sourceTclFileFromNFS(-tcl_file => "ansi_cs.tcl",-location => "/userhome/ats/feature/mgw_files",-mgw_hostname => "VIPER");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub sourceTclFileFromNFS {
#################################################

    my($self,%args) = @_;
    my $subName = 'sourceTclFileFromNFS()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');


    my $tcl_file = $args{-tcl_file};
    my $location = $args{-location};
    my $mgw = uc($args{-mgw_hostname});

    my $nfs_mount = '/sonus/SonusNFS';
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error("Directory $nfs_mount (defined in MGW9000HELPER.pm::".__PACKAGE__ . ") does not exist");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if tcl_file is not set
    unless (defined $tcl_file && $tcl_file !~ /^\s*$/ ) {

        $logger->error('tcl file is not specified or is blank');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if location is not specified
    unless (defined $location && $location !~ /^\s*$/ ) {

        $logger->error('location is not specified or is blank');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if mgw9000 hostname is not specified
    unless (defined $mgw && $mgw !~ /^s*$/ ) {

        $logger->error('mgw9000 hostname is not specified or is blank');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Set "From path"
    my $from_path = $location . '/' . $tcl_file;
    $logger->debug("From Path is $from_path");

    # Set "To Path" ie NFS
    my $to_path = "$nfs_mount\/$mgw\/cli\/scripts";
    $logger->debug("To Path is $to_path");

    # Copy file from "From Path" to "To Path"
#    if ( system('/bin/cp',"-f","$from_path","$to_path")) {
    if ( system('/bin/cp -f' . "$from_path" . ' ' . "$to_path")) {

        $logger->error("Copy failed from $from_path to $to_path");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    else {

        $logger->debug("Copy was successful from $from_path to $to_path");

        my $cmd = "source ..\/$mgw\/cli\/scripts\/$tcl_file";

        # Source the tcl file in MGW9000
        my $default_timeout = $self->{DEFAULTTIMEOUT};
        $self->{DEFAULTTIMEOUT} = 400;
        my @cmdresults = $self->execCmd($cmd);
        $self->{DEFAULTTIMEOUT} = $default_timeout;
        $logger->debug("@cmdresults");

        foreach(@cmdresults) {

            chomp($_);
            # Checking for SUCCESS tag

            if (m/^SUCCESS/) {
                $logger->debug("CMD RESULT: $_");

                # Remove the tcl file from NFS directory
                if ($location ne "$nfs_mount\/$mgw\/cli\/scripts") {
                    if (system("rm -rf $nfs_mount\/$mgw\/cli\/scripts\/$tcl_file")) {
                        $logger->error("Remove failed for $nfs_mount\/$mgw\/cli/scripts\/$tcl_file");
                        $logger->debug('<-- Leaving Sub [0]');
                        return 0;
                    }
                    $logger->debug("Removed $tcl_file in $nfs_mount\/$mgw\/cli\/scripts");
                }

                $logger->debug("Successfully sourced MGW9000 TCL file: $tcl_file");
                $logger->debug('<-- Leaving Sub [1]');
                return 1;
            }
            elsif (m/^error/) {
                unless (m/^error: Unrecognized input \'3\'.  Expected one of: VERSION3 VERSION4/) {
                    $logger->error("Error occurred during execution : $_");
                    $logger->debug('<-- Leaving Sub [0]');
                    return 0;
                }
            }

        } # End foreach

        # If we get here, script has not been successful
        $logger->error("SUCCESS string not found, nor error string. Unknown failure.");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
}

#########################################################################################################

=pod

=head3 getM3UAGateway()

 Checks the M3UA gateway status in MGW9000 and reports on the status of host specified.This functions is only for M3UA links and will not work for Client Server connections.

=over

=item Arguments :

 -sgx_hostname
     specify sgx hostname for which we need to check m3ua status

=item Return Values :

 State of the Host - Host specified is found in the command result and state is returned
 0 - Failure ,no hostname specified or command execution returns no gateway or if specified host is not found in command result

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::getM3UAGateway(-sgx_hostname => "calvin");

=item Notes:

 Executes "SHOW SS7 GATEWAY ALL STATUS" and checks for state for specified hostname.

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub getM3UAGateway {
#################################################

    my ($self,%args) = @_;
    my $subName = 'getM3UAGateway()';
    my $cmd = 'SHOW SS7 GATEWAY ALL STATUS';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');


    my $sgx_hostname = $args{-sgx_hostname};

    # Error if sgx hostname not set
    if (!defined $sgx_hostname) {
        $logger->error('Hostname is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $logger->debug('Retrieving MGW9000 SS7 Gateway ALL status');

    # Execute TCL command on MGW9000
    if ($self->execCmd($cmd)) {

        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);
            # Error if error string returned
            if (m/^error/i) {
                $logger->error("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }

            # Match sgx hostname name from gateway status output from MGW9000
            if ($_ =~ m/.*($sgx_hostname)\s+(\d+).(\d+)\s(\d+).(\d+)\s(\d+).(\d+).(\d+).(\d+)\s+(\w+)/i) {

                $logger->debug("State of Host $1 is $10");

                my $state = $10;
                # Return current status of host
                $logger->debug("<-- Leaving Sub [$state]");
                return $state;
            }
        } # End foreach
        $logger->error("Host specified $sgx_hostname is not found in CMD RESULT");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
} # End sub getM3UAGateway

#########################################################################################################

=pod

=head3 checkM3UAGateway()

 Checks if M3UAGateway is in specified state and returns 1 if state matches.

=over

=item Arguments :

 -sgx_hostname
 -state
  specify state of the association - example - ASPUP

=item Return Values :

 1 - Success
 0 - Failure

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::checkM3UAGateway(-sgx_hostname => "calvin",-state => "ASPUP");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub checkM3UAGateway {
#################################################
    my($self,%args) = @_;
    my $subName = 'checkM3UAGateway()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $sgx_hostname = undef;
    my $state = undef;

    $sgx_hostname = $args{-sgx_hostname};
    $state = $args{-state};

    # Error if sgx hostname not set
    if (!defined $sgx_hostname) {
        $logger->error('Hostname is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if state not set
    if (!defined $state) {
        $logger->error('State is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $result = $self->SonusQA::MGW9000::MGW9000HELPER::getM3UAGateway('-sgx_hostname' => 'calvin','-state' => "ASPUP");

    if ($result =~ /$state/) {
        $logger->debug("Host $sgx_hostname is in specified state $state");
        $logger->debug('<-- Leaving Sub [1]');
        return 1;
    }
    else {
        $logger->error("Host $sgx_hostname is not in specified state $state");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    } # End if

} # End sub checkM3UAGateway

#########################################################################################################

=pod

=head3 getSS7GatewayLink()

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

  \$obj->SonusQA::MGW9000::MGW9000HELPER::getSS7GatewayLink(-sgx_ip => "10.31.240.7",-node_name => "a7n1");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub getSS7GatewayLink {
#################################################
    my($self,%args) = @_;
    my $subName = 'getSS7GatewayLink()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my @retvalues;

    my $node = $args{-node_name};
    my $sgx_ip = $args{-sgx_ip};

    # Error if sgx ip not set
    unless ($sgx_ip) {
        $logger->error('SGX ip is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if node name not set
    unless ($node) {
        $logger->error('Node Name is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $cmd = "SHOW SS7 NODE $node STATUS";
    $logger->debug("Retrieving MGW9000 SS7 NODE $node STATUS");

    # Execute TCL command on MGW9000
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }

            # Match sgx ip from node status output from MGW9000
            if ($_ =~ m/.*($sgx_ip)\s+(\w+)\s+(\w+)/) {

                my $state = $2;
                my $mode = $3;
                $logger->debug("Link State of Host $1 is $state");
                $logger->debug("Link mode of Host $1 is $mode");

                # Return current status and mode of host
                push @retvalues,$state;
                push @retvalues,$mode;
                $logger->debug('<-- Leaving Sub [1]');
                return @retvalues;
            }
        } # End foreach
        $logger->error("Host specified $sgx_ip is not found in CMD RESULT");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
} # End sub getSS7GatewayLink

#########################################################################################################

=pod

=head3 checkSS7GatewayLink()

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

 \$obj->SonusQA::MGW9000::MGW9000HELPER::checkSS7GatewayLink(-sgx_ip => "10.31.240.7",-node_name => "a7n1",-link_state => "AVAILABLE",-link_mode => "ACTIVE");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub checkSS7GatewayLink {
#################################################

    my($self,%args) = @_;
    my $subName = 'checkSS7GatewayLink()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

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
        $logger->error('SGX ip is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if node name not set
    if (!defined $node) {
        $logger->error('Node Name is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if link_state not set
    if (!defined $link_state) {
        $logger->error('Link State is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if link_mode not set
    if (!defined $link_mode) {
        $logger->error('Link Mode is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my @values = $self->SonusQA::MGW9000::MGW9000HELPER::getSS7GatewayLink(-sgx_ip => $sgx_ip,-node_name => $node);

    if ($values[0] =~ /$link_state/) {
        $logger->debug("Link state is $link_state");
    }
    else {
        $logger->error("Link state is not $link_state");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    } # End if

    if ($values[1] =~ /$link_mode/) {
        $logger->debug("Link mode is $link_mode");
    }
    else {
        $logger->error("Link mode is not $link_mode");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    } # End if
    $logger->debug('<-- Leaving Sub [1]');
    return 1;

} # End sub checkSS7GatewayLink

#########################################################################################################

=pod

=head3 getSpecifiedIsupServiceState()

 Checks for the status of isup service in mgw9000 and returns the state.

=over

=item Arguments :

 -service_name

=item Return Values :

 State of the isup service  - Service name specified is found in the command result
 0 - Failure ,no service name specified or command execution returns no status or if specified service is not found in command result

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::getSpecifiedIsupServiceState(-service_name => "ss71");

=item Notes:

 Executes the command "SHOW ISUP SERVICE <service-name> STATUS" and checks if status is available

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub getSpecifiedIsupServiceState {
#################################################

    my($self,%args) = @_;
    my $subName = 'getSpecifiedIsupServiceState()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $service = undef;

    $service = $args{-service_name};

    # Error if service_name not set
    if (!defined $service) {

        $logger->error("service name is not specified");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $cmd = "SHOW ISUP SERVICE $service STATUS";
    $logger->debug("Retrieving MGW9000 ISUP SERVICE $service STATUS");

    # Execute TCL command on MGW9000
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }

            # Match service name in command output from MGW9000
            if ($_ =~ m/.*($service)\s+(\d+)-(\d+)-(\d+)\s+(\w+)/i) {

                $logger->debug("State of service $1 is $5");

                my $state = $5;
                # Return current status of service
                $logger->debug("<-- Leaving Sub [$state]");
                return $state;
            }

        } # End foreach
        $logger->error("Service specified $service is not found in CMD RESULT");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
} # End sub getSpecifiedIsupServiceState

#########################################################################################################

=pod

=head3 checkSpecifiedIsupServiceState()

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

 \$obj->SonusQA::MGW9000::MGW9000HELPER::checkSpecifiedIsupServiceState(-service_name => "SS71",-state => "AVAILABLE");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub checkSpecifiedIsupServiceState {
#################################################

    my($self,%args) = @_;
    my $subName = 'checkSpecifiedIsupServiceState()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $service = undef;
    my $state = undef;

    $state = uc($args{-state});
    $service = $args{-service_name};

    # Error if service_name not set
    if (!defined $service) {
        $logger->error('service name is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if state not set
    if (!defined $state) {
        $logger->error('state is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $result = $self->SonusQA::MGW9000::MGW9000HELPER::getSpecifiedIsupServiceState(-service_name => $service);

    if ($result =~ /$state/) {
        $logger->debug("ISUP Service state is $state");
        $logger->debug('<-- Leaving Sub [1]');
        return 1;
    }
    else {
        $logger->debug("ISUP Service state is not $state");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    } # End if
} # End sub checkSpecifiedIsupServiceState

#########################################################################################################

=pod

=head3 cnsIsupSgDebugSetMask()

   This function sets the mask of a cns card using the isupsgdebug command with options -s for slot and -m for mask.
Value 256 for mask stops the card from responding and 0 restores the card to respond.

=over

=item Arguments :

 -cns_slot
 -mask
    256 - stop the card from responding
    0 - restore the card to continue responding

=item Return Values :

 1-Success if prompt returned
 0-Failure if error message has been printed on executing the debug command or cns_state not specified or cns_slot not specified or cns_state specified is invalid(other than 0 or 1)

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::cnsIsupSgDebugSetMask(-cns_slot => 2,-mask => 0);

=item Notes :

 Executes the following commands in mgw9000 to stop the card from responding
 %admin debugSonus
 %isupsgdebug -s <cns_slot> -m 256
 Executes the following commands in mgw9000 to restore the card
 %admin debugSonus
 %isupsgdebug -s <cns_slot> -m 0

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub cnsIsupSgDebugSetMask {
#################################################

    my($self,%args) = @_;
    my($string);
    my $subName = 'cnsIsupSgDebugSetMask()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $cns_slot = undef;
    my $mask = undef;

    $cns_slot = $args{-cns_slot};
    $mask = $args{-mask};

    # Error if cns_slot not set
    if (!defined $cns_slot) {

        $logger->error('cns_slot is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if cns_state not set
    if (!defined $mask) {

        $logger->error('mask is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Check for mask value and error if not 256 or 0
    if ($mask !~ /(256|0)/) {
        $logger->error("mask $mask is invalid");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $cmd = 'admin debugSonus';
    $logger->debug("Executing admin debugSonus");

    my @cmdresults = $self->execCmd($cmd);

    foreach(@cmdresults) {

        chomp($_);

        # Error if error string returned
        if (m/^error/i) {
            $logger->error("CMD RESULT: $_");
            $logger->debug('<-- Leaving Sub [0]');
            return 0;
        }

    } # End foreach

    # debug command is prepared
    $cmd = "isupsgdebug -s $cns_slot -m $mask";
    $string = "isupsgdebug command for slot $cns_slot changes state to $mask";

    $logger->debug("Executing $cmd");

    @cmdresults = $self->execCmd($cmd);

    foreach(@cmdresults) {

        chomp($_);

        # Error if error string returned
        if (m/^error/i) {
            $logger->error("CMD RESULT: $_");
            $logger->debug('<-- Leaving Sub [0]');
            return 0;
        }

    } # End foreach

    $logger->info("$string");
    $logger->debug('<-- Leaving Sub [1]');
    return 1;

} # End sub cnsIsupSgDebugSetMask

#########################################################################################################

=pod

=head3 switchoverSlot()

 This method performs switchover of MGW9000 cards (CNS or MNS) and reverts based on the slot state.The mandatory parameters are red_group and slot.Default value for wait_for_switch is 1,meaning the function will wait for the switchover to get completed and then report on final slot state.But if we want to exit the function immediately after switchover command is issued,we can specify wait_for_switch as 0.We can use the function getProtectedSlotState in the test script to check for the slot state and use this function again to restore the slot state.

=over

=item Arguments :

 -red_group
    specify the cns/mns redundancy group for which switchover /revert switchover needs to be done
 -slot
    specify the slot number of the card
 -wait_for_switch
    If we need to wait for the switchover to get completed ,then specfify -wait_for_switch => 1, else specify -wait_for_switch => 0.When this flag is 0 , the switchover command will be issued and then subroutine will exit.
 -mode
    If we need to do forced switchover or revert then specify -mode => forced else default will be normal

=item Return Values :

 1 -Success if card state is STANDBY after switchover and ACTIVESYNCED after revert if -wait_for_switch => 1.If -wait_for_switch => 0, then return 1 if client state is RESET
 0 -Failure if command execution fails or inputs not specified

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::switchoverSlot(-red_group => "cns60",-cns_slot => 2,-wait_for_switch => 1);

=item Notes :

 "CONFIGURE REDUNDANCY GROUP <redgroup> SWITCHOVER CLIENT SLOT <slot>" command is executed to perform the switchover.Then "SHOW REDUNDANCY GROUP <cns_redgroup> SLOT <cns_slot>" command is used to check the status of the slot.CONFIGURE REDUNDANCY GROUP <redgroup> REVERT FORCED is used to revert the switchover.If it is mns switchover , after issuing the switchover command , we will lose the connection,so we will exit this subroutine.So it is advised to check for status of the slot in the test script which calls this function.

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub switchoverSlot {
#################################################

    my($self,%args) = @_;
    my $subName = 'switchoverSlot()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

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

        $logger->error('redundancy group is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if slot is not set or if not in range of 1 to 16
    if (!defined $slot) {

        $logger->error('slot is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    elsif (($slot < 1) || ($slot > 16)) {
        $logger->error('Slot number specified is not in range of 1 to 16');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Fetch slot state using getProtectedSlotState
    my $slotstate = $self->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState('-slot' => $slot,'-red_group' => $red_group);

    # Set revert flag based on slot state
    if ($slotstate eq 'STANDBY') {
        $revert = 1;
        $logger->info(' Slot State is STANDBY,so revert will be done');
    }
    elsif ($slotstate eq 'ACTIVESYNCED') {
        $revert = 0;
        $logger->info(' Slot State is ACTIVESYNCED,so switchover will be done');
    }
    elsif ($slotstate eq 'ACTIVENOTSYNCED') {
        $logger->error(' Slot State is ACTIVENOTSYNCED,so switchover is not possible');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    elsif ($slotstate eq 'RESET') {
        $logger->error(' Slot State is RESET,so switchover is not possible');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    else {
        $logger->error(' Invalid slot state ,so switchover is not possible');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if wait_for_switch is not specified or if value is not 0 or 1
    if (!defined $wait) {

        $logger->error(' wait_for_switch is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    elsif (($wait ne 0) && ($wait ne 1)) {
        $logger->error(' Value for wait_for_switch is invalid , set to 0 or 1');
        $logger->debug('<-- Leaving Sub [0]');
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
                $logger->debug("$_");
                # Error if error string returned
                if (m/^error/i) {
                    $logger->error("CMD RESULT: $_");
                    $logger->debug('<-- Leaving Sub [0]');
                    return 0;
                }
            }  # End foreach
        } # Endif

        if ($wait eq 1) {
            my $timeout = 180;

            while ($timeout >= 0 ) {
                my $slotstate = $self->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState('-slot' => $slot,'-red_group' => $red_group);
                if ($slotstate eq 'STANDBY') {
                    $logger->info(" State of slot $slot is $slotstate, Switchover was successful");
                    $logger->debug('<-- Leaving Sub [1]');
                    return 1;
                }
                sleep(45);
                $timeout = $timeout - 45;
            } # End while for timeout

            $logger->error(' Timeout occurred switchover not complete');
            $logger->debug('<-- Leaving Sub [0]');
            return 0;

        } # End if for wait eq 1
        elsif ($wait eq 0) {

            # Check for status
            my $slotstate = $self->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState('-slot' => $slot, '-red_group' => $red_group);
            if ($slotstate eq 'RESET') {
                $logger->info("State of slot $slot is $slotstate");
                $logger->debug('<-- Leaving Sub [1]');
                return 1;
            }
        } # End if for wait 0
    } # End if for revert eq 0

    elsif ($revert eq 1) {

        $cmd = "CONFIGURE REDUNDANCY GROUP $red_group REVERT $mode";

        if($self->execCmd($cmd)) {
            foreach(@{$self->{CMDRESULTS}}) {

                chomp($_);
                $logger->debug("$_");
                # Error if error string returned
                if (m/^error/i) {
                    $logger->error("CMD RESULT: $_");
                    $logger->debug('<-- Leaving Sub [0]');
                    return 0;
                }
            } # End foreach
        }

        if ($wait eq 1) {
            my $timeout = 180;

            while ($timeout >= 0) {
                my $slotstate = $self->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState('-slot' => $slot,'-red_group' => $red_group);
                if ($slotstate eq 'ACTIVESYNCED') {
                    $logger->info("State of slot $slot is $slotstate, Revert was successful");
                    $logger->debug('<-- Leaving Sub [1]');
                    return 1;
                }
                sleep(45);
                $timeout = $timeout - 45;
            } # End while

            $logger->error(' Timeout occurred Revert not complete');
            $logger->debug('<-- Leaving Sub [0]');
            return 0;

        } # End if for wait eq 1
        elsif ($wait eq 0) {
            # Check for status
            sleep(3); # Wait for status change since sometimes it does not happen immediately
            my $slotstate = $self->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState(-slot => $slot,-red_group => $red_group);
            if ($slotstate =~ /ACTIVENOTSYNCED/) {
                $logger->info("State of slot $slot is $slotstate");
                $logger->debug('<-- Leaving Sub [1]');
                return 1;
            }

        } # End if for wait 0
    }   # End elsif for revert=1

$logger->error(' Switchover was not successful');
$logger->debug('<-- Leaving Sub [0]');
return 0;

} # End sub switchoverSlot

#########################################################################################################

=pod

=head3 checkCicsState()

 Checks the cic status for the specified cic range and reports success if cics are in specified state and failure if cics are not in specified state.service,cic_start and cic_end are mandatory.

=over

=item Arguments :

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

=item Return Values :

 1 - Success , when cic specified are matching the state specified
 0 - Failure , when cic specified are not matching the state specified - Prints error message stating why failure is reported - or execCmd failed.
 -1 - If CIC does not exist

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::checkCicsState(-service => "SS71",-cic_start => "2",-cic_end => "13",-ckt_state => "IDLE",-hw_lstate => "UNBLK", -hw_rstate => "UNBLK", -maint_lstate => "UNBLK", -maint_rstate => "UNBLK");

=item Notes :

 Executes the following command
 SHOW ISUP CIRCUIT SERVICE <service name specified> CIC <cic range specified> STATUS

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub checkCicsState {
#################################################

    my($self,%args) = @_;
    my($string);
    my $subName = 'checkCicsState()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($i,$cmd,$flag,$cmd_result);

    # Initialise states if user does not specify any state specific values
    my $ckt_state    = 'IDLE';
    my $hw_lstate    = 'UNBLK';
    my $hw_rstate    = 'UNBLK';
    my $maint_lstate = 'UNBLK';
    my $maint_rstate = 'UNBLK';
    my $cot_state    = 'N/A';
    my $admin_mode   = 'UNBLOCK';
    my $servicetype  = 'ISUP';

    # Check if service,cic_start and cic_end are specified if not return 0
    foreach (qw/ -service -cic_start -cic_end/) {
        unless ( $args{$_} ) {
            $logger->error("$_ required");
            return 0;
        }
    }

    # Check if cic_start is lesser than cic_end and error otherwise
    if ($args{-cic_start} > $args{-cic_end}) {
        $logger->error(' CIC Range specified is incorrect');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Read user inputs for the different states if specified
    $ckt_state = uc($args{'-ckt_state'}) if $args{'-ckt_state'};
    $hw_lstate = uc($args{'-hw_lstate'}) if $args{'-hw_lstate'};
    $hw_rstate = uc($args{'-hw_rstate'}) if $args{'-hw_rstate'};
    $maint_lstate = uc($args{'-maint_lstate'}) if $args{'-maint_lstate'};
    $maint_rstate = uc($args{'-maint_rstate'}) if $args{'-maint_rstate'};
    $cot_state = uc($args{'-cot_state'}) if $args{'-cot_state'};
    $admin_mode = uc($args{'-admin_mode'}) if $args{'-admin_mode'};
    $servicetype = uc($args{'-servicetype'}) if $args{'-servicetype'};

    my $failcics = 0;


    # Command to be executed in MGW9000
    $cmd = "SHOW $servicetype CIRCUIT SERVICE $args{'-service'} CIC $args{'-cic_start'}-$args{'-cic_end'} STATUS";
    unless ($self->execCmd($cmd)) {
        $logger->error(" Unable to execute command \'$cmd\'");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    $flag = 0; # Assume cic states are not matching the user specified states

    for ($i = $args{'-cic_start'}; $i <= $args{'-cic_end'}; $i++) {

        LINE: foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->debug("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }

            if(m/^($i)/) {
                # We found our cic
                $cmd_result = $_;
                # Extract cic status , hw status and maint status from command output from MGW9000
                if ($_ =~ m/^($i)\s+(\w+)\s+(\d+)\s+($ckt_state)\s+($admin_mode)\s+($maint_lstate)\s+($maint_rstate)\s+($hw_lstate)\s+($hw_rstate)\s+($cot_state)/) {
                    $flag = 1;
                }
                elsif ($_ =~ m/^\s+N\/A\s+N\/A\s+N\/A\s+N\/A\s+N\/A\s+N\/A/) {
                    $logger->error(' CIC $i does not exist');
                    $logger->debug('<-- Leaving Sub [-1]');
                    return -1;
                }
                # Break out of the foreach LINE loop.
                last LINE;
            }
        } # End foreach

        # Return 0 if circuit state does not match specified states.
        if ($flag == 0) {

            $logger->error(" Circuit State for CIC $i does not match with specified circuit state");
            $logger->error(" The state of CIC $i is \n $cmd_result");
            $failcics++;
        }

    } # End for loop for cic range

    if ($failcics > 0) {
        $logger->error(" $failcics CICS dont match with specified circuit state");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $logger->debug(' Cics are in specified states');
    $logger->debug('<-- Leaving Sub [1]');
    return 1;

} # End sub checkCicsState

#########################################################################################################

=pod

=head3 getProtectedSlotState ()

 This method returns the state of the protected slot from "SHOW REDUNDANCY GROUP <red group> STATUS" command output.

=over

=item Arguments :

 -red_group
    specify the cns/mns redundancy group
 -slot
    specify the slot number of the protected cns/mns card

=item Return Values :

 State of the card - Success
 0 - Inputs not specified , card specified not found in output, command error

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::getProtectedSlotState(-red_group => "cns60",-cns_slot => 6);

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub getProtectedSlotState {
#################################################

    my($self,%args) = @_;
    my $subName = 'getProtectedSlotState()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $cmd;

    my $red_group = undef;
    my $slot = undef;

    $red_group = $args{-red_group};
    $slot = $args{-slot};

    # Error if red_group is not set
    if (!defined $red_group) {

        $logger->error(' redundancy group is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if slot is not set or if not in range of 1 to 16
    if (!defined $slot) {

        $logger->error(' slot is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    elsif (($slot < 1) || ($slot > 16)) {
        $logger->error(" Slot number $slot specified is not in range of 1 to 16");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $cmd = "SHOW REDUNDANCY GROUP $red_group STATUS";

    if($self->execCmd($cmd)) {

        $logger->debug(" Retrieving slot state for card $slot");

        # Wait for command result
        sleep(10);

        foreach(@{$self->{CMDRESULTS}}) {
            chomp($_);
            # Error if error string returned
            if (m/^error/i) {
                $logger->error(" CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }

            # Check for status

            if (($_ =~ m/.*($slot)\s+(\w+)/) && ($_ !~ m/Date/)) {
                $logger->debug(" State of slot $1 is $2");
                my $state = $2;
                $logger->debug("<-- Leaving Sub [$state]");
                return $state;
            }
        } # End foreach
    }
    $logger->error(" Commmand execution of $cmd was not successful");
    $logger->debug('<-- Leaving Sub [0]');
    return 0;
} # End sub getProtectedSlotState

#########################################################################################################

=pod

=head3 logStart()

 logStart method is used to start capture of logs per testcase in MGW9000.ACT/SYS/DBG/TRC logs are captured.The name of the log file will be of the format <Testcase-id>_MGW9000<ACT/DBG/SYS/TRC>_<MGW9000 hostname>_timestamp.log.Timestamp will be of format yyyymmdd_HH:MM:SS.log
The mandatory arguments are test_case ,hostname.Default for NFS mount directory will be "/sonus/SonusNFS".After using logStart , use logStop function in the test script to kill the processes.

=over

=item NOTE :

 The logs in ACT folder in NFS needs to be cleared by the test script since roll file does not happen for ACT folder.

=item Assumptions made :

 It is assumed that NFS is mounted on the machine from where we run the test script which invokes this function.If NFS is not mounted ,please mount it and then start the test script.

=item Arguments :

 -test_case
     specify testcase id for which log needs to be generated.
 -host_name
     specify the sgx/mgw hostname
 -nfs_mount
     specify the NFS mount directory,default is /sonus/SonusNFS
 -log_dir
     specify the logs directory where logs will be locally stored without ending with / - example - "/home/test/Logs"

=item Return Values :

 Array of pid in the order ACT,DBG,SYS,TRC followed by filesnames of log files -Success
 0-Failure

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::logStart(-test_case => "15804",-host_name => "VIPER",-nfs_mount => "/sonusNFS",-log_dir => "/home/test2/Logs");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub logStart {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $subName = 'logStart()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my (@split,$pid,@result,@retvalues,$cmd,@dbg_file,$rest_of_result);
    my $nfs_mount = '/sonus/SonusNFS';

    $logger->debug('Entering function');

    my $id = `id -un`;
    chomp($id);

    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -test_case -host_name -log_dir/) {
      unless ($args{$_} ) {
        $logger->error("$_ required");
        $logger->debug('Leaving function retcode-0');
        return 0;
      }
    }

    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});
    $args{-host_name} = uc($args{-host_name});
    $nfs_mount = "$nfs_mount" . '/' . $args{-host_name};

    $logger->debug(" Starting Logs for testcase $args{'-test_case'} in $nfs_mount");

    # Prepare timestamp format
    my $timestamp = `date \'\+\%F\_\%H\:\%M\:\%S\'`;
    chomp($timestamp);

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(" Directory $nfs_mount does not exist");
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    # Test if $args{-log_dir} exists
    if (!(-e $args{-log_dir})) {
        $logger->error(" Directory $args{-logdir} does not exist");
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    # Clear ACT logs folder
    if (system("rm -f $nfs_mount\/evlog\/*\/ACT\/*.ACT")) {
        $logger->error(' Unable to remove ACT logs');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    $cmd = 'CONFIGURE EVENT LOG ALL ROLLFILE NOW';

    # Execute TCL command on MGW9000 for rollfile
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(" CMD RESULT: $_");
                $logger->debug('Leaving function retcode-0');
                return 0;
            }
        } # End foreach
    }

    # Execute TCL command on MGW9000 for getting trace files in log folder
    $cmd = 'CONFIGURE EVENT LOG TRACE SAVETO BOTH';
    if ($self->execCmd($cmd)) {
        foreach(@{$self->{CMDRESULTS}}) {

            chomp($_);

            # Error if error string returned
            if (m/^error/i) {
                $logger->error(" CMD RESULT: $_");
                $logger->debug('Leaving function retcode-0');
                return 0;
            }
        } # End foreach
    }

    # Start xtail for ACT file and push pid into @retvalues
    my $actlogfile = join '_',$args{-test_case},'MGW9000','ACT',$args{-host_name},$timestamp;
    $actlogfile = join '.',$actlogfile,'log';

    if (system('/ats/bin/xtail $nfs_mount/evlog/*/ACT/* > ' . "$args{-log_dir}\/$actlogfile \&")) {
        $logger->error(' Unable to Start ACT logs');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }
    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep ACT | grep -v grep`;
        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(" Started xtail for ACT log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    # Start xtail for DBG file and push pid into @retvalues
    my $dbglogfile = join '_',$args{-test_case},'MGW9000','DBG',$args{-host_name},$timestamp;
    $dbglogfile = join '.',$dbglogfile,'log';

    if (system('/ats/bin/xtail $nfs_mount/evlog/*/DBG/* > ' . "$args{-log_dir}\/$dbglogfile \&")) {
        $logger->error(' Unable to Start DBG logs');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }
    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep DBG | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(" Started xtail for DBG log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    # Start xtail for SYS file and push pid into @retvalues
    my $syslogfile = join '_',$args{-test_case},'MGW9000','SYS',$args{-host_name},$timestamp;
    $syslogfile = join '.',$syslogfile,'log';

    if (system('/ats/bin/xtail $nfs_mount/evlog/*/SYS/* > ' . "$args{-log_dir}\/$syslogfile \&")) {
        $logger->error(' Unable to start SYS logs');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep SYS | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(" Started xtail for SYS log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    # Start xtail for TRC file and push pid into @retvalues
    my $trclogfile = join '_',$args{-test_case},'MGW9000','TRC',$args{-host_name},$timestamp;
    $trclogfile = join '.',$trclogfile,'log';

    if (system('/ats/bin/xtail $nfs_mount/evlog/*/TRC/* > ' . "$args{-log_dir}\/$trclogfile \&")) {
        $logger->error(' Unable to start TRC logs');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    else {
        @result = `ps -eo \"%p %U %a\" | grep $id | grep TRC  | grep -v grep`;

        # Get the process id of the last created process and push into @retvalues
        foreach (@result) {
            $_ =~ s/^\s+//;
            ($pid,$rest_of_result) = split(/\s/,$_,2);
        }
        $logger->debug(" Started xtail for TRC log - process id is $pid");
        push @retvalues,$pid;
    } # End if

    push @retvalues,$actlogfile;
    push @retvalues,$dbglogfile;
    push @retvalues,$syslogfile;
    push @retvalues,$trclogfile;

    $logger->debug(" Return Values - @retvalues");
    $logger->debug('Leaving function');
    return @retvalues;

} # End sub logStart()

#########################################################################################################

=pod

=head3 logStop()

 logStop method is used to kill the xtail processes started by logStart.
The mandatory argument is process_list.

=over

=item Arguments :
 -process_list
    List of processes seperated by comma

=item Return Values :

 1-Success
 0-Failure

=item Example :

 \$obj->SonusQA::MGW9000::MGW9000HELPER::logStop(-process_list => "24761,27567");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub logStop {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $subName = 'logStop()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $flag = 1; # Assume sub will return success

    # Check if process list is specified ,if not error
    if (!defined $args{'-process_list'}) {

        $logger->error('Process list is not specified');
        return 0;
    }

    # Kill processes specified in process list
    my @list = split /,/,$args{-process_list};

    foreach (@list) {
        if (system("kill $_")) {
            $logger->debug("Unable to kill process $_");
            $flag = 0;
        }
        else {
            $logger->debug("Killing process $_");
        }
    } # End foreach
    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
} # End sub logStop

#########################################################################################################

=pod

=head3 coreCheck()

 coreCheck checks for cores generated by MGW9000.The mandatory arguments are testcase,hostname of mgw.Cores in mgw9000 are checked if present in <mgwname>/coredump directory in NFS.When core is found ,it is renamed to testcase_core in same directory for future reference.

=over

=item Assumption :

 We assume that NFS is mounted on the machine from where this method is being called from.This function assumes that in coredump directory there are no files starting with "core".So if files are present starting with "core" ,please rename to filename which does not start with "core" before calling this function.

=item Arguments :

 -host_name
    specify hostname
 -test_case
 -nfs_mount
    specify the NFS mount directory - default is /sonus/SonusNFS

=item Return Values :

 Success - Number of cores found
 0 - Core not Found

=item Example :

 $res = $Mgw9000Obj->SonusQA::MGW9000::MGW9000HELPER::coreCheck(-host_name => "VIPER",-test_case => "17461");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub coreCheck {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $subName = 'coreCheck()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my @result;
    my $corecount = 0;

    # Error if testcase is not set
    if (!defined $args{'-test_case'}) {

        $logger->error('Test case is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Error if hostname is not set
    if (!defined $args{'-host_name'}) {

        $logger->error('Host name is not specified');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $nfs_mount = '/sonus/SonusNFS';
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error("Directory $nfs_mount does not exist");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    my $host = uc($args{-host_name});

    # Check if cores are present in $nfs_mount/$host/coredump/ directory
    my @cores = `ls  -1 $nfs_mount/$host/coredump/core*`;
    $logger->debug("@cores");
    my $numcore = $#cores + 1;

    if ($numcore eq 0) {
        $logger->info('No cores found');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    else {
        $logger->info("Number of cores in MGW9000 is $numcore");

        foreach (@cores) {

            my $core_timer = 0;
            chomp($_);
            my $file_name = $_;

            while ($core_timer < 120) {

                #start_size of the core file
                my $start_file_size = stat($file_name)->size;
                $logger->debug("Start File size of core is $start_file_size");

                sleep(5);
                $core_timer = $core_timer + 5;

                #end_size of the core file;
                my $end_file_size = stat($file_name)->size;
                $logger->debug("End File size of core is $end_file_size");

                if ($start_file_size == $end_file_size) {
                    $file_name =~ s/$nfs_mount\/$host\/coredump\///g;
                    my $name = join "_",$args{-test_case},$file_name;

                    # Rename the core to filename with testcase specified
                    my $res = `mv $nfs_mount/$host/coredump/$file_name $nfs_mount/$host/coredump/$name`;
                    $logger->info("Core found in $nfs_mount\/$host\/coredump\/$name");
                    last;
                }
            }
        }

        # Return the number of cores available
        $logger->debug("<-- Leaving Sub [$numcore]");
        return $numcore;
    }

} # End sub coreCheck

#########################################################################################################

=pod

=head3 removeCore()

 This functions removes core files starting with "core" in MGW9000 coredump directory.

=over

=item Arguments :

 -host_name
 -nfs_mount
   This is optional , default value will be /sonus/SonusNFS.If NFS directory is different ,please specify

=item Return Values :

 1- Success
 0 -Failure

=item Example :

 $res = $Mgw9000Obj->SonusQA::MGW9000::MGW9000HELPER::removeCore(-host_name => "VIPER");

=item Author :

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

#################################################
sub removeCore {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $subName = 'removeCore()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    # Error if hostname is not set
    if (!defined $args{-host_name}) {

        $logger->error('Host name is not specified');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    my $nfs_mount = '/sonus/SonusNFS';
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error('Directory $nfs_mount does not exist');
        $logger->debug('Leaving function retcode-0');
        return 0;
    }

    my $host = uc($args{-host_name});

    # Remove cores in $nfs_mount/$host/coredump/ directory
    my @result = `rm -f $nfs_mount/$host/coredump/core*`;

    # Check if cores are present in $nfs_mount/$host/coredump/ directory
    my @cores = `ls $nfs_mount/$host/coredump/core*`;
    my $numcore = $#cores + 1;

    if ($numcore eq 0) {

        $logger->info('No cores found');
        $logger->debug('Leaving function retcode-1');
        return 1;
    }
    else {
        $logger->info("Number of cores in MGW9000 is $numcore");
        $logger->debug('Leaving function retcode-0');
        return 0;
    } # End if
} # End sub removeCore

##################################################################################
#
#purpose: Populate a particular Input IP Filter's Admin values
#Parameters    : shelf, filtername
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getFilteradminvalues(<filtername>)

 Routine to Show the FilterAdminValues .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->getFilteradminvalues("Sec_Filter_1");

=back

=cut

#################################################
sub getFilteradminvalues {
#################################################
    my($self, $filtername) = @_;
    my $subName = 'getFilteradminvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving Input IP Filter Admin Information');
    $self->execFuncCall('showIpInputFilterAllAdmin');
    $self->getconfigvalues( $filtername, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular Output IP Filter's values
#Parameters    : shelf, filtername
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getOutputFiltervalues()

 Routine to Show the Ip Output filter Values .

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $mgw9000Obj->getOutputFiltervalues();

=back

=cut

#################################################
sub getOutputFiltervalues {
#################################################
    my($self, $filtername) = @_;
    my $subName = 'getOutputFiltervalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving Output IP Filter Admin Information');
    $self->execFuncCall('showIpOutputFilterAll');
    $self->getconfigvalues( $filtername, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}


##################################################################################
#
#purpose: Populate a particular Input IP Filter's status values
#Parameters    : shelf, filtername
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getFilterstatusvalues(<filtername>)

 Routine to Show the Ip Input Filter Status Values .

=over

=item Arguments

  Content -Scalar(String)

=item Return

 Array

=item Example(s):

 $mgw9000Obj->getFilterstatusvalues();

=back

=cut

#################################################
sub getFilterstatusvalues {
#################################################
    my($self, $filtername) = @_;
    my $subName = 'getFilterstatusvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving Input IP Filter Status Information');
    $self->execFuncCall('showIpInputFilterStatus', {'ip input filter' => $filtername});
    $self->getconfigvalues( $filtername, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular Session's Summary values
#Parameters    : shelf, nif
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getSessionsummvalues()

 Routine to Show the Security SSH Session Summary Values .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->getSessionsummvalues();

=back

=cut

#################################################
sub getSessionsummvalues {
#################################################
    my($self, $ip) = @_;
    my $subName = 'getSessionsummvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info('  Retrieving Session summary Information');
    $self->execFuncCall('showSecuritySshSessionSummary');
    $self->getconfigvalues( $ip, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: Populate a particular management nif's Admin values
#Parameters    : shelf, nif, slot, port
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getMgmtNIFadminvalues(<shelf>, <slot>, <port>)

 Routine to get the management NIF Admin Values .

=over

=item Arguments

  Content -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->getMgmtNIFadminvalues();

=back

=cut

#################################################
sub getMgmtNIFadminvalues {
#################################################
    my($self, $shelf, $slot, $port, $nif) = @_;
    my $subName = 'getMgmtNIFadminvalues()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $self->execFuncCall(
                'showMgmtNifShelfSlotPortAdmin',
                {
                    'mgmt nif shelf' => $shelf,
                    'slot'=> $slot,
                    'port'=> $port,
                },
            );
    $self->getconfigvalues( $nif, $self->getshowheader());
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: retrieve policer discard rate profile values for a policer
#Parameters    : discard rate profile, policer type
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getPolicerDRprof()

 Routine retrieve policer discard rate profile values for a policer .

=over

=item Arguments

   discard rate profile-Scalar(String)
   policer type-Scalar(String)

=item Return

  None

=item Example(s):

 $mgw9000Obj->getPolicerDRprof("AUTOPROF","Rogue Media Mid Call Bad Dest");

=back

=cut


#################################################
sub getPolicerDRprof {
#################################################
    my($self,$profile,$type) = @_;
    my $subName = 'getPolicerDRprof()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retreive Discard Rate Profile info');

    if ($self->execCmd("SHOW POLICER DISCARD RATE PROFILE $profile ADMIN")){
        foreach(@{$self->{CMDRESULTS}}) {
            if(m/State/){
                my @temp = split;
                $self->{$profile}->{state} = $temp[$#temp];
                $logger->debug("$temp[$#temp]");
            }
            if(m/^$type/){
                if (m/^(\w+\s*\w*\s*\w*\s*\w*\s*\w*\s*\w*\s+\:)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                    $logger->debug(" $_");

                    $self->{$profile}->{$type}->{SETTH}   = $2;
                    $self->{$profile}->{$type}->{CLEARTH} = $3;
                    $self->{$profile}->{$type}->{SETDU}   = $4;
                    $self->{$profile}->{$type}->{CLEARDU} = $5;
                }
            }
        }
    }
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: retrieve Policer system alarm status for a particular policer type
#Parameters    : policer type
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::getPolicerSysAlarmstatus()

 Routine to Show the Security SSH Session Summary Values.

=over

=item Arguments

  Policer type -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->getPolicerAlarmstatus("White");

=back

=cut

#################################################
sub getPolicerSysAlarmstatus {
#################################################
    my($self,$type) = @_;
    my $subName = 'getPolicerSysAlarmstatus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' Retreive Discard Rate Profile info');

    if ($self->execCmd('SHOW POLICER ALARM SYSTEM ALL STATUS')){
        foreach(@{$self->{CMDRESULTS}}) {
            if(m/$type/){
                if (m/^(\s*\w+\s*\w*)\s+(\:\w+)\s+(\d+)\s+(\d+)\s+(\d*)\s+(\d+)/) {
                    $logger->debug("$_");
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
    $logger->debug('<-- Leaving Sub');
}

##################################################################################
#
#purpose: disable redundnacy group and delete clients
#Parameters    : CNSX,PNSX,SPSX
#Return Values : None
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::deleteRedunclients()

 Routine to diable and delete redundnacy clients.

=over

=item Arguments

  Redundancy group name -Scalar(String)


=item Return

 Array

=item Example(s):

 $mgw9000Obj->deleteRedunclients("CNS71");

=back

=cut

#################################################
sub deleteRedunclients {
#################################################
  my($self, $type) = @_;
  my $server = my $redunserver = my $redgroup = "";
  my $i = 0;
  my $subName = 'deleteRedunclients()';
  my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug('--> Entered Sub');

  $logger->info(' Retrieving NIF Admin Information');
  if ($type eq 'all'){
    $server  = 'CNS';
  }else{
    $server = $type;
  }
  $logger->info(" server is $server");

  $self->getHWInventory(1);
  for ($i = 3; $i <= 16; $i++) {
      if ($self->{'hw'}->{'1'}->{$i}->{'ADAPTOR'} =~ m/CNA0/ ) {
          if ($self->{'hw'}->{'1'}->{$i}->{'SERVER'} =~ m/$server/){
              $redunserver = $self->{'hw'}->{'1'}->{$i}->{'SERVER'};
              $redgroup = $self->getRedungroupName($redunserver);
              my $j = 0;
              $logger->debug(" OUT servers:groups $redunserver : $redgroup and slot $i");
              $self->execFuncCall(
                          'configureRedundancyGroupState',
                          {
                              'redundancy group' => $redgroup,
                              'sonusRedundGroupAdmnState' => "disabled",
                          },
                      );

              for($j = 3; $j < $i; $j++) {
                  if($self->{'hw'}->{'1'}->{$j}->{'SERVER'} eq "$redunserver" ){
                      $logger->debug(" IN servers:groups $redunserver : $redgroup and slot $i");
                      $logger->debug(" \t$j");
                      $self->execFuncCall(
                          'configureRedundancyClientGroupSlotState',
                          {
                              'redundancy client group' => $redgroup,
                              'slot' => $j,
                              'sonusRedundClientAdmnState' => "disabled",
                          },
                      );

                      $self->execFuncCall(
                          'deleteRedundancyClientGroupSlot',
                          {
                              'redundancy client group' => $redgroup,
                              'slot' => $j,
                          },
                      );
                  }
              }
          }
      }
  }
  $logger->debug('<-- Leaving Sub');

}

##################################################################################
# purpose: Backup the command history in NFS as a tcl file
# Parameters    : resolved mgw
# Return Values : none
#
##################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000HELPER::backupConfig(<mgw>)

 Routine to Backup the command history in NFS as a tcl file.

=over

=item Arguments

  mgw9000     - reference

=item Return

none

=item Example(s):

  &$mgw9000Obj->backupConfig($mgw1);

=back

=cut

#################################################
sub backupConfig {
#################################################
    my($self, $mgw) = @_;
    my(@history);
    my $subName = 'backupConfig()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    @history = @{$self->{HISTORY}};
    if($#history > 0){
        my $dsiobj = SonusQA::DSI->new(
                    -OBJ_HOST => $mgw->{'NFS'}->{'1'}->{'IP'},
                    -OBJ_USER => 'root',
                    -OBJ_PASSWORD => 'sonus',
                    -OBJ_COMMTYPE => 'SSH',
                );
        my $nfscleancmd =  '/usr/bin/cat /dev/null > '."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/cli/scripts/mgwconf.tcl';
        $dsiobj->execCmd($nfscleancmd);
        while (@history) {
            my $cmdstring = shift @history;
            my $cmd  = substr $cmdstring, 23;
            if($cmd =~ m/PUTS/i){
                next;
            }
            $logger->debug("$cmd");
            my $nfscmd = 'echo '."$cmd  >> "."$mgw->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'}".'/cli/scripts/mgwconf.tcl';
            $dsiobj->execCmd($nfscmd);
        }
    }
    $logger->debug('<-- Leaving Sub');
}

#Function to remove leading/trailing spaces.
#################################################
sub trim($) {
#################################################
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

#########################################################################################################

=pod

=head3 getSS7CicRangesForSrvGrp()

  This function lists the cics for a given service group
  and calculates and returns an array of the cic ranges.

=over

=item Arguments :

  -protocol => <SS7 protocol type (ISUP or BT)>
  -service  => <SS7 service name>

=item Return Values :

  [<array of cic ranges>] if successful.
  [] . empty array otherwise


=item Example :

 $res = $Mgw9000Obj->SonusQA::MGW9000::MGW9000HELPER::getSS7CicRangesForSrvGrp(-protocol => 'ISUP',
                                                                   -service => 'SS71' );

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getSS7CicRangesForSrvGrp {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cicRangeArray;
    my @cmdResult;
    my $subName = 'getSS7CicRangesForSrvGrp()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($protocol, $service, $cmd, $current_cic, $start_cic, $end_cic, $previous_cic, $cic_not_found);

    $cic_not_found = 1;

    $logger->debug('--> Entered Subroutine with args - ' . Dumper(%args));

    $protocol = trim( $args{-protocol} );
    $service  = trim( $args{-service} );

    # Error if -protocol/-service is not set
    if ( (!defined $args{-protocol}) ||
          ($protocol eq '')          ||
          $protocol !~ /BT|ISUP/i ) {

        $logger->error(' missing/invalid "protocol" value [should be BT/ISUP].');
        $logger->debug('<-- Leaving Sub');
        return @cicRangeArray; # return empty array as failure
    }
    if ( (!defined $args{-service}) ||
         ($service eq '') ) {

        $logger->error(' "service" is not specified.');
        $logger->debug('<-- Leaving Sub');
        return @cicRangeArray; # return empty array as failure
    }

    # Get CIC-Status
    $cmd = "SHOW $protocol CIRCUIT SERVICE $service CIC ALL STATUS";
    if ($self->execCmd($cmd)) {

        my @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error("failed to execute command - $cmd.");
        $logger->debug('<-- Leaving Sub');
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
                    push (@cicRangeArray, "${start_cic}\-${end_cic}" );
                }
                else {
                    push (@cicRangeArray, ${start_cic});
                }
                $start_cic = $current_cic;
            }
            $previous_cic = $current_cic;
        }
        elsif(m/^error/i) {
            $logger->error("CMD RESULT: $_");
            $logger->debug('<-- Leaving Sub');
            return @cicRangeArray;
        }
    } # end foreach

    if ($cic_not_found == 1) {
        $logger->error("No CIC's found for service-grp - $service.");
    }
    else {
        $end_cic = $previous_cic;

        if ( $start_cic != $end_cic ){
            push (@cicRangeArray, "${start_cic}\-${end_cic}" );
        }
        else {
            push (@cicRangeArray, "${start_cic}" );
        }
        $logger->debug('<-- Leaving Sub');
    }

   return @cicRangeArray;

}

#########################################################################################################

=pod

=head3 getSS7CicStatus()

  This function checks the circuit status for a given SS7 service group and cic range
  and populates the results against the mgw9000 object as follows foreach circuit:

    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{STATUS}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{ADMIN}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{L_MAINT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{R_MAINT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{L_HW}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{R_HW}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{COT}
    {CICSTATE}->{<protocol>,<srv_grp>}[<cic>]->{OVERALL}

=over

=item Arguments :

  -protocol  => <SS7 protocol type (ISUP or BT)>
  -service   => <SS7 service name>
  -cic_range => <SS7 cic range>

=item Return Values :

   1 - success
   0 - otherwise

=item Example :

   $Mgw9000Obj->getSS7CicStatus(-protocol  => 'BT',
                            -service   => 'SS72',
                            -cic_range => '60-64')

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getSS7CicStatus {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $subName = 'getSS7CicStatus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($protocol, $service, $cicrange, $cmd);
    my ($cic_start, $cic_end, $current_cic , $cic_found);
    my ($status, $admin, $l_maint, $r_maint, $l_hw, $r_hw, $cot);

    $logger->debug('--> Entered Subroutine with args - ' . Dumper(%args));

    $protocol = uc(trim( $args{-protocol} ));
    $service  = uc(trim( $args{-service} ));
    $cicrange = trim( $args{-cic_range} );

    $service  =~ s/[^\w\d]//g;

    # Error if -protocol/-service is not set
    if ( (!defined $args{-protocol}) ||
          ($protocol eq '')        ||
          $protocol !~ /BT|ISUP/i ) {

        $logger->error(' missing/invalid "protocol" value [should be BT/ISUP].');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    if ( (!defined $args{-service}) ||
         ($service eq '') ) {

        $logger->error(' "service" is not specified.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }
    if ( (!defined $args{-cic_range}) ||
         ($cicrange eq '') ) {

        $logger->error(' "cicrange" is not specified.');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    # Check cic_range format
    if ( $cicrange =~ /([0-9]+)[-]([0-9]+)/) {
        $cic_start = $1;
        $cic_end   = $2;

        $cmd = "SHOW ISUP CIRCUIT SERVICE $service CIC $cic_start\-$cic_end STATUS";
    }
    elsif( $cicrange =~ /^([0-9]+)$/ ) {
        $cic_start = $cic_end = $1;
        $cmd = "SHOW ISUP CIRCUIT SERVICE $service CIC $cic_start STATUS";
    }
    else {
        $logger->error(' "cicrange" has incorrect format [should be cic_number OR a range (start_cic-end_cic) ].');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $logger->debug(" running command - $cmd");

    if ($self->execCmd($cmd)) {
        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error(" failed to execute command - $cmd.");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    for ( $current_cic = $cic_start; $current_cic <= $cic_end; $current_cic++) {
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
                $logger->error("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub [0]');
                return 0;
            }
        }

        if ( $cic_found == 0) {
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{STATUS}  = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{ADMIN}   = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_MAINT} = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_MAINT} = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{L_HW}    = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{R_HW}    = 'NOT_PROVISIONED';
            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{COT}     = 'NOT_PROVISIONED';

            $self->{CICSTATE}->{$protocol . ',' . $service}[$current_cic]->{OVERALL} = 'NOT_PROVISIONED';
        }

    }

    $logger->debug('<-- Leaving Sub [1]');
    return 1;
}

#########################################################################################################

=pod

=head3 verifyImageVersion()

   This function compares the images loaded on a MGW9000 to the version passed in as an argument.
   If they all match the function returns 1 (success) otherwise it returns 0 (failure).
   MGW9000 server cards that have their status to .N/A. are ignored


=over

=item Arguments :

   -version => <MGW9000 Image version name e.g. .V06.04.12 A004.>

=item Return Values :

   1 - success
   0 - otherwise

=item Example :

   $Mgw9000Obj->verifyImageVersion(-version => .V06.04.12 A004.)

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub verifyImageVersion {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $subName = 'verifyImageVersion()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($cmd, $version , $slot, $hwType, $loadedVersion, $nonMatchingImageFound);
    $nonMatchingImageFound = 1;

    unless (defined($args{-version}) &&  $args{-version} !~ /^\s*$/ ) {
        $logger->error(' missing/invalid "-version" value.');
        $logger->debug(' Leaving with retcode-0');
        return 0;
    }

    $version = $args{-version};

    $logger->debug(" Checking software version of server cards against \'$version\'.");

    $cmd = 'SHOW SOFTWARE UPGRADE SHELF 1 SUMMARY';
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
                    $logger->error(" loaded image '$loadedVersion' in slot $slot does not match specified image '$version'." );
                    $nonMatchingImageFound = 0;
                }
            }
        }
        elsif(m/^error/i) {
            $logger->error(" CMD RESULT: $_");
            $logger->debug(' Leaving with retcode-0');
            return 0;
        }
      } # End foreach
    }
    else {
        $logger->error(" failed to execute command - $cmd.");
        $logger->debug(' Leaving with retcode-0');
        return 0;
    }

    $logger->debug(" Leaving with retcode-$nonMatchingImageFound");
    return $nonMatchingImageFound;
}

#########################################################################################################

=pod

=head3 areServerCardsUp()

    This function checks that all the server cards in a MGW9000 are in the state .RUNNING., .EMPTY. or .HOLDOFF..
    If so the function returns 1 (success) otherwise it will loop around re-checking every 5 seconds until it succeeds
    or specified timeout value is reached. On timeout the function will return 0 failure.

=over

=item Arguments :

    -timeout => <maximum length of time MGW9000 should be checked>

=item Return Values :

    1 - success
    0 - otherwise

=item Example :

    $Mgw9000Obj->areServerCardsUp()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub areServerCardsUp {
#################################################

    my ($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $subName = 'areServerCardsUp()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($timeout, $cmd, $nonMatchingStatus, $timeElapsed, $t0, $t1, $t0_t1);
    my ($slot, $hwType, $serverStatus, $oneMismatch);

    $nonMatchingStatus = 0;
    $timeout = 60;

    $logger->debug('--> Entered Subroutine with args - ' . Dumper(%args));

    if ( (!defined $args{-timeout}) ||
          ($args{-timeout} eq '') ) {

        $logger->debug('missing "timeout" value, continuing with default (60 secs).');
    }
    else {
        $timeout = $args{-timeout};
    }

    $cmd = 'SHOW INVENTORY SHELF 1 SUMMARY';
    $logger->debug("running command - $cmd");
    $t0 = [gettimeofday];

    do {

        if ($self->execCmd($cmd)) {

            @cmdResult = @{$self->{CMDRESULTS}};
            $oneMismatch = 0;
            $nonMatchingStatus = 0;

            foreach( @cmdResult ) {

                chomp($_);
                if( m/^\d+\s+(\d+)\s+(\S+)\s+(\S+)\s+\S+\s+\S+/i )  {

                    $slot         = $1;
                    $hwType       = $2;
                    $serverStatus = $3;

                    #$logger->debug("slot - $slot \/ hwType - $hwType \/ serverStatus - $serverStatus.");
                    if ( $hwType =~ /UNKNOWN/i ) {
                        $logger->debug("IGNORE SLOT - Hardware Type is UNKNOWN in Slot $slot.");
                        next;
                    }

                    if ( $serverStatus !~ /EMPTY|HOLDOFF|RUNNING/  ) {
                        $oneMismatch = 1;
                        $logger->debug("MISMATCH - Server Status in slot $slot does not match one of EMPTY|HOLDOFF|RUNNING. Currently set to '$serverStatus'.");
                    } else {
                        $logger->debug("MATCH - Server Status in slot $slot set to '$serverStatus'.");
                    }
                }
                elsif (m/^error/i) {
                    $logger->error("Found error in commnad execution. CMD RESULT: $_");
                    $logger->debug('Leaving with retcode-0');
                    return 0;
                }
            }

            if ($oneMismatch == 1) {

                $nonMatchingStatus = 0;
                $logger->debug("Not all server cards are ready, retrying after 5 secs.");
                sleep (5);
            }
            else {

               $nonMatchingStatus = 1;
            }
        }
        else {
            $logger->error("Failed to execute command - $cmd.");
            $logger->debug('Leaving with retcode-0');
            return 0;
        }

    } while ( ($nonMatchingStatus == 0) && (tv_interval($t0) <= $timeout) );

    $logger->debug("Leaving with retcode-$nonMatchingStatus");
    return $nonMatchingStatus;
}

#########################################################################################################

=pod

=head3 getISDNChanRangesForSrvGrp()

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

    $Mgw9000Obj->getISDNChanRangesForSrvGrp(-service => 'is1')

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getISDNChanRangesForSrvGrp {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @chanRangeArray;
    my @cmdResult;
    my $subName = 'getISDNChanRangesForSrvGrp()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($interface, $service, $cmd, $current_chan, $start_chan, $end_chan, $previous_chan, $chan_not_found);
    my $pushString = "";

    $chan_not_found = 1;
    $previous_chan  = 0;

    $logger->debug("--> Entered Subroutine with args - " . Dumper(%args));

    $service  = trim( $args{-service} );

    if ( (!defined $args{-service}) ||
         ($service eq '') ) {

        $logger->error("\"service\" is not specified.");
        $logger->debug('<-- Leaving Sub');
        return @chanRangeArray; # return empty array as failure
    }

    # Get CHAN-Status
    $cmd = "SHOW ISDN BCHANNEL SERVICE $service STATUS";
    if ($self->execCmd($cmd)) {

        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error("failed to execute command - $cmd.");
        $logger->debug('<-- Leaving Sub');
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
                    $pushString = $service . "," . $interface . "," . "${start_chan}\-${end_chan}";
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
            $logger->error("CMD RESULT: $_");
            $logger->debug('<-- Leaving Sub');
            return @chanRangeArray;
        }
    } # end foreach

    if ($chan_not_found == 1)
    {
        $logger->error("No CHAN's found for service-grp - $service.");
    }
    else {
        $end_chan = $previous_chan;

        if ( $start_chan != $end_chan ){
            $pushString = $service . "," . $interface . "," . "${start_chan}\-${end_chan}";
            push (@chanRangeArray, $pushString );
        }
        else {
            $pushString = $service . "," . $interface . "," . $start_chan;
            push (@chanRangeArray, $pushString );
        }
    }

   $logger->debug('<-- Leaving Sub');
   return @chanRangeArray;

}

#########################################################################################################

=pod

=head3 getISDNChannelStatus()

    This function checks the ISDN channel status for a given ISDN service group and channel range
    and populates the results against the mgw9000 object as follows foreach circuit:

    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{USAGE}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{L_ADMIN}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{L_HW}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{R_MAINT}
    {CHANSTATE}->{<srv_grp>,<interface>}[<chan>]->{OVERALL}

    The existing {CHANSTATE}->{<srv_grp>,<interface>} hash will be deleted before re-populating.

=over

=item Arguments :

    -service      => <ISDN service name>
    -chan_range   => <ISND channel range>

=item Return Values :

   1 - success
   0 - otherwise

=item Example :

    $Mgw9000Obj->getISDNChannelStatus(-service    => 'is1',
                                  -chan_range => '1-15')

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getISDNChannelStatus {
#################################################

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @cmdResult;
    my $subName = 'getISDNChannelStatus()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($service, $interface, $chanrange, $cmd);
    my ($chan_start, $chan_end, $current_chan , $chan_found);
    my ($usage, $l_admin, $r_maint, $l_hw);

    $logger->debug('--> Entered Subroutine with args - ' . Dumper(%args));

    $service  =  uc (trim( $args{-service} ));
    $chanrange = trim( $args{-chan_range} );

    $service =~ s/[^\w\d]//g;

    # Error if -chanrange/-service is not set
    if ( (!defined $args{-service}) ||
         ($service eq '') ) {

        $logger->error("\"service\" is not specified.");
        $logger->debug('<-- Leaving Sub');
        return 0;
    }
    if ( (!defined $args{-chan_range}) ||
         ($chanrange eq '') ) {

        $logger->error("\"chanrange\" is not specified.");
        $logger->debug('<-- Leaving Sub');
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
        $logger->error("\"chanrange\" has incorrect format [should be chan_number OR a range (start_chan-end_chan) ].");
        $logger->debug('<-- Leaving Sub');
        return 0;
    }

    $cmd = "SHOW ISDN BCHANNEL SERVICE " . $service ." STATUS";
    $logger->debug("running command - $cmd");

    if ($self->execCmd($cmd)) {
        @cmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error("failed to execute command - $cmd.");
        $logger->debug('<-- Leaving Sub');
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
                $logger->error("CMD RESULT: $_");
                $logger->debug('<-- Leaving Sub');
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

    $logger->debug('<-- Leaving Sub');
    return 1;
}

#########################################################################################################

=pod

=head3 getConfigFromTG()

    This function identifies the circuits or channels tied to a
    service group for all trunk groups of the MGW9000 object.

=over

=item Arguments :

    None

=item Return Values :

    1 - success
    0 - otherwise

    MGW9000 object has the $Mgw9000Obj->{TG_CONFIG} hash populated.

=item Example :

    $Mgw9000Obj->getConfigFromTG()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getConfigFromTG {
#################################################
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my @allTGCmdResult;
    my @allSGCmdResult;
    my @sgStatus;
    my @cmdStatus;
    my @ss7NodeResult;
    my $subName = 'getConfigFromTG()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($cmd, $tgName, $sgName, $sgType ,$isupOrBT, $ss7NodeName );
    my $suitableTrunkGroupFound=0;

    $self->{TG_CONFIG} = undef;

    $cmd = 'SHOW TRUNK GROUP ALL STATUS';
    if ($self->execCmd($cmd)) {
        @allTGCmdResult = @{$self->{CMDRESULTS}};
    }
    else {
        $logger->error("failed to execute command - $cmd.");
        $logger->debug('<-- Leaving Sub');
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
                $logger->debug("TGNAME - $tgName");
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
                                            $logger->error("CMD RESULT: $_");
                                            $logger->debug('<-- Leaving Sub');
                                            return 0;
                                        }
                                    }

                                    if ( ($svrProto !~ /LOCAL/i) && ($gwName eq "") )
                                    {
                                        $logger->error("unable to get gateway assignment for $ss7NodeName.");
                                        $logger->debug("<-- Leaving Sub retCode - 0.");
                                        return 0;
                                    }
                                    elsif ( ($svrProto =~ /M3UA/i) && ($altGwName eq "") )
                                    {
                                        $logger->error("unable to get alternate gateway assignment for $ss7NodeName.");
                                        $logger->debug('<-- Leaving Sub retCode - 0.');
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
                                            $logger->error("failed to execute command - $cmd.");
                                            $logger->debug('<-- Leaving Sub');
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
                                                $logger->error("CMD RESULT: $_");
                                                $logger->debug("<-- Leaving Sub retCode - 0");
                                                return 0;
                                            }
                                        }
                                    } # foreach - GW
                                }
                                else
                                {
                                    $logger->error("failed to execute command - $cmd.");
                                    $logger->debug('<-- Leaving Sub');
                                    return 0;
                                }

                            }
                        }
                        elsif(m/^error/i)
                        {
                            $logger->error("CMD RESULT: $_");
                            $logger->debug('<-- Leaving Sub');
                            return 0;
                        }
                    }
                }
                else
                {
                    $logger->error("failed to execute command - $cmd.");
                    $logger->debug('<-- Leaving Sub');
                    return 0;
                }

                $cmd = "SHOW TRUNK GROUP $tgName SERVICEGROUPS";
                if ($self->execCmd($cmd))
                {
                    @allSGCmdResult = @{$self->{CMDRESULTS}};
                }
                else {
                    $logger->error("failed to execute command - $cmd.");
                    $logger->debug('<-- Leaving Sub');
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
                                         $logger->error("unidentified sg-group $sgName.");
                                         $logger->debug('<-- Leaving Sub');
                                         return 0;
                                     }
                                     $isupOrBT = 'BT';
                                 }
                                 else
                                 {
                                     $logger->error("failed to execute command - $cmd.");
                                     $logger->debug('<-- Leaving Sub');
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
                                    $logger->error("CMD RESULT: $_");
                                    $logger->debug('<-- Leaving Sub');
                                    return 0;
                                }
                            }


                            @{$self->{TG_CONFIG}->{$tgName}->{$isupOrBT . ',' . $sgName}->{CIC_RANGES}} =
                                                  $self->getSS7CicRangesForSrvGrp(-protocol => $isupOrBT,
                                                                                  -service  => $sgName );
                        }
                        else
                        {
                            $logger->error("failed to execute command - $cmd.");
                            $logger->debug('<-- Leaving Sub');
                            return 0;
                        }
                    }
                    elsif ( $sgType =~ /isdn/i ) {

                        @{$self->{TG_CONFIG}->{$tgName}->{'ISDN' . ',' . $sgName}->{CHANNEL_RANGES}} =
                                                 $self->getISDNChanRangesForSrvGrp(-service => $sgName);
                    }
                    else {
                        $logger->error("unsupported service-group type $sgType");
                        $logger->debug('<-- Leaving Sub');
                        return 0;
                    }
                }
                elsif(m/^error/i)
                {
                    $logger->error("CMD RESULT: $_");
                    $logger->debug('<-- Leaving Sub');
                    return 0;
                }
              }
            }
        }
        elsif(m/^error/i) {
            $logger->error("CMD RESULT: $_");
            $logger->debug('<-- Leaving Sub');
            return 0;
        }

    } # foreach allTGCmdResult

    if ($suitableTrunkGroupFound==0)
    {
        $logger->error('no suitable trunk group found');
        $logger->debug('<-- Leaving Sub');
        return 0;
    }

    $logger->debug('<-- Leaving Sub');
    return 1;
}


#########################################################################################################

=pod

=head3 isCleanupOrRebootRequired()

    Assumes MGW9000 object has been populated after TCL configuration
    using getConfigFromTG() function.

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

    $Mgw9000Obj->isCleanupOrRebootRequired()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub isCleanupOrRebootRequired {
#################################################
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $subName = 'isCleanupOrRebootRequired()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my ($cmd);

    @{$self->{CIC_CLEANUP_ARRAY}}  = ();
    @{$self->{CHAN_CLEANUP_ARRAY}} = ();
    # DEBUG - Added this init
    %{$self->{CLEANUP_REASON}} = ();

    unless (defined($self->{'TG_CONFIG'})) {
        $logger->warn('No MGW9000 config found on this MGW9000. Has the getConfigFromTG() function been executed successfully?');
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

                        if ( $self->getSS7CicStatus(-protocol => $serviceType,
                                                    -service => $serviceName,
                                                    -cic_range => $cicRange) )
                        {
                            for(my $cic=$cicStart; $cic <= $cicEnd; $cic++)
                            {

                                my $overAllState = $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{OVERALL};
                                if ( $overAllState eq "NON-IDLE" )
                                {
                                    my $pushData = $serviceType . "," . $serviceName . ',' . $cic;
                                    push(@{$self->{CIC_CLEANUP_ARRAY}}, $pushData);

                                    $self->{CLEANUP_REASON}->{$serviceType . ',' . $serviceName}[$cic] =
                                                               "$serviceType CIC $cic in service group $serviceName is in state: \n" .
                                                               'CIC STATUS = ' . $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{STATUS} . "\n" .
                                                               'LOCAL MAINT = '. $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{L_MAINT}. "\n" .
                                                               'REMOTE MAINT = '. $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{R_MAINT}. "\n" .
                                                               'LOCAL HARDWARE = '. $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{L_HW}."\n" .
                                                               'REMOTE HARDWARE = '. $self->{CICSTATE}->{$serviceType . ',' . $serviceName}[$cic]->{R_HW}."\n";

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
                            $logger->error(" Failed to get circuit status for cic range $cicRange service-$serviceName.");
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
                                    my $pushData = $serviceType . ',' . $serviceName . ',' . $chan;
                                    push(@{$self->{CHAN_CLEANUP_ARRAY}}, $pushData);

                                    $self->{CLEANUP_REASON}->{$serviceType . ',' . $serviceName}[$chan] =
                                                               "$serviceType CHAN $chan in service group $serviceName is in state: \n" .
                                                               'USAGE = ' . $self->{CHANSTATE}->{$serviceName . ','. $interface}[$chan]->{USAGE} . "\n" .
                                                               'LOCAL ADMIN = '. $self->{CHANSTATE}->{$serviceName . ',' . $interface}[$chan]->{L_ADMIN}. "\n" .
                                                               'REMOTE MAINT = '. $self->{CHANSTATE}->{$serviceName . ',' . $interface}[$chan]->{R_MAINT}. "\n" .
                                                               'LOCAL HARDWARE = '. $self->{CHANSTATE}->{$serviceName . ',' .$interface}[$chan]->{L_HW}."\n";

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
                            $logger->error(" Failed to get ISDN B-channel status for chan range $chanRange.");
                        }
                    }
                }
                else
                {
                    $logger->debug("unrecognized serviceType-$serviceType.");
                }
            }
        } # foreach inner
    } # foreach outer

    if ($self->{RESET_NODE})
    {
        $logger->debug("Leaving with retcode-2 (indicating MGW9000 REBOOT required)");
        return 2; # REBOOT
    }
    elsif( ( $#{$self->{CIC_CLEANUP_ARRAY}} > -1) || ( $#{$self->{CHAN_CLEANUP_ARRAY}} > -1) )
    {
        $logger->debug('Leaving with retcode-1 (indicating MGW9000 CLEANUP required)');
        return 1; # CLEANUP
    }

    $logger->debug('Leaving with retcode-0 (indicating that NO CLEANUP is required on the MGW9000');
    return 0; # NO-CLEANUP
}


#########################################################################################################

=pod

=head3 getProtectedSlot()

    Returns the protected slot number.

=over

=item Arguments :

    card-type.

=item Return Values :

    "" - failure
    else the slot.

=item Example :

    $Mgw9000Obj->getProtectedSlot("MNS11-1")

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getProtectedSlot {
#################################################
    my($self, $card) = @_;
    my $subName = 'getProtectedSlot()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $cmd;

    if ( (! defined $card) || ($card eq ""))
    {
        $logger->error("card not defined.");
        return "";
    }

    $cmd = "SHOW REDUNDANCY GROUP $card STATUS";
    my @cmdResult = $self->execCmd($cmd);
    $logger->debug("[$cmd] result [@cmdResult].");
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
                    $logger->error("[$cmd] failure.");
                    $logger->debug('<-- Leaving Sub');
                    return "";
                }
    }

    return "";
}

#########################################################################################################

=pod

=head3 getRedundantSlotState()

    Returns the redundant slot state.

=over

=item Arguments :

    Card-type.

=item Return Values :

    0 - failure
    else the state.

=item Example :

    $Mgw9000Obj->getRedundantSlotState("MNS11-1");

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub getRedundantSlotState {
#################################################
    my($self, $card) = @_;
    my $subName = 'getRedundantSlotState()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $cmd;

    if ( (! defined $card) || ($card eq ""))
    {
        $logger->error("card not defined.");
        return 0;
    }

    $cmd = "SHOW REDUNDANCY GROUP $card STATUS";
    my @cmdResult = $self->execCmd($cmd);
    $logger->debug("[$cmd] result [@cmdResult].");
    my $swFlag=0;
    foreach ( @cmdResult )
    {
                chomp($_);
                if ( m/^\s*Redundant Slot State:\s+(\S+)\s*$/i )
                {
                    $logger->debug("<-- Leaving Sub with retCode-'$1'.");
                    return $1;
                }
                elsif ( m/^error/i )
                {
                    $logger->error("[$cmd] failure.");
                    $logger->debug('<-- Leaving Sub retCode-2.');
                    return 0;
                }
    }

    return 0;
}

#########################################################################################################

=pod

=head3 detectSwOverAndRevert()

    Detects a s/w and if and reverts back.

=over

=item Arguments :

    None

=item Return Values :

    0 - s/w happened
    1 - no s/w happened
    2 - command failure

=item Example :

    $Mgw9000Obj->detectSwOverAndRevert()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

#################################################
sub detectSwOverAndRevert {
#################################################
    my($self) = @_;
    my $subName = 'detectSwOverAndRevert()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    my $swOverNotFound=1;

    my $cmd = 'SHOW REDUNDANCY GROUP SUMMARY';
    my @result = $self->execCmd($cmd);
    $logger->debug("[$cmd] result [@result].");
    foreach ( @result )
    {
        chomp($_);
        if ( m/^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+ENABLED\s*$/i )
        {
            my $cardType = $1;
            my $redSlotState = $self->getRedundantSlotState($cardType);
            $logger->debug(" Card type found = $cardType. Redundant slot state = $redSlotState");
            if ( $redSlotState eq 0 )
            {
                $logger->error(' unable to find red-slot info.');
                $logger->debug('<-- Leaving Sub retCode-2.');
                return 2;
            }

            if ( $redSlotState !~ /STANDBY/i )
            {
                $swOverNotFound=0;
                my $protSlot = $self->getProtectedSlot($cardType);
                $logger->debug("Card type found = $cardType. Redundant slot state = $redSlotState. Protected Slot = $protSlot");
                push(@{$self->{SWITCHEDOVER}}, "$cardType, $protSlot");

                my $redSlotState = $self->getRedundantSlotState($cardType);

                my $timeout = 1800;
                my $t0 = [gettimeofday];
                while ( ($redSlotState !~ /ACTIVESYNCED|ACTIVESYNCING/i) &&
                        (tv_interval($t0) <= $timeout) )
                {
                    $logger->debug("redSlotState-$redSlotState, sleeping for 5 secs.");
                    sleep(5);
                    $redSlotState = $self->getRedundantSlotState($cardType);
                }
                if ( ($redSlotState !~ /ACTIVESYNCED|ACTIVESYNCING/i) )
                {
                    # Timer has expired
                    $logger->error(' red-slot failed to synch within 5 mins.');
                    $self->{RESET_NODE} = 1;
                }

                $cmd = "CONFIGURE REDUNDANCY GROUP $cardType REVERT";
                my @cResult = $self->execCmd($cmd);
                if ( $self->reconnect() == 0 )
                {
                    $logger->error('could not reconnect after REVERT.');
                    $self->{RESET_NODE} = 1;
                    return 0;
                }
                $redSlotState = $self->getRedundantSlotState($cardType);
                while ( ($redSlotState !~ /STANDBY/i) &&
                        (tv_interval($t0) <= $timeout) )
                {
                    $logger->debug("REVERT redSlotState-$redSlotState, sleeping for 5 secs.");
                    sleep(5);
                    $redSlotState = $self->getRedundantSlotState($cardType);
                }
                if ( $redSlotState !~ /STANDBY/i )
                {
                    $logger->error('red-slot failed to STANDBY mode within 5 mins.');
                    $self->{RESET_NODE} = 1;
                }
            }
        }
        elsif ( m/^error/i )
        {
            $logger->error("[$cmd] failure result - [@result].");
            $logger->debug('<-- Leaving Sub retCode-2.');
            return 2;
        }
    }

    $logger->debug("<-- Leaving Sub retCode-$swOverNotFound.");
    return $swOverNotFound;
}

#########################################################################################################

=head3 waitAllRoutingKeys()

    Waits for all M3UA routing keys on the device to reach a specified state.

Arguments : (all optional)

    -timeout                    - Default 60s - Overall time to wait for the routing keys to get into the requested state - in seconds.
     -geographic_redundancy - Default 0   - Set to 1 to select the default pattern match for Goegraphic redundant setup, 0 selects the default pattern for Dual-CE and is the default
     -custom_match                - Specify a custom match string which all routing keys must match e.g.

         "act oos oos oos.*ava una una una" - RKeys are registered only to the primary CE, and the destination(s) are available
         ":282828: 10128:.*act act oos oos.*ava una una una" - Only check RKEYs between PC 40-40-40 and 1-1-40 (ANSI format), RKeys are registered to the primary and secondary CE, but only the primary CE reports the destination as available
         "txR txR oos oos" - RKeys are attempting to register to the SGX, but no positive response has been received.


Return Values :

    0 - Failure (timed out before routing keys detected in requested state.
    1 - Success

Examples:
    $Mgw9000Obj->waitAllRoutingKeys()
    $Mgw9000Obj->waitAllRoutingKeys(-timeout => 15, -custom_match => "txR txR oos oos.*una una una una")
    $Mgw9000Obj->waitAllRoutingKeys(-geographic_redundancy => 1)

Author :
 Malcolm Lashley
 mlashley@sonusnet.com

=cut

#################################################
sub waitAllRoutingKeys {
#################################################

    my ($self, %args) = @_;
    my $subName = 'waitAllRoutingKeys()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');


    # Set default values before args are processed
    my %a = ( -geographic_redundancy => 0,
             -timeout     => 60,
                 -custom_match => "act act oos oos.*ava ava una una",
            );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

# Todo - someone should move sub _info() from MGTS.pm to Base.pm as its a generically useful debug tool to dump the args passed into a function...
#    $self->_info( -sub => $subName, %a );

    if(defined $args{-geographic_redundancy} and defined $args{-custom_match}) {
        $logger->warn('Invalid arguments supplied: -geographic_redundancy overrides -custom_match with a default active/available string, please make your checks');
        $logger->debug('<-- Leaving Sub [0]');
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
       $logger->info ('Waiting for active/available routing keys... time remaining ' . ($a{-timeout} - tv_interval($startLoopTime)));
        $notready = 0;
        foreach (@rkstates2) {
            if (m/$a{-custom_match}/) {
               $logger->debug("Found matching routing keys [ $_ ]");
            } else {
               $logger->info("Found non-matching routing key - will recheck [ $_ ]");
                $notready += 1 ;
            }
        }
        sleep 2 if $notready;
    }
    if ($notready) {
        $logger->error(" Unable to get all routing keys active at MGW9000 - Timed out. Current state:\n" . Dumper(\@rkstates));
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
    }

    $logger->debug('<-- Leaving Sub [1]');
    return 1;

}

#########################################################################################################

=pod

=head3 clearLog()

    Start over the log before a test case starts

=over

=item Arguments :

    None

=item Return Values :

    0 - Failed
    1 - Completed

=item Example :
    $Mgw9000Obj->clearLog()

=item Author :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

#################################################
sub clearLog {
#################################################
   my($self) = @_;
   my $subName = 'clearLog()';

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');


   $logger->info("CLEARING MGW9000 LOG");

   my $r_cmd1="CONFIGURE EVENT LOG ALL ROLLFILE NOW";

   $logger->info("Executing $r_cmd1");

   if ($self->execCmd($r_cmd1)) {
      # Check the command execution status

     foreach(@{$self->{CMDRESULTS}}) {

         chomp($_);
         # Error if error string returned
         if (m/^error/i) {
            $logger->error("CMD RESULT: $_");
            $logger->debug("Leaving function retcode-0");
            return 0;
         }
      }
   }

   $logger->info("command output \n@{$self->{CMDRESULTS}}");


   my $ref_ar = $self->nameCurrentFiles;
  ($ACTfile, $DBGfile, $SYSfile) = @$ref_ar;

   $logger->info( "MGW9000 LOG FILES ROLLED");

   $logger->debug("Leaving function retcode-1");
   return 1;
}

#########################################################################################################

=pod

=head3 getLog()

    Get the MGW9000 logs File ACT DBG and SYS

=over

=item Arguments :
    None

=item Return Values :


  0 if file is not copied
  1 if file is copied

=item Example :
            $Mgw9000Obj->getLog;

=item Author :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

#################################################
sub getLog {
#################################################
   my ($self) = @_;
   my $subName = 'getLog()';
   my ($atsloc, $path, @cmdresults, @dbglog, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber, $dbglogname, $dbglogfullpath, $dsiObj, $dbgfile, $syslogname, $syslogfullpath, $sysfile, $actlogname, $actlogfullpath, $actfile);
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');


   $logger->info('RETRIEVING ACTIVE MGW9000 DBG LOG');

   # Get node name
   $cmd = 'show node admin';
   @cmdresults = $self->execCmd($cmd);
   foreach (@cmdresults) {
      if ( m/Name:\s+(\w+)/ ) {
         $nodename = $1;
         $nodename =~ tr/[a-z]/[A-Z]/;
      }
   }

   $nodename = uc($nodename);
   $logger->info("node name : $nodename");

   if (!defined($nodename)) {
      $logger->warn('NODE NAME MUST BE DEFINED');
      $logger->debug("<-- Leaving Sub [$nodename]");
      return $nodename;
   }

   $logger->info("Got the Node Name = $nodename");

   # Get IP address and path of active NFS
   $cmd = 'show nfs shelf 1 slot 1 status';
   @cmdresults = $self->execCmd($cmd);
   foreach (@cmdresults) {
      if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/ ) {
         $activenfs = $1;
      }
      if (defined $activenfs) {
         if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
            $nfsipaddress = $2;
            $nfsmountpoint = $3;
    $logger->info("NFS IP Address => $nfsipaddress and NFS MOUNT POINT => $nfsmountpoint");
            last;
         }
      }
   }

   # Get chassis serial number
   $cmd = 'show chassis status';
   @cmdresults = $self->execCmd($cmd);
   foreach(@cmdresults) {
      if(m/Serial Number:\s+(\d+)/) {
         $serialnumber = $1;
    $logger->info("Log Serial No. => $serialnumber ");
      }
   }

   # Determine name of active DBG log
   $cmd = 'show event log all status';
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


  $ACTfile =~ m/(\w+).ACT/;
  my $startACTfile = $1;
  $DBGfile =~ m/(\w+).DBG/;
  my $startDBGfile = $1;
  $SYSfile =~ m/(\w+).SYS/;
  my $startSYSfile = $1;

  my (@ACTlist, @DBGlist, @SYSlist);

  while ($startACTfile le $actlogname) {
    $logger->debug("$startACTfile = $startACTfile");
    push @ACTlist, ($startACTfile. '.ACT');
    $startACTfile = hex_inc($startACTfile);
  }

  while ($startDBGfile le $dbglogname) {
    $logger->debug("$startDBGfile = $startDBGfile");
    push @DBGlist, ($startDBGfile. '.DBG');
    $startDBGfile = hex_inc($startDBGfile);
  }

  while ($startSYSfile le $syslogname) {
    $logger->debug("$startSYSfile = $startSYSfile");
    push @SYSlist, ($startSYSfile. '.SYS');
    $startSYSfile = hex_inc($startSYSfile);
  }

   if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {
      my $add_path='/sonus';
      # Create full path to log
              #$dbgfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname" . '.DBG';
              #$actfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$actlogname" . '.ACT';
              #$sysfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$syslogname" . '.SYS';
           my $timeout = 300;
           my $ats_dir = '/home/autouser/mgwlogs/';




           # Open a session for SFTP
           my $sftp_session = new SonusQA::Base( -obj_host       => '10.128.96.76',
                                         -obj_user       => 'autouser',
                                         -obj_password   => 'autouser',
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                       );
           unless ( $sftp_session ) {
              $logger->error('Could not open connection to mallrats');
              $logger->debug('<-- Leaving Sub [0]');
              return 0;
           }

      foreach $dbglogname (@DBGlist) {
        $dbgfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname" ;
        $atsloc = "$ats_dir" ."$dbglogname" ;
        if ( $sftp_session->{conn}->cmd("\/bin\/cat $dbgfile > $atsloc")) {
            $logger->debug("$path transfer success");
            $logger->debug("Executed the CMD ==> \/bin\/cat $dbgfile > $atsloc");
                sleep 5;
            }
        else {
            $logger->error('failed to copy the MGW9000 DBG log file');
            }
      }

      foreach $actlogname (@ACTlist) {
        $actfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/ACT/' . "$actlogname" ;
        $atsloc = "$ats_dir" ."$actlogname" ;
           if ( $sftp_session->{conn}->cmd("\/bin\/cat $actfile > $atsloc")) {
                $logger->info("$path transfer success");
                $logger->info("Executed the CMD ==> \/bin\/cat $actfile > $atsloc");
                sleep 5;
                }
           else {
                $logger->error("failed to copy the MGW9000 ACT log file");
                }
      }

      foreach $syslogname (@SYSlist) {
        $sysfile = "$add_path$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/SYS/' . "$syslogname" ;
        $atsloc = "$ats_dir" ."$syslogname" ;
           if ( $sftp_session->{conn}->cmd("\/bin\/cat $sysfile > $atsloc")) {
                $logger->info("$path transfer success");
                $logger->info("Executed the CMD ==> \/bin\/cat $sysfile > $atsloc");
                sleep 5;
                }
           else {
                $logger->error('failed to copy the MGW9000 SYS log file');
                }
      }

    $sftp_session->DESTROY;
        return (@DBGlist, @ACTlist, @SYSlist);
    }
else {
        $logger->warn(' NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2..');
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
        }

    return (@DBGlist, @ACTlist, @SYSlist);
}


#########################################################################################################



#################################################
sub nameCurrentFiles {
#################################################
  my $self = shift;
  my $subName = 'nameCurrentFiles()';
  my ($dbglogname, $syslogname, $actlogname, $cmd, @cmdresults);
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');

   $logger->debug('Getting current log names');
   # Determine name of active file names
   $cmd = 'show event log all status';
   @cmdresults = qw();
   @cmdresults = $self->execCmd($cmd);

   $logger->debug(" command result \n@cmdresults\n");

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
   }
  # if ACT is not available just return INVALID.
  if( !defined ($actlogname) ) {
     $actlogname = 'INVALID_ACT';
  }
  $logger->debug("$actlogname, $dbglogname, $syslogname");

  my @retval = ("$actlogname", "$dbglogname", "$syslogname");
  $logger->debug('<-- Leaving Sub');
  return \@retval;
}

#########################################################################################################

#################################################
sub hex_inc {
#################################################
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

    $logger->debug("<-- Leaving Sub [$hexstring]");
    return $hexstring;
}


#########################################################################################################

#################################################
sub hexaddone {
#################################################
    my $hexin = shift;
    my $hex = '0x'.$hexin;
    my $dec = hex($hex);
    $dec++;
    my $hexout = sprintf "%X", $dec;
    return $hexout;
}
#########################################################################################################

=pod

=head3 sourceTclFile()

This subroutine is same as sourceTclFileFromNFS. This subroutine needs to be used, when the test case is been run from a system, where mount can not be done.

=over

=item Assumption :

   None

=item Arguments :

 -tcl_file
    name of the tcl file
 -doNotUseC
    Optional : set as 1, if ../C/ not to be used with the TCL file


=item Return Values :

 1 - success ,when tcl file is executed without errors and end tag "SUCCESS" is reached
 0 - failure , error occurs during execution or inputs are not specified

=item Example :

 \$obj->sourceTclFile(-tcl_file => "ansi_cs.tcl");

=item Author :

Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

#################################################
sub sourceTclFile {
#################################################

   my($self,%args) = @_;
   my $subName = 'sourceTclFile()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');


   my %a = (-doNotUseC => 0);

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $tcl_file = $a{-tcl_file};

   # Error if tcl_file is not set
   unless (defined $tcl_file && $tcl_file !~ /^\s*$/ ) {
      $logger->error('tcl file is not specified or is blank');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   my $cmd;

   if($a{-doNotUseC} eq 0) {
      $cmd = "source ..\/C\/$tcl_file";
   } else {
      $cmd = "source $tcl_file";
   }

   # Source the tcl file in mgw
   my $default_timeout = $self->{DEFAULTTIMEOUT};
   $self->{DEFAULTTIMEOUT} = 400;
   my @cmdresults = $self->execCmd($cmd);
   $self->{DEFAULTTIMEOUT} = $default_timeout;

   # $logger->debug("@cmdresults");

   foreach(@cmdresults) {

      chomp($_);

      # Checking for SUCCESS tag
      if (m/^SUCCESS/) {
         $logger->debug("CMD RESULT: $_");
         $logger->debug("Successfully sourced MGW9000 TCL file: $tcl_file");
         $logger->debug('<-- Leaving Sub [1]');
         return 1;
      } elsif (m/^error/) {
         unless (m/^error: Unrecognized input \'3\'.  Expected one of: VERSION3 VERSION4/) {
            $logger->error("Error occurred during execution : $_");
            $logger->debug('<-- Leaving Sub [0]');
            return 0;
         }
      }
   } # End foreach

   # If we get here, script has not been successful
   $logger->error('SUCCESS string not found, nor error string. Unknown failure.');
   $logger->debug('<-- Leaving Sub [0]');
   return 0;
}

#########################################################################################################

=pod

=head3 checkCore()

This subroutine is similar to coreCheck. This subroutine needs to be used, when the test case is been run from a system, where NFS is not mounted

=over

=item Assumption :

   None

=item Arguments :
     -testCaseID => Test case ID

=item Return Values :


=item Example :


=item Author :

Rodrigues, Kevin (krodrigues@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

#################################################
sub checkCore {
#################################################
   my ($self, %args) = @_;
   my $subName = 'checkCore()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');


   # Set default values before args are processed
   my %a;
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $nodeName;
   my $cmd;
   my @cmdResults;

   # Get the MGW9000 name
   if(defined ($a{-mgwName})) {
      $nodeName = $a{-mgwName};
   } else {
      $cmd = 'show node admin';
      $logger->debug("Executing command $cmd");
      @cmdResults = $self->execCmd($cmd);
      $logger->debug('Command Results' . Dumper(\@cmdResults));
      foreach (@cmdResults) {
         if ( m/Node:\s+(\w+)/ ){
            $nodeName = $1;
            $nodeName =~ tr/[a-z]/[A-Z]/;
         }
      }
   }

   # If couldn't get the node name return from here
   if(!defined ($nodeName)) {
      $logger->error('Unable to get node name');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   $logger->debug("Got the Node Name : $nodeName ");

   my $activeNfs;
   my $nfsIpaddress;
   my $nfsMountPoint;

   # Get IP address and path of active NFS
   $cmd = 'show nfs shelf 1 slot 1 status';
   $logger->debug("Executing command $cmd");
   @cmdResults = $self->execCmd($cmd);
   $logger->debug('Command Results' . Dumper(\@cmdResults));
   foreach (@cmdResults) {
      if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/ ) {
         $activeNfs = $1;
      }
      if (defined $activeNfs) {
         if( m|($activeNfs).*\s+(\d+.\d+.\d+.\d+)\s+(\S+)|i ) {
            $nfsIpaddress = $2;
            $nfsMountPoint = $3;
            last;
         }
      }
   }

   # If there is no IP address return from here
   if(!defined($nfsIpaddress)) {
      $logger->error('Unable to get NFS IP Address');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   $logger->debug("Got the NFS IP address : $nfsIpaddress");

   # If there is no mount point return from here
   if(!defined($nfsMountPoint)) {
      $logger->error('Unable to get NFS mount path');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   $logger->debug("Got the NFS mount path : $nfsMountPoint");

   # Remove node name if present
   $nfsMountPoint =~ s|$nodeName||;

   my $softwarePath;

   # get the software path
   $cmd = 'SHOW NFS SHELF 1 ADMIN';
   $logger->debug("Executing command $cmd");

   @cmdResults = $self->execCmd($cmd);
   $logger->debug('Command Results' . Dumper(\@cmdResults));

   foreach(@cmdResults) {
      if(m/Software Path:\s+(\S+)/) {
         $softwarePath = $1;
      }
   }

   # If we couldn't get the Software path, return from here
   if(!defined($softwarePath)) {
      $logger->error('Unable to get software path');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   $logger->debug("Got the software path : $softwarePath");

   my $coreDirPath = "$nfsMountPoint\/$nodeName\/$softwarePath\/coredump";

   # Remove double slashes if present
   $coreDirPath =~ s|//|/|;


   # esatblish a connection to the NFS server
      my $dsiObj = SonusQA::DSI->new(
                                  -OBJ_HOST     => $nfsIpaddress,
                                  -OBJ_USER     => 'root',
                                  -OBJ_PASSWORD => 'sonus',
                                  -OBJ_COMMTYPE => 'SSH',);

   if(!defined ($dsiObj)) {
      $logger->error('Unable to get connection with NFS');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   $logger->debug('connected to NFS');

   $cmd = 'ls -1 $coreDirPath/core*';

   $logger->debug("Executing command $cmd");

   my @coreFiles = $dsiObj->{conn}->cmd($cmd);

   $logger->error("@coreFiles");

   foreach(@coreFiles) {
      if(m/No such file or directory/i) {
         $logger->info('No cores found');
         $logger->debug('<-- Leaving Sub [0]');
         return 0;
      }
   }

   # Get the number of core files
   my $numcore = $#coreFiles + 1;

   $logger->info("Number of cores in MGW9000 is $numcore");

   my $skipLine = 1;

   # Move all core files
   foreach (@coreFiles) {
      if($skipLine eq 1 ) {
         #skip the first line. It may the command
         $skipLine = 0;
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

         $logger->error("@fileDetail");

         my $fileInfo;

         #start_size of the core file
         my $start_file_size;

         my $skipCommand = 1;
         foreach $fileInfo (@fileDetail) {
            if($skipCommand eq 1) {
               $skipCommand = 0;
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;

            $start_file_size = $1;
         }

         $logger->debug("Start File size of core is $start_file_size");

         sleep(5);
         $core_timer = $core_timer + 5;

         #end_size of the core file;
         my $end_file_size;
         @fileDetail = $dsiObj->{conn}->cmd($cmd);

         $skipCommand = 1;
         foreach $fileInfo (@fileDetail) {
            if($skipCommand eq 1) {
               $skipCommand = 0;
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;

            $end_file_size = $1;
         }

         $logger->debug("End File size of core is $end_file_size");

         if ($start_file_size == $end_file_size) {
            $file_name =~ s/$coreDirPath\///g;
            my $name = join '_',$args{-testCaseID},$file_name;

            # Rename the core to filename with testcase specified
            $cmd = "mv $coreDirPath\/$file_name $coreDirPath\/$name";
            my @retCode = $dsiObj->execCmd($cmd);
            $logger->info("Core found in $coreDirPath\/$name");
            last;
         }
      }
   }

   $logger->debug("<-- Leaving Sub [$numcore]");
   return $numcore;
}

#########################################################################################################

=pod

=head3 getLog2()

    This is same as getLog subroutine. This subroutine to be used when the NFS
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
   -timeStamp   => Time stamp
                   Default => "00000000-000000"

=item Return Values :

   0 - if file is not copied
   (@arr1, @arr2) - file Names

=item Example :

   $Mgw9000Obj->getLog2(-testCaseID => $testId,
                        -logDir     => $log_dir);

   $Mgw9000Obj->getLog2(-testCaseID => $testId,
                        -logDir     => $log_dir,
                        -variant    => "ANSI",
                        -timeStamp  => "20101005-080937");
=item Author :

Rodrigues, Kevin (krodrigues@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

#################################################
sub getLog2 {
#################################################
   my ($self, %args) = @_;
   my $subName = 'getLog2()';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
   $logger->debug('--> Entered Sub');


   $logger->info('RETRIEVING ACTIVE MGW9000 DBG LOG');

   # Set default values before args are processed
   my %a = ( -variant   => 'NONE',
             -timeStamp => "00000000-000000");

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   my $cmd;
   my @cmdresults;
   my $nfsipaddress  = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
   my $NFS_userid    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
   my $NFS_passwd    = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
   my $nfsmountpoint = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'BASEPATH'};

   $logger->info("NFS IP Address => $nfsipaddress and NFS MOUNT POINT => $nfsmountpoint");

   ####################################################
   # Step 1: Checking mandatory args;
   ####################################################
   unless ($nfsipaddress) {
      $logger->warn('NFS IP Address MUST BE DEFINED');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }
   unless ($NFS_userid) {
      $logger->warn('NFS User ID MUST BE DEFINED');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }
   unless ($NFS_passwd) {
      $logger->warn('NFS Password MUST BE DEFINED');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }
   unless ($nfsmountpoint) {
      $logger->warn('NFS Mount Point MUST BE DEFINED');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   ####################################################
   # Step 2: Obtain data from MGW9000;
   ####################################################
   # Get chassis serial number
   $cmd = 'show chassis status';
   $logger->debug("Executing command $cmd");
   @cmdresults = $self->execCmd($cmd);
   $logger->debug("****\n@cmdresults \n****");
   my $serialnumber;
   foreach(@cmdresults) {
      if(m/Serial Number:\s+(\d+)/) {
         $serialnumber = $1;
         $logger->debug("Log Serial No. => $serialnumber ");
      }
   }

   # Determine name of active DBG log
   $cmd = 'show event log all status';
   $logger->debug("Executing command $cmd");
   @cmdresults = $self->execCmd($cmd);
   $logger->debug("****\n@cmdresults \n****");

   my $dbglogname;
   my $syslogname;

   foreach(@cmdresults) {
      if (m/(\w+).DBG/) {
         $dbglogname = "$1";
      }
      if (m/(\w+).SYS/) {
         $syslogname = "$1";
      }
   }

   $logger->debug("The Start file names => $DBGfile, $SYSfile");

   # Start filename
   $DBGfile =~ m/(\w+).DBG/;
   my $startDBGfile = $1;
   $SYSfile =~ m/(\w+).SYS/;
   my $startSYSfile = $1;

   # Arrays to hold filenames, some tests may have multiple files
   my (@DBGlist, @SYSlist);
   $logger->debug("DBG startfile:$startDBGfile  endfile:$dbglogname ");

   # Check for DBG Log number wrapping back to 0
   if ($dbglogname lt $startDBGfile) {
      # Max File Count 32, could be obtained from MGW9000 SHOW EVENT LOG ALL ADMIN
      while ($dbglogname lt $startDBGfile) {
         $logger->debug("dbglogname = $dbglogname, startDBGfile = $startDBGfile");
         push @DBGlist, ($startDBGfile. ".DBG");
         $startDBGfile = hex_inc($startDBGfile);

         # Default File Count 32 (Decimal), could be obtained from MGW9000 SHOW EVENT LOG ALL ADMIN
         if ($startDBGfile eq 1000021) {$startDBGfile = 1000001;}
      }
   }

   # Add logs
   while ($startDBGfile le $dbglogname) {
      $logger->debug("startDBGfile = $startDBGfile, dbglogname = $dbglogname");
      push @DBGlist, ($startDBGfile. ".DBG");
      $startDBGfile = hex_inc($startDBGfile);
   }

   $logger->debug("DBG file list @DBGlist");
   $logger->debug("SYS startfile:$startSYSfile  endfile:$syslogname ");

   # Check for SYS Log number wrapping back to 0
   if ($syslogname lt $startSYSfile) {
      while ($syslogname lt $startSYSfile) {
         $logger->debug(" syslogname = $syslogname, startSYSfile = $startSYSfile");
         push @SYSlist, ($startSYSfile. ".SYS");
         $startSYSfile = hex_inc($startSYSfile);

         # Default File Count 32 (Decimal), could be obtained from MGW9000 SHOW EVENT LOG ALL ADMIN
         if ($startSYSfile eq 1000021) {$startSYSfile = 1000001;}
      }
   }

   # Add logs
   while ($startSYSfile le $syslogname) {
      $logger->debug("startSYSfile = $startSYSfile, syslogname = $syslogname");
      push @SYSlist, ($startSYSfile. ".SYS");
      $startSYSfile = hex_inc($startSYSfile);
   }
   $logger->debug("SYS file list @SYSlist");

   # Check NFS path
   if (($nfsmountpoint =~ m/SonusNFS/) || ($nfsmountpoint =~ m/SonusNFS2/)) {
      $logger->debug("got the mount point. $nfsmountpoint");
   } else {
      $logger->warn(' NFS mount Path needs to be set to either /sonus/SonusNFS or /sonus/SonusNFS2..');
      $logger->debug('<-- Leaving Sub [0]');
      return 0;
   }

   ####################################################
   # Step 3: Create SFTP session;
   ####################################################

   # Create full path to log
   my $timeout = 300;
   my $ats_dir = $a{-logDir};

   # Open a session for SFTP
   if (!defined($self->{sftp_session})) {
       $logger->debug("Creating new sftp session");

       $self->{sftp_session} = new Net::SFTP( $nfsipaddress,
                                              user     => $NFS_userid,
                                              password => $NFS_passwd,
                                              debug    => 0,
                                              );

       unless ( $self->{sftp_session}->status == 0 ) {
           $logger->error(" Could not open session object to required SonusNFS \($nfsipaddress\)");
           $logger->debug('<-- Leaving Sub [0]');
           return 0;
       }
   }

   ####################################################
   # Step 4: Copy logs from remote location;
   ####################################################
   my $atsloc;
   my $dbgfile;
   my $sysfile;

   # get DBG log
   foreach $dbglogname (@DBGlist) {
      $dbgfile = "$nfsmountpoint" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
      $atsloc = "$ats_dir\/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}" . '-MGW9000-' . "$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}-" . "$dbglogname";

      $logger->debug("Transferring $dbgfile to $atsloc");

      eval {
          # get the file
          $self->{sftp_session}->get($dbgfile, $atsloc);

          unless ( $self->{sftp_session}->status == 0 ) {
              $logger->error(" Could not transfer $dbgfile to $nfsipaddress");
          }
          else {
              $dbglogname = $atsloc;
          }
      };
      if ($@) {
          $logger->error(" Could not transfer $dbgfile to $nfsipaddress");
          $logger->error(" Error was: $@");
      }
   }

   # get SYS file
   foreach $syslogname (@SYSlist) {
      $sysfile = "$nfsmountpoint" . '/evlog/' . "$serialnumber" . '/SYS/' . "$syslogname";
      $atsloc = "$ats_dir\/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}" . '-MGW9000-' . "$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}-" . "$syslogname";

      $logger->debug("Transferring $sysfile to $atsloc");

      eval {
          # get the file
          $self->{sftp_session}->get($sysfile, $atsloc);

          unless ( $self->{sftp_session}->status == 0 ) {
              $logger->error(" Could not transfer $sysfile to $nfsipaddress");
          }
          else {
              $syslogname = $atsloc;
          }
      };
      if ($@) {
          $logger->error(" Could not transfer $sysfile to $nfsipaddress");
          $logger->error(" Error was: $@");
      }
   }

   # Return ATS Location of files to allow parsing
   $logger->debug('<-- Leaving Sub');
   return (@DBGlist, @SYSlist);
}

#########################################################################################################

=pod

=head3 MnsSwitchover()

    This function does not need to know the card or redundancy group.
    It switches over the MNS card and reconnects.
    A flag to indicate we should wait for the cards to re-synch can be used.

=over

=item Arguments (Optional):

   -waitForSynch => boolean value to determine if we should wait for the cards to synch

=back

=cut

#################################################
sub MnsSwitchover {
#################################################

  my ($self, %args) = @_;
  my $subName = 'MnsSwitchover()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug('--> Entered Sub');

  my %a = ( -waitForSynch => 0 );
  my $redundGroup = '';
  my $redundSynch = 0;
  my $timeout = 500;
  my ($line, $t0, $cmdString);

  my $scr_logger = Log::Log4perl->get_logger('SCREEN');

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  my $mgw_name = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

  # run the CLI
  $cmdString = 'show redundancy group summary';

  $logger->info("cmdString : $cmdString for MGW9000 $a{-mgwNo}");

  unless($self->execCmd($cmdString)) {
    $logger->error('Error in executing the CLI');
    $logger->debug('<-- Leaving Sub [0]');
    return 0;
  }

  $logger->info('Output : ' . Dumper ($self->{CMDRESULTS}));

  my @fields;

  foreach $line ( @{ $self->{CMDRESULTS}} ) {
    @fields = split(' ', $line);
    if(($fields[3] =~ 'MNS') && ($fields[5] eq 'ENABLED')) {
      $redundGroup = $fields[0];

      $cmdString = "configure redundancy group $redundGroup switchover";
      $logger->info("line : $cmdString");
      my $mgw_timeout = $self->{DEFAULTTIMEOUT};
      $self->{DEFAULTTIMEOUT} = 5;

      $t0 = [gettimeofday];
      if($self->execCmd($cmdString)) {
        $logger->error('Error in executing MNS SWITCHOVER: ' . Dumper($self->{CMDRESULTS}));
        foreach $line ( @{ $self->{CMDRESULTS}} ) {
          if($line =~ 'not synced to the standby') {
            while((tv_interval($t0) <= $timeout) && ($redundSynch == 0)) {
              sleep 30;
              if($self->execCmd($cmdString)) {
                $logger->error('Error in executing MNS SWITCHOVER : ' . Dumper($self->{CMDRESULTS}));
              }
              else {
                $logger->info('MNS Switchover successful');
                $redundSynch = 1;
              }
            }
            if(!$redundSynch) {
              $logger->error('MNS Switchover unsuccessful');
              $logger->debug('<-- Leaving Sub [0]');
              return 0;
            }
          }
          else {
            $logger->debug('<-- Leaving Sub [0]');
            return 0;
          }
        }
      }

      $scr_logger->debug(" Reconnecting to MGW9000 '$mgw_name'");
      unless ($self->reconnect( -retry_timeout => 180, -conn_timeout  => 10, )) {
        $scr_logger->error(" Failed to reconnect to MGW9000 object '$mgw_name' to MGW9000 within 3 minutes of rebooting. Exiting...");
        $logger->debug('<-- Leaving Sub [0]');
        return 0;
      }
     $self->{DEFAULTTIMEOUT} = $mgw_timeout;

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
              $logger->info('Active synched to Standby');
              $redundSynch = 1;
              last;
            }
            elsif($line =~ m/^\s*Number of Synced Clients:\s+0\s*$/i ) {
              $logger->info('Waiting for Active to synch with Standby');
            }
          }
        }
        if(!$redundSynch) {
          $logger->info('Active NOT synched with Standby - timeout');
        }
      }
      $logger->debug('<-- Leaving Sub [1]');
      return 1;
    }
  }
  $logger->debug('<-- Leaving Sub [0]');
  return 0;
}

#########################################################################################################

=pod

=head3 getSlotFromPort()

    This function takes the MGW9000 port and returns the card on which it is configured.

=over

=item Arguments (Optional):

   -port => port # Name of the Port
   -type => port_type # E1 or T1 etc

=back

=cut

#################################################
sub getSlotFromPort {
#################################################

  my ($self, %args) = @_;
  my $subName = 'getSlotFromPort()';
  my $redundGroup = "";
  my %a;
  my ($line, $cmdString);

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug('--> Entered Sub');

  my $scr_logger = Log::Log4perl->get_logger('SCREEN');

  # get the arguments
  while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

  if((!defined $a{-port}) or (!defined$a{-type})) {
    $logger->error("Error - required values of port and type not defined $a{-port} $a{-type}");
    $logger->debug('<-- Leaving Sub [0]');
    return 0;
  }

  $cmdString = "SHOW $a{-type} $a{-port} STATUS";

  # run the CLI
  unless($self->execCmd($cmdString)) {
    $logger->error("Error in executing the CLI");
    $logger->debug('<-- Leaving Sub [0]');
    return 0;
  }

  $logger->info("Output : " . Dumper ($self->{CMDRESULTS}));

  my @fields;

  foreach $line ( @{ $self->{CMDRESULTS}} ) {
    @fields = split(' ', $line);
    if($fields[2] =~ "Slot:") {
      $logger->debug("<-- Leaving Sub [$fields[3]]");
      return $fields[3];
    }
  }
  $logger->debug('<-- Leaving Sub [0]');
  return 0;
}

#########################################################################################################

=pod

=head3 searchDBGlog()

    This subroutine is used to find the number of occurrences of a list of patterns in the MGW9000 DBG log

=over

=item Arguments :

   Array containing the list of patterns to be searched on the MGW9000 debug log

=item Return Values :

   Hssh containing the pattern being searched as the key and the number of occurrences of the same in the DBG log as the value

=item Example :

  my @patt = ("msg","msg =","abc");
  my %res = $Mgw9000Obj->searchDBGlog(\@patt);

=item Author :

Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

#################################################
sub searchDBGlog {
#################################################
    my ($self,$patterns) = @_;
    my (@cmdresults, $cmd, $nodename, $activenfs, $nfsipaddress, $nfsmountpoint, $serialnumber,
        $dbglogname, $dbglogfullpath, $dsiObj, @dbglog, %returnHash);
    my @pattArray = @$patterns;
    my ($tmpStr, $cmd1, $string, @tmp1, $retVal,$patt);

    my $subName = 'searchDBGlog()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug('--> Entered Sub');

    $logger->info(' RETRIEVING ACTIVE MGW9000 DBG LOG');

    # Get node name
    $cmd = 'show node admin';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if ( m/Node:\s+(\w+)/ ){
            $nodename = $1;
            $nodename =~ tr/[a-z]/[A-Z]/;
        }
    }
    if (!defined($nodename)) { $logger->warn(' NODE NAME MUST BE DEFINED'); return $nodename; }

    # Get IP address and path of active NFS
    $cmd = 'show nfs shelf 1 slot 1 status';
    @cmdresults = $self->execCmd($cmd);
    foreach (@cmdresults) {
        if( m/Active NFS Server:\s*(PRIMARY|SECONDARY)/i ) {
            $activenfs = $1;
        }
        if (defined $activenfs) {
            if( (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/sonus/\w+)|i) || (m|($activenfs).*\s+(\d+.\d+.\d+.\d+).*(/\w+)|i) ) {
                $nfsipaddress = $2;
                $nfsmountpoint = $3;
                last;
            }
        }
    }

    # Get chassis serial number
    $cmd = 'show chassis status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if(m/Serial Number:\s+(\d+)/) {
            $serialnumber = $1;
        }
    }

    # Determine name of active DBG log
    $cmd = 'show event log all status';
    @cmdresults = $self->execCmd($cmd);
    foreach(@cmdresults) {
        if (m/(\w+.DBG)/) {
            $dbglogname = "$1";
        }
    }

    if ($nfsmountpoint =~ m/PsxQANFS/) {
        # Create full path to log
        $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => $nfsipaddress,
            -OBJ_USER => 'root',
            -OBJ_PASSWORD => 'sonus',
            -OBJ_COMMTYPE => 'SSH',);
    }

    if ($nfsmountpoint =~ m/SonusNFS/) {
        # Create full path to log
        $dbglogfullpath = '/export/home'."$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        $logger->debug("\t\$nfsipaddress = $nfsipaddress \n\t\$nfsmountpoint = $nfsmountpoint \n\t\$nodename = $nodename \n\t\$serialnumber = $serialnumber \n\t\$dbglogname = $dbglogname \n\t\$dbglogfullpath = $dbglogfullpath");
        # Remove double slashes if present
        #$acctlogfullpath =~ s|//|/|;

        # Create DSI object and get log
            $dsiObj = SonusQA::DSI->new(
                -OBJ_HOST => $nfsipaddress,
                -OBJ_USER => 'root',
                -OBJ_PASSWORD => 'sonus',
                -OBJ_COMMTYPE => 'SSH',);
    }

    if (($nfsmountpoint =~ m/MarlinQANFS/) || ($nfsmountpoint =~ m/SonusQANFS/)) {
        if ($nfsmountpoint =~ m/MarlinQANFS/) {
            $dbglogfullpath = '/sonus/SonusQANFS/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        }
        else {
            $dbglogfullpath = "$nfsmountpoint" .'/' . "$nodename" . '/evlog/' . "$serialnumber" . '/DBG/' . "$dbglogname";
        }

        # Create DSI object and get log
        $dsiObj = SonusQA::DSI->new(
            -OBJ_HOST => 'talc',
            -OBJ_USER => 'autouser',
            -OBJ_PASSWORD => 'autouser',
            -OBJ_COMMTYPE => 'SSH',);
    }

    foreach $patt (@pattArray){
        $cmd1 = 'grep -c "'.$patt.'" '. $dbglogfullpath ;

        my @cmdResults;
            unless (@cmdResults = $dsiObj->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
              $logger->warn("  COMMAND EXECUTION ERROR OCCURRED");
            }

        $string = $cmdResults[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $logger->debug(" Number of occurrences of the string \"$patt\" in $dbglogfullpath is $string");
        unless($string){
           $logger->error(" No occurrence of $patt in $dbglogfullpath");
           $string = 0;
        }
        $returnHash{$patt} = $string;
    }
    $logger->debug('<-- Leaving Sub');
    return %returnHash;

}

#########################################################################################################

#################################################
sub AUTOLOAD {
#################################################
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

1;
__END__
