package SonusQA::PSTK;
use Text::CSV;

=head1 NAME

SonusQA::PSTK- Perl module for Professional Services Tool Kit.

=head1 AUTHOR

Mari Satheesh - msatheesh@sonusnet.com

=head1 SYNOPSIS

use ATS; # This is the base class for Automated Testing Structure
##use SonusQA::PSTK; # Only required until this module is included in ATS above.
my $obj = SonusQA::pstk->new(-OBJ_HOST => '<host name | IP Adress>',
    -OBJ_USER => '<cli user name - usually dsi>',
    -OBJ_PASSWORD => '<cli user password>',
    -OBJ_COMMTYPE => "<TELNET|SSH>",
    optional args
    -location => "<where the bin directory of PSTK tool is installed>"
    );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, onusQA::ATSHELPER, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This module provides an interface for the Professional Services Tool Kit.
It provides methods for starting and stopping single-shot and load testing, most cli methods returning true or false (0|1).
Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash,
        allowing the engineer to specific which attributes to use.Complete examples are given for each method.

=head2 METHODS

        GLOBAL :
        $self->{aliasHeaderMap} ;


=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use Net::SCP::Expect;
use vars qw($self);
our @ISA = qw(SonusQA::Base);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------
# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
################################################################################
sub doInitialization {

  my($self, %args)=@_;
  my $sub = "doInitialization()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->info(__PACKAGE__ . ".$sub:   --> Entering Sub ");

  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "v1.15";
  #please define it in TMS otherwise overwrite in Feature.pm
  $self->{BASEPATH} = "/export/home/pstk";

  $self->{FILENAMES} = {
    'collector' => "$self->{BASEPATH}/pstk/etc/collector.cfg" ,
    'pstkstat' => "$self->{BASEPATH}/pstk/etc/pstkstat.cfg",
  } ;
  $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub ");
}
################################################################################

=head1 setSystem()

  This Function is called from Base.pm set the system prompt

=cut
################################################################################
sub setSystem(){
  my($self)=@_;
  my $sub = "setSystem()" ;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
  $logger->info(__PACKAGE__ . ".$sub:   --> Entering Sub ");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd("");
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".$sub:   SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".$sub:   SET PROMPT TO: " . $self->{conn}->last_prompt);
  # Clear the prompt
  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
  $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub ");
  return 1;
}
################################################################################
=head2 createCfgFiles()
  This function enables dynamic creation of the collector.cfg file on the pstk server.
  If the file is already present, then the contents are cleared.

  Argument:
  None.

  Return:
  1: Success
  0: Failure

  usage:
  my $cfg = $pstkObj->createCfgFiles();
  This would create a file collector.cfg under $BASEPATH/pstk/etc directory

=cut
################################################################################
sub createCfgFiles {
  my($self, $filename) = @_;
  my $sub = "createCfgFiles";
  my ($retVal, @retVal,$cmd1,$cmd2);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub:   --> Entering Sub ");

  unless ( $self->{FILENAMES} ) {
    $logger->error(__PACKAGE__ . ".$sub:  .cfg full file name not defined");
    return 0;
  }
  # Clear the contents of the file if it already exists. If not, create a new one
  $cmd1 =
    'echo "
  # FIELDS\
  # name:address:user:pass:cmdtimeout:interval:count:method:prompt:debuglevel:\
  # type:miscopts:orauser:orapass:encpass:sucmd:suuser:supass:suencpass:fcmd:\
  # snmpcommunity:snmpport:snmpinterval:snmpretries:snmptimeout:snmpdebugmask:\
  # adssubsinterval:dsicdrinterval\
    "> ' . %$self->{FILENAMES}->{collector};

    $cmd2 =
    'echo "
  # FIELDS\
  # profile name:field name,field name, etc.\
    "> ' . %$self->{FILENAMES}->{pstkstat};

  #$logger->info(__PACKAGE__ . ".$sub:   Executing commands $cmd1 & $cmd2");

    unless (( $self->{conn}->cmd($cmd1) ) && $self->{conn}->cmd($cmd2) ){
      $logger->error(__PACKAGE__ . ".$sub:   .Unable to write to collector.cfg & pstkstat.cfg file's ");
      $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->error(__PACKAGE__ . ".$sub:   .Command <$cmd1> returned <$retVal>");
      return 0;
    }

  $logger->info(__PACKAGE__ . ".$sub:   Created cfg file's ");
  $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [1]");
  return 1;
}#End of createCfgFiles()
################################################################################
=head2 configCollectorCfg()
  This function is used to write to the cfg file on the pstk server created using createCfgFiles.
  The contents of the file needs to be passed as an input argument.
  This would write to the file collector.cfg under /export/home/pstk/pstk/etc directory on the pstk server with the contents -
  # Poll PSX
  ptpsx2:10.54.10.32:ssuser:x::10::telnet:::psx::::0052616e646f6d495634e81ea6169bcc419201f24ed471ebbf::::::::::::::

  Argument:
  Contents of the file to be passed as an array.

  EXTERNAL FUNCTIONS USED:
  populateCfgfile()

  Return:
  1: Success
  0: Failure

  usage:
   my @contents = ("# Poll PSX",
    "ptpsx2:10.54.10.32:ssuser:x::10::telnet:::psx::::0052616e646f6d495634e81ea6169bcc419201f24ed471ebbf::::::::::::::");

  unless($pstkObject->configCollectorCfg(@contents)){
  $logger->error(__PACKAGE__ ."cfgFILE UPDATION FAILED");
  return 0;
  }
=cut
################################################################################
sub configCollectorCfg {

  my $sub = "configCollectorCfg";
  my($self, @fileContents) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  my ($retVal, @retVal, $cmd);

  unless ( defined ( $self->{FILENAMES}->{collector} )&& defined (@fileContents) ) {
    $logger->error(__PACKAGE__ . ".$sub:  %$self->{FILENAMES}->{collector} file not defined. Invoke createCfgFiles before calling configCollectorCfg");
    $logger->error(__PACKAGE__ . ".$sub:   Please check the contents to be populated in %$self->{FILENAMES}->{collector}");
    return 0;
  }
  unless ( $self->populateCfgfile( $self->{FILENAMES}->{collector},\@fileContents ) ) {
    $logger->error(__PACKAGE__ . ".$sub:   .ERROR populating .cfg file failed");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".$sub:   Updated file $self->{FILENAMES}->{collector} ");
  return 1;

}#End of configCollectorCfg()
################################################################################
=head2 populateCfgfile()
  This function is used to write to the cfg file on the pstk server created using createCfgFiles.
  The contents of the file needs to be passed as an input argument.

  Argument:
  1. cfg file name
  2. Contents of the file to be passed as an array reference.

  Return:
  1: Success
  0: Failure

  usage:
    unless ( $self->populateCfgfile( $self->{FILENAMES}->{collector},/@fileContents) ) {
    $logger->error(__PACKAGE__ . ".$sub:   .ERROR populating .cfg file failed");
    return 0;
    }
=cut
################################################################################
sub populateCfgfile{

  my $sub = "populateCfgfile";
  my($self,$filename,$fileContents) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  $logger->info(__PACKAGE__ . ".$sub:   --> Entering Sub ");

  foreach ( 0..$#{$fileContents}) {
    my $cmd = 'echo "'.$fileContents->[$_].'" >>'.$filename;
#    $logger->info(__PACKAGE__ . ".$sub:   Executing command $cmd");
    unless($self->{conn}->cmd($cmd)) {
      $logger->error(__PACKAGE__ . ".$sub:   .Unable to write to file $filename");
      $logger->error(__PACKAGE__ . ".$sub:   .ERROR in executing Command <$cmd> ");
      $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [0]");
      return 0;
    }
  }
  $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [1]");
  return 1;
}

################################################################################
=head3 SonusQA::PSTK::collectorStart(<command>)

  start collection for a particular node in the config file:

  DEFAULT PATH IS :<$self->{BASEPATH}/pstk/bin> :/export/home/pstk/pstk/bin/

  Command passed shall not have the above path specified, as shown in example below
  my $cmd2 = "collector start all";
  $PSTKObj2->collectorStart($cmd2);

  Returns:
  1 on success
  0 on failure to start.

=cut
################################################################################
sub collectorStart {

  my ($self,$cmd2)=@_;
  my $sub = "collectorStart";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  my ($cmd2,@retOut,@regOut);

  unless ( defined ( $cmd2) ) {
    $cmd2 = "$self->{BASEPATH}/pstk/bin/collector start all";
  }
  $logger->info(__PACKAGE__ . ".$sub:   Executing command $cmd2 ");

  @retOut = $self->{conn}->cmd($cmd2);
  @regOut = map (/Starting\s(\S+)\s+\((\S+)\)\s.+\s\[OK\]/,@retOut);

#forming the ptpsx2_psx_collect.csv filename
#selfobj->{key} = {value}; this should be part of enchancement !!

  $self->{PSTKCSVFILE} = "$regOut[0]\_$regOut[1]\_collect\.csv";
  #Should not move if its for first time creation
  my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time);
  $cmd2 = "mv $self->{BASEPATH}/pstk/log/$self->{PSTKCSVFILE} $self->{BASEPATH}/pstk/log/$self->{PSTKCSVFILE}\_$year$mon$mday\_$hour$min$sec";
  unless ($self->{conn}->cmd($cmd2) ) {
    $logger->error(__PACKAGE__ . ".$sub:  ERROR Moving older/exsisting file [$self->{PSTKCSVFILE}] ");
  }else {
    $logger->debug(__PACKAGE__ . ".$sub:  $cmd2 Success ");
  }

 # $logger->info(__PACKAGE__ . ".$sub:  :  $cmd2");

  if($#regOut >= 0 ) {
    $logger->info(__PACKAGE__ . ".$sub:  Successfully started collecting @regOut");
  }elsif ( grep(/\S+\s+\S+\s+already\s+running\s+/,@retOut)){
    $logger->info(__PACKAGE__ . ".$sub:  Stopping @retOut");
    $self->collectorStop();
    $logger->info(__PACKAGE__ . ".$sub: collectorStop is done trying Collector start ");
    $self->collectorStart();
    @retOut = ();
   }
  else {
    $logger->error(__PACKAGE__ . ".$sub:  ERROR in Collecting @retOut");
    $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [0]");
    return 0;
  }

  # $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [1]");
  return 1;
}
################################################################################
=head3 SonusQA::PSTK::collectorStop(<command>)

  stop collection for a particular node in the config file:

  DEFAULT PATH IS :<$self->{BASEPATH}/pstk/bin> :/export/home/pstk/pstk/bin/

  Command passed shall not have the above path specified, as shown in example below
  my $cmd2 = "collector stop all";
  $PSTKObj2->collectorStop($cmd2);

  Returns:
  1 on success
  0 on failure to start.

=cut
################################################################################
sub collectorStop {

  my ($self,$cmd2)=@_;
  my $sub = "collectorStop";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  my ($cmd2,@retOut,@regOut);

  unless ( defined ( $cmd2) ) {
    $cmd2 = "$self->{BASEPATH}/pstk/bin/collector stop all";
  }
  $logger->info(__PACKAGE__ . ".$sub:   Executing command $cmd2 ");

  @retOut = $self->{conn}->cmd($cmd2);
  @regOut = map (/Stopping\s+(\S+)/,@retOut);

  if($#regOut >= 0 ) {
    $logger->info(__PACKAGE__ . ".$sub:  :  Successfully stopped collecting @regOut");
  }
  else {
    $logger->error(__PACKAGE__ . ".$sub:  ERROR in stopping @retOut");
    $logger->info(__PACKAGE__ . ".$sub:   <-- Leaving Sub [0]");
    return 0;
  }

  return 1;
}
################################################################################
=head2 configPstkStatCfg()

  This function is used to write to the cfg file on the pstk server created using createCfgFiles.
  The contents of the file needs to be passed as an input argument.
  This would write to the file collector.cfg under /export/home/pstk/pstk/etc directory on the pstk server with the contents -
# pstkstat configuration file
  psx:Hostname,Date,Time,TZ,'100-CPU%idle' as 'CPU%busy',CPU%pes,CPU%oracle,'PESDipRateNoExtFixed' as 'Int Dips','PESDipRateExt' as 'Ext Dips','SIPECallRate' as 'SIP cps',CPU%sipe
  psx.mem:Hostname,Date,Time,TZ,CPU%idle,SYSFreeMem,SYSFreeSwap

  Argument:
  Contents of the file to be passed as an array.

  EXTERNAL FUNCTIONS USED:
  populateCfgfile()
parseUserheader()

  Return:
1: Success
0: Failure

usage:
my @contents = ("# pstkstat configuration file",
    "psx:Hostname,Date,Time,TZ,'CPU%idle' , 'CPU%busy',CPU%pes,CPU%oracle,'PESDipRateNoExtFixed' , 'Int Dips','PESDipRateExt' , 'Ext Dips','SIPECallRate' ,'SIP cps',CPU%sipe
    psx.mem:Hostname,Date,Time,TZ,CPU%idle,SYSFreeMem,SYSFreeSwap");

unless($pstkObject->configPstkStatCfg(@contents)){
  $logger->error(__PACKAGE__ ."cfgFILE UPDATION FAILED");
  return 0;
}

=cut
################################################################################
sub configPstkStatCfg {

  my $sub = "configPstkStatCfg";
  my($self, @fileContents) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub);
  my ($retVal, @retVal, $cmd);

  #this function parses @fileContents & stores the headers in an array
  $self->{userHeaders} = $self->parseUserheader(\@fileContents);

  unless ( defined ($self->{FILENAMES}->{pstkstat} ) && defined (@fileContents) ) {
    $logger->error(__PACKAGE__ . ".$sub:   %$self->{FILENAMES}->{pstkstat} file not defined. Invoke createCfgFiles before calling configPstkStatCfg");
    $logger->error(__PACKAGE__ . ".$sub:   Please check the contents to be populated in %$self->{FILENAMES}->{collector}");
    return 0;
  }
  unless ( $self->populateCfgfile( $self->{FILENAMES}->{pstkstat},\@fileContents) ) {
    $logger->error(__PACKAGE__ . ".$sub:   .ERROR populating .cfg file failed");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".$sub:   Updated file $self->{FILENAMES}->{pstkstat} ");

  return 1;

}#End of configPstkStatCfg()
################################################################################
=head3 SonusQA::PSTK::scpFiles(<command>)
  Simple wrappers for scp commands to copy files from remote machine to local machine .
  Errors will be dispalyed at terminal output which might be difficult to handle please use appropiate
  error handler (which is yet to be added ).

  ARGUMENTS:
  filename with its absolute path

  usage:
  $pstkObj->scpFiles("ptpsx2_psx_collect.csv");

Returns:
local file path & name on success
0 on failure

=cut

################################################################################
sub scpFiles{
  my ($self,$logName)=@_;
  my $sub = "scpFiles";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  my ($scpe,$hostip,$errorHandler);
  $logger->info(__PACKAGE__ . ".$sub:  --> Entered sub");

  $hostip = "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}";

  my %scpArgs;
  $scpArgs{-hostip} = $hostip;
  $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
  $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
  $scpArgs{-sourceFilePath} = "$hostip:$logName";
  $scpArgs{-destinationFilePath} = "$hostip\_$self->{PSTKCSVFILE}";

  if ( $logName =~ /_collect.csv/ ) {
    if(&SonusQA::Base::secureCopy(%scpArgs)){
       $logger->debug(__PACKAGE__ . ".$sub:  $logName File copied to $hostip\_$self->{PSTKCSVFILE}");
    }else {
       $logger->debug(__PACKAGE__ . ".$sub:  ERROR in copying $logName to $hostip\_$self->{PSTKCSVFILE}");
    }
 }
  else {
    $logger->error(__PACKAGE__ . ".$sub:  $logName not a valid file to copy");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub [0]");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving sub [1]");
  return "$hostip\_$self->{PSTKCSVFILE}";
}

################################################################################
=head3 SonusQA::PSTK::parseLocalCsvWithAlias()
  parse the local csv file replace the standered header with the user header

  ARGUMENTS:
  Nothing

  Returns:
  1 on success
  0 on failure


=cut
################################################################################
sub parseLocalCsvWithAlias() {

  my ($self) = @_;
  my $sub = "parseLocalCsvWithAlias";
  my (@csvFirstrow,@evalArray,@mod_isect,$csv);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->info(__PACKAGE__ . ".$sub:  --> Entered Sub");

  unless ( -s $self->{PSTKCSVFILE} ) {
    $logger->error(__PACKAGE__ . ".$sub:  cannot Parse [$self->{PSTKCSVFILE}] is not found or or empty file ") ;
    return 0 ;
  }
  $csv = Text::CSV->new(always_quote => 0 );
  { #Insert a line at the beginning of a file
    local @ARGV = ($self->{PSTKCSVFILE});#currently only one node element log is parsed later on it ll be
      local $^I = '';  #Enhanced for all the SONUS variants in that case its best to use the below method
      while(<>){       # http://www.tek-tips.com/faqs.cfm?fid=6549
        if ($. == 1) {
          @csvFirstrow = split (/,/ );
          for my $key (keys %{$self->{aliasHeaderMap}}) {
            unless (s/$key/${$self->{aliasHeaderMap}}{$key}/) {
              #$logger->error(__PACKAGE__ . ".$sub:  didn't replace $key with ${$self->{aliasHeaderMap}}{$key}") ;
              push @evalArray , split(/-/, $key) ;
              my $temp = ${$self->{aliasHeaderMap}}{$key};
              $key =~ s/100-//;
              unless(s/$key/$temp/){
                $logger->error(__PACKAGE__ . ".$sub:  ERROR didn't replace $key with $temp") ;
              }
            }
          }
          @mod_isect = $self->intersectArrays(\@evalArray,\@csvFirstrow,);
          print;
        }
        elsif ( $csv->parse($_) ) {
          my @columns = $csv->fields();
          foreach (@mod_isect) {
            $columns[$_] = 100 - $columns[$_];
          }
          $" = ","; #it applies to array values interpolated into a double-quoted string (or similar interpreted string). Default is space.
          print "@columns\n"; #No comma allowed after filehandle
        }
        else {
          my $err = $csv->error_input;
          my $diag = $csv->error_diag ();
          $logger->error(__PACKAGE__ . ".$sub:  parse line ERROR: $err because $diag");
        }
      }$" = " ";
  }

  unless(-s $self->{PSTKCSVFILE}){
    $logger->error(__PACKAGE__ . ".$sub:  CSV File [$self->{PSTKCSVFILE}] is not found or empty file ") ;
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving Sub [0]");
    return 0 ;
  }
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub [1]");
  return 1;
}
################################################################################
=head3 SonusQA::PSTK::fetchPstkStat(<command>)

  The pstkstat command prints performance statistics as they are collected by PSTK in a manner
  a CSV file is generated after parisng the pstkstat user contenets with the _collect_csv.log file

  example
  Hostname Date Time TZ CPU%busy CPU%pes CPU%oracle Int Dips Ext Dips
  sid 2007-10-09 16:40:49 GMT 4 2.3 0.6 21.9 0.0
  sid 2007-10-09 16:41:19 GMT 4 2.3 0.6 22.1 0.0
  sid 2007-10-09 16:41:49 GMT 3 2.3 0.6 21.9 0.0

  external functions :
  scpFiles
  intersectArrays

  Returns:
  1 on success
  0 on failure

=cut
################################################################################
sub fetchPstkStat {

  my ($self,$cmd2)=@_;
  my $sub = "fetchPstkStat";
  my (@headerPsxCollect,$logger,$csvLogName,@isect,$csv);

  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->debug(__PACKAGE__ . ".$sub:  --> Entered Sub ");

  unless ($csvLogName = $self->scpFiles("$self->{BASEPATH}/pstk/log/$self->{PSTKCSVFILE}")){
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving Sub [0]");
    return 0 ;
  }

# check whether the file exists or not
  unless ( -s $csvLogName) {
    $logger->error(__PACKAGE__ . ".$sub:  :  File [$csvLogName] doesnot exists or file is empty");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving Sub [0]");
    return 0;
  }

#Whenever the PSTK tool version gets changed there is a possibility of header
#alteration so , fetching the header from PSTK tool itself instead of hard coding
  @headerPsxCollect = $self->{conn}->cmd("/export/home/pstk/pstk/bin/psx_collect -d");
  @headerPsxCollect = @headerPsxCollect[2..($#headerPsxCollect-1)];

  { #Insert a line at the beginning of a file
    local @ARGV = ($csvLogName);#currently only one node element log is parsed later on it ll be
      local $^I = ''; #Enhanced for all the SONUS variants in that case its best to use the below method
      while(<>){# http://www.tek-tips.com/faqs.cfm?fid=6549
        s/^<S>\n// ;s/^\n// ;
        if ($. == 1) {
          print "@headerPsxCollect";
        } else {
          print;
        }
      }
  }

  open (outCSV, ">", "$self->{PSTKCSVFILE}") or $logger->error(__PACKAGE__ . ".$sub:  ERROR $!");
  open (CSV, "<", $csvLogName) or $logger->error(__PACKAGE__ . ".$sub:  ERROR $!");

  $csv = Text::CSV->new();

  while (<CSV>) {
    if ($. == 1){
      @headerPsxCollect = split (/,/);
      @isect = $self->intersectArrays($self->{userHeaders},\@headerPsxCollect);
    }
    if ($csv->parse($_)) {
      my @columns = $csv->fields();
      foreach (@isect) {
        print outCSV"$columns[$_],";
      }
      print outCSV "\n"; #No comma allowed after filehandle
    } else {
      my $err = $csv->error_input;
      $logger->error(__PACKAGE__ . ".$sub:  parse line Failed: $err");
    }
  }
  close CSV ;close outCSV ;

  unless ( $self->parseLocalCsvWithAlias() ) {
    $logger->error(__PACKAGE__ . ".$sub:  ERROR parsing Local csv With Alias Header Failed ") ;
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving Sub [0]");
    return 0 ;
  }
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub [1]");
  return 1;
}
################################################################################
=head3 SonusQA::PSTK::intersectArrays(<command>)
  Compares two arrays and return an array with index of matched elements
  probably we can try some more efficient techinques
  This operation is heavy ! but no other go we can replace with map() but internally it does the same

  ARGUMENTS:
  two array references to reduce the memory

  Returns:
  indexes of matched arr1 position wrt arr2

=cut
################################################################################
sub intersectArrays() {
  my ($self,$arr1, $arr2) = @_;
  my ($val1,@diffs,$logger,$sub) ;
  $sub = "intersectArrays()";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->info(__PACKAGE__ . ".$sub:  --> Entered Sub ");

  foreach (0 .. $#{$arr1}) {
    $val1 = $arr1->[$_];
    foreach (0 .. $#{$arr2}) {
      if ( grep/$val1/,$arr2->[$_]){
        push @diffs, $_ ;
        last;
      }
    }
  }
  $logger->debug(__PACKAGE__ . ".$sub:  Index are : @diffs ");
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub ");
  return @diffs;
}
################################################################################
=head3 SonusQA::PSTK::parseUserheader(<command>)
  this parses the contents of an array fetches each word and stores in a list avoid 'as & 100'
  the main intention is to reduce the number of iteration of array operations
  this drastically reduces the array size from 5:1

  ARGUMENTS:
  array reference

  Returns:
  ARRAY with indexes of matched arr1 position wrt arr2


=cut
################################################################################
sub parseUserheader() {
  my ($self,$fileContents_ref) = @_;
  my (@userHeaderArray,$ar,$i,@aliasHeaderArray,%aliasHeaderMap);
  my $sub = "parseUserheader";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->debug(__PACKAGE__ . ".$sub:  --> Entered Sub");

  foreach (0 .. $#{$fileContents_ref}) {
    if( grep (!/^#/,$fileContents_ref->[$_])) {
      push (@userHeaderArray , split (/[,.:'-]/,$fileContents_ref->[$_]) );
      push ( @aliasHeaderArray , split (/,/,$fileContents_ref->[$_]) ); #this is to do 'PESDipRateExt' as 'Ext Dips'
    }
    foreach (@userHeaderArray) {
      s/[,.:'-]//;#use substitution &remove
      s/as//;s/100//;s/\t+//;s/\n//;
    }
  }
# this also overrides if it encounters two same alias headers
  our %aliasHeaderMap = map (/'([\S]+)'\sas\s\'([\w\s%]+)'/,@aliasHeaderArray);

  $self->{aliasHeaderMap} = \%aliasHeaderMap ;
#incrementing hash is done here which increments the value field when the key strikes once again !
  sub remove_duplicates(\@)#http://www.perlmonks.org/?node_id=90493
  {
    $ar = shift;
    my %seen;
    for ($i = 0; $i <= $#{$ar} ; ){
      splice @$ar, --$i, 1 if $seen{$ar->[$i++]}++;
    }
  }
  remove_duplicates (@userHeaderArray);
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub");
  return \@userHeaderArray;
}
################################################################################
=head3 SonusQA::PSTK::CsvFilesTransfer(<testcaseID>)
  This reads IP from TMS and sends to any TFTP server running on that IP.Here
  the file name is hardcoded and should be called from FEATURE.pm
  output file is appended with the testcase ID.The order of the arguments
  should be preserved.

  ARGUMENTS:
    my $fileTxFlag = $pstkObj->CsvFilesTransfer($test_id,"PSTK_proxy_server.xml_$SippServerPID\_.csv",
      "PSTK_proxy_client.xml_$SippClientPID\_.csv");
 test_id should be the MANDATORY FIRST ARGUMANET

  Returns:
  NOTHING


=cut
################################################################################
sub CsvFilesTransfer() {
  my ($self,$test_id,@files4Tx) = @_;
  my $sub = "CsvFilesTransfer";
  my (@verboseTftp,$result);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub:  ");
  $logger->debug(__PACKAGE__ . ".$sub:  --> Entered Sub");

       my $tftpIPaddress = $self->{TMS_ALIAS_DATA}->{'TFTP'}->{'1'}->{'IP'};
        chomp($tftpIPaddress);
        $logger->debug(__PACKAGE__ . ".$sub:  TFTP IP $tftpIPaddress retrieved from TMS.");

        unless ( defined ($tftpIPaddress)){
            $logger->error(__PACKAGE__ . ".$sub:   The TFTP IP is blank or empty");
            $logger->info( ".$sub:  <-- Leaving Sub [0]");
            return 0;
        }
  push @files4Tx ,$self->{PSTKCSVFILE};
  $logger->info( __PACKAGE__ .".$sub: FILES to be transferred @files4Tx");

  foreach(@files4Tx) {

    if($_ =~ /collect.csv/) {
      @verboseTftp = `tftp -v $tftpIPaddress -c put $_ $test_id\_$_`;
    }elsif ($_ =~ /(\w+.?xml_\d+_.csv)/) {
      my $outputFilename = $1;
      @verboseTftp = `tftp -v $tftpIPaddress -c put $_ $test_id\_$1`;
    }else{
     @verboseTftp = `tftp -v $tftpIPaddress -c put $_ $test_id\_$_`;
     $logger->error(__PACKAGE__ . ".$sub:  $_ is this a Valid CSV file to be transfered ?");
    }
    if ( map (/Sent\s(\d+)\s+bytes\s+in\s+\S+\s+seconds/,@verboseTftp)) {
        $logger->debug(__PACKAGE__ . ".$sub:  $_ Transfered ");
        $result++ ;
    }elsif(map (/Transfer\s+timed\s+out./,@verboseTftp)){
        $logger->error(__PACKAGE__ . ".$sub:   Please Check TFTP Server Service - Transfer timed out");
    }else{
        $logger->error(__PACKAGE__ . ".$sub:   Error in TFTP - @verboseTftp");
    }
    @verboseTftp = ();
  }

  unless( $result >= 3 ){
    $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub [0]");
    return 0;
  }
  $logger->info(__PACKAGE__ . ".$sub:  <-- Leaving Sub [1]");
  return 1;
}
################################################################################
1;
__END__
