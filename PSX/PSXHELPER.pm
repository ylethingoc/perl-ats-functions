package SonusQA::PSX::PSXHELPER;

require SonusQA::PSX;
use WWW::Curl::Easy;
use Data::Dumper;

=head1 NAME

SonusQA::ORACLE::ORACLEHELPER - Perl module for Sonus Networks PSX (UNIX) interaction
REQUIRES
Perl5.8.6, Log::Log4perl, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX
DESCRIPTION
This is a place to implement frequent activity functionality, standard non-breaking routines.
Items placed in this library are inherited by all versions of PSX - they must be generic.

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate /;
use File::Path qw(mkpath);
use File::Basename;
our $VERSION = "6.1";

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


# date 
# 03/05/07 18:29:52
# Tue Mar  6 10:26:04 EST 2007

sub getSystemDate {
	my ($self, %args)=@_;
	my (@cmdResults, $cmd, $logger, $sysdate);
	$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getSystemDate");
	$cmd = "date";
	@cmdResults = $self->execCmd($cmd,5);
	$sysdate = chomp($cmdResults[0]);
	return $sysdate;
}


# example# date -u 010100302000
# sets the date to January 1st, 12:30 am, 2000, which will  be
# displayed as
# Thu Jan 01 00:30:00 GMT 2000

sub setSystemDate {
	my ($self, %args)=@_;
	my (@cmdResults, $cmd, $logger, $sysdate);
	$logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystemDate");
	if($self->{OBJ_USER} ne 'root'){
		$logger->error(__PACKAGE__ . ".writeBlankDBUpdateFile Must be root to perform this action");
		return 0;
	}
	print("Args $args{0} $args{1}\n");
	$cmd = "date $args{0}";
	$self->execCmd($cmd,5);
}


=head2 getTimeRangeProfileString()

 getTimeRangeProfileString is used to create a string for use with the 
 time range profile entity on the PSX. The method accepts a low and high 
 range for included hours in the time range, 
 (i.e. getTimeRangeProfileString(5, 10) would include 5am-9:59:59am)
 and returns a string with those hours included.

=over

=item Assumptions made :

 That the EMS is expecting a 360 character string for use with the creation of a time range profile entry.

=item Arguments :

 -low
     Starting hour value of time range.
 -high
     Ending hour value of time range.

=item Return Values :

 $TRPstring - Returns a 360 character string that represents, in hex, the bits (i.e. minutes) that are
              considered a 'valid' time range. A 0xF would be four consecutive minutes of 'valid' time.

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::getTimeRangeProfileString(5, 10);

=item Author :

 S.Martin
 smartin@sonusnet.com

=back

=cut 

sub getTimeRangeProfileString {
	my ($self, $low, $high)=@_;
	my $hourinclude = "FFFFFFFFFFFFFFF";
	my $hourexclude = "000000000000000";
	my $diff = $high - $low;
	my $TRPstring = "";
	my ($i, $j, $k);

	if ($low > 24 || $high > 24) {
		$low = $low - 24;
		$high = $high - 24;
		if ($low < 0) {
			my $diff = 0 - $low;
			$low = 0;
			$high = $high + $diff;
		}
	}
	
	# create low exclude range
	for ($i=0; $i<$low; $i++) {
		$TRPstring = $TRPstring . $hourexclude;
	}

	# create include range
	for ($j=0; $j<$diff; $j++) {
		$TRPstring = $TRPstring . $hourinclude;
	}

	# create high exclude range
	for ($k=0; $k<(24-$high); $k++) {
		$TRPstring = $TRPstring . $hourexclude;
	}

	# Reverse because time starts at least sig. bit.		
	$TRPstring = reverse($TRPstring);
	
	if (length($TRPstring) > 360) {
		$TRPstring = substr($TRPstring, 0, 355);	
	}
	else {
		return ($TRPstring); 
	}
} # end getTimeRangeProfileString


=head2 getTimeRangeProfileSpecialDays()

 Returns a string for use with the Time Range Profile
 entity's 'Special Days' section. It takes as input the
 day and month, ex. 03, 08 for March 8th. 

=over

=item Assumptions made :

 That the EMS is expecting a 366 character string (365 days + Feb 29) for use with the creation of 
 the 'special days' field in a time range profile entry. Also, there is no checking done for invalid
 days (>31).

=item Arguments :

 -day
     The current day of the month (1-31).
 -month
     The current month (1-12).

=item Return Values :

 $specialString - Returns a 366 character string that represents, in binary, the bits (i.e. days) that are
                  considered 'special'.

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::getTimeRangeProfileSpecialDays(25, 6); # (This would be June 25th)

=item Author :

 S.Martin
 smartin@sonusnet.com

=back

=cut 

sub getTimeRangeProfileSpecialDays {
	my ($self, $day, $month)=@_;
	my $i = 1;
	my ($dayString, $monthString, $specialString) = "";
	my %monthHash = (
		'1' 		=> '0000000000000000000000000000000',	# Jan
		'2' 		=> '00000000000000000000000000000',		# Feb
		'3' 		=> '0000000000000000000000000000000',	# Mar
		'4' 		=> '000000000000000000000000000000',		# Apr
		'5' 		=> '0000000000000000000000000000000',	# May
		'6' 		=> '000000000000000000000000000000',		# Jun
		'7' 		=> '0000000000000000000000000000000',	# Jul
		'8' 		=> '0000000000000000000000000000000',	# Aug
		'9' 		=> '000000000000000000000000000000',		# Sept
		'10' 		=> '0000000000000000000000000000000',	# Oct
		'11' 		=> '000000000000000000000000000000',		# Nov
		'12' 		=> '0000000000000000000000000000000',	# Dec		       
	);

        # set the desired day in the day string to 1
	for ($i = 1; $i <= length($monthHash{$month}); $i++) {
		if ($i == $day) { $dayString = $dayString . '1'; }	# if the day matches
		else { $dayString = $dayString . '0'; }
	}

	# set value in hash to reflect updated day string
	$monthHash{$month} = $dayString;

	# Build the 366 character special day string
	$specialString = $monthHash{'1'} . $monthHash{'2'} . $monthHash{'3'} . $monthHash{'4'} . $monthHash{'5'} . $monthHash{'6'} . $monthHash{'7'} . $monthHash{'8'} . $monthHash{'9'} . $monthHash{'10'} . $monthHash{'11'} . $monthHash{'12'}; 
	return $specialString;
} # end getTimeRangeProfileSpecialDays


sub getLog_PreRouterIn {
  my ($self, $logArray)=@_;
  my (@cmdResults, $logger, $startDemarc, $endDemarc);
  @cmdResults = ();
  $startDemarc = '\#+.*PreRouterIn\s+START.*\#+';
  $endDemarc = '\#+.*PreRouterIn\s+END.*\#+';
  if(!defined($logArray)){
    $logger->warn(__PACKAGE__ . ".getLog_PreRouterIn  LOG NOT SUPPLIED - REQUIRED");
    return 0;
  }
  return $self->getLogSegment($startDemarc,$endDemarc,\@{$logArray});
}

=head2 pesLogStart()

 pesLogStart method is used to start capture of pes logs per testcase in PSX. The name of the log file will be of the format <Testcase-id>_PSX_<psx hostname>_timestamp.log. Timestamp will be of format yyyymmdd_HH:MM:SS.log. 
 The mandatory arguments are test_case, host_name.
 The optional arguments are ats_xtail_dir, nfs_mount and psx_nfs_mount. 
 After using pesLogStart ,use pesLogStop function in the test script to kill the process(es).

NOTE :---> For log capture, tail process will fetch the logs and store in AUTOMATION folder in NFS mount directory in the PSX. If AUTOMATION directory is not present , it will be created.

=over

=item Assumptions made :

 It is assumed that NFS is mounted on the PSX machine.Default is set as /export/home/SonusNFS. If NFS is not mounted ,please mount it and then start the test script.

=item Arguments :

 -test_case
     specify testcase id for which log needs to be generated.
 -host_name
     specify the psx/gsx hostname
 -ats_xtail_dir
     This is an optional parameter to specify the ats location for copying the xtail file, default is /ats/bin
 -nfs_mount
     This is an optional parameter to specify the nfs directory from where subroutine is invoked,default is /sonus/SonusNFS
 -psx_nfs_mount
     This is an optional parameter to specify nfs mount directory within PSX ,default value is /export/home/SonusNFS

=item Return Values :

 Success - Return an array with following contents,
           Process id of pes.log,
           Filename of pes log stored in AUTOMATION folder(NFS mount directory)
           If for some reason we are unable to xtail , then that procid and filename will be returned as null
 0 - Failure

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::pesLogStart(-test_case => "15804",-host_name => "VIPER",-nfs_mount => "/export/home/SonusNFS");

=item Author :

 H.Hamblin
 hhamblin@sonusnet.com

=back

=cut

sub pesLogStart {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "pesLogStart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub entering function.");
    my $ats_xtail_dir = "/ats/solaris_tools";
    my $nfs_mount = "/sonus/SonusNFS";
    my $psx_nfs_mount = "/export/home/SonusNFS";
    my (@result,$pid,$procid,@result1);
    my @retvalues;
    my ($peslog); # Log File name
  
    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -test_case -host_name/) { 
        unless ( $args{$_} ) { 
            $logger->error(__PACKAGE__ . ".$sub $_ required");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0; 
        } 
    }
    

    # Test shell as we need to use the correct shell cmd to
    # get the return value of commands being executed.
    my $shell;
    my @output = $conn->cmd( "echo \$shell");
    if (grep /csh/, @output) {
        $shell = "csh";
    } else {
        $shell = "ksh";
    }

    $logger->debug(__PACKAGE__ . "$sub Identified shell = '$shell'");

    $conn->prompt('/[\$%#>\?:] +$/');

    # Setting ats_xtail_dir
    $ats_xtail_dir = $args{-ats_xtail_dir} if ($args{-ats_xtail_dir});
    my $ats_xtail = $ats_xtail_dir . "/" . "xtail";

    # Setting nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});
   
    # Setting psx_nfs_mount
    $psx_nfs_mount = $args{-psx_nfs_mount} if ($args{-psx_nfs_mount}); 

    # Prepare timestamp format
    my $timestamp = `date \'\+\%F\_\%H\:\%M\:\%S\'`;
    chomp($timestamp);

    my @date = $conn->cmd("date \'\+\%m\%d\'");
    chomp($date[0]);    

    # Test if xtail exists in $ats_xtail_dir
    if (!(-e $ats_xtail)) {
        $logger->error(__PACKAGE__ . ".$sub $ats_xtail does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $ats_xtail exists");
    } # End if

    # Test if $nfs_mount exixts
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $nfs_mount exists");
    } # End if

    # Test if $psx_nfs_mount exists
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $psx_nfs_mount");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->error(__PACKAGE__ . "$sub NFS is not mounted in PSX machine");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 

    # Test if AUTOMATION directory exists in $nfs_mount
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $psx_nfs_mount/AUTOMATION");
    chomp($result[0]);
    
    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory does not exist");
        @result1 = $conn->cmd("mkdir $psx_nfs_mount/AUTOMATION");
        chomp($result1[0]);
        if ($result1[0] !~ /Failed to make directory/) {
            $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory created");
            my @result2 = $conn->cmd("chmod 777 $psx_nfs_mount/AUTOMATION");
            my @result3;
            if ($shell eq "csh") {
                @result3 = $conn->cmd("echo \$status");
            } else {
                @result3 = $conn->cmd("echo \$?");
            }
            if (($result2[0] =~ /can't access/) || ($result3[0] != 0)) {
                $logger->error(__PACKAGE__ . "$sub chmod for $psx_nfs_mount/AUTOMATION was not possible");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            } 
        } 
    } 

    # Test if xtail present in AUTOMATION directory else Copy xtail from $ats_xtail_dir to $nfs_mount/AUTOMATION
    @result = $conn->cmd("file -h $psx_nfs_mount/AUTOMATION/xtail");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub xtail does not exist in $psx_nfs_mount/AUTOMATION directory");
        if (system("cp -rf $ats_xtail $nfs_mount/AUTOMATION/")) {
            $logger->error(__PACKAGE__ . "$sub Unable to copy xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } 
        else {
            $logger->debug(__PACKAGE__ . "$sub Copied xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
        } # End if
    } 
    else {
        $logger->debug(__PACKAGE__ . "$sub xtail exists in $psx_nfs_mount/AUTOMATION directory");
    } # End if

    $conn->prompt('/[\$%#>\?:] +$/'); 


    # Ensure pes log is logging on the PSX by the following:
    $self->ssmgmtSequence(['14','3','1','6']);

    # Prepare $peslog name
    $peslog = join "_",$args{-test_case},"PSX","pesLog",uc($args{-host_name}),$timestamp;
    $peslog = join ".",$peslog,"log";

    $logger->debug(__PACKAGE__ . "$sub  $psx_nfs_mount/AUTOMATION/xtail pes.log > $psx_nfs_mount/AUTOMATION/$peslog ");
    @result = $conn->cmd("cd $self->{LOGPATH}");
    @result = $conn->cmd("$psx_nfs_mount/AUTOMATION/xtail pes.log > $psx_nfs_mount/AUTOMATION/$peslog &");
    chomp($result[0]);

    if ($shell eq "csh") {
        @result1 = $conn->cmd("echo \$status");
    } else {
        @result1 = $conn->cmd("echo \$?");
    }
    chomp($result1[0]);

    if ($result1[0] =~ /^0$/) {
        if ($result[0] =~ /\]/) {
            my @pid = split /\]/,$result[0]; 
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[0]) =~ s/^\s+//g;
            $procid = $result[0];
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for $peslog - process id is $procid");
        push @retvalues,$procid;    
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for pesLog,Process id set to null");
        push @retvalues,"null";
        # Setting pes logname to null as we couldn't start xtail.
        $peslog = "null";
    } # End if

    # Push filename of log file created into @retvalues
    push @retvalues,$peslog;

    $logger->debug(__PACKAGE__ . ".$sub leaving with returning array of: @retvalues.");
    return @retvalues; 

} # End sub pesLogStart


=head2 pipeLogStart()

 pipeLogStart method is used to start capture of pipe log per testcase in PSX. The name of the log file will be of the format <Testcase-id>_PSX_<psx hostname>_timestamp.log. Timestamp will be of format yyyymmdd_HH:MM:SS.log. 
 The mandatory arguments are test_case, host_name.
 The optional arguments are ats_xtail_dir, nfs_mount and psx_nfs_mount. 
 After using pipeLogStart ,use pipeLogStop function in the test script to kill the process(es).

NOTE :---> For log capture, tail process will fetch the logs and store in AUTOMATION folder in NFS mount directory in the PSX. If AUTOMATION directory is not present , it will be created.

=over

=item Assumptions made :

 It is assumed that NFS is mounted on the PSX machine.Default is set as /export/home/SonusNFS. If NFS is not mounted ,please mount it and then start the test script.

=item Arguments :

 -test_case
     specify testcase id for which log needs to be generated.
 -host_name
     specify the psx/gsx hostname
 -ats_xtail_dir
     This is an optional parameter to specify the ats location for copying the xtail file, default is /ats/bin
 -nfs_mount
     This is an optional parameter to specify the nfs directory from where subroutine is invoked,default is /sonus/SonusNFS
 -psx_nfs_mount
     This is an optional parameter to specify nfs mount directory within PSX ,default value is /export/home/SonusNFS

=item Return Values :

 Success - Return an array with following contents,
           Process id of pipe.log,
           Filename of pipe log stored in AUTOMATION folder(NFS mount directory)
           If for some reason we are unable to xtail , then that procid and filename will be returned as null
 0 - Failure

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::pipeLogStart(-test_case => "15804",-host_name => "VIPER",-nfs_mount => "/export/home/SonusNFS");

=item Author :

 H.Hamblin
 hhamblin@sonusnet.com

=back 

=cut 

sub pipeLogStart {
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "pipeLogStart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub entering function.");
    my $ats_xtail_dir = "/ats/solaris_tools";
    my $nfs_mount = "/sonus/SonusNFS";
    my $psx_nfs_mount = "/export/home/SonusNFS";
    my (@result,$pid,$procid,@result1);
    my @retvalues;
    my ($pipelog); # Log File name
  
    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -test_case -host_name/) { 
        unless ( $args{$_} ) { 
            $logger->error(__PACKAGE__ . ".$sub $_ required");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0; 
        } 
    }
    
    # Test shell as we need to use the correct shell cmd to
    # get the return value of commands being executed.
    my $shell;
    my @output = $conn->cmd( "echo \$shell");
    if (grep /csh/, @output) {
        $shell = "csh";
    } else {
        $shell = "ksh";
    }

    $logger->debug(__PACKAGE__ . "$sub Identified shell = '$shell'");

    $conn->prompt('/[\$%#>\?:] +$/');

    # Setting ats_xtail_dir
    $ats_xtail_dir = $args{-ats_xtail_dir} if ($args{-ats_xtail_dir});
    my $ats_xtail = $ats_xtail_dir . "/" . "xtail";

    # Setting nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});
   
    # Setting psx_nfs_mount
    $psx_nfs_mount = $args{-psx_nfs_mount} if ($args{-psx_nfs_mount}); 

    # Prepare timestamp format
    my $timestamp = `date \'\+\%F\_\%H\:\%M\:\%S\'`;
    chomp($timestamp);

    my @date = $conn->cmd("date \'\+\%m\%d\'");
    chomp($date[0]);    

    # Test if xtail exists in $ats_xtail_dir
    if (!(-e $ats_xtail)) {
        $logger->error(__PACKAGE__ . ".$sub $ats_xtail does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $ats_xtail exists");
    } # End if

    # Test if $nfs_mount exixts
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $nfs_mount exists");
    } # End if

    # Test if $psx_nfs_mount exists
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $psx_nfs_mount");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->error(__PACKAGE__ . "$sub NFS is not mounted in PSX machine");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    } 

    # Test if AUTOMATION directory exists in $nfs_mount
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $psx_nfs_mount/AUTOMATION");
    chomp($result[0]);
    
    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory does not exist");
        @result1 = $conn->cmd("mkdir $psx_nfs_mount/AUTOMATION");
        chomp($result1[0]);
        if ($result1[0] !~ /Failed to make directory/) {
            $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory created");
            my @result2 = $conn->cmd("chmod 777 $psx_nfs_mount/AUTOMATION");
            my @result3;
            if ($shell eq "csh") {
                @result3 = $conn->cmd("echo \$status");
            } else {
                @result3 = $conn->cmd("echo \$?");
            }
            if (($result2[0] =~ /can't access/) || ($result3[0] != 0)) {
                $logger->error(__PACKAGE__ . "$sub chmod for $psx_nfs_mount/AUTOMATION was not possible");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            } 
        } 
    } 

    # Test if xtail present in AUTOMATION directory else Copy xtail from $ats_xtail_dir to $nfs_mount/AUTOMATION
    @result = $conn->cmd("file -h $psx_nfs_mount/AUTOMATION/xtail");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub xtail does not exist in $psx_nfs_mount/AUTOMATION directory");
        if (system("cp -rf $ats_xtail $nfs_mount/AUTOMATION/")) {
            $logger->error(__PACKAGE__ . "$sub Unable to copy xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } 
        else {
            $logger->debug(__PACKAGE__ . "$sub Copied xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
        } # End if
    } 
    else {
        $logger->debug(__PACKAGE__ . "$sub xtail exists in $psx_nfs_mount/AUTOMATION directory");
    } # End if

    $conn->prompt('/[\$%#>\?:] +$/'); 

    # Prepare $pipelog name
    $conn->prompt('/[\$%#>\?:] +$/');
    $pipelog = join "_",$args{-test_case},"PSX","pipeLog",uc($args{-host_name}),$timestamp;
    $pipelog = join ".",$pipelog,"log";

    @result = $conn->cmd("$psx_nfs_mount/AUTOMATION/xtail pipe.log > $psx_nfs_mount/AUTOMATION/$pipelog &");
    chomp($result[0]);
    if ($shell eq "csh") {
        @result1 = $conn->cmd("echo \$status");
    } else {
        @result1 = $conn->cmd("echo \$?");
    }
    chomp($result1[0]);

    if ($result1[0] =~ /^0$/) {
        if ($result[0] =~ /\]/) {
            my @pid = split /\]/,$result[0];
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[0]) =~ s/^\s+//g;
            $procid = $result[0];
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for $pipelog - process id is $procid");
        push @retvalues,$procid;
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for pipeLog, Process id set to null");
        push @retvalues,"null";
        # Setting pipe logname to null as we couldn't start xtail.
        $pipelog = "null";
    } # End if

    # Push filename of log file created into @retvalues
    push @retvalues,$pipelog;
           
    $logger->debug(__PACKAGE__ . ".$sub leaving with returning array of: @retvalues.");
    return @retvalues; 
    
} # End sub pipeLogStart


=head2 pesLogStop()

 pesLogStop method is used to kill the tail process started by pesLogStart and copy the file from AUTOMATION folder in NFS mount directory to log directory specified by the user.
The mandatory arguments are -pid, -filename and -log_dir.

=over 

=item Arguments :

 -pid
    Process ID of xtail process for pes log 
 -filename
    Filename in AUTOMATION folder in NFS mount directory(as in pesLogStart)
 -log_dir
    local log directory where all the log files will be copied to
 -nfs_mount
    specify the nfs mount directory,default is /sonus/SonusNFS

=item Return Values :

 1-Success
 0-Failure

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::pesLogStop(-pid => "24761",-filename => "17461_PSX_pesLog_MERCURY_2008-02-19_13:11:47.log",-log_dir => "/home/hhamblin/Logs");

=item Author :

 H.Hamblin
 hhamblin@sonusnet.com

=back

=cut

sub pesLogStop {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "pesLogStop()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");

    my (@result);
    my $flag = 1; # Assume success
    $conn->prompt('/[\$%#>\?] +$/');
    
    #Test shell
    my $shell;
    my @output = $conn->cmd( "echo \$shell");
    if (grep /csh/, @output) {
        $shell = "csh";
    } else {
        $shell = "ksh";
    }

    $logger->debug(__PACKAGE__ . "$sub Identified shell = '$shell'");

    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -pid -filename -log_dir/) { 
        unless ( $args{$_} ) { 
            $logger->error(__PACKAGE__ . ".$sub $_ required"); 
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0; 
        } 
    }

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    # Test if $args{-log_dir} exists
    if (!(-e $args{-log_dir})) {
        $logger->error(__PACKAGE__ . ".$sub Directory $args{-logdir} does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    my $pes_log_pid = $args{-pid};
    my $pes_filename = $args{-filename};

    $conn->prompt('/[\$%#>\?:] +$/');    

    if ($pes_log_pid ne "null") {
        @result = $conn->cmd("ps -p $pes_log_pid");
        if ($shell eq "csh") {
            @result = $conn->cmd("echo \$status");
        } else {
            @result = $conn->cmd("echo \$?");
        }
        chomp($result[0]);
        if ($result[0] =~ /^0$/) {
            @result = $conn->cmd("kill -9 $pes_log_pid");
            if ($shell eq "csh") {
                @result = $conn->cmd("echo \$status");
            } else {
                @result = $conn->cmd("echo \$?");
            }
            chomp($result[0]);

            if ($result[0]) {
                $logger->error(__PACKAGE__ . ".$sub Process $pes_log_pid has not been killed");
                $flag = 0;
            } 
            else {
                $logger->debug(__PACKAGE__ . ".$sub Process $pes_log_pid has been killed");
            } # End if
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Process $pes_log_pid does not exist");
            $flag =0;
        } # End if
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Process id is null");
    } # End if

    if ($pes_filename ne "null" && ($pes_filename !~ /^\s*$/ )) {
        if (system("mv $nfs_mount/AUTOMATION/$pes_filename $args{-log_dir}/")) {
            $logger->error(__PACKAGE__ . ".$sub Move failed for $nfs_mount/AUTOMATION/$pes_filename to $args{-log_dir}");
            $flag = 0;
        } 
        else {
           $logger->debug(__PACKAGE__ . ".$sub File $nfs_mount/AUTOMATION/$pes_filename has been moved to $args{-log_dir}/");
        } # End if
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub File name is empty or null");
    } # End if

    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-$flag.");
    return $flag;
    
} # End pesLogStop


=head2 pipeLogStop()

 pipeLogStop method is used to kill the tail process started by pipeLogStart and copy the file from AUTOMATION folder in NFS mount directory to log directory specified by the user.
The mandatory arguments are -pid, -filename and -log_dir.

=over

=item Arguments :

 -pid
    Process ID of xtail process for pipe log 
 -filename
    Filename in AUTOMATION folder in NFS mount directory(as in pipeLogStart)
 -log_dir
    local log directory where all the log files will be copied to
 -nfs_mount
    specify the nfs mount directory,default is /sonus/SonusNFS

=item Return Values :

 1-Success
 0-Failure

=item Example :

 \$obj->SonusQA::PSX::PSXHELPER::pipeLogStop(-pid => "24761",-filename => "17461_PSX_pipeLog_MERCURY_2008-02-19_13:11:47.log",-log_dir => "/home/hhamblin/Logs");

=item Author 

 H.Hamblin
 hhamblin@sonusnet.com

=back

=cut

sub pipeLogStop {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "pipeLogStop()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");

    my (@result);
    my $flag = 1; # Assume success
    $conn->prompt('/[\$%#>\?] +$/');
    
    #Test shell
    my $shell;
    my @output = $conn->cmd( "echo \$shell");
    if (grep /csh/, @output) {
        $shell = "csh";
    } else {
        $shell = "ksh";
    }

    $logger->debug(__PACKAGE__ . "$sub Identified shell = '$shell'");

    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -pid -filename -log_dir/) { 
        unless ( $args{$_} ) { 
            $logger->error(__PACKAGE__ . ".$sub $_ required"); 
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0; 
        } 
    }

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    # Test if $args{-log_dir} exists
    if (!(-e $args{-log_dir})) {
        $logger->error(__PACKAGE__ . ".$sub Directory $args{-logdir} does not exist");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    my $pipe_log_pid = $args{-pid};
    my $pipe_filename = $args{-filename};

    $conn->prompt('/[\$%#>\?:] +$/');    

    if ($pipe_log_pid ne "null") {
        @result = $conn->cmd("ps -p $pipe_log_pid");
        if ($shell eq "csh") {
            @result = $conn->cmd("echo \$status");
        } else {
            @result = $conn->cmd("echo \$?");
        }
        chomp($result[0]);
        if ($result[0] =~ /^0$/) {
            @result = $conn->cmd("kill -9 $pipe_log_pid");
            if ($shell eq "csh") {
                @result = $conn->cmd("echo \$status");
            } else {
                @result = $conn->cmd("echo \$?");
            }
            chomp($result[0]);

            if ($result[0]) {
                $logger->error(__PACKAGE__ . ".$sub Process $pipe_log_pid has not been killed");
                $flag = 0;
            } 
            else {
                $logger->debug(__PACKAGE__ . ".$sub Process $pipe_log_pid has been killed");
            } # End if
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Process $pipe_log_pid does not exist");
            $flag =0;
        } # End if
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Process id is null");
    } # End if

    if ($pipe_filename ne "null" && ($pipe_filename !~ /^\s*$/ )) {
        if (system("mv $nfs_mount/AUTOMATION/$pipe_filename $args{-log_dir}/")) {
            $logger->error(__PACKAGE__ . ".$sub Move failed for $nfs_mount/AUTOMATION/$pipe_filename to $args{-log_dir}");
            $flag = 0;
        } 
        else {
           $logger->debug(__PACKAGE__ . ".$sub File $nfs_mount/AUTOMATION/$pipe_filename has been moved to $args{-log_dir}/");
        } # End if
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub File name is empty or null");
    } # End if

    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-$flag.");
    return $flag;
    
} # End pipeLogStop


=head2 set_loglevel()

This method shall enable the loglevel for various processes 
The mandatory parameters are -

$mgmt : mgmt name -> scpamgmt / sipemgmt / ssmgmt / pgkmgmt
$ref : array reference having the various selection inputs  

=over

=item Arguments :

$mgmt can hold one of the following values  :  ssmgmt / pgkmgmt / sipemgmt / scpamgmt
$ref must be initilaised as : $loglevel = ['14','1','3','5','0']
The values are in the order entered during manual selection of log level

=item Optional arguments :

	-validation_pattern => string need to be greped from log file.

	-validation_pattern => { 'SUA Trace' => 'ENABLED',
				'TCAP Trace' => 'DISABLED'}

=item Return Values :

0 : failure
1 : Success

=item Example :

        my $ssmgmt = ['14','1','3','5']
        my $log1 = "ssmgmt"
	my %args = (-validation_pattern => { 'SUA Trace' => 'ENABLED',
				             'TCAP Trace' => 'DISABLED'});

        or

        my %args = (-validation_pattern => { 'SUA Stack log mask' => '0xff',
                                             'TCAP Stack log mask' => '0x3'});
 $psxObj->set_loglevel($log1,$ssmgmt, %args)

=item Added by :

sangeetha <ssiddegowda@sonusnet.com>

Modified by Malc <mlashley@sonusnet.com> - old version didn't set {conn}->prompt before invoking cmd() method - which meant we had to wait for a timeout each time this method was called, since the subsequent call was to waitfor() simply set the prompt accordingly - and change cmd() to print().

Modified by Naresh <nanthoti@sonusnet.com> - to support JIRA Issue TOOLS-2499. removed the duplicate code from subrotines  ssmgmtSequence, scpamgmtSequence in PSX.pm and set_loglevel in PSXHELPER.pm and copied into the subroutine mgmtSequence in PSX.pm

=back 

=cut

sub set_loglevel {
        
   my ($self,$mgmt,$ref, %args) = @_;
   my $sub = "set_loglevel";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   unless($self->mgmtSequence($mgmt,$ref,%args)){
     if($self->{VERIFICATION_LOG_BACKUP}){
        $logger->warn(__PACKAGE__ . ". $sub revert the log file name from $self->{VERIFICATION_LOG}_back to  $self->{VERIFICATION_LOG}");
        $self->{conn}->cmd("mv $self->{VERIFICATION_LOG}_back $self->{VERIFICATION_LOG}");
     }
     $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
     return 0 ;
   }
   $logger->debug(__PACKAGE__ . ". $sub <-- Leaving Sub [1]");
   return 1;
}

=head2 remove_logs()

This method shall delete the PSX logs

The mandatory parameters are -


Array reference to the names of logs to be deleted
Ex : $log = ['pes','scpa','sipe',pipe'] or $log = ['pes']

=over

=item Arguments :

$log : Array reference

=item Return Values :

0 : failure
1 : Success

=item Example :

        $logs = ['pes','scpa','sipe',pipe'] 
        $psxObj->remove_logs($logs);

=item Added by :

sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub remove_logs {
        
my ($self,$log)=@_;
my $sub = "remove_logs ()";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
my @array = @$log;
if ($ENV{SHARE}) {
    $self->taillogs($log);
} else 
{
        unless($self->{conn}->cmd("cd $self->{LOGPATH}")){
        $logger->error(__PACKAGE__ . ". $sub  COULD NOT CHANGE TO PSX LOG DIR ");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
};
        
foreach(@array)
{
        my $cmd = "rm -rf ".$_."\.log";
        $logger->debug(__PACKAGE__ . ". $sub  REMOVING LOG : $_");
        unless ($self->{conn}->cmd($cmd)){
        $logger->error(__PACKAGE__ . ". $sub  FAILED TO REMOVE $_ LOG ");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
        };
       
}

my $cmd = "cd ../../";
unless ($self->{conn}->cmd($cmd)){
$logger->warn(__PACKAGE__ . ". $sub  FAILED TO REVERT DIR ");
};
}
return 1;

} # End remove_logs



=head2 CLEAR_LOGS()

This method shall initialise logging and delete the PSX logs
Used before testcase invocation in .pm files 

The mandatory parameters are 
None 

=over

=item Arguments :

None 

=item Return Values :

0 : failure
1 : Success

=item Example :

Internally used by the Log_Init function in Utils.pm
$psxObj->CLEAR_LOGS();

=item Added by :

sangeetha <ssiddegowda@sonusnet.com>

=back

=cut

sub CLEAR_LOGS {
my($self) = @_;
my $sub = "CLEAR_PSX_LOGS()";
my $logpath = $self->{LOGPATH}; 
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

$logger->debug(__PACKAGE__ . ".$sub Entering function");

my $ssmgmt = ['14','1','3','5','0'];
my $log1 = "ssmgmt";
unless ($self->set_loglevel($log1,$ssmgmt)){
        $logger->error(__PACKAGE__ . ".$sub FAILED TO SET ssmgmt logging ");
        return 0;
};

my $scpamgmt = ['1','4','6','3'];
my $log2 = "scpamgmt";
unless ($self->set_loglevel($log2,$scpamgmt)){
       $logger->error(__PACKAGE__ . ".$sub FAILED TO SET scpamgmtlogging ");
       return 0;
};

my $sipemgmt = ['1','3','5'];
my $log3 = "sipemgmt";
unless($self->set_loglevel($log3,$sipemgmt)){
        $logger->error(__PACKAGE__ . ".$sub FAILED TO SET sipemgmt logging ");
        return 0;
};

#my $pgkmgmt = ['4'];
#my $log4 = "pgkmgmt";
#unless($self->set_loglevel($log4,$pgkmgmt)){
#        $logger->error(__PACKAGE__ . ".$sub FAILED TO SET pgkmgmt logging ");
#        return 0;
#};

my $logs =['pes','scpa','sipe','pipe','pgk'];
unless ($self->remove_logs($logs)){
        $logger->error(__PACKAGE__ . ".$sub FAILED TO REMOVE LOGS");
        return 0;
};

return 1;

}# END CLEAR_LOGS

#---------log check 

sub search_pattern {
    my ($self,$patterns,$log,$count) = @_;

    my $sub = 'search_pattern()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");


    unless($self->{conn}->cmd("cd $self->{LOGPATH}")){
        $logger->error(__PACKAGE__ . ". $sub  COULD NOT CHANGE TO PSX LOG DIR ");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    };

    my $file_orig;
    if ($ENV{SHARE}) {
        $file_orig = "$log"."-".$ENV{PSX_LOG}."\.log" unless ($log =~ /\.log/);
    } else {
        $file_orig = $log.".log" unless ($log =~ /\.log/);
    }

    my $file = $file_orig.'new';
    $self->executeCmd("dos2unix -f -n $file_orig $file");

    my $ret = 1;
    foreach(@$patterns){
        my $cmd1 = "grep "."\"$_\""." $file \| wc \-l";
        my @find = $self->executeCmd($cmd1);
        my $string = $find[0];
        $string =~ s/\s//g;
        $logger->debug(__PACKAGE__ . ".$sub Number of occurences of the string $_ in $file is $string");

        unless($string){
            $logger->warn(__PACKAGE__ . ".$sub No OCCURENCE of $_ in $file...Waiting 5 seconds");
            sleep(5);
            @find = $self->executeCmd($cmd1);
            $string = $find[0];
            $string =~ s/\s//g;
            $logger->debug(__PACKAGE__ . ".$sub Number of occurences of the string $_ in $file is $string");
            unless($string){
                $logger->error(__PACKAGE__ . ".$sub No OCCURENCE of $_ in $file even after waiting for 5 seconds");
                $ret = 0;
                last;
            }
        }

        unless($string =~ /^\d+$/){
            $logger->error(__PACKAGE__ . ".$sub While checking the pattern $_ in $file, Got an error ".Dumper(\@find));
            $ret = 0;
            last;
        }

        if (defined $count and $count) {
            if ($string == $count) {
                $logger->info(__PACKAGE__ . ".$sub  Number of occurences of the string $_ in $file is $string is matches to required count -> $count");
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub  Number of occurences of the string $_ in $file is $string is does not matches to required count -> $count");
                $ret = 0;
                last;
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$ret]");
    return $ret;
} 

sub executeCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".executeCmd");
  my(@cmdResults,$timestamp);
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  unless (@cmdResults = $self->{conn}->cmd($cmd)) {
    # Section for commnad execution error handling -  hangs, etc can be noted here.
    $logger->warn(__PACKAGE__ . ".executeCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".executeCmd   ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".executeCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".executeCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd GBL CMD ERROR - EXITING");
  };
  chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".executeCmd  CMD RESULTS : @cmdResults");
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  $timestamp = $self->getTime();
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  return @cmdResults;
}

=head2 clearPSXLog()

This subroutine empties the pes.log file

The mandatory parameters are 
None 

=over

=item Arguments :

None 

=item Return Values :

0 : failure
1 : Success

=item Example :

$psxObj->clearPSXLog();

=item Added by :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back 

=cut


sub clearPSXLog {
   my ($self) = @_;
   my $sub = "clearPSXLog()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub CLEANING PSX LOG");

   my $path = $self->{LOGPATH} . "/pes.log";

   $self->{conn}->cmd(">$path");

   $logger->info(__PACKAGE__ . ".$sub pes.log file emptied");

   my @lsValue = $self->{conn}->cmd("ls -l $path");

   $logger->info(__PACKAGE__ . ".$sub ls -l => " . Dumper(@lsValue));

   return 1;
}

=head2 setPSXLogLevel()

This subroutine empties the pes.log file

The mandatory parameters are 
None 

=over 

=item Arguments :

None 

=item Return Values :

0 : failure
1 : Success

=item Example :

$psxObj->setPSXLogLevel();

=item Added by :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back 

=cut

sub setPSXLogLevel {
   my ($self) = @_;
   my $sub = "setPSXLogLevel()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub Resetting the PSX LOG level");

   my $ssmgmt = ['14','1','3','5','0'];
   my $log1 = "ssmgmt";

   $self->set_loglevel($log1,$ssmgmt);

   return 1;
}

=head2 getPSXLog()

   This subroutine gets the log data from the PSX

=over

=item Arguments :

   Mandatory :
   -testId      => test case id
   -logDir      => Logs are stored in this directory
   -logType     => Which type of PSX log

   Optional :
   -variant     => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
   -timeStamp   => Time stamp
                   Default => "00000000-000000"

=item Return Values :

   0       - if file is not copied
   (@arr)  - log file Names

=item Example :

   $psx_obj->getPSXLog(-testId     => $testId,
                       -logDir     => $log_dir,
                       -logType    => ['scpa', 'pes']);

   $psx_obj->getPSXLog(-testId     => $testId,
                       -logDir     => $log_dir,
                       -logType    => ['scpa', 'pes'],
                       -variant    => "ANSI",
                       -timeStamp  => "20101005-080937");

=item Author :

   Susanth Sukumaran (ssukumaran@sonusnet.com)
   Sumitha Reddy(sureddy@sonusnet.com)
   Rodrigues, Kevin (krodrigues@sonusnet.com)

=back 

=cut

sub getPSXLog {
   my ($self, %args) = @_;
   my $sub = "getPSXLog()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub RETRIEVING PSX LOG");
   # Set default values before args are processed
   my %a = ( -variant   => "NONE",
             -timeStamp => "00000000-000000");

   my $timeout = 240;
   my $file_transfer_status;
   my @filelist;
   my $file_name;
   my $remoteFileName;
   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   unless (logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a )) {
       $logger->error(__PACKAGE__ . ".$sub Problem printing argument information via logSubInfo() function.");
       return 0;
   }

   my @array;
   my $to_Dir;

   if(defined ($a{-logType})) {
      @array = @{$a{-logType}};
   } else {
      $logger->error(__PACKAGE__ . ".$sub -logType is not defined");
      return 0;
   }
   if(defined ($a{-logDir})) {
      $to_Dir = $a{-logDir};
   } else {
      $logger->error(__PACKAGE__ . ".$sub -logDir is not defined");
      return 0;
   }


   # TMS Data
   my $root_password  = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
   my $ssuser_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
   my $psxIp           = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} || $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
   my $psxName         = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
   


   unless ($psxIp) {
      $logger->error(__PACKAGE__ . ".$sub PSX IP is not defined in TMS");
      return 0;
   }

   unless ($psxName) {
      $logger->error(__PACKAGE__ . ".$sub PSX name is not defined in TMS");
      return 0;
   }
   my %scpArgs;   
     $scpArgs{-hostip}        = "$self->{OBJ_HOST}";
     $scpArgs{-identity_file} = $self->{OBJ_KEY_FILE};
     if($self->{CLOUD_PSX}){
       $scpArgs{-hostuser}   = "ssuser";
       unless($ssuser_password){
         $logger->error(__PACKAGE__ . ".$sub SSUSER password is not defined in TMS");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
       }
       $scpArgs{-hostpasswd} = $ssuser_password;
     }
     else{
       $scpArgs{-hostuser}   = "root";
       unless($root_password){
         $logger->error(__PACKAGE__ . ".$sub ROOT password is not defined in TMS");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
       }       
       $scpArgs{-hostpasswd} = $root_password;
     }
     
   $logger->debug(__PACKAGE__ . ".$sub Connected to PSX");
   if ($ENV{SHARE}) {
          $self->stopPSXLog();
   }
   # Get the log files
   foreach(@array){
      my $logName = uc $_;
      my $newPsxName = uc $psxName;
	
      # Form the file names
      my $localFileName = "$to_Dir/" . "$a{-testId}-$self->{'VERSION'}-$a{-variant}-$a{-timeStamp}-PSX-$newPsxName-$logName.log";
      if ($ENV{SHARE}) {
          $remoteFileName = "$self->{LOGPATH}/". "$_"."-".$ENV{PSX_LOG}.".log";
      } else {
          $remoteFileName = "$self->{LOGPATH}/". "$_.log";
      };

      push (@filelist, $localFileName);

      $logger->debug(__PACKAGE__ . ".$sub Transferring \'$remoteFileName\' to \'$localFileName\'");

      # Transfer File
      $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$remoteFileName;
      $scpArgs{-destinationFilePath} = $localFileName;
      unless(&SonusQA::Base::secureCopy(%scpArgs)){
         $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
      }
      $logger->debug(__PACKAGE__.".$sub Successfully $_ logs are Transfered to ATS ");
   }  
   # return the transferred file list for further processing
   return @filelist;
}

=head2 printLogFile()

This subroutine prints a log file

The mandatory parameters are 
None 

=over

=item Arguments :

$fileName   - Log file name
$data       - Log Data
$logDir     - Local log dir

=item Return Values :

0 : failure
1 : Success

=item Example :

$psxObj->printLogFile();

=item Added by :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back 

=cut

sub printLogFile {
   my ($self, $fileName,$logDir,@data) = @_;
   my $sub = "printLogFile()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info(__PACKAGE__ . ".$sub printing the log data");

   my @new_file=@data;
   my $file_name=$logDir . "/" . $fileName;

   $logger->info(__PACKAGE__ . ".$sub => $logDir, $file_name");

   foreach (@data) {
      open (FH, ">>$file_name") or print "can't open '$file_name': $!";
      print FH $_;
      print FH "\n";
      close FH;
   }
   sleep 5;
  	$logger->info(__PACKAGE__ . ".$sub COMPLETED printing the FILE");
   return 1;
}

=head2 startPSXTrace()

This subroutine starts the traces on the PSX

The mandatory parameters are 
None

=over

=item Arguments :

$test_id - test ID

=item Return Values :

0 : failure
n : PID of the snoop trace

=item Example :

$psxObj->startPSXTrace($test_id);

=item Added by :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back 

=cut

sub startPSXTrace {
   my ($self, $test_id)=@_;
   my $sub = "startPSXTrace()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub Start Capturing the PSX Trace");

   my $cmd1 = "snoop -d bge0 > $test_id.cap &";
   my @cmdresults = $self->{conn}->cmd("$cmd1");

   sleep(10);

   $logger->info(__PACKAGE__ . ".$sub Capturing the PSX Trace Started");
   $logger->info(__PACKAGE__ . ".$sub  PID info : " . Dumper ( @cmdresults ));

   my $pid = 0;
   foreach(@cmdresults)
   {
      chomp();
      if (m/^\[\d+\]\s+(\d+)/) {
         $pid = $1;
         $logger->info(__PACKAGE__ . ".$sub Captured the PID=$pid of the SNOOP command");
         if ($pid eq 0 || $pid eq '') {
           return 0;
         }
      }
   }

   if($pid eq 0) {
      sleep 1;
      my $cmdString = "ps -aef | grep snoop";
      $logger->debug(__PACKAGE__ . ".$sub executing $cmdString command");

      my @cmdresults = $self->{conn}->cmd("$cmdString");

      my $stringFour;

      $logger->debug(__PACKAGE__ . ".$sub getting the PID. \n@cmdresults ");
      foreach $stringFour (@cmdresults) {
         chomp();
         my $searchString = "snoop";

         if($stringFour =~ /$searchString/) {
            if($stringFour =~ /\S+\s+(\d+)/) {
               $pid = $1;
               $logger->info(__PACKAGE__ . ".$sub Captured the PID=$pid of the tshark command");
               last;
            } else {
              $logger->error(__PACKAGE__ . ".$sub Captured the PID=$pid of the tshark command");
              return 0;
            }
         }
      }
   }

   $logger->info(__PACKAGE__ . ".$sub Returned the PID=$pid of the SNOOP command");
   return($pid);
}

=head2 stopPSXTrace()

This subroutine starts the traces on the PSX

The mandatory parameters are 
None 

=over

=item Arguments :

$test_id - test ID
$pid_name - PID name
$logDir - Log directory

=item Return Values :

0 : failure
n : PID of the snoop trace

=item Example :

$psxObj->stopPSXTrace($pid_name,$test_id,$logDir);

=item Added by :

Avinash Chandrashekar (achandrashekar@sonusnet.com)
Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub stopPSXTrace {
   my ($self, $pid_name,$test_id, $logDir)=@_;
   my $sub = "stopPSXTrace()";

   my $cmd1="kill -9 $pid_name";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub Stop Capturing the PSX Trace");

   $logger->info(__PACKAGE__ . ".$sub $pid_name : $test_id :  $logDir ");

   if ($pid_name eq 0)
   {
      $logger->info(__PACKAGE__ . ".$sub Not Able to retrieve the PID...The Process has become LANGLEY");
      return 0;
   }

   sleep 4;
   $self->{conn}->cmd("$cmd1");
   sleep 8;

   $logger->info(__PACKAGE__ . ".$sub Stopped the PSX Trace");

   #Return the Log File
   my $path = "/export/home/ssuser/$test_id.cap";
   my @psxlog = $self->getLog($path);

   my $new_test_id = $test_id . ".cap";

   $self->printLogFile("$new_test_id",@psxlog,$logDir);
   $logger->info(__PACKAGE__ . ".$sub Log file stored under psxlogs");
   return 1;
}

=head1 configurePSXFromDump()

This subroutine configures PSX from a dump file

=over

=item Arguments :

   The mandatory parameters are
      -dumpFileName => Dump file name
      -localDir     => Local directory

   The optional parametersare
      -dbImportTimeout => Specify time in seconds if 'import sonusdb' is taking more time. Default timeout is 900 seconds i.e. 15 minutes
      -dbUpdateTimeout => Specify time in seconds if 'Updatedb' is taking more time. Default timeout is 1800 seconds i.e. 30 minutes 
      -ConfigureTimeout => Specify time in seconds if 'PSXConfigure.pl' is taking more time. Default timeout is 3600 seconds i.e. 1 hour (required only when PSX version is greater than 09.02)

=item Return Values :

   0 : failure
   1 : Success

=item Example :

   $psxObj->configurePSXFromDump(-dumpFileName => $dumpFileName,
                                 -localDir     => $localDir);

   $psxObj->configurePSXFromDump(-dumpFileName    => $dumpFileName,
                                 -localDir        => $localDir,
                                 -dbImportTimeout => 1000);

   $psxObj->configurePSXFromDump(-dumpFileName    => $dumpFileName,
                                 -localDir        => $localDir,
                                 -dbImportTimeout => 1000,
                                 -dbUpdateTimeout => 2000);
=item Version greater than 09.02:

    $psxObj->configurePSXFromDump(-dumpFileName => $dumpFileName,
                                  -localDir     => $localDir
                                  -ConfigureTimeout => 172800 );


=item Added by :

   Rodrigues, Kevin (krodrigues@sonusnet.com)
   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub configurePSXFromDump() {
    my ($self, %args) = @_;
    my $sub = "configurePSXFromDump()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my %a;
    my @cmdResults;
    my ($prematch, $match)=("","");
    my $cmdString ;

    # get the arguments
    while ( my ($key, $value) = each %args ) { $a{$key} = $value }; 

    # get the required informa tion from TMS
    my $psxIPAddress    = $a{-ip} || $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} || $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
    my $psxUserName     = $a{-userid} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} || 'ssuser';
    my $psxUserPassword = $a{-passwd} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} || 'ssuser';
    my $psxRootPassword = $a{-rootpasswd} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD} || 'sonus';
    my $psxKeyFile = $a{-key} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{KEY_FILE};
    my $fullFileName = "/tmp/" . $a{-dumpFileName}; #TOOLS-71552
    my $localFileName = $a{-localDir} . "/" . $a{-dumpFileName};
 
    # transfer the file

    my %scpArgs;
    $scpArgs{-hostip}              = $psxIPAddress;
    $scpArgs{-hostuser}            = $psxUserName;
    $scpArgs{-hostpasswd}          = $psxUserPassword unless ( $psxKeyFile );
    $scpArgs{-identity_file}       = $psxKeyFile if ( $psxKeyFile );
    $scpArgs{-scpPort}             = 22;
    $scpArgs{-sourceFilePath}      = $localFileName;
    $scpArgs{-destinationFilePath} = $scpArgs{-hostip} . ':' . "$fullFileName";

    $logger->debug(__PACKAGE__ . ".$sub: \%scpArgs ". Dumper(\%scpArgs));

    unless ( &SonusQA::Base::secureCopy(%scpArgs) ) {
        $logger->error(__PACKAGE__ . ".$sub: SCP failed to copy the files" );
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub. [0]" );
        return 0;
    }
    sleep 5;
    $logger->debug(__PACKAGE__ . ".$sub:  file $localFileName transfered to \($psxIPAddress\) PSX");
 
    $logger->debug(__PACKAGE__ . ".$sub:  file \'$localFileName\' transfered  to PSX \($psxIPAddress\) dir \'/export/home/ssuser/SOFTSWITCH/SQL/\'.");

 
    # stop softswitch
    unless ( $self->startStopSoftSwitch(0) ){
        $logger->error(__PACKAGE__ . "$sub: failed to stop PSX softswitch " );
        return 0;
    }
    $logger->info(__PACKAGE__ . "$sub: Successfully Stopped the PSX softswitch" );
    
    $logger->debug(__PACKAGE__ . ".$sub: Sleeping for 10s");
    sleep 10;
    
    if(SonusQA::Utils::greaterThanVersion($self->{VERSION}, 'V09.02.000')){ 
        my $ConfigureTimeout = $a{-ConfigureTimeout} || 3600;
        $logger->debug(__PACKAGE__ . ".$sub The Timeout for configure PSX from Dump is $ConfigureTimeout seconds ");

        #login as root
        unless ( $self->enterRootSessionViaSU() ) {
            $logger->error(__PACKAGE__ . " : Could not enter root session" );
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
        
        $logger->debug(__PACKAGE__ . ".$sub: Executing 'chmod 755 $fullFileName'");
        unless($self->execShellCmd("chmod 755 $fullFileName")){
            $logger->error(__PACKAGE__ . " :.$sub: failed to execute chmod 755 $fullFileName");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        my $cmdString1 = "cd /export/home/ssuser/SOFTSWITCH/BIN/";
        my $cmdString2 = "./PSXConfigure.pl -dbbackupfile $fullFileName";

        $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString1 on PSX");
        unless($self->execShellCmd($cmdString1)){
            $logger->error(__PACKAGE__ . " :.$sub: failed to execute '$cmdString1'");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString2 on PSX");
        $self->{conn}->print( $cmdString2);

        if(SonusQA::Utils::greaterThanVersion($self->{VERSION}, 'V12.00.000')){ 
            my $counter = 1;
                
            while ($prematch !~ /PSX configure completed successfully./){
                unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user system..... :/',
                                                                    -match => '/\#/',
                                                                    -match     => $self->{PROMPT},
                                                                   -errmode => "return",
                                                                   -timeout => $ConfigureTimeout)){
                    $logger->error(__PACKAGE__ . ". $sub unable to get required prompt");
                    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                    $self->leaveRootSession();
                    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
                    $counter = 0;
                    last;
                }

                $logger->debug(__PACKAGE__ . ".$sub COunter = $counter ## Prematch : $prematch ## Match : $match ");
                $counter++;

                if(($match =~ /Enter new password for DB user system..... :/)){
                    $logger->debug(__PACKAGE__ . ".$sub: Executing ENTER on PSX");
                    $self->{conn}->print('');
                }
            }
            return 0 unless($counter);
            $logger->debug(__PACKAGE__ . ".$sub PSX configure completed successfully with $fullFileName ");
        }
        else{
            $logger->debug(__PACKAGE__ . ".$sub sleeping $ConfigureTimeout");
            sleep $ConfigureTimeout; 
            foreach ( 1..3 ) {
                $self->{conn}->print("\cM");
                $logger->debug(__PACKAGE__ . ".$sub: Sent Ctrl-M ($_), sleeping 5s");
                sleep(5);
            }
        }
        
        my %arg = (
                        -obj => $self,
                        -wait => 60,
                        -loop => 30,
                        -pass_phrase => 'Completed upgrading PSX DB',
                        -fail_phrase => 'Failed upgrading PSX DB',
                        -log => "/export/home/ssuser/SOFTSWITCH/BIN/PSXIUC.log",
                   );

        my ($checkStatusResult, $checkStatusCmdResult) = SonusQA::ATSHELPER::checkStatus( \%arg );
        $checkStatusResult = 0 if ( $checkStatusResult == -1 );
        $logger->info(__PACKAGE__ . " : Successfully configured PSX with $fullFileName" ) if ( $checkStatusResult == 1 );
        $logger->error(__PACKAGE__ . " : Failed in configuring PSX with $fullFileName".Dumper($checkStatusCmdResult)) if ( $checkStatusResult == 0 );

        # remove the file it already exists
        $cmdString = "rm -f " . $fullFileName;
        $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
        unless($self->execShellCmd($cmdString)){
            $logger->error(__PACKAGE__ . " :.$sub: failed to execute '$cmdString'");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }

        # Leaving root session
        unless ( $self->leaveRootSession()) {
            $logger->error(__PACKAGE__ . " : Could not leave the root session");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub: Sleeping for 10s");
        sleep 10;

        #start softswitch
        unless ( $self->startStopSoftSwitch(1) ){
            $logger->error(__PACKAGE__ . "$sub: failed to start PSX softswitch " );
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
        $logger->info(__PACKAGE__ . "$sub:Successfully Started the PSX softswitch" );
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$checkStatusResult]");
        
        return $checkStatusResult;
   }

   my $dumpName = $a{-dumpFileName};
   $dumpName =~ s/\.gz//g;
   my $fullDumpName = "/export/home/ssuser/SOFTSWITCH/SQL/" . $dumpName;

   # remove the dump file name if it is already exists
   $cmdString = "rm -f " . $fullDumpName;

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
   $self->execCmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub: cmd results : @{$self->{CMDRESULTS}}");

   # execute gunzip for the file
   $cmdString = "gunzip " . $fullFileName;

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
   $self->execCmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub: cmd results : @{$self->{CMDRESULTS}}");

   # Ensure the SQL dump is present in PSX in the path
   # cd /export/home/ssuser/SOFTSWITCH/BIN
   # Import dmp file
   # cd /export/home/ssuser/SOFTSWITCH/SQL
   # ./import sonusdba <dmpfilename>

   $cmdString = "cd /export/home/ssuser/SOFTSWITCH/SQL/";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   $self->execCmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub: cmd results : @{$self->{CMDRESULTS}}");

   $cmdString = "./import sonusdba $fullDumpName";
   # Do you want to drop the existing objects in the database [y|Y,n|N] ? 
   my $prompt;
   my $prompt2 = '/\?/';

   # Be sure to restore this from any place you may add a 'return'...
   my $prevPrompt = $self->{conn}->prompt($prompt2);

   # requires a lot of time. So increase the timeout
   my $oldTimeout = $self->{DEFAULTTIMEOUT};

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   $self->{conn}->print("$cmdString");

   ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt2,
                                             -errmode => "return",
                                             -timeout => $self->{DEFAULTTIMEOUT}) or do {
      $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");

      $self->{conn}->prompt($prevPrompt);
      return 0;
   };

   $logger->debug(__PACKAGE__ . ".$sub: Prematch : $prematch \n Match : $match");

   $logger->debug(__PACKAGE__ . ".$sub: Reverting Back The Prompt:-> $prevPrompt");

   $self->{conn}->prompt($prevPrompt);

   $cmdString = "y";

   if (defined $a{-dbImportTimeout}) {
       $self->{DEFAULTTIMEOUT} = $a{-dbImportTimeout};
   } else {
       # worst case 15minutes??
       $self->{DEFAULTTIMEOUT} = 15 * 60;
   }

   my $timestamp = $self->getTime();

   @cmdResults = $self->{conn}->cmd(String => $cmdString, Timeout => $self->{DEFAULTTIMEOUT} );
   $logger->debug(__PACKAGE__ . ".$sub ************************** \n @cmdResults \n\n ************************** ") ;

   chomp(@cmdResults);
   @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
   push(@{$self->{CMDRESULTS}},@cmdResults);
   push(@{$self->{HISTORY}},"$timestamp :: $cmdString");

   $self->{DEFAULTTIMEOUT} = $oldTimeout;

   # check the command completed successfully
   my $cmdPassed = 0;
   foreach(@cmdResults) {
      if(m/Import terminated successfully/i){
        $cmdPassed = 1;
        last;
      }
   }

   unless($cmdPassed) {
       $logger->error(__PACKAGE__ . ".$sub Import command failed");
       $logger->debug(__PACKAGE__ . ".$sub Leaving sub[$cmdPassed]");
       return 0;
   }

   #su  -
   #password : sonus
   #./Updatedb

   # get a root user session
   # Open a session for SFTP

   my $timeout = '';

   if (defined $a{-dbUpdateTimeout}) {
       $timeout = $a{-dbUpdateTimeout};
   } else {
       $timeout = 30 * 60;
   }
   unless ($self->enterRootSessionViaSU()){
        $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
        return 0;
    }

   # change the directory
   $cmdString = "cd /export/home/ssuser/SOFTSWITCH/SQL/";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   @cmdResults = $self->{conn}->cmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub: cmd results : @cmdResults");

   $cmdString = "./UpdateDb";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   # Be sure to restore this from any place you may add a 'return'...
   # Enter Country ID (default:1 for US )(default:1).................. :
   # Perform a database backup ( Y|y|N|n )?(default:Y)................ :
   # Please confirm values (Y|y|N|n) ....y
   $prompt2 = '/Please confirm values \(Y\|y\|N\|n\) \.*/';
   my $prompt3 = '/Enter Country ID \(default:1 for US \)\(default:1\)\.*/';
   my $prompt4 = '/Perform a database backup \( Y\|y\|N\|n \)\?\(default:Y\)\.*/';

   $prevPrompt = $self->{conn}->prompt($prompt2);

   @cmdResults = $self->{conn}->print( $cmdString);

    do {
      ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt2,
                                                           -match => $prompt3,
                                                           -match => $prompt4,
                                                           -errmode => "return",
                                                           -timeout => 120) or do {
         $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
         $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         $self->leaveRootSession();
         $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
         return 0;
    };

    $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");

    if(($match =~ /Enter Country ID/) or
        ($match =~ /Perform a database backup/)) {
           $cmdString = "\n";
           $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
           @cmdResults = $self->{conn}->print( $cmdString);
        }
    } while ($match !~ /Please confirm values/);

    $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");

    $cmdString = "y";

    $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

    $prompt2 = '/\#/';

    $prevPrompt = $self->{conn}->prompt($prompt2);

    my @cmdResultsNext = $self->{conn}->cmd(String => $cmdString, Timeout => $timeout);

    $logger->debug(__PACKAGE__ . ".$sub ************************** \n @cmdResultsNext \n\n ************************** ") ;

    # check the command completed successfully
    $cmdPassed = 0;
    foreach(@cmdResultsNext) {
       if(m/Configuring database for Auto Start and Auto Stop/i){
           $cmdPassed = 1;
           # Start Soft Switch
	   # su - ssuser
	   # start.ssoftswitch

           $cmdString = "/export/home/ssuser/SOFTSWITCH/BIN/start.ssoftswitch";
 	   @cmdResults = $self->execCmd("$cmdString");
           last;
       }
    }

    unless($cmdPassed) {
         $logger->error(__PACKAGE__ . ".$sub UpdateDb command failed");
    }
   
    $logger->debug(__PACKAGE__ . ".$sub ************************** \n @cmdResults \n\n ************************** ") ;
    
    unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$cmdPassed]");

    return $cmdPassed;
}

=head1 checkCore()

This subroutine checks for core file in PSX. If core file is present, the file is renamed with the test case ID

=over

=item Arguments :

   The mandatory parameters are
      -testCaseID   => Test case ID

=item Return Values :

   -1 : Error in finding if core files have been generated
   0  : No core files found
   m  : Number of core files found

=item Example :

   $psxObj->checkCore(-testCaseID => $testId);

=item Added by :

   Rodrigues, Kevin (krodrigues@sonusnet.com)
   Susanth Sukumaran (ssukumaran@sonusnet.com)

=item Modified by:

   Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back 

=cut

sub checkCore {
   my ($self, %args) = @_;
   my $sub = "checkCore()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my ($cmdString,@cmdResults);

   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value };
   unless ($self->enterRootSessionViaSU()){
        $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
        return 0;
    }
   
   $self->{conn}->cmd('unalias ls');
   # get the core file names
   $cmdString = "ls -1 $self->{coreDirPath}/core*";
   $logger->debug(__PACKAGE__ . ".$sub executing command $cmdString");

   my @coreFiles = $self->{conn}->cmd("$cmdString");
   $logger->debug(__PACKAGE__ . ".$sub ***** \n @coreFiles \n\n ******* ") ;
   my $retval = 1;
   foreach(@coreFiles) {
      if(m/No such file or directory/i) {
         $logger->info(__PACKAGE__ . ".$sub No cores found");
         $retval=0;
         last;
      }
   }
   unless($retval){
   $self->leaveRootSession();
   $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
   return 0;
   }

   # Get the number of core files
   my $numcore = $#coreFiles + 1;
   $logger->info(__PACKAGE__ . ".$sub Number of cores in PSX is $numcore");

   my $cmd;

   # Move all core files
   foreach (@coreFiles) {
      if( /$cmdString/ ) {
         #skip the first line if its the command
         next;
      }
      my $core_timer = 0;
      chomp($_);
      my $file_name = $_;

      # wait till core file gets generated full
      while ($core_timer < 120) {
         # get the file size
         $cmd = "ls -l $file_name";

         my @fileDetail = $self->{conn}->cmd($cmd);
         $logger->error(__PACKAGE__ . ".$sub @fileDetail");

         my $fileInfo;
         #start_size of the core file
         my $start_file_size;

         foreach $fileInfo (@fileDetail) {
            if( $fileInfo =~ /$cmd/ ) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;
            $start_file_size = $1;
         }
         $logger->debug(__PACKAGE__ . ".$sub Start File size of core file $file_name is $start_file_size");

         sleep(5);
         $core_timer = $core_timer + 5;

         #end_size of the core file;
         my $end_file_size;
         @fileDetail = $self->{conn}->cmd($cmd);

         foreach $fileInfo (@fileDetail) {
            if( $fileInfo =~ /$cmd/ ) {
               next;
            }
            $fileInfo =~ m/\S+\s+\d+\s+\S+\s+\S+\s+(\d+).*/;

            $end_file_size = $1;
         }

         $logger->debug(__PACKAGE__ . ".$sub End File size of core file $file_name is $end_file_size");

         if ($start_file_size == $end_file_size) {
            $file_name =~ s/$self->{coreDirPath}\///g;
            my $name = join "_",$args{-testCaseID},$file_name;

            # Rename the core to filename with testcase specified
            $cmd = "mv $self->{coreDirPath}/$file_name $self->{coreDirPath}/$name";
            my @retCode = $self->{conn}->cmd($cmd);
            $logger->info(__PACKAGE__ . ".$sub Core found in $self->{coreDirPath}/$name");
            last;
         }
      }
   }
	unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
    }

   return $numcore;
}

=head2 runInstallDb()

This subroutine runs install DB in PSX

=over

=item Arguments :

    Mandatory:
        None

    Optional :
        -InstallDbTimeout => Specify time in seconds if 'InstallDB' is taking more time. Default timeout is 3600 seconds i.e. 1 hour (required only when PSX version is greater than 09.02)   

=item Return Values :

   0 : failure
   1 : Success

=item Example :

   $psxObj->runIntallDb();

   $psxObj->runIntallDb(-InstallDbTimeout => 172800);

=item Added by :

   Rodrigues, Kevin (krodrigues@sonusnet.com)
   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub runIntallDb() {
   my ($self, %args) = @_;
   my $sub = "runIntallDb()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value };

   # Ensure the SQL dump is present in PSX in the path
   # cd /export/home/ssuser/SOFTSWITCH/BIN

   unless ($self->stopOracleDB()) {
       $logger->error("$sub: Unable to stop the DB");
       return 0;
   }

   $logger->debug("$sub: Successfully stoped the DB");

   # stop softswitch
   unless ( $self->startStopSoftSwitch(0) ){
       $logger->error(__PACKAGE__ . "$sub: failed to stop PSX softswitch " );
       return 0;
   }
   $logger->debug(__PACKAGE__ . "$sub: Successfully Stopped the PSX softswitch" );

   sleep 10;

   # To get the version

   $self->{VERSION} =~ m/V([0-9]+\.[0-9]+)\.([0-9ABCR]+)/i;

   if ($1 >= "09.02") {

=pod 

  *********The "./InstallDb" procedure is not recommended anymore [TOOLS-4456]*********
       my $InstallDbTimeout;

       if (defined ($a{-InstallDbTimeout})) {
           $InstallDbTimeout = $a{-InstallDbTimeout} ;
       }
       else {
           #Default Timeout
           $InstallDbTimeout = 3600;
       }
       $logger->info(__PACKAGE__ . ".$sub The Timeout for InstallDB is $InstallDbTimeout seconds");

      unless ( $self->enterRootSessionViaSU() ){
           $logger->error( __PACKAGE__ . " : Could not enter root session" );
           return 0;
       }

       # change the directory
       my $cmdString = "cd /export/home/ssuser/SOFTSWITCH/SQL/";

       $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
       $self->execCmd("$cmdString");
       $cmdString = "./InstallDb";
       $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
       unless ( $self->execCmd( "$cmdString", $InstallDbTimeout ) ) {
           $logger->error( __PACKAGE__ . ".$sub InstallDb Failed " );
           return 0;
       }
       $logger->info(__PACKAGE__ . "$sub: Successfully Executed InstallDb" );

       # Leaving root session
       unless ( $self->leaveRootSession()) {
           $logger->error(__PACKAGE__ . " : Could not leave the root session");
           return 0;
       }
       sleep 3;

       # Stop Softswitch
       unless ( $self->startStopSoftSwitch(0)){
           $logger->error(__PACKAGE__ . ".$sub: failed to stop PSX softswitch " );
           return 0;
       }
       $logger->info(__PACKAGE__ . ".$sub:Success: Stopped the PSX softswitch" );


       # Start Softswitch
       unless ( $self->startStopSoftSwitch(1)){
           $logger->error(__PACKAGE__ . ".$sub: failed to start PSX softswitch " );
           return 0;
       }
       $logger->info(__PACKAGE__ . ".$sub:Success: Started the PSX softswitch" );

       sleep 2;

       return 1;

=cut

        my ($result,@checkType,$cmd,%args);
        $cmd = qq( grep "masterorreplica" /var/opt/sonus/ssScriptInputs );
        @checkType  = $self->execCmd($cmd);
        if ($checkType[0] =~ /"s"|"S"/) {

                $logger->info(__PACKAGE__ . ".$sub:PSX is a slave" );
                $logger->info(__PACKAGE__ . ".$sub:Getting the master name");
                $cmd = qq(grep "mastersysname" /var/opt/sonus/ssScriptInputs);
                @checkType  = $self->execCmd($cmd);
                $checkType[0]  =~ s/.*="//g;
                $checkType[0]  =~ s/"//g;
                $args{-mastername} = $checkType[0];
                $logger->info(__PACKAGE__ . ".$sub: Master PSX is $checkType[0] ");
                $logger->info(__PACKAGE__ . ".$sub:Getting the master ip");
                $cmd = qq(grep "masterip" /var/opt/sonus/ssScriptInputs);
                @checkType  = $self->execCmd($cmd);
                $checkType[0]  =~ s/.*="//g;
                $checkType[0]  =~ s/"//g;
                $args{-masterip} = $checkType[0];
                $logger->info(__PACKAGE__ . ".$sub:Calling psx_newdbinstall to replicate the existing DB present in the master on to the slave");
                if (defined ($a{-InstallDbTimeout})) {
                        $logger->info(__PACKAGE__ . ".$sub The Timeout for InstallDB is $a{-InstallDbTimeout} seconds");
                        $args{-Timeout} = $a{-InstallDbTimeout} ;
                }
                $result = $self->psx_newdbinstall(%args);
                return $result;

        }
        else {
                $logger->info(__PACKAGE__ . ".$sub:PSX is a standalone master" );
                $logger->info(__PACKAGE__ . ".$sub:Calling psx_newdbinstall to install a fresh DB on a standalone master");
                if (defined ($a{-InstallDbTimeout})){
                        $logger->info(__PACKAGE__ . ".$sub The Timeout for InstallDB is $a{-InstallDbTimeout} seconds");
                        $args{-Timeout} = $a{-InstallDbTimeout} ;
                }
                $result = $self->psx_newdbinstall(%args);
                return $result;
        }
   }
   unless ($self->enterRootSessionViaSU()){
        $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
        return 0;
    }

   # change the directory
   my $cmdString = "cd /export/home/ssuser/SOFTSWITCH/SQL/";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   my @cmdResults = $self->{conn}->cmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub: cmd results : @cmdResults");

   $cmdString = "./InstallDb";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   # Please confirm values (Y|y|N|n) ....y
   my $prompt2 = '/ \.\.\.\./';
   my $prevPrompt = $self->{conn}->prompt($prompt2);

   @cmdResults = $self->{conn}->print( $cmdString);

   my ($prematch, $match);

   ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt2,
                                             -errmode => "return",
                                             -timeout => 120) or do {
      $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
      $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
      $logger->debug(__PACKAGE__ . ".$sub: cmd results : @cmdResults");
      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $self->leaveRootSession();
      $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
      return 0;
   };

   $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");

   #/export/home/orasql/SSDB directory must be removed and recreated. Continue (default:N) [y|Y,n|N] ? y
   #/export/home/oracle/admin/SSDB directory must be removed and recreated. Continue (default:N) [y|Y,n|N] ? y
   #/export/home/oradata/SSDB directory must be removed and recreated. Continue (default:N) [y|Y,n|N] ? y
   #/export/home2/oraidx/SSDB directory must be removed and recreated. Continue (default:N) [y|Y,n|N] ? y
   #/export/home/orasys/SSDB directory must be removed and recreated. Continue (default:N) [y|Y,n|N] ? y

   $cmdString = "y";
   my $index = 0;

   $prompt2 = '/ \?/';

   $self->{conn}->prompt($prompt2);

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
   @cmdResults = $self->{conn}->print( $cmdString);
   my $retval=1;
   do {

      ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt2,
                                             -errmode => "return",
                                             -timeout => 120) or do {
         $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
         $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
         $logger->debug(__PACKAGE__ . ".$sub: cmd results : @cmdResults");
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         $retval=0;
         last;
      };

      $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");

      $index++;

      if($index < 5) {
         $prompt2 = '/ \?/';

         $self->{conn}->prompt($prompt2);

         $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
         @cmdResults = $self->{conn}->print( $cmdString);
      }
   } while $index < 5;
   unless($retval){

      $self->leaveRootSession();
      $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
      return 0;
   }
   my $timeout = 60 * 80;

   $prompt2 = '/\#/';

   $prevPrompt = $self->{conn}->prompt($prompt2);

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");
   my @cmdResultsNext = $self->{conn}->print($cmdString);

   ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt2,
                                             -errmode => "return",
                                             -timeout => $timeout) or do {
         $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
         $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
         $logger->debug(__PACKAGE__ . ".$sub: cmd results : @cmdResults");
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         $self->leaveRootSession();
         $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
         return 0;
      };

   $logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");

   # check the command completed successfully
   my $cmdPassed = 0;
   if($prematch =~ /Configuring database for Auto Start and Auto Stop/s){
      $logger->debug(__PACKAGE__ . ".$sub Command Completed successfully");
      $cmdPassed = 1;
   }

   $logger->debug(__PACKAGE__ . ".$sub ************************** \n @cmdResultsNext \n\n ************************** ") ;


   # Start Soft Switch
   # su - ssuser
   # start.ssoftswitch

   $cmdString = "/export/home/ssuser/SOFTSWITCH/BIN/start.ssoftswitch";

   $logger->debug(__PACKAGE__ . ".$sub: Executing $cmdString on PSX");

   @cmdResults = $self->execCmd("$cmdString");

   $logger->debug(__PACKAGE__ . ".$sub ************************** \n @cmdResults \n\n ************************** ") ;
  unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
  }


   $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$cmdPassed]");
   return $cmdPassed;
}

=head2 getPSXMgmtOutput()

- This subroutine returns the output of the required PSX Mgmt menu viz ssmgmt,sipemgmt, scpamgmt, slwresdmgmt as a Hash containing the counter name as the key and its value.

- Multiple arguments can be provided for getting the combined output in the form of hash.

- only one mgmt input can be provided as input.

- The output should have either "=" or ":" as the delimiter so that the output can be returned as key and values separated by partoculat delimiter.

=over

=item Arguments :

$opn   :  string corresponding to which you want the output.
$ssmgmt : array reference having the various selection inputs.

=item Example :

   my $opn = 'ssmgmt'
   my $ssmgmt = [15, 20];
   my %resultHash = $psxObj->getPSXMgmtOutput( $opn , $ssmgmt );

   if ($resultHash{"GSM MAP SRI Requests sent"} == 2)
   {
       print "PASS";
   }
   else
   {
       print "FAIL";
   }

=item Added by :

  Garg Mayank (mgarg@sonusnet.com)

=back

=cut

sub getPSXMgmtOutput {
     my ($self, $opn, $ref) = @_;
     my $sub = "getPSXMgmtOutput";

     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     my @array = @$ref;
     my $prompt = '/Enter (Selection|Choice)\:/';
     my ($prematch, $match,$spStr,$ind,$retStr,$key,$value,%table);

     unless(defined($ref)){
         $logger->error(__PACKAGE__ . ".$sub ssmgmt selection sequence MISSING");
         return %table;
     }

     $logger->debug(__PACKAGE__ . ".$sub ENTERING $opn MENU ");
     $self->{conn}->print($opn);
     ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                               -errmode => "return",
                                               -timeout => $self->{DEFAULTTIMEOUT}) or do {
         $logger->warn(__PACKAGE__ . ". $sub  UNABLE TO ENTER $opn MENU ");
         return %table;
         } ;

    my $count = 0 ;
    foreach (@array)
    {
        $self->{conn}->print($_);
        ($prematch, $match) = $self->{conn}->waitfor(-match => $prompt,
                                                  -errmode => "return",
                                                  -timeout => $self->{DEFAULTTIMEOUT});

        my %hash = ( ssmgmt      => 'Sonus SoftSwitch Management Menu',
                     sipemgmt    => 'Sonus SIP Engine Management Menu',
                     slwresdmgmt => 'LWRESD Management Menu' ,
                     scpamgmt    => 'SCPA Management Menu',
                     httpmgmt    => 'HTTP Management Menu', #TOOLS-73220
                    ) ;

        $spStr = $hash{$opn} ;
        $logger->info(__PACKAGE__ . ".$sub  ::  String Obtained :: $spStr ");
        $ind = index($prematch,$spStr);
        $logger->info(__PACKAGE__ . ".$sub  ::  index obtained is ::: $ind ");
        $retStr = substr($prematch,0,$ind);

        my @arr = split("\n",$retStr);
        chomp @arr ;

        foreach (@arr) {
            if ($_ =~ m/=|:/) {
                $count++ ;
                if ($_ =~ m/=/) {
                    ($key, $value) = split "=", $_;
                }
                elsif ( $_ =~ m/:/ ) {
                    ($key, $value) = split ":", $_ ;
                }
                $key =~ s/^\s+//;
                $key =~ s/\s+$//;

                $value =~ s/^\s+//;
                $value =~ s/\s+$//;
                if ($key =~ m/\w+$/){
                    $table{$key} = $value;
                }
            }
        }
    }
  
    $logger->info(__PACKAGE__ . ".$sub Hash obtained is :\n ". Dumper(\%table) );
     
    unless ($count){
        $logger->info(__PACKAGE__ . ".$sub dint get the expected output ");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0 ;
    }

    $logger->info(__PACKAGE__ . ".$sub Entering Ctrl-C to exit out of ssmgmt");
    $self->{conn}->cmd("\x03");

    return %table ;
}


=head2 getSsmgmtOutput()

This subroutine returns the output of the required ssmgmt menu as a Hash containing the counter name as the key and its value.

=over

=item Arguments :

$ssmgmt : array reference having the various selection inputs

=item Example :

   my $ssmgmt = ['15'];
   my %resultHash = $psxObj->getSsmgmtOutput($ssmgmt);

   if ($resultHash{"GSM MAP SRI Requests sent"} == 2)
   {
       print "PASS";
   }
   else
   {
       print "FAIL";
   }

=item Added by :

  Sowmya Jayaraman (sjayaraman@sonusnet.com)

=back

=cut

sub getSsmgmtOutput {
   my ($self, $ref) = @_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__);
   my $sub = "getSsmgmtOutput";
   my %hash ; 

   $logger->info(__PACKAGE__ . ".$sub internal call to subroutine \'getPSXMgmtOutput\'"); 
   unless ( %hash = $self->getPSXMgmtOutput('ssmgmt' , $ref ) ) {
       $logger->debug(__PACKAGE__ . ". $sub  unable to fetch the output of ssmgmt command") ;
       $logger->debug(__PACKAGE__ . ". $sub  Leaving sub [0]");
       return 0 ;
   }    
   
   $logger->debug(__PACKAGE__ . ".$sub successfully parsed the output in hash") ; 
   return %hash ; 
}                   
  

=head2 restartService()

This subroutine restarts a child service on the PSX by simply killing it and letting the framework take care of restarting it.
(We do check that the service is restarted, however)

=over

=item Arguments :

service => 'scpa' 		# String containing the service/process to restart
key	=> 'DEFAULT_SCPA_CFG' 	# String containing unique key visible in the ps output to identify a single instance where e.g. multiple SCPA instances are running
				# If unset - restarts _all_ instances of the process named in 'service' above.
timeout => '30'			# Amount of time (in seconds) to wait for all services to restart, before returning failure.
				# Defaults to 30s if unspecified which should be good for most cases.

=item Returns :

  Will return failure in the case where we can't determine a running service matching the supplied arguments, or if the process(es) fail to respawn before the timeout is reached.

 1-Success
 0-Failure

=item Example :

   # Restart all scpa instances
   my $result = $psxObj->restartService(service => 'scpa'); 

   # Restart only the scpa instances running with configs matching the regexp '.*JAPAN_SCPA_CFG.*'
   # In case your instances have similar named configs and you only want to restart one - you must specifcy a UNIQUE key here, e.g.
   #	If you provisioned JAPAN_SCPA_CFG, ANSI_SCPA_CFG, DEFAULT_SCPA_CFG - then the above will only restart the first one.
   #	If however you had provisioned JAPAN_SCPA_CFG1, JAPAN_SCPA_CFG2, DEFAULT_SCPA_CFG - then the above would restart the first _two_
   # This gives you total flexibility in environments with multiple instances, but must be used with care.

   my $result = $psxObj->restartService(service => 'scpa', key => 'JAPAN_SCPA_CFG'); 

   # Restart all scpa instances, wait 2 minutes (120s) for them to restart
   my $result = $psxObj->restartService(service => 'scpa', timeout => 120); 

=item Added by :

  Malcolm Lashley (mlashley@sonusnet.com)

=back

=cut

sub restartService {
	my ($self, %args) = @_;
	my %a;
	my $sub = "restartService()";

	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

	# Set defaults
	$a{timeout} = 30;

	# get the arguments, override defaults if specified
	while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

	$logger->info(__PACKAGE__ . ".$sub Restarting all instances of $a{service}") if not defined $a{key};
	$logger->info(__PACKAGE__ . ".$sub Restarting specific instances of $a{service} matching $a{key}") if defined $a{key};

	my $cmd = "ps -eo 'pid args' | grep $a{service}";
	$cmd .= " | grep $a{'key'}" if defined $a{key};
	$cmd .= " | grep -v grep";

	my @cmdResults = $self->execCmd($cmd);


#$logger->error(__PACKAGE__ . ".$sub CMD Results" .  Dumper(@cmdResults) );


	my $numberOfServices = $#cmdResults;

	# Sanity check.
	if ($numberOfServices eq -1) {
		$logger->warn(__PACKAGE__ . ".$sub No instances of $a{service} were found - nothing to kill.") if not defined $a{'key'};
		$logger->warn(__PACKAGE__ . ".$sub No instances of $a{service} matching $a{'key'} were found - nothing to kill.") if defined $a{'key'};
		return 0; # Failed - the user should be expecting the services to be running.
	}

	# Parse output - extract process id which is first field per our format argument to 'ps' above, and kill it.

	my @pids; # Array to store the killed process id's so we can exclude them later.

	my $row;
	$logger->info(__PACKAGE__ . ".$sub Found " . ($#cmdResults + 1) . " processes to kill");
	foreach $row (@cmdResults) {
                $row =~ s/^\s+//; #remove leading spaces
		my ($pid, $cmd) = split / /,$row;
		push(@pids, $pid);
		$logger->info(__PACKAGE__ . ".$sub Killing [PID,CMD] [$pid,$cmd]");
		$self->execCmd("kill -9 $pid"); # SIGKILL FTW ;-)
		# NB - we don't check the result here as we're going to do the exact same checks for the process in question having gone away in the below loop.
	}
#$logger->error(__PACKAGE__ . ".$sub PIDS " .  Dumper(@pids) );

	$cmd  = "ps -eo 'pid args' | grep $a{service}";
	$cmd .= " | grep $a{key}" if defined $a{key};
	foreach (@pids) {
		$cmd .= " | grep -v $_ "; # Specifically exclude the processes we tried to kill from the output.
	}
	$cmd .= " | grep -v grep";

	$logger->info(__PACKAGE__ . ".$sub Waiting $a{timeout} seconds for process(es) to respawn");
	my $start = time;
	@cmdResults = $self->execCmd($cmd);
	while( ((time - $start) < $a{timeout}) and ( $#cmdResults != $numberOfServices ) ) {
		sleep 2; # Re-check every couple of seconds.
		@cmdResults = $self->execCmd($cmd);
		$logger->debug(__PACKAGE__ . ".$sub tick, tock...");
	}

	if ($#cmdResults eq $numberOfServices) {
		$logger->info(__PACKAGE__ . ".$sub Expected ($numberOfServices) number of new processes found, return SUCCESs");
                sleep 10;
		return 1;
	} else {
		$logger->warn(__PACKAGE__ . ".$sub Found only $#cmdResults / $numberOfServices new processes after timeout, return FAILURE");
                return 0;
	}

}

sub renameOldCoreFiles() {

  my ($self) = @_;
  my $sub = "renameOldCoreFiles";

  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub Entered Sub");
  my ($cmdString,@cmdResults);

  unless ($self->enterRootSessionViaSU()){
      $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
      $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
      return 0;
  }

  $cmdString = "cd $self->{coreDirPath}";
  $self->{conn}->cmd("$cmdString");
  
  $cmdString = "ls -1 core*";
  $logger->debug(__PACKAGE__ . ".$sub executing command $cmdString");
  
  my @coreFiles = $self->{conn}->cmd("$cmdString");
  
  $logger->debug(__PACKAGE__ . ".$sub ***** \n @coreFiles \n\n ******* ") ;
  my $retval =1;
  foreach(@coreFiles) {
     if(m/No such file or directory/i) {
        $logger->info(__PACKAGE__ . ".$sub No cores found");
        $retval =0;
        last;
     }
  }
  unless($retval){
      $retval = $self->leaveRootSession();
      $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
      return $retval;
  }

  # Get the number of core files
  my $numcore = $#coreFiles + 1;
  $logger->info(__PACKAGE__ . ".$sub Number of cores in PSX is $numcore");

  my ($cmd,$newfileNm);

   # Move all core files
  foreach (@coreFiles) {
    chomp($_);
    $newfileNm = $_;
    $newfileNm =~ s/core/old_core/;
    $cmd = "mv $_ $newfileNm";
    $logger->info(__PACKAGE__ . ".$sub Renaming existing core file $_ as $newfileNm");
   $self->{conn}->cmd($cmd);  
}
 unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
  }
 
  $logger->debug(__PACKAGE__ . ".$sub Leaving Sub");
  return 1;  
}

=head2 stopOracleDB()

This subroutine shut down the oracle DB in PSX

=over

=item Arguments :

   None

=item Return Values :

   0 : failure
   1 : Success

=item Example :

   $psxSSHObj->stopOracleDB();

=item Added by :

   Shashidhar Hayyal(shayyal@sonusnet.com)

=back

=cut

sub stopOracleDB() {
    my ($self) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".stopOracleDB");

    #Get the oracle login credentials
    my $psxIPAddress      = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}|| $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
    #my $psxOracleUserName = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ORACLEUSERID};
    my $psxOracleUserName = 'oracle';
    #my $psxOraclePassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ORACLEPASSWD};
    my $psxOraclePassword = 'oracle';

    my $oracleSession = new SonusQA::Base( -obj_host       => "$psxIPAddress",
                                           -obj_user       => "$psxOracleUserName",
                                           -obj_password   => "$psxOraclePassword",
                                           -comm_type      => 'SSH',
                                           -obj_port       => 22,
                                           -return_on_fail => 1,
                                           -defaulttimeout => 120,
                                         );
   unless ($oracleSession) {
      $logger->error("Unable to open a session to PSX $psxIPAddress");
      return 0;
   }

   my $prevTimeoutValue = $oracleSession->{conn}->timeout(120);

   my $cmdString = 'cd /export/home/oracle';
   $logger->debug("Executing a command :-> $cmdString");
   my @cmdResults = $oracleSession->{conn}->cmd("$cmdString");

   $cmdString = "sqlplus '/ as sysdba'";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");
   sleep (5);
   $logger->debug("Command Output : @cmdResults");
 
   $cmdString = "shutdown immediate";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");
   sleep (5);
   $logger->debug("Command Output : @cmdResults");

   my $shutDownSuccess = 0;
   foreach (@cmdResults) {
       if (/ORACLE\s+instance\s+shut\s+down/i) {
           $shutDownSuccess = 1;
       }
   }

   $cmdString = "exit";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");

   $oracleSession->{conn}->timeout($prevTimeoutValue);

   if ($shutDownSuccess) {
       $logger->debug("DB shut down is successfull");
   } else {
       $logger->error("Unable to shutdown DB");
   }

   $oracleSession->DESTROY;

   return $shutDownSuccess;
}

=head2 startOracleDB()

This subroutine start the oracle DB in PSX

=over

=item Arguments :

   None

=item Return Values :

   0 : failure
   1 : Success

=item Example :

   $psxSSHObj->startOracleDB();

=item Added by :

   Sukruth Sridharan (ssridharan@sonusnet.com)

=back

=cut

sub startOracleDB() {
    my ($self) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startOracleDB");

    #Get the oracle login credentials
    my $psxIPAddress      = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}|| $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
    #my $psxOracleUserName = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ORACLEUSERID};
    my $psxOracleUserName = 'oracle';
    #my $psxOraclePassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ORACLEPASSWD};
    my $psxOraclePassword = 'oracle';

    my $oracleSession = new SonusQA::Base( -obj_host       => "$psxIPAddress",
                                           -obj_user       => "$psxOracleUserName",
                                           -obj_password   => "$psxOraclePassword",
                                           -comm_type      => 'SSH',
                                           -obj_port       => 22,
                                           -return_on_fail => 1,
                                           -defaulttimeout => 120,
                                         );
   unless ($oracleSession) {
      $logger->error("Unable to open a session to PSX $psxIPAddress");
      return 0;
   }

   my $prevTimeoutValue = $oracleSession->{conn}->timeout(120);

   my $cmdString = 'cd /export/home/oracle';
   $logger->debug("Executing a command :-> $cmdString");
   my @cmdResults = $oracleSession->{conn}->cmd("$cmdString");

   $cmdString = "sqlplus '/ as sysdba'";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");
   sleep (5);
   $logger->debug("Command Output : @cmdResults");

   $cmdString = "startup";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");
   sleep (5);
   $logger->debug("Command Output : @cmdResults");

   my $startupSuccess = 0;
   foreach (@cmdResults) {
       if (/ORACLE\s+instance\s+started/i) {
           $startupSuccess = 1;
       }
   }

   $cmdString = "exit";
   $logger->debug("Executing a command :-> $cmdString");
   @cmdResults = $oracleSession->{conn}->cmd("$cmdString");

   $oracleSession->{conn}->timeout($prevTimeoutValue);

   if ($startupSuccess) {
       $logger->debug("DB startup is successfull");
   } else {
       $logger->error("Unable to startup DB");
   }

   $oracleSession->DESTROY;

   return $startupSuccess;
}

=pod

=head2 copyPSXLogToServer()

    This subroutine is used to copy the specified PSX log (such as PES or SCPA) file from PSX to specified server and path.
    If server is not mentioned, it will copy the log to the server where you are running the test and at the path you 
    mentioned in 'destDir'. If the directory is not mentioned then it will copy to the path where you are running the test.

=over

=item Arguments :

    $PSXSSHObj->copyPSXLogToServer(logType          => ['PES', 'SCPA'],
                                [destServerIP       => $destServerIP],
                                [destServerUserName => $destServerUserName],
                                [destServerPasswd   => $destServerPasswd],
                                [destDir            => $destDir],
                                [destFileName       => $destFileName],);

    $PSXSSHObj->copyPSXLogToServer(logType => 'PES');

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Author :

    Shashidhar Hayyal (shayyal@sonusnet.com)

=back

=cut

sub copyPSXLogToServer() {
    my ($self, %args) = @_;
    my $sub = "copyPSXLogToServer()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $destFileName = "";
    
    if (not exists $args{logType}) {
        $logger->error("logType is missing. This is a mandatory argument");
        return 0;
    } 
    
    $logger->info("Log Type Is: $args{logType}");
    
    if (exists $args{destFileName}) {
        if ($args{destFileName} =~ /\.log$/i) {
            $destFileName = $args{destFileName};
        } elsif ($args{destFileName} =~ /$args{logType}/i) {
            $destFileName = "$args{destFileName}" . "\.log";
        } else {
            $destFileName = "$args{destFileName}" . "_" . "$args{logType}" . "\.log";
        }
    } else {
        my $userID = qx#id -un#;
        chomp($userID);
        my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
        $year  += 1900;
        $month += 1;
        my $timeStamp = $sec . $min . $hour . $day . $month . $year;
        
        $destFileName =  $userID . "_" . "$args{logType}" .  "_" . $timeStamp . "\.log";
    }
    
    #If you specified destination server then you must specify username password and directory of that server in %args
    if (exists $args{destServerIP}) {
        $logger->info("Destination Server User name: $args{destServerUserName}");
        $logger->info("Destination Server Password : \$args{destServerPasswd}");
        $logger->info("Destination Directory       : $args{destDir}");
        
        unless (exists $args{destServerUserName} && exists $args{destServerPasswd} && exists $args{destDir}) {
            $logger->error("Either destServerUserName or destServerPasswd or destDir is missing");
            return 0;
        }
                                
        $logger->info("PSX $args{logType} logs will be copied to,");
        $logger->info("server    --> $args{destServerIP}");
        $logger->info("File Name --> $args{destDir}/$destFileName");
            
    } else {
        my $currentDirPath = qx#pwd#;
        chomp ($currentDirPath);
        $logger->info("PSX $args{logType} logs will be copied to your local server with below mentioned path and file name");
        $logger->info("Path --> $currentDirPath/$destFileName");
    }
        
    #Get the required log and copy the file to local server
    my $psxIpAddress  = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}|| $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
    my $psxrootPasswd = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
    
    #Now make SFTP to NFS server
    my $psxRootSessObj = new Net::SFTP( $psxIpAddress,
                                    user     => 'root',
                                    password => $psxrootPasswd,
                                    debug    => 0,);

    unless ($psxRootSessObj) {
        $logger->error("Could not open sftp connection to PSX --> $psxIpAddress");
        return 0;
    }

    $logger->info("SFTP connection to to PSX --> $psxIpAddress is successfull");
    
    #Now copy the log file to local server
    my $srcLogPath; 
    if ($args{logType} =~ /PES/i) {
        $srcLogPath = "$self->{LOGPATH}/pes.log";
    } elsif ($args{logType} =~ /SCPA/i) {
        $srcLogPath = "$self->{LOGPATH}/scpa.log";
    } else {
        $logger->error("You have specified invalid log type --> $args{logType}");
        return 0;
    }
    
    my $destPath;
    
    if (exists $args{destDir} && not exists $args{destServerIP}) {
        $destPath = "$args{destDir}/$destFileName";
    } else {
        my $currentDirPath = qx#pwd#;
        chomp ($currentDirPath);
        $destPath = "$currentDirPath/$destFileName"; 
    }
        
    $logger->info("Copying logs from $srcLogPath To $destPath");
    eval{
       $psxRootSessObj->get($srcLogPath, $destPath);
    };
    if ($@) {
       $logger->error(__PACKAGE__ . ".$sub: Error while copying the file");
       $logger->error(__PACKAGE__ . ".$sub: Error Message: $@");
       return 0;
    }


    if (-e $destPath) {
        $logger->info("Successfully copied to file --> $destPath");
    } else {
        $logger->info("Unable to copy the to local server");  
        return 0;
    }
    
    if (not exists $args{destServerIP}) { 
        $logger->info("Successfully copied $args{logType} to your local server at --> $destPath");           
        return 1;
    }

    #Now make SFTP connection to destination server
    my $destServerSess = new Net::SFTP( $args{destServerIP},
                                    user     => $args{destServerUserName},
                                    password => $args{destServerPasswd},
                                    debug    => 0,);

    unless ( $destServerSess ) {
        $logger->error("Could not open sftp connection to destination server --> $args{destServerIP}");         
        return 0;
    }   

    $logger->info("SFTP connection to destination server  $args{destServerIP} is successfull");
    
    #Now copy the local copy of file to destination server
    my $localCopy      = $destFileName;
    my $destServerFile = "$args{destDir}/$destFileName";
    
    eval{
        $destServerSess -> put($localCopy, $destServerFile); 
    };
    if ($@) {
        $logger->error(__PACKAGE__ . ".$sub: Error while copying the file");
        $logger->error(__PACKAGE__ . ".$sub: Error Message: $@");
        return 0;
    }
  
    unless ($destServerSess) {
        $logger->error("Unable to copy to destination server --> $args{destServerIP}");
        $logger->error("Check the directory you mentioned is present on server, if present check the permissions");                 
        return 0;
    }   

    $logger->info("Successfully copied file to destination server --> $args{destServerIP} at the path --> $destServerFile");
    
    #Now remove the local copy
    qx#rm -rf $localCopy#;
    
    unless (-e $destFileName) {
        $logger->info("Successfully removed the local copy");
    } else {
        $logger->info("Unable to remove the local copy");
    }
     
    return 1;  
}

=head2 getTcapStats()

    This sub get SS7 (TCAP) Statistics in a hash

=over

=item Arguments :

   None

=item Example :

   my %callCount = $psx_obj->getTcapStats();

   The data in the hash table is organized as follows
   $callCount{ANSI_TCAP}->{QRY_SENT}
   $callCount{ANSI_TCAP}->{RSP_RCVD}

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub getTcapStats {
   my ($self, %args) = @_;
   my $sub = "getTcapStats()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Retrieving SS7 (TCAP) Statistics");

   #set the option
   my @temp = ("3");
   my @resultArr = $self->scpamgmtStats(\@temp);

   my $line;
   my $skipLines = 1;
   my $getHeader = 0;
   my $getData = 1; #First we have to get the header
   my $headerString;
   my %callData;
   foreach $line (@resultArr) {
      if ($skipLines eq 1) {
         if($line =~ m/Command Status/) {
            $skipLines = 0;
         } else {
            next;
         }
      }

      if($line =~ m/SCPA Management Menu/) {
         # We reached theh end. Stop here
         last;
      }

      if($line =~ m/---------------/) {
         if($getHeader eq 1) {
            $getData = 1;
            $getHeader = 0;
         } elsif ($getData eq 1) {
            $getHeader = 1;
            $getData = 0;
         }
         next;
      }

      if($getHeader eq 1) {
         #Get the header first and store it
         if($line =~ m/\s+(\S+)\s+(\S+).*/) {
            $headerString = $1 . "_" . $2;
         }
      } else {
         # Get data
         if($line =~ m/\s+(\S+)\s+(\d+)/) {
            $callData{$headerString}{$1} = $2;
         }
      }
   }

   return %callData;
}

=head2 resetTcapStats()

    This sub get SS7 (TCAP) Statistics in a hash

=over

=item Arguments :

   None

=item Example :

   $psx_object->resetTcapStats();

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub resetTcapStats {
   my ($self, %args) = @_;
   my $sub = "resetTcapStats()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Resetting SS7 (TCAP) Statistics");

   #set the option
   my @temp = ("4");
   my @resultArr = $self->scpamgmtStats(\@temp);

   return 1;
}

=head2 startSarCommand()

    This sub starts SAR command

=over

=item Arguments :

    Optional : 
    -delayTime       => Delay time
                        Default is set as 60
    -noOfIntervals   => Number of intervals
                        Default is set to 1140

=item Example :

   $psx_object->startSarCommand();

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub startSarCommand {
   my ($self, %args) = @_;
   my $sub = "startSarCommand()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a = (-delayTime       => 60,
            -noOfIntervals   => 1140);

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Starting the top command");

   #Remove the log file if it is already exists
   my $cmdString = "rm /tmp/ats_sar_logs";

   $logger->info(__PACKAGE__ . ".$sub executing $cmdString");

   my @commandResults = $self->{conn}->cmd($cmdString);

   $logger->info(__PACKAGE__ . ".$sub Command out put : @commandResults");

   # Even though if we run this command in back ground, it will display some values on the terminal.
   # Just redirect it to one file to avoid further problems

   #Remove the screen log file if it is already exists
   $cmdString = "rm /tmp/ats_sar_scr_logs";

   $logger->info(__PACKAGE__ . ".$sub executing $cmdString");

   @commandResults = $self->{conn}->cmd($cmdString);

   $logger->info(__PACKAGE__ . ".$sub Command out put : @commandResults");

   # start loging sar data
   $cmdString = "sar -abcgkmpqruvwy -o /tmp/ats_sar_logs $a{-delayTime} $a{-noOfIntervals} > /tmp/ats_sar_scr_logs &";

   $logger->info(__PACKAGE__ . ".$sub executing $cmdString");

   @commandResults = $self->{conn}->cmd($cmdString);

   $logger->info(__PACKAGE__ . ".$sub Command out put : @commandResults");
   return 1;
}

=head2 stopSarCommand()

    This sub stops the Sar command. Also this sub will collect the sar out put from the PSX

=over

=item Arguments :

    -testCaseID  => Test Case Id
    -logDir      => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item Example :

  @logFile = $psx_obj->stopSarCommand( -testCaseID      => $testId,
                                        -logDir          => "/home/ssukumaran/ats_user/logs",
                                        -timeStamp       => $timestamp);

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub stopSarCommand {
   my ($self, %args) = @_;
   my $sub = "stopSarCommand()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a = (-variant   => "NONE", 
            -timeStamp => "00000000-000000");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Stopping the Sar command");

   unless ( $a{-testCaseID} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory -testCaseID is empty or blank.");
      return 0;
   }
   unless ( $a{-logDir} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
      return 0;
   }

   my $cmdString = "ps -aef |grep sar |grep -v grep";

   $logger->info(__PACKAGE__ . ".$sub executing $cmdString");

   my @commandResults = $self->{conn}->cmd($cmdString);

   $logger->info(__PACKAGE__ . ".$sub Command out put : @commandResults");

   my $line;
   foreach $line (@commandResults) {
      chomp $line;
      if ($line =~ m/\s+\S+\s+(\d+).*/) {
         # Kill the process
         $cmdString = "kill -9 $1";
         $logger->debug(__PACKAGE__ . ".$sub : executing $cmdString command");

         @commandResults = $self->{conn}->cmd($cmdString);
         $logger->debug(__PACKAGE__ . ".$sub @commandResults");
      }
   }

   # Open a session for SFTP
   if (!defined ($self->{sftp_session})) {
      $logger->debug(__PACKAGE__ . ".$sub starting new SFTP session");

      # TMS Data
      my $root_password = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
      my $psxIp         = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}|| $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
      my $psxName       = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

      unless ($root_password) {
         $logger->error(__PACKAGE__ . ".$sub Root password is not defined in TMS");
         return 0;
      }

      unless ($psxIp) {
         $logger->error(__PACKAGE__ . ".$sub PSX IP is not defined in TMS");
         return 0;
      }

      unless ($psxName) {
         $logger->error(__PACKAGE__ . ".$sub PSX name is not defined in TMS");
         return 0;
      }

      $self->{sftp_session} = new Net::SFTP( $psxIp,
                                             user     => "root",
                                             password => $root_password,
                                             debug    => 0,
                                           );

      unless ( $self->{sftp_session} ) {
         $logger->error(__PACKAGE__ . ".$sub Could not open connection to PSX $psxName");
         $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
         return 0;
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub Connected to PSX");

   my @fileList = ("ats_sar_logs",
                   "ats_sar_scr_logs");

   my @retList;

   # Get the alias name
   my $tmsAlias = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   my $fileName;
   foreach $fileName (@fileList) {
      my $localLogFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "PSX-" . "$tmsAlias-" . "$fileName.log" ;
      my $remoteFile = "/tmp/$fileName";

      $logger->debug(__PACKAGE__ . ".$sub Transferring \'$remoteFile\' to \'$localLogFile\'");

      # Transfer File
      eval{
         $self->{sftp_session}->get($remoteFile, $localLogFile);
      };
      if ($@) {
         $logger->error(__PACKAGE__ . ".$sub: Error while copying the file");
         $logger->error(__PACKAGE__ . ".$sub: Error Message: $@");
         return 0;
      }


      # Check the transfer status
      unless ( $self->{sftp_session}->status == 0 ) {
         $logger->error(__PACKAGE__ . ".$sub:  Could not transfer $remoteFile");
      } else {
         $logger->debug(__PACKAGE__ . ".$sub file transfer completed");
         push(@retList, $localLogFile);
      }
   }

   return @retList;
}

=head2 getProcessInfo()

    This sub saves the process info on a log file

=over

=item Arguments :

    -testCaseID  => Test Case Id
    -logDir      => Logs are stored in this directory

   Optional:
    -variant    => Test case variant "ANSI", "ITU" etc
                   Default => "NONE"
    -timeStamp  => Time stamp
                   Default => "00000000-000000"

=item Example :

   my $logFile = $psx_obj->getProcessInfo( -testCaseID      => $testId,
                                           -logDir          => "/home/ssukumaran/ats_user/logs",
                                           -timeStamp       => $timestamp);

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub getProcessInfo {
   my ($self, %args) = @_;
   my $sub = "getProcessInfo()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a = (-variant   => "NONE", 
            -timeStamp => "00000000-000000");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Get Process Info");

   unless ( $a{-testCaseID} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory -testCaseID is empty or blank.");
      return 0;
   }
   unless ( $a{-logDir} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory ats logdir is empty or blank.");
      return 0;
   }

   # Get the alias name
   my $tmsAlias = $self->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   # Make the log file
   my $logFile = $a{-logDir} . "/" . "$a{-testCaseID}-" . "$a{-variant}-" . "$a{-timeStamp}-" . "PSX-" . "$tmsAlias-" . "processInfo.log" ;

   # Remove double slashes if present
   $logFile =~ s|//|/|;

   $logger->info(__PACKAGE__ . ".$sub Opening log file $logFile");

   # Open log file
   unless (open(PROCESSLOG,">> $logFile")) {
      $logger->error(__PACKAGE__ . ".$sub Failed to open $logFile");
      $logger->debug(__PACKAGE__ . ".$sub Leaving function with retcode-0");
      return 0;
   }

   # Command strings
   my $cmd = 'ps -o "pid,fname,args,pcpu,pmem,vsz,rss,osz,time,etime,stime,psr" -u ssuser';
   my $cmd2 = 'ps -o "pid,fname,args,pcpu,pmem,vsz,rss,osz,time,etime,stime,psr" -u oracle';

   my $markerLine = "----------------------- " . localtime(time) . " -----------------------";

   $logger->info(__PACKAGE__ . ".$sub Collecting data");

   # Get the data
   $logger->info(__PACKAGE__ . ".$sub Running command \'date\'");
   my @dateInfo   = $self->{conn}->cmd("date");

   $logger->info(__PACKAGE__ . ".$sub Running command \'$cmd\'");
   my @ssuserInfo = $self->{conn}->cmd($cmd);

   $logger->info(__PACKAGE__ . ".$sub Running command \'$cmd2\'");
   my @oracleInfo = $self->{conn}->cmd($cmd2);

   # Update the log file
   $logger->info(__PACKAGE__ . ".$sub Updating logfile");

   print PROCESSLOG $markerLine . "\n";
   print PROCESSLOG "@dateInfo" . "\n";
   print PROCESSLOG "@ssuserInfo" . "\n";
   print PROCESSLOG "@oracleInfo" . "\n";

   #Close the log file
   $logger->info(__PACKAGE__ . ".$sub Closing log file");
   close(PROCESSLOG);

   #return log file name
   $logger->info(__PACKAGE__ . ".$sub leaving function with retCode - 1");

   return $logFile;
}

=head2 getSsmgmtStats()

    This sub get some of the SSMGMT counts

=over

=item Arguments :

    -options     => Mention options for counters

=item Example :

   my @temp = ("8","26");
   my %callCount = $psx_obj->getSsmgmtStats(-options  => \@temp);

   # The data can be accessed as follows.
   my $cnt = $callCount{"TOLL_FREE_Counters"}->{"Timed_out_AIN_Toll-free_requests"};
   my $cnt1 = $callCount{"TOLL_FREE_Counters"}->{"IN/1_Toll-free_requests_sent_to_SCP"};

   The strings in the DISPLAY is used here jus after replacing the spaces with "_"
   Also make sure to use "" around the strings while accessing the elements

=item Note :

   This sub can be used for any data where the DISPLAY is same as below;
        ---------------------------------------------------------------
        INAP Counters
        ---------------------------------------------------------------
        INAP IDP Sent   = 0
        INAP IDP Failed = 0
        INAP TSSF Timeouts              = 0
        INAP Errors Received            = 0
        INAP Errors Detected            = 0
        ---------------------------------------------------------------

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub getSsmgmtStats {
   my ($self, %args) = @_;
   my $sub = "getSsmgmtStats()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Retrieving requested Statistics");

   unless ( $a{-options} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Options is empty or blank.");
      return 0;
   }

   my $opt;
   my %callData;

   foreach $opt (@{$a{-options}}) {
      #set the option
      my @temp;
      push (@temp, $opt);
      my @resultArr = $self->ssmgmtStats(\@temp);
      my $line;
      my $skipLines = 1;
      my $getHeader = 0;
      my $getData = 1; #First we have to get the header
      my $headerString;
      foreach $line (@resultArr) {
         if ($skipLines eq 1) {
            if($line =~ m/-------------/) {
               $skipLines = 0;
            } else {
               next;
            }
         }

         if($line =~ m/Sonus SoftSwitch Management Menu/) {
            # We reached the end. Stop here
            last;
         }

         if($line =~ m/---------------/) {
            if($getHeader eq 1) {
               $getData = 1;
               $getHeader = 0;
            } elsif ($getData eq 1) {
               $getHeader = 1;
               $getData = 0;
            }
            next;
         }

         if($getHeader eq 1) {
            #Get the header first and store it
            if($line =~ m/\s+(.*)/) {
               $headerString = $1;
               # Replace spaces with "_"
               $headerString =~ tr/ /_/;
            }
         } else {
            # Get data
            if($line =~ m/\s+(.*)= (\d+)/) {
               my $paramString = $1;
               my $paramValue = $2;
               # remove leading and trailing spaces
               $paramString =~ s/^\s+//;
               $paramString =~ s/\s+$//;
               # Replace spaces with "_"
               $paramString =~ tr/ /_/;
               $callData{$headerString}{$paramString} = $paramValue;
            }
         }
      }
   }

   return %callData;
}

=head2 resetSsmgmtStats()

    This sub reset some of the SSMGMT counts

=over

=item Arguments :

    -options     => Mention options for counters

=item Example :

   my @temp = ("9","27");
   my %callCount = $psx_obj->resetSsmgmtStats(-options  => \@temp);

=item Added by :

   Susanth Sukumaran (ssukumaran@sonusnet.com)

=back

=cut

sub resetSsmgmtStats {
   my ($self, %args) = @_;
   my $sub = "resetSsmgmtStats()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # Set default values before args are processed
   my %a;

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Resetting requested Statistics");

   unless ( $a{-options} ) {
      $logger->warn(__PACKAGE__ . ".$sub: Mandatory Options is empty or blank.");
      return 0;
   }

   my $opt;

   foreach $opt (@{$a{-options}}) {
      #set the option
      my @temp;
      push (@temp, $opt);
      $self->ssmgmtStats(\@temp);
   }
   return 1;
}

=head2 verifyPsxPointcodeStatus()

    This subroutine is used to verify the status of given point code in PSX.

=over

=item Arguments :

    Mandatory:

    pointCode  => Point code for which you want to get the status.

    sgId       => SG ID corresponding to that point code.

    statusOfPc => Point code status you want to check.

    Optional:

    congLevel => Congested level
    port      => Port Number

=item Return Values :

    1 - Incase of success
    0 - Incase of failure

=item Example :

   my result = $psxObj->verifyPsxPointcodeStatus(-pointCode  => '1-1-4',
                                                 -sgId       => 10,
                                                 -statusOfPc => 'Available');

   my result = $psxObj->verifyPsxPointcodeStatus(-pointCode  => '1-1-4',
                                                 -sgId       => 10,
                                                 -statusOfPc => 'Congested',
                                                 -congLevel  => 3);

=item Added by :

   Shashidhar Hayyal (shayyal@sonusnet.com)

=back 

=cut

sub verifyPsxPointcodeStatus {
   my ($self, %args) = @_;
   my $sub = "verifyPsxPointcodeStatus()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   $logger->info("$sub: ------- You passed the below details to subroutine -------");
   if (exists $args{-congLevel}) {
       $logger->info("$sub: Pointcode --> $args{-pointCode}, SG ID --> $args{-sgId}, Status --> $args{-statusOfPc}, Cong Level --> $args{-congLevel}");
   } else {
       $logger->info("$sub: Pointcode --> $args{-pointCode}, SG ID --> $args{-sgId}, Status --> $args{-statusOfPc}");
   }

   unless ( (exists $args{-pointCode}) && ($args{-pointCode} =~ /([0-9\-]+)/)) {
      $logger->error("$sub: pointCode option is missing or empty");
      return 0;
   }

   unless ( (exists $args{-sgId}) && ($args{-sgId} =~ /([0-9]+)/)) {
      $logger->error("$sub: sgId option is missing or empty");
      return 0;
   }

   unless ( (exists $args{-statusOfPc}) && ($args{-statusOfPc} =~ /([a-z]+)/i)) {
      $logger->error("$sub: statusOfPC option is missing or empty");
      return 0;
   }


   my @temp = "17";
   my @pcStatus = $self->scpamgmtStats(\@temp, $args{-port});

   $logger->info("$sub: PC Status \n @pcStatus \n");

   my $line;

   # Handling the passage of congLevel without any value or passing like -congLevel => " "
   if (exists $args{-congLevel}) {
       $args{-congLevel} =~ s/^\s*//g;
       $args{-congLevel} =~ s/\s*$//g;
       $args{-congLevel} = 0 if (!$args{-congLevel});
   }

   foreach $line (@pcStatus) {
       if ($line =~ /^\s*[0-9]+\s+([0-9\-]+)\s+([0-9]+)\s+([a-z]+)\s+([0-9]+)?/i) {
           my $pointCode = $1;
           my $sgId      = $2;
           my $status    = $3;
           my $conglevel = $4 || 0 ;

           if (($pointCode eq $args{-pointCode}) && ($sgId eq $args{-sgId}) && ($status eq $args{-statusOfPc})) {
               $logger->info("$sub: ------- Following details are obtained from command output -------");
               if (exists $args{-congLevel}) {
                    $logger->info("$sub Pointcode --> $pointCode, SG ID --> $sgId, Status --> $status, Cong Level --> $conglevel");
                    if ($conglevel ne $args{-congLevel}) {
                        $logger->error("$sub: Congetion level mismatch. Expected --> $args{-congLevel}  Got --> $conglevel");
                        return 0;
                    }
                    $logger->info("$sub: PC Status checking is successful");
                    return 1;
               } 
               $logger->info("$sub: Pointcode --> $pointCode, SG ID --> $sgId, Status --> $status");
               $logger->info("$sub: PC Status checking is successful");
               return 1;
           }
       }
   }

   $logger->error("$sub: PC Status checking is failed");
   return 0;
}

=head2  deletePcScpaData()

DESCRIPTION:

    Remove all SCPA data from the specified Process Configuration entry

=over

=item ARGUMENTS:

    Mandatory:

    Optional:

    -scpa   =>    Name of Process Configuration e.g. SCPA_DEFAULT_CFG

=item PACKAGE:

    SonusQA::PSX::PSXHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

   SonusQA::PSX::sqlplusCommand
   SonusQA::PSX::PSXHELPER::restartService

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    $psx_obj->deletePcScpaData();

=back

=cut

sub deletePcScpaData {
    my ($self, %args) = @_;
    my %a      = ( -scpa => "SCPA_DEFAULT_CFG" );
    my $sub    = "deletePcScpaData()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # get the arguments
    while ( my ( $key, $value ) = each %args ) { $a{$key} = $value; }
  
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );    

    my $psxName = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
    $logger->debug(__PACKAGE__ . ".$sub:  Deleting Data on PSX: $psxName Process Configuration : $a{-scpa}");
    
    eval{
        # #############################
        # PSX Process Configuration 
        # #############################   
        $self->{CMDERRORFLAG}   = 0;
        $self->{DEFAULTTIMEOUT} = 2;
       
        # Delete entries from 
        $self->sqlplusCommand("delete from SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = '$a{-scpa}' AND PARAMETER_TYPE = 4 AND PARAMETER_SUBTYPE = 215; ");
        $self->sqlplusCommand("delete from SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = '$a{-scpa}' AND PARAMETER_TYPE = 4 AND PARAMETER_SUBTYPE = 216; ");
        $self->sqlplusCommand("delete from SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = '$a{-scpa}' AND PARAMETER_TYPE = 4 AND PARAMETER_SUBTYPE = 217; ");
        $self->sqlplusCommand("delete from SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = '$a{-scpa}' AND PARAMETER_TYPE = 4 AND PARAMETER_SUBTYPE = 218; ");
        $self->sqlplusCommand("delete from SS_PROCESS_CONFIG_PARAMS where PROCESS_CONFIG_ID = '$a{-scpa}' AND PARAMETER_TYPE = 4 AND PARAMETER_SUBTYPE = 222; ");

        # #############################
        # Restart SCPA Process 
        # #############################   
        $self->restartService(service => 'scpa', key => '$a{-scpa}', timeout => 120);
    };
    if ($@) {
        $logger->debug(__PACKAGE__ . ".$sub : Error Removing PSX $psxName Configuration ");
        $logger->debug(__PACKAGE__ . ".$sub:  Error was: $@");
        return 0;
    }
                                
    $logger->debug(__PACKAGE__ . ".$sub: Finished Deleting Data on PSX: $psxName Process Configuration : $a{-scpa}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}


=head2  SearchCapCounters()

=over

=item  Arguments : 
		Mandatory Arguments: 
			-search_pattern  - string, whose presence should be checked in output.
		Optional Arguments:
			None

=item  Return Value:

		1 - If the -search_pattern present in output
		0 - On execution failur/ absence of -search_pattern in output

=back 

=cut

sub SearchCapCounters {
    my ($self, %args) = @_;
    my $sub    = "SearchCapCounters()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my ($prematch, $match, $temp_result, %a);
    # get the arguments
    while ( my ( $key, $value ) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    my $cmd = '/export/home/ssuser/SOFTSWITCH/BIN/ssmgmt';
    $self->{conn}->print($cmd);

    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Selection\:/i',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                           -timeout   => $self->{DEFAULTTIMEOUT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    if ($match =~ m/Enter Selection\:/i) {
        $self->{conn}->print(42);
       ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Selection\:/i',
                                                               -match     => '/\[error\]/',
                                                               -match     => $self->{PROMPT},
                                                               -timeout   => $self->{DEFAULTTIMEOUT} ); 
        
       if ($match =~ m/Enter Selection\:/i) {
            $self->{conn}->print(1);                                               
            ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Selection\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );
            $temp_result = $prematch;
            if ($match =~ m/Enter Selection\:/i) {
                $self->{conn}->print(0) ;
                ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Selection\:/i',
                                                              -match     => $self->{PROMPT},
                                                              -match     => '/\[error\]/',
                                                              -timeout   => $self->{DEFAULTTIMEOUT} );
                if ($match =~ m/Enter Selection\:/i) {
                     $self->{conn}->print(0) ;
                     unless (($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT},
                                                                   -timeout   => $self->{DEFAULTTIMEOUT} )) {
                         $logger->error(__PACKAGE__ . ".$sub: unable to complete \'$cmd\' execution");
        		 $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                         return 0;
                     }
                } else {
                    $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' unable to exit from main menu, error occured");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                    $self->{conn}->waitfor( -match => $self->{PROMPT} );
                    return 0;
                }
            } else {
                 $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unable to return to main menu, error occured");
                 $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                 $self->{conn}->waitfor( -match => $self->{PROMPT} );
                 return 0;
            }
       } elsif ($match =~ m/\[error\]/i) {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            return 0;
       } else {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
       }
    } elsif ($match =~ m/\[error\]/i) {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       $self->{conn}->waitfor( -match => $self->{PROMPT} );
       return 0;
    } else {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured $prematch, $match ");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       return 0;
    }
    
    if ( $temp_result =~ m/$a{-search_pattern}/ ) {
       $logger->debug(__PACKAGE__ . ".$sub: search successful for pattern \'$a{-search_pattern}\' in $temp_result");
       return 1;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub: search failed for pattern \'$a{-search_pattern}\' in $temp_result");
       return 0;
    }
}

=head2 slwresdmgmt () 

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
        0.       Exit
        Enter Selection: 0

=over

=item ARGUMENTS:

 Mandatory :

  -sequence     =>  ["3" , "2" ,"XX.XX.XX.XX", "5" ] . Selections as an array referance, includes selection number and ip's.

=item OUTPUT:

 Array   - Console output.
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( @result = $Obj->slwresdmgmt( -sequence => [2, "10.54.80.12", 7])) {
        $logger->debug(__PACKAGE__ . ": Could not get the ssmgmt Statistics ");
        return 0;
}

=item AUTHOR:

rpateel@sonusnet.com

=back

=cut

sub slwresdmgmt {
    my ($self, %args )=@_;
    my %a;

    my $sub = "slwresdmgmt()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".slwresdmgmt" );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a);

    unless ( defined ( $args{-sequence} ) ) {
        $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -sequence has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my (@results, $prematch, $match, $failed);

    $self->{conn}->print($self->{SLWRESDMGMT});

    my $count = 0;
    my @options = @{$args{-sequence}};

    foreach(@options){
        $logger->debug(__PACKAGE__ . ".$sub  SENDING SEQUENCE ITEM: [$_]");

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
            $self->{conn}->print($_);
        }

        my @output = split('\n', $prematch);
        push ( @results, @output, $match );
    }

    unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Selection\:/',
                                                         -match => $self->{PROMPT},
                                                         -errmode => "return",
                                                         -timeout => 5)) {
        $logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
        $logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
        $logger->debug(__PACKAGE__ . ".$sub LAST LINE:" . $self->{conn}->lastline);
    }

    
    my @output;

    if ( $match =~ /Enter Selection/ ) {
        @output = split('\n', $prematch);
        push ( @results, @output );

        $logger->debug(__PACKAGE__ . ".ssSequence  SENDING 0 AGAIN TO BREAK OUT OF SSMGMT MAIN MENU");
        $self->{conn}->print("0");
        unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT}, -errmode => "return")) {
            $logger->debug(__PACKAGE__ . ".$sub  PRE-MATCH:" . $prematch);
            $logger->debug(__PACKAGE__ . ".$sub  MATCH: " . $match);
            $logger->debug(__PACKAGE__ . ".$sub  failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            return 0;
        }
    }

    @output = split('\n', $prematch);
    push ( @results, @output );

    if ($failed) {
       $logger->error(__PACKAGE__ . ".$sub  failed to complete the operation");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }

    @results = $self->{conn}->cmd("cat $self->{SSBIN}/DNSRecordStatus.txt") if (grep(/^8$/, @options));

    $logger->debug(__PACKAGE__ . ": SUCCESS : Returning the stats in an array .");
    $logger->debug(__PACKAGE__ . ": <-- Leaving Sub [1]");

    chomp (@results);
    return @results;
}

=head2 setSigtranTimers () 

DESCRIPTION:

 -  This subroutine will set Sigtran Timers to default values, and validate them.
 -  At the runtime, it checks for the Platform whether it is Linux or Solaris and runs different commmand as applicable for the platform.

=over

=item ARGUMENTS:

   -none

=item OUTPUT:

 1       - success
 0       - Any Failure 

=item EXAMPLE:

unless ( @result = $Obj->setSigtranTimers()) {
        $logger->debug(__PACKAGE__ . ": setSigtranTimers failed ");
        return 0;
}

=item AUTHOR:

rpateel@sonusnet.com

=back

=cut

sub setSigtranTimers {
 
   my ($self, %args) = @_;
   my %display_timer;
   my  @set_timers;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSigtranTimers");
   my $sub = "setSigtranTimers()";
   my $platformtype = $self->{PLATFORM};
   if ( $platformtype eq 'linux'){
       $logger->info(__PACKAGE__ . ".$sub:platform is Linux");
   }
   unless ($self->enterRootSessionViaSU()){
       $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
       $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
       return 0;
   }

   if ( $platformtype eq 'linux') {
   # timer commands and respective values
      %display_timer = ( 'sysctl net/sctp/rto_initial' => 'net.sctp.rto_initial = 1000',
                         'sysctl net/sctp/rto_min' => 'net.sctp.rto_min = 500',
                         'sysctl net/sctp/rto_max' => 'net.sctp.rto_max = 1000',
                         'sysctl net/sctp/hb_interval' => 'net.sctp.hb_interval = 100',
                         'sysctl net/sctp/association_max_retrans' => 'net.sctp.association_max_retrans = 4');
   
      @set_timers = ('sysctl net/sctp/rto_initial=1000', 'sysctl net/sctp/rto_min=500', 'sysctl net/sctp/rto_max=1000', 'sysctl net/sctp/hb_interval=100', 'sysctl net/sctp/association_max_retrans=4');
   }
   else {
      # timer commands and respective values
      %display_timer = ( 'ndd /dev/sctp sctp_rto_initial' => 1000,
		         'ndd /dev/sctp6 sctp_rto_initial' => 1000,
                         'ndd /dev/sctp sctp_rto_min' => 500,
                         'ndd /dev/sctp6 sctp_rto_min' => 500,
                         'ndd /dev/sctp sctp_rto_max' => 1000,
                         'ndd /dev/sctp6 sctp_rto_max' => 1000,
                         'ndd /dev/sctp sctp_heartbeat_interval' => 100,
                         'ndd /dev/sctp6 sctp_heartbeat_interval' => 100,
                         'ndd /dev/sctp sctp_pa_max_retr' => 4,
                         'ndd /dev/sctp6 sctp_pa_max_retr' => 4 
                       );

      @set_timers = ('ndd -set /dev/sctp sctp_rto_initial 1000', 'ndd -set /dev/sctp sctp_rto_min 500', 'ndd -set /dev/sctp sctp_rto_max 1000', 'ndd -set /dev/sctp sctp_heartbeat_interval 100', 'ndd -set /dev/sctp sctp_pa_max_retr 4','ndd -set /dev/sctp6 sctp_rto_initial 1000', 'ndd -set /dev/sctp6 sctp_rto_min 500', 'ndd -set /dev/sctp6 sctp_rto_max 1000', 'ndd -set /dev/sctp6 sctp_heartbeat_interval 100', 'ndd -set /dev/sctp6 sctp_pa_max_retr 4');
   } 

   my (@failed_cmds, @timer_output);
   my $ret_val = 1;

   foreach my $cmd (@set_timers) {
      unless ($self->{conn}->cmd($cmd)) {
         $logger->error(__PACKAGE__ . ".$sub: failed to execute \'$cmd\' on root session");
         push (@failed_cmds, $cmd);
      }
   }

   foreach my $cmd (@failed_cmds) {
      unless ($self->{conn}->cmd($cmd)) {
         $logger->error(__PACKAGE__ . ".$sub: failed to execute \'$cmd\' second time");
      }
   }


   foreach my $cmd (keys %display_timer) {
      unless (@timer_output = $self->{conn}->cmd($cmd)) {
         $logger->error(__PACKAGE__ . ".$sub: failed to execute \'$cmd\' on root session");
         $ret_val = 0;
         $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
         $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
         $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
         
         next;
      }
      unless ($timer_output[0] == $display_timer{$cmd}) {
         $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' returned $timer_output[0] instead of $display_timer{$cmd}");
         $ret_val = 0;
      }
   }

   if ($ret_val == 1) {
      $logger->debug(__PACKAGE__ . ".$sub: successfully set all the timers");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   } else {
      $logger->debug(__PACKAGE__ . ".$sub: failed to set timers");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
   }
unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
  }

}


=head2  stopSipeProcess()

      kill the current sipe process

=over

=item Arguments : 

      None

=item Return Value:

      1 - on sucessful kill of sipe process
      0 - on any failure

=back

=cut

sub stopSipeProcess {
    my($self,%args) = @_;
    my $sub = "stopSipeProcess()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".stopSipeProcess" );
    $logger->debug(__PACKAGE__ . ".$sub Entering function");
    $args{-processName} = 'sipe';
    unless ($self->stopProcess(%args)) {
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 stopProcess()

          kill the current passed process

=over

=item Arguments : 

               -processName => proces name ( ex- sipe/pes)

=item Return Value:

                1 - on sucessful kill of sipe process
                0 - on any failure

=item Example 

     $psxObj->stopProcess(-processName => 'pes');

=back

=cut

sub stopProcess {
    my($self,%args) = @_;
    my $sub = "stopProcess()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".stopProcess" );
    $logger->debug(__PACKAGE__ . ".$sub Entering function");

    my $grepDisplay = "ps -aef | grep -i $args{-processName} | grep -v grep";
    my @process = ();
    unless ( @process = $self->{conn}->cmd($grepDisplay)) {
       $logger->error(__PACKAGE__ . ".$sub: no $args{-processName} process running");
       $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
    }

    chomp @process;
    foreach my $line (@process) {
       chomp $line;
       $line =~ s/^\s+//;
       my @temp = split(/\s+/, $line);
       $logger->debug(__PACKAGE__ . ".$sub: going to kill process id $temp[1]");
       $self->{conn}->cmd( "kill -9 $temp[1]");
       last;
    } 

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 findPatternInLog () 

DESCRIPTION:

 This subroutine searches for user passed pattern in the specified log and returns success (1) on finding it and failure (1) otherwise.
 The log path is /home/brxuser/BRX/BIN.

=over

=item ARGUMENTS:

 Mandatory :

  -process       =>  The log process. For example : "pes", "scpa" , "pipe" etc.
  -pattern       =>  Pattern to be searched for in the log.

=item PACKAGE:

 SonusQA::BRX

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( $brxObj->findPatternInLog( -process => "pes" ,
                                    -pattern => 'SsIdleTimerHandler' , )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not find the required pattern in the log ");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back

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
    
    my $logPath = $self->{LOGPATH};
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
    unless ( $self->execCmd("grep -i '$a{-pattern}' $logPath/$logName | head -1" , 5 ) ) {
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

=head2 startLogs () 

DESCRIPTION:

 This subroutine will empty the required logs and hence restart the logging.

=over

=item ARGUMENTS:

 Mandatory :

  -logs       =>  ["pes" , "pipe" , "scpa" ] . Pass the log names you want to restart.

=item PACKAGE:

 SonusQA::BRX

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 		 - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( $brxObj->startLogs( -logs => ["pes" , "pipe" , "scpa" ] ,
                                          )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not start the required logs ");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back 

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
    my $logPath = $self->{LOGPATH};
    
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

=head2 getLogs () 

DESCRIPTION:

 This subroutine will copy the specified logs to <path> specified by the user . 

=over

=item ARGUMENTS:

 Mandatory :

  -logs       =>  ["pes" , "pipe" , "scpa" ] . Pass the log names you want to restart.
  -feature    =>  specify the feature name. A directory will be created inside ~/ats_user/logs with the feature name
                  and a timestamp.
  -testcase   =>  specify the testcase id. A directory with the testcase id will be created inside the feature dir.

=item PACKAGE:

 SonusQA::BRX

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

  Local Log Path   - Success
           0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( $logpath = $brxObj->getLogs( -logs    => ["pes" , "pipe" , "scpa" ] ,
                           -feature => "BRXTEMPLATE",
                           -testcase => "tms11111" ,)) {
        $logger->debug(__PACKAGE__ . ": Could not copy the required logs ");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back

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
    my $logPath = $self->{LOGPATH};
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

    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} || $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
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
        if (&SonusQA::Base::secureCopy(%scpArgs)) {
            $logger->debug(__PACKAGE__ . ".$sub:  The log file $logName Copied from BRX to $localLogPath");
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: All the logs specified were copied successfully to $localLogPath");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [Local Log Path]");
    return $localLogPath;
}

=head2 getIntervalBetweenMsgs () 

DESCRIPTION:

 This subroutine will find the Difference in time between the first two messages specified, from the desired log and
 return the time difference.

=over

=item ARGUMENTS:

 Mandatory :

  -logWithPath       =>  Path of the log where the check has to be done. Generally, you run the getLogs() and
                         from the return path of getLogs() you append the file name reqd and pass it. Like $returnFromgetLogs/sipe.log
  -msg1               =>  specify the 1st message whose occurances is to be searched for. Ex: "INVITE" or "ACK" or "SIP\2.0", etc.
  -msg2               =>  specify the 2nd message whose occurances is to be searched for. Ex: "INVITE" or "ACK" or "SIP\2.0", etc.
  -Recv              =>  0 or 1. If the message to be searched for is "Recv From" , then set this. Else, 0, which means "Send To:".
  -msg1IntNo          =>  The 1st msg occurence number. Ex: if 1st INVITE is your first msg then pass 1 , else if 3rd INVITE then pass 3.
  -msg2IntNo          =>  The 2nd msg occurence number. Ex: if 2nd INVITE is your second msg and first msg is also an INVITE then pass 2 ,
                           else if 1st INVITE after msg1( not an INVITE ) is your second msg then pass 1.

=item PACKAGE:

 SonusQA::BRX

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

  Time Diff Between the messages In seconds - Success
           0                                - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

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

=item AUTHOR:

sonus-auto-core

=back 

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

    my $temp = '';
    map {$temp .='0'} (1..(6-$cnt));

    $logger->debug(__PACKAGE__ . ".$sub:  Time Difference found between two messages, i.e, $args{-msg1IntNo} $args{-msg1} and $args{-msg2IntNo} $args{-msg2}, in seconds : $secsdiff secs");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [Time Diff In Secs]");
    return $secsdiff;
}

=head2 handleDnsService() 

DESCRIPTION:

 This subroutine will stop/start the DNS service and also run the script on DNS.

=over

=item ARGUMENTS:

 Mandatory :

  -dnsip        =>  ip address of DNS.
  -operation    =>  star or stop
                            - start - to start the DNS service
                            - stop  - to stop the DNS service
 Optional :

  -script       => Script to be run on DNS once the DNS service is stoped
                   Example - "perl server1.pl Normal_resp.pdu"
  -kill         => 1 to stop the Script (started after DNS service stop) before starting DNS service.

=item OUTPUT:

 1       - Success.
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

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

=item AUTHOR:

rpateel@sonusnet.com

=back

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

=over

=item ARGUMENTS:

Mandatory :

  -sequence     =>  ["11" , "2" , "m" ] . here you pass the values that you want to
                                          see the output for.

PACKAGE:

GLOBAL VARIABLES USED:
 None

=item OUTPUT:

 1               - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( @result = $brxObj->configureDSCP( -sequence => [1, 'm', 'y', 'y'] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back

=cut	

sub configureDSCP {

    my ($self, %args )=@_;
    my %a;
    my $retval;
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
	
    my $DSCP_Cmd = "$self->{SSBIN}" . '/' . "configureNifAndDSCP.sh";  
	
    $logger->info(__PACKAGE__ . ".$sub: Executing DSCP command : $DSCP_Cmd");
	
    $self->{conn}->print($DSCP_Cmd);
    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
    	                                                -errmode => "return",
               	                                        -timeout => $self->{DEFAULTTIMEOUT}) ) { 
        $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO ENTER DSCP CONFIGURATION MENU SYSTEM");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
			    return 0;
                    }
		    $logger->debug(__PACKAGE__ . ".$sub: Entering value");
                    $self->{conn}->print($cmds[4]);
                    $retval=$self->leaveRootSession();
                    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
                    return $retval;
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
	            	return 0;
                    }
		    $logger->debug(__PACKAGE__ . ".$sub: Entering value");	
		    $self->{conn}->print($cmds[4]);	
            $retval=$self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
		    return $retval;
	        }
	    } 
	} else {
	    $logger->debug(__PACKAGE__ . ".$sub: Interface selected is not a valid one!");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
	    return 0;		
	}	
		
	unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please Enter the option \(1\-5\) \:/',
	                            			    -errmode => "return",
	                             			    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
 	    $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO MATCH THE SELECTION PROMPT");
	    $logger->debug(__PACKAGE__ . ".$sub: Enabling DSCP Marking failed");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
	    return 0;
        }
			
        if ($match =~ m/$self->{DSCPprompt}/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Successfully Enabled the DSCP Marking for Management/Signaling Interface");
	    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[1]");
        $retval=$self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
	    return $retval;
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
	    return 0;
        }
			
	if ($match =~ m/$self->{DSCPprompt}/i) {
	    $logger->debug(__PACKAGE__ . ".$sub: Successfully Diabled the DSCP Marking for Management/Signaling Interface");
        $retval=$self->leaveRootSession();
	    $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[$retval]");
	    return $retval;
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
	    return 0;
        }
			
        $logger->info(__PACKAGE__ . ".$sub: Successfully Modified the DSCP Marking for Management/Signaling Interface");
        $retval=$self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub[$retval]");
        return $retval;

    } elsif ($cmds[0] =~ /4/i) {
        $logger->debug(__PACKAGE__ . ".$sub: Selecting the option: Show DSCP Marking");
        $self->{conn}->print($cmds[0]);
		
        unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please provide the interface type to proceed \(m\/M for management\, s\/S for signaling\) \:/',
			                              	    -errmode => "return",
			                                    -timeout => $self->{DEFAULTTIMEOUT}) ) { 
            $logger->warn(__PACKAGE__ . ".$sub: UNABLE TO SELECT THE OPTION: Show DSCP Marking");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                return 0;
            }else{
                $logger->info(__PACKAGE__ . ".$sub: File  (DSCPstats.txt) exists! ");
                my $retval=$self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
		    return $retval;
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
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
            return 0;
        }   
    
        $logger->info(__PACKAGE__ . ".$sub: Successfully exited from DSCP config");
        $retval=$self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
        return $retval;
    } else {
  	$logger->debug(__PACKAGE__ . ".$sub: Selected option is invalid!");
    $self->leaveRootSession();
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
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

=over			

=item ARGUMENTS:

Mandatory :

 sequence     =>  ["11" , "2" , "m" ] . here you pass the values that you want to
                                          see the output for.

PACKAGE:

GLOBAL VARIABLES USED:
 None

=item OUTPUT:

 1               - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( @result = $brxObj->configureDscpMarking( -sequence => [1, 5] ,        =====>   Recover Blacklisted Servers
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not get the sipe mgmt Statistics ");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back

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

=head1 SaveAndExitDSCPConfig () 

DESCRIPTION:

 This subroutine exits from the DSCP config.
 Note:
 1. Saves and exits by Issuing option 5 from the DSCP config menu, if it matches for the selection prompt.
 2. If Selection prompt is not matched, then exits by issuing control C.

=over

=item ARGUMENTS:

None

PACKAGE:

GLOBAL VARIABLES USED:
 None

=item OUTPUT:

 1               - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

unless ( $brxObj->SaveAndExitDSCPConfig( )) {
        $logger->debug(__PACKAGE__ . " : Could not exit the DSCP config");
        return 0;
        }

=item AUTHOR:

sonus-auto-core

=back

=cut		


sub SaveAndExitDSCPConfig {
    my($self) = @_;
    my $sub = "SaveAndExitDSCPConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".SaveAndExitDSCPConfig()" );
    
    $logger->info(__PACKAGE__ . ".$sub: Entered ");

    
    $self->{conn}->print(5);

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


=head2 PSX_Stats_Collect()

    This function  just collects all the stats & logs  of PSX as requested and copies them to folder . If the path has OneCall then it treats as one call log collection and created folder under the
    give path as OneCallLog and copies logs based on given list of process. 

=over

=item Arguments:

   1. -path => Mandatory. Path where psx stats have to be collected.If the Path has onecall then it treats as One call log and stats collection
   2. -process => Optional. List of process for which logs and stats are expected.If no process is mentioned then it takes all PT default process "pes,sipe,scpa1,scpa2,scpa3,scpa4,scpa5"

=item Return Value:

    1 - on success
    0 -   on failure

=item Usage:

   my $result =  $psxObj->PSX_Stats_Collect(-path => '/test/');
   my $result =  $psxObj->PSX_Stats_Collect(-path => '/test/', -process => 'pes,scpa1')

=back

=cut

sub PSX_Stats_Collect {
    my ($self, %args )=@_;
    my $sub = "PSX_Stats_Collect";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless ( $args{-path} ) {
        $logger->error(__PACKAGE__ . ".$sub: The mandatory argument for -path has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    #If the Path has the "onecall" then we assume that this is one call log collection and store all the data in OneCallLog
    my $psx_DATA = $args{-path}."/psx_DATA";
    my $dut_Logs = $args{-path}."/dut_Logs";
    my $core_logs = $args{-path}."/Core_Logs";
    if ($args{-path} =~ m/(.*)(onecall.*)/i){
        $dut_Logs = $1."/OneCallLog";
        $psx_DATA = $1."/OneCallLog";
        $core_logs = $1."/OneCallLog";
    }

    $logger->info(__PACKAGE__ . ".$sub: Creating psx data dir : $psx_DATA");
    unless (mkpath($psx_DATA) or (-d $psx_DATA and -w $psx_DATA)) {
        $logger->error(__PACKAGE__ . ".$sub:  Exiting from function as dir:$psx_DATA cant be created and/or not writable");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Creating core logs dir : $core_logs");
    unless (mkpath($core_logs) or (-d $core_logs and -w $core_logs)) {
        $logger->error(__PACKAGE__ . ".$sub:  Exiting from function as dir:$core_logs cant be created and/or not writable");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: Creating dut logs dir : $dut_Logs");
    unless (mkpath($dut_Logs) or (-d $dut_Logs and -w $dut_Logs)) {
        $logger->error(__PACKAGE__ . ".$sub:  Exiting from function as dir:$dut_Logs cant be created and/or not writable");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my %process_hash = (
        ada => {},
        dbrepd => {},
        pipe => {},
        plm => {
            mgmt => 'plmmgmt',
            sequence => [3, 2, 3]
        },
        pes => {
            mgmt => 'ssmgmt',
            sequence => [4, 15, 22, 30, 46, 47, 52]
        },
        sipe => {
            mgmt => 'sipemgmt'
        },
        slwresd => {
            mgmt => 'slwresdmgmt'
        },
        scpa1 => {
            mgmt => 'scpamgmt4777',
            port => 4777
        },
        scpa2 => {
            mgmt => 'scpamgmt4787',
            port => 4787
        },
        scpa3 => {
            mgmt => 'scpamgmt4797',
            port => 4797
        },
        scpa4 => {
            mgmt => 'scpamgmt4807',
            port => 4807
        },
        scpa5 => {
            mgmt => 'scpamgmt4817',
            port => 4817
        }
    );

    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = 'root';
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};

    my $testResult = 1;
    my $skip = 0;

    foreach my $process (keys %process_hash){
        next unless( defined $args{-process} && $args{-process} =~ m/$process/i);
        $logger->info(__PACKAGE__ . ".$sub:  Collecting stats and logs for process: $process");

        if(exists $process_hash{$process}{mgmt}){
            my @mgmt_stats;
            if($process=~/scpa/){
                unless ( @mgmt_stats = $self->scpamgmtStats( ["3", "9", "11", "14", "16" ], $process_hash{$process}{port})){
                    $logger->error(__PACKAGE__ . ".$sub: Could not get the scpa mgmt Statistics for $process");
                    $testResult = 0;
                }
            }
            elsif($process=~/sipe/i){
                unless ( @mgmt_stats = $self->sipemgmtStats( -sequence => ["11","21" ] )) {
                    $logger->debug(__PACKAGE__ . ".$sub: Could not get the sipe mgmt Statistics");
                    $testResult = 0;
                }
            }
            elsif($process=~/slwresd/i){
                unless ( @mgmt_stats = $self->slwresdmgmt( -sequence => ["4"] )) {
                    $logger->debug(__PACKAGE__ . ".$sub: Could not get the slwresdmgmt Statistics");
                    $testResult = 0;
                }
            }
            else{
                my $res;
                ($res,@mgmt_stats) = $self->mgmtStats($self->{uc($process_hash{$process}{mgmt})}, $process_hash{$process}{sequence});
                unless ( $res ) {
                    $logger->error(__PACKAGE__ . ".$sub: Could not get the $process_hash{$process}{mgmt} Statistics");
                    $testResult = 0;
                }
            }

            my $scpa_txt = "$psx_DATA/"."$hostname"."_".$process_hash{$process}{mgmt}.".txt";
            my $fp; #File Handler Variable
            open $fp , ">", $scpa_txt;

            foreach (@mgmt_stats) {
                print $fp $_;
                chomp $_;
                $skip =1 if ($_ =~ /(Sonus SIP Engine|LWRESD|Sonus SoftSwitch|SCPA Management) Management Menu/i);
                $skip = 0 if ($_ =~ /q\.\s+Exit/i);
                next if $skip;
                $logger->info(__PACKAGE__ . ".$sub: $process_hash{$process}{mgmt} Statistics = $_");
            }
            close $fp;
        }

        $logger->debug(__PACKAGE__ . ".$sub: scp $process to $dut_Logs");

        $process = 'scpa' if($process eq 'scpa1');
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.":$self->{LOGPATH}/$process.log";
        $scpArgs{-destinationFilePath} = "$dut_Logs/${hostname}_$process.log";
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy $process file to path $dut_Logs");
            $testResult = 0;
        }
    }
	#JIRA : TOOLS-20763 - collect the conf files as part of run
	$scpArgs{-sourceFilePath} = $scpArgs{-hostip}.":".$self->{SSBIN}."/svc.conf.\*";
	$scpArgs{-destinationFilePath} = $psx_DATA;
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
		$logger->warn(__PACKAGE__ . ".$sub:  SCP failed to copy the conf files svc.conf.* to path $psx_DATA"); #just error logging no failing test
       		}
	$logger->debug(__PACKAGE__ . ".$sub:  Copied the conf files svc.conf.*  to $psx_DATA");

    #This log is available only 10.0.3 and above
    if ( SonusQA::Utils::greaterThanVersion( $self->{VERSION}, 'V10.00.03R000' ) ){
        my $psx_stats_audit = '/opt/sonus/sonusComm/logs/psx.stats.audit';
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$psx_stats_audit;
        $scpArgs{-destinationFilePath} = "$dut_Logs/${hostname}_psx.stats.audit";
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the log files :$psx_stats_audit to $dut_Logs");
            $testResult = 0;
        }
    
        #TOOLS-75395 : collecting alarms stats log from the DUT PSX 
        my $psx_stats_alarm = '/opt/sonus/sonusComm/logs/EventMgrLog.audit';
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$psx_stats_alarm;
        $scpArgs{-destinationFilePath} = "$dut_Logs/${hostname}_psx_stats_alarm";
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the log file, $psx_stats_alarm to $dut_Logs");
            $testResult = 0;
        }
    }

    #Copying the /var/log/messages
    if($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM} eq 'Linux' or $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM} eq 'Lintel'){
        my $messages = '/var/log/messages';
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$messages;
        $scpArgs{-destinationFilePath} = "$dut_Logs/${hostname}_messages";
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the log files :$messages to $dut_Logs");
            $testResult = 0;
        }
    #changing default 600 permissions for messages file as it cant be read by anyone else except from owner
    my $result = `chmod 744 $dut_Logs/${hostname}_messages`;
    }

    $logger->info(__PACKAGE__ . ".$sub: SUCCESS - All Statistics Collected.");

    #Deriving the test case id from path
    my $testCaseId = ($args{-path}  =~ m/.*\/PSX\/(PSX[0-9a-zA-Z_\-]*)\/.*/i) ? $1 : '';

    #check if the core files are present in core log folder
    my $numCores = $self->checkCore(-testCaseID => $testCaseId);
    if ($numCores > 0 ) {
        $testResult = 0;
        $logger->info(__PACKAGE__ . ".$sub:  Copying $numCores core file  to $core_logs");
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$self->{coreDirPath}/*";
        $scpArgs{-destinationFilePath} = "$core_logs";
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the core files  to $core_logs");
           $testResult = 0;
        }
        $self->{root_session}->{conn}->cmd("rm -f $self->{coreDirPath}/*");
     } elsif ($numCores < 0 ) {
         $logger->error(__PACKAGE__ . ".$sub: Failed to connect to SUT with root login and check the core files");
     } else {
         $logger->info(__PACKAGE__ . ".$sub: No core files generated in $self->{coreDirPath}");
     }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$testResult]");
    return $testResult ;
}


=head2 PSX_Stats_Clear()

    Function to Clear the SSMGMT, SCPAMGMT and SIPEMGMT Stats

=over

=item Arguments:

=item Return Value:

    1 - on success
    0 -   on failure

=item Usage:

   my $result =  $psxObj->PSX_Stats_Clear();

=back

=cut


sub PSX_Stats_Clear {
my ($self, %args )=@_;
my ($psxtmsObj1, @TESTCASES,@slwresdmgmtstats, @ssmgmt, @sipemgmt, @scpamgmt1, @scpamgmt2, @scpamgmt3, @scpamgmt4, @scpamgmt5, @testId, $tms_result, $release, $build);
my $sub = "PSX_Stats_Clear";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
my ($testId, $result);
$testId   = "2";

unless ( @sipemgmt = $self->sipemgmtStats( -sequence => ["16","22","23","28" ],
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the sipe mgmt Statistics ");
        return 0;
        }

unless ( @ssmgmt = $self->ssmgmtStats( ["5","7","9","11","13","16","23","25","27","29","31","34","40","53" ],
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the ssmgmt Statistics ");
        return 0;
        }

unless ( @scpamgmt1 = $self->scpamgmtSequence( ["4","6","10","12","15" ], 4777
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the scpa mgmt Statistics ");
        return 0;
        }

unless ( @scpamgmt2 = $self->scpamgmtSequence( ["4","6","10","12","15" ], 4787
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the scpa mgmt Statistics ");
        return 0;
        }

unless ( @scpamgmt3 = $self->scpamgmtSequence( ["4","6","10","12","15" ], 4797
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the scpa mgmt Statistics ");
        return 0;
        }

unless ( @scpamgmt4 = $self->scpamgmtSequence( ["4","6","10","12","15" ], 4807
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the scpa mgmt Statistics ");
        return 0;
        }

unless ( @scpamgmt5 = $self->scpamgmtSequence( ["4","6","10","12","15" ], 4817
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the scpa mgmt Statistics ");
        return 0;
        }
unless ( @slwresdmgmtstats = $self->slwresdmgmt( -sequence => ["5" ],
                                          )) {
        $logger->debug(__PACKAGE__ . " : Could not clear the slwresdmgmt Statistics ");
        return 0;
         }

$logger->debug(__PACKAGE__ . ".$testId: SUCCESS - All the Specified Statistics have been cleared.");

}

sub loadgen_scp { 
my ($self,%args) = @_;
my $sub = "loadgen_scp";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
my @cmd_res = ();

unless ( defined ( $args{-dest} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -dest has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

unless ( defined ( $args{-orig} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -orig has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

my $orig = $args{-orig};
my $dest = $args{-dest}."/loadGen_DATA/";

$logger->info(".$sub Creating dir : $dest");

@cmd_res = $self->execCmd("cd $orig");
if(grep ( /no.*such/i, @cmd_res)) {
    $logger->error(__PACKAGE__ . ".$sub $orig directory not present");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
}
     $logger->debug(__PACKAGE__ . ".$sub Changed working directory to $orig");

unless (mkpath($dest)) {
    $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir: $dest");
}

    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$orig/nohup*";
    $scpArgs{-destinationFilePath} = $dest;

$logger->debug(__PACKAGE__ . ".$sub: scp files $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
unless(&SonusQA::Base::secureCopy(%scpArgs)){
    $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the result files to $scpArgs{-destinationFilePath}");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
    return 0;
}
$logger->info(__PACKAGE__ . ".$sub:  SCP Success to copy the result files to $scpArgs{-destinationFilePath} ");
$logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
return 1;
}

=head2 runReplicationControlCenter
    This function is to configure db replication , to get the current stats for the slaves & copy the Replication center o/p
    to the gine file
    1) If no input is given it will read all the slaves and build hash table. It sets the $self-{ListOfSlaves} to the list of discovered
    2) If file name is given it will just copy the o/p to the file in the ats_log directory.If the Filane name has the path,then the file will be created in the same pat              h. Or if the $self->{result_path} , is set it can copy the created file to this location.
    3) If List of slaves are given it will return  the hash table for the those table.It sets the $self-{ListOfSlaves} to the list of discovered slaves also
    4) If the command options are givem it executes those command options and returns the result

=over

=item Arguments:

    -slaves => array reference of slaves
           or
    -options => arrar reference of options and its values respectively 
          or
    -file   => Name of the flle to which the replication cnter output should be copied
          or
     None :  Function will return the Hash refrence for all the slaves

=item Return Value:

    1 or hasref of stats - on success ( 1 for configuring , hash ref of stats to retrive the stats of slaves)
    0 -   on failure

=item Usage:

   To retrive stats -
      my $result = $masterPsx->runReplicationControlCenter( -slaves => ['PTPSX5']);
      Example o/p:
           'PTPSX5' => {
                        'APPLIED_SQLS' => '1872460',
                        'PENDING_SQLS' => '0',
                        'MAX_SQL_ID' => '1872460',
                        'STATUS' => 'NORMAL',
                        'VERSION' => 'V09.00.01R000',
                        'SLAVE' => 'PTPSX5'
                      }
     my $result = $masterPsx->runReplicationControlCenter();
    Example o/p: PTPSX6 & PTPSX5 are the only registered slaves in the master
           'PTPSX6' => {
                        'APPLIED_SQLS' => '1872460',
                        'PENDING_SQLS' => '0',
                        'MAX_SQL_ID' => '1872460',
                        'STATUS' => 'NORMAL',
                        'VERSION' => 'V09.00.01R000',
                        'SLAVE' => 'PTPSX5'
                      }
           Example o/p:
           'PTPSX5' => {
                        'APPLIED_SQLS' => '1872460',
                        'PENDING_SQLS' => '0',
                        'MAX_SQL_ID' => '1872460',
                        'STATUS' => 'NORMAL',
                        'VERSION' => 'V09.00.01R000',
                        'SLAVE' => 'PTPSX5'
                      }

   To configure :
     my $result = $slavePsx->runReplicationControlCenter( -options => [1,600,3,16]); 
     return 1/0
   To Copy to a file
    my $result = $masterPsx->runReplicationControlCenter( -file => 'slave.txt');

=back

=cut

sub runReplicationControlCenter {
    my ($self, %args) = @_;
    my $sub_name = "runReplicationControlCenter";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my @slaves = (); #Array of slaves consructed from replicationcenter o/p 

    unless ($self->becomeUser(-userName => 'oracle', -password => 'oracle')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed login as \"oracle\"");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($failed,$cmd) = (0,"");
    my %result = ();
    #since V09.02 the replicationcenter path is changed
    if ($self->{VERSION} =~ m /V([0-9]+\.[0-9]+)\.([0-9ABCR]+)/i) {
    	$logger->info(__PACKAGE__ . " The PSX version is $self->{VERSION} "); 
    	$cmd = 'cd /export/home/orasql/SSDB/' if ($1 < 9.02);
    	$cmd = 'cd /export/home/ssuser/SOFTSWITCH/SQL/' if ($1 >= 9.02);
    }


    $self->{conn}->cmd($cmd);

    unless ($self->{conn}->print('./ReplicationControlCenter')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run \'$cmd/ReplicationControlCenter\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $failed = 1;
    }

    unless ($failed) {
        my ($prematch, $match) = ('', '');
        if (defined $args{-options} and $args{-options}) {
            my @options = (@{$args{-options}}, 'test'); #just adding one test flag into option
            foreach my $index (0..$#options) {
                unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter.*:/i', -errmode => "return")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: did not recive '/Enter.*:/");
                    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                    $failed = 1;
                    last;
                }
                if ($index > 1 and ( $index%2 == 0)) {
                    unless ($prematch =~ /row updated/i) {
                        $logger->error(__PACKAGE__ . ".$sub_name: update failed \"row updated\" is not recived");
                        $failed = 1;
                        last;
                    }
                }
                last if ($options[$index] eq 'test');
                $logger->info(__PACKAGE__ . ".$sub_name: sending \"$options[$index]\"");
                $self->{conn}->print($options[$index]); 
            } 
        } elsif (defined $args{-file}) {
             unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter.*:/i', -errmode => "return")) {
                $logger->error(__PACKAGE__ . ".$sub_name: did not recive '/Enter.*:/");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                $failed = 1;
             }
             unless ($failed) {
	         my $fp;
                 my $line=0;
                 my @data = split ("\n", $prematch);
                 unless (open $fp , ">", "$args{-file}"){
                     $logger->error(__PACKAGE__ . ".$sub_name: Couldn't create the file :$args{-file}");
		     $failed = 1;
                 } else {
                     for ($line = 0 ; $line <= $#data; $line++){
		         print $fp "$data[$line]\n";
	             }
                     close $fp;
                 #Copying the file to the result path 
                    if (defined($self->{result_path})){
		        $logger->info(__PACKAGE__ . ".$sub_name: The result path is set so Copying $args{-file} to $self->{result_path}");
                         system ("cp $args{-file} $self->{result_path}"); 
                    }
                }
             }	
	      
	}else {
            unless (($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter.*:/i', -errmode => "return")) {
                $logger->error(__PACKAGE__ . ".$sub_name: did not recive '/Enter.*:/'");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                $failed = 1;
            }
            unless ($failed) {
                my @data = split ("\n", $prematch);

                my @keys = grep(/SLAVE/, @data);
                @keys = split(/\s+/, $keys[0]); #Reading the headers for real slave
                my @keysSlave = ('SLAVE','MAX_SQL_ID','APPLIED_SQLS','PENDING_SQLS','STATUS'); #Since the simulated slave doesn't report Version Number
                my $i = 0 ;
                foreach (@data) {
                   if (grep(/NORMAL/, $_)){
                      $slaves[$i]= (split(/\s+/,$_))[0];
		      $i++;
		  }
                }
                $logger->info(__PACKAGE__ . ".$sub_name: The slaves registered in the master are  @slaves"); 
                $self->{ListOfSlaves} = join(',',@slaves);
                @slaves = (@{$args{-slaves}}) if (defined $args{-slaves}); #if the user has passed slected list of slaves , then only those slaves are verified 
                foreach my $slave (@slaves) {
                    my @temp = grep(/$slave/i, @data);
                    unless (scalar @temp) {
                        $logger->error(__PACKAGE__ . ".$sub_name:  no record found for slave -> $slave");
                        $failed = 1;
                        last;
                    }
                    @temp = split(/\s+/, $temp[0]); #it have only one record
                    map {$result{$slave}{$keys[$_]} = $temp[$_]} 0..$#keys if ($#temp == 5); #store the content for every real slave
                    map {$result{$slave}{$keysSlave[$_]} = $temp[$_]} 0..$#keysSlave if ($#temp == 4); #store the content for every simulated slave
                }
            }
        }
        unless ($self->{conn}->cmd('0')) {
            $logger->error(__PACKAGE__ . ".$sub_name: failed to get user prompt after sending \"0\"");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $failed = 1;
        }
    }

    unless ($self->exitUser()) {
        $failed = 1;
        $logger->error(__PACKAGE__ . ".$sub_name: failed to logout from oracle login"); 
    }

    if ($failed) {
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    (@slaves) ? return \%result : return 1; 
}

=head2 checkSIPSCPStats

    This subroutine is to get all SIPSCP stats and check the given pattern exist or not

=over

=item Arguments:

    A list to check in the order of SCP Server IP, Port, Invite Sent, 2XX Received, 3XX Received, 4XX Received, 5XX Received, 6XX Received

=item Return Value:

    1 - if the given values are matching
    0 - if the given values are not matching

=item Usage:

      my $result = $psxObj->checkSIPSCPStats('10.34.15.95', 9996, 4, 0, 0, 0, 0, 0);

=back

=cut

sub checkSIPSCPStats {
	my $self= shift;
	my @args = @_;

    my $sub    = "checkSIPSCPStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my ($prematch, $match, $temp_result);

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    # Make sure scpamgmt is not currently running
    $self->stopScpamgmtCmd();

    my $cmd = $self->{SCPAMGMT};

    $self->{conn}->print($cmd);

    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice\:/i',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                           -timeout   => $self->{DEFAULTTIMEOUT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return ;
    }
	
	if ($match =~ m/Enter Choice\:/i) {
       $self->{conn}->print(42);
       ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                               -match     => '/\[error\]/',
                                                               -match     => $self->{PROMPT},
                                                               -timeout   => $self->{DEFAULTTIMEOUT} );
       if ($match =~ m/Enter Choice.*\:/i) {
            $self->{conn}->print(1);
            ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );
            $temp_result = $prematch;

            if ($match =~ m/Enter Choice.*\:/i) {
                $self->{conn}->print(0) ;
                unless (($prematch, $match) = $self->{conn}->waitfor(   -match     => $self->{PROMPT},
                                                                        -timeout   => $self->{DEFAULTTIMEOUT} )) {
                    $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' unable to exit from main menu, error occured");
        	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                    return ;
                }
            } else {
			 	$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unable to return to main menu, error occured");
	 			$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		 		$self->{conn}->waitfor( -match => $self->{PROMPT} );
	 			return ;
			}
       } elsif ($match =~ m/\[error\]/i) {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            return ;
       } else {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return ;
       }
    } elsif ($match =~ m/\[error\]/i) {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       $self->{conn}->waitfor( -match => $self->{PROMPT} );
       return ;
    } else {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured $prematch, $match ");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       return ;
    }

	if($temp_result=~/Request Timed Out/i){
		$logger->error(__PACKAGE__ . ".$sub:  Request Timed Out. $temp_result");
       	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       	return ;
	}

    my $ind = index($temp_result,'SCPA Management Menu');
    $temp_result = substr($temp_result,0,$ind);

	my @temp_result = split(/\n/,$temp_result);

	#$logger->debug(__PACKAGE__ . ".$sub: result dumper: ". Dumper(\@temp_result));

    #parsing the result
    my (@all_result, %result, $server);

	foreach (@temp_result){
    	if(/SCP\s+Server\s+IP\s+:\s+(.+)\s+Port\s+:\s+(\d+)/){ 
			$server=$1;
			my $port = $2;
			$server=~s/^\s+//;
			$server=~s/\s+$//;

			if($server=~/$args[0]/ and $port=~/$args[1]/){
				$match = 1;
			}
			else{
				$match = 0;
			}

			next;
  		}
		
		if($match and /Invite Sent\s*:\s*$args[2]/){
			$match++;
			next;
		}

		if($match and /2XX Received\s*:\s*$args[3]/){
        	$match++;
			next;
        }
		if($match and /3XX Received\s*:\s*$args[4]/){
            $match++;
			next;
        }
		if($match and /4XX Received\s*:\s*$args[5]/){
            $match++;
			next;
        }
		if($match and /5XX Received\s*:\s*$args[6]/){
            $match++;
			next;
        }
		if($match and /6XX Received\s*:\s*$args[7]/){
            $match++;
			next;
        }

		last 
			if($match == 7);
	}

	if($match == 7){
		return 1;
	}
	else{
		return 0;
	}
}

=head2 resetSIPSCPServersStats
    This subroutine is to reset stats for all SIP SCP Servers

Arguments:
    None

Return Value:
    1 - if Sip SCP Stats Resetted Sucessfully
    0 - if it fails.

Usage:
      my $result = $psxObj->resetSIPSCPServersStats();

=cut

sub resetSIPSCPServersStats{
    my $self = shift;
    my $sub    = "resetSIPSCPServersStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my ($prematch, $match, $temp_result);

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    # Make sure scpamgmt is not currently running
    $self->stopScpamgmtCmd();

    my $cmd = $self->{SCPAMGMT};

    $self->{conn}->print($cmd);

    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice\:/i',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                           -timeout   => $self->{DEFAULTTIMEOUT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return ;
    }
	
	 if ($match =~ m/Enter Choice\:/i) {
       	$self->{conn}->print(42);
       	($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                               -match     => '/\[error\]/',
                                                               -match     => $self->{PROMPT},
                                                               -timeout   => $self->{DEFAULTTIMEOUT} );
       	if ($match =~ m/Enter Choice.*\:/i) {
            $self->{conn}->print(2);
            ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );
            $temp_result = $prematch;

            if ($match =~ m/Enter Choice.*\:/i) {
                $self->{conn}->print(0) ;
                unless (($prematch, $match) = $self->{conn}->waitfor(   -match     => $self->{PROMPT},
                                                                        -timeout   => $self->{DEFAULTTIMEOUT} )) {
                    $logger->error(__PACKAGE__ . ".$sub: \'$cmd\' unable to exit from main menu, error occured");
        	    $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                    return ;
                }
            } 
			else {
			 	$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unable to return to main menu, error occured");
	 			$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		 		$self->{conn}->waitfor( -match => $self->{PROMPT} );
	 			return ;
			}
       	} 
		elsif ($match =~ m/\[error\]/i) {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            return ;
       	} 
		else {
            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return ;
       	}
    } 
	elsif ($match =~ m/\[error\]/i) {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       $self->{conn}->waitfor( -match => $self->{PROMPT} );
       return ;
    } 
	else {
       $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured $prematch, $match ");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
       return ;
    }

	if($temp_result=~/Sip SCP Stats Resetted Sucessfully/i){
		$logger->info(__PACKAGE__ . ".$sub:  Sip SCP Stats Resetted Sucessfully");
       	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		return 1;
	}
	else {
		$logger->error(__PACKAGE__ . ".$sub:  Couldn't reset Sip SCP Stats. Try again ");
		$logger->debug(__PACKAGE__ . ".$sub: result: $temp_result");
       	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		return 0;
	}
}

=head2 cleanupSCPServer

    This subroutine is to remove SIP SCP Server from stats collection

=over

=item Arguments:
    -ip => IP Address of SIP SCP Server 
	-port => SIP SCP Server Port Number

=item Return Value:

    1 - if SCP server clean up is sucessfull
    0 - if it fails.

=item Usage:

      my $result = $psxObj->cleanupSCPServer(-ip => '10.54.80.8', -port => 9996);

=back

=cut

sub cleanupSCPServer{
    my ($self, %args) = @_;
    my $sub    = "cleanupSCPServer()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my ($prematch, $match, $temp_result, %a);
    # get the arguments
    while ( my ( $key, $value ) = each %args ) { $a{$key} = $value; }

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    # Make sure scpamgmt is not currently running
    $self->stopScpamgmtCmd();

    my $cmd = $self->{SCPAMGMT};


    $self->{conn}->print($cmd);

    unless ( ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice\:/i',
                                                           -match     => '/\[error\]/',
                                                           -match     => $self->{PROMPT},
                                                           -timeout   => $self->{DEFAULTTIMEOUT},
                                                         )) {
        $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after '$cmd'.");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return ;
    }
	
	if ($match =~ m/Enter Choice\:/i) {
       $self->{conn}->print(42);
       ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                               -match     => '/\[error\]/',
                                                               -match     => $self->{PROMPT},
                                                               -timeout   => $self->{DEFAULTTIMEOUT} );
       if ($match =~ m/Enter Choice.*\:/i) {
            $self->{conn}->print(3);
            ($prematch, $match) = $self->{conn}->waitfor( -match     => '/IP Address of SIP SCP Server\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );

			if ($match =~ m/IP Address of SIP SCP Server\:/i) {
				$self->{conn}->print($a{-ip});
				($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter SIP SCP Server Port Number\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );	
				if ($match =~ m/Enter SIP SCP Server Port Number\:/i) {
					 $self->{conn}->print($a{-port});
					($prematch, $match) = $self->{conn}->waitfor( -match     => '/Do you want to continue.*\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );
					if ($match =~ m/Do you want to continue.*\:/i) {
						$self->{conn}->print('y');	
						($prematch, $match) = $self->{conn}->waitfor( -match     => '/Enter Choice.*\:/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT} );
						$temp_result = $prematch;

						if ($match =~ m/Enter Choice.*\:/i) {
							$self->{conn}->print(0) ;
							unless (($prematch, $match) = $self->{conn}->waitfor(   -match     => $self->{PROMPT},
                                                                        -timeout   => $self->{DEFAULTTIMEOUT} )) {
                    			$logger->error(__PACKAGE__ . ".$sub: \'$cmd\' unable to exit from main menu, error occured");
        				$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        			$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                    			$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                    			return ;
                			}
						} 
						else {
                			$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unable to return to main menu, error occured");
                			$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                			$self->{conn}->waitfor( -match => $self->{PROMPT} );
                			return ;
            			}
					} 
					elsif ($match =~ m/\[error\]/i) {
                        $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        $self->{conn}->waitfor( -match => $self->{PROMPT} );
                        return ;
                    } 
					else {
                        $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        return ;
                    }					
				} 
				elsif ($match =~ m/\[error\]/i) {
            		$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
            		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		            $self->{conn}->waitfor( -match => $self->{PROMPT} );
        		    return ;
		       	} 
				else {
	        	    $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            		$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	         	  	return ;
    		   	}
			} 
			elsif ($match =~ m/\[error\]/i) {
	            $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
    	        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        	    $self->{conn}->waitfor( -match => $self->{PROMPT} );
	            return ;
    	   	} 
			else {
        	    $logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	            return ;
    	   	}
		} 
		elsif ($match =~ m/\[error\]/i) {
        	$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            $self->{conn}->waitfor( -match => $self->{PROMPT} );
            return ;
    	} 
		else {
      		$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return ;
        }
	} 
	elsif ($match =~ m/\[error\]/i) {
    	$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' command error:\n$prematch\n$match");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        $self->{conn}->waitfor( -match => $self->{PROMPT} );
        return ;
  	} 
	else {
    	$logger->error(__PACKAGE__ . ".$sub:  \'$cmd\' unknown error occured after Entering selection 42");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return ;
 	}

	if($temp_result=~/SCP Server Clean Up Sucessfull/i){
		$logger->info(__PACKAGE__ . ".$sub:  SCP Server Clean Up Sucessfull");
       	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		return 1;
	}
	else {
		$logger->error(__PACKAGE__ . ".$sub:  Couldn't clean up SCP Servers. Try again ");
		$logger->debug(__PACKAGE__ . ".$sub: result: $temp_result");
       	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
		return 0;
	}
}

=head2 emsLicense()

DESCRIPTION:

    This subroutine is used to push license from EMS to the target device

=over

=item ARGUMENTS:

    1st Arg    - CLI session
    2nd Arg    - EMS IP address
    3rd Arg    - Device Name in EMS

=item PACKAGE:

    SonusQA::PSX:PSXHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::EMS::EMSHELPER::emsLicense 

=item OUTPUT:

    0   - fail
    1   - success

=item EXAMPLE:

    unless ( $psx_object->emsLicense($emsIP, $psxNameInEms) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Cannot push the license from EMS");
        return 0;
    }

=back

=cut

sub emsLicense {

    my ($self, $emsIp, $psxNameInEms) = @_;
    my $sub_name = "emsLicense";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ##################################################
    # Step 1: Checking mandatory args;
    ##################################################

    unless ( defined $emsIp ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter - EMS IP address input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    unless ( defined $psxNameInEms ) {
       $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter - PSX name in EMS input is empty or blank.");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
    }
    unless(&SonusQA::EMS::EMSHELPER::emsLicense($self,-deviceName => $psxNameInEms, -deviceType => 'PSX', -emsIP => $emsIp)){
	$logger->error(__PACKAGE__ . ".$sub_name:  Unable to push license on the EMS for PSX \'$psxNameInEms\' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 vbrRateSheetLoad()

DESCRIPTION:

    This subroutine is used to load the intermdeiate VBR rate sheet file generated from parsing. It is assumed that the files are available at the PSX basepath taken from 
    TMS alias.

=over

=item ARGUMENTS:

   Mandatory
      -IntermediateFile =>
	 File name of the intermediate file including the extension. This should be passed within '' so the . operator is escaped
   Optional
      -timeout =>
	 Timer value used to wiat for rate sheet loading. If not specified , then defailt value of 300 secs is used

=item PACKAGE:

    SonusQA::PSX:PSXHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::EMS::EMSHELPER::vbrRateSheetLoad

=item OUTPUT:

    0   - fail
    Time is secs   - success. If the Vlaue is 0 , it will return 1 , else it will return actual value

=item EXAMPLE:

    $loadtime = $psx_obj->vbrRateSheetLoad(-IntermediateFile => 'Format1RateSheet10_int.csv') ;
    if ($loadtime == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to load the rate sheet ");
        return 0;
    }

=back

=cut

sub vbrRateSheetLoad {
    my($self, %args)=@_;
    my $sub_name = 'vbrRateSheetLoad';
    my ($prematch, $match);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my ($timeTaken,$testResult) = (0,1) ;
    my $timeout = $args{-timeout} || 300;

    unless ( defined ( $args{-IntermediateFile} ) ) {
    $logger->error(__PACKAGE__ . ".$sub_name:  The mandatory argument for \'-IntermediateFile\' has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
    }

    unless ( defined ( $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH} ) ) {
    $logger->error(__PACKAGE__ . ".$sub_name:  PSX basepath is not defined in TMS Alias , the same is used as a path for VBR files .");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
    }


    unless ( $self->becomeUser(-userName =>  "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}" , -password => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} user");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless ( $self->{conn}->print("cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}\'");
        $testResult = 0;
    }

  
    $timeTaken  = time;
    my $cmd = "vbrrsldr -l $args{-IntermediateFile}";

    unless ( $self->{conn}->print("$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $testResult = 0;
    }

   
    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/rate sheet loaded successfully/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \'$cmd\' has failed, Failed to get \'rate sheet loaded successfully\'  msg");
        $testResult = 0;
    }
    $timeTaken = time - $timeTaken;
    unless ($self->{conn}->waitfor( -match     => $self->{PROMPT})) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to get prompt back");
       $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
       $testResult = 0;
    }

    unless ($self->exitUser()){
       $logger->error(__PACKAGE__ . ".$sub_name: failed to exit PSX user: $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ");
       $testResult = 0;
    }

    if ($testResult == 1 ) {
       $logger->info(__PACKAGE__ . ".$sub_name: time taken to load sheet $args{-IntermediateFile}  is :[$timeTaken]");
       $timeTaken =  1 if ($timeTaken == 0 );
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub: [$timeTaken]");
       return $timeTaken;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub: [0]");
       return 0;
    }
}

=head2 vbrRateSheetParser()

DESCRIPTION:

    This subroutine is used to parse the  VBR rate sheet . It is assumed that the files are available at the PSX basepath taken from TMS alias.

=over

=item ARGUMENTS:

   Mandatory
      -IntermediateFile =>
         File name of the intermediate file including the extension. This should be passed within '' so the . operator is escaped
      -FormatFile =>
	 File name of the format file including the extension. This should be passed within '' so the . operator is escaped
      -RateSheetFile =>
         File name of the RateSheet file including the extension. This should be passed within '' so the . operator is escaped

   Optional
      -timeout =>
         Timer value used to wiat for rate sheet parsing. If not specified , then defailt value of 300 secs is used

=item PACKAGE:

    SonusQA::PSX:PSXHELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::EMS::EMSHELPER::vbrRateSheetParser

=item OUTPUT:

    0   - fail
    Time is secs   - success. If the Vlaue is 0 , it will return 1 , else it will return actual value

=item EXAMPLE:

    $parsetime = $psx_obj->vbrRateSheetParser(-FormatFile => 'Format1Template151.dat' , -RateSheetFile => 'Format1RateSheet10.csv' , -IntermediateFile => 'Format1RateSheet10_latchou.csv');
    if ($parsetime == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Failed to parse the rate sheet ");
        return 0;
    }

=back

=cut

sub vbrRateSheetParser {
    my($self, %args)=@_;
    my $sub_name = 'vbrRateSheetParser';
    my ($prematch, $match);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    my ($timeTaken,$testResult) = (0,1) ;
    my $timeout = $args{-timeout} || 300;

    foreach ('-IntermediateFile' , '-FormatFile','-RateSheetFile' ) {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: manditory argument \'$_ \'  is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
            return 0;
        }
    }

    unless ( defined ( $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH} ) ) {
    $logger->error(__PACKAGE__ . ".$sub_name:  PSX basepath is not defined in TMS Alias , the same is used as a path for VBR files .");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
    }


    unless ( $self->becomeUser(-userName =>  "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}" , -password => "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}") ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} user");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }


    unless ( $self->{conn}->print("cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'cd $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $testResult = 0;
    }

    $timeTaken  = time;
    my $cmd = "vbrrsprsr -t $args{'-FormatFile'} -i $args{'-RateSheetFile'} -o $args{'-IntermediateFile'}";

   unless ( $self->{conn}->print("$cmd" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  unable to run \'$cmd\'");
        $testResult = 0;
    }


    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/rate sheet parsed successfully/i', -timeout   => $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub_name: \'$cmd\' has failed, Failed to get \'rate sheet parsed successfully\'  msg");
        $testResult = 0;
    }
    $timeTaken = time - $timeTaken;
    unless ($self->{conn}->waitfor( -match     => $self->{PROMPT})) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to get prompt ($self->{PROMPT}) back");
       $logger->error(__PACKAGE__ . ".$sub_name: errmsg : ". $self->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
       $testResult = 0;
    }

    unless ( $self->exitUser()){
       $logger->error(__PACKAGE__ . ".$sub_name: failed to exit PSX user : $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ");
       $testResult = 0;
    }

    if ($testResult == 1 ) {
       $logger->info(__PACKAGE__ . ".$sub_name: The time taken to parse the sheet $args{-IntermediateFile}  is :[$timeTaken]");
       $timeTaken =  1 if ($timeTaken == 0 );
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub: [$timeTaken]");
       return $timeTaken;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub: [0]");
       return 0;
    }
}


=head2  configureNifAndDSCP()

DESCRIPTION:

 This subroutine will execute '/export/home/ssuser/SOFTSWITCH/BIN/configureNifAndDSCP.sh' script.
 to configure interfaces for PSX, and configures DSCP for Management and Signaling Interface for PSX, and Verifies the configuration.

=over

=item ARGUMENTS:

 Mandatory :

  -action     =>  "modify" --If action is modify then it configures the PSX,
	      =>  "verify" --If action is verify then it verifies the configuration 
 Optional :

  -values     => Hash refernce containing the user-defined values for configuration of PSX.

=item OUTPUT:

 1       - Configuration Success
 0       - Configuration Unsuccessful  

=item EXAMPLE:

my $action = "modify";
unless ( $psxObj->configureNifAndDSCP($action)) {
        $logger->debug(__PACKAGE__ . ": Configuration Unsuccessful");
        return 0;
}
PSX Configuration with user-defined values

my $action       = "modify";
my $values = { 'Host Name'              => 'psxsvtg81_conf',
               'IP Address'             => '10.54.28.150',
               'Netmask IP'             => '255.255.255.0',
               'Gateway IP'             => '10.54.28.1',
               'Bonded Interface'       => 'y',
               'DSCP Status'            => 'y',
               'DSCP Value'             => 60,
               'IP Type'                => 'v6',
               'Signaling IP1'          => 'fd00:10:6b50:40c0::b8',
               'Signaling IP1 Prefix'   => 60,
               'Signaling Gateway IP1'  => 'fd00:10:6b50:40c0::1',
               'Signaling IP2'          => 'fd00:10:6b50:40d0::b8',
               'Signaling IP2 Prefix'   => 60,
               'Signaling Gateway IP '  => 'fd00:10:6b50:40d0::1',
               'DSCP Status Signaling' => 'y',
               'DSCP Value Signaling'  => 60
};
unless ( $psxObj->configureNifAndDSCP($action,$values)) {
        $logger->debug(__PACKAGE__ . ": Configuration Unsuccessful");
        return 0;
}
$logger->debug(__PACKAGE__ . ": Configuration successful");

  Setting DSCP value for management and signalling

my $values = {
               'DSCP Status'            => 'y',
               'DSCP Value'             => 60,
               'DSCP Status Signaling' => 'y',
               'DSCP Value Signaling'  => 60
};
unless ( $psxObj->configureNifAndDSCP($action,$values)) {
        $logger->debug(__PACKAGE__ . ": Configuration Unsuccessful");
        return 0;
}
$logger->debug(__PACKAGE__ . ": Configuration successful");

=back

=cut

sub configureNifAndDSCP
{
    my ($self,$action,$values)=@_;
    my $sub = 'configureNifAndDSCP';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub" );

    $logger->debug(__PACKAGE__ . " :Entered $sub ");
    unless ( $self->enterRootSessionViaSU( )) {
        $logger->debug(__PACKAGE__ . " $sub: Could not enter root session");
        return 0;
    }
    my (%configValues,@valuesToEnter);

    my @matchPatterns = ('Enter the Hostname for this system','Enter Management IP for this system. IPV4 only','Enter the Netmask of Management IP ','Enter the Gateway address of Management IP ','Do you want a bonded Management Interface ','Do you want to enable DSCP marking for Management interface ? ','Enter DSCP Value for Management interface','Do you want to configure signaling interface?','Enter the IP Version for Signaling Interface ','Enter First Signaling .* address','Enter .* prefix length ','Enter Gateway IP ','Enter Second Signaling .* Address','Enter .* prefix length ','Enter Gateway IP ','Do you want to enable DSCP marking for Signaling interface ? ','Enter DSCP Value for Signaling interface');
    if (defined ($values)){
        %configValues = %$values;
        @valuesToEnter = ($configValues{'Host Name'},$configValues{'IP Address'},$configValues{'Netmask IP'},$configValues{'Gateway IP'},$configValues{'Bonded Interface'},$configValues{'DSCP Status'},$configValues{'DSCP Value'},$configValues{'configure signaling interface'},$configValues{'IP Type'},$configValues{'Signaling IP1'},$configValues{'Signaling IP1 Prefix'},$configValues{'Signaling Gateway IP1'},$configValues{'Signaling IP2'},$configValues{'Signaling IP2 Prefix'},$configValues{'Signaling Gateway IP2'},$configValues{'DSCP Status Signaling'},$configValues{'DSCP Value Signaling'});

        foreach('Bonded Interface','DSCP Status','DSCP Status Signaling'){
            if($configValues{$_} =~ /^y$/i){
                $configValues{$_} = 'enabled';
            }
            elsif($configValues{$_} =~ /^n$/i){
                $configValues{$_} = 'disabled';
            }
        }
    } else {

        $configValues{'Host Name'}= $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
        $configValues{'IP Address'} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP}|| $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
        $configValues{'Netmask IP'} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NETMASK};
        $configValues{'Gateway IP'} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{DEFAULT_GATEWAY};
        $configValues{'Bonded Interface'} = 'Enabled';
        $configValues{'DSCP Status'} = 'disabled';
        $configValues{'configure signaling interface'} = 'Y';
        $configValues{'IP Type'} = 'v6';
        $configValues{'Signaling IP1'} = $self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{IPV6};
        $configValues{'Signaling IP1 Prefix'} = 60;
        $configValues{'Signaling Gateway IP1'} = $self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{DEFAULT_GATEWAY_V6};
        $configValues{'Signaling IP2'} = $self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{IPV6};
        $configValues{'Signaling IP2 Prefix'} = 60;
        $configValues{'Signaling Gateway IP2'} = $self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{DEFAULT_GATEWAY_V6};
        $configValues{'DSCP Status Signaling'} = 'disabled';

       @valuesToEnter= ($self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME},$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP},$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NETMASK},$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{DEFAULT_GATEWAY},'y','n',$configValues{'DSCP Value'},'y','v6',$self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{IPV6},60,$self->{TMS_ALIAS_DATA}->{SIGNIF}->{1}->{DEFAULT_GATEWAY_V6},$self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{IPV6},60,$self->{TMS_ALIAS_DATA}->{SIGNIF}->{2}->{DEFAULT_GATEWAY_V6},'n',$configValues{'DSCP Value Signaling'});#added $configValues{'DSCP Value'} and $configValues{'DSCP Value Signaling'} just to ensure it take null value

    }

    if ($configValues{'Signaling IP2'} =~ /^\:\:0$/ || !$configValues{'Signaling IP2'}) {
	#removing 2nd IPV6's gateway and prefix when 2nd IPV6 is not used #TOOLS-10379
	splice @matchPatterns, -4, 2;
	splice @valuesToEnter, -4, 2;
    }
    my $retval =1;
    foreach my $key (keys %configValues){
        if(! $configValues{$key}){
            $logger->debug(__PACKAGE__ . " $sub: Value is not defined for \'$key\' please check required values for configuration are assigned on TMS");
            $retval =0;
            last;
        }
    }
    unless ($retval){
    
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . " $sub Executing Configuration Script \'$self->{SSBIN}/configureNifAndDSCP.sh\'");

    $self->{conn}->print("$self->{SSBIN}/configureNifAndDSCP.sh");
    
    my ($prematch, $match);
    unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Please confirm values...../',
                                                           -match => '/Enter the Hostname for this system/',
                                                          )){
                         $logger->warn(__PACKAGE__ . ".$sub  UNABLE TO ENTER configureNifAndDSCP.sh ");
        		 $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        	 $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                 $self->leaveRootSession();
                 $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                 return 0;
              }

    my $verifyResult;
    if ($action =~ /verify/i){
        if($match !~ /Please confirm values..../){
            $logger->debug(__PACKAGE__ . " DSCP and Signaling Configuration is not done for PSX, and Action is \'verify\', to do the configuration Action should be \'modify\'");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
            return 0;
        }else{
            $logger->debug(__PACKAGE__ . " $sub: Verify Flag is set, calling sub verifyConfigureNifAndDSCP to verify configuration"); 
            $verifyResult = $self->verifyConfigureNifAndDSCP($prematch,%configValues);
            $self->{conn}->print('y');
            unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Do you want to reboot the system ? /',
                                                          )){
                         $logger->warn(__PACKAGE__ . ".$sub  UNABLE TO Confirm values  ");
                  };
            $self->{conn}->print('n');
            if($verifyResult){
                $logger->debug(__PACKAGE__ . " $sub Completed Verifying configuration.. Configuration is successful");
            $retval = $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[$retval]");
                return $retval;
            }else{
                $logger->debug(__PACKAGE__ . " $sub Completed Verifying configuration.. configuration unsuccessful");
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                return 0;
            }
       }
    }
    if($action =~ /modify/){
        if($match =~ /Please confirm values...../)  {
            $self->{conn}->print('n');
            unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter the Hostname for this system /', )) {
                       $logger->error(__PACKAGE__ . ".$sub:  UNABLE TO enter respond for Confirming values ");
        	       $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	               $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                       $self->leaveRootSession();
                       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                       return 0;
                   };

        }
        $self->{conn}->print($valuesToEnter[0]) if($match =~ m/Enter the Hostname for this system/); 
 
        for (my $i = 1;$i <= $#valuesToEnter; $i++){
            unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                           -match     => "/$matchPatterns[$i].+/",
                                                         )) {
                       $logger->error(__PACKAGE__ . ".$sub:  UNABLE TO match \'$matchPatterns[$i]\' ");
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        	$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                       $self->leaveRootSession();
                       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                       return 0;
                   }        
            $logger->debug(__PACKAGE__ . " $sub Entering value for [$matchPatterns[$i]]:  [$valuesToEnter[$i]]");

           if ($match =~ /Do you want to enable DSCP marking/){
               if ((($match =~ /\(Default: n\)/i) && !(defined($valuesToEnter[$i]))) || ($valuesToEnter[$i] eq 'n')){
                    $self->{conn}->print($valuesToEnter[$i]);
                   $i++;
               }else {
                    $self->{conn}->print($valuesToEnter[$i]);
                }
            }elsif ($match =~ /Do you want to configure signaling interface/){
               if ((grep /IP Type|Signaling/,keys %configValues)||($match =~ /\(Default: y\)/i)){
                    $self->{conn}->print('y');
               }else {
                     $self->{conn}->print('n');
                     last;
               }
           }else {
               $self->{conn}->print($valuesToEnter[$i]);
           }
        }
        unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Please confirm values..... /',
                                                     )){
                      $logger->warn(__PACKAGE__ . ".$sub  UNABLE TO ENTER response for \'want to enable DSCP marking for Signaling interface ? \' ");
        	      $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	              $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                  $self->leaveRootSession();
                  $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                      return 0;
                   }
        $verifyResult = $self->verifyConfigureNifAndDSCP($prematch,%configValues);

        $self->{conn}->print('y');
        unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Do you want to reboot the system ? /',
                                                     )){
                        $logger->warn(__PACKAGE__ . ".$sub  UNABLE TO Confirm values  ");
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        return 0;
                   };
        if($verifyResult){
            $logger->debug(__PACKAGE__ . " $sub Configuration is successful");
            $logger->debug(__PACKAGE__ . " $sub Going to reboot the system ");
            $self->{conn}->cmd('y');
            $logger->debug(__PACKAGE__ . " $sub Sleeping for 300Secs  to wait for system to come up");
            sleep(300);
            $logger->debug(__PACKAGE__ . " $sub reconnecting to  PSX");
            unless($self->reconnect(-retry_timeout => 300)){
                $logger->debug(__PACKAGE__ . " $sub Failed to make a reconnection to PSX object");
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            $logger->debug(__PACKAGE__ . " $sub Reconnecting to PSX was successfull ");

        }else{
            $logger->debug(__PACKAGE__ . " $sub Configuration is unsuccessful, coming out without rebooting the system");
            $self->{conn}->cmd('n');
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $retval=$self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$retval]");
        return $retval;
  } 
}
=head2  verifyConfigureNifAndDSCP()

DESCRIPTION:

 This subroutine is internally called by sub configureNifAndDSCP to Verify the configuration.

=over

=item ARGUMENTS:

 Mandatory :

  -scriptValues =>  It gets the current configuration values shown by configureNifAndDSCP.sh script.
  -configValues =>  These are the TMS values which we use for configuring DSCP and Signaling for PSX

=item OUTPUT:

 1       - Configuration Success
 0       - Configuration Unsuccessful

=item EXAMPLE:

    my $result =  $psxObj->verifyConfigureNifAndDSCP($scriptValues,%configValues))

=back

=cut

sub verifyConfigureNifAndDSCP {
    my($self,$result,%configValues) = @_;
    my (@new,%hash);
    my $sub = 'verifyConfigureNifAndDSCP';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub" );

    $logger->debug(__PACKAGE__ . " :Entered $sub");
    my @arr = split(/\n/,$result);
    for (my $i=0;$i <= $#arr;$i++){
        if(($arr[$i] =~ m/:/) && ($arr[$i] !~ /\(/))
        {
            push(@new,$arr[$i]);
        }
    }
    my ($attribute,$value);
    foreach(@new){
        ($attribute,$value) = split(/:\s/,$_);
        $attribute =~ s/^\s+|\s+$//;
        $value =~ s/^\s+|\s+$//;
        $attribute = $attribute." Signaling" if((defined $hash{$attribute}) && ($attribute =~ /DSCP Status/));
        $attribute = $attribute." Signaling" if(($hash{'DSCP Status Signaling'} =~ /enabled/) && ($attribute =~ /DSCP Value/));

        $hash{$attribute}="$value";
    }
    foreach my $key (keys %hash){
        if ($configValues{$key}){
            if(lc $hash{$key} eq lc $configValues{$key}){
                next;
            }else{
                $logger->debug(__PACKAGE__ . " Given value for $key [\'$configValues{$key}\'] is not matching with configured value [\'$hash{$key}\']");
                return 0;
            }
	}
    }
    return 1;
}


=head2  pt_ArchLog_crontab()

DESCRIPTION:

 This subroutine is called to turn off Archive logs on the psx and comment out the DBBackup cron job.

=over

=item ARGUMENTS:

No arguments Required
OUTPUT:
 1       - on Success
 0       - on failure

=item EXAMPLE:

    my $result =  $psxObj->pt_ArchLog_crontab()

=item Added by :

   Sukruth Sridharan (ssridharan@sonusnet.com)

=back 

=cut

sub pt_ArchLog_crontab
{
    my ($self) = @_;
    my $sub    = "pt_ArchLog_crontab";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->info( __PACKAGE__ . ".$sub: Entered Sub" );

    $logger->info( __PACKAGE__ . ".$sub: Stopping softswitch" );
    $self->startStopSoftSwitch(0);
    sleep 5;
    $logger->info( __PACKAGE__ . ".$sub: Stopped softswtich" );
    unless ($self->stopOracleDB()) 
    {
       $logger->error("$sub: Unable to stop the DB");
       return 0;
    }
    sleep 5;
    unless ($self->startOracleDB())  
    {
       $logger->error("$sub: Unable to start the DB");
       return 0;
    } 
    sleep 5;
    $logger->info( __PACKAGE__ . ".$sub: Logging in as oracle user " );
    unless ( $self->becomeUser( -userName => 'oracle', -password => 'oracle' ) )
    {
        $logger->error( __PACKAGE__ . ".$sub: failed login as \"oracle\"" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->info( __PACKAGE__ . ".$sub: Let's go to SQL path " );

    my $cmdString = "cd /export/home/ssuser/SOFTSWITCH/SQL";
    $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
    $self->{conn}->cmd("$cmdString");

    $cmdString = "crontab -l > crontab.bck";
    $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
    $self->{conn}->cmd("$cmdString");
    $cmdString = qq(grep "^#" crontab.bck | grep DbBackup.ksh | wc -l);
    $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
    my @find   = $self->{conn}->cmd($cmdString);
   # $logger->info( __PACKAGE__ . ".$sub: Command result is as follows \n ". Dumper(\@find));
    $find[0] =~ s/\s//g;
 
    $logger->info( __PACKAGE__ . ".$sub: lines:  $find[0] ");
    unless ($find[0])
    {
        $logger->info( __PACKAGE__ . ".$sub: Commenting cronjob for DbBackup.ksh" );
        $cmdString = "sed '/DbBackup.ksh/s|^|#|g' crontab.bck > crontab.new && mv crontab.new crontab.bck";
        $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
        $self->{conn}->cmd("$cmdString");

        $cmdString = "crontab crontab.bck";
        $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
        $self->{conn}->cmd("$cmdString");

        $cmdString = "crontab -l";
        $logger->info( __PACKAGE__ . ".$sub: Executing a command :-> $cmdString" );
        my @cmdResults = $self->{conn}->cmd($cmdString);
        $logger->info( __PACKAGE__ . ".$sub: crontab file is as follows\n@cmdResults");
    }

    else
    {
        $logger->info( __PACKAGE__ . ".$sub: cronjob for DbBackup.ksh is already commented" );
    }

    $self->{conn}->print("TurnOffArchivelog.ksh");

    my ( $prematch, $match );
    unless ( ( $prematch, $match ) = $self->{conn}->waitfor( -match => '/Turn off database archivelog mode ?/', ) )
    {
        $logger->fatal( __PACKAGE__ . ".$sub  UNABLE TO ENTER TurnOffArchivelog.ksh " );
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }
    $self->{conn}->print("y");
    unless (( $prematch, $match ) = $self->{conn}->waitfor(
                                      -match => "/Turning off ARCHIVELOG mode/",
                                     -match => "/Database already in NOARCHIVELOG mode/", ))
    {
        $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \[Turning off ARCHIVELOG mode\]" );
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    if ( $match =~ /Turning off ARCHIVELOG mode/ )
    {
        $logger->info( __PACKAGE__ . ".$sub: Turning off ARCHIVELOG " );
    }
    elsif ( $match =~ /Database already in NOARCHIVELOG mode/ )
    {
        $logger->info( __PACKAGE__ . ".$sub: Archive log is already disabled" );
    }
    $self->{conn}->cmd("");
    $logger->info( __PACKAGE__ . ".$sub: Going back to [ $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ] login" );
    unless($self->exitUser()){
	$logger->info( __PACKAGE__ . ".$sub: failed to exit PSX user : $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}");
	$logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" ); 
	return 0;
    }
    $logger->info( __PACKAGE__ . ".$sub: Starting softswitch" );
    $self->startStopSoftSwitch(1);
    sleep 5;
    $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
    return 1;
}


=head2  psx_newdbinstall()

DESCRIPTION:

 This subroutine is called to either replicate the existing DB present in the master on to the slave or install a fresh DB on the standalone master.
 By default it installs a fresh DB on the standalone master.

=over

=item ARGUMENTS:

No Mandatory Arguments inorder to install a fresh DB on the standalone master.
	Optional :
        -Timeout        =>  Time in seconds to wait for the Db replication to complete.
                            Default value is 7200 (Roughly 2hrs is needed for Performance DB replication on the Slave)  
Inorder to replicate the existing DB present in the master on to the slave, following arguments are required:-

   	-mastername     => Hostname of the Master PSX.
	-masterip       => IP of the Master PSX.

	Optional :
	-Timeout        =>  Time in seconds to wait for the Db replication to complete.
			    Default value is 7200 (Roughly 2hrs is needed for Performance DB replication on the Slave)	

=item OUTPUT:

 1       - on Success
 0       - on failure

=item EXAMPLE:

(i) Inorder to install a fresh DB on the standalone master:
	$psxObj->psx_newdbinstall();
(ii) Inorder to replicate the existing DB present in the master on to the slave:
	my %args;
	$args{-masterip} = $psxMasterObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
	$args{-mastername} = $psxMasterObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
	$psxObj->psx_newdbinstall(%args);

=item Added by :

   Sukruth Sridharan (ssridharan@sonusnet.com)

=back 

=cut

sub psx_newdbinstall {
        my $sub    = "psx_newdbinstall";
        my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
        $logger->info( __PACKAGE__ . ".$sub: Entered Sub" );
        my $self= shift;
        my (%args) = @_;
        my $time_out;
        if (defined ($args{-Timeout}))  {
                $time_out = $args{-Timeout} ;
        }
        else {
                #Default Timeout
                $time_out = 7200;
        }
        $logger->info( __PACKAGE__ . ".$sub: Timeout specified for the subroutine is $time_out ");
        $logger->info( __PACKAGE__ . ".$sub:Stopping softswitch" );
        $self->startStopSoftSwitch(0);
        $logger->info( __PACKAGE__ . ".$sub:Entering Root session" );
        unless ( $self->enterRootSessionViaSU() ) {
                $logger->error( __PACKAGE__ . " : Could not enter root session" );
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }
        $logger->info( __PACKAGE__ . ".$sub:Going to remove ClientAliveInterval & ClientAliveCountMax from sshd config" );
        my $cmd = "perl -pi -e 's/ClientAliveInterval [0-9]*/ClientAliveInterval 0/' /etc/ssh/sshd_config";
        $self->execCmd("$cmd");
        $cmd = "perl -pi -e 's/ClientAliveCountMax [0-9]*/ClientAliveCountMax 0/' /etc/ssh/sshd_config";
        $self->execCmd("$cmd");
        $cmd = "sudo service sshd restart";
        $self->execCmd("$cmd");
        sleep 5;
        $logger->info( __PACKAGE__ . ".$sub:Going to path  \[$self->{SSBIN}\]" );
        $self->execCmd("cd $self->{SSBIN}");
        $cmd = qq(./PSXInstall.pl -mode advance -ha standalone -install newdbinstall);
        $self->{conn}->cmd("$cmd");
        my $mastername = $args{-mastername};
        my $masterip   = $args{-masterip};
	my $retval = 1;
	my (@patternmatch,@promptresponse);

	if(SonusQA::Utils::greaterThanVersion($self->{VERSION}, 'V12.00.000')){

		@patternmatch=("Enter new password for ssuser :", "Re-type new password for ssuser :","Please confirm the above input y|Y|n|N ...","Enter new password for oracle :", "Re-type new password for oracle :","Please confirm the above input y|Y|n|N ...","Enter new password for root :","Re-type new password for root :","Please confirm the above input y|Y|n|N ...","Enter new password for admin :","Re-type new password for admin :","Please confirm the above input y|Y|n|N ...");
		@promptresponse = ("ssuser","ssuser","y","oracle","oracle","y","sonus","sonus","y","admin","admin","y");
	}
	elsif (SonusQA::Utils::greaterThanVersion($self->{VERSION}, 'V10.03.00')){
		@patternmatch = ("Do you want to use the default password for ssuser","Do you want to use the default password for oracle","Do you want to use the default password for root","Do you want to use the default password for admin");
		@promptresponse = ('y','y','y','y');
	}

	if ( ($mastername) && ($masterip) ) {
		$logger->info( __PACKAGE__ . ".$sub:Replicating MasterDB on slave" );
		push @patternmatch , ( "Is this PSX a master or slave", "Master host name", "IP address of the master system" );
		push @promptresponse , ( "s", "$mastername", "$masterip" );
	}
	else {
		$logger->info( __PACKAGE__ . ".$sub:NEWDBINSTALL on a standalone master will be performed" );
		push @patternmatch , ( "Is this PSX a master or slave", "Is this PSX a provisioning only master", "Enable PSX Test Data Access on this PSX" );
		push @promptresponse , ( "", "", "" );
	}

	my ( $prematch, $match );
	my $i = 0;
    
    for (my $i=0; $i< @patternmatch; $i++){
        $logger->debug(__PACKAGE__ . ".$sub: $i: waiting for '/$patternmatch[$i]/'");
		unless (( $prematch, $match ) = $self->{conn}->waitfor( -match => "/$patternmatch[$i]/", )){
			$logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match  \[$patternmatch[$i]\]" );
			$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
			$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
			$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
			$retval = 0;
			last ;
		}

		$logger->info( __PACKAGE__ . ".$sub: eneterin the default value ($promptresponse[$i]) for \[$patternmatch[$i]\]" );
	    $self->{conn}->print("$promptresponse[$i]");
	}
    unless($retval){
    $self->leaveRootSession();
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	return 0;
    }

	if(SonusQA::Utils::greaterThanVersion($self->{VERSION}, 'V12.00.00')){
		unless(($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter the Master DB platform password/',
					-errmode => "return",
					-timeout => 1800)){
			$logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
			$logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
			$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
			$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->leaveRootSession();
	        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
##			$self->DESTROY;
			return 0;
		}

		if(($match =~ /Enter the Master DB platform password/ )){
		    $self->{conn}->print( "dbplatform");
		    unless(($prematch, $match) = $self->{conn}->waitfor(-match =>'/Enable ACL Profile rule.+/')){
			$logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
			$logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
            $self->leaveRootSession();
	        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
			return 0;
		    }
		    if($match =~ /Enable ACL Profile rule.+/){
			$self->{conn}->print("n");
		    }
		}


		while ($prematch !~ /is setup as a Slave/) {
			unless(($prematch, $match) = $self->{conn}->waitfor(-match =>'/Enter new password for DB user system..... :/',
						-match => '/\#/',
						-errmode => "return",
						-timeout => 1800)){
				$logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
				$logger->debug(__PACKAGE__ . ".$sub Prematch : $prematch \n Match : $match ");
				$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
				$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $self->leaveRootSession();
	            $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
##				$self->DESTROY;
				return 0;
			}

			if(($match =~ /Enter new password for DB user system..... :/) )
			{
				$self->{conn}->print("\n");
			}
		}
	}
	else{
		unless (( $prematch, $match ) =
				$self->{conn}->waitfor( -match   => "/setup as a [Slave|Master]/",
					-timeout => $time_out, )) {
			$logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match  \[setup as a [Slave|Master]\]" );
			$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
			$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->leaveRootSession();
			$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
			return 0;
		}
		else {
			$logger->info( __PACKAGE__ . ".$sub: Success! \[$match\] " );
		}
		unless (( $prematch, $match ) =
				$self->{conn}->waitfor(-match => $self->{conn}->prompt,
					-errmode => "return",
					-timeout => $self->{DEFAULTTIMEOUT})){
			$logger->debug(__PACKAGE__ . ".$sub: Expected prompt was" . $self->{conn}->prompt);
			$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
			$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->leaveRootSession();
			$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
			return 0;
		}
	}	
	$logger->debug(__PACKAGE__ . ".$sub PSX configure completed successfully is setup as a Slave with $mastername ");

	unless ( $self->leaveRootSession()) {
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
		$logger->error(__PACKAGE__ . " : Could not leave the root session");
	    $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
		return 0;
	}

	$logger->info( __PACKAGE__ . ".$sub:Starting softswitch" );
	$self->startStopSoftSwitch(1);
	$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
	return 1;
}

=head2  dbchangepassword()

DESCRIPTION:

 This subroutine is called to change the PSX DB user password for user dbimpl.

=over

=item ARGUMENTS:

No arguments Required

=item OUTPUT:

 1       - on Success
 0       - on failure

=item EXAMPLE:

    my $result =  $psxObj->dbchangepassword(-dbuser => 'dbimpl',-dbpassword=>'dbimplnew6')

=item Added by :

   Vijay musigeri (vmusigeri@sonusnet.com)

=back 

=cut

sub dbchangepassword{
        my ($self,%args) = @_;
        my $sub    = "dbchangepassword";
        my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );

        unless ( $args{-dbuser} ) {
            $logger->error(__PACKAGE__ . ".$sub dbuser required");
            $logger->info(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        unless ( $args{-dbpassword} ) {
            $logger->error(__PACKAGE__ . ".$sub dbpassword required");
            $logger->info(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
        unless ($self->enterRootSessionViaSU()){
            $logger->error(__PACKAGE__ . ".$sub Failed to enter root session");
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
            return 0;
        }

        $self->{conn}->print("cd  /export/home/ssuser/SOFTSWITCH/SQL");
        my ($prematch, $match);
        ($prematch, $match) = $self->{conn}->waitfor(-match => '/.*root.*/',
                -errmode => "return",
                -timeout => $self->{DEFAULTTIMEOUT}) or do {
            $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->leaveRootSession();
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
            return 0;
        };

        if($match =~ /.*root.*/){
            $self->{conn}->print("./ChangePassword.ksh");

            ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please confirm values \(Y\|y\|N\|n\) \.\.\.\./',
                    -match => '/Enter Master\(M\) or Slave\(S\) database/',
                    -match => '/Enter new password for DB user insightuser\.\.\.\.\.\(default\:insightuser\) \:/',
                    -errmode => "return",
                    -timeout => $self->{DEFAULTTIMEOUT}) or do {
                $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after ./ChangePassword.ksh");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                return 0;
            };
        }
        my $cmd;
        if($match =~ /Enter new password for DB user insightuser\.\.\.\.\.\(default\:insightuser\) \:/){
                $cmd = $args{-dbuser} eq 'insightuser' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);
                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please confirm values \(Y\|y\|N\|n\) \.\.\.\./',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user insightuser");
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $self->leaveRootSession();
                $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                return 0;
                };

        }
        if($match =~ /Please confirm values \(Y\|y\|N\|n\) \.\.\.\./){
                $self->{conn}->print("n");

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Master\(M\) or Slave\(S\) database/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0;
                };


        }

        if($match =~ /Please confirm values \(Y\|y\|N\|n\) \.\.\.\./){
                $self->{conn}->print("n");

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter Master\(M\) or Slave\(S\) database/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0;
                };


        }

        if($match =~ /Enter Master\(M\) or Slave\(S\) database/){
                $self->{conn}->print("M");
                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user system.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }
        if($match =~ /Enter new password for DB user system.*/){
                $cmd = $args{-dbuser} eq 'system' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user platform.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user system");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }
        if($match =~ /Enter new password for DB user platform.*/){
                $cmd = $args{-dbuser} eq 'platform' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user dbimpl.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user platform");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }
        if($match =~ /Enter new password for DB user dbimpl.*/){
                $cmd = $args{-dbuser} eq 'dbimpl' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user dbquery.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user dbimpl");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }

        if($match =~ /Enter new password for DB user dbquery.*/){
                $cmd = $args{-dbuser} eq 'dbquery' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user hssowner.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user dbquery");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }
        if($match =~ /Enter new password for DB user hssowner.*/){
                $cmd = $args{-dbuser} eq 'hssowner' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);
                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Enter new password for DB user insightuser.*/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user hssowner");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0; };

        }
        if($match =~ /Enter new password for DB user insightuser.*/){
                $cmd = $args{-dbuser} eq 'insightuser' ? $args{-dbpassword} : "";
                $self->{conn}->print($cmd);

                ($prematch, $match) = $self->{conn}->waitfor(-match => '/Please confirm values/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user insightuser");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0;
                };
        }
        if($match =~ /Please confirm values/){
                $self->{conn}->print("y");

                ($prematch, $match) = $self->{conn}->waitfor(-match     => '/root/',
                                -errmode => "return",
                                -timeout => $self->{DEFAULTTIMEOUT}) or do {
                        $logger->warn(__PACKAGE__ . ". $sub unable to get required prompt after Enter new password for DB user insightuser");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $self->leaveRootSession();
                        $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
                        return 0;
                };


        }
unless ($self->leaveRootSession()){
    $logger->error(__PACKAGE__ . ".$sub Failed to leave root session");
    $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
    return 0;
  }

        if($match =~ /root/){ 
            $logger->debug(__PACKAGE__ . ".$sub Leaving Sub[0]");
            return 1;
        }
}

=head2 configureEpsxFromDumpfile()

This subroutine configures ePSX from a dump file

=over

=item Arguments :

   The mandatory parameters are
         $psxObj  - ePSX Object
         $sbxObj  - SBX object 5k or bluefin
         $dumpPath  - ePSX DB dump source file path to copy
         $edumpFileName  - ePSX  DB dump file ePSX*.tar.dmp source file to copy

=item Return Values :

   0 : failure
   1 : Success

=item Example :

 SonusQA::PSX::PSXHELPER::configureEpsxFromDumpfile(     $psxObj,
                                                         $sbxObj,
                                                         $dumpPath,
                                                         $edumpFileName );

=item Added by :

   Bhojappa, Kavan (kbhojappa@sonusnet.com)

=back

=cut

sub configureEpsxFromDumpfile
{
        my ( $psxObj, $sbxObj, $dumpPath, $edumpFileName ) = @_;
	my $sub    = "configureEpsxFromDumpfile";

        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");


        # get the required information from TMS
        my $rootPassword = $sbxObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
        my $linuxPassword = $sbxObj->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD};
        my $iPAddress    = $sbxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} || $sbxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
        my $sbxObjroot;
        my $psxIPAddress    = $psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP} || $psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6};
        my $psxRootPasswrd    = $psxObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
        my $psxUserName     = "oracle";
        my $psxUserPassword = "oracle";

        # ftp the dir
        my $destination_path = "/export/home/oracle/admin/SSDB/udump/";
        my $source_path = "$dumpPath/$edumpFileName";


                 $logger->debug( __PACKAGE__ . ".$sub: psxIPAddress => $psxIPAddress, psxUserName => $psxUserName" );
         # transfer the file
        my %scpArgs;

                $scpArgs{-hostip}              = $psxIPAddress;
                $scpArgs{-hostuser}            = $psxUserName;
                $scpArgs{-hostpasswd}          = $psxUserPassword;
                $scpArgs{-scpPort}             = 22;
                $scpArgs{-sourceFilePath} = $source_path;;
                $scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."$destination_path";


             unless ( &SonusQA::Base::secureCopy(%scpArgs) )
                {
                        $logger->error( __PACKAGE__ . ".$sub:  SCP ePSXdump  failed to copy the files" );
                        $logger->debug( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        return 0;
                }
                $logger->debug( __PACKAGE__ . ".$sub:  file $edumpFileName transfered to \($psxIPAddress\) PSX" );

        $logger->info(__PACKAGE__ . ".$sub:  SCP Success to copy $edumpFileName ");


       # STOP Sxb to import dump
       unless ($sbxObjroot = SonusQA::SBX5000::SBX5000HELPER::makeRootSession( -obj_host => $iPAddress,  -obj_password => $linuxPassword, -sessionlog => 1)) {
       $logger->error(__PACKAGE__ . ".$sub:  unable to make root connection" );
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
               return 0;
               }


       my $cmd = 'service sbx stop';
       my $timeout = 300;
       my ($cmdStatus , @cmdResult) =  SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($sbxObjroot,$cmd,$timeout);
       unless ($cmdStatus){
           $logger->error(__PACKAGE__ . ".$sub:   $cmd unsuccessful  ");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
           return 0;
       }
              $logger->info( __PACKAGE__ . ".$sub:Success:****---- SBX STOP----****  Succesfull wait 40 sec" );

       sleep(40);
                  $logger->info( __PACKAGE__ . ".$sub: Logging in as oracle user " );
        unless ( $psxObj->becomeUser( -userName => 'oracle', -password => 'oracle' ) )
        {
        $logger->error( __PACKAGE__ . ".$sub: failed login as \"oracle\"" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
        }


        my $cmdpath1 = "bash";
         unless ( $psxObj->{conn}->cmd(String => "$cmdpath1", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \$\] Failed @ wait" );
	        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
       		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
       		$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
		}               
		 $logger->info( __PACKAGE__ . ".$sub:Success:****---- $----Bash enable for oracle****   \[$\] " );



        my $cmdpath2 = "source ~/.profile";
        unless ( $psxObj->{conn}->cmd(String => "$cmdpath2", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \$\] Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
			}
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- $----source sqplus profile for oracle****   \[$\] " );


	my $cmdpath3 = "cd /export/home/ssuser/SOFTSWITCH/SQL";
        unless ( $psxObj->{conn}->cmd(String => "$cmdpath3", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \$\] Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0; }
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- $----Let's go to SQL path for oracle****   \[$\] " );


        $logger->info( __PACKAGE__ . ".$sub: Restore eSPX dump file In Progress  " );
        my $cmdDB = "./ePSXRestore -file $destination_path/$edumpFileName";

        my ($match,$prematch);
        $psxObj->{conn}->print("$cmdDB");
       unless ( ($match,$prematch) = $psxObj->{conn}->waitfor(
                                     -match => "/Done. Data restore ./",
                                          -timeout => 1800 ))
        {
        $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \[Done. Data restore\] Restore Failed @ wait" );
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****----  Epsx IMPORTing DUMP----****   \[Done. Data restore\] " );
               $logger->info( __PACKAGE__ . "ePSXRestore........  successfully completed" );



        $psxObj->{conn}->cmd("\n");
        $psxObj->{conn}->cmd("exit");
        $psxObj->{conn}->cmd("exit");
        sleep(30);

                       $logger->info( __PACKAGE__ . ".$sub: Logging in as root user " );
        unless ( $psxObj->becomeUser( -userName => 'root', -password => "$psxRootPasswrd" ) )
        {
        $logger->error( __PACKAGE__ . ".$sub: failed login as \"root\"" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
        }


        my $cmdpath4 = "cd /export/home/ssuser/SOFTSWITCH/SQL";
         unless ( $psxObj->{conn}->cmd(String => "$cmdpath4", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \$\] Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- $---Let's go to SQL path for root****   \[#\] " );




                $logger->info( __PACKAGE__ . ".$sub: UpdateDb ePSX  In Progress  " );

  	my $cmd5 = "./UpdateDb";
        $psxObj->{conn}->print("$cmd5");
        unless ( ($match,$prematch) = $psxObj->{conn}->waitfor(
                                      -match => "/Auto Start and Auto Stop/",
                                        -timeout => 1800 ))
         {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \[Auto Start and Auto Stop\] Restore Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- UDPATE Epsx DUMP----****  \[Auto Start and Auto Stop\] " );
               $logger->info( __PACKAGE__ . "UpdateDb........  successfully completed" );


        sleep(30);


        $psxObj->{conn}->cmd("\n");


        #configure EPSX
        my $cmdString5 = "cd /export/home/core/";
         unless ( $psxObj->{conn}->cmd(String => "$cmdString5", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \#\] Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- $---Delete previous Cores----/export/home/core****   \[#\] " );


        my $cmdString1 = "rm -rf *";
         unless ( $psxObj->{conn}->cmd(String => "$cmdString1", Prompt => $psxObj->{DEFAULTPROMPT}))
        {
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match \#\] Failed @ wait" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- $---Delete previous Cores- rm -Rf---/export/home/core****   \[#\] " );




        $psxObj->{conn}->cmd("exit");

        $logger->info( __PACKAGE__ . ".$sub: pointing DB to DEFAULT_Epsx  " );

        my $chk_DB_name = "sed -i 's|ssmgr_config=DEFAULT[a-zA-Z_]*|ssmgr_config=DEFAULT_Epsx|g' /export/home/ssuser/SOFTSWITCH/BIN/start.ssoftswitch";
        my $chk_DB_name2 = "sed -i 's|ssmgr_config=DEFAULT[a-zA-Z_]*|ssmgr_config=DEFAULT_Epsx|g' /export/home/ssuser/SOFTSWITCH/BIN/start_active.epx";
	my @cmdResults ;
  	unless (  @cmdResults = $psxObj->{conn}->cmd($chk_DB_name) )
        {
                $logger->info( __PACKAGE__ . ".$sub: failed to execute the command : $chk_DB_name" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****----udpated start.ssoftswitch to DEFAULT_Epsx " );

        unless (  @cmdResults = $psxObj->{conn}->cmd($chk_DB_name2) )
        {
                $logger->info( __PACKAGE__ . ".$sub: failed to execute the command : $chk_DB_name2" );
                $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $psxObj->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $psxObj->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $psxObj->{sessionLog2}");
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;}
                $logger->info( __PACKAGE__ . ".$sub:Success:****----update start_active.epx to DEFAULT_Epsx " );




        $logger->debug( __PACKAGE__ . " : Disable Oracle backup and archive logs " );

        unless ( $psxObj->pt_ArchLog_crontab() )
                        {
                        $logger->error( __PACKAGE__ . ": could not Disable DbBackup cronjob and archive logs PSX MASTER object" );
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                        return 0;
                        }
                        $logger->info( __PACKAGE__ . ".$sub:Sleeping for 100 seconds" );
                        sleep 100;

        my $cmdStart = 'service sbx start';
        $timeout = 30;
        ($cmdStatus , @cmdResult) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($sbxObjroot,$cmdStart,$timeout);
        unless ($cmdStatus){
            $logger->error(__PACKAGE__ . ".$sub:   $cmd unsuccessful  ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
                $logger->info( __PACKAGE__ . ".$sub:Success:****---- SBX START----****  Succesfull wait untill its UP" );
        sleep(20);


	#Verify the SBX is UP instead of Blind sleep and waiting to come up  

	my $count =1;

	while ($count < 6){
    	my $cmd = "service sbx status";
    	my $timeout = 20;
    	my ($cmdStatus5 , @cmdResult5) = SonusQA::SBX5000::SBX5000HELPER::_execShellCmd($sbxObjroot,$cmd,$timeout);

    	if (my @check = grep { /\[active\]/i} @cmdResult5){
        $logger->debug(__PACKAGE__ . "$sub: OK service is UP .... count=$count\n " . Dumper(\@check));
        $logger->info( __PACKAGE__ . "$sub: Successfully configured EPSX with  performance DB $edumpFileName" );
		last;
		}
    	else{
		$logger->info(__PACKAGE__ . "$sub: Oh ...Busy Still trying to make BOX UP Checking after 30 sec and Re - Check=$count" );
    		}
	$count ++;
	sleep 30;
	}

	 
	if ($count == 6){
	$logger->info(__PACKAGE__ . "$sub: Wait for 5 times completed ...Dickhoo...... KILL THE SUITE Check the SBX issue ");
	$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
	return 0;
	}
	
	$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
	return 1; 

}




=head2 makeScpaConfs()

	This subroutine configures svc.conf files for scpa processes by modelling it after svc.conf.scpa which is the conf file for default scpa process.

=over

=item Arguments :

	No mandatory parameters necessary. Default conf file names and respective port numbers will be set in accordance with Performance AT&T DB.

=item Optional :

Say for example, you want to bring up processes scpa2 and scpa3 using svc.conf.scpa2 and svc.conf.scpa3 conf files, then;

	(i)   conf file names can be specified as
		$args{"conf_files"} = ["svc.conf.scpa2", "svc.conf.scpa3"];

	(ii)  port numbers for makeScpaCfgMgmtTask can be specified as
		$args{"makeScpaCfgMgmtTask"} = [4788,4798];

	(iii) port numbers for make_pes_handler can be specified as
		$args{"make_pes_handler"} = [3070,3080];

	(iv)  port numbers for make_mgmt_handler can be specified as
		$args{"make_mgmt_handler"} = [4787,4797];

	(v)   port numbers for make_sipscpa_handler can be specified as
		$args{"make_sipscpa_handler"} = [3079,3189];

	(vi)  port numbers for make_sipV6scpa_handler can be specified as
		$args{"make_sipV6scpa_handler"} = [3079,3189];

	(vii) port numbers for make_vcc_worker can be specified as
 		$args{"make_vcc_worker"} = [3107,3117];

=item Return Values :

	0 : failure
	1 : Success

=item Example :

	$psxObj->makeScpaConfs(%args);

=item Added by :

	Sukruth Sridharan (ssridharan@sonusnet.com)

=back

=cut

sub makeScpaConfs
{

        my ($self,%args) = @_;
        my $sub = "makeScpaConfs";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->info( __PACKAGE__ . ".$sub : Entering $sub");

        unless(defined ($args{"conf_files"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use default conf file names");
                $args{"conf_files"} = [ "svc.conf.scpa2", "svc.conf.scpa3", "svc.conf.scpa4", "svc.conf.scpa5" ];
        }

        unless(defined ($args{"makeScpaCfgMgmtTask"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for makeScpaCfgMgmtTask");
                $args{"makeScpaCfgMgmtTask"} = [4788,4798,4808,4818];
        }

        unless(defined ($args{"make_pes_handler"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for make_pes_handler");
                $args{"make_pes_handler"} = [3070,3080,3091,3100];
        }

        unless(defined ($args{"make_mgmt_handler"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for make_mgmt_handler");
                $args{"make_mgmt_handler"} = [4787,4797,4807,4817];
        }

        unless(defined ($args{"make_sipscpa_handler"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for make_sipscpa_handler");
                $args{"make_sipscpa_handler"} = [3079,3189,3199,3209];
        }

        unless(defined ($args{"make_sipV6scpa_handler"})) {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for make_sipV6scpa_handler");
                $args{"make_sipV6scpa_handler"} = [3079,3189,3199,3209];
        }

        unless(defined ($args{"make_vcc_worker"}))        {
                $logger->info( __PACKAGE__ . ".$sub : will use port values for make_vcc_worker");
                $args{"make_vcc_worker"} = [3107,3117,3127,3137];
        }
	
	my ( $prematch, $match );
	my $cmd = qq(cd $self->{SSBIN});
        $self->{conn}->print($cmd);
        unless (( $prematch, $match ) = $self->{conn}->waitfor( -match => $self->{conn}->prompt, -timeout => $self->{DEFAULTTIMEOUT})){
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match prompt after executing command $cmd" );
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
		return 0;
        }
        $logger->info( __PACKAGE__ . ".$sub: Successfully executed $cmd" );

	$cmd = qq(chmod 777 svc.conf.scpa);
	$self->{conn}->print($cmd);
        unless (( $prematch, $match ) = $self->{conn}->waitfor( -match => $self->{conn}->prompt, -timeout => $self->{DEFAULTTIMEOUT})){
                $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match prompt after executing command $cmd" );
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }
        $logger->info( __PACKAGE__ . ".$sub: Successfully executed $cmd" );

        my $i = 0;
        foreach(@{$args{"conf_files"}}) {
                $logger->info( __PACKAGE__ . ".$sub : Creating $_");
                $self->execCmd("cp svc.conf.scpa $_");
                my $file = $_;
                foreach("makeScpaCfgMgmtTask","make_pes_handler","make_mgmt_handler","make_sipscpa_handler","make_sipV6scpa_handler","make_vcc_worker"){
				$cmd = qq(perl -pi -e 's|\($_.*\)-l ([0-9]+)|\$1-l $args{"$_"}[$i]|g' $file);
                                $self->{conn}->print($cmd);
        			unless (( $prematch, $match ) = $self->{conn}->waitfor( -match => $self->{conn}->prompt, -timeout => $self->{DEFAULTTIMEOUT})){
        			        $logger->error( __PACKAGE__ . ".$sub:  UNABLE TO match prompt after executing command $cmd" );
        	        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        	        	$logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        			        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        			        return 0;
        			}
			        $logger->info( __PACKAGE__ . ".$sub: Successfully executed $cmd" );
                }
                $logger->info( __PACKAGE__ . ".$sub : successfully configured $_");
		$i++;
        }
        $logger->info( __PACKAGE__ . ".$sub :  <-- Leaving Sub [1]");
        return 1;


}


=head2 runDbDiagksh()

        This subroutine runs DbDiag.ksh script on the PSX box.

=over

=item Arguments :

        No mandatory parameters necessary. 

=item Return Values :

        0 : failure
        1 : Success

=item Example :

        $psxObj->runDbDiagksh();

=item Added by :

        Sukruth Sridharan (ssridharan@sonusnet.com)

=back

=cut

sub runDbDiagksh
{

        my ($self,%args) = @_;
        my $sub = "runDbDiagksh";
	my $testresult = 1;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->info( __PACKAGE__ . ".$sub : Entering $sub");
    	$logger->info( __PACKAGE__ . ".$sub: Logging in as oracle user " );
    	unless ( $self->becomeUser( -userName => 'oracle', -password => 'oracle' ) )
    	{
    	    $logger->error( __PACKAGE__ . ".$sub: failed login as \"oracle\"" );
    	    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
    	    return 0;
    	}
    	$logger->info( __PACKAGE__ . ".$sub: Let's go to SQL path " );

    	foreach("/export/home/ssuser/SOFTSWITCH/SQL/DbDiag.ksh S","/export/home/ssuser/SOFTSWITCH/SQL/DbDiag.ksh F")
	{
    		unless($self->execCmd("$_",900)) #Could take at least 10 mins on solaris box with huge DB
		{
            		$logger->error( __PACKAGE__ . ".$sub: failed to execute command \"$_\"" );
            		$testresult = 0;
			last;
        	}
	}
    	$logger->info( __PACKAGE__ . ".$sub: Going back to [ $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ] login" );
	unless ( $self->exitUser()){
           $logger->error(__PACKAGE__ . ".$sub: failed to exit PSX user : $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} ");
           $logger->debug(__PACKAGE__ . ".$sub: Leaving sub");
	   return 0; 
        }
	$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [$testresult]" );
	return $testresult;


}
# ******************* INSERT ABOVE THIS LINE:

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

sub taillogs {

    my ($self,$log)=@_;
    my $sub = "remove_logs ()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub entering function.");
    my (@result,$sourcefilename,$logfilename);
    my @array = @$log;

    $ENV{PSX_LOG} = $ENV{PSX_LOG} || 12345;
    #Checking to ensure 2 tails are not run for the same case. 
    @result = $self->execCmd("ps -eaf | grep tee | grep $ENV{PSX_LOG} | grep -v grep | awk '{print \$2}'");
    if(!$result[0])
    {
        foreach(@array)
        {

            # Prepare $log name and removing the logs for the previous case. 
            my $logfilename = "$_"."-".$ENV{PSX_LOG}."\.log";
            $logger->debug(__PACKAGE__ . "$sub destination log filename : $logfilename ");
            @result = $self->execCmd("rm -rf $logfilename");

            $logger->debug(__PACKAGE__ . ".$sub Deleting older logs");
        }
        #Assigning the enviornment variable for the new log name.
        my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
        $ENV{PSX_LOG} = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$month+1,$day,$hour,$min,$sec;

        foreach(@array)
        {
            my $logfilename = "$_"."-".$ENV{PSX_LOG}."\.log";
            # Prepare $log name

            $logger->debug(__PACKAGE__ . "$sub destination log filename : $logfilename ");
            $sourcefilename = $_.".log";
            $self->execCmd("cd $self->{LOGPATH}");
            #tailing the required logs into the new file name
            @result = $self->execCmd("nohup tail -f $self->{LOGPATH}/$sourcefilename  | tee $logfilename > /dev/null &");
            $logger->debug(__PACKAGE__ . "$sub Result : @result");
            chomp($result[0]);

            $logger->debug(__PACKAGE__ . ".$sub start tail for $log,Process id set");
        }
    }
    return 1;

} # End taillogs

sub stopPSXLog {

    my ($self, %args ) = @_ ;
    my $sub = "stopPSXLog()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub Entering function.");
    my @result;

    @result = $self->execCmd("kill -9 `ps -eaf | grep tee | grep $ENV{PSX_LOG} | grep -v grep | awk '{print \$2}'`");
    sleep 3;
    @result = $self->execCmd("echo \$?");
    chomp($result[0]);

    if ($result[0]) {
        $logger->error(__PACKAGE__ . ".$sub tail could not be stopped");
        }
    else {
        $logger->debug(__PACKAGE__ . ".$sub tail has been stopped");
        } # End if
}


=head2 migrateSvcTaskonV6()

        This subroutine migrates tasks on V6 in svc.conf files on the PSX box.

=over

=item Arguments :

        Hash having process names and task names 

=item Return Values :

        0 : failure
        1 : Success

=item Example :

        my %svcTasks = (
        pes_task1 => 'TimerTask',
        pes_task2 => 'PesCfgMgmtTask',
        pes_task3 => 'SipeTask',
        sipe_task1 => 'TimerTask',
        sipe_task2 => 'SipV6Task',
	);
        $psxtmsObj->migrateSvcTaskonV6(\%svcTasks);

=item Added by :

        $psxtmsObj->migrateSvcTaskonV6(\%svcTasks);
        Srot Sinha (sasinha@sonusnet.com)

=back

=cut

sub migrateSvcTaskonV6 {

    my ($self, $taskhash) = @_;
    my $sub = "migrateSvcTaskonV6()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    unless($self->enterRootSessionViaSU()){
        $logger->error(__PACKAGE__ . ".$sub: Failed to enter root session");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my %svcTasks = %{$taskhash};
    $self->execCmd('cp /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.pes /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.pes.bkp');
    $self->execCmd('cp /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.sipe /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.sipe.bkp');
    $self->execCmd('cp /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.slwresd /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.slwresd.bkp');
    $self->execCmd('cp /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.scpa /export/home/ssuser/SOFTSWITCH/BIN/svc.conf.scpa.bkp');
    foreach my $key (keys %svcTasks) {
        my ($filename) = split(/_/, $key);
        $filename = '/export/home/ssuser/SOFTSWITCH/BIN/svc.conf.' . $filename;
        my $taskname = $svcTasks{$key};
        $logger->debug(__PACKAGE__ . ".$sub Task name = $taskname in filename = $filename");
        my @cmdResult;
        @cmdResult = $self->execCmd("grep \"\\b$taskname Service_Object\\b\" $filename | wc -l");
        chomp @cmdResult;
        unless($cmdResult[0] ne '0'){
            $logger->debug(__PACKAGE__ . ".$sub Task name  $taskname not found in filename $filename. Skipping this task");
            next;
        }
        $self->execCmd("sed -i -e 's/^#\\(.*\\)\\b$taskname Service_Object\\b\\(.*\\)\$/\\1$taskname Service_Object\\2/g' $filename");
        unless( $taskname eq 'TimerTask' or $taskname =~ 'CfgMgmtTask'){
        $self->execCmd("sed -i -e '/-v\\s*6/! s/^\\(.*\\)\\b$taskname Service_Object\\b\\(.*\\)\"\\s*\$/\\1$taskname Service_Object\\2 -v 6\"/g' $filename");
        }
        @cmdResult = $self->execCmd("sed  -n '1,/^.*\\b$taskname Service_Object\\b.*\"\\s*\$/p' $filename | tail -2 | head -1 | grep \"Add -K\" | wc -l");
        chomp @cmdResult;
        if ($cmdResult[0] ne '0'){
            $self->execCmd("sed -i -e '/-K/! s/^\\(.*\\)\\b$taskname Service_Object\\b\\(.*\\)\"\\s*\$/\\1$taskname Service_Object\\2 -K\"/g' $filename");
        }
        $logger->debug(__PACKAGE__ . ".$sub Task name $taskname present in filename $filename is migrated on v6");
    }

    unless ( $self->leaveRootSession()) {
        $logger->error(__PACKAGE__ . ".$sub: Could not leave the root session");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 ipv6Configure

        This subroutine configures IPv6 addresses on PSX eth0 and /etc/hosts file

=over

=item Arguments :

        --- 

=item Return Values :

        0 : failure
        1 : Success

=item Example :

        $psxtmsObj->ipv6Configure;

=item Added by :

        Srot Sinha (sasinha@sonusnet.com)

=back

=cut


sub ipv6Configure{
    my($self) = @_ ;
    my $sub = 'ipv6Configure';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $self->enterRootSessionViaSU();
    my $psx_ipv6= $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'IPV6'};
    my $psx_ipv6_gateway= $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'DEFAULT_GATEWAY_V6'};
    my $psx_ipv6prefix= $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'IPV6PREFIXLEN'};
    my $psxname = $self->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'NAME'};

    $self->execCmd("grep -q \"NETWORKING_IPV6=yes\" \"/etc/sysconfig/network\" || echo \"NETWORKING_IPV6=yes\" >> \"/etc/sysconfig/network\"");
    $self->execCmd("grep -q \"IPV6INIT=yes\" \"/etc/sysconfig/network-scripts/ifcfg-eth0\" || echo \"IPV6INIT=yes\" >> \"/etc/sysconfig/network-scripts/ifcfg-eth0\"");
    $self->execCmd("grep -q \"IPV6ADDR=$psx_ipv6/$psx_ipv6prefix\" \"/etc/sysconfig/network-scripts/ifcfg-eth0\" || echo \"IPV6ADDR=$psx_ipv6/$psx_ipv6prefix\" >> \"/etc/sysconfig/network-scripts/ifcfg-eth0\"");
    $self->execCmd("grep -q \"IPV6_DEFAULTGW=$psx_ipv6_gateway\" \"/etc/sysconfig/network-scripts/ifcfg-eth0\" || echo \"IPV6_DEFAULTGW=$psx_ipv6_gateway\" >> \"/etc/sysconfig/network-scripts/ifcfg-eth0\"");
    $self->execCmd("service network restart");          
    $self->execCmd("grep -q \"$psx_ipv6\" \"/etc/hosts\" || echo \"$psx_ipv6    $psxname\" >> \"/etc/hosts\"");

    # Leaving root session
    unless ( $self->leaveRootSession()) {
        $logger->error(__PACKAGE__ . ".$sub Could not leave the root session");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    sleep 10;
    my ($primary_ip, $secondary_ip4,$secondary_ip6) = SonusQA::Utils::getSystemIPs(-host => "localhost" );
         
    unless($self->execCmd("ping6 -c 5 -I $psx_ipv6 $secondary_ip6->[0]")){
        $logger->error(__PACKAGE__ . ".$sub Not able to ping IPV6 gateway");
        return 0;
    }
    if("@{$self->{CMDRESULTS}}" =~ /0% packet loss/ ) {
        $logger->debug(__PACKAGE__ . ".$sub IPV6 is configured successfully");
        return 1;
    }
    $logger->error(__PACKAGE__ . ".$sub Not able to ping IPV6 gateway");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");

return 0;
}

=head2 collectLogs

        This subroutine collects logs for all PSXs.

=over

=item Arguments :

       -path : Path to copy the logs

=item Return Values :

        0 : failure
        1 : Success

=item Example :

        $psxObj->collectLogs(-path => "/home/user/ats_repos/lib/perl/QATEST/<FEATURE NAME>/DUT/<FEATURE NAME>");

=back

=cut
#TOOLS - 18097
sub collectLogs{
    my($self,%args) = @_ ;
    my $sub = 'collectLogs()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my @cmdResults;

    #login as root
    unless ($self->enterRootSessionViaSU()) {
        $logger->error(__PACKAGE__ . " : Could not enter root session");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    #configure PSX
    $self->execCmd("cd /export/home/ssuser/SOFTSWITCH/BIN/");

    unless ( $self->execCmd("./archiveCloudLogs.sh") ) {
        $logger->error(__PACKAGE__ . " : Could not run ./archiveCloudLogs.sh");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    unless (@cmdResults = $self->execCmd("ls -t *.tgz | head -n 1")) {
        $logger->error(__PACKAGE__ . " : Could not get the latest tar file.");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }

    my %scpArgs;
    $scpArgs{-hostip}     = $self->{OBJ_HOST};
    $scpArgs{-hostuser}   = "root";
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD}; 
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."/tmp/$cmdResults[0]";
    $scpArgs{-destinationFilePath} = $args{-path};
 
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
        $self->leaveRootSession();
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }
       
    # Leaving root session
    unless ( $self->leaveRootSession()) {
        $logger->error(__PACKAGE__ . " : Could not leave the root session");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
    return 1;
}
1; # Do not remove
