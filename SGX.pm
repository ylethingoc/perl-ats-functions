package SonusQA::SGX;

=head1 NAME

SonusQA::SGX - Perl module for NetHAWK EASDT interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   my $obj = SonusQA::SGX->new(-OBJ_HOST => '[ HOSTNAME | IP ADDRESS ]',
                               -OBJ_USER => '<cli user name>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => '[ TELNET | SSH ]
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Sonus SGX [SWMML] interface.

=head2 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use File::Basename;
use XML::Simple;
use Data::GUID;
use Tie::File;
use String::CamelCase qw(camelize decamelize wordsplit);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SGX::SGXHELPER SonusQA::SGX::SGXUNIX);

=pod

=head2 B<doInitialization>

    Routine to set object defaults and session prompt.

=over

=item Arguments:

        Object Reference

=item Returns:

        None

=back

=cut

sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{CLITYPE} = "sgx";
  $self->{conn} = undef;
  $self->{PROMPT} = '/\$.*$/';
  $self->{REVERSE_STACK} = 1;
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  $self->{PKGINFO} = "/var/sadm/pkg/SONSgxVer/pkginfo";
  $self->{ENTEREDCLI} = 0;
}

=pod

=head2 B< setSystem >

    This function sets the system information.

=over

=item Arguments:

  None

=item Returns:

        Success- Return 1
        Failure- Exit 0

=back

=cut


sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $logger->info(__PACKAGE__ . ".setSystem  ATTEMPTING TO RETRIEVE SGX VERSION");
  my @v = $self->{conn}->cmd("cat $self->{PKGINFO} | grep VERSION");
  my $version = $v[0];
  if($version =~ m/.*\,\s+(\w+)/){ $version = uc($1);}else{$version = "UNKNOWN";}
  if($version != "UNKNOWN"){
    $logger->info(__PACKAGE__ . ".setSystem  VERSION: $version");
  }else{
    &error(__PACKAGE__ . ".execCmd UNABLE TO DETECT VERSION - ERROR");
  }
  $self->{VERSION} = $version;
  # AUTOGENERATE will force the generation of XML Libraries
  # This is not meant to be used in test scripts
  if($self->{AUTOGENERATE}){
    $self->autogenXML();
    exit 0;  # This is called - as the generation script need not go any further
  }
  # Override the default number of rows(80) so that we don't get swmml command paging - malc.
  $self->{conn}->cmd("stty rows 10000");
  $self->enterSwmml();
  my $xmlconfig = sprintf("%s/%s/%s.xml", $self->{XMLLIBS},$self->{CLITYPE},$self->{VERSION} );
  $self->loadXMLLibrary($xmlconfig);
  &error(__PACKAGE__ . ".setSystem XML CONFIGURATION ERROR") if !$self->{LIBLOADED};
  @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = $self->{conn}->cmd('uname');
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}

=pod

=head2 B<execCmd()>

    This function enables user to execute any command in SGX.

=over

=item Argument:

    Command to be executed.

=item Return Value:

    Array - Output of the command executed.

=item Usage:

    my @results = $Object->execCmd($cmd);
    This would execute the command "ls /ats/NBS/sample.csv" on the SGX server and return the output of the command.

=back

=cut

sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults);
  if(!$self->{ENTEREDCLI}){$self->enterSwmml();}
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $self->{CMDRESULTS} = [];
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=>45 )) {
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    push(@{$self->{CMDRESULTS}},@cmdResults);
    if(grep /Error/is, @cmdResults){
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        &error(__PACKAGE__ . ".execCmd CMD ERROR - EXITING");
    }else{
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  UNKNOWN CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        &error(__PACKAGE__ . ".execCmd CMD ERROR - EXITING");
    }
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  # Remove the escape character that seems to populate each response...
  foreach(@cmdResults){
    $_ =~ s/\e//g;
  }
  push(@{$self->{CMDRESULTS}},@cmdResults);
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  push(@{$self->{HISTORY}},$cmd);
  return @cmdResults;
}
=pod

=head2 B<execFuncCall()>

  This routine is responsible for executing commands that are to be generated and verified by the XML libraries.

=over

=item Argument

  func - A string that represents the standard function ID from within the XML files.
  hash - hash of key value pairs

=item Returns

  Success - returns 1
  Failure - returns 0

=item Example:

  $obj->execFuncCall('func_id',\%hash);

=back

=cut

sub execFuncCall (){
	my ($self,$func,$mKeyVals)=@_;
	my($logger, @cmdResults,$cmd,$flag,$key,$value,$cmdTmp, $funcCp);
        if(Log::Log4perl::initialized()){
          $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execFuncCall");
        }else{
          $logger = Log::Log4perl->easy_init($DEBUG);
        }
        if(!$self->{ENTEREDCLI}){$self->enterSwmml();}
	my @manKeys = (); my @optKeys = (); my @stdKeys = ();
        $logger->debug(__PACKAGE__ . ".execFuncCall MOVING PROVIDED KEYS TO LOWER CASE");
	if( keys %{$mKeyVals}) {
	    while(my ($tmpKey, $tmpVal) = each(%$mKeyVals)) {  $mKeyVals->{lc $tmpKey} = delete $mKeyVals->{$tmpKey}; }
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
              return 0;
              
            }
          }
        }
	
        # Kluge: Force un-nested (single) commands to keyed hash;
        if( !$funcCp->{param} ->{'0'} ){
          foreach (sort {$a<=>$b} keys (%{$funcCp->{param}})) {
            $funcCp->{param}->{'0'}->{$_} = $funcCp->{param}->{$_};
            delete $funcCp->{param}->{$_};
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
		if(defined($mKeyVals->{$key})) {
			$funcCp->{param}->{$_}->{defaultvalue} = $mKeyVals->{$key};
			$funcCp->{param}->{$_}->{picked} = 1;
                        $logger->debug(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$_}->{key} IS PICKED");
		}else{
                  $logger->warn(__PACKAGE__ . ".execFuncCall $funcCp->{param}->{$_}->{key} IS NOT PICKED");
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
                  if($cmd !~ m/\:$/){
                    $cmd .= ",";
                  }
                  $cmd .= ($includekey) ?  "$cmdkey" . "$mKeyVals->{$key}" : "$mKeyVals->{$key}";
                  delete $funcCp->{param}->{$_}->{picked};
		}
	}
	$cmd =~ s/^\s+//g;
        $logger->debug(__PACKAGE__ . ".execFuncCall FORMULATED COMMAND: $cmd");
        $flag = 1; # Assume cmd will work
        @cmdResults = $self->execCmd($cmd);
        foreach(@cmdResults) {
            if(m/(syntax\s+error|M\s+DENY)/i){
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

=head2 B<enterSwmml>

 This routine helps to enter into the 'swmml'. 

=over

=item Argument

  None

=item Returns

  None

=back 

=cut

sub enterSwmml(){
  my $self = shift;
  my($logger, $prevPrompt, @results);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".enterSwmml");
  $self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/\<.*\>\s.*$/');
  $logger->info(__PACKAGE__ . ".enterSwmml  ATTEMPTING TO ENTER SWMML");
  @results = $self->{conn}->cmd("swmml");
  # The below line has been commented by Malc - 20/03/2008
#  @results = $self->{conn}->cmd("\t");
  $logger->info(__PACKAGE__ . ".enterSwmml  ENTERED SWMML");
  $self->{ENTEREDCLI} = 1;
}
=pod

=head2 B<enterSwmml>

 This routine helps to exit from 'swmml'.

=over

=item Argument

  None

=item Returns

  None

=back

=cut

sub exitSwmml(){
  my $self = shift;
  my($logger, $prevPrompt, @results);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".exitSwmml");
  if($self->{ENTEREDCLI}){
    $logger->debug(__PACKAGE__ . ".exitSwmml EXITING SWMLL CLI");
    $self->{conn}->last_prompt("");
    $prevPrompt = $self->{conn}->prompt($self->{PROMPT});
    if($self->{conn}->cmd("exit")){
      $self->{ENTEREDCLI} = 0;
      return 1;
    }else{
      return 0;
    }
  }else{
    $logger->debug(__PACKAGE__ . ".exitSwmml SWMLL CLI FLAG (ENTEREDCLI) IS NOT SET - NO NEED TO EXIT");
  }
  return 1;
}

=pod

=head1 B<autogenXML>

  This routine is responsible for auto-generation of XML libraries for the object instantiated.

=over 

=item Argument

  None

=item Returns

  None

=item Example:

  $obj->autogenXML();

=back

=cut

sub autogenXML(){
  my $self = shift;
  my (@results, @omniCmds, %omniCmds, $logger, $prevPrompt);
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".autogenXML");
  }
  else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $logger->info(__PACKAGE__ . ".autogenXML AUTO-GENERATION OF XML LIBRARY CALLED");
  $logger->debug(__PACKAGE__ . ".autogenXML RETRIEVING AND PROCESSING COMMANDS LIST");
  @results = $self->{conn}->cmd("\t");
  @results = grep /\S/, @results;
  @results = grep /^[A-Z]/, @results;
  foreach(@results){
      my @tmp = split(" ",$_);
      push @omniCmds,@tmp;
  }
  #$self->{conn}->last_prompt("");
  #$prevPrompt = $self->{conn}->prompt($self->{PROMPT});
  #$self->{conn}->cmd("exit");
  if($self->exitSwmml()){
    foreach(@omniCmds){
	my $command = $_;
	chomp($command);
        $logger->debug(__PACKAGE__ . ".autogenXML OMNI SWMML COMMAND EXTRACTED: $command");
	my $cmd1 = $_;
	my $cmd2 = $cmd1;
        $cmd2 =~ s/[\:|\;]//g ;
	my $manfile = "/export/home/omni/man/cat8/$cmd2" . ".8";
        $logger->debug(__PACKAGE__ . ".autogenXML DETERMINED MAN FILE FOR COMMAND EXTRACTION: $manfile");
        $logger->debug(__PACKAGE__ . ".autogenXML EXTRACTING");
        #my $cmd = "export GROFF_FONT_PATH=/usr/share/groff/current/font";  $self->{conn}->cmd($cmd); 
        #$cmd = "groff -Tascii $manfile | col -bx | perl -00 -ne 'print if /$cmd2(?:\\:|\\;|\\[)/'";
        my $cmd = "/usr/bin/cat $manfile | col -bx | perl -00 -ne 'print if /$cmd2(?:\\:|\\;|\\[)/i'";  #- Works kind of
	my @IndividualResults = $self->{conn}->cmd($cmd);
        if(scalar(@IndividualResults) > 0){
          $logger->debug(__PACKAGE__ . ".autogenXML CLEANING UP COMMAND EXTRACTION");
          @IndividualResults = grep /\S/, @IndividualResults;
          @IndividualResults = grep !m/(warning|escape)/, @IndividualResults;
          my $test = join ("",@IndividualResults);
          my @tmpcmd = split(";",$test);
          $omniCmds{$cmd1} = $tmpcmd[0] . ";";
        }
    }
    my $xmlContent = $self->processCmdsToXML(%omniCmds);
    $logger->debug(__PACKAGE__ . ".autogenXML PREPARING FILE SYSTEM FOR LIBRARY DUMP");
    my $path = sprintf("%s/%s", $self->{XMLLIBS},$self->{CLITYPE});
    eval {
        if ( !( -d $path ) ) {
            mkpath( $path, 0, 0777 );
        }
    };
    if(@!){
        $logger->debug(__PACKAGE__ . ".autogenXML ERROR ATTEMPTING TO CREATE FILESYSTEM PATH: $path");
        return 0;
    }
    my $xmlFile2  = sprintf("%s/%s.xml", $path,$self->{VERSION});    
    $logger->debug(__PACKAGE__ . ".autogenXML ATTEMPTING TO OPEN NEW XML LIBRARY FILE: $xmlFile2");
    eval {
        open(FILE2, ">$xmlFile2") or die("Unable to open file: $xmlFile2");
    };
    if(@!){
        $logger->warn(__PACKAGE__ . ".autogenXML ERROR OCCURRED WHILE OPENING LIBRARY FILE: $xmlFile2");
        return 0;
    }
    print FILE2 $self->xmlHeader('SGX', $self->{VERSION}, strftime("%Y%m%d%H%M%S", localtime));
    print FILE2 $xmlContent;
    print FILE2 $self->xmlFooter();
    close FILE2;
  }else{
    $logger->warn(__PACKAGE__ . ".autogenXML UNABLE TO EXIT SWMML CLI INTERFACE");
    
  }
  $self->enterSwmml();
}

=pod

=head2 B<processCmdsToXML>

  Process the given cmds to frame an XML Function.

=over 

=item Argument

  Hash

=item Returns

  scalar - xmlContents

=item Example(s):

 $obj->processCmdsToXML(%omniCmds);

=back

=cut

sub processCmdsToXML(){
  my($self, %omniCmds)=@_;
  my($logger, $cmdCounter,$cmdCounter2, $reverseFunc, $func, $funcParams, $xmlContent );
  $xmlContent = "";
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".processCmdsToXML");
  }
  else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  foreach my $key (sort keys(%omniCmds)) {
      $cmdCounter = 0;
      my $command =   $omniCmds{$key};
      $funcParams = ""; $cmdCounter2 = 0; $cmdCounter = 0; $reverseFunc = "NA";
      $command =~ s/^ *//;
      $command =~ s/(\n|\r)//;
      $command =~ s/\[,/ #/g;
      #$command =~ s/\[:/ #/g;
      $command =~ s/\[:/:\[/g;
      $command =~ s/\[/ #/g;                           
      $command =~ s/\>\]/\>\#/g;
      
      $command =~ s/\}\]/\}\#/g;
      $command =~ s/\]/\#/g;
      my $th = $command;
      $th =~ s/\s{2,}/ /g;
      my $helpDesc = "\t\t<helpdesc><![CDATA[$th]]></helpdesc>\n";
      $command =~ s/\:/\:\+COLON\+/g;
      $command =~ s/\=/\=\+EQUALS\+/g;
      my @commandStruct = split(/(\+COLON\+|\,|\s)/,$command);
      @commandStruct = grep /\S/, @commandStruct;
      @commandStruct = grep /\w/, @commandStruct;
      my $tempfunc = $key; 
      $tempfunc =~ tr/A-Z/a-z/;
      $func  = camelize($tempfunc);
      $func =~ s/-//g;
      my $prevKey;
      my $cnt = 0;
      my $baseCmd = shift(@commandStruct);
      $logger->debug(__PACKAGE__ . ".processCmdsToXML BASE COMMAND - REQUIRED: $baseCmd");
      $funcParams .= $self->xmlParameterBuilder($cmdCounter,$baseCmd,$baseCmd,"undef",0,'R',1,1);
      $cmdCounter++;
      foreach (my $z=0;$z<=$#commandStruct;$z++){
          $_ = $commandStruct[$z];
          
          if(/^[A-Z]/){
            $logger->debug(__PACKAGE__ . ".processCmdsToXML $_ IS A ALPHA/MANDATORY NODE");
            my @tmpArg = split('\+EQUALS\+',$_);
            my $argKey = $tmpArg[0];
            my $arginfo = $tmpArg[1];
            $funcParams .= $self->xmlParameterBuilder($cmdCounter,$argKey,$argKey,"undef",0,'R',1,0);
            if($#tmpArg >2){
              $logger->debug(__PACKAGE__ . ".processCmdsToXML ************************CHECK HERE MANDATORY ARG PROBLEM******************");
            }
          }elsif(/^#/){
              $_ =~ s/#//g;
              my @enums;
              my @tmpArg = split('\+EQUALS\+',$_);
              if($#tmpArg >2){
                $logger->debug(__PACKAGE__ . ".processCmdsToXML ************************CHECK HERE OPTIONAL ARG PROBLEM******************");
              }
              my $argKey = $tmpArg[0];
              my $arginfo = $tmpArg[1];
              if($arginfo =~ /{/){
                  # This means there are enumerations for the argument - record them
                  $arginfo =~ s/\{/\=\{/g;
                  my @argInfoArr = split('\+EQUALS\+',$arginfo);
                  my $primaryArg = $argInfoArr[0];
                  my $enum = $argInfoArr[1];
                  $enum =~ s/(\{|\})//g;
                  $enum =~ s/\|/ /g;
                  @enums = split(" ",$enum);
              }
              if($argKey =~ /{/){
                  # This means there are enumerations for the argument - record them
                  $argKey =~ s/(\{|\})//g;
                  $argKey =~ s/\|/ /g;
                  my @argKeys = split(" ",$argKey);
                  foreach my $subkey (@argKeys){
                      $funcParams .= $self->xmlParameterBuilder($cmdCounter,$subkey,$subkey,"undef",0,'O',1,0);
                      $cmdCounter++;
                  }
              }else{
                  $funcParams .= $self->xmlParameterBuilder($cmdCounter,$argKey,$argKey,"undef",0,'O',1,0);
              }
          }elsif(/^\{/){
              #{PC|DPC}=<identifier> IS A LIST OF NODES
              my @enums;
              my @tmpArg = split('\+EQUALS\+',$_);
              my $argKey = $tmpArg[0];
              $argKey =~ s/(\{|\})//g;
              $argKey =~ s/\|/ /g;
              my @argKeys = split(" ",$argKey);
              my $arginfo = $tmpArg[1];
              if($arginfo =~ /{/){
                  # This means there are enumerations for the argument - record them
                  $arginfo =~ s/\{/\=\{/g;
                  my @argInfoArr = split('\+EQUALS\+',$arginfo);
                  my $primaryArg = $argInfoArr[0];
                  my $enum = $argInfoArr[1];
                  $enum =~ s/(\{|\})//g;
                  $enum =~ s/\|/ /g;
                  @enums = split(" ",$enum);
              }
              foreach my $subkey (@argKeys){
                  $funcParams .= $self->xmlParameterBuilder($cmdCounter,$subkey,$subkey,"undef",0,'O',1,0);
                  $cmdCounter++;
              }
              if($#tmpArg >2){
                $logger->debug(__PACKAGE__ . ".processCmdsToXML ************************CHECK HERE OPTIONAL ARG PROBLEM******************");
                }
          }else{
            $logger->debug(__PACKAGE__ . ".processCmdsToXML I HAVE NO IDEA OF WHAT $_ IS");
             $cmdCounter--;
          }
          $cmdCounter++;
      }
      my $xmlFunc = $self->xmlFunctionBuilder($func,$funcParams,$helpDesc);
      $xmlContent .= "$xmlFunc\n";
  }
  return $xmlContent;
}
=pod

=head2 B<xmlHeader>

  This subroutine builds a xml header with the given values

=over

=item Argument

  $type - xml header type
  $version - xml version
  $build 

=item Returns

  scalar - Framed xml header.

=item Example(s):

  $obj->xmlHeader('header_type','xml_version','build');

=back

=cut

sub xmlHeader(){
    my($self,$type, $version, $built)=@_;
my $xmlHeader =<<ESXML;
<?xml version="1.0" encoding="ISO-8859-1"?>
<?xml-stylesheet type="text/xsl" href="http://masterats.eng.sonusnet.com/xlst/library.xsl"?>
<commandslib>
    <source>SWMML</source>
    <built>$built</built>
    <commandsfile source="SGX CAT8" type="$type" version="$version"/>
ESXML
    return $xmlHeader;
}
=pod

=head2 B<xmlFooter>

  This subroutine builds a xml footer.

=over

=item Argument

  None

=item Returns

  scalar - Framed xml footer.

=item Example(s):

  $obj->xmlFooter();

=back

=cut

sub xmlFooter(){
  my($self)=@_;
my $xmlFooter =<<EOXML;
</commandslib>

EOXML
    return $xmlFooter;
}
=pod

=head2 B<xmlParameterBuilder>

  This subroutine builds a xml parameter with the given values

=over

=item Argument

  $id - xml parameter id
  $cmdkey     
  $key
  $defaultvalue 
  $requires
  $option
  $includeKey 
  $standaloneKey

=item Returns

  scalar - Framed xml parameter.

=item Example(s):

  $obj->xmlParameterBuilder('self','id','cmdkey', 'key','defaultvalue','requires','option','includeKey','standaloneKey');

=back

=cut

sub xmlParameterBuilder(){
    my($self,$id,$cmdkey, $key,$defaultvalue,$requires,$option,$includeKey,$standaloneKey)=@_;
    my $xml = "";
    $key =~ s/(\:|\=|\;)//g;
    $xml="\t\t<param id=\"$id\" key=\"$key\" cmdkey=\"$cmdkey\" defaultvalue=\"$defaultvalue\" option=\"$option\" includeKey=\"$includeKey\" standalone=\"$standaloneKey\"/>\n";
    return $xml;
}
=pod

=head2 B<xmlFunctionBuilder>

  This subroutine builds a xml function with the given parameters 

=over 

=item Argument

  $funcName   - xml function name
  $parameters - xml function contents 
  $helpdesc   - xml helpdesc value

=item Returns

  scalar - Framed xml function.

=item Example(s):

  $obj->xmlFunctionBuilder('func_name','parameters','helpdesc');

=back

=cut

sub xmlFunctionBuilder() {
    my($self, $funcName, $parameters, $helpdesc)=@_;
    $funcName =~ s/(\:|\;)$//;
    my $func = "\t<function id=\"$funcName\">\n";
    $func .= $parameters;
    $func .= $helpdesc;
    $func .= "\t</function>\n";
    return $func;
}

=pod

=head2 B<mmlConfig()>

 mmlConfig method executes a list of mml commands from a file specified.

=over

=item Argument

 -dir
    name of the local folder where file is placed
 -file
    name of the file with mml commands

=item Return

 1 - Success when all commands are executed properly.
 0 - Failure of command execution or inputs not specified.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::mmlConfig(-dir => "/home/work/mml_files",-file => "mml_ansi_cs.txt");

=back

=cut

sub mmlConfig() {

    my($self,%args) = @_;
    my $sub = "mmlConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;
    my $flag = 1; # Return 1 when all commands are successful
    my $dir = undef;
    my $file = undef;

    $dir = $args{-dir};
    $file = $args{-file};
 
    # Error if  local dir is not set
    if ($dir eq undef) {

        $logger->error(__PACKAGE__ . ".$sub Local directory is not specified");
        return 0;
    }

    # Error if file is not set
    if ($file eq undef) {

        $logger->error(__PACKAGE__ . ".$sub file name is not specified");
        return 0;
    }

    # Path where file exists.
    my $path = $dir . "/" . $file;

    # Check if file exists and return 0 if file not existing
    if (system("test -e $path")) {

        $logger->error(__PACKAGE__ . ".$sub Failed to find file specified");
        return 0;
    }
    else {
        open (MML,$path);
        while (<MML>) {

            chomp($_);
            
            # Execute the command in the file one at a time
            @result = $self->execCmd("$_");

            # Check for errors based on command result
            foreach(@result) {
                if(m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub  FAILED - CMD RESULT: $_");
                    $flag = 0;
                    next;
                } elsif (m/M\s+COMPLETED|Current node has been changed|Node already selected/) {
                    $logger->info(__PACKAGE__ . ".$sub  OK - CMD RESULT: $_");
                } elsif (m/\[31m/) {
                    # Silently ignore the returned xterm escape code.
		    # $logger->info(__PACKAGE__ . ".$sub  IGNORED - CMD RESULT: $_");
		} else {
                    $logger->error(__PACKAGE__ . ".$sub UNKNOWN - CMD RESULT: $_");
                    $flag = 0;
                    next;
                }

            } # End foreach
        } # End while
        close MML;
        return $flag;
    } # End else 
} # End sub mmlConfig()

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
