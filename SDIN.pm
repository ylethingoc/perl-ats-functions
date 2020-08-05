package SonusQA::SDIN;

=head1 NAME

    SonusQA::SDIN - Perl module for SDIN

=head1 AUTHOR
=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::SDIN->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

    Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate

=head1 DESCRIPTION

    This module provides an interface to telnet to MSC and PAC cards and execute basic commands on them.

=head1 METHODS

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;
use Data::Dumper;

our $VERSION = "1.0";
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
    $self->{'LOG_PATH'} = '/space/Santera';
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
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    $self->execCmd("bash");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub_name  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    unless ($self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<editXmlFileForUAC()>

    This function change the value in xml file and transfer it to the remote server.

=over 6

=item Arguments:

    Mandatory:
        XMLfile: The file name and pattern to be replaced with new value.
        xmlFilePath: path to xml file
        remotePath: path to folder which contains SIPp file
        remoteIP: IP of remote server
        remoteUser: Username to connect to remote server
        remotePass: Password to connect to remote server


=item Returns:

        Returns 1 - If succeed
        Reutrns 0 - If failed

=item Example:

    my %XMLfile = ('priority_uac_reinvite.xml' => { 'Resource-Priority' => 'ets.3'
											}
                );

    SonusQA::SDIN::editXmlFileForUAC(-XMLfile => \%XMLfile,
                                    -xmlFilePath => './sipp/',
                                    -remotePath => '/usr/local/sipp/',
                                    -remoteIP => '10.250.14.10',
                                    -remoteUser => 'root',
                                    -remotePass => 'root1!23'
                                    )

=back

=cut

sub editXmlFileForUAC {
    my (%args) = @_;
    my $sub_name = "editXmlFileForUAC";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-XMLfile', '-xmlFilePath', '-remotePath', '-remoteIP', '-remoteUser', '-remotePass') {
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my %XMLfile = %{$args{-XMLfile}};
    my $in_file;
    my $out_file;
    foreach my $xml (keys %XMLfile) {
		my $line;
		unless(rename($args{-xmlFilePath}.$xml, $args{-xmlFilePath}.$xml.'.bak')) {
            $logger->error(__PACKAGE__ . " $sub_name: Could not backup xml file");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        $in_file = $args{-xmlFilePath}.$xml.'.bak';
        $out_file = $args{-xmlFilePath}.$xml;
        open (IN, "<$in_file") or $logger->debug(__PACKAGE__ . ".$sub_name: Can't open $in_file: $!\n");
        $logger->debug(__PACKAGE__ . ".$sub_name: Open $xml file \n");
        open (OUT, ">$out_file") or $logger->debug(__PACKAGE__ . ".$sub_name: Can't open $out_file: $!\n");
        $logger->debug(__PACKAGE__ . ".$sub_name: Create new $xml file \n");
        while ( $line = <IN> ) {
            foreach my $pattern (keys %{$XMLfile{$xml}}) {
                my $value = $XMLfile{$xml}{$pattern};
                if ($line =~ /$pattern\:/) {
                    $line =~ s/$pattern\:\s.*/$pattern\: $value/;
                }
            }
            print OUT $line;
        }
        close IN;
        close OUT;
    }

    unless(&SonusQA::Utils::copyDirToRemoteMc("$args{-remoteIP}", "$args{-remoteUser}", "$args{-remotePass}", "$args{-remotePath}", "$args{-xmlFilePath}")) {
        $logger->error(__PACKAGE__ . " $sub_name: Could not transfer file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 B<verifyDumpTime()>

    This function verify the pattern and the time.

=over 6

=item Arguments:

    Mandatory:
        start_boundary: the first sight to begin analyze.
        verifyMess: messages need to paralyze
        ext: expected time
    Optional:
        verifyNoMess: messages that should not exist


=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
    
    my %input = (-start_boundary => ["Application", "Manager Id : 20"],
                -verifyMess => ["Dialed Number             : 511385222810116", "SIP Resource Priority Tags: esnet\.2|esnet\.1"],
                -exT => '15'
                );

    my %input = (-start_boundary => ["Application", "Manager Id : 20"],
                -verifyMess => ["Dialed Number             : 511385222810116"],
                -verifyNoMess => ["SIP Resource Priority Tags: esnet.1"],
                -exT => '15'
                );

    verifyDumpTime(%input);

=back

=cut

sub verifyDumpTime {
    my ($self, %input) = @_;
    ################### Variables ###################
    my (@ses_msc2_date, @DumpVoiceCdr, $header, %count, %content);
    my ($hour_d, $minute_d, $second_d);
    my ($dayOfWeek_c, $month_c, $dayOfMonth_c, $hour_c, $minute_c, $second_c, $year_c);
    #################################################
    my $sub_name = "verifyDumpTime";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $flag = 1;
    foreach('-start_boundary', '-verifyMess', '-exT') {
        unless($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    unless($self->execCmd("cd /billing/voice/cdr/")) {
        $logger->error(__PACKAGE__ . "Could not cd /billing/voice/cdr/");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    ################### Get current system time ###################
    unless(@ses_msc2_date = $self->execCmd("date \"\+\%a \%b \%_d \%R:\%S \%Y\"")) {
        $logger->error(__PACKAGE__ . " $sub_name: Could not execute date" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    ################### Get message's content ###################
    unless(@DumpVoiceCdr = $self->execCmd("DumpVoiceCdr \$(ls \| tail -1) | tail -2800")) {
        $logger->error(__PACKAGE__ . " $sub_name: Could not DumpVoiceCdr the latest CDR file" );
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    ################### Split the record ###################
    push (@DumpVoiceCdr, '----------------------------------- END OF RECORD -----------------------------------');
    my $end_boundary = '-----------------------------------';
    foreach my $line (@DumpVoiceCdr) {
        chomp $line;
        if(!$header && $line =~ /${$input{-start_boundary}}[1]/i && $line =~ /(${$input{-start_boundary}}[0])/) {
            $header = $1;
            $count{$header}++;
        }
        $header ='' if($line =~ /$end_boundary/);
        next unless $header;
        push (@{$content{$header}{$count{$header}}}, $line);
    }
    ################### Verify the messages ###################
    foreach my $i (sort keys %{$content{"${$input{-start_boundary}}[0]"}}) {
        foreach(@{$content{"${$input{-start_boundary}}[0]"}{$i}}) {
            if (defined $input{-verifyNoMess}) {
                foreach my $mess (@{$input{-verifyNoMess}}) {
                    if(grep /$mess/, @{$content{"${$input{-start_boundary}}[0]"}{$i}}) {
                        delete($content{"${$input{-start_boundary}}[0]"}{$i});
                    }
                }
            }
            foreach my $mess (@{$input{-verifyMess}}) {
                unless(grep /$mess/, @{$content{"${$input{-start_boundary}}[0]"}{$i}}) {
                    delete($content{"${$input{-start_boundary}}[0]"}{$i});
                }
            }
        }
    }

    ################### Analyze Time ###################
    if("@ses_msc2_date" =~ /^(\w{3})\s+(\w{3})\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d{4})$/) {
        $dayOfWeek_c = $1;
        $month_c = $2;
        $dayOfMonth_c = $3;
        $hour_c = $4;
        $minute_c = $5;
        $second_c = $6;
        $year_c = $7;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to analyze system time");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    my @timePool;
    foreach my $i (sort {$a <=> $b} %{$content{"${$input{-start_boundary}}[0]"}}) {
        foreach(@{$content{"${$input{-start_boundary}}[0]"}{$i}}) {
            if ($_ =~ /Origination\s+Time\s+:\s(.*)\s$year_c.*\)$/) {
                push(@timePool, $1);
            }
        }
    }

    if (!@timePool) {
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't found your expected record");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ($timePool[-1] =~ /^$dayOfWeek_c\s$month_c\s+$dayOfMonth_c\s(\d{2}):(\d{2}):(\d{2})/) {
        $hour_d = $1;
        $minute_d = $2;
        $second_d = $3;
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't get the time from Dump!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    my $total_sc = $hour_c * 3600 + $minute_c * 60 + $second_c;
    my $total_sd = $hour_d * 3600 + $minute_d * 60 + $second_d;
    unless(abs($total_sc - $total_sd) <= $input{-exT}) {
        $logger->error(__PACKAGE__ . "The period of time is not as your expectation!");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
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
   unless (@cmdResults = $self->execCmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->debug(__PACKAGE__ . ".execCmd errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
      $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
      $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
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
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->debug(__PACKAGE__ .".$sub_name: -->Entered Sub");
    unless (defined $self->{conn}) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    $self->copyLogToATS();
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

1;












