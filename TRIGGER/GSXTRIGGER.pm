package SonusQA::TRIGGER::GSXTRIGGER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::MGTS;
use SonusQA::ATSHELPER;
use SonusQA::TRIGGER::PSXTRIGGER;

=head1 NAME

SonusQA::TRIGGER::GSXTRIGGER class

=head1 SYNOPSIS

use SonusQA::TRIGGER::GSXTRIGGER;

=head1 DESCRIPTION

SonusQA::TRIGGER::GSXTRIGGER processes trigger messages intended for the GSX.  It decodes the received trigger message.
Then it performs actions based on the decoded message and finally returns the result if any to the sender.

=head1 AUTHORS

Susanth Sukumaran (ssukumaran@sonusnet.com)
Kevin Rodrigues (krodrigues@sonusnet.com)

=head2 C< processGSX >

DESCRIPTION:

This subroutine processes a trigger message from MGTS for GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -action        => Action to be taken E.g., STAT/FUNC
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    None 

OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (processGSX(-noOfPatterns  => 1,
                       -action        => $fields[1],
                       -command       => $fields[2],
                       -arg           => $fields[4],
                       -attr          => $fields[5],
                       -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

    or 

    unless (processGSX(-noOfPatterns  => 2,
                       -action        => $fields[1],
                       -command       => $fields[2],
                       -arg           => $fields[4],
                       -attr          => $fields[5],
                       -value         => $fields[6],
                       -attr1         => $fields[7],
                       -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }


=cut

sub processGSX {
   # Process the commands directed towards GSX
   my ($self, %args) = @_;
   my %a;
   my $sub = "processGSX()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   # Check the command
   if($a{-action} eq "STAT")
   {
      # This is status request
      $result = $self->processGSXStatusRequest(%a);
   }
   elsif($a{-action} eq "FUNC")
   {
      # Needs to multiple Processing
      $result = $self->processGSXFunction(%a);
   }

   return $result;
}

=head2 C< processGSXFunction >

DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    None

OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (SonusQA::TRIGGER::GSXTRIGGER::processGSXFunction(-noOfPatterns  => 1,
															 -command       => $fields[2],
															 -arg           => $fields[4],
															 -attr          => $fields[5],
															 -value         => $fields[6],
															 -attr1         => $fields[7],
															 -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=cut

sub processGSXFunction {

   my ($self, %args) = @_;

   my $sub = "processGSXFunction()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   if ($a{-command} eq "GSXSTAT") {
      $result = $self->getGSXStatus(%a);
   } elsif($a{-command} eq "GSXISUP") {
      $result = $self->getGSXISUPStatus(%a);
   } elsif($a{-command} eq "STATCON") {
      $result = $self->getStatCong(%a);
   } elsif($a{-command} eq "GSXONLYSTAT") {
      $result = $self->getGSXStatus(%a, -onlyGSXStat => 1);
   } elsif($a{-command} eq "GSXRANGE") {
      $result = $self->processGSXRangeRequest(%a);
   } elsif($a{-command} eq "GSXWILDCARD") {
      $result = $self->processGSXWildCardRangeRequest(%a);
   }
   return $result;
}

=head2 C< processGSXStatusRequest >

DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    SonusQA::GSX::execCmd

OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (&processGSXStatusRequest(-noOfPatterns  => 1,
										   -command       => $fields[2],
										   -arg           => $fields[4],
										   -attr          => $fields[5],
										   -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

    or 

    unless (&processGSXStatusRequest(-noOfPatterns  => 2,
										   -command       => $fields[2],
										   -arg           => $fields[4],
										   -attr          => $fields[5],
										   -value         => $fields[6],
										   -attr1         => $fields[7],
										   -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }


=cut

sub processGSXStatusRequest {
   my ($self, %args) = @_;
   my %a;
   my $sub = "processGSXStatusRequest()";

   my %GSXmapTable       = ( S7N             => "SHOW SS7 NODE"
                        );

   my %GSXattributeTable   = ( IS              => "ISUP Status"
                        );

   my %GSXvalueTable    = ( FLD             => "FAILED",
                         ACT             => "ACTIVE"
                        );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # get the GSX object
   my $gsx_session = $main::TESTBED{ "gsx:1:obj" };

   # Get the command
   my $cmdString = $GSXmapTable{$a{-command}};

   #Append the argument
   $cmdString = $cmdString . " $a{-arg}";

   # Add the status string after the argument
   $cmdString = $cmdString . " STATUS";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # run the CLI
   unless($gsx_session->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($gsx_session->{CMDRESULTS}));

   #Parse the CLI output
   foreach ( @{ $gsx_session->{CMDRESULTS}} ) {
      my @fields = (split /:/)[0,1];

      if($fields[0] eq $GSXattributeTable{$a{-attr}})
      {
         $logger->info(__PACKAGE__ . ".$sub Pattern matched");
         $logger->info(__PACKAGE__ . ".$sub $fields[0] : $fields[1]");

         # get the status field
         my $status = $fields[1];

         # remove the leading spaces
         $status =~ s/^\s+//;

         # Get the requested status
         my $dataStr = $GSXvalueTable{$a{-value}};

         $logger->info(__PACKAGE__ . ".$sub $status:$dataStr");

         # Check the status
         if($status eq $dataStr)
         {
            # We are through. Got the requested status
            $logger->info(__PACKAGE__ . ".$sub Status matched");

            # return success/true
            return 1;
         }
         else
         {
            # The requested status is not matching
            $logger->info(__PACKAGE__ . ".$sub Status NOT matched");

            # return failure/false
            return 0;
         }
      }
   }
   # return failure/false
   return 0;
}

=head2 C< getGSXStatus >

DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    SonusQA::GSX::execCmd


OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (&getGSXStatus(-noOfPatterns  => 1,
                         -command       => $fields[2],
                         -arg           => $fields[4],
                         -attr          => $fields[5],
                         -value         => $fields[6],
                         -attr1         => $fields[7],
                         -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=cut

sub getGSXStatus {

   my ($self, %args) = @_;
   my %a = (-onlyGSXStat => 0);
   my $sub = "getGSXStatus()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $gsx_session;

   # get the GSX object
   if($a{-arg} eq "FIRST") {
      $gsx_session = $main::TESTBED{ "gsx:1:obj" };
   }
   else {
      $gsx_session = $main::TESTBED{ "gsx:2:obj" };
   }

   # Get the command
   my $cmdString = "SHOW ISUP SERVICE ALL STATUS";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # run the CLI
   unless($gsx_session->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI => $cmdString");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($gsx_session->{CMDRESULTS}));

   my $result = 0;
   my $skipLines = 0;
   my @fields;
   my $line;

   # Parse the output for the required string
   foreach $line ( @{ $gsx_session->{CMDRESULTS}} ) {
      if($skipLines lt 2) {
         if($line =~ m/--------/) {
            $skipLines = $skipLines + 1;
         }
         next;
      }

      # Split with space as delimitter
      @fields = split(' ', $line);

      # Verify the attribute first
      if($fields[1] eq $a{-attr}) {
         $logger->info(__PACKAGE__ . ".$sub Pattern matched");
         $logger->info(__PACKAGE__ . ".$sub $fields[0] : $fields[1] :  $fields[2]");

         # Check the value
         if($fields[2] eq $a{-value}) {
            # We are through. Got the requested status
            $logger->info(__PACKAGE__ . ".$sub Status matched");

            # return success/true
            $result = 1;
         }
         last;
      }
   }

   # Check m3uark
   my $m3uarkResult = 0;
   my $psxStatusFirst = 0;

   # run the CLI
   $cmdString = "admin debugSonus";

   unless($gsx_session->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI => $cmdString");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($gsx_session->{CMDRESULTS}));

   $cmdString = "m3uark";

   unless($gsx_session->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI => $cmdString");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($gsx_session->{CMDRESULTS}));

   $skipLines = 0;

   # Incase unavailable, if the point code is not available in the m3uark
   # output, treat it as true
   my $pointCodePresent = 0;
   
   # Parse the output for the required string
   foreach $line ( @{ $gsx_session->{CMDRESULTS}} ) {
      if($skipLines lt 1) {
         $skipLines = $skipLines + 1;
         next;
      }

      if($line =~ m/----/) {
         next;
      }

      $logger->info(__PACKAGE__ . ".$sub line : $line");

      # Remove : from the line
      $line =~ s/:/ /g;

      $logger->info(__PACKAGE__ . ".$sub line : $line");

      # Split with space as delimitter
      @fields = split(' ', $line);

      # Verify the attribute first
      if($fields[2] eq $a{-attr1}) {
         $logger->info(__PACKAGE__ . ".$sub Pattern matched");
         $logger->info(__PACKAGE__ . ".$sub $fields[0] : $fields[1] :  $fields[2] : $fields[10] : $fields[11]");

         $pointCodePresent = 1;

         # Check the value
         if(($fields[10] eq $a{-value1}) or ($fields[11] eq $a{-value1})) {
            # We are through. Got the requested status
            $logger->info(__PACKAGE__ . ".$sub Status matched");

            # return success/true
            $m3uarkResult = 1;
         }
         last;
      }
   }

   if(($m3uarkResult eq 0) and ($pointCodePresent eq 0) and ($a{-value1} eq "una"))
   {
      # Set the result as true
      $m3uarkResult = 1;
   }

   if($a{-onlyGSXStat} eq 0) {
      if ($a{-value1} eq "ava")   {
         $psxStatusFirst = SonusQA::TRIGGER::PSXTRIGGER::getPsxPcStat(-pattern => "$a{-attr}",
                                                                      -value   => "Available",
                                                                      -psx     => $a{-arg});
      } elsif ($a{-value1} eq "una") {
         $psxStatusFirst = SonusQA::TRIGGER::PSXTRIGGER::getPsxPcStat(-pattern => "$a{-attr}",
                                                                      -value   => "UnAvailable",
                                                                      -psx     => $a{-arg});
      } else   {
         $psxStatusFirst = SonusQA::TRIGGER::PSXTRIGGER::getPsxPcStat(-pattern => "$a{-attr}",
                                                                      -value   => "Congested",
                                                                      -psx     => $a{-arg});
      }
   } else {
     $psxStatusFirst = 1;
   }

   $logger->info(__PACKAGE__ . ".$sub result = $result, m3uarkResult = $m3uarkResult, psxStatusFirst= $psxStatusFirst");
   if(($result eq 1) and ($m3uarkResult eq 1) and ($psxStatusFirst eq 1)) {
      # All are true, return 1
      return 1;
   }

   return 0;
 }

=head2 C< getGSXISUPStatus >

DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    SonusQA::GSX::execCmd

OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (&getGSXISUPStatus(-noOfPatterns  => 1,
                             -command       => $fields[2],
                             -arg           => $fields[4],
                             -attr          => $fields[5],
                             -value         => $fields[6],
                             -attr1         => $fields[7],
                             -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=cut

sub getGSXISUPStatus  {

   my ($self, %args) = @_;
   my %a;
   my $sub = "getGSXISUPStatus()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $gsx_session;
   my $protocolType = $main::TESTSUITE->{VARIANT};
   $logger->info(__PACKAGE__ . ".$sub Protocol type got from testsuite hash : $protocolType");	
   # get the GSX object
   if($a{-arg} eq "FIRST") {
      $gsx_session = $main::TESTBED{ "gsx:1:obj" };
      $protocolType = $protocolType."1";
   }
   else {
      $gsx_session = $main::TESTBED{ "gsx:2:obj" };
      $protocolType = $protocolType."2";
   }

   my $gsx_name    = $gsx_session->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   my $localTrunkName = "TG" . $gsx_name . $protocolType;

   #$logger->info(__PACKAGE__ . ".$sub gsx_session : " . Dumper($gsx_session));

   # Get the command
   my $cmdString = "SHOW TRUNK GROUP ALL STATUS";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # run the CLI
   unless($gsx_session->execCmd($cmdString)) {
      $logger->error(__PACKAGE__ . ".$sub Error in executing the CLI");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($gsx_session->{CMDRESULTS}));

   my $result = 0;
   my $skipLines = 0;
   my $line;

   # Parse the output for the required string
   foreach $line ( @{ $gsx_session->{CMDRESULTS}} ) {
      if($skipLines lt 1) {
         if($line =~ m/--------/) {
            $skipLines = $skipLines + 1;
         }
         next;
      }

      # Split with space as delimiter
      my @fields = split(' ', $line);
      $logger->info(__PACKAGE__ . ".$sub Configured trunk group : $fields[0] and Local trunk group name : $localTrunkName");
      # Verify the attribute first
      if($fields[0] eq $localTrunkName) {
         $logger->info(__PACKAGE__ . ".$sub Pattern matched");
         $logger->info(__PACKAGE__ . ".$sub $fields[0] : $fields[1] :  $fields[2] : $fields[8]");

         # Check the value
         if($fields[2] eq 0) {
            # Calls available is "0". So not available
            $logger->info(__PACKAGE__ . ".$sub Status matched");
            $logger->info(__PACKAGE__ . ".$sub Calls are not available on configured CICs"); 
            if($a{-value} eq "NONZERO") {
               $logger->info(__PACKAGE__ . ".$sub  The argument, 'value' is NONZERO so returning failure.");
               # return failure/false
               $result = 0;
            }
            else {
               $logger->info(__PACKAGE__ . ".$sub  The argument, 'value' is not NONZERO (" . $a{-value} . ') so returning success.');
               # return success/true
               $result = 1;
            }
         }
         else {
            # Calls available is NOT "0". So available
            $logger->info(__PACKAGE__ . ".$sub Status matched");
	    $logger->info(__PACKAGE__ . ".$sub Calls are available on configured CICs");
            if($a{-value} eq "NONZERO") {
               $logger->info(__PACKAGE__ . ".$sub  The argument, 'value' is NONZERO so returning failure.");
               # return success/true
               $result = 1;
            }
            else {
               $logger->info(__PACKAGE__ . ".$sub  The argument, 'value' is not NONZERO (" . $a{-value} . ') so returning success.');
               # return failure/false
               $result = 0;
            }
         }
         last;
      }
   }

   return $result;
}

=head2 C< getStatCong >

DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:
 
    None

EXTERNAL FUNCTIONS USED:

    SonusQA::GSX::execCmd

OUTPUT:
 
    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (&getStatCong(-noOfPatterns  => 1,
                        -command       => $fields[2],
                        -arg           => $fields[4],
                        -attr          => $fields[5],
                        -value         => $fields[6],
                        -attr1         => $fields[7],
                        -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=cut

sub getStatCong  {

   my ($self, %args) = @_;
   my %a;
   my $sub = "getStatCong()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

    my $result = 0;

    $result = $self->getGSXStatus(%a);


    if($result eq 0) {
       # There is some problem. Return from here itself
       return $result;
    }

    # Change the value here
    $a{-value} = 0;

    $result = $self->getGSXISUPStatus(%a);

    return $result;
}

=head2 C< processGSXRangeRequest >

DESCRIPTION:

    This subroutine checks status of all destionations withis the specified range of point codes in GSX

ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -arg           => The argument for the command
    -startRange    => start of point code range
    -endRange      => end of point code range
    -status        => The status to be checked


PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:

    None
EXTERNAL FUNCTIONS USED:

    SonusQA::TRIGGER::getLinkRangeStatus
    SonusQA::TRIGGER::checkLinkRangeStat

OUTPUT:

    0      - fail
    1      - True (Success)

EXAMPLE:

    unless (&processGSXRangeRequest( -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -startRange     => $fields[4],
                                                                  -endRange       => $fields[5],
                                                                  -status         => $fields[6],
                                                                  -protocolType   => $fields[7]);
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=cut

sub processGSXRangeRequest {
   my ($self, %args) = @_;
   my $sub = "processGSXRangeRequest()";
   my %a =  (-gsxInfo     => "FIRST"); ;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $returnStat;
   unless ($returnStat = SonusQA::TRIGGER::getLinkRangeStatus(-startRange   => $a{-startRange},
                                                              -endRange     => $a{-endRange},
                                                              -gsxInfo     => $a{-gsxInfo},
                                                              -getSgx      => 0,
                                                              -protocolType => $a{-protocolType})) {
      $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
      print "Error in getting link status\n";
      return 0;
   }
   my $retCode = 1;
   my $psxStat;
   if ($a{-status} eq "ava")
   {
      $psxStat = "Available";
   }elsif ($a{-status} eq "una")
   {
      $psxStat = "UnAvailable";
   }elsif ($a{-status} eq "con")
   {
      $psxStat = "Congested";
   }

   unless($retCode = SonusQA::TRIGGER::checkLinkRangeStat(-statusInfo => $returnStat,
                                                          -gsxStat     => $a{-status},
                                                          -psxStat     => $psxStat))  {
      $logger->error(__PACKAGE__ . ".$sub: There is an issue with link status");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Returning with ----> [$retCode]");
   return $retCode;
}

=head2 C< processGSXWildCardRangeRequest >

DESCRIPTION:

    This subroutine checks status of all destinations matching the wildcard in GSX

ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -pointcode1    => wild card string
    -status        => The status to be checked
    -conStatus     => The congestion level to be checked
    -exceptFlag    => 1 if except array is present else 0.
    -exceptArr     => The array of point codes to be excluded


PACKAGE:

  SonusQA::TRIGGER::GSXTRIGGER

GLOBAL VARIABLES USED:

    None

EXTERNAL FUNCTIONS USED:

    SonusQA::TRIGGER::getWildCharLinkRangeStatus
    SonusQA::TRIGGER::checkLinkRangeStatWithExcept
    SonusQA::TRIGGER::checkLinkRangeStat

OUTPUT:

    0      - fail
    1      - True (Success)

EXAMPLE:
    unless ($self->processGSXWildCardRangeRequest (  -action        => $fields[1],
                                                                   -CEInfo         => $fields[2],
                                                                   -command        => $fields[3],
                                                                   -pointcode1     => $fields[4],
                                                                   -status         => $fields[6],
                                                                   -conStatus      => $fields[8],
                                                                   -exceptFlag     => 1,
                                                                   -exceptArr      => $fields[10]){
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }


=cut


sub processGSXWildCardRangeRequest {
   my ($self, %args) = @_;
   my $sub = "processGSXWildCardRangeRequest()";
   my %a = (-gsxInfo     => "FIRST");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my @fields = split(',', $a{-pointcode1});
   my $sizeofFields = scalar @fields;
   my $returnStat;
   my $retCode;
   my %tempStatus;
   my $key;
   my $psxStat;
   my $index;
   for($index = 0; $index < $sizeofFields; $index++)
   {
      $logger->info(__PACKAGE__ . ".$sub: Point code : $fields[$index]");
      unless ($returnStat = SonusQA::TRIGGER::getWildCharLinkRangeStatus(-wildChar   => $fields[$index],
                                                                         -protocolType => "JAPAN",
                                                                         -gsxInfo     => $a{-gsxInfo},
                                                                         -getSgx      => 0)) {
         $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
         print "Error in getting link status\n";
         return 0;
      }
      $retCode = 1;
      %tempStatus = %{$returnStat};
      if($a{-exceptFlag} eq 1) {
         $logger->info(__PACKAGE__ . ".$sub:exceptFlag is 1");
         my @fields1 = split(',', $a{-exceptArr});
         my $sizeofFields1 = scalar @fields1;
         my @exceptArr;
         my $index1;
         for($index1 = 0; $index1 < $sizeofFields1; $index1++)
         {
            push (@exceptArr, $fields1[$index1]);
            $logger->info(__PACKAGE__ . ".$sub: remove point code $fields1[$index1]");
         }
         unless($retCode = SonusQA::TRIGGER::checkLinkRangeStatWithExcept(-statusInfo => $returnStat,
                                                                          -exceptArr  => \@exceptArr,
                                                                          -gsxStat     => "una",
                                                                          -psxStat     => "UnAvailable")) {
           $logger->error(__PACKAGE__ . ".$sub The link status is not in the expected state");
           return 0;
         }
      } else {
         if ($a{-status} eq "ava")
         {
            $psxStat = "Available";
         }elsif ($a{-status} eq "una")
         {
            $psxStat = "UnAvailable";
         }elsif ($a{-status} eq "con")
         {
            $psxStat = "Congested";
         }

         unless($retCode = SonusQA::TRIGGER::checkLinkRangeStat(-statusInfo => $returnStat,
                                                                -gsxStat     => $a{-status},
                                                                -psxStat     => $psxStat))  {
            $logger->error(__PACKAGE__ . ".$sub: There is an issue with link status");
            return 0;
         }
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub Returning with ----> [$retCode]");
   return $retCode;
}
1;
