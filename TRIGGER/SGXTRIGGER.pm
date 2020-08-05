package SonusQA::TRIGGER::SGXTRIGGER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::MGTS;
use SonusQA::ATSHELPER;

=head1 NAME

SonusQA::TRIGGER::SGXTRIGGER

=head1 SYNOPSIS

use SonusQA::TRIGGER::SGXTRIGGER;

=head1 DESCRIPTION

SonusQA::TRIGGER::SGXTRIGGER processes trigger messages intended for the GSX.  It decodes the received trigger message.
Then it performs actions based on the decoded message and finally returns the result if any to the sender.

=head1 AUTHORS

Susanth Sukumaran (ssukumaran@sonusnet.com)
Kevin Rodrigues (krodrigues@sonusnet.com)

=head1 METHODS

=head2 processSGX

=over

=item DESCRIPTION:

    This subroutine processes a trigger message from MGTS for SGX

=item ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -action        => Action to be taken E.g., STAT/CONF/FUNC
    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None 

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGX(-noOfPatterns  => 1,
							  -action        => $fields[1],
							  -command       => $fields[2],
							  -CEInfo        => $fields[3],
							  -arg           => $fields[4],
							  -attr          => $fields[5],
							  -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

    or 

    unless ($self->processSGX(-noOfPatterns  => 2,
							  -action        => $fields[1],
							  -command       => $fields[2],
							  -CEInfo        => $fields[3],
							  -arg           => $fields[4],
							  -attr          => $fields[5],
							  -value         => $fields[6],
							  -attr1         => $fields[7],
							  -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGX {
   # Process the commands directed towards SGX
   my ($self, %args) = @_;
   my %a;
   my $sub = "processSGX()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->debug(__PACKAGE__ . ".$sub Entered sub.");

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   # Check the command
   if($a{-action} eq "STAT") {

      # This is status request
      $result = $self->processSGXStatusRequest(%a);
   }
   elsif($a{-action} eq "CONF") {

      # Needs to do some configuration
      $result = $self->processSGXConfigureRequest(%a);
   } elsif($a{-action} eq "FUNC") {

      # Needs to do multiple actions
      $result = $self->processSGXFunction(%a);
   } 
   elsif($a{-action} eq "REQU") {

      # Process the 'request, command
      $result = $self->processSGXRequestCommand(%a);
   }

   # return whatever we got
   return $result;
}

=head2 processSGXFunction

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting configuration change in SGX, which requires a specific functionality needs to be executed.

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXFunction(-command       => $fields[2],
									  -CEInfo        => $fields[3],
									  -arg           => $fields[4],
									  -attr          => $fields[5],
									  -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGXFunction {
   my ($self, %args) = @_;

   my $sub = "processSGXFunction()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   if ($a{-command} eq "RTDEL") {
      $result = $self->deleteRoute(%a);
   } elsif ($a{-command} eq "RTADD") {
      $result = $self->addRoute(%a);
   } elsif ($a{-command} eq "SWTOVR") {
      $result = $self->systemSwitchOver(%a);
   } elsif ($a{-command} eq "STATCON") {
      $result = $self->statCong(%a);
   } elsif ($a{-command} eq "SOFTRST") {
      $result = $self->ceSoftReset(%a);
   }elsif ($a{-command} eq "SGXRANGE") {
      $result = $self->processSGXRangeRequest(%a);
   }elsif ($a{-command} eq "SGXWILDCARD") {
      $result = $self->processSGXWildCardRangeRequest(%a);
   }
   return $result;
}

=head2 processSGXStatusRequest

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting status information from SGX

=item ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute
    -attr1         => The second attribute, whose value to be checked
    -value1        => The value to be checked for the second attribute

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::newFromAlias
    SonusQA::SGX4000::execCliCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXStatusRequest(-noOfPatterns  => 1,
										   -command       => $fields[2],
										   -CEInfo        => $fields[3],
										   -arg           => $fields[4],
										   -attr          => $fields[5],
										   -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

    or 

    unless ($self->processSGXStatusRequest(-noOfPatterns  => 2,
										   -command       => $fields[2],
										   -CEInfo        => $fields[3],
										   -arg           => $fields[4],
										   -attr          => $fields[5],
										   -value         => $fields[6],
										   -attr1         => $fields[7],
										   -value1        => $fields[8])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGXStatusRequest {

   my ($self, %args) = @_;
   my %a;
   my $sub = "processSGXStatusRequest()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %SGXmapTable  = ( S7DS           => "show status ss7 destinationStatus",
                        M3SGP          => "set m3ua sgpLink",
                        M3ASP          => "set m3ua aspLink",
                        S7RT           => "set ss7 route",
                        S7RT1           => "set ss7 route",
                        S7DEL          => "delete ss7 route",
                        SOFTRST        => "request system serverAdmin",
                        SGXSVR         => "service sgx",
                        S7NODE         => "set ss7 node",
                        M3PR           => "set m3ua profile",
                        INTRCE         => "ifconfig bond0"
                      );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the command string
   my $cmdString = $SGXmapTable{$a{-command}};

   # Append the requested argument
   $cmdString = $cmdString . " $a{-arg}";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # Get the SGX object
   my $sgx_object;

   if(($a{-CEInfo} eq "DEF") or ($a{-CEInfo} eq "CE0")) {
      # use default or CE0. Taking CE0 will be always active before starting the test execution
      $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };
	  
   } elsif ($a{-CEInfo} eq "CE1") {
      # Connect to CE1
      my $debug_flag = 0;

      my $ce1Alias = $main::TESTBED{ "sgx4000:1:ce1" };
      $sgx_object = SonusQA::SGX4000::newFromAlias( -tms_alias      => $ce1Alias, 
                                                    -obj_type       => "SGX4000", 
                                                    -return_on_fail => 1,
                                                    -sessionlog     => $debug_flag);
      if($sgx_object) {
         $logger->debug(__PACKAGE__ . ".$sub:  Connection attempt to $ce1Alias successful.");
         $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [obj: $ce1Alias]");
      }
      else {
         $logger->debug(__PACKAGE__ . ".$sub:  Connection attempt to $ce1Alias failed.");
         return 0;
      }

   } else {
      # there is a problem
      $logger->error (__PACKAGE__ . ".$sub Invalid CE specified");
      return 0;
   }

#   $logger->info(__PACKAGE__ . ".$sub sgx_object : " . Dumper ($sgx_object));

   # Execute the CLI
   unless($sgx_object->execCliCmd($cmdString)) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   my @fields;

   if($a{-noOfPatterns} eq 1)
   {
      # Parse the CLI output
      foreach ( @{ $sgx_object->{CMDRESULTS}} ) {
         @fields = (split)[0,1];

         if($fields[0] eq $a{-attr})
         {
            $logger->info(__PACKAGE__ . ".$sub The attribute matched");
            $logger->info(__PACKAGE__ . ".$sub The attribute => $fields[0] : $fields[1]");

            # Check the requested status
            if( $fields[1] =~ m/$a{-value}/ )
            {
               # We are through. The status is matching
               $logger->info(__PACKAGE__ . ".$sub The Status is matching");

               # Return success/True
               return 1;
            }
            else
            {
               # Failed. The status is NOT matching
               $logger->info(__PACKAGE__ . ".$sub The Status is NOT matching");

               # Return failure/false
               return 0;
            }
         }
      }
   }
   else
   {
      # Needs to check status of 2 attributes

      my $attrFlag = 0;
      my $attrOneFlag = 0;
      my $valueFlag = 0;
      my $valueOneFlag = 0;

      # Parse the CLI output
      foreach ( @{ $sgx_object->{CMDRESULTS}} ) {
         @fields = (split)[0,1];

         # Check the first attribute
         if($fields[0] eq $a{-attr})
         {
            $logger->info(__PACKAGE__ . ".$sub The attribute matched");
            $logger->info(__PACKAGE__ . ".$sub The attribute => $fields[0] : $fields[1]");

            # Mark first attribute recived
            $attrFlag = 1;

            # Check the requested status
            if( $fields[1] =~ m/$a{-value}/ )
            {
               # We are through. The status is matching
               $logger->info(__PACKAGE__ . ".$sub The Status is matching");

               $valueFlag = 1;
            }
            else
            {
               # Failed. The status is NOT matching
               $logger->info(__PACKAGE__ . ".$sub The Status is NOT matching");
            }
         }

         # Check the second attribute
         if($fields[0] eq $a{-attr1})
         {
            $logger->info(__PACKAGE__ . ".$sub The attribute1 matched");
            $logger->info(__PACKAGE__ . ".$sub The attribute1 => $fields[0] : $fields[1]");

            # Mark first attribute received
            $attrOneFlag = 1;

            # Check the requested status
            if( $fields[1] =~ m/$a{-value1}/ )
            {
               # We are through. The status is matching
               $logger->info(__PACKAGE__ . ".$sub The Status1 is matching");

               $valueOneFlag = 1;
            }
            else
            {
               # Failed. The status is NOT matching
               $logger->info(__PACKAGE__ . ".$sub The Status1 is NOT matching");
            }
         }

         # Check both attributes are received
         if(($attrFlag eq 1) && ($attrOneFlag eq 1))
         {
            # Got both attributes. Check status
            if(($valueFlag eq 1) && ($valueOneFlag eq 1))
            {
               # Both are true

               # Return success/True
               return 1;
            }
            else
            {
               # Both are failed or at least one is failed

               # Return failure/false
               return 0;
            }
         }
      }
   }

   #  Return failure/false
   return 0;
}

=head2 processSGXRequestCommand

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS to invoke a 'request' command.
    Note - The cli command is executed on the sgx cli session expected to be populated in $main::TESTBED{ "sgx4000:1:obj2" }
    Note - the command is issued without waiting for completion. 
           The application can then check for completion of the command and results later

=item ARGUMENTS:

    -noOfPatterns  => Number of patterns/attributes for processing
    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::newFromAlias
    SonusQA::SGX4000::execCliCmd

=item OUTPUT:

    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXStatusRequest(-noOfPatterns  => 1,
										   -command       => $fields[2],
										   -CEInfo        => $fields[3],
										   -arg           => $fields[4])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGXRequestCommand {
   my ($self, %args) = @_;
   my %a;
   my $sub = "processSGXRequestCommand()";
   
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my $scr_logger = Log::Log4perl->get_logger("SCREEN");

   my %SGXmapTable  = ( S7DS           => "show status ss7 destinationStatus",
                        M3SGP          => "set m3ua sgpLink",
                        M3ASP          => "set m3ua aspLink",
                        S7RT           => "set ss7 route",
                        S7RT2           => "set ss7 route",
                        S7DEL          => "delete ss7 route",
                        SOFTRST        => "request system serverAdmin",
                        SGXSVR         => "service sgx",
                        S7NODE         => "set ss7 node",
                        M3PR           => "set m3ua profile",
                        INTRCE         => "ifconfig bond0",
                        REQSRT         => "request ss7 mtp2SignalingLink"
                      );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
 
   # Get the command string
   my $cmdString = $SGXmapTable{$a{-command}};

   # Append the requested argument
   $cmdString = $cmdString . " $a{-arg}" . " $a{-attr}" . " $a{-value}" . " $a{-attr1}";
  
   # Get the SGX object - uses second cli session
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj2" };

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # Execute the CLI command without waiting for completion
   $sgx_object->{conn}->print($cmdString);
   $sgx_object->{LASTCMD} = $cmdString;

   return 1;
}

=head2 processSGXConfigureRequest

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting configuration change in SGX

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::enterPrivateSession
    SonusQA::SGX4000::execCommitCliCmd
    SonusQA::SGX4000::leaveConfigureSession

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXConfigureRequest(-command       => $fields[2],
											  -CEInfo        => $fields[3],
											  -arg           => $fields[4],
											  -attr          => $fields[5],
											  -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGXConfigureRequest {
   my ($self, %args) = @_;
   my %a;
   my $sub = "processSGXConfigureRequest()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my %SGXmapTable = ( S7DS           => "show status ss7 destinationStatus",
                       M3SGP          => "set m3ua sgpLink",
                       M3ASP          => "set m3ua aspLink",
                       S7MTP2         => "set ss7 mtp2SignalingLink",        
                       S7RT           => "set ss7 route",
                       S7RT2           => "set ss7 route",
                       S7DEL          => "delete ss7 route",
                       SOFTRST        => "request system serverAdmin",
                       SGXSVR         => "service sgx",
                       S7NODE         => "set ss7 node",
                       M3PR           => "set m3ua profile",
                       INTRCE         => "ifconfig bond0",
		       S7DS           => "set ss7 destination",
                       M3TM           => "set ss7 mtp3TimerProfile"
                      );

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

   # get the GSX object
   my $gsx_object = $main::TESTBED{ "gsx:1:obj" };

   my $gsx_name = $gsx_object->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   my $cmdString;
   if(($a{-command} eq "M3ASP") or ($a{-command} eq "S7MTP2") or ($a{-command} eq "S7RT") or ($a{-command} eq "S7NODE") or ($a{-command} eq "S7DS") or ($a{-command} eq "M3TM")){

      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};

      # Append the requested argument
      $cmdString = $cmdString . " $a{-arg} $a{-attr} $a{-value}";

   } elsif ($a{-command} eq "M3SGP") {

      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};

      # Append the GSX name
      $cmdString = $cmdString . " gsx" . "$gsx_name" . "$a{-arg}" . "Active $a{-attr} $a{-value}";

   }  elsif ($a{-command} eq "SOFTRST") {

      my $CEName;

      if ($a{-arg} eq "CE1") {
         $CEName = $main::TESTBED{ "sgx4000:1:ce1:hash" }->{CE}->{1}->{HOSTNAME};
      } else {
         $CEName = $main::TESTBED{ "sgx4000:1:ce0:hash" }->{CE}->{1}->{HOSTNAME};
      }

      $logger->info(__PACKAGE__ . ".$sub CE Name : $CEName");

      my $resetRetCode = $sgx_object->softResetCE($CEName);

      $logger->info(__PACKAGE__ . ".$sub softResetCE returned => $resetRetCode");

      return $resetRetCode;

   } elsif ($a{-command} eq "S7DEL") {

      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};
       
      # Append the argument
      $cmdString =  $cmdString . " $a{-arg}";

   } elsif ($a{-command} eq "SGXSVR") {

      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};
       
      # Append the argument
      $cmdString =  $cmdString . " $a{-attr}";
   } elsif ($a{-command} eq "M3PR" ) {
      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};

      # Append the requested argument
      $cmdString = $cmdString . " $a{-attr} $a{-value}";
   } elsif ($a{-command} eq "INTRCE") {

      # Get the command string
      $cmdString = $SGXmapTable{$a{-command}};
       
      # Append the argument
      $cmdString =  $cmdString . " $a{-attr}";
   } elsif ($a{-command} eq "S7RT2") {
      my $retCode = 1;
      $retCode = lastRouteOos (%a);

      #  Return failure/false
      return $retCode;
   }

   unless ( $sgx_object->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode--\n @{$sgx_object->{CMDRESULTS}}" );
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   my $retCode = 1;

   # Execute the CLI
   unless($sgx_object->execCommitCliCmdConfirm($cmdString)) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      $retCode = 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   unless ( $sgx_object->leaveConfigureSession() ) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to leave private session--\n @{$sgx_object->{CMDRESULTS}}" );
      $sgx_object->leaveConfigureSession;
      $retCode = 0;
   }
   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   #  Return failure/false
   return $retCode;
}

=head2 deleteRoute

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting route delete from the SGX

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (deleteRoute(-command       => $fields[2],
                        -CEInfo        => $fields[3],
                        -arg           => $fields[4],
                        -attr          => $fields[5],
                        -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub deleteRoute {

   my ($self, %args) = @_;

   my $sub = "deleteRoute()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   $result = $self->processSGXConfigureRequest ( -noOfPatterns  => "DUMMY",
                                                 -action        => "CONF",
                                                 -command       => "S7RT",
                                                 -arg           => $a{-arg},
                                                 -attr          => "mode",
                                                 -value         => "outOfService");

   if($result eq 0)
   {
      #There is something wrong. Return from here
      return $result;
   }

   $result = $self->processSGXConfigureRequest ( -noOfPatterns  => "DUMMY",
                                                 -action        => "CONF",
                                                 -command       => "S7RT",
                                                 -arg           => $a{-arg},
                                                 -attr          => "state",
                                                 -value         => "disabled");

   if($result eq 0)
   {
      #There is something wrong. Return from here
      return $result;
   }

   $result = $self->processSGXConfigureRequest ( -noOfPatterns  => "DUMMY",
                                                 -action        => "CONF",
                                                 -command       => "S7DEL",
                                                 -arg           => $a{-arg},
                                                 -attr          => "DUMMY",
                                                 -value         => "DUMMY");

   return $result;
}

=head2 addRoute

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting route add in the SGX

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::execCliCmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (addRoute(-command       => $fields[2],
                     -CEInfo        => $fields[3],
                     -arg           => $fields[4],
                     -attr          => $fields[5],
                     -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub addRoute {
   my ($self, %args) = @_;

   my $sub = "addRoute()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

   my $result = 0;

   # Do the ADD command here itself. It got a lot of arguments...
   my $cmdString = "set ss7 route $a{-arg} linkSetName stp1MgtsCE0Single typeOfRoute m3uaAsp priority 2 destination blueJayFITDest";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");
   
   unless ( $sgx_object->execCliCmd("configure private")) {
       $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode--\n $sgx_object->{CMDRESULTS}" );
       return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   # Execute the CLI
   unless($sgx_object->execCliCmd($cmdString)) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   unless ( $sgx_object->execCliCmd("commit")) {
      $logger->error(__PACKAGE__ . ".$sub :  Failed to execute commit command.");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   unless ( $sgx_object->execCliCmd("exit")) {
      $logger->error(__PACKAGE__ . ".$sub :  Failed to execute exit command.");
      return 0;
   }

   $result = $self->processSGXConfigureRequest ( -noOfPatterns  => "DUMMY",
                                                 -action        => "CONF",
                                                 -command       => "S7RT",
                                                 -arg           => $a{-arg},
                                                 -attr          => "state",
                                                 -value         => "enabled");

   if($result eq 0)
   {
      #There is something wrong. Return from here
      return $result;
   }

   $result = $self->processSGXConfigureRequest ( -noOfPatterns  => "DUMMY",
                                                 -action        => "CONF",
                                                 -command       => "S7RT",
                                                 -arg           => $a{-arg},
                                                 -attr          => "mode",
                                                 -value         => "inService");

   return $result;
}
=head2 systemSwitchOver

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting system switchover

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::switchoverCE

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (systemSwitchOver(-command       => $fields[2],
                             -CEInfo        => $fields[3],
                             -arg           => $fields[4],
                             -attr          => $fields[5],
                             -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub systemSwitchOver {
   my ($self, %args) = @_;

   my $sub = "systemSwitchOver()";
   my %a;
   my $active_ce;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

   my $retCode = $sgx_object->execCliCmd("show table system admin");

   $logger->info(__PACKAGE__ . ".$sub: test code $retCode " . Dumper(\@{$sgx_object->{CMDRESULTS}}));

   if($retCode eq 0) {
      sleep 3;
      # because of sync, the CLI connection must have closed. Distroy the object and connect again
      $sgx_object->DESTROY;
      $main::TESTBED{ "sgx4000:1:obj" } = undef;

      sleep 2;

      # Connect to SGX4000:1. For the Traffic Control tests we are not worried which CE we connect to initially.
      if ( $main::TESTBED{ "sgx4000:1:obj" } = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => \@{ $main::TESTBED{ "sgx4000:1" }}, -debug => 1)) {
         $active_ce = $main::TESTBED{ $main::TESTBED{ "sgx4000:1:obj" }->{OBJ_HOSTNAME} };
         $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $main::TESTBED{ $active_ce } \($active_ce\)");
      }
      else {
         $logger->debug(__PACKAGE__ . ".$sub : Could not open session object to required SGX4000");
         return 0;
      }

      $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

      $retCode = $sgx_object->execCliCmd("show table system admin");
      $logger->info(__PACKAGE__ . ".$sub: test code $retCode " . Dumper(\@{$sgx_object->{CMDRESULTS}}));
   }

   unless ($sgx_object->switchoverCE(-type => $a{-arg}, -waitFSOver => $a{-attr})) {
      $logger->error(__PACKAGE__ . ".$sub:  Failed to do system switch over.");
      return 0;
   }

   my $old_active_ce = $main::TESTBED{ $main::TESTBED{ "sgx4000:1:obj" }->{OBJ_HOSTNAME} };
   my $CE0Name = $main::TESTBED{ "sgx4000:1:ce0:hash" }->{CE}->{1}->{HOSTNAME};
   my $CE1Name = $main::TESTBED{ "sgx4000:1:ce1:hash" }->{CE}->{1}->{HOSTNAME};

   $logger->debug(__PACKAGE__ . ".$sub : Old active CE $old_active_ce");

   my @new_device_list;

   if ( $old_active_ce eq "sgx4000:1:ce1" ) {
       @new_device_list = ( $CE0Name, $CE1Name );
   } else {
       @new_device_list = ( $CE1Name, $CE0Name );
   }

   $logger->debug(__PACKAGE__ . ".$sub : New device list @new_device_list");

   # After the switchover we have to get a new connection
   $sgx_object->DESTROY;
   $main::TESTBED{ "sgx4000:1:obj" } = undef;

   sleep 5;

   # Connect to SGX4000:1. For the Traffic Control tests we are not worried which CE we connect to initially.
   if ( $main::TESTBED{ "sgx4000:1:obj" } = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => \@new_device_list, -debug => 1)) {
      $active_ce = $main::TESTBED{ $main::TESTBED{ "sgx4000:1:obj" }->{OBJ_HOSTNAME} };
      $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $main::TESTBED{ $active_ce } \($active_ce\)");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub : Could not open session object to required SGX4000");
      return 0;
   }

   return 1;
}

=head2 ceSoftReset

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting CE soft reset

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::ceSoftReset

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (ceSoftReset(-command       => $fields[2],
                             -CEInfo        => $fields[3],
                             -arg           => $fields[4],
                             -attr          => $fields[5],
                             -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub ceSoftReset {
   my ($self, %args) = @_;

   my $sub = "ceSoftReset()";
   my %a;
   my $active_ce;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

   # $logger->info(__PACKAGE__ . ".$sub SGX object : " . Dumper($sgx_object) );

   # get the CE Name like => sylvester.uk.sonusnet.com
   my $CEName;

   if ($a{-arg} eq "CE1") {
      $CEName = $main::TESTBED{ "sgx4000:1:ce1:hash" }->{CE}->{1}->{HOSTNAME};

      # get the CE Name like => sylvester.uk.sonusnet.com
      #$CEName = $ce1_sgx_object->{CE_NAME_LONG};
   } else {
      $CEName = $main::TESTBED{ "sgx4000:1:ce0:hash" }->{CE}->{1}->{HOSTNAME};

      # get the CE Name like => sylvester.uk.sonusnet.com
      #$CEName = $sgx_object->{CE_NAME_LONG};
   }

   $logger->info(__PACKAGE__ . ".$sub CE Name : $CEName");

   # Get the command string
   #$cmdString = $SGXmapTable{$a{-command}};

   # Append the CE Name and arg
   #$cmdString = $cmdString . " $CEName $a{-attr}";

   my $resetRetCode = $sgx_object->softResetCE($CEName);

   $logger->info(__PACKAGE__ . ".$sub softResetCE returned => $resetRetCode");

   my $old_active_ce = $main::TESTBED{ $main::TESTBED{ "sgx4000:1:obj" }->{OBJ_HOSTNAME} };
   my $CE0Name = $main::TESTBED{ "sgx4000:1:ce0:hash" }->{CE}->{1}->{HOSTNAME};
   my $CE1Name = $main::TESTBED{ "sgx4000:1:ce1:hash" }->{CE}->{1}->{HOSTNAME};

   $logger->debug(__PACKAGE__ . ".$sub : Old active CE $old_active_ce");

   my @new_device_list;

   if ( $a{-arg} eq "CE1") {
       @new_device_list = ( $CE0Name, $CE1Name );
   } else {
       @new_device_list = ( $CE1Name, $CE0Name );
   }

   $logger->debug(__PACKAGE__ . ".$sub : New device list @new_device_list");

   # Wait before destroying the object
   sleep 1;

   # After the switchover we have to get a new connection
   $sgx_object->DESTROY;
   $main::TESTBED{ "sgx4000:1:obj" } = undef;

   # Wait for few seconds for switchover
   sleep 5;

   # Connect back to SGX4000:1
   if ( $main::TESTBED{ "sgx4000:1:obj" } = SonusQA::SGX4000::SGX4000HELPER::connectAny( -devices => \@new_device_list, -debug => 1)) {
      $active_ce = $main::TESTBED{ $main::TESTBED{ "sgx4000:1:obj" }->{OBJ_HOSTNAME} };
      $logger->debug(__PACKAGE__ . ".$sub : Opened session object to $main::TESTBED{ $active_ce } \($active_ce\)");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub : Could not open session object to required SGX4000");
      return 0;
   }

   return $resetRetCode;
}

=head2 statCong

=over

=item DESCRIPTION:

    This subroutine processes trigger message from MGTS requesting congestion status from SGX

=item ARGUMENTS:

    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SGX4000::switchoverCE

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (statCong(-CEInfo        => $fields[3],
                     -arg           => $fields[4])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub statCong {
   my ($self, %args) = @_;

   my $sub = "statCong()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $result = 0;

   $result = $self->processSGXStatusRequest ( -noOfPatterns  => 2,
                                       -action        => "STAT",
                                       -command       => "S7DS",
                                       -arg           => $a{-arg},
                                       -attr          => "overAllPcStatus",
                                       -value         => "available",
                                       -attr1         => "overAllPcCongestionLevel",
                                       -value1        => 2);

   if($result eq 0)
   {
      #There is some thing wrong. Return from here
      return $result;
   }

   $result = $self->processSGXStatusRequest ( -noOfPatterns  => 1,
                                       -action        => "STAT",
                                       -command       => "S7DS",
                                       -arg           => $a{-arg},
                                       -attr          => "overAllUserPartAvailableList",
                                       -value         => "sccpTup");
   return $result;
}

=head2 lastRouteOos

=over

=item DESCRIPTION:

    This subroutine sets mode of last route to OOS

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -arg           => The argument for the command
    -attr          => The first attribute, whose value to be checked
    -value         => The value to be checked for the first attribute

=item PACKAGE:

    SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless (lastRouteOos(-command       => $fields[2],
                        -CEInfo        => $fields[3],
                        -arg           => $fields[4],
                        -attr          => $fields[5],
                        -value         => $fields[6])) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub lastRouteOos {
   my %args = @_;

   my $sub = "lastRouteOos()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Get the SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" };

   my $cmdString = "set ss7 route";
   # Append the requested argument
   $cmdString = $cmdString . " $a{-arg} $a{-attr} $a{-value}";
   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   my $retCode = 1;

   unless ( $sgx_object->enterPrivateSession()) {
      $logger->error(__PACKAGE__ . ".$sub:  Unable to enter config mode--\n @{$sgx_object->{CMDRESULTS}}" );
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   unless ( $sgx_object->execCliCmd($cmdString)) {
       $logger->debug(__PACKAGE__ . ".$sub Failed to execute the shell command:'$cmdString' --\n@{$sgx_object->{CMDRESULTS}}.");
       return 0;
   }

   unless ( $sgx_object->{conn}->print("commit"))
   {
        $logger->debug(__PACKAGE__ . ".$sub Failed to execute 'commit' command.");
        $retCode = 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Setting the prompt with \[yes,no\].");

   my ($prematch, $match);
   unless ( ($prematch, $match) = $sgx_object->{conn}->waitfor(
                                                           -match     => '/\[yes,no\]/i',
                                                           -match    => $sgx_object->{PROMPT},
                                                              ))
   {
       $logger->debug(__PACKAGE__ . ".$sub Unexpected prompt - after executing 'commit'.");
       $retCode = 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Checking the prompt: $match, expecting the '\[yes,no]'.");
   unless ( $match =~ m/\[yes,no\]/i ) {
        $logger->debug(__PACKAGE__ . ".$sub Unexpected prompt - after executing 'commit'.");
        $retCode = 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub Matched the fingerprint \[yes,no] prompt after 'commit'.");
   unless ( $sgx_object->execCliCmd("yes") ) {
        $logger->debug(__PACKAGE__ . ".$sub Failed to execute the shell command:'yes'--\n@{$sgx_object->{CMDRESULTS}}.");
        $retCode = 0;
   }

   unless ( $sgx_object->leaveConfigureSession ) {
        $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
        $retCode = 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub: Left the config private mode.");

   #  Return failure/false
   return $retCode;
}

=head2 processSGXRangeRequest

=over

=item DESCRIPTION:

    This subroutine checks status of all destinations within the specified range of point codes in SGX

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -startRange    => start of point code range
    -endRange       => end of point code range
    -status        => The status to be checked
    -conStatus     => The congestion level to be checked

=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::TRIGGER::getLinkRangeStatus
    SonusQA::TRIGGER::checkLinkRangeStat

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXRangeRequest (  -action        => $fields[1],
                                                                   -CEInfo         => $fields[2],
                                                                   -command        => $fields[3],
                                                                   -startRange     => $fields[4],
                                                                   -endRange       => $fields[5],
                                                                   -status         => $fields[6],
                                                                   -conStatus      => $fields[8],
                                                                   -protocolType   => $fields[9]) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processSGXRangeRequest {
   my ($self, %args) = @_;
   my $sub = "processSGXRangeRequest()";
   my %a = (-CEInfo      => "DEF");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $returnStat;
   unless ($returnStat = SonusQA::TRIGGER::getLinkRangeStatus(-startRange   => $a{-startRange},
                                                              -endRange     => $a{-endRange},
                                                              -getGsx      => 0,
                                                              -getPsx      => 0,
                                                              -protocolType => $a{-protocolType})) {
      $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
      print "Error in getting link status\n";
      return 0;
   }

   my %tempStatus = %{$returnStat};

   my $retCode;
   unless($retCode = SonusQA::TRIGGER::checkLinkRangeStat(-statusInfo => $returnStat,
                                                          -sgxStat     => $a{-status},
                                                          -sgxCon      => $a{-conStatus},
                                                          )) {
      $logger->error(__PACKAGE__ . ".$sub The link status is not in the expected state");
      print "Link status is not valid in the expected range\n";
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Returning with ----> [$retCode]");
   return $retCode;
}

=head2 processSGXWildCardRangeRequest

=over

=item DESCRIPTION:

    This subroutine checks status of all destinations matching the wildcard in SGX

=item ARGUMENTS:

    -command       => The command to be executed
    -CEInfo        => The CE where the command is executed CE0/CE1/DEF
    -pointcode1    => wild card string
    -status        => The status to be checked
    -conStatus     => The congestion level to be checked
    -exceptFlag    => 1 if except array is present else 0.
    -exceptArr     => The array of point codes to be excluded


=item PACKAGE:

  SonusQA::TRIGGER::SGXTRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::TRIGGER::getWildCharLinkRangeStatus
    SonusQA::TRIGGER::checkLinkRangeStatWithExcept
    SonusQA::TRIGGER::checkLinkRangeStat

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($self->processSGXWildCardRangeRequest (  -action        => $fields[1],
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

=back

=cut

sub processSGXWildCardRangeRequest {
   my ($self, %args) = @_;
   my $sub = "processSGXWildCardRangeRequest()";
   my %a = (-CEInfo      => "DEF", -exceptFlag  => 0);

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
                                                                         -getGsx      => 0,
                                                                         -getPsx      => 0)) {
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
                                                                          -sgxStat     => $a{-status},
                                                                          -sgxCon      => $a{-conStatus})) {
           $logger->error(__PACKAGE__ . ".$sub The link status is not in the expected state");
           return 0;
         }
      } else {
         unless($retCode = SonusQA::TRIGGER::checkLinkRangeStat(-statusInfo => $returnStat,
                                                                -sgxStat     => $a{-status},
                                                                -sgxCon      => $a{-conStatus},
                                                          )) {
            $logger->error(__PACKAGE__ . ".$sub The link status is not in the expected state");
            print "Link status is not valid in the expected range\n";
            return 0;
         }
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub Returning with ----> [$retCode]");
   return $retCode;
}

1;
