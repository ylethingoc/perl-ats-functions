package SonusQA::VMCCS;

=item NAME

SonusQA::VMCCS- Perl module for VMCCS

=item AUTHOR

Venkata Suhas Jinka Ramesh - vramesh@rbbn.com


=item SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::VMCCS->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<SSH>",
                               );

=item REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base,  Data::Dumper,

=item DESCRIPTION

VNF platform for hosting containerized RBBN applications in VM managed environments. Base common services for bootstrap, logging, monitoring and security.
WIKI Link: https://wiki.sonusnet.com/pages/viewpage.action?pageId=271277233
This module provides an interface for Any VMCCS.

=item METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
our @ISA = qw(SonusQA::Base);

=item B<doInitialization>

    This subroutine is to set object defaults

=cut
sub doInitialization {
    my($self)=@_;
    my $sub="doInitialization()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__."$sub");
    $logger->debug(__PACKAGE__."$sub:  --> Entered sub");

    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*\-.*\-.*#/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; 
    $logger->debug(__PACKAGE__."$sub:  <-- Leaving sub");
}


=item B<setSystem>

    This subroutine sets the system information and prompt.

=cut

sub setSystem(){
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__."$sub");
    $logger->debug(__PACKAGE__."$sub: --> Entered Sub");

    my($cmd, $prev_prompt);
    $self->{conn}->cmd("bash");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prev_prompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__."$sub: SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prev_prompt");
    $self->{conn}->cmd($cmd);
    $logger->info( __PACKAGE__."$sub: SET PROMPT TO: " . $self->{conn}->last_prompt);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $self->{conn}->cmd('unalias grep');
    $logger->debug( __PACKAGE__."$sub: <-- Leaving sub[1]");
    return 1;
}


=head2 C< execCmd() >

    This function enables user to execute any command on the server.

=over

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

sub execCmd {
    my ($self,$cmd, $timeout)=@_;
    my $sub = "execCmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "$sub");
    my(@cmdResults,$timestamp);
    $logger->debug( __PACKAGE__."$sub --> Entered Sub");
    unless($timeout) {
        $timeout = $self->{DEFAULTTIMEOUT};
        $logger->debug( __PACKAGE__."$sub Timeout not specified. Using DEFAULTTIMEOUT, $timeout seconds ");
    }
    else {
        $logger->debug( __PACKAGE__."$sub Timeout specified as $timeout seconds ");
    }
    
    $logger->info( __PACKAGE__."$sub ISSUING CMD: $cmd");
    unless ( @cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return" )) {
        $logger->error( __PACKAGE__."$sub COMMAND EXECUTION ERROR OCCURRED");
        $logger->error( __PACKAGE__."$sub errmsg: " . $self->{conn}->errmsg);
        $logger->debug( __PACKAGE__."$sub Session Dump Log is : $self->{sessionLog1}");
        $logger->debug( __PACKAGE__."$sub Session Input Log is: $self->{sessionLog2}");

        #sending ctrl+c to get the prompt back in case the command execution is not completed. So that we can run other commands.
        $logger->error( __PACKAGE__."$sub  Sending ctrl+c");
        unless($self->{conn}->cmd(-string => "\cC")){
            $logger->warn( __PACKAGE__."$sub  Didn't get the prompt back after ctrl+c: errmsg: ". $self->{conn}->errmsg);

            #Reconnect in case ctrl+c fails.
            $logger->warn( __PACKAGE__."$sub  Trying to reconnect...");
            unless( $self->reconnect() ){
                $logger->warn( __PACKAGE__."$sub Failed to reconnect.");
                $logger->debug(__PACKAGE__."$sub: <-- Leaving Sub[] ");
                return ();
            }
            #TOOLS-78559
            $logger->debug(__PACKAGE__. ".$sub: Retrying command: $cmd ");
            unless (@cmdResults = $self->{conn}->cmd( String =>$cmd, Timeout=>$self->{DEFAULTTIMEOUT})) {
                $logger->error(__PACKAGE__ . ".execCmd \'$cmd\' re-execution failed after the reconnection");
                $logger->debug(__PACKAGE__."$sub: <-- Leaving Sub[] ");
                return ();                
            }
        }
        else {
            $logger->info(__PACKAGE__."$sub Sent ctrl+c successfully.");
        }
    }
    chomp(@cmdResults);
    $logger->debug( __PACKAGE__."$sub : ". Dumper \@cmdResults);
    $logger->debug( __PACKAGE__."$sub  <-- Leaving sub");
    return @cmdResults;
}

1;