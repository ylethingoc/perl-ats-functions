
package SonusQA::AMA;

=head1 NAME

 SonusQA::AMA - Perl module for AMA

=head1 AUTHOR

 Vishwas Gururaja - vgururaja@rbbn.com

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::AMA->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate

=head1 DESCRIPTION

 This module provides an interface to run basic calls using a CRS box.

=head1 METHODS

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Module::Locate qw /locate/;

our @ISA = qw(SonusQA::Base);

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
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{STORE_LOGS} = 2;
    $self->{LOCATION} = locate __PACKAGE__ ;
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<setSystem()>

    This function sets the system information and Prompt.

=over 6

=item Arguments:

        Object Reference

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=back

=cut

sub setSystem{
    my ($self) = @_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{conn}->cmd("bash");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
     unless ($self->{conn}->cmd($cmd)){
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

    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<connectCBM()>

    This function takes a hash containing the IP, port, user and password and opens a telnet connection.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        user
        password
 Optional:
        port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-ip => '10.250.14.10', -user => 'root', -password => 'root');
        $obj->connectCBM(%args);

=back

=cut

sub connectToCBM {
    my ($self, %args) = @_;
    my $sub_name = "connectCBM";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-proxy_ip', '-port', '-cbmg_ip', '-user', '-password', '-root_pass'){                                                        #Checking for the parameters in the input hash
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    } 
    my $prev_prompt = $self->{conn}->prompt('/.+\>$/');
    $logger->debug(__PACKAGE__ . ".$sub_name: Changing the prompt to '/.+>\$/'");
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to telnet to $args{-proxy_ip} with port $args{-port}");
    unless($self->execCmd("telnet $args{-proxy_ip} $args{-port}")){                              #telnet to the host
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not telnet to $args{-proxy_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my @cmd_result = $self->execCmd("connect $args{-cbmg_ip} $args{-user} $args{-password} $args{-root_pass}");                                          #connect to cbmg
    unless(grep /$args{-user}/i, @cmd_result){   
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not connect to CBMG $args{-cbmg_ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<setStartTime()>

    This function is used to check the start time.

=over 6

=item Arguments:

 Mandatory:
        Object Reference

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        $obj->setStartTime();

=back

=cut

sub setStartTime {
    my ($self) = @_;
    my $sub_name = "setStartTime";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($self->execCmd("starttime")){                              #connect to cbmg
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute 'starttime'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<updateAdjTime()>

    This function updates or adjusts the bill time.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        -bill_time

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-bill_time => '10000');
        $obj->updateAdjTime(%args);

=back

=cut

sub updateAdjTime {
    my ($self, %args) = @_;
    my $sub_name = "updateAdjTime";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($args{-bill_time}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '-bill_time' not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    unless($self->execCmd("u a $args{-bill_time}")){                              #connect to cbmg
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute 'u a $args{-bill_time}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<executeFilter()>

    This function executes the filter create and append commands.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        %args

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = ('create' => ['006C', 005C'], 'append' =>{'ANSWER' => ['006C', 005C'], 'SERVICE_FEATURE' => ['006C', 005C'], 'ORIGINATING_NUMBER' => ['006C', 005C'], 'TERMINATING_NUMBER' => ['006C', 005C']});;
        $obj->executeFilter(%args);

=back

=cut

sub executeFilter {
    my ($self, %filter) = @_;
    my $sub_name = "executeFilter";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    unless($filter{'create'}){                              #connect to cbmg
        $logger->error(__PACKAGE__ . ".$sub_name: There is no create key in the filter hash");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $self->{FILTER_LENGTH} = scalar @{$filter{'create'}};  # using it in verify records
    for my $i(1..$self->{FILTER_LENGTH}){
        my $val = 'filter create ' . $i . ' ' . $filter{'create'}->[$i-1];
        unless($self->execCmd("$val")){                              #connect to cbmg
            $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$val'");
            $flag = 0;
            last;
        }
        foreach my $cmd (keys %{$filter{'append'}}){
            next unless $cmd;
            my $val = 'filter append '. $i . ' '. $cmd . ' '. $filter{'append'}->{$cmd}->[$i-1];
            unless($self->execCmd("$val")){
                $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$val'");
                $flag = 0;
                last;
            }
        }
        last if($flag == 0);
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;        
}

=head2 B<executeFilter()>

    This function executes the filter list, verify the AMA records and filter delete commands for all the filters.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
 Optional:
        -get_ama

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-get_ama => '1');
        $obj->verifyRecords(%args);

=back

=cut

sub verifyRecords {
    my ($self, %input) = @_;
    my $sub_name = "verifyRecords";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    for my $i (1..$self->{FILTER_LENGTH}){
        $logger->debug(__PACKAGE__ . ".$sub_name: Listing filter $i");
        unless($self->execCmd("filter list $i")){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not list filter $i");
            $flag = 0;
            last;
        }
        my $get_ama = $input{-get_ama} || '1';
        $logger->debug(__PACKAGE__ . ".$sub_name: Getting AMA records for filter $i");
        unless($self->execCmd("getAMA $i $get_ama")){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not get AMA record for filter $i");
            $flag = 0;
            last;
        }
    
        $logger->debug(__PACKAGE__ . ".$sub_name: Deleting filter $i");
        unless($self->execCmd("filter delete $i")){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not delete filter $i");
            $flag = 0;
            last;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Deleted filter $i");    
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag;
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

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
   my(@cmdResults,$timestamp);
   $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub");
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
      $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
      $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
      $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub[0]");
      return 0;
   }
   if(grep /ERR/, @cmdResults){
       $logger->error(__PACKAGE__ . ".execCmd: Error while executing command $cmd");
       $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
       $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub[0]");
       return 0;   
   }

   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
   return @cmdResults;
}

sub closeConn {
    my $self = shift;
    my $sub_name = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ .".$sub_name: -->Entered Sub");
    unless (defined $self->{conn}) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Exiting from telnet");
    $self->{conn}->cmd('quit');
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

1;
