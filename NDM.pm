package SonusQA::NDM;

=head1 NAME

 SonusQA::NDM - Perl module for NDM

=head1 AUTHOR

 Vishwas Gururaja - vgururaja@rbbn.com

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::NDM->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
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
    $self->{PROMPT} = '/.*[\$%#\>].*$/';
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
    my ($self, %args) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    $self->{conn}->cmd("sh");
    unless($self->enterRootForNDM()){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter root session");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }
    if($args{-connect_to_core}){
        $logger->debug(__PACKAGE__ . ".$sub_name: connect_to_core parameter is present. Connecting to CORE");
        unless($self->coreLogin(%{$args{-connect_to_core}})){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not connect to core");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0 ;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<enterRootForNDM()>

=over 6

=item DESCRIPTION:

 This subroutine will enter the linux root session via Su command.
 This subroutine also enters root session via sudo su command


=item ARGUMENTS:

 This function is called from setSystem()

=item PACKAGE:

 SonusQA::NDM

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

 unless ( $Obj->enterRootForNDM( )) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }

=back

=cut

sub enterRootForNDM{
    my ($self) = @_;
    my $sub = "enterRootForNDM";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: Entered sub -->" );

    my $cmd1 = "id";
    my @cmdresults;
    unless(@cmdresults = $self->execCmd($cmd1)){
        $logger->error( __PACKAGE__ . ".$sub: failed to execute the command : $cmd1" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    if(grep( /root/, @cmdresults)){
        $logger->debug( __PACKAGE__ . ".$sub: You are already logged in as root" ) ;
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
        return 1;
    }

    my $cmd2 = "su -";
    $logger->debug( __PACKAGE__ . ".$sub: Issuing the Cli: $cmd2" );
    unless($self->{conn}->print($cmd2)){
        $logger->error( __PACKAGE__ . ".$sub: failed to execute the command : $cmd2");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    my ( $prematch, $match );
    unless (($prematch, $match ) = $self->{conn}->waitfor(
                                         -match   => '/Password.*\:/i', 
                                         -match => $self->{DEFAULTPROMPT},
                                         -errmode => "return",
                                         -timeout => $self->{DEFAULTTIMEOUT})){
        $logger->error( __PACKAGE__ . ".$sub: Root Login Failed" );
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    if($match =~ /Password.*\:/i ){
        unless($self->{conn}->print($self->{ROOTPASSWD})){
            $logger->error( __PACKAGE__ . ".$sub: Failed to print root password");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        unless(($prematch, $match) = $self->{conn}->waitfor( 
                                        -match => '/incorrect|try again|sorry/i',
                                        -match => $self->{conn}->prompt, 
                                        -errmode => "return",
                                        -timeout => $self->{DEFAULTTIMEOUT})){
            $logger->error( __PACKAGE__ . ".$sub: Failed to match any of the patterns. Prematch: $prematch, Match: $match");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        if($match =~ /incorrect|try again|sorry/i){
            $logger->error( __PACKAGE__ . ".$sub: Failed to login to Root");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	    $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }            
    }
    unless($match =~ /root/i){
        unless($self->execCmd('fsh')){
            $logger->error( __PACKAGE__ . ".$sub: Failed to execute the command : 'pwd'");
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->{conn}->print('sudo su root')){
            $logger->error( __PACKAGE__ . ".$sub: Failed to sudo to root" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
            return 0;
        }
        unless (($prematch, $match ) = $self->{conn}->waitfor(
                                         -match   => '/Password.*\:/i',
                                         -match => $self->{DEFAULTPROMPT},
                                         -errmode => "return",
                                         -timeout => $self->{DEFAULTTIMEOUT})){
            $logger->error( __PACKAGE__ . ".$sub: sudo su root Login Failed" );
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
            return 0;
        }
        if($match =~ /Password.*\:/i ){
            unless($self->{conn}->print($self->{ROOTPASSWD})){
                $logger->error( __PACKAGE__ . ".$sub: Failed to enter root password");
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
            unless(($prematch, $match) = $self->{conn}->waitfor(
                                        -match => '/sorry/i',
                                        -match => $self->{conn}->prompt,
                                        -errmode => "return",
                                        -timeout => $self->{DEFAULTTIMEOUT})){
                $logger->error( __PACKAGE__ . ".$sub: Failed to match any of the patterns. Prematch: $prematch, Match: $match");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            if($match =~ /sorry/i){
                $logger->error( __PACKAGE__ . ".$sub: Failed to login to Root");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }         
    }    
    unless(@cmdresults = $self->execCmd($cmd1)){
        $logger->error( __PACKAGE__ . ".$sub: Failed to execute the command : $cmd1" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    if(grep( /root/, @cmdresults)){
        $logger->debug( __PACKAGE__ . ".$sub: Successfully logged in as root" ) ;
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
        return 1;
    }
    $logger->error( __PACKAGE__ . ".$sub: login to root session failed!" );
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
    return 0;
}

=head2 B<coreLogin()>

=over 6

=item DESCRIPTION:

 This function is used to telnet to the CORE from NDM

=item ARGUMENTS:

 This function is called from setSystem()

=item PACKAGE:

 SonusQA::NDM

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

 unless ( $Obj->coreLogin(%args)) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }

=back

=cut

sub coreLogin {
    my ($self, %args) = @_;
    my $sub = "coreLogin";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered sub" );
    unless($self->{conn}->print('telnet cm')){
        $logger->error( __PACKAGE__ . ".$sub: failed to telnet to core");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    my ( $prematch, $match );
    unless (($prematch, $match) = $self->{conn}->waitfor(
                                         -match   => '/Enter username and password/i',
                                         -match => $self->{DEFAULTPROMPT},
                                         -errmode => "return",
                                         -timeout => $self->{DEFAULTTIMEOUT})){
        $logger->error( __PACKAGE__ . ".$sub: Failed to match any of the strings or prompt. Prematch: $prematch, Match: $match");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    my $user;
    my $flag = 0;
    $self->{USER_AND_PASSWD} = 1 if($match =~ /Enter username and password/i);
    foreach $user(keys %args){
        $self->{conn}->waitfor(-match => $self->{conn}->prompt);
        $logger->debug(__PACKAGE__ . ".$sub: Trying with $user and $args{$user}");
        if($self->{USER_AND_PASSWD}){
            unless($self->{conn}->print("$user $args{$user}")){
                $logger->error( __PACKAGE__ . ".$sub: Failed to enter username: $user and password: $args{$user}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }else{
            unless($self->{conn}->print("$user")){
                $logger->error( __PACKAGE__ . ".$sub: Failed to enter username: $user");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            unless(($prematch, $match) = $self->{conn}->waitfor(
                                        -match => $self->{conn}->prompt,
                                        -errmode => "return",
                                        -timeout => $self->{DEFAULTTIMEOUT})){
                $logger->error( __PACKAGE__ . ".$sub: Failed to match the prompt. Prematch: $prematch, Match: $match");
                $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            unless($self->{conn}->print("$args{$user}")){
                $logger->error( __PACKAGE__ . ".$sub: Failed to enter password: $args{$user}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }
        unless(($prematch, $match) = $self->{conn}->waitfor(
                                        -match => '/Invalid.+/i',
                                        -match => '/User logged in on another device|close|command not found/i',
                                        -match => $self->{DEFAULTPROMPT},
                                        -errmode => "return",
                                        -timeout => $self->{DEFAULTTIMEOUT})){
            $logger->error( __PACKAGE__ . ".$sub: Failed to match any of the patterns. Prematch: $prematch, Match: $match");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        if($match =~ /Invalid.+/i){
            $logger->debug(__PACKAGE__ . ".$sub: Failed to telnet with username: $user and password: $args{$user}. Invalid username or password");
            delete $args{$user};
            next;
        }elsif($match =~ /User logged in on another device|close|command not found/i){
            $logger->error( __PACKAGE__ . ".$sub: Telnet to core failed. Need to telnet again");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $self->{conn}->waitfor(-match => $self->{conn}->prompt);
            delete $args{$user};                            # deleting the hash element as it must not be used again
            $self->coreLogin(%args);                        # Need to perform telnet again as it exits the session
        }else{
            $logger->debug(__PACKAGE__ . ".$sub: Telnet to core successful with username: $user and password: $args{$user}");
            $flag = 1;
            last;
        }
    }
    $self->{conn}->waitfor(-match => $self->{conn}->prompt);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 B<logutilStart()>

=over 6

=item DESCRIPTION:

 This function is used to start the logutil. It also clears all the logutil types passed as argument

=item ARGUMENTS:

 Optional:
         -logutil_type(Default: ('AMAB','SWERR','TRAP'))

=item PACKAGE:

 SonusQA::NDM

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

 my %args = (-logutil_type => ['AMAB','SWERR','TRAP']);
 unless ( $Obj->logutilStart(%args)) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }

=back

=cut

sub logutilStart {
    my ($self, %args) = @_;
    my $sub = "logutilStart";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered sub" );
    my @cmdresults;
    my $flag = 1;
    @{$self->{LOGUTIL_TYPE}} = ($args{-logutil_type}) ? @{$args{-logutil_type}} : ('AMAB','SWERR','TRAP');
    unless($self->execCmd('logutil')){
        $logger->error( __PACKAGE__ . ".$sub: Failed to execute the command : 'logutil'" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    unless(@cmdresults = $self->execCmd('listdevs')){
        $logger->error( __PACKAGE__ . ".$sub: Failed to execute the command : 'logutil'" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    foreach my $line (@cmdresults){
        if($line =~ /\d+\s+(.+)\s+Inactive.*/i){
            $logger->debug( __PACKAGE__ . ".$sub: Deleting device $1");
            unless($self->execCmd("deldevice $1")){
                $logger->error( __PACKAGE__ . ".$sub: Failed to delete the device $1" );
                $flag = 0;
                last;
            }
        }
    }
    if($flag == 0){
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    foreach(@{$self->{LOGUTIL_TYPE}}){
        unless($self->execCmd("clear $_")){
            $logger->error( __PACKAGE__ . ".$sub: Failed to clear logutil type $_" );
            $flag = 0;
            last;
        }
        if (/VAMP/){
            $logger->debug( __PACKAGE__ . ".$sub: Log util type is VAMP. Enabling vptrace");
            unless($self->execCmd("vptrace enable")){
                $logger->error( __PACKAGE__ . ".$sub: Failed to enable vptrace");
                $flag = 0;
                last;
            }
        }
    }
    if($flag == 0){
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->{conn}->print('start')){
        $logger->error( __PACKAGE__ . ".$sub: failed to start logutil");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }    
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 B<logutilStop()>

=over 6

=item DESCRIPTION:

 This function is used to stop the logutil. It also opens all the logutil file types 

=item ARGUMENTS:

 Optional:
         -logutil_type(Default: ('AMAB','SWERR','TRAP'))

=item PACKAGE:

 SonusQA::NDM

=item OUTPUT:

 1       - Success
 0       - Failure - Either we timed out, or a command failed.

=item EXAMPLE:

 unless ( $Obj->logutilStop()) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }

=back

=cut

sub logutilStop {
    my ($self, %args) = @_;
    my $sub = "logutilStop";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered sub" );
    my $flag = 1;
    unless($self->{conn}->print('stop')){
        $logger->error( __PACKAGE__ . ".$sub: failed to stop logutil");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    unless($self->{conn}->waitfor(-match => '/This device stopped/i')){
        $logger->error( __PACKAGE__ . ".$sub: failed to match 'This device stopped' after issuing cmd 'stop'");
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    $self->{conn}->waitfor(-match => $self->{conn}->prompt);
    my @cmd_result;
    foreach (@{$self->{LOGUTIL_TYPE}}){
        unless(@cmd_result = $self->execCmd("open $_; back all")){
            $logger->error( __PACKAGE__ . ".$sub: Failed to open logutil type $_" );
            $flag = 0;
        }
        unless(grep /Log empty/i, @cmd_result){
            $logger->error( __PACKAGE__ . ".$sub: Failed match 'Log empty' in logutil type $_" );
            $flag = 0;
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [$flag]");
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
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
   $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
   return @cmdResults;
}

sub closeConn{
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
    $self->{conn}->cmd('logout');
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

1;
