package SonusQA::VIGIL;

=head1 NAME

SonusQA::VIGIL- Perl module for VIGIL

=head1 AUTHOR

Vishwas Gururaja - vgururaja@sonusnet.com

=head1 IMPORTANT

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::VIGIL->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate, SonusQA::VIGIL::HADOOP

=head1 DESCRIPTION

This module provides an interface to create VIGIL Object and nodes present in that and enables to execute SQL Commands on Postgres and Hadoop Impala-shell.

=head1 METHODS

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;
use Data::Dumper;
use SonusQA::VIGIL::HADOOP;
use LWP::UserAgent;
use HTTP::Cookies;
use MIME::Base64;

my $cookie_jar = HTTP::Cookies->new;


our $VERSION = "1.0";
our @ISA = qw(SonusQA::Base);

=head2 B<new()>

=over 6

=item DESCRIPTION:

 This subroutine is called from ATSHELPER newFromAlias() if the object type is  VIGIL. This function creates a VIGIL object and correspondingly objects for different nodes present in it. 

=item ARGUMENTS:

 %args - Arguments passed while calling newFromAlias

=item RETURNS:

 $vigilObj - $vigilObj->{'MAG'}, $vigilObj->{'KAFKA'}, $vigilObj->{'POSTGRES'}, $vigilObj->{'HADOOP-DATA-1'}, $vigilObj->{'HADOOP-MASTER'}, 
 $vigilObj->{'DIG'}, $vigilObj->{'ALE-ROBOCALL'} etc

=back

=cut

sub new {
    my ($class,%args) = @_;
    my $sub = "new";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub: Creating VIGIL object");
    my $vigilObj;
    unless($vigilObj = SonusQA::Base::new($class, %args)){
        $logger->error(__PACKAGE__ . ".$sub: Could not create VIGIL object");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving Sub[0]");
        return 0;
    }
    my @pods;
    if(exists $args{-connect_to_pod} and $args{-connect_to_pod} == 0){
        $logger->debug(__PACKAGE__ . ".$sub: The value of key '-connect_to_pod' is '0'. Not creating object for any of the pods");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
        return $vigilObj;
    }elsif(exists $args{-connect_to_pod} and (ref $args{-connect_to_pod} eq 'ARRAY')){
        $logger->debug(__PACKAGE__ . ".$sub: Creating object and connecting to the pods: @{$args{-connect_to_pod}}");
	@pods = @{$args{-connect_to_pod}};
    }else{
        $logger->debug(__PACKAGE__ . ".$sub: Creating object for pods with status 'Running'");
        @pods = qw(aggengine ale-lcr ale-cdrviewer ale-bwlist ale-networkldapp ale-robocall ale-sentry ale-tdos dig flume gotty hadoop-data-0 hadoop-data-1 hadoop-data-2 hadoop-data-3 hadoop-master-0 hadoop-master-1 hadoop-master-2 hadoop-master-sl kafka-0 kafka-1 kafka-2 kafka-3 mag policymanager postgres-0 postgres-1 postgres-2 sim sysdiag tca threatengine zookeeper-0 zookeeper-1 zookeeper-2 zookeeper-3 zoomdata aggapps addons pqe ruleengine screeninglist digcore digpcap magcore c20dig analysis dynamictables); 
    }
        
	my @pod_status = $vigilObj->execCmd("kubectl get pods");
	shift @pod_status;
#$VAR1 = [
#          'NAME            READY     STATUS    RESTARTS   AGE',
#          'ale-bwlist      1/1       Running   0          1d',
#          'ale-robocall    1/1       Running   0          1d',
#          'dig             2/2       Running   0          1d',
#          'flume           1/1       Running   0          1d',
#          'hadoop-data-1   1/1       Running   0          1d',
#          'hadoop-master   1/1       Running   0          1d',
#          'kafka           1/1       Running   0          1d',
#          'mag             1/1       Running   0          1d',
#          'postgres        1/1       Running   0          1d'
#        ];
    my $pods = join('|', @pods);
    my $logs = $args{-sessionLog};
    foreach my $name (@pod_status){
        next unless($name =~ /\s*(($pods)\S*)\s+\d\/\d\s+Running.*/i);
        my $pod = $1;
        my $pod_name = $2;
        $class = 'SonusQA::VIGIL';
        $args{'node_type'} = $pod;
        $logger->debug(__PACKAGE__ . ".$sub: Creating object for node: $pod_name");
        if($args{-sessionLog}){
            $args{-sessionLog} = ($logs eq '1') ? (uc $pod_name) : ($logs . uc $pod_name);
        }
        if($pod =~ /HADOOP-MASTER/i){
            $class = 'SonusQA::VIGIL::HADOOP';
        }
        unless($vigilObj->{uc $pod_name} = SonusQA::Base::new($class, %args)){
            $logger->error(__PACKAGE__ . ".$sub: Could not create object for $pod_name");
            undef $vigilObj;
            last;
        }
        $logger->debug(__PACKAGE__ . ".$sub: Object created for $pod_name");
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
    return $vigilObj;   
}

=head2 B<doInitialization()>

=over 6

=item DESCRIPTION:

 Routine to set object defaults and session prompt.

=item Arguments:

 Object Reference

=item Returns:

 None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered Sub");

    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]]\s*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; 
    $self->{LOCATION} = locate __PACKAGE__ ;

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
}

=head2 B<setSystem()>

    This function sets the system information and Prompt.

=over 6

=item Arguments:

        Object Reference

=item Returns:

        Returns 0 - If succeeds
        Reutrns 1 - If Failed

=back

=cut

sub setSystem(){
    my ($self) = @_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    unless($main::TESTSUITE->{VIGIL_APPLICATION_VERSION}){                                                              #TOOLS-15141
        unless($main::TESTSUITE->{VIGIL_APPLICATION_VERSION} = $self->getApplicationVersion()){
            $logger->error(__PACKAGE__ . ".$sub: Could not get the release version");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0 ;
        }
        $main::TESTSUITE->{VIGIL_APPLICATION_VERSION} = 'VIGIL_V'.$main::TESTSUITE->{VIGIL_APPLICATION_VERSION};       #Adding 'product' name followed by 'V'for use in build version
        $logger->debug(__PACKAGE__ . ".$sub: Setting 'TESTSUITE->{VIGIL_APPLICATION_VERSION}' as $main::TESTSUITE->{'VIGIL_APPLICATION_VERSION'}");
    }
    my($cmd,$prompt, $prevPrompt);
    if($self->{NODE_TYPE}){
        my $cmd= "kubectl exec $self->{NODE_TYPE} \-it bash";
        unless($self->{conn}->cmd(string => $cmd, timeout => 60, errmode => "return")){
            $logger->error(__PACKAGE__ . ".$sub: Not able to execute the command, $cmd");
            $logger->debug(__PACKAGE__ . ".$sub: trying 'enter'");
            my @result = $self->{conn}->cmd('');
            my $last_prompt = $self->{conn}->last_prompt;
            my ($temp) = split(/-/,$self->{NODE_TYPE});
            $logger->debug(__PACKAGE__ . ".$sub: result after 'enter': ". Dumper(\@result));
            $logger->debug(__PACKAGE__ . ".$sub: prompt: " . $temp);
            $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $last_prompt);
            $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
            unless($last_prompt =~/$temp/){
                $logger->error(__PACKAGE__ . ".$sub: Could not identify prompt after enter");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
                return 0;
            }
        }
    }
    $self->{conn}->cmd("bash");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
     unless ($self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $self->{conn}->cmd("set +o history");
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<execCmd()>

    This function enables user to execute any command on the server.

=over 6

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Return Value:

    Output of the command executed.

=item Example:

    my @results = $obj->execCmd("cat test.txt");
    This would execute the command "cat test.txt" on the session and return the output of the command.

=back

=cut

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $sub = "execCmd";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my(@cmdResults,$timestamp);
   $logger->debug(__PACKAGE__ . ".$sub Entered Sub");
   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub Timeout not specified. Using $timeout seconds ");
   }else {
      $logger->debug(__PACKAGE__ . ".$sub Timeout specified as $timeout seconds ");
   }

   $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->error(__PACKAGE__ . ".$sub COMMAND EXECUTION ERROR OCCURRED");
      $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub LAST LINE:" . $self->{conn}->lastline);
      $logger->debug(__PACKAGE__ . ".$sub PROMPT : " . $self->{conn}->prompt);
      $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");

      $logger->info(__PACKAGE__ . ".$sub Sending ctrl+c");
      unless($self->{conn}->cmd(-string => "\cC")){
        $logger->error(__PACKAGE__ . ".$sub Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);
      }else {
        $logger->info(__PACKAGE__ .".$sub Sent ctrl+c successfully.");
      }

   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub ...... : @cmdResults");
   $logger->debug(__PACKAGE__ . ".$sub  <-- Leaving sub");
   return @cmdResults;
}

=head2 B<executeSQL()>

=over 6

=item DESCRIPTION:

 This function connects to POSTGRES and executes the SQL commands passed to it as the argument and returns a hash containing column name as the key and the records in the column as an array of values.

=item ARGUMENTS:

 %params - ('username' => 'vigil', 'database' => 'sensorstore', 'command' => 'select * from sonuscdrtable limit 5;')

=item RETURNS:

 A hash - %output
    If the command is a 'select' command
 0
    If the command results in an error
 1
    If the command executed is anything other than select command like 'INSERT', 'DELETE' etc.

=item PACKAGE:

 SonusQA::VIGIL

=item EXAMPLE:

 $vigilObj->{POSTGRES}->executeSQL('username' => 'vigil', 'database' => 'sensorstore', 'command' => 'select * from sonuscdrtable limit 5;');
 OR
 $vigilObj->executeSQL('username' => 'vigil', 'database' => 'sensorstore', 'command' => 'select * from sonuscdrtable limit 5;');

=back

=cut

sub executeSQL {
    my ($self, %input_param)=@_;
    my (@cmd_Result, $logger, %output, $record_Count);
    my $sub = "executeSQL";
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    
    my $prompt = $input_param{'database'}. '[=\-\(][#\>]';
    unless($input_param{'username'} and $input_param{'database'} and $input_param{'command'}){
        $logger->error(__PACKAGE__ . ".$sub: One or more of the mandatory parameters not present");
        $logger->debug(__PACKAGE__ . ".$sub: Username is: \'$input_param{'username'}\', Database is: \'$input_param{'database'}\', Command is: \'$input_param{'command'}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }    
    $logger->debug(__PACKAGE__ . ".$sub: Node Type is: $self->{NODE_TYPE}");
    unless ($self->{conn}->cmd(String => "psql \-U $input_param{'username'} $input_param{'database'} \-P pager=off", Prompt => "/$prompt/")) {        
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER SQL ");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless (@cmd_Result = $self->{conn}->cmd(String => '\x on', Prompt => "/$prompt/")) {

        $logger->error(__PACKAGE__ . ".$sub: Failed to execute '\\x on'. Could not set expanded display");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    #TOOLS-77896 - splitting the command to handle long queries
    my ($cmd1, $cmd2) = split / from /i,  $input_param{'command'};
    my (@cmds) = split ',',  $cmd1;
    my $ind = $#cmds;
    push @cmds, " from $cmd2" if($cmd2);
    $logger->debug(__PACKAGE__ . ".$sub: command: $input_param{command}");
    $logger->debug(__PACKAGE__ . ".$sub: cmds: ". Dumper(\@cmds));

    my $flag;
    for (my $i=0; $i< @cmds; $i++){
        $cmds[$i].=',' if($i < $ind);
        unless (@cmd_Result = $self->{conn}->cmd(String => $cmds[$i], Prompt => "/$prompt/")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute command, $cmds[$i] / $i ");
            $flag = 1;
            last;
        }
    }
 
    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub: sending the exit");
    $self->{conn}->cmd("\\q");

    if (grep (/ERROR:/, @cmd_Result)) {
        $logger->error(__PACKAGE__ . ".$sub: Command \'$input_param{'command'}\' resulted in error. Result:".Dumper(\@cmd_Result));
        $self->{'SQL_ERROR'} = \@cmd_Result;
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: successfully executed SQL command: \'$input_param{'command'}\'");
    
    if(grep (/0\s+rows/i, @cmd_Result)){
        $logger->error(__PACKAGE__ . ".$sub: No Data found ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless($input_param{'command'} =~ /select/i){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    }

    chomp (@cmd_Result);
    @cmd_Result = grep /\S/, @cmd_Result;
    foreach(@cmd_Result){
        unless($_ =~ /\-*\[\s*RECORD(.*)\s*\]\-*/){
            my ($field, $value) = split(/\|/);
            $field =~ s/^\s+|\s+$//g;
            $value =~ s/^\s+|\s+$//g;
            push(@{$output{$field}},$value);
        }
        $record_Count = $1;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$record_Count]");
    return %output;
}

=head2 B<tailFlumeLog()>

=over 6

=item DESCRIPTION:

 This sub tails the current flume log for the testcase that is being executed.

=item ARGUMENTS:

 %params - ('logfilename')

=item RETURNS:
  
 0 If the command results in an error
 1 If tail is successful

=item PACKAGE:

 SonusQA::VIGIL

=item EXAMPLE:

 $vigilObj->tailFlumeLog($testCaseId)

=back

=cut

sub tailFlumeLog{
    my ($self, $tmsid) = @_ ;
    my $sub_name = "tailFlumeLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    unless ( $tmsid ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my ($logfile, @result);
    @result = $self->{'FLUME'}->execCmd("cd /var/lib/vigil/flume/data/");
    if(grep /No such file or directory/, @result){
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not execute \'cd /var/lib/vigil/flume/data/\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless( ($logfile) = $self->{'FLUME'}->execCmd('ls -t1 *vigil* |  head -n 1')){
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not get the log file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{'FLUME'}->{conn}->print("tail -f $logfile | tee $tmsid.log") ){
        $logger->error(__PACKAGE__ . ".$sub_name:   Tail of log unsuccessful ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<endFlumeLog()>

=over 6

=item DESCRIPTION:

 This sub ends the tail of the log and stores it

=item RETURNS:
  
 0 If the command results in an error
 1 If log is saved successfully

=item PACKAGE:

 SonusQA::VIGIL

=item EXAMPLE:

 $vigilObj->endFlumeLog();

=back

=cut

sub endFlumeLog{
    my $self = shift ;
    my $sub_name = "endFlumeLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless($self->{'FLUME'}->{conn}->cmd("\cC")){
        $logger->error(__PACKAGE__ . ".$sub_name: Save of log is unsuccessful");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Save of log is successful");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<kickOff()>

=over 6

=item DESCRIPTION:

 It's a wrapper function to kick start the automation by tailing the logs and storing it.

=item ARGUMENTS:

 A hash reference containing: 
 
 Mandatory:
      Testcase ID('testcase_id' as the key)

=item RETURNS:
  
 0 If the tail failed
 1 If tail of logs was successful

=item PACKAGE:

 SonusQA::VIGIL

=item EXAMPLE:

 $vigilObj->kickOff(\%hash);

=back

=cut

sub kickOff {
    my ($self, $hash_ref) = @_ ;
    my $sub_name = "kickOff";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my %parameters = %$hash_ref;
    $self->{WAS_KICKED_OFF} = 0; #to be used in wind_Up to check whether kick_Off is success or not. (Fix for TOOLS-3790)
    unless ($parameters{'testcase_id'}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Tailing Flume logs for test case: $parameters{'testcase_id'}");
    unless($self->tailFlumeLog($parameters{'testcase_id'})){
        $logger->error(__PACKAGE__ . ".$sub_name: Error tailing the logs");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Tail of log successful");
    $self->{WAS_KICKED_OFF} = 1;    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<windUp()>

=over 6

=item DESCRIPTION:

   This subroutine does parse log check and store flume logs. Need to be called as 'root'. 

=item ARGUMENTS:

 A hash reference containing following keys:

 MANDATORY:
   1. TestCase Id          - 'testcase_id'

 OPTIONAL:
   1. Name of the file     - 'parse_log_file'
   2. Search Pattern       - A hash with key 'pattern'
   3. Log copy location    - 'copy_location'
   4. Log Store Flag       - 'log_store_flag'

=item EXTERNAL FUNCTIONS CALLED:
 
 SonusQA::VIGIL::endFlumeLog()
 SonusQA::Base::storeLogs()
 SonusQA::Base::parseLogFiles()

=item PACKAGE:

 SonusQA::VIGIL

=item OUTPUT:

 0   - failure
 1   - success

=item EXAMPLES:

 my $parse = {"ScheduledJob ---->ATTEMPTS" => 1};
 my %windupparam=(
    'testcase_id' => $testCaseId,
    'parse_log_file' => $parseFile,
    'pattern' => $parse,
    'copy_location' => $TESTSUITE->{PATH},
    'log_store_flag' => $TESTSUITE->{STORE_LOGS},
    'source_path' => $path
 ); 
 $vigilObj->windUp(\%windupparam)

=back

=cut

sub windUp {
    my ($self, $hash_param) = @_;
    my $sub_name = "windUp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmdresults = $self->execCmd('id');
    unless (grep(/root/, @cmdresults)){
        $logger->debug( __PACKAGE__ . ".$sub_name: You must be logged in as root" ) ;
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    unless($self->{'WAS_KICKED_OFF'}){
        $logger->debug(__PACKAGE__ . ".$sub_name: Can't do wind_Up, since kick_Off either failed or was not called.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my %params = %$hash_param;
    unless ($params{'testcase_id'}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($params{'source_path'}) {
        $logger->error(__PACKAGE__ . ".$sub_name: Source path of log is empty or blank. Using default path '/nodesec/flume/'");
        $self->{'LOG_PATH'} = '/nodesec/flume/';
    }else{
        $self->{'LOG_PATH'} = $params{'source_path'};
    }
    unless($self->endFlumeLog()){
        $logger->debug(__PACKAGE__ . ".$sub_name: Could not save the log");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my (%searchpattern,$copy_log_location);
    if(defined ($params{'copy_location'})) {
        $copy_log_location = $params{'copy_location'}."/logs";
    }else {
        my $logPath = (defined  $main::TESTSUITE->{PATH} and $main::TESTSUITE->{PATH}) ? $main::TESTSUITE->{PATH} : $self->{LOG_PATH};
        $logger->warn(__PACKAGE__ . ".$sub_name: The location to copy Logs not Defined !! By Default the Logs will be stored in the server at Path => $logPath/logs ");
        $copy_log_location = "$logPath/logs";

    }
    unless ( $self->execCmd("mkdir -p $copy_log_location") ) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Could not create Log Directory ");
    }

    ######## STORING THE LOGS ##################################################

    if ($main::TESTSUITE->{STORE_LOGS}) {
        unless ($self->storeLogs($params{'parse_log_file'},$params{'testcase_id'},$copy_log_location) ) {
            $logger->error(__PACKAGE__ . " $sub_name:   Failed to store the log file: $params{'parse_log_file'}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    ######## Parse Logs ######################################################
    my $parse_flag = 1;
    if($params{pattern}){
        $logger->debug(__PACKAGE__ . " $sub_name: Looking for the patterns in the log '$params{'parse_log_file'}'");
        my ($matchcount,$result) = $self->parseLogFiles($params{'parse_log_file'}, $params{pattern});
        unless($result == 1){
            $logger->debug(__PACKAGE__ . " $sub_name: All the patterns are NOT FOUND in the log,'$params{'parse_log_file'}'");
            $parse_flag = 0;
        } else {
            $logger->debug(__PACKAGE__ . " $sub_name: All the patterns are FOUND in the log,'$params{'parse_log_file'}'");
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$parse_flag]");
    return $parse_flag;
}

=head2 B<getApplicationVersion()>

=over 6

=item DESCRIPTION:

   This subroutine is used to obtain the release version from the file /etc/relversion.txt. This function is called from setSystem().
                            vigiladmin@vigilam3a104:/etc$ cat /etc/relversion.txt
                            01.00.00A104

=item ARGUMENTS:

 None

=item EXTERNAL FUNCTIONS CALLED:

 SonusQA::VIGIL::execCmd()

=item PACKAGE:

 SonusQA::VIGIL

=item OUTPUT:

 0   - failure
 release version   - success

=item EXAMPLES:

 my $version = $vigilObj->getApplicationVersion();

=back

=cut

sub getApplicationVersion{
    my $self = shift;
    my $sub_name = "getApplicationVersion";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my ($software,$cmdresults);
    unless(($software) = $self->execCmd("kubectl get configmap | grep software")){
        $logger->error(__PACKAGE__ . " $sub_name: Failed to get the software-info");
  	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    	return 0;
    }
    if($software=~ /(software-info-.+)\s+\d+\s+/x){
        ($cmdresults)=$self->execCmd("kubectl get configmap $1 -o json | grep relversion");
    }
    else{       
	$logger->error(__PACKAGE__ . " $sub_name: Failed to get version");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }
    if ($cmdresults=~ /((\d)+\.(\d{2})\.(\d{2})[A-Z]*(\d{3})*)/){
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$1]");
    return $1;
    }
}


=head2 B<vigilLogin()>

=over 6

=item DESCRIPTION:

   This subroutine is used to login into vigil using LWP::UserAgent

=item ARGUMENTS:

 -loginip
 -username
 -password

=item EXTERNAL FUNCTIONS CALLED:

 SonusQA::VIGIL::vigilLogin()

=item PACKAGE:

 SonusQA::VIGIL

=item OUTPUT:

 0   - failure
 1   - success

=item EXAMPLES:

  unless($vigilObj->vigilLogin(-loginip => '10.XX.XX.XX', -username=> 'XX', -password=> 'XX')){
         $logger->debug(__PACKAGE__ . ".$sub_name: Login failed");
  }

=back

=cut


sub vigilLogin{
    my ($self,%args) = @_;
    my $sub_name = "vigilLogin";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 0);
    $ua->ssl_opts(SSL_verify_mode => 0x00);

    my $url = "https://$args{-loginip}/login/api/system/sessions/";
    my $auth = "Basic ".encode_base64($args{-username}.':'.$args{-password});

     my $response = $ua->post( $url,
                        Accept=>'application/json',
                        Authorization=>$auth,
                        Content_Type => 'application/json',
                        );

    $ua->{authorization} = $response->authorization;
     my $cookie_jar = HTTP::Cookies->new;
     $cookie_jar->extract_cookies($response);
     $ua->cookie_jar($cookie_jar);
     unless($response->code eq "200") {
         $logger->error(__PACKAGE__ . ".$sub_name: <-- Unable to login into $url");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Login successful");
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->code);
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->content);
     $self->{lwpAgent} = $ua;
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
     return 1;
}

=head2 B<vigilLogout()>

=over 6

=item DESCRIPTION:

   This subroutine is used to logout into vigil using LWP::UserAgent

=item ARGUMENTS:

 -loginip

=item EXTERNAL FUNCTIONS CALLED:

 SonusQA::VIGIL::vigilLogout()

=item PACKAGE:

 SonusQA::VIGIL

=item OUTPUT:

 0   - failure
 1   - success

=item EXAMPLES:

    unless($vigilObj->vigilLogout(-loginip => '10.XX.XX.XX')){
         $logger->debug(__PACKAGE__ . ".$sub_name: Logout failed");
     }

=back

=cut


sub vigilLogout{
    my ($self,%args) = @_;
    my $sub_name = "vigilLogout";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
print Dumper($self->{lwpAgent});
    my $ua = $self->{lwpAgent};

    my $url = "https://$args{-loginip}/api/system/sessions/1";

     my $response = $ua->delete( $url,
                        Accept=>'application/json',
                        Authorization=>$ua->{authorization},
                        Content_Type => 'application/json',
                        );



     unless($response->code eq "200") {
         $logger->error(__PACKAGE__ . ".$sub_name: <-- Unable to logout into $url");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 1;
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Logout successful");
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->code);
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->content);
     $self->{lwpAgent} = $ua;
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
     return 1;
}


=head2 B<vigilFileUpload()>

=over 6

=item DESCRIPTION:

   This subroutine is used to logout into vigil using LWP::UserAgent

=item ARGUMENTS:

 -loginip
 -filename

=item EXTERNAL FUNCTIONS CALLED:

 SonusQA::VIGIL::vigilFileUpload()

=item PACKAGE:

 SonusQA::VIGIL

=item OUTPUT:

 0   - failure
 1   - success

=item EXAMPLES:

    unless($vigilObj->vigilFileUpload(-loginip => '10.XX.XX.XX', -filename => '/home/username/abc.TRC')){
         $logger->debug(__PACKAGE__ . ".$sub_name: File upload failed");
     }


=back

=cut

sub vigilFileUpload{
    my ($self,%args) = @_;
    my $sub_name = "vigilFileUpload";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $ua = $self->{lwpAgent};

    my $url = "https://$args{-loginip}/api/service/ale-networkldapp/app/inputfile";



     my $response = $ua->post( $url,
                        Accept=>'application/json',
                        Content_Type => 'multipart/form-data',
                        Authorization=>$ua->{authorization},
                        Content => [ filename => ["$args{-filename}"] ]
                        );

     unless($response->code eq "200") {
         $logger->error(__PACKAGE__ . ".$sub_name: <-- Unable to login into $url");
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- File upload successful");
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->code);
     $logger->debug(__PACKAGE__ . ".$sub_name: <--Responce code ".$response->content);
     $self->{lwpAgent} = $ua;
     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
     return 1;
}

1;
