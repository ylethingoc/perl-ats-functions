package SonusQA::BRX::BRXHELPER;

use SonusQA::BRX;
=head1 NAME
SonusQA::ORACLE::ORACLEHELPER - Perl module for Sonus Networks BRX (UNIX) interaction
=head1 SYNOPSIS
=head1 REQUIRES
Perl5.8.6, Log::Log4perl, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX
=head1 DESCRIPTION

This is a place to implement frequent activity functionality, standard non-breaking routines.
Items placed in this library are inherited by all versions of BRX - they must be generic.

=head2 METHODS
=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use File::Basename;
our $VERSION = "1.0";
use Switch;

use vars qw($self);

# Documentation format (Less comment markers '#'):

#=head3 $obj-><FUNCTION>({'<key>' => '<value>', ...});
#Example: 
#
#$obj-><FUNCTION>({...});
#
#Mandatory Key Value Pairs:
#        'KEY' => '<TYPE>'
#
#Optional Key Value Pairs:
#       none
#=cut
## ROUTINE:<FUNCTION>


# ******************* INSERT BELOW THIS LINE:

=head1 findPatternInLog () 

DESCRIPTION:

 This subroutine searches for user passed pattern in the specified log and returns success (1) on finding it and failure (1) otherwise.
 The log path is /home/brxuser/BRX/BIN.

ARGUMENTS:

 Mandatory :
 
  -process       =>  The log process. For example : "pes", "scpa" , "pipe" etc.
  -pattern       =>  Pattern to be searched for in the log.
  
PACKAGE:
 SonusQA::BRX

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->findPatternInLog( -process => "pes" ,
                                    -pattern => 'SsIdleTimerHandler' , )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not find the required pattern in the log ");
        return 0;
        }

AUTHOR:
Wasim Mohd
wmohammed@sonusnet.com

=cut

sub findPatternInLog {
    my ($self, %args) = @_;
    my %a;
    
    my $sub = "findPatternInLog()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    # Check Mandatory Parameters
    foreach ( qw / process pattern / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    
    my $logPath = $self->{PATHBIN};
    my $logName = $a{-process} . "." . "log";
    
    # check for the presence of the process.log
    $self->execCmd("test -e $logPath/$logName");
    my @cmdResult = $self->execCmd("echo \$?");
    
    if ( $cmdResult[0] != 0 ) {
        $logger->error(__PACKAGE__ . ".$sub:  The log file $logName is not present in the path $logPath of BRX ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;    
    }
    
    # grep for the specified pattern in the log file.
    unless ( $self->execCmd("grep -i '$a{-pattern}' $logPath/$logName -m 1" , 5 ) ) {
        # Probably grep has hanged. So execute control+c.
        $self->{conn}->print("\cC");
        $logger->error(__PACKAGE__ . ".$sub:  The pattern \"$a{-pattern}\" was not found in the log file $logName ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0; 
    }
    @cmdResult = $self->execCmd("echo \$?");
    
    if ( $cmdResult[0] != 0 ) {
        $logger->error(__PACKAGE__ . ".$sub:  The pattern \"$a{-pattern}\" is not present in the log file $logName ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;    
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: The pattern \"$a{-pattern}\" was found in the log file $logName");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
    
}

=head1 startLogs () 

DESCRIPTION:

 This subroutine will empty the required logs and hence restart the logging.

ARGUMENTS:

 Mandatory :
 
  -logs       =>  ["pes" , "pipe" , "scpa" ] . Pass the log names you want to restart.
  
PACKAGE:
 SonusQA::BRX

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->startLogs( -logs => ["pes" , "pipe" , "scpa" ] ,
                                          )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not start the required logs ");
        return 0;
        }

AUTHOR:
Wasim Mohd
wmohammed@sonusnet.com

=cut

sub startLogs {
    my ($self, %args) = @_;
    my %a;
    
    my $sub = "startLogs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    unless ( defined ( $args{-logs} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -logs has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  
    my @logs = @{$a{-logs}};
    my $logPath = $self->{PATHBIN};
    
    foreach ( @logs ) {
        my $logName = $_ . "." . "log";
        
        # check for the presence of the process.log
        $self->execCmd("test -e $logPath/$logName");
        my @cmdResult = $self->execCmd("echo \$?");
    
        if ( $cmdResult[0] != 0 ) {
            $logger->error(__PACKAGE__ . ".$sub:  The log file $logName is not present in the path $logPath of BRX ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;    
        }
        
        #restart the log by removing the log from the path.
        $self->execCmd("cat /dev/null > $logPath/$logName");
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: All the logs specified were started successfully ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}


=head1 getLogs () 

DESCRIPTION:

 This subroutine will copy the specified logs to <path> specified by the user . 

ARGUMENTS:

 Mandatory :
 
  -logs       =>  ["pes" , "pipe" , "scpa" ] . Pass the log names you want to restart.
  -feature    =>  specify the feature name. A directory will be created inside ~/ats_user/logs with the feature name
                  and a timestamp.
  -testcase   =>  specify the testcase id. A directory with the testcase id will be created inside the feature dir.
  
PACKAGE:
 SonusQA::BRX

GLOBAL VARIABLES USED:
 None

OUTPUT:
  Local Log Path   - Success
           0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $logpath = $brxObj->getLogs( -logs    => ["pes" , "pipe" , "scpa" ] ,
                           -feature => "BRXTEMPLATE",
                           -testcase => "tms11111" ,)) {
        $logger->debug(__PACKAGE__ . ": Could not copy the required logs ");
        return 0;
        }

AUTHOR:
Wasim Mohd
wmohammed@sonusnet.com

=cut

sub getLogs {
    my ($self, %args) = @_;
    my %a;
    
    my $sub = "getLogs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    unless ( defined ( $args{-logs} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -logs has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
  
    unless ( defined ( $args{-feature} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -feature has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless ( defined ( $args{-testcase} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -testcase has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my @logs = @{$a{-logs}};
    my $logPath = $self->{PATHBIN};
    my $featDir = "$ENV{ HOME }/ats_user/logs";
    my $timestamp = strftime "%Y%m%d%H%M%S", localtime;
    # create Feature Directory.
    unless ( system ( "mkdir -p $featDir/${a{-feature}}_${timestamp} " ) == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub *** Could not create log directory for Feature $a{-feature} in $featDir ***");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    $featDir = "$featDir/${a{-feature}}_${timestamp}";
    # create testcase Directory.
    unless ( system ( "mkdir -p $featDir/$a{-testcase} " ) == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub *** Could not create log directory for testcase $a{-testcase} in $featDir ***");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $localLogPath = "$featDir/$a{-testcase}" ;
    
    my $scpError = 0;
    # error handler for scp
    my $errorHandler = sub {
     $logger->error(__PACKAGE__ . ".$sub:  @_ ");
     $logger->error(__PACKAGE__ . ".$sub:  ERROR problems with the call :'scp()' ");
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
     $scpError = 1;
     return 0;
    };


    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
   
    foreach ( @logs ) {
        my $logName = $_ . "." . "log";
        
        # check for the presence of the process.log
        $self->execCmd("test -e $logPath/$logName");
        my @cmdResult = $self->execCmd("echo \$?");
        
        if ( $cmdResult[0] != 0 ) {
            $logger->error(__PACKAGE__ . ".$sub:  The log file $logName is not present in the path $logPath of BRX ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;    
        }
        
        # check for the presence of the destination path directory passed by the user
        unless ( -d $localLogPath ) {
            $logger->error(__PACKAGE__ . ".$sub:  The log path $localLogPath is not present in the local machine ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

	$scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$logPath/$logName";
	$scpArgs{-destinationFilePath} = "$localLogPath";

	if (&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->debug(__PACKAGE__ . ".$sub:  The log file $logName Copied from BRX to $localLogPath ");
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: All the logs specified were copied successfully to $localLogPath");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [Local Log Path]");
    return $localLogPath;
}

=head1 getIntervalBetweenMsgs () 

DESCRIPTION:

 This subroutine will find the Difference in time between the first two messages specified, from the desired log and
 return the time difference.

ARGUMENTS:

 Mandatory :
 
  -logWithPath       =>  Path of the log where the check has to be done. Generally, you run the getLogs() and
                         from the return path of getLogs() you append the file name reqd and pass it. Like $returnFromgetLogs/sipe.log
  -msg1               =>  specify the 1st message whose occurances is to be searched for. Ex: "INVITE" or "ACK" or "SIP\2.0", etc.
  -msg2               =>  specify the 2nd message whose occurances is to be searched for. Ex: "INVITE" or "ACK" or "SIP\2.0", etc.
  -Recv              =>  0 or 1. If the message to be searched for is "Recv From" , then set this. Else, 0, which means "Send To:".
  -msg1IntNo          =>  The 1st msg occurence number. Ex: if 1st INVITE is your first msg then pass 1 , else if 3rd INVITE then pass 3.
  -msg2IntNo          =>  The 2nd msg occurence number. Ex: if 2nd INVITE is your second msg and first msg is also an INVITE then pass 2 ,
                           else if 1st INVITE after msg1( not an INVITE ) is your second msg then pass 1.
  
PACKAGE:
 SonusQA::BRX

GLOBAL VARIABLES USED:
 None

OUTPUT:
  Time Diff Between the messages In seconds - Success
           0                                - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $logpath = $brxObj->getLogs( -logs    => ["pes" , "pipe" , "scpa" ] ,
                           -feature => "BRXTEMPLATE",
                           -testcase => "tms11111" ,)) {
        $logger->debug(__PACKAGE__ . ": Could not copy the required logs ");
        return 0;
        }

unless ( $timediff = $brxObj->getIntervalBetweenMsgs( -logWithPath   =>  "$logpath/sipe.log",
                           -msg1 => "INVITE",
                           -msg2 => "INVITE",
                           -Recv => 1,
                           -msg1IntNo => 1,
                           -msg2IntNo => 2, )) {
        $logger->debug(__PACKAGE__ . ": Could not get the time Difference ");
        return 0;
        }

AUTHOR:
Wasim Mohd
wmohammed@sonusnet.com

=cut

sub getIntervalBetweenMsgs {
    my ($self, %args) = @_;
    my ( $msg );
    
    my $sub = "getIntervalBetweenMsgs()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    #while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %args);
    
    # Check Mandatory Parameters
    foreach ( qw / logWithPath msg1 msg2 msg1IntNo msg2IntNo / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    
    unless ( $args{-Recv} ) {
        $msg = "Send To:";
    } else {
        $msg = "Recv From:";
    }
    
    unless ( -e $args{-logWithPath} ) {
        $logger->error(__PACKAGE__ . ".$sub:  The log passed $args{-logWithPath} does not exist ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    open  FH , "<$args{-logWithPath}" or die $!;
    my @logFile = <FH>;
    close FH;
    
    my ( $lastline , $msec1 , $msec2 , $sec1 , $sec2 , $min1 , $min2 , $hr1 , $hr2 , $diff_found , $msgCount , $firstMsgFound );
    $lastline = "";
    $msgCount = 0;
    $firstMsgFound =0;
    foreach ( @logFile ) {
      unless ( $firstMsgFound ) {
        if ( $_ =~ /^\Q$args{-msg1}\E/ ) {
            if ( $lastline =~ /$msg\s+.*\s+timestamp\s+\[\s*(\d+):(\d+):(\d+)\.(\d+)]/ ) {
                ++$msgCount;
                if ( $msgCount == $args{-msg1IntNo} ) {
                    $msec1 = $4;
                    $sec1 = $3;
                    $min1 = $2;
                    $hr1 = $1;
                    $firstMsgFound =1;
                    $msgCount = 0 if ( $args{-msg1} ne $args{-msg2} );
                    $logger->info(__PACKAGE__ . ".$sub: Matched first message-> mgscount: $msgCount");
                }
            }
        }
      } else {
        if ( $_ =~ /^\Q$args{-msg2}\E/ ) {
            if ( $lastline =~ /$msg\s+.*\s+timestamp\s+\[\s*(\d+):(\d+):(\d+)\.(\d+)]/ ) {
                ++$msgCount;
                if ( $msgCount == $args{-msg2IntNo} ) {
                    $msec2 = $4;
                    $sec2 = $3;
                    $min2 = $2;
                    $hr2 = $1;
                    $diff_found = 1;
                    $logger->info(__PACKAGE__ . ".$sub: Matched second message-> mgscount: $msgCount");
                    last;
                }
            }
        }
      }
        $lastline = $_;
    }
 
    unless ( $diff_found ) {
        $logger->error(__PACKAGE__ . ".$sub:  Two messages $args{-msg1} and $args{-msg2} were not found in your Log $args{-logWithPath} ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    # find the difference in time in seconds
    my $secsdiff = 0;
    if ( $hr2 == $hr1 ) {
        if ( $min2 == $min1 ) {
            $secsdiff += ( $sec2 - $sec1 );
        } else {
            if ( ($min2 - $min1) == 1 ) {
                $secsdiff += ( $sec2 + ( 60 - $sec1));
            } else {
                $secsdiff +=  ( ( $sec2 + ( 60 - $sec1)) + ( ( $min2 - $min1 - 1 ) * 60 ) ) ;
            }
        }
    } else {
        my $minsdiff = 0;
        if ( ($hr2 - $hr1) > 1 ) {
            $minsdiff += ( ( $min2 + ( 60 - $min1)) + ( ( $hr2 - $hr1 - 1 ) * 60 ) ) ;
            $secsdiff += ( $minsdiff * 60 );
        } else {
            $minsdiff += ( $min2 + ( 60 - $min1));
            $secsdiff += ( $minsdiff * 60 );
        }
        $secsdiff -= $sec1; 
        $secsdiff += $sec2;
    }
    
    # Find the micro seconds difference
    my ( $cnt , @cnt , $mdiff );
    if ( $msec2 > $msec1 ) {
        $mdiff = ( $msec2 - $msec1 );
    }
    else {
        $mdiff = ( $msec1 - $msec2 );
    }
    
    # setting the correct resolution for micro seconds difference 
    @cnt = split("", $mdiff);
    $cnt = ++$#cnt;
    switch ( $cnt ) {
        case 6  { $secsdiff .= ".$mdiff"; }
        case 5  { $secsdiff .= ".0$mdiff"; }
        case 4  { $secsdiff .= ".00$mdiff"; }
        case 3  { $secsdiff .= ".000$mdiff"; }
        case 2  { $secsdiff .= ".0000$mdiff"; }
        case 1  { $secsdiff .= ".00000$mdiff"; }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub:  Time Difference found between two messages, i.e, $args{-msg1IntNo} $args{-msg1} and $args{-msg2IntNo} $args{-msg2}, in seconds : $secsdiff secs");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [Time Diff In Secs]");
    return $secsdiff;
}

=head1 slwresdmgmt () 

DESCRIPTION:

 This subroutine will run the slwresdmgmt and performs the operation depend on argument passed.
 
 The menu is :
   ===================================================
                LWRESD Management Menu
        ===================================================
        1.       Logging Management Menu
        2.       Set DNS Server Unavailable
        3.       Set DNS Server Available
        4.       Get LWRESD Statistics
        5.       Reset LWRESD Statistics
        6.       Get DNS Server Status
        7.       Get All DNS Server Status
        8.       Get All TTL expired DNS records
        9.       Get EDNS Failure Count
        0.       Exit
        Enter Selection: 0



ARGUMENTS:

 Mandatory :
 
  -sequence     =>  ["3" , "2" , "5" ] . Selections as an array referance.
  -ipaddress    => ["XX.XX.XX.XX","fd00:10:6b50:44e0::f"] This will be manditory argument when the sequence has any of 2,3,6,9 and the order of -sequence and -ipaddress should match
  
OUTPUT:
 Array	 - Content of DNSRecordStatus.txt incase of -sequence have 8 else Console output.
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( @result = $brxObj->slwresdmgmt( -sequence => [1, 0, 6, 4], -ipaddress => ['fd00:10:6b50:44e0::f'] )) {
        $logger->debug(__PACKAGE__ . ": Could not get the ssmgmt Statistics ");
        return 0;
}

AUTHOR:
rpateel@sonusnet.com

=cut

sub slwresdmgmt {
    my ($self, %args )=@_;
    my %a;
    
    my $sub = "slwresdmgmt()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "slwresdmgmt" );
    
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);
    
    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
 
    my (@results, $prematch, $match, $failed); 
    my @options = @{$a{-sequence}};
    my @ipaddress ;
    @ipaddress = @{$a{-ipaddress}} if ($a{-ipaddress});

    if (grep(/^(2|3|6|9)$/, @options) and !@ipaddress) {
        $logger->error(__PACKAGE__ . ".$sub:  Ipaddress required for this operation not been specified or is blank.");	
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;		
    }
	
    $self->{conn}->cmd("cd $self->{PATHBIN}");
    $self->{conn}->print($self->{SLWREDMGMT});

    if ($#options == 0 and $options[0] =~ /^(2|3|6|9)$/) {
       push (@options, 0);
    }
	
    my $count = 0;
    foreach(@options){	
        if ($_ =~ /^\d+$/) {
            if($_ == 0 and $_ == $options[$#options]) {
                $logger->debug(__PACKAGE__ . ".$sub  SENDING IP Address $ipaddress[$count]");
            } else {
                $logger->debug(__PACKAGE__ . ".$sub  SENDING SEQUENCE ITEM: [$_]");
            }
        } else {
            $logger->warn(__PACKAGE__ . ".$sub  LOGGING LEVEL [$_] IS NOT AN INTEGER - SKIPPING");
            next;
        }
		
        unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\: $/',
                                                             -match => '/Enter IP Address of the DNS Server \: $/',
                                                             -errmode => "return",
                                                             -timeout => $self->{DEFAULTTIMEOUT})) {
            $logger->warn(__PACKAGE__ . ".$sub failed to match the prompt");
            $failed = 1;
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        }

        last if ($failed);

        if ($match =~ /Enter Selection\: $/) {
            $self->{conn}->print($_);
        } elsif ($match =~ /Enter IP Address of the DNS Server \: $/) {
            $logger->debug(__PACKAGE__ . ".$sub: sending ip $ipaddress[$count]");
            $self->{conn}->print($ipaddress[$count]);
            $count++;
            unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\: $/',
                                                                 -errmode => "return",
                                                                 -timeout => $self->{DEFAULTTIMEOUT})) {
                $logger->warn(__PACKAGE__ . ".$sub failed to match the prompt");
                $failed = 1;
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            }
            $self->{conn}->print($_) if(!$failed and $_ > 0);
        }
        
        last if ($failed);
        my @output = split('\n', $prematch);
        push ( @results, @output, $match );           
    }
    
    $self->{conn}->print("0");
    unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                                         -match => $self->{PROMPT},
                                                         -errmode => "return",
                                                         -timeout => 5)) {
        $logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
        $logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
        $logger->debug(__PACKAGE__ . ".$sub LAST LINE:" . $self->{conn}->lastline);
    }
  
    if ( $match =~ /Enter Selection/ ) {
        $logger->debug(__PACKAGE__ . ".ssSequence  SENDING 0 AGAIN TO BREAK OUT OF SSMGMT MAIN MENU");
        $self->{conn}->print("0");
        unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT}, -errmode => "return")) {
            $logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
            $logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
            $logger->debug(__PACKAGE__ . ".$sub  failed");
            $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub  Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
    }

    my @output = split('\n', $prematch);
    push ( @results, @output );

    if ($failed) {
       $logger->error(__PACKAGE__ . ".$sub  failed to complete the operation");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }

    @results = $self->{conn}->cmd("cat DNSRecordStatus.txt") if (grep(/^8$/, @options));

    $logger->debug(__PACKAGE__ . ": SUCCESS : Returning the stats in an array .");
    $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [1]");
	
    chomp (@results);
    return @results;
}


=head1 handleDnsService() 

DESCRIPTION:

 This subroutine will stop/start the DNS service and also run the script on DNS.
 
ARGUMENTS:

 Mandatory :
 
  -dnsip        =>  ip address of DNS.
  -operation    =>  star or stop
                            - start - to start the DNS service
                            - stop  - to stop the DNS service
 Optional :
  
  -script       => Script to be run on DNS once the DNS service is stoped
                   Example - "perl server1.pl Normal_resp.pdu"
  -kill         => 1 to stop the Script (started after DNS service stop) before starting DNS service.
   
  
OUTPUT:
 1       - Success.
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

To stop the DNS service :

 unless ( @result = $brxObj->handleDnsService( -dnsip => '10.54.19.186',
                                              -operation => 'stop',
                                              -script => 'perl server1.pl Normal_resp.pdu')) {
        $logger->debug(__PACKAGE__ . ": Unable to stop the DNS service ");
        return 0;
 }

To start the DNS service :
 unless ( @result = $brxObj->handleDnsService( -dnsip => '10.54.19.186',
                                               -operation => 'start',
                                               -kill => 1)) {
        $logger->debug(__PACKAGE__ . ": Unable to start the DNS service ");
        return 0;
 }

AUTHOR:
rpateel@sonusnet.com

=cut

sub handleDnsService {
    my ($self, %args) = @_;

    my $sub = "handleDnsService()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub $sub");

    my %a   = ( -username      => 'root',
                -password  => 'sonus1' );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);

    unless (defined ($a{-dnsip})) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory argument -dnsip is empty or undefined");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }

    unless (defined ($a{-operation})) {
       $logger->error(__PACKAGE__ . ".$sub: Mandatory argument -operation is empty or undefined");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }

    if (!defined ($self->{dnsObj})) {
        $self->{dnsObj} = SonusQA::DSI->new(
                                           -OBJ_HOST     => $a{-dnsip},
                                           -OBJ_USER     => $a{-username},
                                           -OBJ_PASSWORD => $a{-password},
                                           -OBJ_COMMTYPE => "SSH",
                                           -sessionlog   => 1);
    }

    unless ( $self->{dnsObj} ) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not open connection to DNS server");
        $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to required DNS \($a{-dnsip}\)");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    if ($a{-operation} =~ /stop/i) {

        unless ($self->{dnsObj}->{conn}->cmd("service named stop")) {
            $logger->error(__PACKAGE__ . ".$sub: unable to stop the DNS service");
    	    $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{dnsObj}->{conn}->errmsg);
	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{dnsObj}->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{dnsObj}->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
        
        if ($a{-script}) {
            $logger->debug(__PACKAGE__ . ".$sub: running $a{-script} on DNS");
            $self->{dnsObj}->{conn}->print($a{-script});
        }

    } elsif ($a{-operation} =~ /start/i) {
        
        if ($a{-kill}) {
            $logger->debug(__PACKAGE__ . ".$sub: going to kill the script");
            $self->{dnsObj}->{conn}->cmd("\cC");
        }
       
        unless ($self->{dnsObj}->{conn}->cmd("service named start")) {
            $logger->error(__PACKAGE__ . ".$sub: unable to start the DNS service");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{dnsObj}->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{dnsObj}->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{dnsObj}->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        $self->{dnsObj}->{conn}->close;
        $self->{dnsObj} = undef; 

    } 

    return 1;
}

=head2 C< configureDSCP >

DESCRIPTION:

 This subroutine will get the DSCP utilities for the user passed numbers from the menu and return the results of those
 in an array. 
 
 Note:
 Donot use this API directly . configureDscpMarking() should be called which internally calls this API.
 
 The menu is :

############################################################################  
                       DSCP Configuration
############################################################################

                1. Enable DSCP Marking
                2. Disable DSCP Marking
                3. Modify DSCP Marking
                4. Show DSCP Marking
                5. Save and Exit

                Please Enter the option (1-5) : 
                        
                        
ARGUMENTS:

Mandatory :
 
  -sequence     =>  ["11" , "2" , "m" ] . here you pass the values that you want to
                                          see the output for.
  
PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:


unless ( @result = $brxObj->configureDSCP( -sequence => [1, 'm', 'y', 'y'] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }
        
AUTHOR:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut	

sub configureDSCP {

    my ($self, %args )=@_;
    my %a;

    my $sub = "configureDSCP()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "configureDSCP()" );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);

    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	
    unless ($self->enterRootSessionViaSU() ) {
	$logger->debug(__PACKAGE__ . ".$sub: Failed entering root session");
	return 0;
    }

    my (@cmdResults, $cmd, @cmds, $prematch, $match, $prevPrompt , $enterSelPrompt , @results );
    
    @cmds = @{$a{-sequence}};
    $self->{DSCPprompt} = 'Please Enter the option (1-5) :';
	
    my $DSCP_Cmd = "$self->{PATHBIN}" . '/' . "configureDSCP\.sh";  
	
    $logger->info(__PACKAGE__ . ".$sub: Executing DSCP command : $DSCP_Cmd");
	
    $self->{conn}->print($DSCP_Cmd);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
    	                                                -errmode => "return",
               	                                        -timeout => $self->{DEFAULTTIMEOUT}) ) { 
        $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO ENTER DSCP CONFIGURATION MENU SYSTEM");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }
		
    if ($cmds[0] =~ /1/i) {
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the First option: Enable DSCP Marking");
        $self->{conn}->print($cmds[0]);
		
        unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please provide the interface type to proceed \(m\/M for management\, s\/S for signaling\) \:/',
                       			                    -errmode => "return",
 			                                    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE OPTION: Enable DSCP Marking");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
		
        $self->{conn}->print($cmds[1]);
		
        if ( $cmds[1] =~ /[mM]/i ) {

            $logger->debug(__PACKAGE__ . ".$sub: Selecting the Interface Type as Management");
	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
	                       					-errmode => "return",
	               						-timeout => $self->{DEFAULTTIMEOUT}) ) { 
	       	$logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE INTERFACE TYPE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	       	return 0;
            }
			
	    $self->{conn}->print($cmds[2]);
			
	    if ($cmds[2] =~ /[yY]/i) {
	        $logger->debug(__PACKAGE__ . ".$sub: overwriting DSCP marking for Management interface");
	 	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
 			                                              -match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
				                                    -errmode => "return",
		                                   		    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
                    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO OVERWRITE THE DSCP MARKING FOR MANAGEMENT INTERFACE");
        	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
		    return 0;
                }
		
	        $logger->debug(__PACKAGE__ . ".$sub: Entering value");
		$self->{conn}->print($cmds[3]);
	        if ($cmds[3] =~ m/n/i) {
		    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
		                                       		        -errmode => "return",
					                      	        -timeout => $self->{DEFAULTTIMEOUT}) ) { 
              	        $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO OVERWRITE THE DSCP MARKING FOR MANAGEMENT INTERFACE");
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        	$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
			return 0;
                    }
		    $logger->debug(__PACKAGE__ . ".$sub: Entering value");
                    $self->{conn}->print($cmds[4]);
                    return 1;
		}
	    }  
	} elsif ( $cmds[1] =~ /[sS]/i ) {

            $logger->debug(__PACKAGE__ . ".$sub: Selecting the Interface Type as Signaling");
	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
	 	                                		-errmode => "return",
	                                  			-timeout => $self->{DEFAULTTIMEOUT}) ) { 
	       	$logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE INTERFACE TYPE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	      	return 0;
            }
			
	    $self->{conn}->print($cmds[2]);
			
	    if ($cmds[2] =~ /[yY]/i) {
	        $logger->debug(__PACKAGE__ . ".$sub: overwriting DSCP marking for Signaling interface");
	       	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
  	                       					      -match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
	                               				    -errmode => "return",
	                              				    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
  	            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO OVERWRITE THE DSCP MARKING FOR Signaling INTERFACE");
        	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	            return 0;
                }
				
	        $logger->debug(__PACKAGE__ . ".$sub: Entering value");
	        $self->{conn}->print($cmds[3]);
	       	if ($cmds[3] =~ m/n/i) {
	            unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
	                               					-errmode => "return",
	                               					-timeout => $self->{DEFAULTTIMEOUT}) ) { 
	            	$logger->warn(__PACKAGE__ . ".$sub: UNABLE TO OVERWRITE THE DSCP MARKING FOR SIGNALING INTERFACE");
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        	$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	            	return 0;
                    }
		    $logger->debug(__PACKAGE__ . ".$sub: Entering value");	
		    $self->{conn}->print($cmds[4]);	
		    return 1;
	        }
	    } 
	} else {
	    $logger->debug(__PACKAGE__ . ".$sub: Interface selected is not a valid one!");
	    return 0;		
	}	
		
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
	                            			    -errmode => "return",
	                             			    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
 	    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MATCH THE SELECTION PROMPT");
	    $logger->debug(__PACKAGE__ . ".$sub: Enabling DSCP Marking failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	    return 0;
        }
			
        if ($match =~ m/$self->{DSCPprompt}/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Successfully Enabled the DSCP Marking for Management/Signaling Interface");
	    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
	    return 1;
	}
    } elsif ($cmds[0] =~ /2/i) {
	$logger->debug(__PACKAGE__ . ".$sub: Selecting the Option: Disable the DSCP Marking");
	$self->{conn}->print($cmds[0]);
		
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please provide the interface type to proceed \(m\/M for management\, s\/S for signaling\) \:/',
	               					    -errmode => "return",
		                                            -timeout => $self->{DEFAULTTIMEOUT}) ) { 
            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE OPTION: Enable DSCP Marking");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
		
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the Interface");
	$self->{conn}->print($cmds[1]);

	if ($cmds[1] =~ /[mM]/i) {
            $logger->debug(__PACKAGE__ . ".$sub: Selected the Interface Type as Management");
	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
				                                -errmode => "return",
		                                   		-timeout => $self->{DEFAULTTIMEOUT}) ) { 
	       	$logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE INTERFACE TYPE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	      	return 0;
            }
			
	    $logger->debug(__PACKAGE__ . ".$sub: Disabled the DSCP marking for Management Interface") if ($cmds[2] =~ /[yY]/i);
	    $self->{conn}->print($cmds[2]);
	} elsif ($cmds[1] =~ /[sS]/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Selected the Interface Type as Signaling");
	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(y\/Y for yes\, n\/N for no\)\? \:/',
	                      					-errmode => "return",
	                      					-timeout => $self->{DEFAULTTIMEOUT}) ) { 
	       	$logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE INTERFACE TYPE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	       	return 0;
            }
			
	    $logger->debug(__PACKAGE__ . ".$sub: Disabled the DSCP marking for Signaling Interface") if ($cmds[2] =~ /[yY]/i);
	    $self->{conn}->print($cmds[2]);
	}
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
	                       				    -errmode => "return",
	                       				    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
  	    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MATCH THE SELECTION PROMPT");
	    $logger->debug(__PACKAGE__ . ".$sub: Disabling DSCP Marking failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	    return 0;
        }
			
	if ($match =~ m/$self->{DSCPprompt}/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Successfully Diabled the DSCP Marking for Management/Signaling Interface");
	    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
	    return 1;
	}
		
    } elsif ($cmds[0] =~ /3/i) {
	$logger->debug(__PACKAGE__ . ".$sub: Selecting the option: Modify DSCP Marking");
	$self->{conn}->print($cmds[0]);
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please provide the interface type to proceed \(m\/M for management\, s\/S for signaling\) \:/',
	                       				    -errmode => "return",
	                       				    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE OPTION: Enable DSCP Marking");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
		
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the Interface Type");
        $self->{conn}->print($cmds[1]);
 
        if ($cmds[1] =~ /[mM]/i) {
            $logger->debug(__PACKAGE__ . ".$sub: Selected The Interface Type as Management");
      	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
	   			                            			        -errmode => "return",
				                                 				-timeout => $self->{DEFAULTTIMEOUT}) ) { 
  	        $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MODIFY THE DSCP MARKING FOR MANAGEMENT INTERFACE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	        return 0;
	    }

	    $logger->debug(__PACKAGE__ . ".$sub: Entering the New Value");
	    $self->{conn}->print($cmds[2]);
	} elsif ($cmds[1] =~ /[sS]/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Selected The Interface Type as Signaling");
	    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/\(0 \- 63\) \? \[\d+\]\:/',
 			                            	        -errmode => "return",
		                              		        -timeout => $self->{DEFAULTTIMEOUT}) ) { 
 	        $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MODIFY THE DSCP MARKING FOR SIGNALING INTERFACE");
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	        return 0;
	    }

	    $logger->debug(__PACKAGE__ . ".$sub: Entering the New Value");
	    $self->{conn}->print($cmds[2]);		
	}
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
			                               	    -errmode => "return",
		                              		    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
    	    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MATCH THE SELECTION PROMPT");
	    $logger->debug(__PACKAGE__ . ".$sub: Modifying DSCP Marking failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	    return 0;
        }
			
        $logger->info(__PACKAGE__ . ".$sub: Successfully Modified the DSCP Marking for Management/Signaling Interface");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
        return 1;

    } elsif ($cmds[0] =~ /4/i) {
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the option: Show DSCP Marking");
        $self->{conn}->print($cmds[0]);
		
        unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please provide the interface type to proceed \(m\/M for management\, s\/S for signaling\) \:/',
			                              	    -errmode => "return",
			                                    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE OPTION: Show DSCP Marking");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
		
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the Interface Type");
	$self->{conn}->print($cmds[1]);

	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
	               					    -errmode => "return",
	                          			    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
	    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MATCH THE SELECTION PROMPT");
	    $logger->debug(__PACKAGE__ . ".$sub: Modifying DSCP Marking failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
	    return 0;
        }
		
	my @output = split ("\n", $prematch);
	my $count = 1;
	my $match = 0;
	my @output1;
	foreach (@output) {
	    if ($count <= 3) {
	        if ($_ =~ /\#\#\#\#\#/i){
	            $count += 1;
	            $match = 1;
	        }
	        push @output1, $_ if ($match);
	    }
	}
	$logger->debug(__PACKAGE__ . ".$sub: @output1");

	open(DSCPfile, ">DSCPstats.txt") or die("file cannot be created for storing DSCP stats");
		 
        foreach (@output1) {
            print DSCPfile ("$_\n");
        }
		
        @output = `ls -lrt DSCPstats.txt`;

        foreach ( @output ) {
            if($_ =~ /No such file or directory/i){
                $logger->debug(__PACKAGE__ . ".$sub: File (DSCPstats.txt) not Found! ");
                return 0;
            }else{
                $logger->info(__PACKAGE__ . ".$sub: File  (DSCPstats.txt) exists! ");
		return 1;
            }
        }		
    } elsif ($cmds[0] =~ /5/i) {
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the option: Save and exit");
        $self->{conn}->print($cmds[0]);
		
	my ($prematch, $match);
        unless ( ($prematch, $match) = $self->{conn}->waitfor(   -match => '/$self->{conn}->prompt/',
                                                               -errmode => "return",
                                                               -timeout => $self->{DEFAULTTIMEOUT}) ) {
            $logger->warn(__PACKAGE__ . ".$sub: unable to exit from DSCP config");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }   
    
        $logger->info(__PACKAGE__ . ".$sub: Successfully exited from DSCP config");
        return 1;
    } else {
  	$logger->debug(__PACKAGE__ . ".$sub: Selected option is invalid!");
   	return 0;	
    }
}


=head1 configureDscpMarking () 

DESCRIPTION:

 This subroutine will get the DSCP utilities for the user passed numbers from the menu 
 
 The menu is :

############################################################################  
                       DSCP Configuration
############################################################################

		1. Enable DSCP Marking
  		2. Disable DSCP Marking
		3. Modify DSCP Marking
		4. Show DSCP Marking
		5. Save and Exit

		Please Enter the option (1-5) : 
			
ARGUMENTS:

Mandatory :
 
 sequence     =>  ["11" , "2" , "m" ] . here you pass the values that you want to
                                          see the output for.
   
PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:


unless ( @result = $brxObj->configureDscpMarking( -sequence => [1, 5] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

        
AUTHOR:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut			


sub configureDscpMarking {
    my ($self, %args )=@_;
    my %a;

    my $sub = "configureDscpMarking()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "configureDscpMarking()" );

	$logger->debug(__PACKAGE__ . ".$sub: Entered sub-");
    
    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $result = $self->configureDSCP(%args); 

    unless ( $self->SaveAndExitDSCPConfig() ) {
        $logger->debug(__PACKAGE__ . ".$sub: SaveAndExit DSCP failed");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
	return 0;
    }

    unless ( $self->leaveRootSession() ) {
	$logger->debug(__PACKAGE__ . ".$sub: Failed Leaving root session");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
	return 0;
    }    
	
    return $result if ($result);
    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[0]");
    return 0;

}

=head1 enterRootSessionViaSU () 

DESCRIPTION:

 This subroutine will enter the linux root session via Su command.
 
 
ARGUMENTS:
None

PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->enterRootSessionViaSU( )) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }
        
AUTHOR:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut			

sub enterRootSessionViaSU {
    my ($self) = @_;
    my $sub = "enterRootSessionViaSU()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "enterRootSessionViaSU()" );

    $logger->debug(__PACKAGE__ . ".$sub: Entered ");	
	
    my $cmd1 = "id";
    my $cmd2 = "su root"; 

    my (@cmdresults, @cmdresults1);
    unless ( @cmdresults = $self->execCmd($cmd1) ) {
	$logger->debug(__PACKAGE__ . ".$sub: failed to execute the command : $cmd1");
	return 0;
    }
	
    foreach (@cmdresults) {
  	$logger->debug(__PACKAGE__ . ".$sub: You are already logged in as root") and return 1 if ($_ =~ m/root/i);
    }
	
    $logger->debug(__PACKAGE__ . ".$sub: Issuing the Cli: $cmd2");
	
    my ($prematch, $match);
    $self->{conn}->print($cmd2);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(   -match => '/Password\:/',
							   -errmode => "return",
							   -timeout => $self->{DEFAULTTIMEOUT}) ) { 
        $logger->warn(__PACKAGE__ . ".$sub: Root Login Failed");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }
	
    my $rootpwd = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    if ($match =~ m/Password\:/i) {
	$self->{conn}->print($rootpwd);
    }
	
    unless ( @cmdresults1 = $self->execCmd($cmd1) ) {
  	$logger->debug(__PACKAGE__ . ".$sub: failed to execute the command : $cmd1");
 	return 0;
    }
	
    foreach (@cmdresults1) {
 	if ($_ =~ /root/i) {
    	    $logger->debug(__PACKAGE__ . ".$sub: Successfully entered root Session");
	    return 1;
	}
    }

    $logger->debug(__PACKAGE__ . ".$sub: login to root session failed!");
    return 0;
}

=head1 leaveRootSession () 

DESCRIPTION:

 This subroutine exits from the linux root session.
 
 
ARGUMENTS:
None

PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->leaveRootSession( )) {
        $logger->debug(__PACKAGE__ . " : Could not leave the root session");
        return 0;
        }
        
AUTHOR:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut		

sub leaveRootSession {
    my ($self) = @_;
    my $sub = "leaveRootSession()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "leaveRootSession()" );

    $logger->info(__PACKAGE__ . ".$sub: Entered ");   
	
    my $cmd1 = "id";
    my $cmd2 = "exit"; 

    my (@cmdresults1, @cmdresults2, @cmdresults3);
    unless ( @cmdresults1 = $self->execCmd($cmd1) ) {
 	$logger->info(__PACKAGE__ . ".$sub: failed to execute the command : $cmd1");
	return 0;
    }

    foreach (@cmdresults1) {
	if ($_ =~ /root/i) {
    	    unless ($self->execCmd($cmd2) ) {
		$logger->info(__PACKAGE__ . ".$sub: failed to execute the command : $cmd2");
	        return 0;
	    }
	}
    }

    unless ( @cmdresults2 = $self->execCmd($cmd1) ) {
	$logger->info(__PACKAGE__ . ".$sub: failed to execute the command : $cmd1");
	return 0;
    }
	
    foreach (@cmdresults2) {
 	unless ($_ =~ m/root/i) {
	    $logger->info(__PACKAGE__ . ".$sub: Successfully exited from root session");
	    return 1;
	}
    }
 	
    $logger->info(__PACKAGE__ . ".$sub: Failed!");
    return 1;
}


=head1 SaveAndExitDSCPConfig () 

DESCRIPTION:

 This subroutine exits from the DSCP config.
 Note:
 1. Saves and exits by Issuing option 5 from the DSCP config menu, if it matches for the selection prompt.
 2. If Selection prompt is not matched, then exits by issuing control C.
 
 
ARGUMENTS:
None

PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->SaveAndExitDSCPConfig( )) {
        $logger->debug(__PACKAGE__ . " : Could not exit the DSCP config");
        return 0;
        }
        
AUTHOR:
Ashok Kumarasamy (akumarasamy@sonusnet.com)

=cut		


sub SaveAndExitDSCPConfig {
    my($self) = @_;
    my $sub = "SaveAndExitDSCPConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "SaveAndExitDSCPConfig()" );
    
    $logger->info(__PACKAGE__ . ".$sub: Entered ");

    
    $self->{conn}->print(5);

    print "prompt ----> $self->{PROMPT}\n";
    my ($prematch, $match);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(   -match => $self->{PROMPT},
                                                           -errmode => "return",
                                                           -timeout => $self->{DEFAULTTIMEOUT}) ) {

        $logger->info(__PACKAGE__ . ".$sub: Exiting the DSCP config without saving");
        $self->{conn}->print("\cC");
        unless ( ($prematch, $match) = $self->{conn}->waitfor(   -match => $self->{PROMPT},
                                                               -errmode => "return",
                                                               -timeout => $self->{DEFAULTTIMEOUT}) ) {

            $logger->warn(__PACKAGE__ . ".$sub: unable to exit the DSCP config without saving");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
    } 
    
    $logger->info(__PACKAGE__ . ".$sub: Successfully exited from DSCP config");
    return 1;
    	
}

1; # Do not remove




