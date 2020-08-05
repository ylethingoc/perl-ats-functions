package SonusQA::DSI::DSIHELPER;

=head1 NAME

 SonusQA::DSI::DSIHELPER - Perl module for Sonus Networks DSI (UNIX) interaction

=head1 REQUIRES

 Perl 5.8.6, Log::Log4perl, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

 This is a place to implement frequent activity functionality, standard non-breaking routines.
 Items placed in this library are inherited by all versions of DSI - they must be generic.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);

our $VERSION = "6.1";

use vars qw($self);

# Documentation format (Less comment markers '#'):

#=head3 $obj-><FUNCTION>({'<key>' => '<value>', ...});
#Example: 
#
#$obj-><FUNCTION>({...});
#
#Mandatory Key Value Pairs:
#        'KEY' => '<TYPE>'
#
#Optional Key Value Pairs:
#       none
#=cut
## ROUTINE:<FUNCTION>


# ******************* INSERT BELOW THIS LINE:


# ******************* INSERT ABOVE THIS LINE:

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
