package SonusQA::GSX;

=pod

=head1 NAME

SonusQA::GSX - Perl module for Sonus Networks GSX 9000 interaction

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

   This module provides an interface for the GSX switch.
   This module is a stub, of which most functionality is derived from and XML library system.
   Users are not required to use the XML library system, it can be by-passed.

   This module extends SonusQA::Base and inherites SonusQA::GSX::GSXHELPER and SonusQA::GSX::GSXLTT

=head1 AUTHORS

  Darren Ball <dball@sonusnet.com>  alternatively contact <sonus-auto-core@sonusnet.com>.
  See Inline documentation for contributors.

=head1 REQUIRES

  Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, XML::Simple, Storable, Data::Dumper, SonusQA::Utils,

=head1 ISA

  SonusQA::Base, SonusQA::GSX::GSXHELPER, SonusQA::GSX::GSXLTT

=head1 METHODS

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use File::Basename;
use XML::Simple;
use Storable;
use Tie::IxHash;

require SonusQA::GSX::GSXHELPER;
require SonusQA::GSX::GSXLTT;

our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::GSX::GSXHELPER SonusQA::GSX::GSXLTT);

=pod

=head2 SonusQA::GSX::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.
  This routine discovers correct path for XML library loading.  It uses the package location for forumulation of XML path.

  This routine sets defaults for:  RESET_NODE, NVSDISABLED, IGNOREXML

  This routine is automatically called prior to SESSION creation, and parameter or flag parsing.


=over 

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm");
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  
  #Some flags for performing logical operations.
  $self->{RESET_NODE} = 0;
  $self->{NVSDISABLED} = 0;
  
  # Flag for getCDRmethod (GSXHELPER.pm) to check for
  # existance of DSI object
  $self->{dsiObj} = undef;
  
  # SFTP session for copying log files, one per test suite
  $self->{sftp_session} = undef;
  $self->{nfs_session} = undef;
  
  # Port Configuration, hash table ordered by input
  my %configuredPorts = ();
  tie (%configuredPorts, "Tie::IxHash");
  $self->{GsxPorts} = \%configuredPorts;
  $self->{LastIsupCic} = 0;
   
  $self->{DBGfile}            = "";
  $self->{SYSfile}            = "";
  $self->{ACTfile}            = "";

}

=pod

=head2 SonusQA::GSX::closeConn()

  This routine is called by the object destructor.  It closes the communications (TELNET|SSH) session.
  This is done by simply calling close() on the session object

=over

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub closeConn {
  my ($self) = @_;
  my $sub = "closeConn";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub:  --> Entered Sub");

  if ($self->{conn}) {
    $self->{conn}->close;
  }
  if ($self->{sftp_session}) {
    $self->{sftp_session} = undef;
  }    

  if ($self->{nfs_session}) {
     $self->{nfs_session} = undef;
  }
  $logger->debug(__PACKAGE__ . ".$sub:  --> Leaving the Sub");
}

=pod

=head2 SonusQA::GSX::setSystem()

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the GSX to enable a more efficient automation environment.

  Some of the items or actions is it performing:
    Sets GSX PROMPT to AUTOMATION#
    Sets NO_PAGE to 1
    Sets NO_CONFIRM to 1

    Gets Product Version  - calls GSXHELPER function getVersion()
    Gets Product Type     - calls GSXHELPER function getProductType

  If the IGNOREXML flag is false, this routing will also call the SonusQA::Base function: loadXMLLibrary
  of which will attempt to load the correct standard XML library for this object type and version.

=over

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  my $xmlconfig = "";
  $cmd = 'set PROMPT "AUTOMATION#"';
  $self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION#$/');
  $logger->info(__PACKAGE__ . ".setSystem  SET GSX PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  # Initialise PRODUCTTYPE to blank string as it is checked in execCmd BEFORE
  # we get the product type via getProductType() function
  $self->{PRODUCTTYPE} = "";
  $logger->info(__PACKAGE__ . ".setSystem  SET GSX PROMPT TO: " . $self->{conn}->last_prompt);
  $cmd = 'set NO_PAGE 1';
 
  @results = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".setSystem  SET NO_PAGE TO 1");
  $cmd = 'set NO_CONFIRM 1';
  @results = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".setSystem  SET NO_CONFIRM TO 1");
  $self->getVersion();
  $self->getProductType();

  if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
     $main::TESTSUITE->{DUT_VERSIONS}->{"GSX,$self->{TMS_ALIAS_NAME}"} = $self->{VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"GSX,$self->{TMS_ALIAS_NAME}"});
  }

  &logMetaData('DUTINFO',"EMSCLI DUT TYPE: ". $self->{PRODUCTTYPE});
  &logMetaData('DUTINFO',"EMSCLI DUT VERSION: ". $self->{VERSION});


  unless( $self->{IGNOREXML} ) {


    # Pawel, 12/27/2007
    #
    # Load both the 9000 and 4000 XML files:
    #    $self->{funcref} - for the tested product
    #     $self->{funcref2} - for the other product
    #
    # Note: other references may need to be added (and execFuncCall should be updated accordingly)
  
    my $other_product = $self->{PRODUCTTYPE} =~ m/gsx40/ ? "gsx9000" : "gsx4000";

    $xmlconfig = sprintf('%s/%s/cli/%s.xml', $self->{XMLLIBS}, $other_product, $self->{VERSION});
    $self->loadXMLLibrary($xmlconfig, 1); # Here: 1 means we don't exit on failure
    $self->{funcref2} = $self->{funcref};
    
    $xmlconfig = sprintf('%s/%s/cli/%s.xml', $self->{XMLLIBS}, $self->{PRODUCTTYPE}, $self->{VERSION});
    $self->loadXMLLibrary($xmlconfig);
    &error(__PACKAGE__ . ".setSystem XML CONFIGURATION ERROR") if !$self->{LIBLOADED};
  }
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}

=pod

=head2 SonusQA::GSX::execCmd()

  This routine is responsible for executing commands.  Commands can enter this routine via two methods:
    1. Via a straight call (if script is not using XML libraries, this would be the perferred method in this instance)
    2. Via an execFuncCall call, in which the XML libraries are used to generate a correctly sequence command.
  It performs some basic operations on the results set to attempt verification of an error.

=over

=item Arguments

  cmd <Scalar>
  A string of command parameters and values

=item Returns

  Array
  This return will be an empty array if:
    1. The command executes successfully (no error statement is return)
    2. And potentially empty if the command times out (session is lost)

  The assumption is made, that if a command returns directly to the prompt, nothing has gone wrong.
  The GSX product done not return a 'success' message.

=item Example(s):

  &$obj->execCmd("SHOW INVENTORY SHELF 1 SUMMARY");

=back

=cut

sub execCmd {  
  my ($self,$cmd,$timeout)=@_;
  my $sub_name = 'execCmd';
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
  $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");
    # Pawel
    if ($self->{PRODUCTTYPE} =~ m/gsx40/) {
        $cmd = $self->process4000cmd($cmd);
    }
  $cmd =~ s/Sonus_Null//gi;  # Just in case 
  #TOOLS-71156 && TOOLS-71230
  if($cmd =~ /CONFIGURE\s+SONUS\s+SOFTSWITCH\s(\S+)\s+IPADDRESS\s+(\S+)/ && exists $main::TESTBED{"$main::TESTBED{$1}:hash"} && exists $main::TESTBED{"$main::TESTBED{$1}:hash"}{SLAVE_CLOUD} ){
     my ($ip)=($2);
     my $psx = $main::TESTBED{$1};
     my $ip_type = ($ip=~ /:/) ? 'IPV6' :'IP';

     if($main::TESTBED{"$psx:hash"}->{SLAVE_CLOUD}->{1}->{$ip_type}){
          $cmd =~ s/$ip/$main::TESTBED{"$psx:hash"}->{SLAVE_CLOUD}->{1}->{$ip_type}/;
     }else{
          $logger->error(__PACKAGE__. ".$sub_name {SLAVE_CLOUD}->{1}->{$ip_type} is not present in TESTBED");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub(0)");
          return () ;
      }

  }
  my @commands = ($cmd);
  if($cmd =~ /(CONFIGURE IP ROUTE ADD (IFINDEX|NIF) .* IPADDRESS) (\S+)(.*)/i){
	push(@commands, "$1 $main::TESTBED{\"sbx5000:1:ce0:M_SBC:1:hash\"}->{PKT_NIF}->{1}->{IP}$4") if(defined $main::TESTBED{"sbx5000:1:ce0:M_SBC:1:hash"}->{PKT_NIF}->{1}->{IP});
	push(@commands, "$1 $main::TESTBED{\"sbx5000:1:ce0:M_SBC:1:hash\"}->{PKT_NIF}->{2}->{IP}$4") if(defined $main::TESTBED{"sbx5000:1:ce0:M_SBC:1:hash"}->{PKT_NIF}->{2}->{IP});
  }
  my @cmdResults;
  foreach $cmd(@commands){
  $logger->debug(__PACKAGE__ . ".$sub_name: ISSUING CMD: $cmd");
  my $timestamp = $self->getTime();
  $self->{CMDRESULTS} = [];
  $timeout ||= $self->{DEFAULTTIMEOUT};
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=> $timeout )) {
    ## Do not error for CLI restart and switchover
    my $last_line = $self->{conn}->lastline;
    my $err_msg = $self->{conn}->errmsg;
    my $buffer = ${$self->{conn}->buffer};
    if(($cmd !~ m/node restart/i) && ($cmd !~ m/[mg]ns(\d*-?\d*) (switchover|revert)/i)){
	    # Section for commnad execution error handling - CLI hangs, etc can be noted here.
	    $logger->warn(__PACKAGE__ . ".$sub_name: *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	    $logger->warn(__PACKAGE__ . ".$sub_name: CLI ERROR DETECTED");
	    $logger->warn(__PACKAGE__ . ".$sub_name: errmsg : $err_msg");
	    $logger->warn(__PACKAGE__ . ".$sub_name: last_prompt : ".  $self->{conn}->last_prompt);
	    $logger->warn(__PACKAGE__ . ".$sub_name: lastline : $last_line");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	    $logger->warn(__PACKAGE__ . ".$sub_name: *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        
	    push(@cmdResults, "error: ATS ERROR: Failed to execute command '$cmd'");
	    #&error(__PACKAGE__ . ".execCmd CLI CMD ERROR - EXITING");
	}
    if($buffer =~ /Connection reset by peer/i or $err_msg=~/Connection reset by peer|filehandle isn't open/i or $last_line=~/Broken pipe/){
            $logger->debug(__PACKAGE__ . ".$sub_name: The connection to the GSX has been lost. ");
            $logger->debug(__PACKAGE__ . ".$sub_name: buffer : $buffer");
            $logger->debug(__PACKAGE__ . ".$sub_name: Attempting to reconnect to the GSX.. ");
            if($self->reconnect ){
                    $logger->debug(__PACKAGE__ . ".$sub_name: Reconnection to the GSX was successful ");
                    unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=> $timeout )) {
                            $logger->warn(__PACKAGE__ . ".$sub_name: CLI ERROR DETECTED AFTER RECONNECTION");
                    }else{
                            $logger->debug(__PACKAGE__ . ".$sub_name: CLI execution successful after the reconnection ");
                    }
            }else{
                    $logger->warn(__PACKAGE__ . ".$sub_name: Unable to reconnect to the GSX ");
            }
    }
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  }
  $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub.");
  return @cmdResults;
}

=pod

=head2 SonusQA::GSX::process4000cmd()

  This routine will strip slot and shelf keywords from the passed comamnds

=over

=item Argument

  command <Scalar>
  A string of command parameters.

=item Returns

  command <Scalar>
  Returns the stripped command 

=item Example(s)

  my $strippedCmd = $gsxObj->process4000cmd($cmd);

=back

=cut

sub process4000cmd(){
  my ($self,$command)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".process4000cmd");
  $logger->warn(__PACKAGE__ . ".process4000cmd ");

  $command =~ s/slot shelf \d+ slot/slot/ig;
  $command =~ s/shelf \d+//ig;

  my @stripslot = ("announcement segment", "resource pad");
  foreach (@stripslot){
  	if($command =~ /$_/){
  		$command =~ s/slot \d+//ig;
  	}
  }
  return $command;
}


=pod

=head2 SonusQA::GSX::execCliCmd($cmd)

This routine is wrapper around execCmd which returns a scalar value on execution instead of the original output of the command

=over

=item Argument

  cmd <Scalar>
  The comamnd to be executed

=item Returns

  0 - error in command execution
  1 - command executed successfully

=back

=cut

sub execCliCmd {
    my $sub_name     = "execCliCmd";
    my ($self,$cmd) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCliCmd");
    my (@result);

    @result = $self->execCmd( $cmd );

    foreach ( @result ) {
        chomp;
        if ( /^error/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CLI CMD ERROR:--\n@result");
            return 0;
        }
    }
$logger->debug(__PACKAGE__ . ".$sub_name:  CLI command executed successfully");

 return 1;

}




=pod

=head2 SonusQA::GSX::execFuncCall(<func>, {<anonymous hash})

  This routine is responsible for executing commands that are to be generated and verified by the XML libraries.
  The XML libraries are generated from the GSX build EMS commands file.  The process of generating these files is manual,
  and may be problematic.  It may be best to simply call the command using the execCmd functionality.

  This routine will verify that the actual command exists within the XML libraries.
  This routine will verify that the keys provided via the arguments are valid keys.  If the keys are not valid, the function
  will simply drop the keys, and move forward.  It will also order the keys appropriately.

=over

=item Argument

  func <Scalar>
  A string that represents the standard function ID from within the XML files.

  anonymous hash <Hash>
  An anonymous hash of key value pairs (order is not required)

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
	my ($self,$func,$mKeyVals)=@_;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execFuncCall");
        if(!$self->{LIBLOADED} || $self->{INGOREXML} ){
          $logger->warn(__PACKAGE__ . ".execFuncCall INGOREXML FLAG IS ON OR XML LIBRARY IS NOT LOADED.  execFuncCall NOT AVAILABLE");
          return 0;
        }
	my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $funcCp, @stripWords);
	my @manKeys = (); my @optKeys = (); my @stdKeys = ();
        # Check for product type - if this is a gsx4000 - an attempt will be made to remove any reference to 'shelf' from the func reference.
        # Add any key words to strip out of func name below (inside of @stripWords)
##
        $logger->debug(__PACKAGE__ . ".execFuncCall MOVING PROVIDED KEYS TO LOWER CASE");
	if( keys %{$mKeyVals}) {
	    while(my ($tmpKey, $tmpVal) = each(%$mKeyVals)) {  $mKeyVals->{lc $tmpKey} = delete $mKeyVals->{$tmpKey}; }
	}
        # Pawel, checking all XML commands files
        #
        if ( $self->{funcref}->{function}->{$func} ) {
            $logger->debug(__PACKAGE__ . ".execFuncCall() VERIFIED METHOD EXISTS IN $self->{PRODUCTTYPE} COMMANDS XML FILE: $func");
            $funcCp = ${\$self->{funcref}->{function}->{$func}};

        } elsif ( $self->{funcref2}->{function}->{$func} ) {
            $logger->debug(__PACKAGE__ . ".execFuncCall() VERIFIED METHOD EXISTS IN a non $self->{PRODUCTTYPE} COMMANDS XML FILE: $func");
            $funcCp = ${\$self->{funcref2}->{function}->{$func}};

        } else {
            &error(__PACKAGE__ . ".execFuncCall() METHOD [$func] DOES NOT EXIST IN COMMANDS XML FILE.");
        }
	
	if($funcCp->{mandatorykeys}){ @manKeys = split(",",$funcCp->{mandatorykeys}); @manKeys = map lc, @manKeys;}
	if($funcCp->{optionalkeys}){ @optKeys = split(",",$funcCp->{optionalkeys}); @optKeys = map lc, @optKeys;}
	if($funcCp->{standalonekeys}){ @stdKeys = split(",",$funcCp->{standalonekeys});  @stdKeys = map lc, @stdKeys;}
	$cmd = "";
	# Validate Mandatory Keys:
	if($#manKeys > 0){ foreach(@manKeys){ if(!defined($mKeyVals->{$_})){ &error(__PACKAGE__ . ".execFuncCall  MANADTORY KEY [$_] MISSING FOR METHOD [$func].");} } }
	
	# Validate Optional Keys:  little bit harder:
	foreach (sort {$a<=>$b} keys (%{$funcCp->{param}})) {
		my $key = $funcCp->{param}->{$_}->{key};
		$key =~ tr/A-Z/a-z/;
		my $cmdkey = $funcCp->{param}->{$_}->{cmdkey};
		my $defaultvalue = $funcCp->{param}->{$_}->{defaultvalue};
		my $requires = $funcCp->{param}->{$_}->{requires};
		my $option = $funcCp->{param}->{$_}->{option};
		my $includekey = $funcCp->{param}->{$_}->{includeKey};
		my $standalone = $funcCp->{param}->{$_}->{standalone};	
		if(defined($mKeyVals->{$key})) {
			$funcCp->{param}->{$_}->{defaultvalue} = $mKeyVals->{$key};
			# Verify hierarchy of required keys for parameter
			while($requires > 0){  # First key is always required and standalone.                                
				if(!$funcCp->{param}->{$requires}->{standalone}){
					my $rkey = $funcCp->{param}->{$requires}->{key};
					$rkey =~ tr/A-Z/a-z/;
					if(defined($mKeyVals->{$rkey})){ $funcCp->{param}->{$requires}->{picked} = 1; #KEY REQUIREMENT IS MET
					}else{ &error(__PACKAGE__ . ".execFuncCall  KEY DEPENDANCY [$rkey] IS NOT MET.  KEY REQUIRING IS [$key]"); }
                                        
				}else{ $funcCp->{param}->{$requires}->{picked} = 1; } #REQUIREMENT FOR KEY IS STANDALONE\n"; }
				if(defined($funcCp->{param}->{$requires}->{picked})){ $logger->debug(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$requires}->{key} IS PICKED"); }
				$requires = $funcCp->{param}->{$requires}->{requires};
			}
			# If this is reached, then the main key should be picked also.
			$funcCp->{param}->{$_}->{picked} = 1;
                        $logger->debug(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$_}->{key} IS PICKED");
		}
	}
        $funcCp = $funcCp;
	foreach (sort {$a<=>$b} keys (%{$funcCp->{param}})) {
          
		my $key = $funcCp->{param}->{$_}->{key};
		$key =~ tr/A-Z/a-z/;
		my $cmdkey = $funcCp->{param}->{$_}->{cmdkey};
		my $defaultvalue = $funcCp->{param}->{$_}->{defaultvalue};
		my $requires = $funcCp->{param}->{$_}->{requires};
		my $option = $funcCp->{param}->{$_}->{option};
		my $includekey = $funcCp->{param}->{$_}->{includeKey};
		my $standalone = $funcCp->{param}->{$_}->{standalone};	    
		if( ($option =~ /^R$/i) && ($standalone) && !defined($funcCp->{param}->{$_}->{picked})){ $cmd .= " $cmdkey";}
		if(defined($funcCp->{param}->{$_}->{picked})){
			$cmd .= ($includekey) ? (defined($mKeyVals->{$key}) ? " $cmdkey $mKeyVals->{$key}" : " $cmdkey") : " $mKeyVals->{$key}";
                        delete $funcCp->{param}->{$_}->{picked};
		}
	}
	$cmd =~ s/^\s+//g;
        $cmd =~ s/Sonus_Null//gi;  # Just in case 
        # Pawel, moved to execCmd()
        #if($self->{PRODUCTTYPE} =~ m/(4000|4010)/){
        #  $cmd = $self->process4000cmd($cmd);
        # }
	  
        $logger->debug(__PACKAGE__ . ".execFuncCall FORMULATED COMMAND: $cmd");
        $flag = 1; # Assume cmd will work
        @cmdResults = $self->execCmd($cmd);
        foreach(@cmdResults) {
          if(m/^error/i){
            $logger->warn(__PACKAGE__ . ".execFuncCall  CMD RESULT: $_");
            if($self->{CMDERRORFLAG}){
              $logger->warn(__PACKAGE__ . ".execFuncCall  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
              &error("CMD FAILURE: $cmd");
            }
            $flag = 0;
            next;
          }
        }
        return $flag;
}

=pod

=head2 SonusQA::GSX::help()

  Creates and executes a pod2text command

=over

=item Argument 

  None

=item Returns

  None

=back

=cut

sub help(){
  my $cmd="pod2text " . locate __PACKAGE__;
  print `$cmd`;
}

=pod

=head2 SonusQA::GSX::usage()

  Creates and executes a pod2usage command

=over

=item Argument

  None

=item Returns

  None

=back

=cut

sub usage(){
  my $cmd="pod2usage " . locate __PACKAGE__ ;
  print `$cmd`;
}

=pod

=head2 SonusQA::GSX::manhelp()

  Executes Pod::Help::help function

=over

=item Argument

  None

=item Returns

  None

=back

=cut

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

=pod

=head2 SonusQA::GSX::configureGsxFromTemplate

  Iterate through template files for tokens,
  replace all occurrences of the tokens with the values in the supplied hash (i.e. data from TMS).
  For each template file using GSX session do the provisioning by sourcing the file from SonusNFS server.

=over

=item Argument

  file list <Array Reference>
  specify the list of file names of template (containing GSX commands)

  replacement map (Hash Reference)
  specify the string to search for in the file

  Path Information. Optional. Set as 1, for not to use "../C/" for sourcing TCL file

=item Returns

  0 configuration of sgx4000 using template files failed.
  1 configuration of sgx4000 using template files successful.

=item Example(s)

  my @file_list = (
    "QATEST/GSX/gsxConfigWanTesting.template",
  );

  my %replacement_map = (
    # GSX - related tokens
    'GSXMNS11IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{1}->{IP},
    'GSXMNS12IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{2}->{IP},
    'GSXMNS21IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{3}->{IP},
    'GSXMNS22IP' => $TESTBED{'gsx:1:ce0:hash'}->{MGMTNIF}->{4}->{IP},

    # PSX - related tokens
    'PSX0IP1'  => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{IP},
    'PSX0NAME' => $TESTBED{'psx:1:ce0:hash'}->{NODE}->{1}->{NAME},

    # SGX4000 - related tokens
    'CE0SHORTNAME' => $TESTBED{'sgx4000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME},
    'CE1SHORTNAME' => $TESTBED{'sgx4000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME},
    'CE0LONGNAME' => "$TESTBED{'sgx4000:1:ce0:hash'}->{CE}->{1}->{HOSTNAME}",
    'CE1LONGNAME' => "$TESTBED{'sgx4000:1:ce1:hash'}->{CE}->{1}->{HOSTNAME}",
    'CE0EXT0IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{IP},
    'CE0EXT1IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{IP},
    'CE0INT0IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{IP},
    'CE0INT1IP' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{IP},
    'CE1EXT0IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{IP},
    'CE1EXT1IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{IP},
    'CE1INT0IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{IP},
    'CE1INT1IP' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{IP},

    'CE0EXT0NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
    'CE0EXT1NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
    'CE0INT0NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{1}->{MASK},
    'CE0INT1NETMASK' => $TESTBED{'sgx4000:1:ce0:hash'}->{INT_SIG_NIF}->{2}->{MASK},
    'CE1EXT0NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{1}->{MASK},
    'CE1EXT1NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{EXT_SIG_NIF}->{2}->{MASK},
    'CE1INT0NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{1}->{MASK},
    'CE1INT1NETMASK' => $TESTBED{'sgx4000:1:ce1:hash'}->{INT_SIG_NIF}->{2}->{MASK},
  );

  unless ( $gsx_session->configureGsxFromTemplate( \@file_list, \%replacementemap, $out_filename ) ) {
    $TESTSUITE->{$test_id}->{METADATA} .= "Could not configure SGX4000 from Template files.";
    printFailTest (__PACKAGE__, $test_id, "$TESTSUITE->{$test_id}->{METADATA}");
    return 0;
  }
  $logger->debug(__PACKAGE__ . ".$test_id:  Configured SGX4000 from Template files.");

=back

=cut

sub configureGsxFromTemplate {

    my ($self, $file_list_arr_ref, $replacement_map_hash_ref, $out_file, $flagC) = @_ ;
    my $sub_name = "configureGsxFromTemplate";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    # Checking mandatory inputs...

    unless ( defined $file_list_arr_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory file list array reference input is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    unless ( defined $replacement_map_hash_ref ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory replacement map hash reference input is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    unless ( defined $out_file ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory out filename  input is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    my $doNotUseC = 0;

    if( defined $flagC ) {
       if( $flagC eq 1 )  {
          $doNotUseC = 1;
       }
    }

    my ( @file_list, %replacement_map );
    @file_list       = @$file_list_arr_ref;
    %replacement_map = %$replacement_map_hash_ref;

    my ( $f, @file_processed );
    foreach (@file_list) {
        my ( @template_file );
        unless ( open INFILE, $f = "<$_" ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open input file \'$_\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
        }

        @template_file  = <INFILE>;

        unless ( close INFILE ) {
             $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close input file \'$_\'- Error: $!");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
        }

        # Check to see that all tokens in our input file are actually defined by the user... 
        # if so - go ahead and do the processing.
        my @tokens = SonusQA::Utils::listTokens(\@template_file);

        unless (SonusQA::Utils::validateTokens(\@tokens, \%replacement_map) == 0) {
            $logger->error(__PACKAGE__ . ".$sub_name:  validateTokens failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }

        @file_processed = SonusQA::Utils::replaceTokens(\@template_file, \%replacement_map);
        unless ( @file_processed ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  replaceTokens failed.");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    # open out file and write the content
    unless ( open OUTFILE, $f = ">$out_file" ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open output file \'$out_file\'- Error: $!");
         $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
         return 0;
    }

    print OUTFILE (@file_processed);

    unless ( close OUTFILE ) {
         $logger->error(__PACKAGE__ . ".$sub_name:  Cannot close output file \'$out_file\'- Error: $!");
         $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
         return 0;
    }

    my ($NFS_ip, $NFS_userid, $NFS_passwd, $NFS_path);
    $NFS_ip     = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    $NFS_userid = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'};
    $NFS_passwd = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'};
    $NFS_path   = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'LOCAL_BASE_PATH'};

    $logger->debug(__PACKAGE__ . ".$sub_name: putting \'$out_file\' to \'$NFS_path\'");

    unless ( SonusQA::Utils::SftpFiletoNFS(
                                            $NFS_ip,
                                            $NFS_userid,
                                            $NFS_passwd,
                                            $NFS_path,
                                            $out_file,
                                          ) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: $NFS_ip, $NFS_userid, $NFS_passwd, $NFS_path ");
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not SFTP file \'$out_file\' to SonusNFS.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Could SFTP file \'$out_file\' to SonusNFS.");

    # Create a connection to NFS to delete the file
    if (!defined ($self->{nfs_session})) {
       $self->{nfs_session} = SonusQA::DSI->new(
                                  -OBJ_HOST     => $NFS_ip,
                                  -OBJ_USER     => $NFS_userid,
                                  -OBJ_PASSWORD => $NFS_passwd,
                                  -OBJ_COMMTYPE => "SSH",);
        unless ( $self->{nfs_session} ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not open connection to NFS");
            $logger->error(__PACKAGE__ . ".$sub_name:  Could not open session object to required SonusNFS \($NFS_ip\)");
            $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
            return 0;
        }
    }
 
    my $configFile = $NFS_path . "/" . $out_file;

    my $rmCmd = "rm $configFile";

    unless ( $self->sourceTclFile( -tcl_file     => "$out_file",
                                   -doNotUseC    => $doNotUseC ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not source file \'$out_file\' from SonusNFS to GSX.");
        $logger->debug(__PACKAGE__ . ".$sub_name: removing TCL file \' $rmCmd \' ");
        $self->{nfs_session}->{conn}->cmd($rmCmd);
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  Could source file \'$out_file\' from SonusNFS to GSX.");

    $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully configured GSX from Template.");
    $logger->debug(__PACKAGE__ . ".$sub_name: removing TCL file  \' $rmCmd \' ");
    $self->{nfs_session}->{conn}->cmd($rmCmd);
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");

    return 1;
}


=head2 C< getDecodeMessage() >

=over

=item DESCRIPTION:

    This function obtains the current log path, creates a TOOLS object to NFS and calls the verifyDecodeMessage() function to get the Decoded result by runing the decodeTool for given parameter.

=item Arguments :

   Mandatory :
        -LogType - The type of log to verify the pattern in (DBG etc) 
        -LogFile - File names only in case when 2 files need to be passed
        -RawData - '01 10 21 01 0a 00 02 07 05 01 90 59 83 f8 0a 05 81 12 59 83 08 08 01 00 1d 03 80 90 a3 31 02 00 4a c0 09 06 84 10 33 76 68 33 42 09 3d 01 0e 39 06 3d c0 31 90 c0 d4 00'
        -String - Strings to be matched in the decoded output
        -Variant - protocol variant  can be japan,ansi,china,itu,bt etc 
   Optional :
        -NoRoute - no route option can only be used with the no Logfile
        -DecodeTool - Path of the decodetool

=item Return Values :

   0 - Failed
   1 - Success

=item External Funtions Called:

   SonusQA::GSX::GSXHELPER::getCurLogPath()
   SonusQA::Base::verifyDecodeMessage()
   SonusQA::SBX5000::SBX5000HELPER::_execShellCmd()

=item Example :

 Example for Raw Data:
   my %params = (  -RawData  => '01 11 48 00 0a 03 02 0a 08 83 90 89 04 04 00 00 0f 0a 07 03 13 99 54 04 00 00 1d 03 90 90 a3 31 02 00 18 c0 08 06 03 10 99 54 04 00 00 39 04 31 90 c0 84 00',
                   -String    => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                   -Variant   => 'itu',
                   -NoRoute    => 1
                );

   $Obj->getDecodeMessage(%params);

   my %params = (   -LogType  => 'DBG',
                   -String    => { 'IAM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                                                'RECEIVED'      => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                                               },
                                      'ACM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                                'RECEIVED'      => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                               },
                                      'ANM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                               },
                                    },
                   -Variant   => 'itu',
   );

   $Obj->getDecodeMessage(%params);

                                                   or

   my %params = (   -LogType  => 'DBG',
                   -String    => { 'IAM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},
                                               },
                                      'ACM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},},
                                               }
                                    },
                   -Variant   => 'itu',
   );

   $Obj->getDecodeMessage(%params);

=back 

=cut

sub getDecodeMessage {
    my ($self, %params) = @_;
    my $toolsObj;
    my $sub_name = "getDecodeMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Getting the '$params{-LogType}' log path");
    my $logfullpath = $self->getCurLogPath($params{-LogType});
    if(!$logfullpath or $logfullpath eq '1'){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the log path");
        $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub[0]");
        return 0;
    }
    my ($logpath, $logname) = ($self->{$params{-LogType}.'_PATH'}, $self->{$params{-LogType}.'_NAME'});
    $params{-LogFile} = $logname unless($params{-LogFile} =~ /\,/);
    my $NFS_ip = $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'IP'};
    unless($toolsObj = SonusQA::TOOLS->new(-obj_host => $NFS_ip,
                                    -obj_user => $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'USERID'},
                                    -obj_password => $self->{TMS_ALIAS_DATA}->{'NFS'}->{'1'}->{'PASSWD'},
                                    -obj_commtype => "SSH",
                                    -obj_port => '22',
                                    -decodetool => delete($params{-DecodeTool})
                                   )){
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not open TOOLS object to required SonusNFS \($NFS_ip\)");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }
    $toolsObj->execCmd("cd $logpath");

    unless($toolsObj->verifyDecodeMessage(%params)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to verify the message");
        $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub[0]");
        return 0;
    }

    $toolsObj->execCmd("cd");
    $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub[1]");
    return 1;
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

1;
