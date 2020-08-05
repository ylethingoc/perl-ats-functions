package SonusQA::CDA;

=pod

=head1 NAME

SonusQA::CDA - Perl module for interacting with CDA(Cloud Data Analytics) which is a Datawarehouse Node - Collects all raw data from data agents/producers and allows searches on the same.

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   my $obj = SonusQA::CDA->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH|SFTP|FTP>",
                               );

=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base

=head2 AUTHORS

Naresh Kumar Anthoti <nanthoti@sonusnet.com>, alternatively contact <sonus-ats-dev@sonusnet.com>.

=head1 DESCRIPTION

   This module provides an interface for CDA.
   subroutines to set the defaults, and to run any command and get the result.

=cut

use strict;
use warnings;
use XML::Simple;

use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
our @ISA = qw(SonusQA::Base);


=head1 doInitialization()

DESCRIPTION: 
    Routine to set object defaults.
    This subroutine is called by SonusQA::Base.pm

=cut
sub doInitialization {
    my($self)=@_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[#\$%\}\|\>]\s?$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head1 setSystem()

DESCRIPTION: 
    This subroutine sets the system variables and Prompt.
=cut

sub setSystem(){
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my($cmd,$prompt, $prevPrompt, @results, @version_info, $prematch, $match);
    $self->{conn}->print( "su - root" );
    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/Password/i' , -timeout   => $self->{DEFAULTTIMEOUT})) {
          $logger->error(__PACKAGE__ . ".$sub: failed to Login as /'ROOT/' on $self->{TMS_ALIAS_NAME}");
          $logger->debug(__PACKAGE__ . ".$sub errmsg :.".$self->{conn}->errmsg);
          $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
          $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
          return 0;
    } #waiting for the password prompt to come
    $logger->debug(__PACKAGE__ . ".$sub: DEBUG  Executed \'su - root\' Match: [$match] and \n PreMatch: [$prematch]\n\n");

    $self->{conn}->print( "$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD}" ); #After getting the prompt 'password' , entering the Root password

    unless (($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                                         -errmode => "return",
                                                         -timeout => $self->{DEFAULTTIMEOUT})) {
             $logger->debug(__PACKAGE__ . ".$sub: errmsg : " . $self->{conn}->errmsg ." \n LastLine:". $self->{conn}->lastline );
             $logger->error(__PACKAGE__ . ".$sub: failed to enter root password on $self->{TMS_ALIAS_NAME}");
             $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
             $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
             $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
             return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub:  Successfully logged in as ROOT");
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");

    unless($self->{conn}->cmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }

    unless ($self->{conn}->lastline=~/AUTOMATION\>/) { # export PS1="AUTOMATION> "
	unless ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT})) {
	    $logger->error(__PACKAGE__ . ".$sub: Could not get the prompt ($self->{PROMPT} ) after waitfor.");
            $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $self->{conn}->last_prompt);
            $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0 ;
	}
    }
    
    $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
    $logger->info(__PACKAGE__ . ".$sub SET PROMPT TO: " . $self->{conn}->last_prompt);
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [1]");
    return 1;
}
=head2 execCmd()

DESCRIPTION:
    This function enables user to execute any command on the server.

ARGUMENTS:
    1. Command to be executed.
    2. Timeout in seconds (optional).

OUTPUT:
    0 - Error executing the command.
    1 - Command executed Successfully.
    Output of the command executed will be stored in $self->{CMDRESULTS}

EXAMPLE:
    unless ($self->execCmd("/etc/init.d/cassandra status")){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get cassandra service status");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
=cut

sub execCmd {
    my ($self,$cmd, $timeout)=@_;
    my($logger, @cmdResults);
    my $sub = "execCmd";
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: ---> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub Clearing the buffer");
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command
    $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
    $timeout ||= $self->{DEFAULTTIMEOUT};
    unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $timeout, errmode => "return")) {
        $logger->warn(__PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".$sub  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".$sub  $cmd");
        $logger->error(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->warn(__PACKAGE__ . ".$sub  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }
    chomp(@cmdResults);
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    $self->{CMDRESULTS} =  [@cmdResults];
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub[1]");
    return 1;
}

=head2 exitCassandraDB()

DESCRIPTION:
    This function enables user to log out of cassandra DB.

OUTPUT:
    0 - Couldnot log out of Cassandra DB.
    1 - Successfully logged out of Cassandra DB.

EXAMPLE:
	unless ($self->exitCassandraDB()) {
	    $logger->error(__PACKAGE__. ".$sub: Error exiting Cassandra DB");
	}
=cut

sub exitCassandraDB {
    my ($self) = @_;
    my $sub = "exitCassandraDB()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");

    $self->{conn}->prompt($self->{USERPROMPT});
    $logger->error(__PACKAGE__. ".$sub: Prompt set to ".$self->{conn}->prompt);
    $logger->info(__PACKAGE__. ".$sub: Exiting from Cassandra DB");
    unless ($self->execCmd("exit")) {
	$logger->error(__PACKAGE__. ".$sub: Error exiting Cassandra DB");
	$logger->error(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__. ".$sub: Successfully exited cassandra DB");
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

=head2 enterCassandraDB()

DESCRIPTION:
    This function enables user to connect to cassandra DB.

ARGUMENTS:
    1. keyspace to be used.

OUTPUT:
    0 - Connection to Cassandra DB failed.
    1 - Connected to Cassandra DB.

EXAMPLE:
    unless ($self->enterCassandraDB("sonus")){
        $logger->error(__PACKAGE__ . ".$sub: Failed to connect to cassandra DB");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
=cut

sub enterCassandraDB {
    my ($self, $keyspace) = @_;
    my $sub = "enterCassandraDB()";
    my ($logger, @cmdResults);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub ");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered Sub");

    unless ($keyspace) {
	$logger->error(__PACKAGE__. ".$sub: Mandatory keyspace empty or undefined");
	$logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
	return 0;
    }

    #TOOLS-6387 : Getting USERID & PASSWD from TMS
    my $username = $self->{TMS_ALIAS_DATA}->{CASSANDRA}->{1}->{USERID};
    my $password = $self->{TMS_ALIAS_DATA}->{CASSANDRA}->{1}->{PASSWD};
    my $ip = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP};

    unless ($ip and $username and $password) {
	$logger->error(__PACKAGE__. ".$sub: Error getting ip $ip, username $username or password $password");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
        return 0;
    }

    my $conectDBcmd = "cqlsh $ip -u $username -p $password";

    #using print because prompt is different
    $self->{conn}->print($conectDBcmd);
    unless (my($prematch, $match) =
                        $self->{conn}->waitfor(
                                        -match   => '/\@cqlsh>/',
                                        -errmode => "return",
                        )
        )
    {
        $logger->error(__PACKAGE__. ".$sub: Did not connect to Cassandra DB");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__. ".$sub: connected to Cassandra DB");


    $self->{USERPROMPT} = $self->{conn}->prompt;
    $self->{conn}->prompt('/.+\@cqlsh:.*\> /');
    $logger->debug(__PACKAGE__. ".$sub: Prompt set to ".$self->{conn}->prompt);

    $logger->debug(__PACKAGE__. ".$sub: Issuing command to set the keyspace");
    my $cmd = "use $keyspace;";
    unless ($self->execCmd($cmd)) {
        $logger->error(__PACKAGE__. ".$sub: Failed issuing Cli: $cmd");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
        return 0;
    }

    $logger->debug(__PACKAGE__. ".$sub: keyspace set to $keyspace");
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving Sub[1]");
    return 1;
}

1;
