package SonusQA::IMX::IMXSCP;

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);

our $VERSION = "1.0";
use vars qw($VERSION $self);


sub putFile() {
  my($self, $file, $destinationPath)=@_;
  my($cmd, $logger, $prematch, $match);
  # Format of scp command:   scp -q <file> <user>@<host>:<path>
  # -q disables the 'progress meter - this is required - do not remove
  $cmd = "scp -q %s %s@%s:%s;echo 'DONE';";
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".putFile");
  if(defined($destinationPath)){
    $logger->warn(__PACKAGE__ . ".putFile DESTINATION PATH REQUIRED");
    return 0;
  }
  if(!defined($file) || !-e $file){
    $logger->warn(__PACKAGE__ . ".putFile UNABLE TO VERIFY FILE EXISTANCE");
    return 0;
  }
  # File exists, we can try to send it to the remote host....
  $logger->info(__PACKAGE__ . ".putFile  SCP FILE COPY [PUT]");
  $cmd = sprintf($cmd,$file,$self->{OBJ_USER},$self->{OBJ_HOST},$destinationPath);
  $self->{conn}->print($cmd);
  ($prematch, $match) = $self->{conn}->waitfor(-match => '/[P|p]assword: ?$/i',
					       -match => '/yes\/no/i',
                                               -match =>  'DONE',
					       -errmode => "return") or do {
    $logger->warn(__PACKAGE__ . ".putFile  SCP COMMAND EXECUTED, NEVER RECEIVED BACK MATCH");
    $logger->debug(__PACKAGE__ . ".putFile  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".putFile  Session Input Log is: $self->{sessionLog2}");
    return 0;
    };
  if($match =~ m/yes\/no/i){
      $logger->info(__PACKAGE__ . ".connect  RSA ENCOUNTERED - ENTERING YES");
      $self->{conn}->print("yes");
      ($prematch, $match) = $self->{conn}->waitfor(-match => '/[P|p]assword: ?$/i',
                                                   -errmode => "return") or do {
        $logger->warn(__PACKAGE__ . ".putFile EXPECTED PASSWORD PROMPT, RECEIVED: " .  $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".putFile  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".putFile  Session Input Log is: $self->{sessionLog2}");
        return 0;
      };
  }
  if($match =~ m/[P|p]assword: ?$/i){
      $self->{conn}->print($self->{OBJ_PASSWORD});
      ($prematch, $match) = $self->{conn}->waitfor(-match => $self->{PROMPT},
                                                   -match =>  'DONE',
                                                   -errmode => "return") or do {
        $logger->warn(__PACKAGE__ . ".putFile  PASSWORD PROMPT FAILURE - UNABLE TO PROCEED - ATTEMPTING TO RETURN TO PROMPT");
        for(my $i=0;$i <= 5; $i++){
          $self->{conn}->cmd(" ");  # Hammer out a few carriage returns - to attempt to get back to a sane prompt...
        }
        $logger->debug(__PACKAGE__ . ".putFile  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".putFile  Session Input Log is: $self->{sessionLog2}");
        return 0;
      };
  }
  $logger->info(__PACKAGE__ . ".putFile  FILE TRANSFER COMPLETED");
  return 1;
  
}

sub getFile(){
  
  
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

1; # Do not remove
