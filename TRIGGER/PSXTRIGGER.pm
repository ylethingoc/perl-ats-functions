package SonusQA::TRIGGER::PSXTRIGGER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::MGTS;
use SonusQA::ATSHELPER;

=head1 NAME

SonusQA::TRIGGER::PSXTRIGGER class

=head1 SYNOPSIS

use SonusQA::TRIGGER::PSXTRIGGER;

=head1 DESCRIPTION

SonusQA::TRIGGER::PSXTRIGGER processes trigger messages intended for the PSX.  It decodes the received trigger message.
Then it performs actions based on the decoded message and finally returns the result if any to the sender.

=head2 C< processPSX >

DESCRIPTION:

This subroutine processes a trigger message from MGTS for PSX

ARGUMENTS:

   -action        => Action to be taken E.g., FUNC
   -pattern => Pattern to be searched. E.g., "1-1-40"
   -value   => The expected respective value E.g., "Available"

PACKAGE:

  SonusQA::TRIGGER::PSXTRIGGER

GLOBAL VARIABLES USED:
    None

EXTERNAL FUNCTIONS USED:

    None

OUTPUT:

    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (processPSX(-action=> $action,-pattern => $pattern, -value => $value)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in getting PSX status");
        return 0;
    }

=cut

sub processPSX {
   # Process the commands directed towards PSX
   my ($self, %args) = @_;
   my %a;
   my $sub = "processPSX()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   # Check the command
   if($a{-action} eq "FUNC")
   {
      # Needs to multiple Processing
         $result = SonusQA::TRIGGER::PSXTRIGGER::getPsxPcStat(-pattern => "$a{-attr}",
                                        -value   => "$a{-value}",
                                        -psx     => $a{-arg});
   }

   return $result;
}

=head2 C< getPSXStatus >

DESCRIPTION:

    This subroutine gets the point code status from PSX

ARGUMENTS:

   -pattern => Pattern to be searched. E.g., "1-1-40"
   -value   => The expected respective value E.g., "Available"

PACKAGE:

     SonusQA::TRIGGER::PSXTRIGGER

GLOBAL VARIABLES USED:

    None

EXTERNAL FUNCTIONS USED:


OUTPUT:

    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (getPSXStatus (-pattern => $pattern, -value => $value)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in getting PSX status");
        return 0;
    }

=cut

sub getPSXStatus {

   my ($self, %args) = @_;
   my %a;
   my $sub = "getPSXStatus()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $psxStatusFirst = 0;

   $psxStatusFirst = getPsxPcStat(-pattern => "$a{-attr}",
                                  -value   => $a{-value});
   return $psxStatusFirst;
}
=head2 C< getPsxPcStat >

DESCRIPTION:

    This subroutine gets the point code status from PSX

ARGUMENTS:

   -pattern => Pattern to be searched. E.g., "1-1-40"
   -value   => The expected respective value E.g., "Available"

PACKAGE:

     SonusQA::TRIGGER::PSXTRIGGER

GLOBAL VARIABLES USED:

    None

EXTERNAL FUNCTIONS USED:


OUTPUT:

    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (getPsxPcStat (-pattern => $pattern, -value => $value)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in getting PSX status");
        return 0;
    }

=cut

sub getPsxPcStat {
   my (%args) = @_;
   my %a = (-psx => "FIRST");
   my $sub = "getPsxPcStat()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $psx_obj = $main::TESTBED{ "psx:1:obj" };
   if($a{-psx} eq "FIRST") {
      $psx_obj = $main::TESTBED{ "psx:1:obj" };
   }else {
      $psx_obj = $main::TESTBED{ "psx:2:obj" };
   }

   my $requestedStatus = 0;

   my @temp = "17";

   my @pcStatus = $psx_obj->scpamgmtStats(\@temp);

   $logger->debug(__PACKAGE__ . ".$sub: @pcStatus");

   my $line;
   # Check the requested pattern E.g., 1-1-40
   foreach $line (@pcStatus) {
      chomp($line);
      my @fields = split(' ', $line);

      my $noOfFields = scalar @fields;
      if ($noOfFields > 2) {
         $logger->debug(__PACKAGE__ . ".$sub: line => $line");
         # Check the requested values
         if ($fields[1] eq $a{-pattern}) {
            $logger->debug(__PACKAGE__ . ".$sub: Got the requested pattern => $line");

            # Check the requested value
            if ($fields[3] eq $a{-value}) {
               $logger->debug(__PACKAGE__ . ".$sub: Got the requested value");
               # we are through. Return success
               $requestedStatus = 1;
            } else {
               $logger->debug(__PACKAGE__ . ".$sub: not matching the requested value");
            }
            last;
         }
      }
   }
   return $requestedStatus;
}
1;


