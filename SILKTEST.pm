package SonusQA::SILKTEST;

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use Time::HiRes qw(gettimeofday tv_interval);
use File::Basename;

  our ( $TestStartTime, $TestEndTime, $TestExecTime );
=pod

=head1 NAME

SonusQA::SILKTEST- Perl module for SILKTEST application control.

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   ##use SonusQA::SILKTEST; # Only required until this module is not included in ATS above.

	$obj = SonusQA::SILKTEST->new(-obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
                                             -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                             -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                             -obj_silkPath => "$alias_hashref->{NODE}->{1}->{SILKTEST_LOCATION}",
                                             -obj_commtype => "TELNET",
                                            );

=head1 DESCRIPTION

This Module provides interface to SILKTEST Application through ATS Framework.
SILKTEST is a WINDOWS based application used to perform GUI testing.

=head1 PRE-REQUISITES

PsExec:
ATS to establish a successfull TELNET session with WINDOWS server it requires PsExec Tool to be made available.

PsExec is a light-weight telnet-replacement that lets you execute processes on other systems
This can be downloaded from the below location.
http://technet.microsoft.com/en-us/sysinternals/bb897553

SET PATH on your Windows Machine for
- SILKTEST installation location (Automatically set while SILKTEST is Installed)
- PsExec Executable's location

=head1 ARGUMENTS

    -obj_host:
	Windows Machine's IP address
    -obj_user:
	Windows Machine's User Login Name (viz: SONUSNETWORKS\nramaswamy)
    -obj_password:
	Windows Machine's User Login Password
    -obj_silkPath:
	SILKTEST installation location
    -obj_commtype
        TELNET or SSH; defaults to TELNET

=cut

use vars qw($self);
our @ISA = qw(SonusQA::Base);

my ($hostIp,$hostUser,$hostPwd,$silkLoc);

=head2 doInitialization()
  
  This function is called by Object new() method. Do not need to call it explicitly

  Arguments
    NONE 
  
  Returns
    NOTHING 
=cut

sub doInitialization {
  my($self)=@_;
  my $subName = "doInitialization";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
  
  $self->{COMMTYPES} = ["TELNET", "SSH", "SFTP", "FTP"];
  $self->{TYPE} = __PACKAGE__;
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{DEFAULTTIMEOUT} = 2000;
  $self->{LOCATION} = locate __PACKAGE__;
  my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm"); 
  $self->{DIRECTORY_LOCATION} = $path;
	# Get the User ID as logged-in
  $self->{USER} = `id -un`;
  chomp $self->{USER};
  $self->{LOG_LOCATION} = "/home/$self->{USER}/ats_user/logs";

  $logger->info("Initialization Complete");
  $logger->info("Module Location: $self->{DIRECTORY_LOCATION}");
}

=head2 setSystem()

  This function is called by Base::connect(). Initializes the arguments passed via ATSHELPER newFromAlias()

=cut

sub setSystem(){
    my($self,%args)=@_;
    my $logger = Log::Log4perl->get_logger("");
    $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");

    if ( defined $args{-obj_host} ) {
        $hostIp = $args{-obj_host};
    }

    if ( defined $args{-obj_user} ) {
        $hostUser = $args{-obj_user};
    }
  
    if ( defined $args{-obj_password} ) {
        $hostPwd = $args{-obj_password};
    }

    if ( defined $args{-obj_silkPath} ) {
        $silkLoc = $args{-obj_silkPath};
    }
    $self->{conn}->cmd(String => "tlntadmn config timeoutactive=no", Timeout=> $self->{DEFAULTTIMEOUT}); #Disabling the Telnet session timeout
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT}); #just an try to terminate all the IE session
      
    $logger->info("ENTERED SILKTESTUSER SUCCESSFULLY");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}  

=head2 launchApp

  This Function is invoked by runSilkTest()

  DESCRIPTION:
      Runs PsExec command on the SILKTEST object to load the project and start the application.
      This function constructs the PsExec Command and issues it on the Windows Machine.
      Command also includes the command arguments to convert SILTEST's .res file to a .txt file
      After the SILKTEST execution function parses for the error code and returns 0 or 1.
      
  ARGUMENTS:
    $projPath:
	SILKTEST Project Path on the Windows Machine.
    $projName:
	SILKTEST Project Execution Plan File Name (PLN file Name)
    $vtpName:
	SILKTEST Project File Name (VTP File Name)
    
    Returns:
	0 - For Failure
	1 - For Success
    
=cut

sub launchApp {
  my ($self,$projPath,$projName,$vtpName)=@_;
  my($logger, @cmdResults,$retVal);
  my $subName = "launchApp";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    if ( ! defined $projPath ) {
      $logger->info("MANDATORY PROJECT PATH NOT SPECIFIED..!");
      return 0;
    }

    if ( ! defined $projName ) {
      $logger->info("MANDATORY PROJECT NAME NOT SPECIFIED..!");
      return 0;
    }
    
    if ( ! defined $vtpName ) {
      $logger->info("MANDATORY VTP FILENAME NOT SPECIFIED..!");
      return 0;
    }

    $retVal = 1;
    
    my $psexecCommand = "psexec \\\\$hostIp -u $hostUser -p $hostPwd -i -w \"$silkLoc\" partner.exe -q -proj \"$projPath\\$vtpName.vtp\"  -resextract -r \"$projPath\\$projName.pln\"";
    $logger->info("ISSUING CMD: $psexecCommand");

    @cmdResults = $self->{conn}->cmd(String => $psexecCommand, Timeout=> $self->{DEFAULTTIMEOUT});

    if(grep /error code 0/is, @cmdResults) {
        $logger->info("*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->info("SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info("$psexecCommand");
        $logger->info("CMD RESULTS:");
        chomp(@cmdResults);
	    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info("\t\t$_") } @cmdResults;
        $logger->info("*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	$retVal = 1;
    } else {
        $logger->info("*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->info("UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->info("$psexecCommand");
        $logger->info("CMD RESULTS:");
        chomp(@cmdResults);
	    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info("\t\t$_") } @cmdResults;
        $logger->info("*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	$retVal = 0;
    }

  return ($retVal);
}

=head2 processResultFile()

  This Function is invoked by runSilkTest()

  DESCRIPTION:
      This Function shall copy the Result File (.txt format) to the Windows FTP location (c:\inetput\ftproot)
      Further to copy, this file is FTP'd to ATS server location at /home/<user>/ats_user/logs
      Result file shall be renamed with Timestamp prefixed.

  ARGUMENTS:
      $projPath:
	  SILKTEST Project Path on the Windows Machine.
      $projName:
	  SILKTEST Project Execution Plan File Name (PLN file Name)
      $release:
	TESTED RELEASE VERSION (viz: V08.00.00S000)
      $build:
	TESTED BUILD VERSION (viz: EMS_V08.00.10S000)

  Returns:
      1 on Success

=cut

sub processResultFile {
    my ($self,$projPath,$projName,$release,$build,$donotUpdateResToTMS) = @_;
    my $subName = "processResultFile";
    my ($logger,$tlnt,$ftp,$delFile,$copyFile,$targetLoc,@cmdRes);
    my ($i,$testcaseId,$testresult);

    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");

    $tlnt = new Net::Telnet( Timeout => 15, Host => $hostIp, Errmode => "return");
#    $logger->debug("Connected to the Remote Host");
    $tlnt->login( $hostUser, $hostPwd );
#    $logger->debug("Logged In...");
    sleep 2;

    $targetLoc = 'C:\\Inetpub\\ftproot';
    $delFile = "del $targetLoc\\$projName.txt";
    $copyFile = "copy \"$projPath\\$projName.txt\" $targetLoc";
    
    $logger->warn("COPYING RESULT FILE TO FTP LOCATION == $targetLoc ==");
    
    $tlnt->cmd($delFile);
    sleep (2);
    $tlnt->cmd($copyFile);

    unless ($tlnt->close) {
      $logger->warn("Failed to Disconnect the Copy Session...");
    }

    $logger->info("ATTEMPTING TO FTP RESULT FILE TO ATS SERVER LOCATION");

    if ( $ftp = Net::FTP->new("$hostIp", Debug => 0) ) {
	    $logger->info("Connected to the Remote Host for FTP");
	if ( $ftp->login("$hostUser","$hostPwd") ) {
	  $logger->info("FTP LOGIN SUCCESSFUL");
	} else {
	  my @ftpmsg = $ftp->message;
	  $logger->warn("FTP LOGIN NOT SUCCESSFUL");
	  $logger->warn("SERVICE_MSG: @ftpmsg");
	}

	$projName = "$projName.txt";

	if ( $ftp->get("$projName")) {
	  $logger->info("FTP RESULT FILE == $projName == SUCCESSFUL");
	} else {
	  my @ftpmsg = $ftp->message;
	  $logger->warn("FTP RESULT FILE == $projName == NOT SUCCESSFUL");
	  $logger->warn("SERVICE_MSG: @ftpmsg");
	}	

	if ( $ftp->quit ) {
	    $logger->info("Disconnected From the REMOTE HOST for FTP");
	} else {
	    $logger->warn("ERROR While Disconnecting from Remote HOST for FTP");
	}
    } else {
      my @ftpmsg = $@;
      $logger->warn("FTP NOT SUCCESSFUL");
      $logger->warn("SERVICE_MSG: @ftpmsg");
    }

    my $datestamp = strftime("%Y%m%d%H%M%S",localtime) ;
    my $newprojName = "$datestamp"."_"."$projName";

    `mv $projName $self->{LOG_LOCATION}/$newprojName`;

#	$newprojName = "20110329171709_ACCESS.txt";

    $logger->info("RESULT FILE == $newprojName == COPIED TO ATS SERVER LOCATION");

  my @cmdresults = &parseResultFile("$self->{LOG_LOCATION}/$newprojName",$projPath);

  unless ($donotUpdateResToTMS) {
      for ($i=0; $i<$#cmdresults; $i++) {
	   $testcaseId = $cmdresults[$i];
	   $testresult  = $cmdresults[$i+1];
	   $i++;
	   tmsResultUpdate($release, $build, $testcaseId, $testresult);
      }
  }

return 1;
}

=head2 parseResultFile()

  This Function is invoked by processResultFile()

  DESCRIPTION:
      This Function shall parse the log file to distiguish the Test Case ID against the PASS/FAIL results.
      Also shall reformat the Results and pass the formatted content to sendMail()
      
  ARGUMENTS:
      SILKTEST Result File to be parsed.
      
  Returns:
      An array with Test case ID and respective TMS Result.
      $testcaseId:
	Test case ID against which Result to be updated on TMS
      $result:
	1/0 to identify FAIL/PASS criteria that to be updated on TMS

=cut

sub parseResultFile()
{
    my ($fileName,$projPath) = @_;
    my $subName = "parseResultFile";
    my (@arrResult,@resFile,@arrDisplay,@errorDisplay,@warningDisplay) = ();
    my ($logger,$a1,$a2,$a3,$tmsId,$tmsResult);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    
    $logger->info("UPDATING TMS RESULTS FROM RESULT FILE: $fileName");

    if (open (FH, '<', $fileName)) {
      $logger->info("PARSING RESULT FILE");
    } else {
      my @errmsg = $!;	  
      $logger->warn("COULD NOT PARSE RESULT FILE");
      $logger->warn("SERVICE_MSG: @errmsg");
    }

    while (defined(my $line = <FH>)) {
      push @resFile, $line;
      if ($line =~ /:PASS:/) {
		    if ($line =~  m/\s+(\d+):(\w+):(.*)$/) {
			    $a1 = $1; $a2 = $2;
			    $tmsId = "$a1";
			    $tmsResult = "0";
			    $a3 = $3;
		    }
		    push (@arrResult, "$tmsId", "$tmsResult");
		    push (@arrDisplay, "$tmsId\t\tPASS\t\t$a3")
	    }
      if ($line =~ /:FAIL:/) {
		    if ($line =~  m/\s+(\d+):(\w+):(.*)$/) {
			    $a1 = $1; $a2 = $2;
			    $tmsId = "$a1";
			    $tmsResult = "1";
			    $a3 = $3;
		    }
		    push (@arrResult, "$tmsId", "$tmsResult");
		    push (@arrDisplay, "$tmsId\t\tFAIL\t\t$a3")
	    }
      if ($line =~ /\*\*\* error/i) {
	push(@errorDisplay, $line);
      }
      if ($line =~ /\*\*\* warning/i) {
	push(@warningDisplay, $line);
      }
    }

    $logger->info("========================================================== SILKTEST OUTPUT ======================================================================");
    foreach ( @resFile ) {
      $logger->info("$_");
    }
    $logger->info("=================================================================================================================================================");	

    if (open (STDOUT, "> ParseFile.txt")) {
      $logger->info("REFORMATING RESULT FILE");
    } else {
      my @errmsg = $!;	  
      $logger->warn("COULD NOT FORMAT RESULT FILE");
      $logger->warn("SERVICE_MSG: @errmsg");
    }
  
    print ("=================================================================================================================================================\n");
    print ("\tTCID\t\tSTATUS\t\tMESSAGE\n");
    print ("=================================================================================================================================================\n");
	  foreach ( @arrDisplay ) {
	    print "\t$_\n";
	  }
    print ("=================================================================================================================================================\n");	
  
    if ( scalar @errorDisplay gt 0 ) {
      print "\nOBSERVED BELOW ERRORS\n";
      print ("--------------------------------------------\n");	
      foreach (@errorDisplay) { print "$_"; }
    }
  
    if ( scalar @warningDisplay gt 0 ) {
      print "\nOBSERVED BELOW WARNINGS\n";
      print ("--------------------------------------------\n");	
      foreach (@warningDisplay) { print "$_"; }
    }

    close FH;
    close STDOUT;
    
    &sendMail( -file => "ParseFile.txt",
	       -projPath => $projPath,
	     );
    
    $logger->info("RESULT FILE PARSED SUCCESSFULLY");
    
    `rm ParseFile.txt`;
    
    return (@arrResult);
}

=head2 sendMail()

  This Function is invoked by parseResultFile()

  DESCRIPTION:
    This function shall take the contents of arguments passed and send it over the e-mail.
    E-mail addresses can be specified in the testsuiteList.pl as under
    
    $ENV{'ATS_EMAIL_LIST'} = qw(nramaswamy@sonusnet.com krodrigues@sonusnet.com);
      
    if above list is not specified, by default it shall be mailed to the user ID as logged in.
    
  ARGUMENTS:
    $File:
	File Name whose contents to be mailed.
    $suite:
	Project being executed.
      
  Returns:
      NIL

=cut

sub sendMail ()
    {
    my(%args)=@_;
    my ($logger,$to,$File,$suite,$start_time,$finish_time,$exec_time,$extraInfo);
    my $sub = "sendMail";
    $logger = Log::Log4perl->get_logger( __PACKAGE__ . "$sub .Sending Mail" );
    
    if (! defined $args{-file}){
	$logger->error( __PACKAGE__ . "File name undefined");
	return 0;
    } else { $File = $args{-file};}
    
    $suite = $args{-projPath};

    my @to1 = qx#id -un#;
    chomp(@to1);
    $to = $to1[0]."\@sonusnet\.com";
    my @maillist = ("$to");
    
    if ( defined $ENV{'ATS_EMAIL_LIST'} ) {
      @maillist = $ENV{'ATS_EMAIL_LIST'};
      push ( @maillist, $to );
    }
    
    $logger->debug( __PACKAGE__ . "$sub .Sending the mail to : $to");
    my $sendmail = "/usr/sbin/sendmail -t";
    my $subject = "Subject: Automation Test Results";
    
    $to = "To:@maillist \n";
    $logger->debug(__PACKAGE__ . "$sub .Sending mail :  $to");
    open(SENDMAIL, "| $sendmail") or die "Cannot open $sendmail: $!";
    
    open(RESULT , "$File") or return "cannot open file";
    print SENDMAIL "$subject : $suite\n";
    print SENDMAIL "$to\n";
    
    print SENDMAIL " AUTOMATION RESULTS $suite\n";
    print SENDMAIL " EXECUTION STARTED AT : $start_time\n";
    if ( defined($extraInfo)) {
	print SENDMAIL "$extraInfo\n";
    }
    print SENDMAIL "\n";
    while(<RESULT>)
    {
    print(SENDMAIL " $_");
    }
    print SENDMAIL "\n\n";
    print SENDMAIL " EXECUTION COMPLETED AT : $finish_time\n\n";
    if ( defined ($exec_time))
    {
      print SENDMAIL " EXECUTION DURATION : $exec_time\n";
    } 
    close(SENDMAIL);
    $logger->debug( __PACKAGE__ . "$sub .Successfully Mailed");

}

=head2 tmsResultUpdate()

  This Function is invoked by processResultFile()

  DESCRIPTION:
      This Function shall Update the test results on to TMS against release and Test case ID.
      
  ARGUMENTS:
      $release:
	TESTED RELEASE VERSION (viz: V08.00.00S000)
      $build:
	TESTED BUILD VERSION (viz: EMS_V08.00.10S000)
      $testcaseId:
	Test case ID against which Result to be updated on TMS
      $result:
	1/0 to identify FAIL/PASS criteria that to be updated on TMS
      
  Returns:
      An array with Test case ID and respective TMS Result.

=cut

sub tmsResultUpdate {
	my ($release, $build, $testcaseId, $result) = @_;
	my $subName = "tmsResultUpdate";
	
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");	

#	$logger->info (" Release => $release  Build => $build  TestCaseID => $testcaseId  Result => $result");
	
        if ( $ENV{ "ATS_LOG_RESULT" } )
        {
            $logger->debug("$testcaseId: Logging result in TMS: $result for testcase ID $testcaseId");
            unless ( SonusQA::Utils::log_result (
                                            -test_result    => $result,
                                            -release        => "$release",
                                            -testcase_id    => "$testcaseId",
                                            -build          => "$build",
                                       ) ) {
                $logger->error(" $testcaseId: ERROR: Logging of test result to TMS has FAILED");
            }
	$logger->info("Result Updated in TMS for $testcaseId");
        }
}

=head2 runSilkTest()

  DESCRIPTION:
      This Function shall invoke launchApp() and processResultFile() by collecting the arguments from the FEATURE module.
      This is the only function exposed to Tester for SILKTEST execution.
      
  Returns:
      0 for Failure
      1 for Success

=cut

sub runSilkTest {
  my ($self,%args) = @_;
  my ($logger,$projPath,$projName,$vtpName,$release,$build,$returnFlag);

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);

  my $subName = "runSilkTest";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
 
  if ( defined $args{-projLoc}) {
    $projPath = $args{-projLoc};
  } else {
    $logger->info("MANDATORY PROJECT LOCATION NOT SPECIFIED..!");
    return 0;
  }
  
  if ( defined $args{-plnName}) {
    $projName = $args{-plnName};
  } else {
    $logger->info("MANDATORY PLAN NAME NOT SPECIFIED..!");
    return 0;
  }
    
  if ( defined $args{-vtpName}) {
    $vtpName = $args{-vtpName};
  } else {
    $logger->info("MANDATORY VTP FILENAME NOT SPECIFIED..!");
    return 0;
  }
    
  if ( defined $args{-release}) {
    $release = $args{-release};
  } else {
    $logger->info("MANDATORY RELEASE INFORMATION NOT SPECIFIED..!");
    return 0;
  }
  
  if ( defined $args{-build}) {
    $build = $args{-build};
  } else {
    $logger->info("MANDATORY BUILD INFORMATION NOT SPECIFIED..!");
    return 0;
  }
 
  if ( defined $args{-timeout}) {
    $self->{DEFAULTTIMEOUT} = $args{-timeout};
    $logger->info("SILKTEST EXECUTION DEFAULT TIMEOUT IS SET TO $self->{DEFAULTTIMEOUT} secs");
  }
 
  my $donotUpdateResToTMS;
  if ( defined $args{-donotUpdateResToTMS}) {
    $logger->info("'-donotUpdateResToTMS' PARAMETER IS SET TO --> $args{-donotUpdateResToTMS}");
    $donotUpdateResToTMS = $args{-donotUpdateResToTMS};
  } else {
     $donotUpdateResToTMS = 0;
  }

  $returnFlag = 1; 

  my ( $StartTimeReference, $TestSuiteExecInterval );
  ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )=localtime(time);
  $TestStartTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
  $StartTimeReference = [Time::HiRes::gettimeofday];

  if ($self->launchApp($projPath,$projName,$vtpName)) {
    $logger->info("SILKTEST EXECUTION COMPLETED");
  } else {
    $logger->warn("ERROR WHILE EXECUTING SILKTEST");
    $returnFlag = 0; 
  }

  ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
  $TestEndTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
  my @execTime = reverse( ( gmtime( int tv_interval ($StartTimeReference) ) )[0..2] );
  $TestExecTime = sprintf("%02d:%02d:%02d", $execTime[0], $execTime[1], $execTime[2]);

  if ($self->processResultFile($projPath,$projName,$release,$build,$donotUpdateResToTMS)) {
    $logger->info("PROCESSING RESULT FILE COMPLETED");
  } else {
    $logger->warn("ERROR WHILE PROCESSING RESULT FILE");
    $returnFlag = 0; 
  }

  if ( $returnFlag ) {
    return 1;
  } else {
    return 0;
  }

}

=head2 execCmd()

    This function enables user to execute any command on the Silktest machine.

Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

Return Value:

    Output of the command executed.

Usage:

    my @results = $obj->execCmd("dir");
    This would execute the command "dir" on the session and return the output of the command.

=cut

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
   my(@cmdResults,$timestamp);
   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
   }
   $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      return @cmdResults;
   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   return @cmdResults;
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

=head2 create_FM_FWD()

    This function creates FM FWD Profile on the EMS SUT  
                 - launches silk test on the silk test machine
                 - makes use of PsExec to run the specified silk test script 
                 - Validates the successful launch of silk test
                 - Validates the result of the silk test script executed and generates the result file 

Arguments:

    Hash with below deatils
          - Manditory
                -emsObj  => Object of the EMS SUT
                -vtpName => Project File Name 
                -scriptName => Script to be run
                -FWD_IP   => IP of the forwarded EMS 
                -tcase    => testcase id 

Return Value:

    1 - on success
    0 - on failure

Usage:
    my %args = (-emsObj => 'emsObj',
                -vtpName => 'GSX_8.0_Regression_Rework_Part1',
                -scriptName => 'create_FM_FWD',
                -FWD_IP => "10.54.128.252",
                -tcase => 'FM_PERF_036');

    my $result = $Obj->create_FM_FWD(%args);

=cut

sub create_FM_FWD {
    my($self, %args)=@_;
    my $sub = "create_FM_FWD";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    #my $log_dir = $main::TESTSUITE->{LOG_PATH};
    foreach ('-emsObj','-vtpName', '-scriptName', '-FWD_IP', '-tcase') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }
    $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION}="C:\\Program Files\\Borland\\SilkTest\\Projects\\GSX_8.0_Regression_Rework_Part1";
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    my $silkLoc=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    my $projPath=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION};
    my @cmdResults;
    my $retVal;
    my $ftp;
    my @args="$EMS_IP $args{-FWD_IP} $user $pwd  $args{-tcase}";
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;
    my $SUT_Name=$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $resultFile=$self->{result_path}."$SUT_Name\_$args{-tcase}\_$timestamp"; 
    my $del="del  \"$projPath\\$args{-scriptName}.txt\"";
    $self->{conn}->cmd( String => $del, Timeout=>10);


    my $psexecCommand= "PsExec.exe \\\\$hostIp -u $hostIp\\$hostUser -p $hostPwd -i 0 \"$silkLoc\\partner.exe\" -q -proj \"$projPath\\$args{-vtpName}.vtp\"  -resextract -r \"$projPath\\$args{-scriptName}.t\" @args";
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    unless (@cmdResults=$self->{conn}->cmd( String => $psexecCommand, Timeout=>600)) {
        $logger->error(__PACKAGE__ . ".$sub: failed to execute the command \'$psexecCommand\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub <-[0]");
        return 0;
    }

    if(grep /error code 0/is, @cmdResults) {
        $logger->info(__PACKAGE__ . ".$sub: SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->info(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 1;
        @cmdResults=$self->{conn}->cmd("type \"$projPath\\$args{-scriptName}.txt\"");

        if(grep /Passed/is, @cmdResults) {
            $logger->info(__PACKAGE__ . ".$sub: TEST PASSED");}
        else
        {
            $logger->info(__PACKAGE__ . ".$sub: TEST FAILED with errors");
            $retVal = 0;}

        $logger->info(__PACKAGE__ . ".$sub: Writing the Silk Test results to the file $resultFile.txt");

        my $f;
        unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub: failed to open file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        print LOGFILE join("\n", @cmdResults);
        unless ( close LOGFILE ) {
        $logger->error(__PACKAGE__ . ".$sub: Cannot close output file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub: Silk Test results successfully written to the file $resultFile.txt");
    
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->error(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->error(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->error(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 0;
    }

    return ($retVal);

}

=head2 Silk_Call()

    This function enables FTP on the EMS SUT 
                 - launches silk test on the silk test machine
                 - makes use of PsExec to run the specified silk test script
                 - Validates the successful launch of silk test
                 - Validates the result of the silk test script executed and generates the result file

Arguments:

    Hash with below deatils
          - Manditory
                -emsObj  => Object of the EMS SUT
                -vtpName => Project File Name
                -scriptName => Script to be run
                -tcase    => testcase id

Return Value:

    1 - on success
    0 - on failure

Usage:
    my %args = (-emsObj => 'emsObj',
                -vtpName => 'GSX_8.0_Regression_Rework_Part1',
                -scriptName => 'enable_FTP'| 'disable_FTP'| 'GUI_Login'|'GUI_Login_ClearCache',
                -tcase => 'FM_PERF_036');

    my $result = $Obj->Silk_Call(%args);

=cut

sub Silk_Call {
    my($self, %args)=@_;
    my $sub = "Silk_Call";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    #my $log_dir = $main::TESTSUITE->{LOG_PATH};
    foreach ('-emsObj','-vtpName', '-scriptName', '-tcase') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }
    $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION}="C:\\Program Files\\Borland\\SilkTest\\Projects\\GSX_8.0_Regression_Rework_Part1";
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    my $silkLoc=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    my $projPath=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION};
    my @cmdResults;
    my $retVal;
    my @args="$EMS_IP $user $pwd  $args{-tcase}";
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;
    my $SUT_Name=$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $resultFile=$self->{result_path}."$SUT_Name\_$args{-tcase}\_$timestamp";
    my $del="del  \"$projPath\\$args{-scriptName}.txt\"";
    $self->{conn}->cmd( String => $del, Timeout=>10);


    my $psexecCommand= "PsExec.exe \\\\$hostIp -u $hostIp\\$hostUser -p $hostPwd -i 0 \"$silkLoc\\partner.exe\" -q -proj \"$projPath\\$args{-vtpName}.vtp\"  -resextract -r \"$projPath\\$args{-scriptName}.t\" @args";
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    unless (@cmdResults=$self->{conn}->cmd( String => $psexecCommand, Timeout=>600)) {
        $logger->error(__PACKAGE__ . ".$sub: failed to execute the command \'$psexecCommand\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub <-[0]");
        return 0;
    }

    if(grep /error code 0/is, @cmdResults) {
        $logger->info(__PACKAGE__ . ".$sub: SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->info(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 1;
        @cmdResults=$self->{conn}->cmd("type \"$projPath\\$args{-scriptName}.txt\"");

        if(grep /Passed/is, @cmdResults) {
            $logger->info(__PACKAGE__ . ".$sub: TEST PASSED");}
        else
        {
            $logger->info(__PACKAGE__ . ".$sub: TEST FAILED with errors");
            $retVal = 0;}

        $logger->info(__PACKAGE__ . ".$sub: Writing the Silk Test results to the file $resultFile.txt");

        my $f;
        unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub: failed to open file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        print LOGFILE join("\n", @cmdResults);
        unless ( close LOGFILE ) {
        $logger->error(__PACKAGE__ . ".$sub: Cannot close output file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub: Silk Test results successfully written to the file $resultFile.txt");

    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->error(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->error(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->error(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 0;
    }

    return ($retVal);

}

=head2 Modify_Profile()

    This function modifies the sample collection profile. 
                 - launches silk test on the silk test machine
                 - makes use of PsExec to run the specified silk test script
                 - Validates the successful launch of silk test
                 - Validates the result of the silk test script executed and generates the result file

Arguments:

    Hash with below deatils
          - Manditory
                -emsObj  => Object of the EMS SUT
                -vtpName => Project File Name
                -scriptName => Script to be run
                -tcase    => testcase id
                -dev   => device whose sample profile has to be modified
                -coll  => collection frequency in minutes
                -export => export frequency in minutes
                -stats => either ATT or TG
               
          - Optional
                -HA   => to indicate whether the SUT is HA 

Return Value:

    1 - on success
    0 - on failure

Usage:
    my %args = (-emsObj => 'emsObj',
                -vtpName => 'PerformanceManagement_Regression',
                -scriptName => 'Modify_Profile',
                -tcase => 'PM_PERF_019',
                -dev   => 'GSX',
                -coll => '5',
                -export => '5',
                -stats => 'ATT',
                -HA    => 'HA' );

    my $result = $Obj->Modify_Profile(%args);

=cut

sub Modify_Profile {
    my($self, %args)=@_;
    my $sub = "Modify_Profile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    #my $log_dir = $main::TESTSUITE->{LOG_PATH};
    foreach ('-emsObj','-vtpName', '-scriptName', '-tcase', '-dev', '-coll', '-export','-stats') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }
    $args{-HA} ||= "root";
    $args{-emsObj}->{dev} = uc "$args{-dev}"; #Used in pm_total_loss , pm_device_loss for identfifying the device
    my $test_time = `date +"%s"`;
    $test_time = $test_time - ($test_time % ($args{-export}*60)) + ($args{-export}*60*3);

    my $M=`date -d '1970-01-01 $test_time sec + 19800sec' +"%r" | cut -f2 -d ' '`;
    chomp($M);
    
    my $hour1=`date -d '1970-01-01 $test_time sec + 19800sec' +"%l"`;
    chomp($hour1);

    my $min1=`date -d '1970-01-01 $test_time sec + 19800sec' +"%M"`;
    chomp($min1);
    $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION}="C:\\Program Files\\Borland\\SilkTest\\Projects\\PerformanceManagement_Regression";
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    my $silkLoc=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    my $projPath=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION};
    my @cmdResults;
    my $retVal;
    my $exportPath = "$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}"."$main::TESTSUITE->{PM_DIR}"."/"."$args{-tcase}";
    #my @args="$EMS_IP $user $pwd $args{-coll} $args{-export} $args{-stats} $args{-tcase} $hour1 $min1 $M $args{-dev} $args{-HA}";
    my @args="$EMS_IP $user $pwd $args{-coll} $args{-export} $args{-stats} $exportPath  $hour1 $min1 $M $args{-dev} $args{-HA}";

    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime; 
    my $SUT_Name=$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $resultFile=$self->{result_path}."$SUT_Name\_$args{-tcase}\_$timestamp"; 
    my $del="del  \"$projPath\\$args{-scriptName}.txt\"";
    $self->{conn}->cmd( String => $del, Timeout=>10);


    my $psexecCommand= "PsExec.exe \\\\$hostIp -u $hostIp\\$hostUser -p $hostPwd -i 0 \"$silkLoc\\partner.exe\" -q -proj \"$projPath\\$args{-vtpName}.vtp\"  -resextract -r \"$projPath\\$args{-scriptName}.t\" @args";
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    unless (@cmdResults=$self->{conn}->cmd( String => $psexecCommand, Timeout=>600)) {
        $logger->error(__PACKAGE__ . ".$sub: failed to execute the command \'$psexecCommand\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub <-[0]");
        return 0;
    }

    if(grep /error code 0/is, @cmdResults) {
        $logger->info(__PACKAGE__ . ".$sub: SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->info(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 1;
        @cmdResults=$self->{conn}->cmd("type \"$projPath\\$args{-scriptName}.txt\"");

        if(grep /Passed/is, @cmdResults) {
            $logger->info(__PACKAGE__ . ".$sub: TEST PASSED");}
        else
        {
            $logger->info(__PACKAGE__ . ".$sub: TEST FAILED with errors");
            $retVal = 0;}

        $logger->info(__PACKAGE__ . ".$sub: Writing the Silk Test results to the file $resultFile.txt");

        my $f;
        unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub: failed to open file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        print LOGFILE join("\n", @cmdResults);
        unless ( close LOGFILE ) {
        $logger->error(__PACKAGE__ . ".$sub: Cannot close output file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub: Silk Test results successfully written to the file $resultFile.txt");

    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->error(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->error(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->error(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 0;
    }

    return ($retVal);

}

=head2 Enable_Collection()

    This function enables PM collection.
                 - launches silk test on the silk test machine
                 - makes use of PsExec to run the specified silk test script
                 - Validates the successful launch of silk test
                 - Validates the result of the silk test script executed and generates the result file

Arguments:

    Hash with below deatils
          - Manditory
                -emsObj  => Object of the EMS SUT
                -vtpName => Project File Name
                -scriptName => Script to be run
                -tcase    => testcase id
                -start_node => Starting device name
                -no_of_nodes  => number of devices


Return Value:

    1 - on success
    0 - on failure

Usage:
    my %args = (-emsObj => 'emsObj',
                -vtpName => 'PerformanceManagement_Regression',
                -scriptName => 'Enable_Collection',
                -tcase => 'PM_PERF_019',
                -start_node => "VYOM_4_002",
                -no_of_nodes => "200" );
    
my $result = $Obj->Enable_Collection(%args);

=cut

sub Enable_Collection {
    my($self, %args)=@_;
    my $sub = "Enable_Collection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my $log_dir = $main::TESTSUITE->{LOG_PATH};
    foreach ('-emsObj','-vtpName', '-scriptName', '-tcase', '-start_node', '-no_of_nodes') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION}="C:\\Program Files\\Borland\\SilkTest\\Projects\\PerformanceManagement_Regression";
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    my $silkLoc=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    my $projPath=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION};
    my @cmdResults;
    my $retVal;
    my @args="$EMS_IP $user $pwd $args{-tcase} $args{-start_node} $args{-no_of_nodes}";

    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = "\$(date +%m-%d-%y-%H-%M)";
    my $SUT_Name=$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $resultFile=$log_dir."$SUT_Name\_$args{-tcase}\_$timestamp"; 
    my $del="del  \"$projPath\\$args{-scriptName}.txt\"";
    $self->{conn}->cmd( String => $del, Timeout=>10);


    my $psexecCommand= "PsExec.exe \\\\$hostIp -u $hostIp\\$hostUser -p $hostPwd -i 0 \"$silkLoc\\partner.exe\" -q -proj \"$projPath\\$args{-vtpName}.vtp\"  -resextract -r \"$projPath\\$args{-scriptName}.t\" @args";
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    unless (@cmdResults=$self->{conn}->cmd( String => $psexecCommand, Timeout=>600)) {
        $logger->error(__PACKAGE__ . ".$sub: failed to execute the command \'$psexecCommand\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub <-[0]");
        return 0;
    }

    if(grep /error code 0/is, @cmdResults) {
        $logger->info(__PACKAGE__ . ".$sub: SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->info(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 1;
        @cmdResults=$self->{conn}->cmd("type \"$projPath\\$args{-scriptName}.txt\"");

        if(grep /Passed/is, @cmdResults) {
            $logger->info(__PACKAGE__ . ".$sub: TEST PASSED");}
        else
        {
            $logger->info(__PACKAGE__ . ".$sub: TEST FAILED with errors");
            $retVal = 0;}

        $logger->info(__PACKAGE__ . ".$sub: Writing the Silk Test results to the file $resultFile.txt");

        my $f;
        unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub: failed to open file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        print LOGFILE join("\n", @cmdResults);
        unless ( close LOGFILE ) {
        $logger->error(__PACKAGE__ . ".$sub: Cannot close output file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub: Silk Test results successfully written to the file $resultFile.txt");

    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->error(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->error(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->error(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 0;
    }

    return ($retVal);

}

=head2 Disable_Collection()

    This function disables PM collection.
                 - launches silk test on the silk test machine
                 - makes use of PsExec to run the specified silk test script
                 - Validates the successful launch of silk test
                 - Validates the result of the silk test script executed and generates the result file

Arguments:

    Hash with below deatils
          - Manditory
                -emsObj  => Object of the EMS SUT
                -vtpName => Project File Name
                -scriptName => Script to be run
                -tcase    => testcase id
                -start_node => Starting device name
                -no_of_nodes  => number of devices


Return Value:

    1 - on success
    0 - on failure

Usage:
    my %args = (-emsObj => 'emsObj',
                -vtpName => 'PerformanceManagement_Regression',
                -scriptName => 'Disable_Collection',
                -tcase => 'PM_PERF_019',
                -start_node => "VYOM_4_002",
                -no_of_nodes => "200" );

my $result = $Obj->Disable_Collection(%args);

=cut


sub Disable_Collection {
    my($self, %args)=@_;
    my $sub = "Disable_Collection";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my $log_dir = $main::TESTSUITE->{LOG_PATH};
    foreach ('-emsObj','-vtpName', '-scriptName', '-tcase', '-start_node', '-no_of_nodes') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION}="C:\\Program Files\\Borland\\SilkTest\\Projects\\PerformanceManagement_Regression";
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $hostIp=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    my $hostUser=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
    my $hostPwd=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
    my $silkLoc=$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
    my $projPath=$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{SILKTEST_LOCATION};
    my @cmdResults;
    my $retVal;
    my @args="$EMS_IP $user $pwd $args{-tcase} $args{-start_node} $args{-no_of_nodes}";

    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = "\$(date +%m-%d-%y-%H-%M)";
    my $SUT_Name=$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my $resultFile=$log_dir."$SUT_Name\_$args{-tcase}\_$timestamp"; 
    my $del="del  \"$projPath\\$args{-scriptName}.txt\"";
    $self->{conn}->cmd( String => $del, Timeout=>10);


    my $psexecCommand= "PsExec.exe \\\\$hostIp -u $hostIp\\$hostUser -p $hostPwd -i 0 \"$silkLoc\\partner.exe\" -q -proj \"$projPath\\$args{-vtpName}.vtp\"  -resextract -r \"$projPath\\$args{-scriptName}.t\" @args";
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    unless (@cmdResults=$self->{conn}->cmd( String => $psexecCommand, Timeout=>600)) {
        $logger->error(__PACKAGE__ . ".$sub: failed to execute the command \'$psexecCommand\'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub <-[0]");
        return 0;
    }

    if(grep /error code 0/is, @cmdResults) {
        $logger->info(__PACKAGE__ . ".$sub: SILKTEST LAUNCHED SUCCESSFULLY, COMMAND USED:");
        $logger->info(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->info(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->info(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 1;
        @cmdResults=$self->{conn}->cmd("type \"$projPath\\$args{-scriptName}.txt\"");

        if(grep /Passed/is, @cmdResults) {
            $logger->info(__PACKAGE__ . ".$sub: TEST PASSED");}
        else
        {
            $logger->info(__PACKAGE__ . ".$sub: TEST FAILED with errors");
            $retVal = 0;}

        $logger->info(__PACKAGE__ . ".$sub: Writing the Silk Test results to the file $resultFile.txt");

        my $f;
        unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
        $logger->error(__PACKAGE__ . ".$sub: failed to open file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        print LOGFILE join("\n", @cmdResults);
        unless ( close LOGFILE ) {
        $logger->error(__PACKAGE__ . ".$sub: Cannot close output file ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
        return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub: Silk Test results successfully written to the file $resultFile.txt");

    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: UNKNOWN ERROR DETECTED, COMMAND USED:");
        $logger->error(__PACKAGE__ . ".$sub: $psexecCommand");
        $logger->error(__PACKAGE__ . ".$sub: CMD RESULTS:");
        chomp(@cmdResults);
            @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
        map { $logger->error(__PACKAGE__ . ".$sub: \t\t$_") } @cmdResults;
        $retVal = 0;
    }

    return ($retVal);

}

1;
