package SonusQA::GSX::GSXLTT;

=pod

=head1 NAME

  SonusQA::GSX::GSXLTT - Perl module for Sonus Networks GSX 9000 Load Test Tool (LTT) interaction

=head1 SYNOPSIS

  use ATS;  # This is the base class for Automated Testing Structure
  
  my $obj = SonusQA::GSX->new(
                              #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name - usually admin>',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_COMMTYPE => "<TELNET | SSH>",
                              
                              # OPTIONAL PARAMETERS:
                              
                              # NODE RESET FLAGS:
                              -RESET_NODE => <0|1>,      # Default is 0 or OFF
                              -NVSDISABLED => <0|1>,     # Default is 0 or OFF
                              
                              # XML LIBRARY IGNORE FLAGS:
                              -IGNOREXML => <0|1>,     # Default is 0 or OFF
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
      
  FLAGS:
    RESET_NODE
      BOOLEAN FLAG that is used to determine if the node should be 'reset' on destruction
      This FLAG is specific to GSX, and it only applies to this object.
    NVSDISABLED
      BOOLEAN FLAG that is used to determine if NVS PARAMETERS should be set to DISABLED or left alone during destruction
      This FLAG is specific to GSX, and it only applies to this object
      
    IGNOREXML
      BOOLEAN FLAG that is used to determine whether or not to attempt the load of XML Libraries for this object.
      This FLAG is inherited from SonusQA::Base

=head1 DESCRIPTION

  This module is inherited by any GSX object.  This module provides and interface to the LTT command set.
  It is assume that when executing and commands within this module, the Object will be running and LTT image.

=head1 AUTHORS

  Darren Ball <dball@sonusnet.com>  alternatively contact <sonus-auto-core@sonusnet.com>.
  See Inline documentation for contributors.

=head1 REQUIRES

  Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, XML::Simple, Storable, Data::Dumper, SonusQA::Utils,

=head1 ISA

  SonusQA::Base, SonusQA::GSX::GSXHELPER, SonusQA::GSX::GSXLTT

=head1 SUB-ROUTINES

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Switch;
use Module::Locate qw / locate /;

our $VERSION = "1.0";

use vars qw($self);

=pod

=head1 B<SonusQA::GSX::GSXLTT::createLoadTest()>

  Routine to create LTT configruation.
  
=over 6

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name

=item Returns

  Boolean
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$gsxObj->createLoadTest("TESTINGLOADTEST");

=back

=cut

sub createLoadTest(){
  my ($self,$loadTestName)=@_;
  my ($cmd, @cmdResults);
  my $flag =1;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createLoadTest");
  unless(defined($loadTestName)){
    $logger->warn(__PACKAGE__ . ".createLoadTest  MANADATORY NAME PARAMETER MISSING.");
    return 0;
  };
  $cmd = sprintf("CREATE LOADTEST %s", $loadTestName);
  $logger->debug(__PACKAGE__ . ".createLoadTest  FORUMULATED CMD: $cmd");
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
  	if(m/^error/i){
  		$logger->warn(__PACKAGE__ . ".createLoadTest  CMD RESULT: $_");
  		if($self->{CMDERRORFLAG}){
  			$logger->warn(__PACKAGE__ . ".createLoadTest  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
  			&error("CMD FAILURE: $cmd");
  		}
  		$flag = 0;
  		next;
  	}
  }
  return $flag;
}


=pod

=head1 B<SonusQA::GSX::GSXLTT::deleteLoadTest()>

  Routine to delete LTT configruation.
  
=over 6

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name to delete

=item Returns

  Boolean
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$gsxObj->deleteLoadTest("TESTINGLOADTEST");

=back

=cut

sub deleteLoadTest(){
  my ($self,$loadTestName)=@_;
  my ($cmd, @cmdResults);
  my $flag =1;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteLoadTest");
  unless(defined($loadTestName)){
    $logger->warn(__PACKAGE__ . ".deleteLoadTest  MANADATORY NAME PARAMETER MISSING.");
    return 0;
  };
  $cmd = sprintf("DELETE LOADTEST %s", $loadTestName);
  $logger->debug(__PACKAGE__ . ".deleteLoadTest  FORUMULATED CMD: $cmd");
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
  	if(m/^error/i){
  		$logger->warn(__PACKAGE__ . ".deleteLoadTest  CMD RESULT: $_");
  		if($self->{CMDERRORFLAG}){
  			$logger->warn(__PACKAGE__ . ".deleteLoadTest  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
  			&error("CMD FAILURE: $cmd");
  		}
  		$flag = 0;
  		next;
  	}
  }
  return $flag;
}


=pod

=head1 B<SonusQA::GSX::GSXLTT::configureLoadTest()>

 Routine to configure LTT configuration.
  
=over 6

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
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$gsxObj->createLoadTest("TESTINGLOADTEST");
  &$gsxObj->configureLoadTest("TESTINGLOADTEST",["PARAM1"=>"VALUE1","PARAM2"=>"VALUE2","PARAM3"=>"VALUE3"]);
  &$gsxObj->configureLoadTest("TESTINGLOADTEST","NOTARRAY");

=back

=cut

sub configureLoadTest(){
  my($self, $loadTestName, $params)=@_;
  my ($cmd, $cmdParams, @cmdResults);
  my $flag =1;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".configureLoadTest");
  unless(defined($loadTestName) && defined($params)){
    $logger->warn(__PACKAGE__ . ".configureLoadTest  INVALID ARGUMENTS TO METHOD");
    $logger->warn(__PACKAGE__ . ".configureLoadTest  \$loadTestname: $loadTestName");
    $logger->warn(__PACKAGE__ . ".configureLoadTest  \$params: " . (ref($params) eq "ARRAY" ? join(" ", @{$params}) : $params));
    return 0;
  };
  $cmdParams = ref($params) eq "ARRAY" ? join( " ", map split, @{$params} ) : $params;
  $cmd = sprintf("CONFIGURE LOADTEST %s %s", $loadTestName, $cmdParams);
  $logger->debug(__PACKAGE__ . ".createLoadTest  FORUMULATE CMD: $cmd");
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
  	if(m/^error/i){
  		$logger->warn(__PACKAGE__ . ".configureLoadTest  CMD RESULT: $_");
  		if($self->{CMDERRORFLAG}){
  			$logger->warn(__PACKAGE__ . ".configureLoadTest  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
  			&error("CMD FAILURE: $cmd");
  		}
  		$flag = 0;
  		next;
  	}
  }
  return $flag;
 }

sub help(){
  my $cmd="pod2text " . locate __PACKAGE__;
  print `$cmd`;
}

sub usage(){
  my $cmd="pod2usage " . locate __PACKAGE__ ;
  print `$cmd`;
}

sub manhelp(){
  eval {
   require Pod::Help;
   Pod::Help->help(__PACKAGE__);
  };
  if ($@) {
    my $cmd="pod2text " . locate __PACKAGE__ ;
    print `$cmd`;
  }
}

##################################################################################
#purpose:Configure the Load Test Tool.
#Parameters    : callattempt, callduration, trunkgroup, destinationnumber
#Return Values : None
#
##################################################################################			
=pod

=head1 B<SonusQA::GSX::GSXLTT::configLTT()>

 Routine configure LTT .
  
=over 6

=item Arguments

  LOADTESTNAME <Scalar>, CALLDURATION <Scalar>, TRUNKNAME <Scalar>, CALLEDNUMBER <Scalar>
 
=item Returns

  None


=item Example(s):

  &$gsxObj->configLTT(5,5,ISUPT1,9231110001);

=back

=cut

sub configLTT() {
   my($self, $callattempt, $callduration, $trunk, $callednumber, $datatesttype)=@_;
   my $dtmfcmd = "setlttdtmf 1 6 1 2 3 4 5 6 10";
   my $cmd = "";
    $self->createLoadTest("TEST1");
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". configLTT");
    $logger->info(__PACKAGE__ . ".configLTT   configuring  LTT params \n");
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
    $logger->debug(__PACKAGE__ . ".configLTT $cmd  \n");
    $self->execCmd($cmd);	
    }
    $self->execCmd("setlttdatapath $datatesttype");
}

##################################################################################
#purpose:Start Load Test Tool.
#Parameters    : None
#Return Values : None
#	
##################################################################################		
=pod

=head1 B<SonusQA::GSX::GSXLTT::startLTT()>

 Routine to start LTT .
  
=over 6

=item Arguments

  None
 
=item Returns

  Boolean


=item Example(s):

  &$gsxObj->startLTT();

=back

=cut

sub startLTT() {
   my($self)=@_;
   my $val = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". startLTT");
    $logger->info(__PACKAGE__ . ".configLTT   starting calls  \n");
    if ($self->configureLoadTest("TEST1",["loadtest state"=>"enabled"])){
        $val =1;
	}
    return $val;	
}

##################################################################################
#purpose:Stop Load Test Tool.
#Parameters    : None
#Return Values : None
#	
##################################################################################		
=pod

=head1 B<SonusQA::GSX::GSXLTT::stopLTT()>

 Routine to stop and delete a LTT .
  
=over 6

=item Arguments

  None
 
=item Returns

  Boolean


=item Example(s):

  &$gsxObj->stopLTT();

=back

=cut

sub stopLTT() {
   my($self)=@_;
   my $val = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". stopLTT");
    $logger->info(__PACKAGE__ . ".configLTT   stopping calls \n");
    if ($self->configureLoadTest("TEST1",["loadtest state"=>"disabled"])){
        	$val =1;
	}
    return $val;	
}

##################################################################################
#purpose:Verify Media/Data Path Values.
#Parameters    : None
#Return Values : True/false (1/0)
#	
##################################################################################
		
=pod

=head1 B<SonusQA::GSX::GSXLTT::verifyDataPath()>

 Routine to verify the media/data path values in the LTT .
  
=over 6

=item Arguments

  None
 
=item Returns

  Boolean

=item Example(s):

  &$gsxObj->verifyDatapath();

=back

=cut

sub verifyDataPath() {
  my ($self)=@_;
  my (@cmdResults);
  my $flag =1;
  my $datapathpasscnt = 0;
  my $datapathfailcnt = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".showLTTStatus");
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
                           $logger->info(__PACKAGE__ . ".verifyDataPath  : $_");
			if(m/$lttinfo[5]/i) {
				@temp1 = split;
				$currentdpt = $temp1[$#temp1];
                       	
			}
                         
                   if(m/$lttinfo[2]/i) {
				@temp = split;
      			      $logger->debug(__PACKAGE__ . ".verifyDataPath $info : $temp[$#temp] \n");
      			      if(($temp[$#temp]) eq "0") {
					$datapathpasscnt++;
					}else{
					$datapathfailcnt++;
					}
			}

			if((m/$lttinfo[4]/i) && ($currentdpt ne "4")){
				@temp = split;
				$logger->debug(__PACKAGE__ . ".verifyDataPath  :$info $temp[$#temp] \n");
                		if(($temp[$#temp]) eq "0") {
					$datapathpasscnt++;
					} else {
					$datapathfailcnt++;
				}
			}

		}
	} ##for $info
  } ## for $CMDRESULTS

  $logger->debug(__PACKAGE__ . ".verifyDataPath  :********* passcount :$datapathpasscnt failcount :$datapathfailcnt  \n");
  if ($datapathfailcnt > 0) { 
         $flag = 0;
  }

  return $flag;   
}

=pod

=head1 B<SonusQA::GSX::GSXLTT::showLoadTest()>

 Routine to show LoadTest Status Information.
  
=over 6

=item Arguments

  LOADTESTNAME <Scalar>
  A string that will be the load test configuration name

=item Returns

  Boolean
  This routine directly calls SonusQA:GSX::execCmd with the formulated command.  SonusQA:GSX::execCmd return a true of false Boolean.
  Command results set (output) can be access post call in $obj->{CMDRESULTS} which is an array.

=item Example(s):

  &$gsxObj->showLoadTest("LOADTESTNAME", <ADMIN, STATUS>);

=back

=cut

sub showLoadTest(){
	my ($self,$loadTestName,$showType)=@_;
	my ($cmd, @cmdResults);
	my $flag =1;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".showLoadTest");
	unless(defined($loadTestName)){
		$logger->warn(__PACKAGE__ . ".showLoadTest  MANADATORY NAME PARAMETER MISSING.");
		return 0;
	};
	unless(defined($showType)){
		$showType="STATUS"
	};
	$cmd = sprintf("SHOW LOADTEST %s %s", $loadTestName,$showType);
	$logger->debug(__PACKAGE__ . ".showLoadTest  FORUMULATED CMD: $cmd");
	@cmdResults = $self->execCmd($cmd);
	foreach(@cmdResults) {
		if(m/^error/i)	{
			$logger->warn(__PACKAGE__ . ".showLoadTest  CMD RESULT: $_");
			if($self->{CMDERRORFLAG}){
				$logger->warn(__PACKAGE__ . ".showLoadTest  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
				&error("CMD FAILURE: $cmd");
			}
			$flag = 0;
			next;
		}
	}
	return $flag;
}

1;
