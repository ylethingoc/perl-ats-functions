package SonusQA::SGX::SGXUNIX;

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);

use vars qw($self);


sub exampleFunction() {
  my $self = shift;
  my($logger, @cmdResults);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".examplefunction");
  if($self->exitSwmml()){
    # You should be at the Unix prompt now.
    # Perform you unix style commands via regular net::telnet interface $obj->{conn}
    @cmdResults = $self->{conn}->cmd("ls -l");
    map { $logger->warn(__PACKAGE__ . ".examplefunction\t\t$_") } @cmdResults;
  }else{
    $logger->warn(__PACKAGE__ . ".examplefunction UNABLE TO EXIT SWMML CLI INTERFACE");
    return 0;
  }
  return 1;
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
