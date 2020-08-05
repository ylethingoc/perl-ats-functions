package SonusQA::BGF::BGFHELPER;

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;

sub enterPrivateConfigMode {

    my $sub_name = "enterPrivateConfigMode";
    my ($self) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    unless ( $self->execCliCmd("configure private") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not enter configure private mode");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Entered config private mode");

    return 1;
}

sub configLog {

    my($self,$logLvl,$filterLvl)=@_;
    my $sub_name = "configLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Starting $sub_name");

        &SonusQA::Utils::cleanresults("Results");
        $self->execCliCmd("set oam eventLog typeAdmin $logLvl filterLevel $filterLvl"); 
        $self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name");

}

sub configAddressContext {

    my ($self,$addCtxt,$ipIfGpName,$ipIf,$prefix,$class,$dryupTO) = @_ ;
    my $sub_name = "configAddressContext";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Starting $sub_name");

        $self->execCliCmd("set addressContext $addCtxt ipInterfaceGroup $ipIfGpName ipInterface $ipIf ceName $self->{TMS_ALIAS_DATA}->{CE}->{1}->{HOSTNAME} portName pkt0 ipAddress $self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{IP} prefix $prefix");
        $self->execCliCmd("edit addressContext $addCtxt ipInterfaceGroup $ipIfGpName ipInterface $ipIf"); 
        $self->execCliCmd("set dryupTimeout $dryupTO");
        $self->execCliCmd("top");
        $self->execCliCmd("commit");

        $self->execCliCmd("set addressContext $addCtxt ipInterfaceGroup $ipIfGpName ipInterface $ipIf mode inService");
        $self->execCliCmd("set addressContext $addCtxt ipInterfaceGroup $ipIfGpName ipInterface $ipIf state enabled");  
        $self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name");

} 

sub configProfile {

    my ($self,$mpProfName,$h248EnSch,$iniRtt,$prtv,$etv,$mgstv,$mgcstv) = @_ ;
    my $sub_name = "configProfile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Starting $sub_name"); 

        $self->execCliCmd("set profiles mgProfile $mpProfName h248EncodingScheme $h248EnSch initialRtt $iniRtt");
        $self->execCliCmd("set profiles mgProfile $mpProfName baseRootPackage mgcProvisionalResponseTimerValue $prtv normalMgcExecutionTimerValue $etv");
        $self->execCliCmd("set profiles mgProfile $mpProfName segmentationPackage mgSegmentationTimerValue $mgstv mgcSegmentationTimerValue $mgcstv"); 

        $self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name");

}


sub configVirtualMediaGatewayForAddressContext {

    my ($self,$addCtxt,$vMgw,$mgwProfName,$ipIfGpName,$ipIf,$h248SigPort,$mgwCtlr,$mgwCtlr2,$mgwCtlrRole,$mgwCtlrRole2,$viGrp,$realm,$dscp,$prefer) = @_ ;
    my $sub_name = "configVirtualMediaGatewayForAddressContext";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    $logger->debug(__PACKAGE__ . ".$sub_name:  Starting $sub_name");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayServiceProfileName $mgwProfName");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw state enabled");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw h248SigPort $h248SigPort ipInterfaceGroupName $ipIfGpName ipAddress $self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{IP} portNumber $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{PORT}");
    $self->execCliCmd("commit");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw h248SigPort $h248SigPort state enabled");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr addressType ipV4Addr ipAddress $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{IP} portNumber $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{PORT} state enabled");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr role $mgwCtlrRole");
    $self->execCliCmd("commit");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr role $mgwCtlrRole mode inService");
    $self->execCliCmd("commit");
$self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr2 addressType ipV4Addr ipAddress $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{3}->{IP} portNumber $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{3}->{PORT} state enabled");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr2 role $mgwCtlrRole2");
    $self->execCliCmd("commit");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mediaGatewayController $mgwCtlr2 role $mgwCtlrRole2 mode inService");
    $self->execCliCmd("commit");

    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw mode inService");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw virtualInterfaceGroup $viGrp state enabled");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw virtualInterfaceGroup $viGrp realm $realm ipInterfaceGroupName $ipIfGpName dscp $dscp");
    $self->execCliCmd("commit");
    $self->execCliCmd("set addressContext $addCtxt virtualMediaGateway $vMgw virtualInterfaceGroup $viGrp mode inService");
    $self->execCliCmd("commit");
   $self->execCliCmd("set addressContext $addCtxt staticRoute $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{2}->{IP} 24 $self->{TMS_ALIAS_DATA}->{NIF}->{1}->{DEFAULT_GATEWAY} $ipIfGpName $ipIf preference $prefer");
$self->execCliCmd("commit");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving $sub_name");

} 

sub verifyAlarm {

    my ($self,$pattern,@preOutput) = @_ ;
    my $result = 0;
    my $sub_name = "verifyAlarm";
    my @postOutput;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $pattern ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory search pattern  empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @preOutput ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Pre Output is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");

    }
    my $cmd="show table alarms currentStatus";
    unless (@postOutput = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
   my $count = $#preOutput;
   my @output = @postOutput[$count..$#postOutput];
   @output = grep(/$pattern/ , @output);
   if(@output){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

}


sub parseLogFiles {

    my ($self,$logfile, @logstring) = @_ ;
    my $flag = 0;
    my $sub_name = "parseLogFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $logfile ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filename empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @logstring ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory search pattern is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");

    }

    my $cmd="cd /var/log/sonus/sbx/evlog";
    unless ( $self->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @content=();
       foreach(@logstring){
                my $cmd2="grep \"$_\" $logfile | wc -l";
                my @matches = $self->{conn}->cmd($cmd2);
                my $matches = $matches[0];
                if($matches ge 1){
                    $logger->debug(__PACKAGE__ . ".$sub_name: PARSE SUCCESS: Expected -> \"$_\" in \"$logfile\": Count of Matches -> $matches");
                        }
                        else
                        {
                            $logger->debug(__PACKAGE__ . ".$sub_name: PARSE FAILED: Expected :: -> \"$_\" in \"$logfile\" ");
                                $flag = 1;
                        }
                }


    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }

}


sub checkforCore {

    my ($self, $tcid ,$copyLocation) = @_ ;

    my $sub_name = "checkforCore";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd="cd /var/log/sonus/sbx/coredump";
    unless ( $self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $file_size;
    my @corefile=();
    my @content=();

    my $cmd1="ls -lrt  newCoredumps";
    unless ( @content = $self->{conn}->cmd($cmd1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach(@content){
            $file_size    = (split /\s+/,$_)[4];
            $logger->debug(__PACKAGE__ . ".$sub_name: file Size: $file_size");
            last;
    }

    if($file_size == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: No new core generated");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd3="cat newCoredumps";
    unless ( @content = $self->{conn}->cmd($cmd3)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: Core Dump Found !!! Creating Target Directory .");
    unless ( $self->execShellCmd( "mkdir -p $copyLocation" )) {
    $logger->debug(__PACKAGE__ . ".$sub_name: Could not create Core Storage Directory ");
             }
    $self->execShellCmd('cat /dev/null > newCoredumps'); # To clear the contents of file "newCoredumps".
    foreach (@content){
        my $corefile = (split /\//,$_)[6];
        $corefile =~s/\s//g;
        my $newcorefile = "$corefile"."_".$tcid;
        my $cmd2="\\cp $corefile $copyLocation/$newcorefile";
$logger->debug(__PACKAGE__ . ".$sub_name: $cmd2");
        unless ( $self->{conn}->cmd($cmd2)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd2 .");
	        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        	$logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Core file $corefile copied to Path $copyLocation");
    }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
}

sub getRecentLogFiles {
    
    my ($self,$log_type, $numberoffiles) = @_ ;
    
    my $sub_name = "getRecentLogFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    
    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $log_type ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory log event type input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }   
        
    my $cmd="cd /var/log/sonus/sbx/evlog";
    unless ( $self->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }                               
                                    
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking the latest $numberoffiles $log_type log files.");
                                    
    $cmd="ls -ltr 10*.$log_type|tail -$numberoffiles";
    unless ( $self->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @file_name;
    foreach ( @{$self->{CMDRESULTS}} )
    {
        chomp;
        push @file_name,(split /\s+/,$_)[-1];
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub filenames : @file_name");
    my $return = $#file_name +1;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$return]");
    return @file_name;
}


sub storeLogs {

    my ($self,$filename,$tcid,$copyLocation,$logStoreFlag) = @_ ;
    my $home_dir;
    my $sub_name = "storeLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $filename ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filename empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");

    }

   if($logStoreFlag) {

    my $cmd="\\cp $filename $copyLocation/$filename"."_".$tcid;
    unless ( $self->execShellCmd($cmd))  {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
        }
     }
   else {
   ## might put into a different sub

   if ( $ENV{ HOME } ) {
        $home_dir = $ENV{ HOME };
   }else {
         my $name = $ENV{ USER };
        if ( system( "ls /home/$name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
            $home_dir   = "/home/$name";
        }elsif ( system( "ls /export/home/$name/ > /dev/null" ) == 0 ) {# to run silently, redirecting output to /dev/null
            $home_dir   = "/export/home/$name";
        } else {
            print "*** Could not establish users home directory... using /tmp ***\n";
            $home_dir = "/tmp";
        }
   }

   my $dir = "$home_dir/ats_user/logs/testlogs/";

   unless ( system ( "mkdir -p $dir" ) == 0 ) {
        die "Could not create user log directory in $home_dir/ ";
   }

   my $locallogname = $dir.$tcid."_".$filename;
        $logger->debug(__PACKAGE__ . ".$sub_name: $locallogname");

    my $cmd="cd /var/log/sonus/sbx/evlog";
    unless ( $self->execShellCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                                                                          return 0;
    }

    my @content=();

    my $cmd1="cat $filename";
    unless ( @content = $self->{conn}->cmd($cmd1)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd1 .");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    open (FH,">$locallogname");
    print FH "@content";
    close(FH);
  }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;

}

sub rollLogs {

    my ($self,$type) = @_ ;
    my @logtype = ();
    my $sub_name = "rollLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;

    }

    if (defined($type)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: trying to roll over $type log");
        push @logtype,$type;

    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: so trying to roll over acct, debug and system logs");
        @logtype = ("acct", "debug", "system","trace");

    }

    foreach (@logtype){
        sleep(4);
        my $cmd = "request oam eventLog typeAdmin $_ rolloverLogNow";
        unless ($self->execCliCmd($cmd) ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  Cannot issue $cmd'");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
                }
    }

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;

}

sub compareSystemProcesses {

    my ($self,$before, $after) = @_ ;
    my @logtype = ();
    my $sub_name = "compareSystemProcesses";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @processnames =qw(asp_amf CE_2N_Comp_ChmProcess CE_2N_Comp_FmMasterProcess CE_2N_Comp_CpxAppProc CE_2N_Comp_SmProcess CE_2N_Comp_EnmProcessMain CE_2N_Comp_NimProcess CE_2N_Comp_SsaProcess CE_2N_Comp_PesProcess CE_2N_Comp_ScpaProcess CE_2N_Comp_PipeProcess CE_2N_Comp_PrsProcess CE_2N_Comp_SamProcess CE_2N_Comp_DsProcess CE_2N_Comp_DnsProcess CE_2N_Comp_CamProcess CE_2N_Comp_ImProcess CE_2N_Comp_IpmProcess CE_2N_Comp_PathchkProcess CE_2N_Comp_DiamProcess CE_2N_Comp_ScmProcess_0 CE_2N_Comp_ScmProcess_1 CE_2N_Comp_ScmProcess_2 CE_2N_Comp_ScmProcess_3 CE_2N_Comp_RtmProcess CE_2N_Comp_IkeProcess);


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if(defined($before) && defined($after)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: comparing process info $before and $after");
    }else{
        $before = 1;
        $after = 2;
        $logger->debug(__PACKAGE__ . ".$sub_name: comparing process info $before and $after");
    }

    my $flag = 1;
    foreach (@processnames){
        #check pid is same
        $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ PID before: $self->{1}->{systemprocess}->{$_}->{PID} PID After: $self->{2}->{systemprocess}->{$_}->{PID}");
        unless($self->{1}->{systemprocess}->{$_}->{PID} eq $self->{2}->{systemprocess}->{$_}->{PID}){
                $flag = 0;
                $logger->debug(__PACKAGE__ . ".$sub_name: PID has changed for Process : $_");
                $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ PID before: $self->{1}->{systemprocess}->{$_}->{PID} PID After: $self->{2}->{systemprocess}->{$_}->{PID}");
        };

        #check state is same
         $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ STATE before: $self->{1}->{systemprocess}->{$_}->{STATE} STATE After: $self->{2}->{systemprocess}->{$_}->{STATE}");
        unless($self->{1}->{systemprocess}->{$_}->{STATE} eq $self->{2}->{systemprocess}->{$_}->{STATE}){
                $flag = 0;
                $logger->debug(__PACKAGE__ . ".$sub_name: STATE has changed for Process : $_");
                $logger->debug(__PACKAGE__ . ".$sub_name: Process : $_ STATE before: $self->{1}->{systemprocess}->{$_}->{STATE} STATE After: $self->{2}->{systemprocess}->{$_}->{STATE}");
        };

    } #foreach


    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

}

sub getRollbackInfo {

    my ($self) = @_ ;

    my $sub_name = "getRollbackInfo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @content=();
    $self->execCmd("configure private");
    sleep(2);
    my $cmd="rollback \t\t";
    unless ( @content = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@content){
        if(m/^\s+(0)\s+(-)\s+(\d+-\d+-\d+)\s+(\d+:\d+:\d+)\s+(\w+)/){
                        $logger->debug(__PACKAGE__ . ".$sub_name: $_");
                        $self->{rollback}->{basetimestamp} = $4;
                        $self->{rollback}->{baseindex} = 0;
        }
    }

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
        #return ($self->{rollback}->{basetimestamp});
}

sub RollbackTo {

    my ($self,$timestamp) = @_ ;

    my $sub_name = "RollbackTo";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Rolling To TimeStamp : $timestamp");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $timestamp ) {
        $logger->error(__PACKAGE__ . ".$sub_name: timestamp is empty.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @content=();
    $self->execCmd("configure");
    my $cmd="rollback \t\t";
    unless ( @content = $self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd .");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $flag = 0;
    foreach (@content){
        if(m/^\s+(\d+)\s+(-)\s+(\d+-\d+-\d+)\s+(\d+:\d+:\d+)\s+(\w+)/){
                #$logger->debug(__PACKAGE__ . ".$sub_name: $_");
                if($4 eq $timestamp){
                        $self->{rollback}->{baseindex} = $1;
                        $flag = 1;
                        last;
                $logger->debug(__PACKAGE__ . ".$sub_name: $_");
                }
        }
    }

    if($flag){
        if ($self->{rollback}->{baseindex} == 0) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Roll back skipped as the found index is 0 !! ");
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Roll back index found ");
            my $indexNew = $self->{rollback}->{baseindex};
            $indexNew = $indexNew -1;
            $self->execCliCmd("rollback $indexNew");
            $self->execCliCmd("commit");
            $logger->debug(__PACKAGE__ . ".$sub_name: Rolled back to Index : $indexNew"); }
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Roll back info not found");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to leave config mode.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
 return 1;
}

sub verifyTable {

    my ($self,$cmd,$cliHash,$mode) = @_ ;
    my $sub_name = "verifyTable";
    my (@output,$key,$value,@value,@table,%table);
    my $flag = 0;
    my %cliHash = %$cliHash;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CLI command empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cliHash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Hash Reference empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ########  Execute input CLI Command #########################################

    if ($mode =~m/private/) {
    $self->execCmd("configure private");
    @output = $self->execCmd($cmd);
    $self->leaveConfigureSession;
    }
    else {
    @output = $self->execCmd($cmd);
    }
    foreach (@output)
      {
        $_ =~ s/.*\s+\{\s*//;
        $_ =~ s/\}\s*\n//;
        $_ =~ s/\[ok\].*//s;
        $_ =~ s/^\n$//;
        $_ =~ s/^\s+//;
        $_ =~ s/\;//;
        ($key, @value) = split /\s+/, $_;
        $value = join " ", @value;
        push @table, ($key, $value);
     }

    %table = @table;
    foreach $key (keys %cliHash) {
    if ($table{$key} eq $cliHash{$key}) {
         $logger->debug(__PACKAGE__ . ".$sub_name: Key: $key  Actual: $table{$key}  Expected: $cliHash{$key}  MATCH SUCCESS !!");
     }
     else {
         $logger->debug(__PACKAGE__ . ".$sub_name: Key: $key  Actual: $table{$key}  Expected: $cliHash{$key}  MATCH FAILED !!");
         $flag = 1;
         }
    }
    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }
}

sub kick_Off {

    my ($self) = @_ ;
    my $home_dir;
    my $sub_name = "kick_Off";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    ######## get base config rollback info ######
    unless ( $self->getRollbackInfo) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not get the base config Roll back info.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######## Roll log files ######

    unless ( $self->rollLogs) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot roll logs.");
        return 0;
    }

    ######## get system process info ########

    unless ( $self->enterLinuxShellViaDshBecomeRoot ("sonus", "sonus1" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        return 0;
    }

    unless ( $self->getSystemProcessInfo(1) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot get system process info.");
        return 0;
    }

    unless ($self->leaveDshLinuxShell) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get out of dsh linux shell.");
    }

}

sub wind_Up {

    my ($self,$tcid,$copyLocation,$logStoreFlag) = @_ ;
    my $coreflag = 0;
    my $rollflag = 0;
    my $numberoflogfiles = 1;
    my @logtype = ("ACT", "DBG", "SYS","TRC");
    my ($copyCoreLocation,$copyLogLocation,@logfilenames);
    my $sub_name = "wind_Up";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

   unless(defined ($logStoreFlag)){
        $logger->warn(__PACKAGE__ . ".$sub_name: The flag for log storage not defined !! Using Default Value 1 ");
        $logStoreFlag = 1;
   }

   unless ( $self->enterLinuxShellViaDshBecomeRoot ("sonus", "sonus1" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot Enter Shell via Dsh.");
        return 0;
    }
  if ($logStoreFlag)
  {
    if(defined ($copyLocation)) {
        $copyCoreLocation = $copyLocation."/coredump";
        $copyLogLocation = $copyLocation."/logs";
        unless ( $self->execShellCmd( "mkdir -p $copyLogLocation" )) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Could not create Log Directory ");
        $logStoreFlag = 0;
        }
  }
else {
        $logger->warn(__PACKAGE__ . ".$sub_name: The location to copy Logs/Corefiles not Defined !! By Default the Logs will be stored at the SBX server at Path => /var/log/sonus/ats_user/logs ");
        $logStoreFlag = 1;
        $copyLogLocation = "/var/log/sonus/ats_user/logs";
        $copyCoreLocation = "/var/log/sonus/ats_user/coredump";
        unless ( $self->execShellCmd( "mkdir -p $copyLogLocation" ) ) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Could not create Log Directory ");
        $logStoreFlag = 0;
        }
   }

 }

 else {
        $logger->warn(__PACKAGE__ . ".$sub_name: The Logs will be stored at user's local home directory as prompted. !!");
        if(defined ($copyLocation)) {
        $copyCoreLocation = $copyLocation."/coredump";
           }
        else {
        $copyCoreLocation = "/var/log/sonus/ats_user/coredump";
    }


 }
          ######## compare system process info ############################

    if ( $self->getSystemProcessInfo(2) ) {
            unless ( $self->compareSystemProcesses) {
                $logger->debug(__PACKAGE__ . ".$sub_name:  Processes not the same as before");
            }
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name:  Cannot get system process info");
        $logger->debug(__PACKAGE__ . ".$sub_name:  Skipping Process compare");

    }

    ######## check for core ########################################

    if ($self->checkforCore($tcid,$copyCoreLocation)) {
        $logger->error(__PACKAGE__ . " $sub_name:   found core.");
        #$numberoflogfiles = 2;
        $coreflag = 1;
    }

   ################### Get Recent Log Files & Store Logs ##########################
    foreach (@logtype){
         push @logfilenames , $self->getRecentLogFiles($_,$numberoflogfiles);

    }
    unless ($#logfilenames != -1 ) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get the log file names.");
        return 0;
    }

    foreach (@logfilenames){
        unless ($self->storeLogs($_,$tcid,$copyLogLocation,$logStoreFlag) ) {
                $logger->error(__PACKAGE__ . " $sub_name:   Failed to store the log file: $_.");
        }
    }

    unless ($self->leaveDshLinuxShell) {
        $logger->error(__PACKAGE__ . " $sub_name:   Failed to get out of dsh linux shell.");
        return 0;
    }

    ######## cleanup - Rollback to Base Configuration  ###################

    unless ( $self->RollbackTo($self->{rollback}->{basetimestamp})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Rollback to base config failed .");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        $rollflag = 1;
    }

        if ( $coreflag == 1 || $rollflag == 1)
         {
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
         }
        else {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
        }
}


1;
