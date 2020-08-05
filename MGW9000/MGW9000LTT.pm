package SonusQA::MGW9000::MGW9000LTT;

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

2010-10-20

=cut

#########################################################################################################

=pod

=head1 NAME

SonusQA::MGW9000::MGW9000LTT - Perl module for Sonus Networks MGW9000 Load Test Tool (LTT) interaction

=head1 SYNOPSIS

=head1 DESCRIPTION

  This module provides an interface for the MGW9000 switch for Load Test

=head1 AUTHORS

  See Inline documentation for contributors.

=head1 REQUIRES

  Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, XML::Simple, Storable, Data::Dumper, SonusQA::Utils,

=head2 SUB-ROUTINES

    createLoadTest();
    deleteLoadTest();
    configureLoadTest();
    help();
    usage();
    manhelp();
    configLTT();
    startLTT();
    stopLTT();
    verifyDataPath();
    showLoadTest();
    AUTOLOAD();

=cut

#########################################################################################################

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use Module::Locate qw /locate/;

our $VERSION = "1.0";

use vars qw($self);

#########################################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::createLoadTest(<LOADTESTNAME>)

 Routine to create LTT configruation.
  
=over

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name

=item Returns

  Boolean
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$Mgw9000Obj->createLoadTest("TESTINGLOADTEST");

=back

=cut

#################################################
sub createLoadTest(){
#################################################
  my ($self,$loadTestName)=@_;
  my $subName = 'createLoadTest()';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  $logger->debug("--> Entered Sub");

  my ($cmd, @cmdResults);
  my $flag = 1;

  unless( defined($loadTestName) ) {
      $logger->warn(" MANADATORY NAME PARAMETER MISSING.");
      $logger->debug("<-- Leaving Sub [0]");
      return 0;
  };

  $cmd = sprintf("CREATE LOADTEST %s", $loadTestName);
  $logger->debug(" FORUMULATED CMD: $cmd");
  
  @cmdResults = $self->execCmd($cmd);
  
  foreach(@cmdResults) {
      if(m/^error/i){
          $logger->warn(" CMD RESULT: $_");
          if($self->{CMDERRORFLAG}){
              $logger->warn(" CMDERROR FLAG IS POSITIVE - CALLING ERROR");
              &error("CMD FAILURE: $cmd");
          }
          $flag = 0;
          next;
      }
  }

  $logger->debug("<-- Leaving Sub [$flag]");
  return $flag;
}


#########################################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::deleteLoadTest(<LOADTESTNAME>)

 Routine to delete LTT configruation.
  
=over

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name to delete

=item Returns

  Boolean
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$Mgw9000Obj->deleteLoadTest("TESTINGLOADTEST");

=back

=cut

#################################################
sub deleteLoadTest(){
#################################################
    my ($self,$loadTestName)=@_;
    my $subName = 'deleteLoadTest()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my ($cmd, @cmdResults);
    my $flag = 1;

    unless(defined($loadTestName)){
        $logger->warn(" MANADATORY NAME PARAMETER MISSING.");
        $logger->debug("<-- Leaving Sub [0]");
        return 0;
    };

    $cmd = sprintf("DELETE LOADTEST %s", $loadTestName);
    $logger->debug(" FORUMULATED CMD: $cmd");

    @cmdResults = $self->execCmd($cmd);

    foreach(@cmdResults) {
        if(m/^error/i){
            $logger->warn(" CMD RESULT: $_");
            if($self->{CMDERRORFLAG}){
                $logger->warn(" CMDERROR FLAG IS POSITIVE - CALLING ERROR");
                &error("CMD FAILURE: $cmd");
            }
            $flag = 0;
            next;
        }
    }

    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
}


#########################################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::configureLoadTest(<LOADTESTNAME>, [<PARAM ARRAY> | <PARAM SCALAR>])

 Routine to configure LTT configruation.
  
=over

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name
  
  PARAM ARRAY (Array)
  If an ARRAY is passed in this argument slot, it will be concatenated in order, and presented as a part of
  forumulated command
  
  PARAM SCALAR
  If an SCALAR is passed in this argument slot, it will be concatenated and presented as a part of
  forumulated command
  
=item Returns

  Boolean
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$Mgw9000Obj->createLoadTest("TESTINGLOADTEST");
  &$Mgw9000Obj->configureLoadTest("TESTINGLOADTEST",["PARAM1"=>"VALUE1","PARAM2"=>"VALUE2","PARAM3"=>"VALUE3"]);
  &$Mgw9000Obj->configureLoadTest("TESTINGLOADTEST","NOTARRAY");

=back

=cut

#################################################
sub configureLoadTest(){
#################################################
    my($self, $loadTestName, $params)=@_;
    my $subName = 'configureLoadTest()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my ($cmd, $cmdParams, @cmdResults);
    my $flag = 1;

    unless(defined($loadTestName) && defined($params)){
        $logger->warn(" INVALID ARGUMENTS TO METHOD");
        $logger->warn(" \$loadTestname: $loadTestName");
        $logger->warn(" \$params: " . (ref($params) eq "ARRAY" ? join(" ", @{$params}) : $params));
        $logger->debug("<-- Leaving Sub [0]");
        return 0;
    };

    $cmdParams = ref($params) eq "ARRAY" ? join( " ", map split, @{$params} ) : $params;
    $cmd = sprintf("CONFIGURE LOADTEST %s %s", $loadTestName, $cmdParams);
    $logger->debug(" FORUMULATE CMD: $cmd");
  
    @cmdResults = $self->execCmd($cmd);
  
    foreach(@cmdResults) {
        if(m/^error/i){
            $logger->warn(" CMD RESULT: $_");
            if($self->{CMDERRORFLAG}){
                $logger->warn(" CMDERROR FLAG IS POSITIVE - CALLING ERROR");
                &error("CMD FAILURE: $cmd");
            }
            $flag = 0;
            next;
        }
    }

    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
}

#################################################
sub help(){
#################################################
    my $cmd="pod2text " . locate __PACKAGE__;
    print `$cmd`;
}

#################################################
sub usage(){
#################################################
    my $cmd="pod2usage " . locate __PACKAGE__ ;
    print `$cmd`;
}

#################################################
sub manhelp(){
#################################################
    eval {
        require Pod::Help;
        Pod::Help->help(__PACKAGE__);
    };
    if ($@) {
        my $cmd="pod2text " . locate __PACKAGE__ ;
        print `$cmd`;
    }
}

#########################################################################################################

##################################################################################
#purpose:Configure the Load Test Tool.
#Parameters    : callattempt, callduration, trunkgroup, destinationnumber
#Return Values : None
#
##################################################################################            

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::configLTT(<CALLATTEMPT>, <CALLDURATION>, <TRUNKNAME>, <CALLEDNUMBER> )

 Routine configure LTT .
  
=over

=item Arguments

  LOADTESTNAME <Scalar>, CALLDURATION <Scalar>, TRUNKNAME <Scalar>, CALLEDNUMBER <Scalar>
 
=item Returns

  None


=item Example(s):

  &$Mgw9000Obj->configLTT(5,5,ISUPT1,9231110001);

=back

=cut

#################################################
sub configLTT() {
#################################################
    my $subName = 'configLTT()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my($self, $callattempt, $callduration, $trunk, $callednumber, $datatesttype)=@_;
    my $dtmfcmd = "setlttdtmf 1 6 1 2 3 4 5 6 10";
    my $cmd = "";
    $self->createLoadTest("TEST1");

    $logger->info(" configuring  LTT params \n");
    $self->configureLoadTest("TEST1",["call attempt"=>"$callattempt"]);
    $self->configureLoadTest("TEST1",["call duration"=>"$callduration"]);
    $self->configureLoadTest("TEST1",["trunk group"=> "$trunk"]);
    $self->configureLoadTest("TEST1",["add number"=>"1","destination"=>$callednumber,"percentage" => 100]);
    $self->configureLoadTest("TEST1",["add number"=>"1","state"=>"enabled"]);
    $self->configureLoadTest("TEST1",["circuit service profile"=>"isup"]); 
    $self->execCmd("admin debugsonus");

    if($datatesttype eq "7"){
        $callednumber  =~ s/([0-9])/ $1/g;
        $cmd = $dtmfcmd." ".$callednumber." "."5100";    
        $logger->debug(" $cmd  \n");
        $self->execCmd($cmd);    
    }
    $self->execCmd("setlttdatapath $datatesttype");

    $logger->debug("<-- Leaving Sub");
}

#########################################################################################################

##################################################################################
#purpose:Start Load Test Tool.
#Parameters    : None
#Return Values : None
#    
##################################################################################        

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::startLTT()

 Routine to start LTT .
  
=over

=item Arguments

  None
 
=item Returns

  Boolean


=item Example(s):

  &$Mgw9000Obj->startLTT();

=back

=cut

#################################################
sub startLTT() {
#################################################
    my($self)=@_;
    my $subName = 'startLTT()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my $val = 0;

    $logger->info(" starting calls  \n");
    if ($self->configureLoadTest("TEST1",["loadtest state"=>"enabled"])){
        $val = 1;
    } 

    $logger->debug("<-- Leaving Sub [$val]");
    return $val;    
}

#########################################################################################################

##################################################################################
#purpose:Stop Load Test Tool.
#Parameters    : None
#Return Values : None
#    
##################################################################################        

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::stopLTT()

 Routine to stop and delete a LTT .
  
=over

=item Arguments

  None
 
=item Returns

  Boolean


=item Example(s):

  &$Mgw9000Obj->stopLTT();

=back

=cut

#################################################
sub stopLTT() {
#################################################
    my($self)=@_;
    my $subName = 'stopLTT()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my $val = 0;

    $logger->info(" stopping calls \n");
    if ($self->configureLoadTest("TEST1",["loadtest state"=>"disabled"])){
        $val = 1;
    }

    $logger->debug("<-- Leaving Sub [$val]");
    return $val;    
}

#########################################################################################################

##################################################################################
#purpose:Verify Media/Data Path Values.
#Parameters    : None
#Return Values : True/false (1/0)
#    
##################################################################################
        
=pod

=head3 SonusQA::MGW9000::MGW9000LTT::verifyDataPath()

 Routine to verify the media/data path values in the LTT .
  
=over

=item Arguments

  None
 
=item Returns

  Boolean


=item Example(s):

  &$Mgw9000Obj->verifyDatapath();

=back

=cut

#################################################
sub verifyDataPath() {
#################################################
    my ($self)=@_;
    my $subName = 'verifyDataPath()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my (@cmdResults);
    my $flag =1;
    my $datapathpasscnt = 0;
    my $datapathfailcnt = 0;

    my @lttinfo = ("Total Data Test Updates Received", "Total Down Stream Data Test Passed", "Total Down Stream Data Test Failed", "Total Up Stream Data Test Passed", "Total Up Stream Data Test Failed", "Current Data Path Test");
    my @temp = ();
    my @temp1 = ();
    my $currentdpt; 
    my $cmd = "showlttstatus";
    my $info = "";

    $self->execCmd("admin debugsonus");
    $self->execCmd($cmd);
    
    foreach(@{$self->{CMDRESULTS}}){
        foreach $info (@lttinfo){
            @temp = ();
            if(m/$info/){
                $logger->info(" : $_");
                if(m/$lttinfo[5]/i) {
                    @temp1 = split;
                    $currentdpt = $temp1[$#temp1];
                }
                         
                if(m/$lttinfo[2]/i) {
                    @temp = split;
                    $logger->debug(" $info : $temp[$#temp] \n");
                    if(($temp[$#temp]) eq "0") {
                        $datapathpasscnt++;
                    }else{
                        $datapathfailcnt++;
                    }
                }

                if((m/$lttinfo[4]/i) && ($currentdpt ne "4")){
                    @temp = split;
                    $logger->debug(" $info $temp[$#temp] \n");
                    if(($temp[$#temp]) eq "0") {
                        $datapathpasscnt++;
                    } else {
                        $datapathfailcnt++;
                    }
                }
            }
        } ##for $info
    } ## for $CMDRESULTS

    $logger->debug(" ********* passcount :$datapathpasscnt failcount :$datapathfailcnt  \n");

    if ($datapathfailcnt > 0) { 
        $flag = 0;
    }

    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;   
}

#########################################################################################################

=pod

=head3 SonusQA::MGW9000::MGW9000LTT::showLoadTest(<LOADTESTNAME>, <SHOWTYPE>)

 Routine to show LoadTest Status Information.
  
=over

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name

=item Returns

  Boolean
  This routine directly calls SonusQA:MGW9000::execCmd with the formulated command.  SonusQA:MGW9000::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$Mgw9000Obj->showLoadTest("LOADTESTNAME", <ADMIN, STATUS>);

=back

=cut

#################################################
sub showLoadTest(){
#################################################
    my ($self,$loadTestName,$showType)=@_;
    my $subName = 'showLoadTest()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug("--> Entered Sub");

    my ($cmd, @cmdResults);
    my $flag =1;

    unless(defined($loadTestName)){
        $logger->warn(" MANADATORY NAME PARAMETER MISSING.");
        return 0;
    };

    unless(defined($showType)){
        $showType="STATUS"
    };

    $cmd = sprintf("SHOW LOADTEST %s %s", $loadTestName,$showType);
    $logger->debug(" FORUMULATED CMD: $cmd");
    @cmdResults = $self->execCmd($cmd);

    foreach(@cmdResults) {
        if(m/^error/i)    {
            $logger->warn(" CMD RESULT: $_");
            if($self->{CMDERRORFLAG}){
                $logger->warn(" CMDERROR FLAG IS POSITIVE - CALLING ERROR");
                &error("CMD FAILURE: $cmd");
            }
            $flag = 0;
            next;
        }
    }

    $logger->debug("<-- Leaving Sub [$flag]");
    return $flag;
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
