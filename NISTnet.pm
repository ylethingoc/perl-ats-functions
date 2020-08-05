package SonusQA::NISTnet;

=pod

=head1 NAME

SonusQA::NISTnet - Perl module for Linux NISTnet interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   my $dsi = SonusQA::NISTnet->new(-OBJ_HOST => '<host name | IP Adress>',
                                   -OBJ_USER => '<cli user name>',
                                   -OBJ_PASSWORD => '<cli user password>',
                                  -OBJ_COMMTYPE => "<TELNET|SSH>",
                                );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::UnixBase, SonusQA::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   This module provides an interface for Linux NISTnet interaction.

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES


=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;

use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
  my($temp_file);
  $self->{COMMTYPES} = ["TELNET", "SSH"];
  $self->{TYPE} = "NISTnet";
  $self->{conn} = undef;
  $self->{PROMPT} = '/.*[\$%#].*$/';
  #$self->{PROMPT} = '/.*[#\$%]/';
  $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
  $self->{cnistnet} = "/usr/local/bin/cnistnet";
  # Note: For SuSE Linux, the following line had to be changed
  # Orginal Line: test -x /usr/bin/tset && /usr/bin/tset -I -Q 
  # New Line    : test -x /usr/bin/tset && /usr/bin/tset -I -Q -m network:vt100
  # SuSE Linux and possibly others do not like 'network';
}

sub setSystem(){
  my($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
  $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
  my($cmd,$prompt, $prevPrompt, @results);
  $cmd = 'PS1="AUTOMATION#"';
  $self->{conn}->last_prompt("");
  $prevPrompt = $self->{conn}->prompt('/AUTOMATION#$/');
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
  @results = $self->{conn}->cmd($cmd);
  $self->{conn}->cmd("");
  $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);
  $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
  return 1;
}


sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
  #cmdResults = $self->{conn}->cmd($cmd);
  #return @cmdResults;
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd)) {
    # Section for commnad execution error handling - CLI hangs, etc can be noted here.
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd DSI CLI CMD ERROR - EXITING");
  };
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  return @cmdResults;
}
=head3 $obj->listSessions();

Object method to retrieve an array of the NISTnet box entries.

Return:  ARRAY_REF

Example: 

my @sessions = $obj->listSessions();

BASE COMMAND:	 cnistnet -n -R

=cut
# ROUTINE: listSessions
# Purpose: OBJECT CLI API COMMAND, GENERIC FUNCTION FOR POSITIVE/NEGATIVE TESTING

sub listSessions() {
  my($self)=@_;
  my($cmd,@cmdResults,$logger);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".listSessions");
  $cmd = $self->{cnistnet} . " -n -R";
  @cmdResults = $self->execCmd($cmd);
  $logger->debug(__PACKAGE__ . ".listSessions  CMD RESULTS:");
  foreach(@cmdResults) {
    $logger->debug(__PACKAGE__ . ".listSessions  $_");    
  }
  return @cmdResults;
}

=head3 $obj->turnOn();

Object method to turn NISTnet controller on.  This is a straight command execution,
due to NISTnet interface it is difficult to determine success or failure.

Return:  Boolean

Example: 

if($obj->turnOn()){
  <code>
}

BASE COMMAND:	 cnistnet -u

=cut

sub turnOn() {
  my($self)=@_;
  my(@cmdResults,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".turnOn");
  $flag = 1;
  $logger->info(__PACKAGE__ . ".turnOn  TURNING NISTNET ON");
  $cmd = sprintf("%s -u", $self->{cnistnet});
  $logger->info(__PACKAGE__ . ".turnOn  CMD: $cmd");
  @cmdResults = $self->execCmd($cmd);
  return $flag;
}

=head3 $obj->turnOff();

Object method to turn NISTnet controller off.  This is a straight command execution,
due to NISTnet interface it is difficult to determine success or failure.

Return:  Boolean

Example: 

$obj->turnOff();

 - or -

if($obj->turnOff()){
  <code>
}

BASE COMMAND:	 cnistnet -d

=cut

sub turnOff() {
  my($self)=@_;
  my(@cmdResults,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".turnOff");
  $flag = 1;
  $logger->info(__PACKAGE__ . ".turnOff  TURNING NISTNET OFF");
  $cmd = sprintf("%s -d", $self->{cnistnet});
  $logger->info(__PACKAGE__ . ".turnOff  CMD: $cmd");
  @cmdResults = $self->execCmd($cmd);
  return $flag;
}

=head3 $obj->entryExist(IPADDRESS,IPADDRESS);

Object method to verify if a NISTnet entry exists.  This is a straight command execution,
due to NISTnet interface it is difficult to determine success or failure.

Return:  Boolean

Example: 

if($obj->entryExist('192.168.20.105','192.168.20.104')){
  <code>
}

BASE COMMAND:	 cnistnet -u

=cut

sub entryExist() {
  my($self,$ip1,$ip2)=@_;
  my(@cmdResults,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".entryExist");
  $flag = 0;
  if($ip1 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".entryExist  INVALID IP ADDRESS PASSED: $ip1");
    return $flag;
  }
  if($ip2 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".entryExist  INVALID IP ADDRESS PASSED: $ip2");
    return $flag;
  }
  $logger->debug(__PACKAGE__ . ".entryExist  RETRIEVING SESSIONS");
  @cmdResults = $self->listSessions();
  $logger->debug(__PACKAGE__ . ".entryExist  CHECKING FOR ENTRY:");
  foreach(@cmdResults) {
    if(m/.*$ip1.*$ip2/){
      $flag=1;
    }
  }
  return $flag;
}

=head3 $obj->addEntry(IPADDRESS,IPADDRESS,{ANNON ATTRIBUTE HASH});

Object method to add a NISTnet entry.  This command accepts:

  REQ: IPADDRESS(1) - A valid IP Address
  REQ: IPADDRESS(2) - A valid IP Address
  OPT: HASH - An annonymous hash of key value pairs of which are attributes for the entry
  
  Possible HASH Keys: delay, drop, dup, bandwith, drd  (Case in-sensitive)
  * See NISTnet documentation for indepth information regarding attribute keys (switches) and values
  
Return:  Boolean

Example: 

if($obj->addEntry('192.168.20.105','192.168.20.104',{"delay" => "10",
                                                     "drop" => "0.1",
                                                     <...>,}) )
  <success code>
}else{
  <error code>
}

BASE COMMAND:	 cnistnet -a 192.168.20.105 192.168.20.104 --delay 10 --drop 0.1 <...>

=cut

sub addEntry() {
  my($self,$ip1,$ip2,$attrib)=@_;
  my(@cmdResults,@validAttributeKeys,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".addEntry");
  @validAttributeKeys = ("delay","drop","dup","bandwith","drd");
  $flag = 0;
  if($ip1 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".addEntry  INVALID IP ADDRESS PASSED: $ip1");
    return $flag;
  }
  if($ip2 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".addEntry  INVALID IP ADDRESS PASSED: $ip2");
    return $flag;
  }
  $cmd = sprintf("%s -a %s %s", $self->{cnistnet},$ip1,$ip2);
  if(keys %{$attrib}){
    while( my ($k, $v) = each %{$attrib} ) {
      $k =~ tr/[A-Z]/[a-z]/;
      if ( grep { $_ eq $k } @validAttributeKeys ) {
         $cmd .= " --$k $v";
      } 
    }
  }
  $logger->info(__PACKAGE__ . ".addEntry  CMD: $cmd");
  $logger->info(__PACKAGE__ . ".addEntry  ATTEMPTING TO ADD ENTRY");
  @cmdResults = $self->execCmd($cmd);
  @cmdResults = $self->listSessions();
  for(my $x=0;$x<2;$x++){sleep(1);}
  if($self->entryExist($ip1,$ip2)){
    $logger->info(__PACKAGE__ . ".addEntry  ENTRY ADDED");
    $flag = 1;
  }else{
    $logger->warn(__PACKAGE__ . ".addEntry  ENTRY ADDITION FAILED");
  }
  return $flag;
}

=head3 $obj->removeEntry(IPADDRESS,IPADDRESS);

Object method to remove a NISTnet entry.  This command accepts:

  REQ: IPADDRESS(1) - A valid IP Address
  REQ: IPADDRESS(2) - A valid IP Address
    
Return:  Boolean

Example: 

if($obj->removeEntry('192.168.20.105','192.168.20.104') )
  <success code>
}else{
  <error code>
}

BASE COMMAND:	 cnistnet -r 192.168.20.105 192.168.20.104

=cut


sub removeEntry() {
  my($self,$ip1,$ip2)=@_;
  my(@cmdResults,@validAttributeKeys,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".removeEntry");
  $flag = 0;
  if($ip1 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".removeEntry  INVALID IP ADDRESS PASSED: $ip1");
    return $flag;
  }
  if($ip2 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".removeEntry  INVALID IP ADDRESS PASSED: $ip2");
    return $flag;
  }
  $cmd = sprintf("%s -r %s %s", $self->{cnistnet},$ip1,$ip2);
  $logger->info(__PACKAGE__ . ".removeEntry  CMD: $cmd");
  $logger->info(__PACKAGE__ . ".removeEntry  ATTEMPTING TO REMOVE ENTRY");
  @cmdResults = $self->execCmd($cmd);
  @cmdResults = $self->listSessions();
  for(my $x=0;$x<2;$x++){sleep(1);}
  if($self->entryExist($ip1,$ip2)){
    $logger->warn(__PACKAGE__ . ".removeEntry  ENTRY REMOVAL FAILED");
  }else{
    $logger->info(__PACKAGE__ . ".removeEntry  ENTRY REMOVED");
    $flag = 1;
  }
  return $flag;
}

=head3 $obj->removeAllEntries();

Object method to remove a NISTnet entries.  This command will execute listSessions, and proceed to remove all sessions
returned from that command.
    
Return:  Boolean

Example: 

if($obj->removeAllEntries() )
  <success code>
}else{
  <error code>
}

BASE COMMAND:	 See removeEntry
                
=cut
sub removeAllEntries() {
  my($self)=@_;
  my(@cmdResults,@sessions,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".removeAllEntries");
  $flag = 0;
  $logger->info(__PACKAGE__ . ".removeAllEntries  RETRIEVING ALL ENTRIES");
  @sessions = $self->listSessions();
  if($#sessions > 0){
    foreach(@sessions){
      if($_ =~ m/^cnistnet\s\-a/){
        $cmd = $_;
        $cmd =~ s/cnistnet\s\-a//;
        $cmd =~ s/^ *//;
        my @ips = split(" ",$cmd);
        $self->removeEntry($ips[0],$ips[1]);
      }
    }
  }
  for(my $x=0;$x<2;$x++){sleep(1);}
  @sessions = $self->listSessions();
  if($#sessions > 0){
    $logger->warn(__PACKAGE__ . ".removeAllEntries  UNABLE TO REMOVE ALL ENTRIES:");
  }else{
    $logger->info(__PACKAGE__ . ".removeAllEntries  REMOVED ALL ENTRIES");
  }
  return $flag;
}

=head3 $obj->retrieveStats(IPADDRESS,IPADDRESS);

Object method to retrieve statistics of a NISTnet entry.  This command accepts:

  REQ: IPADDRESS(1) - A valid IP Address
  REQ: IPADDRESS(2) - A valid IP Address
   
Return:  ARRAY_REF

Example: 

my @stats = $obj->retrieveStats('192.168.20.105','192.168.20.104');

BASE COMMAND:	 cnistnet -s 192.168.20.105 192.168.20.104
                
=cut
sub retrieveStats() {
  my($self,$ip1,$ip2)=@_;
  my(@cmdResults,
     $cmd,$logger,$flag);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".retrieveStats");
  @cmdResults = ();
  if($ip1 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".retrieveStats  INVALID IP ADDRESS PASSED: $ip1");
    return $flag;
  }
  if($ip2 !~ m/\b(?:\d{1,3}\.){3}\d{1,3}\b/){
    $logger->warn(__PACKAGE__ . ".retrieveStats  INVALID IP ADDRESS PASSED: $ip2");
    return $flag;
  }
  if($self->entryExist($ip1,$ip2)){
    for(my $x=0;$x<3;$x++){sleep(1);}
    $cmd = sprintf("%s -s %s %s", $self->{cnistnet},$ip1,$ip2);
    $logger->info(__PACKAGE__ . ".retrieveStats  CMD: $cmd");
    $logger->info(__PACKAGE__ . ".retrieveStats  ATTEMPTING TO RETRIEVE STATS");
    @cmdResults = $self->execCmd($cmd);
    @cmdResults = $self->execCmd($cmd);
  }else{
    $logger->warn(__PACKAGE__ . ".retrieveStats  UNABLE TO RETRIEVE STATS (INVALID ENTRY)");
  }
  return @cmdResults;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
  if(Log::Log4perl::initialized()){
    my $logger = Log::Log4perl->get_logger($AUTOLOAD);
    $logger->warn($warn);
  }else{
    Log::Log4perl->easy_init($DEBUG);
    WARN($warn);
  }
}


1;
