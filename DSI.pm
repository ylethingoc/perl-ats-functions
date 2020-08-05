package SonusQA::DSI;

=pod

=head1 NAME

 SonusQA::DSI - Perl module for Sonus Networks Data Stream Integrator (DSI) Unix Side Interaction

=head1 SYNOPSIS

 use ATS;  # This is the base class for Automated Testing Structure
  
 my $obj = SonusQA::DSI->new(
                              #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name - usually admin>',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_COMMTYPE => "<TELNET | SSH>",
                              
                              # OPTIONAL PARAMETERS:
                              # CURRENTLY NONE.
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
    CURRENTLY NONE

=head1 DESCRIPTION

 This module provides an interface for the DSI Unix interface (Unix CLI).  This module should be considered for all intents and purposes the NFS module.  
 Any NFS actions should be coded into this module.
   
 This module does not utilize a XML infrastructure.
   
 This module extends SonusQA::Base.

=head1 AUTHORS

 Darren Ball <dball@sonusnet.com>  alternatively contact <sonus-auto-core@sonusnet.com>. See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, POSIX, Data::Dumper, Text::CSV, Module::Locate, SonusQA::Utils

=head1 ISA

 SonusQA::Base SonusQA::SessUnixBase SonusQA::DSI::DSIHELPER

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use Text::CSV;


our $VERSION = "1.0";
use vars qw($VERSION $self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase SonusQA::DSI::DSIHELPER);

=head1 B<sub doInitialization()>

=over 6

=item DESCRIPTION:

 Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically, use to set Object 
 specific flags, paths, and prompts.

=item PACKAGE:

 SonusQA::DSI

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
  $self->{COMMTYPES} = ["TELNET", "SSH","SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*([\$%\}\|\>].*|# )$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  
  #Some default flags for performing logical operations.
  
}

=head1 B<sub setSystem()>

=over 6

=item DESCRIPTION:

 Base module over-ride.  This routine is responsible to completeing the connection to the object. It performs some basic operations on the GSX to enable a more 
 efficient automation environment.
  
 Some of the items or actions it is performing:
    Sets Unix SHELL to 'bash'
    Sets PROMPT to AUTOMATION#

=item PACKAGE:

 SonusQA::DSI

=item ARGUMENTS:

 NONE 

=item RETURN:

 NONE   

=back

=cut

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd("");
  $self->{conn}->cmd("stty rows 1000"); 
  $self->{conn}->cmd(""); 
  $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  # Clear the prompt
  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

  my @platform = $self->{conn}->cmd('uname');
  @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = @platform;
  chomp @platform;
  my @version = ();
  if ($platform[0] =~ /Linux/i) {
     $logger->info(__PACKAGE__ . ".setSystem ******* this is a Linux platform*****");
     @version = $self->{conn}->cmd('rpm -q SONSdsi');
     if ($version[0] =~ /(V\w+\.\w+\.\w+\-\w+)/i) {
        $main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"} = $1 unless ($main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"});
        $self->{DUT_VERSIONS} = $1;
     } else {
        $version[0] =~ s/(SONSdsi-|\s)//ig;
        $main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"} = $version[0] unless ($main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"});
        $self->{DUT_VERSIONS} = $version[0];
     }
  } else {

     @version = $self->{conn}->cmd('pkginfo -l SONSdsi');
     chomp @version;
     foreach (@version) {
        if ($_ =~ /VERSION:\s+(\S+)/i) {
            $main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"} = $1 unless ($main::TESTSUITE->{DUT_VERSIONS}->{"DSI,$self->{TMS_ALIAS_NAME}"});
            $self->{DUT_VERSIONS} = $1;
            last;
        }
     }
  }
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
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

 SonusQA::DSI

=item ARGUMENTS:

 -cmd <Scalar>
  A string of command parameters and values

=item RETURN:

 Boolean
 This will attempt to return the Unix CLI command signal. If the command to determine this signal fails - 0 is returned by default
  
=item EXAMPLE(s):

 $obj->execCmd("date");

=back

=cut

sub execCmd {  
  my ($self,$cmd)=@_;
  my($flag, $logger,$ok,@cmdResults,$timestamp,$prevBinMode,$lines,$last_prompt, $lastpos, $firstpos);
  $flag = 1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();

  $self->{conn}->buffer_empty;

  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $self->{DEFAULTTIMEOUT} )) {
    $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
    $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  unless ($ok = $self->{conn}->cmd(String => 'echo $?', Timeout => 1 )) {
    $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
    return 0;
  };
  return not $ok;
}

=head1 B<sub parseCDR()>

=over 6

=item DESCRIPTION:

 This routine is used for parsing individial Call Detail Records (CDR).  This routine will split the CDR into an array element.
  
 CDR records may have nested, delimited (comma) fields, that are enclosed in double quotes. This routine will break this fields out into a nested array structure.  
  
=item PACKAGE:

 SonusQA::DSI

=item ARGUMENTS:

 -CDR RECORD <Scalar>
  A call detail record (delimited string (comma)).

=item RETURN:

 -ARRAY
  This routine will return the record broken out into an array for easy parsing.
  
=item EXAMPLE(s):

 my @cdr = $dsiObj->parseCDR('INTERMEDIATE,CORONA,0x00010C1600000004,65223,GMT-05:00-Eastern,09/27/2006,19:09:33.8,2,2000,09/27/2006,19:09:58.8,500,Circuit Switched 
 Voice,PSTN-TO-PSTN,DEFAULT,,3312341235,2064445555,,0,,0,,0,3312341235,COR-CLART1,1,CORONA:CLART1,,,CLART1,1:8:9:5:0:0x00000000:0x00000000,,1:8:9:1:0:0x00000000:
 0x00000000,,,0x00000004,,3,3,5,5,,,0x00,2064445555,1,8,,CLART1,,3312341235,0,0,,2,17,110,,,1,,,17,0x0007000F,0,,,,,,0,,,,,,,,,,,6,,,,,,1,1,1,1,,4,,,2,2,,2,0,500,,,,
 ,6,8,8,,,,,,,,,1,,7,TANDEM,,,,,,,13,1,,,,,"asfasf,asdfasdf,asdfasdfasdf,asdfasdfasdf,asdf",,,,');
 $logger->info(Dumper(@cdr));
  
 # Will Produce:

 2007/08/03 11:26:46 INFO 112 SonusQA::DSI.parseCDR FOUND DELIMITED FIELD AT INDEX: 133
 2007/08/03 11:26:46 INFO 113 SonusQA::DSI.parseCDR CONVERTING TO ARRAY STRUCT
 2007/08/03 11:26:46 INFO 164 $VAR1 = 'INTERMEDIATE';
 $VAR2 = 'CORONA';
 $VAR3 = '0x00010C1600000004';
 $VAR4 = '65223';
 $VAR5 = 'GMT-05:00-Eastern';
 $VAR6 = '09/27/2006';
 $VAR7 = '19:09:33.8';
 $VAR8 = '2';
 $VAR9 = '2000';
 $VAR10 = '09/27/2006';
 $VAR11 = '19:09:58.8';
 $VAR12 = '500';
 $VAR13 = 'Circuit Switched Voice';
 $VAR14 = 'PSTN-TO-PSTN';
 $VAR15 = 'DEFAULT';
 $VAR16 = '';
 $VAR17 = '3312341235';
 $VAR18 = '2064445555';
 $VAR19 = '';
 $VAR20 = '0';
 $VAR21 = '';
 $VAR22 = '0';
 $VAR23 = '';
 $VAR24 = '0';
 $VAR25 = '3312341235';
 $VAR26 = 'COR-CLART1';
 $VAR27 = '1';
 $VAR28 = 'CORONA:CLART1';
 $VAR29 = '';
 $VAR30 = '';
 $VAR31 = 'CLART1';
 $VAR32 = '1:8:9:5:0:0x00000000:0x00000000';
 $VAR33 = '';
 $VAR34 = '1:8:9:1:0:0x00000000:0x00000000';
 $VAR35 = '';
 $VAR36 = '';
 $VAR37 = '0x00000004';
 $VAR38 = '';
 $VAR39 = '3';
 $VAR40 = '3';
 $VAR41 = '5';
 $VAR42 = '5';
 $VAR43 = '';
 $VAR44 = '';
 $VAR45 = '0x00';
 $VAR46 = '2064445555';
 $VAR47 = '1';
 $VAR48 = '8';
 $VAR49 = '';
 $VAR50 = 'CLART1';
 $VAR51 = '';
 $VAR52 = '3312341235';
 $VAR53 = '0';
 $VAR54 = '0';
 $VAR55 = '';
 $VAR56 = '2';
 $VAR57 = '17';
 $VAR58 = '110';
 $VAR59 = '';
 $VAR60 = '';
 $VAR61 = '1';
 $VAR62 = '';
 $VAR63 = '';
 $VAR64 = '17';
 $VAR65 = '0x0007000F';
 $VAR66 = '0';
 $VAR67 = '';
 $VAR68 = '';
 $VAR69 = '';
 $VAR70 = '';
 $VAR71 = '';
 $VAR72 = '0';
 $VAR73 = '';
 $VAR74 = '';
 $VAR75 = '';
 $VAR76 = '';
 $VAR77 = '';
 $VAR78 = '';
 $VAR79 = '';
 $VAR80 = '';
 $VAR81 = '';
 $VAR82 = '';
 $VAR83 = '6';
 $VAR84 = '';
 $VAR85 = '';
 $VAR86 = '';
 $VAR87 = '';
 $VAR88 = '';
 $VAR89 = '1';
 $VAR90 = '1';
 $VAR91 = '1';
 $VAR92 = '1';
 $VAR93 = '';
 $VAR94 = '4';
 $VAR95 = '';
 $VAR96 = '';
 $VAR97 = '2';
 $VAR98 = '2';
 $VAR99 = '';
 $VAR100 = '2';
 $VAR101 = '0';
 $VAR102 = '500';
 $VAR103 = '';
 $VAR104 = '';
 $VAR105 = '';
 $VAR106 = '';
 $VAR107 = '6';
 $VAR108 = '8';
 $VAR109 = '8';
 $VAR110 = '';
 $VAR111 = '';
 $VAR112 = '';
 $VAR113 = '';
 $VAR114 = '';
 $VAR115 = '';
 $VAR116 = '';
 $VAR117 = '';
 $VAR118 = '1';
 $VAR119 = '';
 $VAR120 = '7';
 $VAR121 = 'TANDEM';
 $VAR122 = '';
 $VAR123 = '';
 $VAR124 = '';
 $VAR125 = '';
 $VAR126 = '';
 $VAR127 = '';
 $VAR128 = '13';
 $VAR129 = '1';
 $VAR130 = '';
 $VAR131 = '';
 $VAR132 = '';
 $VAR133 = '';
 $VAR134 = ['asfasf','asdfasdf','asdfasdfasdf','asdfasdfasdf','asdf'];
 $VAR135 = '';
 $VAR136 = '';
 $VAR137 = '';
 $VAR138 = ''; 

=back

=cut

sub parseCDR(){
  my ($self,$record)=@_;
  my($logger, $csv, @record);
  $#record = -1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".parseCDR");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  if(!defined($record)){
    $logger->warn(__PACKAGE__ . ".parseCDR RECORD MUST BE PASSED TO THIS FUNCTION - IT IS EMPTY");
    return ();
  }
  $csv = Text::CSV->new();
  $csv->parse($record);  
  @record = $csv->fields;
  for(my $i=0; $i<$#record; $i++){
    if($record[$i] =~ m/,/){
      $logger->info(__PACKAGE__ . ".parseCDR FOUND DELIMITED FIELD AT INDEX: $i");
      $logger->info(__PACKAGE__ . ".parseCDR CONVERTING TO ARRAY STRUCT");
      my @df = split(/,/,$record[$i]);
      $record[$i] = "";  $record[$i] = ();
      push (@{$record[$i]}, @df);
    }
  } 
  return @record;
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

=head1 B<sub searchLog()>

=over 6

=item DESCRIPTION:

 This subroutine is used to find the number of occurrences of a list of patterns in given log file

=item PACKAGE:

 SonusQA::DSI

=item ARGUMENTS:

 Array containing the list of patterns to be searched in the log file

=item RETURN:

 Hash containing the pattern being searched as the key and the number of occurrences of the same in the given file as the value

=item EXAMPLE:

 my @patt = ("msg","msg =","abc");
 my %res = $dsiobj->searchLog(\@patt);

=item Author :
 
 Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub searchLog() {
    my ($self,$fileName,$patterns)=@_;
    my (%returnHash,$cmd1,$patt,$string,$logger);
    my @pattArray = @$patterns;

    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".searchLog");
    foreach $patt (@pattArray){
        $cmd1 = 'grep -c "'.$patt.'" '. $fileName;

        my @cmdResults;
        unless (@cmdResults = $self->{conn}->cmd(String => $cmd1, Timeout => $self->{DEFAULTTIMEOUT} )) {
            $logger->warn(__PACKAGE__ . ".searchLog  COMMAND EXECUTION ERROR OCCURRED");
	    $logger->debug(__PACKAGE__ . ".searchLog  errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".searchLog  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".searchLog  Session Input Log is: $self->{sessionLog2}");
            return %returnHash;
        }

        $string = $cmdResults[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $logger->debug(__PACKAGE__ . ".searchLog Number of occurrences of the string \"$patt\" in $fileName is $string");
        unless($string){
           $logger->error(__PACKAGE__ . ".searchLog No occurrence of $patt in $fileName");
           $string = 0;
        };
        $returnHash{$patt} = $string;
    }
    return %returnHash;
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
