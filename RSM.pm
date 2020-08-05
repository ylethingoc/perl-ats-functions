package SonusQA::RSM;


=head1 NAME

SonusQA::RSM Real-time Session Management perl Module

=cut



use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw(locate);
use Exporter;

our @ISA = qw(Exporter SonusQA::Base);

=head2 C< doinitialization >

doInitialization subroutine

=head2 description

initializating some mandatory elements

=back

=cut



sub doInitialization {
        my($self)=@_;
        $self->{COMMTYPES} = ["TELNET", "SSH"];
        $self->{conn} = undef;
        $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
        $self->{DEFAULTPROMPT} = $self->{PROMPT};
        $self->{TYPE} = __PACKAGE__;
        $self->{LOCATION} = locate __PACKAGE__ ;

}




=head3 C< setSystem >
setSystem subroutine

=head3 description

Sets the System information and prompt

=back

=cut

sub setSystem {
    my($self)=@_;
    my $subName = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName:  <-- Entering sub");
    my($cmd,$prompt, $prevPrompt);
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
   #cahnged cmd() to print() to fix, TOOLS-4974
    unless($self->{conn}->print($cmd)){
        $logger->error(__PACKAGE__ . ".$subName: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }

    unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
        $logger->error(__PACKAGE__ . ".$subName: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
        $logger->debug(__PACKAGE__ . ".$subName: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$subName: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$subName: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$subName: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$subName: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->cmd(" ");
    $logger->info(__PACKAGE__ . ".$subName  SET PROMPT TO: " . $self->{conn}->last_prompt);
    # Clear the prompt
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $self->{conn}->cmd("TMOUT=72000");
    $self->{conn}->cmd("stty cols 150");
    $self->{conn}->cmd('echo $TERM');
    $self->{conn}->cmd('export TERM=xterm');
    $self->{conn}->cmd('echo $TERM');
    #Setting the Platform type
    my @platform = $self->{conn}->cmd('uname');
    $self->{PLATFORM} =  ($platform[0] =~ /Linux/i) ? 'linux' : 'SunOS';
    #removing alias if any exists
    $self->execCmd("unalias rm");

    # Fix to TOOLS-4696. The default value is India Time Server. Please add NTP->1->IP and NTP->1->TIMEZONE in case you don't have to use default values.
     if ($self->{NTP_SYNC} =~ m/y(?:es)?|1/i) {                                     #Fix to TOOLS-4696
        my $ntpserver = $self->{NTP_IP} || "10.128.254.67";
        my $ntptimezone = $self->{NTP_TZ} || "Asia/Calcutta";
        $self->{conn}->cmd("export TZ=$ntptimezone");
        if ($self->{PLATFORM} eq 'linux' ) {
            $cmd = "sudo ntpdate -s $ntpserver";
            } else {
            $cmd = "sudo /usr/sbin/ntpdate -u $ntpserver";
            }
        my @r = ();
        unless ( @r = $self->{conn}->cmd($cmd) ) {
            $logger->error(__PACKAGE__ . ".$subName: Could not execute command for NTP sync. errmsg: " . $self->{conn}->errmsg);
        }
        $logger->info(__PACKAGE__ . ".$subName: NTP sync was successful");
    }
    $self->{conn}->cmd("set +o history");
 $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub[1]");
        return 1;
}


=head4 C< execCmd >

execCmd subroutine

=item description:

Enables user to execute any command on the server

=item Arguments:

        1. Commands to be executed.
        2. Time-out in seconds (optional).

=item Return Value:

Output of the executed Command.

=back

=cut

sub execCmd {
        my ($self, $cmd, $timeout) = @_;
        my $subName = "execCmd";
        my $logger = Log::Log4perl->get_logger(__PACKAGE__.".$subName");

        $logger->debug(__PACKAGE__ . ".$subName: <-- Entered sub ");

        unless ( $timeout) {
                $timeout = $self->{DEFAULTTIMEOUT};
                #$timeout = 120;
		$logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
        }
        else {
                $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
        }
	
	my @cmdResults;
#        $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
	
        unless(@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
		$logger->error(__PACKAGE__ . ".$subName @cmdResults");
                $logger->error(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
                $logger->error(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
		$logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");

        }

        $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
        $logger->debug(__PACKAGE__ . ".$subName:  <-- Leaving sub ");

        return @cmdResults;
}


1;
