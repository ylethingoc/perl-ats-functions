package SonusQA::POSTMAN;

=head1 NAME

SonusQA::POSTMAN- Perl module for POSTMAN

=head1 AUTHOR

  Toshima Saxena - tsaxena@rbbn.com

=head1 IMPORTANT

B<newman should be available in all ATS servers>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::POSTMAN->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                               );

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utilities::Utils, Data::Dumper 

=head1 DESCRIPTION

This module provides an interface for NEWMAN CLI installed on ATS server.

=head2 METHODS

=cut

use strict;
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Module::Locate qw(locate);
use JSON  ;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base );

=head2 C< doInitialization >

    Routine to set object defaults and session prompt.

=over

=item Arguments:

    Object Reference

=item PACKAGE:

    SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns:

    None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{LOCATION} = locate __PACKAGE__ ;

}

=head2 C< setSystem >

    This function sets the system information and Prompt.

=over

=item Arguments:

        Object Reference

=item PACKAGE:

    SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns:

        0 - if succeeds
        1 - if fails

=item EXAMPLE:

=back

=cut

sub setSystem(){
    my ($self)=@_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Entered sub");
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub_name:  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    unless($self->{conn}->print($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }

    unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }
    $logger->info(__PACKAGE__ . ".$sub_name:  SET PROMPT TO: " . $self->{conn}->last_prompt);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $self->{conn}->cmd("TMOUT=72000");
    $self->{conn}->cmd("stty cols 150");
    $self->{conn}->cmd('echo $TERM');
    $self->{conn}->cmd('export TERM=xterm');
    $self->{conn}->cmd('echo $TERM');
    $self->{conn}->cmd("set +o history");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 C< updateEnvironmentFile >

    This subroutine updates Environment File (in JSON format ) values.

=over

=item ARGUMENTS:

    Mandatory Arguments:
        env_file= Environment File
        parameters=> base_url=$vnfm_ipV4,
                     vnfm_ip =$vnfm_ipV4,
                     timeout =72000     

=item PACKAGE:

 SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item EXAMPLE:
  
    my %args=(env_file => $envFile,
              parameters=>{
                          base_url => $vnfmIPV4,
        		  vnfm_ip => $vnfmIPV4,
        		  response_time => '12000'}
             );

    unless ($obj->updateEnvironmentFile(%args)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to update Environment file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
        return 0;
    }

=item RETURNS:

     1 - file updated successfully
     0 - failed

=back

=cut

sub updateEnvironmentFile{
    my ($self,%args) = @_;
    my $sub_name = "updateEnvironmentFile";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ . "..$sub_name");   
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Args : ". Dumper(%args));
    my $fh; 
    
    unless(($args{env_file} =~ /\.json/)&&($args{parameters})) {
        $logger->error(__PACKAGE__ . ".$sub_name: The mandatory argument 'env_file' or 'parameters' has not been specified.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    unless(open( $fh, $args{env_file})){
        $logger->error(__PACKAGE__ . ".$sub_name: Can't open file $args{env_file}\n");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0; 
    }
    local $/;
    my $json = <$fh>;
    print "json: $json\n";

    my $j = JSON->new->allow_nonref;	
    my $data = $j->decode($json);
    close $fh;
    $logger->debug(__PACKAGE__ . ".$sub_name: data : ". Dumper($data));
    for my $keyValue (@{ $data->{values} }){
	if ($args{parameters}->{$keyValue->{key}}){
	    if($keyValue->{key} eq 'base_url'){
                $keyValue->{value}="https://".$args{parameters}->{$keyValue->{key}};
            }
	    else{
		$keyValue->{value}=$args{parameters}->{$keyValue->{key}};
	    }   
        }
        delete $args{parameters}->{$keyValue->{key}};
    }	
    if(keys %{$args{parameters}}){
       $logger->error(__PACKAGE__ . ".$sub_name: Following keys does not exist in $args{env_file} ".Dumper($args{parameters}));
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
       return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: data : ". Dumper($data));
    unless(open( $fh, ">$args{env_file}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Can't open file $args{env_file}\n"); 
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0; 
    }
    print $fh $j->pretty->encode($data);
    close $fh;
    $logger->info(__PACKAGE__.".$sub_name: Environment File Updated");
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 execPostman
   
     This subroutine execute Postman command on server.

=over

=item Arguments

     Mandatory Args:
        collection_file-> this variabl;e specifies where the postman collection file is saved.
        env_file-> Environment File.
        file_name-> Location where the postman execution result will be saved.
     Optional Args:
        folder-> Folder name present in postman collection that needs to be run in specific testcase 
        timeout- timeout value for command execution.
    
=item Returns

     1 - Postman command is executed successfully.
     0 - Fail to execute postman command.

=item Example
    
    my %args=(  collection_file=>$collectionFile,
                env_file=> $environmentFile,
                result_file=>$resultfile
                folder=>$folder,
                timeout=>72000
             )  

    unless ($obj->execPostman(%args)){            
        $logger->error(__PACKAGE__ . ".$sub_name:failed to run Postman");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub");
        $subResult=0;
        return 0;
    }

=back

=cut

sub execPostman{
    my($self,%args)=@_;
    my $sub_name="execPostman";
    my ($fh,$flag,$cmd_exec);
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Args : ". Dumper(%args));
    
    unless( $args{collection_file} && $args{env_file} && $args{result_file} ){
        $logger->error( ".$sub_name: The mandatory argument FILES have not been specified or is blank.");
        $logger->debug( ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ( defined ($args{folder})){
        $cmd_exec="newman run $args{collection_file} --folder $args{folder} --insecure -e $args{env_file} --timeout-script $args{timeout} --export-environment $args{env_file} > $args{result_file} " ;
    }
    else{
	$cmd_exec="newman run $args{collection_file} --insecure -e $args{env_file} --timeout-script $args{timeout} --export-environment $args{env_file} >$args{result_file} ";
    }
    $self->execCmd("npm bin");
    $self->execCmd("export PATH=\$(npm bin):\$PATH");
    $self->execCmd("echo \$PATH");

    my @cmd_result=$self->execCmd($cmd_exec, $args{timeout});
    if (grep{/newman: command not found/} @cmd_result){
	$logger->error(__PACKAGE__ . ".$sub_name: newman : command not found");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    unless(-e $args{result_file}){
        $logger->error(__PACKAGE__ . ".$sub_name: failed to execute postman");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: command executed successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [1]");
    return 1;
}
	
=head2 C< execCmd() >

    This function enables user to execute any command on the server.

=over

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item PACKAGE:

    SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns:

    0            - fail
    \@cmdresults - Success (Reference to command result array)

=item EXAMPLE:

    $postmanObj->execCmd("newman run VNFMFolder.postman_collection.json --folder cleanup --insecure -e VNFM.postman_environment.json --timeout-script 720000 --export-environment  VNFM.postman_environment.json ");

=back


=cut

sub execCmd{
    my ($self, $cmd, $timeout) = @_;
    my $sub_name = "execCmd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__.".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Entered sub ");

    unless ( $timeout) {
       $timeout = $self->{DEFAULTTIMEOUT};
       $logger->debug(__PACKAGE__ . ".$sub_name: Timeout not specified. Using $timeout seconds ");
    }
    else {
       $logger->debug(__PACKAGE__ . ".$sub_name: Timeout specified as $timeout seconds ");
    }

    my @cmdResults;
    $logger->info(__PACKAGE__ . ".$sub_name: ISSUING CMD: $cmd");
    unless(@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
       $logger->error(__PACKAGE__ . ".$sub_name: @cmdResults");
       $logger->error(__PACKAGE__ . ".$sub_name:  COMMAND EXECUTION ERROR OCCURRED");
       $logger->error(__PACKAGE__ . ".$sub_name:  errmsg : ". $self->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: : @cmdResults");
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub ");
    return @cmdResults;
}

=head2 C<postmanValidation >

    Routine to validate the result of postman cmd

=over

=item Arguments:

    Mandatory Args: file_name- result file obtained

=item PACKAGE:

    SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns:

    1 - All testcases passed
    0 - failure case

=item EXAMPLE:
    
    $obj->postmanValidation($result_file);

=back

=cut

sub postmanValidation{
    my ($self,$file_name)=@_;
    my $result=0;  
    my $sub_name = "postmanValidation";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ . "..$sub_name");
  
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub"); 
   
    unless ( $file_name ) {
        $logger->error(__PACKAGE__ . ".$sub_name: ERROR: The mandatory argument for $_ has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless(-e $file_name){
        $logger->error(__PACKAGE__ . ".$sub_name: File does not exist");
        $logger->error(__PACKAGE__ . ".$sub_name: failed to execute postman");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }     
    $logger->debug(__PACKAGE__ ."\t FilePath = $file_name \n");
    my ($grepTestScripts) = $self->execCmd("grep \"test-scripts\" $file_name | grep -Po \'[0-9]*\' | tail -n 1");
    $logger->debug(__PACKAGE__ ."TEST SCRIPT:: $grepTestScripts\n");
    my ($grepAssertions ) = $self->execCmd("grep \"assertions\" $file_name | grep -Po \'[0-9]*\' | tail -n 1");
    $logger->debug(__PACKAGE__ ."ASSERTIONS:: $grepAssertions\n");
    unless($grepTestScripts ne "" && $grepAssertions ne "" ){     
        $logger->error(__PACKAGE__ . ".$sub_name: TestScripts/Assertions value is null");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    if ( $grepTestScripts == 0 && $grepAssertions == 0){
        $result = 1;
    }
    else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__."Test Scripts output = $grepTestScripts");
    $logger->info(__PACKAGE__."Assertion output = $grepAssertions");
    $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub[$result]");
    return $result;
}

=head2 C<checkJsonResult >
    TOOLS-78288
    Routine to validate the json result of postman cmd


=over

=item Arguments:

    Mandatory Args: 
    json_file => JSON result file to parse
=item PACKAGE:

    SonusQA::POSTMAN

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item Returns:

    P - for pass, if all pending and failed counts  are 0
    F - for fail, if any pending or failed counts  are non 0
    0 - in any other failure

=item EXAMPLE:
    
    $obj->checkJsonResult(json_file => "/home/ayadav/test/newman-run-report-2020-04-28-07-04-42-319-0.json");

=back

=cut

sub checkJsonResult{
    my (%args) = @_;
    my $sub_name = "checkJsonResult";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ . "..$sub_name");
  
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub"); 
   
    unless ( $args{json_file} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: ERROR: The mandatory argument for $args{json_file} has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } 
    my @results;
    unless(@results = `cat $args{json_file} |jq .run.stats`){
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot open the file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $flag ='P';
    foreach(@results){
        if($_ =~/"pending":\s(\d)|"failed":\s(\d)/){
            if($1!=0 || $2!=0){
                $logger->debug(__PACKAGE__ . ".$sub_name:Testcase Failed");
                $flag ='F';
                last;
            }

        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:<---Leaving Sub[$flag]");
    return $flag;

}

1;
