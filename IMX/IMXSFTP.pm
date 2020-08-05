package SonusQA::IMX::IMXSFTP;

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use SonusQA::Base;
use SonusQA::UnixBase;

our $VERSION = "1.0";

# Inherit the two base ATS Perl modules SonusQA::Base and SonusQA::UnixBase
# Methods new(), doInitialization() and setSystem() are defined in the inherited
# modules and the latter two are superseded by the co-named functions in this module.
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

use vars qw($VERSION $self);


sub putFile() {
  my ($self, $file, $destinationPath) = @_;
  my ($cmd, $logger, $prematch, $match);
  # Format of scp command:   scp -q <file> <user>@<host>:<path>
  # -q disables the 'progress meter - this is required - do not remove
  $cmd = "scp -q %s %s@%s:%s";
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
                                               -match => $self->{PROMPT},
                                               -match => '/Last\s+Login/i',
					       -errmode => "return") or &error(__PACKAGE__ . ".connect connecting to host: ", $self->{conn}->lastline);
  if($match =~ m/yes\/no/i){
      $logger->info(__PACKAGE__ . ".connect  RSA ENCOUNTERED - ENTERING YES");
      $self->{conn}->print("yes");
      $self->{conn}->waitfor(-match => '/[P|p]assword: ?$/i',
                       -errmode => "return") or &error(__PACKAGE__ . ".connect connecting to host: ", $self->{conn}->lastline);
  }
  if($match =~ m/[P|p]assword: ?$/i){
      $self->{conn}->print($self->{OBJ_PASSWORD});
      $self->{conn}->waitfor(-match => $self->{PROMPT}, -errmode => "return");
  }
  
  
  
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
