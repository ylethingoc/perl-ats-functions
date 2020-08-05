#!/ats/bin/perl
use Net::Telnet;
use Net::FTP;
use ATS;
use SonusQA::ATSHELPER;
use SonusQA::Utils qw (:all);
use Log::Log4perl qw(get_logger :levels);
my $logger = Log::Log4perl->get_logger(__PACKAGE__);


#The variable $tms_alias will have to edited to choose the right configuration element from the TMS for the ATS execution
$tms_alias = "SGX4KManager";

# Result Logging
#Set ATS_LOG_RESULT = 1 for Logging the Test Results into TMS
#setting it to 0 will not populate the result into TMS

$ENV{ "ATS_LOG_RESULT" } = 1;               # TMS flag

# TMS attribute values
#All the INPUT values required for the execution of the SIlktest from the ATS will be stored below this paragraph .......

  my $domain = "SONUSNETWORKS";
  my $silk_obj = resolveAlias(-tms_alias => $tms_alias);
  my $hostip = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};
  my $hostuser = $silk_obj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID};
  my $script_name = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH};
  $hostuser = "$domain\\$hostuser";
  my $hostpwd = $silk_obj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD};
  my $release = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{RELEASE};
  my $build = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{BUILD};
  my $ats_result_loc = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{ATS_LOCATION};
  my $time_required_execute = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{COMPLETION_TIME};
  my $silktest_loc = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{SILKTEST_LOCATION};
  my $execution_script = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{EXECUTION_SCRIPT};
  my $file = $silk_obj->{TMS_ALIAS_DATA}->{NODE}->{1}->{RESULT_FILE};


#  $logger->info(__PACKAGE__ . "$sub = The Login Credentials Obtained from the TMS is as below \n Host IP => $hostip \n Host UserName => $hostuser \n Host Password => $hostpwd \n Execution Script => $execution_script \n SILKTEST Location => $silktest_loc \n Time 4 Execution => $time_required_execute \n ATS Result Location => $ats_result_loc\n");

$logger->info(__PACKAGE__ . " Setting up the Attributes to Test Execution ");

$current_loc = "$silktest_loc";
$target_loc = 'C:\Inetpub\ftproot';
#$resultFileName = "$ats_result_loc/$file";

=head1 TMS alias usage

target_loc => is the path where the Silktest Result file will be Copied on the Windows Machine. This Location cannot be changed and usually the FTP path C:\Inetpub\ftproot

current_loc => is the PATH where the Silktest Project to be executed is located.. Ideally it is SET to C:\Program Files\Borland\SilkTest\Projects\  if any changes apart from these it needs to be modified in the TMS

script_name => The Batch file name to be executed with Silktest

ats_result_loc => The Location from where the ATS File is being executed usually located at this path /home/{user_name}/ats_repos/lib/perl/SonusQA

time_required_execute => The total time {IN Seconds} taken by Silktest to execute the projects.
The Perl script will pause for the said duration before doing a postmotem of the Test Execution...

Result_File => The details of all the Silk Test Result File MAPPED with the TEST_ID where the TMS results will be updated

release => The Release Number using which the Result to be updated on TMS
build => The Build Name using which the Result to be updated on TMS

=cut

$logger->info(__PACKAGE__ . " The Test will be executed on the Machine $hostip using the User account $hostuser 
				The Test will be for the Duration $time_required_execute  
				The Following Batch script will be Executed for this Test $execution_script 
				All the Old Results will be cleaned from the Location $target_loc 
				The Following Results File $file will be Read and Updated for test results in TMS \n");
sleep (3);
$logger->info(__PACKAGE__ . " ******* Starting the SILK TEST ********* ");
startSilkTest ("$execution_script");
$logger->info(__PACKAGE__ . " TEST COMPLETED ..... ");
sleep(2);

@res_file = split(/,/,$file);
for ($i=0;$i<=$#res_file;$i++) {
	$logger->info(__PACKAGE__ . " Retreiving the Result File $res_file[$i].... ");
		my @spl=split(/\\/, $res_file[$i]);
	copyResultFile($spl[$#spl]);
	}
sleep(2);

=head1 startSilkTest()

Start test scripts on SILKTEST

Arguments:
        Batch Script name to be executed;

Returns:
    * 1, on success
    * 0, otherwise

=cut

sub startSilkTest {
        my ($batchFile)=@_;
        my $sub = "startSilkTest";
	$t = new Net::Telnet( Timeout => 15, Host => $hostip, Errmode => "return");
        $logger->info(__PACKAGE__ . "$.sub = Connected to the Remote Host $hostip");
	$t->login( $hostuser, $hostpwd );
        $logger->info(__PACKAGE__ . "$.sub = Logged into the system using the credentials");
	sleep 2;
	$logger->info(__PACKAGE__ . "$.sub = Starting the Batch FILE for Execution $batchFile");
	$t->cmd("$batchFile");
	sleep(5);
	$logger->info(__PACKAGE__ . "$.sub = SILKTEST started on the Remote Machine...NOW...");
	sleep ($time_required_execute);	
        $logger->info(__PACKAGE__ . "$.sub = Parsing the Silktest Result after $time_required_execute");
	unless ($t->close) {
        $logger->warn(__PACKAGE__ . "$.sub = Failed to Disconnect the Remote Host...");
        }
        $logger->info(__PACKAGE__ . "$.sub = Successfully Disconnected from the Remote Host...");
return 1;
}

=head1 tmsResultUpdate()

Update the test results on TMS

Arguments:
        None

Returns:
    * 1, on success
    * 0, otherwise

=cut

sub tmsResultUpdate {
	my $sub = "tmsResultUpdate";
	my ($release, $build, $testcase_id, $result) = @_;
	$logger->info (" Release => $release  Build => $build  TestCaseID => $testcase_id  Result => $result");
	
        if ( $ENV{ "ATS_LOG_RESULT" } )
        {
                $logger->debug($suite_package . " $testcase_id: Logging result in TMS: $result for testcase ID $testcase_id");
            unless ( SonusQA::Utils::log_result (
                                            -test_result    => $result,
                                            -release        => "$release",
                                            -testcase_id    => "$testcase_id",
                                            -build          => "$build",
                                       ) ) {
                $logger->error($suite_package . " $testcase_id: ERROR: Logging of test result to TMS has FAILED");
            }
	$logger->info(__PACKAGE__ . ".$sub = Result Updated in TMS for $testcase_id");
        }
}

=head1 copyResultFile()

Clear all the Old result file {if exists with the same name} & Copy the Silktest result file i
from the Porject|S location specified onto the ftproot directory located under C:\Inetpub\ftproot

Arguments:
        Result File name to be retreived provided in TMS 

Returns:
    * 1, on success
    * 0, otherwise

=cut

sub copyResultFile {
	my ($filename) = @_;
        my $sub = "copyResultFile";
        $t = new Net::Telnet( Timeout => 15, Host => $hostip, Errmode => "return");
        $logger->info(__PACKAGE__ . ".$sub = connected to the Remote Host...");
        $t->login( $hostuser, $hostpwd );
        $logger->info(__PACKAGE__ . ".$sub = Logged In...");
	sleep 2;

	$t->cmd("cd $target_loc");
        $logger->info(__PACKAGE__ . ".$sub = executed the Command => cd $target_loc");
        $t->cmd("del $filename");
        $logger->info(__PACKAGE__ . ".$sub = deleted the old result file");
	$logger->info(__PACKAGE__ . ".$sub = executed the Command => del $filename");

        $t->cmd("cd $current_loc");
        $logger->info(__PACKAGE__ . ".$sub = executed the Command => cd $current_loc");
        $t->cmd("copy $filename $target_loc");
        $logger->info(__PACKAGE__ . ".$sub = executed the Command => copy $filename $target_loc");
	unless ($t->close) {
        $logger->warn(__PACKAGE__ . ".$sub = Failed to Disconnect the Remote Host..."); 
	}
        $logger->info(__PACKAGE__ . ".$sub = Successfully Disconnected from the Remote Host...");
	getResults($filename);
return 1;
}

=head1 getResults()

FTP the result file from the windows machine onto the Linux machine where ATS is being run

Arguments:
        File name to be retreived

Returns:
    * 1, on success
    * 0, otherwise

Internal Function

=cut

sub getResults {
	my ($fileName) = @_;
	my $sub = "getResults";
	$ftp = Net::FTP->new("$hostip", Debug => 0) or die "Cannot connect to $hostip: $@";
    	$ftp->login("$hostuser","$hostpwd") or die "Cannot login ", $ftp->message;
	$logger->info(__PACKAGE__ . ".$sub => connected to the Remote Host for FTP");
    	$ftp->get("$fileName") or die "get failed ", $ftp->message;
	$logger->info(__PACKAGE__ . ".$sub = FTP successful");
   	$ftp->quit;
	$logger->info(__PACKAGE__ . ".$sub = Disconnected from the Remote Host...");
	sleep 4;
	$resultFileName="$ats_result_loc/$fileName";
	@cmdresults = resultUpdate($resultFileName);

       for ($i=0; $i<$#cmdresults; $i++) {
                $testcase_id = $cmdresults[$i];
                $testresult  = $cmdresults[$i+1];
                $i++;
                tmsResultUpdate($release, $build, $testcase_id, $testresult);
       }


return 1;
}

=head1 resultUpdate()

Parse the result file identifying the TestID and the result condition PASS|FAIL and push it in a array

Arguments:
        File name to be retreived

Returns:
    * 1, on success
    * 0, otherwise

Internal Function

=cut

sub resultUpdate()
{
        my ($file_name) = @_;
	my $sub = "tmsResultUpdate";
        my @arr_result = ();
        open (FH, '<', $file_name) or print $!;
	$logger->info(__PACKAGE__ . ".$sub = Parsing the Result File $file_name....");
        while (defined(my $line = <FH>)) {
         if ($line =~ /:PASS:/) {
                        if ($line =~  m/\s+(\d+):(\w+):/) {
                                $a1 = $1; $a2 = $2;
                                $tms_id = "$a1";
                                $tms_result = "0";
                        }
                        push (@arr_result, "$tms_id", "$tms_result");
			print "\nTEST_ID ==> $tms_id  TEST_RESULT ==> $tms_result \n";
                }
         if ($line =~ /:FAIL:/) {
                        if ($line =~  m/\s+(\d+):(\w+):/) {
                                $a1 = $1; $a2 = $2;
                                $tms_id = "$a1";
                                $tms_result = "1";
                        }
                        push (@arr_result, "$tms_id", "$tms_result");
			print "\nTEST_ID ==> $tms_id  TEST_RESULT ==> $tms_result \n";
                }
        }
        close FH;
	$logger->info(__PACKAGE__ . ".$sub = Result File Parsed Completly...");
	return (@arr_result);
}

=head1 resolveAlias()

Internal Function modified from the framework to only read attributes from the TMS

Arguments:
        $tms_alias

Returns:
    $ats_obj_ref

Internal Function

=cut


sub resolveAlias {
    my (%args) = @_;
    my ( $value, $tms_alias, %refined_args, $ats_obj_type, );
    my $ats_obj_ref;

    # Iterate through the args that are passed in and remove tms_alias and
    # obj_type
    foreach ( keys %args ) {
        if ( $_ eq "-tms_alias" ) {
            $tms_alias = $args{-tms_alias};
        }
        elsif ( $_ eq "-obj_type" ) {
            $ats_obj_type = $args{-obj_type};
        }
        else {
            # Populate a hash with other flags passed in. This will then be
            # passed to Base::new where that function will
            # process remaining hash entries.
            $refined_args{ $_} = $args{ $_ };
        }
    }
        my $alias_hashref = SonusQA::Utils::resolve_alias($tms_alias);

    # Add TMS alias data to the newly created ATS object for later use
    $ats_obj_ref->{TMS_ALIAS_DATA} = $alias_hashref;
    # Add the TMS alias name to the TMS ALAIAS DATA
    $ats_obj_ref->{TMS_ALIAS_DATA}->{ALIAS_NAME} =  $tms_alias;
    return $ats_obj_ref;
}


1;

