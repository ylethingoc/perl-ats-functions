package SonusQA::LISERVER;

=head1 NAME

SonusQA::LISERVER- Perl module to simulate Lawful Intercept Server.

=head1 AUTHOR

Ramesh Pateel - rpateel@sonusnet.com

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 DESCRIPTION

This module simulate Lawful Intercept Server, with help for following tools
     - Wireshark\Tshark

=head1 METHODS

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::Utils qw(:all);
use Module::Locate qw(locate);
use WWW::Curl::Easy;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use HTTP::Cookies;

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base);


sub doInitialization {
   my($self, %args)=@_;

   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

   $self->{COMMTYPES} = ["TELNET", "SSH"];
   $self->{TYPE} = __PACKAGE__;
   $self->{conn} = undef;
   $self->{scp}  = undef;
   $self->{curl} = undef;
   $self->{tshark} = undef;
   $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
   $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
   $self->{LOGPATH} = ''; # mention the path after creation of object inorder to store LISERVER log, It is ATS machine path

   $self->{LOCATION} = locate __PACKAGE__ ;

   $self->{PID} = 0; # We will use PID to determine if an instance is running or not,
   $self->{LASTPID} = 0; # We use this to store the previous PID when the simulation is stopped, required
   $self->{serverPort} = 3002;
   $self->{mediaPort} = 3004;
   $self->{PATH}  = "";
   $self->{HTTPS} = 0;
}


sub setSystem(){
   my($self)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
   $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
   my($cmd,$prompt, $prevPrompt);
   $self->{conn}->cmd("bash");
   $self->{conn}->cmd("");
   $cmd = 'export PS1="AUTOMATION> "';
   $self->{conn}->last_prompt("");
   $self->{PROMPT} = '/AUTOMATION\> $/';
   $self->{DEFAULTTIMEOUT} = 30;
   $self->{CONFIGPATH} = '';
   $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
   $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
   $self->{conn}->cmd($cmd);
   $self->{conn}->cmd(" ");
   $logger->info(__PACKAGE__ . ".setSystem  SET PROMPT TO: " . $self->{conn}->last_prompt);

   $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
   $self->{mediaIp} = $self->{OBJ_HOST};
   $self->{conn}->cmd('set +o history');
   $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
   return 1;
}

=head1 performAction()

=over

=item DESCRIPTION: 

The function is used to do required action on EMS ip using SOAP API's.

=item ARGUMENTS:

    Mandatory Args:
        1st arg                     - Ip Address of EMS
        2nd arg                     - action to perform
        3rd arg                     - xml request to perform

     Optional Args:
        NONE

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

 1 - Success
 0 - Failure

=item EXAMPLE: 

unless ( $liObj->performAction('10.54.66.130','create',$xml) ) {
    $logger->error("__PACKAGE__ . ".$sub: performAction failed");
    return 0;
}

=back

=cut

sub performAction {
    my($self, $emsIP, $action, $xml) = @_;

    my $sub = 'performAction';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    foreach ($emsIP, $action, $xml) {
        unless ($_) {
           $logger->error(__PACKAGE__ . ".$sub mandotory argument is missing or blank");
           return 0;
        }
    }

    $emsIP = "[$emsIP]" if ($emsIP =~ /:/);
    unless (defined $self->{curl}) {
        $self->{curl} = new WWW::Curl::Easy;
        $self->{curl}->setopt(CURLOPT_HEADER,1);
        $self->{curl_response_body} = undef;
        $self->{curl_file_handle} = undef;
        open ($self->{curl_file_handle} ,">", \$self->{curl_response_body});
        $self->{curl}->setopt(CURLOPT_WRITEDATA,$self->{curl_file_handle});
    }

    $action = "SOAPAction: \"$action\"";
    my $protocol = "http";

    RETRY:
    $self->{HTTPS} = 1 if  ( $action =~ /surveillance/i); #Changing protocol to HTTPS for surveillace methods TOOLS-72840
    $protocol = ( defined $self->{HTTPS} and $self->{HTTPS} )?"https":"http";
    my $service = ($action =~ /surveillance/i)?"surveillanceConfig":"LawfulInterceptTargetService";
    $self->{curl}->setopt(CURLOPT_POST,1);
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYHOST, 0); 
    $self->{curl}->setopt(CURLOPT_HTTPHEADER, ["Content-Type: application/xml; charset=utf-8","User-Agent: gSOAP/2.7",$action]);
    $self->{curl}->setopt(CURLOPT_POSTFIELDS, $xml);
    $self->{curl}->setopt(CURLOPT_URL, "$protocol://$emsIP/liTargetProvisioning/services/$service");

    my $retcode = $self->{curl}->perform;
    $logger->info(__PACKAGE__ . ".$sub : response received ->" . $self->{curl_response_body});

    if ($retcode == 0) {
        my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);
        $logger->debug(__PACKAGE__ . ".$sub : Transfer went ok ($response_code)");

        if ($response_code == 302 and $self->{HTTPS} == 0) {
          $self->{HTTPS} = 1;
          $logger->debug(__PACKAGE__ . ".$sub : Unable to perform operation on the EMS http. Trying https now.. ");
          goto RETRY;
        }

        if($response_code == 200) {
            if ($self->{curl_response_body} =~/\<errorMessage\>(.+)\<\/errorMessage\>/) {
                $logger->error(__PACKAGE__. ".$sub : Error in curl perform. Received the message: \"$1\"");
                $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
                return 0;
            }
        }

        unless ($response_code == 200) {
            $logger->error(__PACKAGE__ . ".$sub : ERROR Expected 200 OK response - got $response_code");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
            return 0;
        }
    }elsif($retcode == 7 and $self->{HTTPS} == 0 ){
        $self->{HTTPS} = 1;
        $logger->debug(__PACKAGE__ . ".$sub : Unable to perform operation on the EMS http. Trying https now.. ");
        goto RETRY;
    }else {
        $logger->error(__PACKAGE__ . ".$sub : Error in curl perform: " . $self->{curl}->strerror($retcode)." ($retcode)");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub : $action action performed successfully");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    return 1;
}

=head1 performActionVZLI()

=over

=item DESCRIPTION: 

The function is used to create target or delete on EMS using SS8.

=item ARGUMENTS:

    Mandatory Args:
        -serverIp                 -Ip of the server)SS8)
        -emsIp                    - Ip Address of EMS
        -interceptCriteriaType    - Target Type     (example -> DirectoryNo)
        -interceptCriteriaId      - Target Numeber  (example -> '1\9964053368')
        -Ipaddress                -Any V6 ip address
        -port                      -port no

    Optional Args:
        -user                     - username required for authentication 
        -password                 - password required for authentication

=item PACKAGES USED:

LWP::UserAgent

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $self->performActionVZLI(%args) ) {
    $logger->error("__PACKAGE__ . ".$sub: Unable to call the function'");
    return 0;
}

=back
=cut
sub performActionVZLI{
    my($self, %args)=@_; 
    my $sub = 'performActionVZLI';
    my ($response, $request, $ua);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    foreach ('-emsIp', '-ipaddress', '-port', '-interceptCriteriaId') { #manditory arguments for the method
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub mandotory argument $_ is missing or blank");
            return 0;
        }
    }

    $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->ssl_opts(verify_hostname => 0);
    $ua->ssl_opts( SSL_verify_mode => 0 );

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );
    $request = GET "https://$args{-server_ip}/liTargetProvisioning/TestServlet?commandAction=$args{-action}&_server=$args{-emsIp}&_port=443&username=calea&password=calea&interfaceType=TLS&af_number=1234&targetCriteriaType=06&targetCriteriaId=$args{-interceptCriteriaId}&interceptionType=0001&ipType=01&ipAddress=$args{-ipaddress}&port=$args{-port}&protocolType=01&operationalStatus=01&administrativeStatus=01&encryption=02&enabledFlag=01&linkPollFreq=60&linkInactivityInt=120&dbCleanUpInt=240&noOfTargets=1";
    $response = $ua->request( $request );
    $logger->debug("Response Content : \n".Dumper($response));

    return 1;
}


=head1 provisionTarget()

=over

=item DESCRIPTION: 

The function is used to provision target number on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp                    - Ip Address of EMS
        -interceptCriteriaType    - Target Type     (example -> DirectoryNo)
        -interceptCriteriaId      - Target Numeber  (example -> '1\9964053368')

    Optional Args:
        -user                     - username required for authentication 
        -password                 - password required for authentication

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $liObj->provisionTarget(
                        -emsIp=> '10.54.66.130',
                        -interceptCriteriaType => 'DirectoryNo',
                        -interceptCriteriaId => '1\9964053368'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: target provisiong failed for the number \'1\9964053368\'");
    return 0;
}

=back

=cut


sub provisionTarget {
   my($self, %args)=@_; 
   my $sub = 'provisionTarget';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-emsIp', '-interceptCriteriaType', '-interceptCriteriaId') { #manditory arguments for the method
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub mandotory argument $_ is missing or blank");
         return 0;
      }
   }
   $args{-user} ||= 'calea'; #default user is calea
   $args{-password} ||= 'calea'; #default password is calea.

   if($self->{OBJ_NODE_TYPE} eq 'PCSI'){
   $args{-action} = 'create';
      unless($self->performActionVZLI(%args)){
         $logger->error(__PACKAGE__ . ".$sub Failed to perform $args{-action} action");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }
   
   my $xml = '<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:ns2="http://www.sonusnet.com/ems/lawfulintercept/model" xmlns:ns1="http://www.sonusnet.com/ems/LawfulInterceptTargetService"><SOAP-ENV:Header><USER xsi:type="SOAP-ENC:string">' . $args{-user} . '</USER><PASSWORD xsi:type="SOAP-ENC:string">' . $args{-password} . '</PASSWORD></SOAP-ENV:Header><SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><ns1:createLawfulInterceptTarget><lawfulInterceptTarget><interceptCriteriaType>' . $args{-interceptCriteriaType} . '</interceptCriteriaType><interceptCriteriaId>' . $args{-interceptCriteriaId} . '</interceptCriteriaId><interceptionType>Intercept</interceptionType><forwardedCallIntercept>True</forwardedCallIntercept><ingressCalltoWirelessSub>True</ingressCalltoWirelessSub><enabled>True</enabled>';
   
   $xml .="<tapId>$args{-tapId}</tapId>"  if ($args{-tapId}); 
   $xml .= '</lawfulInterceptTarget></ns1:createLawfulInterceptTarget></SOAP-ENV:Body></SOAP-ENV:Envelope>';
	
   unless ($self->performAction($args{-emsIp}, 'create', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target number provisioning failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target number provisioning successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head1 retrieveTarget()

=over

=item DESCRIPTION: 

The function is used to Retrieve target number on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
            -emsIp                    - Ip Address of EMS
            -interceptCriteriaType    - Target Type     (example -> DirectoryNo)
            -interceptCriteriaId      - Target Numeber  (example -> '1\9964053368')

    Optional Args:
        -user                     - username required for authentication 
        -password                 - password required for authentication

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->retrieveTarget(
                        -emsIp=> '10.54.66.130',
                        -interceptCriteriaType => 'DirectoryNo',
                        -interceptCriteriaId => '1\9964053368'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: retrieve target failed for the number \'1\9964053368\'");
    return 0;
}

=back

=cut

sub retrieveTarget {
   my($self, %args)=@_;
   my $sub = 'retrieveTarget';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-emsIp', '-interceptCriteriaType', '-interceptCriteriaId') { #manditory arguments for the method
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub mandotory argument $_ is missing or blank");
         return 0;
      }
   }

   $args{-user} ||= 'calea'; #default user is calea
   $args{-password} ||= 'calea'; #default password is calea

   my $xml = '<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:ns2="http://www.sonusnet.com/ems/lawfulintercept/model" xmlns:ns1="http://www.sonusnet.com/ems/LawfulInterceptTargetService"><SOAP-ENV:Header><USER xsi:type="SOAP-ENC:string">' . $args{-user} . '</USER><PASSWORD xsi:type="SOAP-ENC:string">' . $args{-password} . '</PASSWORD></SOAP-ENV:Header><SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"> <ns1:retrieveLawfulInterceptTarget><interceptCriteriaType>' . $args{-interceptCriteriaType} . '</interceptCriteriaType><interceptCriteriaId>' . $args{-interceptCriteriaId} . '</interceptCriteriaId>';

  $xml .="<tapId>$args{-tapId}</tapId>"  if ($args{-tapId});
  $xml .='</ns1:retrieveLawfulInterceptTarget></SOAP-ENV:Body></SOAP-ENV:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'retrieve', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target number Retrieve failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }
   
   $logger->debug(__PACKAGE__ . ".$sub : Target number Retrieve successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}
 
=head1 listTargets()

=over

=item DESCRIPTION: 

The function is used to list all target number from DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp                    - Ip Address of EMS

    Optional Args:
        -user                     - username required for authentication
        -password                 - password required for authentication

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->listTargets(
                        -emsIp=> '10.54.66.130'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: listTargets failed");
    return 0;
}

=back

=cut

sub listTargets {
   my($self, %args)=@_;
   my $sub = 'listTargets';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

   unless ($args{-emsIp}) {
         $logger->error(__PACKAGE__ . ".$sub mandotory argument emsIp is missing or blank");
         return 0;
   }

   $args{-user} ||= 'calea'; #default user is calea
   $args{-password} ||= 'calea'; #default password is calea
   
   my $xml = '<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:ns2="http://www.sonusnet.com/ems/lawfulintercept/model" xmlns:ns1="http://www.sonusnet.com/ems/LawfulInterceptTargetService"><SOAP-ENV:Header><USER xsi:type="SOAP-ENC:string">' . $args{-user} . '</USER><PASSWORD xsi:type="SOAP-ENC:string">' . $args{-password} . '</PASSWORD></SOAP-ENV:Header><SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><ns1:listLawfulInterceptTarget>';
   
   $xml .="<tapId>$args{-tapId}</tapId>"  if ($args{-tapId});
   $xml .='</ns1:listLawfulInterceptTarget></SOAP-ENV:Body></SOAP-ENV:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'list', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub unable to list target numbers");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : listTargets successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head1 deProvisionTarget()

=over

=item DESCRIPTION: 

The function is used to De-Provision target number on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp                    - Ip Address of EMS
        -interceptCriteriaType	  - Target Type     (example -> DirectoryNo)
        -interceptCriteriaId      - Target Numeber  (example -> '1\9964053368')

    Optional Args:
        -user                     - username required for authentication 
        -password                 - password required for authentication

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 


unless ( $liObj->deProvisionTarget(
                        -emsIp=> '10.54.66.130',
                        -interceptCriteriaType => 'DirectoryNo',
                        -interceptCriteriaId => '1\9964053368'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: target provisiong failed for the number \'1\9964053368\'");
    return 0;
}

=back

=cut

sub deProvisionTarget() {
   my($self, %args)=@_;

   my $sub = 'deProvisionTarget';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub ");

   foreach ('-emsIp', '-interceptCriteriaType', '-interceptCriteriaId') { #manditory arguments for the method
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub mandotory argument $_ is missing or blank");
         return 0;
      }
   }
   
   $args{-user} ||= 'calea'; #default user is calea
   $args{-password} ||= 'calea'; #default password is calea

   if($self->{OBJ_NODE_TYPE} eq 'PCSI'){
   $args{-action} = 'delete';
      unless($self->performActionVZLI(%args)){
         $logger->error(__PACKAGE__ . ".$sub Failed to perform $args{-action} action");
         $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
         return 0;
      }
   }

   my $xml = '<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:ns2="http://www.sonusnet.com/ems/lawfulintercept/model" xmlns:ns1="http://www.sonusnet.com/ems/LawfulInterceptTargetService"><SOAP-ENV:Header><USER xsi:type="SOAP-ENC:string">' . $args{-user} . '</USER><PASSWORD xsi:type="SOAP-ENC:string">' . $args{-password} . '</PASSWORD></SOAP-ENV:Header><SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><ns1:deleteLawfulInterceptTarget><interceptCriteriaType>' . $args{-interceptCriteriaType} . '</interceptCriteriaType><interceptCriteriaId>' . $args{-interceptCriteriaId}  . '</interceptCriteriaId></ns1:deleteLawfulInterceptTarget></SOAP-ENV:Body></SOAP-ENV:Envelope>';
   


   unless ($self->performAction($args{-emsIp}, 'delete', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target number de-provisioning failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target number de-provisioning successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head1 updateTarget()

=over

=item DESCRIPTION: 

The function is used to update target number on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp                    - Ip Address of EMS
        -interceptCriteriaType    - Target Type     (example -> DirectoryNo)
        -interceptCriteriaId      - Target Numeber  (example -> '1\9964053368')

    Optional Args:
        -user                     - username required for authentication 
        -password                 - password required for authentication
        -forwardedCallIntercept   - possible values True/False, default True
        -targetStatus			  - target status can be enable by setting True, disabled by setting to False, deafult True

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->updateTarget(
                        -emsIp=> '10.54.66.130',
                        -interceptCriteriaType => 'DirectoryNo',
                        -interceptCriteriaId => '1\9964053368',
                        -targetStatus => 'False'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: target provisiong failed for the number \'1\9964053368\'");
    return 0;
}

=back    

=cut

sub updateTarget {
   my($self, %args)=@_;
   my $sub = 'updateTarget';
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

   foreach ('-emsIp', '-interceptCriteriaType', '-interceptCriteriaId') { #manditory arguments for the method
      unless ($args{$_}) {
         $logger->error(__PACKAGE__ . ".$sub mandotory argument $_ is missing or blank");
         return 0;
      }
   }

   $args{-user} ||= 'calea'; #default user is calea
   $args{-password} ||= 'calea'; #default password is calea

   my $xml = '<?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:ns2="http://www.sonusnet.com/ems/lawfulintercept/model" xmlns:ns1="http://www.sonusnet.com/ems/LawfulInterceptTargetService"><SOAP-ENV:Header><USER xsi:type="SOAP-ENC:string">' . $args{-user} . '</USER><PASSWORD xsi:type="SOAP-ENC:string">' . $args{-password} . '</PASSWORD></SOAP-ENV:Header><SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><ns1:updateLawfulInterceptTarget><lawfulInterceptTarget><interceptCriteriaType>' . $args{-interceptCriteriaType} . '</interceptCriteriaType><interceptCriteriaId>' . $args{-interceptCriteriaId} . '</interceptCriteriaId><interceptionType>Intercept</interceptionType><forwardedCallIntercept>' . ($args{-forwardedCallIntercept} || 'True') . '</forwardedCallIntercept><ingressCalltoWirelessSub>True</ingressCalltoWirelessSub><enabled>' . ( $args{-targetStatus} || 'True') . '</enabled>';

   $xml .="<tapId>$args{-tapId}</tapId>"  if ($args{-tapId});
   $xml .='</lawfulInterceptTarget></ns1:updateLawfulInterceptTarget></SOAP-ENV:Body></SOAP-ENV:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'update', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target number provisioning failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target number provisioning successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;
}

=head1 startLiTool()

=over

=item DESCRIPTION: 

The function is used to start LiServer tool which intract with DUT using radius msg's and configure the DUT to send RTP msg's perticular port.

=item ARGUMENTS:

    Mandatory Args:
        NONE

    Optional Args:
        -serverPort   - server port on Tool should run      -> Default value 3002
        -mediaIp	  - Ip Address for media intaracton     ->Default value Local Ip
        -mediaPort    - Port for media intaraction          -> Default value 3004
        -loop         - To enable loopbackmsg in tool       -> Default value 0
        -hexdump      - To enable hexdump in tool           -> Default value 0

=item PACKAGES USED:

NONE

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->startLiTool(
                        -mediaIp=> 9804
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: target provisiong failed for the number \'1\9964053368\'");
    return 0;
}

=back 

=cut

sub startLiTool {
   my ($self, %args) = @_;

   my $sub = "startLiTool";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

   my %mapArgs = ( -serverPort => '-sp', -mediaIp => '-mi', -mediaPort => '-mp');

   my $cmd = $self->{PATH} . 'liServer';

   foreach ( keys %args ) {
      $logger->debug(__PACKAGE__ . ".$sub : $_ => $args{$_}"); 
      if ($mapArgs{$_}) {
         $cmd .= " $mapArgs{$_} $args{$_}";
         $_ =~ s/^-//;
         $self->{$_} = $args{-$_};
      }else {
          $cmd .= " $_ $args{$_}";
      }
   }

   unless ( $self->{conn}->print( $cmd)) {
      $logger->error(__PACKAGE__ . ".$sub: unable to execute \'$cmd\'");
      $logger->error(__PACKAGE__ . ".$sub: not able to start LiServer");
      $logger->debug(__PACKAGE__ . ".$sub:  Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   if ( my ($prematch, $match) = $self->{conn}->waitfor( -match     => '/could not bind socket sorry/',
                                                         -match     => $self->{PROMPT},
                                                         Timeout    => 10)) {
      $logger->error(__PACKAGE__ . ".$sub:  failed start LISERVER cmd-> \'$cmd\'");
      $logger->error(__PACKAGE__ . ".$sub:  LISERVER failed with msg -> $prematch - $match");
      $logger->debug(__PACKAGE__ . ".$sub  Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }
  
   $logger->debug(__PACKAGE__ . ".$sub: successfully started LiServer");
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 stopLiTool()

=over

=item DESCRIPTION: 

The function is used to stop liServer tool already started

=item ARGUMENTS:

    Mandatory Args:
        NONE

    Optional Args:
        -logpath 
        -testid
        -timeout

=item PACKAGES USED:

NONE

=item EXTERNAL FUNCTIONS USED:

NONE

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->stopLiTool()) {
    $logger->error("__PACKAGE__ . ".$sub: capturing media failed'");
    return 0;
}

=back

=cut

sub stopLiTool {
   my ($self, %args) = @_;

   my $sub = "stopLiTool";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my %a = (
       '-testid'  => 'NONE',
        '-logpath' => $self->{LOGPATH},
       '-timeout' => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   unless( $self->{conn}->print("\cC") ) {
        $logger->error(__PACKAGE__ . ".$sub: --> Sending Ctrl-C failed.");
        $logger->debug(__PACKAGE__ . ".$sub:  Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
   }
   $logger->debug(__PACKAGE__ . ".$sub: Sending Ctrl-C is successful !!!!");

   my ($prematch, $match) = ('','');
   unless ( ($prematch, $match) =$self->{conn}->waitfor( -match     => $self->{PROMPT},
                                    -timeout   => $a{-timeout})) {
       $logger->error(__PACKAGE__ . ".$sub:  Could not match expected prompt after sending Ctrl-C.");
       $logger->debug(__PACKAGE__ . ".$sub:  Session Dump Log is : $self->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
       return 0;
   }

   my @result = split("\n",$prematch);
   chomp @result;

   if ($a{-logpath}) {
      my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
      my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
      my $filename = "$a{-logpath}/LISERVER-$timestamp-";
      $filename .= "$a{-testid}.log";
      my $file;
      unless ( open OUTFILE, $file = ">$filename" ) {
          $logger->error(__PACKAGE__ . "$sub :  Cannot open output file \'$filename\'- Error: $!");
          $logger->error(__PACKAGE__ . "$sub : unable to log LISERVER output");
      } else {
          map { print OUTFILE "$_\n" } @result;
      }
   }

   $logger->debug(__PACKAGE__ . ".$sub: Stopping tetherial is successful !!!!");
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return wantarray ? @result : 1;
}

=head1 startRtpCapture()

=over

=item DESCRIPTION: 

The function is used to starts media capture using wireshark on media ip and port, and captured file will be in the format testcaseid-timestamp-LI-TETHERIAL.pcap

=item ARGUMENTS:

    Mandatory Args:
        -testCaseID   - Test-Case ID (used to name the pcap file)

    Optional Args:
        NONE

=item PACKAGES USED:

SonusQA::TSHARK

=item EXTERNAL FUNCTIONS USED:

SonusQA::TSHARK::startCapturing

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->startRtpCapture(
                        -testCaseID=> 871687
                    ) ) {
    $logger->error("__PACKAGE__ . ".$sub: capturing media failed'");
    return 0;
}

=back

=cut

sub startRtpCapture {
   my ($self, %args) = @_;

   my $sub = "startRtpCapture";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

   unless ($args{-testCaseID}) {
      $logger->error(__PACKAGE__ . ".$sub: Test case ID is missing. This is a mandatory parameter");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub Passed Arguments : " . Dumper(\%args));

   unless (defined $args{-user}) {
      $logger->debug(__PACKAGE__ . ".$sub: no user passed to make session to cpature RTP, \'$self->{OBJ_USER}\' will be used");
      $args{-user} = $self->{OBJ_USER};
   }

   unless (defined $args{-password}) {
      $logger->debug(__PACKAGE__ . ".$sub: no user passed to make session to cpature RTP, \'$self->{OBJ_USER}\' will be used");
      $args{-password} = $self->{OBJ_PASSWORD}; 
   }

   unless (defined $self->{tshark}) {
       require SonusQA::TSHARK; # grab it only required at run time

       $self->{tshark} = SonusQA::TSHARK->new(-obj_host => $self->{mediaIp}, 
                                              -sessionlog => 1,
                                              -obj_user => $self->{OBJ_USER},
                                              -obj_password => $self->{OBJ_PASSWORD},
                                              -obj_commtype => "SSH",
                                              -obj_hostname => $self->{OBJ_HOSTNAME},
                                              -obj_port  => 22);

       unless ($self->{tshark}) {
           $logger->error(__PACKAGE__ . ".$sub: unable to create TSHARK object");
           $logger->error(__PACKAGE__ . ".$sub:  Could not open session object to \'$self->{OBJ_HOST}\'");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
           return 0;
       }
   }

   my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
   $year  += 1900;
   $month += 1;
   my $timeStamp = $year . $month . $day . '-' . $hour . $min . $sec;
   $self->{RtpFile} = "$args{-testCaseID}-$timeStamp-LI-TETHERIAL\.pcap";

   my $host = $args{-host} || $self->{mediaIp};
   my $port = $args{-port} || $self->{mediaPort};
 
   my $tsharkCmd = "tethereal  -w $self->{RtpFile} host $host and port $port";

   unless ($self->{tshark}->startCapturing( -cmd => $tsharkCmd, -timeout => $self->{DEFAULTTIMEOUT})) {
      $logger->error(__PACKAGE__ . ".$sub: unable to start RTP capture process");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub: RTP Capture process started successful !!!!");
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 stopRtpCapture()

=over

=item DESCRIPTION: 

The function is used to stop the media capture process by wireshark, and also copy the captured file to required path in local server

=item ARGUMENTS:

    Mandatory Args:
        -logDir   - Log path in local server

    Optional Args:
        NONE

=item PACKAGES USED:

SonusQA::TSHARK

=item EXTERNAL FUNCTIONS USED:

SonusQA::TSHARK::stopCapturing

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE: 

unless ( $liObj->stopRtpCapture(-logDir => '/home/rpateel/LILogs/')) {
    $logger->error("__PACKAGE__ . ".$sub: capturing media failed'");
    return 0;
}

=back

=cut

sub stopRtpCapture {
   my ($self, %args) = @_;

   my $sub = "stopRtpCapture";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

   $args{-scpPort} ||= 22;

   unless ($args{-logDir}) {
      $logger->error(__PACKAGE__ . ".$sub: Destination directory to copy pcap file is missing, This is a mandatory parameter");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
   }

   unless ($self->{tshark}->stopCapturing(-timeout => $self->{DEFAULTTIMEOUT})) {
     $logger->error(__PACKAGE__ . ".$sub: unable to stop capturing");
     $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
     return 0;
   }

   my %scpArgs;
   $scpArgs{-hostip} = $self->{tshark}->{OBJ_HOST};
   $scpArgs{-hostuser} = $self->{tshark}->{OBJ_USER};
   $scpArgs{-hostpasswd} = $self->{tshark}->{OBJ_PASSWORD};
   $scpArgs{-scpPort} = $args{-scpPort};
   $scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:$self->{RtpFile}";
   $scpArgs{-destinationFilePath} = "$args{-logDir}/$self->{RtpFile}";

   $logger->debug(__PACKAGE__ . ".$sub: scp files  to $scpArgs{-destinationFilePath}");

   &SonusQA::Base::secureCopy(%scpArgs);
   
   if (-e $scpArgs{-destinationFilePath}) {
       $logger->info(__PACKAGE__ . ".$sub: File copying is successful !!!!");
   } else {
       $logger->error(__PACKAGE__ . ".$sub: Unable to copy the to local server");
       return 0;
   } 

   unless ($self->{tshark}->{conn}->cmd("rm $self->{RtpFile}")) {
       $logger->error(__PACKAGE__ . ".$sub: unable to deleted \'$self->{RtpFile}\' from \'$self->{tshark}->{OBJ_HOST}\'");
   }

   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
   return 1;
}

=head1 execCmd()

=over

=item DESCRIPTION:

This function enables user to execute any command on the LI server.

=item ARGUMENTS:

1. Command to be executed.
2. Timeout in seconds (optional).

=item RETURS:

Output of the command executed.

=item EXAMPLE:

my @results = $LI->execCmd("ls /ats/NBS/sample.csv");
This would execute the command "ls /ats/NBS/sample.csv" on the SIPP server and return the output of the command.

=back

=cut

sub execCmd{
  my ($self,$cmd, $timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
  my(@cmdResults,$timestamp);
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
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
        $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
        $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
        chomp(@cmdResults);
        map { $logger->warn(__PACKAGE__ . ".execCmd \t\t$_") } @cmdResults;
        $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
        return @cmdResults;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    return @cmdResults;
}

=head1 closeConn()

=over

=item DESCRIPTION:

Overriding the Base.closeConn 

=item ARGUMENTS:

None

=item RETURS:

None

=item EXAMPLE:

$obj->closeConn();

=back

=cut

sub closeConn {
    my ($self) = @_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn");
    $logger->debug(__PACKAGE__ . ".closeConn Closing SGX4000 connection...");

    if ($self->{conn}) {
        $self->{conn}->print("exit");
        $self->{conn}->close;
    }

    if ($self->{tshark}){
        $self->{tshark}->{conn}->print("exit");
        $self->{tshark}->{conn}->close;
        $self->{tshark} = undef;
    }
}

#TOOLS-72840
=head1 addSurveillance()

=over

=item DESCRIPTION: 

The function is used to Add Surveillance record on required DUT (PSX/GSX/SBX) using EMS. 

=item ARGUMENTS:

    Mandatory Args:
        -emsIp         - Ip Address of EMS
        -deviceName    - Device name             (example -> GIMLIVM2)
        -pni           - Call Content DF flag    (example -> true)
        -targetId      - Username                (example -> 'criteria3@rbbn.com')
        -cdDfGroupName - DF group name           (example -> 'grp3')
        -tapId         - Tap ID                  (example -> 3)

    Optional Args:
        -user          - username required for authentication 
        -password      - password required for authentication
        -txCcDfName    - IP address of the DF to which call content transmitted by the target will be sent (becomes mandatory when 'pni' is set to true)
        -txCcDfPort    - Port of the DF to which call content transmitted by the target will be sent (becomes mandatory when 'pni' is set to true)
        -rxCcDfName    - IP address of the DF to which call content received by the target will be sent (becomes mandatory when 'pni' is set to true)
        -rxCcDfName    - Port of the DF to which call content received by the target will be sent (becomes mandatory when 'pni' is set to true)
        -errorOption   - An optional field that can be omitted. Defaults to "stop-on-error"

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $liObj->addSurveillance(
                        -emsIp          => '10.54.66.130',
                        -deviceName     => 'GIMLIVM2',
                        -pni            => 'true'
                        -txCcDfName     => '3.3.3.3',
                        -txCcDfPort     => '3',
                        -rxCcDfName     => '31.31.31.31',
                        -rxCcDfName     => '31',
                        -targetId       => 'criteria3@rbbn.com',
                        -cdDfGroupName  => 'grp3',
                        -tapId          => '3',
                        -errorOption    => 'ignore-error'
                    ) ) {
    $logger->error(__PACKAGE__ . ".$subName: Add Surveillance failed for Target \'criteria3@rbbn.com\'");
    return 0;
}

=back

=cut

sub addSurveillance {
    my ($self,%args) = @_;
    my $sub = "addSurveillance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $flag = 1;
    foreach ('emsIp','deviceName','pni','targetId','cdDfGroupName','tapId') {
        unless (exists $args{-$_}) {
            $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
            $flag =  0;
            last;
        }
    }

    if ($args{-pni} eq 'true' and $flag)  {
        $logger->debug(__PACKAGE__. ".$sub: \'pni\' is set to true. Making \'Call Content DF\' fields mandatory");
        foreach ('txCcDfName','txCcDfPort','rxCcDfName','rxCcDfPort') {
            unless (exists $args{-$_}) {
                $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
                $flag =  0;
                last;
            }
        }
    }

    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $args{-user} ||= 'calea'; #default user is calea
    $args{-password} ||= 'calea'; #default password is calea
    $args{-errorOption} ||= 'stop-on-error'; #default set to ignore error unless otherwise defined

    my $xml = '<?xml version="1.0" encoding="utf-8"?>
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"       xmlns:xsd="http://www.w3.org/2001/XMLSchema"      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <soapenv:Body>
                    <editConfig xmlns="http://www.nextone.com/ivms/schema/config">
                        <config>
                            <ns1:credential xsi:type="ns1:credentialsType" xmlns:ns1="http://www.nextone.com/ivms/schema/common">
                                <ns1:user>'.$args{-user}.'</ns1:user>
                                <ns1:password>'.$args{-password}.'</ns1:password>
                            </ns1:credential>
                            <surveillanceConfig command="addSurveillance" xmlns="">
                                <Surveillance>
                                    <deviceName>'.$args{-deviceName}.'</deviceName>
                                    <pni>'.$args{-pni}.'</pni>
                                    <txCcDfName><name>'.$args{-txCcDfName}.'</name></txCcDfName>
                                    <txCcDfPort>'.$args{-txCcDfPort}.'</txCcDfPort>
                                    <rxCcDfName><name>'.$args{-rxCcDfName}.'</name></rxCcDfName>
                                    <rxCcDfPort>'.$args{-rxCcDfPort}.'</rxCcDfPort>
                                    <targetId><name>'.$args{-targetId}.'</name></targetId>
                                    <cdDfGroupName><name>'.$args{-cdDfGroupName}.'</name></cdDfGroupName>
                                    <tapId><name>'.$args{-tapId}.'</name></tapId>
                                </Surveillance>
                            </surveillanceConfig>
                        </config>
                        <ns2:errorOption xsi:type="ns2:errorOptionType" xmlns:ns2="http://www.nextone.com/ivms/schema/common">'.$args{-errorOption}.'</ns2:errorOption>
                    </editConfig>
                </soapenv:Body>
                </soapenv:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'addSurveillance', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target Device Add Surveillance failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target Device Add Surveillance successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;

}


=head1 modifySurveillance()

=over

=item DESCRIPTION: 

The function is used to Modify Surveillance record on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp         - Ip Address of EMS
        -deviceName    - Device name             (example -> GIMLIVM2)
        -pni           - Call Content DF flag    (example -> true)
        -targetId      - Username                (example -> 'criteria3@rbbn.com')
        -cdDfGroupName - DF group name           (example -> 'grp3')
        -tapId         - Tap ID                  (example -> 3)

    Optional Args:
        -user          - username required for authentication 
        -password      - password required for authentication
        -txCcDfName    - IP address of the DF to which call content transmitted by the target will be sent (becomes mandatory when 'pni' is set to true)
        -txCcDfPort    - Port of the DF to which call content transmitted by the target will be sent (becomes mandatory when 'pni' is set to true)
        -rxCcDfName    - IP address of the DF to which call content received by the target will be sent (becomes mandatory when 'pni' is set to true)
        -rxCcDfName    - Port of the DF to which call content received by the target will be sent (becomes mandatory when 'pni' is set to true)
        -errorOption   - An optional field that can be omitted. Defaults to "stop-on-error"

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $liObj->modifySurveillance(
                        -emsIp          => '10.54.66.130',
                        -deviceName     => 'GIMLIVM2',
                        -txCcDfName     => '3.3.3.3',
                        -txCcDfPort     => '3',
                        -rxCcDfName     => '31.31.31.31',
                        -rxCcDfName     => '31',
                        -targetId       => 'criteria3@rbbn.com',
                        -cdDfGroupName  => 'grp3',
                        -tapId          => '3',
                        -errorOption    => 'ignore-error'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$subName: Modify Surveillance failed for Target \'criteria3@rbbn.com\'");
    return 0;
}

=back

=cut

sub modifySurveillance {
    my ($self,%args) = @_;
    my $sub = "modifySurveillance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $flag = 1;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    foreach ('emsIp','deviceName','pni','targetId','cdDfGroupName','tapId') {
        unless ( exists $args{-$_}) {
            $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
            $flag =  0;
            last;
        }
    }

    if ($args{-pni} eq 'true' && $flag) {
        $logger->debug(__PACKAGE__. ".$sub: \'pni\' is set to true. Making \'Call Content DF\' fields mandatory");
        foreach ('txCcDfName','txCcDfPort','rxCcDfName','rxCcDfPort') {
            unless ( exists $args{-$_}) {
                $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
                $flag =  0;
                last;
            }
        }
    }

    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $args{-user} ||= 'calea'; #default user is calea
    $args{-password} ||= 'calea'; #default password is calea
    $args{-errorOption} ||= 'stop-on-error'; #default set to ignore error unless otherwise defined

    my $xml = '<?xml version="1.0" encoding="utf-8"?>
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"       xmlns:xsd="http://www.w3.org/2001/XMLSchema"      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <soapenv:Body>
                    <editConfig xmlns="http://www.nextone.com/ivms/schema/config">
                        <config>
                            <ns1:credential xsi:type="ns1:credentialsType" xmlns:ns1="http://www.nextone.com/ivms/schema/common">
                                <ns1:user>'.$args{-user}.'</ns1:user>
                                <ns1:password>'.$args{-password}.'</ns1:password>
                            </ns1:credential>
                            <surveillanceConfig command="modifySurveillance" xmlns="">
                                <Surveillance>
                                    <deviceName>'.$args{-deviceName}.'</deviceName>
                                    <pni>'.$args{-pni}.'</pni>
                                    <txCcDfName><name>'.$args{-txCcDfName}.'</name></txCcDfName>
                                    <txCcDfPort>'.$args{-txCcDfPort}.'</txCcDfPort>
                                    <rxCcDfName><name>'.$args{-rxCcDfName}.'</name></rxCcDfName>
                                    <rxCcDfPort>'.$args{-rxCcDfPort}.'</rxCcDfPort>
                                    <targetId><name>'.$args{-targetId}.'</name></targetId>
                                    <cdDfGroupName><name>'.$args{-cdDfGroupName}.'</name></cdDfGroupName>
                                    <tapId><name>'.$args{-tapId}.'</name></tapId>
                                </Surveillance>
                            </surveillanceConfig>
                        </config>
                        <ns2:errorOption xsi:type="ns2:errorOptionType" xmlns:ns2="http://www.nextone.com/ivms/schema/common">'.$args{-errorOption}.'</ns2:errorOption>
                    </editConfig>
                </soapenv:Body>
                </soapenv:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'modifySurveillance', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target Device Modify Surveillance failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target Device Modify Surveillance successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;    
}

=head1 removeSurveillance()

=over

=item DESCRIPTION: 

The function is used to Remove Surveillance record on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp         - Ip Address of EMS
        -deviceName    - Device name             (example -> GIMLIVM2)
        -tapId         - Tap ID                  (example -> 3)

    Optional Args:
        -user          - username required for authentication 
        -password      - password required for authentication
        -errorOption   - An optional field that can be omitted. Defaults to "stop-on-error"

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $liObj->removeSurveillance(
                        -emsIp          => '10.54.66.130',
                        -deviceName     => 'GIMLIVM2',
                        -tapId          => '3'
                        -errorOption    => 'ignore-error'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$subName: Remove Surveillance failed for Target \'criteria3@rbbn.com\'");
    return 0;
}

=back

=cut

sub removeSurveillance {
    my ($self,%args) = @_;
    my $sub = "removeSurveillance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $flag = 1;    
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    foreach ('emsIp','deviceName','tapId') {
        unless ( exists $args{-$_}) {
            $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
            $flag =  0;
            last;
        }
    }

    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $args{-user} ||= 'calea'; #default user is calea
    $args{-password} ||= 'calea'; #default password is calea
    $args{-errorOption} ||= 'stop-on-error'; #default set to ignore error unless otherwise defined

    my $xml = '<?xml version="1.0" encoding="utf-8"?>
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"       xmlns:xsd="http://www.w3.org/2001/XMLSchema"      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <soapenv:Body>
                    <editConfig xmlns="http://www.nextone.com/ivms/schema/config">
                        <config>
                            <ns1:credential xsi:type="ns1:credentialsType" xmlns:ns1="http://www.nextone.com/ivms/schema/common">
                                <ns1:user>'.$args{-user}.'</ns1:user>
                                <ns1:password>'.$args{-password}.'</ns1:password>
                            </ns1:credential>
                            <surveillanceConfig command="removeSurveillance" xmlns="">
                                <Surveillance>
                                    <deviceName>'.$args{-deviceName}.'</deviceName>
                                    <pni>false</pni>
                                    <txCcDfName xsi:nil="true"/>
                                    <txCcDfPort xsi:nil="true"/>
                                    <rxCcDfName xsi:nil="true"/>
                                    <rxCcDfPort xsi:nil="true"/>
                                    <targetId xsi:nil="true"/>
                                    <cdDfGroupName xsi:nil="true"/>
                                    <tapId><name>'.$args{-tapId}.'</name></tapId>
                                </Surveillance>
                            </surveillanceConfig>
                        </config>
                        <ns2:errorOption xsi:type="ns2:errorOptionType" xmlns:ns2="http://www.nextone.com/ivms/schema/common">'.$args{-errorOption}.'</ns2:errorOption>
                    </editConfig>
                </soapenv:Body>
                </soapenv:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'removeSurveillance', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target Device Remove Surveillance failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target Device Remove Surveillance successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;

}

=head1 removeAllSurveillance()

=over

=item DESCRIPTION: 

The function is used to Remove Surveillance record on required DUT (PSX/GSX/SBX) using EMS.

=item ARGUMENTS:

    Mandatory Args:
        -emsIp         - Ip Address of EMS
        -tapId         - Tap ID                  (example -> 3)

    Optional Args:
        -user          - username required for authentication 
        -password      - password required for authentication
        -errorOption   - An optional field that can be omitted. Defaults to "stop-on-error"

=item PACKAGES USED:

WWW::Curl::Easy

=item GLOBAL VARIABLES USED:

None

=item RETURNS:

1 - Success
0 - Failure

=item EXAMPLE:

unless ( $liObj->removeAllSurveillance(
                        -emsIp          => '10.54.66.130',
                        -deviceName     => 'GIMLIVM2',
                        -errorOption    => 'ignore-error'
                    ) ) {
    $logger->error("__PACKAGE__ . ".$subName: Remove Surveillance failed for Target \'criteria3@rbbn.com\'");
    return 0;
}

=back

=cut

sub removeAllSurveillance {
    my ($self,%args) = @_;
    my $sub = "removeAllSurveillance";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $flag = 1;    
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    foreach ('emsIp','deviceName') {
        unless ( exists $args{-$_}) {
            $logger->error(__PACKAGE__. ".$sub: Mandatory argument $_ missing or blank");
            $flag =  0;
            last;
        }
    }

    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
        return 0;
    }

    $args{-user} ||= 'calea'; #default user is calea
    $args{-password} ||= 'calea'; #default password is calea
    $args{-errorOption} ||= 'stop-on-error'; #default set to ignore error unless otherwise defined

    my $xml = '<?xml version="1.0" encoding="utf-8"?>
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"       xmlns:xsd="http://www.w3.org/2001/XMLSchema"      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <soapenv:Body>
                    <editConfig xmlns="http://www.nextone.com/ivms/schema/config">
                        <config>
                            <ns1:credential xsi:type="ns1:credentialsType" xmlns:ns1="http://www.nextone.com/ivms/schema/common">
                                <ns1:user>'.$args{-user}.'</ns1:user>
                                <ns1:password>'.$args{-password}.'</ns1:password>
                            </ns1:credential>
                            <surveillanceConfig command="removeAllSurveillance" xmlns="">
                                <Surveillance>
                                    <deviceName>'.$args{-deviceName}.'</deviceName>
                                    <pni>false</pni>
                                    <txCcDfName xsi:nil="true"/>
                                    <txCcDfPort xsi:nil="true"/>
                                    <rxCcDfName xsi:nil="true"/>
                                    <rxCcDfPort xsi:nil="true"/>
                                    <targetId xsi:nil="true"/>
                                    <cdDfGroupName xsi:nil="true"/>
                                    <tapId xsi:nil="true"/>
                                </Surveillance>
                            </surveillanceConfig>
                        </config>
                        <ns2:errorOption xsi:type="ns2:errorOptionType" xmlns:ns2="http://www.nextone.com/ivms/schema/common">'.$args{-errorOption}.'</ns2:errorOption>
                    </editConfig>
                </soapenv:Body>
                </soapenv:Envelope>';

   unless ($self->performAction($args{-emsIp}, 'removeSurveillance', $xml)) {
       $logger->error(__PACKAGE__ . ".$sub Target Device Remove-All Surveillance failed");
       $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [0]");
       return 0;
   }

   $logger->debug(__PACKAGE__ . ".$sub : Target Device Remove-All Surveillance successful");
   $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
   return 1;

}



1;
