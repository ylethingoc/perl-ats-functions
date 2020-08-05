package SonusQA::EMSCLI;
use JSON::XS ;
 
=pod

=head1 NAME

SonusQA::EMSCLI - Perl module for Sonus Networks EMS CLI interaction

=head1 SYNOPSIS

  use ATS;  # This is the base class for Automated Testing Structure
  
  my $obj = SonusQA::EMSCLI->new(
                              #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name - usually admin>',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_TARGET   => <EMS target instance>,
                              -OBJ_COMMTYPE => "TELNET",
                              
                              # OPTIONAL PARAMETERS:
                              
                              -OBJ_PORT => <TCP PORT INTEGER>,
                              # STACK FLAGS:
                              -REVERSE_STACK => <0|1>,      # Default is 1 or ON
                              -DUMPSTACK => <0|1>,          # Default is 0 or OFF
                              
                              # XML LIBRARY FLAGS:
                              -IGNOREXML => <0|1>,          # Default is 0 or OFF
                              -AUTOGENERATE => <0|1>,       # Default is 0 or OFF
                              );
                               
  PARAMETER DESCRIPTIONS:
    OBJ_HOST
      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_USER
      The user name or ID that is used to 'login' to the device. 
    OBJ_PASSWORD
      The user password that is used to 'login' to the device.
    OBJ_TARGET
      The target instance in which to work with (this can be any EMS controlled target.
    OBJ_COMMTYPE
      The session or connection type that will be established.  
      
  FLAGS:
    REVERSE_STACK
      BOOLEAN FLAG that is used to determine if all commands that are considered reversable will be 'reversed' on destruction.
      This FLAG is specific to EMS CLI, and it only applies to this object.  Currently only PSX is thoroughly tested in this manner.
      The stack is FIFO.  Call created entities are typically push onto the stack using the reverse call (delete).  This is a best effort mechanism
      and should not be 100% relied on.  Users can manually push items onto the stack.
      
    DUMPSTACK
      BOOLEAN FLAG that is used to determine if a REVERSE STACK will be dumped to the file system prior to destruction.  Scripts can use this mechanism to store
      the created stack without reversing it.  They can call the stack back in at a latter point in time, to perform the reversal.
      
    IGNOREXML
      BOOLEAN FLAG that is used to determine whether or not to attempt the load of XML Libraries for this object.
      This FLAG is inherited from SonusQA::Base
      
    AUTOGENERATE
      BOOLEAN FLAG that is used to determine whether or not to regenerate XML Libraries on the fly (forced) for this object.
      This FLAG is specific to this Object only.

=head1 DESCRIPTION

   This module provides an interface for the EMS CLI, allowing for the automated control of multiple Sonus Products in a standardized way.
   This module is a stub, of which most functionality is derived from and XML library system.
   Users are not required to use the XML library system, it can be by-passed.
   
   This module extends SonusQA::Base and inherites SonusQA::GSX::EMSCLIHELPER

=head1 AUTHORS

  Darren Ball <dball@sonusnet.com>  alternatively contact <sonus-auto-core@sonusnet.com>.
  See Inline documentation for contributors.

=head1 REQUIRES

  Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, XML::Simple, Data::Dumper, SonusQA::Utils, Switch, Data::UUID, Data::GUID,
  Tie::File, DBM::Deep, Fcntl

=head1 ISA

  SonusQA::Base, SonusQA::EMSCLI::EMSCLIHELPER

=head1 SUB-ROUTINES

=cut


use SonusQA::Utils qw(:all);
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use HTTP::Cookies;
use JSON qw( decode_json );
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;
use File::Path;
use XML::Simple;
use Switch;
use Data::UUID;
use Tie::File;
use Fcntl 'O_RDWR', 'O_RDONLY', 'O_CREAT';
use DBM::Deep;
use Data::GUID;
use List::MoreUtils qw(first_index);

require SonusQA::EMSCLI::EMSCLIHELPER;
require SonusQA::PSXCLIHELPER;

our $VERSION = "1.0";

use vars qw($self @ISA $AUTOLOAD @EXPORT_OK %EXPORT_TAGS );
our @ISA = qw(SonusQA::Base  SonusQA::EMSCLI::EMSCLIHELPER SonusQA::PSXCLIHELPER);

@EXPORT_OK = (); # keys %methods  -> this would be the xml function names.
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

=pod

=head1 B<SonusQA::EMSCLI::doInitialization()>

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.
  This routine discovers correct path for XML library loading.  It uses the package location for forumulation of XML path.

  This routine sets defaults for:  REVERSE_STACK, DUMPSTACK, AUTOGENERATE
  
  This routine is automatically called prior to SESSION creation, and parameter or flag parsing.
    

=over 6 

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub doInitialization {
  my($self)=@_;
  my($logger,$temp_file);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }

  $self->{COMMTYPES} = ["TELNET" , "SSH"];      # added as to provide the fall back behaviour of ATS. 
  $self->{TYPE} = __PACKAGE__;
  $self->{CLITYPE} = "UNKNOWN";
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*>\s?$/'; # '/.*[\$%#\}\|\>].*$/'
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  
  $self->{TARGETINSTANCEVERSION} = "UNKNOWN";
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  
  #Some flags for performing logical operations.
  $self->{REVERSE_STACK} = 1;
  $self->{DUMPSTACK} = 0;
  $self->{AUTOGENERATE} = 0;
}

=pod

=head1 B<SonusQA::EMSCLI::setSystem()>

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the GSX to enable a more efficient automation environment.
  
  Some of the items or actions is it performing:
    Determines target instance type and version
    Selects target instance once discovered
    Resets the prompt to match the EMSCLI prompt based on target instance
  
  If the IGNOREXML flag is false, this routing will also call the SonusQA::Base function: loadXMLLibrary
  of which will attempt to load the correct standard XML library for this object type and version.

=over 6

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub setSystem(){
    my($self)=@_;
    my($logger, $cmd, $prompt, $prevPrompt, @results, $objectFound, $resultsCount);
    my %featureHash;
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub ");

    if($self->{IGNOREXML}){
      $logger->info(__PACKAGE__ . ".setSystem AUTOMATICALLY TURNING OFF REVERSE_STACK - IGNOREXML IS ENABLED");
      $self->{REVERSE_STACK} = 0;
    }
    if ($self->{REGISTER_NODE} || $ENV{'I_JUST_ISOd'}) {
        $logger->debug(__PACKAGE__ . ".setSystem REGISTER_NODE ($self->{REGISTER_NODE}) || I_JUST_ISOd ($ENV{'I_JUST_ISOd'})");
        $self->registerPSXNode( -master_node => $self->{MASTER_NODE}, -test_data_access => $self->{TEST_DATA_ACCESS})
    }
    @results = $self->{conn}->cmd("find target instances");
    my $cnt1 = 0;
    my $targetInstanceVersion = 0;
    my $instanceFound = 0;
    my ($targetType,$targetVersion,@targetInstanceInfo);
    foreach(@results) {
        if ($_ =~ m/Target\s+Instance\s+:\s+$self->{OBJ_TARGET}/i) {
            $targetType = $cnt1 - 2;  # This will pick up the Target line (for type)
            $targetVersion = $cnt1 - 1;  # This will pick up the Target Version line
            $targetInstanceVersion = $cnt1 + 1;    # This will pick up the Target Instance Version Line
            $instanceFound = 1;
            last;
        }
        $cnt1++;
    }
    if($instanceFound){
        @targetInstanceInfo = @results[$targetType,$targetVersion,$targetInstanceVersion];
        $targetType = $targetInstanceInfo[0];
        $targetType =~ s/\s+Target\s+:\s+//i;
        $targetType =~ tr/A-Z/a-z/;
        
        chomp($targetType);
        $self->{CLITYPE} = $targetType;
        $targetVersion = $targetInstanceInfo[1];
        $targetVersion =~ s/\s+Target.*:\s+//i;
        chomp($targetVersion);
        if($targetVersion !~ m/^V/){
            $targetVersion = "";
        }
        $self->{VERSION} = $targetVersion;
        $targetInstanceVersion = $targetInstanceInfo[2];
        $targetInstanceVersion =~ s/\s+Target.*:\s+//i;
        $targetInstanceVersion =~ s/(,|\s+)//g;
        chomp($targetInstanceVersion);
        if($targetInstanceVersion =~ m/^V/){
          $self->{TARGETINSTANCEVERSION} = $targetInstanceVersion;
        }
    }else{
        &error(__PACKAGE__ . ".setSystem UNABLE TO DETECT OBJECT TYPE AND VERSION");
    }
    $self->{CLITYPE} =~ tr/A-Za-z0-9\. //cd;
    $self->{TARGETINSTANCEVERSION} =~ tr/A-Za-z0-9\. //cd;
    $self->{VERSION} =~ tr/A-Za-z0-9\. //cd;
    $logger->info(__PACKAGE__ . ".setSystem  DISCOVERED DEVICE TYPE             : " . $self->{CLITYPE});
    $logger->info(__PACKAGE__ . ".setSystem  DISCOVERED DEVICE INSTANCE VERSION : " . $self->{TARGETINSTANCEVERSION});
    unless ($self->discoverNode( -emsIp  => $self->{OBJ_HOST} , -deviceNameInEms => $self->{OBJ_TARGET}, -deviceType => uc($self->{CLITYPE}))) {
        $logger->warn(__PACKAGE__ . ".setSystem failed to discover $self->{OBJ_TARGET} in $self->{OBJ_HOST}");
    }
    $main::TESTSUITE->{DUT_VERSIONS}->{uc($self->{CLITYPE}) . "," . uc($self->{OBJ_TARGET})} = $self->{TARGETINSTANCEVERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{uc($self->{CLITYPE}) . ",". ($self->{OBJ_TARGET})});
    $logger->info(__PACKAGE__ . ".setSystem  DISCOVERED DEVICE VERSION          : " . $self->{VERSION});    
    $cmd = sprintf("select target instance %s",$self->{OBJ_TARGET});
    unless( @results = $self->{conn}->cmd($cmd) ) {
	&error(__PACKAGE__ . ".setSystem Failed to select target instance '".$self->{OBJ_TARGET}."'");
    }
    chomp @results;
    if( grep ( /No target found for instance provided/i, @results ) ){
        &error(__PACKAGE__ . ".setSystem Failed to select target instance '".$self->{OBJ_TARGET}."' '@results' Provide a valid target instance or register the device on the EMS with the given target instance name (if it is not registered) and retry");
    }
    $prevPrompt = $self->{conn}->last_prompt;
    $logger->debug(__PACKAGE__ . ".setSystem  ATTEMPTING TO DECIPHER PROMPT: $prevPrompt");
    $self->{conn}->last_prompt("");
    $prevPrompt = $self->{conn}->prompt('/' . $self->{OBJ_TARGET} . '>\s$/i');
    $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    @results = $self->{conn}->cmd("?"); @results = $self->{conn}->cmd("?");
    &logMetaData('DUTINFO',"EMSCLI DUT TYPE: ". $self->{CLITYPE});
    &logMetaData('DUTINFO',"EMSCLI DUT INSTANCE VERSION: ". $self->{TARGETINSTANCEVERSION});
    &logMetaData('DUTINFO',"EMSCLI DUT VERSION: ". $self->{VERSION});
    unless($self->{IGNOREXML}){
      foreach($self->{TARGETINSTANCEVERSION}, $self->{VERSION}) {
        my $xmlconfig = sprintf("%s/%s/%s.xml", $self->{XMLLIBS},$self->{CLITYPE},$_);
        last if $self->loadXMLLibrary($xmlconfig);
      }
      &error(__PACKAGE__ . ".setSystem XML CONFIGURATION ERROR") if !$self->{LIBLOADED}; 
    }
    if( $main::TESTBED{CLOUD_PSX}{lc($self->{OBJ_TARGET})} ){
	if(SonusQA::Utils::greaterThanVersion( $self->{VERSION}, 'V11.02.00')){
	    if($self->{ASSOCIATE_LICENSE}){
         #TOOLS-19244 :List of Domain locked license needs to be pushed for EMS 11.2
             	%featureHash=(
                  	'POL-VPN-D'=>1,
                 	'POL-SPE-D'=>1,
               		'POL-SIP-D'=>1,
               		'POL-ENUMSVR-D'=>1,
                	'POL-H323PGK-D'=>1,
	                'POL-BASESW-D'=>3,
 	                'POL-ENUMCLT-D'=>3,
        	        'POL-IN-D'=>3,
      	                'POL-ITUTCAP-D'=>3,
               		'POL-SIPSCP-D'=>3,
               		'POL-TCAP-D'=>3,
                	'POL-GLNP-D'=>3,
                	'POL-GSM-D'=>3,
              	  	'POL-IS41-D'=>3,
                	'POL-LNP-D'=>3,
                	'POL-TF-D'=>3,
                	'POL-TRANS-D'=>3,
                	'POL-LCR-D'=>3,
                	'POL-OBRDLNP-D'=>3,
                	'POL-STSH-D'=>3
               );
	       unless(SonusQA::ATSHELPER::associateLicenseDLL( $self->{OBJ_HOST}, $self->{OBJ_TARGET}, %featureHash)){
                   $logger->error(__PACKAGE__ . ".setSystem  Unable to push licenses in EMS 11.2");
               }
	   }
        }else{
             unless($self->configurePSXLicenseOnCloud($self->{OBJ_HOST})) {
                $logger->error(__PACKAGE__ . ".setSystem  Unable to assign licenses");
             }
           } 

    }
    elsif($ENV{'I_JUST_ISOd'}){
        delete $ENV{'I_JUST_ISOd'};
        my %featureHash = (
            'POL-SPE' => 1,
            'POL-VPN' => 1,
        );

        unless(SonusQA::ATSHELPER::associateLicenses($self->{OBJ_HOST}, $self->{OBJ_TARGET}, %featureHash)){
            $logger->warn(__PACKAGE__ . ".setSystem: Unable to associate default licenses.");
        }
    }

    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head1 B<SonusQA::EMSCLI::execCmd()>

  This routine is responsible for executing commands.  Commands can enter this routine via two methods:
    1. Via a straight call (if script is not using XML libraries, this would be the perferred method in this instance)
    2. Via an execFuncCall call, in which the XML libraries are used to generate a correctly sequence command.
  It performs some basic operations on the results set to attempt verification of an error.
  
=over 6

=item Arguments

  cmd <Scalar>
  A string of command parameters and values
  timeout<optional>
  timeout value in seconds

=item Returns

  Array
  This return will be an empty array if:
    1. The command executes successfully (no error statement is return)
    2. And potentially empty if the command times out (session is lost)
  
  The assumption is made, that if a command returns directly to the prompt, nothing has gone wrong.
  The GSX product done not return a 'success' message.
  
=item Example(s):

  &$obj->execCmd("");

=back

=cut

sub execCmd {  
  my ($self,$cmd,$timeout)=@_;
  my($logger, @cmdResults);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $timeout ||= $self->{DEFAULTTIMEOUT};
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $self->{CMDRESULTS} = [];
  my $chk_error = 1;
  EXECUTE_CMD:
  $self->{conn}->buffer_empty;
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=> $timeout )) {
      $logger->error(__PACKAGE__ . ".execCmd  UNKNOWN CLI ERROR DETECTED");
      my $errmsg = $self->{conn}->errmsg;
      $logger->debug(__PACKAGE__ . ".execCmd   errmsg: " . $errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".execCmd buffer: ". ${$self->{conn}->buffer});
      $logger->debug(__PACKAGE__ . ".execCmd lastline: ". $self->{conn}->lastline);
      if ($chk_error && ($errmsg =~ /write error/ || ${$self->{conn}->buffer} =~ /User session has timed out idling after 600000 ms/)) {
          $chk_error = 0;
          unless ($self->reconnect()) {
              $logger->error(__PACKAGE__ . ".execCmd unable to reconnect");
          }else {
              $logger->debug(__PACKAGE__ . ".execCmd reconnection made sucessfully");
              $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD AFTER RECONNECTION : $cmd");
              goto EXECUTE_CMD;
          }
      }
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  push(@{$self->{HISTORY}},$cmd);
  return @cmdResults;
}

=pod

=head1 B<SonusQA::EMSCLI::execFuncCall()>

  This routine is responsible for executing commands that are to be generated and verified by the XML libraries.
  The XML libraries are generated from the GSX build EMS commands file.  The process of generating these files is manual,
  and may be problematic.  It may be best to simply call the command using the execCmd functionality.
  
  This routine will verify that the actual command exists within the XML libraries.
  This routine will verify that the keys provided via the arguments are valid keys.  If the keys are not valid, the function
  will simply drop the keys, and move forward.  It will also order the keys appropriately.
  
=over 6

=item Argument

  func <Scalar>
  A string that represents the standard function ID from within the XML files.
  
  anonymous hash <Hash>
  An anonymous hash of key value pairs (order is not required)

  [automatic cleanup flag] <int>
  This argument is optional and by default is set to 1.
  This flag provides a way to override the default behaviour of automatic cleanup of PSX provisioning.
  In some cases it is necessary to delete seed data for a test case.  It these cases,
  the data should be restored (via a create) at the end of the script and therefore not deleted again. 

=item Returns

  Boolean 
  This will return 1 is the command comes back to the prompt immediately.
  A cursory check for the pattern "error" within the results array will cause a 0 (false) to come back.

=item Example(s):

  &$obj->execFuncCall("objFunctionName", {"command_parameter1" => "parameter_value1",
                                          "command_parameter2" => "parameter_value2"} );

=back

=cut

sub execFuncCall (){
  my ($self,$func,$mKeyVals,$autoclean)=@_;
  if ( !defined($autoclean) ) { $autoclean = 1; }
  my($logger, @cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $funcCp);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execFuncCall");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  
  $logger->debug(__PACKAGE__ . ".execFuncCall --> Entered Sub");
  if(!$self->{LIBLOADED} || $self->{INGOREXML}){
    $logger->warn(__PACKAGE__ . ".execFuncCall INGOREXML FLAG IS ON OR XML LIBRARY IS NOT LOADED.  execFuncCall NOT AVAILABLE");
    $logger->debug(__PACKAGE__ . ".execFuncCall <-- Leaving sub [0]");
    return 0;
  }

  $mKeyVals->{'Process_Manager'} = $main::TESTBED{'ssmgr_config'} if($func =~ /ScpServiceDeviceLabel/ and $main::TESTBED{'ssmgr_config'}); #cloud_psx

  if (($func=~/^delete(Vb|Lc)rExceptions$/) and (!defined $mKeyVals->{'system_exception'})){
      $mKeyVals->{'system_exception'} = 0;
  }
  my @manKeys = (); my @optKeys = (); my @stdKeys = ();
  $logger->debug(__PACKAGE__ . ".execFuncCall MOVING PROVIDED KEYS TO LOWER CASE");
  foreach my $tmpKey (keys %{$mKeyVals}){
     $mKeyVals->{lc $tmpKey} = delete $mKeyVals->{$tmpKey}; 
  }
  if($self->{funcref}->{function}->{$func}){ $logger->debug(__PACKAGE__ . ".execFuncCall  VERIFIED METHOD EXISTS IN COMMANDS XML FILE: $func"); }	
  else{ &error(__PACKAGE__ . ".execFuncCall  METHOD [$func] DOES NOT EXIST IN COMMANDS XML FILE.");}
  $funcCp = ${\$self->{funcref}->{function}->{$func}};
  if($funcCp->{mandatorykeys}){ @manKeys = split(",",$funcCp->{mandatorykeys});}
  if($funcCp->{optionalkeys}){ @optKeys = split(",",$funcCp->{optionalkeys});}
  if($funcCp->{standalonekeys}){ @stdKeys = split(",",$funcCp->{standalonekeys}); }
  $cmd = "";
  # Validate Mandatory Keys:
  if($#manKeys > 0){
    foreach(@manKeys){
      if(!defined($mKeyVals->{$_})){
        $logger->warn(__PACKAGE__ . ".execFuncCall  MANADTORY KEY [$_] MISSING FOR METHOD [$func].");
        $logger->debug(__PACKAGE__ . ".execFuncCall <-- Leaving sub [0]");
        return 0;
        
      }
    }
  }
  #TOOLS-12925 DNS related changes for SRV4 PSX
  if (($func=~/^(create|update)(ForwardersData|LwresdDnsServerData|LwresdProfile)$/) and ($main::TESTBED{'PSXCloudType'} eq 'SRV4')){
    if($2=~/^(LwresdProfile)$/){
        my $string = hex ($mKeyVals->{'lwresd_atributes'});
        $string = $string | 4; #Changing the third position in binary to 1 to enable IPV6 flag in lwresd profile for SRV4 PSX
        $string = sprintf ( "%x", $string); 
        $mKeyVals->{'lwresd_atributes'} = "0x".$string;  
        $mKeyVals->{'interface_name_v6'} = "eth2"; #configuring the interface name for IPV6 for SRV4 PSX 
    } else { 
      $mKeyVals->{'ip_type'} = 1; #configuring the IP Type as IPV6 for SRV4 PSX
    }
  }
  # Save current profile configuration in hash if the function is update or delete
  my $currentProfileConfig;
  if ($func=~/^(delete|update)/ and $funcCp->{reversefunc} and $autoclean){
    my $showFunc = $func;
    $showFunc =~ s/(delete|update)/show/; 
    my $acl_list = $mKeyVals;
    $acl_list = $self->findAclProfileData(${$mKeyVals}{'acl_profile_id'}, ${$mKeyVals}{'sequence_number'}) if($showFunc =~ /AclProfileData/); #TOOLS-17410 
    if ($self->execFuncCall($showFunc,$acl_list)){
      $logger->debug(__PACKAGE__ . ".execFuncCall  SHOW COMMAND FOR [$func] SUCCESSFULL. NOW PARSING THE RESULT TO SAVE IN HASH");
      foreach (@{$self->{CMDRESULTS}}){
        next if (m/^Result:\sOk/i || m/PSX:V.*:/ || m/^\s*$/);
        my ($key,$value) = ($1,$2) if(/\s*(\S+)\s*:\s*(.*)\s*/); #TOOLS-20756
        $value =~ s/^~$/""/;
        if($func =~ /^update/){
          foreach my $mKey (keys (%{$mKeyVals})){
            $currentProfileConfig->{$key} = $value if($mKey eq lc($key));
          }
        } else {
          $currentProfileConfig->{$key} = $value;
        }
      }
    }else {
      $logger->warn(__PACKAGE__ . ".execFuncCall  SHOW COMMAND FOR [$func] UNSUCCESSFULL REVERSESTACK WILL HAVE TO BE HANDLES MANUALLY.");
    }
  }
  # Validate Optional Keys:  little bit harder:
  foreach (sort {$a<=>$b} keys (%{$funcCp->{param}})) {
    my $key = $funcCp->{param}->{$_}->{key};
    $key =~ tr/A-Z/a-z/;
    my $cmdkey = $funcCp->{param}->{$_}->{cmdkey};
    my $defaultvalue = $funcCp->{param}->{$_}->{defaultvalue};
    #my $requires = $funcCp->{param}->{$_}->{requires};
    my $option = $funcCp->{param}->{$_}->{option};
    my $includekey = $funcCp->{param}->{$_}->{includeKey};
    my $standalone = $funcCp->{param}->{$_}->{standalone};	
    if(defined($mKeyVals->{$key}) and !$standalone) { # skipping stupid case where we have command field same as standalone
            $funcCp->{param}->{$_}->{defaultvalue} = $mKeyVals->{$key};
            $funcCp->{param}->{$_}->{picked} = 1;
            $logger->debug(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$_}->{key} IS PICKED");
    }else{
      #$logger->warn(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$_}->{key} IS NOT PICKED");
    }
  }
  foreach (sort {$a<=>$b} keys (%{$funcCp->{param}})) {
    my $key = $funcCp->{param}->{$_}->{key};
    $key =~ tr/A-Z/a-z/;
    my $cmdkey = $funcCp->{param}->{$_}->{cmdkey};
    my $defaultvalue = $funcCp->{param}->{$_}->{defaultvalue};
    #my $requires = $funcCp->{param}->{$_}->{requires};
    my $option = $funcCp->{param}->{$_}->{option};
    my $includekey = $funcCp->{param}->{$_}->{includeKey};
    my $standalone = $funcCp->{param}->{$_}->{standalone};	    
    if( ($option =~ /^r$/i) && ($standalone)){ $cmd .= " $cmdkey";}
    if(defined($funcCp->{param}->{$_}->{picked})){
         $cmd .= ($mKeyVals->{$key}=~/^".*"$/) ? (($includekey) ? " $cmdkey $mKeyVals->{$key}" : " $mKeyVals->{$key}") :( ($includekey) ? " $cmdkey \"$mKeyVals->{$key}\"" : " \"$mKeyVals->{$key}\"");
        delete $funcCp->{param}->{$_}->{picked};
    }
  }
  $cmd =~ s/^\s+//g;
RETRY:
  $logger->debug(__PACKAGE__ . ".execFuncCall FORMULATED COMMAND: $cmd");
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  foreach(@cmdResults) {
    if(m/^Result:\sOk/i){
      $logger->info(__PACKAGE__ . ".$func  CMD RESULT: $_");
      $flag = 1;
      if($funcCp->{reversefunc} and $autoclean ){
          $mKeyVals = $currentProfileConfig if ($func=~/^(delete|update)/);
          push(@{$self->{STACK}},[$funcCp->{reversefunc}, [$mKeyVals] ]);
      }
      last;
    }elsif($0 !~ /STARTPSXAUTOMATION/i && $_ =~ /ERR_REC_EXISTS/i && $cmd =~ /create/){
        $cmd =~ s/^create/update/i;
        goto RETRY;
    }elsif(m/^error/i){
      $logger->warn(__PACKAGE__ . ".execFuncCall  CMD RESULT: $_");
      $main::failure_msg .= "TOOLS:EMSCLI-$_\n";      
      if($self->{CMDERRORFLAG}){
        $logger->warn(__PACKAGE__ . ".execFuncCall  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
        &error("CMD FAILURE: $cmd");
      }
      $flag = 0;
      next;
    }
  }
  if( $flag && $func =~ m/create|update/ && $self->{PSX_ALIAS} ne $self->{OBJ_TARGET} && $main::TESTBED{CLOUD_PSX}{lc($self->{PSX_ALIAS})}){        
      unless($self->checkSyncStatus()){
          $logger->error(__PACKAGE__ . ".execFuncCall Failed to call subroutine checkSyncStatus");
          $flag =0;
	  last;
      }
  }

  # TOOLS-8799
  # Storing gateway_id to %GATEWAY_ID to decide whether we need to check PSX is active or not when they make it active
  # Used in SonusQA::SBX5000::execCmd(), if( ($cmd =~ /commit/i) and ($last_cmd =~ /set\s+system\s+policyServer\s+remoteServer\s+(\S+)\s+mode\s+active/)){
  if($flag && $func=~/^createGateway/){
    $logger->debug(__PACKAGE__ . ".execFuncCall storing gateway_id: $mKeyVals->{gateway_id} in to GATEWAY_ID hash");
    $GATEWAY_ID{$mKeyVals->{gateway_id}} = 1;
  }

  $logger->debug(__PACKAGE__ . ".execFuncCall <-- Leaving sub [$flag]");
  return $flag;
}

=pod

=head1 B<SonusQA::EMSCLI::_REVERSESTACK()>

  This routine is responsible for reversing the FIFO stack that has been accumulated prior to call.
  Typically this routine is NOT called within the script itself.  It is called on destruction.
  If this is called by the script, the troubleshooting and owership of this methodolody is put on the user that
  implemented it.
  
  This method will 'loop' through the FIFO stack and 'attempt' to reverse with a best effort.  Other methodologies can be implemented
  to perform this action, and can be accomplished by turning off REVERSE_STACK, and grabbing the global stack and programatically
  processing it.
  
  REVERSE_STACK FLAG is automatically disabled if IGNOREXML FLAG is enabled
  
=over 6

=item Argument

  None - this accesses a globally controlled object stack
 
=item Returns

  None - this method access the globally controlled object stack, and calls execFuncCall with each stack item.

=back

=cut

sub _REVERSESTACK(){
  my($self)=@_;
  my($logger, @stack);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._REVERSESTACK");
  }
  else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  if($self->{REVERSE_STACK}){
    $logger->info(__PACKAGE__ . "._REVERSESTACK STACK FLAG IS TRUE - EXECUTING REVERSE_STACK");
    $logger->info(__PACKAGE__ . "._REVERSESTACK  ***********************************************************");
    $logger->info(__PACKAGE__ . "._REVERSESTACK  ATTEMPTING STACK CLEANUP, WARNING/FAILURES AFTER THIS POINT");
    $logger->info(__PACKAGE__ . "._REVERSESTACK  WILL REQUIRE MANUAL CLEANUP");
    $logger->info(__PACKAGE__ . "._REVERSESTACK  ***********************************************************");
    @stack = @{$self->{STACK}};
    my %acl_seq;
    #reverse(@stack);
    if(scalar @stack > 0){
      while (@stack) {
        my @cmdStruct = @{pop @stack};
        my $cmd = $cmdStruct[0];
        $logger->debug(__PACKAGE__ . "._REVERSESTACK  COMMAND/METHOD: " . $cmdStruct[0]);
        if(ref($cmdStruct[1]) eq "ARRAY"){
            $logger->debug(__PACKAGE__ . "._REVERSESTACK  COMMAND ARGUMENT IS ARRAY");
	    if($cmd =~ /^deleteAclProfileData/i) { 
		$acl_seq{${${$cmdStruct[1]}[0]}{'acl_profile_id'}} = $self->findAclProfileData(${${$cmdStruct[1]}[0]}{'acl_profile_id'}) unless($acl_seq{${${$cmdStruct[1]}[0]}{'acl_profile_id'}});
	        ${${$cmdStruct[1]}[0]}{sequence_number}=$acl_seq{${${$cmdStruct[1]}[0]}{'acl_profile_id'}}{${${$cmdStruct[1]}[0]}{'priority'}}{${${$cmdStruct[1]}[0]}{'direction'}}; 
	    }
        #setting P_Origination_Id to NULL if autoGenPOrig is 0, For TOOLS-75481
        elsif($cmd=~/^(updateServiceDefinition|updateTrunkgroup|updateGateway|updateSTIProfile)/ and ${${$cmdStruct[1]}[0]}{autoGenPOrig} eq '0'){
            ${${$cmdStruct[1]}[0]}{ P_Origination_Id}= '';
            $logger->debug(__PACKAGE__ . "._REVERSESTACK setting P_Origination_Id to null");            
        }
	    $self->execFuncCall($cmd,@{$cmdStruct[1]},0);
        }elsif(ref($cmdStruct[1]) eq "SCALAR"){
            $logger->debug(__PACKAGE__ . "._REVERSESTACK  COMMAND ARGUMENT IS SCALAR");
            $self->execFuncCall($cmd,$cmdStruct[1]);
        }elsif(!ref($cmdStruct[1])){
            $logger->warn(__PACKAGE__ . "._REVERSESTACK  INVALID REFERENCE ENCOUNTERED!");
        }else{
            $logger->debug(__PACKAGE__ . "._REVERSESTACK  UNKNOWN COMMAND ARGUMENT(s) TYPE");
        }
        #sleep(1);
      }
    }
    else{
      $logger->debug(__PACKAGE__ . "._REVERSESTACK  DUMP STACK FILE CONTAINS NO ELEMENTS!");
    }
  }
  else{
    $logger->info(__PACKAGE__ . "._REVERSESTACK STACK FLAG IS NOT SET - EXITING REVERSE_STACK");
  }
}

=pod

=head1 B<SonusQA::EMSCLI::findAclProfileData()>

  This routine is responsible for getting sequence number or entire profile list for the specified profile id(Priority and Direction are unique). This subroutine is called from _REVERSESTACK() and execFuncCall() subroutines.

=over 6

=item Argument

Mandatory :

  acl_profile_id - Acl Profile Id  

Optional :
  
  seq_number - Sequence number of Acl Profile id

=item Returns

  Acl Sequence - hash reference(if sequence number is not passed)
  Acl List - hash referencce(if sequence number is passed)

=item Example
 
  acl_seq{"DEFAULT_ACL_PROFILE"} = $self->findAclProfileData("DEFAULT_ACL_PROFILE") unless($acl_seq{"DEFAULT_ACL_PROFILE"}})
  $acl_list = $self->findAclProfileData(${$mKeyVals}{'acl_profile_id'}, ${$mKeyVals}{'sequence_number'}) if($showFunc =~ /AclProfileData/);  

=item Output

  acl_seq = {
          '6' => {
                   'INBOUND' => '17'
                 },
          '5' => {
                   'INBOUND' => '21'
                 },
          '0' => {
                   'NONE' => '16',
                   'INBOUND' => '7'
                 },
          '4' => {
                   'INBOUND' => '20'
                 },
          '2' => {
                   'INBOUND' => '18'
                 },
          '3' => {
                   'INBOUND' => '19'
                 }
        };

  acl_list = {
		'Acl_Profile_Id'  => 'DEFAULT_ACL_PROFILE'
		'Sequence_Number' => '21'
  		'Interface_Name'  => 'User_defined_rule'
  		'Source_Ip'       => '10.54.81.11'
		'Source_Port'     => '4330'
  		'Destination_Ip'  => '10.54.213.33'
  		'Priority'        => '5'
  		'Destination_Port'=> '*'
 		'Protocol'        => 'TCP'
  		'Action'          => 'ACCEPT'
  		'Direction'       => 'INBOUND'
	    }

=back

=cut

sub findAclProfileData {
  my ($self, $acl_profile_id, $seq_number) = @_;
  my ($logger,%acl_seq, %acl_list);
  my $sub = "findAclProfileData()";
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  }
  else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $logger->debug(__PACKAGE__ . ".Entered $sub");
  my $flag=0;
  my @cmdResult = $self->execCmd("find Acl_Profile_data Acl_Profile_Id $acl_profile_id");
  foreach (@cmdResult) {
    $acl_list{$1} = $2 if(/(\S+)\s*:\s?(.*)/);
    if($acl_list{'Direction'}) {
       if($seq_number ==  $acl_list{'Sequence_Number'}) {
           $flag = 1;
	   last;
       }
       $acl_seq{$acl_list{'Priority'}}{$acl_list{'Direction'}} = $acl_list{'Sequence_Number'};
       %acl_list = ();
    }
  }	
  $logger->debug(__PACKAGE__ . ".Leaving $sub");
  return ($flag) ? \%acl_list : \%acl_seq;
}

=pod

=head1 B<SonusQA::EMSCLI::_DUMPSTACK()>

  This routine is responsible for reversing dumping the FIFO reverse stack to the file system.
  
  There are 3 scenario in which this routine may be called:
  
  Scenario 1:  
  This routine is called automatically on destruction.  The routine will verify that a DUMPSTACK flag
  is set to true prior to dumping the contents of the REVERSE_STACK to the file system. 
 
  Scenario 2:
  This routine can be manually called over-riding the DUMPSTACKFILE name. The method will over-ride the DUMPSTACK flag,
  setting it to true.  This will effectively force the dump.
  
  Scenario 3:
  If this routine is called manually, and the DUMPSTACKFILE name is not provided, the DUMPSTACK flag must be true, else the routine will simply return.
  If the DUMPSTACK flag is true the DUMPSTACKFILE name will be auto-generated.
   
=over 6

=item Argument

  DUMPSTACKFILE <scalar> - this will be the file name of the dump file generated. This should be an absolute path, typically to /tmp.
 
=item Returns

  NOTHING

=item Example(s):

  &$obj->_DUMPSTACK(""/tmp/myDumpFile.dump");
  
  or
  
  $obj->{DUMPSTACK} = 1;
  &$obj->_DUMPSTACK(""/tmp/myDumpFile.dump");
  $obj->{DUMPSTACK} = 0;
  
=back

=cut

sub _DUMPSTACK(){
  my($self,$overrideFileName)=@_;
  my($logger, @stack,@cmdStack,$builtCmd);
  
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._DUMPSTACK");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
 
  if(defined($overrideFileName)){
    $self->{DUMPSTACKFILE} = $overrideFileName;
    $self->{DUMPSTACK} = 1;
  }
  if(!$self->{DUMPSTACK}){
    return;
  }
  if(!defined($self->{DUMPSTACKFILE})){
    $self->{DUMPSTACKFILE} = "/tmp/" . Data::GUID->new  . ".dump"; 
  }
  $logger->info(__PACKAGE__ . "._DUMPSTACK  ***********************************************************");
  $logger->info(__PACKAGE__ . "._DUMPSTACK  ATTEMPTING STACK DUMP TO FILE");
  $logger->info(__PACKAGE__ . "._DUMPSTACK  FILE NAME: " . $self->{DUMPSTACKFILE});
  $logger->info(__PACKAGE__ . "._DUMPSTACK  ***********************************************************");
  @stack = @{$self->{STACK}};
  #reverse(@stack);
  my $db = DBM::Deep->new(
      file => $self->{DUMPSTACKFILE},
      type => DBM::Deep->TYPE_ARRAY
  );
  push (@$db, @stack);
}

=pod

=head1 B<SonusQA::EMSCLI::loadDumpStack()>

  This routine is responsible for loading a previously dumped DUMPSTACKFILE from the file system.
  It is assumed that the Object type calling this routine is the same Object type that generated the DUMPSTACKFILE.
  
  This routine only re-loads the DUMPSTACKFILE into the memory stack in which it will be called.  It does not call
  the _REVERSESTACK routine.
  
  
=over 6

=item Argument

  DUMPSTACKFILE <Scalar> - The location or path to an object dumpstack file.  This should be an absolute path.
 
=item Returns

  Array   - The stack array that was successfully picked up from the file system.  True in this case.
            If the routine fails - it will return an empty array.

=item Example(s):

  $obj->{STACK} = &$obj->loadDumpStack("/tmp/mydumpstackfile.dbm");

=back

=cut

sub loadDumpStack(){
  my($self, $dumpstackfile)=@_;
  my($logger,$stack,@cmdStack,$builtCmd);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".loadDumpStackFile");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }

  if(! -e $dumpstackfile){
    $logger->warn(__PACKAGE__ . ".loadDumpStackFile  ***********************************************************");
    $logger->warn(__PACKAGE__ . ".loadDumpStackFile  ATTEMPTED TO LOAD NON-EXISTANT STACK FILE: $dumpstackfile");
    $logger->warn(__PACKAGE__ . ".loadDumpStackFile  ***********************************************************");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".loadDumpStackFile  ***********************************************************");
  $logger->info(__PACKAGE__ . ".loadDumpStackFile  ATTEMPTING TO LOAD STACK DUMP TO FILE");
  $logger->info(__PACKAGE__ . ".loadDumpStackFile  FILE NAME: $dumpstackfile");
  $logger->info(__PACKAGE__ . ".loadDumpStackFile  ***********************************************************");
  my $db = DBM::Deep->new(
      file => $dumpstackfile,
      type => DBM::Deep->TYPE_ARRAY
  );
  $stack = $db->export();
  return @$stack;
  
}

=pod

=head1 B<SonusQA::EMSCLI::autogenXML()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.  
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=item Example(s):

  &$obj->autogenXML();

=back

=cut

sub autogenXML(){
    my $self = shift;
    my ($logger, $funcParams, $cmdCounter, $cmdCounter2, $includeKey, $standaloneKey, $defaultvalue ,$telObj, $help);
    my (@results, @targetInstanceInfo,@lines,@funcNames,@reverseFuncNames,%commandRef,
        $cnt1, $targetType, $targetVersion, $targetInstanceVersion, $instanceFound,$reverseFunc,$func,
        );
    $cnt1 = 0;
    $targetInstanceVersion = 0;
    $instanceFound = 0;
    
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".autogenXML");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    $logger->debug(__PACKAGE__. ".autogenXML  ---> Entered Sub");
    # We should already have VERSION and TARGETINSTANCEVERSION
    $logger->debug(__PACKAGE__ . ".autogenXML RETRIEVING AND PROCESSING COMMANDS LIST");
    @lines = $self->{conn}->cmd("?");
    @lines = grep /\S/, @lines; # remove empty elements or spaces in the array
    if(scalar(@lines) < 1){
      $logger->warn(__PACKAGE__ . ".autogenXML UNABLE TO RETRIEVE COMMANDS LIST");
      return 0;
    }
    foreach(@lines){
        if($_ =~ m/Command:/i){
            my @command = split(/\s+/);
            my $newFunc =  join(" ", @command[2..$#command]);
            my @commandHelp = $self->{conn}->cmd("help $newFunc");
            @commandHelp = grep /\S/, @commandHelp;
            foreach(@commandHelp){
                $_ =~ s/^ *//;
                if(m/^Result/){next;}
                $_ =~ s/.*Command:\s//;
                if($_ =~ m/^$newFunc\s/){
                    #push(@commandList,$_);
                    $commandRef{$newFunc} = $_;
                }
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".autogenXML COMMAND LIST RETRIEVED");
    $logger->debug(__PACKAGE__ . ".autogenXML PREPARING FILE SYSTEM FOR LIBRARY DUMP");
    my $path = sprintf("%s/%s", $self->{XMLLIBS},$self->{CLITYPE});
    eval {
        if ( !( -d $path ) ) {
            mkpath( $path, 0, 0777 );
        }
    };
    if($@){
        $logger->debug(__PACKAGE__ . ".autogenXML ERROR ATTEMPTING TO CREATE FILESYSTEM PATH: $path");
        $logger->debug(__PACKAGE__ . ".autogenXML ERROR MESSAGE: [$@]");
        return 0;
    }
    my $xmlFile2  = sprintf("%s/%s.xml", $path,$self->{TARGETINSTANCEVERSION});
    $logger->debug(__PACKAGE__ . ".autogenXML ATTEMPTING TO OPEN NEW XML LIBRARY FILE: $xmlFile2");
    eval {
        open(FILE2, ">$xmlFile2") or die("Unable to open file: $xmlFile2");
    };
    if($@){
        $logger->warn(__PACKAGE__ . ".autogenXML ERROR OCCURRED WHILE OPENING LIBRARY FILE: $xmlFile2");
        $logger->debug(__PACKAGE__ . ".autogenXML ERROR MESSAGE: [$@]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".autogenXML XML FILES OPENED SUCCESSFULLY");
    
    #print FILE1 &xmlHeader($targetType, $self->{VERSION}, strftime("%Y%m%d%H%M%S", localtime));
    print FILE2 $self->xmlHeader($targetType, $self->{TARGETINSTANCEVERSION}, strftime("%Y%m%d%H%M%S", localtime));
    $logger->debug(__PACKAGE__ . ".autogenXML PROCESSING COMMANDS LIST TO XML FORMAT");
    foreach my $key (sort keys(%commandRef)) {
        $funcParams = "";
        $cmdCounter2 = 0;
        $cmdCounter = 0;
        $reverseFunc = "NA";
        my $command =   $commandRef{$key};
        $command =~ s/\cM//g;
        $command =~ s/\r//g;
        $command =~ s/\x0D//g;
        $command =~ s/\015//g;
        chomp($command);
        my $helpdesc = "\t\t<helpdesc><![CDATA[$command]]></helpdesc>\n";
        $command =~ s/$key//g;
        $command =~ s/^ *//;
        my @commandStruct = split(/(<[^>]*>|\[.*?\]|\s)/,$command);
        @commandStruct = grep /\S/, @commandStruct;
        $func = "";
        my @funcArr = split(" ",$key);
        my $funcArrCnt = 0;
        foreach(@funcArr){
            $funcParams .= $self->xmlParameterBuilder($cmdCounter,$_,$_,"undef",0,'R',1,1);
            $cmdCounter++;
            $cmdCounter2++;
            $func .= $funcArrCnt > 0 ? ucfirst($_) : $_;
            $funcArrCnt++;
        }
        my $cmd = $key;
        my ($cmdKeys, %hkeys, %okeys, $prevKey, $cnt);
        while(@commandStruct){
            $_ =shift @commandStruct;
            if(/^<(.*)>/){
                $cmd .= " %s";
                if(defined($prevKey)){
                    $hkeys{$prevKey} = $1;
                    $cmdKeys .= "\$mKeyVals->{$prevKey},";
                    $funcParams .= $self->xmlParameterBuilder($cmdCounter,$prevKey,$prevKey,"undef",$cmdCounter,'R',1,0);
                    $cmdCounter++;
                }else{
                    $hkeys{$1} = $1;
                    $cmdKeys .= "\$mKeyVals->{$1},";
                    $funcParams .= $self->xmlParameterBuilder($cmdCounter,$1,$1,"undef",$cmdCounter,'R',1,0);
                    $cmdCounter++;
                }
            }elsif(/^\[(.*)\]/){
                my $subkey = $1;
                $subkey =~ s/^ *//;
                my @subCommand = split(/\s+/,$subkey);
                $prevKey = $subCommand[0];
                $prevKey =~ tr/[A-Z]/[a-z]/;
                if($subCommand[1] =~ m/<(.*)>/){
                    $okeys{$prevKey} = $1;
                    $funcParams .= $self->xmlParameterBuilder($cmdCounter,$prevKey,$prevKey,"undef",$cmdCounter2,'O',1,0);
                    $cmdCounter++;
                }
                else{
                    $okeys{$prevKey} = $subCommand[1];
                    $funcParams .= $self->xmlParameterBuilder($cmdCounter,$prevKey,$prevKey,"undef",$cmdCounter2,'O',1,0);
                    $cmdCounter++;
                }
            }else {
                chomp($_);
                $_ =~ tr/[A-Z]/[a-z]/;
                $cmd .= " $_";
                $prevKey = $_;
                $cnt++;
            }
        }
        $_ = "";
        $command= "";
        if(defined($func) && defined($cmd)){
            my $basecmd = $cmd;
            chop($cmdKeys) if(defined $cmdKeys);
            $cmd =~ s/^ *//;
            if(defined $cmdKeys && length($cmdKeys) > 0){ $cmd = "\"$cmd\",$cmdKeys"; }else{ $cmd = "\"$cmd\""; }
            $func =~ s/\-//g; $func =~ s/\_id//g; $func =~ s/\_//g;
            push(@funcNames,$func);
            
            if($func =~ m/^create/i){
                # For create statements, the opposite is easy - just look for the delete and push that on the stack.
                # The following exceptions exist:
                # Billing Info Profile
                $reverseFunc = $func;
                if ($reverseFunc =~ m/createBillingInfoProfileData/) {
                    $reverseFunc = "deleteBillingInfoProfile";
                }
                else {
                    $reverseFunc =~ s/create/delete/;
                    push(@reverseFuncNames,$reverseFunc);
                }
            }elsif($func =~ m/^update/i){
                # For update statements, the opposite is not so easy:
                #  Perform the show for the function if possible, gather the information or parameters from the show, and collect them as an anonymous hash,
                #  and push the exact same call (to set back the parameters as they were before the update
                $reverseFunc = $func;
                push(@reverseFuncNames,$reverseFunc);
            }elsif($func =~ m/^delete/i && $func !~ m/(ElementRoutingPriorityGroup|LocalCallingAreaNpaNxx|RoutingCriteriaGroup|ServiceArea|SplitAreaCode)/i){
                # For delete statements, fire show command and store the result in a hash. Push create and hash on STACK
                $reverseFunc = $func;
                $reverseFunc =~ s/delete/create/;
                push(@reverseFuncNames,$reverseFunc);
            }
            my $xmlFunc = $self->xmlFunctionBuilder($func,$reverseFunc,$funcParams,$self->xmlMkeysBuilder(%hkeys),$self->xmlOkeysBuilder(%okeys), $helpdesc);
            print FILE2 $xmlFunc;
        }
    }
    $logger->debug(__PACKAGE__ . ".autogenXML Scanning derived reverse function names:");
    my $mflag = 0;
    foreach my $r (@reverseFuncNames){
        foreach my $f (@funcNames){
            if($r eq $f){ $logger->debug(__PACKAGE__ . ".autogenXML FOUND MATCH FOR: $r"); $mflag = 1; }
        }
        if(!$mflag){ $logger->debug(__PACKAGE__ . ".autogenXML ***** NO MATCH FOUND FOR: $r"); }
        $mflag = 0;
    }
    print FILE2 $self->xmlFooter();
    close FILE2;
    $logger->debug(__PACKAGE__ . ".autogenXML XML LIBRARY GENERATED: $xmlFile2");
    $logger->debug(__PACKAGE__ . ".autogenXML DONE");
    return 1;
}

=pod

=head1 B<SonusQA::EMSCLI::xmlHeader()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.   This is a supporting function of autogenXML.
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=back

=cut

sub xmlHeader(){
    my($self, $targetType, $targetVersion, $built)=@_;
    
my $xmlHeader =<<ESXML;
<?xml version="1.0" encoding="ISO-8859-1"?>
<?xml-stylesheet type="text/xsl" href="http://masterats.eng.sonusnet.com/xlst/library.xsl"?>
<commandslib>
    <source>EMSCLI</source>
    <built>$built</built>
    <commandsfile source="EMSCLI" type="$targetType" version="$targetVersion"/>
ESXML
    return $xmlHeader;
}
sub xmlFooter(){
  my($self)=@_;
my $xmlFooter =<<EOXML;
</commandslib>
EOXML
    return $xmlFooter;
}

=pod

=head1 B<SonusQA::EMSCLI::xmlParameterBuilder()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.  This is a supporting function of autogenXML.
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=back

=cut

sub xmlParameterBuilder(){
    my($shelf, $id,$cmdkey, $key,$defaultvalue,$requires,$option,$includeKey,$standaloneKey)=@_;
    my $xml = "";
    $xml="\t\t<param id=\"$id\" key=\"$key\" cmdkey=\"$cmdkey\" defaultvalue=\"$defaultvalue\" option=\"$option\" includeKey=\"$includeKey\" standalone=\"$standaloneKey\"/>\n";
    return $xml;
}

=pod

=head1 B<SonusQA::EMSCLI::xmlMkeysBuilder()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.  This is a supporting function of autogenXML.
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=back

=cut

sub xmlMkeysBuilder(){
    my($self, %keys)=@_;
    my @keyArray;
    my $xml = "";
    while ( my ($key, $value) = each(%keys) ) {
        push @keyArray, "$key";
    }
    if($#keyArray >= 0){
        my $keysString = join(",", @keyArray);
        $xml="\t\t<mandatorykeys><![CDATA[$keysString]]></mandatorykeys>\n";
    }
    return $xml;
}

=pod

=head1 B<SonusQA::EMSCLI::xmlOkeysBuilder()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.  This is a supporting function of autogenXML.
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=back

=cut

sub xmlOkeysBuilder(){
    my($self, %keys)=@_;
    my @keyArray;
    my $xml = "";
    while ( my ($key, $value) = each(%keys) ) {
        push @keyArray, "$key";
    }
    if($#keyArray >= 0){
        my $keysString = join(",", @keyArray);
        $xml="\t\t<optionalkeys><![CDATA[$keysString]]></optionalkeys>\n";
    }
    return $xml;
}

=pod

=head1 B<SonusQA::EMSCLI::xmlFunctionBuilder()>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.
  The code in this routine should not be executed manually.  This is a supporting function of autogenXML.
  
  This routine should only be maintained by the Sonus Automation Core Team <sonus-auto-core@sonusnet.com>  
  
=over 6

=item Argument

  None
 
=item Returns

  None

=back

=cut

sub xmlFunctionBuilder() {
    my($self, $funcName,$reverseFuncName, $parameters,$mkeys,$optkeys, $helpdesc)=@_;
    my $func = "\t<function id=\"$funcName\">\n";
    $func .= $parameters;
    if(length($mkeys) > 0){$func .= $mkeys;}
    if(length($optkeys) > 0){$func .= $optkeys;}
    if($reverseFuncName ne "NA"){ $func .= "\t\t<reversefunc><![CDATA[$reverseFuncName]]></reversefunc>\n";}
    if(length($helpdesc) > 0){$func .= $helpdesc;}
    $func .= "\t</function>\n";
    return $func;
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


#simple function to remove spaces at the begining and ending of strings
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }

=head1 B<SonusQA::EMSCLI::clearptpsx()>

  This routine is responsible for disabling all configured Services on the PSX object.
  All the services that are currently configured on the PSX are gathered and they are all disabled.
  Individual services that need to be enabled for the specific testcase have to be enabled again.

=over 6

=item Argument

  None

=item Returns

  None

=back

=cut

sub clearptpsx{
    my ($self) = @_;
    my $sub_name ="clearptpsx";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name --> Entered Sub ");
    $logger->debug(__PACKAGE__ . ".$sub_name finding all services configured");
	#Step-1: Find all the configured services on the PSX
	unless ($self->execFuncCall( "findServiceDefinition")) {
		$logger->error(__PACKAGE__ . ".$sub_name: failed to execute command findServiceDefinition on EMS");
		$logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
		return 0;
	}
   	my @cmdResults=@{$self->{CMDRESULTS}};
	my @services=(); #configured services will be stored in this array
   	foreach my $line (@cmdResults) {
		if($line =~/Service_Id/ and !($line =~ /Enum_LNP/)){ # look only specific lines in the results, ignore Enum_LNP service, there is a PSX bug in blindly disabling it
			push(@services,trim(substr($line,index($line,':')+1)));
        }
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: Services are ".Dumper(@services));
	#iterate through the services that we gathered previously and disable each one
	#Step-2 : Disable all the services that we found in step-1, except Enum_LNP, there is an issue in disabling it with Sanity DB
	foreach my $serviceId (@services) {
   		my $priority="";
		unless($self->execFuncCall("showServiceDefinition",{'service_id' => $serviceId})) {
			$logger->error(__PACKAGE__ . ".$sub_name: failed to execute command showServiceDefinition on EMS");
			$logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
			return 0;
		}
		my @cmdResults=@{$self->{CMDRESULTS}};
		foreach my $line (@cmdResults) {
       		if(index($line,"Scp_Query_Priority") > 0) {
           		$priority=trim(substr($line,index($line,':')+1));
               	last; #thats it, no more looking required, we got what we wanted for this service
			}
		}
   		$logger->debug( __PACKAGE__ . ": Service is \"$serviceId\" Priority is \"$priority\"");
 		unless ($self->execFuncCall("updateServiceDefinition",{'Service_Id' => $serviceId,'Scp_Query_Priority' => $priority,'Scp_Trigger_Active' => '0',})) {
		     $logger->error(__PACKAGE__ . ".$sub_name: failed to disable service:$serviceId with priority:$priority ");
		     $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub ->[0]");
		      return 0;
   		} 
        $logger->info(__PACKAGE__ . ".$sub_name: Disabled service $serviceId with priority $priority");
	}
	$logger->debug(__PACKAGE__ . ".$sub_name: Returning success from function");
	return 1;
}

=head1 B<SonusQA::EMSCLI::registerPSXNode()>

  Register PSX node on EMS by passing -register_node => 1 while creating ems object.

=over 6

=item Arguments :
   
  Mandatory : None

  Optional
      -register_node => 1  # to register PSX on EMS
      -test_data_access => 1  # to register with test data access


=item Return Values :

  1 - on successfully registering psx node on ems
  0 - otherwise

=item Example :
   
  our  $emsObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'EMSBL13VM5BISTQ', -obj_type => "EMS" ,-target_instance => 'psxvm3', -register_node => 1, -test_data_access => 1);

=back

=cut

sub registerPSXNode {

    my ( $self, %args ) = @_;
    my ($ems_ip, $node_ip, $node_name, $node_type, $master_node, $test_data_access, $ssh_login, $ssh_passwd);

    my $sub_name = "registerPSXNode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");
    $ems_ip = $self->{OBJ_HOST};

    if($args{-insight}){
      $node_name ="localhost";
      $node_ip = $self->{OBJ_HOST};
      $node_type = 'INSIGHT';
    }
    else{
      my $node_alias_hash_ref = SonusQA::Utils::resolve_alias($self->{OBJ_TARGET});
      $node_name = $self->{OBJ_TARGET};
      $node_ip = $node_alias_hash_ref->{NODE}->{1}->{IP};
      $ssh_login = $node_alias_hash_ref->{LOGIN}->{1}->{USERID} || 'ssuser';
      $ssh_passwd = $node_alias_hash_ref->{LOGIN}->{1}->{PASSWD} || 'ssuser';
      $node_type = defined($node_alias_hash_ref->{NODE}->{1}->{TYPE})? $node_alias_hash_ref->{NODE}->{1}->{TYPE} : 'PSX';
      $master_node = defined($args{-master_node}) ? $args{-master_node} : '';
      $test_data_access = defined($args{-test_data_access}) ? $args{-test_data_access} : '';
    }
    my (%form_fields, $username, $password, $command);
    
    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
    $ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    $username = 'admin'; # to be decided whether to set dynamically
    $password = 'admin'; # to be decided whether to set dynamically
    $command = 'cmd_register';

    my $authorisation_value ;
    ($ua, $cookie_jar , $authorisation_value ) = SonusQA::ATSHELPER::loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);
    unless ( $authorisation_value ) {
        ($ua, $cookie_jar, %form_fields) = $self->getPSXNodeForm('ems_ip' => $ems_ip, 'node_ip'=>$node_ip, 'node_name' => $node_name, 'node_type' => $node_type, 'ua' => $ua, 'cookie_jar' => $cookie_jar,'command' => $command,'ssh_login' => $ssh_login, 'ssh_passwd' => $ssh_passwd, 'master_node' => $master_node, 'test_data_access' => $test_data_access );
        unless ($self->postNodeForm($ua, $cookie_jar, $ems_ip, %form_fields)){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to register PSX Node.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } else {
        unless (SonusQA::ATSHELPER::registerPSXNodeNew( 'ua' => $ua, 'cookie_jar' => $cookie_jar, 'ems_ip' => $ems_ip,'node_ip' => $node_ip,'node_name' => $node_name, 'ssh_login' => $ssh_login, 'ssh_passwd' => $ssh_passwd, 'master_node' => $master_node , 'node_type' => $node_type)){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to register PSX Node.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head1 B<SonusQA::EMSCLI::unregisterPSXNode()>
    
  Unregister PSX node from EMS

=over 6

=item Arguments :
   
  Mandatory : None

=item Return Values :

  1 - if successfully
  0 - otherwise

=item Example :
   
  $emsObj->unregisterPSXNode

=back

=cut

sub unregisterPSXNode {

    my ($self) = @_;
    my ($ems_ip, @node_ips, @node_names, $node_type,  $psx_obj);

    my $sub_name = "unregisterPSXNode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");
    $ems_ip = ($self->{OBJ_HOST} =~ m/:/) ? "[$self->{OBJ_HOST}]" : $self->{OBJ_HOST}; #TOOLS-17561?
    $node_names[0] = $self->{PSX_ALIAS};
    my $resolved_testbed = $main::TESTBED{$self->{PSX_ALIAS}}.":hash";
    $node_ips[0] = $main::TESTBED{$resolved_testbed}->{NODE}->{1}->{IP};
    $node_type = defined($main::TESTBED{$resolved_testbed}->{NODE}->{1}->{TYPE})? $main::TESTBED{$resolved_testbed}->{NODE}->{1}->{TYPE} : 'PSX';
    my (%form_fields, $username, $password, $command);

    my $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
    $ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    $username = 'admin'; # to be decided whether to set dynamically
    $password = 'admin'; # to be decided whether to set dynamically
    my $authorisation_value ;
    ($ua, $cookie_jar, $authorisation_value) = SonusQA::ATSHELPER::loginToEMSGUI($ems_ip, $username, $password, $ua, $cookie_jar);

    unless( $authorisation_value ) {
        $command = 'cmd_unregister';
        ($ua, $cookie_jar, %form_fields) = $self->getPSXNodeForm( 'ems_ip' => $ems_ip, 'node_ip'=> $node_ips[0],'node_name' =>  $node_names[0],'node_type' => $node_type,'ua' => $ua,'cookie_jar' => $cookie_jar, 'command' => $command);

        unless ($self->postNodeForm($ua, $cookie_jar, $ems_ip, %form_fields)){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to unregisterPSXNode.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $command = 'cmd_purge';
        ($ua, $cookie_jar, %form_fields) = $self->getPSXNodeForm( 'ems_ip' => $ems_ip, 'node_ip'=> $node_ips[0],'node_name' =>  $node_names[0],'node_type' => $node_type,'ua' => $ua,'cookie_jar' => $cookie_jar, 'command' => $command , 'node_id' => $form_fields{'nodeId'});

        unless ($self->postNodeForm($ua, $cookie_jar, $ems_ip, %form_fields)){
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to purgePSXNode.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }else {
        if($self->{PSX_ALIAS} ne $self->{OBJ_TARGET} && $main::TESTBED{$self->{OBJ_TARGET}}) {
            push(@node_names, $self->{OBJ_TARGET}) ;
            push(@node_ips, $main::TESTBED{$resolved_testbed}->{MGMTNIF}->{1}->{IP})
        }
        my $node_condition = join('|',@node_names);
	my %id;
	$logger->debug(__PACKAGE__ . ".$sub_name: Getting Node id");
	my $url = "https://$ems_ip/nodeMgmt/v1.0/nodes" ;
        my $request = HTTP::Request->new( 'GET', $url );
        my $response = $ua->request( $request ) ;
        my $content = decode_json($response->{'_content'});
	foreach(@{%{$content}{'nodes'}}) {
	    if($_->{'name'} =~ /($node_condition)/) {
		$id{$1} = $_->{'nodeId'};
	    }
	}
	foreach my $node(@node_names) {
             my $psx_ip = shift @node_ips;   
              if($main::TESTBED{CLOUD_PSX}{lc$node}) { # check for cloud
                  if($id{$node}){
                      my %args = (-obj_user => 'admin',
                                  -comm_type => 'SSH',
                                  -obj_host => $psx_ip,
                                  -obj_password => 'admin',
                                  -obj_key_file => $main::TESTBED{'psx:1:ce0:hash'}->{LOGIN}->{1}->{KEY_FILE},
                                 );
                      if( $psx_obj = SonusQA::PSX->new (%args) ) {
      
                          if ( $psx_obj->enterRootSessionViaSU()) {
  		               unless($psx_obj->execCmd("/export/home/ssuser/SOFTSWITCH/BIN/emsRegistration.py -a deregister")) {
                                   $logger->warn(__PACKAGE__ .".$sub_name : Failed to execute the command for deregister");
                               }

                          }else{
                               $logger->warn(__PACKAGE__ . " : Could not enter sudo root session");
                           }
                     $psx_obj->DESTROY(); 

                     }else{
                          $logger->warn(__PACKAGE__.'->'.__LINE__."::$sub_name Obj Creation for ip [$psx_ip}] FAILED");
                      }
                     
                 }else{
                        $logger->warn(__PACKAGE__ . " : $node is not present for deregister");
		                  }
                 }

       	else {
                $url = "https://$ems_ip/nodeMgmt/v1.0/nodes/$id{$node}/actions/unregisterNode" ;
                $request->uri( $url );
                $request->method('PUT') ;
                $request->header( 'Content-Type' => 'application/json' );
                $response = $ua->request( $request );
	    }
        
	$logger->debug(__PACKAGE__ . ".$sub_name: Deleting Node $node");
        $url = "https://$ems_ip/nodeMgmt/v1.0/nodes/$id{$node}" ;
        $request->uri( $url );
        $request->method('DELETE') ;
        $response = $ua->request( $request );

        unless ($response->is_success) {
            $logger->error(__PACKAGE__ . ".$sub_name:Resonse Status Line : ". $response->status_line);
            $logger->error(__PACKAGE__ . ".$sub_name:Response Content : \n". $response->decoded_content);
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:Resonse Status Line : ". $response->status_line);
     }
     }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head1 B<SonusQA::EMSCLI::getPSXNodeForm()>
    
  Helper function to get form details before registering/unregistering PSX node from EMS

=over 6

=item Arguments :
   
  Mandatory :
      -ems_ip - ip on which psx needs to be registered
      -node_ip - psx ip to be register on ems
      -node_name - psx name to be register on ems
      -node_type - type of the node psx/epsx
      -ua - user agent object
      -cookie_jar - cookie jar to store cookie
      -command - type of command (cmd_register, cmd_unregister, cmd_purge)
  Optional :
      -ssh_login - EMS login username ( if not passed, by default 'ssuser' will be considered.)
      -ssh_passwd - EMS login password ( if not passed, by default 'ssuser' will be considered.)
      -master_node - this is passed for slave
      -test_data_access - '1' if it is 'test DB only' 

=item Return Values :

  ($ua, $cookie_jar, %form_fields) - if successfully
  0 - otherwise

=item Example :
   
  $self->getPSXNodeForm('ems_ip' => $ems_ip, 'node_ip'=>$node_ip, 'node_name' => $node_name, 'node_type' => $node_type, 'ua' => $ua, 'cookie_jar' => $cookie_jar,'command' => $command,'ssh_login' => $ssh_login, 'ssh_passwd' => $ssh_passwd, 'master_node' => $master_node, 'test_data_access' => $test_data_access );

=back

=cut

sub getPSXNodeForm {
    my ($self , %args) = @_ ;
    my $ua = $args{'ua'} ;
    my $cookie_jar = $args{'cookie_jar'} ;
    my $command = $args{'command'} ;

    my $sub_name = "getPSXNodeForm";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");

    my ( $request, $response, $decoded_message, @nodes, $master_node_id);
    my @fields_to_parse = qw/username password mgmtPort testDBMgmtPort agentLogin agentPassword snmpReadCommunity snmpPort databaseSID databasePort databaseUsername databasePassword/;
    my %form_fields = (
            'node_type' => 'PSX6000',
            'type' => 'PSX6000',
            'clli' => '',
            'version' => 'Unknown',
            'reachabilityPollingMillis' => '60000',
            'altIp1' => '',
            'altIp2' => '',
            'altIp3' => '',
            'altIp4' => '',
            'altIp5' => '',
            'altIp6' => '',
            'altIp7' => '',
            'altIp8' => '',
            'serverNifIpBackup' => '',
            'masterPsxNode' => '',
            'cb_discover' => 'on',
            'sshEnabled' => 'on',
            'sshType' => 'direct',
            'psxSshLogin' => "$args{'ssh_login'}",      #to be decided whether to populate dyanmically
            'psxSshPassword' => "$args{'ssh_passwd'}",   #to be decided whether to populate dyanmically
            'name' => $args{'node_name'},
            'serverNifIp' => $args{'ems_ip'},
        );

    if ($args{'master_node'}) {
        $request = GET "https://$args{'ems_ip'}/nodeAdmin/NodeAdminServlet?op=getAllNodesByType";
        $cookie_jar->add_cookie_header( $request );
        $response = $ua->request( $request );
        $decoded_message = decode_json($response->decoded_content);
        @nodes = @{ $decoded_message->[0]->{'children'} };
        push(@nodes, @{ $decoded_message->[3]->{'children'} });

        foreach my $node (@nodes){
            if($node->{'data'} eq $args{'master_node'}){
                $master_node_id = $node->{'attr'}->{'id'};
            }
        }

        if ($master_node_id eq '') {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the node id.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $form_fields{'masterSlave'} = ( !$args{'test_data_access'} ) ? 'slave' : 'slavetest';
        $form_fields{'masterPsxNode'} = $master_node_id;
    } else {
        $form_fields{'masterSlave'} = ( !$args{'test_data_access'} ) ? 'master' : 'mastertest';
        $form_fields{'masterPsxNode'} = '0';
    }

    if ($args{'node_type'} eq 'PSX') {
        $form_fields{'ip1'} = $args{'node_ip'};
        $form_fields{'ip2'} = '';
        $form_fields{'psxConfigModeRbGrp'} = '0';
    } elsif($args{'node_type'} eq 'EPSX') {
        $form_fields{'epxIp1'} = $args{'node_ip'};
        $form_fields{'epxIp2'} = '';
        $form_fields{'psxConfigModeRbGrp'} = '2';
    }
    $logger->debug("Trying to fetch the form for : $command");

    if ($command eq 'cmd_register') {
        $request = GET "https://$args{'ems_ip'}/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp?cmd_input=input&node_type=PSX6000";
        $form_fields{'cmd_register'} = 'Register';
        $form_fields{'enabled'} = 'true';

    } elsif ($command eq 'cmd_unregister'){
        $request = GET "https://$args{'ems_ip'}/nodeAdmin/NodeAdminServlet?op=getAllNodesByType";
        $cookie_jar->add_cookie_header( $request );
        $response = $ua->request( $request );
        $decoded_message = decode_json($response->decoded_content);
        foreach (my $count = 0 ; $count < scalar @{$decoded_message} ; $count++ ) {
            @nodes = @{ $decoded_message->[$count]->{'children'} };
            foreach my $node (@nodes){
                if($node->{'data'} eq $args{'node_name'}){
                    $args{'node_id'} = $node->{'attr'}->{'id'};
                    last;
                }
            }
            last if ( $args{'node_id'} ) ;
        }
        unless ($args{'node_id'} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the node id.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        $request = GET "https://$args{'ems_ip'}/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp?node_type=PSX6000&cmd_inspect=inspect&nodeId=$args{'node_id'}";
        $form_fields{'cmd_unregister'} = 'Unregister'; 
        $form_fields{'enabled'} = 'true';
        push(@fields_to_parse, ( 'nodeId', 'version'));

    } elsif ($command eq 'cmd_purge'){
        $request = GET "https://$args{'ems_ip'}/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp?node_type=PSX6000&cmd_inspect=inspect&nodeId=$args{'node_id'}";
        $form_fields{'cmd_purge'} = '  Purge '; 
        $form_fields{'enabled'} = 'false';
        push(@fields_to_parse, ( 'nodeId', 'version'));
    }
    
    $cookie_jar->add_cookie_header( $request );
    $response = $ua->request( $request );
    my @html= split /\n/, $response->decoded_content;

    foreach my $line (@html) {
        if ( my @match = grep { $line =~ /name="$_/ } @fields_to_parse ) { 
            my @record = split /(value="|">)/, $line;
            $form_fields{$match[0]} = $record[2];
        }
    }

    $logger->debug("Fetched form for $command");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return ($ua, $cookie_jar, %form_fields);
}

=head1 B<SonusQA::EMSCLI::postNodeForm()>

  Helper function to post generated form to ems GUI for registering/unregistering PSX node from EMS

=over 6

=item Arguments :

  Mandatory :
      $ua - user agent object
      $cookie_jar - cookie jar to store cookie
      $ems_ip - ip on which psx needs to be registered
      %form_fields -  form fields to be posted with the request

=item Return Values :

  1 - if successfully
  0 - otherwise

=item Example :

  $self->postNodeForm

=back

=cut

sub postNodeForm {

    my ($self, $ua, $cookie_jar, $ems_ip, %form_fields) = @_;
    my $sub_name = "postNodeForm";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . "Entered : $sub_name");

    $logger->debug("Posting generated form with form fields : ". Dumper(\%form_fields));
    my $request = POST "https://$ems_ip/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp", \%form_fields;
    $cookie_jar->add_cookie_header( $request );
    my $response = $ua->request( $request );
    $cookie_jar->extract_cookies( $response );

    unless ($response->is_success) {
      $logger->error("Resonse Status Line : ". $response->status_line);
      $logger->error("Response Content : \n". $response->decoded_content);
      return 0;
    }

    $logger->debug("Resonse Status Line : ". $response->status_line);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head1 B<SonusQA::EMSCLI::installEPSXLicenseX()>

  Helper function  to push EPSXlicense from EMA.

=over 6

=item Arguments :
   
  Mandatory : 
      $sbx_ip - ip on which EPSX license needs to be installed
      $username - EMA gui login username
      $password - EMA gui login password
      $licenseFilePath - License path for the xml file

=item Return Values :

 ($ua, $cookie_jar) - if successfully
  0 - otherwise

=item Example :
   
 $sbx_ip = '10.54.41.21';
 $username = 'admin';
 $password = 'Sonus@123';
 $licenseFilePath = '/home/<user>/perlScripts/epsxlic.xml';
 $self->installEPSLicenseX($sbx_ip,$username,$password,$licenseFilePath);

=back

=cut

sub installEPSXLicenseX {

	my ($self ,$sbx_ip ,$username, $password, $licenseFilePath) = @_;
	my (%form_fields );

	my $sub_name = "installEPSXLicenseX";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . "Entered : $sub_name");

	my $ua = LWP::UserAgent->new( keep_alive => 1 );
	$ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
	$ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));
    
	my $cookie_jar = HTTP::Cookies->new( );
	$ua->cookie_jar( $cookie_jar );

	($ua, $cookie_jar) = &loginToEMAGUI($self, $sbx_ip, $username, $password, $ua, $cookie_jar);
        unless($cookie_jar->as_string =~ /JSESSIONID/ ){
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to login into EMA.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
        }
	($ua, $cookie_jar, %form_fields) = &getEPSXLicenseNodeForm($self, $sbx_ip, $ua, $cookie_jar, $licenseFilePath);  
        unless($cookie_jar->as_string =~ /JSESSIONID/ ){
                $logger->error(__PACKAGE__ . ".$sub_name:  Unable to create license form.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
        }
	unless (&postEPSXLincenseNodeForm($self, $sbx_ip, $ua, $cookie_jar, %form_fields)){
		$logger->error(__PACKAGE__ . ".$sub_name:  Failed to sign into EMS.");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}

	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return 1;
}

=head1 B<SonusQA::EMSCLI::loginToEMAGUI()>
 
  Helper function to login to ems GUI before registering/unregistering PSX node from EMS

=over 6

=item Arguments :
   
  Mandatory : 
      $sbx_ip - ip on which psx needs to be registered
      $username - ems gui login username
      $password - ems gui login password
      $ua - user agent object
      $cookie_jar - cookie jar to store cookie

=item Return Values :

 ($ua, $cookie_jar) - if successfully
  0 - otherwise

=item Example :
   
  $self->loginToEMAGUI

=back

=cut

sub loginToEMAGUI {

	my ($self, $sbx_ip, $username, $password, $ua, $cookie_jar) = @_;

	my $sub_name = "loginToEMAGUI";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . "Entered : $sub_name");

	my $request = GET "https://$sbx_ip/core/ui/places.jsp";
	my $response = $ua->request( $request);
	$cookie_jar->extract_cookies( $response );

        #if we are able to fetch cookie, then is reachable & responding
	unless($cookie_jar->as_string =~ /JSESSIONID/ ){
		$logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the cookie(JSESSIONID). Check if server is reachable.");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}

	$request = POST "https://$sbx_ip/core/ui/j_security_check", [ j_username => $username, j_password => $password, hdnAgreeToTermsStatus => 'disable', j_security_check => ' Log In '];
	$cookie_jar->add_cookie_header( $request );
	$response = $ua->request( $request );
	$cookie_jar->extract_cookies( $response );


        # if response contains 'j_username', login failed & promting to enter credentials again.
	if($response->decoded_content =~ /name="j_username"/ ){
		$logger->error(__PACKAGE__ . ".$sub_name:  Failed to sign into EMA.");
		$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}
        
        $request = GET "https://$sbx_ip/core/ui/places.jsp";
        $cookie_jar->add_cookie_header( $request );
        $response = $ua->request( $request);
        $cookie_jar->extract_cookies( $response );

        # ems needs JSESSIONIDSSO for subsequent request.
        unless($cookie_jar->as_string =~ /JSESSIONIDSSO/ ){
                $logger->error(__PACKAGE__ . ".$sub_name:  Failed to fetch the cookie(JSESSIONIDSSO).");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
        }
        $logger->debug("Successfully logged into EMA GUI");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return ($ua, $cookie_jar);
}


=head1 B<SonusQA::EMSCLI::getEPSXLicenseNodeForm()>
    
  Helper function to login to ems GUI before registering/unregistering PSX node from EMS

=over 6

=item Arguments :
   
  Mandatory : 
      $sbx_ip - ip on which psx needs to be registered
      $ua - user agent object
      $cookie_jar - cookie jar to store cookie
      $licenseFile - License file path for xml file

=item Return Values :

 ($ua, $cookie_jar) - if successfully
  0 - otherwise

=item Example :
   
  $self->getEPSXLicenseNodeForm

=back

=cut

sub getEPSXLicenseNodeForm {

	my ($self, $sbx_ip, $ua, $cookie_jar, $licenseFile) = @_;

	my $sub_name = "getEPSXLicenseNodeForm";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . "Entered : $sub_name");

	my %form_fields = (
			'bundleName' => 'ATSLicense',
			'xxoperation' => 'installLicense',
			'bundleCfgRadioByString' => 'byString',
			'bundleCfgByFile' => 'existingFile',
			);
	my $data = `cat $licenseFile`;
	chomp($data);
	$form_fields{'bundleString'} = $data;

	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return ($ua, $cookie_jar, %form_fields);
}


=head1 B<SonusQA::EMSCLI::postEPSXLincenseNodeForm()>

  Helper function to login to ems GUI before registering/unregistering PSX node from EMS

=over 6

=item Arguments :
   
  Mandatory : 
      $sbx_ip - ip on which psx needs to be registered
      $ua - user agent object
      $cookie_jar - cookie jar to store cookie
      %form_fields - License form fields generated by getEPSXLicenseNodeForm()

=item Return Values :

  ($ua, $cookie_jar) - if successfully
   0 - otherwise

=item Example :
   
 $self->postEPSXLincenseNodeForm

=back

=cut

sub postEPSXLincenseNodeForm {
	my ($self, $sbx_ip, $ua, $cookie_jar, %form_fields) = @_;

	my $sub_name = "postEPSXLincenseNodeForm";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->debug(__PACKAGE__ . "Entered : $sub_name");
	my $request = POST "https://$sbx_ip//sbx/Sbx5kTreeHandlerServlet", \%form_fields;
	$cookie_jar->add_cookie_header( $request );
	my $response = $ua->request( $request );
	$cookie_jar->extract_cookies( $response );
 
        unless ($response->is_success) {
            $logger->error("Resonse Status Line : ". $response->status_line);
            $logger->error("Response Content : \n". $response->decoded_content);
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
        return 1;

}

=pod

=head1 B<SonusQA::EMSCLI::configurePSXLicenseOnCloud()>

   Helper function to associate licenses with cloud psx

=over 6

=item Arguments :

   $ems_ip(mandatory) - ip on which psx is registered
   $profile_id(optional) - Sls profile id

=item Return Values :

   1 - success
   0 - failure

=item Examples : 
   
   unless($self->configurePSXLicenseOnCloud($self->{OBJ_HOST})) {
       $logger->error(__PACKAGE__ . ".setSystem  Unable to assign licenses");
   }

=back

=cut

sub configurePSXLicenseOnCloud {
	my ($self, $ems_ip, $profile_id) = @_;
	my $sub_name = "configurePSXLicenseOnCloud";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->debug(__PACKAGE__ . "Entered : $sub_name".Dumper $ems_ip);
	my ($license_flag, $flag) = (0,1);
	$profile_id ||= '123';
	my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV4') ? 0 : 1;

	my @cmd = ("create Sls_Profile Sls_Profile_Id $profile_id",
		   "create Sls_Profile_Data Sls_Profile_Id $profile_id Sls_Priority 0 Sls_Ip_Address $ems_ip Ip_Type $ip_type",
		   "create License_Profile License_Profile_Id $profile_id Sls_Profile_Id $profile_id License_Chunk_Size 1",
		   "create License_Profile_Data Feature_Name SIPE_License License_Profile_Id $profile_id License_Max_Count 0 License_Min_Count 0",
		   "create License_Profile_Data Feature_Name DPLUS_License License_Profile_Id $profile_id License_Max_Count 0 License_Min_Count 0",
		   "create License_Profile_Data Feature_Name ENUM_License License_Profile_Id $profile_id License_Max_Count 0 License_Min_Count 0",
		   "create License_Profile_Data Feature_Name VPN_License License_Profile_Id $profile_id License_Max_Count 1 License_Min_Count 0"
		  );

	my (@uuid, @cmdResults);
=pod 
	PSX:V11.00.00A017:SLAVEA17> find Psx_Node_Info


        	Psx_Node_Info_Id: DEFAULT
        	Psx_Uuid        : 7CFD617C-A430-485D-B5BE-F97FF3315DE2

        	Psx_Node_Info_Id: DEFAULT
        	Psx_Uuid        : 8A137323-8C9B-4382-BE33-8626B1FA910E


	Result: Ok
=cut	
	unless(@uuid = $self->execCmd("find Psx_Node_Info")) {
            $logger->error(__PACKAGE__ .".$sub_name : Failed to execute the command find Psx_Node_Info");
	    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
            return 0;
        }

	foreach (@uuid) { 
	    if (/uuid/i) {
		my $id = (split(':'))[-1];
		my $show = "show Psx_Node_Info Psx_Node_Info_Id DEFAULT Psx_Uuid $id";
                unless(@cmdResults = $self->execCmd($show)) {
                    $logger->error(__PACKAGE__ .".$sub_name : Failed to execute the command ");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
                    $flag = 0;
		    last;
                }
		if(grep /License_Profile_Id\s*:\s*~/, @cmdResults) {
	            push(@cmd, "update Psx_Node_Info Psx_Node_Info_Id DEFAULT Psx_Uuid $id License_Profile_Id $profile_id");
		    $license_flag = 1;
	        }
	    } 
	}
	
	if($flag) {
	    if($license_flag) {
	        foreach (@cmd) {
	            unless($self->execCmd($_)) {
		        $logger->error(__PACKAGE__ .".$sub_name : Failed to execute the command $_");
                    	$flag = 0;
                    	last;
            	    }   
	        }   
            }   
	    else {
 		$logger->debug(__PACKAGE__ . ".$sub_name: Licenses are already associated.");
	    }
        }   
	
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$flag]");
        return $flag;
}
=pod

=head1 B<SonusQA::EMSCLI::checkSyncStatus()>

    Function to check Sync status
=over 6

=item Return Values :

   1 - success
   0 - failure

=item Examples :

   unless($self->checkSyncStatus()) {
       $logger->error(__PACKAGE__ . ".$sub_name: Failed to call the subroutine");
   }

=back

=cut

sub checkSyncStatus{
    my $self = shift;
    my $sub_name = "checkSyncStatus";
    my(@cmdres ,@line_array1, @line_array, $index, $index1);
    my ($i, $flag ) = (0, 1 );
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name:Entered Sub");
    unless($self->{PSX_OBJ}){
         my %args = (-obj_user => 'admin',
                                  -comm_type => 'SSH',
                                  -obj_host => $main::TESTBED{$main::TESTBED{$self->{PSX_ALIAS}}.":hash"}->{MGMTNIF}->{1}->{IPV6}||$main::TESTBED{$main::TESTBED{$self->{PSX_ALIAS}}.":hash"}->{MGMTNIF}->{1}->{IP},
                                  -obj_password => 'admin',
                                  -obj_key_file => $main::TESTBED{$main::TESTBED{$self->{PSX_ALIAS}}.":hash"}->{LOGIN}->{1}->{KEY_FILE},
                                 );

        unless( $self->{PSX_OBJ}= SonusQA::PSX->new (%args)){
            $logger->error(__PACKAGE__ . ".$sub_name :Failed to create PSX object");  
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]"); 
            return 0;
        }
    }
    unless($self->{PSX_OBJ}->becomeUser(-userName => 'oracle',-password =>'oracle')){
        $logger->error(__PACKAGE__ . ".$sub_name : Could not enter becomeUser ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }

    $self->{PSX_OBJ}->execCmd("cd /export/home/ssuser/SOFTSWITCH/SQL/");
    do{
        if($i){
            $logger->info(__PACKAGE__ . ".$sub_name:Sleep for 3 sec ");
            sleep(3);
        }
        unless( @cmdres = $self->{PSX_OBJ}->execCmd("./DbReplicationStatus.ksh")){
           $logger->error(__PACKAGE__ .".$sub_name : Failed to execute the command ");
           $flag = 0; 
           last;
        }
        ($index) = first_index { $_ =~ m/PENDING_SQLS/ } @cmdres;
        @line_array1 = split('\s+' , $cmdres[$index]);
        ($index1) = first_index { $_ eq 'PENDING_SQLS' } @line_array1;
        $index+=4;
        @line_array = split('\s+' , $cmdres[$index]);
        $i++;
        $logger->debug(__PACKAGE__ . ".$sub_name:PENDING_SQL= $line_array[$index1]  ITERATION-$i");
    }while($line_array[$index1] !=0 && $i < 10 );

    $flag = 0 if($line_array[$index1] != 0) ;
 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$flag]");
    return $flag;
}	
