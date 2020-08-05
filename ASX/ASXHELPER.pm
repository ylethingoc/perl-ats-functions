package SonusQA::ASX::ASXHELPER;

use SonusQA::Utils qw(:errorhandlers :utilities);
use POSIX;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::HARNESS;
#########################################################################################################
=head1 NAME

  SonusQA::ASX - Perl module for ASX interaction

=head1 DESCRIPTION

  This ASXHELPER package contains various subroutines that assists with ASX related interactions.
	Subroutines are defined to provide Value add to the test execution in terms of verification and validation.

	Currently this package includes the following subroutines:

	sub parseLogFiles()
	sub verifyCDR()
	sub checkforCore()
	sub storeLogs()
	sub serverRestart()
	sub serverStop()
	sub serverStart()
	sub clearLogs()
	sub runManage()
	sub editAsxConfigFile()
	sub serverReboot()
	sub kick_off()
	sub wind_Up()   

=head1 AUTHORS

  See Inline documentation for contributors.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Utils 

=head1 METHODS

#########################################################################################################              

=pod

=head2 SonusQA::ASX::ASXHELPER::parseLogFiles

  Parses the Log file for string(s) passed by the tester through "%parseLogData"

=over

=item Arguments

  $copyLocation > Location of Copied Log Files 
  $tcid > Test Case ID
  %parseLogData > Hash data containing file name and string(s) to be Matched for

    if %parseLogData has the first element of the matching array as a Digit ranging [1-99] function is passed to "subroutine parseLogAgainst"
    else continue in this subroutine.

=item Example(s)

  $self->parseLogFiles($copyLocation,$tcid,%$parseData)

=item Returns

  1 on Success 
  0 on Failure

=back

=cut

sub parseLogFiles {
    my ($self,$copyLocation,$tcid,%parseLogData) = @_ ;
    my $sub_name = "parseLogFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->warn(__PACKAGE__ . ".$sub_name:  Parsing Values");

    unless ( defined $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Copy Location is empty or blank.");
    }

    unless ( defined $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Test Case ID is empty or blank.");
    }

    if ( ! keys %parseLogData ) {
        $logger->error(__PACKAGE__ . ".$sub_name: SEARCH PATTERN is EMPTY or UNDEFINED!");
	return 1;
    }

    unless ( $self->{conn}->cmd("mkdir -p $copyLocation") ) {
	$logger->error(__PACKAGE__ . ".$sub_name: COULD NOT CREATE ASX LOG DIRECTORY, PLEASE CHECK THE PERMISSION or CREATE DIRECTORY MANUALLY!");
    }

    system ("mkdir -p Temp");

    my $logName = $_;
    my $newlogName = "$tcid.$logName";
    my $refCount;
    my @refArray;
    my $parseflag = 1;
    my $matches = 0;
    my $result = 1;
    my $matchFail = 0;

    for (keys %parseLogData) 
    {
	$logName = $_;
	$newlogName = "$tcid.$logName";
	my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};

	my %scpArgs;
        $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
        $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{NAME};
        $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD};
	if ( $logName eq 'logFm' ) {
            $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:/trace/FM/$logName";
        } else {
            $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:/trace/$logName";
        }
        $scpArgs{-destinationFilePath} = "Temp/$newlogName";
	&SonusQA::Base::secureCopy(%scpArgs);
	sleep 2;
	    
	    my $file = "Temp/$newlogName";
	    my $parseString;
	    if ( $parseLogData{$_}[0] =~ /^([0-9]{1}|[0-9]{1}[0-9]{1})$/ )
	    {
		$parseString = $parseLogData{$_}[1];
		$refCount = $parseLogData{$_}[0] + 1;
		unless(@refArray = `grep -a -A $refCount "$parseString" $file`) {
		    $logger->debug(__PACKAGE__ . ".$sub_name: REFERANCE LOG FILE OR REFERANCE NOT FOUND");
		    $result = 0;
		    $parseflag = 0;
		}

		if (&parseLogAgainst($logName,\@refArray,\%parseLogData)) {
		    $matches++;
		} else {
		    $logger->debug(__PACKAGE__ . ".$sub_name: PARSE AGAINST REFERANCE LOG FAILED");
		    $result = 0;
		    $parseflag = 0;
		}
	    } else {
		for my $i ( 0 .. $#{$parseLogData{$_}}) {

    		if (open (FH, "$file")) {
        		$logger->info(__PACKAGE__ . ".$sub_name OPENED FILE: $file");
		    } else {
    		    $logger->error(__PACKAGE__ . ".$sub_name Cannot Open File $file: $!");
    		}

    		$parseString = $parseLogData{$_}[$i];
		    foreach my $fh ( <FH> ) {
			if($fh =~ /$parseString/){
			    $matches++;
			}
		    }
		close(FH);

		if ($matches == 0 ) {
			$matchFail = 1;
		}
 
		$logger->debug(__PACKAGE__ . ".$sub_name: Expected -> \"$parseString\" in \"$logName\" Matches -> $matches");

		if ( $matchFail == 0 && $result == 1 ) {
		    $parseflag = 1;
		} else {
		    $parseflag = 0;
		}
    		$matches = 0;
	    }
	}
    }
        
    if( $parseflag == 1 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }  
}

=pod

=head2 SonusQA::ASX::ASXHELPER::parseLogAgainst

  Parses the Log file for string(s) passed by the tester through "%parseLogData" Against the referance Parse String

  Example(s)

   Assume the following is the log output
--------------------------------------------------------
    OTHER LEG RECORD INFO:
        Current Route Index: 0
        Has Leg reached alerting state: false
        Should Leg provide inband ringback: false
        Disconnect Initiator: -1
        Call Route Type: ROUTE_TYPE_LOCAL
        Subscriber Dialed Digits:
        Is Suspended: false
        Is Passive: true
        Is Local Hold: false
        Is Remote Hold: false
--------------------------------------------------------

    In the above log Tester wants to verify for the value "Disconnect Initiator: -1" under the referance section wherein
	log line startes/matches with pattern "OTHER LEG RECORD INFO:" and assume the value lies within the next 10 lines of the
	referance match.

    In such case user shall create his %matchData as
	%parseLogData = ( logCc => [10,"OTHER LEG RECORD INFO:","Disconnect Initiator: -1","Is Passive: true"] );

=over

=item Arguments

  $logName > Log File to be verified 
  $refArray > Referance Array as passed by subroutine "parseLogFiles"
  $parseLogData > Log Data to be parsed against this Array as passed by the subroutine "parseLogFiles"

=item Example(s)

  $self->parseLogAgainst($logName, $refArray, $parseLogData)

  Framework usage of this subroutine is through the subroutine "parseLogFiles" as we shall be validating against the copied local logs.

=item Returns

  1 on Success 
  0 on Failure

=back

=cut

sub parseLogAgainst {
    my $sub_name = "parseLogAgainst";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entering Sub ");
    my ($logName, $refArray, $parseLogData) = @_ ;
    my @refArray = @$refArray;
    my %parseLogData = %$parseLogData;
    my $matchAgainst = 1;

    for my $k ( 2 .. $#{$parseLogData{$logName}}) {
	my $parseString = $parseLogData{$logName}[$k];
	if(grep (/$parseString/,@refArray)) {
	    $logger->debug(__PACKAGE__ . ".$sub_name: SUCCESS: Expected -> \"$parseString\" Referance -> \"$parseLogData{$logName}[1]\" in Log File -> \"$logName\"");
	} else {
	    $logger->debug(__PACKAGE__ . ".$sub_name: FAILED: Expected -> \"$parseString\" Referance -> \"$parseLogData{$logName}[1]\" in Log File -> \"$logName\"");
	    $matchAgainst = 0;
	}
    }
    
    if($matchAgainst) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
} 

=pod

=head2 SonusQA::ASX::ASXHELPER::verifyCDR

  This subroutine shall parse CDR records for strings to match under "/act" directory. 

=over

=item Arguments

  $cdrVirtue = 0;	(Optional, default set to 1)
	> 1 refers to STRICT Validation (validates exact value against the field count).
	> 0 refers to LOOSE Validation (validates only the field name matching for exact case).
  %cdrHash : Hash of a Hash Containing
	> Type of Record to be Parsed, such as START/STOP/ATTEMPT/FEATURE.
	> Strings to be parsed in CDR.

=item Example(s)

  my %cdrHash = ( START => {2 => "nodeNm=GUNA", 5 => "orgCgN=2220001001"} , STOP => {2 => "nodeNm=GUNA", 5 => "orgCgN=2220001001"} , FEATURE => { 88 => "ftrTyp=1"} );

  $self->verifyCDR(%$cdrHash)

=item Returns

  1 on Success
  0 on Failure

=item Modified by

  Ashok Kumarasamy (akumarasamy@sonusnet.com)

=back

=cut

sub verifyCDR
{
    my ($self, $cdrVirtue, %CDRRef) = @_ ;
    my $sub_name = "verifyCDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
   
    my @version;
    my $recordType;
    my $recordList;
    my @content=();
    my @cdrvalues=();
    my @cdrDump=();
    my @cdrContent=();

    my $cdACT ="cd /act";
    my $catACT ="cat A_*.ACT";
    my $catMCID ="cat mcid/U_*.MCID";

	sleep (5);

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless (defined $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory session input is empty or blank.");
	return 0;
    }

    unless ( keys %CDRRef ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: CDR RECORD reference is EMPTY OR UNDEFINED!");
    }

    if ( ! defined $cdrVirtue ) {
        $cdrVirtue = 1;
	$logger->debug(__PACKAGE__ . ".$sub_name: CDR VIRTUE NOT DEFINED SETTING DEFAULT AS STRICT MATCHING" );
    }
    
    if ( $cdrVirtue == 1 ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: CDR STRICT MATCHING" );
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name: CDR LOOSE MATCHING" );
    }

    unless ( $self->{conn}->cmd($cdACT)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cdACT ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @content = $self->{conn}->cmd($catACT )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$catACT ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    #get the version of the device

    my $cmd = "pkginfo -l SONSasx | grep VERSION";
    my $Asx_version = 0;    
    my $shift_index;

    #stores all the 8.0 Feature Codes 
    my @Feature_code = ( "ASX_001", "ASX_008", "ASX_017", "ASX_027", "ASX_035", "ASX_045", "ASX_057", "ASX_063", "ASX_076", "ASX_128", "ASX_139", "ASX_152", "ASX_165", "ASX_175", "ASX_190", "ASX_200", "ASX_214", "ASX_002", "ASX_010", "ASX_018", "ASX_028", "ASX_037", "ASX_047", "ASX_064", "ASX_077", "ASX_129", "ASX_140", "ASX_154", "ASX_166", "ASX_176", "ASX_191", "ASX_201", "ASX_215", "ASX_003", "ASX_011", "ASX_019", "ASX_029", "ASX_038", "ASX_048", "ASX_058", "ASX_065", "ASX_122", "ASX_132", "ASX_141", "ASX_157", "ASX_167", "ASX_183", "ASX_193", "ASX_204", "ASX_218", "ASX_004", "ASX_012", "ASX_020", "ASX_030", "ASX_039", "ASX_049", "ASX_059", "ASX_069", "ASX_123", "ASX_133", "ASX_142", "ASX_158", "ASX_168", "ASX_185", "ASX_194", "ASX_205", "ASX_219", "ASX_005", "ASX_013", "ASX_021", "ASX_031", "ASX_040", "ASX_053", "ASX_070", "ASX_124", "ASX_135", "ASX_143", "ASX_161", "ASX_169", "ASX_186", "ASX_196", "ASX_206", "ASX_220", "ASX_014", "ASX_022", "ASX_032", "ASX_042", "ASX_055", "ASX_060", "ASX_071", "ASX_125", "ASX_136", "ASX_148", "ASX_162", "ASX_170", "ASX_187", "ASX_197", "ASX_207", "ASX_006", "ASX_015", "ASX_023", "ASX_033", "ASX_043", "ASX_061", "ASX_073", "ASX_126", "ASX_137", "ASX_149", "ASX_163", "ASX_171", "ASX_188", "ASX_198", "ASX_209", "ASX_007", "ASX_016", "ASX_025", "ASX_034", "ASX_044", "ASX_056", "ASX_062", "ASX_074", "ASX_127", "ASX_138", "ASX_151", "ASX_164", "ASX_174", "ASX_189", "ASX_199", "ASX_213", "ASX_041" ); 

    my $Feature_code;

    if (defined ($testsuite_name)) {
        $logger->debug(__PACKAGE__ . ".$sub_name: testsuite----> $testsuite_name ");
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name: \$testsuite_name not defined");
    }
    
    #identifying the Feature Code from the Global Variable
    if ($testsuite_name =~ /(ASX_\d*):/i) {
	$Feature_code = $1;
	$logger->debug(__PACKAGE__ . ".$sub_name: Feature code : $Feature_code \n");
    }else{
	$logger->debug(__PACKAGE__ . ".$sub_name: Could not get the Feature Code from the testrun");
    }

    foreach (@Feature_code) {
	if ($Feature_code eq "$_") {
	    $logger->debug(__PACKAGE__ . ".$sub_name: Feature Code exists in the buffer");
	    $shift_index = 1;
	    last;	
	}
    }	

    unless ( @version = $self->{conn}->cmd($cmd) ) {
	$logger->debug(__PACKAGE__ . ".$sub_name: Failed to get the Device Version ");
	$logger->debug(__PACKAGE__ . ".$sub_name: Setting default as 8.0");
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: @version");
        foreach (@version) {
	    if ($_ =~ /V08\.0[3-9]/i) { 
	        $Asx_version = 1;
	    }elsif ($_ =~ /V08\.00/i) { 
	        $Asx_version = 0;
	    }
        }
    }

    my $flagCDR = 1; 
    my ($index,$newIndex);
    for $recordType (keys %CDRRef) {
	
	if ( $recordType eq 'TRACE') {
	    @content = $self->{conn}->cmd($catMCID );
	}
        foreach (@content) {
	    if(m/^$recordType/) {
		push @cdrDump, $_;
	    }
	}
	
	    
	for $index (keys %{$CDRRef{$recordType}}) {

	    if (ref($CDRRef{$recordType}->{$index}) eq "HASH") {
	        $newIndex = $index - 1;
		@cdrContent = $cdrDump[$newIndex];
		@cdrvalues = split("\,", $cdrContent[0]);

		if ($cdrVirtue == 1) {
		    for $recordList (keys %{$CDRRef{$recordType}{$index}}) {
		        my $new_recordList = $recordList - 1;

			if ($Asx_version == 1) {

			    if ($shift_index) {
	
			        if ($recordType eq "STOP") {
                                    if ($new_recordList >= 86 and $new_recordList <= 90) {
					$new_recordList = $new_recordList + 2;
                                    }elsif ($new_recordList >= 91 and $new_recordList <= 100) {
					$new_recordList = $new_recordList + 3;
				    }
				}elsif ($recordType eq "FEATURE") {
		                    if ($new_recordList >= 86 and $new_recordList <= 112) {
					$new_recordList = $new_recordList + 2;
                                    }
				}elsif ($recordType eq "ATTEMPT") {
                                    if ($new_recordList >= 86 and $new_recordList <= 88) {
					$new_recordList = $new_recordList + 2;
                                    }elsif ($new_recordList >= 89 and $new_recordList <= 94) {
					$new_recordList = $new_recordList + 3;
				    }
				}elsif ($recordType eq "INTERMEDIATE") {
                                    if ($new_recordList >= 86 and $new_recordList <= 87) {
					$new_recordList = $new_recordList + 2;
                                    }
				}	
			    }
		    	}  	

			if($cdrvalues[$new_recordList] =~ /\Q$CDRRef{$recordType}{$index}{$recordList}\E/i) {
			    $logger->debug(__PACKAGE__ . ".$sub_name: RECORD MATCHED: Expected: $CDRRef{$recordType}{$index}{$recordList} Actual:$cdrvalues[$new_recordList] in Record Type: $recordType - $index" );
			} else {
			    $logger->debug(__PACKAGE__ . ".$sub_name: RECORD DID NOT MATCH: Expected: $CDRRef{$recordType}{$index}{$recordList} Actual:$cdrvalues[$new_recordList] in Record Type: $recordType - $index" );
			    $flagCDR=0;
			}
		    }
		} else {
		    foreach my $record (keys %{$CDRRef{$recordType}{$index}}) {
		        if (grep (m/\Q$CDRRef{$recordType}{$index}{$record}\E/,@cdrvalues)) {
			    $logger->debug(__PACKAGE__ . ".$sub_name: RECORD FIELD \"$CDRRef{$recordType}{$index}{$record}\" FOUND in \"$recordType - $index\"" );
			} else {
			    $logger->debug(__PACKAGE__ . ".$sub_name: RECORD FIELD \"$CDRRef{$recordType}{$index}{$record}\" NOT FOUND in \"$recordType - $index\"" );
			    $flagCDR=0;
			}
		    }
		}
	    }
	    #Following Condition is needed to support Backward Compatibility	
	    if (ref($CDRRef{$recordType}->{$index}) ne "HASH") {
		$newIndex = 0;
		@cdrContent = $cdrDump[$newIndex];
		@cdrvalues = split("\,", $cdrContent[0]);
	
		if ($cdrVirtue == 1) {

		    for $recordList (keys %{$CDRRef{$recordType}}) {
			my $new_recordList = $recordList - 1;

                        if ($Asx_version == 1) {

                            if ($shift_index) {

                                if ($recordType eq "STOP") {
                                    if ($new_recordList ge 86 and $new_recordList le 90) {
                                        $new_recordList = $new_recordList + 2;
                                    }elsif ($new_recordList ge 91 and $new_recordList le 100) {
                                        $new_recordList = $new_recordList + 3;
                                    }
                                }elsif ($recordType eq "FEATURE") {
                                    if ($new_recordList ge 86 and $new_recordList le 112) {
                                        $new_recordList = $new_recordList + 2;
                                    }
                                }elsif ($recordType eq "ATTEMPT") {
                                    if ($new_recordList ge 86 and $new_recordList le 88) {
                                        $new_recordList = $new_recordList + 2;
                                    }elsif ($new_recordList ge 89 and $new_recordList le 94) {
                                        $new_recordList = $new_recordList + 3;
                                    }
                                }elsif ($recordType eq "INTERMEDIATE") {
                                    if ($new_recordList ge 86 and $new_recordList le 87) {
                                        $new_recordList = $new_recordList + 2;
                                    }
                                }
                            }
                        }
			if($cdrvalues[$new_recordList] =~ /\Q$CDRRef{$recordType}{$recordList}\E/i) {
			    $logger->debug(__PACKAGE__ . ".$sub_name: MATCHED: Expected: $CDRRef{$recordType}{$recordList} Actual:$cdrvalues[$new_recordList] in Record Type: $recordType" );
			} else {
			    $logger->debug(__PACKAGE__ . ".$sub_name: DID NOT MATCH: Expected: $CDRRef{$recordType}{$recordList} Actual:$cdrvalues[$new_recordList] in Record Type: $recordType" );
			    $flagCDR=0;
			}
		    }
		} else {
		    foreach my $record (keys %{$CDRRef{$recordType}}) {
			if (grep (m/\Q$CDRRef{$recordType}{$record}\E/,@cdrvalues)) {
			    $logger->debug(__PACKAGE__ . ".$sub_name: FIELD \"$CDRRef{$recordType}{$record}\" FOUND in \"$recordType\"" );
			} else {
			    $logger->debug(__PACKAGE__ . ".$sub_name: FIELD \"$CDRRef{$recordType}{$record}\" NOT FOUND in \"$recordType\"" );
			    $flagCDR=0;	
			}
		    }
		}
	    }
	}
    @cdrDump=();
    }
    
    if($flagCDR)
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }
    else
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
}

=pod

=head2 SonusQA::ASX::ASXHELPER::checkforCore

  This subroutine shall check for generated core, 
	if "yes" copies to a specified location.
	if "No" just passes the information.

=over 

=item Arguments

  $copyLocation    > Location to copy Core Files 
  $tcid            > Test Case ID

=item Example(s)

	$self->checkforCore($copyLocation,$tcid);

=item Returns

  1, if No Core Generated and if Core Generated and Copied Successfully.
  0, if Failed to check for Core or if failed to copy the core.

=back

=cut

sub checkforCore
{
    my ($self,$copyLocation, $tcid) = @_ ;
    my $sub_name = "checkforCore";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: CORE LOGS STORE PATH: $copyLocation");

    my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    
    my $file_size;
    my @corefile=();
    my @content=();
    my $coreflag = 1;

    my $lsCORE = "ls -lrt core_$hostname*";
    my $cdCORE = "cd /export/home/core/";

	my $datestamp = strftime("%Y%m%d%H%M%S",localtime) ;

    unless (defined $self)
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless (defined $tcid)
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->{conn}->cmd("mkdir -p $copyLocation") ) {
	$logger->error(__PACKAGE__ . ".$sub_name: COULD NOT CREATE ASX LOG DIRECTORY, PLEASE CHECK THE PERMISSION or CREATE DIRECTORY MANUALLY!");
    }

    unless ( $self->{conn}->cmd($cdCORE))
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cdCORE --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @content = $self->{conn}->cmd($lsCORE))
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$lsCORE --\n@{$self->{CMDRESULTS}}.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach(@content)
    {
        $file_size = (split /\s+/,$_)[4];
#       $logger->debug(__PACKAGE__ . ".$sub_name: file Size: $file_size");
	last;
    }

    if($file_size == 0)
    {
        $logger->info(__PACKAGE__ . ".$sub_name: No new core generated");
	$coreflag = 1;
	return 1;
    }
    else
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: NEW CORE FOUND");
		$coreflag = 1;
		sleep(80);

	    if (&checkServerStatus) {
    	    $logger->debug(__PACKAGE__ . ".$sub_name  ASX STARTED SUCCESSFULLY");
	    } else {
    	    $logger->error(__PACKAGE__ . ".$sub_name: ASX NOT STARTED");
    	}
    }

    foreach (@content)
    {
	my $corefile = $_;
	$corefile = (split /\s+/,$_)[8];
	my $newcorefile = "$datestamp.$tcid.$corefile";
        my $cpCORE = "cp $corefile $copyLocation/$newcorefile";
    	unless ( @content = $self->{conn}->cmd($cpCORE))
	{
	    $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cpCORE .");
	    $coreflag = 0;
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
    	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    	}
        $logger->debug(__PACKAGE__ . ".$sub_name: Copied Core $corefile => $newcorefile");
    }

    if($coreflag == 1 )
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    }
    else
    {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } 
}

=pod

=head2 SonusQA::ASX::ASXHELPER::storeLogs

  This subroutine shall Copy the Log files to a specified Location

=over

=item Arguments

  $copyLocation    > Location to copy Log Files 
  $tcid            > Test Case ID

=item Example(s)

  self->storeLogs($copyLocation,$tcid);

=item Returns

  1 on Success
  0 on Failure 

=back

=cut

sub storeLogs
{
    my ($self,$copyLocation,$tcid,@files) = @_ ;
    my $sub_name = "storeLogs";
    my $fileName;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: ASX LOGS STORE PATH: $copyLocation");

	my $datestamp = strftime("%Y%m%d%H%M%S",localtime) ;

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Directory Name empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->{conn}->cmd("mkdir -p $copyLocation") ) {
	$logger->error(__PACKAGE__ . ".$sub_name: COULD NOT CREATE ASX LOG DIRECTORY, PLEASE CHECK THE PERMISSION or CREATE DIRECTORY MANUALLY!");
    }

    unless ( $self->{conn}->cmd("cd /trace")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could Not change Directory.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }

# Following condition is to take care of backward Compatibility...!
    if ( scalar @files gt 0 ) {

	    if ( $self->{conn}->cmd("cp /act/A* $copyLocation/$datestamp.$tcid.A.ACT")) {
    	    $logger->info(__PACKAGE__ . ".$sub_name: Copied ACT => $datestamp.$tcid.A.ACT");
	    } else {
    	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy ACT Files");
    	}

	foreach my $fileName ( @files ) {
	    if ( $self->{conn}->cmd("cp $fileName $copyLocation/$datestamp.$tcid.$fileName")) {
		$logger->info(__PACKAGE__ . ".$sub_name: Copied $fileName => $datestamp.$tcid.$fileName");
	    } else {
		$logger->error(__PACKAGE__ . ".$sub_name: Could Not copy $fileName");
	    }
	}
    } else {
    
	if ( $self->{conn}->cmd("cp logCc $copyLocation/$datestamp.$tcid.logCc")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logCc => $datestamp.$tcid.logCc");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logCc");
	}
    
	if ( $self->{conn}->cmd("cp logDa $copyLocation/$datestamp.$tcid.logDa")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logDa => $datestamp.$tcid.logDa");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logDa");
	}
	
	if ( $self->{conn}->cmd("cp logSipDa $copyLocation/$datestamp.$tcid.logSipDa")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logSipDa => $datestamp.$tcid.logSipDa");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logSipDa");
	}
    
	if ( $self->{conn}->cmd("cp logH248Da $copyLocation/$datestamp.$tcid.logH248Da")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logH248Da => $datestamp.$tcid.logH248Da");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logH248Da");
	}
    
	if ( $self->{conn}->cmd("cp logMrm $copyLocation/$datestamp.$tcid.logMrm")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logMrm => $datestamp.$tcid.logMrm");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logMrm");
	}
    
	if ( $self->{conn}->cmd("cp logSip $copyLocation/$datestamp.$tcid.logSip")) {
	    $logger->info(__PACKAGE__ . ".$sub_name: Copied logSip => $datestamp.$tcid.logSip");
	} else {
	    $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy logSip");
	}

    if ( $self->{conn}->cmd("cp /act/A* $copyLocation/$datestamp.$tcid.A.ACT")) {
        $logger->info(__PACKAGE__ . ".$sub_name: Copied ACT => $datestamp.$tcid.A.ACT");
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: Could Not copy ACT Files");
    }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=pod

=head2 SonusQA::ASX::ASXHELPER::serverRestart()

  This function restarts the ASX.
  The function assumes that the current user is asxuser.
  The command issued is "stopasx all;startasx all"

=over

=item Arguement

  None

=item Example(s)

  $asx_obj ->serverRestart();

=item Returns

  Nothing

=back

=cut 

sub serverRestart {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".serverRestart");
    my $sub_name = "serverRestart";
    $logger->debug(__PACKAGE__ . ".$sub_name Entered --> $sub_name "); 

    $self->{conn}->cmd("cd /sons/asx/bin");

    $logger->debug(__PACKAGE__ . ".$sub_name  ISSUING ASX RESTART COMMAND");
    
    unless ($self->{conn}->print("stopasx all;startasx all")) {
        $logger->error(__PACKAGE__ . ".$sub_name: FAILED TO ISSUE RESTART COMMAND");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }

    $self->{conn}->cmd("y");
    $logger->debug(__PACKAGE__ . ".$sub_name  ASX STOPPED");
    sleep(80);

    my $res = &checkServerStatus;

	if ($res == 1) {
    	$logger->debug(__PACKAGE__ . ".$sub_name  ASX RESTARTED SUCCESSFULLY");
		return 1;
	} else {
    	$logger->debug(__PACKAGE__ . ".$sub_name  ASX RESTART FAILED");
		return 0;
	}  
}

=pod 

=head2 SonusQA::ASX::ASXHELPER::serverStop()

  This function stops the ASX.
  The function assumes that the current user is asxuser.
  The command issued is "stopasx all".

=over

=item Arguement

  None

=item Example(s)

  $asx_obj ->serverStop();

=item Returns

  Nothing

=back

=cut

sub serverStop {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".serverStop");
    my $sub_name = "serverStop";
    $logger->debug(__PACKAGE__ . ".$sub_name Entered --> $sub_name "); 
    $logger->debug(__PACKAGE__ . ".$sub_name ISSUING ASX SERVER STOP COMMAND");
	my @stopLog;
	
	$self->{conn}->cmd("cd /sons/asx/bin");

    unless (@stopLog = $self->{conn}->print("stopasx all")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to STOP ASX .");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }

    if(grep(/already/,@stopLog)) {
        $logger->debug(__PACKAGE__ . ".$sub_name ASX SERVER IS DOWN ALREADY");
        return 0;
    } else {
    	$self->{conn}->cmd("y");
    	sleep(20);

    my $res = &checkServerStatus;
    
    if ($res == 0 ) {
    	    $logger->error(__PACKAGE__ . ".$sub_name: ASX STOPPED");
			return 1;
    	} else {
        	$logger->debug(__PACKAGE__ . ".$sub_name  ASX NOT STOPPED");
			return 0;
	    }
    }

}

=pod

=head2 SonusQA::ASX::ASXHELPER::serverStart()

  This function starts the ASX.
  The function assumes that the current user is asxuser.
  The command issued is "startasx all".

=over

=item Arguement

  None

=item Example(s)

  $asx_obj ->serverStart();

=item Returns

  Nothing

=back

=cut

sub serverStart {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".serverStart");
    my $sub_name = "serverStart";
    $logger->debug(__PACKAGE__ . ".$sub_name Entered --> $sub_name "); 
    $logger->debug(__PACKAGE__ . ".$sub_name ISSUING ASX SERVER START COMMAND");
  
    $self->{conn}->cmd("cd /sons/asx/bin");

    unless ($self->{conn}->print("startasx all")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to START ASX .");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }
    
    sleep(60);
    
    my $res = &checkServerStatus;
    
    if ($res == 1) {
    	$logger->debug(__PACKAGE__ . ".$sub_name  ASX STARTED SUCCESSFULLY");
		return 1;
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: ASX NOT STARTED");
		return 0;
    }
}

=pod

=head2 SonusQA::ASX::ASXHELPER::clearLogs()

  This function clears the logs in trace directory as well as in act directory.
  The fuction assumes that the current user is asxuser.

=over

=item Arguments

  None

=item Example(s)

  $asx_obj ->clearLogs();

=item Returns

  Nothing

=back

=cut

sub clearLogs
{
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".clearLogs");
	my $prom = '/.*[\$%#\}\|\>\]].*$/';
    my $sub_name = "clearLogs";
	my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Entered Sub");

    $self->{conn}->print("cd /trace");
    $self->{conn}->waitfor(-match => $prom,
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
	    or &error(__PACKAGE__ . ".clearLogs Unable to enter Trace Directory");
    $logger->debug(__PACKAGE__ . ".$sub_name ENTERED TRACE DIRECTORY");
    
    $self->{conn}->cmd("> logCc");
    $self->{conn}->cmd("> logSip");
    $self->{conn}->cmd("> logSipMw");
    $self->{conn}->cmd("> logH248Da");
    $self->{conn}->cmd("> logDa");
    $self->{conn}->cmd("> logCAMain");
    $self->{conn}->cmd("> logPm");
    $self->{conn}->cmd("> logCam");
    $self->{conn}->cmd("> logQos");
    $self->{conn}->cmd("> logCalea");
    $self->{conn}->cmd("> logVmrm");
    $self->{conn}->cmd("> logMrm");
    $self->{conn}->cmd("> logAgent");
    $self->{conn}->cmd("> logSipDa");
    $self->{conn}->cmd("> logRm");
    $self->{conn}->cmd("> logAppDa");
    $self->{conn}->cmd("> logCli");
    $self->{conn}->cmd("> logDs");
    $self->{conn}->cmd("> logFe");
    $self->{conn}->cmd("> logFmMain");
    $self->{conn}->cmd("> logH248Stack.log");
    $self->{conn}->cmd("> logIke");
    $self->{conn}->cmd("> logJdmkAgent");
    $self->{conn}->cmd("> logSec");
    $self->{conn}->cmd("> logSipSg");
    $self->{conn}->cmd("> FM/logFm");
    
    $logger->debug(__PACKAGE__ . ".$sub_name TRACE LOGS CLEARED");
    $self->{conn}->print("cd /act");
    $self->{conn}->waitfor(-match => $prom,
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
	    or &error(__PACKAGE__ . ".clearLogs Unable to enter ACT Directory");
    $logger->debug(__PACKAGE__ . ".$sub_name ENTERED ACT DIRECTORY");

    $self->{conn}->cmd("> A_*.ACT");
    $self->{conn}->cmd("> mcid/A_*.MCID");

# Below section is to verify that no unwanted file to get created with above names if "Active" records were not found.

	my @listACT = $self->{conn}->cmd('ls A_\*.ACT');
    @listACT = $self->{conn}->cmd('ls mcid/A_\*.MCID');

	foreach (@listACT) {
		if ($_ =~ /A_\*/) {
	    	$self->{conn}->cmd('rm -rf A_\*.ACT');
	    	$self->{conn}->cmd('rm -rf mcid/A_\*.MCID');
		}
	}

	sleep(4);

# Killing CamMain process shall generate the "Active" Record if not available.

    $self->{conn}->cmd("pkill -9 CamMain");
    $logger->debug(__PACKAGE__ . ".$sub_name ACT FILES AND MCID FILES CLEARED");

    $self->{conn}->cmd("cd /export/home/core");
    $logger->debug(__PACKAGE__ . ".$sub_name ENTERED CORE DIRECTORY");
    $self->{conn}->print("rm -rf core_$hostname*");
	sleep(4);
    $self->{conn}->waitfor(-match => $prom,
                         -errmode => "return",
                         -timeout => $self->{DEFAULTTIMEOUT})
	    or &error(__PACKAGE__ . ".$sub_name Unable to Clear Core Files");
    $logger->debug(__PACKAGE__ . ".$sub_name  CORE FILES CLEARED");
	
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub [1]");
    return 1;
}

=pod 

=head2 SonusQA::ASX::ASXHELPER::runManage()

  This function is used to run internal manage commands generally used for simulating error scenarios.

=over

=item Argument

  $cmd = manage -P CAM -C CamLogger.rsn.set.4294967292

=item Example(s)

  $asx_obj-> runManage("manage -P CAM -C CamLogger.rsn.set.4294967292");

=item Returns

  Nothing

=back

=cut

sub runManage {
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runManage");
  $logger->debug(__PACKAGE__ . ".RunManage Executing Command $cmd");
  #$self->{conn}->cmd("bash");
  #$self->{conn}->cmd("");
  $self->{conn}->cmd($cmd);
  $logger->debug(__PACKAGE__ . ".RunManage() Executed Manage Command Successfully");
}

=pod

=head2 SonusQA::ASX::ASXHELPER::editAsxConfigFile()

  This function provides a way to configure the AsxConfig.xml file. The function serverRestart() has to be called after this function in order for the changes to take effect.

=over

=item Arguement

  $Find = AccountFileSizeLimit value="1048576"
  $Replace = AccountFileSizeLimit value="2048"

=item Example(s)

  $self->editAsxConfigFile('AccountFileSizeLimit value="1048576"','AccountFileSizeLimit value="2048"');

  This command will replace the AccountFileSizeLimit value from 1048576 to 2048.

=item Returns

  1 - File modifies successfully
  0 - Error while modifying

=back

=cut

sub editAsxConfigFile {
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".editAsxConfigFile");
    my ($self,%editEntries)=@_;
    my $sub_name = "editAsxConfigFile";
	
    $logger->debug(__PACKAGE__ . ".$sub_name Entered --> $sub_name "); 

    for (keys %editEntries) {
 	my $cmd = "perl -pi -e 's/$_/$editEntries{$_}/g' /sons/asx/AsxConfig.xml";
	$self->{conn}->cmd($cmd);  
	$logger->debug(__PACKAGE__ . ".$sub_name : Modified $_ with $editEntries{$_} ");
    }	
	$logger->debug(__PACKAGE__ . ".$sub_name : Issuing Server Restart for Changes to take effect ");

	my $res = &serverRestart;

	if($res == 1) {
	    $logger->debug(__PACKAGE__ . ".$sub_name ASX CONFIG FILE MODIFIED SUCCESSFULLY");
	    return 1;
	} else {
	    $logger->debug(__PACKAGE__ . ".$sub_name ERROR WHILE MODIFYING ASX CONFIG FILE");
	    return 0;
	}
}

=pod

=head2 SonusQA::ASX::ASXHELPER::serverReboot()

  This function is used to force reboot the ASX system.Sufficient timer of 3 min is included for the box to come up.

=over

=item Argument

  None

=item Example(s)

  $asx_obj ->serverReboot();

=item Returns

  Nothing

=back

=cut

##############
#
#  This function is under reconstruction
#
##############


sub serverReboot {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".serverReboot");
    my $sub_name = "serverReboot";

    $self->{conn}->cmd("exit");
    $logger->debug(__PACKAGE__ . ".$sub_name Entered --root-- User");
    $logger->debug(__PACKAGE__ . ".$sub_name Rebooting ASX ");
    $self->{conn}->cmd("reboot");
    $logger->debug(__PACKAGE__ . ".$sub_name Executed Reboot Command Successfully");
    $self->{conn}->close; 
    $logger->debug(__PACKAGE__ . ".$sub_name closing connection ");

    sleep(180);  
}

=pod

=head2 SonusQA::ASX::ASXHELPER::execCLI()

  Executes the CLI command as per the scalar passed and Validates the elements of the array among the CLI output

=over

=item Argument

  %args = (
  $args{command} => "CLI TO BE EXECUTED",
  $args{match} => ["match1","match2","match3"],
  $args{output} => 1
  );

  $args{command} - Command to be Executed.
  $args{match} - Array of matches to be Looked for.
  $args{output} - 1 (Show output) or 0 (Don't Show output - Default). 

=item Example(s)

  $asx_obj ->execCLI(%args);
    After execution of CLI command it is recommended to invoke exitCLI to exit from the CLI prompt.

=item Returns

  1 - Match found
  0 - Match not found

=back

=cut

sub execCLI {
	my ( $self, %args ) = @_;
	my ( @match, $cliCmd, $showOutput, @cliResults, $flagCLI );
    my $sub_name = "execCLI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    $logger->debug(__PACKAGE__ . ".$sub_name ENTER CLI MODE" );
	my $prompt_string	= "/$hostname\> \$/";
    my $prevPrompt = $self->{conn}->prompt($prompt_string);
    if ($self->{conn}->print("cli")) {
      $logger->debug(__PACKAGE__ . ".$sub_name ENTERED CLI MODE: Previous Prompt is $prevPrompt");
	} else {
        $logger->warn(__PACKAGE__ . ".$sub_name FAILED TO ENTER CLI MODE");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	  return 0;
	}
	$self->{conn}->waitfor($prompt_string);

    $logger->debug(__PACKAGE__ . ".$sub_name PROMPT: " . $self->{conn}->prompt . "\n");

	if ( defined $args{match} ) {
        @match = @{$args{match}};
    }

	if ( defined $args{command} ) {
        $cliCmd = $args{command};
    }

	if ( defined $args{output} ) {
        $showOutput = $args{output};
    } else {
		$showOutput = 0;
	}

    $logger->debug(__PACKAGE__ . ".$sub_name EXECUTING COMMAND: $cliCmd ");

	@cliResults = $self->{conn}->cmd(String => $cliCmd, Timeout => 30, Errmode => "return");
    $flagCLI = 1;

	if ($showOutput) {
		print "###################CLI COMMAND OUTPUT####################\n";
		foreach (@cliResults) {
			print ("$_");
		}
		print "#########################################################\n";
	}

    foreach my $m (@match) {
		if(grep(m/$m/,@cliResults)) {
	    	$logger->debug(__PACKAGE__ . ".$sub_name Match Found: $m");
		} else {
		    $logger->debug(__PACKAGE__ . ".$sub_name Match NOT Found: $m");
	    	$flagCLI = 0;
		}
    }
    
    if($flagCLI) {
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }
}

=pod

=head2 SonunsQA::ASX::ASXHELPER::exitCLI

  Exits CLI mode

=over

=item Argument

  None

=item Example(s)

  $self->exitCLI;	

=item Returns

  Nothing

=back

=cut

sub exitCLI {
    my ($self)=@_;
    my $sub_name = "exitCLI";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	my $setPrompt = "/AUTOMATION\>/";

    $logger->debug(__PACKAGE__ . ".$sub_name EXIT CLI MODE");
	$self->{conn}->prompt($setPrompt);
	$self->{conn}->print("exit");
	$self->{conn}->buffer_empty;
	my @pscli = $self->{conn}->cmd("ps -ef | grep cli");

	if (scalar @pscli gt 0 ) {
		$self->{conn}->print("pkill -9 cli");
      	$logger->debug(__PACKAGE__ . ".$sub_name KILL CLI PROCESS");
		$self->{conn}->waitfor(Match => $setPrompt,Timeout => 10);
	}
}


=pod

=head2 SonunsQA::ASX::ASXHELPER::checkServerStatus

  This checks the server status by looking if all the processes are up.

=over

=item Argument

  None

=item Returns

  1 on Success
  0 on Failure

=item Example(s)

  $self->checkServerStatus;

=back

=cut

sub checkServerStatus {
    my ($self)=@_;
    my $sub_name = "checkServerStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    my $intCmd = '/sbin/ifconfig -a';    
    my @intLst = $self->{conn}->cmd($intCmd);
    my $status = 0;

    foreach my $inf ( @intLst ) {
	if(grep(/bge0:1/,$inf)) {
	    $logger->debug(__PACKAGE__ . ".$sub_name BGE0:1 INTERFACE OBSERVED TO BE UP");
	    $status = 1;
	} elsif (grep(/e1000g0:1/,$inf)) {
	    $logger->debug(__PACKAGE__ . ".$sub_name e1000g0:1 INTERFACE OBSERVED TO BE UP");
	    $status = 1;
	} elsif (grep(/ce0:1/,$inf)) {
	    $logger->debug(__PACKAGE__ . ".$sub_name ce0:1 INTERFACE OBSERVED TO BE UP");
	    $status = 1;	    
	} elsif(grep(/bge0:2/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name BGE0:2 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        } elsif (grep(/e1000g0:2/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name e1000g0:2 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        } elsif (grep(/ce0:2/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name ce0:2 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        } elsif (grep(/eth0\s/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name eth0 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        } elsif (grep(/eth0:1\s/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name eth0:1 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        } elsif (grep(/eth1\s/,$inf)) {
            $logger->debug(__PACKAGE__ . ".$sub_name eth1 INTERFACE OBSERVED TO BE UP");
            $status = 1;
        }
    }

    if ($status == 1) {
	$logger->debug(__PACKAGE__ . ".$sub_name ***** ASX SERVER IS UP *****");
	return 1;
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name ***** NOT ALL ASX SERVER PROCESS ARE UP *****");
	return 0;
    }
    
}


=pod

=head2 SonunsQA::ASX::ASXHELPER::getServerTime

  This subroutine shall return the Current Server time with the specified format.

=over

=item Formats supported

  EPOC - UNIX EPOC time format - Time in Secs since 1970
  HHMM - Hour and Minutes
  YYMMDD - Year Month and Date

=item Returns

  the time in Requested format

=item Example(s)

  $self->getServerTime("HHMM")
  $self->getServerTime("EPOC")

=back

=cut

sub getServerTime {
    my ($self,$format)=@_;
    my $sub_name = "getServerTime";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
    my $currentTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
	
	if ( $format eq "HHMM" ) {
    	my $HHMM = sprintf "%02d%02d", $hour,$min;
	    return $HHMM;
	} elsif ( $format eq "EPOC" ) {
		my $EPOC = time();
		return $EPOC;
	} elsif ( $format eq "YYMMDD" ) {
    	my $YYMMDD = sprintf "%4d%02d%02d", $year+1900,$mon+1,$mday;
	    return $YYMMDD;
	}
}

=pod

=head2 SonunsQA::ASX::ASXHELPER::getTimestamp

  This Subroutine gets you the Timestamp of the corresponding log message refered by the input file.
  This applies to any ASX Log file under /trace directory.
  This subroutine is used by compareCDR function to compare the timestamp returned with the CDR values.

=over

=item Argument

  ind => Index of Occurance of the Log Match.
  match => Complete string (Possibly any Debug message) passed as referance to fetch the timestamp.
  logName => Log File Name refering to the match Value.

=item Returns

  the Timestamp in MM/DD/YYYY HH:MM:SS.mSec format.

=item Example(s)

  $asxObj->getTimestamp( -ind => '1', -match => 'User: ept596@10.34.9.104 detected an offHook at', -logName => "logDa");

=back

=cut

sub getTimestamp {

    my ( $self, %args ) = @_;
    my $sub_name = "getTimestamp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($logName, $newlogName, $file, $ind, $timestamp, @matches, $match );

	my $datestamp = strftime("%Y%m%d%H%M%S",localtime) ;

    if ( ! defined $args{-ind} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: LOG INDEX NOT DEFINED!");
	return 0;
    } else {
	$ind = $args{-ind}-1;
    }

    if ( ! defined $args{-match} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: LOG MATCH REFERANCE NOT DEFINED!");
	return 0;
    }

    if ( ! defined $args{-logName} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: LOG FILE NAME NOT DEFINED!");
	return 0;
    } else {
	$logName = $args{-logName};
	$newlogName = $datestamp.$args{-logName};
	$file = "Temp/$newlogName";
    }

    `mkdir -p Temp`;

    my $hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
    my %scpArgs;
    $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
    $scpArgs{-hostuser} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{NAME};
    $scpArgs{-hostpasswd} = $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD};
    if ( $logName eq 'logFm' ) {
       $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:/trace/FM/$logName";
    } else {
       $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:/trace/$logName";
    }
    $scpArgs{-destinationFilePath} = "Temp/$newlogName";
    &SonusQA::Base::secureCopy(%scpArgs);
    sleep(2);

    if (open (FH, "$file")) {
    	$logger->info(__PACKAGE__ . ".$sub_name OPENED FILE: $file");
	} else {
		$logger->error(__PACKAGE__ . ".$sub_name Cannot Open File $file: $!");
	}

     foreach my $fh ( <FH> ) {
            if($fh =~ /$args{-match}/) {
                $fh =~ /:(\d\d\d\d)\/(\d\d)\/(\d\d)\s+(\d\d):(\d\d):(\d\d).(\d\d\d)\w/;
#                $timestamp = "$2/$3/$1 $4:$5:$6.$7";
# Modified to ignore the Milliseconds value, based on the Request raised by SVT. CQ SONUS00113262
                $timestamp = "$2/$3/$1 $4:$5:$6";
                push @matches, $timestamp;
                $match++;
            }
    }
     
    if ($#matches < 0) {
	$logger->error(__PACKAGE__ . ".$sub_name LOG FILE NOT FOUND or MATCH COULD NOT BE OBSERVED!");
    }
        close(FH);
	
    `rm -rf Temp`;
    return $matches[$ind];
}

=pod

=head2 SonunsQA::ASX::ASXHELPER::compareCDR

  This subroutine is explicitely defined to check the CDR values against timestamp fetched from getTimestamp function.
  This can be enhanced based on future requirements of comparing CDR's against various other values.

=over

=item Argument

  ind => Index of Occurance of the Log Match.
  match => Complete string (Possibly any Debug message) passed as referance to fetch the timestamp.
  logName => Log File Name refering to the match Value.	

  Above arguments are necessary while comparing CDR's against Timestamps from the Log Files.

  -cdrInd => Defines the CDR Index.
  -cdrType => Defines the CDR Record Type.
  -cdrField => Defines the CDR Field whose value to be compared.

=item Returns 

  1 for Success
  0 for Failure.

=item Example(s)

  $asxObj->compareCDR( -ind => '1', -match => 'User: ept596@10.34.9.104 detected an offHook at', -logName => "logDa" ,-cdrRef => { -ind => '1', -type => 'START', -field => 'orgOffTP' } );

=back

=cut

sub compareCDR {
    
    my ( $self, %args ) = @_;
    my $sub_name = "compareCDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($cdrInd, $cdrType, $cdrField, $cdACT, $catACT, $cdrMatch, @content, @cdrValues, $fieldValue, @unique, $field, $refValue );
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ( defined $args{-cdrRef} ) {
        $cdrInd = $args{-cdrRef}{-ind}-1;
        $cdrType = $args{-cdrRef}{-type};
        $cdrField = $args{-cdrRef}{-field};
    } else {
	$logger->error(__PACKAGE__ . ".$sub_name: CDR REFERANCES NOT DEFINED!");
	return 0;
    }

    $cdACT ="cd /act";
    $catACT ="cat A_*.ACT";

    unless ( $self->{conn}->cmd($cdACT)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cdACT ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @content = $self->{conn}->cmd($catACT )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$catACT ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    foreach (@content) {
	if ( m/^$cdrType/) {
	    push @unique, $_;
	}
    }

    if ($#unique < 0) {
	$logger->error(__PACKAGE__ . ".$sub_name: CDR RECORD NOT FOUND or CDR MATCH COULD NOT BE OBSERVED!");
	return 0;
    } else {
	$logger->debug(__PACKAGE__ . ".$sub_name: CDR RECORD FOUND");
    }

    @cdrValues = split(/\,/,$unique[$cdrInd]);

    $logger->debug(__PACKAGE__ . ".$sub_name: MATCHING AGAINST CDR REFERANCES
    ========================================
	CDR INDEX => $args{-cdrRef}{-ind}\t
	CDR TYPE => $args{-cdrRef}{-type}\t
	CDR FIELD => $args{-cdrRef}{-field}\t
    ========================================");

    foreach (@cdrValues) {
	if ( /$cdrField/) {
	    ($field,$cdrMatch) = split (/=/,$_);
	    $logger->debug(__PACKAGE__ . ".$sub_name: CDR FIELD \"$field\" OBSERVED VALUE AS \"$cdrMatch\"");
    	}
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: GETTING THE TIMESTAMP FROM THE LOG REFERANCES AS
    ================================================================
	LOG FILE => $args{-logName}
	LOG MATCH => \"$args{-match}\"
	LOG MATCH INDEX => $args{-ind}
    ================================================================");
    unless ($refValue = $self->getTimestamp( -ind => $args{-ind}, -logName => $args{-logName}, -match => $args{-match} )) {
	$logger->error(__PACKAGE__ . ".$sub_name: COULD NOT GET TIMESTAMP FROM THE LOG");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

#    if ($refValue eq $cdrMatch) {
# Modified to ignore the Milliseconds value, based on the Request raised by SVT. CQ SONUS00113262
    if ($cdrMatch =~ /$refValue/ ) {
		$logger->info(__PACKAGE__ . ".$sub_name: CDR RECORD MATCHED WITH THE REFERANCE");
		$logger->debug(__PACKAGE__ . ".$sub_name: EXPECTED => $cdrMatch , OBSERVED => $refValue ; IGNORING MilliSeconds Value!!!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1;
    } else {
		$logger->error(__PACKAGE__ . ".$sub_name: CDR DID NOT MATCH: EXPECTED => $cdrMatch , OBSERVED => $refValue");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
}


=pod

=head2 SonunsQA::ASX::ASXHELPER::kick_off

  This Subroutine is derived to combine several subroutines that might be commonly invoked before executing the test tool command.
  Currently kick_off invokes clearLogs() function, enhancements may include other additions to this subroutine.

=over

=item Argument

  None

=item Returns

  1 on Success
  0 on Failure

=item Example(s)

  $self->kick_Off;

=back

=cut

sub kick_Off {
    my ($self) = @_ ;
    my $sub_name = "kick_Off";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $self->clearLogs() ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  Could not Kick-Off successfully!");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
}

=pod

=head2 SonunsQA::ASX::ASXHELPER::wind_up

  This Subroutine is derived to combine several subroutines that might be commonly invoked after executing the test tool command.
  Currently wind_up invokes the following subroutines:
	checkforCore(), storeLogs(), verifyCDR(), parseLogFiles() 	

=over

=item Argument

  $copyLocation	>	Location to Save Log files
  $tcid			>	Test Case ID
  $parseData		>	Hash Referance to Data To be Parsed, Data contains filename and array of string(s) to be matched
  $actRecordType	>	Scalar value refering to the CDR record Type such as START/STOP/ATTEMPT/FEATURE
  $cdrHash		> 	Hash Referance to Data to be Parsed under ACT record, Data contains index of the element and corresponding value. 

    Example: my %parseData = ( logCc => ["ccAuditDisoveredOneLeg: false","isCallingNumberSourceSupportEnabled: false","Nature Of Number: UNIQUE_SUBSCRIBER_NUMBER"] ,
                                   logSipDa => ["Called Party Grade: PSTN_NUMBER","isPresentationNumberEnabled: false"] );

      Where "logCc" defines the file name to be parsed for '["ccAuditDisoveredOneLeg: false","isCallingNumberSourceSupportEnabled: false","Nature Of Number: UNIQUE_SUBSCRIBER_NUMBER"]' and
            "logSipDa" to be parsed for ["Called Party Grade: PSTN_NUMBER","isPresentationNumberEnabled: false"]


    Example: my %recordHash = ( 2 => "nodeNm=GUNA", 5 => "orgCgN=2220001001" );
      where '2 => "nodeNm=GUNA"' defines 2nd parameter or the record must be "nodeNm=GUNA"

    Example: my $actRecordType = "START";

=item Returns

  1 - Successful
  0 - Failure

=item Example(s)

  $objAsx->wind_Up( "$TESTSUITE->{ASXLOGPATH}",$test_id,\%matchData,$recordType,\%recordHash )	

=back

=cut

sub wind_Up {
    my ( $self,$copyLocation,$tcid,$parseData,$cdrHash,$cdrVirtue,$filesToCopy ) = @_ ;
    my $sub_name = "wind_Up";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    ######## Check for Defined Mandatory Parameters ########

    unless ( defined $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( defined $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input \"Copy Location\" is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $self->{conn}->cmd("mkdir -p $copyLocation") ) {
	$logger->error(__PACKAGE__ . ".$sub_name: COULD NOT CREATE ASX LOG DIRECTORY, PLEASE CHECK THE PERMISSION or CREATE DIRECTORY MANUALLY!");
    }

    unless ( defined $tcid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input \"Test Case ID\" is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    ######## check for core ########
	my $flagCORE = 0;
	my $flagCDR = 0;
	my $flagParse = 0;

    if ($self->checkforCore($copyLocation,$tcid)) {
        $logger->info(__PACKAGE__ . " $sub_name:   CHECK FOR CORE COMPLETED.");
	$flagCORE = 1;
    } else {
        $logger->error(__PACKAGE__ . " $sub_name:   CHECK FOR CORE FAILED.");
	$flagCORE = 0;
    }

    ######## Store Logs ########

    unless ($self->storeLogs($copyLocation,$tcid,@$filesToCopy) ) {
       	$logger->infp(__PACKAGE__ . " $sub_name:   Store log files COMPLETED.");
    }

    ######## Verify CDR Logs ########

    if ($self->verifyCDR($cdrVirtue, %$cdrHash )) {
        $logger->debug(__PACKAGE__ . " $sub_name:   Verify CDR COMPLETED.");
	$flagCDR = 1;
    } else {
        $logger->debug(__PACKAGE__ . " $sub_name:   Verify CDR FAILED.");
	$flagCDR = 0;
    }

    ######## parse log ########
    if ($self->parseLogFiles($copyLocation,$tcid,%$parseData) ) {
   	$logger->debug(__PACKAGE__ . " $sub_name:   Parse Data COMPLETED");
	$flagParse = 1;
    } else {
   	$logger->debug(__PACKAGE__ . " $sub_name:   Parse Data FAILED");
	$flagParse = 0;
    }

    system ("rm -r Temp");
    if ( $flagCORE == 1 && $flagCDR == 1 && $flagParse == 1 ) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }

}

1;
