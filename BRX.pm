package SonusQA::BRX;

=pod

=head1 NAME

SonusQA::BRX- Perl module for BRX UNix side interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $obj = SonusQA::BRX->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH|SFTP|FTP>",
                               );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for the BRX Unix side.
   It provides methods for both postive and negative testing, most cli methods returning true or false (0|1).
   Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, 
   allowing the engineer to specific which attributes to use.  Complete examples are given for each method.

=head2 AUTHORS

Wasim Mohd <wmohammed@sonusnet.com>, alternatively, contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;
use SonusQA::BRX::BRXHELPER;


our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase SonusQA::BRX::BRXHELPER);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%\}\|\>].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{VERSION} = "UNKNOWN";
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
  $self->{XMLLIBS} = $self->{DIRECTORY_LOCATION} . "xml";
  #$self->{SSBIN} = "/export/home/ssuser/SOFTSWITCH/BIN";
  
  $self->{PATHBIN} = '/home/brxuser/BRX/BIN';
  $self->{sftp_session} = undef;
  $self->{scpe} = undef;
  $self->{dnsObj} = undef;
}

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $self->{conn}->cmd("bash");
  $self->{conn}->cmd(""); 
 $cmd = 'export PS1="AUTOMATION> "';
  $self->{conn}->last_prompt("");
  $self->{PROMPT} = '/AUTOMATION\> $/';
 $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd(" ");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);

  @results = $self->{conn}->cmd("unset PROMPT_COMMAND");
  $logger->info(__PACKAGE__ . ".setSystem Unset \$PROMPT_COMMAND to avoid errors");
 
  # Set some more defaults for commonly used utilities
  #$self->{STARTSS} = "$self->{SSBIN}/start.ssoftswitch";
  #$self->{STOPSS} = "$self->{SSBIN}/stop.ssoftswitch";
  $self->{SIPEMGMT} = "sipemgmt";
  $self->{SSMGMT} = "ssmgmt";
  $self->{SLWREDMGMT} = "slwresdmgmt";
  $self->{STARTSS} = "start.ssoftswitch";
  $self->{STOPSS} = "stop.ssoftswitch";
  #$self->{SCPAMGMT} = "$self->{SSBIN}/scpamgmt";
  # Clear the prompt
  $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

  if ($self->{OBJ_USER} =~ /brxuser/i) {
     my @version_info = ();
     unless (@version_info = $self->{conn}->cmd('pes -v')) {
        $logger->error(__PACKAGE__ . ".setSystem CMD: \'pes -v\' failed");
     } else {
        chomp @version_info;
        $self->{VERSION} = $version_info[0];
        if (defined $main::TESTSUITE and keys %{$main::TESTSUITE}) {
            $main::TESTSUITE->{DUT_VERSIONS}->{"BRX,$self->{TMS_ALIAS_NAME}"} = $self->{VERSION} unless ($main::TESTSUITE->{DUT_VERSIONS}->{"BRX,$self->{TMS_ALIAS_NAME}"});
        }
     }
  }

  @{$main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{UNAME}} = $self->execCmd('uname');
  $logger->debug(__PACKAGE__ . ".setSystem <-- Leaving sub [1]");
  return 1;

}


sub execCmd {  
  my ($self,$cmd, $timeout)=@_;
  my($flag, $logger, @cmdResults,$timestamp,$prevBinMode,$lines,$last_prompt, $lastpos, $firstpos);
  $flag = 1;
  if(Log::Log4perl::initialized()){
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  }else{
    $logger = Log::Log4perl->easy_init($DEBUG);
  }
  
  unless ( defined $timeout ) {
      $timeout = $self->{DEFAULTTIMEOUT};
  }
  
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $timeout )) {
    $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
    $logger->debug(__PACKAGE__ . ".execCmd: errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".Session Input Log is: $self->{sessionLog2}");
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{CMDRESULTS}},@cmdResults);
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
  foreach(@cmdResults) {
    if(m/(Permission|Error)/i){
        if($self->{CMDERRORFLAG}){
          $logger->warn(__PACKAGE__ . ".execCmd  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
          &error("CMD FAILURE: $cmd");
        }
        $flag = 0;
        last;
    }
  }

return @cmdResults;
}
 
=head1 sipemgmtStats () 

DESCRIPTION:

 This subroutine will get the sipemgmt stats for the user passed numbers from the menu and return the results of those
 in an array.
 
 The menu is :
 
                 ===================================================
                         Sonus SIP Engine Management Menu
                ===================================================
                1.       Trace Level DEBUG ON
                2.       Trace Level DEBUG OFF
                3.       Trace Level TRACE ON
                4.       Trace Level TRACE OFF
                5.       Hex Dump ON
                6.       Hex Dump OFF
                7.       Get Sipe Counters
                8.       Get Sipe Proxy Counters
                9.       Get Sipe Summary Counters
                10.      Get Sipe Misc Counters
                11.      Get All Sipe Counters
                12.      Reset Sipe counters
                13.      Reset Sipe Proxy Counters
                14.      Reset Sipe Summary Counters
                15.      Reset Sipe Misc Counters
                16.      Reset All Sipe Counters
                20.      Garbage Collection and Cleanup
                21.      Get SIPE DNS Counters
                22.      Reset SIPE DNS Counters
                23.      Reset SIPE DNS Timers
                30.      Address Reachability Service Menu
                q.       Exit


ARGUMENTS:

 Mandatory :
 
  -sequence     =>  ["11" , "2" , "5" ] . here you pass the numbers that you want to
                                          see the output for.
                      if ["30"] , then it will be assumed that you want to recover the blacklisted servers
                                   and the API will proceed accordingly.
  
PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( @result = $brxObj->sipemgmtStats( -sequence => ["11" , "2" ] ,
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

unless ( @result = $brxObj->sipemgmtStats( -sequence => ["30-1-2" ] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }
        
AUTHOR:
Wasim Mohd. ==> wmohammed@sonusnet.com

=cut

sub sipemgmtStats {
    my ($self, %args )=@_;
    my %a;
    
    my $sub = "sipemgmtStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "sipemgmtStats()" );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  
    my (@cmdResults, $cmd, @cmds, $prematch, $match, $prevPrompt , $enterSelPrompt , @results );
    $prevPrompt = $self->{conn}->prompt;
  
    @cmds = @{$a{-sequence}};
    $self->{conn}->print($self->{SIPEMGMT});
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
    $logger->warn(__PACKAGE__ . ".sipemgmtSequence  UNABLE TO ENTER SIPEMGMT MENU SYSTEM");
    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
    return 0;
    };
    $prevPrompt = $self->{conn}->prompt;
    $self->{conn}->prompt('/Enter Selection\:/');
   
    my %clear_ip = %{$a{-clear_from_blacklist}};
    if ( $cmds[0] eq "30-1-2" ) {
        $logger->info(__PACKAGE__ . ".sipemgmtSequence Sequence Number 30-1-2 passed in argument. Will Check for Blacklisted Servers Now ");
        @cmdResults = $self->{conn}->cmd(30);
        push ( @results , @cmdResults );
        @cmdResults = $self->{conn}->cmd(1);
        push ( @results , @cmdResults );
        my ( %blacklistIpPorts , $blackListFlag , $key , $ipCnt);
        $ipCnt = "a";
        foreach ( @cmdResults ) {
            if ($self->{POST_9_0} ) {
                 if ( $_ =~ /\s+(\S+)\s+(\S+)\s+(\d+)/ ) {
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence POST_9_0 is set, so i will take care of Transport protocol");
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence BlackList : IP $1 with Port $3 with Transport $2 found to be blacklisted ");
                     $blacklistIpPorts{$1}{$3} = $2;
                     $blackListFlag = 1;
                 }
            } else {
                 if ( $_ =~ /\s+(\S+)\s+(\d+)/ ) {
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence POST_9_0 is not set, so i wont take care of Transport protocol");
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence BlackList : IP $1 with Port $2 found to be blacklisted ");
                     $blacklistIpPorts{$1}{$2} = 1;
                     $blackListFlag = 1;
                 }
            }
        }

        foreach $key ( keys %blacklistIpPorts ) {
            if ($a{-clear_from_blacklist}) {
                if (!defined $blacklistIpPorts{$key}{$clear_ip{$key}}) {
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence $key - " . $clear_ip{$key} . " doesnt match passed params - mismatch in ip and port");
                     next;
                }
            }

            foreach my $port (keys %{$blacklistIpPorts{$key}}) {

                $logger->info(__PACKAGE__ . ".sipemgmtSequence Recover BlackListed Server : IP $key with Port $port");
                @cmdResults = $self->{conn}->cmd(30);
                push ( @results , @cmdResults );
                $self->{conn}->print(2);
                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Server IP Address to be recovered\:/',
                                                             -errmode => "return",
                                                             -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".scpamgmtSequence  PROBLEM ENTERING IP Address to be recovered $key ");
                     $self->{conn}->cmd("\cC");
	             $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        	     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
                     return 0;
                };
                push ( @results , $prematch );
                push ( @results , $match );
                $self->{conn}->print($key);
               ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Server Port Number\:/',
                                                            -errmode => "return",
                                                            -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".scpamgmtSequence  PROBLEM ENTERING Port Number ");
                     $self->{conn}->cmd("\cC");
		     $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        	     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
                     return 0;
               };
               push ( @results , $prematch );
               push ( @results , $match );
               push ( @results , $port);
               unless ( $self->{POST_9_0} ) {
                     @cmdResults = $self->{conn}->cmd($port);
                     push ( @results , @cmdResults );

               } else {
                     $self->{conn}->print($port);
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence POST_9_0 falg is set so i will take care Transport Selection");
                     ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Transport Selection\:/',
                                                                  -errmode => "return",
                                                                  -timeout => $self->{DEFAULTTIMEOUT}) or do {
                     $logger->error(__PACKAGE__ . ".sipemgmtSequence  PROBLEM ENTERING Port Number ");
                     $self->{conn}->cmd("\cC");
	             $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        	     $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
                     return 0;
                     };
                     push ( @results , $prematch );
                     push ( @results , $match );
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence passing $blacklistIpPorts{$key}{$port} for Transport Selection");
                     my $transport = ( $blacklistIpPorts{$key}{$port} =~ /UDP/i) ? 2 : 1;
                     push ( @results , $transport);
                     @cmdResults = $self->{conn}->cmd($transport);
                     push ( @results , @cmdResults );
                     $logger->info(__PACKAGE__ . ".sipemgmtSequence BlackListed Server : IP $key with Port $port transport $blacklistIpPorts{$key}{$port} Recovered ");
               }
               $logger->info(__PACKAGE__ . ".sipemgmtSequence BlackListed Server : IP $key with Port $port Recovered ");
            }
        }
        unless ( $blackListFlag ) {
             $logger->info(__PACKAGE__ . ".sipemgmtSequence NO Blacklisted Servers Found !!!! ");
        }
    } else {
        foreach(@cmds){
            if ($_ =~ /^\d+$/) {
                $logger->info(__PACKAGE__ . ".sipemgmtSequence  SENDING SEQUENCE ITEM: [$_]");
                @cmdResults = $self->{conn}->cmd($_);
                push ( @results , @cmdResults );
            }
            else {
                $logger->warn(__PACKAGE__ . ".sipemgmtSequence  LOGGING LEVEL [$_] IS NOT AN INTEGER - SKIPPING");
            }
        }
    } 

    $logger->debug(__PACKAGE__ . ".sipemgmtSequence  SENDING q TO BREAK OUT OF SIPEMGMT");
    $self->{conn}->print("q");
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                                 -match => $prevPrompt,
                                                 -errmode => "return",
                                                 -timeout => 5) or do {
            $logger->debug(__PACKAGE__ . ".sipemgmtSequence  PRE-MATCH:" . $prematch);
            $logger->debug(__PACKAGE__ . ".sipemgmtSequence  MATCH: " . $match);
            $logger->debug(__PACKAGE__ . ".sipemgmtSequence LAST LINE:" . $self->{conn}->lastline);
    };

    # In case inside another menu . Come out of it by printing q
    if ( $match =~ /Enter Selection/ ) {
        $logger->debug(__PACKAGE__ . ".sipeSequence  SENDING 0 AGAIN TO BREAK OUT OF SIPEMGMT MAIN MENU");
        $self->{conn}->print("q");
    }

    # Set the previous prompt back
    $self->{conn}->prompt($prevPrompt);

    $self->{conn}->print("date");
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prevPrompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
        $logger->debug(__PACKAGE__ . ".sipemgmtSequence  PRE-MATCH:" . $prematch);
        $logger->debug(__PACKAGE__ . ".sipemgmtSequence  MATCH: " . $match);
        $logger->error(__PACKAGE__ . ".scpamgmtSequence  PROBLEM SETTING THE PROMPT TO $prevPrompt ");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
        return 0;
    };

    $logger->debug(__PACKAGE__ . ": SUCCESS : The SIPE MGMT stats were found. Returning the stats in an array .");
    $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [1]");
    return @results;
}


=head1 ssmgmtStats () 

DESCRIPTION:

 This subroutine will get the ssmgmt stats for the user passed numbers from the menu and return the results of those
 in an array.
 
 The menu is :
  ===============================================================
                Sonus BRX Management Menu
        ===============================================================
        4.       Get Counters
        5.       Reset counters
        6.       Get LNP Counters
        7.       Reset LNP Counters
        8.       Get Toll free Counters
        9.       Reset Toll free Counters
        14.      Logging Management Menu
        19.      Cache Dump Menu
        22.      Get DNS-ENUM Statistics
        23.      Clear DNS-ENUM Statistics
        28.      Get Socket Counters
        29.      Reset Socket Counters
        30.      Get Pes Failure Counters
        31.      Reset Pes Failure Counters
        0.       Exit
        Enter Selection: 0



ARGUMENTS:

 Mandatory :
 
  -sequence     =>  ["11" , "2" , "5" ] . here you pass the numbers that you want to
                                          see the output for.
  
PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( @result = $brxObj->ssmgmtStats( -sequence => ["11" ] ,
                                          )) {
        $logger->debug(__PACKAGE__ . ": Could not get the ssmgmt Statistics ");
        return 0;
        }

AUTHOR:
Wasim Mohd. ==> wmohammed@sonusnet.com

=cut

sub ssmgmtStats {
    my ($self, %args )=@_;
    my %a;
    
    my $sub = "sipemgmtStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "ssmgmtStats" );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  
    my (@cmdResults, $cmd, @cmds, $prematch, $match, $prevPrompt , @results );
    $prevPrompt = $self->{conn}->prompt;
  
    @cmds = @{$a{-sequence}};
    $self->{conn}->print($self->{SSMGMT});
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
    $logger->warn(__PACKAGE__ . ".ssmgmtSequence  UNABLE TO ENTER SIPEMGMT MENU SYSTEM");
    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
    return 0;
    };
    $prevPrompt = $self->{conn}->prompt;
    $self->{conn}->prompt('/Enter Selection\:/');
    
    foreach(@cmds){
        if ($_ =~ /^\d+$/) {
            $logger->debug(__PACKAGE__ . ".ssmgmtSequence  SENDING SEQUENCE ITEM: [$_]");
            @cmdResults = $self->{conn}->cmd($_);
            push ( @results , @cmdResults );
        }
        else {
            $logger->warn(__PACKAGE__ . ".ssSequence  LOGGING LEVEL [$_] IS NOT AN INTEGER - SKIPPING");
        }    
    }
    
    $logger->debug(__PACKAGE__ . ".ssmgmtSequence PROMPT: " . $self->{conn}->prompt );
    
    $logger->debug(__PACKAGE__ . ".ssSequence  SENDING 0 TO BREAK OUT OF SSMGMT");
    $self->{conn}->print("0");
    ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                                 -match => $prevPrompt,
                                                 -errmode => "return",
                                                 -timeout => 5) or do {
            $logger->debug(__PACKAGE__ . ".ssmgmtSequence  PRE-MATCH:" . $prematch);
            $logger->debug(__PACKAGE__ . ".ssmgmtSequence  MATCH: " . $match);
            $logger->debug(__PACKAGE__ . ".ssmgmtSequence LAST LINE:" . $self->{conn}->lastline);
    };
    
     # In case inside another menu . Come out of it by printing 0
    if ( $match =~ /Enter Selection/ ) {
        $logger->debug(__PACKAGE__ . ".ssSequence  SENDING 0 AGAIN TO BREAK OUT OF SSMGMT MAIN MENU");
        $self->{conn}->print("0");
    }
  
    # Set the previous prompt back
    $self->{conn}->prompt($prevPrompt);

    $self->{conn}->print("date");
    ($prematch, $match) = $self->{conn}->waitfor(-match => $prevPrompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
        $logger->debug(__PACKAGE__ . ".ssmgmtSequence  PRE-MATCH:" . $prematch);
        $logger->debug(__PACKAGE__ . ".ssmgmtSequence  MATCH: " . $match);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
    };
    
    $logger->debug(__PACKAGE__ . ": SUCCESS : The SS MGMT stats were found. Returning the stats in an array .");
    $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [1]");
    return @results;
  
}

=head1 startStopSoftSwitch () 

DESCRIPTION:
 This subroutine will start or stop the softswitch on BRX.

ARGUMENTS:
 Mandatory :
  1 or 0  - Pass 1 for start and 0 for stop.
  
PACKAGE:

GLOBAL VARIABLES USED:
 None
OUTPUT:
 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:
unless ( $brxObj->startStopSoftSwitch( 1 )) {
        $logger->debug(__PACKAGE__ . ": Could not start/stop Softswitch ");
        return 0;
        }

AUTHOR:
Wasim Mohd. ==> wmohammed@sonusnet.com

=cut

sub startStopSoftSwitch {
    my ($self, $bFlag)=@_;
    my (@cmdResults,$cmd,$logger);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startStopSoftSwitch");
    $logger->debug(__PACKAGE__ . ": --> Entered  Sub ");
    $cmd = ($bFlag) ? $self->{STARTSS} : $self->{STOPSS};  
    $logger->info(__PACKAGE__ . ".startStopSoftSwitch Sending cmd: $cmd");
    $self->{conn}->print($cmd);
    
    my ( $prematch, $match );
    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                                          -match => '/Want to Stop and Restart Softswitch /',
                                                          -errmode => "return",
                                                          -timeout => $self->{DEFAULTTIMEOUT}) ) {
        $logger->error(__PACKAGE__ . ":  Unable to get the Prompt after executing the start/stop soft switch command ");
        $logger->debug(__PACKAGE__ . ".startStopSoftSwitch: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".startStopSoftSwitch: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
        return 0;
    }
    
    if ( $match =~ /Want to Stop and Restart Softswitch/) {
        $self->{conn}->print("n");
        $logger->error(__PACKAGE__ . ":  Sonus SoftSwitch Process Manager Already Running !!!! ");
        $logger->debug(__PACKAGE__ . ".startStopSoftSwitch: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".startStopSoftSwitch: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ": SUCCESS : Start/Stop Soft Switch Successful ");
    $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [1]");
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



