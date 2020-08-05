package SonusQA::TRIGGER;

=head1 NAME

SonusQA::TRIGGER

=head1 SYNOPSIS

use SonusQA::TRIGGER;

=head1 DESCRIPTION

SonusQA::TRIGGER This package/class contains those common subroutines which make up the interface between ATS
                 and external test equipment through the use of so-called 'trigger' messages.  This includes
                 setting up the listening socket, receiving messages via this socket and sending responses
                 back, as well as initial processing of the triggers.  This package then uses additional
                 packages, e.g. ./TRIGGER/SGXTRIGGER.pm to process the triggers for the individual DUTs.

=head1 AUTHORS

Susanth Sukumaran (ssukumaran@sonusnet.com)
Kevin Rodrigues (krodrigues@sonusnet.com)

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Exporter;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use SonusQA::MGTS;
use SonusQA::TRIGGER::GSXTRIGGER;
use SonusQA::TRIGGER::SGXTRIGGER;
use SonusQA::TRIGGER::COMMANDMAPTABLE;
use SonusQA::TRIGGER::PSXTRIGGER;
use POSIX qw(strftime);

our @ISA = qw(SonusQA::TRIGGER::GSXTRIGGER SonusQA::TRIGGER::SGXTRIGGER SonusQA::TRIGGER::PSXTRIGGER);

=head1 METHODS

=head2 createFiles

=over

=item DESCRIPTION:

    This subroutine create the remote hook log  and remote hook lock files in MGTS. The remote hook log file
    contains the trigger command sent to ATS and the response received. While the remote hook lock file
    is used to make sure that only one remote hook operation is happening at one time.

=item ARGUMENTS:

    The following arguments are defined default inside the subroutine. Use the arguments only if the
    default values to be overridden

    -delete      => Delete the existing file. The default value is set to delete the existing file

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS::cmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->createFiles( )) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not create remote hook related files on MGTS");
        return 0;
    }

=back

=cut

sub createFiles {
   my ($self, %args) = @_;
   my $sub = "createFiles()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   
   # Set default values before args are processed
   my %a = (-delete     => 1, );

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   my $remote_dir = $self->{LOG_DIR};

   my $logfile = "remoteHookLog.log";

   my $remote_path = $remote_dir . "/" . $logfile;

   unless ( $self->cmd( -cmd => "touch $remote_path" ) == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub : Failed to touch '$remote_path' on the MGTS");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   } else {
      $logger->debug(__PACKAGE__ . ".$sub : Remote hook log file on MGTS \"$remote_path\" exists");
   }                   
    
   $logfile = "fishHookLock";

   $remote_path = $remote_dir . "/" . $logfile;

   unless ( $self->cmd( -cmd => "touch $remote_path" ) == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub : Failed to touch '$remote_path' on MGTS");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   } else {
      $logger->debug(__PACKAGE__ . ".$sub : Fish hook lock file on MGTS \"$remote_path\" exists");
   }

   $logger->debug(__PACKAGE__ . ".$sub : Success - The required files are created");
   return 1;
}

=head2 setupTriggerSocket

=over

=item DESCRIPTION:

 This subroutine setups the remoteHook on the current ATS host machine for listening. The port is taken from the MGTS object variable $mgts_object->{FISH_HOOK_PORT}. The sub then makes a call to SonusQA::SOCK->new which opens the Socket. A reference to the socket is then returned.

=item ARGUMENTS:

    -object    => The item of test equipment which will be sending trigger messages.

=item PACKAGE:

 SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 $socket - Success
 0       - Failure

=item EXAMPLE:

SonusQA::TRIGGER::setupTriggerSocket( );

=back

=cut

sub setupTriggerSocket {

   my ($self, %args) = @_;
   my %a;

   my $sub_name = "setupTriggerSocket";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub_name, %a);

   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub"); 
  
   my ($fishhook_port, $listen_port_object);

   # Ensure fishHook port is specified on the MGTS object
   if ( $self->{FISH_HOOK_PORT} && $self->{FISH_HOOK_PORT} ne "" ) {
      $fishhook_port = $self->{FISH_HOOK_PORT};
      $logger->debug(__PACKAGE__ . ".$sub_name:  Setting up remote hook to use port $fishhook_port"); 
   } else {
      $logger->error(__PACKAGE__ . ".$sub_name:  Port is not set in \$self->{FISH_HOOK_PORT}. Please update TMS object for MGTS");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }

   # Open LISTEN port based on the FISH_HOOK_PORT
   unless ( $listen_port_object = SonusQA::SOCK->new (-port => $fishhook_port) ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  Cannot open remote hook port on port $fishhook_port");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }

   $self->{SOCK_INFO} = $listen_port_object;

   $logger->debug(__PACKAGE__ . ".$sub_name:  Opened remote hook on port $fishhook_port");
   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [obj:sock]"); 

   return 1;
}

=head2 writeFishHookToDatafiles

=over

=item DESCRIPTION:

 This function writes a file called fishHook to the MGTS user's datafiles directory. Inside this file is an IP address and a port number as:

 mgts-M500-1:/home/mgtsuser18/datafiles-122:> cat fishHook
 10.128.96.76
 7025
 mgts-M500-1:/home/mgtsuser18/datafiles-123:>  

 The fishHook is designed as a way in which the MGTS can communicate with ATS from with a state machine. On the MGTS machine an executable called remotehook will read the fishHook file and parse the IP and port. Once read a string will be sent via TCP to that port which can then be read by the user.

 The IP address is the local ATS machines IP address that the MGTS server can contact on the given port.

=item ARGUMENTS:

 -object    => The item of test equipment which will be sending trigger messages.

=item PACKAGE:

 SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 1 - Success
 0 - Failure

=item EXAMPLE:

SonusQA::TRIGGER::writeFishHookToDatafiles( );

=back

=cut


sub writeFishHookToDatafiles {

   my ($self, %args) = @_;
   my %a;

   my $sub_name = "writeFishHookToDatafiles";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub_name, %a);

   $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub"); 

   my ($fishhook_ip, $fishhook_port, $ping_ip);

   # Ensure host IP for MGTS is set, if not we cannot proceed--it maybe that this sub is not be called correctly
   unless ( $self->{OBJ_HOST} ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  \$self->{OBJ_HOST} is not set.");
      $logger->error(__PACKAGE__ . ".$sub_name:  Is this sub being called as \$obj->writeFishHookToDatafiles ???");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }

   # Ensure fishHook port is specified
   if ( $self->{FISH_HOOK_PORT} && $self->{FISH_HOOK_PORT} ne "" ) {
      $fishhook_port = $self->{FISH_HOOK_PORT};
      $logger->debug(__PACKAGE__ . ".$sub_name:  Set fishHook port to $fishhook_port"); 
   } else {
      $logger->error(__PACKAGE__ . ".$sub_name:  Port is not set in \$self->{FISH_HOOK_PORT}.");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }
    
   # Get local hostname IP address
   my @local_ip = &SonusQA::ATSHELPER::getIPFromLocalHost();
   unless ( @local_ip ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  No local IP addresses found.");                     
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }

   foreach ( @local_ip ) {
      # The below ping is NOT an ICMP ping, it relies on the connection to the remote echo port
      # if this is unavailable in the future, this will fail... right now though, we cool.
      $ping_ip = Net::Ping->new();

      if ( $ping_ip->ping( $self->{OBJ_HOST} )) {
         $logger->debug(__PACKAGE__ . ".$sub_name:  Local IP address $_ is reachable from the MGTS server \($self->{OBJ_HOST}\)");                     
         $fishhook_ip = $_; 
         $ping_ip->close();
         last;
      } else {
         $ping_ip->close();
      }
   } 

   unless ( $fishhook_ip ) {
      $logger->error(__PACKAGE__ . ".$sub_name:  No Local IP address-- @local_ip --can reach the MGTS server \($self->{OBJ_HOST}\)");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
      return 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub_name:  Writing fishHook to MGTS datafiles directory for $self->{OBJ_USER}"); 
   $logger->debug(__PACKAGE__ . ".$sub_name:  fishHook--IP: $fishhook_ip, PORT: $fishhook_port"); 

   # Now we know MGTS is reachable and we have the port number, we must populate the fishHook
   $self->cmd( -cmd => "echo \"$fishhook_ip\\n$fishhook_port\" > \$HOME/datafiles/fishHook" );

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]"); 
   return 1;
}

=head2 downloadRemoteHookLog 

=over

=item DESCRIPTION:

    This subroutine downloads the log file created by remotehook in MGTS

=item ARGUMENTS:

    -testId      => Test ID
    -logDir      => ATS log directory
    -timeStamp   => Test suite execution start time
    -variant     => test suite variant.
    The following arguments are defined default inside the subroutine. Use the arguments only if the
    default values to be overridden

    -delete      => Delete the existing file. 
                    0 - Do not delete the file
                    1 - Delete the file
                    The default value is set 1, to delete the existing file

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::MGTS:cmd

=item OUTPUT:

    0      - fail
    1      - True (Success)

=item EXAMPLE:

    unless ($mgts_object->downloadRemoteHookLog (-testId      => $testId,
                                                 -logDir      => $log_dir,
                                                 -variant     => $variant,
                                                 -timeStamp   => $timestamp)) {
        $logger->debug(__PACKAGE__ . ".$sub : Could not download remote hook log from MGTS");
        return 0;
    }

=back

=cut

sub downloadRemoteHookLog {

   my ($self, %args) = @_;

   my $sub = "downloadRemoteHookLog()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   my $userRequestedDelete = 0;

   # Check the user requested for the delete of log file
   if($args{-delete}) {
      $userRequestedDelete = 1;
   }


   unless ( defined $args{-variant} ) { $args{-variant} = "NONE"; }
   # Set default values before args are processed
   my %a = (-delete     => 1, );

   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
   $a{-timeStamp} = strftime "%Y%m%d-%H%M%S", localtime;
   $a{-remote_dir} = $self->{LOG_DIR};
   $a{-local_name} = "remoteHookLog_" . $a{-testId} . "_" . $a{-variant} . "_" . $a{-timeStamp} . ".log";
   $a{-logfile} = "remoteHookLog.log";

   my $local_path  = $a{-logDir} . "/" . $a{-local_name};
   my $remote_path = $a{-remote_dir} . "/" . $a{-logfile};

   unless ( $self->cmd( -cmd => "test -e $remote_path " ) == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub : Failed to find file '$remote_path' on local server");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   } else {
      $logger->debug(__PACKAGE__ . ".$sub : Remote hook Log file on MGTS \"$remote_path\" exists");
   }

   # Copy the MGTS log
   $logger->debug(__PACKAGE__ . ".$sub : Copying file '${remote_path}' to '$local_path'");
   unless ($self->cmd( -cmd => "cat ${remote_path}") == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub : Failed to cat MGTS log file '${remote_path}': $!");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (open(MGTSRMHKLOG,">${local_path}")) {
      $logger->error(__PACKAGE__ . ".$sub : Failed to open remote hook log on MGTS '$local_path' for writing");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   print MGTSRMHKLOG $self->{OUTPUT} . "\n";
   close(MGTSRMHKLOG);

   if ( $a{-delete} ) {
      # Remove MGTS log from MGTS server if -delete specified as 1
      $logger->debug(__PACKAGE__ . ".$sub : Deleting file '${remote_path}'");
      if ($self->cmd( -cmd => "rm -f ${remote_path}") ) {
         $logger->warn(__PACKAGE__ . ".$sub : Failed to remove remote hook log file from MGTS '${remote_path}': $!");

         # If user requested for delete, return error
         if($userRequestedDelete eq 1) {
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub : Success - Remote hook log is downloaded");
   return 1;
}

=head2 waitForTriggerMsg

=over

=item DESCRIPTION:

    This subroutine waits for a trigger message from MGTS

=item ARGUMENTS:

    -timeout             => Timeout for waiting for a trigger message from MGTS
    -customProcessMsg    => Reference to a function which will perform custom processing
                            on the received trigger message.  If not included then the
                            standard processing will occur.

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    SonusQA::SOCK::readFromRemote
    SonusQA::SOCK::sendToRemote

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

    unless (SonusQA::TRIGGER::waitForTriggerMsg(-timeout => $timeout)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub waitForTriggerMsg {
   my ($self, %args) = @_;
   my %a;
   my $sub = "waitForTriggerMsg()";
   my $resultStr = "FALSE";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   $logger->info(__PACKAGE__ . ".$sub Waiting for trigger message");

   # Wait on socket to receive trigger message
   my $inData = $self->{SOCK_INFO}->readFromRemote(-timeout => $a{-timeout});

   if( $inData ne "" && $inData ne "0" ) {
 
      $logger->info(__PACKAGE__ . ".$sub inData : " . Dumper ($inData) . "\n");
   
      if( $self->processTriggerMsg( -triggerMsg => $inData,
                                    -customProcessMsg => $a{-customProcessMsg} ) eq 1 ) {
        $resultStr = "TRUE";
      }
    
      $logger->info(__PACKAGE__ . ".$sub Sending \"$resultStr\" Back to MGTS");

      $self->{SOCK_INFO}->sendToRemote($resultStr);
    
      return 1;
   } else {
      $logger->warn(__PACKAGE__ . ".$sub: No message received from state machine before $a{-timeout} second timeout.");
      return 0;
   }
}

=head2 processTriggerMsg

=over

=item DESCRIPTION:

    This subroutine is the entry point for processing trigger messages received from the MGTS.

=item ARGUMENTS:

    -triggerMsg          => The trigger message string received from the MGTS.
    -customProcessMsg    => Reference to a function which will perform custom processing
                            on the received trigger message.  If not included then the
                            standard processing will occur.

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

    unless( processTriggerMsg( -triggerMsg => $triggerMsg ) ) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in processing trigger message");
        return 0;
    }

=back

=cut

sub processTriggerMsg {
   my ($self, %args) = @_;
   my %a;
  
   my $sub = "processTriggerMsg()";
   my $resultStr = "0";
   my $customFunc = "";
  
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  
   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
  
   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );
  
   my $inData = $a{-triggerMsg};
  
   $logger->info(__PACKAGE__ . ".$sub inData : " . Dumper ($inData) . "\n");
  
   chomp($inData);    # remove the "\n"
   $inData =~ s/^\s+//;   # remove leading spaces
   $inData =~ s/\s+$//;   # remove trailing spaces
  
   my $cmdInfo = $SonusQA::TRIGGER::COMMANDMAPTABLE::commandMapTable{$inData};
   
   $logger->info(__PACKAGE__ . ".$sub cmdInfo : " . Dumper ($cmdInfo) . "\n");
  
   # Check the result
   if( $cmdInfo ne "" )
   {
      # Retrieve the data in an array
      my @fields = split(' ', $cmdInfo);
   
      $logger->info(__PACKAGE__ . ".$sub fields : " . Dumper (@fields) . "\n");
   
      my $sizeofFields = scalar @fields;
      $logger->info(__PACKAGE__ . ".$sub sizeof fields : $sizeofFields");
   
      #added to introduce 250 ms delay before checking the status
      select(undef, undef, undef, 0.25);
   
      # Check the first field for device info
      if($fields[0] eq "SGX") {
         $logger->info(__PACKAGE__ . ".$sub Device is SGX");
    
         # Branch out to SGX to execute CLI

         if($fields[3] eq "SGXWILDCARD") {
            if($fields[9] eq "except") {
               $resultStr = $self->processSGX( -action        => $fields[1],
                                                                   -CEInfo         => $fields[2],
                                                                   -command        => $fields[3],
                                                                   -pointcode1     => $fields[4],
                                                                   -status         => $fields[6],
                                                                   -conStatus      => $fields[8],
                                                                   -exceptFlag     => 1,
                                                                   -exceptArr      => $fields[10]);
             } else {
               $resultStr = $self->processSGX( -action        => $fields[1],
                                                                   -CEInfo         => $fields[2],
                                                                   -command        => $fields[3],
                                                                   -pointcode1     => $fields[4],
                                                                   -status         => $fields[6],
                                                                   -conStatus      => $fields[8]);
            }
         } elsif($fields[3] eq "SGXRANGE") {
            $resultStr = $self->processSGX( -action        => $fields[1],
                                                                   -CEInfo         => $fields[2],
                                                                   -command        => $fields[3],
                                                                   -startRange     => $fields[4],
                                                                   -endRange       => $fields[5],
                                                                   -status         => $fields[6],
                                                                   -conStatus      => $fields[8],
                                                                   -protocolType   => $fields[9]);
         } elsif($sizeofFields eq 7) {
            # check one attribute
            $resultStr = $self->processSGX( -noOfPatterns  => 1,
                                                                   -action        => $fields[1],
                                                                   -CEInfo        => $fields[2],
                                                                   -command       => $fields[3],
                                                                   -arg           => $fields[4],
                                                                   -attr          => $fields[5],
                                                                   -value         => $fields[6]);
         } else {
            # check 2 attributes
            $resultStr = $self->processSGX(-noOfPatterns  => 2,
                                                                  -action        => $fields[1],
                                                                  -CEInfo        => $fields[2],
                                                                  -command       => $fields[3],
                                                                  -arg           => $fields[4],
                                                                  -attr          => $fields[5],
                                                                  -value         => $fields[6],
                                                                  -attr1         => $fields[7],
                                                                  -value1        => $fields[8]);
         }

         $logger->debug(__PACKAGE__ . ".$sub Checking SGX  Link Status \n");
         if ( %main::protocolPcHash ) {
             my ($key, $value, @pcList,$result );
             while ( ($key,$value) = each %main::protocolPcHash ){
               @pcList = @{$value};
               #push @allPcList,@pcList;

               unless ($result = checkStat( -pcList       => \@pcList,
                                            -protocolType => $key,
                                            -whichElement => $fields[0] )) {
                     $logger->info(__PACKAGE__ . ".$sub Error in  Checking SGX  Link Status ");
                     return 0;
               }
             }
         }

      } elsif($fields[0] eq "GSX") {
         $logger->info(__PACKAGE__ . ".$sub Device is GSX");
    
         # Branch out to GSX to execute CLI
         if($fields[2] eq "GSXWILDCARD") {
            if($fields[6] eq "except") {
               $resultStr = $self->processGSX( -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -pointcode1    => $fields[4],
                                                                  -status        => $fields[5],
                                                                  -exceptFlag    => 1,
                                                                  -exceptArr     => $fields[7]);
            } else {
               $resultStr = $self->processGSX( -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -pointcode1    => $fields[4],
                                                                  -status        => $fields[5]);
            }
         }elsif ($fields[2] eq "GSXRANGE") {
            $resultStr = $self->processGSX( -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -startRange     => $fields[4],
                                                                  -endRange       => $fields[5],
                                                                  -status         => $fields[6],
                                                                  -protocolType   => $fields[7]);
         } elsif($sizeofFields eq 6) {
            $resultStr = $self->processGSX(-noOfPatterns  => 1,
                                                                  -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -attr          => $fields[4],
                                                                  -value         => $fields[5]);
         } else {
            $resultStr = $self->processGSX(-noOfPatterns  => 2,
                                                                  -action        => $fields[1],
                                                                  -command       => $fields[2],
                                                                  -arg           => $fields[3],
                                                                  -attr          => $fields[4],
                                                                  -value         => $fields[5],
                                                                  -attr1         => $fields[6],
                                                                  -value1        => $fields[7]);
         }
      } elsif($fields[0] eq "PSX") {
        $logger->info(__PACKAGE__ . ".$sub Device is PSX");
        $logger->info(__PACKAGE__ . ".$sub point code is : $fields[3]");
        $resultStr = $self->processPSX(
                                       -action        => $fields[1],
                                       -arg           => $fields[3],
                                       -attr          => $fields[4],
                                       -value         => $fields[5]);
      } else {
        $logger->error(__PACKAGE__ . ".$sub Invalid Device type received : $fields[0]");
      }
   } elsif( ( $customFunc = $a{-customProcessMsg} ) ne "" ) {
      $resultStr = &$customFunc( -triggerMsg => $a{-triggerMsg} );
      $logger->info(__PACKAGE__ . ".$sub Trigger message processed by custom ");
   } else {
      $logger->error(__PACKAGE__ . ".$sub No command mapping exists for this string: $cmdInfo.");
   }
  
   return $resultStr;
}

=head2 getLinkRangeStatus

=over

=item DESCRIPTION:

    This subroutine gets the status from SGX, GSX and PSX for a range of point codes

=item ARGUMENTS:

   Mandatory :
      -startRange      => Point code start range
                          E.g., 1-1-2 for ANSI
                                2-1-1 for JAPAN 
      -endRange        => Point code end range
                          E.g., 1-1-8 for ANSI
                                8-1-1 for JAPAN 
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

      -CEInfo          => CE to be used
                          E.g., DEF,CE0,CE1
                          The default is set to "DEF"
      -gsxInfo         => GSX to be used
                          E.g., FIRST,SECOND
                          The default is set to "FIRST"

   Optional :
      -sgId            => SG ID to be used
                          E.g., 10, 11
                          The default is set to "NONE"
      -getSgx          => Get SGX status
                          1 => Get SGX status
                          0 => Do not get SGX status
                          Default value is 1
      -getPsx          => Get PSX status
                          1 => Get PSX status
                          0 => Do not get PSX status
                          Default value is 1
      -getGsx          => Get GSX status
                          1 => Get GSX status
                          0 => Do not get GSX status
                          Default value is 1

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, hash reference with the values collected from SGX,GSX and PSX

=item EXAMPLE:

   my $linkStat;

   Sample 1:
   ---------
   unless ($linkStat = SonusQA::TRIGGER::getLinkRangeStatus(-startRange   => "2-1-1",
                                                            -endRange     => "5-1-1",
                                                            -protocolType => "JAPAN")) {
      $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
      print "Error in getting link status\n";
      return 0;
   }

   Sample 2:
   ---------
   unless ($linkStat = SonusQA::TRIGGER::getLinkRangeStatus(-startRange   => "1-1-1",
                                                            -endRange     => "3-1-1",
                                                            -getSgx      => 0,
                                                            -protocolType => "JAPAN")) {
      $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
      print "Error in getting link status\n";
      return 0;
   }

=back

=cut

sub getLinkRangeStatus {
   my (%args) = @_;
   my $sub = "getLinkRangeStatus()";
   my %a = (-CEInfo      => "DEF",
            -gsxInfo     => "FIRST",
            -sgId        => "NONE",
            -getSgx      => 1,
            -getPsx      => 1,
            -getGsx      => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Check the required parameters are provided
   unless (defined $a{-startRange}) {
      $logger->error(__PACKAGE__ . ".$sub The start range is not provided");
      return 0;
   }

   unless (defined $a{-endRange}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   my %statusInfo;

   # Get the status info
   my $returnStat;

   unless ($returnStat = makeLinkRangeHash(-statusInfo     => \%statusInfo,
                                           -startRange     => $a{-startRange},
                                           -endRange       => $a{-endRange},
                                           -protocolType   => $a{-protocolType})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in making the hash table");
      return 0;
   }

   # Get SGX status
   if($a{-getSgx} eq 1) {
      unless($returnStat = getSGXLinkRangeStatus(-statusInfo => $returnStat,
                                                 -CEInfo     => $a{-CEInfo})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting SGX status");
         return 0;
      }
   }
   # Get GSX status
   if($a{-getGsx} eq 1) {
      unless($returnStat = getGSXLinkRangeStatus(-statusInfo   => $returnStat,
                                                 -gsxInfo      => $a{-gsxInfo},
                                                 -protocolType => $a{-protocolType})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting GSX status");
         return 0;
      }
   }
   # Get PSX status
   if($a{-getPsx} eq 1) {
      unless($returnStat = getPSXLinkRangeStatus(-statusInfo => $returnStat,
                                                 -sgId       => $a{-sgId}))  {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting PSX status");
         return 0;
      }
   }

   # Return the status as a hash table
   return $returnStat;
}

=head2 getWildCharLinkRangeStatus

=over

=item DESCRIPTION:

    This subroutine gets the status from SGX, GSX and PSX for a range indicated using wild chars

=item ARGUMENTS:

   Mandatory :
      -wildChar        => A wild char range
                          E.g.; "1-1-*"
                                "1-*-2"
                                "*-2-*"
                                "*-*-*"
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

   Optional :
      -CEInfo          => CE to be used
                          E.g., DEF,CE0,CE1
                          The default is set to "DEF"
      -gsxInfo         => GSX to be used
                          E.g., FIRST,SECOND
                          The default is set to "FIRST"

      -sgId            => SG ID to be used
                          E.g., 10, 11
                          The default is set to "NONE"
      -getSgx          => Get SGX status
                          1 => Get SGX status
                          0 => Do not get SGX status
                          Default value is 1
                          Note : Even though this flag is set to 0, we have to access SGX to get the
                          available point codes. When the flag is set 0, the point codes are taken
                          from SGX, but the SGX status is not returned to the user
      -getPsx          => Get PSX status
                          1 => Get PSX status
                          0 => Do not get PSX status
                          Default value is 1
      -getGsx          => Get GSX status
                          1 => Get GSX status
                          0 => Do not get GSX status
                          Default value is 1

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, hash reference with the values collected from SGX,GSX and PSX


=item EXAMPLE:

   unless ($linkStat = SonusQA::TRIGGER::getWildCharLinkRangeStatus(-wildChar   => "6-*-*",
                                                                    -protocolType => "JAPAN")) {
      $logger->error(__PACKAGE__ . ".$sub Error in getting link status");
      print "Error in getting link status\n";
      return 0;
   }

=back

=cut

sub getWildCharLinkRangeStatus {
   my (%args) = @_;
   my $sub = "getWildCharLinkRangeStatus()";
   my %a = (-CEInfo      => "DEF",
            -gsxInfo     => "FIRST",
            -sgId        => "NONE",
            -getSgx      => 1,
            -getPsx      => 1,
            -getGsx      => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Check the required parameters are provided
   unless (defined $a{-wildChar}) {
      $logger->error(__PACKAGE__ . ".$sub The Wild Char string is not provided");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   my %statusInfo;

   # Get the status info
   my $returnStat;

   unless ($returnStat = makeWildCharLinkRangeHash(-statusInfo     => \%statusInfo,
                                                   -wildChar       => $a{-wildChar},
                                                   -protocolType   => $a{-protocolType},
                                                   -CEInfo         => $a{-CEInfo})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in making the hash table");
      return 0;
   }

   # Get SGX status
   if($a{-getSgx} eq 1) {
      unless($returnStat = getSGXLinkRangeStatus(-statusInfo => $returnStat,
                                                 -CEInfo     => $a{-CEInfo})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting SGX status");
         return 0;
      }
   }
   # Get GSX status
   if($a{-getGsx} eq 1) {
      unless($returnStat = getGSXLinkRangeStatus(-statusInfo   => $returnStat,
                                                 -gsxInfo      => $a{-gsxInfo},
                                                 -protocolType => $a{-protocolType})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting GSX status");
         return 0;
      }
   }
   # Get PSX status
   if($a{-getPsx} eq 1) {
      unless($returnStat = getPSXLinkRangeStatus(-statusInfo => $returnStat,
                                                 -sgId       => $a{-sgId}))  {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting PSX status");
         return 0;
      }
   }

   # Return the status as a hash table
   return $returnStat;
}

=head2 makeLinkRangeHash

=over

=item DESCRIPTION:

    This subroutine makes the hash table used to get status of links

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => An empty hash table reference
      -startRange      => Point code start range
                          E.g., 1-1-2 for ANSI
                                2-1-1 for JAPAN
      -endRange        => Point code end range
                          E.g., 1-1-8 for ANSI
                                8-1-1 for JAPAN
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

   Optional :
      None

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, updated hash reference

=item EXAMPLE:

   unless ($returnStat = makeLinkRangeHash(-statusInfo     => \%statusInfo,
                                           -startRange     => $a{-startRange},
                                           -endRange       => $a{-endRange},
                                           -protocolType   => $a{-protocolType})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in making the hash table");
      return 0;
   }

=back

=cut

sub makeLinkRangeHash {
   my (%args) = @_;
   my $sub = "makeLinkRangeHash()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Check the required parameters are provided
   unless (defined $a{-startRange}) {
      $logger->error(__PACKAGE__ . ".$sub The start range is not provided");
      return 0;
   }

   unless (defined $a{-endRange}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   #Get the input hash data
   my %tempStatus = %{$args{-statusInfo}};

   # Get the start and end range
   my $startRange = $a{-startRange};
   my $endRange = $a{-endRange};

   #Get the start member
   my @tempArr = split(/-/, $startRange);
   my $startMemb;
   if($a{-protocolType} eq "JAPAN") {
      $startMemb = $tempArr[0];
   } else {
      $startMemb = $tempArr[2];
   }

   my $commString;
   if($a{-protocolType} eq "JAPAN") {
      # Get the common string -1-1
      $commString = "-$tempArr[1]-$tempArr[2]";
   } else {
      # Get the common string 1-1-
      $commString = "$tempArr[0]-$tempArr[1]-";
   }

   #Get the end member
   @tempArr = split(/-/, $endRange);
   my $endMemb;
   if($a{-protocolType} eq "JAPAN") {
      $endMemb = $tempArr[0];
   } else {
      $endMemb = $tempArr[2];
   }

   $logger->debug(__PACKAGE__ . ".$sub: startMemb => $startMemb, endMemb => $endMemb");

   # Initialize the hash table
   my $index = $startMemb;

   while ($index <= $endMemb) {
      # Make the point code string
      my $pointCode;
      if($a{-protocolType} eq "JAPAN") {
         $pointCode  = $index . $commString;
      } else {
         $pointCode  = $commString . $index;
      }
      $tempStatus{$pointCode}{SGX}{STATUS} = "Invalid";
      $tempStatus{$pointCode}{SGX}{CON_VALUE} = -1;

      push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");
      push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");

      $tempStatus{$pointCode}{PSX}{STATUS} = "Invalid";

      $index++;
   }

   $logger->debug(__PACKAGE__ . ".$sub: Completed the hash table" . Dumper(\%tempStatus));
   return \%tempStatus;
}

=head2 makeWildCharLinkRangeHash

=over

=item DESCRIPTION:

    This subroutine makes the hash table used to get status of links. The link information is retrieved from SGX

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => An empty hash table reference
      -wildChar        => A wild char range
                          E.g.; "1-1-*"
                                "1-*-2"
                                "*-2-*"
                                "*-*-*"
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

   Optional :
      -CEInfo          => CE to be used
                          E.g., DEF,CE0,CE1
                          The default is set to "DEF" 
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, updated hash reference

=item EXAMPLE:

   unless ($returnStat = makeWildCharLinkRangeHash(-statusInfo     => \%statusInfo,
                                                   -wildChar       => $a{-wildChar},
                                                   -protocolType   => $a{-protocolType},
                                                   -CEInfo         => $a{-CEInfo})) {
      $logger->error(__PACKAGE__ . ".$sub: Error in making the hash table");
      return 0;
   }

=back

=cut

sub makeWildCharLinkRangeHash {
   my (%args) = @_;
   my $sub = "makeWildCharLinkRangeHash()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   # Check the required parameters are provided
   unless (defined $a{-wildChar}) {
      $logger->error(__PACKAGE__ . ".$sub The Wild Char is not provided");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   #Get the input hash data
   my %tempStatus = %{$args{-statusInfo}};

   # Get the SGX object
   my $sgx_object;

   if(($a{-CEInfo} eq "DEF") or ($a{-CEInfo} eq "CE0")) {
      # use default or CE0. Taking CE0 will be always active before starting the test execution
      $sgx_object = $main::TESTBED{ "sgx4000:1:obj" } || $args{-sgxObj};
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
         $logger->error(__PACKAGE__ . ".$sub:  Connection attempt to $ce1Alias failed.");
         return 0;
      }
   } else {
      # there is a problem
      $logger->error (__PACKAGE__ . ".$sub Invalid CE specified");
      return 0;
   }

   # Make the command string
   my $cmdString = "show table ss7 destinationStatus";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # Execute the CLI
   unless($sgx_object->execCliCmd($cmdString)) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   my @tempArr = split (/-/, $a{-wildChar});

   my $skipLines = 0;
   my $line;
   my $matchCount;
   # Parse the output for the required string
   foreach $line ( @{ $sgx_object->{CMDRESULTS}} ) {
      if($skipLines eq 0) {
         if($line =~ m/--------/) {
            $skipLines = 1;
         }
         next;
      }

      # Get the values
      if ($line =~ m/\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\w+)\s+(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/) {
         my $overallPcStatus = $1;
         my $conValue = $2;
         my $pointCode = $3;

         $logger->info(__PACKAGE__ . ".$sub PC = $pointCode, OPC : $overallPcStatus, CV = $conValue");

         # Use wild char string to identify this is useful point code
         $matchCount = 0;
         my @tempPcArr = split (/-/, $pointCode);

         my $index = 0;
         while ($index <= 2) {
            if(($tempArr[$index] eq '*') or ($tempArr[$index] eq $tempPcArr[$index])){
               $matchCount++;
            } else {
               last;
            }
            $index++;
         }

         if ($matchCount eq 3) {
            $tempStatus{$pointCode}{SGX}{STATUS} = "Invalid";
            $tempStatus{$pointCode}{SGX}{CON_VALUE} = -1;

            push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");
            push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");

            $tempStatus{$pointCode}{PSX}{STATUS} = "Invalid";
         }
      }
   }
   $logger->debug(__PACKAGE__ . ".$sub: Completed the hash table" . Dumper(\%tempStatus));
   return \%tempStatus;
}

=head2 getSGXLinkRangeStatus

=over

=item DESCRIPTION:

    This subroutine gets the status from SGX for a range of point codes

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => A hash reference with keys set as range of point codes
                          Refer makeLinkRangeHash sub for more information

   Optional :
      -CEInfo          => CE to be used
                          E.g., DEF,CE0,CE1
                          The default is set to "DEF"
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, hash reference with the values collected from SGX

=item EXAMPLE:

   unless($returnStat = getSGXLinkRangeStatus(-statusInfo => \%statusInfo,
                                              -CEInfo     => $a{-CEInfo})) {
      $logger->error(__PACKAGE__ . ".$sub:  Error in getting SGX status");
      return 0;
   }

=back

=cut

sub getSGXLinkRangeStatus {
   my (%args) = @_;
   my $sub = "getSGXLinkRangeStatus()";
   my %a = (-CEInfo    => "DEF");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   #Get the input hash data
   my %tempStatus = %{$args{-statusInfo}};

   # Get the SGX object
   my $sgx_object;

   if(($a{-CEInfo} eq "DEF") or ($a{-CEInfo} eq "CE0")) {
      # use default or CE0. Taking CE0 will be always active before starting the test execution
      $sgx_object = $main::TESTBED{ "sgx4000:1:obj" } || $args{-sgxObj};
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
         $logger->error(__PACKAGE__ . ".$sub:  Connection attempt to $ce1Alias failed.");
         return 0;
      }
   } else {
      # there is a problem
      $logger->error (__PACKAGE__ . ".$sub Invalid CE specified");
      return 0;
   }

   # Make the command string
   my $cmdString = "show table ss7 destinationStatus";

   $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

   # Execute the CLI
   unless($sgx_object->execCliCmd($cmdString)) {
      $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
      return 0;
   }

   $logger->info(__PACKAGE__ . ".$sub Output : " . Dumper ($sgx_object->{CMDRESULTS}));

   my $skipLines = 0;
   my $line;
   # Parse the output for the required string
   foreach $line ( @{ $sgx_object->{CMDRESULTS}} ) {
      if($skipLines eq 0) {
         if($line =~ m/--------/) {
            $skipLines = 1;
         }
         next;
      }

      # Get the values
      if ($line =~ m/\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\w+)\s+(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/) {
         my $overallPcStatus = $1;
         my $conValue = $2;
         my $pointCode = $3;

         $logger->info(__PACKAGE__ . ".$sub PC = $pointCode, OPC : $overallPcStatus, CV = $conValue");
         #Check we require to save this point code information
          my $key;
          foreach $key (keys %tempStatus){
             if ($key eq $pointCode) {
                # Got the point code. Save the status
                $tempStatus{"$key"}{SGX}{STATUS} = $overallPcStatus;
                $tempStatus{"$key"}{SGX}{CON_VALUE} = $conValue;

                $logger->info(__PACKAGE__ . ".$sub Updated $key");
                last;
             }
          }
      }
   }

   # Return the updated hash reference
   return \%tempStatus;
}

=head2 getGSXLinkRangeStatus

=over

=item DESCRIPTION:

    This subroutine gets the status from GSX for a range of point codes

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => A hash reference with keys set as range of point codes
                          Refer makeLinkRangeHash sub for more information

      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

   Optional :
      -gsxInfo         => GSX to be used
                          E.g., FIRST,SECOND
                          The default is set to "FIRST"

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, hash reference with the values collected from GSX

=item EXAMPLE:

   unless($returnStat = getGSXLinkRangeStatus(-statusInfo   => $returnStat,
                                              -gsxInfo      => $a{-gsxInfo},
                                              -protocolType => $a{-protocolType})) {
      $logger->error(__PACKAGE__ . ".$sub:  Error in getting GSX status");
      return 0;
   }

=back

=cut

sub getGSXLinkRangeStatus {
   my (%args) = @_;
   my $sub = "getGSXLinkRangeStatus()";
   my %a = (-gsxInfo   => "FIRST");

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   # Check the mandatory arguments are provided
   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The end range is not provided");
      return 0;
   }

   my %tempStatus = %{$args{-statusInfo}};

   # Get the converted point codes
   my $key;
   my %convertedCodes;
   foreach $key (keys %tempStatus){
      my $pcInHex = getHexFromPC(-pointCode    => $key,
                                 -protocolType => $a{-protocolType});
      if($pcInHex eq 0) {
         $logger->error(__PACKAGE__ . ".$sub Error in converting point code");
         return 0;
      }
      $convertedCodes{"$key"} = $pcInHex;
   }
   my $gsx_session;

   # get the GSX object
   if($a{-gsxInfo} eq "FIRST") {
      $gsx_session = $main::TESTBED{ "gsx:1:obj" };
   }
   else {
      $gsx_session = $main::TESTBED{ "gsx:2:obj" };
   }

   # run the CLI
   my $cmdString = "admin debugSonus";

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

   my $skipLines = 0;
   my $line;

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
      # Get the point code and status
      if($line =~ m/\s+\S+\s+\S+\s+(\w+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\w+)\s+(\w+)\s+\S+\s+\S+/) {
         my $pointCode = $1;
         my $stat1 = $2;
         my $stat2 = $3;

         foreach $key (keys %convertedCodes) {
            if($convertedCodes{"$key"} eq $pointCode) {
               $tempStatus{"$key"}{GSX}{STATUS}[0] = $stat1;
               $tempStatus{"$key"}{GSX}{STATUS}[1] = $stat2;
               $logger->info(__PACKAGE__ . ".$sub : Updated $key with $stat1 and $stat2");
            }
         }
      }
   }

   return \%tempStatus;
}

=head2 getPSXLinkRangeStatus

=over

=item DESCRIPTION:

    This subroutine gets the status from PSX for a range of point codes

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => A hash reference with keys set as range of point codes
                          Refer getLinkRangeStatus sub for more information

   Optional :
      None

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    On success, hash reference with the values collected from PSX

=item EXAMPLE:

   unless($returnStat = getPSXLinkRangeStatus(-statusInfo => $returnStat))  {
      $logger->error(__PACKAGE__ . ".$sub:  Error in getting PSX status");
      return 0;
   }

=back

=cut

sub getPSXLinkRangeStatus {
   my (%args) = @_;
   my $sub = "getPSXLinkRangeStatus()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   # Check the mandatory arguments are provided
   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   my %tempStatus = %{$args{-statusInfo}};

   my $psx_object = $main::TESTBED{ "psx:1:obj" };

   my @temp = "17";

   my @pcStatus = $psx_object->scpamgmtStats(\@temp);

   $logger->debug(__PACKAGE__ . ".$sub: @pcStatus");

   my $line;
   my $skipLines = 0;
   # Check the requested pattern E.g., 1-1-40
   foreach $line (@pcStatus) {
      if ($skipLines eq 0) {
         if($line =~ m/----/) {
            $skipLines = 1;
         }
         next;
      }
      if ($line =~ m/SCPA Management Menu/) {
         # status over. comeout
         last;
      }
      if ($line =~ m/\S+\s+(\S+)\s+(\S+)\s+(\w+)/) {
         my $pointCode = $1;
         my $sgId = $2;
         my $status = $3;

         $logger->info(__PACKAGE__ . ".$sub: PC = $pointCode, STAT = $status, SGID = $sgId");
         #Check we require to save this point code information
          my $key;
          foreach $key (keys %tempStatus){
             if (($key eq $pointCode) && ($a{-sgId} eq "NONE")) {
                $tempStatus{"$key"}{PSX}{STATUS} = $status;

                $logger->info(__PACKAGE__ . ".$sub: Updated $key with $status");
                last;
             } elsif (($key eq $pointCode) && ($a{-sgId} eq $sgId)) {
                $tempStatus{"$key"}{PSX}{STATUS} = $status;
                $logger->info(__PACKAGE__ . ".$sub: Updated $key with $status");
                last;
             }
         }
      }
   }
   return \%tempStatus;
}

=head2 checkLinkRangeStat

=over

=item DESCRIPTION:

    This subroutine verifies the status

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => A hash reference with keys set as range of point codes
                          Refer getLinkRangeStatus sub for more information

   Optional :
      -sgxStat     => Required SGX status
                      Default value is "available"
      -sgxCon      => Required SGX congestion value
                      Default value is 0
      -gsxStat     => Required GSX status
                      Default value is "ava"
      -psxStat     => Required PSX status
                      Default value is "Available"

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - All the links are with the requested status

=item EXAMPLE:

   unless($returnStat = checkLinkRangeStat(-statusInfo => $returnStat))  {
      $logger->error(__PACKAGE__ . ".$sub: There is an issue with link status");
      return 0;
   }

=back

=cut

sub checkLinkRangeStat {
   my (%args) = @_;
   my $sub = "checkLinkRangeStat()";
   my %a = ( -sgxStat     => "available",
             -sgxCon      => 0,
             -gsxStat     => "ava",
             -psxStat     => "Available"
           );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   # Check the mandatory arguments are provided
   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   my $retCode = 1;
   my %tempStatus = %{$args{-statusInfo}};

   $logger->debug(__PACKAGE__ . ".$sub \n " . Dumper(\%tempStatus));

   my $key;
   foreach $key (keys %tempStatus){
      if(($tempStatus{"$key"}{SGX}{STATUS} ne $a{-sgxStat} ) and
         ($tempStatus{"$key"}{SGX}{STATUS} ne "Invalid")){
         $logger->error(__PACKAGE__ . ".$sub SGX status not matching : $key");
         $retCode = 0;
         last;
      }
      if(($tempStatus{"$key"}{SGX}{CON_VALUE} != $a{-sgxCon}) and
         ($tempStatus{"$key"}{SGX}{STATUS} ne "Invalid")){
         $logger->error(__PACKAGE__ . ".$sub SGX Congestion not matching : $key");
         $retCode = 0;
         last;
      }
      if(($tempStatus{"$key"}{GSX}{STATUS}[0] ne $a{-gsxStat} ) and 
         ($tempStatus{"$key"}{GSX}{STATUS}[0] ne "Invalid")){
         $logger->error(__PACKAGE__ . ".$sub GSX status not matching : $key");
         $retCode = 0;
         last;
      }
      if(($tempStatus{"$key"}{GSX}{STATUS}[1] ne $a{-gsxStat} ) and
         ($tempStatus{"$key"}{GSX}{STATUS}[1] ne "Invalid")) {
         $logger->error(__PACKAGE__ . ".$sub GSX status not matching : $key");
         $retCode = 0;
         last;
      }
      if(($tempStatus{"$key"}{PSX}{STATUS} ne $a{-psxStat} ) and 
         ($tempStatus{"$key"}{PSX}{STATUS} ne "Invalid")) {
         $logger->error(__PACKAGE__ . ".$sub PSX status not matching : $key");
         $retCode = 0;
         last;
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub Returning with ----> [$retCode]");
   return $retCode;
}

=head2 checkLinkRangeStatWithExcept

=over

=item DESCRIPTION:

    This subroutine verifies the status. This is similar to checkLinkRangeStat subroutine,
    except that, here a set of given point codes are excepted from checking the status

=item ARGUMENTS:

   Mandatory :
      -statusInfo      => A hash reference with keys set as range of point codes
                          Refer getLinkRangeStatus sub for more information
      -exceptArr       => Reference to except point code array
                          E.g. ("1-1-2", "1-*-*")

   Optional :
      -sgxStat     => Required SGX status
                      Default value is "available"
      -sgxCon      => Required SGX congestion value
                      Default value is 0
      -gsxStat     => Required GSX status
                      Default value is "ava"
      -psxStat     => Required PSX status
                      Default value is "Available"

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - All the links are with the requested status

=item EXAMPLE:

   my @exceptArr = ("1-1-2", "1-*-*");
   unless($returnStat = checkLinkRangeStatWithExcept(-statusInfo => $returnStat,
                                                     -exceptArr  => \@exceptArr))  {
      $logger->error(__PACKAGE__ . ".$sub: There is an issue with link status");
      return 0;
   }

=item Note:

   This API looks at all the destinations in the table including the adjacent 
   destinations (STPs). If user wants the STPs to be excluded, then they have 
   to include the STP point codes in the exception list as appropriate.

   Example: User wants to check all destinations except x-x-x are unavailable. 
   But STPs will always be available. So the exception list will be 
   (x-x-x, stp1 pc, stp2 pc).

=back

=cut

sub checkLinkRangeStatWithExcept {
   my (%args) = @_;
   my $sub = "checkLinkRangeStatWithExcept()";
   my %a = ( -sgxStat     => "available",
             -sgxCon      => 0,
             -gsxStat     => "ava",
             -psxStat     => "Available"
           );

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   # Check the mandatory arguments are provided
   unless (defined $a{-statusInfo}) {
      $logger->error(__PACKAGE__ . ".$sub Point code hash is not available");
      return 0;
   }

   unless (defined $a{-exceptArr}) {
      $logger->error(__PACKAGE__ . ".$sub Except Point code array is not available");
      return 0;
   }

   my %tempStatus = %{$args{-statusInfo}};
   my @inArr = @{$args{-exceptArr}};

   $logger->debug(__PACKAGE__ . ".$sub \n " . Dumper(\%tempStatus));

   # First get the point codes to be removed
   my @removePcs;

   my $pc;
   foreach $pc (keys %tempStatus){
      my @pcArr = split (/-/, $pc);
      my $exceptPc;
      my $matchCount;
      foreach $exceptPc (@inArr) {
         my @tempArr = split (/-/, $exceptPc);
         my $index = 0;
         $matchCount = 0;
         my $tempString = "";
         while ($index <= 2) {
            if(($tempArr[$index] eq '*') or ($tempArr[$index] eq $pcArr[$index])){
               if($index eq 0) {
                  $tempString = $pcArr[$index];
               } else {
                  $tempString .= "-" . $pcArr[$index];
               }
               $matchCount++;
            } else {
               last;
            }
            $index++;
         }
         if ($matchCount eq 3) {
            push (@removePcs, $tempString);
         }
      }
   }

   # remove the point codes from the hash
   $logger->debug(__PACKAGE__ . ".$sub removing point codes @removePcs");

   foreach $pc (@removePcs) {
      delete ($tempStatus{"$pc"});
   }

   # Now check the status
   my $retCode = checkLinkRangeStat(-statusInfo => \%tempStatus,
                                    -sgxStat    => $a{-sgxStat},
                                    -sgxCon     => $a{-sgxCon},
                                    -gsxStat    => $a{-gsxStat},
                                    -psxStat    => $a{-psxStat} );

   return $retCode;
}

=head2 getHexFromPC

=over

=item DESCRIPTION:

    This subroutine converts the point code to the hex equivalent

=item ARGUMENTS:

   Mandatory :
      -pointCode        => Point code
                          E.g., 1-1-2 for ANSI
                                2-1-1 for JAPAN
      -protocolType    => Protocol Type
                          E.g., ANSI,ITU,JAPAN

   Optional :
      None

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    The hex equivalent to the given point code

=item EXAMPLE:

      my $pcInHex = getHexFromPC(-pointCode    => $key,
                                 -protocolType => $a{-protocolType});
      if($pcInHex eq 0) {
         $logger->error(__PACKAGE__ . ".$sub Error in converting point code");
         return 0;
      }

=back

=cut

sub getHexFromPC {
   my (%args) = @_;
   my $sub = "getHexFromPC()";
   my %a;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-pointCode}) {
      $logger->error(__PACKAGE__ . ".$sub The Point Code is not provided");
      return 0;
   }

   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The Protocol type is not provided");
      return 0;
   }

   my @tempArr = split (/-/, $a{-pointCode});
   my $pcInHex;

   if (($a{-protocolType} eq "ANSI") or ($a{-protocolType} eq "CHINA")) {
      # Change to Hex
      my $net = sprintf("%x", $tempArr[0]);
      my $clu = sprintf("%02x", $tempArr[1]);
      my $mem = sprintf("%02x", $tempArr[2]);

      # Make the string
      $pcInHex = "$net$clu$mem";
   } elsif ($a{-protocolType} eq "JAPAN") {
      # Get binary
      my $str = unpack("B32", pack("N", $tempArr[0]));
      my $str1 = unpack("B32", pack("N", $tempArr[1]));
      my $str2 = unpack("B32", pack("N", $tempArr[2]));

      # Take the required bits
      my @pcArr;
      $str =~ m/\d{25}(\d{7})/;
      $pcArr[0] = $1;

      $str1 =~ m/\d{28}(\d{4})/;
      $pcArr[1] = $1;

      $str2 =~ m/\d{27}(\d{5})/;
      $pcArr[2] = $1;

      # Make the binay string
      my $pcBin = $pcArr[0].$pcArr[1].$pcArr[2];

      # Convert to hex
      my $int = unpack("N", pack("B32", substr("0" x 32 . $pcBin, -32)));
      $pcInHex = sprintf("%x", $int );
   } elsif (($a{-protocolType} eq "ITU" ) or ($a{-protocolType} eq "BT7" )) {
      # Get binary
      my $str = unpack("B32", pack("N", $tempArr[0]));
      my $str1 = unpack("B32", pack("N", $tempArr[1]));
      my $str2 = unpack("B32", pack("N", $tempArr[2]));

      # Take the required bits
      my @pcArr;
      $str =~ m/\d{29}(\d{3})/;
      $pcArr[0] = $1;

      $str1 =~ m/\d{24}(\d{8})/;
      $pcArr[1] = $1;

      $str2 =~ m/\d{29}(\d{3})/;
      $pcArr[2] = $1;

      # Make the binary string
      my $pcBin = $pcArr[0].$pcArr[1].$pcArr[2];

      # Convert to hex
      my $int = unpack("N", pack("B32", substr("0" x 32 . $pcBin, -32)));
      $pcInHex = sprintf("%x", $int );
   } else {
      $logger->error(__PACKAGE__ . ".$sub Invalid protocol type specified");
      return 0;
   }
   
   $logger->debug(__PACKAGE__ . ".$sub protocolType => $a{-protocolType}, $a{-pointCode} => $pcInHex");
   return $pcInHex;
}

=head2 checkM3uaInternalStatus

=over

=item DESCRIPTION:

    This subroutine checks and corrects the status of Associations and links

=item ARGUMENTS:

   Mandatory :
      -sctpAssocNames        => Reference to an array of SCT Association Names to be checked
      -m3uaSgpLinkNames      => Reference to an array of M3UA SGP Link Names to be checked

   Optional :
      -doConfig              => Correct the status
                                1 - Do config
                                0 - No config. Just check the status and report
                                Default => 1

      -sgxId                 => 1 or 2 (check the config status for first or second sgx)
                                Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)
      None

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

   my @sctpAssocNames = ("gsxGROVERCE0Active", "gsxGROVERCE1Active");
   my @m3uaSgpLinkNames = ("gsxGROVERCE0Active", "gsxGROVERCE1Active");

   $retCode = SonusQA::TRIGGER::checkM3uaInternalStatus(-sctpAssocNames     => \@sctpAssocNames,
                                                        -m3uaSgpLinkNames   => \@m3uaSgpLinkNames);

=back

=cut

sub checkM3uaInternalStatus {
   my (%args) = @_;
   my $sub = "checkM3uaInternalStatus()";
   my %a = (-doConfig => 1,
            -sgxId    => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-sctpAssocNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SCTP Association Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-m3uaSgpLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to M3UA SGP Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   my $doConfig = $a{-doConfig};

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   # Do 2 times. First correct the status if failed. Second time, only check the status and
   # return
   my $index = 0;
   my %statInfo;
   my $retStatus;
   my @assocNames = @{$a{-sctpAssocNames}};
   my @sgpLinkNames = @{$a{-m3uaSgpLinkNames}};
   my $retCode;
   my $checkAgain = 0;

   $logger->debug(__PACKAGE__ . ".$sub :************TEST BED STATUS CHECK STARTED FOR M3UA INTERNAL******************");
   while ($index < 2) {
      ##############################################################################################
      # Check Sigtran SCTP Association
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SIGTR_SCTP",
                                                -names         => \@assocNames,
                                                -doConfig      => $doConfig,
                                                -sgxId         => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: Sigtran SCTP Association check fails");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      ##############################################################################################
      # Check M3UA SGP link
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "M3UA_SGP_LINK",
                                                -names         => \@sgpLinkNames,
                                                -doConfig      => $doConfig,
                                                -sgxId	       => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: M3UA SGP link check fails");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      # Do it only once. The called sub waits for status change
      if($index eq 0) {
         ##############################################################################################
         # Check Sigtran SCTP Association Status
         ##############################################################################################
         unless ($retCode = checkM3uaSuaIntStatus(-tableInfo     => "SIGTR_SCTP_STAT",
                                                  -names         => \@assocNames,
                                                  -status        => "established",
                                                  -type          => "M3UA",
                                                  -doConfig      => $doConfig,
                                                  -sgxId         => $a{-sgxId})) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: Sigtran SCTP Association Status check fails");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }


         ##############################################################################################
         # Check M3UA SGP link Status
         ##############################################################################################
         unless ($retCode = checkM3uaSuaIntStatus(-tableInfo     => "M3UA_SGP",
                                                  -names         => \@sgpLinkNames,
                                                  -status        => "linkStateUp",
                                                  -doConfig      => $doConfig,
                                                  -sgxId         => $a{-sgxId})) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: M3UA SGP link Status check fails");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      #If config is done, better check the status once again
      if(($checkAgain eq 0) or ($doConfig eq 0)){
         # Config is not done. Just finish it
         last;
      }

      $doConfig = 0;
      $index++;
   }
   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK FINISHED FOR M3UA INTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK PASSED FOR M3UA INTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head2 checkSuaInternalStatus

=over

=item DESCRIPTION:

    This subroutine checks and corrects the status of Associations and links

=item ARGUMENTS:

   Mandatory :
      -sctpAssocNames        => Reference to an array of SCT Association Names to be checked
      -suaSgpLinkNames       => Reference to an array of SUA SGP Link Names to be checked

   Optional :
      -doConfig              => Correct the status
                                1 - Do config
                                0 - No config. Just check the status and report
                                Default => 1
      -sgxId                 => 1 or 2 (check the config status for first or second sgx)
                                Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

   my @sctpAssocNames = ("psxJupiterCE0", "psxJupiterCE1");
   my @suaSgpLinkNames = ("psxJupiterCE0", "psxJupiterCE1");

   $retCode = SonusQA::TRIGGER::checkSuaInternalStatus(-sctpAssocNames     => \@sctpAssocNames,
                                                        -suaSgpLinkNames   => \@suaSgpLinkNames);

=back

=cut

sub checkSuaInternalStatus {
   my (%args) = @_;
   my $sub = "checkSuaInternalStatus()";
   my %a = (-doConfig => 1,
            -sgxId    => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-sctpAssocNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SCTP Association Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-suaSgpLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SUA SGP Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   my $doConfig = $a{-doConfig};

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   # Do 2 times. First correct the status if failed. Second time, only check the status and
   # return
   my $index = 0;
   my %statInfo;
   my $retStatus;
   my @assocNames = @{$a{-sctpAssocNames}};
   my @sgpLinkNames = @{$a{-suaSgpLinkNames}};
   my $retCode;
   my $checkAgain = 0;

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK STARTED FOR SUA INTERNAL******************");
   while ($index < 2) {
      ##############################################################################################
      # Check Sigtran SCTP Association
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SIGTR_SCTP",
                                                -names         => \@assocNames,
                                                -doConfig      => $doConfig,
                                                -sgxId         => $a{-sgxId},
                                                -sgxObj        => $args{-sgxObj})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: Sigtran SCTP Association check fails");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR SUA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      ##############################################################################################
      # Check SUA SGP link
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SUA_SGP_LINK",
                                                -names         => \@sgpLinkNames,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId         => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: SUA SGP link check fails");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR SUA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      # Do it only once. The called sub waits for status change
      if($index eq 0) {
         ##############################################################################################
         # Check Sigtran SCTP Association Status
         ##############################################################################################
         unless ($retCode = checkM3uaSuaIntStatus(-tableInfo     => "SIGTR_SCTP_STAT",
                                                  -names         => \@assocNames,
                                                  -status        => "established",
                                                  -type          => "SUA",
                                                  -doConfig      => $doConfig,
                                                  -sgxObj        => $args{-sgxObj},
                                                  -sgxId         => $a{-sgxId})) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: Sigtran SCTP Association Status check fails");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR SUA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }

         ##############################################################################################
         # Check SUA SGP link Status
         ##############################################################################################
         unless ($retCode = checkM3uaSuaIntStatus(-tableInfo     => "SUA_SGP",
                                                  -names         => \@sgpLinkNames,
                                                  -status        => "linkStateUp",
                                                  -doConfig      => $doConfig,
                                                  -sgxObj        => $args{-sgxObj},
                                                  -sgxId         => $a{-sgxId})) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: SUA SGP link Status check fails");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR SUA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      #If config is done, better check the status once again
      if(($checkAgain eq 0) or ($doConfig eq 0)){
         # Config is not done. Just finish it
         last;
      }

      $doConfig = 0;
      $index++;
   }

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK FINISHED FOR SUA INTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK PASSED FOR SUA INTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head2 checkSgxTabEntryStatus

=over

=item DESCRIPTION:

    This subroutine  checks the status of given entry in the table

=item ARGUMENTS:

   Mandatory :
      -names        => Reference to an array of Names to be checked
      -tableInfo    => Table information
                       Refer SGX4000::SGX4000HELPER::getSgxTableStat

   Optional :
      -state        => State value
                       Default is "enabled"
      -mode         => Mode value
                       Default is "inService"
      -doConfig     => Correct the status
                       1 - Do config
                       0 - No config
                       Default => 0
      -sgxId        => 1 or 2 (check the config status for first or second sgx)
                       Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SIGTR_SCTP",
                                                -names         => \@assocNames,
                                                -doConfig      => $doConfig)) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         return 0;
      }

=back

=cut

sub checkSgxTabEntryStatus {
   my (%args) = @_;
   my $sub = "checkSgxTabEntryStatus()";
   my %a = (-state    => "enabled",
            -mode     => "inService",
            -doConfig => 0,
            -sgxId    => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-names}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to Names is not provided");
      return 0;
   }

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   my %statInfo;
   my $retStatus;
   my $retCode;
   my $retValue = 1;



   my @names = @{$a{-names}};
   my $name;
   my $checkAll = 0;
   foreach $name (@names) {
   
      # Get the current status
 if(defined $a{-checkSpecific} and $a{-checkSpecific} == 1 ){
               # Get the current status
                       unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                                         -checkSpecific=> $name,
                                                                         -statusInfo   => \%statInfo)) {
                        $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
                          return 0;
                        }
               }else{
                if($checkAll == 0){
                   unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                                 -statusInfo   => \%statInfo)) {
                   $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
                   return 0;
                   }
                  $checkAll = 1;
                 }
                }
      #Check the name exists
      unless (defined ($retStatus->{$name})) {
         $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$name\'. Its not part of the display");
         return 0;
      }
      #Check the status
      if($retStatus->{$name}->{"STATE"} ne $a{-state}) {
         $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$a{-state}\'");
         #Check we have to correct the status
         if($a{-doConfig} eq 1) {
            unless ($retCode = $sgx_object->setModeIsv(-tableInfo    => $a{-tableInfo},
                                                         -name         => $name,
                                                         -setState     => 1)) {
               $logger->error(__PACKAGE__ . ".$sub: Error in setting required status");
               return 0;
            }
            $retValue = 2;
         } else {
            return 0;
         }
      } elsif($retStatus->{$name}->{"MODE"} ne $a{-mode}) {
         #Check we have to correct the status
         if($a{-doConfig} eq 1) {
            $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$a{-mode}\'");
            unless ($retCode = $sgx_object->setModeIsv(-tableInfo    => $a{-tableInfo},
                                                         -name         => $name,
                                                         -setState     => 0)) {
               $logger->error(__PACKAGE__ . ".$sub: Error in setting required status");
               return 0;
            }
            $retValue = 2;
         } else {
            $logger->error(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$a{-mode}\'");
            return 0;
         }
      } else {
         $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is in \'$a{-state}\' and \'$a{-mode}\'");
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub: returning from sub with $retValue");
   return $retValue;
}

=head2 checkM3uaSuaIntStatus

=over

=item DESCRIPTION:

    This subroutine checks the status of given entry in the table

=item ARGUMENTS:

   Mandatory :
      -names        => Reference to an array of Names to be checked
      -tableInfo    => Table information
                       Refer SGX4000::SGX4000HELPER::getSgxTableStat
      -status       => Status value

   Optional :
      -doConfig     => Correct the status
                       1 - Do config
                       0 - No config
                       Default => 0
      -sgxId        => 1 or 2 (check the config status for first or second sgx)
                       Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLE SUSED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

         unless ($retCode = checkM3uaSuaIntStatus(-tableInfo     => "SIGTR_SCTP_STAT",
                                                  -names         => \@assocNames,
                                                  -status        => "established",
                                                  -type          => "SUA",
                                                  -doConfig      => $doConfig)) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            return 0;
         }

=back

=cut

sub checkM3uaSuaIntStatus {
   my (%args) = @_;
   my $sub = "checkM3uaSuaIntStatus()";
   my %a = (-doConfig => 0,
            -sgxId    => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-names}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj}) ) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   my %statInfo;
   my $retStatus;
   my $retCode;
   my $retValue = 1;

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK STARTED FOR M3UA SUA INTERNAL******************");
   # Get the current status
   unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                     -statusInfo   => \%statInfo)) {
      $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
      $logger->error(__PACKAGE__ . ".$sub: unable to get current sgx table status");
      $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   my %tabStatInfo;
   my $tabRetStatus;

   # Get the required information once here
   if($a{-tableInfo} eq "SIGTR_SCTP_STAT") {
      my $linkTable;
      if($a{-type} eq "SUA") {
         $linkTable = "SUA_SGP_LINK";
      } elsif ($a{-type} eq "M3UA") {
         $linkTable = "M3UA_SGP_LINK";
      } else {
         $logger->error(__PACKAGE__ . ".$sub: Invalid type parameter");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # Get the current status
      unless ($tabRetStatus = $sgx_object->getSgxTableStat(-tableInfo    => $linkTable,
                                                           -statusInfo   => \%tabStatInfo)) {
         $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
         $logger->error(__PACKAGE__ . ".$sub: unable to get current status for $linkTable");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my @names = @{$a{-names}};
   my $name;

   foreach $name (@names) {
      #Check the name exists
      unless (defined ($retStatus->{$name})) {
         $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$name\'. Its not part of the display");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
      #Check the status
      if($retStatus->{$name}->{"STATUS"} ne $a{-status}) {
         #Check we have to correct the status
         if($a{-doConfig} eq 1) {
            $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$a{-status}\'");
            # Get Link Name
            my $linkName;
            # For SCTP assoc, get the link name from link table for the corresponding Assoc
            if($a{-tableInfo} eq "SIGTR_SCTP_STAT") {
               my $found = 0;
               my $tempName;
               foreach $tempName (keys %tabStatInfo) {
                  if($tabStatInfo{$tempName}->{"ASSOC_NAME"} eq $name) {
                     $found = 1;
                     $logger->debug(__PACKAGE__ . ".$sub: for assoc \'$name\' link is \'$tempName\'");
                     $linkName = $tempName;
                     last;
                  }
               }
               if($found eq 0) {
                  $logger->error(__PACKAGE__ . ".$sub: unable to find link for assoc \'$name\'");
                  $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
                  $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
                  return 0;
               }
            } else {
               $linkName = $name;
               if($a{-tableInfo} =~ /SUA_SGP/ ) {
                  $a{-type} = "SUA";
               } else {
                  $a{-type} = "M3UA";
               }
            }
    
            my @cmdStrings;
            if($a{-type} eq "SUA") {
               push(@cmdStrings, "set sua sgpLink $linkName mode outOfService");
               push(@cmdStrings, "set sua sgpLink $linkName mode inService");
            } elsif ($a{-type} eq "M3UA") {
               push(@cmdStrings, "set m3ua sgpLink $linkName mode outOfService");
               push(@cmdStrings, "set m3ua sgpLink $linkName mode inService");
            }

            $logger->debug(__PACKAGE__ . ".$sub: Entering the config private mode.");
            unless ($sgx_object->enterPrivateSession() ) {
               $logger->error(__PACKAGE__ . ".$sub:  Failed to enter config mode.");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }

            # Make the SGP link OOS and then ISV
            $logger->debug(__PACKAGE__ . ".$sub: Executing @cmdStrings ");
            unless ($sgx_object->execCommitCliCmdConfirm(@cmdStrings)) {
               unless ($sgx_object->leaveConfigureSession) {
                  $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
               }
               $logger->error(__PACKAGE__ . ".$sub:  Failed to execute @cmdStrings.");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }

            unless ($sgx_object->leaveConfigureSession) {
               $logger->error(__PACKAGE__ . ".$sub:  Failed to leave config mode.");
            }

            $logger->debug(__PACKAGE__ . ".$sub: Left the config private mode.");

            $retValue = 2;
         } else {
            $logger->error(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$a{-status}\'");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }
   }
   # Now wait and check the status is changed
   if($retValue eq 2) {
      # wait for some time till Assoc or link is up
      sleep 10;
      my $index = 0;
      while($index < 5) {
         my %tempStatInfo;
         # Get the current status
         unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $a{-tableInfo},
                                                           -statusInfo   => \%tempStatInfo)) {
            $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
            $logger->error(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
         
         my $goodStat = 1;
         foreach $name (@names) {
            if($retStatus->{$name}->{"STATUS"} ne $a{-status}) {
               $goodStat = 0;
               last;
            }
         }
         if($goodStat eq 0) {
            sleep 10;
            $index++;
            $logger->error(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK FAILED FOR M3UA SUA INTERNAL******************");
            $retValue = 0;
         } else {
            $logger->debug(__PACKAGE__ . ".$sub: all the links are in good state");
            $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK PASSED FOR M3UA SUA INTERNAL******************");
            $retValue = 1;
            last;
         }
	}
   }
   
   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK FINISHED FOR M3UA SUA INTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub: returning from sub with $retValue");
   return $retValue;
}

=head2 mgtsDwnldAndRun

=over

=item DESCRIPTION:

    This subroutine downloads the assignment and runs a set of state machines

=item ARGUMENTS:

   Mandatory :
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                   If -skipDwnld is '1', the node names are retrieved from this
      -logDir                   => ATS log directory
      -testId                   => Test Case ID


   Optional :
      -skipDwnld                => Flag to indicate Assignment download
                                   0 - Download the assignment
                                   1 - Do Not download the assignment. Only run the state machines
                                   The Default value is 0

      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

         unless ($retCode = mgtsDwnldAndRun(-mgtsInfo         => \%mgtsInfo,
                                            -assignment       => $a{-assignment},
                                            -skipDwnld        => 0,
                                            -logDir           => $a{-logDir},
                                            -timeStamp        => $a{-timeStamp},
                                            -doNotLogMGTS     => $a{-doNotLogMGTS},
                                            -variant          => $a{-variant},
                                            -testId           => $a{-testId},
                                           )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            return 0;
         }

    or

         $retCode = mgtsDwnldAndRun(-skipDwnld        => 1,
                                    -mgtsInfo         => \%mgtsInfo,
                                    -assignment       => $a{-assignment},
                                    -logDir           => $a{-logDir},
                                    -timeStamp        => $a{-timeStamp},
                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                    -variant          => $a{-variant},
                                    -testId           => $a{-testId},
                                   );

=back

=cut

sub mgtsDwnldAndRun {
   my (%args) = @_;
   my $sub = "mgtsDwnldAndRun()";
   my %a = (-skipDwnld        => 0,
            -doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -mgtsNumber       => 1 ); 

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-mgtsInfo}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
      return 0;
   }

   unless (defined $a{-logDir}) {
      $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
      return 0;
   }

   unless (defined $a{-testId}) {
      $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
      return 0;
   }

   if($a{-skipDwnld} eq 0) {
      unless (defined $a{-assignment}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
         return 0;
      }
   }

   my %mgtsInfo = %{$a{-mgtsInfo}};

   # Get MGTS object
   my $mgts_object = $main::TESTBED{ "mgts:$a{-mgtsNumber}:obj" };

  $mgts_object->{DEFAULTTIMEOUT} = 60;

   my $nodeName;
   if($a{-skipDwnld} eq 0) {
      # Download the assignment
      unless ($mgts_object->configureMgtsFromTar(-putTarFile     => 0,
                                                 -mgtsAssignment => $a{-assignment},
                                                )) {
         $logger->debug(__PACKAGE__ . ".$sub : Error in configuring MGTS");
         return 0;
      }
   }
   if (defined ($a{-waitTime})){
        sleep($a{-waitTime});
   }
   foreach $nodeName (keys %mgtsInfo) {
      # Get the state machine names
      my @stateMachines;

      if($a{-skipDwnld} eq 0) {
         unless (defined ($mgtsInfo{$nodeName}->{stateMachines})) {
            next;
         }
         @stateMachines = @{$mgtsInfo{$nodeName}->{stateMachines}};
      } else {
         unless (defined ($mgtsInfo{$nodeName}->{spStateMachines})) {
            next;
         }
         @stateMachines = @{$mgtsInfo{$nodeName}->{spStateMachines}};
      }

      if($stateMachines[0] eq "") {
         next;
      }

      # Execute the state machines
      my $stateMachine;
      foreach $stateMachine(@stateMachines) {
         unless ($mgts_object->executeStateMachine (-testId             => $a{-testId},
                                                    -nodeName           => $nodeName,
                                                    -stateMachine       => $stateMachine,
                                                    -mgtsStatesDir      => $mgtsInfo{$nodeName}->{mgtsStatesDir},
                                                    -logDir             => $a{-logDir},
                                                    -timeStamp          => $a{-timeStamp},
                                                    -doNotLogMGTS       => $a{-doNotLogMGTS},
                                                    -variant            => $a{-variant},
                                                    )) {
             $logger->debug(__PACKAGE__ . ".$sub : Could not execute the MGTS state machine");
             return 0;
         }
      }
   }

   return 1;
}

=head2 checkM3uaExternalStatus

=over

=item DESCRIPTION:

    This subroutine checks and corrects the status of Associations and links

=item ARGUMENTS:

   Mandatory :
      -sctpAssocNames           => Reference to an array of SCTP Association Names to be checked
      -m3uaAspLinkNames         => Reference to an array of M3UA ASP Link Names to be checked
      -m3uaAspLinkSetNames      => Reference to an array of M3UA ASP Link Set Names to be checked
      -ss7Destinations          => Reference to an array of SS7 Destination Names to be checked
      -ss7Routes                => Reference to an array of SS7 Route Names to be checked
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA

                                   If -skipDwnld is '1', the node names are retrieved from this
      -logDir                   => ATS log directory
      -testId                   => Test Case ID



   Optional :

      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"

      -doConfig                 => Correct the status
                                   1 - Do config
                                   0 - No config. Just check the status and report
                                   Default => 1

      -sgxId        			=> 1 or 2 (check the config status for first or second sgx)
								   Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

   my $node1                 = "STP1";
   my $node2                 = "STP2";
   my @initialStateMachinesi_node1  = ("M3UA-Association-toSTP");
   my @initialStateMachinesi_node2  = ("M3UA-Association-toSTP_STP2");
   my $mgtsStatesDir         = "/home/mgtsuser5/datafiles/States/ISUPoverSCTP/ANSI/TRAFFICCONTROL/";

   my @sctpAssocNames        = ("stp1MgtsCE0Single", "stp2MgtsCE1Single");
   my @m3uaAspLinkNames      = ("stp1MgtsCE0Single", "stp2MgtsCE1Single");
   my @m3uaAspLinkSetNames   = ("stp1MgtsCE0Single", "stp2MgtsCE1Single");
   my @ss7Destinations       = ("blueJayFITDest", "test");
   my @ss7Routes             = ("blueJayFITrtCE0", "blueJayFITrtCE1", "testCE0", "testCE1");
   my @stateMachines         = ("DAUD_DAVA");
   my $assignment            = "M3UA_TRAFFIC_CONTROLS_ANSI";
   my $logDir                = "/home/ssukumaran/ats_user/logs/";
   my $testId                = "11111";
   my %mgtsInfo;

   $mgtsInfo{"$node1"}->{"stateMachines"} = \@initialStateMachinesi_node1;
   $mgtsInfo{"$node1"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node1"}->{"spStatMachines"} = \@stateMachines;
   $mgtsInfo{"$node2"}->{"stateMachines"} = \@initialStateMachinesi_node2;
   $mgtsInfo{"$node2"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node2"}->{"spStatMachines"} = \@stateMachines;

   $retCode = SonusQA::TRIGGER::checkM3uaExternalStatus(
                                                        -sctpAssocNames         => \@sctpAssocNames,
                                                        -m3uaAspLinkNames       => \@m3uaAspLinkNames,
                                                        -m3uaAspLinkSetNames    => \@m3uaAspLinkSetNames,
                                                        -ss7Destinations        => \@ss7Destinations,
                                                        -ss7Routes              => \@ss7Routes,
                                                        -assignment             => $assignment,
                                                        -mgtsInfo               => \%mgtsInfo,
                                                        -logDir                 => $logDir,
                                                        -testId                 => $testId,
                                                       );

=back

=cut

sub checkM3uaExternalStatus {
   my (%args) = @_;
   my $sub = "checkM3uaExternalStatus()";
   my %a = (-doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -doConfig         => 1,
            -sgxId    		  => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-sctpAssocNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SCTP Association Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-m3uaAspLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to M3UA ASP Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-m3uaAspLinkSetNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to M3UA ASP Link Set Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-ss7Destinations}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 Destination Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-ss7Routes}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 routes Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   if ($a{-doConfig} eq 1) {
      unless (defined $a{-assignment}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-mgtsInfo}) {
         $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-logDir}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-testId}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my %mgtsInfo;

   my $doConfig = $a{-doConfig};

   if ($doConfig eq 1) {
      %mgtsInfo = %{$a{-mgtsInfo}};
   }

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   # Do 2 times. First correct the status if failed. Second time, only check the status and
   # return
   my $index = 0;
   my %statInfo;
   my $retStatus;
   my @assocNames            = @{$a{-sctpAssocNames}};
   my @m3uaAspLinkNames      = @{$a{-m3uaAspLinkNames}};
   my @m3uaAspLinkSetNames   = @{$a{-m3uaAspLinkSetNames}};
   my @ss7Destinations       = @{$a{-ss7Destinations}};
   my @ss7Routes             = @{$a{-ss7Routes}};
   my $retCode;
   my $checkAgain = 0;

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK STARTED FOR M3UA EXTERNAL******************");

   while ($index < 2) {
      ##############################################################################################
      # Check Sigtran SCTP Association
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SIGTR_SCTP",
                                                -names         => \@assocNames,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId	       => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: Sigtran SCTP Association check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      ##############################################################################################
      # Check M3UA ASP link
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "M3UA_ASP_LINK",
                                                -names         => \@m3uaAspLinkNames,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId		   => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: M3UA ASP link check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      ##############################################################################################
      # Check M3UA ASP link set
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "M3UA_ASP_LINK_SET",
                                                -names         => \@m3uaAspLinkSetNames,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId		   => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: M3UA ASP link set check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      # If there is any update, we have to run then we need to Download and run the list of state machines
      if(($doConfig eq 1) and ($checkAgain eq 1)) {
         unless ($retCode = mgtsDwnldAndRun(-mgtsInfo         => \%mgtsInfo,
                                            -assignment       => $a{-assignment},
                                            -skipDwnld        => 0,
                                            -logDir           => $a{-logDir},
                                            -timeStamp        => $a{-timeStamp},
                                            -doNotLogMGTS     => $a{-doNotLogMGTS},
                                            -variant          => $a{-variant},
                                            -testId           => $a{-testId},
                                           )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: unable to download and run mgts");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      ##############################################################################################
      # Check SS7 ROUTE
      ##############################################################################################
      my $runStateMachine = 0;
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SS7_ROUTE",
                                                -names         => \@ss7Routes,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId		   => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: SS7 ROUTE check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
         $runStateMachine = 1;
      }

      ##############################################################################################
      # Check SS7 DEST
      ##############################################################################################
      unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => "SS7_DEST_TAB",
                                                -names         => \@ss7Destinations,
                                                -doConfig      => $doConfig,
                                                -sgxObj        => $args{-sgxObj},
                                                -sgxId		   => $a{-sgxId})) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         $logger->error(__PACKAGE__ . ".$sub: SS7 DEST check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
         $runStateMachine = 1;
      }

      # If there is any update, we have to run then we need to Download and run the list of state machines
      if(($doConfig eq 1) and ($runStateMachine eq 1)) {

         $retCode = mgtsDwnldAndRun(-skipDwnld        => 1,
                                    -mgtsInfo         => \%mgtsInfo,
                                    -logDir           => $a{-logDir},
                                    -timeStamp        => $a{-timeStamp},
                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                    -variant          => $a{-variant},
                                    -testId           => $a{-testId},
                                   );
          $logger->debug(__PACKAGE__ . ".$sub: return code of state machine execution => $retCode");
      }

      ##############################################################################################
      # Check Sigtran Sctp Assocaition Status
      ##############################################################################################
      my %sigStatInfo;
      my $sigRetStatus;
      my $assocName;
      my $dwnldAndrun = 0;

      # Get the current status
      unless ($sigRetStatus = $sgx_object->getSgxTableStat(-tableInfo    => "SIGTR_SCTP_STAT",
                                                           -statusInfo   => \%sigStatInfo)) {
         $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
         $logger->error(__PACKAGE__ . ".$sub: Sigtran Sctp Assocaition Status check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      foreach $assocName (@assocNames) {
         #Check the name exists
         unless (defined ($sigRetStatus->{$assocName})) {
            $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$assocName\'. Its not part of the display");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }

         #Check the status
         if($sigRetStatus->{$assocName}->{"STATUS"} ne "established") {
            #Check we have to correct the status
            if($doConfig eq 1) {
               $logger->debug(__PACKAGE__ . ".$sub: The entry \'$assocName\' is not in \'established\'");
               $checkAgain = 1;
               $dwnldAndrun = 1;
               last;
            } else {
               $logger->error(__PACKAGE__ . ".$sub: The entry \'$assocName\' is not in \'established\'");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }
         } else {
            $logger->debug(__PACKAGE__ . ".$sub: The entry \'$assocName\' is in \'established\'");
         }
      }

      ##############################################################################################
      # Check M3ua Asp Link Status
      ##############################################################################################
      my %aspStatInfo;
      my $aspRetStatus;
      my $aspName;

      # Get the current status
      unless ($aspRetStatus = $sgx_object->getSgxTableStat(-tableInfo    => "M3UA_ASP",
                                                           -statusInfo   => \%aspStatInfo)) {
         $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
         $logger->error(__PACKAGE__ . ".$sub: M3ua Asp Link Status check failed");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      foreach $aspName (@m3uaAspLinkNames) {
         #Check the name exists
         unless (defined ($aspRetStatus->{$aspName})) {
            $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$aspName\'. Its not part of the display");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }

         #Check the status
         if($aspRetStatus->{$aspName}->{"STATUS"} ne "linkStateUp") {
            #Check we have to correct the status
            if($doConfig eq 1) {
               $logger->debug(__PACKAGE__ . ".$sub: The entry \'$aspName\' is not in \'linkStateUp\'");
               $checkAgain = 1;
               $dwnldAndrun = 1;
               last;
            } else {
               $logger->error(__PACKAGE__ . ".$sub: The entry \'$aspName\' is not in \'linkStateUp\'");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }
         }
      }

      if(($doConfig eq 1) and ($dwnldAndrun eq 1)) {
         unless ($retCode = mgtsDwnldAndRun(-skipDwnld        => 0,
                                            -mgtsInfo         => \%mgtsInfo,
                                            -assignment       => $a{-assignment},
                                            -logDir           => $a{-logDir},
                                            -timeStamp        => $a{-timeStamp},
                                            -doNotLogMGTS     => $a{-doNotLogMGTS},
                                            -variant          => $a{-variant},
                                            -testId           => $a{-testId},
                                           )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->error(__PACKAGE__ . ".$sub: unable to download and run mgts");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      ##############################################################################################
      # Check SS7 Destination Status
      ##############################################################################################
      my %destStatInfo;
      my $destRetStatus;
      my $destName;
      $runStateMachine = 0;
      my $checkTCongestion = 0;

      # Get the current status
      unless ($destRetStatus = $sgx_object->getSgxTableStat(-tableInfo    => "SS7_DEST",
                                                            -statusInfo   => \%destStatInfo)) {
         $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
         $logger->error(__PACKAGE__ . ".$sub: SS7 Destination Status check fails");
         $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      foreach $destName (@ss7Destinations) {
         #Check the name exists
         unless (defined ($destRetStatus->{$destName})) {
            $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$destName\'. Its not part of the display");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }

         #Check the status
         if($destRetStatus->{$destName}->{"OVER_ALL_PC_STATUS"} ne "available") {
            #Check we have to correct the status
            if($doConfig eq 1) {
               $logger->debug(__PACKAGE__ . ".$sub: The entry \'$destName\' is not in \'available\'");
               $checkAgain = 1;
               $runStateMachine = 1;
               last;
            } else {
               $logger->error(__PACKAGE__ . ".$sub: The entry \'$destName\' is not in \'available\'");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }
         } elsif ($destRetStatus->{$destName}->{"OVER_ALL_PC_CONG_LEVEL"} ne 0) {
            #Check we have to correct the status
            if($doConfig eq 1) {
               $logger->debug(__PACKAGE__ . ".$sub: The entry \'$destName\' is not in \'0\'");
               $checkAgain = 1;
               $checkTCongestion = 1;
               last;
            } else {
               $logger->error(__PACKAGE__ . ".$sub: The entry \'$destName\' is not in \'0\'");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }
         } else {
            $logger->debug(__PACKAGE__ . ".$sub: The entry \'$destName\' is in  \'available\' and \'0\'");
         }
      }

      # If there is any update, we have to run then we need to Download and run the list of state machines
      if(($doConfig eq 1) and ($runStateMachine eq 1)) {

         $retCode = mgtsDwnldAndRun(-skipDwnld        => 1,
                                    -mgtsInfo         => \%mgtsInfo,
                                    -assignment       => $a{-assignment},
                                    -logDir           => $a{-logDir},
                                    -timeStamp        => $a{-timeStamp},
                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                    -variant          => $a{-variant},
                                    -testId           => $a{-testId},
                                   );
         $logger->debug(__PACKAGE__ . ".$sub: return code of state machine execution => $retCode");
      }

      if(($doConfig eq 1) and ($checkTCongestion eq 1)) {
         # Get M3UA profile
         # Make the command string
         my $cmdString = "show table ss7 destinationStatus";

         $logger->info(__PACKAGE__ . ".$sub cmdString : $cmdString");

         # Execute the CLI
         unless($sgx_object->execCliCmd($cmdString)) {
            $logger->error (__PACKAGE__ . ".$sub Failed CLI execution");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }

         # Get the tCongestion
         my $line;
         my $tCongestion = 0;
         foreach $line ( @{ $sgx_object->{CMDRESULTS}} ) {
            if($line =~ m/^tCongestion (\d+);/) {
               $tCongestion = $1;
            }
         }

         $logger->info(__PACKAGE__ . ".$sub the received tCongestion value is \'$tCongestion\'");
         # Needs to double the value
         $tCongestion = $tCongestion * 2;

         $logger->info(__PACKAGE__ . ".$sub waiting till \'$tCongestion\' seconds");

         my $index = 0;
         my $goodStatus = 1;
         while ($index < $tCongestion) {
            my %tempStatInfo;
            my $tempRetStatus;

            # Get the current status
            unless ($tempRetStatus = $sgx_object->getSgxTableStat(-tableInfo    => "SS7_DEST",
                                                                  -statusInfo   => \%tempStatInfo)) {
               $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
               $logger->error(__PACKAGE__ . ".$sub: SS7 DEST check fails");
               $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
               $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
               return 0;
            }

            # Hope all the destinations are fine
            $goodStatus = 1;
            foreach $destName (@ss7Destinations) {
               #Check the name exists.
               unless (defined ($tempRetStatus->{$destName})) {
                  $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$destName\'. Its not part of the display");
                  $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
                  $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
                  return 0;
               }

               #Check the status
               if ($destRetStatus->{$destName}->{"OVER_ALL_PC_CONG_LEVEL"} ne 0) {
                  $goodStatus = 0;
                  last;
               }
            }
            if($goodStatus eq 1) {
               # Done. All the destinations are good
               last;
            }
            # Wait for 10 seconds
            $index = $index + 10;
            sleep 10;
         }
         # check status
         if($goodStatus eq 0) {
            # We have waited enough. Return with error
            $logger->error(__PACKAGE__ . ".$sub: Still the congestion level is NOT \'0\'");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FINISHED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M3UA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      #If config is done, better check the status once again
      if(($checkAgain eq 0) or ($doConfig eq 0)){
         # Config is not done. Just finish it
         last;
      }

      $doConfig = 0;
      $index++;
   }
   
   $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FINISHED FOR M3UA EXTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK PASSED FOR M3UA EXTERNAL******************");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head2 dwlndAndWaitForMTPRestart

=over

=item DESCRIPTION:

    This subroutine downloads the assignment and runs a set of state machines. Also waitf for
    MTP restart

=item ARGUMENTS:

   Mandatory :
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA

      -logDir                   => ATS log directory
      -testId                   => Test Case ID
      -ss7Destinations          => Reference to an array of SS7 Destination Names to be checked
                                   to verify MTP restart

   Optional :
      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"

      -mgtsNumber               => mgts number to be used from testbed.

      -sgxId                    => 1 or 2 (check the config status for first or second sgx)
                                   Default => 1
      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

         unless ($retCode = dwlndAndWaitForMTPRestart(-mgtsInfo         => \%mgtsInfo,
                                                      -assignment       => $a{-assignment},
                                                      -skipDwnld        => 0,
                                                      -logDir           => $a{-logDir},
                                                      -timeStamp        => $a{-timeStamp},
                                                      -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                      -variant          => $a{-variant},
                                                      -testId           => $a{-testId},
                                                      -ss7Destinations  => \@ss7Destinations,
                                                     )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            return 0;
         }

=back

=cut

sub dwlndAndWaitForMTPRestart {
   my (%args) = @_;
   my $sub = "dwlndAndWaitForMTPRestart()";
   my %a = (-doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -mgtsNumber       => 1,
            -sgxId            => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-mgtsInfo}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
      return 0;
   }

   unless (defined $a{-assignment}) {
      $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
      return 0;
   }

   unless (defined $a{-logDir}) {
      $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
      return 0;
   }

   unless (defined $a{-testId}) {
      $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
      return 0;
   }

   unless (defined $a{-ss7Destinations}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 Destination Names is not provided");
      return 0;
   }


   my %mgtsInfo = %{$a{-mgtsInfo}};
   my $retCode;

   unless ($retCode = mgtsDwnldAndRun(-mgtsInfo         => \%mgtsInfo,
                                      -assignment       => $a{-assignment},
                                      -skipDwnld        => 0,
                                      -logDir           => $a{-logDir},
                                      -timeStamp        => $a{-timeStamp},
                                      -doNotLogMGTS     => $a{-doNotLogMGTS},
                                      -variant          => $a{-variant},
                                      -testId           => $a{-testId},
				      -waitTime         => $a{-waitTime},
                                      -mgtsNumber       => $a{-mgtsNumber},
                                     )) {
      $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
      return 0;
   }

   my @ss7Destinations       = @{$a{-ss7Destinations}};

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   my $statInfo = {};
   $statInfo->{OVER_ALL_PC_STATUS} = "available";

   my $retData = $sgx_object->waitForSgxStatusChange(-tableInfo  => "SS7_DEST",
                                                     -linkNames  => \@ss7Destinations,
                                                     -status     => $statInfo,
                                                     -interval   => 10,
						     -checkSpecific    => $a{-checkSpecific},
                                                     -attempts   =>  7);

   $logger->debug(__PACKAGE__ . ".$sub: Returning with $retData");
   return $retData;
}

=head2 M2paMtp2ExternalCommon

=over

=item DESCRIPTION:

    A common routine used for M2PA and MTP2 External Status check APIs

=item ARGUMENTS:

   Mandatory :
      -tblInfo                  => A hash reference for the table

                                   If -statusFlag is 1
                                      "SIGTR_SCTP_STAT" => 
                                                           status  => established
                                                           names   => \@assocNames

                                   If -statusFlag is 0
                                      "SIGTR_SCTP"      =>
                                                           names   => \@assocNames
                                                           sendTfa => 0

                                      "SS7_ROUTE"       =>
                                                           names   => \@routeNames
                                                           sendTfa => 1
                                                           tfaStateMachine => TFA state machine name

      -order                    => A reference array where the order of the tables to be checked is kept
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA

      -logDir                   => ATS log directory
      -testId                   => Test Case ID
      -ss7Destinations          => Reference to an array of SS7 Destination Names to be checked
                                   to verify MTP restart

   Optional :
      -statusFlag               => 1 - Checks the status of the given tables
                                   0 - Checks state and mode of the given tables
                                   Default => 1
      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"

      -mgtsNumber               => Define the MGTS Number with respect to the testbed which has
                                   to be used here. Exapmle : -mgtsNumber => 2 , if "mgts:2:obj" from the testbed
                                   to be used instead of the default "mgts:1:obj".

      -sgxId                    => 1 or 2 (check the config status for first or second sgx)
                                   Default => 1

      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

      unless ($retCode = M2paMtp2ExternalCommon(
                                                 -tblInfo          => \%stateTbl,
                                                 -order            => \@stateOrder,
                                                 -statusFlag       => 0,
                                                 -ss7Destinations  => \@ss7Destinations,
                                                 -doConfig         => $doConfig,
                                                 -mgtsInfo         => \%mgtsInfo,
                                                 -assignment       => $a{-assignment},
                                                 -logDir           => $a{-logDir},
                                                 -timeStamp        => $a{-timeStamp},
                                                 -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                 -variant          => $a{-variant},
                                                 -testId           => $a{-testId},
                                                 -mgtsNumber       => $a{-mgtsNumber},
                                               )) {
         $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
         return 0;
      }

=back

=cut

sub M2paMtp2ExternalCommon {
   my (%args) = @_;
   my $sub = "M2paMtp2ExternalCommon()";
   my %a = (-statusFlag       => 1,
            -doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -mgtsNumber       => 1,
            -sgxId            => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-tblInfo}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to Table info is not provided");
      return 0;
   }
   unless (defined $a{-order}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to order is not provided");
      return 0;
   }
   if($a{-doConfig} eq 1) {
      unless (defined $a{-mgtsInfo}) {
         $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
         return 0;
      }

      unless (defined $a{-assignment}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
         return 0;
      }

      unless (defined $a{-logDir}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
         return 0;
      }

      unless (defined $a{-testId}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
         return 0;
      }
   }

   unless (defined $a{-ss7Destinations}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 Destination Names is not provided");
      return 0;
   }

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" } is not defind");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   my %tableInfo = %{$a{-tblInfo}};

   my $tblName;
   my $downldAssignment      = 0;
   my $sendTfa               = 0;
   my $retCode;
   my $index                 = 0;
   my $retValue              = 1;;

   my @order = @{$a{-order}};

   # Needs to do it 2 times. For some tables, TFA is send and then status needs to be checked.
   # If there is no change is status, assignment is downloaded again
   while ($index < 2) {
      foreach $tblName (@order) {
         my @names = @{$tableInfo{$tblName}->{names}};
         if($a{-statusFlag} eq 0) {
            unless ($retCode = checkSgxTabEntryStatus(-tableInfo     => $tblName,
                                                      -names         => \@names,
                                                      -doConfig      => $a{-doConfig},
                                                      -sgxObj        => $args{-sgxObj},
						      -checkSpecific => $a{-checkSpecific},
                                                      -sgxId         => $a{-sgxId})) {
               $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
               return 0;
            }

            # If config is done. Check the status again and report back
            if ($retCode eq 2) {
               # If TFA is already sent, download the assignment
               if(($sendTfa ne 1) and ($tableInfo{$tblName}->{sendTfa} eq 1)) {
                  $sendTfa = 1;
               } else {
                  $downldAssignment = 1;
               }
            }
         } else {
            my %statInfo;
            my $retStatus;
            my $name;
	    my $checkAll = 0;
            # Get the current status
           
            my $status = $tableInfo{$tblName}->{status};
            foreach $name (@names) {
           
		if(defined $a{-checkSpecific} and $a{-checkSpecific} == 1) {
               # Get the current status			
	               unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $tblName,
		                                                         -checkSpecific=> $name,
                	                                                 -statusInfo   => \%statInfo)) {
                  	$logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
			  return 0;
			}
               }else{
		if($checkAll == 0){
		   unless ($retStatus = $sgx_object->getSgxTableStat(-tableInfo    => $tblName,
                                                                 -statusInfo   => \%statInfo)) {
                   $logger->error(__PACKAGE__ . ".$sub: Error in getting required status");
                   return 0;
		   }
		  $checkAll = 1;
		 }
		}

               #Check the name exists
               unless (defined ($retStatus->{$name})) {
                  $logger->error(__PACKAGE__ . ".$sub: This name looks like wrong \'$name\'. Its not part of the display");
                  return 0;
               }
               if($tblName eq "SS7_DEST") {

                  # Needs different processing

                  #Check the status
                  if($retStatus->{$name}->{"OVER_ALL_PC_STATUS"} ne "available") {
                     #Check we have to correct the status
                     if($a{-doConfig} eq 1) {
                        $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'available\'");
                        if(($sendTfa ne 1) and ($tableInfo{$tblName}->{sendTfa} eq 1)) {
                           $sendTfa = 1;
                        } else {
                           $downldAssignment = 1;
                        }
                        last;
                     } else {
                        $logger->error(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'available\'");
                        return 0;
                     }
                  } else {
                     $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is in  \'available\' and \'0\'");
                  }
               } else {
                  #Check the status
                  if($retStatus->{$name}->{"STATUS"} ne $status) {
                     #Check we have to correct the status
                     if($a{-doConfig} eq 1) {
                        $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$status\'");
                        $downldAssignment = 1;
                        last;
                     } else {
                        $logger->error(__PACKAGE__ . ".$sub: The entry \'$name\' is not in \'$status\'");
                        return 0;
                     }
                  } else {
                     $logger->debug(__PACKAGE__ . ".$sub: The entry \'$name\' is in \'$status\'");
                  }
               }
            }
         }
      }

      my @ss7Destinations       = @{$a{-ss7Destinations}};

      my %mgtsInfo;
      if($a{-doConfig} eq 1) {
         %mgtsInfo              = %{$a{-mgtsInfo}};
      }
   
      if(($downldAssignment eq 0) and ($sendTfa eq 1) and ($index eq 0)) {
         $retValue = 2;
         $retCode = mgtsDwnldAndRun(-skipDwnld        => 1,
                                     -mgtsInfo         => \%mgtsInfo,
                                     -assignment       => $a{-assignment},
                                     -logDir           => $a{-logDir},
                                     -timeStamp        => $a{-timeStamp},
                                     -doNotLogMGTS     => $a{-doNotLogMGTS},
                                     -variant          => $a{-variant},
                                     -testId           => $a{-testId},
				     -waitTime         => $a{-waitTime},
                                     -mgtsNumber       => $a{-mgtsNumber},
                                    );
         # If the status is not corrected, set the downldAssignment flag
      }

      if($downldAssignment eq 1){
         $retValue = 2;
         $sendTfa = 0;
         unless ($retCode = dwlndAndWaitForMTPRestart(-mgtsInfo         => \%mgtsInfo,
                                                      -assignment       => $a{-assignment},
                                                      -skipDwnld        => 0,
                                                      -logDir           => $a{-logDir},
                                                      -timeStamp        => $a{-timeStamp},
                                                      -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                      -variant          => $a{-variant},
                                                      -testId           => $a{-testId},
                                                      -ss7Destinations  => \@ss7Destinations,
                                                      -mgtsNumber       => $a{-mgtsNumber}, 
                                                      -sgxObj        => $args{-sgxObj},
						      -waitTime         => $a{-waitTime},
						      -checkSpecific    => $a{-checkSpecific},
                                                      -sgxId            => $a{-sgxId}
                                                     )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            return 0;
         }
      }

      if($sendTfa eq 0) {
         last;
      }

      $index++;
   }
   return $retValue;
}

=head2 checkM2paExternalStatus

=over

=item DESCRIPTION:

    This subroutine checks and corrects the status of Associations and links

=item ARGUMENTS:

   Mandatory :
      -sctpAssocNames           => Reference to an array of SCTP Association Names to be checked
      -m2paLinkNames            => Reference to an array of M2PA Link Names to be checked
      -mtp2SigLinkNames         => Reference to an array of MTP2 Link Names to be checked
      -mtp2SigLinkSetNames      => Reference to an array of MTP2 Link Set Names to be checked
      -ss7Destinations          => Reference to an array of SS7 Destination Names to be checked
      -ss7Routes                => Reference to an array of SS7 Route Names to be checked
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA

      -logDir                   => ATS log directory
      -testId                   => Test Case ID



   Optional :

      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"
      -doConfig                 => Correct the status
                                   1 - Do config
                                   0 - No config. Just check the status and report
                                   Default => 1

      -mgtsNumber               => Define the MGTS Number with respect to the testbed which has
                                   to be used here. Exapmle : -mgtsNumber => 2 , if "mgts:2:obj" from the testbed
                                   to be used instead of the default "mgts:1:obj".

      -sgxId                    => 1 or 2 (check the config status for first or second sgx)
                                   Default => 1

      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

   my $node1                 = "STP1";
   my $node2                 = "STP2";
   my @initialStateMachinesi_node1  = ("");
   my @initialStateMachinesi_node2  = ("");
   my $mgtsStatesDir         = "/home/mgtsuser5/datafiles/States/ANSI/MTP3TrafficControls/";

   my @sctpAssocNames        = ("ansiStp1MgtsCE0Single", "ansiStp1MgtsCE1Single", "ansiStp2MgtsCE0Single", "ansiStp2MgtsCE1Single");
   my @m2paLinkNames         = ("ansim2palink1", "ansim2palink2", "ansim2palink3", "ansim2palink4");
   my @mtp2SigLinkNames      = ("mtpSL1", "mtpSL2", "mtpSL3", "mtpSL4");
   my @mtp2SigLinkSetNames   = ("mtpLset1", "mtpLset2");
   my @ss7Destinations       = ("Dest1141", "stpMgts1", "stpMgts2", "blueJayFITDest");
   my @ss7Routes             = ("Destn1141rtCE0", "Destn1141rtCE1", "blueJayFITrtCE0", "blueJayFITrtCE1", "blueJayFITstprtCE0", "blueJayFITstprtCE1");
   my @stateMachines_node1   = ("TFA_1140");   # TFA state machine
   my @stateMachines_node2   = ("TFA_1140");   # TFA state machine
   my $assignment            = "SGX4000-Slot8-M2PA-Traffic-Controls";
   my $logDir                = "/home/ssukumaran/ats_user/logs/";
   my $testId                = "11111";
   my %mgtsInfo;

   $mgtsInfo{"$node1"}->{"stateMachines"} = \@initialStateMachinesi_node1;
   $mgtsInfo{"$node1"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node1"}->{"spStateMachines"} = \@stateMachines_node1;
   $mgtsInfo{"$node2"}->{"stateMachines"} = \@initialStateMachinesi_node2;
   $mgtsInfo{"$node2"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node2"}->{"spStateMachines"} = \@stateMachines_node2;

   # Get MGTS object
   my $mgts_object = $main::TESTBED{ "mgts:1:obj" };

   $retCode = SonusQA::TRIGGER::checkM2paExternalStatus(
                                                        -sctpAssocNames         => \@sctpAssocNames,
                                                        -m2paLinkNames          => \@m2paLinkNames,
                                                        -mtp2SigLinkNames       => \@mtp2SigLinkNames,
                                                        -mtp2SigLinkSetNames    => \@mtp2SigLinkSetNames,
                                                        -ss7Destinations        => \@ss7Destinations,
                                                        -ss7Routes              => \@ss7Routes,
                                                        -assignment             => $assignment,
                                                        -mgtsInfo               => \%mgtsInfo,
                                                        -stateMachines          => \@stateMachines,
                                                        -logDir                 => $logDir,
                                                        -testId                 => $testId,
                                                        -mgtsNumber             => 1,
                                                       );

=back

=cut

sub checkM2paExternalStatus {
   my (%args) = @_;
   my $sub = "checkM2paExternalStatus()";
   my %a = (-doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -doConfig         => 1,
            -mgtsNumber       => 1,
            -sgxId            => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-sctpAssocNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SCTP Association Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-m2paLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to M2PA Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-mtp2SigLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MTP2 Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-mtp2SigLinkSetNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MTP2 Link Set Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-ss7Destinations}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 Destination Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-ss7Routes}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 routes Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   if($a{-doConfig} eq 1) {
      unless (defined $a{-assignment}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-mgtsInfo}) {
         $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-logDir}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-testId}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my $doConfig = $a{-doConfig};

   my %mgtsInfo;

   if($doConfig eq 1) {
      %mgtsInfo = %{$a{-mgtsInfo}};
   }

   # Get SGX object
   if ((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/\$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
	
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   # Do 2 times. First correct the status if failed. Second time, only check the status and
   # return
   my $index = 0;
   my @assocNames            = @{$a{-sctpAssocNames}};
   my @m2paLinkNames         = @{$a{-m2paLinkNames}};
   my @mtp2SigLinkNames      = @{$a{-mtp2SigLinkNames}};
   my @mtp2SigLinkSetNames   = @{$a{-mtp2SigLinkSetNames}};
   my @ss7Destinations       = @{$a{-ss7Destinations}};
   my @ss7Routes             = @{$a{-ss7Routes}};
   my $retCode;
   my $checkAgain = 0;

   my %stateTbl;
   my %statusTbl;

   # State and mode check
   $stateTbl{"SIGTR_SCTP"}->{names}           = \@assocNames;
   $stateTbl{"SIGTR_SCTP"}->{sendTfa}         = 0;
   $stateTbl{"M2PA_LINK"}->{names}            = \@m2paLinkNames;
   $stateTbl{"M2PA_LINK"}->{sendTfa}          = 0;
   $stateTbl{"SS7_MTP2_LINKSET"}->{names}     = \@mtp2SigLinkSetNames;
   $stateTbl{"SS7_MTP2_LINKSET"}->{sendTfa}   = 0;
   $stateTbl{"SS7_MTP2_SIG"}->{names}         = \@mtp2SigLinkNames;
   $stateTbl{"SS7_MTP2_SIG"}->{sendTfa}       = 0;
   $stateTbl{"SS7_ROUTE"}->{names}            = \@ss7Routes;
   $stateTbl{"SS7_ROUTE"}->{sendTfa}          = 1;
   $stateTbl{"SS7_DEST_TAB"}->{names}         = \@ss7Destinations;
   $stateTbl{"SS7_DEST_TAB"}->{sendTfa}       = 1;

   my @stateOrder = ("SIGTR_SCTP", "M2PA_LINK", "SS7_MTP2_LINKSET", "SS7_MTP2_SIG", "SS7_ROUTE", "SS7_DEST_TAB");

   # Status check
   $statusTbl{"SIGTR_SCTP_STAT"}->{names}     =  \@assocNames;
   $statusTbl{"SIGTR_SCTP_STAT"}->{sendTfa}   = 0;
   $statusTbl{"SIGTR_SCTP_STAT"}->{status}    = "established";
   $statusTbl{"M2PA_LINK_STAT"}->{names}      = \@m2paLinkNames;
   $statusTbl{"M2PA_LINK_STAT"}->{sendTfa}    = 0;
   $statusTbl{"M2PA_LINK_STAT"}->{status}     = "inServiceNeitherEndBusy";
   $statusTbl{"SS7_MTP2"}->{names}            = \@mtp2SigLinkNames;
   $statusTbl{"SS7_MTP2"}->{sendTfa}          = 0;
   $statusTbl{"SS7_MTP2"}->{status}           = "available";
   $statusTbl{"SS7_ROUTE_STAT"}->{names}      = \@ss7Routes;
   $statusTbl{"SS7_ROUTE_STAT"}->{sendTfa}    = 0;
   $statusTbl{"SS7_ROUTE_STAT"}->{status}     = "available";
   $statusTbl{"SS7_DEST"}->{names}            = \@ss7Destinations;
   $statusTbl{"SS7_DEST"}->{sendTfa}          = 1;
   $statusTbl{"SS7_DEST"}->{status}           = "available";

   my @statusOrder = ("SIGTR_SCTP_STAT", "M2PA_LINK_STAT", "SS7_MTP2", "SS7_ROUTE_STAT", "SS7_DEST");

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK STARTED FOR M2PA EXTERNAL******************");

   while ($index < 2) {
      if($doConfig eq 1) {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%stateTbl,
                                                    -order            => \@stateOrder,
                                                    -statusFlag       => 0,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsInfo         => \%mgtsInfo,
                                                    -assignment       => $a{-assignment},
                                                    -logDir           => $a{-logDir},
                                                    -timeStamp        => $a{-timeStamp},
                                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                    -variant          => $a{-variant},
                                                    -testId           => $a{-testId},
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
					            -checkSpecific    => $a{-checkSpecific}								
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M2PA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      } else {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%stateTbl,
                                                    -order            => \@stateOrder,
                                                    -statusFlag       => 0,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M2PA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      if($doConfig eq 1) {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%statusTbl,
                                                    -order            => \@statusOrder,
                                                    -statusFlag       => 1,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsInfo         => \%mgtsInfo,
                                                    -assignment       => $a{-assignment},
                                                    -logDir           => $a{-logDir},
                                                    -timeStamp        => $a{-timeStamp},
                                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                    -variant          => $a{-variant},
                                                    -testId           => $a{-testId},
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
					            -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M2PA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      } else {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%statusTbl,
                                                    -order            => \@statusOrder,
                                                    -statusFlag       => 1,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M2PA EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      if(($checkAgain eq 0) or ($doConfig eq 0)){
         last;
      }

      $doConfig = 0;
      $index++;
   }

   # Once we have reached here means, there are no errors. Just check the congestion and return

   my $statInfo = {};
   $statInfo->{OVER_ALL_PC_CONG_LEVEL} = 0;

   my $retData = $sgx_object->waitForSgxStatusChange(-tableInfo  => "SS7_DEST",
                                                     -linkNames  => \@ss7Destinations,
                                                     -status     => $statInfo,
                                                     -interval   => 10,
                                                     -attempts   =>  7,
						     -checkSpecific    => $a{-checkSpecific});

   $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FINISHED FOR M2PA EXTERNAL******************");

   if ($retData == 1) {
      $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK PASSED FOR M2PA EXTERNAL******************");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   } else {
      $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR M2PA EXTERNAL******************");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   }
   
   return $retData;
}

=head2 checkMtp2ExternalStatus

=over

=item DESCRIPTION:

    This subroutine checks and corrects the status of links

=item ARGUMENTS:

   Mandatory :
      -mtp2LinkNames            => Reference to an array of MTP2 Link Names to be checked
      -mtp2SigLinkNames         => Reference to an array of MTP2 Link Names to be checked
      -mtp2SigLinkSetNames      => Reference to an array of MTP2 Link Set Names to be checked
      -ss7Destinations          => Reference to an array of SS7 Destination Names to be checked
      -ss7Routes                => Reference to an array of SS7 Route Names to be checked
      -assignment               => MGTS assignment to be downloaded
      -mgtsInfo                 => A hash reference which looks like following
                                      Node1 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA
                                      Node2 =>
                                               statMachines    => \@statMachineNames
                                               mgtsStatesDir   => $mgtsStatesDir
                                               spStatMachines  => \@spStatMachineNames    E.g., DAUD_DAVA or TFA

      -logDir                   => ATS log directory
      -testId                   => Test Case ID



   Optional :

      -variant                  => Test case variant "ANSI", "ITU" etc
                                   Default => "NONE"

      -timeStamp                => Time stamp
                                   Default => "00000000-000000"

      -doConfig                 => Correct the status
                                   1 - Do config
                                   0 - No config. Just check the status and report
                                   Default => 1

       -mgtsNumber               => Define the MGTS Number with respect to the testbed which has
                                   to be used here. Exapmle : -mgtsNumber => 2 , if "mgts:2:obj" from the testbed
                                   to be used instead of the default "mgts:1:obj".

      -sgxId                    => 1 or 2 (check the config status for first or second sgx)
                                    Default => 1  

      -sgxObj                => sgx object referance incase absense of global hash (%TESTBED)

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

   my $node1                 = "STP1";
   my $node2                 = "STP2";
   my @initialStateMachinesi_node1  = ("");
   my @initialStateMachinesi_node2  = ("");
   my $mgtsStatesDir         = "/home/mgtsuser5/datafiles/States/ANSI/MTP3TrafficControls/";

   my @mtp2LinkNames         = ("chipMtp21", "chipMtp22", "daleMtp21", "daleMtp22");
   my @mtp2SigLinkNames      = ("mtpSL1", "mtpSL2", "mtpSL3", "mtpSL4");
   my @mtp2SigLinkSetNames   = ("mtpLset1", "mtpLset2");
   my @ss7Destinations       = ("Dest1141", "stpMgts1", "stpMgts2", "blueJayFITDest");
   my @ss7Routes             = ("Destn1141rtCE0", "Destn1141rtCE1", "blueJayFITrtCE0", "blueJayFITrtCE1", "blueJayFITstprtCE0", "blueJayFITstprtCE1");
   my @stateMachines_node1   = ("TFA_1140");   # TFA state machine
   my @stateMachines_node2   = ("TFA_1140");   # TFA state machine
   my $assignment            = "SGX4000_MP_MTP_Traffic_Controls_ANSI_M500_2_11";
   my $logDir                = "/home/ssukumaran/ats_user/logs/";
   my $testId                = "11111";
   my %mgtsInfo;

   $mgtsInfo{"$node1"}->{"stateMachines"} = \@initialStateMachinesi_node1;
   $mgtsInfo{"$node1"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node1"}->{"spStateMachines"} = \@stateMachines_node1;
   $mgtsInfo{"$node2"}->{"stateMachines"} = \@initialStateMachinesi_node2;
   $mgtsInfo{"$node2"}->{"mgtsStatesDir"} = $mgtsStatesDir;
   $mgtsInfo{"$node2"}->{"spStateMachines"} = \@stateMachines_node2;

   # Get MGTS object
   my $mgts_object = $main::TESTBED{ "mgts:1:obj" };

   $retCode = SonusQA::TRIGGER::checkMtp2ExternalStatus(
                                                        -mtp2LinkNames          => \@mtp2LinkNames,
                                                        -mtp2SigLinkNames       => \@mtp2SigLinkNames,
                                                        -mtp2SigLinkSetNames    => \@mtp2SigLinkSetNames,
                                                        -ss7Destinations        => \@ss7Destinations,
                                                        -ss7Routes              => \@ss7Routes,
                                                        -assignment             => $assignment,
                                                        -mgtsInfo               => \%mgtsInfo,
                                                        -stateMachines          => \@stateMachines,
                                                        -logDir                 => $logDir,
                                                        -testId                 => $testId,
                                                       );

=back

=cut

sub checkMtp2ExternalStatus {
   my (%args) = @_;
   my $sub = "checkMtp2ExternalStatus()";
   my %a = (-doNotLogMGTS     => 0,
            -variant          => "NONE",
            -timeStamp        => "00000000-000000",
            -doConfig         => 1,
            -mgtsNumber       => 1,
            -sgxId            => 1);

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-mtp2LinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MTP2 Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-mtp2SigLinkNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MTP2 Link Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-mtp2SigLinkSetNames}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to MTP2 Link Set Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

   unless (defined $a{-ss7Destinations}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 Destination Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   unless (defined $a{-ss7Routes}) {
      $logger->error(__PACKAGE__ . ".$sub The reference to SS7 routes Names is not provided");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }

  unless (defined $a{-checkSpecific}) {
     $a{-checkSpecific} = 0;
  }
   if ($a{-doConfig} eq 1) {
      unless (defined $a{-assignment}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory Assignment is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-mgtsInfo}) {
         $logger->error(__PACKAGE__ . ".$sub The reference to MGTS info is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-logDir}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory log directory is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }

      unless (defined $a{-testId}) {
         $logger->error(__PACKAGE__ . ".$sub The mandatory test ID is not provided");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my $doConfig = $a{-doConfig};

   my %mgtsInfo;

   if($doConfig eq 1) {
      %mgtsInfo = %{$a{-mgtsInfo}};
   }

   # Get SGX object
   if((!defined $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" }) and (!defined $args{-sgxObj})) {
      $logger->error(__PACKAGE__ . ".$sub \$main::TESTBED{ \"sgx4000:$a{-sgxId}:obj\" }/$args{-sgxObj} is not defind");
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
      return 0;
   }
   my $sgx_object = $main::TESTBED{ "sgx4000:$a{-sgxId}:obj" } || $args{-sgxObj};

   # Do 2 times. First correct the status if failed. Second time, only check the status and
   # return
   my $index = 0;
   my @mtp2LinkNames         = @{$a{-mtp2LinkNames}};
   my @mtp2SigLinkNames      = @{$a{-mtp2SigLinkNames}};
   my @mtp2SigLinkSetNames   = @{$a{-mtp2SigLinkSetNames}};
   my @ss7Destinations       = @{$a{-ss7Destinations}};
   my @ss7Routes             = @{$a{-ss7Routes}};
   my $retCode;
   my $checkAgain = 0;

   my %stateTbl;
   my %statusTbl;

   # State and mode check
   $stateTbl{"SS7_MTP2_LINK_TAB"}->{names}    = \@mtp2LinkNames;
   $stateTbl{"SS7_MTP2_LINK_TAB"}->{sendTfa}  = 0;
   $stateTbl{"SS7_MTP2_LINKSET"}->{names}     = \@mtp2SigLinkSetNames;
   $stateTbl{"SS7_MTP2_LINKSET"}->{sendTfa}   = 0;
   $stateTbl{"SS7_MTP2_SIG"}->{names}         = \@mtp2SigLinkNames;
   $stateTbl{"SS7_MTP2_SIG"}->{sendTfa}       = 0;
   $stateTbl{"SS7_ROUTE"}->{names}            = \@ss7Routes;
   $stateTbl{"SS7_ROUTE"}->{sendTfa}          = 1;
   $stateTbl{"SS7_DEST_TAB"}->{names}         = \@ss7Destinations;
   $stateTbl{"SS7_DEST_TAB"}->{sendTfa}       = 1;

   my @stateOrder = ("SS7_MTP2_LINK_TAB", "SS7_MTP2_SIG", "SS7_MTP2_LINKSET", "SS7_ROUTE", "SS7_DEST_TAB");

   # Status check
   $statusTbl{"SS7_MTP2_LINK"}->{names}       = \@mtp2LinkNames;
   $statusTbl{"SS7_MTP2_LINK"}->{sendTfa}     = 0;
   $statusTbl{"SS7_MTP2_LINK"}->{status}      = "inServiceNeitherEndBusy";
   $statusTbl{"SS7_MTP2"}->{names}            = \@mtp2SigLinkNames;
   $statusTbl{"SS7_MTP2"}->{sendTfa}          = 0;
   $statusTbl{"SS7_MTP2"}->{status}           = "available";
   $statusTbl{"SS7_ROUTE_STAT"}->{names}      = \@ss7Routes;
   $statusTbl{"SS7_ROUTE_STAT"}->{sendTfa}    = 0;
   $statusTbl{"SS7_ROUTE_STAT"}->{status}     = "available";
   $statusTbl{"SS7_DEST"}->{names}            = \@ss7Destinations;
   $statusTbl{"SS7_DEST"}->{sendTfa}          = 1;
   $statusTbl{"SS7_DEST"}->{status}           = "available";

   my @statusOrder = ("SS7_MTP2_LINK", "SS7_MTP2", "SS7_ROUTE_STAT", "SS7_DEST");

   $logger->debug(__PACKAGE__ . ".$sub: ************TEST BED STATUS CHECK STARTED FOR MTP2 EXTERNAL******************");

   while ($index < 2) {
      if ($doConfig eq 1) {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%stateTbl,
                                                    -order            => \@stateOrder,
                                                    -statusFlag       => 0,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsInfo         => \%mgtsInfo,
                                                    -assignment       => $a{-assignment},
                                                    -logDir           => $a{-logDir},
                                                    -timeStamp        => $a{-timeStamp},
                                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                    -variant          => $a{-variant},
                                                    -testId           => $a{-testId},
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},					
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR MTP2 EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      } else {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%stateTbl,
                                                    -order            => \@stateOrder,
                                                    -statusFlag       => 0,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR MTP2 EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      if($doConfig eq 1) {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%statusTbl,
                                                    -order            => \@statusOrder,
                                                    -statusFlag       => 1,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsInfo         => \%mgtsInfo,
                                                    -assignment       => $a{-assignment},
                                                    -logDir           => $a{-logDir},
                                                    -timeStamp        => $a{-timeStamp},
                                                    -doNotLogMGTS     => $a{-doNotLogMGTS},
                                                    -variant          => $a{-variant},
                                                    -testId           => $a{-testId},
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId            => $a{-sgxId},
					            -waitTime         => $a{-waitTime},
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR MTP2 EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      } else {
         unless ($retCode = M2paMtp2ExternalCommon(
                                                    -tblInfo          => \%statusTbl,
                                                    -order            => \@statusOrder,
                                                    -statusFlag       => 1,
                                                    -ss7Destinations  => \@ss7Destinations,
                                                    -doConfig         => $doConfig,
                                                    -mgtsNumber       => $a{-mgtsNumber},
                                                    -sgxObj        => $args{-sgxObj},
                                                    -sgxId    	      => $a{-sgxId},
						    -waitTime         => $a{-waitTime},
						    -checkSpecific    => $a{-checkSpecific}
                                                  )) {
            $logger->error(__PACKAGE__ . ".$sub: Unable to perform required action");
            $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR MTP2 EXTERNAL******************");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
         }
      }

      # If config is done. Check the status again and report back
      if ($retCode eq 2) {
         $checkAgain = 1;
      }

      if(($checkAgain eq 0) or ($doConfig eq 0)){
         last;
      }

      $doConfig = 0;
      $index++;
   }

   # Once we have reached here means, there are no errors. Just check the congestion and return

   my $statInfo = {};
   $statInfo->{OVER_ALL_PC_CONG_LEVEL} = 0;

   my $retData = $sgx_object->waitForSgxStatusChange(-tableInfo  => "SS7_DEST",
                                                     -linkNames  => \@ss7Destinations,
                                                     -status     => $statInfo,
                                                     -interval   => 10,
                                                     -attempts   =>  7,
						     -checkSpecific    => $a{-checkSpecific});

   $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FINISHED FOR MTP2 EXTERNAL******************");

   if ($retData == 1) {
       $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK PASSED FOR MTP2 EXTERNAL******************");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");      
   } else {
       $logger->debug(__PACKAGE__ . ".$sub : ************TEST BED STATUS CHECK FAILED FOR MTP2 EXTERNAL******************");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
   }

   return $retData;
}

=head2 checkStat 

=over

=item DESCRIPTION:

    This subroutine check status

=item ARGUMENTS:

    -pcList : pclist array reference 
    -protocolType : protocol type

    Default:
    -CEInfo      => "DEF",
    -gsxInfo     => "FIRST",
    -whichElement => "SGX"

=item PACKAGE:

    SonusQA::TRIGGER

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0    - fail
    1    - success

=item EXAMPLE:

    unless (SonusQA::TRIGGER::checkStat(%args)) {
        $logger->debug(__PACKAGE__ . ".$sub : Error in check stat");
        return 0;
    }

=back

=cut


sub checkStat {
   my (%args) = @_;
   my %a = (-CEInfo      => "DEF",
            -gsxInfo     => "FIRST",
            -whichElement => "SGX");

   my $sub = "checkStat()";

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   logSubInfo( -pkg => __PACKAGE__,  -sub => $sub, %a );

   unless (defined $a{-pcList} ) {
      $logger->error(__PACKAGE__ . ".$sub The reference to pcList Array is not provided");
      return 0;
   }
   unless (defined $a{-protocolType}) {
      $logger->error(__PACKAGE__ . ".$sub The Protocol Type  is not provided");
      return 0;
   }

   # Get SGX object
   my $sgx_object = $main::TESTBED{ "sgx4000:1:obj" } || $args{-sgxObj};

   my @pcList = @{$a{-pcList}};
   my $pointCode;
   my %tempStatus;

   foreach $pointCode (@pcList) {
      $tempStatus{$pointCode}{SGX}{STATUS} = "Invalid";
      $tempStatus{$pointCode}{SGX}{CON_VALUE} = -1;

      push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");
      push (@{$tempStatus{$pointCode}{GSX}{STATUS}}, "Invalid");

      $tempStatus{$pointCode}{PSX}{STATUS} = "Invalid";
   }

      my $returnStat;

      $logger->debug(__PACKAGE__ . ".$sub:  Get SGX Link Range status");
      if ( $a{-whichElement} eq "SGX" ){
          unless($returnStat = SonusQA::TRIGGER::getSGXLinkRangeStatus(-statusInfo => \%tempStatus,
                                                 -CEInfo     => $a{-CEInfo})) {
             $logger->error(__PACKAGE__ . ".$sub:  Error in getting SGX status");
             $logger->debug(__PACKAGE__ . ".$sub: ----------> Leaving Sub [0] ");
             return 0;
          }
      $logger->debug(__PACKAGE__ . ".$sub:  Get  GSX Link Range status");
      unless($returnStat = SonusQA::TRIGGER::getGSXLinkRangeStatus(-statusInfo   => $returnStat,
                                                 -gsxInfo      => $a{-gsxInfo},
                                                 -protocolType => $a{-protocolType})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting GSX status");
         $logger->debug(__PACKAGE__ . ".$sub: ----------> Leaving Sub [0] ");
         return 0;
      }

     }elsif ( $a{-whichElement} eq "GSX" ) {
      unless($returnStat = SonusQA::TRIGGER::getGSXLinkRangeStatus(-statusInfo   => \%tempStatus,
                                                 -gsxInfo      => $a{-gsxInfo},
                                                 -protocolType => $a{-protocolType})) {
         $logger->error(__PACKAGE__ . ".$sub:  Error in getting GSX status");
         $logger->debug(__PACKAGE__ . ".$sub: ----------> Leaving Sub [0] ");
         return 0;
      }
    }    

   $logger->error(__PACKAGE__ . ".$sub:  Check Link Range Status ");
   unless($returnStat = SonusQA::TRIGGER::checkLinkRangeStat(-statusInfo => $returnStat))  {
      $logger->error(__PACKAGE__ . ".$sub: There is an issue with link status");
      $logger->debug(__PACKAGE__ . ".$sub: ----------> Leaving Sub [0] ");
      return 0;
   }

 $logger->debug(__PACKAGE__ . ".$sub: ----------> Leaving Sub [Success] ");
 return 1;
}

1;
